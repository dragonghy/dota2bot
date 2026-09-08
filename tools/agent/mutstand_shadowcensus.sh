#!/usr/bin/env bash
# Mutation stand for the SECOND shadow census of
# X.ConsiderItemDesire["item_tpscroll"] -- "two thirds of 'stayfield''s branch is
# claimed by an upstream branch, the shadow is BENIGN there, and all three
# candidate levers price out EMPTY" (strategy, 2026-09-08, OWNER_PRIORITIES P2 +
# P4.4(ii)).
# Run by hand when tests/_tpquiet_sweep.lua, its consumers, the four home-TP
# branches of ability_item_usage_generic, or J.IsFieldRegenSituation are edited,
# and before quoting any of the census readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_tpquiet.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a mutant
#     can never score "caught" for having applied to nothing, nor "survived" for
#     having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  A census's whole product is ZEROS AND CEILINGS, and a
# zero is the single easiest reading to fake by accident.  The mutants that
# matter here are therefore the ones that make a zero appear or a ceiling widen
# while everything still looks measured:
#   * M6 IS THE WRONG-BUT-GREEN ONE FOR A CENSUS.  Invert the source clause on
#     the '撤退:3' deep leg.  Nothing about the tree changes, the walk still runs,
#     every structural pin still holds -- and the "this lever is unbuildable for
#     want of one frame" conclusion silently becomes "this lever has a domain".
#     Only an assertion that names the CLAUSE, not the size, can see it.
#   * M7 IS THE MISSING-KEY ONE.  Rename a counter in the sweep.  The bucket
#     stops existing, the manifest still parses, and a `nil` would compare
#     `~= 2` and read as an ordinary failure -- or, in a file without the `must`
#     guard, as nothing at all (GH #171: a bucket never reached and a bucket
#     measured zero must never be the same thing).
#   * M11 IS THE ONE THE COUNTS CANNOT DEFEND.  Give '撤退:2' a regen veto.  Every
#     corpus number in the census is byte-identical -- the census measures
#     TRIGGERS, not vetoes -- while the family's standing exemption, and the
#     correction that explains why it survives, have been quietly reversed.
#   * M13 IS THE CONTROL.  A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
AIUG=bots/ability_item_usage_generic.lua
TEST=tests/test_tpscroll_branch_shadow_census.lua
SWEEP=tests/_tpquiet_sweep.lua

