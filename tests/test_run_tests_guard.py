#!/usr/bin/env python3
"""tests/run_tests.lua -- a run that executed zero test bodies must not exit 0.

WHY (GH #200, batch desk 2026-08-26T03:15Z): the pre-launch gate that was
supposed to prove "every hero file still loads" before paying ~$2.1 for a wave
was `lua5.1 tests/test_smoke_load.lua`, which returns the test TABLE and calls
nothing -- exit 0, zero bytes of output.  The neighbouring typo is the same
shape through the runner: the filter matches a FILENAME SUBSTRING, so
`run_tests.lua tests/test_smoke_load.lua` matched 0 of 190 files and printed
`0 tests, 0 failures` with exit 0.  Both are indistinguishable from a real pass
at the exit code, and no counter raised its hand.

TWO TIERS, and the split is the point.  The behavioural tier needs lua5.1,
which a fresh container does not have.  Skipping the whole file there would
reproduce the defect being fixed (a check that proves nothing and says so only
in text nobody reads), so the SOURCE tier below runs everywhere and fails if the
guard is deleted from run_tests.lua.  The behavioural tier is added on top when
the interpreter is present.  Absence of lua5.1 therefore weakens this test but
cannot silently defeat it.  (The selfcheck's own `SKIP (no lua5.1)` line, which
does not lift an exit code, is GH #171 and is ruled there, not duplicated here.)
"""

import os
import shutil
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNNER = os.path.join(REPO, "tests", "run_tests.lua")

failures = []
ran = 0


def check(label, cond, detail=""):
    global ran
    ran += 1
    if cond:
        print("  ok   %s" % label)
    else:
        failures.append("%s%s" % (label, (" -- " + detail) if detail else ""))
        print("  FAIL %s%s" % (label, (" -- " + detail) if detail else ""))


# --- tier 1: source ratchet (always runs) ----------------------------------
print("tier 1: source ratchet")
with open(RUNNER, encoding="utf-8") as fh:
    src = fh.read()

check("counts files matched by the filter", "matched = matched + 1" in src,
      "without a matched counter, 'filter selected nothing' cannot be told "
      "apart from 'nothing failed'")
check("has a zero-test branch", "NO TESTS RAN" in src)
check("that branch exits non-zero", "os.exit(2)" in src,
      "a diagnostic that leaves the exit code at 0 is the defect, not the fix")
check("names both causes separately",
      "matched == 0" in src and "total == 0" in src,
      "a filter typo and a file defining no tests need different fixes")

# --- tier 1b: the contract guard (GH #387) ---------------------------------
# A file whose chunk returns a non-table reached `pairs(tests)` OUTSIDE the
# pcall, so it did not fail -- it killed the runner, mid-suite, and every file
# after it silently went unrun (~229 of 277 on 2026-09-01).  Two properties, and
# the second is the one with the blast radius:
check("has a return-contract branch", "type(tests) ~= 'table'" in src,
      "a chunk returning nil must be caught before pairs() sees it")
check("the contract branch fails the FILE, not the run",
      "contract error" in src and "os.exit" not in src.split("contract error")[1]
      .split("else")[0],
      "one bad file must not be able to delete the other files' results")

# --- tier 1c: no test file runs itself (the shape that caused GH #387) ------
# The bad file carried a PRIVATE copy of the runner ending in `os.exit(1)`.  It
# passed standalone, which is why it looked fine, and its `os.exit` would have
# taken the runner down mid-suite the first time one of its assertions went red.
# The runner is the only supported entry point (GH #200); a test file that
# exits the process is not a test file.
_self_runners = []
for _n in sorted(os.listdir(os.path.join(REPO, "tests"))):
    if not (_n.startswith("test_") and _n.endswith(".lua")):
        continue
    with open(os.path.join(REPO, "tests", _n), encoding="utf-8") as _fh:
        _body = "\n".join(ln for ln in _fh.read().splitlines()
                          if not ln.lstrip().startswith("--"))
    if "os.exit" in _body:
        _self_runners.append(_n)
check("no test file exits the process itself", not _self_runners,
      "these carry a private harness and can decapitate the run: %s"
      % ", ".join(_self_runners))

