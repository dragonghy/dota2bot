#!/usr/bin/env python3
"""Waits that already expired -- the other half of `pending_rulings.py`.

WHY THIS EXISTS (2026-08-28T19:xxZ, strategy)
---------------------------------------------
`pending_rulings.py` watches one end of the delivery path: a request that
nobody ruled.  Nothing watched the OTHER end -- a stream still recording
"I am waiting for a ruling on X" after that ruling landed.

Founding case, measured on this tree.  The director admitted `campexit`
into the armed set at 2026-08-28T06:5xZ; the ruling landed on `origin` as
commit `e7e57979`, which put `campexit` into `test_set.md`'s line 2 (the
member string every wave arms from) and wrote the verdict into
`state.json`.  The strategy charter then carried

    交棒:总监(① `campexit` 入集裁定**仍欠** ...)

in FOUR consecutive 当前状态 entries -- 07:30Z, 10:35Z, 13:55Z, 16:32Z --
every one of them on a tree that already contained the ruling.  The 07:30Z
round printed `开工 HEAD == e7e5797` in its own report: the ruling commit,
quoted by the round that called the ruling missing.  The data was not
absent; the question was.

The expensive part is not the stale sentence, it is what the sentence was
used FOR.  Two of those rounds picked their work unit by reading their own
backlog's 下一格 and finding it blocked -- "backlog 最上两条的下一格都是
「等总监裁定」⇒ 阻塞 ⇒ 认领 <something else>".  An expired wait does not
fail a test, does not turn a report red, and does not lose a game.  It
silently changes what the next four rounds work on.

WHAT IT REPORTS
---------------
For each stream charter under `iterations/streams/`, the **live** 当前状态
entry (the newest bullet; the one a fresh session reads as current state)
is scanned for an ADMISSION wait -- a line that both asks for an admission
ruling (入集 / 裁 / 待裁 / 裁定) and says it is still outstanding (等 / 仍欠
/ 仍挂着 / 阻塞 / 未裁) -- naming a soak-candidate id in backticks that is
ALREADY armed in `test_set.md` line 2, or already promoted in `bots/`.

  STALE  -- the wait's own object is already in the arm string.  A finding.
  INFO   -- the same id/phrase elsewhere in the charter (backlog, history).
            Reported as context and NEVER as a finding: those lines are
            supposed to be a record of what was true when written.

LIMITS (read these before quoting the output)
---------------------------------------------
1. **It reports a problem, not a verdict.**  A stream may be waiting on a
   SECOND ruling about an id that is already armed (a promote decision, a
   re-arm after a returned wave).  The tool cannot tell those from an
   expired admission wait; it can only say the admission half is over.
   Judge the quoted line.
2. **Only the live 当前状态 block is a finding.**  Backlog entries carry
   their own timestamps and are deliberately historical -- `0BAND` saying
   "等总监裁 `campexit`" was TRUE at 04:3xZ and stays true as a record.
   The blind spot is real and named: a backlog item whose 下一格 is the
   one a session reads to pick work is NOT covered here, only echoed as
   INFO.  A corollary: an expired wait stops being a finding as soon as the
   next status entry lands, because it is then history.  That is intended --
   the tool catches a wait while it is the LIVE claim, which is the only
   window in which it can still steer a round's choice of work.
3. **The armed set is a positional read** -- line 2 of `test_set.md`, the
   same read `tests/test_pending_rulings.py` documents.  A fuzzy search
   would match the historical member strings quoted in the archive.
4. **Match is on backticked ids only.**  A wait that names its id in prose
   without backticks reads as no id at all.  That is the conservative
   direction: this tool under-reports rather than inventing waits.
5. It says nothing about whether a wait is *justified*, only whether its
   stated object already moved.
6. **The mention/use exemption is a text match too** (RESOLVED_MARKERS).  A
   block that quotes an expired wait while declaring it over is exempt for
   that id, which is what makes the tool survivable -- and it is equally an
   escape hatch for a block that writes 已入集 next to a wait it has not
   actually resolved.  The words are ones a reader sees; judge the block.

Exit codes: 0 = no expired wait in any live block; 3 = at least one (a
finding, not a failure); 2 = an input could not be read (NOT a pass).
"""

import argparse
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STREAMS = os.path.join(REPO, "iterations", "streams")
TEST_SET = os.path.join(STREAMS, "test_set.md")
BOTS = os.path.join(REPO, "bots")

