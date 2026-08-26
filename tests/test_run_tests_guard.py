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

print("\n%d checks, %d failures" % (ran, len(failures)))
if failures:
    for f in failures:
        print("FAIL: %s" % f)
    sys.exit(1)
