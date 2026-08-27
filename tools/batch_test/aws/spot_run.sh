#!/usr/bin/env bash
# Launch N parallel SPOT soak-farm instances. Each one boots from the baked
# AMI, refreshes the repo + game, generates the soak pool, deploys, runs the
# soak farm, ships every finished game to ITS OWN S3 run prefix, and
# SELF-TERMINATES (watchdog + shutdown-behavior=terminate). Spot is ~60-70%
# cheaper than on-demand; because every game uploads to S3 the moment it ends,
# a spot reclaim loses at most the handful of in-flight games.
#
#   ./spot_run.sh                         # 1 spot instance, main, 14 slots, 3h cap
#   ./spot_run.sh --count 4               # 4 parallel spot farms, distinct tags+prefixes
#   ./spot_run.sh --count 3 --ref my-exp  # each farm runs branch my-exp
#   ./spot_run.sh --slots 12 --hours 2    # 12 slots, 2h hard watchdog
#   ./spot_run.sh --rec-slots 16          # record a .dem on ALL 16 slots (#75)
#   ./spot_run.sh --on-demand             # escape hatch: on-demand (no reclaim risk)
#   ./spot_run.sh --az us-west-2a         # pin this instance to one AZ (#252)
#   ./spot_run.sh --az us-west-2a,us-west-2c   # rotate a wave over these AZs
#   ./spot_run.sh --no-az-spread          # legacy: let EC2 choose (pre-#252)
#   ./spot_run.sh --dry-run               # print the plan, launch nothing
#
# Cost safety (see SPOT_USAGE.md):
#   - --instance-initiated-shutdown-behavior terminate  (never leaks a stopped box)
#   - `shutdown -h +<HOURS*60>` watchdog in user-data (default 3h, hard cap)
#   - spot interruption behavior = terminate (default); a poller flushes logs on notice
#   - one-time spot request (NOT persistent) so a reclaim does not silently relaunch
set -euo pipefail
cd "$(dirname "$0")"
source aws.env
command -v awsx >/dev/null 2>&1 && aws() { awsx "$@"; }
[ -n "$AMI_ID" ] || { echo "AMI_ID empty in aws.env — run bake_ami.sh first" >&2; exit 1; }

COUNT=1
REF=main
SLOTS=14            # parallel games per instance (c6i.4xlarge = 16 vCPU)
REC_SLOTS=1         # how many of those slots record a .dem ([harness] #75).
                    # 1 = the long-standing default: the frame-level channel
                    # gets 1/SLOTS of the games this wave pays for. Raise it
                    # only on instances that are measuring the throughput cost
                    # of SourceTV, and raise it IDENTICALLY on both arms of a
                    # mirrored pair so the A/B comparison stays symmetric.
HOURS=3             # watchdog hard cap (self-terminate). Outer bound: use --hours 12.
VALIDATE=""         # "--validate 'CAND SEED1 SEED2 ... [--games N] [--cand-ref STR]'":
                    # after farm_start, run
                    # tools/batch_test/soak/validate_onspot.sh with these args,
                    # upload the verdict to s3://$S3_BUCKET/validation/, then
                    # shut down immediately (terminate) instead of waiting for the
                    # watchdog. This is the scheduled job's cross-firing handoff.
