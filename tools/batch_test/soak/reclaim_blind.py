#!/usr/bin/env python3
"""Decide whether the wave just harvested was RECLAIM-BLINDED, and therefore
whether the NEXT wave escalates off spot.

Why this exists (director ruling on GH #271, 2026-08-28)
--------------------------------------------------------
The batch desk's degradation ladder (batch-desk.md §5) escalates on
`InsufficientInstanceCapacity`, which is a LAUNCH-TIME error.  The dominant
failure mode for seven waves running was not that: `run-instances` returned
fine, `InstanceLifecycle=spot` checked out, and the machine was then taken
away MID-FLIGHT with `instance-terminated-no-capacity`.  So the ladder's
only path to `--on-demand` was structurally unreachable, and owner GH #158's
"除非没有 spot 的机器" had no observable form.  This file is that form.

The loss is a STEP, not a proportion.  A wave machine runs seed S twice --
first the `ab` leg, then the `ba` leg -- and `mirror_ab.sh` flips legs by
writing one file (`bots/Customize/soak_side.lua`) over SSM after the ab leg
has banked TARGET games.  A machine reclaimed before that flip yields a pure
single-leg orphan whose `arm_depth` is 0.0, no matter how long it lived:

    W19-R  16.8 min -> ab26/ba0  NO-PAIR
    W19-R  34.8 min -> ab10/ba0  NO-PAIR     <- lived 2x as long, bought the same
    W20    30.8 min -> ab26/ba0  NO-PAIR
    W21    42.6 min -> ab30/ba12 paired      <- 8 more minutes, 1 whole seed

What the trigger is, and why it is not "count the reclaims"
-----------------------------------------------------------
A wave is BLINDED iff BOTH:

  (1) it yielded <= 1 paired seed, and
  (2) at least one machine was reclaimed (`instance-terminated-no-capacity`)
      before the changeover point.

Clause (1) is the yield, and clause (2) is the ATTRIBUTION.  Both are load
bearing and each one alone misclassifies the measured history:

    wave    machines  reclaimed  paired   yield<=1?  reclaim?   verdict
    W17        4          4        0        yes        yes      BLINDED
    W17-R      4          4        0        yes        yes      BLINDED
    W18        4          2        2        no         yes      ok
    W19        4          3        1        yes        yes      BLINDED
    W19-R      3          3        0        yes        yes      BLINDED
    W20        4          1        3        no         yes      ok
    W21        4          0        4        no         no       ok
    W24        4          0        4        no         no       ok
    W25        4          0        4        no         no       ok
    W28        4          0        4        no         no       ok   <- see below

W24/W25 were added 2026-08-30 by the director while ruling GH #332.  They are
first-hand SIR rows (`create` + `update` read while the requests were still
alive) and they MOVED THE BRACKET: W24 seed 1633 paired after 40.63 min, which
is 1.97 min shorter than the W21 survivor the upper edge used to quote.  The
bracket has been (34.8, 40.63] since 2026-08-29 and nobody noticed, because
this file's history table stopped at W21.  40.0 still sits inside it -- the
constant is NOT refuted -- but the margin to the upper edge is 0.63 min, not
2.6 min.  The next paired machine that lands under 40.0 refutes it for real.

"Count the reclaims >= 2" would have fired on W18, a wave that delivered half
its seeds.  Clause (2) is the more important of the two: without it a wave
that bought nothing for a reason on-demand CANNOT FIX (a harness bug, a bad
seed set, an AMI that will not boot) escalates to a ~3x more expensive
instrument aimed at a problem it does not treat.  Do not drop it to "simplify".

Why <= 1 and not = 0: `mirror_multi.sh`'s own file header says a single seed
is a per-comp reading and not the population mean, so a one-seed wave is not
a wave-level answer either -- it is an orphan with better paperwork.

The changeover constant is BRACKETED, not chosen
------------------------------------------------
Longest orphan observed: 34.8 min (W19-R).  Shortest paired survivor: 40.63
min (W24 seed 1633, ab27/ba13, arm_depth 17.55, first-hand SIR
06:18:41Z -> 06:59:19Z).  Every value in (34.8, 40.63] classifies all 35
machines observed so far identically; 40 sits inside that bracket.  The number is
therefore a reading, not a preference -- and readings expire.  So this file
re-checks the bracket against its own input on every run: a reclaimed machine
that lived PAST the threshold and still came back unpaired, or a paired seed
from a machine that died BEFORE it, means the flip point has moved.  That is
`BRACKET VIOLATED` and exit 2 -- re-derive the constant -- and not a quiet
answer computed with a number the data just contradicted.  Same stance as
GH #267 test 6: a gauge is not allowed to disagree with itself in silence.

Exit codes (the 0/1/2 vocabulary of GH #171 / #205 / #213)
----------------------------------------------------------
  0  NOT BLINDED   -- next wave launches spot, as always.  GH #158 unchanged.
  1  BLINDED       -- next wave launches `--on-demand`, ONE wave, then reverts.
  2  could-not-run -- a self-contradicting record, an unread field that CHANGES
                      the answer, or a violated bracket.  Nothing was decided;
                      this is not a pass.

There is no persisted state: the answer is a function of the previous wave's
own harvest, which the desk already computes.  One-shot by construction --
an on-demand wave cannot satisfy clause (2), so it always hands the next wave
back to spot.

An unread field is not automatically a refusal (GH #699)
--------------------------------------------------------
Added 2026-09-10 by the director.  Until today every unreadable field took the
whole wave to exit 2 from inside the per-machine parse loop, BEFORE a single
clause was evaluated.  On W62 that closed the farm:

  1. this gate's own prescription when a wave is BLINDED is "next wave
     on-demand" (see clause (2) and the verdict lines below);
  2. an on-demand machine has no spot request, so the only code its record can
     carry is EC2's `StateReason.Code` -- which is read from
     `describe-instances`, where a terminated instance ages out in ~1h
     (GH #375) while the wave rhythm puts harvest ~3h after launch;
  3. so an on-demand wave's rows arrive at harvest with `status_code: null`,
     permanently: W62's four rows each carry a `status_code_unrecoverable`
     block, both first-hand sources (`describe-instances`, `cloudtrail
     lookup-events`) having been spent;
  4. the gate reads only `--wave-json` and only the PREVIOUS wave, with no
     persisted state and no bypass flag;
  5. making the previous wave be something other than W62 requires launching a
     wave, and launching a wave requires this gate to return 0.

(1)-(5) close on themselves.  This is an ABSORBING STATE, not an expiry: the
reading does not change when the month rolls over, because what it reads is
neither money nor the calendar but a record that can never be completed.  The
gate that prescribes on-demand could not survive its own prescription.

The fix is NOT a bypass flag -- that would restore exactly the silent false
pass GH #661 closed.  It is this:

    A gate may not demand a datum its own answer does not depend on.

So an ABSENT field is now carried as a hole with a name (`Unread`) rather than
raised, and the verdict is computed at EVERY admissible value that hole could
take.  If they all agree, the field was immaterial and the agreed verdict is
returned with the hole disclosed by name.  If they disagree, it is exit 2 with
the same force as before -- and now with the reason stated as "this field
changes the answer", which is the true one.

Two properties keep the dangerous direction closed:

  * The exploration puts `instance-terminated-no-capacity` on every unread
    code, ON-DEMAND ROWS INCLUDED.  A spot machine mislabelled `on-demand`
    whose code was never read therefore cannot walk its reclaim out of the
    attribution clause: the adversarial extension is scored too, and if it
    flips the verdict the answer is exit 2.
  * Only ABSENCE defers.  A field that is PRESENT and wrong still refuses, at
    full force and by its old name: a SIR code on an on-demand row, spot's EC2
    spelling on an on-demand row, an EC2 code on a spot row (GH #412), a code
    outside the EC2 vocabulary on an on-demand row (GH #661), an unknown
    market or survival_bound, a non-numeric survival, an update that precedes
    its create.  Those are records that contradict themselves, and a
    contradiction is not a hole -- exploring it would be scoring a lie.

Why W62 comes out NOT BLINDED, and why that is a reading and not a shrug: its
yield is 4 paired seeds of 4 machines, so clause (1) (`yield <= 1`) is FALSE
before attribution is ever consulted, and `low_yield` is computed from ab/ba
and arm_depth -- fields that are present, and that stay mandatory.  The missing
code cannot reach the verdict from there.  The bracket gauge is a separate
matter: a row whose code or survival was not read is EXEMPT from it, disclosed
by name, on the same precedent that already exempts a lower-bound survival --
an unread field is strictly less informative than a lower bound, so the check
that a lower bound cannot support, a hole cannot support either.

Usage
-----
  reclaim_blind.py --wave-json wave.json          # or `-` for stdin
  reclaim_blind.py --wave-json - --changeover-min 40 --min-arm-depth 8

Input JSON:
  {"wave": "W21",
   "machines": [
     {"seed": 983, "status_code": "instance-terminated-by-user",
      "create": "2026-08-28T12:16:36Z", "update": "2026-08-28T13:01:33Z",
      "ab": 28, "ba": 14, "arm_depth": 18.67},
     ...]}

A refill machine bought under GH #408 carries its market and its EC2 code:

     {"seed": 2745, "market": "on-demand",
      "status_code": "Client.UserInitiatedShutdown",
      "survival_min": 52.0, "ab": 27, "ba": 13, "arm_depth": 17.1},

`survival_min` may be given directly instead of create/update.  `arm_depth`
is optional: when present it is held to --min-arm-depth (default 8, matching
GH #269's MIN_ARM_DEPTH), when absent pairing falls back to ab>0 and ba>0 and
the per-machine line says so rather than pretending the depth was checked.

When the survival number is a PROXY, say so: `survival_bound`
--------------------------------------------------------------
Optional per-machine key, `"exact"` (default) or `"lower"`.  It exists because
the SIR record expires within hours while the wave's own S3 uploads do not, so
a wave read after the fact is scored on "time of last upload", which is a LOWER
BOUND on survival -- the machine still had to finish shutting down.  Measured
offset over the eight W24/W25 machines that have both readings: mean 2.90 min,
range 2.15-3.32.

A lower bound is not a weaker version of a measurement; it is sound in one
direction and unsound in the other, and this file's two clauses face opposite
ways:

  * "reclaimed PAST the flip yet unpaired" needs survival > T.  lb > T implies
    true > T, so this branch is SOUND on a lower bound and stays armed.
  * "paired BEFORE the flip" needs survival < T.  lb < T implies NOTHING about
    the true value, so this branch is UNSOUND on a lower bound and is skipped
    -- out loud, naming the machine, never silently.
  * the ATTRIBUTION clause ("reclaimed before the flip") also needs survival
    < T.  A reclaimed machine whose lower bound falls under the flip is
    therefore UNDECIDABLE -- exit 2, not a guess in either direction.  Guessing
    "before" invents a BLINDED; guessing "after" hides one.

GH #332 is the wave that forced this: W28's BRACKET VIOLATED was entirely an
artifact of substituting the proxy, and the substitution was invisible because
the field it was written into is named for a measurement.

A machine that is not on the spot market at all: `market`
---------------------------------------------------------
Added 2026-09-02 by the director ruling GH #408 (refill escalation).  That
ruling sends the REFILL machine -- and only it -- to `--on-demand` when the
seed it is replacing was lost to `instance-terminated-no-capacity`.  Such a
machine has no spot instance request, so it has no SIR `Status.Code` at all;
the only code its record can carry is EC2's `StateReason.Code`
(`Client.UserInitiatedShutdown` for a clean self-terminate).

Before this key existed, that row hit `unknown SIR status_code` and took the
WHOLE wave to exit 2 -- i.e. the ruling would have silently disabled the gate
that the same ruling reads.  Machines therefore declare their market:

  * `"market": "spot"` (the default, so every wave written before today reads
    unchanged): the code must be SIR vocabulary.
  * `"market": "on-demand"`: the code must NOT be SIR vocabulary -- an
    on-demand instance cannot be reclaimed for capacity, so a row claiming
    both is a record that contradicts itself, and that is exit 2 rather than
    a guess about which half is true.  It counts for YIELD like any other
    machine and can never satisfy the ATTRIBUTION clause.

The dangerous direction here is mislabelling a spot machine `on-demand`: its
reclaim would drop out of the attribution clause and hide a BLINDED wave.
The contradiction check above is what closes that direction -- a mislabelled
spot machine still carries `instance-terminated-*` and is refused by name.

Telling an EC2 code apart from a MIS-WRITTEN one (GH #412)
-----------------------------------------------------------
W36's harvest wrote `machines[].status_code` from `describe-instances`'
`StateReason.Code` instead of the SIR `Status.Code`, and this file answered
`UNDECIDABLE: unknown SIR status_code 'Server.SpotInstanceTermination'`.  It
did refuse -- but the sentence points at the market, and the round read it as
"the market could not be classified" when the truth was "we wrote the wrong
field".  A loud wrong answer costs what a quiet one costs.

So a `Server.*` / `Client.*` shaped code on a SPOT machine now names its own
cause and its own remedy, including the `sir_status_code` sibling key when
the record already carries it.  It stays exit 2: the fallback ("just read
`sir_status_code` when `status_code` is unreadable") is refused on purpose --
it converts a drifting write convention into a tolerated one, which is the
direction GH #412 was opened to prevent.
"""
import argparse
import datetime as _dt
import itertools as _itertools
import json
import sys

