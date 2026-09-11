#!/usr/bin/env python3
"""Gate (iii) -- the monthly spend fence -- as an executable check.

Director ruling on GH #504, 2026-09-05.  Filed by the batch desk in its
2026-09-05T00:11Z round, from a defect that had been silently live since
2026-09-01 and had not yet cost anything.

THE FILING STORY IS THE SPECIFICATION.  On 2026-08-28 the director rewrote
gate (iii) and the stated point of the rewrite was to REMOVE A FREE PARAMETER:

    ⇒ 新写法:围栏 = 下一个尚未跨过的 owner 可见 Budget ACTUAL 告警档。
    ... 这样围栏不再是猜的 ... 副作用即是目的:下一次「该不该再抬」不再由
    总监自由裁量。

That is a rule with no free parameter in it.  But the same clause then wrote
down the rule's ANSWER, evaluated once, in August:

    `dota2bot-batch` 的告警在限额 $100 的 50/80/100%,即 $50 / $80 / $100;
    $50 已跨 ... 下一档就是 $80。... 当月唯一的操作数是上面的 $80。

`dota2bot-batch` is `TimeUnit: MONTHLY`.  ActualSpend resets on the 1st, and
with it the set of thresholds that have been crossed.  At 2026-09-01T00:00Z the
September ActualSpend went to $0, `$50` became un-crossed, and the rule's own
output became `$50` -- while the charter, every round's report, and the desk's
launch arithmetic went on reading the cached `$80`.

    A derived value was written down as a literal, and its input moves on a
    schedule nobody is watching.

Three properties made it invisible, and they are the reason this is a program
now and not a corrected number:

    1. It fails toward MORE spending, not less: $30 of headroom the rule does
       not actually grant.  A fence that fails toward less spending files its
       own bug report by throttling somebody.  This one is silent by shape.
    2. The wrong line is BYTE-IDENTICAL to the right one for the whole of
       August.  There is no diff to notice, no missing reading, no error.
    3. It only bites when spend is high -- i.e. it is armed exactly when the
       owner-visible email it exists to prevent is closest.  The desk's own
       burn-rate arithmetic (GH #505) puts the first real bite in mid-September.

Same family as the `pullcad` trap (a constraint frozen FALSE by a promote
elsewhere), as GH #469 (gate (i) was prose plus an agent's mental arithmetic
until W12/W20/W44 breached it three times the same way), and as #205/#213 (a
check that could not run read as a check that passed).  The remedy is the same
one that worked for gate (i): make the gate a program that prints a number and
refuses, so that "re-derive it" is not a thing anyone has to remember on the
1st of the month.

WHAT THIS TOOL DERIVES, AND FROM WHERE.  Nothing here is a constant carried
over from a previous month.  Every operand is re-read at call time:

    ActualSpend, BudgetLimit, TimeUnit   `budgets describe-budget`      (free)
    the alert thresholds themselves      `budgets describe-notifications
                                          -for-budget`                  (free)

The second call is the one that removes the last literal.  AGENTS.md records
that `dota2bot-agent` cannot read `DescribeBudgetActionsForBudget`, and the
charter accordingly hard-coded "50/80/100%" as documentation.  That permission
gap does NOT extend to notifications: this account CAN read them (verified
2026-09-05, exit 0, three ACTUAL notifications returned).  So the percentages
are read, not asserted.

THREE RULINGS ARE BAKED IN, because leaving them to prose is what got us here.

RULING 1 -- WHICH THRESHOLD IS "THE NEXT ONE NOT YET CROSSED".  The alerts are
`ComparisonOperator: GREATER_THAN`, so the owner's email is sent when spend
STRICTLY EXCEEDS the threshold.  A month sitting exactly ON a threshold has not
sent it.  Therefore:

    fence = min{ T : T >= actual }        over ACTUAL-type thresholds

and a run whose projected total lands exactly on the fence is allowed.  The
conservative-looking alternative (`T > actual`) would skip past a threshold the
instant spend touched it, which is the over-permissive direction.

RULING 2 -- PERCENTAGE VS ABSOLUTE THRESHOLDS.  `ThresholdType` is omitted from
the API response when it is the default, and the default is PERCENTAGE.  An
absent field is therefore read as PERCENTAGE and the tool SAYS SO on its own
output line.  This matters more than it looks: `dota2bot-batch` has limit
$100.0 and thresholds 50/80/100, so the percentage reading and the absolute
reading COINCIDE TODAY, in every digit.  That coincidence is exactly the shape
that hides a defect until the limit changes -- so the interpretation is printed
every run rather than inferred by whoever reads the numbers.

RULING 3 -- WHEN AWS AND OUR ARITHMETIC DISAGREE, NOBODY LAUNCHES.  Each
notification carries `NotificationState` (`OK` / `ALARM`), which is AWS's own
answer to "has this one fired this month".  We compute the same fact from
ActualSpend.  If the two disagree in EITHER direction the tool exits 2
(could-not-run), never 0:

    we say not-crossed / AWS says ALARM -- the owner already got an email we
        believe was never sent; our fence is built on a false premise.
    we say crossed / AWS says OK -- we skipped a live threshold, i.e. we are
        being MORE permissive than the rule allows.

Both are over-permissive or unexplained, and a blocked launch is the safe
failure.  Exit 2 is not a pass; see GH #171/#205/#213 for the vocabulary.

RULING 4 -- `--pending` IS A CLAIM, AND THIS TOOL NOW CHECKS IT.  Director,
2026-09-06, from the batch desk's 09:12Z hand-off (GH #515).  `--pending`
defaulted to 0.0, so a run that simply did not pass it printed

    pending waves    : $0.000   (launched, may not be in MTD yet)

which READS like a measurement and IS an unexamined default.  On 2026-09-06 the
desk ran the gate, got `CLEAR`, and the honest reconstruction said `THROTTLED`:
an instance belonging to another project (`c7a.16xlarge`,
`Project=final-table-trainer`) had been burning all day against a budget that
carries NO cost filter, and ActualSpend lags 4.3-11.3h behind.  The desk
extrapolated by hand, over-rode its own green tool, and did not launch.  It was
right, and the fact that it had to do that by hand is the defect.

Note the shape, which is the SAME one this file was written to kill: a term
whose correct value is derived, defaulted to a literal, and the literal is
indistinguishable from the derivation on every quiet day.  It fails toward MORE
spending.  It bites exactly when spend is high (that is when things are
running).  It is silent.

The remedy deliberately does NOT invent a cost model.  This tool does not know
what an arbitrary instance costs -- spot price, on-demand price and lifecycle
would each need their own read, and a markup constant guessed here would be a
new free parameter, which is the disease.  What it CAN establish for free is
the PRECONDITION under which `$0.000` is true:

    pending == 0 is certifiable if and only if nothing is running.

So: the tool reads `ec2 describe-instances` (free, no tag filter -- the budget
has none either) and

    nothing running, no --pending      -> pending = $0.000, marked CERTIFIED
    something running, no --pending    -> exit 2, listing what is running
    --pending given (0.0 included)     -> the operator's own number, marked
                                          ASSERTED, with the instances it has
                                          to cover printed next to it

An operator who really wants the old behaviour passes `--no-accrual-check`,
which prints a line calling itself SKIPPED, not certified (the `RULE6_BYPASS`
pattern from GH #213) and is meant to be quoted in the round's report.

Two boundaries, stated rather than assumed:
  * the enumeration is UNFILTERED BY TAG ON PURPOSE.  `dota2bot-batch` has no
    cost filter today, so every running instance in the account does consume
    this fence's headroom regardless of whose project it is.  If the owner ever
    adds the `Project` filter (DECISIONS_NEEDED #15) this check becomes
    over-conservative -- it would throttle us for somebody else's compute.  That
    is the failure direction that files its own bug report, and the tool prints
    whether the budget carries `CostFilters` so the day it changes is visible.
  * RULING 5 -- THE SCOPE OF THAT ZERO IS NOW PRINTED, BECAUSE IT WAS A CLAIM.
    Director, 2026-09-09 (GH #677's round; the finding is not GH #677 itself).
    Until this ruling the line above said `account-wide` and the docstring said
    `ACCOUNT-WIDE ON PURPOSE`, while `ec2 describe-instances` is a REGIONAL
    call and `~/.aws/config` pins `region = us-west-2`
    (`tools/batch_test/aws/bootstrap_creds.sh`).  So the reading was one region
    and the claim was the account -- and the budget it protects has no region
    filter either, so a `c7a.16xlarge` burning in `us-east-1` was invisible to
    a check that printed CERTIFIED.  Same family as everything else in this
    file: a claim wider than its reading, silent by shape, failing toward MORE
    spending, and biting exactly when spend is high.  It surfaced while ruling
    on `headroom $0.292`, whose sole named cause is foreign compute that our
    own leak checks (also `us-west-2`, from `aws.env`) have never covered.
    The remedy is NOT a new constant: the tool enumerates the account's enabled
    regions (`ec2 describe-regions`, free) and reads each.  Where that
    enumeration cannot be had -- the restricted `dota2bot-agent` may lack
    `ec2:DescribeRegions` -- it falls back to the configured region and
    DEGRADES THE CLAIM rather than the gate: the zero is then printed as
    `CERTIFIED WITHIN SCOPE`, never as account-wide, and a `WAVE_FENCE SCOPE:`
    line rides after the verdict line so the caveat travels with the sentence
    people copy into reports.  Deliberately NOT an exit 2: turning a
    false-label defect into a permanent launch outage is a policy change, and
    the desk is already fence-blocked; the honest label is the fix.
  * exit 2 here means could-not-run, as everywhere else in this file.  A
    blocked launch is the safe failure; a launch on an uncertified zero is not.
  * RULING 6 -- THAT ZERO ALSO HAD A CLOCK, AND IT WAS THE WRONG ONE.
    Director, 2026-09-10 (GH #683's round; the finding is not GH #683 itself).
    Ruling 4 above states its precondition as a biconditional:

        pending == 0 is certifiable if and only if nothing is running.

    The `=>` half is sound and is what the exit 2 below enforces: something
    running does mean pending > 0.  The `<=` half -- the half this branch
    PRINTS AS CERTIFIED -- is false, and it is false for the farm's normal
    mode of operation.  `pending` is not "money accruing at this instant"; the
    charter defines it (batch-desk.md ss2(jia)) as waves already launched whose
    cost has not reached MTD yet, because ActualSpend lags 4.3-11.3h.  A wave
    that launched inside that lag and SELF-TERMINATED is invisible to both
    terms at once: gone from `describe-instances`, not yet in ActualSpend.  And
    self-termination is not an edge case here -- AGENTS.md forbids launching
    anything without a self-destruction path, so between waves the census is
    structurally zero for our own spend.  The census therefore certified
    nothing about the farm; it only ever caught FOREIGN long-lived compute,
    which is the single incident it was generalised from.

    Measured, not reasoned: on 2026-09-10T00:14Z the desk ran this gate and got
    `CERTIFIED (0 accruing instances account-wide)` with `headroom $5.692`,
    then did the arithmetic by hand and got `$2.442`.  The gap is $3.250 =
    W62 ($2.150, launched 21:24Z, 61 minutes AFTER the MTD snapshot) + W61
    ($1.100, 5.0h before it, inside the lag band).  Same family as Rulings 1,
    4 and 5: a claim wider than its reading, silent by shape, failing toward
    MORE spending, biting hardest when waves are frequent.

    Second half of the same defect, and the reason the remedy names a clock:
    the desk's hand window is anchored to NOW while the MTD it corrects is
    anchored to the budget's own `LastUpdatedTime`.  When that snapshot is
    stale -- 3.9h stale on 2026-09-10 -- every wave in the gap is dropped from
    pending by construction.  W60 (09-09T09:23Z) is exactly such a wave: 14.9h
    before `now` so the desk's 12h window excluded it, but only 11.0h before
    the snapshot, i.e. still inside the 4.3-11.3h lag band and possibly not in
    the $74.308 it was being subtracted from.

    The remedy again invents no cost model and no margin constant.  It reads
    the wave records (local JSON, free, offline) with gate (i)'s own parser and
    establishes the same kind of PRECONDITION Ruling 4 did, on the right clock:

        pending == 0 is certifiable only if no wave launched after
        (budget LastUpdatedTime - 11.3h)

    A wave inside that window does not get priced here; the zero simply stops
    being certifiable and `--pending` becomes required, which is what the desk
    already computes by hand every round.  Unreadable records or a missing
    `LastUpdatedTime` DEGRADE THE CLAIM, NOT THE GATE, per Ruling 5: the tool
    falls back to `now`, says which clock it used, and never calls the result
    an accrual-complete zero.  Note the fallback direction is the permissive
    one (`now` is later, so the window is narrower), which is why it is
    labelled rather than silently taken.
  * RULING 7 -- THAT LABEL WAS PRINTED ON EVERY SINGLE RUN, AND IT NO LONGER
    STOPS AT THE WORDING.  Director, 2026-09-10, from the batch desk's 03:1xZ
    hand-off (GH #692 the defect, GH #693 the policy).  Two findings, and the
    second one is the reason the first one had teeth.

    (a) The parser.  Ruling 6's fallback was designed as a RARE labelled
    degrade.  It was not rare: `awsx budgets describe-budget --output json`
    hands `LastUpdatedTime` back as a float epoch, `parse_snapshot_instant`
    only knew datetimes and ISO strings, so the degrade fired on 100% of live
    runs from the day Ruling 6 landed.  `check_costs.sh` printed the correct
    instant in the same round the gate called it unreadable.  Fixed by
    accepting the epoch -- see that function.

    (b) The exit code.  GH #683 ss4 moved launch authority from "the director
    rules each round" to arithmetic: exit 0 plus a `--pending` covering every
    wave the tool lists means launch, no ask.  From that moment THE EXIT CODE
    IS THE AUTHORISATION, and Ruling 6's degrade -- which touches the wording
    and not the exit code -- became a hole with money on the other side.
    Measured on the first round ss4 was exercised: the degraded clock listed
    one wave (W62, $2.150) where the honest clock listed three ($5.400); the
    desk covered every wave the tool named, in full, and the gate answered
    exit 0 on a launch that would have crossed the fence ($80.808 > $80.00).
    The desk did not launch, because it did the arithmetic by hand.  A gate
    that is only safe when its operator does not trust it is not a gate.

    So a degraded clock now returns exit 2, before any verdict branch, with
    or without `--pending`.  Note this REVERSES Ruling 5's "deliberately not
    an exit 2" for this one code path, and the reversal is narrow on purpose:
    Ruling 5's own region clause is untouched.  What changed is not the
    appetite for outages -- it is that ss4 removed the human who used to read
    the caveat line.  The gate does not close permanently: `--snapshot-instant`
    lets the operator assert the clock they can read elsewhere (labelled a
    claim, and it is the clock, so the check still runs), and
    `--no-accrual-check` remains the written skip.  Fix (a) is also what makes
    (b) affordable: with the epoch parsed, the degrade is rare again.

    Deliberately NOT widened to `why_unread`.  An unread wave record is
    permissive too, but it is a different reading with a different remedy and
    GH #693 asked about the clock; widening it here would be a policy change
    smuggled in under a bug fix.  It stays a caveat on an exit 0, pinned by
    assertion 16f so that the narrowing stays visible.

WHAT THIS TOOL DOES NOT RULE ON.  The $90 brake line and the $100 owner
approval line are the OWNER's numbers, not the budget's, and this tool neither
derives nor relaxes them.  It applies the brake as a second ceiling
(`--brake`), so the operative fence is `min(next uncrossed threshold, brake)`,
and it refuses at the brake with a line that says to stop and report rather
than to wait.

Usage:

    python3 tools/batch_test/soak/wave_fence.py --planned 1.10
    python3 tools/batch_test/soak/wave_fence.py --planned 1.10 --pending 1.76
    python3 tools/batch_test/soak/wave_fence.py --actual 17.773 --limit 100 \
        --thresholds 50,80,100 --planned 1.10     # offline; for tests/audit

Exit codes:  0 the fence holds and the launch is inside it
             2 could-not-run / uncertifiable -- NOT a pass
             3 the fence (or the brake) would be crossed -- do not launch
"""

