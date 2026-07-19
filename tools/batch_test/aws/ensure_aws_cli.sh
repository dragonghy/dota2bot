#!/usr/bin/env bash
# Ensure the AWS CLI (`aws`) is available in this ephemeral container.
#
# Fresh session containers clone the repo but do NOT ship the AWS CLI, so the
# bootstrap's `sts get-caller-identity` verification (and every later `awsx`
# call) has nothing to exec. This installs it.
#
# Idempotent: no-op if `aws` is already on PATH.
# Exits 0 if `aws` is available afterwards; non-zero if every method failed.

if command -v aws >/dev/null 2>&1; then
    echo "[ensure_aws_cli] AWS CLI already present: $(aws --version 2>&1)"
    exit 0
fi

echo "[ensure_aws_cli] AWS CLI not found — installing (outbound via the agent proxy)..."

# Method 1: pip. Fast and proxy-friendly. awscli v1 covers everything batch
# testing uses (sts, ec2, s3, ssm, budgets). Running as root installs the
# `aws` entry point into /usr/local/bin, which is on PATH.
for PIP in "pip3" "python3 -m pip"; do
    if $PIP --version >/dev/null 2>&1; then
        if $PIP install --quiet --disable-pip-version-check awscli >/dev/null 2>&1; then
            if command -v aws >/dev/null 2>&1; then
                echo "[ensure_aws_cli] installed via '$PIP': $(aws --version 2>&1)"
                exit 0
            fi
        fi
    fi
done

# Method 2: official v2 bundled installer, as a fallback.
if command -v curl >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
    TMP="$(mktemp -d)"
    if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" \
            -o "$TMP/awscliv2.zip" \
        && unzip -q "$TMP/awscliv2.zip" -d "$TMP"; then
        "$TMP/aws/install" --update >/dev/null 2>&1 \
            || "$TMP/aws/install" >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP"
    if command -v aws >/dev/null 2>&1; then
        echo "[ensure_aws_cli] installed via official installer: $(aws --version 2>&1)"
        exit 0
    fi
fi

echo "[ensure_aws_cli] ERROR: could not install the AWS CLI by any method." >&2
exit 1
