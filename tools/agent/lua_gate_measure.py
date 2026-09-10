#!/usr/bin/env python3
"""Measure every tests/test_*.lua and write the Lua push-gate manifest.

WHY THIS FILE EXISTS (GH #624, director ruling 2026-09-10).

`.githooks/pre-push` runs iron rule 6's Lua STATIC half (`luacheck`, GH #205 /
GH #213) and the FAST PYTHON ratchets (`py_gate.py`, GH #616).  It runs no Lua
TEST at all.  GH #624 measured what that gap costs: a Lua census test goes red
the moment someone lands a new gate/call site, the pusher's own gate is silent
about it, and the red is discovered by the NEXT stream to start work -- when the
stream that tripped it is already gone.  Four instances by 2026-09-10, three of
them standing red on `main` at once.

This file is `py_gate_measure.py`'s sibling and deliberately copies its rule:

⛔ MEMBERSHIP IS DECIDED BY MEASURED SECONDS, NEVER BY FILENAME (GH #616
constraint 1).  "Anything with `census` in the name goes in the gate" is this
repo's most-repeated defect shape -- a detector that knows one spelling calls
every other spelling absent.  A name is a claim about a file; seconds are a
measurement of it.  So this tool RUNS each test and writes down what it cost.

WHAT IS DIFFERENT FROM THE PYTHON SIBLING, AND WHY -- the knobs are not copied,
they are re-measured, because the two populations are not alike:

  * a python ratchet is ~0.1-0.5s; 84 of 114 fit in 12s.
  * a Lua test pays for a fresh Lua VM, the mock Bot API, and (for a census)
    a walk of the whole `bots/` corpus.  The three reds GH #624 is about
    measured 1.88s / 2.60s / 4.72s on 2026-09-10 -- i.e. the tests this gate
    exists for are among the EXPENSIVE ones, not the cheap ones.

That last line is the trap in a verbatim port: cheapest-first with a 12s budget
would fill the gate with the cheapest 12s of tests and leave out every test the
issue was opened about, while still reporting a healthy `selected_count`.  So
the knobs live in the manifest, they are set from THIS measurement's real
distribution, and `--dry-run` prints the distribution so the next person can
re-derive them instead of inheriting them.

⚠️ WHAT THIS DOES NOT BUY, stated rather than implied.  A test slower than the
per-test cap stays out of the hook; it is covered only by 开工自检 and the full
suite (~100 min, GH #124).  The manifest names every one of them with a
`reason`, so "why was this not caught at push time" is always answerable
without guessing.

Usage:
    python3 tools/agent/lua_gate_measure.py            # measure, write manifest
    python3 tools/agent/lua_gate_measure.py --dry-run  # measure, print, no write
"""
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# The gate's own parser, imported rather than re-implemented: a baseline
# written by one regex and read by another is a baseline that silently stops
# matching the day either drifts.
import lua_gate  # noqa: E402

# this file is tools/agent/<me>.py -- three dirnames up is the repo root
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "agent", "lua_gate_manifest.json")

