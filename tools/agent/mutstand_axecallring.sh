#!/usr/bin/env bash
# Mutation stand for tests/test_axe_call_ring_anchor.lua
# (hero 2026-09-15, the `axecallring` lever -- Berserker's Call is decided by the
# RING, not by the one hero Axe happens to be committing on).  Each mutant breaks
# ONE thing that file claims; a mutant that SURVIVES is an assertion that was not
# doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the mutant
# is "about".  tests/run_tests.lua sorts test names, so a source-shape mutant is
# often caught upstream of the section it is aimed at.
#
# ⭐ TWO OF THE TWELVE MUTATE THE TEST (M11, M12), and they are the ones worth
# reading.  This lever's headline numbers are a 1 and a 0 -- and a 1 measured on
# the wrong slice, or a 0 produced by an instrument that never reached the frame,
# is exactly what a broken census hands you for free.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `axecallring` in bots/Customize/soak_side.lua.  That is the change
#     itself, not a mutation of an assertion.
#   * recutting the staged frame.  The frame is the evidence, not the assertion.
#   * dropping the census's `alive ~= false` predicate.  It would SURVIVE, and
#     honestly so: all 40 Axe rows in today's corpus are alive, so that conjunct
#     is not load-bearing HERE.  It stays in the test because GH #794 is what
#     happens when it is absent the day a corpse lands, and a stand entry that
#     is known to survive teaches nothing.
#
# Usage: bash tools/agent/mutstand_axecallring.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_axe_call_ring_anchor.lua
AXE=bots/BotLib/hero_axe.lua

TMP=$(mktemp -d) || exit 2
for f in "$TEST" "$AXE"; do
	cp "$f" "$TMP/$(echo "$f" | tr / _)" || exit 2
done

