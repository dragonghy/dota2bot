#!/usr/bin/env python3
"""Acceptance for the pre-push Lua leg's SCOPE source (GH #865 (A), RULING 70).

WHAT WENT WRONG
---------------
`.githooks/pre-push` computed the fast Lua leg's scope as

    git diff --name-only origin/main...HEAD

`origin/main` is a LOCAL ref and `git push origin HEAD:main` MOVES it to HEAD.
So the twin push of the mandated two-push path asked that expression and got an
EMPTY diff -- which the gate reads, correctly by its own fail-closed rules, as
"could not tell, run everything".  Measured on the director's 2026-09-17T04:20Z
round: a markdown-only re-push whose tree `main` already carried printed
`scope EMPTY -> running the WHOLE manifest` and then ran 567.4s.  Worse, before
GH #865 (C) added the announce line, that leg printed nothing on its way in, so
in the log a leg that HUNG and a leg that was about to run the whole manifest
were indistinguishable -- and #865's first draft misattributed four reproducible
"hangs" to a network timeout, i.e. turned a fixable harness defect into an
unactionable fact about the environment.

THE FIX.  git already tells a pre-push hook the remote's current sha for each
ref, on stdin, as `<local ref> <local sha> <remote ref> <remote sha>`.  That sha
is the base the push is actually adding to and CANNOT be moved by an earlier
push in the same round.  `tools/agent/prepush_scope.sh` reads it.

THE AMENDMENT (RULING 70, and why this file has a fourth entry).  RULING 69's
(A) said an all-zero remote sha -- a NEW ref -- is "the true cannot-tell, run
the whole set".  That is right about git and wrong about this repo: every
Routine session pushes its own branch, so the branch push is a new ref on EVERY
round (measured 2026-09-17: 1264 `claude/*` refs on origin, this session's
branch absent from `ls-remote`).  Taken literally it would convert the FIRST
push of every round -- the common case, every markdown-only round included --
from a scope answer into a full manifest run: a regression in the common case,
bought to fix a rare one.  For a new branch the question still has an answer
(the commits this branch adds to the integration branch), so the new-ref path
falls back to the merge base with `origin/main`.  A branch push does not move
`origin/main`, so the twin-push defect cannot reach that path; and when it is
poisoned anyway (main pushed first), the merge base is HEAD, the diff is empty,
and empty still means RUN EVERYTHING.  The fallback can lose precision.  It
cannot fail open -- which is the only property that matters here.

WHAT THIS ASSERTS.  Not that the scope is "right" in some abstract sense: that
each of the entries below gets the answer its own rules name, and that the
fail-closed direction survives every way the computation can break.  Every
negative path in this file must end in `unknown` + an EMPTY path list, because
`lua_gate.touches_lua([])` is True -- an empty list runs the whole manifest.
A mutation stand at the bottom is the reason this is a ratchet and not a
restatement: four realistic edits, each of which must be killed by a named
entry.  The stand mutates COPIES in a temp dir and never writes the repo's own
file, so there is no restore step that can leave a patched control behind
(the trap measured on 2026-09-17T04:20Z, where the control copy was taken
AFTER the fix and duly reported "it never crashed").
"""

import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCOPE_SH = os.path.join(REPO, "tools", "agent", "prepush_scope.sh")
HOOK = os.path.join(REPO, ".githooks", "pre-push")

sys.path.insert(0, os.path.join(REPO, "tools", "agent"))

checks = 0
failures = []

ZERO = "0" * 40


def check(cond, what):
    global checks
    checks += 1
    if not cond:
        failures.append(what)
    return bool(cond)


def git(cwd, *args):
    return subprocess.run(("git",) + args, cwd=cwd, capture_output=True,
                          text=True, check=False)


