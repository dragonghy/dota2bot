#!/usr/bin/env python3
"""Ratchet for the GH #117 camp-geometry refusal, and for the lever that replaced it.

WHAT IS BEING PROTECTED
-----------------------
The director's 2026-08-25T07:xxZ ruling (owner P1 DoD step 4) said to tighten
`PULL_CAMP_LANE_GAP` from 1200 to a typical drag length (p90 992 / median 742),
and said the geometry had to be checked FIRST because the two connect-producing
camps are the whole numerator.  `tools/agent/pullcamp_lane_geometry.py` ran that
check against the corpus' own map and the answer was REFUSE: those two camps are
the two WIDEST-gap camps still firing, so a distance threshold deletes the
numerator before it deletes anything else.

A refusal is worth exactly as much as its ability to survive the next person who
reads the ruling and not the answer.  So:

  LAYER 1 -- the constant.  `PULL_CAMP_LANE_GAP` must still read 1200.  Tighten
  it and this file goes red naming the refusal, rather than the change landing
  quietly and the connect numerator going to zero in a wave nobody attributes.

  LAYER 2 -- the geometry.  The tool's own --selfcheck must pass: the
  reconstruction still reproduces the observed W7->W8 camp split, the ordinal
  claim still holds, and it holds under the corner-restored polyline too.

  LAYER 3 -- the lever that took the tightening's place.  `pulldrag` must stay
  gated, and gated STANDALONE.  Writing it as `IsSoakCandidate('pulldrag') and
  IsSoakCandidate('pullcamp')` would freeze it FALSE the day `pullcamp` is
  promoted -- the failure this repo has already paid for once (`pullcad`), and
  the one where `check_armed_wiring.py` still reports WIRED while the lever is a
  byte-for-byte no-op.

  LAYER 4 -- the reverse assertions.  A checker that cannot fail is not a
  checker.  Each mutation below breaks one input and asserts the tool notices.

Usage:  python3 tests/test_pullcamp_lane_geometry.py
"""

import io
import os
import re
import sys
import contextlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'agent'))

import pullcamp_lane_geometry as geo   # noqa: E402

JMZ = os.path.join(ROOT, 'bots', 'FunLib', 'jmz_func.lua')
ROAM = os.path.join(ROOT, 'bots', 'mode_roam_generic.lua')

failures = []


def check(name, cond, detail=''):
    if cond:
        print('  ok   %s' % name)
    else:
        print('  FAIL %s   %s' % (name, detail))
        failures.append(name)


def run_tool(argv=('--selfcheck',)):
    """(ok, stdout).  The tool asserts internally; an AssertionError is a fail."""
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            geo.main(list(argv))
        return True, buf.getvalue()
    except (AssertionError, SystemExit) as exc:
        return False, buf.getvalue() + '\n' + repr(exc)


