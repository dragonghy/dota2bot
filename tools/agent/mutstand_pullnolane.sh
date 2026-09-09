#!/usr/bin/env bash
# Mutation stand for the 'pullnolane' guard (strategy, 2026-09-09, GH #648 --
# OWNER_PRIORITIES P1 + P4.4(i)).
#
# The claim under test: "J.ShouldPullNeutralCamp's lane guard tested for nil,
# which the engine never returns; LANE_NONE (= 0) is the no-lane answer, the
# shipped guard fires on 0 of 1021 corpus frames while LANE_NONE is present on
# 1021 of 1021, and arming 'pullnolane' turns exactly the 18 frames that fell
# through into the lane read into clean nils, never the other way."
#
# Run by hand when J.ShouldPullNeutralCamp, tests/_pullcamp_sweep.lua,
# tests/test_pullnolane_guard.lua, the LANE_* pins in tests/mock/bot_api.lua or
# the LANE_* line of docs/BOT_API_REFERENCE.md are edited, and before quoting
# any of these readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_fieldsip.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a
#     mutant can never score "caught" for having applied to nothing, nor
#     "survived" for having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507).
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M3 IS THE ORDER-BLIND ONE, and it is the reason the differential is a
#     measurement at all. Move the guard from ABOVE the GetLaneFrontLocation
#     call to BELOW it. The guard is still present, still names its id, still
#     compares to LANE_NONE -- every source-presence check passes -- and the
#     corpus columns collapse because the raise now happens first. A file that
#     had checked presence alone would call this tree unchanged.
#   * M6 IS THE HARNESS HALF, and without it this whole round is unmeasurable.
#     Put LANE_NONE back on the mock's auto-numbering sentinel (1024). Nothing
#     in bots/ changes; the guard simply stops being expressible in the fixture
#     world, and every corpus column silently reverts to the pre-repair
#     reading. This is the TEAM_RADIANT defect the same file already carries a
#     pin for -- the failure mode is "false for a reason unrelated to the
#     frame", and it is invisible unless asserted in BOTH directions.
#   * M10 IS THE TIDY-LOOKING ONE. Rewrite the sweep's `lane_none` column as
#     the literal `lane == 0` ("we already know LANE_NONE is 0"). Every count
#     in the manifest is byte-identical, `lane_zero == lane_none` becomes true
#     by construction, and the only assertion that the constant is still 0 in
#     this world is gone. No counter can see it; only the source pin can.
#   * M11 IS THE ZERO-VALUED COLUMN, taught by mutstand_fieldsip.sh's M8/M13.
#     `guard_opens` reads 0 on a clean tree, so renaming its bump would be an
#     EQUIVALENT mutant (the branch never executes, so no key appears or
#     disappears). What is checkable is the branch's polarity: make
#     `guard_opens` fire on `guard_closes`'s own condition and the forbidden
#     direction stops being forbidden.
#   * M12 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_pullnolane_guard.lua
SWEEP=tests/_pullcamp_sweep.lua
MOCK=tests/mock/bot_api.lua
DOC=docs/BOT_API_REFERENCE.md

FILES=("$JMZ" "$TEST" "$SWEEP" "$MOCK" "$DOC")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_pullnolane.XXXXXX")
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

run_tests() {
    lua5.1 tests/run_tests.lua pullnolane_guard > "$WORK/run.log" 2>&1
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

sub_or_die() {
    sub "$@" || { echo "ANCHOR FAILURE -- stand aborted, nothing below is meaningful"; exit 3; }
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -3 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
SURVIVED=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
        SURVIVED=$((SURVIVED + 1))
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
        SURVIVED=$((SURVIVED + 1))
    fi
    restore > /dev/null
}

score_control() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- CORRECT, this leg must not be caught"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) -- the stand is scoring the ACT of editing,"
        echo "        not the edit; every count above is suspect:"
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
        SURVIVED=$((SURVIVED + 1))
    fi
    restore > /dev/null
}

# Anchors are LITERAL and must be UNIQUE.
GUARD=$'\tif J.IsSoakCandidate( \'pullnolane\' ) and nLane == ( LANE_NONE or 0 ) then\n\t\treturn nil\n\tend\n'
FRONT=$'\tlocal vFront = GetLaneFrontLocation( GetTeam(), nLane, 0 )\n\tlocal vMid   = GetLocationAlongLane( nLane, 0.5 )\n'
MOCK_NONE=$'    G.LANE_NONE = 0\n'
MOCK_MID=$'    G.LANE_MID = 2\n'
DOCLINE='LANE_NONE = 0    LANE_TOP = 1'
SWEEP_ARM=$'                        return sId == \'pullcamp\' or sId == \'pullnolane\'\n'
SWEEP_NONE=$'                if lane == (LANE_NONE or 0) then bump(\'lane_none\') end\n'
SWEEP_OPENS=$'                    if ok and v == nil and not ok2 then bump(\'guard_opens\') end\n'

