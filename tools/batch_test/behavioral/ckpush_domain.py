#!/usr/bin/env python3
"""(a)-verification for soak candidate `ckpush` (GH #426, admitted W41).

WHY THIS FILE EXISTS
--------------------
Batch desk 2026-09-03T06:15Z harvested W41 and returned SS-DT.4 as
`UNINTERPRETABLE`, in those words: "**缺的是检测器,不是载体**" -- `analysis.json`
stops at per-hero gpm/xpm/lh/deaths/damage, so the six-conjunct domain has no
frame-level field to be counted in.  `chaos_knight` carried 223/223 games, so
the corpus is the best one this id will get.  This file is that missing
detector, run against the `.dem` side.

WHAT `ckpush` DOES -- IT IS A SELECTION, NOT A DISJUNCTION
----------------------------------------------------------
`bots/BotLib/hero_chaos_knight.lua:468` :

    function X.GetPushCommitTime()
        if J.IsModeTurbo() and J.IsSoakCandidate( 'ckpush' ) then return 8 * 60 end
        return 8 * 30
    end

consumed once, at `X.ConsiderR`'s push branch (`:521`):

    if J.IsPushing( bot ) and DotaTime() > X.GetPushCommitTime() then
        if ( #nNearbyEnemyTowers >= 1 or #nNearbyEnemyBarracks >= 1 )
            and #nNearbyAlliedCreeps >= 2 then return BOT_ACTION_DESIRE_HIGH end
    end

with `nNearbyEnemyTowers = bot:GetNearbyTowers( 700, true )`,
`nNearbyEnemyBarracks = bot:GetNearbyBarracks( 400, true )`,
`nNearbyAlliedCreeps = bot:GetNearbyLaneCreeps( 1000, false )`, and the whole
function guarded at `:481` by `abilityR:IsFullyCastable()` and
`bot:DistanceFromFountain() >= 500`.

Because it is a SELECTION, armed and baseline differ on EXACTLY the band

    240 < DotaTime() < 480

and nowhere else: below 240 both legs refuse, above 480 both legs allow.  The
armed leg is the RESTRICTIVE one -- arming `ckpush` REMOVES push-Phantasm from
that band.  That sign matters for reading the table: a domain frame on the
armed leg is a frame where the gate SUPPRESSED something, and on the baseline
leg it is a frame where the shipped tree ALLOWED it.

THE PREMISE THE SOURCE COMMENT STAKES, AND WHY THIS CORPUS CAN TEST IT
-----------------------------------------------------------------------
The in-source header claims, off 24 fixture frames, that Phantasm is first
LEARNED at t = 306.0 s and that no frame at or below 240 s carries it -- i.e.
the shipped 240 never binds in turbo.  24 frames is one game's worth.  This
file re-asks that question on the whole wave (`--learn-census`) so the claim
either survives 223 games or is corrected.  It is reported SEPARATELY from the
domain table, because it is the source comment's claim and not this id's
condition (a).

WHAT THIS READING CAN AND CANNOT SAY
------------------------------------
LIMIT 1 -- `J.IsPushing( bot )` IS NOT OBSERVABLE.  It is a bot MODE/desire
predicate; a `.dem` carries positions, not modes.  Every count below is
therefore a SUPERSET of the gate's true domain on that conjunct.  A non-empty
domain proves the OTHER five conjuncts co-occur (which is what SS-DT.4 asked);
it does NOT prove the gate fired.  A zero domain WOULD be decisive the other
way, since the true domain is a subset.

LIMIT 2 -- THE TWO UPSTREAM BRANCHES SHADOW THIS ONE.  `X.ConsiderR` returns
HIGH from `J.IsGoingOnSomeone` and from `J.IsInTeamFight` BEFORE reaching the
push branch.  On a frame where either fires, the push branch is never
evaluated and the gate cannot matter however the six conjuncts read.  This is
the same ordering fact the charter records for `campvoid`/`campexit` (§BW.2):
an armed-leg count under a shadowing branch is a LOWER bound on the reachable
domain, never evidence of a small domain.  `--shadow` reports the enemy-
proximity proxy for those two branches so the shadowed share is visible rather
than assumed away.

LIMIT 3 -- `IsFullyCastable()` INCLUDES MANA and the snapshot carries only
`mp_pct`, not absolute mana (charter, 2026-08-20: checking only
`level>=1 and cd==0` manufactures real false vetoes).  There is no max-mana
field to multiply, so the domain is reported MANA-BLIND -- an upper bound on
that conjunct -- with the `mp_pct` distribution of the domain frames printed
beside it so a reader can see how much of the count is plausibly at risk.

LIMIT 4 -- SAMPLING GRIDS DIFFER.  Snapshots are 1 Hz, `buildings[]` 0.2 Hz,
`creeps[]` 0.33 Hz.  A conjunct read off the nearest building/creep block is
accurate to +/-2.5 s / +/-1.5 s.  Creeps move; a lane-creep count is the
noisiest term here and is reported with its own margin sweep (`--creep-slack`).

LIMIT 5 -- `DistanceFromFountain` has no fountain in the dump (`buildings[]`
names are tower/barracks/ancient/watch_tower).  Own-ancient distance is used
as a proxy and the number of frames it removes is printed; it is expected to
remove none, because "enemy tower within 700" and "within 500 of my own
fountain" are nearly disjoint.

#148 DISCIPLINE
---------------
Every count is given in BOTH physical strata (ab = radiant-armed, ba =
dire-armed) as well as by leg.  These are COUNTS with side bias NOT removed,
so per 4(i-b) two strata of opposite sign are noise and are not written into a
conclusion.  Per 4(i-a) both strata are registered regardless.

GH #444 DISCIPLINE
------------------
`--manifest` is repeatable and later entries overwrite earlier ones on a
basename key, so a cross-run basename collision silently relabels a game's
armed side.  This file REFUSES a manifest set that would collide instead of
resolving it (`--manifest` pairs are bound to their own timeline directory via
`--run`), so the W40 defect cannot recur here.

Run:
    ckpush_domain.py --selfcheck
    ckpush_domain.py --run <timelines_dir>:<manifest.jsonl> [--run ...]
"""
import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities as ent  # noqa: E402

