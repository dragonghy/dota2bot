#!/usr/bin/env bash
# Restore the normal single-version bot deployment (repo checkout) after a
# mirror run (ab_deploy.sh).
set -euo pipefail
VS=/opt/dota2/game/dota/scripts/vscripts
ln -sfn /opt/dota2bot/bots "$VS/bots"
rm -f "$VS/bots_ab_new" "$VS/bots_ab_old" /opt/soak/ab_version
echo "plain deployment restored: $VS/bots -> /opt/dota2bot/bots"
