#!/usr/bin/env bash
# Mutation stand for the `lvlcarry` lever (strategy desk 2026-09-11T0x:xxZ).
# Not part of any suite -- run by hand when X.NoNearbyEnemyAtLevelCarry in
# bots/mode_team_roam_generic.lua, its one call site, or
# tests/test_lvlcarry_carry_deny_level_quantifier.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ ANCHORS HERE CARRY THE GATE LINE ABOVE THEM, AND THAT IS THE ONE THING THIS
# STAND LEARNED THAT 'lvlany'S DID NOT HAVE TO. This lever's helper is a
# deliberate near-duplicate of X.NoNearbyEnemyAtLevel -- same loop, same
# comparison, different id -- so the bare body lines now occur TWICE in $SRC.
# A bare anchor would make `sub` abort as AMBIGUOUS (which is the right failure,
# but it is a failure), and a stand that aborts scores nothing. The gate id is
# what disambiguates. The same edit was made to mutstand_lvlany.sh in the same
# commit, for the same reason and in the other direction.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while leaving
# the defect, or while quietly meaning something else:
#   * M1/M3 are the two shapes of "the gate stops holding the change back". M1
#     drops the candidate check; M3 lifts the loop out of the gate entirely.
#     Both make the UNARMED leg fire, which is the one thing a gated fix must
#     never do. 3b is the only section that can see it -- and here it sees it
#     over all 1306 live rows, not over the 2 the lever changes.
#   * M2 is the narrower half: turbo-only dropped, candidate kept.
#   * M4 and M5 are the two ways the armed leg can look repaired and not be.
#     M4 flips the loop's answer; M5 keeps the loop and re-reads `[1]` inside
#     it, which leaves every structural pin in section 6 green.
#   * M6 is the pullcad trap (AGENTS.md): conjoining an already-PROMOTED id
#     freezes the gate FALSE forever, because a promoted id is in no armed
#     string. `fight` is a real promoted id.
#   * ⭐ M7 IS THIS LEVER'S OWN FAILURE MODE and has no counterpart in the
#     'lvlany' stand: point this helper's gate at 'lvlany'. The two call sites
#     then arm and disarm TOGETHER, which is the lanefix bundling (gpm -74.5,
#     then -88.7, 0/4 comps) rebuilt by hand -- and every behavioural assertion
#     in sections 1-4 stays green, because the helper still does the right thing
#     when it is armed. Only section 6 can see whose id it is.
#   * M8 moves the drive cell: 650 and 12 are the SHIPPED constants, read off
#     the call site, not chosen for a nice number. They are also what makes this
#     a different measurement from 'lvlany' (7 miss rows there, 2 here).
#   * M9 is the FORBIDDEN DIRECTION: leave the helper alone and rewrite the
#     CALLER so nothing asks the question. Every behavioural assertion about the
#     helper stays green while the lever gates nothing at all.
#   * M10 is the BATON eroding: one of the TWO remaining siblings is quietly
#     repaired, with no id, no test and no line in any report. This is the GH #13
#     shape written as an assertion.
#   * M11 is the premise itself -- shared with 'lvlany' and worth paying for
#     twice. The whole argument is that `[1]` is CORRECTLY the nearest and the
#     guard is wrong anyway. If the list stops being distance-ordered, the
#     argument silently downgrades to the weaker 'anyhero' one.
#   * M12 and M13 are the two halves of "the corpus quietly stopped being about
#     the right set of heroes". M12 asks the sweep for ALLIES where it wants
#     enemies; M13 breaks the producer's self-exclusion. Neither can be caught
#     by a counter -- every ratchet in a file like this is a FLOOR, and
#     contamination only ever SATISFIES a floor (that is the lesson 'anyhero'
#     paid for when its own M7 SURVIVED). Only the zero-equalities in 4a can see
#     them, and M13 is why 4a has an ALLY-side one: see the note at M13.
#   * ⭐ M14 is the ORACLE degenerating. Section 3b compares the helper against
#     shipped_answer(), a hand-written copy of the shipped expression. If that
#     copy collapses to a constant `true`, "matches shipped" is satisfied by any
#     helper that always answers true and the section is green and empty. This
#     is why 3b asserts `shipped_true < drives` FIRST, before the comparison.
#
# ⛔ ONE SUBSTITUTION IS DELIBERATELY NOT ON THIS BENCH, and saying so is part of
# the reading. Swapping the drive's raw `h:GetNearbyHeroes` for the J-filtered
# `J.GetNearbyHeroes` would SURVIVE -- and that is not a hole, it is section 4d's
# claim: the two producers return identical lists on every frame in this corpus
# (jfilter_differs == 0), so no assertion here can depend on which one is read.
# Putting it on the bench would score a hole that the file already declares as a
# bound. The day a fixture can tell them apart, 4d goes red first.
#
# Usage: bash tools/agent/mutstand_lvlcarry.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_team_roam_generic.lua
TEST=tests/test_lvlcarry_carry_deny_level_quantifier.lua
MOCK=tests/mock/replay_fixture.lua

