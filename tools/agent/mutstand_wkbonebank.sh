#!/usr/bin/env bash
# Mutation stand for the `wkbonebank` candidate -- the skeleton-bank conjunct of
# X.ConsiderW's attack branch in Wraith King, the one that prices an ABSOLUTE
# payoff as a RATIO of capacity and is therefore non-monotone in ability rank
# (hero, 2026-09-13, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.wk_IsBoneGuardBankCommittable, X.ConsiderW or
# tests/test_wk_bone_guard_bank_floor.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_lionpushclock.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution);
#   * every `want` is the FIRST thing the mutant makes the suite say.
#
# ⛔ THE FILTER IS THE SINGLE FILE, AND THAT IS LOAD-BEARING.  Backlog -161's
# fourth lesson: a hero-wide filter that carries pre-existing reds makes
# "exit != 0" and "the mutant was caught" the same observation, and they look
# identical.  `wk_bone_guard_bank_floor` is one file and its baseline is
# genuinely green (13/0), which is what `score` assumes.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed path hands back the shipped answer.
#   * M5 removes the CALL SITE by restoring the literal ratio.  Helper, id,
#     header and every algebra test survive; only a wiring census sees it.
#   * M6 is THE DIRECTION MUTANT and the reason §4 exists.  `>=` -> `<=` on the
#     floor still passes every gate-plumbing test and still LOOKS like a
#     widening -- it widens by 11 cells instead of 6 -- but the cells it adds
#     include releasing on an EMPTY bank, which no rank of the shipped rule ever
#     commits on.  §4.2 is the only assertion that can tell those two widenings
#     apart, because it demands a lower-rank WITNESS for each added cell rather
#     than merely counting them.
#   * M7 moves the floor off the value re-derived from the shipped ladder, i.e.
#     invents a free parameter where the header claims a monotone closure.
#   * M8 is the pullcad trap (AGENTS.md): conjoining `wkbonefight` -- the sibling
#     id on the SAME `if`, so the tempting mistake here is unusually tempting --
#     freezes this gate FALSE the day that id is promoted, and
#     check_armed_wiring.py still calls it WIRED.
#   * M9 is a control on §7: adding the `maxStack > 0` guard that any reviewer
#     would ask for is a GATE-OFF BEHAVIOR CHANGE, the one thing a soak candidate
#     may never do.  If §7 cannot see it, the "byte for byte" claim in the helper
#     header is decoration.
#   * M10 is a control on the VALUE argument.  Flatten the skeleton-damage ladder
#     and the inversions stop being DOMINANCE inversions -- non-monotone alone is
#     not a defect.  If §3.1 stays green on a flat ladder, this lever's whole
#     condition (c) was never being checked.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_bone_guard_bank_floor.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkbonebank.XXXXXX")
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
    lua5.1 tests/run_tests.lua wk_bone_guard_bank_floor > "$WORK/run.log" 2>&1
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
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonebank' ) )" \
            "	if not ( J.IsModeTurbo() )"
score "M1" "gate OFF, rank "

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  A soak candidate that
#     can move a normal-mode game is not a soak candidate.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonebank' ) )" \
            "	if not ( J.IsSoakCandidate( 'wkbonebank' ) )"
score "M2" "armed but NON-TURBO, rank "

# ---------------------------------------------------------------------------
# M3: the id is renamed.  A wave that arms `wkbonebank` then arms NOTHING, while
#     every behavioural assertion that drives the helper directly still passes
#     because the test arms whatever the source says.
echo
echo "=== M3: the id is renamed out from under the wave ==="
sub "$HERO" "J.IsSoakCandidate( 'wkbonebank' )" \
            "J.IsSoakCandidate( 'wkbonebank2' )"
score "M3" "no longer names wkbonebank"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper, id, call site and header all survive; the armed leg
#     simply returns the shipped answer.  This is the mutant a gate-plumbing test
#     cannot see, and it is the shape AGENTS.md calls out by name.
echo
echo "=== M4: the armed leg hands back the shipped answer ==="
sub "$HERO" "	return nStack >= X.nBoneGuardShippedFloor" \
            "	return bShipped"
