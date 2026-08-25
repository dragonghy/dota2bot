#!/usr/bin/env python3
"""Ratchet for the 2026-08-25 REFUSAL to port `pulldrag` to the lane creep pull.

WHAT IS BEING PROTECTED
-----------------------
`pulldrag` (GH #117, 2026-08-25T07:5xZ) found that the CAMP pull walks toward
`J.GetTeamFountain()` while its own comment says it means the lane, and measured
that proxy wasting 81-87% of every step.  `J.ShouldCreepPullLane` -- LIVE since
'creeppull'/'pullbeat' were promoted on 2026-08-23 -- contains the identical
substitution, so porting the fix is the obvious next move.

`tools/agent/lane_drag_direction.py` measured it and the answer is REFUSE: in
that trigger's own domain the fountain proxy already IS the lane-backward
direction (dot >= 0.97, both teams, all three lanes, both corner models).  The
camp pull is a real defect because a camp sits OFF the lane; a wave sits ON it,
and `bWavePushedToUs` says the wave is on OUR half -- the half that runs into
the base the fountain is in.

A refusal is worth exactly what it can survive.  The next reader of this repo
sees `pulldrag`'s write-up, sees the same expression in the lane pull, and ports
it.  This file is what stops that from landing silently.

  LAYER 1 -- the shipped code the refusal is a statement ABOUT.  The retreat
  point must still be the fountain expression, the step must still be 600, and
  there must be NO soak candidate wired into it.  Any of those changing means
  somebody acted on the shape without reading the verdict.

  LAYER 2 -- the measurement.  The tool's --selfcheck must pass and its verdict
  line must still read REFUSED.  That check covers the trigger-domain readings,
  the corpus-measured right-angle bend, the mid-lane negative control, and the
  flip between the two corner models.

  LAYER 3 -- the residual.  The refusal is NOT "this is fine everywhere": past
  the equilibrium the proxy really is near-perpendicular, and `bZoned` /
  `bMeleeVs2Ranged` can fire a pull there.  Those two disjuncts must still exist
  in the Lua, because they are the premise of the open question handed to the
  replay desk.  If they ever go away, the handoff must go away with them.

  LAYER 4 -- reverse assertions.  A checker that cannot fail is not a checker.

Usage:  python3 tests/test_lane_drag_direction.py
"""

import contextlib
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'agent'))

import lane_drag_direction as geo      # noqa: E402
import pullcamp_lane_geometry as camp  # noqa: E402

JMZ = os.path.join(ROOT, 'bots', 'FunLib', 'jmz_func.lua')

failures = []


def check(name, cond, detail=''):
    if cond:
        print('  ok   %s' % name)
    else:
        print('  FAIL %s   %s' % (name, detail))
        failures.append(name)


def run_tool(argv=('--selfcheck',)):
    """(ok, stdout).  Non-zero exit or an exception is a fail."""
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            rc = geo.main(list(argv))
        return rc == 0, buf.getvalue()
    except (AssertionError, SystemExit) as exc:
        return False, buf.getvalue() + '\n' + repr(exc)


def pull_body(src):
    body = src.split('function J.ShouldCreepPullLane( bot )', 1)
    return body[1].split('\nend\n', 1)[0] if len(body) > 1 else ''


