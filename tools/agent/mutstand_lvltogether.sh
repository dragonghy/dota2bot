#!/usr/bin/env bash
# Mutation stand for the `lvltogether` lever (strategy desk 2026-09-11T2x:xxZ).
# Not part of any suite -- run by hand when X.NoNearbyEnemyAtLevelTogether in
# bots/mode_team_roam_generic.lua, its one call site inside X.CanAttackTogether,
# or tests/test_lvltogether_can_attack_together_level_quantifier.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ ANCHORS CARRY THE GATE LINE, AND BY NOW THERE ARE FOUR REASONS TO. $SRC
# holds FOUR byte-identical helper bodies (X.NoNearbyEnemyAtLevel, ...Carry,
# ...Group, ...Together) -- same loop, same comparison, different id. The gate id
# is the ONLY thing that disambiguates them, so every body anchor below carries
# it. A bare anchor would make `sub` abort as AMBIGUOUS, and a stand that aborts
# scores nothing.
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
#     'lvlgroup'. The sites then arm and disarm TOGETHER -- the lanefix bundling
#     (gpm -74.5, then -88.7, 0/4 comps) rebuilt by hand -- while every
#     behavioural assertion stays green, because the helper still does the right
#     thing when it is armed. Only section 6 can see whose id it is.
#   * M8 moves the drive cell; 600/10 are read off the shipped function.
#   * M9 is the FORBIDDEN DIRECTION: leave the helper alone, rewrite the CALLER
#     so nothing asks the question.
#   * M10 is the BATON eroding in the other direction -- a FIFTH site written in
#     the old `[1]` shape after the baton was declared empty. Section 7 is the
#     GH #13 shape (a baton that decays into a sentence nobody re-reads) as an
#     assertion, and it now has to catch additions, not only removals.
#   * M11 is the premise, shared with the three siblings and worth paying for a
#     fourth time: if the list stops being distance-ordered, `[1]` is no longer
#     "correctly the nearest" and the argument silently downgrades to the weaker
#     'anyhero' one.
#   * M12 and M13 are "the corpus quietly stopped being about the right set of
#     heroes". Neither can be caught by a counter -- every ratchet here is a
#     FLOOR and contamination only ever SATISFIES a floor.
#   * M14 is the ORACLE degenerating to a constant.
#
# ⭐⭐ M15-M19 ARE THIS LEVER'S OWN, AND THEY GUARD THE TWO THINGS THAT MAKE IT
# DIFFERENT FROM ITS SIBLINGS.
#   * Section 5's honesty rests on a measured ZERO plus an EQUALITY naming the
#     one conjunct that holds it. M15 removes `#allies >= 2` -- the zero then has
#     no subject AND the function has quietly become reachable; only 5b's term
#     pin and order check can see it. M16 and M17 drift the REPLICATION's
#     constants in the test, so the zero measures a different predicate while
#     every ratchet stays satisfied (they are all floors, and a wider radius only
#     ADDS rows). That is why 5b builds its pinned terms FROM this file's
#     constants instead of typing them out.
#   * Section 1's finding is that the SUBJECT is usually not the asking bot.
#     M18 breaks the ally-side ORACLE (armed widens instead of narrows) and must
#     be caught by 1b's direction assertion -- the one claim that survives the
#     zero. M19 rewrites a call site from (ally) to (bot): the tree then no
#     longer has the path section 1 measures, while section 1's counters (all
#     floors, taken from the corpus rather than the source) stay green. Only
#     5c's 3-of-4 split can see M19, which is why that split is pinned as a
#     number rather than as "at least one such site exists".
#
# ⛔ ONE SUBSTITUTION IS DELIBERATELY NOT ON THIS BENCH, and saying so is part of
# the reading. Swapping the drive's raw `h:GetNearbyHeroes` for the J-filtered
# `J.GetNearbyHeroes` would SURVIVE -- and that is not a hole, it is section 4d's
# declared bound: the two producers return identical lists on every frame in this
# corpus (jfilter_differs == 0). Putting it on the bench would score a hole the
# file already declares. The day a fixture tells them apart, 4d goes red first.
#
# Usage: bash tools/agent/mutstand_lvltogether.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_team_roam_generic.lua
TEST=tests/test_lvltogether_can_attack_together_level_quantifier.lua
MOCK=tests/mock/replay_fixture.lua

