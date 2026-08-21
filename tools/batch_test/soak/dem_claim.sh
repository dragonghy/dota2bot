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
DEM_AWS=${DEM_AWS:-aws}          # injection point for the offline tests

# dem_bulk_prefix <s3_prefix> <rec_slots>  -- where this slot's .dem goes.
#
# Retention is carried by the KEY, not by an object tag. The runner instance
# profile grants s3:PutObject/GetObject/ListBucket only (see the s3-results
# policy in tools/batch_test/aws/setup_aws.sh) -- it has NO s3:PutObjectTagging,
# so every tagging call made from an instance is denied, and a tag-filtered
# lifecycle rule would match nothing at all. Bulk recordings therefore live
# under the bucket-level `dem21/<run>/` prefix, covered by a plain prefix
# lifecycle rule that needs no permission the uploader lacks and cannot fail
# halfway. `soak/<run>/` keeps only the per-game archive (.analysis.json,
# .log.gz, .demclaim.json) that the replay stream depends on and that must
# never expire.
#
# REC_SLOTS=1 (the shipped default) returns the input untouched: its single
# .dem still lands in soak/<run>/ and replays/ and still never expires.
dem_bulk_prefix() {
    local prefix="$1" rec_slots="${2:-1}" nos run
    if [ "$rec_slots" = "1" ]; then
        printf '%s' "$prefix"
        return
    fi
    nos=${prefix#s3://}          # bucket/soak/<run>
    run=${nos#*/}                # soak/<run>
    run=${run#soak/}             # <run>
    printf 's3://%s/dem21/%s' "${nos%%/*}" "$run"
}

# dem_flat_key <tag> <s3_prefix>  -- basename of the flat `replays/` mirror.
#
# Why the run id is in the name ([harness] #95). $TAG is `<HHMMSS stamp>_slot1`
# and every instance of a wave records its own slot 1, so two instances that
# start a game in the SAME SECOND write the same key -- and S3 has no collision:
# the second PUT simply wins. 21 of the 991 flat keys are such a pair (measured
# 2026-08-21 by grouping soak/**.dem by basename), including the frame GH #59
# was filed on. The failure mode is the worst one this project has: the flat
# copy is a whole, dumpable, normal-looking replay OF A DIFFERENT MATCH, so a
# lookup by filename is answered wrongly and quietly. That is the same doctrine
# this file already states for the claim itself -- a .dem attributed to the
# wrong game is strictly worse than no .dem -- applied one level up, to the key.
#
# The run id is appended rather than prefixed so `replays/<date>_<time>*` globs
# (how every existing corpus is selected) keep working unchanged, and so the
# flat mirror finally says which run it came from. Historical keys are left
# alone; they are repairable offline, since each flat copy's SIZE matches
# exactly one of its soak/ namesakes (21/21 resolvable, same measurement).
#
# No run id => empty output => the caller writes NO mirror. Falling back to the
# bare $TAG would silently re-create the collision this function exists to
# remove, and an absent mirror is missing evidence while a colliding one is
# wrong evidence (dem_claim's "no claim => no upload", same reason).
dem_flat_key() {
    local tag="$1" prefix="${2:-}" nos run
    nos=${prefix#s3://}          # bucket/soak/<run>
    nos=${nos%/}
    run=${nos#*/}                # soak/<run>
    run=${run#soak/}             # <run>
    case "$run" in
        ''|*/*|"$nos") return ;; # no recognisable single run id -- say nothing
    esac
    printf '%s__%s.dem' "$tag" "$run"
}

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

# dem_reap <replaydir> <max_age_min> [s3_prefix] [hard_age_min]
#   Rescue-then-drop the unclaimed .dem left behind by dead games. Only reached
#   with more than one recorder: with a single recorder soak_loop still purges
#   the whole pool exactly as it did before #75. A file older than the wall-clock
#   game cap cannot belong to a live recording, so this never touches a game in
#   progress.
#
# Why rescue rather than delete (#75 §X.1 乙): "no claim => no upload" is right
# about ATTRIBUTION but makes the multi-recorder path all-or-nothing, and the
# thing it throws away is an UNLABELLED .dem, not a MISLABELLED one. The game's
# analysis.json (final score, duration, heroes) is enough to join it back
# offline, so the downside of a wave where all three claim chains miss drops
# from "that seed's frame evidence is gone" to "that seed's frame evidence needs
# one offline join".
#
# <s3_prefix> here is the BULK prefix (dem_bulk_prefix), not soak/<run>/, so a
# rescued .dem expires with the rest of the wave's recordings.
#
# The key is the file's OWN basename under <s3_prefix>/unattributed/, which is
# what makes 16 slots racing to rescue the same file idempotent: they all write
# the same bytes to the same object, so no coordination is needed.
#
# Upload failure does not strand disk: a file that is still here past hard_age
# (default 3x) is dropped anyway, preserving the pre-#75 disk guarantee with a
# bounded lag. Prints one summary line to stderr.
dem_reap() {
    local rd="$1" age="${2:-20}" prefix="${3:-}" hard="${4:-}"
    [ -n "$hard" ] || hard=$((age * 3))
    local rescued=0 failed=0 dropped=0 f base key

    while IFS= read -r f; do
        [ -n "$f" ] || continue
        base=$(basename "$f")
        if [ -n "$prefix" ] && [ -s "$f" ]; then
            key="$prefix/unattributed/$base"
            if $DEM_AWS s3 cp "$f" "$key" --quiet 2>/dev/null; then
                # No tagging call: the caller passes a prefix that is already
                # under the expiring `dem21/` tree (dem_bulk_prefix), and the
                # instance profile could not tag an object even if we asked.
                rm -f "$f" 2>/dev/null && rescued=$((rescued + 1))
                continue
            fi
            failed=$((failed + 1))
            # Keep it for the next pass unless it is so old that holding it is
            # just a disk leak.
            [ -n "$(find "$f" -maxdepth 0 -mmin "+$hard" 2>/dev/null)" ] || continue
        fi
        rm -f "$f" 2>/dev/null && dropped=$((dropped + 1))
    done <<EOF
$(find "$rd" "$rd/discarded/replays" -maxdepth 1 -type f -name '*.dem' \
    -mmin "+$age" 2>/dev/null)
EOF

    echo "dem_reap: rescued=$rescued upload_failed=$failed dropped=$dropped" >&2
}
