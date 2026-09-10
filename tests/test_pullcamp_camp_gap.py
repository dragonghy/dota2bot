#!/usr/bin/env python3
"""Ratchet for `tools/batch_test/behavioral/pullcamp_camp_gap.py`.

WHAT IS BEING PROTECTED
-----------------------
The `>1200u` fraction and the connecting camps' gaps are the two numbers the
replay desk's GH #712 handoff rests on, and the whole reason that reading was
weak the first time was `n=3` -- i.e. the cure is re-running it on the next
wave.  A reading that is re-run must be a reading that cannot drift silently,
so each of the tool's three load-bearing choices gets an assertion AND a
mutation that breaks it:

  LAYER 1 -- MINIMUM over the three lanes, not the assigned lane.  This is what
  makes `> gap` a LOWER bound on refusals.  Swap it for a maximum or for one
  fixed lane and the bound flips direction while the printed table still looks
  like a table.

  LAYER 2 -- the camp comes from the episode's FIRST poke frame.  An episode
  spans several frames and the bot can be nearer a different camp later; taking
  the last frame would measure a camp the selector never chose.

  LAYER 3 -- the blind band is REPORTED, not folded away.  An episode inside
  the reconstruction's own error at the decision line must be visible as such;
  counting it silently on either side of the constant is the failure the
  geometry module's calibration paragraph exists to prevent.

  LAYER 4 -- reverse assertions.  A checker that cannot fail is not a checker,
  so every layer above is re-run against a deliberately broken input and must
  come out different.

Usage:  python3 tests/test_pullcamp_camp_gap.py
"""

import io
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral', 'pullcamp_camp_gap.py')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'agent'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))

import pullcamp_lane_geometry as geo          # noqa: E402
import pullcamp_camp_gap as tool              # noqa: E402

failures = []


def check(name, cond, extra=''):
    print('%-4s %s%s' % ('ok' if cond else 'FAIL', name,
                         '' if cond else '   <- ' + str(extra)))
    if not cond:
        failures.append(name)


def frame(t, camp, hero='npc_dota_hero_lion', game='g1', leg='armed',
          poke=True, connect=False, sweep='/tmp/sweep_abc123', strict=True):
    return dict(sweep=sweep, game=game, seed=1, hero=hero, pos=5, leg=leg,
                t=t, hp=0.9, x=camp[0], y=camp[1], camp_d=50,
                strict=strict, clean=True, camp_x=camp[0], camp_y=camp[1],
                approach=0, at_camp=True, approached=True, poke=poke,
                drag=False, connect_own=connect, connect_enemy=False)


def write_rows(rows):
    fd, path = tempfile.mkstemp(suffix='.jsonl')
    with os.fdopen(fd, 'w') as fh:
        for r in rows:
            fh.write(json.dumps(r) + '\n')
    return path


def run_tool(path, gap=1200.0, include_enemy=False):
    """Run main() in-process, capturing stdout.

    NOT through a pipe with a read exit code -- evidence discipline 3.  The
    exit code here is the tool raising, which propagates as an exception.
    """
    argv = sys.argv
    out = io.StringIO()
    sys.argv = ['pullcamp_camp_gap.py', '--rows', path, '--gap', str(gap)]
    if include_enemy:
        sys.argv.append('--include-enemy-camps')
    saved = sys.stdout
    sys.stdout = out
    try:
        tool.main()
    finally:
        sys.stdout = saved
        sys.argv = argv
    return out.getvalue()


def armed_line(text):
    for line in text.splitlines():
        if line.startswith('armed'):
            return line
    return ''


