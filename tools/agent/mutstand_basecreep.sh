#!/usr/bin/env bash
# Mutation stand for tests/test_basecreep_ancient_rearm.lua -- soak candidate
# 'basecreep', landed 2026-09-17.
#
# What is priced here is the SECOND consumer of the wall-1 list (charter
# 0NEXT35): aba_defend's base-threat top-up.
#   HALF 1  the top-up asks WeightedEnemiesAroundLocation for a "creep weight",
#           and that function prices off `unitState.enemyHeroes` -- already
#           IsValidHero-filtered -- so a creep weighs nothing. The repair reads
#           the PARALLEL sum [threatcreep] already built.
#   HALF 2  the assignment is `=`, not a max. The arm is reached only when
#           `heroesNearAncient == 0`, so the shipped weight is 0 except through
#           the <= 0.35s cache -- i.e. off a hero reading, on exactly the frames
#           where a pending `+BASE_THREAT_HOLD` is replaced by `+1.5` and the
#           hold is SHORTENED. The repair makes it math.max.
# Neither half ships alone (B2 / B3 below are that pair, made explicit), so the
# two are ONE id. [threatcreep]'s own consumer, the shipped `count`, and
# `math.floor` are untouched, and B5 / B6 price that.
#
# ⛔ [threatcreep] measured this same call site and called it a provable no-op.
# That was correct and was ONLY about WALL 2 -- `math.floor(x) >= 2` iff
# `x >= 2`. B4 is that no-op, kept as a mutant so the scope of that sentence
# cannot drift back to covering WALL 1.
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1). Each leg first proves the edit LANDED with
# grep -c, then runs the test; a mutant whose edit did not land is reported
# NO-OP -- a failure of the stand, not a pass of the code (GH #846).
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.
#
# This stand does NOT write bots/Customize/soak_side.lua -- the test arms the id
# by overriding J.IsSoakCandidate directly -- so it does not contend for that
# global inode (GH #229, GH #365 §3, GH #848).
#
# Usage: bash tools/agent/mutstand_basecreep.sh
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
    if lua5.1 tests/run_tests.lua basecreep_ancient_rearm >/dev/null 2>&1; then
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

GATE='local bBaseCreep = jmz.IsSoakCandidate("basecreep") and jmz.IsModeTurbo()'
PICK='if (bBaseCreep and creepWeightRaw or creepWeight) >= 2 then'
MAXL='baseThreatUntil = bBaseCreep and math.max(baseThreatUntil or -1, nTopUp) or nTopUp'

echo "== mutation stand: basecreep base-threat top-up =="

# B1  The lever is deleted: the top-up goes back to the shipped hero-only sum
#     with a bare assignment. This is trunk exactly as it was. If it survives,
#     nothing in the file measures the lever at all.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace(
    'if (bBaseCreep and creepWeightRaw or creepWeight) >= 2 then',
    'if creepWeight >= 2 then -- MUT_B1', 1)
s = s.replace(
    'baseThreatUntil = bBaseCreep and math.max(baseThreatUntil or -1, nTopUp) or nTopUp',
    'baseThreatUntil = nTopUp', 1)
open(p, 'w').write(s)
PY
check "B1 the armed reading is deleted" "$DEF" "MUT_B1" 1 CAUGHT

# B2  ⭐ HALF 1 ALONE -- the raw sum is read, the assignment stays a bare `=`.
#     This is the mutant that is the whole reason these are one id: it moves the
#     number, and it moves it in the one direction this branch forbids (a mega
#     wave at the ancient would cut a LIVE hero hold from +4 to +1.5).
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'baseThreatUntil = bBaseCreep and math.max(baseThreatUntil or -1, nTopUp) or nTopUp'
s = s.replace(old, 'baseThreatUntil = nTopUp -- MUT_B2', 1)
open(p, 'w').write(s)
PY
check "B2 half 1 alone (raw sum, bare assignment -- can shorten)" "$DEF" "MUT_B2" 1 CAUGHT

