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

# ---------------------------------------------------------------------------
# 9. GH #420 -- the third bucket.  The two buckets above are keyed on a LEG'S
#    NOTE LEVEL, and a leg has exactly one.  A python leg that is both red and
#    partly un-run notes 3, lands in FINDINGS whole, and the tests inside it
#    that never ran have nowhere to be -- so the block printed
#    `UNCERTIFIABLE (exit 2): none` on a run whose own leg body read
#    `75 passed, 1 failed, 2 uncertifiable` (director 09-02, live).
#
#    THE LOAD-BEARING ASSERTIONS HERE ARE 9.3 AND 9.5.  9.1/9.2/9.7 would pass
#    for any implementation that prints a third line at all.  9.3 pins the shape
#    that motivated the issue (red AND un-run in one output), and 9.5 pins the
#    reason the extractor reads the per-file lines instead of the runner's
#    machine-readable roll-up: that roll-up is printed ONLY when nothing failed
#    (tests/run_py_tests.sh:48-55), i.e. it is absent exactly on the strictly
#    worse tree -- reading it would have rebuilt the defect inside the fix.
# ---------------------------------------------------------------------------

# The verbatim leg body from GH #420's 現場 (and from this round's own tree).
# Note what is NOT in it: no `uncertifiable: ...` roll-up line.
PY_RED_AND_UNRUN = '\n'.join([
    'PASS  tests/test_a.py',
    'FAIL  tests/test_detector_source_constants.py',
    '      some failure detail',
    'UNCERTIFIABLE  tests/test_rc_wrapper.py  (did NOT run -- this is not a pass and not a failure)',
    '      could not read its input',
    'UNCERTIFIABLE  tests/test_selfcheck_lua_leg.py  (did NOT run -- this is not a pass and not a failure)',
    '',
    '75 passed, 1 failed, 2 uncertifiable',
    'failed: tests/test_detector_source_constants.py',
])

PY_UNRUN_ONLY = '\n'.join([
    'PASS  tests/test_a.py',
    'UNCERTIFIABLE  tests/test_rc_wrapper.py  (did NOT run -- this is not a pass and not a failure)',
    '',
    '76 passed, 0 failed, 1 uncertifiable',
    'uncertifiable: tests/test_rc_wrapper.py',
])


def drive_py(body_output, note_level):
    """Feed the python leg's captured output through the extractor.

    Shaped like the wrapper: capture the runner output into `suite`, hand it to
    the extractor, then let the branch note its level.
    """
    quoted = "'" + body_output.replace("'", "'\\''") + "'"
    return drive("sc_leg 'trunk-red(python)'\n"
                 "suite=%s\n"
                 "sc_unrun_from_py_output \"$suite\"\n"
                 "sc_note %d" % (quoted, note_level))


# 9.1 ⭐ THE 09-02 SHAPE.  Red and un-run in one leg: FINDINGS names the leg,
#     the new line names the FILES, and both are readable in the same block.
out, rc = drive_py(PY_RED_AND_UNRUN, 3)
notrun = (field(out, 'NOT RUN (inside a leg)') or '').split()
check(field(out, 'FINDINGS (exit 3)') == 'trunk-red(python)',
      'the red leg is still attributed, got %r' % field(out, 'FINDINGS (exit 3)'))
check('tests/test_rc_wrapper.py' in notrun and 'tests/test_selfcheck_lua_leg.py' in notrun,
      'BOTH un-run files must be named on the #420 shape, got %r' % notrun)
check(len(notrun) == 2, 'exactly the two un-run files expected, got %r' % notrun)
check('tests/test_detector_source_constants.py' not in notrun,
      'the FAILING file is not an un-run file; it must not leak into this bucket')
check('ATTRIBUTION BROKEN' not in out,
      'declared count (2) matches the names found (2); no drift banner expected:\n%s' % out)

# 9.2 The exit code moves by zero words -- #420's own acceptance sentence.  A
#     run whose ONLY finding is un-run files still exits what its legs said.
check(rc == 3, 'the #420 shape must still exit 3, got %d' % rc)
out0, rc0 = drive("sc_leg 'a'\nsc_note 0\nsc_unrun 'tests/test_x.py'")
check(rc0 == 0, 'sc_unrun must not raise the exit code, got %d' % rc0)
check(field(out0, 'NOT RUN (inside a leg)') == 'tests/test_x.py',
      'a clean run still reports what did not run, got %r'
      % field(out0, 'NOT RUN (inside a leg)'))

