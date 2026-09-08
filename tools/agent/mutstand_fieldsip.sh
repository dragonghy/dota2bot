#!/usr/bin/env bash
# Mutation stand for the FOURTH census -- the pricing of 'fieldsip', the third
# leg of the registered promote atom 'field_hold_needs_magnitude' (strategy,
# 2026-09-08, OWNER_PRIORITIES P2 + P4.4(ii)).
#
# The claim under test: "co-arming 'fieldsip' with either hold leg kills that
# leg's ENTIRE live domain (19/19 and 2/2), while transferring exactly those
# frames to the supply side (22 == 22), and above 540 max health the armed
# predicate is a salve-only presence test rather than a magnitude one."
#
# Run by hand when tests/_tpquiet_sweep.lua, tests/test_fieldsip_atom_pricing.lua,
# J.IsFieldSipEnough, J.FieldRegenSipValue, J.ShouldRegenNotGoHome, the
# J.FIELD_SIP_* constants or any J.ShouldFieldBuyRegen* consumer are edited, and
# before quoting any of these readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_retreatveto.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a
#     mutant can never score "caught" for having applied to nothing, nor
#     "survived" for having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets, not the one
#     the author hoped for (the retreat-veto stand's M2 finding).
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507 -- and the buydeep round got bitten by it once).
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE, and why they are not the
# obvious ones:
#   * M3 IS THE ORDER-BLIND ONE. Move the sip guard from LAST to FIRST inside
#     J.ShouldRegenNotGoHome. The predicate is a pure conjunction of
#     side-effect-free tests, so EVERY corpus counter is byte-identical -- 19,
#     22, 0, all of them -- and only the "appended, never inserted" pin can see
#     it. A census that had checked its claims by counting alone would call this
#     tree unchanged.
#   * M10 IS THE ONE WHOSE DANGEROUS DIRECTION IS THE TIDY-LOOKING ONE. The
#     killed-set bar column already reads 19/19, so TIGHTENING it is invisible.
#     Swapping SIP_NONFLASK_MAX_BAR for SIP_FLASK_MAX_BAR looks like "use the
#     bar" cleanup and collapses the salve-only reading to 0. Same shape as the
#     previous stand's M10: the visible direction is not the one you reach for.
#   * M8/M13 ARE THE TWO HALVES OF ONE LESSON ABOUT ZERO-VALUED COLUMNS, and it
#     cost two batteries to get right. The first M8 renamed the `bump()` for
#     `fs_sf2_live_survives` -- a column whose clean value is 0 -- and SURVIVED
#     with `must()` sitting directly on that counter. Two things stack up:
#       (1) the sweep ZERO-INITIALISES every bucket (GH #171, so "never reached"
#           and "measured zero" differ to the parser), so a rename cannot make a
#           key VANISH; it can only ADD one. ⇒ the guard a zero-valued column
#           needs is a CLOSURE CHECK ON THE KEY SET, not a nil check on one key.
#           M13 is that leg: it renames a bump that DOES fire, so the new key
#           actually appears and the closure check has something to see.
#       (2) but `fs_sf2_live_survives`'s bump never EXECUTES at all -- its zero
#           is a dead branch, not an empty tally -- so renaming it added no key
#           either and the mutant was simply EQUIVALENT. Nothing key-based can
#           ever see a change to a branch that never runs. What CAN be checked
#           is that the branch's two outcomes are exhaustive over the live set,
#           so M8 now flips the branch's POLARITY instead of its name.
#     ⇒ "a counter reads 0" and "a counter was read and came back 0" are still
#     two different claims, and a third case -- "the branch that writes it never
#     ran" -- is invisible to both `must()` and the closure check.
#   * M11 IS THE ONE THAT MAKES THE PARTITION CHECK LIE WHILE LOOKING LIKE A
#     CLEANUP. Read the partition off the SHIPPED hold answer instead of the
#     armed one ("use the shipped predicate"): the check stops being about the
#     armed configuration, which is the only configuration it was ever about.
#   * M12 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_fieldsip_atom_pricing.lua
SWEEP=tests/_tpquiet_sweep.lua

