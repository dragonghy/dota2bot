#!/usr/bin/env python3
"""Name the python tests that NO automatic reader runs, and refuse to let that set grow.

WHY THIS FILE EXISTS (GH #843 acceptance 2, director ruling 2026-09-17T16:xxZ;
族属 GH #810 / GH #806 / GH #624 / GH #616).

GH #843's second half asks for exactly one thing, verbatim:

    `py_gate_manifest.json` 里 `in_gate: false` 且 `reason: over_per_test_cap`
    的行,各自有一条**写下来的**读者归属(哪怕结论是「无」)。

Today that is 17 rows (cap 3.0s).  Two of them have already cost real rounds:
`test_bots_walk_farm_only.py` (3.723s, reddened trunk twice in one evening and
was found by the NEXT desk hours later -- #843's own filing) and
`test_spot_az_spread.py` (3.756s, left the hook on 2026-09-17 and nothing
raised a hand -- owed row `py_gate_evicted_spot_az_spread`).

⛔ THE ATTRIBUTION IS COMPUTED, NOT STORED PER ROW, AND THAT IS THE WHOLE
DESIGN DECISION.  A hand-written `reader:` field on each manifest row would be
a fix that ERASES ITSELF, silently, on the next re-measure:
`py_gate_measure.py:305` builds `"tests": dict(sorted(tests.items()))` FRESH
from the measurement, and -- unlike the Lua side -- the python manifest has no
`BASELINE_KEYS` / `carry_baseline()` mechanism at all (that is GH #783's fix,
and it was never ported to this half).  So a per-row field would survive
exactly until the next container ran measure, and its disappearance would look
like nothing at all.  ⇒ The durable form of "written down" is a CHECKED
RELATION plus the tool that keeps it true.

⭐ THE ANSWER FOR THE PYTHON HALF IS DIFFERENT FROM THE LUA HALF, AND THE
DIFFERENCE IS THE SELECTOR'S SHAPE -- arithmetic, not opinion:

  * Lua:    开工自检's leg discovers by TAG (`[detector]`/`[ratchet]` + four
            named files).  A `[hero]`-tagged over-cap file falls through BOTH
            selectors -- that is GH #806, and why `lua_gate_coverage.py` found
            113 of 449 files (25%) read by nobody.
  * python: 开工自检's leg is `bash tests/run_py_tests.sh`, which discovers by
            GLOB over the whole directory (`for f in tests/test_*.py`) with NO
            time cap in the leg.  A glob is a SUPERSET of the manifest by
            construction, so every `in_gate: false` row is still read.

Measured on the day this landed: 147 python tests on disk, 147 matched by the
reader, **0 uncovered**, and all 17 `in_gate: false` rows covered.  So #843's
answer for this half is "the reader is 开工自检's python leg, for every row" --
and it is EARNED against the corpus, not inherited from a sentence.

⛔ WHICH IS PRECISELY WHY IT NEEDS A RATCHET RATHER THAN A PARAGRAPH.
`lua_gate_measure.py` promised in prose that over-cap tests are "covered only
by 开工自检 and the full suite"; GH #806 measured that sentence FALSE for a
real file.  The python promise above is true TODAY and is currently asserted by
nothing.  Three reachable ways to falsify it, none exotic:

  1. A test lands in a SUBDIRECTORY.  `tests/test_*.py` is depth-1; the walk
     here is recursive.  `tests/mock/`, `tests/fixtures/` and `tests/frames/`
     ALREADY EXIST -- so `tests/mock/test_foo.py` is a plausible landing spot,
     not a hypothetical.  It would be invisible to the reader AND to the gate.
  2. The glob in `run_py_tests.sh` is narrowed (a `--changed-only` incremental
     walk is one of #843's own suggested options, and it would silently convert
     this half into the Lua half).
  3. The leg acquires a time cap.  Then the SLOWEST tests get cut first -- i.e.
     exactly the `over_per_test_cap` population this relation exists for.
     RULING 57 is the precedent: the watchdog leg's 120s cap left three python
     cases `did NOT run` for sixteen rounds.

⛔ IT DOES NOT RE-SPELL THE READER'S SELECTOR.  The glob is EXTRACTED from
`run_py_tests.sh` itself, because a second spelling of someone else's rule is
this repo's most-recorded defect ("a baseline written by one regex and read by
another stops matching the day either drifts").  If the extraction fails, this
exits **2 (UNCERTIFIABLE), not 0** -- a reader whose selector we cannot read is
not a reader we may credit.

⛔ IT RUNS NOT ONE TEST.  Set arithmetic, well under a second, because a
checker that costs minutes is a checker that gets skipped.  Whether the covered
tests are RED is a different question with a different price; this tool says
WHO IS NOT BEING WATCHED, not who is failing.

⛔ STATED LIMIT -- "READ" IS NOT "PRICED", AND GH #839 OWNS THE OTHER HALF.
This tool answers WHO READS a test.  It does NOT answer whether the test is
PRICED in the hook's cumulative budget.  A file with no manifest row is run by
`py_gate.py` anyway (it prints `N new test(s) not in the manifest were run
anyway, costing …`), so it is READ -- and this relation therefore reports it as
covered, correctly.  But it is un-priced, which is exactly GH #839's subject
("py_gate manifest 又漂了:7/141 个测试无行").  ⇒ A green reading here does not
mean the manifest is fresh, and must not be quoted as if it did.  This file's
own nail, `tests/test_py_gate_coverage.py`, lands WITHOUT a manifest row and is
thus one of #839's population on the day it ships -- recorded here rather than
left for the next reader to discover.

⛔ NON-VACUITY IS THE PROPERTY UNDER TEST, NOT AN ASSUMPTION.  A relation whose
two sides are computed the same way answers `0 uncovered` forever and reads
like health.  `tests/test_py_gate_coverage.py` plants files in the three shapes
above into a temp tree and asserts each is REPORTED -- so "0" keeps meaning
"nothing fell through" rather than "nothing could".

Usage:
    python3 tools/agent/py_gate_coverage.py                  # check (0/2/3)
    python3 tools/agent/py_gate_coverage.py --list           # + every name
    python3 tools/agent/py_gate_coverage.py --attribution    # per-row readers
    python3 tools/agent/py_gate_coverage.py --update-baseline
"""
import glob as globmod
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Overridable so tests/test_py_gate_coverage.py can run THE REAL CLI against a
# temp tree.  A ratchet tested only through its own internals is a ratchet whose
# exit codes -- the part every caller reads -- were never exercised.
ROOT = os.environ.get("PY_GATE_COVERAGE_ROOT", ROOT)
MANIFEST = os.environ.get(
    "PY_GATE_COVERAGE_MANIFEST",
    os.path.join(ROOT, "tools", "agent", "py_gate_manifest.json"),
)
BASELINE = os.environ.get(
    "PY_GATE_COVERAGE_BASELINE",
    os.path.join(ROOT, "tools", "agent", "py_gate_coverage_baseline.json"),
)
RUNNER = os.path.join(ROOT, "tests", "run_py_tests.sh")

