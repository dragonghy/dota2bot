#!/usr/bin/env python3
"""Acceptance for tools/agent/unlanded_commits.py.

Every case builds a REAL git repository and runs the real tool on it -- the
thing being asserted is behaviour on git's own data structures (patch-ids,
graft points, merge-bases), and a mock of git would be a mock of exactly the
part that has the bug.  Same reasoning the Lua side records in test_set.md
section 0b: a fixture that stubs the mechanism under test proves nothing.

The four load-bearing claims:
  1. a genuinely unlanded commit is REPORTED (exit 3, named, with its ref)
  2. a REBASE TWIN -- same patch, different SHA -- is NOT reported (exit 0);
     SHA identity would have called it lost
  3. a SHALLOW clone REFUSES below the graft point instead of reporting the
     ~100 pre-boundary commits a naive scan invents
  4. a scan with ZERO refs exits non-zero; "matched nothing" must not read as
     "nothing is wrong" (the empty-match trap this repo has hit six times)

Run:  python3 tests/test_unlanded_commits.py
"""

import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TOOL = os.path.join(REPO, "tools", "agent", "unlanded_commits.py")

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
    p = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError("git %s -> %s" % (" ".join(args), p.stderr.strip()))
    return p.stdout


def run_tool(repo, *extra):
    p = subprocess.run(
        [sys.executable, TOOL, "--repo", repo] + list(extra),
        capture_output=True,
        text=True,
    )
    return p.returncode, p.stdout + p.stderr


def commit(repo, path, text, msg):
    with open(os.path.join(repo, path), "w") as fh:
        fh.write(text)
    git(["add", "-A"], repo)
    git(["commit", "-m", msg], repo)
    return git(["rev-parse", "HEAD"], repo).strip()


def new_origin(tmp):
    """An 'origin' clone with a main branch plus a session branch, wired so the
    tool sees refs/remotes/origin/* exactly as an agent container does."""
    upstream = os.path.join(tmp, "upstream")
    os.makedirs(upstream)
    git(["init", "-q", "-b", "main"], upstream)
    git(["config", "user.email", "t@t"], upstream)
    git(["config", "user.name", "t"], upstream)
    commit(upstream, "base.txt", "base\n", "base commit")
    return upstream


def clone(tmp, upstream, name, depth=None):
    work = os.path.join(tmp, name)
    args = ["clone", "-q"]
    if depth:
        args += ["--depth", str(depth)]
    args += ["file://" + upstream, work]
    git(args, tmp)
    git(["config", "user.email", "t@t"], work)
    git(["config", "user.name", "t"], work)
    return work


# ---------------------------------------------------------------- case 1 + 2
print("case 1/2: a real orphan is reported, its rebase twin is not")
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)

    # A session branch carrying work that never reached main.
    git(["checkout", "-q", "-b", "claude/lost-session"], up)
    commit(up, "lost.txt", "work that never landed\n", "director 01:00Z: the lost work unit")

    # A second session branch whose patch DID land on main, but under a
    # different SHA (the rebase twin).
    git(["checkout", "-q", "main"], up)
    git(["checkout", "-q", "-b", "claude/rebased-session"], up)
    commit(up, "landed.txt", "work that did land\n", "strategy 22:33Z: the landed work unit")
    git(["checkout", "-q", "main"], up)
    # An INTERVENING commit first.  Without it, cherry-picking a commit whose
    # parent is already HEAD reproduces byte-identical metadata and therefore the
    # SAME sha -- there is no twin, and the "sha identity would have been wrong"
    # claim is vacuous.  The first draft of this test did exactly that, and
    # mutation M1 (swap `git cherry` for `rev-list trunk..ref`) walked straight
    # past it.  The intervening commit changes the parent, so the twin gets a
    # different sha and the same patch-id -- which is the whole point.
    commit(up, "intervening.txt", "unrelated\n", "hero: an unrelated main commit")
    git(["cherry-pick", "claude/rebased-session"], up)

    work = clone(tmp, up, "work")
    code, out = run_tool(work, "--days", "3650")

    check(code == 3, "exit 3 when unlanded work exists (got %d)" % code)
    check("the lost work unit" in out, "the genuinely-lost commit is named")
    check("claude/lost-session" in out, "the branch holding it is named")
    # prove the twin really is a twin before asserting anything about it
    twin_branch = git(["rev-parse", "origin/claude/rebased-session"], work).strip()
    twin_main = git(["rev-parse", "origin/main"], work).strip()
    check(twin_branch != twin_main, "the twin has a DIFFERENT sha (else the case is vacuous)")
    check(
        git(["rev-list", "origin/main..origin/claude/rebased-session"], work).strip() != "",
        "sha-identity WOULD have called the twin lost (so M1 has something to kill)",
    )
    check(
        "the landed work unit" not in out,
        "the REBASE TWIN is not reported (patch-id, not sha, is the equivalence)",
    )
    check("git cherry-pick" in out, "output hands over a runnable recovery command")

    # denominator, always
    check("refs scanned" in out and "commits examined" in out, "denominator printed")
    check("shallow clone    : no" in out, "a full clone says so")

