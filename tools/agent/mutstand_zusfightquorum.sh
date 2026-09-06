#!/usr/bin/env bash
# Mutation stand for the `zusfightquorum` candidate -- the team-fight branch of
# Zeus's X.ConsiderR asks for a quorum of enemy heroes that is the CEILING of
# the quantity it thresholds, not a point inside its range (hero, 2026-09-06,
# OWNER_PRIORITIES P4.4).  Run by hand when X.zuus_ShouldUltForTeamFight,
# X.ConsiderR, tests/test_zuus_fight_quorum.lua or
# tests/_zusfightquorum_sweep.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusultstrand.sh):
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
# WHAT THIS STAND IS FOR.  Five of the eleven are directional, instrumental or
# premise-moving rather than cosmetic, and they are the ones worth reading:
#   * M5 IS THE ONE THAT MOVES THE PREMISE.  The round rests on a single
#     falsifiable sentence -- "the shipped quorum is the ceiling of the count,
#     not a point inside its range" -- and it is section 2, which compares the
#     shipped constant against the corpus's own largest side, that carries it.
#     Drop the quorum to 3 and the sentence becomes false; nothing that asserts
#     on the helper's gate-off/armed answers alone can tell you why.
#   * M6 IS THE BLANK CHEQUE WEARING A TUNING KNOB'S CLOTHES.  Inflate the fight
#     radius and every vantage point sees the whole enemy team, so the shipped
#     quorum stops being out of range and the branch fires map-wide.  Only the
#     corpus sweep sees this, because it reads the radius off the hero file
#     instead of re-typing it.
#   * M7 IS THE VACUITY CONTROL, and a quorum lever needs one more than most: a
#     count that can never reach its threshold and a count that is never read
#     produce exactly the same falses.  Make the head count constant 0 and only
#     section 4's labelled full-team injection notices.
#   * M8 AND M9 ARE THE TWO WAYS THE ARMED SIDE DIES.  M8 drops the armed quorum
#     to 1 -- 46% of the corpus admitted, a 130s-cooldown global nuke in every
#     skirmish.  M9 raises it to the shipped value -- the dead-wiring twin, where
#     helper, id, gate and call site all survive review while the armed answer is
#     byte-for-byte the shipped one and the verdict reads back "tested, no
#     effect" with nothing raising a hand.
#   * M11 IS THE INSTRUMENT CONTROL ON THE SWEEP ITSELF.  Section 2's range claim
#     is worth exactly as many vantage points as it was paid for; narrow the
#     sweep to subject frames only and the claim must stop being made.
#
# Usage: bash tools/agent/mutstand_zusfightquorum.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_zuus.lua
TEST=tests/test_zuus_fight_quorum.lua
SWEEP=tests/_zusfightquorum_sweep.lua

