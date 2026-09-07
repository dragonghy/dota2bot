#!/usr/bin/env python3
"""arm_since.py -- how long has each armed id been armed, machine-readably.

WHY THIS EXISTS
---------------
OWNER_PRIORITIES P4.2 says to clear the armed set "从核验记录最少、最难买 (a)
的 id 清起".  "How long has it been armed" is the other half of that sort key,
and on 2026-09-07T10:00Z the director round found it was **left-truncated in
this container**: the answer was being read off `git log` of
`iterations/streams/test_set.md`, and a routine container is a shallow clone --
after `--deepen=400` the file's history still started at 2026-08-30, so 40 of
51 ids answered "unknown" for a reason that is a property of the CLONE, not of
the lab.  (Same family as the `arm_md5` back-lookup in test_set.md §FQ.2, which
had to deepen before it could resolve eight of ten waves.)

The fix is to stop asking git.  Admissions are recorded in prose that ships
inside the repo at full length:

  A. `iterations/streams/test_set.md` -- the 入集 sections (authoritative; this
     is the source the 2026-09-07T13:31Z handoff named).
  B. `iterations/reports/director/<UTC>.md` -- the ruling reports.  The
     FILENAME is the timestamp, so this source cannot drift even if the prose
     is later rewritten, and the archive on disk starts 2026-08-19T00:53Z.
  C. `iterations/armed_since.json` -- the pinned registry this tool reads and
     checks.  Ids older than source B's archive (the July bundle) carry a
     `lower_bound` precision plus the state.json key that proves the bound.

WHAT IT IS NOT
--------------
* It does NOT say an id is stale, worth keeping, or worth 退集.  It answers one
  question: since when.  The verdict is the director's.
* `lower_bound` rows mean "armed AT LEAST this long".  They are floors, never
  equalities (GH #106 house rule); a floor is still a true reading and it is
  the one P4.2 sorts on, because those rows sort oldest either way.
* Deriving a date from prose is best-effort.  A derived date NEVER silently
  overwrites the registry: a disagreement is reported and raises the exit code,
  because "the archive got rewritten" and "the registry is wrong" look the same
  from here and only a human can tell them apart.

EXIT CODES (evidence discipline: a tool that could not run must not read as a pass)
  0  every armed id is pinned and no derived date contradicts its pin
  2  could not run (input missing/unreadable)
  3  findings: an armed id with no registry row, a contradiction, or a stale row
"""

import json
import os
import re
import sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEST_SET = os.path.join(ROOT, "iterations", "streams", "test_set.md")
REPORT_DIR = os.path.join(ROOT, "iterations", "reports", "director")
REGISTRY = os.path.join(ROOT, "iterations", "armed_since.json")

DATE_RE = re.compile(r"(20\d\d-\d\d-\d\d)T")
ID_RE = re.compile(r"`([a-z][a-z0-9_]{2,})`")
FNAME_RE = re.compile(r"^(20\d{6})T(\d{2})")

# An admission EVENT is written `<id>` 入集** or `<id>` 入集( -- the bolded /
# parenthesised form.  Prose that merely mentions 入集 ("`slotarb` 的入集是条件性
# 的", "不提入集", "重新入集路径") is not an event and must not be counted; those
# lines are the reason this is a form match and not a keyword match.
NEG_BEFORE = ("重新", "不提", "未来", "将来", "再", "该")
NEG_NEAR = ("退集", "出集")


def _fail(msg):
    print("UNCERTIFIABLE -- %s. This is NOT a pass." % msg)
    sys.exit(2)


def scan_text(text, armed):
    """Yield (id, date_or_None, line_no) admission events found in `text`."""
    out = []
    cur_date = None
    for lineno, line in enumerate(text.split("\n"), 1):
        dates = DATE_RE.findall(line)
        if dates:
            cur_date = dates[0]
        for m in re.finditer("入集", line):
            s, e = m.span()
            tail = line[e:e + 2]
            if not (tail.startswith("**") or tail[:1] in ("(", "(")):
                continue
            pre = line[max(0, s - 90):s]
            if line[max(0, s - 2):s].endswith(NEG_BEFORE):
                continue
            if any(n in pre[-40:] for n in NEG_NEAR):
                continue
            ids = [t for t in ID_RE.findall(pre) if t in armed]
            for i in dict.fromkeys(ids):
                out.append((i, dates[0] if dates else cur_date, lineno))
    return out


