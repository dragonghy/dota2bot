#!/usr/bin/env python3
"""Un-ruled queue requests -- the §BB.4 obligation, made mechanical.

WHY THIS EXISTS (2026-08-25T13:xxZ, director)
---------------------------------------------
`test_set.md` §BB.4 (legislated 2026-08-24T19:xxZ) says a rideshare admission
proposal -- one that declares "搭车 / 不申请专波 / 零 AWS 增量" -- must be
approved or returned **in the round it arrives**, because its only cost is
not being ruled.

The rule was written and then not enforced by its own author: by
2026-08-25T13:xxZ the un-ruled pile held `campsel` (proposed 08-23T23:3xZ),
`tbearly`, `tpgap`, `tpdeathbuy`, `zusstatic` and `pulldrag` -- i.e. every
single proposal that arrived after §BB.4 was written.  Nothing was broken;
nobody was told.  The 待裁区 of `test_set.md` is prose, and prose does not
raise its hand.  This is the same shape as iron rule 10's founding case:
the detector that would have caught it did not exist, so the work rebuilt
itself by hand.

WHAT IT REPORTS
---------------
Requests in `iterations/queue.json` that are still open (`status` in
`pending`/`running`/`harvested`) and carry no `director` ruling, split into
two buckets, because they need two different rulings:

  RIDESHARE  -- the request text declares it rides an existing wave at zero
                AWS increment.  §BB.4 applies: rule it this round.
  OTHER      -- everything else (archive scans, dedicated-wave asks).  These
                still need a routing/scheduling ruling, but §BB.4's
                same-round deadline is not what binds them.

LIMITS (read these before quoting the output)
---------------------------------------------
1. **It reports a problem, not a verdict.**  An un-ruled OTHER request may be
   legitimately parked behind a wave slot that does not exist yet
   (`RECEIVED_NOT_SCHEDULED` is a real ruling, and this tool cannot tell an
   un-ruled request from one whose ruling belongs to a future round).
2. **The RIDESHARE test is a text match** on the request's own declaration.
   A proposal that rides a wave without saying so reads as OTHER; a proposal
   that says so falsely reads as RIDESHARE.  Judge the quoted line.
3. **Age is best-effort and often unavailable.**  Routine containers clone
   shallow (50 commits at the time of writing), so a request introduced
   before the graft point has no first-appearance commit in this checkout.
   The honest output there is `age=unknown`, not a fabricated zero --
   backlog §6b's rule after the `busy-bardeen` misjudgement: when the
   evidence cannot separate two cases, say so rather than pick one.
4. It says nothing about whether a ruling is *correct*, only whether one
   exists in the machine-read field (`director`).  §BA.4 / §AW.1: a ruling
   that lives only in report prose is not delivered, and to this tool it is
   indistinguishable from no ruling at all -- which is the point.

Exit codes: 0 = no un-ruled RIDESHARE request; 3 = at least one (a finding,
not a failure).  OTHER-bucket entries never change the exit code.
"""

import argparse
import json
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
QUEUE = os.path.join(REPO, "iterations", "queue.json")

OPEN_STATES = ("pending", "running", "harvested")

# The declarations a rideshare proposal makes about itself.  Kept as literal
# substrings on purpose: these are the exact phrases the streams write, and a
# looser regex would start classifying dedicated-wave asks as rideshares.
RIDESHARE_MARKERS = (
    "搭车",
    "零 AWS 增量",
    "不申请专波",
    "不申请新波",
    "NO NEW WAVE NEEDED",
    "NO WAVE",
    "零 EC2",
)


def load_requests(path=QUEUE):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh).get("requests", [])


def is_open(req):
    return req.get("status") in OPEN_STATES


def is_unruled(req):
    """No machine-read ruling.  Absent field and null both count (§AW.1)."""
    return req.get("director") in (None, {}, "")


def is_rideshare(req):
    text = req.get("question", "") or ""
    return any(marker in text for marker in RIDESHARE_MARKERS)


def first_seen(req_id, path=QUEUE):
    """First commit in *this checkout* that introduced the request id.

    Returns an ISO date string, or None when the answer is not available --
    a shallow clone whose graft point is newer than the request, or a git
    that refuses to run at all.  LIMIT 3: None means unknown, never zero.
    """
    needle = '"id": "%s"' % req_id
    try:
        out = subprocess.run(
            ["git", "-C", REPO, "log", "--format=%aI", "-S", needle, "--", path],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    lines = [ln for ln in out.stdout.splitlines() if ln.strip()]
    return lines[-1] if lines else None


def partition(requests):
    """Open+un-ruled requests, split into (rideshare, other).

    The two buckets are disjoint and together hold every open un-ruled
    request -- asserted by tests/test_pending_rulings.py, because a guard
    that silently drops a bucket is worse than no guard.
    """
    open_unruled = [r for r in requests if is_open(r) and is_unruled(r)]
    ride = [r for r in open_unruled if is_rideshare(r)]
    other = [r for r in open_unruled if not is_rideshare(r)]
    return ride, other


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--queue", default=QUEUE)
    ap.add_argument("--no-age", action="store_true",
                    help="skip the git first-appearance lookup (faster)")
    args = ap.parse_args()

    requests = load_requests(args.queue)
    ride, other = partition(requests)

    def render(bucket, title):
        if not bucket:
            print("%s: none" % title)
            return
        print("%s: %d" % (title, len(bucket)))
        for r in bucket:
            age = "unknown" if args.no_age else (first_seen(r["id"], args.queue) or "unknown")
            print("  %-12s status=%-9s prio=%s bundle=%-24s first_seen=%s"
                  % (r.get("id"), r.get("status"), r.get("priority"),
                     r.get("bundle") or "-", age))

    print("=== un-ruled queue requests (director field empty) ===")
    render(ride, "RIDESHARE (§BB.4: rule this round)")
    render(other, "OTHER (routing/slot ruling still owed)")
    print("total open requests: %d" % sum(1 for r in requests if is_open(r)))
    return 3 if ride else 0


if __name__ == "__main__":
    sys.exit(main())
