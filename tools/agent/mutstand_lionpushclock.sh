#!/usr/bin/env bash
# Mutation stand for the `lionpushclock` candidate -- the wall-clock curfew on
# X.ConsiderQ's 推线 (lane-push) firing point in Lion, the only wall-clock
# COMPARISON in bots/BotLib/hero_lion.lua (hero, 2026-09-12, OWNER_PRIORITIES
# P4.4 (i)).  Run by hand when X.lion_IsLanePushClockOpen, X.ConsiderQ or
# tests/test_lion_q_lane_push_clock.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axecallclock.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution);
#   * every `want` is the FIRST thing the mutant makes the suite say.
#
# ⛔ THE FILTER IS THE SINGLE FILE, AND THAT IS LOAD-BEARING HERE.  Backlog -160
# recorded that a `lion` filter carries SEVEN pre-existing reds on a clean tree
# (6 x test_lion_considere_earlyreturn_domain.lua + 1 x
# test_lion_ult_cash_weakest.lua), which would make `exit != 0` and "the mutant
# was caught" the same observation -- and they look identical.  Filtering to this
# one file makes the baseline genuinely green, which is what `score` assumes.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M4 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed path hands back the shipped answer.
#   * M5 removes the CALL SITE by restoring the literal.  Helper, id, header and
#     every constant test survive; only a ratchet that counts the WIRING sees it.
#   * M6 is THE DIRECTION MUTANT and the reason §4 exists: swap the two
#     thresholds and the lever silently becomes a NARROWING -- it would then
#     REFUSE lane-push Impales between 4:30 and 9:00 that shipped allows, and
#     every "a negative wave means those extra casts were bad" sentence in the
#     header would be false.
#   * M7 moves the armed threshold off SHIPPED/2, i.e. invents a free parameter
#     where the header claims this repo's own stated Turbo pace ratio.
#   * M8 is the pullcad trap (AGENTS.md): conjoining a sibling id -- the tempting
#     way to write "this rides on top of that" -- freezes this gate FALSE the day
#     that id is promoted, and check_armed_wiring.py still calls it WIRED.
#   * M9 is a control on the STAND ITSELF: the 5-instant gate-layer domain census
#     must be able to go red, or "5 of 14" is a sentence rather than a limit.
#   * M10 is a control on the (c) ARGUMENT: if reordering the ability build row
#     so Impale is no longer rank 4 by hero level 8 does not turn §5.4 red, then
#     the condition (c) this lever ships on was never being checked.  The mutant
#     row is a PERMUTATION of the shipped one (same multiset of points), so only
#     the level-8 prefix reading can tell them apart.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_q_lane_push_clock.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lionpushclock.XXXXXX")
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
    lua5.1 tests/run_tests.lua lion_q_lane_push_clock > "$WORK/run.log" 2>&1
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
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'lionpushclock' )" \
            "	if J.IsModeTurbo()"
score "M1" "shipped leg should REFUSE inside"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  A soak candidate that
#     can move a normal-mode game is not a soak candidate.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'lionpushclock' )" \
            "	if J.IsSoakCandidate( 'lionpushclock' )"
score "M2" "armed but NOT turbo must answer exactly what shipped answers"

# ---------------------------------------------------------------------------
# M3: the id is renamed.  A wave that arms `lionpushclock` then arms NOTHING,
#     while every behavioural assertion that drives the helper directly still
#     passes because the test arms whatever the source says.
echo
echo "=== M3: the id is renamed out from under the wave ==="
sub "$HERO" "J.IsSoakCandidate( 'lionpushclock' )" \
            "J.IsSoakCandidate( 'lionpushclock2' )"
score "M3" "no longer names lionpushclock"

# ---------------------------------------------------------------------------
# M4: DEAD WIRING.  Helper, id, call site and header all survive; the armed leg
#     simply returns the shipped answer.  This is the mutant that a gate-plumbing
#     test cannot see, and it is the shape AGENTS.md calls out by name.
echo
echo "=== M4: the armed leg hands back the shipped answer ==="
sub "$HERO" "		return DotaTime() > X.nQLanePushClockTurbo" \
            "		return DotaTime() > X.nQLanePushClockShipped"
