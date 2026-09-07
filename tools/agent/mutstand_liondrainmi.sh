#!/usr/bin/env bash
# Mutation stand for `liondrainmi` -- the WIDENING lever on X.ConsiderE's
# 打架抽蓝 target test (hero, 2026-09-07, backlog -109, OWNER_PRIORITIES P4.4(i)).
#
# Run by hand when X.lion_IsDrainCombatTargetCastable, X.ConsiderE, the
# PREMISE-FALSIFIED note in bots/BotLib/hero_lion.lua,
# tests/test_lion_drain_combat_widen.lua or the staged frame are edited, and
# before quoting any of that test file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_liondrainbkb.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK: a stand
# that rewrites shipped source in place opens a tearing window (GH #507).
#
# WHAT THIS STAND IS FOR.  The new test went green on its FIRST run, which is
# exactly the condition under which a suite proves nothing.  Four mutants carry
# the weight:
#   * M3 and M4 are the two ways a WIDENING lever turns into something else --
#     once by losing its gate (a defaults change wearing candidate clothing),
#     once by reversing direction (armed refuses what shipped accepted).  Only
#     the second is visible to a source assertion; the first needs the driven
#     gate-off reading.
#   * M6 is SCOPE CREEP: the mana-refill site (a creep, a different domain) gets
#     widened too, in one line that looks like consistency.  Nothing about this
#     round's evidence covers that site.
#   * M10 mutates the FROZEN FRAME rather than the code -- it checks that
#     section 1 reads the replay's own modifier list rather than an expectation
#     of what that list says.
#   * M12 is the control: a comment-only edit must NOT be scored as caught.
#
# Usage: bash tools/agent/mutstand_liondrainmi.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_drain_combat_widen.lua
OVERRIDES=bots/FunLib/aba_global_overrides.lua
FIXTURE=tests/frames/f_260905_004847_lion_drain_bkb.lua

FILES=("$HERO" "$TEST" "$OVERRIDES" "$FIXTURE")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ldmi.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

