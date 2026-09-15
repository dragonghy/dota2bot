#!/usr/bin/env bash
# Mutation stand for tests/test_wk_reserve_rank_blind.lua
# (hero 2026-09-15, the `wkrank0` reserve rank-blindness lever, GH #407).
# Each mutant breaks ONE thing that file claims; a mutant that SURVIVES is an
# assertion that was not doing work.
#
# Restore is from a byte copy taken before the first mutation and re-applied
# after every mutant, then PROVED with sha256sum (evidence-discipline rule 1):
# a stand that only `cp`s has no way to notice it put back wrong bytes.
#
# ⚠️ `want` NAMES THE ASSERTION THAT ACTUALLY FIRES FIRST, not the one the
# mutant is "about".  tests/run_tests.lua sorts test names, so a source-shape
# mutant is usually caught by section 1 before the section it was aimed at ever
# runs.  Two mutants below (M9, M12) are annotated where that bites.
#
# ⚠️ TWO OF THESE MUTATE THE TEST, NOT THE HERO FILE (M7, M8), and they are the
# ones that matter most here.  This lever's whole headline is a ZERO (no frame
# in the corpus has hero level >= 6 with R at rank 0), and a zero is the one
# reading that a broken instrument produces for free.  M7 and M8 attack the two
# ways the zero could be manufactured: a corpus that is too small, and a corpus
# that lets ABSENCES in.
#
# ⛔ MUTANTS THAT ARE NOT HERE, and why -- do not add them:
#   * arming `wkrank0` for real in bots/Customize/soak_side.lua.  That is the
#     change itself, not a mutation of an assertion.
#   * moving the `nLV >= 6` conjunct in X.ShouldSaveMana.  That is GATE-OFF
#     behaviour, which a soak candidate may not touch; a mutant of it tests the
#     shipped rule, not this lever's assertions.
#
# Usage: bash tools/agent/mutstand_wkrank0.sh

set -u
cd "$(dirname "$0")/../.." || exit 2

TEST=tests/test_wk_reserve_rank_blind.lua
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
	out=$(lua5.1 tests/run_tests.lua wk_reserve_rank_blind 2>&1)
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
#     The silent-no-op shape check_armed_wiring.py cannot see (a call site
#     exists; the predicate is simply unreachable by any wave).
sed -i "s/'wkrank0'/'wkrank0XX'/g" "$WK"
run "M1 gate id renamed -> 1.1 must red" "no longer names wkrank0 as a quoted literal"

# M2  The turbo conjunct is dropped.  Every soak candidate is turbo-only.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkrank0' ) )\n"
new = "\tif not ( J.IsSoakCandidate( 'wkrank0' ) )\n"
assert s.count(old) == 1, 'M2 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M2 turbo guard dropped -> 1.1 must red" "lost its turbo guard"

# M3  The gate is written as a CONJUNCTION with the sibling id `wksaveidle` --
#     the pullcad trap, and the single most likely wrong edit in this file: all
#     three reserve levers sit on the same shipped predicate in the same
#     function, so "the reserve levers belong together" reads as good taste.  It
#     freezes this one FALSE the day either id is promoted, with
#     check_armed_wiring.py still calling it WIRED.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkrank0' ) )\n"
new = ("\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkrank0' )\n"
       "\t\t\tand J.IsSoakCandidate( 'wksaveidle' ) )\n")
assert s.count(old) == 1, 'M3 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M3 gate conjoined with the sibling id -> 1.1 must red" \
    "must hold exactly ONE IsSoakCandidate call"

# M4  The release is folded into the sibling's statement as a second disjunct.
#     This is the edit that LOOKS tidiest and it is the GH #798 shape: arming
#     either id then releases BOTH frame sets, so a wave reading is attributable
#     to neither member.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ("\tif bShipped and X.IsReincarnationReserveUnlearned()\n"
       "\tthen\n"
       "\t\treturn false\n"
       "\tend\n")
