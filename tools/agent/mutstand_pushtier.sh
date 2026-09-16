#!/usr/bin/env bash
# Mutation stand for tests/test_pushtier_min_tie.lua (soak candidate 'pushtier',
# GH #857).
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP -- a failure of the
# stand, not a pass of the code (GH #846: an unapplied mutant that scores is the
# stand lying in the flattering direction).
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.
#
# ⚠ Run it SERIALLY with anything else that touches bots/Customize/soak_side.lua
# (开工自检's Lua leg, another mutation stand).  That path is one global inode;
# concurrent use presents as "the gate did not fire" (GH #229, GH #365 §3).
#
# Usage: bash tools/agent/mutstand_pushtier.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

PUSH=bots/FunLib/aba_push.lua
TS=typescript/bots/FunLib/aba_push.ts
BAKP=$(mktemp)
BAKT=$(mktemp)
cp "$PUSH" "$BAKP"
cp "$TS" "$BAKT"
SUMS=$(sha256sum "$PUSH" "$TS")

restore() {
    cp "$BAKP" "$PUSH"
    cp "$BAKT" "$TS"
    if [ "$(sha256sum "$PUSH" "$TS")" != "$SUMS" ]; then
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
    if lua5.1 tests/run_tests.lua pushtier_min_tie >/dev/null 2>&1; then
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

echo "== mutation stand: pushtier =="

# M1  The lever is deleted: armed, the tier block does nothing at all.  Gate,
#     id and call site all still read right to check_armed_wiring.py.
sed -i "s/        local nMinTier = math.min(topTier, midTier, botTier)/        local nMinTier = 99 -- MUT1/" "$PUSH"
check "M1 armed arm becomes inert" "$PUSH" "MUT1" 1 CAUGHT

# M2  The armed arm keeps the uniqueness requirement after all -- i.e. it is
#     the shipped chain again, reached through a gate.  This is the mutant that
#     matters most: the whole lever IS the removal of that requirement, and a
#     [gate]-only test file would call this WIRED and measure nothing.
sed -i "s/        if topTier == nMinTier then/        if topTier == nMinTier and midTier ~= nMinTier and botTier ~= nMinTier then -- MUT2/" "$PUSH"
check "M2 uniqueness sneaks back into the armed arm" "$PUSH" "MUT2" 1 CAUGHT

# M3  Direction flipped: the multiplier goes to the lanes at the MAXIMUM tier.
#     A behavioural leg alone could be fooled here (the answer still moves);
#     the [fix] leg asserts the armed pick sits at the MINIMUM tier, which is
#     what separates "changed the answer" from "changed it the right way".
sed -i "s/        local nMinTier = math.min(topTier, midTier, botTier)/        local nMinTier = math.max(topTier, midTier, botTier) -- MUT3/" "$PUSH"
check "M3 preference direction flipped" "$PUSH" "MUT3" 1 CAUGHT

# M4  The gate is armed for everybody: turbo conjunct dropped AND the soak id
#     dropped.  The behaviour under test still happens, so only [control] and
#     [gate] can see this.
sed -i "s/    if jmz.IsModeTurbo() and jmz.IsSoakCandidate('pushtier') then/    if true then -- MUT4/" "$PUSH"
check "M4 gate always open" "$PUSH" "MUT4" 1 CAUGHT

# M5  The turbo conjunct alone is dropped.  On this corpus IsModeTurbo() is
#     true, so NO behavioural leg can see it -- it is the [source] assertion or
#     nothing.  (That is the whole reason that assertion is not prose.)
sed -i "s/    if jmz.IsModeTurbo() and jmz.IsSoakCandidate('pushtier') then/    if jmz.IsSoakCandidate('pushtier') then -- MUT5/" "$PUSH"
check "M5 turbo conjunct dropped" "$PUSH" "MUT5" 1 CAUGHT

# M6  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'pushtier' alone the lever no-ops, and the day that second id is
#     promoted the conjunct is frozen false forever while a wiring census still
#     answers WIRED.
sed -i "s/    if jmz.IsModeTurbo() and jmz.IsSoakCandidate('pushtier') then/    if jmz.IsModeTurbo() and jmz.IsSoakCandidate('pushtier') and jmz.IsSoakCandidate('c14') then -- MUT6/" "$PUSH"
check "M6 gate conditioned on a second id" "$PUSH" "MUT6" 1 CAUGHT

# M7  A NEW CONSTANT smuggled into the armed arm: 0.5 becomes 0.25 for the top
#     lane only.  The answer on the bearing frame does not have to move, so the
#     [source] halving census is the leg that sees it.  "One lever at a time"
#     is a claim about the code, and this is how it is measured.
python3 - "$PUSH" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
# the FIRST halving inside the armed arm belongs to the top lane
i = s.index("if jmz.IsModeTurbo() and jmz.IsSoakCandidate('pushtier') then")
j = s.index("topLaneScore = topLaneScore * 0.5", i)
s = s[:j] + "topLaneScore = topLaneScore * 0.25 -- MUT7" + s[j + len("topLaneScore = topLaneScore * 0.5"):]
open(p, 'w').write(s)
PY
check "M7 a second constant enters the armed arm" "$PUSH" "MUT7" 1 CAUGHT

# M8  The barracks sub-clause is dropped from the armed arm only.  Same shape as
#     M7: a retained clause quietly lost where no behavioural leg on this corpus
#     can see it (the sub-clause needs tier >= 3, which this corpus does not
#     reach).  GH #834 §5 is the standing lesson.
python3 - "$PUSH" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index("if jmz.IsModeTurbo() and jmz.IsSoakCandidate('pushtier') then")
j = s.index("if not jmz.Utils.IsAnyBarracksOnLaneAlive(false, Lane.Top) then", i)
s = s[:j] + "if false then -- MUT8" + s[j + len("if not jmz.Utils.IsAnyBarracksOnLaneAlive(false, Lane.Top) then"):]
open(p, 'w').write(s)
PY
check "M8 barracks sub-clause dropped from the armed arm" "$PUSH" "MUT8" 1 CAUGHT

# M9  The TypeScript source loses the lever while the Lua keeps it.  aba_push.lua
#     is transpiler output; a Lua-only lever is reverted by the next
#     regeneration, silently and by someone who is not looking for it.
sed -i 's/jmz.IsSoakCandidate("pushtier")/jmz.IsSoakCandidate("pushtier_MUT9")/' "$TS"
check "M9 TypeScript source drifts from the Lua" "$TS" "MUT9" 1 CAUGHT

# M10 CONTROL.  A comment-only edit inside the tier block.  It must SURVIVE: if
#     the suite goes red here, some assertion is keyed to comment text rather
#     than to code or to a decision.
sed -i 's/^    -- \[GH #857\] Soak candidate/    -- [GH #857] (control edit) Soak candidate/' "$PUSH"
check "M10 CONTROL comment-only edit" "$PUSH" "control edit" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "== all mutants CAUGHT, control SURVIVED =="
    exit 0
fi
echo "== $fails leg(s) failed =="
exit 1
