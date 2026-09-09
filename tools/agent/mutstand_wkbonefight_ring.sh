#!/usr/bin/env bash
# Mutation stand for the 2026-09-09 NARROWING of `wkbonefight` -- the Bone Guard
# enemy-count leg, re-priced from the 1600 view ring onto the branch's own 650
# engagement ring (hero, OWNER_PRIORITIES P4.4(i); spends the hero-31 domain read
# in iterations/reports/replay-check/domain_scan_hero_2_30_31.md section 6).
#
# Run by hand when tests/test_wk_bone_guard_enemy_count.lua,
# hero_skeleton_king.lua's X.ConsiderW / X.IsBoneGuardEnemyCountOk /
# X.wk_CountBoneGuardEngaged, or any WK-subject fixture is edited -- and before
# quoting any of that file's readings.
#
# WHY THIS STAND EXISTS AT ALL.  The previous Axe round (2026-09-09T17:10Z) shipped
# a correct narrowing whose own mutation stand went QUIET: three mutants had been
# anchored on a frame where, AFTER the narrowing, both legs stood down, so they
# turned SURVIVED because the fix was right.  A finish that only checks "still
# 11/11 green" cannot see that.  So every mutant below is anchored on a reading
# that the narrowing MOVED (9 -> 6 admitted frames, 3 dropped by name), never on
# one it left alone.
#
# WHAT NEEDS GUARDING, and the mutants that guard it:
#   * the engaged-ring premise is IN the `if`, not just in the header  -> M1, M5
#   * the ring is 650 (the branch's own), not 1600                     -> M6, M8
#   * the call site hands over its OWN table                           -> M3, M10
#   * a missing table fails CLOSED, not open                           -> M4
#   * DIRECTION BY CONSTRUCTION survives the narrowing                 -> M7
#   * the gate is still turbo-only and still standalone                -> M2, M9
#
# THE THREE WORTH READING:
#   * M1 IS THE ROUND'S ANSWER.  It restores `nEnemies >= 1`, i.e. the leg as it
#     read before this change.  If that survives, the narrowing is undocumented
#     by the tests and the next reader will "simplify" it straight back out.
#   * M4 IS THE FAIL-OPEN TRIPWIRE.  A caller that forgets the table must land on
#     the shipped duel test.  Flip that default to permissive and the old 1600
#     leg silently returns for every such caller, with no counter reporting it --
#     a Bone Guard that WAS cast leaves no more trace than one that was not.
#   * M7 IS THE ATTRIBUTION GUARD.  Drop the `nEnemies == 1` disjunct and armed
#     stops being a superset of shipped, so a negative wave read can no longer be
#     attributed to "more releases were bad" -- the lever could now be REMOVING
#     releases, which no wave counter can see.
#
# DISCIPLINE (inherited from tools/agent/mutstand_lionearlyreturn.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never score
#     "caught" for having applied to nothing (GH #550);
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# Usage: bash tools/agent/mutstand_wkbonefight_ring.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_bone_guard_enemy_count.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkbonefight_ring.XXXXXX")
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

