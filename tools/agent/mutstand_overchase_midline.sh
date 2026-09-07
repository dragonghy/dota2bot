#!/usr/bin/env bash
# Mutation stand for the `overchase` midline-margin narrowing -- "the branch
# that carries the guard is the one with no anchor" (strategy, 2026-09-07,
# OWNER_PRIORITIES P4.4(i)).  Run by hand when leg (b) of
# J.ShouldPunishOverchase, J.SafeToCommitFight's 'depthnum' margin, or
# tests/test_overchase_midline_margin.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_ohnum.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing, nor "survived" for having
#     applied to the wrong one of two identical sites (GH #550);
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  This lever has NO new soak id -- it edits the body of
# an already-gated helper -- so the usual "is the gate wired" mutants do not
# apply and the file's whole weight rests on real-frame behaviour.  Four of the
# six are the reason it exists:
#   * M1 IS THE REVERT.  Put 800 back and the guard fires on the positive
#     control again.  A stand that cannot see M1 is certifying a no-op.
#   * M2 IS THE OFF SWITCH, and it is this lever's own near-miss.  Over-tighten
#     the same number and the positive control still passes -- because it
#     asserts a REFUSAL, and a guard that refuses everything refuses that too.
#     Only the negative controls separate "narrowed" from "disabled", which is
#     exactly the lanefix lesson (locally-correct, aggregate-negative).
#   * M3 TIGHTENS THE WRONG BRANCH.  It applies the new margin to the HARD
#     building read instead of the soft one.  The positive control passes (that
#     frame has no building within 1200 either way); if M3 survives, the file is
#     certifying a claim about WHICH branch was narrowed that it cannot see.
#   * M5 BREAKS THE BORROWED NUMBER.  The lever's stated justification is that
#     it adopts J.SafeToCommitFight's existing fog margin rather than inventing
#     a third one.  Move that margin and the two silently disagree while every
#     behavioural assertion still passes.
#
# Usage: bash tools/agent/mutstand_overchase_midline.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_overchase_midline_margin.lua

