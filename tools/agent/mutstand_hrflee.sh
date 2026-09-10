#!/usr/bin/env bash
# Mutation stand for the lane-harass RETREAT VECTOR (strategy, 2026-09-10).
#
# The claim under test: "J.GetLaneHarassResponse's 'back' branch builds its step
# from the fountain alone, so `tValid` -- the mob it just counted to decide it
# was outnumbered -- has no vote in the heading, and on the one frame in this
# corpus where the harassers sit between the bot and home the retreat spends 402
# of its 420 units CLOSING on them; armed, the heading is projected off the mob
# direction, which moves exactly that frame, keeps the gap, still buys ground
# toward home, and can never change whether 'back' fires."
#
# Run by hand when J.GetLaneHarassResponse, tests/_lanekill_domain_sweep.lua or
# tests/test_hrflee_retreat.lua are edited, and before quoting any of these
# readings anywhere.
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
# #507). Each leg costs ~32s (the test drives the whole fixture corpus once for
# the manifest and four more times for the two named frames); budget ~7 min.
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M1 IS THE PLAUSIBLE WRONG FIX, AND IT IS THE ONE MOST LIKELY TO BE
#     WRITTEN BY THE NEXT READER: retreat STRAIGHT away from the mob. It repairs
#     the measured defect completely -- the landing stops closing -- and it does
#     it by walking the bot AWAY from home, which on the witness costs 415u of
#     ground in the direction the branch exists to travel. Only the second
#     property in section 2 can tell the two apart, which is why that assertion
#     is there and why this leg is first.
#   * M2 AND M4 ARE THE CONDITION LEGS. M2 drops the `nDot < 0` test so the
#     projection runs on every retreat (including the 17 that were already
#     heading away); M4 inverts it so it runs on exactly the wrong ones. Both
#     leave a correctly-named, correctly-placed, id-gated block in the tree.
#   * M3 IS THE EFFECT-BLIND ONE. The centroid is built, the dot product is
#     computed, and the shipped vector is returned anyway. Every source-shape
#     check passes; only driving the helper sees it.
#   * M5 IS WHY SECTION 1 COUNTS MAGNITUDES INSTEAD OF READING ONE. A guard that
#     invents its own step length is a new policy, not the repair this change
#     claims to be -- and the landing would still stop closing, so no behaviour
#     column catches it.
#   * M8 IS THE FORBIDDEN DIRECTION, written as the other plausible fix: give up
#     and return nil rather than re-aim. It also stops the bot walking into the
#     mob -- by deleting a retreat, which is 'hrparity's job and a different
#     change with a different risk. `hf_verdict_moved` is the only column that
#     can reject it.
#   * M9 IS THE FAMILY DEFECT COMING BACK IN THROUGH THE FIX. The armed block
#     builds its own enemy census at its own radius instead of reusing tValid --
#     which is exactly "one comparison, two rulers", the shape this whole family
#     of rounds exists to remove.
#   * M10 AND M11 ARE THE INSTRUMENT LEGS, done by DISCONNECTION rather than
#     rename. M11 guards the CO-ARM reading -- the one number here that changes
#     what a wave request may ask for, and the one most likely to be quietly
#     re-baselined by a later round.
#   * M12 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_hrflee_retreat.lua
SWEEP=tests/_lanekill_domain_sweep.lua