MARKET="--instance-market-options MarketType=spot,SpotOptions={SpotInstanceType=one-time,InstanceInterruptionBehavior=terminate}"
SPOT=1
DRYRUN=0
ALLOW_SHORT_WATCHDOG=0   # [GH #108] see the wave-budget guard below
TAG_PREFIX=dota2bot-soak-spot
STAMP=$(date +%Y%m%d_%H%M%S)
# [harness] #98: run_id must not rest on STAMP's 1-second resolution. Within ONE
# call `_${n}_` disambiguates structurally, but the batch desk's standing 4x1
# topology (one seed per instance => four separate COUNT=1 calls) makes every
# run_id n=1, so only the second separates them. Measured margin across 58
# same-wave adjacent calls: min 2s, median 5s -- and that floor is just "one
# ec2 run-instances round trip", which nothing guarantees. If two calls ever
# share a second, both instances write to s3://.../soak/<run_id>/, same-second
# game basenames collide (21 such pairs already exist bucket-wide, harmless only
# because they sit under different prefixes), S3 last-write-wins silently drops
# games, AND the two seeds merge -- so recover_verdict.py's per-seed pairing
# starts answering with the other seed's games. Every documented workaround
# ("re-download per run, then merge") is structurally void in that case, since
# there is nothing left to separate. This token makes uniqueness independent of
# wall-clock resolution. It is APPENDED so every historical prefix glob
# (spot_<date>_<time>*) and every archived run_id in the reports stays literal;
# consumers treat run_id as an opaque token (dem_claim.sh / dem_inventory.py
# split on "__", never on run_id's internals).
# 3 bytes = 16.7M values: with the four same-second calls of a 4x1 wave the
# birthday odds are ~4e-7 per wave, i.e. the failure mode stops being a
# scheduling question. Falls back to the PID (distinct across the four calls,
# which is exactly the case that matters) if /dev/urandom is unreadable.
RUN_TOKEN=$(od -An -N3 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
[ -n "$RUN_TOKEN" ] || RUN_TOKEN=$(printf '%06x' $$)

# [harness] #252: placement. Until 2026-08-27 this script passed NO placement at
# all, so every instance landed wherever EC2 put it -- which in practice was the
# same AZ every time (W17: four instances, all us-west-2b, all four reclaimed in
# the SAME SECOND by one `instance-terminated-no-capacity` event; the whole wave
# produced 128 radiant-only orphans and zero usable seeds for ~$0.48). The 4x1
# topology's redundancy was fully cancelled at the placement layer.
#
# NOTE ON THE ROTATION KEY -- this is the same trap as RUN_TOKEN above, and #252
# asks for the version that falls into it. "Nth instance takes the Nth AZ" is
# void under the batch desk's standing 4x1 topology, because those four
# instances are four separate COUNT=1 processes and `n` is 1 in every one of
# them; the rotation would put all four back in one AZ, i.e. exactly today's
# failure. So the rotation offset is RANDOM PER PROCESS by default (like
# RUN_TOKEN, and for the same reason: uniqueness must not rest on something the
# four calls share). With 4 AZs that turns P(all four in one AZ) from ~1 into
# 4^-3 = 1/64, and P(at least two AZs) into 63/64.
#   For a GUARANTEED spread, pass the AZ explicitly (--az us-west-2a, one per
#   call) or launch the wave as one --count 4 call: an explicit --az list is
#   walked from offset 0, so a single call with N AZs and --count N is
#   deterministic and hits each AZ exactly once.
# AZ_LIST (aws.env) empty, or --no-az-spread, restores the pre-#252 behavior.
AZ_SPREAD=1
AZ_ARG=""           # --az value: one AZ pins, a comma list rotates

while [ $# -gt 0 ]; do
    case "$1" in
        --count) COUNT=$2; shift 2 ;;
        --ref) REF=$2; shift 2 ;;
        --slots) SLOTS=$2; shift 2 ;;
        --rec-slots) REC_SLOTS=$2; shift 2 ;;
        --hours) HOURS=$2; shift 2 ;;
        --type) INSTANCE_TYPE=$2; shift 2 ;;
        --validate) VALIDATE=$2; shift 2 ;;
        --az) AZ_ARG=$2; shift 2 ;;
        --no-az-spread) AZ_SPREAD=0; shift ;;
        --on-demand) MARKET=""; SPOT=0; TAG_PREFIX=dota2bot-soak-od; shift ;;
        --allow-short-watchdog) ALLOW_SHORT_WATCHDOG=1; shift ;;
        --dry-run) DRYRUN=1; shift ;;
        *) echo "unknown arg $1" >&2; exit 1 ;;
    esac
done

WATCHDOG_MIN=$((HOURS * 60))

# ---- [harness] #252: build the AZ ring and pick this process's start offset.
AZS=()
if [ "$AZ_SPREAD" -eq 1 ]; then
    IFS=',' read -r -a _az_raw <<< "${AZ_ARG:-${AZ_LIST:-}}"
    for _az in "${_az_raw[@]:-}"; do
        _az=$(echo "$_az" | xargs)          # tolerate "a, b" spacing
        [ -n "$_az" ] && AZS+=("$_az")
    done
