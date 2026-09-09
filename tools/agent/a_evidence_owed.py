#!/usr/bin/env python3
"""Is ANYTHING raising a hand for this armed id's condition (a)?

GH #540, the general half.  Filed 2026-09-05 after `verify_coverage.py` measured
40 of 61 armed ids with no machine-readable (a) verdict anywhere, and the
diagnosis was not that the work is hard:

    Iron rule 2.5 delivers a RULING to the field the ruled party reads.  A
    condition-(a) acceptance obligation is not a ruling -- it is an attachment
    of the action "admission approved", and the `queue.json` row that carried
    the admission belongs to the REQUESTING stream and is resolved the moment
    admission is granted.  The replay desk is never that row's addressee, so
    the obligation has no row it could be written into.  It lives in
    `test_set.md` prose: authoritative, and driving nobody.

    This is the GH #332 / #413 filing sentence again -- the desk audits N
    obligations, hits N of N, the answer is correct, and the (N+1)th had
    nowhere to be missing from.

WHY A CHECKER AND NOT 40 HAND-WRITTEN ROWS
------------------------------------------
GH #540 offered both, and the checker is the one that keeps working.  The two
rows written by hand on the filing day (`a_evidence_tpdying`,
`a_evidence_tpreach`) each cost a paragraph of prose and each covered exactly
one id -- and neither covers the id admitted NEXT WEEK, which is the id this
defect will be found on again.  The armed set turns over: 61 on the filing day,
37 today.  A checker keyed on the arm string covers whatever is armed when it
runs, including ids nobody has thought of yet.

⭐ The registry rows are not made pointless by this -- they are made OPTIONAL
IN THE RIGHT DIRECTION.  Opening one is how a stream says "this obligation is
mine and here is its `done_when`"; this leg is what happens when nobody does.

THE RULE, in one line: an armed id must carry EITHER a condition-(a) verdict
(a VERIFY line) OR a row in `owed_executions.json` that names it.  Neither =
finding, exit 3.  ⚠️ The failure direction is the whole point (GH #540 ask 3):
an id with nothing owed must never read as "nothing is owed".  Silence is
exactly how the 40 got there.

COVERAGE, and it is deliberately mechanical (two forms, both bare-readable):
  * a row whose `id` is `a_evidence_<id>` -- the convention the two hand-written
    rows already use;
  * a row carrying `covers_ids: [...]` that lists the id -- for one row that
    discharges several ids at once, which is what a delivery round actually
    looks like (one detector run answers every id in its own subject line).

⛔ A RETIRED ROW DOES NOT COUNT AS COVERAGE, on purpose.  A row is retired when
its `done_when` is satisfied, and `done_when: path_exists` judges that an
artefact EXISTS, not what is in it (`pending_rulings.py` LIMIT 11).  So a
retired row plus no VERIFY line is the exact state this leg exists to shout
about: the purchase was recorded as made and the verdict never appeared.
Counting `retired` here would let the registry close its own case.

⛔ WHAT THIS TOOL DOES NOT SAY (read before quoting it in a ruling)
------------------------------------------------------------------
  * `OWED` is not a claim that the obligation will be discharged, that the row
    is well-written, or that its `done_when` is strong.  It says a row names
    the id.  How good the row is, is `pending_rulings.py`'s question.
  * `VERDICT` inherits `verify_coverage.py`'s regex and corpus: the VERIFY
    convention starts 2026-08-30, so a pre-convention verdict living in prose
    reads as absent here.  That direction is loud, not quiet -- it asks for a
    row that already exists in prose, which is cheap; the opposite direction
    would be silence, which is the defect.
  * The route class printed beside a finding (DELIVER / MENTION / BUILD /
    NO-CORPUS) is `a_evidence_route.py`'s reading, quoted verbatim so the two
    censuses cannot drift.  It says what the PURCHASE would be; it does not say
    the purchase is easy, and DELIVER in particular is not a claim that the
    named tool answers (a).  Read that tool's LIMITS before quoting a class.
  * A covering row that names an id which is no longer armed is reported as a
    note, NOT a finding: withdrawal from the test set does not destroy the
    ability to buy (a) from banked corpus (`test_set.md` §FB.4, and the
    `tpdying`/`tpreach` pair are the measured precedent -- both were withdrawn
    and both were bought afterwards).

EXIT: 0 clean / 2 could-not-run / 3 findings -- the same three words as rule 10,
the push gate (GH #213) and the python runner (GH #243).
"""

import argparse
import json
import os
import shlex
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROUTE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "a_evidence_route.py")
REGISTRY = os.path.join(REPO, "iterations", "owed_executions.json")

# The convention the two hand-written rows already use.  Kept as a constant so
# the test can assert the real rows still match it rather than restating it.
ROW_PREFIX = "a_evidence_"


def route(path=ROUTE, extra=None):
    """`a_evidence_route.py --json`, as a subprocess ON PURPOSE.

    Importing it and re-deriving the classification here would put a second
    implementation of the DELIVER/MENTION/BUILD split in the tree, and the two
    would drift on exactly the ids a ruling is about -- that census's own
    header spends a paragraph on why the discriminator is the docstring
    SUBJECT line and not the filename.  One reader, quoted.
    """
    cmd = [sys.executable, path, "--json"] + list(extra or [])
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        return None, "a_evidence_route.py exited %d: %s" % (
            proc.returncode, (proc.stderr or "").strip()[:300])
    try:
        return json.loads(proc.stdout), None
    except ValueError as exc:                                  # noqa: BLE001
        return None, "a_evidence_route.py --json is not JSON: %s" % exc


