#!/usr/bin/env bash
# Mutation stand for tests/test_fixture_kv_getters.lua -- the fixture loader's
# KV getters (hero, 2026-09-04).  Run by hand when the loader's value_ladder /
# rank_step / getter installation changes, and before quoting any number that
# file records.
#
# DISCIPLINE (house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS FOR.  The subject is an INSTRUMENT, so the ordinary failure
# mode is not "a wrong action" but "a plausible number".  Each mutant below
# leaves the loader working and every other test green; only a file that pins
# what the ladder means can tell them apart.  M4 and M6 are the two that a test
# written as "the getter answers something non-zero" would survive.
#
# Usage: bash tools/agent/mutstand_kvgetters.sh
set -u
cd "$(dirname "$0")/../.."

TEST=tests/test_fixture_kv_getters.lua
LOADER=tests/mock/replay_fixture.lua

FILES=("$TEST" "$LOADER")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_kv.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_fixture_kv_getters > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex), and abort if the anchor is gone -- a mutant
# that silently applied to nothing scores "caught" for the wrong reason.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
if old not in s:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the getters go back to the generic `^Get` default.  The defect itself.
echo
echo "=== M1: GetSpecialValue* is never installed (the shipped-before state) ==="
sub "$LOADER" '                    sp.GetSpecialValueFloat = function(self, sKey)' \
              '                    sp.GetSpecialValueFloatDISABLED = function(self, sKey)'
score "M1" "served damage should be the KV step for the handle rank"

# ---------------------------------------------------------------------------
# M2: only the cast range goes back.  Narrower than M1 and the one that decides
#     whether the 375u ring reading is held up by anything.
echo
echo "=== M2: GetCastRange is never installed ==="
sub "$LOADER" '                        sp.GetCastRange = function(self)' \
              '                        sp.GetCastRangeDISABLED = function(self)'
score "M2" "Culling Blade cast range, got"

# ---------------------------------------------------------------------------
# M3: the ladder stops being rank-indexed and always pays step 1.  Every read on
#     a rank-1 handle -- which is most of this corpus -- is UNCHANGED, so a test
#     that only checked "non-zero on the pinned frame" survives this.
echo
echo "=== M3: rank_step ignores the rank and always pays step 1 ==="
sub "$LOADER" '    if nRank == nil or nRank < 1 then return steps[1] end
    return steps[math.min(nRank, #steps)]' \
              '    return steps[1]'
score "M3" "rank 2 should read"

# ---------------------------------------------------------------------------
# M4: the clamp becomes an index, so a rank past the ladder reads nil.  In game
#     that is every talent row and every 3-step ultimate ladder at rank 4+.
echo
echo "=== M4: a rank past the ladder's end reads nil instead of the last step ==="
sub "$LOADER" '    return steps[math.min(nRank, #steps)]' \
              '    return steps[nRank]'
score "M4" "a rank past the ladder pays its last step"

# ---------------------------------------------------------------------------
# M5: the conditional bonus is folded in -- the plausible "improvement" that
#     would double-count a talent the engine has already folded, and would make
#     every fold-dependent reading in this repo silently optimistic.
echo
echo "=== M5: the special_bonus_* row is folded into the served base ==="
sub "$LOADER" '    local kv = entry[sKey]
    if kv == nil or kv.base == nil then return nil end' \
              '    local kv = entry[sKey]
    if kv == nil or kv.base == nil then return nil end
    if kv.bonus ~= nil and kv.bonus["special_bonus_unique_axe_5"] ~= nil then
        return { 425, 525, 625 }
    end'
score "M5" "the served read is the BASE step"

# ---------------------------------------------------------------------------
# M6: a NO-BASE key stops answering 0 and answers its bonus instead.  This is
#     the mutant that would "repair" GH #162 inside the instrument -- i.e. make
#     the fixture world disagree with the engine in exactly the dimension the
#     `lionsplash` candidate exists to measure.
echo
echo "=== M6: a NO-BASE key answers a number instead of 0 ==="
sub "$LOADER" '                        local steps = value_ladder(u.name, a.name, sKey)
                        if steps == nil then return 0 end' \
              '                        local steps = value_ladder(u.name, a.name, sKey)
                        if steps == nil then return 325 end'
score "M6" "the engine answers 0 for a key with no base value"

# ---------------------------------------------------------------------------
# M7: the focus-five guard is dropped and every hero is served.  The snapshot
#     has no block for them, so the reads still answer 0 -- section 2c CANNOT SEE
#     this mutant, and that is a measurement, not a gap left open: the guard is
#     not load-bearing for the answer, only for the cost and the intent.  It is
#     caught by the SOURCE tripwire in section 6a instead, which is the only
#     honest place to catch something that changes no reading.
echo
echo "=== M7 (control): the has_kv guard is dropped ==="
sub "$LOADER" '                if has_kv(u.name) then' \
              '                if true then'
score "M7" "the loader dropped its focus-five guard"

# ---------------------------------------------------------------------------
# M8 (positive control): a comment-only edit must leave the file green.  A stand
#     where everything reds is a stand that proves nothing.
echo
echo "=== M8 (positive control): comment-only edit ==="
sub "$LOADER" '--- Which per-level step a rank reads.' \
              '--- (control edit) Which per-level step a rank reads.'
TOTAL=$((TOTAL + 1))
run_tests; RC=$?
if [ "$RC" -eq 0 ]; then
    echo "M8  correctly SURVIVED (exit 0) -- the file is not red at everything"
    CAUGHT=$((CAUGHT + 1))
else
    echo "M8  RED (exit $RC) on a comment -- the file is over-anchored"
fi
restore > /dev/null

echo
echo "=== $CAUGHT / $TOTAL ==="
