#!/usr/bin/env bash
# Mutation stand for the 'hrparity' guard (strategy, 2026-09-09).
#
# The claim under test: "J.GetLaneHarassResponse decides whether the bot is
# outnumbered by comparing a 1100u enemy count against a 900u ally count, so an
# ally standing at 1000u is invisible while an enemy at the same spot is not;
# on 2 of 84 entered frames that biased comparison is the whole difference
# between conceding the lane and staying in it, and arming 'hrparity' turns
# exactly those into a non-retreat and never the other way."
#
# Run by hand when J.GetLaneHarassResponse, tests/_lanekill_domain_sweep.lua or
# tests/test_hrparity_guard.lua are edited, and before quoting any of these
# readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_hrreach.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a
#     mutant can never score "caught" for having applied to nothing, nor
#     "survived" for having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets -- not the one
#     the author hoped for (three legs of mutstand_dragnolane.sh's first draft
#     were WRONG MESSAGE for exactly that reason).
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507). Each leg costs ~33s (the test drives the whole
# 110-fixture corpus three times per entered frame), so budget ~7 minutes.
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M4 AND M5 ARE WHY THE TEST ASSERTS EQUALITY, NOT A LITERAL. M4 recounts
#     allies on the SHIPPED 900 (the guard is present, named, ordered correctly
#     -- and is the identity function); M5 recounts them on 1600 (a wider net
#     than the enemy side, which is a NEW POLICY, not the repair this id claims
#     to be). A test that asserted "the armed radius is >= 900", or that only
#     watched the flip count, would let one of the two through.
#   * M6 IS THE CROSS-CHECK LEG. `nOurs = 1 + #tValid` makes the outnumbered
#     test permanently false: every count still moves, the differential is
#     still non-zero, the direction columns still read zero. Only the SECOND
#     path to the domain -- population arithmetic done independently of the
#     drives -- separates "keys on the parity test" from "keys on nothing"
#     (the lesson M5 of mutstand_hrreach.sh taught at 0 == 54-54).
#   * M3 IS THE ORDER-BLIND ONE. The block is present, unique, names its id,
#     and is moved below the branch it was written to correct, where the
#     reassignment is dead. Existence checks all pass.
#   * M7 IS THE ZERO-VALUED COLUMN, varied by POLARITY not by name
#     (mutstand_fieldsip.sh's M8/M13): `hp_noparse` reads 0 on a clean tree, so
#     renaming its bump is an EQUIVALENT mutant -- the branch never executes.
#   * M8 IS THE ACCIDENTAL-PROMOTE RATCHET, and it is here because the pin it
#     replaces did not have it. The 'hrreach' round's section 5 asserted the
#     ally radius by matching the FIRST `GetNearbyHeroes( bot, N, false` in the
#     helper; this repair lands as a SECOND, gated read, so that pin stayed
#     green while the helper changed under it. A ratchet aimed at an ungated
#     edit cannot see a gated one -- and a gated one is the only kind this
#     group is allowed to write. M8 moves the SHIPPED default to 1100 (what an
#     accidental promote looks like) and must be caught.
#   * M9 DEFENDS THE WAVE RECOMMENDATION. The co-armed drive is what a wave
#     carrying both ids would measure; collapse it back to one id and the
#     "these frames end up standing and farming" claim becomes unsupported.
#   * M10 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_hrparity_guard.lua
SWEEP=tests/_lanekill_domain_sweep.lua

FILES=("$JMZ" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_hrparity.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_hrparity_guard > "$WORK/run.log" 2>&1
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
GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'hrparity\' )\n\tthen\n'
BLOCK=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'hrparity\' )\n\tthen\n\t\tlocal tAlliesEven = J.GetNearbyHeroes( bot, 1100, false, BOT_MODE_NONE )\n\t\tnOurs = 1 + ( tAlliesEven ~= nil and #tAlliesEven or 0 )\n\tend\n\n'
RECOUNT=$'\t\tlocal tAlliesEven = J.GetNearbyHeroes( bot, 1100, false, BOT_MODE_NONE )\n\t\tnOurs = 1 + ( tAlliesEven ~= nil and #tAlliesEven or 0 )\n'
ASSIGN=$'\t\tnOurs = 1 + ( tAlliesEven ~= nil and #tAlliesEven or 0 )\n'
# Two lines, not one: the bare `local tAllies = J.GetNearbyHeroes( bot, 900,
# false, ... )` line appears TWICE in jmz_func.lua, and the stand's ambiguity
# check refused the one-line form rather than mutating whichever came first
# (GH #550, exactly as it did on mutstand_hrreach.sh's M8).
SHIPPED_ALLY=$'\tlocal tAllies = J.GetNearbyHeroes( bot, 900, false, BOT_MODE_NONE )\n\tlocal nOurs = 1 + ( tAllies ~= nil and #tAllies or 0 )\n'
SHIPPED_TAIL=$'\treturn \'fire\', hWeakest\nend\n'
SWEEP_NOPARSE=$'                            if G.HR_PARITY_R == nil then\n                                bump(\'hp_noparse\')\n'
SWEEP_COARM=$'                        armed = { hrparity = true, hrreach = true }\n'
HDR=$'\t-- Soak candidate \'hrparity\' (2026-09-09). THE OUTNUMBERED TEST COMPARES\n'

# ---------------------------------------------------------------------------
echo
echo "=== mutants ==="

# M1 -- the guard is simply gone.  Armed must then equal shipped.
sub_or_die "$JMZ" "$BLOCK" ""
score "M1 guard deleted                 " \
    "armed, witness A still answers"

# M2 -- the gate is not a gate: the id conjunct is dropped, so the recount runs
# in every turbo game whether or not anything armed it.
sub_or_die "$JMZ" "$GATE" $'\tif J.IsModeTurbo()\n\tthen\n'
score "M2 id conjunct dropped           " \
    "turbo alone now changes the answer on"

# M3 -- ORDER BLIND.  The block is still present, still unique, still names its
# id; it is moved below the branch it corrects, where the recount is dead.
sub_or_die "$JMZ" "$BLOCK" ""
sub_or_die "$JMZ" "$SHIPPED_TAIL" "$BLOCK"$'\treturn \'fire\', hWeakest\nend\n'
score "M3 block moved below the branch  " \
    "sits BELOW the outnumbered test"

# M4 -- the armed radius is the SHIPPED one: the guard is the identity function
# and the asymmetry it claims to remove is untouched.
sub_or_die "$JMZ" "$RECOUNT" $'\t\tlocal tAlliesEven = J.GetNearbyHeroes( bot, 900, false, BOT_MODE_NONE )\n\t\tnOurs = 1 + ( tAlliesEven ~= nil and #tAlliesEven or 0 )\n'
score "M4 armed radius back to 900      " \
    "the guard reads allies at 900 but enemies at 1100"

# M5 -- the armed radius OVERSHOOTS the enemy radius.  Not a symmetrisation any
# more but a new policy ("help two screens away counts"), which is the thing
# this id promises it is not.
sub_or_die "$JMZ" "$RECOUNT" $'\t\tlocal tAlliesEven = J.GetNearbyHeroes( bot, 1600, false, BOT_MODE_NONE )\n\t\tnOurs = 1 + ( tAlliesEven ~= nil and #tAlliesEven or 0 )\n'
score "M5 armed radius overshoots (1600)" \
    "the guard reads allies at 1600 but enemies at 1100"

# M6 -- THE CROSS-CHECK LEG.  The 1100 ally read STAYS (so the census still
# parses a radius and still predicts 2 flips); only the assignment is replaced,
# making the outnumbered test permanently false.  Every direction column still
# reads zero and the differential is still non-zero -- the two paths to the
# domain disagreeing is the only thing that can see it.
sub_or_die "$JMZ" "$ASSIGN" $'\t\tnOurs = 1 + #tValid\n'
score "M6 recount replaced by a tie     " \
    "the two paths to the domain disagree"

# M7 -- ZERO-VALUED COLUMN, varied by POLARITY (renaming the bump of a branch
# that never executes is an equivalent mutant).
sub_or_die "$SWEEP" "$SWEEP_NOPARSE" $'                            if G.HR_PARITY_R ~= nil then\n                                bump(\'hp_noparse\')\n'
score "M7 hp_noparse polarity flipped   " \
    "the census fell back on an unparsed parity radius"

# M8 -- THE ACCIDENTAL-PROMOTE RATCHET.  The repair leaves its gate and becomes
# the shipped default.  This is the mutant the hrreach round's section-5 pin
# could not see (it matched the FIRST ally read, which a gated repair leaves in
# place); catching it is the reason that pin was rewritten.
sub_or_die "$JMZ" "$SHIPPED_ALLY" $'\tlocal tAllies = J.GetNearbyHeroes( bot, 1100, false, BOT_MODE_NONE )\n\tlocal nOurs = 1 + ( tAllies ~= nil and #tAllies or 0 )\n'
score "M8 repair ungated (silent promote)" \
    "the shipped ally radius now equals the enemy radius"

# M9 -- the co-armed drive is collapsed back to one id, so the pair reading the
# wave recommendation rests on is no longer being taken.
sub_or_die "$SWEEP" "$SWEEP_COARM" $'                        armed = { hrparity = true }\n'
score "M9 co-arm drive collapsed        " \
    "un-retreated frames end as nil with both ids armed"

# M10 -- CONTROL.  A comment-only edit must survive.
sub_or_die "$JMZ" "$HDR" $'\t-- Soak candidate \'hrparity\' (2026-09-09). The outnumbered test compares\n'
score_control "M10 comment-only edit (control)  "

# ---------------------------------------------------------------------------
echo
echo "=== stand summary ==="
echo "legs=$TOTAL  caught=$CAUGHT  survived=$SURVIVED"
if [ "$SURVIVED" -eq 0 ]; then
    echo "STAND GREEN -- every mutant is visible to tests/test_hrparity_guard.lua"
    exit 0
fi
echo "STAND RED -- $SURVIVED mutant(s) are invisible; the readings above are"
echo "             not yet defended by an assertion that would notice them."
exit 1
