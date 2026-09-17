#!/usr/bin/env python3
"""Acceptance for tools/agent/py_gate_coverage.py (GH #843 acceptance 2).

WHY THIS EXISTS.  The subject computes a RELATION -- which python tests under
`tests/` no automatic reader runs -- and ratchets it.  On the day it landed the
answer was **0 uncovered of 147**, and that is exactly the shape this repo has
paid for twice: a check whose honest answer is "all clear" is indistinguishable
from a check that cannot see anything.  `py_gate`'s `5f` asserted
`len(rt) >= 100` while claiming to assert coverage; the selfcheck's Lua leg had
four cases that "passed" without the clean run finishing.

⭐ SO NON-VACUITY IS THE PRIMARY CLAIM HERE, not a footnote.  The python half is
covered today only because 开工自检's leg discovers by GLOB (a superset of the
manifest by construction) while the Lua half discovers by TAG (GH #806: a
`[hero]`-tagged over-cap file fell through both selectors).  That difference is
the whole reason the python answer is 0 and the Lua answer was 113 -- and it is
a property of one line in `tests/run_py_tests.sh`, which nothing else asserts.
Two of its three reachable falsifications are tested here as MUTATION STANDS
against a temp tree, with the exit code read bare:

  A. a test lands in a SUBDIRECTORY (`tests/mock/` etc. already exist), so the
     depth-1 glob misses it and so does the gate;
  B. the runner's glob is NARROWED (an incremental walk is one of #843's own
     suggested options, and it would convert this half into the Lua half).

  (C, the leg acquiring a time cap, is NOT testable by set arithmetic -- it is
  named in the subject's docstring and left to RULING 57's precedent.  Stating
  that here rather than faking a check for it: a test that pretends to cover C
  would be the same defect one layer up.)

The load-bearing claims, in the order they can fail:
  1. the reader's selector is EXTRACTED from tests/run_py_tests.sh, not
     re-spelled -- narrowing the runner's glob really does change the answer.
  2. an unreadable/ambiguous selector is UNCERTIFIABLE (exit 2), never a pass:
     a reader whose rule we had to guess is not a reader we may credit.
  3. THE RATCHET BITES: a newly-uncovered file exits 3 and is named.
  4. no baseline => exit 2 with a banner that does not read like a pass.
  5. --update-baseline REFUSES growth.
  6. #843 acceptance 2, on the REAL repo: every `in_gate: false` row carries a
     written reader attribution, and none of them reads `NONE`.
  7. it runs NO test and stays cheap (the design rests on nobody skipping it).

MUTATION STAND (§四): four mutants of the SUBJECT, run against the same temp
trees.  Restore goes through a file copy outside the tree + `sha256sum -c`
(evidence discipline 1) -- never `git checkout`, which would discard the
subject itself while it is still uncommitted.

Run:  python3 tests/test_py_gate_coverage.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SUBJECT = os.path.join(REPO, "tools", "agent", "py_gate_coverage.py")
# Overridable ONLY so the mutation stand can point at a mutated COPY in a temp
# dir: the stand must never write the repo file (evidence discipline 1, and
# RULING 70's note that a stand restored in-tree can leave a patched control).
SUBJECT = os.environ.get("PY_GATE_COVERAGE_SUBJECT", SUBJECT)
RUNNER = os.path.join(REPO, "tests", "run_py_tests.sh")
MANIFEST = os.path.join(REPO, "tools", "agent", "py_gate_manifest.json")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append("FAIL: " + label)
        print("FAIL: " + label)


def run(root, manifest, baseline, *args, subject=SUBJECT):
    env = dict(os.environ)
    env["PY_GATE_COVERAGE_ROOT"] = root
    env["PY_GATE_COVERAGE_MANIFEST"] = manifest
    env["PY_GATE_COVERAGE_BASELINE"] = baseline
    return subprocess.run(
        [sys.executable, subject] + list(args),
        capture_output=True, text=True, timeout=120, env=env,
    )


def make_tree(names, runner_glob="tests/test_*.py", in_gate=()):
    """A minimal repo: tests/<names>, a runner carrying `runner_glob`, a
    manifest whose `in_gate` rows are `in_gate`."""
    root = tempfile.mkdtemp(prefix="pygatecov_")
    for rel in names:
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write("# placeholder\n")
    os.makedirs(os.path.join(root, "tests"), exist_ok=True)
    with open(os.path.join(root, "tests", "run_py_tests.sh"), "w",
              encoding="utf-8") as fh:
        fh.write("#!/usr/bin/env bash\nset -u\n"
                 "for f in %s; do\n  python3 \"$f\"\ndone\n" % runner_glob)
    mpath = os.path.join(root, "manifest.json")
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump({"tests": {
            rel: {"seconds": 1.0, "in_gate": rel in in_gate,
                  "reason": None if rel in in_gate else "over_per_test_cap"}
            for rel in names if rel.startswith("tests/") and "/" not in rel[6:]
        }}, fh)
    return root, mpath, os.path.join(root, "baseline.json")


# ---------------------------------------------------------------- §1 real repo
res = run(REPO, MANIFEST, os.path.join(REPO, "tools", "agent",
                                       "py_gate_coverage_baseline.json"),
          "--attribution")
check(res.returncode == 0,
      "1a: the subject is clean on the real repo (got %d)\n%s"
      % (res.returncode, res.stdout[-800:]))
check("glob tests/test_*.py" in res.stdout,
      "1b: the real runner's glob is reported, so the reader is named not assumed")
check("UNCOVERED (no automatic reader runs these): 0 of" in res.stdout,
      "1c: the real python corpus has nothing falling through both selectors")
# §6 -- GH #843 acceptance 2, asserted rather than narrated.
check(": NONE" not in res.stdout and " NONE" not in res.stdout.replace(
        "NONE)", ""),
      "6a: no out-of-gate row reads NONE -- #843 acceptance 2 is satisfied, "
      "not merely computed")
with open(MANIFEST, encoding="utf-8") as fh:
    real_rows = json.load(fh)["tests"]
n_out = sum(1 for v in real_rows.values() if not v.get("in_gate"))
check(n_out > 0,
      "6b: the real manifest still HAS out-of-gate rows (%d) -- if this ever "
      "hits zero, §6a passes vacuously and this check is the only warning"
      % n_out)
check("out-of-gate rows with a written reader: %d of %d" % (n_out, n_out)
      in res.stdout,
      "6c: every one of the %d out-of-gate rows is attributed" % n_out)

# ------------------------------------------------------- §2 non-vacuity: subdir
# A. A test in a subdirectory: invisible to a depth-1 glob AND to the gate.
root, mpath, bpath = make_tree(
    ["tests/test_a.py", "tests/test_b.py"], in_gate=("tests/test_a.py",))
try:
    r0 = run(root, mpath, bpath, "--update-baseline")
    check(r0.returncode == 0 and "0 uncovered" in r0.stdout,
          "2a: a clean temp tree baselines at 0 uncovered (got %d)\n%s"
          % (r0.returncode, r0.stdout))
    os.makedirs(os.path.join(root, "tests", "mock"), exist_ok=True)
    with open(os.path.join(root, "tests", "mock", "test_sub.py"), "w") as fh:
        fh.write("# lands in a subdirectory\n")
    r1 = run(root, mpath, bpath)
    check(r1.returncode == 3,
          "2b: a test in tests/mock/ is UNCOVERED and exits 3 (got %d)\n%s"
          % (r1.returncode, r1.stdout))
    check("tests/mock/test_sub.py" in r1.stdout and "NEW UNCOVERED" in r1.stdout,
          "2c: it is named, not merely counted\n%s" % r1.stdout)
    r2 = run(root, mpath, bpath, "--update-baseline")
    check(r2.returncode == 3 and "REFUSED" in r2.stdout,
          "5a: --update-baseline REFUSES to record growth (got %d)" % r2.returncode)
finally:
    shutil.rmtree(root, ignore_errors=True)

# -------------------------------------------- §1 extraction: narrow the glob
# B. The runner's glob is narrowed.  If the subject hardcoded the pattern this
# is invisible; because it reads the runner, the answer changes.
root, mpath, bpath = make_tree(
    ["tests/test_a.py", "tests/test_keep.py"], in_gate=())
try:
    r0 = run(root, mpath, bpath, "--update-baseline")
    check(r0.returncode == 0 and "0 uncovered" in r0.stdout,
          "1d: baseline clean before narrowing (got %d)" % r0.returncode)
    with open(os.path.join(root, "tests", "run_py_tests.sh"), "w") as fh:
        fh.write("#!/usr/bin/env bash\nset -u\n"
                 "for f in tests/test_keep*.py; do\n  python3 \"$f\"\ndone\n")
    r1 = run(root, mpath, bpath)
    check(r1.returncode == 3 and "tests/test_a.py" in r1.stdout,
          "1e: narrowing the RUNNER's glob makes test_a uncovered -- the "
          "selector is read from the runner, not re-spelled (got %d)\n%s"
          % (r1.returncode, r1.stdout))
    check("glob tests/test_keep*.py" in r1.stdout,
          "1f: the narrowed glob itself is echoed back")
    # §6d -- THE SYNTHETIC CASE FOR THE ATTRIBUTION RULE (evidence discipline 2).
    # On the real repo every out-of-gate row IS read by the leg, so a subject
    # that credited the leg unconditionally would agree with the corpus word for
    # word and §6a would never have to discriminate.  Here test_a.py is
    # out-of-gate AND outside the narrowed glob, so the only correct answer is
    # NONE -- which is also #843's "哪怕结论是「无」" case.
    r1b = run(root, mpath, bpath, "--attribution")
    attr_line = [ln for ln in r1b.stdout.splitlines()
                 if "tests/test_a.py" in ln and "NONE" in ln]
    check(bool(attr_line),
          "6d: a row that is out-of-gate AND outside the reader's glob is "
          "attributed NONE, not credited to the leg\n%s" % r1b.stdout)
    # Both rows are out-of-gate in this tree (`in_gate=()`); only test_keep.py
    # is still inside the narrowed glob, so the honest summary is 1 of 2.
    check("with a written reader: 1 of 2" in r1b.stdout,
          "6e: and the summary counts it as unattributed, so the headline "
          "number cannot read healthy while a row has no reader\n%s"
          % r1b.stdout)
    # §2 -- an unreadable selector is could-not-run, not a pass.
    with open(os.path.join(root, "tests", "run_py_tests.sh"), "w") as fh:
        fh.write("#!/usr/bin/env bash\n# no loop at all\n")
    r2 = run(root, mpath, bpath)
    check(r2.returncode == 2 and "UNCERTIFIABLE" in r2.stdout,
          "2d: an unreadable selector is exit 2 UNCERTIFIABLE (got %d)\n%s"
          % (r2.returncode, r2.stdout))
    check("NOT a pass" in r2.stdout,
          "2e: the exit-2 banner says it is not a pass (rule 10 vocabulary)")
    with open(os.path.join(root, "tests", "run_py_tests.sh"), "w") as fh:
        fh.write("#!/usr/bin/env bash\nset -u\n"
                 "for f in tests/test_*.py; do\n  python3 \"$f\"\ndone\n"
                 "for g in tests/other_*.py; do\n  python3 \"$g\"\ndone\n")
    r3 = run(root, mpath, bpath)
    check(r3.returncode == 2 and "found 2" in r3.stdout,
          "2f: TWO candidate loops is ambiguous => exit 2, never a guess "
          "(got %d)\n%s" % (r3.returncode, r3.stdout))
finally:
    shutil.rmtree(root, ignore_errors=True)

# ------------------------------------------------- §3 an empty corpus is not 0
# The healthy answer to this relation is "0 uncovered", so an empty corpus
# produces a reading that is CHARACTER-FOR-CHARACTER the healthy one.  Found by
# reading the subject adversarially while writing it, not by a mutant.
root, mpath, bpath = make_tree(["tests/test_a.py"], in_gate=("tests/test_a.py",))
try:
    r0 = run(root, mpath, bpath, "--update-baseline")
    check(r0.returncode == 0, "3a: baseline banks on a non-empty corpus")
    os.remove(os.path.join(root, "tests", "test_a.py"))
    r1 = run(root, mpath, bpath)
    check(r1.returncode == 2 and "empty corpus" in r1.stdout,
          "3b: an emptied tests/ is UNCERTIFIABLE, not a clean 0 of 0 "
          "(got %d)\n%s" % (r1.returncode, r1.stdout))
    check("0 of 0" not in r1.stdout,
          "3c: and it never prints the vacuous headline at all")
finally:
    shutil.rmtree(root, ignore_errors=True)

# ------------------------------------------------------------ §4 no baseline
root, mpath, bpath = make_tree(["tests/test_a.py"], in_gate=("tests/test_a.py",))
try:
    r = run(root, mpath, bpath)
    check(r.returncode == 2 and "no baseline yet" in r.stdout,
          "4a: no baseline => exit 2 (got %d)" % r.returncode)
    check("NOT a pass" in r.stdout,
          "4b: and it says so in the reader's own vocabulary")
finally:
    shutil.rmtree(root, ignore_errors=True)

# ------------------------------------------------------------------- §7 cost
root, mpath, bpath = make_tree(
    ["tests/test_%d.py" % i for i in range(60)], in_gate=())
trip = os.path.join(tempfile.mkdtemp(prefix="pygatecov_trip_"), "ran")
bindir = tempfile.mkdtemp(prefix="pygatecov_bin_")
try:
    # Any attempt to actually execute a test would go through one of these.
    for name in ("python3", "lua5.1", "bash"):
        p = os.path.join(bindir, name)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write("#!/bin/sh\ntouch %s\nexit 0\n" % trip)
        os.chmod(p, 0o755)
    env = dict(os.environ)
    env["PATH"] = bindir + os.pathsep + env.get("PATH", "")
    env["PY_GATE_COVERAGE_ROOT"] = root
    env["PY_GATE_COVERAGE_MANIFEST"] = mpath
    env["PY_GATE_COVERAGE_BASELINE"] = bpath
    t0 = time.time()
    subprocess.run([sys.executable, SUBJECT, "--update-baseline"],
                   capture_output=True, text=True, timeout=120, env=env)
    elapsed = time.time() - t0
    check(not os.path.exists(trip),
          "7a: the subject executed no test -- it is set arithmetic, and the "
          "design rests on it staying cheap")
    check(elapsed < 10.0,
          "7b: a full run costs well under 10s (got %.2fs)" % elapsed)
    print("  NOTE  subject cost on this container: %.2fs" % elapsed)
finally:
    shutil.rmtree(root, ignore_errors=True)
    shutil.rmtree(bindir, ignore_errors=True)

print("\n%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)
