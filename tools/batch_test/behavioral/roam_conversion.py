#!/usr/bin/env python3
"""Lane-kill opportunity scanner + action-object (creep-vs-hero) diff.

Rebuilds, from dumper timelines, the two frame-level measurements the director
pre-registered for the `roamstale` bisect (test_set.md section G.3):

  1. in-domain kill conversion -- the replay-check #41 metric: during the
     laning phase, when a <=40% HP enemy hero stands within 800u of a bot that
     has an ally nearby, does that enemy die within 6s?
  2. the action-object split -- inside the same episodes, does the bot's own
     damage in the next 4s land on the ENEMY HERO or on a CREEP?  The
     `roamstale` defect (GH #39/#41) is that Think() attacks LAST frame's
     last-hit creep whenever an early collapse branch wins the auction, so the
     stale-handle signature is "episode open, bot damages creeps only".

Plus the out-of-domain control window (t 520-900s) where both lane-kill
helpers hard `return nil`, so any candidate-vs-baseline gap there is NOT
attributable to these branches.

Usage:
    roam_conversion.py <sweep_out_dir> [<sweep_out_dir> ...]
    roam_conversion.py --allow-unattributed <dir> [...]

Each sweep_out_dir is a directory produced by sweep_run.sh (it must contain
timelines/ and analysis/).  Read-only; no AWS, no billable resource.

WHAT THIS TABLE IS, AND WHAT IT IS NOT (director ruling 2026-08-21, test_set.md
section AG, GH #94).  The armed-vs-baseline columns below are ONE LEG of a
two-arm bisect, not an estimator.  In a mirrored wave the two sides play EACH
OTHER, so a within-arm candidate-minus-baseline delta moves for two reasons at
once and is negatively coupled with itself; the isolated estimator is the
two-arm ARMED A-B (candidate side vs candidate side, seed-paired), because both
candidate sides face opponents whose CODE is identical.  Differencing two of
these tables into a DiD is banned: it subtracts a baseline leg that is not a
control (there is no arm-level nuisance to remove -- same tree, same seeds,
same drafts) and can only add variance, and it is how `roamstale`'s registered
+22.9pp came to be ~63% baseline-leg.  Use roamstale_null_channel.py, which
prints ARMED A-B next to the baseline-leg contrast it would have subtracted.

Because the table is a leg, it is meaningless until you know WHICH ARM it came
from, and this script pools every directory it is given into one `armed` cell.
Hand it both arms and it averages a treated and an untreated candidate side
into a single number that looks exactly like a normal measurement.  So the
candidate id string is read out of each run's games_manifest.jsonl and the run
aborts (exit 2) if the directories disagree or if the manifest is missing.
`--allow-unattributed` is the deliberate escape hatch; it stamps the output
UNATTRIBUTED rather than quietly guessing an arm.
"""
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "soak"))
import seed_draft  # noqa: E402  -- the only correct source of a hero's position

LANING_END = 480.0        # turbo hard floor of J.IsInLaningPhase()
OUT_START, OUT_END = 520.0, 900.0

