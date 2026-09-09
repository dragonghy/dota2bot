#!/usr/bin/env bash
# Mutation stand for the 'dragnolane' guard and the shared J.IsLaneAssigned
# predicate (strategy, 2026-09-09, GH #652 -- the follow-on to GH #648).
#
# The claim under test: "three sites still carried the GH #648 defect; priced on
# one 1021-frame walk, site A is unreachable (0 frames), site B is a measured
# no-op (frontamt_differs 0) inside a PROMOTED helper, and site C answers a
# non-nil drag destination off an unresolvable lane id on every frame -- so
# arming 'dragnolane' turns all 1021 into clean nils and never the other way."
#
# Run by hand when J.GetLanePullDragTarget, J.IsLaneAssigned,
# tests/_pullcamp_sweep.lua, tests/test_lanenone_site_pricing.lua or the LANE_*
# pins in tests/mock/bot_api.lua are edited, and before quoting any of these
# readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_pullnolane.sh):
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
#   * M3 IS THE ORDER-BLIND ONE, and here it is STRICTLY HARDER than the same
#     leg was for 'pullnolane'. Move the guard from above the 21-sample lane
#     walk to just before `return vDest`. The guard is still present, still
#     names its id, still calls the predicate -- AND THE RETURNED VALUE IS
#     UNCHANGED, so every corpus column, the differential included, is
#     byte-identical. Nothing but the source-order pin can see it. What the
#     mutant destroys is the reason the guard exists: the samples it was
#     written to keep from running now run.
#   * M6 IS THE CONSTANT-RETURNING PREDICATE. `J.IsLaneAssigned` rewritten as
#     `return false` leaves the whole differential intact (1021 closes either
#     way) because the corpus reads LANE_NONE on every frame. Only the
#     both-directions assertion on a real frame -- LANE_MID must read TRUE --
#     separates "reads the lane" from "answers no".
#   * M9 IS THE HARNESS HALF, and without it this round is unmeasurable. Put
#     LANE_NONE back on the mock's auto-numbering sentinel (1024). Nothing in
#     bots/ changes; the predicate simply stops being expressible in the
#     fixture world and every column reverts to the pre-repair reading.
#   * M11 IS THE COUNT-BLIND ONE. Rewrite the sweep's `alongline_nonnil` column
#     as an unconditional bump ("we already know it always answers"). The
#     manifest is byte-identical -- 1021 either way -- so no assertion over the
#     counts can see it; only the source pin can.
#   * M12 IS THE RATCHET. Repair site B's guard silently. That site was priced
#     as a measured no-op, and this stand's whole point is that the pricing
#     stays attached to the code it describes.
#   * M13 IS THE ZERO-VALUED COLUMN, taught by mutstand_fieldsip.sh's M8/M13
#     and reused by mutstand_pullnolane.sh's M11. `drag_opens` reads 0 on a
#     clean tree, so renaming its bump is an EQUIVALENT mutant (the branch
#     never executes). Vary its POLARITY instead.
#   * M14 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_lanenone_site_pricing.lua
SWEEP=tests/_pullcamp_sweep.lua
MOCK=tests/mock/bot_api.lua

FILES=("$JMZ" "$TEST" "$SWEEP" "$MOCK")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_dragnolane.XXXXXX")
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
    lua5.1 tests/run_tests.lua lanenone_site_pricing > "$WORK/run.log" 2>&1
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
GUARD=$'\tif J.IsSoakCandidate( \'dragnolane\' ) and not J.IsLaneAssigned( bot ) then\n\t\treturn nil\n\tend\n'
TAIL=$'\tbot.pullDragCampX, bot.pullDragCampY = vCamp.x, vCamp.y\n'
PRED_NIL=$'\tif nLane == nil then return false end\n'
PRED_HEAD=$'function J.IsLaneAssigned( bot )\n\tif bot == nil then return false end\n'
PRED_RET=$'\treturn nLane ~= ( LANE_NONE or 0 )\n'
MOCK_NONE=$'    G.LANE_NONE = 0\n'
SITEB=$'\tlocal nLane = bot:GetAssignedLane()\n\tif nLane ~= nil then\n\t\tlocal nOurFront   = GetLaneFrontAmount( GetTeam(), nLane, false )\n'
SWEEP_ARM=$'                        return sId == \'pulldrag\' or sId == \'dragnolane\'\n'
SWEEP_ALONG=$'                    if GetLocationAlongLane(lane, 0.5) ~= nil then\n                        bump(\'alongline_nonnil\')\n                    end\n'
SWEEP_OPENS=$'                    if okC and vC == nil and okD and vD ~= nil then\n                        bump(\'drag_opens\')\n                    end\n'

# The message the reader ACTUALLY gets: cs.universal fires first, before
# the count assertion underneath it.
ARMED_NONNIL='frames where the armed function returns nil:'

echo
echo "=== mutants ==="

# M1 -- the repair reverted outright.
sub_or_die "$JMZ" "$GUARD" ""
score "M1  guard deleted from J.GetLanePullDragTarget                " \
      "no longer gates the repair on 'dragnolane'"