score "M4" "cells, expected 6"

# ---------------------------------------------------------------------------
# M5: the CALL SITE is reverted to the literal ratio.  The helper, the constant,
#     the header and every algebra section stay green -- the lever is simply not
#     in the tree.
echo
echo "=== M5: the call site goes back to the literal ratio ==="
sub "$HERO" "		and ( X.wk_IsBoneGuardBankCommittable( nStack, maxStack ) or talent6:IsTrained() )" \
            "		and ( nStack / maxStack >= 0.6 or talent6:IsTrained() )"
score "M5" "occurrences in code (the "

# ---------------------------------------------------------------------------
# M6: THE DIRECTION MUTANT, and the reason §4 exists.  `>=` -> `<=` is still a
#     widening (11 added cells, not 6) and still passes every plumbing test --
#     but the cells it adds include an EMPTY bank, which no rank of the shipped
#     rule commits on anywhere.  Counting cannot tell the two widenings apart;
#     demanding a lower-rank witness per added cell can.
echo
echo "=== M6: the floor comparison is inverted (widens, but past the closure) ==="
sub "$HERO" "	return nStack >= X.nBoneGuardShippedFloor" \
            "	return nStack <= X.nBoneGuardShippedFloor"
score "M6" "monotone-closure argument does not cover this cell"

# ---------------------------------------------------------------------------
# M7: the floor walks off the value re-derived from the shipped ladder.  The
#     header claims the 2 is READ OFF the shipped rule and is not a tuning knob;
#     if a 3 slips through, that sentence is decoration.
echo
echo "=== M7: the floor is no longer the shipped rule's own smallest commitment ==="
sub "$HERO" "X.nBoneGuardShippedFloor = 2" \
            "X.nBoneGuardShippedFloor = 3"
score "M7" "smallest bank the shipped rule commits on anywhere is"

# ---------------------------------------------------------------------------
# M8: THE PULLCAD TRAP, unusually tempting here because `wkbonefight` gates the
#     enemy-count conjunct of the SAME `if` and "this rides on top of that" is
#     the natural thing to write.  It freezes this gate FALSE the day
#     `wkbonefight` is promoted, and check_armed_wiring.py still says WIRED.
echo
echo "=== M8: the gate names a second id (pullcad trap) ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonebank' ) )" \
            "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkbonebank' ) and J.IsSoakCandidate( 'wkbonefight' ) )"
score "M8" "must hold exactly ONE IsSoakCandidate call"

# ---------------------------------------------------------------------------
# M9: CONTROL ON §7.  Adding the `maxStack > 0` guard is exactly what a reviewer
#     would ask for, and it is a GATE-OFF BEHAVIOR CHANGE: with maxStack 0 and a
#     non-empty bank the shipped expression answers true (inf >= 0.6) and the
#     guarded one answers false.  If §7 cannot see this, "byte for byte" is prose.
echo
echo "=== M9: control -- the degenerate-maxStack gate-OFF cell must be able to go red ==="
sub "$HERO" "	local bShipped = nStack / maxStack >= 0.6" \
            "	local bShipped = maxStack > 0 and nStack / maxStack >= 0.6"
score "M9" "A guard was added to the helper"

# ---------------------------------------------------------------------------
# M10: CONTROL ON CONDITION (c).  Flatten the skeleton-damage ladder in the TEST.
#      The rank inversions survive unchanged -- 4/6 still clears 0.6 and 4/8
#      still does not -- but they stop being DOMINANCE inversions, and
#      non-monotone alone is not a defect.  If §3.1 stays green on a flat ladder,
#      the value half of this lever was never being checked.
echo
echo "=== M10: control -- the dominance half of the argument is un-ratcheted ==="
sub "$TEST" "    skeleton_damage      = { 34, 39, 43, 49 }," \
            "    skeleton_damage      = { 49, 49, 49, 49 },"
score "M10" "not a dominance inversion"

# ---------------------------------------------------------------------------
echo
echo "=== SCORE: $CAUGHT/$TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
