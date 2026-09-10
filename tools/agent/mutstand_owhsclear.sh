#!/usr/bin/env bash
# Mutation stand for the off-wave harass AGGRO-CLEARANCE cut (strategy,
# 2026-09-10).
#
# The claim under test: "J.GetOffWaveHarassSpot built `tCreeps` -- the enemy
# lane creeps inside nAggroR, the only reason the branch exists -- fed it to the
# lane axis and then gave it no vote in the one free variable, the sign of the
# perpendicular; so the nStep sidestep could land back inside nAggroR of a creep
# (a third of the aggro ball does that), and the fix is a TIE-BREAK that
# overrules the hero vote only when the side it picked fails the aggro test AND
# the mirror passes it -- never changing WHETHER the sidestep fires, and with no
# id of its own."
#
# Run by hand when J.GetOffWaveHarassSpot, tests/_lanekill_domain_sweep.lua or
# tests/test_owhs_aggro_clearance.lua are edited, and before quoting any of
# these readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_owhs.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK (GH
# #507). Each leg drives the whole fixture corpus once for the manifest and four
# more times for the witnesses; budget ~6 min.
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M1 IS THE DEFECT ITSELF, put back. If the stand cannot catch the tie-break
#     being deleted, nothing else it says means anything.
#   * M2 IS THE POLICY MUTANT and it is the one a reader is most likely to write
#     by accident: drop the "the side I picked actually fails" half and always
#     take the clean side. It looks like the same idea and it is a different
#     change -- it overrules the hero vote on frames with no cause. Only the
#     no-op column (foot injection) and the negative control see it.
#   * M3 IS THE EFFECT-BLIND ONE. The clearance test is present, correctly
#     placed and correctly shaped -- and measures the wrong SET (the hero
#     census). Every source-shape check passes.
#   * M4 IS THE SILENT NARROWING: the clearance test keeps its shape and reads a
#     tighter ball than the branch is about, so the fix no-ops on its own
#     witness while every structural row stays green.
#   * M5 AND M6 ARE THE 0DUPGUARD LEGS (charter item 甲, 2026-09-10). Each
#     splits ONE binding back into two literals that agree today. Behaviour is
#     byte-for-byte identical on every frame; only the single-binding row in
#     section 1 can see it. On `deepnum` this exact mutant was the one that
#     proved the shared local was load-bearing.
#   * M7 AND M8 ARE THE INSTRUMENT LEGS, done by DISCONNECTION rather than
#     rename, so the reader gets a reported 0 against a live population. M8 in
#     particular guards the COST column -- the one number in this round that
#     argues against the change (161 of 166 flips step nearer a hero).
#   * M9 IS THE FORBIDDEN DIRECTION written as the plausible alternative fix:
#     refuse to step at all when the wave would not be cleared. It removes the
#     bad step by removing the branch, which is the sister stand's M8 and is
#     rejected here by the same column.
#   * M10 PROVES SECTION 2 IS NOT DECORATION: push the step past twice the aggro
#     radius and the defect becomes unreachable, so the cut would be dead code.
#   * M11 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
SWEEP=tests/_lanekill_domain_sweep.lua
TEST=tests/test_owhs_aggro_clearance.lua

FILES=("$JMZ" "$SWEEP" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_owhsclear.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_owhs_aggro_clearance > "$WORK/run.log" 2>&1
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

sub_or_die() {
    sub "$@" || { echo "ANCHOR FAILURE -- stand aborted, nothing below is meaningful"; exit 3; }
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -3 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
SURVIVED=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
        SURVIVED=$((SURVIVED + 1))
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
        SURVIVED=$((SURVIVED + 1))
    fi
    restore > /dev/null
}

score_control() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- CORRECT, this leg must not be caught"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) -- the stand is scoring the ACT of editing,"
        echo "        not the edit; every count above is suspect:"
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
        SURVIVED=$((SURVIVED + 1))
    fi
    restore > /dev/null
}

# Anchors are LITERAL and must be UNIQUE.
TIEBREAK=$'\tif nCreepsAggroedAt( px, py ) > 0\n\tand nCreepsAggroedAt( -px, -py ) == 0 then\n\t\tpx, py = -px, -py\n\tend\n'
LOOP=$'\t\tfor _, hCreep in pairs( tCreeps ) do\n'
CMP=$'\t\t\t\tif math.sqrt( ex * ex + ey * ey ) < nAggroR then\n'
STEPBIND=$'\tlocal nStep = 550\n'
RET=$'\treturn Vector( vBot.x + px * nStep, vBot.y + py * nStep, 0 )\n'
CREEPLIST=$'\tlocal tCreeps = bot:GetNearbyLaneCreeps( nAggroR, true )\n'
SW_CAUSE=$'                            if bOldHits then bump(\'ow_clear_old_hits\') end\n'
SW_COST=$'                                        bump(\'ow_clear_flip_nearer_hero\')\n'
HDR=$'\t-- [CLEARANCE 20260910] THE SET THAT MADE THE STEP NECESSARY HAD NO VOTE IN\n'

# ---------------------------------------------------------------------------
echo
echo "=== mutants ==="

