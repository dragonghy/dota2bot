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

# ---- 11. Ruling 4 (director 2026-09-06, from the desk's 09:12Z hand-off).
#          `pending` defaulted to 0.0, which READS like a measurement and IS an
#          unexamined default.  The load-bearing assertion is that the SAME
#          call -- no --pending, no edit -- answers differently depending on
#          whether anything is actually running.  That is the whole defect:
#          on 09-06 the gate printed CLEAR with a c7a.16xlarge burning all day.
BUSY = [{"id": "i-0114b249d00ad956e", "type": "c7a.16xlarge",
         "state": "running", "launched": "2026-09-06T00:11:00+00:00",
         "project": "final-table-trainer"}]

rc, out, pend = wf.certify_pending([], None)
check(rc == 0 and pend == 0.0, "nothing running + no --pending => zero stands",
      "got rc=%d pend=%r" % (rc, pend))
check(any("CERTIFIED" in l and "reading, not a default" in l for l in out),
      "and the zero is labelled a reading, not a default")

rc, out, pend = wf.certify_pending(BUSY, None)
check(rc == 2 and pend is None,
      "the 09-06 situation: something running + no --pending => exit 2",
      "got rc=%d pend=%r" % (rc, pend))
check(any("pending=$0.000 is FALSE" in l for l in out),
      "the refusal names the false premise, not a generic error")
check(any("i-0114b249d00ad956e" in l and "final-table-trainer" in l
          for l in out),
      "and it prints WHAT is running, so the operator can price it")

# The desk over-rode its own green tool by hand and was right.  With Ruling 4
# the same facts come out of the tool, so nobody has to be right by hand.
check(wf.check(39.328, 100.0, "MONTHLY", notes(), planned=1.10)[0] == 0
      and wf.certify_pending(BUSY, None)[0] == 2,
      "the fence arithmetic alone still says CLEAR -- Ruling 4 is what stops it")

# An asserted figure is allowed (the tool prices nothing), but it is marked as
# an assertion and carries the list it has to cover.
rc, out, pend = wf.certify_pending(BUSY, 4.50)
check(rc == 0 and pend == 4.50, "--pending is honoured over running instances",
      "got rc=%d pend=%r" % (rc, pend))
check(any("ASSERTED" in l for l in out),
      "...but printed as ASSERTED, never as a reading")

# --pending 0.0 is a claim the operator is allowed to make; the silent default
# is what was removed.  These two must NOT collapse to the same code path.
rc0, _, pend0 = wf.certify_pending(BUSY, 0.0)
rcN, _, pendN = wf.certify_pending(BUSY, None)
check(rc0 == 0 and pend0 == 0.0 and rcN == 2,
      "an explicit --pending 0 differs from omitting it", "got %d/%d" % (rc0, rcN))

# The escape hatch must call itself a skip, in the GH #213 vocabulary.
rc, out, pend = wf.certify_pending(BUSY, None, check_enabled=False)
check(rc == 0 and pend == 0.0, "--no-accrual-check does not block",
      "got rc=%d pend=%r" % (rc, pend))
check(any("SKIPPED, NOT CERTIFIED" in l for l in out),
      "and it says SKIPPED, not certified -- a line to quote in the report")

# A failed enumeration is could-not-run, not an empty account.
rc, out, pend = wf.certify_pending(None, None)
check(rc == 2 and any("could not enumerate" in l for l in out),
      "an unreadable account is UNCERTIFIABLE, not 'nothing is running'",
      "got rc=%d" % rc)

# The cost-filter line exists so the day the budget stops being account-wide is
# visible; today it is unfiltered and that is why other projects count.
_, out, _ = wf.certify_pending([], None, cost_filters={})
check(any("budget filters   : none" in l for l in out),
      "an unfiltered budget says so on its own line")
_, out, _ = wf.certify_pending([], None, cost_filters={"TagKeyValue": ["x"]})
check(any("OVER-count" in l for l in out),
      "a filtered budget warns that the account-wide read over-counts")

# ---- 12. parse_instances: only accruing states, and no tag filter.  A
#          `Project`-scoped read is the bug, not the feature: the budget has no
#          cost filter, so somebody else's instance spends our headroom.
payload = {"Reservations": [{"Instances": [
    {"InstanceId": "i-aaa", "InstanceType": "c5.large",
     "State": {"Name": "running"}, "LaunchTime": "2026-09-06T02:00:00+00:00",
     "Tags": [{"Key": "Project", "Value": "final-table-trainer"}]},
    {"InstanceId": "i-bbb", "InstanceType": "c5.large",
     "State": {"Name": "terminated"}, "LaunchTime": "2026-09-05T02:00:00+00:00"},
    {"InstanceId": "i-ccc", "InstanceType": "c5.large",
     "State": {"Name": "shutting-down"},
     "LaunchTime": "2026-09-06T01:00:00+00:00"},
]}]}
rows = wf.parse_instances(payload)
check([r["id"] for r in rows] == ["i-ccc", "i-aaa"],
      "terminated is dropped, shutting-down is kept, sorted by launch time",
      "got %r" % [r["id"] for r in rows])