# The one line in run_py_tests.sh that decides what 开工自检's python leg reads.
# Matching the loop header (rather than hardcoding the pattern) is what keeps
# this tool honest if that selector is ever narrowed.
RUNNER_GLOB_RE = re.compile(r"^\s*for\s+\w+\s+in\s+([^\s;]+)\s*;?\s*do\s*$", re.M)


class Uncertifiable(Exception):
    """Something needed to compute the relation could not be read."""


def reader_glob(root=ROOT, runner=None):
    """The reader's OWN glob, lifted out of tests/run_py_tests.sh.

    Deliberately not a constant: see the docstring.  Anything unreadable or
    ambiguous raises, because crediting a reader whose selector we guessed is
    the failure this file exists to prevent.
    """
    path = runner or RUNNER
    try:
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
    except OSError as exc:
        raise Uncertifiable("cannot read the python runner: %s" % exc)
    hits = RUNNER_GLOB_RE.findall(src)
    hits = [h for h in hits if h.endswith(".py")]
    if len(hits) != 1:
        raise Uncertifiable(
            "expected exactly one `for f in <*.py glob>; do` in %s, found %d %r"
            % (os.path.relpath(path, root), len(hits), hits)
        )
    return hits[0]


def reader_covered(root=ROOT, pattern=None):
    """Files 开工自检's python leg would discover, by running its own glob."""
    pat = pattern if pattern is not None else reader_glob(root)
    return {
        os.path.relpath(p, root).replace(os.sep, "/")
        for p in globmod.glob(os.path.join(root, pat))
        if os.path.isfile(p)
    }


