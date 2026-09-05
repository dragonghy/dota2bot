#!/usr/bin/env bash
# Mutation stand for the `cmcreepcap` candidate -- Frostbite's creep-farm health
# ceiling taken off its rank-4 literal (hero, 2026-09-05, OWNER_PRIORITIES P4.4).
# Run by hand when X.cm_GetFrostbiteCreepCap, X.ConsiderW or
# tests/test_cm_frostbite_creep_cap.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkbonefight.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing, nor "survived" for having
#     applied to the wrong one of two identical sites;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  Four of the eight are directional or instrumental
# rather than cosmetic, and they are the ones worth reading:
#   * M3 is the DEAD-WIRING twin: helper, id, gate and both call sites all
#     survive review while the armed answer is byte-for-byte the shipped one.
#     The lever is then inert in every wave and the verdict reads back "tested,
#     no effect" with nothing raising a hand (GH #531's third shape).
#   * M4 is the FORBIDDEN DIRECTION, and it is the one mutant that reads like a
#     correction rather than a bug: "+1s, because of the duration talent".  It
#     turns the narrowing into a WIDENING (1600 at rank 4), which would let a
#     negative reading be blamed on a cast the lever invented -- the exact
#     attribution this file's header promises is impossible.  Nothing but the
#     rank ladder in section 3 can see it; no single-rank assertion can.
#   * M7 is a control on the REAL-FRAME READS.  Section 2's whole claim is that
#     the three KV values come off the real Frostbite handle.  Point the handle
#     at a sibling ability that declares none of the three: if section 2 stays
#     green, it was reading the mock's blanket answer, not this ability.
#   * M8 is a control on the ZERO in section 5, which is the most easily faked
#     reading in the file ("no creeps" is true both when the loader serves none
#     and when the probe is broken).  Point the probe at something the loader
#     demonstrably DOES serve.  If section 5 stays green, the scan was never
#     measuring anything and the coverage boundary is prose.
#
# Usage: bash tools/agent/mutstand_cmcreepcap.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_frostbite_creep_cap.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmcc.XXXXXX")
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
# hero's W block, its talent rows and its mana budget, and a stand scoped to the
# new file alone would report a collision there as SURVIVED.
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

GATE_LINE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'cmcreepcap\' )'
ARMED_RETURN=$'\t\t\treturn nKvCreepDamage'
DURATION_TERM=$'\t\t\t\t\t\t\t * hAbility:GetSpecialValueFloat( \'duration\' )'
ZERO_GUARD=$'\t\tif nKvCreepDamage > 0'
CALL_SITE_2=$'\t\t\t\tand nEnemysStrongestCreepsHealth2 <= nCreepCap'

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
# M1: the candidate check is dropped.  The narrowing becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE_LINE" $'\tif J.IsModeTurbo()'
score "M1" "un-armed rank"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE_LINE" $'\tif J.IsSoakCandidate( \'cmcreepcap\' )'
score "M2" "non-turbo rank"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  The armed branch hands back the shipped literal.
echo
echo "=== M3: the armed branch answers exactly what shipped answers ==="
sub "$HERO" "$ARMED_RETURN" $'\t\t\treturn 1200'
score "M3" "armed differs on 0 frames"

# ---------------------------------------------------------------------------
# M4: THE FORBIDDEN DIRECTION.  `+ 1` on the duration reads like a correction --
#     "account for the +1.0s talent" -- and turns the narrowing into a widening
#     (1600 at rank 4).  Only the rank LADDER in section 3 sees it.
echo
echo "=== M4: the duration term is widened by a second (narrowing becomes widening) ==="
sub "$HERO" "$DURATION_TERM" $'\t\t\t\t\t\t\t * ( hAbility:GetSpecialValueFloat( \'duration\' ) + 1 )'
score "M4" "> shipped 1200"

# ---------------------------------------------------------------------------
# M5: the fall-through is disarmed.  `>= 0` lets a zero KV read through, and a
#     cap of 0 does not narrow the farm block -- it CLOSES it, silently, in every
#     armed turbo game.  This is the mutant section 7 exists for.
echo
echo "=== M5: a zero KV read is allowed through as a cap of 0 ==="
sub "$HERO" "$ZERO_GUARD" $'\t\tif nKvCreepDamage >= 0'
score "M5" "it closes it"

# ---------------------------------------------------------------------------
# M6: one call site reverts to the literal.  The helper, the id, the gate and the
#     OTHER call site all survive review; only one wire is gone, and the block is
#     rank-independent again on the branch that searches the WIDER radius.
echo
echo '=== M6: the far-creep call site hardcodes 1200 again ==='
sub "$HERO" "$CALL_SITE_2" $'\t\t\t\tand nEnemysStrongestCreepsHealth2 <= 1200'
score "M6" "is back in X.ConsiderW"

# ---------------------------------------------------------------------------
# M7: a control on the REAL-FRAME READS.  Point section 2's handle at Crystal
#     Nova, which declares none of damage_per_second / creep_multiplier /
#     duration.  If section 2 stays green, its "live KV off a real handle" claim
#     was reading a blanket mock answer rather than this ability.
echo
echo "=== M7: the real-frame handle is pointed at a sibling ability (instrument control) ==="
sub "$TEST" "local FROST = 'crystal_maiden_frostbite'" \
            "local FROST = 'crystal_maiden_crystal_nova'"
score "M7" "dps read is not live"

# ---------------------------------------------------------------------------
# M8: a control on the ZERO in section 5.  Point the creep probe at the hero
#     scan, which the loader demonstrably DOES serve.  If section 5 stays green,
#     "no creeps on any frame" was measuring the probe, not the loader, and the
#     coverage boundary this file draws is prose.
echo
echo "=== M8: the empty-creep probe is pointed at something the loader serves (instrument control) ==="
sub "$TEST" "assert(#bot:GetNearbyCreeps(1600, true) == 0, path" \
            "assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0, path"
score "M8" "GOOD NEWS"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
