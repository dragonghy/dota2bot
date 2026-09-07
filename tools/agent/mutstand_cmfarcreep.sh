#!/usr/bin/env bash
# Mutation stand for the `cmfarcreep` candidate -- X.ConsiderW's "先远" half
# applying its mana-backed relaxed floor to the NEAR creep's health while the
# cast, the 460 floor and the cap are all about the FAR creep (hero, 2026-09-07,
# OWNER_PRIORITIES P4.4).  Run by hand when X.cm_IsFarCreepFloorMet,
# X.cm_GetStrongestUnit, X.ConsiderW or tests/test_cm_far_creep_floor.lua are
# edited, and before quoting any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmrangedhp.sh):
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
# reader (GH #507).  That bug has now been self-reported by this desk in three
# consecutive rounds; this line is not a substitute for the mechanism asked for
# in the hero charter's backlog `-119`.
#
# WHAT THIS STAND IS FOR.  Five of the ten are directional or instrumental
# rather than cosmetic, and they are the ones worth reading:
#   * M5 IS THE UNGATED-BEHAVIOUR-CHANGE MUTANT, and it is the one this lever is
#     most exposed to: swap the first two arguments at the call site and the
#     SHIPPED leg reads the far creep.  The lever's whole content is which
#     health each leg reads, so an argument swap ships the change with the gate
#     still nominally in place, and every gate-off/turbo assertion stays green.
#     Only section 1's exact-argument-order assertion sees it.
#   * M9 IS THE `liondrainbkb` LESSON (GH #549): superset is not correctness.
#     An armed leg answering a constant `true` is a strict superset of shipped
#     and section 3's dominance sweep certifies it happily; only the assertion
#     on the armed VALUE catches it.
#   * M3 IS THE DEAD-WIRING TWIN.  Helper, id, gate and call site all survive
#     review while the armed answer is byte-for-byte the shipped one -- the
#     lever is then inert in every wave and the verdict reads back "tested, no
#     effect" with nothing raising a hand (GH #531's third shape).  Section 3's
#     anti-vacuum counter is the only thing that sees it.
#   * M7 is the ORDER, which is the direction argument.  Consult the gate before
#     the shipped leg and the widening no longer provably reaches only frames
#     shipped refused -- nothing about the ANSWER moves, so no value assertion
#     can see it.
#   * M8 is a control on the ZERO in section 5, the most easily faked reading in
#     the file ("no creeps" is true both when the loader serves none and when
#     the probe is broken).  Point the probe at something the loader
#     demonstrably DOES serve.  If section 5 stays green, the coverage boundary
#     this file draws is prose.
#
# Usage: bash tools/agent/mutstand_cmfarcreep.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_far_creep_floor.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmfc.XXXXXX")
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

# The filter is `cm`, not this one file: a dozen sibling files assert on this
# hero's W block, its two pickers, its talent rows and its mana budget, and a
# stand scoped to the new file alone would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua cm > "$WORK/run.log" 2>&1
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

