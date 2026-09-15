#!/usr/bin/env bash
# Mutation stand for tests/test_axe_cull_blade_mail.lua
# (hero 2026-09-15, the `axecullbm` lever -- Culling Blade declines a target
# whose Damage Return would kill Axe).  Each mutant breaks ONE thing that file
# claims; a mutant that SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the mutant
# is "about".  tests/run_tests.lua sorts test names, so a source-shape mutant is
# often caught upstream of the section it is aimed at.
#
# ⭐ APPLY-GUARDS ADDED 2026-09-15 (hero, while landing `axebhcamp`).  The
# `axecallring` round found this failure mode on its own M9 and fixed it there,
# and its backlog entry named THIS file as still carrying the hole.  The hole
# turned out to be wider than that note said: it was not one mutant, it was ALL
# TWELVE -- eleven `python3 - <<'PY'` heredocs with no `||` on them, plus an M1
# that mutated with `sed -i`.
#   * an unguarded heredoc whose `assert` fails writes NOTHING and exits
#     non-zero INTO A SHELL THAT IGNORES IT, so `run` then measures the
#     PRISTINE tree and prints SURVIVED for a mutant that never existed;
#   * `sed -i` that matches nothing is worse -- it exits ZERO and says nothing
#     at all.
# Both directions are silent and both point the same way: they manufacture
# evidence about whether an assertion is doing work.
#
# ⭐⭐ AND THE GUARD FIRED ON ITS VERY FIRST RUN, on M9 -- so this was not a
# precaution, it was a repair.  M9's anchor was the single line
# `\t\tif J.IsValidHero( npcEnemy )\n`, and it stopped being unique on
# 2026-09-15 when `axecallring` added X.axe_CountCallRingTargets, whose loop
# opens with the identical line.  From that commit on, M9's python `assert`
# failed, the file was never written, the suite ran on the PRISTINE tree, and
# the unguarded stand scored the result anyway.  ⛔ So the "12/12 全杀" this
# stand reported on 2026-09-15 counted a mutant that had never been applied.
# The anchor is now two lines (the second is where the two loops part), M9
# applies, and it KILLS -- the assertion it aims at was doing work all along.
# The number was right; the reason was not, and only the guard could tell them
# apart.  (Same shape as the `axecallring` M9 the backlog pointed here from --
# that round found it in its own stand and wrote that this file still had it.
# It had it twelve times.)
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `axecullbm` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#   * editing the six shipped conjuncts of the execute loop.  Those are shipped
#     behaviour that three sibling levers (`axecull`, `axecullreach`,
#     `cullthresh`) and their files already pin; mutating them tests those.
#   * recutting FRAME_BM.  The frame is the evidence, not the assertion.
#
# Usage: bash tools/agent/mutstand_axecullbm.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_axe_cull_blade_mail.lua
AXE=bots/BotLib/hero_axe.lua
SHAPES=tests/mock/special_value_shapes.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$AXE" "$SHAPES"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$AXE" "$SHAPES"; do
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
	out=$(lua5.1 tests/run_tests.lua axe_cull_blade_mail 2>&1)
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
out=$(lua5.1 tests/run_tests.lua axe_cull_blade_mail 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The gate id is renamed, i.e. arming the published string moves nothing.
#     The silent-no-op shape check_armed_wiring.py cannot see: a call site
#     exists, the predicate is simply unreachable by any wave.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.IsSoakCandidate( 'axecullbm' )"
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "J.IsSoakCandidate( 'axecullbmXX' )", 1))
PY
run "M1 gate id renamed -> the single-id pin must red" \
    "no longer names axecullbm"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\treturn J.IsModeTurbo() and J.IsSoakCandidate( 'axecullbm' )"
new = "\treturn J.IsSoakCandidate( 'axecullbm' )"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "no longer requires turbo"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  ⭐ `axecull` is also a SUBSTRING of this
#     lever's own id, which is why section 6 quotes the ids instead of matching
#     them bare -- the first draft of that check reported this mutant on the
#     PRISTINE tree.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.IsModeTurbo() and J.IsSoakCandidate( 'axecullbm' )"
new = "J.IsModeTurbo() and J.IsSoakCandidate( 'cullthresh' ) and J.IsSoakCandidate( 'axecullbm' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is the COUNT assertion, not the sibling-name one.  Section 6 checks
# the id count before it loops over sibling names, so an ADDED sibling reds on
# "now names 2 soak ids" and the name loop never runs; the name loop is what
# catches a sibling that REPLACES rather than adds (M1 exercises that path).
# The stand's first run recorded this as WRONG MESSAGE -- it was the stand's
# bookkeeping that was wrong, not the test.
run "M3 gate names a sibling id -> pullcad guard must red" \
    "now names 2 soak ids"

# M4  The lever becomes the BLANKET veto -- the sibling pattern section 7 exists
#     to reject.  This is the mutant that "reads like the obvious fix": it vetoes
#     every reflecting target, throwing away a certain hero kill whenever an
#     enemy has popped the item.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\treturn nSelfHealth <= nCullReflectShare * nTargetHealth"
new = "\treturn nSelfHealth == nSelfHealth"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 blanket veto (lethality test removed) -> the healthy-Axe control must red" \
    "vetoes a cull by a 2548 hp Axe"

