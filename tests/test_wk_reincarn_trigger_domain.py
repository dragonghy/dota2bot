#!/usr/bin/env python3
"""Runs `wk_reincarn_trigger_domain.py`'s selfcheck battery from the python suite.

WHY THIS FILE EXISTS ALONGSIDE `wk_reincarn_trigger_domain.py --selfcheck`.  The
module's selfcheck is the real battery -- it builds a synthetic timeline and
pins the identifier, the illusion filter, the corpse filter and iron rule
4(ii).  But `tests/run_py_tests.sh` only loops over `tests/test_*.py`, so
without this wrapper nothing in the tree ever invokes it, which is the same
shape as the un-run tests GH #243 and the runner's own header call out.

It also pins the two frames that CORRECTED the identifier, because those are
the ones a future edit is most likely to undo: the amendment's proposed
"cooldown 0 -> positive" edge is wrong in both directions on the real corpus,
and the magnitude threshold is what separates the real 110/150 s cooldown from
the 4.3 s auxiliary timer riding on the same ability handle.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'wk_reincarn_trigger_domain.py')

fails = []


def ok(name, cond, why=''):
    print('%-52s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.exists(TOOL):
    print('could not read %s' % TOOL)
    sys.exit(2)

proc = subprocess.run([sys.executable, TOOL, '--selfcheck'],
                      capture_output=True, text=True)
print(proc.stdout, end='')
ok('selfcheck exits clean', proc.returncode == 0,
   'exit %d' % proc.returncode)
ok('selfcheck reports OK', 'selfcheck: OK' in proc.stdout)
ok('no check in the battery FAILed', ' FAIL' not in proc.stdout)

# The battery must keep covering the corrections, not just pass.  Naming the
# checks here means deleting one of them fails this file rather than quietly
# shrinking the battery.
for must in ('identifier-B-agrees',
             'identifier-B-ignores-auxiliary-timer',
             'identifier-C-agrees',
             'fountain-death-not-a-trigger',
             'dead-enemy-at-300u-excluded',
             'illusion-on-top-of-wk-excluded',
             'engine-slow-target-count',
             'aggregate-reports-no-median'):
    ok('battery still covers %s' % must, must in proc.stdout)

sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))
import wk_reincarn_trigger_domain as M                      # noqa: E402

# The threshold has to sit strictly between the auxiliary timer and the real
# cooldown, or identifier B goes back to being wrong in both directions.
ok('B threshold above the 4.3s auxiliary timer', M.B_MIN_CD > 4.3,
   'B_MIN_CD=%r' % M.B_MIN_CD)
ok('B threshold below the rank-3 cooldown (~110s)', M.B_MIN_CD < 109.0,
   'B_MIN_CD=%r' % M.B_MIN_CD)
ok('radii are the two the talent rows actually name',
   (M.R_SHIPPED, M.R_TALENT) == (600.0, 900.0),
   'got %r' % ((M.R_SHIPPED, M.R_TALENT),))

if fails:
    print('\n%d FAILURE(S):' % len(fails))
    for f in fails:
        print('  - %s' % f)
    sys.exit(1)
print('\nall checks passed')
