#!/usr/bin/env bash
# Mutation stand for the `ohnum` candidate -- "a punish with no building behind
# it needs the numbers, not parity" (strategy, 2026-09-07, OWNER_PRIORITIES
# P4.4(i)).  Run by hand when J.ShouldRefuseUnsupportedPunish, its call site in
# J.ShouldPunishDive, or tests/test_ohnum_refusal.lua are edited, and before
# quoting any of that file's readings.
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
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507) -- the shape that cost the 2026-09-07T17:15Z round three
# false reds it had to re-run statically to disown.
#
# WHAT THIS STAND IS FOR.  Four of the seven are the reason it exists:
#   * M3 IS THE DEAD-WIRING TWIN.  Helper, id, gate and call site all survive
#     review while the armed answer is byte-for-byte the shipped one.  Only the
#     real-frame reading can tell it from the fix.
#   * M4 IS THE PLACEMENT MUTANT, and it is this lever's own near-miss.  It
#     moves the call from the shared commit line INTO the 'ownhalf' branch --
#     the obvious place to put it, and the place that turns the id into
#     `ownhalf AND ohnum`, makes its single-arm zero unreadable, and leaves
#     `check_armed_wiring.py` still answering WIRED.  Every behavioural
#     assertion in the file passes on M4; if it survives, this stand is
#     certifying the exact shape GH #576 / #600 / #607 were filed about.
#   * M5 DELETES THE BUILDING RELEASE, which is the only thing standing between
#     this candidate and the PROMOTED shipped punish.  A stand that cannot see
#     M5 is certifying a silent narrowing of live turbo behaviour.
#   * M6 DELETES THE LETHAL RELEASE.  The corpus cannot witness that release
#     (the mock's GetEstimatedDamageToTarget answers 0 on every frame,
#     `lethal_release 0`), so a source-level mutant is the ONLY control on it.
#     This is the declared substitute for a frame, and it is named as such in
#     tests/test_ohnum_refusal.lua's LIMIT block rather than left implicit.
#
# Usage: bash tools/agent/mutstand_ohnum.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_ohnum_refusal.lua

FILES=("$JMZ" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ohnum.XXXXXX")
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

# The filter is `ohnum`, and the gated-helper nesting census is run beside it:
# this lever adds a gated helper called from a gated caller, and M4's whole
# point is that the census row and the placement must move together.
run_tests() {
    lua5.1 tests/run_tests.lua ohnum > "$WORK/run.log" 2>&1
    local rc=$?
    lua5.1 tests/run_tests.lua gated_helper_nesting_census >> "$WORK/run.log" 2>&1
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

HEAD=$'function J.ShouldRefuseUnsupportedPunish( bot, target )\n\tif not J.IsModeTurbo() then return false end\n\tif not J.IsSoakCandidate( \'ohnum\' ) then return false end\n'
BLDG=$'\tfor _, building in pairs( GetUnitList( UNIT_LIST_ALLIED_BUILDINGS ) or {} )\n\tdo\n\t\tif J.IsValidBuilding( building )\n\t\tand GetUnitToUnitDistance( target, building ) <= 1200\n\t\tthen\n\t\t\treturn false\n\t\tend\n\tend\n'
LETHAL=$'\tif J.GetTotalEstimatedDamageToTarget( tAllies, target )\n\t\t>= target:GetHealth() + target:GetHealthRegen() * 5.0\n\tthen\n\t\treturn false\n\tend\n'
VERDICT=$'\treturn #tAllies < #J.GetEnemiesNearLoc( vLoc, 1200 ) + 1\n'
CALL=$'\t\t\tif bInDomain\n\t\t\tand J.SafeToCommitFight( bot, enemy )\n\t\t\tand not J.ShouldRefuseUnsupportedPunish( bot, enemy )\n\t\t\tthen\n\t\t\t\treturn enemy\n\t\t\tend'
DEPTH=$'\t\t\t\tif nInvadeDepth >= 800 then bInDomain = true end'

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
#     name -- the refusal would narrow the PROMOTED punish in every turbo game.
echo
echo "=== M1: the helper stops asking whether the candidate is armed ==="
sub "$JMZ" "$HEAD" $'function J.ShouldRefuseUnsupportedPunish( bot, target )\n\tif not J.IsModeTurbo() then return false end\n'
score "M1" "no longer carries its own ohnum gate"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$JMZ" "$HEAD" $'function J.ShouldRefuseUnsupportedPunish( bot, target )\n\tif not J.IsSoakCandidate( \'ohnum\' ) then return false end\n'
score "M2" "no longer turbo-only"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  The verdict line is replaced by the constant the
#     un-armed helper already returns, so armed == shipped on every frame while
#     helper, id, gate and call site all still read correct.
echo
echo "=== M3: the helper answers false on every frame (dead wiring) ==="
sub "$JMZ" "$VERDICT" $'\treturn false\n'
score "M3" "the refusal did not fire"

# ---------------------------------------------------------------------------
# M4: THE PLACEMENT MUTANT -- this lever's own near-miss.  The call is moved off
#     the shared commit line and into the 'ownhalf' branch, which makes the
#     lever `ownhalf AND ohnum` and its single-arm zero unreadable.  Every
#     behavioural assertion still passes; only the placement pin can see it.
echo
echo "=== M4: the call is moved INSIDE the ownhalf branch ==="
sub "$JMZ" "$CALL" $'\t\t\tif bInDomain\n\t\t\tand J.SafeToCommitFight( bot, enemy )\n\t\t\tthen\n\t\t\t\treturn enemy\n\t\t\tend'
sub "$JMZ" "$DEPTH" $'\t\t\t\tif nInvadeDepth >= 800\n\t\t\t\tand not J.ShouldRefuseUnsupportedPunish( bot, enemy )\n\t\t\t\tthen bInDomain = true end'
score "M4" "moved off the shared commit line and into the ownhalf branch"

# ---------------------------------------------------------------------------
# M5: the BUILDING release is deleted.  The refusal then reaches the shipped
#     (PROMOTED) punish domain too -- a silent narrowing of live turbo play, and
#     the one mutant whose blast radius is not confined to this candidate.
echo
echo "=== M5: the building release is deleted ==="
sub "$JMZ" "$BLDG" ""
score "M5" "the building release is the only thing standing"

# ---------------------------------------------------------------------------
# M6: the LETHAL release is deleted.  The corpus cannot witness this release at
#     all (mock burst is 0 on every frame), so this source mutant is the ONLY
#     control on it -- a declared substitute for a frame, not a frame.
echo
echo "=== M6: the lethal release is deleted ==="
sub "$JMZ" "$LETHAL" ""
score "M6" "LETHAL release is gone from the helper"

# ---------------------------------------------------------------------------
# M7: a control on the REFUSAL THRESHOLD itself.  Drop the `+ 1` so the helper
#     refuses only when actually outnumbered -- i.e. it accepts parity again,
#     which is the whole defect.  The positive control is the only thing that
#     can see it, and if it cannot, "advantage not parity" is prose.
echo
echo "=== M7: the +1 advantage margin is dropped back to parity ==="
sub "$JMZ" "$VERDICT" $'\treturn #tAllies < #J.GetEnemiesNearLoc( vLoc, 1200 )\n'
score "M7" "the refusal did not fire"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ]
exit $?
