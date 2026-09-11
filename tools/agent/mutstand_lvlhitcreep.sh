#!/usr/bin/env bash
# Mutation stand for the `lvlhitcreep` lever (strategy desk 2026-09-11).
# Not part of any suite -- run by hand when X.AnyEnemyAtLevelHitCreep in
# bots/mode_team_roam_generic.lua, its one call site inside
# X.IsModeSuitToHitCreep, or
# tests/test_lvlhitcreep_suit_to_hit_creep_level_quantifier.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while leaving
# the defect, or while quietly meaning something else:
#   * M1/M3 are the two shapes of "the gate stops holding the change back"; M2
#     is the narrower half (turbo-only dropped, candidate kept). All three make
#     the UNARMED leg fire, which is the one thing a gated fix must never do.
#   * M4, M5 and M19 are the three ways the armed leg can look repaired and not
#     be. M4 inverts the loop's answer; M5 keeps the loop and re-reads `[1]`
#     inside it, leaving every structural pin in section 6 green; M19 drifts the
#     comparison by one rank.
#   * M6 is the pullcad trap (AGENTS.md): conjoining an already-PROMOTED id
#     (`fight` is a real one) freezes the gate FALSE forever, while
#     check_armed_wiring.py still calls the lever WIRED.
#   * M7 is the family's own failure mode: point this helper's gate at a SIBLING
#     id. The sites then arm and disarm TOGETHER -- the lanefix bundling
#     (gpm -74.5, then -88.7, 0/4 comps) rebuilt by hand -- while every
#     behavioural assertion stays green, because the helper still does the right
#     thing when it is armed. Only section 6a can see whose id it is.
#   * M8 and M18 drift the call site's two constants (level 8, the `>= 3` group
#     leg). Both move what section 5's 9 is a count OF while leaving it green:
#     every ratchet in the file is a FLOOR.
#   * M9 is the FORBIDDEN DIRECTION: leave the helper alone, rewrite the CALLER
#     back to the old shape so nothing asks the question.
#   * M10 is the census eroding in the other direction -- a SECOND site written
#     in the old `[1] >= N` shape after this one was repaired.
#   * M11 is the premise the whole family rests on: if the list stops being
#     distance-ordered, `[1]` is no longer "the nearest" and the argument
#     silently downgrades to a different, weaker one.
#   * M12 and M13 are "the corpus quietly stopped being about the right set of
#     heroes". Neither can be caught by a counter -- every ratchet here is a
#     FLOOR and contamination only ever SATISFIES a floor, which is why section
#     4a is written as two EQUALITIES.
#   * M14 is the test's own shipped-side ORACLE degenerating to a constant.
#   * M16 and M17 drift the TEST's constants, so every count is taken at a cell
#     the shipped function does not read, while the floors stay satisfied.
#
# ⭐⭐ M15 IS THIS LEVER'S OWN, AND IT IS THE ONE THAT CHANGED THE TEST.
#   Section 5 is this file's whole claim to being stronger than its four
#   siblings: the enclosing function's early return really moves, on 9 rows.
#   That count is produced by a REPLICATION of the shipped `if`, and the first
#   version of the test pinned only the flips and the partition sum. M15 deletes
#   the `#enemies >= 3` term from that replication -- and it SURVIVED: the
#   masked row is re-scored as a flip, so flips go 9 -> 10 (a floor, satisfied),
#   masked goes 1 -> 0, and the partition still sums to 10. The stand bought a
#   real hole, and the fix is a floor on the MASKED count, which is now in the
#   file with M15 named in its comment.
#
# Usage: bash tools/agent/mutstand_lvlhitcreep.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_team_roam_generic.lua
TEST=tests/test_lvlhitcreep_suit_to_hit_creep_level_quantifier.lua
MOCK=tests/mock/replay_fixture.lua

