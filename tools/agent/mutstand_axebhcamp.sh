#!/usr/bin/env bash
# Mutation stand for tests/test_axe_hunger_camp_reach.lua
# (hero 2026-09-15, the `axebhcamp` lever -- X.ConsiderW's 打野 pick elects the
# MOST-HEALTH creep out of a ring 100 units wider than Battle Hunger's cast
# range, with no distance term between the list and the bid).  Each mutant
# breaks ONE thing that file claims; a mutant that SURVIVES is an assertion that
# was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⭐ EVERY MUTATION IS APPLIED THROUGH A PYTHON `assert` ON ITS ANCHOR, INCLUDING
# THE ONE-LINERS.  The `axecallring` round measured why: its M9 anchor also
# matched inside X.ConsiderW, the python assert failed, the file was never
# written, the suite stayed green -- and the stand printed SURVIVED for a mutant
# that had never existed.  A `sed -i` that matches nothing fails the same way
# and says nothing at all, so no mutant here uses one.
#
# ⭐ FOUR OF THE TWELVE MUTATE THE TEST (M8, M9, M10, M12), and they are the
# ones worth reading.  This lever's measurement half is TWO ZEROS, and a zero is
# exactly what a broken instrument hands you for free.  M9 in particular pins
# the branch-level / end-to-end split: the branch answer here is 1 swap and the
# end-to-end answer is 0 casts, because X.ConsiderQ ties at 0.75 and is asked
# first.  A round that conflated them would report a cast that never happens.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `axebhcamp` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#   * replacing `ipairs` with `pairs` in the filter.  It WOULD survive, and
#     honestly so: on an array built by the engine the two agree, and the order
#     claim only bites on a tie at max health, which no case here constructs.
#     It stays in the source because claim 3 is stated about ties; a stand entry
#     known to survive teaches nothing.
#   * weakening §2.3b's `^npc_dota_hero_` to `^npc_`.  Also a survivor: today's
#     corpus has 0 non-hero rows either way, so the mutant is invisible until
#     the very day the assertion is supposed to fire.
#
# Usage: bash tools/agent/mutstand_axebhcamp.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_axe_hunger_camp_reach.lua
AXE=bots/BotLib/hero_axe.lua
KV=tests/mock/special_value_shapes.lua        # M12 moves the measured quantity

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$AXE" "$KV"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$AXE" "$KV"; do
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
	out=$(lua5.1 tests/run_tests.lua axe_hunger_camp_reach 2>&1)
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
out=$(lua5.1 tests/run_tests.lua axe_hunger_camp_reach 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# ---------------------------------------------------------------- the gate --

# M1  The gate id is renamed, i.e. arming the published string moves nothing.
#     The silent-no-op shape check_armed_wiring.py cannot see: a call site
#     exists, the predicate is simply unreachable by any wave.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.IsSoakCandidate( 'axebhcamp' )"
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "J.IsSoakCandidate( 'axebhcampXX' )", 1))
PY
run "M1 gate id renamed -> the single-id pin must red" \
    "the id in the predicate is not axebhcamp"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhcamp' ) ) then return tCreepList end"
new = "\tif not ( J.IsSoakCandidate( 'axebhcamp' ) ) then return tCreepList end"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "the lever must be turbo-only"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  Frozen FALSE the day the sibling is
#     promoted, and check_armed_wiring.py still calls it WIRED.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.IsModeTurbo() and J.IsSoakCandidate( 'axebhcamp' )"
new = "J.IsModeTurbo() and J.IsSoakCandidate( 'axebhreach' ) and J.IsSoakCandidate( 'axebhcamp' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 gate names a sibling id -> pullcad guard must red" "names 2 soak ids"

# -------------------------------------------------------- the direction --

# M4  Gate OFF stops handing back the very table it was given and returns a
#     copy.  Behaviourally identical TODAY and forever, in the engine -- which
#     is the point: "byte-for-byte the shipped path" is a claim about identity,
#     and only an identity assertion can hold it.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhcamp' ) ) then return tCreepList end"
new = ("\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhcamp' ) ) then\n"
       "\t\tlocal tCopy = {}\n"
       "\t\tfor _, h in ipairs( tCreepList ) do tCopy[#tCopy + 1] = h end\n"
       "\t\treturn tCopy\n"
       "\tend")
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 gate off returns a copy -> the identity pin must red" \
    "hand back the very table it was given"

