#!/usr/bin/env bash
# Bootstrap AWS credentials for a fresh session/container.
#
# Each Claude Code session runs in a new ephemeral container that clones the
# repo fresh — it does NOT carry over ~/.aws/credentials. This script rebuilds
# the working AWS setup from environment variables that the owner stores in the
# cloud environment config (so secrets live there, never in the repo).
#
# Required env vars (set these in the cloud environment settings):
#   DOTA2BOT_AWS_KEY_ID       = the dota2bot-agent IAM user's access key id
#   DOTA2BOT_AWS_SECRET       = its secret access key
# (Custom names are used on purpose: the standard AWS_* names are occupied by
#  proxy placeholders in this environment and can't be relied on.)
#
# Run once at the start of any session that needs AWS:
#   source tools/batch_test/aws/bootstrap_creds.sh   (or just run it)
set -euo pipefail

KEY_ID="${DOTA2BOT_AWS_KEY_ID:-}"
SECRET="${DOTA2BOT_AWS_SECRET:-}"

if [ -z "$KEY_ID" ] || [ -z "$SECRET" ]; then
    echo "ERROR: DOTA2BOT_AWS_KEY_ID / DOTA2BOT_AWS_SECRET not set in the environment." >&2
    echo "The owner must add the dota2bot-agent IAM key to the cloud environment config." >&2
    exit 1
fi

mkdir -p ~/.aws
cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = $KEY_ID
aws_secret_access_key = $SECRET
EOF
chmod 600 ~/.aws/credentials
cat > ~/.aws/config <<'EOF'
[default]
region = us-west-2
output = json
EOF

# awsx wrapper: strip the proxy's placeholder AWS_* env vars (which shadow the
# credentials file) and point the CLI at the proxy CA bundle.
cat > /usr/local/bin/awsx <<'WRAP'
#!/bin/bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_CA_BUNDLE=/root/.ccr/ca-bundle.crt
exec aws "$@"
WRAP
chmod +x /usr/local/bin/awsx

# Make sure the AWS CLI is installed before verifying (fresh containers lack it,
# so a manual `bootstrap_creds.sh` run self-heals just like session_setup does).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
[ -f "$HERE/ensure_aws_cli.sh" ] && bash "$HERE/ensure_aws_cli.sh" || true

# verify
ARN=$(awsx sts get-caller-identity --query Arn --output text 2>&1) || {
    echo "credentials written but verification failed: $ARN" >&2
    exit 1
}
echo "AWS ready: $ARN"
case "$ARN" in
    *dota2bot-agent) echo "(restricted batch-runner user — correct)";;
    *root) echo "WARNING: these are ROOT credentials, not the restricted user. Rotate to dota2bot-agent." >&2;;
esac