import argparse
import datetime as _dt
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wave_throttle  # noqa: E402  -- gate (i)'s wave-record parser, reused

BUDGET_NAME = "dota2bot-batch"
DEFAULT_BRAKE = 90.0          # owner's brake line; see AGENTS.md AWS policy
DEFAULT_OWNER_LINE = 100.0    # owner's approval line; reported, never applied

# EC2 states that are already accruing charges but may not be in MTD yet.
# `stopping`/`shutting-down` are in: an instance dying right now still billed
# for the hours it has already run, and those hours are what MTD is behind on.
ACCRUING_STATES = ("pending", "running", "stopping", "shutting-down")

# Ruling 6.  The upper end of the documented ActualSpend lag.  A wave launched
# more recently than this before the budget snapshot cannot be assumed to be in
# it.  The MAX is the load-bearing end: using the 4.3h floor would certify a
# zero over waves that are merely PROBABLY billed.
ACCRUAL_LAG_MAX_HOURS = 11.3


class Uncertifiable(Exception):
    """The check could not be run.  Exit 2 -- this is not a pass."""


# ------------------------------------------------- RULING 10 (director, GH #721)
#
# THE FILING STORY IS THE SPECIFICATION, AGAIN.
#
# Since the fence was written, its refusal line has read:
#
#     "Crossing needs the director's explicit ruling that round, plus the
#      written explanation the charter owes for every crossed threshold."
#
# That sentence names an authority.  It gave that authority NO WAY TO SPEAK.
# There is no flag, no file, no field -- so a director who rules "cross it"
# hands the desk a ruling the tool cannot be told about, and the only way to
# act on it is TO NOT RUN THE GATE.  That is an unbounded, unlogged bypass,
# reached by the one path nothing can audit: absence.  It is the charter's own
# 2.5 defect ("a ruling has to land in the field the ruled party reads")
# baked into a tool -- and this file is the ruled party.
#
# 2026-09-10 is the round where it bit.  Headroom $1.053, wave needs $1.100:
# the desk was blocked by $0.047 with 20 days of September left, and the
# blocking number was an ACCOUNT number (see the note on `budget filters`
# below), ~55% of it spent by a co-tenant workload with its own $150 budget.
#
# SO THE FIELD IS BUILT HERE, AND IT IS BUILT NARROW.  Four constraints, and
# every one of them is what keeps this from being the bypass switch that
# GM.2(a) forbade:
#
#   (1) IT CANNOT REACH THE BRAKE.  `min(ruling, brake)` -- and a ruling that
#       names a number above the brake (or above the owner's approval line) is
#       REFUSED, exit 2, not silently clamped.  Silence is not the permissive
#       answer, and a clamp would let a wrong ruling read as an obeyed one.
#   (2) IT MUST EXPIRE, AND THE EXPIRY IS CHECKED, NOT PROSE.  A ruling with
#       no expiry is refused.  An expired one is refused.  The failure mode
#       this closes is the one every crossing ruling has: it is written for a
#       month and then quietly becomes the permanent ceiling.
#   (3) IT MUST NAME ITSELF.  `--crossing-ref` is mandatory and is printed
#       verbatim, so the round's report carries the ruling that authorised it
#       and an auditor can go read that ruling.
#   (4) IT ANNOUNCES ITSELF ON EVERY RUN IT TOUCHES, including the CLEAR one,
#       with the derived fence printed BESIDE the ruling ceiling -- so a
#       reader always sees which bound actually bit and that one of them is a
#       ruling rather than a reading.
#
# What it deliberately does NOT do: it does not rescue the NO-FENCE case
# (MTD already past every alert).  Past the owner's approval line the answer
# is the owner's, and a director ruling is not a substitute for it.


