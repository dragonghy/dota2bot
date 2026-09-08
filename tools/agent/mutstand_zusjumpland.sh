#!/usr/bin/env bash
# Mutation stand for the `zusjumpland` candidate -- the reach term on
# X.ConsiderE's 进攻 firing point, which measures Heavenly Jump's target from the
# hop's TAKE-OFF point while the shockwave that is the whole payoff is searched
# from the LANDING point (hero, 2026-09-08, OWNER_PRIORITIES P4.4 (i)).  Run by
# hand when X.zuus_IsJumpTargetInShockwaveReach, X.ConsiderE or
# tests/test_zuus_jump_landing_reach.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmlaneband.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring
#     (and an aborted mutant is NOT a surviving mutant -- the 2026-09-08 Axe
#     stand scored one as SURVIVED and reported 10/11 for a 11/11 stand);
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.  In a double-quoted bash string
#     that is command substitution.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).  This stream self-caught that overlap on 2026-09-08.
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M5 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, armed path hands back the shipped answer.  Inert in every wave,
#     and the verdict reads back "tested, no effect".
#   * M7 is the same thing wearing this lever's own arithmetic: read 0 instead of
#     hop_distance and the landing point collapses onto the bot, so the armed
#     branch is byte-equivalent to shipped WHILE STILL COMPUTING A LANDING POINT.
#     This is the one a reader is least likely to spot by eye.
#   * M4 is the WIDENING.  Unlike `cmlaneband` (whose shipped answer was an
#     unconditional true, making a superset mutant inexpressible), this lever's
#     shipped answer is a real predicate -- so dropping the shipped guard and
#     measuring only from the landing point ADMITS targets the shipped term
#     refuses.  §0.2 (b) of the test promises this mutant exists; here it is.
#   * M3 is the INVERSION: armed refuses exactly the hops that connect.
#   * M8 keeps a landing-point measurement that no longer means what its note
#     says -- a slack that gives back precisely what the lever took.
#   * M9 is a control on the STAND ITSELF: a census that cannot go red is not a
#     limit, it is a sentence.
#   * M10 is the pullcad trap (AGENTS.md) in its native habitat -- conjoining a
#     sibling id THIS VERY FILE already calls (`zusbind`), which would freeze
#     this gate FALSE the day that sibling is promoted.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_zuus.lua
TEST=tests/test_zuus_jump_landing_reach.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zjl.XXXXXX")
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

# The filter is `zuus`, not this one file: the sibling Zeus assertions read the
# same hero module, and a stand scoped to the new file alone would report a
# collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua zuus > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of two identical sites scores "survived" for the
# wrong reason.
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

SHIPPEDLINE="	if not J.IsInRange( hBot, hTarget, nSearchRadius ) then return false end"
GATELINE="	if J.IsModeTurbo() and J.IsSoakCandidate( 'zusjumpland' )"
HOPLINE="		local nHop = hAbility:GetSpecialValueInt( 'hop_distance' )"
LANDLINE="		return GetUnitToLocationDistance( hTarget, vLanding ) <= nSearchRadius"
CALLSITE="			and X.zuus_IsJumpTargetInShockwaveReach( bot, targetHero, abilityE, nCastRange )
"
CENSUS="                        if GetUnitToUnitDistance(bot, e) > nRange - nHop then"

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
# M1: the candidate check is dropped.  The narrowing becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATELINE" "	if J.IsModeTurbo()"
score "M1" "gate off diverged from J.IsInRange"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1;
#     only the explicit non-turbo case in section 5 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "$GATELINE" "	if J.IsSoakCandidate( 'zusjumpland' )"
score "M2" "the lever fires outside Turbo"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed refuses exactly the hops that carry
#     the target into the shockwave and accepts the ones that leave it behind --
#     the opposite of every sentence written about it, while staying gated,
#     wired and turbo-only.
echo
echo "=== M3: the landing-point test is inverted ==="
sub "$HERO" "$LANDLINE" "		return GetUnitToLocationDistance( hTarget, vLanding ) > nSearchRadius"
score "M3" "armed answered"

