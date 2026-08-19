#!/usr/bin/env bash
# Batch-sweep EVERY non-warmup replay under one soak run's S3 prefix through
# the dumper + detect.py pipeline, producing one trigger-count table for the
# whole run (issue #25 item 2 -- replay-check's throughput requirement is a
# 100% breadth sweep every cycle; before this script that meant hand-running
# get_dumper.sh's binary + detect.py once per game).
#
#   sweep_run.sh <s3_run_prefix> [out_dir]
# e.g.
#   sweep_run.sh s3://dota2bot-batch-results-4924/soak/spot_20260819_001001_1_main/
#
# Warmup games are skipped automatically: a game's .analysis.json
# script_version must start with "mirror:" (candidate/baseline mirrored-draft
# stamp) -- see iterations/reports/replay-check/20260819T004401Z.md section 2
# for why the pre-stamp warmup game must not be treated as armed-but-silent.
#
# Output (under $out_dir, default tools/batch_test/behavioral/.sweep_out/<run>):
#   sweep_summary.md     -- per-detector trigger counts (this run) + how many
#                            of those triggers landed on the candidate-armed
#                            side vs the baseline side of each game
#   all_findings.jsonl    -- every finding, tagged with game/cand/seed/side
#   games_manifest.jsonl  -- one line per swept game (cand/seed/side)
#   timelines/, findings/ -- per-game dumper + detect.py output (kept for
#                            follow-up frame-level digging)
#
# Read-only S3 access only; does not launch or touch any billable AWS
# resource. Requires AWS creds in-session
# (bash tools/batch_test/aws/session_setup.sh).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC=${1:?"usage: sweep_run.sh <s3_run_prefix> [out_dir]"}
[[ "$SRC" == */ ]] || SRC="$SRC/"
OUT=${2:-"$REPO/.sweep_out/$(basename "${SRC%/}")"}
mkdir -p "$OUT/dem" "$OUT/analysis" "$OUT/timelines" "$OUT/findings"

AWS_CMD=awsx; command -v awsx >/dev/null 2>&1 || AWS_CMD=aws

echo "[sweep] resolving dumper binary..." >&2
BIN=$(bash "$REPO/get_dumper.sh" "$REPO/.dumper_cache")

echo "[sweep] listing $SRC" >&2
mapfile -t DEMS < <($AWS_CMD s3 ls "$SRC" | awk '{print $4}' | grep '\.dem$')
echo "[sweep] found ${#DEMS[@]} .dem files" >&2

SWEPT=0
SKIPPED=0
: > "$OUT/all_findings.jsonl"
: > "$OUT/games_manifest.jsonl"

for dem in "${DEMS[@]}"; do
    name="${dem%.dem}"
    aj="$OUT/analysis/${name}.analysis.json"
    $AWS_CMD s3 cp "${SRC}${name}.analysis.json" "$aj" --quiet 2>/dev/null || true
    if [ ! -s "$aj" ]; then
        echo "[sweep] SKIP $name (no analysis.json)" >&2
        SKIPPED=$((SKIPPED+1))
        continue
    fi
    sv=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('script_version',''))" "$aj")
    case "$sv" in
        mirror:*) ;;
        *)
            echo "[sweep] SKIP $name (warmup/unstamped, script_version=$sv)" >&2
            SKIPPED=$((SKIPPED+1))
            continue
            ;;
    esac
    side=$(echo "$sv" | awk -F: '{print $NF}')
    cand=$(echo "$sv" | sed -E 's/^mirror:(.*):s[0-9]+:[a-z]+$/\1/')
    seed=$(echo "$sv" | sed -E 's/^mirror:.*:s([0-9]+):[a-z]+$/\1/')

    demf="$OUT/dem/${name}.dem"
    $AWS_CMD s3 cp "${SRC}${dem}" "$demf" --quiet
    tlf="$OUT/timelines/${name}.timeline.json"
    "$BIN" "$demf" > "$tlf"
    python3 "$REPO/detect.py" "$tlf" --json "$OUT/findings/${name}.findings.json" > /dev/null

    python3 - "$OUT/findings/${name}.findings.json" "$name" "$cand" "$seed" "$side" "$tlf" >> "$OUT/all_findings.jsonl" <<'PY'
import json, sys
path, name, cand, seed, side, tlf = sys.argv[1:7]
teams = json.load(open(tlf))["game"]["teams"]
side_team = {"radiant": 2, "dire": 3}.get(side)
for f in json.load(open(path)):
    f["game"] = name
    f["cand"] = cand
    f["seed"] = seed
    f["side"] = side  # which physical team is the armed candidate in THIS game
    hero_team = teams.get(f.get("hero"))
    f["hero_team"] = hero_team
    f["on_candidate_side"] = (hero_team == side_team) if hero_team is not None else None
    print(json.dumps(f))
PY
    echo "{\"game\": \"$name\", \"cand\": \"$cand\", \"seed\": \"$seed\", \"side\": \"$side\"}" >> "$OUT/games_manifest.jsonl"
    rm -f "$demf"  # bound disk; timeline/findings kept for follow-up
    SWEPT=$((SWEPT+1))
    echo "[sweep] $SWEPT/${#DEMS[@]} done: $name (cand=$cand seed=$seed side=$side)" >&2
done

echo "[sweep] swept=$SWEPT skipped=$SKIPPED (of ${#DEMS[@]} total .dem)" >&2

python3 - "$OUT" "$SWEPT" "$SKIPPED" <<'PY'
import json, os, sys
from collections import Counter, defaultdict

out, swept, skipped = sys.argv[1], sys.argv[2], sys.argv[3]
findings = [json.loads(l) for l in open(os.path.join(out, "all_findings.jsonl"))]
games = [json.loads(l) for l in open(os.path.join(out, "games_manifest.jsonl"))]

by_detector = Counter(f["detector"] for f in findings)
per_game_dets = defaultdict(set)
cand_hits = Counter()   # finding landed on the armed/candidate-side hero
base_hits = Counter()   # finding landed on the baseline-side hero
unknown_hits = Counter()
for f in findings:
    per_game_dets[f["game"]].add(f["detector"])
    d = f["detector"]
    if f["on_candidate_side"] is True:
        cand_hits[d] += 1
    elif f["on_candidate_side"] is False:
        base_hits[d] += 1
    else:
        unknown_hits[d] += 1

detectors = sorted(by_detector)
lines = [
    "# Sweep summary\n\n",
    f"games swept: {swept} (skipped {skipped} warmup/unstamped)\n\n",
    "| detector | total | games with >=1 | candidate-side hits | baseline-side hits |\n",
    "|---|---|---|---|---|\n",
]
for d in detectors:
    n_games = sum(1 for g, ds in per_game_dets.items() if d in ds)
    lines.append(f"| {d} | {by_detector[d]} | {n_games}/{len(games)} | "
                 f"{cand_hits[d]} | {base_hits[d]} |\n")

md = "".join(lines)
open(os.path.join(out, "sweep_summary.md"), "w").write(md)
print(md)
PY

echo "[sweep] wrote $OUT/sweep_summary.md + all_findings.jsonl + games_manifest.jsonl" >&2
