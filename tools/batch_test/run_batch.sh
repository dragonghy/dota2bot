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
    local log="$OUT_DIR/game_${i}.log"
    echo "[game $i] starting"
    # -condebug writes console output; we redirect stdout too and keep both.
    timeout "${GAME_TIMEOUT_MIN}m" "$DOTA_BIN" \
        -dedicated -insecure -nowatchdog \
        +sv_lan 1 +sv_cheats 1 \
        +map dota \
        +host_timescale "$TIMESCALE" \
        -fill_with_bots \
        +dota_auto_surrender_all_disconnected_timeout 0 \
        +tv_enable 0 \
        > "$log" 2>&1 || true
    echo "[game $i] finished ($(wc -l < "$log") log lines)"
    python3 "$(dirname "$0")/parse_log.py" "$log" > "$OUT_DIR/game_${i}.json" || \
        echo "[game $i] parse failed — inspect $log" >&2
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
