#!/usr/bin/env bash
# Mutation stand for tests/test_warddupkey_eaten_spots.lua (strategy charter
# 0NEXT24; soak candidate 'warddupkey').
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP -- a failure of the
# stand, not a pass of the code.
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.
#
# ⚠ Run it SERIALLY with anything else that touches bots/Customize/soak_side.lua
# (开工自检's Lua leg, another mutation stand).  That path is one global inode;
# concurrent use presents as "the gate did not fire" (GH #229, GH #365 §3).
#
# ⭐ THE ONE THIS STAND EXISTS FOR IS M5, and it is the same shape 'wardcomma'
# needed one for: this lever's defect is a transcription slip, so the tempting
# "fix" is to just delete the duplicate key and ship it -- which moves the
# shipped default with no wave behind it.  Nothing behavioural can see M5: with
# the duplicate removed the armed leg and the unarmed leg agree, so every
# counterfactual case goes green.  Only the source census can see it, and only
# because it asserts the swallowed spot is still swallowed.
#
# ⭐⭐ M8 is the one this stand adds over wardcomma's, and it is specific to a
# lever that APPENDS rather than overwrites: drop the idempotence guard.  The
# producers call the resolver on every tick, so a non-idempotent append grows
# the group without bound for a whole game -- and a single-call test cannot see
# it at all.
#
# Usage: bash tools/agent/mutstand_warddupkey.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

WARD=bots/FunLib/aba_ward_utility.lua
BAK=$(mktemp)
cp "$WARD" "$BAK"
SUM=$(sha256sum "$WARD")

restore() {
    cp "$BAK" "$WARD"
    if [ "$(sha256sum "$WARD")" != "$SUM" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

check() {
    local name="$1" needle="$2" want="$3" expect="$4"
    local got
    got=$(grep -c -- "$needle" "$WARD")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua test_warddupkey_eaten_spots >/dev/null 2>&1; then
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

echo "== mutation stand: warddupkey =="

# M1  The lever is deleted: the resolver never appends.  Gate, id and both call
#     sites still read right to check_armed_wiring.py; only the behaviour is
#     gone.
sed -i 's/^\t\t\t\ttGroup\[nMax + 1\] = r.spot$/\t\t\t\treturn -- MUT1/' "$WARD"
check "M1 resolver stops restoring" "MUT1" 1 CAUGHT

# M2  The gate is open for everybody: turbo conjunct AND soak id dropped.  The
#     armed behaviour still happens, so the armed cases stay green -- only the
#     unarmed counterfactual and the source leg can see this.
sed -i "s/if not (J.IsModeTurbo() and J.IsSoakCandidate('warddupkey')) then return end/if false then return end -- MUT2/" "$WARD"
check "M2 gate always open" "MUT2" 1 CAUGHT

# M3  The turbo conjunct alone is dropped.  On this corpus IsModeTurbo() is
#     true, so NO behavioural leg can see it; it is the source assertion or
#     nothing.
sed -i "s/if not (J.IsModeTurbo() and J.IsSoakCandidate('warddupkey')) then return end/if not J.IsSoakCandidate('warddupkey') then return end -- MUT3/" "$WARD"
check "M3 turbo conjunct dropped" "MUT3" 1 CAUGHT

# M4  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'warddupkey' alone the lever no-ops, and the day that second id is
#     promoted the conjunct freezes false forever while a wiring census still
#     answers WIRED.
sed -i "s/if not (J.IsModeTurbo() and J.IsSoakCandidate('warddupkey')) then return end/if not (J.IsModeTurbo() and J.IsSoakCandidate('warddupkey') and J.IsSoakCandidate('campfarm')) then return end -- MUT4/" "$WARD"
check "M4 gate conditioned on a second id" "MUT4" 1 CAUGHT

# M5  ⭐ THE DUPLICATE KEY IS SIMPLY RENUMBERED AWAY.  The behaviour the lever
#     wants becomes the shipped default, un-gated, with no wave behind it.  Both
#     arms now agree, so every counterfactual case is satisfied; only the source
#     census ("exactly three duplicate spot keys in bots/, and they are these
#     three") can see that the shipped default moved.
sed -i 's/^\t\t\[4\] = { location = WARD_DUP_DIRE_MID1_EATEN, plant_time_obs = 0, plant_time_sentry = 0, },$/\t\t[9] = { location = WARD_DUP_DIRE_MID1_EATEN, plant_time_obs = 0, plant_time_sentry = 0, }, -- MUT5/' "$WARD"
check "M5 duplicate key renumbered UNGATED (shipped default moves)" "MUT5" 1 CAUGHT

# M6  The restored point becomes a coordinate nobody wrote.  Every "the shipped
#     list does not contain a restored spot" assertion stays true; only the legs
#     that name the restored point can see it.
sed -i 's/^local WARD_DUP_DIRE_MID1_EATEN = Vector(-2400.793457, 1431.276611)$/local WARD_DUP_DIRE_MID1_EATEN = Vector(-2400.793457, 1000.000000) -- MUT6/' "$WARD"
check "M6 restored point becomes an invented constant" "MUT6" 1 CAUGHT

# M7  The sentry producer stops resolving the gate, so "may I sentry here" and
#     "may I observer here" answer off two different groups -- the GH #265
#     shape, planted.  No observer-path assertion can see it.
perl -0pi -e 's/\tX\.ApplyWardCommaFix\(\)\n\tX\.ApplyWardDupKeyFix\(\)\n\tlocal possibleSpots = \{\}/\tX.ApplyWardCommaFix()\n\tlocal possibleSpots = {} -- MUT7/' "$WARD"
check "M7 the sentry path stops asking" "MUT7" 1 CAUGHT

# M8  ⭐⭐ THE IDEMPOTENCE GUARD IS DROPPED.  Armed, the very first producer call
#     still answers correctly, so every single-call assertion is satisfied; the
#     group then grows by one spot on every tick for the rest of the game.
sed -i 's/^\t\t\tif not bPresent then$/\t\t\tif true then -- MUT8/' "$WARD"
check "M8 append is no longer idempotent" "MUT8" 1 CAUGHT

# M9  The three restored spots lose their plant_time bookkeeping, so a restored
#     spot can never expire out of the list and never be recorded as used.  The
#     list-length and argmin legs cannot see it; the drain leg can.
sed -i 's/spot = { location = WARD_DUP_DIRE_MID1_EATEN, plant_time_obs = 0, plant_time_sentry = 0, } }/spot = { location = WARD_DUP_DIRE_MID1_EATEN, plant_time_sentry = 0, } } -- MUT9/' "$WARD"
check "M9 restored spot loses plant_time_obs" "MUT9" 1 CAUGHT

# CONTROL  A comment-only edit inside the head note.  Nothing about the decision
#          moves, so the suite must stay GREEN; if it does not, some assertion is
#          keyed to prose instead of to code.
perl -0pi -e 's/-- \[warddupkey 20260915\] Soak candidate/-- CONTROLMUT [warddupkey 20260915] Soak candidate/' "$WARD"
check "CONTROL comment-only edit" "CONTROLMUT" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "mutation stand: all mutants CAUGHT, control SURVIVED"
    exit 0
fi
echo "mutation stand: $fails leg(s) failed"
exit 1
