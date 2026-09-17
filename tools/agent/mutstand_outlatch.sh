#!/usr/bin/env bash
# Mutation stand for tests/test_outlatch_latch_real_frame.lua -- the real-frame
# half of `outlatch`'s condition (a) (replay-check, W89, 2026-09-17; owed row
# iterations/owed_executions.json:outlatch_condition_a_fixture).
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusmana.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418) -- an
#     interrupted run must not leave a mutant in bots/;
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent or NOT UNIQUE aborts instead of scoring
#     caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS FOR. The test's claim has three moving parts and a mutant
# per part, each expected to be caught by the section that owns it:
#   M1  revert the fix (unconditional latch)    -> [frame F4] + [source]
#   M2  gate always on (shipped re-scans too)   -> [frame F3] + both [gate]
#   M3  OUTPOST_RESCAN_INTERVAL 1.0 -> 100.0    -> [frame F4]'s spacing
#
# Usage: bash tools/agent/mutstand_outlatch.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_outpost_generic.lua
TEST=outlatch_latch_real_frame

FILES=("$SRC")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_outlatch.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

run_tests() {
    lua5.1 tests/run_tests.lua "$TEST" > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex); abort if the anchor is absent OR not unique.
# A mutant that silently applied to nothing scores "caught" for a reason the
# score line cannot show.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import io, os, sys
p = os.environ['F']
s = io.open(p, encoding='utf-8').read()
old, new = os.environ['OLD'], os.environ['NEW']
n = s.count(old)
if n != 1:
    sys.stderr.write('anchor appears %d times, expected 1\n' % n)
    sys.exit(1)
io.open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
    return $?
}

# --- baseline: the unmutated tree must be green, or every CAUGHT below is
# --- ambiguous.
run_tests
base_rc=$?
if [ "$base_rc" -ne 0 ]; then
    echo "BASELINE RED (exit $base_rc) -- no mutant is scored; fix the tree first."
    grep '^FAIL\[' "$WORK/run.log" | sed 's/^/      /'
    exit 2
fi
printf 'baseline: GREEN -- %s\n\n' \
    "$(grep -o '[0-9]* tests, [0-9]* failures' "$WORK/run.log" | tail -1)"

caught=0
survived=0

mutate () {
    local name="$1" old="$2" new="$3"
    restore
    sub "$SRC" "$old" "$new"
    local anchor_rc=$?
    if [ "$anchor_rc" -ne 0 ]; then
        restore
        printf '%s: ABORTED -- the anchor did not apply uniquely. This is NOT a result.\n' "$name"
        exit 2
    fi

    run_tests
    local rc=$?
    restore

    if [ "$rc" -ne 0 ]; then
        caught=$((caught + 1))
        printf '%s: CAUGHT (exit %d)\n' "$name" "$rc"
    else
        survived=$((survived + 1))
        printf '%s: *** SURVIVED *** (exit 0)\n' "$name"
    fi
    grep '^FAIL\[' "$WORK/run.log" | sed 's/^/      /'
}

mutate M1 \
    'DidWeGetOutpost = not bRescan or #Outposts > 0' \
    'DidWeGetOutpost = true'

mutate M2 \
    'local bRescan = J.IsModeTurbo() and J.IsSoakCandidate' \
    'local bRescan = true or J.IsModeTurbo() and J.IsSoakCandidate'

mutate M3 \
    'local OUTPOST_RESCAN_INTERVAL = 1.0' \
    'local OUTPOST_RESCAN_INTERVAL = 100.0'

printf '\n%d caught / %d survived\n' "$caught" "$survived"

# The trap stays armed to the end: `restore` is idempotent and verifies itself,
# so the last word on the tree comes from it either way.
restore
printf 'restore verified (sha256sum -c) -- the tree holds no mutant\n'

if [ "$survived" -eq 0 ]; then exit 0; fi
exit 1
