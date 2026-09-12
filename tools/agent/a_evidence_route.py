#!/usr/bin/env python3
"""For an armed id with NO condition-(a) verdict: is (a) unbuyable, or undelivered?

WHY THIS EXISTS
---------------
`verify_coverage.py` counts which armed ids carry a machine-readable VERIFY
line.  It answers "who has a verdict".  It cannot answer the question the
director actually rules on, which is the NEXT one:

    for an id with verify=0 -- is the evidence structurally unbuyable
    (=> withdraw it from the test set), or is the evidence buyable and
    simply never delivered (=> the id stays, and somebody owes a run)?

`test_set.md §FB.2` makes that distinction law -- "退集的理由与上一轮两条不同,
不许混着写" -- and it has been drawn BY HAND every round since.  Four director
rounds (§GD..§GG) each priced one or two ids by hand, and the hand-read has a
direction: §GD..§GF all ended in "买不到" because they all started from the
FIXTURE loader, which is one of the two routes to (a) and the one that is
blind most often.  The other route -- a behavioural detector over batch
replays -- lives in `tools/batch_test/behavioral/`, needs no fixture at all,
and for several of those ids ALREADY EXISTS on trunk with the id's own name on
the file.

This census reads the three facts that separate the two answers, mechanically,
for every armed id at once:

    waves     how many wave records ever carried the id in their arm string
              (i.e. does a corpus in which the id was LIVE exist at all)
    tools     which behavioural tools name the id in their docstring head
              (i.e. does an instrument that can ask the (a) question exist)
    verify    VERIFY lines, read with verify_coverage's own regex so the two
              censuses cannot drift apart

CLASSES.  Exactly one per armed id, and the classes are a partition (asserted
below, not hoped for):

    VERIFIED   verify >= 1                     nothing is owed here
    NO-CORPUS  waves == 0                      the id has never been live in a
                                               wave; (a) needs a wave BEFORE it
                                               needs an analyst
    DELIVER    corpus + a tool that DECLARES   both halves exist and nobody has
               the id in its SUBJECT line      run them together: this is a
                                               DELIVERY debt (§FB.2/§FB.3), and
                                               withdrawing such an id would be
                                               recording the wrong reason
    MENTION    corpus, and the id is named     WEAKER than DELIVER on purpose,
               only DEEPER in some tool's head and the separation is measured,
                                               not stylistic: `ownhalf` and
                                               `overchase` are named in
                                               `capmono_refusal.py` /
                                               `capmono_gradient.py` as
                                               CONFOUNDERS of capmono ("`ownhalf`
                                               ... push the other way"), which is
                                               the opposite of an instrument for
                                               them.  Collapsing this into
                                               DELIVER would have produced two
                                               owed rows pointing at tools that
                                               cannot answer.
    BUILD      corpus, no naming tool at all   the corpus exists but no
                                               instrument names the id: someone
                                               must name or build one, and THAT
                                               is the purchase, not a withdrawal

⛔ WHAT THIS TOOL DOES NOT SAY (read before quoting it in a ruling)
------------------------------------------------------------------
  * `DELIVER` is NOT a claim that the named tool answers the (a) question
    correctly, or that it was ever run to completion, or that its domain is
    non-empty on the banked corpus.  It says: a tool on trunk NAMES this id in
    its head.  The step after this census is to read that tool's docstring and
    its pre-registered reading -- exactly one file, which is the whole saving.
  * A tool naming an id in its head may be naming it to say the OPPOSITE ("not
    comparable on a wave where `pulldrag` is armed").  The tool prints the
    file names so that sentence gets read; it never counts it as evidence.
  * `waves` counts ARM-STRING MEMBERSHIP, not frames in domain.  An id can ride
    thirteen waves and still have an empty in-engine domain -- that is a
    finding the detector makes, and this census cannot.
  * `BUILD` is not "unbuyable" either.  It is "no instrument names it yet".
    Unbuyability is a claim about the world (the dump does not carry lane
    fronts; the loader answers 0) and only a measurement can make it -- see
    `gated_getter_stub_census.py` for the fixture-side half of that question.

THE RATCHET.  Every denominator this census divides by is printed, and a zero
denominator is an ABORT rather than a clean-looking empty answer: with no wave
records every id reads NO-CORPUS, with no behavioural tools every id with a
corpus reads BUILD, and both mistakes look exactly like a finished census that
found a lot of debt.  That is the defect shape this repo keeps paying for (the
strip_comments pair in §GG's own census, `gated_getter_stub_census.py`), so it
is an exit code here, not a caveat.

EXIT: 0 ran, 2 could not run (any denominator empty / arm string unreadable).
A census, not a gate: it never fails on how much debt it finds.
"""
import argparse
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_coverage as VC                                   # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# How much of a behavioural tool is read.  The docstring head is where these
# tools declare which candidate they serve ("`tpgap` condition (a)", "(a)-
# evidence for the `pulldrag` soak candidate").  Reading the WHOLE file would
# match every id that appears in a constant table or an argparse choice list,
# which is how a mention-counter turns into noise.
HEAD_CHARS = 4000


