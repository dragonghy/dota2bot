#!/usr/bin/env python3
"""Runs `tpreach_domain.py`'s selfcheck battery from the python suite.

WHY THIS FILE EXISTS ALONGSIDE `tpreach_domain.py --selfcheck`.  The module's
selfcheck is the real battery (42 checks: the band arithmetic, the illusion
filter, the delayed-press witness, the four source-pins).  But
`tests/run_py_tests.sh` only loops over `tests/test_*.py`, so without this
wrapper nothing in the tree ever invokes it -- the GH #243 shape, and the same
reason `tests/test_od_stall_leg.py` exists.

It also pins the checks a future edit is most likely to undo, by name.

THE MELEE FLOOR (replay-check 2026-08-30, W28).  `--reach-mode p90` handed a
blind band to four MELEE heroes -- chaos_knight 980, juggernaut 2821,
ember_spirit 2120, dragon_knight 770 -- and 14 of the 45 ADDED rows it produced
had one of them as the band enemy.  The source's own rule is that a melee hero
can NEVER be in ADDED (`reach > 700` needs `GetAttackRange() > 550`), so a
third of that domain was impossible by construction, and nothing in the output
said so.

The existing `ability-not-an-attack` guard cannot catch it: `ATTACK_INFLICTOR`
is `dota_unknown`, the ABSENCE of a named inflictor, so illusion, summon and
attack-modifier damage (Phantasm, Exorcism, Omnislash, Sleight of Fist) logs
under the hero's own name with nothing to filter on.  Deleting the floor
therefore does not fail any pre-existing check -- it just quietly re-inflates
the domain.  Hence the names below, and hence the two header lines: a reader
who sees no `melee floor removed:` line must be able to conclude the tool did
not check, never that the table was clean.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'tpreach_domain.py')

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
# Not `'FAIL' not in stdout`: the battery's own summary line reads
# "42 PASS / 0 FAIL", so the substring is present on a clean run.  A failing
# check is a line that STARTS with FAIL.
ok('no check in the battery FAILed',
   not [l for l in proc.stdout.splitlines() if l.startswith('FAIL')],
   '; '.join(l for l in proc.stdout.splitlines() if l.startswith('FAIL')))

# Naming the checks means deleting one fails this file instead of quietly
# shrinking the battery.
for name in ('band-added',
             'inside-700-not-added',
             'past-reach-not-added',
             'ability-not-an-attack',
             'thin-evidence-falls-back',
             'melee-floor-blocks-a-contaminated-tail',
             'melee-floor-keeps-it-out-of-added',
             'melee-floor-spares-a-ranged-hero',
             'melee-floor-cuts-where-the-source-cuts',
             'melee-floor-is-a-noop-at-p50',
             'diagnostics-name-the-floored-hero',
             'diagnostics-name-the-degenerate-band',
             'illusion-not-a-band-enemy',
             'src-wide-scan',
             'src-reach-buffer',
             'src-gate'):
    ok('battery still runs %s' % name, name in proc.stdout)

# The floor is the SOURCE's rule, not a tuned threshold, so it has to cut where
# the source cuts.  Asserted here against the module directly rather than
# through the battery, because this is the one number a well-meaning edit would
# "round" (to 500, or to MELEE_RANGE_U) without noticing it stopped matching
# `GetAttackRange() > 550`.
sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))
import tpreach_domain as T                                    # noqa: E402

ok('the floor cut is NARROW_SCAN_U, i.e. the source rule',
   T.NARROW_SCAN_U == 700.0 and T.REACH_BUFFER_U == 150.0,
   'reach = range + %.0f must clear %.0f' % (T.REACH_BUFFER_U, T.NARROW_SCAN_U))
ok('melee-vs-ranged is decided on a robust statistic',
   T.MELEE_DECISION_PCT == 50,
   'p%d is a tail percentile -- the contaminated half' % T.MELEE_DECISION_PCT)
ok('a 550-range hero gets no band, a 551 one does',
   'x' not in T.reach_table({'x': [550.0] * T.MIN_ATTACKS})
   and 'x' in T.reach_table({'x': [551.0] * T.MIN_ATTACKS}))

# The W28 shape itself, as a regression: chaos_knight's real p50 is 195 and its
# max is a map diagonal.  Whatever percentile sizes the band, this hero must
# not have one.
ck = [195.0] * 1100 + [3000.0] * 374
saved = T.RANGE_PCT
try:
    for pctl in (50, 75, 90, 95):
        T.RANGE_PCT = pctl
        ok('W28 chaos_knight stays out of the band at p%d' % pctl,
           'chaos_knight' not in T.reach_table({'chaos_knight': ck}),
           'p%d raw %.0f' % (pctl, T.pct(ck, pctl) + T.REACH_BUFFER_U))
finally:
    T.RANGE_PCT = saved

# `reach >= WIDE_SCAN_U` makes the band test `d <= min(reach, 1200)` stop
# testing reach at all -- ADDED degenerates into "any enemy in (700, 1200]".
# W28's p90 table put death_prophet at 6868 there.  The header must say so.
_, degenerate = T.reach_diagnostics({'dp': [6718.0] * T.MIN_ATTACKS},
                                    T.reach_table({'dp': [6718.0] * T.MIN_ATTACKS}))
ok('a degenerate band is reported, not silently used',
   [h for h, _ in degenerate] == ['dp'])

print()
if fails:
    print('FAILED %d check(s):' % len(fails))
    for f in fails:
        print('  ' + f)
    sys.exit(1)
print('tpreach_domain wrapper: all checks ok')
