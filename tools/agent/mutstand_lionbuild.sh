#!/usr/bin/env bash
# Mutation stand for tests/test_lion_hex_max_build.lua
# (hero 2026-09-19, the `lionbuild` lever -- WHICH ability Lion's build row
# leaves for the skill-point wall to strand; the shipped row strands
# `lion_voodoo`, the gated row strands `lion_mana_drain`).
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ EVERY MUTATION IS FENCED (`|| exit 2` on the heredoc, plus an anchor-count
# assert inside it).  GH #846: a mutant that never got applied is scored on an
# UNMUTATED tree, and that reads as a clean sweep for a whole round.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so a mutant aimed
# at §4 is often caught by §2 or §3 first -- and that is a BETTER message, not
# a worse one, as long as the stand says which.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `lionbuild` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#   * reordering entries WITHIN the armed row that change no ladder (there are
#     none: every entry of this row is one of the four abilities and each one's
#     position IS its hero level).  A mutant known to be a no-op teaches nothing.
#
# Usage: bash tools/agent/mutstand_lionbuild.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_lion_hex_max_build.lua
LION=bots/BotLib/hero_lion.lua
KV=tests/mock/special_value_shapes.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$LION" "$KV"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$LION" "$KV"; do
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
	out=$(lua5.1 tests/run_tests.lua lion_hex_max_build 2>&1)
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
out=$(lua5.1 tests/run_tests.lua lion_hex_max_build 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The armed row is reverted to the shipped row, i.e. the candidate is a
#     construction-zero lever with a perfectly correct header (GH #838 shape):
#     arming it changes nothing at all.
python3 - <<'PY' || { echo 'ABORT: M1 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = '{1,3,1,2,2,6,1,1,2,2,6,3,3,3,6},--Hex maxed instead of Mana Drain'
new = '{1,3,1,2,3,6,1,1,3,3,6,2,2,2,6},--Hex maxed instead of Mana Drain'
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M1 armed row reverted to the shipped row -> the strand move must red" \
    "Moving the strand from"

# M2  The armed row moves an ability the candidate swears it does not touch:
#     Earth Spike's fourth point is taken one level later.  The row is still a
#     valid permutation and still strands the Drain -- what dies is the
#     single-lever ATTRIBUTION claim, which is what a wave reading rests on.
python3 - <<'PY' || { echo 'ABORT: M2 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = '{1,3,1,2,2,6,1,1,2,2,6,3,3,3,6},--Hex maxed instead of Mana Drain'
new = '{1,3,1,2,2,6,1,2,1,2,6,3,3,3,6},--Hex maxed instead of Mana Drain'
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 armed row shifts Earth Spike -> the narrowness pin must red" \
    "Earth Spike and Finger of Death do not move"

# M3  The gate id is renamed, i.e. arming the published string moves nothing.
#     The silent-no-op shape check_armed_wiring.py cannot see: a call site
#     exists, the predicate is simply unreachable by any wave.
python3 - <<'PY' || { echo 'ABORT: M3 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
assert s.count("J.IsSoakCandidate( 'lionbuild' )") == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace("J.IsSoakCandidate( 'lionbuild' )",
                             "J.IsSoakCandidate( 'lionbuildXX' )", 1))
PY
run "M3 gate id renamed -> the wiring pin must red" \
    "does not read J.IsSoakCandidate('lionbuild')"

# M4  The pullcad trap, written the way it actually gets written: a SIBLING id
#     from the same file ANDed into this condition.  Frozen FALSE the day
#     `lionwfight` is promoted, and check_armed_wiring.py still calls it WIRED.
python3 - <<'PY' || { echo 'ABORT: M4 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "if J.IsModeTurbo() and J.IsSoakCandidate( 'lionbuild' ) then"
new = ("if J.IsModeTurbo() and J.IsSoakCandidate( 'lionbuild' )"
       " and J.IsSoakCandidate( 'lionwfight' ) then")
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 pullcad trap (sibling id ANDed in) -> the one-id count must red" \
    "soak-candidate ids, not 1"

# M5  The turbo conjunct is dropped.  Every soak candidate is turbo-only; without
#     this the row would be selectable in a NORMAL-MODE game, where the trade
#     this candidate's own prose makes (lane harass for mid-game lockdown) is
#     explicitly NOT argued.
python3 - <<'PY' || { echo 'ABORT: M5 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "if J.IsModeTurbo() and J.IsSoakCandidate( 'lionbuild' ) then"
new = "if J.IsSoakCandidate( 'lionbuild' ) then"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 turbo conjunct dropped -> the gate shape must red" \
    "is not turbo-gated"

# M6  The SHIPPED row is edited -- the one thing `lionbuild` promises it does not
#     touch.  A default-behaviour change hidden in a commit about a gated
#     candidate is exactly the shape §2 exists to refuse.
python3 - <<'PY' || { echo 'ABORT: M6 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = '\t\t\t\t\t\t{1,3,1,2,3,6,1,1,3,3,6,2,2,2,6},\n'
new = '\t\t\t\t\t\t{1,3,1,2,3,6,1,1,3,2,6,3,2,2,6},\n'
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 shipped row edited -> the gate-off inertness pin must red" \
    "sold as inert when unarmed"

# M7  The KV column the case is priced off moves, the way a patch moves it: the
#     Hex cooldown stops falling with rank.  The prose in hero_lion.lua argues
#     24s -> 12s; §5 is how the next reader learns the argument went stale
#     instead of inheriting it.
python3 - <<'PY' || { echo 'ABORT: M7 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['AbilityCooldown'] = { base = '24 20 16 12', bonus = { ['special_bonus_unique_lion_5'] = '-2.0' } },"
new = "['AbilityCooldown'] = { base = '24 20 16 16', bonus = { ['special_bonus_unique_lion_5'] = '-2.0' } },"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 Hex cooldown column flattened -> the KV pin must red" \
    "prices the swap off these columns"

# M8  The Drain's fourth rank is flattened in the KV -- the COST side of the
#     trade.  A stand that only mutates the gain side would let a file that
#     oversells the candidate pass; this is the mutant that says the cost
#     assertion is load-bearing too.
python3 - <<'PY' || { echo 'ABORT: M8 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
old = "['mana_per_second'] = { base = '20 40 60 120', bonus = {  } },"
new = "['mana_per_second'] = { base = '20 40 60 60', bonus = {  } },"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 Drain rank-4 refill flattened -> the cost-side pin must red" \
    "prices the swap off these columns"

# M9  The armed row is made a NON-permutation: a Finger point is spent on the
#     Hex instead.  It still strands the Drain, so the strand assertion alone
#     would pass it; what must catch it is the multiset check that backs the
#     phrase "same points, different order".
python3 - <<'PY' || { echo 'ABORT: M9 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = '{1,3,1,2,2,6,1,1,2,2,6,3,3,3,6},--Hex maxed instead of Mana Drain'
new = '{1,3,1,2,2,6,1,1,2,2,2,3,3,3,6},--Hex maxed instead of Mana Drain'
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 armed row is not a permutation -> the multiset pin must red" \
    "candidate claims a PERMUTATION"

echo
echo "mutants killed: $pass   survived/wrong-message: $fail"
[ "$fail" -eq 0 ] || exit 1