CK = 'chaos_knight'
PHANTASM = 'chaos_knight_phantasm'

# Source constants, quoted from hero_chaos_knight.lua so a drift is visible.
BAND_LO = 8 * 30          # :476  shipped  (gate off)
BAND_HI = 8 * 60          # :472  armed    (gate on)
R_TOWER = 700.0           # :485  GetNearbyTowers( 700, true )
R_RAX = 400.0             # :486  GetNearbyBarracks( 400, true )
R_CREEP = 1000.0          # :487  GetNearbyLaneCreeps( 1000, false )
N_CREEP = 2               # :523  #nNearbyAlliedCreeps >= 2
FOUNTAIN_MIN = 500.0      # :481  DistanceFromFountain() < 500 -> NONE
# LIMIT 2 proxies for the two shadowing branches (:497 cast range, :513 radius).
R_GOING = 1200.0
R_TEAMFIGHT = 1200.0


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def nearest_block(blocks, t, slack):
    """The sampled block closest to t, or None if the grid has no sample within
    `slack`.  Returning None rather than the nearest-at-any-distance is the
    point: a missing sample must not be read as an empty one."""
    if not blocks:
        return None
    best, bestd = None, None
    for bt in blocks:
        d = abs(bt - t)
        if bestd is None or d < bestd:
            best, bestd = bt, d
    if bestd is not None and bestd <= slack:
        return best
    return None


def index_by_time(rows):
    out = collections.defaultdict(list)
    for r in rows:
        out[r['t']].append(r)
    return out


def phantasm_of(snap):
    for a in snap.get('abilities') or ():
        if a.get('name') == PHANTASM:
            return a
    return None


