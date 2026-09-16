#!/usr/bin/env bash
# Mutation stand for tests/test_tpstash_mode_tautology.lua (strategy charter
# 0NEXT26; soak candidate 'tpstash').
#
# Every mutant is applied to the SHIPPED files, never to a copy of them
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP -- a failure of the
# stand, not a pass of the code.
#
# Restore is from byte copies taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.  sha256sum rather than `git diff --quiet`: this stand runs mid-work,
# and a git comparison reports DIRTY for every uncommitted line under test.
#
# ⚠ Run it SERIALLY with anything else that touches bots/Customize/soak_side.lua
# (开工自检's Lua leg, another mutation stand).  That path is one global inode;
# concurrent use presents as "the gate did not fire" (GH #229, GH #365 §3).
#
# ⚠ THE LEG THAT MATTERS MOST HERE IS M1, and it is checked by WHICH assertion
# fires.  This lever's two remaining operands (the stash, slots 9-14, and the
# active mode) are absent from the dump, so no end-to-end behavioural leg
# exists today.  What stands in for one is the DRIVEN domain sweep in §2b --
# the real shipped helper, on a real frame, across all 22 mode values.  A stand
# that only read the exit code would be satisfied by the source pins alone and
# would never notice that the driven half had stopped observing anything.
#
# Usage: bash tools/agent/mutstand_tpstash.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

JMZ=bots/FunLib/jmz_func.lua
AIU=bots/ability_item_usage_generic.lua
BAKJ=$(mktemp)
BAKA=$(mktemp)
OUT=$(mktemp)
cp "$JMZ" "$BAKJ"
cp "$AIU" "$BAKA"
SUMS=$(sha256sum "$JMZ" "$AIU")