def wave_arm_ids(path):
    """The arm string of one wave record, as a set of ids.

    Parsed from the `arm_string` FIELD, never by regex over the file: a wave
    record's prose fields discuss ids that are not members (`arm_delta_vs_W57`
    names the two ids it REMOVED), and a substring scan would count exactly
    those as membership -- an over-count concentrated on the withdrawn ids,
    i.e. on the ids a ruling is about.
    """
    with open(path, encoding="utf-8") as fh:
        rec = json.load(fh)
    s = rec.get("arm_string")
    if not isinstance(s, str):
        return None
    return {x.strip() for x in s.split(",") if x.strip()}


# The tool's SUBJECT LINE: the docstring's opening sentence, where these files
# declare which candidate they serve.  Measured discriminator, not a style
# preference -- the four heads read by hand while this census was written
# separate exactly here:
#   lion_drain_census.py  "`liondrainstop` condition-(a) census ..."   SUBJECT
#   tpgap_domain.py       "`tpgap` condition (a): does the guard ..."  SUBJECT
#   pulldrag_walk.py      "(a)-evidence for the `pulldrag` candidate"  SUBJECT
#   capmono_refusal.py    "capmono clean-domain refuse-collapse rate"  -- and
#                         `ownhalf` appears 45 lines lower, as a CONFOUNDER
#                         ("`ownhalf` ... push the other way")
# A FILENAME rule was tried first and got `liondrainstop` wrong (its instrument
# is named after the hero, `lion_drain_census.py`), i.e. it demoted a
# purpose-built condition-(a) census to the same class as a confounder note.
SUBJECT_CHARS = 220


def subject_of(head):
    """The tool's opening paragraph: docstring start to the first blank line.

    A flat character window was tried first and is wrong in a way that only
    shows on real files: 220 characters from byte 0 runs past the title of any
    tool with a short one, and lands inside the first section -- which is
    exactly where a confounder note lives.  The paragraph boundary is the
    thing these docstrings actually use to separate "what I am about" from
    "what I had to consider".
    """
    i = head.find('"""')
    body = head[i + 3:] if i != -1 else head
    body = body.lstrip("\n")
    cut = body.find("\n\n")
    if cut != -1:
        body = body[:cut]
    return body[:SUBJECT_CHARS]


