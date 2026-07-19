#!/usr/bin/env bash
# Multi-seed mirrored-draft A/B. A single mirror_ab.sh run cancels draft variance
# WITHIN one comp, but the fix effect itself VARIES BY COMP (iterations/0010: #4
# nodive ranged -24..+42 GPM across 3 seeds). So a single seed is per-comp, not
# the population mean. This runs N seeds (N distinct comps) and reports the MEAN
# fix_effect ± the per-seed spread and how many comps each metric helped — the
# real ship/no-ship signal.
#
#   INST=<id> RUN=<run_id> mirror_multi.sh <cand-id> "<seed1 seed2 ...>" [games]
#
# Each seed = one mirror pair (fix on radiant wave, fix on dire wave, same draft).
# Runs seeds serially on the given instance; parallelize across CANDIDATES by
# giving each its own instance (golden + spots).
set -uo pipefail
CAND="${1:?cand id}"; SEEDS="${2:?space-separated seeds}"; TARGET="${3:-12}"
INST="${INST:?set INST}"; RUN="${RUN:?set RUN}"
REGION="${REGION:-us-west-2}"; BUCKET="${BUCKET:-s3://dota2bot-batch-results-4924}"
HERE="$(cd "$(dirname "$0")" && pwd)"
RESULTS="$(mktemp)"; trap 'rm -f "$RESULTS"' EXIT

for SEED in $SEEDS; do
  echo "########## $CAND seed=$SEED ##########" >&2
  # Run one mirror pair; capture its verdict lines and re-parse the numbers.
  OUT=$(INST="$INST" RUN="$RUN" REGION="$REGION" BUCKET="$BUCKET" \
        bash "$HERE/mirror_ab.sh" "$CAND" "$SEED" "$TARGET" 2>>/dev/stderr)
  echo "$OUT" | python3 - "$SEED" >> "$RESULTS" <<'PY'
import sys,re,json
seed=sys.argv[1]; txt=sys.stdin.read()
row={"seed":seed}
for metric in ("GPM","XPM","DEATHS"):
    m=re.search(rf"{metric}\s+ABdiff=\S+ BAdiff=\S+\s+fix_effect=([+-]?\d+\.?\d*)", txt)
    row[metric.lower()]=float(m.group(1)) if m else None
dr=re.search(r"distinct drafts=(\d+)", txt); row["drafts"]=int(dr.group(1)) if dr else None
print(json.dumps(row))
PY
done

echo "=== MULTI-SEED VERDICT (fix=$CAND, seeds: $SEEDS) ==="
python3 - "$RESULTS" "$CAND" <<'PY'
import sys,json,statistics
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
cand=sys.argv[2]
if not rows: print("NO RESULTS"); sys.exit(0)
print(f"per-seed (fix_effect; GPM/XPM up=better, deaths down=better):")
for r in rows:
    print(f"  seed {r['seed']:>8}  GPM={r['gpm']:+7.1f}  XPM={r['xpm']:+7.1f}  DEATHS={r['deaths']:+.2f}  drafts={r.get('drafts')}")
def agg(k, better_is_neg=False):
    xs=[r[k] for r in rows if r.get(k) is not None]
    if not xs: return
    mean=statistics.mean(xs); sd=statistics.pstdev(xs) if len(xs)>1 else 0
    npos=sum(1 for x in xs if (x<0 if better_is_neg else x>0))
    label="better" if (mean<0 if better_is_neg else mean>0) else "worse"
    print(f"  {k.upper():6} mean={mean:+7.1f}  sd={sd:6.1f}  comps_better={npos}/{len(xs)}  -> {label}")
print(f"aggregate over {len(rows)} comps:")
agg("gpm"); agg("xpm"); agg("deaths", better_is_neg=True)
print("  SHIP if mean clearly positive AND most comps better AND deaths not worse.")
PY
echo "MULTI_DONE"
