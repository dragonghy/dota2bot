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

# [director 20260827, GH #243] Exit code 2 from a test means IT DID NOT RUN --
# it could not read its input -- as distinct from 1, which means it ran and the
# answer was wrong.  Before this, both printed `FAIL <file>` and 开工自检
# escalated either one to `TRUNK RED -- a python test is failing ON THE WORKING
# TREE`.  A census whose corpus file vanished mid-scan therefore told a whole
# round that trunk was red.  Same 0/2/3 vocabulary as rule 10 (GH #171) and the
# push gate (GH #213): could-not-run is its own answer, and it is not a pass
# either -- this runner still exits non-zero on it.
pass=0
fail=0
unrun=0
failed=""
uncertifiable=""
for f in tests/test_*.py; do
    [ -e "$f" ] || continue
    out=$(python3 "$f" 2>&1); rc=$?
    if [ "$rc" -eq 0 ]; then
        pass=$((pass + 1))
        printf 'PASS  %s\n' "$f"
    elif [ "$rc" -eq 2 ]; then
        unrun=$((unrun + 1))
        uncertifiable="$uncertifiable $f"
        printf 'UNCERTIFIABLE  %s  (did NOT run -- this is not a pass and not a failure)\n' "$f"
        printf '%s\n' "$out" | sed 's/^/      /'
    else
        fail=$((fail + 1))
        failed="$failed $f"
        printf 'FAIL  %s\n' "$f"
        printf '%s\n' "$out" | sed 's/^/      /'
    fi
done

printf '\n%d passed, %d failed, %d uncertifiable\n' "$pass" "$fail" "$unrun"
if [ "$fail" -ne 0 ]; then
    printf 'failed:%s\n' "$failed"
    exit 1
fi
if [ "$unrun" -ne 0 ]; then
    printf 'uncertifiable:%s\n' "$uncertifiable"
    exit 2
fi
