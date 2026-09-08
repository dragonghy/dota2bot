#!/usr/bin/env bash
# Mutation stand for the `axebhreach` candidate -- the reach term on
# X.ConsiderW's 团战 firing point, the one hero-targeting point in that function
# that runs a MIN-SEARCH over the nCastRange + 200 ring with no distance test
# (hero, 2026-09-08, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.axe_IsHungerFightTargetInReach, X.ConsiderW or
# tests/test_axe_battle_hunger_fight_reach.lua are edited, and before quoting
# any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkqlane.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.  In a double-quoted bash string
#     that is command substitution, and the 2026-09-07 stand scored a mutant
#     "red with the wrong message" for exactly that reason.
#   * every `want` is the FIRST thing the mutant makes the suite say, not the
#     sentence you wish it said.  M5/M8 of the 2026-09-08T17:05Z stand were
#     first written the other way round and scored "red, wrong message" twice.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed path hands back the shipped answer -- inert in every
#     wave, and the verdict reads back "tested, no effect".
#   * M3 is the INVERSION: the gate keeps the band elections and drops the
#     reachable ones, the exact opposite of every sentence written about it.
#   * M6/M7 are the two ways to keep a reach term that no longer means what its
#     note says: the wrong bound, and a bound that stops composing with the
#     aether-lens term the other six firing points see.
#   * M10 is the SUBTLE one and it is why this lever is not "another reach
#     term": moving the same call OUT of the loop filter and onto the elected
#     winner turns a SWAP into a REFUSAL.  Every wiring check, every gate test
#     and the whole §5 block still pass; only §3.2 (armed elects the reachable
#     candidate, not nobody) can see it.
#   * M8 is a control on the STAND ITSELF: a census that cannot go red is not a
#     limit, it is a sentence.
#   * M9 is the pullcad trap (AGENTS.md) in its native habitat -- conjoining a
#     sibling id that lives in the same `if`, and would freeze this gate FALSE
#     the day that sibling is promoted.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_battle_hunger_fight_reach.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_axebh.XXXXXX")
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

# The filter is `axe`, not this one file: the sibling Axe assertions
# (axecull / axecallbkb / axebhpure / axebhrecast / axecullreach) read the same
# hero module, and a stand scoped to the new file alone would report a collision
# there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua axe > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of several identical sites scores "survived" for the
# wrong reason.  This file needs the ambiguity guard badly: X.ConsiderW carries
# four near-identical selector loops and the same four-term filter appears in
# three of them.
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
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhreach' ) )" \
            "	if not ( J.IsModeTurbo() )"
score "M1" "gate OFF must answer the shipped"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1;
#     only the explicit non-turbo case in §5.1 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhreach' ) )" \
            "	if not ( J.IsSoakCandidate( 'axebhreach' ) )"
score "M2" "outside Turbo the helper must answer the shipped"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed drops the reachable candidates and
#     keeps the band ones, while staying gated, wired and turbo-only.
echo
echo "=== M3: the reach term is inverted ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange )" \
            "	return not J.IsInRange( bot, hTarget, nCastRange )"
score "M3" "the in-range candidate must pass"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped answer anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange )" \
            "	return true"
score "M4" "the band candidate must be refused"

# ---------------------------------------------------------------------------
# M5: THE CALL SITE IS REMOVED.  The helper, its note, its id registration and
#     its unit tests all survive; the min-search goes back to electing anything
#     in the nCastRange + 200 ring.
echo
echo "=== M5: the 团战 min-search stops routing through the helper ==="
sub "$HERO" "				and X.axe_IsHungerFightTargetInReach( npcEnemy, nCastRange )
" \
            ""
score "M5" "is wired at 0 sites in X.ConsiderW"

# ---------------------------------------------------------------------------
# M6: the bound loosens to the ring the lever exists to close.  It then accepts
#     exactly the elections it was written to refuse, while still looking armed,
#     wired and gated.
echo
echo "=== M6: the bound loosened to the +200 search ring ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange )" \
            "	return J.IsInRange( bot, hTarget, nCastRange + 200 )"
score "M6" "the band candidate must be refused"

# ---------------------------------------------------------------------------
# M7: the passed-in nCastRange is replaced by the constant that happens to be
#     right TODAY on the pin frame.  Every reading in §0.1 and §3 still holds --
#     and the lever silently stops composing with aetherRange, i.e. an Axe who
#     bought the Aether Lens both buy lists carry would have 225u of his real
#     cast range refused.
echo
echo "=== M7: the parameter replaced by the constant that is right today ==="
sub "$HERO" "	return J.IsInRange( bot, hTarget, nCastRange )" \
            "	return J.IsInRange( bot, hTarget, 600 )"
score "M7" "the bound is no longer the passed-in nCastRange"

# ---------------------------------------------------------------------------
# M8: A CONTROL ON THE STAND ITSELF.  The §1 census stops distinguishing the
#     band from the inside of the cast range.  If this survives, the domain
#     numbers in §0.3 limit 1 are prose, not a reading.
echo
echo "=== M8: the census stops distinguishing the band from the cast range ==="
sub "$TEST" "                    if GetUnitToUnitDistance(bot, e) <= nCast then nIn = nIn + 1" \
            "                    if GetUnitToUnitDistance(bot, e) <= nCast + BONUS then nIn = nIn + 1"
score "M8" "the band domain moved"

# ---------------------------------------------------------------------------
# M9: THE PULLCAD TRAP.  Conjoin the sibling id that sits three lines away in
#     the SAME `if` (`axebhrecast`, the freshness lever).  Every wiring check
#     still reads the call site as WIRED, and the gate is frozen FALSE in every
#     wave that does not arm BOTH -- and permanently, the day axebhrecast
#     promotes, because a promoted id appears in no armed string.
echo
echo "=== M9: the gate is conjoined with the sibling id in the same if ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhreach' ) )" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'axebhreach' ) and J.IsSoakCandidate( 'axebhrecast' ) )"
score "M9" "the band candidate must be refused"

# ---------------------------------------------------------------------------
# M10: THE SWAP BECOMES A REFUSAL.  The same helper, the same id, the same
#      turbo gate, the same one call -- moved OUT of the loop filter and onto
#      the elected winner.  The lever then refuses the frame instead of handing
#      the branch to the weakest REACHABLE enemy, which is a different lever
#      wearing this one's name and its whole (c) argument.  §5 cannot see it;
#      only §3.2 can.
echo
echo "=== M10: the reach term moved from the filter onto the elected winner ==="
sub "$HERO" "				and X.axe_IsHungerFightTargetInReach( npcEnemy, nCastRange )
" \
            ""
sub "$HERO" "		if npcWeakestEnemy ~= nil
		then" \
            "		if npcWeakestEnemy ~= nil
			and X.axe_IsHungerFightTargetInReach( npcWeakestEnemy, nCastRange )
		then"
score "M10" "armed elected nil, expected crystal_maiden"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