FILES=("$SRC" "$TEST" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lvlcarry.XXXXXX")
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
    lua5.1 tests/run_tests.lua lvlcarry > "$WORK/run.log" 2>&1
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

GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlcarry\') then'
# See the ANCHORS note at the top: the gate id is the only thing that tells this
# helper's loop apart from X.NoNearbyEnemyAtLevel's byte-identical one.
HIT=$'\'lvlcarry\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return false end'
CALL=$'\t\tand X.NoNearbyEnemyAtLevelCarry(nNearbyEnemyHeroes, 12)'

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
# M1: the candidate check is dropped -- a defaults change wearing a gate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() then'
score "M1" "answers exactly what the shipped expression answers"

# ---------------------------------------------------------------------------
# M2: turbo-only dropped, candidate check kept -- the narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "$GATE" $'\tif J.IsSoakCandidate(\'lvlcarry\') then'
score "M2" "the gate is not turbo-only"

# ---------------------------------------------------------------------------
# M3: the loop is lifted OUT of the gate -- the change ships to every game.
echo
echo "=== M3: the loop runs ungated ==="
# `if true then` and not a deletion: removing the gate line alone orphans its
# matching `end`, and the file then fails to LOAD -- red, but for a reason that
# has nothing to do with what M3 is asking (the tombhp M3 lesson, reused).
sub "$SRC" "$GATE" $'\tif true then'
score "M3" "answers exactly what the shipped expression answers"

# ---------------------------------------------------------------------------
# M4: the armed leg is present, gated, loops -- and answers the wrong way.
echo
echo "=== M4: the loop finds the dangerous hero and returns true anyway ==="
sub "$SRC" "$HIT" $'\'lvlcarry\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return true end'
score "M4" "sees the dangerous hero on every miss row"

# ---------------------------------------------------------------------------
# M5: the loop is there, the gate is there, and it re-reads [1] every time.
# Every structural pin in section 6 stays green; only the drive can see this.
echo
echo "=== M5: the loop body re-reads tHeroes[1] instead of tHeroes[i] ==="
sub "$SRC" "$HIT" $'\'lvlcarry\') then\n\t\tfor i = 1, #tHeroes do\n\t\t\tif tHeroes[1]:GetLevel() >= nLevel then return false end'
score "M5" "sees the dangerous hero on every miss row"

# ---------------------------------------------------------------------------
# M6: the pullcad trap -- conjoin an id that is already PROMOTED.
echo
echo "=== M6: the gate is conjoined with a PROMOTED id (frozen FALSE) ==="
sub "$SRC" "$GATE" \
    $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlcarry\') and J.IsSoakCandidate(\'fight\') then'
score "M6" "soak candidates"

# ---------------------------------------------------------------------------
# M7: THIS LEVER'S OWN FAILURE MODE -- the two sites share one id and therefore
# arm together. The lanefix bundle, rebuilt by hand.
echo
echo "=== M7: the helper is gated on lvlany's id (the two sites bundle) ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlany\') then'
score "M7" "gate is gone from the helper"

# ---------------------------------------------------------------------------
# M8: the drive cell moves. 650 and 12 are read off the shipped call site.
echo
echo "=== M8: the drive runs at r=1600 instead of the shipped 650 ==="
sub "$TEST" "local SITE_RADIUS = 650" "local SITE_RADIUS = 1600"
score "M8" "stopped being the thing this lever is about"

# ---------------------------------------------------------------------------
# M9: the FORBIDDEN DIRECTION -- the helper is perfect and nobody calls it.
echo
echo "=== M9: the call site stops asking the question ==="
sub "$SRC" "$CALL" $'\t\tand true'
score "M9" "may now be gating nothing"

# ---------------------------------------------------------------------------
# M10: the baton erodes -- one of the TWO remaining siblings is quietly
# repaired, with no id, no test and no line in any report.
echo
echo "=== M10: a sibling site is silently repaired (the baton shrinks) ==="
sub "$SRC" \
    $'\t\tand X.CanAttackTogether(bot)\n\t\tand (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 12)' \
    $'\t\tand X.CanAttackTogether(bot)\n\t\tand X.NoNearbyEnemyAtLevelCarry(nNearbyEnemyHeroes, 12)'
score "M10" "un-repaired"

# ---------------------------------------------------------------------------
# M11: the PREMISE. If these lists stop being distance-ordered, `[1]` is no
# longer "correctly the nearest" and this stops being a different finding from
# 'anyhero'. 1b must refuse rather than let the weaker argument stand in.
echo
echo "=== M11: the list stops being distance-ordered (the premise itself) ==="
sub "$MOCK" \
    $'            table.sort(out, function(a, b)\n                local da, db = GetUnitToUnitDistance(self, a), GetUnitToUnitDistance(self, b)\n                if da == db then return a:GetUnitName() < b:GetUnitName() end\n                return da < db\n            end)' \
    $'            table.sort(out, function(a, b)\n                return a:GetUnitName() < b:GetUnitName()\n            end)'
score "M11" "came back out of distance order"

# ---------------------------------------------------------------------------
# M12: the sweep reads the wrong side of the map. bots/ is untouched; the
# measurement quietly stops being about enemies while every FLOOR is satisfied.
echo
echo "=== M12: the sweep reads allies instead of enemies ==="
sub "$TEST" \
    $'                    local list = h:GetNearbyHeroes(SITE_RADIUS, true,\n                        BOT_MODE_NONE)' \
    $'                    local list = h:GetNearbyHeroes(SITE_RADIUS, false,\n                        BOT_MODE_NONE)'
score "M12" "same-team hero in the enemy list"

# ---------------------------------------------------------------------------
# M13: the producer stops excluding the asking hero.
# ⭐ THIS MUTANT CHANGED THE TEST, WHICH IS WHAT A STAND IS FOR. First run it
# went red with the WRONG MESSAGE: the enemy-side equality in 4a never fired,
# because the mock rejects the asking hero a SECOND time on the team comparison
# (`isEnemy = other:GetTeam() ~= self:GetTeam()` is false for yourself), so the
# enemy list is byte-identical under this mutation. What actually moved was the
# ALLY list, and with it `#allies >= 2` -- i.e. exactly what section 7b's zero
# is a statement about. 4a grew an ally-side equality so the right file
# complains; scoring it "caught" on 7b's message would have been the stand
# lying about what was on the bench (evidence-discipline rule 4: a matching
# conclusion is not a correct reason).
echo
echo "=== M13: the producer stops excluding the asking hero ==="
sub "$MOCK" \
    $'                if other ~= self and v.alive' \
    $'                if v.alive'
score "M13" "put the asking hero in its own ALLY list"

# ---------------------------------------------------------------------------
# M14: the ORACLE degenerates to a constant. 3b then compares the helper against
# `true`, which any always-true helper satisfies.
echo
echo "=== M14: the shipped-expression oracle collapses to a constant ==="
sub "$TEST" \
    '    return (list[1] == nil) or (list[1]:GetLevel() < nLevel)' \
    '    return true'
score "M14" "satisfiable by a constant"

# ---------------------------------------------------------------------------
echo
echo "=== stand: $CAUGHT/$TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND INCOMPLETE -- a surviving mutant is a hole in the test, not a pass"
exit 1
