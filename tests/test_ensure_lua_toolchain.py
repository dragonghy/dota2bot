#!/usr/bin/env python3
"""Acceptance for tools/agent/ensure_lua_toolchain.sh + tools/agent/luacheck_gate.sh.

WHY THIS EXISTS.  GH #205.  Iron rule 6's first door is
`luacheck bots game --formatter plain`, and in a Routine container it had never
once been opened: `luacheck` is not preinstalled, every round wrote down "容器无
luacheck,跳过", and the next round read that back as a fact about the
environment.  It was not one -- `apt-get install -y lua-check` is 5.5s and the
gate itself is 13s (measured 2026-08-26, this container, 0 warnings on trunk).

Three layers of the SAME error, all in the direction of "we can't":
  1. lua5.1 absent  -> the selfcheck's Lua leg never ran            (GH #171)
  2. luacheck absent -> rule 6's static half never ran               (GH #205)
  3. and the reason 2 looked settled: the package was looked up as `luacheck`,
     which really is absent from apt, so `Unable to locate package` read as
     "it's a luarocks package".  It is `lua-check`, and
     .github/workflows/ci.yml:15 had the right name the whole time.

Layer 3 is why the package-name map is asserted here against CI: prose about
which name is right is exactly what got read back wrong three times.

The load-bearing claims, in the order they can fail:
  1. the shared buy is BOUNDED, GUARDED, ONLY-WHEN-MISSING, and SILENT on
     failure -- so a container with no apt/sudo/network behaves exactly as it
     did before this file existed
  2. the package-name map says lua-check for luacheck, and agrees with CI
  3. the gate RAISES ITS EXIT CODE on both bad outcomes -- 3 for warnings, 2 for
     could-not-run -- and its could-not-run banner does not read like its pass
     line.  A gate that reports without raising is the shape GH #171 ruled on;
     re-learning it on a new leg is the failure this claim exists to stop
  4. END TO END: no PATH at all => the buy returns 1 silently and the gate exits
     2 with the banner; a tree with a real luacheck warning => exit 3; a clean
     tree => exit 0.

Run:  python3 tests/test_ensure_lua_toolchain.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ENSURE = os.path.join(REPO, "tools", "agent", "ensure_lua_toolchain.sh")
GATE = os.path.join(REPO, "tools", "agent", "luacheck_gate.sh")

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)


def code_only(text):
    """Drop whole-line comments.

    Absence claims must read code, not prose: both files document at length the
    strings they no longer print, and asserting over prose makes their own
    history unwritable (tests/test_selfcheck_lua_leg.py paid for this lesson).
    """
    return "\n".join(ln for ln in text.splitlines()
                     if not ln.lstrip().startswith("#"))


check(os.path.exists(ENSURE), "0a: tools/agent/ensure_lua_toolchain.sh exists")
check(os.path.exists(GATE), "0b: tools/agent/luacheck_gate.sh exists")
ens = open(ENSURE, encoding="utf-8").read() if os.path.exists(ENSURE) else ""
gate = open(GATE, encoding="utf-8").read() if os.path.exists(GATE) else ""
ens_code, gate_code = code_only(ens), code_only(gate)

# ---------------------------------------------------------------------------
# 1. the shared buy is bounded, guarded, only-when-missing, silent on failure
# ---------------------------------------------------------------------------
_fn = re.search(r"\nensure_lua_tool\(\)\s*\{(.*?)\n\}", ens, re.S)
check(_fn is not None, "1a: ensure_lua_tool's body can be isolated")
body = _fn.group(1) if _fn else ""

check("timeout " in body,
      "1b: the install is bounded (an unbounded apt-get in the command every "
      "stream runs at 开工 is a hang, and a hang reads as 'still working')")
check("command -v apt-get" in body,
      "1c: the install is guarded on apt-get actually existing")
check("sudo -n" in body,
      "1d: non-root only proceeds with passwordless sudo -- a password prompt "
      "would block the trigger forever")
check(re.search(r'command -v "\$tool".*return 0', body) is not None,
      "1e: it returns early when the tool is already there (an unconditional "
      "apt-get taxes every trigger to buy what it already has)")
# Silent on failure is the whole reason this is safe to put in front of
# everything: with no apt, no sudo or no network the caller sees exactly what it
# saw before this file existed, and decides for itself what absence means.
#
# The first draft of this check was `printf.*\|\|\s*return 1` -- a shape, and
# the wrong one.  The mutation that adds `|| { printf "no apt"; return 1; }`
# puts the printf on the OTHER side of the ||, so it SURVIVED.  Counting is what
# the claim actually is: exactly one printf in this function, and it is the
# success line.  (Case 4a2 below then re-checks the same claim by running it.)
_printfs = re.findall(r"printf [^\n]*", body)
check(len(_printfs) == 1 and _printfs and _printfs[0].startswith("printf 'installed"),
      "1f: exactly one printf in ensure_lua_tool -- the success line.  Every "
      "failure path is a bare `return 1` (got: %r)" % (_printfs,))

# ---------------------------------------------------------------------------
# 2. the package-name map -- layer 3 of the defect
# ---------------------------------------------------------------------------
check(re.search(r"luacheck\)\s*printf 'lua-check", ens) is not None,
      "2a: luacheck maps to the apt package `lua-check`")
check(re.search(r"lua5\.1\)\s*printf 'lua5\.1", ens) is not None,
      "2b: lua5.1 maps to `lua5.1`")
check("apt-get install -y luacheck" not in ens_code,
      "2c: nothing installs the package name that does not exist")
ci = os.path.join(REPO, ".github", "workflows", "ci.yml")
if os.path.exists(ci):
    ci_src = open(ci, encoding="utf-8").read()
    # CI is the independent witness: it has been installing the right name since
    # before this file existed.  If someone "fixes" one of the two, this fails.
    check("lua-check" in ci_src,
          "2d: CI installs lua-check too -- the map and CI agree")
else:
    print("  SKIP  2d: no .github/workflows/ci.yml")

# ---------------------------------------------------------------------------
# 3. the gate raises its exit code, and its un-run banner is not its pass line
# ---------------------------------------------------------------------------
check("exit 3" in gate_code, "3a: the warnings path exits 3")
check("exit 2" in gate_code, "3b: the could-not-run path exits 2")
# Read the CODE, not the header: the header explains the banner, so anchoring
# on the first occurrence anywhere anchors on the prose about it.
check("UNCERTIFIABLE" in gate_code, "3c: the could-not-run path says UNCERTIFIABLE")
_unc = gate_code.find("UNCERTIFIABLE")
check(_unc == -1 or "NOT a pass" in gate_code[_unc:_unc + 600],
      "3d: the banner says in words that it is not a pass")
check(re.search(r"SKIP \(no luacheck", gate_code) is None,
      "3e: the un-run path is not a bare SKIP line (that shape IS the defect)")
check("ensure_lua_tool luacheck" in gate,
      "3f: the gate buys luacheck before declaring it missing")
check("--formatter plain" in gate,
      "3g: the gate runs rule 6's actual command, not a variant of it")

# ---------------------------------------------------------------------------
# 4. end to end
# ---------------------------------------------------------------------------
BASH = shutil.which("bash") or "/bin/bash"

# 4a: no PATH at all.  This is the container case the whole issue is about, and
# it is reachable whether or not luacheck exists here: an empty PATH hides both
# luacheck and apt-get, so the buy fails at its first guard.  bash is resolved
# BEFORE the empty PATH is handed over -- passing "bash" with PATH="" starts
# nothing at all, and that crash looks green.
empty = tempfile.mkdtemp(prefix="ensure_nopath_")
try:
    p = subprocess.run([BASH, "-c", ". ./tools/agent/ensure_lua_toolchain.sh\n"
                                    "ensure_lua_tool luacheck; echo rc=$?"],
                       cwd=REPO, env={"PATH": empty}, timeout=180,
                       capture_output=True, text=True)
    out = p.stdout + p.stderr
    check("rc=1" in out, "4a: with no PATH the buy returns 1 (got %r)" % out[:200])
    # Nothing at all, not merely "no success line": the caller owns the banner,
    # and a helper that narrates its own failure inside 开工自检 is one more
    # unremarkable line in the region where the SKIP/PASS blindness lives.
    said = [ln for ln in out.splitlines() if ln.strip() and not ln.startswith("rc=")]
    check(not said, "4a2: and prints nothing at all while failing (got %r)" % said)

    g = subprocess.run([BASH, GATE], cwd=REPO, env={"PATH": empty}, timeout=180,
                       capture_output=True, text=True)
    gout = g.stdout + g.stderr
    check(g.returncode == 2,
          "4b: the gate exits 2 when it cannot run (got %d). Returning 0 here "
          "is the whole GH #205 defect: a gate that could not run must not "
          "return what a clean run returns." % g.returncode)
    check("UNCERTIFIABLE" in gout, "4b2: and prints the banner (got %r)" % gout[:200])
    check("0 warnings" not in gout, "4b3: and never emits the pass line")
finally:
    shutil.rmtree(empty, ignore_errors=True)

# 4c/4d: the red and clean paths, on a throwaway tree.  Deliberately NOT on
# `bots game`: that is 13s, and this file runs inside the python leg of 开工自检,
# which every stream pays for on every trigger.  The gate takes its targets as
# arguments precisely so this can be cheap and still exercise the real luacheck.
if shutil.which("luacheck") is None:
    print("  SKIP  4c/4d: end-to-end needs luacheck")
else:
    tmp = tempfile.mkdtemp(prefix="luacheck_gate_")
    try:
        clean_dir = os.path.join(tmp, "clean")
        dirty_dir = os.path.join(tmp, "dirty")
        os.makedirs(clean_dir)
        os.makedirs(dirty_dir)
        with open(os.path.join(clean_dir, "ok.lua"), "w") as fh:
            fh.write("local X = {}\nfunction X.f(a) return a end\nreturn X\n")
        # A 1xx (global access) warning -- the family .luacheckrc actually
        # enforces (`only = { "1" }`), so this is the real gate's real trigger.
        with open(os.path.join(dirty_dir, "bad.lua"), "w") as fh:
            fh.write("local X = {}\nfunction X.f() return ThisGlobalDoesNotExist end\nreturn X\n")

        c = subprocess.run([BASH, GATE, clean_dir], cwd=REPO, timeout=180,
                           capture_output=True, text=True)
        check(c.returncode == 0,
              "4c: a clean target exits 0 (got %d: %r)" % (c.returncode, (c.stdout + c.stderr)[:200]))
        check("0 warnings" in c.stdout, "4c2: and says so")

        d = subprocess.run([BASH, GATE, dirty_dir], cwd=REPO, timeout=180,
                           capture_output=True, text=True)
        dout = d.stdout + d.stderr
        check(d.returncode == 3, "4d: a warning exits 3 (got %d)" % d.returncode)
        check("LUACHECK RED" in dout, "4d2: and says LUACHECK RED")
        check("bad.lua" in dout, "4d3: and names the file (got %r)" % dout[:300])
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

print("\n%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)
