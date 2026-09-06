#!/usr/bin/env bash
# Mutation stand for the `axebhrecast` candidate -- X.ConsiderW's "already has
# Battle Hunger" veto names a caster-side (and stale) modifier, so it has never
# fired (hero, 2026-09-06, OWNER_PRIORITIES P4.4).
# Run by hand when X.axe_IsBattleHungerFresh, X.ConsiderW or
# tests/test_axe_battle_hunger_recast.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_liondrainbkb.sh):
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
# WHAT THIS STAND IS FOR.  Five of the eight are directional rather than
# cosmetic, and they are the ones worth reading:
#   * M3 is the DEAD-WIRING twin: the helper exists, the id is registered, the
#     three call sites are there and check_armed_wiring.py finds them -- and the
#     armed branch can never be taken.  A wave arms it, reads back "tested, no
#     effect", and nothing raises a hand.  No SOURCE assertion sees it; only the
#     driven frame does.
#   * M5 is a DEFAULTS CHANGE wearing a candidate's name: the shipped operand is
#     repaired in place, so gate OFF stops re-hungering in every game and every
#     mode.  "Ships dark" exists to prevent exactly this, and the repair is the
#     tempting edit here because the shipped string really is a typo.
#   * M6 is the INVERTED VETO: armed refuses everyone who is NOT hungered and
#     permits the one who is.  It is STILL a strict subset of shipped, so the
#     subset case cannot see it; it is caught only by the case that requires
#     arming to be a no-op where nobody carries the debuff.
#   * M7 removes the SHARD premise.  With the shard Battle Hunger stacks and the
#     whole dominance argument reverses, so this is the mutant that turns a
#     correct lever into a wrong one without touching its direction.
#   * M8 is a control on the INSTRUMENT, not the subject: if the corpus census
#     stopped visiting hero-instants, "the tested name appears on NO unit in ANY
#     Axe frame" would be vacuously true -- and that sentence is half of the
#     defect claim.
#
# Usage: bash tools/agent/mutstand_axebhrecast.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_battle_hunger_recast.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_abr.XXXXXX")
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

# The filter is `axe`, not this one file: five sibling files assert on the same
# function's neighbours (axecallbkb / axecull / axebhpure / cullthresh), and a
# stand scoped to the new file only would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua axe > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of three identical call sites scores "survived" for
# the wrong reason.  The three call sites ARE byte-identical, which is why M4's
# anchor carries the following two lines with it.
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
# M1: the candidate check is dropped.  The veto becomes the shipped default in
#     every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "		and J.IsModeTurbo() and J.IsSoakCandidate( 'axebhrecast' )" \
            "		and J.IsModeTurbo()"
score "M1" "shipped veto fired on"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1,
#     and the one every behavioural case except the non-turbo one would miss.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "		and J.IsModeTurbo() and J.IsSoakCandidate( 'axebhrecast' )" \
            "		and J.IsSoakCandidate( 'axebhrecast' )"
score "M2" "armed but non-turbo"

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  Helper, id, three call sites and the wiring check
#     all intact; the armed branch is simply unreachable.  No source assertion in
#     the test file can see this -- only the driven frame can.
echo
echo "=== M3: the armed branch becomes unreachable (the dead-wiring twin) ==="
sub "$HERO" "		and hTarget:HasModifier( 'modifier_axe_battle_hunger' )" \
            "		and false"
score "M3" "armed, mode retreat"

# ---------------------------------------------------------------------------
# M4: one call site reverts to the shipped literal.  Reads as a tidy-up -- the
#     helper is still defined, still gated, still tested in isolation, and the
#     other two sites still call it -- and silently drops a third of the lever.
echo
echo "=== M4: the retreat call site reverts to the shipped literal ==="
sub "$HERO" "				and X.axe_IsBattleHungerFresh( npcEnemy )
			then
				hCastTarget = npcEnemy
				sCastMotive = 'W-撤退:'" \
            "				and not npcEnemy:HasModifier( 'modifier_axe_battle_hunger_self' )
			then
				hCastTarget = npcEnemy
				sCastMotive = 'W-撤退:'"
score "M4" "must call the helper exactly 3 times"

# ---------------------------------------------------------------------------
# M5: A DEFAULTS CHANGE, and it is the tempting edit.  The shipped operand is
#     "repaired" to the correct modifier name, so gate OFF is no longer the
#     shipped expression: Axe stops re-hungering in normal mode too, with nothing
#     armed and no wave behind it.
echo
echo "=== M5: the shipped operand is repaired in place (defaults change) ==="
sub "$HERO" "	local bShipped = not hTarget:HasModifier( 'modifier_axe_battle_hunger_self' )" \
            "	local bShipped = not hTarget:HasModifier( 'modifier_axe_battle_hunger' )"
score "M5" "the shipped predicate must be computed FIRST and bound"

# ---------------------------------------------------------------------------
# M6: THE INVERTED VETO.  Armed refuses everyone who is NOT hungered and permits
#     the one who is.  Still a strict subset of shipped, so the subset assertion
#     cannot see it; caught only by the no-op-where-nobody-is-hungered case.
echo
echo "=== M6: the veto is inverted (armed refuses the fresh targets) ==="
sub "$HERO" "		and hTarget:HasModifier( 'modifier_axe_battle_hunger' )" \
            "		and not hTarget:HasModifier( 'modifier_axe_battle_hunger' )"
score "M6" "who carries no Battle Hunger at all"

# ---------------------------------------------------------------------------
# M7: the SHARD premise is removed.  Direction is untouched and every subset
#     assertion still holds -- what changes is that the lever now fires in the
#     one configuration where re-casting is a genuine second stack, i.e. it is
#     wrong rather than narrow.
echo
echo "=== M7: the shard premise is dropped (correct lever -> wrong lever) ==="
sub "$HERO" "		and not J.HasAghanimsShard( bot )" \
            "		and true"
score "M7" "armed with shard"

# ---------------------------------------------------------------------------
# M8: a control on the CORPUS CENSUS.  Stop it visiting hero-instants.  Section
#     2's "the tested name appears on NO unit in ANY Axe frame" is half of the
#     defect claim; if it survives a census that visits nobody, the claim was
#     vacuous rather than measured.
echo
echo "=== M8: the corpus census visits nobody (instrument control) ==="
sub "$TEST" "        for _, h in pairs(heroes) do
            nUnits = nUnits + 1" \
            "        for _, h in pairs({}) do
            nUnits = nUnits + 1"
score "M8" "the census must actually have walked the corpus"

# ---------------------------------------------------------------------------
# The EXIT trap restores and verifies; do not restore-and-delete here.
echo
echo "=== $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
exit 0
