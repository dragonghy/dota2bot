#!/usr/bin/env bash
# Mutation stand for GH #570 -- the False Promise veto proposed for Axe's
# X.HasSpecialModifier, WITHDRAWN as PREMISE-FALSIFIED (hero, 2026-09-06,
# OWNER_PRIORITIES P4.4).  Run by hand when tests/test_axe_cull_promise_premise
# .lua, tests/frames/f_260828_124358_axe_cull_promise.lua, hero_axe.lua's
# X.HasSpecialModifier, or either of the two containment instruments are edited,
# and before quoting any of that file's readings.
#
# WHAT IS UNUSUAL ABOUT THIS ONE.  Every other stand in this directory guards a
# lever that landed in bots/.  This round landed NOTHING in bots/: the evidence
# said the veto would delete kills, so there is no gate to mutate.  What the
# stand has to protect instead is the READING that says so -- a reading built
# from four different kinds of thing, each of which can rot in its own way:
#
#   * the SHIPPED SOURCE (the omission is real)                  -> M1, M2
#   * the STAGED FRAME (the veto would fire, on a real world)    -> M3, M8, M9
#   * FROZEN COMBAT-LOG ROWS (the cast was a kill)               -> M4
#   * the two CONTAINMENT INSTRUMENTS (2 vs 0)                   -> M5, M6, M7
#
# THE THREE WORTH READING:
#   * M1 IS THE REVIVAL TRIPWIRE.  Somebody reads GH #570, agrees with its
#     prose, and adds the name to the veto list.  The verdict here says that
#     costs kills on the only frame anyone has -- so adding it must go RED and
#     say so, not quietly pass because nothing tested the withdrawal.
#   * M5 IS THE FRAME THAT WOULD REVIVE THE LEVER, SIMULATED.  Move one window's
#     end so a cull lands STRICTLY inside a live promise, and section 6's
#     half-open zero must go red and NAME it.  A verdict of "premise falsified"
#     is only honest if it can be un-falsified by new supply; this mutant is the
#     proof that it can.
#   * M3 IS THE INJECTION CONTROL.  Section 4's whole claim is that the proposed
#     veto WOULD have fired here.  Neuter the injection into a no-op and the
#     section must stop passing -- otherwise it was asserting that a frame the
#     veto never read is a frame the veto would change.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusfightquorum.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing, nor "survived" for having
#     applied to the wrong one of two identical sites (GH #550);
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# Usage: bash tools/agent/mutstand_cullpromise.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_cull_promise_premise.lua
FRAME=tests/frames/f_260828_124358_axe_cull_promise.lua
SCANNER=tools/batch_test/behavioral/cullthresh_domain.py
GENERATOR=tools/batch_test/replayscope/make_fixture.py

FILES=("$HERO" "$TEST" "$FRAME" "$SCANNER" "$GENERATOR")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cullpromise.XXXXXX")
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

# The filter is `axe`, not this one file: tests/test_axe_cull_immune_veto.lua
# also reads X.HasSpecialModifier's name list, and a stand scoped to the new
# file alone would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua axe > "$WORK/run.log" 2>&1
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

ILLUSION=$'\t\tor npcEnemy:HasModifier( \'modifier_illusion\' )'
SPHERE=$'\t\tor npcEnemy:HasModifier( \'modifier_item_sphere_target\' )'
INJECT='        if npcEnemy:HasModifier(FP) then fired = fired + 1 return true end'
CAST_ROW='    { t = 1203.9, target = '"'"'npc_dota_hero_phantom_assassin'"'"', death_t = 1203.9, dmg =  16 },'
WINDOW_ROW='    { target = '"'"'npc_dota_hero_oracle'"'"',      add = 1452.7, remove = 1452.9 },'
SCANNER_CMP='            if a <= t <= b:'
GEN_CMP='            live = [(s, e) for (s, e) in ivs if s <= t < e]'
FRAME_MOD="{ name = 'modifier_oracle_false_promise_timer', remaining = 0.1, elapsed = 0.1, stacks = 0 }, "
FRAME_HP='hp = 437, max_hp = 2253'

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
# M1: THE REVIVAL TRIPWIRE.  A later round takes GH #570's prose at face value
#     and adds the name to the shipped veto list.  On the one frame in the tree
#     where it can fire, that deletes a hero kill.
echo
echo "=== M1: the False Promise veto is added to the shipped list after all ==="
sub "$HERO" "$ILLUSION" \
    "$ILLUSION"$'\n\t\tor npcEnemy:HasModifier( \'modifier_oracle_false_promise_timer\' )'
