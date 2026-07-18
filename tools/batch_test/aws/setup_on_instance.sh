#!/usr/bin/env bash
# Run ON the bake instance (Ubuntu 24.04). Installs steamcmd + deps and clones
# the repo. After this, log into steamcmd once (see aws/README.md) so the
# credential cache is baked into the AMI.
set -euo pipefail

sudo dpkg --add-architecture i386
sudo apt-get update
# steamcmd needs a license accept; preseed it
echo steam steam/question select "I AGREE" | sudo debconf-set-selections
echo steam steam/license note '' | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    steamcmd lib32gcc-s1 python3 git awscli lua5.1 lua-check

sudo mkdir -p /opt/dota2 && sudo chown ubuntu:ubuntu /opt/dota2
git clone https://github.com/dragonghy/dota2bot.git /opt/dota2bot

# game expects the bot scripts here:
mkdir -p /opt/dota2/game/dota/scripts/vscripts

echo ""
echo "now log into steam ONCE to bake credentials (use the dedicated account):"
echo "  steamcmd +force_install_dir /opt/dota2 +login <ACCOUNT> +app_update 570 validate +quit"
echo "then record the account name for unattended updates:"
echo "  echo <ACCOUNT> | sudo tee /opt/steam_user"
