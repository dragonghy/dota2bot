#!/usr/bin/env bash
# Mutation stand for the `pullchew` candidate -- GH #250 §4, the pull trigger's
# "never pull under threat" clause asked about NEUTRALS (strategy, 2026-09-11,
# OWNER_PRIORITIES P4.4 / P1).
# Run by hand when J.ShouldPullNeutralCamp, J.IsPullCampChewing, either
# PULL_CHEW_* constant or tests/test_pullchew_camp_commit.lua are edited, and
# before quoting any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkbonefight.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing, nor "survived" for having
#     applied to the wrong one of two identical sites;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR. Five of the mutants are directional or instrumental
# rather than cosmetic, and they are the ones worth reading:
#   * M3 is THE MUTANT THIS LEVER WAS WRITTEN AROUND: drop the commitment
#     exemption. It reads exactly like a simplification -- "why ask whether a
#     plan exists, just refuse while a camp is on me" -- and it turns the id
#     from a guard into a MUTE of the whole mechanic, because aggroing the camp
#     is how a pull starts. No counter anywhere reports a pull that was never
#     attempted; this is the `lanefix` trade, and the stand is where it has to
#     be caught.
#   * M4 is the INHERITED CONSTANT. 6.0 -> 3.0 is not a typo, it is the value
#     `fieldcreep` and `tpchew` both use for this same probe, so it is what a
#     future editor "corrects" the outlier to. It empties the domain on the only
#     frame that exists -- the guard-that-cannot-fire shape this family has now
#     paid for four times (GH #13, #277, #648, this).
#   * M5 is the LOST NARROWING: drop the neutral conjunct and the lever fires on
#     lane-creep damage, which a laning support takes constantly. Scored against
#     the naturally-occurring viper control rather than a constructed one.
#   * M7 is a control on the WITNESS itself. If J.IsLanePullSafe stopped
#     answering SAFE, section 1's defect reading would be vacuous and this whole
#     file would be asserting nothing about the shipped tree.
#   * M8 is a control on the WORLD ASSUMPTION. Install the synthesized neutral
#     reader globally and the opt-in pin must fail -- otherwise four other files
#     that declare the empty default are being silently overtaken (GH #624's
#     shape, and the exact thing the tpchew round hit).
#
# Usage: bash tools/agent/mutstand_pullchew.sh
set -u
cd "$(dirname "$0")/../.."

LIB=bots/FunLib/jmz_func.lua
TEST=tests/test_pullchew_camp_commit.lua
LOADER=tests/mock/replay_fixture.lua

FILES=("$LIB" "$TEST" "$LOADER")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_pullchew.XXXXXX")
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

# The filter is `pull`, not this one file: the census, the pullreach test, the
# pulllane blind-A and the pullnolane guard all assert on this same helper, and
# a stand scoped to the new file alone would report a collision there as
# SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua pull > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex). Abort on an absent OR ambiguous anchor.
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

GATE_LINE=$'\tif J.IsSoakCandidate( \'pullchew\' ) and bot.roamCampPull == nil\n\t\tand J.IsPullCampChewing( bot )\n\tthen\n\t\treturn nil\n\tend'
LOOKBACK=$'local PULL_CHEW_LOOKBACK = 6.0'
RADIUS=$'local PULL_CHEW_NEUTRAL_RADIUS = 1400'
DMG_CALL=$'\tif not bot:WasRecentlyDamagedByCreep( PULL_CHEW_LOOKBACK ) then return false end'
NEUT_CALL=$'\treturn #bot:GetNearbyNeutralCreeps( PULL_CHEW_NEUTRAL_RADIUS ) > 0'
OPTIN=$'      if tOpts.neutrals then'

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
# M1: the whole clause is deleted.  The id becomes registered-but-unwired: the
#     helper exists, state.json names it, and no wave can ever move a frame.
echo
echo "=== M1: the clause is removed from J.ShouldPullNeutralCamp ==="
sub "$LIB" "$GATE_LINE" $'\t-- (clause removed by M1)'
score "M1" "not inside J.ShouldPullNeutralCamp"