def disk_tests(root=ROOT):
    """Every python test on disk -- RECURSIVE, so it can see what a depth-1
    glob cannot.  This asymmetry is the content of the whole check."""
    d = os.path.join(root, "tests")
    out = set()
    for dirpath, _dirs, files in os.walk(d):
        for f in files:
            if f.startswith("test_") and f.endswith(".py"):
                rel = os.path.relpath(os.path.join(dirpath, f), root)
                out.add(rel.replace(os.sep, "/"))
    return out


def gate_covered(manifest):
    """Files the push hook actually runs -- `in_gate`, never a filename
    (GH #616 constraint 1)."""
    return {k for k, v in manifest.get("tests", {}).items() if v.get("in_gate")}


def classify(root=ROOT, manifest_path=None, runner=None):
    try:
        with open(manifest_path or MANIFEST, encoding="utf-8") as fh:
            manifest = json.load(fh)
    except OSError as exc:
        raise Uncertifiable("cannot read the manifest: %s" % exc)
    except ValueError as exc:
        raise Uncertifiable("manifest is not readable JSON: %s" % exc)

    pattern = reader_glob(root, runner)
    disk = disk_tests(root)
    # ⛔ AN EMPTY CORPUS IS NOT A CLEAN ANSWER.  Without this, a missing or
    # emptied `tests/` walks to nothing, `uncovered` is empty, and the tool
    # prints "0 of 0 (0%)" and exits 0 -- a vacuous pass, which is the exact
    # defect shape this file exists to legislate against (and it would read
    # identically to the healthy answer, because the healthy answer is also 0).
    if not disk:
        raise Uncertifiable(
            "no python tests found under tests/ in %s -- an empty corpus cannot "
            "certify a coverage relation" % root
        )
    rows = manifest.get("tests", {})
    gate = gate_covered(manifest) & disk
    leg = reader_covered(root, pattern) & disk
    uncovered = disk - gate - leg

    def why(rel):
        row = rows.get(rel)
        if row is None:
            # Postdates `measured_at`: never measured, so never selectable.
            return "no_manifest_row"
        return row.get("reason") or "unknown"

    # #843's acceptance, computed: one reader attribution per out-of-gate row.
    attribution = {}
    for rel, row in sorted(rows.items()):
        if row.get("in_gate"):
            continue
        if rel not in disk:
            attribution[rel] = "gone_from_disk"
        elif rel in leg:
            attribution[rel] = "开工自检 python leg (tests/run_py_tests.sh)"
        else:
            attribution[rel] = "NONE"

    return {
        "pattern": pattern,
        "disk": len(disk),
        "gate": len(gate),
        "reader_leg": len(leg),
        "out_of_gate_rows": len(attribution),
        "attribution": attribution,
        "uncovered": sorted(uncovered),
        "why": {rel: why(rel) for rel in sorted(uncovered)},
    }


