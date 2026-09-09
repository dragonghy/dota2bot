#!/usr/bin/env bash
# Mutation stand for the 'ownhalf' invade-depth margin (strategy, 2026-09-09).
#
# The claim under test: "J.ShouldPunishDive's 'ownhalf' branch and
# J.ShouldPunishOverchase's midline branch compute the SAME ancient-distance
# quantity and hand it to the SAME commit test, and the first one required only
# 800u where the second (and J.SafeToCommitFight's 'depthnum' branch, which
# both borrow from) requires 1600u; putting the branch on the tree's own
# convention removes 43 (bot, enemy) pairs on 37 frames from the domain by
# arithmetic and 23 frames from the armed drive, deletes no shipped firing, and
# leaves genuinely deep invaders still punished."
#
# Run by hand when J.ShouldPunishDive, J.ShouldPunishOverchase,
# tests/_posture_domain_sweep.lua or tests/test_ownhalf_margin.lua are edited,
# and before quoting any of these readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_hrparity.sh):
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
# concurrent reader (GH #507). Each leg costs ~32s (the guard drives the whole
# 110-fixture / 1021-frame posture sweep once per run), so budget ~6 minutes.
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M2 IS WHY THE PIN IS THREE-WAY AND NOT TWO-WAY. "Make the two numbers
#     agree" has a second solution: move the SIBLING down to 800 instead. That
#     mutant satisfies any equality between this branch and overchase, restores
#     the exact defect on both sites at once, and is caught only because
#     J.SafeToCommitFight's 'depthnum' margin is pinned as a third witness --
#     the one of the three that carries the written reason.
#   * M3 IS THE NEGATIVE CONTROL'S REASON TO EXIST, and it is built to defeat
#     every other assertion in the file. It moves BOTH margins together to a
#     value no corpus frame reaches: the parity pins stay green, the band stays
#     empty, the shipped path is untouched, the positive control still refuses
#     -- and the branch is dead. Only "a genuinely deep invader is still
#     punished" separates NARROWED from SWITCHED OFF. That is the lanefix
#     lesson, and it was the overchase round's own near-miss.
#   * M4 IS THE ACCIDENTAL-PROMOTE LEG. Drop `bOwnHalf` from the branch
#     condition and the wider domain runs in every turbo game with nothing
#     armed -- an unpromoted behaviour change live in real games. Its `want`
#     is written from what the leg ACTUALLY printed: the first draft expected
#     the shipped-path witness to speak up, the placement pin spoke first, and
#     the pin's message said only "re-anchor this" -- true but useless. The pin
#     was split so a branch present WITHOUT its gate names the accidental
#     promote; the expectation was not bent to fit the old message.
#   * M5 IS THE 0OVERCHASE RULE AS AN EXECUTABLE. A nested
#     J.IsSoakCandidate('<new>') inside a branch already gated on an unpromoted
#     host is the conjunction `ownhalf AND <new>`; its single-arm wave reads a
#     zero that is structurally impossible, and check_armed_wiring.py still
#     calls it WIRED (GH #606). Prose said so; this leg makes the tree say so.
#   * M6 IS THE DEAD-COLUMN RATCHET. `pd_pairs` shipped in this sweep declared
#     and never bumped -- a counter that could only ever print 0 standing beside
#     real ones (the GH #171 shape). Un-bump it and the stand must notice, or
#     the repair can silently regress and the next reader gets a zero that means
#     "unmeasured" while looking like "empty".
#   * M7 IS THE SIGN LEG. Measuring depth into THEIR half instead of ours keeps
#     every literal in place, keeps the margins equal, keeps the band empty --
#     and inverts what the branch is about.
#   * M8 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_ownhalf_margin.lua
SWEEP=tests/_posture_domain_sweep.lua