# ---------------------------------------------------------------------------
# M2: the candidate check is dropped.  A defaults change wearing a candidate's
#     name -- it would ship live in every Turbo game.
echo
echo "=== M2: the gate stops asking whether the candidate is armed ==="
sub "$LIB" $'if J.IsSoakCandidate( \'pullchew\' ) and bot.roamCampPull == nil' \
           $'if bot.roamCampPull == nil'
score "M2" "not inside J.ShouldPullNeutralCamp"

# ---------------------------------------------------------------------------
# M3: THE MUTANT THIS LEVER WAS WRITTEN AROUND.  Drop the commitment exemption
#     and the guard fires from the aggro instant onward, aborting every pull it
#     has.  Reads as a simplification; is a mute of the mechanic.
echo
echo "=== M3: the in-progress exemption is dropped ==="
sub "$LIB" $'if J.IsSoakCandidate( \'pullchew\' ) and bot.roamCampPull == nil' \
           $'if J.IsSoakCandidate( \'pullchew\' )'
score "M3" "in-progress exemption is gone"

# ---------------------------------------------------------------------------
# M4: THE INHERITED CONSTANT.  6.0 -> 3.0, the value both siblings use for this
#     probe.  Empties the domain on the only frame that can witness the lever.
echo
echo "=== M4: the lookback is 'corrected' to the sibling constant 3.0 ==="
sub "$LIB" "$LOOKBACK" $'local PULL_CHEW_LOOKBACK = 3.0'
score "M4" "does not fire on the only frame"

# ---------------------------------------------------------------------------
# M5: THE LOST NARROWING.  Without the neutral conjunct the lever fires on lane
#     creep damage -- scored against viper, whose two goodguys_ranged rows on
#     this very frame make the raw probe true.
echo
echo "=== M5: the neutral conjunct is dropped (raw creep probe only) ==="
sub "$LIB" "$NEUT_CALL" $'\treturn true'
score "M5" "fires on lane-creep damage"

# ---------------------------------------------------------------------------
# M6: the damage conjunct is dropped.  Standing near any camp would refuse a
#     pull -- which is most of the jungle, and the opposite of the mechanic.
echo
echo "=== M6: the damage conjunct is dropped (proximity only) ==="
sub "$LIB" "$DMG_CALL" $'\tif false then return false end'
score "M6" "damage conjunct is gone from J.IsPullCampChewing"
# ⛔ M6 IS SCORED AGAINST A SOURCE PIN, AND THAT IS WEAKER.  It SURVIVED every
#    behavioural assertion on the first run of this stand, for a structural
#    reason: the loader synthesizes the neutral list FROM the damage rows, so
#    "neutrals non-empty => creep damage true" is an IDENTITY on this
#    instrument and no corpus frame can separate the conjuncts.  In the real
#    engine they are independent (vision is not damage), which is why the
#    conjunct stays.  test_pullchew_camp_commit.lua's world section carries the
#    identity check AND the label; do not quietly upgrade this line's status.

# ---------------------------------------------------------------------------
# M7: CONTROL ON THE WITNESS.  If the shipped safety predicate stopped saying
#     SAFE here, section 1's defect reading would be measuring nothing.
echo
echo "=== M7: J.IsLanePullSafe is made to refuse this frame (witness control) ==="
# The anchor carries the FUNCTION HEADER, not just the clause: `if J.GetHP( bot )
# < 0.5 then return false end` occurs three times in this file, and the first run
# of this stand correctly aborted on ANCHOR AMBIGUOUS rather than mutating an
# arbitrary one of them.  That abort is the guard working; the repair is a unique
# anchor, never a relaxed matcher.
sub "$LIB" $'function J.IsLanePullSafe( bot )\n\tif bot == nil or not bot:IsAlive() then return false end\n\tif J.GetHP( bot ) < 0.5 then return false end' \
           $'function J.IsLanePullSafe( bot )\n\tif bot == nil or not bot:IsAlive() then return false end\n\tif J.GetHP( bot ) < 0.9 then return false end'
