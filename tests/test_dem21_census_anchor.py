#!/usr/bin/env python3
"""The dem21 sweep anchor must be COMPUTED from the live rule, not remembered.

WHY THIS EXISTS
    A lifecycle sweep lag is a lag from something, and here that something --
    the objects' creation timestamps -- is destroyed by the very rule being
    measured.  2026-09-16T15:11Z the desk pinned the 08-25 cohort's sweep into
    a ~3h window and registered the band as `[21h, 24h]` without naming the
    anchor.  After the cohort was swept the anchor could no longer be
    recovered from the bucket, so the band could only be copied forward, never
    checked.

    Re-deriving the same observation against the anchor S3 documents -- expiry
    = creation time + `Expiration.Days`, ROUNDED UP to the next UTC midnight --
    gives `[12h, 15h]`, and moves the 08-26 cohort from "overdue since today"
    to "due 2026-09-17T00:00Z".  That round had started a lag clock on a cohort
    that was not due.  The error direction is the quiet one: an overstated lag
    keeps a stalled lifecycle rule looking healthy, and storage is billed for
    every day of the difference.

HOW IT TESTS
    On the real script (`tools/batch_test/aws/dem21_census.py`), over listing
    lines copied VERBATIM out of the 2026-09-16T18:1xZ `s3 ls --recursive`
    read and a lifecycle document copied verbatim out of
    `s3api get-bucket-lifecycle-configuration` on the live bucket -- not lines
    this test invented to match its own expectations.

    `--now` is passed on every case.  A census whose answer moves with the
    wall clock is a test that passes today and fails on a date nobody chose.
"""

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "batch_test", "aws", "dem21_census.py")

checks = 0
failed = 0


def check(label, got, want):
    global checks, failed
    checks += 1
    if got != want:
        failed += 1
        print(f"FAIL {label}\n  got:  {got!r}\n  want: {want!r}")
    else:
        print(f"ok   {label}")


def check_true(label, cond, detail=""):
    global checks, failed
    checks += 1
    if not cond:
        failed += 1
        print(f"FAIL {label}  {detail}")
    else:
        print(f"ok   {label}")


# Copied verbatim from the 2026-09-16T18:1xZ read of
# s3://dota2bot-batch-results-4924/dem21/ (sizes and timestamps unaltered);
# one line per cohort boundary that the finding turns on.
LISTING = """2026-08-26 03:26:04    2097152 dem21/w55_seed901_slot1.dem
2026-08-26 22:08:15   22347776 dem21/w55_seed904_slot3.dem
2026-08-27 00:28:13   21299200 dem21/w56_seed905_slot0.dem
2026-08-27 22:12:41   20971520 dem21/w56_seed908_slot3.dem
2026-09-11 22:21:42   19922944 dem21/w69_seed988_slot2.dem
Total Objects: 5
   Total Size: 86638592
"""

# Copied verbatim from `s3api get-bucket-lifecycle-configuration
# --bucket dota2bot-batch-results-4924` (LC_EXIT=0, 2026-09-16T18:1xZ).
LIFECYCLE = {
    "TransitionDefaultMinimumObjectSize": "all_storage_classes_128K",
    "Rules": [
        {
            "Expiration": {"Days": 21},
            "ID": "dem21-expire-21d",
            "Filter": {"Prefix": "dem21/"},
            "Status": "Enabled",
        },
        {
            "ID": "abort-incomplete-mpu-7d",
            "Filter": {"Prefix": ""},
            "Status": "Enabled",
            "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7},
        },
    ],
}


def run(tmp, listing=LISTING, lifecycle=LIFECYCLE, now="2026-09-16T18:15:00Z", extra=None):
    lp = os.path.join(tmp, "listing.txt")
    with open(lp, "w") as fh:
        fh.write(listing)
    argv = [sys.executable, SCRIPT, "--listing", lp, "--now", now, "--json"]
    if lifecycle is not None:
        cp = os.path.join(tmp, "lc.json")
        with open(cp, "w") as fh:
            json.dump(lifecycle, fh)
        argv += ["--lifecycle", cp]
    argv += extra or []
    p = subprocess.run(argv, capture_output=True, text=True)
    return p


