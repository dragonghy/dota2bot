#!/usr/bin/env bash
# Mutation stand for tests/test_wk_save_mana_unreachable_cap.lua
# (hero 2026-09-15, the `wksavecap` unreachable-reserve lever, GH #407).
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so a source-shape
# mutant is usually caught by section 1 before the section it was aimed at
# ever runs.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `wksavecap` for real in bots/Customize/soak_side.lua.  That is the
#     change itself, not a mutation of an assertion.
#   * moving the `nLV >= 6` conjunct in X.ShouldSaveMana.  That is GATE-OFF
#     behaviour, which a soak candidate may not touch; a mutant of it tests the
#     shipped rule, not this lever's assertions.
#
# Usage: bash tools/agent/mutstand_wksavecap.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_wk_save_mana_unreachable_cap.lua
WK=bots/BotLib/hero_skeleton_king.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$WK"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$WK"; do
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
	out=$(lua5.1 tests/run_tests.lua wk_save_mana_unreachable_cap 2>&1)
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

# M1  The gate id is renamed, i.e. arming the published string moves nothing.
#     This is the silent-no-op shape check_armed_wiring.py cannot see (a call
#     site exists; the predicate is simply unreachable by any wave).
sed -i "s/'wksavecap'/'wksavecapXX'/g" "$WK"
run "M1 gate id renamed -> 1.1 must red" "no longer names wksavecap"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wksavecap' ) )\n"
new = "\tif not ( J.IsSoakCandidate( 'wksavecap' ) )\n"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo guard dropped -> 1.1 must red" "lost its turbo guard"

# M3  The gate is written as a CONJUNCTION with the sibling id `wksaveidle` --
#     the pullcad trap.  Both levers sit on the same shipped predicate in the
#     same function, so this is the single most likely wrong edit here: it looks
#     like "the reserve levers belong together" and it freezes this one FALSE
#     the day either id is promoted, with check_armed_wiring.py still calling it
#     WIRED.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wksavecap' ) )\n"
new = ("\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wksavecap' )\n"
       "\t\t\tand J.IsSoakCandidate( 'wksaveidle' ) )\n")
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 gate conjoined with the sibling id -> 1.1 must red" \
    "must hold exactly ONE IsSoakCandidate call"

# M4  The call site is reverted to the shipped right-hand side and the helper is
#     left orphaned.  Every cell in §3 still passes (the helper itself is
#     untouched and §3 calls it directly); §2's decision domain and §1.2 see it.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = '\t\tand ( bot:GetMana() - nAbility:GetManaCost() < X.GetReincarnationReserve( nAbility ) )\n'
new = '\t\tand ( bot:GetMana() - nAbility:GetManaCost() < abilityR:GetManaCost() )\n'
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 call site reverted -> 1.2 must red" \
    "occurrences in code (the definition and the single call site"

# M5  ⭐ THE ONE THAT MATTERS.  The gate-OFF early return is deleted, so the cap
#     applies unconditionally.  Nothing about the ARMED behaviour moves -- §2.3,
#     §3.1, §4.1 and §4.2 all stay green -- and the lever now changes shipped
#     play in every game including non-turbo.  Only the inertness cell (§3.2)
#     and the non-turbo cell (§3.3) can see it, which is exactly why a soak
#     candidate needs both.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ("\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wksavecap' ) )\n"
       "\tthen\n"
       "\t\treturn nReserve\n"
       "\tend\n")
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, '', 1))
PY
run "M5 gate-OFF early return deleted -> 3.2 must red" "the gate leaks"

# M6  The `min` loses its guard: the armed leg returns `nMaxMana - nCost`
#     unconditionally.  The headline frame still releases (§2.3 green) and the
#     arithmetic still looks like a cap, but on a LARGE pool the reserve now
#     GROWS past R's price -- the lever silently becomes a NARROWING one and
#     every negative-wave attribution written in its note is void.  §4.1 is the
#     cell that exists for this; §3.1 reaches it first.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ('\tif nReachable < 0 or nReachable >= nReserve\n'
       '\tthen\n'
       '\t\treturn nReserve\n'
       '\tend\n')
