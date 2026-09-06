#!/usr/bin/env bash
# Mutation stand for the `liondrainbkb` candidate -- Mana Drain refused on a
# spell-immune enemy in X.ConsiderE's 团战吸蓝 branch (hero, 2026-09-06,
# OWNER_PRIORITIES P4.4).
# Run by hand when X.lion_IsDrainTargetCastable, X.ConsiderE or
# tests/test_lion_drain_immune_target.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axecallbkb.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent ABORTS instead of scoring caught,
#     and so does one whose anchor occurs MORE THAN ONCE;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  Four of the mutants are directional rather than
# cosmetic, and they are the ones worth reading:
#   * M3 is the DEAD-WIRING twin: the helper exists, the id is registered, the
#     call site is there and check_armed_wiring.py finds it -- and the armed
#     branch can never be taken.  A wave arms it, reads back "tested, no effect",
#     and nothing raises a hand.  Note it is NOT caught by any source assertion:
#     only behaviour can see it.
#   * M5 is a DEFAULTS CHANGE wearing a candidate's name: the shipped operand is
#     swapped for the narrow helper, so gate OFF stops aiming at targets it used
#     to aim at, in every game and every mode.  "Ships dark" exists to prevent
#     exactly this.
#   * M6 is the INVERTED VETO: armed refuses the reachable enemies and permits
#     the immune one.  It is still a subset of shipped -- so the subset check
#     alone cannot see it -- and it is caught by the one case that says arming
#     must be a NO-OP on a frame where nobody is immune.
#   * M7 is a control on the INSTRUMENT, not the subject: if the supply scan
#     stopped visiting enemy hero-instants, "0 spell-immune in 8 frames" would be
#     vacuously true, and that sentence is the whole of this lever's domain claim.
#
# Usage: bash tools/agent/mutstand_liondrainbkb.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_drain_immune_target.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_ldb.XXXXXX")
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

# The filter is `lion`, not this one file: the sibling `liondrain` /
# `liondrainstop` files assert on the same function's neighbours, and a stand
# scoped to the new file only would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
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
# M1: the candidate check is dropped.  The veto is now the shipped default in
#     every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainbkb' )" \
            "	if J.IsModeTurbo()"
score "M1" "turbo but not armed must be inert"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1,
#     and the one every behavioural case except 3e would miss.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'liondrainbkb' )" \
            "	if J.IsSoakCandidate( 'liondrainbkb' )"
score "M2" "outside turbo the candidate must be inert"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  Helper, id, call site and wiring check all intact;
#     the armed branch is simply unreachable.  No source assertion in the test
#     file can see this -- only the driven counterfactual can.
echo
echo "=== M3: the armed branch becomes unreachable (the dead-wiring twin) ==="
sub "$HERO" "		and hTarget:IsMagicImmune()" \
            "		and false"
score "M3" "armed, the same branch must pick crystal_maiden"

# ---------------------------------------------------------------------------
# M4: the call site reverts to the shipped predicate.  Reads as a tidy-up (the
#     helper is still defined and still tested in isolation) and silently
#     removes the lever from the only branch it exists for.
echo
echo "=== M4: the call site reverts to J.CanCastOnMagicImmune ==="
sub "$HERO" "				and X.lion_IsDrainTargetCastable( npcEnemy ) -- see X.lion_IsDrainTargetCastable" \
            "				and J.CanCastOnMagicImmune( npcEnemy ) -- see X.lion_IsDrainTargetCastable"
score "M4" "expected exactly one call site in X.ConsiderE, found 0"

# ---------------------------------------------------------------------------
# M5: A DEFAULTS CHANGE.  The shipped operand is swapped for the NON-piercing
#     helper, so gate OFF is no longer the shipped expression: Lion stops aiming
#     at spell-immune enemies in normal mode too, with nothing armed.  It reads
#     as "just use the right helper" and is exactly what shipping dark forbids.
echo
echo "=== M5: the shipped operand is swapped for the narrow helper (defaults change) ==="
sub "$HERO" "	local bShipped = J.CanCastOnMagicImmune( hTarget )" \
            "	local bShipped = J.CanCastOnNonMagicImmune( hTarget )"
score "M5" "the shipped predicate must be evaluated first and bound"

# ---------------------------------------------------------------------------
# M6: THE INVERTED VETO.  Armed refuses every enemy who is NOT immune and
#     permits the one who is.  Still a strict subset of shipped, so the subset
#     assertion cannot see it; caught only by the case that requires arming to
#     be a no-op where nobody is immune.
echo
echo "=== M6: the veto is inverted (armed refuses the reachable enemies) ==="
sub "$HERO" "		and hTarget:IsMagicImmune()" \
            "		and not hTarget:IsMagicImmune()"
score "M6" "armed orders drifted on a frame with nobody immune"

# ---------------------------------------------------------------------------
# M7: a control on the SUPPLY SCAN.  Stop it visiting enemy hero-instants.
#     Section 2's "no enemy hero-instant is spell-immune in ANY Lion-subject
#     frame" is this lever's whole domain claim; if it survives a scan that
#     visits nobody, the claim was vacuous rather than measured.
echo
echo "=== M7: the supply scan visits nobody (instrument control) ==="
sub "$TEST" "        for name, h in pairs(heroes) do
            if h:GetTeam() ~= bot:GetTeam() then
                nEnemies = nEnemies + 1" \
            "        for name, h in pairs(heroes) do
            if false then
                nEnemies = nEnemies + 1"
score "M7" "enemy hero-instants dropped below the measured 40"

# ---------------------------------------------------------------------------
# M8: a control on the KV cross-check.  Move the recalled cooldown anchor off
#     the shipped ladder: if section KV stays green, it was reading its own
#     constant back and the "11.6 of a rank-2 12s cooldown" reading in section 1
#     rests on nothing.
echo
echo "=== M8: the recalled cooldown anchor is moved off the KV ladder (instrument control) ==="
sub "$TEST" "local DRAIN_COOLDOWN = { 15, 12, 9, 6 }" \
            "local DRAIN_COOLDOWN = { 15, 11, 9, 6 }"
score "M8" "cooldown: anchor 11"

# ---------------------------------------------------------------------------
# The EXIT trap restores and verifies; do not restore-and-delete here.
echo
echo "=== $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
exit 0
