#!/usr/bin/env bash
# Mutation stand for tests/test_defquiet_idle_defender.lua (soak candidate
# 'defquiet').
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
# This stand does NOT write bots/Customize/soak_side.lua -- the test file arms
# the id by overriding J.IsSoakCandidate directly -- so it does not contend for
# that global inode (GH #229, GH #365 §3, GH #848).
#
# Usage: bash tools/agent/mutstand_defquiet.sh
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
    if lua5.1 tests/run_tests.lua defquiet_idle_defender >/dev/null 2>&1; then
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

GUARD='if (not bDefQuiet or nNearby >= 1 or creepWeights > 0) and not result and pos == GetClosestAllyPos('
GATE='local bDefQuiet = jmz.IsSoakCandidate("defquiet") and jmz.IsModeTurbo()'

echo "== mutation stand: defquiet =="

# M1  The lever is deleted: armed, the clause fires exactly as shipped.  The
#     gate, the id and the call site all still read right to
#     check_armed_wiring.py, which asks whether a call site exists -- not
#     whether the predicate can ever be false.
sed -i "s/$GUARD/if true and not result and pos == GetClosestAllyPos( -- MUT1/" "$DEF"
check "M1 armed arm becomes inert" "$DEF" "MUT1" 1 CAUGHT

# M2  The precondition is weakened to one that cannot fail.  This is the mutant
#     that matters most: the whole lever IS the requirement that somebody be
#     there, and a [gate]-only test file would call this WIRED and measure
#     nothing.
sed -i "s/nNearby >= 1 or creepWeights > 0) and not result/nNearby >= 0) and not result -- MUT2/" "$DEF"
check "M2 precondition weakened to always-true" "$DEF" "MUT2" 1 CAUGHT

# M3  Direction flipped: armed now keeps the QUIET buildings and drops the
#     threatened one.  A behavioural leg that only checked "the answer moved"
#     would be fooled here; the control lane inside the bearing frame is what
#     separates "changed the answer" from "changed it the right way".
sed -i "s/nNearby >= 1 or creepWeights > 0) and not result/nNearby < 1) and not result -- MUT3/" "$DEF"
check "M3 precondition direction flipped" "$DEF" "MUT3" 1 CAUGHT

# M4  A THRESHOLD smuggled in where a precondition belongs.  At >= 2 the lever
#     also drops the bot lane of the bearing frame, which has exactly one
#     enemy -- i.e. it stops being "is anybody there" and becomes a knob about
#     how many.  Only the control lane sees this.
sed -i "s/nNearby >= 1 or creepWeights > 0) and not result/nNearby >= 2) and not result -- MUT4/" "$DEF"
check "M4 precondition becomes a 2-enemy threshold" "$DEF" "MUT4" 1 CAUGHT

# M5  The gate is open for everybody: both the soak id and the turbo conjunct
#     are gone.  The behaviour under test still happens, so only the [gate]
#     legs can see this one.
sed -i "s/$GATE/local bDefQuiet = true -- MUT5/" "$DEF"
check "M5 gate always open" "$DEF" "MUT5" 1 CAUGHT

# M6  The turbo conjunct alone is dropped.  Every frame in this corpus is turbo,
#     so no leg driven on the corpus AS IT IS can see this; the leg that catches
#     it is the one that makes J.IsModeTurbo() report a non-turbo game.  That is
#     why that leg exists and is not prose.
sed -i "s/$GATE/local bDefQuiet = jmz.IsSoakCandidate(\"defquiet\") -- MUT6/" "$DEF"
check "M6 turbo conjunct dropped" "$DEF" "MUT6" 1 CAUGHT

# M7  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'defquiet' alone the lever no-ops, and the day that second id is
#     promoted the conjunct is frozen false forever while a wiring census still
#     answers WIRED.
sed -i "s/$GATE/local bDefQuiet = jmz.IsSoakCandidate(\"defquiet\") and jmz.IsModeTurbo() and jmz.IsSoakCandidate(\"defclose\") -- MUT7/" "$DEF"
check "M7 gate conditioned on a second id" "$DEF" "MUT7" 1 CAUGHT

# M8  A RETAINED clause quietly widened: the role list grows a fourth role.
#     The bearing frame's answer need not move, so this is the [source] verbatim
#     assertion or nothing -- GH #834 §5 / 0NEXT31 (乙), whose whole point is
#     that "one lever at a time" is a claim about the code and has to be
#     measured like one.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('if (not bDefQuiet or nNearby >= 1 or creepWeights > 0) and not result and pos == GetClosestAllyPos(')
j = s.index('{2, 3},', i)
s = s[:j] + '{2, 3, 4}, -- MUT8' + s[j + len('{2, 3},'):]
open(p, 'w').write(s)
PY
check "M8 the retained role list is widened" "$DEF" "MUT8" 1 CAUGHT

# M9  The TypeScript source loses the lever while the Lua keeps it.
#     aba_defend.lua is transpiler output; a Lua-only lever is reverted by the
#     next regeneration, silently and by someone who is not looking for it.
sed -i 's/jmz.IsSoakCandidate("defquiet")/jmz.IsSoakCandidate("defquiet_MUT9")/' "$TS"
check "M9 TypeScript source drifts from the Lua" "$TS" "MUT9" 1 CAUGHT

# M10 CONTROL.  A comment-only edit inside the block the lever lives in.  It
#     must SURVIVE: if the suite goes red here, some assertion is keyed to
#     comment text rather than to code or to a decision.
sed -i 's/^        -- \[defquiet\] The nNearby ladder above/        -- [defquiet] (control edit) The nNearby ladder above/' "$DEF"
check "M10 CONTROL comment-only edit" "$DEF" "control edit" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "== all mutants CAUGHT, control SURVIVED =="
    exit 0
fi
echo "== $fails leg(s) failed =="
exit 1
