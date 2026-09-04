#!/usr/bin/env python3
"""(a)-verification for soak candidate `campsel` (GH #137, strategy 08-23T23:35Z).

WHAT `campsel` DOES
-------------------
`bots/mode_farm_generic.lua` resolves the closest neutral camp through ONE
wrapper (`ClosestCamp`), which passes the gate in as `bReadCampRecord` to
`J.Site.GetClosestNeutralSpwan` (`bots/FunLib/aba_site.lua`).  `RefreshCamp`
emits WRAPPERS -- `{idx = camp.idx, cattr = camp}` -- and that selector calls
its two predicates on the wrapper, which carries neither `.team` nor `.type`:

    IsEnemyCamp(wrapper)   = (nil ~= GetTeam())   => TRUE for EVERY camp
    IsAncientCamp(wrapper) = (nil == "ancient")   => FALSE for EVERY camp

so, shipped: (1) every camp is multiplied by the enemy penalty, and a UNIFORM
factor cannot move an argmin -- the enemy-jungle penalty the line exists to
apply does not exist, only its side effect (the 15000 cut-off is scaled to an
effective 10000 for all camps); (2) the `GetLevel() >= 10 or not ancient`
ancient gate is dead at every level.  Armed, both predicates read `camp.cattr`
and mean what they say.

TWO HALVES, AND ONLY ONE OF THEM IS CLEANLY OBSERVABLE HERE
-----------------------------------------------------------
* HALF A (the enemy penalty becomes real).  Armed, own-side camps cost `d` and
  enemy-side camps cost `1.5 d`, so the argmin FLIPS whenever the raw-nearest
  camp is an enemy one and an own camp sits inside 1.5x of it.  Observable
  prediction: the armed leg should jungle LESS on the enemy half.  Nothing
  else in the armed string edits camp choice BY SIDE (`campfarm` edits the
  ancient-creep target list, which is side-blind), so this half is the one
  this file measures as its primary.
* HALF B (the level-10 ancient gate comes alive).  Its observable -- a level
  < 10 hero engaging an ancient camp -- is ALREADY suppressed by two shipped
  clauses (`utils.IsValidCreep`'s `GetLevel() > 9 or not IsAncientCreep`) and
  is additionally moved by `campfarm`, which is armed in the SAME string.  It
  is therefore reported as a CONTROL, never as this id's attribution.

THE PREMISE NOTHING IN THE TREE HAS EVER CHECKED
------------------------------------------------
Both restorations assume the ENGINE's `GetNeutralSpawners()` record carries
`.team` in {2,3} (comparable to `GetTeam()`) and `.type` as the STRING
"ancient".  The fix's own local validation cannot see that: the strategy
group's report says so in its own words -- `GetNeutralSpawners()` is `{}` on
every fixture and the camp table is "a declared stand-in" the fixer wrote.
And this repo's own `docs/BOT_API_REFERENCE.md` documents BOTH fields as
INTS.  If `.type` is an int, `IsAncientCamp` is FALSE even armed and half B is
a no-op; if `.team` is TEAM_NEUTRAL for every camp, `IsEnemyCamp` is TRUE even
armed and half A is a no-op too -- i.e. the id could be a total no-op and
would read back as "tested, no effect" with nothing raising a hand.
`premise_sites()` prints the three shipped readers of the RAW record that
stake the same claim, so the reader can weigh code against doc; the corpus
half of the answer is the HALF A table.

WHAT THE READING CAN AND CANNOT SAY
-----------------------------------
Observable: a neutral-camp engagement (hero damage traded with an
`npc_dota_neutral*` unit), its first frame, and which half of the map the
camp centroid sits on (`camp_owner`, decided by distance to the two ANCIENT
buildings read out of the timeline, not by a hardcoded sign of x).

NOT observable: the bot's MODE.  `ClosestCamp` only runs on the farm path,
and a `.dem` cannot say whether a hero standing in the enemy jungle got there
by farm desire, a rotation, a chase, or a smoke.  So the enemy-half share is
a SUPERSET of the decisions this gate touches: a real Delta is evidence the
gate bites, a zero Delta is NOT proof it does not (the gate's own share of
the superset may be too small to show).  Stated here so no later round reads
a null as a refutation.

CONFOUND, NAMED: `pullcamp` (`jmz_func.lua:8385`) is armed in the same string
and its camp filter is `camp.team == GetTeam()` -- OWN camps only.  Were it
firing, it would push own-side engagements up on the armed leg, i.e. in the
SAME direction as half A's prediction.  It is a registered SILENT (owner P1),
which is why half A is readable at all -- and `pullcamp`'s silence has the
SAME `camp.team` premise underneath it, which is reported as a cross-link
rather than assumed either way.

#148 DISCIPLINE
---------------
Every leg number is given in BOTH physical strata (ab = radiant-armed,
ba = dire-armed); two layers of opposite sign are noise, not a reading, and
that test runs BEFORE the pooled zero test so a cancellation can never be
laundered into SILENT.  Counts over a small integer range are reported as
means plus a share, never as a lone median.

Usage:
    campsel_domain.py <sweep_dir> [<sweep_dir> ...] [--out out.jsonl]
    campsel_domain.py --selfcheck
    campsel_domain.py --source
"""
import argparse
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
from ancient_camp_domain import is_ancient, is_hero, load  # noqa: E402
from campgrade_ladder import camp_owner  # noqa: E402
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', '..'))
ABA_SITE = os.path.join(REPO, 'bots', 'FunLib', 'aba_site.lua')
FARM_MODE = os.path.join(REPO, 'bots', 'mode_farm_generic.lua')
JMZ = os.path.join(REPO, 'bots', 'FunLib', 'jmz_func.lua')
TA = os.path.join(REPO, 'bots', 'BotLib', 'hero_templar_assassin.lua')
API_DOC = os.path.join(REPO, 'docs', 'BOT_API_REFERENCE.md')

CAND = 'campsel'
NEUTRAL = 'npc_dota_neutral'

# Episode shaping.  Same family of constants as ancient_camp_domain: a gap
# longer than GAP starts a new engagement, and a camp's samples are the hero
# positions at the moment he traded with one of its creeps.
GAP = 12.0
CLUSTER_R = 900.0          # pullcamp_domain's CAMP_CLUSTER family
WARMUP_GAMES = 8           # games spent on camp geometry before the reading
CAMP_SUPPORT = 3           # a centroid needs this many samples to be a camp
FAR_FROM_CAMP = 1200.0     # GH #176/#191 illusion hygiene, same bound as
                           # campfarm_target.FAR_FROM_CAMP
# How far BEFORE the first blow the camp choice was made.  The selector runs
# on the farm path and the hero then walks; 20 s is the walk, not the fight,
# and it is reported as a chosen lead rather than a discovered one -- the
# witness rate is given at three leads so the reader can see it is not an
# artefact of one.
DECIDE_LEADS = (10.0, 20.0, 30.0)
# A hero who TELEPORTED (scroll, blink, respawn) inside the decision lead was
# not standing where the lead says he was, so the witness would be evaluated
# from a position on the far side of the map.  Found by looking at the frames
# BEFORE the aggregate: `ffdcb6/20260826_211631_slot6` sniper t0=190.8 moves
# (-5507,4918) -> (4466,-5211) in one 5 s step.  The guard is model-free --
# a speed no hero can walk -- rather than a `modifier_teleporting` match, so
# it also catches blink, forced movement and a respawn snap.  Dota's hard
# movement cap is 550 u/s; 700 leaves room for interpolation error.
MAX_WALK_SPEED = 700.0


# --------------------------------------------------------------------------
# source facts -- read out of bots/, never copied (source_constants contract)
# --------------------------------------------------------------------------
def _read(path):
    with open(path, 'r', encoding='utf-8') as fh:
        return fh.read()


def _strip_lua_comments(src):
    return re.sub(r'^\s*--.*$', '', src, flags=re.M)


