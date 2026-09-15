#!/usr/bin/env bash
# Mutation stand for tests/test_wardcomma_mid3_spot.lua (strategy charter
# 0NEXT23; soak candidate 'wardcomma').
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
# ⭐ THE ONE THIS STAND EXISTS FOR IS M5.  This lever's defect is a typo, so the
# tempting "fix" is to just write the comma in and ship it -- which changes the
# shipped default with no wave behind it.  M5 is exactly that edit, and nothing
# behavioural can see it: with the comma written in, the armed leg and the
# unarmed leg agree, so the counterfactual cases go green.  Only the source
# census can see it, and only because it asserts that the broken literal is
# still there.
#
# Usage: bash tools/agent/mutstand_wardcomma.sh
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
    if lua5.1 tests/run_tests.lua test_wardcomma_mid3_spot >/dev/null 2>&1; then
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

echo "== mutation stand: wardcomma =="

# M1  The lever is deleted: the resolver never writes.  Gate, id and both call
#     sites still read right to check_armed_wiring.py; only the behaviour is
#     gone.
sed -i 's/^\ttWardCommaSpot.location = WARD_MID3_R3_FIXED$/\treturn -- MUT1/' "$WARD"
check "M1 resolver stops correcting" "MUT1" 1 CAUGHT

# M2  The gate is open for everybody: turbo conjunct AND soak id dropped.  The
#     armed behaviour still happens, so the armed cases stay green -- only the
#     unarmed counterfactual and the source leg can see this.
sed -i "s/if not (J.IsModeTurbo() and J.IsSoakCandidate('wardcomma')) then return end/if false then return end -- MUT2/" "$WARD"
check "M2 gate always open" "MUT2" 1 CAUGHT

# M3  The turbo conjunct alone is dropped.  On this corpus IsModeTurbo() is
#     true, so NO behavioural leg can see it; it is the source assertion or
#     nothing.
sed -i "s/if not (J.IsModeTurbo() and J.IsSoakCandidate('wardcomma')) then return end/if not J.IsSoakCandidate('wardcomma') then return end -- MUT3/" "$WARD"
check "M3 turbo conjunct dropped" "MUT3" 1 CAUGHT

# M4  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'wardcomma' alone the lever no-ops, and the day that second id is
#     promoted the conjunct freezes false forever while a wiring census still
#     answers WIRED.
sed -i "s/if not (J.IsModeTurbo() and J.IsSoakCandidate('wardcomma')) then return end/if not (J.IsModeTurbo() and J.IsSoakCandidate('wardcomma') and J.IsSoakCandidate('campfarm')) then return end -- MUT4/" "$WARD"
check "M4 gate conditioned on a second id" "MUT4" 1 CAUGHT

# M5  ⭐ THE COMMA IS SIMPLY WRITTEN IN.  The behaviour the lever wants becomes
#     the shipped default, un-gated, with no wave behind it.  Both arms now
#     agree, so every counterfactual case is satisfied; only the source census
#     ("exactly one missing-comma literal in bots/, and it is this one") can see
#     that the shipped default moved.
sed -i 's/^local WARD_MID3_R3_SHIPPED = Vector(-2414.402100 -3802.327637)$/local WARD_MID3_R3_SHIPPED = Vector(-2414.402100, -3802.327637) -- MUT5/' "$WARD"
check "M5 typo fixed UNGATED (the shipped default moves)" "MUT5" 1 CAUGHT

# M6  The correction targets a coordinate nobody wrote: the y is taken from the
#     other cluster member rather than from the line's own second number.  Every
#     "armed is not the corrupted point" assertion stays true; only the leg that
#     names the armed point can see it.
sed -i 's/^local WARD_MID3_R3_FIXED   = Vector(-2414.402100, -3802.327637)$/local WARD_MID3_R3_FIXED   = Vector(-2414.402100, -1664.330566) -- MUT6/' "$WARD"
check "M6 armed point becomes an invented constant" "MUT6" 1 CAUGHT

# M7  The sentry producer stops resolving the gate, so "may I sentry here" and
#     "may I observer here" answer off two different coordinates -- the GH #265
#     shape, planted.  No observer-path assertion can see it.
perl -0pi -e 's/\tX\.ApplyWardCommaFix\(\)\n\tlocal possibleSpots = \{\}/\tlocal possibleSpots = {} -- MUT7/' "$WARD"
check "M7 the sentry path stops asking" "MUT7" 1 CAUGHT

# CONTROL  A comment-only edit inside the head note.  Nothing about the decision
#          moves, so the suite must stay GREEN; if it does not, some assertion is
#          keyed to prose instead of to code.
perl -0pi -e 's/-- \[wardcomma 20260915\] Soak candidate/-- CONTROLMUT [wardcomma 20260915] Soak candidate/' "$WARD"
check "CONTROL comment-only edit" "CONTROLMUT" 1 SURVIVED

if [ "$fails" -eq 0 ]; then
    echo "mutation stand: all mutants CAUGHT, control SURVIVED"
    exit 0
fi
echo "mutation stand: $fails leg(s) failed"
exit 1