def main():
    src = open(JMZ).read()
    body = pull_body(src)

    # ---- LAYER 1: the shipped code the refusal is about --------------------
    print('layer 1 -- the shipped lane pull')
    check('J.ShouldCreepPullLane still exists', body != '')
    check('its retreat point is still built from the fountain',
          'local vFountain = J.GetTeamFountain()' in body
          and 'vFountain.x - vWave.x' in body,
          'the expression the refusal is about has changed -- re-run '
          'tools/agent/lane_drag_direction.py before trusting either')
    check('the drag step is still 600', re.search(r'dx / nMag \* 600', body) is not None)
    check('no soak candidate has been wired into the retreat point',
          "IsSoakCandidate" not in body.split('-- Retreat point:', 1)[-1],
          'somebody gated a lane-backward retreat here.  Read the REFUSED verdict '
          'in tools/agent/lane_drag_direction.py first: inside this trigger\'s own '
          'domain the fountain proxy already IS the lane-backward direction, so '
          'such a lever is inert by construction and a wave spent on it buys a '
          'reading shaped exactly like a frozen gate')

    # The camp-pull lever must NOT have been reused here.  It answers "closest
    # point on the lane to a CAMP", which for a wave already on the lane is the
    # wave itself -- a zero-length step, i.e. the pull would stop dragging.
    check('J.GetLanePullDragTarget is not called from the lane pull',
          'J.GetLanePullDragTarget' not in body,
          'the camp lever returns the closest lane point to its argument; for a '
          'wave already on the lane that is a zero-length drag')

    # ---- LAYER 2: the measurement -----------------------------------------
    print('layer 2 -- the geometry answer')
    ok, out = run_tool()
    check('lane_drag_direction --selfcheck passes', ok, out[-500:])
    check('the verdict is still REFUSED',
          'REFUSED' in out and 'J.ShouldCreepPullLane' in out)
    check('the map is still constant across the corpus',
          re.search(r'agree on all \d+ towers', out) is not None)
    check('the corpus still measures a right-angle bend on both side lanes',
          camp.corner_vertex('TOP') is not None and camp.corner_vertex('BOT') is not None)
    check('mid is still bendless -- the negative control for the corner story',
          camp.corner_vertex('MID') is None)
    check('the sister camp tool is still green with the shared corner rule',
          run_camp_tool())

    # ---- LAYER 3: the residual, which is NOT refuted -----------------------
    print('layer 3 -- the registered residual')
    check('the tool still prints the residual rather than a clean bill',
          'RESIDUAL' in out)
    check('bZoned still exists -- the residual\'s premise',
          'local bZoned = J.IsLaneZonedByEnemy(' in body)
    check('bMeleeVs2Ranged still exists -- the residual\'s other premise',
          'bMeleeVs2Ranged = true' in body)
    check('the wave-pushed disjunct, which is what makes the refusal true, is intact',
          'bWavePushedToUs = nEnemyFront > nOurFront' in body,
          'the refusal rests on this clause putting the wave on OUR half; if the '
          'trigger no longer says that, the domain argument has to be redone')

    # ---- LAYER 4: reverse assertions --------------------------------------
    print('layer 4 -- reverse (each must make the tool complain)')
    saved_fount = dict(geo.FOUNTAIN)
    saved_towers = dict(camp.LANE_TOWERS)
    saved_corner = camp.corner_vertex

    # (a) Move a fountain to the map centre.  "Toward home" then points across
    #     the map from everywhere and the trigger-domain readings must collapse.
    #     This is the assertion that carries the whole verdict, so it needs a
    #     mutation that only it can catch.
    geo.FOUNTAIN = dict(saved_fount)
    geo.FOUNTAIN[geo.RADIANT] = (0.0, 0.0)
    ok, _out = run_tool()
    check('(a) a fountain in the map centre breaks the trigger-domain claim', not ok)
    geo.FOUNTAIN = dict(saved_fount)

    # (b) Accept the mid-lane "corner".  Mid has no bend, so a vertex there makes
    #     the restored polyline double back and the mid negative control -- the
    #     one that says a bendless lane must not care which model is used -- has
    #     to notice.  Separate from (a) on purpose: two reverse cases that trip
    #     the same assertion are one reverse case.
    camp.corner_vertex = lambda lane: (
        camp.line_intersection(camp.LANE_TOWERS[(camp.RADIANT, lane)][1],
                               camp.LANE_TOWERS[(camp.RADIANT, lane)][2],
                               camp.LANE_TOWERS[(camp.DIRE, lane)][0],
                               camp.LANE_TOWERS[(camp.DIRE, lane)][1]))
    ok, _out = run_tool()
    check('(b) a spurious mid-lane corner is caught', not ok)
    camp.corner_vertex = saved_corner

    # (c) A mis-filed tower must be rejected by the shared loader, not absorbed
    #     into a slightly wrong lane.
    camp.LANE_TOWERS = dict(saved_towers)
    camp.LANE_TOWERS[(camp.RADIANT, 'BOT')] = [(-3952, -6112), (-360, -6256), (4860, -6378)]
    ok, _out = run_tool()
    check('(c) a tower coordinate that is not in the corpus is rejected', not ok)
    camp.LANE_TOWERS = dict(saved_towers)

    # (d) Control.
    ok, out = run_tool()
    check('(d) control -- restored inputs pass again', ok, out[-300:])

    print()
    if failures:
        print('%d FAILED: %s' % (len(failures), ', '.join(failures)))
        return 1
    print('all checks passed')
    return 0


def run_camp_tool():
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            return camp.main(['--selfcheck']) == 0
    except (AssertionError, SystemExit):
        return False


if __name__ == '__main__':
    sys.exit(main())