with tempfile.TemporaryDirectory() as tmp:
    # --- case 1: the anchor itself -------------------------------------------
    # The load-bearing case.  Both 08-26 objects were created after 00:00:00Z,
    # so `creation date + 21d` (2026-09-16) and the documented rounded-up
    # expiry (2026-09-17T00:00Z) differ by a full day.  Reading the first as
    # the due instant is exactly what produced the `[21h, 24h]` band.
    p = run(tmp)
    check("case1 exit", p.returncode, 0)
    doc = json.loads(p.stdout)
    by_day = {c["day"]: c for c in doc["cohorts"]}
    check("case1 expire_days read from the live rule", doc["expire_days"], 21)
    check("case1 08-26 due instant", by_day["2026-08-26"]["due"], "2026-09-17T00:00:00Z")
    check("case1 08-26 is NOT overdue at 18:15Z", by_day["2026-08-26"]["status"], "not due")
    check("case1 08-26 hours until due", by_day["2026-08-26"]["hours_until_due"], 5.75)
    check("case1 08-26 last created", by_day["2026-08-26"]["last"], "2026-08-26T22:08:15Z")
    check("case1 08-27 due instant", by_day["2026-08-27"]["due"], "2026-09-18T00:00:00Z")
    # The cohort whose sweep was actually pinned: due 2026-09-16T00:00Z, seen
    # present at 12:13Z and gone at 15:11Z => the band is [12.2h, 15.2h].
    check("case1 cohort count", len(doc["cohorts"]), 3)
    check("case1 summarize trailer is not an unparsed line", doc["unparsed_lines"], 0)
    check("case1 objects", doc["objects"], 5)
    check("case1 bytes", doc["bytes"], 86638592)

    # --- case 2: overdue is reported as overdue, with hours ------------------
    # Same corpus, clock moved past the 08-26 due instant.
    p = run(tmp, now="2026-09-17T13:00:00Z")
    doc = json.loads(p.stdout)
    by_day = {c["day"]: c for c in doc["cohorts"]}
    check("case2 08-26 overdue", by_day["2026-08-26"]["status"], "OVERDUE")
    check("case2 08-26 overdue hours", by_day["2026-08-26"]["overdue_hours"], 13.0)
    check("case2 08-27 still not due", by_day["2026-08-27"]["status"], "not due")

    # --- case 3: it will not assume 21 --------------------------------------
    # The prefix is named `dem21/`; the name is what keeps looking right after
    # the rule changes.  A 14-day rule must move every due instant.
    lc14 = json.loads(json.dumps(LIFECYCLE))
    lc14["Rules"][0]["Expiration"]["Days"] = 14
    p = run(tmp, lifecycle=lc14)
    doc = json.loads(p.stdout)
    by_day = {c["day"]: c for c in doc["cohorts"]}
    check("case3 expire_days follows the rule, not the prefix name", doc["expire_days"], 14)
    check("case3 08-26 due instant moves", by_day["2026-08-26"]["due"], "2026-09-10T00:00:00Z")
    check("case3 08-26 now overdue", by_day["2026-08-26"]["status"], "OVERDUE")

    # --- case 4: a disabled rule is not a rule ------------------------------
    lc_off = json.loads(json.dumps(LIFECYCLE))
    lc_off["Rules"][0]["Status"] = "Disabled"
    p = run(tmp, lifecycle=lc_off)
    check_true("case4 refuses when nothing expires the prefix", p.returncode != 0, p.stdout)
    check_true("case4 says why", "REFUSED" in p.stderr, p.stderr)

    # --- case 5: neither source given ---------------------------------------
    lp = os.path.join(tmp, "listing.txt")
    p = subprocess.run(
        [sys.executable, SCRIPT, "--listing", lp, "--now", "2026-09-16T18:15:00Z"],
        capture_output=True, text=True,
    )
    check_true("case5 refuses with no expiry source at all", p.returncode != 0, p.stdout)

    # --- case 6: an unreadable line is never silently benign ----------------
    # The failure this file exists to avoid is a listing-format change that
    # reads back as an empty/small bucket.  It must be counted AND announced
    # on its own stderr line.
    p = run(tmp, listing=LISTING + "2026/08/26 03:26:04 2097152 dem21/reformatted.dem\n")
    doc = json.loads(p.stdout)
    check("case6 unparsed line counted", doc["unparsed_lines"], 1)
    check_true("case6 WARNING on its own line", "WARNING:" in p.stderr, p.stderr)
    check_true(
        "case6 WARNING says the counts are short, not that the bucket is empty",
        "short by that many" in p.stderr,
        p.stderr,
    )
    check("case6 the parsed rows are unchanged", doc["objects"], 5)

    # --- case 7: exact-midnight creation does not get rounded up an extra day
    # The one input for which `+Days` already IS a midnight.  Rounding it up
    # anyway would overstate every due instant by 24h -- the same direction as
    # the defect above, arrived at from the other side.
    p = run(tmp, listing="2026-08-26 00:00:00 1024 dem21/midnight.dem\n", now="2026-09-16T18:15:00Z")
    doc = json.loads(p.stdout)
    check("case7 midnight creation expires at +Days exactly", doc["cohorts"][0]["due"], "2026-09-16T00:00:00Z")
    check("case7 midnight cohort is overdue at 18:15Z", doc["cohorts"][0]["status"], "OVERDUE")

print(f"\n{checks} checks, {failed} failed")
sys.exit(1 if failed else 0)
