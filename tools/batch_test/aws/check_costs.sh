#!/usr/bin/env bash
# Sanity check: nothing left running, and what this month has cost so far.
#
# Cost of the check itself (batch-desk 2026-08-21T08:xxZ):
#   `ce get-cost-and-usage` is billed at $0.01 PER REQUEST. The charter calls
#   this script twice per trigger (step 2 + step 6), 12 triggers/day
#   => 24 requests/day = $0.24/day = ~$7.3/month, measured on the bill
#   (service "AWS Cost Explorer", qty 24 on 08-19, qty 23 on 08-20).
#   That is 16% of the desk's own $45 fence, and on a zero-batch day it is the
#   single largest marginal line — bigger than the standing AMI snapshot cost.
#   `budgets describe-budgets` reports the same ActualSpend for free and is at
#   least as fresh (verified 2026-08-21: budgets 18.277 vs ce 18.2767, budget
#   LastUpdatedTime 06:37Z while CE had no row for the current day at all).
#   So the MTD number comes from Budgets by default; CE is kept for the cases
#   where it actually earns its $0.01: a near-brake confirmation, or a
#   per-day/per-service breakdown.
#
# ⭐ ABOVE THE BRAKE, THE CONFIRMATION BUYS NOTHING (GH #801, director
# 2026-09-13). The auto-confirmation above fires on `MTD >= CONFIRM_AT` alone,
# so it keeps paying $0.01 every trigger AFTER the brake has already closed the
# gate. Measured by the batch desk 2026-09-13: $0.116/day, and on this month's
# first zero-batch day the `AWS Cost Explorer` line was $0.040 of $0.075 total
# published spend — 53.1%, the single largest item, with no EC2 row at all.
# The failure direction is the dangerous one: the script spends most reliably
# exactly when there is least room left to spend.
#   The confirmation's legislative purpose is to make a LAUNCH DECISION safe.
#   When headroom to the brake can no longer fit even the cheapest wave
#   ($1.10), no launch decision exists, so there is nothing to confirm.
#   => the auto-confirmation now also requires `brake - MTD >= CHEAPEST_WAVE`.
# ⛔ It is a SKIP, not a pass, and it says so on stdout — the decision is never
#   silent, and it resumes by itself the moment headroom returns.
# ⚠️ Fail direction, on purpose: if the brake cannot be read, the script PAYS
#   (a missing brake must never be able to silence the confirmation).
#
# Usage:
#   check_costs.sh                 # instances + MTD (free) + AMI
#   check_costs.sh --ce            # force the paid Cost Explorer read ($0.01)
#   check_costs.sh --budgets-only  # never fall back to CE, even on failure
#   check_costs.sh --leak-only     # instances only; no cost lookup at all
#   COST_BRAKE_AT= COST_CHEAPEST_WAVE=  # override the two numbers above
#   COST_BRAKE_AT=0                     # disable the headroom condition
#   COST_BRAKE_SRC=<dir>                # where to import wave_fence from
#                                       # (test seam; see the note below)
set -euo pipefail
cd "$(dirname "$0")"
source aws.env

# In agent sessions the raw `aws` CLI fails (proxy placeholder AWS_* env vars
# shadow the real key) — route through the awsx wrapper when it exists.
if command -v awsx >/dev/null 2>&1; then aws() { awsx "$@"; }; fi

BUDGET_NAME=${BUDGET_NAME:-dota2bot-batch}
# Spend at/above which the free reading is no longer good enough on its own and
# we pay the $0.01 to confirm against Cost Explorer. Set below the $45 fence so
# the confirmation happens before, not after, a launch decision gets close.
CONFIRM_AT=${COST_CONFIRM_AT:-35}

# GH #801. The brake line, and the cheapest wave that could ever be launched.
# The brake is read from wave_fence.py so there is ONE definition of it in the
# repo, not a second copy drifting here. `$1.10/wave` is the batch desk's
# cheapest-wave constant (spot 4x1; re-ruled 2026-09-09, not disproven).
#
# ⚠️ An UNREADABLE brake leaves BRAKE_AT empty on purpose, and an empty
# BRAKE_AT makes the headroom condition vacuous, i.e. the confirmation is
# PAID. The other fallback (substitute 90.00 and carry on) would let an
# owner-raised brake be silently ignored, and the confirmation would then be
# skipped in exactly the situation where launches are possible again.
#
# COST_BRAKE_SRC exists so that "wave_fence cannot be read" is REACHABLE from a
# test.  Without it the paragraph above is an untested promise: a mutant that
# substitutes 90.00 here survives every test, because no test can make the
# import fail.  (Measured: it did survive, 2026-09-13, and that is why this
# seam exists.)  It can only ever change whether this script pays $0.01 --
# wave_fence.py itself remains the launch gate and does not read this.
BRAKE_SRC=${COST_BRAKE_SRC:-../soak}
BRAKE_AT=${COST_BRAKE_AT:-$(python3 -c \
    "import sys; sys.path.insert(0, sys.argv[1]); import wave_fence; \
print('%.2f' % wave_fence.DEFAULT_BRAKE)" "$BRAKE_SRC" 2>/dev/null || true)}
CHEAPEST_WAVE=${COST_CHEAPEST_WAVE:-1.10}

