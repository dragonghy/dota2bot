#!/usr/bin/env bash
# Mutation stand for the `zusultstrand` candidate -- the retreat branch of Zeus's
# X.ConsiderR is guarded by `bot:GetRespawnTime() > abilityR:GetCooldown()`, a
# conjunct whose right-hand side is a flat 130 and whose left-hand side cannot
# exceed 75 in turbo (hero, 2026-09-06, OWNER_PRIORITIES P4.4).  Run by hand when
# X.zuus_ShouldCashUltBeforeDeath, X.ConsiderR or
# tests/test_zuus_ult_strand.lua are edited, and before quoting any of that
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
# WHAT THIS STAND IS FOR.  Four of the nine are directional or instrumental
# rather than cosmetic, and they are the ones worth reading:
#   * M5 IS THE ONE THAT MOVES THE PREMISE.  The whole round rests on a single
#     falsifiable sentence -- "the ult's cooldown strictly exceeds every respawn
#     ceiling" -- and NOTHING that asserts on the helper's answers can see it
#     move.  M5 drops the declared cooldown under the ceiling; only section 2,
#     which reads the KV snapshot and jmz_func's own GH #215 block instead of
#     re-typing 130 and 75, goes red.
#   * M7 IS THE VACUITY CONTROL, and this lever needs one more than most.  Every
#     `false` section 3 records could equally be produced by a comparison that
#     ignores its inputs; that is precisely how a structurally-dead conjunct
#     looks from the outside.  M7 makes the shipped expression constant-false
#     and section 4's labelled 131 injection is the only thing that notices.
#   * M8 IS THE BLANK-CHEQUE CONTROL.  This lever is a WIDENING: the shipped
#     conjunct is structurally false, so arming can only ADD casts.  The one
#     thing keeping it narrow is the chaser radius.  Drop it and the branch
#     cashes a 250-500 mana ultimate at every low-HP retreat.
#   * M6 is a control on the REAL-FRAME READ.  Section 3's claim is that the 130
#     comes off the real handle on each fixture.  Point the handle at a sibling
#     ability that declares no AbilityCooldown: if section 3 stays green, it was
#     reading a blanket mock answer rather than this ability.
#
# Usage: bash tools/agent/mutstand_zusultstrand.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_zuus.lua
TEST=tests/test_zuus_ult_strand.lua
KV=tests/mock/special_value_shapes.lua

FILES=("$HERO" "$TEST" "$KV")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zus.XXXXXX")
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
# hero's bolt block, its mana budget and its talent rows, and a stand scoped to
# the new file alone would report a collision there as SURVIVED.
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

GATE_LINE=$'\tif not ( J.IsModeTurbo() and J.IsSoakCandidate( \'zusultstrand\' ) ) then return false end'
SHIPPED=$'\tlocal bShipped = hBot:GetRespawnTime() > abilityR:GetCooldown()'
CHASER=$'\tif tChasers == nil or #tChasers == 0 then return false end'
CALL_SITE=$'\t\tif X.zuus_ShouldCashUltBeforeDeath( bot )'
RADIUS='X.nUltCashChaseRadius = 1600'
KV_COOLDOWN=$'            [\'AbilityCooldown\'] = { base = \'130\', bonus = {  } },\n            [\'AbilityManaCost\'] = { base = \'250 375 500\', bonus = {  } },'

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
# M1: the candidate check is dropped.  The widening becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name, and on
#     a WIDENING that means new ult casts in live games.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsModeTurbo() ) then return false end'
score "M1" "gate-off answered"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1,
#     and the one that reaches the normal-mode window the header explicitly
#     refuses to touch (level-25 Octarine, 97.5s < 100s).
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE_LINE" $'\tif not ( J.IsSoakCandidate( \'zusultstrand\' ) ) then return false end'
score "M2" "fired outside turbo"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  Helper, id, gate and call site all survive review
#     while the armed answer is byte-for-byte the shipped one.  The lever is then
#     inert in every wave and the verdict reads back "tested, no effect" with
#     nothing raising a hand (GH #531's third shape).
echo
echo "=== M3: the armed branch answers exactly what shipped answers ==="
sub "$HERO" "$CHASER" $'\tif tChasers ~= nil then return bShipped end'
score "M3" "admitted 0 of the real Zeus frames"