# Charter files only.  test_set.md is the 待裁区 archive itself and README.md
# is the iron-rule sheet; neither has a 当前状态 section.
NOT_A_CHARTER = ("test_set.md", "README.md", "routine_prompts.md")

STATUS_HEADER = "## 当前状态"
BULLET = re.compile(r"^- 20\d\d-\d\d-\d\dT")
BACKTICKED = re.compile(r"`([a-z][a-z0-9_]{2,})`")
PROMOTED = re.compile(r"PROMOTED \(was soak-candidate '([a-z0-9_]+)'\)")

# Both halves must be present on the same line.  The admission half keeps the
# finding off legitimate live waits of other kinds -- "等录像组核验 `campexit`"
# (condition (a) evidence) is a real outstanding wait on an armed id and must
# NOT be flagged.
ADMISSION_MARKERS = ("入集", "待裁", "裁定", "裁 ", "裁`")
OUTSTANDING_MARKERS = ("等", "仍欠", "仍挂着", "阻塞", "未裁", "还挂着")

# Mention vs use.  A round that REPORTS an expired wait quotes the wait --
# "本组连续四轮写着「等总监裁 `campexit` 入集(仍挂着)」" is a finding written
# down, not a finding to make.  Without this, the tool reddens on the very
# report that fixes the thing it found, which is the shape that gets a
# detector switched off in one round.  So a hit is exempt when SOME line in
# the same block names the same id together with a resolution word: the block
# has already said the wait is over.  Deliberately block-scoped and id-scoped
# -- line scope misses it (the quote and its correction are different lines),
# and block scope without the id would let one resolved id silence a live
# wait on another.
RESOLVED_MARKERS = ("已入集", "已落地", "已裁", "过期", "更正", "作废",
                    "不需要再裁", "已 armed", "已armed")


class InputError(Exception):
    """An input could not be read -- exit 2, never a silent pass."""


def armed_ids(path=TEST_SET):
    """The member string is line 2 of test_set.md, comma separated (LIMIT 3)."""
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        raise InputError("cannot read %s: %s" % (path, exc))
    if len(lines) < 2:
        raise InputError("%s has no line 2 (the member string)" % path)
    ids = [tok.strip() for tok in lines[1].split(",")]
    ids = [tok for tok in ids if re.fullmatch(r"[a-z][a-z0-9_]*", tok or "")]
    if not ids:
        raise InputError("line 2 of %s parsed to zero ids" % path)
    return set(ids)


def promoted_ids(root=BOTS):
    """Ids whose gate is gone, read off the in-source PROMOTED notes.

    A wait for the ADMISSION of a promoted id is staler still: that id is
    live in every Turbo game, not merely armed in a wave.
    """
    found = set()
    if not os.path.isdir(root):
        return found
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            if not name.endswith(".lua"):
                continue
            try:
                with open(os.path.join(dirpath, name), encoding="utf-8",
                          errors="replace") as fh:
                    found.update(PROMOTED.findall(fh.read()))
            except OSError:
                continue
    return found


def charter_files(streams_dir=STREAMS):
    if not os.path.isdir(streams_dir):
        raise InputError("no such directory: %s" % streams_dir)
    return sorted(
        os.path.join(streams_dir, name)
        for name in os.listdir(streams_dir)
        if name.endswith(".md") and name not in NOT_A_CHARTER
    )


def split_charter(path):
    """(live status block, everything else) as two lists of (lineno, text).

    The live block runs from the first `- <ISO timestamp>` bullet after the
    当前状态 header to the next such bullet (or EOF).  A charter without
    that header has an empty live block -- not an error: only the five
    stream charters carry one.
    """
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    numbered = list(enumerate(lines, start=1))
    try:
        header = next(i for i, (_n, t) in enumerate(numbered)
                      if t.startswith(STATUS_HEADER))
    except StopIteration:
        return [], numbered
    body = numbered[header + 1:]
    try:
        start = next(i for i, (_n, t) in enumerate(body) if BULLET.match(t))
    except StopIteration:
        return [], numbered
    rest = body[start + 1:]
    end = next((i for i, (_n, t) in enumerate(rest) if BULLET.match(t)), len(rest))
    live = body[start:start + 1 + end]
    live_nums = {n for n, _t in live}
    return live, [(n, t) for n, t in numbered if n not in live_nums]


