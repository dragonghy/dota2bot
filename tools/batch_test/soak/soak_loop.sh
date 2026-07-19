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
SOAK_CAP_MIN=${SOAK_CAP_MIN:-10}   # game-minute lock enforced by the referee
GAME_CAP_MIN=15          # wall-clock kill backstop; the rcon referee should
                         # always end the match first with a real scoreboard
RCON_PW=soakref          # LAN-only dedicated server, constant password is fine
REFEREE="$REPO/tools/batch_test/soak/referee.py"

mkdir -p /opt/soak/slot$SLOT
sleep $((SLOT * 10))     # one-time desync so slots don't all load the map at once

# Replay recording: only slot 1 records (keeps disk + attribution sane — one
# recorder means the newest .dem is unambiguously this game's). Every slot-1
# game's .dem is uploaded to S3 for owner review + the behavioral bug pipeline
# (tools/batch_test/behavioral/batch_s3.sh), then deleted locally.
REC=""
REPLAYDIR="$DOTA/game/dota/replays"
if [ "$SLOT" = "1" ]; then REC="+tv_enable 1 +tv_autorecord 1 +tv_delay 0"; fi

while true; do
    TS=$(date +%Y%m%d_%H%M%S)
    TAG="${TS}_slot${SLOT}"
    # Stamp the exact code version this game runs (captured at launch, before
    # any mid-game `git pull` from the iteration job can change HEAD).
    # During a mirror run ab_deploy.sh leaves /opt/soak/ab_version describing
    # both sides — that stamp wins.
    VER=$(cat /opt/soak/ab_version 2>/dev/null \
        || (cd "$REPO" && git describe --tags --always --dirty 2>/dev/null) \
        || echo unknown)

    cd "$DOTA" && setsid bash -c "LD_LIBRARY_PATH=$DOTA/game/bin/linuxsteamrt64:$DOTA/game/dota/bin/linuxsteamrt64 \
        ./game/bin/linuxsteamrt64/dota2 \
        -dedicated -insecure -nogc -nowatchdog \
        -port $PORT \
        -usercon +rcon_password $RCON_PW \
        $REC \
        +sv_lan 1 +sv_cheats 1 \
        +sv_hibernate_when_empty 0 \
        +dota_surrender_on_disconnect 0 \
        +dota_auto_surrender_all_disconnected_timeout 86400 \
        +dota_bot_practice_difficulty 3 \
        +dota_bot_practice_gamemode 23 \
        +dota_force_gamemode 23 \
        +dota_lobby_browser_selected_gamemode 23 \
        +dota_bot_practice_start 1 \
        +host_timescale 4 \
        -fill_with_bots \
        +map dota \
        </dev/null > /opt/soak/slot$SLOT/stdout_$TAG.log 2>&1 &
        echo \$! > /opt/soak/slot$SLOT/pid"

    PID=$(cat /opt/soak/slot$SLOT/pid 2>/dev/null || echo 0)
    START_EPOCH=$(date +%s)
    WAITED=0
    while kill -0 "$PID" 2>/dev/null && [ $WAITED -lt $((GAME_CAP_MIN * 60)) ]; do
        sleep 15; WAITED=$((WAITED + 15))
        # game-clock referee: anchors on the horn, refines with Building
        # timestamps, extrapolates, and past SOAK_CAP_MIN fires
        # `dota_dev forcewin` (instant end, normal signout; analyze_log
        # overrides the winner with the economic leader).
        if [ $WAITED -ge 60 ]; then
            python3 "$REFEREE" "$PORT" "$RCON_PW" \
                /opt/soak/slot$SLOT/stdout_$TAG.log \
                /opt/soak/slot$SLOT/refstate_$TAG.json \
                --cap-min "$SOAK_CAP_MIN" \
                >> /opt/soak/slot$SLOT/referee_$TAG.log 2>&1 || true
        fi
    done
    kill -9 "$PID" 2>/dev/null
    WALL_S=$(( $(date +%s) - START_EPOCH ))

    # collect + analyze + ship (dedicated-server stdout carries the console stream).
    # WALL_S lets analyze_log compute the achieved timescale (stdout has no
    # per-line clock, so wall time is measured here instead).
    LOG=/opt/soak/slot$SLOT/game_$TAG.log
    mv /opt/soak/slot$SLOT/stdout_$TAG.log "$LOG" 2>/dev/null
    if [ -s "$LOG" ]; then
        SOAK_WALL_S=$WALL_S SOAK_SCRIPT_VERSION="$VER" SOAK_CAP_MIN="$SOAK_CAP_MIN" \
            python3 "$REPO/tools/batch_test/soak/analyze_log.py" "$LOG" \
            > /opt/soak/slot$SLOT/analysis_$TAG.json 2>/dev/null
        gzip -f "$LOG"
        aws s3 cp "$LOG.gz" "$S3_PREFIX/$TAG.log.gz" --quiet
        aws s3 cp /opt/soak/slot$SLOT/analysis_$TAG.json "$S3_PREFIX/$TAG.analysis.json" --quiet
        rm -f "$LOG.gz"
    fi
    # slot 1: ship the freshly recorded replay, then purge local .dem
    if [ "$SLOT" = "1" ]; then
        DEM=$(ls -t "$REPLAYDIR"/*.dem "$REPLAYDIR"/discarded/replays/*.dem 2>/dev/null | head -1)
        if [ -n "$DEM" ] && [ -s "$DEM" ]; then
            aws s3 cp "$DEM" "$S3_PREFIX/$TAG.dem" --quiet
            aws s3 cp "$DEM" "s3://dota2bot-batch-results-4924/replays/$TAG.dem" --quiet
        fi
        rm -f "$REPLAYDIR"/*.dem "$REPLAYDIR"/discarded/replays/*.dem 2>/dev/null
    fi
    sleep 5
done
