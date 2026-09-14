#!/usr/bin/env bash
# Mutation stand for tests/test_talent_side_not_the_wall.lua
# (hero 2026-09-14, the corpus census that eliminates the t10 SIDE SELECTOR as
# the mechanism behind the talent wall).
#
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.  Two of the mutants edit bots/ rather than
# tests/, on purpose: the census's §2 claims it is driven through the SHIPPED
# J.Skill.GetTalentBuild, and the only way to prove that claim is to move the
# shipped function and watch the census notice.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test NAMES (not sections), so
# the order here is: LIMIT A, LIMIT B, LIMIT C, "control: nothing below the
# tier", "the t10 side is driven through", "the talent reading reaches", "the
# t10 side selector does not separate".  A mutant aimed at the census is
# routinely caught by LIMIT A first, because LIMIT A runs the same census.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * widening the band (>= 11 -> >= 10).  Cell counts are RATCHETS: they may
#     rise freely, so a widening mutant is unobservable there by construction,
#     and the one assertion it would trip (the level<10 control) is a different
#     claim.  M6 narrows instead, which the min_total anti-vacuum guard sees.
#   * deleting a fixture.  That reds every ratchet in the suite at once and
#     says nothing about which assertion carries which claim.
#
# Usage: bash tools/agent/mutstand_talentside.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_talent_side_not_the_wall.lua
SKILL=bots/FunLib/aba_skill.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$SKILL"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$SKILL"; do
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
	out=$(lua5.1 tests/run_tests.lua talent_side_not_the_wall 2>&1)
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

# M1  The talent detector is narrowed to `special_bonus_unique`, i.e. it stops
#     seeing the GENERIC stat talents -- which is what most t10 rows are.  The
#     census would then read a talent wall where there is uptake.
python3 - <<'PY'
p = 'tests/test_talent_side_not_the_wall.lua'
s = open(p).read()
old = "ab.name:match('^special_bonus')"
assert s.count(old) == 2, 'M1 anchor count changed (%d)' % s.count(old)
# Only the CENSUS counter, not section 1's own control loop: the control is
# what proves the reading can see a talent at all, and a mutant that blinds
# both says only "everything went dark".
open(p, 'w').write(s.replace(old, "ab.name:match('^special_bonus_unique')", 1))
PY
# LIMIT A fires first (see the ordering note above): narrowing the detector
# takes the GENERIC t10 rows out of the witness set before any cell is read.
run "M1 census talent detector narrowed to _unique -> LIMIT A must red" \
    "with a visibility witness FELL"

# M2  The visibility witness is made vacuous (every hero counts).  This is the
#     mutant that matters most: without the witness, "0 talents" and "the
#     dumper cannot see this hero's talents" are the same row, and the census
#     silently becomes a reading about the instrument.
python3 - <<'PY'
p = 'tests/test_talent_side_not_the_wall.lua'
s = open(p).read()
old = "        if b.talents > 0 then seen[b.name] = true end"
new = "        seen[b.name] = true"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 visibility witness made vacuous -> LIMIT A must red" \
    "RETIRES LIMIT A"

# M3  The SHIPPED selector is inverted in bots/: {0, n} starts taking index 2.
#     §2 claims the census is driven through the real J.Skill.GetTalentBuild
#     rather than through a paraphrase of it; this is the only mutant that can
#     tell those two apart.
python3 - <<'PY'
p = 'bots/FunLib/aba_skill.lua'
s = open(p).read()
old = "[1] = ( tTalentTreeList['t10'][1] == 0 and 1 or 2 ),"
new = "[1] = ( tTalentTreeList['t10'][1] == 0 and 2 or 1 ),"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 shipped t10 selector inverted -> the driven-through claim must red" \
    "no longer maps {0, n} to sTalentList index 1"

# M4  The shipped selector stops depending on the row at all (both sides
#     collapse onto index 1).  The 2x2 becomes a 2x1 -- and a 2x1 cannot
#     eliminate anything, which is exactly what §2's second half is for.
python3 - <<'PY'
p = 'bots/FunLib/aba_skill.lua'
s = open(p).read()
old = "[1] = ( tTalentTreeList['t10'][1] == 0 and 1 or 2 ),"
new = "[1] = 1,"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 shipped t10 selector made row-independent -> side 2 must empty" \
    "side 2, carries a talent FELL"

# M5  The fixture sweep loses its recursion, so tests/fixtures/skillstall/ --
#     the four frames GH #822's acceptance 1 landed -- silently leave the
#     corpus while the census still reports a number.
python3 - <<'PY'
p = 'tests/test_talent_side_not_the_wall.lua'
s = open(p).read()
old = 'io.popen("find " .. FIXTURE_ROOT .. " -name \'*.lua\' | sort")'
new = 'io.popen("ls " .. FIXTURE_ROOT .. "/*.lua | sort")'
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 fixture sweep de-recursed -> the body ratchet must red" \
    "hero bodies read out of the corpus FELL"

# M6  The band is narrowed to level >= 21, which is where this corpus runs out
#     of bodies.  The claim would then rest on a handful of rows while still
#     printing two shares -- the vacuum corpus_scale's min_total exists for.
python3 - <<'PY'
p = 'tests/test_talent_side_not_the_wall.lua'
s = open(p).read()
old = "    local cells = census(tBodies, 11)"
new = "    local cells = census(tBodies, 21)"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 band narrowed to >= 21 -> a ratchet or the anti-vacuum guard must red" \
    "FELL"

# M7  The level<10 control is widened to level<12, so it now spans levels at
#     which a talent IS legal.  A control that cannot fail is not a control.
python3 - <<'PY'
p = 'tests/test_talent_side_not_the_wall.lua'
s = open(p).read()
old = "        if b.level < 10 then"
new = "        if b.level < 12 then"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 impossible-talent control widened past the tier -> it must red" \
    "is impossible in the game"

# M8  LIMIT C's witness hero is swapped for one with a single outcome.  The
#     disagreement with GH #817's per-hero-constant headline is the whole
#     content of that section; it must not survive losing its evidence.
python3 - <<'PY'
p = 'tests/test_talent_side_not_the_wall.lua'
s = open(p).read()
old = "b.name == 'npc_dota_hero_lina'"
new = "b.name == 'npc_dota_hero_zuus'"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 LIMIT C witness swapped for a single-outcome hero -> LIMIT C must red" \
    "WITHOUT a talent FELL"

echo
echo "mutants killed: $pass   survived/wrong-message: $fail"
[ "$fail" -eq 0 ] || exit 1
