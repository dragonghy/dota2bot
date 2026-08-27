#!/usr/bin/env python3
"""GH #243 -- a census answer must not depend on whether a gate test is mid-flight.

WHAT WAS BROKEN.  Six censuses open-coded `os.walk(bots/)` then `open()` on each
listed path.  Sixteen Lua gate tests (GH #229) create and delete
`bots/Customize/soak_side.lua` between those two moments, so a census that
listed the file and reached it after the deletion died with FileNotFoundError
and was reported as `FAIL <file>`, which 开工自检 escalates to `TRUNK RED`.

MEASURED, not theorised: under that churn `tests/test_ability_value_key_census.py`
failed 3 runs in 8 and `tests/test_guard_implication_census.py` 1 in 10, while
both were green on every quiet re-run of the same tree -- the exact 39/2 vs
41/0 split GH #243 reported.

WHAT IS ASSERTED HERE, and why in this order:

  1. THE EXCLUSION, deterministically.  The corpus listing is byte-identical
     with the gate switch present and absent.  This is the repair that removes
     the race rather than surviving it, and it is testable without any timing.
  2. EVERY CENSUS USES IT.  Asserted against each tool's OWN listing function,
     not by re-deriving the list here -- a test that walks its own path can stay
     green while the scan's path rots (the sentence
     test_guard_implication_census.py already earned).
     It also greps for a re-introduced open-coded walk, because the defect was
     never one call site; it was six copies of two lines.
  3. VANISH IS DID-NOT-RUN, NOT A DIFFERENT ANSWER.  `read_lua` on a deleted
     path raises `CorpusVanished` (not FileNotFoundError, and NOT an OSError
     subclass -- a call site that catches OSError to skip unreadable inputs
     must not be able to swallow this into a shorter count).
  4. THE EXIT CODE SURVIVES THE WHOLE CHAIN.  test -> run_py_tests.sh ->
     selfcheck: 2 stays 2 and never prints TRUNK RED.  0 clean / 2 did-not-run /
     3 findings, the same vocabulary as GH #171 and GH #213.
  5. THE RACE ITSELF, under real churn.  Last because it is the only timing
     assertion in the file: the two censuses that were measured failing are run
     while the gate switch is created and deleted in a loop, and must not fail.
     A quiet-tree-only regression test would have passed BEFORE this change.

Run: python3 tests/test_lua_corpus_stability.py   (or tests/run_py_tests.sh)
"""

import os
import re
import subprocess
import sys
import tempfile
import textwrap
import threading

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

import lua_corpus as L  # noqa: E402

SWITCH = os.path.join(REPO, "bots", "Customize", "soak_side.lua")
SWITCH_REL = "bots/Customize/soak_side.lua"
SWITCH_BODY = "return { side = 'radiant', cand = 'x', seed = 1 }\n"

FAIL = []


def ok(name, cond, detail=""):
    if cond:
        print("  ok    %s" % name)
    else:
        FAIL.append(name)
        print("  FAIL  %s%s" % (name, ("  -- " + detail) if detail else ""))


def eq(name, got, want):
    ok(name, got == want, "got %r want %r" % (got, want))


class switch_present(object):
    """Write the gate switch the way a Lua gate test does; always clean up."""

    def __enter__(self):
        with open(SWITCH, "w", encoding="utf-8") as fh:
            fh.write(SWITCH_BODY)
        return self

    def __exit__(self, *exc):
        if os.path.exists(SWITCH):
            os.unlink(SWITCH)
        return False


ok("the gate switch is absent to begin with (this file must not inherit one)",
   not os.path.exists(SWITCH))

# ----------------------------------------------------------------------------
# 1. the exclusion
# ----------------------------------------------------------------------------
quiet = L.bots_lua_relpaths(REPO)
with switch_present():
    armed = L.bots_lua_relpaths(REPO)
    ok("the gate switch really was on disk during that listing",
       os.path.exists(SWITCH))

ok("the corpus listing is non-empty (a broken walk would make the rest vacuous)",
   len(quiet) > 100, "got %d files" % len(quiet))
eq("the corpus listing is identical with the gate switch present and absent",
   armed, quiet)
ok("the gate switch is not in the corpus either way",
   SWITCH_REL not in quiet and SWITCH_REL not in armed)
ok("the exclusion row carries its reason (a bare path invites a second row)",
   "GH #243" in L.EXCLUDED_RELPATHS.get(SWITCH_REL, ""))
eq("nothing else is excluded -- an easy-to-extend exclusion list is how a "
   "census quietly stops covering shipped code",
   sorted(L.EXCLUDED_RELPATHS), [SWITCH_REL])
ok("shipped code under the same directory is still corpus",
   "bots/Customize/general.lua" in quiet)
