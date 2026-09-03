#!/usr/bin/env python3
"""(a)-verification for soak candidate `roshdist` (GH #422, admitted W41).

WHY THIS FILE EXISTS
--------------------
`roshdist` was handed to replay-check with condition (a) unbought: test_set.md
§DP.8 says in as many words that the fixture level cannot reach it -- a fixture
does not record the bot's active mode, so the `botActiveMode == BOT_MODE_ROSHAN`
conjunct is out of reach there, and §DP.8 names the shape replay-check is to
look for: **主体离坑口很远、却被抬起了撤退欲望** (a subject far from the pit
whose retreat desire is raised anyway).  The previous round
(`20260903T072000Z.md` §7) recorded `VERIFY id=roshdist verdict=INDETERMINATE
episodes=0` -- "not measured", not "measured and empty".  This file measures it.

WHAT `roshdist` DOES
--------------------
`bots/mode_retreat_generic.lua:423`:

    if botActiveMode == BOT_MODE_ROSHAN
        and not J.IsRoshanAlive()
        and J.IsAtRoshanPit(bot, vRoshanLocation)      <-- the gated conjunct
        and IsLocationVisible(vRoshanLocation)
    then
        if not C.aegisNearby1200 then
            return BOT_MODE_DESIRE_MODERATE
        end
    end

`J.IsAtRoshanPit` (jmz_func.lua:12380) resolves the gate in one place:

    unarmed  -> GetUnitToLocationDistance(bot, vRoshanLocation)   -- a NUMBER
    armed    -> that distance <= 1600                             -- a BOOLEAN

Every Lua number is truthy (0 included), so the shipped conjunct is a spacer,
not a condition.  **The armed leg is the RESTRICTIVE one**: arming `roshdist`
can only ever REMOVE this retreat desire, never add one.  So the divergence
domain is exactly

    {frames where roshan is dead}  x  {dist(bot, pit) > 1600}

and a frame with dist <= 1600 is bit-identical between the legs.  Sign matters
for reading the table: a `far` frame on the armed leg is a frame where the gate
SUPPRESSED an offer; on the baseline leg it is a frame the shipped tree let
through.

TWO CONJUNCTS ARE FULLY OBSERVABLE, AND THAT IS THE POINT
---------------------------------------------------------
Unlike `ckpush` (whose `J.IsPushing` is a desire predicate and unreachable),
`roshdist`'s own operand is pure geometry:

  * the pit is a PURE FUNCTION OF THE CLOCK -- `J.GetCurrentRoshanLocation()`
    (jmz_func.lua:11511) returns `J.Utils.DireRoshanLoc` when
    `DotaTime() % 600 < 300` ("day") and `J.Utils.RadiantRoshanLoc` otherwise.
    No engine state, no fog: this file recomputes it exactly.
  * `not J.IsRoshanAlive()` (jmz_func.lua:10065) is `DotaTime() - killTime <=
    6*60` in turbo, and the roshan DEATH lands in `events[]` with its `t`.
  * the hero's own position is in `snapshots[]`.

SECTION A EXISTS BECAUSE THE RADIUS IS ONLY AS GOOD AS THE CENTRE
-----------------------------------------------------------------
`roshdist` measures 1600 units from whatever `J.GetCurrentRoshanLocation()`
returns.  If that function names the wrong pit, the armed leg refuses everyone
-- including a bot standing in the real pit -- and "armed refused" would mean
something entirely different from what §DP proposes.  Nobody has checked that
premise against a replay, so this file checks it FIRST and separately: at each
roshan death it takes the heroes who were actually damaging roshan and asks
which pit they were standing in.  That is the instrument-zero discipline of
GH #89/#391/§DJ applied to a location instead of to a distance.

WHAT THIS READING CANNOT SAY
----------------------------
LIMIT 1 -- `botActiveMode == BOT_MODE_ROSHAN` IS NOT OBSERVABLE.  A `.dem`
carries positions, not modes.  Every domain count below is a SUPERSET on that
conjunct.  A non-empty domain therefore proves the OTHER conjuncts co-occur; it
does NOT prove the gate fired on any one frame.  A ZERO domain would be
decisive the other way, since the true domain is a subset of this one.

LIMIT 2 -- `IsLocationVisible(vRoshanLocation)` IS NOT OBSERVABLE EITHER.  The
dumper's README (behavioral/README.md, "Vision / fog of war") records that the
replay carries no per-team visibility flag at all; the god stream has no
`m_iTaggedAsVisibleByTeam`.  Same direction as LIMIT 1: superset.

LIMIT 3 -- `C.aegisNearby1200` scans `GetDroppedItemList()` for an aegis lying
on the GROUND within 1200 (mode_retreat_generic.lua:33).  Dropped items are not
in the dump.  A held aegis IS (`snapshots[].items` carries `aegis`), so this
file reports the held-aegis frames as an upper-bound proxy and does not
subtract them: an aegis in an inventory is exactly the case `scanDroppedForAegis`
does NOT see.

LIMIT 4 -- SNAPSHOTS INCLUDE ILLUSIONS.  Phantasm/manta images share the hero's
class name (last round's §2 saw 20+ chaos_knight rows on one second).  Section A
therefore takes the MINIMUM distance over a hero's rows (the real unit is the
one hitting roshan), and section B counts HERO-FRAMES as they appear, which
over-counts illusion-heavy heroes.  `--dedupe-nearest` reports the domain with
one row per (hero, second) -- the row nearest the pit -- so the reader can see
how much of the count is images.

Usage:
    roshdist_domain.py --run <timelines_dir>:<manifest.jsonl> [--run ...]
    roshdist_domain.py --selfcheck
"""
import argparse
import collections
import json
import math
import os
import sys

