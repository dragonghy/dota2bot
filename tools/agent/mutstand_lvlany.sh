#!/usr/bin/env bash
# Mutation stand for the `lvlany` lever (strategy desk 2026-09-10T22:xxZ).
# Not part of any suite -- run by hand when X.NoNearbyEnemyAtLevel in
# bots/mode_team_roam_generic.lua, its one call site, or
# tests/test_lvlany_first_member_level_quantifier.lua is edited.
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
#   * M1/M3 are the two shapes of "the gate stops holding the change back". M1
#     drops the candidate check; M3 lifts the loop out of the gate entirely.
#     Both make the UNARMED leg fire, which is the one thing a gated fix must
#     never do, and 3b is the only section that can see it.
#   * M2 is the narrower half: turbo-only dropped, candidate kept.
#   * M4 and M5 are the two ways the armed leg can look repaired and not be.
#     M4 flips the loop's answer; M5 keeps the loop and re-reads `[1]` inside
#     it, which leaves every structural pin in section 6 green.
#   * M6 is the pullcad trap (AGENTS.md): conjoining an already-PROMOTED id
#     freezes the gate FALSE forever, because a promoted id is in no armed
#     string. `fight` is a real promoted id.
#   * M7 is the vacuum this particular corpus can fall into. Unlike the two
#     rounds before it, the producer here (bot:GetNearbyHeroes, restored by the
#     loader with a team comparison) DOES carry enemy semantics -- which is what
#     lets sections 1-3 be about enemies at all. M7 asks the sweep for ALLIES
#     instead. Every ratchet in this file is a FLOOR, so a wrong-side list could
#     satisfy all of them; only the zero claim in 4a can see it.
#   * M8 moves the drive cell: 750 and 10 are the SHIPPED constants, read off
#     the call site, not chosen for a nice number.
#   * M9 is the FORBIDDEN DIRECTION: leave the helper alone and rewrite the
#     CALLER so nothing asks the question. Every behavioural assertion about the
#     helper stays green while the lever gates nothing at all.
#   * M10 is the BATON eroding. Section 7 pins the three sibling sites that this
#     work unit deliberately did NOT touch. If one is quietly repaired (or
#     quietly deleted), the report's "three more" becomes false while nothing
#     else in the file notices. This is the GH #13 shape written as an
#     assertion.
#   * M11 is the premise itself. This lever's whole argument is that `[1]` is
#     CORRECTLY the nearest and the guard is wrong anyway -- that is what makes
#     it a different finding from 'anyhero' rather than a second copy of it. If
#     the list stops being distance-ordered, the argument silently downgrades to
#     the weaker one. 1b has to notice.
#
# Usage: bash tools/agent/mutstand_lvlany.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_team_roam_generic.lua
TEST=tests/test_lvlany_first_member_level_quantifier.lua
MOCK=tests/mock/replay_fixture.lua

FILES=("$SRC" "$TEST" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lvlany.XXXXXX")
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
    lua5.1 tests/run_tests.lua lvlany > "$WORK/run.log" 2>&1
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

GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlany\') then'
HIT=$'\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return false end'
LOOP=$'\t\tfor i = 1, #tHeroes do'
CALL='    and X.NoNearbyEnemyAtLevel(nNearbyEnemyHeroes, 10)'

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
score "M1" "exactly what the shipped expression answers"

# ---------------------------------------------------------------------------
# M2: turbo-only dropped, candidate check kept -- the narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "$GATE" $'\tif J.IsSoakCandidate(\'lvlany\') then'
score "M2" "the gate is not turbo-only"

# ---------------------------------------------------------------------------
# M3: the loop is lifted OUT of the gate -- the change ships to every game.
echo
echo "=== M3: the loop runs ungated ==="
# `if true then` and not a deletion: removing the gate line alone orphans its
# matching `end`, and the file then fails to LOAD -- red, but for a reason that
# has nothing to do with what M3 is asking. (This is the tombhp M3 lesson,
# reused here rather than relearned.)
sub "$SRC" "$GATE" $'\tif true then'
score "M3" "exactly what the shipped expression answers"

# ---------------------------------------------------------------------------
# M4: the armed leg is present, gated, loops -- and answers the wrong way.
echo
echo "=== M4: the loop finds the dangerous hero and returns true anyway ==="
sub "$SRC" "$HIT" $'\t\t\tif tHeroes[i]:GetLevel() >= nLevel then return true end'
score "M4" "somebody IS over the bar"

# ---------------------------------------------------------------------------
# M5: the loop is there, the gate is there, and it re-reads [1] every time.
# Every structural pin in section 6 stays green; only the drive can see this.
echo
echo "=== M5: the loop body re-reads tHeroes[1] instead of tHeroes[i] ==="
sub "$SRC" "$HIT" $'\t\t\tif tHeroes[1]:GetLevel() >= nLevel then return false end'
score "M5" "somebody IS over the bar"

# ---------------------------------------------------------------------------
# M6: the pullcad trap -- conjoin an id that is already PROMOTED.
echo
echo "=== M6: the gate is conjoined with a PROMOTED id (frozen FALSE) ==="
sub "$SRC" "$GATE" \
    $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlany\') and J.IsSoakCandidate(\'fight\') then'
score "M6" "soak candidates"

# ---------------------------------------------------------------------------
# M7: the sweep asks for ALLIES. bots/ is untouched; the measurement quietly
# stops being about enemies while every floor in the file is still satisfied.
echo
echo "=== M7: the sweep reads the wrong side of the map ==="
sub "$TEST" \
    $'                    local list = J.GetNearbyHeroes(h, SITE_RADIUS, true,\n                        BOT_MODE_NONE)' \
    $'                    local list = J.GetNearbyHeroes(h, SITE_RADIUS, false,\n                        BOT_MODE_NONE)'
score "M7" "same-team hero in the enemy list"

# ---------------------------------------------------------------------------
# M8: the drive cell moves. 750 and 10 are read off the shipped call site.
echo
echo "=== M8: the drive runs at r=1600 instead of the shipped 750 ==="
sub "$TEST" "local SITE_RADIUS = 750" "local SITE_RADIUS = 1600"
score "M8" "stopped being the thing this lever is about"

# ---------------------------------------------------------------------------
# M9: the FORBIDDEN DIRECTION -- the helper is perfect and nobody calls it.
echo
echo "=== M9: the call site stops asking the question ==="
sub "$SRC" "$CALL" "    and true"
score "M9" "may now be gating nothing"

# ---------------------------------------------------------------------------
# M10: the baton erodes -- one of the three untouched siblings is quietly
# repaired. The report and the GH issue both say "three more"; only section 7
# can tell the next round that the number moved.
echo
echo "=== M10: a sibling site is silently repaired (the baton shrinks) ==="
sub "$SRC" \
    $'\t\tand X.CanAttackTogether(bot)\n\t\tand (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 12)' \
    $'\t\tand X.CanAttackTogether(bot)\n\t\tand X.NoNearbyEnemyAtLevel(nNearbyEnemyHeroes, 12)'
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
echo
echo "=== stand: $CAUGHT/$TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND INCOMPLETE -- a surviving mutant is a hole in the test, not a pass"
exit 1
