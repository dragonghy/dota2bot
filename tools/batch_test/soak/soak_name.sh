#!/usr/bin/env bash
# [GH #167] Build a validation/ object basename that fits NAME_MAX.
#
#   soak_name.sh <armed-string> <suffix>     -> prints "<token><suffix>"
#
# WHY THIS EXISTS
#   The verdict and run.log basenames were "<armed-string><suffix>" verbatim.
#   The armed string is MONOTONICALLY GROWING (16 ids -> 26 = 232 bytes ->
#   28 -> 29), so on 2026-08-24 the W7 verdict basename reached 266 bytes and
#   every `s3 cp --recursive validation/` died with `[Errno 36] File name too
#   long`.  That is NAME_MAX (255, one path COMPONENT) -- not PATH_MAX -- so a
#   shorter destination directory does not help, and the AWS CLI trips on it at
#   its own `.<random8>` temp file, before the rename.
#
#   The S3 key itself has no such limit, so nothing was ever lost server-side;
#   what broke is every path that pulls a verdict DOWN to a local disk.  And it
#   broke SILENTLY in the way that costs a session: `s3 cp --recursive` prints
#   its failures interleaved with normal progress, so `| tail` reads like a
#   clean run until you `ls` and find zero files.
#
# THE RULE
#   Short enough -> the armed string is kept VERBATIM.  Every basename ever
#   archived keeps meaning exactly what it meant (GH #167 §建议 3: do not
#   rename history, and let the harvest side read both forms).  Only when the
#   whole basename would exceed NAME_MAX does the string collapse to
#
#       <first-id>+<n>more-<sha1(armed-string)[:12]>
#
#   which stays human-identifiable (you can tell two waves apart at a glance)
#   AND machine-recoverable: the full string is in the verdict JSON's `cand`
#   field already, and the sha1 lets a harvester confirm the match instead of
#   guessing.
#
#   If even the collapsed form does not fit, this exits NON-ZERO and says so.
#   The defect this file fixes was a length overflow that nothing announced;
#   replacing it with a silent truncation would be the same defect with a
#   different tail.
set -uo pipefail

CAND="${1?armed string}"
SUFFIX="${2-}"

NAME_MAX=255

blen() { LC_ALL=C printf '%s' "$1" | wc -c | tr -d ' '; }

full="${CAND}${SUFFIX}"
if [ "$(blen "$full")" -le "$NAME_MAX" ]; then
    printf '%s' "$full"
    exit 0
fi

# Collapse.  sha1sum over the exact bytes of the armed string -- no trailing
# newline, so `printf '%s' "$CAND" | sha1sum` reproduces it anywhere.
sha=$(LC_ALL=C printf '%s' "$CAND" | sha1sum | cut -c1-12)
first=${CAND%%,*}
n=$(LC_ALL=C printf '%s' "$CAND" | tr ',' '\n' | grep -c .)
short="${first}+${n}ids-${sha}${SUFFIX}"

if [ "$(blen "$short")" -gt "$NAME_MAX" ]; then
    echo "soak_name.sh: collapsed basename is still $(blen "$short") > $NAME_MAX bytes" >&2
    echo "  suffix alone is $(blen "$SUFFIX") bytes -- shorten the suffix, do not truncate here" >&2
    exit 1
fi

printf '%s' "$short"
