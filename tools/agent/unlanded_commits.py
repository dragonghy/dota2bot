#!/usr/bin/env python3
"""Report work that was committed and pushed to a session branch but never landed on main.

WHY THIS EXISTS
---------------
2026-08-22T03:00Z, director.  Two whole work units -- `director 01:00Z` (GH #103,
the gate-claim ratchet) and `strategy 22:33Z` (GH #100, the sixteenth world
assertion, 24 tests) -- were committed, pushed to their own session branches, and
never reached `main`.  Both opened GitHub issues describing the work as DONE, so
every downstream reader believed the fix was in the tree while `nochaselow` was
still sitting in `bots/FunLib/jmz_func.lua` and `test_gate_claim_consistency.lua`
did not exist.  Nothing in the team's routine could see this: each agent verifies
its OWN push, and a push to `refs/heads/<session-branch>` succeeds even when the
follow-up `git push origin HEAD:main` does not.

The loss is silent in both directions.  The author's session ends believing it
shipped; the next session reads `main` and sees no gap, because a gap is the
absence of a commit and absence has no shape.  This tool gives it a shape.

TWO TRAPS THIS TOOL IS BUILT AROUND
-----------------------------------
1. THE SHALLOW CLONE.  Agent containers clone shallow (this repo's `main` reads
   as 50 commits).  Under a shallow clone, every commit older than the graft
   boundary looks unreachable from `main` whether or not it landed -- the naive
   `git log --all --not origin/main` over-reports by ~100 commits here.  The
   batch desk hit the mirror of this on 2026-08-21T12:10Z ("a shallow clone makes
   the tree-drift check fail toward 'clean'").

   The protection is a REFUSAL, not a filter: a ref with no merge-base against
   the truncated trunk is uncertifiable, so it is counted and named as refused
   rather than judged.  On the live container that is 172 of 213 refs -- which is
   the honest answer, not a defect.  The count is always printed, so "refused
   172" can never be mistaken for "checked 172".  A deepened clone
   (`git fetch --unshallow`) converts refusals into real answers.

2. THE REBASE TWIN.  A commit that landed via rebase has a different SHA on the
   stale branch, so SHA identity over-reports too.  Patch identity is the right
   equivalence, so the walk is `git cherry`, which marks `-` for a patch already
   upstream and `+` for one that genuinely is not.

ANTI-EMPTY-MATCH
----------------
"Nothing is unlanded" and "the scan matched nothing" are the same output unless
the denominator is printed -- the failure shape this team has now hit in #29,
#31, #34, #37, #95 and #103.  So every run prints refs scanned / commits
examined / boundary, and a run that examined zero refs exits non-zero instead of
reporting a clean tree.

LIMITS -- read these before believing a finding
-----------------------------------------------
1. It can only see refs that exist in THIS clone.  Work that was never pushed at
   all is invisible to it and always will be: it answers "was pushed work
   merged", not "was all work pushed".

2. IT DETECTS AN ABSENT *PATCH*, NOT ABSENT *WORK*.  `git cherry` compares
   patch-ids, so a commit whose content reached the trunk in MODIFIED form --
   re-applied by hand, re-created on a newer base, landed with the numbers
   updated -- has a different patch-id and is still reported.  Measured on this
   repo 2026-08-22: c58de69 and 2ec437a were reported unlanded while their
   content was already on main as cac2fa5 and 7de5147, because the relanded
   copies carried different corpus constants.  The report is literally true and
   reads as something stronger than it is.

   So a finding is a QUESTION, not a verdict.  Triage it by looking for the
   content on the trunk (`git log --oneline --all --grep`, or diff the file the
   commit touches) before concluding anything was lost.  The cheap tell is a
   trunk commit with the same subject or the same files.

3. A shallow clone leaves most refs uncertifiable (172 of 213 here).  Those are
   counted and named as refused, never silently judged.

EXIT CODES
    0  scanned, nothing unlanded
    2  cannot certify (zero refs scanned, or `git` refused)
    3  unlanded work found
"""

import argparse
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

