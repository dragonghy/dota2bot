#!/usr/bin/env bash
# Mutation stand for the `lionwreach` candidate -- the reach term on
# X.ConsiderW's 打断 (interrupt) firing point, the one reader of that function's
# nCastRange + 300 ring that carries no distance term at all while its own twin,
# eleven lines below in the SAME `if` body, spells `J.IsInRange( bot, npcEnemy,
# nCastRange + 50 )` (hero, 2026-09-12, OWNER_PRIORITIES P4.4 (i)).  Run by hand
# when X.lion_IsInterruptTargetInReach, X.ConsiderW or
# tests/test_lion_hex_interrupt_reach.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axebhreach.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution);
#   * every `want` is the FIRST thing the mutant makes the suite say.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, armed hands back the shipped answer -- inert in every wave, and
#     the verdict reads back "tested, no effect".
#   * M3 is the INVERSION: armed refuses the reachable channeller and keeps the
#     band one, the exact opposite of every sentence written about it.
#   * M6/M7/M10 are the three ways to keep a reach term that no longer means
#     what its note says: the bound loosened back to the ring, the passed-in
#     nCastRange swapped for the constant that is right on ONE frame (this is
#     why frame B carries a different Hex rank and no Aether Lens), and the
#     named slack silently moved off the sibling's own 50.
#   * ⭐ M11 is the SCOPE mutant and it is the subtle one: move the SAME
#     conjunct onto the sibling sub-branch, which already has the bound.  The
#     gate, the id, the wiring census (2 mentions), the turbo-only leg and the
#     whole §5 block stay green; only the frames can see that the branch the
#     lever exists for went back to bidding at +300.
#   * M8 is a control on the STAND ITSELF: a census that cannot go red is not a
#     limit, it is a sentence.
#   * M9 is the pullcad trap (AGENTS.md) -- conjoining a sibling id, which
#     freezes this gate FALSE the day that sibling is promoted while
#     check_armed_wiring.py still calls the site WIRED.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_hex_interrupt_reach.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lionwreach.XXXXXX")
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

# The filter is `lion`, not this one file: the sibling Lion assertions
# (lionrreach / lionqfight / lionqdmg / liondrain*) read the same hero module,
# and a stand scoped to the new file alone would report a collision there as
# SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of several identical sites scores "survived" for the
# wrong reason.  X.ConsiderW carries five near-identical selector loops and the
# same three-term filter appears in four of them, so this guard is load-bearing.
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

# ---------------------------------------------------------------------------
# ⭐ THE BASELINE IS A FAILURE SET, NOT AN EXIT CODE, and that is not a
# loosening -- it is the only form that is true here.  The `lion` filter carries
# 7 PRE-EXISTING trunk reds on a clean tree (six in
# tests/test_lion_considere_earlyreturn_domain.lua, one in
# tests/test_lion_ult_cash_weakest.lua), all of them corpus-size `==` asserts
# that went red when the archive grew from 27 to 42 live-Lion frames -- verified
# 2026-09-12 by restoring hero_lion.lua from git and re-running.  A stand that
# demanded exit 0 would abort on somebody else's red forever; a stand that just
# compared exit codes would score EVERY mutant as caught, because the run is
# already non-zero.  So the baseline records WHICH cases fail, and a mutant
# scores only on a failure this file did not already have.
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
grep '^FAIL:' "$WORK/run.log" | sort -u > "$WORK/base_fails.txt"
NBASE=$(wc -l < "$WORK/base_fails.txt")
echo "baseline EXIT=$BASE with $NBASE pre-existing failing case(s):"
sed 's/^/        /' "$WORK/base_fails.txt"
if grep -q 'test_lion_hex_interrupt_reach' "$WORK/base_fails.txt"; then
    echo "BASELINE RED IN THIS LEVER'S OWN FILE -- stand aborted, nothing below"
    echo "is meaningful.  Fix the lever before mutating it."
    exit 2
fi

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    grep '^FAIL:' "$WORK/run.log" | sort -u > "$WORK/now_fails.txt"
    local nNew
    nNew=$(comm -13 "$WORK/base_fails.txt" "$WORK/now_fails.txt" | wc -l)
    if [ "$nNew" -eq 0 ]; then
        echo "$name  SURVIVED (exit $rc, no failing case beyond the baseline set)"
        echo "        -- the stand cannot see this"
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
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionwreach' ) ) then return true end" \
            "	if not ( J.IsModeTurbo() ) then return true end"
score "M1" "gate off, with npc_dota_hero_zuus channelling"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1;
#     only the explicit non-turbo case in §5 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionwreach' ) ) then return true end" \
            "	if not ( J.IsSoakCandidate( 'lionwreach' ) ) then return true end"
score "M2" "outside Turbo the armed helper must answer the shipped"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed refuses the reachable channeller and
#     keeps the band one, while staying gated, wired and turbo-only.
echo
echo "=== M3: the reach term is inverted ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange + X.nWInterruptReachSlack )" \
            "	return not J.IsInRange( bot, hTarget, nCastRange + X.nWInterruptReachSlack )"
