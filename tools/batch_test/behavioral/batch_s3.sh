#!/usr/bin/env bash
# Process every replay under an S3 prefix and upload per-game findings +
# a merged summary. Compute-cheap (~0.5s parse + <1s detect per 10MB replay),
# so this runs fine on the soak instance itself without launching anything.
#
#   batch_s3.sh [SRC_PREFIX] [DST_PREFIX]
# defaults:
#   SRC_PREFIX = s3://dota2bot-batch-results-4924/replays/
#   DST_PREFIX = s3://dota2bot-batch-results-4924/behavioral/
set -euo pipefail

WORK=/opt/behav
REPO=${BEHAV_REPO:-/opt/dota2bot/tools/batch_test/behavioral}
SRC=${1:-s3://dota2bot-batch-results-4924/replays/}
DST=${2:-s3://dota2bot-batch-results-4924/behavioral/}
OUT=$WORK/out
mkdir -p "$OUT"

mapfile -t KEYS < <(aws s3 ls "$SRC" | awk '{print $4}' | grep '\.dem$' || true)
echo "found ${#KEYS[@]} replays under $SRC"

: > "$OUT/all_findings.jsonl"
for k in "${KEYS[@]}"; do
    echo "=== $k ==="
    bash "$REPO/run_replay.sh" "${SRC}${k}" "$OUT" || { echo "FAILED: $k"; continue; }
    name=$(basename "$k" .dem)
    aws s3 cp "$OUT/$name.findings.json" "${DST}${name}.findings.json" --quiet
    # append findings tagged with the source replay for a fleet-wide roll-up
    python3 - "$OUT/$name.findings.json" "$name" >> "$OUT/all_findings.jsonl" <<'PY'
import json, sys
name = sys.argv[2]
for f in json.load(open(sys.argv[1])):
    f["replay"] = name
    print(json.dumps(f))
PY
done

# fleet roll-up: which detectors / heroes fire most across all games
python3 - "$OUT/all_findings.jsonl" > "$OUT/rollup.json" <<'PY'
import json, sys
from collections import Counter
rows = [json.loads(l) for l in open(sys.argv[1])]
by_det = Counter(r["detector"] for r in rows)
by_hero = Counter((r["detector"], r["hero"]) for r in rows)
out = {"total": len(rows),
       "by_detector": dict(by_det),
       "by_detector_hero": {f"{d}|{h}": n for (d, h), n in by_hero.most_common()}}
print(json.dumps(out, indent=2))
PY
aws s3 cp "$OUT/rollup.json" "${DST}rollup.json" --quiet
echo "=== rollup ==="; cat "$OUT/rollup.json"
echo "uploaded per-game findings + rollup to $DST"
