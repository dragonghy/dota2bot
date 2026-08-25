#!/usr/bin/env python3
"""Camp-to-lane perpendicular gaps, from the corpus' own map geometry.

WHY THIS EXISTS
---------------
GH #117, director ruling 2026-08-25T07:xxZ, owner P1 DoD step 4: before
`PULL_CAMP_LANE_GAP` (`bots/FunLib/jmz_func.lua`) may be tightened from the
observed max drag (1200) down to a typical value (p90 992 / median 742), one
question must be answered first, and the ruling says it must not be skipped:

    do the camps that actually PRODUCE connects still fit under the tighter
    constant?

Those two camps are the entire numerator of the connect rate (W7/W8, both
physical sides, 2 connects each, replay desk 2026-08-25T01:3xZ).  Filtering
them out would turn `pulllane` from "drops the impossible pulls" into "drops
all pulls", and that reading is byte-identical to SILENT.

WHY IT CAN BE ANSWERED WITH ZERO AWS
------------------------------------
The predicate measures a camp against `GetLocationAlongLane`, which is an
engine call and is a mock constant in fixtures (world assertion: 930/930 corpus
frames).  But the lane is pinned by objects the fixtures DO carry: every
fixture snapshot lists all 22 towers with coordinates, and all 61 fixtures that
carry buildings agree on every one of them EXACTLY.  The map is therefore a
measured constant of this engine build, not an assumption, and the towers of a
lane lie on that lane.  The lane polyline below is built from those measured
coordinates only.

HOW THE RECONSTRUCTION IS CHECKED (this is the load-bearing part)
-----------------------------------------------------------------
A reconstruction that only agreed with itself would be worthless here, because
the decision sits inside its error bar.  So it is checked against behaviour the
project already paid for: W7 -> W8 armed `pulllane` for the first time, and the
replay desk published which camps KEPT firing and which went to exactly 0.0 per
100 games.  A correct polyline must reproduce that partition with a single
threshold -- and it does: every surviving camp reads below every cleared camp,
bracketing the constant into a narrow band that contains the source value.  The
partition is the edge control; without it this file would just be arithmetic
about a line nobody verified.

WHY THE VERDICT IS ORDINAL AND NOT A CALIBRATED NUMBER
------------------------------------------------------
The reconstruction is not exact: the behaviour bracket lands ~60u above the
1200 in source, which is the size one should expect from a tower chord standing
in for the engine's own 21-sample polyline plus centroid rounding.  So this
file deliberately does NOT rest its conclusion on "camp X reads 1220 > 992".
It rests on the ORDER, which survives any monotone error:

    among the camps that still fire, the two that produce the connects are the
    two WIDEST-gap ones.

Tightening a distance threshold removes camps widest-first.  Therefore any
tightening that changes behaviour at all removes the entire connect numerator
BEFORE it removes either camp that has never produced a connect.  That holds
without knowing the offset between these units and the engine's.

THE CORNER, checked rather than assumed
---------------------------------------
Segments are drawn straight between towers, so at the two map corners the
polyline CUTS the corner and could read a camp as closer to the lane than it
is.  The radiant numerator camp sits near one, so `--selfcheck` re-runs every
row against a corner-RESTORED polyline (the bend put back at the intersection
of the two straight tower stretches -- a parameter-free construction, no
invented waypoint).  It moves that camp by 1u: its closest approach is governed
by the ordinary tier2-tier1 stretch, not by the chord.  So the corner is not
doing any work here, and that is now an assertion rather than a hope.

Usage:
    python3 tools/agent/pullcamp_lane_geometry.py [--selfcheck]
"""

import glob
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ---------------------------------------------------------------- map, measured

BUILDING_RE = re.compile(
    r"\{ name = '(\w+)', team = (\d+), x = (-?\d+), y = (-?\d+)")

RADIANT, DIRE = 2, 3