# --- tier 2: behaviour (needs lua5.1) --------------------------------------
lua = shutil.which("lua5.1")
if lua is None:
    print("tier 2: SKIPPED (no lua5.1) -- tier 1 above still ran and still binds")
else:
    print("tier 2: behaviour under %s" % lua)

    def run(*args):
        p = subprocess.run([lua, "tests/run_tests.lua"] + list(args), cwd=REPO,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return p.returncode, p.stdout.decode("utf-8", "replace")

    rc, out = run("tests/test_smoke_load.lua")
    check("path-as-filter (the GH #200 typo) exits non-zero", rc != 0,
          "rc=%d" % rc)
    check("path-as-filter says why", "NO TESTS RAN" in out, out.strip()[-200:])

    rc, out = run("zzz_no_such_filter_exists")
    check("filter matching nothing exits non-zero", rc != 0, "rc=%d" % rc)

    rc, out = run("smoke_load")
    check("the correct entry still passes", rc == 0, "rc=%d :: %s" % (rc, out[-200:]))
    check("the correct entry really ran bodies", "3 tests, 0 failures" in out,
          out.strip()[-200:])

    # --- tier 2b: the contract guard, end to end (GH #387) -----------------
    # A synthetic tree, because the property under test is what happens to the
    # files AFTER the bad one -- and on the live tree there is (now) no bad one.
    # Three files, named so they sort a < b < c: the offender sits in the
    # middle, exactly as the real one sat 48th of 277.
    import tempfile
    _tmp = tempfile.mkdtemp(prefix="run_tests_contract_")
    try:
        _t = os.path.join(_tmp, "tests")
        os.mkdir(_t)
        shutil.copy(RUNNER, os.path.join(_t, "run_tests.lua"))
        with open(os.path.join(_t, "test_aaa_before.lua"), "w") as fh:
            fh.write("local tests = {}\ntests['a'] = function() end\n"
                     "return tests\n")
        # The offender, reproduced in miniature: it runs its own body, prints
        # its own pass line, and returns nothing.
        with open(os.path.join(_t, "test_bbb_contract.lua"), "w") as fh:
            fh.write("io.write('1 run, 0 failed\\n')\n")
        with open(os.path.join(_t, "test_ccc_after.lua"), "w") as fh:
            fh.write("local tests = {}\ntests['c'] = function() end\n"
                     "return tests\n")
        # A SECOND, non-nil offender, and it is not decoration: a guard written
        # `tests == nil` passes every check above and still lets `pairs('oops')`
        # kill the runner.  Without this file the weaker guard is a surviving
        # mutant, so the assertion -- not the guard -- would have been the thing
        # at fault (evidence discipline 2).
        with open(os.path.join(_t, "test_ddd_string.lua"), "w") as fh:
            fh.write("return 'oops'\n")
        p = subprocess.run([lua, "tests/run_tests.lua"], cwd=_tmp,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        cout = p.stdout.decode("utf-8", "replace")
        check("a contract-breaking file exits non-zero", p.returncode != 0,
              "rc=%d" % p.returncode)
        check("it names the offending file", "test_bbb_contract.lua" in cout,
              cout.strip()[-300:])
        check("it says the file returned the wrong type",
              "contract error" in cout, cout.strip()[-300:])
        # THE ONE THAT MATTERS: the runner survived it.  Before the guard this
        # died on `pairs(nil)` with a traceback and no summary line at all, and
        # test_ccc_after never ran.
        check("a non-nil wrong type is caught too (not just nil)",
              "test_ddd_string.lua" in cout, cout.strip()[-300:])
        check("the file AFTER it still ran (the runner survived)",
              "4 tests, 2 failures" in cout,
              "expected 2 bodies + 2 contract failures; got: %s"
              % cout.strip()[-300:])
        check("no interpreter traceback escaped", "stack traceback" not in cout,
              cout.strip()[-300:])
    finally:
        shutil.rmtree(_tmp, ignore_errors=True)

print("\n%d checks, %d failures" % (ran, len(failures)))
if failures:
    for f in failures:
        print("FAIL: %s" % f)
    sys.exit(1)
