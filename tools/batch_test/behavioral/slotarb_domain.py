#!/usr/bin/env python3
"""(a)-verification for soak candidate `slotarb` (GH #406).

WHAT `slotarb` DOES
-------------------
`bots/FunLib/aba_site.lua`'s `IsTheClosestOne(bot, loc, bSlotArb)` answers "am I
the teammate closest to this camp".  It walks `GetTeamPlayers(GetTeam())`, which
hands back PLAYER IDS (0-4 radiant / 5-9 dire), and feeds each one to
`GetTeamMember`, whose argument is a team SLOT (1..5).  Out of range the engine
answers nil, so the SHIPPED scan silently walks a SUBSET of the roster:

    radiant  ids 0..4 -> GetTeamMember(0) is nil; 1..4 are slots 1..4
             => the hero in team slot 5 (pid 4) is NEVER looked at
    dire     ids 5..9 -> only GetTeamMember(5) exists
             => only team slot 5 (pid 9) is EVER looked at

Armed (`nSlot = i`) the scan is the whole roster.  `closestMember` is seeded
with `bot` itself, so the armed TRUE set is a strict SUBSET of the shipped one:
**armed can only REFUSE a camp shipped accepted, never the reverse.**  Resolved
in exactly one place, the `ClosestCamp` wrapper in `bots/mode_farm_generic.lua`,
which passes it as the 4th argument of `J.Site.GetClosestNeutralSpwan` (the 3rd
is `campsel`, an INDEPENDENT candidate armed in the same string -- GH #420's
"two arguments are two gates" note).

THE DIVERGENCE DOMAIN THIS FILE MEASURES
----------------------------------------
For one camp decision at instant `t` with camp location `loc`:

    shipped TRUE  <=>  no REACHED teammate is strictly closer to loc than bot
    armed   TRUE  <=>  no teammate at all is strictly closer
    DIVERGENCE    <=>  shipped TRUE and some UNREACHED teammate is closer

`UNREACHED` is the side-dependent complement above: {pid 4} for a radiant bot,
{pid 5,6,7,8} for a dire one.  So the domain is **structurally 4x larger on
dire**, and that is a property of the defect, not of the corpus -- every table
below is therefore split by physical side as well as by leg (铁律 4(i-a)).

DIRECTION, READ IT WITH THE TABLE.  A divergent decision on the BASELINE leg is
a camp the shipped tree handed to a hero who was NOT the closest farmer; the
same decision on the ARMED leg is one the gate would have refused.  The gate is
INHIBITORY: there is no positive armed observable, so what is bought here is the
counterfactual (the domain is non-empty and side-shaped), plus the falsifiable
half -- armed's divergent rate should sit BELOW baseline's on the same physical
side, and armed can never exceed baseline by construction.

LIMITS -- read before quoting a number.
 1. MODE IS NOT OBSERVABLE.  The engine clause is `member:GetActiveMode() ==
    BotMode.Farm`; a `.dem` cannot say a teammate's mode.  Counting every closer
    teammate therefore OVERCOUNTS: `div_wide` is an UPPER BOUND on the domain.
    `div_tight` additionally requires the closer teammate to be in the jungle
    himself (within JUNGLE_R of a neutral creep sample at that instant) -- a
    farm proxy, not the mode, so it is a tighter bound, not a truth.
 2. THE CAMP DECISION INSTANT IS NOT OBSERVABLE EITHER.  The selector runs on
    the farm path and the hero then walks.  The reading is taken at `t0 - lead`
    for three leads (10/20/30 s) so the reader can see it is not an artefact of
    one; `--lead` picks the primary.  Episodes where the subject moved faster
    than any hero can walk inside the lead (blink, scroll, respawn snap) are
    dropped -- campsel_domain's MAX_WALK_SPEED guard, same constant.
 3. CAMP LOCATION IS THE NEUTRAL CREEP, not the hero.  A camp is located by the
    nearest `creeps[]` sample with `team == 4` inside CREEP_DT of the first
    blow; an engagement with no such sample is dropped as UNLOCATABLE (the
    creep grid is 0.33 Hz -- a missing sample is unknown, never "no camp").
 4. ENTITY KEYS (GH #176): bodies are keyed `(hero, idx)` and only PRE-HORN
    bodies count.  Illusions DO attack neutrals, so the first blow is
    attributed to the pre-horn body of that name and the episode is dropped
    unless that body is itself within FAR_FROM_CAMP of the camp.
 5. A TEAMMATE WHOSE POSITION IS UNKNOWN at the decision instant (no bracketing
    live sample within ALIVE_DT on both sides) is NOT counted as closer.  That
    is the conservative direction for the domain claim and the permissive one
    for the "armed refused nothing" claim -- both are stated, neither is hidden.
 6. BOTH LEGS LIVE IN THE SAME GAME.  This estimator does not cancel side bias,
    so 铁律 4(i-b) applies to any cross-leg count: the leg comparison is made
    WITHIN one physical side (dire-armed vs dire-baseline), never across.

Usage:
    slotarb_domain.py --run <timelines_dir>:<manifest.jsonl> [--run ...]
    slotarb_domain.py --selfcheck
"""
import argparse
import collections
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slotdust_arbitration import (  # noqa: E402
    DIRE, RADIANT, real_bodies, roster, team_slot)

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', '..'))
ABA_SITE = os.path.join(REPO, 'bots', 'FunLib', 'aba_site.lua')
FARM_MODE = os.path.join(REPO, 'bots', 'mode_farm_generic.lua')

