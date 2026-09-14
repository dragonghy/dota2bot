#!/usr/bin/env bash
# Mutation stand for tests/test_wk_bone_guard_bank_full.lua
# (hero 2026-09-14, the `wkbonefull` branch-2 bank-floor lever).
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so the order is
# 1.1, 1.2, 1.3, 2.1 ... 8.1 -- and a source-shape mutant is usually caught by
# section 1 before the section it was aimed at ever runs.  Getting this wrong
# is the WRONG MESSAGE result three earlier rounds on this desk hit.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `wkbonefull` for real in bots/Customize/soak_side.lua.  That is
#     the change itself, not a mutation of an assertion.
#   * editing the LADDER table in the test.  The helper is HANDED maxStack out
#     of that same table, so a ladder edit moves both sides of every §2
#     comparison together and is unobservable there by construction.  §3 and
#     §4 do read it one-sidedly, but a mutant that only ever reds "the numbers
#     this file derives moved" is testing the test's arithmetic, not the lever.
#
# Usage: bash tools/agent/mutstand_wkbonefull.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_wk_bone_guard_bank_full.lua
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
	out=$(lua5.1 tests/run_tests.lua wk_bone_guard_bank_full 2>&1)
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
sed -i "s/'wkbonefull'/'wkbonefullXX'/g" "$WK"
run "M1 gate id renamed -> 1.1 must red" "no longer names wkbonefull"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only, and
#     §2.2 exists because an armed leg without it passes §2.1 and §2.4 both.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonefull' ) )\n"
new = "\tif not ( J.IsSoakCandidate( 'wkbonefull' ) )\n"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo guard dropped -> 1.1 must red" "lost its turbo guard"

# M3  The gate is written as a CONJUNCTION with the sibling id -- the pullcad
#     trap, frozen FALSE the day either id is promoted, with
#     check_armed_wiring.py still calling it WIRED.  It is the single most
#     likely wrong edit here, because the two armed legs are identical.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonefull' ) )\n"
new = ("\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonefull' )\n"
       "\t\t\tand J.IsSoakCandidate( 'wkbonebank' ) )\n")
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 gate conjoined with the sibling id -> 1.1 must red" \
    "must hold exactly ONE IsSoakCandidate call"

# M4  The call site is reverted: branch 2 goes back to the inline equality and
#     the helper is left orphaned.  Every behavioural cell in §2 still passes
#     (the helper itself is untouched); only the wiring cell sees it.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = '\tif ( X.wk_IsBoneGuardBankFull( nStack, maxStack ) or talent6:IsTrained() )\n'
new = '\tif ( nStack == maxStack or talent6:IsTrained() )\n'
assert s.count(old) == 1, 'M4 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M4 call site reverted -> 1.2 must red" \
    "occurrences in code (the definition and the single call site)"

# M5  The shipped leg is DELETED rather than kept first: the helper returns the
#     armed closure only.  Gate OFF then refuses every release branch 2 ships
#     today -- the one thing a soak candidate may never do.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ('\tlocal bShipped = ( nStack == maxStack )\n'
       '\n'
       '\tif bShipped\n'
       '\tthen\n'
       '\t\treturn true\n'
       '\tend\n')
new = '\tlocal bShipped = ( nStack == maxStack )\n'
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 shipped early return deleted -> 2.1 must red" "shipped equality says"

# M6  The floor is lowered below what the closure derives.  The lever stays a
#     superset (so the direction cell is happy) and stays turbo-only -- only the
#     PINNED CELL COUNT sees it.  This is why §2.4 counts instead of sampling.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
# the LAST occurrence is wk_IsBoneGuardBankFull's; the first is the sibling's
old = '\treturn nStack >= X.nBoneGuardShippedFloor\nend\n'
assert s.count(old) == 2, 'M6 anchor count changed (%d)' % s.count(old)
head, sep, tail = s.rpartition(old)
open(p, 'w').write(head + '\treturn nStack >= 1\nend\n' + tail)
PY
run "M6 floor lowered to 1 -> 2.4 must red" "expected 12"

# M7  The helper is "tidied" into the single-return shape -- gate OFF returns
#     the shipped answer, gate ON returns the armed leg ALONE -- and the armed
#     leg excludes the full bank.  Gate-OFF behaviour is untouched, so §2.1,
#     §2.2 and §2.3 all stay green; the lever now DELETES shipped releases and
#     only the superset half of §2.4 sees it.  This is the mutant that matters
#     most: every negative-wave attribution this lever will ever get depends on
#     the armed set being a superset.
#     ⚠️ The FIRST draft of this mutant inserted `if bShipped then return false
#        end` at the top of the armed leg, which sits BELOW `if bShipped then
#        return true end` and is therefore unreachable -- a mutant that changed
#        nothing and was scored SURVIVED.  Deleting a shipped release requires
#        breaking the early-return SHAPE, which is the whole point of the shape.
python3 - <<'PY'
import re
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
m = re.search(r'function X\.wk_IsBoneGuardBankFull\( nStack, maxStack \)\n'
              r'.*?\n\treturn nStack >= X\.nBoneGuardShippedFloor\nend\n',
              s, re.S)
assert m, 'M7 anchor not found'
new = ('function X.wk_IsBoneGuardBankFull( nStack, maxStack )\n'
       '\n'
       '\tlocal bShipped = ( nStack == maxStack )\n'
       '\n'
       "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonefull' ) )\n"
       '\tthen\n'
       '\t\treturn bShipped\n'
       '\tend\n'
       '\n'
       '\treturn nStack >= X.nBoneGuardShippedFloor and nStack < maxStack\nend\n')
open(p, 'w').write(s[:m.start()] + new + s[m.end():])
PY
run "M7 armed leg excludes the shipped cell -> 2.4 must red" \
    "ARMED DELETED A SHIPPED RELEASE"

# M8  The forbidden repair: a `maxStack > 0` guard is added to the SHIPPED leg,
#     which silently fixes the `0 == 0` empty-bank corner.  It is the right
#     thing to want and the wrong thing to do inside a gate -- it moves gate-OFF
#     behaviour.  Nothing in §2 sees it (maxStack is never 0 on the ladder).
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = '\tlocal bShipped = ( nStack == maxStack )\n'
new = '\tlocal bShipped = ( maxStack > 0 and nStack == maxStack )\n'
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 maxStack>0 guard added to the shipped leg -> 8.1 must red" \
    "A guard was added to"

# M9  The SIBLING's armed leg is re-tuned and this one is not.  §5.1 is the only
#     thing in the tree that would notice the two closures drifting apart, and
#     it must notice from either side.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = '\treturn nStack >= X.nBoneGuardShippedFloor\nend\n'
assert s.count(old) == 2, 'M9 anchor count changed (%d)' % s.count(old)
# the FIRST occurrence is wk_IsBoneGuardBankCommittable's
new = '\treturn nStack > X.nBoneGuardShippedFloor\nend\n'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 sibling armed leg re-tuned alone -> 5.1 must red" \
    "The two armed legs are the same closure"

echo
echo "mutants killed $pass / $((pass + fail))"
[ "$fail" -eq 0 ] || exit 3