FILES=("$JMZ" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ocmid.XXXXXX")
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
    lua5.1 tests/run_tests.lua overchase_midline > "$WORK/run.log" 2>&1
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

# The SOFT (midline) read inside J.ShouldPunishOverchase.  Anchored on the two
# lines together because the bare `- 1600` appears elsewhere in the file.
SOFT=$'\t\t\t\t\tbDeep = J.GetLocationToLocationDistance( vEnemyLoc, hOwnAncient:GetLocation() )\n\t\t\t\t\t\t< J.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() ) - 1600'
# The HARD (building) read in the same leg.
HARD=$'\t\t\t\t\tand GetUnitToUnitDistance( enemy, building ) <= 1200'
# The margin this lever borrows, in J.SafeToCommitFight's 'depthnum' branch.
# ⚠️ The five-line 'depthnum' paragraph is BYTE-FOR-BYTE IDENTICAL in
# J.SafeToCommitFight and J.SafeToCommitFightOnArrival, so the obvious anchor is
# AMBIGUOUS and the guard aborts on it -- which is how this stand first scored
# M5 as "survived" for a mutant that had applied to nothing (GH #550, live).
# The anchor is therefore extended UPWARD to the nearest line that differs: the
# comment closing SafeToCommitFight's lethal-branch note. Do not shorten it.
BORROW=$'\t-- unchanged.\n\tif J.IsModeTurbo() and J.IsSoakCandidate( \'depthnum\' ) then\n\t\tlocal hEnemyAncient = GetAncient( GetOpposingTeam() )\n\t\tlocal hOwnAncient   = GetAncient( GetTeam() )\n\t\tlocal bDeep = hEnemyAncient ~= nil and hOwnAncient ~= nil\n\t\t\tand J.GetLocationToLocationDistance( vLoc, hEnemyAncient:GetLocation() )\n\t\t\t\t< J.GetLocationToLocationDistance( vLoc, hOwnAncient:GetLocation() ) - 1600'
BORROW_NEW=$'\t-- unchanged.\n\tif J.IsModeTurbo() and J.IsSoakCandidate( \'depthnum\' ) then\n\t\tlocal hEnemyAncient = GetAncient( GetOpposingTeam() )\n\t\tlocal hOwnAncient   = GetAncient( GetTeam() )\n\t\tlocal bDeep = hEnemyAncient ~= nil and hOwnAncient ~= nil\n\t\t\tand J.GetLocationToLocationDistance( vLoc, hEnemyAncient:GetLocation() )\n\t\t\t\t< J.GetLocationToLocationDistance( vLoc, hOwnAncient:GetLocation() ) - 2400'

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
# M1: THE REVERT.  The old 800 margin comes back, so the guard fires on the
#     positive control again.  This is the mutant that proves the lever is not
#     a no-op.
echo
echo "=== M1: the margin reverts to the shipped 800 ==="
sub "$JMZ" "$SOFT" $'\t\t\t\t\tbDeep = J.GetLocationToLocationDistance( vEnemyLoc, hOwnAncient:GetLocation() )\n\t\t\t\t\t\t< J.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() ) - 800'
score "M1" "the narrowed guard now FIRES on the positive-control frame"

# ---------------------------------------------------------------------------
# M2: THE OFF SWITCH -- this lever's own near-miss.  Over-tighten to 4000 and
#     the guard stops firing anywhere.  The positive control STILL PASSES (it
#     asserts a refusal), so only the negative controls can tell a narrowing
#     from a disablement.
echo
echo "=== M2: the margin is over-tightened to 4000 (off switch) ==="
sub "$JMZ" "$SOFT" $'\t\t\t\t\tbDeep = J.GetLocationToLocationDistance( vEnemyLoc, hOwnAncient:GetLocation() )\n\t\t\t\t\t\t< J.GetLocationToLocationDistance( vEnemyLoc, hEnemyAncient:GetLocation() ) - 4000'
score "M2" "the narrowed guard no longer fires on"

# ---------------------------------------------------------------------------
# M3: THE WRONG BRANCH.  The new margin is applied to the HARD building read
#     instead of the soft one, and the soft read goes back to 800.  The
#     positive-control frame has no allied building within 1200 either way, so
#     every behavioural assertion about THAT frame is unchanged.
echo
echo "=== M3: the BUILDING branch is tightened instead of the midline ==="
sub "$JMZ" "$HARD" $'\t\t\t\t\tand GetUnitToUnitDistance( enemy, building ) <= 600'
score "M3" "building radius is now 600"

# ---------------------------------------------------------------------------
# M4: the soft branch is deleted outright.  Leg (b) then admits only chasers
#     next to a live structure of ours -- which the census says is NONE of the
#     corpus's firings (oc_fire_building 0), so the guard goes silent.
echo
echo "=== M4: the soft midline branch is deleted entirely ==="
sub "$JMZ" "$SOFT" $'\t\t\t\t\tbDeep = false'
score "M4" "the narrowed guard no longer fires on"

# ---------------------------------------------------------------------------
# M5: THE BORROWED NUMBER breaks.  J.SafeToCommitFight's 'depthnum' margin moves
#     to 2400 while leg (b) keeps 1600.  Behaviour on all three frames is
#     unchanged (that branch needs 'depthnum' armed, which no test here arms),
#     so only the source pin on the convention can see it.
echo
echo "=== M5: the depthnum margin this lever borrows moves to 2400 ==="
sub "$JMZ" "$BORROW" "$BORROW_NEW"
score "M5" "the fog margin the tree already writes for this exact reasoning is 2400"

# ---------------------------------------------------------------------------
# M6: a control on the STAND ITSELF.  A pure-comment edit inside the same
#     function must NOT turn the file red -- if it does, some assertion is
#     anchored on prose rather than on code or behaviour, and every "caught"
#     above is suspect.
echo
echo "=== M6 (control): a comment-only edit must NOT be caught ==="
sub "$JMZ" $'\t\t\t-- STRICTLY NARROWING: this can only turn a collapse OFF, never on,' \
    $'\t\t\t-- STRICTLY NARROWING (reworded control edit; no code changed),'
run_tests; RC=$?
TOTAL=$((TOTAL + 1))
if [ "$RC" -eq 0 ]; then
    echo "M6  correctly NOT caught (exit 0) -- no assertion is anchored on prose"
    CAUGHT=$((CAUGHT + 1))
else
    echo "M6  FALSE POSITIVE (exit $RC) -- an assertion is anchored on a comment,"
    echo "        so the 'caught' verdicts above do not mean what they say:"
    grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
fi
restore > /dev/null

# ---------------------------------------------------------------------------
echo
echo "=== stand: $CAUGHT/$TOTAL ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
