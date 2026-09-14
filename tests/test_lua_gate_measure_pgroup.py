#!/usr/bin/env python3
"""`lua_gate_measure.py` must not leave orphans behind (GH #783 §4).

WHY THIS FILE EXISTS.

`owed_executions.json:lua_gate_baseline_e2e` (B), opened 2026-09-12 off a
reproduced sighting: a killed 开工自检 left one `ppid == 1` `lua5.1` still
burning CPU 71 seconds later.  The tool that starts those children measures
SECONDS, and membership in the push gate is decided by those seconds and by
nothing else (GH #616 constraint 1).  So an orphan does not merely waste a core
-- it inflates the very number the tool exists to produce, in the direction that
pushes a test over the 5.5s cap and OUT of the gate.  ⚠️ And a slow reading does
not look wrong: it looks like an ordinary number.

Two holes, and they are NOT the same hole -- this is why there are two cases
rather than one:

  * the PER-TEST TIMEOUT path: `subprocess.run(timeout=...)` kills the direct
    child only; anything that child started outlives it.
  * the SIGNAL path: the 09-12 sighting was a signal to the MEASURE PROCESS,
    not a per-test timeout.  Fixing only the timeout path would have left the
    actually-observed shape untouched.

⛔ EVERY KILL CASE CARRIES A CONTROL that runs the OLD shape and asserts the
orphan DOES survive.  Without it, "no survivor found" is satisfied just as well
by a `pgrep` that never matches anything -- the vacuous-green defect this repo
keeps paying for.  The control is the only thing that makes the green mean
something.
"""
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools", "agent")
TOOL = os.path.join(TOOLS, "lua_gate_measure.py")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    print("  %-4s %s" % ("ok" if cond else "FAIL", label))
    if not cond:
        failures.append(label)


