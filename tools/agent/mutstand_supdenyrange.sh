#!/usr/bin/env bash
# Mutation stand for tests/test_supdenyrange_support_deny_reach.lua
# (charter 0NEXT18).
#
# Every mutant is applied to the SHIPPED implementation, never to a copy of it
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate).  Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP, which is a failure
# of the stand, not a pass of the code.  ⭐ The check COUNTS rather than looks
# (charter 0NEXT18 卯): "did the edit land" and "did THIS edit land" are two
# questions, and only a count answers both -- the sibling stand's first M4 hit
# two sites and printed a different mutant than the one it named.
#
# ⭐ TWO OF THESE LEGS EXIST BECAUSE THIS ID HAS A TWIN.  The shipped tree now
# carries two byte-identical predicates differing only in their id, at two call
# sites behind two armed populations.  Structural assertions cannot tell a
# correct pair from a pair that has silently collapsed into one lever -- M5 and
# M6 are the pair that can, and M6 in particular is caught ONLY by the
# cross-arm legs of section 2b.
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.  sha256sum rather than `git diff --quiet` on purpose: this stand is
# meant to be runnable mid-work, and a git comparison against the index reports
# DIRTY for every uncommitted line of the change under test.
#
# ⛔ DO NOT run this concurrently with 开工自检's Lua leg or another gate test:
# both drive bots/Customize/soak_side.lua, ONE global inode (GH #229), and the
# collision presents as a FAKE red in whichever process loses.
#
# Usage: bash tools/agent/mutstand_supdenyrange.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

LAN=bots/mode_laning_generic.lua
JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_supdenyrange_support_deny_reach.lua
BAKL=$(mktemp)
BAKJ=$(mktemp)
BAKT=$(mktemp)
cp "$LAN" "$BAKL"
cp "$JMZ" "$BAKJ"
cp "$TEST" "$BAKT"

SUMS=$(sha256sum "$LAN" "$JMZ" "$TEST")