FILES=("$SRC" "$TEST" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lvltogether.XXXXXX")
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
    lua5.1 tests/run_tests.lua lvltogether > "$WORK/run.log" 2>&1
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

GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvltogether\') then'
# The gate id is the only thing that tells this helper's loop apart from the
# three byte-identical ones above it.
HIT=$'\'lvltogether\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return false end'
CALL=$'\t\t  and X.NoNearbyEnemyAtLevelTogether(nNearbyEnemyHeroes, 10)'
ALLY2=$'\t      and #allies >= 2\n'

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
sub "$SRC" "$GATE" $'\tif J.IsSoakCandidate(\'lvltogether\') then'
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
sub "$SRC" "$HIT" $'\'lvltogether\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return true end'
score "M4" "sees the dangerous hero on every miss row"

# ---------------------------------------------------------------------------
echo
echo "=== M5: the loop body re-reads tHeroes[1] instead of tHeroes[i] ==="
sub "$SRC" "$HIT" $'\'lvltogether\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[1]:GetLevel() >= nLevel then return false end'
score "M5" "sees the dangerous hero on every miss row"

# ---------------------------------------------------------------------------
echo
echo "=== M6: the gate is conjoined with a PROMOTED id (frozen FALSE) ==="
sub "$SRC" "$GATE" \
    $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvltogether\') and J.IsSoakCandidate(\'fight\') then'
score "M6" "soak candidates"

# ---------------------------------------------------------------------------
echo
echo "=== M7: the helper is gated on lvlgroup's id (the sites bundle) ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlgroup\') then'
score "M7" "gate is gone from the helper"

# ---------------------------------------------------------------------------
echo
echo "=== M8: the drive runs at r=1600 instead of the shipped 600 ==="
sub "$TEST" "local SITE_RADIUS = 600" "local SITE_RADIUS = 1600"
score "M8" "stopped being the thing this lever is about"

# ---------------------------------------------------------------------------
echo
echo "=== M9: the call site stops asking the question ==="
sub "$SRC" "$CALL" $'\t\t  and true'
score "M9" "may now be gating nothing"

# ---------------------------------------------------------------------------
echo
echo "=== M10: a FIFTH site is written in the old [1] shape (the baton refills) ==="
sub "$SRC" $'\t      and #allies >= 2\n\t\t  -- [lvltogether 20260911]' \
    $'\t      and #allies >= 2\n\t\t  and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 10)\n\t\t  -- [lvltogether 20260911]'
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
# ⭐ M15-M17: section 5's zero and the equality that names what holds it.
echo
echo "=== M15: \`#allies >= 2\` leaves the function (the zero loses its subject) ==="
sub "$SRC" "$ALLY2" ""
score "M15" "X.CanAttackTogether no longer contains"

# ---------------------------------------------------------------------------
echo
echo "=== M16: the replication's ally radius drifts (1200 -> 1600) ==="
sub "$TEST" "local ALLY_RADIUS = 1200" "local ALLY_RADIUS = 1600"
score "M16" "X.CanAttackTogether no longer contains"

# ---------------------------------------------------------------------------
echo
echo "=== M17: the replication's level drifts (10 -> 12) ==="
sub "$TEST" "local SITE_LEVEL = 10" "local SITE_LEVEL = 12"
score "M17" "X.CanAttackTogether no longer contains"

# ---------------------------------------------------------------------------
# ⭐ M18-M19: section 1, this lever's own finding (the subject is not the asker).
echo
echo "=== M18: the ally-side oracle WIDENS instead of narrowing ==="
sub "$TEST" \
    $'    for i = 1, #list do\n        if list[i]:GetLevel() >= nLevel then return false end\n    end\n    return true' \
    $'    for i = 1, #list do\n        if list[i]:GetLevel() >= nLevel then return true end\n    end\n    return true'
score "M18" "MORE co-attackers armed than"

# ---------------------------------------------------------------------------
echo
echo "=== M19: a call site stops passing an ally (section 1's path disappears) ==="
sub "$SRC" $'\t\tif X.IsValid(ally) and X.CanAttackTogether(ally)' \
    $'\t\tif X.IsValid(ally) and X.CanAttackTogether(bot)'
score "M19" "called with an ally at"

# ---------------------------------------------------------------------------
echo
echo "=== stand: $CAUGHT/$TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND INCOMPLETE -- a surviving mutant is a hole in the test, not a pass"
exit 1