def build_crossing(ceiling, ref, expiry, brake=DEFAULT_BRAKE,
                   owner_line=DEFAULT_OWNER_LINE, now=None):
    """Validate a director crossing ruling.

    Returns (crossing_dict_or_None, error_string_or_None).  A non-None error
    is exit 2 -- the gate did not run.  Kept out of main() so the refusals are
    reachable from a test without an AWS account, which is where the last four
    rulings' bugs were found.
    """
    if ceiling is None:
        if ref or expiry:
            return None, ("--crossing-ref/--crossing-expiry were given with no "
                          "--director-crossing. That names a ruling which "
                          "authorises nothing; it is more likely a dropped "
                          "flag than an intent.")
        return None, None
    if not ref or not str(ref).strip():
        return None, ("--director-crossing needs --crossing-ref: the ruling has "
                      "to be quotable in the round's report, or nobody can "
                      "audit what authorised the crossing.")
    if not expiry:
        return None, ("--director-crossing needs --crossing-expiry: a crossing "
                      "ruling that cannot expire becomes the permanent "
                      "ceiling, which is the whole failure mode it is fenced "
                      "against.")
    when = parse_snapshot_instant(expiry)
    if when is None:
        return None, ("--crossing-expiry %r is not an instant this tool can "
                      "read (want ISO-8601 or an epoch)." % expiry)
    moment = now if now is not None else _dt.datetime.now(_dt.timezone.utc)
    if moment > when:
        return None, ("the crossing ruling %s expired at %s and it is now %s. "
                      "Get a fresh ruling; an expired one is not a weaker "
                      "ruling, it is no ruling."
                      % (ref, when.isoformat(), moment.isoformat()))
    if ceiling > brake:
        return None, ("--director-crossing $%.2f is above the $%.2f brake. The "
                      "brake is the owner's line, not the director's; a "
                      "crossing ruling may raise the fence up to it and no "
                      "further. Refused rather than clamped, so a wrong "
                      "ruling cannot read as an obeyed one." % (ceiling, brake))
    if ceiling > owner_line:
        return None, ("--director-crossing $%.2f is above the owner's $%.2f "
                      "approval line. That is the owner's decision, not a "
                      "ruling this tool will accept." % (ceiling, owner_line))
    return {"ceiling": float(ceiling), "ref": str(ref).strip(),
            "expiry": when.isoformat()}, None


# ------------------------------------------------- RULING 11 (director, GH #729)
#
# RULING 10 BUILT THE CHANNEL AND LEFT THE DIALLING TO MEMORY.
#
# 2026-09-10T19:08Z the director ruled: September operative ceiling $85.00,
# ref GH#721/director-20260910, expiry 2026-09-30T23:59:00Z.  It was delivered
# by the book -- charter 2.5's three places, `batch-desk.md` carrying the
# literal command line, `owed_executions.json`, `test_set.md §GO`.
#
# 2026-09-10T21:18Z, the very next round, the desk ran this gate and reported:
#
#     "**未用 `--director-crossing`** -- 跨 `$80` 需总监**当轮**明确裁定,
#      **本台不预支**"
#
# It was not disobedience and it was not a missed delivery.  IT WAS THIS FILE
# TALKING.  The refusal line has said, since long before Ruling 10, that
# crossing needs the director's ruling THAT ROUND -- and Ruling 10 did not
# touch that sentence.  So the desk obeyed the tool, and the tool's sentence
# structurally excludes every ruling not issued inside the current round,
# which is EVERY standing ruling: Ruling 10's whole mechanism is an EXPIRY,
# i.e. an authorisation that is meant to span rounds by construction.  The
# two sentences cannot both be true and the older one won.
#
# Cost, measured not asserted: replaying that round's own numbers offline
# (`--actual 78.253 --pending 1.100 --planned 1.100`) gives exit 3 bare and
# exit 0 with the ruling, `headroom $4.547 after this wave`.  The desk was
# blocked by a sentence, not by money, ~2h after the money was granted.
#
# TWO FIXES, AND THE SECOND IS THE STRUCTURAL ONE.
#
# (A) The refusal line no longer says "that round".  What actually binds is
#     "a ruling that has not expired AT THIS INSTANT", which is what the code
#     has always checked; the prose was describing a different tool.
#
# (B) A ruling in force is READ BY THIS TOOL, not remembered by its operator.
#     Ruling 10 diagnosed "the tool cannot be told about the ruling" and built
#     three flags -- but three flags that must be RECALLED and RETYPED every
#     round are still a channel whose default state is silence, and absence of
#     a flag is indistinguishable from absence of a ruling.  So a director
#     issuing a crossing now writes one record into
#     `iterations/director_rulings.json`, and the gate reads it ITSELF, on
#     every run, with no flag at all.  Same `build_crossing`, so all four of
#     Ruling 10's constraints hold verbatim on this path too -- a registry
#     ruling that reaches for the brake is refused exactly as a flagged one is.
#
# THE REGISTRY IS NEVER SILENT.  Every run prints what it found, including
# "nothing".  That is the load-bearing half: a ruling that has EXPIRED and is
# skipped silently reads exactly like a ruling that was never made, and the
# desk would file "跨档需裁定,本台不预支" again while a director who wrote
# the record believes the channel is open.  That is the defect this ruling
# exists to close, one month later.
#
# ONE DELIBERATE ASYMMETRY, because the two paths answer different questions:
#   * an EXPIRED ruling passed via FLAGS is exit 2 (Ruling 10, unchanged) --
#     the operator ASSERTED this round that a ruling is live, and it is not;
#     acting on a false assertion is the failure.
#   * an EXPIRED record in the REGISTRY is NOT fatal -- nobody asserted it,
#     it is an old record reaching its designed end of life.  The gate runs
#     at the DERIVED fence and says so loudly.  Making it fatal would turn
#     every expiry into a self-inflicted outage of the gate itself, which is
#     how a safety tool gets routed around.
# Registry records that are MALFORMED, or two live records disagreeing, ARE
# fatal: then we do not know what is in force, and "did not run" is the only
# honest answer.  It is also the restrictive direction -- nothing launches.

DEFAULT_RULINGS_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.dirname(os.path.abspath(__file__))))),
    "iterations", "director_rulings.json")


