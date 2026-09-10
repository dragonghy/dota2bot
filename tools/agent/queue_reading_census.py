#!/usr/bin/env python3
"""Delivered-but-unspent queue readings -- the hero backlog's own criterion,
made mechanical (hero desk, 2026-09-10).

WHY THIS EXISTS
---------------
Three consecutive hero rounds (backlog `-135` / `-136` / `-137`) selected their
work unit with the same hand-run rule:

    a `<stream>-*` row in iterations/queue.json whose `status` is not `done`
    and whose `result` already has something in it is money that was bought
    and never spent.

The rule earned its place -- it produced a `bots/` main body three times.  What
it does NOT survive is being run by hand a fourth time, for two reasons that
are properties of the FILE, not of any round:

1. A MISSING `status` IS NOT `!= done`, IT IS UNKNOWN -- and it reads as
   selectable.  On 2026-09-10 exactly three rows in the whole queue carried no
   `status` key at all, all three of them `hero-*`, and one of them (`hero-37`)
   was the row the PREVIOUS round had just spent.  A spent reading and an
   unspent one were byte-identical to the criterion, so the criterion would
   have re-selected it every round until someone noticed by memory.  Memory is
   what iron rule 9 says the relay drops.

2. THE SAME RESULT TEXT CAN SIT ON MANY ROWS.  A wave harvest writes one
   family-level paragraph (`gpm ... comps_better ...` over a 51/58-id armed
   string) into every rideshare row of that wave.  Four such rows are not four
   readings; they are ONE reading, and it prices the FAMILY, not any single id
   in it.  Counting rows there is the row-count version of the mistake iron
   rule 4(i-a) names: reporting the number of games when the question asked for
   the reading.

WHAT IT PRINTS
--------------
One line per candidate row (result present, not marked spent), carrying:

  CLASS      the evidence-based guess at what the result IS --
             DOMAIN-READING (frames/episodes/instants with denominators),
             WAVE-AGGREGATE (five-metric wave verdict over an armed string),
             RULING (a routing/verdict sentence with no measured quantity),
             or AMBIGUOUS when the top two classes tie.  The markers that
             fired are printed with it: a label whose evidence is not visible
             is a label the next round cannot check.
  GROUP      rows whose result text is identical are stamped with a shared
             group tag.  `g2:3` means "text group 2, shared by 3 rows".

FINDINGS (exit 3) ARE ONLY THE SCHEMA HOLE -- a row with no `status` key.  That
one is mechanical, is fixable by the desk that owns the row in the round it is
found, and cannot be argued with.  Everything else here is INFORMATION for the
round's own judgement: a classifier that could veto a work unit would be a
prose parser deciding what gets worked on, and this file's own LIMITS section
says why it must not be trusted that far.

Exit codes follow the repo's 0/2/3 vocabulary (GH #171, #205, #213):
    0  clean          every row carries a status
    2  could not run  queue.json missing or unparseable  (NOT a pass)
    3  findings       at least one row carries no status

Usage:
    python3 tools/agent/queue_reading_census.py [--stream hero] [--all]
"""
import hashlib
import json
import os
import re
import sys

_DEFAULT_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
# Overridable so tests/test_queue_reading_census.py can stand up a throwaway
# tree and drive every branch.  Announced on every run, for the same reason
# py_gate.py announces its own override: a tool that can be pointed elsewhere
# quietly is a tool that can be dodged quietly.
ROOT = os.environ.get("QUEUE_CENSUS_ROOT") or _DEFAULT_ROOT
QUEUE = os.path.join(ROOT, "iterations", "queue.json")

# A row is SPENT when it says so in the vocabulary the queue already uses.
# `done` is the batch desk's word; `delivered-and-consumed` is the word the
# hero desk stamped on hero-31 and hero-35 after spending them.  No new word is
# invented here -- GH #317 (vocabulary drift) is what a fourth synonym costs.
SPENT_STATUSES = ("done", "delivered-and-consumed", "rejected")