restore() {
    cp "$BAKJ" "$JMZ"
    cp "$BAKA" "$AIU"
    if [ "$(sha256sum "$JMZ" "$AIU")" != "$SUMS" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

# $1 name  $2 file  $3 needle  $4 wanted grep -c  $5 CAUGHT|SURVIVED
# $6 (optional) substring the failure output MUST contain -- i.e. WHICH case
#    caught it.  Without this a mutant can be "caught" by an unrelated
#    assertion and the leg still reads green.
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
    if lua5.1 tests/run_tests.lua test_tpstash_mode_tautology >"$OUT" 2>&1; then
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

echo "== mutation stand: tpstash =="

# M1  The lever is deleted at the HELPER: it answers false for everything.  The
#     call site, the gate, the id and the turbo conjunct all still read right to
#     a wiring census -- only the behaviour is gone.  Only the DRIVEN sweep can
#     see this, which is the whole reason §2b exists.
sed -i 's/^\treturn nActiveMode == BOT_MODE_PUSH_TOWER_TOP$/\treturn false -- MUT1/' "$JMZ"
check "M1 helper always false (lever deleted)" "$JMZ" "MUT1" 1 CAUGHT \
      "armed, the helper holds on"

# M2  The `and` is put back to `or` INSIDE the helper -- i.e. the original
#     defect, relocated.  Armed it now holds the TP on every mode, so the lever
#     stops being a narrowing and becomes "never complete items at all".
sed -i 's/^\t\tor nActiveMode == BOT_MODE_PUSH_TOWER_MID$/\t\tor nActiveMode ~= BOT_MODE_PUSH_TOWER_MID -- MUT2/' "$JMZ"
check "M2 the tautology, relocated into the helper" "$JMZ" "MUT2" 1 CAUGHT \
      "armed, the helper holds on"

# M3  The gate is open for everybody: the soak-id guard is dropped.  The
#     narrowing still happens, so the ARMED sweep stays green -- only the
#     UNARMED sweep and the [helper] source pins can see this.
sed -i "s/\tif not J.IsSoakCandidate( 'tpstash' ) then return false end/\t-- MUT3/" "$JMZ"
check "M3 soak gate dropped (ships live)" "$JMZ" "MUT3" 1 CAUGHT

# M4  The turbo conjunct alone is dropped.  IsModeTurbo() is true on this
#     corpus, so NO behavioural or driven leg can see it -- it is the [helper]
#     source assertion or nothing.
#     ⚠ ANCHORED ON THE LINE ABOVE IT, and that is not tidiness: the bare line
#     `if not J.IsModeTurbo() then return false end` occurs 37 times in this
#     file, so a plain sed mutates 37 helpers and the leg reads NO-OP (grep -c
#     = 37).  Measured, not guessed -- it is what this stand's first run did.
perl -0pi -e "s/(if not J\.IsSoakCandidate\( 'tpstash' \) then return false end\n)\tif not J\.IsModeTurbo\(\) then return false end/\$1\t-- MUT4/" "$JMZ"
check "M4 turbo conjunct dropped" "$JMZ" "MUT4" 1 CAUGHT \
      "gate-first, turbo-second"

# M5  Gate and turbo are SWAPPED.  Un-armed the helper now reaches an engine
#     call before consulting its own switch.  Nothing behavioural moves -- both
#     orders answer the same thing -- so this is the source pin or nothing.
perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'tpstash' \) then return false end\n\tif not J\.IsModeTurbo\(\) then return false end/\tif not J.IsModeTurbo() then return false end -- MUT5\n\tif not J.IsSoakCandidate( 'tpstash' ) then return false end/" "$JMZ"
check "M5 gate and turbo swapped" "$JMZ" "MUT5" 1 CAUGHT \
      "gate-first, turbo-second"

# M6  The pullcad trap, planted: the gate is conditioned on a SECOND id.  Armed
#     under 'tpstash' alone the lever no-ops, and the day that second id is
#     promoted the conjunct is frozen false forever while a wiring census still
#     answers WIRED.
sed -i "s/\tif not J.IsSoakCandidate( 'tpstash' ) then return false end/\tif not J.IsSoakCandidate( 'tpstash' ) then return false end\n\tif not J.IsSoakCandidate( 'siegecap' ) then return false end -- MUT6/" "$JMZ"
check "M6 gate conditioned on a second id" "$JMZ" "MUT6" 1 CAUGHT \
      "candidate ids"

# M7  ⭐ The fix ships UNGATED: the call site drops the helper and inlines the
#     conjunction the author meant.  This is the mutant that turns a dark lever
#     into a live behaviour change in every game, normal mode included, and NO
#     driven leg can see it -- armed and unarmed both narrow.  It is the [site]
#     pin or nothing.
sed -i 's/\tand not J.ShouldHoldStashTpWhileBusy( nMode )/\tand nMode ~= BOT_MODE_PUSH_TOWER_TOP and nMode ~= BOT_MODE_ATTACK -- MUT7/' "$AIU"
check "M7 fix inlined at the call site (ungated ship)" "$AIU" "MUT7" 1 CAUGHT \
      "no longer reads"

# M8  ⭐ A candidate id is named INLINE at the call site -- the shape that made
#     test_tpstale_recover_leak.lua red on this lever's first draft.  It works,
#     so no driven leg can see it; what it destroys is the ability to arm the
#     levers in this branch SEPARATELY.
#     ⚠ THE HELPER CALL IS DELIBERATELY LEFT IN PLACE.  The first version of
#     this leg REPLACED it, and then the "call site no longer reads the helper"
#     assertion fired first -- so the leg went red for M7's reason and the
#     inline-id pin was never exercised at all.  The stand read CAUGHT BY THE
#     WRONG CASE, which is the only thing that distinguishes the two.
sed -i "s/\tand not J.ShouldHoldStashTpWhileBusy( nMode )/\tand not J.ShouldHoldStashTpWhileBusy( nMode ) and not J.IsSoakCandidate('tpstash') -- MUT8/" "$AIU"
check "M8 gate re-inlined at the call site" "$AIU" "MUT8" 1 CAUGHT \
      "separately armable"

# M9  The `not` is dropped at the call site: the sense of the conjunct inverts.
#     Un-armed this is still inert (the helper answers false, so the branch is
#     now blocked outright rather than allowed outright) -- which is exactly why
#     an "un-armed is inert" argument that reasons only about the GATE, and not
#     about the sense of the term it feeds, is not enough.
sed -i 's/\tand not J.ShouldHoldStashTpWhileBusy( nMode )/\tand J.ShouldHoldStashTpWhileBusy( nMode ) -- MUT9/' "$AIU"
check "M9 call-site sense inverted" "$AIU" "MUT9" 1 CAUGHT \
      "no longer reads"

# M10 The four modes become three: ATTACK is dropped from the helper.  The
#     narrowing is still real and still gated, so only the driven sweep's
#     EQUALITY on the blocked set can see it -- a count-only assertion would
#     have let it through.
sed -i 's/^\t\tor nActiveMode == BOT_MODE_ATTACK$/\t\tor false -- MUT10/' "$JMZ"
check "M10 one of the four modes dropped" "$JMZ" "MUT10" 1 CAUGHT \
      "armed, the helper holds on"

# CONTROL  A comment-only edit inside the helper's header.  Nothing behavioural
#     and nothing pinned moves, so the suite must stay GREEN.  A control that
#     goes red means some assertion is keyed to comment text.
sed -i 's|^-- \[tpstash / strategy 2026-09-16\] "AM I IN THE MIDDLE OF HITTING SOMETHING?" --|-- [tpstash] CONTROL EDIT -- this line is prose and nothing may key on it|' "$JMZ"
check "CONTROL comment-only edit" "$JMZ" "CONTROL EDIT" 1 SURVIVED

echo
if [ "$fails" -eq 0 ]; then
    echo "mutation stand: ALL CAUGHT + control SURVIVED"
    exit 0
fi
echo "mutation stand: $fails leg(s) failed"
exit 1
