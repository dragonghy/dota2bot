#!/usr/bin/env bash
# Mutation stand for tests/test_gated_helper_liveness.lua -- the detector that
# turns red when a J.* helper carrying its own soak gate loses its last call
# site (strategy 2026-09-07, GH #600 / GH #601).  Run by hand when that test,
# its EXEMPT list, or the two restored vetoes in mode_retreat_generic.lua are
# edited, and before quoting any of its readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_pgchannel.sh):
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
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507).
#
# WHAT THIS STAND IS FOR.  Three of the seven are worth reading:
#   * M1 IS THE DEFECT ITSELF, replayed: it restores `8b25217e`'s one-line diff
#     (the pgchannel veto written OVER the stayfield2 veto's condition, same
#     body, same token).  If M1 survives, this whole round bought nothing --
#     the detector would be blind to the accident it was built for.
#   * M4 is the control on the EXTRACTOR.  A census whose parser breaks reads
#     CLEAN, and clean is this file's published answer, so a mutant that makes
#     gated_helpers() see nothing must be caught by the floor rather than
#     applauded as a green tree.
#   * M7 is the control on the SOURCE leg.  Swapping the two vetoes' order is
#     behaviourally free (both answer NONE), which is exactly why it must be
#     pinned: without that leg, a future REPLACEMENT could again present itself
#     as a reordering and nothing would count the difference.
#
# Usage: bash tools/agent/mutstand_gated_helper_liveness.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
RETREAT=bots/mode_retreat_generic.lua
TEST=tests/test_gated_helper_liveness.lua

FILES=("$JMZ" "$RETREAT" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ghl.XXXXXX")
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

# The filter is `gated_helper`, which picks up both this detector and the
# nesting census beside it: the two share a stripper and a body-extraction
# convention, and a stand blind to the census would report a broken shared
# assumption as SURVIVED.  The stayfield call-site file is run too -- it is the
# id-specific detector that actually caught the live defect, and a mutant that
# silenced it while leaving this file green would be the worst outcome here.
run_tests() {
    lua5.1 tests/run_tests.lua gated_helper > "$WORK/run.log" 2>&1
    local rc=$?
    lua5.1 tests/run_tests.lua stayfield_callsite >> "$WORK/run.log" 2>&1
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

STAY=$'    if J.ShouldRegenNotWalkHome(bot) then\n        return BOT_MODE_DESIRE_NONE\n    end\n'
PGCH=$'    if J.ShouldLetTpChannelFinish(bot) then\n        return BOT_MODE_DESIRE_NONE\n    end\n'
EXEMPT_LANEFIX=$'    [\'J.IsLaneFixActive\'] = true,\n'
FLOOR=$'    assert(n >= 40,'
BODYEND=$'            while j <= #lines and lines[j]:gsub(\'%s+$\', \'\') ~= \'end\' do j = j + 1 end\n'
GATEWORD=$'            if body:find(\'IsSoakCandidate\', 1, true) then\n'
DEFSUB=$'             - select(2, code:gsub(\'function%s+J%.\' .. short .. \'%s*%(\', \'\'))\n'

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
# M1: THE DEFECT, REPLAYED.  8b25217e's exact one-line diff: delete the
#     stayfield2 veto and keep the pgchannel one.  Same body, same token, and
#     the ten-line stayfield2 comment stays above it.
echo
echo "=== M1: the stayfield2 veto is deleted again (the 8b25217e diff) ==="
sub "$RETREAT" "$STAY" ""
score "M1" "lost its last call site"

# ---------------------------------------------------------------------------
# M2: the OTHER direction of the same swap -- the pgchannel veto is the one
#     deleted.  Its id is not in the armed string today, so nothing measuring
#     waves would notice; the detector must still name it.
echo
echo "=== M2: the pgchannel veto is deleted instead ==="
sub "$RETREAT" "$PGCH" ""
score "M2" "lost its last call site"

# ---------------------------------------------------------------------------
# M3: an EXEMPT row is dropped while the tree is unchanged.  Scores the claim
#     that the exemption list is READ, not decoration: without it the first
#     assertion would be passing on two helpers nobody has looked at.
echo
echo "=== M3: the 'lanefix' exemption row is dropped ==="
sub "$TEST" "$EXEMPT_LANEFIX" ""
score "M3" "lost its last call site"

# ---------------------------------------------------------------------------
# M4: THE EXTRACTOR CONTROL.  Make the gate word unmatchable: gated_helpers()
#     then returns nothing, dead() returns nothing, and every liveness
#     assertion passes vacuously.  Only the floor can see this.
echo
echo "=== M4: the extractor stops recognising the gate word ==="
sub "$TEST" "$GATEWORD" $'            if body:find(\'IsSoakCandidateZZZ\', 1, true) then\n'
score "M4" "the extractor stopped seeing them"

# ---------------------------------------------------------------------------
# M5: M4 AGAIN WITH THE FLOOR DEFEATED.  M4 alone is caught by one assertion,
#     and a stand that stops there is certifying a single point of failure on
#     the mutant that matters most (a parser reading nothing publishes "clean").
#     So break the extractor AND lower its floor to zero in the same mutant:
#     what is left to catch it is the embedded positive control, which is the
#     property that makes this file more than a register.
#     (The floor alone is deliberately NOT a mutant here -- moving 40 to 0 on an
#     intact extractor changes no answer, and scoring it would inflate the
#     denominator with a mutant that is correct to survive.)
echo
echo "=== M5: the extractor is broken AND its floor lowered to zero ==="
sub "$TEST" "$GATEWORD" $'            if body:find(\'IsSoakCandidateZZZ\', 1, true) then\n'
sub "$TEST" "$FLOOR" $'    assert(n >= 0,'
score "M5" "it cannot see the defect it exists for"

# ---------------------------------------------------------------------------
# M6: the definition is no longer subtracted from the call count, so every
#     gated helper looks called (by itself) and the dead set is always empty.
#     The subtlest mutant here: the file stays green on the real tree AND on
#     M1's tree, so only the embedded positive control can catch it.
echo
echo "=== M6: the helper's own definition counts as a call site ==="
sub "$TEST" "$DEFSUB" $'             - 0\n'
score "M6" "it cannot see the defect it exists for"

# ---------------------------------------------------------------------------
# M7: THE ORDER CONTROL.  Swap the two vetoes.  Behaviourally free -- both
#     answer NONE -- which is why a replacement could once again read as a
#     reordering if this leg cannot see it.
echo
echo "=== M7: the two vetoes swap places ==="
sub "$RETREAT" "$STAY" ""
sub "$RETREAT" "$PGCH" "$PGCH$STAY"
score "M7" "the two vetoes swapped order"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ]
exit $?