eq("the listing is sorted (two censuses must not disagree about order)",
   quiet, sorted(quiet))

# ----------------------------------------------------------------------------
# 2. every census uses it
# ----------------------------------------------------------------------------
import ability_value_key_census as AV        # noqa: E402
import talent_name_binding_census as TN      # noqa: E402
import write_only_local_census as WO         # noqa: E402
import guard_implication_census as GI        # noqa: E402


def rel(paths):
    return sorted(os.path.relpath(p, REPO).replace(os.sep, "/") for p in paths)


with switch_present():
    eq("ability_value_key_census.hero_files() excludes it",
       rel(AV.hero_files()), quiet)
    eq("talent_name_binding_census.hero_files() excludes it",
       rel(TN.hero_files()), quiet)
    eq("write_only_local_census.all_bot_files() excludes it",
       sorted(r for _p, r in WO.all_bot_files()), quiet)
    ok("guard_implication_census --all excludes it",
       SWITCH_REL not in subprocess.run(
           [sys.executable, os.path.join(REPO, "tools", "agent",
                                         "guard_implication_census.py"),
            "--all", "--json"],
           capture_output=True, text=True, cwd=REPO).stdout)

# The defect was six copies of two lines, so pin that no seventh grows back.
# Scoped to walks of bots/ -- walks of tools/ or tests/ are a different corpus.
WALKERS = []
for base, _dirs, names in os.walk(os.path.join(REPO, "tools", "agent")):
    for n in sorted(names):
        if n.endswith(".py"):
            WALKERS.append(os.path.join(base, n))
for n in sorted(os.listdir(os.path.join(REPO, "tests"))):
    if n.endswith(".py"):
        WALKERS.append(os.path.join(REPO, "tests", n))

WALK_BOTS = re.compile(r"os\.walk\(\s*os\.path\.join\([^)]*[\"']bots[\"']")
open_coded = []
for path in WALKERS:
    if os.path.basename(path) in ("lua_corpus.py", "test_lua_corpus_stability.py"):
        continue
    with open(path, encoding="utf-8", errors="replace") as fh:
        if WALK_BOTS.search(fh.read()):
            open_coded.append(os.path.relpath(path, REPO))
eq("no tool or test open-codes a walk of bots/ any more (use lua_corpus)",
   open_coded, [])

# ----------------------------------------------------------------------------
# 3. vanish is did-not-run, not a different answer
# ----------------------------------------------------------------------------
gone = os.path.join(tempfile.gettempdir(), "no_such_corpus_file_gh243.lua")
if os.path.exists(gone):
    os.unlink(gone)
try:
    L.read_lua(gone)
    ok("read_lua raises on a vanished file", False, "it returned")
except L.CorpusVanished as exc:
    ok("read_lua raises CorpusVanished on a vanished file", True)
    ok("the exception names the path", gone in str(exc))
except Exception as exc:                                    # noqa: BLE001
    ok("read_lua raises CorpusVanished on a vanished file", False, repr(exc))

ok("CorpusVanished is NOT an OSError -- `except OSError: continue` must not be "
   "able to turn did-not-run into counted-fewer",
   not issubclass(L.CorpusVanished, OSError))

# A permission/encoding error is a real environment defect and must NOT be
# laundered into the same bucket.  (Skipped when running as root, where the
# mode bits do not deny anything -- and skipping is SAID, not silent.)
with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as fh:
    fh.write("-- x\n")
    unreadable = fh.name
os.chmod(unreadable, 0o000)
try:
    L.read_lua(unreadable)
    ok("a permission error is not reported as a vanish "
       "(NOT CHECKED: running as root, the mode bits deny nothing)", True)
except L.CorpusVanished:
    ok("a permission error is not reported as a vanish", False,
       "PermissionError was laundered into CorpusVanished")
except PermissionError:
    ok("a permission error is not reported as a vanish", True)
finally:
    os.chmod(unreadable, 0o600)
    os.unlink(unreadable)

# ----------------------------------------------------------------------------
# 4. exit 2 survives the chain: test -> run_py_tests.sh -> selfcheck
# ----------------------------------------------------------------------------
eq("lua_corpus spells did-not-run as 2, the same code as rule 10 and the push gate",
   L.UNCERTIFIABLE_EXIT, 2)

probe_src = textwrap.dedent("""
    import os, sys
    sys.path.insert(0, %r)
    from lua_corpus import CorpusVanished, uncertifiable
    uncertifiable(CorpusVanished('/gone/x.lua'), 'the probe')
""" % os.path.join(REPO, "tools", "agent"))

probe = subprocess.run([sys.executable, "-c", probe_src],
                       capture_output=True, text=True, cwd=REPO)
