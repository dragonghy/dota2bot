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
#   unparseable.txt       -- one line per game the dumper could not read
#                            ([harness] #258); also counted in sweep_summary.md
#                            and listed in sweep_complete.json. A bad .dem
#                            costs its own game and nothing else.
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
mkdir -p "$OUT/dem" "$OUT/analysis" "$OUT/timelines" "$OUT/findings" "$OUT/unparseable"

AWS_CMD=awsx; command -v awsx >/dev/null 2>&1 || AWS_CMD=aws

echo "[sweep] resolving dumper binary..." >&2
BIN=$(bash "$REPO/get_dumper.sh" "$REPO/.dumper_cache")

# A REC_SLOTS=1 wave keeps its single .dem beside the per-game archive; a bulk
# (--rec-slots N) wave puts every recording under the bucket's expiring
# dem21/<run>/ tree instead, because retention there is carried by the key (the
# runner instance profile cannot tag objects -- see dem_claim.sh:dem_bulk_prefix).
# The .analysis.json always stays under soak/<run>/, so only the .dem source moves.
DEM_SRC="$SRC"
echo "[sweep] listing $DEM_SRC" >&2
mapfile -t DEMS < <($AWS_CMD s3 ls "$DEM_SRC" | awk '{print $4}' | grep '\.dem$' || true)
if [ "${#DEMS[@]}" -eq 0 ] && [[ "$SRC" == */soak/* ]]; then
    DEM_SRC="${SRC%%/soak/*}/dem21/$(basename "${SRC%/}")/"
    echo "[sweep] no .dem beside the archive; trying bulk prefix $DEM_SRC" >&2
    mapfile -t DEMS < <($AWS_CMD s3 ls "$DEM_SRC" | awk '{print $4}' | grep '\.dem$' || true)
fi
echo "[sweep] found ${#DEMS[@]} .dem files" >&2

SWEPT=0
SKIPPED=0
UNPARSEABLE=0
: > "$OUT/all_findings.jsonl"
: > "$OUT/games_manifest.jsonl"
# [harness] #258: names of games the dumper could not parse. Kept in a FILE,
# not a bash array, on purpose -- an empty array expanded under `set -u` is
# itself an error on older bash, and a degrade path that dies is not a degrade
# path. Truncated here for the same reason the sentinel is removed below: a
# leftover list from an earlier sweep of this same out_dir would be read as
# this sweep's.
: > "$OUT/unparseable.txt"
# [harness] #102: clear any sentinel from an EARLIER complete sweep of this same
# out_dir before touching the manifest. A re-run that dies halfway would
# otherwise leave last time's sentinel sitting on top of this time's truncated
# manifest -- the exact "looks finished, is not" shape this sentinel exists to
# rule out. Removed here, written only after the summary below succeeds.
rm -f "$OUT/sweep_complete.json"

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
    $AWS_CMD s3 cp "${DEM_SRC}${dem}" "$demf" --quiet
    tlf="$OUT/timelines/${name}.timeline.json"
    # [harness] #258: ONE .dem the dumper cannot parse used to take the whole
    # run with it. Under `set -e` the failed exec exited before the summary and
    # the sentinel were written, so the 5 games already swept were correctly
    # refused by every #102 consumer -- 1 bad file cost 6/25 = 24% of a wave's
    # corpus, on a preemption wave that could least afford it (W17-R).
    # The sentinel was not wrong; the bug was upstream promoting "this GAME is
    # unparseable" (a property of one file) to "this RUN never ran" (a property
    # of the sweep). Degrade per game: count it, name it, keep going.
    #
    # BOUNDARY, deliberate: only the dumper call degrades. A `detect.py` failure
    # below stays fatal, because that is a property of OUR code on an already
    # parsed timeline -- swallowing it per game would hide a real defect behind
    # a shrinking corpus, which is the very shape #102 exists to catch.
    if ! "$BIN" "$demf" > "$tlf" 2> "$OUT/unparseable/${name}.dumper.err" \
       || [ ! -s "$tlf" ]; then
        rm -f "$tlf" "$demf"
        echo "$name" >> "$OUT/unparseable.txt"
        UNPARSEABLE=$((UNPARSEABLE+1))
        echo "[sweep] UNPARSEABLE $name (dumper failed or wrote nothing; stderr in" \
             "$OUT/unparseable/${name}.dumper.err) -- counted, run continues" >&2
        continue
    fi
    rm -f "$OUT/unparseable/${name}.dumper.err"
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

echo "[sweep] swept=$SWEPT skipped=$SKIPPED unparseable=$UNPARSEABLE (of ${#DEMS[@]} total .dem)" >&2

# [harness] #258: the one case the per-game degrade must NOT swallow. If every
# stamped game failed to parse, "keep going" would hand the consumers a
# complete-looking sentinel over an EMPTY corpus -- unparseable read as absent,
# the #253/#257 family, and the exact failure this fix is supposed to remove
# rather than relocate. No summary, no sentinel, loud exit.
if [ "$SWEPT" -eq 0 ] && [ "$UNPARSEABLE" -gt 0 ]; then
    echo "[sweep] FATAL: 0 games swept and $UNPARSEABLE unparseable -- refusing to" \
         "write a summary/sentinel over an empty corpus. Rebuild the dumper" \
         "(get_dumper.sh) or check the .dem source; see $OUT/unparseable.txt" >&2
    exit 4
fi

python3 - "$OUT" "$SWEPT" "$SKIPPED" <<'PY'
import json, os, sys
from collections import Counter, defaultdict

out, swept, skipped = sys.argv[1], sys.argv[2], sys.argv[3]
findings = [json.loads(l) for l in open(os.path.join(out, "all_findings.jsonl"))]
games = [json.loads(l) for l in open(os.path.join(out, "games_manifest.jsonl"))]
unparseable = [l.strip() for l in open(os.path.join(out, "unparseable.txt")) if l.strip()]

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
# [harness] #258: `unparseable K` is printed ALWAYS, including K == 0. Printing
# it only when non-zero would make "no bad games" and "swept by a version that
# did not count them" the same bytes -- absent again reading as zero, which is
# the whole complaint. The `games swept: N (` prefix is load-bearing: consumers
# parse it as split(':')[1].split('(')[0] and cross-check it against the
# manifest line count (null_leg_occupancy.py:load_manifest), so K goes INSIDE
# the parenthesis and N keeps meaning "games in the manifest".
lines = [
    "# Sweep summary\n\n",
    f"games swept: {swept} (skipped {skipped} warmup/unstamped, "
    f"unparseable {len(unparseable)})\n\n",
]
if unparseable:
    lines.append("unparseable games (dumper could not read the .dem; NOT in the "
                 "counts below): " + ", ".join(sorted(unparseable)) + "\n\n")
lines += [
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

# [harness] #102: explicit completion sentinel, written LAST and only on the
# success path (set -e means any earlier failure exits before this line).
# A sweep that dies mid-loop leaves a directory that is byte-for-byte
# indistinguishable from a good one to every consumer -- they all read only
# games_manifest.jsonl, which is appended per game, so a partial sweep is just
# "a corpus with fewer games" and nothing says so. That silently took capmono's
# arm A from 16 games to 13 (pooled domain frames 86 -> 72, seed906 Jaccard
# 0.43 -> 0.00) while r moved only +0.011 -> +0.018, i.e. it looked normal.
# Consumers MUST require this file and cross-check `swept` against the manifest
# line count; sweep_summary.md is NOT a valid sentinel (it is only incidentally
# last, undocumented as such, and carries no dem_found, so "swept all 4" and
# "found 5 .dem, swept 4" are indistinguishable inside it).
python3 - "$OUT" "${#DEMS[@]}" "$SWEPT" "$SKIPPED" "$DEM_SRC" <<'PY'
import json, os, sys
out, dem_found, swept, skipped, src = sys.argv[1:6]
# [harness] #258: the sentinel carries the unparseable count AND the names, so a
# consumer can make its own call (accept the shrunken corpus / re-sweep / refuse)
# instead of the sweep making it for everyone by dying.
unparseable = [l.strip() for l in open(os.path.join(out, "unparseable.txt")) if l.strip()]
json.dump({
    "dem_found": int(dem_found),
    "swept": int(swept),
    "skipped": int(skipped),
    "unparseable": len(unparseable),
    "unparseable_games": sorted(unparseable),
    "exit_code": 0,
    "s3_prefix": src,
}, open(os.path.join(out, "sweep_complete.json"), "w"), indent=2)
PY

echo "[sweep] wrote $OUT/sweep_summary.md + all_findings.jsonl + games_manifest.jsonl + sweep_complete.json (unparseable=$UNPARSEABLE)" >&2
