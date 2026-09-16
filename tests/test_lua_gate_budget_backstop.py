#!/usr/bin/env python3
"""Acceptance for the Lua push-gate's cumulative budget being a BACKSTOP, and
for every manifest row carrying a reason a writer could actually have written
(director 2026-09-16, RULING 62; GH #810, GH #624, sibling of GH #839).

TWO DEFECTS, ONE FILE, AND THEY FEED EACH OTHER.

(A) THE BUDGET'S MARGIN WAS A JUDGEMENT CALL, NOT A RULE.  `lua_gate_measure.py`
already rules that the per-test cap is the only live selector and the
cumulative budget is a backstop -- its own header says so, and records that at
200.0 the budget silently bound before the cap, dropping 8 of 322 tests and
taking trunk-red coverage from 18/18 down to 14/18 "with nothing in the output
raising a hand".  It then set 300.0 against a sub-cap total of 250.7s: a 1.20x
margin.  ⭐ NOTHING IN THE REPO CHECKED THAT MARGIN, so the difference between
"backstop" and "selector" was a sentence in a docstring, and the failure it
describes is silent by construction -- an evicted test gets a `reason` and no
one reads reasons.  The sibling python leg had the identical hole and needed a
ruling of its own (RULING 61) to notice it.

(B) A ROW WHOSE `reason` NO WRITER COULD HAVE WRITTEN IS A HAND-EDIT, and the
manifest's own `_comment` forbids hand-edits ("Do not hand-edit; re-measure").
Three rows carried reasons like `fast (measured individually 2026-09-15 by
hero, NOT by a suite re-measure: lua_gate_measure.py rewrites known_red and
would block the next pusher, GH #783)`.  ⭐ THAT STATED BLOCKER WAS ALREADY
FALSE WHEN IT WAS LAST COPIED: GH #783's fix (`carry_baseline` in
`build_manifest`) landed 2026-09-15T16:25:31Z, and the same change rewrote the
`_comment` to read "re-measure -- which PRESERVES the `known_red` baseline".
The last row citing it landed 2026-09-16T02:14:00Z, nine hours later, because
the reason string was copied from the row above it.  A stale premise spreads by
copy-paste and nothing refuses it.

⭐ WHY (B) IS NOT A STYLE COMPLAINT.  Each hand-edited row carries SECONDS that
no measurement pass produced, and seconds are what (A) is computed from.  So a
hand-edit is an unmeasured number feeding the very total that decides whether
the budget is still a backstop -- the two defects are the same defect seen at
two distances.

⛔ WHY THE ALLOWED SET IS DERIVED, NOT LISTED.  Hardcoding
{"fast", "too_slow", ...} here would rot the first time `select()` grows a
branch, and would rot SILENTLY in the permissive direction is not the risk --
it rots in the refusing direction, which is worse in practice: the next person
to add a legitimate reason gets a red they did not cause and reaches for the
bypass.  So case 2 runs `select()` over synthetic measurements that hit every
branch and reads the reasons back out of it.  Case 1 then checks the shipped
manifest against that.  If `select()` gains a branch, this file follows it with
no edit.

  1. ⭐ every row in the shipped manifest carries a reason `select()` can emit.
  2. the allowed set is really derived -- `select()` emits all of them on
     synthetic input, so case 1 cannot pass by comparing against an empty set.
  3. ⭐ the cumulative budget evicted nothing: no row is `over_cumulative_budget`.
     This is the assertion whose absence let 200.0 bind unnoticed.
  4. ⭐ the budget is a backstop by the written rule: >= 2x the shipped sub-cap
     total.  The rule, not the number, is what survives the next re-measure.
  5. the knobs in the module and the knobs recorded in the manifest agree --
     otherwise cases 3 and 4 grade a manifest that the current code would not
     produce.
"""

import importlib.util
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "tools", "agent", "lua_gate_measure.py")
MANIFEST = os.path.join(ROOT, "tools", "agent", "lua_gate_manifest.json")

# How much headroom over the measured sub-cap total makes the budget a
# backstop rather than a selector.  RULING 61 fixed this rule on the python
# sibling; RULING 62 carries it here.  It is a rule so that a re-measure on a
# slower container cannot quietly turn the backstop back into a selector.
BACKSTOP_MULTIPLE = 2.0

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


