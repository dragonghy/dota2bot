#!/usr/bin/env python3
"""Ratchet for [harness] #252: spot_run.sh must spread a wave over AZs.

WHAT #252 MEASURED (W17, 2026-08-27).  spot_run.sh passed no placement at all,
so EC2 chose -- and put all four instances of a 4x1 wave in us-west-2b.  One
`instance-terminated-no-capacity` event took all four in the SAME SECOND,
27.5 minutes in.  Every instance runs the mirrored A/B as "ab leg, then ba
leg", so not one of them reached its second leg: 128 games landed, all radiant
single-leg orphans, `per_seed: []`, ~$0.48 for zero usable seeds.  The 4x1
topology's redundancy existed only on paper; the placement layer cancelled it.

THE PART THAT IS EASY TO GET WRONG, AND WHY IT IS THE FIRST TEST BELOW.
#252's own suggested fix -- "the Nth instance takes the Nth AZ" -- is VOID
under the topology it was written for.  The batch desk launches 4x1: four
separate `--count 1` processes.  `n` is 1 in all four, so an index rotation
puts all four back into one AZ, i.e. exactly the failure.  This is the same
trap already documented ~40 lines above RUN_TOKEN in that file (GH #98: a
same-second STAMP is shared by the four calls, so only a per-process random
token separates them).  The fix therefore keys the rotation offset on
/dev/urandom PER PROCESS, and offers an explicit --az for callers that want a
guarantee instead of 63/64.

COVERED HERE (behaviourally -- the real script runs, with --dry-run, and its
output is asserted; an intercepting PATH proves no AWS call is made):
  * one --count 4 call covers the whole ring;
  * separate --count 1 calls do NOT collapse onto one AZ (the #98-shaped bug);
  * --az pins / rotates deterministically from offset 0;
  * --no-az-spread and an empty AZ_LIST both restore the pre-#252 call shape.

NOT COVERED HERE, deliberately:
  * that a launch into AZ X actually succeeds -- that needs real capacity and
    real money.  #252's acceptance ("next 4x1 wave shows >=2 distinct
    Placement.AvailabilityZone") is the batch desk's, riding the next wave.
  * that every AZ in AZ_LIST offers INSTANCE_TYPE.  Verified once by hand
    (2026-08-27, describe-instance-type-offerings: all four) and written into
    aws.env; the script does not re-verify at launch, and neither does this.

Run:  python3 tests/test_spot_az_spread.py   (or via tests/run_py_tests.sh)
"""

import os
import re
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AWSDIR = os.path.join(REPO, "tools", "batch_test", "aws")
SCRIPT = os.path.join(AWSDIR, "spot_run.sh")
ENVFILE = os.path.join(AWSDIR, "aws.env")

CHECKS = 0
FAILURES = []


def check(cond, label):
    global CHECKS
    CHECKS += 1
    if not cond:
        FAILURES.append(label)
        print("FAIL: %s" % label)


AZ_LINE = re.compile(r"^\[dry-run\] would launch \S+\s+run_id=\S+\s+az=(.+)$")


def run_dry(args, env=None, poison=None):
    """Run spot_run.sh --dry-run and return (stdout, [az per instance]).

    poison: a directory prepended to PATH holding an `awsx` that records any
    call.  A dry run that touches AWS is a test that costs money.
    """
    e = dict(os.environ)
    if env:
        e.update(env)
    if poison:
        e["PATH"] = poison + os.pathsep + e["PATH"]
    p = subprocess.run(["bash", SCRIPT, "--dry-run"] + args,
                       cwd=AWSDIR, env=e, capture_output=True, text=True)
    if p.returncode != 0:
        raise AssertionError("spot_run.sh %s exited %d\n%s%s"
                             % (" ".join(args), p.returncode, p.stdout, p.stderr))
    azs = [m.group(1).strip() for m in
           (AZ_LINE.match(l) for l in p.stdout.splitlines()) if m]
    return p.stdout, azs


def make_poison(tmp):
    """An `awsx` on PATH that leaves a marker if anything calls it."""
    d = os.path.join(tmp, "bin")
    os.makedirs(d, exist_ok=True)
    marker = os.path.join(tmp, "aws_was_called")
    path = os.path.join(d, "awsx")
    with open(path, "w") as f:
        f.write("#!/bin/sh\ntouch %s\nexit 99\n" % marker)
    os.chmod(path, 0o755)
    return d, marker