# M1 -- THE DEFECT, put back: the creep set goes back to having no vote.
sub_or_die "$JMZ" "$TIEBREAK" ""
score "M1 tie-break deleted             " \
    "the tie-break did not fire on its own witness"

# M2 -- THE POLICY MUTANT: keep the clean side whenever it is clean, with no
# requirement that the side the hero vote picked actually failed.  Same idea to
# a skim reader, a different change to the bot: it overrules the vote for free.
sub_or_die "$JMZ" "$TIEBREAK" \
    $'\tif nCreepsAggroedAt( -px, -py ) == 0 then\n\t\tpx, py = -px, -py\n\tend\n'
score "M2 flip whenever mirror is clean " \
    "moved a spot on the foot injection"

# M3 -- DEAD SET.  The clearance test is shaped correctly and measures the hero
# census instead of the creeps it exists to clear.
#
# ⚠️ THIRD FORMULATION OF THE `want`, both earlier ones recorded rather than
# quietly replaced -- the message a leg prints is part of what the stand
# certifies, so getting it wrong twice is worth more written down than hidden.
#   draft 1, the witness message ("the tie-break did not fire on its own
#     witness"): WRONG MESSAGE. On the witness frames this mutant still flips --
#     for the wrong reason -- and the spot still comes out clear, so those rows
#     stay GREEN. A witness that checks only the OUTCOME can be satisfied by
#     luck; only a control that fixes the CAUSE separates them.
#   draft 2, the BEHIND control's second assertion ("the side flipped with the
#     creep behind the step"): still WRONG MESSAGE, and for a reason worth
#     keeping. The control never reaches its second assertion, because the
#     mutant has already broken its FIRST one: `drive` learns which side to put
#     the creep on by asking the helper (pass 1), so a helper wired to the wrong
#     set answers pass 1 wrongly too, and the arithmetic restatement -- which is
#     NOT mutated -- lands 151u from a creep that is supposed to be behind it.
# The string below is the one the reader actually gets, and it happens to be the
# sharpest of the three: the helper's own answer no longer agrees with the
# independent restatement of its own rule.
sub_or_die "$JMZ" "$LOOP" $'\t\tfor _, hCreep in pairs( tSideEnemies or {} ) do\n'
score "M3 clearance reads the wrong set " \
    "the geometry is not what this file thinks it is"

# M4 -- SILENT NARROWING.  A tighter ball than the branch is about: every
# structural row stays green and the fix no-ops where it matters.
sub_or_die "$JMZ" "$CMP" \
    $'\t\t\t\tif math.sqrt( ex * ex + ey * ey ) < nAggroR * 0.2 then\n'
score "M4 clearance ball narrowed 0.2x  " \
    "the tie-break did not fire on its own witness"

# M5 -- 0DUPGUARD 甲, step side: the return goes back to a literal.  Behaviour
# is identical on every frame in the corpus.
sub_or_die "$JMZ" "$RET" \
    $'\treturn Vector( vBot.x + px * 550, vBot.y + py * 550, 0 )\n'
score "M5 step binding split to literal " \
    "appears more than once in the helper"

# M6 -- 0DUPGUARD 甲, aggro side: the creep list goes back to a literal.
sub_or_die "$JMZ" "$CREEPLIST" \
    $'\tlocal tCreeps = bot:GetNearbyLaneCreeps( 500, true )\n'
score "M6 aggro binding split to literal" \
    "appears more than once in the helper"

# M7 -- INSTRUMENT, cause side.  The column that says the probe really is
# standing in the region that defeats the step.
sub_or_die "$SWEEP" "$SW_CAUSE" ""
score "M7 cause column cut              " \
    "ow_clear_old_hits 0 != probe"

# M8 -- INSTRUMENT, cost side.  The column that argues AGAINST this change.
sub_or_die "$SWEEP" "$SW_COST" ""
score "M8 cost column cut               " \
    "the cost column reads zero"

# M9 -- THE FORBIDDEN DIRECTION as the plausible alternative fix: refuse the
# sidestep when it would not clear the wave.  It repairs the aiming by deleting
# the branch on exactly its own domain.
sub_or_die "$JMZ" "$TIEBREAK" \
    $'\tif nCreepsAggroedAt( px, py ) > 0 then return nil end\n'
score "M9 bail out instead of flipping  " \
    "the clearance test leaked into the firing condition"

# M10 -- the relation between the two constants, which is what makes the defect
# reachable at all.  A step past 2*nAggroR clears from any creep position.
sub_or_die "$JMZ" "$STEPBIND" $'\tlocal nStep = 1100\n'
score "M10 step past twice the ball     " \
    "the step now clears the aggro ball from any creep position"

# M11 -- CONTROL.  A comment-only edit must survive.
sub_or_die "$JMZ" "$HDR" \
    $'\t-- [CLEARANCE 20260910] the set that made the step necessary had no vote\n'
score_control "M11 control: comment-only edit   "

# ---------------------------------------------------------------------------
echo
echo "=== stand ==="
echo "caught/correct $CAUGHT of $TOTAL   (survived $SURVIVED)"
if [ "$SURVIVED" -eq 0 ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED -- $SURVIVED leg(s) the tests cannot see"
exit 1