check(rows[1]["project"] == "final-table-trainer" and rows[0]["project"] is None,
      "the Project tag is read for the report, never used to filter")
check(wf.parse_instances({}) == [],
      "an empty payload is an empty list, not a crash")

# ---- 13. RULING 5: a zero is only "account-wide" when the scope says so.
#          Director, 2026-09-09.  The defect these assertions have teeth
#          against is NOT a wrong number -- `certify_pending` returned the same
#          $0.000 before and after.  It is that the WORD on the line was
#          `account-wide` while `ec2 describe-instances` is regional and
#          `~/.aws/config` pins one region, so a foreign instance in another
#          region was certified absent.  Hence every assertion below is about
#          the sentence, and 13c is the one that fails if the old wording is
#          put back.
COMPLETE = {"regions": ["us-east-1", "us-west-2"], "complete": True}
LIMITED = {"regions": ["us-west-2"], "complete": False,
           "why": "describe-regions unavailable: AccessDenied"}

code, lines, pending = wf.certify_pending([], None, scope=COMPLETE)
text = "\n".join(lines)
check((code, pending) == (0, 0.0), "complete scope + no instances => certified zero")
check("account-wide" in text and "WITHIN SCOPE" not in text,
      "a complete-scope zero may still be called account-wide")
check("2 region(s) read" in text and "COMPLETE" in text,
      "the scope line names how many regions were actually read")

code, lines, pending = wf.certify_pending([], None, scope=LIMITED)
text = "\n".join(lines)
check((code, pending) == (0, 0.0),
      "13c-guard: scope-limited zero still returns 0 -- degrade the CLAIM, "
      "not the gate (a launch outage would be a policy change)")
check("CERTIFIED WITHIN SCOPE ONLY" in text,
      "13c: a scope-limited zero is NOT certified account-wide", text)
check("account-wide zero" in text and "NOT an" in text,
      "13c: the line says in words that this is not an account-wide zero")
check("SCOPE-LIMITED" in text and "AccessDenied" in text,
      "the scope line carries WHY the enumeration was incomplete")

# The `--pending` variant of the same branch: the label still has to degrade.
code, lines, pending = wf.certify_pending([], 1.76, scope=LIMITED)
check((code, pending) == (0, 1.76), "--pending is still taken as the larger claim")
check("ZERO WITHIN SCOPE" in "\n".join(lines),
      "the asserted-pending branch degrades its label too")
code, lines, _ = wf.certify_pending([], 1.76, scope=COMPLETE)
check("CERTIFIED ZERO (" in "\n".join(lines),
      "...and does not degrade it when the scope is complete")

# scope=None is the offline / --no-accrual-check path: no scope line at all,
# and nothing may claim account-wide from it either.
line, complete = wf.scope_line(None)
check(line is None and complete is False,
      "no live enumeration => no scope line, and `complete` is False")
code, lines, pending = wf.certify_pending(
    [], None, check_enabled=False, skip_reason="offline mode")
check(code == 0 and "SKIPPED, NOT CERTIFIED" in "\n".join(lines),
      "offline still prints the SKIPPED line, unchanged by Ruling 5")

# An accruing instance prints its region, so "which region is burning" is
# readable off the gate output instead of reconstructed afterwards.
rows = [{"id": "i-aaa", "type": "c7a.16xlarge", "state": "running",
         "launched": "2026-09-06T02:00:00+00:00",
         "project": "final-table-trainer", "region": "us-east-1"}]
code, lines, pending = wf.certify_pending(rows, None, scope=COMPLETE)
check(code == 2 and pending is None,
      "instances accruing + no --pending is still UNCERTIFIABLE (Ruling 4)")
check("us-east-1" in "\n".join(lines),
      "the accruing line names the region the instance is in")
rows_noregion = [dict(rows[0])]
del rows_noregion[0]["region"]
check("(region unread)" in "\n".join(wf.certify_pending(
          rows_noregion, 1.0, scope=LIMITED)[1]),
      "a row with no region says so rather than printing a blank")