# M5  The guard stops asking about the modifier and vetoes on health alone.  A
#     mutant with the SAME direction as the lever (it only ever deletes orders),
#     so no direction argument catches it -- only the keyed-on-the-modifier
#     control in section 5 does.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\tif npcEnemy == nil or not npcEnemy:HasModifier( 'modifier_item_blade_mail_reflect' )"
new = "\tif npcEnemy == nil"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 modifier check dropped -> the reflect-removed control must red" \
    "the veto is keyed on something other than"

# M6  The bound is widened from the target's health to the damage instance --
#     i.e. the reading the KV could NOT settle is adopted instead of bounded.
#     Direction is unchanged (still a narrowing), the corpus domain is still 0,
#     and section 3 still passes: only the knife edge in section 5 moves.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\treturn nSelfHealth <= nCullReflectShare * nTargetHealth"
new = "\treturn nSelfHealth <= nCullReflectShare * X.CullKillThreshold( abilityR:GetLevel() )"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 bound widened to the damage instance -> the crossing ladder must red" \
    "crossing is 1104.15"

# M7  The comparison loses its equality case (`<=` -> `<`), so a hero on exactly
#     the return's worth of health is cleared to cull and dies.  The classic
#     off-by-one that no aggregate reading can see.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\treturn nSelfHealth <= nCullReflectShare * nTargetHealth"
new = "\treturn nSelfHealth < nCullReflectShare * nTargetHealth"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is the INTEGER-crossing probe (1105), not the 1104.15 ladder above
# it.  0.85 * 1299 is not an integer, so no integer health lands on that
# crossing and the whole ladder is blind to the equality case -- this mutant
# SURVIVED the stand's first run and the fix was a new probe, not a new mutant
# (evidence discipline rule 2: suspect the assertion).
run "M7 <= becomes < -> the equality probe must red" \
    "must keep its equality case (crossing is 1105)"

# M8  The RECORDED constant drifts.  There is no in-repo cross-check for it
#     (items are not in special_value_shapes.lua), so the source pin is the only
#     reader it has -- this mutant is the proof of that claim.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "local nCullReflectShare = 0.85"
new = "local nCullReflectShare = 0.75"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 the RECORDED 0.85 drifts to 0.75 -> the constant pin must red" \
    "no longer 0.85"

# M9  The conjunct is moved to the FRONT of the loop's `and` chain, ahead of the
#     shipped vetoes.  Behaviour is identical (`and` is commutative here) but the
#     header's "the shipped conjuncts keep their order and their short-circuit
#     cost" stops being true -- a claim only a source pin can hold.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
mine = "\t\t\tand not X.IsCullReflectLethal( npcEnemy )\n"
assert s.count(mine) == 1, 'M9 anchor not found exactly once'
s = s.replace(mine, "", 1)
# The one-line loop head matched TWICE from 2026-09-15 on: `axecallring` added
# X.axe_CountCallRingTargets, whose loop opens with the identical line.  The
# second line is where the two part (CanBeSeen against the ring's IsInRange).
anchor = "\t\tif J.IsValidHero( npcEnemy )\n\t\t\tand npcEnemy:CanBeSeen()\n"
assert s.count(anchor) == 1, 'M9 loop head not found exactly once'
open(p, 'w').write(s.replace(anchor, anchor + mine, 1))
PY
run "M9 conjunct hoisted above the shipped vetoes -> the ordering pin must red" \
    "no longer sits after the shipped ones"

# M10 THE INSTRUMENT CONTROL, and the one aimed at this file rather than at the
#     lever.  Delete the kill-threshold half of the ruling from this tree's KV
#     snapshot by planting a `kill_threshold` key back into axe_culling_blade.
#     Section 6's "this tree KNOWS OF NO kill threshold" check is the ONLY thing
#     standing between a future patch that reintroduces the mechanic and a
#     header that still says the question dissolved.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "            ['damage'] = { base = '275 375 475'"
new = "            ['kill_threshold'] = { base = '250 350 450', bonus = {  } },\n            ['damage'] = { base = '275 375 475'"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 a kill_threshold key reappears in the KV snapshot -> the ruling pin must red" \
    "threshold\` key has appeared"

# M11 THE CENSUS CONTROL.  Make section 2's domain reading passable for the
#     wrong reason: widen the threshold it measures against so a frame that is
#     NOT in the lever's domain would be counted in it.  If section 2 stays
#     green, its 0 was never a measurement of anything.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_axe_cull_blade_mail.lua'
s = open(p).read()
old = "                        if d <= 175 + BONUS and u.hp < 150 + 100 * 3 then"
new = "                        if d <= 175 + BONUS and u.hp < 150 + 100 * 30 then"
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 census threshold inflated -> the domain-zero assertion must red" \
    "the decision domain is no longer 0"

# M12 THE LIVENESS CONTROL for section 3.  Make the inertness sweep vacuous by
#     driving nothing, the way an `ipairs({})` slip does.  Section 3's own
#     `nDriven` guard is the only thing that notices, and this proves it.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_axe_cull_blade_mail.lua'
s = open(p).read()
old = "            and unit_named(fx, AXE) ~= nil and fx.self == AXE then"
new = "            and unit_named(fx, AXE) ~= nil and fx.self == 'nobody' then"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 inertness sweep driven over nothing -> the vacuity guard must red" \
    "Axe-subject frames drove"

echo
echo "MUTANTS killed=$pass  survived_or_wrong=$fail"
[ "$fail" -eq 0 ] || exit 1
