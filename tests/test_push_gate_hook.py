#!/usr/bin/env python3
"""Acceptance for .githooks/pre-push + tools/agent/arm_push_gate.sh (GH #213).

WHY THIS EXISTS.  GH #205 made iron rule 6's static half RUNNABLE
(`tools/agent/luacheck_gate.sh`: buys `lua-check` in 5.5s, runs in 13s, exits
0/2/3).  It left the other half of the defect standing: the gate still only ran
if the pusher remembered, and `.claude/rules/claude-code.md`'s push path had
nothing between an author and `origin/main`.  That is GH #113's shape a fourth
time -- a check that exists and nobody runs -- and #113's own fix (hang it on
the one command every stream runs) is what this hook's ARMING borrows.

The load-bearing claims, in the order they can fail:
  1. the hook exists, is EXECUTABLE (git silently ignores a non-executable
     hook -- a disarmed gate that looks armed is worse than no gate), and
     DELEGATES to luacheck_gate.sh rather than growing a second copy of the
     luacheck invocation.  Same claim shape as test_selfcheck_lua_leg.py 4e/4f
     ("must not grow its own installer back"), one file over
  2. it REFUSES on red (gate exit 3) AND on could-not-run (gate exit 2).  The
     second is the load-bearing one: "could not run" reading as "allowed" is
     literally GH #171's SKIP and GH #205's `Unable to locate package`, both of
     which were one unremarkable line with no machine-readable effect
  3. RULE6_BYPASS=1 exists, allows, and SAYS it skipped -- a bypass nobody can
     spell strands work in a dead container (GH #113 measured that cost), and a
     bypass that says "ok" is the silent skip we just removed
  4. arming is bounded, guarded, LOUD on failure, idempotent, and refuses to
     stomp a core.hooksPath somebody else chose
  5. the selfcheck DELEGATES the arming (two lines) instead of inlining it, and
     raises its exit code when arming fails
  6. END TO END, in throwaway repos: gate exit 0 => push allowed; 3 => refused;
     2 => refused; bypass => allowed; and arm_push_gate.sh really sets
     core.hooksPath in a fresh clone, twice, without touching the work tree.

Run:  python3 tests/test_push_gate_hook.py
"""

