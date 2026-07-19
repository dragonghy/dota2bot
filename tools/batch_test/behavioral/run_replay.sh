#!/usr/bin/env bash
# End-to-end behavioral analysis of ONE replay: .dem -> timeline.json -> findings.
# Runs on the soak instance after setup_instance.sh has built behav-dump.
#
#   run_replay.sh <replay.dem | s3://bucket/key.dem> [out_dir]
#
# Writes <out_dir>/<name>.timeline.json and <out_dir>/<name>.findings.json,
# and prints the human-readable findings.
set -euo pipefail

WORK=/opt/behav
REPO=${BEHAV_REPO:-/opt/dota2bot/tools/batch_test/behavioral}
SRC=${1:?usage: run_replay.sh <replay.dem|s3://...> [out_dir]}
OUT=${2:-$WORK/out}
mkdir -p "$OUT"

DEM="$SRC"
if [[ "$SRC" == s3://* ]]; then
    DEM="$WORK/replays/$(basename "$SRC")"
    mkdir -p "$WORK/replays"
    aws s3 cp "$SRC" "$DEM" --quiet
fi
NAME=$(basename "$DEM" .dem)

"$WORK/behav-dump" "$DEM" > "$OUT/$NAME.timeline.json"
python3 "$REPO/detect.py" "$OUT/$NAME.timeline.json" --json "$OUT/$NAME.findings.json"
