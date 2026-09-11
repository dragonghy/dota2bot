#!/usr/bin/env bash
# Mutation stand for the `pullreach` lever (strategy desk 2026-09-11, GH #740).
# Not part of any suite -- run by hand when J.IsCampWithinPullReach, the camp
# loop inside J.ShouldPullNeutralCamp, PULL_CAMP_LANE_REACH, or
# tests/test_pullreach_camp_lane_reach.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ ANCHOR HAZARD SPECIFIC TO THIS LEVER. `J.IsCampWithinPullReach` is a
# near-copy of the shipped `J.IsCampBesideLane` twenty lines above it -- same
# signature, same loop, same guard, DIFFERENT constant. Every anchor below is
# therefore disambiguated by the constant name (`PULL_CAMP_LANE_REACH`) or by
# the `tReachPath` variable. A bare loop/guard anchor aborts as AMBIGUOUS --
# the right failure, but a stand that aborts scores nothing. This is the same
# hazard the `lvlany` round hit when its near-copy helper landed.
#
# ⛔ WHAT IS DELIBERATELY NOT ON THIS STAND, and why it would be a lie to put
# it here: the turbo-only check and the `pullcamp` candidate check at the top
# of J.ShouldPullNeutralCamp belong to `pullcamp`, not to this id. Mutating
# them would score this stand green on somebody else's guard.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while leaving
# the defect, or while quietly meaning something else:
#   * M1/M2 are the two directions of "the gate stops meaning armed": frozen
#     open (the lever fires in a wave that did not ask for it, so nothing is
#     attributable) and frozen shut (a no-op that still reads as landed).
#   * M3 is the pullcad trap (AGENTS.md): conjoin an already-PROMOTED id and
#     the gate is frozen FALSE forever, because a promoted id is in no armed
#     string. `creeppull` is a real PROMOTED id and a real pull-family sibling,
#     so this is the plausible version of the mistake, not a strawman.
#   * ⭐⭐ M4 and M12 ARE THIS LEVER'S OWN FAILURE MODE, and the round walked
#     into it. They are kept as TWO mutants because hand-reading M4's red
#     (evidence-discipline rule 4: red is not the same as red for the right
#     reason) showed the first description of it was WRONG.
#       - M4 merges the two samplings under `pulllane or pullreach` while still
#         assigning each path under its own gate. That is behaviourally
#         IDENTICAL -- no test of the selector's answers can see it, and the
#         first draft of this comment claimed it "applies both constants",
#         which the stand's own log disproves. Its real defect is discipline:
#         it rewrites a RETIRED id's lever body (a retirement is not a reject)
#         and puts two soak ids on one line (the pullcad shape). So it is
#         caught by the source pin ALONE, and that is the correct catcher.
#       - M12 is the version that really does couple them: hand `pullreach`'s
#         path to the `pulllane` filter as well. Nothing in the source shape
#         looks wrong; only the behavioural witness at 1,450u can see it.
#     The pair is the point. One mutant would have let a source pin stand in
#     for a behavioural claim, or the reverse.
#   * M5/M6 are the constant moving to each of the two forbidden places: back
#     onto 1200 (which cuts into the connect class) and out to 3000 (which
#     re-admits the impossible tier the ruling filed the issue about).
#   * M7 is the comparison operator, M8 the segment loop truncated to one
#     segment, M9 the nil-path guard inverted -- that last one is the byte-for-
#     byte-when-disarmed property, i.e. the thing that makes this a gated fix.
#   * ⭐⭐ M10 and M11 are the FORBIDDEN DIRECTION: leave the shipped Lua alone
#     and break the TEST's own measuring instrument. M10 restores the index bug
#     this round actually hit (reading the dire tower rows front-to-back, so
#     dire t3 is compared against dire t1); M11 turns the corpus' MINIMUM-over-
#     three-lanes convention into a maximum, which is what makes "> x is
#     refused" a one-directional bound. Both leave bots/ untouched and both
#     must go red, or the readings in state.json are measured with the wrong
#     ruler and nobody is told. The `bagtango` round walked into exactly this
#     (its M10) by scoring "red = caught" without reading WHY it was red.

set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/jmz_func.lua
TEST=tests/test_pullreach_camp_lane_reach.lua