def resolved_in_block(block):
    """Ids the block itself declares settled (see RESOLVED_MARKERS)."""
    done = set()
    for _lineno, text in block:
        if any(m in text for m in RESOLVED_MARKERS):
            done.update(BACKTICKED.findall(text))
    return done


def stale_hits(block, settled):
    """Lines in *block* that wait on an admission ruling for a settled id."""
    already_reported = resolved_in_block(block)
    hits = []
    for lineno, text in block:
        if not any(m in text for m in ADMISSION_MARKERS):
            continue
        if not any(m in text for m in OUTSTANDING_MARKERS):
            continue
        ids = sorted({i for i in BACKTICKED.findall(text)
                      if i in settled and i not in already_reported})
        if ids:
            hits.append((lineno, text.strip(), ids))
    return hits


def landed_when(gate_id, path=TEST_SET, window=40):
    """When *gate_id* entered the MEMBER STRING, best-effort.

    Returns "<short sha> <ISO date>" or None.

    The obvious implementation -- `git log -S <id> -- test_set.md` -- is the
    wrong question and was this tool's first cut: it answers "when did this
    id first appear anywhere in the file", which for `campexit` is the
    04:3xZ 待裁区 PROPOSAL, three hours before the ruling that armed it.
    Quoting that as the landing time would have made a legitimate wait look
    expired, i.e. the same over-claim this tool exists to catch, committed
    by the tool itself.  So walk the file's history oldest-first and return
    the first commit whose LINE 2 holds the id.

    None means unknown, never a fabricated zero (pending_rulings.py LIMIT 3):
    a shallow clone can start after the landing, and the walk is capped at
    *window* commits touching the file.
    """
    try:
        log = subprocess.run(
            ["git", "-C", REPO, "log", "--format=%h %aI", "-n", str(window), "--", path],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if log.returncode != 0:
        return None
    rel = os.path.relpath(path, REPO)
    entries = [ln.split(None, 1) for ln in log.stdout.splitlines() if ln.strip()]
    for sha, when in reversed(entries):  # oldest first
        try:
            blob = subprocess.run(
                ["git", "-C", REPO, "show", "%s:%s" % (sha, rel)],
                capture_output=True, text=True, timeout=30,
            )
        except (OSError, subprocess.SubprocessError):
            return None
        if blob.returncode != 0:
            continue
        lines = blob.stdout.splitlines()
        if len(lines) >= 2 and gate_id in [t.strip() for t in lines[1].split(",")]:
            return "%s %s" % (sha, when)
    return None


def scan(paths, settled):
    """[(path, live_hits, history_hit_count)] for every charter given."""
    report = []
    for path in paths:
        live, rest = split_charter(path)
        report.append((path, stale_hits(live, settled), len(stale_hits(rest, settled))))
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--streams", default=STREAMS)
    ap.add_argument("--test-set", default=TEST_SET)
    ap.add_argument("--bots", default=BOTS)
    ap.add_argument("--no-age", action="store_true",
                    help="skip the git first-appearance lookup (faster)")
    args = ap.parse_args()

    print("=== expired waits (the ruling already landed) ===")
    try:
        armed = armed_ids(args.test_set)
        charters = charter_files(args.streams)
    except InputError as exc:
        print("UNCERTIFIABLE -- %s" % exc)
        print("This line is NOT a pass: the expired-wait question went unasked this round.")
        return 2

    promoted = promoted_ids(args.bots)
    settled = armed | promoted
    findings = 0
    for path, live, history in scan(charters, settled):
        name = os.path.basename(path)
        for lineno, text, ids in live:
            findings += 1
            print("STALE  %s:%d" % (name, lineno))
            for gate_id in ids:
                where = "promoted in bots/" if gate_id in promoted else "armed in test_set.md line 2"
                age = "" if args.no_age else (landed_when(gate_id, args.test_set) or "unknown")
                print("       id=%-12s %s%s"
                      % (gate_id, where, (" (since %s)" % age) if age else ""))
            print("       line: %s" % (text[:160] + ("…" if len(text) > 160 else "")))
        if history:
            print("INFO   %s: %d matching line(s) outside the live 当前状态 block "
                  "(history -- not a finding, see LIMIT 2)" % (name, history))
    if not findings:
        print("no expired admission wait in any live 当前状态 block (%d charter(s), %d settled id(s))"
              % (len(charters), len(settled)))
    return 3 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
