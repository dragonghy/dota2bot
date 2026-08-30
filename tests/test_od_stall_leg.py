#!/usr/bin/env python3
"""Runs `od_stall_leg.py`'s selfcheck battery from the python suite.

WHY THIS FILE EXISTS ALONGSIDE `od_stall_leg.py --selfcheck`.  The module's
selfcheck is the real battery -- it pins the leg resolution (by team id, not by
string), the one-directional ROW_CONTRADICTS_STAMP proof, and the two build
rows read off `hero_obsidian_destroyer.lua` itself.  But `tests/run_py_tests.sh`
only loops over `tests/test_*.py`, so without this wrapper nothing in the tree
ever invokes it -- the same shape as the un-run tests GH #243 calls out, and
the same shape as `tests/test_wk_reincarn_trigger_domain.py` exists to fix.

It also pins the thing a future edit is most likely to undo.  `odbuild`'s
condition (a) was bought on W28 by a leg contrast (armed objurgation 4/4/4 and
16 points, baseline 0/0/0/0 and 6 points, 10/10 rows with no exception), and
that reading is only legible because the module's PRE-GATE block prints the
stalls BY LEG and the armed leg's rank next to its verdict.  A headline that
says "OD IS STILL in the STALL table => UNINTERPRETABLE, returned" with those
two lines removed returns the candidate for the defect it removes -- the stall
rows are on the leg that keeps index 4.  So the strings are named here.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'od_stall_leg.py')

fails = []


def ok(name, cond, why=''):
    print('%-56s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.exists(TOOL):
    print('could not read %s' % TOOL)
    sys.exit(2)

proc = subprocess.run([sys.executable, TOOL, '--selfcheck'],
                      capture_output=True, text=True)
print(proc.stdout, end='')
ok('selfcheck exits clean', proc.returncode == 0, 'exit %d' % proc.returncode)
ok('no check in the battery FAILed', 'FAIL' not in proc.stdout)

# Naming the checks means deleting one fails this file instead of quietly
# shrinking the battery.
for must in ('resolved by TEAM ID',
             'ROW_CONTRADICTS_STAMP',
             'is NOT a stamp contradiction',
             'unstamped game reads WARMUP',
             'armed row still names index 3 third',
             'shipped row still never names index 3',
             'empty end-of-game abilities frame is not a spend',
             't_objurg_1 is the FIRST frame'):
    ok('battery still covers: %s' % must, must in proc.stdout)

sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))
import od_stall_leg as M                                    # noqa: E402

# The PRE-GATE block is the load-bearing half of the W28 reading: the verdict
# line is only safe to quote while the leg split and the armed rank travel with
# it.  Build a corpus in the exact W28 shape and assert all three survive.
stalled = {'obsidian_destroyer_arcane_orb': 1,
           'obsidian_destroyer_astral_imprisonment': 4,
           M.OBJURGATION: 0,
           'obsidian_destroyer_sanity_eclipse': 1}
healthy = {'obsidian_destroyer_arcane_orb': 4,
           'obsidian_destroyer_astral_imprisonment': 4,
           M.OBJURGATION: 4,
           'obsidian_destroyer_sanity_eclipse': 3}
rows = [M.od_row(M._tl(2, 26, healthy), 'armed_g', 'mirror:x:s1:radiant'),
        M.od_row(M._tl(2, 23, stalled), 'base_g', 'mirror:x:s1:dire')]
text = M.summarise(rows)

ok('PRE-GATE prints the stalls by leg',
   'stalls by leg: ARMED 0/1 | baseline 1/1' in text, text)
ok('PRE-GATE prints the armed-leg objurgation rank',
   'armed-leg objurgation rank(s): 4' in text, text)
ok('a non-zero armed leg does NOT read as the case CF returns',
   'NON-ZERO' in text and 'UNINTERPRETABLE' not in text, text)

# ...and the other direction still reads as the case CF does return, so the
# fix above is a narrowing, not a disabling.
rows_zero = [M.od_row(M._tl(2, 23, stalled), 'armed_g', 'mirror:x:s1:radiant')]
text_zero = M.summarise(rows_zero)
ok('an all-zero armed leg still reads UNINTERPRETABLE',
   'UNINTERPRETABLE' in text_zero, text_zero)

if fails:
    print('\n%d FAILURE(S):' % len(fails))
    for f in fails:
        print('  - %s' % f)
    sys.exit(1)
print('\nall checks passed')
