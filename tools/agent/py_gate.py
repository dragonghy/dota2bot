#!/usr/bin/env python3
"""Iron rule 6's python half, for the push hook (GH #616).

Runs the FAST python ratchets -- the ones `tools/agent/py_gate_measure.py`
measured as cheap enough for a hook -- and reports in the repo's 0/2/3
vocabulary:

    0  clean          every in-scope test passed
    2  could not run  something in scope did not produce an answer
    3  findings       an in-scope test failed

`.githooks/pre-push` refuses the push on BOTH 2 and 3, exactly as it already
does for the Lua half.  "Could not run" reading as "allowed" is how GH #171's
SKIP and GH #205's `Unable to locate package` each became an established fact.

SCOPE IS NARROW ON PURPOSE, AND THE BANNER SAYS SO.  This gate does not claim
the whole python suite; `tests/run_py_tests.sh` is still what the director's
开工自检 runs, and slow legs like `tests/test_selfcheck_lua_leg.py` (120s budget,
GH #358) stay there.  A wrapper whose banner claims more than it asserts is a
trap this repo has already paid for (GH #198 §2), so every line below counts
what it actually did.

THE ONE DISTINCTION THAT CARRIES WEIGHT.  A test that does not answer inside
its timeout is handled by whether we had ALREADY MEASURED IT:

  * measured fast, now times out -> that is a CHANGE OF STATE on a test this
    gate promised to run.  Exit 2, push refused, re-measure.
  * never measured (new file)    -> out of scope, listed by name in the banner,
    no refusal.  It was never promised; the full suite still covers it.

Silently dropping the first case is how a gate quietly stops gating.

Usage:  python3 tools/agent/py_gate.py [--list]
"""
import json
import os
import subprocess
import sys
import time

# this file is tools/agent/<me>.py -- three dirnames up is the repo root
_DEFAULT_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
# Overridable so tests/test_py_gate.py can stand up a throwaway repo and drive
# every branch.  An override is ANNOUNCED at the top of every run (see main):
# a gate that can be pointed somewhere else quietly is a gate that can be
# dodged quietly, and this repo has already paid for silent skips twice
# (GH #171 SKIP, GH #205 `Unable to locate package`).
ROOT = os.environ.get("PY_GATE_ROOT") or _DEFAULT_ROOT
MANIFEST = os.environ.get("PY_GATE_MANIFEST") or os.path.join(
    ROOT, "tools", "agent", "py_gate_manifest.json"
)

EXIT_CLEAN = 0
EXIT_UNRUN = 2
EXIT_FINDINGS = 3


def load_manifest(path=MANIFEST):
    with open(path) as fh:
        return json.load(fh)


def discover(root=ROOT):
    d = os.path.join(root, "tests")
    if not os.path.isdir(d):
        return []
    return sorted(
        os.path.join("tests", f)
        for f in os.listdir(d)
        if f.startswith("test_") and f.endswith(".py")
    )


def partition(manifest, on_disk):
    """Split the on-disk tests into (selected, skipped, unmeasured, missing).

    Membership comes from the manifest's `in_gate` flag, which
    py_gate_measure.py sets from MEASURED SECONDS.  Nothing here looks at a
    filename to decide whether a test belongs in the gate -- that is GH #616
    constraint 1, and it is the difference between a rule and a guess.
    """
    tests = manifest.get("tests", {})
    on_disk = set(on_disk)
    selected, skipped = [], []
    for rel, meta in sorted(tests.items()):
        if rel not in on_disk:
            continue
        (selected if meta.get("in_gate") else skipped).append(rel)
    unmeasured = sorted(on_disk - set(tests))
    missing = sorted(
        rel for rel, meta in tests.items() if meta.get("in_gate") and rel not in on_disk
    )
    return selected, skipped, unmeasured, missing


