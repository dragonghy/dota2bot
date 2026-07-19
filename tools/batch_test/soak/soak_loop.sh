#!/usr/bin/env bash
# One soak-farm slot: draft -> launch -> wait for game end -> analyze -> upload -> repeat.
# Run N of these (distinct SLOT numbers) for parallelism. Designed for the
# batch AMI instance layout (/opt/dota2, /opt/dota2bot).
#
#   soak_loop.sh <SLOT> <S3_PREFIX>
# e.g. soak_loop.sh 1 s3://bucket/soak/run_20260719
set -u
SLOT=${1:?slot number}
S3_PREFIX=${2:?s3 prefix}
DOTA=/opt/dota2
REPO=/opt/dota2bot
VS=$DOTA/game/dota/scripts/vscripts
PORT=$((27020 + SLOT))
GAME_CAP_MIN=45          # wall-clock cap per game (4x turbo normally ~15 min)
LOCK=/tmp/soak_draft.lock

mkdir -p /opt/soak/slot$SLOT

while true; do
    TS=$(date +%Y%m%d_%H%M%S)
    TAG="${TS}_slot${SLOT}"

    # Serialize draft+launch+pick window: Customize/general.lua is global to
    # the shared install, so only one slot may draft while another's pick
    # phase is still reading it.
    (
        flock 9
        python3 "$REPO/tools/batch_test/soak/draft.py" \
            --customize "$REPO/bots/Customize/general.lua" > /opt/soak/slot$SLOT/draft_$TAG.json
        # 9>&- : do NOT leak the flock fd into the long-lived game process,
        # or the lock stays held for the whole game and slots serialize.
        # Console output goes to the per-slot stdout log (con_logfile proved
        # unreliable headless); parse_log handles the timestamp-less format.
        cd "$DOTA" && setsid bash -c "LD_LIBRARY_PATH=$DOTA/game/bin/linuxsteamrt64:$DOTA/game/dota/bin/linuxsteamrt64 \
            ./game/bin/linuxsteamrt64/dota2 \
            -dedicated -insecure -nogc -nowatchdog \
            -port $PORT \
            +sv_lan 1 +sv_cheats 1 \
            +sv_hibernate_when_empty 0 \
            +dota_force_gamemode 23 \
            +dota_start_ai_game 1 \
            +dota_surrender_on_disconnect 0 \
            +dota_auto_surrender_all_disconnected_timeout 86400 \
            +host_timescale 4 \
            -fill_with_bots \
            +map dota \
            </dev/null > /opt/soak/slot$SLOT/stdout_$TAG.log 2>&1 &
            echo \$! > /opt/soak/slot$SLOT/pid" 9>&-
        # hold the lock through map load + hero pick (~3 min), so the next
        # slot's draft can't clobber Customize mid-pick
        sleep 200
    ) 9>"$LOCK"

    PID=$(cat /opt/soak/slot$SLOT/pid 2>/dev/null || echo 0)
    # wait for natural end, capped
    WAITED=0
    while kill -0 "$PID" 2>/dev/null && [ $WAITED -lt $((GAME_CAP_MIN * 60)) ]; do
        sleep 30; WAITED=$((WAITED + 30))
    done
    kill -9 "$PID" 2>/dev/null

    # collect + analyze + ship (stdout log IS the console log for a
    # dedicated server; per-slot file, no cross-slot collision)
    LOG=/opt/soak/slot$SLOT/game_$TAG.log
    mv /opt/soak/slot$SLOT/stdout_$TAG.log "$LOG" 2>/dev/null
    if [ -s "$LOG" ]; then
        python3 "$REPO/tools/batch_test/soak/analyze_log.py" "$LOG" \
            > /opt/soak/slot$SLOT/analysis_$TAG.json 2>/dev/null
        gzip -f "$LOG"
        aws s3 cp "$LOG.gz" "$S3_PREFIX/$TAG.log.gz" --quiet
        aws s3 cp /opt/soak/slot$SLOT/analysis_$TAG.json "$S3_PREFIX/$TAG.analysis.json" --quiet
        aws s3 cp /opt/soak/slot$SLOT/draft_$TAG.json "$S3_PREFIX/$TAG.draft.json" --quiet
        rm -f "$LOG.gz"
    fi
    sleep 5
done
