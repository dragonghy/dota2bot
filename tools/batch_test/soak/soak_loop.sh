#!/usr/bin/env bash
# One soak-farm slot: launch -> wait for game end -> analyze -> upload -> repeat.
# Drafting happens IN-GAME (custom_loader.ApplySoakDraft + Customize/soak_pool.lua),
# so slots are fully independent — no shared config writes, no lock.
#
#   soak_loop.sh <SLOT> <S3_PREFIX>
set -u
SLOT=${1:?slot number}
S3_PREFIX=${2:?s3 prefix}
DOTA=/opt/dota2
REPO=/opt/dota2bot
PORT=$((27020 + SLOT))
GAME_CAP_MIN=45          # wall-clock cap per game (4x turbo normally ~15 min)

mkdir -p /opt/soak/slot$SLOT
sleep $((SLOT * 10))     # one-time desync so slots don't all load the map at once

while true; do
    TS=$(date +%Y%m%d_%H%M%S)
    TAG="${TS}_slot${SLOT}"
    # Stamp the exact code version this game runs (captured at launch, before
    # any mid-game `git pull` from the iteration job can change HEAD).
    VER=$(cd "$REPO" && git describe --tags --always --dirty 2>/dev/null || echo unknown)

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
        echo \$! > /opt/soak/slot$SLOT/pid"

    PID=$(cat /opt/soak/slot$SLOT/pid 2>/dev/null || echo 0)
    START_EPOCH=$(date +%s)
    WAITED=0
    while kill -0 "$PID" 2>/dev/null && [ $WAITED -lt $((GAME_CAP_MIN * 60)) ]; do
        sleep 30; WAITED=$((WAITED + 30))
    done
    kill -9 "$PID" 2>/dev/null
    WALL_S=$(( $(date +%s) - START_EPOCH ))

    # collect + analyze + ship (dedicated-server stdout carries the console stream).
    # WALL_S lets analyze_log compute the achieved timescale (stdout has no
    # per-line clock, so wall time is measured here instead).
    LOG=/opt/soak/slot$SLOT/game_$TAG.log
    mv /opt/soak/slot$SLOT/stdout_$TAG.log "$LOG" 2>/dev/null
    if [ -s "$LOG" ]; then
        SOAK_WALL_S=$WALL_S SOAK_SCRIPT_VERSION="$VER" \
            python3 "$REPO/tools/batch_test/soak/analyze_log.py" "$LOG" \
            > /opt/soak/slot$SLOT/analysis_$TAG.json 2>/dev/null
        gzip -f "$LOG"
        aws s3 cp "$LOG.gz" "$S3_PREFIX/$TAG.log.gz" --quiet
        aws s3 cp /opt/soak/slot$SLOT/analysis_$TAG.json "$S3_PREFIX/$TAG.analysis.json" --quiet
        rm -f "$LOG.gz"
    fi
    sleep 5
done
