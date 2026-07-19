#!/usr/bin/env bash
# Mirrored-draft A/B for a gated fix. The random-draft soak A/B can't resolve a
# behavior-fix-sized effect (per-game draft variance ~600 GPM swamps it; see
# iterations/0010). This pins the draft seed (bots/FunLib/custom_loader.lua reads
# soak_side.lua's `seed`) so BOTH waves use the IDENTICAL 10-hero draft, then
# swaps which side runs the fix. Averaging the paired (fix-side - base-side) diff
# cancels BOTH the radiant side bias AND the draft difference, leaving only the
# fix effect.
#
#   INST=<instance-id> RUN=<s3 run_id> mirror_ab.sh <cand-id> <seed> [games-per-wave]
#
# e.g. INST=i-08b59ef7130025860 RUN=run_20260719_1601 mirror_ab.sh nodive 424242 12
#
# Drives the farm over SSM (never SSH). Prints, per metric, ABdiff / BAdiff and
# the canceled fix_effect (GPM/XPM up = better; deaths down = better), plus a
# `distinct drafts` sanity line (must be 1 — proves the seed pinned the draft).
set -uo pipefail
CAND="${1:?cand id, e.g. nodive}"; SEED="${2:?integer seed}"; TARGET="${3:-12}"
INST="${INST:?set INST=<instance-id>}"; RUN="${RUN:?set RUN=<s3 run_id>}"
REGION="${REGION:-us-west-2}"; BUCKET="${BUCKET:-s3://dota2bot-batch-results-4924}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

deploy() { # side stamp
  local side="$1" stamp="$2" cmd
  cmd=$(awsx ssm send-command --region "$REGION" --instance-ids "$INST" \
    --document-name AWS-RunShellScript \
    --parameters "{\"commands\":[\"cd /opt/dota2bot\",\"sudo mkdir -p /opt/soak\",\"printf 'return { side = \\\\047$side\\\\047, cand = \\\\047$CAND\\\\047, seed = $SEED }\\\\n' | sudo -u ubuntu tee bots/Customize/soak_side.lua\",\"echo '$stamp' | sudo tee /opt/soak/ab_version\"]}" \
    --query 'Command.CommandId' --output text)
  sleep 8
  awsx ssm get-command-invocation --region "$REGION" --command-id "$cmd" --instance-id "$INST" \
    --query 'StandardOutputContent' --output text
}

collect() { # stamp destdir
  local stamp="$1" dir="$2"; mkdir -p "$dir"; local seen="$dir/.seen"; touch "$seen"; local idle=0
  while true; do
    local keys new=0 k n
    keys=$(awsx s3 ls "$BUCKET/soak/$RUN/" 2>/dev/null | awk '{print $4}' | grep 'analysis.json' | sort)
    for k in $keys; do
      grep -qxF "$k" "$seen" 2>/dev/null && continue
      echo "$k" >> "$seen"; new=1
      awsx s3 cp "$BUCKET/soak/$RUN/$k" "$dir/$k" --quiet 2>/dev/null || true
    done
    n=$(python3 - "$dir" "$stamp" <<'PY'
import json,glob,sys
d,st=sys.argv[1],sys.argv[2]; n=0
for f in glob.glob(d+"/*.analysis.json"):
    try: a=json.load(open(f))
    except: continue
    if (a.get("script_version") or "")==st: n+=1
print(n)
PY
)
    echo "$(date +%H:%M) [$stamp] $n/$TARGET" >&2
    [ "$n" -ge "$TARGET" ] && return 0
    [ "$new" = 0 ] && idle=$((idle+1)) || idle=0
    [ "$idle" -ge 30 ] && { echo "STALL $n" >&2; return 1; }
    sleep 60
  done
}

RS="mirror:$CAND:s$SEED:radiant"; DS="mirror:$CAND:s$SEED:dire"
echo "=== WAVE 1: fix=$CAND on RADIANT, seed=$SEED ==="; deploy radiant "$RS"; collect "$RS" "$WORK/r"
echo "=== WAVE 2: fix=$CAND on DIRE, seed=$SEED (same draft) ==="; deploy dire "$DS"; collect "$DS" "$WORK/d"

echo "=== MIRRORED VERDICT (fix=$CAND, seed=$SEED) ==="
python3 - "$WORK/r" "$RS" "$WORK/d" "$DS" <<'PY'
import json,glob,sys,statistics
rd,rs,dd,ds=sys.argv[1:5]
def load(d,st):
    out=[]
    for f in glob.glob(d+"/*.analysis.json"):
        try: a=json.load(open(f))
        except: continue
        if (a.get("script_version") or "")==st: out.append(a)
    return out
def draftset(a): return tuple(sorted((p.get("hero") or "") for p in a.get("players",[])))
def sidevals(a,team,metric): return [p.get(metric) or 0 for p in a.get("players",[]) if p.get("team")==team]
AB=load(rd,rs); BA=load(dd,ds)
drafts=set(draftset(a) for a in AB)|set(draftset(a) for a in BA)
print(f"AB games={len(AB)} BA games={len(BA)} distinct drafts={len(drafts)} (want 1)")
if not AB or not BA: print("MISSING WAVE"); sys.exit(0)
def m(xs): xs=[x for s in xs for x in s]; return statistics.mean(xs) if xs else 0
for metric in ("gpm","xpm","deaths"):
    ab=m([sidevals(a,"radiant",metric) for a in AB]) - m([sidevals(a,"dire",metric) for a in AB])
    ba=m([sidevals(a,"dire",metric) for a in BA]) - m([sidevals(a,"radiant",metric) for a in BA])
    eff=(ab+ba)/2
    better = eff<0 if metric=="deaths" else eff>0
    print(f"  {metric.upper():6} ABdiff={ab:+.1f} BAdiff={ba:+.1f}  fix_effect={eff:+.2f} ({'fix better' if better else 'fix worse'})")
print("  fix_effect cancels side bias AND draft (identical seed both waves)")
PY
echo "MIRROR_DONE"