assert s.count(old) == 1, 'M4 anchor not found exactly once'
s = s.replace(old, '', 1)
old2 = "\tif bShipped and X.IsReincarnationReserveIdle()\n"
new2 = ("\tif bShipped and ( X.IsReincarnationReserveIdle()\n"
        "\t\t\tor X.IsReincarnationReserveUnlearned() )\n")
assert s.count(old2) == 1, 'M4 second anchor not found exactly once'
open(p, 'w').write(s.replace(old2, new2, 1))
PY
run "M4 release folded onto the sibling's statement -> 1.2 must red" \
    "release statement was rewritten"

# M5  The `bShipped and` guard is dropped from this lever's own statement, so
#     the release can fire on a frame the shipped rule never refused -- i.e. the
#     lever gains the ability to move the answer false -> true.  Nothing about
#     the armed-release readings moves; only the shape cell and the direction
#     cells can see it.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tif bShipped and X.IsReincarnationReserveUnlearned()\n"
new = "\tif X.IsReincarnationReserveUnlearned()\n"
assert s.count(old) == 1, 'M5 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M5 bShipped guard dropped -> 1.2 must red" \
    "not guarded by the already-bound bShipped"

# M6  ⭐ The rank comparison is REVERSED: the helper releases when R IS trained.
#     Every source-shape cell in section 1 stays green -- the gate is wired,
#     turbo-only and names one id -- and the file still reads as a rank lever.
#     Only the behavioural sections can tell that it now releases the wrong half
#     of the world, and section 3.3 (inert on the real frames) is the one that
#     screams, because every recorded frame has R trained.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\treturn not abilityR:IsTrained()\n"
new = "\treturn abilityR:IsTrained()\n"
assert s.count(old) == 1, 'M6 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M6 rank comparison reversed -> 3.3 must red" \
    "changed the answer on real recorded frames"

# M7  ⭐ TEST MUTANT.  The corpus is narrowed to tests/fixtures, i.e. exactly the
#     split the sibling file uses.  The lever's headline zero SURVIVES that
#     narrowing -- which is the point: a zero measured on a smaller corpus is a
#     smaller claim, and nothing in the reading itself says which corpus it came
#     from.  The counts are what notice.
python3 - <<'PY'
p = 'tests/test_wk_reserve_rank_blind.lua'
s = open(p).read()
old = "local DIRS = { 'tests/fixtures', 'tests/frames' }\n"
new = "local DIRS = { 'tests/fixtures' }\n"
assert s.count(old) == 1, 'M7 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M7 corpus narrowed to tests/fixtures -> 2.1 must red" \
    "priced live Wraith King frames across"

# M8  ⭐⭐ TEST MUTANT, AND THE ONE THIS FILE EXISTS FOR.  The abilities-less
#     rows are let into the priced corpus.  Their blank handles answer rank 0,
#     which this lever READS as "unlearned" -- and two of the three sit at hero
#     level >= 6.  So the domain that section 2.2 measures as EMPTY becomes
#     non-empty, out of nothing but absence.  A round that skipped the split
#     would have reported this lever's first domain members and been wrong in
#     the direction that feels like success.
python3 - <<'PY'
p = 'tests/test_wk_reserve_rank_blind.lua'
s = open(p).read()
old = ("                    if type(u.abilities) == 'table' then\n"
       "                        priced[#priced + 1] = path\n"
       "                    else\n"
       "                        absent[#absent + 1] = short(path)\n"
       "                    end\n")
new = ("                    priced[#priced + 1] = path\n"
       "                    if type(u.abilities) ~= 'table' then\n"
       "                        absent[#absent + 1] = short(path)\n"
       "                    end\n")
assert s.count(old) == 1, 'M8 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M8 absences admitted to the priced corpus -> 2.x must red" \
    "priced live Wraith King frames across"

