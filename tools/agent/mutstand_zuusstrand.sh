#!/usr/bin/env bash
# Mutation stand for tests/test_zuus_row_strand_priced.lua
# (hero 2026-09-19, `ZUUSSTRAND` -- the NEGATIVE reading: Zeus's build rows
# strand `zuus_heavenly_jump` and that is the right choice, so no candidate was
# cut.  Two sibling heroes got one in the two preceding rounds.)
#
# ⭐ WHY A STAND ON A NON-CHANGE.  A file whose whole job is to say "do not
# land a lever here" is read exactly once -- by the round that was about to
# land one.  If its assertions do not fire, it reads as a permission slip.
# Each mutant breaks ONE thing the file claims; a SURVIVOR is an assertion that
# was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ EVERY MUTATION IS FENCED (`|| exit 2`, plus an anchor-count assert inside).
# GH #846: a mutant that never got applied is scored on an UNMUTATED tree, and
# that reads as a clean sweep for a whole round.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about" -- tests/run_tests.lua sorts test names.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * landing a `zuusbuild` row.  That is a different change, not a mutation of
#     an assertion; §1 would red on it and that is the file working.
#   * editing the PROSE in bots/BotLib/hero_zuus.lua.  §4 pins one phrase it
#     quotes (M8); the rest of that note is prose and this stand does not
#     pretend otherwise -- see the LIMIT printed at the end.
#
# Usage: bash tools/agent/mutstand_zuusstrand.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_zuus_row_strand_priced.lua
ZEUS=bots/BotLib/hero_zuus.lua
KV=tests/mock/special_value_shapes.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$ZEUS" "$KV"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$ZEUS" "$KV"; do
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