FILES=("$SRC" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_pullreach.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_pullreach_camp_lane_reach > "$WORK/run.log" 2>&1
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

# --- anchors, each disambiguated from the near-identical 'pulllane' sibling ---
GATE=$'\tif J.IsSoakCandidate( \'pullreach\' ) then\n\t\ttReachPath = {}'
LANEBLOCK=$'\tlocal tLanePath = nil\n\tif J.IsSoakCandidate( \'pulllane\' ) then\n\t\ttLanePath = {}\n\t\tfor k = 0, 20 do\n\t\t\tlocal v = GetLocationAlongLane( nLane, k / 20 )\n\t\t\tif v ~= nil then tLanePath[#tLanePath + 1] = v end\n\t\tend\n\tend\n\n\tlocal tReachPath = nil\n\tif J.IsSoakCandidate( \'pullreach\' ) then\n\t\ttReachPath = {}\n\t\tfor k = 0, 20 do\n\t\t\tlocal v = GetLocationAlongLane( nLane, k / 20 )\n\t\t\tif v ~= nil then tReachPath[#tReachPath + 1] = v end\n\t\tend\n\tend'
MERGED=$'\tlocal tLanePath = nil\n\tlocal tReachPath = nil\n\tif J.IsSoakCandidate( \'pulllane\' ) or J.IsSoakCandidate( \'pullreach\' ) then\n\t\tlocal tPath = {}\n\t\tfor k = 0, 20 do\n\t\t\tlocal v = GetLocationAlongLane( nLane, k / 20 )\n\t\t\tif v ~= nil then tPath[#tPath + 1] = v end\n\t\tend\n\t\tif J.IsSoakCandidate( \'pulllane\' ) then tLanePath = tPath end\n\t\tif J.IsSoakCandidate( \'pullreach\' ) then tReachPath = tPath end\n\tend'
CONST=$'local PULL_CAMP_LANE_REACH = 1800'
CMP=$'\t\tif DistanceToSegment( vCamp, tLanePath[i], tLanePath[i + 1] )\n\t\t\t< PULL_CAMP_LANE_REACH'
LOOP=$'\tfor i = 1, #tLanePath - 1 do\n\t\tif DistanceToSegment( vCamp, tLanePath[i], tLanePath[i + 1] )\n\t\t\t< PULL_CAMP_LANE_REACH'
NILGUARD=$'function J.IsCampWithinPullReach( vCamp, tLanePath )\n\tif vCamp == nil or tLanePath == nil or #tLanePath < 2 then return true end'
DIREIDX=$'                local slot = LANE_SLOTS[lane][side == \'dire\' and (#pts + 1 - i) or i]'
MINGAP=$'        if g < best then best, which = g, lane end'
CALL=$'\t\t\tand J.IsCampBesideLane( camp.location, tLanePath )\n\t\t\tand J.IsCampWithinPullReach( camp.location, tReachPath )'

PASS=0
FAIL=0

# $1 = label, $2 = "green"|"red" expected AFTER the mutation
expect() {
    label="$1"; want="$2"
    run_tests
    rc=$?
    if [ "$want" = red ]; then
        if [ "$rc" -ne 0 ]; then
            echo "  CAUGHT  $label"; PASS=$((PASS+1))
        else
            echo "  SURVIVED $label  <-- the suite cannot see this mutation"; FAIL=$((FAIL+1))
        fi
    else
        if [ "$rc" -eq 0 ]; then
            echo "  ok      $label"; PASS=$((PASS+1))
        else
            echo "  BROKE   $label  <-- expected green, got red"; FAIL=$((FAIL+1))
            sed -n '1,25p' "$WORK/run.log"
        fi
    fi
    restore
}

echo "=== baseline (unmutated tree must be GREEN) ==="
expect "baseline" green

echo "=== M1  gate frozen OPEN (the filter fires in a wave that did not arm it) ==="
sub "$SRC" "$GATE" $'\tif true then\n\t\ttReachPath = {}'
expect "M1 gate frozen open" red

echo "=== M2  gate frozen SHUT (a no-op that still reads as landed) ==="
sub "$SRC" "$GATE" $'\tif false then\n\t\ttReachPath = {}'
expect "M2 gate frozen shut" red

echo "=== M3  pullcad trap: conjoin the PROMOTED sibling 'creeppull' ==="
sub "$SRC" "$GATE" \
    $'\tif J.IsSoakCandidate( \'pullreach\' ) and J.IsSoakCandidate( \'creeppull\' ) then\n\t\ttReachPath = {}'
expect "M3 conjoined with promoted 'creeppull'" red

echo "=== M4  THIS LEVER'S TRAP: one shared path for both filters ==="
sub "$SRC" "$LANEBLOCK" "$MERGED"
expect "M4 sampling blocks merged -- both constants apply at once" red

echo "=== M5  constant back onto 1200 (cuts into the connect class) ==="
sub "$SRC" "$CONST" $'local PULL_CAMP_LANE_REACH = 1200'
expect "M5 constant retuned to pulllane's 1200" red

echo "=== M6  constant widened to 3000 (re-admits the impossible tier) ==="
sub "$SRC" "$CONST" $'local PULL_CAMP_LANE_REACH = 3000'
expect "M6 constant widened past the impossible tier" red

echo "=== M7  comparison loosened from < to <= ==="
sub "$SRC" "$CMP" $'\t\tif DistanceToSegment( vCamp, tLanePath[i], tLanePath[i + 1] )\n\t\t\t<= PULL_CAMP_LANE_REACH'
expect "M7 < became <=" red

echo "=== M8  only the FIRST segment is measured (the polyline stops being one) ==="
sub "$SRC" "$LOOP" $'\tfor i = 1, 1 do\n\t\tif DistanceToSegment( vCamp, tLanePath[i], tLanePath[i + 1] )\n\t\t\t< PULL_CAMP_LANE_REACH'
expect "M8 loop truncated to one segment" red

echo "=== M9  nil/short path now REJECTS (disarming would change shipped play) ==="
sub "$SRC" "$NILGUARD" \
    $'function J.IsCampWithinPullReach( vCamp, tLanePath )\n\tif vCamp == nil or tLanePath == nil or #tLanePath < 2 then return false end'
expect "M9 unreadable lane mutes the mechanic" red

echo "=== M10 INSTRUMENT: the dire tower rows read front-to-back again ==="
sub "$TEST" "$DIREIDX" $'                local slot = LANE_SLOTS[lane][i]'
expect "M10 test reads dire t3 against dire t1" red

echo "=== M11 INSTRUMENT: min-over-three-lanes becomes max ==="
sub "$TEST" "$MINGAP" $'        if g > best or best == math.huge then best, which = g, lane end'
expect "M11 the corpus' MINIMUM convention inverted" red

echo "=== M12 THE REAL COUPLING: pullreach's path also feeds the 1200 filter ==="
sub "$SRC" "$CALL" $'\t\t\tand J.IsCampBesideLane( camp.location, tReachPath )\n\t\t\tand J.IsCampWithinPullReach( camp.location, tReachPath )'
expect "M12 one path feeds both constants" red

echo
echo "STAND: $PASS ok, $FAIL bad"
[ "$FAIL" -eq 0 ] || exit 1
