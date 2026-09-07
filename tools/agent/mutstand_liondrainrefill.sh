#!/usr/bin/env bash
# Mutation stand for backlog -114 -- the mana-refill drain branch's widening,
# answered NOT TAKEN (hero, 2026-09-07, OWNER_PRIORITIES P4.4).  Run by hand
# when tests/test_lion_drain_refill_domain.lua, hero_lion.lua's X.ConsiderE, or
# the shipped IsMagicImmune override are edited, and before quoting any of that
# file's readings.
#
# WHAT THIS ONE HAS TO PROTECT.  Like mutstand_cullpromise.sh, this round landed
# NOTHING in bots/ -- so there is no gate to mutate.  What needs guarding is the
# READING that says the lever is not worth building, and it is built out of
# three kinds of thing that rot differently:
#
#   * READING (1), the SAME-CIRCLE fact (guard radius == scan radius)  -> M1, M2, M3
#   * READING (2), WHOSE NAMES the immunity list is spelled with       -> M4, M5, M6, M7
#   * the DECISION the widening would flip, and the ABSENCE of it      -> M8, M9, M10
#   * the unmeasurability claim's own driver                            -> M11
#
# THE THREE WORTH READING:
#   * M9 IS THE REVIVAL TRIPWIRE.  Somebody reads -114, disagrees, and just
#     swaps the refill loop's predicate for the permissive one -- ungated.  The
#     verdict here says that widening's surviving supply is dominated by this
#     ability's OWN immunity modifier, so taking it must go RED and say so, not
#     quietly pass because nothing tested a decision to do nothing.
#   * M6 IS THE DECISIVE READING'S TRIPWIRE.  "Exactly one immunity name is
#     spelled with this bot's own name" is the whole weight of NOT TAKEN.  Break
#     the singleton in either direction (M6 removes it, M7 adds a second) and
#     the file must stop agreeing.
#   * M8 IS THE INJECTION CONTROL.  Section 3 claims the shipped predicate
#     refuses a unit carrying the drain immunity and the widened one accepts it.
#     Neuter the injection and the section must collapse -- otherwise it was
#     comparing two predicates on a unit neither of them could tell apart, which
#     is exactly the vacuity the section asserts against FIRST.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cullpromise.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing (GH #550);
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# Usage: bash tools/agent/mutstand_liondrainrefill.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
OVERRIDES=bots/FunLib/aba_global_overrides.lua
TEST=tests/test_lion_drain_refill_domain.lua

FILES=("$HERO" "$OVERRIDES" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_liondrainrefill.XXXXXX")
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

# The filter is `lion`, not this one file: tests/test_lion_drain_combat_widen.lua
# and tests/test_lion_drain_immune_target.lua read the same immunity list, and a
# stand scoped to the new file alone would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort on an absent OR ambiguous anchor.
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

# Same, but for an anchor that is legitimately repeated: replaces EVERY hit and
# aborts only on absence.  Used where the mutant's meaning is "this string is
# gone from the file", which a single-hit substitution cannot express.
sub_all() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
if s.count(old) == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new))
PY
}

GUARD_ASSIGN='hEnemyList = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )'
CREEP_SCAN='bot:GetNearbyCreeps( 1600, true )'
REFILL_GUARD='if #hEnemyList == 0 and #nEnemyTowers == 0'
REFILL_TEST='and J.CanCastOnNonMagicImmune( nCreep )'
BKB_BUILD='"item_black_king_bar"'
PANGO=$'        or self:HasModifier(\'modifier_pangolier_rollup\')\n'
LIONMOD="'modifier_lion_mana_drain_immunity'"
INJECT=$'    spec.IsMagicImmune = true\n'
FRAME_TAIL=$'    \'tests/frames/f_260905_004847_lion_drain_bkb.lua\',\n}'

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
# M1: the GUARD's circle shrinks.  Reading (1) says the branch's own hero-free
#     conjunct covers the circle the creeps come out of.  Shrink the guard and
#     the annulus between them is NEW SUPPLY -- the verdict has to be re-taken,
#     not re-baselined.
echo
echo "=== M1: the hero-free guard shrinks to 1200u while the scan stays 1600u ==="
sub "$HERO" "$GUARD_ASSIGN" 'hEnemyList = J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE )'
score "M1 " "the annulus between them is new supply"

# ---------------------------------------------------------------------------
# M2: the SCAN's circle grows past the guard's -- the same divergence from the
#     other side.  Both directions matter: only one of them looks like a typo.
echo
echo "=== M2: the creep scan widens past the guard (1600 -> 900 guard-side read) ==="
sub "$HERO" "$CREEP_SCAN" 'bot:GetNearbyCreeps( 900, true )'
score "M2 " "the annulus between them is new supply"