def _split_top_level(arglist):
    """Split a Lua argument list on its TOP-LEVEL commas.

    `a and f('x'), b and f('y')` -> two arguments.  Depth-aware because the
    whole point is to keep a nested `f(a, b)` from reading as two gates; a
    plain `.split(',')` would put every comma at top level and make the
    conjunction check below unable to see a conjunction at all.
    """
    out, depth, cur = [], 0, []
    for ch in arglist:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(''.join(cur))
            cur = []
            continue
        cur.append(ch)
    out.append(''.join(cur))
    return [a.strip() for a in out if a.strip()]


def _selector_body(src=None):
    """Source text of `____exports.GetClosestNeutralSpwan = function(...)`."""
    src = _strip_lua_comments(src if src is not None else _read(ABA_SITE))
    m = re.search(r'^____exports\.GetClosestNeutralSpwan\s*=\s*function\s*\(',
                  src, re.M)
    if not m:
        raise RuntimeError('aba_site.lua: GetClosestNeutralSpwan not found')
    nxt = re.compile(r'^____exports\.', re.M).search(src, m.end())
    return src[m.start():nxt.start() if nxt else len(src)]


def gate_facts(farm_src=None, aba_src=None):
    """Everything the attribution argument stands on, derived not transcribed."""
    farm = _strip_lua_comments(farm_src if farm_src is not None
                               else _read(FARM_MODE))
    body = _selector_body(aba_src)

    # (1) exactly ONE gate, and it names this candidate.  A second
    # IsSoakCandidate in the same conjunction is the GH-#207 shape: the day the
    # other id is promoted the whole gate freezes FALSE.
    #
    # READ PER ARGUMENT, not over the whole argument list (director 2026-09-02).
    # The two are the same number only while the wrapper carries one gate.  On
    # 2026-09-01 `slotarb` (GH #406) was threaded through the SAME call as a
    # second, INDEPENDENT argument -- `f(hBot, tCamps, <campsel gate>, <slotarb
    # gate>)` -- and this scan, which spanned the whole list, reported
    # `cands=['campsel','slotarb']` and turned trunk red on a tree where nothing
    # was conjoined with anything.  The hazard named in the paragraph above is a
    # property of ONE argument (`A and B` freezes when B is promoted); two
    # arguments are two gates, each armable alone, which is what the wrapper's
    # own header claims.  Widening the check to "two ids anywhere in the call is
    # fine" would have deleted the #207 protection instead of aiming it, so the
    # split is the fix and `sibling_cands` below is the ratchet: a THIRD id
    # appearing still has to be acknowledged once, in the test, by name.
    m = re.search(
        r'GetClosestNeutralSpwan\s*\(\s*hBot\s*,\s*tCamps\s*,'
        r'(?P<arg>.*?)\)\s*\n', farm, re.S)
    if not m:
        raise RuntimeError('mode_farm_generic.lua: ClosestCamp call not found')
    arg = m.group('arg')
    per_arg = [re.findall(r"IsSoakCandidate\(\s*'([^']+)'\s*\)", a)
               for a in _split_top_level(arg)]
    cands = next((ids for ids in per_arg if 'campsel' in ids), [])
    sibling_cands = sorted({i for ids in per_arg for i in ids} - {'campsel'})
    conjoined = sorted(tuple(ids) for ids in per_arg if len(ids) > 1)

    # (2) the ONE call site.  If a second appears, the gate is resolved in a
    # place this file has never looked at.
    call_sites = len(re.findall(r'J\.Site\.GetClosestNeutralSpwan\s*\(',
                                _strip_lua_comments(_read(FARM_MODE))))

    # (3) the selector's own numbers: the penalty multiplier and the cut-off.
    pen = re.search(r'dist\s*=\s*dist\s*\*\s*([\d.]+)', body)
    cut = re.search(r'local\s+minDist\s*=\s*([\d.]+)', body)
    lvl = re.search(r'bot:GetLevel\(\)\s*>=\s*(\d+)', body)
    # (4) the selection itself -- `rec` is the wrapper unless armed.
    sel = re.search(r'if\s+bReadCampRecord\s+and\s+camp\.cattr\s*~=\s*nil\s+then'
                    r'\s*\n\s*rec\s*=\s*camp\.cattr', body)
    # (5) both predicates must be called on `rec`, not on `camp` -- if a
    # future edit passes `camp` again the armed leg silently becomes shipped.
    on_rec = len(re.findall(r'Is(?:Enemy|Ancient)Camp\(rec\)', body))
    on_camp = len(re.findall(r'Is(?:Enemy|Ancient)Camp\(camp\)', body))
    return {
        'cands': cands,
        'sibling_cands': sibling_cands,
        'conjoined': conjoined,
        'call_sites': call_sites,
        'penalty': float(pen.group(1)) if pen else None,
        'cutoff': float(cut.group(1)) if cut else None,
        'ancient_level': int(lvl.group(1)) if lvl else None,
        'selection': bool(sel),
        'preds_on_rec': on_rec,
        'preds_on_camp': on_camp,
    }


def premise_sites(srcs=None):
    """Every shipped reader of a RAW engine camp record, plus the doc's claim.

    This is the audit half of the file: the armed leg's whole meaning rests on
    `.team` being a team id and `.type` being the string "ancient".

    GH #241 filed this as a two-sided contradiction -- three shipped sites
    against our own API reference, which called both fields ints.  2026-08-27
    (strategy) retired the second side: that row was never an observation of
    this API (Valve publishes no field list; the engine dump says `variant`),
    the same six rows appear verbatim in an unrelated third-party repo, and
    the row contradicted itself -- every numeric annotation in it sat next to
    a string-valued description (`type` (int) "small, medium, large, ancient";
    `speed` (float) where shipped code compares to "fast"/"slow").

    So the doc no longer refutes anything, and `doc_fields` is now audited for
    the opposite property: that it does NOT re-assert a scalar type it cannot
    source.  The underlying question is still open -- removing a bad refuter
    does not confirm the code, and a `.dem` still cannot answer it.
    """
    srcs = srcs or {}
    def src(key, path):
        return _strip_lua_comments(srcs.get(key, _read(path)))

    team_readers = []
    for key, path in (('aba', ABA_SITE), ('jmz', JMZ), ('ta', TA)):
        body = src(key, path)
        for m in re.finditer(r'camp\.team\s*[~=]=\s*GetTeam\(\)', body):
            team_readers.append((os.path.basename(path),
                                 body[:m.start()].count('\n') + 1))
    type_readers = []
    for key, path in (('aba', ABA_SITE), ('ta', TA)):
        body = src(key, path)
        for m in re.finditer(r'camp\.type\s*[~=]=\s*"(\w+)"', body):
            type_readers.append((os.path.basename(path),
                                 body[:m.start()].count('\n') + 1,
                                 m.group(1)))
    # The other two RAW fields shipped code compares against STRINGS.  They
    # are what makes the retired doc row self-contradicting rather than merely
    # wrong, so they are pinned here and not left to prose.
    speed_readers = []
    for m in re.finditer(r'camp\.cattr\.speed\s*[~=]=\s*"(\w+)"',
                         src('aba', ABA_SITE)):
        speed_readers.append(m.group(1))
    idx_readers = len(re.findall(r'camp\.idx\b', src('aba', ABA_SITE)))

    doc = srcs.get('doc')
    if doc is None:
        doc = _read(API_DOC) if os.path.exists(API_DOC) else ''
    m = re.search(r'###\s*`GetNeutralSpawners\(\)`(.*?)(?=\n###\s)', doc, re.S)
    section = m.group(1) if m else ''
    # [director 2026-09-04, trunk red] The annotation is read as the FIRST WORD
    # inside the parenthesis, and the closing `)` is deliberately NOT required.
    #
    # The old form was `\((\w+)\)` -- the whole parenthetical had to be one bare
    # word.  2026-09-04T07:45Z (strategy, GH #480) rewrote the `.type` row's
    # annotation into a sentence that wraps a line (`(unverified -- **and the
    # method that settled `.team` provably cannot settle it**)`), and the row
    # then matched NOTHING: `type` left `doc_fields` entirely.  Two consumers,
    # two different fates, and that asymmetry is the whole reason this comment
    # exists -- `set(doc_fields) >= {'team','type'}` went RED and said so, while
    # its sibling `doc_fields.get('type') != 'int'` went quietly TRUE BY
    # ABSENCE.  A refuter-detector that passes because it is looking at nothing
    # is the failure this section's own check names out loud ("if this section
    # stops parsing, the audit above is reading nothing").
    #
    # Failure direction is preserved by taking the LEADING token: an annotation
    # that re-asserts a scalar type still reads `int` as its first word, so
    # `(int, but see ...)` re-arms the refuter check exactly as `(int)` did.
    # Widening to the closing paren (`\(([^)]*)\)`) would NOT have been the same
    # fix -- a value of `'int, but see ...'` is `!= 'int'`, i.e. green.
    doc_fields = dict(re.findall(r'^-\s*`(\w+)`\s*\(\s*(\w+)', section, re.M))
    return {'team_readers': team_readers,
            'type_readers': type_readers,
            'speed_readers': speed_readers,
            'idx_readers': idx_readers,
            'doc_section': section,
            'doc_fields': doc_fields}


