#!/usr/bin/env bash
# Mutation stand for tests/test_threatcreep_lane_tiebreak.lua -- soak candidate
# 'threatcreep', landed 2026-09-17.
#
# What is priced here is a TWO-WALL repair confined to ONE consumer:
#   WALL 1  aba_defend.WeightedEnemiesAroundLocation prices its units off
#           `unitState.enemyHeroes` (GetUnitList(Enemies) already filtered by
#           IsValidHero), so its creep rungs are unreachable and a creep weighs
#           nothing. The fix walks `unitState.enemyCreeps` into a PARALLEL sum.
#   WALL 2  a lane creep is priced 0.2 and a full wave is four of them, so
#           4 * 0.2 = 0.8 floors to 0 -- the same score an EMPTY lane gets. The
#           parallel sum is unfloored; `math.floor` and the shipped `count` are
#           left exactly as they are, because they still feed the
#           `creepWeight >= 2` base-threat re-arm and the ShouldDefend ladder.
# Only GetThreatenedLane's tie-break reads the parallel sum, and only when armed.
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate). Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP -- a failure of the
# stand, not a pass of the code (GH #846).
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.
#
# This stand does NOT write bots/Customize/soak_side.lua -- the test file arms
# the id by overriding J.IsSoakCandidate directly -- so it does not contend for
# that global inode (GH #229, GH #365 §3, GH #848).
#
# Usage: bash tools/agent/mutstand_threatcreep.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

DEF=bots/FunLib/aba_defend.lua
TS=typescript/bots/FunLib/aba_defend.ts
BAKD=$(mktemp)
BAKT=$(mktemp)
cp "$DEF" "$BAKD"
cp "$TS" "$BAKT"
SUMS=$(sha256sum "$DEF" "$TS")

