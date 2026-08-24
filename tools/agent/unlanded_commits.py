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

CLAIMS-LANDED -- why one unlanded commit is worse than another
--------------------------------------------------------------
2026-08-24T12:xxZ, director.  Not all UNLANDED rows are equal, and until this
round the tool printed them as if they were.

A plain unlanded commit is WORK IN FLIGHT.  It is benign by default: the next
round's selfcheck names it and rescues it, which is the loop working.  That is
what 2026-08-22 was, and what the rescue note of 2026-08-23T23:16Z was -- it
said, in the commit itself, that main was DELIBERATELY not pushed until a gate
closed, and it left the rescue instruction.  Nothing was misinformed.

An unlanded commit whose own text says IT ALREADY LANDED is a different animal.
2026-08-24T01:xxZ ran its gate to completion (full suite 1658/0), wrote
"promote 已落 main" into both its report and the charter status section, and
then ended without the push.  Every downstream reader inherits an assertion
that is false: the charter is the first thing each fresh routine session reads,
and one of those readers -- the batch desk -- CLONES `origin/main` and spends
real money measuring whatever tree it finds there.  A promote believed shipped
but still gated is a wave that measures the wrong defaults and reports back a
verdict about a configuration nobody ran.

So the claim is worth surfacing separately from the commit.  The row still says
UNLANDED; it now also says whether that commit is quietly contradicting itself,
and prints the line it found so the reader judges the sentence, not the tool's
opinion of it.  See LIMIT 4 -- this is a text match, and it is reported as a
QUESTION for exactly the reason LIMIT 2 gives.

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

4. CLAIMS-LANDED IS A TEXT MATCH, NOT A PROOF.  It reads the commit message and
   the lines the commit ADDS under `iterations/` (the prose the next session
   actually reads), and looks for a sentence asserting the work is on main, with
   same-line negations excluded so a rescue note saying "main is deliberately
   not pushed" does not trip it.  Both error directions are real: a claim
   phrased in words the pattern does not know is MISSED, and a sentence quoting
   or predicting a landing ("W4 clones the tree only after the promote lands")
   is a FALSE POSITIVE.  That is why the matched line is printed verbatim next
   to the row -- the reader judges the sentence.  Absence of the marker is NOT
   evidence that a commit made no claim.

   It also does not fire on the inverse and more common case: a report that
   claims a landing while the commit carrying that claim itself landed fine and
   only the CODE stayed behind.  Catching that needs a per-claim referent, which
   this does not have.

EXIT CODES
    0  scanned, nothing unlanded
    2  cannot certify (zero refs scanned, or `git` refused)
    3  unlanded work found