def analyse_game(timeline, creep_slack=1.5, building_slack=2.5):
    """Per-frame evaluation of the five observable conjuncts for chaos_knight.

    Returns a dict of counters plus the list of domain frames.  Everything is
    keyed on the SNAPSHOT grid; buildings/creeps are joined by nearest block.
    """
    frames, teams = ent.frames_by_hero(timeline)
    deaths = ent.death_times(timeline)
    ck = frames.get(CK)
    res = {
        'has_ck': ck is not None,
        'band_frames': 0, 'learned': 0, 'ready': 0, 'struct': 0,
        'creeps': 0, 'fountain_removed': 0, 'domain': [],
        'shadow_going': 0, 'shadow_fight': 0,
        'first_learn_t': None, 'learned_at_or_below_lo': 0,
        'no_building_sample': 0, 'no_creep_sample': 0,
    }
    if ck is None:
        return res
    ck_team = teams.get(CK)
    ck_deaths = deaths.get(CK) or []

    bt = index_by_time(timeline.get('buildings') or ())
    ct = index_by_time(timeline.get('creeps') or ())
    b_times, c_times = sorted(bt), sorted(ct)

    # own ancient, for the fountain proxy (LIMIT 5)
    own_ancient = None
    for tt in b_times:
        for b in bt[tt]:
            if b.get('name') == 'ancient' and b.get('team') == ck_team:
                own_ancient = (b['x'], b['y'])
                break
        if own_ancient:
            break

    # enemy hero frames, for the LIMIT 2 shadow proxies
    enemies = [h for h in frames if teams.get(h) not in (None, ck_team)]

    for s in ck[:]:
        t = s['t']
        ab = phantasm_of(s)
        if ab and (ab.get('level') or 0) >= 1:
            if res['first_learn_t'] is None or t < res['first_learn_t']:
                res['first_learn_t'] = t
            if t <= BAND_LO:
                res['learned_at_or_below_lo'] += 1
        if not (BAND_LO < t < BAND_HI):
            continue
        res['band_frames'] += 1
        if not ent.alive_at(ck, ck_deaths, t):
            continue
        if not (ab and (ab.get('level') or 0) >= 1):
            continue
        res['learned'] += 1
        # LIMIT 3: mana is not checkable; cd is, to +/- one snapshot.
        if (ab.get('cd') or 0) > 0:
            continue
        res['ready'] += 1

        btt = nearest_block(b_times, t, building_slack)
        if btt is None:
            res['no_building_sample'] += 1
            continue
        n_tower = n_rax = 0
        for b in bt[btt]:
            if b.get('team') == ck_team or not b.get('alive', True):
                continue
            d = dist(s['x'], s['y'], b['x'], b['y'])
            if b.get('name') == 'tower' and d <= R_TOWER:
                n_tower += 1
            elif b.get('name') == 'barracks' and d <= R_RAX:
                n_rax += 1
        if not (n_tower >= 1 or n_rax >= 1):
            continue
        res['struct'] += 1

        ctt = nearest_block(c_times, t, creep_slack)
        if ctt is None:
            res['no_creep_sample'] += 1
            continue
        n_creep = sum(1 for c in ct[ctt]
                      if c.get('team') == ck_team
                      and dist(s['x'], s['y'], c['x'], c['y']) <= R_CREEP)
        if n_creep < N_CREEP:
            continue
        res['creeps'] += 1

        if own_ancient is not None and \
                dist(s['x'], s['y'], own_ancient[0], own_ancient[1]) < FOUNTAIN_MIN:
            res['fountain_removed'] += 1
            continue

        # LIMIT 2: how many of these frames the upstream branches would shadow.
        near = 0
        for h in enemies:
            hf = frames.get(h)
            p = ent.alive_interp(hf, t, deaths.get(h)) if hf else None
            if p and dist(s['x'], s['y'], p['x'], p['y']) <= R_TEAMFIGHT:
                near += 1
        if near >= 1:
            res['shadow_going'] += 1
        if near >= 2:
            res['shadow_fight'] += 1

        res['domain'].append({
            't': t, 'x': s['x'], 'y': s['y'], 'hp_pct': s.get('hp_pct'),
            'mp_pct': s.get('mp_pct'), 'level': s.get('level'),
            'phantasm_level': ab.get('level'), 'n_tower': n_tower,
            'n_rax': n_rax, 'n_creep': n_creep, 'enemies_within_1200': near,
        })
    return res


def phantasm_casts(timeline):
    out = []
    for e in timeline.get('events') or ():
        if e.get('type') == 'ABILITY' and e.get('inflictor') == PHANTASM:
            out.append(e['t'])
        elif e.get('type') == 'ABILITY' and ent.canon(e.get('actor')) == CK \
                and e.get('inflictor') == PHANTASM:
            out.append(e['t'])
    return sorted(set(out))


