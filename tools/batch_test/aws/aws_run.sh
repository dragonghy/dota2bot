#!/usr/bin/env bash
command -v awsx >/dev/null && aws() { awsx "$@"; }
# Launch one unattended batch run on a self-terminating Spot instance.
#
#   ./aws_run.sh -n 100 --old main --new my-branch [--on-demand] [-t 4] [-j 8]
#   ./aws_run.sh --dry-run ...            # print the plan + user-data, launch nothing
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
MAX_HOURS_EXPLICIT=0    # director RULING 80 (甲1): a real wave must PASS --max-hours
DRYRUN=0
# On-demand list price for INSTANCE_TYPE in AWS_REGION, used only by the
# --dry-run exposure line below. RULING 80 (甲2) prices an aws_run.sh wave at
# the on-demand rate against its OWN watchdog, not at the $1.10 spot constant.
# Dated on purpose: a stale price here under-records the fence (the dangerous
# side), so the dry run prints the date and lets you override it.
OD_RATE_USD_H=${OD_RATE_USD_H:-0.673}   # c6i.4xlarge / us-west-2, charter 2026-08-24

while [ $# -gt 0 ]; do
    case "$1" in
        -n) N_GAMES=$2; shift 2 ;;
        --old) OLD_REF=$2; shift 2 ;;
        --new) NEW_REF=$2; shift 2 ;;
        -t) TIMESCALE=$2; shift 2 ;;
        -j) PARALLEL=$2; shift 2 ;;
        --on-demand) MARKET=""; shift ;;
        --max-hours) MAX_HOURS=$2; MAX_HOURS_EXPLICIT=1; shift 2 ;;
        --dry-run) DRYRUN=1; shift ;;
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
# The AMI's clone may be shallow, and the P4.1 upstream ruler wave measures
# against the repo's FIRST commit -- which a shallow clone simply does not
# have.  Deepen first, but only when shallow: --unshallow on a complete clone
# is an error.  [batch-desk 2026-09-18]
if [ "\$(sudo -u ubuntu git rev-parse --is-shallow-repository)" = "true" ]; then
    sudo -u ubuntu git fetch --unshallow origin || sudo -u ubuntu git fetch origin
fi
sudo -u ubuntu git fetch origin '$NEW_REF' '$OLD_REF' || sudo -u ubuntu git fetch origin
sudo -u ubuntu git checkout '$NEW_REF' && sudo -u ubuntu git pull --ff-only origin '$NEW_REF' || true

# Resolve a caller-supplied ref to a form 'git archive' accepts on THIS clone.
# A branch name must become origin/<name> (the checkout can be stale); a commit
# SHA or tag must be used BARE -- 'origin/<sha>' is not a ref at all and git
# rejects it with "not a valid object name".  Hardcoding the origin/ prefix is
# what made the P4.1 ruler wave (--old <upstream sha>) unlaunchable: it died in
# make_ab_build.py before a single game ran.  [batch-desk 2026-09-18]
resolve_ref() {
    if sudo -u ubuntu git rev-parse --verify --quiet "origin/\$1^{commit}" >/dev/null 2>&1; then
        echo "origin/\$1"
    elif sudo -u ubuntu git rev-parse --verify --quiet "\$1^{commit}" >/dev/null 2>&1; then
        echo "\$1"
    else
        return 1
    fi
}

# refresh game files (cached credentials from the AMI bake; /opt/steam_user
# holds the account name — no password needed for a cached session)
if [ -f /opt/steam_user ]; then
    sudo -u ubuntu steamcmd +force_install_dir /opt/dota2 +login "\$(cat /opt/steam_user)" +app_update 570 +quit || true
fi

VS=/opt/dota2/game/dota/scripts/vscripts
OUT=/opt/results/$RUN_ID

# Every build/output dir below is written by 'sudo -u ubuntu', but /opt is
# root-owned -- so ubuntu cannot create them and make_ab_build.py died on
# PermissionError while run_batch.sh went right on playing games with NO bots
# dir at all ("bots will be default AI"). That combination measures default AI
# against default AI and uploads it as a result, so create the dirs up front
# AND make a failed build fatal (below) rather than a warning. [Y1, 2026-09-05]
mkdir -p /opt/ab_fwd /opt/ab_rev \$OUT
chown ubuntu:ubuntu /opt/ab_fwd /opt/ab_rev /opt/results \$OUT

# Refuse to run games unless the A/B build actually landed. Without this the
# run is silently an A/A of stock bots -- a failure that looks like data.
ab_guard() {
    for d in bots bots_ab_new bots_ab_old; do
        [ -d "\$VS/\$d" ] && continue
        echo "FATAL: \$VS/\$d missing -- A/B build failed; refusing to run games"
        # die now instead of idling until the watchdog: ship the log so the
        # failure is diagnosable, then terminate.
        aws s3 cp /var/log/batch_run.log s3://$S3_BUCKET/$RUN_ID/batch_run.log
        shutdown -h now
        exit 1
    done
}

