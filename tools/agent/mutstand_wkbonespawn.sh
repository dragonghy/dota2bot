#!/usr/bin/env bash
# Mutation stand for tests/test_wk_bone_guard_stock_gate.lua
# (hero 2026-09-14, the `wkbonespawn` empty-bank release lever).
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1,
# and the gap tools/agent/py_gate.py caught on this desk's stand two rounds
# ago): a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so the order is
# section 1, 2, 2b, 3, 4, 5, 6 -- and a source-shape mutant is usually caught
# by section 1 before the section it was aimed at ever runs.  Getting this
# wrong is the WRONG MESSAGE result the -170/-172/-173 rounds hit three times.
#
# ⛔ TWO MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * deleting the `hRow == nil` guard.  Nothing in the corpus produces a nil
#     t20 handle (the loader always answers a handle), so the mutant is
#     unobservable rather than surviving.  It is a defensive line, and the
#     file says so instead of pretending a test covers it.
#   * arming `wkbonespawn` for real in soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#
# ⭐ AND TWO THAT ARE HERE EXPECTED TO SURVIVE (S1, S2 at the bottom).  Each
# pins a LIMIT the test file states in prose; a survivor is a PASS and a RED
# is the finding, because it means the prose went stale.  Counting a declared
# limit as a failure would have pushed this desk to strengthen an assertion
# that cannot be strengthened on this corpus.
#
# Usage: bash tools/agent/mutstand_wkbonespawn.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_wk_bone_guard_stock_gate.lua
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
	out=$(lua5.1 tests/run_tests.lua wk_bone_guard_stock_gate 2>&1)
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
sed -i "s/'wkbonespawn'/'wkbonespawnXX'/g" "$WK"
run "M1 gate id renamed -> section 1 must red" "must be the turbo+candidate gate"

# M2  The helper moves to the LEFT of the `or`, so it is consulted on frames the
#     shipped chain answers without it.  That destroys the world-A no-op, and it
#     is invisible to every behavioural assertion in world B.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ('\t\tor not ( bot:HasModifier( "modifier_skeleton_king_bone_guard" )\n'
       '\t\t\t\t\tor X.wk_IsBoneGuardEmptyBankOpen() )\n')
new = ('\t\tor not ( X.wk_IsBoneGuardEmptyBankOpen()\n'
       '\t\t\t\t\tor bot:HasModifier( "modifier_skeleton_king_bone_guard" ) )\n')
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 helper moved left of the or -> section 1 must red" \
    "the second disjunct of X.ConsiderW is not"

# M3  The `== true` comparison is dropped on the ARGUMENT path, so any truthy
#     answer from an unimplemented reader arms the lever.
sed -i "s/if hTalent ~= nil then return hTalent:IsTrained() == true end/if hTalent ~= nil then return hTalent:IsTrained() end/" "$WK"
run "M3 == true dropped -> section 2 must red" \
    "a non-boolean truthy answer opened the gate"

# M4  The talent conjunct is dropped: armed, the lever opens an empty-bank
#     release with the t20 row UNTRAINED -- zero skeletons, 42s cooldown burned.
#     This is the mutant that matters most; it is the whole safety argument.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ('\tif hTalent ~= nil then return hTalent:IsTrained() == true end\n'
       '\n\treturn talent6 ~= nil and talent6:IsTrained() == true\n')
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, '\treturn true\n', 1))
PY
run "M4 talent conjunct dropped -> section 2 must red" "armed + UNTRAINED must refuse"

# M5  The argument is ignored and the file-scope handle is always used.  The
#     call site is unaffected (it passes nothing), so only a test that hands the
#     helper a talent state can notice -- which is the reason the parameter
#     exists at all.
sed -i "s/if hTalent ~= nil then return hTalent:IsTrained() == true end/if hTalent == nil then return false end/" "$WK"
run "M5 argument ignored -> section 2 must red" "armed + trained must open"

