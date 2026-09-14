#!/usr/bin/env bash
# Mutation stand for the `cmrspeed` candidate -- the hurt-count ring on
# X.ConsiderR's branch 1 in bots/BotLib/hero_crystal_maiden.lua, which SUBTRACTS
# A SPEED FROM A DISTANCE and so carries an unwritten factor of exactly one
# second (hero, 2026-09-14, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.cm_GetFieldHurtRing, X.ConsiderR branch 1 or
# tests/test_cm_field_hurt_ring.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmrflee.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick;
#   * ⚠️ an anchor is taken from CODE, never from prose (the 2026-09-13 Lion
#     round scored a mutant SURVIVED because perl rewrote the lever's own header
#     comment).  Every anchor below is checked for uniqueness by `sub` itself.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while moving
# nothing, or moving the wrong thing:
#   * M4 IS THE REASON THE STAND EXISTS.  Reading the horizon from
#     `AbilityCastPoint` instead of `explosion_interval` leaves the helper, the
#     id, the call site, the clamp and the direction guarantee all intact -- and
#     crystal_maiden_freezing_field declares AbilityCastPoint 0, so the armed
#     ring becomes `base - speed * 0` = the FULL base ring on every frame.  That
#     is not a no-op, it is a DIFFERENT and much larger lever wearing this one's
#     id, and nothing about the source shape says so.
#   * M5 is the dead-wiring twin: a horizon of 1.0 is the shipped expression, so
#     the armed leg is inert in every wave and a verdict reads back "tested, no
#     effect" with nobody raising a hand.
#   * M7 is the CLAMP REMOVAL.  Without `nHorizon > X.nRHurtHorizonShipped` the
#     armed leg can NARROW, and the note's "a negative wave read can never be a
#     lever-eaten release" sentence becomes false while the code still reads
#     like a widening.
#   * M9 is the ARGUMENT SWAP: this helper takes two scalars and a handle, so a
#     swapped pair is invisible to any assertion that does not pin the call
#     literally.
#   * M10 is the second copy of 0.82 -- the helper typing the base ring factor
#     itself instead of taking it from the call site.  Harmless today and the
#     exact shape that drifts the day somebody edits the branch.
#   * M11 is the pullcad trap (AGENTS.md): conjoining the sibling `cmrcrowd`,
#     which would freeze this gate FALSE the day that sibling is promoted while
#     check_armed_wiring.py still calls it WIRED.  It is the sibling this lever
#     COLLIDES with, which is precisely why somebody might reach for it.
#   * M12 is a control on the STAND ITSELF -- it breaks the corpus drive so a
#     census that cannot go red would be exposed.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_field_hurt_ring.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmrspeed.XXXXXX")
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