echo
echo "=== mutants ==="

# M1 -- the repair reverted outright.
sub_or_die "$JMZ" "$GUARD" ""
score "M1  guard deleted from J.ShouldPullNeutralCamp                " \
      "the 'pullnolane' gate is gone"

# M2 -- the id renamed.  A gate whose id appears in no armed string is inert,
# and inert is exactly what the corpus differential must refuse to call WIRED.
sub_or_die "$JMZ" "IsSoakCandidate( 'pullnolane' )" "IsSoakCandidate( 'pullnolane2' )"
score "M2  gate id renamed (no armed string can carry it)             " \
      "the guard closes no frame at all"

# M3 -- ORDER.  Present, correct, and below the call it is supposed to precede.
sub_or_die "$JMZ" "${GUARD}${FRONT}" "${FRONT}${GUARD}"
score "M3  guard moved BELOW the first lane read (order-blind mutant) " \
      "a lane read now happens BEFORE the LANE_NONE guard"

# M4 -- the wrong constant, and a plausible one: LANE_TOP is the neighbouring
# member of the same family.
sub_or_die "$JMZ" "nLane == ( LANE_NONE or 0 )" "nLane == ( LANE_TOP or 1 )"
score "M4  guard compares to LANE_TOP instead of LANE_NONE            " \
      "the guard closes no frame at all"

# M5 -- polarity.  "Guard the lanes we have" instead of "guard the lane we
# do not have"; reads almost the same and inverts the whole domain.
sub_or_die "$JMZ" "nLane == ( LANE_NONE or 0 )" "nLane ~= ( LANE_NONE or 0 )"
score "M5  guard polarity flipped                                     " \
      "the guard closes no frame at all"

# M6 -- HARNESS.  LANE_NONE back on the auto-numbering sentinel.
sub_or_die "$MOCK" "$MOCK_NONE" ""
score "M6  mock LANE_NONE re-sentinelled (nothing in bots/ changed)   " \
      "in the fixture world, not the engine 0"

# M7 -- the same defect one member over, to prove the pin is on the FAMILY.
sub_or_die "$MOCK" "$MOCK_MID" $'    G.LANE_MID = 1026\n'
score "M7  mock LANE_MID off the documented value                     " \
      "no longer matches the API reference"

# M8 -- the doc anchor.  The guard's licence is the documented value; if the
# reference stops saying 0, the guard is comparing to a number nobody claims.
sub_or_die "$DOC" "$DOCLINE" 'LANE_NONE = 9    LANE_TOP = 1'
score "M8  API reference renumbers LANE_NONE                          " \
      "the API reference now says LANE_NONE = 9"

# M9 -- the sweep stops arming the guard on its second drive.  The two drives
# become the same drive; the differential goes to zero while every other
# column is untouched.
sub_or_die "$SWEEP" "$SWEEP_ARM" $'                        return sId == \'pullcamp\'\n'
score "M9  sweep's second drive no longer arms the guard              " \
      "the guard closes no frame at all"

# M10 -- the tidy-looking one.  Counts are byte-identical; only the pin sees it.
sub_or_die "$SWEEP" "$SWEEP_NONE" $'                if lane == 0 then bump(\'lane_none\') end\n'
score "M10 sweep's lane_none column rewritten as a literal 0          " \
      "no longer reads LANE_NONE"

# M11 -- the zero-valued column, mutated by POLARITY rather than by name.
sub_or_die "$SWEEP" "$SWEEP_OPENS" $'                    if (not ok) and ok2 and v2 == nil then bump(\'guard_opens\') end\n'
score "M11 guard_opens made to fire on guard_closes's own condition   " \
      "arming pullnolane opened"

# M12 -- CONTROL.  A comment-only edit must not be caught.
sub_or_die "$JMZ" \
    "-- Gated all the same, so an armed 'pullcamp' wave does not silently change" \
    "-- Gated regardless, so an armed 'pullcamp' wave does not silently change"
score_control "M12 comment-only edit (control)                                "

echo
echo "=== stand summary ==="
echo "legs $TOTAL  caught $CAUGHT  survived $SURVIVED"
if [ "$SURVIVED" -ne 0 ]; then
    echo "STAND RED -- $SURVIVED leg(s) the tests cannot see"
    exit 3
fi
echo "STAND GREEN -- every mutant caught, control survived"
