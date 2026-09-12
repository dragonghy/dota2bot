#!/usr/bin/env python3
"""Acceptance for the Lua push-gate manifest's RED BASELINE surviving a
re-measure (GH #783).

THE DEFECT THIS PINS.  `tools/agent/lua_gate_manifest.json` carries two
different kinds of thing: MEASUREMENTS (how many seconds each test costs, which
a re-measure is supposed to overwrite) and a BASELINE (`known_red*` -- which
tests were already red before you arrived, which a re-measure has no business
touching).  Three writers exist.  `set_known_red()` sets the baseline;
`reselect()` replays the knobs over stored seconds and preserved the baseline
by accident, because it mutates the loaded dict; `main()` re-measured and built
its dict FROM SCRATCH, so it dropped all four baseline keys -- and
`lua_gate.py` reads a missing key as an empty baseline, never a permissive one.

So the single action the manifest's own `_comment` permits ("Do not hand-edit;
re-measure") disarmed the amnesty list, and the next `git push` -- by anyone,
very likely not the person who re-measured -- was refused by nine reds that
predated them.  Both routes had a cost, so what actually happened is the third
route: nobody registered anything.  The strategy group's manifest registration
was owed for five rounds and read as a discipline problem the whole time.

⭐ WHY THE CASES BELOW ARE NOT JUST "case 4".  Case 4 alone would pass with a
four-line patch to `main()`, and the shape would survive: the two write paths
would still disagree about what belongs to whom, and a FIFTH baseline key added
later would be dropped in exactly the same way.  Case 5 pins the direction the
fix must NOT take, case 6 pins the writers to one registry, and case 7 pins the
path that was already correct so a future refactor cannot quietly make it the
broken one.

  1. `carry_baseline` copies every baseline key verbatim.
  2. a missing manifest (first-ever measure) carries nothing, and is not an error.
  3. an unreadable/corrupt manifest carries nothing rather than crashing the
     measure -- twelve minutes in is a bad place to raise.
  4. ⭐ the REAL measure-path writer (`build_manifest`) carries the baseline.
     This is the case whose absence was the bug.
  5. ⭐ ...and does NOT re-derive it from the current run.  A re-measure knows
     which tests are red today; adopting that set would amnesty a red the
     measuring round had just introduced, which is a fail-OPEN and strictly
     worse than the bug being fixed.
  6. ⭐ every baseline key `set_known_red` writes is registered in
     BASELINE_KEYS, and the keys `lua_gate.py` actually reads are registered
     too.  This is the half that cannot rot.
  7. `reselect()` preserves the baseline as well, so both surviving paths agree.
  8. the carried baseline is visible to the CONSUMER's own read
     (`set(manifest.get("known_red") or ())`), not merely present in the file.

⚠️ WHAT THIS FILE DOES NOT BUY.  It never runs a real measurement pass (~12
minutes) and never runs `lua_gate.py` end to end against real Lua.  Case 8
reproduces the consumer's read expression rather than calling it, because in
`lua_gate.py` that read is inline in a function that also runs the suite.  So
this asserts the manifest CONTRACT, not the gate's behaviour on a live tree;
the issue's own acceptance ("run a real measure, then a real gate") remains the
thing only a slow round can do.

Run:  python3 tests/test_lua_gate_baseline_carryover.py
"""

import importlib.util
import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "agent", "lua_gate_measure.py")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if cond:
        print("  ok   %s" % label)
    else:
        print("  FAIL %s" % label)
        failures.append(label)


def try_carry(mod, target, path):
    """`carry_baseline`, with a raise reported as a FAIL instead of a traceback.

    The mutation stand for this file killed two mutants by TRACEBACK rather
    than by a named check -- correct as a signal, useless as a message, and it
    aborts the remaining cases so one mutation reads as one failure of unknown
    shape.  A gate whose failure mode is a stack trace is a gate the next
    person has to re-derive.
    """
    try:
        return mod.carry_baseline(target, path), None
    except Exception as exc:                                 # noqa: BLE001
        return None, "%s: %s" % (type(exc).__name__, exc)


