#!/usr/bin/env bash
# Mutation stand for tests/test_axe_q_lane_push_crowd.lua
# (hero 2026-09-16, the `axecallcrowd` lever -- the 带线 firing point's ally-crowd
# cap refuses a GROUPED PUSH, and `#hEnemyList == 0` on the same `if` is what
# says so).  Each mutant breaks ONE thing that file claims; a mutant that
# SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ EVERY MUTATION IS FENCED (`|| exit 2` on the heredoc, plus an anchor-count
# assert inside it).  GH #846: a mutant that never got applied is scored as a
# survivor-or-kill on an UNMUTATED tree, and the axecullbm M9 case shows that
# reads as "12/12" for a whole round.  The fence is not optional decoration.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the mutant
# is "about".  tests/run_tests.lua sorts test names, so a source-shape mutant is
# often caught upstream of the section it is aimed at.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `axecallcrowd` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#   * shrinking the ally radius to 400 or 265.  That is not a mutation of this
#     lever, it is the OTHER lever -- the one §2.3 measured dead at 600 and
#     above.  M10 mutates it to 600 precisely because 600 is inside the range
#     the measurement covers; 400 would red for being a different question.
#   * dropping `#laneCreepList >= 4`.  The end-to-end domain is 0 either way
#     (GH #772), so it would SURVIVE, and honestly so.  A stand entry that is
#     known to survive teaches nothing.
#
# Usage: bash tools/agent/mutstand_axecallcrowd.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_axe_q_lane_push_crowd.lua
AXE=bots/BotLib/hero_axe.lua
JMZ=bots/FunLib/jmz_func.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$AXE" "$JMZ"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$AXE" "$JMZ"; do
		pristine="$TMP/$(echo "$f" | tr / _)"
		cp "$pristine" "$f"
		if [ "$(sha256sum < "$pristine")" != "$(sha256sum < "$f")" ]; then
			echo "ABORT: restore of $f did not reproduce the pristine bytes." >&2
			echo "       The working tree is NOT clean -- recover $f from git." >&2
			exit 2
		fi
	done
}
trap 'restore; rm -rf "$TMP"' EXIT

pass=0
fail=0

# run <name> <want-substring>  -- expects the suite to go RED and to say <want>
run() {
	local name="$1" want="$2" out
	out=$(lua5.1 tests/run_tests.lua axe_q_lane_push_crowd 2>&1)
	if echo "$out" | grep -q "0 failures"; then
		echo "SURVIVED  $name  -- the suite stayed green"
		fail=$((fail + 1))
	elif echo "$out" | grep -qF "$want"; then
		echo "killed    $name"
		pass=$((pass + 1))
	else
		echo "WRONG MESSAGE  $name  -- red, but not on the assertion aimed at"
		echo "$out" | grep -A3 'FAIL' | head -10
		fail=$((fail + 1))
	fi
	restore
}