# An unresolvable ref must die HERE, not inside make_ab_build.py: that failure
# leaves the bots dirs missing, which ab_guard reports as "A/B build failed" --
# true, but it names the wrong cause and the next reader re-debugs the build.
OLD_ARCHIVE_REF=\$(resolve_ref '$OLD_REF') || {
    echo "FATAL: cannot resolve --old ref '$OLD_REF' on this clone"
    aws s3 cp /var/log/batch_run.log s3://$S3_BUCKET/$RUN_ID/batch_run.log
    shutdown -h now; exit 1
}
NEW_ARCHIVE_REF=\$(resolve_ref '$NEW_REF') || {
    echo "FATAL: cannot resolve --new ref '$NEW_REF' on this clone"
    aws s3 cp /var/log/batch_run.log s3://$S3_BUCKET/$RUN_ID/batch_run.log
    shutdown -h now; exit 1
}
echo "resolved refs: old='\$OLD_ARCHIVE_REF' new='\$NEW_ARCHIVE_REF'"

# direction 1: Radiant=NEW
sudo -u ubuntu python3 tools/batch_test/make_ab_build.py --old "\$OLD_ARCHIVE_REF" --new "\$NEW_ARCHIVE_REF" --out /opt/ab_fwd
rm -rf \$VS/bots \$VS/bots_ab_new \$VS/bots_ab_old
cp -r /opt/ab_fwd/bots /opt/ab_fwd/bots_ab_new /opt/ab_fwd/bots_ab_old \$VS/
ab_guard
sudo -u ubuntu tools/batch_test/run_batch.sh -n $HALF -j $PARALLEL -t $TIMESCALE -d /opt/dota2 -o \$OUT/fwd

# direction 2: sides swapped
sudo -u ubuntu python3 tools/batch_test/make_ab_build.py --old "\$OLD_ARCHIVE_REF" --new "\$NEW_ARCHIVE_REF" --swap --out /opt/ab_rev
rm -rf \$VS/bots \$VS/bots_ab_new \$VS/bots_ab_old
cp -r /opt/ab_rev/bots /opt/ab_rev/bots_ab_new /opt/ab_rev/bots_ab_old \$VS/
ab_guard
sudo -u ubuntu tools/batch_test/run_batch.sh -n $((N_GAMES - HALF)) -j $PARALLEL -t $TIMESCALE -d /opt/dota2 -o \$OUT/rev

aws s3 sync \$OUT s3://$S3_BUCKET/$RUN_ID/
aws s3 cp /var/log/batch_run.log s3://$S3_BUCKET/$RUN_ID/batch_run.log
shutdown -h now
EOF
)

# ---- director RULING 80 (乙): the rehearsal exit.
# This path had no --dry-run while spot_run.sh did, so it could not be walked
# without spending money -- and that is the carrier the P4.1 launch defect rode
# for forty-nine rounds (the `origin/<sha>` ref resolution died inside the
# rendered user-data, where nothing local ever looked).  The user-data is
# printed in full for exactly that reason: the bugs on this path live in it.
# LIMITS: this buys REHEARSABILITY. It does not verify that the wave will
# launch, that the refs resolve on the AMI's clone, or that the price below is
# what the wave will actually cost -- only AWS and the bill answer those.
if [ "$DRYRUN" -eq 1 ]; then
    MARKET_LABEL=$([ -n "$MARKET" ] && echo "spot" || echo "on-demand")
    WORST=$(awk "BEGIN{printf \"%.2f\", $OD_RATE_USD_H * $MAX_HOURS}")
    echo "[dry-run] would launch 1 instance for $RUN_ID"
    echo "          ami=$AMI_ID  type=$INSTANCE_TYPE  region=$AWS_REGION  market=$MARKET_LABEL"
    echo "          games=$N_GAMES (fwd $HALF / rev $((N_GAMES - HALF)))  -t $TIMESCALE  -j $PARALLEL"
    echo "          old='$OLD_REF'  new='$NEW_REF'"
    echo "          S3: s3://$S3_BUCKET/$RUN_ID/"
    echo
    if [ "$MAX_HOURS_EXPLICIT" -eq 1 ]; then
        echo "          watchdog: --max-hours $MAX_HOURS (EXPLICIT -- copy this value into the launch record, RULING 80 (甲1))"
    else
        echo "          watchdog: --max-hours $MAX_HOURS (DEFAULTED -- RULING 80 (甲1) forbids this on a real wave; pass it explicitly)"
    fi
    echo "          fence price (RULING 80 (甲2)): 1 x \$$OD_RATE_USD_H/h x ${MAX_HOURS}h = \$$WORST"
    echo "          ^ watchdog CAP at the on-demand rate, NOT a forecast and NOT the \$1.10 spot constant"
    echo "            (that constant is calibrated on 4 x 0.550h spot machine-hours; it does not price this path)."
    echo "          ^ \$$OD_RATE_USD_H/h is a charter constant dated 2026-08-24; override with OD_RATE_USD_H=<rate>."
    echo
    echo "---- rendered user-data (this is what the instance would run) ----"
    printf '%s\n' "$USER_DATA"
    echo "---- end user-data ----"
    echo
    echo "(dry-run: nothing launched)"
    exit 0
fi

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
