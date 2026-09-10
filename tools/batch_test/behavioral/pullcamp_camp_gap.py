#!/usr/bin/env python3
"""Per-episode camp-to-lane perpendicular gap for the pulls `pullcamp` actually made.

WHY THIS EXISTS (and why it is a file rather than an ad-hoc paste)
------------------------------------------------------------------
`tools/agent/pullcamp_lane_geometry.py` measures a FIXED list of camps -- the
ones the W7->W8 behaviour split named -- against the map reconstructed from the
fixtures' tower coordinates.  It answers "would tightening `PULL_CAMP_LANE_GAP`
drop the camps that produce connects?".

The replay desk's 2026-09-10T13:12Z round asked a different question of the same
map: not "these named camps", but "the camp of EVERY poke episode this wave
produced" -- which is how it got `>1200u = 15/39 = 38.5%` and the three
connecting camps' gaps `1268 / 1268 / 1200`.  That reading was computed inline
and therefore could not be re-run on the next wave without retyping it, while
its whole weakness was `n=3` and the only cure is more corpus.  This file is
that inline reading, made repeatable.  It adds no new geometry and no new
episode logic: it imports `min_gap` from the geometry module and `episodes()`
from `pullcamp_domain`, so a change to either propagates here.

MEASURE, stated so a reader does not over-read it
-------------------------------------------------
For each poke episode, the camp is `(camp_x, camp_y)` recorded on the episode's
FIRST poke frame (`pullcamp_domain.py` writes it; the bot's own selector picked
that camp), and the reading is the MINIMUM perpendicular gap over all three
lane polylines.

  * Only STRICT episodes count by default -- those whose camp is a FRIENDLY
    camp (`pullcamp_domain.py` sets `strict` exactly there).  This is not a
    cleanliness preference: `J.ShouldPullNeutralCamp` filters on
    `camp.team == GetTeam()` BEFORE `J.IsCampBesideLane` ever runs, so a gap
    measured at an enemy-side camp is a gap the predicate is never shown.
    Measured on W63: 1 of 29 armed poke episodes is non-strict, and including
    it moved the headline from 17/28 to 18/29 -- small here, but it is the
    kind of contamination that has no reason to stay bounded on the next wave.
    `--include-enemy-camps` restores the unfiltered reading.
  * Taking the MINIMUM makes the number insensitive to which lane the bot was
    assigned -- the dump does not carry `GetAssignedLane()`.  A camp whose
    minimum already exceeds the constant is rejected by `J.IsCampBesideLane`
    for EVERY lane, so `min > 1200` is a LOWER BOUND on the rejection count,
    never an upper one.  Conversely `min <= 1200` does NOT mean the camp
    passes: it may be beside a lane that is not this bot's.
  * The reconstruction reads ~20-82u wide of the engine at the decision line
    (see the geometry module's EDGE CONTROL).  So a per-episode gap within
    ~100u of 1200 is INSIDE the instrument's error, and the tally below prints
    that band separately instead of hiding it inside a >/<= split.

USAGE
    pullcamp_camp_gap.py [--rows /tmp/pullcamp_rows.jsonl] [--gap 1200]
"""
import argparse
import json
import os
import statistics
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
# tools/batch_test/behavioral -> tools/batch_test -> tools -> repo root.
# Three levels, not two: two lands on `tools/`, and `tools/tools/agent` is not
# a path, so the import below fails only when the tool is run on its own.  The
# unit test inserted the right paths itself before importing, so it PASSED on
# the broken version -- a test whose harness supplies what the tool must supply
# cannot see the tool missing it.
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'agent'))
sys.path.insert(0, HERE)

from pullcamp_lane_geometry import load_map, lane_paths, min_gap   # noqa: E402
from pullcamp_domain import episodes                               # noqa: E402

# Half-width of the band around the constant inside which this reconstruction
# cannot tell "rejected" from "accepted".  Sized from the geometry module's own
# calibration paragraph (behaviour brackets the constant into [1220, 1282) while
# the source says 1200), rounded up to a round number.
BLIND_BAND = 100