# 9.3 ⭐ The extractor reads the runner's PER-FILE lines.  Neither the count
#     line, the `failed:` line, nor the indented detail may be mistaken for a
#     file name.
check(all(not n.startswith('uncertifiable') and n.startswith('tests/') for n in notrun),
      'only tests/ paths may enter the bucket, got %r' % notrun)

# 9.4 The exit-2-only shape (nothing failed) still works -- and the leg's own
#     level-2 attribution is untouched by the new bucket.
out, rc = drive_py(PY_UNRUN_ONLY, 2)
check(rc == 2, 'un-run only should still exit 2, got %d' % rc)
check(field(out, 'UNCERTIFIABLE (exit 2)') == 'trunk-red(python)',
      'the leg-level bucket is unchanged, got %r' % field(out, 'UNCERTIFIABLE (exit 2)'))
check(field(out, 'NOT RUN (inside a leg)') == 'tests/test_rc_wrapper.py',
      'the file-level bucket names the file, got %r' % field(out, 'NOT RUN (inside a leg)'))

# 9.5 ⭐ THE REASON THE EXTRACTOR IS SHAPED THIS WAY.  run_py_tests.sh prints
#     its machine-readable `uncertifiable:` roll-up only when fail == 0, so on
#     the red tree there is none -- and 9.1 above passed on output that has no
#     such line.  Assert that absence explicitly so a future "simplification"
#     to grep the roll-up fails here instead of in a Routine round.
check('uncertifiable:' not in PY_RED_AND_UNRUN,
      'the #420 fixture must NOT contain the roll-up line -- that is the point')
runner = open(os.path.join(ROOT, 'tests', 'run_py_tests.sh')).read()
check(runner.index("printf 'failed:%s\\n'") < runner.index("printf 'uncertifiable:%s\\n'"),
      'the runner still exits on `failed:` before printing `uncertifiable:`; '
      'if that changed, revisit the extractor comment in selfcheck_tally.sh')

# 9.6 ⭐ The new bucket cannot lie quietly either (this file's header rule).
#     Declare two, hand it output where the per-file lines have drifted, and it
#     must say so rather than print a confident short list.
drifted = PY_RED_AND_UNRUN.replace('UNCERTIFIABLE  tests/', 'NOTRUN  tests/')
out, rc = drive_py(drifted, 3)
check('ATTRIBUTION BROKEN' in out,
      'a declared count the extractor cannot match must print ATTRIBUTION BROKEN, got:\n%s' % out)
check(rc == 3, 'the drift banner must not change the exit code, got %d' % rc)

# 9.7 The field always prints, like the two above it: an absent line reads as
#     "not measured", which is the defect being replaced (test 1's rationale).
out, rc = drive("sc_leg 'cadence'\nsc_note 0")
check(field(out, 'NOT RUN (inside a leg)') == 'none',
      'a clean run must print the field with `none`, got %r'
      % field(out, 'NOT RUN (inside a leg)'))

# 9.8 The wrapper actually feeds the extractor, and does so BEFORE the branch on
#     `suite_rc` -- so the exit-1 branch (red AND un-run) is covered, not just
#     the exit-2 one.  Putting the call inside a branch is precisely how the leg
#     body acquired this bug in the first place.
check('sc_unrun_from_py_output "$suite"' in wrapper,
      'the wrapper must feed the python leg output to the extractor')
check(wrapper.index('sc_unrun_from_py_output "$suite"')
      < wrapper.index('if [ "$suite_rc" -eq 0 ]; then'),
      'the extractor call must precede the suite_rc branch, so BOTH non-zero '
      'branches carry the un-run names')
check(wrapper.index('suite=$(bash tests/run_py_tests.sh 2>&1)')
      < wrapper.index('sc_unrun_from_py_output "$suite"'),
      'the extractor must run after the suite is captured')

if failures:
    print('FAIL  %d of %d checks' % (len(failures), checks))
    for f in failures:
        print('      ' + f)
    sys.exit(1)
print('ok  %d checks  (selfcheck exit attribution, GH #267 4b)' % checks)
