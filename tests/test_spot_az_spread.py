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

AND THE RESIDUE #256 FOUND, one wave later.  W18 passed #252's acceptance (4
instances, 3 distinct AZs) and in the same wave showed that a pinned AZ with no
capacity fell back to "let EC2 choose" — which chose us-west-2b, the AZ that
had just zeroed W17 and W17-R.  The fallback quietly restored the correlation
#252 removes, in the one situation where it is most likely to be fatal (the pin
failed BECAUSE capacity is tight).  Section 7 below drives the real script
against a fake EC2 that refuses named AZs, and asserts the ring walk: the
separating assertion is not "an instance launched" — the buggy version launches
one too — but "the instance it launched is still inside the ring".

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


LAUNCH_RE = re.compile(r"^launched \S+\s+id=(\S+)\s+run_id=\S+\s+az=(.+)$")


def make_fake_ec2(tmp, fail_azs):
    """An `awsx` on PATH that SIMULATES run-instances, failing in `fail_azs`.

    Returns (bindir, calllog).  Every call appends the requested AZ (or the
    literal `none` for an unpinned call) to calllog, so the retry walk is
    readable as a sequence, not just as a final state.  Real AWS is never
    reached: spot_run.sh routes every `aws` through `awsx`, and this one
    shadows it on PATH.
    """
    d = os.path.join(tmp, "fakebin")
    os.makedirs(d, exist_ok=True)
    calllog = os.path.join(tmp, "calls.txt")
    path = os.path.join(d, "awsx")
    with open(path, "w") as f:
        f.write(
            "#!/bin/bash\n"
            "az=none\n"
            "for a in \"$@\"; do\n"
            "  case \"$a\" in AvailabilityZone=*) az=${a#AvailabilityZone=} ;; esac\n"
            "done\n"
            "echo \"$az\" >> %s\n"
            "for bad in %s; do\n"
            "  if [ \"$az\" = \"$bad\" ]; then\n"
            "    echo 'An error occurred (InsufficientInstanceCapacity) ...' >&2\n"
            "    exit 254\n"
            "  fi\n"
            "done\n"
            "echo \"i-fake${az//[!a-z0-9]/}\"\n"
            % (calllog, " ".join(fail_azs) or "__none__")
        )
    os.chmod(path, 0o755)
    return d, calllog


