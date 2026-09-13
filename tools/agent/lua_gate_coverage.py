#!/usr/bin/env python3
"""Name the Lua tests that NO automatic reader runs, and refuse to let that set grow.

WHY THIS FILE EXISTS (GH #806, director ruling 2026-09-13T22:xxZ).

GH #806 was opened as "`test_lion_considere_earlyreturn_domain.lua` is 6-red on
trunk and is not in the Lua gate manifest, so three green legs let the push
through and the next desk to start work found the red."  It proposed two fixes:
put the file in the manifest if it is fast enough, or amnesty it in
`known_red`.  Measured, BOTH are wrong, and the reason is the point of this
file:

  * INTO THE MANIFEST is not available.  The file measures 10.44 / 10.55 /
    10.59s (three runs, this container, 2026-09-13T22:xxZ) against a 5.5s
    per-test cap.  Its manifest row already says `reason: timed_out` and that
    label is ACCURATE, not an artifact -- GH #616 constraint 1 forbids
    overriding measured seconds with a filename.
  * INTO `known_red` is worse.  That list means "already red when this leg
    landed, amnestied"; this file went red TODAY from corpus drift.  The hero
    desk refused it for the right reason: it formalises "nobody looks".

So the defect is neither the file nor the manifest.  It is that the exclusion
is INVISIBLE.  `lua_gate_measure.py`'s own "WHAT THIS DOES NOT BUY" says an
over-cap test "is covered only by 开工自检 and the full suite", and for this
file THAT SENTENCE IS FALSE: 开工自检's Lua leg discovers by TAG
(`[detector]`/`[ratchet]` plus four named files) and this file is tagged
`[hero]`.  Two selectors, two different rules, and the file falls through both
-- so the only thing left is the ~100-min suite that GH #124 says does not
finish in a routine container.

⭐ THE CRUX, and it is arithmetic rather than opinion: THE CAP SELECTS AGAINST
THE POPULATION THE GATE EXISTS FOR.  `lua_gate_measure.py` records it in its
own header -- "the tests this gate exists for are among the EXPENSIVE ones, not
the cheap ones."  Both of the trunk reds standing on 2026-09-13 were over-cap
files, on both legs:

    tests/test_lion_considere_earlyreturn_domain.lua   10.5s vs 5.5s cap (Lua)
    tests/test_bots_walk_farm_only.py                   3.64s vs 3.0s cap (python)

The python one had been reddened by an unregistered `io.popen` walk, was the
THIRD instance on that one census, and its author's push read `py gate: 84 ran,
0 findings`.  A cap set for cost is quietly deciding coverage.

WHAT THIS FILE DOES, AND WHAT IT DELIBERATELY DOES NOT.

It computes a RELATION -- disk vs {push gate, 开工自检's tag leg, known_red} --
and prints the files covered by none of them.  That is the shape the last
director round (2026-09-13T19:46Z, py_gate `5f`) recorded getting wrong in the
other direction: *a constant floor is an assertion about manifest size;
coverage is a relation between manifest and disk.  What was asserted was the
latter; what was written down was the former.*  So this asserts the relation.

⛔ IT DOES NOT RUN A SINGLE TEST.  It is set arithmetic and reads in well under
a second, because a checker that costs minutes is a checker that gets skipped.
Whether the uncovered files are RED is a different question with a different
price (measured today: 113 files, ~19 min); this tool tells you WHO IS NOT
BEING WATCHED, not who is currently failing.

⛔ IT DOES NOT TURN THE EXISTING 113 RED.  A check that is red from its first
day is a check that gets read as furniture -- this repo's own favourite defect
(green because it asserted nothing) wearing the opposite colour.  It RATCHETS:
the baseline names today's uncovered set, and a file that becomes uncovered
LATER -- a new test that lands unmeasured, or a tagged test that loses its tag
-- exits 3 and names itself.  The set is meant to SHRINK; `--update-baseline`
records a shrink and REFUSES to record a growth.

Usage:
    python3 tools/agent/lua_gate_coverage.py                  # check (0/2/3)
    python3 tools/agent/lua_gate_coverage.py --list           # + every name
    python3 tools/agent/lua_gate_coverage.py --update-baseline
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Overridable so tests/test_lua_gate_coverage.py can run THE REAL CLI against a
# temp tree.  A ratchet tested only through its own internals is a ratchet whose
# exit codes -- the part every caller reads -- were never exercised.
ROOT = os.environ.get("LUA_GATE_COVERAGE_ROOT", ROOT)
MANIFEST = os.environ.get(
    "LUA_GATE_COVERAGE_MANIFEST",
    os.path.join(ROOT, "tools", "agent", "lua_gate_manifest.json"),
)
BASELINE = os.environ.get(
    "LUA_GATE_COVERAGE_BASELINE",
    os.path.join(ROOT, "tools", "agent", "lua_gate_coverage_baseline.json"),
)
SELFCHECK = os.path.join(ROOT, "tools", "agent", "routine_selfcheck.sh")

# 开工自检's Lua leg discovers by tag plus four names that predate the tag
# convention.  This is a SECOND SPELLING of a rule that lives in
# routine_selfcheck.sh, which is exactly the defect this repo keeps recording
# ("a baseline written by one regex and read by another stops matching the day
# either drifts").  It is tolerable here for one reason only: it is not
# trusted.  tests/test_lua_gate_coverage.py extracts the shell leg's OWN
# `files=$(...)` pipeline out of routine_selfcheck.sh, runs it, and asserts the
# two sets are EQUAL -- so drift on either side fails a test instead of
# silently shrinking the covered set.
TAGS = ("[detector]", "[ratchet]")
PRE_TAG_NAMED = (
    "tests/test_gate_claim_consistency.lua",
    "tests/test_data_consistency.lua",
    "tests/test_level_gate_census.lua",
    "tests/test_wk_fact_anchor.lua",
)


def disk_tests(root=ROOT):
    d = os.path.join(root, "tests")
    return {
        "tests/" + f
        for f in os.listdir(d)
        if f.startswith("test_") and f.endswith(".lua")
    }


def selfcheck_covered(root=ROOT, disk=None):
    """Files 开工自检's Lua leg would discover: tagged, plus the four named."""
    if disk is None:
        disk = disk_tests(root)
    out = set()
    for rel in sorted(disk):
        try:
            with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
                src = fh.read()
        except OSError:
            continue
        if any(t in src for t in TAGS):
            out.add(rel)
    return out | ({p for p in PRE_TAG_NAMED} & disk)


