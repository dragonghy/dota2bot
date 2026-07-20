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
#   ./spot_run.sh --on-demand             # escape hatch: on-demand (no reclaim risk)
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
HOURS=3             # watchdog hard cap (self-terminate). Outer bound: use --hours 12.
VALIDATE=""         # "--validate 'CAND SEED1 SEED2 ... [--games N]'": after farm_start,
                    # run tools/batch_test/soak/validate_onspot.sh with these args,
                    # upload the verdict to s3://$S3_BUCKET/validation/, then
                    # shut down immediately (terminate) instead of waiting for the
                    # watchdog. This is the scheduled job's cross-firing handoff.
MARKET="--instance-market-options MarketType=spot,SpotOptions={SpotInstanceType=one-time,InstanceInterruptionBehavior=terminate}"
SPOT=1
DRYRUN=0
TAG_PREFIX=dota2bot-soak-spot
STAMP=$(date +%Y%m%d_%H%M%S)

while [ $# -gt 0 ]; do
    case "$1" in
        --count) COUNT=$2; shift 2 ;;
        --ref) REF=$2; shift 2 ;;
        --slots) SLOTS=$2; shift 2 ;;
        --hours) HOURS=$2; shift 2 ;;
        --type) INSTANCE_TYPE=$2; shift 2 ;;
        --validate) VALIDATE=$2; shift 2 ;;
        --on-demand) MARKET=""; SPOT=0; TAG_PREFIX=dota2bot-soak-od; shift ;;
        --dry-run) DRYRUN=1; shift ;;
        *) echo "unknown arg $1" >&2; exit 1 ;;
    esac
done

WATCHDOG_MIN=$((HOURS * 60))

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
bash tools/batch_test/soak/farm_start.sh $SLOTS "\$RUN_ID"
echo "soak farm up: \$RUN_ID ($SLOTS slots) -> \$S3_RUN"
EOF
    # optional autonomous validation: run it after the farm is up, then power
    # off (instance-initiated-shutdown-behavior=terminate makes this a real
    # terminate). VALIDATE = "CAND SEED1 SEED2 ... [--games N]".
    if [ -n "$VALIDATE" ]; then
        local vcand vgames vseeds
        vcand=$(echo "$VALIDATE" | awk '{print $1}')
        vgames=$(echo "$VALIDATE" | grep -oE -- '--games [0-9]+' | awk '{print $2}')
        vseeds=$(echo "$VALIDATE" | sed -e 's/--games [0-9]*//' | cut -d' ' -f2- | xargs)
        cat <<EOF

# ---- autonomous multi-seed validation, then self-terminate
sleep 60   # let the first slots actually launch
bash /opt/dota2bot/tools/batch_test/soak/validate_onspot.sh \
    '$vcand' '$vseeds' '${vgames:-12}' '$S3_BUCKET' >> /var/log/validate.log 2>&1
aws s3 cp /var/log/validate.log "s3://$S3_BUCKET/validation/${vcand}_\$(date +%Y%m%d_%H%M)_run.log" --quiet || true
shutdown -h now
EOF
    fi
}

echo "plan: $COUNT x $( [ $SPOT -eq 1 ] && echo SPOT || echo on-demand ) $INSTANCE_TYPE"
echo "  ref=$REF  slots=$SLOTS  watchdog=${HOURS}h  region=$AWS_REGION"
echo

LAUNCHED=()
for n in $(seq 1 "$COUNT"); do
    RUN_ID="spot_${STAMP}_${n}_${REF//\//-}"
    NAME="${TAG_PREFIX}-${n}"
    UD=$(build_user_data "$RUN_ID")

    if [ $DRYRUN -eq 1 ]; then
        echo "[dry-run] would launch $NAME  run_id=$RUN_ID"
        echo "          S3: s3://$S3_BUCKET/soak/$RUN_ID/"
        continue
    fi

    ID=$(aws ec2 run-instances --region "$AWS_REGION" \
        --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
        ${KEY_NAME:+--key-name "$KEY_NAME"} --security-group-ids "$SECURITY_GROUP" \
        --iam-instance-profile Name="$IAM_PROFILE" \
        $MARKET \
        --instance-initiated-shutdown-behavior terminate \
        --user-data "$UD" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=soak-run,Value=$RUN_ID}]" \
        --query 'Instances[0].InstanceId' --output text)

    LAUNCHED+=("$ID")
    echo "launched $NAME  id=$ID  run_id=$RUN_ID"
    echo "   S3: s3://$S3_BUCKET/soak/$RUN_ID/"
done

[ $DRYRUN -eq 1 ] && { echo; echo "(dry-run: nothing launched)"; exit 0; }

echo
echo "all instances self-terminate after ${HOURS}h (or on spot reclaim)."
echo "watch:  ./check_costs.sh"
echo "        awsx ec2 describe-instances --region $AWS_REGION --filters Name=tag:Name,Values=${TAG_PREFIX}-* Name=instance-state-name,Values=pending,running --query 'Reservations[].Instances[].[InstanceId,InstanceLifecycle,State.Name]' --output table"
echo "results: aws s3 ls s3://$S3_BUCKET/soak/"
echo "kill all: awsx ec2 terminate-instances --region $AWS_REGION --instance-ids ${LAUNCHED[*]}"
