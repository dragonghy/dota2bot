#!/usr/bin/env bash
# Idempotent one-time setup of the behavioral replay-parsing toolchain on the
# soak instance (Ubuntu 24.04). Installs Go, fetches + patches manta, and builds
# the behav-dump binary. Safe to re-run. Does NOT touch the running soak farm.
#
# Run over SSM as root, e.g.:
#   awsx ssm send-command --instance-ids i-08b59ef7130025860 \
#     --document-name AWS-RunShellScript \
#     --parameters commands='bash /opt/dota2bot/tools/batch_test/behavioral/setup_instance.sh'
#
# Or point BEHAV_DUMPER_SRC at a main.go shuttled via S3 if the repo isn't on
# the instance yet.
set -euo pipefail

GO_VER=1.22.5
MANTA_VER=v1.5.0
WORK=/opt/behav
REPO=${BEHAV_REPO:-/opt/dota2bot/tools/batch_test/behavioral}
DUMPER_SRC=${BEHAV_DUMPER_SRC:-$REPO/dumper/main.go}

export PATH=$PATH:/usr/local/go/bin
export GOPATH=/opt/gopath GOCACHE=/opt/gocache

# 1. Go toolchain
if ! /usr/local/go/bin/go version >/dev/null 2>&1; then
    echo "[setup] installing Go $GO_VER"
    curl -sSL -m 180 -o /tmp/go.tgz "https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz"
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tgz
fi
go version

# 2. module + manta dependency
mkdir -p "$WORK/dumper"
cd "$WORK"
[ -f go.mod ] || go mod init behav
go get "github.com/dotabuff/manta@${MANTA_VER}"

# 3. vendor manta and patch the game-build detection.
#    Dedicated-server replays report a bare game dir ('.../game/dota') with no
#    /dota_vNNNN/ build tag, so manta's onCSVCMsg_ServerInfo errors out. We
#    default GameBuild to 9999 (above every legacy field-patch upper bound in
#    field_patch.go, so none of the <=1027 coord/angle/mana patches wrongly
#    apply to a modern replay). This is the ONLY change to manta.
MSRC="$GOPATH/pkg/mod/github.com/dotabuff/manta@${MANTA_VER}"
DST="$WORK/manta_local"
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
print("[setup] patched manta class.go")
PY
# Swap manta's source for our patched copy. The initial `go get` already wrote
# the require line + go.sum entries for manta and its deps (snappy/protobuf/
# go-spew); do NOT `go mod tidy` here — it prunes the now-locally-replaced
# require and breaks the build.
go mod edit -replace "github.com/dotabuff/manta=./manta_local"

# 4. build the dumper
cp "$DUMPER_SRC" "$WORK/dumper/main.go"
go build -o "$WORK/behav-dump" ./dumper
echo "[setup] built $WORK/behav-dump"
"$WORK/behav-dump" 2>&1 | head -1 || true
echo "[setup] OK"
