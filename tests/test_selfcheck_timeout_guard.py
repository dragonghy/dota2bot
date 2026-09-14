#!/usr/bin/env python3
"""Acceptance for the `timeout` refusal in tools/agent/routine_selfcheck.sh.

WHAT THIS PINS.  A self-check started as

    timeout 600 bash tools/agent/routine_selfcheck.sh > /tmp/sc.log 2>&1

is not a bounded self-check; it is an UNREAD one.  Measured 2026-09-14T06:57Z:
real code `EXIT=124` (`timeout`'s kill code, outside the script's own 0/2/3
vocabulary), 537 lines of log, the last line a just-opened banner
`=== trunk health (fast Lua detectors) ===`, no `legs run` line and no
`worst exit` line -- the whole fast-Lua detector leg never ran.

WHY A GUARD AND NOT A REMINDER.  Three consecutive director rounds typed the
flag, each having registered the previous one: 04:15Z recorded it, 06:57Z
recorded it again with the 124 reading and wrote "next round: redirect +
background + NO timeout", 10:05Z claimed all three were done, 13:0xZ typed it
again.  That is exactly the pipe guard's history (three charter reminders,
three breaks), and the pipe guard's comment already said why a note cannot
reach this slot: the command is typed BEFORE the charter is read.

THE FAILURE IS NOT RANDOM SAMPLING.  The legs run in a fixed order, so a clock
cut always truncates the SAME tail.  The same legs go unread every time, while
the exit code says 124 and the log's final line looks like a leg that ran.

CASE 2 AND 3 ARE THE FALSE-POSITIVE RISK, PINNED.  A guard that also refused a
bare run, or ignored its own opt-out, would cost every round its self-check --
strictly worse than the defect.  Both are asserted here.  Note how they are
asserted: a WORKING guard refuses in milliseconds, so for the must-not-refuse
cases a short budget that EXPIRES is itself proof of non-refusal.  That is why
a timeout is a pass there and a failure in case 1.

⚠️ This file's own subprocess budgets use Python's `subprocess.run(timeout=)`,
which does NOT spawn a `timeout(1)` process -- so this test does not trip the
very guard it is testing.  Switching these to shell `timeout` would make every
case refuse and the file would assert nothing.

Exit 0 clean / 1 failures.
Run: bash tools/agent/rc.sh python3 tests/test_selfcheck_timeout_guard.py
"""
import os
import signal
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "tools", "agent", "routine_selfcheck.sh")

# A refusal happens before any leg runs, so it lands in well under a second.
# Anything slower than this is the guard NOT firing.
REFUSAL_BUDGET_S = float(os.environ.get("TG_REFUSAL_BUDGET", "60"))
# For the must-not-refuse cases we only need long enough to prove the script
# got past the guard and into its first leg -- a refusal is instant, so any
# budget the script OUTLIVES is already the whole proof.  Kept deliberately
# small: at 25s this file measured 16.91s and was the single most expensive
# unmeasured test in the py-gate drift report; the extra 20s bought nothing
# that the first second had not already settled.
PROCEED_BUDGET_S = float(os.environ.get("TG_PROCEED_BUDGET", "6"))

TIMED_OUT = "__TIMEOUT__"

failures = []
checks = 0


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        failures.append(msg)


def sh_split(cmd, budget, env=None):
    """Like sh(), but keeps the two streams apart: (stdout, stderr, rc).

    Case 1e needs this.  The guard writes its stderr copy FIRST and its stdout
    copy second, on purpose, so that under `2>&1 | tail -1` the VERDICT is the
    final line.  Concatenating as stdout+stderr (what sh() returns) reverses
    that order artificially and would fail a guard that is in fact correct --
    measured: 1e failed exactly this way before the split.  The ordering
    property belongs to stdout, which the guard's own comment calls "the
    channel inside the pipe".
    """
    out, rc = _run(cmd, budget, env, split=True)
    return out[0], out[1], rc


def sh(cmd, budget, env=None):
    """Run `cmd` under bash. Returns (stdout+stderr, returncode).

    A budget expiry returns (TIMED_OUT, -1) rather than raising: for the
    must-not-refuse cases that outcome is the evidence, not an error.
    """
    return _run(cmd, budget, env, split=False)


