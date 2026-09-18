#!/usr/bin/env bash
# Mutation stand for tests/test_wk_q_flee_reach.lua -- the ratchet behind the
# gated soak candidate `wkqflee` (hero, 2026-09-18).
#
# ⭐ WHY THIS STAND HAS NO SECTION C.  Its sibling
# tools/agent/mutstand_wkqfightseed.sh needed a control section because its
# verdict was a NEGATIVE ("arming moves nothing"), and a driver that cannot see
# any difference reports exactly that too.  This lever's claim is POSITIVE and
# the positive control is inside the test: §3.3 drives the SAME frame through
# the SAME shipped X.ConsiderQ twice and the legs differ (HIGH/lion vs 0/nil).
# A driver blind to the lever would fail that assertion, not pass it.
#
# DISCIPLINE (inherited from the sibling stands):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first edit (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507, GH #848) -- and the charter's `-205` spent a round
# reading four such phantom reds as its own.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_q_flee_reach.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkqflee.XXXXXX")
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

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous.
# ⭐ The ambiguity guard is load bearing HERE specifically: X.ConsiderQ holds ten
# `return BOT_ACTION_DESIRE_HIGH` lines and hero_skeleton_king.lua holds two
# `J.IsSoakCandidate( '...' )` reach helpers whose bodies differ by one token --
# GH #873 §五.1 is the round that lost a work unit to exactly that collision.
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

run_tests() {
    lua5.1 tests/run_tests.lua wk_q_flee > "$WORK/run.log" 2>&1
    return $?
}

score() {
    NAME="$1"
    run_tests; RC=$?
    restore
    if [ "$RC" -ne 0 ]; then
        echo "  CAUGHT    $NAME"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "  SURVIVED  $NAME"
        echo "            (a SURVIVED mutant is a fact about the TREE, not a typo:"
        echo "             no assertion in $TEST prices this edit)"
        SURVIVED=$((SURVIVED + 1))
    fi
    TOTAL=$((TOTAL + 1))
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

CAUGHT=0; SURVIVED=0; TOTAL=0

echo "=== mutants ==="

# M1 -- the armed predicate becomes the COMMIT allowance (+80).  §0 of the test
# argues at length that +80 is the one number a retreat is not spending; if
# nothing goes red, that argument is prose.
sub "$HERO" "	return J.IsInRange( npcEnemy, bot, nCastRange )

end" "	return J.IsInRange( npcEnemy, bot, nCastRange + 80 )

end" || exit 3
score "M1 armed predicate widened to the +80 commit gate"

# M2 -- the predicate is hollowed out: armed behaves like unarmed.
sub "$HERO" "	return J.IsInRange( npcEnemy, bot, nCastRange )

end" "	return true

end" || exit 3
score "M2 armed predicate hollowed to \`true\` (lever inert while claiming to be armed)"

# M3 -- the turbo conjunct is dropped, so the lever acts in normal games too.
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkqflee' ) )" \
            "	if not ( J.IsSoakCandidate( 'wkqflee' ) )" || exit 3
score "M3 turbo-only conjunct dropped"

# M4 -- the gate reads a SIBLING id.  ⭐ This is GH #873 §五.1's collision as a
# mutant: arming one string would then arm two levers, and no wave can separate
# them.  The anchor is the whole `not (...)` line so the guard above can see the
# ambiguity if the two helpers ever converge.
sub "$HERO" "J.IsModeTurbo() and J.IsSoakCandidate( 'wkqflee' )" \
            "J.IsModeTurbo() and J.IsSoakCandidate( 'wkqlane' )" || exit 3
score "M4 gate id swapped to the sibling \`wkqlane\`"

# M5 -- the call site is removed from the retreat loop.  The helper still exists,
# still reads correctly, and is consulted by nobody: the `-204` shape (a lever
# whose armed return was never once executed).
sub "$HERO" "				and X.wk_IsFleeBlastTargetInReach( npcEnemy, nCastRange )
" "" || exit 3
score "M5 call site deleted from the retreat loop (helper orphaned)"

# M6 -- the SHIPPED search ring is narrowed to the cast range.  That is the fix
# ungated and applied to every branch at once; §0.1's band counts are counts of
# the +43 ring and must not survive it.
sub "$HERO" "local nEnemysHerosInRange = J.GetNearbyHeroes(bot, nCastRange + 43, true, BOT_MODE_NONE )" \
            "local nEnemysHerosInRange = J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )" || exit 3
score "M6 shipped search ring narrowed from nCastRange + 43 to nCastRange"

# M7 -- the helper stops reading its argument and hardcodes today's rank-1 cast
# range.  ⭐ Behaviourally identical on the pinned frame; it differs ONLY once
# the +260 extension fires or Q outranks rank 1, which is precisely the
# composition §2.3 and §5.3 exist to price.
sub "$HERO" "	return J.IsInRange( npcEnemy, bot, nCastRange )

end" "	return J.IsInRange( npcEnemy, bot, 525 )

end" || exit 3
score "M7 helper ignores its nCastRange argument and hardcodes 525"

echo "=== result ==="
echo "$CAUGHT/$TOTAL caught, $SURVIVED survived"
[ "$SURVIVED" -eq 0 ] || exit 1
