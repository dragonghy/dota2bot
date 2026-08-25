#!/usr/bin/env python3
"""Home-ward vs lane-backward for the LANE creep pull -- and why it is NOT the
same defect as its camp-pull sister.

WHY THIS EXISTS
---------------
`J.ShouldCreepPullLane` (bots/FunLib/jmz_func.lua) is LIVE: 'creeppull' and
'pullbeat' were promoted together on 2026-08-23, so every turbo game runs it.
It implements 勾线 -- aggro the enemy wave off an enemy hero, then WALK BACK so
the wave follows you down the lane and the equilibrium resets.  The point it
walks to is built out of `J.GetTeamFountain()`:

    dx, dy   = fountain - wave
    vRetreat = bot + 600 * normalize(dx, dy)

That is the identical substitution `pulldrag` found in the camp-pull sister one
trigger earlier (GH #117, 2026-08-25T07:5xZ): HOME standing in for THE LANE.
There it wasted 81-87% of every step.  This file asks the same question here.

THE ANSWER IS THE OPPOSITE ONE, AND THAT IS THE POINT
-----------------------------------------------------
    VERDICT: REFUSED.  Inside this trigger's own domain the fountain proxy IS
    the lane-backward direction: dot >= 0.97 on every lane, for both teams, and
    under BOTH corner models, from the puller's own tier-2 out to his lane's
    equilibrium.  A 600u home-ward step drags the wave >= 581u down the lane.

The camp pull and the lane pull share a defect SHAPE and not a defect.  The
difference is domain, and it is structural rather than a matter of degree:

  * a camp sits 1.0-1.3k OFF the lane, so the drag must move PERPENDICULAR to
    it, and perpendicular is the one component "toward home" does not have;
  * a wave sits ON the lane, and the puller stands on his OWN half of it --
    `bWavePushedToUs`, the trigger's first disjunct, is literally the statement
    that the wave is on our side of the equilibrium.  On its own half of any
    lane, "toward my fountain" and "backward along this lane" are one ray,
    because that half runs INTO the base the fountain sits in.

    ==> Finding the same defect shape twice is not evidence of a defect twice.
        Before porting a fix to a sister behaviour, intersect the error's domain
        with the TRIGGER's domain: a proxy can be worst exactly where the
        trigger cannot fire and exact where it does.

THE SECOND CRITERION -- WHY THE FIRST READ OF THIS SAID "DEFECT"
----------------------------------------------------------------
    A reconstruction good enough for a DISTANCE can be unusable for a DIRECTION.

The sister file draws each lane straight from tier-1 to tier-1 and showed that
restoring the corner moved its widest camp by 1u, so for a distance the chord is
fine.  For a tangent it is not fine anywhere along that chord: a chord across a
right-angle bend points ~45 degrees away from BOTH stretches it replaces, over
its whole ~4.2-5.4k length.  A first read of this used the narrow own-tier-1 to
equilibrium window, which on a side lane lies almost entirely ON that chord --
and it reported the shipped proxy losing 66-71% of every step (median 0.34
BOT/radiant, 0.29 TOP/dire).  The same window on the corner-restored polyline
reads median 1.00.  The defect was the reconstruction, not the code.  Distance
error is bounded by the sagitta; direction error is not bounded at all.  Both
models are printed below and the flip is asserted, not smoothed.

WHICH MODEL IS THE LANE -- measured from the corpus, not declared
------------------------------------------------------------------
The bend is not an assumption; the towers measure it.  A lane's two tower
stretches (radiant t3->t1 and dire t1->t3) meet at

    TOP 88.9 deg     BOT 91.0 deg     MID 1.8 deg

so the side lanes turn a right angle and mid does not.  Same 22 tower
coordinates every fixture carries, all 61 building-carrying fixtures agreeing on
every one exactly; the loader and the corner rule are imported from the sister
file rather than copied.

WHAT `dot` IS
-------------
At a point p on the lane, `back` is the unit tangent toward our own ancient and
`f` is the unit vector toward our fountain.  dot = f . back, so a 600u step
toward the fountain drags the wave 600*dot units backward ALONG the lane and
600*sqrt(1-dot^2) units sideways off it.  dot = 1: the proxy is exactly right.

THE FOUR WINDOWS THIS FILE REPORTS
----------------------------------
  TRIGGER DOMAIN  own tier-2 -> equilibrium, minus one 600u drag step at the
                  bend.  This is where a laning pull happens: `bWavePushedToUs`
                  puts the wave on our half, and a wave behind our own tier-2
                  inside the first 6 minutes is not a lane to be reset.  The
                  refusal is stated on this window, and only on it.
  THE CHORD       between the two tier-1s -- the corner region.  Nobody's own
                  half.
  own t1..equilib the window a first read used.  Reported because it is where
                  the two corner models FLIP; on a side lane it is short (n=15
                  to 38 samples) and sits on the chord in the chorded model, so
                  its sample count is printed beside it.  Read its MEDIAN: the
                  window stops AT the bend, so its min is the bend sliver every
                  time, for whichever team owns the leg.
  PAST THE EQ.    the enemy's half, out to their tier-2.  The residual.

THE RESIDUAL, REGISTERED RATHER THAN ROUNDED AWAY
-------------------------------------------------
Past the equilibrium the proxy really is close to perpendicular for the team
whose half it is not (min 0.07-0.12 on both side lanes, both models).
`bWavePushedToUs`
cannot put a pull there -- but the trigger's other two disjuncts, `bZoned` and
`bMeleeVs2Ranged`, say nothing about where the wave is, so a pull fired by those
CAN.  Nothing here refutes that.

  ==> The open question is empirical and free: of the shipped pull episodes,
      what share happens past its lane's arc midpoint?  Measurable in .dem
      already bought (W3 spot_20260823_1809*, where 'creeppull' was armed and
      the replay desk already located every episode -- GH #143 / 2026-08-23
      21:00Z).  If the share is material the lever comes back WITH a domain; if
      it is ~0 it stays dead.  test_set.md AX.2 forbids requesting a wave for a
      lever whose domain has not been measured when it can be measured for free,
      and this one can.

Usage:
    python3 tools/agent/lane_drag_direction.py [--selfcheck]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pullcamp_lane_geometry as camp  # noqa: E402  (map loader + corner rule)

RADIANT, DIRE = camp.RADIANT, camp.DIRE
TEAM_NAME = {RADIANT: 'radiant', DIRE: 'dire'}

# bots/FunLib/jmz_func.lua:8-9 -- the vectors J.GetTeamFountain() hands back.
FOUNTAIN = {RADIANT: (-6619.0, -6336.0), DIRE: (6928.0, 6372.0)}

# The drag step in J.ShouldCreepPullLane's retreat point.
STEP = 600.0

# One drag step either side of the bend is held out of the trigger window and
# reported separately.  The tangent turns 90 degrees there, so a reading inside
# it is a statement about which side of the corner the sample landed on, not
# about the lane.  Holding it out makes the refusal weaker, which is the right
# direction for a claim to be wrong in.
BEND_SLIVER = STEP

SAMPLE = 25.0


def lane_path(ancients, lane, corners):
    r = list(camp.LANE_TOWERS[(RADIANT, lane)])
    d = list(camp.LANE_TOWERS[(DIRE, lane)])
    mid = []
    if corners:
        v = camp.corner_vertex(lane)
        if v is not None:
            mid = [v]
    return [ancients[RADIANT]] + r + mid + d + [ancients[DIRE]]


def arc_lengths(path):
    cum = [0.0]
    for i in range(len(path) - 1):
        cum.append(cum[-1] + math.hypot(path[i + 1][0] - path[i][0],
                                        path[i + 1][1] - path[i][1]))
    return cum


def point_at(path, cum, s):
    """(point, unit tangent) at arc length s, tangent pointing radiant->dire."""
    s = max(0.0, min(cum[-1], s))
    for i in range(len(path) - 1):
        seg = cum[i + 1] - cum[i]
        if seg <= 0:
            continue
        if s <= cum[i + 1] or i == len(path) - 2:
            f = (s - cum[i]) / seg
            a, b = path[i], path[i + 1]
            return ((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f),
                    ((b[0] - a[0]) / seg, (b[1] - a[1]) / seg))
    raise AssertionError('arc length %r off the path' % s)


def dot_at(path, cum, s, team):
    """f . back at arc length s -- see WHAT `dot` IS in the header."""
    p, u = point_at(path, cum, s)
    back = (-u[0], -u[1]) if team == RADIANT else (u[0], u[1])
    fx, fy = FOUNTAIN[team]
    dx, dy = fx - p[0], fy - p[1]
    m = math.hypot(dx, dy)
    if m < 1.0:
        return None
    return (dx / m) * back[0] + (dy / m) * back[1]


def arc_of(path, cum, pt):
    """Arc length of the point on the path closest to pt."""
    best, bs, s = None, 0.0, 0.0
    while s <= cum[-1]:
        p, _ = point_at(path, cum, s)
        d = math.hypot(p[0] - pt[0], p[1] - pt[1])
        if best is None or d < best:
            best, bs = d, s
        s += SAMPLE
    return bs


def scan(path, cum, team, lo, hi):
    out, s = [], lo
    while s <= hi:
        d = dot_at(path, cum, s, team)
        if d is not None:
            out.append(d)
        s += SAMPLE
    return sorted(out)


def survey(ancients, corners):
    rows = {}
    for lane in ('TOP', 'MID', 'BOT'):
        path = lane_path(ancients, lane, corners)
        cum = arc_lengths(path)
        eq = cum[-1] / 2.0
        t1 = {t: arc_of(path, cum, camp.LANE_TOWERS[(t, lane)][2 if t == RADIANT else 0])
              for t in (RADIANT, DIRE)}
        t2 = {t: arc_of(path, cum, camp.LANE_TOWERS[(t, lane)][1])
              for t in (RADIANT, DIRE)}
        for team in (RADIANT, DIRE):
            other = DIRE if team == RADIANT else RADIANT
            if team == RADIANT:
                band = scan(path, cum, team, t2[team], eq - BEND_SLIVER)
                past = scan(path, cum, team, eq + BEND_SLIVER, t2[other])
            else:
                band = scan(path, cum, team, eq + BEND_SLIVER, t2[team])
                past = scan(path, cum, team, t2[other], eq - BEND_SLIVER)
            # The narrow window a first read of this used: own tier-1 out to
            # the equilibrium.  Reported because it is where the two corner
            # models FLIP -- in the chorded model it lies almost entirely on the
            # chord, in the restored model almost entirely on the own-side leg.
            # Short by construction (a side lane's own tier-1 sits close to the
            # equilibrium), so its sample count is printed with it.
            t1band = (scan(path, cum, team, t1[team], eq) if team == RADIANT
                      else scan(path, cum, team, eq, t1[team]))
            rows[(lane, team)] = {
                'band': band,
                'past': past,
                't1band': t1band,
                'chord': scan(path, cum, team, t1[RADIANT], t1[DIRE]),
            }
    return rows


def mm(vals):
    """'min/med' of a sorted window, or a visible marker when it is empty.

    Empty is printed, never dashed away: "the proxy is fine here" and "this
    window reached no samples" must not read the same.
    """
    if not vals:
        return '  EMPTY WINDOW '
    return 'min %.2f med %.2f' % (vals[0], vals[len(vals) // 2])


def fmt(rows, title):
    print(title)
    print('  %-4s %-8s | %-33s | %-16s | %-16s | %s'
          % ('lane', 'team', 'TRIGGER DOMAIN  own t2..equilibrium',
             'THE CHORD t1..t1', 'own t1..equilib.', 'PAST THE EQ.'))
    for lane in ('TOP', 'MID', 'BOT'):
        for team in (RADIANT, DIRE):
            r = rows[(lane, team)]
            b = r['band']
            back = '%3du/%du back' % (round(STEP * b[0]), int(STEP)) if b else ''
            print('  %-4s %-8s | %-17s %-15s | %-16s | %-16s | %s  (n=%d)'
                  % (lane, TEAM_NAME[team], mm(b), back, mm(r['chord']),
                     mm(r['t1band']), mm(r['past']), len(r['t1band'])))
    print()


def worst(rows, key):
    vals = [rows[(lane, t)][key][0]
            for lane in ('TOP', 'MID', 'BOT') for t in (RADIANT, DIRE)
            if rows[(lane, t)][key]]
    return min(vals) if vals else float('nan')


def worst_med(rows, key):
    """Lowest MEDIAN across the six lane/team rows.

    The own-t1 window necessarily runs right up to the bend, so its MIN is the
    bend sliver for whichever team owns the leg -- an integer-edge artifact of
    where the window stops, not a reading about the window.  The median is the
    quantity that separates the two corner models here, and per GH #148(ii) the
    counts it is taken over are printed beside it.
    """
    vals = [rows[(lane, t)][key][len(rows[(lane, t)][key]) // 2]
            for lane in ('TOP', 'MID', 'BOT') for t in (RADIANT, DIRE)
            if rows[(lane, t)][key]]
    return min(vals) if vals else float('nan')


def main(argv):
    selfcheck = '--selfcheck' in argv
    files, towers, ancients = camp.load_map()
    # Run the sister file's declaration check for its side effect: it raises if
    # any declared lane tower is absent from the corpus, or if the three lanes
    # plus the two base towers do not partition all 22 exactly.  This file builds
    # its own polylines and would otherwise happily measure a mis-filed lane --
    # caught by the (c) reverse case in tests/test_lane_drag_direction.py, which
    # is why the call is here and not merely implied.
    camp.lane_paths(towers, ancients)
    print('map: %d fixtures carry buildings and agree on all %d towers\n'
          % (files, len(towers)))

    print('IS THERE A BEND?  the angle between a lane\'s two tower stretches')
    angles = {}
    for lane in ('TOP', 'MID', 'BOT'):
        r, d = camp.LANE_TOWERS[(RADIANT, lane)], camp.LANE_TOWERS[(DIRE, lane)]
        a = (r[2][0] - r[0][0], r[2][1] - r[0][1])
        b = (d[2][0] - d[0][0], d[2][1] - d[0][1])
        c = (a[0] * b[0] + a[1] * b[1]) / (math.hypot(*a) * math.hypot(*b))
        angles[lane] = math.degrees(math.acos(max(-1.0, min(1.0, c))))
        v = camp.corner_vertex(lane)
        print('  %-4s %6.1f deg   corner vertex: %s'
              % (lane, angles[lane],
                 'none' if v is None else '(%d,%d)' % (round(v[0]), round(v[1]))))
    print('  ==> the side lanes turn a right angle; mid does not.')
    print()

    restored = survey(ancients, corners=True)
    chorded = survey(ancients, corners=False)
    fmt(restored, 'CORNER-RESTORED polyline -- the lane the towers describe')
    fmt(chorded, 'CHORDED polyline -- the sister file\'s model, kept to show what it does here')

    w_r, w_c = worst(restored, 'band'), worst(chorded, 'band')
    c_r, c_c = worst(restored, 'chord'), worst(chorded, 'chord')
    p_r = worst(restored, 'past')
    n_r = worst_med(restored, 't1band')
    n_c = worst_med(chorded, 't1band')

    print('VERDICT: porting the `pulldrag` rewrite to J.ShouldCreepPullLane is REFUSED.')
    print('  In the trigger\'s own domain the fountain proxy already IS the lane-backward')
    print('  direction.  Worst reading anywhere from a puller\'s tier-2 to his lane\'s')
    print('  equilibrium: %.2f corner-restored, %.2f chorded -- a %du step drags the wave'
          % (w_r, w_c, int(STEP)))
    print('  %du down the lane at worst.  BOTH corner models agree, so the refusal does'
          % round(STEP * min(w_r, w_c)))
    print('  not depend on the reconstruction at all.')
    print()
    print('  Where the models flip is the narrow own-t1..equilibrium window: lowest')
    print('  MEDIAN across the six rows is %.2f restored vs %.2f chorded.  (Median, not'
          % (n_r, n_c))
    print('  min: that window stops AT the bend, so its min is always the bend sliver.)')
    print('  In the restored model that window sits on the')
    print('  own-side leg of the bend; in the chorded model it sits on the chord, whose')
    print('  tangent is a 45-degree diagonal no creep walks.  That is the whole reason a')
    print('  first read of this looked like a defect, and it is why the refusal is stated')
    print('  on the t2 window, which both models populate off the corner.')
    print()
    print('  RESIDUAL, not refuted: past the equilibrium the proxy reads %.2f -- close to'
          % p_r)
    print('  perpendicular.  Only `bZoned` / `bMeleeVs2Ranged` can fire a pull there.')
    print('  Measure that share off the W3 .dem before requesting anything (AX.2).')
    print()

    if not selfcheck:
        return 0

    fails = []

    def check(ok, msg):
        if not ok:
            fails.append(msg)

    # 1. The bend, from the corpus.  This is what makes the corner-restored model
    #    the lane rather than a preference -- and what makes the chord unusable
    #    for a tangent.
    for lane in ('TOP', 'BOT'):
        check(80.0 < angles[lane] < 100.0,
              '%s tower stretches meet at %.1f deg -- the right-angle bend this file '
              'rests on is not there' % (lane, angles[lane]))
        check(camp.corner_vertex(lane) is not None, '%s lost its corner vertex' % lane)
    check(angles['MID'] < 15.0,
          'mid tower stretches meet at %.1f deg -- mid is supposed to be straight'
          % angles['MID'])
    check(camp.corner_vertex('MID') is None,
          'mid was given a corner vertex; a spurious one reverses the tangent')

    # 2. THE VERDICT.  Every lane, every team, both models.  Each window must be
    #    non-empty and reasonably long: "the proxy is fine" and "the scan reached
    #    nothing" must not be the same line on paper.
    for name, rows in (('corner-restored', restored), ('chorded', chorded)):
        for lane in ('TOP', 'MID', 'BOT'):
            for team in (RADIANT, DIRE):
                b = rows[(lane, team)]['band']
                check(len(b) >= 100,
                      '%s %s/%s: trigger domain scanned %d samples -- a refusal must '
                      'not rest on a short window'
                      % (name, lane, TEAM_NAME[team], len(b)))
                if b:
                    check(b[0] >= 0.96,
                          '%s %s/%s: the proxy reads %.3f inside the trigger domain -- '
                          'the refusal was written against >= 0.96'
                          % (name, lane, TEAM_NAME[team], b[0]))

    # 3. The residual is real and is NOT being claimed away.  If this ever passes
    #    0.5 the registered open question is stale and the handoff must be pulled.
    for lane in ('TOP', 'BOT'):
        bad = [t for t in (RADIANT, DIRE)
               if restored[(lane, t)]['past'] and restored[(lane, t)]['past'][0] < 0.5]
        check(len(bad) >= 1,
              '%s: nothing past the equilibrium reads badly any more -- the residual '
              'this file registers has gone away' % lane)

    # 4. The second criterion, kept honest: the two models must actually reverse
    #    each other ON THE CHORD, or the worked example is gone and the criterion
    #    has to be re-argued rather than repeated.
    check(n_r >= 0.90,
          'the own-t1..equilibrium window no longer reads clean under the restored '
          'model (median %.2f) -- the flip this file documents has changed shape' % n_r)
    check(n_c <= 0.5,
          'the chorded model no longer manufactures a defect on that window (%.2f); '
          'the "a chord keeps proximity and loses the tangent" example has lost its '
          'teeth and must be re-argued rather than repeated' % n_c)
    check(c_c <= 0.5 and c_r <= 0.5,
          'the chord stretch no longer reads badly in either model (%.2f / %.2f)'
          % (c_r, c_c))

    # 5. Mid is the negative control for the corner story: no bend, so both
    #    models must read the same there, on every window.
    for team in (RADIANT, DIRE):
        for key in ('band', 'chord', 't1band', 'past'):
            a = restored[('MID', team)][key]
            c = chorded[('MID', team)][key]
            check(a and c and abs(a[0] - c[0]) < 0.01,
                  'mid/%s %s reads %.3f restored vs %.3f chorded -- a lane with no bend '
                  'must not care which corner model is used'
                  % (TEAM_NAME[team], key, a[0] if a else -1, c[0] if c else -1))

    # 6. The loader really is the sister file's, and really did check the map.
    check(len(towers) == 22, 'expected 22 corpus towers, got %d' % len(towers))
    check(files >= 20, 'only %d fixtures carried buildings' % files)

    if fails:
        for f in fails:
            print('FAIL: %s' % f)
        return 1
    print('selfcheck: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