FILES=("$HERO" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zfq.XXXXXX")
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

# The filter is `zuus`, not this one file: the sibling files assert on this
# hero's ult strand, its bolt block, its mana budget and its talent rows, and a
# stand scoped to the new file alone would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua zuus > "$WORK/run.log" 2>&1
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

GATE_LINE=$'\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( \'zusfightquorum\' ) ) then return false end'
COUNT_LINE=$'\tlocal nInvUnit = J.GetInvUnitCount( false, tNearbyEnemyHeroes )'
ARMED_RET=$'\treturn nInvUnit >= X.nUltFightQuorumArmed'
CALL_SITE=$'\t\tand X.zuus_ShouldUltForTeamFight( bot )'
FIGHT_SITE=$'\tif J.IsInTeamFight( bot, X.nUltFightRadius )'
RADIUS='X.nUltFightRadius = 1400'
Q_SHIPPED='X.nUltFightQuorumShipped = 5'
Q_ARMED='X.nUltFightQuorumArmed = 3'
SWEEP_VANTAGE=$'            if u.alive and h ~= nil and h.GetNearbyHeroes ~= nil then'

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
# M1: the candidate check is dropped.  The lowered quorum becomes the shipped
#     default in every Turbo game -- a defaults change wearing a candidate's
#     name, and on a WIDENING that means new ult casts in live games.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsModeTurbo() ) then return false end'
score "M1" "gate-off answered"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1,
#     and it reaches normal mode, where a 130s cooldown is a much smaller share
#     of the ultimates the hero will cast in the game.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsSoakCandidate( \'zusfightquorum\' ) ) then return false end'
score "M2" "fired outside turbo"

# ---------------------------------------------------------------------------
# M3: the call site reverts to the inline quorum.  The helper, the id and the
#     gate all survive review; only the wire is gone, and `check_armed_wiring.py`'s
#     question ("does a call site exist?") is the one thing this does not answer.
echo
echo "=== M3: the call site inlines the ceiling quorum again ==="
sub "$HERO" "$CALL_SITE" \
    $'\t\tand J.GetInvUnitCount( false, J.GetNearbyHeroes( bot, 1400, true, BOT_MODE_NONE ) ) >= 5'
score "M3" "still holds the bare J.GetInvUnitCount"

# ---------------------------------------------------------------------------
# M4: the two halves of the shipped condition are allowed to drift.  A literal
#     in J.IsInTeamFight and a constant in the head count measure two different
#     circles, and a later edit to one of them moves only half the branch.
echo
echo "=== M4: the fight test goes back to a literal radius ==="
sub "$HERO" "$FIGHT_SITE" $'\tif J.IsInTeamFight( bot, 1400 )'
score "M4" "no longer hands X.nUltFightRadius"

# ---------------------------------------------------------------------------
# M5: THE PREMISE.  Everything in this round follows from "the shipped quorum is
#     the ceiling of the count, not a point inside its range".  Drop it below the
#     ceiling and it becomes an ordinary threshold -- the branch is reachable and
#     the lever is misdiagnosed.  Only section 2, which compares the shipped
#     constant against the corpus's own largest side, can see this.
echo
echo "=== M5: the shipped quorum drops below the team ceiling (the premise) ==="
sub "$HERO" "$Q_SHIPPED" 'X.nUltFightQuorumShipped = 3'
score "M5" "the largest side in the corpus holds"

# ---------------------------------------------------------------------------
# M6: the fight radius is inflated past the map.  It looks like a tuning choice
#     and it is a blank cheque: every vantage point then sees the whole enemy
#     team, the shipped quorum stops being out of range, and the branch fires
#     map-wide.  Only the corpus sweep sees it, and only because the sweep READS
#     the radius off the hero file instead of re-typing it.
echo
echo "=== M6: the fight radius is inflated until everyone is in every fight ==="
sub "$HERO" "$RADIUS" 'X.nUltFightRadius = 16000'
score "M6" "no longer out of range"

# ---------------------------------------------------------------------------
# M7: THE VACUITY CONTROL.  A count that can never reach its threshold and a
#     count that is never read produce exactly the same falses -- that is how a
#     ceiling quorum looks from the outside.  Make the head count constant 0;
#     only section 4's labelled full-team injection notices, which is why that
#     injection exists.
echo
echo "=== M7: the head count stops reading its input (vacuity control) ==="
sub "$HERO" "$COUNT_LINE" $'\tlocal nInvUnit = 0'
score "M7" "did NOT reach the shipped quorum"

# ---------------------------------------------------------------------------
# M8: THE BLANK CHEQUE.  This lever is a widening and the armed quorum is the
#     only thing keeping it narrow.  At 1 it admits 46% of the corpus -- a
#     130s-cooldown, 250-500 mana global nuke in every two-hero skirmish.
echo
echo "=== M8: the armed quorum drops to a single enemy hero ==="
sub "$HERO" "$Q_ARMED" 'X.nUltFightQuorumArmed = 1'
score "M8" "it is a blank cheque that fires a 130s-cooldown global nuke"

# ---------------------------------------------------------------------------
# M9: THE DEAD-WIRING TWIN.  Raise the armed quorum to the shipped value and the
#     armed answer is byte-for-byte the shipped one.  Helper, id, gate and call
#     site all survive review, the lever is inert in every wave, and the verdict
#     reads back "tested, no effect" with nothing raising a hand (GH #531's third
#     shape).
echo
echo "=== M9: the armed quorum is raised to the shipped quorum ==="
sub "$HERO" "$Q_ARMED" 'X.nUltFightQuorumArmed = 5'
score "M9" "admits 0 vantage points out of"

# ---------------------------------------------------------------------------
# M10: the armed leg answers the SHIPPED quorum while the constant stays put.
#      The same inert lever as M9 but hidden in the expression rather than in a
#      number a reviewer would check.
echo
echo "=== M10: the armed leg compares against the shipped quorum ==="
sub "$HERO" "$ARMED_RET" $'\treturn nInvUnit >= X.nUltFightQuorumShipped'
score "M10" "did not admit a fight of"

# ---------------------------------------------------------------------------
# M11: THE INSTRUMENT CONTROL ON THE SWEEP.  Section 2's claim is about the RANGE
#      of the count, and a claim about a range is worth exactly as many vantage
#      points as it was paid for.  Narrow the sweep to subject frames only (109
#      instead of 1012) and the claim must stop being made rather than quietly
#      shrink.
echo
echo "=== M11: the sweep narrows to subject frames only (instrument control) ==="
sub "$SWEEP" "$SWEEP_VANTAGE" \
    $'            if u.alive and h ~= nil and h.GetNearbyHeroes ~= nil and u.name == fx.self then'
score "M11" "vantage points; the range claim is worth as many"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
