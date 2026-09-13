#!/usr/bin/env bash
# Mutation stand for the `cmrflee` candidate -- the crowd conjunct on
# X.ConsiderR's retreat branch in bots/BotLib/hero_crystal_maiden.lua, which
# multiplied an HP FRACTION by an unbounded head count and so refused every
# state from three visible chasers upward (hero, 2026-09-13,
# OWNER_PRIORITIES P4.4 (i)).  Run by hand when X.cm_IsFieldRetreatCrowdOk,
# X.ConsiderR branch 3 or tests/test_cm_r_retreat_crowd.lua are edited, and
# before quoting any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axecullreach.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.
#   * ⚠️ an anchor is taken from CODE, never from prose.  The 2026-09-13 Lion
#     round scored a mutant SURVIVED because its needle also appeared in the
#     lever's own header comment and perl rewrote the PROSE.  Every anchor below
#     was checked for uniqueness by `sub` itself, which is what makes that
#     failure mode an abort rather than a score.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while moving
# nothing, or moving the wrong thing:
#   * M4 is the DEAD-WIRING twin in its subtlest form.  `math.min` -> `math.max`
#     leaves the helper, the id, the call site and the direction guarantee all
#     intact and makes the clamp a no-op at EVERY rung: at crowd 1 and 2 the
#     shipped early return fires first, and at crowd >= 3 max() hands back the
#     shipped bound.  Inert in every wave, and the verdict reads back "tested,
#     no effect".
#   * M6 is the ARGUMENT SWAP.  This helper takes THREE scalars of which two are
#     numbers, so a swapped pair is invisible to any assertion that does not pin
#     the call literally.
#   * M7/M8 move the cap off the ladder.  The cap is not a tuning knob -- it is
#     the shipped rule's own last satisfiable rung -- so a moved cap must be red
#     even though the code still reads like a clamp.
#   * M11 is the second copy of 0.38: the helper typing the step itself instead
#     of taking it from the call site.  Harmless today and the exact shape that
#     drifts the day somebody edits the branch.
#   * M10 is the pullcad trap (AGENTS.md): conjoining the sibling `cmrsolo`,
#     which would freeze this gate FALSE the day that sibling is promoted while
#     check_armed_wiring.py still calls it WIRED.
#   * M13 is a control on the STAND ITSELF -- it breaks the corpus census so a
#     census that cannot go red would be exposed.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_r_retreat_crowd.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmrflee.XXXXXX")
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

# The filter is `test_cm_r_`, not this one file: the two sibling ConsiderR test
# files (crowd, solo) read the same hero module and the same branch, and a stand
# scoped to the new file alone would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua test_cm_r_ > "$WORK/run.log" 2>&1
    return $?
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
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrflee' ) )" \
            "	if not ( J.IsModeTurbo() )"
score "M1" "arming cmrsolo opened"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrflee' ) )" \
            "	if not ( J.IsSoakCandidate( 'cmrflee' ) )"
score "M2" "turbo-only was lost"

# ---------------------------------------------------------------------------
# M3: THE CLAMP IS REMOVED.  Armed hands back the shipped bound -- helper, id,
#     call site and header all still there, and the lever moves nothing.
echo
echo "=== M3: the armed leg returns the shipped bound (dead wiring) ==="
sub "$HERO" "	return nHp > nStep * math.min( nCrowd, X.nRRetreatCrowdCap )" \
            "	return nHp > nStep * nCrowd"
score "M3" "the armed leg added nothing anywhere on the grid"

# ---------------------------------------------------------------------------
# M4: min -> max.  The subtlest dead wiring: the clamp is still a clamp, still
#     gated, still turbo-only, still one-directional, and inert at every rung.
echo
echo "=== M4: math.min becomes math.max (inert at every rung) ==="
sub "$HERO" "	return nHp > nStep * math.min( nCrowd, X.nRRetreatCrowdCap )" \
            "	return nHp > nStep * math.max( nCrowd, X.nRRetreatCrowdCap )"
score "M4" "the armed leg added nothing anywhere on the grid"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.  Helper, header, id registration and the whole
#     ladder derivation survive; branch 3 goes back to the saturating product.
echo
echo "=== M5: the call site is removed from X.ConsiderR ==="
sub "$HERO" "			and X.cm_IsFieldRetreatCrowdOk( nHP, 0.38, #nEnemysHeroesFurther )" \
            "			and nHP > 0.38 * #nEnemysHeroesFurther"