DEFAULT_REMOTE = "origin"
DEFAULT_TRUNK = "main"


def git(args, cwd, check=True):
    p = subprocess.run(
        ["git"] + args, cwd=cwd, capture_output=True, text=True
    )
    if check and p.returncode != 0:
        raise RuntimeError("git %s failed: %s" % (" ".join(args), p.stderr.strip()))
    return p.stdout


def is_shallow(cwd):
    return git(["rev-parse", "--is-shallow-repository"], cwd).strip() == "true"


def commit_date(cwd, sha):
    """Committer date, UTC.  Committer (not author) is what rebase moves, and
    what the graft boundary is expressed in."""
    raw = git(["show", "-s", "--format=%cI", sha], cwd).strip()
    return datetime.fromisoformat(raw)


def trunk_boundary(cwd, trunk):
    """Oldest commit reachable from trunk.  Under a shallow clone this is the
    graft point: below it, reachability from trunk is unknowable, not false."""
    shas = git(["rev-list", trunk], cwd).split()
    if not shas:
        raise RuntimeError("%s has no commits" % trunk)
    return shas[-1], commit_date(cwd, shas[-1])


def remote_refs(cwd, remote, trunk_ref):
    """Session branches under the remote, trunk and the remote HEAD excluded.

    Filter on the FULL refname: `refs/remotes/origin/HEAD` shortens to plain
    `origin`, so a `%(refname:short).endswith("/HEAD")` test silently lets it
    through and counts the trunk a second time under an alias.  Caught by case
    5's non-zero-denominator check."""
    out = git(
        [
            "for-each-ref",
            "--format=%(refname)%09%(refname:short)%09%(symref)",
            "refs/remotes/%s" % remote,
        ],
        cwd,
    )
    refs = []
    for line in out.splitlines():
        parts = line.split("\t")
        full, short = parts[0], parts[1]
        symref = parts[2] if len(parts) > 2 else ""
        if full.endswith("/HEAD") or symref:
            continue
        if short == trunk_ref:
            continue
        refs.append(short)
    return refs