# ---- 14. RULING 5, the enumeration itself.  `read_accruing_instances` is the
#          function that DECIDES `complete`, so leaving it untested would leave
#          the whole ruling resting on a flag nothing checks.  The AWS boundary
#          is one function (`_awsx`), so the honest offline test is to stub
#          that and assert on the calls made and the scope returned.
def stub_awsx(regions=("us-east-1", "us-west-2"), instances=None,
              regions_fail=False, fail_regions=()):
    """Return (fake_awsx, calls).  `instances` maps region -> payload rows."""
    calls = []

    def fake(args):
        calls.append(list(args))
        if args[1] == "describe-regions":
            if regions_fail:
                raise wf.Uncertifiable("AccessDenied for DescribeRegions")
            return {"Regions": [{"RegionName": r} for r in regions]}
        region = args[args.index("--region") + 1] if "--region" in args else None
        if region in fail_regions:
            raise wf.Uncertifiable("timed out")
        rows = (instances or {}).get(region, [])
        return {"Reservations": [{"Instances": rows}]}

    return fake, calls


def inst(iid, region_hint=""):
    return {"InstanceId": iid, "InstanceType": "c7a.16xlarge",
            "State": {"Name": "running"},
            "LaunchTime": "2026-09-06T02:00:00+00:00",
            "Tags": [{"Key": "Project", "Value": "final-table-trainer"}]}


saved_awsx = wf._awsx
try:
    # 14a. Happy path: every enabled region is read, rows carry their region.
    fake, calls = stub_awsx(instances={"us-east-1": [inst("i-east")]})
    wf._awsx = fake
    rows, scope = wf.read_accruing_instances()
    check(scope["complete"] is True, "all regions readable => scope complete")
    check(scope["regions"] == ["us-east-1", "us-west-2"],
          "the scope names the regions read", "got %r" % scope["regions"])
    check([r["region"] for r in rows] == ["us-east-1"],
          "the row is stamped with the region it was found in")
    check(sum(1 for c in calls if c[1] == "describe-instances") == 2,
          "one describe-instances per region, not one for the account")
    check(all("--region" in c for c in calls if c[1] == "describe-instances"),
          "each per-region call passes --region explicitly")

    # 14b. THE ONE THAT MATTERS: no DescribeRegions permission.  The gate must
    #      still run (fall back to the configured region) and must NOT call the
    #      result complete -- that flag is the entire difference between an
    #      honest zero and the defect this ruling fixes.
    fake, calls = stub_awsx(regions_fail=True)
    wf._awsx = fake
    rows, scope = wf.read_accruing_instances()
    check(rows == [], "fallback still returns a reading")
    check(scope["complete"] is False,
          "14b: describe-regions denied => the scope is NOT complete")
    check("describe-regions unavailable" in scope.get("why", ""),
          "the fallback says why it is incomplete")
    check(sum(1 for c in calls if c[1] == "describe-instances") == 1
          and not any("--region" in c for c in calls
                      if c[1] == "describe-instances"),
          "the fallback reads exactly the configured default region")

    # 14c. A partial failure is incomplete too -- and names the region, so the
    #      next round knows which one to re-read rather than re-deriving it.
    fake, calls = stub_awsx(regions=("us-east-1", "eu-west-1", "us-west-2"),
                            fail_regions=("eu-west-1",),
                            instances={"us-west-2": [inst("i-west")]})
    wf._awsx = fake
    rows, scope = wf.read_accruing_instances()
    check(scope["complete"] is False, "one unreadable region => not complete")
    check(scope["regions"] == ["us-east-1", "us-west-2"],
          "only the regions actually read are listed")
    check("eu-west-1" in scope.get("why", ""),
          "the unreadable region is named", "got %r" % scope.get("why"))
    check([r["id"] for r in rows] == ["i-west"],
          "rows from the readable regions are still returned")

    # 14d. End to end through certify_pending: a denied DescribeRegions plus an
    #      empty region must never print the word this ruling exists to remove.
    fake, _ = stub_awsx(regions_fail=True)
    wf._awsx = fake
    rows, scope = wf.read_accruing_instances()
    text = "\n".join(wf.certify_pending(rows, None, scope=scope)[1])
    check("CERTIFIED WITHIN SCOPE ONLY" in text
          and "account-wide, read this run" not in text,
          "14d: the fallback's zero reaches the report as scope-limited")
finally:
    wf._awsx = saved_awsx


