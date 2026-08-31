#!/usr/bin/env python3
"""Acceptance for the pipe refusal in tools/agent/routine_selfcheck.sh.

WHAT THIS PINS.  Evidence discipline 3 -- "never measure an exit code through a
pipe" -- recurred five times, always as the FIRST command of a director round:

    bash tools/agent/routine_selfcheck.sh 2>&1 | tail -60   -> harness said 0

and that 0 is `tail`'s.  Charter backlog 22 retired "write another reminder" as
a fix (three rounds wrote one; three rounds broke it) and asked for the shape to
be made mechanically impossible instead.  The guard refuses to run when stdout
is a pipe.

THE LOAD-BEARING PROPERTY IS NOT "IT EXITS 2".  A caller who pipes CANNOT read
the exit code -- that is the whole defect -- so an exit code alone would be a
fix the victim cannot see.  What actually reaches them is the TEXT, and only
because the refusal happens before any leg runs, making the output short enough
to survive a small `tail` window.  Case 3 is therefore the real payload: it
asserts the message arrives through `| tail -1`.

WHY THE DISCRIMINANT IS "FIFO" AND NOT "NOT A TTY".  Backlog 22 raised the risk
that a legitimate redirect would be caught.  Cases 2 and 4 are that risk, pinned:
a redirect to a file and a plain captured run must both still work.  A `[ -t 1 ]`
guard would have failed both, which is why the tty test is not the one used.

Exit 0 clean / 1 failures.  Run: bash tools/agent/rc.sh python3 tests/test_selfcheck_pipe_guard.py
"""
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "tools", "agent", "routine_selfcheck.sh")

failures = []
checks = 0


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        failures.append(msg)


# A WORKING guard refuses in milliseconds -- it is the first thing the script
# does.  So a generous budget only ever gets spent when the guard is BROKEN, and
# then it is spent running the whole ~8min self-check, three times over, in a
# test whose answer was already decided at the first millisecond.  The mutation
# stand sets PG_TIMEOUT low for exactly that reason; a timeout is reported as a
# FAILURE, not as an error, because "did not refuse within the budget" is a true
# and sufficient reading of a guard that no longer guards.
BUDGET_S = float(os.environ.get("PG_TIMEOUT", "900"))
TIMED_OUT = "__TIMEOUT__"


def sh(cmd, env=None):
    """Run `cmd` under bash. Returns (stdout+stderr, returncode)."""
    e = dict(os.environ)
    if env:
        e.update(env)
    try:
        p = subprocess.run(["bash", "-c", cmd], cwd=REPO, capture_output=True,
                           text=True, timeout=BUDGET_S, env=e)
    except subprocess.TimeoutExpired:
        return TIMED_OUT, -1
    return p.stdout + p.stderr, p.returncode


# The guard must fire before anything expensive, so every piped case below is
# fast.  A generous timeout only matters if the guard is BROKEN (then the real
# self-check runs, ~8min) -- which is itself the failure we want reported as a
# failure rather than as a hang.
PIPED = 'bash tools/agent/routine_selfcheck.sh 2>&1 | cat'

# --- 1. the defect shape is refused ----------------------------------------
out, rc = sh(PIPED)
check("REFUSED" in out,
      "1a: piping to `cat` must be REFUSED, got: %r" % out[:400])
check("SELFCHECK_EXIT=2" in out,
      "1b: the refusal must name could-not-run code 2 in-band")
check("rc.sh" in out,
      "1c: the refusal must point at the shorter correct path (rc.sh)")
check("SELFCHECK_PIPE_OK" in out,
      "1d: the refusal must name its own escape hatch")
# The refusal must not have run the checks.  A leg banner in the output would
# mean it refused AFTER working, which defeats the tail-window property.
check("anchors" not in out.lower() and "cadence" not in out.lower(),
      "1e: refusal must precede every leg (no leg output), got: %r" % out[:400])
# 1f: the REAL exit code, not just the in-band claim about it.  `> >(cat)` makes
# stdout a FIFO -- so the guard still fires -- while leaving `$?` the script's
# own, which a plain `| cat` destroys.  Without this, a mutant that prints
# "SELFCHECK_EXIT=2" and then exits 0 would pass every other check here: the
# text and the code would be free to disagree, which is the exact family of
# defect (a did-not-run wearing a pass) this guard was built against.
out1f, _ = sh('bash tools/agent/routine_selfcheck.sh > >(cat) 2>&1; '
              'echo "REALEXIT=$?"')
check("REALEXIT=2" in out1f,
      "1f: the refusal's ACTUAL exit code must be 2, not merely a line of text "
      "claiming 2; got: %r" % out1f[-300:])

# --- 2. a redirect to a FILE is NOT refused --------------------------------
# This is the false positive backlog 22 explicitly warned about: the background
# self-check of this very round is `cmd > file`.  A `[ -t 1 ]` guard fails here.
out2, _ = sh('bash -c \'[ -p /dev/stdout ] && echo FIFO || echo NOTFIFO\' '
             '> /tmp/pg_redir.out 2>&1; cat /tmp/pg_redir.out')
check("NOTFIFO" in out2,
      "2a: a redirect to a file must not look like a FIFO, got: %r" % out2[:200])