# A shared paragraph is only worth reporting when it is long enough to BE a
# reading.  Short duplicates (`pending`, a date stamp, a bare wave id) would
# turn the section into noise, and a section that is always full is a section
# nobody reads -- the failure mode iron rule 10 was written against.
MIN_SHARED_SEGMENT = 120

# Markers are deliberately SHAPE words, not id names: a class inferred from
# which id the row is about would answer with the question.
MARKERS = {
    "WAVE-AGGREGATE": [
        r"comps_better", r"per_seed", r"min_arm_depth", r"thin_arm_seeds",
        r"\bgpm\b", r"\bxpm\b", r"winrate", r"\bW\d+\b.{0,40}(收割|harvest)",
        r"seeds? scored", r"\d/\d seeds",
    ],
    "DOMAIN-READING": [
        r"\d[\d,]*\s*帧", r"\bepisode", r"\binstants?\b", r"域读数",
        r"iterations/reports/(replay-check|hero)/", r"\d+\s*/\s*\d+\s*局",
        r"\d+(\.\d+)?%", r"分母",
    ],
    "RULING": [
        r"裁定", r"ROUTED_", r"APPROVED", r"FROZEN-HOLD", r"UNINTERPRETABLE",
        r"结构上(买不到|拿不到)", r"结构性空集", r"不请求入集", r"登记不改状态",
    ],
}


def classify(text):
    """Return (label, evidence) -- evidence is the markers that actually fired.

    A tie between the top two classes is AMBIGUOUS on purpose.  The alternative
    (break the tie by marker order, or by which class was checked first) is a
    label that looks decided and is not, which is the shape citation_audit.py
    had to grow an AMBIGUOUS verdict for.
    """
    hits = {}
    for label, patterns in MARKERS.items():
        fired = [p for p in patterns if re.search(p, text)]
        if fired:
            hits[label] = fired
    if not hits:
        return "UNCLASSIFIED", {}
    ranked = sorted(hits.items(), key=lambda kv: (-len(kv[1]), kv[0]))
    if len(ranked) > 1 and len(ranked[0][1]) == len(ranked[1][1]):
        return "AMBIGUOUS", hits
    return ranked[0][0], hits


def result_text(row):
    r = row.get("result")
    if r is None:
        return ""
    if not isinstance(r, str):
        r = json.dumps(r, ensure_ascii=False)
    return r.strip()


