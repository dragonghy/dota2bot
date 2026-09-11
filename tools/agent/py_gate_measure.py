#!/usr/bin/env python3
"""Measure every tests/test_*.py and write the push-gate manifest.

WHY THIS FILE EXISTS (GH #616).

Iron rule 6's push gate (`.githooks/pre-push` -> `tools/agent/luacheck_gate.sh`)
covers the Lua static half only.  The python ratchets were in NO push gate, so
the only leg that ever ran them was the director's 开工自检 -- one stream, every
2h -- and a red therefore sat on `main` for half a day while the stream that
tripped it had already ended its round.  09-05 read 7 reds at once.

The fix is to put the FAST python ratchets in the hook.  The whole suite cannot
go in: `tests/test_selfcheck_lua_leg.py` alone carries a 120s budget (GH #358).

⛔ The selection must be MACHINE-READABLE AND BY MEASURED SECONDS, never by name
(GH #616 constraint 1).  "Anything with `ratchet` in the filename goes in the
gate" is this repo's most-repeated defect shape: a detector that knows one
spelling calls every other spelling absent (the 09-08 `"sha256sum" in src`
finding was that same shape, on the same file as an earlier fix for it).  A name
is a claim about a file; seconds are a measurement of it.  So this tool RUNS
each test and writes down what it cost.

Two knobs, both recorded in the manifest so the gate never re-derives them:

  per_test_cap_seconds   a single test slower than this is out, whatever it is
  budget_seconds         cheapest-first, include while the running total fits

The second knob is what keeps the acceptance promise in GH #616: the Lua static
half costs 18s cold, and this half "should not double it".

Usage:
    python3 tools/agent/py_gate_measure.py            # measure, write manifest
    python3 tools/agent/py_gate_measure.py --dry-run  # measure, print, no write
"""
import json
import os
import subprocess
import sys
import time

# this file is tools/agent/<me>.py -- three dirnames up is the repo root
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "agent", "py_gate_manifest.json")

# A test slower than this never enters the hook, even if the budget has room.
PER_TEST_CAP_SECONDS = 3.0
# Cheapest-first cumulative ceiling for everything the hook runs.
BUDGET_SECONDS = 12.0
# Hard stop while measuring: a leg like test_selfcheck_lua_leg.py budgets 120s
# (GH #358) and we do not need its exact number to know it is out.
MEASURE_TIMEOUT_SECONDS = 20.0
# What the hook allows a selected test before calling it a change of state.
# Generous headroom over the cap: a loaded container must not read as a broken
# test.  Measured 2026-09-08: running the measure pass while 开工自检 was also
# running flipped `test_carrier_hero_guard.py` to rc=1, which it does NOT do
# when run alone -- contention is real on this container, and this headroom is
# what keeps it out of the gate's verdict.
HOOK_TIMEOUT_SECONDS = 15.0


def discover(root):
    d = os.path.join(root, "tests")
    return sorted(
        os.path.join("tests", f)
        for f in os.listdir(d)
        if f.startswith("test_") and f.endswith(".py")
    )


def measure_one(root, rel):
    """Return (seconds, rc, timed_out).  rc is the test's own exit code."""
    t0 = time.time()
    try:
        p = subprocess.run(
            [sys.executable, rel],
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=MEASURE_TIMEOUT_SECONDS,
        )
        return time.time() - t0, p.returncode, False
    except subprocess.TimeoutExpired:
        return MEASURE_TIMEOUT_SECONDS, None, True


def select(measurements, per_test_cap, budget):
    """Machine-readable selection: by seconds, cheapest first, never by name.

    Returns the manifest's `tests` mapping.  Every file gets a `reason`, so a
    reader can always answer "why is this one not in the gate" without guessing.
    """
    out = {}
    ordered = sorted(measurements, key=lambda m: m["seconds"])
    running = 0.0
    for m in ordered:
        rel = m["path"]
        # ⚠️ 2026-09-11 (director): ROUND ONCE, BEFORE SELECTING, and select on
        # the number that actually gets written down.  This used to select on
        # the raw float while storing `round(x, 3)`, so the manifest's ROWS and
        # its own `selected_total_seconds` disagreed by up to n * 5e-4 -- 0.033s
        # over 84 rows on the 2026-09-08 manifest, enough to put the row sum
        # (12.029) over a budget (12.0) the selection never crossed.  The red
        # that produces reads exactly like "the hook got too slow" and is
        # instead an artefact of rounding a number after deciding with it.
        secs = round(m["seconds"], 3)
        if m["timed_out"] or secs > per_test_cap:
            out[rel] = {
                "seconds": secs,
                "in_gate": False,
                "reason": "over_per_test_cap",
            }
            continue
        if running + secs > budget:
            out[rel] = {
                "seconds": secs,
                "in_gate": False,
                "reason": "over_cumulative_budget",
            }
            continue
        running += secs
        out[rel] = {
            "seconds": secs,
            "in_gate": True,
            "reason": "fast",
        }
    return out, running


def main():
    dry = "--dry-run" in sys.argv
    files = discover(ROOT)
    measurements = []
    for rel in files:
        secs, rc, timed_out = measure_one(ROOT, rel)
        measurements.append(
            {"path": rel, "seconds": secs, "rc": rc, "timed_out": timed_out}
        )
        flag = "TIMEOUT" if timed_out else ("rc=%s" % rc)
        print("%7.2fs  %-8s %s" % (secs, flag, rel), flush=True)

    tests, total = select(measurements, PER_TEST_CAP_SECONDS, BUDGET_SECONDS)
    in_gate = [k for k, v in tests.items() if v["in_gate"]]
    manifest = {
        "_comment": (
            "Generated by tools/agent/py_gate_measure.py (GH #616). Selection is "
            "by MEASURED SECONDS, never by filename. Do not hand-edit; re-measure."
        ),
        "measured_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "per_test_cap_seconds": PER_TEST_CAP_SECONDS,
        "budget_seconds": BUDGET_SECONDS,
        "measure_timeout_seconds": MEASURE_TIMEOUT_SECONDS,
        "hook_timeout_seconds": HOOK_TIMEOUT_SECONDS,
        "selected_total_seconds": round(total, 3),
        "selected_count": len(in_gate),
        "measured_count": len(tests),
        "tests": dict(sorted(tests.items())),
    }

    print(
        "\n%d of %d selected, %.2fs total (per-test cap %.1fs, budget %.1fs)"
        % (len(in_gate), len(tests), total, PER_TEST_CAP_SECONDS, BUDGET_SECONDS)
    )
    if dry:
        print("--dry-run: manifest NOT written")
        return 0
    with open(MANIFEST, "w") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=False)
        fh.write("\n")
    print("wrote %s" % os.path.relpath(MANIFEST, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