# SIR status codes this file knows how to read.  Anything else is UNKNOWN and
# forces exit 2 rather than being guessed into one of these buckets: guessing
# "probably a self-terminate" is exactly the direction that hides a reclaim.
SELF_TERMINATED = "instance-terminated-by-user"
RECLAIMED = "instance-terminated-no-capacity"
KNOWN_CODES = (SELF_TERMINATED, RECLAIMED)

DEFAULT_CHANGEOVER_MIN = 40.0
DEFAULT_MIN_ARM_DEPTH = 8.0

# How to read a machine's survival number.  EXACT is the SIR's own
# Status.UpdateTime; LOWER is a proxy that can only be too small (last S3
# upload).  Anything else is UNKNOWN and forces exit 2, same stance as an
# unknown status_code: a bound we cannot name is a bound we cannot honour.
BOUND_EXACT = "exact"
BOUND_LOWER = "lower"
KNOWN_BOUNDS = (BOUND_EXACT, BOUND_LOWER)

# Which market a machine was bought on (GH #408).  Absent means spot, so every
# wave recorded before 2026-09-02 reads exactly as it did.
MARKET_SPOT = "spot"
MARKET_ON_DEMAND = "on-demand"
KNOWN_MARKETS = (MARKET_SPOT, MARKET_ON_DEMAND)

