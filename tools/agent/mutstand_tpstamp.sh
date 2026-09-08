#!/usr/bin/env bash
# Mutation stand for the hoisted TP-channel baseline stamp -- "the guard that
# measures damage during a channel was measuring from wherever the chain
# happened to stop" (strategy, 2026-09-08, OWNER_PRIORITIES P4.4(i), GH #607).
# Run by hand when J.StampTpChannelHealth, its call site in
# mode_retreat_generic.GetDesireHelper, or
# tests/test_tpstamp_channel_baseline.lua are edited, and before quoting any of
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
# WHAT THIS STAND IS FOR.  Four of the nine are the reason it exists:
#   * M3 IS THE DEFECT ITSELF, PUT BACK.  The call is moved from above the
#     early-outs down to the bottom of the guard chain -- exactly where the
#     shipped stamp already lives.  Helper, id, gate and call site all still
#     read correct; only the real-frame witnesses can tell it from the fix.
#     If M3 survives, this stand is certifying a no-op.
#   * M4 IS THE HALF-MOVE, and it is the subtler one.  The call goes below the
#     modifier blocklist early-out but stays above the chain: the positive
#     controls still pass (neither witness returns there), and only the
#     placement pin sees it.  A frame that returns at that early-out is hidden
#     from the stamp again, silently.
#   * M7 TURNS THE STAMP INTO AN UNCONDITIONAL RE-WRITE.  The baseline then
#     tracks the hero's health downward and the difference is always ~0, so
#     `tpwatch` never fires -- while every gate, id and call site still reads
#     correct and the stamp is demonstrably "present" on all 23 frames.  This is
#     the mutant that a stamped/not-stamped reading alone cannot see, which is
#     why the direction assertion exists at all.
#   * M9 IS THE MUST-NOT-FIRE CONTROL.  It gives the record-only stamp a damage
#     condition -- a change that looks like a narrowing and reads defensible,
#     and which reproduces the original defect one level down: the stamp again
#     only happens on some frames of the channel, just chosen differently.
#
# Usage: bash tools/agent/mutstand_tpstamp.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
RET=bots/mode_retreat_generic.lua
TEST=tests/test_tpstamp_channel_baseline.lua

