#!/usr/bin/env python3
"""Ratchet for [harness] GH #801: check_costs.sh must not pay above the brake.

WHAT #801 MEASURED (batch desk, 2026-09-13).  The auto-confirmation in
check_costs.sh fires on `MTD >= CONFIRM_AT` ($35) and nothing else, so it kept
buying a $0.01 Cost Explorer read on every trigger for the ten rounds AFTER the
$90 brake had already answered `exit 3` to the cheapest possible wave.  Measured
cost $0.116/day; on this month's first zero-batch day the `AWS Cost Explorer`
line was $0.040 of $0.075 published spend -- 53.1%, the largest single item,
with no EC2 row at all.

WHY THAT SHAPE IS WORTH A RATCHET AND NOT JUST A PATCH.  The failure direction
is the dangerous one: the script spends most reliably exactly when there is
least room left to spend, and the spending itself moves the brake closer.  The
confirmation's legislative purpose is to make a LAUNCH DECISION safe; when
headroom can no longer fit the cheapest wave ($1.10) there is no launch
decision, so the $0.01 buys a number nobody can act on.

THE SEPARATING ASSERTION IS NOT "IT DID NOT CALL CE".  A script that never
confirms anything passes that.  Every skip case below is paired with a pay case
that differs only in the MTD, so what is asserted is the BOUNDARY, not the
silence.  Section 4 is the one that matters most: an unreadable brake must fall
through to PAYING, because the other fallback (assume $90) would let an
owner-raised brake silently keep the confirmation switched off in exactly the
situation where launches are possible again.

COVERED HERE (behaviourally -- the real bash script runs, against an `awsx` on
PATH that records every subcommand and returns canned budget rows):
  * below CONFIRM_AT               -> no CE call         (pre-existing rule)
  * above CONFIRM_AT, headroom ok  -> CE call            (pre-existing rule)
  * above CONFIRM_AT, no headroom  -> no CE call, and a line that calls itself
                                      a SKIP, not a pass                (#801)
  * exactly at the boundary        -> pays (>= is not <)               (#801)
  * brake unreadable               -> pays, and says why                (#801)
      both ways it can be unreadable: a garbage override, AND the wave_fence
      import failing (the second one needed a seam -- see 4-bis)
  * COST_BRAKE_AT=0                -> pays (documented escape hatch)   (#801)
  * --ce / --leak-only             -> unchanged by all of the above
"""

import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AWSDIR = os.path.join(REPO, "tools", "batch_test", "aws")
SCRIPT = os.path.join(AWSDIR, "check_costs.sh")

CHECKS = 0
FAILURES = []


def check(cond, label):
    global CHECKS
    CHECKS += 1
    if not cond:
        FAILURES.append(label)
        print("FAIL: %s" % label)


def make_fake_aws(tmp, actual, budget_ok=True):
    """An `awsx` on PATH that answers the four reads and logs every call.

    It answers `budgets describe-budgets` with `actual`, and `ce
    get-cost-and-usage` with a number that is deliberately NOT equal to
    `actual` -- so a test can tell which source a printed figure came from.
    """
    d = os.path.join(tmp, "bin")
    os.makedirs(d, exist_ok=True)
    calllog = os.path.join(tmp, "calls.log")
    path = os.path.join(d, "awsx")
    with open(path, "w") as f:
        f.write(
            "#!/bin/sh\n"
            'echo "$@" >> %s\n'
            'case "$1 $2" in\n'
            '  "sts get-caller-identity") echo 581436534924 ;;\n'
            '  "budgets describe-budgets")\n'
            "      %s\n"
            "      ;;\n"
            '  "ce get-cost-and-usage") printf "%%s\\tUSD\\n" 77.777777 ;;\n'
            "  *) : ;;\n"
            "esac\n"
            "exit 0\n"
            % (
                calllog,
                (
                    'printf "%s\\t99.9\\t100.0\\t1757772000\\n"' % actual
                    if budget_ok
                    else "exit 1"
                ),
            )
        )
    os.chmod(path, 0o755)
    return d, calllog


