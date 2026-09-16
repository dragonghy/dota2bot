#!/usr/bin/env bash
# Mutation stand for tests/test_axe_q_lane_push_nocap.lua
# (hero 2026-09-16, the `axecallnocap` lever -- whether X.ConsiderQ's 带线 firing
# point should carry an ally-crowd cap AT ALL; `axecallcrowd` raised the cap to
# 4 and the state it keeps refusing is the full five-man grouped push).
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ EVERY MUTATION IS FENCED (`|| exit 2` on the heredoc, plus an anchor-count
# assert inside it).  GH #846: a mutant that never got applied is scored on an
# UNMUTATED tree, and the axecullbm M9 case shows that reads as "12/12" for a
# whole round.  The fence is not optional decoration.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so a mutant aimed
# at §5 is often caught by a §3 count that moved with it -- and that is a
# BETTER message, not a worse one, as long as the stand says which.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `axecallnocap` in bots/Customize/soak_side.lua.  That is the
#     change itself, not a mutation of an assertion.
#   * dropping `#laneCreepList >= 4`.  The end-to-end domain is 0 either way
#     (GH #772), so it would SURVIVE, and honestly so.  A stand entry known to
#     survive teaches nothing.
#   * shrinking the ally radius to 400.  §2.3 of the CROWD test owns that
#     measurement; here it is a different question and the red would be about
#     the other lever.
#
# Usage: bash tools/agent/mutstand_axecallnocap.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_axe_q_lane_push_nocap.lua
AXE=bots/BotLib/hero_axe.lua
KV=tests/mock/special_value_shapes.lua

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
	out=$(lua5.1 tests/run_tests.lua axe_q_lane_push_nocap 2>&1)
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
out=$(lua5.1 tests/run_tests.lua axe_q_lane_push_nocap 2>&1)
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
assert s.count("'axecallnocap'") == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace("'axecallnocap'", "'axecallnocapXX'", 1))
PY
run "M1 gate id renamed -> the single-id pin must red" \
    "no longer names axecallnocap"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only, and