MODE=auto
for arg in "$@"; do
    case "$arg" in
        --ce)           MODE=ce ;;
        --budgets-only) MODE=budgets ;;
        --leak-only)    MODE=leak ;;
        # 2,43 = the whole comment header, ending on the last Usage line.
        # (It used to read 2,26, which stopped mid-header and then printed
        # three lines of code; the header has grown since.)
        # `basename`, not `$0`: the script has already cd'd into its own
        # directory above, so a relative `$0` no longer resolves and --help
        # died with "can't read ..." for every caller outside that directory.
        -h|--help)      sed -n '2,43p' "$(basename "$0")"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

mtd_from_ce() {  # $0.01 per call
    local start end
    start=$(date +%Y-%m-01)
    end=$(date -d tomorrow +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d)
    aws ce get-cost-and-usage --time-period Start="$start",End="$end" \
        --granularity MONTHLY --metrics UnblendedCost \
        --query 'ResultsByTime[0].Total.UnblendedCost.[Amount,Unit]' --output text
}

mtd_from_budgets() {  # free
    local acct
    acct=$(aws sts get-caller-identity --query Account --output text)
    aws budgets describe-budgets --account-id "$acct" \
        --query "Budgets[?BudgetName=='${BUDGET_NAME}']|[0].[CalculatedSpend.ActualSpend.Amount,CalculatedSpend.ForecastedSpend.Amount,BudgetLimit.Amount,LastUpdatedTime]" \
        --output text
}

echo "== running/pending instances (should be empty unless a batch is live) =="
aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=pending,running" \
              "Name=tag:Name,Values=dota2bot-*" \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`]|[0].Value]' \
    --output table

if [[ "$MODE" == "leak" ]]; then
    echo "== month-to-date cost == (skipped: --leak-only)"
else
    echo "== month-to-date cost =="
    if [[ "$MODE" == "ce" ]]; then
        mtd_from_ce
        echo "   source: cost-explorer (billed \$0.01 for this call)"
    else
        if read -r ACTUAL FORECAST LIMIT UPDATED < <(mtd_from_budgets 2>/dev/null) \
           && [[ -n "${ACTUAL:-}" && "$ACTUAL" != "None" ]]; then
            printf '%s\tUSD\n' "$ACTUAL"
            printf '   source: budgets/%s (free) | forecast %s | budget limit %s | budget refreshed %s\n' \
                "$BUDGET_NAME" "$FORECAST" "$LIMIT" \
                "$(python3 -c "import datetime,sys;print(datetime.datetime.utcfromtimestamp(float(sys.argv[1])).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$UPDATED" 2>/dev/null || echo "$UPDATED")"
            # Near a brake line the free number stops being good enough alone.
            if [[ "$MODE" == "auto" ]] \
               && python3 -c "import sys;sys.exit(0 if float(sys.argv[1])>=float(sys.argv[2]) else 1)" "$ACTUAL" "$CONFIRM_AT" 2>/dev/null; then
                # GH #801: ...unless the brake has already made every launch
                # impossible, in which case there is no decision to confirm.
                # An empty/unparseable BRAKE_AT falls through to PAYING.
                # A non-positive brake means "no brake known" and prints
                # nothing, so COST_BRAKE_AT=0 disables the condition (pays).
                HEADROOM=$(python3 -c "import sys
b = float(sys.argv[1])
if b > 0:
    print('%.3f' % (b - float(sys.argv[2])))" "${BRAKE_AT:-}" "$ACTUAL" 2>/dev/null || true)
                if [[ -n "$HEADROOM" ]] \
                   && python3 -c "import sys;sys.exit(0 if float(sys.argv[1])<float(sys.argv[2]) else 1)" "$HEADROOM" "$CHEAPEST_WAVE" 2>/dev/null; then
                    echo "   >= \$$CONFIRM_AT, but headroom to the \$$BRAKE_AT brake is \$$HEADROOM"
                    echo "   < \$$CHEAPEST_WAVE (cheapest wave) — CE confirmation SKIPPED, NOT passed (GH #801)."
                    echo "   Nothing can launch at this MTD, so confirming it buys nothing."
                    echo "   Resumes by itself as soon as headroom >= \$$CHEAPEST_WAVE."
                else
                    echo "   >= \$$CONFIRM_AT — confirming against cost-explorer (\$0.01):"
                    mtd_from_ce | sed 's/^/   /'
                    [[ -n "$HEADROOM" ]] \
                        || echo "   (brake unreadable — paid anyway; GH #801 fails toward paying)"
                fi
            fi
        elif [[ "$MODE" == "budgets" ]]; then
            echo "   ERROR: budgets read failed and --budgets-only forbids the CE fallback" >&2
            exit 1
        else
            echo "   (budgets read failed — falling back to cost-explorer, \$0.01)" >&2
            mtd_from_ce
        fi
    fi
fi

echo "== AMI + snapshots (the only standing cost) =="
aws ec2 describe-images --region "$AWS_REGION" --owners self \
    --filters "Name=name,Values=dota2bot-batch-*" \
    --query 'Images[].[ImageId,Name,CreationDate]' --output table