def run_live(args, fakebin):
    """Run spot_run.sh for real (no --dry-run) against the fake EC2."""
    e = dict(os.environ)
    e["PATH"] = fakebin + os.pathsep + e["PATH"]
    p = subprocess.run(["bash", SCRIPT] + args, cwd=AWSDIR, env=e,
                       capture_output=True, text=True)
    launched = [(m.group(1), m.group(2).strip()) for m in
                (LAUNCH_RE.match(l) for l in p.stdout.splitlines()) if m]
    return p, launched


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
          "a failed pinned launch still ends with an instance (unpinned last resort)")
    check("--count 1" in src or "4x1" in src,
          "the file states the topology the offset rule exists for")

    # ---- 7. [harness] #256: a failed pin re-aims INSIDE the ring ---------
    # W18 (2026-08-27) passed #252's acceptance (3 distinct AZs of 4) and in the
    # same wave showed the residue: seed 921 asked for us-west-2c, the pin
    # failed, the fallback dropped placement entirely, and EC2 put it in
    # us-west-2b -- the AZ that had just zeroed W17 and W17-R.  The assertion
    # that separates the fix from the bug is not "an instance was launched"
    # (the buggy version launches one too); it is "the instance it launched is
    # still inside the ring".
    with tempfile.TemporaryDirectory() as tmp:
        # 7a. one AZ dead -> next ring AZ, NOT <ec2 chose>.
        fake, calllog = make_fake_ec2(tmp, ["us-west-2c"])
        p, launched = run_live(["--count", "1", "--az", "us-west-2c"], fake)
        check(p.returncode == 0, "a dead pinned AZ is not fatal (exit %d)" % p.returncode)
        check(len(launched) == 1, "exactly one instance launched: %r" % (launched,))
        got_az = launched[0][1] if launched else ""
        check(got_az != "<ec2 chose>",
              "a dead pin does NOT fall back to EC2-chosen placement -- this is "
              "the #256 assertion the pre-fix script fails (got %r)" % got_az)
        check(got_az in ring and got_az != "us-west-2c",
              "it re-aims at another ring AZ: %r" % got_az)
        check(got_az == "us-west-2d",
              "the walk starts AFTER the failed AZ in ring order (2c -> 2d): %r" % got_az)
        check("re-aiming inside the ring" in p.stderr,
              "the re-aim is announced on stderr")
        calls = open(calllog).read().split()
        check(calls == ["us-west-2c", "us-west-2d"],
              "exactly one wasted call, then the next ring AZ: %r" % (calls,))
        check(len(calls) >= 1, "anti-vacuity: the fake EC2 really ran")

        # 7b. the walk diverges: two calls that failed in DIFFERENT AZs do not
        # pile onto the same next AZ (that would rebuild the correlation).
        os.makedirs(os.path.join(tmp, "b"), exist_ok=True)
        fake2, _ = make_fake_ec2(os.path.join(tmp, "b"), ["us-west-2a"])
        _, launched2 = run_live(["--count", "1", "--az", "us-west-2a"], fake2)
        check(launched2 and launched2[0][1] == "us-west-2b",
              "a 2a failure re-aims at 2b, not at 2d: %r" % (launched2,))

    with tempfile.TemporaryDirectory() as tmp:
        # 7c. only the last ring AZ alive -> the whole ring is walked, once each.
        fake, calllog = make_fake_ec2(tmp, ["us-west-2b", "us-west-2c", "us-west-2d"])
        p, launched = run_live(["--count", "1", "--az", "us-west-2b"], fake)
        calls = open(calllog).read().split()
        check(calls == ["us-west-2b", "us-west-2c", "us-west-2d", "us-west-2a"],
              "the ring is walked in order and each AZ tried exactly once: %r" % (calls,))
        check(launched and launched[0][1] == "us-west-2a",
              "the surviving AZ is used: %r" % (launched,))
        check("AZ RING EXHAUSTED" not in p.stderr,
              "a ring with one live AZ is not 'exhausted'")

    with tempfile.TemporaryDirectory() as tmp:
        # 7d. whole ring dead -> unpinned last resort, but LOUDLY.
        fake, calllog = make_fake_ec2(tmp, list(ring))
        p, launched = run_live(["--count", "1", "--az", "us-west-2a"], fake)
        check(p.returncode == 0, "ring exhaustion still launches (exit %d)" % p.returncode)
        check(launched and launched[0][1] == "<ec2 chose>",
              "the last resort is the pre-#252 unpinned call: %r" % (launched,))
        check("AZ RING EXHAUSTED" in p.stderr,
              "ring exhaustion is announced as its own `!!` line, not as a normal launch")
        check("!!" in p.stderr, "the exhaustion line is visually distinct from `!` retries")
        calls = open(calllog).read().split()
        check(calls == list(ring) + ["none"],
              "every ring AZ is tried before placement is abandoned: %r" % (calls,))

    with tempfile.TemporaryDirectory() as tmp:
        # 7e. anti-vacuity for the happy path: no retry when the pin succeeds.
        fake, calllog = make_fake_ec2(tmp, [])
        p, launched = run_live(["--count", "1", "--az", "us-west-2d"], fake)
        calls = open(calllog).read().split()
        check(calls == ["us-west-2d"],
              "a pin that works makes exactly ONE call (no gratuitous retry): %r" % (calls,))
        check(launched and launched[0][1] == "us-west-2d",
              "and reports the AZ it actually used: %r" % (launched,))
        check("re-aiming" not in p.stderr, "no re-aim line on the happy path")

    # 7f. structural: the retry ring is NOT the placement ring.  Under the batch
    # desk's one-explicit-AZ-per-call convention AZS has a single element, so a
    # retry keyed on AZS would have nowhere to walk -- i.e. #256 again.
    check("AZ_RETRY_RING" in src and 'IFS=\',\' read -r -a _rr_raw <<< "${AZ_LIST:-}"' in src,
          "the retry ring is built from aws.env AZ_LIST, not from the --az pin")
    check("az_retry_order" in src, "the walk order is a named, testable function")

    print("\n%d checks, %d failures" % (CHECKS, len(FAILURES)))
    if FAILURES:
        for f in FAILURES:
            print("  - %s" % f)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