def load_baseline():
    try:
        with open(BASELINE, encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        return None


def main(argv):
    want_list = "--list" in argv
    want_attr = "--attribution" in argv
    update = "--update-baseline" in argv
    try:
        st = classify()
    except Uncertifiable as exc:
        print("UNCERTIFIABLE -- %s" % exc)
        print("  This is NOT a pass: the coverage relation was not computed.")
        return 2

    unc = st["uncovered"]
    print(
        "PY GATE COVERAGE  disk %d | push gate %d | 开工自检 leg %d  (glob %s)"
        % (st["disk"], st["gate"], st["reader_leg"], st["pattern"])
    )
    counts = {}
    for rel in unc:
        counts[st["why"][rel]] = counts.get(st["why"][rel], 0) + 1
    pct = (100.0 * len(unc) / st["disk"]) if st["disk"] else 0.0
    print(
        "  UNCOVERED (no automatic reader runs these): %d of %d (%.0f%%)  %s"
        % (len(unc), st["disk"], pct, counts or "{}")
    )
    nones = sorted(k for k, v in st["attribution"].items() if v == "NONE")
    print(
        "  out-of-gate rows with a written reader: %d of %d  (GH #843 acceptance 2)"
        % (st["out_of_gate_rows"] - len(nones), st["out_of_gate_rows"])
    )
    if want_attr:
        for rel, who in sorted(st["attribution"].items()):
            print("    %-46s %s" % (rel, who))
    if want_list:
        for rel in unc:
            print("    %-18s %s" % (st["why"][rel], rel))

    base = load_baseline()
    if update:
        if base is not None:
            grew = sorted(set(unc) - set(base.get("uncovered", [])))
            if grew:
                print(
                    "REFUSED to update the baseline: %d file(s) BECAME uncovered."
                    % len(grew)
                )
                for rel in grew:
                    print("    NEW UNCOVERED  %-18s %s" % (st["why"][rel], rel))
                print("  The baseline records shrinks, never growth. Fix the cause.")
                return 3
        with open(BASELINE, "w", encoding="utf-8") as fh:
            json.dump(
                {
                    "_comment": (
                        "Baseline for tools/agent/py_gate_coverage.py "
                        "(GH #843 acceptance 2). The uncovered set is meant to "
                        "STAY EMPTY: unlike the Lua half, 开工自检's python leg "
                        "discovers by glob, so it is a superset of the manifest "
                        "by construction. A file that becomes uncovered later "
                        "exits 3 and names itself; --update-baseline refuses to "
                        "record growth."
                    ),
                    "uncovered_count": len(unc),
                    # Broken out as its own bare-readable top-level key so an
                    # iterations/owed_executions.json row can pin on it with
                    # `kind: json_value`.  A count that lives only inside a list
                    # is not a criterion anything can read bare.
                    "rows_with_no_reader_count": len(nones),
                    "uncovered": unc,
                },
                fh,
                indent=1,
            )
            fh.write("\n")
        print("baseline updated: %d uncovered" % len(unc))
        return 0

    if base is None:
        print("UNCERTIFIABLE -- no baseline yet; run --update-baseline.")
        print("  This is NOT a pass: nothing was compared.")
        return 2

    known = set(base.get("uncovered", []))
    grew = sorted(set(unc) - known)
    shrank = sorted(known - set(unc))
    if shrank:
        print(
            "  %d file(s) left the uncovered set since the baseline -- "
            "re-run with --update-baseline to bank it." % len(shrank)
        )
        for rel in shrank:
            print("    NOW COVERED    %s" % rel)
    if grew:
        print(
            "UNCOVERED SET GREW -- %d file(s) that nothing reads automatically:"
            % len(grew)
        )
        for rel in grew:
            print("    NEW UNCOVERED  %-18s %s" % (st["why"][rel], rel))
        print(
            "  A test nobody runs cannot refuse a push, so its red is found by the\n"
            "  NEXT desk to start work (GH #624, GH #843). Fix by one of:\n"
            "    * move it to tests/ top level so run_py_tests.sh's glob sees it, or\n"
            "    * measure it under the cap and re-run py_gate_measure.py, or\n"
            "    * if it is genuinely expensive AND genuinely watched elsewhere,\n"
            "      say where, then --update-baseline."
        )
        return 3
    print("  uncovered set unchanged from the baseline -- OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
