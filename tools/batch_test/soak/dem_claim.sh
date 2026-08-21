#!/usr/bin/env bash
# Attribute a finished game's SourceTV .dem to the slot that recorded it.
#
# Why this file exists ([harness] #75): soak_loop.sh recorded on slot 1 only,
# because N slots share one replays/ directory and `ls -t | head -1` cannot say
# which server wrote which file. That one `if` hard-coded the frame-evidence
# sample size to 1/N of the games we pay for (16 slots => 5.1% of a wave kept
# any .dem). Naming the recorder is what unlocks N-slot recording, and naming
# it is all this file does.
#
# Three independent claims, strongest first:
#   logname   this slot's OWN console log names the .dem its server recorded.
#             Cross-slot ambiguity cannot exist -- one log, one server.
#   hostname  the demo header carries this game's `+hostname soak_<TAG>` stamp.
#   mtime     newest .dem wins. This is the pre-#75 heuristic and it is only
#             sound while the instance has a single recorder, so it is offered
#             only when REC_SLOTS=1 (i.e. it reproduces today's behaviour bit
#             for bit and is never used to break a tie between real recorders).
#
# No claim => no upload. A .dem attributed to the wrong game silently poisons
# frame evidence, which is strictly worse than having no .dem: the economic
# channel would still read fine while every frame-level conclusion drawn from
# it is about some other match.
#
# Emits one JSON object on stdout (the per-game claim sidecar). `path` is empty
# when nothing was claimed; every run reports what the other methods WOULD have
# picked, so an ordinary REC_SLOTS=1 wave validates the logname/hostname
# machinery for free before any wave depends on it.
set -u

DEM_CLAIM_HDR_BYTES=${DEM_CLAIM_HDR_BYTES:-65536}
DEM_CLAIM_LOCK=${DEM_CLAIM_LOCK:-/opt/soak/.replays.lock}

# _dem_json_str <s>  -- minimal JSON string escaping (paths + method names only)
_dem_json_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# _dem_candidates <replaydir>  -- every .dem currently sitting in the shared pool
_dem_candidates() {
    local rd="$1"
    find "$rd" "$rd/discarded/replays" -maxdepth 1 -type f -name '*.dem' \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-
}

# dem_claim <slot> <tag> <replaydir> <log_dem_name> <rec_slots> <dest>
#   log_dem_name: the .dem name this slot's own console log mentioned ("" if none)
#   dest:         where the claimed file is moved to (atomically, under the lock)
dem_claim() {
    local slot="$1" tag="$2" replaydir="$3" logdem="$4" rec_slots="$5" dest="$6"
    local by_log="" by_host="" by_mtime="" chosen="" method="none"
    local n=0 host_hits=0

    mkdir -p "$(dirname "$DEM_CLAIM_LOCK")" 2>/dev/null
    # One claimer at a time: candidates are resolved and the winner is moved out
    # of the shared pool inside the same critical section, so two slots can never
    # walk away believing they own the same file.
    exec 9>>"$DEM_CLAIM_LOCK" 2>/dev/null || true
    flock -w 60 9 2>/dev/null || true

    local f base
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -s "$f" ] || continue
        n=$((n + 1))
        base=$(basename "$f")
        if [ -n "$logdem" ] && [ -z "$by_log" ] && [ "$base" = "$(basename "$logdem")" ]; then
            by_log="$f"
        fi
        if [ -z "$by_host" ] && head -c "$DEM_CLAIM_HDR_BYTES" "$f" 2>/dev/null \
                | grep -aqF "$tag"; then
            by_host="$f"; host_hits=$((host_hits + 1))
        fi
        [ -z "$by_mtime" ] && by_mtime="$f"   # candidates arrive newest-first
    done <<EOF
$(_dem_candidates "$replaydir")
EOF

    if [ -n "$by_log" ]; then
        chosen="$by_log"; method="logname"
    elif [ -n "$by_host" ]; then
        chosen="$by_host"; method="hostname"
    elif [ "$rec_slots" = "1" ] && [ -n "$by_mtime" ]; then
        # Single recorder on this instance: newest == mine, same as pre-#75.
        chosen="$by_mtime"; method="mtime"
    fi

    if [ -n "$chosen" ] && [ -e "$chosen" ]; then
        if mv -f "$chosen" "$dest" 2>/dev/null; then
            chosen="$dest"
        else
            chosen=""; method="move_failed"
        fi
    elif [ -n "$chosen" ]; then
        chosen=""; method="vanished"
    fi

    flock -u 9 2>/dev/null || true
    exec 9>&- 2>/dev/null || true

    printf '{"slot":%s,"tag":"%s","method":"%s","path":"%s","candidates":%s,' \
        "$slot" "$(_dem_json_str "$tag")" "$method" "$(_dem_json_str "$chosen")" "$n"
    printf '"by_logname":"%s","by_hostname":"%s","by_mtime":"%s",' \
        "$(_dem_json_str "$(basename "${by_log:-}" 2>/dev/null)")" \
        "$(_dem_json_str "$(basename "${by_host:-}" 2>/dev/null)")" \
        "$(_dem_json_str "$(basename "${by_mtime:-}" 2>/dev/null)")"
    printf '"log_named":"%s","hostname_hits":%s,"rec_slots":%s}\n' \
        "$(_dem_json_str "$(basename "${logdem:-}" 2>/dev/null)")" \
        "$host_hits" "$rec_slots"
}

# dem_reap <replaydir> <max_age_min>  -- drop unclaimed .dem left by dead games.
# Only reached with more than one recorder: with a single recorder soak_loop
# still purges the whole pool exactly as it did before #75. A file older than
# the wall-clock game cap cannot belong to a live recording, so this cannot
# delete a game in progress.
dem_reap() {
    local rd="$1" age="${2:-20}"
    find "$rd" "$rd/discarded/replays" -maxdepth 1 -type f -name '*.dem' \
        -mmin "+$age" -delete 2>/dev/null || true
}
