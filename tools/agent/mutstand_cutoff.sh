#!/usr/bin/env bash
# Mutation stand for the `cutoff` lever (strategy desk 2026-09-12).
# Not part of any suite -- run by hand when X.AheadOfEveryEnemyToAncient in
# bots/mode_retreat_generic.lua, its one call site inside X.ShouldRun, or
# tests/test_cutoff_retreat_ancient_race_quantifier.lua is edited.
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
#   * M4 and M5 are two ways the armed leg can look repaired and not be. M4
#     inverts the loop's answer; M5 keeps the loop and re-reads `[1]` inside it,
#     leaving every structural pin in section 6 green.
#   * M7 is the pullcad trap (AGENTS.md): conjoining an already-PROMOTED id
#     (`fight` is a real one) freezes the gate FALSE forever, while
#     check_armed_wiring.py still calls the lever WIRED. ⚠️ It is caught by the
#     site_miss RATCHET falling to 0, NOT by any gate-shaped assertion -- the
#     gate still READS right, it just can never be true. The first run of this
#     stand scored M7 as "RED with the wrong message" for exactly that reason,
#     and the fix was to name the ratchet, not to add a pin.
#   * M8 is the family's own failure mode: point this helper's gate at a SIBLING
#     id. The sites then arm and disarm TOGETHER -- the lanefix bundling
#     (gpm -74.5, then -88.7, 0/4 comps) rebuilt by hand -- while every
#     behavioural assertion stays green, because the helper still does the right
#     thing when it is armed. Only section 6 can see whose id it is.
#   * M9 is the FORBIDDEN DIRECTION: leave the helper alone, rewrite the CALLER
#     back to the old shape so nothing asks the question.
#   * M10 is the census eroding in the other direction -- a SECOND site written
#     in the old `GetDistanceFromAncient(nEnemyHeroes[k], ...)` shape after this
#     one was repaired.
#   * M11 and M12 are "the corpus quietly stopped being about the right set of
#     heroes". Neither can be caught by a counter -- every ratchet in the test
#     is a FLOOR and contamination only ever SATISFIES a floor, which is why
#     section 4c is written as two EQUALITIES.
#   * M13 is the test's own shipped-side ORACLE degenerating to a constant.
#   * M14 drifts the TEST's radius constant, so every count is taken at a cell
#     the shipped producer does not read while the floors stay satisfied.
#   * M15 is the premise section 4a pins: a sort appearing on the producer's
#     path would make `[1]` mean "the nearest" again, which is a DIFFERENT
#     (weaker) defect than the one this file argues.
#
# ⭐⭐ M6 IS THIS LEVER'S OWN, AND IT IS THE ONE THAT CHANGED THE TEST.
#   Relaxing the armed comparison from `>=` to `>` means a DEAD HEAT -- the bot
#   and a chaser exactly equidistant from the ancient -- stops counting as cut
#   off. That is not cosmetic: shipped's own comparison is the strict `<`, so on
#   such a member armed would be TRUE where shipped is FALSE, which is the
#   DIRECTION VIOLATION section 3c exists to forbid. M6 SURVIVED the first run:
#   these are float distances, so exact equality occurs on no row of this corpus
#   and on no corpus that could be built. The hole was real and the stand bought
#   it; the fix is the `>=` source pin now in section 4d, naming M6.
#
# ⭐ M16 IS THIS LEVER'S OWN TOO. The armed loop skips members that are not valid
#   heroes, and section 4d measures that this corpus has NO such member -- so no
#   row can tell a helper with the skip from one without it. M16 deletes the
#   skip: it must be caught by the SOURCE pin in section 4d and by nothing else,
#   and the stand exists to prove that the source pin is load-bearing rather
#   than decorative. If M16 ever starts being caught by a behavioural section,
#   the corpus grew an invalid member and section 4d should be rewritten.
#
# ⭐ M17 IS THE DIRECTION BOUND'S OWN ANCHOR. Starting the loop at i = 2 leaves
#   every other behaviour intact and is invisible to a reader -- but it is
#   exactly the edit that breaks `armed TRUE implies shipped TRUE`, because
#   `[1]` stops being evaluated. Section 3c is the assertion that has to see it.
#
# Usage: bash tools/agent/mutstand_cutoff.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_retreat_generic.lua
TEST=tests/test_cutoff_retreat_ancient_race_quantifier.lua
MOCK=tests/mock/replay_fixture.lua