# The shape of an EC2 `StateReason.Code` (`Server.SpotInstanceTermination`,
# `Client.UserInitiatedShutdown`).  On a spot row this is the GH #412 write-side
# drift, not an unknown market state -- see this file's header.
EC2_CODE_PREFIXES = ("Server.", "Client.")

# The EC2 `StateReason.Code` vocabulary an ON-DEMAND row may speak (GH #661).
# Until 2026-09-09 there was no vocabulary here at all: the on-demand branch
# refused a missing code and a SIR code, then returned ANY other string, so
# `"banana pancakes"` and `""` both certified as termination codes.  Paired with
# the fact that the field is structurally unreadable by harvest time (terminated
# instances age out of describe-instances in ~1h, GH #375, while the wave rhythm
# puts harvest ~3h after launch), that made the on-demand attribution clause
# unable to fail out loud: a reading that can never be taken, behind a check that
# can never refuse it.  The failure direction is the dangerous one -- "did not
# read" silently recorded as "read".
EC2_SELF_SHUTDOWN = "Client.InstanceInitiatedShutdown"   # `shutdown` from inside the box
EC2_USER_SHUTDOWN = "Client.UserInitiatedShutdown"       # TerminateInstances from outside
# Ways AWS itself ends an on-demand box.  None is a spot reclaim, so none can
# reach the attribution clause -- but each is a real thing the API says, and
# refusing a true reading is its own kind of lie.
EC2_SERVER_CODES = ("Server.InternalError", "Server.ScheduledStop")
KNOWN_EC2_CODES = (EC2_SELF_SHUTDOWN, EC2_USER_SHUTDOWN) + EC2_SERVER_CODES

