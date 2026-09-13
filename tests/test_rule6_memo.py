#!/usr/bin/env python3
"""[ratchet] The rule 6 push-gate memo may only ever be an OPTIMIZATION.

WHAT IT GUARDS.  `.githooks/pre-push` now memoizes one all-green three-leg
reading, keyed by `HEAD^{tree}` + `origin/main`, so the second `git push` of the
mandated two-push path replays it instead of re-earning it (director ruling
2026-09-13; see tools/agent/rule6_memo.py for why the RACE, not the waste, is
the reason).

THE FAILURE DIRECTION THAT MATTERS IS FAIL-OPEN: a memo that answers "green" for
a tree it was not taken on turns the whole gate into RULE6_BYPASS with a
friendlier banner -- and unlike the bypass, nothing would be printed for anyone
to quote.  So every check below asserts a MISS or a REFUSAL, not a hit; there is
exactly one hit assertion (case 1) and it exists only so the others cannot be
satisfied by a memo that never hits at all.  That pairing is deliberate: this
repo has shipped detectors whose passing state was "matches nothing".

The end-to-end case (5) drives the REAL hook file with stub gates, because the
memo's whole value lives in wiring the hook does -- reading PIPESTATUS rather
than `$?` through `tee`, and storing only on all-green.  A unit test of
rule6_memo.py alone would pass with the hook wired backwards.

Run: python3 tests/test_rule6_memo.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MEMO = os.path.join(REPO, "tools", "agent", "rule6_memo.py")
HOOK = os.path.join(REPO, ".githooks", "pre-push")

checks = 0
failures = []


def check(cond, why):
    global checks
    checks += 1
    if not cond:
        failures.append(why)


def run(cmd, cwd, env=None):
    e = dict(os.environ)
    e.setdefault("GIT_AUTHOR_NAME", "t")
    e.setdefault("GIT_AUTHOR_EMAIL", "t@e.st")
    e.setdefault("GIT_COMMITTER_NAME", "t")
    e.setdefault("GIT_COMMITTER_EMAIL", "t@e.st")
    if env:
        e.update(env)
    p = subprocess.run(
        cmd, cwd=cwd, env=e, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        universal_newlines=True,
    )
    return p.returncode, p.stdout


def memo(work, *args, **kw):
    return run([sys.executable, MEMO] + list(args), work, kw.get("env"))


def new_repo(root, name):
    """A work tree with a bare `origin` whose `main` matches HEAD."""
    work = os.path.join(root, name)
    bare = os.path.join(root, name + ".git")
    os.makedirs(work)
    run(["git", "init", "-q", "--bare", bare], root)
    run(["git", "init", "-q", "-b", "wip", work], root)
    run(["git", "config", "user.email", "t@e.st"], work)
    run(["git", "config", "user.name", "t"], work)
    with open(os.path.join(work, "f.txt"), "w") as fh:
        fh.write("one\n")
    run(["git", "add", "-A"], work)
    run(["git", "commit", "-qm", "init"], work)
    run(["git", "remote", "add", "origin", bare], work)
    run(["git", "push", "-q", "origin", "HEAD:refs/heads/main"], work)
    run(["git", "fetch", "-q", "origin", "main"], work)
    run(["git", "update-ref", "refs/remotes/origin/main", "FETCH_HEAD"], work)
    return work, bare


def commit(work, text):
    with open(os.path.join(work, "f.txt"), "w") as fh:
        fh.write(text)
    run(["git", "add", "-A"], work)
    run(["git", "commit", "-qm", text.strip()], work)


READINGS = (
    "GATE_EXIT=0  CLEAN (iron rule 6 static half passed)\n"
    "py gate: 97 ran, 0 findings, 0 uncertifiable, 28.5s\n"
    "lua gate: 354 ran, 0 findings, 0 uncertifiable, 9 known-red, 377.4s\n"
)

TMP = tempfile.mkdtemp(prefix="rule6memo.")
try:
    # ---- case 1: clean tree, stored reading, same tree -> HIT -----------
    # The only hit assertion in the file. Without it every other check could
    # be satisfied by a memo that is simply always a miss.
    work, _bare = new_repo(TMP, "hit")
    src = os.path.join(TMP, "readings.txt")
    with open(src, "w") as fh:
        fh.write(READINGS)
    rc, _ = memo(work, "put", src)
    check(rc == 0, "put on a clean tree should succeed, got rc=%d" % rc)
    rc, out = memo(work, "get")
    check(rc == 0, "get on the same clean tree should HIT, got rc=%d" % rc)
    check("RULE6_MEMO=REUSE" in out,
          "a hit must print the machine token RULE6_MEMO=REUSE")
    check("not a skip" in out,
          "a hit must say in words that it is a reuse and NOT a skip -- a "
          "banner readable as RULE6_BYPASS is the whole hazard")
    check(all(line.split(":")[0] in out for line in READINGS.strip().splitlines()),
          "a hit must replay the three stored verdict lines to be quoted")

    # ---- case 2: the tree moved -> MISS ---------------------------------
    commit(work, "two\n")
    rc, _ = memo(work, "get")
    check(rc == 1, "a new commit changes HEAD^{tree}; get must MISS, got rc=%d" % rc)

    # ---- case 3: dirty tree -> UNAVAILABLE, both directions -------------
    # The legs read what is on DISK. A dirty tree means the tree sha does not
    # name what was measured, so neither reading nor writing is allowed.
    work2, _ = new_repo(TMP, "dirty")
    rc, _ = memo(work2, "put", src)
    check(rc == 0, "baseline put on the clean tree failed, rc=%d" % rc)
    with open(os.path.join(work2, "f.txt"), "a") as fh:
        fh.write("edited\n")
    rc, out = memo(work2, "get")
    check(rc == 2, "a DIRTY tree must make get unavailable (2), got rc=%d" % rc)
    rc, _ = memo(work2, "put", src)
    check(rc == 2, "a DIRTY tree must refuse put (2), got rc=%d" % rc)
    # ...and an UNTRACKED file counts: luacheck lints files on disk, tracked
    # or not, so an untracked bots/*.lua is inside the measured domain.
    run(["git", "checkout", "-q", "--", "f.txt"], work2)
    rc, _ = memo(work2, "get")
    check(rc == 0, "restoring the file should restore the hit, got rc=%d" % rc)
    with open(os.path.join(work2, "untracked.lua"), "w") as fh:
        fh.write("-- x\n")
    rc, _ = memo(work2, "get")
    check(rc == 2, "an UNTRACKED file must make get unavailable (2), got rc=%d" % rc)
    os.unlink(os.path.join(work2, "untracked.lua"))

    # ---- case 4: origin/main moved -> MISS ------------------------------
    # The Lua leg scopes itself with `git diff origin/main...HEAD`, so a moved
    # base is a bigger changed-set: a different question, not the same answer.
    work3, bare3 = new_repo(TMP, "base")
    rc, _ = memo(work3, "put", src)
    check(rc == 0, "baseline put failed, rc=%d" % rc)
    rc, _ = memo(work3, "get")
    check(rc == 0, "baseline get should hit, rc=%d" % rc)
    other = os.path.join(TMP, "other")
    run(["git", "clone", "-q", "-b", "main", bare3, other], TMP)
    run(["git", "config", "user.email", "t@e.st"], other)
    run(["git", "config", "user.name", "t"], other)
    commit(other, "someone else\n")
    run(["git", "push", "-q", "origin", "HEAD:main"], other)
    run(["git", "fetch", "-q", "origin", "main"], work3)
    run(["git", "update-ref", "refs/remotes/origin/main", "FETCH_HEAD"], work3)
    rc, _ = memo(work3, "get")
    check(rc == 1, "a moved origin/main must MISS (1), got rc=%d" % rc)

    # ---- case 4b: a corrupt entry is a MISS, never a hit ----------------
    work4, _ = new_repo(TMP, "corrupt")
    memo(work4, "put", src)
    rc, keyout = memo(work4, "key")
    check(rc == 0 and "MEMO_KEY=" in keyout, "key subcommand should work")
    memo_dir = os.path.join(work4, ".git", "rule6_memo")
    names = sorted(os.listdir(memo_dir))
    check(len(names) == 1, "expected exactly one memo entry, got %r" % names)
    path = os.path.join(memo_dir, names[0])
    with open(path, "w") as fh:
        fh.write("{not json")
    rc, _ = memo(work4, "get")
    check(rc == 1, "a corrupt entry must MISS (1), not hit, got rc=%d" % rc)
    # A well-formed entry that names a DIFFERENT tree must also miss, even
    # though it sits under the right key -- the record is re-checked, not
    # trusted for having been found.
    with open(path, "w") as fh:
        json.dump({"tree": "0" * 40, "base": "0" * 40, "at": "x",
                   "readings": READINGS}, fh)
    rc, _ = memo(work4, "get")
    check(rc == 1, "an entry naming another tree must MISS (1), got rc=%d" % rc)
    # An empty reading is not a reading.
    empty = os.path.join(TMP, "empty.txt")
    open(empty, "w").close()
    rc, _ = memo(work4, "put", empty)
    check(rc == 2, "put must refuse empty readings (2), got rc=%d" % rc)

    # ---- case 5: end to end, the REAL hook with stub legs ---------------
    # Stubs make the three legs instant; what is under test is the hook's
    # wiring -- PIPESTATUS through `tee`, store-only-on-all-green, and the
    # second push of one tree taking the memo path.
    work5, _bare5 = new_repo(TMP, "e2e")
    os.makedirs(os.path.join(work5, ".githooks"))
    shutil.copy(HOOK, os.path.join(work5, ".githooks", "pre-push"))
    os.chmod(os.path.join(work5, ".githooks", "pre-push"), 0o755)
    agent = os.path.join(work5, "tools", "agent")
    os.makedirs(agent)
    shutil.copy(MEMO, os.path.join(agent, "rule6_memo.py"))
    # The marker lives OUTSIDE the work tree on purpose: an untracked file
    # inside it would (correctly) make the memo unavailable, and the test
    # would then pass for the wrong reason.
    marker = os.path.join(TMP, "legruns.txt")
    open(marker, "w").close()

    def write_stubs(luacheck_rc):
        with open(os.path.join(agent, "luacheck_gate.sh"), "w") as fh:
            fh.write("#!/usr/bin/env bash\n"
                     "echo leg1 >> %s\n"
                     "printf 'GATE_EXIT=%d  banner\\n'\n"
                     "exit %d\n" % (marker, luacheck_rc, luacheck_rc))
        with open(os.path.join(agent, "py_gate.py"), "w") as fh:
            fh.write("print('py gate: 1 ran, 0 findings, 0 uncertifiable, 0.1s')\n")
        with open(os.path.join(agent, "lua_gate.py"), "w") as fh:
            fh.write("print('lua gate: 1 ran, 0 findings, 0 uncertifiable, "
                     "0 known-red, 0.1s')\n")

    write_stubs(0)
    run(["git", "add", "-A"], work5)
    run(["git", "commit", "-qm", "stubs"], work5)
    run(["git", "config", "core.hooksPath", ".githooks"], work5)

    rc, out1 = run(["git", "push", "-q", "origin", "HEAD:refs/heads/br"], work5)
    check(rc == 0, "first push should pass the stubbed gate, rc=%d out=%s" % (rc, out1))
    check("RULE6_MEMO=REUSE" not in out1, "the FIRST push must not be a memo hit")
    runs_after_first = len(open(marker).read().split())

    rc, out2 = run(["git", "push", "-q", "origin", "HEAD:refs/heads/main2"], work5)
    check(rc == 0, "second push of the same tree should pass, rc=%d out=%s" % (rc, out2))
    check("RULE6_MEMO=REUSE" in out2,
          "the SECOND push of an identical tree must take the memo path; "
          "got:\n%s" % out2)
    runs_after_second = len(open(marker).read().split())
    check(runs_after_second == runs_after_first,
          "the memo hit must not run leg 1 again (%d -> %d)"
          % (runs_after_first, runs_after_second))

    # RULE6_NO_MEMO=1 forces a real second reading.
    rc, out3 = run(["git", "push", "-q", "origin", "HEAD:refs/heads/main3"], work5,
                   env={"RULE6_NO_MEMO": "1"})
    check(rc == 0, "forced re-run should still pass, rc=%d" % rc)
    check("RULE6_MEMO=REUSE" not in out3, "RULE6_NO_MEMO=1 must force the full legs")
    check(len(open(marker).read().split()) == runs_after_first + 1,
          "RULE6_NO_MEMO=1 must actually re-run leg 1")

    # ---- case 6: EACH leg red, one at a time ----------------------------
    # A red leg must (a) refuse the push and (b) leave nothing memoized, so the
    # retry after the fix cannot be answered out of the memo.
    #
    # ⚠️ EACH leg, separately, and that is not thoroughness for its own sake --
    # the mutation stand found the gap.  `tee` put a pipe on this path for the
    # first time, and `tee` succeeds essentially always, so a leg whose exit
    # code is read with `$?` instead of PIPESTATUS[0] reads GREEN off a RED
    # gate.  Leg 1 alone happens to survive that (it prints its own exit code
    # as `GATE_EXIT=` and the hook cross-checks the two, refusing on a
    # disagreement) -- so a test that only ever reddens leg 1 scores the pipe
    # bug as caught while legs 2 and 3, which print no exit code and have no
    # cross-check, would push a red tree in silence.
    def red_leg_case(tag, filename, body):
        w, _b = new_repo(TMP, "e2ered" + tag)
        shutil.copytree(os.path.join(work5, ".githooks"), os.path.join(w, ".githooks"))
        shutil.copytree(os.path.join(work5, "tools"), os.path.join(w, "tools"))
        a6 = os.path.join(w, "tools", "agent")
        with open(os.path.join(a6, filename), "w") as fh:
            fh.write(body)
        os.chmod(os.path.join(a6, filename), 0o755)
        run(["git", "add", "-A"], w)
        run(["git", "commit", "-qm", "stubs red " + tag], w)
        run(["git", "config", "core.hooksPath", ".githooks"], w)
        rc, out = run(["git", "push", "-q", "origin", "HEAD:refs/heads/br"], w)
        check(rc != 0, "a RED %s must REFUSE the push (PIPESTATUS, not $?); out=%s"
              % (tag, out))
        check("PUSH REFUSED" in out, "a red %s must print PUSH REFUSED; out=%s" % (tag, out))
        check(not os.path.isdir(os.path.join(w, ".git", "rule6_memo")),
              "a red %s must memoize NOTHING" % tag)

    red_leg_case("leg1", "luacheck_gate.sh",
                 "#!/usr/bin/env bash\nprintf 'GATE_EXIT=3  banner\\n'\nexit 3\n")
    red_leg_case("leg2", "py_gate.py",
                 "import sys\nprint('py gate: 1 ran, 1 findings, 0 uncertifiable, 0.1s')\n"
                 "sys.exit(3)\n")
    red_leg_case("leg3", "lua_gate.py",
                 "import sys\nprint('lua gate: 1 ran, 1 findings, 0 uncertifiable, "
                 "0 known-red, 0.1s')\nsys.exit(3)\n")
    # ...and could-not-run (exit 2) is not a pass either, on the leg that has
    # no banner to cross-check.
    red_leg_case("leg3-unrun", "lua_gate.py", "import sys\nsys.exit(2)\n")
finally:
    shutil.rmtree(TMP, ignore_errors=True)

print("%d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