eq("uncertifiable() exits 2", probe.returncode, 2)
ok("its banner says did NOT run", "did NOT run" in probe.stderr)
ok("its banner denies being a failure, in as many words",
   "NOT a test failure" in probe.stderr)

# Drive the real runner over a throwaway tests dir: one green, one exit-2.
with tempfile.TemporaryDirectory() as tmp:
    shim = os.path.join(tmp, "tests")
    os.makedirs(shim)
    with open(os.path.join(shim, "test_green_probe.py"), "w") as fh:
        fh.write("print('ok')\n")
    with open(os.path.join(shim, "test_unrun_probe.py"), "w") as fh:
        fh.write(probe_src)
    with open(os.path.join(REPO, "tests", "run_py_tests.sh"), encoding="utf-8") as fh:
        runner_src = fh.read()
    with open(os.path.join(shim, "run_py_tests.sh"), "w", encoding="utf-8") as fh:
        fh.write(runner_src)
    run = subprocess.run(["bash", "tests/run_py_tests.sh"],
                         capture_output=True, text=True, cwd=tmp)
    eq("run_py_tests.sh exits 2 when a test could not run (not 1)",
       run.returncode, 2)
    ok("it prints UNCERTIFIABLE, not FAIL, for that file",
       "UNCERTIFIABLE  tests/test_unrun_probe.py" in run.stdout
       and "FAIL  tests/test_unrun_probe.py" not in run.stdout,
       run.stdout)
    ok("and it still counts the green one as passed",
       "1 passed, 0 failed, 1 uncertifiable" in run.stdout, run.stdout)

    # A real failure must still be exit 1 -- the point is to tell them apart,
    # not to soften the failure path.
    with open(os.path.join(shim, "test_red_probe.py"), "w") as fh:
        fh.write("import sys; sys.exit(1)\n")
    run2 = subprocess.run(["bash", "tests/run_py_tests.sh"],
                          capture_output=True, text=True, cwd=tmp)
    eq("a genuine failure still exits 1 even alongside an uncertifiable one",
       run2.returncode, 1)

with open(os.path.join(REPO, "tools", "agent", "routine_selfcheck.sh"),
          encoding="utf-8") as fh:
    selfcheck = fh.read()
py_leg = selfcheck[selfcheck.index("=== trunk health (python test suite) ==="):]
py_leg = py_leg[:py_leg.index("[director 20260826, GH #171]")]
ok("the selfcheck python leg branches on the runner's exit code",
   "suite_rc" in py_leg, py_leg)
ok("exit 2 there prints UNCERTIFIABLE and notes 2",
   'suite_rc" -eq 2' in py_leg and "note 2" in py_leg, py_leg)
ok("exit 2 there does NOT print TRUNK RED",
   py_leg.index("note 2") < py_leg.index("TRUNK RED -- a python test"), py_leg)
ok("a real failure there still says TRUNK RED and notes 3",
   "TRUNK RED -- a python test" in py_leg and "note 3" in py_leg, py_leg)

# ----------------------------------------------------------------------------
# 5. the race itself, under real churn
# ----------------------------------------------------------------------------
# The two files GH #243 measured failing, run while the gate switch is created
# and deleted the way tests/run_tests.lua creates and deletes it.  Before the
# exclusion this reproduced at ~3/8 and ~1/10; the loop below gives each of them
# more attempts than that.
MEASURED = ["tests/test_ability_value_key_census.py",
            "tests/test_guard_implication_census.py"]
ROUNDS = 6

stop = threading.Event()


def churn():
    while not stop.is_set():
        try:
            with open(SWITCH, "w", encoding="utf-8") as fh:
                fh.write(SWITCH_BODY)
            os.unlink(SWITCH)
        except OSError:
            pass


churner = threading.Thread(target=churn, daemon=True)
churner.start()
try:
    bad = []
    for _ in range(ROUNDS):
        for t in MEASURED:
            r = subprocess.run([sys.executable, t], capture_output=True,
                               text=True, cwd=REPO)
            if r.returncode != 0:
                bad.append("%s rc=%d %s" % (t, r.returncode,
                                            r.stdout[-300:] + r.stderr[-300:]))
finally:
    stop.set()
    churner.join(timeout=5)
    if os.path.exists(SWITCH):
        os.unlink(SWITCH)

eq("the two measured censuses stay green under gate-switch churn "
   "(%d runs each)" % ROUNDS, bad, [])
ok("the churn left no gate switch behind", not os.path.exists(SWITCH))

print()
if FAIL:
    print("%d FAILED: %s" % (len(FAIL), ", ".join(FAIL)))
    sys.exit(1)
print("lua corpus stability: exclusion holds, vanish reads as did-not-run, "
      "exit 2 survives the chain")
