#!/usr/bin/env bash
# Mutation stand for 'tpdeep' -- "the 回复状态 branch fires almost entirely BELOW
# the band the P2 family is allowed to speak in, and the branch proves in its own
# conjuncts that it is not an escape" (strategy, 2026-09-08, OWNER_PRIORITIES P2
# + P4.4(i)).
# Run by hand when J.ShouldDeepSipNotTpRecover, its call site in the '回复状态'
# branch of X.ConsiderItemDesire["item_tpscroll"], or
# tests/test_tpdeep_recover_band.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_tprecov.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a mutant
#     can never score "caught" for having applied to nothing, nor "survived" for
#     having run the baseline (GH #550; it bit the sibling stand on M3/M4).
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507 -- the sibling round's own self-inflicted wound).
#
# WHAT THIS STAND IS FOR.  Four of the ten are the reason it exists, and three of
# those four are invisible to every corpus counter in the test file:
#   * M5 IS THE WRONG-BUT-GREEN IMPLEMENTATION, and it is specific to a lever
#     that lives BESIDE another one.  Deleting the band's UPPER edge is the edit
#     a reviewer would wave through ("the sibling already covers above 0.18, so
#     this test is redundant").  On the pinned frame the answer is byte-identical;
#     the partition frame stays green too, because both trigger frames above 0.18
#     fail a LATER deep clause anyway (`band_high_otherwise_domain 0` -- measured,
#     which is exactly why that assertion cannot catch this).  What moves is the
#     one column driven over all 1021 live frames: `overlap`, the frames both ids
#     claim.  Two levers whose bands overlap make a single-arm A/B on either one
#     uninterpretable -- and nothing else in the file can see it.
#   * M6 AND M9 ARE THE CLAUSES THE CORPUS CANNOT DEFEND.  The low edge stops 12
#     trigger frames but costs ZERO domain (`band_low_otherwise_domain 0`), and
#     the one deep-band frame that separates a 6-second damage window from a
#     3-second one sits below that edge.  Delete the edge, or harmonise the
#     window down to the sibling's, and every corpus counter in the test file is
#     byte-identical.  Only the structural constant pins see them.  If those pins
#     were ever dropped for being "redundant with the domain count", these two
#     would survive.
#   * M10 IS THE NARROWING/OFF-SWITCH CONTROL, and it is the lanefix lesson: a
#     helper that answers TRUE for everything passes the POSITIVE frame test (the
#     pinned frame is held) and only the NEGATIVE control can tell "this narrows
#     the branch" from "this disables the branch below 0.18".
#
# Usage: bash tools/agent/mutstand_tpdeep.sh
set -u
cd "$(dirname "$0")/../.."

JMZ=bots/FunLib/jmz_func.lua
AIUG=bots/ability_item_usage_generic.lua
TEST=tests/test_tpdeep_recover_band.lua

