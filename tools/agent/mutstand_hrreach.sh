#!/usr/bin/env bash
# Mutation stand for the 'hrreach' guard (strategy, 2026-09-09).
#
# The claim under test: "J.GetLaneHarassResponse selects a harass target from
# an 1100u DETECTION radius and its caller spends that handle as an attack
# order, so on 8 of 54 'fire' frames the bot is sent walking at someone no hero
# in the patch could reach (max 1078u); arming 'hrreach' turns exactly those
# into a fall-through and never the other way."
#
# Run by hand when J.GetLaneHarassResponse, tests/_lanekill_domain_sweep.lua or
# tests/test_hrreach_guard.lua are edited, and before quoting any of these
# readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_dragnolane.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a
#     mutant can never score "caught" for having applied to nothing, nor
#     "survived" for having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets -- not the one
#     the author hoped for. Three legs of the first draft of
#     mutstand_dragnolane.sh were WRONG MESSAGE for exactly that reason.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507). Each leg costs ~28s (the test drives the whole
# 110-fixture corpus twice per entered frame), so budget ~6 minutes.
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M5 IS THE ONE THE CROSS-CHECK EXISTS FOR. Replace bot:GetAttackRange()
#     with the literal detection radius. The guard is still present, still
#     names its id, still loops, still compares a distance -- and the counting
#     identity `hr_closes == hr_fire - hr2_fire` STILL HOLDS (0 == 54-54). Only
#     the two-path cross-check (hr_fire_d_gt900 from the shipped drive vs
#     hr_closes_universal from the differential) separates "keyed on reach"
#     from "keyed on nothing".
#   * M3 IS THE ORDER-BLIND ONE. Move the whole gated block below the shipped
#     weakest loop's `return`. Every existence check still passes: the block is
#     present, unique, names its id. It is simply unreachable. Unlike
#     dragnolane's M3 the corpus columns DO move here, so this leg is caught
#     twice over -- the source-order pin is the one that would still catch it
#     if the columns ever stopped being sensitive, and that is why it is
#     asserted separately rather than inferred from the counts.
#   * M8 IS THE RATCHET (M12's lesson). It was written as "silently repair the
#     OTHER defect this round measured and deliberately did not fix". That
#     repair landed on 2026-09-09 as the gated id 'hrparity', so the same edit
#     now stands for the OTHER failure at the same spot -- the repair leaving
#     its gate. ⚠️ RECORD THE MISS THAT TAUGHT THIS: section 5's original pin
#     matched the FIRST `GetNearbyHeroes( bot, N, false` in the helper and
#     asserted 900, and a GATED repair leaves that line exactly where it was --
#     so the pin stayed GREEN while the helper changed under it. This leg only
#     ever caught the ungated form. A ratchet has to name the shipped default
#     AND require the repair where it lives; section 5 was rewritten to do both.
#   * M9 IS THE ZERO-VALUED COLUMN, taught by mutstand_fieldsip.sh's M8/M13.
#     `hr_opens` reads 0 on a clean tree, so renaming its bump is an
#     EQUIVALENT mutant -- the branch never executes. Vary its POLARITY.
#   * M7 IS THE COUNT-BLIND ONE. Every frame in this corpus is a range stub, so
#     rewriting the hr_range_stub column as an unconditional bump leaves the
#     manifest byte-identical. A source pin was added to
#     tests/test_hrreach_guard.lua in the same round SO THAT this leg is
#     catchable at all -- without it the mutant survives.
#   * M10 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_hrreach_guard.lua
SWEEP=tests/_lanekill_domain_sweep.lua

