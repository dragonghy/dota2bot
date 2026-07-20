#!/usr/bin/env bash
# Self-contained multi-seed mirrored-draft validation, run ON the farm instance
# itself (no SSM, no external driver). Designed for the hourly scheduled job's
# cross-firing handoff: firing N launches a spot whose user-data runs this after
# farm_start; it drives the waves locally, computes the multi-seed verdict, and
# uploads it to s3://<bucket>/validation/<cand>_<stamp>.verdict.json; the
# instance then self-terminates. Firing N+1 just reads the verdict from S3.
#
#   validate_onspot.sh <cand-id> "<seed1 seed2 ...>" [games-per-wave] [s3-bucket]
#
# Requires: the soak farm already running on this instance (farm_start.sh),
# repo at /opt/dota2bot, analysis JSONs landing under /opt/soak/**.
set -uo pipefail
CAND="${1:?cand id}"; SEEDS="${2:?seeds}"; TARGET="${3:-12}"
BUCKET="${4:-dota2bot-batch-results-4924}"
REPO=/opt/dota2bot
STAMP_TS=$(date +%Y%m%d_%H%M)
OUT=/opt/validation; mkdir -p "$OUT"
RESULTS="$OUT/rows.jsonl"; : > "$RESULTS"

deploy_wave() { # side seed stamp
  printf "return { side = '%s', cand = '%s', seed = %s }\n" "$1" "$CAND" "$2" \
    | sudo -u ubuntu tee "$REPO/bots/Customize/soak_side.lua" >/dev/null
  echo "$3" | sudo tee /opt/soak/ab_version >/dev/null
}

count_stamped() { # stamp -> count of local analysis files carrying it
  python3 - "$1" <<'PY'
import json,glob,sys
st=sys.argv[1]; n=0
for f in glob.glob('/opt/soak/**/*.analysis.json', recursive=True):
    try:
        if (json.load(open(f)).get('script_version') or '')==st: n+=1
    except Exception: pass
print(n)
PY
}

wait_wave() { # stamp -> 0 when TARGET reached, 1 on stall (~35 min cap)
  local stamp="$1" n=0 i=0
  while true; do
    n=$(count_stamped "$stamp")
    echo "$(date +%H:%M) [$stamp] $n/$TARGET"
    [ "$n" -ge "$TARGET" ] && return 0
    i=$((i+1)); [ "$i" -ge 35 ] && { echo "STALL [$stamp] at $n"; return 1; }
    sleep 60
  done
}

for SEED in $SEEDS; do
  RS="mirror:$CAND:s$SEED:radiant"; DS="mirror:$CAND:s$SEED:dire"
  echo "===== $CAND seed=$SEED wave RADIANT ====="
  deploy_wave radiant "$SEED" "$RS"; wait_wave "$RS" || true
  echo "===== $CAND seed=$SEED wave DIRE ====="
  deploy_wave dire "$SEED" "$DS"; wait_wave "$DS" || true
  python3 - "$CAND" "$SEED" "$RS" "$DS" >> "$RESULTS" <<'PY'
import json,glob,statistics,sys
cand,seed,rs,ds=sys.argv[1:5]
def load(st):
    out=[]
    for f in glob.glob('/opt/soak/**/*.analysis.json', recursive=True):
        try:
            a=json.load(open(f))
            if (a.get('script_version') or '')==st: out.append(a)
        except Exception: pass
    return out
def sidevals(a,t,m): return [p.get(m) or 0 for p in a.get('players',[]) if p.get('team')==t]
def M(xs): xs=[x for s in xs for x in s]; return statistics.mean(xs) if xs else 0
AB,BA=load(rs),load(ds)
row={'seed':seed,'ab_games':len(AB),'ba_games':len(BA)}
drafts=set(tuple(sorted((p.get('hero') or '') for p in a.get('players',[]))) for a in AB+BA)
row['distinct_drafts']=len(drafts)
if AB and BA:
    for m in ('gpm','xpm','deaths','last_hits'):
        ab=M([sidevals(a,'radiant',m) for a in AB])-M([sidevals(a,'dire',m) for a in AB])
        ba=M([sidevals(a,'dire',m) for a in BA])-M([sidevals(a,'radiant',m) for a in BA])
        row[m]=round((ab+ba)/2,2)
print(json.dumps(row))
PY
done

# aggregate + upload verdict
python3 - "$CAND" "$SEEDS" "$RESULTS" > "$OUT/verdict.json" <<'PY'
import json,statistics,sys
cand,seeds,path=sys.argv[1:4]
rows=[json.loads(l) for l in open(path) if l.strip()]
v={'cand':cand,'seeds':seeds.split(),'per_seed':rows,'mean':{},'comps_better':{}}
for m in ('gpm','xpm','deaths','last_hits'):
    xs=[r[m] for r in rows if m in r]
    if not xs: continue
    v['mean'][m]=round(statistics.mean(xs),2)
    neg = m=='deaths'
    v['comps_better'][m]=f"{sum(1 for x in xs if (x<0 if neg else x>0))}/{len(xs)}"
g=v['mean'].get('gpm'); d=v['mean'].get('deaths')
v['suggested']=('promote' if (g is not None and g>5 and
    int(v['comps_better']['gpm'].split('/')[0])*2>len(rows) and (d is None or d<=0))
    else 'hold_or_reject')
print(json.dumps(v,indent=1))
PY
cat "$OUT/verdict.json"
aws s3 cp "$OUT/verdict.json" "s3://$BUCKET/validation/${CAND}_${STAMP_TS}.verdict.json" --quiet \
  && echo "VERDICT_UPLOADED s3://$BUCKET/validation/${CAND}_${STAMP_TS}.verdict.json"
# clean gate for whatever runs next on this instance
printf "return { side = false, cand = false }\n" | sudo -u ubuntu tee "$REPO/bots/Customize/soak_side.lua" >/dev/null
sudo rm -f /opt/soak/ab_version
echo "VALIDATE_ONSPOT_DONE"
