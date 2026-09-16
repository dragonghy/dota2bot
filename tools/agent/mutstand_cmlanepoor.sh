#!/usr/bin/env bash
# Mutation stand for tests/test_cm_lane_fallback_wallet.lua
# (hero 2026-09-16, the `cmlanepoor` lever -- X.ConsiderW's 对线期消耗 block
# ships a LAST firing point that is its FIRST one with both of the first one's
# conditions deleted).  Each mutant breaks ONE thing that file claims; a mutant
# that SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so a source-shape
# mutant is usually caught by §1 no matter which later section it aims at.
# Claiming otherwise is claiming a kill that did not happen.
#
# ⭐ EVERY heredoc carries `||` and every anchor carries an exact-count assert
# (GH #846).  An unguarded heredoc whose `assert` fails writes NOTHING and
# exits non-zero into a shell that ignores it, so the run then measures the
# PRISTINE tree and scores a mutant that never existed.
#
# ⭐ FOUR OF THESE MUTATE THE TEST, NOT THE LEVER (M9, M10, M12, M13), and they
# are the ones that matter most.  This lever's headline readings are COUNTS over
# a corpus and a ZERO at branch layer, and a broken instrument produces both for
# free: a file walk that quietly stops being exhaustive (M9), a comment counted
# as code (M10), an injection that silently does not take (M12), a unit filter
# that selects nobody (M13).
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `cmlanepoor` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.  (§2.4 arms the real switch
#     through tests/mock/soak_side.lua, which is the checked way.)
#   * deleting frames from the corpus.  The corpus is the evidence, not the
#     assertion.  M9/M13 mutate how the file READS it, which is the assertion.
#   * editing X.ConsiderW's OTHER firing points (击杀 / 打断TP / 团战 / 保护自己).
#     Those belong to `cmwhit`, `cmwface`, `cmtfclock` and the shipped tree.
#     M8 is the one exception and it is deliberate: sub-branch 1 is not a
#     neighbour here, it is the premise of §1.1's reachability argument.
#
# Usage: bash tools/agent/mutstand_cmlanepoor.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_cm_lane_fallback_wallet.lua
CM=bots/BotLib/hero_crystal_maiden.lua
JMZ=bots/FunLib/jmz_func.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$CM" "$JMZ"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$CM" "$JMZ"; do
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
	out=$(lua5.1 tests/run_tests.lua cm_lane_fallback_wallet 2>&1)
	if echo "$out" | grep -q "0 failures"; then
		echo "SURVIVED  $name  -- the suite stayed green"
		fail=$((fail + 1))
	elif echo "$out" | grep -qF "$want"; then
		echo "killed    $name"
		pass=$((pass + 1))
	else
		echo "WRONG MESSAGE  $name  -- red, but not on the assertion aimed at"
		echo "$out" | grep -A3 'FAIL' | head -12
		fail=$((fail + 1))
	fi
	restore
}

# Sanity: the pristine tree must be GREEN, or every "killed" below is a lie.
out=$(lua5.1 tests/run_tests.lua cm_lane_fallback_wallet 2>&1)
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
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "J.IsSoakCandidate( 'cmlanepoor' )"
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "J.IsSoakCandidate( 'cmlanepoorXX' )", 1))
PY
run "M1 gate id renamed -> the id pin must red" "not \`cmlanepoor\`"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmlanepoor' ) ) then return true end"
new = "if not ( J.IsSoakCandidate( 'cmlanepoor' ) ) then return true end"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "is not turbo-gated"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  A gate naming a second id freezes FALSE
#     the day that id is promoted, and check_armed_wiring.py still calls the
#     site WIRED.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "J.IsModeTurbo() and J.IsSoakCandidate( 'cmlanepoor' )"
new = "J.IsModeTurbo() and J.IsSoakCandidate( 'cmlaneband' ) and J.IsSoakCandidate( 'cmlanepoor' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 sibling id conjoined -> pullcad pin must red" "candidate ids, expected 1"

# M4  The call site is reverted to the shipped conjunct.  The helper still
#     exists, the gate still exists, check_armed_wiring.py still calls it
#     WIRED, and the lever measures nothing in every wave it ever rides.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "\n\t\t\tand X.cm_IsLaneFallbackAffordable( nMP > 0.5 or bot:GetMana() > nKeepMana )"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "", 1))
PY
run "M4 call site reverted -> the wiring pin must red" "call site in bots/BotLib/hero_crystal_maiden.lua, found 0"

# M5  ⭐ THE LEVER INVERTS: armed ADMITS exactly when the wallet said no.  That
#     turns a subset lever into a superset one, i.e. the opposite direction from
#     the one §0.3 promises and the one any wave reading would be attributed to.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "\treturn bShippedWallet\n\nend"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "\treturn not bShippedWallet\n\nend", 1))
PY
run "M5 armed answer inverted -> direction must red" "armed with a failing wallet must refuse"

# M6  Gate OFF stops being inert: the unarmed answer becomes `false`, so the
#     shipped tree changes in every real game.  That is the one thing a soak
#     candidate may never do, and it is invisible to any test that only ever
#     looks at the armed leg.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "J.IsSoakCandidate( 'cmlanepoor' ) ) then return true end"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "J.IsSoakCandidate( 'cmlanepoor' ) ) then return false end", 1))
PY
run "M6 gate-off answer flipped -> inertness must red" "gate off this conjunct has to be a no-op"

