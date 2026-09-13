#!/usr/bin/env bash
# Mutation stand for the `wkidleshare` candidate -- the RATIO term inside
# `wksaveidle`'s release in Wraith King: the reserve is only worth releasing while
# it is most of the pool, and X.IsReincarnationReserveIdle had no such term
# (hero, 2026-09-13, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.IsReserveShareHigh, X.IsReincarnationReserveIdle or
# tests/test_wk_reserve_share_floor.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkbonebank.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution);
#   * every `want` is the FIRST thing the mutant makes the suite say.
#
# ⛔ THE FILTER IS THE SINGLE FILE, AND THAT IS LOAD-BEARING.  A hero-wide filter
# carrying pre-existing reds makes "exit != 0" and "the mutant was caught" the
# same observation.  `wk_reserve_share_floor` is one file and its baseline is
# genuinely green (10/0).
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK (GH #507).
#
# ⛔ WHAT THIS STAND IS REALLY FOR, and it is unusual.  This lever's DOMAIN ON THE
# CORPUS IS ZERO -- arming it moves no frame in tests/fixtures.  So almost every
# mutant below is invisible to behaviour and visible only to a source or algebra
# assertion, and a stand is the only way to find out whether those assertions are
# load-bearing or decoration.  A surviving mutant here is not "the predicate is
# redundant"; it is "this file cannot tell whether the predicate is there".
#   * M1/M2 are the gate-polarity mutants.  Because this gate is PERMISSIVE when
#     unarmed, the usual "drop the candidate check" mutant makes the narrowing a
#     DEFAULTS CHANGE in every Turbo game -- the one thing a soak candidate may
#     never do, and the exact mistake the PROMOTE RECIPE block exists to prevent.
#   * M3 is the DEAD-WIRING mutant: helper present, id registered, header intact,
#     and the armed path hands back the shipped answer anyway.
#   * M4 removes the CALL SITE.  Every algebra assertion survives; only the
#     wiring assertion in section 6 sees it.
#   * M5 is the DIRECTION mutant.  `>=` -> `<=` still looks like a narrowing and
#     still passes gate plumbing, but it narrows the OPPOSITE frames -- it would
#     release only in the late game, which is precisely the case the value
#     argument says not to.  It is also the mutant that must break section 4's
#     "the host's own two release frames survive" ratchet.
#   * M6 is the pullcad trap: conjoining the host id freezes this gate FALSE the
#     day `wksaveidle` is promoted, and check_armed_wiring.py still calls it WIRED.
#   * M7 is a control on the CORPUS reading, not on the code: put the falsified
#     rank-3 sentence back in the header.  If section 6 cannot see it, then
#     nothing stops the next round re-deriving the premise this whole lever came
#     from.
#   * M8 is a control on section 5.  Move R's third build-row point from entry 15
#     to entry 13 and the entry-15 wall no longer applies -- the premise would be
#     LIVE again.  If section 5 stays green, it was reading a number it typed in
#     rather than the file's own rows.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_reserve_share_floor.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkidleshare.XXXXXX")
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
    lua5.1 tests/run_tests.lua wk_reserve_share_floor > "$WORK/run.log" 2>&1
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

GATE="	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkidleshare' ) )"

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
# M1: the candidate check is dropped.  Because this gate is PERMISSIVE when
#     unarmed, dropping the id makes the narrowing the Turbo DEFAULT.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE" "	if not ( J.IsModeTurbo() )"
score "M1" "no longer names wkidleshare"

# ---------------------------------------------------------------------------
# M2: turbo-only dropped, candidate check kept.  A soak candidate that can move a
#     normal-mode game is not a soak candidate.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "$GATE" "	if not ( J.IsSoakCandidate( 'wkidleshare' ) )"
score "M2" "lost its own turbo guard"

# ---------------------------------------------------------------------------
# M3: DEAD WIRING.  Helper, id, header, call site all present; the armed path
#     simply answers the shipped answer.
echo
echo "=== M3: armed, the helper hands back the unarmed answer ==="
sub "$HERO" "	return ( nReserve / nMaxMana ) >= X.nReserveShareFloor" \
            "	return true"
score "M3" "the share falls under the floor"

# ---------------------------------------------------------------------------
# M4: the CALL SITE is removed.  Every algebra assertion about the helper still
#     passes; the helper is simply never consulted.
echo
echo "=== M4: the release stops consulting the ratio term ==="
sub "$HERO" "	if not X.IsReserveShareHigh()
	then
		return false
	end

	if J.GetHP( bot ) < 0.95" \
            "	if J.GetHP( bot ) < 0.95"
score "M4" "no longer consults the ratio term"

# ---------------------------------------------------------------------------
# M5: THE DIRECTION MUTANT.  `>=` -> `<=` keeps every gate-plumbing property and
#     inverts which frames the lever releases on.
echo
echo "=== M5: the floor comparison is inverted ==="
sub "$HERO" "	return ( nReserve / nMaxMana ) >= X.nReserveShareFloor" \
            "	return ( nReserve / nMaxMana ) <= X.nReserveShareFloor"
score "M5" "the armed helper now REFUSES it"

# ---------------------------------------------------------------------------
# M6: the pullcad trap.  Conjoining the HOST id freezes this gate FALSE the day
#     `wksaveidle` is promoted.
echo
echo "=== M6: the gate is conjoined with its host id ==="
sub "$HERO" "$GATE" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkidleshare' ) and J.IsSoakCandidate( 'wksaveidle' ) )"
score "M6" "soak ids"

# ---------------------------------------------------------------------------
# M7: the falsified premise is put back verbatim.  This is a control on section
#     6, and on whether anything stops the next round re-deriving it.
echo
echo "=== M7: the struck rank-3 premise is re-asserted in the header ==="
sub "$HERO" "--- to \"never cast\" for as long as R sits at rank 1." \
            "--- to \"never cast\" for as long as R sits at rank 1.  Note the reserve already
--- collapses on its own at R rank 3, where Reincarnation is FREE."
score "M7" "appears 2 times"

# ---------------------------------------------------------------------------
# M8: a control on section 5.  Move R's third point inside the 13-point budget
#     and the wall no longer applies -- the premise would be live again.
echo
echo "=== M8: R's third build-row point is moved inside the 13-point budget ==="
sub "$HERO" "							{2,1,2,3,2,6,2,3,3,3,6,1,1,1,6},--pos1,3" \
            "							{2,1,2,3,2,6,2,3,3,3,6,1,6,1,1},--pos1,3"
score "M8" "not 15"

# ---------------------------------------------------------------------------
echo
echo "=== score ==="
echo "$CAUGHT/$TOTAL mutants caught with an actionable message"
if [ "$CAUGHT" -ne "$TOTAL" ]; then
    echo "⚠️  a surviving mutant here is a hole in the assertions, not a redundant"
    echo "    predicate.  Fix the test, or write the survival into its header as a"
    echo "    declared limit -- do not quote this stand as clean."
    exit 1
fi