score "M3" "armed moved the IN-RANGE interrupt"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped answer anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange + X.nWInterruptReachSlack )" \
            "	return true"
score "M4" "armed still ordered hex ->"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.  The helper, its note, its id registration and
#     its unit tests all survive; the interrupt point goes back to bidding on
#     anything in the nCastRange + 300 ring.
echo
echo "=== M5: the interrupt point stops routing through the helper ==="
sub "$HERO" "				and X.lion_IsInterruptTargetInReach( npcEnemy, nCastRange )
" \
            ""
score "M5" "appears 1 times (expected 2"

# ---------------------------------------------------------------------------
# M6: the bound loosens to the ring the lever exists to close.  It then accepts
#     exactly the bids it was written to refuse, while still looking armed,
#     wired and gated.
echo
echo "=== M6: the bound loosened to the +300 search ring ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange + X.nWInterruptReachSlack )" \
            "	return J.IsInRange( bot, hTarget, nCastRange + 300 )"
score "M6" "armed still ordered hex ->"

# ---------------------------------------------------------------------------
# M7: the passed-in nCastRange is replaced by the constant that happens to be
#     right TODAY on frame A (900 = Hex rank 4 + the real Aether Lens).  Every
#     frame-A reading still holds, and the lever silently stops composing with
#     rank and with aetherRange -- which is exactly what frame B (rank 1, no
#     lens, nCastRange 575) exists to catch.
echo
echo "=== M7: the parameter replaced by the constant that is right on frame A ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange + X.nWInterruptReachSlack )" \
            "	return J.IsInRange( bot, hTarget, 900 + X.nWInterruptReachSlack )"
score "M7" "armed still hexes the band member on frame B"

# ---------------------------------------------------------------------------
# M8: A CONTROL ON THE STAND ITSELF.  The §1 census stops distinguishing the
#     band from the inside of the bound.  If this survives, the domain numbers
#     in §0.3 limit 1 are prose, not a reading.
echo
echo "=== M8: the census stops distinguishing the band from the bound ==="
sub "$TEST" "                        if GetUnitToUnitDistance(bot, e) > cr + SLACK then" \
            "                        if GetUnitToUnitDistance(bot, e) > cr + BAND then"
score "M8" "the band domain SHRANK"

# ---------------------------------------------------------------------------
# M9: THE PULLCAD TRAP.  Conjoin the sibling id that lives in the same file and
#     is reachable from the same dispatch (`lionhexaoe`).  Every wiring check
#     still reads the call site as WIRED, the gate is frozen FALSE in every wave
#     that does not arm BOTH -- and permanently, the day lionhexaoe promotes,
#     because a promoted id appears in no armed string.
echo
echo "=== M9: the gate conjoins a second candidate id ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionwreach' ) ) then return true end" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionwreach' ) and J.IsSoakCandidate( 'lionhexaoe' ) ) then return true end"
score "M9" "soak candidates; exactly one is allowed"

# ---------------------------------------------------------------------------
# M10: the named slack moves off the sibling's own 50 to a number that looks
#      just as reasonable.  The whole (c) argument -- "nothing is invented, the
#      bound is copied off the twin eleven lines below" -- quietly stops being
#      true, and the lever starts refusing casts the sibling would allow.
echo
echo "=== M10: the slack constant moved off the sibling's bound ==="
sub "$HERO" "X.nWInterruptReachSlack = 50" \
            "X.nWInterruptReachSlack = 250"
score "M10" "X.nWInterruptReachSlack is no longer 50"

# ---------------------------------------------------------------------------
# M11: ⭐ THE SCOPE MUTANT.  The same conjunct, moved onto the sibling
#      sub-branch -- which already carries the bound, so the move is a no-op
#      there and a total loss here.  Gate, id, turbo-only leg, the 2-mention
#      wiring census and every §5 assert stay green; only the real frames can
#      see that the branch this id exists for went back to bidding at +300.
echo
echo "=== M11: the conjunct moved onto the sibling sub-branch ==="
sub "$HERO" "			if npcEnemy:IsChanneling()
				-- [lionwreach] gate off this conjunct is \`true\`, byte for byte.
				-- Armed it is the SIBLING sub-branch's own bound, eleven lines
				-- below: J.IsInRange( bot, npcEnemy, nCastRange + 50 ).
				and X.lion_IsInterruptTargetInReach( npcEnemy, nCastRange )
			then" \
            "			if npcEnemy:IsChanneling()
			then"
sub "$HERO" "				and J.IsInRange( bot, npcEnemy, nCastRange + 50 )
			then" \
            "				and J.IsInRange( bot, npcEnemy, nCastRange + 50 )
				and X.lion_IsInterruptTargetInReach( npcEnemy, nCastRange )
			then"
score "M11" "armed still ordered hex ->"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT / $TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ]
