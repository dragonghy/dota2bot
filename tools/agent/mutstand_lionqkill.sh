#!/usr/bin/env bash
# Mutation stand for the `lionqkill` candidate -- the reach term on
# X.ConsiderQ's 击杀 loop, the one drop-out point of twelve in that function
# that can hand the engine an Earth Spike cast point outside cast range
# (hero, 2026-09-08, OWNER_PRIORITIES P4.4 (i)).  Run by hand when
# X.lion_IsImpaleKillTargetInReach, X.ConsiderQ or
# tests/test_lion_q_kill_reach.lua are edited, and before quoting any of that
# file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusjumpland.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring
#     (and an aborted mutant is NOT a surviving mutant);
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.  In a double-quoted bash string
#     that is command substitution.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# ⚠️ AMBIGUITY IS THE LIVE RISK IN THIS FILE, not a theoretical one.  This
# helper's four guard lines are TEXTUALLY IDENTICAL to
# X.lion_ShouldCommitUltKill's (same shape, same argument names, deliberately --
# `lionrreach` is this lever's R sibling).  So every anchor below spans the ONE
# line that carries this id.  Anchoring on a guard line alone would apply the
# mutant to the ult lever and score SURVIVED for the wrong reason.
#
# WHAT THIS STAND IS FOR.  The failure modes that would leave this lever LOOKING
# landed while it moved nothing, or moved the wrong thing:
#   * M5 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, armed path hands back the shipped answer.  check_armed_wiring.py
#     still says WIRED; the verdict reads back "tested, no effect".
#   * M7 is the same thing wearing this lever's own arithmetic: freeze the ring
#     at the 670 that happens to be correct on today's corpus and the aether
#     lens bonus plus the file's own +20 stop composing -- correct on every
#     fixture, wrong in any game where Lion buys the lens.
#   * M4 is the WIDENING.  Drop the shipped early-out and armed can turn a
#     shipped false into a true, so the id stops being a strict narrowing and a
#     negative wave reading could no longer be attributed to removed casts.
#   * M8 gives back exactly what the lever took while still reading as a reach
#     term.
#   * M9 is a control on the STAND ITSELF: a limit that cannot go red is a
#     sentence, not a limit.
#   * M10 is the pullcad trap (AGENTS.md) in its native habitat -- conjoining
#     `lionqdmg`, the very id this lever's domain waits on.  That is the ONE
#     wrong way to encode a dependency the whole §0.2 note is about, and it is
#     the mutant a reader is most likely to think is an improvement.

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_lion.lua
TEST=tests/test_lion_q_kill_reach.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_lqk.XXXXXX")
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

# The filter is `lion`, not this one file: the sibling Lion assertions read the
# same hero module, and a stand scoped to the new file alone would report a
# collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua lion > "$WORK/run.log" 2>&1
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

# The whole predicate body, anchored on the one line carrying this id.
BODY="	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionqkill' ) ) then return bShippedLethal end

	if hBot == nil or hTarget == nil then return bShippedLethal end

	if type( nCastRange ) ~= 'number' then return bShippedLethal end

	return J.IsInRange( hTarget, hBot, nCastRange )"

SHIPPEDOUT="function X.lion_IsImpaleKillTargetInReach( hBot, hTarget, nCastRange, bShippedLethal )

	if not bShippedLethal then return bShippedLethal end
"

CALLSITE="			and X.lion_IsImpaleKillTargetInReach( bot, npcEnemy, nCastRange,
					J.WillMagicKillTarget( bot, npcEnemy, nDamage, 5.0 ) )"

CLAMP="J.GetDelayCastLocation( bot, botTarget, nCastRange, 260, nDelayTime )"

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
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionqkill' ) ) then return bShippedLethal end" \
              "	if not ( J.IsModeTurbo() ) then return bShippedLethal end"
score "M1" "gate-off changed the answer"

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  Only the explicit
#     non-turbo case in section 3 can see it.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionqkill' ) ) then return bShippedLethal end" \
              "	if not ( J.IsSoakCandidate( 'lionqkill' ) ) then return bShippedLethal end"
score "M2" "armed outside turbo refused a target"

# ---------------------------------------------------------------------------
# M3: THE GATE POINTS THE OTHER WAY.  Armed refuses exactly the targets the
#     ability CAN reach and accepts the ones it cannot -- the opposite of every
#     sentence written about it, while staying gated, wired and turbo-only.
echo
echo "=== M3: the ring test is inverted ==="
sub "$HERO" "$BODY" "${BODY%return J.IsInRange( hTarget, hBot, nCastRange )}return not J.IsInRange( hTarget, hBot, nCastRange )"
score "M3" "armed accepted a target 6.42u out of range"