score "M1" "re-open GH #570"

# ---------------------------------------------------------------------------
# M2: a name is DROPPED from the shipped list instead.  The count assertion is
#     what makes "seven, and none of them Oracle's" a measurement rather than a
#     sentence; without it the loop over names passes trivially on an empty list.
echo
echo "=== M2: a name is dropped from the shipped veto list (7 -> 6) ==="
sub "$HERO" "$SPHERE" ''
score "M2" "it now names 6"

# ---------------------------------------------------------------------------
# M3: THE INJECTION CONTROL.  Section 4 claims the proposed veto would fire on
#     this frame.  Make the injection a no-op that still counts itself and the
#     claim must collapse -- a veto that changes nothing cannot be evidence that
#     the veto changes something.
echo
echo "=== M3: section 4's injected veto is neutered into a no-op ==="
sub "$TEST" "$INJECT" '        if npcEnemy:HasModifier(FP) then fired = fired + 1 end'
score "M3" "the veto suppresses the branch"

# ---------------------------------------------------------------------------
# M4: a frozen cast row loses its kill.  "Every cull in that game is a kill" is
#     the row that turns the request's 2 hits from waste into value; if the rows
#     can drift without anything noticing, the verdict rests on a transcription.
echo
echo "=== M4: one frozen cast row is made a MISS instead of a kill ==="
sub "$TEST" "$CAST_ROW" \
    '    { t = 1203.9, target = '"'"'npc_dota_hero_phantom_assassin'"'"', death_t = 1300.0, dmg =  16 },'
score "M4" "has no DEATH row at the same tick"

# ---------------------------------------------------------------------------
# M5: THE FRAME THAT WOULD REVIVE THE LEVER.  Extend the last promise window
#     past the cull, so the cast lands STRICTLY inside a live promise.  Section
#     6's half-open counter must go red and name it -- that is the shape of the
#     evidence GH #570 always needed and never had.
echo
echo "=== M5: one window is extended so a cull lands strictly INSIDE it ==="
sub "$TEST" "$WINDOW_ROW" \
    '    { target = '"'"'npc_dota_hero_oracle'"'"',      add = 1452.7, remove = 1460.0 },'
score "M5" "that is the frame GH #570 always needed"

# ---------------------------------------------------------------------------
# M6: the scanner is quietly fixed to half-open.  That is a GOOD change, and it
#     still has to be loud: it moves the 449-cast count that opened the issue, so
#     the stand must force somebody to re-take that reading.
echo
echo "=== M6: the domain scanner switches to half-open containment ==="
sub "$SCANNER" "$SCANNER_CMP" '            if a <= t < b:'
score "M6" "no longer uses CLOSED containment"

# ---------------------------------------------------------------------------
# M7: the generator drifts the OTHER way, to closed.  Then the staged frame
#     itself would have been built by a closed reconstruction, and its
#     `remaining = 0.1` would mean something different from what section 8 says.
echo
echo "=== M7: the fixture generator switches to closed containment ==="
sub "$GENERATOR" "$GEN_CMP" \
    '            live = [(s, e) for (s, e) in ivs if s <= t <= e]'
score "M7" "no longer uses HALF-OPEN containment"

# ---------------------------------------------------------------------------
# M8: the supply control.  Strip the modifier out of the staged frame and every
#     "the veto would fire here" sentence loses its world.  A frame that no
#     longer carries the buff must not still pass as the frame that does.
echo
echo "=== M8: the staged frame loses the False Promise modifier ==="
sub "$FRAME" "$FRAME_MOD" ''
score "M8" "the promise is LIVE at the decision instant"

# ---------------------------------------------------------------------------
# M9: the decision is read off the REAL frame, not stubbed.  Put oracle's HP
#     above the execute threshold and the shipped branch must stop firing -- if
#     section 3 still reports HIGH, it was not reading the frame's numbers.
echo
echo "=== M9: oracle's HP is raised above the execute threshold ==="
sub "$FRAME" "$FRAME_HP" 'hp = 1437, max_hp = 2253'
score "M9" "oracle's real HP at the instant"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ]
