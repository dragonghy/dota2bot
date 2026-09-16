#!/usr/bin/env bash
# Mutation stand for tests/test_lion_hex_panic_level.lua
# (hero 2026-09-16, the `lionwpanic` lever -- X.ConsiderW's 保护自己 firing
# point is switched off below hero level 10 by a term that measures nothing
# about the situation).  Each mutant breaks ONE thing that file claims; a
# mutant that SURVIVES is an assertion that was not doing work.
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
# ⭐ THREE OF THESE MUTATE THE TEST OR A FILE THE TEST READS, NOT THE LEVER
# (M9, M10, M12), and they are the ones that matter most here.  This lever's
# headline readings are COUNTS over a corpus, and a broken instrument produces
# counts for free: a sweep that quietly stopped being exhaustive (M9), a
# comment counted as code (M10), an enumerator that yields nothing (M12).
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `lionwpanic` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.  (§7.3 arms the real switch
#     through tests/mock/soak_side.lua, which is the checked way.)
#   * moving the frames the corpus holds.  The corpus is the evidence, not the
#     assertion.  M9 mutates how the file READS it, which is the assertion.
#   * editing X.ConsiderW's other firing points (打断 / 团战 / 攻击 / 撤退).
#     Those are `lionwreach`'s and the shipped tree's; mutating them tests
#     tests/test_lion_hex_interrupt_reach.lua.
#
# Usage: bash tools/agent/mutstand_lionwpanic.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_lion_hex_panic_level.lua
LION=bots/BotLib/hero_lion.lua
CM=bots/BotLib/hero_crystal_maiden.lua
JMZ=bots/FunLib/jmz_func.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$LION" "$CM" "$JMZ"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$LION" "$CM" "$JMZ"; do
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
	out=$(lua5.1 tests/run_tests.lua lion_hex_panic_level 2>&1)
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
out=$(lua5.1 tests/run_tests.lua lion_hex_panic_level 2>&1)
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
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "J.IsSoakCandidate( 'lionwpanic' )"
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "J.IsSoakCandidate( 'lionwpanicXX' )", 1))
PY
run "M1 gate id renamed -> the id pin must red" "not \`lionwpanic\`"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "\tif J.IsModeTurbo() and J.IsSoakCandidate( 'lionwpanic' )"
new = "\tif J.IsSoakCandidate( 'lionwpanic' )"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "is not turbo-gated"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  A gate naming a second id freezes FALSE
#     the day that id is promoted, and check_armed_wiring.py still calls the
#     site WIRED.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "if J.IsModeTurbo() and J.IsSoakCandidate( 'lionwpanic' )"
new = "if J.IsModeTurbo() and J.IsSoakCandidate( 'lionwreach' ) and J.IsSoakCandidate( 'lionwpanic' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 sibling id conjoined -> pullcad pin must red" "candidate ids, expected 1"

# M4  The call site is reverted to the shipped conjunct.  The helper still
#     exists, the gate still exists, check_armed_wiring.py still calls it
#     WIRED, and the lever measures nothing in every wave it ever rides.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "and X.lion_IsPanicHexLevelOpen( nLV )"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "and nLV >= 10", 1))
PY
run "M4 call site reverted -> the wiring pin must red" "call site in bots/BotLib/hero_lion.lua, found 0"

# M5  ⭐ THE LEVER INVERTS: armed CLOSES the branch instead of opening it, so
#     arming would delete the defensive Hex above level 10 as well.  Direction
#     is the first thing this file claims and the first thing a wave reading
#     would be attributed to.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "\tif J.IsModeTurbo() and J.IsSoakCandidate( 'lionwpanic' )\n\tthen\n\t\treturn true\n\tend"
new = "\tif J.IsModeTurbo() and J.IsSoakCandidate( 'lionwpanic' )\n\tthen\n\t\treturn false\n\tend"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 armed answer inverted -> direction must red" "armed must be the constant true"

# M6  The cliff edge: `>=` becomes `>`, so a Lion at EXACTLY level 10 loses the
#     branch in the shipped tree.  ⚠️ The corpus alone would not see this if it
#     held no level-10 instant, which is why §7.1 walks 9/10/11 explicitly --
#     the same "no integer sits on the knife edge" hole M7 of
#     mutstand_axecullbm.sh found the expensive way.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "\treturn nHeroLevel >= X.nWPanicLevelShipped"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "\treturn nHeroLevel > X.nWPanicLevelShipped", 1))
PY
run "M6 shipped comparison loses the edge -> gate-off pin must red" "byte for "