FILES=("$JMZ" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_hrreach.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_hrreach_guard > "$WORK/run.log" 2>&1
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
GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'hrreach\' )\n\tthen\n'
BLOCK=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'hrreach\' )\n\tthen\n\t\tlocal hInReach, nInReach = nil, math.huge\n\t\tlocal nMyReach = bot:GetAttackRange()\n\t\tfor _, e in pairs( tValid ) do\n\t\t\tif GetUnitToUnitDistance( bot, e ) <= nMyReach\n\t\t\tand e:GetHealth() < nInReach then\n\t\t\t\tnInReach, hInReach = e:GetHealth(), e\n\t\t\tend\n\t\tend\n\t\tif hInReach == nil then return nil end\n\t\treturn \'fire\', hInReach\n\tend\n\n'
SHIPPED_TAIL=$'\treturn \'fire\', hWeakest\nend\n'
REACHCMP=$'\t\t\tif GetUnitToUnitDistance( bot, e ) <= nMyReach\n'
GETRANGE=$'\t\tlocal nMyReach = bot:GetAttackRange()\n'
FALLTHRU=$'\t\tif hInReach == nil then return nil end\n'
# Two lines, not one: the bare `GetNearbyHeroes( bot, 900, false, ... )` call
# appears twice in this file and the stand's ambiguity check correctly refused
# the one-line form rather than mutating whichever came first (GH #550).
ALLYR=$'\tlocal tAllies = J.GetNearbyHeroes( bot, 900, false, BOT_MODE_NONE )\n\tlocal nOurs = 1 + ( tAllies ~= nil and #tAllies or 0 )\n'
SWEEP_STUB=$'                        if nMyReach == 150 then bump(\'hr_range_stub\')\n                        else bump(\'hr_range_live\') end\n'
SWEEP_OPENS=$'                            if sResp ~= \'fire\' and s2 == \'fire\' then\n                                bump(\'hr_opens\')\n                            end\n'
HDR=$'-- soak candidate \'hrreach\' (2026-09-09), which narrows that branch\'s candidate\n'

# ---------------------------------------------------------------------------
echo
echo "=== mutants ==="

# M1 -- the guard is simply gone.  Armed must then equal shipped.
sub_or_die "$JMZ" "$BLOCK" ""
score "M1 guard deleted                 " \
    "armed, the helper still answers"

# M2 -- the gate is not a gate: the id conjunct is dropped, so the narrowing
# runs in every turbo game whether or not anything armed it.
sub_or_die "$JMZ" "$GATE" $'\tif J.IsModeTurbo()\n\tthen\n'
score "M2 id conjunct dropped           " \
    "turbo alone now changes the answer"

# M3 -- ORDER BLIND.  The block is still present, still unique, still names its
# id; it is moved below the shipped return and is therefore dead code.
sub_or_die "$JMZ" "$BLOCK" ""
sub_or_die "$JMZ" "$SHIPPED_TAIL" $'\treturn \'fire\', hWeakest\n'"$BLOCK"$'end\n'
score "M3 block moved below shipped ret " \
    "sits BELOW the shipped weakest-harasser loop"

# M4 -- the reach comparison is inverted: armed now keeps exactly the targets
# it was written to drop.
sub_or_die "$JMZ" "$REACHCMP" $'\t\t\tif GetUnitToUnitDistance( bot, e ) >= nMyReach\n'
score "M4 reach comparison inverted     " \
    "armed, the helper still answers"

# M5 -- THE CROSS-CHECK LEG.  The guard stops reading the bot's own reach and
# compares against the detection radius instead, so nothing is ever out of
# reach.  hr_closes == hr_fire - hr2_fire still holds (0 == 54-54).
sub_or_die "$JMZ" "$GETRANGE" $'\t\tlocal nMyReach = 1100\n'
score "M5 reach replaced by 1100 const  " \
    "the two independent counts of out-of-reach fires disagree"

# M6 -- the fall-through is replaced by "attack someone anyway", which is the
# behaviour the id exists to remove.
sub_or_die "$JMZ" "$FALLTHRU" $'\t\tif hInReach == nil then hInReach = tValid[1] end\n'
score "M6 fall-through becomes any tgt  " \
    "the two independent counts of out-of-reach fires disagree"

# M7 -- COUNT BLIND.  Every frame in this corpus is a range stub, so an
# unconditional bump leaves the manifest byte-identical.  Catchable only
# because a source pin was added in the same round.
sub_or_die "$SWEEP" "$SWEEP_STUB" $'                        bump(\'hr_range_stub\')\n'
score "M7 stub column becomes a bump    " \
    "no longer tests the stub value"

# M8 -- THE RATCHET.  Re-aimed 2026-09-09, when the round that priced the
# asymmetry here landed the repair as the gated id 'hrparity': this mutant is
# now "the repair leaves its gate and becomes the shipped default", i.e. an
# accidental promote.  The leg is unchanged because the edit is the same edit --
# what changed is which mistake it stands for.
sub_or_die "$JMZ" "$ALLYR" $'\tlocal tAllies = J.GetNearbyHeroes( bot, 1100, false, BOT_MODE_NONE )\n\tlocal nOurs = 1 + ( tAllies ~= nil and #tAllies or 0 )\n'
score "M8 asymmetry silently repaired   " \
    "no longer reads enemies at 1100 and allies at 900"

# M9 -- ZERO-VALUED COLUMN, varied by POLARITY not by name (renaming the bump
# of a branch that never executes is an equivalent mutant).
sub_or_die "$SWEEP" "$SWEEP_OPENS" $'                            if sResp == \'fire\' and s2 ~= \'fire\' then\n                                bump(\'hr_opens\')\n                            end\n'
score "M9 hr_opens polarity flipped     " \
    "frames gained a \"fire\" when hrreach was armed"

# M10 -- CONTROL.  A comment-only edit must survive.
sub_or_die "$JMZ" "$HDR" $'-- soak candidate \'hrreach\' (2026-09-09), which narrows that branch\'s set\n'
score_control "M10 comment-only edit (control)  "

# ---------------------------------------------------------------------------
echo
echo "=== stand summary ==="
echo "legs=$TOTAL  caught=$CAUGHT  survived=$SURVIVED"
if [ "$SURVIVED" -eq 0 ]; then
    echo "STAND GREEN -- every mutant is visible to tests/test_hrreach_guard.lua"
    exit 0
fi
echo "STAND RED -- $SURVIVED mutant(s) are invisible; the readings above are"
echo "             not yet defended by an assertion that would notice them."
exit 1
