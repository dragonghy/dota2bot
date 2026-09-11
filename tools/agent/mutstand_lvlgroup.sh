#!/usr/bin/env bash
# Mutation stand for the `lvlgroup` lever (strategy desk 2026-09-11T1x:xxZ).
# Not part of any suite -- run by hand when X.NoNearbyEnemyAtLevelGroup in
# bots/mode_team_roam_generic.lua, its one call site, or
# tests/test_lvlgroup_group_push_level_quantifier.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ ANCHORS CARRY THE GATE LINE, AND HERE THAT MATTERS MORE THAN IT DID FOR
# 'lvlcarry'. There are now THREE byte-identical helper bodies in $SRC
# (X.NoNearbyEnemyAtLevel, ...Carry, ...Group) -- same loop, same comparison,
# different id. The gate id is the ONLY thing that disambiguates them, so every
# body anchor below carries it. A bare anchor would make `sub` abort as
# AMBIGUOUS, and a stand that aborts scores nothing.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while leaving
# the defect, or while quietly meaning something else:
#   * M1/M3 are the two shapes of "the gate stops holding the change back"; M2
#     is the narrower half (turbo-only dropped, candidate kept). All three make
#     the UNARMED leg fire, which is the one thing a gated fix must never do.
#   * M4 and M5 are the two ways the armed leg can look repaired and not be.
#     M4 flips the loop's answer; M5 keeps the loop and re-reads `[1]` inside
#     it, leaving every structural pin in section 6 green.
#   * M6 is the pullcad trap (AGENTS.md): conjoining an already-PROMOTED id
#     freezes the gate FALSE forever. `fight` is a real promoted id.
#   * M7 is the family's own failure mode: point this helper's gate at
#     'lvlcarry'. The two sites then arm and disarm TOGETHER -- the lanefix
#     bundling (gpm -74.5, then -88.7, 0/4 comps) rebuilt by hand -- while every
#     behavioural assertion stays green, because the helper still does the right
#     thing when it is armed. Only section 6 can see whose id it is.
#   * M8 moves the drive cell; 650/12 are read off the shipped call site.
#   * M9 is the FORBIDDEN DIRECTION: leave the helper alone, rewrite the CALLER
#     so nothing asks the question.
#   * M10 is the BATON eroding: the ONE remaining sibling quietly repaired, with
#     no id, no test and no line in any report -- the GH #13 shape as an
#     assertion.
#   * M11 is the premise, shared with 'lvlany'/'lvlcarry' and worth paying for a
#     third time: if the list stops being distance-ordered, `[1]` is no longer
#     "correctly the nearest" and the argument silently downgrades to the weaker
#     'anyhero' one.
#   * M12 and M13 are "the corpus quietly stopped being about the right set of
#     heroes". Neither can be caught by a counter -- every ratchet here is a
#     FLOOR and contamination only ever SATISFIES a floor.
#   * M14 is the ORACLE degenerating to a constant.
#
# ⭐⭐ M15, M16 AND M17 ARE THIS LEVER'S OWN, AND THEY EXIST BECAUSE OF SECTION 5.
# This lever's honesty rests on a measured ZERO -- arming changes the branch's
# outcome on 0 rows -- taken over a 13-row candidate population. A zero is the
# easiest thing in this suite to make meaningless without touching a single
# assertion:
#   * M15 removes `X.CanAttackTogether(bot)` from the branch. The zero is then a
#     statement about a conjunct that is no longer standing beside the guard --
#     and the branch has quietly become reachable. Only 5c's ordering check can
#     see it.
#   * M16 and M17 drift the REPLICATION's constants (ALLY_RADIUS, INNER_LEVEL)
#     in the test. The zero then measures a different predicate than the shipped
#     one while every ratchet stays satisfied, because they are all floors and a
#     wider radius only ADDS rows. This is why section 5b builds its pinned
#     terms FROM those constants instead of typing them out -- the literal list
#     the first draft had would have SURVIVED both.
#
# ⛔ ONE SUBSTITUTION IS DELIBERATELY NOT ON THIS BENCH, and saying so is part of
# the reading. Swapping the drive's raw `h:GetNearbyHeroes` for the J-filtered
# `J.GetNearbyHeroes` would SURVIVE -- and that is not a hole, it is section 4d's
# declared bound: the two producers return identical lists on every frame in this
# corpus (jfilter_differs == 0). Putting it on the bench would score a hole the
# file already declares. The day a fixture tells them apart, 4d goes red first.
#
# Usage: bash tools/agent/mutstand_lvlgroup.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_team_roam_generic.lua
TEST=tests/test_lvlgroup_group_push_level_quantifier.lua
MOCK=tests/mock/replay_fixture.lua

FILES=("$SRC" "$TEST" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lvlgroup.XXXXXX")
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
    lua5.1 tests/run_tests.lua lvlgroup > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous.
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
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ANCHOR PROBLEM -- stand aborted rather than scoring a no-op"
        exit 2
    fi
}

GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlgroup\') then'
# The gate id is the only thing that tells this helper's loop apart from the two
# byte-identical ones above it.
HIT=$'\'lvlgroup\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return false end'
CALL=$'\t\tand X.NoNearbyEnemyAtLevelGroup(nNearbyEnemyHeroes, 12)'

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
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() then'
score "M1" "answers exactly what the shipped expression answers"

