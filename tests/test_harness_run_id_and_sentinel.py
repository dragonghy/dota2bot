#!/usr/bin/env python3
"""Ratchets for the two harness fixes ruled on 2026-08-22 ([harness] #98, #102).

Both fixes protect against the same *shape* of failure -- not a crash, but a
silently smaller/wrong corpus that every consumer reads as normal:

  #98  Two spot_run.sh calls in the same second used to produce the SAME
       run_id, so two instances share one s3://.../soak/<run_id>/ prefix.
       Same-second game basenames then collide (21 such pairs already exist
       bucket-wide, harmless today only because they sit under different
       prefixes), S3 last-write-wins drops games, and -- worse -- the two
       seeds merge, so recover_verdict.py's per-seed pairing starts answering
       with the other seed's games.  Every documented workaround ("download
       per run, then merge") is structurally void there: nothing is left to
       separate by.

  #102 A sweep_run.sh that dies mid-loop leaves a directory byte-for-byte
       indistinguishable from a complete one, because every consumer reads
       only games_manifest.jsonl and that file is appended per game.  It
       silently took capmono's arm A from 16 games to 13 while the headline
       statistic moved +0.011 -> +0.018.

What this file does and does NOT cover, stated up front:
  * #98 is covered BEHAVIOURALLY -- the script is actually run (--dry-run,
    no AWS call, nothing launched) and its output asserted.
  * #102's atomic install is covered BEHAVIOURALLY -- the rename semantics
    the fix rests on are exercised against a real running executable.
  * #102's sentinel ordering is covered STRUCTURALLY (source assertions).
    End-to-end sweep_run.sh needs AWS creds + the dumper binary, so the
    consumer-side half ("refuse a directory with no sentinel, cross-check
    swept against the manifest line count") is replay-check's acceptance,
    per #102 section 5 -- it is NOT claimed here.

Run:  python3 tests/test_harness_run_id_and_sentinel.py
      (or via tests/run_py_tests.sh)
"""

import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPOT_RUN = os.path.join(REPO, "tools/batch_test/aws/spot_run.sh")
SWEEP_RUN = os.path.join(REPO, "tools/batch_test/behavioral/sweep_run.sh")
GET_DUMPER = os.path.join(REPO, "tools/batch_test/behavioral/get_dumper.sh")

checks = 0
failures = []


def check(cond, label, detail=""):
    global checks
    checks += 1
    if cond:
        print("  ok   %s" % label)
    else:
        print("  FAIL %s%s" % (label, ("  -- " + detail) if detail else ""))
        failures.append(label)


# ---------------------------------------------------------------- #98 --------
# The dangerous topology is the batch desk's standing 4x1: four SEPARATE
# COUNT=1 invocations, so `n` is 1 in all four and only STAMP separates them.
# Reproduce exactly that, then assert uniqueness does not depend on the clock.

def spot_dry_run_ids(n_calls=4):
    ids = []
    for _ in range(n_calls):
        out = subprocess.run(
            ["bash", SPOT_RUN, "--dry-run", "--count", "1", "--ref", "main"],
            cwd=os.path.dirname(SPOT_RUN),
            capture_output=True, text=True,
        )
        if out.returncode != 0:
            raise RuntimeError("spot_run.sh --dry-run failed: %s" % out.stderr[-500:])
        found = re.findall(r"run_id=(\S+)", out.stdout)
        if len(found) != 1:
            raise RuntimeError("expected 1 run_id per COUNT=1 call, got %r" % found)
        ids.append(found[0])
    return ids


print("[#98] run_id uniqueness does not rest on 1-second STAMP resolution")
ids = spot_dry_run_ids(4)
for i in ids:
    print("       %s" % i)

check(len(set(ids)) == 4,
      "four separate COUNT=1 calls yield four distinct run_ids",
      "got %d distinct: %r" % (len(set(ids)), ids))

# Precondition of the bug: all four are n=1.  If this ever stops holding the
# test above would pass for the wrong reason.
check(all(re.search(r"_1_", i) for i in ids),
      "all four run_ids are n=1 (the topology that made STAMP load-bearing)")

# The clock-independence claim itself, asserted deterministically rather than
# by hoping the four calls land in one second: the per-invocation token must
# differ across calls.  If it did not, two same-second calls WOULD collide.
tokens = [i.rsplit("_", 1)[-1] for i in ids]
check(len(set(tokens)) == 4,
      "the per-invocation token differs on every call (clock-independent)",
      "tokens=%r" % tokens)
check(all(re.fullmatch(r"[0-9a-f]{6}", t) for t in tokens),
      "token is 6 hex chars (16.7M values; ~4e-7 birthday odds per 4x1 wave)",
      "tokens=%r" % tokens)

# Archived run_ids and every existing prefix glob must keep working: the token
# is APPENDED, so the historical `spot_<date>_<time>_<n>_<ref>` head is intact.
check(all(re.fullmatch(r"spot_\d{8}_\d{6}_1_main_[0-9a-f]{6}", i) for i in ids),
      "shape stays spot_<date>_<time>_<n>_<ref>_<token> (old prefix globs literal)",
      "got %r" % ids)


# --------------------------------------------------------------- #102 --------
print("\n[#102] sweep completion sentinel: written last, only on success")
sweep_src = open(SWEEP_RUN).read()

