#!/usr/bin/env bash
# Mutation stand for 'tpquiet' -- "a veto on a branch that never runs is not a
# veto: '撤退:1' is upstream of '回复状态' and RETURNS, so on 1 of 'tpdeep''s 2
# domain frames the sibling's veto is never evaluated" (strategy, 2026-09-08,
# OWNER_PRIORITIES P2 + P4.4(i)).
# Run by hand when J.ShouldSipNotTpQuietHome, its call site in the '撤退:1' branch
# of X.ConsiderItemDesire["item_tpscroll"], or
# tests/test_tpquiet_shadowed_branch.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_tpdeep.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a mutant
#     can never score "caught" for having applied to nothing, nor "survived" for
#     having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507 -- and the sibling round wounded itself with exactly this, then
# caught it only because two numbers disagreed).
#
# WHAT THIS STAND IS FOR.  Four of the mutants are the reason it exists, and each
# is an edit a reviewer would plausibly wave through:
#   * M5 IS THE WRONG-BUT-GREEN ONE FOR THIS LEVER'S SHAPE.  Move the call site
#     from '撤退:1' to '回复状态'.  Every corpus counter about the HELPER is
#     unchanged -- the helper is untouched -- and the id is still wired, still
#     gated, still one call site.  What dies is the entire point: the veto is
#     back on the shadowed branch.  Only the call-site counts can see it.
#   * M6 IS THE "HARMONISE THE CONSTANTS" EDIT.  The band edge is a NAMED
#     constant here where the sibling inlines it, so "tidying" it to a different
#     number reads as a formatting choice.  It is the licence for the lever.
#   * M9 IS THE GH #550 REGRESSION.  Rewrite the helper's band line into the
#     sibling's INLINE form -- objectively tidier, and it silently makes
#     mutstand_tpdeep.sh's BAND_HI anchor ambiguous, which aborts the SIBLING's
#     whole stand under the SIBLING's name for a change that is not the
#     sibling's.
#   * M10 IS THE ONE THE CORPUS CANNOT DEFEND.  Delete the structural
#     source-order pin.  Every count in the file is byte-identical, because the
#     order is not a count -- and without it two armed ids race for one frame
#     with no rule saying which acts.

set -u

JMZ=bots/FunLib/jmz_func.lua
AIUG=bots/ability_item_usage_generic.lua
TEST=tests/test_tpquiet_shadowed_branch.lua
SWEEP=tests/_tpquiet_sweep.lua