# ---------------------------------------------------------------- case 3
print("case 3: a shallow clone refuses below the graft point")
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)
    # deep-ish history on main, so a depth-1 clone truncates most of it
    for i in range(6):
        commit(up, "m%d.txt" % i, "m%d\n" % i, "main commit %d" % i)
    # an OLD side branch forked from the first commit -- below any shallow graft
    first = git(["rev-list", "--max-parents=0", "main"], up).split()[0]
    git(["checkout", "-q", "-b", "claude/ancient", first], up)
    commit(up, "ancient.txt", "old\n", "ancient side work")
    git(["checkout", "-q", "main"], up)

    shallow = clone(tmp, up, "shallow", depth=1)
    # bring the side branch's tip in without deepening main
    git(["fetch", "-q", "--depth", "1", "origin", "claude/ancient:refs/remotes/origin/claude/ancient"], shallow)

    code, out = run_tool(shallow, "--days", "3650")
    check("shallow clone    : YES" in out, "shallowness is announced, not inferred")
    check("REFUSED" in out, "the tool refuses out loud rather than reporting silently")
    check(
        code in (0, 2),
        "a shallow scan does not manufacture an orphan below the graft (exit %d)" % code,
    )
    check("UNLANDED WORK" not in out, "the pre-boundary commit is NOT invented as unlanded work")
    check(
        "REFUSED refs" in out and "certifiable refs" in out,
        "the refusal is COUNTED against a denominator, not just mentioned "
        "(refused-N must never read as checked-N)",
    )

# ---------------------------------------------------------------- case 4
print("case 4: zero refs is not a clean tree")
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)
    work = clone(tmp, up, "work")
    # Strip every remote ref except the trunk itself.  --no-deref matters:
    # refs/remotes/origin/HEAD is a symref, and deleting it WITHOUT --no-deref
    # deletes what it points at -- i.e. main.  (That accident is how the
    # unreadable-trunk path below got found in the first place.)
    for ref in git(["for-each-ref", "--format=%(refname)", "refs/remotes/origin"], work).split():
        if ref.endswith("/main"):
            continue
        git(["update-ref", "--no-deref", "-d", ref], work)
    code, out = run_tool(work, "--days", "3650")
    check(code == 2, "exit 2 (CANNOT CERTIFY) when zero refs were scanned (got %d)" % code)
    check("An empty scan is not a clean tree" in out, "the empty scan says why it cannot certify")
    check("OK: no unlanded work" not in out, "a zero-ref scan never claims a clean tree")

# ---------------------------------------------------------------- case 7
print("case 7: an unreadable trunk is CANNOT CERTIFY, not a crash")
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)
    work = clone(tmp, up, "work")
    git(["checkout", "-q", "-b", "solo"], work)
    git(["update-ref", "--no-deref", "-d", "refs/remotes/origin/main"], work)
    code, out = run_tool(work, "--days", "3650")
    check(code == 2, "exit 2 when the trunk ref cannot be read (got %d)" % code)
    check("CANNOT CERTIFY" in out, "it says CANNOT CERTIFY in its own vocabulary")
    check("Traceback" not in out, "no python traceback -- exit 1 reads as a shell failure, not a verdict")

# ---------------------------------------------------------------- case 5
print("case 5: a genuinely clean tree reports clean, with its denominator")
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)
    git(["checkout", "-q", "-b", "claude/merged-session"], up)
    commit(up, "ok.txt", "landed\n", "hero 00:00Z: landed work")
    git(["checkout", "-q", "main"], up)
    git(["merge", "-q", "--ff-only", "claude/merged-session"], up)

    work = clone(tmp, up, "work")
    code, out = run_tool(work, "--days", "3650")
    check(code == 0, "exit 0 on a clean tree (got %d)" % code)
    check("OK: no unlanded work" in out, "clean tree says so explicitly")
    check("refs scanned     : 1" in out, "clean result carries a NON-ZERO denominator")

# ---------------------------------------------------------------- case 6
print("case 6: the age cutoff is real (old orphans are out of the window)")
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)
    git(["checkout", "-q", "-b", "claude/lost-session"], up)
    commit(up, "lost.txt", "old orphan\n", "director: an old orphan")
    git(["checkout", "-q", "main"], up)
    work = clone(tmp, up, "work")

    code_wide, out_wide = run_tool(work, "--days", "3650")
    code_narrow, out_narrow = run_tool(work, "--days", "0")
    check(code_wide == 3, "inside the window: reported")
    check(code_narrow == 0, "outside the window: not reported (exit %d)" % code_narrow)
    check(
        "commits examined : 1" in out_narrow,
        "even when filtered out, the commit is COUNTED -- the denominator does not "
        "shrink to match the finding",
    )