# ---------------------------------------------------------------------------
# M4: THE WIDENING.  The shipped early-out is dropped, so the armed path is
#     reachable with bShippedLethal false and can answer TRUE on a target the
#     shipped code refuses.  The id stops being a strict narrowing.
echo
echo "=== M4: the shipped early-out is dropped, so armed can widen ==="
sub "$HERO" "$SHIPPEDOUT" "function X.lion_IsImpaleKillTargetInReach( hBot, hTarget, nCastRange, bShippedLethal )
"
score "M4" "armed manufactured a cast"

# ---------------------------------------------------------------------------
# M5: DEAD WIRING.  Helper present, id registered, call site present, armed path
#     hands back the shipped answer anyway.
echo
echo "=== M5: the armed path returns the shipped answer (dead wiring) ==="
sub "$HERO" "$BODY" "${BODY%return J.IsInRange( hTarget, hBot, nCastRange )}return bShippedLethal"
score "M5" "an in-ring-kept cast is at"

# ---------------------------------------------------------------------------
# M6: THE CALL SITE IS REMOVED.  The helper, its note, its id registration and
#     its unit tests all survive; the 击杀 loop goes back to bidding on targets
#     it cannot reach.
echo
echo "=== M6: the 击杀 loop stops routing through the helper ==="
sub "$HERO" "$CALLSITE" "			and J.WillMagicKillTarget( bot, npcEnemy, nDamage, 5.0 )"
score "M6" "the 击杀 loop no longer routes through"

# ---------------------------------------------------------------------------
# M7: DEAD WIRING WEARING THIS LEVER'S OWN ARITHMETIC.  The ring is frozen at the
#     670 that is correct on every fixture (no Lion in the corpus owns an aether
#     lens), so the passed-in nCastRange stops composing with the lens bonus and
#     with the file's own +20.  Right answer on the corpus, wrong function.
echo
echo "=== M7: the ring is frozen at today's constant instead of the argument ==="
sub "$HERO" "$BODY" "${BODY%return J.IsInRange( hTarget, hBot, nCastRange )}return J.IsInRange( hTarget, hBot, 670 )"
score "M7" "armed refused an in-ring target"

# ---------------------------------------------------------------------------
# M8: THE SLACK THAT GIVES BACK WHAT THE LEVER TOOK.  Still a reach term, still
#     reads as one, and it re-admits the entire band the id exists to refuse.
echo
echo "=== M8: the ring is widened by the bonus list's own +200 ==="
sub "$HERO" "$BODY" "${BODY%return J.IsInRange( hTarget, hBot, nCastRange )}return J.IsInRange( hTarget, hBot, nCastRange + 200 )"
score "M8" "an in-ring-kept cast is at"

# ---------------------------------------------------------------------------
# M9: A CONTROL ON THE STAND ITSELF.  Limit 2 excuses leaving the 攻击 branch's
#     +300 guard alone on the grounds that J.GetDelayCastLocation clamps it
#     downstream.  Break the clamp and the limit must go red -- otherwise it is
#     a sentence, not a limit, and the next reader inherits an excuse nothing
#     checks.
echo
echo "=== M9: the 攻击 branch's downstream clamp is removed (limit-2 control) ==="
sub "$HERO" "$CLAMP" "J.GetDelayCastLocation( bot, botTarget, nCastRange, 0, nDelayTime )"
score "M9" "no longer clamps through J.GetDelayCastLocation"

# ---------------------------------------------------------------------------
# M10: THE PULLCAD TRAP, in its native habitat.  `lionqdmg` is the id this
#     lever's domain waits on, so conjoining it LOOKS like encoding the
#     dependency in code instead of prose.  It is the one thing that must not
#     happen: the day `lionqdmg` is promoted it is in no armed string, this gate
#     freezes FALSE forever, check_armed_wiring.py still calls it WIRED, and the
#     verdict reads back "tested, no effect" with nothing raising a hand.
echo
echo "=== M10: the gate is conjoined with lionqdmg (pullcad trap) ==="
sub "$HERO" "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionqkill' ) ) then return bShippedLethal end" \
              "	if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'lionqkill' ) and J.IsSoakCandidate( 'lionqdmg' ) ) then return bShippedLethal end"
score "M10" "in its own body"

# ---------------------------------------------------------------------------
echo
echo "=== stand result ==="
echo "CAUGHT $CAUGHT / $TOTAL"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
