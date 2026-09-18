#!/usr/bin/env python3
"""Ratchet for the aws_run.sh rehearsal exit (director RULING 80 (乙), batch-desk 2026-09-18).

The defect this pins, stated as the mechanism rather than the symptom:

  spot_run.sh had `--dry-run`; aws_run.sh did not.  So the ONE launch path
  P4.1 goes through could not be walked without spending money, and every
  question about it -- does the SHA interpolate bare? what watchdog will the
  instance actually get? what does this wave cost the fence? -- could only be
  answered by launching, or by reading prose.  That is the carrier the P4.1
  ref-form defect rode for forty-nine rounds: it died inside the RENDERED
  user-data, where nothing local ever looked (see test_aws_run_ref_form.py).

  RULING 80 adds two disciplines this file keeps honest:
    (甲1) a real wave MUST pass --max-hours explicitly; the default must not
          be eaten silently.  The dry run has to SAY which of the two happened.
    (甲2) the fence prices an aws_run.sh wave against its OWN watchdog at the
          on-demand rate -- NOT against the $1.10 spot constant, which is
          calibrated on 4 x 0.550h spot machine-hours and does not price this
          path.  Getting this wrong under-records the fence: the dangerous
          side, and it stacks with the MTD lag the charter already names.

What this file covers, and what it does NOT:
  * "Launches nothing" is covered BEHAVIOURALLY, as a mutation stand: the
    stub `aws` does not merely record a call, it makes one FATAL.  The stand
    is then self-checked -- the same stub is run against a copy whose dry-run
    guard is disabled, and that copy MUST reach the launch.  Without that
    second half, "no AWS call" could equally mean the stub was never wired.
  * The price LINE is covered; the price VALUE is not.  $0.673/h is a dated
    charter constant, and this file does not claim it is still current --
    only that the line scales with the wave's own --max-hours instead of
    being pinned to the spot constant.
  * Nothing here says a real wave would launch, that refs resolve on the
    AMI's clone, or what the wave would actually cost.  Only AWS and the
    bill answer those.  This buys REHEARSABILITY.

Run:  python3 tests/test_aws_run_dryrun.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
AWS_RUN = os.path.join(ROOT, "tools", "batch_test", "aws", "aws_run.sh")

failures = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        print("  FAIL %s" % msg)
        failures.append(msg)


# A stub that does not just observe a launch -- it FAILS one.  A dry run that
# reaches this line is the defect, so the test must not be able to pass
# through it.
FATAL_STUB = (
    'aws() {\n'
    '    echo "LAUNCH_REACHED: $1 $2" >&2\n'
    '    exit 77\n'
    '}\n'
)


def run_variant(argv, disable_guard=False):
    """Run aws_run.sh (optionally with its dry-run guard mutated off).

    Returns (returncode, stdout, stderr).  `aws` is stubbed fatally, so even
    the mutated copy cannot reach real AWS.
    """
    src = open(AWS_RUN).read()
    anchor = "source aws.env\n"
    assert anchor in src, "aws_run.sh no longer sources aws.env"
    src = src.replace(anchor, anchor + FATAL_STUB, 1)
    if disable_guard:
        guard = 'if [ "$DRYRUN" -eq 1 ]; then'
        assert guard in src, "dry-run guard not found in its expected form"
        src = src.replace(guard, 'if [ "$DRYRUN" -eq 99 ]; then', 1)
    tmpdir = tempfile.mkdtemp()
    tmp = os.path.join(tmpdir, "aws_run_stub.sh")
    with open(tmp, "w") as fh:
        fh.write(src)
    os.chmod(tmp, 0o755)
    # aws_run.sh does `cd "$(dirname "$0")"` then `source aws.env`.
    shutil.copy(os.path.join(os.path.dirname(AWS_RUN), "aws.env"),
                os.path.join(tmpdir, "aws.env"))
    proc = subprocess.run(["bash", tmp] + argv, capture_output=True, text=True)
    shutil.rmtree(tmpdir, ignore_errors=True)
    return proc.returncode, proc.stdout, proc.stderr


BASE = ["--dry-run", "-n", "40", "--old",
        "74727e4a66ab38d16fdb09800a19ab6c0c82c6b9", "--new", "main"]

print("== 1. the flag exists and the rehearsal completes ==")
rc, out, err = run_variant(BASE + ["--max-hours", "2"])
check(rc == 0, "--dry-run exits 0 (rc=%d, stderr=%s)" % (rc, err.strip()[:200]))
check("(dry-run: nothing launched)" in out,
      "the run says, in so many words, that it launched nothing")

print("\n== 2. launches nothing -- and the stand proves it could have ==")
check("LAUNCH_REACHED" not in err and rc != 77,
      "no AWS call is made on the dry-run path")
mrc, mout, merr = run_variant(BASE + ["--max-hours", "2"], disable_guard=True)
check(mrc == 77 and "LAUNCH_REACHED: ec2 run-instances" in merr,
      "SELF-CHECK: with the guard disabled the SAME stub does reach the launch "
      "(mutant rc=%d) -- so check 2 above is a reading, not a silent no-op" % mrc)

print("\n== 3. the rendered user-data is printed (this is what it buys) ==")
check("---- rendered user-data" in out and "---- end user-data ----" in out,
      "the user-data the instance would run is shown, not summarised")
check("resolve_ref '74727e4a66ab38d16fdb09800a19ab6c0c82c6b9'" in out,
      "a bare-SHA --old reaches the resolver bare -- the P4.1 form is walkable "
      "locally (NOT a claim that it resolves on the AMI's clone)")
check("shutdown -h +120" in out,
      "--max-hours 2 really becomes the instance's watchdog (2h = 120min)")

print("\n== 4. RULING 80 (甲1): the watchdog says which way it was set ==")
check(re.search(r"--max-hours 2 \(EXPLICIT", out) is not None,
      "an explicitly passed --max-hours is marked EXPLICIT")
drc, dout, _ = run_variant(BASE)
check(drc == 0 and re.search(r"--max-hours 12 \(DEFAULTED", dout) is not None,
      "a DEFAULTED watchdog is named as such, not eaten silently")
check("RULING 80" in dout,
      "the defaulted case cites the ruling that forbids it on a real wave")

print("\n== 5. RULING 80 (甲2): priced by its OWN watchdog, not the spot constant ==")


def price_of(text):
    m = re.search(r"=\s*\$([0-9]+\.[0-9]{2})", text)
    return float(m.group(1)) if m else None


p2, p12 = price_of(out), price_of(dout)
check(p2 is not None and p12 is not None,
      "a fence-price line is printed in both cases (2h=%s, 12h=%s)" % (p2, p12))
# Each line rounds to cents independently, so a 6x comparison inherits up to
# 6*0.005 + 0.005 = 0.035 of rounding slack (0.673*2 -> 1.35, 0.673*12 -> 8.08,
# and 1.35*6 = 8.10).  The claim is proportionality, not bit-equality.
check(p2 is not None and p12 is not None and abs(p12 - p2 * 6) <= 0.04,
      "the price scales with the wave's own watchdog (12h is 6x the 2h wave, "
      "up to per-line cent rounding)")
check(p12 is not None and p12 > 1.10,
      "the defaulted wave prices ABOVE the $1.10 spot constant (%s) -- the "
      "under-recording RULING 80 was issued about" % p12)
check("NOT a forecast" in out and "1.10" in out,
      "the line disclaims itself: a watchdog cap, explicitly not the spot constant")

print("")
if failures:
    print("FAILED %d check(s):" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")
