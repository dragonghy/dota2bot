#!/usr/bin/env bash
# Mutation stand for the `lionultcash` candidate -- the "团战对最弱的敌人" exit
# of Lion's X.ConsiderR, which is UNREACHABLE as shipped (hero, 2026-09-07,
# OWNER_PRIORITIES P4.4 (i)).  Run by hand when X.lion_ShouldCashUltAtWeakest,
# X.ConsiderR or tests/test_lion_ult_cash_weakest.lua are edited, and before
# quoting any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axecallbkb.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: the helper exists, the id is registered, the
#     wiring check finds a call site -- and every armed path hands back the
#     shipped answer, so the lever is inert in every wave and the verdict reads
#     back "tested, no effect" with nothing raising a hand.
#   * M5 is the FORBIDDEN DIRECTION: an armed bail-out returns `false` instead
#     of `bShippedLethal`, which turns a widening into a NARROWING and makes the
#     gate-off leg stop casting fingers it used to cast.  No in-domain counter
#     would report "Lion stopped fingering".
#   * M7 is the pullcad trap in its native habitat: conjoining `ultcash`, the id
#     J.IsDyingUnderAttack is already gated on.  Two armed ids, one lever, and a
#     gate frozen FALSE the day either is promoted.
#   * M9 is a control on the STAND ITSELF: the §1 census is what discovered that
#     an earlier draft's "zero archive frames reach the body" was wrong by five.
#     A census that cannot go red is not a limit, it is a sentence.
#   * M10 is the one only §2 can see: making the 击杀 loop ask a DIFFERENT
#     question breaks the closed-form unreachability argument while every
#     behavioural case about the armed leg stays green.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_ult_cash_weakest.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_luc.XXXXXX")
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

# The filter is `lion`, not this one file: five sibling files assert on the same
# hero, and a stand scoped to the new file alone would report a collision there
# as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of two identical sites scores "survived" for the
# wrong reason.  This file needs the ambiguity guard: X.ConsiderQ, X.ConsiderW
# and X.ConsiderR carry near-identical selector loops.
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
# M1: the candidate check is dropped.  The widening becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionultcash' ) ) then return bShippedLethal end" \
            "	if not ( J.IsModeTurbo() ) then return bShippedLethal end"
score "M1" "gate off now fires with nobody lethal"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1;
#     only the explicit non-turbo case in §4 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionultcash' ) ) then return bShippedLethal end" \
            "	if not ( J.IsSoakCandidate( 'lionultcash' ) ) then return bShippedLethal end"
score "M2" "the lever fired outside turbo"

# ---------------------------------------------------------------------------
# M3: the HP conjunct loosens to the block's OTHER half.  The lever would then
#     cash a non-lethal finger in any teamfight at full health -- which is the
#     half §0 deliberately leaves shut.
echo
echo "=== M3: the HP conjunct loosened from 0.4 to 1.0 ==="
sub "$HERO" "	if nBotHP >= 0.4 then return bShippedLethal end" \
            "	if nBotHP >= 1.01 then return bShippedLethal end"
score "M3" "the HP conjunct is not load-bearing"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, call site present, and the
#     armed path hands back the shipped answer anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "	if not J.IsInRange( hTarget, hBot, nCastRange ) then return bShippedLethal end

	return true" \
            "	if not J.IsInRange( hTarget, hBot, nCastRange ) then return bShippedLethal end

	return bShippedLethal"
score "M4" "armed fingered nil with nobody lethal"

# ---------------------------------------------------------------------------
# M5: FORBIDDEN DIRECTION.  One armed bail-out invents `false` instead of
#     handing back the shipped answer, so gate-off stops firing where shipped
#     fired.  A widening lever silently becomes a narrowing one.
echo
echo "=== M5: an armed bail-out returns false instead of bShippedLethal ==="
sub "$HERO" "	if nBotHP >= 0.4 then return bShippedLethal end" \
            "	if nBotHP >= 0.4 then return false end"
score "M5" 'appeared in the body.  For a WIDENING lever'

# ---------------------------------------------------------------------------
# M6: the true short-circuit is removed.  The armed detour becomes reachable for
#     targets the shipped predicate ACCEPTS, and the strict-superset argument --
#     the whole attribution boundary -- dies.
echo
echo "=== M6: the shipped-answer short-circuit is removed ==="
sub "$HERO" "	if bShippedLethal then return true end

	if not ( J.IsModeTurbo()" \
            "	if not ( J.IsModeTurbo()"
score "M6" "the true short-circuit is gone"

# ---------------------------------------------------------------------------
# M7: THE PULLCAD TRAP, in the exact place it is easiest to walk into: reaching
#     for J.IsDyingUnderAttack, which is itself gated on 'ultcash'.  Two armed
#     ids for one lever, and a gate frozen FALSE the day either is promoted.
echo
echo "=== M7: the damage conjunct reaches for the ultcash-gated helper ==="
sub "$HERO" "	if not hBot:WasRecentlyDamagedByAnyHero( 2.0 ) then return bShippedLethal end" \
            "	if not J.IsDyingUnderAttack( hBot ) then return bShippedLethal end"
score "M7" "IsDyingUnderAttack"

# ---------------------------------------------------------------------------
# M8: the reach conjunct is dropped.  npcWeakestEnemy comes from a list at
#     nCastRange + 400, so the armed leg would start ordering casts on targets
#     Lion has to WALK to -- turning "cash the ult before dying" into a dive,
#     and importing hero backlog -120's problem into a brand new lever.
echo
echo "=== M8: the reach conjunct dropped (the cast becomes a walk order) ==="
sub "$HERO" "	if not J.IsInRange( hTarget, hBot, nCastRange ) then return bShippedLethal end" \
            "	if hTarget == nil then return bShippedLethal end"
score "M8" "the reach conjunct is not load-bearing"

# ---------------------------------------------------------------------------
# M9: A CONTROL ON THE STAND ITSELF.  The §1 census is the file's LIMIT, and a
#     limit that cannot go red is a sentence, not a measurement.  Break the
#     enumerator so it sees one directory instead of two: the counts must move.
echo
echo "=== M9: the corpus enumerator silently drops tests/frames/ ==="
sub "$TEST" "    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do" \
            "    for _, dir in ipairs({ FIXTURE_DIR }) do"
score "M9" "live-Lion instants, was 27"

# ---------------------------------------------------------------------------
# M10: the closed form breaks, and ONLY §2 can see it.  Make the 击杀 loop ask a
#      different question from the 团战 exit -- a longer delay.  Every case about
#      the armed leg stays green; the unreachability argument does not.
echo
echo "=== M10: the 击杀 loop stops asking the 团战 exit's question ==="
sub "$HERO" "			if J.WillMagicKillTarget( bot, npcEnemy, nDamage, nCastPoint + 0.25 )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy, 'R击杀'" \
            "			if J.WillMagicKillTarget( bot, npcEnemy, nDamage, nCastPoint + 9.75 )
			then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy, 'R击杀'"
score "M10" "the 击杀 loop no longer asks"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
