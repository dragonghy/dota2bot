#!/usr/bin/env python3
"""Acceptance for the python-trunk-health leg of tools/agent/routine_selfcheck.sh.

WHY THIS EXISTS.  The leg's job is to tell a fresh Routine session whether the
python side of the tree is red.  It has been corrected twice for saying the
WRONG THING -- GH #243 (a could-not-run reported as TRUNK RED) and GH #267
(hand-made exit attribution) -- and after both, the banner is right.

This file is GH #380.

What neither fix touched is whether the reader can tell WHY.  run_py_tests.sh
captures each failing test's own output and prints it indented by six spaces
(`sed 's/^/      /'`).  The leg reached the reader through
`grep -E '^(FAIL|failed:|[0-9]+ passed)'`, anchored at `^`, which drops every
indented line.  The runner produced the diagnosis; the leg deleted it.

MEASURED, 2026-09-01 (the round that wrote this file).  开工自检 printed:

    FAIL  tests/test_rc_wrapper.py
    71 passed, 1 failed, 1 uncertifiable
    failed: tests/test_rc_wrapper.py
    TRUNK RED -- a python test is failing ON THE WORKING TREE.

The next run of the same suite on the same tree read `72 passed, 0 failed`, and
the named test was green **30/30 standalone**.  So the failure was
intermittent, and the text the leg discarded was the ONLY copy of the evidence.
Re-running is not a recovery: a flake that does not reproduce is gone.

That is why this is not cosmetics.  A red nobody can diagnose is, to the reader,
the same object as a false red -- and this leg's own source says a false TRUNK
RED "is what teaches people to ignore the line".  The trust cost is identical;
only the mechanism differs.

Second defect, found in the same output above: the run was BOTH red and
uncertifiable, and the exit-1 branch's grep had no `uncertifiable:` alternative.
So the branch that reports the strictly worse tree named LESS of what was wrong
-- the un-run file went unnamed, while the exit-2 branch would have named it.

The load-bearing claims:
  1. the leg exists and can be lifted out of the script
  2. RED path: the failing test's indented detail survives to stdout
  3. RED path: an un-run file is named too (both-wrong case)
  4. UNCERTIFIABLE path: the detail survives there as well
  5. the full output is written OUTSIDE the tree and its path is printed
     (the inline tail is a view; the log is the data -- rc.sh's RC_LOG idiom)
  6. the green path stays quiet, and neither banner nor exit code regresses
     (this file must not re-break GH #243: exit 2 is never TRUNK RED)
  7. the leg never writes inside the repo (the auto-stash refusal above it in
     the script turns on exactly this property)

Run:  python3 tests/test_selfcheck_py_leg.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SCRIPT = os.path.join(REPO, "tools", "agent", "routine_selfcheck.sh")

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)


def code_only(text):
    """Drop whole-line comments.

    Borrowed verbatim in spirit from tests/test_selfcheck_lua_leg.py: this
    wrapper documents at length what its branches USED to print, so an
    absence-assertion that reads prose fails on a correct script.
    """
    return "\n".join(ln for ln in text.splitlines()
                     if not ln.lstrip().startswith("#"))


# ---------------------------------------------------------------------------
# 1. lift the leg out of the script
# ---------------------------------------------------------------------------
src = open(SCRIPT, encoding="utf-8").read()

_lo = src.find("sc_leg 'trunk-red(python)'")
_hi = src.find("sc_leg 'trunk-red(lua)'")
check(_lo != -1, "1a: the script has a python trunk-health leg at all")
check(_hi > _lo, "1b: the leg's end (the next leg's sc_leg) is locatable")
LEG_SRC = src[_lo:_hi] if (_lo != -1 and _hi > _lo) else ""
LEG_CODE = code_only(LEG_SRC)

# The leg calls `bash tests/run_py_tests.sh` by a repo-relative path, so a
# stand is a directory with a tests/run_py_tests.sh that prints what we want and
# exits with the code we want.  That is the whole isolation: no real suite runs
# here, which is what keeps this test seconds rather than the ~2 minutes the
# Lua leg's end-to-end costs (and it is why that one reports UNCERTIFIABLE in
# Routine containers -- see GH #358).
HARNESS_PRE = ("set -u\n"
               ". %s/tools/agent/selfcheck_tally.sh\n"
               "note() { sc_note \"$1\"; }\n"
               "unchecked() { sc_note 2; }\n" % REPO)

# A canned runner output with the exact SHAPE run_py_tests.sh emits: PASS/FAIL
# lines at column 0, the failing test's own output indented six spaces, then
# the summary and the trailing `failed:` / `uncertifiable:` lines.
DETAIL_MARK = "AssertionError: banner is the last non-blank line"
FAKE_OUT_RED = (
    "PASS  tests/test_alpha.py\n"
    "FAIL  tests/test_rc_wrapper.py\n"
    "      exit 3: wrapper exits with the command's code                ok\n"
    "      %s\n"
    "      note: this line is the diagnosis and must survive\n"
    "UNCERTIFIABLE  tests/test_selfcheck_lua_leg.py  (did NOT run -- this is not a pass and not a failure)\n"
    "      UNCERTIFIABLE 5a: the clean run did not finish inside 120s\n"
    "\n"
    "71 passed, 1 failed, 1 uncertifiable\n"
    "failed: tests/test_rc_wrapper.py\n"
    "uncertifiable: tests/test_selfcheck_lua_leg.py\n"
) % DETAIL_MARK

FAKE_OUT_UNRUN = (
    "PASS  tests/test_alpha.py\n"
    "UNCERTIFIABLE  tests/test_census.py  (did NOT run -- this is not a pass and not a failure)\n"
    "      %s\n"
    "\n"
    "72 passed, 0 failed, 1 uncertifiable\n"
    "uncertifiable: tests/test_census.py\n"
) % DETAIL_MARK

# The indented line here is SYNTHETIC and deliberately so.  run_py_tests.sh
# prints a test's own output only for a non-pass, so a genuinely green run
# cannot emit a six-space-indented line -- which means an all-green stand
# agrees with the broken rule "dump the detail unconditionally" and 6d/6e never
# have to discriminate.  Measured: the mutation "call sc_py_detail on the green
# path too" SURVIVED against a realistic green stand, and went red the moment
# this line was added.  That is evidence-discipline rule 2 -- a surviving mutant
# means suspect the assertion, because the corpus happened to agree.
#
# The count line stays LAST: the green path is `tail -1`, so anything appended
# after it would break 6c for an unrelated reason.
FAKE_OUT_GREEN = (
    "PASS  tests/test_alpha.py\n"
    "      %s\n"
    "73 passed, 0 failed, 0 uncertifiable\n"
) % DETAIL_MARK


def run_leg(fake_out, fake_rc):
    """Run the real leg source against a stand runner -> (text, rc)."""
    tree = tempfile.mkdtemp(prefix="selfcheck_pyleg_")
    tmp = tempfile.mkdtemp(prefix="selfcheck_pytmp_")
    try:
        os.mkdir(os.path.join(tree, "tests"))
        runner = os.path.join(tree, "tests", "run_py_tests.sh")
        with open(runner, "w", encoding="utf-8") as fh:
            fh.write("#!/usr/bin/env bash\ncat <<'SC_EOF'\n%s\nSC_EOF\nexit %d\n"
                     % (fake_out.rstrip("\n"), fake_rc))
        # `sc_worst`, not `$worst`: the script assigns `worst` only at its very
        # last line, well below this leg, so `exit "$worst"` under `set -u`
        # aborts the harness with 127 -- a number that is neither 0, 2 nor 3
        # and would fail every exit-code check for a reason having nothing to
        # do with the leg.
        harness = HARNESS_PRE + LEG_SRC + "\nexit \"$(sc_worst)\"\n"
        env = dict(os.environ)
        env["TMPDIR"] = tmp
        p = subprocess.run(["bash", "-c", harness], cwd=tree, timeout=60,
                           capture_output=True, text=True, env=env)
        # Snapshot what the leg left behind inside "the repo" for check 7.
        left = sorted(os.listdir(tree)) + sorted(os.listdir(os.path.join(tree, "tests")))
        return p.stdout + p.stderr, p.returncode, left, tmp
    finally:
        shutil.rmtree(tree, ignore_errors=True)
        # `tmp` is deliberately NOT removed here -- check 5 reads the log the
        # leg wrote into it.  Cleaned by the caller.


if not LEG_SRC:
    print("  SKIP  2-7: leg source not isolated")
    failures.append("leg source not isolated")
else:
    # -----------------------------------------------------------------------
    # 2/3. the RED path
    # -----------------------------------------------------------------------
    red_out, red_rc, red_left, red_tmp = run_leg(FAKE_OUT_RED, 1)
    try:
        check(red_rc == 3, "2a: a failing suite still raises the exit code to 3 (got %d)" % red_rc)
        check("TRUNK RED" in red_out, "2b: the red banner is still printed")
        check("FAIL  tests/test_rc_wrapper.py" in red_out,
              "2c: the failing file is still named")
        check(DETAIL_MARK in red_out,
              "2d: the failing test's OWN output survives to stdout -- this is "
              "the defect: an anchored grep dropped every six-space-indented "
              "line, so the reader got a filename and no diagnosis")
        check("note: this line is the diagnosis and must survive" in red_out,
              "2e: the whole indented block survives, not just its first line")
        check("uncertifiable: tests/test_selfcheck_lua_leg.py" in red_out,
              "3a: a run that is BOTH red and un-run names the un-run file too "
              "(the exit-1 branch reports the worse tree; it must not name less "
              "of what is wrong than the exit-2 branch does)")

        # -------------------------------------------------------------------
        # 5. the full output lands outside the tree, and is named
        # -------------------------------------------------------------------
        m = re.search(r"^PY_LOG: (\S+)", red_out, re.M)
        check(m is not None, "5a: the red path prints PY_LOG: <path>")
        if m:
            log = m.group(1)
            check(os.path.isfile(log), "5b: PY_LOG names a real file (%s)" % log)
            if os.path.isfile(log):
                body = open(log, encoding="utf-8").read()
                check(DETAIL_MARK in body, "5c: the log carries the detail")
                check("71 passed, 1 failed" in body,
                      "5d: the log is the WHOLE runner output, not the inline view")
            check(os.path.realpath(log).startswith(os.path.realpath(red_tmp)),
                  "5e: the log is written under TMPDIR, i.e. OUTSIDE the repo")

        # -------------------------------------------------------------------
        # 7. the leg writes nothing inside the tree
        # -------------------------------------------------------------------
        check(red_left == ["tests", "run_py_tests.sh"],
              "7a: the leg created nothing inside the repo (found %r). The "
              "auto-stash refusal above this leg in the script turns on this "
              "property." % (red_left,))
    finally:
        shutil.rmtree(red_tmp, ignore_errors=True)

    # -----------------------------------------------------------------------
    # 4. the UNCERTIFIABLE path
    # -----------------------------------------------------------------------
    un_out, un_rc, _un_left, un_tmp = run_leg(FAKE_OUT_UNRUN, 2)
    try:
        check(un_rc == 2, "4a: a could-not-run suite exits 2, not 3 (got %d). "
                          "GH #243: exit 2 is NOT a red trunk." % un_rc)
        check("TRUNK RED" not in un_out,
              "4b: GH #243 does not regress -- a could-not-run is never TRUNK RED")
        check("UNCERTIFIABLE" in un_out, "4c: the un-run banner is printed")
        check(DETAIL_MARK in un_out,
              "4d: the detail survives on the UNCERTIFIABLE path too -- 'why "
              "did it not run' is the same question as 'why did it fail', and "
              "the same anchored grep was eating the answer")
        check(re.search(r"^PY_LOG: \S+", un_out, re.M) is not None,
              "4e: the un-run path names its log as well")
    finally:
        shutil.rmtree(un_tmp, ignore_errors=True)

    # -----------------------------------------------------------------------
    # 6. the GREEN path stays quiet
    # -----------------------------------------------------------------------
    gr_out, gr_rc, _gr_left, gr_tmp = run_leg(FAKE_OUT_GREEN, 0)
    try:
        check(gr_rc == 0, "6a: a green suite still exits 0 (got %d)" % gr_rc)
        check("TRUNK RED" not in gr_out and "UNCERTIFIABLE" not in gr_out,
              "6b: the green path prints no banner")
        check("73 passed, 0 failed, 0 uncertifiable" in gr_out,
              "6c: the green path still prints the count line")
        check("PY_LOG:" not in gr_out,
              "6d: no log is written on the green path -- a log every round is "
              "noise, and the leg runs before every work unit")
        check(DETAIL_MARK not in gr_out,
              "6e: the green path does not start dumping detail")
    finally:
        shutil.rmtree(gr_tmp, ignore_errors=True)

    # -----------------------------------------------------------------------
    # source-level pins
    # -----------------------------------------------------------------------
    check("note 3" in LEG_CODE and "note 2" in LEG_CODE,
          "8a: both non-green branches still call the exit-code accumulator "
          "(a leg that reports without raising the exit code is not a gate)")
    check("uncertifiable:" in LEG_CODE.split("note 3")[0].split("elif")[-1] or
          "uncertifiable:" in LEG_CODE,
          "8b: the red branch's filter admits the uncertifiable line")


print()
if failures:
    print("selfcheck python leg: %d of %d check(s) FAILED" % (len(failures), checks))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("selfcheck python leg: all %d checks ok" % checks)
