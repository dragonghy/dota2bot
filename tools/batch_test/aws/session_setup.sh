#!/usr/bin/env bash
# Session setup entrypoint for the cloud environment's setup-script hook.
#
# Point the environment's setup script at this file by ABSOLUTE path:
#     bash /home/user/dota2bot/tools/batch_test/aws/session_setup.sh
#
# What it does, in order:
#   1. No-op (exit 0) if the AWS creds env vars aren't set — most work
#      (hero logic, tests, docs) doesn't need AWS.
#   2. Ensure the AWS CLI is installed. Fresh containers clone the repo but do
#      NOT ship `aws`, so without this the bootstrap's verify step fails and
#      every later `awsx` call has nothing to exec.
#   3. Bootstrap ~/.aws/credentials + the awsx wrapper and verify identity.
#
# Design guarantees:
#   - NEVER fails the session: always exits 0.
#   - Self-locating: does not depend on the caller's working directory.

# Resolve repo root without relying on cwd (fall back to the standard path).
REPO="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../.." 2>/dev/null && pwd)"
[ -d "$REPO/tools/batch_test/aws" ] || REPO=/home/user/dota2bot
AWS_DIR="$REPO/tools/batch_test/aws"

log() { echo "[session_setup] $*"; }

# 1. Skip entirely when creds aren't configured in the environment.
if [ -z "${DOTA2BOT_AWS_KEY_ID:-}" ] || [ -z "${DOTA2BOT_AWS_SECRET:-}" ]; then
    log "AWS creds not set (DOTA2BOT_AWS_KEY_ID/SECRET) — skipping AWS setup."
    log "This is fine unless you need to run batch tests."
    exit 0
fi

# 2. Make sure the AWS CLI exists (bootstrap's verify step + awsx need it).
if [ -f "$AWS_DIR/ensure_aws_cli.sh" ]; then
    bash "$AWS_DIR/ensure_aws_cli.sh" \
        || log "AWS CLI install failed (non-fatal); bootstrap verify may not run."
else
    log "ensure_aws_cli.sh not found at $AWS_DIR — assuming aws is preinstalled."
fi

# 3. Bootstrap credentials + awsx wrapper and verify identity.
if [ -f "$AWS_DIR/bootstrap_creds.sh" ]; then
    if bash "$AWS_DIR/bootstrap_creds.sh"; then
        log "AWS bootstrap complete."
    else
        log "AWS bootstrap failed (non-fatal); run it manually if you need AWS."
    fi
else
    log "bootstrap_creds.sh not found at $AWS_DIR — skipping."
fi

exit 0
