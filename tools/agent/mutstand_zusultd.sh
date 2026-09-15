#!/usr/bin/env bash
# Mutation stand for tests/test_zuus_nimbus_ult_reserve.lua
# (hero 2026-09-15, the `zusultd` lever -- Zeus's ult-mana reserve wired to its
# FOURTH consumer, X.ConsiderD/Nimbus).  Each mutant breaks ONE thing that file
# claims; a mutant that SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the mutant
# is "about".  tests/run_tests.lua sorts test names, so "[ratchet] section 6/7"
# run BEFORE "section 1..5" and a source-shape mutant is often caught upstream of
# the section it is aimed at.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `zusultd` for real in bots/Customize/soak_side.lua.  That is the
#     change itself, not a mutation of an assertion.
#   * editing X.zuus_ShouldSaveManaForUlt's clause list.  That helper is SHIPPED
#     behaviour for three other call sites (`zusult` was promoted 2026-09-11), so
#     mutating it tests those three, not this lever.  M7/M8 mutate what THIS site
#     hands the helper instead, which is where this lever actually lives.
#
# Usage: bash tools/agent/mutstand_zusultd.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_zuus_nimbus_ult_reserve.lua
ZUUS=bots/BotLib/hero_zuus.lua
SHAPES=tests/mock/special_value_shapes.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$ZUUS" "$SHAPES"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$ZUUS" "$SHAPES"; do
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
	out=$(lua5.1 tests/run_tests.lua zuus_nimbus_ult_reserve 2>&1)
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
out=$(lua5.1 tests/run_tests.lua zuus_nimbus_ult_reserve 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The gate id is renamed, i.e. arming the published string moves nothing.
#     This is the silent-no-op shape check_armed_wiring.py cannot see (a call
#     site exists; the predicate is simply unreachable by any wave).
sed -i "s/'zusultd'/'zusultdXX'/g" "$ZUUS"
run "M1 gate id renamed -> the wiring guard must red" \
    "gate is gone from X.SkillsComplement"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\t\tand J.IsModeTurbo()\n\t\tand J.IsSoakCandidate( 'zusultd' )"
new = "\t\tand J.IsSoakCandidate( 'zusultd' )"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "is no longer turbo-only"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  `zusult` is PROMOTED, so this exact edit
#     would freeze the lever FALSE in every wave while every automatic reader
#     still called it WIRED.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "and J.IsSoakCandidate( 'zusultd' )"
new = "and J.IsSoakCandidate( 'zusult' ) and J.IsSoakCandidate( 'zusultd' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 gate names a promoted sibling -> pullcad guard must red" \
    "other candidate id(s) in its own condition"

# M4  The gate loses its `castDDesire > 0` guard, i.e. the reserve is consulted
#     on frames that were never going to cast Nimbus.  That is not a behaviour
#     change today, but it silently changes what the lever's domain MEANS.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\tif ( castDDesire > 0\n\t\tand J.IsModeTurbo()"
new = "\tif ( true\n\t\tand J.IsModeTurbo()"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 live-bid guard dropped -> direction section must red" \
    "no longer conditioned on a live Nimbus bid"

# M5  The gate body RAISES the desire instead of zeroing it, i.e. the lever stops
#     being a narrowing.  A wave reading on a two-directional lever cannot be
#     attributed at all, which is why section 5 pins the body verbatim.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\tthen\n\t\tcastDDesire = 0\n\tend\n\tif ( castDDesire > 0 )"
new = "\tthen\n\t\tcastDDesire = BOT_ACTION_DESIRE_HIGH\n\tend\n\tif ( castDDesire > 0 )"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 gate body raises desire -> narrowing guard must red" \
    "is now \`castDDesire = BOT_ACTION_DESIRE_HIGH\`"

# M6  X.ConsiderD stops carrying the target out.  The gate still parses, the
#     helper is still called, and the lever is a STRUCTURAL no-op: the reserve
#     refuses every non-hero target on its own J.IsValidHero clause.  This is
#     the failure mode the third return value exists to prevent, and it is the
#     one an automatic wiring reader cannot see.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\tcastDDesire, castDLocation, castDTarget = X.ConsiderD()"
new = "\tcastDDesire, castDLocation = X.ConsiderD()"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 target no longer carried out -> wiring guard must red" \
    "no longer takes a third value out of X.ConsiderD"

# M7  The hold prices the WRONG SPEND: the Bolt handle instead of the Nimbus one.
#     Under `zusultx` the reserve subtracts hSpell:GetManaCost(), so this quietly
#     prices 125-150 where 275 is being spent -- and the gate still reads WIRED.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "X.zuus_ShouldSaveManaForUlt( bot, castDTarget, hCloudHandle )"
new = "X.zuus_ShouldSaveManaForUlt( bot, castDTarget, abilityW )"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 hold prices the Bolt handle -> handle guard must red" \
    "no longer prices the NIMBUS handle"

# M8  The RETREAT branch starts naming its chaser, i.e. self-preservation drops
#     become holdable.  Reason (1) of section 4's exemption is gone; reason (2)
#     (the helper's own retreat clause) still holds, which is exactly why the
#     file asserts BOTH and why this mutant must still die.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), nil"
new = "return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), npcEnemy"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 retreat branch names its chaser -> exemption guard must red" \
    "retreat branch no longer returns nil as its third value"

# M9  One of the three SIBLING reserve sites is unwired.  The file's whole thesis
#     is "three guarded, one not"; at two guarded it is describing something else.
python3 - <<'PY'
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "if ( castQDesire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castQTarget, abilityQ ) )"
new = "if ( castQDesire > 0 and false )"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 the ConsiderQ reserve site unwired -> the four-site census must red" \
    "reserve call sites, not 4"

# M10 The KV price asymmetry is inverted: Nimbus made CHEAPER than a rank-1 ult.
#     Section 2's "largest of the four holes" sentence and section 3's rank-1
#     emptiness both run on 275 > 250, and neither may survive its own premise.
python3 - <<'PY'
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['zuus_cloud'] = {\n            ['AbilityCastPoint'] = { base = '0.2', bonus = {  } },\n            ['AbilityCastRange'] = { base = '0', bonus = {  } },\n            ['AbilityCooldown'] = { base = '45', bonus = {  } },\n            ['AbilityManaCost'] = { base = '275', bonus = {  } },"
new = old.replace("base = '275'", "base = '200'")
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 Nimbus made cheaper than a rank-1 ult -> price guard must red" \
    "Nimbus costs 200 now, not 275"

# M11 The ult cost LADDER is flattened to its rank-1 value.  Section 3's whole
#     point is that the window is empty at rank 1 and nonempty above it; with a
#     flat ladder there is no "above it" and the section must not stay green.
#     ⚠️ This mutant is the reason section 3 drives the rank-2/rank-3 bounds
#     through the handle instead of asserting them off the ladder alone.
python3 - <<'PY'
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['AbilityManaCost'] = { base = '250 375 500', bonus = {  } },"
new = "['AbilityManaCost'] = { base = '250 250 250', bonus = {  } },"
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 ult cost ladder flattened -> the ladder guard must red" \
    "the ult cost ladder is now 250/250/250"

# M12 The TEST's healthy-enemy helper is made to accept any hero, including one
#     below the reserve's health floor.  Section 3's liveness guard would then be
#     satisfiable by a target the reserve refuses for an unrelated reason, and
#     every "does not hold" below it would be a vacuity.
#     ⚠️ This is a mutant of the TEST, not of bots/: the failure it models is the
#     one that actually happens to this file (a driver that stops driving).
python3 - <<'PY'
p = 'tests/test_zuus_nimbus_ult_reserve.lua'
s = open(p).read()
old = "        if J.IsValidHero(h) and J.GetHP(h) >= 0.75 then return h end"
new = "        if J.IsValidHero(h) then return h end"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 test accepts an unhealthy target -> section 3's liveness guard must red" \
    "Some clause other than mana is refusing"

echo
echo "mutants killed: $pass    survived/wrong: $fail"
[ "$fail" -eq 0 ] || exit 1
