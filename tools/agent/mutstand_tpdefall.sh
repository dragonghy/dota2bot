#!/usr/bin/env bash
# Mutation stand for the `tpdefall` FINDING (strategy desk 2026-09-12).
# Not part of any suite -- run by hand when the winnability site inside
# J.ShouldTpSupportTowerFight (bots/FunLib/jmz_func.lua), the producer
# J.GetEnemiesNearLoc, or tests/test_tpdefall_tower_commit_quantifier.lua is
# edited.
#
# ⛔ WHAT IS ON THE BENCH IS NOT A BEHAVIOUR CHANGE. The lever this census prices
# was written, measured and reverted in the same work unit (see the test file's
# header, and section 4e for the reason). What landed is a COMMENT REPAIR plus
# the census. So the mutants here are not "does the fix still fire" -- they are
# "can this file still be trusted to say what it says", which is the only thing
# a census-without-a-lever is for. Two consequences worth stating plainly:
#   * the gate-shaped mutants a normal stand carries do not exist here, and
#   * the mutants that matter most are the ones aimed at the FILE's own oracles
#     (M8, M9) and at its corpus scoping (M10), because a census whose oracle
#     has quietly degenerated still prints numbers.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# THE MUTANTS
#   M1  the false sentence comes back. This is the ONE thing this round actually
#       changed in shipped bytes, so it is the one thing a regression can undo.
#   M2  a `table.sort` appears on the producer's path -- `[1]` would mean "the
#       nearest" again, which is a DIFFERENT (weaker) defect than the one this
#       file argues, and the file must not go on arguing the old one.
#   M3  the site moves to a different member. The census would then be about a
#       site that is not there.
#   M4  the tparrive leg silently repaired: fine as a change, not fine
#       unannounced, because the header registers it as deliberately left alone.
#   M5  the candidate early return moved below the site -- the only way anything
#       at this site could reach a shipped game.
#   M6  the TEST's own ring constant drifts, so every count is taken at a cell
#       the shipped producer never reads while the floors stay satisfied.
#   M7  a sibling file drops the assertion section 4e leans on. The revert
#       recorded in this file was priced against those two frames; if they go,
#       the price is stale and the next attempt must re-measure.
#   M8  ⭐ the file's SHIPPED oracle degenerates to a constant true.
#   M9  ⭐ the file's UNIVERSAL oracle degenerates to a constant true.
#       M8/M9 are the census's own failure mode: both keep every structural pin
#       green and both keep printing plausible numbers, so only section 3b's
#       EQUALITIES can see them -- and they are seen by DIFFERENT ones, which is
#       why both are on the bench and why neither is written as a ratchet:
#         * M9 trips `DIR_VIOLATION == 0` -- a constant-true universal claims 82
#           commits `[1]` refuses, i.e. the forbidden direction.
#         * M8 slips PAST the subtraction (113 - 28 == 85 balances) and is caught
#           only by `miss_ge2 == site_miss`: a constant-true shipped oracle
#           manufactures withdrawals on ONE-MEMBER lists, where the two readings
#           are literally the same expression. ⭐ That is the assertion doing
#           work no count could do, and the reason it is in the file.
#   M10 ⭐ the subject-team filter removed -- trap (2) in the test's header put
#       back. The loader binds enemies/allies to the LOADED subject's team, so
#       driving an opposite-team hero hands the shipped producer that hero's own
#       TEAMMATES as "enemies". It must be caught by section 4c's SAME_TEAM
#       equality, and by nothing else: every other counter is a floor, and
#       contamination only ever SATISFIES a floor.
#
# Usage: bash tools/agent/mutstand_tpdefall.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/jmz_func.lua
TEST=tests/test_tpdefall_tower_commit_quantifier.lua
SIB=tests/test_tparrive_collapse_gate.lua
FILES=("$SRC" "$TEST" "$SIB")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tpdefall.XXXXXX")
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
    lua5.1 tests/run_tests.lua tpdefall > "$WORK/run.log" 2>&1
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

SITE=$'\t\t\t\tand ( J.SafeToCommitFight( bot, tEnemies[1] )'
ARRIVE=$'\t\t\t\t\t\tand J.SafeToCommitFightOnArrival( bot, tEnemies[1] ) ) )'
CANDGATE=$'\tif not ( J.IsSoakCandidate( \'midtp\' ) or bSup ) then return nil end'
PRODUCER=$'\treturn enemies\nend\n\nfunction J.GetAnyEnemiesNearLoc(vLoc, nRadius)'
PROSE=$'\t\t\t\t-- of the enemies at the tower. If it does not hold, do NOT'

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

# M1: the repaired sentence reverts. The only shipped bytes this round changed.
sub "$SRC" "$PROSE" $'\t\t\t\t-- the nearest tower enemy. If it does not hold, do NOT'
score "M1 the false sentence comes back   " 'calls tEnemies[1] "the nearest tower enemy"'

# M2: a sort on the producer's path -- `[1]` would mean "the nearest" again.
sub "$SRC" "$PRODUCER" $'\ttable.sort(enemies, function() return false end)\n\treturn enemies\nend\n\nfunction J.GetAnyEnemiesNearLoc(vLoc, nRadius)'
score "M2 producer gains a table.sort     " "now sorts"

# M3: the site moves off the member this census is about.
sub "$SRC" "$SITE" $'\t\t\t\tand ( J.SafeToCommitFight( bot, tEnemies[#tEnemies] )'
score "M3 the site reads a different one  " "no longer reads tEnemies[1]. If someone repaired the site"

# M4: the tparrive leg silently repaired.
sub "$SRC" "$ARRIVE" $'\t\t\t\t\t\tand J.SafeToCommitFightOnArrival( bot, tEnemies[#tEnemies] ) ) )'
score "M4 tparrive leg silently repaired  " "the tparrive leg no longer reads tEnemies[1]"

# M5: the candidate early return moved below the site it guards.
sub "$SRC" "$CANDGATE" $'\tlocal bGateLater = not ( J.IsSoakCandidate( \'midtp\' ) or bSup )'
score "M5 candidate gate no longer early  " "midtp/suptp guard"

# M6: the TEST's own ring constant drifts.
sub "$TEST" $'local TOWER_RING = 1200' $'local TOWER_RING = 900'
score "M6 test ring constant drifts       " "FELL"

# M7: the sibling assertion section 4e is priced against disappears.
sub "$SIB" $'\'parity: both arms respond\'' $'\'parity: both arms answered\''
score "M7 sibling frame assertion dropped " "re-price before re-landing"

# M8: the file's SHIPPED oracle degenerates to a constant.
sub "$TEST" $'    return J.SafeToCommitFight(bot, t[1]) and true or false\nend' $'    return true\nend'
score "M8 shipped oracle -> constant true " "happened on a ONE-member list"

# M9: the file's UNIVERSAL oracle degenerates to a constant.
sub "$TEST" $'        if J.IsValidHero(t[i]) and not J.SafeToCommitFight(bot, t[i]) then\n            return false\n        end' $'        if false then\n            return false\n        end'
score "M9 universal oracle -> constant    " "row(s) where the universal says commit"

# M10: trap (2) put back -- the subject-team filter removed from the sweep.
sub "$TEST" $'                if h ~= nil and h.IsAlive and h:IsAlive()\n                    and h:GetTeam() == subj_team\n                then\n                    bump(\'live\')' $'                if h ~= nil and h.IsAlive and h:IsAlive() then\n                    bump(\'live\')'
score "M10 subject-team filter removed    " "list an ally as an enemy"

echo
echo "=== STAND: $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