# Spot's own EC2 spelling.  On an on-demand row this is the SAME
# self-contradiction the SIR refusal catches, only spelled in EC2 vocabulary --
# a mislabelled spot machine whose reclaim would otherwise walk out of the
# attribution clause.  Listed separately, and checked BEFORE the whitelist,
# because a blanket `Server.*` allowance would wave exactly this one through.
EC2_SPOT_ONLY_CODES = ("Server.SpotInstanceTermination", "Server.SpotInstanceShutdown")

# The measured bracket the default constant sits inside.  Printed every run so
# the next person can see what would narrow it.  Narrowed 2026-08-30 (GH #332):
# W24 seed 1633 is a first-hand paired survivor at 40.63 min, shorter than the
# W21 seed 995 reading (42.6) the upper edge used to quote.
BRACKET_LO = 34.8    # longest orphan observed (W19-R)
BRACKET_HI = 40.63   # shortest paired survivor observed (W24 seed 1633)

# The concrete readings an UNREAD field is scored at (GH #699).  Two per hole is
# exhaustive, not a sample: every clause in this file touches a code only
# through `== RECLAIMED` and a survival only through a comparison with
# `changeover_min`, so one representative on each side of each predicate covers
# every reading the field could have had.
#
# RECLAIMED is in this tuple for on-demand rows too, and that is the whole
# safety argument: the row asserts a market, and an unread code is exactly the
# state in which that assertion cannot be checked.  Scoring the adversarial
# value keeps a spot machine mislabelled `on-demand` from walking its reclaim
# out of the attribution clause -- the direction this file's `market` section
# calls the dangerous one.
_CODE_EXTENSIONS = (RECLAIMED, SELF_TERMINATED)

# Refuse rather than explore past this many points.  Reaching it means most of
# the wave was never read, which is a harvest to fix and not an answer to
# compute -- and an exploration too big to print is one nobody audits.
MAX_EXTENSION_POINTS = 4096


class Undecidable(Exception):
    """Raised when the input CONTRADICTS ITSELF.  Maps to exit 2, never to 0.

    Reserved for records that cannot be true as written -- a present value from
    the wrong vocabulary, an update before its create, an unknown market.  A
    merely ABSENT field is an `Unread`, not this: see GH #699 in the header.
    """


class Unread(object):
    """A field the record does not supply: a hole that knows its own name.

    Not a value and never comparable to one -- every predicate in this file is
    evaluated against the CONCRETE extensions of the hole, never against the
    hole itself, so a stray `row["code"] == RECLAIMED` on an unread row reads
    False for the same reason `None == RECLAIMED` does, rather than silently
    picking the benign side.
    """
    __slots__ = ("reason",)

    def __init__(self, reason):
        self.reason = reason

    def __repr__(self):
        return "<unread: %s>" % self.reason


def is_unread(value):
    return isinstance(value, Unread)


def _parse_ts(value, where):
    if not isinstance(value, str):
        raise Undecidable("%s: timestamp is not a string (%r)" % (where, value))
    text = value.strip().replace("Z", "+00:00")
    try:
        return _dt.datetime.fromisoformat(text)
    except ValueError:
        raise Undecidable("%s: unparseable timestamp %r" % (where, value))


def survival_minutes(machine, where):
    """Minutes the machine was alive, from an explicit field or create/update."""
    if "survival_min" in machine:
        try:
            return float(machine["survival_min"])
        except (TypeError, ValueError):
            raise Undecidable("%s: survival_min is not a number" % where)
    if "create" in machine and "update" in machine:
        start = _parse_ts(machine["create"], where)
        end = _parse_ts(machine["update"], where)
        delta = (end - start).total_seconds() / 60.0
        if delta < 0:
            raise Undecidable("%s: update precedes create" % where)
        return delta
    # ABSENT, not wrong: the record simply never said how long the machine
    # lived.  GH #699 -- carried as a hole and explored, not raised.  A PRESENT
    # survival that will not parse stays a refusal above, because a number that
    # is not a number is a contradiction rather than a gap.
    return Unread("%s: survival was not read (no survival_min, and not both "
                  "create and update)" % where)


