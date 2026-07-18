#!/usr/bin/env bash
command -v awsx >/dev/null && aws() { awsx "$@"; }
# Launch one unattended batch run on a self-terminating Spot instance.
#
#   ./aws_run.sh -n 100 --old main --new my-branch [--on-demand] [-t 4] [-j 8]
#
# The instance: builds the A/B dirs (normal + swapped sides), runs half the
# games each way, syncs results to S3, then shuts down (= terminates).
# Watchdog: hard poweroff after MAX_HOURS regardless of progress.
set -euo pipefail
cd "$(dirname "$0")"
source aws.env
[ -n "$AMI_ID" ] || { echo "AMI_ID empty — run bake_ami.sh first" >&2; exit 1; }

N_GAMES=100; OLD_REF=main; NEW_REF=main; TIMESCALE=4; PARALLEL=8
MARKET="--instance-market-options MarketType=spot"
MAX_HOURS=12

while [ $# -gt 0 ]; do
    case "$1" in
        -n) N_GAMES=$2; shift 2 ;;
        --old) OLD_REF=$2; shift 2 ;;
        --new) NEW_REF=$2; shift 2 ;;
        -t) TIMESCALE=$2; shift 2 ;;
        -j) PARALLEL=$2; shift 2 ;;
        --on-demand) MARKET=""; shift ;;
        --max-hours) MAX_HOURS=$2; shift 2 ;;
        *) echo "unknown arg $1" >&2; exit 1 ;;
    esac
done

RUN_ID="run_$(date +%Y%m%d_%H%M%S)_${NEW_REF//\//-}_vs_${OLD_REF//\//-}"
HALF=$((N_GAMES / 2))

USER_DATA=$(cat <<EOF
#!/bin/bash
set -x
shutdown -h +$((MAX_HOURS * 60))    # watchdog: hard cap
exec > /var/log/batch_run.log 2>&1

cd /opt/dota2bot
sudo -u ubuntu git fetch origin '$NEW_REF' '$OLD_REF'
sudo -u ubuntu git checkout '$NEW_REF' && sudo -u ubuntu git pull --ff-only origin '$NEW_REF' || true

# refresh game files (cached credentials from the AMI bake; /opt/steam_user
# holds the account name — no password needed for a cached session)
if [ -f /opt/steam_user ]; then
    sudo -u ubuntu steamcmd +force_install_dir /opt/dota2 +login "\$(cat /opt/steam_user)" +app_update 570 +quit || true
fi

VS=/opt/dota2/game/dota/scripts/vscripts
OUT=/opt/results/$RUN_ID

# direction 1: Radiant=NEW
sudo -u ubuntu python3 tools/batch_test/make_ab_build.py --old 'origin/$OLD_REF' --new 'origin/$NEW_REF' --out /opt/ab_fwd
rm -rf \$VS/bots \$VS/bots_ab_new \$VS/bots_ab_old
cp -r /opt/ab_fwd/bots /opt/ab_fwd/bots_ab_new /opt/ab_fwd/bots_ab_old \$VS/
sudo -u ubuntu tools/batch_test/run_batch.sh -n $HALF -j $PARALLEL -t $TIMESCALE -d /opt/dota2 -o \$OUT/fwd

# direction 2: sides swapped
sudo -u ubuntu python3 tools/batch_test/make_ab_build.py --old 'origin/$OLD_REF' --new 'origin/$NEW_REF' --swap --out /opt/ab_rev
rm -rf \$VS/bots \$VS/bots_ab_new \$VS/bots_ab_old
cp -r /opt/ab_rev/bots /opt/ab_rev/bots_ab_new /opt/ab_rev/bots_ab_old \$VS/
sudo -u ubuntu tools/batch_test/run_batch.sh -n $((N_GAMES - HALF)) -j $PARALLEL -t $TIMESCALE -d /opt/dota2 -o \$OUT/rev

aws s3 sync \$OUT s3://$S3_BUCKET/$RUN_ID/
aws s3 cp /var/log/batch_run.log s3://$S3_BUCKET/$RUN_ID/batch_run.log
shutdown -h now
EOF
)

ID=$(aws ec2 run-instances --region "$AWS_REGION" \
    --image-id "$AMI_ID" --instance-type "$INSTANCE_TYPE" \
    ${KEY_NAME:+--key-name "$KEY_NAME"} --security-group-ids "$SECURITY_GROUP" \
    --iam-instance-profile Name="$IAM_PROFILE" \
    $MARKET \
    --instance-initiated-shutdown-behavior terminate \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=dota2bot-$RUN_ID}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "launched $ID for $RUN_ID"
echo "  ~$N_GAMES games, expect $(( N_GAMES * 12 / PARALLEL / 60 + 1 ))-ish hours; instance self-terminates."
echo "  results will land in s3://$S3_BUCKET/$RUN_ID/"
echo "  later: ./fetch_results.sh $RUN_ID"