# bots/FunLib/utils.lua:709-710
RADIANT_PIT = (-2984.0, 2349.0)
DIRE_PIT = (2980.0, -2816.0)

# bots/FunLib/jmz_func.lua:12388 -- the derived "arrived at the pit" radius
PIT_RADIUS = 1600.0

# bots/FunLib/jmz_func.lua:10072 -- turbo respawn assumption
ROSH_DEAD_WINDOW = 6 * 60.0

ROSHAN = 'npc_dota_roshan'


def dist(x, y, pit):
    return math.hypot(x - pit[0], y - pit[1])


def time_of_day(t):
    """bots/FunLib/jmz_func.lua:10013 -- cycle 600, night starts at 300."""
    return 'day' if (t % 600.0) < 300.0 else 'night'


def current_pit(t):
    """bots/FunLib/jmz_func.lua:11511 -- day => Dire pit, night => Radiant pit."""
    return DIRE_PIT if time_of_day(t) == 'day' else RADIANT_PIT


def roshan_deaths(tl):
    """Game-clock seconds of every roshan DEATH in events[]."""
    out = []
    for e in tl.get('events', ()):
        if e.get('type') == 'DEATH' and e.get('target') == ROSHAN:
            out.append(float(e['t']))
    return sorted(out)


def dead_intervals(deaths):
    """`not J.IsRoshanAlive()` as half-open [t_k, t_k + 360) windows, merged."""
    out = []
    for t in deaths:
        lo, hi = t, t + ROSH_DEAD_WINDOW
        if out and lo <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], hi))
        else:
            out.append((lo, hi))
    return out


def in_any(t, intervals):
    for lo, hi in intervals:
        if lo <= t < hi:
            return True
    return False


def roshan_attackers(tl, t_death, lookback=20.0):
    """Heroes that dealt DAMAGE to roshan in the lookback before its death."""
    names = set()
    for e in tl.get('events', ()):
        if (e.get('type') == 'DAMAGE' and e.get('target') == ROSHAN
                and e.get('actor_hero') and t_death - lookback <= float(e['t']) <= t_death):
            names.add(e['actor'])
    return names


