#!/usr/bin/env bash
# Mutation stand for the `wkbonefight` candidate -- Bone Guard's release freed
# from its duel test (hero, 2026-09-05, OWNER_PRIORITIES P4.4).
# Run by hand when X.IsBoneGuardEnemyCountOk, X.ConsiderW or
# tests/test_wk_bone_guard_enemy_count.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axecallbkb.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing, nor "survived" for having
#     applied to the wrong one of two identical sites.
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  Four of the mutants are directional or instrumental
# rather than cosmetic, and they are the ones worth reading:
#   * M3 is the DEAD-WIRING twin: the helper exists, the id is registered, a call
#     site exists, and the armed answer is byte-for-byte the shipped one.  The
#     lever is then inert in every wave and the verdict reads back "tested, no
#     effect" with nothing raising a hand (GH #531's third shape).
#   * M4 is the FORBIDDEN DIRECTION and it is the mutant this lever was written
#     around.  `>= 2` reads exactly like the intended change -- "fire in
#     teamfights" -- and it silently STOPS the duel release the shipped code
#     makes.  No counter reports a Bone Guard that was not cast.
#   * M7 is a control on the SUPPLY SCAN.  If the visible-enemy counts stopped
#     being measured, section 2's histogram would be vacuous and the "1 of 7"
#     headline would rest on nothing.
#   * M8 is a control on the BLOCKER measurement, which is a ZERO reading and so
#     the most easily faked one in the file: point the modifier probe at a
#     modifier the corpus really carries.  If section 5 stays green, HasModifier
#     was answering false for everything and "on 0 of 13 frames" measured the
#     mock rather than the corpus.
#
# Usage: bash tools/agent/mutstand_wkbonefight.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_bone_guard_enemy_count.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkbf.XXXXXX")
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

# The filter is `wk`, not this one file: four sibling files assert on this hero's
# Bone Guard block and its talent bypass, and a stand scoped to the new file
# alone would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua wk > "$WORK/run.log" 2>&1
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

GATE_LINE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'wkbonefight\' )'
ARMED_LINE=$'\t\treturn nEnemies >= 1'
CALL_SITE=$'\t\tand X.IsBoneGuardEnemyCountOk( #nEnemysHerosInView )'

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
# M1: the candidate check is dropped.  The widening becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE_LINE" $'\tif J.IsModeTurbo()'
score "M1" "unarmed answer at n="

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE_LINE" $'\tif J.IsSoakCandidate( \'wkbonefight\' )'
score "M2" "non-turbo answer at n="

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  The armed branch returns the shipped predicate.
echo
echo "=== M3: the armed branch answers exactly what shipped answers ==="
sub "$HERO" "$ARMED_LINE" $'\t\treturn nEnemies == 1'
score "M3" "armed clause admits"

# ---------------------------------------------------------------------------
# M4: THE FORBIDDEN DIRECTION.  `>= 2` looks like the intended widening and is a
#     narrowing at n == 1: the shipped duel release disappears when armed.
echo
echo "=== M4: armed drops the duel case (widening becomes a swap) ==="
sub "$HERO" "$ARMED_LINE" $'\t\treturn nEnemies >= 2'
score "M4" "shipped releases and armed does not"

# ---------------------------------------------------------------------------
# M5: the count term stops being a count term.  Armed fires with nobody in view,
#     which turns branch 1 into an unconditional release the moment the two
#     upstream blockers are lifted.
echo
echo "=== M5: armed releases with zero enemies in view ==="
sub "$HERO" "$ARMED_LINE" $'\t\treturn true'
score "M5" "armed fires at 0 enemies"

# ---------------------------------------------------------------------------
# M6: the call site reverts to the literal duel test.  The helper, the id and the
#     gate all survive review; only the wire is gone.
echo
# (the literal is single-quoted: backticks inside a double-quoted echo are
# command substitution, which is what the first run of this stand printed as
# `==: command not found` -- harmless to the scoring, misleading to the reader.)
echo '=== M6: X.ConsiderW hardcodes `== 1` again and stops calling the helper ==='
sub "$HERO" "$CALL_SITE" $'\t\tand #nEnemysHerosInView == 1'
score "M6" "no longer calls the helper"

# ---------------------------------------------------------------------------
# M7: a control on the SUPPLY SCAN.  Collapse the radius the counts are taken
#     over.  Section 2's histogram is the whole of the "1 of 7" headline; if it
#     survives a radius that can contain nobody, it was never measuring.
echo
echo "=== M7: the supply scan's view radius is collapsed to zero (instrument control) ==="
sub "$TEST" "local VIEW_RADIUS = 1600  -- the radius X.ConsiderW passes to J.GetNearbyHeroes" \
            "local VIEW_RADIUS = 0  -- the radius X.ConsiderW passes to J.GetNearbyHeroes"
score "M7" "visible-enemy histogram moved"

# ---------------------------------------------------------------------------
# M8: a control on the BLOCKER measurement.  Section 5's "0 of 13" is a ZERO
#     reading, the kind that is true either because the corpus says so or because
#     the probe is broken.  Point it at a modifier the corpus really carries
#     (modifier_skeleton_king_vampiric_spirit_aura appears on WK instants) -- if
#     section 5 stays green, HasModifier answers false for everything.
echo
echo "=== M8: the blocker probe is pointed at a modifier the corpus DOES carry (instrument control) ==="
sub "$TEST" "local MOD = 'modifier_skeleton_king_bone_guard'" \
            "local MOD = 'modifier_skeleton_king_vampiric_spirit_aura'"
score "M8" "now appears on"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
