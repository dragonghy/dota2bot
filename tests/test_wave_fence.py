#!/usr/bin/env python3
"""wave_fence.py must re-derive the fence, and must refuse rather than guess.

Director, 2026-09-05, GH #504.  These assertions are the ruling's teeth: the
defect being fixed is NOT "the number was wrong", it is "a derived number was
cached and its input resets monthly".  So the load-bearing test is the FIRST
one -- the same budget on 2026-08-31 and on 2026-09-01 must yield DIFFERENT
fences from the same code path, with nothing edited in between.

Exit 0 all good / 1 an assertion failed / 2 could not run (GH #243).
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tools", "batch_test", "soak"))

try:
    import wave_fence as wf
except Exception as exc:                                   # pragma: no cover
    print("UNCERTIFIABLE: cannot import wave_fence: %s" % exc)
    sys.exit(2)

failures = []
checks = 0


def check(ok, label, detail=""):
    global checks
    checks += 1
    if not ok:
        failures.append("FAIL: %s%s" % (label, ("  -- " + detail) if detail else ""))


# The real budget, as read from AWS 2026-09-05: limit $100, three ACTUAL
# notifications at 50/80/100 percent, ThresholdType absent (=> PERCENTAGE).
def notes(states=(None, None, None)):
    out = []
    for raw, state in zip((50.0, 80.0, 100.0), states):
        n = {"NotificationType": "ACTUAL", "ComparisonOperator": "GREATER_THAN",
             "Threshold": raw}
        if state is not None:
            n["NotificationState"] = state
        out.append(n)
    return out


def fence_of(actual, states=(None, None, None), limit=100.0):
    rows = wf.resolve_thresholds(notes(states), limit)
    row = wf.pick_fence(rows, actual)
    return None if row is None else row["amount"]


# ---- 1. THE LOAD-BEARING ONE: the monthly reset moves the fence by itself ---
# August: $57.60 spent, $50 crossed  => fence $80.  September 1st, same budget,
# same code, MTD back to ~0          => fence $50.  This is the whole defect.
check(fence_of(57.60) == 80.0, "August MTD $57.60 => fence $80",
      "got %r" % fence_of(57.60))
check(fence_of(0.0) == 50.0, "September MTD $0 => fence $50 (the reset)",
      "got %r" % fence_of(0.0))
check(fence_of(17.773) == 50.0,
      "the actual 2026-09-05 reading $17.773 => fence $50, not the cached $80",
      "got %r" % fence_of(17.773))

# ---- 2. Ruling 1: GREATER_THAN is strict, so sitting ON a threshold is not
#         crossing it, and that threshold is still the operative fence.
check(fence_of(50.0) == 50.0, "exactly $50 has NOT crossed the $50 alert",
      "got %r" % fence_of(50.0))
check(fence_of(50.01) == 80.0, "a cent over $50 moves the fence to $80",
      "got %r" % fence_of(50.01))

# ---- 3. Ruling 2: percentage vs absolute must not be decided by coincidence.
#         With limit $100 the two readings coincide; with limit $200 they must
#         not.  An absent ThresholdType reads as PERCENTAGE and says so.
rows200 = wf.resolve_thresholds(notes(), 200.0)
check([r["amount"] for r in rows200] == [100.0, 160.0, 200.0],
      "threshold 50 on a $200 limit is $100, not $50",
      "got %r" % [r["amount"] for r in rows200])
check(all(r["assumed_kind"] and r["kind"] == "PERCENTAGE" for r in rows200),
      "absent ThresholdType is read as PERCENTAGE and flagged as assumed")
abs_rows = wf.resolve_thresholds(
    [{"NotificationType": "ACTUAL", "Threshold": 50.0,
      "ThresholdType": "ABSOLUTE_VALUE"}], 200.0)
check(abs_rows[0]["amount"] == 50.0 and not abs_rows[0]["assumed_kind"],
      "an explicit ABSOLUTE_VALUE threshold is taken at face value",
      "got %r" % abs_rows[0])

# ---- 4. FORECASTED notifications must not be mistaken for spend.  AWS's own
#         September forecast is $119.286; if a forecast alert counted, every
#         threshold would read as crossed and the fence would vanish.
mixed = notes() + [{"NotificationType": "FORECASTED", "Threshold": 50.0,
                    "NotificationState": "ALARM"}]
check(len(wf.resolve_thresholds(mixed, 100.0)) == 3,
      "FORECASTED notifications are dropped from the fence derivation",
      "got %d rows" % len(wf.resolve_thresholds(mixed, 100.0)))

# ---- 5. Ruling 3: disagreement with AWS's own NotificationState => exit 2,
#         in BOTH directions.  Neither is allowed to read as a pass.
rc, out = wf.check(17.773, 100.0, "MONTHLY", notes(("ALARM", "OK", "OK")))
check(rc == 2, "we say $50 not crossed but AWS says ALARM => exit 2",
      "got rc=%d" % rc)
check(any("DISAGREEMENT" in l for l in out), "the disagreement is printed")
rc, out = wf.check(57.60, 100.0, "MONTHLY", notes(("OK", "OK", "OK")))
check(rc == 2, "we say $50 crossed but AWS says OK => exit 2 as well",
      "got rc=%d" % rc)
rc, _ = wf.check(17.773, 100.0, "MONTHLY", notes(("OK", "OK", "OK")),
                 planned=1.10)
check(rc == 0, "agreement on all three states => the gate can pass",
      "got rc=%d" % rc)

# ---- 6. A non-monthly budget invalidates the reset premise => exit 2, not 0.
rc, out = wf.check(17.773, 100.0, "ANNUALLY", notes())
check(rc == 2, "TimeUnit != MONTHLY => UNCERTIFIABLE", "got rc=%d" % rc)
check(any("not MONTHLY" in l for l in out), "the reason names the premise")

# ---- 7. The gate's actual verdicts, including the pending term.
rc, _ = wf.check(17.773, 100.0, "MONTHLY", notes(), planned=1.10, pending=1.76)
check(rc == 0, "2026-09-05 reading + W46/W47 + $1.10 planned clears $50",
      "got rc=%d" % rc)
rc, out = wf.check(49.50, 100.0, "MONTHLY", notes(), planned=1.10)
check(rc == 3, "a wave that would cross $50 is THROTTLED", "got rc=%d" % rc)
check(any("$50.00" in l and "alert email" in l for l in out),
      "the refusal names the owner-visible email it is protecting")
# ...and the SAME wave was legal under the cached $80.  This is the $30 of
# headroom the defect handed out.
rows = wf.resolve_thresholds(notes(), 100.0)
check(wf.pick_fence(rows, 49.50)["amount"] == 50.0
      and 49.50 + 1.10 <= 80.0,
      "the throttled wave would have passed against the cached $80 fence")

# ---- 8. The brake is the owner's, applied but never derived or relaxed.
rc, out = wf.check(89.50, 100.0, "MONTHLY", notes(("ALARM", "ALARM", "OK")),
                   planned=1.10)
check(rc == 3, "past the $90 brake => THROTTLED", "got rc=%d" % rc)
check(any("BRAKE" in l for l in out) and any("owner" in l for l in out),
      "the brake refusal is routed to the owner, not to a wait")
rc, out = wf.check(100.50, 100.0, "MONTHLY",
                   notes(("ALARM", "ALARM", "ALARM")), planned=1.10)
check(rc == 3, "above every threshold => no fence, exit 3", "got rc=%d" % rc)
check(any("NO FENCE" in l for l in out) and
      any("Do not pick a higher number" in l for l in out),
      "with no threshold left the tool refuses instead of inventing one")

# ---- 9. A budget with no ACTUAL notifications has nothing to derive from.
rc, out = wf.check(17.773, 100.0, "MONTHLY",
                   [{"NotificationType": "FORECASTED", "Threshold": 50.0}])
check(rc == 2, "no ACTUAL notifications => UNCERTIFIABLE, not a free pass",
      "got rc=%d" % rc)

# ---- 10. No exit-0 path may print a number a reader could cache as next
#          month's fence without being told not to.
rc, out = wf.check(17.773, 100.0, "MONTHLY", notes(), planned=1.10)
check(rc == 0 and any("re-run the tool" in l for l in out),
      "the CLEAR line tells the reader not to copy the fence forward")

for line in failures:
    print(line)
print("%d checks, %d failed" % (checks, len(failures)))
sys.exit(1 if failures else 0)
