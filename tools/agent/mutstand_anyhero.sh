#!/usr/bin/env bash
# Mutation stand for the `anyhero` lever (strategy desk 2026-09-10).
# Not part of any suite -- run by hand when X.IsHeroWithinRadius in
# bots/FunLib/aba_special_units.lua, its one caller, or
# tests/test_anyhero_first_member_quantifier.lua is edited.
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
#   * M7 is THE ONE THIS LEVER NEEDS AND tombhp's STAND HAD NO ANALOGUE FOR.
#     The corpus enemy list contains the asking hero at distance 0 (section 4a),
#     so the self-exclusion in the sweep is not tidying -- it is what makes the
#     measurement mean anything.
#     ⚠️ THIS ENTRY CLAIMED THE WRONG MECHANISM UNTIL THE STAND DISPROVED IT,
#     and the correction is the useful part. The claim was "remove the exclusion
#     and the miss population EMPTIES, so the drive runs on nothing". M7
#     SURVIVED (exit 0, all 14 green) and the mutant was right: with self in the
#     list `best` is 0, so the misses and every other count go UP, not down --
#     and every count in this file is a cs.ratchet, i.e. a FLOOR. Contamination
#     can only ever satisfy a floor. The measurement did not collapse loudly, it
#     kept passing while quietly meaning "the bot is near itself".
#     What catches it is therefore not a ratchet at all but a ZERO claim
#     (`best_zero == 0` in section 1a): two distinct hero handles at distance 0
#     is not geometry. That is the same doctrine corpus_scale.lua already states
#     -- "a claim whose whole content is a zero stays an equality" -- arrived at
#     from the other end, by a surviving mutant.
#   * M8 moves the drive radius: 470 was measured, not chosen.
#   * M9 is the FORBIDDEN DIRECTION: leave the helper alone and rewrite the
#     CALLER so nothing asks the question. Every behavioural assertion about the
#     helper stays green while the lever gates nothing at all.
#   * M10 does not touch bots/ either -- it puts a sort into the producer, which
#     is the one change that would make the shipped `[1]` correct and this whole
#     lever unnecessary. It must not pass quietly.
#
# Usage: bash tools/agent/mutstand_anyhero.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/aba_special_units.lua
JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_anyhero_first_member_quantifier.lua

FILES=("$SRC" "$JMZ" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_anyhero.XXXXXX")
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
    lua5.1 tests/run_tests.lua anyhero > "$WORK/run.log" 2>&1
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

GATE="    if J.IsModeTurbo() and J.IsSoakCandidate('anyhero') then"
LOOP="        for i = 2, #tUnits do"
HIT="            if J.IsValidHero(tUnits[i]) and J.IsInRange(bot, tUnits[i], nRadius) then"

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
sub "$SRC" "$GATE" "    if J.IsModeTurbo() then"
score "M1" "and it answers false -- exactly what shipped answers"

# ---------------------------------------------------------------------------
# M2: turbo-only dropped, candidate check kept -- the narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "$GATE" "    if J.IsSoakCandidate('anyhero') then"
score "M2" "the gate is not turbo-only"

# ---------------------------------------------------------------------------
# M3: the loop is lifted OUT of the gate -- the change ships to every game.
echo
echo "=== M3: the loop runs ungated ==="
# `if true then` and not a deletion: removing the gate line alone orphans its
# matching `end`, and the file then fails to LOAD -- red, but for a reason that
# has nothing to do with what M3 is asking.
sub "$SRC" "$GATE" "    if true then"
score "M3" "and it answers false -- exactly what shipped answers"

# ---------------------------------------------------------------------------
# M4: the armed leg is present, gated, loops -- and answers the wrong way.
echo
echo "=== M4: the loop finds the hero and returns false ==="
sub "$SRC" "$HIT"$'\n'"                return true" "$HIT"$'\n'"                return false"
score "M4" "and it answers true on every row where a hero IS inside the radius"

# ---------------------------------------------------------------------------
# M5: the loop is there, the gate is there, and it re-reads [1] every time.
# Every structural pin in section 6 stays green; only the drive can see this.
echo
echo "=== M5: the loop body re-reads tUnits[1] instead of tUnits[i] ==="
sub "$SRC" "$HIT" \
    "            if J.IsValidHero(tUnits[1]) and J.IsInRange(bot, tUnits[1], nRadius) then"
score "M5" "and it answers true on every row where a hero IS inside the radius"

# ---------------------------------------------------------------------------
# M6: the pullcad trap -- conjoin an id that is already PROMOTED.
echo
echo "=== M6: the gate is conjoined with a PROMOTED id (frozen FALSE) ==="
sub "$SRC" "$GATE" \
    "    if J.IsModeTurbo() and J.IsSoakCandidate('anyhero') and J.IsSoakCandidate('fight') then"
score "M6" "soak gates, expected 1"

# ---------------------------------------------------------------------------
# M7: the sweep stops removing the asking hero from its own enemy list.
# bots/ is untouched; the MEASUREMENT collapses into a vacuum.
echo
echo "=== M7: the sweep keeps the asking hero in the list (self at distance 0) ==="
sub "$TEST" "                        if raw[i] ~= h then list[#list + 1] = raw[i] end" \
            "                        if true then list[#list + 1] = raw[i] end"
score "M7" "row(s) put a \"different\" hero at distance 0"

# ---------------------------------------------------------------------------
# M8: the drive radius moves -- 470 was measured, not chosen.
echo
echo "=== M8: the drive runs at r=1200 instead of the measured 470 ==="
sub "$TEST" "                        local R = 470" "                        local R = 1200"
score "M8" "rows driven at r=470 FELL"

# ---------------------------------------------------------------------------
# M9: the FORBIDDEN DIRECTION -- the helper is left alone and the CALLER is
# rewritten so nothing asks the question. The lever gates nothing; sections 1-4
# and 6 all stay green.
echo
echo "=== M9: the caller stops asking (the lever is orphaned) ==="
sub "$SRC" "                    if not X.IsHeroWithinRadius(tEnemyHeroes, botAttackRange - 130)" \
           "                    if #tEnemyHeroes == 0"
score "M9" "no longer reads X.IsHeroWithinRadius(tEnemyHeroes, botAttackRange - 130)"

# ---------------------------------------------------------------------------
# M10: the producer starts sorting. This is the ONE change that would make the
# shipped `[1]` read correct -- and it must not land silently, because it
# retires this lever rather than confirming it.
echo
echo "=== M10: J.GetEnemiesNearLoc sorts its result ==="
# Anchored on the arc-warden line, which is unique to GetEnemiesNearLoc -- the
# cache comment and `return enemies` each occur three times in this file, and
# the stand ABORTED rather than mutate the wrong function.
sub "$JMZ" $'\t\tand not enemyHero:HasModifier(\'modifier_arc_warden_tempest_double\')\n\t\tthen\n\t\t\ttable.insert(enemies, enemyHero)\n\t\tend\n\tend' \
           $'\t\tand not enemyHero:HasModifier(\'modifier_arc_warden_tempest_double\')\n\t\tthen\n\t\t\ttable.insert(enemies, enemyHero)\n\t\tend\n\tend\n\n\ttable.sort(enemies, function(a, b)\n\t\treturn GetUnitToLocationDistance(a, vLoc) < GetUnitToLocationDistance(b, vLoc)\n\tend)'
score "M10" "now sorts its result"

# ---------------------------------------------------------------------------
echo
echo "=== STAND: $CAUGHT of $TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED -- at least one mutant the tests cannot see"
exit 1
