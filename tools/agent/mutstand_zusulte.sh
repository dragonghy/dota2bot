#!/usr/bin/env bash
# Mutation stand for tests/test_zuus_jump_ult_reserve.lua
# (hero 2026-09-16, the `zusulte` lever -- the ult-mana reserve's FIFTH
# consumer, Heavenly Jump).  Each mutant breaks ONE thing that file claims; a
# mutant that SURVIVES is an assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so a source-shape
# mutant is usually caught by section 1 no matter which later section it aims
# at.  Claiming otherwise is claiming a kill that did not happen.
#
# ⭐ EVERY heredoc carries `||` and every anchor carries an exact-count assert
# (GH #846).  An unguarded heredoc whose `assert` fails writes NOTHING and
# exits non-zero into a shell that ignores it, so the run then measures the
# PRISTINE tree and scores a mutant that never existed.  That is not a
# hypothetical: mutstand_axecullbm.sh reported "12/12" on 2026-09-15 with one
# mutant never applied.
#
# ⭐⭐ WHY SECTION 5 IS IN TWO HALVES, and what this stand actually proved about
# it.  A first draft of the test file had 5.1 alone -- an as-recorded sweep over
# all 19 Zeus frames -- and called it "the direction tripwire".  It is a sweep
# that COULD NOT HAVE FAILED: both legs bid NONE on every frame because
# J.IsGoingOnSomeone is structurally false offline (section 6.2), so its
# inequality is 0 <= 0 nineteen times.  5.2's declared counterfactual is what
# turns direction into a driven reading (2 live bids, 1 flip, on real frames).
# ⛔ BUT SEE M5b: this stand contains NO mutant that 5.2 alone kills -- section
# 1.1's text pin and section 3's liveness guard both sort before it and both
# get there first.  5.2's value is that it is the file's only non-vacuous
# direction reading, not that it is the sole killer of anything here.  Saying
# otherwise would be the "matching conclusion, wrong reason" failure.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `zusulte` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#   * editing X.zuus_ShouldSaveManaForUlt's own clauses.  Those are shipped
#     (promoted `zusult`) behaviour that tests/test_zuus_nimbus_ult_reserve.lua
#     and the GH #47/#59 files already pin; mutating them tests those.
#   * moving the frames in ZUUS_FRAMES.  The corpus is the evidence, not the
#     assertion.  (M9/M10 mutate how the file READS the corpus, which is the
#     assertion.)
#
# Usage: bash tools/agent/mutstand_zusulte.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_zuus_jump_ult_reserve.lua
ZUUS=bots/BotLib/hero_zuus.lua
SHAPES=tests/mock/special_value_shapes.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$ZUUS" "$SHAPES"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$ZUUS" "$SHAPES"; do
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
	out=$(lua5.1 tests/run_tests.lua zuus_jump_ult_reserve 2>&1)
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
out=$(lua5.1 tests/run_tests.lua zuus_jump_ult_reserve 2>&1)
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
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "J.IsSoakCandidate( 'zusulte' )"
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "J.IsSoakCandidate( 'zusulteXX' )", 1))
PY
run "M1 gate id renamed -> the gate pin must red" "gate is gone from X.zuus_IsJumpChipHeldForUlt"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'zusulte' ) ) then return false end"
new = "if not ( J.IsSoakCandidate( 'zusulte' ) ) then return false end"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "no longer asks J.IsModeTurbo"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  ⭐ `zusult` is a PROPER SUBSTRING of this
#     lever's own id, which is why section 7.1 quotes the ids instead of
#     matching them bare -- a bare match self-reports on the pristine tree.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "J.IsModeTurbo() and J.IsSoakCandidate( 'zusulte' )"
new = "J.IsModeTurbo() and J.IsSoakCandidate( 'zusultd' ) and J.IsSoakCandidate( 'zusulte' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is the COUNT assertion, not the sibling-name one: 7.1 checks the id
# count before it loops over names, so an ADDED sibling reds on the count and
# the name loop never runs.  M1 exercises the REPLACE path.
run "M3 sibling id conjoined -> pullcad pin must red" "consults IsSoakCandidate 2 times"