CAND = 'slotarb'
NEUTRAL_PREFIX = 'npc_dota_neutral'
HERO_PREFIX = 'npc_dota_hero_'
NEUTRAL_TEAM = 4

GAP = 12.0             # campsel_domain.GAP -- engagement grouping
FAR_FROM_CAMP = 1200.0  # campfarm_target/campsel hygiene (LIMIT 4)
JUNGLE_R = 1200.0      # "this teammate is in the jungle too" (LIMIT 1)
FARM_WINDOW = 5.0      # "this teammate is CLEARING a camp right now" (LIMIT 1)
CREEP_DT = 2.0         # creeps[] is 0.33 Hz (LIMIT 3)
ALIVE_DT = 2.0         # bracketing window for a live position (LIMIT 5)
MAX_WALK_SPEED = 700.0  # campsel_domain.MAX_WALK_SPEED (LIMIT 2)
WALK_SPEED = 400.0     # ground a hero can cover per second, STRICT rows only
MIN_APPROACH = 600.0   # already inside the camp => the choice was made earlier
MIN_BLOWS = 3          # a cleared camp, not one incidental swing
CAMP_SPLIT_R = 900.0   # two camps this far apart are two decisions, not one
LEADS = (10.0, 20.0, 30.0)
DEFAULT_LEAD = 20.0


# ---------------------------------------------------------------------------
# source facts -- derived from bots/, never transcribed
# ---------------------------------------------------------------------------
def _read(path):
    with open(path, 'r', encoding='utf-8') as fh:
        return fh.read()


def _strip_lua_comments(src):
    return re.sub(r'^\s*--.*$', '', src, flags=re.M)


def gate_facts(farm_src=None, aba_src=None):
    """Everything the attribution rests on, read off the tree at run time."""
    farm = _strip_lua_comments(farm_src if farm_src is not None
                               else _read(FARM_MODE))
    aba = _strip_lua_comments(aba_src if aba_src is not None
                              else _read(ABA_SITE))

    # (1) the ONE resolution point, and which ARGUMENT carries this candidate.
    m = re.search(r'GetClosestNeutralSpwan\s*\(\s*hBot\s*,\s*tCamps\s*,'
                  r'(?P<arg>.*?)\)\s*\n', farm, re.S)
    args, cand_arg, conjoined = [], None, []
    if m:
        depth, cur = 0, []
        for ch in m.group('arg'):
            if ch in '([{':
                depth += 1
            elif ch in ')]}':
                depth -= 1
            if ch == ',' and depth == 0:
                args.append(''.join(cur))
                cur = []
                continue
            cur.append(ch)
        args.append(''.join(cur))
        for i, a in enumerate(args):
            ids = re.findall(r"IsSoakCandidate\(\s*'([^']+)'\s*\)", a)
            if CAND in ids:
                cand_arg = i
                if len(ids) > 1:
                    conjoined = sorted(ids)
    call_sites = len(re.findall(r'J\.Site\.GetClosestNeutralSpwan\s*\(', farm))

    # (2) the scan itself: shipped feeds the player id, armed feeds the index.
    body = ''
    b = re.search(r'^____exports\.IsTheClosestOne\s*=\s*function\s*\(', aba, re.M)
    if b:
        nxt = re.compile(r'^____exports\.', re.M).search(aba, b.end())
        body = aba[b.start():nxt.start() if nxt else len(aba)]
    return {
        'call_sites': call_sites,
        'cand_arg': cand_arg,
        'n_args': len(args),
        'conjoined': conjoined,
        'iter_players': bool(re.search(r'ipairs\(GetTeamPlayers\(GetTeam\(\)\)\)',
                                       body)),
        'shipped_slot_is_id': bool(re.search(r'local\s+nSlot\s*=\s*id', body)),
        'armed_slot_is_index': bool(re.search(
            r'if\s+bSlotArb\s+then\s*\n\s*nSlot\s*=\s*i\b', body)),
        'seeds_with_bot': bool(re.search(r'local\s+closestMember\s*=\s*bot', body)),
        'strict_closer': bool(re.search(r'memberDist\s*<\s*minDist', body)),
        'farm_mode_clause': bool(re.search(
            r'GetActiveMode\(\)\s*==\s*BotMode\.Farm', body)),
        'returns_identity': bool(re.search(r'return\s+closestMember\s*==\s*bot',
                                           body)),
    }


