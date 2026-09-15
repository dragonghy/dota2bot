#!/usr/bin/env bash
# Mutation stand for tests/test_axe_t15_payoff.lua, 2026-09-15 re-take
# (hero stream).  The re-take moved six registered numbers (29 / 19 / 5 / 1 /
# 2.45 / 16.60) and replaced the 2026-08-28 prose sentence "corpus growth alone
# can NEVER flip it" with a per-rank table the file now EVALUATES.  Each mutant
# breaks ONE thing that file claims; a mutant that SURVIVES is an assertion that
# was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.  The
# fixture that M6 moves aside is restored the same way.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the mutant
# is "about".  tests/run_tests.lua sorts test names, and
# "corpus health: Call is near its ceiling" sorts BEFORE
# "corpus health: which added frames move the direction", so any mutant that
# moves a summed ceiling is caught by the older test first.  That is not a
# defect in the new one -- it is why M3 and M7 are labelled by what they prove
# (the ceilings are load-bearing) rather than by where they were aimed.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * anything under bots/ that is not the build row.  This file's subject is a
#     talent VERDICT, not a behaviour: section 2 reads the datafeed and the
#     build row, section 3 reads the fixture corpus.  Mutating a Consider
#     function would test neither.
#   * lowering any of the six re-taken numbers to make a red go away.  That is
#     the one fix this file's own header rules out ("re-read them rather than
#     lowering the bar").
#
# Usage: bash tools/agent/mutstand_axe_t15_retake.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_axe_t15_payoff.lua
AXE=bots/BotLib/hero_axe.lua
FIXTURE=tests/fixtures/f_20260909_212625_lion_235.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$AXE" "$FIXTURE"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$AXE" "$FIXTURE"; do
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
	out=$(lua5.1 tests/run_tests.lua axe_t15_payoff 2>&1)
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
out=$(lua5.1 tests/run_tests.lua axe_t15_payoff 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# ---------------------------------------------------------------------------
# The per-rank table (the claim the 2026-08-28 sentence got wrong).

# M1  Berserker's Call rank 4 is made CHEAP to keep up (cooldown 12 -> 20), so
#     5 * ceil_C(4) drops below Battle Hunger's capped 1.00 and NO rung of the
#     ladder moves the margin down any more.  The corpus holds no rank-4 Call
#     frame, so this moves nothing else -- exactly the mutant that would make
#     the old "NEVER" true again, and the file has to notice.
python3 - <<'PY'
p = 'tests/test_axe_t15_payoff.lua'
s = open(p).read()
old = '    cooldown = { 18, 16, 14, 12 },'
new = '    cooldown = { 18, 16, 14, 20 },'
assert s.count(old) == 1, 'M1 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M1 Call rank 4 cooldown 12->20 -> the negative rung disappears" \
    "rungs of the ladder now move the margin DOWN, not 1"

# M2  The size of the negative rung is changed without changing its sign
#     (Call rank 4 duration 3.0 -> 6.0).  The count assertion still passes, so
#     this is aimed one assertion further in: the -0.250 per dry frame.
python3 - <<'PY'
p = 'tests/test_axe_t15_payoff.lua'
s = open(p).read()
old = '    duration = { 2.1, 2.4, 2.7, 3.0 },'
new = '    duration = { 2.1, 2.4, 2.7, 6.0 },'
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 Call rank 4 duration 3.0->6.0 -> the rung's SIZE must red" \
    "per dry frame, not -0.250"

# M3  Battle Hunger's uptime cap is removed from ceiling().  This is the term
#     the whole correction rests on -- Hunger is capped at 1.00 from rank 3 up
#     while Call keeps climbing, which is the only reason a negative rung
#     exists.  Caught upstream by the summed ceiling, which is the point: the
#     two readings are the same arithmetic.
python3 - <<'PY'
p = 'tests/test_axe_t15_payoff.lua'
s = open(p).read()
old = '    return (up > 1) and 1 or up'
new = '    return up'
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 uptime cap removed -> the summed Hunger ceiling must red" \
    "summed Battle Hunger uptime ceiling is now"

# M4  The build row stops taking a fourth Berserker's Call point (its last Call
#     entry becomes Counter Helix), so Call rank 4 is unreachable at any level
#     and the enumeration finds no negative rung.  Same red as M1, reached from
#     the OTHER input -- the table is driven off the build row, not hand-listed,
#     and this is the mutant that proves it.
python3 - <<'PY'
import re
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
m = re.search(r'local tAllAbilityBuildList = \{(.*?)\n\}', s, re.S)
assert m, 'M4: could not find tAllAbilityBuildList'
body = m.group(1)
# The build row is a list of ability-slot indices; Berserker's Call is slot 1.
# Turn its LAST occurrence into slot 3 (Counter Helix).
idx = body.rfind('1,')
assert idx >= 0, 'M4: no Call entry to rewrite'
body2 = body[:idx] + '3,' + body[idx + 2:]
open(p, 'w').write(s[:m.start(1)] + body2 + s[m.end(1):])
PY
run "M4 build row never maxes Call -> the negative rung is unreachable" \
    "rungs of the ladder now move the margin DOWN, not 1"

# M5  The rung enumeration stops at hero level 14, i.e. it never looks above
#     the talent it is about.  This is the exact blind spot the 2026-08-28
#     sentence had, re-introduced as code instead of as prose.
python3 - <<'PY'
p = 'tests/test_axe_t15_payoff.lua'
s = open(p).read()
old = '    for nLevel = 1, 25 do'
new = '    for nLevel = 1, 14 do'
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 rung enumeration capped at level 14 -> the blind spot must red" \
    "rungs of the ladder now move the margin DOWN, not 1"

# ---------------------------------------------------------------------------
# The six re-taken numbers.

# M6  The 29th live-Axe frame is taken away again.  This pins the PROVENANCE
#     claim in the header block -- that f_20260909_212625_lion_235.lua is the
#     frame that moved 28 -> 29 and 18 -> 19 -- rather than leaving it as prose
#     next to a number that would read the same if some other fixture had.
mv "$FIXTURE" "$TMP/held_out.lua"
out=$(lua5.1 tests/run_tests.lua axe_t15_payoff 2>&1)
mv "$TMP/held_out.lua" "$FIXTURE"
if echo "$out" | grep -q "0 failures"; then
	echo "SURVIVED  M6 the 29th frame held out -- the suite stayed green"
	fail=$((fail + 1))
elif echo "$out" | grep -qF "28 live-Axe frames, not 29"; then
	echo "killed    M6 the 29th frame held out -> the count must name 28"
	pass=$((pass + 1))
else
	echo "WRONG MESSAGE  M6 -- red, but not on the assertion aimed at"
	echo "$out" | grep -A3 'FAIL' | head -10
	fail=$((fail + 1))
fi
restore

# M7  A summed Call ceiling that no longer matches the ranks the corpus holds
#     (rank 3 cooldown 14 -> 12).  Sixteen of the nineteen modifier-carrying
#     frames are at Call rank 1 and three at rank 3, so this moves 2.45 and
#     nothing else -- the number that makes "live on 1 frame" read as SATURATED.
python3 - <<'PY'
p = 'tests/test_axe_t15_payoff.lua'
s = open(p).read()
old = '    cooldown = { 18, 16, 14, 12 },'
new = '    cooldown = { 18, 16, 12, 12 },'
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 Call rank 3 cooldown 14->12 -> the summed Call ceiling must red" \
    "Axe frames is now"

echo
echo "mutants killed: $pass   survived/wrong: $fail"
[ "$fail" -eq 0 ] || exit 1
