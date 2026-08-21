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

# Replay recording. Slots 1..REC_SLOTS record; REC_SLOTS=1 is the pre-#75
# default and behaves bit for bit as it always did (one recorder means the
# newest .dem is unambiguously this game's). Raising it is what buys frame
# evidence: the economic channel's n has always been every game, the frame
# channel's n was games/N, and that ratio was this one setting ([harness] #75).
#
# The knob is a file, not an env var: farm_start.sh starts each loop through
# `sudo -u ubuntu`, which drops the environment. Env still wins when present so
# a single loop can be driven by hand.
REPLAYDIR="$DOTA/game/dota/replays"
REC_SLOTS=${SOAK_REC_SLOTS:-$(cat /opt/soak/rec_slots 2>/dev/null || echo 1)}
case "$REC_SLOTS" in ''|*[!0-9]*) REC_SLOTS=1 ;; esac
RECORDING=0
[ "$SLOT" -le "$REC_SLOTS" ] && RECORDING=1
# shellcheck source=dem_claim.sh
. "$REPO/tools/batch_test/soak/dem_claim.sh" 2>/dev/null || true
if ! type dem_claim >/dev/null 2>&1; then
    # Ships in the same commit as this file, so this is a broken checkout rather
    # than a real branch. Say so and record nothing: an unclaimable .dem is only
    # disk, but a silently mis-shipped one is bad frame evidence.
    echo "slot$SLOT: dem_claim.sh missing — replay recording DISABLED" >&2
    RECORDING=0
fi

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

    # Purge stale .dem BEFORE launch so the post-game claim can't grab a
    # leftover replay from an earlier/killed game (attribution safety).
    # With one recorder the whole pool is ours to wipe, exactly as before #75.
    # With several, wiping it would destroy the other slots' recordings that are
    # being written RIGHT NOW, so only genuinely dead files are reaped.
    if [ "$RECORDING" = "1" ]; then
        if [ "$REC_SLOTS" = "1" ]; then
            rm -f "$REPLAYDIR"/*.dem "$REPLAYDIR"/discarded/replays/*.dem 2>/dev/null
        else
            dem_reap "$REPLAYDIR" $((GAME_CAP_MIN + 5))
        fi
    fi

    # Per-game recording args. The +hostname stamp is the second, independent
    # way to tell whose .dem is whose: it rides in the demo header, so a claim
    # can be checked against the file itself rather than against the clock.
    REC=""
    [ "$RECORDING" = "1" ] && \
        REC="+tv_enable 1 +tv_autorecord 1 +tv_delay 0 +hostname soak_$TAG"

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
    # The strongest attribution we have, taken while the log is still plain
    # text: whatever .dem this slot's own console named, this slot recorded.
    LOGDEM=""
    if [ "$RECORDING" = "1" ] && [ -s "$LOG" ]; then
        LOGDEM=$(grep -aoE '[A-Za-z0-9_.:/-]+\.dem' "$LOG" 2>/dev/null | tail -1)
    fi
    if [ -s "$LOG" ]; then
        SOAK_WALL_S=$WALL_S SOAK_SCRIPT_VERSION="$VER" SOAK_CAP_MIN="$SOAK_CAP_MIN" \
            python3 "$REPO/tools/batch_test/soak/analyze_log.py" "$LOG" \
            > /opt/soak/slot$SLOT/analysis_$TAG.json 2>/dev/null
        gzip -f "$LOG"
        aws s3 cp "$LOG.gz" "$S3_PREFIX/$TAG.log.gz" --quiet
        aws s3 cp /opt/soak/slot$SLOT/analysis_$TAG.json "$S3_PREFIX/$TAG.analysis.json" --quiet
        rm -f "$LOG.gz"
    fi
    # Claim this game's replay out of the shared pool and ship it. The claim
    # sidecar goes up on every recorded game, including ordinary REC_SLOTS=1
    # waves, so the logname/hostname machinery is proven on data we were paying
    # for anyway before any wave's evidence depends on it.
    if [ "$RECORDING" = "1" ]; then
        MINE=/opt/soak/slot$SLOT/$TAG.dem
        CLAIM=/opt/soak/slot$SLOT/$TAG.demclaim.json
        dem_claim "$SLOT" "$TAG" "$REPLAYDIR" "$LOGDEM" "$REC_SLOTS" "$MINE" > "$CLAIM"
        aws s3 cp "$CLAIM" "$S3_PREFIX/$TAG.demclaim.json" --quiet
        if [ -s "$MINE" ]; then
            aws s3 cp "$MINE" "$S3_PREFIX/$TAG.dem" --quiet
            # Bulk recording only: tag for the bucket's 21-day `soak-dem-expire-21d`
            # rule (tag-filtered, so it can never reach a .log.gz/.analysis.json —
            # the per-game archive the replay stream depends on stays forever).
            # Untagged means today's retention, so a REC_SLOTS=1 wave keeps every
            # .dem exactly as long as it always has.
            if [ "$REC_SLOTS" != "1" ]; then
                S3_NOSCHEME=${S3_PREFIX#s3://}
                aws s3api put-object-tagging \
                    --bucket "${S3_NOSCHEME%%/*}" --key "${S3_NOSCHEME#*/}/$TAG.dem" \
                    --tagging 'TagSet=[{Key=lifecycle,Value=dem21}]' >/dev/null 2>&1
            fi
            # The flat replays/ mirror is the owner-review + behavioral-sweep
            # entry point. Keep it for slot 1 only: at 16 recorders a second
            # copy of every game is ~6 GB/wave of duplicate storage.
            [ "$SLOT" = "1" ] && \
                aws s3 cp "$MINE" "s3://dota2bot-batch-results-4924/replays/$TAG.dem" --quiet
        fi
        rm -f "$MINE" "$CLAIM"
        # Single recorder: the pool is ours, wipe it as before #75.
        [ "$REC_SLOTS" = "1" ] && \
            rm -f "$REPLAYDIR"/*.dem "$REPLAYDIR"/discarded/replays/*.dem 2>/dev/null
    fi
    sleep 5
done
