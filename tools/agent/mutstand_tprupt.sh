#!/usr/bin/env bash
# Mutation stand for tests/test_tprupt_rupture_leak.lua -- soak candidate
# 'tprupt', landed 2026-09-17.
#
# What is priced here is a DESTINATION-OWNERSHIP drop confined to ONE branch:
# the rupture branch of X.ConsiderItemDesire["item_tpscroll"] fires on a bare
# non-nil test on the function-scoped destination local, which two upstream
# branches (前往守塔 / 前往推塔) write and then fall through without clearing.
# 'tpstale' closed the same leak at 回复状态; this closes it at the only other
# consumer, and that branch reads NO health at all, so it is exposed on frames
# the sibling's low-HP head never reaches.
#
# Every mutant is applied to the SHIPPED files, never to a copy of them
# (evidence-discipline rule 1: a stand built on a duplicate measures the
# duplicate). Each leg first proves the edit LANDED with grep -c, then runs the
# test; a mutant whose edit did not land is reported NO-OP -- a failure of the
# stand, not a pass of the code (GH #846).
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.
#
# This stand does NOT write bots/Customize/soak_side.lua (the test file owns
# that through tests/mock/soak_side.lua), so it does not contend for that global
# inode (GH #229, GH #365 §3, GH #848).
#
# Usage: bash tools/agent/mutstand_tprupt.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

AIUG=bots/ability_item_usage_generic.lua
JMZ=bots/FunLib/jmz_func.lua
BAKA=$(mktemp)
BAKJ=$(mktemp)
cp "$AIUG" "$BAKA"
cp "$JMZ" "$BAKJ"
SUMS=$(sha256sum "$AIUG" "$JMZ")

