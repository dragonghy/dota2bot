#!/usr/bin/env bash
# Mutation stand for the 'deepnum' guard (strategy, 2026-09-09).
#
# The claim under test: "J.IsLaneFrontTooDeepToHold's DEEP tier decides whether
# we out-number them at a spot by comparing an ally count taken on the SHALLOW
# tier's 1000u disc against an enemy count taken on 1600u, so an ally at 1300 is
# off the board while an enemy at the same 1300 is a besieger; on 2 of the 84
# deep-tier frames in this corpus that biased comparison is the whole difference
# between abandoning the front and holding it, and arming 'deepnum' turns
# exactly those into a hold and never the other way."
#
# Run by hand when J.IsLaneFrontTooDeepToHold, tests/_lanekill_domain_sweep.lua
# or tests/test_deepnum_parity.lua are edited, and before quoting any of these
# readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_hrparity.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a
#     mutant can never score "caught" for having applied to nothing, nor
#     "survived" for having run the baseline (GH #550);
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK (GH
# #507). Each leg costs ~40s (the test drives the whole fixture corpus once for
# the manifest and four more times for the named witnesses), so budget ~8 min.
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * M4 AND M5 ARE WHY THE TEST ASSERTS EQUALITY, NOT A LITERAL. M4 recounts
#     allies on the SHIPPED 1000 (present, named, correctly ordered -- and the
#     identity function); M5 recounts them on 2400 (a WIDER net than the enemy
#     side, which is a new policy, not the repair this id claims to be). A test
#     that asserted "the armed radius is >= 1000", or that only watched the flip
#     count, would let one of the two through.
#   * M3 IS THE ORDER/EFFECT-BLIND ONE. The block is present, unique, named and
#     correctly placed, and it discards the count it just computed. Existence
#     and placement checks all pass; only the two-route cross-check sees it.
#   * M6 IS THE BOUND LEG. Returning a constant false makes the armed drive
#     abandon nothing anywhere: dn_closes jumps to every shipped true. Only the
#     ARITHMETIC path -- populations counted independently of the drive --
#     bounds that, which is why section 3 asserts dn_closes <= dn_disc_differs
#     as a BOUND and not as an equality it would be a coincidence to satisfy.
#   * M7 IS WHY THERE ARE NEGATIVE CONTROLS. `<` instead of `<=` still repairs
#     the parity, still flips both witnesses, and still reads zero in the
#     forbidden direction -- but it also stops the bot abandoning a front it is
#     genuinely losing 2v2. Only a frame chosen because the guard must NOT
#     change it can tell "narrowed" from "loosened".
#   * M8 IS THE ACCIDENTAL-PROMOTE RATCHET (the M12 lesson from the 'hrparity'
#     round: a pin aimed at an ungated edit cannot see a gated one, and a gated
#     one is the only kind this group is allowed to write). It moves the SHIPPED
#     default to 1600 -- what a silent promote looks like -- and must be caught.
#   * M9 DEFENDS THE REASON THIS ID EXISTS AT ALL. The premise of the whole
#     round is that this helper is NOT armed-only: bCustomLastHit in
#     mode_laning_generic.lua is true for override-module heroes with nothing
#     armed. Break that premise and the 0OVERCHASE rule would apply instead
#     (inherit the host's gate, add no id), so a pin has to watch it.
#   * M10 IS THE ZERO-VALUED-COLUMN LEG done by DISCONNECTION, not by rename:
#     dn_disc_differs is a genuinely non-zero column, so removing its bump is a
#     real mutant and not an equivalent one.
#   * M11 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit.

set -u

JMZ=bots/FunLib/jmz_func.lua
MODE=bots/mode_laning_generic.lua
TEST=tests/test_deepnum_parity.lua
SWEEP=tests/_lanekill_domain_sweep.lua

FILES=("$JMZ" "$MODE" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_deepnum.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_deepnum_parity > "$WORK/run.log" 2>&1
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
GATE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'deepnum\' ) then\n'
BLOCK=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'deepnum\' ) then\n\t\tlocal nWide = 0\n\t\tlocal tWide = J.GetNearbyHeroes( bot, 1600, false, BOT_MODE_NONE )\n\t\tfor _, a in pairs( tWide or {} ) do\n\t\t\tif J.IsValidHero( a ) then nWide = nWide + 1 end\n\t\tend\n\t\treturn ( 1 + nWide ) <= nEnemies\n\tend\n'
SHIPPED_RET=$'\treturn ( 1 + nAllies ) <= nEnemies\nend\n'
ARMED_R=$'\t\tlocal tWide = J.GetNearbyHeroes( bot, 1600, false, BOT_MODE_NONE )\n'
ARMED_RET=$'\t\treturn ( 1 + nWide ) <= nEnemies\n'
# TWO lines, not one: the bare `local tAllies = J.GetNearbyHeroes( bot, 1000,
# false, ... )` line appears TWICE in jmz_func.lua and the ambiguity check
# refused the one-line form rather than mutating whichever came first (GH #550).
SHIPPED_ALLY=$'\tlocal nAllies = 0\n\tlocal tAllies = J.GetNearbyHeroes( bot, 1000, false, BOT_MODE_NONE )\n'
MODE_FLAG=$'local bCustomLastHit = local_mode_laning_generic\n'
SWEEP_DISC=$'                            if nWide > nNear then bump(\'dn_disc_differs\') end\n'
HDR=$'-- [deepnum 2026-09-09] THE DEEP TIER COMPARES TWO COUNTS TAKEN WITH TWO\n'

# ---------------------------------------------------------------------------
echo
echo "=== mutants ==="

# M1 -- the guard is simply gone.  Armed must then equal shipped everywhere.
sub_or_die "$JMZ" "$BLOCK" ""
score "M1 guard deleted                 " \
    "the shipped helper no longer names 'deepnum'"

# M2 -- the gate is not a gate: the id conjunct is dropped, so the recount runs
# in every turbo game whether or not anything armed it.  This helper is NOT
# armed-only, so that is a live shipped behaviour change.
sub_or_die "$JMZ" "$GATE" $'\tif J.IsModeTurbo() then\n'
score "M2 id conjunct dropped           " \
    "the deepnum branch is no longer"

# M3 -- DEAD RECOUNT.  The block is present, unique, names its id and sits in
# the right place; it computes the wider count and THROWS IT AWAY, falling
# through to the shipped return.  Every existence and placement check passes.
#
# ⚠️ THIS IS THE SECOND FORMULATION, and the first one is recorded rather than
# quietly replaced. M3 originally moved the whole block BELOW the shipped
# `return`, which in Lua is a SYNTAX ERROR (a return must end its block): the
# leg went red, but for "the fixture would not load", which is a message no
# reader can act on -- the stand scored it WRONG MESSAGE and counted it as
# survived, which is exactly what that scoring rule is for.
sub_or_die "$JMZ" "$ARMED_RET" ""
score "M3 recount computed, discarded   " \
    "the guard is not keying on the parity test"

# M4 -- the recount happens on the SHIPPED disc: the guard exists, is named,
# is ordered correctly, and is the identity function.
sub_or_die "$JMZ" "$ARMED_R" \
    $'\t\tlocal tWide = J.GetNearbyHeroes( bot, 1000, false, BOT_MODE_NONE )\n'
score "M4 armed radius back to shipped  " \
    "it exists to put both sides of the numbers test on ONE ruler"

# M5 -- the recount OVERSHOOTS the enemy disc.  Still a differential, still
# non-zero, still one-directional -- and no longer a parity repair.
sub_or_die "$JMZ" "$ARMED_R" \
    $'\t\tlocal tWide = J.GetNearbyHeroes( bot, 2400, false, BOT_MODE_NONE )\n'
score "M5 armed radius overshoots 2400  " \
    "it exists to put both sides of the numbers test on ONE ruler"

# M6 -- the armed branch stops comparing anything.  Every shipped true becomes
# an armed false; only the arithmetic bound can say that is too many.
sub_or_die "$JMZ" "$ARMED_RET" $'\t\treturn false\n'
score "M6 armed branch returns constant " \
    "impossible, so the"

# M7 -- strictly-greater instead of not-less.  Repairs the parity, flips both
# witnesses, reads zero in the forbidden direction -- and also stops the bot
# leaving a front it is losing at parity.  Only the negative controls see it.
sub_or_die "$JMZ" "$ARMED_RET" $'\t\treturn ( 1 + nWide ) < nEnemies\n'
score "M7 <= weakened to <               " \
    "the guard is not narrowing, it is"

# M8 -- ACCIDENTAL PROMOTE: the shipped default quietly moves to the armed
# radius, so the repair is live for every bot that reaches this helper.
sub_or_die "$JMZ" "$SHIPPED_ALLY" \
    $'\tlocal nAllies = 0\n\tlocal tAllies = J.GetNearbyHeroes( bot, 1600, false, BOT_MODE_NONE )\n'
score "M8 shipped default promoted      " \
    "the repair has left its gate"

# M9 -- the premise: bCustomLastHit stops being an ungated disjunct, which is
# the whole reason this repair carries its own id instead of inheriting one.
sub_or_die "$MODE" "$MODE_FLAG" $'local bCustomLastHit = false\n'
score "M9 host premise broken           " \
    "no longer keys on the override module"

# M10 -- the instrument: the column that proves the two discs really differ on
# this corpus (i.e. that the loader answers the radius question) is
# disconnected.  A genuinely non-zero column, so this is not an equivalent
# mutant.
#
# ⚠️ SECOND FORMULATION OF THE `want`, AND THE REASON IS THE SWEEP'S OWN
# DESIGN. The first draft expected "the sweep did not report counter
# dn_disc_differs" -- but every counter in this census is ZERO-INITIALISED on
# purpose (the GH #171 shape: "never reached" and "measured zero" must not look
# alike), so cutting the bump yields a reported 0, not a missing key. The
# message the reader actually gets is the loader-vs-tree one, and that is what
# this leg now demands.
sub_or_die "$SWEEP" "$SWEEP_DISC" ""
score "M10 disc-differs column cut      " \
    "this census is measuring the loader, not the tree"

# M11 -- CONTROL.  A comment-only edit must survive.
sub_or_die "$JMZ" "$HDR" $'-- [deepnum 2026-09-09] (comment reflowed by the mutation stand control leg)\n'
score_control "M11 comment-only control         "

# ---------------------------------------------------------------------------
echo
echo "=== stand summary ==="
echo "legs $TOTAL  caught $CAUGHT  survived $SURVIVED"
if [ "$SURVIVED" -eq 0 ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED -- $SURVIVED leg(s) the guard's tests cannot see"
exit 1