# --------------------------------------------------------------------------
# corpus
# --------------------------------------------------------------------------
def is_neutral(name):
    return bool(name) and name.startswith(NEUTRAL)


def cluster(points, radius=CLUSTER_R):
    """Greedy single-pass clustering; returns (cx, cy, n) per cluster."""
    cs = []
    for x, y in points:
        for c in cs:
            if math.dist((x, y), (c[0], c[1])) <= radius:
                n = c[2] + 1
                c[0] = c[0] + (x - c[0]) / n
                c[1] = c[1] + (y - c[1]) / n
                c[2] = n
                break
        else:
            cs.append([x, y, 1])
    return [tuple(c) for c in cs]


def camp_samples(tl, frames):
    """Hero positions at the instants they traded with a neutral creep."""
    pts = []
    for e in tl['events']:
        if e['type'] != 'DAMAGE':
            continue
        a, tg = e['actor'], e['target']
        if is_hero(a) and is_neutral(tg):
            h = entities.canon(a)
        elif is_neutral(a) and is_hero(tg):
            h = entities.canon(tg)
        else:
            continue
        s = entities.interp(frames.get(h, []), e["t"])
        if s:
            pts.append((s['x'], s['y']))
    return pts


def episodes(tl, frames):
    """Neutral-camp engagements: one per hero per contiguous trade run."""
    trades = defaultdict(list)
    for e in tl['events']:
        if e['type'] != 'DAMAGE':
            continue
        a, tg = e['actor'], e['target']
        if is_hero(a) and is_neutral(tg):
            trades[entities.canon(a)].append((e['t'], tg))
        elif is_neutral(a) and is_hero(tg):
            trades[entities.canon(tg)].append((e['t'], a))
    out = []
    for h, rows in trades.items():
        rows.sort()
        cur = [rows[0]]
        for r in rows[1:]:
            if r[0] - cur[-1][0] <= GAP:
                cur.append(r)
            else:
                out.append((h, cur))
                cur = [r]
        out.append((h, cur))
    eps = []
    for h, rows in out:
        s = entities.interp(frames.get(h, []), rows[0][0])
        if not s:
            continue
        eps.append({'hero': h, 't0': rows[0][0], 't1': rows[-1][0],
                    'x0': s['x'], 'y0': s['y'], 'level': s['level'],
                    'blows': len(rows),
                    'ancient': any(is_ancient(u) for _, u in rows)})
    return eps


def teleported(frames_, t0, t1, cap=MAX_WALK_SPEED):
    """True if the hero covered ground faster than any hero can walk in [t0,t1].

    Consecutive SAMPLES are compared, not interpolations of them, because an
    interpolated pair straddling the jump would hide it by averaging.
    """
    span = [f for f in frames_ if t0 <= f['t'] <= t1]
    for a, b in zip(span, span[1:]):
        dt = b['t'] - a['t']
        if dt > 0 and math.dist((a['x'], a['y']), (b['x'], b['y'])) / dt > cap:
            return True
    return False


def argmin_witness(px, py, target, camps_by_half, hero_team, penalty):
    """Was a cheaper camp available under the ARMED cost function?

    The gate's whole content is that the cost of an ENEMY camp is `penalty * d`
    while an OWN camp costs `d`; shipped, both cost `penalty * d`, so the
    argmin is the raw-nearest camp.  So the one decision the two legs can
    disagree about is exactly: the hero engaged an ENEMY camp while some OWN
    camp was strictly cheaper under the armed cost.  On a leg where the
    predicate really bites, that combination should be RARER.

    Returns None when the target half is not enemy (the pair cannot disagree
    there), else True/False.  A None is not a zero: it is excluded from the
    denominator, which is what keeps the rate a rate about this decision.
    """
    if target != 'enemy':
        return None
    own = camps_by_half.get(hero_team, [])
    ene = camps_by_half.get('enemy_of_%s' % hero_team, [])
    if not own or not ene:
        return None
    d_ene = min(math.dist((px, py), (c[0], c[1])) for c in ene)
    d_own = min(math.dist((px, py), (c[0], c[1])) for c in own)
    return d_own < penalty * d_ene


def witness_margin(px, py, target, camps_by_half, hero_team, penalty):
    """How far the witness is from flipping: d_own / (penalty * d_ene).

    Below 1.0 the witness fires.  Reported as a distribution because rule
    4(ii) says a thresholded count must expose its knife edge -- a corpus
    whose witnesses all sit at 0.99 is telling a different story from one
    whose witnesses sit at 0.4, and the RATE alone cannot tell them apart.
    """
    if target != 'enemy':
        return None
    own = camps_by_half.get(hero_team, [])
    ene = camps_by_half.get('enemy_of_%s' % hero_team, [])
    if not own or not ene:
        return None
    d_ene = min(math.dist((px, py), (c[0], c[1])) for c in ene)
    d_own = min(math.dist((px, py), (c[0], c[1])) for c in own)
    if d_ene <= 0:
        return None
    return d_own / (penalty * d_ene)


