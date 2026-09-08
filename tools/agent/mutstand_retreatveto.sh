#!/usr/bin/env bash
# Mutation stand for the THIRD shadow census -- the mode_retreat_generic veto
# chain: "'stayfield2' reaches 19 of its 24 frames EXACTLY, the shadow is benign
# because both lines return the same NONE, and the live domain is bought by the
# REGEN blind spot rather than the danger one" (strategy, 2026-09-08,
# OWNER_PRIORITIES P2 + P4.4(ii)).
# Run by hand when tests/_tpquiet_sweep.lua, its consumers, the veto chain in
# bots/mode_retreat_generic.lua, J.ShouldStayAndRegen or J.IsFieldRegenSituation
# are edited, and before quoting any of these readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_shadowcensus.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a mutant
#     can never score "caught" for having applied to nothing, nor "survived" for
#     having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets, not the one
#     the author hoped for -- the M2 finding of the previous stand, where a
#     mutant scored SURVIVED because the stand was waiting on a sentence the
#     code could not produce (an earlier assertion fired first).
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  This census's product is an EXACT domain (19) plus
# two structural claims -- "nothing returns between the two vetoes" and "both
# return the same value".  Neither of those is a count, and the previous stand's
# M10 proved that an assertion whose input the checked artefact produces checks
# nothing.  So the mutants that matter are the ones that keep every counter
# plausible while quietly turning the exactness or the benign-ness into a lie:
#   * M3 IS THE ONE THAT TURNS AN IDENTITY INTO A CEILING.  Insert a third exit
#     between the two vetoes.  Every corpus number is byte-identical -- the
#     sweep drives the HELPERS, not the chain -- and `srnwh_armed_true_live`
#     silently stops being a domain.
#   * M4 IS THE ONE THAT MAKES THE SHADOW A BEHAVIOUR DIFFERENCE.  Change the
#     gated veto's return value.  Again every counter holds; only the "benign"
#     verdict, which rests entirely on the two returns being the SAME constant,
#     becomes false.
#   * M8 IS THE MISSING-KEY ONE (GH #171).  Rename a counter in the sweep: the
#     bucket stops existing, the manifest still parses, and a `nil` must not
#     read as a satisfied assertion.
#   * M12 IS THE CONTROL.  A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
MRG=bots/mode_retreat_generic.lua
TEST=tests/test_retreat_veto_reachability.lua
SWEEP=tests/_tpquiet_sweep.lua