# ---------------------------------------------------------------------------
# M4: the call site reverts to the inline comparison.  The helper, the id and the
#     gate all survive review; only the wire is gone, and `check_armed_wiring.py`'s
#     question ("does a call site exist?") is the one thing this does not answer.
echo
echo "=== M4: the call site inlines the dead comparison again ==="
sub "$HERO" "$CALL_SITE" $'\t\tif bot:GetRespawnTime() > abilityR:GetCooldown()'
score "M4" "still holds the bare"

# ---------------------------------------------------------------------------
# M5: THE PREMISE.  Everything in this round follows from "the ult's cooldown
#     strictly exceeds every respawn ceiling".  Drop the declared cooldown under
#     the turbo ceiling and the conjunct stops being structurally false -- the
#     branch is reachable and the lever is misdiagnosed.  NOTHING that asserts on
#     the helper's answers can see this; only section 2, which reads the KV
#     snapshot and jmz_func's GH #215 block instead of re-typing 130 and 75.
echo
echo "=== M5: the declared ult cooldown drops under the respawn ceiling (the premise) ==="
sub "$KV" "$KV_COOLDOWN" $'            [\'AbilityCooldown\'] = { base = \'70\', bonus = {  } },\n            [\'AbilityManaCost\'] = { base = \'250 375 500\', bonus = {  } },'
score "M5" "is no longer structurally false"

# ---------------------------------------------------------------------------
# M6: a control on the REAL-FRAME READ.  Point section 3's handle at Static
#     Field, which declares no AbilityCooldown at all.  If section 3 stays green,
#     its "the 130 comes off the real handle" claim was reading a blanket mock
#     answer rather than this ability.
echo
echo "=== M6: the real-frame handle is pointed at a sibling ability (instrument control) ==="
# The mutation moves ONLY the handle lookup, not the `ULT` constant: moving the
# constant would also move the frame-naming check and section 2's KV read, and
# the stand would then score section 2's red as if it were section 3's.  A
# mutant that lands somewhere other than the assertion under control is not a
# control (GH #550 in its behavioural form).
sub "$TEST" "    return bot:GetAbilityByName(ULT)" \
            "    return bot:GetAbilityByName('zuus_static_field')"
score "M6" "read 0, not the KV"

# ---------------------------------------------------------------------------
# M7: THE VACUITY CONTROL.  A structurally-dead conjunct and a comparison that
#     ignores its inputs are indistinguishable from the outside -- every `false`
#     section 3 records is consistent with both.  Make the shipped expression
#     constant-false; only section 4's labelled 131 injection notices, which is
#     why that injection exists.
echo
echo "=== M7: the shipped comparison stops reading its inputs (vacuity control) ==="
sub "$HERO" "$SHIPPED" $'\tlocal bShipped = false'
score "M7" "did NOT flip the conjunct"

# ---------------------------------------------------------------------------
# M8: THE BLANK CHEQUE.  This lever is a widening; the chaser radius is the only
#     thing keeping it narrow.  Drop the term and the branch cashes a 250-500
#     mana ultimate at every low-HP retreat, including the ones the bot survives.
echo
echo "=== M8: the armed leg fires with no chaser term at all ==="
sub "$HERO" "$CHASER" $'\tif false then return false end'
score "M8" "7479u away"

# ---------------------------------------------------------------------------
# M9: the radius is inflated past the map.  Softer than M8 and it looks like a
#     tuning choice rather than a deletion, but it is the same blank cheque: a
#     term that admits every frame narrows nothing.  Section 5's two-sided census
#     (both counts must be positive) is what refuses it.
echo
echo "=== M9: the chaser radius is inflated until it admits everything ==="
sub "$HERO" "$RADIUS" 'X.nUltCashChaseRadius = 16000'
score "M9" "admitted EVERY real Zeus frame"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
