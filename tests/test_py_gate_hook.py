#!/usr/bin/env python3
"""Behavioural acceptance for .githooks/pre-push's python half (GH #616).

SPLIT OUT FROM tests/test_py_gate.py ON PURPOSE, AND THE REASON IS THE RULE
ITSELF.  Driving the real hook means paying for the Lua half it runs first
(`luacheck_gate.sh`, 13s warm) once per case -- about 26s here.  The python
push gate admits a test by MEASURED SECONDS, so this file does not belong in
it.  The alternative was to exempt the gate's own test from the gate's own
rule, which is the shape that makes a rule stop meaning anything.  So: the fast
logic checks stay in test_py_gate.py (inside the gate); the expensive
end-to-end wiring lives here and is run by tests/run_py_tests.sh in 开工自检.

What it asserts, and why each one can fail open:

  1. RED python half  -> the hook exits 1 (push refused) and NAMES the test.
     GH #616's acceptance criterion, in the words it was written in.
  2. COULD-NOT-RUN    -> the hook exits 1 too.  This is the load-bearing half:
     "could not run" reading as "allowed" is exactly how GH #171's SKIP and
     GH #205's `Unable to locate package` each became an established fact that
     nobody re-examined for weeks.
  3. CLEAN            -> the hook exits 0, so the gate does not brick the repo.
     Without this control, 1 and 2 are satisfied by a hook that refuses always.
  4. RULE6_BYPASS=1 still gets a dead container through, and its banner says
     the python half was skipped TOO -- a bypass whose text names only half of
     what it skipped is a report the author will copy honestly and still get
     wrong (GH #198 §2).

Run:  python3 tests/test_py_gate_hook.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
HOOK = os.path.join(REPO, ".githooks", "pre-push")

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)


PASSING = "import sys\nprint('ok')\nsys.exit(0)\n"
FAILING = "import sys\nprint('THE FINDING TEXT')\nsys.exit(1)\n"
UNRUN = "import sys\nprint('could not read my corpus')\nsys.exit(2)\n"


def make_tree(tmp, tag, body):
    root = os.path.join(tmp, tag)
    os.makedirs(os.path.join(root, "tests"))
    os.makedirs(os.path.join(root, "tools", "agent"))
    with open(os.path.join(root, "tests", "test_a.py"), "w") as fh:
        fh.write(body)
    mpath = os.path.join(root, "tools", "agent", "py_gate_manifest.json")
    with open(mpath, "w") as fh:
        json.dump({
            "per_test_cap_seconds": 3.0,
            "budget_seconds": 12.0,
            "hook_timeout_seconds": 15.0,
            "tests": {"tests/test_a.py": {"seconds": 0.1, "in_gate": True,
                                          "reason": "fast"}},
        }, fh)
    return root, mpath


def run_hook(root, mpath, **extra_env):
    env = dict(os.environ)
    env["PY_GATE_ROOT"] = root
    env["PY_GATE_MANIFEST"] = mpath
    env.update(extra_env)
    return subprocess.run(["bash", HOOK], cwd=REPO, env=env,
                          capture_output=True, text=True, timeout=900)


tmp = tempfile.mkdtemp(prefix="pygatehook_")
try:
    # ---- 3 first: the control.  If a clean tree does not pass, checks 1 and
    # 2 below are satisfied by a hook that simply refuses everything, and the
    # whole file would be green while the repo could not push at all.
    root, mpath = make_tree(tmp, "clean", PASSING)
    r = run_hook(root, mpath)
    check(r.returncode == 0,
          "3: (control) a CLEAN python half lets the push through -- without "
          "this, 1 and 2 pass vacuously for a hook that always refuses "
          "(got %d: %r)" % (r.returncode, (r.stdout + r.stderr)[-500:]))

    # ---- 1. red refuses, and names the test
    root, mpath = make_tree(tmp, "red", FAILING)
    r = run_hook(root, mpath)
    check(r.returncode == 1,
          "1a: a RED python ratchet REFUSES the push (got %d)" % r.returncode)
    check("test_a.py" in r.stdout,
          "1b: and the refusal names WHICH python test found it (GH #616 "
          "acceptance) -- got %r" % r.stdout[-400:])
    check("THE FINDING TEXT" in r.stdout,
          "1c: and carries the finding itself, so the author does not have to "
          "re-run the suite to learn what broke")
    check("python half is RED" in r.stdout,
          "1d: and says PYTHON, distinguishably from the Lua half's refusal -- "
          "two gates with one error message is a gate you cannot act on")

    # ---- 2. could-not-run refuses too
    root, mpath = make_tree(tmp, "unrun", UNRUN)
    r = run_hook(root, mpath)
    check(r.returncode == 1,
          "2a: COULD-NOT-RUN refuses as well -- 'it did not run' must not read "
          "as 'it passed' (GH #171, GH #205) (got %d)" % r.returncode)
    check("could NOT RUN" in r.stdout,
          "2b: and the banner says could-not-run, not red -- the two call for "
          "different actions (buy the tool vs fix the code)")

    # ---- 4. the bypass still works, and its text names BOTH halves
    root, mpath = make_tree(tmp, "bypass", FAILING)
    r = run_hook(root, mpath, RULE6_BYPASS="1")
    check(r.returncode == 0,
          "4a: RULE6_BYPASS=1 still gets a dead container through even over a "
          "RED python half (got %d)" % r.returncode)
    check("SKIPPED, not passed" in r.stdout,
          "4b: and calls itself a skip, not a pass -- that line is the one the "
          "author is expected to quote in the round report")
    check("python" in r.stdout,
          "4c: and names the PYTHON half among what it skipped.  A bypass "
          "banner that lists only luacheck would be copied into a report "
          "honestly and still understate what went unchecked")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("\npy_gate_hook: %d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)