# Tower -> lane membership.  These are NOT free parameters: every coordinate is
# asserted to exist in the corpus tower set, and the three lanes plus the two
# base towers per team are asserted to partition all 22 towers exactly once.  A
# tower that moved, vanished or was mis-filed turns the loader red.
LANE_TOWERS = {
    (RADIANT, 'TOP'): [(-6592, -3408), (-6501, -872), (-6336, 1856)],
    (RADIANT, 'MID'): [(-4640, -4144), (-3190, -2926), (-1544, -1408)],
    (RADIANT, 'BOT'): [(-3952, -6112), (-360, -6256), (4860, -6379)],
    (DIRE, 'TOP'): [(-5275, 6036), (-128, 6016), (3552, 5776)],
    (DIRE, 'MID'): [(524, 652), (2496, 2112), (4272, 3759)],
    (DIRE, 'BOT'): [(6269, -2240), (6400, 384), (6336, 3032)],
}
BASE_TOWERS = {
    RADIANT: [(-5712, -4864), (-5392, -5192)],
    DIRE: [(4944, 4776), (5280, 4432)],
}

# ------------------------------------------------------- camps, as measured off
# the harvested .dem corpus.  Rounded centroids and per-camp poke rates are the
# replay desk's W7/W8 table (GH #117 comment 2026-08-25T01:3xZ); `connects` is
# the ABSOLUTE connect count on that camp, which is the quantity the ruling says
# must survive any tightening.  The two `precise` rows are the same two camps at
# the finer centroid published in the 2026-08-22T15:18Z position clustering.
CAMPS = [
    # (side, (x, y), observed, connects, label)
    ('radiant', (4000, -5000), 'SURVIVED', 2, 'radiant safe-lane pull camp'),
    ('radiant', (200, -5200), 'SURVIVED', 0, ''),
    ('radiant', (-4000, 1000), 'CLEARED', 0, ''),
    ('radiant', (-1400, -3400), 'CLEARED', 0, ''),
    ('radiant', (-5000, -200), 'CLEARED', 0, ''),
    ('dire', (-4000, 4800), 'SURVIVED', 2, 'dire safe-lane pull camp'),
    ('dire', (-800, 5000), 'SURVIVED', 0, ''),
    ('dire', (-2600, 3800), 'CLEARED', 0, ''),
    ('dire', (1000, 2600), 'CLEARED', 0, ''),
    ('dire', (3400, -1400), 'CLEARED', 0, ''),
    ('dire', (1200, 4200), 'CLEARED', 0, ''),
]
PRECISE = [
    ('radiant', (3994, -5137), 'SURVIVED', 2, 'radiant hot camp, fine centroid'),
    ('dire', (-4007, 4947), 'SURVIVED', 2, 'dire hot camp, fine centroid'),
]

# The constants on the table in the ruling.
CANDIDATES = [
    (1200, 'in source today: max observed drag (1,170) rounded up'),
    (992, 'p90 of the observed drag -- the ruling\'s proposal'),
    (742, 'median of the observed drag -- the ruling\'s tighter proposal'),
]


def load_map():
    """Every tower/ancient coordinate, asserted identical across all fixtures."""
    seen = {}
    files = 0
    for path in sorted(glob.glob(os.path.join(ROOT, 'tests/fixtures/*.lua'))):
        with open(path) as fh:
            text = fh.read()
        if 'buildings = {' not in text:
            continue
        files += 1
        here = set()
        for m in BUILDING_RE.finditer(text.split('buildings = {')[1]):
            kind, team, x, y = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4))
            if kind in ('tower', 'ancient'):
                here.add((kind, team, x, y))
        for key in here:
            seen.setdefault(key, 0)
            seen[key] += 1
    if files < 20:
        raise SystemExit('too few fixtures carry buildings: %d' % files)
    disagree = [k for k, n in seen.items() if n != files]
    if disagree:
        raise SystemExit('map is NOT constant across fixtures: %r' % disagree[:4])
    towers = sorted(k[1:] for k in seen if k[0] == 'tower')
    ancients = {k[1]: (k[2], k[3]) for k in seen if k[0] == 'ancient'}
    return files, towers, ancients


def line_intersection(p1, p2, p3, p4):
    """Where the line p1p2 meets the line p3p4, or None if parallel."""
    d1x, d1y = p2[0] - p1[0], p2[1] - p1[1]
    d2x, d2y = p4[0] - p3[0], p4[1] - p3[1]
    den = d1x * d2y - d1y * d2x
    if abs(den) < 1e-9:
        return None
    t = ((p3[0] - p1[0]) * d2y - (p3[1] - p1[1]) * d2x) / den
    return (p1[0] + d1x * t, p1[1] + d1y * t)