def observed_pit(tl, t_death, slack=2.0, accept=900.0):
    """Which pit roshan actually died in, read off the killers' own positions.

    Returns (pit_name, median_min_distance) or (None, best) when the evidence
    does not clear `accept` -- an UNRESOLVED death is reported, never guessed.
    """
    attackers = roshan_attackers(tl, t_death)
    if not attackers:
        return None, None
    per_hero = {}
    for s in tl.get('snapshots', ()):
        if s['hero'] not in attackers or abs(float(s['t']) - t_death) > slack:
            continue
        d = per_hero.setdefault(s['hero'], [None, None])
        for i, pit in enumerate((RADIANT_PIT, DIRE_PIT)):
            v = dist(float(s['x']), float(s['y']), pit)
            if d[i] is None or v < d[i]:
                d[i] = v
    if not per_hero:
        return None, None
    meds = []
    for i in range(2):
        vals = sorted(d[i] for d in per_hero.values() if d[i] is not None)
        if not vals:
            return None, None
        meds.append(vals[len(vals) // 2])
    best = min(meds)
    if best > accept:
        return None, best
    return ('radiant' if meds[0] < meds[1] else 'dire'), best


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
            files.append((fn[:-len('.timeline.json')], os.path.join(tl_dir, fn)))
    return files, stamps


# ---------------------------------------------------------------------------
# selfcheck: synthetic frames whose right answer is known by construction
# ---------------------------------------------------------------------------
def selfcheck():
    ok = [0, 0]

    def ck(cond, what):
        ok[0 if cond else 1] += 1
        print('%-5s %s' % ('PASS' if cond else 'FAIL', what))

    # 1-4. the clock -> pit function, both sides of both edges.
    ck(current_pit(0.0) == DIRE_PIT, 't=0 is day => Dire pit')
    ck(current_pit(299.9) == DIRE_PIT, 't=299.9 still day')
    ck(current_pit(300.0) == RADIANT_PIT, 't=300 flips to night => Radiant pit')
    ck(current_pit(600.0) == DIRE_PIT, 't=600 wraps back to day')

    # 5. the two pits are far enough apart that naming the wrong one is not a
    #    rounding error -- this is the premise section A is worth running for.
    ck(dist(RADIANT_PIT[0], RADIANT_PIT[1], DIRE_PIT) > 4 * PIT_RADIUS,
       'the pits are >4 radii apart (a wrong pit cannot be inside 1600)')

    # 6-7. the gated operand itself, at the boundary. `<=`, not `<`.
    ck(PIT_RADIUS <= PIT_RADIUS, 'armed accepts exactly 1600 (the operand is <=)')
    ck(not (PIT_RADIUS + 0.1 <= PIT_RADIUS), 'armed refuses 1600.1')

    # 8. the dead-window shape, incl. the merge of overlapping kills.
    ck(dead_intervals([100.0, 200.0]) == [(100.0, 200.0 + ROSH_DEAD_WINDOW)],
       'two kills 100s apart merge into one dead window')
    # 9. and its exclusive upper edge (respawn is alive again).
    iv = dead_intervals([100.0])
    ck(in_any(100.0, iv) and not in_any(100.0 + ROSH_DEAD_WINDOW, iv),
       'the dead window is half-open [kill, kill+360)')

    # 10-11. observed_pit reads the killers, and refuses when they are nowhere
    #        near either pit rather than guessing the nearer one.
    tl = {
        'events': [
            {'t': 500.0, 'type': 'DEATH', 'actor': 'npc_dota_hero_lion',
             'target': ROSHAN, 'actor_hero': True},
            {'t': 495.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_lion',
             'target': ROSHAN, 'actor_hero': True},
        ],
        'snapshots': [
            {'t': 500.0, 'hero': 'npc_dota_hero_lion', 'team': 2,
             'x': DIRE_PIT[0] + 100, 'y': DIRE_PIT[1], 'items': []},
        ],
    }
    ck(observed_pit(tl, 500.0)[0] == 'dire', 'observed pit = where the killer stood')
    tl2 = json.loads(json.dumps(tl))
    tl2['snapshots'][0]['x'] = 0.0
    tl2['snapshots'][0]['y'] = 0.0
    ck(observed_pit(tl2, 500.0)[0] is None, 'a killer at mid refuses to resolve a pit')

    # 12. t=500 is night, so the FORMULA says Radiant while the frame above
    #     says Dire: the disagreement this file exists to count is expressible.
    ck(current_pit(500.0) == RADIANT_PIT and observed_pit(tl, 500.0)[0] == 'dire',
       'formula/observed can disagree (the section A finding is representable)')

    print('selfcheck: %d passed, %d failed' % (ok[0], ok[1]))
    return 0 if ok[1] == 0 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--run', action='append', default=[],
                    help='<timelines_dir>:<manifest.jsonl>, repeatable; each '
                         'manifest is bound to its own dir (GH #444)')
    ap.add_argument('--radius', type=float, default=PIT_RADIUS)
    ap.add_argument('--dedupe-nearest', action='store_true',
                    help='count one row per (hero, second), the one nearest the '
                         'pit -- LIMIT 4, illusions')
    ap.add_argument('--episodes', type=int, default=0,
                    help='print the N longest far-from-pit episodes as frame '
                         'evidence')
    ap.add_argument('--selfcheck', action='store_true')
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()
    if not args.run:
        ap.error('--run is required')

    # (stratum, leg) -> counters.  stratum ab = radiant armed (charter 铁律 4).
    cells = collections.defaultdict(collections.Counter)
    pit_rows = []          # section A: one row per resolved roshan death
    episodes = []          # section B: contiguous far-from-pit runs
    games = 0
    games_with_death = 0

    for spec in args.run:
        tl_dir, manifest = spec.split(':', 1)
        files, stamps = load_run(tl_dir, manifest)
        for base, path in files:
            st = stamps.get(base)
            if st is None:
                continue
            _cand, seed, side = st
            games += 1
            stratum = 'ab' if side == 'radiant' else 'ba'
            armed_team = 2 if side == 'radiant' else 3
            with open(path, encoding='utf-8') as fh:
                tl = json.load(fh)
            deaths = roshan_deaths(tl)
            for leg in ('armed', 'baseline'):
                cells[(stratum, leg)]['games'] += 1
            if not deaths:
                continue
            games_with_death += 1

            # --- section A: is the clock-derived pit the pit roshan died in?
            for td in deaths:
                pit, best = observed_pit(tl, td)
                pit_rows.append({
                    'game': base, 'seed': seed, 't': td,
                    'tod': time_of_day(td),
                    'formula': 'dire' if current_pit(td) is DIRE_PIT else 'radiant',
                    'observed': pit, 'best': best,
                })

            # The pit roshan was ACTUALLY in for each dead window -- section B2
            # asks what the armed leg does to a bot standing in THAT pit.
            real_by_death = {}
            for r in pit_rows[-len(deaths):]:
                real_by_death[r['t']] = (
                    None if r['observed'] is None else
                    (RADIANT_PIT if r['observed'] == 'radiant' else DIRE_PIT))

            # --- section B: the divergence domain
            iv = dead_intervals(deaths)
            def real_pit_at(t, _d=deaths, _m=real_by_death):
                last = None
                for td in _d:
                    if td <= t:
                        last = td
                return _m.get(last) if last is not None else None

            best_row = {}
            for s in tl.get('snapshots', ()):
                t = float(s['t'])
                if not in_any(t, iv):
                    continue
                d = dist(float(s['x']), float(s['y']), current_pit(t))
                rp = real_pit_at(t)
                dr = None if rp is None else dist(float(s['x']), float(s['y']), rp)
                if args.dedupe_nearest:
                    k = (s['hero'], round(t, 1))
                    if k not in best_row or d < best_row[k][0]:
                        best_row[k] = (d, s, t, dr)
                    continue
                _tally(cells, stratum, armed_team, s, t, d, args.radius,
                       episodes, base, seed, dr)
            if args.dedupe_nearest:
                for d, s, t, dr in best_row.values():
                    _tally(cells, stratum, armed_team, s, t, d, args.radius,
                           episodes, base, seed, dr)

    print('games with a manifest row: %d   (with >=1 roshan death: %d)'
          % (games, games_with_death))
    print()
    print('=== A. pit truth: does J.GetCurrentRoshanLocation() name the pit')
    print('       roshan actually died in? (killers own positions, +/-2s) ===')
    agree = collections.Counter()
    for r in pit_rows:
        if r['observed'] is None:
            agree['unresolved'] += 1
        else:
            agree['agree' if r['observed'] == r['formula'] else 'DISAGREE'] += 1
            agree['tod=%s obs=%s' % (r['tod'], r['observed'])] += 1
    print('roshan deaths seen: %d' % len(pit_rows))
    for k in ('agree', 'DISAGREE', 'unresolved'):
        print('  %-11s %d' % (k, agree[k]))
    for k in sorted(k for k in agree if k.startswith('tod=')):
        print('  %-22s %d' % (k, agree[k]))
    print()
    print('=== B. divergence domain: roshan dead AND dist(bot,pit) > %d ===' % args.radius)
    print('    (armed REFUSES these; baseline OFFERS BOT_MODE_DESIRE_MODERATE)')
    print('    superset on mode + visibility -- LIMIT 1, LIMIT 2')
    hdr = ('stratum', 'leg', 'games', 'dead_fr', 'near<=r', 'DOMAIN>r',
           'held_aegis', 'far_share')
    print('%-8s %-9s %6s %8s %8s %9s %11s %9s' % hdr)
    for stratum in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            c = cells[(stratum, leg)]
            tot = c['dead_frames']
            print('%-8s %-9s %6d %8d %8d %9d %11d %8s' % (
                stratum, leg, c['games'], tot, c['near'], c['far'],
                c['held_aegis'],
                ('%.1f%%' % (100.0 * c['far'] / tot)) if tot else '-'))

    print()
    print('=== B2. the bots that ARE in the pit roshan died in ===')
    print('    at_real_pit  = dead-window frames within %d of the OBSERVED pit'
          % args.radius)
    print('    REFUSED      = of those, how many the armed leg rejects because')
    print('                   they are >%d from the CLOCK-DERIVED pit' % args.radius)
    print('%-8s %-9s %12s %10s %9s' % ('stratum', 'leg', 'at_real_pit',
                                       'REFUSED', 'refused%'))
    for stratum in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            c = cells[(stratum, leg)]
            n = c['at_real_pit']
            print('%-8s %-9s %12d %10d %8s' % (
                stratum, leg, n, c['at_real_pit_refused'],
                ('%.1f%%' % (100.0 * c['at_real_pit_refused'] / n)) if n else '-'))

    if args.episodes:
        print()
        print('=== C. longest far-from-pit episodes (frame evidence) ===')
        episodes.sort(key=lambda e: -e['n'])
        for e in episodes[:args.episodes]:
            print('  %s seed=%s %-28s %s t=%.1f..%.1f (%d frames) '
                  'dist %.0f..%.0f' % (
                      e['game'], e['seed'], e['hero'], e['leg'],
                      e['t0'], e['t1'], e['n'], e['d0'], e['d1']))
    return 0


def _tally(cells, stratum, armed_team, s, t, d, radius, episodes, base, seed,
           d_real=None):
    leg = 'armed' if int(s['team']) == armed_team else 'baseline'
    c = cells[(stratum, leg)]
    c['dead_frames'] += 1
    if d > radius:
        c['far'] += 1
    else:
        c['near'] += 1
    # section B2: a bot standing in the pit roshan was ACTUALLY in.
    if d_real is not None and d_real <= radius:
        c['at_real_pit'] += 1
        if d > radius:
            c['at_real_pit_refused'] += 1
    if 'aegis' in (s.get('items') or ()):
        c['held_aegis'] += 1
    # contiguous far runs, per (game, hero) -- section C frame evidence
    key = (base, s['hero'], leg)
    run = _tally.open_runs.get(key)
    if d > radius:
        if run and t - run['t1'] <= 1.6:
            run['t1'], run['d1'], run['n'] = t, d, run['n'] + 1
        else:
            if run:
                episodes.append(run)
            _tally.open_runs[key] = {
                'game': base, 'seed': seed, 'hero': s['hero'], 'leg': leg,
                't0': t, 't1': t, 'd0': d, 'd1': d, 'n': 1,
            }
    elif run:
        episodes.append(run)
        _tally.open_runs.pop(key, None)


_tally.open_runs = {}


if __name__ == '__main__':
    sys.exit(main())