score "M7" "no longer answers SAFE here"

# ---------------------------------------------------------------------------
# M8: CONTROL ON THE WORLD ASSUMPTION.  Install the synthesized neutral reader
#     globally; the opt-in pin must go red, or four other files that declare the
#     empty default are being overtaken in silence.
echo
echo "=== M8: the synthesized neutral reader is installed globally ==="
sub "$LOADER" "$OPTIN" $'      if true then'
score "M8" "installed WITHOUT the opt-in"

# ---------------------------------------------------------------------------
# M9: INSTRUMENT CONTROL on the radius pin.  Make one radius answer differently
#     and the "distance is not modelled" assertion must notice -- otherwise a
#     later reader could take a domain count through that constant as measured.
echo
echo "=== M9: the loader's neutral reader is made radius-aware (radius-pin control) ==="
# First written as a no-op comment appended to the constant, which SURVIVED --
# correctly, because it changed nothing.  The real control has to be aimed at the
# LOADER: the shipped reader takes no radius parameter at all, so nothing on the
# lever side can move that pin.  Give it a radius and the pin must notice, which
# is what makes "every radius answers alike" a measurement rather than a
# restatement of the mock's signature.
sub "$LOADER" $'        rawget(heroes[u.name], \'__spec\').GetNearbyNeutralCreeps = function()\n            return synth\n        end' \
              $'        rawget(heroes[u.name], \'__spec\').GetNearbyNeutralCreeps = function(_, r)\n            if (r or 0) < 1000 then return {} end\n            return synth\n        end'
score "M9" "distance became modelled"

# ---------------------------------------------------------------------------
# M10: the clause is moved BELOW the camp loop, where the reasoning in section 1
#      ("the same clause, asked about the other units") stops holding.
echo
echo "=== M10: the order pin -- the threat clause is renamed out of reach ==="
sub "$LIB" $'\tif #J.GetEnemiesNearLoc( bot:GetLocation(), 800 ) > 0 then return nil end' \
           $'\tif false then return nil end'
score "M10" "enemy-hero threat clause is gone"

# ---------------------------------------------------------------------------
# M11: a second soak id joins the gate line -- the `pullcad` shape, which
#      freezes the lever FALSE the day the other id is promoted.
echo
echo "=== M11: a second soak id is added to the gate line ==="
sub "$LIB" $'if J.IsSoakCandidate( \'pullchew\' ) and bot.roamCampPull == nil' \
           $'if J.IsSoakCandidate( \'pullchew\' ) and J.IsSoakCandidate( \'pullcamp\' ) and bot.roamCampPull == nil'
score "M11" "two soak ids on one line"

# ---------------------------------------------------------------------------
# M12: the predicate gates itself as well as being gated -- the caller then
#      cannot make it inert, and arming it touches two decisions.
echo
echo "=== M12: the predicate grows a gate of its own ==="
sub "$LIB" $'\tif bot == nil then return false end\n\tif not bot:WasRecentlyDamagedByCreep( PULL_CHEW_LOOKBACK ) then return false end' \
           $'\tif bot == nil then return false end\n\tif not J.IsSoakCandidate( \'pullchew\' ) then return false end\n\tif not bot:WasRecentlyDamagedByCreep( PULL_CHEW_LOOKBACK ) then return false end'
score "M12" "gates itself as well as being gated"

# ---------------------------------------------------------------------------
echo
echo "=== STAND RESULT ==="
echo "caught $CAUGHT / $TOTAL"
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN -- every mutant is seen by the file it is aimed at"
    exit 0
fi
echo "STAND RED -- at least one mutant is invisible to the tests"
exit 1
