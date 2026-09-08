#!/usr/bin/env bash
# Mutation stand for 'tprecov' -- "the fourth home-TP branch is the only one of
# the four with no regen veto, and the obvious fix for it is a no-op by closed
# form" (strategy, 2026-09-08, OWNER_PRIORITIES P2 + P4.4(i)).
# Run by hand when J.ShouldSipNotTpRecover, its call site in the '回复状态'
# branch of X.ConsiderItemDesire["item_tpscroll"], or
# tests/test_tprecov_recover_trip.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_tpstamp.sh):
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
# WHAT THIS STAND IS FOR.  Three of the nine are the reason it exists:
#   * M5 IS THE WRONG-BUT-GREEN IMPLEMENTATION.  It routes the helper through
#     J.ShouldRegenNotGoHome -- the family's own predicate, the reading any
#     reviewer would call the obvious one.  On the pinned frame it answers
#     IDENTICALLY (that frame clears IsFieldRegenSituation too), so every
#     behavioural assertion in the file stays green.  What it changes is
#     invisible from a fixture: J.IsFieldSipEnough ('fieldsip', ARMED in the
#     current member string) then demands FieldRegenSipValue >= 0.25*MaxHealth,
#     and with the flask excluded by the branch's own `itemFlask == nil` that
#     caps at 135 -- i.e. MaxHealth <= 540, impossible under `GetLevel() >= 6`.
#     M5 is a lever that measures EMPTY on the string the lab is running while
#     reading correct in review.  It is caught by the ALL-ON leg of the
#     single-arm attribution test -- with every id armed the routed helper goes
#     SILENT on the pinned frame, because `fieldsip` inside it demands a sip the
#     branch's own `itemFlask == nil` has already made unreachable.  That is the
#     emptiness DEMONSTRATED rather than asserted, which is why the stand quotes
#     that message and not the structural one (the structural pin is still
#     there and would catch it too, one assertion later).
#   * M6 AND M7 ARE THE CLAUSES THE CORPUS CANNOT DEFEND.  The 0.18 floor stops
#     29 of the 31 trigger frames BEFORE the supply and attributed-damage
#     clauses are reached, so deleting either leaves every corpus counter in the
#     test file byte-identical.  If the individual clause pins were dropped for
#     being "redundant with the domain count", these two would survive.
#   * M9 IS THE NARROWING/OFF-SWITCH CONTROL, and it is the lanefix lesson: a
#     helper that answers TRUE for everything passes the POSITIVE frame test
#     (the pinned frame is held) and only the NEGATIVE control can tell "this
#     narrows the branch" from "this disables the branch".
#
# Usage: bash tools/agent/mutstand_tprecov.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
AIUG=bots/ability_item_usage_generic.lua
TEST=tests/test_tprecov_recover_trip.lua