# THE LETHALITY PROXY -- defined HERE, once, and imported by every consumer.
#
# test_set.md AJ.5 found this number written out four separate times across
# behavioral/, each site unaware of the others, after `#92` had already flipped
# the SIGN of one of the readings that leaned on it.  The most consequential
# copy was in `find_kill_windows.py`, which does not produce a reading at all --
# it SELECTS WHICH FRAMES BECOME FIXTURES, so the whole execution-verification
# sampling surface grows on it.
#
# HONEST PROVENANCE (the `#90` registry's whole point is that this line cannot
# be reconstructed by a reader, so it is stated rather than implied):
#
#   THIS CONSTANT MIRRORS NO SHIPPED LITERAL.  There is no `0.4` in the lane-kill
#   helpers that means "the victim is killable".  The shipped gate asks
#   `GetEstimatedDamageToTarget(...) >= victim HP + 4s regen`, an ABSOLUTE-health
#   comparison against our castable burst, and that call is not in the dumper
#   stream.  0.40 is a stand-in for an unobservable predicate, so every episode
#   any consumer yields is a SUPERSET of the frames the gate really fired on.
#
#   The nearest thing to a source is arithmetic, not a literal: the armed bid
#   RemapValClamped(HP, 0, 0.5, NONE, 0.92) = min(0.92, 1.84*HP) only beats the
#   0.75 fallback it preempts above HP > 0.75/1.84 = 0.4076.  That is about the
#   ACTOR's HP, not the victim's -- it is `lanekill_commit.BID_FLOOR_HIGH`, a
#   different quantity that merely lands near the same number.  Do not fuse them.
#
#   test_set.md AJ.5 recorded the site as `jmz_func.lua:6932`.  Re-checked
#   2026-08-22T21:0xZ while converging the copies: line 6932 is inside
#   `J.ShouldBodyBlockHarass`, an 800u enemy scan in an unrelated helper.  The
#   pointer was wrong when it was written, which is the exact rot the registry
#   exists to catch -- and why a prose pointer is not a registration.
#
# DO NOT redefine 0.40 in a consumer.  `tests/test_detector_source_constants.py`
# section 2b censuses every module-level HP constant in this directory and goes
# red on an unregistered one.
VICTIM_HP_PROXY = 0.40
VICTIM_HP = VICTIM_HP_PROXY   # legacy name; archived readings cite it verbatim
VICTIM_RANGE = 800.0
ALLY_RANGE = 1200.0
DEDUP_S = 6.0
CONVERT_S = 6.0
ACTION_S = 4.0
# Snapshots are 1Hz and LAG the event stream: a victim can already be dead in
# the DEATH events while the next snapshot still shows it at 4% HP (real case:
# 20260819_182941_slot1, PA dies t=465.1, snapshot t=465.4 says hp_pct 0.04).
# Both the kill window and the action window therefore reach LAG_S back, or a
# kill that the episode's own frame provoked is scored as a non-conversion.
LAG_S = 1.0


def dist(a, b):
    return math.hypot(a['x'] - b['x'], a['y'] - b['y'])


def paused_spans(tl, frames):
    """Same definition as detect.py's _paused_spans: an event gap >=3s during
    which every hero's snapshot position is frozen.  Window detectors MUST skip
    these -- an armed-side 24s 'stall' in 20260819_183042_slot1 (earthshaker
    next to a 14% slardar) turned out to be the frozen post-game segment, with
    every entity's x/y and hp identical for 24 straight frames."""
    per_hero = collections.defaultdict(list)
    for t, snaps in frames.items():
        for s in snaps:
            per_hero[s['hero']].append((t, s['x'], s['y']))
    spans, ts = [], [e['t'] for e in tl['events']]
    for a, b in zip(ts, ts[1:]):
        if b - a < 3.0:
            continue
        frozen, sampled = True, False
        for pts in per_hero.values():
            xs = {(x, y) for (t, x, y) in pts if a < t < b}
            if len(xs) >= 2:
                frozen = False
                break
            if xs:
                sampled = True
        if frozen and sampled:
            spans.append((a, b))
    return spans


def canon_hero(name):
    """Join key for the snapshot side and the event side of a timeline.

    `[harness] GH #82`: the dumper derives a snapshot's hero name from the
    ENTITY CLASS (`dumper/main.go:180 classToNPC`, which splits camelCase into
    underscores), while events carry the COMBAT LOG name.  For most heroes the
    two agree -- CDOTA_Unit_Hero_WitchDoctor -> witch_doctor is right -- but
    where the engine's own npc name has NO underscore the derivation invents
    one, and the join silently misses:

        snapshots: npc_dota_hero_queen_of_pain    events: ...queenofpain
        snapshots: npc_dota_hero_vengeful_spirit  events: ...vengefulspirit

    (The event side is the correct one; `mode_farm_generic.lua:872` and
    `ts_libs/dota/heroes.lua:87` both spell it `npc_dota_hero_queenofpain`.)
    Measured on the 19-game 20260819_22xx corpus: both heroes appear in 5
    games each, and in every one of them `death_spans()` produced NO span at
    all -- i.e. the criterion this module exists to provide reported them
    ALIVE THROUGH EVERY DEATH, 196 corpse frames' worth in the 9 OD games.
    That is the #78 failure mode with the bound removed: not one leaked frame
    per death but the whole span.

    Collapsing underscores is the join, not a rename: callers keep passing
    whatever name they hold and both spellings land on the same key."""
    return name.replace("_", "") if name else name


