#!/usr/bin/env bash
# Mutation stand for tests/test_roshdps_team_sum.lua
# (strategy 2026-09-16, the `roshdps` lever -- J.HasEnoughDPSForRoshan divides a
# GROUP dps total by the party size and compares the per-hero MEAN against a bar
# derived for the group).
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1).
#
# ⚠️ EVERY MUTATION IS FENCED (`|| exit 2` on the heredoc, plus an anchor-count
# assert inside it).  GH #846: a mutant that never got applied is scored on an
# UNMUTATED tree and reads as a clean sweep.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about" -- run_tests.lua sorts test names.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming 'roshdps' in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#   * changing plannedTimeToKill from 60.  §1 pins it as a NUMBER QUOTED IN THE
#     REPORT, not as the lever; a mutant there tests the pin's wording, and the
#     pin already says what it is for.
#
# Usage: bash tools/agent/mutstand_roshdps.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_roshdps_team_sum.lua
JMZ=bots/FunLib/jmz_func.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$JMZ"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$JMZ"; do
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
	out=$(lua5.1 tests/run_tests.lua roshdps 2>&1)
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
out=$(lua5.1 tests/run_tests.lua roshdps 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The gate id is renamed: arming the published string moves nothing.  The
#     silent-no-op shape check_armed_wiring.py cannot see (a call site exists,
#     the predicate is simply unreachable by any wave).
python3 - <<'PY' || { echo 'ABORT: M1 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
assert s.count("IsSoakCandidate( 'roshdps' )") == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace("IsSoakCandidate( 'roshdps' )",
                             "IsSoakCandidate( 'roshdpsXX' )", 1))
PY
run "M1 gate id renamed -> the id pin must red" "is no longer 'roshdps'"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only;
#     without this the id would change a NORMAL-MODE game.
python3 - <<'PY' || { echo 'ABORT: M2 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "\tif not J.IsSoakCandidate( 'roshdps' ) then return false end\n\tif not J.IsModeTurbo() then return false end"
new = "\tif not J.IsSoakCandidate( 'roshdps' ) then return false end"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> helper shape must red" \
    "gate-first-then-turbo"

# M3  The pullcad trap: a SIBLING id ANDed into the helper's condition.  Frozen
#     FALSE the day that id is promoted, and check_armed_wiring.py still calls
#     it WIRED.
python3 - <<'PY' || { echo 'ABORT: M3 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "\tif not J.IsSoakCandidate( 'roshdps' ) then return false end"
new = ("\tif not J.IsSoakCandidate( 'roshdps' ) then return false end\n"
       "\tif not J.IsSoakCandidate( 'roshgate' ) then return false end")
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 pullcad trap (sibling id ANDed in) -> must red" \
    "candidate ids; a second one"

# M4  ⭐ THE LEVER ITSELF, UN-GATED: the division is deleted outright, so every
#     shipped game changes.  This is the mutant that proves the un-armed
#     inertness proof (§4) is load-bearing and not decorative.
python3 - <<'PY' || { echo 'ABORT: M4 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "    DPS =  DPS / #heroes"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "    DPS =  DPS", 1))
PY
run "M4 division deleted un-gated -> the shipped-expression pin must red" \
    "the shipped division is gone"

# M5  The gate is inverted: un-armed takes the SUM, armed takes the mean.  The
#     suite must not be satisfied by "the two legs differ" -- it has to know
#     which leg is which.
python3 - <<'PY' || { echo 'ABORT: M5 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "    local nDPS = DPS\n    if J.ShouldRateRoshanDpsAsTeamSum() then nDPS = nTeamDPS end"
new = "    local nDPS = nTeamDPS\n    if J.ShouldRateRoshanDpsAsTeamSum() then nDPS = DPS end"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 gate inverted (un-armed becomes the sum) -> must red" \
    "no longer DEFAULTS to the divided value"

# M6  The armed leg reads a THIRD thing (half the sum) instead of the group
#     total -- a plausible "compromise" edit that the direction claim does not
#     cover and §4's armed-equals-`sum >= bar` case must catch.
python3 - <<'PY' || { echo 'ABORT: M6 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "if J.ShouldRateRoshanDpsAsTeamSum() then nDPS = nTeamDPS end"
new = "if J.ShouldRateRoshanDpsAsTeamSum() then nDPS = nTeamDPS / 2 end"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 armed leg reads half the sum -> must red" \
    "not \`nDPS = nTeamDPS\`"

# M7  nTeamDPS is captured AFTER the division, so the armed leg silently
#     becomes the mean too: an armed wave that measures nothing and reports
#     "tested, no effect".
python3 - <<'PY' || { echo 'ABORT: M7 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "    local nTeamDPS = DPS\n    DPS =  DPS / #heroes"
new = "    DPS =  DPS / #heroes\n    local nTeamDPS = DPS"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` names the ORDER pin in §1, added after the first run of this stand
#    showed the §4 proof catching M7 while the site pin (presence only) did not.
run "M7 sum captured after the division -> armed becomes inert, must red" \
    "captured AFTER the shipped division"

# M8  The bar is scaled by the party size instead -- the OTHER way to make the
#     units agree.  It is not this lever (it changes the un-armed default in
#     every shipped game), and the un-armed pin must say so.
python3 - <<'PY' || { echo 'ABORT: M8 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "    DPSThreshold = roshanHealth / plannedTimeToKill"
new = "    DPSThreshold = roshanHealth / plannedTimeToKill / #heroes"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ The first version of this pin matched a SUBSTRING, so appending `/ #heroes`
#    to the bar left it green and the kill came from §4 instead. The pin is now
#    anchored to the end of the statement; this `want` is that anchored message.
run "M8 bar divided by party size instead -> un-armed pin must red" \
    "no longer exactly roshanHealth / plannedTimeToKill"

# M9  ⭐ THE CORPUS HALF.  The divisor sweep counts every hero slot instead of
#     the subject's ALIVE allies, so §5 W2 would be reading a constant 10 and
#     calling it the divisor.
python3 - <<'PY' || { echo 'ABORT: M9 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_roshdps_team_sum.lua'
s = open(p).read()
old = "                if u.team == sSelfTeam and u.alive then nAlive = nAlive + 1 end"
new = "                nAlive = nAlive + 1"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⭐ THIS ONE SURVIVED the first run and that is why the upper pin exists: with
#    only "mean > 1 / max >= 4 / some frame has 3", a sweep reading a constant
#    10 passes every assertion. `want` is the upper pin it now trips.
run "M9 divisor sweep counts all slots -> the max-alive pin must red" \
    "A party has five"

# M10 ⭐ THE REVERSE CALL.  The W1 scanner is broken (it looks for a key that
#     cannot exist), so "no dps field in the dump" would be a FALSE ZERO of
#     exactly the 0NEXT28 shape.  The reverse call is what must notice.
python3 - <<'PY' || { echo 'ABORT: M10 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_roshdps_team_sum.lua'
s = open(p).read()
old = "                    if sK == 'max_hp' then s.nHpFields = s.nHpFields + 1 end"
new = "                    if sK == 'max_hp_XX' then s.nHpFields = s.nHpFields + 1 end"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 reverse call disabled -> W1 must refuse to call the zero an absence" \
    "scanner cannot find max_hp either"

# CONTROL  A comment-only edit.  If this "kills", the stand is measuring noise.
python3 - <<'PY' || { echo 'ABORT: control failed to apply.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "-- [roshdps, strategy 2026-09-16] THE ROSHAN BAR IS A TEAM BAR"
assert s.count(old) == 1, 'control anchor not found exactly once'
open(p, 'w').write(s.replace(old, old + " (control edit)", 1))
PY
out=$(lua5.1 tests/run_tests.lua roshdps 2>&1)
if echo "$out" | grep -q "0 failures"; then
	echo "SURVIVED  CONTROL comment-only edit  -- correct, the stand is not noisy"
	pass=$((pass + 1))
else
	echo "CONTROL KILLED -- a comment moved the suite. Every kill above is suspect."
	echo "$out" | grep -A3 'FAIL' | head -10
	fail=$((fail + 1))
fi
restore

echo
echo "mutstand roshdps: $pass as expected, $fail not"
[ "$fail" -eq 0 ] || exit 3