FILES=("$JMZ" "$AIUG" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tpdeep.XXXXXX")
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
    lua5.1 tests/run_tests.lua tpdeep > "$WORK/run.log" 2>&1
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
# scores SURVIVED (measured on the sibling stand's first run -- M3 and M4 both).
sub_or_die() {
    sub "$@" || { echo "ANCHOR FAILURE -- stand aborted, nothing below is meaningful"; exit 3; }
}

# Anchors are LITERAL and must be UNIQUE.  Two of the single-line ones are not on
# their own: `if not J.IsModeTurbo() then return false end` occurs 30 times in
# this file, `if not J.HasFieldRegenSource( bot ) then return false end` 3 times,
# and the tower/return tail is byte-identical to the sibling helper's -- so those
# are widened with a neighbouring line that IS unique.  This is GH #550.
GATEPAIR=$'\tif not J.IsSoakCandidate( \'tpdeep\' ) then return false end\n\tif not J.IsModeTurbo() then return false end\n'
GATEONLY=$'\tif not J.IsSoakCandidate( \'tpdeep\' ) then return false end\n'
BAND_HI=$'\tif nHP >= 0.18 then return false end\n'
BAND_LO=$'\tif nHP < 0.10 then return false end\n'
SOURCE=$'\tif not J.HasFieldRegenSource( bot ) then return false end\n\n\t-- Unattributed'
DMG=$'\tif bot:WasRecentlyDamagedByAnyHero( 6.0 ) then return false end\n'
RING=$'\tif #J.GetNearbyHeroes( bot, 2500, true, BOT_MODE_NONE ) > 0 then return false end\n'
TAIL=$'\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end\n\n\treturn true\nend\n\n-- [stayfield2'
CALL=$'\t\t\tand not J.ShouldDeepSipNotTpRecover( bot )\n'

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
#     helper that still passes review -- and the sibling's own test file cannot
#     see it, because its counts are scoped to its own helper's name.
echo
echo "=== M1: the call site is deleted from the 回复状态 branch ==="
sub_or_die "$AIUG" "$CALL" ""
score "M1 " "no longer carries exactly one of each family veto"

# ---------------------------------------------------------------------------
# M2: the candidate check is dropped.  A defaults change wearing a candidate's
#     name -- the veto would be live in every shipped turbo game, below the floor
#     the family drew for genuine escapes.
echo
echo "=== M2: the helper stops asking whether the candidate is armed ==="
sub_or_die "$JMZ" "$GATEPAIR" $'\tif not J.IsModeTurbo() then return false end\n'
score "M2 " "UNARMED the helper answers TRUE"

# ---------------------------------------------------------------------------
# M3: turbo-only is dropped, the candidate check kept.  The narrower half of M2.
echo
echo "=== M3: the turbo guard is dropped, the candidate check kept ==="
sub_or_die "$JMZ" "$GATEPAIR" "$GATEONLY"
score "M3 " "no longer gate-first-then-turbo"

# ---------------------------------------------------------------------------
# M4: the gate is moved BELOW every read.  The helper still contains the gate and
#     exactly one id -- a grep, and check_armed_wiring.py, still answer "gated" --
#     while an unarmed shipped game now evaluates J.GetHP, J.HasFieldRegenSource
#     and two engine scans on every call.
echo
echo "=== M4: the gate is moved BELOW every read ==="
sub_or_die "$JMZ" "$GATEPAIR" $'\tif not J.IsModeTurbo() then return false end\n'
sub_or_die "$JMZ" "$TAIL" $'\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end\n\n'"$GATEONLY"$'\treturn true\nend\n\n-- [stayfield2'
score "M4 " "no longer gate-first-then-turbo"

# ---------------------------------------------------------------------------
# M5: THE WRONG-BUT-GREEN ONE.  Delete the band's UPPER edge -- "the sibling
#     already owns above 0.18, so this line is redundant".  The pinned frame is
#     unchanged, the partition frame is unchanged (both trigger frames above 0.18
#     fail a later deep clause anyway -- measured, `band_high_otherwise_domain 0`),
#     every stop bucket is unchanged.  What moves is `overlap`, driven over all
#     1021 live frames: the two ids start claiming the same frames, and a
#     single-arm A/B on either stops being attributable.
echo
echo "=== M5: the band's UPPER edge is deleted (the sibling 'already covers it') ==="
sub_or_die "$JMZ" "$BAND_HI" ""
score "M5 " "are claimed by BOTH tprecov and tpdeep"

# ---------------------------------------------------------------------------
# M6: the band's LOWER edge is deleted.  Invisible to every corpus counter in the
#     test file (`band_low_otherwise_domain 0` -- the 12 frames it stops all fail
#     a later clause too), so only the structural constant pin sees it.  It is
#     also the edit a later round is most likely to make on purpose, since 12 of
#     the 29 deep frames sit below it.
echo
echo "=== M6: the band's LOWER edge (0.10) is deleted ==="
sub_or_die "$JMZ" "$BAND_LO" ""
score "M6 " "band's lower edge moved to"

# ---------------------------------------------------------------------------
# M7: the danger ring is harmonised back to the sibling's 1200.  This one IS
#     corpus-visible and the negative control is what sees it: a bot at 10.2% HP
#     with an empty 1200 ring and an enemy inside 2500 would be held in the field.
echo
echo "=== M7: the 2500 ring is harmonised down to the sibling's 1200 ==="
sub_or_die "$JMZ" "$RING" $'\tif #J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE ) > 0 then return false end\n'
score "M7 " "behaving as an off switch for the deep band"

# ---------------------------------------------------------------------------
# M8: the danger read acquires the sibling's ATTRIBUTION.  That reads as
#     harmonising two siblings and is in fact a WIDENING exactly where this lever
#     must not widen: attribution lets a frame through once the hero that hit the
#     bot has walked off, and at 12% HP one returning hero is the whole risk.
#     Both deep-band frames with recent damage have their damager in range, so no
#     corpus counter moves -- structural pin only.
echo
echo "=== M8: the danger read acquires the sibling's attribution ==="
sub_or_die "$JMZ" "$DMG" $'\tif bot:WasRecentlyDamagedByAnyHero( 6.0 )\n\t\tand J.HasNearbyHeroDamager( bot, 3000, 6.0 )\n\tthen\n\t\treturn false\n\tend\n'
score "M8 " "acquired J.HasNearbyHeroDamager"

# ---------------------------------------------------------------------------
# M9: the damage window is harmonised down to the sibling's 3.0s.  The one
#     deep-band frame that separates the two windows sits BELOW the low edge, so
#     every corpus counter is byte-identical -- structural pin only, again.
echo
echo "=== M9: the 6s damage window is harmonised down to the sibling's 3s ==="
sub_or_die "$JMZ" "$DMG" $'\tif bot:WasRecentlyDamagedByAnyHero( 3.0 ) then return false end\n'
score "M9 " "is no longer longer than the sibling"

# ---------------------------------------------------------------------------
# M10: THE OFF-SWITCH.  Everything after the gates is short-circuited to `true`.
#      The pinned frame is still held, so the POSITIVE test passes; only the
#      negative control can tell a narrowing from a disabled branch.
echo
echo "=== M10: the helper becomes an unconditional hold ==="
sub_or_die "$JMZ" "$GATEPAIR" "$GATEPAIR"$'\tif true then return true end\n'
score "M10" "behaving as an off switch for the deep band"

# ---------------------------------------------------------------------------
echo
echo "=== summary ==="
echo "CAUGHT $CAUGHT / $TOTAL"
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "AT LEAST ONE MUTANT SURVIVED -- the pin has a hole; fix the test, not this file"
    exit 3
fi
echo "no survivors"