restore() {
    cp "$BAKA" "$AIUG"
    cp "$BAKJ" "$JMZ"
    if [ "$(sha256sum "$AIUG" "$JMZ")" != "$SUMS" ]; then
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
    if lua5.1 tests/run_tests.lua tprupt_rupture_leak >/dev/null 2>&1; then
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

echo "== mutation stand: tprupt rupture-branch destination ownership =="

# M1  The repair is deleted: the branch goes back to firing on whatever
#     destination it inherited.  This is trunk exactly as it was.  If it
#     survives, nothing in the file measures the lever at all.
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """		if J.ShouldDropUnownedRuptureTp( bRuptureTpIsOurs )
		then
			tpLoc = nil
		end

"""
assert s.count(old) == 1, s.count(old)
s = s.replace(old, "		-- MUT_M1\n\n")
open(p, 'w').write(s)
PY
check "M1 the drop is deleted" "$AIUG" "MUT_M1" 1 CAUGHT

# M2  ⭐ THE NO-OP THAT LOOKS LIKE THE FIX.  The ownership flag is set
#     unconditionally, ABOVE the branch's own conjunction, so it is true on
#     every frame and the drop never drops anything.  A wave arming this reads
#     back "tested, no effect" while check_armed_wiring.py answers WIRED.
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """		local bRuptureTpIsOurs = false
		local nAllyCount"""
assert s.count(old) == 1
s = s.replace(old, """		local bRuptureTpIsOurs = true -- MUT_M2
		local nAllyCount""")
open(p, 'w').write(s)
PY
check "M2 flag set unconditionally (armed is a no-op)" "$AIUG" "MUT_M2" 1 CAUGHT

# M3  ⛔ THE ONE DIRECTION THIS LEVER MUST NEVER TAKE.  The gated block ASSIGNS a
#     destination instead of dropping one, so armed can OPEN the branch on a
#     frame the shipped tree left shut -- a widening wearing a narrowing's
#     comment.
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """		if J.ShouldDropUnownedRuptureTp( bRuptureTpIsOurs )
		then
			tpLoc = nil
		end"""
assert s.count(old) == 1
s = s.replace(old, """		if J.ShouldDropUnownedRuptureTp( bRuptureTpIsOurs )
		then
			tpLoc = J.GetTeamFountain() -- MUT_M3
		end""")
open(p, 'w').write(s)
PY
check "M3 the gated block assigns instead of dropping" "$AIUG" "MUT_M3" 1 CAUGHT

# M4  The gate is named inline, in the branch body, instead of in the helper.
#     That is what makes two levers on one branch jointly armable instead of
#     separately -- the shape that turned tprecov/tpdeep red on 2026-09-14.
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "		if J.ShouldDropUnownedRuptureTp( bRuptureTpIsOurs )\n"
assert s.count(old) == 1
s = s.replace(old, "		if J.IsSoakCandidate( 'tprupt' ) and J.ShouldDropUnownedRuptureTp( bRuptureTpIsOurs ) -- MUT_M4\n")
open(p, 'w').write(s)
PY
check "M4 the candidate id is named in the branch body" "$AIUG" "MUT_M4" 1 CAUGHT

# M5  The helper borrows the SIBLING's id.  Arming 'tpstale' would then move two
#     branches at once and a per-id reading would credit the wrong lever; the
#     controls in section 5 are what see it.
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """function J.ShouldDropUnownedRuptureTp( bOwnsDestination )
	if not J.IsSoakCandidate( 'tprupt' ) then return false end"""
assert s.count(old) == 1
s = s.replace(old, """function J.ShouldDropUnownedRuptureTp( bOwnsDestination ) -- MUT_M5
	if not J.IsSoakCandidate( 'tpstale' ) then return false end""")
open(p, 'w').write(s)
PY
check "M5 the helper borrows the sibling id" "$JMZ" "MUT_M5" 1 CAUGHT

# M6  The pullcad trap, planted: the gate is conditioned on a SECOND id, so the
#     day that id is promoted the conjunct is frozen FALSE forever while a
#     wiring census still answers WIRED.
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """function J.ShouldDropUnownedRuptureTp( bOwnsDestination )
	if not J.IsSoakCandidate( 'tprupt' ) then return false end"""
assert s.count(old) == 1
s = s.replace(old, """function J.ShouldDropUnownedRuptureTp( bOwnsDestination ) -- MUT_M6
	if not J.IsSoakCandidate( 'tprupt' ) then return false end
	if not J.IsSoakCandidate( 'tpstale' ) then return false end""")
open(p, 'w').write(s)
PY
check "M6 gate conditioned on a second id" "$JMZ" "MUT_M6" 1 CAUGHT

# M7  The turbo conjunct alone is dropped.  Every fixture frame in the driven
#     legs is turbo, so only the leg that makes J.IsModeTurbo() report a
#     non-turbo game can see this one.
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """	if not J.IsSoakCandidate( 'tprupt' ) then return false end
	if not J.IsModeTurbo() then return false end
	return bOwnsDestination ~= true"""
assert s.count(old) == 1
s = s.replace(old, """	if not J.IsSoakCandidate( 'tprupt' ) then return false end -- MUT_M7
	return bOwnsDestination ~= true""")
open(p, 'w').write(s)
PY
check "M7 turbo conjunct dropped" "$JMZ" "MUT_M7" 1 CAUGHT

# M8  Gate and turbo swapped, so an unarmed tree reaches an engine call before
#     short-circuiting.  The inertness claim of every gated lever in this family
#     is "unarmed it reaches no engine call at all".
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """	if not J.IsSoakCandidate( 'tprupt' ) then return false end
	if not J.IsModeTurbo() then return false end
	return bOwnsDestination ~= true"""
assert s.count(old) == 1
s = s.replace(old, """	if not J.IsModeTurbo() then return false end -- MUT_M8
	if not J.IsSoakCandidate( 'tprupt' ) then return false end
	return bOwnsDestination ~= true""")
open(p, 'w').write(s)
PY
check "M8 gate-first inverted to turbo-first" "$JMZ" "MUT_M8" 1 CAUGHT

# M9  The predicate is inverted: it now drops the destinations the branch DID
#     choose and keeps the leaked ones -- the exact opposite behaviour, with an
#     unchanged call site and an unchanged gate.
#     ⛔ Anchored on the FUNCTION line: the sibling 'tpstale' helper ends in the
#     identical three statements, and a body-only anchor matches both (the stand
#     refused to score it, which is the grep gate doing its job -- GH #846).
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
head = 'function J.ShouldDropUnownedRuptureTp( bOwnsDestination )'
i = s.index(head)
old = '	return bOwnsDestination ~= true'
j = s.index(old, i)
s = s[:j] + '	return bOwnsDestination == true -- MUT_M9' + s[j + len(old):]
open(p, 'w').write(s)
PY
check "M9 the ownership test inverted" "$JMZ" "MUT_M9" 1 CAUGHT

# M10 ⭐ THE SEPARATION CLAIM, MUTATED.  The rupture branch head gains a health
#     term, which is exactly what would make it a duplicate of the branch
#     'tpstale' already guards -- the reason this round is a second finding and
#     not a restatement rests on that absence.
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """	if bot:HasModifier( 'modifier_bloodseeker_rupture' ) and nEnemyCount <= 1
		and J.GetModifierTime( bot, "modifier_bloodseeker_rupture" ) >= 3.1"""
assert s.count(old) == 1
s = s.replace(old, """	if bot:HasModifier( 'modifier_bloodseeker_rupture' ) and nEnemyCount <= 1 -- MUT_M10
		and botHP < 0.2
		and J.GetModifierTime( bot, "modifier_bloodseeker_rupture" ) >= 3.1""")
open(p, 'w').write(s)
PY
check "M10 the rupture head gains a health term" "$AIUG" "MUT_M10" 1 CAUGHT

# M11 CONTROL.  A pure comment edit inside the branch: no behaviour, no
#     structure, no constant moves.  It MUST survive -- if it does not, some
#     assertion is keyed to prose rather than to code, which is the failure mode
#     0NEXT33 §乙 was written about.
python3 - "$AIUG" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "		-- Gated turbo-only: disarmed, the flag below is written and never read,"
assert s.count(old) == 1
s = s.replace(old, "		-- MUT_M11 control comment; the sentence below is unchanged.\n" + old)
open(p, 'w').write(s)
PY
check "M11 control: comment-only edit" "$AIUG" "MUT_M11" 1 SURVIVES

echo
if [ "$fails" -eq 0 ]; then
    echo "mutation stand: ALL CAUGHT (10 mutants) + control SURVIVED"
    exit 0
fi
echo "mutation stand: $fails leg(s) failed"
exit 1
