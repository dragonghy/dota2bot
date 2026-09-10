#!/usr/bin/env bash
# Mutation stand for the `isvalidbld` reading (strategy desk 2026-09-10, second
# work unit). Not part of any suite -- run by hand when J.IsValid, the runMode
# barracks branch, the fixture loader's structure wiring or
# tests/test_isvalid_building_sentinel.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# WHAT THIS STAND IS FOR. This round lands NO bots/ change, so what is on the
# bench is a RULING and a FINDING, and each of them has a way to be wrong:
#   * M1 removes the cause. If J.IsValid stops rejecting buildings, the whole
#     file's subject is gone -- and the reading must not survive that quietly.
#   * M2 is the FINDING BEING FIXED. The day somebody changes the runMode
#     branch to the building validator, this file has to say so rather than
#     keep asserting a defect that is no longer there. A stand that cannot go
#     red on the repair is a stand that would leave a stale finding standing.
#   * M3 is the RULING'S ALARM. Feed one centroid call site a structure list
#     and the second sentinel becomes reachable exactly where this round said
#     it was not. If M3 survives, the refusal in the charter is unguarded.
#   * M4 attacks the CAUSE ISOLATION rather than the count: section 1 claims the
#     rejection is `not IsBuilding()` and nothing else, so a loader that stops
#     marking structures as buildings must break it.
#   * M5 is a NEW dead branch of the same family appearing elsewhere in the
#     tree -- the one thing this file exists to catch early.
#   * M6 does not touch bots/ at all: it moves a published reading.
#
# Usage: bash tools/agent/mutstand_isvalidbld.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
FARM=bots/mode_farm_generic.lua
RETREAT=bots/mode_retreat_generic.lua
LOADER=tests/mock/replay_fixture.lua
TEST=tests/test_isvalid_building_sentinel.lua

FILES=("$JMZ" "$FARM" "$RETREAT" "$LOADER" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_isvalidbld.XXXXXX")
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
    lua5.1 tests/run_tests.lua isvalid_building_sentinel > "$WORK/run.log" 2>&1
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
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: J.IsValid stops rejecting buildings -- the cause the whole file is about.
echo
echo "=== M1: J.IsValid drops its 'not IsBuilding()' conjunct ==="
sub "$JMZ" "			and not nTarget:IsBuilding()" \
           "			and true"
score "M1" "structures now pass J.IsValid"

# ---------------------------------------------------------------------------
# M2: the finding is REPAIRED. Not a defect -- the good day. The file must
#     still go red, because a finding that outlives its fix is a stale register.
echo
echo "=== M2: the runMode branch is switched to the building validator ==="
sub "$FARM" "if J.IsValid(runModeBarracks[1])" \
            "if J.IsValidBuilding(runModeBarracks[1])"
score "M2" "expected exactly the one known site, got 0"

# ---------------------------------------------------------------------------
# M3: THE RULING'S ALARM -- a centroid call site is handed a structure list.
#     The line mutated is the nearest preceding assignment of the variable that
#     bot.farmLocation's centroid reads, so the resolver sees a new producer.
echo
echo "=== M3: one centroid call site is fed a tower list ==="
sub "$FARM" "hLaneCreepList = bot:GetNearbyLaneCreeps(1600, false)" \
            "hLaneCreepList = bot:GetNearbyTowers(1600, false)"
score "M3" "takes a producer this file has never classified"

# ---------------------------------------------------------------------------
# M4: the CAUSE, not the count. Section 1 says the rejection is IsBuilding and
#     nothing else; a loader that stops saying so must break that claim.
echo
echo "=== M4: the loader stops marking structures as buildings ==="
sub "$LOADER" "            IsBuilding = true," \
              "            IsBuilding = false,"
score "M4" "every structure answers IsBuilding"

# ---------------------------------------------------------------------------
# M5: a SECOND dead branch of the same family lands elsewhere in the tree.
echo
echo "=== M5: another structure list is handed to the unit validator ==="
sub "$RETREAT" "if J.IsValidBuilding(nEnemyTowers[1]) and not J.IsPushing(bot) then" \
               "if J.IsValid(nEnemyTowers[1]) and not J.IsPushing(bot) then"
score "M5" "expected exactly the one known site, got 2"

# ---------------------------------------------------------------------------
# M6: a published READING is moved, in the test file only. bots/ is untouched.
echo
echo "=== M6: the recorded all-invalid structure-list count is moved ==="
sub "$TEST" "cs.ratchet(C('tower_nonempty'), 520, 'non-empty structure lists')" \
            "cs.ratchet(C('tower_nonempty'), 620, 'non-empty structure lists')"
score "M6" "non-empty structure lists FELL"

# ---------------------------------------------------------------------------
echo
echo "=== STAND: $CAUGHT/$TOTAL caught ==="
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "STAND NOT GREEN -- read the SURVIVED lines above before believing any"
    echo "reading this round published."
    exit 1
fi
echo "STAND GREEN"