# Sanity: the pristine tree must be GREEN, or every "killed" below is a lie.
out=$(lua5.1 tests/run_tests.lua axe_q_lane_push_crowd 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The gate id is renamed, i.e. arming the published string moves nothing.
#     The silent-no-op shape check_armed_wiring.py cannot see: a call site
#     exists, the predicate is simply unreachable by any wave.
python3 - <<'PY' || { echo 'ABORT: M1 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
assert s.count("'axecallcrowd'") == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace("'axecallcrowd'", "'axecallcrowdXX'", 1))
PY
run "M1 gate id renamed -> the single-id pin must red" \
    "no longer names axecallcrowd"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only, and
#     without this the id would change a NORMAL-MODE game.
python3 - <<'PY' || { echo 'ABORT: M2 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\tif J.IsModeTurbo() and J.IsSoakCandidate( 'axecallcrowd' )"
new = "\tif J.IsSoakCandidate( 'axecallcrowd' )"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "lost its turbo guard"

# M3  The pullcad trap, written the way it actually gets written: the SIBLING id
#     on the same branch ANDed into this condition.  Frozen FALSE the day
#     axecallclock is promoted, and check_armed_wiring.py still calls it WIRED.
python3 - <<'PY' || { echo 'ABORT: M3 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.IsModeTurbo() and J.IsSoakCandidate( 'axecallcrowd' )"
new = "J.IsModeTurbo() and J.IsSoakCandidate( 'axecallclock' ) and J.IsSoakCandidate( 'axecallcrowd' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 gate names the sibling id -> pullcad guard must red" \
    "must hold exactly ONE IsSoakCandidate call"

# M4  The call site is reverted to the literal, i.e. the helper is defined,
#     tested, and DEAD -- the shape check_armed_wiring.py is blind to because it
#     asks whether a call site exists, not whether THIS one is it.
python3 - <<'PY' || { echo 'ABORT: M4 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\tand X.axe_IsLanePushCrowdOpen( #hAllyList )\n"
new = "\t\tand #hAllyList <= 2\n"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is the COUNT half of §1.2, not its "the literal is back" half: the
# count assertion is written first inside the same test body, so it is what
# fires.  Aiming the stand at the prose-nicer message scored WRONG MESSAGE.
run "M4 call site reverted to the literal -> the wiring pin must red" \
    "expected exactly two X.axe_IsLanePushCrowdOpen( occurrences"

# M5  ⭐ The armed cap is raised to 5, which DELETES the conjunct rather than
#     raising it: no five-man team can exceed 5, so the branch loses its ability
#     to refuse at all.  Every corpus reading stays IDENTICAL except the one
#     frame in §3.2 -- this is the mutant that makes "the residual is occupied"
#     a measurement instead of a sentence.
python3 - <<'PY' || { echo 'ABORT: M5 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "X.nQLanePushAllyCapTurbo   = 4"
new = "X.nQLanePushAllyCapTurbo   = 5"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 armed cap raised to 5 -> the 'conjunct deleted' guard must red" \
    "DELETES the conjunct rather than"

# M6  The armed cap equals the shipped one: the lever is wired, published, and
#     a byte-level no-op in every wave.  "Tested, no effect" with nobody raising
#     a hand is exactly the verdict shape AGENTS.md warns about.
python3 - <<'PY' || { echo 'ABORT: M6 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "X.nQLanePushAllyCapTurbo   = 4"
new = "X.nQLanePushAllyCapTurbo   = 2"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 armed cap == shipped cap -> the direction pin must red" \
    "must be LARGER than shipped"

# M7  ⭐ The two caps are SWAPPED, so a widening silently becomes a NARROWING.
#     Both constants still exist, both are still read off the source, and the
#     helper still compiles -- only a test that pins WHICH number is shipped can
#     see it.  (Same mutant as axecallclock's M6, and it is here for the same
#     reason: the direction claim is what a negative wave reading is attributed
#     with.)
python3 - <<'PY' || { echo 'ABORT: M7 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "X.nQLanePushAllyCapShipped = 2\nX.nQLanePushAllyCapTurbo   = 4"
new = "X.nQLanePushAllyCapShipped = 4\nX.nQLanePushAllyCapTurbo   = 2"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 caps swapped -> widening silently became narrowing; §2.1 must red" \
    "shipped cap moved to 4"

# M8  The helper stops reading its argument and always admits.  Direction is
#     unchanged (it can still only ADD casts), the gate is still turbo-only and
#     still names one id, and nothing about the wiring census moves -- only a
#     test that drives the predicate on real ally counts can see it.
python3 - <<'PY' || { echo 'ABORT: M8 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\treturn nAllyCount <= X.nQLanePushAllyCapTurbo\n"
new = "\t\treturn true\n"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 armed leg ignores the count -> the loaded-predicate read must red" \
    "armed leg disagrees"

# M9  ⭐ THE GATE-OFF LEG stops being byte-for-byte the shipped behaviour: the
#     shipped return reads the TURBO cap.  A soak candidate that changes the
#     tree with its gate DOWN is the one failure mode that cannot be undone by
#     un-arming it, and §3.1's shipped-leg read plus §3.3's non-turbo read are
#     the only things standing in front of it.
python3 - <<'PY' || { echo 'ABORT: M9 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\treturn nAllyCount <= X.nQLanePushAllyCapShipped\n"
new = "\treturn nAllyCount <= X.nQLanePushAllyCapTurbo\n"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 gate-off leg reads the armed cap -> the shipped-leg read must red" \
    "shipped leg disagrees"

# M10 ⭐ THE DEAD LEVER COMES BACK.  The ally radius is moved 1600 -> 600, i.e.
#     the change §2.3 measured to move ZERO Axe instants is landed anyway, and
#     silently, on top of this one.  It is invisible to every other assertion in
#     the file BY CONSTRUCTION -- that is what "measured dead" means -- so §5.2
#     is the only thing that can notice the bytes moved.
python3 - <<'PY' || { echo 'ABORT: M10 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "hAllyList = J.GetAlliesNearLoc( bot:GetLocation(), 1600 )"
new = "hAllyList = J.GetAlliesNearLoc( bot:GetLocation(), 600 )"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 the measured-dead radius lever lands silently -> §5.2 must red" \
    "is no longer J.GetAlliesNearLoc"

# M11 ⭐ THE OFF-BY-ONE CLAIM'S CONTROL.  J.GetAlliesNearLoc stops counting the
#     caster.  Both caps keep their numbers and every gate assertion stays
#     green, but "Axe plus at most one other" silently becomes "at most two
#     others" -- the header's whole reading of what the cap MEANS, and §2.2's
#     five-man argument with it.  §2.4 is the only assertion that asks.
python3 - <<'PY' || { echo 'ABORT: M11 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = """		if member ~= nil
			and member:IsAlive()
			and GetUnitToLocationDistance( member, vLoc ) <= nRadius
		then"""
new = """		if member ~= nil
			and member:IsAlive()
			and GetUnitToLocationDistance( member, vLoc ) > 0
			and GetUnitToLocationDistance( member, vLoc ) <= nRadius
		then"""
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 the ally list stops counting the caster -> the off-by-one pin must red" \
    "the caster is at distance 0 from himself"

# M12 ⭐ THE CENSUS SLICE'S CONTROL, and it mutates the TEST.  §2.3's "the radius
#     moves ZERO instants" is a statement about AXE-subject frames; this mutant
#     drops the subject filter so it would become a statement about all 142
#     subjects, where the radius DOES move some.
#
#     ⭐ WHAT THE STAND ACTUALLY MEASURED, which is better news than what it was
#     aimed at: the widening cannot be SILENT here.  `world()` loads every frame
#     with the Axe subject hard-anchored, so the first non-Axe frame makes
#     replay_fixture abort with `fixture subject not in units` rather than
#     quietly averaging a wider slice.  The slice is enforced TWICE -- once by
#     the filter this mutant removes and once by the loader -- and the second
#     enforcement is the one that cannot be edited away by accident.  The `want`
#     string below names the loader, because naming the radius message would be
#     claiming a kill this file did not make.
python3 - <<'PY' || { echo 'ABORT: M12 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_axe_q_lane_push_crowd.lua'
s = open(p).read()
old = "        if fx ~= nil and fx.self == UNIT and type(fx.time) == 'number' then"
new = "        if fx ~= nil and fx.self ~= nil and type(fx.time) == 'number' then"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 the Axe-subject filter is dropped from the census -> §2.3 must red" \
    "fixture subject not in units"

echo
echo "mutants killed: $pass   survived/wrong-message: $fail"
[ "$fail" -eq 0 ] || exit 1