def main():
    src = open(JMZ).read()
    roam = open(ROAM).read()

    # ---- LAYER 1: the constant the refusal is about ------------------------
    print('layer 1 -- the constant')
    m = re.search(r'^local PULL_CAMP_LANE_GAP = (\d+)$', src, re.M)
    check('PULL_CAMP_LANE_GAP is declared', m is not None)
    if m:
        check('PULL_CAMP_LANE_GAP is still 1200', m.group(1) == '1200',
              'reads %s -- if this was a deliberate tightening, read the REFUSED '
              'verdict in tools/agent/pullcamp_lane_geometry.py first: the two '
              'camps that produce every connect are the two widest-gap camps '
              'still firing, so tightening removes the numerator first'
              % m.group(1))

    # ---- LAYER 2: the geometry answer -------------------------------------
    print('layer 2 -- the geometry')
    ok, out = run_tool()
    check('pullcamp_lane_geometry --selfcheck passes', ok, out[-400:])
    check('verdict is still REFUSED', 'VERDICT: tightening PULL_CAMP_LANE_GAP is REFUSED' in out)
    check('the map is still constant across the corpus',
          re.search(r'identical in all \d+ fixtures', out) is not None)
    check('the observed W7->W8 split is still reproduced',
          'separated by a single threshold: YES' in out)
    check('the ordinal claim survives the corner-restored model',
          'order unchanged (numerator still the two widest): YES' in out)

    # ---- LAYER 3: the lever that replaced the tightening -------------------
    print('layer 3 -- the pulldrag lever')
    check('J.GetLanePullDragTarget exists',
          'function J.GetLanePullDragTarget( bot, vCamp )' in src)
    body = src.split('function J.GetLanePullDragTarget( bot, vCamp )', 1)
    body = body[1].split('\nend\n', 1)[0] if len(body) > 1 else ''
    check("gated on 'pulldrag'", "J.IsSoakCandidate( 'pulldrag' )" in body)
    check('turbo-only', 'J.IsModeTurbo()' in body)
    check("gate is STANDALONE (no conjunction with another candidate id)",
          len(re.findall(r"IsSoakCandidate\(\s*'(\w+)'\s*\)", body)) == 1,
          'a second candidate id inside this gate freezes it FALSE the day that '
          'id is promoted')
    check('unreadable lane falls back rather than muting the pull',
          'if nLane == nil then return nil end' in body)
    check('the drag site consumes it',
          'J.GetLanePullDragTarget(bot, bot.roamCampPull)' in roam)
    check('the drag site keeps the shipped fountain walk as the fallback',
          re.search(r'local vB, vF = bot:GetLocation\(\), J\.GetTeamFountain\(\)',
                    roam) is not None)
    # The two constants of the drag cadence are NOT this lever's business.
    check('poke cadence 3.0s untouched', 'now - bot.campPullAttackTime > 3.0' in roam)
    check('500u step length untouched', 'dx / n * 500' in roam)

    # ---- LAYER 4: reverse assertions -- does any of this have teeth? -------
    print('layer 4 -- reverse (each must make the tool complain)')
    saved_camps = list(geo.CAMPS)
    saved_precise = list(geo.PRECISE)
    saved_towers = dict(geo.LANE_TOWERS)

    # (a) If a zero-connect camp were the widest, the ordinal claim is false and
    #     the refusal would not follow.  Move one out to a gap of ~1250 -- past
    #     the numerator (1220) but still inside the cleared camps' floor (1282),
    #     so this mutation breaks ONLY the ordinal claim and not the edge control
    #     that (b) tests.  Isolation is the point: two reverse cases that trip
    #     the same assertion are one reverse case.
    geo.CAMPS = [(s, ((-800, 4769) if (s == 'dire' and (x, y) == (-800, 5000)) else (x, y)),
                  o, c, l) for (s, (x, y), o, c, l) in saved_camps]
    ok, out = run_tool()
    check('(a) a wider zero-connect camp breaks the ordinal claim', not ok)
    geo.CAMPS = list(saved_camps)

    # (b) A camp table where a cleared camp sits inside the firing ones breaks
    #     the edge control -- the reconstruction would no longer explain W7->W8.
    geo.CAMPS = [(s, ((-4007, 4900) if (s == 'dire' and (x, y) == (-2600, 3800)) else (x, y)),
                  o, c, l) for (s, (x, y), o, c, l) in saved_camps]
    ok, out = run_tool()
    check('(b) an interleaved cleared camp breaks the edge control', not ok)
    geo.CAMPS = list(saved_camps)

    # (c) A mis-filed tower must be caught by the corpus check, not absorbed.
    geo.LANE_TOWERS = dict(saved_towers)
    geo.LANE_TOWERS[(geo.DIRE, 'TOP')] = [(-5275, 6036), (-128, 6016), (3552, 5777)]
    ok, out = run_tool()
    check('(c) a tower coordinate that is not in the corpus is rejected', not ok)
    geo.LANE_TOWERS = dict(saved_towers)

    # (d) Control: with everything restored the tool is green again, so the
    #     three reds above are the mutations and not a wedged module.
    geo.PRECISE = list(saved_precise)
    ok, out = run_tool()
    check('(d) control -- restored inputs pass again', ok, out[-300:])

    print()
    if failures:
        print('%d FAILED: %s' % (len(failures), ', '.join(failures)))
        return 1
    print('all checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