# ---- 15. RULING 6: the certified zero has a clock, and it was the wrong one -
# Director, 2026-09-10.  The defect is measured, not hypothetical: on
# 2026-09-10T00:14Z the live gate printed `CERTIFIED (0 accruing instances
# account-wide)` and `headroom $5.692` three hours after W62 self-terminated,
# while the desk's hand arithmetic said $2.442.  The load-bearing assertion is
# 15a: nothing running + a recent wave must NOT certify a zero.
import datetime as _dt                                       # noqa: E402
import json as _json                                         # noqa: E402
import shutil as _shutil                                     # noqa: E402
import tempfile as _tempfile                                 # noqa: E402

_SNAP = "2026-09-09T20:23:37Z"
_NOW = _dt.datetime(2026, 9, 10, 0, 19, 23, tzinfo=_dt.timezone.utc)


def waves_dir_with(records):
    """records: {"W62": ["2026-09-09T21:24:41Z", ...] or None}"""
    path = _tempfile.mkdtemp(prefix="wf_waves_")
    for wave_id, stamps in records.items():
        machines = [{"seed": i, "launched_at": s}
                    for i, s in enumerate(stamps or [None])]
        with open(os.path.join(path, "%s_wave.json" % wave_id), "w") as fh:
            _json.dump({"wave": wave_id, "machines": machines}, fh)
    return path