FILES=("$JMZ" "$RET" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tpstamp.XXXXXX")
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

# The filter is `tpstamp`, and the pgchannel veto is run beside it: this lever
# edits the same two files and the same retreat chain, and a mutant that moves
# the call site must not be allowed to break that lever unnoticed.
run_tests() {
    lua5.1 tests/run_tests.lua tpstamp > "$WORK/run.log" 2>&1
    local rc=$?
    lua5.1 tests/run_tests.lua pgchannel_veto >> "$WORK/run.log" 2>&1
    local rc2=$?
    [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ]
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

GATES=$'\tif not J.IsModeTurbo() then return end\n\tif not J.IsSoakCandidate( \'tpwatch\' ) then return end\n\tif bot == nil or not bot:IsAlive() then return end\n'
CLEAR=$'\tif not bot:HasModifier( \'modifier_teleporting\' ) then\n\t\tbot.tpChannelStartHealth = nil\n\t\treturn\n\tend\n'
WRITE=$'\tif bot.tpChannelStartHealth == nil then\n\t\tbot.tpChannelStartHealth = bot:GetHealth()\n\tend\nend'
CALL=$'    J.StampTpChannelHealth(bot)\n'
# The last line of the guard chain's own tpwatch call -- the bottom of the
# chain, where the shipped stamp already happens.
CHAINCALL=$'    if J.ShouldAbandonTpChannel(bot) then\n        return BOT_MODE_DESIRE_VERYHIGH\n    end'
# The first statement AFTER the modifier blocklist early-out.  M4 puts the call
# here, i.e. genuinely past that block.  (An earlier draft of M4 inserted the
# call immediately ABOVE the early-out's own opening line and scored SURVIVED --
# correctly: it had not moved the call at all.  A mutant that does nothing is
# not a hole in the pin.)
BELOWEARLY=$'    botHP          = J.GetHP(bot)'

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
# M1: the call site is deleted outright.  The plainest way this lever becomes a
#     dead helper that still passes review.
echo
echo "=== M1: the record-only call site is deleted ==="
sub "$RET" "$CALL" ""
score "M1" "the record-only stamp call is gone from mode_retreat_generic"

# ---------------------------------------------------------------------------
# M2: the candidate check is dropped.  A defaults change wearing a candidate's
#     name -- the stamp would then be written in every shipped turbo game.
echo
echo "=== M2: the stamp stops asking whether the candidate is armed ==="
sub "$JMZ" "$GATES" $'\tif not J.IsModeTurbo() then return end\n\tif bot == nil or not bot:IsAlive() then return end\n'
score "M2" "touched the stamp with its id unarmed"

# ---------------------------------------------------------------------------
# M3: THE DEFECT ITSELF, PUT BACK.  The call moves to the BOTTOM of the guard
#     chain, beside the shipped tpwatch call -- which is exactly where the
#     stamp already effectively happens.  Everything still reads correct; the
#     lever is a no-op.
echo
echo "=== M3: the call is moved to the BOTTOM of the guard chain ==="
sub "$RET" "$CALL" ""
sub "$RET" "$CHAINCALL" $'    J.StampTpChannelHealth(bot)\n    if J.ShouldAbandonTpChannel(bot) then\n        return BOT_MODE_DESIRE_VERYHIGH\n    end'
score "M3" "tpwatch armed still leaves no baseline"

# ---------------------------------------------------------------------------
# M4: THE HALF-MOVE.  Below the modifier blocklist early-out, above the chain.
#     Neither witness returns at that early-out, so every behavioural assertion
#     still passes -- only the placement pin can see it.
echo
echo "=== M4: the call is moved BELOW the early-out block ==="
sub "$RET" "$CALL" ""
sub "$RET" "$BELOWEARLY" $'    J.StampTpChannelHealth(bot)\n\n    botHP          = J.GetHP(bot)'
score "M4" "has moved BELOW"

# ---------------------------------------------------------------------------
# M5: turbo-only is dropped, the candidate check kept.  The narrower half of M2.
echo
echo "=== M5: the turbo guard is dropped, the candidate check kept ==="
sub "$JMZ" "$GATES" $'\tif not J.IsSoakCandidate( \'tpwatch\' ) then return end\n\tif bot == nil or not bot:IsAlive() then return end\n'
score "M5" "the stamp lost its turbo gate"

# ---------------------------------------------------------------------------
# M6: the gates are moved BELOW the write.  The helper still contains both
#     gates and both ids -- a grep, and check_armed_wiring.py, still answer
#     "gated" -- while the write happens on every shipped frame.
echo
echo "=== M6: both gates are moved BELOW the write ==="
sub "$JMZ" "$GATES$CLEAR$WRITE" $'\tif bot == nil or not bot:IsAlive() then return end\n'"$CLEAR"$'\tif bot.tpChannelStartHealth == nil then\n\t\tbot.tpChannelStartHealth = bot:GetHealth()\n\tend\n\tif not J.IsModeTurbo() then return end\n\tif not J.IsSoakCandidate( \'tpwatch\' ) then return end\nend'
score "M6" "touched the stamp with its id unarmed"

# ---------------------------------------------------------------------------
# M7: THE UNCONDITIONAL RE-WRITE.  Drop the nil guard so the baseline follows
#     the hero's health down.  The stamp is then "present" on all 23 frames --
#     a stamped/not-stamped census reads BETTER -- while the difference the
#     guard measures is always ~0 and tpwatch can never fire.
echo
echo "=== M7: the stamp is re-written every frame (baseline decays) ==="
sub "$JMZ" "$WRITE" $'\tbot.tpChannelStartHealth = bot:GetHealth()\nend'
score "M7" "no longer guards its write with a nil test"

# ---------------------------------------------------------------------------
# M8: the clear-on-no-channel is deleted.  A baseline from a previous channel
#     survives into the next one, so the guard measures against a health the
#     hero had minutes ago -- it would fire early and often, the opposite bias.
echo
echo "=== M8: the stale baseline is never cleared ==="
sub "$JMZ" "$CLEAR" $'\tif not bot:HasModifier( \'modifier_teleporting\' ) then\n\t\treturn\n\tend\n'
score "M8" "a stale baseline survived a non-channeling frame"

# ---------------------------------------------------------------------------
# M9: MUST-NOT-FIRE CONTROL.  Give the record-only stamp a damage condition.  It
#     reads like a narrowing and would pass review; it reproduces the original
#     defect one level down -- the stamp again happens only on SOME frames of
#     the channel, and those frames are by construction ones where damage has
#     already landed, i.e. the baseline is depressed exactly as before.
echo
echo "=== M9: the record-only stamp grows a damage condition ==="
# The nil test is kept LITERALLY intact on purpose: otherwise M9 trips the
# nil-guard assertion (M7's detector) and the stand would be reporting M7's
# finding under M9's name.  The mutant has to leave every other claim true so
# that the damage condition is the only thing left to see it.
sub "$JMZ" "$WRITE" $'\tif bot.tpChannelStartHealth == nil then\n\t\tif bot:WasRecentlyDamagedByAnyHero( 1.5 ) then\n\t\t\tbot.tpChannelStartHealth = bot:GetHealth()\n\t\tend\n\tend\nend'
score "M9" "has grown a damage condition"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
