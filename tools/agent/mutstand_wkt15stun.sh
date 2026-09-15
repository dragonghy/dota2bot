#!/usr/bin/env bash
# Mutation stand for tests/test_wk_t15_stun_price.lua
# (hero 2026-09-15, the `wkt15stun` t15 talent lever -- Wraith King's last
# unpriced tier).  Each mutant breaks ONE thing that file claims; a mutant that
# SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, and this file's
# order is [corpus] / "Q holds rank 3" / "[3] has no reader" / "a real ...
# frame" / "shipped t15 takes [4]" / "the t15 pair" / "the wkt15stun gate",
# so a source-shape mutant is often caught upstream of the section it is aimed at.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `wkt15stun` for real in bots/Customize/soak_side.lua.  That is the
#     change itself, not a mutation of an assertion.
#   * editing tAllAbilityBuildList's CONTENT (which ability gets which point).
#     That is gate-off behaviour, which a soak candidate may not touch; a mutant
#     of it tests the shipped build, not this lever's assertions.  M11 mutates
#     the test's READER of that row instead, which is where the real bug was.
#
# Usage: bash tools/agent/mutstand_wkt15stun.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_wk_t15_stun_price.lua
WK=bots/BotLib/hero_skeleton_king.lua
SLOTS=tests/mock/talent_slots.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$WK" "$SLOTS"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$WK" "$SLOTS"; do
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
	out=$(lua5.1 tests/run_tests.lua wk_t15_stun_price 2>&1)
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
out=$(lua5.1 tests/run_tests.lua wk_t15_stun_price 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The gate id is renamed, i.e. arming the published string moves nothing.
#     This is the silent-no-op shape check_armed_wiring.py cannot see (a call
#     site exists; the predicate is simply unreachable by any wave).
sed -i "s/'wkt15stun'/'wkt15stunXX'/g" "$WK"
run "M1 gate id renamed -> the armed-leg parse must red" \
    "no longer has a body this file can parse"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "if J.IsModeTurbo() and J.IsSoakCandidate( 'wkt15stun' ) then"
new = "if J.IsSoakCandidate( 'wkt15stun' ) then"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "is no longer turbo-only"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  Frozen FALSE the day that id is promoted,
#     and check_armed_wiring.py still calls it WIRED.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "if J.IsModeTurbo() and J.IsSoakCandidate( 'wkt15stun' ) then"
new = "if J.IsModeTurbo() and J.IsSoakCandidate( 'wkt10ls' ) and J.IsSoakCandidate( 'wkt15stun' ) then"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 gate names a sibling id -> pullcad guard must red" \
    "other candidate id(s) in its own condition"

# M4  The SHIPPED row is flipped, i.e. the lever stops being dark.  A soak
#     candidate that changes gate-off behaviour is not a soak candidate.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\t\t\t\t\t\t\t['t15'] = {10, 0},"
new = "\t\t\t\t\t\t\t['t15'] = {0, 10},"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 shipped t15 flipped live -> gate-off guard must red" \
    "may not change gate-off behaviour"

# M5  The armed leg writes the SHIPPED pair, i.e. the lever is a byte-level
#     no-op that every automatic reader would still call WIRED.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\ttTalentTreeList['t15'] = {0, 10}"
new = "\ttTalentTreeList['t15'] = {10, 0}"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 armed leg made a no-op -> armed-pair guard must red" \
    "the armed leg now writes"

# M6  The lever WIDENS: it takes a second tier along with its own.  This is the
#     failure the "exactly two queue slots move" bound exists for -- a wave read
#     could no longer be attributed to the t15 talent.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\ttTalentTreeList['t15'] = {0, 10}\nend"
new = "\ttTalentTreeList['t15'] = {0, 10}\n\ttTalentTreeList['t20'] = {0, 10}\nend"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 lever moves a second tier -> confinement bound must red" \
    "queue slots, not 2"

# M7  The pricing PROSE drifts off the arithmetic.  A block that quotes a
#     percentage the KV no longer supports is the silent half of this hazard.
sed -i 's/stun 1\.4 -> 2\.15s   +53\.6%/stun 1.4 -> 2.15s   +60.0%/' "$WK"
run "M7 quoted percentage drifts -> prose ratchet must red" \
    "no longer quotes 53.6%"

# M8  The t15 pair itself moves in the KV snapshot (a rebalance, or a
#     regenerated census).  The price must not survive its own inputs changing.
sed -i "s/name = 'special_bonus_hp_300'/name = 'special_bonus_hp_350'/" "$SLOTS"
run "M8 t15 row renamed in the KV -> pair anchor must red" \
    "not special_bonus_hp_300"

# M9  A reader of blast_stun_duration appears in the hero file, which is exactly
#     what would give this lever the t10 pair's coupling hazard (GH #228).
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tlocal nDotDps = hAbility:GetSpecialValueInt( 'blast_dot_damage' )\n"
new = old + "\tlocal nStun = hAbility:GetSpecialValueFloat( 'blast_stun_duration' )\n"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 a blast_stun_duration reader appears -> inertness half must red" \
    "now reads blast_stun_duration"

# M10 The corpus scan is pointed at a name no fixture carries, so it counts
#     nothing.  A census whose loop never runs asserts nothing, and the ceiling
#     `nHigh < 15` would pass VACUOUSLY (0 < 15) without the lower bound.
sed -i "s/name = 'npc_dota_hero_skeleton_king'(\[^/name = 'npc_dota_hero_skeleton_kingXX'([^/" "$TEST"
run "M10 corpus scan matches nothing -> census liveness must red" \
    "the archive holds 0 Wraith King hero rows"

# M11 The build-row reader goes back to the naive `%d+` sweep this file shipped
#     on its first run.  It swallows the row's own `--pos1,3` trailing comment,
#     hands back SEVENTEEN entries, and silently levels Wraithfire Blast a fifth
#     time.  ⚠️ The `#row == 15` assert is relaxed in the same mutant on purpose:
#     with it in place this mutant only proves that guard fires, and the point is
#     that section 3's rank ladder catches the bad row on its own.
python3 - <<'PY'
p = 'tests/test_wk_t15_stun_price.lua'
s = open(p).read()
old = """    local row = skillmap.build_row(SRC, 1, 'tAllAbilityBuildList')
    assert(#row == 15, 'tAllAbilityBuildList row is ' .. #row"""
new = """    local body = SRC:match('local tAllAbilityBuildList = {(.-)\\n}')
    local row = {}
    for n in body:gmatch('%d+') do row[#row + 1] = tonumber(n) end
    assert(#row >= 15, 'tAllAbilityBuildList row is ' .. #row"""
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 naive build-row parse restored -> rank ladder must red" \
    "times, not 4"

# M12 The talent-slot liveness guard in section 6.  An empty slot list makes
#     "all 8 are nil" true by iterating nothing -- the M10 lesson of
#     tests/test_wk_save_mana_unreachable_cap.lua section 6.1, one file later.
python3 - <<'PY'
p = 'tests/test_wk_t15_stun_price.lua'
s = open(p).read()
old = "    for _, i in ipairs({ 10, 15, 18, 19, 20, 21, 22, 23 }) do"
new = "    for _, i in ipairs({}) do"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 talent-slot list emptied -> section 6 liveness must red" \
    "the talent-slot list under test is 0 long"

echo
echo "mutants killed: $pass    survived/wrong: $fail"
[ "$fail" -eq 0 ] || exit 1