def build_repo(tmp):
    """A throwaway repo with a base commit and one commit on top.

    Layout mirrors the shapes the gate cares about: a `bots/` Lua file (in
    scope), a `tests/` file (in scope), and a markdown file (out of scope).
    """
    r = os.path.join(tmp, "repo")
    os.makedirs(os.path.join(r, "bots"))
    os.makedirs(os.path.join(r, "docs"))
    git(r if os.path.isdir(r) else tmp, "init", "-q", r)
    git(r, "config", "user.email", "t@example.invalid")
    git(r, "config", "user.name", "t")
    git(r, "config", "commit.gpgsign", "false")

    def write(rel, text):
        p = os.path.join(r, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(text)

    write("bots/base.lua", "-- base\n")
    write("docs/base.md", "base\n")
    git(r, "add", "-A")
    git(r, "commit", "-q", "-m", "base")
    base = git(r, "rev-parse", "HEAD").stdout.strip()

    write("bots/changed.lua", "-- changed\n")
    write("docs/note.md", "note\n")
    git(r, "add", "-A")
    git(r, "commit", "-q", "-m", "work")
    head = git(r, "rev-parse", "HEAD").stdout.strip()

    # The local mirror of the remote's integration branch.
    git(r, "update-ref", "refs/remotes/origin/main", base)
    return r, base, head


def run_scope(repo, stdin_text, script=None, env_extra=None):
    """Run the scope tool; return (provenance_token, [paths])."""
    script = script or SCOPE_SH
    out = os.path.join(repo, ".scope_out")
    env = dict(os.environ)
    if env_extra:
        env.update(env_extra)
    p = subprocess.run(["bash", script, out], cwd=repo, input=stdin_text,
                       capture_output=True, text=True, check=False, env=env)
    token = p.stdout.strip().splitlines()[-1] if p.stdout.strip() else ""
    paths = []
    if os.path.exists(out):
        with open(out, encoding="utf-8") as fh:
            paths = [ln for ln in fh.read().splitlines() if ln]
        os.remove(out)
    return token, paths


def entries(repo, base, head, script=None):
    """The scope tool's answer for each documented entry.

    Returned as a dict so the mutation stand can name which entry killed which
    mutant, rather than reporting "something differs".
    """
    res = {}

    # 1. EXISTING remote ref: the sha git names is authoritative.
    res["existing_ref"] = run_scope(
        repo, "refs/heads/x %s refs/heads/x %s\n" % (head, base), script)

    # 2. The #865 case itself: local origin/main has been MOVED to HEAD (what
    #    `git push origin HEAD:main` does). The old expression answers empty
    #    here; the stdin remote sha is unaffected.
    git(repo, "update-ref", "refs/remotes/origin/main", head)
    res["poisoned_origin_main"] = run_scope(
        repo, "refs/heads/x %s refs/heads/x %s\n" % (head, base), script)
    git(repo, "update-ref", "refs/remotes/origin/main", base)

    # 3. NEW remote ref (all-zero remote sha) with a usable fallback.
    res["new_ref_fallback"] = run_scope(
        repo, "refs/heads/x %s refs/heads/x %s\n" % (head, ZERO), script)

    # 4. NEW remote ref with NO fallback base: nothing positive to say.
    res["new_ref_no_base"] = run_scope(
        repo, "refs/heads/x %s refs/heads/x %s\n" % (head, ZERO), script,
        env_extra={"PREPUSH_FALLBACK_REF": "refs/remotes/origin/nope"})

    # 5. A remote sha this clone does not have. An error must not arrive
    #    wearing the shape of "nothing changed".
    res["unknown_object"] = run_scope(
        repo, "refs/heads/x %s refs/heads/x %s\n" % (head, "b" * 40), script)

    # 6. No stdin at all (hand-invoked, or a caller that consumed it).
    res["no_stdin"] = run_scope(repo, "", script)

    # 7. A good line followed by a broken one: a partial answer is not an
    #    answer, so the path list must come back EMPTY, not half-filled.
    res["partial_then_broken"] = run_scope(
        repo,
        "refs/heads/x %s refs/heads/x %s\n" % (head, base)
        + "refs/heads/y %s refs/heads/y %s\n" % (head, "b" * 40),
        script)

    # 8. A pure DELETE (local sha zeroed) casts no vote.
    res["delete_only"] = run_scope(
        repo, "(delete) %s refs/heads/x %s\n" % (ZERO, base), script)
    return res


def main():
    import lua_gate  # noqa: E402  (path set above)

    tmp = tempfile.mkdtemp(prefix="prepush_scope_")
    try:
        repo, base, head = build_repo(tmp)
        r = entries(repo, base, head)

        # ---- entry 1: existing ref, authoritative base ----
        tok, paths = r["existing_ref"]
        check(tok == "stdin-remote",
              "existing remote ref: provenance must be `stdin-remote` (the sha "
              "git named), got %r" % tok)
        check(sorted(paths) == ["bots/changed.lua", "docs/note.md"],
              "existing remote ref: scope must be the diff from the sha git "
              "named, got %r" % (sorted(paths),))
        check(lua_gate.touches_lua(paths) is True,
              "existing remote ref: a scope containing bots/ must RUN the leg")

        # ---- entry 2: the defect GH #865 was opened about ----
        tok, paths = r["poisoned_origin_main"]
        check(tok == "stdin-remote" and sorted(paths) == ["bots/changed.lua",
                                                          "docs/note.md"],
              "GH #865: with local origin/main moved to HEAD (what `git push "
              "origin HEAD:main` does), the scope must still be the real diff. "
              "This is the whole fix: got tok=%r paths=%r" % (tok, sorted(paths)))

        # ---- entry 3: new ref falls back (RULING 70's amendment) ----
        tok, paths = r["new_ref_fallback"]
        check(tok == "fallback-merge-base",
              "new remote ref: with a usable integration ref the answer comes "
              "from the merge base, not from give-up. Every Routine session "
              "pushes a NEW branch, so give-up here is the common case paying "
              "for the rare one (RULING 70). got %r" % tok)
        check(sorted(paths) == ["bots/changed.lua", "docs/note.md"],
              "new remote ref: scope must be what this branch adds to the "
              "integration branch, got %r" % (sorted(paths),))

        # ---- entry 4: new ref, no base at all -> whole manifest ----
        tok, paths = r["new_ref_no_base"]
        check(tok == "unknown" and paths == [],
              "new remote ref with no usable fallback: no positive answer "
              "exists, so provenance is `unknown` and the path list is EMPTY "
              "(empty => run everything). got tok=%r paths=%r" % (tok, paths))
        check(lua_gate.touches_lua(paths) is True,
              "an EMPTY scope must still mean RUN EVERYTHING -- lua_gate."
              "touches_lua([]) is the fail-closed premise this file relies on. "
              "If that ever flips, this hook skips on silence.")

        # ---- entry 5-8: every other way it can break ends fail-closed ----
        for name in ("unknown_object", "no_stdin", "partial_then_broken",
                     "delete_only"):
            tok, paths = r[name]
            check(tok == "unknown" and paths == [],
                  "%s: a computation that could not answer must read "
                  "`unknown` with an EMPTY path list, never a partial or "
                  "silent one. got tok=%r paths=%r" % (name, tok, paths))

        # ---- the hook actually uses it, and stdin is read before any leg ----
        with open(HOOK, encoding="utf-8") as fh:
            hook = fh.read()
        check("prepush_scope.sh" in hook,
              ".githooks/pre-push must compute scope via "
              "tools/agent/prepush_scope.sh")
        # Comment lines are stripped before this one. The hook SHOULD still
        # name the old expression -- a fix whose file does not say what it
        # replaced is re-broken by the next reader -- and a whole-file text
        # match cannot tell an explanation from a use. What must be gone is the
        # expression as CODE.
        hook_code = "\n".join(ln for ln in hook.splitlines()
                              if not ln.lstrip().startswith("#"))
        check("origin/main...HEAD" not in hook_code,
              ".githooks/pre-push must no longer derive the Lua leg's scope "
              "from `origin/main...HEAD` -- that expression is the GH #865 "
              "defect, because `git push origin HEAD:main` moves that ref")
        check("origin/main...HEAD" in hook,
              ".githooks/pre-push must still NAME the expression it replaced, "
              "in a comment. GH #865 spent four reproductions misattributing "
              "this to the network; the next reader should not have to.")
        check("RUN EVERYTHING" in hook,
              ".githooks/pre-push must still say an empty scope runs "
              "everything (the fail-closed direction is deliberate)")
        if check(hook.count("PREPUSH_REFS") >= 2,
                 ".githooks/pre-push must capture git's ref-update lines"):
            check(hook.index("PREPUSH_REFS=") < hook.index("rule6_memo.py"),
                  ".githooks/pre-push must read stdin BEFORE the first "
                  "subprocess: stdin is consumable exactly once, and the memo "
                  "can exit the hook outright")

        # ---- mutation stand ----
        # Realistic edits, each on a COPY. The repo's own file is never written,
        # so no restore step can leave a patched control behind.
        with open(SCOPE_SH, encoding="utf-8") as fh:
            original = fh.read()

        mutants = [
            ("M1 revert to the poisonable expression",
             'base="$remote_sha"',
             'base=$(git rev-parse "$fallback_ref" 2>/dev/null)',
             "poisoned_origin_main"),
            ("M2 let a failed diff pass as an empty one",
             'if ! git diff --name-only "$base" "$local_sha" >> "$out" '
             '2>/dev/null; then\n        fail_closed\n        break\n    fi',
             'git diff --name-only "$base" "$local_sha" >> "$out" 2>/dev/null'
             ' || true',
             "unknown_object"),
            ("M3 literal RULING 69 (A): new ref always gives up",
             'base=$(git merge-base "$fallback_ref" "$local_sha" 2>/dev/null)'
             ' || base=""',
             'base=""',
             "new_ref_fallback"),
            ("M4 keep a partial path list after a failure",
             'if [ "$have_any" -ne 1 ]; then\n    src="unknown"\n'
             '    : > "$out" 2>/dev/null || true',
             'if [ "$have_any" -ne 1 ]; then\n    src="unknown"',
             "partial_then_broken"),
        ]

        mut_dir = os.path.join(tmp, "mutants")
        os.makedirs(mut_dir)

        # Control: the unmutated copy must reproduce the real file's answers.
        control = os.path.join(mut_dir, "control.sh")
        with open(control, "w", encoding="utf-8") as fh:
            fh.write(original)
        ctrl = entries(repo, base, head, script=control)
        check(all(ctrl[k] == r[k] for k in r),
              "mutation stand CONTROL: an unmutated copy must answer exactly "
              "as the repo's own file does. If this fails the stand is "
              "measuring the copy's environment, not the mutants.")

        for label, old, new, killer in mutants:
            if not check(original.count(old) == 1,
                         "mutation stand %s: its anchor must match exactly "
                         "once in prepush_scope.sh (found %d). A stale anchor "
                         "silently turns a mutant into a no-op, and a no-op "
                         "mutant always 'survives'."
                         % (label, original.count(old))):
                continue
            path = os.path.join(mut_dir, label.split()[0] + ".sh")
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(original.replace(old, new))
            mr = entries(repo, base, head, script=path)
            check(mr[killer] != r[killer],
                  "mutation stand %s SURVIVED: entry `%s` answered %r either "
                  "way. A mutant that survives means the entry is not "
                  "asserting what its name claims."
                  % (label, killer, mr[killer]))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("\n%d checks, %d failures" % (checks, len(failures)))
    for f in failures:
        print("  FAILED: %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
