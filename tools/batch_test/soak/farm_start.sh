#!/usr/bin/env bash
# Start the soak farm on this instance: N parallel slot loops, staggered.
#   farm_start.sh [N_SLOTS] [RUN_ID]
set -u
N=${1:-16}
RUN_ID=${2:-run_$(date +%Y%m%d_%H%M)}
S3_PREFIX="s3://dota2bot-batch-results-4924/soak/$RUN_ID"
REPO=/opt/dota2bot

pkill -f soak_loop.sh 2>/dev/null; pkill -9 dota2 2>/dev/null; sleep 2
mkdir -p /opt/soak && chown -R ubuntu:ubuntu /opt/soak 2>/dev/null || true

# How many slots record a .dem ([harness] #75). Written to a file because the
# loops start through `sudo -u ubuntu`, which drops the environment. Absent =>
# soak_loop defaults to 1 = the pre-#75 behaviour.
if [ -n "${SOAK_REC_SLOTS:-}" ]; then
    echo "$SOAK_REC_SLOTS" > /opt/soak/rec_slots
    chown ubuntu:ubuntu /opt/soak/rec_slots 2>/dev/null || true
    echo "replay recording: slots 1..$SOAK_REC_SLOTS"
fi

for i in $(seq 1 "$N"); do
    setsid sudo -u ubuntu bash "$REPO/tools/batch_test/soak/soak_loop.sh" "$i" "$S3_PREFIX" \
        </dev/null > /opt/soak/loop_$i.out 2>&1 &
done
echo "soak farm started: $N slots -> $S3_PREFIX"
echo "$RUN_ID" > /opt/soak/current_run
