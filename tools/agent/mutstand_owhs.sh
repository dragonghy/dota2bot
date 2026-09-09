#!/usr/bin/env bash
# Mutation stand for the off-wave harass SIDE RULER (strategy, 2026-09-09).
#
# The claim under test: "J.GetOffWaveHarassSpot chose which way to sidestep by
# averaging the HARASS-TARGET list (enemies within 800), while the sentence that
# choice implements says 'away from their OTHER laner' -- so a hero at 900 had
# no vote on ground the 550u step was about to cross; the side choice now reads
# its own census at the radius this branch already uses twice, that changes the
# side on 4 of the 166 reachable frames in this corpus and never changes WHETHER
# the sidestep fires, and the change carries no id of its own because its single
# call site is a pure conjunction with 'l5trees'."
#
# Run by hand when J.GetOffWaveHarassSpot, the cut-2 branch in
# bots/mode_laning_generic.lua, tests/_lanekill_domain_sweep.lua or
# tests/test_owhs_side_ruler.lua are edited, and before quoting any of these
# readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_deepnum.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK (GH
# #507). Each leg costs ~27s (the test drives the whole fixture corpus once for
# the manifest and three more times for the named witnesses); budget ~6 min.
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M1 AND M2 ARE WHY SECTION 1 ASSERTS AN EQUALITY, NOT A LITERAL. M1 puts
#     the side census back on the target list's 800 (present, named, correctly
#     placed -- and the identity of the old defect); M2 overshoots it to 2400,
#     which is a new policy rather than the repair this change claims to be. A
#     test that asserted ">= 800", or that only watched the flip count, would
#     let one of the two through.
#   * M3 IS THE EFFECT-BLIND ONE. The census is present, unique, named and
#     correctly placed, and the centroid loop quietly averages the OLD list
#     instead. Every source-shape check passes; only driving the helper and
#     recomputing the side independently sees it.
#   * M4 IS THE WRONG REPAIR. Widening the TARGET list to 1200 also puts the
#     comparison on one ruler -- by moving the ruler that decides whether the
#     sidestep fires at all, which is a different change with a different risk
#     and was not measured here.
#   * M6 IS THE BOUND LEG. Never flipping makes the driven spot agree with the
#     old rule everywhere; only the second, arithmetic route can say so.
#   * M8 IS THE FORBIDDEN DIRECTION, written as the plausible ALTERNATIVE fix:
#     bail out instead of choosing a side. It repairs the defect in the sense
#     that the bot no longer walks at the voteless hero -- by stopping the
#     sidestep on 39 frames, i.e. by changing when the branch fires. The test
#     must reject it, and `ow_drive_nil_on_reach` is the only column that can.
#   * M9 IS THE GATE-CLAIM LEG (last round's sister finding, from the other
#     side): a header saying "only 'l5trees' reaches me" is worth nothing if the
#     call site grows a disjunct that needs no id. This change carries no id of
#     its own BECAUSE that claim is true, so a pin has to watch it.
#   * M10 AND M11 ARE THE INSTRUMENT LEGS, done by DISCONNECTION rather than
#     rename: both columns are genuinely non-zero here, so neither is an
#     equivalent mutant. M11 in particular guards the COST reading -- the one
#     number in this round that argues against the change.
#   * M12 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
MODE=bots/mode_laning_generic.lua
TEST=tests/test_owhs_side_ruler.lua
SWEEP=tests/_lanekill_domain_sweep.lua