# M9  The call-site ordering branch A rests on is broken: X.ConsiderQ asks
#     X.ShouldSaveMana BEFORE IsFullyCastable, so "the function was entered"
#     stops entailing "mana >= cost".
#     ⚠️ This also breaks section 5.2's control (the shipped leg would now read
#     Q's cast range), but 4.1 sorts first and is the cell that fires.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ("\tif not abilityQ:IsFullyCastable()\n"
       "\t\tor X.ShouldSaveMana( abilityQ )\n")
new = ("\tif X.ShouldSaveMana( abilityQ )\n"
       "\t\tor not abilityQ:IsFullyCastable()\n")
assert s.count(old) == 1, 'M9 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M9 ConsiderQ asks the reserve before IsFullyCastable -> 4.1 must red" \
    "BEFORE testing IsFullyCastable"

# M10 Branch A is decoupled from R's price: the reserve becomes a constant.  The
#     armed behaviour is untouched and every rank cell stays green; only 4.2 --
#     which prices R at 0 and asserts the reserve follows it to 0 -- can see
#     that the no-op branch of this lever's correctness argument is gone.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\tlocal nReserve = abilityR:GetManaCost()\n"
new = "\tlocal nReserve = 220\n"
assert s.count(old) == 1, 'M10 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M10 reserve stops reading R's price -> 4.2 must red" \
    "but the reserve read"

# M11 The call site is deleted outright and the helper is left as dead code.
#     Every cell that calls X.IsReincarnationReserveUnlearned DIRECTLY would
#     still pass; this is the shape check_armed_wiring.py exists for and 1.2
#     is what catches it here.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = ("\tif bShipped and X.IsReincarnationReserveUnlearned()\n"
       "\tthen\n"
       "\t\treturn false\n"
       "\tend\n")
assert s.count(old) == 1, 'M11 anchor not found exactly once'
open(p, 'w').write(s.replace(old, '', 1))
PY
run "M11 call site deleted, helper orphaned -> 1.2 must red" \
    "call site inside X.ShouldSaveMana"

# M12 The helper reads the WRONG HANDLE: Wraithfire Blast's rank instead of
#     Reincarnation's.  This is the mutant that most resembles a plausible edit,
#     because the function it is called from takes the ability as an argument
#     and the reader has to remember which ability the reserve is FOR.  Every
#     source-shape cell stays green.
#     ⚠️ On the recorded frames Q is at rank >= 1 on all seven firing frames, so
#     the armed leg releases nothing and 3.2 is the cell that fires.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\treturn not abilityR:IsTrained()\n"
new = "\treturn not abilityQ:IsTrained()\n"
assert s.count(old) == 1, 'M12 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M12 helper reads Q's rank instead of R's -> 3.2 must red" \
    "frames, expected all of them"

# M13 ⭐ THE ACCESSOR IS SWAPPED FOR A BEHAVIOURALLY IDENTICAL ONE:
#     `not abilityR:IsTrained()` becomes `abilityR:GetLevel() < 1`.  Every
#     behavioural cell in this suite stays green, because the loader DERIVES
#     IsTrained from GetLevel and the engine agrees -- so this mutant is
#     invisible to every reading and visible only to 1.1b.  That is the whole
#     reason 1.1b exists: the convention (huskar / `axeblink` /
#     J.IsWkReincarnationArmed's `wkreinctr` all ask IsTrained before believing
#     an ability handle) is what a source-level ownership sweep can find, and a
#     convention only most of its instances follow is the GH #235 shape.
python3 - <<'PY'
p = 'bots/BotLib/hero_skeleton_king.lua'
s = open(p).read()
old = "\treturn not abilityR:IsTrained()\n"
new = "\treturn abilityR:GetLevel() < 1\n"
assert s.count(old) == 1, 'M13 anchor not found exactly once'
open(p, 'w').write(s.replace(old, new, 1))
PY
run "M13 IsTrained swapped for an equivalent GetLevel read -> 1.1b must red" \
    "no longer asks abilityR:IsTrained()"

echo
echo "mutation stand: $pass killed, $fail survived/wrong-message"
[ "$fail" -eq 0 ] || exit 1
