#!/usr/bin/env bash
# Mutation stand for the `zusjumpany` candidate -- X.ConsiderE's RETREAT firing
# point, which asks an EXISTENTIAL question ("is there an enemy I am running
# away from?") of exactly one member of the ring it just built (hero,
# 2026-09-11, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.zuus_FindRetreatJumpThreat, X.zuus_IsRetreatJumpThreat, X.ConsiderE or
# tests/test_zuus_jump_escape_any.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusjumpland.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring
#     (an aborted mutant is NOT a surviving mutant);
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick -- in a double-quoted bash
#     string that is command substitution.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M5 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed path scans nothing but index 1 anyway.  Inert in
#     every wave, and the verdict reads back "tested, no effect".
#   * M4 is the DIRECTION mutant, and for this lever it points the unusual way.
#     Every previous reach lever on this stream was a NARROWING and its
#     dangerous mutant was a widening; this one is a WIDENING, so the dangerous
#     mutant is the one that makes the armed pool stop containing the shipped
#     one (scan from index 2).  §3's `nOnlyShipped == 0` is the only assertion
#     in the suite that can see it.
#   * M8 is a control on the STAND'S OWN INSTRUMENT, and it is the mutant this
#     stand paid for.  Every number in §3/§4/§5/§7 rests on an injected facing,
#     and an injection that silently does not take reads EXACTLY like a lever
#     that does nothing.  M8 installs the facing under a key nothing calls, so
#     `IsFacingLocation` falls back to bot_api's `^Is -> false` everywhere.
#     ⚠️ M8's FIRST DRAFT (drop `rawset(h, k, nil)` from `inject`, i.e. leave the
#     lazily materialised method in place) was an EQUIVALENT MUTANT and the stand
#     scored it 5/8 SURVIVED: this mock's cached method reads `__spec[key]` at
#     CALL time, so dropping the cache-clear changes nothing.  The second line of
#     `inject` is defensive, not load-bearing -- worth knowing before anyone
#     writes another stand around it.
#     ⚠️ M8's first RUN also exposed a real hole in the test: §2 checked only
#     that a FRESH world still answers `false`, which is a world the injector
#     never touched, so a blinded injector passed it.  §2 now carries a POSITIVE
#     control (inject 0 deg and 180 deg, assert the answer moves).  That is the
#     "the discriminator must still see the defect" lesson the 2026-09-11
#     `test_local_assign_discipline` round paid for, recurring one round later.
#   * M7 is the pullcad trap (AGENTS.md) in its native habitat: conjoining a
#     sibling id THIS VERY FILE already calls (`zusjumpland`), which would
#     freeze this gate FALSE the day that sibling is promoted, while
#     check_armed_wiring.py still calls it WIRED.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_zuus.lua
TEST=tests/test_zuus_jump_escape_any.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zja.XXXXXX")
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

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous.
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

GATELINE="	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'zusjumpany' ) )"
SCANHEAD="	for _, hEnemy in ipairs( tEnemies )"
SCANBODY="		if X.zuus_IsRetreatJumpThreat( hBot, hEnemy ) then return hEnemy end"
NEARBODY="		if X.zuus_IsRetreatJumpThreat( hBot, hNearest ) then return hNearest end"
CALLSITE="			if X.zuus_FindRetreatJumpThreat( bot, tableNearbyEnemyHeroes ) ~= nil"
INJECTOR="    inject(bot, 'IsFacingLocation', function(self, vLoc, nTol)"

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
# M1: the candidate check is dropped.  The widening becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATELINE" "	if false"
score "M1" "unarmed answer diverges from"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  Only §7 can see this --
#     the whole fixture corpus is a Turbo world.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "$GATELINE" "	if not ( J.IsSoakCandidate( 'zusjumpany' ) )"
score "M2" "the lever fires outside Turbo"

# ---------------------------------------------------------------------------
# M3: THE SCAN IS INVERTED.  Armed elects exactly the enemies the branch is not
#     about -- the ones in FRONT of the bot -- while staying gated, wired and
#     turbo-only, and the escape hop then points INTO the chaser.
echo
echo "=== M3: the armed scan elects on the negated predicate ==="
sub "$HERO" "$SCANBODY" "		if not X.zuus_IsRetreatJumpThreat( hBot, hEnemy ) then return hEnemy end"
score "M3" "the shipped leg fired on"

# ---------------------------------------------------------------------------
# M4: THE DIRECTION MUTANT, and for this lever it is a NARROWING.  Scanning from
#     index 2 drops the shipped candidate out of the armed pool, so the armed
#     leg stops being a superset and a batch reading could no longer be
#     attributed to "jumps this ADDED".  §3's reverse count is the only
#     assertion that can see it.
echo
echo "=== M4: the armed scan skips index 1, so armed is no longer a superset ==="
sub "$HERO" "$SCANHEAD" "	for _, hEnemy in ipairs( { unpack( tEnemies, 2 ) } )"
score "M4" "this lever is supposed to be a"

# ---------------------------------------------------------------------------
# M5: DEAD WIRING.  Helper present, id registered, call site present, gate
#     turbo-only -- and the armed path looks at index 1 and nothing else.
#     check_armed_wiring.py still says WIRED; the wave reads back "no effect".
echo
echo "=== M5: armed scans only index 1, i.e. hands back the shipped answer ==="
sub "$HERO" "$SCANHEAD" "	for _, hEnemy in ipairs( { tEnemies[1] } )"
score "M5" "swept disagreement 0 deg does not match"

# ---------------------------------------------------------------------------
# M6: THE CALL SITE IS TAKEN BACK OUT and the shipped expression restored.  The
#     helper survives, the id survives, the tests that drive the helper
#     DIRECTLY survive -- only the wiring assertions and the end-to-end section
#     can see it.
echo
echo "=== M6: the call site reverts to the shipped tableNearbyEnemyHeroes[1] ==="
sub "$HERO" "$CALLSITE" "			local targetHero = tableNearbyEnemyHeroes[1]
			if J.IsValidHero( targetHero )
				and J.CanCastOnNonMagicImmune( targetHero )
				and not bot:IsFacingLocation( targetHero:GetLocation(), 120 )"
score "M6" "is not (definition + exactly one call site)"

# ---------------------------------------------------------------------------
# M7: THE PULLCAD TRAP.  A sibling id this very file already calls is conjoined
#     into the gate.  The lever then freezes FALSE the day `zusjumpland` is
#     promoted -- a promoted id is in no armed string -- and nothing raises a
#     hand: the call site exists, so check_armed_wiring.py calls it WIRED and
#     the verdict reads back "tested, no effect".
echo
echo "=== M7: the gate conjoins the sibling id zusjumpland ==="
sub "$HERO" "$GATELINE" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'zusjumpany' ) and J.IsSoakCandidate( 'zusjumpland' ) )"
score "M7" "gate is not the expected shape"

# ---------------------------------------------------------------------------
# M8: A CONTROL ON THE STAND'S OWN INSTRUMENT.  `inject` drops the lazily
#     materialised method so the new spec entry takes; without that second line
#     the already-cached `IsFacingLocation` stays in place and EVERY facing in
#     §3/§4/§5/§7 is silently the mock's `false`.  The suite must go red -- if it
#     does not, none of this file's numbers are about the facings it names.
echo
echo "=== M8: the facing injector is blinded (installed under a key nothing calls) ==="
sub "$TEST" "$INJECTOR" "    inject(bot, 'IsFacingLocationNOTTHEKEY', function(self, vLoc, nTol)"
score "M8" "the facing injector did not take"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ]