def unreached_pids(team):
    """Player ids the SHIPPED scan never looks at, for a bot on this team."""
    if team == RADIANT:
        return {4}                     # id 0 out of range, slot 5 never asked
    return {5, 6, 7, 8}                # only id 5 (== slot 5) is in range


# ---------------------------------------------------------------------------
# corpus
# ---------------------------------------------------------------------------
def dist(ax, ay, bx, by):
    return math.dist((ax, ay), (bx, by))


def is_neutral(name):
    return bool(name) and name.startswith(NEUTRAL_PREFIX)


def is_hero(name):
    return bool(name) and name.startswith(HERO_PREFIX)


def index_bodies(snaps):
    """{(hero, idx): [live frames sorted]} over PRE-HORN bodies only."""
    bodies = real_bodies(snaps)
    by_ent = collections.defaultdict(list)
    for s in snaps:
        if (s.get('hp_pct') or 0) <= 0:
            continue
        k = (s['hero'], s['idx'])
        if k in bodies:
            by_ent[k].append(s)
    for v in by_ent.values():
        v.sort(key=lambda s: s['t'])
    return by_ent


def live_pos(frames, t, dt=ALIVE_DT):
    """Bracketed live position at `t`, or None when unknown (LIMIT 5)."""
    before = after = None
    for s in frames:
        if s['t'] <= t:
            before = s
        elif after is None:
            after = s
            break
    if before is None or after is None:
        return None
    if t - before['t'] > dt or after['t'] - t > dt:
        return None
    span = after['t'] - before['t']
    f = 0.0 if span <= 0 else (t - before['t']) / span
    return (before['x'] + (after['x'] - before['x']) * f,
            before['y'] + (after['y'] - before['y']) * f)


def teleported(frames, t0, t1, cap=MAX_WALK_SPEED):
    span = [f for f in frames if t0 <= f['t'] <= t1]
    for a, b in zip(span, span[1:]):
        dt = b['t'] - a['t']
        if dt > 0 and dist(a['x'], a['y'], b['x'], b['y']) / dt > cap:
            return True
    return False


def neutral_samples(tl):
    """Neutral creep samples bucketed by whole second, for camp location."""
    by_t = collections.defaultdict(list)
    for c in tl.get('creeps', ()):
        if c.get('team') == NEUTRAL_TEAM:
            by_t[int(c['t'])].append((c['x'], c['y']))
    return by_t


def nearest_neutral(by_t, t, x, y, dt=CREEP_DT, radius=FAR_FROM_CAMP):
    best, bd = None, radius
    for sec in range(int(t - dt), int(t + dt) + 1):
        for cx, cy in by_t.get(sec, ()):
            d = dist(x, y, cx, cy)
            if d <= bd:
                best, bd = (cx, cy), d
    return best


def engagements(tl):
    """One record per hero per contiguous run of blows traded with neutrals."""
    trades = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] != 'DAMAGE':
            continue
        a, tg = e['actor'], e['target']
        if is_hero(a) and is_neutral(tg):
            trades[a].append((e['t'], True))       # the hero swung first
        elif is_neutral(a) and is_hero(tg):
            trades[tg].append((e['t'], False))     # the camp swung at him
    out = []
    for hero, ts in trades.items():
        ts.sort()
        cur = [ts[0]]
        for t in ts[1:]:
            if t[0] - cur[-1][0] <= GAP:
                cur.append(t)
            else:
                out.append((hero, cur))
                cur = [t]
        out.append((hero, cur))
    return [{'hero': h, 't0': ts[0][0], 't1': ts[-1][0], 'blows': len(ts),
             'initiated': ts[0][1], 'blows_at': ts}
            for h, ts in out]


def trades_by_hero(tl):
    """{hero name: sorted times it traded blows with a neutral creep}."""
    out = collections.defaultdict(list)
    for e in tl['events']:
        if e['type'] != 'DAMAGE':
            continue
        a, tg = e['actor'], e['target']
        if is_hero(a) and is_neutral(tg):
            out[a].append(e['t'])
        elif is_neutral(a) and is_hero(tg):
            out[tg].append(e['t'])
    for v in out.values():
        v.sort()
    return out