def load_standing_crossing(path, now=None, brake=DEFAULT_BRAKE,
                           owner_line=DEFAULT_OWNER_LINE):
    """Read the standing crossing ruling, if any, out of the registry file.

    Returns (crossing_or_None, notes, fatal_error_or_None).  `notes` is always
    non-empty: this tool never says nothing about the registry (see above).
    A non-None fatal error is exit 2 -- the gate did not run.
    """
    notes = []
    if not os.path.exists(path):
        notes.append("crossing registry: none at %s -- no standing ruling. "
                     "The gate runs at the DERIVED fence." % path)
        return None, notes, None
    try:
        with open(path) as fh:
            blob = json.load(fh)
    except Exception as exc:
        return None, notes, (
            "crossing registry %s could not be read (%s). A registry we "
            "cannot parse means we do not know whether a ruling is in force, "
            "and guessing 'none' answers a question nobody asked."
            % (path, exc))
    records = blob.get("crossings") if isinstance(blob, dict) else blob
    if not isinstance(records, list):
        return None, notes, (
            "crossing registry %s has no `crossings` list. Expected "
            "{\"crossings\": [{ceiling, ref, expiry}, ...]}." % path)

    moment = now if now is not None else _dt.datetime.now(_dt.timezone.utc)
    live, expired = [], []
    for i, rec in enumerate(records):
        if not isinstance(rec, dict):
            return None, notes, (
                "crossing registry %s entry %d is not an object." % (path, i))
        for key in ("ceiling", "ref", "expiry"):
            if key not in rec:
                return None, notes, (
                    "crossing registry %s entry %d has no `%s`. Ruling 10's "
                    "three constraints are not optional on this path."
                    % (path, i, key))
        when = parse_snapshot_instant(rec["expiry"])
        if when is None:
            return None, notes, (
                "crossing registry %s entry %d has expiry %r, which is not an "
                "instant this tool can read. An unreadable expiry is not an "
                "expiry." % (path, i, rec["expiry"]))
        (expired if moment > when else live).append((rec, when))

    for rec, when in expired:
        notes.append("crossing registry: ruling %s EXPIRED at %s (now %s) -- "
                     "NOT applied. This run uses the DERIVED fence. If a "
                     "crossing is still wanted, the director issues a fresh "
                     "ruling; an expired one is no ruling."
                     % (rec["ref"], when.isoformat(), moment.isoformat()))
    if len(live) > 1:
        return None, notes, (
            "crossing registry %s has %d rulings in force at once (%s). Which "
            "ceiling binds is then a bookkeeping accident, so nothing "
            "launches until the director retires the stale one."
            % (path, len(live), ", ".join(r["ref"] for r, _ in live)))
    if not live:
        if not expired:
            notes.append("crossing registry: %d record(s) at %s, none in "
                         "force -- the gate runs at the DERIVED fence."
                         % (len(records), path))
        return None, notes, None

    rec, _when = live[0]
    crossing, err = build_crossing(rec["ceiling"], rec["ref"], rec["expiry"],
                                   brake=brake, owner_line=owner_line,
                                   now=moment)
    if err is not None:
        return None, notes, (
            "crossing registry %s: ruling %s is not one this tool will "
            "accept -- %s" % (path, rec["ref"], err))
    notes.append("crossing registry: ruling %s IS IN FORCE (read from %s, not "
                 "from a flag). It is applied below."
                 % (crossing["ref"], path))
    return crossing, notes, None


# ---------------------------------------------------------------- pure core

def resolve_thresholds(notifications, limit):
    """ACTUAL thresholds as dollar amounts, plus how each was interpreted.

    Returns a list of dicts sorted by amount:
        {"amount": float, "raw": float, "kind": "PERCENTAGE"|"ABSOLUTE_VALUE",
         "assumed_kind": bool, "state": "OK"|"ALARM"|None}

    FORECASTED notifications are dropped: the fence is about money already
    spent, and a forecast alert does not mean the owner got a "you have spent"
    email.  (AWS's own forecast for September is $119.286 -- see GH #505 --
    which would otherwise read as "every threshold already crossed".)
    """
    out = []
    for note in notifications:
        if note.get("NotificationType") != "ACTUAL":
            continue
        try:
            raw = float(note["Threshold"])
        except (KeyError, TypeError, ValueError):
            raise Uncertifiable(
                "a notification has no readable Threshold: %r" % (note,))
        kind = note.get("ThresholdType")
        assumed = kind is None
        if assumed:
            kind = "PERCENTAGE"          # Ruling 2: the API's own default
        if kind == "PERCENTAGE":
            amount = limit * raw / 100.0
        elif kind == "ABSOLUTE_VALUE":
            amount = raw
        else:
            raise Uncertifiable("unknown ThresholdType %r" % (kind,))
        out.append({
            "amount": amount, "raw": raw, "kind": kind,
            "assumed_kind": assumed, "state": note.get("NotificationState"),
        })
    if not out:
        raise Uncertifiable(
            "budget %r has no ACTUAL notifications -- the fence rule has "
            "nothing to derive a value from" % BUDGET_NAME)
    out.sort(key=lambda t: t["amount"])
    return out


def pick_fence(thresholds, actual):
    """Ruling 1: the lowest ACTUAL threshold not yet crossed (T >= actual)."""
    for t in thresholds:
        if t["amount"] >= actual:
            return t
    return None


def state_disagreements(thresholds, actual):
    """Ruling 3: rows where NotificationState contradicts our arithmetic."""
    bad = []
    for t in thresholds:
        if t["state"] is None:
            continue                      # offline mode; nothing to cross-check
        we_crossed = actual > t["amount"]       # GREATER_THAN, strictly
        aws_crossed = t["state"] == "ALARM"
        if we_crossed != aws_crossed:
            bad.append((t, we_crossed, aws_crossed))
    return bad


def scope_line(scope):
    """Ruling 5.  One line saying WHERE the accrual reading actually looked.

    `scope` is the dict `read_accruing_instances` returns, or None when there
    was no live enumeration at all (offline / --no-accrual-check).  Returns
    (line, complete) -- `complete` False means no zero from this read may be
    called account-wide.
    """
    if not scope:
        return None, False
    regions = scope.get("regions") or []
    shown = ", ".join(regions[:6]) + ("  +%d more" % (len(regions) - 6)
                                      if len(regions) > 6 else "")
    if scope.get("complete"):
        return ("accrual scope    : %d region(s) read [%s]  <- COMPLETE: every "
                "region this account has enabled" % (len(regions), shown),
                True)
    why = scope.get("why") or "enumeration incomplete"
    return ("accrual scope    : %d region(s) read [%s]  <- SCOPE-LIMITED, NOT "
            "the account (%s). A zero below does not exclude accrual "
            "elsewhere." % (len(regions), shown, why), False)


def parse_snapshot_instant(text):
    """Ruling 6.  The budget's own `LastUpdatedTime`, or None if unreadable.

    Deliberately tolerant of the shapes THIS TOOL'S OWN CALL PATH hands back.
    Ruling 7 (GH #692) is why that sentence now names the call path: the
    original wording said "the shapes botocore hands back", and the tolerance
    list was written to match botocore -- while `_read_budget()` goes through
    the CLI's `--output json`, which serialises `LastUpdatedTime` as a FLOAT
    EPOCH (`1788985417.716`).  That shape fell through to `return None`, so on
    this account the clock degraded to `now` on 100% of runs.  The data was
    there and correct the whole time; the parser dropped it on the floor.
    "Could not read it" and "read it and did not recognise it" print the same
    exit code and are not the same defect.

    Returning None is a real answer here -- it routes to Ruling 7's exit 2
    rather than to a guess.
    """
    if text is None:
        return None
    if isinstance(text, _dt.datetime):
        return (text if text.tzinfo
                else text.replace(tzinfo=_dt.timezone.utc)).astimezone(
                    _dt.timezone.utc)
    # Ruling 7.  `bool` is excluded on purpose: isinstance(True, int) is True,
    # and a stray boolean dated 1970-01-01 is a wrong reading, not a reading.
    if isinstance(text, (int, float)) and not isinstance(text, bool):
        try:
            return _dt.datetime.fromtimestamp(float(text), _dt.timezone.utc)
        except (ValueError, OverflowError, OSError):
            return None
    if not isinstance(text, str):
        return None
    raw = text.strip().replace("Z", "+00:00")
    try:
        parsed = _dt.datetime.fromisoformat(raw)
    except ValueError:
        return None
    return (parsed if parsed.tzinfo
            else parsed.replace(tzinfo=_dt.timezone.utc)).astimezone(
                _dt.timezone.utc)


def waves_since(waves_dir, cutoff):
    """Ruling 6.  Wave records whose LAST machine went up at or after `cutoff`.

    Returns (rows, why_unread).  `rows` is [(wave_id, last_launch)] sorted
    newest first; `why_unread` is None on a clean read and a sentence otherwise.
    A record the parser refuses (no `launched_at`, a bare time of day) is NOT
    silently dropped -- it comes back as an unread reason, because "we could not
    date this wave" and "this wave is old" must not print the same.

    One exception, and it is not a softening: W37-W39 predate GH #544 and carry
    no `launched_at` at all, so a naive read attaches an unread caveat to EVERY
    future run -- a permanent caveat is an unread one, which is how a gate stops
    being read.  Those records can be bounded without inventing anything, using
    gate (i)'s own ruling 3: numeric order IS a time order INSIDE a family.  So
    an undatable record with a higher-numbered datable sibling that launched
    before the cutoff is itself before the cutoff.  Only records that cannot be
    bounded that way stay unread.
    """
    rows = []
    try:
        families = wave_throttle.list_wave_records(waves_dir)
    except wave_throttle.Uncertifiable as exc:
        return [], str(exc)
    unread = []
    for family, records in families:
        # `records` is highest number first, so the running minimum is the
        # tightest upper bound ruling 3 allows for everything still to come.
        bound_above = None
        for number, name in records:
            wave_id = "%s%d" % (family, number)
            try:
                record = wave_throttle.load_record(waves_dir, name)
                launches = wave_throttle.slate_launches(record, wave_id)
            except wave_throttle.Uncertifiable as exc:
                if bound_above is not None and bound_above < cutoff:
                    continue          # ruling 3 dates it old; nothing to say
                unread.append(str(exc))
                continue
            if not launches:
                continue
            last = max(launches)
            bound_above = last if bound_above is None else min(bound_above,
                                                               last)
            if last >= cutoff:
                rows.append((wave_id, last))
    rows.sort(key=lambda pair: pair[1], reverse=True)
    return rows, ("; ".join(unread[:3]) if unread else None)


