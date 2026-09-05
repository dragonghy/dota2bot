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

VERIFY_RE = re.compile(
    r"^VERIFY\s+id=([A-Za-z0-9_]+)\s+verdict=([A-Z]+)"
    r"(?:\s+episodes=(\S+))?", re.M)
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test-set",
                    default=os.path.join(REPO, "iterations/streams/test_set.md"))
    ap.add_argument("--reports",
                    default=os.path.join(REPO, "iterations/reports/replay-check"))
    ap.add_argument("--all", action="store_true",
                    help="print every armed id, not only the uncovered ones")
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
    for path in files:
        stem = os.path.basename(path)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        for m in VERIFY_RE.finditer(text):
            verify.setdefault(m.group(1), []).append(
                (stem, m.group(2), m.group(3)))
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

    rows = []
    for wid in ids:
        v = verify.get(wid, [])
        last = v[-1] if v else None
        rows.append((wid, len(v), last[1] if last else "-",
                     last[0][:15] if last else "-", len(narrat.get(wid, ()))))
    rows.sort(key=lambda r: (r[1], r[4], r[0]))

    print("\n%-16s %6s %-14s %-16s %6s" %
          ("id", "verify", "last_verdict", "last_report", "narrat"))
    for wid, nv, verdict, rep, nn in rows:
        if not a.all and nv > 0:
            continue
        print("%-16s %6d %-14s %-16s %6d" % (wid, nv, verdict, rep, nn))

    blind = [r[0] for r in rows if r[1] == 0 and r[4] == 0]
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
    print("  * an id can be armed and legitimately unverifiable from replays;")
    print("    that is a finding about the instrument, not a debt (see")
    print("    creepthink, report 20260905T09xxZ).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