def _run(cmd, budget, env, split):
    e = dict(os.environ)
    # Inherited from the caller's shell, this would silently disarm case 1.
    e.pop("SELFCHECK_TIMEOUT_OK", None)
    # `capture_output=True` makes /dev/stdout a FIFO, which is the PIPE guard's
    # documented false positive (that guard names
    # `subprocess.run(capture_output=True)` explicitly and offers this opt-out
    # for it).  Without this line every case below is answered by the PIPE
    # guard instead: measured, cases 1a/1b/1c still PASSED -- both guards print
    # REFUSED and exit 2 -- and only 1d, the check that asks the refusal to
    # NAME its cause, told them apart.  A test that agrees with itself for the
    # wrong reason is not a passing test.
    e.setdefault("SELFCHECK_PIPE_OK", "1")
    if env:
        e.update(env)
    # `start_new_session=True` + killpg, because the must-not-refuse cases are
    # SUPPOSED to hit their budget: the self-check is then mid-leg, and killing
    # only the direct `bash -c` child orphans the script and every leg it has
    # spawned.  Measured before this was added: 11 stray routine_selfcheck
    # processes and a load average of 4.88 on a container with nothing else to
    # do -- which then slows the very runs being measured.
    popen = subprocess.Popen(["bash", "-c", cmd], cwd=REPO,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, env=e, start_new_session=True)
    try:
        sout, serr = popen.communicate(timeout=budget)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(popen.pid), signal.SIGKILL)
        except OSError:
            popen.kill()
        sout, serr = popen.communicate()
        sout = TIMED_OUT + (sout or "")
        if split:
            return (sout, serr or ""), -1
        return sout + (serr or ""), -1
    if split:
        return (sout, serr), popen.returncode
    return sout + serr, popen.returncode


def main():
    # --- case 1: the defect shape itself -----------------------------------
    out, rc = sh("timeout 600 bash %s" % SCRIPT, REFUSAL_BUDGET_S)
    check(not out.startswith(TIMED_OUT),
          "1a running under `timeout` must REFUSE, and a refusal is instant; "
          "this one did not answer within %ss" % REFUSAL_BUDGET_S)
    check(rc == 2,
          "1b a refusal exits 2 (could-not-run vocabulary, never 0 and never "
          "124); got %r" % rc)
    check("REFUSED" in out,
          "1c the refusal must SAY so -- the exit code alone is a fix the "
          "victim may not read; got %r" % out[:200])
    check("timeout" in out,
          "1d the refusal must name `timeout` as the cause, or the reader "
          "cannot act on it")

    # The verdict must be the LAST line, so it survives a small `tail` window.
    # Same load-bearing property as the pipe guard's case 3.
    sout, serr, _ = sh_split("timeout 600 bash %s" % SCRIPT, REFUSAL_BUDGET_S)
    lines = [ln for ln in sout.strip().splitlines() if ln.strip()]
    check(lines and lines[-1].startswith("SELFCHECK_EXIT=2"),
          "1e the LAST line of STDOUT must be the SELFCHECK_EXIT=2 verdict (it "
          "is what survives `| tail -1`); got %r" % (lines[-1] if lines else None))
    check("REFUSED" in serr,
          "1f a copy must also reach STDERR, for the `| tail` written WITHOUT "
          "`2>&1` where stderr bypasses the pipe; got %r" % serr[:200])

    # --- case 2: a bare run must still work --------------------------------
    # The false-positive that would be worse than the defect.
    out, rc = sh("bash %s" % SCRIPT, PROCEED_BUDGET_S)
    check("REFUSED" not in out,
          "2a a BARE run must NOT be refused -- a guard that fires here costs "
          "every round its self-check; got %r" % out[:300])

    # --- case 3: the opt-out must be honoured ------------------------------
    out, rc = sh("timeout 600 bash %s" % SCRIPT, PROCEED_BUDGET_S,
                 env={"SELFCHECK_TIMEOUT_OK": "1"})
    check("REFUSED" not in out,
          "3a SELFCHECK_TIMEOUT_OK=1 must suppress the refusal (a guard with "
          "no escape hatch is one a caller cannot argue with); got %r"
          % out[:300])

    # --- case 4: the ancestor walk, not just the parent --------------------
    # A bash between `timeout` and the script is what the harness produces when
    # it runs a COMPOUND command, and a parent-only guard would miss it.
    #
    # ⚠️ THE `; true` IS LOAD-BEARING, and a surviving mutant is what proved it.
    # This case was first written as `timeout 600 bash -c 'bash <script>'`, and
    # mutation M3 -- the walk cut from 3 levels to 1 -- SURVIVED it, 9 checks 0
    # failed.  Reason, measured directly: bash EXECS a `-c` body that is a
    # single simple command, so no bash remains in between and `timeout` ends
    # up the DIRECT parent.  The case was asserting the walk while exercising
    # only the parent check.  Measured both ways at 2026-09-14T13:1xZ:
    #
    #     timeout N bash -c '<one command>'        -> parent comm = `timeout`
    #     timeout N bash -c '<one command>; true'  -> parent comm = `bash`
    #
    # Making the body compound suppresses the exec optimisation and produces
    # the real two-level shape.  `|| exit $?` rather than `; true`, for a
    # second reason found the same way: `; true` is compound (so the walk IS
    # exercised) but it also REPLACES the script's exit code with `true`'s, and
    # this case then read rc=0 while the refusal text was plainly present.  The
    # `||` form is equally compound and propagates the 2.
    out, rc = sh("timeout 600 bash -c 'bash %s || exit $?'" % SCRIPT,
                 REFUSAL_BUDGET_S)
    check(not out.startswith(TIMED_OUT) and rc == 2 and "REFUSED" in out,
          "4a `timeout N bash -c '<script>'` must also refuse -- the guard "
          "walks ancestors, not just the immediate parent; got rc=%r %r"
          % (rc, out[:200]))

    print("%d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("FAIL: %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
