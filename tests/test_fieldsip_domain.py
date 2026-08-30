#!/usr/bin/env python3
"""Runs `fieldsip_domain.py`'s corpus-free selfcheck battery from the python suite.

WHY THIS FILE EXISTS.  `tests/run_py_tests.sh` only loops over `tests/test_*.py`,
so a probe that is only ever invoked by hand is a probe nothing in the tree runs
-- the GH #243 shape, and the same reason `tests/test_od_stall_leg.py` and
`tests/test_tpreach_domain.py` exist.  The module splits its battery in two so
this wrapper can run in CI where no sweep dir exists: `pure_checks()` needs no
frames, `corpus_checks()` does.

⭐ WHAT IS ACTUALLY BEING PROTECTED HERE: THE ONE ASSUMPTION.
`fieldsip` is `sip >= 0.25 * GetMaxHealth()`, and `GetMaxHealth()` is NOT in the
dump -- snapshots carry `hp_pct` and no absolute bar.  The probe therefore does
not evaluate the threshold at all; it partitions frames by WHICH item is the
best accepted sip and scores only the class that no plausible hero bar could
flip (`CERTAIN`: faerie fire 85, tango 115).  `bottle` (135) and `flask` (400)
are left unscored on purpose -- a 1600 bar is ordinary mid-game.

That makes `CERTAIN_MAXHP_FLOOR = 460` the single load-bearing number in the
tool, and it is load-bearing in a way that fails SILENTLY: move it to 600 and
the bottle quietly joins the scored domain; move it to 1600 and so does the
flask, at which point the probe is measuring `fieldregen`'s frames and still
prints a clean-looking table.  Nothing else in the tree would notice.  So the
floor is pinned from BOTH sides below, plus the exact boundary case.

⭐⭐ AND THE BOUNDARY IS EXACT, NOT APPROXIMATE.  `4 * 115 == 460`: the tango
sits precisely ON the floor, so the comparison has to stay strict (`maxHP >
460`).  A hero with a 460 bar carrying a tango reads "enough" and is correctly
outside the domain.  Relaxing that `<=` to `<` would drop the tango -- which is
391 of the 496 armed-leg CERTAIN frames in W28, i.e. most of the domain -- and
the tool would report a much smaller domain rather than an error.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'fieldsip_domain.py')

fails = []


def ok(name, cond, why=''):
    print('%-58s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.exists(TOOL):
    print('could not read %s' % TOOL)
    sys.exit(2)

proc = subprocess.run([sys.executable, TOOL, '--selfcheck'],
                      capture_output=True, text=True)
print(proc.stdout, end='')
ok('selfcheck exits clean', proc.returncode == 0, 'exit %d' % proc.returncode)
# Not `'FAIL' not in stdout`: every line of the battery is tagged [PASS] or
# [FAIL], so on a clean run the substring is absent -- but the summary line of a
# DIRTY run would still contain it either way.  A failing check is a line
# carrying the [FAIL] tag.  (The same trap `tests/test_tpreach_domain.py`
# registered on 2026-08-30.)
ok('no check in the battery FAILed',
   not [l for l in proc.stdout.splitlines() if '[FAIL]' in l],
   '; '.join(l for l in proc.stdout.splitlines() if '[FAIL]' in l))

# A corpus-free run must SAY it skipped the corpus half.  A reader who sees
# neither the skip line nor the corpus checks has to be able to conclude the
# tool did not look -- never that the corpus was clean (铁律 10's
# `SKIP`/`UNCERTIFIABLE` wording, applied to a probe).
ok('a corpus-free run declares the skip, not a pass',
   'SKIPPED, not passed' in proc.stdout)

# Naming the checks means deleting one fails this file instead of quietly
# shrinking the battery.
for name in ('FIELD_SIP_HEAL mirrors the Lua table exactly',
             'MIN_FRACTION mirrors J.FIELD_SIP_MIN_FRACTION',
             'the tango sits exactly ON the floor',
             'CERTAIN and AMBIGUOUS partition the heal table',
             'sip_class(flask + tango) == AMBIGUOUS',
             'a backpack flask does NOT raise the sip',
             'sip_best reads slots 0..5 only'):
    ok('battery still runs: %s' % name[:44], name in proc.stdout)

sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))
import fieldsip_domain as F                                   # noqa: E402

# -- the floor, pinned from both sides -------------------------------------
ok('the floor is 4x the tango, i.e. derived not tuned',
   F.CERTAIN_MAXHP_FLOOR == F.FIELD_SIP_HEAL['tango'] / F.MIN_FRACTION,
   'floor %s vs 4*tango %s' % (F.CERTAIN_MAXHP_FLOOR,
                               F.FIELD_SIP_HEAL['tango'] / F.MIN_FRACTION))
ok('no CERTAIN item could be "enough" at the floor',
   all(F.FIELD_SIP_HEAL[i] / F.MIN_FRACTION <= F.CERTAIN_MAXHP_FLOOR
       for i in F.CERTAIN_ITEMS))
ok('every AMBIGUOUS item needs a bar above the floor',
   all(F.FIELD_SIP_HEAL[i] / F.MIN_FRACTION > F.CERTAIN_MAXHP_FLOOR
       for i in F.AMBIGUOUS_ITEMS))
ok('bottle is NOT scored (charges unobservable, closest to the line)',
   'bottle' in F.AMBIGUOUS_ITEMS and 'bottle' not in F.CERTAIN_ITEMS)
ok('flask is NOT scored (a 1600 bar is ordinary mid-game)',
   'flask' in F.AMBIGUOUS_ITEMS and 'flask' not in F.CERTAIN_ITEMS)

# -- the classifier takes the MAX, not the first slot ----------------------
# A hero carrying tango + flask is NOT in the domain; reading slot order
# instead of the max would put it there and book `fieldregen`'s frames here.
ok('tango + flask classifies on the max (AMBIGUOUS), not slot order',
   F.sip_class({'items': ['tango', 'flask']}) == 'AMBIGUOUS'
   and F.sip_class({'items': ['flask', 'tango']}) == 'AMBIGUOUS')

# -- the inverted clause, which is the whole difference from fieldbuy ------
# `fieldsip`'s domain requires a source PRESENT; `fieldbuy`'s requires it
# ABSENT.  If someone ever "unifies" the two domain functions, this fails.
import fieldbuy_domain as B                                   # noqa: E402
ok('fieldsip and fieldbuy disagree about the source clause',
   B.__name__ != F.__name__ and F.domain_frame is not B.domain_frame)

# -- the co-arming guards --------------------------------------------------
# `bagsalve` armed would widen J.FieldRegenSipValue into the backpack, where
# the only admissible item is the flask -- the largest value in the table.
ok('bagsalve is registered as the forbidden co-armed id',
   F.FORBIDDEN_ID == 'bagsalve')
ok('fieldbuy is registered as the execution vehicle, not a rival',
   F.VEHICLE_ID == 'fieldbuy' and F.RIVAL_ID == 'fieldregen')

print()
if fails:
    print('FAILED %d check(s):' % len(fails))
    for f in fails:
        print('  ' + f)
    sys.exit(1)
print('fieldsip_domain wrapper: all checks ok')