# ---------------------------------------------------------------------------
# M3: the hero-free conjunct is DELETED outright.  Reading (1) then has no
#     premise at all, and the file must abort rather than pass on the remainder.
echo
echo "=== M3: the #hEnemyList == 0 conjunct is dropped from the refill guard ==="
sub "$HERO" "$REFILL_GUARD" 'if #nEnemyTowers == 0'
score "M3 " "reading (1) of this"

# ---------------------------------------------------------------------------
# M4: a name is DROPPED from the shipped immunity list (11 -> 10).  The count is
#     what makes reading (2)'s 9/2 split a partition rather than a sentence.
echo
echo "=== M4: a name is dropped from the shipped immunity list (11 -> 10) ==="
sub "$OVERRIDES" "$PANGO" ''
score "M4 " "modifier names, was 11"

# ---------------------------------------------------------------------------
# M5: a name is ADDED, and an unprefixed one -- so the residual channel this
#     file declares unresolvable grows without the HONEST BOUNDS noticing.
echo
echo "=== M5: an unprefixed name is added to the shipped immunity list ==="
sub "$OVERRIDES" "$PANGO" "$PANGO"$'        or self:HasModifier(\'modifier_some_new_immunity\')\n'
score "M5 " "modifier names, was 11"

# ---------------------------------------------------------------------------
# M6: THE DECISIVE READING'S TRIPWIRE, removal side.  Rename the drain immunity
#     so it is no longer spelled with this bot's name.  The singleton -- the
#     entire weight of NOT TAKEN -- must stop holding.
echo
echo "=== M6: modifier_lion_mana_drain_immunity loses its lion prefix ==="
sub "$OVERRIDES" "$LIONMOD" "'modifier_manadrain_immunity'"
score "M6 " "That singleton is why"

# ---------------------------------------------------------------------------
# M7: the same tripwire, addition side.  A SECOND lion-prefixed immunity name
#     means the supply inside the hero-free circle is no longer one thing, and
#     "dominated by this ability's own modifier" needs re-arguing.
echo
echo "=== M7: a second lion-prefixed immunity name appears ==="
sub "$OVERRIDES" "$PANGO" "$PANGO"$'        or self:HasModifier(\'modifier_lion_impale_immunity\')\n'
score "M7 " "That singleton is why"

# ---------------------------------------------------------------------------
# M8: THE INJECTION CONTROL.  Section 3's claim is that shipped refuses and
#     widened accepts.  Neuter the immunity half of the injection and the two
#     predicates become indistinguishable again -- which is precisely the
#     vacuity the section asserts against before leaning on anything.
echo
echo "=== M8: section 3's immunity injection is neutered into a no-op ==="
sub "$TEST" "$INJECT" $'    spec.IsMagicImmune = false\n'
score "M8 " "the injections took"

# ---------------------------------------------------------------------------
# M9: THE REVIVAL TRIPWIRE.  A later round takes the widening anyway, ungated,
#     by swapping the refill loop's predicate.  NOT TAKEN must be a claim the
#     tree can defend, not a sentence in a report.
echo
echo "=== M9: the refill loop is widened after all, ungated ==="
sub "$HERO" "$REFILL_TEST" 'and J.CanCastOnMagicImmune( nCreep )'
score "M9 " "was answered NOT TAKEN; if a"

# ---------------------------------------------------------------------------
# M10: the widening arrives GATED instead -- a soak id planted inside the refill
#      branch.  That needs its own id, its own domain reading and its own entry;
#      it must not slide in under this round's decision.
echo
echo "=== M10: a soak gate is planted inside the refill branch ==="
sub "$HERO" "$REFILL_TEST" $'and ( J.CanCastOnNonMagicImmune( nCreep ) or J.IsSoakCandidate( \'liondrainrefill\' ) )'
score "M10" "a soak gate appeared inside the mana-refill branch"

# ---------------------------------------------------------------------------
# M11: the unmeasurability claim's own driver.  Drop a frame and the count must
#      move -- otherwise "not one creep in this generator's entire output" could
#      be true of an empty loop.
echo
echo "=== M11: a frame is dropped from DRIVEN_FRAMES (13 -> 12) ==="
sub "$TEST" "$FRAME_TAIL" '}'
score "M11" "frames driven, was 13"

# ---------------------------------------------------------------------------
# M12: the item-build source for "BKB rides a hero item" disappears.  Without it
#      the second unprefixed name is an unsupported third channel, and the
#      HONEST BOUNDS understate what is unresolved.
echo
echo "=== M12: item_black_king_bar leaves Lion's own build list (both slots) ==="
sub_all "$HERO" "$BKB_BUILD" '"item_sheepstick"'
score "M12" "is no longer in"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