#     without this the id would change a NORMAL-MODE game.
python3 - <<'PY' || { echo 'ABORT: M2 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\tif J.IsModeTurbo() and J.IsSoakCandidate( 'axecallnocap' )"
new = "\tif J.IsSoakCandidate( 'axecallnocap' )"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "lost its turbo guard"

# M3  The pullcad trap, written the way it actually gets written: the SIBLING id
#     on the same `if` ANDed into this condition.  Frozen FALSE the day
#     axecallcrowd is promoted, and check_armed_wiring.py still calls it WIRED.
python3 - <<'PY' || { echo 'ABORT: M3 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.IsModeTurbo() and J.IsSoakCandidate( 'axecallnocap' )"
new = ("J.IsModeTurbo() and J.IsSoakCandidate( 'axecallnocap' )"
       " and J.IsSoakCandidate( 'axecallcrowd' )")
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is the ONE-ID COUNT, not the "names a second id" loop below it in
#    §1.1: the count assertion sits earlier in the same test body and fires
#    first.  That is the better message -- it names the arity, not just the
#    stranger -- and claiming the loop's message would be claiming a kill this
#    stand did not make.
run "M3 pullcad trap (sibling id ANDed in) -> must red" \
    "must hold exactly ONE IsSoakCandidate call"

# M4  The gate is armed but INERT: the armed leg answers false, so the id is a
#     construction-zero lever with a perfectly correct header (GH #838 shape).
python3 - <<'PY' || { echo 'ABORT: M4 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = """	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallnocap' )
	then
		return true
	end
"""
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, old.replace('return true', 'return false'), 1))
PY
run "M4 armed leg made inert -> the constant-true drive must red" \
    "this id is supposed to DELETE the conjunct"

# M5  The gate leaks: the helper answers true with the id UNARMED, so shipped
#     behaviour changed in every real Turbo game.  This is the one mutant whose
#     survival would mean the branch is live rather than dark.
python3 - <<'PY' || { echo 'ABORT: M5 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = """		return true
	end

	return false

end"""
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, old.replace('return false', 'return true'), 1))
PY
run "M5 gate-off leaks true -> the inertness drive must red" \
    "it is not inert"

# M6  The call site's disjunction is REORDERED so the gate is consulted first.
#     Behaviour is identical (`or` is commutative here) -- which is exactly why
#     the shape pin has to exist: §1.2 is what `call_site()` in the test rests
#     on, and a reader who edits the source must be told the mirror moved.
python3 - <<'PY' || { echo 'ABORT: M6 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = ("\t\tand ( X.axe_IsLanePushCrowdOpen( #hAllyList )\n"
       "\t\t\t\tor X.axe_IsLanePushCrowdCapOff() )")
new = ("\t\tand ( X.axe_IsLanePushCrowdCapOff()\n"
       "\t\t\t\tor X.axe_IsLanePushCrowdOpen( #hAllyList ) )")
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 call site disjunction reordered -> the shape pin must red" \
    "is no longer"

# M7  `#hEnemyList == 0` leaves the 带线 `if`.  That conjunct is what makes the
#     branch a PUSH rather than a fight; LIMIT 2 and the whole safety argument
#     rest on it being there.
python3 - <<'PY' || { echo 'ABORT: M7 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
# `and #hEnemyList == 0` occurs TWICE in this file (the other one is a
# different branch), so the anchor carries the line above it.
old = "or X.axe_IsLanePushCrowdCapOff() )\n\t\tand #hEnemyList == 0\n"
new = "or X.axe_IsLanePushCrowdCapOff() )\n"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 the safety conjunct deleted -> the census must red" \
    "left the 带线"

# M8  `J.IsAllowedToSpam` leaves the same `if`.  The header's "the cap is not a
#     mana rationer" argument is BECAUSE a mana rationer is already there.
python3 - <<'PY' || { echo 'ABORT: M8 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\tand J.IsAllowedToSpam( bot, nManaCost )\n\t\tand bot:GetAttackTarget() ~= nil"
new = "\t\tand bot:GetAttackTarget() ~= nil"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 the mana rationer deleted -> the census must red" \
    "J.IsAllowedToSpam left the 带线"

# M9  The ALLY ring shrinks.  Every count in the test file is over 1600u.
python3 - <<'PY' || { echo 'ABORT: M9 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "hAllyList = J.GetAlliesNearLoc( bot:GetLocation(), 1600 )"
new = "hAllyList = J.GetAlliesNearLoc( bot:GetLocation(), 1200 )"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ MEASURED, and worth knowing: 1200u moves NOTHING in §3.1/§3.2 -- not the
#    11/15/16, not the separating frame's 5 allies.  That is the same finding
#    the CROWD round bought (§2.3 there: the radius is true and not
#    load-bearing), reproduced from the other side.  So §5.3 is the ONLY
#    assertion standing between this file's counts and a silently different
#    ring, and that is why it is a source read rather than prose.
run "M9 ally ring 1600 -> 1200 -> only the ring pin catches it" \
    "hAllyList is now built with radius 1200"

# M10 The ENEMY ring shrinks while the ally ring stays.  The two conjuncts then
#     describe different rings and "no enemy in view" stops being the safety
#     term the cap was supposed to be redundant with -- without either LINE
#     looking wrong on its own.
python3 - <<'PY' || { echo 'ABORT: M10 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "hEnemyList = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )"
new = "hEnemyList = J.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE )"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 enemy ring shrinks, ally ring does not -> the ring pin must red" \
    "hEnemyList is now built with radius 800"

# M11 The KV cooldown moves.  §0.1's cooldown-rationing argument is about real
#     seconds; the test reads them off the KV so the prose cannot drift alone.
python3 - <<'PY' || { echo 'ABORT: M11 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
i = s.index("['axe_berserkers_call']")
j = s.index("['axe_counter_helix']")
blk = s[i:j]
old = "['AbilityCooldown'] = { base = '18 16 14 12'"
assert blk.count(old) == 1, 'M11 anchor not found exactly once in the Call block'
open(p, 'w').write(s[:i] + blk.replace(old, old.replace('18 16 14 12', '20 18 16 14'), 1) + s[j:])
PY
run "M11 Call cooldown KV moved -> the source-read must red" \
    "AbilityCooldown reads"

# M12 The ARMED CAP is raised to 5, which deletes `axecallcrowd`'s conjunct and
#     therefore erases the one instant that separates the two ids.  The stand's
#     point: LIMIT 1's "exactly 1" is a measurement, not a sentence.
python3 - <<'PY' || { echo 'ABORT: M12 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = 'X.nQLanePushAllyCapTurbo   = 4'
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, 'X.nQLanePushAllyCapTurbo   = 5', 1))
PY
# The first message is §3.1's sibling count (15 -> 16), and §3.2's
# "no longer exceeds the armed cap" reds in the same run -- i.e. the stand
# shows BOTH halves of LIMIT 1 are measurements.
run "M12 armed cap raised to 5 -> the 1-instant separation must red" \
    "armed admits 16 Axe instants"

# M13 The SHIPPED cap is raised to 3.  §3.1's 11 is a statement about `<= 2`.
python3 - <<'PY' || { echo 'ABORT: M13 failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = 'X.nQLanePushAllyCapShipped = 2'
assert s.count(old) == 1, 'M13 anchor not found exactly once'
open(p, 'w').write(s.replace(old, 'X.nQLanePushAllyCapShipped = 3', 1))
PY
run "M13 shipped cap raised to 3 -> the shipped domain must red" \
    "shipped admits 12 Axe instants"

echo
echo "mutation stand: $pass killed, $fail survived-or-wrong-message"
[ "$fail" -eq 0 ] || exit 1
