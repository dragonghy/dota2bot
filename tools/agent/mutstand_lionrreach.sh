#!/usr/bin/env bash
# Mutation stand for the `lionrreach` candidate -- the reach term on the two
# places X.ConsiderR commits Finger of Death to a member of nInBonusEnemyList
# (hero, 2026-09-08, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.lion_ShouldCommitUltKill, X.ConsiderR or tests/test_lion_ult_reach.lua are
# edited, and before quoting any of that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_lionultcash.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.  In a double-quoted bash string
#     that is command substitution, and the 2026-09-07 stand scored a mutant
#     "red with the wrong message" for exactly that reason.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call sites
#     present, and every armed path hands back the shipped answer -- inert in
#     every wave, and the verdict reads back "tested, no effect".
#   * M3 is the FORBIDDEN DIRECTION: this id is a NARROWING, so the way to break
#     its attribution boundary is to make it ADD a cast.  No in-domain counter
#     would report "Lion started fingering things it never used to".
#   * M5 is the one this stand exists for.  Removing the SECOND call site leaves
#     every kill-loop case green while the dive walks back in through the 团战
#     exit -- and that exit is dead code as shipped, so nothing else in the
#     suite has an opinion about it.
#   * M8 is a control on the STAND ITSELF: a census that cannot go red is not a
#     limit, it is a sentence.  (The first draft of this file's §1 was wrong by
#     three frames and one leak frame; the assert caught it, not a re-read.)
#   * M9 is the pullcad trap in its native habitat: conjoining `lionultcash`,
#     the id that lives thirty lines away and reads the same list.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_ult_reach.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lrr.XXXXXX")
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

# The filter is `lion`, not this one file: six sibling files assert on the same
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
# M1: the candidate check is dropped.  The narrowing becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionrreach' ) ) then return bShippedLethal end" \
            "	if not ( J.IsModeTurbo() ) then return bShippedLethal end"
score "M1" "gate off must return the shipped answer (true)"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1;
#     only the explicit non-turbo case in section 5 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionrreach' ) ) then return bShippedLethal end" \
            "	if not ( J.IsSoakCandidate( 'lionrreach' ) ) then return bShippedLethal end"
score "M2" "the lever fired outside turbo"

# ---------------------------------------------------------------------------
# M3: FORBIDDEN DIRECTION.  The shipped-false short-circuit invents a true, so
#     an armed leg starts ADDING casts.  A narrowing lever becomes a widening
#     one, and every attribution sentence written about it is then false.
echo
echo "=== M3: the shipped-false short-circuit returns true ==="
sub "$HERO" "	if not bShippedLethal then return bShippedLethal end" \
            "	if not bShippedLethal then return true end"
score "M3" "the lever turned a shipped false into a cast"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper present, id registered, both call sites present, and
#     the armed path hands back the shipped answer anyway.  check_armed_wiring.py
#     still says WIRED; the wave reads back "tested, no effect".
echo
echo "=== M4: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "	return J.IsInRange( hTarget, hBot, nCastRange )" \
            "	return bShippedLethal"
score "M4" "of the 4 cube points, expected exactly 1"

# ---------------------------------------------------------------------------
# M5: THE SECOND CALL SITE IS REMOVED -- the whole reason this stand exists.
#     Every kill-loop case stays green and the dive walks back in through the
#     团战 exit, on the one archive frame that can show it.
echo
echo "=== M5: the 团战 exit stops routing through the helper ==="
sub "$HERO" "					X.lion_ShouldCommitUltKill( bot, npcWeakestEnemy, nCastRange,
						J.WillMagicKillTarget( bot, npcWeakestEnemy, nDamage , nCastPoint + 0.25 ) ) )" \
            "					J.WillMagicKillTarget( bot, npcWeakestEnemy, nDamage , nCastPoint + 0.25 ) )"
score "M5" "armed still fingered"

# ---------------------------------------------------------------------------
# M6: the FIRST call site is removed.  The kill loop goes back to committing the
#     finger on anything lethal in the nCastRange + 400 list.
echo
echo "=== M6: the 击杀 loop stops routing through the helper ==="
sub "$HERO" "			if X.lion_ShouldCommitUltKill( bot, npcEnemy, nCastRange,
					J.WillMagicKillTarget( bot, npcEnemy, nDamage, nCastPoint + 0.25 ) )" \
            "			if J.WillMagicKillTarget( bot, npcEnemy, nDamage, nCastPoint + 0.25 )"
score "M6" "calls X.lion_ShouldCommitUltKill 1 times, expected 2"

# ---------------------------------------------------------------------------
# M7: the reach term loosens to the band it was written to close.  The lever
#     then accepts exactly the walk orders it exists to refuse, while still
#     looking armed, wired and gated.
echo
echo "=== M7: the reach term loosened to nCastRange + 400 ==="
sub "$HERO" "	return J.IsInRange( hTarget, hBot, nCastRange )" \
            "	return J.IsInRange( hTarget, hBot, nCastRange + 400 )"
score "M7" "which is a 345.8-unit WALK order"

# ---------------------------------------------------------------------------
# M8: A CONTROL ON THE STAND ITSELF.  The section 1 census stops measuring the
#     band and counts every castable enemy instead.  If this survives, the
#     domain numbers in section 0.3 are prose, not a reading.
echo
echo "=== M8: the census stops distinguishing the band from the whole list ==="
sub "$TEST" "                        if d > CAST_RANGE then nBand = nBand + 1 end" \
            "                        if d > 0 then nBand = nBand + 1 end"
score "M8" "the band domain moved"

# ---------------------------------------------------------------------------
# M9: THE PULLCAD TRAP.  Conjoining lionultcash -- the id thirty lines away that
#     reads the same list -- freezes this gate FALSE the day either id is
#     promoted, while check_armed_wiring.py still reports WIRED.
echo
echo "=== M9: the gate conjoins a second candidate id ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionrreach' ) ) then return bShippedLethal end" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionrreach' ) and J.IsSoakCandidate( 'lionultcash' ) ) then return bShippedLethal end"
score "M9" "of the 4 cube points, expected exactly 1"

# ---------------------------------------------------------------------------
# M10: the nCastRange the caller hands in is replaced by a constant.  The lever
#      would then ignore aether lens, the 1200 clamp and any talent, and the
#      reach question would silently stop being about this ability.
echo
echo "=== M10: the handed-in cast range is replaced by a literal ==="
sub "$HERO" "	return J.IsInRange( hTarget, hBot, nCastRange )" \
            "	return J.IsInRange( hTarget, hBot, 900 )"
score "M10" "the reach test does not use the nCastRange it is handed"

# ---------------------------------------------------------------------------
echo
echo "=== score ==="
echo "$CAUGHT/$TOTAL CAUGHT"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 3
exit 0