def corner_vertex(lane):
    """The bend where a side lane turns, or None for a lane that has none.

    Parameter-free: the intersection of the two straight tower stretches that
    meet at the bend (radiant tier2->tier1 and dire tier1->tier2).  Two lines
    always meet somewhere, so the intersection alone proves nothing -- an
    essentially straight lane produces a meeting point somewhere in the MIDDLE
    of itself.  The test is therefore geometric rather than a tolerance: a real
    map corner lies FARTHER from the map centre than both tier-1s it joins,
    because it is the OUTSIDE of the turn.  On mid the solution lands between
    the towers and is rejected.

    [20260825] This replaces an `abs(x) < 9000 and abs(y) < 9000` box, which
    admitted the mid-lane solution at (1364, 1274) and inserted a spurious
    vertex that made the corner-restored mid polyline double back on itself.
    It was HARMLESS for every reading in this file -- the extra segments lie
    along the mid lane, so a min-distance-to-lane reading is unchanged, and the
    cross-check prints the camps moving 0-1u either way.  It is NOT harmless for
    a reader that wants the lane's TANGENT (tools/agent/lane_drag_direction.py),
    where a doubled-back vertex reverses the direction outright.
    """
    r = LANE_TOWERS[(RADIANT, lane)]
    d = LANE_TOWERS[(DIRE, lane)]
    v = line_intersection(r[1], r[2], d[0], d[1])
    if v is None:
        return None
    norm = lambda p: math.hypot(p[0], p[1])  # noqa: E731
    if norm(v) > norm(r[2]) and norm(v) > norm(d[0]):
        return v
    return None


def lane_paths(towers, ancients, corners=False):
    """The three lane polylines, radiant ancient -> dire ancient.

    With corners=False the two tier-1s are joined by one straight chord, which
    CUTS the map corner.  That is not sloppiness: the engine's own predicate
    measures to the chords between its 21 `GetLocationAlongLane` samples, so it
    cuts the same corner -- only less, because its chords are ~770u long and
    this one is ~4,300u.  With corners=True the bend is restored by inserting
    the intersection of the two straight tower stretches, which is a
    parameter-free construction (no invented waypoint).  Neither model is the
    engine's; running both is how the corner-sensitive rows are made visible
    instead of being asserted away.
    """
    have = set(towers)
    used = []
    for (team, _lane), pts in LANE_TOWERS.items():
        for p in pts:
            if (team,) + p not in have:
                raise SystemExit('declared lane tower %r (team %d) not in corpus' % (p, team))
            used.append((team,) + p)
    for team, pts in BASE_TOWERS.items():
        for p in pts:
            if (team,) + p not in have:
                raise SystemExit('declared base tower %r (team %d) not in corpus' % (p, team))
            used.append((team,) + p)
    if sorted(used) != sorted(towers):
        raise SystemExit('lane declaration does not partition the %d corpus towers'
                         % len(towers))

    paths = {}
    for lane in ('TOP', 'MID', 'BOT'):
        r = LANE_TOWERS[(RADIANT, lane)]           # t3, t2, t1 (outward)
        d = LANE_TOWERS[(DIRE, lane)]              # t1, t2, t3 (inward)
        mid = []
        if corners:
            v = corner_vertex(lane)
            if v is not None:
                mid = [v]
        paths[lane] = [ancients[RADIANT]] + r + mid + d + [ancients[DIRE]]
    return paths


def seg_distance(v, a, b):
    """Distance from v to the SEGMENT ab -- same measure as DistanceToSegment
    in jmz_func.lua, so the numbers here are the numbers the predicate sees."""
    abx, aby = b[0] - a[0], b[1] - a[1]
    l2 = abx * abx + aby * aby
    if l2 <= 0:
        return math.hypot(v[0] - a[0], v[1] - a[1])
    t = ((v[0] - a[0]) * abx + (v[1] - a[1]) * aby) / l2
    t = max(0.0, min(1.0, t))
    return math.hypot(v[0] - (a[0] + abx * t), v[1] - (a[1] + aby * t))


def gap_to_lane(v, path):
    """(gap, index of the closest segment)."""
    best, idx = None, -1
    for i in range(len(path) - 1):
        d = seg_distance(v, path[i], path[i + 1])
        if best is None or d < best:
            best, idx = d, i
    return best, idx


def all_gaps(v, paths):
    return {lane: gap_to_lane(v, p) for lane, p in paths.items()}


def min_gap(v, paths):
    g = all_gaps(v, paths)
    lane = min(g, key=lambda k: g[k][0])
    return g[lane][0], lane, g[lane][1]