FILES=("$SRC" "$TEST" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lvlhitcreep.XXXXXX")
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
    lua5.1 tests/run_tests.lua lvlhitcreep > "$WORK/run.log" 2>&1
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

GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlhitcreep\') then'
LOOP=$'\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return true end\n\t\tend\n\t\treturn false'
CALL=$'    if #nEnemyHeroes >= 3 or X.AnyEnemyAtLevelHitCreep(nEnemyHeroes, 8) then'

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
score "M1" "where the helper UNARMED disagrees"

echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "$GATE" $'\tif J.IsSoakCandidate(\'lvlhitcreep\') then'
score "M2" "the helper lost its turbo-only guard"

# `if true then` and not a deletion: removing the gate line alone orphans its
# matching `end` and the file fails to LOAD -- red for a reason that has nothing
# to do with what M3 is asking.
echo
echo "=== M3: the loop runs ungated ==="
sub "$SRC" "$GATE" $'\tif true then'
score "M3" "where the helper UNARMED disagrees"

echo
echo "=== M4: the armed loop answers the wrong way round ==="
sub "$SRC" "$LOOP" $'\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return false end\n\t\tend\n\t\treturn true'
score "M4" "where the helper ARMED disagrees"

echo
echo "=== M5: the loop is there but still reads only the nearest ==="
sub "$SRC" "$LOOP" $'\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[1]:GetLevel() >= nLevel then return true end\n\t\tend\n\t\treturn false'
score "M5" "where the helper ARMED disagrees"

echo
echo "=== M19: the armed comparison drifts one rank (>= becomes >) ==="
sub "$SRC" "$LOOP" $'\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() > nLevel then return true end\n\t\tend\n\t\treturn false'
score "M19" "where the helper ARMED disagrees"

echo
echo "=== M6: the pullcad trap -- gate conjoined with a PROMOTED id ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlhitcreep\') and J.IsSoakCandidate(\'fight\') then'
score "M6" "the pullcad trap"

echo
echo "=== M7: the gate points at a SIBLING's id (the lanefix bundling) ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvltogether\') then'
score "M7" "the helper no longer gates on lvlhitcreep"

echo
echo "=== M8: the call site's LEVEL constant drifts (8 -> 10) ==="
sub "$SRC" "$CALL" $'    if #nEnemyHeroes >= 3 or X.AnyEnemyAtLevelHitCreep(nEnemyHeroes, 10) then'
score "M8" "no longer reads"

echo
echo "=== M18: the call site's GROUP leg drifts (>= 3 becomes >= 2) ==="
sub "$SRC" "$CALL" $'    if #nEnemyHeroes >= 2 or X.AnyEnemyAtLevelHitCreep(nEnemyHeroes, 8) then'
score "M18" "no longer reads"

echo
echo "=== M9: FORBIDDEN DIRECTION -- the caller reverts to the old shape ==="
sub "$SRC" "$CALL" $'    if #nEnemyHeroes >= 3 or (nEnemyHeroes[1] ~= nil and nEnemyHeroes[1]:GetLevel() >= 8) then'
score "M9" "no longer reads"

echo
echo "=== M10: a SECOND site written in the old \`[1] >= N\` shape ==="
sub "$SRC" "$CALL" $'    if nEnemyHeroes[1] ~= nil and nEnemyHeroes[1]:GetLevel() >= 25 then return false end\n    if #nEnemyHeroes >= 3 or X.AnyEnemyAtLevelHitCreep(nEnemyHeroes, 8) then'
score "M10" "un-repaired"

echo
echo "=== M11: the premise -- the list stops being distance-ordered ==="
sub "$MOCK" $'                if da == db then return a:GetUnitName() < b:GetUnitName() end\n                return da < db' \
    $'                if da == db then return a:GetUnitName() < b:GetUnitName() end\n                return da > db'
score "M11" "where some enemy is NEARER than"

echo
echo "=== M12: the producer stops excluding the asking hero ==="
# ⚠️ TWO SUBSTITUTIONS, AND THE REASON IS A MEASUREMENT, NOT A PREFERENCE.
# Dropping the `other ~= self` guard ALONE is a NO-OP on this path: the team
# split two lines below (`isEnemy = other:GetTeam() ~= self:GetTeam()`) already
# excludes self from every `enemies = true` query, so self never reaches the
# list either way. Measured before this bench line was written -- the full
# corpus census is byte-identical with and without that guard (all 11 counters,
# including site_miss and miss_flips). Scoring that single edit as SURVIVED
# would have recorded a hole in the TEST for a mutation that changes NOTHING,
# which is the stand lying in the direction nobody checks. So M12 also forces
# self to count as an enemy, which is what actually puts it in the list -- at
# distance 0, i.e. as `[1]`, which is precisely the element this lever is about.
sub "$MOCK" $'                if other ~= self and v.alive' $'                if v.alive'
sub "$MOCK" $'                    local isEnemy = other:GetTeam() ~= self:GetTeam()' \
    $'                    local isEnemy = other == self or other:GetTeam() ~= self:GetTeam()'
score "M12" "the asking hero is inside its"

echo
echo "=== M13: the producer stops splitting the teams ==="
sub "$MOCK" $'                    if (enemies and isEnemy) or (not enemies and not isEnemy) then' \
    $'                    if true then'
score "M13" "where an ALLY is inside the enemy list"

echo
echo "=== M14: the test's shipped-side ORACLE degenerates to a constant ==="
sub "$TEST" $'    return list[1] ~= nil and list[1]:GetLevel() >= nLevel\nend' \
    $'    return true\nend'
score "M14" "where the helper UNARMED disagrees"

echo
echo "=== M15: the replication drops the \`>= 3\` group leg ==="
sub "$TEST" $'    return #list >= GROUP_LEG or level_fn(list, SITE_LEVEL)' \
    $'    return level_fn(list, SITE_LEVEL)'
score "M15" "short-circuited FELL to"

echo
echo "=== M16: the TEST's radius constant drifts (750 -> 900) ==="
sub "$TEST" $'local SITE_RADIUS = 750' $'local SITE_RADIUS = 900'
score "M16" "the radius the whole census is taken at"

echo
echo "=== M17: the TEST's level constant drifts (8 -> 10) ==="
sub "$TEST" $'local SITE_LEVEL = 8' $'local SITE_LEVEL = 10'
score "M17" "no longer reads"

# ---------------------------------------------------------------------------
echo
echo "=== SCORE: $CAUGHT/$TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
else
    echo "STAND HAS HOLES -- read each SURVIVED line above before trusting the test"
    exit 1
fi