def trading_at(times, t, window=FARM_WINDOW):
    lo, hi = t - window, t + window
    for x in times:
        if x > hi:
            return False
        if x >= lo:
            return True
    return False


def decide(by_ent, team_roster, team, pid, camp, t, jungle_by_t, trades=None):
    """Evaluate both legs of IsTheClosestOne at instant `t`.

    Returns None when the subject's own position is unknown, else a dict with
    the shipped/armed answers and the witnesses that produced them.
    """
    me = team_roster[team][pid]
    mine = live_pos(by_ent[me], t)
    if mine is None:
        return None
    my_d = dist(mine[0], mine[1], camp[0], camp[1])
    unreached = unreached_pids(team)
    trades = trades or {}
    closer_reached, closer_unreached, closer_tight = [], [], []
    closer_farming = []
    for other_pid, key in sorted(team_roster[team].items()):
        if other_pid == pid:
            continue
        p = live_pos(by_ent[key], t)
        if p is None:
            continue                      # LIMIT 5
        d = dist(p[0], p[1], camp[0], camp[1])
        if d >= my_d:
            continue
        row = {'pid': other_pid, 'slot': team_slot(team, other_pid),
               'hero': key[0], 'd': d}
        if other_pid in unreached:
            closer_unreached.append(row)
            if nearest_neutral(jungle_by_t, t, p[0], p[1],
                               radius=JUNGLE_R) is not None:
                closer_tight.append(row)
            if trading_at(trades.get(key[0], ()), t):
                closer_farming.append(row)
        else:
            closer_reached.append(row)
    return {
        'my_d': my_d,
        'shipped_true': not closer_reached,
        'armed_true': not closer_reached and not closer_unreached,
        'closer_reached': closer_reached,
        'closer_unreached': closer_unreached,
        'closer_tight': closer_tight,
        'closer_farming': closer_farming,
    }