# B3  ⭐ HALF 2 ALONE -- the max is kept, the shipped hero-only sum is read. By
#     the closed form this is a NO-OP: the condition is false except on the
#     stale-cache frames, and there the pending value is the larger one. The
#     mirror of B2, and the other half of the "one id" argument.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'if (bBaseCreep and creepWeightRaw or creepWeight) >= 2 then'
s = s.replace(old, 'if creepWeight >= 2 then -- MUT_B3', 1)
open(p, 'w').write(s)
PY
check "B3 half 2 alone (max kept, hero-only sum -- a no-op)" "$DEF" "MUT_B3" 1 CAUGHT

# B4  ⛔ THE [threatcreep] NO-OP, KEPT AS A MUTANT. The raw sum is read and then
#     re-floored before the threshold. `math.floor(x) >= 2` iff `x >= 2`, so
#     this leg is genuinely equivalent AT THE THRESHOLD -- which is exactly the
#     sentence [threatcreep] proved, and exactly the sentence that hid WALL 1
#     here for a round. It is scored CAUGHT because the source ratchet pins the
#     expression, not because the arithmetic differs: the point of the leg is
#     that the scope of that sentence cannot drift back silently.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'if (bBaseCreep and creepWeightRaw or creepWeight) >= 2 then'
new = 'if (bBaseCreep and math.floor(creepWeightRaw) or creepWeight) >= 2 then -- MUT_B4'
s = s.replace(old, new, 1)
open(p, 'w').write(s)
PY
check "B4 wall 2 re-applied to the parallel sum (threshold-equivalent)" "$DEF" "MUT_B4" 1 CAUGHT

# B5  WALL 1 "repaired" in the SHIPPED sum instead: the hero loop is pointed at
#     enemyCreeps. That moves [threatcreep]'s consumer and the ShouldDefend
#     ladder in the same edit -- the lanefix mistake, one lever moving three
#     consumers.
#     ⛔ Anchored on `local count = 0` through python: the same loop header
#     appears in ShouldDefend and a bare sed rewrites BOTH.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('    local count = 0\n')
old = 'for ____, unit in ipairs(unitState.enemyHeroes) do'
j = s.index(old, i)
s = s[:j] + 'for ____, unit in ipairs(unitState.enemyCreeps) do -- MUT_B5' + s[j + len(old):]
open(p, 'w').write(s)
PY
check "B5 the shipped sum is pointed at the creep list" "$DEF" "MUT_B5" 1 CAUGHT

# B6  The parallel sum stops seeing creeps: the enemyCreeps loop is removed. The
#     gate still exists, the call site still binds two values, and
#     check_armed_wiring.py still answers WIRED -- a no-op that reads back as
#     "tested, no effect".
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
head = '    local rawCount = count\n    for ____, unit in ipairs(unitState.enemyCreeps) do\n'
i = s.index(head)
j = s.index('\n    count = math.floor(count)\n', i)
s = s[:i] + '    local rawCount = count -- MUT_B6' + s[j:]
open(p, 'w').write(s)
PY
check "B6 the parallel sum never sees a creep" "$DEF" "MUT_B6" 1 CAUGHT

# B7  The untouched threshold is lowered. `>= 2` is what keeps a BASIC wave
#     (4 * 0.2 = 0.8) from topping up base threat; at `>= 0.5` a single ranged
#     creep wandering into the base would hold the whole team at the ancient.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'if (bBaseCreep and creepWeightRaw or creepWeight) >= 2 then'
new = 'if (bBaseCreep and creepWeightRaw or creepWeight) >= 0.5 then -- MUT_B7'
s = s.replace(old, new, 1)
open(p, 'w').write(s)
PY
check "B7 the threshold 2 is lowered" "$DEF" "MUT_B7" 1 CAUGHT

