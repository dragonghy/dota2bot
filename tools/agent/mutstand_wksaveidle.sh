#!/usr/bin/env bash
# Mutation stand for the `wksaveidle` candidate -- Wraith King releases the
# Reincarnation mana reserve on a frame where nothing can spend it
# (hero, 2026-09-07, OWNER_PRIORITIES P4.4).
# Run by hand when X.IsReincarnationReserveIdle, X.ShouldSaveMana or
# tests/test_wk_reserve_idle_release.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axecallbkb.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS instead of scoring;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand that
# rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# THE FILTER IS `wk_`, NOT THIS ONE FILE.  X.ShouldSaveMana is read by
# tests/test_wk_save_mana_lock_census.lua as well, and that file's sections 2-4
# are readings of the very function these mutants edit.  A stand scoped to the
# new file alone would score a collision there as SURVIVED.
#
# ⭐ WHAT THIS STAND IS ACTUALLY FOR.  Three of the mutants below are the ones
# worth reading, and one of them is a confession:
#   * M3 is BEHAVIOURALLY A NO-OP AND MUST STILL BE CAUGHT.  Dropping the
#     `bShipped and` guard in front of the release changes no answer today --
#     when the shipped predicate is false the function returns false either way.
#     But the whole direction argument ("armed can only move true -> false") is a
#     property of that shape, not of today's arithmetic, and a later edit to the
#     release could make the armed leg invent a reserve the shipped leg never
#     asked for.  Only a source assertion can see this one, and section 1 of the
#     test file exists for it.
#   * M7 IS THE HONEST GAP.  Loosening the health threshold from 0.95 to 0.60
#     moves NOTHING behaviourally on this corpus: the two frames it would newly
#     admit (hp 0.69 and 0.76) are both held out by the visible-enemy term
#     anyway.  So the corpus cannot price the threshold, the test file says so in
#     its header, and this mutant is caught by the source assertion alone.  That
#     is recorded here rather than hidden, because a stand that scores 100% while
#     one of its numbers is unmeasured is lying about which of them are load
#     bearing.
#   * M10 is the `pullcad` trap in its sibling form: the release helper names a
#     DIFFERENT live id.  Both helpers exist, check_armed_wiring.py still finds a
#     call site, and a wave arming `wksaveidle` would move nothing while the
#     verdict reads back "tested, no effect" with nothing raising a hand.
#
# Usage: bash tools/agent/mutstand_wksaveidle.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_reserve_idle_release.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wksi.XXXXXX")
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
    lua5.1 tests/run_tests.lua wk_ > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the wrong of two identical sites scores "survived" for the
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

GATE="	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wksaveidle' ) )"

# ---------------------------------------------------------------------------
# M1: the candidate check is dropped.  The release becomes the shipped default
#     in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE" "	if not ( J.IsModeTurbo() )"
score "M1" "the release answered true with nothing armed"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE" "	if not ( J.IsSoakCandidate( 'wksaveidle' ) )"
score "M2" "outside turbo the candidate must be inert"

# ---------------------------------------------------------------------------
# M3: THE SHAPE MUTANT, behaviourally a no-op today (see the header).  The
#     release stops being guarded by the shipped answer, so nothing stops a
#     later edit from making the armed leg impose a reserve of its own.
echo
echo "=== M3: the release is no longer guarded by the shipped answer ==="
sub "$HERO" "	if bShipped and X.IsReincarnationReserveIdle()" \
            "	if X.IsReincarnationReserveIdle()"
score "M3" "the release is no longer guarded by the shipped answer"

# ---------------------------------------------------------------------------
# M4: the health term is deleted.  The release now fires on a dying Wraith King
#     -- exactly the frame the reserve exists for.
echo
echo "=== M4: the health term is deleted (release ignores how hurt he is) ==="
sub "$HERO" "	if J.GetHP( bot ) < 0.95
	then
		return false
	end

	return #J.GetNearbyHeroes" \
            "	return #J.GetNearbyHeroes"
score "M4" "at half health the release must NOT fire"

# ---------------------------------------------------------------------------
# M5: the visible-enemy term is INVERTED -- release only when enemies ARE in
#     sight.  Same two operands, same source shape, opposite meaning.
echo
echo "=== M5: the enemy term is inverted (release only when enemies are here) ==="
sub "$HERO" "	return #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) == 0" \
            "	return #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0"
score "M5" "armed, the reserve must let the cast through"

# ---------------------------------------------------------------------------
# M6: the ring shrinks.  A smaller radius makes "nobody in sight" easier and the
#     domain grows -- the classic silent widening of a measured number.
echo
echo "=== M6: the 1600u ring shrinks to 500u ==="
sub "$HERO" "	return #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) == 0" \
            "	return #J.GetNearbyHeroes( bot, 500, true, BOT_MODE_NONE ) == 0"
score "M6" "the visible-enemy term moved"

# ---------------------------------------------------------------------------
# M7: the health threshold is loosened 0.95 -> 0.60.  BEHAVIOURALLY A NO-OP on
#     this corpus (see the header) -- caught by the source assertion alone, and
#     that is the point of running it.
echo
echo "=== M7: the health threshold is loosened to 0.60 (the honest gap) ==="
sub "$HERO" "	if J.GetHP( bot ) < 0.95" "	if J.GetHP( bot ) < 0.60"
score "M7" "the health term moved"

# ---------------------------------------------------------------------------
# M8: the gate's refusal is inverted -- the helper releases unconditionally.
echo
echo "=== M8: the gate returns true instead of false when disarmed ==="
sub "$HERO" "$GATE
	then
		return false
	end" "$GATE
	then
		return true
	end"
score "M8" "the release answered true with nothing armed"

# ---------------------------------------------------------------------------
# M9: the helper names a DIFFERENT, LIVE id in this same file (`wkrosh`).  The
#     `pullcad` trap's sibling: both gates exist, check_armed_wiring.py finds a
#     call site, and a wave arming `wksaveidle` moves nothing.
echo
echo "=== M9: the release names this file's OTHER live id (recoupling) ==="
sub "$HERO" "$GATE" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkrosh' ) )"
score "M9" "the reserve released on someone else's candidate id"

# ---------------------------------------------------------------------------
# M10: A CONTROL ON THE INSTRUMENT, not on the subject.  If the corpus walk
#      stopped seeing the priced frames, section 3's "6 fire, 2 release" would
#      be a reading of a smaller world and every ratio in the file would move
#      with nothing red.  This mutates the TEST, deliberately.
echo
echo "=== M10: the corpus walk silently loses frames (instrument control) ==="
sub "$TEST" "                    if type(u.abilities) == 'table' then out[#out + 1] = path end" \
            "                    if type(u.abilities) == 'table' and #out < 20 then out[#out + 1] = path end"
score "M10" "Wraith King frames, recorded 33"

# ---------------------------------------------------------------------------
# The EXIT trap restores and verifies; do not restore-and-delete here.
echo
echo "=== $CAUGHT/$TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
exit 0
