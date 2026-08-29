#!/usr/bin/env python3
"""Acceptance for tools/agent/claim_precheck.sh (GH #290).

Replays the 2026-08-28T22:03Z incident on a real throwaway repository: a round
commits a fix locally, then -- before pushing -- drafts the comment that closes
the issue and cites the new test file, the new state.json key and the new
test_set.md section.  Every one of those citations resolves in the container and
in NONE of them for a reader.

The load-bearing claims:

  1. the draft, checked while the work is unpushed, exits 3 and names the
     citations that do not resolve on origin/main;
  2. the SAME draft, checked after the push, exits 0 -- so the gate is not a
     constant refusal, and the order it demands is the only difference;
  3. the unpushed-commit count is printed either way, because it is the reason
     case 1 fails and a reader of the output should not have to infer it;
  4. a draft that cites nothing exits 0 with a line saying so -- refusing there
     is how a gate earns the reflex to skip it;
  5. no draft argument, or an unreadable one, is exit 2 (could not run), never
     0 -- rule 10's vocabulary: not-run is not a pass.

Run:  python3 tests/test_claim_precheck.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TOOL = os.path.join(REPO, "tools", "agent", "claim_precheck.sh")

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)
    else:
        print("  ok    %s" % label)


def git(args, cwd):
    subprocess.run(["git"] + args, cwd=cwd, check=True, capture_output=True, text=True)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def run(draft, repo):
    env = dict(os.environ, CLAIM_PRECHECK_REPO=repo)
    p = subprocess.run(["bash", TOOL] + draft, cwd=REPO, env=env,
                       capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def main():
    root = tempfile.mkdtemp(prefix="claimpre-")
    try:
        # A real origin + a real clone.  The clone is where the round works.
        origin = os.path.join(root, "origin.git")
        seed = os.path.join(root, "seed")
        os.makedirs(seed)
        git(["init", "-q", "-b", "main"], seed)
        git(["config", "user.email", "t@t"], seed)
        git(["config", "user.name", "t"], seed)
        write(os.path.join(seed, "iterations/state.json"), json.dumps({"old": 1}) + "\n")
        write(os.path.join(seed, "iterations/streams/test_set.md"), "# test set\n")
        git(["add", "-A"], seed)
        git(["commit", "-qm", "seed"], seed)
        # `-b main` on the BARE side too: without it the bare HEAD points at
        # `master`, the clone below checks nothing out, and the push in case 2
        # dies on "src refspec main does not match any" -- a fixture bug that
        # would read as a tool failure.
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", origin],
                       check=True, capture_output=True, text=True)
        git(["remote", "add", "origin", origin], seed)
        git(["push", "-q", "-u", "origin", "main"], seed)

        work = os.path.join(root, "work")
        subprocess.run(["git", "clone", "-q", origin, work], check=True,
                       capture_output=True, text=True)
        git(["config", "user.email", "t@t"], work)
        git(["config", "user.name", "t"], work)

        # The round does the work -- for real -- and commits it locally.
        write(os.path.join(work, "tests/test_skill_list_nil_head_drain.lua"), "-- 9 checks\n")
        write(os.path.join(work, "iterations/state.json"),
              json.dumps({"old": 1, "skilldrain_NILHEAD_20260828": {"why_not_gated": "..."}}) + "\n")
        write(os.path.join(work, "iterations/streams/test_set.md"),
              "# test set\n\n## §CA the ruling\ntext\n")
        git(["add", "-A"], work)
        git(["commit", "-qm", "the fix"], work)

        draft = os.path.join(root, "draft.md")
        write(draft,
              "director ruling + landing. archive `test_set.md` §CA; machine-readable\n"
              "`iterations/state.json:skilldrain_NILHEAD_20260828`; the assertions are in\n"
              "tests/test_skill_list_nil_head_drain.lua (9 checks, 7/7 mutations).\n")

        # 1 + 3. committed, NOT pushed -- exactly the 22:03Z state
        print("\ncase 1: draft checked while the work is unpushed")
        code, out = run([draft], work)
        check(code == 3, "exit 3")
        check("DO NOT PUBLISH YET" in out, "says not to publish")
        check("test_skill_list_nil_head_drain.lua" in out, "names the missing test file")
        check("skilldrain_NILHEAD_20260828" in out, "names the missing state.json key")
        check("§CA" in out, "names the missing test_set.md section")
        check("local commits not on origin/main: 1" in out,
              "prints the unpushed count that explains it")

        # 2. push, then the same draft
        print("\ncase 2: the same draft, after the push")
        git(["push", "-q", "origin", "main"], work)
        code, out = run([draft], work)
        check(code == 0, "exit 0 -- the gate is not a constant refusal")
        check("OK to publish" in out, "says it is safe now")
        check("local commits not on origin/main: 0" in out, "count went to 0")

        # 4. nothing to certify
        print("\ncase 4: a draft that cites nothing")
        empty = os.path.join(root, "empty.md")
        write(empty, "looks good to me, shipping\n")
        code, out = run([empty], work)
        check(code == 0, "exit 0")
        check("NO CITATIONS" in out, "says why, rather than printing a bare pass")

        # 5. could-not-run is not a pass
        print("\ncase 5: could-not-run")
        code, out = run([], work)
        check(code == 2, "no draft -> exit 2")
        check("not a pass" in out, "says a refusal is not a pass")
        code, out = run([os.path.join(root, "no-such-file.md")], work)
        check(code == 2, "unreadable draft -> exit 2")

    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("\n%d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  - %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