restore() {
	local f pristine
	for f in "$TEST" "$AXE"; do
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
	out=$(lua5.1 tests/run_tests.lua axe_call_ring_anchor 2>&1)
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
out=$(lua5.1 tests/run_tests.lua axe_call_ring_anchor 2>&1)
if ! echo "$out" | grep -q "0 failures"; then
	echo "ABORT: the pristine suite is already red; a mutation stand on a red" >&2
	echo "       baseline cannot tell a kill from the pre-existing failure." >&2
	echo "$out" | tail -5 >&2
	exit 2
fi

# M1  The gate id is renamed, i.e. arming the published string moves nothing.
#     The silent-no-op shape check_armed_wiring.py cannot see: a call site
#     exists, the predicate is simply unreachable by any wave.
sed -i "s/'axecallring'/'axecallringXX'/g" "$AXE"
run "M1 gate id renamed -> the single-id pin must red" \
    "no longer names axecallring"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\treturn J.IsModeTurbo() and J.IsSoakCandidate( 'axecallring' )"
new = "\treturn J.IsSoakCandidate( 'axecallring' )"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo conjunct dropped -> gate shape must red" "lost its turbo conjunct"

# M3  The pullcad trap, written the way it actually gets written: a sibling id
#     ANDed into the same condition.  Frozen FALSE the day the sibling is
#     promoted, and check_armed_wiring.py still calls it WIRED.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "J.IsModeTurbo() and J.IsSoakCandidate( 'axecallring' )"
new = "J.IsModeTurbo() and J.IsSoakCandidate( 'axecallbkb_ii' ) and J.IsSoakCandidate( 'axecallring' )"
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is the COUNT assertion, not the sibling-name loop in §7.2: §6.1
# counts the ids before §7.2 ever runs, and run_tests sorts by name.
run "M3 gate names a sibling id -> pullcad guard must red" \
    "names 2 soak ids"

# M4  The counter stops asking WHERE the enemy stands -- every member of the
#     265u search list counts.  Direction is unchanged (it can still only add
#     casts), the frame still fires, and only the ladder in §3.1 can see it.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\t\tand J.IsInRange( bot, npcEnemy, nRing )\n"
new = ""
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 the ring test is dropped from the counter -> the §3.1 ladder must red" \
    "one enemy just inside necrolyte"

# M5  The counter stops applying the SHIPPED immunity reader, i.e. this lever
#     silently absorbs `axecallbkb_ii`'s premise.  Nothing about the live corpus
#     changes -- both ring members read non-immune on the recorded frame -- so
#     only the injected control in §3.3 can see it.  ⭐ This is the mutant that
#     makes "the two ids are separable" a reading instead of a sentence.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\t\tand J.CanCastOnNonMagicImmune( npcEnemy )\n\t\t\tand not J.IsDisabled( npcEnemy )\n"
new = "\t\t\tand not J.IsDisabled( npcEnemy )\n"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 immunity veto dropped from the counter -> the separability control must red" \
    "silently absorbed"

# M6  The counter stops refusing an already-locked-down hero, so a Call is spent
#     re-disabling somebody who cannot act anyway.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\t\t\tand not J.IsDisabled( npcEnemy )\n"
new = ""
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 the disable veto is dropped -> the §3.3 control must red" \
    "the not-J.IsDisabled veto is gone"

# M7  The nil default flips from restrictive to permissive.  A caller that
#     forgot its argument would then fire this branch on EVERY frame, and no
#     corpus reading would show it because the live call site always passes a
#     list.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "\tif tEnemies == nil then return 0 end"
new = "\tif tEnemies == nil then return X.nCallRingQuorum end"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 nil answers the quorum instead of 0 -> the restrictive-default pin must red" \
    "a caller that forgot its argument"

# M8  The quorum drops to 1 -- the widening the header refuses on purpose.  It
#     triples the offline domain and it looks like an improvement.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "X.nCallRingQuorum = 2"
new = "X.nCallRingQuorum = 1"
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 quorum widened to 1 -> the quorum pin must red" "the quorum moved to 1"

# M9  The new firing point is moved AHEAD of the shipped branch.  On this corpus
#     no answer changes -- but the direction argument ("arming can only ADD a
#     Call") is priced on the shipped branch returning first, and an armed leg
#     that pre-empts it can MOVE a cast onto a different target.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
# -*- coding: utf-8 -*-
import io
p = 'bots/BotLib/hero_axe.lua'
s = io.open(p, encoding='utf-8').read()
HEAD = '\t-- [axecallring] The ring, not the anchor.'
NEXT = '\t--\u5e26\u7ebf\u65f6\u5632\u8bbd\u5c0f\u5175\u653b\u51fb\u81ea\u5df1'   # the lane-push comment right after it
PREV = ('\t--\u653b\u51fb\u654c\u4eba\u65f6\n\tif J.IsGoingOnSomeone( bot )\n\tthen\n'
        '\t\tif J.IsValidHero( botTarget )\n'
        '\t\t\tand J.IsInRange( botTarget, bot, nRadius - 90 )')
# \u26a0\ufe0f X.ConsiderW opens with the SAME four lines; the fifth is where they part
# (nRadius - 90 against nCastRange).  A four-line anchor matches twice and the
# stand aborted rather than mutating the wrong function.
for tok in (HEAD, NEXT, PREV):
    assert s.count(tok) == 1, 'M9 anchor not found exactly once: ' + repr(tok)
block = s[s.index(HEAD):s.index(NEXT)]
rest = s[:s.index(HEAD)] + s[s.index(NEXT):]
at = rest.index(PREV)
io.open(p, 'w', encoding='utf-8').write(rest[:at] + block + rest[at:])
PY
run "M9 the ring firing point is hoisted above the shipped branch -> §6.2 must red" \
    "runs BEFORE the shipped branch"

# M10 The call site stops handing the counter the shipped -90 margin and uses
#     the bare radius instead.  On this frame the answer is the same (Shadow
#     Shaman is not in the 265u list either way), so only the source pin sees it
#     -- which is the point: "one term moves" is a claim about the SOURCE.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "X.axe_CountCallRingTargets( nInRangeEnemyList, nRadius - 90 )"
new = "X.axe_CountCallRingTargets( nInRangeEnemyList, nRadius )"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 the -90 margin leaves the call site -> the one-term-moves pin must red" \
    "the shipped 265u list and the shipped"

# M11 ⭐ TEST-SIDE.  The census stops walking tests/frames/ and reads only
#     tests/fixtures/.  Every number in §2 stays plausible -- and the ONE row
#     that reaches quorum lives in tests/frames/, so the branch-level domain
#     silently becomes 0 and §4 would be driving a frame the census says does
#     not exist.  This is the slice defect backlog -183 paid for once already.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'tests/test_axe_call_ring_anchor.lua'
s = open(p).read()
old = "for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do"
new = "for _, dir in ipairs({ FIXTURE_DIR }) do"
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
# ⚠️ `want` is §2.1's ROW COUNT, not §2.2's quorum floor: run_tests sorts by
# name, so the population size reds first and §2.2 never gets to speak.  Both
# go red on this mutant; only one of them can be the message.
run "M11 the census forgets tests/frames/ -> the population pin must red" \
    "Call-ready Axe rows, recorded 28"

# M12 ⭐ TEST-SIDE, and it is the control for the headline ZERO.  §5 claims the
#     END-TO-END domain is 0 because X.ConsiderR wins the arm order.  Make the
#     ultimate decline and the Call really is cast -- if §5 stays green on that,
#     its 0 was produced by an instrument that never reached the branch.
python3 - <<'PY' || { echo 'ABORT: a mutation failed to apply; an unmutated tree is not a survivor.' >&2; exit 2; }
p = 'bots/BotLib/hero_axe.lua'
s = open(p).read()
old = "function X.ConsiderR()\n"
new = "function X.ConsiderR()\n\n\tif true then return 0 end\n"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 the ultimate declines -> §5's end-to-end ZERO must red" \
    "the END-TO-END domain has left 0"

echo
echo "MUTSTAND axecallring: killed $pass, not killed $fail"
[ "$fail" -eq 0 ] || exit 1
