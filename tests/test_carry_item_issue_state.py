#!/usr/bin/env python3
"""Acceptance for the carry-item issue-state cross-read (RULING 63 / owed row
`carry_item_issue_state_crossread`).

THE INCIDENT THIS PINS
----------------------
The director charter's『下次触发』list is copied forward every round.  On
2026-09-16T04:05Z item ⑦ read, verbatim, `GH #523(连续第十轮未取)` — and
**#523 had been closed since 2026-09-08T13:12:53Z**.  Ten rounds of a counter
going up, attached to a name that was already settled; and inside that same
closed issue sat a second item that had had no machine-readable registration
since 09-05, invisible to the whole team for 11 days.

**一个已完成的名字在攒紧迫感,一件真未完的事在无人看见 —— 两者是同一次抄写的两面。**

This leg answers only the first half, and the tests below require it to keep
saying so: STALE-CARRY must never read as "that work is done".

FIRST LIVE READING (2026-09-16T10:0xZ, the round that landed this) — the
exposure was not one item: of the 4 refs in the newest carry list, **two** were
closed.  `#523` was the known one; **`#538` (closed 2026-09-05T23:40:50Z,
carried 10.3 days later)** nobody had noticed, and it is only reachable at all
because a chained `GH #538 / #528` ref counts as two.

THE LOAD-BEARING CLAIMS
-----------------------
  1. a closed carried ref is a FINDING (exit 3), printed with its number and
     the time it closed;
  2. an open carried ref is not;
  3. a ref the corpus does not contain reads UNCERTIFIABLE (exit 2) — NEVER
     `open`, never a finding.  RULING 55: a list read that misses a number
     proves nothing about that number;
  4. no corpus / unparseable corpus / STALE corpus / future-dated corpus all
     withhold findings entirely.  The stale case is the direction guard: a
     stale corpus can call a REOPENED issue closed, and someone would then
     strike a live todo off the list;
  5. anti-empty-match: a carry list with zero refs exits 2, not 0.  "nothing
     closed" and "the regex matched nothing" must not print the same;
  6. scope: only the『下次触发』segment of the NEWEST entry is in play.  A
     closed issue named in the narrative body, or in an older entry's list, is
     not a finding — `--entries N` is how you reach back on purpose;
  7. chained refs (`GH #538 / #528`) count; a bare `#77` does not.  Both
     directions are asserted: widening this regex to every `#<n>` would dilute
     the finding, and a stable false positive is how a detector stops being
     read (GH #276);
  8. the finding text names the remedy (strike the name, or register the
     remaining work as a machine-read owed row) and explicitly denies that a
     closed issue means the work is finished.  Without this the leg would
     teach exactly the mistake #523 is made of;
 10. (RULING 67, 2026-09-16T19:0xZ) a newest entry that ends with **no**
     『下次触发』list is a FINDING (exit 3), not UNCERTIFIABLE, and the leg
     falls back to the last entry that does carry one.

     The incident: entry `2026-09-16T15:55Z` (RULING 66) ended without a list.
     The next round ran this leg and read back three true lines that add up to
     "nothing to check here" — `no『下次触发』segment` / `0 carry segment(s),
     0 GH ref(s)` / `UNCERTIFIABLE ... (anti-empty-match)` — while the truth
     was that the 13:18Z list (10 items, `GH #810/#240/#528`) had stopped being
     cross-read by anything.  **A missing corpus is "nobody could look this
     round"; a missing list is "the baton was dropped" — the first fixes itself
     next round and the second does not, so they must not share an exit code.**

     The fallback is not a violation of claim 6 but its premise failing: an old
     list is superseded by the NEXT LIST, not by the next round.  When no next
     list was written, the old one is still the live baton and reading it is
     the correct scope.  And NO-HANDOFF stands on its own — exit 3 even when
     every ref in the fallen-back list is open, because what needs fixing is
     this round writing a list.

  9. two corpus shapes this repo actually writes, both found by running the
     leg on the real charter rather than by reading it: an entry stamped
     `T10:1xZ` (fuzzy minute digits) is parsed, and the carry segment is the
     entry's LAST『下次触发』, because the narrative routinely discusses the
     list before the list appears.  A digits-only entry regex reads the
     PREVIOUS round's list while printing an identical-looking clean line; a
     first-occurrence segment pulls the whole narrative into scope and
     manufactured three false findings on the round that landed this.

Run:  python3 tests/test_carry_item_issue_state.py
"""