FILES=("$JMZ" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_fieldsip.XXXXXX")
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
    lua5.1 tests/run_tests.lua fieldsip_atom_pricing > "$WORK/run.log" 2>&1
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
MINFRAC='J.FIELD_SIP_MIN_FRACTION = 0.25'
FAERIE=$'\titem_faerie_fire  =  85,\n'
GATE=$'\tif not J.IsSoakCandidate( \'fieldsip\' ) then return true end\n'
HOLDFN=$'function J.ShouldRegenNotGoHome( bot )\n\tif not J.IsFieldRegenSituation( bot ) then return false end\n\tif not J.HasFieldRegenSource( bot ) then return false end\n\t-- [fieldsip] Appended, never inserted: unarmed this line is the literal\n\t-- `true`, so the clause order and the shipped answer above are unchanged.\n\tif not J.IsFieldSipEnough( bot ) then return false end\n\n\treturn true\nend\n'
HOLDFN_FIRST=$'function J.ShouldRegenNotGoHome( bot )\n\tif not J.IsFieldSipEnough( bot ) then return false end\n\tif not J.IsFieldRegenSituation( bot ) then return false end\n\tif not J.HasFieldRegenSource( bot ) then return false end\n\n\treturn true\nend\n'
HOLDFN_NOSIP=$'function J.ShouldRegenNotGoHome( bot )\n\tif not J.IsFieldRegenSituation( bot ) then return false end\n\tif not J.HasFieldRegenSource( bot ) then return false end\n\n\treturn true\nend\n'
# ⚠️ The bare sip conjunction line occurs TWICE in jmz_func (the ring arm and
# the deep arm), so it is made unique by carrying the ring helper's own gate.
RINGGATE=$'function J.ShouldFieldBuyRegenRing( bot )\n\tif not J.IsSoakCandidate( \'buyring\' ) then return false end\n'
SWAPTALLY=$'                        tally(hold_sip, hold_bare, \'fs_hold_kills_swapped\', \'fs_hold_gains_swapped\')\n'
KILLBAR=$'                                if nMaxHP ~= nil and nMaxHP > G.SIP_NONFLASK_MAX_BAR then\n'
PARTITION=$'                            if hold_sip and buy_pair then bump(\'fs_partition_both\') end\n'
SURVIVES=$'                            if sf2_pair then bump(\'fs_sf2_live_survives\')\n'
SIPBODY=$'\treturn J.FieldRegenSipValue( bot ) >= J.FIELD_SIP_MIN_FRACTION * nMax\n'

# ---------------------------------------------------------------------------
# M1: the bar's denominator moves.  Everything downstream of this census is a
#     quotient with it, so a silent retune of the family would re-baseline every
#     number this file publishes without anybody noticing.
echo "=== M1: FIELD_SIP_MIN_FRACTION 0.25 -> 0.10 ==="
sub_or_die "$JMZ" "$MINFRAC" 'J.FIELD_SIP_MIN_FRACTION = 0.10'
score "M1" "the non-flask bar moved to"

# M2: the largest NON-flask sip becomes the largest sip outright.  The two bars
#     cross, the "salve and only a salve" band goes empty, and the killed-set
#     reading loses its meaning while every structural count still holds.
echo "=== M2: item_faerie_fire 85 -> 500 (max non-flask now exceeds the flask) ==="
sub_or_die "$JMZ" "$FAERIE" $'\titem_faerie_fire  =  500,\n'
score "M2" "the flask / largest-non-flask heals moved to"

# M3 ⭐ THE ORDER-BLIND ONE.  Sip guard moved from LAST to FIRST.  A pure
#     conjunction of side-effect-free predicates: every corpus counter is
#     byte-identical and only the structural pin can see it.
echo "=== M3: the sip guard is INSERTED first instead of appended last ==="
sub_or_die "$JMZ" "$HOLDFN" "$HOLDFN_FIRST"
score "M3" "no longer the LAST guard"

# M4: the hold side stops consuming the sip test altogether.  The headline
#     collapses to zero kills, and the swapped-tally leg must also notice that
#     its non-zero side went quiet.
echo "=== M4: J.IsFieldSipEnough removed from the hold predicate ==="
sub_or_die "$JMZ" "$HOLDFN" "$HOLDFN_NOSIP"
score "M4" "the transfer moved to"

# M5: the gate fails CLOSED.  This is the 'wandbleed2' trap in its other
#     direction: unarmed the helper would answer FALSE, so the shipped hold
#     would silently narrow in every real game -- the exact thing "gated means
#     inert until promoted" promises cannot happen.
echo "=== M5: the fieldsip gate fails CLOSED (return true -> return false) ==="
sub_or_die "$JMZ" "$GATE" $'\tif not J.IsSoakCandidate( \'fieldsip\' ) then return false end\n'
score "M5" "no longer opens with a fail-OPEN gate"

# M6: one of the five supply consumers stops asking the magnitude question.
#     The hold/buy split stops adding up to the call-site count -- i.e. this
#     census's model of where the id lives goes stale.
echo "=== M6: the ring buy-arm drops its sip conjunct ==="
sub_or_die "$JMZ" $'\tif J.HasFieldRegenSource( bot ) and J.IsFieldSipEnough( bot ) then\n\t\treturn false\n\tend\n\n\treturn true\nend\n\n-- [buydeep' $'\tif J.HasFieldRegenSource( bot ) then\n\t\treturn false\n\tend\n\n\treturn true\nend\n\n-- [buydeep'
# ⚠️ The `want` is the FIRST assertion the reader actually reaches, not the one
# the mutant is aimed at: dropping the conjunct also drops a call site, and the
# call-site count is asserted before the buy-consumer count in the same test.
# The first battery had this leg's `want` set to the buy-consumer sentence and
# scored it "RED with the WRONG MESSAGE" -- the stand waiting on a line the code
# does not emit, which is the retreat-veto stand's M2 lesson recurring.
score "M6" "call sites, not 6"

# M7: one supply consumer's OWN gate moves BELOW the sip call.  That ordering is
#     the entire reason "armed alone, this id is hold-side-only" is a structural
#     fact rather than a corpus coincidence.
echo "=== M7: the ring buy-arm's own gate is moved below its sip call ==="
sub_or_die "$JMZ" "$RINGGATE" $'function J.ShouldFieldBuyRegenRing( bot )\n'
score "M7" "put their own IsSoakCandidate gate UPSTREAM"

# M8 ⭐ THE MISSING-KEY ONE (GH #171), aimed at a column whose clean value is 0.
#     Renaming a bumped counter only makes it read 0 and an `== 19` catches it
#     as an ordinary failure.  `fs_sf2_live_survives` is 0 on a clean tree, so a
#     rename makes the KEY vanish and `nil` reaches the assertion -- only
#     `must()` can tell "never measured" from "measured zero".
echo "=== M8: the survivor/killed branch has its POLARITY flipped ==="
sub_or_die "$SWEEP" "$SURVIVES" $'                            if not sf2_pair then bump(\'fs_sf2_live_survives\')\n'
score "M8" "live 'stayfield2' frames. The finding"

# M13: the counterpart, aimed at the closure check itself -- a renamed bump on a
#      column that DOES fire. `fs_sf2_live_killed` stays present (zero-init) and
#      reads 0 while a NEW key carries the 19, so the only visible trace is the
#      extra key. Scored on the closure message specifically, which is why the
#      declared-columns test is named to sort ahead of the headline.
echo "=== M13: a FIRING bump is renamed (the closure check's own leg) ==="
sub_or_die "$SWEEP" $'                                bump(\'fs_sf2_live_killed\')\n' $'                                bump(\'fs_sf2_live_killedX\')\n'
score "M13" "UNDECLARED fourth-census column"

# M9: the swapped tally is deleted.  `fs_hold_gains == 0` then rests on nothing
#     -- a counter whose content is all zeros cannot tell "the direction holds"
#     from "the tally never ran".
echo "=== M9: the swapped hold tally is removed ==="
sub_or_die "$SWEEP" "$SWAPTALLY" ''
score "M9" "The zero above is only evidence if"

# M10 ⭐ THE TIDY-LOOKING DIRECTION.  The killed-set column already reads 19/19,
#      so tightening it is invisible; swapping in the OTHER parsed bar reads as
#      "use the bar" and collapses the salve-only reading to zero.
echo "=== M10: the killed-set column is read against the FLASK bar instead ==="
sub_or_die "$SWEEP" "$KILLBAR" $'                                if nMaxHP ~= nil and nMaxHP > G.SIP_FLASK_MAX_BAR then\n'
score "M10" "killed frames sit ABOVE the non-flask bar"

# M11 ⭐ THE PARTITION CHECK MADE VACUOUS BY A CLEANUP.  Reading the partition
#      off the SHIPPED hold answer instead of the armed one looks like a
#      simplification and stops the check being about the armed configuration --
#      the only configuration it was ever about.
echo "=== M11: the partition is read off the shipped hold instead of the armed one ==="
sub_or_die "$SWEEP" "$PARTITION" $'                            if hold_bare and buy_pair then bump(\'fs_partition_both\') end\n'
score "M11" "armed frame(s) have the hold AND the buy both"

# M12: CONTROL.  A comment-only edit inside the helper this census is about.
#      It must SURVIVE -- otherwise the stand is scoring the act of editing.
echo "=== M12 (CONTROL): comment-only edit ==="
sub_or_die "$JMZ" '-- Gated on soak candidate '"'"'fieldsip'"'"'. UNARMED IT IS THE LITERAL' '-- CONTROL EDIT (mutstand_fieldsip.sh). Gated on '"'"'fieldsip'"'"'. UNARMED IT IS THE LITERAL'
score_control "M12"

echo
echo "=== stand summary ==="
echo "legs $TOTAL  caught $CAUGHT  survived $SURVIVED"
if [ "$SURVIVED" -ne 0 ]; then
    echo "STAND RED -- $SURVIVED leg(s) the assertions cannot see"
    exit 1
fi
echo "STAND GREEN -- every leg scored as designed"
exit 0