# A test slower than this never enters the hook, even if the budget has room.
#
# 5.5s, and the number came off a COVERAGE CURVE rather than taste.  Once scope
# (not budget) controls cost, this knob's only remaining job is to keep a
# 120s-class leg out of a push hook, so it was swept against the question the
# gate exists to answer -- how many of the 18 tests red on trunk 2026-09-10 it
# would catch:
#
#     cap 3.0s -> 302 tests, 152.8s, 12/18      cap 5.0s -> 318 tests, 217.8s, 16/18
#     cap 4.0s -> 309 tests, 177.5s, 14/18      cap 5.5s -> 322 tests, 238.7s, 18/18
#     cap 6.0s -> 324 tests, 249.9s, 18/18  <- buys nothing more
#
# 5.5 is the smallest cap that saturates, which is why it is not an arbitrary
# pick.  ⚠️ It is fitted to ONE sample (one tree, one day) and could be
# overfitted to it; the curve is printed here so the next person re-sweeps
# instead of inheriting.  It must also stay under MEASURE_TIMEOUT_SECONDS --
# otherwise a `timed_out` entry, whose seconds are the timeout rather than a
# measurement, would become selectable on a number nobody measured.
PER_TEST_CAP_SECONDS = 5.5
# Cheapest-first cumulative ceiling for everything the hook runs.
#
# ⭐⭐ THIS NUMBER IS DELIBERATELY LARGE ENOUGH TO TAKE EVERY SUB-CAP TEST, AND
# THAT IS A RULING, NOT A SLOPPY KNOB (director 2026-09-10, GH #624).  The
# first landing of this file used 25.0s cheapest-first, copying the python
# sibling.  Then its own measurement was pointed at the question the gate
# exists to answer -- "of the tests RED on this tree right now, how many would
# the hook have caught?" -- and the answer killed BOTH orderings:
#
#     18 tests red on trunk, 2026-09-10
#     cheapest-first,  25s budget -> 169 tests,  3/18 caught
#     cheapest-first,  60s budget -> 244 tests,  5/18 caught
#     expensive-first, 25s budget ->  10 tests,  0/18 caught
#     expensive-first, 40s budget ->  17 tests,  0/18 caught
#
# Reds DO skew expensive (72% of them cost >=1.0s against 36% of the
# population), so "take the expensive ones" sounds right and is measurably
# WORSE: it spends the whole budget on ten slow tests that happen to be green.
# The reds run from 0.13s to 5.12s -- there is no cheap subset that contains
# them, so no ordering rescues a small budget.  A 3/18 gate that reported a
# healthy `selected_count` would have been this repo's own favourite defect
# (green because it asserted nothing) rebuilt on purpose.
#
# So the budget stops being the lever.  Cost is controlled by SCOPE instead --
# `lua_gate.py --if-touched` runs nothing when the push carries no Lua corpus
# and no test (GH #624 option 1, word for word: "even if only run when the
# files they each touch are changed").  A push that does touch them pays for
# every sub-cap test, which is the only selection that actually covers the
# population.  Measured under load 2026-09-10: 322 tests under the cap, 238.7s.
#
# ⚠️ IT MUST STAY CLEAR OF THE CAP'S OWN TOTAL, and the first try did not: at
# 200.0 the budget bound before the cap did, silently dropping 8 of the 322 and
# taking trunk-red coverage back from 18/18 down to 14/18 -- a knob set for
# cost quietly overruling the knob set from the coverage curve, with nothing in
# the output raising a hand.  300.0 leaves the CAP as the only live selector,
# which is what the ruling above decided.  If a future sweep raises the cap,
# re-check this number instead of assuming it still has headroom.
BUDGET_SECONDS = 300.0
# Hard stop while measuring.  Anything at or over the per-test cap is out
# regardless, so there is no reason to pay for its exact number.
MEASURE_TIMEOUT_SECONDS = 6.0
# What the hook allows a selected test before calling it a change of state.
# Generous headroom over the cap for the same reason py_gate_measure.py records:
# contention on this container is real, and a loaded container must not read as
# a broken test.
HOOK_TIMEOUT_SECONDS = 20.0

LUA = os.environ.get("LUA_BIN", "lua5.1")


def discover(root):
    d = os.path.join(root, "tests")
    return sorted(
        f for f in os.listdir(d) if f.startswith("test_") and f.endswith(".lua")
    )


def ambiguous_filters(names):
    """Filenames that are a SUBSTRING of another filename.

    `tests/run_tests.lua <filter>` matches a filename SUBSTRING, so a name
    contained in another name would silently run two files under one entry --
    the measurement would be of the pair and the gate would run the pair.  This
    has to be a checked fact rather than an assumption: it is exactly the shape
    where a wrong number looks like an ordinary number.
    """
    return sorted(a for a in names if any(a != b and a in b for b in names))


def measure_one(root, name):
    """Return (seconds, rc, timed_out).  rc is the runner's own exit code."""
    t0 = time.time()
    try:
        p = subprocess.run(
            [LUA, "tests/run_tests.lua", name],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=MEASURE_TIMEOUT_SECONDS,
        )
        return time.time() - t0, p.returncode, False
    except subprocess.TimeoutExpired:
        return MEASURE_TIMEOUT_SECONDS, None, True


def _run_case_probe(rel):
    """Run one baselined test and return (rc, output) for case extraction.

    Same invocation as `measure_one` -- through the runner, never the file
    directly.  Timing is irrelevant here, so a generous timeout is fine; what
    matters is that the output is the same output the GATE will parse, because
    the baseline is only worth anything if both sides read the same shape.
    """
    try:
        p = subprocess.run(
            [LUA, "tests/run_tests.lua", os.path.basename(rel)],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=MEASURE_TIMEOUT_SECONDS,
        )
        return p.returncode, p.stdout.decode("utf-8", "replace")
    except subprocess.TimeoutExpired as exc:
        return None, (exc.output or b"").decode("utf-8", "replace")


