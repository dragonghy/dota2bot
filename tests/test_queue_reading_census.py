#!/usr/bin/env python3
"""[ratchet] tools/agent/queue_reading_census.py -- the four ways it can lie.

WHY EACH CHECK EXISTS (a check without a failure mode is decoration).

1. A SPENT ROW MUST LEAVE THE CANDIDATE LIST, AND A ROW WITH NO `status` MUST
   BE A FINDING.  The tool exists because backlog `-135`/`-136`/`-137` selected
   three rounds of work with "status != done and result non-empty".  On
   2026-09-10 three rows carried no `status` key at all -- and one of them,
   `hero-37`, was the row the round before had just SPENT.  Missing-key and
   not-done are the same thing to that criterion, so the spent row stays
   selectable forever.  Checks 1a/1b/1c pin both directions: the stamped row
   drops out, the unstamped row is named, and the exit code is 3.

2. THE WEAK FORM OF "THE SAME READING ON SEVERAL ROWS" MUST NOT BE THE ONLY
   FORM.  Hashing the whole `result` finds only rows that are byte-identical
   (`hero-24`/`hero-25`).  The real shape is a harvest paragraph APPENDED to
   rows that already carry different heads -- `hero-23` and `hero-29` hold the
   same W53 reading and hash differently.  Check 2 builds exactly that shape
   and fails if only the whole-text grouping fires.  Counting those rows as
   separate readings is the row-count version of iron rule 4(i-a): reporting
   the number of rows when the question asked for the reading.

3. A DUPLICATE THAT IS TOO SHORT TO BE A READING MUST STAY QUIET.  The same
   section, fed a repeated date stamp or a bare `pending`, would fire on every
   row of the file -- and a section that is always full is a section nobody
   reads, which is the failure iron rule 10 was written against.

4. AN UNDECIDED LABEL MUST SAY SO.  A tie between two marker classes is
   AMBIGUOUS, never the class that happens to be checked first: a label that
   looks decided and is not is what `citation_audit.py` had to grow its own
   AMBIGUOUS verdict for.  Check 4 also pins that the MARKERS are printed --
   a class whose evidence is invisible cannot be checked by the round that
   reads it.

WHAT THIS FILE DOES NOT ASSERT: that any CLASS on the real queue is the right
reading of that row.  The tool reads prose; prose lies (`hero-1` carries frame
and percent markers on a paragraph the backlog records as a RULING).  What is
pinned is that the label always arrives with the markers that produced it, so
the round can disagree with it in one glance.

Run: python3 tests/test_queue_reading_census.py
"""

import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "queue_reading_census.py")

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))


def build_root(tmp, rows):
    os.makedirs(os.path.join(tmp, "iterations"), exist_ok=True)
    with open(os.path.join(tmp, "iterations", "queue.json"), "w",
              encoding="utf-8") as fh:
        json.dump({"_protocol": "test", "requests": rows, "done": []}, fh,
                  ensure_ascii=False)


def run_in(tmp, *extra):
    env = dict(os.environ, QUEUE_CENSUS_ROOT=tmp)
    proc = subprocess.run([sys.executable, TOOL, "--all"] + list(extra),
                          capture_output=True, text=True, env=env)
    return proc.returncode, proc.stdout + proc.stderr


READING = ("录像组交付三列读数:118 局 / 四个 run,W 就绪 112,933 帧,"
           "1600 内敌人数 0/1/>=2 = 65.6%/14.5%/19.9%,分母见 "
           "iterations/reports/replay-check/20260906T191500Z.md")
WAVE = ("2026-09-07T15:1xZ batch-desk (W53 make-up harvest): this id rides "
        "W53's 51-id string. 3 of 4 seeds scored, gpm -6.80 / xpm -3.04, "
        "comps_better 1/3, min_arm_depth 19.29, thin_arm_seeds empty.")


def row(rid, **kw):
    base = {"id": rid, "stream": "hero", "bundle": "", "seeds": [],
            "priority": 3, "question": "q", "acceptance": "a"}
    base.update(kw)
    return base


