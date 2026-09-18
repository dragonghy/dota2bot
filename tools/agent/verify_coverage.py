#!/usr/bin/env python3
"""Condition-(a) coverage census: which armed ids have an execution verdict?

WHY THIS EXISTS.  Iron law 2 makes condition (a) -- "the replay desk confirmed
the change really executes and behaves correctly in a real game" -- a hard
precondition for every promote.  The weekly efficiency ledger has a cell for
"ids whose condition (a) completed this week" and it has read `未单独计` for
weeks, because the verdicts live in the prose of 150+ reports and cannot be
counted.  That is the one quantity in this machine with no counter, and it is
also the standing blocker on promotes.  charter step 7 (director, 2026-08-30)
added the machine-readable line

    VERIFY id=<gate id> verdict=<WORKING|BUGGY|SILENT|INDETERMINATE> episodes=<n>

so it could be counted.  This is the counter.

WHAT A ZERO HERE DOES AND DOES NOT MEAN.  ** A zero VERIFY count is NOT a claim
that the id was never looked at. ** The VERIFY convention only starts
2026-08-30; everything verified before that says so in prose only.  So the tool
prints TWO independent columns and never merges them:

    verify   -- machine-readable VERIFY lines (countable, the ledger's number)
    narrat   -- reports where a verdict WORD appears within a few lines of the
                id (a weak, generous, false-positive-prone signal, printed so
                that a zero in the first column cannot be misread as "nobody
                ever looked")

An id with verify=0 AND narrat=0 is the real blind spot, and those are listed
separately at the end.  That list is the useful output: it is where the next
round's catch-up work belongs (charter workflow step 2, "核验记录最少的 id").

SOURCES.  The armed set is read off `iterations/streams/test_set.md` line 2 --
the same line the batch desk's arm-string census reads, so the two cannot drift
apart silently.  Reports are `iterations/reports/replay-check/*.md`.

EXIT: 0 ran, 2 could not run (missing arm string or reports).  A census, not a
gate -- it never fails on coverage, it reports it.
"""
import argparse
import glob
import os
import re
import sys

# NO `^` ANCHOR, AND `episodes` IS DIGITS-ONLY.  Both of those are fixes, and
# both defects ran in the same direction -- they made verified ids read as
# unverified, i.e. the counter manufactured condition-(a) debt.
#
# Measured on the corpus this tool actually reads
# (`iterations/reports/replay-check/*.md`, 2026-09-06): the old `^VERIFY`
# anchor dropped **26 of 59** VERIFY lines (44.1%), because this desk writes
# the line inside markdown emphasis or a code span -- ``**`VERIFY id=… `**``,
# `` `VERIFY id=…` ``, `- **`VERIFY …`** `` -- exactly as the charter's own
# step-7 examples are rendered.  Seven ARMED ids the census printed as
# `verify=0` in fact carried a verdict: odaoe, pullcad, roshdist, rotscope,
# slotpush, stayfield, stayfield2.  `roshdist` was the expensive one: its
# recorded verdict is **BUGGY (episodes=77)** and the ledger showed it as
# never verified, so a known-broken armed id read as untouched debt.
#
# The cost is not hypothetical: the round that found this had *chosen*
# `rotscope` as its work unit off that very `verify=0` row, and `rotscope` had
# been verified INDETERMINATE two days earlier with a structural reason.  The
# instrument was steering rounds into repeating finished work -- the same shape
# as the `zusult` in-domain-count trap and the stale-mana channel: **the
# measuring device manufactured the conclusion it then reported.**
#
# Dropping the anchor does NOT loosen the separation the tests pin: the pattern
# still demands a literal id AND a CAPS verdict token, so the many meta
# sentences that merely discuss the convention (`VERIFY id=… verdict=…` with an
# ellipsis, table rows describing the format) still do not match.  That was
# checked against the real corpus, not assumed.
#
# `episodes=(\S+)` swallowed the trailing markup along with the number and
# reported counts like `5020**` and ``7`。``; `(\d+)` cannot.
#
# ⚠️ 2026-09-18 (director, GH-filed by the replay desk 15:42Z).  THIRD DEFECT,
# AND THE FIRST ONE THAT RAN IN THE OPPOSITE DIRECTION: the two fixes above
# made verified ids read as unverified (manufactured DEBT, the safe side); this
# one made an id read as verified when nobody had judged it (manufactured
# SATISFACTION, and condition (a) is iron law 2's precondition for a promote).
#
# The shape: a report that QUOTES another document's VERIFY line -- an evidence
# table citing `…/20260911T101534Z.md:69`, a pasted `grep` hit, an owed row's
# acceptance sentence -- scored as a fresh verdict by the round that quoted it.
# Measured on the live corpus that day, 10 of 191 matches were quotations, in
# three failure classes of rising cost:
#   * date drift (7): the verdict word was right, but `last_report` jumped by
#     up to 6 days, so "how stale is this id's verification" reads too fresh;
#   * TIME REVERSAL (1): `abilanc`'s 09-17 quotation of a 09-11 INDETERMINATE
#     overwrote the real 09-15 WORKING -- not an over-count, a wrong answer;
#   * FABRICATION (1): `ownhalf` read `WORKING` from a round whose own §5 says
#     verbatim "VERIFY 行 0 条 ⛔ 不硬凑" (zero verdicts this round).  The string
#     it was quoting is the acceptance sentence of the owed row whose ruling
#     reads "⛔ 不许拿 `verify > 0` 当促进依据" -- so REVIEWING that row fed the
#     counter the very evidence the row exists to withhold, once per round,
#     self-sustaining.
#
# ⛔ The `^` anchor cannot come back (see above: it dropped 44.1% of real
# lines), so the discriminator has to live somewhere else.  It lives on the
# ROW: a line that also names WHERE ELSE THIS STRING LIVES -- another report's
# stem or path, an owed row, an acceptance sentence -- is citing, not judging.
# A desk stating its own verdict does not cite a source for it on the same row.
#
# Scope, stated so it is not over-read: LINE scope, not block scope.  Block
# scope was measured first and is WRONG HERE -- it flagged 27 of 191, and the
# extra 17 were real verdicts whose paragraph merely happened to name a corpus
# path (`20260917T095600Z.md:11`, `…T125517Z.md:8`, every `a_evidence_*.md`
# headline).  That is the under-count direction this file has already been
# burned by twice, so the wider rule was rejected on the measurement rather
# than kept for its tidiness.
VERIFY_RE = re.compile(
    r"VERIFY\s+id=([A-Za-z0-9_]+)\s+verdict=([A-Z]+(?:-[A-Z]+)*)"
    r"(?:\s+episodes=(\d+))?")