FILES=("$JMZ" "$AIUG" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tprecov.XXXXXX")
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
    lua5.1 tests/run_tests.lua tprecov > "$WORK/run.log" 2>&1
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

# An anchor failure must never be reported as a surviving mutant: without this
# wrapper `sub` aborts, the mutant never lands, and the leg runs the BASELINE and
# scores SURVIVED (measured on this stand's first run -- M3 and M4 both).
sub_or_die() {
    sub "$@" || { echo "ANCHOR FAILURE -- stand aborted, nothing below is meaningful"; exit 3; }
}

# Anchors are LITERAL and must be UNIQUE.  Two of the single-line ones are not:
# `if not J.IsModeTurbo() then return false end` occurs 29 times in this file and
# the supply/ring lines occur 2 and 3 times (J.ShouldRegenNotGoHome and
# J.IsFieldRegenSituation use the same words), so those are widened with their
# neighbouring line.  This is GH #550, and it bit on this stand's first run: the
# ambiguous anchor aborted `sub`, the mutant never landed, and the leg scored
# SURVIVED on an unmutated tree.  Hence the `|| exit 3` after every sub below --
# an anchor failure now ABORTS the stand instead of being reported as a hole.
GATEPAIR=$'\tif not J.IsSoakCandidate( \'tprecov\' ) then return false end\n\tif not J.IsModeTurbo() then return false end\n'
GATEONLY=$'\tif not J.IsSoakCandidate( \'tprecov\' ) then return false end\n'
FLOOR=$'\tif J.GetHP( bot ) < 0.18 then return false end\n'
SOURCE=$'\tif not J.HasFieldRegenSource( bot ) then return false end\n\n\t-- Attributed danger'
ATTRIB=$'\tif bot:WasRecentlyDamagedByAnyHero( 3.0 )\n\t\tand J.HasNearbyHeroDamager( bot, 3000, 3.0 )\n\tthen\n\t\treturn false\n\tend\n'
TAIL=$'\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end\n\n\treturn true\nend'
CALL=$'\t\t\tand not J.ShouldSipNotTpRecover( bot )\n'

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
# M1: the call site is deleted.  The plainest way this lever becomes a dead
#     helper that still passes review -- the branch goes back to being the one
#     of four with no regen veto at all.
echo
echo "=== M1: the call site is deleted from the 回复状态 branch ==="
sub_or_die "$AIUG" "$CALL" ""
score "M1" "no longer carries J.ShouldSipNotTpRecover"

# ---------------------------------------------------------------------------
# M2: the candidate check is dropped.  A defaults change wearing a candidate's
#     name -- the veto would then be live in every shipped turbo game.
echo
echo "=== M2: the helper stops asking whether the candidate is armed ==="
sub_or_die "$JMZ" "$GATEPAIR" $'\tif not J.IsModeTurbo() then return false end\n'
score "M2" "UNARMED the helper answers TRUE"

# ---------------------------------------------------------------------------
# M3: turbo-only is dropped, the candidate check kept.  The narrower half of M2.
echo
echo "=== M3: the turbo guard is dropped, the candidate check kept ==="
sub_or_die "$JMZ" "$GATEPAIR" "$GATEONLY"
score "M3" "no longer gate-first-then-turbo"

# ---------------------------------------------------------------------------
# M4: the gate is moved BELOW every read.  The helper still contains the gate
#     and exactly one id -- a grep, and check_armed_wiring.py, still answer
#     "gated" -- while an unarmed shipped game now evaluates J.GetHP,
#     J.HasFieldRegenSource and two engine scans on every call.
echo
echo "=== M4: the gate is moved BELOW every read ==="
sub_or_die "$JMZ" "$GATEPAIR" $'\tif not J.IsModeTurbo() then return false end\n'
sub_or_die "$JMZ" "$TAIL" $'\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end\n\n'"$GATEONLY"$'\treturn true\nend'
score "M4" "no longer gate-first-then-turbo"

# ---------------------------------------------------------------------------
# M5: THE WRONG-BUT-GREEN IMPLEMENTATION.  Route through the family's own
#     predicate.  Identical answer on the pinned frame; EMPTY on the armed
#     string the lab is running, because J.IsFieldSipEnough rides inside it.
echo
echo "=== M5: the helper is routed through J.ShouldRegenNotGoHome ==="
sub_or_die "$JMZ" "$SOURCE" $'\tif not J.ShouldRegenNotGoHome( bot ) then return false end\n\n\t-- Attributed danger'
score "M5" "an inner id has turned this lever off"

# ---------------------------------------------------------------------------
# M6: the supply read is deleted.  The helper would then hold an EMPTY-HANDED
#     bot in the field -- the supply side's domain, not this lever's.  Every
#     corpus counter in the test file is unchanged by this (the floor stops the
#     29 frames before this clause is reached), so only the clause pin sees it.
echo
echo "=== M6: the supply read (HasFieldRegenSource) is deleted ==="
sub_or_die "$JMZ" "$SOURCE" $'\n\t-- Attributed danger'
score "M6" "no longer asks J.HasFieldRegenSource"

# ---------------------------------------------------------------------------
# M7: the ATTRIBUTED danger read becomes the unattributed one -- i.e. exactly
#     the shipped defect 'stayattr' exists to remove, reproduced one function
#     over.  Also invisible to every corpus counter here.
echo
echo "=== M7: the danger read loses its attribution ==="
sub_or_die "$JMZ" "$ATTRIB" $'\tif bot:WasRecentlyDamagedByAnyHero( 3.0 )\n\tthen\n\t\treturn false\n\tend\n'
score "M7" "no longer reads damage the ATTRIBUTED way"

# ---------------------------------------------------------------------------
# M8: the family's floor is deleted.  This is the one clause a later round is
#     most likely to "widen" on purpose (29 of 31 trigger frames sit below it),
#     so it has to go red loudly rather than quietly change what the lever is.
echo
echo "=== M8: the 0.18 floor is deleted ==="
sub_or_die "$JMZ" "$FLOOR" ""
score "M8" "HP floor"

# ---------------------------------------------------------------------------
# M9: THE OFF-SWITCH.  Everything after the gates is short-circuited to `true`.
#     The pinned frame is still held, so the POSITIVE test passes; only the
#     negative control can tell a narrowing from a disabled branch.
echo
echo "=== M9: the helper becomes an unconditional hold ==="
sub_or_die "$JMZ" "$GATEPAIR" "$GATEPAIR"$'\tif true then return true end\n'
score "M9" "behaving as an off switch"

# ---------------------------------------------------------------------------
echo
echo "=== summary ==="
echo "CAUGHT $CAUGHT / $TOTAL"
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "AT LEAST ONE MUTANT SURVIVED -- the pin has a hole; fix the test, not this file"
    exit 3
fi
echo "no survivors"