def death_spans(tl, real_idx):
    """hero -> [(t_death, t_respawn)] built from DEATH EVENTS, not from hp_pct.

    Keyed by `canon_hero()`; `is_dead()` looks up the same way, so a caller
    holding either spelling gets the right answer (GH #82).

    `[bug] #78`: every detector in this directory used `hp_pct > 0` as its
    liveness test.  That is a PROXY, and the whole point of #78 is that a proxy
    has to be checked on the class of events it exists to catch.  Measured here
    on the 32-game 1609xx/1807xx corpus (182 deaths, 4033 corpse frames):

      * 3880/4033 corpse frames DO read hp_pct == 0 exactly -- so on this
        corpus the proxy is right 96.2% of the time, not "systematically
        wrong";
      * the leak is bounded and one-sided in TIME: 153 frames, 34/182 deaths,
        and in every observed case it is the FIRST snapshot at or after the
        DEATH event (<=0.3s later) still carrying the last LIVE sample -- the
        1Hz lag this module's LAG_S comment already described, seen from the
        other side.

      * ITS VALUE RANGE IS NOT BOUNDED BY 0.40.  This docstring used to read
        "leaked values observed: 0.005 .. 0.29, i.e. ALL of them land inside a
        `hp_pct <= 0.40` victim band".  Re-measured 2026-08-21T06:3xZ over the
        whole 1609xx/1807xx corpus (940 spans, 19207 corpse frames, 235 leaks):
        the RATE reproduces (0.250 leak frames/death; max lag 0.30s) but the
        range does not.  Strictly after DEATH: p95 0.241, p99 0.370, max 0.386.
        At lag == 0.0 (snapshot stamped at the DEATH tick, which `is_dead()`
        counts as dead): max 0.517, with 0.437 landing inside capmono's actor
        band [0.42,0.50].  Both >0.42 frames are Lion's Finger of Death kills.

    So the proxy does not fail "everywhere", and where it fails it fails INSIDE
    a low-HP band for most victims -- but "most" is not "all", and a one-cast
    nuke puts the leak wherever the victim's HP was.  Do not re-derive a
    detector's safety from that band.  Hence
    this helper: a hero is dead from its DEATH event until it respawns, and
    respawn is detected by the fountain teleport (hp back above 0.5 AND a
    >1500u jump), never by hp alone.
    """
    per = collections.defaultdict(list)
    for s in tl['snapshots']:
        if real_idx.get(s['hero']) == s['idx']:
            per[canon_hero(s['hero'])].append(s)
    for h in per:
        per[h].sort(key=lambda s: s['t'])

    spans = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] != 'DEATH' or not e.get('target_hero'):
            continue
        h, td = canon_hero(e['target']), e['t']
        if spans[h] and spans[h][-1][1] > td:
            continue                      # already inside a known death span
        snaps = per.get(h) or []
        loc = next(((s['x'], s['y']) for s in reversed(snaps) if s['t'] <= td), None)
        tr = float('inf')
        for s in snaps:
            if s['t'] <= td or s['hp_pct'] <= 0.5:
                continue
            jumped = loc is None or math.hypot(s['x'] - loc[0], s['y'] - loc[1]) > 1500.0
            # Fountain respawn teleports; REINCARNATION DOES NOT.  Wraith King
            # (skeleton_king -- a focus hero) revives on the spot after ~3s:
            # measured 20260820_181721_slot1, DEATH t=380.9, hp 0.000 for
            # 381.5-383.5, then hp=1.000 at t=384.5 forty-eight units away.
            # A jump-only respawn test leaves him "dead" for the next 28s and
            # silently deletes real frames (he fights at 0.3% HP through
            # t=395).  So accept a no-jump revival too, but only after 1.5s --
            # the hp_pct leak this helper exists to catch is ALWAYS the single
            # snapshot within 0.3s of the DEATH event (measured max 0.30s over
            # 700 spans), so the guard separates the two cases with margin.
            if jumped or s['t'] - td >= 1.5:
                tr = s['t']
                break
        spans[h].append((td, tr))
    return spans