def main():
    args = sys.argv[1:]
    stream = "hero"
    show_all = False
    while args:
        a = args.pop(0)
        if a == "--stream":
            stream = args.pop(0) if args else stream
        elif a == "--all":
            show_all = True
        else:
            print("unknown argument: %s" % a)
            sys.exit(2)

    if ROOT != _DEFAULT_ROOT:
        print("NOTE: QUEUE_CENSUS_ROOT override in effect -- reading %s" % ROOT)

    try:
        with open(QUEUE, encoding="utf-8") as fh:
            doc = json.load(fh)
        rows = doc["requests"]
        if not isinstance(rows, list):
            raise ValueError("`requests` is not a list")
    except Exception as exc:                                # noqa: BLE001
        print("COULD NOT RUN (exit 2, NOT a pass): %s -- %s"
              % (os.path.relpath(QUEUE, ROOT), exc))
        sys.exit(2)

    prefix = stream + "-" if stream != "*" else ""
    mine = [r for r in rows
            if isinstance(r, dict) and str(r.get("id", "")).startswith(prefix)]

    # group identical result texts BEFORE selecting, so a shared wave paragraph
    # is visible as one reading even when only some of its rows are candidates.
    groups = {}
    for row in mine:
        text = result_text(row)
        if text:
            groups.setdefault(hashlib.md5(text.encode("utf-8")).hexdigest(),
                              []).append(row.get("id"))
    tags = {}
    for n, (digest, ids) in enumerate(
            sorted(groups.items(), key=lambda kv: (-len(kv[1]), kv[0])), 1):
        for i in ids:
            tags[i] = ("g%d:%d" % (n, len(ids)), len(ids))

    # Whole-text identity is the weak form of the same question: a harvest
    # round appends its paragraph to rows that already carry different heads,
    # so two rows can hold THE SAME reading and hash differently.  Segments are
    # what the desk would actually be spending, so they are grouped too.
    segments = {}
    for row in mine:
        rid = row.get("id")
        for seg in re.split(r"\|\|", result_text(row)):
            seg = re.sub(r"\s+", " ", seg).strip()
            if len(seg) >= MIN_SHARED_SEGMENT:
                digest = hashlib.md5(seg.encode("utf-8")).hexdigest()
                bucket = segments.setdefault(digest, {"ids": [], "seg": seg})
                if rid not in bucket["ids"]:
                    bucket["ids"].append(rid)

    with_result = [r for r in mine if result_text(r)]

    findings = []
    candidates = []
    for row in mine:
        rid = row.get("id")
        text = result_text(row)
        if "status" not in row:
            findings.append(
                "NO STATUS: `%s` carries no `status` key.  The backlog "
                "criterion reads that as `!= done` and re-selects the row "
                "forever -- stamp it (%s) or `pending`."
                % (rid, "/".join(SPENT_STATUSES)))
        status = row.get("status")
        spent = status in SPENT_STATUSES or any(
            k.startswith("consumed_by") for k in row)
        if text and not spent:
            label, evidence = classify(text)
            candidates.append((rid, status, label, evidence, tags.get(rid)))

    print("stream: %s   rows: %d   with a result: %d   candidates (unspent): %d"
          % (stream, len(mine), len(with_result), len(candidates)))
    print()
    print("%-10s %-32s %-16s %s" % ("id", "status", "class", "group  markers"))
    shown = candidates if show_all else candidates[:25]
    for rid, status, label, evidence, tag in shown:
        markers = ", ".join(sorted(
            m for fired in evidence.values() for m in fired))[:60]
        print("%-10s %-32s %-16s %-7s %s"
              % (rid, status if status is not None else "(none)", label,
                 tag[0] if tag else "-", markers))
    if not show_all and len(candidates) > len(shown):
        print("... %d more (--all)" % (len(candidates) - len(shown)))

    shared = sorted(((tags[ids[0]][0], ids)
                     for ids in groups.values() if len(ids) > 1),
                    key=lambda pair: pair[0])
    if shared:
        print()
        print("SHARED RESULT TEXT -- one reading, several rows:")
        for tag, ids in shared:
            print("  %-7s %s" % (tag, ", ".join(str(i) for i in ids)))

    shared_segs = sorted((b for b in segments.values() if len(b["ids"]) > 1),
                         key=lambda b: (-len(b["ids"]), b["seg"][:40]))
    if shared_segs:
        print()
        print("SHARED RESULT SEGMENT -- the same paragraph on several rows "
              "(one reading, N rows; it prices what the paragraph is about, "
              "not each id):")
        for bucket in shared_segs:
            print("  %d rows: %s" % (len(bucket["ids"]),
                                     ", ".join(str(i) for i in bucket["ids"])))
            print("      %s..." % bucket["seg"][:88])

    print()
    print("LIMITS, so this table is not over-read:")
    print("  * CLASS is evidence about the TEXT, never about the id.  A wave")
    print("    paragraph pasted onto a domain-scan row still reads")
    print("    WAVE-AGGREGATE, and that is the point: what is on the row is")
    print("    what the next round would actually get to spend.")
    print("  * A row can be spent WITHOUT its status moving (a round that")
    print("    consumed it and forgot to stamp).  This tool cannot see that;")
    print("    it can only see that the stamp is missing, which is why the")
    print("    missing-status finding is the one thing it escalates.")
    print("  * `result` non-empty is not `question` answered.  Several rows")
    print("    carry only a denominator, or only the requester's own note.")

    if findings:
        print()
        print("FINDINGS -- %d:" % len(findings))
        for f in findings:
            print("  " + f)
        sys.exit(3)
    sys.exit(0)


if __name__ == "__main__":
    main()