def tool_head(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read(HEAD_CHARS)


def classify(ids, waves, tools_by_id, verify):
    """One class per id.  The order of the tests IS the definition."""
    out = {}
    for i in ids:
        if verify.get(i):
            out[i] = "VERIFIED"
        elif not waves.get(i):
            out[i] = "NO-CORPUS"
        elif any(sub for _, sub, _ in tools_by_id.get(i, [])):
            out[i] = "DELIVER"
        elif tools_by_id.get(i):
            out[i] = "MENTION"
        else:
            out[i] = "BUILD"
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--test-set",
                    default=os.path.join(REPO, "iterations/streams/test_set.md"))
    ap.add_argument("--waves",
                    default=os.path.join(REPO, "iterations/reports/batch-desk/waves"))
    ap.add_argument("--behavioral",
                    default=os.path.join(REPO, "tools/batch_test/behavioral"))
    ap.add_argument("--reports",
                    default=os.path.join(REPO, "iterations/reports/replay-check"))
    ap.add_argument("--id", action="append", default=None,
                    help="only these ids (repeatable); the census still reads "
                         "the whole arm string, so the denominators stay true")
    ap.add_argument("--class", dest="cls", default=None,
                    help="only rows in this class")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    try:
        ids = VC.arm_ids(a.test_set)
    except Exception as exc:                                   # noqa: BLE001
        print("AER_COULD_NOT_RUN: %s" % exc, file=sys.stderr)
        return 2

    wave_files = sorted(glob.glob(os.path.join(a.waves, "W*_wave.json")))
    tool_files = sorted(glob.glob(os.path.join(a.behavioral, "*.py")))
    report_files = sorted(glob.glob(os.path.join(a.reports, "*.md")))
    for what, seq, where in (("wave records", wave_files, a.waves),
                             ("behavioural tools", tool_files, a.behavioral),
                             ("reports", report_files, a.reports)):
        if not seq:
            print("AER_COULD_NOT_RUN: no %s under %s -- every id would be "
                  "misclassified, and the misclassification looks like a "
                  "finished census" % (what, where), file=sys.stderr)
            return 2

    waves = {i: [] for i in ids}
    waves_parsed = 0
    for path in wave_files:
        try:
            members = wave_arm_ids(path)
        except Exception:                                      # noqa: BLE001
            members = None
        if members is None:
            continue
        waves_parsed += 1
        tag = os.path.basename(path).split("_")[0]
        for i in ids:
            if i in members:
                waves[i].append(tag)
    if waves_parsed == 0:
        print("AER_COULD_NOT_RUN: %d wave record(s) found, none carried a "
              "parseable arm_string" % len(wave_files), file=sys.stderr)
        return 2

    tools_by_id = {i: [] for i in ids}
    for path in tool_files:
        stem = os.path.basename(path)
        head = tool_head(path)
        for i in ids:
            if re.search(r"\b%s\b" % re.escape(i), head):
                subject = bool(re.search(r"\b%s\b" % re.escape(i),
                                         subject_of(head)))
                own = stem.startswith(i + "_") or stem == i + ".py"
                tools_by_id[i].append((stem, subject, own))

    verify = {}
    verify_reports = {}
    for path in report_files:
        stem = os.path.basename(path)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        seen = set()
        for m in VC.VERIFY_RE.finditer(text):
            row = (m.group(1), m.group(2), m.group(3))
            if row in seen:
                continue
            seen.add(row)
            verify.setdefault(m.group(1), []).append(m.group(2))
            # WHICH REPORT the line came from, carried alongside the verdict
            # word so a reader can ask WHEN it was taken.  The verdict word
            # alone cannot answer "is this reading about the id's CURRENT
            # armed era", and a pre-arming reading counted as coverage is
            # silence -- the one failure direction this census family exists
            # to refuse (a_evidence_owed.py's header, PRE-ARM).  Text output
            # is unchanged on purpose; this is a JSON-only addition.
            verify_reports.setdefault(m.group(1), []).append(stem)

    cls = classify(ids, waves, tools_by_id, verify)
    # PARTITION INVARIANT.  Same discipline as the frame-accounting assertion in
    # gated_getter_stub_census: a census whose buckets do not add up to its own
    # denominator is reporting a number about itself, not about the tree.
    counts = {k: 0 for k in ("VERIFIED", "NO-CORPUS", "DELIVER", "MENTION", "BUILD")}
    for i in ids:
        counts[cls[i]] += 1
    if sum(counts.values()) != len(ids):
        print("AER_ABORT: classes %d != ids %d" % (sum(counts.values()), len(ids)),
              file=sys.stderr)
        return 2

    rows = []
    for i in ids:
        if a.id and i not in a.id:
            continue
        if a.cls and cls[i] != a.cls:
            continue
        rows.append({
            "id": i,
            "class": cls[i],
            "verify": len(verify.get(i, [])),
            "verdicts": verify.get(i, []),
            "verify_reports": verify_reports.get(i, []),
            "waves": len(waves[i]),
            "last_wave": waves[i][-1] if waves[i] else None,
            "tools": [t for t, _, _ in tools_by_id[i]],
            "subject_tools": [t for t, sub, _ in tools_by_id[i] if sub],
            "own_name_tools": [t for t, _, own in tools_by_id[i] if own],
        })

    if a.json:
        json.dump({"counts": counts, "denominators": {
            "ids": len(ids), "waves_parsed": waves_parsed,
            "behavioral_tools": len(tool_files), "reports": len(report_files)},
            "rows": rows}, sys.stdout, indent=1)
        print()
        return 0

    print("A-EVIDENCE-ROUTE  ids %d  wave-records %d  behavioural-tools %d  "
          "reports %d" % (len(ids), waves_parsed, len(tool_files),
                          len(report_files)))
    print("                  VERIFIED %d  DELIVER %d  MENTION %d  BUILD %d  "
          "NO-CORPUS %d"
          % (counts["VERIFIED"], counts["DELIVER"], counts["MENTION"],
             counts["BUILD"], counts["NO-CORPUS"]))
    print()
    print("%-16s %-9s %6s %5s %-6s %s"
          % ("id", "class", "verify", "waves", "last",
             "tools naming it (* = names it in its SUBJECT line)"))
    order = {"DELIVER": 0, "MENTION": 1, "BUILD": 2, "NO-CORPUS": 3,
             "VERIFIED": 4}
    for r in sorted(rows, key=lambda r: (order[r["class"]], -r["waves"], r["id"])):
        names = ", ".join(
            (t + "*" if t in r["subject_tools"] else t) for t in r["tools"]) or "-"
        print("%-16s %-9s %6d %5d %-6s %s"
              % (r["id"], r["class"], r["verify"], r["waves"],
                 r["last_wave"] or "-", names))
    print()
    print("LIMITS -- quoting a row in a ruling means quoting these too:")
    print("  * DELIVER says a tool DECLARES the id in its subject line; it does")
    print("    not say the tool answers (a), was ever run, or has a non-empty")
    print("    domain.  MENTION is weaker: the id is named deeper in someone")
    print("    else's head, which is where a CONFOUNDER note lives too")
    print("    (measured: ownhalf/overchase inside the capmono tools).")
    print("  * BUILD is 'no instrument names it yet', NOT 'unbuyable'.")
    print("    Unbuyability is a measurement (see gated_getter_stub_census.py")
    print("    for the fixture-side half), never an absence in this table.")
    print("  * waves counts ARM-STRING MEMBERSHIP, not frames in domain.")
    print("  * verify shares verify_coverage's regex and corpus, so a zero here")
    print("    carries that tool's caveat: the VERIFY convention starts")
    print("    2026-08-30 and older verdicts live in prose only.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