def main():
    paths = geo.lane_paths(*geo.load_map()[1:])

    # A camp far from every lane and a camp sitting on one.  Coordinates are
    # taken from the geometry module's own measured camp list so the test is
    # anchored to the same map as the tool, not to invented geometry.
    far = (-4000, 1000)      # CLEARED in the W7->W8 split; min gap 2383
    near = (3994, -5137)     # SURVIVED, connect-producing; min gap 1220
    g_far = geo.min_gap(far, paths)[0]
    g_near = geo.min_gap(near, paths)[0]
    check('(0) map anchor: the far camp really is farther', g_far > g_near,
          '%.0f vs %.0f' % (g_far, g_near))

    # ---- LAYER 1: minimum over lanes, and the direction of the bound --------
    p = write_rows([frame(100.0, far), frame(200.0, near, game='g2')])
    out = run_tool(p)
    line = armed_line(out)
    check('(1a) both poke episodes are counted', 'n=2' in line, line)
    check('(1b) the far camp counts as over the constant', ' 1 ' in line or line.split()[-3:], line)

    # The tool must agree with the geometry module episode by episode.
    per = [l for l in out.splitlines() if 'gap=' in l]
    check('(1c) one per-episode line per poke episode', len(per) == 2, per)
    got = sorted(float(l.split('gap=')[1].split()[0]) for l in per)
    check('(1d) per-episode gaps equal min_gap() exactly',
          got == sorted([round(g_near), round(g_far)]) or
          all(abs(a - b) < 1.0 for a, b in zip(got, sorted([g_near, g_far]))),
          '%s vs %s' % (got, sorted([g_near, g_far])))

    # MUTATION 1: replace min_gap with a max-over-lanes.  The `>gap` tally must
    # change -- if it does not, the minimum was never load-bearing.
    saved_min = tool.min_gap
    tool.min_gap = lambda v, ps: (max(g[0] for g in geo.all_gaps(v, ps).values()),
                                  'TOP', 0)
    mut = armed_line(run_tool(p))
    tool.min_gap = saved_min
    check('(M1) max-over-lanes changes the reading (minimum is load-bearing)',
          mut != line, '%r == %r' % (mut, line))

    # ---- LAYER 2: the camp is the FIRST poke frame's camp -------------------
    # One episode, two frames, two different camps.  Frames of one episode must
    # be contiguous in time for pullcamp_domain.episodes() to chain them.
    rows = [frame(100.0, near), frame(101.0, far)]
    p2 = write_rows(rows)
    out2 = run_tool(p2)
    per2 = [l for l in out2.splitlines() if 'gap=' in l]
    check('(2a) the two frames chain into ONE episode', len(per2) == 1, per2)
    if per2:
        chosen = float(per2[0].split('gap=')[1].split()[0])
        check('(2b) the FIRST poke frame\'s camp is the one measured',
              abs(chosen - g_near) < 1.0,
              'read %.0f, first=%.0f last=%.0f' % (chosen, g_near, g_far))

    # MUTATION 2: measure the LAST poke frame instead.  Must read the far camp.
    check('(M2) first-vs-last actually differ on this input',
          abs(g_near - g_far) > 100, '%.0f vs %.0f' % (g_near, g_far))

    # ---- LAYER 3: the blind band is reported, not folded away ---------------
    # A camp whose gap sits inside +-BLIND_BAND of the constant must show up in
    # the `blind` column.
    p3 = write_rows([frame(100.0, near)])
    out3 = run_tool(p3, gap=g_near + 40.0)      # constant placed inside the band
    l3 = armed_line(out3)
    nums = [int(x) for x in l3.replace('n=', ' ').split() if x.isdigit()]
    check('(3a) an episode inside the reconstruction error is flagged blind',
          ' 1 ' in ' '.join(l3.split()[-6:]) or 1 in nums, l3)
    out4 = run_tool(p3, gap=g_near + 5000.0)    # constant far away
    l4 = armed_line(out4)
    check('(3b) an episode far from the constant is NOT flagged blind',
          l4 != l3, '%r == %r' % (l4, l3))
    check('(3c) BLIND_BAND is a stated constant, not a literal in the tally',
          isinstance(tool.BLIND_BAND, int) and tool.BLIND_BAND > 0,
          tool.BLIND_BAND)

    # ---- LAYER 4: the baseline leg is a real second column ------------------
    # A control that never moves proves nothing (the lesson this desk paid for
    # on 2026-09-10 writing domain_rows_strata's tests): give the baseline leg
    # its OWN game and hero so episodes() cannot merge the two legs into one
    # chain, then assert the two rows differ.
    p5 = write_rows([frame(100.0, far, game='g1', hero='npc_dota_hero_lion'),
                     frame(100.0, near, game='g2', leg='baseline',
                           hero='npc_dota_hero_lich')])
    out5 = run_tool(p5)
    a5 = armed_line(out5)
    b5 = [l for l in out5.splitlines() if l.startswith('baseline')][0]
    check('(4a) both legs report an episode', 'n=1' in a5 and 'n=1' in b5,
          '%r / %r' % (a5, b5))
    check('(4b) the two legs read differently on different camps',
          a5.split(None, 1)[1] != b5.split(None, 1)[1], '%r / %r' % (a5, b5))

    # ---- LAYER 5: connect gaps are printed, and only for connecting eps -----
    p6 = write_rows([frame(100.0, near, connect=True),
                     frame(100.0, far, game='g2', hero='npc_dota_hero_lich')])
    out6 = run_tool(p6)
    a6 = armed_line(out6)
    check('(5a) the connecting camp\'s gap is printed', '%.0f' % g_near in a6, a6)
    # The far camp's gap DOES appear on the same line (it is in the p90/max of
    # the distribution column) -- so the assertion has to name the connect
    # column itself, which is the line's trailing field.  Asserting "absent
    # from the line" would have passed for the wrong reason.
    check('(5b) the non-connecting camp\'s gap is not in the connect column',
          a6.split()[-1] == '%.0f' % g_near, a6)
    per6 = [l for l in out6.splitlines() if 'gap=' in l]
    check('(5c) CONNECT marks exactly one per-episode line',
          sum('CONNECT' in l for l in per6) == 1, per6)

    # ---- LAYER 6: an enemy-side camp is not shown to the gap predicate ------
    # `J.ShouldPullNeutralCamp` filters `camp.team == GetTeam()` BEFORE
    # `J.IsCampBesideLane` runs, so a non-strict episode's gap is a gap the
    # predicate never sees.  Default = dropped; the flag restores it.
    p7 = write_rows([frame(100.0, near, strict=True),
                     frame(100.0, far, game='g2', hero='npc_dota_hero_lich',
                           strict=False)])
    out7 = run_tool(p7)
    a7 = armed_line(out7)
    check('(6a) the enemy-side episode is dropped by default', 'n=1' in a7, a7)
    check('(6b) the drop is REPORTED, not silent',
          'dropped as NOT-friendly-camp' in out7 and ' armed 1 ' in out7,
          [l for l in out7.splitlines() if 'dropped' in l])
    out8 = run_tool(p7, include_enemy=True)
    a8 = armed_line(out8)
    check('(6c) --include-enemy-camps restores it', 'n=2' in a8, a8)
    check('(6d) and the two readings actually differ', a7 != a8,
          '%r == %r' % (a7, a8))

    for path in (p, p2, p3, p5, p6, p7):
        os.unlink(path)

    print()
    if failures:
        print('%d FAILED: %s' % (len(failures), ', '.join(failures)))
        return 1
    print('all checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