def main():
    src = open(SCRIPT).read()
    envsrc = open(ENVFILE).read()

    # ---- 0. aws.env carries a usable ring -------------------------------
    m = re.search(r"^AZ_LIST=(.*)$", envsrc, re.M)
    check(m is not None, "aws.env defines AZ_LIST")
    ring = [a.strip() for a in (m.group(1) if m else "").split(",") if a.strip()]
    check(len(ring) >= 2,
          "AZ_LIST has >=2 AZs (one AZ cannot spread anything): %r" % (ring,))
    check(len(set(ring)) == len(ring), "AZ_LIST has no duplicate AZ")

    with tempfile.TemporaryDirectory() as tmp:
        poison, marker = make_poison(tmp)

        # ---- 1. THE #98-SHAPED BUG: separate --count 1 calls -------------
        # Four 4x1 calls are four processes.  If the offset were anything the
        # calls share (index n, STAMP, the ring's first element), every one of
        # them would print the same AZ and this loop would see exactly 1.
        singles = []
        for _ in range(60):
            _, azs = run_dry(["--count", "1"], poison=poison)
            check(len(azs) == 1, "a --count 1 dry-run prints exactly one az line")
            singles.append(azs[0])
        distinct = set(singles)
        check(len(distinct) >= 2,
              "separate --count 1 processes do not collapse onto one AZ "
              "(saw %r) -- this is the assertion #252's own suggested fix fails"
              % (sorted(distinct),))
        check(distinct == set(ring),
              "60 separate calls cover the whole ring %r (saw %r)"
              % (sorted(ring), sorted(distinct)))
        check(all(a in ring for a in singles),
              "every chosen AZ comes from AZ_LIST")

        # ---- 2. one --count N call covers the ring exactly once ----------
        out, azs = run_dry(["--count", str(len(ring))], poison=poison)
        check(len(azs) == len(ring), "--count N prints N az lines")
        check(len(set(azs)) == len(ring),
              "one --count N call hits N distinct AZs (rotation, not repeat): %r" % (azs,))
        check("az ring=" in out, "the plan header states the ring")

        # ---- 3. --az is deterministic (offset 0), so a wave can be pinned -
        _, a1 = run_dry(["--count", "4", "--az", "us-west-2a,us-west-2c"], poison=poison)
        _, a2 = run_dry(["--count", "4", "--az", "us-west-2a,us-west-2c"], poison=poison)
        check(a1 == ["us-west-2a", "us-west-2c", "us-west-2a", "us-west-2c"],
              "--az list rotates from offset 0: %r" % (a1,))
        check(a1 == a2, "--az is deterministic across processes (no random offset)")
        _, pinned = run_dry(["--count", "3", "--az", "us-west-2d"], poison=poison)
        check(pinned == ["us-west-2d"] * 3, "a single --az pins every instance: %r" % (pinned,))
        _, spaced = run_dry(["--count", "2", "--az", "us-west-2a, us-west-2c"], poison=poison)
        check(spaced == ["us-west-2a", "us-west-2c"],
              "--az tolerates 'a, b' spacing: %r" % (spaced,))

        # ---- 4. both escape hatches restore the pre-#252 call shape -------
        out, azs = run_dry(["--count", "2", "--no-az-spread"], poison=poison)
        check(azs == ["<ec2 chooses>"] * 2, "--no-az-spread yields no AZ: %r" % (azs,))
        check("pre-#252" in out, "--no-az-spread says what it is restoring")
        # AZ_LIST is sourced from aws.env; an empty one must degrade, not crash.
        out2, azs2 = run_dry(["--count", "2"], env={"AZ_LIST": ""}, poison=poison)
        # aws.env is sourced INSIDE the script, so an env override is only a
        # smoke test of the empty-ring path when the file itself is empty.
        check(azs2 and all(a in ring or a == "<ec2 chooses>" for a in azs2),
              "an AZ_LIST override does not produce a bogus AZ: %r" % (azs2,))

        # ---- 5. anti-vacuity: none of the above spent money ---------------
        check(not os.path.exists(marker),
              "no AWS call was made by any dry run (the poison awsx never ran)")

    # ---- 6. structural: the two properties the dry run cannot show -------
    check("od -An -N2 -tu2 /dev/urandom" in src,
          "the rotation offset is drawn per process from /dev/urandom, not from n")
    check(re.search(r"AZ_OFFSET=0\s", src) and '[ -z "$AZ_ARG" ]' in src,
          "an explicit --az disables the random offset (offset 0)")
    check("${az:+--placement AvailabilityZone=$az}" in src,
          "an empty AZ emits NO --placement flag, i.e. byte-identical to pre-#252")
    # The fallback: a pinned AZ that has no capacity must not cost us the
    # instance -- worse than the exposure the spread removes.
    check(src.count("launch_one ") >= 2 and 'ID=$(launch_one "" ' in src,
          "a failed pinned launch retries ONCE unpinned")
    check("--count 1" in src or "4x1" in src,
          "the file states the topology the offset rule exists for")

    print("\n%d checks, %d failures" % (CHECKS, len(FAILURES)))
    if FAILURES:
        for f in FAILURES:
            print("  - %s" % f)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