def is_dead(spans, hero, t):
    """True if `hero` is inside a death span at time t.  The window opens at the
    DEATH event itself: the leaked frames are all AFTER it.

    `hero` may be spelled either way -- see `canon_hero()` / GH #82."""
    return any(a <= t < b for a, b in spans.get(canon_hero(hero), ()))


def load_game(tl_path, aj_path):
    tl = json.load(open(tl_path))
    aj = json.load(open(aj_path))
    sv = aj.get('script_version', '')
    if not sv.startswith('mirror:'):
        return None
    armed_side = sv.rsplit(':', 1)[-1]           # radiant | dire
    armed_team = 2 if armed_side == 'radiant' else 3
    # Position comes from the SEED's draft.  The old `team_slot % 5 + 1` here was
    # wrong: `X.ShufflePickOrder` permutes pick slots every game with the engine's
    # unseeded RandomInt while the (hero, role, lane) triple travels together, so
    # the slot carries per-game entropy and the hero keeps its drafted role.  On
    # 291 mirror games the slot label agreed with the drafted one on 47.3% of rows
    # and explained eta^2 = 0.174 of last-hit variance against 0.482 (GH #57).
    # A game we cannot attribute is dropped, not guessed.
    pos = seed_draft.positions_for_game(aj)
    if pos is None:
        return None

    # Illusions are emitted as separate entities under the SAME class name
    # (a Chaos Knight Phantasm shows up as six npc_dota_hero_chaos_knight rows
    # in one frame).  Counting them multiplies episodes and fakes geometry, so
    # lock each hero to its real entity: the idx present for the whole game.
    # (Charter tool-trap: "lock idx before tracking a single unit".)
    seen = collections.Counter((s['hero'], s['idx']) for s in tl['snapshots'])
    real = {}
    for (h, i), n in seen.items():
        if h not in real or n > real[h][1]:
            real[h] = (i, n)
    real_idx = {h: v[0] for h, v in real.items()}

    # The dumper keeps emitting snapshots for ~25s AFTER the game ends (every
    # one of the 13 games in the 1808xx wave has a 24-25s frozen tail, 4303
    # rows total).  detect.py's _paused_spans cannot see it -- that definition
    # needs an event PAIR bracketing the freeze, and the tail has no trailing
    # event -- so window detectors read frozen post-game state as behavior.
    # Cut everything past the last event.
    t_end = max(e['t'] for e in tl['events'])

    frames = collections.defaultdict(list)
    n_illusion = 0
    for s in tl['snapshots']:
        if real_idx.get(s['hero']) != s['idx']:
            n_illusion += 1
            continue
        if s['t'] > t_end:
            continue
        frames[round(s['t'], 1)].append(s)
    return {
        'tl': tl, 'frames': frames, 'pos': pos, 'n_illusion': n_illusion,
        'armed_team': armed_team, 'armed_side': armed_side,
        'pauses': paused_spans(tl, frames),
        # [bug] #78: event-based liveness, for callers that select on a low-HP
        # band (where the hp_pct proxy's leak lives entirely).  Existing
        # callers keep their own hp_pct test until each is re-read on corpus.
        'dead': death_spans(tl, real_idx),
    }