# ---------------------------------------------------------------------------
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "$GATE" $'\tif J.IsSoakCandidate(\'lvlgroup\') then'
score "M2" "the gate is not turbo-only"

# ---------------------------------------------------------------------------
# `if true then` and not a deletion: removing the gate line alone orphans its
# matching `end` and the file fails to LOAD -- red for a reason that has nothing
# to do with what M3 is asking (the tombhp M3 lesson, reused).
echo
echo "=== M3: the loop runs ungated ==="
sub "$SRC" "$GATE" $'\tif true then'
score "M3" "answers exactly what the shipped expression answers"

# ---------------------------------------------------------------------------
echo
echo "=== M4: the loop finds the dangerous hero and returns true anyway ==="
sub "$SRC" "$HIT" $'\'lvlgroup\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return true end'
score "M4" "sees the dangerous hero on every miss row"

# ---------------------------------------------------------------------------
echo
echo "=== M5: the loop body re-reads tHeroes[1] instead of tHeroes[i] ==="
sub "$SRC" "$HIT" $'\'lvlgroup\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[1]:GetLevel() >= nLevel then return false end'
score "M5" "sees the dangerous hero on every miss row"

# ---------------------------------------------------------------------------
echo
echo "=== M6: the gate is conjoined with a PROMOTED id (frozen FALSE) ==="
sub "$SRC" "$GATE" \
    $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlgroup\') and J.IsSoakCandidate(\'fight\') then'
score "M6" "soak candidates"

# ---------------------------------------------------------------------------
echo
echo "=== M7: the helper is gated on lvlcarry's id (the two sites bundle) ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlcarry\') then'
score "M7" "gate is gone from the helper"

# ---------------------------------------------------------------------------
echo
echo "=== M8: the drive runs at r=1600 instead of the shipped 650 ==="
sub "$TEST" "local SITE_RADIUS = 650" "local SITE_RADIUS = 1600"
score "M8" "stopped being the thing this lever is about"

# ---------------------------------------------------------------------------
echo
echo "=== M9: the call site stops asking the question ==="
sub "$SRC" "$CALL" $'\t\tand true'
score "M9" "may now be gating nothing"

# ---------------------------------------------------------------------------
echo
echo "=== M10: the remaining sibling is silently repaired (the baton shrinks) ==="
sub "$SRC" \
    $'\t\t  and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 10)' \
    $'\t\t  and X.NoNearbyEnemyAtLevelGroup(nNearbyEnemyHeroes, 10)'
score "M10" "un-repaired level-10"

# ---------------------------------------------------------------------------
echo
echo "=== M11: the list stops being distance-ordered (the premise itself) ==="
sub "$MOCK" \
    $'            table.sort(out, function(a, b)\n                local da, db = GetUnitToUnitDistance(self, a), GetUnitToUnitDistance(self, b)\n                if da == db then return a:GetUnitName() < b:GetUnitName() end\n                return da < db\n            end)' \
    $'            table.sort(out, function(a, b)\n                return a:GetUnitName() < b:GetUnitName()\n            end)'
score "M11" "came back out of distance order"

# ---------------------------------------------------------------------------
echo
echo "=== M12: the sweep reads allies instead of enemies ==="
sub "$TEST" \
    $'                    local list = h:GetNearbyHeroes(SITE_RADIUS, true,\n                        BOT_MODE_NONE)' \
    $'                    local list = h:GetNearbyHeroes(SITE_RADIUS, false,\n                        BOT_MODE_NONE)'
score "M12" "same-team hero in the enemy list"

# ---------------------------------------------------------------------------
echo
echo "=== M13: the producer stops excluding the asking hero ==="
sub "$MOCK" \
    $'                if other ~= self and v.alive' \
    $'                if v.alive'
score "M13" "put the asking hero in its own ALLY list"

# ---------------------------------------------------------------------------
echo
echo "=== M14: the shipped-expression oracle collapses to a constant ==="
sub "$TEST" \
    '    return (list[1] == nil) or (list[1]:GetLevel() < nLevel)' \
    '    return true'
score "M14" "satisfiable by a constant"

# ---------------------------------------------------------------------------
# ⭐ M15-M17: section 5's zero, which is what this lever's honesty rests on.
echo
echo "=== M15: X.CanAttackTogether leaves the branch (the zero loses its subject) ==="
sub "$SRC" $'\t\tand X.CanAttackTogether(bot)\n\t\t-- [lvlgroup 20260911]' \
    $'\t\t-- [lvlgroup 20260911]'
score "M15" "no longer inside the branch guarded by"

# ---------------------------------------------------------------------------
echo
echo "=== M16: the replication's ally radius drifts (1200 -> 1600) ==="
sub "$TEST" "local ALLY_RADIUS = 1200" "local ALLY_RADIUS = 1600"
score "M16" "X.CanAttackTogether no longer contains"

# ---------------------------------------------------------------------------
echo
echo "=== M17: the replication's inner level drifts (10 -> 12) ==="
sub "$TEST" "local INNER_LEVEL = 10" "local INNER_LEVEL = 12"
score "M17" "X.CanAttackTogether no longer contains"

# ---------------------------------------------------------------------------
echo
echo "=== stand: $CAUGHT/$TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND INCOMPLETE -- a surviving mutant is a hole in the test, not a pass"
exit 1
