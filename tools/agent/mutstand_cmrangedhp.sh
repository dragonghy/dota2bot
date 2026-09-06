#!/usr/bin/env bash
# Mutation stand for the `cmrangedhp` candidate -- the hardcoded 500 that
# X.cm_GetStrongestUnit reports as the health of the ranged creep it
# early-returns (hero, 2026-09-06, OWNER_PRIORITIES P4.4).  Run by hand when
# X.cm_GetRangedCreepReportedHealth, X.cm_GetStrongestUnit, X.ConsiderW or
# tests/test_cm_ranged_creep_health.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmcreepcap.sh):
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
# WHAT THIS STAND IS FOR.  Four of the nine are directional or instrumental
# rather than cosmetic, and they are the ones worth reading:
#   * M6 IS THE ONE THAT MOVES THE PREMISE.  This lever cannot widen: 500 clears
#     every floor and every rank's cap, so no armed value can admit where
#     shipped declines, and the per-pair subset check in section 3 is an
#     IDENTITY that cannot fail.  What CAN break the direction claim is the
#     premise itself -- a consumer floor above 500.  M6 raises `> 460` to
#     `> 560` and is the only mutant in this stand that makes the header's
#     narrowing sentence false.  No assertion about the armed value can see it.
#   * M9 IS THE `liondrainbkb` LESSON (GH #549) MADE CONCRETE: subset is not
#     correctness.  An armed leg answering a constant 1 is still a strict subset
#     of shipped and section 3 certifies it happily; the only thing that catches
#     it is section 6's assertion that armed reports the unit's OWN health.
#   * M7 is a control on the REAL-FRAME READS.  Section 2's whole claim is that
#     the rank and the cap come off the real Frostbite handle on each fixture.
#     Point the handle at a sibling ability that declares none of the three
#     keys: if section 2 stays green, it was reading a blanket mock answer.
#   * M8 is a control on the ZERO in section 5, the most easily faked reading in
#     the file ("no creeps" is true both when the loader serves none and when
#     the probe is broken).  Point the probe at something the loader
#     demonstrably DOES serve.  If section 5 stays green, the coverage boundary
#     this file draws is prose.
#
# Usage: bash tools/agent/mutstand_cmrangedhp.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_ranged_creep_health.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmrhp.XXXXXX")
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
# hero's W block, its pickers, its talent rows and its mana budget, and a stand
# scoped to the new file alone would report a collision there as SURVIVED.
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

GATE_LINE=$'\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( \'cmrangedhp\' ) ) then return nShipped end'
ARMED_RETURN=$'\treturn nHealth\n'
ZERO_GUARD=$'\tif nHealth == nil or nHealth <= 0 then return nShipped end'
CALL_SITE=$'\t\t\t\treturn unit, X.cm_GetRangedCreepReportedHealth( unit )'
FLOOR_460=$'\t\t\tif ( nEnemysStrongestCreepsHealth2 > 460'

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
# M1: the candidate check is dropped.  The repair becomes the shipped default in
#     every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsModeTurbo() ) then return nShipped end'
score "M1" "gate off, health"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsSoakCandidate( \'cmrangedhp\' ) ) then return nShipped end'
score "M2" "outside turbo the armed helper reported"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  Helper, id, gate and call site all survive review
#     while the armed answer is byte-for-byte the shipped one.  The lever is then
#     inert in every wave and the verdict reads back "tested, no effect" with
#     nothing raising a hand (GH #531's third shape).
echo
echo "=== M3: the armed branch answers exactly what shipped answers ==="
sub "$HERO" "$ARMED_RETURN" $'\treturn nShipped\n'
score "M3" "armed reported"

# ---------------------------------------------------------------------------
# M4: the call site reverts to the bare literal.  The helper, the id and the gate
#     all survive review; only the wire is gone, and `check_armed_wiring.py`'s
#     question ("does a call site exist?") is the one thing this does not answer.
echo
echo "=== M4: the call site hardcodes 500 again ==="
sub "$HERO" "$CALL_SITE" $'\t\t\t\treturn unit, 500'
score "M4" "still returns the bare literal 500"

# ---------------------------------------------------------------------------
# M5: the fall-through is disarmed.  `< 0` lets a zero health read through, and
#     reporting 0 does not narrow this exit -- it CLOSES it, since 0 fails every
#     floor, so the ranged half of the farm block goes silent in every armed
#     turbo game (the GH #162 house rule).
echo
echo "=== M5: a zero health read is allowed through as a reported 0 ==="
sub "$HERO" "$ZERO_GUARD" $'\tif nHealth == nil or nHealth < 0 then return nShipped end'
score "M5" "it would CLOSE it"

# ---------------------------------------------------------------------------
# M6: THE PREMISE.  This lever cannot widen -- 500 clears every floor and every
#     cap, so the per-pair subset check in section 3 is an identity that no armed
#     value can break.  What CAN break the direction claim is a consumer floor
#     ABOVE 500.  Nothing that asserts on the armed value sees this.
echo
echo "=== M6: a consumer floor is raised above the shipped report (the direction premise) ==="
sub "$HERO" "$FLOOR_460" $'\t\t\tif ( nEnemysStrongestCreepsHealth2 > 560'
score "M6" "no longer clears the floor"

# ---------------------------------------------------------------------------
# M7: a control on the REAL-FRAME READS.  Point section 2's handle at Crystal
#     Nova, which declares none of damage_per_second / creep_multiplier /
#     duration.  If section 2 stays green, its "live KV off a real handle" claim
#     was reading a blanket mock answer rather than this ability.
echo
echo "=== M7: the real-frame handle is pointed at a sibling ability (instrument control) ==="
sub "$TEST" "local FROST = 'crystal_maiden_frostbite'" \
            "local FROST = 'crystal_maiden_crystal_nova'"
score "M7" "answered a cap of 0"

# ---------------------------------------------------------------------------
# M8: a control on the ZERO in section 5.  Point the creep probe at the hero
#     scan, which the loader demonstrably DOES serve.  If section 5 stays green,
#     "no creeps on any frame" was measuring the probe, not the loader, and the
#     coverage boundary this file draws is prose.
echo
echo "=== M8: the empty-creep probe is pointed at something the loader serves (instrument control) ==="
sub "$TEST" "local t = bot:GetNearbyCreeps(1400, bEnemy)" \
            "local t = bot:GetNearbyHeroes(1400, bEnemy, 0)"
score "M8" "creep(s) on"

# ---------------------------------------------------------------------------
# M9: SUBSET IS NOT CORRECTNESS.  A constant 1 is below the shipped 500, so it
#     is a strict subset of shipped at every rank and every floor and section 3
#     certifies it.  Only the value assertion in section 6 says it is wrong.
echo
echo "=== M9: the armed leg reports a constant below 500 (still a subset) ==="
sub "$HERO" "$ARMED_RETURN" $'\treturn 1\n'
score "M9" "Any constant below"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