score "M5" "no longer routes its crowd conjunct"

# ---------------------------------------------------------------------------
# M6: THE ARGUMENT SWAP.  Two of the three arguments are numbers, so a swapped
#     pair is invisible to every assertion that does not pin the call literally.
echo
echo "=== M6: the step and the crowd are passed in the wrong order ==="
sub "$HERO" "X.cm_IsFieldRetreatCrowdOk( nHP, 0.38, #nEnemysHeroesFurther )" \
            "X.cm_IsFieldRetreatCrowdOk( nHP, #nEnemysHeroesFurther, 0.38 )"
score "M6" "no longer routes its crowd conjunct"

# ---------------------------------------------------------------------------
# M7: the cap is raised off the ladder.  Still reads like a clamp; now it admits
#     a rung the shipped rule never accepts at any health.
echo
echo "=== M7: the cap is raised to 3 (off the ladder) ==="
sub "$HERO" "X.nRRetreatCrowdCap = 2" "X.nRRetreatCrowdCap = 3"
score "M7" "the ladder says the last satisfiable rung is"

# ---------------------------------------------------------------------------
# M8: the cap is lowered to 1 -- i.e. clamped to the rung that is a NO-OP.  The
#     lever then widens all the way down to the outer guard, which is a
#     different (and much larger) lever wearing this one's id.
echo
echo "=== M8: the cap is lowered to 1 (the no-op rung) ==="
sub "$HERO" "X.nRRetreatCrowdCap = 2" "X.nRRetreatCrowdCap = 1"
score "M8" "the ladder says the last satisfiable rung is"

# ---------------------------------------------------------------------------
# M9: the OUTER guard moves off 0.38.  Rung 1 stops being a restatement of it,
#     so the first sentence of the header's ladder is no longer true.
echo
echo "=== M9: the outer retreat guard moves off 0.38 ==="
sub "$HERO" "	if J.IsRetreating( bot ) and nHP > 0.38" \
            "	if J.IsRetreating( bot ) and nHP > 0.30"
score "M9" "has moved off"

# ---------------------------------------------------------------------------
# M10: the pullcad trap (AGENTS.md).  A second id inside this gate's condition
#      freezes it FALSE the day that id is promoted, while check_armed_wiring.py
#      still calls the call site WIRED.
echo
echo "=== M10: a sibling id is conjoined into the gate (the pullcad trap) ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrflee' ) )" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmrflee' ) and J.IsSoakCandidate( 'cmrsolo' ) )"
score "M10" "must name exactly one candidate id"

# ---------------------------------------------------------------------------
# M11: the helper types the step itself.  Two copies of 0.38, agreeing today and
#      drifting the first time somebody edits the branch.
echo
echo "=== M11: the helper types 0.38 instead of taking nStep ==="
sub "$HERO" "	local bShipped = nHp > nStep * nCrowd" \
            "	local bShipped = nHp > 0.38 * nCrowd"
score "M11" "now types 0.38 itself"

# ---------------------------------------------------------------------------
# M12: branch 3's own 1300u ring moves.  Every rung in the header is about THAT
#      ring; a different radius is a different crowd and a different ladder.
echo
echo "=== M12: branch 3's 1300u enemy ring is widened ==="
sub "$HERO" "		local nEnemysHeroesFurther = J.GetNearbyHeroes(bot, 1300, true, BOT_MODE_NONE )" \
            "		local nEnemysHeroesFurther = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE )"
score "M12" "branch 3 lost"

# ---------------------------------------------------------------------------
# M13: CONTROL ON THE STAND ITSELF.  The census reads the 500u ring for both
#      counts, so the corpus table it prints is no longer about two rings.  A
#      census that cannot go red would show up here as SURVIVED.
echo
echo "=== M13: the census reads the wrong ring (control) ==="
sub "$TEST" "    local further = J.GetNearbyHeroes(bot, 1300, true, BOT_MODE_NONE)" \
            "    local further = J.GetNearbyHeroes(bot, 500, true, BOT_MODE_NONE)"
score "M13" "no longer carries the crowd premise"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