def load_tool():
    import importlib.util

    sys.path.insert(0, TOOLS)
    spec = importlib.util.spec_from_file_location("lua_gate_measure", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# --- marker plumbing -------------------------------------------------------
# A unique sleep duration is the handle: `pgrep -f` on it can only match a
# process this test started, so a survivor is never someone else's.
def marker_cmd(marker):
    """A child that ALSO starts a grandchild -- the shape an orphan comes from."""
    return ["sh", "-c", "sleep %s & sleep %s" % (marker, marker)]


def survivors(marker):
    """PIDs whose command is EXACTLY `sleep <marker>` -- nothing else.

    ⚠️ The first version of this returned every `pgrep -f "sleep <marker>"` hit,
    and that was wrong in a way that made the file green for the wrong reason:
    the DRIVER process carries the marker in its own argv (the marker is inside
    the python source it was handed), so `survivors()` answered "yes, a child is
    running" the instant the driver existed -- before its thread had started any
    child at all.  case 4 then SIGTERMed a driver with nothing under it and
    found no survivor, which is exactly what a working handler looks like.
    ⛔ Its own control (4c) is what caught it: the control leaked in a hand-run
    probe and reported zero here, and only a instrument-side bug explains that
    pair.  Match the exact command, not a substring of anybody's argv.
    """
    want = "sleep %s" % marker
    p = subprocess.run(["pgrep", "-af", want],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    out = []
    for line in p.stdout.decode().splitlines():
        pid, _, cmd = line.partition(" ")
        if cmd.strip() == want and pid.strip().isdigit():
            out.append(pid.strip())
    return out


def gone_within(marker, seconds):
    """True as soon as nothing matches; polling, not a fixed sleep."""
    deadline = time.time() + seconds
    while time.time() < deadline:
        if not survivors(marker):
            return True
        time.sleep(0.05)
    return not survivors(marker)


def reap(marker):
    for pid in survivors(marker):
        try:
            os.kill(int(pid), 9)
        except (OSError, ValueError):
            pass


def unique(tag):
    # seconds with a fractional part nothing else would pick
    return "%d.%s" % (600 + (os.getpid() % 90), tag)


def main():
    mod = load_tool()

    # --- 1: ordinary runs still work ---------------------------------------
    print("case 1: rc and output still come back")
    rc, out, timed_out = mod.run_capture(["sh", "-c", "echo hi; exit 3"], ROOT, 30)
    check(rc == 3, "1a: the child's own exit code is returned (got %r)" % rc)
    check(b"hi" in out, "1b: stdout is captured")
    check(timed_out is False, "1c: a run that finished is not reported as timed out")

    rc, out, timed_out = mod.run_capture(["sh", "-c", "sleep 30"], ROOT, 0.3)
    check(timed_out is True, "1d: a run that blew the timeout says so")
    check(rc is None, "1e: a timed-out run has no exit code to report")

    # --- 2: the child gets its own process group ---------------------------
    print("\ncase 2: the child runs in its OWN process group")
    rc, out, _ = mod.run_capture(["sh", "-c", "ps -o pgid= -p $$"], ROOT, 30)
    child_pgid = out.decode().strip().split()[-1] if out.strip() else ""
    check(child_pgid.isdigit(), "2a: read the child's pgid (%r)" % child_pgid)
    check(child_pgid.isdigit() and int(child_pgid) != os.getpgid(0),
          "2b: it is NOT this process's group (child %s, ours %d)"
          % (child_pgid, os.getpgid(0)))

    # --- 3: the timeout path kills the GROUP -------------------------------
    print("\ncase 3: a per-test timeout takes the grandchild with it")
    m = unique("13")
    try:
        _rc, _out, timed_out = mod.run_capture(marker_cmd(m), ROOT, 0.3)
        check(timed_out is True, "3a: the marker run did time out (control for 3b)")
        check(gone_within(m, 3.0), "3b: NO survivor after the timeout kill")
    finally:
        reap(m)

    # --- 3c: CONTROL -- the old shape leaks, so 3b is not vacuous ----------
    print("\ncase 3c: CONTROL -- the shape this replaced DOES leak")
    mc = unique("14")
    try:
        try:
            subprocess.run(marker_cmd(mc), cwd=ROOT, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=0.3)
        except subprocess.TimeoutExpired:
            pass
        left = survivors(mc)
        check(bool(left),
              "3c: plain subprocess.run(timeout=) leaves %d survivor(s) -- so "
              "3b's pgrep can see an orphan when there is one" % len(left))
    finally:
        reap(mc)

    # --- 4: the SIGNAL path (the actually-observed 09-12 shape) ------------
    print("\ncase 4: SIGTERM to the measure process takes its children down")
    m4 = unique("15")
    proc, ok = start_driver(m4, install=True)
    try:
        check(ok, "4a: driver reached 'ready' with its child running")
        proc.terminate()
        proc.wait(timeout=10)
        check(gone_within(m4, 3.0), "4b: NO survivor after the measure process "
                                    "was SIGTERMed")
    finally:
        try:
            proc.kill()
        except OSError:
            pass
        reap(m4)

    print("\ncase 4c: CONTROL -- without the handler the same SIGTERM leaks")
    m5 = unique("16")
    proc, ok = start_driver(m5, install=False)
    try:
        check(ok, "4c0: control driver reached 'ready' (control for 4c)")
        proc.terminate()
        proc.wait(timeout=10)
        time.sleep(0.4)
        left = survivors(m5)
        check(bool(left),
              "4c: no handler => %d survivor(s), so 4b is a statement about "
              "the handler and not about pgrep" % len(left))
    finally:
        try:
            proc.kill()
        except OSError:
            pass
        reap(m5)

    # --- 5: the call shape the owed row pins -------------------------------
    print("\ncase 5: no caller is left on the un-grouped shape")
    src = open(TOOL).read()
    # AST, not a substring search: the file's own prose EXPLAINS why it is not
    # `subprocess.run(timeout=...)` any more, and a substring check cannot tell
    # an explanation from a caller -- it failed on the docstring first time out.
    check(not _calls_subprocess_run(src),
          "5a: lua_gate_measure.py has no subprocess.run CALL left "
          "(the prose that names it does not count)")
    check("start_new_session=True" in src, "5b: children are started in a new session")
    check("killpg" in src, "5c: the kill goes to the group")

    print("\n%d checks, %d failures" % (checks, len(failures)))
    for f in failures:
        print("  FAILED:", f)
    return 3 if failures else 0


def _calls_subprocess_run(src):
    import ast

    for node in ast.walk(ast.parse(src)):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        if (isinstance(f, ast.Attribute) and f.attr == "run"
                and isinstance(f.value, ast.Name) and f.value.id == "subprocess"):
            return True
    return False


def start_driver(marker, install):
    """A stand-in measure process holding one live child.

    `install` toggles the ONLY difference between case 4 and its control, so the
    control differs from the test in exactly one edit.
    """
    src = (
        "import sys, threading, time\n"
        "sys.path.insert(0, %r)\n"
        "import lua_gate_measure as m\n"
        "%s\n"
        "t = threading.Thread(target=m.run_capture,\n"
        "                     args=([%r, %r, %r], %r, 120), daemon=True)\n"
        "t.start()\n"
        "time.sleep(0.4)\n"
        "print('ready', flush=True)\n"
        "time.sleep(120)\n"
        % (TOOLS,
           "m._install_signal_handlers()" if install else "pass",
           "sh", "-c", "sleep %s & sleep %s" % (marker, marker), ROOT)
    )
    proc = subprocess.Popen([sys.executable, "-c", src], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    deadline = time.time() + 15
    while time.time() < deadline:
        if survivors(marker):
            return proc, True
        if proc.poll() is not None:
            return proc, False
        time.sleep(0.05)
    return proc, False


if __name__ == "__main__":
    sys.exit(main())
