#!/usr/bin/env bash
# Mutation stand for the WITHDRAWAL of `liondrainbkb` (hero, 2026-09-06,
# GH #566, OWNER_PRIORITIES P4.4).  Its previous version stood behind the lever;
# the lever's premise was falsified on real frames and the code was withdrawn,
# so what needs a stand now is the PIN -- the thing that stops the same veto
# being re-derived from the same unverifiable KV sentence.
#
# Run by hand when X.ConsiderE, the PREMISE-FALSIFIED note in
# bots/BotLib/hero_lion.lua, tests/test_lion_drain_immune_target.lua or
# tests/frames/f_260905_004847_lion_drain_bkb.lua are edited, and before
# quoting any of that test file's readings.
#
# DISCIPLINE (inherited from the version this replaces):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent ABORTS instead of scoring caught,
#     and so does one whose anchor occurs MORE THAN ONCE;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  A withdrawal is mostly ABSENCE, and absence is the
# easy thing to assert vacuously.  Four of the eight mutants are the ones worth
# reading:
#   * M1 and M4 are the two ways the veto comes BACK -- once as a re-narrowed
#     call site (reads like a helper tidy-up), once as a live gate again.  Both
#     are silent in every behavioural test, because the corpus frame they would
#     change is the one this round froze.
#   * M5 is a control on the INSTRUMENT the falsifier depends on: if the shipped
#     IsMagicImmune reader stops consulting the BKB modifier, then "the target
#     was spell-immune by the shipped reader's own criterion" is no longer a
#     fact about anything, and the falsifier evaporates without a word.
#   * M8 mutates the FROZEN FRAME rather than the code: it checks that section 2
#     is reading the replay's modifier list and not a hardcoded expectation of
#     what that list says.  A pin that would pass on a frame carrying no
#     immunity is not pinning the falsification at all.
#
# Usage: bash tools/agent/mutstand_liondrainbkb.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_drain_immune_target.lua
OVERRIDES=bots/FunLib/aba_global_overrides.lua
FIXTURE=tests/frames/f_260905_004847_lion_drain_bkb.lua

FILES=("$HERO" "$TEST" "$OVERRIDES" "$FIXTURE")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ldb.XXXXXX")
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

# The filter is `lion`, not this one file: the sibling `liondrain` /
# `liondrainstop` tests assert on the same branch's neighbours, and a stand
# scoped to the new file only would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of two identical sites scores "survived" for the
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

# ---------------------------------------------------------------------------
# M1: THE VETO COMES BACK AS A TIDY-UP.  The call site is re-narrowed to the
#     stricter helper directly -- no gate, no id, no new function, nothing for a
#     wiring check to notice.  This is the withdrawn lever's effect with none of
#     its paperwork, and it is a DEFAULTS change: it would fire in every game
#     and every mode, not just an armed Turbo wave.
echo
echo "=== M1: the 团战吸蓝 call site is re-narrowed to the stricter helper ==="
sub "$HERO" "				and J.CanCastOnMagicImmune( npcEnemy ) -- see the PREMISE-FALSIFIED note by X.lion_ShouldStopDrain" \
            "				and J.CanCastOnNonMagicImmune( npcEnemy ) -- see the PREMISE-FALSIFIED note by X.lion_ShouldStopDrain"
score "M1" "no longer calls J.CanCastOnMagicImmune( npcEnemy )"

# ---------------------------------------------------------------------------
# M2: THE LESSON IS QUIETLY DELETED.  The code is unchanged and every
#     behavioural reading is unchanged; all that is gone is the record of WHY
#     the permissive helper is the right one.  The next reader re-derives the
#     veto from the same external KV sentence and the same 75-game corpus has to
#     be re-bought to stop them.
echo
echo "=== M2: the PREMISE-FALSIFIED note loses its banner ==="
sub "$HERO" "--- PREMISE-FALSIFIED (2026-09-06): the withdrawn" \
            "--- Historical note (2026-09-06): the withdrawn"
sub "$HERO" "-- see the PREMISE-FALSIFIED note by X.lion_ShouldStopDrain" \
            "-- see the historical note by X.lion_ShouldStopDrain"
score "M2" "no longer carries the PREMISE-FALSIFIED note"

