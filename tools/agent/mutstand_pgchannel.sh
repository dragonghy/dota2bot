#!/usr/bin/env bash
# Mutation stand for the `pgchannel` candidate -- the retreat-desire veto that
# holds a TP channel instead of cancelling it with a move order (strategy,
# 2026-09-07, OWNER_PRIORITIES P4.4(i)).  Run by hand when
# J.ShouldLetTpChannelFinish, its call site in mode_retreat_generic.lua, or
# tests/test_pgchannel_veto.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmrangedhp.sh):
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
# WHAT THIS STAND IS FOR.  Three of the eight are worth reading:
#   * M6 IS THE ONE THIS LEVER EXISTS BECAUSE OF.  It moves the veto from above
#     the guard chain to inside it, directly under the pushguard floor -- which
#     is the shape the first draft of this fix had.  That draft was measured to
#     be a NO-OP on its own witnessed frame (0.92 -> 0.75, the next live floor
#     taking over), and every gate-plumbing assertion in the file passes on it.
#     If M6 survives, this stand is certifying the exact mistake the round was
#     spent finding.
#   * M8 is a control on the REAL-FRAME READ.  Section "shipped floors a
#     just-started channel at the pushguard 0.92" claims to be driving the real
#     mode_retreat_generic chain.  Move that floor's constant by 0.01: if the
#     test stays green it was asserting a number it had written down, not one it
#     had measured.
#   * M7 is a control on the DOMAIN LIMIT.  The veto's whole safety argument is
#     that it only ever fires mid-channel.  Delete the modifier test and the
#     helper answers true on every turbo frame; only the negative-control frames
#     can see that, and if they cannot, "domain-limited" is prose.
#
# Usage: bash tools/agent/mutstand_pgchannel.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
RETREAT=bots/mode_retreat_generic.lua
TEST=tests/test_pgchannel_veto.lua

FILES=("$JMZ" "$RETREAT" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_pgchan.XXXXXX")
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

# The filter is `pgchannel`, and the retreat-chain ordering test is run beside
# it: this lever edits that chain's file, and a stand blind to the invariant
# that file carries would report a broken ordering as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua pgchannel > "$WORK/run.log" 2>&1
    local rc=$?
    lua5.1 tests/run_tests.lua retreat_priority >> "$WORK/run.log" 2>&1
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

HEAD=$'function J.ShouldLetTpChannelFinish( bot )\n\tif not J.IsModeTurbo() then return false end\n\tif not J.IsSoakCandidate( \'pgchannel\' ) then return false end\n'
CHAN=$'\tif not bot:HasModifier( \'modifier_teleporting\' ) then return false end\n'
BURST=$'\tif J.IsIncomingBurstLethal( bot, 3.0 ) then return false end\n'
TPWATCH=$'\tif J.ShouldAbandonTpChannel( bot ) then return false end\n'
RET=$'\tif J.ShouldAbandonTpChannel( bot ) then return false end\n\treturn true\nend'
VETO=$'    if J.ShouldLetTpChannelFinish(bot) then\n        return BOT_MODE_DESIRE_NONE\n    end\n'
PGFLOOR=$'    if J.ShouldAbortDeepSoloPush(bot) then\n        return 0.92\n    end\n'

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
# M1: the candidate check is dropped.  A defaults change wearing a candidate's
#     name -- the veto would be live in every turbo game.
echo
echo "=== M1: the helper stops asking whether the candidate is armed ==="
sub "$JMZ" "$HEAD" $'function J.ShouldLetTpChannelFinish( bot )\n\tif not J.IsModeTurbo() then return false end\n'
score "M1" "no longer carries its own pgchannel gate"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$JMZ" "$HEAD" $'function J.ShouldLetTpChannelFinish( bot )\n\tif not J.IsSoakCandidate( \'pgchannel\' ) then return false end\n'
score "M2" "no longer turbo-only"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  Helper, id, gate and call site all survive review
#     while the armed answer is byte-for-byte the shipped one.  Only the
#     real-frame reading can tell this apart from the fix.
echo
echo "=== M3: the helper answers false on every frame (dead wiring) ==="
sub "$JMZ" "$RET" $'\tif J.ShouldAbandonTpChannel( bot ) then return false end\n\treturn false\nend'
score "M3" "not the NONE the veto returns"

# ---------------------------------------------------------------------------
# M4: the LIVE release is deleted.  The veto then holds a channel whose owner
#     the visible enemies can already kill inside the channel window.
echo
echo "=== M4: the lethal-incoming-burst release is deleted ==="
sub "$JMZ" "$BURST" ""
score "M4" "LIVE release (lethal incoming burst) is gone"

# ---------------------------------------------------------------------------
# M5: the deference to tpwatch is deleted.  Inert today, load-bearing the day
#     that id is armed -- and its absence is exactly what a reader would miss.
echo
echo "=== M5: the deference to tpwatch is deleted ==="
sub "$JMZ" "$TPWATCH" ""
score "M5" "deference to tpwatch is gone"

# ---------------------------------------------------------------------------
# M6: THE FIRST DRAFT.  The veto is moved from above the chain to inside it,
#     under the pushguard floor.  Measured no-op; every gate assertion passes.
echo
echo "=== M6: the veto is moved INSIDE the chain, below the pushguard floor ==="
sub "$RETREAT" "$VETO" ""
sub "$RETREAT" "$PGFLOOR" "$PGFLOOR$VETO"
score "M6" "moved INSIDE the retreat"

# ---------------------------------------------------------------------------
# M7: the domain limit is deleted -- the helper stops reading the channel and
#     answers true on every armed turbo frame.  Only the negative controls see it.
echo
echo "=== M7: the helper stops reading modifier_teleporting ==="
sub "$JMZ" "$CHAN" ""
score "M7" "veto has leaked outside its domain"

# ---------------------------------------------------------------------------
# M8: a control on the real-frame read.  Move the pushguard floor by 0.01.  If
#     the shipped-value assertion stays green it was reciting, not measuring.
echo
echo "=== M8: the pushguard floor constant is moved 0.92 -> 0.93 ==="
sub "$RETREAT" "$PGFLOOR" $'    if J.ShouldAbortDeepSoloPush(bot) then\n        return 0.93\n    end\n'
score "M8" "not the 0.92"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ]
exit $?