# ---------------------------------------------------------------------------
# M4: THE WIDENING.  The shipped guard is dropped and only the landing-point
#     test remains.  Armed then ADMITS targets the shipped term refuses (a hop
#     that carries the bot toward a target outside nSearchRadius), so the id
#     stops being a strict narrowing -- and a negative batch reading could no
#     longer be attributed to "casts this removed".
echo
echo "=== M4: the shipped guard is dropped, so armed can widen ==="
sub "$HERO" "$SHIPPEDLINE" ""
score "M4" "armed admitted a target the shipped term refuses"

# ---------------------------------------------------------------------------
# M5: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped answer anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M5: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "$LANDLINE" "		return true"
score "M5" "armed still queued Heavenly Jump"

# ---------------------------------------------------------------------------
# M6: THE CALL SITE IS REMOVED.  The helper, its note, its id registration and
#     its unit tests all survive; the 进攻 branch goes back to measuring from the
#     take-off point.
echo
echo "=== M6: the 进攻 branch stops routing through the helper ==="
sub "$HERO" "$CALLSITE" "			and J.IsInRange( bot, targetHero, nCastRange )
"
score "M6" "the helper is called at 0 firing points"

# ---------------------------------------------------------------------------
# M7: DEAD WIRING WEARING THIS LEVER'S OWN ARITHMETIC.  The hop is read as 0
#     instead of off the KV, so the landing point collapses onto the bot and the
#     armed branch is byte-equivalent to shipped -- while still computing a
#     landing point, still naming the id, still passing every gate-plumbing
#     check.  This is the mutant a reader is least likely to catch by eye, and
#     the reason the helper's degeneracy case is asserted rather than assumed.
echo
echo "=== M7: hop_distance is read as 0, so the landing point is the bot ==="
sub "$HERO" "$HOPLINE" "		local nHop = 0"
score "M7" "armed still queued Heavenly Jump"

# ---------------------------------------------------------------------------
# M8: A SLACK THAT GIVES BACK WHAT THE LEVER TOOK.  The measurement moves to the
#     landing point -- correct -- and then the radius is widened by the same hop
#     distance, so every target the shipped term admits is admitted again.  The
#     note above the helper stays true sentence by sentence and the lever is
#     still inert.
echo
echo "=== M8: the radius is widened by the hop, undoing the narrowing ==="
sub "$HERO" "$LANDLINE" "		return GetUnitToLocationDistance( hTarget, vLanding ) <= nSearchRadius + nHop"
score "M8" "armed still queued Heavenly Jump"

# ---------------------------------------------------------------------------
# M9: A CONTROL ON THE STAND ITSELF.  The section 1 census stops distinguishing
#     the band from the direction-proof sightings.  If this survives, the domain
#     numbers in section 0.3 are prose, not a reading.
echo
echo "=== M9: the census stops separating band from direction-proof ==="
sub "$TEST" "$CENSUS" "                        if GetUnitToUnitDistance(bot, e) > 0 then"
score "M9" "the geometry moved"

# ---------------------------------------------------------------------------
# M10: THE PULLCAD TRAP (AGENTS.md).  The gate is conjoined with a sibling id
#      this same file already calls.  Written this way the dependency looks like
#      code rather than prose -- and it freezes this gate FALSE on the day
#      `zusbind` is promoted, because a promoted id appears in no armed string.
#      check_armed_wiring.py still reports WIRED (it checks that a call site
#      exists, not that the predicate can ever be true), and the verdict reads
#      back "tested, no effect" with nothing raising a hand.
echo
echo "=== M10: the gate is conjoined with a sibling id (pullcad trap) ==="
sub "$HERO" "$GATELINE" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'zusjumpland' ) and J.IsSoakCandidate( 'zusbind' )"
score "M10" "does not fire the lever -- it is conjoined with"

# ---------------------------------------------------------------------------
echo
echo "=== score ==="
echo "$CAUGHT/$TOTAL caught"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