def run(tmp, actual, args=(), env=None, budget_ok=True):
    """Run the real check_costs.sh; return (proc, [argv lines the fake saw])."""
    fakebin, calllog = make_fake_aws(tmp, actual, budget_ok=budget_ok)
    e = dict(os.environ)
    e["PATH"] = fakebin + os.pathsep + e["PATH"]
    # aws.env may name a region only; keep the script's own defaults otherwise.
    if env:
        e.update(env)
    p = subprocess.run(["bash", SCRIPT] + list(args), cwd=AWSDIR, env=e,
                       capture_output=True, text=True)
    calls = []
    if os.path.exists(calllog):
        calls = [l.strip() for l in open(calllog) if l.strip()]
    return p, calls


def ce_calls(calls):
    return [c for c in calls if c.startswith("ce get-cost-and-usage")]


def main():
    src = open(SCRIPT).read()

    # ---- 0. the constants exist and the brake is not a second hard-coded copy
    check("CHEAPEST_WAVE" in src, "0a: script defines CHEAPEST_WAVE")
    check("wave_fence" in src and "DEFAULT_BRAKE" in src,
          "0b: the brake is read from wave_fence.py, not re-typed here")
    # The one number that may legitimately be literal here is the wave cost.
    check("COST_BRAKE_AT" in src and "COST_CHEAPEST_WAVE" in src,
          "0c: both numbers are overridable from the environment")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 1. pre-existing rule: below the confirm line, never pay
        p, calls = run(tmp, "12.500")
        check(p.returncode == 0, "1a: exits 0 below CONFIRM_AT")
        check(ce_calls(calls) == [], "1b: no CE call below CONFIRM_AT")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 2. pre-existing rule: above the confirm line WITH headroom, pay
        #         ($50 is $40 below the $90 brake -- a wave still fits)
        p, calls = run(tmp, "50.000")
        check(p.returncode == 0, "2a: exits 0 above CONFIRM_AT with headroom")
        check(len(ce_calls(calls)) == 1,
              "2b: pays exactly one CE call when a launch is still possible")
        check("confirming against cost-explorer" in p.stdout,
              "2c: says it is confirming")
        check("77.777777" in p.stdout, "2d: the CE figure reaches stdout")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 3. #801: above the confirm line WITHOUT headroom, do not pay.
        #         $89.130 is the reading that was live when #801 was filed:
        #         headroom $0.870 < $1.10, and gate (iii) answered exit 3.
        p, calls = run(tmp, "89.130")
        check(p.returncode == 0, "3a: exits 0 above the brake (still a report)")
        check(ce_calls(calls) == [],
              "3b: pays NOTHING when no wave can launch  <-- #801")
        check("SKIPPED" in p.stdout and "NOT passed" in p.stdout,
              "3c: the skip calls itself a skip, not a pass")
        check("0.870" in p.stdout,
              "3d: it prints the headroom it decided on (a reading, not a mood)")
        check("Resumes by itself" in p.stdout,
              "3e: it prints the restore condition, so nobody has to remember it")
        check("89.130" in p.stdout,
              "3f: the free MTD is still reported -- the report is not skipped")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 3'. the BOUNDARY, which is what separates the fix from "never
        #          confirm".  headroom == $1.10 exactly: a wave still fits.
        p, calls = run(tmp, "88.900")
        check(len(ce_calls(calls)) == 1,
              "3g: headroom == cheapest wave still PAYS (>= is not <)")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 4. #801's fail direction: an unreadable brake must PAY.
        p, calls = run(tmp, "89.130", env={"COST_BRAKE_AT": "not-a-number"})
        check(len(ce_calls(calls)) == 1,
              "4a: an unreadable brake pays -- it must not silence the check")
        check("brake unreadable" in p.stdout,
              "4b: and says so, so the paid call is explainable")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 4-bis. THE CASE THAT A SURVIVING MUTANT ASKED FOR.
        # 4a above only covers "COST_BRAKE_AT is set to garbage".  The fallback
        # that actually matters is the OTHER one: wave_fence.py unreadable, no
        # override set.  A mutant substituting a literal 90.00 there survived
        # every assertion in this file (2026-09-13) because no test could make
        # the import fail.  COST_BRAKE_SRC makes that path reachable; pointing
        # it at an empty directory is exactly "the constant is gone".
        empty = os.path.join(tmp, "no_wave_fence_here")
        os.makedirs(empty)
        p, calls = run(tmp, "89.130", env={"COST_BRAKE_SRC": empty})
        check(len(ce_calls(calls)) == 1,
              "4e: an unreadable wave_fence.py pays -- no literal brake is "
              "substituted behind the reader's back  <-- kills the survivor")
        check("brake unreadable" in p.stdout,
              "4f: and the paid call explains itself")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 4-ter. the same seam, pointed at the real thing, still reads the
        # real constant -- otherwise 4e would pass for the boring reason that
        # the seam broke the brake read for everyone.
        p, calls = run(tmp, "89.130",
                       env={"COST_BRAKE_SRC": os.path.join(REPO, "tools",
                                                           "batch_test", "soak")})
        check(ce_calls(calls) == [],
              "4g: the seam pointed at the real soak/ still finds $90 and skips")
        check("90.00 brake" in p.stdout,
              "4h: and the skip line quotes the brake it actually read")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 4'. the documented escape hatch behaves as documented
        p, calls = run(tmp, "89.130", env={"COST_BRAKE_AT": "0"})
        check(len(ce_calls(calls)) == 1,
              "4c: COST_BRAKE_AT=0 disables the condition (pays), as documented")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 4''. an owner-raised brake re-opens the confirmation by itself
        p, calls = run(tmp, "89.130", env={"COST_BRAKE_AT": "150"})
        check(len(ce_calls(calls)) == 1,
              "4d: raising the brake resumes paying with no other edit")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 5. the explicit modes are untouched by any of this
        p, calls = run(tmp, "89.130", args=["--ce"])
        check(len(ce_calls(calls)) == 1,
              "5a: --ce still forces the paid read above the brake")
        check("SKIPPED" not in p.stdout, "5b: --ce prints no skip line")

    with tempfile.TemporaryDirectory() as tmp:
        p, calls = run(tmp, "89.130", args=["--leak-only"])
        check(ce_calls(calls) == [], "5c: --leak-only still costs nothing")
        check("skipped: --leak-only" in p.stdout, "5d: --leak-only says so")

    with tempfile.TemporaryDirectory() as tmp:
        # ---- 6. the budgets-read failure path is unchanged: CE is the
        #         fallback SOURCE there, not the confirmation, so the #801
        #         condition must not suppress it.
        p, calls = run(tmp, "89.130", budget_ok=False)
        check(len(ce_calls(calls)) == 1,
              "6a: a failed budgets read still falls back to CE above the brake")

    with tempfile.TemporaryDirectory() as tmp:
        p, calls = run(tmp, "89.130", args=["--budgets-only"], budget_ok=False)
        check(ce_calls(calls) == [],
              "6b: --budgets-only still forbids that fallback")
        check(p.returncode == 1, "6c: and still exits 1")

    # ---- 7. --help, from a directory that is NOT the script's own.  Found
    # while editing the header line range: the script cd's into its own
    # directory first, so a relative `$0` is already stale by the time --help
    # reads it, and every caller outside tools/batch_test/aws got
    # `sed: can't read ...` and exit 2.  Pre-existing; fixed in the same edit.
    # ⚠️ The path must be RELATIVE.  An absolute $0 survives the cd, so a test
    # that passes SCRIPT (absolute) asserts nothing here -- the reverted-fix
    # mutant passed it.  The shape that broke is the shape a human types.
    rel = os.path.relpath(SCRIPT, REPO)
    p = subprocess.run(["bash", rel, "--help"], cwd=REPO,
                       capture_output=True, text=True)
    check(p.returncode == 0,
          "7a: --help exits 0 when invoked by RELATIVE path from elsewhere")
    check("Usage:" in p.stdout, "7b: --help actually prints the usage block")
    check("GH #801" in p.stdout, "7c: and documents the condition it now has")
    check("set -euo" not in p.stdout,
          "7d: the range stops at the header, not three lines into the code")

    print("\n%d checks, %d failed" % (CHECKS, len(FAILURES)))
    for f in FAILURES:
        print("  - %s" % f)
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
