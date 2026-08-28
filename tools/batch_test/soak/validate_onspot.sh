#!/usr/bin/env bash
# Self-contained multi-seed mirrored-draft validation, run ON the farm instance
# itself. Designed for the hourly scheduled job's cross-firing handoff: firing N
# launches a spot whose user-data runs this after farm_start; it drives the waves
# locally (via soak_side + ab_version), reads the finished games back FROM S3
# (the farm uploads each game to s3://<bucket>/soak/<run_id>/ and deletes it
# locally, so we MUST read S3, not the local disk), computes the multi-seed
# verdict, uploads it to s3://<bucket>/validation/<name>_<stamp>.verdict.json
# (<name> = the armed string, collapsed by soak_name.sh when it would overflow
# NAME_MAX -- GH #167),
# and the instance then self-terminates.
#
#   validate_onspot.sh <cand-id> "<seed1 seed2 ...>" <games-per-wave> <s3-bucket> <run-id>
#
# run-id is the S3 soak run prefix this instance ships to (spot_run.sh passes it).
set -uo pipefail
CAND="${1:?cand id}"; SEEDS="${2:?seeds}"; TARGET="${3:-12}"
BUCKET="${4:?s3 bucket}"; RUN_ID="${5:?s3 run id (soak/<run_id>)}"
# [GH #141] Optional two-arm wave: CAND_REF is the armed string the REFERENCE
# leg carries. Unset (the default) = today: the reference leg arms nothing and
# the wave reads candidate-vs-stable.
CAND_REF="${CAND_REF:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=/opt/dota2bot
# [GH #108] The stall budget is a MULTIPLE OF THE GAME CAP, not a constant.
# A half-wave costs: the drain of whatever game each slot is already in, plus
# ceil(TARGET/slots) fresh games, each about cap/1.8 wall-minutes (the farm's
# measured control-slot timescale).  The literal 35 this replaces was 3.5x the
# 10-minute cap; at 25 it would have been 1.4x the wall time of a SINGLE game
# and every wave would have "stalled" while perfectly healthy -- under-producing
# silently, because the caller does `|| true` and scores whatever arrived.
# The cap itself is read from soak_loop.sh so the two cannot drift apart; that
# file is the single source of truth for it (env still wins, as it does there).
CAP_MIN=${SOAK_CAP_MIN:-$(sed -n 's/^SOAK_CAP_MIN=\${SOAK_CAP_MIN:-\([0-9]\{1,\}\)}.*/\1/p' \
    "$HERE/soak_loop.sh" 2>/dev/null | head -1)}
case "${CAP_MIN:-}" in ''|*[!0-9]*) CAP_MIN=25 ;; esac
STALL_MIN=${STALL_MIN:-$(( CAP_MIN * 7 / 2 ))}
S3RUN="s3://$BUCKET/soak/$RUN_ID"
# Second-resolution + host suffix: two same-minute runs of the same candidate
# used to OVERWRITE each other's verdict (happened three times on 2026-07-23:
# _0506, _1602 -- the losing run's numbers had to be dug out of run.log or
# recomputed via recover_verdict.py). Per-game data was never at risk; this
# just makes the verdict object name collision-free.
STAMP_TS=$(date +%Y%m%d_%H%M%S)_$(hostname | tail -c 5)
OUT=/opt/validation; mkdir -p "$OUT"; WORK="$OUT/games"; mkdir -p "$WORK"
SEEN="$OUT/.seen"; : > "$SEEN"
RESULTS="$OUT/rows.jsonl"; : > "$RESULTS"

sync_s3() { # pull any new analysis.json from this run into WORK
  aws s3 ls "$S3RUN/" 2>/dev/null | awk '{print $4}' | grep 'analysis.json' | while read -r k; do
    grep -qxF "$k" "$SEEN" 2>/dev/null && continue
    echo "$k" >> "$SEEN"
    aws s3 cp "$S3RUN/$k" "$WORK/$k" --quiet 2>/dev/null || true
  done
}

count_stamped() { # stamp -> count in WORK
  python3 - "$WORK" "$1" <<'PY'
import json,glob,sys
d,st=sys.argv[1],sys.argv[2]; n=0
for f in glob.glob(d+"/*.analysis.json"):
    try:
        if (json.load(open(f)).get("script_version") or "")==st: n+=1
    except Exception: pass
print(n)
PY
}

deploy_wave() { # side seed stamp
  CAND_REF="$CAND_REF" bash "$HERE/write_soak_side.sh" "$1" "$CAND" "$2" \
    | sudo -u ubuntu tee "$REPO/bots/Customize/soak_side.lua" >/dev/null
  echo "$3" | sudo tee /opt/soak/ab_version >/dev/null
}

wait_wave() { # stamp -> 0 when TARGET reached, 1 on stall (STALL_MIN minutes)
  local stamp="$1" n=0 i=0
  while true; do
    sync_s3
    n=$(count_stamped "$stamp")
    echo "$(date +%H:%M) [$stamp] $n/$TARGET"
    [ "$n" -ge "$TARGET" ] && return 0
    i=$((i+1)); [ "$i" -ge "$STALL_MIN" ] && { echo "STALL [$stamp] at $n after ${STALL_MIN}min (cap=${CAP_MIN})"; return 1; }
    sleep 60
  done
}

for SEED in $SEEDS; do
  RS="mirror:$CAND:s$SEED:radiant"; DS="mirror:$CAND:s$SEED:dire"
  echo "===== $CAND seed=$SEED wave RADIANT ====="; deploy_wave radiant "$SEED" "$RS"; wait_wave "$RS" || true
  echo "===== $CAND seed=$SEED wave DIRE ====="; deploy_wave dire "$SEED" "$DS"; wait_wave "$DS" || true
  python3 - "$WORK" "$CAND" "$SEED" "$RS" "$DS" >> "$RESULTS" <<'PY'