# The filter is `lion`, not this one file: the sibling liondrain /
# liondrainstop / liondrainbkb tests assert on the same branch's neighbours, and
# a stand scoped to the new file alone would report a collision there as
# SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the wrong of two identical sites scores "survived" for the
# wrong reason.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
if n != 1:
    sys.stderr.write("ANCHOR AMBIGUOUS (%d hits) in %s: %r\n" % (n, f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0
SURVIVED_BY_DESIGN=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# A mutant that MUST NOT be caught.  Scored separately so a stand that has
# become trigger-happy (everything red, including edits that change nothing)
# reports that rather than hiding inside a perfect score.
score_control() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  survived, AS DESIGNED (exit 0)"
        SURVIVED_BY_DESIGN=$((SURVIVED_BY_DESIGN + 1))
    else
        echo "$name  CAUGHT (exit $rc) -- but nothing observable changed. The"
        echo "        stand is reporting noise:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: THE LEVER IS DEFINED BUT NOT WIRED.  The call site goes back to the
#     stricter helper directly.  Everything about the lever still exists -- the
#     function, the gate, the id, the register entry -- and check_armed_wiring
#     style checks that look for a call site elsewhere would be satisfied by the
#     definition.  An armed wave then reads "tested, no effect".
echo
echo "=== M1: the 打架抽蓝 call site is unwired back to the shipped helper ==="
sub "$HERO" "			and X.lion_IsDrainCombatTargetCastable( botTarget )" \
            "			and J.CanCastOnNonMagicImmune( botTarget )"
score "M1" "no longer calls X.lion_IsDrainCombatTargetCastable( botTarget )"

# ---------------------------------------------------------------------------
# M2: THE TURBO CLAUSE IS DROPPED.  The id still gates it, so it still looks
#     dark -- but an armed farm string now changes NORMAL-mode games too, which
#     is the one thing every soak candidate in this repo promises it does not do.
echo
echo "=== M2: the gate loses its turbo-only clause ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainmi' )" \
            "	if J.IsSoakCandidate( 'liondrainmi' )"
score "M2" "the turbo-only clause is load-bearing"

# ---------------------------------------------------------------------------
# M3: A DEFAULTS CHANGE WEARING CANDIDATE CLOTHING.  The gate is removed and the
#     permissive answer becomes the shipped one.  The function, its name, its
#     doc comment and its call site are all unchanged; every register that reads
#     the call site still sees the lever.  This is the mutant that a
#     source-shape assertion alone would miss the point of -- what catches it
#     first is the DRIVEN gate-off reading on the real frame.
echo
echo "=== M3: the gate is deleted and the widened answer ships by default ==="
sub "$HERO" "	if bShipped then return true end

	if J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainmi' )
	then
		return J.CanCastOnMagicImmune( hTarget )
	end

	return bShipped" \
            "	if bShipped then return true end

	return J.CanCastOnMagicImmune( hTarget )"
score "M3" "GATE OFF the branch must still refuse this target"

# ---------------------------------------------------------------------------
# M4: DIRECTION REVERSED.  Armed stops accepting anything extra.  The lever is
#     then a no-op at best -- and the shape it leaves behind (`return false`
#     inside the armed detour) is the exact silhouette of a NARROWING lever,
#     i.e. the withdrawn `liondrainbkb` arriving under a new id.
echo
echo "=== M4: the armed path refuses instead of accepting ==="
sub "$HERO" "		return J.CanCastOnMagicImmune( hTarget )
	end" \
            "		return false
	end"
score "M4" "ARMED + turbo the branch must accept the spell-immune enemy"

# ---------------------------------------------------------------------------
# M5: THE PULLCAD TRAP.  A second candidate id is conjoined into the gate -- the
#     "good way" to encode a dependency, and the way that freezes the lever
#     FALSE forever the day the other id is promoted, while a wiring checker
#     still calls it WIRED because a call site exists.
echo
echo "=== M5: a second candidate id is conjoined into the gate ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainmi' )" \
            "	if J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainmi' ) and J.IsSoakCandidate( 'liondrain' )"
score "M5" "IsSoakCandidate calls, was 1"

# ---------------------------------------------------------------------------
# M6: SCOPE CREEP, IN ONE LINE THAT LOOKS LIKE CONSISTENCY.  The mana-refill
#     loop is widened too.  Its target is a CREEP out of GetNearbyCreeps -- a
#     different domain with a different base rate -- and NOTHING this round
#     measured says anything about it.  It also arrives UNGATED, so unlike the
#     lever itself it would ship live.
echo
echo "=== M6: the mana-refill (creep) site is widened as well ==="
sub "$HERO" "				and J.CanCastOnNonMagicImmune( nCreep )" \
            "				and J.CanCastOnMagicImmune( nCreep )"
score "M6" "stopped calling J.CanCastOnNonMagicImmune( nCreep )"

# ---------------------------------------------------------------------------
# M7: THE SIBLING BRANCH IS RE-NARROWED.  GH #566 established on real frames
#     that the 团战吸蓝 branch's permissive helper is CORRECT.  This round was
#     not allowed to touch it, and a widening round is exactly when a reader
#     might "tidy" the two branches into agreement from the wrong end.
echo
echo "=== M7: the 团战吸蓝 branch is re-narrowed ==="
sub "$HERO" "				and J.CanCastOnMagicImmune( npcEnemy ) -- see the PREMISE-FALSIFIED note by X.lion_ShouldStopDrain" \
            "				and J.CanCastOnNonMagicImmune( npcEnemy ) -- see the PREMISE-FALSIFIED note by X.lion_ShouldStopDrain"
score "M7" "stopped calling J.CanCastOnMagicImmune( npcEnemy )"

# ---------------------------------------------------------------------------
# M8: A CONTROL ON THE COUNTERFACTUAL.  Section 2's first labelled injection is
#     neutered.  The two helpers then agree on every unit, and "gate off refuses
#     this target" would be asserted about a world in which nobody is immune.
echo
echo "=== M8: section 2's immunity injection is neutered ==="
sub "$TEST" "    rawget(bb, '__spec').IsMagicImmune = true  -- INJECTION, see HONEST BOUNDS
    assert(bb:IsMagicImmune() == true, 'the injection took')" \
            "    rawget(bb, '__spec').IsMagicImmune = false -- INJECTION, see HONEST BOUNDS
    assert(bb:IsMagicImmune() == true, 'the injection took')"
score "M8" "the injection took"

# ---------------------------------------------------------------------------
# M9: A CONTROL ON THE INSTRUMENT, NOT THE SUBJECT.  The shipped IsMagicImmune
#     reader stops consulting the BKB modifier.  Neither the hero file nor the
#     frame moves -- but "this unit is spell-immune by the shipped reader's own
#     criterion" stops being a fact, and section 5's non-vacuity evaporates.
echo
echo "=== M9: the shipped immunity reader stops consulting the BKB modifier ==="
sub "$OVERRIDES" "        or self:HasModifier('modifier_black_king_bar_immune')" \
                 "        or self:HasModifier('modifier_black_king_bar_immune_renamed')"
score "M9" "is no longer a name the shipped IsMagicImmune reader consults"

# ---------------------------------------------------------------------------
# M10: THE FROZEN FRAME IS MUTATED, NOT THE CODE.  Bristleback loses the BKB
#      modifier.  A test that would still pass on a frame carrying no immunity
#      is not reading the replay at all.
echo
echo "=== M10: the staged frame loses its Black King Bar modifier ==="
sub "$FIXTURE" "{ name = 'modifier_black_king_bar_immune', remaining = 7.6, elapsed = 0.4, stacks = 0 }" \
               "{ name = 'modifier_black_king_bar_gone', remaining = 7.6, elapsed = 0.4, stacks = 0 }"
score "M10" "the frame really carries the Black King Bar immunity"

# ---------------------------------------------------------------------------
# M11: A CITATION STOPS RESOLVING.  The PREMISE-FALSIFIED note's frame path is
#      broken.  This is not hypothetical: that path read `tests/fixtures/` from
#      the day the rollback staged the frame in `tests/frames/`, and nothing in
#      the suite noticed for a day -- a note whose evidence cannot be opened is
#      the failure mode the note exists to prevent.
echo
echo "=== M11: the note's frame path stops resolving ==="
sub "$HERO" "---   tests/frames/f_260905_004847_lion_drain_bkb.lua -- STAGED, deliberately" \
            "---   tests/frames/f_260905_004847_lion_drain_bkb_moved.lua -- STAGED, deliberately"
score "M11" "which does not exist"

# ---------------------------------------------------------------------------
# M12: THE CONTROL.  A comment-only edit in the test file.  Nothing observable
#      changes, so a stand in good health scores this SURVIVED.
echo
echo "=== M12 (control): a comment-only edit, must NOT be caught ==="
sub "$TEST" "-- Round: hero desk 2026-09-07, backlog -109, owner priority P4.4(i)." \
            "-- Round: hero desk 2026-09-07, backlog -109 (control mutant marker)."
score_control "M12"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$((TOTAL - 1)) mutants CAUGHT; $SURVIVED_BY_DESIGN/1 control survived as designed ==="
sha256sum -c "$WORK/sum.txt" > /dev/null \
    && echo "tree restored byte-clean" \
    || { echo "TREE NOT CLEAN"; exit 2; }
