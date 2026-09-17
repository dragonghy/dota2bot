#!/usr/bin/env bash
# Mutation stand for tests/test_fightfoe_enemyless_fight.lua -- soak candidate
# 'fightfoe', landed 2026-09-17.
#
# What is priced here is J.IsInTeamFight's missing enemy term: the predicate
# reads ONE list and it is the ALLY list (`bEnemy = false`), so "two allies in
# attack mode and an empty ring" and "two allies fighting the other team beside
# me" are the same answer. The repair appends ONE conjunct, at the CALLER'S own
# radius, guarded by the shipped answer itself.
#
# ⛔ READ THE SCORING COLUMN BEFORE THE RESULT. Four legs below (B2, B7, B8, B9)
# are BEHAVIOURALLY EQUIVALENT to the shipped tree on this corpus and are caught
# by the §1 source ratchet alone. That is said out loud rather than left to be
# discovered: a stand whose legs are all "behaviour" reads stronger than it is,
# and a reader who assumes it would mis-price the next round's evidence.
#
# ⭐⭐ THE CONTROL LEG IS NOT DECORATION (charter 0NEXT36). A stand with no
# control cannot tell "every mutant was caught" from "nothing ran at all" -- the
# exact failure this repo bought on 2026-09-17T07:23Z, where a test file missing
# its `return tests` made all twelve legs read CAUGHT for a reason that had
# nothing to do with the code. The control below must SURVIVE; if it goes RED,
# read the stand as broken and NOT the code as good.
#
# Every mutant is applied to the SHIPPED file, never to a copy of it
# (evidence-discipline rule 1). Each leg first proves the edit LANDED with
# grep -c, then runs the test; a mutant whose edit did not land is reported
# NO-OP -- a failure of the stand, not a pass of the code (GH #846).
#
# Restore is from a byte copy taken before the first mutation and verified with
# sha256sum afterwards, so a stand that dies mid-run cannot leave a mutant
# shipped.
#
# This stand does NOT write bots/Customize/soak_side.lua itself -- the test file
# owns that through tests/mock/soak_side.lua -- so it adds no contention of its
# own for that global inode (GH #229, GH #365 §3).
#
# Usage: bash tools/agent/mutstand_fightfoe.sh
# Exit: 0 = every mutant CAUGHT and the control SURVIVED; 1 = otherwise.

set -u
cd "$(dirname "$0")/../.." || exit 1

JMZ=bots/FunLib/jmz_func.lua
BAK=$(mktemp)
cp "$JMZ" "$BAK"
SUM=$(sha256sum "$JMZ")

restore() {
    cp "$BAK" "$JMZ"
    if [ "$(sha256sum "$JMZ")" != "$SUM" ]; then
        echo "FATAL: restore failed -- the tree still carries a mutant" >&2
        exit 2
    fi
}
trap restore EXIT

fails=0