def scan(g, t_lo, t_hi):
    """Yield opportunity episodes in [t_lo, t_hi)."""
    frames, pos = g['frames'], g['pos']
    deaths = collections.defaultdict(list)
    dmg = collections.defaultdict(list)
    for e in g['tl']['events']:
        if e['type'] == 'DEATH' and e.get('target_hero'):
            deaths[e['target']].append(e['t'])
        elif e['type'] == 'DAMAGE' and e.get('actor_hero'):
            dmg[e['actor']].append((e['t'], bool(e.get('target_hero')), e['target']))

    pauses = g['pauses']
    last = {}
    for t in sorted(frames):
        if not (t_lo <= t < t_hi):
            continue
        if any(not (t + ACTION_S < a or t - LAG_S > b) for a, b in pauses):
            continue
        snaps = frames[t]
        alive = [s for s in snaps if s.get('hp_pct', 0) > 0]   # drop corpse frames
        for actor in alive:
            for victim in alive:
                if victim['team'] == actor['team']:
                    continue
                if victim['hp_pct'] > VICTIM_HP:
                    continue
                if dist(actor, victim) > VICTIM_RANGE:
                    continue
                if not any(a is not actor and a['team'] == actor['team']
                           and dist(actor, a) <= ALLY_RANGE for a in alive):
                    continue
                key = (actor['hero'], actor['idx'], victim['hero'], victim['idx'])
                if key in last and t - last[key] < DEDUP_S:
                    continue
                last[key] = t
                killed = any(t - LAG_S < d <= t + CONVERT_S for d in deaths[victim['hero']])
                hits = [(ht, ish) for ht, ish, _ in dmg[actor['hero']]
                        if t - LAG_S < ht <= t + ACTION_S]
                yield {
                    't': t,
                    'actor': actor['hero'], 'victim': victim['hero'],
                    'actor_team': actor['team'],
                    'armed': actor['team'] == g['armed_team'],
                    'pos': pos.get(actor['hero'], 0),
                    'actor_hp': actor['hp_pct'], 'victim_hp': victim['hp_pct'],
                    'edist': round(dist(actor, victim)),
                    'killed': killed,
                    'hit_hero': any(ish for _, ish in hits),
                    'hit_creep': any(not ish for _, ish in hits),
                    'no_dmg': not hits,
                }


def pct(n, d):
    return f'{100.0*n/d:5.1f}% ({n}/{d})' if d else '   n/a'


ARM_BANNER = (
    'NOTE: armed-vs-baseline below is ONE LEG of a bisect, not an estimator.\n'
    '      The isolated contrast is two-arm ARMED A-B (roamstale_null_channel.py).\n'
    '      Do not difference two of these tables into a DiD -- test_set.md AG.')


def arm_identity(dirs):
    """-> (id_set_per_dir, dirs_without_manifest).

    The candidate id string is read out of each run's games_manifest.jsonl.  It
    is READ, never inferred from the directory name: the name is a label a human
    typed, the stamp is what the instance actually armed.
    """
    per_dir, missing = {}, []
    for d in dirs:
        path = os.path.join(d, 'games_manifest.jsonl')
        if not os.path.exists(path):
            missing.append(d)
            continue
        ids = set()
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                cand = json.loads(line).get('cand') or ''
                ids |= {p for p in cand.split(',') if p}
        per_dir[d] = ids
    return per_dir, missing


