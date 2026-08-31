#!/usr/bin/env python3
"""Acceptance for the IGNORED-BY-DESIGN path class (GH #365, strategy 13:57Z §8).

THE INCIDENT THIS PINS
----------------------
The strategy group published a GH #365 comment whose entire subject was that
`bots/Customize/soak_side.lua` -- a farm-only switch listed in `.gitignore` --
is absent from trunk.  `claim_precheck.sh` judged that comment exit 3 with the
single finding `MISSING path bots/Customize/soak_side.lua`.  The tool was not
wrong about the fact; it was wrong about what the fact means.  MISSING means
"you forgot to push", and nobody can push a gitignored path.  The comment went
out over a known exit 3, and every comment of that shape would have to be
pardoned by hand -- which is how a gate stops being run at all.

THE LOAD-BEARING CLAIMS
-----------------------
  1. a draft citing a gitignored path exits 0, and prints the path under
     IGNORED-BY-DESIGN -- forgiven OUT LOUD, because a silent amnesty and a
     correct one have the same exit code;
  2. the downgrade is scoped to gitignored paths ONLY: a draft citing a plain
     unpushed file still exits 3 with MISSING.  If this test only had claim 1,
     "always return IGNORED" would pass it;
  3. a TRACKED path keeps resolving OK even when an ignore rule would match it
     (rules do not override what is actually on trunk);
  4. the guard: when the container's `.gitignore` differs from trunk's, the
     downgrade is withheld and the path reads MISSING again.  check-ignore
     reads the working tree, the audit speaks about trunk, and an ignore rule
     that exists only here proves nothing about a reader's checkout.

Run:  python3 tests/test_citation_audit_ignored.py
"""

