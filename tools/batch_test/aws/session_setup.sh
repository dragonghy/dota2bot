#!/usr/bin/env bash
# Session setup entrypoint for the cloud environment's setup-script hook.
#
# Point the environment's setup script at this file by ABSOLUTE path:
#     bash /home/user/dota2bot/tools/batch_test/aws/session_setup.sh
#
# Design goals:
#   - NEVER fail the session. AWS is only needed for batch testing; most work
#     (hero logic, tests, docs) doesn't need it. This script always exits 0.
#   - Self-locating: does not depend on the caller's working directory.
#   - No-op when AWS creds aren't configured in the environment.

# Resolve repo root without relying on cwd (fall back to the standard path).
REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../.." 2>/dev/null && pwd)"
[ -d "$REPO/tools/batch_test/aws" ] || REPO=/home/user/dota2bot

BOOTSTRAP="$REPO/tools/batch_test/aws/bootstrap_creds.sh"

if [ -z "${DOTA2BOT_AWS_KEY_ID:-}" ] || [ -z "${DOTA2BOT_AWS_SECRET:-}" ]; then
    echo "[session_setup] AWS creds not set (DOTA2BOT_AWS_KEY_ID/SECRET) — skipping AWS bootstrap."
    echo "[session_setup] This is fine unless you need to run batch tests."
    exit 0
fi

if [ ! -f "$BOOTSTRAP" ]; then
    echo "[session_setup] bootstrap_creds.sh not found at $BOOTSTRAP — skipping."
    exit 0
fi

if bash "$BOOTSTRAP"; then
    echo "[session_setup] AWS bootstrap complete."
else
    echo "[session_setup] AWS bootstrap failed (non-fatal); run it manually if you need AWS."
fi
exit 0
