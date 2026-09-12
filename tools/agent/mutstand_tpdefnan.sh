#!/usr/bin/env bash
# Mutation stand for the `tpdefnan` repair (strategy desk 2026-09-12, GH #539).
# Not part of any suite -- run by hand when J.GetTowerDefenseTpLocation
# (bots/FunLib/jmz_func.lua), its one call site in
# bots/ability_item_usage_generic.lua, or
# tests/test_tpdefnan_tower_tp_landing.lua is edited.
#
# WHAT IS ON THE BENCH. A real behaviour change, but a DARK one: the repaired
# call site sits inside `if hTowerFight ~= nil`, and J.ShouldTpSupportTowerFight
# returns nil unless turbo AND 'midtp'/'suptp' is armed. So the mutants split in
# three, and the split is the point:
#   * M1/M6 -- the GATE/WIRING mutants. Can the shipped tree reach this, and is
#     the repaired call still the one that is wired?
#   * M2/M3/M5 -- the BEHAVIOUR mutants. Does the corpus reading actually
#     constrain where the TP lands, or would any vector satisfy it?
#   * M4 -- ⭐ THE ONE THE CORPUS CANNOT BUY. No tower in the frame corpus
#     stands on a fountain, so `nDist <= 0` is unreachable here and sections 2-4
#     stay green with the branch deleted. It is bought by a SOURCE PIN
#     (section 7) and by nothing else, and the stand records that difference
#     rather than letting a text assertion pass for a measurement.
#   * M7/M8/M9 -- the ORACLE mutants. A census whose own finiteness test or
#     whose mechanism predicate has degenerated still prints plausible numbers.
#     M7/M8 aim at `finite`, M9 at `in_tower_slots`; each must be caught by a
#     DIFFERENT assertion, which is why all three are here.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# Usage: bash tools/agent/mutstand_tpdefnan.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/jmz_func.lua
CALL=bots/ability_item_usage_generic.lua
TEST=tests/test_tpdefnan_tower_tp_landing.lua
FILES=("$SRC" "$CALL" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tpdefnan.XXXXXX")
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
    lua5.1 tests/run_tests.lua tpdefnan > "$WORK/run.log" 2>&1
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
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ANCHOR PROBLEM -- stand aborted rather than scoring a no-op"
        exit 2
    fi
}

WIRE=$'\t\tlocal vTpLoc = J.GetTowerDefenseTpLocation( hTowerFight )'
TOWARD=$'\treturn J.GetLocationTowardDistanceLocation( hTower, vFountain, 575 )'
ZERO=$'\tif nDist <= 0 then return vTower end'
CANDGATE=$'\tif not ( J.IsSoakCandidate( \'midtp\' ) or bSup ) then return nil end'
FINITE=$'    if v == nil or v.x == nil then return false end'
SLOTS=$'    local vT = tower:GetLocation()\n    for i = 0, 10 do'

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
        grep -m1 'FAIL' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

echo
echo "=== mutants ==="

# M1: the wiring reverts to the NaN-producing shared helper. This is the whole
# change in one line, and the only regression a future edit is likely to make.
sub "$CALL" "$WIRE" $'\t\tlocal vTpLoc = J.GetNearbyLocationToTp( hTowerFight:GetLocation() )'
score "M1 wiring reverts to the NaN call  " "expected exactly one call to J.GetTowerDefenseTpLocation"

# M2: the landing point goes to the ENEMY fountain -- still finite, still 575u
# away, and it puts the defender in front of the tower he came to defend. Only
# the side assertion can see it; a finiteness-only file would call this fixed.
sub "$SRC" "$TOWARD" $'\treturn J.GetLocationTowardDistanceLocation( hTower, J.GetEnemyFountain(), 575 )'
score "M2 lands in FRONT of the tower     " "no closer to our own fountain"

# M3: the shipped 575 is retuned on the way past. A repair is allowed to be a
# repair; it is not allowed to be a silent retune.
sub "$SRC" "$TOWARD" $'\treturn J.GetLocationTowardDistanceLocation( hTower, vFountain, 300 )'
score "M3 the 575 constant drifts         " "not 575u from their"

# M4: ⭐ the zero-distance branch is deleted. UNREACHABLE on this corpus -- no
# tower stands on a fountain -- so every count stays identical and only the
# section 7 source pin can say anything. Expected to be caught by TEXT, and the
# stand states that this one is not a measurement.
sub "$SRC" "$ZERO" $'\tif nDist < 0 then return vTower end'
score "M4 zero-distance branch weakened   " "zero-distance branch is gone"

# M5: the helper degenerates to "TP onto the building itself" -- finite, on our
# side (it IS the tower), and wrong. Caught by the offset equality alone.
sub "$SRC" "$TOWARD" $'\treturn vTower'
score "M5 lands on the building itself    " "not 575u from their"

# M6: the candidate early return moves below the site it guards -- the only way
# anything at this site could reach a shipped game.
sub "$SRC" "$CANDGATE" $'\tlocal bGateLater = not ( J.IsSoakCandidate( \'midtp\' ) or bSup )'
score "M6 candidate gate no longer early  " "midtp/suptp early returns"

# M7: ⭐ the file's own finiteness oracle degenerates to "everything is finite".
# Sections 2/3 would then report a corpus with no defect and a perfect repair.
sub "$TEST" "$FINITE" $'    if true then return true end\n    if v == nil or v.x == nil then return false end'
score "M7 finite() constant true          " "came back FINITE"

# M8: the same oracle degenerates the other way. Section 1's second pole exists
# for exactly this and for nothing else.
sub "$TEST" "$FINITE" $'    if true then return false end\n    if v == nil or v.x == nil then return false end'
score "M8 finite() constant false         " "finiteness test itself is broken"

# M9: ⭐ the MECHANISM predicate degenerates to "every tower is a GetTower slot".
# Every NaN stays explained, so NAN_UNEXPLAINED cannot see it; the far-and-
# slotted towers that answer finite are what catches it, i.e. the OTHER
# direction of the equivalence. Both directions are in the file because a
# single-direction check scores this as clean.
sub "$TEST" "$SLOTS" $'    local vT = tower:GetLocation()\n    if true then return true end\n    for i = 0, 10 do'
score "M9 mechanism predicate always true " "over-predicts"

echo
echo "=== stand ==="
echo "$CAUGHT/$TOTAL caught"
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
else
    echo "STAND RED -- a mutant the assertions cannot see is a claim this file"
    echo "            is not entitled to make. Fix the file, not this script."
    exit 1
fi