GATE_LINE=$'\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( \'cmfarcreep\' ) ) then return false end'
SHIPPED_LEG=$'\tif nNearHealth > nFloor then return true end'
ARMED_RETURN=$'\treturn nFarHealth > nFloor'
CALL_SITE='X.cm_IsFarCreepFloorMet( nEnemysStrongestCreepsHealth1, nEnemysStrongestCreepsHealth2, 390 )'
INITIALIZER=$'\tlocal nStrongestUnitHealth = GetBot():GetAttackDamage()'
CREEP_PROBE=$'            local t = bot:GetNearbyCreeps(nRadius, true)'

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
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsModeTurbo() ) then return false end'
score "M1" "gate OFF, near="

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsSoakCandidate( \'cmfarcreep\' ) ) then return false end'
score "M2" "armed in NON-turbo"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  Helper, id, gate and call site all survive review
#     while the armed leg answers exactly what the shipped leg already answered.
echo
echo "=== M3: the armed branch re-reads the NEAR health (inert lever) ==="
sub "$HERO" "$ARMED_RETURN" $'\treturn nNearHealth > nFloor'
score "M3" "arming widened NOTHING"

# ---------------------------------------------------------------------------
# M4: the call site reverts to the bare inline test.  The helper, the id and the
#     gate all survive review; only the wire is gone, and check_armed_wiring.py's
#     question ("does a call site exist?") is the one thing this does not answer.
echo
echo '=== M4: the call site inlines `Health1 > 390` again ==='
sub "$HERO" "$CALL_SITE" 'nEnemysStrongestCreepsHealth1 > 390'
score "M4" "still carries the bare"

# ---------------------------------------------------------------------------
# M5: THE UNGATED BEHAVIOUR CHANGE.  Swap the first two arguments and the
#     SHIPPED leg reads the far creep -- the lever's entire content, delivered
#     with the gate still nominally in place.  Every gate-off and turbo-only
#     assertion stays green because the helper is unchanged.
echo
echo "=== M5: the call site swaps near and far (ships the change ungated) ==="
sub "$HERO" "$CALL_SITE" \
    'X.cm_IsFarCreepFloorMet( nEnemysStrongestCreepsHealth2, nEnemysStrongestCreepsHealth1, 390 )'
score "M5" "argument ORDER"

# ---------------------------------------------------------------------------
# M6: the helper stops reading its third argument and hardcodes the floor.  The
#     shipped tree still behaves identically, so nothing about gate-off moves;
#     what moves is that the floor at the call site stops being the floor.
echo
echo "=== M6: the helper hardcodes 390 and ignores nFloor ==="
sub "$HERO" "$ARMED_RETURN" $'\treturn nFarHealth > 390'
score "M6" "not reading its third argument"

# ---------------------------------------------------------------------------
# M7: THE ORDER, which IS the direction argument.  Consult the gate first and the
#     widening no longer provably reaches only frames the shipped leg refused.
#     The ANSWER does not move on any input, so no value assertion sees it.
echo
echo "=== M7: the gate is consulted before the shipped leg (direction premise) ==="
NL=$'\n'
sub "$HERO" "${SHIPPED_LEG}${NL}${NL}${GATE_LINE}" "${GATE_LINE}${NL}${NL}${SHIPPED_LEG}"
score "M7" "the gate was consulted"

# ---------------------------------------------------------------------------
# M8: a control on the ZERO in section 5.  Point the creep probe at the hero
#     scan, which the loader demonstrably DOES serve.  If section 5 stays green,
#     the coverage boundary this file draws is prose, not a reading.
echo
echo "=== M8: the creep probe is pointed at the hero scan (instrument control) ==="
sub "$TEST" "$CREEP_PROBE" \
    $'            local t = bot:GetNearbyHeroes(nRadius, true, 0)'
score "M8" "answered"

# ---------------------------------------------------------------------------
# M9: SUPERSET IS NOT CORRECTNESS (GH #549).  A constant `true` on the armed leg
#     dominates shipped everywhere; section 3's dominance sweep certifies it.
echo
echo "=== M9: the armed leg answers a constant true ==="
sub "$HERO" "$ARMED_RETURN" $'\treturn true'
score "M9" "A superset check alone cannot see this"

# ---------------------------------------------------------------------------
# M10: THE FALLBACK'S IDENTITY, which is the half of the header that says WHY
#      the defect bites where the far branch matters.  Zero the picker's
#      initialiser: the argument in the helper header ("Health1 falls back to her
#      attack damage") becomes false while every behavioural assertion about the
#      lever itself stays green.
echo
echo "=== M10: the picker initialises its running maximum to 0 ==="
sub "$HERO" "$INITIALIZER" $'\tlocal nStrongestUnitHealth = 0'
score "M10" "no longer initialises its running maximum"

# ---------------------------------------------------------------------------
echo
echo "=== restoring and re-checking the baseline ==="
restore
run_tests; FINAL=$?
echo "post-restore EXIT=$FINAL"
echo
echo "SCORE: $CAUGHT/$TOTAL caught"
[ "$FINAL" -eq 0 ] || exit 2
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
exit 0