# THE VERDICT VOCABULARY IS CHARTER STEP 7's, AND A TOKEN OUTSIDE IT IS NOT A
# VERDICT.  `verdict=([A-Z]+)` truncated `NOT-ARMED` to `NOT` and filed it as a
# verdict word -- 12 lines on the 2026-09-18 corpus (`skillstall` 9,
# `outcommit` 3).  Both ids sit outside the armed string today, so the table
# never showed it; it would have appeared, uncontested, on the day either id
# entered the set.  Off-vocabulary matches are counted in their own bucket and
# printed -- never silently dropped, because a parser that discards what it
# cannot classify is how `NOT` got in here in the first place.
VERDICT_VOCAB = ("WORKING", "BUGGY", "SILENT", "INDETERMINATE")
# A row that names where else this string lives.  Each alternative was read off
# the real corpus, not imagined: report stem, report path (a pasted `grep` hit
# carries both), the owed registry by name, an owed row's `done_when` field,
# the `{'kind': …}` cell of the desk's owed-review table, and the desk's own
# word for an acceptance sentence.
CITED_RE = re.compile(
    r"\d{8}T\d{6}Z\.md"
    r"|iterations/reports/"
    r"|owed_executions"
    r"|done_when"
    r"|['\"]kind['\"]"
    r"|验收句")
# THE ONE PLACE THE ROW RULE IS WIDENED, AND ONLY AS FAR AS THE MEASUREMENT
# SUPPORTS.  An owed row's acceptance sentence gets quoted as a markdown
# BLOCKQUOTE, and the field name that identifies it ("done_when", the `kind`
# cell, the desk's word 验收句) then sits on a NEIGHBOURING row of the same
# quote rather than on the row carrying the VERIFY string.  Those two rows are
# one block, so the pointer test runs over the whole blockquote -- but only for
# these markers, never for a bare report path: a summary head naming another
# report is ordinary practice at this desk and must keep counting.
# Blast radius, measured on the 2026-09-18 corpus before adopting it: of 191
# matches, exactly TWO sit inside a blockquote at all, and both are the
# residue this widening is for (`20260918T154200Z.md:6` and `:82`, the round
# that reported the defect quoting the acceptance sentence twice).  With it,
# the census reproduces the desk's hand-read correction table 7 rows out of 7.
OWED_QUOTE_RE = re.compile(
    r"owed_executions|done_when|['\"]kind['\"]|验收句")
