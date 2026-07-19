#!/usr/bin/env bash
# Deploy a mirror (candidate-vs-reference) build to this farm instance.
#   ab_deploy.sh <OLD_REF> <NEW_REF> [swap]
# OLD = reference/baseline side, NEW = candidate side.
# Default sides: Radiant=NEW, Dire=OLD; pass "swap" to flip.
# Restore normal (single-version) mode with plain_deploy.sh.
set -euo pipefail
OLD=${1:?old (reference) git ref}
NEW=${2:?new (candidate) git ref}
SWAP=${3:-}
REPO=/opt/dota2bot
OUT=/opt/ab_build
VS=/opt/dota2/game/dota/scripts/vscripts

cd "$REPO"
SWAPFLAG=""
[ "$SWAP" = "swap" ] && SWAPFLAG="--swap"
sudo -u ubuntu python3 tools/batch_test/make_ab_build.py \
    --old "$OLD" --new "$NEW" $SWAPFLAG --out "$OUT"

# the farm-only draft pool is gitignored, so the git-archive trees lack it;
# it is identical for both sides — install it as a real file everywhere.
for d in "$OUT/bots" "$OUT/bots_ab_new" "$OUT/bots_ab_old"; do
    mkdir -p "$d/Customize"
    cp "$REPO/bots/Customize/soak_pool.lua" "$d/Customize/soak_pool.lua"
done

ln -sfn "$OUT/bots" "$VS/bots"
ln -sfn "$OUT/bots_ab_new" "$VS/bots_ab_new"
ln -sfn "$OUT/bots_ab_old" "$VS/bots_ab_old"

# soak_loop stamps this instead of git describe while an AB build is live
SIDES="R=NEW,D=OLD"
[ "$SWAP" = "swap" ] && SIDES="R=OLD,D=NEW"
echo "ab:${OLD}..${NEW}:${SIDES}" > /opt/soak/ab_version
chown ubuntu:ubuntu /opt/soak/ab_version 2>/dev/null || true
echo "AB build live: $(cat /opt/soak/ab_version)"