def load_tool():
    """Import the tool as a module so its real functions are the subject."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "agent"))
    spec = importlib.util.spec_from_file_location("lua_gate_measure", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def a_baseline():
    """A baseline shaped like the live one: two files, cases for one of them."""
    return {
        "known_red": ["tests/test_alpha.lua", "tests/test_beta.lua"],
        "known_red_cases": {"tests/test_alpha.lua": ["alpha.CASE_ONE"]},
        "known_red_at": "2026-09-10T00:00:00Z",
        "known_red_note": "baselined when the leg landed",
    }


def a_tests_block(names):
    return {os.path.join("tests", n): {"seconds": 1.5, "in_gate": True,
                                       "reason": "fast"} for n in names}


def write_manifest(path, extra):
    man = {"_comment": "x", "measured_at": "2026-09-10T00:00:00Z",
           "per_test_cap_seconds": 5.5, "budget_seconds": 240.0,
           "measure_timeout_seconds": 240, "hook_timeout_seconds": 300,
           "selected_total_seconds": 3.0, "selected_count": 2,
           "measured_count": 2,
           "tests": a_tests_block(["test_alpha.lua", "test_beta.lua"])}
    man.update(extra)
    with open(path, "w") as fh:
        json.dump(man, fh, indent=2, sort_keys=True)
        fh.write("\n")
    return man


def main():
    lgm = load_tool()
    work = tempfile.mkdtemp(prefix="lgb_")
    live_manifest = lgm.MANIFEST
    try:
        # 1. verbatim copy -------------------------------------------------
        print("case 1: carry_baseline copies every key verbatim")
        p = os.path.join(work, "m1.json")
        base = a_baseline()
        write_manifest(p, base)
        got = {}
        n, raised = try_carry(lgm, got, p)
        check(raised is None, "does not raise%s" % ("" if not raised else " -- %s" % raised))
        check(n == len(lgm.BASELINE_KEYS),
              "reports the number of keys it carried (%s)" % n)
        for key in lgm.BASELINE_KEYS:
            check(got.get(key) == base[key], "%s is byte-identical" % key)

        # 2. no old manifest -----------------------------------------------
        print("\ncase 2: a first-ever measure carries nothing and does not raise")
        got = {}
        n, raised = try_carry(lgm, got, os.path.join(work, "does_not_exist.json"))
        check(raised is None,
              "a missing manifest does not raise%s" % ("" if not raised else " -- %s" % raised))
        check(n == 0, "carries 0 keys")
        check(got == {}, "adds nothing at all")

        # 3. corrupt old manifest ------------------------------------------
        print("\ncase 3: an unreadable manifest carries nothing, still no raise")
        bad = os.path.join(work, "bad.json")
        with open(bad, "w") as fh:
            fh.write("{ this is not json")
        got = {}
        n, raised = try_carry(lgm, got, bad)
        check(raised is None,
              "a corrupt manifest does not raise%s" % ("" if not raised else " -- %s" % raised))
        check(n == 0, "carries 0 keys from a corrupt file")
        check(got == {}, "adds nothing at all")

        # 4. THE BUG: the measure path's own writer ------------------------
        print("\ncase 4: build_manifest (the measure path) carries the baseline")
        p4 = os.path.join(work, "m4.json")
        write_manifest(p4, a_baseline())
        lgm.MANIFEST = p4
        tests = a_tests_block(["test_alpha.lua", "test_beta.lua"])
        man, carried = lgm.build_manifest(tests, 3.0, 2, 2)
        check(carried == len(lgm.BASELINE_KEYS),
              "the writer reports carrying %d keys" % carried)
        for key in lgm.BASELINE_KEYS:
            check(man.get(key) == a_baseline()[key],
                  "re-measured manifest still has %s" % key)
        check(man["tests"] == tests,
              "...while the MEASUREMENTS are the new ones, not the old ones")

        # 5. and does not invent one ---------------------------------------
        print("\ncase 5: the baseline is carried, never re-derived from this run")
        p5 = os.path.join(work, "m5.json")
        narrow = dict(a_baseline())
        narrow["known_red"] = ["tests/test_alpha.lua"]
        narrow["known_red_cases"] = {"tests/test_alpha.lua": ["alpha.CASE_ONE"]}
        write_manifest(p5, narrow)
        lgm.MANIFEST = p5
        # test_gamma is red on THIS tree and was never baselined.  A writer that
        # re-derived the baseline from the current run would amnesty it.
        tests5 = a_tests_block(["test_alpha.lua", "test_gamma.lua"])
        man5, _ = lgm.build_manifest(tests5, 3.0, 2, 2)
        check(man5.get("known_red") == ["tests/test_alpha.lua"],
              "known_red is exactly the old list")
        check("tests/test_gamma.lua" not in (man5.get("known_red") or ()),
              "a test red on THIS tree is NOT amnestied by re-measuring")

        # 6. one registry, and the consumer reads what is in it -------------
        print("\ncase 6: every baseline key a writer writes is registered")
        src = open(TOOL).read()
        written = set()
        for line in src.splitlines():
            s = line.strip()
            if s.startswith("baseline[\"") and "] = " in s:
                written.add(s.split("\"")[1])
        check(bool(written), "found the set_known_red writer's keys in source")
        unregistered = sorted(written - set(lgm.BASELINE_KEYS))
        check(not unregistered,
              "set_known_red writes no key missing from BASELINE_KEYS%s"
              % ("" if not unregistered else " -- %s" % unregistered))
        gate_src = open(os.path.join(ROOT, "tools", "agent", "lua_gate.py")).read()
        read_by_gate = {k for k in ("known_red", "known_red_cases")
                        if 'manifest.get("%s")' % k in gate_src}
        check(read_by_gate == {"known_red", "known_red_cases"},
              "the gate still reads both keys this test claims it reads")
        check(read_by_gate <= set(lgm.BASELINE_KEYS),
              "every key the gate reads is registered for carry-over")

        # 7. the other surviving writer -------------------------------------
        print("\ncase 7: reselect() preserves the baseline too")
        p7 = os.path.join(work, "m7.json")
        write_manifest(p7, a_baseline())
        lgm.MANIFEST = p7
        rc = lgm.reselect([])
        check(rc == 0, "reselect exits 0")
        with open(p7) as fh:
            after = json.load(fh)
        for key in lgm.BASELINE_KEYS:
            check(after.get(key) == a_baseline()[key],
                  "reselect kept %s byte-identical" % key)

        # 8. the consumer's own read ----------------------------------------
        print("\ncase 8: the carried baseline is visible to the gate's read")
        p8 = os.path.join(work, "m8.json")
        write_manifest(p8, a_baseline())
        lgm.MANIFEST = p8
        man8, _ = lgm.build_manifest(a_tests_block(["test_alpha.lua"]), 1.5, 1, 1)
        with open(p8, "w") as fh:
            json.dump(man8, fh, indent=2, sort_keys=True)
        with open(p8) as fh:
            round_tripped = json.load(fh)
        # Verbatim the expression in lua_gate.py.
        seen = set(round_tripped.get("known_red") or ())
        check(seen == {"tests/test_alpha.lua", "tests/test_beta.lua"},
              "the gate's read finds both baselined tests after a re-measure")
        check(seen, "...and it is not the empty baseline the bug produced")
    finally:
        lgm.MANIFEST = live_manifest
        shutil.rmtree(work, ignore_errors=True)

    print("\n%d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  - %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