# ---------------------------------------------------------------------------
# M3: THE VERDICT KEEPS ITS EVIDENCE-FREE HALF.  The banner survives, one of the
#     three replays does not.  A premise retired without the frames that retired
#     it is an opinion with a label on it, and the leg dropped here (M3 drops the
#     order-acceptance one) is the only leg that falsifies the sentence AS
#     WRITTEN -- the other two speak to what happens after the order is taken.
echo
echo "=== M3: the order-acceptance replay is dropped from the note ==="
sub "$HERO" "---   ORDER ACCEPTED WHILE IMMUNE.  1db27d__20260903_093254_slot1: the engine" \
            "---   ORDER ACCEPTED WHILE IMMUNE.  (replay reference dropped): the engine"
score "M3" "must keep naming all three replays"

# ---------------------------------------------------------------------------
# M4: THE VETO COMES BACK WITH ITS PAPERWORK.  A live turbo+candidate gate is
#     re-introduced inline at the call site.  Unlike M1 this one ships dark, so
#     it is defensible-looking -- and it is still the change whose premise this
#     round falsified, arriving without an answer to section 2.
echo
echo "=== M4: a live liondrainbkb gate is re-introduced at the call site ==="
sub "$HERO" "				and J.CanCastOnMagicImmune( npcEnemy ) -- see the PREMISE-FALSIFIED note by X.lion_ShouldStopDrain" \
            "				and J.CanCastOnMagicImmune( npcEnemy )
				and not ( J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainbkb' )
					and npcEnemy:IsMagicImmune() )"
score "M4" "still gates on liondrainbkb"

# ---------------------------------------------------------------------------
# M5: A CONTROL ON THE INSTRUMENT, NOT THE SUBJECT.  The shipped IsMagicImmune
#     reader stops consulting the BKB modifier.  Nothing in the fixture moves and
#     nothing in hero_lion.lua moves -- but "the target was spell-immune" stops
#     being a fact the shipped code would agree with, and the falsifier is empty.
#     The name list is READ from this file precisely so this cannot pass quietly.
echo
echo "=== M5: the shipped immunity reader stops consulting the BKB modifier ==="
sub "$OVERRIDES" "        or self:HasModifier('modifier_black_king_bar_immune')" \
                 "        or self:HasModifier('modifier_black_king_bar_immune_renamed')"
score "M5" "is no longer one of the names the shipped"

# ---------------------------------------------------------------------------
# M6: A CONTROL ON THE COUNTERFACTUAL.  Section 3's one labelled injection is
#     neutered.  Both helpers then answer the same thing, the comparison it
#     draws becomes vacuous, and "the stricter helper refuses this target" would
#     be asserted about a world where nobody is immune.
echo
echo "=== M6: section 3's immunity injection is neutered ==="
sub "$TEST" "    rawget(bb, '__spec').IsMagicImmune = true  -- INJECTION, see HONEST BOUNDS" \
            "    rawget(bb, '__spec').IsMagicImmune = false -- INJECTION, see HONEST BOUNDS"
score "M6" "the injection took"

# ---------------------------------------------------------------------------
# M7: A CONTROL ON THE SUPPLY SCAN.  If the scan stopped visiting enemy
#     hero-instants, "exactly 1 spell-immune instant in 9 frames" would be
#     vacuously true -- the same shape of blindness the previous version of this
#     stand checked for when the count it protected was 0.
echo
echo "=== M7: the supply scan stops visiting enemy hero-instants ==="
sub "$TEST" "            if h:GetTeam() ~= bot:GetTeam() then" \
            "            if false then"
score "M7" "enemy hero-instants moved from the measured 45"

# ---------------------------------------------------------------------------
# M8: THE FROZEN FRAME ITSELF IS MUTATED.  The target's immunity modifier is
#     swapped for the ITEM modifier of the same item -- a real modifier that
#     grants nothing, and exactly the confusion GH #357 recorded ("an item in a
#     slot cannot make IsMagicImmune answer true").  If section 2 passed anyway,
#     it would be asserting an expectation about the frame rather than reading
#     the frame.
echo
echo "=== M8: the frozen frame's BKB immunity becomes the mere item modifier ==="
sub "$FIXTURE" "{ name = 'modifier_black_king_bar_immune', remaining = 7.6, elapsed = 0.4, stacks = 0 }" \
               "{ name = 'modifier_item_black_king_bar', remaining = 7.6, elapsed = 0.4, stacks = 0 }"
score "M8" "the target is spell-immune by the shipped reader"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
exit 0
