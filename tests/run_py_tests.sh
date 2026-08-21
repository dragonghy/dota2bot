#!/usr/bin/env bash
# Runs every plain-python test under tests/ (the Lua runner, tests/run_tests.lua,
# cannot see them -- it loads .lua files only).
#
# Why this exists: as of 2026-08-21 there were four `tests/*.py` files and NO
# runner for any of them, so nothing failed when one rotted.  A test nobody runs
# is the same shape as the dead S3 lifecycle rule rejected in test_set.md Z.4 --
# a rule that is on the books and matches nothing.  Each file is standalone and
# exits non-zero on failure, so the runner is just the loop.
#
# Usage:  bash tests/run_py_tests.sh
set -u
cd "$(dirname "$0")/.."

pass=0
fail=0
failed=""
for f in tests/test_*.py; do
    [ -e "$f" ] || continue
    if out=$(python3 "$f" 2>&1); then
        pass=$((pass + 1))
        printf 'PASS  %s\n' "$f"
    else
        fail=$((fail + 1))
        failed="$failed $f"
        printf 'FAIL  %s\n' "$f"
        printf '%s\n' "$out" | sed 's/^/      /'
    fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -ne 0 ]; then
    printf 'failed:%s\n' "$failed"
    exit 1
fi