fi
AZ_OFFSET=0
if [ ${#AZS[@]} -gt 0 ] && [ -z "$AZ_ARG" ]; then
    # random start ONLY for the implicit (aws.env) ring -- see the note above:
    # a per-process constant start is what makes four COUNT=1 calls collide.
    _r=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' \n')
    [ -n "$_r" ] || _r=$$
    AZ_OFFSET=$(( _r % ${#AZS[@]} ))
fi

# ---- [GH #108] wave-budget guard: does the watchdog outlast the wave it backs?
# The 2026-07 "852 accident" was a seed that got no games because the instance
# self-terminated mid-wave; the wave still produced a verdict, computed on the
# seeds that HAD run, and nothing in it said a seed was missing. Raising the cap
# 10 -> 25 multiplies every wave's wall time by ~2.5x, so the same accident that
# needed a 4-seed wave to happen now happens at 2 seeds on the default 3h.
# So the arithmetic is done here, BEFORE any money is spent, and a wave that
# cannot fit is refused with the --hours it needs rather than truncated.
# The estimate is deliberately crude and stated in the message so a human can
# overrule it: --allow-short-watchdog launches anyway (legitimate for a wave
# that is meant to be cut short, e.g. a smoke launch).
if [ -n "$VALIDATE" ]; then
    g_games=$(echo "$VALIDATE" | grep -oE -- '--games [0-9]+' | awk '{print $2}' || true)
    g_games=${g_games:-12}
    # same stripping as build_user_data, or --games' value counts as a seed
    g_seeds=$(echo "$VALIDATE" | sed -e 's/--games [0-9]*//' -e 's/--cand-ref [^ ]*//' \
              | cut -d' ' -f2- | xargs | wc -w)
    [ "$g_seeds" -ge 1 ] || g_seeds=1
    g_cap=$(sed -n 's/^SOAK_CAP_MIN=\${SOAK_CAP_MIN:-\([0-9]\{1,\}\)}.*/\1/p' \
            ../soak/soak_loop.sh 2>/dev/null | head -1)
    case "${g_cap:-}" in ''|*[!0-9]*) g_cap=25 ;; esac
    # cap/1.8 wall-minutes per game (measured control-slot timescale), one
    # drained game plus ceil(games/slots) fresh ones per half-wave, two
    # half-waves per seed, plus ~12 min of boot + steam refresh + `sleep 60`.
    g_per=$(( (g_cap * 10 + 17) / 18 ))
    g_rounds=$(( (g_games + SLOTS - 1) / SLOTS ))
    g_need=$(( g_seeds * 2 * (1 + g_rounds) * g_per + 12 ))
    g_hours=$(( (g_need + 59) / 60 ))
    if [ "$g_need" -gt "$WATCHDOG_MIN" ]; then
        echo "wave budget: cap=${g_cap}min x ${g_seeds} seed(s) x 2 legs x $((1 + g_rounds)) game(s)/leg" >&2
        echo "             ~${g_need} min needed, watchdog is ${WATCHDOG_MIN} min (--hours $HOURS)." >&2
        echo "             the last seed(s) would get no games, and the verdict would not say so." >&2
        if [ "$ALLOW_SHORT_WATCHDOG" -eq 1 ]; then
            echo "             --allow-short-watchdog given: launching anyway." >&2
        else
            echo "REFUSED: relaunch with --hours ${g_hours}, or pass --allow-short-watchdog." >&2
            exit 1
        fi
    fi
fi

build_user_data() {
    # $1 = RUN_ID (also the S3 run prefix under soak/)
    local run_id=$1
    cat <<EOF
#!/bin/bash
set -x
# ---- watchdog: hard self-terminate cap (paired with shutdown-behavior=terminate)
shutdown -h +$WATCHDOG_MIN
exec > /var/log/soak_farm.log 2>&1
export AWS_DEFAULT_REGION=$AWS_REGION

RUN_ID='$run_id'
S3_RUN="s3://$S3_BUCKET/soak/\$RUN_ID"

# ---- spot-interruption handler: on a reclaim notice, flush in-flight artifacts
# to S3 before the ~2-min cutoff (finished games already shipped per-game).
cat > /opt/spot_watch.sh <<'SW'
#!/bin/bash
S3_RUN="\$1"
while true; do
    TOK=\$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null)
    ACT=\$(curl -s -H "X-aws-ec2-metadata-token: \$TOK" \
        http://169.254.169.254/latest/meta-data/spot/instance-action 2>/dev/null)
    if echo "\$ACT" | grep -q '"action"'; then
        echo "SPOT INTERRUPTION: \$ACT" >> /var/log/soak_farm.log
        for f in /opt/soak/slot*/analysis_*.json; do
            [ -s "\$f" ] && aws s3 cp "\$f" "\$S3_RUN/\$(basename \$f)" --quiet
        done
        aws s3 cp /var/log/soak_farm.log "\$S3_RUN/soak_farm.log" --quiet
        break
    fi
    sleep 5
done
SW
chmod +x /opt/spot_watch.sh
setsid /opt/spot_watch.sh "\$S3_RUN" >/dev/null 2>&1 &

# ---- refresh repo (owned by ubuntu) to the requested ref
cd /opt/dota2bot
sudo -u ubuntu git fetch -q origin '$REF' || true
sudo -u ubuntu git checkout '$REF' || true
sudo -u ubuntu git pull --ff-only origin '$REF' || true
sudo -u ubuntu git log --oneline -1 || true

# ---- refresh game files via cached Steam session (no password; account in /opt/steam_user)
if [ -f /opt/steam_user ]; then
    sudo -u ubuntu steamcmd +force_install_dir /opt/dota2 \
        +login "\$(cat /opt/steam_user)" +app_update 570 +quit || true
fi

# ---- generate the farm-only soak draft pool (gitignored, must be regenerated)
sudo -u ubuntu python3 tools/batch_test/soak/gen_soak_pool.py \
    --out /opt/dota2bot/bots/Customize/soak_pool.lua || true

# ---- plain (single-version) deploy: symlink bots/ into the game vscripts dir
bash tools/batch_test/soak/plain_deploy.sh || true

# ---- launch the soak farm -> ships each finished game to \$S3_RUN
export SOAK_REC_SLOTS=$REC_SLOTS
bash tools/batch_test/soak/farm_start.sh $SLOTS "\$RUN_ID"
echo "soak farm up: \$RUN_ID ($SLOTS slots) -> \$S3_RUN"
EOF
    # optional autonomous validation: run it after the farm is up, then power
    # off (instance-initiated-shutdown-behavior=terminate makes this a real
    # terminate). VALIDATE = "CAND SEED1 SEED2 ... [--games N] [--cand-ref STR]".
    if [ -n "$VALIDATE" ]; then
        local vcand vgames vseeds vref
        vcand=$(echo "$VALIDATE" | awk '{print $1}')
        vgames=$(echo "$VALIDATE" | grep -oE -- '--games [0-9]+' | awk '{print $2}')
        # [GH #141] optional two-arm wave: "--cand-ref <armed-string>" makes the
        # reference leg carry its own ids instead of running stable. Stripped
        # out of the seed list exactly like --games is, or its value would be
        # parsed as a seed.
        vref=$(echo "$VALIDATE" | grep -oE -- '--cand-ref [^ ]+' | awk '{print $2}')
        vseeds=$(echo "$VALIDATE" | sed -e 's/--games [0-9]*//' -e 's/--cand-ref [^ ]*//' \
                 | cut -d' ' -f2- | xargs)
        cat <<EOF

# ---- autonomous multi-seed validation, then self-terminate
sleep 60   # let the first slots actually launch
CAND_REF='$vref' bash /opt/dota2bot/tools/batch_test/soak/validate_onspot.sh \
    '$vcand' '$vseeds' '${vgames:-12}' '$S3_BUCKET' "\$RUN_ID" >> /var/log/validate.log 2>&1
# [GH #167] same NAME_MAX collapse as the verdict object -- this basename is
# only ~12 bytes shorter than that one, so it overflows one wave later, not
# never.  One helper, so the two names cannot drift apart.
LOGNAME=\$(bash /opt/dota2bot/tools/batch_test/soak/soak_name.sh '$vcand' "_\$(date +%Y%m%d_%H%M)_run.log")
aws s3 cp /var/log/validate.log "s3://$S3_BUCKET/validation/\$LOGNAME" --quiet || true
shutdown -h now
EOF
    fi
}

launch_one() {
    # $1 = AZ ("" = let EC2 choose, the pre-#252 behavior), $2 = NAME,
    # $3 = RUN_ID, $4 = user-data. Echoes the instance id.
    local az=$1 name=$2 run_id=$3 ud=$4
    aws ec2 run-instances --region "$AWS_REGION" \
        --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
        ${KEY_NAME:+--key-name "$KEY_NAME"} --security-group-ids "$SECURITY_GROUP" \
        --iam-instance-profile Name="$IAM_PROFILE" \
        ${az:+--placement AvailabilityZone=$az} \
        $MARKET \
        --instance-initiated-shutdown-behavior terminate \
        --user-data "$ud" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name},{Key=soak-run,Value=$run_id}]" \
        --query 'Instances[0].InstanceId' --output text
}

echo "plan: $COUNT x $( [ $SPOT -eq 1 ] && echo SPOT || echo on-demand ) $INSTANCE_TYPE"
echo "  ref=$REF  slots=$SLOTS  rec_slots=$REC_SLOTS  watchdog=${HOURS}h  region=$AWS_REGION"
if [ ${#AZS[@]} -gt 0 ]; then
    echo "  az ring=${AZS[*]}  start=${AZS[$AZ_OFFSET]}$( [ -z "$AZ_ARG" ] && echo ' (random offset, see #252)' )"
else
    echo "  az=<ec2 chooses>  (no AZ spread: pre-#252 behavior)"
fi
echo

LAUNCHED=()
for n in $(seq 1 "$COUNT"); do
    RUN_ID="spot_${STAMP}_${n}_${REF//\//-}_${RUN_TOKEN}"
    NAME="${TAG_PREFIX}-${n}"
    UD=$(build_user_data "$RUN_ID")
    AZ=""
    [ ${#AZS[@]} -gt 0 ] && AZ=${AZS[$(( (AZ_OFFSET + n - 1) % ${#AZS[@]} ))]}

    if [ $DRYRUN -eq 1 ]; then
        echo "[dry-run] would launch $NAME  run_id=$RUN_ID  az=${AZ:-<ec2 chooses>}"
        echo "          S3: s3://$S3_BUCKET/soak/$RUN_ID/"
        continue
    fi

    # A pinned AZ can fail outright where an unpinned launch would have been
    # placed elsewhere ("no capacity" is per-AZ). Losing an instance to the
    # spread guard would be worse than the exposure it removes, so a pinned
    # failure falls back ONCE to the pre-#252 unpinned call.
    ERRLOG=$(mktemp)
    if ID=$(launch_one "$AZ" "$NAME" "$RUN_ID" "$UD" 2>"$ERRLOG"); then
        :
    elif [ -n "$AZ" ]; then
        echo "  ! $NAME: launch in $AZ failed -- $(tail -1 "$ERRLOG")" >&2
        echo "  ! retrying once with EC2-chosen placement (pre-#252 behavior)" >&2
        AZ=""
        ID=$(launch_one "" "$NAME" "$RUN_ID" "$UD")
    else
        cat "$ERRLOG" >&2
        rm -f "$ERRLOG"
        exit 1
    fi
    rm -f "$ERRLOG"

    LAUNCHED+=("$ID")
    echo "launched $NAME  id=$ID  run_id=$RUN_ID  az=${AZ:-<ec2 chose>}"
    echo "   S3: s3://$S3_BUCKET/soak/$RUN_ID/"
done

[ $DRYRUN -eq 1 ] && { echo; echo "(dry-run: nothing launched)"; exit 0; }

echo
echo "all instances self-terminate after ${HOURS}h (or on spot reclaim)."
echo "watch:  ./check_costs.sh"
echo "        awsx ec2 describe-instances --region $AWS_REGION --filters Name=tag:Name,Values=${TAG_PREFIX}-* Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[].[InstanceId,InstanceLifecycle,State.Name]' --output table"
echo "results: aws s3 ls s3://$S3_BUCKET/soak/"
echo "kill all: awsx ec2 terminate-instances --region $AWS_REGION --instance-ids ${LAUNCHED[*]}"
