#!/usr/bin/env python3
"""How long has the armed set stood still?  (RULING 73 §HN.4-bis, iron rule 9)

WHY THIS EXISTS -- and it is the first leg in this script written against the
seat that runs it.

`test_set.md` line 3 is the head history line: it records WHEN the armed member
string last moved and how many 判定完结 (verdict closures) that move carried.
Between 2026-09-14T16:xx and 2026-09-17T22:0x that line did not change for **23
consecutive director rounds**, and iron rule 9's 12-round escalation never
fired.  Two reasons, both structural, both quoted from RULING 73:

  (a) 巡检 reads "did the group file a report", not "did the report contain the
      thing".  All 23 rounds filed a report, so the `cadence` leg was green
      every single time -- and NO leg counted verdict closures.  This is the
      `pullcad` family: an automatic reader checks that a thing EXISTS, never
      that it can be TRUE.

  (b) Iron rule 9's escalation action reads 「点名该组」, and in this one cell
      「该组」 IS THE INSPECTING SEAT.  That makes the rule an open circuit on
      itself -- the first self-referential open circuit recorded in this lab.

⛔ SO THE TRIGGER IS NOT A REPORT NAME.  RULING 73 ⑧(b) is literal about this:
read `test_set.md`'s member-string history lines, NOT report names -- reading
report names is exactly the path that was green for 23 rounds.  Report names
appear here only as the DENOMINATOR (how many director rounds have gone by);
they can never satisfy this leg, only make its number bigger.

WHAT COUNTS AS THE ANCHOR
-------------------------
The newest history line that carries BOTH a `<stamp> 的变动` and `判定完结 <N>`
with N >= 1.  The `判定完结` clause is load-bearing, not decoration:

  * an 入集 (admission) also moves the member string but closes NO verdict --
    `test_set.md:142` (`arbheart` + `slotwait` 同轮入集) is exactly that shape.
    Anchoring on "the string moved" would let an admission round RESET the
    stall counter, and that failure direction HIDES a stall.
  * if the `判定完结` convention were dropped, this walks further back and gets
    LOUDER.  Every degenerate input here is loud, never a quiet pass.

FUZZY STAMPS.  The house writes `2026-09-17T2x:xxZ`.  Masked digits resolve to
the EARLIEST matching instant, which maximises the counted stall -- the loud
side, chosen deliberately: the round that WROTE the ruling may then be counted
as a stall round (over-count of at most 1).  The thresholds are 12 and 24; an
off-by-one at that scale costs nothing, and the opposite error is the one this
leg exists because of.

EXIT CODES (house convention: 0 clean / 2 could-not-run / 3 finding)
  0  stall < 12 director rounds.
  3  stall >= 12 -- iron rule 9 red escalation, naming the director seat.
  2  no anchor, no report corpus, unreadable `test_set.md`, unparseable stamp,
     or `origin/main` not readable.  ⛔ An empty report corpus is NOT "0 rounds
     of stall": a corpus that answers nothing proves nothing about the number
     (RULING 55), and "0" is precisely the answer that reads like health.

LIMITS -- quoting this leg in a ruling means quoting these too:
  * It counts DIRECTOR ROUNDS, not calendar time.  A quiet cron and a stalled
    seat are the same number here.
  * It reads `判定完结 <N>` as written.  It does not audit whether the closure
    was real, correct, or worth 1 vs 2 (§GS.1 had to argue 2-not-3 by hand).
  * It says nothing about P4.2's per-round `>= 2` target -- that is a rate, this
    is a gap.  A round closing exactly 1 resets this counter and still misses
    the owner's bar.
  * The anchor is the newest QUALIFYING line by resolved stamp, not by file
    order, so a history line inserted out of order cannot move the anchor
    backwards without also carrying a newer stamp.
"""

import os
import re
import subprocess
import sys
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

TESTSET = os.environ.get("VERDICT_CLOSURE_TESTSET",
                         os.path.join(REPO, "iterations", "streams", "test_set.md"))
# Overridable ONLY for the acceptance suite / mutation stand, and announced when
# used: a leg whose corpus can be swapped silently is a leg that can be made to
# say anything.
REPORT_LIST = os.environ.get("VERDICT_CLOSURE_REPORT_LIST", "")
DECISIONS = os.environ.get("VERDICT_CLOSURE_DECISIONS",
                           os.path.join(REPO, "iterations", "DECISIONS_NEEDED.md"))

NAME_NOTICE = 12   # 铁律 9: 12 轮零推进 -> 报告红色升级并指名下一步
DECISIONS_NOTICE = 24  # 铁律 9: 24 轮零推进 -> 写进 DECISIONS_NEEDED

STAMP_RE = re.compile(
    r"(20\d\d)-([0-9x]{2})-([0-9x]{2})T([0-9x]{2}):([0-9x]{2})(?::([0-9x]{2}))?Z"
    r"[^\n]{0,60}?的变动")
CLOSURE_RE = re.compile(r"判定完结\s*\*{0,2}\s*(\d+)")
REPORT_RE = re.compile(r"^(\d{8}T\d{6}Z)\.md$")


def resolve_earliest(m):
    """Masked digits -> the earliest instant the stamp can mean (loud side)."""
    y = int(m.group(1))
    parts = []
    for i, lo in ((2, 1), (3, 1), (4, 0), (5, 0)):
        raw = m.group(i)
        if raw is None:
            parts.append(lo)
            continue
        digits = "".join(c if c.isdigit() else "0" for c in raw)
        parts.append(max(int(digits), lo))
    mo, day, hh, mi = parts
    sec_raw = m.group(6)
    sec = int("".join(c if c.isdigit() else "0" for c in sec_raw)) if sec_raw else 0
    try:
        return datetime(y, mo, day, hh, mi, sec, tzinfo=timezone.utc)
    except ValueError:
        return None


