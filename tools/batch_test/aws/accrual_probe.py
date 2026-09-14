#!/usr/bin/env python3
"""GH #779, director 2026-09-14T09:5xZ ruling 2: is a frozen MTD hiding money?

WHAT THIS ANSWERS.  `check_costs.sh` reads MTD from `budgets describe-budgets`
for free, and that figure carries its own clock (`LastUpdatedTime`).  When that
clock stops moving, the desk has repeatedly wanted to pay $0.01 for a Cost
Explorer read to find out what the frozen number is hiding.  GH #801 switched
that purchase off entirely once headroom can no longer fit the cheapest wave.
This probe is the one documented way back through that switch, and it opens
only when the freeze can actually be hiding something.

THE CRITERION, VERBATIM FROM THE RULING.  The $0.01 may be spent only when

    the `budget refreshed` stamp is FROZEN
      AND ( (alpha) the live census reads NON-ZERO
            OR (beta) a wave record falls inside the 11.3h lag window )

and when (alpha) and (beta) are BOTH zero the frozen stamp opens no blind spot,
so nothing is bought.  That last clause is the point of the whole thing: a
stopped clock over an idle account is not evidence of hidden spend, it is just
a stopped clock.

WHY IT IS NOT KEYED ON HOW LONG THE FREEZE HAS LASTED.  The obvious criterion
-- "frozen for >= N hours" -- is the one the ruling forbids in as many words,
and the reason is that the desk measured freeze duration for four rounds and
then had to withdraw the whole series: the readings were real but the USE was
wrong, because freeze duration is not a hazard, it is a symptom whose
correlation with hazard is unknown.  Keying the purchase on it would put a
withdrawn quantity in a trigger position.  So "frozen" here is a COMPARISON --
this run's stamp against the last stamp this probe saw -- and never a duration.

WHY THE WINDOW IS NOT RE-TYPED HERE.  `ACCRUAL_LAG_MAX_HOURS = 11.3` and the
account-wide census both live in `wave_fence.py`, which is gate (iii) itself.
Importing them means there is ONE definition of "could this have accrued
without landing in MTD yet" in the repo.  A second copy here would drift, and
it would drift silently in the direction of the cheaper answer.

FAIL DIRECTION, ON PURPOSE.  An unreadable census exits 2 and the caller PAYS.
This matches `check_costs.sh`'s existing discipline for an unreadable brake:
an instrument that cannot be read must never be able to SILENCE the check.  The
cost of a wrong "pay" is $0.01; the cost of a wrong "skip" is launching on an
MTD that was hiding a wave.

A FRESH CONTAINER HAS NO PRIOR STAMP, and every routine session is a fresh
container.  Unknown is therefore treated as frozen -- but only ever inside the
(alpha)/(beta) branch, which is to say only when something really is accruing.
When the account is idle the both-zero clause answers first and the stamp is
never consulted at all, so a fresh container does not pay for its own freshness.

Exit codes:
  0  BYPASS   -- the freeze can be hiding money; the caller should pay the $0.01
  1  NO BYPASS-- documented, printed, and not a failure
  2  UNCERTIFIABLE -- an instrument could not be read; the caller pays
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOAK = os.path.normpath(os.path.join(HERE, "..", "soak"))


def _load_wave_fence(src=None):
    sys.path.insert(0, src or SOAK)
    import wave_fence  # noqa: E402
    return wave_fence


def coerce_stamp(text):
    """`--snapshot` arrives as a CLI string; epoch must survive that trip.

    GH #692 was exactly this shape one layer in: `parse_snapshot_instant`
    accepts an epoch as int/float but not as the string a CLI hands it, and
    the AWS CLI serializes `LastUpdatedTime` as a float epoch.  Left uncoerced
    the parse fails, the window silently re-anchors on `now`, and the failure
    is the PERMISSIVE one -- which is why this returns the number, and why the
    caller treats an unparseable clock as uncertifiable rather than as zero.
    """
    try:
        return float(text)
    except (TypeError, ValueError):
        return text


def read_stamp_state(path):
    """The previous stamp this probe recorded, or None when there is none."""
    try:
        with open(path) as f:
            return f.read().strip() or None
    except (IOError, OSError):
        return None


def write_stamp_state(path, stamp):
    """Record this run's stamp.  Best effort: a cache that cannot be written
    degrades to "unknown", which is the paying direction, never the silent one.
    """
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(str(stamp))
        return True
    except (IOError, OSError):
        return False


def decide(frozen, n_accruing, wave_rows):
    """Pure: the ruling's conjunction, and nothing else.

    Returns (bypass, reason).  `frozen` may be None for "no prior stamp".
    """
    blind_spot = bool(n_accruing) or bool(wave_rows)
    if not blind_spot:
        return False, ("alpha and beta are both zero -- a frozen stamp over an "
                       "idle account opens no blind spot")
    if frozen is False:
        return False, ("the stamp MOVED this run, so the MTD figure is not the "
                       "frozen one the ruling's first conjunct is about")
    if frozen is None:
        return True, ("no prior stamp on this container, treated as frozen "
                      "(the paying direction) because alpha/beta are non-zero")
    return True, "the stamp is frozen AND alpha/beta is non-zero"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--snapshot", required=True,
                    help="the budget LastUpdatedTime check_costs.sh just read "
                         "(epoch or ISO-8601); this probe does not re-read the "
                         "budget, so it cannot disagree with its caller")
    ap.add_argument("--state", required=True,
                    help="where the previous stamp was recorded")
    ap.add_argument("--waves-dir", default=None)
    ap.add_argument("--fence-src", default=None,
                    help="test seam: where to import wave_fence from")
    args = ap.parse_args(argv)

    try:
        wf = _load_wave_fence(args.fence_src)
    except Exception as exc:                                # pragma: no cover
        print("   accrual probe: UNCERTIFIABLE -- wave_fence unreadable (%s)"
              % str(exc)[:120])
        return 2

    waves_dir = args.waves_dir
    if waves_dir is None:
        import wave_throttle
        waves_dir = wave_throttle.DEFAULT_WAVES_DIR

    # (beta) -- the 11.3h lag window, anchored on the budget's own clock.
    # This is wave_fence's function, so the window here IS gate (iii)'s window.
    accrual = wf.read_wave_accrual(waves_dir, coerce_stamp(args.snapshot))
    wave_rows = accrual["rows"]
    if accrual.get("clock_degraded"):
        # Ruling 7's shape: a window anchored on `now` instead of the snapshot
        # is the PERMISSIVE one (waves drop out by construction), so it must
        # not be allowed to produce a quiet "nothing accruing".
        print("   accrual probe: UNCERTIFIABLE -- the snapshot clock could not "
              "be parsed, so the 11.3h window would be anchored on `now`")
        return 2

    # (alpha) -- the live census.  No tag filter, never priced, account-wide.
    try:
        rows, scope = wf.read_accruing_instances()
    except Exception as exc:
        print("   accrual probe: UNCERTIFIABLE -- the accruing-instance census "
              "could not be read (%s)" % str(exc)[:120])
        print("   paying anyway: an unreadable instrument must never SILENCE "
              "the confirmation.")
        return 2

    # Ruling 5's distinction, applied to a PURCHASE decision: "zero accruing"
    # and "zero accruing IN THE REGIONS WE COULD READ" are different
    # propositions, and `read_accruing_instances` returns the second one with
    # no exception -- a census that failed in every region comes back as an
    # empty list, which would walk straight into the both-zero clause and buy
    # nothing. That is the dangerous direction, so an incomplete scope with
    # nothing found is uncertifiable, not zero.
    if not rows and not scope.get("complete"):
        print("   accrual probe: UNCERTIFIABLE -- census found nothing, but "
              "scope is INCOMPLETE (%s)" % str(scope.get("why"))[:140])
        print("   'zero within scope' is not 'zero'; paying rather than "
              "reading an unread region as an idle one.")
        return 2

    prev = read_stamp_state(args.state)
    frozen = None if prev is None else (prev == str(args.snapshot))
    bypass, reason = decide(frozen, len(rows), wave_rows)
    write_stamp_state(args.state, args.snapshot)

    print("   accrual probe (GH #779): alpha = %d accruing instance(s) %s; "
          "beta = %d wave record(s) after %s"
          % (len(rows),
             "account-wide" if scope.get("complete") else "WITHIN SCOPE ONLY",
             len(wave_rows),
             accrual["cutoff"].strftime("%Y-%m-%dT%H:%M:%SZ")))
    print("   stamp %s -- %s" % (
        {True: "FROZEN", False: "moved", None: "unknown (fresh container)"}[frozen],
        reason))
    return 0 if bypass else 1


if __name__ == "__main__":
    sys.exit(main())
