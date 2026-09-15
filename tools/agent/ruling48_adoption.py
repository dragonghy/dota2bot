#!/usr/bin/env python3
"""RULING 48 self-report channel: measure adoption, and sum the `<N>` it buys.

WHAT THIS ANSWERS (the numerator half of `owed_executions.json:
s3_attribution_gap_remeasure_under_ruling48`).

RULING 48 (2026-09-15T07:1xZ) made one sentence mandatory in every round
report that touched S3: the cost line is written in three segments,
`零 EC2 / 零 CE / S3 读取 <N> 个对象(出网未计价)`, and `零支出` is banned
as the third segment.  RULING 49 (乙) then commissioned a remeasure of the
S3 attribution gap after three batch-desk rounds, on this reasoning: the
74-77% "unattributed" was measured against the streams' OWN self-reports,
and "a stream that downloaded but did not write it down is invisible to
that method".  RULING 48 is the repair of that channel.

So the gap has two halves and they are NOT symmetric:

  numerator   -- what the streams say they read.  THIS SCRIPT.  Free, and
                 readable the instant the reports land.
  denominator -- what S3 actually cost over the same window.  Lives behind
                 the 11.3h Cost Explorer / budgets lag band, so it is NOT
                 readable while the window is still inside that band.

Hand-counting the numerator is exactly the trap iron rule 4 (i-a) took six
rounds to notice (`ab_games` is not a reading), so the count lives in a
script that the next round re-runs rather than in a round report's prose.

WHAT IT DELIBERATELY DOES NOT DO
  * It does not price anything.  RULING 48 is explicit that streams are not
    asked to turn `<N>` into dollars ("不要求各流自己算出美元数" -- the
    conservative side on purpose, because per-round egress pricing is not
    answerable from `USAGE_TYPE`).  What is wanted is the number a later
    reader can multiply.  Printing a dollar figure here would invent the
    very rate the ruling says nobody has.
  * It does not read S3, EC2 or Cost Explorer.  Zero AWS calls, zero cost.
  * It does not judge a round.  A round that genuinely touched no object
    and says so is compliant; the finding is a MISSING line, not a zero.

EXIT CODES (evidence discipline 2: a run that could not run is not a pass)
  0  every report in the window carries a parseable three-part line
  2  could not run (no reports in window, unreadable tree)
  3  findings: a missing line, a banned `零支出`, or an approximate `<N>`
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

# The third segment, with its numeral.  `个对象` is the prescribed unit, but
# the streams in practice itemise by object type (`13 个 .dem + 13 个
# .analysis.json`), which is strictly MORE information than the ruling asks
# for -- so both spellings count, and every numeral on the line is summed.
_SEG3_NUM = re.compile(r"S3\s*读取\s*(.+?)(?:$|\n)")
_NUMERAL = re.compile(r"(?<![\d.])(\d[\d,]*)\s*个")
# A line that says "read nothing" without ever writing a numeral.  Compliant
# in substance (the true N is zero) but it hands a later reader a word where
# the ruling asked for a number, so it is reported separately rather than
# silently folded into the zeros.
_PROSE_ZERO = re.compile(r"零\s*S3\s*读取|S3\s*读取\s*为?\s*零")
# The banned third segment (RULING 48's whole subject).
_BANNED = re.compile(r"零\s*EC2\s*/\s*零\s*CE\s*/\s*\*{0,2}零支出")
# An approximation where an exact count was available to the writer.
_APPROX = re.compile(r"[约大概约莫]\s*\d|~\s*\d|\d\s*余|若干\s*个")
# The first two segments -- used to find the cost line at all.
_SEG12 = re.compile(r"零\s*EC2\s*[、/]\s*零\s*CE")

_TS = re.compile(r"^(\d{8}T\d{6}Z)\.md$")


def _strip_markup(line: str) -> str:
    """Drop the emphasis/callout noise that varies between streams."""
    return line.replace("**", "").replace("`", "").replace("⛔", "").replace("⭐", "")


def scan_report(path: pathlib.Path) -> dict:
    """Classify one round report's RULING 48 cost line.

    Returns a record with `status` in:
      OK_N          -- three-part line with at least one numeral
      OK_PROSE_ZERO -- says it read nothing, but wrote no numeral
      BANNED        -- third segment is `零支出` (the thing RULING 48 bans)
      NO_LINE       -- no cost line found at all
    """
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:  # unreadable file is a finding, never a zero
        return {"report": str(path), "status": "NO_LINE", "detail": f"unreadable: {exc}"}

    banned_hits: list[str] = []
    best: dict | None = None

    for raw in text.splitlines():
        line = _strip_markup(raw)
        if _BANNED.search(line):
            banned_hits.append(raw.strip()[:160])
        if not _SEG12.search(line):
            continue

        objects, approx = 0, False
        seg3 = _SEG3_NUM.search(line)
        numerals = _NUMERAL.findall(seg3.group(1)) if seg3 else []
        # `零 S3 读取` also matches _SEG3_NUM (it CONTAINS "S3 读取"), so the
        # numeral test, not the segment match, is what separates "wrote a
        # number" from "wrote a word".  Testing the segment alone silently
        # reported every prose zero as OK_N and printed `prose zeros: 0`.
        if numerals:
            tail = seg3.group(1)
            objects = sum(int(n.replace(",", "")) for n in numerals)
            approx = bool(_APPROX.search(tail))
            status = "OK_N"
        elif _PROSE_ZERO.search(line):
            status = "OK_PROSE_ZERO"
        else:
            continue

        cand = {
            "report": str(path),
            "status": status,
            "objects": objects,
            "approx": approx,
            "line": raw.strip()[:200],
        }
        # A report may carry the line twice (summary + cost section).  Keep the
        # one that reports the most -- an itemised numeral beats a prose zero,
        # and a larger N beats a smaller one, so a duplicate can never shrink
        # the round's declared read.
        rank = (cand["status"] == "OK_N", cand["objects"])
        if best is None or rank > (best["status"] == "OK_N", best["objects"]):
            best = cand

    if best is None:
        if banned_hits:
            return {
                "report": str(path),
                "status": "BANNED",
                "objects": 0,
                "approx": False,
                "line": banned_hits[0],
            }
        return {"report": str(path), "status": "NO_LINE", "objects": 0, "approx": False, "line": ""}

    if banned_hits:
        best["also_banned_form"] = banned_hits[0]
    return best


def collect(reports_dir: pathlib.Path, since: str, until: str) -> list[pathlib.Path]:
    out = []
    for stream in sorted(p for p in reports_dir.iterdir() if p.is_dir()):
        for f in stream.iterdir():
            m = _TS.match(f.name)
            if m and since <= m.group(1) <= until:
                out.append(f)
    return sorted(out, key=lambda p: p.name)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--reports", default="iterations/reports", type=pathlib.Path)
    ap.add_argument("--since", required=True, help="inclusive, e.g. 20260915T071500Z")
    ap.add_argument("--until", default="99999999T999999Z", help="inclusive")
    ap.add_argument("--json", action="store_true", help="emit the records as JSON too")
    args = ap.parse_args()

    if not args.reports.is_dir():
        print(f"RULING48_ADOPTION: could not run -- {args.reports} is not a directory")
        print("EXIT 2 -- nothing was measured; this is NOT a pass.")
        return 2

    paths = collect(args.reports, args.since, args.until)
    if not paths:
        print(f"RULING48_ADOPTION: could not run -- no reports in [{args.since}, {args.until}]")
        print("EXIT 2 -- nothing was measured; this is NOT a pass.")
        return 2

    records = [scan_report(p) for p in paths]

    print(f"window          : [{args.since}, {args.until}]  {len(records)} report(s)")
    for r in records:
        mark = {"OK_N": "  ", "OK_PROSE_ZERO": "~ ", "BANNED": "! ", "NO_LINE": "! "}[r["status"]]
        n = r.get("objects", 0)
        extra = " (APPROX)" if r.get("approx") else ""
        print(f"{mark}{r['status']:<14} N={n:<6}{extra} {r['report']}")

    with_line = [r for r in records if r["status"].startswith("OK")]
    with_n = [r for r in records if r["status"] == "OK_N"]
    missing = [r for r in records if r["status"] in ("NO_LINE", "BANNED")]
    approx = [r for r in with_n if r["approx"]]
    total = sum(r["objects"] for r in with_n)
    nonzero = [r for r in with_n if r["objects"] > 0]

    print()
    print(f"adoption        : {len(with_line)}/{len(records)} report(s) carry a three-part cost line")
    print(f"declared objects: {total} across {len(nonzero)} report(s) that read anything")
    print(f"prose zeros     : {len(records) - len(with_n) - len(missing)} (said zero, wrote no numeral)")
    print(f"approximate N   : {len(approx)}")
    # The number this whole channel exists to produce.  Stated as a count, never
    # as dollars -- see the module docstring.
    print(f"MULTIPLIABLE N  : {total}  <- one number a later reader can multiply by a unit price")
    print("LIMIT: this is the NUMERATOR only. The gap also needs the window's actual")
    print("       S3 cost, which sits behind the ~11.3h budgets/CE lag band. A window")
    print("       still inside that band has no denominator yet -- and 'no denominator'")
    print("       is not 'no gap'.")

    if args.json:
        print()
        print(json.dumps({"window": [args.since, args.until], "total_objects": total, "records": records},
                         ensure_ascii=False, indent=2))

    if missing or approx:
        print()
        for r in missing:
            print(f"FINDING {r['status']}: {r['report']}")
        for r in approx:
            print(f"FINDING APPROX_N: {r['report']} -- an approximate N still multiplies, but the")
            print("        exact count was in the caller's own hands at write time.")
        print(f"RULING48_ADOPTION: FINDINGS (exit 3) -- {len(missing)} missing/banned, {len(approx)} approximate.")
        return 3

    print()
    print("RULING48_ADOPTION: CLEAN (exit 0) -- every report in the window declares its S3 reads.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
