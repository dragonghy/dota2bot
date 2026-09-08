#!/usr/bin/env bash
# Mutation stand for the `axecullreach` candidate -- the reach term on
# X.ConsiderR's one firing loop in bots/BotLib/hero_axe.lua, which selected from
# nCastRange + 200 (375u) while the ability reaches 175u and the correctly-scoped
# list sat DEAD on the line above (hero, 2026-09-08, OWNER_PRIORITIES P4.4 (i)).
# Run by hand when X.IsCullReachOn, X.CullTargetPool, X.ConsiderR or
# tests/test_axe_cull_reach.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkqlane.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution in a
#     double-quoted bash string scored a mutant "red with the wrong message" on
#     2026-09-07).
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while moving
# nothing, or moving the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, armed path hands back the shipped pool.  Inert in every wave, and
#     the verdict reads back "tested, no effect".
#   * M3 is the INVERSION -- armed drops the in-reach casts and keeps the
#     out-of-reach ones.  Unlike the `wkqlane` shape, this lever CAN be widened
#     (M9), because its two pools are both real lists; so both directions are on
#     the stand.
#   * M6 is the ARGUMENT SWAP.  `X.CullTargetPool(a, b)` with a and b exchanged
#     inverts the lever while every distance, health and wiring assertion that
#     does not look at argument ORDER still passes.  This is why section 8 pins
#     the argument order literally.
#   * M7 and M8 are the two facts the fixture world cannot drive, mutated IN THE
#     SOURCE rather than in the assertion: a second firing branch in X.ConsiderR
#     (the `lionrreach` relocation trap, which would CATCH the rejected targets),
#     and an R arm that stops returning before the Q arm (which is the whole
#     mechanism behind "Berserker's Call is never even asked").  Weakening the
#     assert instead would only prove the assert can be deleted.
#   * M10 is the pullcad trap (AGENTS.md): conjoining the sibling `cullthresh`,
#     which would freeze this gate FALSE the day that sibling is promoted while
#     check_armed_wiring.py still calls it WIRED.
#   * M11 is a control on the STAND ITSELF -- it breaks the corpus census so a
#     census that cannot go red would be exposed.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_cull_reach.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_axecr.XXXXXX")
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

# The filter is `axe`, not this one file: eleven sibling Axe test files read the
# same hero module, and a stand scoped to the new file alone would report a
# collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua axe > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of two identical sites scores "survived" for the
# wrong reason.
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
# M1: the candidate check is dropped.  The narrowing becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecullreach' )" \
            "	return J.IsModeTurbo()"
score "M1" "unarmed FRAME_RING no longer fires Culling"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecullreach' )" \
            "	return J.IsSoakCandidate( 'axecullreach' )"
score "M2" "is no longer turbo-only"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed keeps the out-of-reach targets and
#     drops the in-reach ones -- the exact opposite of every sentence written
#     about this lever, while staying gated, wired and turbo-only.
echo
echo "=== M3: the pool selection is inverted ==="
sub "$HERO" "		return tInRangeEnemyList
	end

	return tInBonusEnemyList" \
            "		return tInBonusEnemyList
	end

	return tInRangeEnemyList"
score "M3" "armed FRAME_RING still bids"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped pool anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped pool (dead wiring) ==="
sub "$HERO" "		return tInRangeEnemyList
	end" \
            "		return tInBonusEnemyList
	end"
score "M4" "armed FRAME_RING still bids"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.  Helper, header, id registration and unit tests
#     all survive; the loop goes back to committing on the 375u ring.
echo
echo "=== M5: the call site is removed from X.ConsiderR ==="
sub "$HERO" "	for _, npcEnemy in pairs( X.CullTargetPool( nInRangeEnemyList, nInBonusEnemyList ) )" \
            "	for _, npcEnemy in pairs( nInBonusEnemyList )"
score "M5" "call sites in X.ConsiderR, was 1"

# ---------------------------------------------------------------------------
# M6: THE ARGUMENT SWAP.  Same helper, same call site, arguments exchanged.  The
#     lever inverts, and every assertion that does not read argument ORDER still
#     passes -- which is precisely why section 8 pins the order literally.
echo
echo "=== M6: the two pools are passed in the wrong order ==="
sub "$HERO" "X.CullTargetPool( nInRangeEnemyList, nInBonusEnemyList )" \
            "X.CullTargetPool( nInBonusEnemyList, nInRangeEnemyList )"
score "M6" "armed FRAME_RING still bids"

# ---------------------------------------------------------------------------
# M7: the relocation ratchet is disarmed.  A second firing branch in X.ConsiderR
#     could CATCH the targets this lever rejects (the `lionrreach` trap), and
#     section 6 exists to make that a red rather than a rediscovery.
echo
echo "=== M7: a second firing branch appears in X.ConsiderR ==="
sub "$HERO" "	local nDamageType = DAMAGE_TYPE_PURE" \
            "	local nDamageType = DAMAGE_TYPE_PURE
	if false then return BOT_ACTION_DESIRE_HIGH, nil, 'M7' end"
score "M7" "firing branches, was 1"

# ---------------------------------------------------------------------------
# M8: the dominance ratchet is disarmed.  Section 7 carries the ONLY machine
#     check behind the "Berserker's Call is never even asked" argument; without
#     it that argument is prose.
echo
echo "=== M8: the R arm stops returning before the Q arm ==="
sub "$HERO" "		bot:ActionQueue_UseAbilityOnEntity( abilityR, castRTarget )
		return
	end" \
            "		bot:ActionQueue_UseAbilityOnEntity( abilityR, castRTarget )
	end"
score "M8" "the R arm no longer returns unconditionally"

# ---------------------------------------------------------------------------
# M9: THE WIDENING.  Unlike a lever whose shipped answer is an unconditional
#     true, this one CAN be made to add casts: hand the armed path a pool built
#     on a LARGER radius.  Nothing about the gate, the id or the wiring changes.
echo
echo "=== M9: the armed pool is widened past the shipped one ==="
# The anchor carries the DAMAGE_TYPE_PURE line above it: X.ConsiderW opens with a
# byte-identical `nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )` pair,
# and the two-line form alone is AMBIGUOUS (this stand scored M9 SURVIVED on that
# for one round -- an aborted mutant is not a passing one).
sub "$HERO" "	local nDamageType = DAMAGE_TYPE_PURE
	local nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )" \
            "	local nDamageType = DAMAGE_TYPE_PURE
	local nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange + 400 )"
score "M9" "the armed pool is no longer built on the bare nCastRange"

# ---------------------------------------------------------------------------
# M10: the pullcad trap in its native habitat -- the gate names the sibling
#      `cullthresh`, which lives in the same function and would freeze this gate
#      FALSE the day that sibling is promoted, with check_armed_wiring.py still
#      calling it WIRED.
echo
echo "=== M10: the gate conjoins the sibling cullthresh id ==="
sub "$HERO" "	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecullreach' )" \
            "	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecullreach' ) and J.IsSoakCandidate( 'cullthresh' )"
score "M10" "soak ids, was 1"

# ---------------------------------------------------------------------------
# M11: a control on the STAND ITSELF.  Break the corpus enumeration and the two
#      census sections (5 and 10) must notice; a census that cannot go red is a
#      sentence, not a limit.
echo
echo "=== M11: the corpus enumeration is emptied ==="
sub "$TEST" "        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))" \
            "        local p = assert(io.popen('ls /nonexistent_corpus_dir 2>/dev/null'))"
score "M11" "corpus frames carry an Axe"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT / $TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ]
