#!/usr/bin/env python3
"""tests/run_tests.lua -- a failure must be legible WHILE the run is still going.

WHY (GH #216, hero 2026-08-26T13:57Z found it, director 15:5xZ): trunk's full
Lua suite had 2 reds, and the issue reporting them could not name either one.
Not for want of trying -- two independent full runs were launched and both were
still going when the finder had to hand off, because the runner printed
`failures[]` only after the loop.  The whole suite is ~100min (GH #124) and is
dominated by a handful of slow files, so "which case is red" cost the full
100min no matter where in the run the red was.  The diagnosis cost of a failure
was pinned to the SLOWEST FILE IN THE SUITE rather than to the failure.

Two properties are asserted here, and the second is the one that is easy to
write and easy to get wrong:

  1. ORDERING -- the failure's name and text are emitted at the moment it
     happens, before later tests run.  A `FAIL[n]:` line that comes out after
     everything else is the defect this fixes, wearing the new format.

  2. FLUSHING -- and it is visible before the process exits.  stdout to a pipe
     or a file is block-buffered; a ~100min run is ALWAYS redirected somewhere.
     Ordering alone cannot catch a missing flush: at exit everything is flushed
     anyway, so the captured bytes come out in the same order either way and an
     unflushed "immediate" print passes an ordering test while delivering
     nothing to the person watching `tail -f`.  Case B therefore reads the pipe
     WHILE a later test is still sleeping.  That is the only tier that can tell
     the two apart, so it is worth the ~6s it costs.

The fixture is synthetic on purpose: a temp dir holding a copy of the runner and
four tiny test files.  The runner takes its test directory from `arg[0]`, so a
copy in a temp dir enumerates that dir -- no dependency on the repo's real
suite, and nothing here can be perturbed by (or perturb) it.

BUYS lua5.1 rather than declaring it absent -- GH #171's ruling, applied here.
"""

import os
import select
import shutil
import subprocess
import sys
import tempfile
import time

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
# Deliberately thin.  Everything about WHEN the print happens is behavioural and
# lives in tier 2; asserting the shape of the emitting code here would only
# pin down one spelling of it.  What this tier holds is the property tier 2
# cannot see by construction: the end-of-run block must SURVIVE.  A run whose
# failures scrolled past 90 minutes ago still needs them gathered at the bottom,
# and a "we print them immediately now, so the summary is redundant" cleanup
# would look green in every tier-2 case below.
print("tier 1: source ratchet")
with open(RUNNER, encoding="utf-8") as fh:
    src = fh.read()

check("end-of-run failure block still present",
      "for _, f in ipairs(failures) do" in src,
      "immediate printing does not make the gathered list redundant -- it is "
      "the only place a reader who scrolled past the failure can find it")
check("failure path flushes", "io.stdout:flush()" in src,
      "without a flush the immediate print is not immediate under redirection")