# M8  The nil guard on the file-scope read goes, leaving an unguarded read of
#     a handle GH #366's level wall can leave untrainable -- the shape
#     `zusboltcap` (GH #175) shipped.  tests/test_focus_talent_reach_wall.lua
#     section 3 catches it too; it is asserted HERE as well so this file
#     defends its own shape instead of waiting for another file's detector to
#     be run by somebody else next round.
sed -i "s/return talent6 ~= nil and talent6:IsTrained() == true/return talent6:IsTrained() == true/" "$WK"
run "M8 nil guard dropped -> section 1 must red" "is no longer"

# M6  The census loses the split that makes its zero mean anything: every WK
#     frame joins the "informative" bucket, including the 14 with no modifier
#     list at all, so "0 carry the charge modifier" stops distinguishing "does
#     not carry it" from "the pipeline recorded nothing".
sed -i "s/if row.hasList then/if true then/g" "$TEST"
run "M6 informative split dropped -> section 3 must red" "informative frames"

# M7  A SECOND call site appears inside branch 2.  Every behavioural reading in
#     sections 2-4 stays true and the direction argument silently acquires a
#     second place to come from.
#     ⚠️ IT IS THE WORLD-A LEG THAT CATCHES THIS, and the first `want` written
#        here named world B and scored WRONG MESSAGE.  Mechanism, worth keeping:
#        in world B the top guard REFUSES (the t20 row reads untrained on a
#        fixture), so branch 2 -- and the injected second call with it -- is
#        never reached and world B still counts exactly 1.  In world A the guard
#        passes, branch 2 runs, and the count that must be 0 reads 1.  Same trap
#        shape as -170/-172/-173: the regex/leg that fires first is not the one
#        the mutant is "about".
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = '\tif ( nStack == maxStack or talent6:IsTrained() )\n'
new = '\tif ( nStack == maxStack or talent6:IsTrained() or X.wk_IsBoneGuardEmptyBankOpen() )\n'
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 second call site added -> section 5 (world A leg) must red" \
    "was still called 1 times"

# --------------------------------------------------------------------------
# DECLARED SURVIVORS.  Two mutants are EXPECTED to leave the suite green, and
# they are run rather than described because each one pins a LIMIT the test
# file states in prose: if a future corpus makes one of them killable, the
# prose is what has gone stale, and this stand says so instead of silently
# getting stronger.  A survivor here is a PASS; a red is the finding.
expect_survive() {
	local name="$1" out
	out=$(lua5.1 tests/run_tests.lua wk_bone_guard_stock_gate 2>&1)
	if echo "$out" | grep -q "0 failures"; then
		echo "survived  $name  (as declared)"
		pass=$((pass + 1))
	else
		echo "NOW KILLED  $name  -- the declared LIMIT is gone; rewrite the note"
		echo "$out" | grep -A3 'FAIL' | head -10
		fail=$((fail + 1))
	fi
	restore
}

# S1  The rank filter.  Declared in the test header: all 33 live WK rows with an
#     abilities table carry Bone Guard at rank >= 1, so the filter excludes
#     nothing today and is kept for the population it NAMES, not for its effect.
sed -i "s/if wlvl ~= nil and wlvl >= 1 then/if wlvl ~= nil then/" "$TEST"
expect_survive "S1 corpus rank filter dropped -- excludes nothing on this corpus"

# S2  Section 7's armed leg is run unarmed.  Declared in the test header: the
#     lever's effect is NOT representable at the function level, because the
#     helper's talent conjunct reads a row the dumper never writes.  So the two
#     legs of section 7 are indistinguishable BY CONSTRUCTION -- which is
#     exactly why section 4 supplies the talent state instead.
sed -i "s/local zA, nA, oA = tally(true)/local zA, nA, oA = tally(false)/" "$TEST"
expect_survive "S2 section 7's armed leg unarmed -- legs are identical by construction"

echo
echo "mutants killed $pass / $((pass + fail))"
[ "$fail" -eq 0 ] || exit 3