def coverage(registry):
    """id -> the owed row that names it.  Open rows only (see the header)."""
    out = {}
    for row in registry.get("owed", []):
        if not isinstance(row, dict):
            continue
        rid = row.get("id")
        explicit = row.get("covers_ids")
        if isinstance(explicit, list):
            for i in explicit:
                if isinstance(i, str) and i.strip():
                    out.setdefault(i.strip(), rid)
        if isinstance(rid, str) and rid.startswith(ROW_PREFIX):
            covered = rid[len(ROW_PREFIX):]
            if covered:
                out.setdefault(covered, rid)
    return out


def judge(rows, covered):
    """One state per armed id.  The order of the tests IS the definition."""
    out = []
    for r in rows:
        i = r["id"]
        if r.get("verify"):
            state, why = "VERDICT", "%d VERIFY line(s)" % r["verify"]
        elif i in covered:
            state, why = "OWED", covered[i]
        else:
            state, why = "UNOWED", r.get("class", "?")
        out.append((state, i, why, r))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--registry", default=REGISTRY)
    ap.add_argument("--route", default=ROUTE)
    # ONE string, shlex-split, rather than a repeatable `--route-arg`: argparse
    # refuses a value that begins with `--`, so the repeatable form could not
    # pass through the census's own flags (`--route-arg --test-set X` reads
    # `--test-set` as an option of THIS parser).  Caught by this tool's test on
    # its first run, where it presented as every synthetic case exiting 2.
    ap.add_argument("--route-args", default="",
                    help="passed through to a_evidence_route.py, shlex-split "
                         "(tests use it to point the census at a fixture tree)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    data, err = route(a.route, shlex.split(a.route_args))
    if data is None:
        print("AEO_COULD_NOT_RUN: %s" % err, file=sys.stderr)
        return 2

    # A registry this tool cannot read must NOT read as "nothing is owed" --
    # that is this leg's own failure mode, one level up from the one it
    # watches.
    try:
        with open(a.registry, encoding="utf-8") as fh:
            registry = json.load(fh)
    except Exception as exc:                                   # noqa: BLE001
        print("AEO_COULD_NOT_RUN: registry %s: %s" % (a.registry, exc),
              file=sys.stderr)
        return 2
    if not isinstance(registry.get("owed"), list):
        print("AEO_COULD_NOT_RUN: registry %s has no `owed` list -- every id "
              "would read UNOWED, and that misreading looks like a finished "
              "census" % a.registry, file=sys.stderr)
        return 2

    rows = data.get("rows") or []
    covered = coverage(registry)
    verdicts = judge(rows, covered)
    armed = {r["id"] for r in rows}

    unowed = [v for v in verdicts if v[0] == "UNOWED"]
    owed = [v for v in verdicts if v[0] == "OWED"]

    if a.json:
        print(json.dumps({
            "counts": {"armed": len(rows), "verdict": len(verdicts) - len(unowed) - len(owed),
                       "owed": len(owed), "unowed": len(unowed)},
            "rows": [{"id": i, "state": s, "why": w, "class": r.get("class")}
                     for s, i, w, r in verdicts],
            "covers_unarmed": sorted(i for i in covered if i not in armed),
        }, indent=1))
        return 3 if unowed else 0

    print("A-EVIDENCE-OWED  armed %d  verdict %d  owed-row %d  UNOWED %d"
          % (len(rows), len(verdicts) - len(unowed) - len(owed), len(owed),
             len(unowed)))

    if unowed:
        print("\nnothing is raising a hand for these ids' condition (a) "
              "(GH #540); the cheap fix is ONE row in\n"
              "iterations/owed_executions.json named `%s<id>` (or one row "
              "carrying `covers_ids`),\nnot the analysis itself:" % ROW_PREFIX)
        for _, i, cls, r in sorted(unowed, key=lambda v: (v[2], v[1])):
            subj = [t for t in (r.get("subject_tools") or r.get("tools") or [])]
            print("  %-16s %-10s waves %2s last %-4s  %s"
                  % (i, cls, r.get("waves", "?"), r.get("last_wave") or "-",
                     ", ".join(subj[:4]) or "no tool names it"))

    if owed:
        print("\nowed row exists (this leg is satisfied; whether the row is "
              "GOOD is pending_rulings.py's question):")
        for _, i, rid, _r in sorted(owed, key=lambda v: v[1]):
            print("  %-16s <- %s" % (i, rid))

    stale = sorted(i for i in covered if i not in armed)
    if stale:
        print("\nnote, NOT a finding -- these covering rows name ids that are "
              "not in the current arm string.\nWithdrawal does not destroy the "
              "ability to buy (a) from banked corpus (test_set.md §FB.4):")
        for i in stale:
            print("  %-16s <- %s" % (i, covered[i]))

    print("\nLIMITS -- quoting a row in a ruling means quoting these too:")
    print("  * OWED says a row NAMES the id.  It does not say the row is well")
    print("    written, that its done_when is strong, or that anyone will run")
    print("    it.  That is pending_rulings.py's question, not this leg's.")
    print("  * VERDICT inherits verify_coverage's regex and corpus: the VERIFY")
    print("    convention starts 2026-08-30, so an older verdict living in")
    print("    prose reads as absent here (loud, not quiet -- by design).")
    print("  * A retired row is NOT coverage: done_when path_exists judges an")
    print("    artefact, not a verdict (pending_rulings LIMIT 11), so retired")
    print("    plus no VERIFY line is precisely what this leg shouts about.")
    print("  * The class beside a finding is a_evidence_route's reading,")
    print("    quoted; DELIVER is not a claim the named tool answers (a).")

    if unowed:
        print("\nFINDING: %d armed id(s) with neither a verdict nor an owed "
              "row." % len(unowed))
        return 3
    print("\nevery armed id carries a verdict or an owed row -- OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