def unlanded_on_ref(cwd, trunk_ref, ref):
    """Commits on `ref` whose PATCH is not upstream in trunk.

    `git cherry` needs a fork point; with a shallow clone there may not be one,
    which is itself information -- return it rather than swallowing it."""
    try:
        base = git(["merge-base", trunk_ref, ref], cwd).strip()
    except RuntimeError:
        return None, "no merge-base with %s (shallow graft or unrelated history)" % trunk_ref
    try:
        out = git(["cherry", trunk_ref, ref, base], cwd)
    except RuntimeError as exc:
        return None, str(exc)
    return [ln.split()[1] for ln in out.splitlines() if ln.startswith("+")], None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--repo", default=".")
    ap.add_argument("--remote", default=DEFAULT_REMOTE)
    ap.add_argument("--trunk", default=DEFAULT_TRUNK)
    ap.add_argument(
        "--days",
        type=float,
        default=3.0,
        help="only report commits this recent (default 3); the routine cadence is "
        "2h, so anything older has already been read past by every group",
    )
    ap.add_argument(
        "--verbose-refusals",
        action="store_true",
        help="list every uncertifiable ref instead of a count plus three examples",
    )
    ap.add_argument(
        "--fetch",
        action="store_true",
        help="fetch the remote first; without it the scan can only see refs "
        "already in this clone, which is a smaller claim",
    )
    args = ap.parse_args(argv)

    cwd = args.repo
    trunk_ref = "%s/%s" % (args.remote, args.trunk)

    if args.fetch:
        try:
            git(["fetch", args.remote], cwd)
        except RuntimeError as exc:
            print("WARN  fetch failed, scanning refs already in this clone: %s" % exc)

    shallow = is_shallow(cwd)
    try:
        boundary_sha, boundary_date = trunk_boundary(cwd, trunk_ref)
    except RuntimeError as exc:
        # An unresolvable trunk used to exit 1 with a traceback.  Exit 1 is what
        # a python crash and a shell failure both look like, and neither reads as
        # "this scan did not happen" -- so say it in the tool's own vocabulary.
        print("=== unlanded-commit scan ===")
        print("CANNOT CERTIFY: %s is unreadable -- %s" % (trunk_ref, exc))
        print("An empty scan is not a clean tree.")
        return 2
    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)

    # NOTE (2026-08-22, director): an earlier draft added a second floor here --
    # `max(cutoff, boundary_date)` when shallow -- to keep pre-graft commits out.
    # Mutation M2 could not kill it, and the reason is structural, not a weak
    # test: a ref only reaches this loop if it HAS a merge-base with the trunk,
    # and a merge-base present in a shallow clone is itself at or above the graft
    # point, so every commit `git cherry` can return is already newer than the
    # boundary.  The line was decorative.  The real shallow protection is the
    # REFUSED path in unlanded_on_ref() (172 of 213 refs on the live container),
    # and it is load-bearing and tested.  Deleted rather than kept, because a
    # guard nothing can kill is the same shape as the lying gate comments in
    # GH #103.
    floor = cutoff

    refs = remote_refs(cwd, args.remote, trunk_ref)

    findings = []
    refused = []
    examined = 0
    for ref in refs:
        shas, err = unlanded_on_ref(cwd, trunk_ref, ref)
        if shas is None:
            refused.append((ref, err))
            continue
        for sha in shas:
            examined += 1
            when = commit_date(cwd, sha)
            if when < floor:
                continue
            subject = git(["show", "-s", "--format=%s", sha], cwd).strip()
            findings.append((when, sha[:7], ref, subject))

    # ---- denominator, always, so a clean run cannot be confused with no run ----
    print("=== unlanded-commit scan ===")
    print("trunk            : %s (%s commits)" % (trunk_ref, len(git(["rev-list", trunk_ref], cwd).split())))
    print("refs scanned     : %d" % len(refs))
    print("commits examined : %d (patch-id compared, rebase twins excluded)" % examined)
    print("age cutoff       : %s (--days %g)" % (cutoff.isoformat(timespec="seconds"), args.days))
    print("shallow clone    : %s" % ("YES" if shallow else "no"))
    if shallow:
        print(
            "REFUSED below    : %s (%s) -- reachability from %s is UNKNOWABLE below the\n"
            "                   graft point, so nothing older is reported either way."
            % (boundary_date.isoformat(timespec="seconds"), boundary_sha[:7], trunk_ref)
        )
    # Aggregate, don't enumerate.  On a real container 200 of 213 refs have no
    # merge-base with a shallow trunk, and printing a line each buries the two
    # commits that matter under two screens of noise -- a report nobody reads is
    # the same as no report.  But the COUNT stays, because "refused 200" and
    # "refused 0" must never look alike.
    if refused:
        print(
            "REFUSED refs     : %d of %d (uncertifiable, mostly stale session branches "
            "with no\n                   merge-base against a shallow trunk)"
            % (len(refused), len(refs))
        )
        for ref, err in refused[:3]:
            print("                   e.g. %s -- %s" % (ref, err))
        if len(refused) > 3:
            print("                   ... %d more (pass --verbose-refusals to list)" % (len(refused) - 3))
        if args.verbose_refusals:
            for ref, err in refused:
                print("                   REFUSED %s -- %s" % (ref, err))
    print("certifiable refs : %d" % (len(refs) - len(refused)))

    if not refs:
        print("\nCANNOT CERTIFY: zero refs scanned. An empty scan is not a clean tree.")
        return 2

    if not findings:
        print("\nOK: no unlanded work in the certifiable window.")
        return 0

    print("\nUNLANDED WORK (%d commit(s)) -- committed and pushed, never on %s:" % (len(findings), trunk_ref))
    for when, short, ref, subject in sorted(findings, reverse=True):
        print("  %s  %s  %s" % (when.isoformat(timespec="seconds"), short, subject))
        print("      on %s   ->  git cherry-pick %s" % (ref, short))
    return 3


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # `... | head` closes the pipe early; without this the tool exits 1,
        # which is indistinguishable from "the scan failed".
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(2)