restore() {
    cp "$BAKD" "$DEF"
    cp "$BAKT" "$TS"
    if [ "$(sha256sum "$DEF" "$TS")" != "$SUMS" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

check() {
    local name="$1" file="$2" needle="$3" want="$4" expect="$5"
    local got
    got=$(grep -c -- "$needle" "$file")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua threatcreep_lane_tiebreak >/dev/null 2>&1; then
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: SURVIVED -- the suite is green on a mutant"
            fails=$((fails + 1))
        else
            echo "  $name: SURVIVED (as intended -- control)"
        fi
    else
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: CAUGHT"
        else
            echo "  $name: RED -- the control mutant went red, so at least one"
            echo "        assertion is keyed to something it should not be"
            fails=$((fails + 1))
        fi
    fi
    restore
}

GATE='local bThreatCreep = jmz.IsSoakCandidate("threatcreep") and jmz.IsModeTurbo()'
PICK='(bThreatCreep and nWeightedRaw or nWeighted) \* 0.4,'
FLOOR='    count = math.floor(count)'
SEED='local bestScore = -1'

echo "== mutation stand: threatcreep lane tie-break =="

# T1  The lever is deleted: the tie-break goes back to the floored, hero-only
#     sum.  This is trunk exactly as it was, and the whole round says that
#     configuration answers Top on every hero-quiet frame.  If it survives,
#     nothing in the file is measuring the lever at all.
sed -i "s/$PICK/nWeighted * 0.4, -- MUT_T1/" "$DEF"
check "T1 the armed branch is deleted" "$DEF" "MUT_T1" 1 CAUGHT

# T2  ⭐ WALL 1 REPAIRED, WALL 2 LEFT STANDING -- the mutant that is the whole
#     reason these are one id.  The parallel sum is built (creeps counted) and
#     then floored before use, so a full four-creep wave weighs 0.8 and reads 0.
#     A stand without this leg would have let a NO-OP ship while every gate and
#     wiring census answered WIRED.
sed -i "s/$PICK/(bThreatCreep and math.floor(nWeightedRaw) or nWeighted) * 0.4, -- MUT_T2/" "$DEF"
check "T2 wall 2 left standing (parallel sum re-floored)" "$DEF" "MUT_T2" 1 CAUGHT

# T3  ⭐ WALL 2 REPAIRED, WALL 1 LEFT STANDING -- the mirror of T2, and the fix
#     this round STARTED with before the test caught it.  The parallel sum is
#     unfloored but never sees a creep, because the enemyCreeps loop is gone.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
head = '    local rawCount = count\n    for ____, unit in ipairs(unitState.enemyCreeps) do\n'
i = s.index(head)
j = s.index('\n    count = math.floor(count)\n', i)
s = s[:i] + '    local rawCount = count -- MUT_T3' + s[j:]
open(p, 'w').write(s)
PY
check "T3 wall 1 left standing (enemyCreeps loop removed)" "$DEF" "MUT_T3" 1 CAUGHT

# T4  The parallel sum is fed the WRONG list -- `enemyHeroes`, the very list
#     wall 1 is about.  Every unit there is already priced by the loop above, so
#     this double-counts heroes and still cannot see a creep: a change that
#     moves numbers without repairing anything.
#     ⛔ Edited through python, anchored on `local rawCount`: the same loop
#     header appears in ShouldDefend, and a bare sed rewrites BOTH -- which the
#     stand reported as a NO-OP (grep -c = 2) rather than scoring it. That
#     refusal is the point of the grep gate (GH #846).
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('    local rawCount = count\n')
old = 'for ____, unit in ipairs(unitState.enemyCreeps) do'
j = s.index(old, i)
s = s[:j] + 'for ____, unit in ipairs(unitState.enemyHeroes) do -- MUT_T4' + s[j + len(old):]
open(p, 'w').write(s)
PY
check "T4 parallel sum fed the hero list again" "$DEF" "MUT_T4" 1 CAUGHT

# T5  ⛔ THE RETAINED HALF, mutated.  `count` (floored, hero-only) is redirected
#     to the new sum, so the OTHER consumer -- the `creepWeight >= 2`
#     base-threat re-arm -- silently moves too.  That is the lanefix bundle
#     mistake in one line, and it is invisible to any leg that only asks what
#     GetThreatenedLane answered.
sed -i "s/^$FLOOR\$/    count = math.floor(rawCount) -- MUT_T5/" "$DEF"
check "T5 the retained floored sum is redirected" "$DEF" "MUT_T5" 1 CAUGHT

# T6  The lane-creep price moved 0.2 -> 1.0 in the new loop.  The arithmetic the
#     round rests on ("a full wave of four weighs 0.8") is FALSE at that price,
#     and the arithmetic leg is the only thing in the repo that would notice --
#     the bearing frame's answer moves either way.
sed -i "s/                rawCount = rawCount + 0.2/                rawCount = rawCount + 1.0 -- MUT_T6/" "$DEF"
check "T6 the 0.2 lane-creep price is moved" "$DEF" "MUT_T6" 1 CAUGHT

# T7  ⭐ The cap raised past a hero.  0.9 is what bounds this SELECTOR: one
#     visible enemy hero scores 10, so the capped creep term can never outrank
#     it.  At 99 the lever can pull the whole team off a lane that has a hero on
#     it -- caught only by the [bound] leg, whose stand-in deliberately works
#     against its own assertion.
sed -i "s/^                0.9\$/                99 -- MUT_T7/" "$DEF"
check "T7 the 0.9 cap raised past a hero" "$DEF" "MUT_T7" 1 CAUGHT

# T8  The seed order's tie-break inverted (`>` becomes `>=`), so an exact tie
#     now resolves to the LAST lane instead of the first.  Trunk's degenerate
#     answer changes identity without the lever being involved at all; the
#     no-creep control leg is what sees it.
sed -i "s/        if score > bestScore then/        if score >= bestScore then -- MUT_T8/" "$DEF"
check "T8 exact-tie resolution inverted" "$DEF" "MUT_T8" 1 CAUGHT

# T9  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'threatcreep' alone the lever no-ops, and the day that second id is
#     promoted the conjunct is frozen false forever while a wiring census still
#     answers WIRED.
sed -i "s/$GATE/local bThreatCreep = jmz.IsSoakCandidate(\"threatcreep\") and jmz.IsModeTurbo() and jmz.IsSoakCandidate(\"defclose\") -- MUT_T9/" "$DEF"
check "T9 gate conditioned on a second id" "$DEF" "MUT_T9" 1 CAUGHT

# T10 The turbo conjunct alone is dropped.  Every frame in this corpus is turbo,
#     so no leg driven on the corpus AS IT IS can see it; the leg that catches
#     it is the one that makes J.IsModeTurbo() report a non-turbo game.
sed -i "s/$GATE/local bThreatCreep = jmz.IsSoakCandidate(\"threatcreep\") -- MUT_T10/" "$DEF"
check "T10 turbo conjunct dropped" "$DEF" "MUT_T10" 1 CAUGHT

# T11 The `enemyHeroCnt == 0` guard is widened to `<= 1`, so the creep term now
#     also runs on a lane that HAS a visible hero.  The bound in T7 depends on
#     this guard as much as on the cap, and the answer on the bearing frame does
#     not have to move -- this is the verbatim source assertion or nothing.
sed -i "s/        if enemyHeroCnt == 0 then/        if enemyHeroCnt <= 1 then -- MUT_T11/" "$DEF"
check "T11 the hero-quiet guard is widened" "$DEF" "MUT_T11" 1 CAUGHT

# T12 The TypeScript source loses the enemyCreeps loop while the Lua keeps it.
#     aba_defend.lua is transpiler output; a Lua-only edit is reverted by the
#     next regeneration, silently and by someone who is not looking for it.
#     ⛔ Anchored on `let rawCount` for the same reason as T4: ShouldDefend's
#     TypeScript carries the identical loop header.
python3 - "$TS" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('    let rawCount = count;\n')
old = '    for (const unit of unitState.enemyCreeps) {'
j = s.index(old, i)
s = s[:j] + '    // MUT_T12\n    for (const unit of []) {' + s[j + len(old):]
open(p, 'w').write(s)
PY
check "T12 TypeScript source drifts from the Lua" "$TS" "MUT_T12" 1 CAUGHT

# T13 CONTROL.  A comment-only edit inside the block the lever lives in.  It
#     must SURVIVE: if the suite goes red here, some assertion is keyed to
#     comment text rather than to code or to a decision.  ⛔ Not decorative in
#     THIS family: last round a sibling test asserted over the whole file,
#     comments included, and an explanatory comment turned it red while the code
#     was untouched (0NEXT33 §乙).
sed -i 's/^-- ⭐ THE DEFECT IS TWO WALLS/-- (control edit) ⭐ THE DEFECT IS TWO WALLS/' "$DEF"
check "T13 CONTROL comment-only edit" "$DEF" "control edit" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "== all mutants CAUGHT, control SURVIVED =="
    exit 0
fi
echo "== $fails leg(s) failed =="
exit 1