FILES=("$JMZ" "$MODE" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_owhs.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_owhs_side_ruler > "$WORK/run.log" 2>&1
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
SIDE=$'\tlocal tSideEnemies = J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE )\n'
SIDE_LOOP=$'\tfor _, e in pairs( tSideEnemies or {} ) do\n'
# TWO lines, not one: the bare `local tEnemies = J.GetNearbyHeroes( bot, 800,
# true, ... )` line appears TWICE in jmz_func.lua and the ambiguity check would
# refuse it rather than mutate whichever came first (GH #550).
TGT=$'\tlocal tEnemies = J.GetNearbyHeroes( bot, 800, true, BOT_MODE_NONE )\n\tlocal bTarget = false\n'
ALLY=$'\tlocal tAllies = J.GetNearbyHeroes( bot, 1200, false, BOT_MODE_NONE )\n'
FLIP=$'\t\t\tpx, py = -px, -py\n'
NEN=$'\tif nEn > 0 then\n'
GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'l5trees\')\n'
SWEEP_BAND=$'                                bump(\'ow_band\')\n'
SWEEP_COST=$'                                    bump(\'ow_flip_nearer_someone\')\n'
HDR=$'-- [RULER 20260909] TWO QUESTIONS, ONE LIST -- fixed. The 800 list answers "is\n'

# ---------------------------------------------------------------------------
echo
echo "=== mutants ==="

# M1 -- the side census goes back to the target list's radius: present, named,
# correctly placed, and the identity of the defect this round removed.
sub_or_die "$JMZ" "$SIDE" \
    $'\tlocal tSideEnemies = J.GetNearbyHeroes( bot, 800, true, BOT_MODE_NONE )\n'
score "M1 side census back to 800       " \
    "must read the same board as this helper's own"

# M2 -- the side census OVERSHOOTS every board this branch uses.  Still a
# differential, still one list per question -- and no longer this branch's own
# number, which is the entire "this is a repair, not a new policy" argument.
sub_or_die "$JMZ" "$SIDE" \
    $'\tlocal tSideEnemies = J.GetNearbyHeroes( bot, 2400, true, BOT_MODE_NONE )\n'
score "M2 side census overshoots 2400   " \
    "must read the same board as this helper's own"

# M3 -- DEAD CENSUS.  The wider list is computed and the centroid loop averages
# the old one.  Every source-shape read still passes.
sub_or_die "$JMZ" "$SIDE_LOOP" $'\tfor _, e in pairs( tEnemies or {} ) do\n'
score "M3 census computed, not used     " \
    "stopped keying on its own side census"

# M4 -- THE WRONG REPAIR: put both questions on one ruler by widening the one
# that decides whether the sidestep fires at all.
#
# ⚠️ SECOND FORMULATION OF THE `want`, recorded rather than quietly replaced.
# The first draft demanded "the harass-target radius moved", which is section
# 1's SECOND assertion -- and it never runs, because widening the target list to
# the side radius trips the FIRST one (strict containment) a line earlier. The
# leg was red for the right reason and scored WRONG MESSAGE on a `want` that
# named a line the reader never reaches; the string below is the one the reader
# actually gets.
sub_or_die "$JMZ" "$TGT" \
    $'\tlocal tEnemies = J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE )\n\tlocal bTarget = false\n'
score "M4 target list widened instead   " \
    "must stay strictly inside the side census"

# M5 -- the ally peel scan moves off the branch's board.  The equality in
# section 1 is symmetric on purpose: it is a claim about ONE ruler, so either
# side moving must break it.
sub_or_die "$JMZ" "$ALLY" \
    $'\tlocal tAllies = J.GetNearbyHeroes( bot, 800, false, BOT_MODE_NONE )\n'
score "M5 peel scan moved to 800        " \
    "must read the same board as this helper's own"

# M6 -- the side choice stops flipping: the step always goes to the +p side, so
# the driven spot agrees with the old rule everywhere.
sub_or_die "$JMZ" "$FLIP" ""
score "M6 perpendicular never flipped   " \
    "stopped keying on its own side census"

# M7 -- the vote is skipped entirely (the centroid is never consulted).  Same
# observable shape as M6 from the source, different cause.
sub_or_die "$JMZ" "$NEN" $'\tif false then\n'
score "M7 vote never consulted          " \
    "stopped keying on its own side census"

# M8 -- THE PLAUSIBLE ALTERNATIVE FIX, and it is forbidden: refuse to sidestep
# at all when somebody in the band would be crossed.  It removes the bad step
# by removing the branch on 39 frames.
sub_or_die "$JMZ" "$SIDE" \
    $'\tlocal tSideEnemies = J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE )\n\tfor _, e in pairs( tSideEnemies or {} ) do\n\t\tif J.IsValidHero( e ) and GetUnitToUnitDistance( bot, e ) > 800 then return nil end\n\tend\n'
score "M8 bail out instead of choosing  " \
    "the side census leaked into the firing condition"

# M9 -- the gate claim this change rests on: the call site grows a disjunct that
# needs no armed id, so the helper (and this edit inside it) would be LIVE.
sub_or_die "$MODE" "$GATE" \
    $'\tif J.IsModeTurbo() and (J.IsSoakCandidate(\'l5trees\') or J.IsCore(bot))\n'
score "M9 call-site gate disjoined      " \
    "the call-site gate grew a disjunction"

# M10 -- the instrument: the column that proves an enemy really does sit in the
# band on this corpus is disconnected.  Zero-initialised, so what the reader
# gets is a reported 0 against a live population, not a missing key.
sub_or_die "$SWEEP" "$SWEEP_BAND" ""
score "M10 band column cut              " \
    "ow_band 0 != ow_side_pop_differs"

# M11 -- the instrument, on the COST side.  This is the column that argues
# AGAINST the change (the new side can step nearer the hero being poked), and a
# stand that only guarded the flattering columns would be scoring an argument.
sub_or_die "$SWEEP" "$SWEEP_COST" ""
score "M11 cost column cut              " \
    "ow_flip_nearer_someone 0 vs ow_side_flips"

# M12 -- CONTROL.  A comment-only edit must survive.
sub_or_die "$JMZ" "$HDR" \
    $'-- [RULER 20260909] (comment reflowed by the mutation stand control leg)\n'
score_control "M12 comment-only control         "

# ---------------------------------------------------------------------------
echo
echo "=== stand summary ==="
echo "legs $TOTAL  caught $CAUGHT  survived $SURVIVED"
if [ "$SURVIVED" -eq 0 ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED -- $SURVIVED leg(s) the change's tests cannot see"
exit 1
