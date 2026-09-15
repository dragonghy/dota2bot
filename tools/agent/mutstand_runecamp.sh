#!/usr/bin/env bash
# Mutation stand for tests/test_runecamp_contest_source.lua (strategy charter
# 0NEXT20; soak candidate 'runecamp').
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP -- a failure of the
# stand, not a pass of the code.
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.  sha256sum rather than `git diff --quiet`: this stand runs mid-work,
# and a git comparison reports DIRTY for every uncommitted line under test.
#
# ⚠ Run it SERIALLY with anything else that touches bots/Customize/soak_side.lua
# (开工自检's Lua leg, another mutation stand).  That path is one global inode;
# concurrent use presents as "the gate did not fire" (GH #229, GH #365 §3).
#
# Usage: bash tools/agent/mutstand_runecamp.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

RUNE=bots/mode_rune_generic.lua
UTIL=bots/FunLib/utils.lua
BAKR=$(mktemp)
BAKU=$(mktemp)
cp "$RUNE" "$BAKR"
cp "$UTIL" "$BAKU"
SUMS=$(sha256sum "$RUNE" "$UTIL")

restore() {
    cp "$BAKR" "$RUNE"
    cp "$BAKU" "$UTIL"
    if [ "$(sha256sum "$RUNE" "$UTIL")" != "$SUMS" ]; then
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
    if lua5.1 tests/run_tests.lua runecamp_contest_source >/dev/null 2>&1; then
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

echo "== mutation stand: runecamp =="

# M1  The lever is deleted: the candidate set goes back to the bot-centric list
#     unconditionally.  Gate, id and call site all still read right to
#     check_armed_wiring.py; only the behaviour is gone.
sed -i 's/^\t\ttRuneContest = J.GetEnemiesNearLoc(vRuneLocation,$/\t\ttRuneContest = nEnemyHeroes -- MUT1 (/' "$RUNE"
check "M1 armed set reverts to the bot ring" "$RUNE" "MUT1" 1 CAUGHT

# M2  The gate is armed for everybody: turbo conjunct dropped AND the soak id
#     dropped.  The behaviour under test still happens, so every [fix]
#     assertion stays green -- only the [control] and [gate] legs can see this.
sed -i "s/if J.IsModeTurbo() and J.IsSoakCandidate('runecamp') then/if true then -- MUT2/" "$RUNE"
check "M2 gate always open" "$RUNE" "MUT2" 1 CAUGHT

# M3  The turbo conjunct alone is dropped.  On this corpus IsModeTurbo() is
#     true, so NO behavioural leg can see it; it is the [gate] source assertion
#     or nothing.  (That is the whole reason that assertion is not prose.)
sed -i "s/if J.IsModeTurbo() and J.IsSoakCandidate('runecamp') then/if J.IsSoakCandidate('runecamp') then -- MUT3/" "$RUNE"
check "M3 turbo conjunct dropped" "$RUNE" "MUT3" 1 CAUGHT

# M4  The pullcad trap, planted: the gate is conditioned on a SECOND id as well.
#     Armed under 'runecamp' alone the lever now no-ops, and the day that second
#     id is promoted the conjunct is frozen false forever while a wiring census
#     still answers WIRED.
sed -i "s/if J.IsModeTurbo() and J.IsSoakCandidate('runecamp') then/if J.IsModeTurbo() and J.IsSoakCandidate('runecamp') and J.IsSoakCandidate('campfarm') then -- MUT4/" "$RUNE"
check "M4 gate conditioned on a second id" "$RUNE" "MUT4" 1 CAUGHT

# M5  The armed radius becomes a constant of its own (the shipped 1600 ring,
#     re-used at the rune).  The bearing frame is 2974u out, so this is exactly
#     the "an invented constant re-creates the blindness" mutant, and it must be
#     caught by BEHAVIOUR, not only by the [gate] text assertion.
sed -i 's/^\t\t\tGetUnitToLocationDistance(bot, vRuneLocation) + 300)$/\t\t\t1600) -- MUT5/' "$RUNE"
check "M5 armed radius becomes a new constant" "$RUNE" "MUT5" 1 CAUGHT

# M6  The lever "helps itself" by loosening a clause instead of widening the
#     set: the 600u camper test becomes 3000u while the set stays bot-centric.
#     Behaviourally this changes nothing on the bearing frame (the set is
#     empty), so only the [gate] clause-verbatim leg can see it -- and that is
#     the leg that keeps this file honest about what shipped.
sed -i 's/GetUnitToLocationDistance(enemy, vRuneLocation) < 600)/GetUnitToLocationDistance(enemy, vRuneLocation) < 3000) -- MUT6/' "$RUNE"
check "M6 a clause is loosened instead of the set widened" "$RUNE" "MUT6" 1 CAUGHT

# M7  The early return that defines the annulus moves from 600 to 0.  The
#     [gate] leg pins it because the 1000u annulus the header prices is derived
#     from that number; if it drifts, the header's arithmetic is wrong.
sed -i 's/if GetUnitToLocationDistance(bot, vRuneLocation) < 600 then return false end/if GetUnitToLocationDistance(bot, vRuneLocation) < 0 then return false end -- MUT7/' "$RUNE"
check "M7 the annulus floor moves" "$RUNE" "MUT7" 1 CAUGHT

# M8  CanBeSeen() is removed from utils.IsValidUnit.  This is the mutant that
#     would make the armed set a FOG READER, and the "no vision is bought"
#     claim in the header rests on nothing else.
sed -i 's/return not target:IsNull() and target:CanBeSeen() and target:IsAlive()/return not target:IsNull() and target:IsAlive() -- MUT8/' "$UTIL"
check "M8 CanBeSeen dropped from IsValidUnit" "$UTIL" "MUT8" 1 CAUGHT

# M9  CONTROL.  A comment-only edit inside the guard.  It must SURVIVE: if the
#     suite goes red here, some assertion is keyed to comment text rather than
#     to code or to a decision.
sed -i 's/^-- THE ASYMMETRY\. /-- THE ASYMMETRY (control edit). /' "$RUNE"
check "M9 CONTROL comment-only edit" "$RUNE" "control edit" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "== all mutants CAUGHT, control SURVIVED =="
    exit 0
fi
echo "== $fails leg(s) failed =="
exit 1
