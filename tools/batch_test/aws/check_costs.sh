#!/usr/bin/env bash
# Sanity check: nothing left running, and what this month has cost so far.
set -euo pipefail
cd "$(dirname "$0")"
source aws.env

# In agent sessions the raw `aws` CLI fails (proxy placeholder AWS_* env vars
# shadow the real key) — route through the awsx wrapper when it exists.
if command -v awsx >/dev/null 2>&1; then aws() { awsx "$@"; }; fi

echo "== running/pending instances (should be empty unless a batch is live) =="
aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=pending,running" \
              "Name=tag:Name,Values=dota2bot-*" \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime,Tags[?Key==`Name`]|[0].Value]' \
    --output table

echo "== month-to-date cost =="
START=$(date +%Y-%m-01)
END=$(date -d tomorrow +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d)
aws ce get-cost-and-usage --time-period Start="$START",End="$END" \
    --granularity MONTHLY --metrics UnblendedCost \
    --query 'ResultsByTime[0].Total.UnblendedCost.[Amount,Unit]' --output text

echo "== AMI + snapshots (the only standing cost) =="
aws ec2 describe-images --region "$AWS_REGION" --owners self \
    --filters "Name=name,Values=dota2bot-batch-*" \
    --query 'Images[].[ImageId,Name,CreationDate]' --output table