def survival_bound(machine, where):
    """How the survival number may be used.  Absent means an exact reading."""
    bound = machine.get("survival_bound", BOUND_EXACT)
    if bound not in KNOWN_BOUNDS:
        raise Undecidable("%s: unknown survival_bound %r (known: %s)"
                          % (where, bound, ", ".join(KNOWN_BOUNDS)))
    return bound


def market_of(machine, where):
    """Which market the machine was bought on.  Absent means spot (GH #408)."""
    market = machine.get("market", MARKET_SPOT)
    if market not in KNOWN_MARKETS:
        raise Undecidable("%s: unknown market %r (known: %s)"
                          % (where, market, ", ".join(KNOWN_MARKETS)))
    return market


def read_status_code(machine, market, where):
    """The termination code, checked against the vocabulary its market uses.

    Spot rows speak SIR (`Status.Code`); on-demand rows have no SIR at all and
    can only speak EC2 (`StateReason.Code`).  Each vocabulary is refused in the
    other's row, and the EC2-shaped refusal on a spot row names the write site
    rather than the market (GH #412).
    """
    code = machine.get("status_code")

    if market == MARKET_ON_DEMAND:
        if code is None:
            # ABSENT, and on an on-demand row absent is the STRUCTURAL case, not
            # a slip: the code could only have come from `describe-instances`,
            # which ages a terminated instance out in ~1h (GH #375) against a
            # ~3h harvest.  Raising here is what closed the farm on W62 -- see
            # GH #699 in the header.  It becomes a hole, explored at
            # `instance-terminated-no-capacity` too, so a spot machine
            # mislabelled on-demand still cannot hide its reclaim.
            return Unread(
                "%s: market is on-demand and status_code is missing -- an "
                "on-demand row still has to say how the machine ended "
                "(EC2 StateReason.Code, e.g. Client.UserInitiatedShutdown)"
                % where)
        if code in KNOWN_CODES:
            raise Undecidable(
                "%s: market says on-demand but status_code %r is SIR "
                "vocabulary -- an on-demand instance has no spot request, so "
                "this record contradicts itself.  One of the two is wrong and "
                "this file will not pick: a mislabelled spot machine would "
                "drop its reclaim out of the attribution clause"
                % (where, code))
        if code in EC2_SPOT_ONLY_CODES:
            raise Undecidable(
                "%s: market says on-demand but status_code %r is spot's own EC2 "
                "spelling -- an on-demand instance has no spot request, so this "
                "record contradicts itself exactly as a SIR code would.  Same "
                "refusal, same reason: a mislabelled spot machine would drop its "
                "reclaim out of the attribution clause"
                % (where, code))
        if code not in KNOWN_EC2_CODES:
            raise Undecidable(
                "%s: unknown EC2 StateReason.Code %r on an on-demand row "
                "(known: %s).  This branch used to accept any string at all, so "
                "prose and the empty string both certified as termination codes "
                "(GH #661).  If the instance aged out of describe-instances "
                "before the harvest round could read it (GH #375), that is a "
                "MISSING reading and has to read as exit 2 -- do not write the "
                "explanation into this field, because a field that explains its "
                "own absence is indistinguishable from one that was read"
                % (where, code, ", ".join(KNOWN_EC2_CODES)))
        return code

    if code in KNOWN_CODES:
        return code
    if isinstance(code, str) and code.startswith(EC2_CODE_PREFIXES):
        hint = ("; this row already carries sir_status_code=%r, which is the "
                "correct source" % machine["sir_status_code"]
                if isinstance(machine.get("sir_status_code"), str)
                else "; re-read Status.Code from "
                     "describe-spot-instance-requests, or, if the request has "
                     "expired, from this record's own sir_status_code")

        raise Undecidable(
            "%s: status_code %r is an EC2 StateReason.Code, not a SIR "
            "Status.Code -- this is a WRITE-SIDE error in the harvesting "
            "round, not an unclassifiable market%s.  (If this machine really "
            "was on-demand, the row is missing \"market\": \"on-demand\".)"
            % (where, code, hint))
    if code is None:
        # ABSENT on a spot row.  Same treatment as the on-demand hole, and the
        # same safety: the exploration scores RECLAIMED, so a wave whose yield
        # is low cannot come back "not blinded" on a code nobody read -- the
        # extensions disagree there and that is exit 2.
        return Unread("%s: status_code is missing -- a spot row still has to "
                      "say how the machine ended (SIR Status.Code, one of: %s)"
                      % (where, ", ".join(KNOWN_CODES)))
    raise Undecidable("%s: unknown SIR status_code %r (known: %s)"
                      % (where, code, ", ".join(KNOWN_CODES)))