FILES=("$SRC" "$TEST" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cutoff.XXXXXX")
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
    lua5.1 tests/run_tests.lua cutoff > "$WORK/run.log" 2>&1
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

GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'cutoff\') then'
LOOPHEAD=$'\t\tfor i = 1, #tHeroes do'
SKIP=$'\t\t\tif J.IsValidHero(tHeroes[i])\n\t\t\tand nBotDist >= J.GetDistanceFromAncient(tHeroes[i], false)\n\t\t\tthen'
CALL=$'        and X.AheadOfEveryEnemyToAncient(nEnemyHeroes, bot)'
SHIPPED=$'\treturn nBotDist < J.GetDistanceFromAncient(tHeroes[1], false)'

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
sub "$SRC" "$GATE" $'\tif J.IsSoakCandidate(\'cutoff\') then'
score "M2" "the lever is no longer turbo-only"

# `if true then` and not a deletion: removing the gate line alone orphans its
# matching `end` and the file fails to LOAD -- red for a reason that has nothing
# to do with what M3 is asking.
echo
echo "=== M3: the loop runs ungated ==="
sub "$SRC" "$GATE" $'\tif true then'
score "M3" "where the helper UNARMED disagrees"

echo
echo "=== M4: the armed loop answers the wrong way round ==="
sub "$SRC" $'\t\t\t\treturn false\n\t\t\tend\n\t\tend\n\t\treturn true' $'\t\t\t\treturn true\n\t\t\tend\n\t\tend\n\t\treturn false'
score "M4" "where the helper ARMED disagrees"

echo
echo "=== M5: the loop is there but still reads only the first member ==="
sub "$SRC" $'and nBotDist >= J.GetDistanceFromAncient(tHeroes[i], false)' \
           $'and nBotDist >= J.GetDistanceFromAncient(tHeroes[1], false)'
score "M5" "where the helper ARMED disagrees"

echo
echo "=== M6: a dead heat stops counting as cut off ==="
sub "$SRC" $'and nBotDist >= J.GetDistanceFromAncient(tHeroes[i], false)' \
           $'and nBotDist > J.GetDistanceFromAncient(tHeroes[i], false)'
score "M6" "no longer compares with >= against tHeroes[i]"

echo
echo "=== M7: the pullcad trap -- conjoin an already-PROMOTED id ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'cutoff\') and J.IsSoakCandidate(\'fight\') then'
score "M7" "rows where arming withdraws the race-home permission FELL to 0"

echo
echo "=== M8: the gate points at a SIBLING id (bundling by hand) ==="
sub "$SRC" "$GATE" $'\tif J.IsModeTurbo() and J.IsSoakCandidate(\'lvlhitcreep\') then'
score "M8" "the gate id cutoff is gone"

echo
echo "=== M9: the CALLER is written back to the old shape ==="
sub "$SRC" "$CALL" $'        and J.GetDistanceFromAncient(bot, false) < J.GetDistanceFromAncient(nEnemyHeroes[1], false)'
score "M9" "no longer reads"

echo
echo "=== M10: a SECOND site in the un-repaired shape ==="
sub "$SRC" "$CALL" $'        and X.AheadOfEveryEnemyToAncient(nEnemyHeroes, bot)\n        and J.GetDistanceFromAncient(bot, false) < J.GetDistanceFromAncient(nEnemyHeroes[2], false)'
score "M10" "un-repaired"

echo
echo "=== M11: the census stops excluding the observer from its own list ==="
sub "$TEST" $'                            and u:GetTeam() ~= h:GetTeam()\n                        then\n                            site[#site + 1] = u' \
            $'                            and (u:GetTeam() ~= h:GetTeam() or u == h)\n                        then\n                            site[#site + 1] = u'
score "M11" "carry the observer in its"

echo
echo "=== M12: the census stops splitting the two teams ==="
sub "$TEST" $'                            and u:GetTeam() ~= h:GetTeam()\n                        then\n                            site[#site + 1] = u' \
            $'                            and u ~= h\n                        then\n                            site[#site + 1] = u'
score "M12" "carry an ALLY in the enemy"

echo
echo "=== M13: the test's shipped-side oracle degenerates to a constant ==="
sub "$TEST" $'    return list[1] ~= nil\n        and J.GetDistanceFromAncient(hBot, false)\n            < J.GetDistanceFromAncient(list[1], false)' \
            $'    return list[1] ~= nil'
score "M13" "where the helper UNARMED disagrees"

echo
echo "=== M14: the TEST's radius constant drifts off the producer's ==="
sub "$TEST" $'local SITE_RADIUS = 1600' $'local SITE_RADIUS = 1200'
score "M14" "FELL to"

echo
echo "=== M15: a sort appears on the producer's path ==="
sub "$SRC" $'    local unitList = GetUnitList(UNIT_LIST_ALL)' \
           $'    local unitList = GetUnitList(UNIT_LIST_ALL)\n    table.sort(unitList, function(a, b) return a:GetHealth() < b:GetHealth() end)'
score "M15" "table.sort call(s) in"

echo
echo "=== M16: the armed loop's invalid-member skip is deleted ==="
sub "$SRC" "$SKIP" $'\t\t\tif nBotDist >= J.GetDistanceFromAncient(tHeroes[i], false)\n\t\t\tthen'
score "M16" "no longer skips invalid members"

echo
echo "=== M17: the armed loop starts at i = 2, so [1] is never evaluated ==="
sub "$SRC" "$LOOPHEAD" $'\t\tfor i = 2, #tHeroes do'
score "M17" "no longer starts at i = 1"

echo
echo "=== M18: the unarmed leg silently becomes the armed answer ==="
sub "$SRC" "$SHIPPED" $'\treturn J.IsValidHero(tHeroes[1]) and nBotDist < J.GetDistanceFromAncient(tHeroes[1], false) and #tHeroes < 2'
score "M18" "where the helper UNARMED disagrees"

# ---------------------------------------------------------------------------
echo
echo "=============================================================="
echo "cutoff mutation stand: $CAUGHT/$TOTAL caught"
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
else
    echo "STAND RED -- at least one mutant the assertions cannot see"
    exit 1
fi