def check_single_arm(dirs, allow_unattributed=False):
    """Abort unless every directory carries the same candidate id set.

    Returns the shared id set (or None when running UNATTRIBUTED).
    """
    per_dir, missing = arm_identity(dirs)
    if missing:
        if not allow_unattributed:
            print('!! no games_manifest.jsonl in: %s\n'
                  '   This table is one leg of a bisect and cannot be attributed to\n'
                  '   an arm without the stamp.  Re-run sweep_run.sh so the manifest\n'
                  '   is written, or pass --allow-unattributed to say so out loud.'
                  % ', '.join(sorted(missing)), file=sys.stderr)
            sys.exit(2)
        print('ARM: UNATTRIBUTED (no manifest for %d dir(s)) -- this table names no arm'
              % len(missing))
        return None
    sets = list(per_dir.values())
    if not sets:
        if allow_unattributed:
            print('ARM: UNATTRIBUTED (no directories carried a manifest)')
            return None
        print('!! no directories carried a games_manifest.jsonl', file=sys.stderr)
        sys.exit(2)
    first = sets[0]
    for d, ids in per_dir.items():
        if ids != first:
            only_a, only_b = sorted(first - ids), sorted(ids - first)
            print('!! the directories are not one arm: %s vs %s differ by\n'
                  '   %s\n'
                  '   Pooling them averages a treated and an untreated candidate side\n'
                  '   into one cell that looks like a normal measurement.  Run each arm\n'
                  '   separately, or use roamstale_null_channel.py --arm-a/--arm-b.'
                  % (sorted(per_dir)[0], d,
                     ' / '.join(filter(None, [
                         ('only in the first: ' + ', '.join(only_a)) if only_a else '',
                         ('only in %s: ' % d) + ', '.join(only_b) if only_b else ''])) or
                     '(nothing -- sets differ but the diff is empty?)'),
                  file=sys.stderr)
            sys.exit(2)
    print('ARM: %d ids armed in every stamp [%s]'
          % (len(first), ','.join(sorted(first)) if first else '(none)'))
    return first


def main():
    argv = sys.argv[1:]
    allow_unattributed = '--allow-unattributed' in argv
    dirs = [a for a in argv if not a.startswith('--')]
    if not dirs:
        print(__doc__)
        return 1
    check_single_arm(dirs, allow_unattributed)
    print(ARM_BANNER)
    print()
    buckets = {'in': collections.defaultdict(list), 'out': collections.defaultdict(list)}
    games = 0
    for d in dirs:
        for tl in sorted(glob.glob(os.path.join(d, 'timelines', '*.timeline.json'))):
            name = os.path.basename(tl).replace('.timeline.json', '')
            aj = os.path.join(d, 'analysis', name + '.analysis.json')
            if not os.path.exists(aj):
                continue
            g = load_game(tl, aj)
            if g is None:
                continue
            games += 1
            for win, (lo, hi) in (('in', (0.0, LANING_END)),
                                  ('out', (OUT_START, OUT_END))):
                for ep in scan(g, lo, hi):
                    ep['game'] = name
                    buckets[win]['armed' if ep['armed'] else 'base'].append(ep)

    print(f'games scanned: {games}\n')
    for win, label in (('in', f'IN-DOMAIN  (laning, t<{LANING_END:.0f}s)'),
                       ('out', f'OUT-DOMAIN (t {OUT_START:.0f}-{OUT_END:.0f}s, helpers return nil)')):
        print(f'== {label} ==')
        print(f'{"":18} {"armed":>18} {"baseline":>18}')
        a, b = buckets[win]['armed'], buckets[win]['base']
        rows = [
            ('episodes', len(a), len(b)),
            ('killed<=6s', sum(x['killed'] for x in a), sum(x['killed'] for x in b)),
            ('hit the hero<=4s', sum(x['hit_hero'] for x in a), sum(x['hit_hero'] for x in b)),
            ('CREEP-ONLY<=4s', sum(x['hit_creep'] and not x['hit_hero'] for x in a),
                               sum(x['hit_creep'] and not x['hit_hero'] for x in b)),
            ('no damage<=4s', sum(x['no_dmg'] for x in a), sum(x['no_dmg'] for x in b)),
        ]
        na, nb = len(a), len(b)
        for lab, va, vb in rows:
            if lab == 'episodes':
                print(f'{lab:18} {va:>18} {vb:>18}')
            else:
                print(f'{lab:18} {pct(va, na):>18} {pct(vb, nb):>18}')
        print()
    # dump episodes for frame-level follow-up
    with open('/tmp/roam_episodes.jsonl', 'w') as fh:
        for win in buckets:
            for side in buckets[win]:
                for ep in buckets[win][side]:
                    ep['window'] = win
                    fh.write(json.dumps(ep) + '\n')
    print('episodes -> /tmp/roam_episodes.jsonl')
    return 0


if __name__ == '__main__':
    sys.exit(main())