# ---------------------------------------------------------------- check 1
with tempfile.TemporaryDirectory() as tmp:
    # distinct result texts on purpose: rows sharing one text would also show
    # up in the SHARED sections, and this check is about the CANDIDATE TABLE.
    build_root(tmp, [
        row("hero-1", status="pending", result=READING + " 一"),
        row("hero-2", status="delivered-and-consumed", result=READING + " 二"),
        row("hero-3", status="pending", result=READING + " 三",
            consumed_by_hero_20260830="report"),
        row("hero-4", result=READING + " 四"),   # no status key at all
    ])
    rc, out = run_in(tmp)
    table = [ln for ln in out.split("LIMITS")[0].split("\n")
             if ln.startswith("hero-")]
    listed = [ln.split()[0] for ln in table]
    check("1a a stamped-spent row is not a candidate",
          "hero-2" not in listed, str(listed))
    check("1a' a consumed_by_* row is not a candidate",
          "hero-3" not in listed, str(listed))
    check("1b an unstamped row is still a candidate and is named",
          "hero-4" in listed, str(listed))
    check("1c missing status => exit 3 and a NO STATUS finding naming the row",
          rc == 3 and "NO STATUS" in out and "hero-4" in out.split("FINDINGS")[-1],
          "rc=%d\n%s" % (rc, out[-400:]))
    check("1d the unspent count is the candidate count, not the row count",
          "rows: 4" in out and "candidates (unspent): 2" in out,
          out.split("\n")[0] if out else "")

# ---------------------------------------------------------------- check 2
with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, [
        row("hero-23", status="pending", result="头一段,W26 收割。 || " + WAVE),
        row("hero-29", status="pending", result="另一段,W52 收割。 || " + WAVE),
    ])
    rc, out = run_in(tmp)
    check("2a one paragraph on two rows with different heads is reported as "
          "ONE reading", "SHARED RESULT SEGMENT" in out
          and "hero-23" in out.split("SHARED RESULT SEGMENT")[-1]
          and "hero-29" in out.split("SHARED RESULT SEGMENT")[-1],
          out[-600:])
    check("2b whole-text grouping alone would MISS it (the two rows do not "
          "hash together)", "SHARED RESULT TEXT" not in out, out[-600:])
    check("2c a shared paragraph is not itself a finding",
          rc == 0, "rc=%d" % rc)

# ---------------------------------------------------------------- check 3
with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, [
        row("hero-1", status="pending", result=READING + " || 2026-09-07 登记"),
        row("hero-2", status="pending", result=WAVE + " || 2026-09-07 登记"),
    ])
    rc, out = run_in(tmp)
    check("3 a duplicate too short to be a reading does not open the section",
          "SHARED RESULT SEGMENT" not in out, out[-600:])

# ---------------------------------------------------------------- check 4
with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, [
        # one marker from each of two classes, and nothing else: a tie.
        row("hero-1", status="pending", result="裁定:见 1,234 帧。"),
        row("hero-2", status="pending", result=WAVE),
    ])
    rc, out = run_in(tmp)
    line = [ln for ln in out.split("\n") if ln.startswith("hero-1")]
    line = line[0] if line else ""
    check("4a a tie is AMBIGUOUS, not the first class checked",
          "AMBIGUOUS" in line, line or out[-400:])
    check("4b the label arrives with the markers that produced it",
          "裁定" in line and "帧" in line, line or out[-400:])
    wline = [ln for ln in out.split("\n") if ln.startswith("hero-2")]
    check("4c a wave paragraph classifies as WAVE-AGGREGATE",
          wline and "WAVE-AGGREGATE" in wline[0], wline[:1])

# ---------------------------------------------------------------- check 5
with tempfile.TemporaryDirectory() as tmp:
    build_root(tmp, [row("hero-1", status="pending", result=READING)])
    os.remove(os.path.join(tmp, "iterations", "queue.json"))
    rc, out = run_in(tmp)
    check("5a missing queue.json => could-not-run 2, not a pass", rc == 2,
          "rc=%d" % rc)
    check("5b the banner says it is not a pass", "NOT a pass" in out,
          out[-300:])

with tempfile.TemporaryDirectory() as tmp:
    os.makedirs(os.path.join(tmp, "iterations"))
    with open(os.path.join(tmp, "iterations", "queue.json"), "w",
              encoding="utf-8") as fh:
        fh.write("{not json")
    rc, out = run_in(tmp)
    check("5c unparseable queue.json => exit 2, not 0 and not 3", rc == 2,
          "rc=%d %s" % (rc, out[-200:]))

# ------------------------------------------------------------- real tree
proc = subprocess.run([sys.executable, TOOL], capture_output=True, text=True)
check("6 every hero row on the real tree carries a status (exit 0)",
      proc.returncode == 0,
      "rc=%d\n%s" % (proc.returncode, proc.stdout[-600:]))

failed = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    if not ok:
        print("FAIL  %s\n        %s" % (name, detail))
print("%d checks, %d failed" % (len(checks), len(failed)))
sys.exit(1 if failed else 0)