import os
import shutil
import stat
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
HOOK = os.path.join(REPO, ".githooks", "pre-push")
ARM = os.path.join(REPO, "tools", "agent", "arm_push_gate.sh")
SELFCHECK = os.path.join(REPO, "tools", "agent", "routine_selfcheck.sh")
BASH = shutil.which("bash") or "/bin/bash"

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

    Absence claims must read code, not prose: these files document at length
    the very strings and shapes they are asserted NOT to contain, and asserting
    over prose makes their own history unwritable.  (tests/test_selfcheck_lua_leg.py
    paid for this lesson; GH #216 §6 paid for its mirror image, a comment that
    made itself false by naming a tag the discovery greps for.)
    """
    return "\n".join(ln for ln in text.splitlines()
                     if not ln.lstrip().startswith("#"))


def read(path):
    return open(path, encoding="utf-8").read() if os.path.exists(path) else ""


# ---------------------------------------------------------------------------
# 1. the hook exists, is executable, and delegates
# ---------------------------------------------------------------------------
check(os.path.exists(HOOK), "1a: .githooks/pre-push exists")
check(os.path.exists(ARM), "1b: tools/agent/arm_push_gate.sh exists")

hook, arm = read(HOOK), read(ARM)
hook_code, arm_code = code_only(hook), code_only(arm)

mode = os.stat(HOOK).st_mode if os.path.exists(HOOK) else 0
check(bool(mode & stat.S_IXUSR),
      "1c: the hook is executable -- git SKIPS a non-executable hook without a "
      "word, which is a gate that looks armed and is not")

check("tools/agent/luacheck_gate.sh" in hook_code,
      "1d: the hook delegates to the rule 6 gate")
check("luacheck " not in hook_code.replace("luacheck_gate.sh", ""),
      "1e: and does NOT grow its own luacheck invocation back -- one copy of "
      "the gate, or the two drift and the hook passes what the gate would fail")
check("run_tests.lua" not in hook_code,
      "1f: and does NOT quietly widen into the dynamic half (GH #124, ~100min); "
      "the scope written in the issue is the scope shipped")

# ---------------------------------------------------------------------------
# 2/3. refusal semantics and the bypass, read off the code
# ---------------------------------------------------------------------------
check("RULE6_BYPASS" in hook_code, "2a: the hook has a spellable bypass")
check("exit 1" in hook_code, "2b: the hook can refuse a push")

# ---------------------------------------------------------------------------
# 4. arming: bounded, guarded, loud, non-stomping
# ---------------------------------------------------------------------------
check("timeout " in arm_code,
      "4a: arming is bounded (it runs inside 开工自检; a hang there reads as "
      "'still working' and eats the trigger)")
check("command -v git" in arm_code,
      "4b: arming is guarded on git existing")
check("rev-parse" in arm_code,
      "4c: arming is guarded on actually being in a work tree")
check("core.hooksPath" in arm_code, "4d: arming sets core.hooksPath")
check("NOT ARMED" in arm_code,
      "4e: arming is LOUD when it fails -- unlike ensure_lua_toolchain.sh, "
      "whose caller decides what a missing tool means, here the failure IS the "
      "finding (an unarmed gate is the state this file exists to end)")
for forbidden in ("git stash", "git checkout -- ", "git reset", "rm -rf"):
    check(forbidden not in arm_code,
          "4f: arming never touches the work tree (%r) -- the selfcheck's "
          "refusal to auto-stash is untouched by this" % forbidden)

# ---------------------------------------------------------------------------
# 5. the selfcheck delegates rather than inlining
# ---------------------------------------------------------------------------
sc = code_only(read(SELFCHECK))
check("arm_push_gate.sh" in sc, "5a: the selfcheck arms the gate")
check("note 2" in sc.split("arm_push_gate.sh")[1].split("\n")[0]
      if "arm_push_gate.sh" in sc else False,
      "5b: and an unarmed gate raises the selfcheck's exit code (uncertifiable, "
      "not clean -- the three-value convention this wrapper already owns)")
check(sc.count("core.hooksPath") == 0,
      "5c: the selfcheck does NOT inline the arming -- one copy of the "
      "bounded/guarded/loud properties, asserted in one place (4a-4f above)")

# ---------------------------------------------------------------------------
# 6. END TO END
# ---------------------------------------------------------------------------
tmp = tempfile.mkdtemp(prefix="pushgate-")
try:
    def fake_repo(gate_exit):
        """A throwaway tree with the real hook and a stub gate."""
        d = tempfile.mkdtemp(dir=tmp)
        os.makedirs(os.path.join(d, "tools", "agent"))
        os.makedirs(os.path.join(d, ".githooks"))
        shutil.copy(HOOK, os.path.join(d, ".githooks", "pre-push"))
        stub = os.path.join(d, "tools", "agent", "luacheck_gate.sh")
        with open(stub, "w") as fh:
            fh.write("#!/usr/bin/env bash\nprintf 'STUBGATE\\n'\nexit %d\n" % gate_exit)
        os.chmod(stub, 0o755)
        return d

    def run_hook(d, env_extra=None):
        env = dict(os.environ)
        env.pop("RULE6_BYPASS", None)
        env.update(env_extra or {})
        return subprocess.run([os.path.join(d, ".githooks", "pre-push")],
                              cwd=d, env=env, input="", timeout=60,
                              capture_output=True, text=True)

    d0 = fake_repo(0)
    r0 = run_hook(d0)
    check(r0.returncode == 0,
          "6a: gate exit 0 => push allowed (got %d: %r)"
          % (r0.returncode, (r0.stdout + r0.stderr)[:200]))
    check("STUBGATE" in r0.stdout + r0.stderr,
          "6a2: and the gate actually ran (its output is on the pusher's screen, "
          "not swallowed)")

    d3 = fake_repo(3)
    r3 = run_hook(d3)
    check(r3.returncode != 0, "6b: gate exit 3 (RED) => push REFUSED")
    check("REFUSED" in r3.stdout + r3.stderr, "6b2: and says so")

    d2 = fake_repo(2)
    r2 = run_hook(d2)
    check(r2.returncode != 0,
          "6c: gate exit 2 (COULD NOT RUN) => push REFUSED too -- the whole "
          "point; 'uncertifiable' silently allowing is GH #171 and #205 verbatim")
    check("REFUSED" in r2.stdout + r2.stderr, "6c2: and says so")

    rb = run_hook(d3, {"RULE6_BYPASS": "1"})
    check(rb.returncode == 0, "6d: RULE6_BYPASS=1 lets a red tree through")
    check("SKIPPED, not passed" in rb.stdout + rb.stderr,
          "6d2: and the bypass line calls itself a SKIP, not a pass -- a bypass "
          "that prints nothing is the silent omission this hook removed")
    check("STUBGATE" not in rb.stdout + rb.stderr,
          "6d3: and the bypass short-circuits before the 13s gate (otherwise "
          "the escape hatch costs what it escapes)")

    # arming, in a fresh git repo that has never seen core.hooksPath
    repo = tempfile.mkdtemp(dir=tmp)
    subprocess.run(["git", "init", "-q", repo], check=True, timeout=60)
    os.makedirs(os.path.join(repo, "tools", "agent"))
    os.makedirs(os.path.join(repo, ".githooks"))
    shutil.copy(ARM, os.path.join(repo, "tools", "agent", "arm_push_gate.sh"))
    shutil.copy(HOOK, os.path.join(repo, ".githooks", "pre-push"))
    os.chmod(os.path.join(repo, ".githooks", "pre-push"), 0o755)
    marker = os.path.join(repo, "uncommitted.txt")
    with open(marker, "w") as fh:
        fh.write("work in progress\n")

    def hookspath(where):
        p = subprocess.run(["git", "config", "--get", "core.hooksPath"],
                           cwd=where, capture_output=True, text=True, timeout=60)
        return p.stdout.strip()

    a1 = subprocess.run([BASH, os.path.join(repo, "tools", "agent", "arm_push_gate.sh")],
                        cwd=repo, capture_output=True, text=True, timeout=60)
    check(a1.returncode == 0,
          "6e: arming a fresh clone succeeds (got %d: %r)"
          % (a1.returncode, (a1.stdout + a1.stderr)[:300]))
    check(hookspath(repo) == ".githooks",
          "6e2: and core.hooksPath really reads back as .githooks (got %r)"
          % hookspath(repo))
    check(os.path.exists(marker) and open(marker).read() == "work in progress\n",
          "6e3: and uncommitted work is untouched")

    a2 = subprocess.run([BASH, os.path.join(repo, "tools", "agent", "arm_push_gate.sh")],
                        cwd=repo, capture_output=True, text=True, timeout=60)
    check(a2.returncode == 0 and "already set" in a2.stdout,
          "6f: arming twice is idempotent and says it was already armed "
          "(got %d: %r)" % (a2.returncode, (a2.stdout + a2.stderr)[:200]))

    subprocess.run(["git", "config", "core.hooksPath", ".myhooks"],
                   cwd=repo, check=True, timeout=60)
    a3 = subprocess.run([BASH, os.path.join(repo, "tools", "agent", "arm_push_gate.sh")],
                        cwd=repo, capture_output=True, text=True, timeout=60)
    check(a3.returncode != 0 and hookspath(repo) == ".myhooks",
          "6g: a core.hooksPath somebody else chose is NOT stomped (got %d, now %r)"
          % (a3.returncode, hookspath(repo)))
    check("NOT ARMED" in a3.stdout + a3.stderr,
          "6g2: and refusing to stomp is announced, not silent")

    # not a git work tree at all
    bare = tempfile.mkdtemp(dir=tmp)
    os.makedirs(os.path.join(bare, "tools", "agent"))
    os.makedirs(os.path.join(bare, ".githooks"))
    shutil.copy(ARM, os.path.join(bare, "tools", "agent", "arm_push_gate.sh"))
    shutil.copy(HOOK, os.path.join(bare, ".githooks", "pre-push"))
    os.chmod(os.path.join(bare, ".githooks", "pre-push"), 0o755)
    a4 = subprocess.run([BASH, os.path.join(bare, "tools", "agent", "arm_push_gate.sh")],
                        cwd=bare, capture_output=True, text=True,
                        timeout=60, env={**os.environ, "GIT_CEILING_DIRECTORIES": bare})
    check(a4.returncode != 0 and "NOT ARMED" in a4.stdout + a4.stderr,
          "6h: outside a work tree it fails loudly instead of pretending "
          "(got %d: %r)" % (a4.returncode, (a4.stdout + a4.stderr)[:200]))

    # the hook must also refuse when the gate is missing entirely -- a clone
    # with a deleted gate is exactly the "could not run" case, arriving by a
    # different road than a missing package.
    dmissing = fake_repo(0)
    os.remove(os.path.join(dmissing, "tools", "agent", "luacheck_gate.sh"))
    rm = run_hook(dmissing)
    check(rm.returncode != 0,
          "6i: a MISSING gate script refuses the push too (got %d)" % rm.returncode)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("\n%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)