# M7  The shipped constant is moved (10 -> 6).  Gate off then ships a DIFFERENT
#     bot than the one main runs, which is the one thing a soak candidate may
#     never do.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
old = "X.nWPanicLevelShipped = 10"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "X.nWPanicLevelShipped = 6", 1))
PY
run "M7 shipped constant moved -> the one-place pin must red" "appears 0 times, expected once"

# M8  The OTHER level term in this file (X.ConsiderQ's `nLV >= 15`) is dragged
#     along.  That is a different firing point with a different premise; a
#     round that quietly widened it too would make a wave reading
#     unattributable to either.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_lion.lua'
s = open(p).read()
# ⚠️ The anchor carries its leading tabs: `nLV >= 15` appears TWICE in the
# file, once as code (X.ConsiderQ) and once inside a doc comment eleven
# functions above it.  A bare anchor would abort here -- and that abort is the
# GH #846 guard doing its job, not a stand fault.
old = "\n\t\tand nLV >= 15\n"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "\n\t\tand nLV >= 12\n", 1))
PY
run "M8 the OTHER firing point is dragged along -> §1.1 must red" "is no longer exactly once"

# M9  ⭐ THE SWEEP QUIETLY STOPS BEING EXHAUSTIVE: the corpus walk drops
#     tests/frames/.  Every count in §3 and §4 then answers about a smaller
#     world and nothing says so.  This is the sister file's recorded failure
#     (test_lion_ult_reserve_domain.lua: a "whole archive" sweep that stopped
#     being whole the day tests/frames/ was created, and stayed green).
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_lion_hex_panic_level.lua'
s = open(p).read()
old = "for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do"
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "for _, dir in ipairs({ FIXTURE_DIR }) do", 1))
PY
run "M9 corpus walk drops tests/frames -> the counts must red" "live-Lion instants below hero level"

# M10 ⭐ A COMMENT IS COUNTED AS CODE: §1.1 reads the raw file again instead of
#     the comment-stripped one.  The helper header QUOTES the shipped
#     comparison it replaced, so the raw read finds `nLV >= 10` three times and
#     the assertion fails -- proving the strip is load-bearing rather than
#     tidiness.  (Last round's `_wkreinctr_sweep.lua`: "a comment is not a
#     caller", same shape, found by a red on somebody else's round.)
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_lion_hex_panic_level.lua'
s = open(p).read()
old = "    local src = read_code(SRC)"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "    local src = read_file(SRC)", 1))
PY
run "M10 §1.1 counts comments as code -> must red" "is still in bots/BotLib/hero_lion.lua"

# M11 The (c) argument's evidence is falsified at its source: Crystal Maiden's
#     own 保护自己 branch grows the level term this lever removes.  §2 is the
#     only thing standing between "the tree already ships this shape" and a
#     sentence nobody re-checks.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_crystal_maiden.lua'
s = open(p).read()
old = "\tif bot:WasRecentlyDamagedByAnyHero( X.nWSelfDefenseDamageWindow )\n\t\tand #nEnemysHeroesInRange >= 1"
new = "\tif bot:WasRecentlyDamagedByAnyHero( X.nWSelfDefenseDamageWindow )\n\t\tand bot:GetLevel() >= 10\n\t\tand #nEnemysHeroesInRange >= 1"
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 the sibling grows a level term -> the (c) evidence must red" "has grown a level term"

# M12 ⭐ THE EMPTY-CORPUS TRAP: the enumerator yields nothing, so every count in
#     §3 and §4 is a claim about the empty set -- including §4's zero, which is
#     the reading this file leans on hardest.  A stand without this mutant
#     cannot tell "measured zero" from "measured nothing".
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_lion_hex_panic_level.lua'
s = open(p).read()
old = "            if name:match('^f_.*%.lua$') then"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "            if name:match('^ZZ_.*%.lua$') then", 1))
PY
run "M12 the corpus enumerator yields nothing -> the guard must red" "yielded no f_*.lua frame"

# M13 J.IsRetreating loses the disjunct that makes relocation possible at all.
#     If that helper really were the complement of the branch's mode test, the
#     helper header's relocation paragraph would be overstating the risk -- and
#     an overstatement nobody re-checks is how a bound drifts.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/FunLib/jmz_func.lua'
s = open(p).read()
old = "\t\t or ( mode == BOT_MODE_EVASIVE_MANEUVERS and bDamagedByAnyHero )\n"
assert s.count(old) == 1, 'M13 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "", 1))
PY
run "M13 J.IsRetreating loses EVASIVE_MANEUVERS -> the bound must red" "no longer answers true under BOT_MODE_EVASIVE_MANEUVERS"

echo
echo "mutstand_lionwpanic: $pass killed, $fail survived/wrong-message"
[ "$fail" -eq 0 ] || exit 1