# M4  The conjunct is deleted from X.ConsiderE.  The gate still exists, the
#     helper still exists, check_armed_wiring.py still calls it WIRED, and the
#     lever measures nothing in every wave it ever rides.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\n\t\t\tand not X.zuus_IsJumpChipHeldForUlt( bot, targetHero, abilityE )"
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "", 1))
PY
run "M4 call site deleted -> the wiring pin must red" "is called at 0 points inside X.ConsiderE"

# M5  ⭐⭐ THE `not` IS DROPPED -- the lever INVERTS.  Armed, Zeus jumps ONLY at
#     the targets the reserve wanted him to skip.  See the header: section 5.1
#     cannot see this and section 5.2 is the reason the file has two halves.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "and not X.zuus_IsJumpChipHeldForUlt( bot, targetHero, abilityE )"
new = "and X.zuus_IsJumpChipHeldForUlt( bot, targetHero, abilityE )"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 the negation is dropped -> direction must red" "no longer reads"

# M5b  The same inversion, but SPELLED so section 1.1's text pin still matches:
#      the negation moves inside the helper, so the call site still reads
#      `and not X.zuus_IsJumpChipHeldForUlt( bot, targetHero, abilityE )`.
#      ⛔ MEASURED, AND IT CORRECTS THE DRAFT'S CLAIM ABOUT THIS STAND.  The
#      draft named 5.2 as the assertion that catches it.  It does not get there
#      first: section 3's LIVENESS guard ("the hold does not fire even at mana
#      249") reds before it, because an inverted helper stops holding inside the
#      window.  5.2 also goes red in the same run -- on its flip-IDENTITY
#      assertion, naming the wrong frame -- but naming 5.2 here would be
#      claiming a kill that a different assertion made.
#      ⇒ NO MUTANT IN THIS STAND IS KILLED BY 5.2 ALONE.  That is not an
#      argument for deleting 5.2: 5.1 is provably vacuous (0 <= 0 nineteen
#      times, see the header) while 5.2 drives 2 live bids and 1 flip on real
#      frames, and M12 is what keeps 5.2 from going vacuous too.  What it means
#      is that 5.2 earns its place by being the file's only NON-VACUOUS
#      direction reading, not by being the sole killer of anything here.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\treturn X.zuus_ShouldSaveManaForUlt( hBot, hTarget, hAbility ) == true"
new = "\treturn X.zuus_ShouldSaveManaForUlt( hBot, hTarget, hAbility ) ~= true"
assert s.count(old) == 1, 'M5b anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5b negation hidden inside the helper -> 3's liveness must red" \
    "the hold does not fire even at mana 249"

# M6  The retreat exemption is destroyed the cheap way: the helper stops
#     deferring to J.IsRetreating by short-circuiting the shipped reserve.
#     Section 4.1 is the only thing between this and a Zeus who hoards mana
#     while running for his life.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\treturn X.zuus_ShouldSaveManaForUlt( hBot, hTarget, hAbility ) == true"
new = "\treturn J.IsValidHero( hTarget ) and J.GetHP( hTarget ) >= X.nUltSaveHealthFloor"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 retreat deference removed -> 4.1 must red" "the hold fires on a RETREATING Zeus"

# M7  The wrong handle is priced: the conjunct passes the ULT handle instead of
#     the jump.  Under `zusultx` that subtracts 250 where it should subtract
#     50, i.e. it silently prices a spend that is not happening -- and the site
#     still reads as WIRED.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "and not X.zuus_IsJumpChipHeldForUlt( bot, targetHero, abilityE )"
new = "and not X.zuus_IsJumpChipHeldForUlt( bot, targetHero, abilityR )"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 the wrong handle is priced -> the wiring pin must red" "no longer reads"

# M8  The conjunct is MOVED onto the retreat firing point as well.  The lever
#     would then refuse escapes, which is the one thing its header promises it
#     cannot do.  ⚠️ `want` is section 1.1's call-count, which sorts first.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "\t\t\tif X.zuus_FindRetreatJumpThreat( bot, tableNearbyEnemyHeroes ) ~= nil\n"
new = ("\t\t\tlocal hFlee = X.zuus_FindRetreatJumpThreat( bot, tableNearbyEnemyHeroes )\n"
       "\t\t\tif hFlee ~= nil and not X.zuus_IsJumpChipHeldForUlt( bot, hFlee, abilityE )\n")
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 the retreat branch is routed through the hold -> 1.1 must red" \
    "is called at 2 points inside X.ConsiderE"

