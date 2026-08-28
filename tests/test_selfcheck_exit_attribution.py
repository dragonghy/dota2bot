#!/usr/bin/env python3
"""Acceptance for the source-attributed exit code of 开工自检 (GH #267 §4b).

WHY THIS EXISTS.  `tests/test_activemode_world_assertion.lua` sat RED on
origin/main for ~22 hours (2026-08-27 -> 08-28).  Every stream ran
`tools/agent/routine_selfcheck.sh` in that window and read `selfcheck worst
exit: 3`, and every one of them wrote some form of "exit 3, all of it cadence"
into their report -- correct on the days before, false in this window.  The
wrapper collapsed seven legs into ONE INTEGER, so the sentence was HAND-MADE
attribution with nothing to check it against.

THE LOAD-BEARING ASSERTION IS NOT "the breakdown is printed".  A run in which
cadence and a trunk red BOTH fire must name BOTH -- test 3 below.  That is the
08-27 shape exactly, and it is the only assertion here that a merely decorative
implementation cannot pass: a tail that printed the first source, or the last
one, or `worst`'s own leg, would satisfy every other check in this file.

Second load-bearing claim, test 6: the breakdown CANNOT SILENTLY DISAGREE with
the total it explains.  A future leg that raises the exit code without
announcing itself gets an ATTRIBUTION BROKEN banner rather than an
authoritative-looking `FINDINGS: none` next to `worst exit: 3` -- which would be
the original defect wearing the fix's clothes.

Design note on why this drives the tally directly instead of the whole wrapper:
a full selfcheck is ~20s and reaches the network, and to see two sources at once
it would have to be made to fail two ways on purpose.  The tally is a separate
sourceable file for exactly this reason (same move as ensure_lua_toolchain.sh,
GH #205).  Test 7 then pins the wrapper to it end to end, so the extraction
cannot drift into testing a file nobody sources.

Run:  python3 tests/test_selfcheck_exit_attribution.py
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TALLY = os.path.join(ROOT, 'tools', 'agent', 'selfcheck_tally.sh')
WRAPPER = os.path.join(ROOT, 'tools', 'agent', 'routine_selfcheck.sh')

failures = []
checks = 0


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        failures.append(msg)


def drive(body):
    """Source the tally, run `body`, return (stdout, exit code)."""
    script = '. %s\n%s\nsc_report\nexit "$(sc_worst)"\n' % (TALLY, body)
    p = subprocess.run(['bash', '-c', script], cwd=ROOT,
                       capture_output=True, text=True)
    return p.stdout, p.returncode


def field(out, label):
    for line in out.splitlines():
        if line.startswith(label):
            return line.split(':', 1)[1].strip()
    return None


# 1. A clean run: no sources, exit 0, and the fields still print (an absent
#    breakdown reads as "not measured", which is what we are replacing).
out, rc = drive("sc_leg 'cadence'\nsc_note 0\nsc_leg 'unlanded'\nsc_note 0")
check(rc == 0, 'clean run should exit 0, got %d' % rc)
check(field(out, 'FINDINGS (exit 3)') == 'none',
      'clean run should print FINDINGS: none, got %r' % field(out, 'FINDINGS (exit 3)'))
check(field(out, 'UNCERTIFIABLE (exit 2)') == 'none',
      'clean run should print UNCERTIFIABLE: none')
check(field(out, 'legs run') == '2', 'clean run should count 2 legs')
check('ATTRIBUTION BROKEN' not in out, 'clean run must not claim broken attribution')

# 2. One source only -- the ordinary shape of the days BEFORE 08-27.  The
#    sentence "all of it cadence" is now something the output says.
out, rc = drive("sc_leg 'cadence'\nsc_note 3\nsc_leg 'trunk-red(lua)'\nsc_note 0")
check(rc == 3, 'a finding should exit 3, got %d' % rc)
check(field(out, 'FINDINGS (exit 3)') == 'cadence',
      'single source should be named alone, got %r' % field(out, 'FINDINGS (exit 3)'))

# 3. ⭐ THE 08-27 SHAPE.  Cadence and a trunk red in the same run.  Both must be
#    named; naming only one is the defect this whole change exists to remove.
out, rc = drive("sc_leg 'cadence'\nsc_note 3\nsc_leg 'trunk-red(lua)'\nsc_note 3")
sources = (field(out, 'FINDINGS (exit 3)') or '').split()
check(rc == 3, 'two findings should still exit 3, got %d' % rc)
check('cadence' in sources and 'trunk-red(lua)' in sources,
      'BOTH sources must be named on the 08-27 shape, got %r' % sources)
check(len(sources) == 2, 'exactly two sources expected, got %r' % sources)

# 4. Levels do not bleed into each other: an uncertifiable leg is not a finding,
#    and a finding does not appear on the uncertifiable line.  (The wrapper's
#    0/2/3 vocabulary is load-bearing elsewhere -- GH #171, #213, #243 -- and a
#    breakdown that blurs 2 into 3 would re-open every one of them.)
out, rc = drive("sc_leg 'trunk-red(python)'\nsc_note 2\nsc_leg 'cadence'\nsc_note 3")
check(rc == 3, 'worst of {2,3} is 3, got %d' % rc)
check(field(out, 'FINDINGS (exit 3)') == 'cadence', 'level 3 line must hold only the 3')
check(field(out, 'UNCERTIFIABLE (exit 2)') == 'trunk-red(python)',
      'level 2 line must hold only the 2')

# 5. `worst` is unchanged in every case -- no stream's existing reading of the
#    exit code moves.  2 alone still exits 2; a later 2 does not lower a 3.
out, rc = drive("sc_leg 'a'\nsc_note 2")
check(rc == 2, 'a lone uncertifiable should exit 2, got %d' % rc)
out, rc = drive("sc_leg 'a'\nsc_note 3\nsc_leg 'b'\nsc_note 2")
check(rc == 3, 'a later 2 must not lower a 3, got %d' % rc)

# 6. ⭐ The instrument cannot lie quietly.  Raise the total behind the tally's
#    back and the tail says so.
out, rc = drive("sc_leg 'a'\nsc_note 0\n_sc_worst=3")
check(rc == 3, 'hand-raised worst should still exit 3, got %d' % rc)
check('ATTRIBUTION BROKEN' in out,
      'a total with no attributed source must print ATTRIBUTION BROKEN, got:\n%s' % out)

# 7. The wrapper actually sources this file and prints the breakdown before its
#    own summary line -- otherwise tests 1-6 grade a file nobody runs, which is
#    this repo's most-repeated defect (GH #113, #116, #171).
wrapper = open(WRAPPER).read()
check('. ./tools/agent/selfcheck_tally.sh' in wrapper,
      'the wrapper must source tools/agent/selfcheck_tally.sh')
check('sc_report' in wrapper, 'the wrapper must call sc_report')
check(wrapper.index('sc_report') < wrapper.index('selfcheck worst exit'),
      'the breakdown must print BEFORE the summary line it explains')
check("printf '\\nselfcheck worst exit: %d\\n' \"$worst\"" in wrapper,
      'the summary line must stay byte-identical (streams grep for it)')

# 8. Every leg of the wrapper announces itself.  A leg added later without an
#    `sc_leg` is exactly what test 6 catches at runtime -- but catching it here
#    costs nothing and names the file to edit.  Legs are counted by their banner
#    printfs (`=== ... ===`), which is how the wrapper's output is structured.
banners = [ln for ln in wrapper.splitlines()
           if ln.startswith("printf '") and '===' in ln and 'exit sources' not in ln]
declared = [ln for ln in wrapper.splitlines() if ln.startswith('sc_leg ')]
check(len(banners) == len(declared),
      'every leg banner needs an sc_leg: %d banners vs %d sc_leg calls'
      % (len(banners), len(declared)))
check(len(declared) >= 7, 'expected at least 7 legs, found %d' % len(declared))
for name in ('cadence', 'unlanded'):
    check(any("'%s'" % name in ln for ln in declared),
          '#267 §4b names %s explicitly; it must be a declared leg' % name)
check(any('trunk-red' in ln for ln in declared),
      '#267 §4b names trunk-red explicitly; it must be a declared leg')

if failures:
    print('FAIL  %d of %d checks' % (len(failures), checks))
    for f in failures:
        print('      ' + f)
    sys.exit(1)
print('ok  %d checks  (selfcheck exit attribution, GH #267 4b)' % checks)
