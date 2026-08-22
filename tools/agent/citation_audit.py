#!/usr/bin/env python3
"""Audit the citations an agent publishes: every path or commit it names must resolve.

WHY THIS EXISTS
---------------
GH #113 (hero, 2026-08-22T12:00Z).  Of ~27 routine triggers that day, THREE
produced work that never reached `main`, in three different shapes:

    hero 08:00Z      conclusions posted to GH #104 (comment 5379290390), not a
                     single line pushed -- not even to a session branch
    hero 10:00Z      rebuilt, committed `e940d31`, pushed to a session branch,
                     never landed on main
    strategy 07:30Z  954 lines incl. a `bots/FunLib/jmz_func.lua` behaviour
                     change, session branch only

`tools/agent/unlanded_commits.py` (2026-08-22T03:00Z) sees the second and third:
it diffs remote refs against the trunk.  It is STRUCTURALLY BLIND to the first --
there is no branch to diff.  For ~1.5h a published record claimed the harness was
fixed while it was not, and the next reader would have built on a correction that
did not exist.

This tool closes that hole with the check #113 proposed, which needs nothing but
the comment text and `git`:

    Every report path and commit hash an agent cites must resolve on some remote
    ref.  A citation that resolves nowhere means the work was never pushed; one
    that resolves only off-trunk means it was pushed to the wrong place.

"Was it pushed" and "was it pushed to the right place" become the same question,
and all three of the day's shapes land in it.

WHAT IT DOES NOT DO
-------------------
It audits what an agent SAID IT DID.  Work that was silently not done and also
never mentioned is invisible to it -- the same honest boundary
`unlanded_commits.py` states about work that was never pushed.  The complement
is `--cadence`, which needs no input at all: every stream files a report every
2h, so a hole in `iterations/reports/<stream>/` is a lost trigger.  Cadence
catches the round that vanished without a word; citations catch the round that
spoke without landing.  Neither subsumes the other; run both.

THREE TRAPS THIS TOOL IS BUILT AROUND
-------------------------------------
1. THE STALE `origin/main`.  Measured on a live agent container 2026-08-22: the
   remote-tracking ref read `46d381d` while the real trunk tip was `84696ff`,
   about a hundred commits later.  The hero group nearly published a wrong A/B
   off a worktree cut from that ref.  A citation audit against a stale trunk
   invents OFF-TRUNK findings for work that landed hours ago, so the trunk is
   compared against `git ls-remote` and a stale one REFUSES (exit 2) instead of
   reporting.  `--fetch` fixes it in place.

2. THE HEX THAT IS NOT A COMMIT.  Reports are full of md5 sums, S3 keys and
   run-id fragments that match `[0-9a-f]{7,40}` perfectly.  Reporting those as
   lost commits would bury the real finding, so by default a hash is only
   audited when it is ANCHORED -- named as a commit by a nearby git word
   (commit/tree/sha/rebase/HEAD/提交/树).  Both counts are always printed, so
   "anchored 3 of 41 hex tokens" can never be read as "there were 3".

3. THE SHALLOW CLONE.  Agent containers clone shallow.  Under a shallow clone an
   unresolvable SHA means "not in this clone", which is NOT the same claim as
   "does not exist" -- so it is REFUSED and counted, never reported as a finding.
   `git fetch --unshallow` converts refusals into answers.  (Same refusal-not-
   filter discipline as `unlanded_commits.py` trap 1.)

ANTI-EMPTY-MATCH
----------------
"No bad citations" and "the regex matched nothing" print identically unless the
denominator is shown -- the failure this repo has now hit in #29, #31, #34, #37,
#95, #103.  So every run prints sources / citations extracted / resolved, and a
run that extracted ZERO citations exits 2 rather than reporting a clean bill.

FINDING CLASSES
    MISSING    cited path/commit resolves on no remote ref  -> never pushed
    OFF-TRUNK  resolves only on a non-trunk remote ref      -> pushed, not landed
    REFUSED    unresolvable under a shallow clone           -> uncertifiable
    GAP        a hole in a stream's report cadence          -> lost trigger

EXIT CODES
    0  audited, everything resolves
    2  cannot certify (no citations extracted, stale trunk, git refused)
    3  findings
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

DEFAULT_REMOTE = "origin"
DEFAULT_TRUNK = "main"

# First path segment must be one of these; without the whitelist the extractor
# happily "finds" paths inside URLs, log lines and prose.
REPO_ROOTS = ("iterations", "tools", "tests", "bots", "game", "docs", ".github")

PATH_RE = re.compile(
    r"(?<![\w/.-])((?:%s)(?:/[\w.+-]+)+\.(?:md|lua|py|sh|json|txt|yml|yaml))"
    % "|".join(re.escape(r) for r in REPO_ROOTS)
)
HEX_RE = re.compile(r"(?<![\w])([0-9a-f]{7,40})(?![\w])")
# A hash is audited only if one of these appears within ANCHOR_WINDOW characters
# before it.  Chinese forms included: the team writes reports in both languages.
ANCHOR_WORDS = (
    "commit", "commits", "sha", "tree", "rebase", "cherry", "head", "revision",
    "提交", "树", "版本",
)
ANCHOR_WINDOW = 60
REPORT_NAME_RE = re.compile(r"^(\d{8}T\d{6}Z)\.md$")


def git(args, cwd, check=True):
    p = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True)
    if check and p.returncode != 0:
        raise RuntimeError("git %s failed: %s" % (" ".join(args), p.stderr.strip()))
    return p.stdout


def git_ok(args, cwd):
    return subprocess.run(
        ["git"] + args, cwd=cwd, capture_output=True, text=True
    ).returncode == 0


def is_shallow(cwd):
    return git(["rev-parse", "--is-shallow-repository"], cwd).strip() == "true"


def remote_refs(cwd, remote, trunk_ref):
    """Remote-tracking refs, trunk and the symbolic HEAD alias excluded.

    Filtering on the SHORT name would let `refs/remotes/origin/HEAD` through as
    plain `origin` and count the trunk twice under an alias -- the bug
    `unlanded_commits.py` records in its own `remote_refs`."""
    out = git(
        ["for-each-ref", "--format=%(refname)%09%(refname:short)%09%(symref)",
         "refs/remotes/%s" % remote],
        cwd,
    )
    refs = []
    for line in out.splitlines():
        parts = line.split("\t")
        full, short = parts[0], parts[1]
        symref = parts[2] if len(parts) > 2 else ""
        if full.endswith("/HEAD") or symref or short == trunk_ref:
            continue
        refs.append(short)
    return refs


def trunk_is_stale(cwd, remote, trunk, trunk_ref):
    """(stale, local, remote) -- an unfetchable remote answers (False, ...).

    Trap 1: auditing against a stale trunk manufactures OFF-TRUNK findings for
    work that landed hours ago.  A remote we cannot reach is a different
    condition from a trunk we know is behind; only the latter refuses."""
    try:
        out = git(["ls-remote", remote, "refs/heads/%s" % trunk], cwd)
    except RuntimeError:
        return False, None, None
    remote_sha = out.split()[0] if out.split() else None
    try:
        local_sha = git(["rev-parse", trunk_ref], cwd).strip()
    except RuntimeError:
        return False, None, remote_sha
    if not remote_sha:
        return False, local_sha, None
    return (local_sha != remote_sha), local_sha, remote_sha


def anchored(text, start):
    window = text[max(0, start - ANCHOR_WINDOW):start].lower()
    return any(w in window for w in ANCHOR_WORDS)


def extract(text, hash_mode):
    """-> (paths, hashes, hex_seen).  `hex_seen` is the denominator for trap 2."""
    paths = []
    for m in PATH_RE.finditer(text):
        # A path inside a URL is someone else's tree, not a claim about ours.
        head = text[max(0, m.start() - 8):m.start()]
        if "://" in head or head.endswith("com/") or head.endswith("blob/"):
            continue
        paths.append(m.group(1))
    hashes = []
    hex_seen = 0
    for m in HEX_RE.finditer(text):
        tok = m.group(1)
        if tok.isdigit():          # a bare number, not a hash
            continue
        hex_seen += 1
        if hash_mode == "anchored" and not anchored(text, m.start()):
            continue
        hashes.append(tok)
    return paths, hashes, hex_seen


def load_sources(comment_files, text_files):
    """-> [(label, text)].  Comment JSON accepts either a bare list or the
    GitHub-ish {"comments": [...]} envelope; each item needs a `body`."""
    sources = []
    for path in comment_files:
        raw = sys.stdin.read() if path == "-" else open(path, encoding="utf-8").read()
        data = json.loads(raw)
        if isinstance(data, dict):
            data = data.get("comments", data.get("items", []))
        for i, item in enumerate(data):
            if isinstance(item, str):
                body, label = item, "%s#%d" % (path, i)
            else:
                body = item.get("body") or ""
                label = item.get("html_url") or item.get("url") or "%s#%d" % (path, i)
            if body:
                sources.append((label, body))
    for path in text_files:
        sources.append((path, open(path, encoding="utf-8").read()))
    return sources


def resolve_path(cwd, path, trunk_ref, refs):
    if git_ok(["cat-file", "-e", "%s:%s" % (trunk_ref, path)], cwd):
        return "OK", trunk_ref
    for ref in refs:
        if git_ok(["cat-file", "-e", "%s:%s" % (ref, path)], cwd):
            return "OFF-TRUNK", ref
    return "MISSING", None


def resolve_hash(cwd, sha, trunk_ref, refs, shallow):
    if not git_ok(["cat-file", "-e", "%s^{commit}" % sha], cwd):
        # Under a shallow clone "not here" is not "not anywhere" (trap 3).
        return ("REFUSED" if shallow else "MISSING"), None
    if git_ok(["merge-base", "--is-ancestor", sha, trunk_ref], cwd):
        return "OK", trunk_ref
    for ref in refs:
        if git_ok(["merge-base", "--is-ancestor", sha, ref], cwd):
            return "OFF-TRUNK", ref
    return "MISSING", None


def audit_citations(cwd, sources, trunk_ref, refs, shallow, hash_mode):
    findings, counts = [], {"paths": 0, "hashes": 0, "hex_seen": 0, "ok": 0, "refused": 0}
    seen = set()
    for label, text in sources:
        paths, hashes, hex_seen = extract(text, hash_mode)
        counts["hex_seen"] += hex_seen
        for p in paths:
            counts["paths"] += 1
            key = ("path", p)
            if key in seen:
                continue
            seen.add(key)
            verdict, where = resolve_path(cwd, p, trunk_ref, refs)
            if verdict == "OK":
                counts["ok"] += 1
            else:
                findings.append((verdict, "path", p, label, where))
        for h in hashes:
            counts["hashes"] += 1
            key = ("hash", h)
            if key in seen:
                continue
            seen.add(key)
            verdict, where = resolve_hash(cwd, h, trunk_ref, refs, shallow)
            if verdict == "OK":
                counts["ok"] += 1
            elif verdict == "REFUSED":
                counts["refused"] += 1
            else:
                findings.append((verdict, "commit", h, label, where))
    return findings, counts


def audit_cadence(cwd, reports_dir, cadence_h, tolerance, window_h):
    """A hole in a stream's report rhythm is a trigger that produced nothing.

    Costs nothing and needs no input -- it is the half of #113 that sees the
    round which vanished without publishing anything at all."""
    findings, counts = [], {"streams": 0, "reports": 0, "skipped": 0}
    root = os.path.join(cwd, reports_dir)
    if not os.path.isdir(root):
        return findings, counts, "no such directory: %s" % reports_dir
    now = datetime.now(timezone.utc)
    horizon = now - timedelta(hours=window_h)
    for stream in sorted(os.listdir(root)):
        sdir = os.path.join(root, stream)
        if not os.path.isdir(sdir):
            continue
        stamps = []
        for name in sorted(os.listdir(sdir)):
            m = REPORT_NAME_RE.match(name)
            if not m:
                counts["skipped"] += 1     # named, never silently dropped
                continue
            stamps.append(datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ")
                          .replace(tzinfo=timezone.utc))
        if not stamps:
            continue
        counts["streams"] += 1
        stamps.sort()
        counts["reports"] += len(stamps)
        recent = [s for s in stamps if s >= horizon]
        prior = [s for s in stamps if s < horizon]
        chain = ([prior[-1]] if prior else []) + recent
        for a, b in zip(chain, chain[1:]):
            gap = (b - a).total_seconds() / 3600.0
            if gap > cadence_h * tolerance:
                findings.append(("GAP", "cadence", stream,
                                 "%s -> %s" % (a.strftime("%m-%dT%H:%MZ"),
                                               b.strftime("%m-%dT%H:%MZ")),
                                 "%.1fh" % gap))
        if chain:
            trailing = (now - chain[-1]).total_seconds() / 3600.0
            if trailing > cadence_h * tolerance:
                findings.append(("GAP", "cadence", stream,
                                 "%s -> now" % chain[-1].strftime("%m-%dT%H:%MZ"),
                                 "%.1fh" % trailing))
    return findings, counts, None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--repo", default=".")
    ap.add_argument("--remote", default=DEFAULT_REMOTE)
    ap.add_argument("--trunk", default=DEFAULT_TRUNK)
    ap.add_argument("--comments", action="append", default=[],
                    help="JSON of GitHub comments (list, or {comments:[...]}); "
                         "'-' reads stdin.  Repeatable.")
    ap.add_argument("--text", action="append", default=[],
                    help="plain text/markdown file to audit citations in.  Repeatable.")
    ap.add_argument("--cadence", action="store_true",
                    help="also audit report cadence under iterations/reports/")
    ap.add_argument("--reports-dir", default="iterations/reports")
    ap.add_argument("--cadence-hours", type=float, default=2.0)
    ap.add_argument("--cadence-tolerance", type=float, default=1.75,
                    help="flag a gap wider than cadence*tolerance (default 1.75, "
                         "i.e. 3.5h on a 2h cadence -- one whole missed slot plus "
                         "the drift a trigger is allowed)")
    ap.add_argument("--cadence-window", type=float, default=24.0,
                    help="only audit the last N hours of cadence (default 24)")
    ap.add_argument("--hash-mode", choices=("anchored", "all"), default="anchored",
                    help="'anchored' (default) audits a hex token only when a git "
                         "word names it as a commit; 'all' audits every hex token "
                         "and will report md5 sums and S3 keys")
    ap.add_argument("--fetch", action="store_true",
                    help="fetch the remote first; without it a stale trunk refuses")
    args = ap.parse_args(argv)

    cwd = args.repo
    trunk_ref = "%s/%s" % (args.remote, args.trunk)

    if args.fetch:
        try:
            git(["fetch", args.remote], cwd)
        except RuntimeError as exc:
            print("WARN  fetch failed, auditing refs already in this clone: %s" % exc)

    if not (args.comments or args.text or args.cadence):
        print("REFUSE  nothing to audit: pass --comments/--text and/or --cadence")
        return 2

    findings = []
    exit_code = 0

    if args.comments or args.text:
        stale, local_sha, remote_sha = trunk_is_stale(cwd, args.remote, args.trunk, trunk_ref)
        if stale:
            print("REFUSE  %s is stale (%s) while the remote is at %s -- a citation "
                  "audit against a stale trunk invents OFF-TRUNK findings.  Re-run "
                  "with --fetch." % (trunk_ref, (local_sha or "?")[:8], (remote_sha or "?")[:8]))
            return 2
        try:
            sources = load_sources(args.comments, args.text)
        except (OSError, ValueError) as exc:
            print("REFUSE  cannot read citation sources: %s" % exc)
            return 2
        try:
            refs = remote_refs(cwd, args.remote, trunk_ref)
            shallow = is_shallow(cwd)
        except RuntimeError as exc:
            print("REFUSE  git: %s" % exc)
            return 2
        f, counts = audit_citations(cwd, sources, trunk_ref, refs, shallow, args.hash_mode)
        findings += f
        print("CITATIONS  sources %d  refs %d  trunk %s%s" %
              (len(sources), len(refs) + 1, trunk_ref, "  (shallow clone)" if shallow else ""))
        print("           paths cited %d  hashes audited %d of %d hex tokens (%s)  "
              "resolved on trunk %d  refused %d" %
              (counts["paths"], counts["hashes"], counts["hex_seen"], args.hash_mode,
               counts["ok"], counts["refused"]))
        if counts["paths"] + counts["hashes"] == 0:
            # Anti-empty-match: an empty scan must not print as a clean bill.
            print("REFUSE  zero citations extracted from %d source(s) -- 'nothing bad' "
                  "and 'nothing matched' are the same output, so this refuses."
                  % len(sources))
            return 2

    if args.cadence:
        f, counts, err = audit_cadence(cwd, args.reports_dir, args.cadence_hours,
                                       args.cadence_tolerance, args.cadence_window)
        if err:
            print("REFUSE  cadence: %s" % err)
            return 2
        findings += f
        print("CADENCE    streams %d  reports %d  non-report files skipped %d  "
              "window %.0fh  flag > %.1fh" %
              (counts["streams"], counts["reports"], counts["skipped"],
               args.cadence_window, args.cadence_hours * args.cadence_tolerance))
        if counts["streams"] == 0:
            print("REFUSE  zero streams found under %s" % args.reports_dir)
            return 2

    if findings:
        print("")
        for verdict, kind, what, where, extra in findings:
            print("%-9s %-7s %s" % (verdict, kind, what))
            print("          %s %s" % ("between:" if verdict == "GAP" else "cited by:", where))
            if extra:
                print("          %s" % ("resolves on %s" % extra if verdict == "OFF-TRUNK"
                                        else extra))
        print("\n%d finding(s)" % len(findings))
        exit_code = 3
    else:
        print("\nclean")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