def classify_machine(machine, changeover_min, min_arm_depth, where):
    """One machine -> (survival, code, paired, depth_checked, bound, market)."""
    market = market_of(machine, where)
    code = read_status_code(machine, market, where)
    bound = survival_bound(machine, where)
    survival = survival_minutes(machine, where)

    for field in ("ab", "ba"):
        if field not in machine:
            raise Undecidable("%s: missing leg count %r" % (where, field))
        try:
            int(machine[field])
        except (TypeError, ValueError):
            raise Undecidable("%s: leg count %r is not an integer" % (where, field))
    ab, ba = int(machine["ab"]), int(machine["ba"])

    paired = ab > 0 and ba > 0
    depth_checked = False
    if paired and machine.get("arm_depth") is not None:
        try:
            depth = float(machine["arm_depth"])
        except (TypeError, ValueError):
            raise Undecidable("%s: arm_depth is not a number" % where)
        depth_checked = True
        if depth < min_arm_depth:
            paired = False
    return survival, code, paired, depth_checked, bound, market


def check_bracket(rows, changeover_min):
    """Both directions the changeover constant can go stale.

    Returns (violations, skipped).  An empty violations list = the constant
    still separates this input the way it separated the waves it was read off
    of.  `skipped` names every check an input made unsound, so a suppressed
    check is still a visible one -- a bracket check that quietly declines to
    run is the same shape of lie as a gate that prints nothing.

    Two things make a row unsound to gauge, and both are named out loud:
    a lower-bound survival (the original case), and an unread code or survival
    (GH #699).  The second follows from the first a fortiori -- a hole is
    strictly less informative than a lower bound -- and it is why this check is
    NOT re-run per extension point: gauging the constant against a value this
    file invented would be reading the invention back as evidence.
    """
    bad = []
    skipped = []
    for row in rows:
        seed, survival, code = row["seed"], row["survival"], row["code"]
        if is_unread(code) or is_unread(survival):
            what = ("code and survival were"
                    if is_unread(code) and is_unread(survival)
                    else ("status_code was" if is_unread(code)
                          else "survival was"))
            skipped.append("seed %s: %s not read, so neither direction of "
                           "the bracket can be gauged on this machine (a hole "
                           "supports strictly less than the lower bound that "
                           "already exempts a machine here)" % (seed, what))
            continue
        paired, bound = row["paired"], row["bound"]
        # Sound on a lower bound: lb > T implies the true survival > T.
        if code == RECLAIMED and survival > changeover_min and not paired:
            bad.append("seed %s: reclaimed at %.1f min (PAST the %.1f min flip) "
                       "yet unpaired -- the flip point moved later"
                       % (seed, survival, changeover_min))
        # Unsound on a lower bound: lb < T implies nothing about the true value.
        if paired and survival < changeover_min:
            if bound == BOUND_LOWER:
                skipped.append("seed %s: %.1f min is a LOWER BOUND below the "
                               "%.1f min flip -- says nothing about the true "
                               "survival, so the 'moved earlier' check is not "
                               "applied to this machine"
                               % (seed, survival, changeover_min))
            else:
                bad.append("seed %s: paired after only %.1f min (BEFORE the %.1f min flip) "
                           "-- the flip point moved earlier"
                           % (seed, survival, changeover_min))
    return bad, skipped


def check_attribution_decidable(rows, changeover_min):
    """Machines whose 'reclaimed before the flip' answer the input cannot give.

    The attribution clause asks survival < T.  For a reclaimed machine carrying
    only a lower bound under T, both answers are still open, and they fall on
    opposite sides of the verdict: calling it 'before' invents a BLINDED wave
    and a 3x more expensive instrument; calling it 'after' hides one.  So it is
    exit 2 -- the one answer that is true.
    """
    return ["seed %s: reclaimed, and its %.1f min is a LOWER BOUND under the "
            "%.1f min flip -- whether it died before the flip is exactly what "
            "the attribution clause needs and exactly what this input cannot say"
            % (r["seed"], r["survival"], changeover_min)
            for r in rows
            if r["code"] == RECLAIMED and r["bound"] == BOUND_LOWER
            and r["survival"] < changeover_min]


def _extensions(rows, changeover_min):
    """Every concrete reading the unread fields could have had.

    Yields lists of rows in which `code` and `survival` are always real values,
    so the decision function below never has to know a hole exists.
    """
    per_row = []
    for row in rows:
        codes = (_CODE_EXTENSIONS if is_unread(row["code"]) else (row["code"],))
        survivals = ((changeover_min - 1.0, changeover_min + 1.0)
                     if is_unread(row["survival"]) else (row["survival"],))
        per_row.append([(c, s) for c in codes for s in survivals])
    for combo in _itertools.product(*per_row):
        yield [dict(row, code=code, survival=survival)
               for row, (code, survival) in zip(rows, combo)]