def scan(dirs, warmup=WARMUP_GAMES):
    games = []
    for d in dirs:
        for m in load_sweep(d):
            p = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            if os.path.exists(p):
                games.append((d, m, p))
            else:
                print('[warn] missing timeline %s' % p, file=sys.stderr)

    pts = []
    for _, _, p in games[:warmup]:
        tl = load(p)
        fr, _ = entities.frames_by_hero(tl)
        pts += camp_samples(tl, fr)
        del tl
    camps = [c for c in cluster(pts) if c[2] >= CAMP_SUPPORT]
    # Camp halves are a property of the MAP, so they are fixed once off the
    # first timeline that carries both ancients rather than re-derived per
    # game (a game whose ancients are missing would otherwise silently place
    # every camp as `unknown`).
    map_anc = {}
    for _, _, p in games[:warmup]:
        tl = load(p)
        for b in tl.get('buildings', []):
            if b['name'] == 'ancient':
                map_anc.setdefault(b['team'], (b['x'], b['y']))
        del tl
        if RADIANT in map_anc and DIRE in map_anc:
            break
    camps_by_half = defaultdict(list)
    camp_side = {}
    for c in camps:
        o = camp_owner(c[0], c[1], map_anc)
        if o is None:
            continue
        camp_side[(c[0], c[1])] = o
        camps_by_half[o].append(c)
    # Mirror keys so the witness can ask for "the enemy of team T" without
    # re-deriving the opposite team at every call site.
    camps_by_half['enemy_of_%s' % RADIANT] = camps_by_half[DIRE]
    camps_by_half['enemy_of_%s' % DIRE] = camps_by_half[RADIANT]

    recs = []
    ngames = {'radiant': 0, 'dire': 0}
    stats = Counter()
    pen = gate_facts()['penalty']
    for d, m, p in games:
        run_tag = os.path.basename(d.rstrip('/')).split('_')[-1]
        tl = load(p)
        teams = tl['game']['teams']
        armed_team = RADIANT if m['side'] == 'radiant' else DIRE
        ngames[m['side']] += 1
        frames, _ = entities.frames_by_hero(tl)
        ancients = {}
        for b in tl.get('buildings', []):
            if b['name'] == 'ancient':
                ancients.setdefault(b['team'], (b['x'], b['y']))
        for e in episodes(tl, frames):
            ht = teams.get('npc_dota_hero_' + e['hero'])
            if ht not in (RADIANT, DIRE):
                stats['no_team'] += 1
                continue
            r = dict(e)
            r['game'] = m['game']
            r['run'] = run_tag              # same-name cross-run collision
            r['seed'] = m.get('seed')
            r['leg'] = 'armed' if ht == armed_team else 'baseline'
            r['arm_side'] = m['side']
            # The PHYSICAL side this hero played on, which is a different
            # question from which side was armed -- rule 4(i) exists because
            # the first can be the larger effect.
            r['hero_side'] = 'radiant' if ht == RADIANT else 'dire'
            # nearest known camp centroid, so an episode that happened nowhere
            # near a camp (a jungle skirmish, a pulled creep dying in lane) can
            # be excluded from the primary rather than silently counted.
            #
            # THE HALF IS THE CAMP'S, NOT THE HERO'S.  The first version of
            # this file asked `camp_owner(hero_x, hero_y)`, and the frames
            # caught it: `ffdcb6/20260826_211631_slot6` phantom_assassin
            # t0=325.7 stands 255 u from an OWN-half camp (the one he is
            # hitting) while his own position classifies as the enemy half --
            # near the diagonal midline the hero and the camp he is standing
            # in fall on opposite sides.  The gate chooses a CAMP, so the camp
            # is what carries the side.
            if camps:
                near = min(camps, key=lambda c: math.dist(
                    (e['x0'], e['y0']), (c[0], c[1])))
                r['camp_d'] = math.dist((e['x0'], e['y0']),
                                        (near[0], near[1]))
                ct = camp_side.get((near[0], near[1]))
            else:
                r['camp_d'] = None
                ct = None
            r['half'] = ('own' if ct == ht
                         else ('enemy' if ct is not None else 'unknown'))
            r['at_camp'] = r['camp_d'] is not None and r['camp_d'] <= CLUSTER_R
            # the argmin witness, at each lead, from where the hero actually
            # stood that many seconds before his first blow
            fr_h = frames.get(e['hero'], [])
            for lead in DECIDE_LEADS:
                s = entities.interp(fr_h, e['t0'] - lead)
                tp = teleported(fr_h, e['t0'] - lead, e['t0'])
                r['tp%d' % int(lead)] = tp
                r['w%d' % int(lead)] = (
                    argmin_witness(s['x'], s['y'], r['half'], camps_by_half,
                                   ht, pen) if s and not tp else None)
                r['m%d' % int(lead)] = (
                    witness_margin(s['x'], s['y'], r['half'], camps_by_half,
                                   ht, pen) if s and not tp else None)
                if tp:
                    stats['teleport_dropped'] += 1
            stats['episodes'] += 1
            stats['at_camp'] += 1 if r['at_camp'] else 0
            stats['unknown_half'] += 1 if r['half'] == 'unknown' else 0
            recs.append(r)
        del tl
    return {'eps': recs, 'ngames': ngames, 'camps': camps, 'stats': stats,
            'games': len(games)}


# --------------------------------------------------------------------------
# reading
# --------------------------------------------------------------------------
def layered(eps, ngames, pred):
    """(ab, ba) counts and per-game rates -- iron rule 4(i), never pooled only."""
    out = {}
    for side in ('radiant', 'dire'):
        row = {}
        for leg in ('armed', 'baseline'):
            n = sum(1 for e in eps
                    if e['arm_side'] == side and e['leg'] == leg and pred(e))
            row[leg + '_n'] = n
            row[leg] = n / float(max(ngames[side], 1))
        row['delta'] = row['armed'] - row['baseline']
        out[side] = row
    out['pooled'] = {leg + '_n': sum(1 for e in eps
                                     if e['leg'] == leg and pred(e))
                     for leg in ('armed', 'baseline')}
    a, b = out['radiant']['delta'], out['dire']['delta']
    out['opposed'] = (a > 0 > b) or (a < 0 < b)
    out['one_layer_flat'] = (a == 0) != (b == 0)
    return out


def shares(eps, pred_num, pred_den):
    """Share tables -- rule 4(ii): a small-range count never gets a lone median."""
    out = {}
    for side in ('radiant', 'dire'):
        row = {}
        for leg in ('armed', 'baseline'):
            sub = [e for e in eps
                   if e['arm_side'] == side and e['leg'] == leg and pred_den(e)]
            n = sum(1 for e in sub if pred_num(e))
            row[leg + '_n'] = n
            row[leg + '_d'] = len(sub)
            row[leg] = n / float(len(sub)) if sub else 0.0
        row['delta'] = row['armed'] - row['baseline']
        out[side] = row
    a, b = out['radiant']['delta'], out['dire']['delta']
    out['opposed'] = (a > 0 > b) or (a < 0 < b)
    out['one_layer_flat'] = (a == 0) != (b == 0)
    return out