FILES=("$JMZ" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ownhalf.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_ownhalf_margin > "$WORK/run.log" 2>&1
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
MARGIN=$'\t\t\t\tif nInvadeDepth >= 1600 then bInDomain = true end\n'
BRANCH=$'\t\t\tif not bInDomain and bOwnHalf\n'
CHASE=$'\t\t\t\t\t\t< J.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() ) - 1600\n'
COMMIT=$'\t\t\tand J.GetLocationToLocationDistance( vLoc, hEnemyAncient:GetLocation() )\n\t\t\t\t< J.GetLocationToLocationDistance( vLoc, hOwnAncient:GetLocation() ) - 1600\n\t\tif bDeep then\n\t\t\treturn #tAllies >= #J.GetEnemiesNearLoc( vLoc, 1200 ) + 1\n'
DEPTH=$'\t\t\t\tlocal nInvadeDepth =\n\t\t\t\t\tJ.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() )\n\t\t\t\t\t- J.GetLocationToLocationDistance( vEnemyLoc, hOwnAncient:GetLocation() )\n'
PDPAIRS=$'                            bump(\'pd_pairs\')\n'
HDR=$'\t\t\t\t-- [strategy 20260909 / tests/_posture_domain_sweep.lua] THE MARGIN\n'

# ---------------------------------------------------------------------------
echo
echo "=== mutants ==="

# M1 -- the rollback.  Put this branch back on the shallow margin and leave the
# sibling where it is: the exact tree this change was made from.
sub_or_die "$JMZ" "$MARGIN" $'\t\t\t\tif nInvadeDepth >= 800 then bInDomain = true end\n'
score "M1 margin rolled back to 800     " \
    "same quantity, same team's ground, same downstream commit"

# M2 -- AGREEMENT BY MOVING THE OTHER ONE.  Both sites end up at 800, so any
# two-way equality pin is satisfied while the defect is restored on BOTH.
sub_or_die "$JMZ" "$MARGIN" $'\t\t\t\tif nInvadeDepth >= 800 then bInDomain = true end\n'
sub_or_die "$JMZ" "$CHASE" $'\t\t\t\t\t\t< J.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() ) - 800\n'
score "M2 sibling dragged down to 800   " \
    "has drifted from the depthnum convention it borrows"

# M3 -- NARROWED vs SWITCHED OFF.  Move all three margins together to a depth
# no corpus frame reaches; every pin except the negative control stays green.
sub_or_die "$JMZ" "$MARGIN" $'\t\t\t\tif nInvadeDepth >= 9000 then bInDomain = true end\n'
sub_or_die "$JMZ" "$CHASE" $'\t\t\t\t\t\t< J.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() ) - 9000\n'
sub_or_die "$JMZ" "$COMMIT" $'\t\t\tand J.GetLocationToLocationDistance( vLoc, hEnemyAncient:GetLocation() )\n\t\t\t\t< J.GetLocationToLocationDistance( vLoc, hOwnAncient:GetLocation() ) - 9000\n\t\tif bDeep then\n\t\t\treturn #tAllies >= #J.GetEnemiesNearLoc( vLoc, 1200 ) + 1\n'
score "M3 all three margins -> disable  " \
    "only this one can tell"

# M4 -- ACCIDENTAL PROMOTE.  The branch no longer asks whether anything armed
# it, so the wider domain runs in every turbo game.
sub_or_die "$JMZ" "$BRANCH" $'\t\t\tif not bInDomain\n'
score "M4 gate dropped from the branch  " \
    "no longer asks whether anything armed"

# M5 -- a nested candidate inside an unpromoted host (GH #606 / #576 / #600).
sub_or_die "$JMZ" "$MARGIN" $'\t\t\t\tif nInvadeDepth >= 1600 and J.IsSoakCandidate( \'ohdeep\' ) then bInDomain = true end\n'
score "M5 nested soak id in the branch  " \
    "a soak gate appeared inside or below the ownhalf branch"

# M6 -- the dead column comes back: pd_pairs declared, never bumped.
sub_or_die "$SWEEP" "$PDPAIRS" ""
score "M6 pd_pairs un-bumped again      " \
    "pd_pairs is back to 0"

# M7 -- SIGN.  Same literals, same equality, opposite question.
sub_or_die "$JMZ" "$DEPTH" $'\t\t\t\tlocal nInvadeDepth =\n\t\t\t\t\tJ.GetLocationToLocationDistance( vEnemyLoc, hOwnAncient:GetLocation() )\n\t\t\t\t\t- J.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() )\n'
score "M7 invade depth sign flipped     " \
    "only this one can tell"

# M8 -- CONTROL.  A comment-only edit must survive.
sub_or_die "$JMZ" "$HDR" $'\t\t\t\t-- [strategy 20260909 -- comment-only control leg] THE MARGIN\n'
score_control "M8 comment-only control          "

# ---------------------------------------------------------------------------
echo
echo "=== stand ==="
echo "legs $TOTAL   caught/correct $CAUGHT   survived $SURVIVED"
if [ "$SURVIVED" -ne 0 ]; then
    echo "STAND RED -- at least one mutant is invisible to the guard; do not"
    echo "quote this guard's readings until every leg is accounted for."
    exit 3
fi
echo "STAND GREEN"