def load_run(tl_dir, manifest_path):
    """A manifest is bound to its own timeline dir -- GH #444, never pooled."""
    stamps = {}
    with open(manifest_path, encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            g = json.loads(line)
            stamps[g['game']] = (g.get('cand'), g.get('seed'), g.get('side'))
    files = []
    for fn in sorted(os.listdir(tl_dir)):
        if fn.endswith('.timeline.json'):
            files.append((fn[:-len('.timeline.json')],
                          os.path.join(tl_dir, fn)))
    return files, stamps


def split_by_camp(blows, jungle_by_t, by_ent_key_frames, radius=CAMP_SPLIT_R):
    """Cut one trade run into per-CAMP runs.

    FOUND BY LOOKING AT THE FRAMES, NOT THE AGGREGATE: `20260903_101254_slot5`
    crystal_maiden trades with the ancient frog camp at t=870..876 and with the
    wolf camp 3 s later, and a 12 s GAP merges them into ONE episode whose camp
    is then the FIRST camp -- so the decision would have been evaluated against
    a camp the hero was only passing through.  Cutting on camp geometry is the
    difference between "which camp did he choose" and "what did he hit first".
    """
    runs, cur, cur_loc = [], [], None
    for t, initiated in blows:
        pos = live_pos(by_ent_key_frames, t)
        if pos is None:
            continue
        loc = nearest_neutral(jungle_by_t, t, pos[0], pos[1])
        if loc is None:
            continue
        if cur_loc is not None and dist(loc[0], loc[1], cur_loc[0],
                                       cur_loc[1]) > radius:
            runs.append((cur_loc, cur))
            cur, cur_loc = [], None
        cur.append((t, initiated))
        cur_loc = loc if cur_loc is None else (
            (cur_loc[0] * (len(cur) - 1) + loc[0]) / len(cur),
            (cur_loc[1] * (len(cur) - 1) + loc[1]) / len(cur))
    if cur:
        runs.append((cur_loc, cur))
    return runs


def scan_game(tl, base, seed, armed_side, leads=LEADS):
    """Yield one row per LOCATABLE camp engagement, for every lead."""
    snaps = tl['snapshots']
    by_ent = index_bodies(snaps)
    team_roster = roster(by_ent)
    if team_roster is None:
        return None, 'malformed roster'
    by_name = {}
    for team, pids in team_roster.items():
        for pid, key in pids.items():
            by_name.setdefault(key[0], (team, pid, key))
    jungle_by_t = neutral_samples(tl)
    trades = trades_by_hero(tl)
    armed_team = RADIANT if armed_side == 'radiant' else DIRE
    rows = []
    for ep in engagements(tl):
        who = by_name.get(ep['hero'])
        if who is None:
            continue
        team, pid, key = who
        parts = split_by_camp(ep['blows_at'], jungle_by_t, by_ent[key])
        if not parts:
            rows.append({'game': base, 'unlocatable': True})
            continue
        for camp, blows in parts:
            scan_part(rows, by_ent, team_roster, jungle_by_t, trades, base,
                      seed, team, pid, key, camp, blows, armed_side, leads)
    return rows, None


def scan_part(rows, by_ent, team_roster, jungle_by_t, trades, base, seed,
              team, pid, key, camp, blows, armed_side, leads):
    """One camp engagement: the decision tables for each lead."""
    if camp is not None:
        armed_team = RADIANT if armed_side == 'radiant' else DIRE
        t0 = blows[0][0]
        initiated = blows[0][1]
        leg = 'armed' if team == armed_team else 'baseline'
        side = 'radiant' if team == RADIANT else 'dire'
        for lead in leads:
            t = t0 - lead
            if t < 0:
                continue
            if teleported(by_ent[key], t, t0):
                continue                               # LIMIT 2
            d = decide(by_ent, team_roster, team, pid, camp, t, jungle_by_t,
                       trades)
            if d is None:
                continue
            rows.append({
                'game': base, 'seed': seed, 'hero': key[0], 'pid': pid,
                'slot': team_slot(team, pid), 'side': side, 'leg': leg,
                'stratum': 'ab' if armed_side == 'radiant' else 'ba',
                'lead': lead, 't': round(t, 2), 't0': round(t0, 2),
                'camp': [round(camp[0], 1), round(camp[1], 1)],
                'blows': len(blows), 'my_d': round(d['my_d'], 1),
                'initiated': initiated,
                # STRICT: the decision instant has to be one a walking hero
                # could have acted on -- he must still be OUTSIDE the camp
                # (the choice is not yet consumed) and INSIDE the ground a
                # hero can cover before the first blow (WALK_SPEED * lead).
                # Without it a row can sit 8,000 u away 20 s before a blow,
                # which is not a camp decision at all -- it is the lead
                # landing in an unrelated part of the hero's game (LIMIT 2).
                'approach_ok': (MIN_APPROACH <= d['my_d']
                                <= WALK_SPEED * lead),
                'shipped_true': d['shipped_true'],
                'armed_true': d['armed_true'],
                'divergent': d['shipped_true'] and bool(d['closer_unreached']),
                'divergent_tight': d['shipped_true'] and bool(d['closer_tight']),
                'divergent_farming': (d['shipped_true']
                                      and bool(d['closer_farming'])),
                'witness': d['closer_unreached'][:3],
                'unlocatable': False,
            })


# ---------------------------------------------------------------------------
# selfcheck: synthetic frames whose right answer is known by construction
# ---------------------------------------------------------------------------
def _snap(hero, idx, team, pid, t, x, y, hp=1.0):
    return {'hero': hero, 'idx': idx, 'team': team, 'player_id': pid, 't': t,
            'x': x, 'y': y, 'hp': 500, 'hp_pct': hp, 'level': 6, 'items': [],
            'abilities': []}


def _stand(positions, times=(-60.0, 97.0, 98.0, 99.0, 100.0, 101.0, 102.0,
                             103.0, 200.0)):
    """One pre-horn body per (team, pid) standing still at its position."""
    snaps = []
    for i, ((team, pid), (x, y)) in enumerate(sorted(positions.items())):
        hero = 'npc_dota_hero_h%d' % pid
        for t in times:
            snaps.append(_snap(hero, 100 + i, team, pid, t, x, y))
    return snaps


def selfcheck():
    ok = [0, 0]

    def ck(cond, what):
        ok[0 if cond else 1] += 1
        print('%-5s %s' % ('PASS' if cond else 'FAIL', what))

    f = gate_facts()
    ck(f['call_sites'] == 1, 'exactly one J.Site.GetClosestNeutralSpwan call site')
    ck(f['cand_arg'] == 1 and f['n_args'] == 2,
       'slotarb is the SECOND gate argument (campsel is the first)')
    ck(f['conjoined'] == [], 'the slotarb argument is not conjoined with another id')
    ck(f['iter_players'] and f['shipped_slot_is_id'],
       'shipped feeds the PLAYER ID to GetTeamMember')
    ck(f['armed_slot_is_index'], 'armed feeds the loop INDEX (the team slot)')
    ck(f['seeds_with_bot'] and f['returns_identity'],
       'closestMember is seeded with bot => armed TRUE is a SUBSET of shipped')
    ck(f['strict_closer'], 'a witness must be STRICTLY closer (ties keep the bot)')
    ck(f['farm_mode_clause'], 'the scan requires BotMode.Farm (LIMIT 1 is real)')

    ck(team_slot(RADIANT, 0) == 1 and team_slot(RADIANT, 4) == 5,
       'radiant pid->slot mapping')
    ck(team_slot(DIRE, 5) == 1 and team_slot(DIRE, 9) == 5,
       'dire pid->slot mapping')
    ck(unreached_pids(RADIANT) == {4}, 'radiant misses exactly team slot 5')
    ck(unreached_pids(DIRE) == {5, 6, 7, 8}, 'dire misses team slots 1..4')

    # A dire subject at the camp with an UNREACHED teammate standing closer.
    camp = (4000.0, 3000.0)
    pos = {(DIRE, 5): (3800.0, 3000.0),   # slot 1 -- unreached, CLOSER
           (DIRE, 6): (4600.0, 3000.0),   # the subject
           (DIRE, 7): (9000.0, 9000.0),
           (DIRE, 8): (9000.0, -9000.0),
           (DIRE, 9): (9000.0, 0.0),      # slot 5 -- the only reached one
           (RADIANT, 0): (-9000.0, 0.0), (RADIANT, 1): (-9000.0, 1000.0),
           (RADIANT, 2): (-9000.0, 2000.0), (RADIANT, 3): (-9000.0, 3000.0),
           (RADIANT, 4): (-9000.0, 4000.0)}
    by_ent = index_bodies(_stand(pos))
    tr = roster(by_ent)
    ck(tr is not None, 'synthetic roster is well formed')
    jungle = {100: [camp]}
    d = decide(by_ent, tr, DIRE, 6, camp, 100.0, jungle)
    ck(d['shipped_true'] and not d['armed_true'],
       'dire: shipped ACCEPTS the camp its own slot-1 farmer owns; armed refuses')
    ck([w['slot'] for w in d['closer_unreached']] == [1],
       'the witness is named by team slot, not by player id')
    ck(bool(d['closer_tight']),
       'the witness standing in the camp counts as jungling (tight column)')

    # The reached teammate is closer -> BOTH legs refuse, not a divergence.
    pos2 = dict(pos)
    pos2[(DIRE, 9)] = (3900.0, 3000.0)
    by2 = index_bodies(_stand(pos2))
    d2 = decide(by2, roster(by2), DIRE, 6, camp, 100.0, jungle)
    ck(not d2['shipped_true'] and not d2['armed_true'],
       'a closer REACHED teammate is refused by both legs (no divergence)')

    # Radiant subject: only pid 4 is unreached.
    pos3 = {(RADIANT, 0): (4600.0, 3000.0),   # the subject
            (RADIANT, 1): (9000.0, 0.0), (RADIANT, 2): (9000.0, 1000.0),
            (RADIANT, 3): (9000.0, 2000.0),
            (RADIANT, 4): (3800.0, 3000.0),   # slot 5 -- unreached, CLOSER
            (DIRE, 5): (-9000.0, 0.0), (DIRE, 6): (-9000.0, 1000.0),
            (DIRE, 7): (-9000.0, 2000.0), (DIRE, 8): (-9000.0, 3000.0),
            (DIRE, 9): (-9000.0, 4000.0)}
    by3 = index_bodies(_stand(pos3))
    d3 = decide(by3, roster(by3), RADIANT, 0, camp, 100.0, jungle)
    ck(d3['shipped_true'] and not d3['armed_true'] and
       [w['slot'] for w in d3['closer_unreached']] == [5],
       'radiant: the slot-5 farmer is invisible to the shipped scan')

    # Nobody closer -> both legs accept; and a tie keeps the camp (strict <).
    pos4 = dict(pos3)
    pos4[(RADIANT, 4)] = (4600.0, 3000.0)     # exactly as far as the subject
    by4 = index_bodies(_stand(pos4))
    d4 = decide(by4, roster(by4), RADIANT, 0, camp, 100.0, jungle)
    ck(d4['shipped_true'] and d4['armed_true'],
       'an equally-distant teammate does not take the camp (ties keep the bot)')

    # An illusion (no pre-horn sample) must not become a witness.
    illus = _stand(pos3) + [_snap('npc_dota_hero_h4', 999, RADIANT, 4, t,
                                  3900.0, 3000.0)
                            for t in (99.0, 100.0, 101.0)]
    by5 = index_bodies(illus)
    ck(all(k[1] != 999 for k in by5), 'a post-horn body is not indexed (GH #176)')

    # A dead teammate is not a witness: hp_pct 0 frames are dropped, and the
    # bracketing rule then refuses to interpolate across the hole.
    dead = [s for s in _stand(pos3)]
    for s in dead:
        if s['player_id'] == 4 and 97.0 <= s['t'] <= 103.0:
            s['hp_pct'] = 0
    by6 = index_bodies(dead)
    d6 = decide(by6, roster(by6), RADIANT, 0, camp, 100.0, jungle)
    ck(d6 is not None and not d6['closer_unreached'],
       'a dead teammate is not counted as closer (LIMIT 5, conservative)')

    # engagement shaping: who swung first, and where one episode ends.
    ev = [{'t': 100.0, 'type': 'DAMAGE', 'actor': 'npc_dota_neutral_kobold',
           'target': 'npc_dota_hero_h0'},
          {'t': 101.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_h0',
           'target': 'npc_dota_neutral_kobold'},
          {'t': 400.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_h0',
           'target': 'npc_dota_neutral_kobold'}]
    eps = engagements({'events': ev})
    ck(len(eps) == 2, 'a %.0fs gap starts a new engagement' % GAP)
    ck(eps[0]['initiated'] is False and eps[0]['blows'] == 2,
       'the camp swinging first is NOT an initiated engagement')
    ck(eps[1]['initiated'] is True, 'a hero swinging first IS initiated')

    # split_by_camp: the defect the pinned frame exposed (one trade run, two
    # camps 3,000 u apart -- 20260903_101254_slot5 crystal_maiden).
    walker = ([_snap('npc_dota_hero_h0', 1, RADIANT, 0, -60.0, 0.0, 0.0)] +
              [_snap('npc_dota_hero_h0', 1, RADIANT, 0, t, 60.0 * (t - 100),
                     0.0) for t in [100.0 + i for i in range(0, 61)]])
    by_w = index_bodies(walker)
    fr = by_w[('npc_dota_hero_h0', 1)]
    jungle2 = {}
    for sec in range(100, 161):
        jungle2[sec] = [(60.0 * (sec - 100), 0.0)]
    near = split_by_camp([(105.0, True), (106.0, True)], jungle2, fr)
    far = split_by_camp([(105.0, True), (155.0, True)], jungle2, fr)
    ck(len(near) == 1, 'two blows on one camp stay ONE decision')
    ck(len(far) == 2,
       'blows %du apart are TWO camp decisions (the 101254_slot5 defect)'
       % int(60 * 50))

    print('\n%d PASS / %d FAIL' % (ok[0], ok[1]))
    return 1 if ok[1] else 0


# ---------------------------------------------------------------------------
def _rate(n, d):
    return '%5.1f%%' % (100.0 * n / d) if d else '    --'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--run', action='append', default=[],
                    help='<timelines_dir>:<manifest.jsonl>, repeatable; each '
                         'manifest is bound to its own dir (GH #444)')
    ap.add_argument('--lead', type=float, default=DEFAULT_LEAD)
    ap.add_argument('--episodes', type=int, default=0,
                    help='print the N divergent decisions with the largest '
                         'distance gap, as frame evidence')
    ap.add_argument('--out')
    ap.add_argument('--selfcheck', action='store_true')
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()
    if not args.run:
        ap.error('--run is required')

    rows, games, skipped, unlocatable = [], 0, 0, 0
    for spec in args.run:
        tl_dir, manifest = spec.split(':', 1)
        files, stamps = load_run(tl_dir, manifest)
        for base, path in files:
            st = stamps.get(base)
            if st is None:
                continue
            _cand, seed, side = st
            with open(path, encoding='utf-8') as fh:
                tl = json.load(fh)
            got, err = scan_game(tl, base, seed, side, leads=LEADS)
            if err:
                skipped += 1
                continue
            games += 1
            for r in got:
                if r.get('unlocatable'):
                    unlocatable += 1
                else:
                    rows.append(r)

    f = gate_facts()
    print('== source facts (read off the tree, not transcribed) ==')
    for k in sorted(f):
        print('   %-20s %s' % (k, f[k]))
    print('\ngames read: %d   (roster-malformed, dropped: %d)' % (games, skipped))
    print('unlocatable engagements (no neutral creep sample, LIMIT 3): %d'
          % unlocatable)

    at_lead = [r for r in rows if r['lead'] == args.lead]
    print('\n== A. camp decisions at lead %.0fs, by side x leg ==' % args.lead)
    print('   %-8s %-9s %7s %8s %9s %9s %9s' %
          ('side', 'leg', 'decs', 'shipYES', 'div_wide', 'rate', 'div_tight'))
    cells = collections.defaultdict(collections.Counter)
    for r in at_lead:
        c = cells[(r['side'], r['leg'])]
        c['decs'] += 1
        c['ship'] += 1 if r['shipped_true'] else 0
        c['div'] += 1 if r['divergent'] else 0
        c['tight'] += 1 if r['divergent_tight'] else 0
    for side in ('radiant', 'dire'):
        for leg in ('baseline', 'armed'):
            c = cells[(side, leg)]
            print('   %-8s %-9s %7d %8d %9d %9s %9d' %
                  (side, leg, c['decs'], c['ship'], c['div'],
                   _rate(c['div'], c['ship']), c['tight']))

    strict = [r for r in at_lead if r['approach_ok'] and r['initiated']
              and r['blows'] >= MIN_BLOWS]
    print('\n== A2. STRICT rows only: the hero swung first, cleared >=%d blows,'
          ' and was %.0f..%.0fu from the camp at the decision instant =='
          % (MIN_BLOWS, MIN_APPROACH, WALK_SPEED * args.lead))
    print('   %-8s %-9s %7s %8s %9s %8s %9s %9s %8s' %
          ('side', 'leg', 'decs', 'shipYES', 'div_wide', 'rate', 'div_tight',
           'div_farm', 'rate'))
    scells = collections.defaultdict(collections.Counter)
    for r in strict:
        c = scells[(r['side'], r['leg'])]
        c['decs'] += 1
        c['ship'] += 1 if r['shipped_true'] else 0
        c['div'] += 1 if r['divergent'] else 0
        c['tight'] += 1 if r['divergent_tight'] else 0
        c['farm'] += 1 if r['divergent_farming'] else 0
    for side in ('radiant', 'dire'):
        for leg in ('baseline', 'armed'):
            c = scells[(side, leg)]
            print('   %-8s %-9s %7d %8d %9d %8s %9d %9d %8s' %
                  (side, leg, c['decs'], c['ship'], c['div'],
                   _rate(c['div'], c['ship']), c['tight'], c['farm'],
                   _rate(c['farm'], c['ship'])))

    print('\n== B. the same rows split by stratum (铁律 4(i-a)) ==')
    print('   %-6s %-8s %-9s %7s %8s %9s %9s' %
          ('strat', 'side', 'leg', 'decs', 'shipYES', 'div_wide', 'rate'))
    st_cells = collections.defaultdict(collections.Counter)
    for r in at_lead:
        c = st_cells[(r['stratum'], r['side'], r['leg'])]
        c['decs'] += 1
        c['ship'] += 1 if r['shipped_true'] else 0
        c['div'] += 1 if r['divergent'] else 0
    for key in sorted(st_cells):
        c = st_cells[key]
        print('   %-6s %-8s %-9s %7d %8d %9d %9s' %
              (key[0], key[1], key[2], c['decs'], c['ship'], c['div'],
               _rate(c['div'], c['ship'])))

    print('\n== C. lead sensitivity (LIMIT 2) ==')
    print('   %-6s %-8s %-9s %8s %9s %9s' %
          ('lead', 'side', 'leg', 'shipYES', 'div_wide', 'rate'))
    for lead in LEADS:
        for side in ('radiant', 'dire'):
            for leg in ('baseline', 'armed'):
                sub = [r for r in rows if r['lead'] == lead and
                       r['side'] == side and r['leg'] == leg]
                ship = [r for r in sub if r['shipped_true']]
                div = [r for r in ship if r['divergent']]
                print('   %-6.0f %-8s %-9s %8d %9d %9s' %
                      (lead, side, leg, len(ship), len(div),
                       _rate(len(div), len(ship))))

    if args.episodes:
        print('\n== D. frame evidence: divergent decisions, widest gap first ==')
        div = [r for r in strict if r['divergent_farming']] or \
              [r for r in strict if r['divergent']]
        div.sort(key=lambda r: -(r['my_d'] - min(w['d'] for w in r['witness'])))
        for r in div[:args.episodes]:
            w = min(r['witness'], key=lambda w: w['d'])
            print('   %s t=%.1f (blow t0=%.1f) %s pid=%d slot=%d %s/%s' %
                  (r['game'], r['t'], r['t0'], r['hero'], r['pid'], r['slot'],
                   r['side'], r['leg']))
            print('      camp %s  subject %.0fu  |  closer UNREACHED teammate '
                  '%s slot=%d %.0fu' %
                  (r['camp'], r['my_d'], w['hero'], w['slot'], w['d']))

    if args.out:
        with open(args.out, 'w', encoding='utf-8') as fh:
            for r in rows:
                fh.write(json.dumps(r) + '\n')
        print('\nwrote %s (%d rows)' % (args.out, len(rows)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
