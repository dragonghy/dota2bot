#!/usr/bin/env bash
# Mutation stand for the `axecallclock` candidate -- the wall-clock curfew on
# X.ConsiderQ's 带线 (lane-push) firing point in Axe, the only wall clock in
# bots/BotLib/hero_axe.lua (hero, 2026-09-12, OWNER_PRIORITIES P4.4 (i)).  Run by
# hand when X.axe_IsLanePushClockOpen, X.ConsiderQ or
# tests/test_axe_q_lane_push_clock.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmrsolo.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick (command substitution);
#   * every `want` is the FIRST thing the mutant makes the suite say.
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
#     REFUSE taunts between 3:00 and 6:00 that shipped allows, and every
#     "a negative wave means those extra taunts were bad" sentence in the header
#     would be false.
#   * M7 moves the armed threshold off SHIPPED/2, i.e. invents a free parameter
#     where the header claims this repo's own stated Turbo pace ratio.
#   * M8 is the pullcad trap (AGENTS.md): conjoining a sibling id -- the tempting
#     way to write "this rides on top of that" -- freezes this gate FALSE the day
#     that id is promoted, and check_armed_wiring.py still calls it WIRED.
#   * M9 is a control on the STAND ITSELF: the 2-instant gate-layer domain census
#     must be able to go red, or "2 of 16" is a sentence rather than a limit.
#   * M10 is a control on the (c) ARGUMENT: if breaking the ability build row so
#     Counter Helix is no longer rank 4 by level 7 does not turn §5.4 red, then
#     the condition (c) this lever ships on was never being checked.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_q_lane_push_clock.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_axecallclock.XXXXXX")
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

# The filter is the single file: this stand mutates shipped Axe source that other
# Axe assertions also read, and a wider filter would let a pre-existing red in a
# sibling file abort every baseline.  What the stand is measuring is whether THIS
# test file can see each mutant.
run_tests() {
    lua5.1 tests/run_tests.lua axe_q_lane_push_clock > "$WORK/run.log" 2>&1
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
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallclock' )" \
            "	if J.IsModeTurbo()"
score "M1" "shipped leg should REFUSE inside"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  A soak candidate that
#     can move a normal-mode game is not a soak candidate.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallclock' )" \
            "	if J.IsSoakCandidate( 'axecallclock' )"
score "M2" "armed but NOT turbo must answer exactly what shipped answers"

# ---------------------------------------------------------------------------
# M3: the id is renamed.  A wave that arms `axecallclock` then arms NOTHING,
#     while every behavioural assertion that drives the helper directly still
#     passes because the test arms whatever the source says.
echo
echo "=== M3: the id is renamed out from under the wave ==="
sub "$HERO" "J.IsSoakCandidate( 'axecallclock' )" \
            "J.IsSoakCandidate( 'axecallclock2' )"
score "M3" "no longer names axecallclock"

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
sub "$HERO" "		and X.axe_IsLanePushClockOpen()" \
            "		and DotaTime() > 6 * 60"
score "M5" "occurrences in code"

# ---------------------------------------------------------------------------
# M6: THE DIRECTION MUTANT.  Swap the thresholds and the lever becomes a
#     NARROWING: armed refuses taunts in (3:00, 6:00] that shipped allows.  Every
#     attribution sentence in the header inverts and nothing else changes shape.
echo
echo "=== M6: the two thresholds are swapped (widening becomes narrowing) ==="
sub "$HERO" "X.nQLanePushClockShipped = 6 * 60
X.nQLanePushClockTurbo   = 3 * 60" \
            "X.nQLanePushClockShipped = 3 * 60
X.nQLanePushClockTurbo   = 6 * 60"
score "M6" "shipped clock moved to"

# ---------------------------------------------------------------------------
# M7: the armed threshold walks off SHIPPED/2.  The header claims the 2x is this
#     repo's own stated Turbo pace ratio and not a free parameter; if 4:00 slips
#     through, that sentence is decoration.
echo
echo "=== M7: the armed threshold is no longer the shipped one halved ==="
sub "$HERO" "X.nQLanePushClockTurbo   = 3 * 60" \
            "X.nQLanePushClockTurbo   = 4 * 60"
score "M7" "is no longer SHIPPED/2"

# ---------------------------------------------------------------------------
# M8: THE PULLCAD TRAP.  Conjoining a sibling id is the tempting way to write
#     "this rides on top of that"; it freezes this gate FALSE the day that id is
#     promoted, and check_armed_wiring.py still calls the call site WIRED.
echo
echo "=== M8: the gate names a second id (pullcad trap) ==="
sub "$HERO" "	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallclock' )" \
            "	if J.IsModeTurbo() and J.IsSoakCandidate( 'axecallclock' ) and J.IsSoakCandidate( 'axecallbkb_i' )"
score "M8" "must hold exactly ONE IsSoakCandidate call"

# ---------------------------------------------------------------------------
# M9: CONTROL ON THE STAND ITSELF.  Raise the window floor inside the TEST so the
#     two in-window instants stop being in-window.  If §3.1 stays green, "2 of 16"
#     was never a measured domain.
echo
echo "=== M9: control -- the gate-layer domain census must be able to go red ==="
sub "$TEST" "        if fr.t > TURBO and fr.t <= SHIPPED then hit[#hit + 1] = fr end" \
            "        if fr.t > SHIPPED and fr.t <= SHIPPED then hit[#hit + 1] = fr end"
score "M9" "expected at least 2 Axe-subject instants"

# ---------------------------------------------------------------------------
# M10: CONTROL ON CONDITION (c).  Break the ability build row so Counter Helix is
#      no longer rank 4 by hero level 7.  The lever's whole (c) argument is that
#      the branch's payoff engine is at full rank long before the curfew lifts; if
#      §5.4 cannot see the row change, that argument is unguarded prose.
echo
echo "=== M10: control -- the (c) argument's build row is un-ratcheted ==="
sub "$HERO" "	{2,3,1,3,3,6,3,2,2,2,6,1,1,1,6},--pos3" \
            "	{2,3,1,2,2,6,2,3,3,3,6,1,1,1,6},--pos3"
score "M10" "reaches only rank"

# ---------------------------------------------------------------------------
echo
echo "=== SCORE: $CAUGHT/$TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