def derive(armed):
    """{id: (date, source)} -- earliest evidence wins per source, A beats B."""
    found = {}
    try:
        ts_text = open(TEST_SET, encoding="utf-8").read()
    except OSError as exc:
        _fail("cannot read %s (%s)" % (TEST_SET, exc))
    for i, date, lineno in scan_text(ts_text, armed):
        if date and i not in found:
            found[i] = (date, "test_set.md:%d" % lineno)

    if os.path.isdir(REPORT_DIR):
        for fn in sorted(os.listdir(REPORT_DIR)):
            if not fn.endswith(".md"):
                continue
            m = FNAME_RE.match(fn)
            if not m:
                continue
            date = "%s-%s-%s" % (m.group(1)[:4], m.group(1)[4:6], m.group(1)[6:8])
            try:
                text = open(os.path.join(REPORT_DIR, fn), encoding="utf-8",
                            errors="replace").read()
            except OSError:
                continue
            for i, _d, _ln in scan_text(text, armed):
                if i not in found:
                    found[i] = (date, "reports/director/%s" % fn)

    # C. state.json keys are conventionally `<id>_<YYYYMMDD>` (campsel_20260824,
    #    slotdust_20260902, ...).  Weakest of the three -- the key's date is the
    #    day the LANDING/verdict was archived, which is the admission day only
    #    because admission rulings are archived the day they are made.  Used
    #    only for ids neither A nor B can see.
    try:
        state = json.load(open(os.path.join(ROOT, "iterations", "state.json"),
                               encoding="utf-8"))
    except (OSError, ValueError):
        state = {}
    for key in sorted(state):
        m = re.match(r"^([a-z][a-z0-9_]{2,})_(20\d{2})(\d{2})(\d{2})", key)
        if not m:
            continue
        i = m.group(1)
        if i in armed and i not in found:
            found[i] = ("%s-%s-%s" % (m.group(2), m.group(3), m.group(4)),
                        "state.json:%s" % key)
    return found


def main():
    argv = sys.argv[1:]
    show_all = "--all" in argv

    try:
        lines = open(TEST_SET, encoding="utf-8").read().split("\n")
        armed = [x.strip() for x in lines[1].split(",") if x.strip()]
    except (OSError, IndexError) as exc:
        _fail("cannot read the armed string from %s (%s)" % (TEST_SET, exc))
    if not armed:
        _fail("the armed string parsed to zero ids")

    try:
        reg = json.load(open(REGISTRY, encoding="utf-8"))
    except OSError as exc:
        _fail("cannot read %s (%s)" % (REGISTRY, exc))
    except ValueError as exc:
        _fail("%s is not valid JSON (%s)" % (REGISTRY, exc))
    rows = reg.get("ids", {})

    derived = derive(armed)
    today = datetime.now(timezone.utc).date()
    findings = []

    table = []
    for i in armed:
        row = rows.get(i)
        if not row:
            findings.append(
                "UNPINNED: `%s` is armed and has no row in armed_since.json "
                "(derived: %s). Admitting an id without registering its arming "
                "time is what this leg exists to catch."
                % (i, derived.get(i, ("-", "-"))[0]))
            table.append((None, i, "-", "?", "UNPINNED"))
            continue
        since = row.get("armed_since", "")
        prec = row.get("precision", "exact")
        try:
            d = datetime.strptime(since[:10], "%Y-%m-%d").date()
        except ValueError:
            findings.append("UNREADABLE: `%s` armed_since=%r" % (i, since))
            table.append((None, i, since, "?", "UNREADABLE"))
            continue
        days = (today - d).days
        dv = derived.get(i)
        note = prec
        if dv and prec == "exact" and dv[0] != since[:10]:
            findings.append(
                "CONTRADICTION: `%s` pinned %s, prose says %s (%s). The pin is "
                "NOT auto-corrected -- decide which source moved."
                % (i, since[:10], dv[0], dv[1]))
            note = "CONTRADICTED"
        table.append((d, i, since[:10], days, note))

    for i in rows:
        if i not in armed and not rows[i].get("retired_at"):
            findings.append(
                "STALE ROW: `%s` has a row but is not in the armed string; a "
                "退集/promote must stamp `retired_at` on its row." % i)

    table.sort(key=lambda r: (r[0] is not None, r[0] or ""))
    print("armed ids: %d   pinned: %d   registry: %s"
          % (len(armed), sum(1 for r in table if r[4] != "UNPINNED"),
             os.path.relpath(REGISTRY, ROOT)))
    print()
    print("%-16s %-12s %6s  %s" % ("id", "armed_since", "days", "precision"))
    shown = table if show_all else table[:20]
    for _d, i, since, days, note in shown:
        print("%-16s %-12s %6s  %s" % (i, since, days, note))
    if not show_all and len(table) > len(shown):
        print("... %d more (--all)" % (len(table) - len(shown)))

    print()
    print("LIMITS, so these numbers are not over-read:")
    print("  * a `lower_bound` row is a FLOOR ('armed at least since'), never an")
    print("    equality -- those ids predate the director report archive")
    print("    (starts 2026-08-19T00:53Z) and their bound comes from a pinned")
    print("    state.json wave record that quotes the arm string of that day.")
    print("  * days armed is NOT evidence about an id's quality. It is one half")
    print("    of P4.2's sort key; the other half is verify_coverage.py.")
    print("  * an id 退集'd and later re-admitted keeps ONE row: `armed_since`")
    print("    is the CURRENT stint, and the previous one moves to `history`.")

    if findings:
        print()
        print("FINDINGS -- %d:" % len(findings))
        for f in findings:
            print("  " + f)
        sys.exit(3)
    sys.exit(0)


if __name__ == "__main__":
    main()