# B8  The gate loses its turbo conjunct, so the id would be live outside turbo.
sed -i "s/$GATE/local bBaseCreep = jmz.IsSoakCandidate(\"basecreep\") -- MUT_B8/" "$DEF"
check "B8 the gate stops being turbo-only" "$DEF" "MUT_B8" 1 CAUGHT

# B9  ⭐ THE PULLCAD TRAP, made explicit: the gate is written as a conjunction of
#     two candidate ids. It looks stricter and it is frozen FALSE the day the
#     second id is promoted, while every wiring census still answers WIRED
#     (GH #622).
sed -i "s/$GATE/local bBaseCreep = jmz.IsSoakCandidate(\"basecreep\") and jmz.IsSoakCandidate(\"threatcreep\") and jmz.IsModeTurbo() -- MUT_B9/" "$DEF"
check "B9 the gate names a second candidate id (pullcad)" "$DEF" "MUT_B9" 1 CAUGHT

# B10 The creep pricing is inverted so the parallel sum can fall BELOW the
#     shipped sum. The whole direction argument (armed can only turn the
#     condition FALSE -> TRUE) rests on that inequality.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('    local rawCount = count\n')
old = '                rawCount = rawCount + 0.2\n'
j = s.index(old, i)
s = s[:j] + '                rawCount = rawCount - 0.2 -- MUT_B10\n' + s[j + len(old):]
open(p, 'w').write(s)
PY
check "B10 a creep prices negative (raw can fall below shipped)" "$DEF" "MUT_B10" 1 CAUGHT

# B11 The mega rung is repriced to the basic bucket. The whole point of leaving
#     the threshold at 2 is that a SIEGE OR MEGA push clears it and a basic wave
#     does not; at 0.2 a mega wave of four reads 0.8 and nothing ever tops up.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('    local rawCount = count\n')
old = '                rawCount = rawCount + 0.6\n'
j = s.index(old, i)
s = s[:j] + '                rawCount = rawCount + 0.2 -- MUT_B11\n' + s[j + len(old):]
open(p, 'w').write(s)
PY
check "B11 mega creeps are repriced to the basic bucket" "$DEF" "MUT_B11" 1 CAUGHT

# B12 The .ts source is reverted while the .lua keeps the fix. The .lua is
#     GENERATED from the .ts, so this is the shape in which a landed fix
#     disappears at the next regeneration with every Lua test still green.
python3 - "$TS" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'baseThreatUntil = bBaseCreep ? math.max(baseThreatUntil || -1, nTopUp) : nTopUp;'
s = s.replace(old, 'baseThreatUntil = nTopUp; // MUT_B12', 1)
open(p, 'w').write(s)
PY
check "B12 the .ts source is reverted behind the .lua" "$TS" "MUT_B12" 1 CAUGHT

# CONTROL  A change that must NOT be caught: the local that decides whether the
#     top-up arm is reached at all is renamed throughout, behaviour identical.
#     It is read three times in this function and named in none of the retained
#     criteria, so if any assertion above is keyed to incidental text rather than
#     to the behaviour and the pinned criteria, this goes red and the stand says
#     so.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
n = s.count('isBaseThreatActive')
assert n >= 3, 'control mutant expected >=3 uses, found %d' % n
s = s.replace('isBaseThreatActive', 'bBaseThreatLive')
s = s.replace('    local bBaseThreatLive = IsBaseThreatActive()',
              '    local bBaseThreatLive = IsBaseThreatActive() -- MUT_CONTROL', 1)
open(p, 'w').write(s)
PY
check "CONTROL an unpinned local is renamed throughout" "$DEF" "MUT_CONTROL" 1 SURVIVED

echo
if [ "$fails" -eq 0 ]; then
    echo "mutation stand: all mutants CAUGHT, control SURVIVED"
    exit 0
fi
echo "mutation stand: $fails leg(s) did not behave as declared"
exit 1
