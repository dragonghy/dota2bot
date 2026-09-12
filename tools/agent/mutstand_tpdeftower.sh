#!/usr/bin/env bash
# Mutation stand for the `tpdeftower` FINDING (strategy desk 2026-09-12).
# Not part of any suite -- run by hand when the winnability site inside
# J.ShouldTpSupportTowerFight (bots/FunLib/jmz_func.lua), its tower-name test,
# the sibling candidate tests/test_tparrive_collapse_gate.lua, or
# tests/test_tpdeftower_anchor_pricing.lua is edited.
#
# ⛔ WHAT IS ON THE BENCH IS NOT A BEHAVIOUR CHANGE. The tower-anchored reading
# this census prices was written and driven in an OUT-OF-TREE COPY of the repo,
# never in the worktree; what landed is two comment repairs plus the census. So
# the mutants are not "does the fix still fire" -- they are "can this file still
# be trusted to say what it says", which is the only job a census without a
# lever has. Two consequences:
#   * there are no gate-shaped mutants here, and
#   * the ones that matter most aim at the file's OWN ORACLES (M1-M3), at its
#     corpus scoping (M4) and at its end-to-end DRIVER (M5) -- a census whose
#     oracle or driver has quietly degenerated still prints plausible numbers.
#
# ⭐ M5 IS THE ONE THIS ROUND ADDED ON PURPOSE. Section 4's load-bearing
# assertions are two REFUSALS ("shipped answers nil on tparrive's controls"), and
# a driver that stopped arming anything satisfies both for free -- the host's
# second line returns nil with no candidate armed. Every negative reading needs
# a positive control, and M5 is the mutant that proves this file has one.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ Do NOT run this while the start-of-shift self-check is running: they share
# the worktree, and a half-written mutant reads as a real regression (the
# 2026-09-12T08:00Z round lost a measurement that way).
#
# Usage: bash tools/agent/mutstand_tpdeftower.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/jmz_func.lua
TEST=tests/test_tpdeftower_anchor_pricing.lua
SIB=tests/test_tparrive_collapse_gate.lua
FILES=("$SRC" "$TEST" "$SIB")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tpdeftower.XXXXXX")
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
    lua5.1 tests/run_tests.lua tpdeftower > "$WORK/run.log" 2>&1
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

echo
echo "=== mutants ==="

# M1: the file's SHIPPED oracle degenerates to a constant true. Every ratchet in
# section 2 keeps passing (a ratchet only ever sees growth); what breaks is the
# ADD count, which is defined against it.
sub "$TEST" $'    return J.SafeToCommitFight(bot, t[1]) and true or false\nend' $'    return true\nend'
score "M1 shipped oracle -> constant true " "sites the tower anchor ADDS FELL"

# M2: the COUNTERFACTUAL oracle degenerates to a constant true -- the shape that
# would make this round's finding look bigger than it is.
sub "$TEST" $'    return #tAllies >= #tEnemies, false\nend' $'    return true, false\nend'
score "M2 counterfactual -> constant true " "sites the tower anchor WITHDRAWS FELL"

# M3: ...and to a constant false, which is caught by a DIFFERENT assertion (the
# non-degeneracy floor), not by the same one reading a smaller number.
sub "$TEST" $'    return #tAllies >= #tEnemies, false\nend' $'    return false, false\nend'
score "M3 counterfactual -> constant false" "the tower-anchored reading commits on 0 sites"

# M4: trap (2) put back -- the subject-team filter removed from the sweep, so the
# loader hands the shipped producer the driven hero's own teammates as enemies.
sub "$TEST" $'                if h ~= nil and h.IsAlive and h:IsAlive()\n                    and h:GetTeam() == subj_team\n                then\n                    bump(\'live\')' $'                if h ~= nil and h.IsAlive and h:IsAlive() then\n                    bump(\'live\')'
score "M4 subject-team filter removed     " "list an ALLY of the driven hero as an enemy"

# M5: ⭐ the end-to-end DRIVER stops arming. Both of section 4's refusals become
# free, and only the positive control can see it.
sub "$TEST" $'    for _, id in ipairs(ids) do armed[id] = true end' $'    for _, id in ipairs(ids) do armed[id] = false end'
score "M5 driver arms nothing             " "no longer makes the host answer on the one frame"

# M6: the outpost detector degenerates -- the second finding's whole subject.
sub "$TEST" $'local function is_outpost(b) return b:GetUnitName() == \'watch_tower\' end' $'local function is_outpost(b) return b ~= nil and false end'
score "M6 outpost detector -> false       " "FELL to 0 (registered 8)"

# M7: the repaired prose reverts to the false inference. One of the two things
# this round actually changed in shipped bytes.
sub "$SRC" $'-- IT WAS WRONG IN ITS INFERENCE. This comment used to call that branch inert in' $'-- IT WAS WRONG: never deep, so that branch is inert. This comment used to say'
score "M7 false inference comes back      " "is back in the prose"

# M8: someone lands the narrowing this round declined to land. Fine as a change,
# not fine unannounced -- the census's outpost counts are about the wide filter.
sub "$SRC" $'		and string.find( building:GetUnitName(), \'tower\' ) ~= nil' $'		and string.find( building:GetUnitName(), \'tower\' ) ~= nil\n		and building:GetUnitName() ~= \'watch_tower\''
score "M8 outpost narrowing lands quietly " "the host now names"

# M9: the sibling candidate's negative control disappears. The collision in
# section 4 was priced against those two lines; without them the price is stale.
sub "$SIB" $'        shipped = false, armed = false,' $'        shipped = false,'
score "M9 sibling negative control gone   " "re-price before re-landing"

# M10: the TEST's copy of the 'depthnum' margin drifts, so section 6 counts deep
# sites by a convention the predicate does not use.
sub "$TEST" $'local DEEP_MARGIN = 1600' $'local DEEP_MARGIN = 16000'
score "M10 test depth margin drifts       " "margin is no longer"

echo
echo "=== STAND: $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
