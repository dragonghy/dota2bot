#!/usr/bin/env bash
# Mutation stand for the `axecallbkb` candidate -- Berserker's Call allowed to
# fire through spell immunity (hero, 2026-09-05, OWNER_PRIORITIES P4.4).
# Run by hand when X.IsCallPierceOn, X.ConsiderQ or
# tests/test_axe_call_immune_veto.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cullthresh.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent ABORTS instead of scoring caught;
#   * NEW HERE, and it is the `-91`/`-94` guard finally written into a fresh
#     stand rather than retrofitted: an anchor that occurs MORE THAN ONCE also
#     aborts.  This file needs it more than most -- `X.ConsiderQ` and
#     `X.ConsiderR` carry near-identical immunity clauses two hundred lines
#     apart, and `replace(..., 1)` would quietly mutate whichever came first.
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  Three of the mutants are directional rather than
# cosmetic, and they are the ones worth reading:
#   * M4 is the DEAD-WIRING twin: the helper exists, the gate id is registered,
#     the wiring check finds a call site -- and the clause reverts to the shipped
#     predicate, so the lever is inert in every wave and the verdict reads back
#     "tested, no effect" with nothing raising a hand.
#   * M6 is the FORBIDDEN DIRECTION: dropping the shipped operand at branch (ii)
#     turns a widening into a NARROWING, and gate-off then stops casting Calls it
#     used to cast.  No in-domain counter would report "Axe stopped Calling".
#   * M8 is a control on the INSTRUMENT, not the subject: if the supply scan's
#     ring stopped measuring distances, section 2's "never co-occur" would be
#     vacuously true, and that is the sentence the whole domain claim rests on.
#
# Usage: bash tools/agent/mutstand_axecallbkb.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_call_immune_veto.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_acb.XXXXXX")
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

# The filter is `axe`, not this one file: the sibling `axecull` file asserts on
# the same function's neighbours, and a stand scoped to the new file only would
# report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua axe > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of two identical sites scores "survived" for the
# wrong reason -- which is the shape `-91` and `-94` both cost a round on.
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
# M1: the candidate check is dropped.  The widening is now the shipped default in
#     every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecallbkb' )" \
            "	return J.IsModeTurbo()"
score "M1" "shipped code declines an interrupt it could land"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1,
#     and the one every behavioural case in this file would miss.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "	return J.IsModeTurbo() and J.IsSoakCandidate( 'axecallbkb' )" \
            "	return J.IsSoakCandidate( 'axecallbkb' )"
score "M2" "outside turbo the candidate must be inert"

# ---------------------------------------------------------------------------
# M3: branch (i)'s widening loses its gate.  Shipped Turbo behaviour changes with
#     nothing armed -- the exact thing "ships dark" is supposed to prevent.
echo
echo "=== M3: branch (i) widens unconditionally (the gate leaves the clause) ==="
sub "$HERO" "			and ( not npcEnemy:IsMagicImmune() or X.IsCallPierceOn() ) -- see X.IsCallPierceOn" \
            "			and true -- see X.IsCallPierceOn"
score "M3" "shipped code declines an interrupt it could land"

# ---------------------------------------------------------------------------
# M4: THE DEAD-WIRING TWIN.  The clause reverts to the shipped predicate while
#     the helper, the id and the call-site-existence check all stay intact.  A
#     wave would arm this and read back "no effect" with nothing raising a hand.
echo
echo "=== M4: branch (i) reverts to the shipped predicate (the dead-wiring twin) ==="
sub "$HERO" "			and ( not npcEnemy:IsMagicImmune() or X.IsCallPierceOn() ) -- see X.IsCallPierceOn" \
            "			and not npcEnemy:IsMagicImmune() -- see X.IsCallPierceOn"
score "M4" "armed desire, got 0"

# ---------------------------------------------------------------------------
# M5: branch (ii)'s widened operand is wired to the NON-piercing helper.  It
#     reads as a widening and is a tautology: an operand that can only be true
#     when the operand beside it is already true.  No behavioural case in this
#     file can see it, because branch (ii) has no behavioural case at all.
echo
echo "=== M5: branch (ii)'s widened operand uses the non-piercing helper ==="
sub "$HERO" "					or ( X.IsCallPierceOn() and J.CanCastOnMagicImmune( botTarget ) ) ) -- see X.IsCallPierceOn" \
            "					or ( X.IsCallPierceOn() and J.CanCastOnNonMagicImmune( botTarget ) ) ) -- see X.IsCallPierceOn"
score "M5" "must be gated AND must use the magic-immune-piercing helper"

# ---------------------------------------------------------------------------
# M6: THE FORBIDDEN DIRECTION.  Branch (ii) loses its shipped operand, so gate
#     OFF the branch stops firing on targets it used to fire on.  A lever that is
#     only allowed to add casts silently removes them.
echo
echo "=== M6: branch (ii) drops the shipped operand (widening becomes narrowing) ==="
sub "$HERO" "			and ( J.CanCastOnNonMagicImmune( botTarget )
					or ( X.IsCallPierceOn() and J.CanCastOnMagicImmune( botTarget ) ) ) -- see X.IsCallPierceOn" \
            "			and ( X.IsCallPierceOn() and J.CanCastOnMagicImmune( botTarget ) ) -- see X.IsCallPierceOn"
score "M6" "the shipped operand must stay FIRST"

# ---------------------------------------------------------------------------
# M7: a control on the KV cross-check.  Move the recalled cooldown anchor off the
#     shipped ladder: if section KV stays green, it was reading its own constant
#     back and the "17.0 of 18" reading in section 1 rests on nothing.
echo
echo "=== M7: the recalled cooldown anchor is moved off the KV ladder (instrument control) ==="
sub "$TEST" "local Q_COOLDOWN = { 18, 16, 14, 12 }" \
            "local Q_COOLDOWN = { 17, 16, 14, 12 }"
score "M7" "cooldown: anchor 17"

# ---------------------------------------------------------------------------
# M8: a control on the SUPPLY SCAN.  Collapse the ring the scan measures against.
#     Section 2's "Call ready and enemy in the ring never co-occur" is the whole
#     of this lever's domain claim; if it survives a ring that can contain
#     nothing, the claim was vacuous rather than measured.
echo
echo "=== M8: the supply scan's ring is collapsed to zero (instrument control) ==="
sub "$TEST" "local RING = Q_RADIUS - 50  -- the interrupt branch's GetAroundEnemyHeroList arg" \
            "local RING = 0  -- the interrupt branch's GetAroundEnemyHeroList arg"
score "M8" "in-ring frames dropped below the measured 1"

# ---------------------------------------------------------------------------
# The EXIT trap restores and verifies; do not restore-and-delete here.
echo
echo "=== $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
exit 0