# ---------------------------------------------------------------- case 7
# Regression corpus for CLAIMS-LANDED.  The first cut of the pattern ran at 1
# true positive in 4 on the real commits of 2026-08-24, so the sentences below
# are TRANSCRIBED from those commits rather than invented -- an invented corpus
# would have agreed with the broken pattern.
print("case 7: CLAIMS-LANDED separates an assertion from a plan, a denial and a condition")
CLAIM_CASES = [
    # (label, sentence, should_flag)
    ("assertion, the 2026-08-24T03:11Z loss verbatim",
     "\u21d2 \u00a78.5 \u90a3\u9053\u95e8**\u8fc7\u4e86**\uff0cpromote \u843d main\u3002", True),
    ("assertion, charter status line",
     "\u5168\u91cf\u5957\u4ef6 1658 tests / 0 failures \u21d2 promote \u5df2\u843d main\u3002", True),
    ("assertion, english",
     "The promote landed on main as stable-v2.", True),
    ("DENIAL -- the rescue note of 23:16Z, which must stay clean",
     "main is deliberately not pushed until the full suite closes", False),
    ("DENIAL -- chinese, 'the right move is NOT to cherry-pick onto main'",
     "**\u21d2 \u62a2\u6551\u7684\u6b63\u786e\u505a\u6cd5\u4e0d\u662f\u76f4\u63a5 cherry-pick \u843d main\uff0c\u662f\u5148\u8865\u4e0a\u90a3\u9053\u95e8**", False),
    ("SEQUENCING -- 'all green, THEN land on main'",
     "\u5728\u8fd9\u4efd\u6811\u4e0a\u8dd1\u5b8c `lua5.1 tests/run_tests.lua`\uff0c**\u5168\u7eff\u518d\u843d main**\uff1b", False),
    ("TEMPORAL TAIL -- 'AFTER landing on main, two things remain'",
     "\u843d main \u540e\u8fd8\u6b20**\u4e24\u4ef6\u6536\u5c3e**\uff1a(i) `git push origin HEAD:stable-v2`", False),
    ("CONDITIONAL HEAD -- english",
     "Once the suite is green it will be pushed to main.", False),
    # Found by dogfooding: the commit that ADDED this feature tripped its own
    # flag, because explaining the incident means quoting the false sentence.
    # Every commit documenting a false landing claim contains one.
    ("QUOTED -- a commit REPORTING the false claim, not making it",
     'The round wrote "promote already landed on main" into the charter.', False),
    ("QUOTED -- CJK brackets, the same shape",
     "\u8ffd\u8bc4\u300c\u5df2\u843d main\uff0c`stable-v2`\uff0csha\u300d\u3002", False),
    # The copula: the landing is the SUBJECT of a statement about WHEN, which is
    # how both surviving false positives were phrased.
    ("COPULA -- 'the landing on main IS this round', a statement about timing",
     "\u5b83 00:09:32Z \u53d1\u6ce2\uff0c\u800c promote \u843d main \u662f **01:xxZ**", False),
]
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)
    git(["checkout", "-q", "-b", "claude/claimer"], up)
    os.makedirs(os.path.join(up, "iterations"), exist_ok=True)
    shas = []
    for i, (label, sentence, want) in enumerate(CLAIM_CASES):
        # Put the sentence in a report under iterations/, NOT in the commit
        # subject: the 2026-08-24 loss put its false claim in the prose every
        # fresh session reads at startup, which is the harder source to reach.
        shas.append(commit(up, "iterations/r%d.md" % i, sentence + "\n", "director: case %d" % i))
    git(["checkout", "-q", "main"], up)
    work = clone(tmp, up, "claimwork")
    code, out = run_tool(work, "--days", "3650")
    check(code == 3, "the claim corpus is unlanded work (exit %d)" % code)
    for (label, sentence, want), sha in zip(CLAIM_CASES, shas):
        short = sha[:7]
        row = [ln for ln in out.splitlines() if short in ln and "cherry-pick" not in ln]
        flagged = bool(row) and "[CLAIMS-LANDED]" in row[0]
        check(bool(row), "case is reported at all: %s" % label)
        check(flagged == want,
              "%s -> %s (got %s)" % (label, "FLAG" if want else "clean",
                                     "FLAG" if flagged else "clean"))
    want_n = sum(1 for _, _, w in CLAIM_CASES if w)
    check("of which CLAIMS-LANDED : %d" % want_n in out,
          "the CLAIMS-LANDED count is printed and equals %d" % want_n)
    check('claims: "' in out,
          "the matched sentence is QUOTED, so the reader judges the line and not the tool")

# ---------------------------------------------------------------- case 8
print("case 8: the CLAIMS-LANDED count prints even at zero (anti-empty-match)")
with tempfile.TemporaryDirectory() as tmp:
    up = new_origin(tmp)
    git(["checkout", "-q", "-b", "claude/quiet"], up)
    commit(up, "quiet.txt", "no prose at all\n", "strategy: a work unit that claims nothing")
    git(["checkout", "-q", "main"], up)
    work = clone(tmp, up, "quietwork")
    code, out = run_tool(work, "--days", "3650")
    check(code == 3, "still reports the unlanded commit (exit %d)" % code)
    check("of which CLAIMS-LANDED : 0" in out,
          "zero claims is PRINTED as zero -- 'no claim' and 'the scan did not run' "
          "must not look alike")
    check("[CLAIMS-LANDED]" not in out, "and no row is flagged")

print("\n%d checks, %d failed" % (checks, len(failures)))
if failures:
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