# M7  The shipped reserve moves (220 -> 20).  The lever rations against
#     nKeepMana, so a file that quietly re-prices it ships a different bot with
#     every assertion about the LEVER still green.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "\tnKeepMana = 220"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "\tnKeepMana = 20", 1))
PY
run "M7 shipped mana reserve re-priced -> the anchor pin must red" "the shipped mana reserve moved off 220"

# M8  ⭐ The PREMISE of §1.1: sub-branch 1 loses its `not J.IsDisabled` term.
#     The whole "the last firing point is reached BECAUSE one of two terms
#     refused" argument is about those two terms; with one gone the header's
#     reasoning is false while the lever itself still works perfectly.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "\t\t\t\tand not J.IsDisabled( nWeakestEnemyHeroInRange )\n\t\t\tthen\n\t\t\t\treturn BOT_ACTION_DESIRE_HIGH, nWeakestEnemyHeroInRange"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "\t\t\tthen\n\t\t\t\treturn BOT_ACTION_DESIRE_HIGH, nWeakestEnemyHeroInRange", 1))
PY
run "M8 sub-branch 1 loses its waste test -> the reachability pin must red" "lost its \`not J.IsDisabled\` term"

# M9  ⭐ INSTRUMENT.  The corpus file walk quietly stops being exhaustive.  Both
#     directories still yield frames, so the `n > 0` guard is satisfied and the
#     counts simply come back smaller -- the failure mode
#     test_lion_ult_reserve_domain.lua has on record.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_cm_lane_fallback_wallet.lua'
s = open(p).read()
old = "if name:match('^f_.*%.lua$') then"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "if name:match('^f_2609.*%.lua$') then", 1))
PY
run "M9 corpus walk silently narrowed -> the gate-layer counts must red" "(was 70 when written)"

# M10 ⭐ INSTRUMENT.  read_code stops stripping line comments, so this lever's
#     own header -- which QUOTES the shipped disjunction it is about -- starts
#     being counted as code.  The `nMP > 0.5` census then reads 3 where the tree
#     holds 2, and every source-shape claim in §1 is being made about prose.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_cm_lane_fallback_wallet.lua'
s = open(p).read()
old = "out[#out + 1] = line:gsub('%-%-.*$', '')"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "out[#out + 1] = line", 1))
PY
run "M10 comment stripper disabled -> the code-vs-prose census must red" "times in the CODE of"

# M11 The shipped disjunction is rebuilt INSIDE the helper instead of being
#     passed in.  Behaviour is identical; what breaks is
#     tests/_cm_t10_payoff_sweep.lua, which parses this file's mana gates out of
#     the source text and would silently model one gate fewer.  GH #650's family
#     -- a census whose subject moved out from under it.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "function X.cm_IsLaneFallbackAffordable( bShippedWallet )"
assert s.count(old) == 1, 'M11 anchor not found exactly once'
s = s.replace(old, "function X.cm_IsLaneFallbackAffordable( bShippedWallet )\n\n\tbShippedWallet = nMP > 0.5 or bot:GetMana() > nKeepMana", 1)
open(p, 'w').write(s)
PY
run "M11 wallet expression hidden inside the helper -> the sweep pin must red" "rebuilds the wallet expression itself"

# M12 ⭐ INSTRUMENT.  `inject` stops writing the spec entry, so every injection
#     in §5 silently does not take.  The two declared counterfactuals are then
#     not applied, the block stays unreachable, and "the lever changed nothing"
#     and "the drive never happened" look identical.
#     ⚠️ THE FIRST VERSION OF THIS MUTANT SURVIVED and the finding is recorded
#     rather than scored away: it deleted the OTHER line (`rawset(h, k, nil)`,
#     the cache drop) and the suite stayed GREEN, because every injection in
#     this file happens before anything has called the method.  The cache drop
#     is defensive here, not load-bearing, and the test's own comment now says
#     so instead of repeating the house claim.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_cm_lane_fallback_wallet.lua'
s = open(p).read()
old = "    rawget(h, '__spec')[k] = v\n    rawset(h, k, nil)"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "    rawset(h, k, nil)", 1))
PY
run "M12 injections silently do not take -> the end-to-end drive must red" "the shipped tree must bid HIGH here"

# M13 ⭐ INSTRUMENT.  The corpus row filter selects DEAD Crystal Maidens.  The
#     walk is still exhaustive, `#tRows > 0` still holds, and the counts are
#     simply about a different population -- so the branch-layer ZERO would be
#     about a set nobody meant to ask about.  "Measured zero" and "measured the
#     wrong thing" are the same integer without this.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_cm_lane_fallback_wallet.lua'
s = open(p).read()
old = "if u.name == UNIT and u.alive ~= false then present = true end\n            end\n            if present then\n                local J, bot = rf.load(path, UNIT)"
assert s.count(old) == 1, 'M13 anchor not found exactly once'
new = old.replace("u.alive ~= false", "u.alive == false")
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M13 corpus row filter selects the wrong population -> the counts must red" "live-CM instants:"

echo
echo "mutants killed: $pass    survived/wrong: $fail"
[ "$fail" -eq 0 ] || exit 1