FILES=("$JMZ" "$MRG" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_retreatveto.XXXXXX")
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
    lua5.1 tests/run_tests.lua retreat_veto_reachability > "$WORK/run.log" 2>&1
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

# The control leg is scored with the opposite expectation.
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
SWHCALL=$'    if J.ShouldStayAndRegen(bot) then\n        return BOT_MODE_DESIRE_NONE\n    end\n'
WALKCALL=$'    if J.ShouldRegenNotWalkHome(bot) then\n        return BOT_MODE_DESIRE_NONE\n    end\n'
WALKWRAP=$'function J.ShouldRegenNotWalkHome( bot )\n\tif not J.IsSoakCandidate( \'stayfield2\' ) then return false end\n\treturn J.ShouldRegenNotGoHome( bot )\nend\n'
SWHBAND=$'\tif nHP < 0.18 or nHP > 0.75 then return false end\n'
# ⚠️ The 1200-ring line ALONE occurs three times in jmz_func -- as an anchor it
# aborts the stand (AMBIGUOUS), which is the guard working, not a mutant. It is
# made unique by carrying the 'stayattr' clause immediately above it, a line that
# exists once in the tree.
SWHRING=$'\tif bot:WasRecentlyDamagedByAnyHero( 3.0 )\n\t\tand ( not J.IsSoakCandidate( \'stayattr\' )\n\t\t\tor J.HasNearbyHeroDamager( bot, 3000, 3.0 ) )\n\tthen\n\t\treturn false\n\tend\n\tif #J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE ) > 0 then return false end\n'
SWHRING_MUT=$'\tif bot:WasRecentlyDamagedByAnyHero( 3.0 )\n\t\tand ( not J.IsSoakCandidate( \'stayattr\' )\n\t\t\tor J.HasNearbyHeroDamager( bot, 3000, 3.0 ) )\n\tthen\n\t\treturn false\n\tend\n\tif #J.GetNearbyHeroes( bot, 2000, true, BOT_MODE_NONE ) > 0 then return false end\n'
SHADOWSPLIT=$'                            if swh then\n                                bump(\'srnwh_armed_true_shadowed\')\n'
LIVEKEY=$'                                bump(\'srnwh_armed_true_live\')\n                                note(\'sf2_live\')\n'
NOFLASK=$'                                if not bFlask then bump(\'sf2_live_swh_noflask\') end\n'
DMGREAD=$'                                local bDmg = bot:WasRecentlyDamagedByAnyHero(G.SWH_DMG_WINDOW)\n'
UNEXPL=$'                                if not bDmg and bFlask then bump(\'sf2_live_unexplained\') end\n'
WALKARM=$'                    sArmed = \'stayfield2\'\n                    local okWalkArm, walk_true = pcall(J.ShouldRegenNotWalkHome, bot)\n'
BETWEEN=$'G.MRG_RETURNS_BETWEEN = (at_swh_ret and at_srnwh)\n'

# ---------------------------------------------------------------------------
# M1: the GATED veto's call site is deleted from the chain.  This is not a
#     hypothetical: the director's 2026-09-07 note in that very file records the
#     commit that did exactly this, replacing the call with a different helper's
#     and leaving the comment block behind.  Shipped play never moved (the
#     helper is false unarmed); what died was every future wave's reading.
echo
echo "=== M1: the gated veto's ONLY call site is removed from the chain ==="
sub_or_die "$MRG" "$WALKCALL" ''
score "M1 " "is gone from GetDesireHelper"

# ---------------------------------------------------------------------------
# M2: the two vetoes swap order.  Every counter in the sweep is byte-identical
#     (the sweep drives the HELPERS, not the chain), and the shadow reverses
#     direction: the PROMOTED veto would now be the one losing frames.
#     Done as TWO subs rather than one span, because a long comment block sits
#     between the two calls and a single anchor over it would be a 400-character
#     literal that goes ABSENT on the next comment edit -- an anchor that breaks
#     for an unrelated reason scores nothing, it aborts the stand.  Order
#     matters: deleting first keeps the second anchor unique.
echo
echo "=== M2: the gated veto is moved ABOVE the promoted one ==="
sub_or_die "$MRG" "$SWHCALL" ''
sub_or_die "$MRG" "$WALKCALL" "$WALKCALL$SWHCALL"
score "M2 " "the gated veto now precedes the PROMOTED one"

# ---------------------------------------------------------------------------
# M3: THE EXACTNESS MUTANT.  A third exit is inserted between the two vetoes.
#     Nothing the sweep counts changes; `srnwh_armed_true_live` silently stops
#     being a domain and becomes a ceiling, and every downstream sentence that
#     says "exactly 19" becomes an overstatement.
echo
echo "=== M3: a third return is inserted between the two vetoes ==="
sub_or_die "$MRG" "$WALKCALL" $'    if botHP > 0.9 then\n        return BOT_MODE_DESIRE_NONE\n    end\n'"$WALKCALL"
score "M3 " "was inserted between the two vetoes"

# ---------------------------------------------------------------------------
# M4: THE BENIGN-NESS MUTANT.  The gated veto stops returning the SAME value as
#     the promoted one.  The whole "the shadow costs the bot nothing" verdict
#     rests on those two constants being equal -- and no counter can see it.
echo
echo "=== M4: the gated veto returns a different desire ==="
sub_or_die "$MRG" "$WALKCALL" $'    if J.ShouldRegenNotWalkHome(bot) then\n        return BOT_MODE_DESIRE_LOW\n    end\n'
score "M4 " "stopped returning BOT_MODE_DESIRE_NONE"

# ---------------------------------------------------------------------------
# M5: the two wrappers drift apart -- 'stayfield2' gets a second conjunct.  The
#     headline "one opinion asked at two addresses" quietly stops holding, and
#     the per-frame identity column is the only thing that could notice.
echo
echo "=== M5: the walk-half wrapper acquires an extra conjunct ==="
sub_or_die "$JMZ" "$WALKWRAP" $'function J.ShouldRegenNotWalkHome( bot )\n\tif not J.IsSoakCandidate( \'stayfield2\' ) then return false end\n\tif bot:GetLevel() < 6 then return false end\n\treturn J.ShouldRegenNotGoHome( bot )\nend\n'
# Scored on the message the reader ACTUALLY gets. The tempting `want` here is
# the per-frame `core_disagree` sentence, but that assertion is never reached:
# shrinking the walk-half's opinion trips the `srnwh_armed_true == 24` line
# three assertions earlier in the same test. A stand that demands a sentence the
# code cannot produce reports a caught mutant as survived (the previous stand's
# M2 finding, reproduced here).
score "M5 " "have drifted apart"

# ---------------------------------------------------------------------------
# M6: THE CLOSED-FORM MUTANT (band).  The promoted veto's ceiling drops below
#     the gated helper's, so the band containment breaks.  The column
#     `sf2_live_swh_above_ceil` was a CLOSED FORM only while that containment
#     held; the mutant turns it into a sample without emptying it.
echo
echo "=== M6: the promoted veto's ceiling falls below the field-regen ceiling ==="
sub_or_die "$JMZ" "$SWHBAND" $'\tif nHP < 0.18 or nHP > 0.40 then return false end\n'
score "M6 " "is no longer inside the promoted veto's"

# ---------------------------------------------------------------------------
# M7: THE CLOSED-FORM MUTANT (ring).  The promoted veto's ring grows past the
#     field-regen ring, so "a 1200 occupant is impossible on a live frame" stops
#     being arithmetic.
echo
echo "=== M7: the promoted veto's ring grows wider than the field-regen ring ==="
sub_or_die "$JMZ" "$SWHRING" "$SWHRING_MUT"
score "M7 " "is now WIDER than the field-regen ring"

# ---------------------------------------------------------------------------
# M8: THE MISSING-KEY MUTANT (GH #171), and it has to be aimed at a counter that
#     reads ZERO on a clean tree or it is not the shape at all.  Renaming a
#     bumped counter merely makes it 0, which an `== 19` assertion catches as an
#     ordinary failure.  The dangerous case is a column whose clean value IS 0:
#     drop it from the zero-init list and the key never appears in the manifest,
#     so `nil` reaches the assertion -- and `nil == 0` is false but `nil ~= 0`
#     "passes" in the many places a reviewer writes the check that way.  Only the
#     `must` guard can tell "never measured" from "measured zero".
echo
echo "=== M8: a clean-zero counter is dropped from the zero-init list ==="
sub_or_die "$SWEEP" $'    \'sf2_live_swh_above_ceil\', \'sf2_live_unexplained\' }) do\n' $'    \'sf2_live_swh_above_ceil\' }) do\n'
score "M8 " "is missing from the manifest"

# ---------------------------------------------------------------------------
# M9: THE PARTITION MUTANT.  The shadow test is inverted, so the split reverses
#     (5/19 becomes 19/5) while still summing to 24 -- a leak-free partition of
#     the wrong thing.  The headline number is the one that moves.
echo
echo "=== M9: the shadow test is inverted (the split reverses, the sum holds) ==="
sub_or_die "$SWEEP" "$SHADOWSPLIT" $'                            if not swh then\n                                bump(\'srnwh_armed_true_shadowed\')\n'
score "M9 " "the shadowed half moved to"

# ---------------------------------------------------------------------------
# M10: THE CORRECTION MUTANT, and its DIRECTION is the whole point.  Making the
#      flask read STRICTER cannot be seen (the column is already 19 of 19 and
#      cannot rise) -- so the mutant that matters is the GENEROUS one: conflate
#      the promoted veto's flask-only read with the gated helper's broader
#      source read.  That is the plausible "cleanup" a reviewer would wave
#      through, and it erases this round's correction entirely: every live frame
#      has a field-regen source by construction, so the flask-blind column
#      collapses from 19 to 0 and "the REGEN blind spot buys the whole domain"
#      silently becomes its opposite.
echo
echo "=== M10: the flask read is widened into the field-regen source read ==="
sub_or_die "$SWEEP" $'                                local bFlask = J.IsItemAvailable(\'item_flask\') ~= nil\n                                    or bot:HasModifier(\'modifier_flask_healing\')\n                                    or bot:HasModifier(\'modifier_tango_heal\')\n' $'                                local bFlask = J.IsItemAvailable(\'item_flask\') ~= nil\n                                    or J.HasFieldRegenSource(bot)\n'
score "M10" "the flask/tango-blind frames moved to"

# ---------------------------------------------------------------------------
# M11: THE ARMING MUTANT.  The walk-half read is taken with the OTHER half's id
#      armed.  Both wrappers route to the same predicate, so every number stays
#      plausible -- and the two call sites have quietly become one measurement,
#      which is the whole reason the family keeps two ids.
echo
echo "=== M11: the walk-half is read with 'stayfield' armed instead ==="
sub_or_die "$SWEEP" "$WALKARM" $'                    sArmed = \'stayfield\'\n                    local okWalkArm, walk_true = pcall(J.ShouldRegenNotWalkHome, bot)\n'
score "M11" "armed more than one id at a time"

# ---------------------------------------------------------------------------
# M12: THE CONTROL.  A comment-only edit changes no behaviour and must SURVIVE.
#      Without it the stand is scoring the act of editing rather than the edit,
#      and every "caught" above means nothing.
echo
echo "=== M12 (control): a comment-only edit -- must SURVIVE ==="
sub_or_die "$MRG" $'    -- === RETREAT GUARD CHAIN: BEGIN (priority-ordered) ===\n' $'    -- === RETREAT GUARD CHAIN: BEGIN (priority-ordered) === [mutstand control]\n'
score_control "M12"

# ---------------------------------------------------------------------------
echo
echo "=== stand summary ==="
echo "legs: $TOTAL   caught (incl. control): $CAUGHT   survived: $SURVIVED"
if [ "$SURVIVED" -ne 0 ]; then
    echo "STAND RED -- $SURVIVED leg(s) the assertions cannot see."
    exit 3
fi
echo "STAND GREEN -- every mutant is caught and the control survives."
exit 0