check() {
    local name="$1" needle="$2" want="$3" expect="$4"
    local got
    got=$(grep -c -- "$needle" "$JMZ")
    if [ "$got" != "$want" ]; then
        echo "  $name: NO-OP -- edit did not land (grep -c '$needle' = $got, wanted $want)"
        fails=$((fails + 1))
        restore
        return
    fi
    if lua5.1 tests/run_tests.lua fightfoe_enemyless_fight >/dev/null 2>&1; then
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

echo "== mutation stand: fightfoe (J.IsInTeamFight has no enemy term) =="

# B1  The lever is deleted: the veto block is removed and the function is trunk
#     exactly as it was. If this survives, nothing in the file measures the
#     lever at all.  [behaviour]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """	if #attackModeAllyList >= 2
	and J.ShouldTeamFightNeedAnEnemy()
	and #J.GetNearbyHeroes( bot, nRadius, true, BOT_MODE_NONE ) == 0
	then
		return false
	end
"""
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, '\t-- MUT_B1\n', 1)
open(p, 'w').write(s)
PY
check "B1 the whole veto is deleted (trunk)" "MUT_B1" 1 CAUGHT

# B2  The veto loses its `#attackModeAllyList >= 2` guard. ⛔ SOURCE-ONLY: with
#     the guard gone the veto can only fire where the shipped answer was already
#     FALSE, so behaviour on this corpus is unchanged -- what is lost is the
#     CLOSED-FORM direction proof, which stops being readable off the line.
#     §1's `== 2` count is what keeps it.  [source ratchet]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """	if #attackModeAllyList >= 2
	and J.ShouldTeamFightNeedAnEnemy()"""
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, """	if J.ShouldTeamFightNeedAnEnemy() -- MUT_B2""", 1)
open(p, 'w').write(s)
PY
check "B2 the direction guard is dropped (source-only)" "MUT_B2" 1 CAUGHT

# B3  The conjunct is inverted: the veto fires when an enemy IS in the ring.
#     This is the lever pointed at its own domain -- a real fight stops being
#     one and the enemy-less frame is kept.  [behaviour]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '\tand #J.GetNearbyHeroes( bot, nRadius, true, BOT_MODE_NONE ) == 0\n'
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, '\tand #J.GetNearbyHeroes( bot, nRadius, true, BOT_MODE_NONE ) > 0 -- MUT_B3\n', 1)
open(p, 'w').write(s)
PY
check "B3 the enemy conjunct is inverted" "MUT_B3" 1 CAUGHT

# B4  The gate call is dropped from the veto: the behaviour ships LIVE in every
#     turbo game while `J.ShouldTeamFightNeedAnEnemy` still sits above it
#     looking gated.  [behaviour]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '\tand J.ShouldTeamFightNeedAnEnemy()\n'
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, '\tand true -- MUT_B4\n', 1)
open(p, 'w').write(s)
PY
check "B4 the call site stops asking the gate" "MUT_B4" 1 CAUGHT

# B5  The gate keeps its id and loses TURBO: the lever leaks into normal mode.
#     [behaviour]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """	if not J.IsSoakCandidate( 'fightfoe' ) then return false end
	if not J.IsModeTurbo() then return false end"""
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, """	if not J.IsSoakCandidate( 'fightfoe' ) then return false end -- MUT_B5""", 1)
open(p, 'w').write(s)
PY
check "B5 the gate loses its turbo leg" "MUT_B5" 1 CAUGHT

# B6  The gate loses its ID and keeps turbo: the behaviour is LIVE in every
#     turbo game, which is the one thing a soak candidate may never be.
#     [behaviour]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "\tif not J.IsSoakCandidate( 'fightfoe' ) then return false end\n"
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, '\t-- MUT_B6\n', 1)
open(p, 'w').write(s)
PY
check "B6 the gate loses its candidate id (ships live)" "MUT_B6" 1 CAUGHT

# B7  ⛔ THE 'pullcad' TRAP, PRICED. A second id is conjoined into the gate.
#     The day either id is promoted the predicate freezes FALSE, the lever
#     no-ops in every wave, check_armed_wiring.py still answers WIRED, and the
#     verdict reads back "tested, no effect" with nothing raising a hand
#     (GH #622). Caught twice over: §1 counts the ids, §2 finds the gate shut
#     with only 'fightfoe' armed.  [behaviour + source ratchet]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = "\tif not J.IsSoakCandidate( 'fightfoe' ) then return false end\n"
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, "\tif not ( J.IsSoakCandidate( 'fightfoe' ) and J.IsSoakCandidate( 'fightstate' ) ) then return false end -- MUT_B7\n", 1)
open(p, 'w').write(s)
PY
check "B7 a second id is conjoined into the gate" "MUT_B7" 1 CAUGHT

# B8  The conjunct stops using the CALLER'S radius and hardcodes 1600. ⛔
#     SOURCE-ONLY on this corpus: the clamp means 1600 is already the maximum,
#     and the pinned frame's ring is empty at every radius, so no frame here
#     moves. What is lost is the "no new constant, it is the caller's own
#     question" property -- §1's verbatim string is what keeps it.
#     [source ratchet]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '\tand #J.GetNearbyHeroes( bot, nRadius, true, BOT_MODE_NONE ) == 0\n'
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, '\tand #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) == 0 -- MUT_B8\n', 1)
open(p, 'w').write(s)
PY
check "B8 the caller's radius is replaced by a literal (source-only)" "MUT_B8" 1 CAUGHT

# B9  ⛔ ONE LEVER. The author's own commented-out second conjunct is smuggled
#     into the body. It is a real behaviour change in the engine, but on this
#     corpus GetActiveMode is not driven, so §1's `count(GetActiveMode) == 0` is
#     what keeps it out.  [source ratchet]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '\treturn #attackModeAllyList >= 2 -- and bot:GetActiveMode() ~= BOT_MODE_RETREAT\n'
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, '\treturn #attackModeAllyList >= 2 and bot:GetActiveMode() ~= BOT_MODE_RETREAT -- MUT_B9\n', 1)
open(p, 'w').write(s)
PY
check "B9 the second lever is smuggled in (source-only)" "MUT_B9" 1 CAUGHT

# B10 The SHIPPED expression itself is moved: `>= 2` becomes `> 2`. Nothing in
#     this lever is allowed to touch it, and the un-armed case is what says so.
#     [behaviour]
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = '\treturn #attackModeAllyList >= 2 -- and bot:GetActiveMode()'
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, '\treturn #attackModeAllyList > 2 -- MUT_B10 and bot:GetActiveMode()', 1)
open(p, 'w').write(s)
PY
check "B10 the shipped threshold is moved" "MUT_B10" 1 CAUGHT

# CONTROL  A change that must NOT be caught: the gate's two early returns are
#     folded into one expression. Behaviour is identical, the id is still the
#     only one named, and IsSoakCandidate still precedes IsModeTurbo -- so every
#     retained criterion still holds. If this goes RED, some assertion above is
#     keyed to incidental text rather than to behaviour and the pinned criteria,
#     and the CAUGHT column above cannot be read.
python3 - "$JMZ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """	if not J.IsSoakCandidate( 'fightfoe' ) then return false end
	if not J.IsModeTurbo() then return false end
	return true
end"""
assert s.count(old) == 1, 'anchor not unique'
s = s.replace(old, """	-- MUT_CONTROL
	return J.IsSoakCandidate( 'fightfoe' ) and J.IsModeTurbo()
end""", 1)
open(p, 'w').write(s)
PY
check "CONTROL the gate is folded into one equivalent expression" "MUT_CONTROL" 1 SURVIVED

echo
if [ "$fails" -eq 0 ]; then
    echo "mutation stand: all mutants CAUGHT, control SURVIVED"
    exit 0
fi
echo "mutation stand: $fails leg(s) did not behave as declared"
exit 1