FILES=("$JMZ" "$AIUG" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tpquiet.XXXXXX")
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
    lua5.1 tests/run_tests.lua tpquiet > "$WORK/run.log" 2>&1
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
# scores SURVIVED.
sub_or_die() {
    sub "$@" || { echo "ANCHOR FAILURE -- stand aborted, nothing below is meaningful"; exit 3; }
}

# Anchors are LITERAL and must be UNIQUE.  The helper's lines are unique BY
# CONSTRUCTION (it names its constants where the sibling inlines them -- that is
# M9's subject), so none of these needs widening against jmz_func; the call-site
# one is widened with its neighbouring conjunct because `and not J.Should...`
# lines are a family.
GATEPAIR=$'\tif not J.IsSoakCandidate( \'tpquiet\' ) then return false end\n\tif not J.IsModeTurbo() then return false end\n'
GATEONLY=$'\tif not J.IsSoakCandidate( \'tpquiet\' ) then return false end\n'
BANDCONST=$'\tlocal QUIET_BAND_HI, QUIET_BAND_LO = 0.18, 0.10\n'
BAND_HI=$'\tif nHP >= QUIET_BAND_HI then return false end\n'
BAND_LO=$'\tif nHP < QUIET_BAND_LO then return false end\n'
SOURCE=$'\tif not J.HasFieldRegenSource( bot ) then return false end\n\tif bot:WasRecentlyDamagedByAnyHero( QUIET_DMG_WINDOW ) then return false end\n'
DMG=$'\tif bot:WasRecentlyDamagedByAnyHero( QUIET_DMG_WINDOW ) then return false end\n'
RING=$'\tif #J.GetNearbyHeroes( bot, QUIET_RING, true, BOT_MODE_NONE ) > 0 then return false end\n'
TAIL=$'\tif #bot:GetNearbyTowers( QUIET_TOWER, true ) > 0 then return false end\n\n\treturn true\nend\n'
CALL=$'\t\t\tand not J.ShouldSipNotTpQuietHome( bot )\n'
R4CALL=$'\t\t\tand not J.ShouldDeepSipNotTpRecover( bot )\n'
ORDERPIN=$'G.T1_RETURN_BEFORE_R4 = (at_t1_ret and at_r4_trig and at_t1_ret < at_r4_trig) and 1 or 0\n'

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
#     helper that still passes review -- and check_armed_wiring.py would still
#     have called the id WIRED before the call site existed at all (GH #606).
echo
echo "=== M1: the call site is deleted from the '撤退:1' branch ==="
sub_or_die "$AIUG" "$CALL" ""
score "M1 " "call(s) to the new helper, not exactly one"

# ---------------------------------------------------------------------------
# M2: the candidate check is dropped.  A defaults change wearing a candidate's
#     name -- the veto would be live in every shipped turbo game, below the floor
#     the family drew for genuine escapes.
echo
echo "=== M2: the helper stops asking whether the candidate is armed ==="
sub_or_die "$JMZ" "$GATEPAIR" $'\tif not J.IsModeTurbo() then return false end\n'
score "M2 " "with no id armed"

# ---------------------------------------------------------------------------
# M3: turbo-only is dropped, the candidate check kept.  The narrower half of M2:
#     the lever would reach normal mode, which owner policy scopes it out of.
echo
echo "=== M3: the turbo guard is dropped, the candidate check kept ==="
sub_or_die "$JMZ" "$GATEPAIR" "$GATEONLY"
score "M3 " "asks J.IsModeTurbo() exactly once"

# ---------------------------------------------------------------------------
# M4: the gate is moved BELOW every read.  The helper still contains the gate and
#     exactly one id -- a grep, and check_armed_wiring.py, still answer "gated" --
#     while an unarmed shipped game now runs J.GetHP, J.HasFieldRegenSource and
#     two engine scans on every call.
echo
echo "=== M4: the gate is moved BELOW every read ==="
sub_or_die "$JMZ" "$GATEPAIR" $'\tif not J.IsModeTurbo() then return false end\n'
sub_or_die "$JMZ" "$TAIL" $'\tif #bot:GetNearbyTowers( QUIET_TOWER, true ) > 0 then return false end\n\n'"$GATEONLY"$'\treturn true\nend\n'
score "M4 " "gate is no longer ahead of every read"

# ---------------------------------------------------------------------------
# M5: THE WRONG-BUT-GREEN ONE, and it is the generous-looking edit.  ALSO wire
#     the helper into the '回复状态' branch -- "why not guard both, it can only
#     help".  The helper is untouched, so every corpus column about it reads
#     exactly the same; the branch this lever claims still carries its call; the
#     gate is still one id.  What dies is attributability: one armed id now moves
#     two call sites, so a wave on 'tpquiet' could never say which branch
#     produced its verdict -- the exact reason this is a separate id from
#     'tpdeep' rather than a second call to it.  Only the whole-file count sees
#     it.
echo
echo "=== M5: the helper is ALSO wired into the '回复状态' branch ==="
sub_or_die "$AIUG" "$R4CALL" "$R4CALL$CALL"
score "M5 " "call(s) to the new helper. A second call site"

# ---------------------------------------------------------------------------
# M6: "harmonise" the band's upper edge.  It is a NAMED constant here where the
#     sibling inlines it, so changing the number looks like a formatting
#     decision.  It is not: the band edge is the entire licence for calling this
#     the SAME judgement as the sibling's, and 0.19 would eat the one percentage
#     point the PROMOTED veto already owns on this branch.
echo
echo "=== M6: the band's upper edge is nudged to the branch's own cap ==="
sub_or_die "$JMZ" "$BANDCONST" $'\tlocal QUIET_BAND_HI, QUIET_BAND_LO = 0.19, 0.10\n'
score "M6 " "band upper edge drifted from the sibling"

# ---------------------------------------------------------------------------
# M7: the band's lower edge is deleted.  The corpus CANNOT defend this one --
#     `band_low_otherwise_domain 0` says removing it costs zero domain frames, so
#     every count in the file stays put.  It is caught structurally, against the
#     sibling's own number, which is precisely why that assertion exists.
echo
echo "=== M7: the band's lower edge is deleted ==="
sub_or_die "$JMZ" "$BAND_LO" ""
score "M7 " "declared but not used by the body"

# ---------------------------------------------------------------------------
# M8: the regen-source clause is deleted.  Without it the lever holds a bot in
#     the field at 11% HP with nothing whatsoever to drink -- the exact opposite
#     of what owner priority P2 asks for.
echo
echo "=== M8: the helper stops asking whether there is anything to drink ==="
sub_or_die "$JMZ" "$SOURCE" "$DMG"
score "M8 " "no longer asks J.HasFieldRegenSource"

# ---------------------------------------------------------------------------
# M9: THE GH #550 REGRESSION, and it is objectively a tidy-up.  Rewrite the two
#     band lines into the sibling's INLINE form and drop the now-unused constant.
#     Nothing about this lever's behaviour changes at all -- and
#     tools/agent/mutstand_tpdeep.sh's BAND_HI/BAND_LO anchors become AMBIGUOUS,
#     which aborts the SIBLING's entire stand, in the SIBLING's name, for a
#     change that is not the sibling's.  This is why that check lives HERE.
echo
echo "=== M9: the band lines are 'tidied' into the sibling's inline form ==="
sub_or_die "$JMZ" "$BAND_HI" $'\tif nHP >= 0.18 then return false end\n'
sub_or_die "$JMZ" "$BAND_LO" $'\tif nHP < 0.10 then return false end\n'
sub_or_die "$JMZ" "$BANDCONST" ""
score "M9 " "mutstand_tpdeep.sh"

# ---------------------------------------------------------------------------
# M10: the manifest's copy of the source-order pin is falsified.  The test file
#      DERIVES the order itself (that is the M10 finding from this stand's first
#      run: reading it out of the manifest let a hard-coded `1` through), so what
#      this mutant exercises is the AGREEMENT check -- the thing that makes a
#      sweep describing a different tree than the test visible instead of silent.
echo
echo "=== M10: the sweep's copy of the source-order pin is falsified ==="
sub_or_die "$SWEEP" "$ORDERPIN" $'G.T1_RETURN_BEFORE_R4 = 0\n'
score "M10" "manifest disagrees with the source order"

# ---------------------------------------------------------------------------
# M13: the guarded branch loses its RETURN -- it falls through to '撤退:2'
#      instead.  This is the real regression the order pin exists for, and it is
#      the one a whole-file `find` could not see: the same `return ... tpLoc ...`
#      line ends two sibling branches, so the naive pin would be satisfied by a
#      sibling's return and go green on a branch that no longer shadows anything.
echo
echo "=== M13: the '撤退:1' branch loses its own return ==="
sub_or_die "$AIUG" $'\t\t\treturn BOT_ACTION_DESIRE_HIGH, tpLoc, sCastType, sCastMotive\n\t\tend\n\n\n\t\t--第二种情况' $'\t\tend\n\n\n\t\t--第二种情况'
score "M13" "no longer contains its fountain-TP return"

# ---------------------------------------------------------------------------
# M11: the ring is widened to the branch's own 1600.  The helper would then add
#      nothing over the branch on the surroundings axis, and `quiet_ring_margin`
#      -- 3 frames the branch passes and this refuses -- stops being a reading
#      about the radius.
echo
echo "=== M11: the ring is widened to the branch's own 1600 ==="
sub_or_die "$JMZ" $'\tlocal QUIET_RING, QUIET_TOWER = 2500, 1200\n' $'\tlocal QUIET_RING, QUIET_TOWER = 1600, 1200\n'
score "M11" "ring radius drifted from the sibling"

# ---------------------------------------------------------------------------
# M12: THE CONTROL.  A comment-only edit inside the helper must NOT redden the
#      stand.  Without a control, "12 caught" cannot be told apart from "this
#      test file is red on any edit at all".
echo
echo "=== M12 (CONTROL): a comment inside the helper is reworded ==="
sub_or_die "$JMZ" $'\t-- Every one of these five is J.ShouldDeepSipNotTpRecover\'s own constant.\n' $'\t-- Every one of these five is the sibling helper\'s own constant.\n'
TOTAL=$((TOTAL + 1))
run_tests; RC=$?
if [ "$RC" -eq 0 ]; then
    echo "M12  CONTROL OK (exit 0) -- the file is not red on any edit whatsoever"
    CAUGHT=$((CAUGHT + 1))
else
    echo "M12  CONTROL FAILED (exit $RC) -- a comment reword reddens the stand, so"
    echo "     every 'caught' above is suspect:"
    grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
fi
restore > /dev/null

# ---------------------------------------------------------------------------
echo
echo "=== stand summary ==="
echo "$CAUGHT / $TOTAL"
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "STAND NOT GREEN -- at least one mutant survived or the control failed."
    exit 1
fi
echo "STAND GREEN"