run() {
	local name="$1" want="$2" out
	out=$(lua5.1 tests/run_tests.lua zuus_row_strand_priced 2>&1)
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
out=$(lua5.1 tests/run_tests.lua zuus_row_strand_priced 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The mid row is re-cut so the strand lands on the ARC instead -- i.e. a
#     future round lands the `zuusbuild` this file exists to decline, and the
#     file has to notice.  Arc takes 3 points, Jump 4.
python3 - <<'PY' || { echo 'ABORT: M1 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = '{1,3,1,2,1,6,1,2,2,2,6,3,3,3,6},--pos2'
new = '{1,3,1,2,3,6,3,2,2,2,6,1,1,1,6},--pos2'
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M1 mid row re-cut to strand the arc -> the strand pin must red" \
    "strands engine slot"

# M2  The SIBLING row is re-cut the same way.  The reading is stated for BOTH
#     rows, and a per-role hero is exactly where a one-row check passes while
#     half the bodies in a game run something else.
python3 - <<'PY' || { echo 'ABORT: M2 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = '{2,1,2,3,2,6,2,1,1,1,6,3,3,3,6},--pos4,5'
new = '{2,1,2,3,2,6,2,3,3,3,6,1,1,1,6},--pos4,5'
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 sibling row re-cut to strand the arc -> the BOTH-rows pin must red" \
    "strands engine slot"

# M3  The multiset is changed to {4,4,2,3} -- the ult's third rank bought inside
#     the thirteen points.  §4 declines that alternative on the mana ladder; §1
#     is what notices a row that took it anyway.
python3 - <<'PY' || { echo 'ABORT: M3 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = '{1,3,1,2,1,6,1,2,2,2,6,3,3,3,6},--pos2'
new = '{1,3,1,2,1,6,1,2,2,2,6,3,6,3,3},--pos2'
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is the PER-SLOT line, not the multiset line, and that is a reading
#     rather than a workaround: {4,4,2,3} SORTS to the same multiset as {4,4,3,2},
#     so the multiset assertion cannot see this mutant at all.  Recorded because
#     it prices the multiset assertion: it catches a row that spends the wrong
#     NUMBER of points, never a row that spends them on the wrong abilities.
run "M3 row buys the ult's third rank inside the wall -> the per-slot pin must red" \
    "at the wall; the reading is arc=4 bolt=4 jump=3 ult=2"

# M4  The KV moves so the stranded rank becomes the EXPENSIVE one to decline --
#     the patch-day shape.  The reading must expire rather than go stale.
python3 - <<'PY' || { echo 'ABORT: M4 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['damage'] = { base = '25 50 75 100', bonus = { ['CalculateSpellDamageTooltip'] = '1' } },"
new = "['damage'] = { base = '25 50 75 400', bonus = { ['CalculateSpellDamageTooltip'] = '1' } },"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 jump's fourth rank becomes the biggest of the three -> the pricing must red" \
    "zuus_heavenly_jump.damage is now"

# M5  The jump's CONTROL payload grows a rank ladder.  This is the crux the
#     whole reading turns on (it is what separates Zeus from Lion), and it is
#     the mutation a real patch is most likely to make.
python3 - <<'PY' || { echo 'ABORT: M5 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['move_slow'] = { base = '80', bonus = { ['display_type'] = 'kDebuffPercentage' } },"
new = "['move_slow'] = { base = '50 60 70 80', bonus = { ['display_type'] = 'kDebuffPercentage' } },"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 jump's slow becomes a ladder -> the crux must red" \
    "is now a ladder"

# M6  The CONTRAST half: Lion's Hex stops being a disable-uptime ladder.  If
#     that is gone, "the Lion lever does not transfer" is no longer an argument,
#     and the file must say so rather than keep quoting it.
python3 - <<'PY' || { echo 'ABORT: M6 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['AbilityCooldown'] = { base = '24 20 16 12', bonus = { ['special_bonus_unique_lion_5'] = '-2.0' } },"
new = "['AbilityCooldown'] = { base = '24 24 24 24', bonus = { ['special_bonus_unique_lion_5'] = '-2.0' } },"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 Lion's Hex stops buying uptime -> the contrast must red" \
    "no longer a ladder that buys"

# M7  ⭐ THE ONE THAT CHANGED THE FILE.  The first M7 re-cut the mid row around
#     the swap (entries 4 and 5 exchanged) expecting the domain pin to widen.
#     It SURVIVED -- and the survivor was right: swapping row entries i and j
#     moves the ranks held on exactly levels i..j-1 whatever the digits are, so
#     the "{2,3}" reading is ARITHMETIC, and the comment claiming it as a
#     property of THESE rows was wrong.  Section 5 now says so and demonstrates
#     it with a far swap.  What is left for a mutant to break is the PREMISE:
#     entries 2 and 4 must hold different abilities or there is no swap to
#     decline.  This row keeps the multiset {4,4,3,2} and the jump strand (so
#     sections 1-4 stay green) while putting a jump point at BOTH entries.
python3 - <<'MUT' || { echo 'ABORT: M7 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = '{1,3,1,2,1,6,1,2,2,2,6,3,3,3,6},--pos2'
new = '{1,3,1,3,1,6,1,2,2,2,6,2,3,3,6},--pos2'
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
MUT
run "M7 entries 2 and 4 hold the same ability -> the swap's premise must red" \
    "are now the same ability"

# M8  ⭐ THE COST SIDE.  §4 declines the {4,4,2,3} alternative by QUOTING this
#     file's own affordability reading.  Delete the quoted phrase and the
#     foreclosure is being asserted from memory -- the exact failure a stand
#     that only mutates the benefit side lets through.
python3 - <<'PY' || { echo 'ABORT: M8 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
assert s.count('cannot pay for it') == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace('cannot pay for it', 'is unable to afford it', 1))
PY
run "M8 the quoted affordability reading is paraphrased away -> the foreclosure must red" \
    "no longer carries the affordability reading"

# M9  The ult's mana ladder flattens, i.e. rank 3 stops costing more.  The
#     foreclosure rests on that column and on nothing else.
python3 - <<'PY' || { echo 'ABORT: M9 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['AbilityManaCost'] = { base = '250 375 500', bonus = {  } },"
new = "['AbilityManaCost'] = { base = '250 375 375', bonus = {  } },"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 the ult's rank-3 mana bill flattens -> the foreclosure's column must red" \
    "zuus_thundergods_wrath.AbilityManaCost is now"

echo
echo "killed $pass / $((pass + fail))"
echo
echo "LIMIT: this stand mutates the two build-row literals, the KV columns the"
echo "reading is priced off, and the ONE phrase in bots/BotLib/hero_zuus.lua"
echo "that section 4 quotes.  The rest of the note above tAllAbilityBuildList is"
echo "prose and nothing here pins it: a round that edits its NUMBERS without"
echo "editing the KV would not be caught.  Stated rather than left implicit."
[ "$fail" -eq 0 ] || exit 1