# --- tier 2: behaviour ------------------------------------------------------
lua = shutil.which("lua5.1")
if lua is None:
    subprocess.run(["bash", os.path.join(REPO, "tools", "agent",
                                         "ensure_lua_toolchain.sh"), "lua5.1"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    lua = shutil.which("lua5.1")

if lua is None:
    # Not a pass.  GH #171: a leg that could not run must not look like a leg
    # that ran, so tier 1 above carries the file and this says so out loud.
    print("tier 2: UNCERTIFIABLE -- lua5.1 absent and could not be installed; "
          "tier 1 above still ran and still binds")
else:
    print("tier 2: behaviour under %s" % lua)

    FILES = {
        # sorts first -- the failure the later files must not outrun
        "test_a_fail.lua":
            "return { ['boom'] = function() error('SENTINEL_BOOM') end }\n",
        # sorts second -- a syntax error, so the runner never reaches a body
        "test_b_loaderr.lua":
            "this is not lua ((\n",
        # sorts third -- announces itself only when it actually runs
        "test_c_marker.lua":
            "return { ['later'] = function() io.write('SENTINEL_LATER') end }\n",
    }
    SLOW = ("return { ['slow'] = function() os.execute('sleep 6') end }\n")

    def make_tree(files):
        d = tempfile.mkdtemp(prefix="failfast_")
        shutil.copy(RUNNER, os.path.join(d, "run_tests.lua"))
        for name, body in files.items():
            with open(os.path.join(d, name), "w", encoding="utf-8") as fh:
                fh.write(body)
        return d

    # --- case A: ordering ---------------------------------------------------
    tree = make_tree(FILES)
    p = subprocess.run([lua, os.path.join(tree, "run_tests.lua")],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.stdout.decode("utf-8", "replace")
    shutil.rmtree(tree, ignore_errors=True)

    i_fail = out.find("SENTINEL_BOOM")
    i_later = out.find("SENTINEL_LATER")
    check("A1 the failing case's text appears at all", i_fail >= 0, out[-300:])
    check("A2 a later test really ran", i_later >= 0, out[-300:])
    check("A3 the failure is printed BEFORE the later test runs",
          0 <= i_fail < i_later,
          "fail@%d later@%d -- this is the defect: failures gathered at the "
          "end cost the whole run to read" % (i_fail, i_later))
    check("A4 the failure line names file :: test",
          "test_a_fail.lua :: boom" in out, out[-300:])
    check("A5 the load error is announced immediately too",
          0 <= out.find("test_b_loaderr.lua") < i_later, out[-400:])
    check("A6 E and F stay distinct in the progress stream",
          "F\n" in out and "E\n" in out, repr(out[:120]))
    check("A7 the end-of-run block still lists every failure",
          out.count("FAIL: ") == 2, "found %d" % out.count("FAIL: "))
    check("A8 the run exits non-zero", p.returncode != 0,
          "rc=%d" % p.returncode)

    # --- case B: flush (the property ordering cannot see) -------------------
    # One failing file, then a file that sleeps.  If the failure text reaches us
    # while the sleeper is still sleeping, it was flushed.  If it only arrives
    # at exit, it was not -- and `tail -f` on a 100min run would have shown
    # nothing for 100 minutes while claiming to be live.
    tree = make_tree({"test_a_fail.lua": FILES["test_a_fail.lua"],
                      "test_z_slow.lua": SLOW})
    proc = subprocess.Popen([lua, os.path.join(tree, "run_tests.lua")],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            bufsize=0)
    seen, deadline = b"", time.time() + 4.0
    while time.time() < deadline and b"SENTINEL_BOOM" not in seen:
        r, _, _ = select.select([proc.stdout], [], [], deadline - time.time())
        if not r:
            break
        chunk = proc.stdout.read(4096)
        if not chunk:
            break
        seen += chunk
    still_running = proc.poll() is None
    check("B1 failure text arrives before the process exits",
          b"SENTINEL_BOOM" in seen,
          "read %r in 4s while a later test slept" % seen[-200:])
    check("B2 ... and the process really was still running (so B1 is about "
          "flushing, not about a fast exit)", still_running,
          "the sleeper should still have ~2s left")
    proc.kill()
    proc.wait()
    shutil.rmtree(tree, ignore_errors=True)

    # --- case C: control ----------------------------------------------------
    # A green run must stay quiet.  Without this, "print FAIL for every test"
    # would pass every case above.
    tree = make_tree({"test_a_ok.lua":
                      "return { ['fine'] = function() end }\n"})
    p = subprocess.run([lua, os.path.join(tree, "run_tests.lua")],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out = p.stdout.decode("utf-8", "replace")
    shutil.rmtree(tree, ignore_errors=True)
    check("C1 a green run prints no failure line",
          "FAIL" not in out, out[-200:])
    check("C2 a green run exits 0", p.returncode == 0, "rc=%d" % p.returncode)

print("\n%d checks, %d failures" % (ran, len(failures)))
if failures:
    for f in failures:
        print("FAIL: %s" % f)
    sys.exit(1)