check("sweep_complete.json" in sweep_src,
      "sweep_run.sh writes a sweep_complete.json sentinel")

# Ordering is the whole point: a sentinel written before the work, or left over
# from a previous complete run, certifies nothing.
i_clear = sweep_src.find('rm -f "$OUT/sweep_complete.json"')
i_loop = sweep_src.find("for dem in")
i_summary = sweep_src.find('"sweep_summary.md"), "w"')   # where the summary is written
i_write = sweep_src.find('"sweep_complete.json"), "w"')  # where the sentinel is written
check(i_summary != -1 and i_write != -1,
      "both writers located in source (anchors still match)",
      "i_summary=%d i_write=%d" % (i_summary, i_write))

check(i_clear != -1 and i_loop != -1 and i_clear < i_loop,
      "a stale sentinel is cleared BEFORE the per-game loop starts appending")
check(i_write != -1 and i_summary != -1 and i_write > i_summary,
      "the sentinel is written AFTER the summary (i.e. last on the success path)")

# The sentinel must carry dem_found -- without it "swept all 4" and "found 5,
# swept 4" are the same file, which is precisely why sweep_summary.md could
# never serve as the sentinel.
for field in ("dem_found", "swept", "skipped", "exit_code", "s3_prefix"):
    check('"%s"' % field in sweep_src,
          "sentinel carries %s" % field)


print("\n[#102] atomic install: a running dumper is never overwritten in place")
dumper_src = open(GET_DUMPER).read()

check("flock" in dumper_src,
      "get_dumper.sh serialises concurrent acquires with flock (build-vs-build)")
check(dumper_src.count('mv -f "$STAGE" "$BIN"') == 2,
      "BOTH paths (cache hit and local build) install via atomic rename",
      "found %d" % dumper_src.count('mv -f "$STAGE" "$BIN"'))
# The invariant that keeps the fix in place: nothing may land on $BIN directly.
check('go build -o "$BIN"' not in dumper_src and 'cp "$S3_URI" "$BIN"' not in dumper_src,
      "nothing writes to $BIN directly any more (only the rename does)")

# Now the mechanism the fix rests on, exercised for real, as an A/B against
# the overwrite it replaced.  The property that matters is INODE PINNING:
# rename(2) detaches the old inode from the name instead of modifying it, so a
# consumer that already opened/exec'd it keeps a complete file, and no reader
# ever observes a half-written one at that path.  An in-place overwrite gives
# neither guarantee -- which is how a sweep caught "Permission denied" (or
# could have caught a truncated binary) mid-loop and died under set -e.
#
# NOTE ON METHOD: an earlier draft of this test tried to show it by leaving
# `sh <script>` running across the swap.  That proves nothing -- sh re-opens
# the path and had not necessarily read it yet, so it printed the NEW content
# and the check "failed" for a reason unrelated to rename semantics.  Holding
# an explicit fd is the deterministic form of the same question.
tmp = tempfile.mkdtemp(prefix="dumper_atomic_")
try:
    binp = os.path.join(tmp, "behav-dump")
    with open(binp, "w") as f:
        f.write("#!/bin/sh\necho v1\n")
    os.chmod(binp, os.stat(binp).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    # (A) the fix: stage + rename, with a consumer holding the old file open
    #     exactly as an in-flight exec holds its image.
    holder = open(binp, "rb")
    stage = os.path.join(tmp, ".behav-dump.stage")
    with open(stage, "w") as f:
        f.write("#!/bin/sh\necho v2\n")
    os.chmod(stage, os.stat(stage).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    os.replace(stage, binp)          # same syscall as `mv -f` within one filesystem

    held = holder.read()
    holder.close()
    check(held == b"#!/bin/sh\necho v1\n",
          "rename: a consumer holding the old binary still reads it COMPLETE",
          "got %r" % held)

    fresh = subprocess.run([binp], capture_output=True, text=True)
    check(fresh.returncode == 0 and fresh.stdout.strip() == "v2",
          "rename: a new exec afterwards gets the complete NEW binary",
          "got %r rc=%s" % (fresh.stdout, fresh.returncode))

    check(not os.path.exists(stage),
          "rename: the staging file is consumed (no debris left behind)")

    # (B) the control -- what the code did before.  Writing in place mutates
    #     the very inode the consumer is holding: it observes a file that is
    #     neither the old one nor (mid-write) a complete one.
    ctl = os.path.join(tmp, "ctl-dump")
    with open(ctl, "w") as f:
        f.write("#!/bin/sh\necho v1\n")
    holder2 = open(ctl, "rb")
    with open(ctl, "w") as f:        # truncate-in-place, as cp/`go build -o` do
        f.write("#!/bin/sh\necho ")  # <- caught here, mid-write: a partial file
    seen = holder2.read()
    holder2.close()
    check(seen != b"#!/bin/sh\necho v1\n",
          "control: in-place overwrite DOES disturb a holder (fix is not a no-op)",
          "holder still saw the old bytes -- the A/B proves nothing")
    check(seen == b"#!/bin/sh\necho ",
          "control: the holder observes the PARTIAL file (the #102 failure mode)",
          "got %r" % seen)
finally:
    shutil.rmtree(tmp, ignore_errors=True)


print("\n%d checks, %d failures" % (checks, len(failures)))
if failures:
    for f in failures:
        print("  failed: %s" % f)
    sys.exit(1)
sys.exit(0)
