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


def make_fake_aws(tmp, actual, budget_ok=True, instances="[]"):
    """An `awsx` on PATH that answers the reads and logs every call.

    It answers `budgets describe-budgets` with `actual`, and `ce
    get-cost-and-usage` with a number that is deliberately NOT equal to
    `actual` -- so a test can tell which source a printed figure came from.

    `instances` is the Reservations list the GH #779 accrual probe's (alpha)
    census sees.  The default `[]` is the state every #801 round was actually
    measured in (`CERTIFIED 0 accruing instances account-wide`), so the #801
    sections below assert the skip against the real scenario rather than
    against an account the fake simply could not describe.
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
            '  "ec2 describe-regions")\n'
            '      echo \'{"Regions":[{"RegionName":"us-west-2"}]}\' ;;\n'
            # Two different callers reach `describe-instances`: the leak check
            # at the top of the script (tag-filtered, --output table) and the
            # GH #779 census (deliberately NOT tag-filtered). Only the census
            # is steered here -- failing both would kill the script under
            # `set -e` at the leak check and never reach the code under test.
            '  "ec2 describe-instances")\n'
            '      case "$*" in\n'
            '        *tag:Name*) echo \'{"Reservations":[]}\' ;;\n'
            "        *) %s ;;\n"
            "      esac ;;\n"
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
                ("exit 1" if instances is None
                 else "echo '{\"Reservations\":%s}'" % instances),
            )
        )
    os.chmod(path, 0o755)
    return d, calllog


ONE_LIVE_INSTANCE = (
    '[{"Instances":[{"InstanceId":"i-0ff","InstanceType":"c6i.4xlarge",'
    '"State":{"Name":"running"},"LaunchTime":"2026-09-14T09:00:00+00:00",'
    '"Tags":[{"Key":"Project","Value":"someone-else"}]}]}]'
)


def run(tmp, actual, args=(), env=None, budget_ok=True, instances="[]",
        state=None):
    """Run the real check_costs.sh; return (proc, [argv lines the fake saw]).

    `state` is the GH #779 stamp cache.  It defaults to a fresh path inside
    `tmp`, so no test can be contaminated by another test's stamp -- or by the
    real container cache, which would make these results depend on whether a
    routine had run check_costs.sh earlier in the session.
    """
    fakebin, calllog = make_fake_aws(tmp, actual, budget_ok=budget_ok,
                                     instances=instances)
    e = dict(os.environ)
    e["PATH"] = fakebin + os.pathsep + e["PATH"]
    e["COST_ACCRUAL_STATE"] = state or os.path.join(tmp, "stamp")
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

    # ---- 8. GH #779, director 2026-09-14T09:5xZ ruling 2: the accrual probe.
    #
    # Every case below sits at MTD 89.130 -- inside #801's skip, where the
    # script would otherwise never pay. What separates them is ONLY the thing
    # the ruling names, so each pair isolates one conjunct:
    #   8a vs 8b : the census (alpha). Same frozen stamp, different account.
    #   8b vs 8c : the stamp.  Same live instance, frozen vs moved.
    # A patch that just "pays when the stamp is frozen" fails 8a; one that just
    # "pays when something is accruing" fails 8c; one that never pays fails 8b.
    STAMP = "1757772000"            # what the fake budget reports every run

    with tempfile.TemporaryDirectory() as tmp:
        # 8a. Frozen stamp, IDLE account -> the both-zero clause: buy nothing.
        st = os.path.join(tmp, "stamp")
        open(st, "w").write(STAMP)
        p, calls = run(tmp, "89.130", state=st)
        check(ce_calls(calls) == [],
              "8a: frozen stamp + alpha/beta both zero pays NOTHING  <-- #779")
        check("no blind spot" in p.stdout,
              "8b-pre: and it says why -- a stopped clock over an idle account")
        check("SKIPPED" in p.stdout and "NOT passed" in p.stdout,
              "8a': #801's skip line still stands underneath it")

    with tempfile.TemporaryDirectory() as tmp:
        # 8b. Frozen stamp, one accruing instance -> the blind spot is real.
        st = os.path.join(tmp, "stamp")
        open(st, "w").write(STAMP)
        p, calls = run(tmp, "89.130", state=st, instances=ONE_LIVE_INSTANCE)
        check(len(ce_calls(calls)) == 1,
              "8b: frozen stamp + a live accruing instance PAYS  <-- #779")
        check("1 accruing instance" in p.stdout,
              "8b': the census reading is printed, not just its verdict")
        check("77.777777" in p.stdout,
              "8b'': and the CE figure actually reaches stdout")

    with tempfile.TemporaryDirectory() as tmp:
        # 8c. Same live instance, but the stamp MOVED -> first conjunct fails.
        st = os.path.join(tmp, "stamp")
        open(st, "w").write("1700000000")       # a different, older stamp
        p, calls = run(tmp, "89.130", state=st, instances=ONE_LIVE_INSTANCE)
        check(ce_calls(calls) == [],
              "8c: a stamp that MOVED does not pay, even with alpha non-zero")
        check("moved" in p.stdout,
              "8c': and names which conjunct failed")

    with tempfile.TemporaryDirectory() as tmp:
        # 8d. Fail direction, and the exact shape that makes it load-bearing:
        # `describe-regions` answers but `describe-instances` FAILS in every
        # region. read_accruing_instances does not raise for that -- it returns
        # an empty list with an incomplete scope, which is byte-identical to an
        # idle account at the call site. Read as zero it walks into the
        # both-zero clause and buys nothing, in precisely the case where the
        # account might be burning money unseen.
        #
        # ⚠️ This assertion was WRONG on its first draft and a mutant proved it:
        # it fed invalid JSON instead, which raises inside parse_instances and
        # exits 2 down the generic exception path -- so deleting the scope
        # guard entirely still passed. A failing call, not a malformed one, is
        # what reaches the guard.
        p, calls = run(tmp, "89.130", instances=None,
                       state=os.path.join(tmp, "stamp"))
        check(len(ce_calls(calls)) == 1,
              "8d: an unreadable census PAYS -- it must not silence the check")
        check("UNCERTIFIABLE" in p.stdout,
              "8d': and calls itself uncertifiable, not 'nothing accruing'")
        check("INCOMPLETE" in p.stdout or "not 'zero'" in p.stdout,
              "8d'': via the scope guard -- 'zero within scope' is not zero")

    with tempfile.TemporaryDirectory() as tmp:
        # 8j. (beta) on its own: an IDLE account, but a wave launched inside
        # the 11.3h lag window. That is the case the whole ruling exists for --
        # the machine has already self-terminated (so the census is honestly
        # zero) and the money it spent has not landed in MTD yet. A mutant that
        # dropped the wave-record disjunct survived the suite until this case
        # existed, because every other case here drives (alpha).
        wd = os.path.join(tmp, "waves")
        os.makedirs(wd)
        # The fake budget stamp is epoch 1757772000 = 2025-09-13T14:00:00Z;
        # 30 minutes before it is comfortably inside the 11.3h window.
        with open(os.path.join(wd, "W99_wave.json"), "w") as f:
            f.write('{"wave": "W99", "machines": [{"seed": 1,'
                    ' "launched_at": "2025-09-13T13:30:00.000Z"}]}')
        st = os.path.join(tmp, "stamp")
        open(st, "w").write(STAMP)
        p, calls = run(tmp, "89.130", state=st, env={"COST_WAVES_DIR": wd})
        check(len(ce_calls(calls)) == 1,
              "8j: frozen stamp + a wave inside the 11.3h window PAYS  <-- #779")
        check("1 wave record" in p.stdout,
              "8j': and the beta reading is printed alongside alpha")

    with tempfile.TemporaryDirectory() as tmp:
        # 8k. The same wave, but dated well outside the window -> nothing is
        # accruing unseen, so the both-zero clause answers and nothing is paid.
        # This is what stops 8j from passing on "any waves dir at all".
        wd = os.path.join(tmp, "waves")
        os.makedirs(wd)
        with open(os.path.join(wd, "W99_wave.json"), "w") as f:
            f.write('{"wave": "W99", "machines": [{"seed": 1,'
                    ' "launched_at": "2025-09-10T13:30:00.000Z"}]}')
        st = os.path.join(tmp, "stamp")
        open(st, "w").write(STAMP)
        p, calls = run(tmp, "89.130", state=st, env={"COST_WAVES_DIR": wd})
        check(ce_calls(calls) == [],
              "8k: a wave OUTSIDE the window does not pay -- the window binds")

    with tempfile.TemporaryDirectory() as tmp:
        # 8l. A fresh container has no prior stamp, and every routine session is
        # one. Unknown must be treated as frozen -- but only here, inside the
        # alpha/beta branch. A mutant that made unknown mean "do not pay"
        # survived until this case existed, and it would have failed silently:
        # the first round after any container restart is exactly when a wave
        # from the previous session may still be unaccounted for.
        p, calls = run(tmp, "89.130", instances=ONE_LIVE_INSTANCE,
                       state=os.path.join(tmp, "no-such-stamp"))
        check(len(ce_calls(calls)) == 1,
              "8l: no prior stamp + alpha non-zero PAYS (unknown = frozen)")
        check("fresh container" in p.stdout,
              "8l': and says the stamp was unknown, not that it was frozen")

    with tempfile.TemporaryDirectory() as tmp:
        # 8m. ...and the other half of 8l: a fresh container over an IDLE
        # account still pays nothing, so "unknown = frozen" cannot become a
        # back door that makes every first round of every session buy a read.
        p, calls = run(tmp, "89.130",
                       state=os.path.join(tmp, "no-such-stamp"))
        check(ce_calls(calls) == [],
              "8m: no prior stamp over an idle account still pays NOTHING")

    with tempfile.TemporaryDirectory() as tmp:
        # 8e. The escape hatch is a SKIP and says so (RULE6_BYPASS discipline).
        p, calls = run(tmp, "89.130", instances=ONE_LIVE_INSTANCE,
                       env={"COST_NO_ACCRUAL_PROBE": "1"})
        check(ce_calls(calls) == [], "8e: the escape hatch does not pay")
        check("NOT CONSULTED" in p.stdout and "SKIP" in p.stdout,
              "8e': and prints a line that calls itself a skip, not a finding")

    with tempfile.TemporaryDirectory() as tmp:
        # 8f. Below CONFIRM_AT nothing changed: the probe is not even reached,
        # so the new leg cannot add AWS calls to the common quiet round.
        p, calls = run(tmp, "12.500", instances=ONE_LIVE_INSTANCE)
        check(ce_calls(calls) == [], "8f: still no CE call below CONFIRM_AT")
        check("accrual probe" not in p.stdout,
              "8f': and the probe is not consulted at all down there")

    # ---- 8g. THE ONE THE RULING FORBIDS IN AS MANY WORDS: no freeze-duration
    # threshold anywhere in the criterion. The withdrawn quantity is freeze
    # DURATION; keying the purchase on it would put a retracted reading into a
    # trigger position. "Frozen" must be a comparison, never a clock arithmetic.
    probe_src = open(os.path.join(AWSDIR, "accrual_probe.py")).read()
    import re as _re
    check(not _re.search(r"FREEZE_(HOURS|MAX|MIN)|freeze_hours|frozen_for",
                         probe_src),
          "8g: the criterion defines no freeze-duration threshold  <-- #779")
    # Substring matching cannot answer this one: the probe's own docstring
    # explains WHY it does not re-type the window, and naming a constant in
    # order to say "not defined here" must not read as defining it. So the
    # assertion is on the parsed tree -- no 11.3 float literal reaches code,
    # and nothing assigns the window's name.
    import ast as _ast
    _tree = _ast.parse(probe_src)
    _floats = [n.value for n in _ast.walk(_tree)
               if isinstance(n, _ast.Constant) and isinstance(n.value, float)]
    _assigned = [t.id for n in _ast.walk(_tree)
                 if isinstance(n, _ast.Assign) for t in n.targets
                 if isinstance(t, _ast.Name)]
    check(11.3 not in _floats and "ACCRUAL_LAG_MAX_HOURS" not in _assigned,
          "8h: the 11.3h window is imported from wave_fence, not re-typed")
    check("read_wave_accrual" in probe_src
          and "read_accruing_instances" in probe_src,
          "8i: both instruments are wave_fence's, so there is one definition")

    print("\n%d checks, %d failed" % (CHECKS, len(FAILURES)))
    for f in FAILURES:
        print("  - %s" % f)
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