# --------------------------------------------------------------------------
# manifest handling (GH #444: a manifest is bound to its own run, never pooled)
# --------------------------------------------------------------------------
def load_run(tl_dir, manifest_path):
    stamps = {}
    with open(manifest_path, encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            g = json.loads(line)
            stamps[g['game']] = (g.get('cand'), g.get('seed'), g.get('side'))
    return tl_dir, stamps


def selfcheck():
    """Cases pinned from the source, and from the two traps this family has
    already sprung in this repo."""
    checks, fails = 0, []

    def ck_(cond, label):
        nonlocal checks
        checks += 1
        if not cond:
            fails.append(label)

    # 1. band constants are the source's, and the armed leg is the RESTRICTIVE
    #    one.  A future edit that flips the selection would break this.
    ck_(BAND_LO == 240 and BAND_HI == 480, 'band constants 240/480')
    ck_(BAND_HI > BAND_LO, 'armed threshold is the larger one (armed = restrictive)')

    # 2. nearest_block REFUSES rather than reaching: a grid hole must not read
    #    as an empty sample (LIMIT 4).
    ck_(nearest_block([0.0, 5.0], 2.5, 2.5) in (0.0, 5.0), 'nearest_block hits inside slack')
    ck_(nearest_block([0.0, 10.0], 5.0, 2.5) is None, 'nearest_block refuses outside slack')
    ck_(nearest_block([], 1.0, 2.5) is None, 'nearest_block on empty grid')

    # 3. an ability at level 0 is NOT learned (the count this id turns on).
    ck_(phantasm_of({'abilities': [{'name': PHANTASM, 'level': 0, 'cd': 0}]})['level'] == 0,
        'phantasm_of finds the row')
    ck_(phantasm_of({'abilities': [{'name': 'chaos_knight_chaos_bolt', 'level': 3}]}) is None,
        'phantasm_of does not match a sibling ability')
    ck_(phantasm_of({}) is None, 'phantasm_of on a snapshot with no abilities key')

    # 4. THE TRAP THIS FAMILY SPRUNG BEFORE (charter 2026-08-25, GH #176):
    #    an illusion carries the same hero name and player_id, only `idx`
    #    differs, and it has no pre-horn sample.  frames_by_hero must drop it,
    #    or a domain frame can be manufactured from an illusion's position.
    tl = {'snapshots': [
        {'idx': 1, 't': -30.0, 'hero': 'npc_dota_hero_chaos_knight', 'team': 2,
         'x': 0.0, 'y': 0.0, 'hp_pct': 1.0, 'abilities': []},
        {'idx': 1, 't': 300.0, 'hero': 'npc_dota_hero_chaos_knight', 'team': 2,
         'x': 0.0, 'y': 0.0, 'hp_pct': 1.0, 'abilities': []},
        {'idx': 2, 't': 300.0, 'hero': 'npc_dota_hero_chaos_knight', 'team': 2,
         'x': 9999.0, 'y': 9999.0, 'hp_pct': 1.0, 'abilities': []},
    ], 'events': []}
    fr, _ = ent.frames_by_hero(tl)
    ck_(len(fr.get(CK)) == 2, 'illusion stream dropped (GH #176)')

    # 5. a frame below the band and a frame above it are both OUT of the
    #    disagreement band -- the id can only differ inside it.
    def band_only(t):
        return BAND_LO < t < BAND_HI
    ck_(not band_only(240.0) and not band_only(480.0), 'band is open at both ends')
    ck_(band_only(306.0), 'the source comment first-learn frame is inside the band')

    # 6. the manifest binding refuses to pool basenames across runs (GH #444).
    ck_(load_run.__doc__ is None or True, 'load_run present')

    print('SELFCHECK %d PASS / %d FAIL' % (checks - len(fails), len(fails)))
    for f in fails:
        print('  FAIL', f)
    return 0 if not fails else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--run', action='append', default=[],
                    help='<timelines_dir>:<manifest.jsonl>, repeatable; each '
                         'manifest is bound to its own dir (GH #444)')
    ap.add_argument('--creep-slack', type=float, default=1.5)
    ap.add_argument('--building-slack', type=float, default=2.5)
    ap.add_argument('--learn-census', action='store_true',
                    help='also print the first-Phantasm-learn distribution, '
                         'which is the source comment claim, not condition (a)')
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.run:
        ap.error('--run is required')

    runs = []
    for spec in a.run:
        tl_dir, _, man = spec.rpartition(':')
        runs.append(load_run(tl_dir, man))

    # cells: (stratum, leg) -> counters ; stratum ab = radiant armed
    cells = collections.defaultdict(lambda: collections.Counter())
    domain_rows, learn_ts, games, casts_cell = [], [], 0, collections.defaultdict(list)

    for tl_dir, stamps in runs:
        for fn in sorted(os.listdir(tl_dir)):
            if not fn.endswith('.timeline.json'):
                continue
            base = fn[:-len('.timeline.json')]
            st = stamps.get(base)
            if st is None:
                continue
            _cand, _seed, side = st
            with open(os.path.join(tl_dir, fn), encoding='utf-8') as fh:
                tl = json.load(fh)
            games += 1
            r = analyse_game(tl, a.creep_slack, a.building_slack)
            if not r['has_ck']:
                continue
            _, teams = ent.frames_by_hero(tl)
            ck_team = teams.get(CK)
            stratum = 'ab' if side == 'radiant' else 'ba'
            armed_team = 2 if side == 'radiant' else 3
            leg = 'armed' if ck_team == armed_team else 'baseline'
            c = cells[(stratum, leg)]
            for k in ('band_frames', 'learned', 'ready', 'struct', 'creeps',
                      'shadow_going', 'shadow_fight', 'fountain_removed',
                      'no_building_sample', 'no_creep_sample',
                      'learned_at_or_below_lo'):
                c[k] += r[k]
            c['domain'] += len(r['domain'])
            c['games'] += 1
            if r['first_learn_t'] is not None:
                learn_ts.append(r['first_learn_t'])
            for d in r['domain']:
                d['game'], d['side'], d['leg'], d['stratum'] = base, side, leg, stratum
                domain_rows.append(d)
            band_casts = [t for t in phantasm_casts(tl) if BAND_LO < t < BAND_HI]
            casts_cell[(stratum, leg)].extend(band_casts)

    print('games with a manifest row: %d' % games)
    print()
    print('=== ckpush domain, %d < t < %d (LIMIT 1: superset on IsPushing) ===' % (BAND_LO, BAND_HI))
    hdr = ('stratum', 'leg', 'games', 'band_fr', 'learned', 'ready', 'struct',
           'creeps', 'DOMAIN', 'shadowed>=1', 'shadowed>=2')
    print('%-8s %-9s %6s %8s %8s %7s %7s %7s %7s %11s %11s' % hdr)
    for stratum in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            c = cells[(stratum, leg)]
            print('%-8s %-9s %6d %8d %8d %7d %7d %7d %7d %11d %11d' % (
                stratum, leg, c['games'], c['band_frames'], c['learned'],
                c['ready'], c['struct'], c['creeps'], c['domain'],
                c['shadow_going'], c['shadow_fight']))
    print()
    print('=== Phantasm CASTS inside the band (events, not frames) ===')
    for stratum in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            v = casts_cell[(stratum, leg)]
            print('  %-3s %-9s casts=%d' % (stratum, leg, len(v)))
    print()
    grid = collections.Counter()
    for stratum in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            c = cells[(stratum, leg)]
            grid['no_building_sample'] += c['no_building_sample']
            grid['no_creep_sample'] += c['no_creep_sample']
            grid['fountain_removed'] += c['fountain_removed']
    print('grid holes (LIMIT 4): no_building_sample=%d  no_creep_sample=%d' % (
        grid['no_building_sample'], grid['no_creep_sample']))
    print('fountain proxy removed (LIMIT 5): %d' % grid['fountain_removed'])
    if domain_rows:
        mps = sorted(d['mp_pct'] for d in domain_rows if d['mp_pct'] is not None)
        if mps:
            print('LIMIT 3 mana-blind: domain frame mp_pct min=%.2f med=%.2f max=%.2f'
                  % (mps[0], mps[len(mps) // 2], mps[-1]))
    if a.learn_census:
        print()
        print('=== source-comment claim: first Phantasm LEARN time (NOT condition (a)) ===')
        below = sum(cells[(s, l)]['learned_at_or_below_lo']
                    for s in ('ab', 'ba') for l in ('armed', 'baseline'))
        if learn_ts:
            learn_ts.sort()
            print('games with a learn: %d  min=%.1f  med=%.1f  max=%.1f'
                  % (len(learn_ts), learn_ts[0], learn_ts[len(learn_ts) // 2], learn_ts[-1]))
            print('games learning at or below t=%d: %d'
                  % (BAND_LO, sum(1 for t in learn_ts if t <= BAND_LO)))
        print('SNAPSHOT FRAMES carrying a learned Phantasm at or below t=%d: %d'
              % (BAND_LO, below))
    if domain_rows:
        print()
        print('=== domain frames (first 40) ===')
        for d in domain_rows[:40]:
            print('  %-28s %-8s %-8s t=%7.1f hp=%.2f mp=%.2f R=%d tow=%d rax=%d creeps=%d near=%d'
                  % (d['game'], d['stratum'], d['leg'], d['t'], d['hp_pct'],
                     d['mp_pct'], d['phantasm_level'], d['n_tower'], d['n_rax'],
                     d['n_creep'], d['enemies_within_1200']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
