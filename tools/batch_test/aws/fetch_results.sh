#!/usr/bin/env bash
# Pull batch results from S3 and print the A/B report.
#   ./fetch_results.sh              # list available runs
#   ./fetch_results.sh <run_id>     # download + report
set -euo pipefail
cd "$(dirname "$0")"
source aws.env

if [ $# -eq 0 ]; then
    echo "available runs:"
    aws s3 ls "s3://$S3_BUCKET/" | awk '{print "  " $2}'
    exit 0
fi

RUN_ID=$1
DEST="results/$RUN_ID"
mkdir -p "$DEST"
aws s3 sync "s3://$S3_BUCKET/$RUN_ID/" "$DEST" --quiet
echo "downloaded to $DEST"
echo ""
# fwd: Radiant=NEW -> radiant wins are NEW wins; rev: swapped
python3 ../report.py "$DEST/fwd" "$DEST/rev" || true
echo ""
echo "NOTE: in fwd/ Radiant=NEW; in rev/ Radiant=OLD. NEW's true win rate ="
echo "      (radiant wins in fwd + dire wins in rev) / total decided games."