def wave_accrual_lines(rows, why_unread, clock, clock_source, cutoff):
    """Ruling 6.  The report lines for the wave-record half of the zero."""
    lines = ["wave accrual     : records after %s (= %s - %.1fh lag, clock "
             "from %s)" % (cutoff.strftime("%Y-%m-%dT%H:%M:%SZ"),
                           clock.strftime("%Y-%m-%dT%H:%M:%SZ"),
                           ACCRUAL_LAG_MAX_HOURS, clock_source)]
    for wave_id, last in rows:
        lines.append("  un-accrued?    : %s last machine up %s  <- inside the "
                     "lag window, so its cost may not be in MTD above"
                     % (wave_id, last.strftime("%Y-%m-%dT%H:%M:%SZ")))
    if why_unread:
        lines.append("  records unread : %s  <- these waves were NOT checked; "
                     "a zero below does not cover them (Ruling 6)" % why_unread)
    return lines


def certify_pending(instances, pending_supplied, cost_filters=None,
                    check_enabled=True, skip_reason="--no-accrual-check",
                    scope=None, waves=None):
    """Rulings 4 and 6.  Decide what the `pending` term is allowed to be.

    `instances` is a list of dicts (id / type / state / launched / project /
    region) or None when the enumeration itself could not be run.
    `pending_supplied` is the operator's `--pending`, or None when they did not
    pass one.  `scope` (Ruling 5) says which regions the list came from; a zero
    is only ever called account-wide when that scope is complete.  `waves`
    (Ruling 6) is the dict `read_wave_accrual` returns -- the SECOND
    precondition on the zero, on the budget snapshot's clock rather than on
    this instant.

    Returns (exit_code, lines, pending).  exit_code 0 means the caller may go
    on to the fence arithmetic; 2 means could-not-run and pending is None.
    """
    lines = []

    if not check_enabled:
        value = 0.0 if pending_supplied is None else pending_supplied
        lines.append(
            "accrual check    : SKIPPED, NOT CERTIFIED (%s). $%.3f below is "
            "an assumption, not a reading; quote this line in the round's "
            "report." % (skip_reason, value))
        return 0, lines, value

    if instances is None:
        if pending_supplied is not None:
            lines.append(
                "accrual check    : COULD NOT ENUMERATE instances; $%.3f is "
                "the operator's asserted figure and nothing cross-checked it."
                % pending_supplied)
            return 0, lines, pending_supplied
        lines.append(
            "UNCERTIFIABLE: could not enumerate running instances, so "
            "pending=$0.000 is an assumption rather than a reading.")
        lines.append(
            "Pass --pending with your own figure, or --no-accrual-check to "
            "say in writing that this term was skipped.")
        lines.append("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
        return 2, lines, None

    if cost_filters:
        lines.append(
            "budget filters   : %s  <- the untagged accrual below may "
            "OVER-count for a filtered budget (over-conservative; see Ruling "
            "4)" % json.dumps(cost_filters, sort_keys=True)[:200])
    else:
        lines.append(
            "budget filters   : none  <- so every instance in the account "
            "does land in this budget, whoever owns it")

    sline, complete = scope_line(scope)
    if sline:
        lines.append(sline)

    # Ruling 6: the wave-record half of the precondition.  It is printed
    # BEFORE the verdict on the zero because it can veto that verdict.
    wave_rows = []
    if waves:
        lines.extend(wave_accrual_lines(
            waves["rows"], waves.get("why_unread"), waves["clock"],
            waves["clock_source"], waves["cutoff"]))
        wave_rows = waves["rows"]

    # Ruling 7.  A degraded clock is no longer a caveat on an exit 0.  Placed
    # BEFORE every verdict branch because it invalidates all of them at once:
    # every branch below rests on the wave list, and the wave list was cut
    # with the wrong clock.  Note it fires whether or not `--pending` was
    # given -- that is the whole hole GH #692 measured, where a `--pending`
    # that covered every wave the tool NAMED still under-covered by $3.250
    # because the naming itself was short.
    if waves and waves.get("clock_degraded"):
        lines.append(
            "UNCERTIFIABLE: the wave-accrual window above was anchored to %s, "
            "not to the budget snapshot, so the wave list is NARROWER than "
            "the truth and pending cannot be certified from it (Ruling 7)."
            % waves.get("clock_source", "an unstated clock"))
        lines.append(
            "Re-run with --snapshot-instant <the budget LastUpdatedTime that "
            "check_costs.sh prints>, or pass --no-accrual-check and quote its "
            "SKIPPED line in the round's report.")
        lines.append("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
        return 2, lines, None

    # Deliberately NOT folded into Ruling 5's `complete`: that flag words its
    # caveat in terms of REGIONS, and a clock caveat printed in region
    # language would be exactly this file's recurring defect (a claim that
    # does not match its reading) committed while fixing it.
    #
    # Ruling 7 deliberately did NOT widen to `why_unread`: an unread record is
    # also permissive, but it is a different reading with a different remedy,
    # and GH #693 asked about the clock.  It stays a caveat on an exit 0, and
    # assertion 16f pins that boundary so the narrowing is visible rather than
    # forgotten.
    clock_caveat = None
    if waves and (waves.get("why_unread")
                  or waves.get("clock_source") != "budget snapshot"):
        clock_caveat = (
            "  zero qualified : the wave half above ran on %s%s, so this zero "
            "is not an accrual-complete one (Ruling 6)."
            % (waves.get("clock_source", "an unstated clock"),
               " and left records unread" if waves.get("why_unread") else ""))

    if not instances:
        where = "account-wide" if complete else "in the region(s) above"
        if pending_supplied is not None:
            lines.append(
                "accrual check    : CERTIFIED %s (0 accruing instances %s), "
                "but --pending $%.3f was given and is used as the larger "
                "claim." % ("ZERO" if complete else "ZERO WITHIN SCOPE",
                            where, pending_supplied))
            if wave_rows:
                # Ruling 6.  The tool still does not price waves -- but it does
                # say how many the figure has to cover, so a sum that quietly
                # omits one is visible AT THE POINT OF THE CLAIM rather than
                # three hours later in somebody's hand arithmetic.  That
                # omission is the whole of GH #683: the desk's $3.250 covered
                # W62 and W61 and dropped W60, because its window was anchored
                # to `now` while MTD was anchored to the snapshot.
                lines.append(
                    "  must cover     : %d wave(s) listed above (%s). This "
                    "tool does not price them; check your sum covers each."
                    % (len(wave_rows), ", ".join(r[0] for r in wave_rows)))
            if clock_caveat:
                lines.append(clock_caveat)
            return 0, lines, pending_supplied
        if wave_rows:
            # The half Ruling 4 got wrong: nothing is accruing NOW, and that
            # is not the question.  Do not price the waves -- a markup
            # constant here is the free parameter this file exists to remove.
            lines.append(
                "UNCERTIFIABLE: nothing is accruing at this instant, but %d "
                "wave(s) above launched inside the %.1fh ActualSpend lag, so "
                "pending=$0.000 is NOT certifiable (Ruling 6)."
                % (len(wave_rows), ACCRUAL_LAG_MAX_HOURS))
            lines.append(
                "A self-terminating wave is invisible to BOTH terms at once: "
                "gone from describe-instances, not yet in MTD. That gap is "
                "the farm's normal state between waves, not an edge case.")
            lines.append(
                "This tool does not price waves. Pass --pending with the "
                "desk's own figure (sum of the waves above), or pass "
                "--no-accrual-check and quote the SKIPPED line in your report.")
            lines.append("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
            return 2, lines, None
        if complete:
            lines.append(
                "accrual check    : CERTIFIED (0 accruing instances "
                "account-wide, read this run) -- pending $0.000 is a reading, "
                "not a default.")
        else:
            # "a reading, not a default" is orthogonal to scope and survives
            # verbatim: a one-region zero is still READ.  Dropping that clause
            # here is what assertion 11 caught when this branch was first
            # written -- Ruling 5 narrows the CLAIM, it does not demote the
            # reading to an assumption.
            lines.append(
                "accrual check    : CERTIFIED WITHIN SCOPE ONLY (0 accruing "
                "instances in the region(s) above, read this run) -- pending "
                "$0.000 is a reading, not a default, but it is NOT an "
                "account-wide zero: the budget has no region filter, so "
                "accrual in an unread region lands on this fence unseen "
                "(Ruling 5).")
        if clock_caveat:
            lines.append(clock_caveat)
        return 0, lines, 0.0

    for inst in instances:
        lines.append(
            "  accruing       : %s %s [%s] %s launched %s project=%s"
            % (inst.get("id", "?"), inst.get("type", "?"),
               inst.get("state", "?"), inst.get("region", "(region unread)"),
               inst.get("launched", "?"),
               inst.get("project") or "(untagged)"))

    if pending_supplied is not None:
        lines.append(
            "accrual check    : ASSERTED $%.3f by the operator; it must cover "
            "the %d instance(s) above, which this tool does not price."
            % (pending_supplied, len(instances)))
        return 0, lines, pending_supplied

    lines.append(
        "UNCERTIFIABLE: %d instance(s) are accruing charges right now and "
        "ActualSpend lags 4.3-11.3h behind, so pending=$0.000 is FALSE."
        % len(instances))
    lines.append(
        "This tool does not price arbitrary instances (a markup constant here "
        "would be the free parameter this whole file exists to remove).")
    lines.append(
        "Estimate the un-billed accrual yourself and pass --pending, or pass "
        "--no-accrual-check and quote the SKIPPED line in your report.")
    lines.append("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
    return 2, lines, None


def check(actual, limit, time_unit, notifications, planned=0.0, pending=0.0,
          brake=DEFAULT_BRAKE, owner_line=DEFAULT_OWNER_LINE, crossing=None):
    """Run the gate.  Returns (exit_code, list_of_report_lines).

    `crossing` is Ruling 10's validated director ruling (see build_crossing) or
    None.  It can only ever move the ceiling between the derived fence and the
    brake; it is never consulted before the brake or the no-fence refusal.
    """
    lines = []
    try:
        if time_unit != "MONTHLY":
            raise Uncertifiable(
                "budget TimeUnit is %r, not MONTHLY. This tool's whole reason "
                "for existing is that the crossed-threshold set RESETS "
                "monthly; on any other period that premise is unchecked."
                % (time_unit,))
        thresholds = resolve_thresholds(notifications, limit)
    except Uncertifiable as exc:
        return 2, [
            "UNCERTIFIABLE: %s" % exc,
            "gate (iii) DID NOT RUN. That is not a pass -- do not launch on it.",
            "WAVE_FENCE: UNCERTIFIABLE (exit 2)",
        ]

    projected = actual + pending + planned

    lines.append("budget           : %s (TimeUnit MONTHLY -- the crossed set "
                 "resets on the 1st)" % BUDGET_NAME)
    lines.append("limit            : $%.2f" % limit)
    lines.append("actual (MTD)     : $%.3f   <- re-read this run, never cached"
                 % actual)
    lines.append("pending waves    : $%.3f   (launched, may not be in MTD yet)"
                 % pending)
    lines.append("planned          : $%.3f" % planned)
    lines.append("projected total  : $%.3f" % projected)

    for t in thresholds:
        mark = "crossed" if actual > t["amount"] else "NOT yet crossed"
        how = "%g%% of limit" % t["raw"] if t["kind"] == "PERCENTAGE" \
            else "absolute $%g" % t["raw"]
        if t["assumed_kind"]:
            how += " (ThresholdType absent => PERCENTAGE, Ruling 2)"
        state = t["state"] if t["state"] is not None else "n/a (offline)"
        lines.append("  ACTUAL alert   : $%-7.2f %-15s [%s] AWS state=%s"
                     % (t["amount"], mark, how, state))

    bad = state_disagreements(thresholds, actual)
    if bad:
        for t, we_crossed, aws_crossed in bad:
            lines.append(
                "DISAGREEMENT at $%.2f: our arithmetic says %s, AWS "
                "NotificationState says %s."
                % (t["amount"],
                   "crossed" if we_crossed else "not crossed",
                   "ALARM (fired)" if aws_crossed else "OK (not fired)"))
        lines.append(
            "Ruling 3: either direction leaves the fence resting on a premise "
            "we cannot certify, and both directions are over-permissive.")
        lines.append("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
        return 2, lines

    fence_row = pick_fence(thresholds, actual)
    if fence_row is None:
        lines.append(
            "NO FENCE: MTD $%.3f is above every ACTUAL alert threshold, the "
            "top one included. There is no 'next owner-visible alert' left to "
            "stop in front of -- this is past the owner's $%.2f approval line "
            "and is the owner's decision, not this tool's."
            % (actual, owner_line))
        if crossing is not None:
            # Ruling 10's deliberate hole: past every alert there is no fence
            # left for a director to authorise crossing, and the next line is
            # the owner's, not this tool's.
            lines.append(
                "DIRECTOR CROSSING: ruling %s is NOT applied -- there is no "
                "fence left to cross. A crossing ruling raises the fence "
                "toward the brake; it is not a substitute for the owner's "
                "approval line." % crossing["ref"])
        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- stop and report to the "
                     "owner. Do not pick a higher number.")
        return 3, lines

    fence = fence_row["amount"]
    lines.append("fence            : $%.2f   <- lowest ACTUAL alert not yet "
                 "crossed (Ruling 1)" % fence)
    lines.append("brake            : $%.2f   (owner's line, not derived here)"
                 % brake)
    operative = min(fence, brake)
    underived = operative          # what the ceiling would be with no ruling
    lines.append("operative ceiling: $%.2f   = min(fence, brake)" % operative)

    if crossing is not None:
        operative = min(crossing["ceiling"], brake)
        lines.append(
            "DIRECTOR CROSSING: ceiling $%.2f by ruling %s, expires %s"
            % (crossing["ceiling"], crossing["ref"], crossing["expiry"]))
        lines.append(
            "                   derived fence $%.2f -> operative ceiling "
            "$%.2f = min(ruling, brake). The brake is untouched."
            % (fence, operative))
        if operative < underived:
            # RULING 15 (GH #754).  `min(ruling, brake)` HAS NO FLOOR, so the
            # same record raises the ceiling while the derived fence sits below
            # it and LOWERS the ceiling once the derived fence rises above it.
            # Nothing about the record changes -- MTD crosses a budget alert,
            # the next uncrossed alert becomes the fence, and a grant silently
            # becomes a cap.  Every line above still reads like a grant ("IS IN
            # FORCE ... It is applied below", "The brake is untouched"), and
            # all of them stay true, which is exactly why nobody looked: the
            # desk read `headroom $1.137` for three rounds and filed the
            # shortfall as a money problem.  It was a $5.00 self-inflicted one.
            lines.append(
                "                   *** RESTRICTIVE RIGHT NOW: this ruling is "
                "COSTING $%.2f of headroom, not buying any. Without it the "
                "operative ceiling would be $%.2f = min(derived fence $%.2f, "
                "brake $%.2f). A crossing is applied as min(ruling, brake) and "
                "that min has no floor, so a ruling written to RAISE a low "
                "derived fence becomes a CAP the moment MTD crosses an alert "
                "and the fence jumps above it. If the director meant a cap, "
                "this line is the cap working. If the director meant a "
                "crossing, THE RULING HAS FINISHED and belongs in `_retired`."
                % (underived - operative, underived, fence, brake))
        lines.append(
            "                   This line is a RULING, not a reading. Quote it "
            "verbatim in the round's report, and re-run the tool -- the expiry "
            "above is checked on every run, so this ceiling cannot outlive the "
            "ruling by being copied forward.")

    if projected > brake:
        lines.append("A launch at this instant would put MTD past the $%.2f "
                     "BRAKE line." % brake)
        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- brake, not fence. Stop "
                     "and report to the owner; do not wait it out.")
        return 3, lines
    if projected > operative:
        if crossing is not None and operative < underived:
            # RULING 15.  The sentence below used to be the only one on this
            # path, and on a RESTRICTIVE ruling every clause of it is false:
            # the ruling bought no band, and the wave is NOT past anything the
            # fence or the brake would have stopped.  This is the sentence the
            # desk quoted into GH #754 as a money shortfall.
            lines.append(
                "A launch at this instant would put MTD past $%.2f, the "
                "ceiling the director's own ruling %s named -- BUT THAT "
                "CEILING IS $%.2f BELOW WHAT THE FENCE AND THE BRAKE ALLOW ON "
                "THEIR OWN ($%.2f). This wave needs $%.3f and the UNDERIVED "
                "headroom is $%.3f, so THE MONEY IS THERE and a ruling is what "
                "is refusing. The ruling is still being obeyed, not "
                "overridden. Do NOT re-plan the wave around this number and do "
                "NOT pick a cheaper market to fit under it: take it back to "
                "the director, who either meant this cap or has a ruling to "
                "retire."
                % (operative, crossing["ref"], underived - operative,
                   underived, planned, underived - actual - pending))
        elif crossing is not None:
            lines.append(
                "A launch at this instant would put MTD past $%.2f, the "
                "ceiling the director's own ruling %s named. The ruling is "
                "being obeyed, not overridden: it bought a band, and this "
                "wave is past the top of it."
                % (operative, crossing["ref"]))
        else:
            # Ruling 11(A).  This sentence used to say the ruling had to be
            # the director's "that round", which excludes every standing
            # ruling -- and Ruling 10's mechanism IS a standing ruling with an
            # expiry.  What binds is unexpired AT THIS INSTANT, which is what
            # the code checks; the prose described a different tool, and the
            # desk obeyed the prose two hours after a live ruling was granted.
            lines.append(
                "A launch at this instant would put MTD past $%.2f, i.e. the "
                "owner receives a Budget alert email. Crossing needs a "
                "director crossing ruling that has NOT EXPIRED at this "
                "instant -- it does NOT have to have been issued this round; "
                "a standing ruling is in force until its expiry. No such "
                "ruling was found: see the `crossing registry` line above for "
                "what was read. If one exists, it belongs in "
                "iterations/director_rulings.json (Ruling 11) where this tool "
                "reads it by itself; --director-crossing / --crossing-ref / "
                "--crossing-expiry remain for a ruling made mid-round."
                % fence)
        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- do not launch. Headroom "
                     "was $%.3f, this wave needs $%.3f."
                     % (operative - actual - pending, planned))
        return 3, lines

    lines.append("headroom         : $%.3f after this wave"
                 % (operative - projected))
    if crossing is not None and projected > fence:
        # Only say "the ruling is why this passed" when the ruling is in fact
        # why it passed.  A crossing that was carried but not needed must not
        # read as one that was spent -- that is how a ruling gets remembered as
        # load-bearing when the derived fence would have cleared the wave alone.
        lines.append(
            "WAVE_FENCE: CLEAR (exit 0) -- gate (iii) passes ONLY BECAUSE OF "
            "RULING %s. The derived fence $%.2f was NOT met; the ceiling that "
            "was met is $%.2f, and it is a ruling with an expiry, not a "
            "reading. Do not copy either number forward; re-run the tool."
            % (crossing["ref"], fence, operative))
        return 0, lines
    if crossing is not None:
        lines.append(
            "WAVE_FENCE: CLEAR (exit 0) -- gate (iii) passes on the fence "
            "DERIVED THIS RUN ($%.2f); ruling %s was carried but NOT needed "
            "for this wave. Do not copy $%.2f forward; re-run the tool."
            % (fence, crossing["ref"], fence))
        return 0, lines
    lines.append("WAVE_FENCE: CLEAR (exit 0) -- gate (iii) passes with the "
                 "fence DERIVED THIS RUN. Do not copy $%.2f into a report as "
                 "next month's number; re-run the tool." % fence)
    return 0, lines


# ------------------------------------------------------------------- AWS I/O

def _awsx(args):
    try:
        proc = subprocess.run(["awsx"] + args, capture_output=True, text=True)
    except FileNotFoundError:
        raise Uncertifiable(
            "`awsx` not found. Run tools/batch_test/aws/session_setup.sh "
            "first; never call `aws` directly (the proxy shadows AWS_*).")
    if proc.returncode != 0:
        raise Uncertifiable("awsx %s failed (rc=%d): %s"
                            % (" ".join(args), proc.returncode,
                               proc.stderr.strip()[:400]))
    try:
        return json.loads(proc.stdout)
    except ValueError:
        raise Uncertifiable("awsx %s returned unparseable JSON"
                            % " ".join(args))


def read_from_aws(budget_name=BUDGET_NAME):
    """Both free reads.

    Returns (actual, limit, time_unit, notifications, cost_filters,
    last_updated).  `last_updated` is Ruling 6's clock: the instant the MTD
    figure above was itself refreshed, which is NOT this instant and was
    3.9h stale on the round that filed the ruling.
    """
    ident = _awsx(["sts", "get-caller-identity", "--output", "json"])
    acct = ident.get("Account")
    if not acct:
        raise Uncertifiable("could not read the account id")
    budget = _awsx(["budgets", "describe-budget", "--account-id", acct,
                    "--budget-name", budget_name, "--output", "json"])
    try:
        b = budget["Budget"]
        actual = float(b["CalculatedSpend"]["ActualSpend"]["Amount"])
        limit = float(b["BudgetLimit"]["Amount"])
        time_unit = b["TimeUnit"]
    except (KeyError, TypeError, ValueError) as exc:
        raise Uncertifiable("budget payload missing a field: %s" % exc)
    notes = _awsx(["budgets", "describe-notifications-for-budget",
                   "--account-id", acct, "--budget-name", budget_name,
                   "--output", "json"])
    return (actual, limit, time_unit, notes.get("Notifications", []),
            b.get("CostFilters") or {}, b.get("LastUpdatedTime"))


def read_wave_accrual(waves_dir, last_updated, now=None,
                      asserted_instant=None):
    """Ruling 6.  The wave-record precondition on a certified zero.

    Returns the dict `certify_pending` consumes.  `clock_degraded` (Ruling 7)
    is the load-bearing field: True means the window was anchored to `now`
    because no snapshot instant could be had, which is the PERMISSIVE
    direction (a later clock is a narrower window, so waves drop out of
    pending by construction).  Under Ruling 7 that flag stops the gate; it is
    no longer a label on an exit 0.

    `asserted_instant` is the operator's own `--snapshot-instant`: a clock
    they read somewhere this tool could not (`check_costs.sh` prints the same
    `LastUpdatedTime` this parser wants).  It is a CLAIM, so it is labelled as
    one -- but it is a clock, so it is not degraded.
    """
    now = now or _dt.datetime.now(_dt.timezone.utc)
    clock = parse_snapshot_instant(asserted_instant)
    if clock is not None:
        clock_source, degraded = (
            "snapshot instant ASSERTED by the operator (--snapshot-instant)",
            False)
    else:
        clock = parse_snapshot_instant(last_updated)
        if clock is None:
            clock, clock_source, degraded = (
                now, "now (budget LastUpdatedTime unreadable)", True)
        else:
            clock_source, degraded = "budget snapshot", False
    cutoff = clock - _dt.timedelta(hours=ACCRUAL_LAG_MAX_HOURS)
    rows, why_unread = waves_since(waves_dir, cutoff)
    return {"rows": rows, "why_unread": why_unread, "clock": clock,
            "clock_source": clock_source, "cutoff": cutoff,
            "clock_degraded": degraded}


def parse_instances(payload):
    """Pure: flatten a describe-instances payload to the rows Ruling 4 prints.

    Only ACCRUING_STATES are kept.  Deliberately NOT filtered by tag: the
    budget is unfiltered, so somebody else's instance spends our headroom.
    """
    rows = []
    for res in payload.get("Reservations", []):
        for inst in res.get("Instances", []):
            state = (inst.get("State") or {}).get("Name")
            if state not in ACCRUING_STATES:
                continue
            project = None
            for tag in inst.get("Tags") or []:
                if tag.get("Key") == "Project":
                    project = tag.get("Value")
                    break
            rows.append({
                "id": inst.get("InstanceId"),
                "type": inst.get("InstanceType"),
                "state": state,
                "launched": inst.get("LaunchTime"),
                "project": project,
            })
    rows.sort(key=lambda r: (r["launched"] or "", r["id"] or ""))
    return rows


def read_regions():
    """The account's enabled regions (`ec2 describe-regions`, free).

    Raises Uncertifiable when the call cannot be made -- `dota2bot-agent` is
    permission-scoped and may not carry `ec2:DescribeRegions`.  The caller
    degrades the CLAIM, not the gate (Ruling 5).
    """
    payload = _awsx(["ec2", "describe-regions", "--output", "json"])
    names = sorted(r.get("RegionName") for r in payload.get("Regions", [])
                   if r.get("RegionName"))
    if not names:
        raise Uncertifiable("describe-regions returned no region names")
    return names


def read_accruing_instances():
    """Ruling 4's free read.  No tag filter, never priced.

    Returns (rows, scope).  `ec2 describe-instances` is REGIONAL, so one call
    reads one region; Ruling 5 is why the scope travels with the rows instead
    of the caller assuming it covered the account.
    """
    filters = ["Name=instance-state-name,Values=" + ",".join(ACCRUING_STATES)]

    def read_one(region=None):
        args = ["ec2", "describe-instances", "--filters"] + filters
        if region:
            args += ["--region", region]
        return parse_instances(_awsx(args + ["--output", "json"]))

    try:
        regions = read_regions()
    except Uncertifiable as exc:
        rows = read_one()                       # the configured default region
        for row in rows:
            row["region"] = "(configured default)"
        return rows, {"regions": ["(configured default)"], "complete": False,
                      "why": "describe-regions unavailable: %s"
                             % str(exc)[:120]}

    rows, read, failed = [], [], []
    for region in regions:
        try:
            found = read_one(region)
        except Uncertifiable as exc:
            failed.append("%s (%s)" % (region, str(exc)[:60]))
            continue
        read.append(region)
        for row in found:
            row["region"] = region
            rows.append(row)
    rows.sort(key=lambda r: (r["launched"] or "", r["id"] or ""))
    scope = {"regions": read, "complete": not failed}
    if failed:
        scope["why"] = "%d region(s) unreadable: %s" % (len(failed),
                                                        "; ".join(failed))
    return rows, scope


# ----------------------------------------------------------------- CLI

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Gate (iii): the monthly spend fence, derived not cached.")
    parser.add_argument("--planned", type=float, default=0.0,
                        help="estimated cost of the wave about to launch")
    parser.add_argument("--pending", type=float, default=None,
                        help="already-launched waves that may not be in MTD "
                             "yet (the desk's Sigma term). Omitting it no "
                             "longer means $0 -- see Ruling 4: the zero has "
                             "to be certifiable")
    parser.add_argument("--no-accrual-check", action="store_true",
                        help="skip Ruling 4's running-instance read AND "
                             "Ruling 6's wave-record read. Prints a line "
                             "calling itself SKIPPED, not certified; quote "
                             "that line in the round's report.")
    parser.add_argument("--snapshot-instant", default=None,
                        help="Ruling 7: the budget's own LastUpdatedTime, "
                             "asserted by the operator when this tool cannot "
                             "read it (check_costs.sh prints it). Accepts an "
                             "ISO-8601 instant or an epoch. It is labelled as "
                             "a claim, but it is a clock, so the gate runs.")
    parser.add_argument("--waves-dir", default=wave_throttle.DEFAULT_WAVES_DIR,
                        help="Ruling 6: where the wave records live. A wave "
                             "launched inside the ActualSpend lag makes "
                             "pending=$0 uncertifiable even with nothing "
                             "running.")
    parser.add_argument("--director-crossing", type=float, default=None,
                        metavar="CEILING",
                        help="RULING 10: an expiring director ruling that "
                             "raises the operative ceiling above the DERIVED "
                             "fence, never above --brake. Requires "
                             "--crossing-ref and --crossing-expiry. This is "
                             "not a bypass: with it the gate still runs, still "
                             "prints, and still refuses -- it just refuses "
                             "against the number the ruling named.")
    parser.add_argument("--crossing-ref", default=None, metavar="REF",
                        help="the ruling being invoked (issue + report path). "
                             "Printed verbatim so the round's report carries "
                             "what authorised the crossing.")
    parser.add_argument("--crossing-expiry", default=None, metavar="INSTANT",
                        help="when the ruling dies (ISO-8601 or epoch). "
                             "Mandatory, and checked before the gate runs: a "
                             "crossing ruling that cannot expire becomes the "
                             "permanent ceiling.")
    parser.add_argument("--crossing-file", default=DEFAULT_RULINGS_FILE,
                        metavar="PATH",
                        help="RULING 11: the standing-ruling registry this "
                             "tool reads BY ITSELF, so a live ruling does not "
                             "depend on the operator remembering three flags. "
                             "What it found is printed on every run, "
                             "including when it found nothing.")
    parser.add_argument("--no-crossing-file", action="store_true",
                        help="RULING 11: do not consult the registry. Prints "
                             "a line calling itself NOT CONSULTED; a standing "
                             "ruling may exist and this run did not look.")
    parser.add_argument("--brake", type=float, default=DEFAULT_BRAKE)
    parser.add_argument("--owner-line", type=float, default=DEFAULT_OWNER_LINE)
    parser.add_argument("--budget-name", default=BUDGET_NAME)
    parser.add_argument("--actual", type=float,
                        help="offline mode: MTD instead of reading AWS")
    parser.add_argument("--limit", type=float,
                        help="offline mode: budget limit")
    parser.add_argument("--thresholds",
                        help="offline mode: comma-separated ACTUAL thresholds, "
                             "read as PERCENTAGE of --limit")
    parser.add_argument("--time-unit", default="MONTHLY",
                        help="offline mode: budget TimeUnit")
    args = parser.parse_args(argv)

    # Ruling 7.  An unparseable assertion is refused HERE -- before the
    # offline/online split, and before anything is read -- rather than
    # ignored.  Silently falling back would answer a question the operator
    # did not ask, in the permissive direction, which is the shape of every
    # defect this file has been fixed for.  Validating it early also puts it
    # where a test without an AWS account can reach it; the live branch is
    # exactly where it would otherwise never be exercised (GH #692's own
    # lesson: the shape that bit us had never been in the input set).
    if (args.snapshot_instant is not None
            and parse_snapshot_instant(args.snapshot_instant) is None):
        print("UNCERTIFIABLE: --snapshot-instant %r is not an instant this "
              "tool can read (want ISO-8601 or an epoch)."
              % args.snapshot_instant)
        print("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
        return 2

    # Ruling 10, validated in the same place and for the same reason Ruling 7
    # is: before anything is read, so a malformed or expired ruling cannot be
    # discovered halfway through and cannot be reached only on the live path.
    crossing, crossing_error = build_crossing(
        args.director_crossing, args.crossing_ref, args.crossing_expiry,
        brake=args.brake, owner_line=args.owner_line)
    if crossing_error is not None:
        print("UNCERTIFIABLE: %s" % crossing_error)
        print("gate (iii) DID NOT RUN. That is not a pass -- do not launch.")
        print("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
        return 2

    # Ruling 11.  Validated in the same place and for the same reason: before
    # anything is read.  The registry speaks on EVERY run -- "nothing in
    # force" is a reading, and it is the one whose silence cost W64.
    if args.no_crossing_file:
        print("crossing registry: NOT CONSULTED (--no-crossing-file). A "
              "standing ruling may be in force and this run did not look; "
              "that is a SKIP, not a finding of none.")
    else:
        standing, notes, registry_error = load_standing_crossing(
            args.crossing_file, brake=args.brake, owner_line=args.owner_line)
        for note in notes:
            print(note)
        if registry_error is not None:
            print("UNCERTIFIABLE: %s" % registry_error)
            print("gate (iii) DID NOT RUN. That is not a pass -- do not "
                  "launch.")
            print("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
            return 2
        if crossing is not None and standing is not None:
            # Both spoke.  The flag wins -- it is this round's assertion --
            # but the override is announced, because a flag silently shadowing
            # a standing ruling is how the registry would stop being read.
            print("crossing registry: ruling %s is IN FORCE but is OVERRIDDEN "
                  "by the --director-crossing flags given this round (%s). "
                  "The flag is what binds below."
                  % (standing["ref"], crossing["ref"]))
        elif standing is not None:
            crossing = standing

    offline = args.actual is not None
    instances = None
    cost_filters = None
    scope = None
    waves = None
    last_updated = None
    try:
        if offline:
            if args.limit is None or args.thresholds is None:
                raise Uncertifiable(
                    "offline mode needs --actual, --limit and --thresholds")
            notes = [{"NotificationType": "ACTUAL",
                      "ComparisonOperator": "GREATER_THAN",
                      "Threshold": float(x)}
                     for x in args.thresholds.split(",")]
            actual, limit = args.actual, args.limit
            time_unit = args.time_unit
        else:
            (actual, limit, time_unit, notes, cost_filters,
             last_updated) = read_from_aws(args.budget_name)
    except Uncertifiable as exc:
        print("UNCERTIFIABLE: %s" % exc)
        print("gate (iii) DID NOT RUN. That is not a pass -- do not launch.")
        print("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
        return 2

    if offline:
        print("source           : OFFLINE (--actual/--limit/--thresholds). "
              "This is for tests and post-hoc audit; a launch must use the "
              "AWS read.")
        # Offline is audit mode: there is no live account to enumerate, so
        # Ruling 4 has nothing to certify from and says so rather than
        # pretending the zero was read.
        accrual_enabled = False
        skip_reason = "offline mode: no live account to enumerate"
    else:
        skip_reason = "--no-accrual-check"
        accrual_enabled = not args.no_accrual_check
        if accrual_enabled:
            try:
                instances, scope = read_accruing_instances()
            except Uncertifiable as exc:
                print("accrual read     : FAILED -- %s" % exc)
                instances, scope = None, None
            waves = read_wave_accrual(args.waves_dir, last_updated,
                                      asserted_instant=args.snapshot_instant)

    acc_code, acc_lines, pending = certify_pending(
        instances, args.pending, cost_filters=cost_filters,
        check_enabled=accrual_enabled, skip_reason=skip_reason, scope=scope,
        waves=waves)
    for line in acc_lines:
        print(line)
    if acc_code != 0:
        return acc_code

    code, lines = check(actual, limit, time_unit, notes,
                        planned=args.planned, pending=pending,
                        brake=args.brake, owner_line=args.owner_line,
                        crossing=crossing)
    for line in lines:
        print(line)
    # Ruling 5: the caveat rides AFTER the verdict, because the verdict line is
    # the one that gets copied into the round's report.
    _, complete = scope_line(scope)
    if scope and not complete:
        print("WAVE_FENCE SCOPE : the accrual zero above covered %d region(s), "
              "NOT the account (%s). Quote this line in the round's report."
              % (len(scope.get("regions") or []),
                 scope.get("why") or "enumeration incomplete"))
    # Ruling 6 rides after the verdict for the same reason Ruling 5 does.
    # Ruling 7 emptied the degraded case out of here (it cannot reach a
    # verdict any more), so what is left is the operator's asserted clock:
    # still not a reading, still travelling with the copied sentence.
    if waves and waves.get("clock_source") != "budget snapshot":
        print("WAVE_FENCE CLOCK : the wave-accrual window above was anchored "
              "to %s -- a claim, not a reading. Quote this line in the "
              "round's report." % waves["clock_source"])
    return code


if __name__ == "__main__":
    sys.exit(main())