def verdict(res):
    """WORKING / BUGGY-SUSPECT / SILENT / EMPTY-DOMAIN / REFUSE.

    Ordered so that (i) an empty domain is its own answer and is never
    reported as a silence the lever caused, and (ii) two layers of OPPOSITE
    sign are tested BEFORE the pooled zero, so a side-cancellation can never
    be laundered into SILENT -- while a genuine both-layers-flat zero still
    reads SILENT (the `tbearly` lesson).
    """
    eps = [e for e in res['eps'] if e['at_camp'] and e['half'] != 'unknown']
    if not eps:
        return 'EMPTY-DOMAIN', ('no hero ever traded with a neutral creep '
                                'inside a known camp on a placeable half')
    # The verdict is taken on the ARGMIN WITNESS, not on the raw enemy-half
    # share.  The share is a superset of the gate's decisions (a hero is in
    # the enemy jungle for a hundred reasons a .dem cannot separate); the
    # witness is the shape of the one disagreement the two legs can have.
    # Both of its denominators must agree, in both strata -- a reading that
    # survives only the conditional denominator is a composition shift.
    k = 'w%d' % int(DECIDE_LEADS[len(DECIDE_LEADS) // 2])
    cond = shares(eps, lambda e: e[k] is True, lambda e: e[k] is not None)
    uncond = shares(eps, lambda e: e[k] is True, lambda e: True)
    if not any(e[k] is not None for e in eps):
        return 'EMPTY-DOMAIN', ('no enemy-half engagement with both halves of '
                               'the map carrying a known camp')
    for tab, why in ((cond, 'conditional'), (uncond, 'leg-independent')):
        if tab['opposed']:
            return 'REFUSE', ('ab and ba witness rates (%s denominator) move '
                              'in opposite directions -- iron rule 4(i) says '
                              'that is noise' % why)
    sa = cond['radiant']['delta'], cond['dire']['delta']
    sb = uncond['radiant']['delta'], uncond['dire']['delta']
    if (min(sa) < 0 < max(sb)) or (max(sa) > 0 > min(sb)):
        return 'REFUSE', ('the two denominators disagree in sign -- the '
                          'conditional reading is a composition shift')
    a = (sa[0] + sb[0]) / 2.0
    b = (sa[1] + sb[1]) / 2.0
    tab = cond
    if a == 0 and b == 0:
        return 'SILENT', ('domain is non-empty (%d camp engagements) but the '
                          'argmin witness fires at an identical rate on both '
                          'legs in both strata' % len(eps))
    # A FLAT layer is not a contradiction of a signed one -- folding zero into
    # "disagreement" would throw away every reading with one small stratum,
    # which is most of a narrow id's domain.  So it is not refused; it is
    # NAMED, so nobody reads a one-legged signal as a two-layer agreement.
    flat = (a == 0) != (b == 0)
    if a <= 0 and b <= 0:
        return ('WORKING-ONE-LAYER' if flat else 'WORKING'), (
            'armed takes the enemy camp over a cheaper own one LESS often '
            '(ab %+.3f, ba %+.3f, mean of both denominators)%s'
            % (a, b, '; only one stratum carries it' if flat else
               ' -- both strata and both denominators agree'))
    if a >= 0 and b >= 0:
        return ('BUGGY-SUSPECT-ONE-LAYER' if flat else 'BUGGY-SUSPECT'), (
            'armed takes the enemy camp over a cheaper own one MORE often '
            '(ab %+.3f, ba %+.3f, mean of both denominators)%s'
            % (a, b, '; only one stratum carries it' if flat else
               ' -- both strata and both denominators agree'))
    return 'REFUSE', 'unreachable by construction -- signs already partitioned'


def report(res):
    g = gate_facts()
    pr = premise_sites()
    print('=== source facts (read from bots/, not copied)')
    print('  gate           J.IsModeTurbo() and J.IsSoakCandidate(%r)'
          % CAND)
    print('  gate ids       %s   (must be exactly [%r])' % (g['cands'], CAND))
    print('  call sites     %d   (the wrapper is the ONLY resolution point)'
          % g['call_sites'])
    print('  penalty        x%.1f on an enemy camp' % g['penalty'])
    print('  cut-off        %.0f u (effective %.0f u shipped: every camp is '
          'penalised)' % (g['cutoff'], g['cutoff'] / g['penalty']))
    print('  ancient gate   GetLevel() >= %d' % g['ancient_level'])
    print('  operand swap   %s   preds on rec=%d  on camp=%d'
          % ('present' if g['selection'] else 'ABSENT (!)',
             g['preds_on_rec'], g['preds_on_camp']))

    print('\n=== the premise (NOT answerable from a .dem -- reported, not resolved)')
    print('  shipped readers of a RAW engine camp record:')
    for f, ln in pr['team_readers']:
        print('    %-22s :%-6d camp.team compared to GetTeam()' % (f, ln))
    for f, ln, lit in pr['type_readers']:
        print('    %-22s :%-6d camp.type compared to the STRING %r'
              % (f, ln, lit))
    print('  docs/BOT_API_REFERENCE.md says GetNeutralSpawners() returns: %s'
          % (', '.join('%s (%s)' % kv for kv in sorted(pr['doc_fields'].items()))
             or '(section not found)'))
    clash = [k for k, v in pr['doc_fields'].items()
             if k in ('team', 'type') and v == 'int']
    if clash:
        print('  ==> CONTRADICTION on %s: the code reads a string/team id, the '
              'doc says int.' % ', '.join(sorted(clash)))
        print('      If the doc is right, the armed leg is a no-op and reads '
              'back as "tested, no effect".')

    st = res['stats']
    print('\n=== corpus')
    print('  games %d   camps found %d   episodes %d   at a camp %d   '
          'half unplaceable %d'
          % (res['games'], len(res['camps']), st['episodes'], st['at_camp'],
             st['unknown_half']))
    print('  witness reads dropped because the hero TELEPORTED inside the '
          'lead: %d (over all %d leads)'
          % (st['teleport_dropped'], len(DECIDE_LEADS)))

    eps = [e for e in res['eps'] if e['at_camp'] and e['half'] != 'unknown']
    print('\n=== HALF A (primary): share of camp engagements on the ENEMY half')
    show_share(shares(eps, lambda e: e['half'] == 'enemy', lambda e: True),
               'all levels')
    for lo, hi, name in ((1, 9, 'level 1..9'), (10, 11, 'level 10..11'),
                         (12, 99, 'level >=12')):
        show_share(shares(eps, lambda e: e['half'] == 'enemy',
                          lambda e, lo=lo, hi=hi: lo <= e['level'] <= hi),
                   name)

    print('\n=== rule 4(i) arithmetic on this observable: side vs leg')
    print('    (the size of the effect the PHYSICAL side has, next to the '
          'size of\n     the effect the ARMED leg has -- pooled the other '
          'way each time)')
    for name, key, vals in (('enemy-half share', 'half', ('own', 'enemy')),):
        for label, keyfn, a_, b_ in (
                ('physical side', lambda e: e['hero_side'], 'radiant', 'dire'),
                ('armed leg    ', lambda e: e['leg'], 'armed', 'baseline')):
            ra = [e for e in eps if keyfn(e) == a_]
            rb = [e for e in eps if keyfn(e) == b_]
            fa = (sum(1 for e in ra if e[key] == vals[1]) / float(len(ra))
                  if ra else 0.0)
            fb = (sum(1 for e in rb if e[key] == vals[1]) / float(len(rb))
                  if rb else 0.0)
            print('    %-14s %-9s %.3f (n=%d)   %-9s %.3f (n=%d)   '
                  'effect %.1f pp'
                  % (label, a_, fa, len(ra), b_, fb, len(rb),
                     abs(fa - fb) * 100))

    print('\n=== HALF A (sharp): the ARGMIN WITNESS -- engaged an enemy camp')
    print('    while an own camp was strictly cheaper under the ARMED cost.')
    print('    Denominator = enemy-half engagements only; a non-enemy target')
    print('    cannot separate the two legs and is excluded, not zeroed.')
    for lead in DECIDE_LEADS:
        k = 'w%d' % int(lead)
        show_share(shares(eps, lambda e, k=k: e[k] is True,
                          lambda e, k=k: e[k] is not None),
                   'lead %.0fs' % lead)
    # The conditional rate above is conditioned on a quantity the legs may
    # themselves differ in (how often they engage an enemy camp at all), so
    # a composition shift could masquerade as a rate shift.  The same witness
    # over EVERY camp engagement cannot: its denominator is leg-independent
    # by construction.  Both are printed; a reading that only survives one of
    # them is not a reading.
    print('\n    same witness, denominator = ALL camp engagements')
    print('    (leg-independent denominator -- rules out a composition shift)')
    for lead in DECIDE_LEADS:
        k = 'w%d' % int(lead)
        show_share(shares(eps, lambda e, k=k: e[k] is True,
                          lambda e: True),
                   'lead %.0fs' % lead)

    # Rule 4(ii): expose the knife edge.  A witness that fires at ratio 0.99
    # is one step from not firing; the RATE cannot distinguish that corpus
    # from one where every witness fires by a mile.
    k = 'm%d' % int(DECIDE_LEADS[len(DECIDE_LEADS) // 2])
    print('\n    margin distribution at lead %.0fs (d_own / (%.1f * d_enemy); '
          '< 1.0 fires)' % (DECIDE_LEADS[len(DECIDE_LEADS) // 2],
                            gate_facts()['penalty']))
    for leg in ('armed', 'baseline'):
        ms = sorted(e[k] for e in eps if e.get(k) is not None
                    and e['leg'] == leg and e[k] < 1.0)
        if not ms:
            print('      %-9s no witness fired' % leg)
            continue
        near = sum(1 for m in ms if m >= 0.9)
        print('      %-9s n=%-5d mean %.3f   within 10%% of the threshold: '
              '%d (%.1f%%)'
              % (leg, len(ms), sum(ms) / len(ms), near,
                 100.0 * near / len(ms)))

    print('\n=== HALF B (control only -- campfarm is armed in the same string)')
    show(layered(eps, res['ngames'],
                 lambda e: e['ancient'] and e['level'] < g['ancient_level']),
         'ancient engagements below the selector gate (level < %d)'
         % g['ancient_level'], res['ngames'])
    show(layered(eps, res['ngames'],
                 lambda e: e['ancient'] and e['level'] >= g['ancient_level']),
         'ancient engagements at or above it (level >= %d)'
         % g['ancient_level'], res['ngames'])

    v, why = verdict(res)
    print('\n=== VERDICT  %s' % v)
    print('  %s' % why)
    return v


def show_share(tab, title):
    print('  %-16s %14s %14s %9s  %s'
          % (title, 'armed', 'baseline', 'delta', 'two-layer'))
    for side in ('radiant', 'dire'):
        r = tab[side]
        note = ''
        if side == 'dire':
            note = ('OPPOSED => NOISE (4i)' if tab['opposed']
                    else ('one layer flat' if tab['one_layer_flat']
                          else 'both layers agree'))
        print('    %-14s %4d/%-4d %.3f %4d/%-4d %.3f %+9.3f  %s'
              % ('ab' if side == 'radiant' else 'ba',
                 r['armed_n'], r['armed_d'], r['armed'],
                 r['baseline_n'], r['baseline_d'], r['baseline'],
                 r['delta'], note))


def show(tab, title, ngames):
    print('  %s' % title)
    print('    %-9s %7s %11s %11s %9s' % ('arm side', 'games', 'armed',
                                          'baseline', 'delta'))
    for side in ('radiant', 'dire'):
        r = tab[side]
        print('    %-9s %7d %4d/%.3f %4d/%.3f %+9.3f'
              % ('ab' if side == 'radiant' else 'ba', ngames[side],
                 r['armed_n'], r['armed'], r['baseline_n'], r['baseline'],
                 r['delta']))
    note = ('OPPOSED => NOISE (4i)' if tab['opposed']
            else ('one layer flat' if tab['one_layer_flat']
                  else 'both layers agree'))
    print('    %-9s %7s %11d %11d   two-layer: %s'
          % ('pooled', '-', tab['pooled']['armed_n'],
             tab['pooled']['baseline_n'], note))


# --------------------------------------------------------------------------
# selfcheck
# --------------------------------------------------------------------------
def selfcheck():
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-52s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    def raises(fn):
        try:
            fn()
        except Exception:
            return True
        return False

    # ---- source facts, on the real tree -----------------------------------
    g = gate_facts()
    chk('gate names exactly one candidate', g['cands'] == [CAND], str(g['cands']))
    chk('exactly ONE ClosestCamp resolution site', g['call_sites'] == 1,
        '= %s' % g['call_sites'])
    chk('penalty read from aba_site.lua', g['penalty'] == 1.5,
        '= %s' % g['penalty'])
    chk('cut-off read from aba_site.lua', g['cutoff'] == 15000.0,
        '= %s' % g['cutoff'])
    chk('ancient level read from aba_site.lua', g['ancient_level'] == 10,
        '= %s' % g['ancient_level'])
    chk('operand swap present', g['selection'] is True)
    chk('both predicates called on rec', g['preds_on_rec'] == 2,
        '= %s' % g['preds_on_rec'])
    chk('no predicate left on the wrapper', g['preds_on_camp'] == 0,
        '= %s' % g['preds_on_camp'])

    # ---- anti-selfskip: each source assertion must really go red ----------
    real_aba = _read(ABA_SITE)
    real_farm = _read(FARM_MODE)
    chk('ANTI-SELFSKIP penalty: 1.5->1.0 is seen',
        gate_facts(aba_src=real_aba.replace('dist * 1.5', 'dist * 1.0')
                   )['penalty'] == 1.0)
    chk('ANTI-SELFSKIP cut-off: 15000->9000 is seen',
        gate_facts(aba_src=real_aba.replace('local minDist = 15000',
                                            'local minDist = 9000')
                   )['cutoff'] == 9000.0)
    chk('ANTI-SELFSKIP level: >=10 -> >=9 is seen',
        gate_facts(aba_src=real_aba.replace('bot:GetLevel() >= 10',
                                            'bot:GetLevel() >= 9')
                   )['ancient_level'] == 9)
    chk('ANTI-SELFSKIP swap removed is seen',
        gate_facts(aba_src=real_aba.replace(
            'if bReadCampRecord and camp.cattr ~= nil then',
            'if false then'))['selection'] is False)
    chk('ANTI-SELFSKIP predicate put back on the wrapper is seen',
        gate_facts(aba_src=real_aba.replace('IsAncientCamp(rec)',
                                            'IsAncientCamp(camp)')
                   )['preds_on_camp'] == 1)
    chk('ANTI-SELFSKIP a second soak id in the gate is seen',
        gate_facts(farm_src=real_farm.replace(
            "J.IsSoakCandidate('campsel')",
            "J.IsSoakCandidate('campsel') and J.IsSoakCandidate('campfarm')")
            )['cands'] == ['campsel', 'campfarm'])
    chk('ANTI-SELFSKIP a second call site is seen',
        len(re.findall(r'J\.Site\.GetClosestNeutralSpwan\s*\(',
                       _strip_lua_comments(real_farm)
                       + '\nJ.Site.GetClosestNeutralSpwan(x, y, false)')) == 2)
    chk('a missing selector raises, never defaults',
        raises(lambda: _selector_body('-- nothing here\n')))
    chk('a missing ClosestCamp call raises, never defaults',
        raises(lambda: gate_facts(farm_src='local x = 1\n')))

    # ---- the premise audit ------------------------------------------------
    pr = premise_sites()
    chk('>=3 shipped readers compare camp.team to GetTeam()',
        len(pr['team_readers']) >= 3, str(pr['team_readers']))
    chk('>=1 shipped reader compares camp.type to a STRING',
        len(pr['type_readers']) >= 1, str(pr['type_readers']))
    chk('the API doc section is found and carries team/type',
        set(pr['doc_fields']) >= {'team', 'type'}, str(pr['doc_fields']))
    chk('ANTI-SELFSKIP the doc reader really reads the doc',
        premise_sites({'doc': '### `GetNeutralSpawners()`\n\n- `team` (str):'
                              ' x\n\n### `Next()`\n'})['doc_fields']
        == {'team': 'str'})
    chk('ANTI-SELFSKIP a removed team reader is seen',
        len(premise_sites({'jmz': 'nothing\n'})['team_readers'])
        == len(pr['team_readers']) - 1)
    # ---- the retired refuter (2026-08-27) ---------------------------------
    # `speed` and `idx` are why the old doc row is self-contradicting rather
    # than merely a wrong guess: shipped code compares `speed` to STRINGS the
    # row typed `float`, and reads an `idx` the row never listed.
    chk('shipped code compares camp.speed to strings, not a float',
        sorted(pr['speed_readers']) == ['fast', 'slow'],
        str(pr['speed_readers']))
    chk('shipped code reads a camp.idx the old doc row never listed',
        pr['idx_readers'] >= 4, str(pr['idx_readers']))
    chk('ANTI-SELFSKIP a removed speed reader is seen',
        premise_sites({'aba': 'nothing\n'})['speed_readers'] == [])
    chk('ANTI-SELFSKIP a removed idx reader is seen',
        premise_sites({'aba': 'nothing\n'})['idx_readers'] == 0)
    chk('the doc no longer types team/type as int',
        pr['doc_fields'].get('team') != 'int'
        and pr['doc_fields'].get('type') != 'int',
        str(pr['doc_fields']))
    # Exactly-once, not membership: `#241` occurs twice in that section, so
    # `'#241' in section` survives deleting either pointer (measured).
    chk('the doc section still says out loud that this is UNVERIFIED',
        pr['doc_section'].count('UNVERIFIED') == 1
        and pr['doc_section'].count('See GH #241.') == 1
        and pr['doc_section'].count('settled types (GH #241)') == 1)
    chk('ANTI-SELFSKIP the UNVERIFIED read really reads the section',
        'UNVERIFIED' not in premise_sites(
            {'doc': '### `GetNeutralSpawners()`\n\n- `team` (str): x\n'
                    '\n### `Next()`\n'})['doc_section'])

    # ---- geometry / episodes ----------------------------------------------
    cs = cluster([(0, 0), (10, 10), (5000, 0), (5010, 5)])
    chk('cluster separates two camps a map apart', len(cs) == 2, str(len(cs)))
    chk('cluster merges samples inside the radius',
        max(c[2] for c in cs) == 2)
    chk('is_neutral accepts a neutral', is_neutral('npc_dota_neutral_kobold'))
    chk('is_neutral rejects a hero',
        not is_neutral('npc_dota_hero_axe'))
    chk('is_neutral rejects a lane creep',
        not is_neutral('npc_dota_creep_badguys_melee'))
    chk('is_neutral rejects None-ish', not is_neutral(''))

    tl = {'game': {'teams': {'npc_dota_hero_axe': RADIANT}},
          'events': [
              {'t': 100.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_axe',
               'target': 'npc_dota_neutral_kobold', 'value': 40},
              {'t': 103.0, 'type': 'DAMAGE', 'actor': 'npc_dota_neutral_kobold',
               'target': 'npc_dota_hero_axe', 'value': 9},
              # a gap longer than GAP starts a second engagement
              {'t': 200.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_axe',
               'target': 'npc_dota_neutral_black_dragon', 'value': 40},
          ]}
    frames = {'axe': [{'t': 100.0, 'x': 1000.0, 'y': 200.0, 'level': 6,
                       'hp_pct': 0.9},
                      {'t': 200.0, 'x': -4600.0, 'y': 0.0, 'level': 13,
                       'hp_pct': 0.7}]}
    eps = sorted(episodes(tl, frames), key=lambda e: e['t0'])
    chk('a trade run becomes one episode', len(eps) == 2, str(len(eps)))
    chk('an episode keeps the FIRST frame (decision side)',
        eps[0]['level'] == 6 and eps[0]['x0'] == 1000.0)
    chk('creep-on-hero damage counts as the same engagement',
        eps[0]['blows'] == 2, str(eps[0]['blows']))
    chk('the ancient flag reads the units actually traded with',
        eps[1]['ancient'] is True and eps[0]['ancient'] is False)

    # ---- the teleport guard (found by reading frames, not the table) -----
    walk = [{'t': 0.0, 'x': 0.0, 'y': 0.0}, {'t': 1.0, 'x': 300.0, 'y': 0.0},
            {'t': 2.0, 'x': 600.0, 'y': 0.0}]
    tp = [{'t': 0.0, 'x': 0.0, 'y': 0.0}, {'t': 1.0, 'x': 300.0, 'y': 0.0},
          {'t': 2.0, 'x': 9000.0, 'y': 0.0}]
    chk('teleport guard passes a hero who only walked',
        teleported(walk, 0.0, 2.0) is False)
    chk('teleport guard catches a map-crossing jump',
        teleported(tp, 0.0, 2.0) is True)
    chk('teleport guard only looks inside the window it was given',
        teleported(tp, 0.0, 1.0) is False)
    chk('teleport guard compares SAMPLES, not an interpolation across the jump',
        teleported(tp, 0.0, 2.0, cap=8800.0) is False
        and teleported(tp, 0.0, 2.0, cap=8600.0) is True)

    # ---- the argmin witness ----------------------------------------------
    by_half = {RADIANT: [(-4000.0, 0.0, 9)], DIRE: [(4000.0, 0.0, 9)]}
    by_half['enemy_of_%s' % RADIANT] = by_half[DIRE]
    by_half['enemy_of_%s' % DIRE] = by_half[RADIANT]
    chk('witness is None on an own-half target (cannot separate the legs)',
        argmin_witness(0.0, 0.0, 'own', by_half, RADIANT, 1.5) is None)
    chk('witness is None when a half has no camp at all',
        argmin_witness(0.0, 0.0, 'enemy', {RADIANT: by_half[RADIANT]},
                       RADIANT, 1.5) is None)
    # hero at x=+3000: enemy(dire) camp 1000 away, own(radiant) camp 7000.
    # armed cost: own 7000 vs enemy 1500 -> enemy really is cheapest, no flag.
    chk('witness FALSE when the enemy camp is cheapest even armed',
        argmin_witness(3000.0, 0.0, 'enemy', by_half, RADIANT, 1.5) is False)
    # hero at x=0: both camps 4000 away.  armed cost own 4000 vs enemy 6000
    # -> the own camp IS cheaper, so engaging the enemy one is the witness.
    chk('witness TRUE when an own camp is cheaper under the armed cost',
        argmin_witness(0.0, 0.0, 'enemy', by_half, RADIANT, 1.5) is True)
    # hero at x=+500: own 4500 away, enemy 3500.  The enemy camp is the RAW
    # nearest (so shipped picks it), but 1.5x3500 = 5250 > 4500, so armed
    # prefers the own camp -- this is precisely the argmin flip, and it
    # vanishes the moment the penalty is 1.0.
    chk('the witness really depends on the penalty (1.0 kills the flag)',
        argmin_witness(500.0, 0.0, 'enemy', by_half, RADIANT, 1.5) is True
        and argmin_witness(500.0, 0.0, 'enemy', by_half, RADIANT, 1.0)
        is False)
    chk('the margin agrees with the witness at the boundary',
        (witness_margin(500.0, 0.0, 'enemy', by_half, RADIANT, 1.5) < 1.0)
        is argmin_witness(500.0, 0.0, 'enemy', by_half, RADIANT, 1.5)
        and (witness_margin(3000.0, 0.0, 'enemy', by_half, RADIANT, 1.5)
             >= 1.0))
    chk('the margin is None wherever the witness is None',
        witness_margin(0.0, 0.0, 'own', by_half, RADIANT, 1.5) is None)
    chk('the witness is side-symmetric (dire hero, mirrored geometry)',
        argmin_witness(0.0, 0.0, 'enemy', by_half, DIRE, 1.5) is True)

    anc = {RADIANT: (-7000.0, -6500.0), DIRE: (7000.0, 6500.0)}
    # The half must follow the CAMP, not the hero -- the frames caught this.
    # A hero standing at (x,y) whose nearest camp centroid is classified the
    # other way must be counted with the camp.
    _anc = {RADIANT: (-7000.0, -6500.0), DIRE: (7000.0, 6500.0)}
    chk('a hero and the camp he is standing in CAN classify differently '
        '(the reason `half` follows the camp)',
        camp_owner(500.0, -500.0, _anc) != camp_owner(-500.0, 500.0, _anc))

    chk('camp_owner puts a radiant-side camp on radiant',
        camp_owner(-4000.0, -1000.0, anc) == RADIANT)
    chk('camp_owner puts a dire-side camp on dire',
        camp_owner(4000.0, 1000.0, anc) == DIRE)
    chk('camp_owner refuses without both ancients',
        camp_owner(0.0, 0.0, {RADIANT: (0, 0)}) is None)

    # ---- the reading ------------------------------------------------------
    def ep(side, leg, half, level=8, ancient=False, at_camp=True, w=None):
        r = {'arm_side': side, 'leg': leg, 'half': half, 'level': level,
             'ancient': ancient, 'at_camp': at_camp}
        for lead in DECIDE_LEADS:
            r['w%d' % int(lead)] = w
        return r

    ng = {'radiant': 1, 'dire': 1}
    t = shares([ep('radiant', 'armed', 'own'),
                ep('radiant', 'baseline', 'enemy')],
               lambda e: e['half'] == 'enemy', lambda e: True)
    chk('share table reads a one-sided corpus',
        t['radiant']['armed'] == 0.0 and t['radiant']['baseline'] == 1.0)
    chk('rule 4(i): opposite layers are flagged opposed',
        shares([ep('radiant', 'armed', 'enemy'),
                ep('radiant', 'baseline', 'own'),
                ep('dire', 'armed', 'own'),
                ep('dire', 'baseline', 'enemy')],
               lambda e: e['half'] == 'enemy', lambda e: True)['opposed'])
    chk('a flat layer is NOT called opposed',
        not shares([ep('radiant', 'armed', 'own'),
                    ep('radiant', 'baseline', 'own'),
                    ep('dire', 'armed', 'own'),
                    ep('dire', 'baseline', 'enemy')],
                   lambda e: e['half'] == 'enemy',
                   lambda e: True)['opposed'])
    chk('layered() counts per stratum and pools',
        layered([ep('radiant', 'armed', 'own', ancient=True),
                 ep('dire', 'baseline', 'own', ancient=True)],
                ng, lambda e: e['ancient'])['pooled']
        == {'armed_n': 1, 'baseline_n': 1})

    # verdict, all six worlds, ORDER pinned
    def V(eps_):
        return verdict({'eps': eps_, 'ngames': ng, 'camps': [], 'stats': Counter(),
                        'games': 0})[0]
    # The verdict rides the WITNESS, so `w` is what these worlds vary.  A
    # `w=None` episode is a non-enemy target: it must stay in the
    # leg-independent denominator and out of the conditional one.
    def W(side, leg, w):
        return ep(side, leg, 'enemy' if w is not None else 'own', w=w)

    chk('verdict EMPTY-DOMAIN on no placeable engagement',
        V([ep('radiant', 'armed', 'unknown')]) == 'EMPTY-DOMAIN')
    chk('verdict EMPTY-DOMAIN also when nothing is at a camp',
        V([ep('radiant', 'armed', 'own', at_camp=False)]) == 'EMPTY-DOMAIN')
    chk('verdict EMPTY-DOMAIN when no episode has a witness at all',
        V([ep('radiant', 'armed', 'own'), ep('dire', 'baseline', 'own')])
        == 'EMPTY-DOMAIN')
    chk('verdict SILENT when both strata are genuinely flat',
        V([W('radiant', 'armed', True), W('radiant', 'baseline', True),
           W('dire', 'armed', True), W('dire', 'baseline', True)])
        == 'SILENT')
    chk('verdict WORKING when armed takes the cheaper-own bait less often',
        V([W('radiant', 'armed', False), W('radiant', 'baseline', True),
           W('dire', 'armed', False), W('dire', 'baseline', True)])
        == 'WORKING')
    chk('verdict BUGGY-SUSPECT when armed takes it MORE often',
        V([W('radiant', 'armed', True), W('radiant', 'baseline', False),
           W('dire', 'armed', True), W('dire', 'baseline', False)])
        == 'BUGGY-SUSPECT')
    chk('ORDER: a side cancellation reads REFUSE, never SILENT',
        V([W('radiant', 'armed', True), W('radiant', 'baseline', False),
           W('dire', 'armed', False), W('dire', 'baseline', True)])
        == 'REFUSE')
    # A flat layer is NOT refused (it is not a contradiction) but it must never
    # be reported as a two-layer agreement either -- so it gets its own name.
    chk('ORDER: one flat layer + one signed is NAMED, not laundered',
        V([W('radiant', 'armed', True), W('radiant', 'baseline', True),
           W('dire', 'armed', False), W('dire', 'baseline', True)])
        == 'WORKING-ONE-LAYER')
    chk('ORDER: a flat layer on the BUGGY side is named too',
        V([W('radiant', 'armed', True), W('radiant', 'baseline', True),
           W('dire', 'armed', True), W('dire', 'baseline', False)])
        == 'BUGGY-SUSPECT-ONE-LAYER')
    # THE COMPOSITION GUARD.  Both legs fire the witness on every enemy-half
    # engagement they have, so the conditional rate is flat -- but the armed
    # leg has FEWER such engagements, so the leg-independent rate falls.  A
    # file that read only the conditional table would call this SILENT.
    chk('a pure composition shift is NOT laundered into SILENT',
        V([W('radiant', 'armed', True), ep('radiant', 'armed', 'own'),
           W('radiant', 'baseline', True), W('radiant', 'baseline', True),
           W('dire', 'armed', True), ep('dire', 'armed', 'own'),
           W('dire', 'baseline', True), W('dire', 'baseline', True)])
        != 'SILENT')

    print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
    return 0 if ok else 1


def frames(dirs, want, lead=20.0, limit=6, per_game=2):
    """Frame-by-frame for the episodes the witness fired on (hard rule: frames
    before aggregates).  Prints one hero's own trajectory from `lead` seconds
    before his first blow, with BOTH cost functions evaluated at every second,
    so the disagreement between the legs is visible as numbers rather than
    asserted as a rate."""
    pen = gate_facts()['penalty']
    shown = 0
    for d in dirs:
        if shown >= limit:
            break
        for m in load_sweep(d):
            if shown >= limit:
                break
            p = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            if not os.path.exists(p):
                continue
            tl = load(p)
            teams = tl['game']['teams']
            armed_team = RADIANT if m['side'] == 'radiant' else DIRE
            fr, _ = entities.frames_by_hero(tl)
            anc = {}
            for b in tl.get('buildings', []):
                if b['name'] == 'ancient':
                    anc.setdefault(b['team'], (b['x'], b['y']))
            in_this_game = 0
            pts = camp_samples(tl, fr)
            camps = [c for c in cluster(pts) if c[2] >= CAMP_SUPPORT]
            by_half = defaultdict(list)
            for c in camps:
                o = camp_owner(c[0], c[1], anc)
                if o is not None:
                    by_half[o].append(c)
            by_half['enemy_of_%s' % RADIANT] = by_half[DIRE]
            by_half['enemy_of_%s' % DIRE] = by_half[RADIANT]
            for e in episodes(tl, fr):
                if shown >= limit or in_this_game >= per_game:
                    break
                ht = teams.get('npc_dota_hero_' + e['hero'])
                if ht not in (RADIANT, DIRE):
                    continue
                leg = 'armed' if ht == armed_team else 'baseline'
                if leg != want:
                    continue
                near = min(camps, key=lambda c: math.dist(
                    (e['x0'], e['y0']), (c[0], c[1]))) if camps else None
                ct = (camp_owner(near[0], near[1], anc) if near else None)
                if ct is None:
                    continue
                half = 'own' if ct == ht else 'enemy'
                s = entities.interp(fr.get(e['hero'], []), e['t0'] - lead)
                if (not s
                        or teleported(fr.get(e['hero'], []), e['t0'] - lead,
                                      e['t0'])
                        or argmin_witness(s['x'], s['y'], half, by_half, ht,
                                          pen) is not True):
                    continue
                shown += 1
                in_this_game += 1
                print('\n--- %s / %s  seed %s  %s (%s, team %s)  L%d  t0=%.1f'
                      % (os.path.basename(d.rstrip('/')).split('_')[-1],
                         m['game'], m.get('seed'), e['hero'], leg, ht,
                         e['level'], e['t0']))
                print('    %7s %9s %9s %9s %9s %9s'
                      % ('t', 'x', 'y', 'd_own', 'd_ene', 'armed picks'))
                t = e['t0'] - lead
                while t <= e['t1'] + 0.001:
                    f = entities.interp(fr.get(e['hero'], []), t)
                    if f:
                        do = min(math.dist((f['x'], f['y']), (c[0], c[1]))
                                 for c in by_half[ht])
                        de = min(math.dist((f['x'], f['y']), (c[0], c[1]))
                                 for c in by_half['enemy_of_%s' % ht])
                        print('    %7.1f %9.0f %9.0f %9.0f %9.0f %9s'
                              % (t, f['x'], f['y'], do, de,
                                 'own' if do < pen * de else 'enemy'))
                    t += 5.0
                print('    shipped cost ranks by raw distance (every camp is '
                      'x%.1f), armed penalises only the enemy half' % pen)
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dirs', nargs='*')
    ap.add_argument('--out')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--source', action='store_true',
                    help='print the source facts + premise audit; no corpus')
    ap.add_argument('--frames', choices=('armed', 'baseline'),
                    help='frame-by-frame for episodes the witness fired on')
    ap.add_argument('--limit', type=int, default=6)
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if a.source:
        g = gate_facts()
        pr = premise_sites()
        print(json.dumps({'gate': g, 'premise': pr}, indent=2, default=list))
        return 0
    if not a.dirs:
        return selfcheck()
    if a.frames:
        return frames(a.dirs, a.frames, limit=a.limit)
    res = scan(a.dirs)
    report(res)
    if a.out:
        with open(a.out, 'w') as fh:
            for r in res['eps']:
                fh.write(json.dumps(r) + '\n')
        print('\nwrote %s (%d rows)' % (a.out, len(res['eps'])))
    return 0


if __name__ == '__main__':
    sys.exit(main())