tmpdirs = []
try:
    # 15a. THE LOAD-BEARING ONE.  W62 went up 61 minutes AFTER the budget
    #      snapshot and self-terminated before this run: invisible to
    #      describe-instances AND to MTD at the same time.
    d = waves_dir_with({"W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    code, lines, pending = wf.certify_pending([], None, waves=w)
    text = "\n".join(lines)
    check(code == 2, "15a: nothing running + a recent wave does NOT certify $0",
          "got exit %r" % code)
    check(pending is None, "15a2: no pending value is handed back on exit 2",
          "got %r" % (pending,))
    check("CERTIFIED" not in text.replace("NOT certifiable", ""),
          "15a3: the word CERTIFIED does not reach the report", text[:200])

    # 15b. The other half of the same defect: the desk's window is anchored to
    #      NOW while MTD is anchored to the snapshot.  W60 (09-09T09:23Z) is
    #      14.9h before now -- outside a 12h now-window -- but only 11.0h
    #      before the snapshot, i.e. still inside the 4.3-11.3h lag band.
    d = waves_dir_with({"W60": ["2026-09-09T09:23:33Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    check([r[0] for r in w["rows"]] == ["W60"],
          "15b: the snapshot clock catches the wave a now-clock drops",
          "rows %r cutoff %s" % (w["rows"], w["cutoff"]))
    w_now = wf.read_wave_accrual(d, None, now=_NOW)
    check(w_now["rows"] == [],
          "15b2: and the now-clock demonstrably drops it (that IS the defect)")
    check(w_now["clock_source"].startswith("now"),
          "15b3: the permissive fallback names itself",
          "got %r" % w_now["clock_source"])

    # 15c. A wave older than the lag band does not block anything.  Without
    #      this the fix would be a permanent launch outage, not a gate.
    d = waves_dir_with({"W40": ["2026-09-02T21:31:51Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    code, lines, pending = wf.certify_pending([], None, waves=w)
    check(code == 0 and pending == 0.0,
          "15c: an old wave still certifies $0", "got %r/%r" % (code, pending))

    # 15d. --pending is the documented way through, exactly as in Ruling 4.
    d = waves_dir_with({"W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    code, lines, pending = wf.certify_pending([], 3.25, waves=w)
    check(code == 0 and pending == 3.25,
          "15d: the operator's own figure is accepted", "got %r" % (pending,))

    # 15d2. GH #683 itself: the desk's $3.250 covered W62 and W61 and dropped
    #       W60.  A supplied figure must be told what it has to cover, or the
    #       omission is only ever found by hand, three hours later.
    d = waves_dir_with({"W60": ["2026-09-09T09:23:33Z"],
                        "W61": ["2026-09-09T15:24:29Z"],
                        "W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    text = "\n".join(wf.certify_pending([], 3.25, waves=w)[1])
    check("must cover" in text and "3 wave(s)" in text and "W60" in text,
          "15d2: a supplied pending is told which waves it must cover",
          text[-300:])

    # 15e. The tool must not price the waves.  A markup constant here is the
    #      free parameter this whole file exists to remove.
    d = waves_dir_with({"W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    text = "\n".join(wf.certify_pending([], None, waves=w)[1])
    check("does not price waves" in text,
          "15e: the refusal says it does not price waves")
    check("$1.10" not in text and "$2.15" not in text,
          "15e2: no wave price is invented in the output")

    # 15f. Ruling 3 bounding: W37-W39 predate GH #544 and carry no
    #      launched_at.  A higher-numbered datable sibling before the cutoff
    #      dates them old -- otherwise every future run carries a caveat
    #      nobody reads.
    d = waves_dir_with({"W39": None, "W40": ["2026-09-02T21:31:51Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    check(w["why_unread"] is None,
          "15f: an undatable record bounded old by ruling 3 is not 'unread'",
          "got %r" % (w["why_unread"],))

    # 15g. ...and the bound is not a licence: when the datable sibling is
    #      itself inside the window, the undatable record stays unread.
    d = waves_dir_with({"W61": None, "W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    check(w["why_unread"] is not None and "W61" in w["why_unread"],
          "15g: an undatable record inside the window stays unread",
          "got %r" % (w["why_unread"],))

    # 15h. --no-accrual-check still skips the whole thing, and still says so.
    d = waves_dir_with({"W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    code, lines, pending = wf.certify_pending(
        [], None, check_enabled=False, waves=w)
    check(code == 0 and pending == 0.0
          and "SKIPPED, NOT CERTIFIED" in "\n".join(lines),
          "15h: the documented bypass still prints SKIPPED, not a pass")

    # 15i. Ruling 5's caveat must not be reworded in clock language, nor the
    #      other way round: the two qualifications stay distinguishable.
    #      Ruling 7 moved this case off the `now` fallback (which no longer
    #      reaches a verdict at all) and onto the operator-asserted clock --
    #      the surviving exit-0 path that still carries a clock caveat.
    d = waves_dir_with({"W40": ["2026-09-02T21:31:51Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, None, now=_NOW, asserted_instant=_SNAP)
    text = "\n".join(wf.certify_pending(
        [], None, scope={"regions": ["us-west-2", "us-east-1"],
                         "complete": True}, waves=w)[1])
    check("account-wide, read this run" in text,
          "15i: a complete region scope still reads account-wide")
    check("zero qualified" in text and "region filter" not in text,
          "15i2: the clock caveat is worded as a clock, not as a region",
          text[-300:])

    # 15j. parse_snapshot_instant takes what botocore actually hands back.
    check(wf.parse_snapshot_instant("2026-09-09T20:23:37Z")
          == _dt.datetime(2026, 9, 9, 20, 23, 37, tzinfo=_dt.timezone.utc),
          "15j: a Z-suffixed string parses")
    check(wf.parse_snapshot_instant(
        _dt.datetime(2026, 9, 9, 20, 23, 37, tzinfo=_dt.timezone.utc))
        == _dt.datetime(2026, 9, 9, 20, 23, 37, tzinfo=_dt.timezone.utc),
        "15j2: a datetime passes through")
    check(wf.parse_snapshot_instant("not a time") is None
          and wf.parse_snapshot_instant(None) is None,
          "15j3: an unreadable stamp returns None, which routes to the label")

    # ---- 16. RULING 7 (director 2026-09-10, GH #692 defect / #693 policy).
    # Two halves.  (a) the parser did not know the shape the CLI actually
    # returns, so Ruling 6's "rare labelled degrade" fired on 100% of live
    # runs; (b) after GH #683 ss4 the exit code IS the launch authorisation,
    # so a degrade that only touches the wording authorises a wave over the
    # fence.  16a and 16d are the load-bearing pair: 16a is the shape that was
    # dropped, 16d is the exit 0 that dropping it produced.

    # 16a. THE MEASURED SHAPE.  This float is verbatim from the batch desk's
    #      2026-09-10T03:1xZ round: `awsx budgets describe-budget --output
    #      json` on aws-cli/1.46.1.  It is the same instant check_costs.sh
    #      printed as 2026-09-09T20:23:37Z while this parser called it
    #      unreadable.
    check(wf.parse_snapshot_instant(1788985417.716)
          == _dt.datetime(2026, 9, 9, 20, 23, 37, 716000,
                          tzinfo=_dt.timezone.utc),
          "16a: the CLI's float epoch parses to the instant check_costs prints",
          "got %r" % (wf.parse_snapshot_instant(1788985417.716),))
    check(wf.parse_snapshot_instant(1788985417)
          == _dt.datetime(2026, 9, 9, 20, 23, 37, tzinfo=_dt.timezone.utc),
          "16a2: an int epoch parses too")

    # 16b. isinstance(True, int) is True.  A boolean dated 1970-01-01 would be
    #      a WRONG reading, which is worse than an unreadable one: it would
    #      certify a window nobody chose.
    check(wf.parse_snapshot_instant(True) is None
          and wf.parse_snapshot_instant(False) is None,
          "16b: a bool is not an epoch",
          "got %r/%r" % (wf.parse_snapshot_instant(True),
                         wf.parse_snapshot_instant(False)))
    check(wf.parse_snapshot_instant(float("nan")) is None
          and wf.parse_snapshot_instant(1e30) is None,
          "16b2: a non-finite or absurd epoch returns None, it does not raise")

    # 16c. The degrade now reaches the exit code, on the branch that used to
    #      print CERTIFIED.  Nothing running, no wave in the (narrow) window:
    #      under Ruling 6 this was an exit 0 with a caveat line.
    d = waves_dir_with({"W40": ["2026-09-02T21:31:51Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, None, now=_NOW)          # no snapshot at all
    check(w["clock_degraded"] is True,
          "16c: a missing LastUpdatedTime marks the clock degraded")
    code, lines, pending = wf.certify_pending([], None, waves=w)
    text = "\n".join(lines)
    check(code == 2 and pending is None,
          "16c2: a degraded clock does not certify a zero (Ruling 7)",
          "got %r/%r" % (code, pending))
    check("CERTIFIED" not in text,
          "16c3: and the word CERTIFIED does not reach the report", text[:300])
    check("--snapshot-instant" in text and "--no-accrual-check" in text,
          "16c4: the refusal names both ways through, so it is not an outage",
          text[-300:])

    # 16d. THE OTHER LOAD-BEARING ONE -- GH #692's measured hole.  The desk
    #      passed a --pending covering every wave the tool NAMED and got exit
    #      0 on a launch that crossed the fence, because the naming itself
    #      was short by two waves.  A supplied figure must NOT buy past a
    #      degraded clock: the clock is what decided which waves to name.
    d = waves_dir_with({"W60": ["2026-09-09T09:23:33Z"],
                        "W61": ["2026-09-09T15:24:29Z"],
                        "W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w_bad = wf.read_wave_accrual(d, None, now=_NOW)
    # At this `now` the narrower window drops W60 only; on the desk's own
    # round (a later `now`) it dropped W60 and W61.  The count is incidental,
    # the direction is not: the degraded list is a SUBSET, always.
    check(sorted(r[0] for r in w_bad["rows"]) == ["W61", "W62"],
          "16d: the degraded clock drops a wave the snapshot clock keeps",
          "rows %r" % (w_bad["rows"],))
    code, lines, pending = wf.certify_pending([], 3.250, waves=w_bad)
    check(code == 2 and pending is None,
          "16d2: --pending does not buy past a degraded clock (Ruling 7)",
          "got %r/%r" % (code, pending))
    # ...and with the epoch parsed, the same corpus names all three.
    w_ok = wf.read_wave_accrual(d, 1788985417.716, now=_NOW)
    check(w_ok["clock_degraded"] is False
          and sorted(r[0] for r in w_ok["rows"]) == ["W60", "W61", "W62"],
          "16d3: the epoch fix restores the three waves the desk found by hand",
          "rows %r source %r" % (w_ok["rows"], w_ok["clock_source"]))

    # 16e. --snapshot-instant: the gate still runs, and still says the clock
    #      was asserted rather than read.  Without this the fix would be a
    #      launch outage whenever AWS changes a serialisation again.
    w_as = wf.read_wave_accrual(d, None, now=_NOW, asserted_instant=_SNAP)
    check(w_as["clock_degraded"] is False
          and "ASSERTED" in w_as["clock_source"],
          "16e: an asserted clock is a clock, and is labelled a claim",
          "got %r" % (w_as["clock_source"],))
    check(sorted(r[0] for r in w_as["rows"]) == ["W60", "W61", "W62"],
          "16e2: and it cuts the same window the budget snapshot would")
    code, lines, pending = wf.certify_pending([], 5.400, waves=w_as)
    check(code == 0 and pending == 5.400,
          "16e3: the operator gets through on their own clock + own figure",
          "got %r/%r" % (code, pending))
    check("ASSERTED" in "\n".join(lines),
          "16e4: the claim travels into the lines, not just the dict")

    # 16f. THE NARROWING, PINNED.  Ruling 7 covers the clock, NOT unread
    #      records: an unread record is permissive too, but widening it here
    #      would be a policy change smuggled in under a bug fix.  If a later
    #      round decides to widen, it should have to edit this assertion.
    d = waves_dir_with({"W61": None, "W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, _SNAP, now=_NOW)
    check(w["why_unread"] is not None and w["clock_degraded"] is False,
          "16f: unread records with a good clock are not a degraded clock")
    code, lines, pending = wf.certify_pending([], 5.400, waves=w)
    check(code == 0 and "zero qualified" in "\n".join(lines),
          "16f2: that case stays a caveat on an exit 0 (deliberately unwidened)",
          "got %r" % (code,))

    # 16g. --no-accrual-check outranks Ruling 7, as it does every other
    #      ruling in this file: it returns before any of them, and says so.
    d = waves_dir_with({"W62": ["2026-09-09T21:24:41Z"]})
    tmpdirs.append(d)
    w = wf.read_wave_accrual(d, None, now=_NOW)
    code, lines, pending = wf.certify_pending(
        [], None, check_enabled=False, waves=w)
    check(code == 0 and "SKIPPED, NOT CERTIFIED" in "\n".join(lines),
          "16g: the written skip still works under a degraded clock")

    # 16h. An unparseable assertion is refused, not ignored.  Falling back
    #      silently would answer a question the operator did not ask, in the
    #      permissive direction -- the exact shape of everything above.
    _offline = ["--actual", "75.023", "--limit", "100",
                "--thresholds", "50,80,100", "--planned", "1.10"]
    check(wf.main(_offline + ["--snapshot-instant", "yesterday-ish"]) == 2,
          "16h: an unreadable --snapshot-instant is refused, not ignored")
    check(wf.parse_snapshot_instant("yesterday-ish") is None,
          "16h2: ...and the value really is unreadable, so 16h is not vacuous")
    check(wf.main(_offline + ["--snapshot-instant", _SNAP]) == 0,
          "16h3: a readable one does not refuse (16h is not just 'flag => 2')")
finally:
    for d in tmpdirs:
        _shutil.rmtree(d, ignore_errors=True)

# ---- 17. RULING 10 (director 2026-09-10, GH #721): the tool named an
#          authority and gave it no way to speak.  The refusal line has always
#          said "Crossing needs the director's explicit ruling that round" --
#          and there was no flag, no file, no field.  So the ONLY way to act on
#          such a ruling was to not run the gate: an unbounded, unlogged bypass
#          reached through absence.  These checks are about the four things
#          that keep the new field from being the bypass switch GM.2(a)
#          forbade.

_FUTURE = "2099-01-01T00:00:00Z"
_PAST = "2000-01-01T00:00:00Z"
_REF = "GH#721/director-20260910"

# 17a. The blocking round itself, reproduced from the desk's 18:14Z reading.
#      $0.047 short, with 20 days of September left.
rc, out = wf.check(77.847, 100.0, "MONTHLY", notes(("ALARM", "OK", "OK")),
                   planned=1.10, pending=1.10)
check(rc == 3, "17a: the 2026-09-10 reading is THROTTLED", "got rc=%d" % rc)
check(any("Headroom was $1.053" in l and "needs $1.100" in l for l in out),
      "17a2: ...by $0.047, the desk's number to the mill")
check(any("--director-crossing" in l for l in out),
      "17a3: ...and the refusal now says HOW a ruling reaches this tool, "
      "instead of naming an authority with no channel")

# 17b. The same wave, with the ruling supplied, clears -- and says so.
_cross, _err = wf.build_crossing(85.0, _REF, _FUTURE)
check(_err is None and _cross is not None,
      "17b: a well-formed ruling validates", "err=%r" % _err)
rc, out = wf.check(77.847, 100.0, "MONTHLY", notes(("ALARM", "OK", "OK")),
                   planned=1.10, pending=1.10, crossing=_cross)
check(rc == 0, "17b2: ...and the blocked wave clears under it", "got rc=%d" % rc)
check(any("ONLY BECAUSE OF RULING" in l and _REF in l for l in out),
      "17b3: ...and the exit-0 line says the ruling is why, and names it")
check(any("RULING, not a reading" in l for l in out),
      "17b4: ...and marks the ceiling as a ruling rather than a reading")

# ---- 17c. THE LOAD-BEARING ONE.  A crossing ruling is a CEILING, not an
#           unlock.  At MTD $84.50 the derived fence is already $100 (the $80
#           alert is crossed), so min(fence, brake) = $90 and this wave would
#           pass WITHOUT any ruling.  Carrying the $85 ruling makes it FAIL.
#           That is the whole difference between a bounded ruling and a bypass
#           switch: this flag can only be spent down to the number the ruling
#           named, and it can tighten.
rc, out = wf.check(84.50, 100.0, "MONTHLY", notes(("ALARM", "ALARM", "OK")),
                   planned=1.10)
check(rc == 0, "17c: without the ruling, MTD $84.50 clears (fence is $100 now)",
      "got rc=%d" % rc)
rc, out = wf.check(84.50, 100.0, "MONTHLY", notes(("ALARM", "ALARM", "OK")),
                   planned=1.10, crossing=_cross)
check(rc == 3, "17c2: ...and WITH the $85 ruling the same wave is REFUSED",
      "got rc=%d" % rc)
check(any("the ceiling the director's own ruling" in l and _REF in l
          for l in out),
      "17c3: ...and the refusal says the ruling is being obeyed, not overridden")

# 17d. It cannot reach the brake, and a ruling that tries is REFUSED rather
#      than silently clamped -- a clamp lets a wrong ruling read as an obeyed
#      one.
_c, _err = wf.build_crossing(95.0, _REF, _FUTURE)
check(_c is None and _err and "brake" in _err,
      "17d: a ruling above the $90 brake is refused, not clamped", "err=%r" % _err)
_c, _err = wf.build_crossing(105.0, _REF, _FUTURE, brake=120.0)
check(_c is None and _err and "approval line" in _err,
      "17d2: ...and a raised --brake does not open the owner's $100 line either",
      "err=%r" % _err)

# 17e. It must expire, and the expiry is checked rather than written down.
_c, _err = wf.build_crossing(85.0, _REF, None)
check(_c is None and _err and "expire" in _err,
      "17e: a ruling with no expiry is refused", "err=%r" % _err)
_c, _err = wf.build_crossing(85.0, _REF, _PAST)
check(_c is None and _err and "expired" in _err,
      "17e2: an expired ruling is refused -- it is no ruling, not a weak one",
      "err=%r" % _err)
_c, _err = wf.build_crossing(85.0, _REF, "sometime in september")
check(_c is None and _err and "not an instant" in _err,
      "17e3: an unreadable expiry is refused, not ignored", "err=%r" % _err)

# 17f. It must name itself, and a half-supplied ruling is a dropped flag.
_c, _err = wf.build_crossing(85.0, "  ", _FUTURE)
check(_c is None and _err and "crossing-ref" in _err,
      "17f: a ruling that cannot be quoted is refused", "err=%r" % _err)
_c, _err = wf.build_crossing(None, _REF, _FUTURE)
check(_c is None and _err and "authorises nothing" in _err,
      "17f2: a ref/expiry with no ceiling is refused, not ignored", "err=%r" % _err)
_c, _err = wf.build_crossing(None, None, None)
check(_c is None and _err is None,
      "17f3: ...and no ruling at all is the ordinary case, not an error")

# 17g. The two places a ruling must NOT reach.  The brake is the owner's line
#      and the no-fence case is past the owner's approval line.
rc, out = wf.check(89.50, 100.0, "MONTHLY", notes(("ALARM", "ALARM", "OK")),
                   planned=1.10, crossing=wf.build_crossing(
                       90.0, _REF, _FUTURE)[0])
check(rc == 3 and any("BRAKE" in l for l in out),
      "17g: a ruling at the brake still cannot carry a wave past the brake",
      "got rc=%d" % rc)
rc, out = wf.check(100.50, 100.0, "MONTHLY", notes(("ALARM", "ALARM", "ALARM")),
                   planned=1.10, crossing=_cross)
check(rc == 3 and any("NOT applied" in l for l in out),
      "17g2: past every alert the ruling is not applied, and says so",
      "got rc=%d" % rc)

# 17h. A ruling carried but not needed must not read as one that was spent.
rc, out = wf.check(17.773, 100.0, "MONTHLY", notes(), planned=1.10,
                   crossing=_cross)
check(rc == 0 and any("carried but NOT needed" in l for l in out),
      "17h: an unneeded ruling does not claim credit for the wave", "got rc=%d" % rc)

# 17i. The wiring: main() really reaches build_crossing, and really reaches
#      check() with the result.  Without this, every check above could pass on
#      a function nothing calls.
_base = ["--actual", "77.847", "--limit", "100", "--thresholds", "50,80,100",
         "--planned", "1.10", "--pending", "1.10"]
check(wf.main(_base) == 3, "17i: main() refuses the blocking round")
check(wf.main(_base + ["--director-crossing", "85",
                       "--crossing-ref", _REF,
                       "--crossing-expiry", _FUTURE]) == 0,
      "17i2: ...and clears it under the ruling")
check(wf.main(_base + ["--director-crossing", "85",
                       "--crossing-ref", _REF,
                       "--crossing-expiry", _PAST]) == 2,
      "17i3: ...and an expired ruling is exit 2 (so 17i2 is not 'flag => 0')")
check(wf.main(_base + ["--director-crossing", "85"]) == 2,
      "17i4: ...and a ruling with no ref never reaches the gate")

for line in failures:
    print(line)
print("%d checks, %d failed" % (checks, len(failures)))
sys.exit(1 if failures else 0)