def _decide(rows, changeover_min, bracket):
    """Concrete rows -> the verdict, as data rather than prose.

    THE one place the verdict is computed.  An extension point is scored by
    running this, not by a second copy of the clauses reasoning about what this
    would have said -- a checker that re-derives the rule it is checking drifts
    away from it, and then agrees with itself while both are wrong.
    """
    violations, _ = bracket
    attr_undecidable = check_attribution_decidable(rows, changeover_min)
    paired_n = sum(1 for r in rows if r["paired"])
    early = [r for r in rows
             if r["code"] == RECLAIMED and r["survival"] < changeover_min]
    low_yield = paired_n <= 1

    if attr_undecidable:
        return {"exit": 2, "verdict": (), "attr_undecidable": attr_undecidable,
                "paired_n": paired_n, "early_n": len(early)}
    if violations:
        return {"exit": 2, "verdict": (), "attr_undecidable": [],
                "paired_n": paired_n, "early_n": len(early)}
    if low_yield and early:
        return {"exit": 1, "attr_undecidable": [],
                "paired_n": paired_n, "early_n": len(early),
                "verdict": (
                    "VERDICT: BLINDED -- yield <= 1 AND the loss is capacity.",
                    "NEXT WAVE: launch --on-demand (ONE wave), then revert to spot.",
                    "  GH #158 stands: a spot machine that cannot be KEPT past the "
                    "flip is a spot machine we did not get.")}
    if low_yield:
        return {"exit": 0, "attr_undecidable": [],
                "paired_n": paired_n, "early_n": len(early),
                "verdict": (
                    "VERDICT: not blinded -- yield <= 1, but NO machine was "
                    "reclaimed before the flip.",
                    "NEXT WAVE: spot.  On-demand does not treat this: whatever ate "
                    "the yield, it was not capacity.  Diagnose the harness instead.")}
    return {"exit": 0, "attr_undecidable": [],
            "paired_n": paired_n, "early_n": len(early),
            "verdict": (
                "VERDICT: not blinded -- the wave delivered %d paired seed(s)."
                % paired_n,
                "NEXT WAVE: spot (the default; GH #158 unchanged).")}