VERDICT_WORDS = re.compile(r"WORKING|BUGGY|SILENT|INDETERMINATE")
NARR_WINDOW = 260          # chars each side of a mention -- deliberately loose

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def arm_ids(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    if len(lines) < 2:
        raise ValueError("%s has no line 2 (the arm string)" % path)
    ids = [x.strip() for x in lines[1].strip().split(",") if x.strip()]
    if not ids:
        raise ValueError("%s line 2 parsed to zero ids" % path)
    return ids


def scan_report(text):
    """Split one report's VERIFY matches into verdicts / citations / off-vocab.

    ⭐ THE ONE PLACE THE RULE LIVES.  `a_evidence_route.py` counts VERIFY lines
    with this module's regex, and `a_evidence_owed.py` decides VERDICT-vs-OWED
    off that count -- so a citation rule that lived only in this file's `main()`
    would fix the census and leave the obligation leg reading a quotation as a
    discharged debt.  That is this repo's most-repeated defect shape (a reading
    that exists in one leg and never reaches its sibling three lines away), so
    the rule is a function both legs call, not a loop one of them owns.

    Returns three lists of `(lineno, id, verdict, episodes_or_None, line)` for
    the refused ones and `(lineno, id, verdict, episodes_or_None)` for verdicts.

    PER LINE, NOT PER FILE.  The citation test is a property of the ROW a match
    sits on, so the parser has to know which row that is; scanning the whole
    blob cannot answer it.  It also stops `\s+` from bridging a newline, which
    was never an intended match.

    DEDUP WITHIN ONE REPORT.  This desk states its verdict twice in the same
    file by convention -- once in the report's summary head, once in the body
    section that argues it.  Those are one verdict, not two.  Before the anchor
    came off, the head copy was usually the emphasised one and so was invisible,
    which hid the double-count; counting both now would inflate the ledger's own
    number in the OPPOSITE direction from the bug the 09-06 fix repairs, and an
    over-count is the failure mode the docstring calls "worse than the 未单独计
    it replaced".
    """
    verdicts, cited, offvocab = [], [], []
    seen = set()
    lines = text.split("\n")
    for idx, line in enumerate(lines):
        lineno = idx + 1
        for m in VERIFY_RE.finditer(line):
            wid, verdict, eps = m.group(1), m.group(2), m.group(3)
            if CITED_RE.search(line) or in_owed_quote(lines, idx):
                cited.append((lineno, wid, verdict, eps, line.strip()))
                continue
            if verdict not in VERDICT_VOCAB:
                offvocab.append((lineno, wid, verdict, eps, line.strip()))
                continue
            if (wid, verdict, eps) in seen:
                continue
            seen.add((wid, verdict, eps))
            verdicts.append((lineno, wid, verdict, eps))
    return verdicts, cited, offvocab


def in_owed_quote(lines, idx):
    """True when this row is inside a blockquote that quotes an owed row.

    The block is the contiguous run of `>`-prefixed rows around `idx`; a row
    that is not part of a blockquote is never widened, so this cannot reach
    ordinary prose.  See OWED_QUOTE_RE for why only those markers widen.
    """
    if not lines[idx].lstrip().startswith(">"):
        return False
    start = idx
    while start > 0 and lines[start - 1].lstrip().startswith(">"):
        start -= 1
    end = idx
    while end + 1 < len(lines) and lines[end + 1].lstrip().startswith(">"):
        end += 1
    return bool(OWED_QUOTE_RE.search("\n".join(lines[start:end + 1])))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test-set",
                    default=os.path.join(REPO, "iterations/streams/test_set.md"))
    ap.add_argument("--reports",
                    default=os.path.join(REPO, "iterations/reports/replay-check"))
    ap.add_argument("--all", action="store_true",
                    help="print every armed id, not only the uncovered ones")
    ap.add_argument("--show-citations", action="store_true",
                    help="list the VERIFY matches that were read as citations "
                         "or as off-vocabulary tokens, with file and line")
    a = ap.parse_args()

    try:
        ids = arm_ids(a.test_set)
    except Exception as exc:                       # noqa: BLE001
        print("VC_COULD_NOT_RUN: %s" % exc, file=sys.stderr)
        return 2
    files = sorted(glob.glob(os.path.join(a.reports, "*.md")))
    if not files:
        print("VC_COULD_NOT_RUN: no reports under %s" % a.reports,
              file=sys.stderr)
        return 2

    verify = {}
    narrat = {}
    # Two buckets of matches that are NOT verdicts.  They are kept and printed
    # rather than dropped: this tool's whole history is defects that removed
    # lines quietly, and a count nobody can see is a count nobody can dispute.
    cited = []          # a VERIFY string quoted from somewhere else
    offvocab = []       # a token outside charter step 7's vocabulary
    for path in files:
        stem = os.path.basename(path)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        verdicts, cit, off = scan_report(text)
        cited += [(stem,) + r for r in cit]
        offvocab += [(stem,) + r for r in off]
        for _lineno, wid, verdict, eps in verdicts:
            verify.setdefault(wid, []).append((stem, verdict, eps))
        # Where every armed id is named in this file, so a verdict word can be
        # attributed to the NEAREST id rather than to whichever id happens to
        # sit within the window.  Without this the column over-counts exactly
        # where reports are densest -- and a dense paragraph is precisely where
        # several ids are discussed together, so the ids that were NOT judged
        # would inherit their neighbours' verdicts and stop looking blind.
        # Caught by tests/test_verify_coverage.py ("gamma" case) on the first
        # version of this tool, which used a bare +-window.
        id_spans = []
        for other in ids:
            for m in re.finditer(r"\b%s\b" % re.escape(other), text):
                id_spans.append((m.start(), m.end(), other))
        id_spans.sort()
        # Attribute each verdict word to the nearest id named BEFORE it, within
        # the window.  Not "nearest in either direction": a verdict follows its
        # subject in both the English and the Chinese this desk writes
        # ("`<id>`: WORKING", "VERIFY id=X verdict=Y", "<id> 这一轮 SILENT"), so
        # a following id is the NEXT sentence's subject, not this verdict's.
        # Nearest-in-either-direction was tried first and inverted the fixture:
        # it handed beta's verdict to gamma on the next line.
        for w in VERDICT_WORDS.finditer(text):
            best, bestd = None, None
            for s, e, name in id_spans:
                if e > w.start():
                    break                 # id_spans is sorted; rest are later
                d = w.start() - e
                if d <= NARR_WINDOW and (bestd is None or d <= bestd):
                    best, bestd = name, d
            if best is not None:
                narrat.setdefault(best, set()).add(stem)

    print("armed ids: %d   reports scanned: %d" % (len(ids), len(files)))
    print("ids with >=1 machine-readable VERIFY line: %d"
          % sum(1 for i in ids if i in verify))
    print("not counted: %d citation(s), %d off-vocabulary token(s)"
          % (len(cited), len(offvocab)))
    if a.show_citations:
        for stem, lineno, wid, verdict, _eps, line in cited:
            print("  CITATION      %s:%d  %s %s | %s"
                  % (stem, lineno, wid, verdict, line[:110]))
        for stem, lineno, wid, verdict, _eps, line in offvocab:
            print("  OFF-VOCAB     %s:%d  %s %s | %s"
                  % (stem, lineno, wid, verdict, line[:110]))

    rows = []
    for wid in ids:
        v = verify.get(wid, [])
        last = v[-1] if v else None
        # `episodes` is PRINTED, not just parsed.  It was captured from the
        # first version and thrown away, which is why the `(\S+)` capture could
        # sit there returning `5020**` and ``7`。`` without anything noticing.
        # A parsed-but-unprinted field is an unread instrument: nothing can
        # contradict it.  It also carries real signal for the ledger -- an
        # INDETERMINATE at episodes=0 (domain never reached) and one at
        # episodes=4527 (domain saturated, attribution the blocker) are
        # different kinds of debt and should not share a row.
        rows.append((wid, len(v), last[1] if last else "-",
                     last[2] if (last and last[2]) else "-",
                     last[0][:15] if last else "-", len(narrat.get(wid, ()))))
    rows.sort(key=lambda r: (r[1], r[5], r[0]))

    print("\n%-16s %6s %-14s %9s %-16s %6s" %
          ("id", "verify", "last_verdict", "episodes", "last_report", "narrat"))
    for wid, nv, verdict, eps, rep, nn in rows:
        if not a.all and nv > 0:
            continue
        print("%-16s %6d %-14s %9s %-16s %6d" % (wid, nv, verdict, eps, rep, nn))

    blind = [r[0] for r in rows if r[1] == 0 and r[5] == 0]
    print("\nBLIND SPOTS (no VERIFY line AND no verdict word ever near the id "
          "in any report) -- %d:" % len(blind))
    print("  " + (", ".join(blind) if blind else "(none)"))
    print("\nLIMITS, so the numbers above are not over-read:")
    print("  * verify=0 is NOT 'never verified' -- the VERIFY convention starts")
    print("    2026-08-30; anything older is prose only, which is the whole")
    print("    reason this counter had to be added.")
    print("  * narrat is a LOOSE proximity match (a verdict word within %d"
          % NARR_WINDOW)
    print("    chars of the id): generous on purpose, so it over-counts rather")
    print("    than letting a real reading go missing. It is not evidence that")
    print("    condition (a) was bought -- only the VERIFY column counts.")
    print("  * citations are detected AT LINE SCOPE: a quoted VERIFY string")
    print("    that names no source on its own row is still counted. Measured")
    print("    2026-09-18: 2 such lines remained (one report's prose quoting")
    print("    its own §2 twice). Narrower than the defect, on purpose --")
    print("    block scope was measured and dropped 17 real verdicts.")
    print("  * an id can be armed and legitimately unverifiable from replays;")
    print("    that is a finding about the instrument, not a debt (see")
    print("    creepthink, report 20260905T09xxZ).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
