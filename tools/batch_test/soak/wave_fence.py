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
import json
import subprocess
import sys

BUDGET_NAME = "dota2bot-batch"
DEFAULT_BRAKE = 90.0          # owner's brake line; see AGENTS.md AWS policy
DEFAULT_OWNER_LINE = 100.0    # owner's approval line; reported, never applied


class Uncertifiable(Exception):
    """The check could not be run.  Exit 2 -- this is not a pass."""


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


def check(actual, limit, time_unit, notifications, planned=0.0, pending=0.0,
          brake=DEFAULT_BRAKE, owner_line=DEFAULT_OWNER_LINE):
    """Run the gate.  Returns (exit_code, list_of_report_lines)."""
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
        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- stop and report to the "
                     "owner. Do not pick a higher number.")
        return 3, lines

    fence = fence_row["amount"]
    lines.append("fence            : $%.2f   <- lowest ACTUAL alert not yet "
                 "crossed (Ruling 1)" % fence)
    lines.append("brake            : $%.2f   (owner's line, not derived here)"
                 % brake)
    operative = min(fence, brake)
    lines.append("operative ceiling: $%.2f   = min(fence, brake)" % operative)

    if projected > brake:
        lines.append("A launch at this instant would put MTD past the $%.2f "
                     "BRAKE line." % brake)
        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- brake, not fence. Stop "
                     "and report to the owner; do not wait it out.")
        return 3, lines
    if projected > fence:
        lines.append(
            "A launch at this instant would put MTD past $%.2f, i.e. the owner "
            "receives a Budget alert email. Crossing needs the director's "
            "explicit ruling that round, plus the written explanation the "
            "charter owes for every crossed threshold." % fence)
        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- do not launch. Headroom "
                     "was $%.3f, this wave needs $%.3f."
                     % (fence - actual - pending, planned))
        return 3, lines

    lines.append("headroom         : $%.3f after this wave" % (fence - projected))
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
    """Both free reads.  Returns (actual, limit, time_unit, notifications)."""
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
    return actual, limit, time_unit, notes.get("Notifications", [])


# ----------------------------------------------------------------- CLI

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Gate (iii): the monthly spend fence, derived not cached.")
    parser.add_argument("--planned", type=float, default=0.0,
                        help="estimated cost of the wave about to launch")
    parser.add_argument("--pending", type=float, default=0.0,
                        help="already-launched waves that may not be in MTD "
                             "yet (the desk's Sigma term)")
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

    offline = args.actual is not None
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
            actual, limit, time_unit, notes = read_from_aws(args.budget_name)
    except Uncertifiable as exc:
        print("UNCERTIFIABLE: %s" % exc)
        print("gate (iii) DID NOT RUN. That is not a pass -- do not launch.")
        print("WAVE_FENCE: UNCERTIFIABLE (exit 2)")
        return 2

    if offline:
        print("source           : OFFLINE (--actual/--limit/--thresholds). "
              "This is for tests and post-hoc audit; a launch must use the "
              "AWS read.")

    code, lines = check(actual, limit, time_unit, notes,
                        planned=args.planned, pending=args.pending,
                        brake=args.brake, owner_line=args.owner_line)
    for line in lines:
        print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