FILES=("$JMZ" "$AIUG" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_shadowcensus.XXXXXX")
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
    lua5.1 tests/run_tests.lua shadow_census > "$WORK/run.log" 2>&1
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

# An anchor failure must never be reported as a surviving mutant: without this
# wrapper `sub` aborts, the mutant never lands, and the leg runs the BASELINE and
# scores SURVIVED.
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

# The control leg is scored with the opposite expectation.
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
T3BOUND=$'                        local bT3 = ((nHP < T3_HP) or (nHP + nMP < T3_SUM))\n                            and bot:GetLevel() >= T3_LVL and nRing1600 <= 1 and bNoFlask\n'
T2BASE=$'                        local bT2 = (nHP < (T2_BASE + T2_PER * nRing1600))\n'
UNION3=$'                            if bT1 or bT2 then bump(\'t3_shadowed_by_either\') end\n'
ROWT1=$'                            if bT1 then bump(\'t3_shadowed_by_t1\'); note(\'t3_by_t1\') end\n'
DEEPSRC=$'                                if J.HasFieldRegenSource(bot) then\n                                    bump(\'t3_deep_src\')\n'
TOWERKEY=$'                            if #bot:GetNearbyTowers(20000, true) > 0 then\n                                bump(\'t2_empty_with_any_tower\')\n                            end\n'
STAYFLOOR=$'G.STAY_FLOOR = tonumber(fieldsit and fieldsit:match(\'nHP < ([%d%.]+) or nHP >\')) or -1\n'
SHIPREAD=$'                    local okStayShip, stay_shipped = pcall(J.ShouldRegenNotTpHome, bot)\n'
FSBAND=$'\tif nHP < 0.18 or nHP > 0.55 then return false end\n'
T3CALL=$'\t\t\tand not J.ShouldRegenNotTpHome( bot )\n'
T2ADDVETO=$'\t\t\tand bot:WasRecentlyDamagedByAnyHero( 6.0 )\n'
T2RET=$'\t\t\tsCastMotive = \'撤退:2\'\n'

# ---------------------------------------------------------------------------
# M1: the '撤退:3' trigger bound loses its level conjunct.  The bound gets LOOSER,
#     which is the direction a reviewer forgives ("it is an upper bound anyway"),
#     and the reachability denominator this whole census divides by moves.
echo
echo "=== M1: 撤退:3's trigger bound drops its level conjunct ==="
sub_or_die "$SWEEP" "$T3BOUND" $'                        local bT3 = ((nHP < T3_HP) or (nHP + nMP < T3_SUM))\n                            and nRing1600 <= 1 and bNoFlask\n'
score "M1 " "trigger bound moved to"

# ---------------------------------------------------------------------------
# M2: '撤退:2''s cap base is zeroed.  This is the very arithmetic the correction
#     in jmz_func rests on: with base 0 the branch really would "require
#     enemies", and the empty-ring leg would vanish -- turning a corrected
#     finding back into the sentence it replaced.
echo
echo "=== M2: 撤退:2's cap base is zeroed (the 'requires enemies' claim) ==="
sub_or_die "$SWEEP" "$T2BASE" $'                        local bT2 = (nHP < (0 + T2_PER * nRing1600))\n'
# The first assertion the mutant reaches is the branch's TRIGGER bound, not the
# empty-ring column two lines below it -- zeroing the base shrinks the whole
# branch, not just its quiet leg. Scored on the message the reader actually
# gets: a stand that demands a message the code cannot produce reports a caught
# mutant as survived.
score "M2 " "撤退:2's trigger bound moved to"

# ---------------------------------------------------------------------------
# M3: the shadow UNION becomes an intersection.  6 would read as 2, and the
#     headline "two thirds of the branch" would read as "a fifth".
echo
echo "=== M3: the shadow union is computed as an intersection ==="
sub_or_die "$SWEEP" "$UNION3" $'                            if bT1 and bT2 then bump(\'t3_shadowed_by_either\') end\n'
score "M3 " "the union moved to"

# ---------------------------------------------------------------------------
# M4: the printed rows for the 撤退:1 shadow stop being emitted while the counter
#     keeps counting.  The count survives; the ONLY evidence that could be
#     re-checked against the looseness of the bounds is gone.
echo
echo "=== M4: the 撤退:1 shadow rows stop being printed (counter kept) ==="
sub_or_die "$SWEEP" "$ROWT1" $'                            if bT1 then bump(\'t3_shadowed_by_t1\') end\n'
score "M4 " "disagree with the count"

# ---------------------------------------------------------------------------
# M5: the sweep's parse of the field-regen floor is replaced by a literal.  The
#     partition below/above the floor is the whole "5 of 9 have no veto at all"
#     subtraction, and a literal makes it stop tracking the source it claims to
#     be about.
echo
echo "=== M5: the field-regen floor is a literal instead of a parse ==="
sub_or_die "$SWEEP" "$STAYFLOOR" $'G.STAY_FLOOR = 0.10\n'
score "M5 " "read a different field-regen band"

# ---------------------------------------------------------------------------
# M6: THE WRONG-BUT-GREEN ONE.  The deep leg's source clause is inverted, so the
#     empty domain fills up.  Everything else is untouched; the conclusion
#     "unbuildable for want of one frame" silently becomes its opposite.
echo
echo "=== M6: the deep leg's regen-source clause is inverted ==="
sub_or_die "$SWEEP" "$DEEPSRC" $'                                if not J.HasFieldRegenSource(bot) then\n                                    bump(\'t3_deep_src\')\n'
score "M6 " "no longer empty"

# ---------------------------------------------------------------------------
# M7: THE MISSING-KEY ONE.  A counter the census asserts on is renamed at its
#     bump site, so the bucket keeps its zero-initialised value forever.  Without
#     an anti-vacuum assertion this reads as a perfectly ordinary measurement.
echo
echo "=== M7: an anti-vacuum counter is renamed at its bump site ==="
sub_or_die "$SWEEP" "$TOWERKEY" $'                            if #bot:GetNearbyTowers(20000, true) > 0 then\n                                bump(\'t2_empty_with_any_tower_x\')\n                            end\n'
score "M7 " "anti-vacuum for the tower clause on this leg moved"

# ---------------------------------------------------------------------------
# M8: the SHIPPED read of the '撤退:3' veto is taken with the id already armed.
#     The inertness column then reads TRUE-heavy, and "this id is gated" would be
#     answered by a stub rather than by the tree.
echo
echo "=== M8: the shipped read of the 撤退:3 veto is taken armed ==="
sub_or_die "$SWEEP" "$SHIPREAD" $'                    sArmed = \'stayfield\'\n                    local okStayShip, stay_shipped = pcall(J.ShouldRegenNotTpHome, bot)\n                    sArmed = nil\n'
score "M8 " "answers TRUE with no id armed"

# ---------------------------------------------------------------------------
# M9: the shared field-regen band is widened downward in jmz_func.  This is the
#     edit the census explicitly refuses to make (it moves 'stayfield',
#     'stayfield2' and 'fieldbuy' on one push -- the lanefix bundle mistake), so
#     it must not be able to arrive silently underneath the census either.
echo
echo "=== M9: the shared field-regen floor is lowered 0.18 -> 0.10 ==="
sub_or_die "$JMZ" "$FSBAND" $'\tif nHP < 0.10 or nHP > 0.55 then return false end\n'
score "M9 " "field-regen band moved to"

# ---------------------------------------------------------------------------
# M10: 'stayfield''s only call site is deleted from '撤退:3'.  Every reachability
#      number in the census is ABOUT that call site; without it the file would be
#      measuring the reachability of nothing.
echo
echo "=== M10: 'stayfield''s call site is deleted from 撤退:3 ==="
sub_or_die "$AIUG" "$T3CALL" ""
score "M10" "no longer wired into"

# ---------------------------------------------------------------------------
# M11: THE ONE THE COUNTS CANNOT DEFEND.  '撤退:2' acquires a regen veto.  Every
#      corpus counter is byte-identical (the census measures triggers), and the
#      family's standing exemption -- kept on a measurement, not on the sentence
#      that used to justify it -- is reversed with nothing raising a hand.
echo
echo "=== M11: 撤退:2 acquires a regen veto ==="
sub_or_die "$AIUG" "$T2ADDVETO" $'\t\t\tand bot:WasRecentlyDamagedByAnyHero( 6.0 )\n\t\t\tand not J.ShouldStayAndRegen( bot )\n'
score "M11" "has acquired the veto"

# ---------------------------------------------------------------------------
# M12: the branch IDENTITY anchor is renamed.  Every "which branch is upstream"
#      fact in this census -- and every branch slice in the sweep -- is anchored
#      on the cast-motive STRING, because the `return ... tpLoc ...` line is
#      shared by all three retreat branches and cannot identify one (the sibling
#      stand's M13).  Rename the motive and the anchors silently lose their
#      subject while the file still compiles and still TPs home.
echo
echo "=== M12: 撤退:2's cast motive is renamed (the branch identity anchor) ==="
sub_or_die "$AIUG" "$T2RET" $'\t\t\tsCastMotive = \'撤退:2b\'\n'
score "M12" "is gone from the comment-stripped source"

# ---------------------------------------------------------------------------
# M13: THE CONTROL.  A comment-only edit inside the corrected block must SURVIVE.
echo
echo "=== M13 (control): a comment-only edit must SURVIVE ==="
sub_or_die "$JMZ" $'-- ⛔ CORRECTION 2026-09-08 (strategy, tests/test_tpscroll_branch_shadow_census.lua).\n' $'-- ⛔ CORRECTION 2026-09-08 (strategy, tests/test_tpscroll_branch_shadow_census.lua). [control]\n'
score_control "M13"

# ---------------------------------------------------------------------------
echo
echo "=== stand summary ==="
echo "legs: $TOTAL   caught (incl. control behaving): $CAUGHT   survived: $SURVIVED"
if [ "$SURVIVED" -eq 0 ]; then
    echo "STAND GREEN -- every mutant is visible and the control is not"
    exit 0
fi
echo "STAND RED -- $SURVIVED leg(s) the census cannot see"
exit 1