# M9  ⭐ The KV is moved, not the code: Heavenly Jump is repriced ABOVE a rank-1
#     ult.  The window [cost, 250) goes empty exactly the way Nimbus's already
#     is, so the header's "nonempty at every rank pairing" -- the single
#     sentence separating this lever from `zusultd` -- becomes false with the
#     source untouched.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/mock/special_value_shapes.lua'
s = open(p).read()
# ⚠️ ANCHORED THROUGH THE ABILITY NAME, not on the ladder alone: `50 60 70 80`
# occurs TWICE in this snapshot, so a bare anchor mutates whichever comes first
# and the count assert is the only thing that noticed.
head = "['zuus_heavenly_jump'] = {"
assert s.count(head) == 1, 'M9 ability anchor not found exactly once'
i = s.index(head)
old = "['AbilityManaCost'] = { base = '50 60 70 80', bonus = {  } },"
j = s.index(old, i)
assert j - i < 600, 'M9 landed outside the zuus_heavenly_jump block'
open(p, 'w').write(s[:j] + "['AbilityManaCost'] = { base = '260 270 280 290', bonus = {  } }," + s[j + len(old):])
PY
run "M9 the jump is repriced above a rank-1 ult -> 2 must red" "the jump cost ladder is now"

# M10  ⭐ The corpus reading is loosened where nobody would look: the health
#      floor the reserve compares against is raised, so MORE targets count as
#      "healthy" and the domain grows.  Neither the source of the lever nor the
#      corpus changes; only the number that decides what the lever is about.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_zuus.lua'
s = open(p).read()
old = "X.nUltSaveHealthFloor = 0.6"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, "X.nUltSaveHealthFloor = 0.3", 1))
PY
run "M10 the health floor is moved -> the domain tripwire must red" \
    "(frame, enemy) pairs, recorded"

# M11  ⭐ A mutation of the TEST, not of the lever: section 6.1's domain loop is
#      handed an empty corpus.  An empty `for` executes no assert at all, so a
#      count that is "driven" over nothing is prose with a loop in front of it.
#      (Same shape as mutstand_wksavecap.sh M10, which SURVIVED first time.)
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_zuus_jump_ult_reserve.lua'
s = open(p).read()
old = """    local nFrames, nPairs, tWhere = 0, 0, {}
    for _, path in ipairs(ZUUS_FRAMES) do"""
new = """    local nFrames, nPairs, tWhere = 0, 0, {}
    for _, path in ipairs({}) do"""
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M11 section 6.1 is handed an empty corpus -> its own count must red" \
    "(frame, enemy) pairs, recorded"

# M12  ⭐ The other liveness hole, on the counterfactual: 5.2's injected target
#      is replaced by nil, so every X.ConsiderE call bails on J.IsValidHero and
#      the inequality is 0 <= 0 again -- the exact vacuity 5.1 already has and
#      5.2 exists to escape.  Only 5.2's OWN liveness assert can see it.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_zuus_jump_ult_reserve.lua'
s = open(p).read()
old = "        J.GetProperTarget = function() return hPick end"
new = "        J.GetProperTarget = function() return nil end"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 the counterfactual target is nil -> 5.2's liveness must red" \
    "shipped jump bid on 0 frames"

# M13  ⭐ The end-to-end zero is turned into a REAL zero, silently: the mode
#      getter is given an answer inside the BOT_MODE namespace.  6.2's whole
#      job is to refuse to read 0 as a domain, and it must notice the day the
#      loader learns the answer -- otherwise the file keeps calling a readable
#      zero UNASKABLE and hero-95 keeps buying a question that got cheap.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_zuus_jump_ult_reserve.lua'
s = open(p).read()
old = "        local nMode = bot:GetActiveMode()"
new = "        local nMode = BOT_MODE_ROAM"
assert s.count(old) == 1, 'M13 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M13 GetActiveMode answers a real mode -> 6.2 must red" \
    "now answers a REAL BOT_MODE"

echo
echo "mutants killed: $pass   survived/wrong: $fail"
[ "$fail" -eq 0 ] || exit 1