def select(measurements, per_test_cap, budget):
    """By seconds, cheapest first, never by name.  Every file gets a `reason`."""
    tests = {}
    total = 0.0
    for name, (secs, rc, timed_out) in sorted(measurements.items(), key=lambda kv: kv[1][0]):
        rel = os.path.join("tests", name)
        if timed_out or secs >= per_test_cap:
            tests[rel] = {"seconds": round(secs, 3), "in_gate": False,
                          "reason": "timed_out" if timed_out else "too_slow"}
            continue
        if total + secs > budget:
            tests[rel] = {"seconds": round(secs, 3), "in_gate": False,
                          "reason": "over_cumulative_budget"}
            continue
        total += secs
        tests[rel] = {"seconds": round(secs, 3), "in_gate": True, "reason": "fast"}
    return tests, total


def set_known_red(argv):
    """Write the manifest's `known_red` baseline from a file of test names.

    WHY A BASELINE EXISTS AT ALL (director 2026-09-10, GH #624).  This leg
    landed on a tree with EIGHTEEN Lua tests already red -- each one confirmed
    individually and unloaded, not inferred from the measurement pass.  A gate
    with no baseline would therefore have refused every push in the repo from
    its first minute, which is not a gate but a blockade, reachable only
    through the `RULE6_BYPASS=1` hatch that exists to record a SKIPPED gate.
    The header of `luacheck_gate.sh` names that exact outcome as the reason it
    does not port a guard it would otherwise want.

    So the gate's promise is the honest one: **you did not ADD a red.**

    ⚠️ WHAT A BASELINE COSTS, said out loud because this is the dangerous half.
    A baselined test is one nobody has to look at, and an amnesty nobody
    revisits is permanent.  Three things push the other way, none of them
    subtle: every run PRINTS the baselined tests by name with a count; a
    baselined test that starts passing prints a line asking to be removed; and
    the list can only be rewritten by this tool, from a file of measured
    results, never by hand.
    ⛔ WHAT IT CANNOT DO: a baselined test that goes red for a SECOND, NEW
    reason still reads as "known".  There is no channel that separates them,
    so shrinking the list is the only real fix and the printout says so.

    Usage: python3 tools/agent/lua_gate_measure.py --set-known-red <file>
    """
    i = argv.index("--set-known-red")
    src = argv[i + 1]
    names = [ln.strip() for ln in open(src) if ln.strip()]
    with open(MANIFEST) as fh:
        man = json.load(fh)
    rels = sorted({n if n.startswith("tests/") else os.path.join("tests", n)
                   for n in names})
    unknown = [r for r in rels if r not in man["tests"]]
    if unknown:
        print("REFUSED -- these are not measured tests: %s" % " ".join(unknown))
        return 2
    # Record WHICH CASES are red, not just which files.  Each named test is
    # re-run here through the runner so the case list is measured on this tree
    # rather than copied out of whatever produced `src`.  A file whose red
    # names no case is recorded with an EMPTY list, which the gate reads as
    # "no case ever matched here" and therefore refuses on -- the safe
    # direction, and it shows up as a finding rather than as silence.
    cases, unreadable = {}, []
    for rel in rels:
        rc, out = _run_case_probe(rel)
        if rc == 0:
            # It passes now; it does not belong in a red baseline at all.
            unreadable.append((rel, "passes on this tree -- do not baseline it"))
            continue
        found = sorted(lua_gate.failing_cases(out))
        cases[rel] = found
        if not found:
            unreadable.append((rel, "red, but its output names no test case"))
    if unreadable:
        print("⚠️  %d entr(ies) could not be given a case list:" % len(unreadable))
        for rel, why in unreadable:
            print("      %s  (%s)" % (rel, why))
        print("   These are recorded as-is. An empty case list is NOT an "
              "amnesty: the gate treats an unrecognised red shape as new.")

    man["known_red"] = rels
    man["known_red_cases"] = {r: cases[r] for r in rels if r in cases}
    man["known_red_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    man["known_red_note"] = (
        "Red on trunk when this leg landed (GH #624), each confirmed by an "
        "individual unloaded re-run. The gate does not refuse a push for these; "
        "it refuses for anything NOT on this list. The list is meant to SHRINK "
        "-- it is not an exemption, and it is printed by name on every run. "
        "`known_red_cases` narrows each entry to the CASES that were failing: a "
        "baselined file that starts failing somewhere NEW refuses the push, "
        "while ordinary corpus drift inside an already-failing case does not.")
    with open(MANIFEST, "w") as fh:
        json.dump(man, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print("known_red: %d test(s) baselined, %d case(s) recorded"
          % (len(rels), sum(len(v) for v in cases.values())))
    return 0


def reselect(argv):
    """Re-run `select()` on the seconds ALREADY recorded, without re-running.

    A measurement pass costs ~12 minutes of wall clock; re-deriving the
    selection from knobs does not need to cost that, and re-running the tests
    to answer a question about the KNOBS would also silently re-measure them
    under whatever load the container happens to carry -- two changes at once,
    the older of which is invisible in the diff.  So a knob change replays the
    stored seconds and says so in `reselected_at`.
    """
    with open(MANIFEST) as fh:
        old = json.load(fh)
    measurements = {
        os.path.basename(rel): (meta["seconds"], 0, meta["reason"] == "timed_out")
        for rel, meta in old["tests"].items()
    }
    tests, total = select(measurements, PER_TEST_CAP_SECONDS, BUDGET_SECONDS)
    n_in = sum(1 for v in tests.values() if v["in_gate"])
    old.update({
        "per_test_cap_seconds": PER_TEST_CAP_SECONDS,
        "budget_seconds": BUDGET_SECONDS,
        "hook_timeout_seconds": HOOK_TIMEOUT_SECONDS,
        "selected_total_seconds": round(total, 3),
        "selected_count": n_in,
        "reselected_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "reselected_note": ("knobs replayed over the seconds recorded at "
                            "`measured_at`; no test was re-run"),
        "tests": tests,
    })
    if "--dry-run" in argv:
        print("reselect: %d tests, %.3fs (--dry-run: manifest NOT written)"
              % (n_in, total))
        return 0
    with open(MANIFEST, "w") as fh:
        json.dump(old, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print("reselect: %d of %d tests, %.3fs of the %.1fs budget (cap %.1fs)"
          % (n_in, len(tests), total, BUDGET_SECONDS, PER_TEST_CAP_SECONDS))
    print("wrote %s" % MANIFEST)
    return 0


def main(argv):
    if "--set-known-red" in argv:
        return set_known_red(argv)
    if "--reselect" in argv:
        return reselect(argv)
    dry = "--dry-run" in argv
    names = discover(ROOT)
    amb = ambiguous_filters(names)
    if amb:
        # Not a crash: report it and drop them.  A filename that is a substring
        # of another cannot be measured or run alone through this runner, and
        # pretending otherwise is how a reading of the wrong thing gets stored
        # as a reading of the right thing.
        print("AMBIGUOUS FILTER (name is a substring of another test's name; "
              "excluded from the gate):")
        for a in amb:
            print("   ", a)
        names = [n for n in names if n not in amb]

    measurements = {}
    t_wall = time.time()
    for i, name in enumerate(names, 1):
        secs, rc, timed_out = measure_one(ROOT, name)
        measurements[name] = (secs, rc, timed_out)
        flag = "TIMEOUT" if timed_out else ("red" if rc else "ok")
        print(f"[{i:3d}/{len(names)}] {secs:6.2f}s {flag:8s} {name}", flush=True)

    tests, total = select(measurements, PER_TEST_CAP_SECONDS, BUDGET_SECONDS)
    n_in = sum(1 for v in tests.values() if v["in_gate"])

    secs_sorted = sorted(v[0] for v in measurements.values())
    def pct(p):
        return secs_sorted[min(len(secs_sorted) - 1, int(len(secs_sorted) * p))]
    print()
    print(f"measured {len(measurements)} files in {time.time() - t_wall:.0f}s wall")
    print(f"distribution: p50={pct(0.5):.2f}s p75={pct(0.75):.2f}s "
          f"p90={pct(0.9):.2f}s max={secs_sorted[-1]:.2f}s")
    print(f"selected {n_in} tests, {total:.3f}s of the {BUDGET_SECONDS}s budget "
          f"(per-test cap {PER_TEST_CAP_SECONDS}s)")
    red = sorted(n for n, (s, rc, t) in measurements.items() if rc not in (0, None))
    if red:
        print(f"RED ON THIS TREE ({len(red)}):")
        for n in red:
            print("   ", n, "IN GATE" if tests[os.path.join("tests", n)]["in_gate"] else "not in gate")

    if dry:
        print("\n--dry-run: manifest NOT written")
        return 0

    manifest = {
        "_comment": ("Generated by tools/agent/lua_gate_measure.py (GH #624). "
                     "Selection is by MEASURED SECONDS, never by filename. "
                     "Do not hand-edit; re-measure."),
        "measured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "per_test_cap_seconds": PER_TEST_CAP_SECONDS,
        "budget_seconds": BUDGET_SECONDS,
        "measure_timeout_seconds": MEASURE_TIMEOUT_SECONDS,
        "hook_timeout_seconds": HOOK_TIMEOUT_SECONDS,
        "selected_total_seconds": round(total, 3),
        "selected_count": n_in,
        "measured_count": len(measurements),
        "tests": tests,
    }
    with open(MANIFEST, "w") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print(f"\nwrote {MANIFEST}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