# TWO filters, not one file and not `test_cm_`.
#   * the new file alone would report a collision in a sibling as SURVIVED, so
#     the three other ConsiderR test files (`test_cm_r_`: crowd, solo,
#     retreat-crowd) are run with it;
#   * the whole `test_cm_` family is NOT used, for two measured reasons: it does
#     not finish inside 120s on this container (x13 runs is half an hour of
#     stand), and tests/test_cm_pos5_boots.lua is RED on origin/main
#     independently of this lever (a corpus census: "the two arms are no longer
#     at comparable hero level, 8.74 vs 7.56").  A stand whose baseline is red
#     aborts, so widening the filter here would buy nothing and cost the stand.
run_tests() {
    lua5.1 tests/run_tests.lua test_cm_field_hurt_ring.lua > "$WORK/run.log" 2>&1
    local a=$?
    lua5.1 tests/run_tests.lua test_cm_r_ >> "$WORK/run.log" 2>&1
    local b=$?
    if [ "$a" -ne 0 ]; then return "$a"; fi
    return "$b"
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous.
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
# M1: the candidate check is dropped.  The widening becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrspeed' ) )" \
            "	if not ( J.IsModeTurbo() )"
score "M1" "unarmed, speed"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrspeed' ) )" \
            "	if not ( J.IsSoakCandidate( 'cmrspeed' ) )"
score "M2" "outside turbo the lever must be inert"

# ---------------------------------------------------------------------------
# M3: THE CALL SITE IS REMOVED.  Helper, header, id registration and the whole
#     dimensional derivation survive; branch 1 goes back to the bare expression.
echo
echo "=== M3: the call site is removed from X.ConsiderR ==="
sub "$HERO" "X.cm_GetFieldHurtRing( nRadius * 0.82, enemy:GetCurrentMovementSpeed(), abilityR )" \
            "nRadius * 0.82 - enemy:GetCurrentMovementSpeed()"
score "M3" "is back at a call site"

# ---------------------------------------------------------------------------
# M4: THE WRONG TIME KEY.  crystal_maiden_freezing_field declares
#     AbilityCastPoint 0, so this turns the armed ring into the FULL base ring
#     on every frame -- a different, much larger lever wearing this id, with the
#     helper, gate, clamp and direction guarantee all still in place.
echo
echo "=== M4: the horizon is read from AbilityCastPoint (declared 0) ==="
sub "$HERO" "	local nHorizon = hAbility:GetSpecialValueFloat( 'explosion_interval' )" \
            "	local nHorizon = hAbility:GetSpecialValueFloat( 'AbilityCastPoint' )"
score "M4" "is a different lever wearing"

# ---------------------------------------------------------------------------
# M5: DEAD WIRING.  A horizon of exactly the shipped 1.0 makes the armed leg the
#     shipped expression at every speed -- inert in every wave.
echo
echo "=== M5: the horizon becomes the shipped 1.0 (dead wiring) ==="
sub "$HERO" "	return nBaseRing - nSpeed * nHorizon" \
            "	return nBaseRing - nSpeed * X.nRHurtHorizonShipped"
score "M5" "armed never widened anywhere on the grid"

# ---------------------------------------------------------------------------
# M6: THE SHIPPED HORIZON MOVES.  1.0 is not a tuning knob -- it is what the
#     shipped source's missing factor IS -- so moving it silently changes
#     gate-OFF behaviour, which is the one thing a soak candidate may not do.
echo
echo "=== M6: the shipped horizon is retuned to 0.5 (gate-OFF behaviour moves) ==="
sub "$HERO" "X.nRHurtHorizonShipped = 1.0" "X.nRHurtHorizonShipped = 0.5"
score "M6" "the helper must be"

# ---------------------------------------------------------------------------
# M7: THE CLAMP IS REMOVED.  Without the upper bound the armed leg can NARROW,
#     and the direction guarantee in the note is false while the code still
#     reads like a widening.
echo
echo "=== M7: the upper clamp on the horizon is removed ==="
sub "$HERO" "		or nHorizon > X.nRHurtHorizonShipped
" "		or false
"
score "M7" "a horizon ABOVE the shipped 1.0 must be refused"

# ---------------------------------------------------------------------------
# M8: the non-negative speed guard is removed.  The direction proof assumes
#     speed >= 0; without the guard a negative speed makes armed NARROWER.
echo
echo "=== M8: the negative-speed guard is removed ==="
sub "$HERO" "	if type( nSpeed ) ~= 'number' or nSpeed < 0 or hAbility == nil" \
            "	if type( nSpeed ) ~= 'number' or hAbility == nil"
score "M8" "with a negative speed the helper must answer the shipped expression"

# ---------------------------------------------------------------------------
# M9: THE ARGUMENT SWAP.  Two of the three arguments are scalars, so a swapped
#     pair is invisible to every assertion that does not pin the call literally.
echo
echo "=== M9: the base ring and the speed are passed in the wrong order ==="
sub "$HERO" "X.cm_GetFieldHurtRing( nRadius * 0.82, enemy:GetCurrentMovementSpeed(), abilityR )" \
            "X.cm_GetFieldHurtRing( enemy:GetCurrentMovementSpeed(), nRadius * 0.82, abilityR )"
score "M9" "expected exactly one call site passing"

# ---------------------------------------------------------------------------
# M10: the second copy of 0.82 -- the helper typing the base-ring factor itself.
#      Harmless today, and the exact shape that drifts from the call site.
echo
echo "=== M10: the helper types 0.82 itself (a second copy of the base ring) ==="
sub "$HERO" "	local nShipped = nBaseRing - nSpeed * X.nRHurtHorizonShipped" \
            "	local nShipped = nBaseRing * 0.82 / 0.82 - nSpeed * X.nRHurtHorizonShipped"
score "M10" "types 0.82 itself"

# ---------------------------------------------------------------------------
# M11: the pullcad trap -- conjoining the sibling this lever COLLIDES with.
#      Frozen FALSE the day `cmrcrowd` is promoted, and still WIRED to
#      check_armed_wiring.py.
echo
echo "=== M11: the gate is conjoined with the sibling cmrcrowd (pullcad trap) ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrspeed' ) )" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrspeed' ) and J.IsSoakCandidate( 'cmrcrowd' ) )"
score "M11" "must name exactly one soak id"

# ---------------------------------------------------------------------------
# M12: A CONTROL ON THE STAND ITSELF.  If the corpus drive cannot go red, every
#      "the lever moved N frames" reading above is worthless.  Break the frame
#      list and the section-6 census must say so.
echo
echo "=== M12: control -- the corpus drive is broken (the census must notice) ==="
sub "$TEST" "    'tests/fixtures/f_260820_043039_cm_cask_close.lua',
    'tests/fixtures/f_260820_102645_cm_es_reach.lua'," \
            "    'tests/fixtures/f_260820_102645_cm_es_reach.lua',"
score "M12" "the CM-subject frame list is no longer 10 frames"

# ---------------------------------------------------------------------------
echo
echo "=== score ==="
echo "$CAUGHT / $TOTAL mutants caught"
restore
echo "RESTORED OK"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