def q(v):
    if not v:
        return 'n=0'
    s = sorted(v)
    p90 = s[min(len(s) - 1, int(round(0.9 * (len(s) - 1))))]
    return ('n=%d median %.0f p90 %.0f max %.0f'
            % (len(s), statistics.median(s), p90, s[-1]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rows', default='/tmp/pullcamp_rows.jsonl')
    ap.add_argument('--gap', type=float, default=1200.0,
                    help='PULL_CAMP_LANE_GAP as it stands in jmz_func.lua')
    ap.add_argument('--include-enemy-camps', action='store_true',
                    help='also count episodes whose camp is NOT friendly -- '
                         'camps the Lua selector rejects before the gap '
                         'predicate is reached')
    a = ap.parse_args()

    files, towers, ancients = load_map()
    paths = lane_paths(towers, ancients)
    print('map: %d towers, %d ancients, identical in all %d fixtures carrying '
          'buildings' % (len(towers), len(ancients), files))

    rows = [json.loads(l) for l in open(a.rows)]
    by_leg = defaultdict(list)
    for r in rows:
        by_leg[r['leg']].append(r)

    print()
    hdr = ('%-9s %-28s %6s %6s %6s   %s'
           % ('leg', 'gap distribution', '>%d' % a.gap, 'blind', 'conn', 'connecting camps\' gaps'))
    print(hdr)
    print('-' * len(hdr))

    detail = {}
    dropped_n = {}
    for leg in ('armed', 'baseline'):
        eps = [e for e in episodes(by_leg.get(leg, []))
               if any(r['poke'] for r in e)]
        gaps, over, blind, conn_gaps = [], 0, 0, []
        per_ep = []
        dropped = 0
        for e in eps:
            t0 = min(r['t'] for r in e if r['poke'])
            f0 = [r for r in e if r['t'] == t0][0]
            if not f0.get('strict', True) and not a.include_enemy_camps:
                dropped += 1
                continue
            g, lane, _ = min_gap((f0['camp_x'], f0['camp_y']), paths)
            gaps.append(g)
            if g > a.gap:
                over += 1
            if abs(g - a.gap) <= BLIND_BAND:
                blind += 1
            connected = any(r['connect_own'] or r['connect_enemy'] for r in e)
            if connected:
                conn_gaps.append(g)
            per_ep.append((f0['sweep'], f0['game'], f0['hero'], t0,
                           f0['camp_x'], f0['camp_y'], g, lane, connected))
        detail[leg] = per_ep
        dropped_n[leg] = dropped
        print('%-9s %-28s %5d%s %5d%s %6d   %s'
              % (leg, q(gaps),
                 over, ' ' if not gaps else '', blind, ' ',
                 len(conn_gaps),
                 ' / '.join('%.0f' % x for x in sorted(conn_gaps)) or '-'))

    print()
    print('episodes dropped as NOT-friendly-camp (the Lua selector rejects them '
          'before the gap predicate): armed %d  baseline %d%s'
          % (dropped_n.get('armed', 0), dropped_n.get('baseline', 0),
             '   [--include-enemy-camps: none dropped]'
             if a.include_enemy_camps else ''))

    print()
    print('LIMITS -- quoting a number above means quoting these too:')
    print('  * min over three lanes => `>%d` is a LOWER bound on how many of these'
          % a.gap)
    print('    pulls `J.IsCampBesideLane` would refuse, not an upper one.')
    print('  * the `blind` column counts episodes within +-%du of the constant,'
          % BLIND_BAND)
    print('    i.e. inside this reconstruction\'s own error at the decision line.')
    print('    An episode can be counted in BOTH `>%d` and `blind`.' % a.gap)
    print('  * `conn` is the episode-level connect flag from pullcamp_domain.py')
    print('    (proximity of following neutrals to a lane creep), not a tracked')
    print('    identity; the gaps beside it are the camps those pulls started at.')

    print()
    print('PER-EPISODE (armed leg, widest gap first -- a tightening removes from the top)')
    for row in sorted(detail.get('armed', []), key=lambda r: -r[6]):
        print('  %-10s %-24s %-22s t=%-7.1f camp=(%5d,%5d) gap=%7.0f %-4s %s'
              % (os.path.basename(row[0])[-6:], row[1], row[2], row[3],
                 row[4], row[5], row[6], row[7],
                 'CONNECT' if row[8] else ''))


if __name__ == '__main__':
    main()
