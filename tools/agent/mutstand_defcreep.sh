#!/usr/bin/env bash
# Mutation stand for tests/test_defquiet_creep_siege.lua -- the `creepWeights`
# disjunct added to soak candidate 'defquiet' on 2026-09-16.
#
# This stand is the SECOND half of the defquiet pair; tools/agent/mutstand_defquiet.sh
# prices the original lever and is not repeated here. What is priced here is the
# narrowing: that the armed leg stops dropping a defender off a building an
# enemy CREEP is at, and that the truncation which made that necessary
# (nNearby = heroes + math.floor(creepWeights), a lane creep priced 0.2, so a
# full four-creep wave floors to zero) is still in the file, untouched.
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
# Usage: bash tools/agent/mutstand_defcreep.sh
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
    if lua5.1 tests/run_tests.lua defquiet_creep_siege >/dev/null 2>&1; then
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

GUARD='or nNearby >= 1 or creepWeights > 0) and not result'
GATE='local bDefQuiet = jmz.IsSoakCandidate("defquiet") and jmz.IsModeTurbo()'
TRUNC='local nNearby = enemyHeroNearby + math.floor(creepWeights)'

echo "== mutation stand: defquiet/creepWeights narrowing =="

# N1  The narrowing is deleted: this is [defquiet] exactly as it landed last
#     round, and the point of the whole round is that THAT configuration pulls
#     the defender off a tower under a wave.  If this survives, nothing in the
#     file is measuring the narrowing at all.
sed -i "s/$GUARD/or nNearby >= 1) and not result -- MUT_N1/" "$DEF"
check "N1 the creepWeights disjunct is deleted" "$DEF" "MUT_N1" 1 CAUGHT

# N2  Weakened to a predicate that cannot fail.  creepWeights is initialised to
#     0, so `>= 0` holds on every frame -- the armed leg becomes inert, and a
#     [gate]-only file would still call it WIRED.  The control lanes inside the
#     bearing frame are what see this.
sed -i "s/$GUARD/or nNearby >= 1 or creepWeights >= 0) and not result -- MUT_N2/" "$DEF"
check "N2 disjunct weakened to always-true" "$DEF" "MUT_N2" 1 CAUGHT

# N3  Direction flipped: the lever now keeps a defender on the two lanes with
#     nothing near them and drops the one with a creep at the tower.  A leg that
#     only asked "did the answer move" is fooled here; the same-frame control is
#     what separates "changed the answer" from "changed it the right way".
sed -i "s/$GUARD/or nNearby >= 1 or creepWeights <= 0) and not result -- MUT_N3/" "$DEF"
check "N3 disjunct direction flipped" "$DEF" "MUT_N3" 1 CAUGHT

# N4  ⭐ The defect, re-introduced under a new spelling.  `creepWeights > 1` is
#     a THRESHOLD where a presence test belongs: at 0.2 per lane creep it needs
#     six bodies, so it re-creates exactly the truncation this lever exists to
#     route around -- while reading, to a skimming eye, like the same clause.
sed -i "s/$GUARD/or nNearby >= 1 or creepWeights > 1) and not result -- MUT_N4/" "$DEF"
check "N4 presence test becomes a threshold" "$DEF" "MUT_N4" 1 CAUGHT

# N5  The truncation "fixed" instead of routed around.  math.ceil moves EVERY
#     rung of the 1/2/3/>=4 ladder (one creep now reads as one enemy hero),
#     which is the change this lever deliberately did not make.  It is caught by
#     the arithmetic leg and by the verbatim source assertion, not by the
#     bearing frame -- the bearing frame's own answer does not have to move.
sed -i "s/$TRUNC/local nNearby = enemyHeroNearby + math.ceil(creepWeights) -- MUT_N5/" "$DEF"
check "N5 the retained truncation is changed to ceil" "$DEF" "MUT_N5" 1 CAUGHT

# N6  The lane-creep price moved 0.2 -> 1.0.  The arithmetic the whole round
#     rests on ("a full wave of four floors to zero") is FALSE at that price,
#     and the arithmetic leg is the only thing in the repo that would notice.
sed -i "s/creepWeights = creepWeights + 0.2/creepWeights = creepWeights + 1.0 -- MUT_N6/" "$DEF"
check "N6 the 0.2 lane-creep price is moved" "$DEF" "MUT_N6" 1 CAUGHT

# N7  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'defquiet' alone the lever no-ops, and the day that second id is
#     promoted the conjunct is frozen false forever while a wiring census still
#     answers WIRED.
sed -i "s/$GATE/local bDefQuiet = jmz.IsSoakCandidate(\"defquiet\") and jmz.IsModeTurbo() and jmz.IsSoakCandidate(\"defclose\") -- MUT_N7/" "$DEF"
check "N7 gate conditioned on a second id" "$DEF" "MUT_N7" 1 CAUGHT

# N8  The turbo conjunct alone is dropped.  Every frame in this corpus is turbo,
#     so no leg driven on the corpus AS IT IS can see it; the leg that catches
#     it is the one that makes J.IsModeTurbo() report a non-turbo game.
sed -i "s/$GATE/local bDefQuiet = jmz.IsSoakCandidate(\"defquiet\") -- MUT_N8/" "$DEF"
check "N8 turbo conjunct dropped" "$DEF" "MUT_N8" 1 CAUGHT

# N9  The TypeScript source loses the disjunct while the Lua keeps it.
#     aba_defend.lua is transpiler output; a Lua-only edit is reverted by the
#     next regeneration, silently and by someone who is not looking for it.
sed -i 's/|| creepWeights > 0)/) \/\/ MUT_N9/' "$TS"
check "N9 TypeScript source drifts from the Lua" "$TS" "MUT_N9" 1 CAUGHT

# N10 A RETAINED clause quietly widened: the role list grows a fourth role.
#     The bearing frame's answer need not move, so this is the [source] verbatim
#     assertion or nothing -- 0NEXT31 (乙), fourth time it has paid.
python3 - "$DEF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index('if (not bDefQuiet or nNearby >= 1 or creepWeights > 0) and not result')
j = s.index('{2, 3},', i)
s = s[:j] + '{2, 3, 4}, -- MUT_N10' + s[j + len('{2, 3},'):]
open(p, 'w').write(s)
PY
check "N10 the retained role list is widened" "$DEF" "MUT_N10" 1 CAUGHT

# N11 CONTROL.  A comment-only edit inside the block the lever lives in.  It
#     must SURVIVE: if the suite goes red here, some assertion is keyed to
#     comment text rather than to code or to a decision.  ⛔ This control is not
#     decorative in THIS file: the sibling test had an assertion reading
#     `not s:find('nNearby == 0')` over the whole file, comments included, and
#     this round's explanatory comment turned it red while the ladder was
#     untouched.  Fixed there; the control here is what keeps it fixed.
sed -i 's/^        -- `creepWeights > 0` IS PART OF THE PRECONDITION/        -- (control edit) `creepWeights > 0` IS PART OF THE PRECONDITION/' "$DEF"
check "N11 CONTROL comment-only edit" "$DEF" "control edit" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "== all mutants CAUGHT, control SURVIVED =="
    exit 0
fi
echo "== $fails leg(s) failed =="
exit 1
