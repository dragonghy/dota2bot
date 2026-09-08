#!/usr/bin/env bash
# Mutation stand for the `cmlaneband` candidate -- the reach term on
# X.ConsiderW's 对线期消耗 lane-harass firing point, the second of the two firing
# points in that function that read nEnemysHeroesInBonus (nCastRange + 200) with
# no distance test (hero, 2026-09-08, OWNER_PRIORITIES P4.4 (i)).  Run by hand
# when X.cm_IsLaneHarassTargetInReach, X.ConsiderW or
# tests/test_cm_w_lane_band.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkqlane.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.  In a double-quoted bash string
#     that is command substitution, and the 2026-09-07 stand scored a mutant
#     "red with the wrong message" for exactly that reason.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed path hands back the shipped answer -- inert in every
#     wave, and the verdict reads back "tested, no effect".
#   * M3 is the INVERSION.  The shipped answer here is an unconditional `true`,
#     so a strict-superset mutant is not expressible -- this lever CANNOT be made
#     to widen by editing the armed branch alone, which is exactly why the
#     direction sentence in the source is a property of the SHAPE and not a
#     promise.  What CAN go wrong is the gate pointing the other way.
#   * M6, M7 and M10 are the three ways to keep a reach term that no longer means
#     what its note says: the wrong slack, no slack, and a slack that stops
#     composing with the `+ 30`, the Aether Lens bonus and the lone-enemy
#     attack-range extension the caller folds into nCastRange.
#   * M8 is a control on the STAND ITSELF: a census that cannot go red is not a
#     limit, it is a sentence.
#   * M9 is the pullcad trap (AGENTS.md) in its native habitat -- conjoining a
#     sibling id that this very function already calls, and that would freeze
#     this gate FALSE the day that sibling is promoted.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_crystal_maiden.lua
TEST=tests/test_cm_w_lane_band.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cmlb.XXXXXX")
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

# The filter is `cm`, not this one file: the sibling Crystal Maiden assertions
# read the same hero module, and a stand scoped to the new file alone would
# report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua cm > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of two identical sites scores "survived" for the
# wrong reason.  This file needs the ambiguity guard: X.ConsiderW carries eight
# near-identical firing points.
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

GATELINE="	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmlaneband' ) ) then return true end"
REACHLINE="	return J.IsInRange( hTarget, hBot, nCastRange + 50 )"
CALLSITE="				and X.cm_IsLaneHarassTargetInReach( bot, nWeakestEnemyHeroInBonus, nCastRange )
"

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
sub "$HERO" "$GATELINE" "	if not ( J.IsModeTurbo() ) then return true end"
score "M1" "gate off must be the shipped no-filter answer (true)"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1;
#     only the explicit non-turbo case in section 5 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "$GATELINE" "	if not ( J.IsSoakCandidate( 'cmlaneband' ) ) then return true end"
score "M2" "the lever fired outside turbo"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed drops the in-reach casts and keeps
#     the band ones -- the exact opposite of every sentence written about it,
#     while staying gated, wired and turbo-only.
echo
echo "=== M3: the reach term is inverted ==="
sub "$HERO" "$REACHLINE" "	return not J.IsInRange( hTarget, hBot, nCastRange + 50 )"
score "M3" "armed is no longer exactly"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped answer anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "$REACHLINE" "	return true"
score "M4" "armed still admits"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.  The helper, its note, its id registration and
#     its unit tests all survive; the branch goes back to committing Frostbite on
#     anything in the nCastRange + 200 ring.
echo
echo "=== M5: the lane-harass branch stops routing through the helper ==="
sub "$HERO" "$CALLSITE" ""
score "M5" "no longer calls X.cm_IsLaneHarassTargetInReach"

# ---------------------------------------------------------------------------
# M6: the reach term loosens to the ring it was written to close.  The lever then
#     accepts exactly the walk orders it exists to refuse, while still looking
#     armed, wired and gated.
echo
echo "=== M6: the reach term loosened to the +200 search ring ==="
sub "$HERO" "$REACHLINE" "	return J.IsInRange( hTarget, hBot, nCastRange + 200 )"
score "M6" "armed still admits"

# ---------------------------------------------------------------------------
# M7: the slack is dropped entirely.  A defensible-looking edit -- and a
#     different lever: it also refuses the (nCastRange, nCastRange + 50] casts
#     that the 进攻 firing point accepts, so the id would no longer be "this
#     function's own commit gate applied to the branch that lacks one".
echo
echo "=== M7: the +50 slack dropped, so the gate stops matching the 进攻 branch ==="
sub "$HERO" "$REACHLINE" "	return J.IsInRange( hTarget, hBot, nCastRange )"
score "M7" "armed is no longer exactly"

# ---------------------------------------------------------------------------
# M8: A CONTROL ON THE STAND ITSELF.  The section 1 census stops distinguishing
#     the band from the gate.  If this survives, the domain numbers in section
#     0.3 are prose, not a reading.
echo
echo "=== M8: the census stops distinguishing the band from the gate ==="
sub "$TEST" "                    if d <= NCR + GATE then" \
            "                    if d <= NCR + BONUS then"
score "M8" "the band domain moved"

# ---------------------------------------------------------------------------
# M9: THE PULLCAD TRAP.  Conjoin a sibling id that X.ConsiderW itself already
#     calls (`cmfarcreep`, the far-creep floor lever).  Every wiring check still
#     reads the call site as WIRED, and the gate is frozen FALSE in every wave
#     that does not arm BOTH -- and permanently, the day cmfarcreep promotes,
#     because a promoted id appears in no armed string.
echo
echo "=== M9: the gate is conjoined with a sibling id in the same function ==="
sub "$HERO" "$GATELINE" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'cmlaneband' ) and J.IsSoakCandidate( 'cmfarcreep' ) ) then return true end"
score "M9" "armed still admits"

# ---------------------------------------------------------------------------
# M10: THE PARAMETER IS FROZEN INTO TODAY'S CONSTANT.  630 + 50 is the right
#     answer on every frame in the corpus, so nothing about the reading moves --
#     but the gate stops composing with the caller's `+ 30`, with aetherRange,
#     and with the lone-enemy attack-range extension above the branch.  This is
#     the arithmetic half of the pullcad lesson.
echo
echo "=== M10: nCastRange replaced by today's value ==="
sub "$HERO" "$REACHLINE" "	return J.IsInRange( hTarget, hBot, 680 )"
score "M10" "armed is no longer exactly"

# ---------------------------------------------------------------------------
echo
echo "score: $CAUGHT/$TOTAL CAUGHT"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
exit 0