def load_tool():
    """Import the tool as a module so its real `select()` is the subject."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "agent"))
    spec = importlib.util.spec_from_file_location("lua_gate_measure", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def producible_reasons(mod):
    """Every `reason` string `select()` can put on a row, read out of it.

    Synthetic measurements are built to hit each branch of `select()`:
    a cheap test, a test at/over the per-test cap, a timed-out test, and -- by
    handing `select` a deliberately tiny budget -- a test evicted by the
    cumulative ceiling.  The budget used here is a local argument, NOT the
    module's; this function asks what the code CAN emit, never what the
    shipped knobs do emit.
    """
    cap = mod.PER_TEST_CAP_SECONDS
    # name -> (seconds, rc, timed_out)
    sample = {
        "test_cheap.lua": (0.10, 0, False),
        "test_also_cheap.lua": (0.20, 0, False),
        "test_over_cap.lua": (cap + 1.0, 0, False),
        "test_timed_out.lua": (mod.MEASURE_TIMEOUT_SECONDS, 0, True),
    }
    reasons = set()
    # A budget big enough to take both cheap tests, and one too small to take
    # the second -- together these reach every branch.
    for budget in (1000.0, 0.15):
        rows, _ = mod.select(sample, cap, budget)
        reasons.update(r["reason"] for r in rows.values())
    return reasons


def main():
    mod = load_tool()
    with open(MANIFEST) as fh:
        man = json.load(fh)
    rows = man["tests"]

    allowed = producible_reasons(mod)

    print("case 1: every manifest row's reason is one select() can emit")
    bad = sorted((rel, meta["reason"]) for rel, meta in rows.items()
                 if meta.get("reason") not in allowed)
    if bad:
        print("     %d hand-edited row(s) -- the manifest's own _comment says "
              "\"Do not hand-edit; re-measure\":" % len(bad))
        for rel, reason in bad:
            print("       %s\n           %s" % (rel, reason))
        print("     Remedy: re-measure, or `python3 tools/agent/"
              "lua_gate_measure.py --reselect` to re-derive every reason from "
              "the stored seconds without re-running anything.")
    check(not bad, "no hand-edited reason among %d row(s) (allowed: %s)"
          % (len(rows), ", ".join(sorted(allowed))))

    print("\ncase 2: the allowed set is derived from select(), not listed here")
    check(len(allowed) >= 4,
          "select() emits %d distinct reason(s) on synthetic input: %s"
          % (len(allowed), ", ".join(sorted(allowed))))
    check("fast" in allowed and "over_cumulative_budget" in allowed,
          "the derivation reaches both the accepting and the evicting branch")

    print("\ncase 3: the cumulative budget evicted nothing")
    evicted = sorted(rel for rel, meta in rows.items()
                     if meta.get("reason") == "over_cumulative_budget")
    if evicted:
        print("     the budget bound before the per-test cap did, which is the "
              "2026-09-10 failure at 200.0 repeating:")
        for rel in evicted:
            print("       %s  (%.3fs -- under the %.1fs cap)"
                  % (rel, rows[rel]["seconds"], mod.PER_TEST_CAP_SECONDS))
    check(not evicted,
          "0 of %d row(s) excluded by the cumulative budget" % len(rows))

    print("\ncase 4: the budget is a backstop, not a selector")
    sub_cap = sum(m["seconds"] for m in rows.values() if m.get("in_gate"))
    need = BACKSTOP_MULTIPLE * sub_cap
    budget = mod.BUDGET_SECONDS
    print("     sub-cap total %.1fs over %d in-gate row(s); budget %.1fs = "
          "%.2fx" % (sub_cap, sum(1 for m in rows.values() if m.get("in_gate")),
                     budget, budget / sub_cap if sub_cap else 0.0))
    check(budget >= need,
          "budget %.1fs >= %.1fx sub-cap total (%.1fs)"
          % (budget, BACKSTOP_MULTIPLE, need))

    print("\ncase 5: the module's knobs and the manifest's recorded knobs agree")
    check(man.get("budget_seconds") == mod.BUDGET_SECONDS,
          "budget_seconds: manifest %s == module %s"
          % (man.get("budget_seconds"), mod.BUDGET_SECONDS))
    check(man.get("per_test_cap_seconds") == mod.PER_TEST_CAP_SECONDS,
          "per_test_cap_seconds: manifest %s == module %s"
          % (man.get("per_test_cap_seconds"), mod.PER_TEST_CAP_SECONDS))

    print("\n%d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  - %s" % f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