# M5  The filter measures against the BAND ring instead of the cast range, i.e.
#     the lever becomes a no-op that still looks wired.  Nothing about the gate
#     shape changes and §5's source pins all still pass.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\tif J.IsInRange( bot, hCreep, nCastRange )"
new = "\t\tif J.IsInRange( bot, hCreep, nCastRange + 100 )"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` names §3.3's SUBSET COUNT, not the "armed elected ..." line further
# down it: run_tests sorts by case name, so §3.3 fires before §3.6, and with the
# ring widened the filter removes nothing -- 3 of 3 survive.  (Same reason the
# `axecallring` stand had to point M3 at a count instead of the loop it aimed at.)
run "M5 filter widened to the band ring -> the swap must red" \
    "armed candidates 3 of 3"

# M6  The filter is INVERTED: it keeps exactly the creeps the lever exists to
#     drop.  Direction reverses; every source pin still passes.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\tif J.IsInRange( bot, hCreep, nCastRange )"
new = "\t\tif not J.IsInRange( bot, hCreep, nCastRange )"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is §3.3's count again (1 of 3 survive -- only the band member), for
# the same ordering reason as M5.  §3.4 also reds, and its message is the more
# telling one: inverted, the lever elects the SMALL far creep over the big near
# one, i.e. it breaks claim 3 as well as claim 2.
run "M6 filter inverted -> the swap must red" "armed candidates 1 of 3"

# M11 The gate is CONSULTED and then ignored: the early return goes away, so the
#     filter runs on every game, turbo or not, armed or not.  This is the shape
#     a gated fix fails into when the guard is edited rather than deleted -- the
#     id is still there, check_armed_wiring.py is still happy, and the lever is
#     LIVE IN EVERY REAL GAME.  M4's sibling, and the more dangerous one.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhcamp' ) ) then return tCreepList end"
new = "\tlocal _bGate = J.IsModeTurbo() and J.IsSoakCandidate( 'axebhcamp' )"
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 gate consulted then ignored -> the gate-off identity pin must red" \
    "hand back the very table it was given"

# ------------------------------------------------------------- the wiring --

# M7  The call site stops using the filter and hands J.GetMostHpUnit the raw
#     ring again -- the shipped defect, restored, with the helper still present
#     and still tested in isolation.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.GetMostHpUnit( X.axe_HungerCampCandidates( neutralCreepList, nCastRange ) )"
new = "J.GetMostHpUnit( neutralCreepList )"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 call site drops the filter -> the wiring pin must red" \
    "no longer runs through X.axe_HungerCampCandidates"

# --------------------------------------------------- the test's own instruments --

# M8  The corpus enumerator is truncated to one directory.  Every denominator in
#     §1 and §2 shrinks, and with it the meaning of both zeros -- "0 of 40"
#     silently becomes "0 of a smaller number" while every case still reads
#     green on its own terms.  §1.1 is the guard that must catch it.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_axe_hunger_camp_reach.lua'
s = open(p).read()
old = "    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do"
new = "    for _, dir in ipairs({ FIXTURE_DIR }) do"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 corpus enumerator truncated -> the denominator pin must red" \
    "the corpus moved"

# M9  ⭐ THE SPLIT, ATTACKED.  §3.6 is made to read the BRANCH's answer off the
#     end-to-end dispatch, the conflation this file exists to refuse.  On this
#     frame X.ConsiderQ ties at 0.75 and is asked first, so the dispatch casts
#     Berserker's Call and the jungle target never becomes an order: the mutant
#     reads nil where the branch says granite_golem.  A round that made this
#     mistake would report a swap that does not happen.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_axe_hunger_camp_reach.lua'
s = open(p).read()
old = """    local function bid(bArmed)
        local _, _, X = anchor(bArmed, camp_far_is_big)
        local d, hT, sM = X.ConsiderW()
        return d, hT and hT:GetUnitName() or nil, sM
    end"""
new = """    local function bid(bArmed)
        local _, bot, X = anchor(bArmed, camp_far_is_big)
        local log = rf.record_actions(bot)
        X.SkillsComplement()
        return BOT_ACTION_DESIRE_HIGH, hungered(log), 'W-打野'
    end"""
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 the branch reading taken off the dispatch -> §3.6 must red" \
    "gate off should target the far golem"

# M10 §2.2's [L1] assertion is flipped to claim the synthesized-neutral model
#     CAN answer a distance question.  It cannot -- J.IsInRange asks CanBeSeen
#     first and the model has none -- and that is the half of §0.2 (a) that
#     protects a later round from reading "the armed leg dropped every creep"
#     as a live domain.  The flattering direction is the one to guard.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_axe_hunger_camp_reach.lua'
s = open(p).read()
old = "        assert(J.IsInRange(bot, hCreep, 1) == false, string.format("
new = "        assert(J.IsInRange(bot, hCreep, 1) == true, string.format("
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 [L1] flipped to claim the model can answer -> §2.2 must red" \
    "J.IsInRange now answers TRUE for a synthesized neutral"

# M12 ⭐ THE THING §1.3 MEASURES IS MOVED, not the assertion that measures it.
#     axe_battle_hunger's KV cast range is flattened to a rank-independent 600,
#     so the real handles start answering 600 at every rank.  EVERY band size
#     in §0.1 is denominated in that ladder -- "at rank 1 the band's outer edge
#     is exactly the rank-2 cast range" is a sentence about it -- so if §1.3's
#     per-rank check is not load-bearing, this goes through unnoticed.
#     (An earlier draft defanged the ASSERTION instead, with `or true`.  That
#     mutant survives, because §1.3's rank tally still holds and nothing else
#     reads the ladder -- which tells you about the tally, not about the ladder
#     check.  Mutating the measured quantity is the question actually worth
#     asking, and it is the one evidence discipline 2 points at.)
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['AbilityCastRange'] = { base = '600 700 800 900', bonus = {  } },"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
new = "['AbilityCastRange'] = { base = '600 600 600 600', bonus = {  } },"
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 the KV cast-range ladder is flattened -> §1.3 must red" \
    "ladder says"

echo
echo "mutants killed: $pass   survived/wrong: $fail"
[ "$fail" -eq 0 ] || exit 1
