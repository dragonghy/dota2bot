#!/usr/bin/env python3
"""Gate (i) -- the >=6h routine-wave throttle -- must refuse, and must refuse
LOUDLY when it cannot read its own anchor.

Companion to `tools/batch_test/soak/wave_throttle.py`; director ruling on
GH #469 (乙), 2026-09-04.  The tool's docstring carries the filing story.  This
file pins the three properties that decide whether it is a gate or a decoration:

  1. IT SAYS NO.  The founding case is rebuilt from W43's and W44's real
     timestamps and must come back exit 3.  A gate that cannot reproduce the
     breach it was filed for is not enforcing anything.

  2. AN UNREADABLE ANCHOR IS NOT AN UNLOCKED ONE.  Every way the anchor can go
     missing -- no `launched_at`, a bare time of day with no date (the real
     W26/W27 shape), unparseable JSON, no records at all -- must exit 2, the
     could-not-run code, and must NOT exit 0.  This is the property the whole
     repo keeps paying for the absence of (#205's uninstallable linter, #213's
     push gate that could not run, `describe-instances` answering `[]`): an
     absence read as good news.  Here the good news spends money.

  3. THE TWO RULINGS HOLD.  The anchor is the LAST machine up (ruling 1), and a
     `rerun` block opens no window while a `machines[]` slate does (ruling 2).
     Both are asserted against synthetic records built to disagree -- a slate
     whose spread straddles the deadline, and a record carrying a rerun and
     nothing else.

Exit 0 clean, 1 on a failed check.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "batch_test", "soak", "wave_throttle.py")

checks = 0
failures = []


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        failures.append(msg)


def run(waves_dir, *args):
    """Run the tool and return (exit code, combined output).

    Read with subprocess.run so the exit code is the tool's own -- no pipe
    between the command and the code (evidence discipline 3).
    """
    proc = subprocess.run(
        [sys.executable, TOOL, "--waves-dir", waves_dir] + list(args),
        capture_output=True, text=True,
    )
    return proc.returncode, proc.stdout + proc.stderr


def write_wave(waves_dir, wave, machines=None, extra=None):
    record = {"wave": wave}
    if machines is not None:
        record["machines"] = machines
    if extra:
        record.update(extra)
    with open(os.path.join(waves_dir, "%s_wave.json" % wave), "w",
              encoding="utf-8") as handle:
        json.dump(record, handle)


def slate(*stamps):
    return [{"seed": 1000 + i, "launched_at": s} for i, s in enumerate(stamps)]


tmp = tempfile.mkdtemp(prefix="wave_throttle_test_")
try:
    # ---------------------------------------------------------------- 1 -----
    # THE FOUNDING CASE.  W43's four real launch times, asked whether W44's
    # earliest real launch instant was allowed.  It was not.
    d = os.path.join(tmp, "founding")
    os.makedirs(d)
    write_wave(d, "W43", slate(
        "2026-09-03T18:21:58Z", "2026-09-03T18:22:40Z",
        "2026-09-03T18:22:59Z", "2026-09-03T18:23:04Z"))
    rc, out = run(d, "--now", "2026-09-04T00:18:45Z")
    check(rc == 3, "the founding case (W44's launch instant against W43's "
                   "slate) did not come back throttled: exit %d" % rc)
    check("THROTTLED" in out, "founding case did not print THROTTLED")
    # Under ruling 1 the breach is 4m19s, not the 3m13s the desk recorded off
    # the first machine.  Both numbers are real; the ruling picks one, and this
    # asserts the tool reports the ruled one rather than quietly averaging.
    check("4m19s" in out,
          "founding case did not measure the breach as 4m19s (ruling 1, "
          "anchored on the LAST machine); got:\n%s" % out)
    check("00:21:58Z" in out,
          "the other reading (first machine, unlock 00:21:58Z) was not printed "
          "-- the ruling must stay visible, not buried")

    # Six hours and one second later the same slate is clear.
    rc, out = run(d, "--now", "2026-09-04T00:23:05Z")
    check(rc == 0, "one second past unlock did not read as unlocked: %d" % rc)
    check("UNLOCKED" in out, "past-unlock run did not print UNLOCKED")
    # The boundary itself: >= unlock is unlocked, and the second before is not.
    rc_at, _ = run(d, "--now", "2026-09-04T00:23:04Z")
    rc_before, out_before = run(d, "--now", "2026-09-04T00:23:03Z")
    check(rc_at == 0, "exactly AT unlock did not pass (exit %d)" % rc_at)
    check(rc_before == 3, "one second BEFORE unlock passed (exit %d)" % rc_before)
    check("1s SHORT" in out_before,
          "a one-second breach was not reported in seconds; a gate that rounds "
          "cannot distinguish 1s from 3 minutes:\n%s" % out_before)

    # ---------------------------------------------------------------- 2 -----
    # RULING 1: the anchor is the LAST machine.  This slate is built so the two
    # readings disagree about this very instant.
    d = os.path.join(tmp, "ruling1")
    os.makedirs(d)
    write_wave(d, "W50", slate("2026-09-01T00:00:00Z", "2026-09-01T00:10:00Z"))
    rc, out = run(d, "--now", "2026-09-01T06:05:00Z")
    check(rc == 3,
          "anchored on the FIRST machine (unlock 06:00) instead of the LAST "
          "(06:10): a launch at 06:05 was let through, exit %d" % rc)
    check("slate spread     : 600s" in out,
          "the slate spread was not reported, so the size of the disagreement "
          "between the two readings is invisible:\n%s" % out)

    # ---------------------------------------------------------------- 3 -----
    # RULING 2: a rerun opens no window; a machines[] slate does.  The rerun
    # record here is the LATER one and carries a launch that, if honoured,
    # would throttle this instant.  It must be walked past -- and said so.
    d = os.path.join(tmp, "ruling2")
    os.makedirs(d)
    write_wave(d, "W60", slate("2026-09-01T00:00:00Z"))
    write_wave(d, "W61", machines=[], extra={
        "rerun": {"why": "one seed re-flown into W60",
                  "launched_at": "2026-09-01T05:00:00Z"}})
    rc, out = run(d, "--now", "2026-09-01T06:00:01Z")
    check(rc == 0,
          "a registered repair machine opened a new throttle window (ruling 2 "
          "says it does not): exit %d\n%s" % (rc, out))
    check("W60" in out, "the anchor was not W60")
    check("skipped W61" in out,
          "the walk-back past W61 was silent; a walk-back that changes the "
          "answer must be visible:\n%s" % out)

    # ---------------------------------------------------------------- 4 -----
    # AN UNREADABLE ANCHOR IS NOT AN UNLOCKED ONE.  Four shapes, all exit 2.
    cases = []

    d = os.path.join(tmp, "no_stamp")
    os.makedirs(d)
    write_wave(d, "W70", [{"seed": 1}, {"seed": 2}])
    cases.append(("a machine with no launched_at", d))

    d = os.path.join(tmp, "bare_time")
    os.makedirs(d)
    # The real W26/W27 shape: a time of day with no date.  Guessing a date here
    # is how a check invents an anchor.
    write_wave(d, "W71", slate("18:17:02Z", "18:17:13Z"))
    cases.append(("a bare time of day (the real W26/W27 shape)", d))

    d = os.path.join(tmp, "bad_json")
    os.makedirs(d)
    with open(os.path.join(d, "W72_wave.json"), "w", encoding="utf-8") as fh:
        fh.write("{not json")
    cases.append(("a wave record that is not JSON", d))

    d = os.path.join(tmp, "empty_dir")
    os.makedirs(d)
    cases.append(("a directory with no wave records at all", d))

    cases.append(("a waves dir that does not exist",
                  os.path.join(tmp, "nope")))

    d = os.path.join(tmp, "all_empty")
    os.makedirs(d)
    write_wave(d, "W73", machines=[])
    write_wave(d, "W74", machines=[])
    cases.append(("every record present but none with a slate", d))

    for label, path in cases:
        rc, out = run(path, "--now", "2026-09-04T00:00:00Z")
        check(rc == 2, "%s did not read as UNCERTIFIABLE: exit %d\n%s"
                       % (label, rc, out))
        check(rc != 0, "%s READ AS UNLOCKED -- an absence spending money" % label)
        check("UNCERTIFIABLE" in out,
              "%s did not print UNCERTIFIABLE:\n%s" % (label, out))
        check("not a pass" in out,
              "%s did not say in words that this is not a pass" % label)

    # A malformed --now is the same family: the tool must not fall back to the
    # real clock (which on a fast machine would silently answer a different
    # question).
    d = os.path.join(tmp, "founding")
    rc, out = run(d, "--now", "18:17:02Z")
    check(rc == 2, "a bare-time --now did not read as UNCERTIFIABLE: %d" % rc)

    # ---------------------------------------------------------------- 5 -----
    # --exclude must actually move the anchor, and say that it did.
    d = os.path.join(tmp, "exclude")
    os.makedirs(d)
    write_wave(d, "W80", slate("2026-09-01T00:00:00Z"))
    write_wave(d, "W81", slate("2026-09-01T05:00:00Z"))
    rc_incl, _ = run(d, "--now", "2026-09-01T06:00:01Z")
    rc_excl, out_excl = run(d, "--now", "2026-09-01T06:00:01Z", "--exclude", "W81")
    check(rc_incl == 3, "W81 did not throttle when included (exit %d)" % rc_incl)
    check(rc_excl == 0, "--exclude W81 did not move the anchor to W80 (%d)" % rc_excl)
    check("excluded on the command line" in out_excl,
          "the exclusion was not named in the output")

    # ---------------------------------------------------------------- 6 -----
    # THE REAL TREE.  The live waves dir must produce a verdict, not a refusal:
    # if the desk's own records have drifted out of this parser's reach, that is
    # a finding here and not a discovery at launch time.
    real = os.path.join(REPO, "iterations", "reports", "batch-desk", "waves")
    rc, out = run(real, "--now", "2026-09-04T00:18:45Z", "--exclude", "W44")
    check(rc != 2,
          "the REAL waves dir is UNCERTIFIABLE -- gate (i) cannot read its own "
          "anchor on trunk:\n%s" % out)
    check(rc == 3,
          "the real W43 anchor did not throttle W44's launch instant (exit %d); "
          "this is the historical breach and it must stay reproducible:\n%s"
          % (rc, out))
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("%d checks, %d failed" % (checks, len(failures)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)