# M2 -- the id renamed.  A gate whose id appears in no armed string is inert,
# and inert is what the corpus differential must refuse to call WIRED.
sub_or_die "$JMZ" "IsSoakCandidate( 'dragnolane' )" "IsSoakCandidate( 'dragnolane2' )"
score "M2  gate id renamed (no armed string can carry it)            " \
      "$ARMED_NONNIL"

# M3 -- ORDER, and the returned VALUE IS UNCHANGED.  Every column, the
# differential included, is byte-identical; only the source-order pin sees it.
sub_or_die "$JMZ" "${GUARD}" ""
sub_or_die "$JMZ" "${TAIL}" "${GUARD}${TAIL}"
score "M3  guard moved BELOW the 21-sample lane walk (value-neutral) " \
      "sits BELOW the lane sampler"

# M4 -- the wrong constant, and a plausible one: the neighbouring member of the
# same documented family.
sub_or_die "$JMZ" "return nLane ~= ( LANE_NONE or 0 )" "return nLane ~= ( LANE_TOP or 1 )"
score "M4  predicate compares to LANE_TOP instead of LANE_NONE       " \
      "J.IsLaneAssigned no longer names LANE_NONE"

# M5 -- polarity at the CALL SITE.  "Only drag when we have a lane" reads
# almost the same and inverts the whole domain.
sub_or_die "$JMZ" "and not J.IsLaneAssigned( bot ) then" "and J.IsLaneAssigned( bot ) then"
score "M5  call-site polarity flipped                                " \
      "the repair no longer calls the shared predicate"

# M6 -- the predicate stops reading the lane and answers a constant.  The
# differential survives this untouched (the corpus is LANE_NONE everywhere);
# only the LANE_MID direction separates "reads" from "answers no".
sub_or_die "$JMZ" "$PRED_RET" $'\treturn false\n'
score "M6  predicate rewritten to a constant, not a lane read       " \
      "it is not reading the lane, it is returning a constant"

# M7 -- the predicate stops rejecting nil.  The guards it replaces all did.
sub_or_die "$JMZ" "$PRED_NIL" ""
score "M7  predicate no longer rejects a nil lane                    " \
      "nil lane no longer reads false"

# M8 -- a gate migrates INSIDE the shared predicate.  The next site to adopt it
# would silently inherit an unrelated candidate id.
sub_or_die "$JMZ" "$PRED_HEAD" \
    "${PRED_HEAD}"$'\tif not J.IsSoakCandidate( \'dragnolane\' ) then return true end\n'
score "M8  soak gate moved inside the shared predicate               " \
      'a soak gate moved INSIDE J.IsLaneAssigned'

# M9 -- HARNESS.  LANE_NONE back on the auto-numbering sentinel; bots/ untouched.
sub_or_die "$MOCK" "$MOCK_NONE" ""
score "M9  mock LANE_NONE re-sentinelled (nothing in bots/ changed)  " \
      "$ARMED_NONNIL"

# M10 -- the sweep's second drive stops arming the guard.  The two drives become
# the same drive; the differential goes to zero, every other column untouched.
sub_or_die "$SWEEP" "$SWEEP_ARM" $'                        return sId == \'pulldrag\'\n'
score "M10 sweep's second drive no longer arms the guard             " \
      "$ARMED_NONNIL"

# M11 -- COUNT-BLIND.  The column stops asking; the manifest is unchanged.
sub_or_die "$SWEEP" "$SWEEP_ALONG" $'                    bump(\'alongline_nonnil\')\n'
score "M11 alongline_nonnil column stops consulting the lane sampler " \
      "no longer asks the lane sampler"

# M12 -- the RATCHET on a site this round deliberately did NOT touch.
sub_or_die "$JMZ" "$SITEB" \
    $'\tlocal nLane = bot:GetAssignedLane()\n\tif nLane ~= ( LANE_NONE or 0 ) then\n\t\tlocal nOurFront   = GetLaneFrontAmount( GetTeam(), nLane, false )\n'
score "M12 site B repaired silently (priced as a no-op, and PROMOTED)" \
      'no longer guards on `nLane ~= nil`'

# M13 -- the zero-valued column, mutated by POLARITY rather than by name.
sub_or_die "$SWEEP" "$SWEEP_OPENS" \
    $'                    if okC and vC ~= nil and okD and vD == nil then\n                        bump(\'drag_opens\')\n                    end\n'
score "M13 drag_opens made to fire on drag_closes's own condition    " \
      "produced a drag destination where the shipped code had"

# M14 -- CONTROL.  A comment-only edit must not be caught.
sub_or_die "$JMZ" \
    "-- Gated all the same: 'pulldrag' has banked readings (GH #117 connect rate)," \
    "-- Gated regardless: 'pulldrag' has banked readings (GH #117 connect rate),"
score_control "M14 comment-only edit (control)                               "

echo
echo "=== stand summary ==="
echo "legs $TOTAL  caught $CAUGHT  survived $SURVIVED"
if [ "$SURVIVED" -ne 0 ]; then
    echo "STAND RED -- $SURVIVED leg(s) the tests cannot see"
    exit 3
fi
echo "STAND GREEN -- every mutant caught, control survived"