def read_anchor(path):
    """(instant, closures, raw_stamp, line_no, fuzzy) of the newest closure line."""
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        return None, "cannot read %s (%s)" % (path, exc)
    best = None
    stamped = 0
    for n, line in enumerate(lines, 1):
        m = STAMP_RE.search(line)
        if not m:
            continue
        stamped += 1
        c = CLOSURE_RE.search(line)
        if not c or int(c.group(1)) < 1:
            continue
        inst = resolve_earliest(m)
        if inst is None:
            continue
        raw = m.group(0)[:m.group(0).index("Z") + 1]
        fuzzy = "x" in raw
        cand = (inst, int(c.group(1)), raw, n, fuzzy)
        if best is None or inst > best[0]:
            best = cand
    if best is None:
        return None, ("no history line carries BOTH a `<stamp> 的变动` and "
                      "`判定完结 >= 1` (%d stamped line(s) seen)" % stamped)
    return best, None


def read_reports():
    if REPORT_LIST:
        try:
            with open(REPORT_LIST, encoding="utf-8") as fh:
                raw = [l.strip() for l in fh if l.strip()]
        except OSError as exc:
            return None, "cannot read the override list %s (%s)" % (REPORT_LIST, exc)
        src = "OVERRIDE list %s" % REPORT_LIST
    else:
        try:
            out = subprocess.run(
                ["git", "-C", REPO, "ls-tree", "-r", "--name-only", "origin/main",
                 "iterations/reports/director/"],
                capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as exc:
            return None, "git ls-tree failed (%s)" % exc
        if out.returncode != 0:
            return None, ("git ls-tree origin/main returned %d -- %s"
                          % (out.returncode, (out.stderr or "").strip()[:160]))
        raw = [l.strip() for l in out.stdout.splitlines() if l.strip()]
        src = "origin/main:iterations/reports/director/"
    stamps = []
    for p in raw:
        m = REPORT_RE.match(os.path.basename(p))
        if not m:
            continue
        try:
            stamps.append((datetime.strptime(m.group(1), "%Y%m%dT%H%M%SZ")
                           .replace(tzinfo=timezone.utc), os.path.basename(p)))
        except ValueError:
            continue
    if not stamps:
        return None, ("%s yielded 0 name-shaped director report(s) -- a corpus "
                      "that answers nothing is not a zero" % src)
    return (sorted(stamps), src), None


def uncertifiable(msg):
    print("UNCERTIFIABLE -- %s" % msg)
    print("  ⛔ This is NOT a pass.  The stall counter was not computed this "
          "round, which is a different thing from it reading 0.")
    return 2


def main():
    print("anchor source : %s" % os.path.relpath(TESTSET, REPO))
    anchor, err = read_anchor(TESTSET)
    if err:
        return uncertifiable(err)
    inst, closures, raw, line_no, fuzzy = anchor
    print("anchor        : line %d -- `%s`, 判定完结 %d" % (line_no, raw, closures))
    if fuzzy:
        print("resolve       : fuzzy stamp -> EARLIEST instant %s (loud side; the "
              "ruling's own round may be counted, over-count <= 1)"
              % inst.strftime("%Y-%m-%dT%H:%M:%SZ"))
    else:
        print("resolve       : exact stamp %s" % inst.strftime("%Y-%m-%dT%H:%M:%SZ"))

    got, err = read_reports()
    if err:
        return uncertifiable(err)
    (stamps, src) = got
    if REPORT_LIST:
        print("⚠️ corpus OVERRIDDEN by VERDICT_CLOSURE_REPORT_LIST -- this run is "
              "a test harness run, not a reading of the repo.")
    since = [n for t, n in stamps if t > inst]
    print("denominator   : %s, %d name-shaped report(s), %d newer than the anchor"
          % (src, len(stamps), len(since)))
    print("              ⛔ report names are the DENOMINATOR ONLY -- filing one "
          "can never satisfy this leg (RULING 73 ⑧(b)).")
    if since:
        print("newest        : %s" % since[-1])
    stall = len(since)
    print("STALL         : %d director round(s) with no 判定完结 "
          "(thresholds: %d 点名 / %d DECISIONS_NEEDED)"
          % (stall, NAME_NOTICE, DECISIONS_NOTICE))

    if stall < NAME_NOTICE:
        print("\nthe armed set closed a verdict within the last %d round(s) -- OK"
              % NAME_NOTICE)
        return 0

    esc = "DECISIONS_NEEDED" if stall >= DECISIONS_NOTICE else "点名"
    print("\nFINDING: %d director round(s) since the last 判定完结 -- iron rule 9 "
          "escalation level: %s." % (stall, esc))
    print("  ⛔ 该组 = THE DIRECTOR SEAT ITSELF.  This leg exists because that "
          "made the rule an open circuit (RULING 73 §HN.4-bis).")
    try:
        with open(DECISIONS, encoding="utf-8") as fh:
            body = fh.read()
        carried = "判定完结" in body
    except OSError:
        carried = None
    if carried is True:
        print("  note: `%s` already carries a 判定完结 line (cross-read, not a "
              "judgement that it is the right line)."
              % os.path.relpath(DECISIONS, REPO))
    elif carried is False:
        print("  note: `%s` carries NO 判定完结 line."
              % os.path.relpath(DECISIONS, REPO))
    else:
        print("  note: DECISIONS_NEEDED.md unreadable -- cross-read skipped.")
    return 3


if __name__ == "__main__":
    sys.exit(main())
