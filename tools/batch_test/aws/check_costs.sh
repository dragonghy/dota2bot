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
# Usage:
#   check_costs.sh                 # instances + MTD (free) + AMI
#   check_costs.sh --ce            # force the paid Cost Explorer read ($0.01)
#   check_costs.sh --budgets-only  # never fall back to CE, even on failure
#   check_costs.sh --leak-only     # instances only; no cost lookup at all
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

MODE=auto
for arg in "$@"; do
    case "$arg" in
        --ce)           MODE=ce ;;
        --budgets-only) MODE=budgets ;;
        --leak-only)    MODE=leak ;;
        -h|--help)      sed -n '2,26p' "$0"; exit 0 ;;
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
                echo "   >= \$$CONFIRM_AT — confirming against cost-explorer (\$0.01):"
                mtd_from_ce | sed 's/^/   /'
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