def evaluate(wave, changeover_min=DEFAULT_CHANGEOVER_MIN,
             min_arm_depth=DEFAULT_MIN_ARM_DEPTH):
    """wave dict -> (exit_code, list_of_lines).  Never raises Undecidable."""
    lines = []
    name = wave.get("wave", "(unnamed)") if isinstance(wave, dict) else "(unnamed)"
    lines.append("=== reclaim-blind check (GH #271 ruling) -- wave %s ===" % name)
    # The edges print at 2dp, not 1: at 1dp the upper edge reads 40.6 against a
    # 40.0 constant, which rounds the 0.63 min of remaining margin out of the
    # only line that shows it.
    lines.append("changeover %.1f min  (measured bracket %.2f < x <= %.2f, "
                 "margin above the constant %.2f min)  min_arm_depth %.1f"
                 % (changeover_min, BRACKET_LO, BRACKET_HI,
                    BRACKET_HI - changeover_min, min_arm_depth))

    if not isinstance(wave, dict):
        lines.append("UNDECIDABLE: top level is not an object")
        return 2, lines
    machines = wave.get("machines")
    if not isinstance(machines, list) or not machines:
        lines.append("UNDECIDABLE: no `machines` list -- nothing was checked, "
                     "and nothing checked is not a pass")
        return 2, lines

    rows = []
    try:
        for i, machine in enumerate(machines):
            if not isinstance(machine, dict):
                raise Undecidable("machine[%d]: not an object" % i)
            seed = machine.get("seed", "?")
            where = "seed %s" % seed
            survival, code, paired, depth_checked, bound, market = classify_machine(
                machine, changeover_min, min_arm_depth, where)
            rows.append({"seed": seed, "survival": survival, "code": code,
                         "paired": paired, "depth_checked": depth_checked,
                         "bound": bound, "market": market,
                         "ab": int(machine["ab"]), "ba": int(machine["ba"])})
    except Undecidable as exc:
        lines.append("UNDECIDABLE: %s" % exc)
        return 2, lines

    for row in rows:
        how = "depth-checked" if row["depth_checked"] else "ab/ba only (no arm_depth given)"
        mark = ">=" if row["bound"] == BOUND_LOWER else "  "
        if row["market"] == MARKET_ON_DEMAND:
            how = "on-demand, %s" % how
        # A hole prints as a hole.  It must never render as a number or as a
        # code, because the per-machine line is what a reader scans to decide
        # whether the wave was read at all.
        shown_survival = ("  (unread)" if is_unread(row["survival"])
                          else "%6.1f min" % row["survival"])
        shown_code = "(unread)" if is_unread(row["code"]) else row["code"]
        lines.append("  seed %-8s %s%s  %-34s ab%-3d/ba%-3d  %s  [%s]"
                     % (row["seed"], mark, shown_survival, shown_code,
                        row["ab"], row["ba"],
                        "PAIRED " if row["paired"] else "NO-PAIR", how))
    n_od = sum(1 for r in rows if r["market"] == MARKET_ON_DEMAND)
    if n_od:
        lines.append("market     : %d of %d machine(s) on-demand (GH #408 refill) -- "
                     "they count for yield and can never satisfy the attribution "
                     "clause, because an on-demand row is refused if it carries a "
                     "SIR code at all, or spot's EC2 spelling, or any code outside "
                     "the EC2 vocabulary (GH #661)"
                     % (n_od, len(rows)))
    n_lower = sum(1 for r in rows if r["bound"] == BOUND_LOWER)
    if n_lower:
        lines.append("survival   : %d of %d machine(s) carry a LOWER BOUND (>=), not a "
                     "reading -- see `survival_bound` in this file's header"
                     % (n_lower, len(rows)))

    unread_rows = [r for r in rows
                   if is_unread(r["code"]) or is_unread(r["survival"])]

    # The bracket is gauged ONCE, on the rows that can support it.  It is not
    # re-run per extension point: a value this file invented is not evidence
    # about whether the constant it was invented against has gone stale.
    bracket = check_bracket(rows, changeover_min)

    n_points = 1
    for row in rows:
        n_points *= ((2 if is_unread(row["code"]) else 1)
                     * (2 if is_unread(row["survival"]) else 1))
    if n_points > MAX_EXTENSION_POINTS:
        lines.append("UNDECIDABLE: %d machine(s) carry an unread field, which is "
                     "%d extension point(s) -- past the %d this file will explore. "
                     "That much of the wave unread is a harvest to fix, not an "
                     "answer to compute (this is exit 2, not a pass)"
                     % (len(unread_rows), n_points, MAX_EXTENSION_POINTS))
        return 2, lines

    outcomes = [_decide(point, changeover_min, bracket)
                for point in _extensions(rows, changeover_min)]
    agreed = set((o["exit"], o["verdict"]) for o in outcomes)

    if len(agreed) > 1:
        # The hole is load bearing.  This is the same refusal the file always
        # made, finally saying the true reason: not "a field is missing" but
        # "this missing field is the answer".
        lines.append("UNDECIDABLE: an unread field CHANGES the verdict, so it "
                     "cannot be answered around:")
        for row in unread_rows:
            for key in ("code", "survival"):
                if is_unread(row[key]):
                    lines.append("    %s" % row[key].reason)
        outs = sorted(set(o["exit"] for o in outcomes))
        lines.append("    scored %d extension point(s); they do not agree "
                     "(exit codes %s)"
                     % (len(outcomes), ", ".join(str(o) for o in outs)))
        lines.append("UNDECIDABLE: re-read those field(s) (this is exit 2, not a "
                     "pass and not a BLINDED)")
        return 2, lines

    res = outcomes[0]

    if res["attr_undecidable"]:
        lines.append("UNDECIDABLE: the attribution clause cannot be evaluated on this input:")
        for u in res["attr_undecidable"]:
            lines.append("    %s" % u)
        lines.append("UNDECIDABLE: re-run with an exact survival for those machine(s) "
                     "(this is exit 2, not a pass and not a BLINDED)")
        return 2, lines

    violations, bracket_skipped = bracket
    for s in bracket_skipped:
        lines.append("bracket    : SKIPPED for %s" % s)
    if violations:
        lines.append("BRACKET VIOLATED -- the changeover constant no longer separates "
                     "this input; re-derive it before trusting any verdict:")
        for v in violations:
            lines.append("    %s" % v)
        lines.append("UNDECIDABLE: refusing to answer with a number the data just "
                     "contradicted (this is exit 2, not a pass and not a BLINDED)")
        return 2, lines

    lines.append("yield      : %d paired seed(s) of %d machine(s)"
                 % (res["paired_n"], len(rows)))
    if unread_rows:
        # Never print a count computed off an invented value.  The reader gets
        # the span the input actually supports, and the span's own irrelevance.
        spans = sorted(set(o["early_n"] for o in outcomes))
        lines.append("attribution: %d..%d machine(s) reclaimed before the flip "
                     "-- a RANGE, because %d machine(s) carry an unread field"
                     % (spans[0], spans[-1], len(unread_rows)))
        lines.append("unread     : %d of %d machine(s) do not supply a field this "
                     "check reads:" % (len(unread_rows), len(rows)))
        for row in unread_rows:
            for key in ("code", "survival"):
                if is_unread(row[key]):
                    lines.append("    %s" % row[key].reason)
        lines.append("immaterial : all %d extension point(s) agree, so the verdict "
                     "below does not rest on the unread field(s).  A gate may not "
                     "demand a datum its own answer does not depend on (GH #699)."
                     % len(outcomes))
        lines.append("             The exploration scores %r on every unread code, "
                     "on-demand rows included, so a mislabelled spot machine "
                     "cannot hide a reclaim here." % RECLAIMED)
    else:
        lines.append("attribution: %d machine(s) reclaimed before the flip"
                     % res["early_n"])

    lines.extend(res["verdict"])
    return res["exit"], lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--wave-json", required=True,
                    help="path to the harvested wave's JSON, or - for stdin")
    ap.add_argument("--changeover-min", type=float, default=DEFAULT_CHANGEOVER_MIN)
    ap.add_argument("--min-arm-depth", type=float, default=DEFAULT_MIN_ARM_DEPTH)
    args = ap.parse_args(argv)

    try:
        if args.wave_json == "-":
            wave = json.load(sys.stdin)
        else:
            with open(args.wave_json) as handle:
                wave = json.load(handle)
    except (OSError, ValueError) as exc:
        print("=== reclaim-blind check (GH #271 ruling) ===")
        print("UNDECIDABLE: could not read --wave-json: %s" % exc)
        return 2

    code, lines = evaluate(wave, args.changeover_min, args.min_arm_depth)
    for line in lines:
        print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
