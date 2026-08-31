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

THE MIDDLE BOX (GH #290, 2026-08-29) -- CITATIONS THAT ARE NOT PATHS
--------------------------------------------------------------------
On 2026-08-28T22:03Z a round closed GH #286 and published FIVE citations for a
fix that was committed locally but NOT YET PUSHED.  Between then and 02:xxZ the
next reader saw "issue closed, tree empty": GH #287 went on to fence the hero
group off a test file that did not exist, and W23 launched on the unfixed tree.

Of those five citations this tool, as it stood, could only have caught ONE:

    tests/test_skill_list_nil_head_drain.lua      path      -> MISSING, caught
    bots/ability_item_usage_generic.lua           path      -> exists (the FILE
                                                               did; the claimed
                                                               function did not)
    iterations/state.json:skilldrain_NILHEAD_...  key       -> not a citation kind
    test_set.md §CA                               section   -> not a citation kind
                                                               (and no repo-root
                                                               prefix, so PATH_RE
                                                               never saw it)
    iterations/reports/director/ (a directory)    -         -> not a citation kind

So two kinds are added here, exactly the two #290 §4 item 3 names:

    KEY        `state.json:<key>`   resolved by parsing the file at trunk
    SECTION    `<charter>.md §XX`   resolved against `^#{1,6} §XX` at trunk

and one verdict falls out of the second for free: two rulings can claim the same
section id (measured the same day -- §CA was written twice, by two concurrent
director sessions), which makes every citation of it AMBIGUOUS rather than wrong.

THE GRACE WINDOW (#290 comment, 2026-08-29T02:47Z)
--------------------------------------------------
A comment posted thirty seconds before `git push` cites work that is real and
about to land.  Judging it against the trunk of that instant makes it red, and a
detector that cries at correct behaviour gets muted.  So a citation that does not
resolve is a FINDING only if its comment is older than --comment-grace-hours
(default 2h, one routine cadence); younger ones print as PENDING and do not set
the exit code.  Sources with no `created_at` get no grace -- the failure
direction is toward asking, per #276.

WHAT THIS DOES NOT DO
---------------------
- No off-trunk search for KEY/SECTION citations.  Resolving those means parsing
  file CONTENT, and this clone can carry 500 remote refs; `unlanded_commits.py`
  already answers "is there work on a branch".  A key/section that is not on
  trunk reads MISSING, and the line says off-trunk was not searched.
- No identifier claims.  "adds local `CompactSkillList`" is the citation that
  would have caught #286 first, but every backticked word in a report has that
  shape and the false-positive rate would bury the real ones.  Still open.
- Section ids are matched as `[A-Z]{1,2}` + optional `.N`/`.Nx`.  `§4` and `§3.3`
  inside "GH #286 §4" are ISSUE sections, not charter sections; requiring an
  uppercase letter is what keeps them out.

FINDING CLASSES
    MISSING    cited path/commit resolves on no remote ref  -> never pushed
    OFF-TRUNK  resolves only on a non-trunk remote ref      -> pushed, not landed
    AMBIGUOUS  a section id that two headings both claim    -> cite resolves to 2
    REFUSED    unresolvable under a shallow clone           -> uncertifiable
    GAP        a hole in a stream's report cadence          -> lost trigger
    PENDING    unresolved, but the comment is inside grace  -> printed, not a finding
    IGNORED-BY-DESIGN
               a path trunk's own .gitignore matches        -> printed, not a finding

THE IGNORED-BY-DESIGN CLASS (GH #365 comment, 2026-08-31T13:57Z)
----------------------------------------------------------------
A cited path that is gitignored is absent from trunk ON PURPOSE.  Judging it
MISSING says "you forgot to push" about a file nobody could ever push, and the
first real case was self-defeating: a comment whose entire subject was that
`bots/Customize/soak_side.lua` does not exist on trunk was, necessarily, judged
red by this tool and published over a known exit 3.  A gate that must be
manually pardoned every time it is right is the gate people stop running.

Two guards keep this from becoming an amnesty:
  * check-ignore reads the WORKING TREE's ignore files, but the audit speaks
    about trunk.  The downgrade only applies when every `.gitignore` is
    byte-identical to trunk and no untracked one adds rules
    (`ignore_rules_certifiable`).  Otherwise MISSING keeps its old meaning to
    the letter -- a rule that exists only in this container proves nothing
    about a reader's checkout.
  * The class is PRINTED, one line per path, with the reason.  Silent
    forgiveness and correct forgiveness look identical in the exit code; only
    the printout separates them.

EXIT CODES
    0  audited, everything resolves
    2  cannot certify (no citations extracted, stale trunk, stale corpus, git refused)
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

# GH #312.  A `.md` in a stream directory whose name OPENS with a `YYYYmmddT`
# stamp is claiming to be a report; if it then fails REPORT_NAME_RE the name is
# malformed (`20260829T131xZ.md`, `20260829T0707Z.md`), NOT "some other file".
# Folding the two into one aggregate `skipped` count is what turned a real
# director work unit into an 11.5h cadence hole that two other streams then
# published as "that stream delivered nothing" -- the failure shape is not a
# missing log line, it is a deliverable translated into an accusation.
MALFORMED_REPORT_RE = re.compile(r"^\d{8}T.*\.md$")
_FIELD_MAX = (23, 59, 59)


def malformed_span(name):
    """The [lo, hi] instants a malformed report stamp could denote, or None.

    Deliberately an INTERVAL, not a guess: `20260829T10xxZ` says only "some
    time in hour 10".  Unknown digits go to 0 for the floor and to the field's
    maximum for the ceiling, so the span is honest about what the name does not
    say.  Recovered from the NAME, never from git -- a file's commit time is
    when it landed, which is a different question from when the round ran.
    """
    m = re.match(r"^(\d{8})T([0-9A-Za-z]*?)Z?\.md$", name)
    if not m:
        return None
    day, part = m.group(1), m.group(2)[:6].ljust(6, "x")
    lo, hi = [], []
    for i in range(3):
        f, cap = part[2 * i:2 * i + 2], _FIELD_MAX[i]
        lo.append(int(("%s%s" % (f[0] if f[0].isdigit() else "0",
                                 f[1] if f[1].isdigit() else "0"))))
        top = int("%s%s" % (f[0] if f[0].isdigit() else "9",
                           f[1] if f[1].isdigit() else "9"))
        hi.append(min(top, cap))
        if lo[i] > cap:
            return None
    try:
        base = datetime.strptime(day, "%Y%m%d").replace(tzinfo=timezone.utc)
    except ValueError:
        return None
    return (base + timedelta(hours=lo[0], minutes=lo[1], seconds=lo[2]),
            base + timedelta(hours=hi[0], minutes=hi[1], seconds=hi[2]))

# --- the middle box (GH #290) -------------------------------------------------
# `state.json:<key>`, with or without the `iterations/` prefix and with or
# without the backticks the reports wrap it in.
KEY_RE = re.compile(r"(?<![\w/])(?:iterations/)?state\.json:([A-Za-z0-9_]{3,})")

# `<charter>.md §XX`.  The file anchor is REQUIRED and must be within
# SECTION_WINDOW characters, because a bare `§CA` in prose is a back-reference
# inside the same document, and `§4` after "GH #286" is an issue section.
SECTION_FILES = {
    "test_set.md": "iterations/streams/test_set.md",
    "director.md": "iterations/streams/director.md",
    "strategy.md": "iterations/streams/strategy.md",
    "hero.md": "iterations/streams/hero.md",
    "replay-check.md": "iterations/streams/replay-check.md",
    "batch-desk.md": "iterations/streams/batch-desk.md",
}
SECTION_WINDOW = 24
SECTION_RE = re.compile(
    r"(?P<file>%s)(?P<between>[^\n]{0,%d}?)§(?P<sec>[A-Z]{1,2}(?:\.\d+[a-z]?)?)"
    % ("|".join(re.escape(f) for f in SECTION_FILES), SECTION_WINDOW)
)
HEADING_RE_TMPL = r"^#{1,6}[ \t]*§%s(?![0-9A-Za-z.])"


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


def extract_keys(text):
    """-> [key] cited as `state.json:<key>`."""
    return [m.group(1) for m in KEY_RE.finditer(text)]


def extract_sections(text):
    """-> [(repo_path, section_id)] cited as `<charter>.md §XX`.

    Only the FIRST `§` within SECTION_WINDOW characters of the filename binds
    (the `between` group is non-greedy and `§`-free by construction): a second
    id further along the sentence is prose, not a citation of that file, and
    guessing at it is how a detector earns its mute."""
    out = []
    for m in SECTION_RE.finditer(text):
        assert "§" not in m.group("between")
        out.append((SECTION_FILES[m.group("file")], m.group("sec")))
    return out


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


def parse_ts(value):
    """ISO-8601 (GitHub's `2026-08-29T02:47:22Z`) -> aware datetime, or None."""
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def load_sources(comment_files, text_files):
    """-> (sources, fetched_at).  Each source is (label, text, created_at|None).

    Comment JSON accepts a bare list or the GitHub-ish {"comments": [...]}
    envelope; each item needs a `body`.  `created_at` (GitHub supplies it
    verbatim) drives the grace window; `fetched_at` on the envelope is how a
    stale corpus is told apart from a clean one."""
    sources = []
    fetched_at = None
    for path in comment_files:
        raw = sys.stdin.read() if path == "-" else open(path, encoding="utf-8").read()
        data = json.loads(raw)
        if isinstance(data, dict):
            fetched_at = fetched_at or parse_ts(data.get("fetched_at"))
            data = data.get("comments", data.get("items", []))
        for i, item in enumerate(data):
            if isinstance(item, str):
                body, label, created = item, "%s#%d" % (path, i), None
            else:
                body = item.get("body") or ""
                label = item.get("html_url") or item.get("url") or "%s#%d" % (path, i)
                created = parse_ts(item.get("created_at") or item.get("updated_at"))
            if body:
                sources.append((label, body, created))
    for path in text_files:
        sources.append((path, open(path, encoding="utf-8").read(), None))
    return sources, fetched_at


def ignore_rules_certifiable(cwd, trunk_ref):
    """Can `git check-ignore` here speak for a READER's checkout of trunk_ref?

    check-ignore reads the WORKING TREE's ignore files; the question this tool
    answers is about trunk.  Those coincide only when every `.gitignore` is
    byte-identical to trunk and no untracked one is adding rules.  When they do
    not coincide we must not downgrade anything -- an ignore rule that exists
    only in this container says nothing about what a reader would see.
    """
    if not git_ok(["diff", "--quiet", trunk_ref, "--", "*.gitignore"], cwd):
        return False
    p = subprocess.run(["git", "ls-files", "--others", "--exclude-standard",
                        "--", "*.gitignore"], cwd=cwd, capture_output=True, text=True)
    return p.returncode == 0 and p.stdout.strip() == ""


def path_ignored_by_design(cwd, path):
    """True when trunk's own ignore rules match this path.

    `--no-index` is required: without it check-ignore refuses to speak about a
    path that is tracked, and the paths we ask about are exactly the ones that
    are not.
    """
    return git_ok(["check-ignore", "-q", "--no-index", "--", path], cwd)


def resolve_path(cwd, path, trunk_ref, refs, ignore_ok=False):
    if git_ok(["cat-file", "-e", "%s:%s" % (trunk_ref, path)], cwd):
        return "OK", trunk_ref
    for ref in refs:
        if git_ok(["cat-file", "-e", "%s:%s" % (ref, path)], cwd):
            return "OFF-TRUNK", ref
    # GH #365 comment (strategy, 2026-08-31T13:57Z): a path the repo ignores BY
    # DESIGN is absent from trunk on purpose, so "a reader cannot follow it" is
    # not a stranding -- it is the fact being cited.  The live case is
    # `bots/Customize/soak_side.lua`: a comment whose whole subject is that the
    # farm-only switch does not exist on trunk was, necessarily, judged red by
    # this tool.  A detector that cries at correct behaviour gets muted, so this
    # class exists to keep MISSING meaning "you forgot to push".
    if ignore_ok and path_ignored_by_design(cwd, path):
        return "IGNORED", None
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


def show(cwd, ref, path):
    """File content at a ref, or None when the path is not there."""
    p = subprocess.run(["git", "show", "%s:%s" % (ref, path)], cwd=cwd,
                       capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


def resolve_key(cwd, key, trunk_ref, cache):
    """A `state.json:<key>` citation -> ("OK"|"MISSING", note).

    Off-trunk is NOT searched (see WHAT THIS DOES NOT DO): parsing content
    across every remote ref is the expensive half, and `unlanded_commits.py`
    already answers "does some branch have work"."""
    if "state" not in cache:
        raw = show(cwd, trunk_ref, "iterations/state.json")
        try:
            cache["state"] = json.loads(raw) if raw is not None else None
        except ValueError:
            cache["state"] = None
    data = cache["state"]
    if data is None:
        return "MISSING", "iterations/state.json unreadable at %s" % trunk_ref
    if key in data:
        return "OK", None
    return "MISSING", "no such key at %s (off-trunk refs not searched)" % trunk_ref


def resolve_section(cwd, path, sec, trunk_ref, cache):
    """A `<charter>.md §XX` citation -> ("OK"|"MISSING"|"AMBIGUOUS", note)."""
    if path not in cache:
        cache[path] = show(cwd, trunk_ref, path)
    text = cache[path]
    if text is None:
        return "MISSING", "%s not at %s" % (path, trunk_ref)
    hits = re.findall(HEADING_RE_TMPL % re.escape(sec), text, re.M)
    if len(hits) == 1:
        return "OK", None
    if len(hits) > 1:
        return "AMBIGUOUS", "%d headings claim §%s in %s" % (len(hits), sec, path)
    return "MISSING", "no §%s heading in %s (off-trunk refs not searched)" % (sec, path)


def audit_citations(cwd, sources, trunk_ref, refs, shallow, hash_mode,
                    grace_hours=0.0, now=None):
    findings = []
    counts = {"paths": 0, "hashes": 0, "hex_seen": 0, "keys": 0, "sections": 0,
              "ok": 0, "refused": 0, "pending": 0, "ignored": 0}
    pending = []
    ignored = []
    cache = {}
    now = now or datetime.now(timezone.utc)
    # Computed once: whether this container's ignore rules are trunk's rules.
    # False => no path is downgraded and MISSING keeps its old meaning exactly.
    ignore_ok = ignore_rules_certifiable(cwd, trunk_ref)

    def record(verdict, kind, what, label, where, created):
        """Grace: an unresolved citation from a comment younger than the window
        is PENDING (printed, no exit code) rather than a finding."""
        if created is not None and grace_hours > 0:
            age_h = (now - created).total_seconds() / 3600.0
            if age_h < grace_hours:
                counts["pending"] += 1
                pending.append((kind, what, label, "%.1fh old, grace %.1fh"
                                % (age_h, grace_hours)))
                return
        findings.append((verdict, kind, what, label, where))

    seen = set()
    for label, text, created in sources:
        paths, hashes, hex_seen = extract(text, hash_mode)
        counts["hex_seen"] += hex_seen
        for p in paths:
            counts["paths"] += 1
            key = ("path", p)
            if key in seen:
                continue
            seen.add(key)
            verdict, where = resolve_path(cwd, p, trunk_ref, refs, ignore_ok)
            if verdict == "OK":
                counts["ok"] += 1
            elif verdict == "IGNORED":
                counts["ignored"] += 1
                ignored.append((p, label))
            else:
                record(verdict, "path", p, label, where, created)
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
                record(verdict, "commit", h, label, where, created)
        for k in extract_keys(text):
            counts["keys"] += 1
            key = ("key", k)
            if key in seen:
                continue
            seen.add(key)
            verdict, note = resolve_key(cwd, k, trunk_ref, cache)
            if verdict == "OK":
                counts["ok"] += 1
            else:
                record(verdict, "key", "state.json:%s" % k, label, note, created)
        for spath, sec in extract_sections(text):
            counts["sections"] += 1
            key = ("section", spath, sec)
            if key in seen:
                continue
            seen.add(key)
            verdict, note = resolve_section(cwd, spath, sec, trunk_ref, cache)
            if verdict == "OK":
                counts["ok"] += 1
            else:
                record(verdict, "section", "%s §%s" % (os.path.basename(spath), sec),
                       label, note, created)
    return findings, counts, pending, ignored


def audit_cadence(cwd, reports_dir, cadence_h, tolerance, window_h):
    """A hole in a stream's report rhythm is a trigger that produced nothing.

    Costs nothing and needs no input -- it is the half of #113 that sees the
    round which vanished without publishing anything at all."""
    findings, counts = [], {"streams": 0, "reports": 0, "skipped": 0,
                            "malformed": 0}
    malformed = []                  # (stream, name, span or None) -- GH #312
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
                if MALFORMED_REPORT_RE.match(name):
                    counts["malformed"] += 1
                    malformed.append((stream, name, malformed_span(name)))
                else:
                    counts["skipped"] += 1  # named, never silently dropped
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
        mine = [(n, sp) for s, n, sp in malformed if s == stream]

        def extra(gap_h, a, b):
            """`%.1fh`, plus the malformed-name files sitting INSIDE the hole.

            GH #312: without this the hole reads as "this stream produced
            nothing", and downstream acts on that reading.  The hole is still
            reported -- an unfilled timestamp is a real defect -- but it may
            not be reported as idleness when a deliverable is sitting in it.
            """
            inside = [n for n, sp in mine if sp and sp[1] > a and sp[0] < b]
            if not inside:
                return "%.1fh" % gap_h
            return ("%.1fh  [!] %d malformed-name file(s) inside this window "
                    "(%s) -- likely a real work unit; fix the NAME, do not read "
                    "this gap as idle" % (gap_h, len(inside), ", ".join(inside)))

        for a, b in zip(chain, chain[1:]):
            gap = (b - a).total_seconds() / 3600.0
            if gap > cadence_h * tolerance:
                findings.append(("GAP", "cadence", stream,
                                 "%s -> %s" % (a.strftime("%m-%dT%H:%MZ"),
                                               b.strftime("%m-%dT%H:%MZ")),
                                 extra(gap, a, b)))
        if chain:
            trailing = (now - chain[-1]).total_seconds() / 3600.0
            if trailing > cadence_h * tolerance:
                findings.append(("GAP", "cadence", stream,
                                 "%s -> now" % chain[-1].strftime("%m-%dT%H:%MZ"),
                                 extra(trailing, chain[-1], now)))
    counts["malformed_files"] = malformed
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
    ap.add_argument("--comment-grace-hours", type=float, default=2.0,
                    help="a citation from a comment younger than this prints as "
                         "PENDING instead of a finding (default 2.0, one routine "
                         "cadence).  Sources with no created_at get no grace.")
    ap.add_argument("--comments-max-age", type=float, default=0.0,
                    help="refuse (exit 2) when the comment corpus envelope's "
                         "`fetched_at` is older than this many hours.  0 (default) "
                         "does not check.  A stale corpus certifies nothing.")
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
            sources, fetched_at = load_sources(args.comments, args.text)
        except (OSError, ValueError) as exc:
            print("REFUSE  cannot read citation sources: %s" % exc)
            return 2
        if args.comments and args.comments_max_age > 0:
            if fetched_at is None:
                print("REFUSE  the comment corpus carries no `fetched_at`; with "
                      "--comments-max-age set, an undated corpus cannot be told "
                      "apart from a stale one.")
                return 2
            age_h = (datetime.now(timezone.utc) - fetched_at).total_seconds() / 3600.0
            if age_h > args.comments_max_age:
                print("REFUSE  comment corpus is %.1fh old (max %.1fh) -- it "
                      "certifies nothing about comments posted since.  Refresh it "
                      "(see tools/agent/refresh_issue_corpus.md)."
                      % (age_h, args.comments_max_age))
                return 2
        try:
            refs = remote_refs(cwd, args.remote, trunk_ref)
            shallow = is_shallow(cwd)
        except RuntimeError as exc:
            print("REFUSE  git: %s" % exc)
            return 2
        f, counts, pending, ignored = audit_citations(
            cwd, sources, trunk_ref, refs, shallow, args.hash_mode,
            grace_hours=args.comment_grace_hours)
        findings += f
        print("CITATIONS  sources %d  refs %d  trunk %s%s" %
              (len(sources), len(refs) + 1, trunk_ref, "  (shallow clone)" if shallow else ""))
        print("           paths cited %d  hashes audited %d of %d hex tokens (%s)  "
              "resolved on trunk %d  refused %d" %
              (counts["paths"], counts["hashes"], counts["hex_seen"], args.hash_mode,
               counts["ok"], counts["refused"]))
        print("           state.json keys cited %d  charter sections cited %d  "
              "pending inside %.1fh grace %d" %
              (counts["keys"], counts["sections"], args.comment_grace_hours,
               counts["pending"]))
        print("           paths absent from trunk BY DESIGN (gitignored) %d" %
              counts["ignored"])
        for kind, what, label, why in pending:
            print("PENDING   %-7s %s\n          cited by: %s\n          %s"
                  % (kind, what, label, why))
        # Printed, never counted: the reader must still see which citations were
        # let through and why, or this class becomes a silent amnesty.
        for what, label in ignored:
            print("IGNORED-BY-DESIGN  path    %s\n          cited by: %s\n"
                  "          matched by trunk's own .gitignore -- absent on purpose, "
                  "not unpushed" % (what, label))
        if counts["paths"] + counts["hashes"] + counts["keys"] + counts["sections"] == 0:
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
              "malformed report names %d  window %.0fh  flag > %.1fh" %
              (counts["streams"], counts["reports"], counts["skipped"],
               counts["malformed"], args.cadence_window,
               args.cadence_hours * args.cadence_tolerance))
        # GH #312: named one by one, and kept apart from the directory's
        # recognised non-report files.  An aggregate count cannot tell the
        # reader which class a number belongs to, and only one of the two
        # classes means "a round's output is invisible to this leg".
        for stream, name, span in counts.get("malformed_files", []):
            when = ("%s..%s" % (span[0].strftime("%m-%dT%H:%M"),
                                span[1].strftime("%H:%MZ"))
                    if span else "stamp unrecoverable from the name")
            print("SKIPPED-IN-STREAM  %s/%s  (claims a report stamp; %s)"
                  % (stream, name, when))
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