def run_one(rel, timeout, root=ROOT):
    """Return (rc, output, seconds, timed_out); rc is None on timeout."""
    t0 = time.time()
    try:
        p = subprocess.run(
            [sys.executable, rel],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
        return p.returncode, p.stdout.decode("utf-8", "replace"), time.time() - t0, False
    except subprocess.TimeoutExpired as exc:
        out = (exc.output or b"").decode("utf-8", "replace")
        return None, out, time.time() - t0, True


def indent(text, pad="      "):
    return "".join(pad + line + "\n" for line in text.rstrip("\n").split("\n"))


def main(argv):
    if os.environ.get("PY_GATE_ROOT") or os.environ.get("PY_GATE_MANIFEST"):
        print("PY GATE REDIRECTED -- root=%s manifest=%s (not the repo's own)"
              % (ROOT, MANIFEST))
    try:
        manifest = load_manifest()
    except Exception as exc:  # missing, unreadable, malformed
        print("PY GATE COULD NOT RUN -- manifest unreadable: %s" % exc)
        print("  Regenerate it:  python3 tools/agent/py_gate_measure.py")
        return EXIT_UNRUN

    cap = float(manifest.get("per_test_cap_seconds", 3.0))
    # Generous headroom over the measured cap: a slow container should not be
    # read as a broken test.  Still far under the 120s legs this gate excludes.
    # In the manifest (not derived here) so a test can drive the timeout branch
    # without spending the real one.
    timeout = float(manifest.get("hook_timeout_seconds") or max(cap * 5.0, 15.0))

    on_disk = discover()
    selected, skipped, unmeasured, missing = partition(manifest, on_disk)

    if "--list" in argv:
        for rel in selected:
            print("IN   %s  (%.2fs)" % (rel, manifest["tests"][rel]["seconds"]))
        for rel in skipped:
            m = manifest["tests"][rel]
            print("OUT  %s  (%.2fs, %s)" % (rel, m["seconds"], m["reason"]))
        for rel in unmeasured:
            print("NEW  %s  (never measured)" % rel)
        return EXIT_CLEAN

    if not selected:
        print("PY GATE COULD NOT RUN -- the manifest selected 0 tests.")
        print("  Regenerate it:  python3 tools/agent/py_gate_measure.py")
        return EXIT_UNRUN

    t0 = time.time()
    findings, unrun, new_over_budget = [], [], []
    ran = 0

    for rel in selected:
        rc, out, secs, timed_out = run_one(rel, timeout)
        if timed_out:
            # Measured fast, now will not answer: a change of state on a test
            # this gate promised to run.  Not a pass.
            unrun.append((rel, "timed out after %.0fs (manifest says %.2fs)"
                          % (secs, manifest["tests"][rel]["seconds"]), out))
        elif rc == 0:
            ran += 1
        elif rc == 2:
            unrun.append((rel, "exit 2 -- the test could not run", out))
        else:
            findings.append((rel, "exit %d" % rc, out))
            ran += 1

    # New tests nobody has measured yet: run them, but a slow one is out of
    # scope rather than a refusal -- this gate never promised to carry it.
    for rel in unmeasured:
        rc, out, secs, timed_out = run_one(rel, timeout)
        if timed_out:
            new_over_budget.append(rel)
        elif rc == 0:
            ran += 1
        elif rc == 2:
            unrun.append((rel, "exit 2 -- the test could not run", out))
        else:
            findings.append((rel, "exit %d" % rc, out))
            ran += 1

    elapsed = time.time() - t0

    for rel, why, out in findings:
        print("FAIL  %s  (%s)" % (rel, why))
        print(indent(out), end="")
    for rel, why, out in unrun:
        print("UNCERTIFIABLE  %s  (%s -- not a pass and not a failure)" % (rel, why))
        if out.strip():
            print(indent(out), end="")

    print(
        "\npy gate: %d ran, %d findings, %d uncertifiable, %.1fs"
        % (ran, len(findings), len(unrun), elapsed)
    )
    print(
        "  scope: %d fast python ratchets (selected by measured seconds <= %.1fs, "
        "cumulative budget %.1fs)" % (len(selected), cap, manifest.get("budget_seconds", 0.0))
    )
    print(
        "  NOT claimed here: %d slower python tests (run by tests/run_py_tests.sh "
        "in 开工自检), and the Lua dynamic half (GH #124)." % len(skipped)
    )
    if unmeasured:
        print("  %d new test(s) not in the manifest were run anyway: %s"
              % (len(unmeasured), " ".join(unmeasured)))
    if new_over_budget:
        print("  %d new test(s) exceeded the hook budget and were EXCLUDED: %s"
              % (len(new_over_budget), " ".join(new_over_budget)))
        print("  (re-measure to record them: python3 tools/agent/py_gate_measure.py)")
    if missing:
        print("  %d manifest test(s) are gone from disk (renamed/deleted): %s"
              % (len(missing), " ".join(missing)))

    if findings:
        return EXIT_FINDINGS
    if unrun:
        return EXIT_UNRUN
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
