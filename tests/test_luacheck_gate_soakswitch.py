#!/usr/bin/env python3
"""[ratchet] The rule-6 static gate must not be reddened by the arming switch.

WHY THIS EXISTS (director 2026-09-08; same race as GH #229 / GH #243)
---------------------------------------------------------------------
`bots/Customize/soak_side.lua` is the gitignored, farm-only switch that arms a
soak candidate.  Sixteen Lua gate tests and 开工自检 CREATE AND DELETE it while
they run.  `luacheck bots game` walks the tree and then opens what it walked, so
a gate run that overlaps one of them lists the file and cannot read it:

    bots/Customize/soak_side.lua: I/O error (couldn't read: No such file...)
    LUACHECK RED -- iron rule 6 requires 0 warnings on the WORKING TREE.
    GATE_EXIT=3  RED

Measured, not theoretical: that is verbatim what `tools/agent/luacheck_gate.sh`
printed at 13:02Z while `routine_selfcheck.sh` was running in another process,
on a tree with ZERO Lua changes.  The sentence about the working tree is false,
and since GH #213 the same gate sits in `.githooks/pre-push` -- so the race does
not merely mislead a reader, it REFUSES A PUSH over a file that is not in the
diff, is not in the repo, and was never corpus.

`tools/agent/lua_corpus.py` fixed exactly this for the python censuses by
excluding the switch BY NAME ("which removes the race at the source rather than
making it survivable").  This test pins the same repair in the one tool that
never got it, and pins it in BOTH halves -- the flag is in the command, and the
gate really is clean with a syntactically broken switch on disk.

What it does NOT assert: that the gate survives any other file vanishing
mid-walk.  It does not; that is `lua_corpus.py`'s repair (2) and this gate has
not bought it.  A RED naming an I/O error is still a race to re-run.

Run: python3 tests/test_luacheck_gate_soakswitch.py
"""

import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
GATE = os.path.join("tools", "agent", "luacheck_gate.sh")
SWITCH = os.path.join("bots", "Customize", "soak_side.lua")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


# ---- half 1: the flag is in the command that actually runs.
with open(os.path.join(REPO, GATE), encoding="utf-8") as fh:
    gate_src = fh.read()
check("--exclude-files" in gate_src and SWITCH.replace(os.sep, "/") in gate_src,
      "the gate no longer excludes the arming switch by name -- the 2026-09-08 "
      "race is back and it refuses pushes")

# ---- half 2: the behaviour.  A syntactically broken switch on disk must not
# redden the gate.  Source-only pinning would pass on a gate that spells the
# flag right and passes it after `--`.
have_luacheck = shutil.which("luacheck") is not None
if not have_luacheck:
    # UNCERTIFIABLE, not a pass (GH #205's rule): say so and exit 2 rather than
    # print a green line nobody can distinguish from a checked one.
    print("UNCERTIFIABLE -- luacheck is not installed, so the behavioural half "
          "did not run.  Buy it with: apt-get install -y lua-check")
    print("%d checks, %d failed (source half only)" % (checks, len(failures)))
    sys.exit(2 if not failures else 1)

full_switch = os.path.join(REPO, SWITCH)
backup = None
existed = os.path.exists(full_switch)
if existed:
    # Another process (a Lua gate test, 开工自检) may own the file right now.
    # Put back exactly what was there.
    backup = tempfile.mkstemp(prefix="soakswitch_")[1]
    shutil.copyfile(full_switch, backup)
try:
    broken = "return { side = 'radiant', cand = 'x'   -- unclosed table\n"
    with open(full_switch, "w", encoding="utf-8") as fh:
        fh.write(broken)

    # The control comes FIRST: if luacheck does not object to this content on
    # its own, the assertion below is satisfied by a file nothing would flag,
    # and the whole test is vacuous.
    ctrl = subprocess.run(["luacheck", SWITCH, "--formatter", "plain"],
                          cwd=REPO, capture_output=True, text=True)
    check(ctrl.returncode != 0,
          "CONTROL BROKEN: luacheck is happy with the deliberately broken "
          "switch, so 'the gate stayed clean' would prove nothing:\n%s"
          % ctrl.stdout)

    # The gate is run on a NARROW target (`bots/Customize`, the directory the
    # switch lives in) rather than the default `bots game`.  Two reasons, and
    # neither weakens the claim: the exclusion is hardcoded in the script, not
    # passed in by the caller, so it is the same code path; and a full-tree run
    # is ~13s, which in an unmeasured ratchet is a push-gate timeout (GH #616's
    # budget) -- a test that reddens the gate it defends is not a defence.
    run = subprocess.run(["bash", GATE, os.path.join("bots", "Customize")],
                         cwd=REPO, capture_output=True, text=True)
    check(run.returncode == 0,
          "the gate went RED on a broken ARMING SWITCH (exit %d) -- that file "
          "is not corpus and must not be able to refuse a push:\n%s"
          % (run.returncode, run.stdout[-800:]))
    check("GATE_EXIT=0" in run.stdout,
          "the gate's own verdict line did not read clean:\n%s" % run.stdout[-400:])
finally:
    if backup is not None:
        shutil.copyfile(backup, full_switch)
        os.unlink(backup)
    elif os.path.exists(full_switch):
        os.unlink(full_switch)

print("%d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
