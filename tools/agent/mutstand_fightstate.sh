#!/usr/bin/env bash
# Mutation stand for tests/test_fightstate_power_accumulator.lua (strategy
# charter 0NEXT27; soak candidate 'fightstate').
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
# ⚠ WHAT THIS STAND CANNOT REACH, said once so no leg below is over-read:
# neither GetOffensivePower() nor GetRawOffensivePower() is in the dump, so no
# leg here evaluates the two totals on a real frame.  §5 W1 of the test pins
# that absence (reverse-called), and §4 exhausts the selection over a grid
# instead.  A mutant that changed only the engine's numbers would be invisible
# to this stand, and that is a property of the corpus, not of these legs.
#
# Usage: bash tools/agent/mutstand_fightstate.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

JMZ=bots/FunLib/jmz_func.lua
BAKJ=$(mktemp)
OUT=$(mktemp)
cp "$JMZ" "$BAKJ"
SUMS=$(sha256sum "$JMZ")

restore() {
    cp "$BAKJ" "$JMZ"
    if [ "$(sha256sum "$JMZ")" != "$SUMS" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

# $1 name  $2 file  $3 needle  $4 wanted grep -c  $5 CAUGHT|SURVIVED
# $6 (optional) substring the failure output MUST contain -- i.e. WHICH case
#    caught it.  Without this a mutant can be "caught" by an unrelated
#    assertion and the leg still reads green ("red" and "red for the right
#    reason" are two questions; charter 0NEXT27 (申)).
check() {
    local name="$1" file="$2" needle="$3" want="$4" expect="$5" by="${6:-}"
    local got
    got=$(grep -c -- "$needle" "$file")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua test_fightstate_power_accumulator >"$OUT" 2>&1; then
        if [ "$expect" = "CAUGHT" ]; then
            echo "  $name: SURVIVED -- the suite is green on a mutant"
            fails=$((fails + 1))
        else
            echo "  $name: SURVIVED (as intended -- control)"
        fi
    else
        if [ "$expect" != "CAUGHT" ]; then
            echo "  $name: RED -- the control mutant went red, so at least one"
            echo "        assertion is keyed to something it should not be"
            fails=$((fails + 1))
        elif [ -n "$by" ] && ! grep -qF -- "$by" "$OUT"; then
            echo "  $name: CAUGHT BY THE WRONG CASE -- expected a failure"
            echo "        naming '$by'; got:"
            grep -m3 '^FAIL' "$OUT" | sed 's/^/          /'
            fails=$((fails + 1))
        else
            echo "  $name: CAUGHT"
        fi
    fi
    restore
}

echo "== mutation stand: fightstate =="

# M1  ⭐ THE DEFECT, RESTORED.  The comparison goes back to ourPowerRaw and the
#     selection above it is left in place, so the gate, the id, the turbo
#     conjunct and the call site all still read right to a wiring census --
#     ourPower is simply a dead store again.
sed -i 's/^\tlocal res = nOurPower > enemyPower$/\tlocal res = ourPowerRaw > enemyPower -- MUT1/' "$JMZ"
check "M1 comparison reverts to ourPowerRaw (the shipped defect)" "$JMZ" "MUT1" 1 CAUGHT \
      "compares ourPowerRaw again"

# M2  ⭐ THE FIX SHIPS LIVE.  The default flips to the state-aware total, so the
#     gate still exists and still answers false in shipped games -- and changes
#     nothing, because the un-armed path now carries the armed behaviour into
#     every game, normal mode included.  No driven leg can see this: armed and
#     un-armed agree.  It is the [site] default pin or nothing.
sed -i 's/^\tlocal nOurPower = ourPowerRaw$/\tlocal nOurPower = ourPower -- MUT2/' "$JMZ"
check "M2 default flipped to ourPower (ungated ship)" "$JMZ" "MUT2" 1 CAUGHT \
      "no longer defaults to ourPowerRaw"

# M3  The guard is dropped entirely: the assignment becomes unconditional.
#     Same destination as M2 by another route, and the route matters -- an
#     assertion that only checked the default would miss this one.
perl -0pi -e 's/\tif J\.ShouldRateOurFightPowerByState\(\) then\n\t\tnOurPower = ourPower\n\tend/\tnOurPower = ourPower -- MUT3/' "$JMZ"
check "M3 armed assignment unguarded" "$JMZ" "MUT3" 1 CAUGHT \
      "no longer guarded by"

# M4  The soak-id guard is dropped from the helper: the lever ships live in
#     every Turbo game.  The selection still happens, so §4's mirror stays
#     consistent -- the [helper] source pin and the driven un-armed leg are
#     what see it.
sed -i "s/\tif not J.IsSoakCandidate( 'fightstate' ) then return false end/\t-- MUT4/" "$JMZ"
check "M4 soak gate dropped (ships live in turbo)" "$JMZ" "MUT4" 1 CAUGHT

# M5  The turbo conjunct alone is dropped.  IsModeTurbo() is true on this
#     corpus, so NO driven leg can see it -- the source assertion or nothing.
#     ⚠ ANCHORED ON THE LINE ABOVE IT: the bare line
#     `if not J.IsModeTurbo() then return false end` occurs dozens of times in
#     this file, so a plain sed mutates every one of them and the leg reads
#     NO-OP.  Measured on the tpstash stand (37 helpers), not guessed.
perl -0pi -e "s/(if not J\.IsSoakCandidate\( 'fightstate' \) then return false end\n)\tif not J\.IsModeTurbo\(\) then return false end/\$1\t-- MUT5/" "$JMZ"
check "M5 turbo conjunct dropped" "$JMZ" "MUT5" 1 CAUGHT \
      "gate-first, turbo-second"

# M6  Gate and turbo SWAPPED.  Un-armed the helper now reaches an engine call
#     before consulting its own switch.  Nothing behavioural moves.
perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'fightstate' \) then return false end\n\tif not J\.IsModeTurbo\(\) then return false end/\tif not J.IsModeTurbo() then return false end -- MUT6\n\tif not J.IsSoakCandidate( 'fightstate' ) then return false end/" "$JMZ"
check "M6 gate and turbo swapped" "$JMZ" "MUT6" 1 CAUGHT \
      "gate-first, turbo-second"

# M7  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'fightstate' alone the lever no-ops, and the day that second id is
#     promoted the conjunct is frozen false forever while a wiring census still
#     answers WIRED.
sed -i "s/\tif not J.IsSoakCandidate( 'fightstate' ) then return false end/\tif not J.IsSoakCandidate( 'fightstate' ) then return false end\n\tif not J.IsSoakCandidate( 'siegecap' ) then return false end -- MUT7/" "$JMZ"
check "M7 gate conditioned on a second id" "$JMZ" "MUT7" 1 CAUGHT \
      "candidate ids"

# M8  ⭐ THE LEVER IS QUIETLY NEUTERED: ourPower is built from the RAW getter
#     too, so the two totals become identical and arming can never move a
#     frame.  Every gate, id, call site and default still reads correct --
#     this is the "tested, no effect" shape the charter keeps warning about,
#     and only the "differ in exactly one getter" pin can see it.
sed -i 's/unit:GetOffensivePower())) \* (math.sqrt(Max(0, unit:GetAttackDamage() \* unit:GetAttackSpeed() \* 5)))/unit:GetRawOffensivePower())) * (math.sqrt(Max(0, unit:GetAttackDamage() * unit:GetAttackSpeed() * 5))) --[[MUT8]]/' "$JMZ"
# ⚠ The `by` string is the assertion that actually fires, measured, not the one
#   I expected: the per-line "an ourPower line reads the RAW getter" check sits
#   above the count check inside the same case, so it is the one that speaks.
#   The first run of this stand read CAUGHT BY THE WRONG CASE and that is how I
#   know -- an exit-code-only leg would have called it green.
check "M8 ourPower rebuilt from the RAW getter (lever neutered)" "$JMZ" "MUT8" 1 CAUGHT \
      "an ourPower line reads the RAW getter"

# M9  The Max(0,...) guard is taken back off the ourPower line.  Nothing moves
#     on any frame in this corpus, because nothing here produces a negative
#     product -- but armed, a single negative product makes the total nan and
#     nan > x is false, i.e. "we are not stronger" for a reason unrelated to
#     the lever.  The source pin is the only reader.
sed -i 's/ourPower + (math.log(1 + unit:GetOffensivePower())) \* (math.sqrt(Max(0, unit:GetAttackDamage() \* unit:GetAttackSpeed() \* 5))) \* fMul/ourPower + (math.log(1 + unit:GetOffensivePower())) * (math.sqrt(unit:GetAttackDamage() * unit:GetAttackSpeed() * 5)) * fMul -- MUT9/' "$JMZ"
check "M9 Max(0,...) removed from the ourPower term" "$JMZ" "MUT9" 1 CAUGHT \
      "unguarded math.sqrt"

# M10 The ENEMY total becomes state-aware too.  That destroys the premise the
#     whole lever rests on -- "we can see our own cooldowns and not theirs" --
#     while leaving every other reading in the file green.
sed -i 's/enemyPower + (math.log(1 + unit:GetRawOffensivePower())) \* (math.sqrt(Max(0, unit:GetAttackDamage() \* unit:GetAttackSpeed() \* 5))) \* fMul/enemyPower + (math.log(1 + unit:GetOffensivePower())) * (math.sqrt(Max(0, unit:GetAttackDamage() * unit:GetAttackSpeed() * 5))) * fMul -- MUT10/' "$JMZ"
check "M10 enemy total made state-aware (asymmetry premise broken)" "$JMZ" "MUT10" 1 CAUGHT \
      "state-aware getter"

# CONTROL  A comment-only edit inside the helper's header.  Nothing behavioural
#     and nothing pinned moves, so the suite must stay GREEN.  A control that
#     goes red means some assertion is keyed to comment text.
sed -i 's|^-- \[fightstate, strategy 2026-09-16\] WHICH OF THE TWO ACCUMULATORS J.WeAreStronger$|-- [fightstate] CONTROL EDIT -- this line is prose and nothing may key on it|' "$JMZ"
check "CONTROL comment-only edit" "$JMZ" "CONTROL EDIT" 1 SURVIVED

echo
if [ "$fails" -eq 0 ]; then
    echo "mutation stand: ALL CAUGHT + control SURVIVED"
    exit 0
fi
echo "mutation stand: $fails leg(s) failed"
exit 1