"""

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

DEFAULT_REMOTE = "origin"
DEFAULT_TRUNK = "main"

# A sentence asserting the work is already on the trunk.  Deliberately narrow:
# a missed claim costs one round (the plain UNLANDED row still prints), while a
# lamp that reddens every round is one nobody reads -- the failure the charter
# section 15 names outright.
_CLAIM_RE = re.compile(
    r"""(
          已\s*落\s*(地|入)?\s*(主干|trunk|main)   # "已落 main"
        | 落\s*(了)?\s*main\b                       # "promote 落 main"
        | 已\s*(推|合)\s*(送|入|进)?\s*(到|进)?\s*main\b
        | 已\s*在\s*(origin/)?main\s*上
        | landed\s+(on|in)\s+(origin/)?main
        | (is|are|was|were)\s+now\s+(on|in)\s+(origin/)?main
        | reached\s+(origin/)?main
        | merged\s+(in)?to\s+(origin/)?main
        | pushed\s+to\s+(origin/)?main
        )""",
    re.IGNORECASE | re.VERBOSE,
)

# Same-line disqualifiers.  Measured, not guessed: the first cut of this pattern
# ran at 1 true positive in 4 on the very commits that motivated the tool, and a
# lamp that reddens every round is one nobody reads (charter section 15).  The
# three false positives named the two shapes below, and both are now excluded.
_NEGATION_RE = re.compile(
    r"""(
        # (A) the sentence DENIES the landing
          未\s*落 | 没\s*(有\s*)?落 | 尚未 | 从未 | 不\s*推 | 未\s*推 | 别\s*推 | 不要\s*推
        | 不是 | 而不是 | 并非 | 並非
        | never\s+(on|in|reached|landed|pushed)
        | not\s+(yet\s+)?(pushed|landed|on|in|reach)
        | deliberately\s+not
        | before\s+the\s+push
        )""",
    re.IGNORECASE | re.VERBOSE,
)

# (B) the landing is a TEMPORAL or CONDITIONAL clause, not an assertion that it
# happened: "落 main 后还欠两件收尾" is a plan, "落 main 之前" is a deadline.
# Anchored to the claim itself rather than the whole line, because these
# particles are ordinary words everywhere else in the sentence.
_CLAUSE_TAIL_RE = re.compile(
    r"""^\s*(
          (之)?[后後前] | 时 | 之时 | 才 | 再 | 就 | 以后 | 以前
        | \s*(after|before|once|until|when)\b
        )""",
    re.IGNORECASE | re.VERBOSE,
)
_CLAUSE_HEAD_RE = re.compile(
    r"""(
          若 | 如果 | 一旦 | 等到? | 待 | 将要? | 即将 | 打算 | 应该 | 应当 | 须 | 必须
        # English modals/subordinators anywhere in the prefix, not end-anchored:
        # "Once the suite is green it WILL BE pushed to main" puts four words
        # between the modal and the claim.  Cost of the wider match is a missed
        # claim in a sentence that merely contains "will" -- LIMIT 4's stated
        # direction of error, and the plain UNLANDED row still prints.
        | \b(once|if|when|until|unless|after|before)\b
        | \b(will|would|shall|should|must|plan(s|ned)?\s+to|going\s+to|intend)\b
        # "全绿**再**落 main" / "...才落 main": a sequencing particle immediately
        # before the claim turns it into an instruction.  End-anchored, because
        # these characters are common words anywhere else in the sentence.
        | [再才就]\s*\**\s*$
        )""",
    re.IGNORECASE | re.VERBOSE,
)


def landing_claim(cwd, sha):
    """First line of this commit that ASSERTS the work is on the trunk, or None.

    Two sources, because the two readers differ: the commit message is what a
    triaging agent reads, and the lines added under `iterations/` (reports,
    charters, state) are what every FRESH session reads at startup.  The
    2026-08-24T01:xxZ loss put its false claim in the second one."""
    try:
        body = git(["show", "-s", "--format=%B", sha], cwd)
    except RuntimeError:
        body = ""
    try:
        # Added lines only: a commit is not responsible for prose it merely
        # carries past.  `-U0` keeps context lines out of the `+` set.
        diff = git(["show", "-U0", "--format=", sha, "--", "iterations/"], cwd)
    except RuntimeError:
        diff = ""

    lines = [ln.strip() for ln in body.splitlines()]
    lines += [
        ln[1:].strip()
        for ln in diff.splitlines()
        if ln.startswith("+") and not ln.startswith("+++")
    ]
    for ln in lines:
        if not ln:
            continue
        if _NEGATION_RE.search(ln):
            continue
        m = _CLAIM_RE.search(ln)
        if not m:
            continue
        if _CLAUSE_TAIL_RE.match(ln[m.end():]):
            continue          # "...落 main 后还欠两件收尾" -- a plan, not a report
        if _CLAUSE_HEAD_RE.search(ln[: m.start()]):
            continue          # "等 promote 落 main" -- a precondition
        return ln
    return None


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
            findings.append((when, sha[:7], ref, subject, landing_claim(cwd, sha)))

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

    claiming = [f for f in findings if f[4]]
    print("\nUNLANDED WORK (%d commit(s)) -- committed and pushed, never on %s:" % (len(findings), trunk_ref))
    # The count goes first and is printed even when it is zero, so "no commit
    # claims to have landed" and "the claim scan did not run" cannot look alike
    # -- the same anti-empty-match rule the denominators above follow.
    print("  of which CLAIMS-LANDED : %d (see LIMIT 4 -- text match, judge the quoted line)" % len(claiming))
    for when, short, ref, subject, claim in sorted(findings, reverse=True):
        flag = "  [CLAIMS-LANDED]" if claim else ""
        print("  %s  %s  %s%s" % (when.isoformat(timespec="seconds"), short, subject, flag))
        print("      on %s   ->  git cherry-pick %s" % (ref, short))
        if claim:
            said = claim if len(claim) <= 150 else claim[:147] + "..."
            print('      claims: "%s"' % said)
            print("      ^ this commit is UNLANDED while its own text says otherwise -- every")
            print("        fresh session reads that sentence, and the batch desk spends money")
            print("        on the tree at %s. Rescue this one FIRST." % trunk_ref)
    return 3


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # `... | head` closes the pipe early; without this the tool exits 1,
        # which is indistinguishable from "the scan failed".
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(2)
