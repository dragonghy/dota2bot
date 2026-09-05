#!/usr/bin/env bash
# Batch-run headless Dota 2 bot matches. See README.md in this directory.
#
#   ./run_batch.sh -n 10 -j 5 -t 4 -d ~/dota2 -o results/run1
#
# Requires: a Dota 2 install (SteamCMD), this repo's bots/ linked into
# game/dota/scripts/vscripts/bots.
set -euo pipefail

N_GAMES=10
PARALLEL=5
TIMESCALE=4
DOTA_DIR="$HOME/dota2"
OUT_DIR="results/$(date +%Y%m%d_%H%M%S)"
GAME_TIMEOUT_MIN=90   # wall-clock cap per game (at timescale 4, ~6h of game time)

usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while getopts 'n:j:t:d:o:h' opt; do
    case "$opt" in
        n) N_GAMES=$OPTARG ;;
        j) PARALLEL=$OPTARG ;;
        t) TIMESCALE=$OPTARG ;;
        d) DOTA_DIR=$OPTARG ;;
        o) OUT_DIR=$OPTARG ;;
        *) usage ;;
    esac
done

DOTA_BIN="$DOTA_DIR/game/bin/linuxsteamrt64/dota2"
[ -x "$DOTA_BIN" ] || { echo "dota2 binary not found at $DOTA_BIN" >&2; exit 1; }
SCRIPTS_LINK="$DOTA_DIR/game/dota/scripts/vscripts/bots"
[ -e "$SCRIPTS_LINK" ] || echo "WARNING: $SCRIPTS_LINK missing — bots will be default AI" >&2

mkdir -p "$OUT_DIR"
echo "batch: $N_GAMES games, $PARALLEL parallel, timescale $TIMESCALE -> $OUT_DIR"

run_one() {
    local i=$1
    local conlog="console_batch_${i}.log"     # per-instance, under game/dota/
    local log="$OUT_DIR/game_${i}.log"
    echo "[game $i] starting"
    rm -f "$DOTA_DIR/game/dota/$conlog"
    # Flag set validated on the diagnostic instance (2026-07-19):
    #  -nogc                            -> don't block map load waiting for the Steam GC
    #  +sv_hibernate_when_empty 0      -> no-humans server must not hibernate
    #  +dota_start_ai_game 1           -> auto-start the bot match (BEFORE +map)
    #  +dota_surrender_on_disconnect 0 + long all-disconnected timeout
    #                                   -> bots-only game isn't insta-ended as "all disconnected"
    #  +con_logfile per instance       -> parallel servers can't share -condebug's console.log
    LD_LIBRARY_PATH="$DOTA_DIR/game/bin/linuxsteamrt64:$DOTA_DIR/game/dota/bin/linuxsteamrt64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    timeout "${GAME_TIMEOUT_MIN}m" "$DOTA_BIN" \
        -dedicated -insecure -nogc -nowatchdog \
        -port $((27014 + i)) \
        +sv_lan 1 +sv_cheats 1 \
        +sv_hibernate_when_empty 0 \
        +dota_force_gamemode 23 \
        +dota_start_ai_game 1 \
        +dota_surrender_on_disconnect 0 \
        +dota_auto_surrender_all_disconnected_timeout 86400 \
        +host_timescale "$TIMESCALE" \
        -fill_with_bots \
        +con_logfile "$conlog" \
        +map dota \
        > "$log.stdout" 2>&1 || true
    # the console log is meant to be the parseable record, but +con_logfile does
    # not land on every AMI (Y1 2026-09-05: cp silently failed, every .log was
    # absent, all 80 game JSONs came back 0 bytes). The stdout redirect captures
    # the same "Match signout" scoreboard, so fall back to it: parse whichever of
    # $log / $log.stdout is non-empty. A wave must never be lost to a missing con
    # log when the stdout holds the identical record.
    cp "$DOTA_DIR/game/dota/$conlog" "$log" 2>/dev/null || true
    local parse_src="$log"
    if [ ! -s "$parse_src" ] && [ -s "$log.stdout" ]; then
        parse_src="$log.stdout"
    fi
    echo "[game $i] finished ($(wc -l < "$parse_src" 2>/dev/null || echo 0) log lines; src=$(basename "$parse_src"))"
    python3 "$(dirname "$0")/parse_log.py" "$parse_src" > "$OUT_DIR/game_${i}.json" || \
        echo "[game $i] parse failed — inspect $parse_src" >&2
}

# simple job pool
active=0
for i in $(seq 1 "$N_GAMES"); do
    run_one "$i" &
    active=$((active + 1))
    if [ "$active" -ge "$PARALLEL" ]; then
        wait -n
        active=$((active - 1))
    fi
done
wait
echo "batch complete: $OUT_DIR"
python3 "$(dirname "$0")/report.py" "$OUT_DIR" || true