score "M4" "armed leg should ADMIT inside the"

# ---------------------------------------------------------------------------
# M5: the CALL SITE is reverted to the literal.  The helper, the constants, the
#     header and §2 all stay green -- the lever is simply not in the tree.
echo
echo "=== M5: the call site goes back to the literal clock ==="
sub "$HERO" "		and nSkillLV >= 4 and X.lion_IsLanePushClockOpen()" \
            "		and nSkillLV >= 4 and DotaTime() > 9 * 60"
score "M5" "occurrences in code"

# ---------------------------------------------------------------------------
# M6: THE DIRECTION MUTANT.  Swap the thresholds and the lever becomes a
#     NARROWING: armed refuses casts in (4:30, 9:00] that shipped allows.  Every
#     attribution sentence in the header inverts and nothing else changes shape.
echo
echo "=== M6: the two thresholds are swapped (widening becomes narrowing) ==="
sub "$HERO" "X.nQLanePushClockShipped = 9 * 60
X.nQLanePushClockTurbo   = 4.5 * 60" \
            "X.nQLanePushClockShipped = 4.5 * 60
X.nQLanePushClockTurbo   = 9 * 60"
score "M6" "shipped clock moved to"

# ---------------------------------------------------------------------------
# M7: the armed threshold walks off SHIPPED/2.  The header claims the 2x is this
#     repo's own stated Turbo pace ratio and not a free parameter; if 6:00 slips
#     through, that sentence is decoration.
echo
echo "=== M7: the armed threshold is no longer the shipped one halved ==="
sub "$HERO" "X.nQLanePushClockTurbo   = 4.5 * 60" \
            "X.nQLanePushClockTurbo   = 6 * 60"
score "M7" "is no longer SHIPPED/2"

# ---------------------------------------------------------------------------
# M8: THE PULLCAD TRAP.  Conjoining a sibling id is the tempting way to write
#     "this rides on top of that"; it freezes this gate FALSE the day that id is
#     promoted, and check_armed_wiring.py still calls the call site WIRED.
echo
echo "=== M8: the gate names a second id (pullcad trap) ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'lionpushclock' )" \
            "	if J.IsModeTurbo() and J.IsSoakCandidate( 'lionpushclock' ) and J.IsSoakCandidate( 'lionqfight' )"
score "M8" "must hold exactly ONE IsSoakCandidate call"

# ---------------------------------------------------------------------------
# M9: CONTROL ON THE STAND ITSELF.  Collapse the window inside the TEST so the
#     five in-window instants stop being in-window.  If §3.1 stays green,
#     "5 of 14" was never a measured domain.
echo
echo "=== M9: control -- the gate-layer domain census must be able to go red ==="
sub "$TEST" "        if fr.t > TURBO and fr.t <= SHIPPED then hit[#hit + 1] = fr end" \
            "        if fr.t > SHIPPED and fr.t <= SHIPPED then hit[#hit + 1] = fr end"
score "M9" "expected at least 5 Lion-subject instants"

# ---------------------------------------------------------------------------
# M10: CONTROL ON CONDITION (c).  Permute the ability build row so Impale is no
#      longer rank 4 by hero level 8 (the branch's own `nSkillLV >= 4`).  The
#      lever's whole (c) argument is that the branch's precondition is satisfied
#      long before the curfew lifts; if §5.4 cannot see the row change, that
#      argument is unguarded prose.
echo
echo "=== M10: control -- the (c) argument's build row is un-ratcheted ==="
sub "$HERO" "						{1,3,1,2,3,6,1,1,3,3,6,2,2,2,6}," \
            "						{1,3,1,2,3,6,1,3,1,3,6,2,2,2,6},"
score "M10" "reaches only rank"

# ---------------------------------------------------------------------------
echo
echo "=== SCORE: $CAUGHT/$TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