FILES=("$JMZ" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_hrflee.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_hrflee_retreat > "$WORK/run.log" 2>&1
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
COND=$'\t\t\t\t\tif nDot < 0 then\n'
PROJ=$'\t\t\t\t\t\tlocal tx, ty = hx - nDot * ax, hy - nDot * ay\n'
RET=$'\t\t\t\t\t\treturn \'back\',\n\t\t\t\t\t\t\tVector( vB.x + tx * 420, vB.y + ty * 420, vB.z )\n'
GATE=$'\t\tif J.IsModeTurbo() and J.IsSoakCandidate( \'hrflee\' )\n'
MOB=$'\t\t\tfor _, e in pairs( tValid ) do\n'
SWEEP_DEFECT=$'                                    if dLand < dNow then\n                                        bump(\'hf_into_mob\')\n'
SWEEP_PAIR=$'                                            bump(\'hf_lost_to_parity\')\n'
HDR=$'\t\t-- Soak candidate \'hrflee\' (2026-09-10). THE RETREAT DIRECTION IS BUILT\n'

# ---------------------------------------------------------------------------
echo
echo "=== mutants ==="

# M1 -- THE PLAUSIBLE WRONG FIX: run straight away from the mob. Repairs the
# measured defect and abandons the branch's purpose in the same line.
sub_or_die "$JMZ" "$PROJ" \
    $'\t\t\t\t\t\tlocal tx, ty = ax, ay\n'
score "M1 flee straight away from mob   " \
    "gives up ground toward home"

# M2 -- the condition goes away: project on every retreat, including the 17 that
# were already heading away from the mob.
sub_or_die "$JMZ" "$COND" $'\t\t\t\t\tif true then\n'
score "M2 projection on every retreat   " \
    "already heading away from the mob"

# M3 -- DEAD GUARD. Centroid built, dot product computed, shipped vector
# returned anyway. Every source-shape read still passes.
sub_or_die "$JMZ" "$RET" \
    $'\t\t\t\t\t\treturn \'back\',\n\t\t\t\t\t\t\tVector( vB.x + dx / n * 420, vB.y + dy / n * 420, vB.z )\n'
# ⚠️ `want` CORRECTED IN PLACE, not worked around: the first version expected
# "armed produced the shipped landing" (the witness-frame assertion). The
# census assertion fires FIRST -- with the guard dead, `hf_land_moved` drops to
# 0 and `hf_missed_defect` rises to 1, and section 5 runs before section 2's
# frame drive. The leg was red for the right reason with a message this line
# could not match, which is exactly what the WRONG MESSAGE rule is for.
score "M3 dead guard, ships old vector  " \
    "frames were in the defect bucket and armed did not move them"

# M4 -- the condition is INVERTED: the guard re-aims exactly the retreats that
# were already fine and leaves the defect frame alone.
sub_or_die "$JMZ" "$COND" $'\t\t\t\t\tif nDot > 0 then\n'
score "M4 condition inverted            " \
    "frames were in the defect bucket and armed did not move them"

# M5 -- the armed landing invents its own step length. The landing still stops
# closing, so no behaviour column sees it; only section 1 does.
sub_or_die "$JMZ" "$RET" \
    $'\t\t\t\t\t\treturn \'back\',\n\t\t\t\t\t\t\tVector( vB.x + tx * 800, vB.y + ty * 800, vB.z )\n'
# ⚠️ `want` CORRECTED IN PLACE (same reason as M3). The shipped return still
# carries two `* 420` uses, so the count assertion passes and it is the SECOND
# assertion in that test -- "no other magnitude crept in" -- that catches this.
# That is the assertion the leg exists to exercise; the first version of this
# line named the other one.
score "M5 armed step invents 800        " \
    "a second step magnitude appeared in the helper: 800"

# M6 -- the turbo conjunct is dropped: the guard would run in normal games too,
# outside the mode this lab tunes for.
sub_or_die "$JMZ" "$GATE" $'\t\tif J.IsSoakCandidate( \'hrflee\' )\n'
score "M6 turbo conjunct dropped        " \
    "not conjoined with J.IsModeTurbo()"

# M7 -- the change rides a SIBLING id instead of carrying its own. The helper is
# live in real games (bCustomLastHit needs no armed id), so an id that is armed
# for another reason would ship this behaviour unmeasured.
sub_or_die "$JMZ" "$GATE" \
    $'\t\tif J.IsModeTurbo() and J.IsSoakCandidate( \'hrparity\' )\n'
score "M7 rides hrparity's id           " \
    "no 'hrflee' gate in J.GetLaneHarassResponse"

# M8 -- FORBIDDEN DIRECTION, as the other plausible fix: stop retreating rather
# than re-aim. Also stops the bot walking into the mob -- by deleting a retreat.
sub_or_die "$JMZ" "$RET" $'\t\t\t\t\t\treturn nil\n'
score "M8 bail out instead of re-aiming " \
    "armed changed the verdict to nil"

# M9 -- THE FAMILY DEFECT, BACK IN THROUGH THE FIX: the armed block builds its
# own enemy census at its own radius instead of reusing the branch's list.
sub_or_die "$JMZ" "$MOB" \
    $'\t\t\tfor _, e in pairs( J.GetNearbyHeroes( bot, 700, true, BOT_MODE_NONE ) or {} ) do\n'
score "M9 armed block re-censuses at 700" \
    "that is the two-rulers defect this family exists to fix"

# M10 -- INSTRUMENT LEG, by disconnection: the arithmetic route stops seeing the
# defect bucket, so the cross-check has nothing left to disagree with.
sub_or_die "$SWEEP" "$SWEEP_DEFECT" \
    $'                                    if dLand < dNow - 99999 then\n                                        bump(\'hf_into_mob\')\n'
score "M10 arithmetic route disconnected" \
    "the two routes disagree"

# M11 -- INSTRUMENT LEG for the CO-ARM reading: the column that says a leg
# carrying 'hrparity' leaves this id no domain stops counting.
sub_or_die "$SWEEP" "$SWEEP_PAIR" \
    $'                                            bump(\'hf_pair_keeps\')\n'
score "M11 co-arm column disconnected   " \
    "the co-arm reading CHANGED"

# M12 -- CONTROL. A comment-only edit must survive.
sub_or_die "$JMZ" "$HDR" \
    $'\t\t-- Soak candidate \'hrflee\' (2026-09-10). [control edit] THE RETREAT\n\t\t-- DIRECTION IS BUILT\n'
score_control "M12 control: comment-only edit   "

# ---------------------------------------------------------------------------
echo
echo "=== stand ==="
echo "caught $CAUGHT / $TOTAL   (survived $SURVIVED)"
if [ "$SURVIVED" -eq 0 ]; then
    echo "STAND GREEN -- every mutant is visible to the assertions"
    exit 0
fi
echo "STAND RED -- $SURVIVED mutant(s) invisible; the readings above are not"
echo "             backed by anything that would notice them changing"
exit 1