# The segment that spans from one team's tier-1 to the other's tier-1 is the one
# that crosses a map corner, i.e. the only one where the straight-line polyline
# under-reads.  In the path layout above it is index 3 (anc,t3,t2,t1 | t1,t2,t3,anc).
CORNER_SEGMENT = 3


def main(argv):
    selfcheck = '--selfcheck' in argv
    files, towers, ancients = load_map()
    paths = lane_paths(towers, ancients)

    print('map: %d towers, %d ancients, identical in all %d fixtures carrying buildings'
          % (len(towers), len(ancients), files))
    print()
    hdr = '%-8s %-16s %-9s %5s %8s %8s %8s %9s %5s' % (
        'side', 'camp', 'observed', 'conn', 'TOP', 'MID', 'BOT', 'min', 'lane')
    print(hdr)
    print('-' * len(hdr))
    rows = []
    for side, camp, observed, conn, label in CAMPS + PRECISE:
        g = all_gaps(camp, paths)
        mn, lane, seg = min_gap(camp, paths)
        rows.append((side, camp, observed, conn, mn, lane, seg, label))
        print('%-8s %-16s %-9s %5d %8.0f %8.0f %8.0f %9.0f %5s'
              % (side, '(%d,%d)' % camp, observed, conn,
                 g['TOP'][0], g['MID'][0], g['BOT'][0], mn, lane))

    cleared = [r for r in rows if r[2] == 'CLEARED']
    numerator = [r for r in rows if r[3] > 0]

    # One row per physical camp: the fine centroid supersedes the rounded one.
    firing = {}
    for r in rows:
        if r[2] != 'SURVIVED':
            continue
        key = (r[0], r[3] > 0)
        if key not in firing or r[7]:            # a labelled (precise) row wins
            firing[key] = r
    ranked = sorted(firing.values(), key=lambda r: -r[4])
    survived = ranked
    hi_surv = max(r[4] for r in survived)
    lo_clear = min(r[4] for r in cleared)

    print()
    print('EDGE CONTROL -- does the reconstruction reproduce the observed W7->W8 split?')
    print('  widest camp that KEPT firing : %7.0f' % hi_surv)
    print('  closest camp that went to 0.0: %7.0f' % lo_clear)
    print('  separated by a single threshold: %s  (behaviour brackets the constant '
          'into [%.0f, %.0f))' % ('YES' if hi_surv < lo_clear else 'NO', hi_surv, lo_clear))
    print('  calibration: the 1200 in source sits just BELOW that bracket, so this')
    print('               reconstruction reads ~%.0f-%.0fu wide of the engine at the'
          % (hi_surv - 1200, lo_clear - 1200))
    print('               decision line.  Centroid rounding and the tower chord standing')
    print('               in for the engine\'s 21 samples both live in that gap.  That is')
    print('               why the verdict below is ordinal, not a calibrated comparison.')

    print()
    print('THE QUESTION THE RULING SAYS TO ANSWER FIRST')
    print('  camps that still fire, widest gap first -- tightening removes from the top:')
    for i, r in enumerate(ranked, 1):
        print('    %d. %-8s (%5d,%5d)  gap %6.0f on %s   connects: %d%s'
              % (i, r[0], r[1][0], r[1][1], r[4], r[5], r[3],
                 '   <-- NUMERATOR' if r[3] > 0 else ''))
    top2_are_numerator = all(r[3] > 0 for r in ranked[:2]) \
        and all(r[3] == 0 for r in ranked[2:])
    lo_num = min(r[4] for r in ranked if r[3] > 0)
    hi_zero = max(r[4] for r in ranked if r[3] == 0)

    print()
    verdicts = {}
    for value, why in CANDIDATES:
        kept = [r for r in ranked if r[3] > 0 and r[4] < value]
        verdicts[value] = len(kept)
        print('  PULL_CAMP_LANE_GAP = %4d  (%s)' % (value, why))
        print('      connect-producing camps admitted: %d of %d | firing camps admitted: %d of %d'
              % (len(kept), len([r for r in ranked if r[3] > 0]),
                 len([r for r in ranked if r[4] < value]), len(ranked)))
        if value == 1200:
            print('      (read this row through the calibration: the engine admits BOTH')
            print('       numerator camps at this value -- that is the observed fact the')
            print('       bracket above was derived from, not a prediction of this tool.)')
        else:
            print('      (calibrated, this value lands at ~%.0f-%.0f in these units, so the'
                  % (value + hi_surv - 1200, value + lo_clear - 1200))
            print('       two zero-connect camps may or may not survive it -- the numerator')
            print('       does not, on either end of the bracket.)')

    print()
    if top2_are_numerator:
        print('VERDICT: tightening PULL_CAMP_LANE_GAP is REFUSED.')
        print('  The two camps that produce every connect are the two WIDEST-gap camps')
        print('  still firing (%.0f and %.0f), and the two camps that have never produced'
              % tuple(sorted((r[4] for r in ranked if r[3] > 0), reverse=True)))
        print('  one are the two NARROWEST (%.0f and %.0f).  A distance threshold removes'
              % tuple(sorted((r[4] for r in ranked if r[3] == 0), reverse=True)))
        print('  from the wide end, so any tightening that changes behaviour at all deletes')
        print('  the whole numerator FIRST -- the exact opposite of the intent.  At the')
        print('  proposed p90 the two zero-connect camps sit ON the calibration bracket,')
        print('  so the outcome is either SILENT (all four gone) or, worse to read, poke')
        print('  episodes that keep firing with a numerator of exactly zero.')
        print('  This is ordinal, so it does not depend on the calibration above.')
        print('  Root cause it points at: every camp the engine can pull from sits 1.0-1.3k')
        print('  off the lane while the drag reaches a median 742u / p90 992u.  The two')
        print('  distributions do not overlap, so no constant is both typical and non-empty.')
        print('  The binding constraint is the DRAG, not the filter.')
    else:
        print('VERDICT: unexpected -- re-read before acting.')

    # ---- cross-check under the corner-restored model ------------------------
    # The one row that can be argued with is the radiant numerator camp, whose
    # closest approach lands on the corner chord.  Re-running with the bend
    # restored says how much of the reading was the chord.
    alt = lane_paths(towers, ancients, corners=True)
    print()
    print('CROSS-CHECK -- same camps against a corner-restored polyline')
    alt_rank = []
    for r in ranked:
        a = min_gap(r[1], alt)[0]
        alt_rank.append((a, r))
        print('    %-8s (%5d,%5d)  chorded %6.0f -> corner-restored %6.0f  (%+.0f)  connects: %d'
              % (r[0], r[1][0], r[1][1], r[4], a, a - r[4], r[3]))
    alt_sorted = [r for _a, r in sorted(alt_rank, key=lambda x: -x[0])]
    alt_ordinal = all(r[3] > 0 for r in alt_sorted[:2]) and all(r[3] == 0 for r in alt_sorted[2:])
    print('  order unchanged (numerator still the two widest): %s' % ('YES' if alt_ordinal else 'NO'))
    alt_hi_surv = max(a for a, _r in alt_rank)
    print('  the corner chord moves the widest row by %.0fu -- it is governed by the'
          % (alt_hi_surv - max(r[4] for r in ranked)))
    print('  ordinary tier2-tier1 stretch, so no conclusion here rests on the corner.')
    print('  RESIDUAL, stated rather than smoothed: the widest camp that kept firing reads')
    print('  %.0f, which is ~%.0fu ABOVE the 1200 in source.  Centroid rounding and the'
          % (alt_hi_surv, alt_hi_surv - 1200))
    print('  tower chord standing in for the engine\'s 21 samples both live in that gap;')
    print('  it is not resolvable from here and is not assumed away.  The VERDICT below')
    print('  uses the ORDER, which is identical under both models.')

    if selfcheck:
        assert hi_surv < lo_clear, 'reconstruction does not reproduce the observed split'
        assert alt_ordinal, 'the ordinal claim does not survive the corner-restored model'
        assert top2_are_numerator, (
            'the ordinal claim failed: connect-producing camps are no longer the '
            'widest-gap firing camps')
        assert lo_num > hi_zero, 'numerator/zero-connect gaps overlap'
        assert verdicts[992] == 0 and verdicts[742] == 0, (
            'a proposed tightening no longer removes the whole numerator')
        assert verdicts[1200] >= 1, 'the constant in source removes the whole numerator too'
        corner = [r for r in ranked if r[3] > 0 and r[6] == CORNER_SEGMENT]
        assert len(corner) <= 1, 'both numerator camps read off corner chords'
        print()
        print('selfcheck: OK  (%d numerator row(s) read off a corner chord -- true gap '
              'larger there, conclusion conservative)' % len(corner))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