restore() {
    cp "$BAKL" "$LAN"
    cp "$BAKJ" "$JMZ"
    cp "$BAKT" "$TEST"
    if [ "$(sha256sum "$LAN" "$JMZ" "$TEST")" != "$SUMS" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

# check <name> <file> <landed-grep> <expect-count> <CAUGHT|SURVIVE>
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
    if lua5.1 tests/run_tests.lua test_supdenyrange_support_deny_reach >/dev/null 2>&1; then
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

echo "== mutation stand: supdenyrange =="

# M1  The gate stops naming its own id.  A gate that names nothing is armed by
#     nothing, so the whole lever silently no-ops -- the 'pullcad' failure mode
#     (GH #622), and the one a wiring census cannot see.
sed -i "s/J.IsSoakCandidate( 'supdenyrange' )/J.IsSoakCandidate( 'supdenyrangez' )/" "$JMZ"
check "M1 gate id renamed" "$JMZ" "IsSoakCandidate( 'supdenyrangez' )" 1 CAUGHT

# M1b The helper stops being gate-first: turbo is asked before the candidate id.
#     Nothing about the id, the call site or the answer changes -- unarmed it
#     simply reaches an engine call it is not allowed to reach.
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index('function J.ShouldDropOutOfReachSupportDeny')
gate = "\tif not J.IsSoakCandidate( 'supdenyrange' ) then return false end\n"
turbo = "\tif not J.IsModeTurbo() then return false end\n"
marked = "\tif not J.IsModeTurbo() then return false end -- MUT1B\n"
body = s[i:i + 400]
assert gate + turbo in body, 'the helper is not in the expected two-line order'
s = s[:i] + body.replace(gate + turbo, marked + gate, 1) + s[i + 400:]
open(p, 'w', encoding='utf-8').write(s)
PY
check "M1b helper turbo-before-gate" "$JMZ" "MUT1B" 1 CAUGHT

# M2  POLARITY.  The call-site conjunct loses its `not`, so armed the branch
#     keeps exactly the denies it should drop and drops exactly the ones it
#     should keep.  The id, the gate, the helper and the call site are all still
#     there and a wiring census still says WIRED -- only the direction is gone,
#     and direction is the one property this lever claims by construction rather
#     than by a count.
sed -i "s/and not J.ShouldDropOutOfReachSupportDeny(bot, denyCreep) then/and J.ShouldDropOutOfReachSupportDeny(bot, denyCreep) then -- MUT2/" "$LAN"
check "M2 narrowing becomes a widening" "$LAN" "MUT2" 1 CAUGHT

# M3  OPERATOR DRIFT.  `>` becomes `>=`, so a creep standing exactly at the
#     bound is dropped.  Every behavioural count in the file is unchanged (no
#     real row sits exactly on the reach), the gate legs are unchanged, and the
#     source ratchets are unchanged.  ONLY the boundary leg of section 2 can see
#     it -- which is what that leg is for.
#     ⚠️ Targeted by OFFSET, not by pattern: the shipped tree now carries TWO
#     identical `> bot:GetAttackRange()` returns (this helper and its sibling),
#     so a bare sed would mutate both and print a different mutant than this leg
#     names.  That is exactly what the landed-edit COUNT is for.
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index('function J.ShouldDropOutOfReachSupportDeny')
old = 'return GetUnitToUnitDistance( bot, hCreep ) > bot:GetAttackRange()'
new = 'return GetUnitToUnitDistance( bot, hCreep ) >= bot:GetAttackRange() -- MUT3'
body = s[i:i + 400]
assert old in body, 'the helper is not in the expected shape'
s = s[:i] + body.replace(old, new, 1) + s[i + 400:]
open(p, 'w', encoding='utf-8').write(s)
PY
check "M3 bound operator > becomes >=" "$JMZ" "MUT3" 1 CAUGHT

# M4  THE BOUND BECOMES THE RING.  `bot:GetAttackRange()` is replaced by the
#     1200 the deny list is already built with.  Structure entirely survives:
#     the gate is first, turbo is second, the conjunct is still `and not`, one
#     id, one call site -- and the lever becomes a no-op on every frame, because
#     nothing the 1200 list can hand it is ever beyond 1200.  This is the
#     order-blind shape: the thing a structural assertion cannot distinguish
#     from the real implementation.  Same offset targeting as M3, same reason.
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index('function J.ShouldDropOutOfReachSupportDeny')
old = 'return GetUnitToUnitDistance( bot, hCreep ) > bot:GetAttackRange()'
new = 'return GetUnitToUnitDistance( bot, hCreep ) > 1200 -- MUT4'
body = s[i:i + 400]
assert old in body, 'the helper is not in the expected shape'
s = s[:i] + body.replace(old, new, 1) + s[i + 400:]
open(p, 'w', encoding='utf-8').write(s)
PY
check "M4 bound becomes the ring width" "$JMZ" "> 1200 -- MUT4" 1 CAUGHT

# M5  THE TWO IDS COLLAPSE INTO ONE, AT THE CALL SITE.  The support branch is
#     re-pointed at the SIBLING's helper, so 'denyreach' alone now moves TWO
#     call sites behind DIFFERENT armed populations -- the non-independence the
#     retreat guard chain was reordered to remove (GH #29), and the thing that
#     makes a per-id verdict unattributable.  The branch is still guarded, still
#     `and not`, still exactly one call -- a wiring census sees nothing.
sed -i "s/and not J.ShouldDropOutOfReachSupportDeny(bot, denyCreep) then/and not J.ShouldDropOutOfReachDeny(bot, denyCreep) then -- MUT5/" "$LAN"
check "M5 support site re-pointed at the sibling helper" "$LAN" "MUT5" 1 CAUGHT

# M6  ⭐ THE TWO IDS COLLAPSE INTO ONE, AT THE GATE -- and this one is caught by
#     NOTHING in section 1.  The SIBLING helper is re-gated onto THIS id, so
#     arming 'supdenyrange' now moves both helpers and arming 'denyreach' moves
#     neither.  Every structural assertion in this file reads this id's helper
#     and this id's call site, and all of them stay green; only the cross-arm
#     legs of section 2b, which drive BOTH helpers under each arm, can see it.
#     ⇒ if this leg ever SURVIVES, section 2b has stopped measuring
#     independence and the two ids are one lever wearing two names.
sed -i "s/if not J.IsSoakCandidate( 'denyreach' ) then return false end/if not J.IsSoakCandidate( 'supdenyrange' ) then return false end -- MUT6/" "$JMZ"
check "M6 sibling helper re-gated onto this id" "$JMZ" "MUT6" 1 CAUGHT

# M7  THE GUARD IS DELETED, THE HELPER IS KEPT.  The shipped call site goes back
#     to the unguarded two lines while J.ShouldDropOutOfReachSupportDeny stays in
#     the tree, fully written and fully tested in isolation.  This is the shape a
#     wiring census is blindest to -- the id exists, the helper exists, its unit
#     tests pass, and the lever is not connected to anything.
python3 - "$LAN" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index('local function DoSupportLaningThink()')
old = ("\tif J.IsValid(denyCreep)\n"
       "\tand not J.ShouldDropOutOfReachSupportDeny(bot, denyCreep) then")
new = "\tif J.IsValid(denyCreep) then -- MUT7"
# 2500, not 900: the branch now carries an eleven-line header, and a window
# sized to the pre-fix source puts the target OUTSIDE it.  That first draft is
# what the NO-OP report is for -- it named the leg's own window, not the code.
body = s[i:i + 2500]
assert old in body, 'the support deny branch is not in the expected shape'
s = s[:i] + body.replace(old, new, 1) + s[i + 2500:]
open(p, 'w', encoding='utf-8').write(s)
PY
check "M7 call-site guard deleted, helper kept" "$LAN" "MUT7" 1 CAUGHT

# M8  THE RECORDED DOMAIN IS ZEROED.  A lever with an empty domain must not
#     ship, and section 3's own census is the only thing in this file that knows
#     the domain is not empty -- so its assertions have to be keyed to the
#     NUMBERS, not merely to the numbers' presence.
sed -i "s/    assert(n150 == 4, 'beyond-melee count moved: ' .. n150)/    assert(n150 == 0, 'beyond-melee count moved: ' .. n150) -- MUT8/" "$TEST"
check "M8 domain census zeroed" "$TEST" "MUT8" 1 CAUGHT

# CONTROL  A comment-only edit inside the shipped call site.  It must SURVIVE:
#     if it does not, some assertion is keyed to comment text rather than to
#     code, and every CAUGHT above would be suspect for the same reason.
sed -i "s/-- \[supdenyrange\] Same missing term as the core Think's deny branch, at the/-- [supdenyrange] SAME MISSING TERM AS THE CORE THINK'S DENY BRANCH, AT THE/" "$LAN"
check "CONTROL comment-only edit" "$LAN" "SAME MISSING TERM AS THE CORE THINK" 1 SURVIVE

echo
if [ "$fails" -eq 0 ]; then
    echo "STAND GREEN -- 8 mutants CAUGHT, control SURVIVED, 0 NO-OP"
    exit 0
fi
echo "STAND RED -- $fails leg(s) failed"
exit 1