new = ('\tif nReachable < 0\n'
       '\tthen\n'
       '\t\treturn nReserve\n'
       '\tend\n')
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 the cap can now exceed R's price -> 3.1 must red" \
    "specified"

# M7  The negative-pool guard is dropped.  An ability priced above the whole
#     pool now hands back a NEGATIVE reserve, which releases the guard on every
#     such frame instead of leaving the shipped answer alone.  No frame in the
#     corpus has that shape, so §2 stays green -- only the grid sees it.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = '\tif nReachable < 0 or nReachable >= nReserve\n'
new = '\tif nReachable >= nReserve\n'
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 negative reserve allowed -> 3.1 must red" "specified"

# M8  The cap is computed off CURRENT mana instead of MAX mana -- the edit a
#     reader makes when they remember "the pool" and not "the pool's ceiling".
#     It reads almost identically and it destroys the lever's meaning: the
#     reserve now shrinks whenever the hero is merely low on mana, which is the
#     one situation the shipped rule is right about.  The headline frame is at a
#     FULL pool, so §2.3 cannot see this at all.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = '\tlocal nReachable = nMaxMana - nCost\n'
new = '\tlocal nReachable = bot:GetMana() - nCost\n'
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 cap reads current mana, not max -> 3.1 must red" "specified"

# M9  §5.2's control is disabled: the cast-range counter is moved so that the
#     SHIPPED leg also reads it.  §5.1 still passes ("ConsiderQ answers 0"), and
#     without the control that 0 is indistinguishable from a body that never
#     ran.  Mutating the TEST here is the point -- the claim under test is that
#     the control separates the two legs.
python3 - <<'PY'
p = 'tests/test_wk_save_mana_unreachable_cap.lua'
s = open(p).read()
old = "    local shipped, armed = range_reads(nil), range_reads(CAND)\n"
new = "    local shipped, armed = range_reads(CAND), range_reads(CAND)\n"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 the control no longer contrasts the two legs -> 5.2 must red" \
    "The reserve is supposed"

# M10  The disjointness loop is emptied.  ⭐ THIS MUTANT SURVIVED ON ITS FIRST
#      RUN (2026-09-15) and the fix went into the TEST, not into the mutant: a
#      `for` over an empty list executes no assert, so §6.1's disjointness claim
#      was prose with a loop in front of it.  §6.1 now counts its own iterations.
#      Kept in the stand because a later "tidy" of that counter puts the hole
#      straight back.
python3 - <<'PY'
p = 'tests/test_wk_save_mana_unreachable_cap.lua'
s = open(p).read()
old = "    for _, name in ipairs(c.released_idle) do\n        checked = checked + 1\n"
new = "    for _, name in ipairs({}) do\n        checked = checked + 1\n"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 disjointness loop emptied -> 6.1 liveness guard must red" \
    "it is not iterating the set it claims to iterate"

# M11  A REAL overlap, so the disjointness clause itself is shown to fire rather
#      than only its liveness guard.  The census records the sibling's releases
#      under the headline frame's name, which is what an actual overlap would
#      look like to this section while leaving every count intact (still 2).
#      ⚠️ A source-side overlap cannot be used here: §2.3 pins the cap's release
#      set exactly, so any hero-file mutation that creates an overlap reds there
#      first and never reaches §6.1.
python3 - <<'PY'
p = 'tests/test_wk_save_mana_unreachable_cap.lua'
s = open(p).read()
old = "            if not idle.save then c.released_idle[#c.released_idle + 1] = name end\n"
new = "            if not idle.save then c.released_idle[#c.released_idle + 1] = HEADLINE end\n"
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 the two release sets really overlap -> 6.1 must red" \
    "released by BOTH"

echo
echo "mutants killed: $pass    survived/wrong: $fail"
[ "$fail" -eq 0 ] || exit 1