import json,glob,statistics,sys
d,cand,seed,rs,ds=sys.argv[1:6]
def load(st):
    out=[]
    for f in glob.glob(d+"/*.analysis.json"):
        try:
            a=json.load(open(f))
            if (a.get("script_version") or "")==st: out.append(a)
        except Exception: pass
    return out
def sv(a,t,m): return [p.get(m) or 0 for p in a.get("players",[]) if p.get("team")==t]
def M(xs): xs=[x for s in xs for x in s]; return statistics.mean(xs) if xs else 0
AB,BA=load(rs),load(ds)
row={"seed":seed,"ab_games":len(AB),"ba_games":len(BA)}
drafts=set(tuple(sorted((p.get("hero") or "") for p in a.get("players",[]))) for a in AB+BA)
row["distinct_drafts"]=len(drafts)
# [GH #269] The farm's happy path is THIS copy, so the depth gate has to live
# here too -- a gate that exists only in recover_verdict.py is a gate every
# non-reclaimed wave runs without.  MIN_ARM_DEPTH must equal the literal in
# recover_verdict.py (tests/test_verdict_arm_depth.py asserts both copies carry
# the same number).  arm_depth = harmonic mean of the two leg counts = games
# per leg this seed is worth, because Var[(ab+ba)/2] = s^2/(2*arm_depth); the
# `if AB and BA` gate alone could not tell ba=1 from ba=15, and on W19 one dire
# game moved the wave mean 76.5 gpm while every other field looked normal.
MIN_ARM_DEPTH=8
row["arm_depth"]=round((2.0*len(AB)*len(BA)/(len(AB)+len(BA))) if (AB and BA) else 0.0,2)
row["scored"]=bool(AB and BA) and row["arm_depth"]>=MIN_ARM_DEPTH
if not (AB and BA): row["excluded"]="NO-PAIR"
elif not row["scored"]: row["excluded"]="THIN-ARM"
if row["scored"]:
    for m in ("gpm","xpm","deaths","last_hits"):
        ab=M([sv(a,"radiant",m) for a in AB])-M([sv(a,"dire",m) for a in AB])
        ba=M([sv(a,"dire",m) for a in BA])-M([sv(a,"radiant",m) for a in BA])
        row[m]=round((ab+ba)/2,2)
print(json.dumps(row))
PY
done

python3 - "$CAND" "$SEEDS" "$RESULTS" "$CAND_REF" > "$OUT/verdict.json" <<'PY'
import json,statistics,sys
cand,seeds,path,cand_ref=sys.argv[1:5]
rows=[json.loads(l) for l in open(path) if l.strip()]
# [GH #141] A two-arm wave's per-seed number is armA-minus-armB, NOT
# candidate-minus-stable. The math is the same; the ACCOUNTING must not be, or
# the reading silently pollutes every later comparison and cannot be told apart
# afterwards. cand_ref is always present; contrast says which kind this is.
v={"cand":cand,"cand_ref":cand_ref or None,
   "contrast":"two_arm" if cand_ref else "vs_stable",
   "seeds":seeds.split(),"per_seed":rows,"mean":{},"comps_better":{}}
for m in ("gpm","xpm","deaths","last_hits"):
    xs=[r[m] for r in rows if m in r]
    if not xs: continue
    v["mean"][m]=round(statistics.mean(xs),2)
    neg=m=="deaths"
    v["comps_better"][m]=f"{sum(1 for x in xs if (x<0 if neg else x>0))}/{len(xs)}"
# [GH #269] The excluded seeds are published, not left in the per-seed rows for
# a reader who has no reason to suspect them.
complete=[r for r in rows if "gpm" in r]
v["min_arm_depth"]=8
v["thin_arm_seeds"]=[{"seed":r["seed"],"ab_games":r.get("ab_games"),
                      "ba_games":r.get("ba_games"),"arm_depth":r.get("arm_depth")}
                     for r in rows if r.get("excluded")=="THIN-ARM"]
g=v["mean"].get("gpm"); d=v["mean"].get("deaths")
# [GH #269] The majority test counts the SCORED seeds, matching both the mean
# above it and `comps_better`'s own denominator.  It used to divide by
# `len(rows)`, so a seed excluded from the mean still voted against promote
# here -- the same incoherence #269 names (a seed too thin to be measured must
# not decide the reading), just with the sign that happened to look safe.
# recover_verdict.py has always used the scored count; the two copies now agree.
v["suggested"]=("promote" if (g is not None and g>5 and complete and
    int(v["comps_better"]["gpm"].split('/')[0])*2>len(complete) and (d is None or d<=0))
    else "hold_or_reject")
print(json.dumps(v,indent=1))
PY
cat "$OUT/verdict.json"
# [GH #167] NAME_MAX: the armed string is monotonically growing and passed 255
# bytes at 26 ids, which killed every `s3 cp --recursive validation/`.
# soak_name.sh keeps short names verbatim and collapses only the long ones.
VNAME=$(bash "$HERE/soak_name.sh" "$CAND" "_${STAMP_TS}.verdict.json") || exit 1
aws s3 cp "$OUT/verdict.json" "s3://$BUCKET/validation/$VNAME" --quiet \
  && echo "VERDICT_UPLOADED s3://$BUCKET/validation/$VNAME"
printf "return { side = false, cand = false }\n" | sudo -u ubuntu tee "$REPO/bots/Customize/soak_side.lua" >/dev/null
sudo rm -f /opt/soak/ab_version
echo "VALIDATE_ONSPOT_DONE"