import os
import subprocess
import sys
import tempfile
import shutil

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
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def run(draft, repo):
    env = dict(os.environ, CLAIM_PRECHECK_REPO=repo)
    p = subprocess.run(["bash", TOOL, draft], cwd=REPO, env=env,
                       capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def main():
    root = tempfile.mkdtemp(prefix="citignore-")
    try:
        # A real origin + a real clone, same shape as test_claim_precheck.py:
        # git is the part that can be wrong, so it is not mocked.
        origin = os.path.join(root, "origin.git")
        seed = os.path.join(root, "seed")
        os.makedirs(seed)
        git(["init", "-q", "-b", "main"], seed)
        git(["config", "user.email", "t@t"], seed)
        git(["config", "user.name", "t"], seed)
        write(os.path.join(seed, ".gitignore"), "bots/Customize/soak_side.lua\n")
        write(os.path.join(seed, "bots/BotLib/hero_axe.lua"), "-- tracked\n")
        git(["add", "-A"], seed)
        git(["commit", "-q", "-m", "seed"], seed)
        # `-b main` on the bare repo: without it HEAD points at `master`, the
        # clone below checks nothing out, and every check in this file fails for
        # a reason that has nothing to do with what it tests.
        git(["init", "-q", "--bare", "-b", "main", origin], root)
        git(["remote", "add", "origin", origin], seed)
        git(["push", "-q", "-u", "origin", "main"], seed)

        clone = os.path.join(root, "clone")
        git(["clone", "-q", origin, clone], root)
        git(["config", "user.email", "t@t"], clone)
        git(["config", "user.name", "t"], clone)

        draft = os.path.join(root, "draft.md")

        # --- claim 1: the incident itself, and it must print the reason.
        write(draft, "The switch `bots/Customize/soak_side.lua` is not on trunk, "
                     "and that absence is the subject of this comment.\n")
        rc, out = run(draft, clone)
        check(rc == 0, "gitignored path alone -> exit 0 (was 3, the #365 shape)")
        check("IGNORED-BY-DESIGN" in out and "soak_side.lua" in out,
              "the forgiven path is printed by name, not silently dropped")
        check("MISSING" not in out, "no MISSING line for a by-design absence")

        # --- claim 2: scope.  An ordinary unpushed path is still a finding.
        # Without this case, `return "IGNORED"` unconditionally passes claim 1.
        write(os.path.join(clone, "tests/test_brand_new.lua"), "-- local only\n")
        git(["add", "-A"], clone)
        git(["commit", "-q", "-m", "local work"], clone)
        write(draft, "See `tests/test_brand_new.lua` and "
                     "`bots/Customize/soak_side.lua`.\n")
        rc, out = run(draft, clone)
        check(rc == 3, "an ordinary unpushed path still exits 3")
        check("MISSING" in out and "test_brand_new.lua" in out,
              "the unpushed path is still named MISSING")
        check("IGNORED-BY-DESIGN" in out and "soak_side.lua" in out,
              "both classes coexist in one draft, each on its own line")

        # --- claim 3: tracked wins over the rule.
        write(os.path.join(clone, ".gitignore"),
              "bots/Customize/soak_side.lua\nbots/BotLib/hero_axe.lua\n")
        git(["add", "-A"], clone)
        git(["commit", "-q", "-m", "widen ignore"], clone)
        git(["push", "-q", "origin", "main"], clone)
        write(draft, "`bots/BotLib/hero_axe.lua` is on trunk AND matched by a rule.\n")
        rc, out = run(draft, clone)
        check(rc == 0, "a tracked path that a rule matches is still fine")
        check("IGNORED-BY-DESIGN" not in out,
              "on-trunk resolution wins over the ignore rule (OK, not IGNORED)")

        # --- claim 4: the guard.  A rule that lives only in this container
        # must not speak for a reader's checkout.
        write(os.path.join(clone, ".gitignore"),
              "bots/Customize/soak_side.lua\nbots/BotLib/hero_axe.lua\ntools/local_only.py\n")
        # uncommitted: working tree now differs from trunk on .gitignore
        write(draft, "`tools/local_only.py` -- ignored HERE, unknown to trunk.\n")
        rc, out = run(draft, clone)
        check(rc == 3, "container-only ignore rule does NOT forgive (exit 3)")
        check("MISSING" in out and "local_only.py" in out,
              "with divergent .gitignore, MISSING keeps its old meaning")
        # and the divergence withholds the downgrade from EVERY path, including
        # the one that would legitimately earn it -- fail closed, not open.
        write(draft, "`bots/Customize/soak_side.lua` again, under a dirty .gitignore.\n")
        rc, out = run(draft, clone)
        check(rc == 3 and "IGNORED-BY-DESIGN" not in out,
              "the guard is repo-wide: no downgrade at all while rules diverge")

        # restore parity and show the same draft flips back -- so claim 4 is a
        # guard, not a constant refusal.
        write(os.path.join(clone, ".gitignore"),
              "bots/Customize/soak_side.lua\nbots/BotLib/hero_axe.lua\n")
        rc, out = run(draft, clone)
        check(rc == 0 and "IGNORED-BY-DESIGN" in out,
              "restoring .gitignore parity restores the downgrade")

        # --- claim 4b: the UNTRACKED half of the guard.  Added because M5 of
        # this change's mutation stand -- deleting the `ls-files --others` check
        # and keeping only the diff -- survived every case above.  A nested
        # `.gitignore` that was never committed diverges from trunk while
        # `git diff` stays silent about it, because diff does not see untracked
        # files.  That is the one shape the diff alone cannot cover.
        write(os.path.join(clone, "tools/.gitignore"), "local_only.py\n")
        write(draft, "`tools/local_only.py` -- ignored by an UNTRACKED rule file.\n")
        rc, out = run(draft, clone)
        check(rc == 3 and "MISSING" in out,
              "an untracked .gitignore does not earn the downgrade for its own rule")
        write(draft, "`bots/Customize/soak_side.lua` under an untracked ignore file.\n")
        rc, out = run(draft, clone)
        check(rc == 3 and "IGNORED-BY-DESIGN" not in out,
              "an untracked .gitignore withholds the downgrade repo-wide too")
        os.remove(os.path.join(clone, "tools/.gitignore"))
        rc, out = run(draft, clone)
        check(rc == 0 and "IGNORED-BY-DESIGN" in out,
              "removing the untracked rule file restores the downgrade")
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("\n%d checks, %d failures" % (checks, len(failures)))
    for f in failures:
        print("  FAILED: %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