import datetime
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "agent", "carry_item_issue_state.py")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)


def load_module():
    spec = importlib.util.spec_from_file_location("carry_item_issue_state", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


NOW = datetime.datetime(2026, 9, 16, 12, 0, 0, tzinfo=datetime.timezone.utc)

CHARTER = """# 总监章程

## 当前状态(每次触发后更新)
- **2026-09-16T10:1xZ**:立案正文点名 GH #900(叙事引用,不是待办)。
  正文谈论『下次触发』这件事本身,顺带引用 GH #901。
  **下次触发**:①GH #523 ②GH #810 ③GH #538 / #528 ④裸号 #77
- **2026-09-16T04:05Z**:上一轮。
  **下次触发**:①GH #902(旧清单,默认不看)

## 别的节
这一节里的 GH #903 永远不该被扫到。
"""

CHARTER_NO_REFS = """# x

## 当前状态(每次触发后更新)
- **2026-09-16T07:02Z**:本轮。
  **下次触发**:①把 `walk_farm` 的读数量出来 ②看守自检那三条 python 用例

## 别的节
"""

CORPUS = {
    "fetched_at": "2026-09-16T11:00:00Z",
    "issues": {
        "523": {"state": "closed", "closed_at": "2026-09-08T13:12:53Z"},
        "538": {"state": "closed", "closed_at": "2026-09-05T23:40:50Z"},
        "810": {"state": "open"},
        "528": {"state": "OPEN"},
        "900": {"state": "closed", "closed_at": "2026-09-01T00:00:00Z"},
        "901": {"state": "closed", "closed_at": "2026-09-01T00:00:00Z"},
        "902": {"state": "closed", "closed_at": "2026-09-01T00:00:00Z"},
        "903": {"state": "closed", "closed_at": "2026-09-01T00:00:00Z"},
        "77": {"state": "closed", "closed_at": "2026-09-01T00:00:00Z"},
    },
}


def write(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def write_json(path, blob, raw=None):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(raw if raw is not None else json.dumps(blob))


def main():
    mod = load_module()
    root = tempfile.mkdtemp(prefix="carryitem-test-")
    try:
        charter = os.path.join(root, "director.md")
        no_refs = os.path.join(root, "director_norefs.md")
        corpus = os.path.join(root, "corpus.json")
        write(charter, CHARTER)
        write(no_refs, CHARTER_NO_REFS)
        write_json(corpus, CORPUS)

        # --- claims 1, 2, 3, 7, 8 -------------------------------------------
        rc, lines = mod.audit(charter, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 3, "claim 1: a closed carried ref exits 3 (got %d)" % rc)
        check("STALE-CARRY   GH #523 closed 2026-09-08T13:12:53Z" in body,
              "claim 1: the finding names the number and when it closed")
        check("STALE-CARRY   GH #538" in body,
              "claim 1: every closed carried ref is reported, not just the first")
        check("2026-09-16T10:1xZ" in body,
              "claim 1: the finding names the entry that carried it")
        # claim 9 (both of these were found by running the leg on the REAL charter,
        # not by reading it): the newest entry's stamp is routinely written with
        # `x` in the minute digits (`T10:1xZ`), and an entry's NARRATIVE often
        # discusses『下次触发』before the list itself appears.  A digits-only entry
        # regex silently reads the PREVIOUS round's list and looks identical; a
        # first-occurrence segment drags the whole narrative into scope.
        check("STALE-CARRY   GH #523" in body,
              "claim 9a: an entry stamped `T10:1xZ` is parsed, not skipped")
        check("#901" not in body,
              "claim 9b: an earlier『下次触发』mention in the narrative does not "
              "widen the segment (the list is the entry's TAIL)")
        check("STALE-CARRY   GH #810" not in body and "STALE-CARRY   GH #528" not in body,
              "claim 2: open refs are not findings")
        check("GH #810" in body and "GH #528" in body,
              "claim 2: open refs are still printed (the denominator is shown)")
        check("GH #528" in body,
              "claim 7: a chained `/ #<n>` ref is taken (the #538 / #528 shape)")
        check("#77" not in body,
              "claim 7 (reverse): a bare `#<n>` is NOT taken")
        check("不是说那件事做完了" in body,
              "claim 8: the finding denies that a closed issue means work done")
        check("owed" in body,
              "claim 8: the finding names the registration remedy")

        # --- claim 3: absent from corpus is UNCERTIFIABLE, never open --------
        thin = os.path.join(root, "thin.json")
        write_json(thin, {"fetched_at": "2026-09-16T11:00:00Z",
                          "issues": {"810": {"state": "open"}}})
        rc, lines = mod.audit(charter, thin, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 2, "claim 3: an unlisted ref exits 2, not 0 and not 3 (got %d)" % rc)
        check("UNCERTIFIABLE GH #523" in body,
              "claim 3: the unlisted ref is named as unverified")
        check("STALE-CARRY" not in body,
              "claim 3: absence from a list read never becomes an accusation")
        check("NOT the same claim as `open`" in body,
              "claim 3: the printout says what absence does not mean")

        # --- claim 4: four ways the corpus withholds ------------------------
        missing = os.path.join(root, "nope.json")
        rc, lines = mod.audit(charter, missing, 1, 48.0, now=NOW)
        check(rc == 2 and "STALE-CARRY" not in "\n".join(lines),
              "claim 4a: a missing corpus withholds findings (got %d)" % rc)

        broken = os.path.join(root, "broken.json")
        write_json(broken, None, raw="{not json")
        rc, lines = mod.audit(charter, broken, 1, 48.0, now=NOW)
        check(rc == 2 and "STALE-CARRY" not in "\n".join(lines),
              "claim 4b: an unparseable corpus withholds findings (got %d)" % rc)

        stale = os.path.join(root, "stale.json")
        blob = dict(CORPUS)
        blob["fetched_at"] = "2026-09-10T11:00:00Z"
        write_json(stale, blob)
        rc, lines = mod.audit(charter, stale, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 2, "claim 4c: a stale corpus withholds findings (got %d)" % rc)
        check("STALE-CARRY" not in body,
              "claim 4c: THE direction guard -- a stale corpus can accuse a reopened issue")
        check("old" in body,
              "claim 4c: the age is printed, so the withholding can be checked")
        # and it is a guard, not a constant refusal: the same corpus, fresh, fires.
        rc, _ = mod.audit(charter, stale, 1, 200.0, now=NOW)
        check(rc == 3,
              "claim 4c: widening --max-age-hours lets the same corpus answer "
              "(the guard is a guard, not a permanent refusal)")

        future = os.path.join(root, "future.json")
        blob = dict(CORPUS)
        blob["fetched_at"] = "2026-09-20T11:00:00Z"
        write_json(future, blob)
        rc, lines = mod.audit(charter, future, 1, 48.0, now=NOW)
        check(rc == 2 and "STALE-CARRY" not in "\n".join(lines),
              "claim 4d: a future-dated corpus withholds findings (got %d)" % rc)

        nomap = os.path.join(root, "nomap.json")
        write_json(nomap, {"fetched_at": "2026-09-16T11:00:00Z"})
        rc, lines = mod.audit(charter, nomap, 1, 48.0, now=NOW)
        check(rc == 2 and "STALE-CARRY" not in "\n".join(lines),
              "claim 4e: a corpus with no `issues` map withholds findings (got %d)" % rc)

        # a state string that is neither open nor closed is unverified, not open
        weird = os.path.join(root, "weird.json")
        write_json(weird, {"fetched_at": "2026-09-16T11:00:00Z",
                           "issues": {"523": {"state": "merged"},
                                      "538": {"state": "open"},
                                      "810": {"state": "open"},
                                      "528": {"state": "open"}}})
        rc, lines = mod.audit(charter, weird, 1, 48.0, now=NOW)
        check(rc == 2 and "UNCERTIFIABLE GH #523" in "\n".join(lines),
              "claim 4f: an unrecognised state reads UNCERTIFIABLE, not open (got %d)" % rc)

        # --- claim 5: anti-empty-match --------------------------------------
        rc, lines = mod.audit(no_refs, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 2, "claim 5: a carry list with zero refs exits 2, not 0 (got %d)" % rc)
        check("anti-empty-match" in body,
              "claim 5: the printout says why an empty match is not a clean bill")
        check("0 GH ref(s)" in body,
              "claim 5: the denominator is always printed")

        # --- claim 6: scope --------------------------------------------------
        rc, lines = mod.audit(charter, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check("#900" not in body and "#901" not in body,
              "claim 6: closed refs in the narrative body are out of scope")
        check("#903" not in body,
              "claim 6: refs outside the 当前状态 section are out of scope")
        check("#902" not in body,
              "claim 6: an older entry's carry list is not scanned by default")
        rc2, lines2 = mod.audit(charter, corpus, 2, 48.0, now=NOW)
        check("STALE-CARRY   GH #902" in "\n".join(lines2),
              "claim 6: --entries 2 reaches the older list on purpose")
        check("2 entries (of 2)" in "\n".join(lines2),
              "claim 6: how far back it looked is printed")

        # --- claim 10: NO-HANDOFF (RULING 67) -------------------------------
        # The newest entry ends with no list at all.  Everything below the
        # entry header is narrative, and the previous round's list is still the
        # live baton.
        # ⚠️ The narrative line that mentions『下次触发』goes too: with it, the
        # entry still "has" a segment (the mark is matched anywhere) and the
        # drop is invisible.  That is a REAL hole in the marker regex, measured
        # at 0/86 occurrences on today's charter and registered as the owed row
        # `carry_mark_prose_vs_list` -- it is not asserted here because a test
        # that pins a hole goes red the day the hole is closed.
        dropped = os.path.join(root, "dropped.md")
        write(dropped, CHARTER
              .replace("  正文谈论『下次触发』这件事本身,顺带引用 GH #901。\n", "")
              .replace("  **下次触发**:①GH #523 ②GH #810 ③GH #538 / #528 ④裸号 #77",
                       "  本轮收尾没写清单。"))
        rc, lines = mod.audit(dropped, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 3,
              "claim 10a: a newest entry with no carry list exits 3, not 2 (got %d)" % rc)
        check("NO-HANDOFF" in body and "2026-09-16T10:1xZ" in body,
              "claim 10a: the finding names the entry that dropped the baton")
        check("CARRY-FROM    2026-09-16T04:05Z" in body,
              "claim 10b: the fallback names the last entry that carries a list")
        check("STALE-CARRY   GH #902" in body,
              "claim 10b: the fallen-back list is actually cross-read")
        check("1 entry back" in body and "fuzzy stamp" in body,
              "claim 10c: the distance is printed, and a stamp this repo cannot "
              "parse (`T10:1xZ`) says so instead of silently dropping the age -- "
              "'fell back 1 entry' and 'fell back 30 hours' are different readings")
        # ... and with parseable stamps the hours are actually computed.
        dropped_num = os.path.join(root, "dropped_num.md")
        write(dropped_num, open(dropped, encoding="utf-8").read()
              .replace("2026-09-16T10:1xZ", "2026-09-16T10:15Z"))
        rc, lines = mod.audit(dropped_num, corpus, 1, 48.0, now=NOW)
        check("6.2h older" in "\n".join(lines),
              "claim 10c: a parseable pair of stamps prints the real age")
        check("anti-empty-match" not in body,
              "claim 10a: a dropped baton must not print as an empty match")

        # NO-HANDOFF stands alone: exit 3 even when the fallen-back list is clean.
        clean_back = os.path.join(root, "clean_back.md")
        write(clean_back, CHARTER
              .replace("  正文谈论『下次触发』这件事本身,顺带引用 GH #901。\n", "")
              .replace("  **下次触发**:①GH #523 ②GH #810 ③GH #538 / #528 ④裸号 #77",
                       "  本轮收尾没写清单。")
              .replace("  **下次触发**:①GH #902(旧清单,默认不看)",
                       "  **下次触发**:①GH #810(仍然 open)"))
        rc, lines = mod.audit(clean_back, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 3,
              "claim 10d: NO-HANDOFF is a finding on its own -- exit 3 even when "
              "every fallen-back ref is open (got %d)" % rc)
        check("STALE-CARRY" not in body,
              "claim 10d: ... and it does not manufacture a stale-carry to get there")
        check("本轮把『下次触发』写出来" in body,
              "claim 10d: the finding names the one remedy (write the list)")

        # The corpus guards are about accusing an issue NUMBER.  They say nothing
        # about a missing list, which is read off the charter -- so a withheld
        # corpus must not swallow the NO-HANDOFF finding.
        rc, lines = mod.audit(dropped, missing, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 3,
              "claim 10e: a missing corpus withholds accusations but not the "
              "NO-HANDOFF finding (got %d)" % rc)
        check("NO-HANDOFF" in body and "STALE-CARRY" not in body,
              "claim 10e: ... the two are independent readings")

        # No entry anywhere carries a list: say so, do not crash, still exit 3.
        none_at_all = os.path.join(root, "none.md")
        write(none_at_all, CHARTER
              .replace("  正文谈论『下次触发』这件事本身,顺带引用 GH #901。\n", "")
              .replace("  **下次触发**:①GH #523 ②GH #810 ③GH #538 / #528 ④裸号 #77",
                       "  没写。")
              .replace("  **下次触发**:①GH #902(旧清单,默认不看)", "  也没写。"))
        rc, lines = mod.audit(none_at_all, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 3 and "nothing to fall back to" in body,
              "claim 10f: no list anywhere is still a finding, and says so (got %d)" % rc)

        # Both at once: baton dropped AND the fallen-back list names no issue.
        # The finding wins the exit code, and the empty-match denominator is
        # still disclosed -- neither reading is allowed to swallow the other.
        both = os.path.join(root, "both.md")
        write(both, CHARTER
              .replace("  正文谈论『下次触发』这件事本身,顺带引用 GH #901。\n", "")
              .replace("  **下次触发**:①GH #523 ②GH #810 ③GH #538 / #528 ④裸号 #77",
                       "  本轮收尾没写清单。")
              .replace("  **下次触发**:①GH #902(旧清单,默认不看)",
                       "  **下次触发**:①把 `walk_farm` 的读数量出来"))
        rc, lines = mod.audit(both, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check(rc == 3,
              "claim 10h: NO-HANDOFF plus a ref-less fallback list exits 3, because "
              "the finding does not depend on what the fallback contained (got %d)" % rc)
        check("0 GH ref(s)" in body and "回落之后仍然是 0 个 GH ref" in body,
              "claim 10h: ... and the empty-match denominator is still disclosed")

        # Direction guard: when the newest entry DOES carry a list, nothing falls
        # back -- the older list stays out of scope exactly as claim 6 requires.
        rc, lines = mod.audit(charter, corpus, 1, 48.0, now=NOW)
        body = "\n".join(lines)
        check("NO-HANDOFF" not in body and "CARRY-FROM" not in body,
              "claim 10g: the fallback fires ONLY when the newest entry has no list")
        check("#902" not in body,
              "claim 10g: ... so a superseded list is still out of scope")

        # --- CLI wiring: exit code and verdict line survive main() ----------
        # ⚠️ `main()` reads the REAL clock, so the fixture corpus above (dated
        # relative to NOW) would be withheld as future-dated here.  Stamping
        # this copy with the wall clock is the point: it proves the CLI path and
        # the audit() path agree on a corpus the freshness guard accepts.
        live = os.path.join(root, "live.json")
        blob = dict(CORPUS)
        blob["fetched_at"] = datetime.datetime.now(
            datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        write_json(live, blob)
        proc = subprocess.run(
            [sys.executable, TOOL, "--charter", charter, "--issues", live],
            capture_output=True, text=True)
        check(proc.returncode == 3,
              "CLI: main() returns the audit's exit code (got %d)" % proc.returncode)
        check("VERDICT  : FINDINGS (exit 3)" in proc.stdout,
              "CLI: the verdict line names the tri-state")
        proc = subprocess.run([sys.executable, TOOL, "--selfcheck"],
                              capture_output=True, text=True)
        check(proc.returncode == 0 and "SELFCHECK ALL PASS" in proc.stdout,
              "CLI: --selfcheck passes on this tree")
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print("\n%d checks, %d failures" % (checks, len(failures)))
    for f in failures:
        print("  FAILED: %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