# --- 3. THE PAYLOAD: the refusal survives `| tail -1` ----------------------
# The victim of this defect reads a TAIL, not an exit code.  If the last line
# does not carry the verdict, the fix is invisible to exactly the person it is
# for.  `tail -1` is the harshest window that exists.
out3, rc3 = sh('bash tools/agent/routine_selfcheck.sh 2>&1 | tail -1')
check("SELFCHECK_EXIT=2" in out3,
      "3a: the verdict must be the LAST line, so `| tail -1` still shows it; "
      "got: %r" % out3[:300])
check(rc3 == 0,
      "3b: sanity -- the pipeline itself still reports tail's 0, which is the "
      "whole reason the verdict has to be in the text (got %d)" % rc3)

# --- 4. the escape hatch works ---------------------------------------------
# Callers that genuinely read the true code (subprocess capture, `$(...)`) are
# FIFOs too and cannot be told apart from inside.  They opt out.  Asserting only
# that the guard does not fire keeps this cheap: we do not re-run the ~8min
# self-check, we check that it got PAST the refusal.
#
# `--bogus-arg` is load-bearing, and it is only sound because the guard runs
# BEFORE argument parsing.  In the first draft the guard sat after the parser,
# so this case exited at "unknown argument" without ever reaching the guard --
# both checks passed for a reason that had nothing to do with the hatch.  Mutant
# M5 (hatch condition deleted) SURVIVED, and that survival is the only thing
# that said so: a green check measuring nothing looks exactly like a green check
# measuring something.  If the guard is ever moved back below the parser, M5
# starts surviving again -- that is the alarm, so leave the stand wired up.
out4, _ = sh('bash tools/agent/routine_selfcheck.sh --bogus-arg 2>&1 | cat',
             env={"SELFCHECK_PIPE_OK": "1"})
check("REFUSED: stdout is a PIPE" not in out4,
      "4a: SELFCHECK_PIPE_OK=1 must suppress the pipe refusal, got: %r"
      % out4[:300])
check("unknown argument" in out4,
      "4b: with the hatch set, control must reach normal argument handling; "
      "got: %r" % out4[:300])

# --- 5. the guard is not accidentally disabled in-tree ---------------------
with open(SCRIPT) as fh:
    src = fh.read()


def code_only(text):
    """Drop whole-line comments.

    The first draft of 5b read the raw source and failed on the guard's own
    PROSE -- the comment block explains why `[ -t 1 ]` is the wrong test, so
    naming it there tripped a check meant for code.  A source check that cannot
    tell code from the commentary about it is checking the commentary.
    """
    return "\n".join(ln for ln in text.splitlines()
                     if not ln.lstrip().startswith("#"))


guard = code_only(src)
check("-p /dev/stdout" in guard,
      "5a: the guard must test for a FIFO specifically")
check("[ -t 1 ]" not in guard,
      "5b: the guard must NOT use the tty test in CODE -- it would reject the "
      "legitimate redirect and captured-run shapes (cases 2 and 4)")
# 5c pins the ordering that case 3a measured, at the source level: within the
# GUARD BLOCK, the stderr aside must not come after the verdict line.
#
# Scoping this to the block is not tidiness.  The first version split the whole
# file on the verdict string, which was accidentally correct only while the
# guard sat at the bottom; moving the guard to the top (so case 4 stops being
# vacuous) put the argument parser's own `>&2` after the split point and turned
# CONTROL red.  A check whose correctness depends on where the code happens to
# sit is measuring layout, not behaviour.
#
# Delimiting the block needs a LINE-anchored `exit 2`, not the substring.  The
# aside's own text contains the words "exit 2, nothing checked", so a substring
# search cut the block off inside a printf argument and reported 0 stderr writes
# where there is 1 -- a check that was red on correct code, for a reason that
# looked like a real finding.  Both delimiters are matched as whole statements.
_m = re.search(r'^if \[ -z "\$\{SELFCHECK_PIPE_OK:-\}".*?^\s*exit 2\s*$',
               guard, re.S | re.M)
check(_m is not None,
      "5c0: the guard block must be locatable as `if [ -z \"${SELFCHECK_PIPE_OK"
      ":-}\" ] ... exit 2` (absent or unrecognisable = nothing below is measured)")
block = _m.group(0) if _m else ""
check(block.count(">&2") == 1,
      "5c1: the guard block must write to stderr exactly once (got %d)"
      % block.count(">&2"))
check(">&2" not in block.split("SELFCHECK_EXIT=2")[-1],
      "5c: nothing may be written to stderr AFTER the verdict line, or it "
      "becomes the last line under `2>&1 | tail -1` (this is exactly what 3a "
      "caught on the first draft)")
# 5d: the guard must precede argument parsing.  This is what makes case 4 a real
# test of the hatch rather than a test of the argument parser (see the note
# there); mutant M5 is the alarm, and this check names the cause directly.
check(_m is not None and guard.index("extra=()") > _m.start(),
      "5d: the guard must run BEFORE argument parsing, or a caller with a bad "
      "argument exits at the parser and never reaches it (case 4 goes vacuous)")

print("%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  FAIL " + f)
sys.exit(1 if failures else 0)
