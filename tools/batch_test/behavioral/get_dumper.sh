#!/usr/bin/env bash
# Fast acquisition of the behav-dump binary for a fresh Claude Code container.
#
# Routine sessions (replay-check et al.) are fresh-per-fire: without caching,
# every session pays the full ~10-20 min Go-toolchain + manta-patch + build
# cost from setup_instance.sh before it can look at a single frame (see
# iterations/reports/replay-check/20260819T004401Z.md section 1, issue #25).
#
# This script tries a cached prebuilt binary from S3 first (seconds); only on
# a cache miss (first-ever run, or dumper/main.go changed) does it fall back
# to a full local build, and then uploads the fresh binary back to S3 so the
# NEXT session hits the fast path. Safe to re-run; does not touch any running
# soak farm or launch any billable AWS resource (S3 GET/PUT only).
#
#   get_dumper.sh [OUT_DIR]
# Prints the path to the ready-to-run behav-dump binary as the last stdout
# line (all progress/log goes to stderr) -- so `BIN=$(get_dumper.sh)` works.
#
# Requires AWS creds in-session (bash tools/batch_test/aws/session_setup.sh)
# for the S3 cache; falls back to build-only (no cache read/write) if AWS
# isn't available, since parsing itself needs no AWS access.
set -euo pipefail

REPO=${BEHAV_REPO:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"}
OUT=${1:-"$REPO/.dumper_cache"}
BUCKET=${DOTA2BOT_S3_BUCKET:-dota2bot-batch-results-4924}
DUMPER_SRC="$REPO/dumper/main.go"
PATCH_RECIPE="$REPO/setup_instance.sh"
BIN="$OUT/behav-dump"
GO_VER=1.22.5
MANTA_VER=v1.5.0

mkdir -p "$OUT"

# [harness] #102: two sweeps running at once share this one $OUT. Two distinct
# races live here, and they need two distinct fixes -- a lock alone does NOT
# close the observed one:
#   (1) EXEC-vs-OVERWRITE (what actually bit): sweep A is inside its per-game
#       loop exec'ing $BIN while sweep B re-downloads/chmods that same path.
#       A gets "Permission denied" (or a half-written file) mid-sweep, dies
#       under set -e, and leaves a partial corpus that looks complete (#102).
#       A lock cannot help: A is not inside get_dumper.sh when it execs.
#       Fixed by installing the binary with an ATOMIC rename below -- a running
#       exec keeps the old inode, and any new exec sees a complete file.
#   (2) BUILD-vs-BUILD: two cache misses would share $GOPATH/$GOCACHE and the
#       patched manta_local tree (which is rm -rf'd and re-copied), corrupting
#       each other. That one IS a lock's job, so take one for the whole
#       acquire -- the loser waits for the winner's build (10-20 min) and then
#       hits the cache, instead of racing it.
if [ -z "${GET_DUMPER_LOCKED:-}" ] && command -v flock >/dev/null 2>&1; then
    exec env GET_DUMPER_LOCKED=1 flock "$OUT/.lock" "$0" "$@"
fi

# Cache key = hash of the dumper source + the manta-patch recipe, so any
# change to either automatically invalidates stale cached binaries.
SRC_HASH=$(cat "$DUMPER_SRC" "$PATCH_RECIPE" | sha256sum | cut -c1-16)
S3_KEY="tools/dumper/behav-dump-${SRC_HASH}"
S3_URI="s3://${BUCKET}/${S3_KEY}"
echo "[get_dumper] cache key: $SRC_HASH" >&2

AWS_CMD=""
if command -v awsx >/dev/null 2>&1; then AWS_CMD=awsx
elif command -v aws >/dev/null 2>&1; then AWS_CMD=aws
fi

# Staging path for the atomic install (same filesystem as $BIN, so mv is a
# rename(2) and never a copy). See the EXEC-vs-OVERWRITE note above.
STAGE="$OUT/.behav-dump.$$"
trap 'rm -f "$STAGE"' EXIT

if [ -n "$AWS_CMD" ] && $AWS_CMD s3 cp "$S3_URI" "$STAGE" --quiet 2>/dev/null && [ -s "$STAGE" ]; then
    chmod +x "$STAGE"
    mv -f "$STAGE" "$BIN"          # atomic: no reader ever sees a partial $BIN
    echo "[get_dumper] cache HIT: pulled $S3_URI (skip build)" >&2
    echo "$BIN"
    exit 0
fi
echo "[get_dumper] cache MISS ($S3_URI) -- building locally" >&2

# --- local build (mirrors setup_instance.sh's recipe, parametrized on $OUT) ---
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="$OUT/gopath" GOCACHE="$OUT/gocache"

if ! /usr/local/go/bin/go version >/dev/null 2>&1; then
    echo "[get_dumper] installing Go $GO_VER" >&2
    curl -sSL -m 180 -o /tmp/go_dumper.tgz "https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz"
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go_dumper.tgz
fi

mkdir -p "$OUT/dumper"
cd "$OUT"
[ -f go.mod ] || go mod init behav
go get "github.com/dotabuff/manta@${MANTA_VER}"

MSRC="$GOPATH/pkg/mod/github.com/dotabuff/manta@${MANTA_VER}"
DST="$OUT/manta_local"
rm -rf "$DST"; mkdir -p "$DST"; cp -r "$MSRC"/. "$DST"/; chmod -R u+w "$DST"
python3 - "$DST/class.go" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '''\tmatches := gameBuildRegexp.FindStringSubmatch(m.GetGameDir())
\tif len(matches) < 2 {
\t\treturn fmt.Errorf("unable to determine game build from '%s'", m.GetGameDir())
\t}'''
new = '''\tmatches := gameBuildRegexp.FindStringSubmatch(m.GetGameDir())
\tif len(matches) < 2 {
\t\t// Dedicated-server replays have no /dota_vNNNN/ build tag; default high
\t\t// so no legacy (<=1027) field patch wrongly applies. See README.md.
\t\tp.GameBuild = 9999
\t\treturn nil
\t}'''
assert old in s, "manta class.go build-detection block not found (manta version drift?)"
s = s.replace(old, new).replace('\t"fmt"\n', '', 1)
open(p, "w").write(s)
print("[get_dumper] patched manta class.go")
PY
go mod edit -replace "github.com/dotabuff/manta=./manta_local"

cp "$DUMPER_SRC" "$OUT/dumper/main.go"
go build -o "$STAGE" ./dumper

if [ ! -s "$STAGE" ]; then
    echo "[get_dumper] ERROR: build did not produce a binary" >&2
    exit 1
fi
chmod +x "$STAGE"
mv -f "$STAGE" "$BIN"              # atomic install, same reason as the cache path
echo "[get_dumper] built $BIN" >&2

if [ -n "$AWS_CMD" ]; then
    if $AWS_CMD s3 cp "$BIN" "$S3_URI" --quiet; then
        echo "[get_dumper] cached fresh build at $S3_URI for next session" >&2
    else
        echo "[get_dumper] WARN: cache upload failed (non-fatal, binary still usable)" >&2
    fi
fi

echo "$BIN"
