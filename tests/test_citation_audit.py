#!/usr/bin/env python3
"""Acceptance for tools/agent/citation_audit.py.

Every case builds a REAL git repository (trunk + session branch + a real clone,
shallow where the case is about shallowness) and runs the real tool on it.  What
is being asserted is behaviour on git's own data -- tree lookups, ancestry,
graft points -- and a mock of git would be a mock of exactly the part that can
be wrong.  Same reasoning as tests/test_unlanded_commits.py and test_set.md 0b.

The load-bearing claims, one per shape GH #113 names:

  1. hero 08:00Z shape -- a cited report that exists on NO remote ref is
     MISSING (exit 3).  This is the shape `unlanded_commits.py` is structurally
     blind to: there is no branch to diff.
  2. hero 10:00Z / strategy 07:30Z shape -- a cited report that resolves only on
     a session branch is OFF-TRUNK (exit 3), naming the branch.
  3. a citation that resolves on the trunk is NOT reported (exit 0); without
     this the tool could be a constant "3" and still pass 1 and 2.
  4. anti-empty-match -- a source with zero citations exits 2, not 0.
  5. trap 2 -- an unanchored md5-shaped token is not audited as a commit, while
     an anchored missing one is.  Measured on the live repo: 41 hex tokens in a
     day's reports, 3 of them commits.
  6. trap 3 -- under a shallow clone an unresolvable hash is REFUSED, not
     reported.
  7. trap 1 -- a stale remote-tracking trunk REFUSES (exit 2) rather than
     inventing OFF-TRUNK findings.  Measured live 2026-08-22: origin/main read
     46d381d while the trunk tip was 84696ff.
  8. cadence -- a hole in a stream's report rhythm is a GAP; a stream on cadence
     is not; files that are not reports are counted as skipped, never silently
     dropped.

Cases 9-13 are GH #290 -- the middle box.  The 2026-08-28T22:03Z round closed an
issue with five citations for work that was committed locally and not yet pushed;
of the five, cases 1-8 could catch exactly one, because the other four were not
paths.  Each case below is one of the four, plus the two disciplines the ruling
comment attached to them:

  9.  `state.json:<key>` resolves against the parsed file at trunk, and a key
      that is not there is MISSING -- with the line saying off-trunk was not
      searched, so "clean" cannot be read as "looked everywhere".
  10. `<charter>.md §XX` resolves against `^#{1,6} §XX`; a section id that TWO
      headings claim is AMBIGUOUS, a third verdict.  Not hypothetical: §CA was
      written twice on 2026-08-29 by two concurrent director sessions.
  11. `GH #286 §4` sitting near a charter mention is an ISSUE section and must
      not be audited -- the false positive that would mute the whole leg.
  12. grace -- a citation from a comment younger than --comment-grace-hours is
      PENDING (printed, exit unaffected), because a comment posted seconds
      before `git push` is correct behaviour; no timestamp means no grace.
  13. a comment corpus older than --comments-max-age REFUSES (2).  A stale
      corpus says nothing about comments posted since, and per rule 10 a leg
      that did not run is not a pass.

Run:  python3 tests/test_citation_audit.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TOOL = os.path.join(REPO, "tools", "agent", "citation_audit.py")

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


def run(args, cwd):
    p = subprocess.run([sys.executable, TOOL] + args, cwd=cwd,
                       capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def git(args, cwd):
    subprocess.run(["git"] + args, cwd=cwd, check=True,
                   capture_output=True, text=True)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def make_origin(root):
    """A bare-ish origin with `main` plus a session branch carrying one report."""
    origin = os.path.join(root, "origin")
    os.makedirs(origin)
    git(["init", "-q", "-b", "main"], origin)
    git(["config", "user.email", "t@t"], origin)
    git(["config", "user.name", "t"], origin)
    write(os.path.join(origin, "iterations/reports/hero/20260822T060000Z.md"), "landed\n")
    # The middle box (GH #290): the two citation kinds that are CONTENT, not
    # paths.  `§CB` is written twice on purpose -- a section id two rulings both
    # claim is the shape measured live on 2026-08-29 (§CA, two director
    # sessions), and it is a third verdict, not a missing one.
    write(os.path.join(origin, "iterations/state.json"),
          json.dumps({"landed_key_20260822": {"status": "ok"}, "other": 1}) + "\n")
    write(os.path.join(origin, "iterations/streams/test_set.md"),
          "# test set\n\n## §BB landed ruling\ntext\n\n### §BB.4 sub\ntext\n\n"
          "## §CB first claimant\ntext\n\n## §CB second claimant\ntext\n")
    git(["add", "-A"], origin)
    git(["commit", "-qm", "landed report"], origin)
    git(["checkout", "-qb", "claude/session-x"], origin)
    write(os.path.join(origin, "iterations/reports/hero/20260822T100000Z.md"), "branch only\n")
    git(["add", "-A"], origin)
    git(["commit", "-qm", "branch-only report"], origin)
    branch_sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=origin,
                                capture_output=True, text=True).stdout.strip()
    git(["checkout", "-q", "main"], origin)
    return origin, branch_sha


def clone(root, origin, name, depth=None):
    """A shallow clone needs a `file://` source: git IGNORES --depth on a plain
    local path (it hardlinks the object store), so the naive form yields a full
    clone and case 6 would silently assert nothing."""
    dst = os.path.join(root, name)
    args = ["clone", "-q"]
    src = origin
    if depth:
        args += ["--depth", str(depth)]
        src = "file://" + os.path.abspath(origin)
    subprocess.run(["git"] + args + [src, dst], check=True,
                   capture_output=True, text=True)
    subprocess.run(["git", "fetch", "-q", "origin"], cwd=dst, check=True,
                   capture_output=True, text=True)
    return dst


def comments_file(root, name, bodies, created=None, fetched=None):
    """`created`/`fetched` are ISO strings; omitting them keeps the pre-#290
    shape (a bare list, no timestamps -> no grace, no staleness check)."""
    path = os.path.join(root, name)
    items = [{"body": b, "html_url": "https://gh/c/%d" % i}
             for i, b in enumerate(bodies)]
    if created:
        for it in items:
            it["created_at"] = created
    payload = items if fetched is None else {"fetched_at": fetched, "comments": items}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh)
    return path


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def main():
    root = tempfile.mkdtemp(prefix="citaudit-")
    try:
        origin, branch_sha = make_origin(root)
        work = clone(root, origin, "work")

        # 1. never pushed at all -- the shape unlanded_commits.py cannot see
        print("\ncase 1: cited report on no ref at all -> MISSING")
        cf = comments_file(root, "c1.json", [
            "done, see iterations/reports/hero/20260822T080000Z.md for the numbers"])
        code, out = run(["--repo", work, "--comments", cf], work)
        check(code == 3, "exit 3")
        check("MISSING" in out and "20260822T080000Z" in out, "names the missing report")
        check("gh/c/0" in out, "names the comment that cited it")

        # 2. pushed to a session branch, never landed
        print("\ncase 2: cited report only on a session branch -> OFF-TRUNK")
        cf = comments_file(root, "c2.json", [
            "rebuilt in iterations/reports/hero/20260822T100000Z.md"])
        code, out = run(["--repo", work, "--comments", cf], work)
        check(code == 3, "exit 3")
        check("OFF-TRUNK" in out, "classed OFF-TRUNK, not MISSING")
        check("session-x" in out, "names the branch it is stranded on")

        # 3. the tool is not a constant 3
        print("\ncase 3: cited report that is on the trunk -> clean")
        cf = comments_file(root, "c3.json", [
            "see iterations/reports/hero/20260822T060000Z.md"])
        code, out = run(["--repo", work, "--comments", cf], work)
        check(code == 0, "exit 0")
        check("clean" in out, "prints clean")
        check("paths cited 1" in out, "prints the denominator it checked")

        # 4. anti-empty-match
        print("\ncase 4: a source citing nothing -> refuse, not clean")
        cf = comments_file(root, "c4.json", ["looks good to me"])
        code, out = run(["--repo", work, "--comments", cf], work)
        check(code == 2, "exit 2, not 0")
        check("zero citations" in out, "says why it refused")

        # 5. hex that is not a commit
        print("\ncase 5: unanchored hex is not audited; anchored missing one is")
        md5 = "d41d8cd98f00b204e9800998ecf8427e"
        cf = comments_file(root, "c5.json", ["md5 %s, byte-identical" % md5])
        code, out = run(["--repo", work, "--comments", cf], work)
        check(code == 2, "unanchored-only source extracts nothing (exit 2)")
        check("of 1 hex tokens" in out, "the skipped token is still counted")
        cf = comments_file(root, "c5b.json", ["landed as commit deadbee1234 last round"])
        code, out = run(["--repo", work, "--comments", cf, "--fetch"], work)
        check(code == 3 and "deadbee1234" in out, "anchored unknown hash is reported")
        cf = comments_file(root, "c5c.json", ["md5 %s" % md5])
        code, out = run(["--repo", work, "--comments", cf, "--hash-mode", "all"], work)
        check(code == 3 and md5 in out, "--hash-mode all does audit it (opt-in)")

        # 6. shallow clone refuses instead of accusing
        print("\ncase 6: shallow clone -> REFUSED, not MISSING")
        shallow = clone(root, origin, "shallow", depth=1)
        cf = comments_file(root, "c6.json", ["commit deadbee1234 has it"])
        code, out = run(["--repo", shallow, "--comments", cf], shallow)
        check("shallow clone" in out, "says the clone is shallow")
        check("refused 1" in out, "counts the refusal")
        check("MISSING" not in out, "does not accuse under a shallow clone")
        check(code == 0, "a refusal alone is not a finding")

        # 7. stale trunk refuses
        print("\ncase 7: stale origin/main -> refuse (trap 1)")
        stale = clone(root, origin, "stale")
        write(os.path.join(origin, "iterations/reports/hero/20260822T140000Z.md"), "new\n")
        git(["add", "-A"], origin)
        git(["commit", "-qm", "newer trunk work"], origin)
        cf = comments_file(root, "c7.json", [
            "see iterations/reports/hero/20260822T140000Z.md"])
        code, out = run(["--repo", stale, "--comments", cf], stale)
        check(code == 2, "exit 2 rather than a manufactured finding")
        check("stale" in out and "--fetch" in out, "names the cause and the cure")
        code, out = run(["--repo", stale, "--comments", cf, "--fetch"], stale)
        check(code == 0, "--fetch converts the refusal into a clean answer")

        # 8. cadence
        print("\ncase 8: cadence gaps")
        cad = os.path.join(root, "cad")
        now = datetime.now(timezone.utc)
        for h in (1, 3, 5, 7):            # on cadence
            write(os.path.join(cad, "reports/steady",
                               (now - timedelta(hours=h)).strftime("%Y%m%dT%H%M%SZ") + ".md"), "x")
        for h in (1, 9, 11):              # a 8h hole
            write(os.path.join(cad, "reports/holey",
                               (now - timedelta(hours=h)).strftime("%Y%m%dT%H%M%SZ") + ".md"), "x")
        write(os.path.join(cad, "reports/holey", "efficiency_202634.md"), "not a report")
        code, out = run(["--repo", cad, "--cadence", "--reports-dir", "reports"], cad)
        check(code == 3, "exit 3 on a hole")
        check("GAP" in out and "holey" in out, "names the stream with the hole")
        check("steady" not in out.split("GAP")[1], "the on-cadence stream is not flagged")
        check("skipped 1" in out, "the non-report file is counted, not dropped")
        check("streams 2" in out, "prints the denominator")

        # ------------------------------------------------------------------
        # GH #290 -- the middle box: citations that are content, not paths.
        # Of the five citations the 2026-08-28T22:03Z close comment published,
        # cases 1-8 above could only ever have caught the one that was a path.
        # ------------------------------------------------------------------

        # 9. state.json:<key>
        print("\ncase 9: state.json:<key> -> resolved / MISSING")
        cf = commentsFile = comments_file(root, "c9.json", [
            "archived as `iterations/state.json:landed_key_20260822`"])
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 0, "a key that is on trunk is clean")
        check("state.json keys cited 1" in out, "prints the key denominator")
        cf = comments_file(root, "c9b.json", [
            "archived as `state.json:skilldrain_NILHEAD_20260828`"])
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 3, "exit 3 on a key that is not there")
        check("MISSING" in out and "skilldrain_NILHEAD_20260828" in out,
              "names the missing key")
        check("off-trunk refs not searched" in out,
              "states the boundary instead of implying it looked everywhere")

        # 10. <charter>.md §XX
        print("\ncase 10: charter section -> resolved / MISSING / AMBIGUOUS")
        cf = comments_file(root, "c10.json", ["full ruling in `test_set.md` §BB.4"])
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 0, "a section that is on trunk is clean")
        check("charter sections cited 1" in out, "prints the section denominator")
        cf = comments_file(root, "c10b.json", ["full ruling in `test_set.md` **§CZ**"])
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 3 and "§CZ" in out, "a section with no heading is MISSING")
        cf = comments_file(root, "c10c.json", ["see `test_set.md` §CB"])
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 3 and "AMBIGUOUS" in out,
              "a section id two headings claim is AMBIGUOUS, not MISSING")
        check("2 headings claim" in out, "says how many claimants")

        # 11. the §N that belongs to an issue, not to a charter.  Two guards,
        # and they are separable: the WINDOW (a § far from the filename is not
        # about that file) and the CHARSET (`§4` is an issue section wherever it
        # sits).  Asserting only 11a passes even with the charset widened to
        # accept digits -- measured, which is why 11b exists.
        print("\ncase 11a: a distant §N is not bound to the charter mention")
        cf = comments_file(root, "c11.json", [
            "`test_set.md` §BB.4 records it; the recipe is GH #286 §4 item 1, "
            "and #290 §3 is the connected damage"])
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 0, "the distant issue sections are not audited")
        check("charter sections cited 1" in out, "only the near charter one counted")

        print("\ncase 11b: `§4` right beside the charter mention is still an issue section")
        cf = comments_file(root, "c11b.json", [
            "the ruling is in `test_set.md`, GH #286 §4 item 1 -- see also "
            "iterations/reports/hero/20260822T060000Z.md"])
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check("charter sections cited 0" in out,
              "a digit-led section id is never a charter citation")
        check(code == 0, "and the source is not reported")

        # 12. grace -- a comment posted seconds before the push is not red
        print("\ncase 12: grace window")
        now = datetime.now(timezone.utc)
        body = ["landed in iterations/reports/hero/20260822T080000Z.md"]
        cf = comments_file(root, "c12.json", body, created=iso(now - timedelta(minutes=5)))
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 0, "inside grace: not a finding")
        check("PENDING" in out, "but it is printed, not swallowed")
        cf = comments_file(root, "c12b.json", body, created=iso(now - timedelta(hours=4)))
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 3, "past grace: a finding")
        cf = comments_file(root, "c12c.json", body)          # no created_at
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 3, "no timestamp -> no grace (fail toward asking)")
        cf = comments_file(root, "c12d.json", body, created=iso(now - timedelta(minutes=5)))
        code, out = run(["--repo", work, "--fetch", "--comments", cf, "--comment-grace-hours", "0"], work)
        check(code == 3, "--comment-grace-hours 0 disables it")

        # 13. a stale corpus certifies nothing
        print("\ncase 13: --comments-max-age")
        good = ["see iterations/reports/hero/20260822T060000Z.md"]
        cf = comments_file(root, "c13.json", good, fetched=iso(now - timedelta(minutes=10)))
        code, out = run(["--repo", work, "--fetch", "--comments", cf, "--comments-max-age", "6"], work)
        check(code == 0, "a fresh corpus audits normally")
        cf = comments_file(root, "c13b.json", good, fetched=iso(now - timedelta(hours=30)))
        code, out = run(["--repo", work, "--fetch", "--comments", cf, "--comments-max-age", "6"], work)
        check(code == 2, "a stale corpus refuses (2), it does not pass")
        check("30." in out and "Refresh" in out, "prints the age and the cure")
        cf = comments_file(root, "c13c.json", good)          # bare list, no fetched_at
        code, out = run(["--repo", work, "--fetch", "--comments", cf, "--comments-max-age", "6"], work)
        check(code == 2, "an undated corpus refuses too")
        code, out = run(["--repo", work, "--fetch", "--comments", cf], work)
        check(code == 0, "...but only when --comments-max-age asked for the check")

    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("\n%d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  - %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