def gate_covered(manifest):
    """Files the push hook actually runs -- `in_gate`, never a filename."""
    return {k for k, v in manifest.get("tests", {}).items() if v.get("in_gate")}


def classify(root=ROOT, manifest_path=None):
    with open(manifest_path or MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)
    disk = disk_tests(root)
    rows = manifest.get("tests", {})
    gate = gate_covered(manifest) & disk
    leg = selfcheck_covered(root, disk)
    amnesty = set(manifest.get("known_red", [])) & disk
    uncovered = disk - gate - leg - amnesty

    def why(rel):
        row = rows.get(rel)
        if row is None:
            # Postdates `measured_at`: never measured, so never selectable.
            # This is the Lua twin of the fail-open channel the director round
            # of 2026-09-13T19:46Z closed on py_gate (STALE MANIFEST, exit 2).
            return "no_manifest_row"
        return row.get("reason") or "unknown"

    return {
        "disk": len(disk),
        "gate": len(gate),
        "selfcheck_leg": len(leg),
        "known_red": len(amnesty),
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
    update = "--update-baseline" in argv
    try:
        st = classify()
    except FileNotFoundError as exc:
        print("UNCERTIFIABLE -- cannot read the manifest: %s" % exc)
        print("  This is NOT a pass: the coverage relation was not computed.")
        return 2

    unc = st["uncovered"]
    print(
        "LUA GATE COVERAGE  disk %d | push gate %d | 开工自检 leg %d | known_red %d"
        % (st["disk"], st["gate"], st["selfcheck_leg"], st["known_red"])
    )
    counts = {}
    for rel in unc:
        counts[st["why"][rel]] = counts.get(st["why"][rel], 0) + 1
    pct = (100.0 * len(unc) / st["disk"]) if st["disk"] else 0.0
    print(
        "  UNCOVERED (no automatic reader runs these): %d of %d (%.0f%%)  %s"
        % (len(unc), st["disk"], pct, counts or "{}")
    )
    print(
        "  'uncovered' means: not in the push hook, not discovered by 开工自检's\n"
        "  tag leg, not amnestied. Only the ~100-min suite (GH #124) reaches them."
    )
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
                        "Baseline for tools/agent/lua_gate_coverage.py (GH #806). "
                        "The uncovered set is meant to SHRINK. A file that becomes "
                        "uncovered later exits 3 and names itself; --update-baseline "
                        "refuses to record growth."
                    ),
                    "uncovered_count": len(unc),
                    # Broken out as its own top-level key so an
                    # iterations/owed_executions.json row can pin on it with
                    # `kind: json_value` (the baton for GH #806: re-measure the
                    # Lua manifest so every on-disk test has a row again).  A
                    # count that lives only inside a list is not a criterion
                    # anything can read bare.
                    "no_manifest_row_count": sum(
                        1 for r in unc if st["why"][r] == "no_manifest_row"
                    ),
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
            "  NEXT desk to start work (GH #624, GH #806). Fix by one of:\n"
            "    * measure it under the cap and re-run lua_gate_measure.py, or\n"
            "    * tag it [detector]/[ratchet] so 开工自检's Lua leg runs it, or\n"
            "    * if it is genuinely expensive AND genuinely watched elsewhere,\n"
            "      say where, then --update-baseline."
        )
        return 3
    print("  uncovered set unchanged from the baseline -- OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