# The filter is `wk_`, not this one file: the sibling WK tests read the same
# source region and the same frames, and a stand scoped to the new file alone
# would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua wk_ > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort on an absent OR ambiguous anchor.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
if n != 1:
    sys.stderr.write("ANCHOR AMBIGUOUS (%d hits) in %s: %r\n" % (n, f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# ⚠️ TAB-PREFIXED ON PURPOSE where the source is tab-indented.  The bare strings
# also occur inside the header comment block above X.IsBoneGuardEnemyCountOk,
# where sub() would (correctly) abort on them as AMBIGUOUS.
ARMED_LEG=$'\t\treturn nEnemies == 1\n\t\t\tor X.wk_CountBoneGuardEngaged( tEnemies, nRadius or 650 ) >= 2'
GATE_LINE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'wkbonefight\' )'
NIL_GUARD=$'\tif tEnemies == nil then return 0 end'
RANGE_TEST=$'\t\t\tand J.IsInRange( bot, npcEnemy, nRadius )'
ENGAGE_LOCAL=$'\tlocal nEngageRange = 650'
CALLSITE=$'\t\tand X.IsBoneGuardEnemyCountOk( #nEnemysHerosInView, nEnemysHerosInView, nEngageRange )'

pass=0; fail=0
score() { # score <name> <exit> <what it protects>
    if [ "$2" -ne 0 ]; then
        echo "  CAUGHT    $1 -- $3"
        pass=$((pass + 1))
    else
        echo "  SURVIVED  $1 -- $3"
        fail=$((fail + 1))
    fi
}

mutate() { # mutate <name> <file> <old> <new> <what it protects>
    restore
    if ! sub "$2" "$3" "$4"; then
        echo "  ABORTED   $1 -- anchor absent or ambiguous (NOT a pass)"
        fail=$((fail + 1))
        return
    fi
    run_tests; local rc=$?
    score "$1" "$rc" "$5"
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- every mutant below would score CAUGHT for"
    echo "the wrong reason.  Fix the tree first.  Log: $WORK/run.log"
    tail -20 "$WORK/run.log"
    exit 2
fi
echo "  baseline GREEN"
echo

echo "=== mutants ==="

# M1 -- the round's answer: the leg as it read BEFORE 2026-09-09.
mutate M1 "$HERO" "$ARMED_LEG" $'\t\treturn nEnemies >= 1' \
    "the pre-narrowing 1600-ring leg (9 of 13 frames, 3 of them out of reach)"

# M2 -- gate hygiene: turbo-only.
mutate M2 "$HERO" "$GATE_LINE" $'\tif J.IsSoakCandidate( \'wkbonefight\' )' \
    "the gate is turbo-only"

# M3 -- dead-wire the call site: count only, so the leg lands on the fallback.
mutate M3 "$HERO" "$CALLSITE" \
    $'\t\tand X.IsBoneGuardEnemyCountOk( #nEnemysHerosInView )' \
    "the call site hands over the table it walked"

# M4 -- fail OPEN on a missing table instead of closed.
mutate M4 "$HERO" "$NIL_GUARD" $'\tif tEnemies == nil then return 99 end' \
    "a missing table falls back to the shipped duel, not to a release"

# M5 -- threshold 2 -> 1: 'joins a 3v3' becomes 'someone is nearby'.
mutate M5 "$HERO" "$ARMED_LEG" \
    $'\t\treturn nEnemies == 1\n\t\t\tor X.wk_CountBoneGuardEngaged( tEnemies, nRadius or 650 ) >= 1' \
    "the engaged threshold is 2 (the premise is a FIGHT, not a presence)"

# M6 -- the ring drifts back to 1600 at the call site.
mutate M6 "$HERO" "$ENGAGE_LOCAL" $'\tlocal nEngageRange = 1600' \
    "the engagement ring is 650, the branch's own reach"

# M7 -- drop the shipped disjunct: armed stops being a superset.
mutate M7 "$HERO" "$ARMED_LEG" \
    $'\t\treturn X.wk_CountBoneGuardEngaged( tEnemies, nRadius or 650 ) >= 2' \
    "DIRECTION BY CONSTRUCTION: armed may only ADD releases"

# M8 -- the counter ignores the radius it was handed.
mutate M8 "$HERO" "$RANGE_TEST" $'\t\t\tand J.IsValid( npcEnemy )' \
    "the counter actually applies the ring (not a re-count of the table)"

# M9 -- the gate reads a name that is armed for something else.
mutate M9 "$HERO" "$GATE_LINE" \
    $'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'wkbuild\' )' \
    "the gate names exactly this id"

# M10 -- the call site hands over a DIFFERENT table than the one it counted.
mutate M10 "$HERO" "$CALLSITE" \
    $'\t\tand X.IsBoneGuardEnemyCountOk( #nEnemysHerosInView, {}, nEngageRange )' \
    "the table passed is the one the count was taken from"

restore
echo
echo "=== result ==="
echo "  $pass CAUGHT / $((pass + fail)) fired"
[ "$fail" -eq 0 ] || echo "  ⚠️  $fail SURVIVED or ABORTED -- read each one before quoting this file"
[ "$fail" -eq 0 ]
