#!/usr/bin/env bash
# Mutation stand for the 'soloclaim' guard (strategy, 2026-09-17 --
# OWNER_PRIORITIES P4.4(i)).
#
# The claim under test: "J.IsOtherAllysTarget's `#hAllyList <= 1` guard is
# written as if the ally ring contained the asker; it never does (self_in_list
# 0 / 1039), so the guard discards a LONE ally's claim unread on 357 of 1039
# frames, and arming 'soloclaim' can only turn a shipped FALSE into TRUE --
# never the reverse (up 184 == armable 184, down 0)."
#
# Run by hand when J.IsOtherAllysTarget, J.IsAllysTarget,
# tests/_soloclaim_sweep.lua or tests/test_soloclaim_lone_ally_claim.lua are
# edited, and before quoting any of these readings anywhere.
#
# DISCIPLINE (inherited from tools/agent/mutstand_pullnolane.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts the WHOLE stand, so a
#     mutant can never score "caught" for having applied to nothing;
#   * the baseline is proven GREEN before the first mutant;
#   * every leg's `want` is the message the reader ACTUALLY gets.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK. A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507).
#
# ⭐ WHICH MUTANTS ARE THE LOAD-BEARING ONES HERE:
#   * S1 IS THE LEVER ITSELF, inverted: gate the guard so it fires only when
#     armed. Every presence check still passes (the id is named, turbo is
#     named, the ordering holds); only the differential can see it.
#   * S3 IS THE ORDER-BLIND ONE. Leave the gate in the function but move the
#     whole guard BELOW the loop. The guard is still there, still compares to
#     1, still names 'soloclaim' -- and it now decides nothing, because the
#     loop has already returned. A file checking presence alone calls this
#     tree unchanged.
#   * S4 IS THE SCOPE ONE: drop `J.IsModeTurbo()` from the conjunction. The
#     lever then fires in every game mode, which is the one thing the charter
#     forbids unconditionally, and no count of flips can see it.
#   * S5 IS THE WRONG-ID ONE: gate on a DIFFERENT live candidate id
#     ('pullcamp'). Every presence check still passes -- there is a gate, it is
#     turbo-scoped, it sits in the right place -- and check_armed_wiring.py
#     would still say WIRED, while this lever now rides another candidate's
#     wave and no-ops in its own. That is the 'pullcad' reading exactly.
#   * S6/S7 ARE THE TWO HALVES OF THE FALSE BELIEF. Deleting `ally ~= bot` is
#     a no-op on behaviour (self_in_list is 0), so only a source pin can see
#     it -- and it is the evidence that the belief was ever held. Widening the
#     guard to `<= 2` eats the two-ally witness instead.
#   * S8 IS THE DISCRIMINATOR. Give the sibling J.IsAllysTarget the same `<= 1`
#     guard. Nothing about J.IsOtherAllysTarget changes, every flip count is
#     byte-identical, and the argument that the sibling reads the list the
#     other way is simply gone. Only the sibling pin can see it.
#   * S9 IS THE ZERO-VALUED COLUMN (taught by mutstand_fieldsip.sh's M8/M13).
#     `down` reads 0 on a clean tree, so renaming its bump would be an
#     EQUIVALENT mutant. What IS checkable is its polarity: swap the two tally
#     legs so the forbidden direction is the one being counted as allowed.
#   * S10 IS THE MEMOISE TRAP, and it is the most expensive one here (0NEXT37).
#     Make `load()` cache its first result, so every leg of every case is
#     served by ONE `rf.load`. That is what "read both answers off one load"
#     actually is, and it is the shape the first draft of the fightfoe sweep
#     shipped: `J.IsModeTurbo` memoises into a module-level cache, so the
#     shipped answer comes back byte-identical to the armed one and the tally
#     reads up == 0 AND down == 0 -- indistinguishable from a perfect
#     direction proof. The un-armed leg's own gate assertion is what refuses
#     it here, one step before the values are ever compared.
#   * S11 IS THE CONTROL. A comment-only edit must SURVIVE, or the stand is
#     scoring the act of editing rather than the edit. ⛔ A stand with no
#     control leg cannot tell "caught everything" from "never ran": the
#     basecreep round scored 12 false CAUGHTs that way (0NEXT36).

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_soloclaim_lone_ally_claim.lua
SWEEP=tests/_soloclaim_sweep.lua

FILES=("$JMZ" "$TEST" "$SWEEP")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_soloclaim.XXXXXX")
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
    lua5.1 tests/run_tests.lua soloclaim_lone_ally_claim > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort on an absent OR ambiguous anchor.
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

sub_or_die() {
    sub "$@" || { echo "ANCHOR FAILURE -- stand aborted, nothing below is meaningful"; exit 3; }
}

GUARD='	if #hAllyList <= 1
		and not ( J.IsModeTurbo() and J.IsSoakCandidate( '"'"'soloclaim'"'"' ) )
	then
		return false
	end
'

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -3 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
SURVIVED=0
TOTAL=0

# `want2` is optional and is NOT a loosening: some mutants can be caught by
# either of two assertions depending on which case run_tests reaches first, and
# a single `want` would then score a genuine catch as "wrong message" on
# whichever ordering the runner happens to pick.  Both strings must still be
# messages the reader can act on.
score() {
    local name="$1" want="$2" want2="${3:-}"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ -n "$want2" ] && grep -qF "$want2" "$WORK/run.log"; then want="$want2"; fi
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
        SURVIVED=$((SURVIVED + 1))
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
        SURVIVED=$((SURVIVED + 1))
    fi
    restore > /dev/null
}

score_control() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- CORRECT, this leg must not be caught"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) -- the stand is scoring the ACT of editing,"
        echo "        not the edit; every count above is suspect:"
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
        SURVIVED=$((SURVIVED + 1))
    fi
    restore > /dev/null
}

echo
echo "=== mutants ==="

# S1 -- the lever inverted: armed is the only state in which the guard fires.
sub_or_die "$JMZ" "$GUARD" '	if #hAllyList <= 1
		and ( J.IsModeTurbo() and J.IsSoakCandidate( '"'"'soloclaim'"'"' ) )
	then
		return false
	end
'
score "S1 lever inverted             " "shipped already answers true" \
      "armed did not see the lone ally"

# S2 -- the guard removed outright (ungated). Shipped stops being shipped.
sub_or_die "$JMZ" "$GUARD" ''
score "S2 guard deleted, not gated   " "shipped already answers true"

# S3 -- order-blind: the guard survives but moves BELOW the loop it gates.
sub_or_die "$JMZ" "$GUARD" ''
sub_or_die "$JMZ" '	return false

end


function J.IsAllysTarget( unit )' '	if #hAllyList <= 1
		and not ( J.IsModeTurbo() and J.IsSoakCandidate( '"'"'soloclaim'"'"' ) )
	then
		return false
	end

	return false

end


function J.IsAllysTarget( unit )'
score "S3 guard moved below the loop " "shipped already answers true"

# S4 -- scope: turbo dropped from the conjunction.
sub_or_die "$JMZ" "$GUARD" '	if #hAllyList <= 1
		and not ( J.IsSoakCandidate( '"'"'soloclaim'"'"' ) )
	then
		return false
	end
'
score "S4 turbo scope dropped        " "the lever fired outside turbo"

# S5 -- id-blind: any candidate's switch arms this lever.
sub_or_die "$JMZ" "$GUARD" '	if #hAllyList <= 1
		and not ( J.IsModeTurbo() and J.IsSoakCandidate( '"'"'pullcamp'"'"' ) )
	then
		return false
	end
'
score "S5 gate reads the wrong id    " "the lever fired under another candidate" \
      "armed did not see the lone ally"

# S6 -- the dead half of the false belief, deleted. No behavioural effect.
sub_or_die "$JMZ" '			and ally ~= bot
			and not ally:IsIllusion()
			and ( J.GetProperTarget( ally ) == unit
					or ( not ally:IsBot() and ally:IsFacingLocation( unit:GetLocation(), 20 ) ) )' '			and not ally:IsIllusion()
			and ( J.GetProperTarget( ally ) == unit
					or ( not ally:IsBot() and ally:IsFacingLocation( unit:GetLocation(), 20 ) ) )'
score "S6 'ally ~= bot' deleted      " "was deleted"

# S7 -- the guard widened to <= 2, eating the two-ally witness.
sub_or_die "$JMZ" '	if #hAllyList <= 1
		and not ( J.IsModeTurbo()' '	if #hAllyList <= 2
		and not ( J.IsModeTurbo()'
score "S7 guard widened to <= 2      " "the shipped guard itself is gone"

# S8 -- the discriminator: give the sibling the same guard.
sub_or_die "$JMZ" '	local hAllyList = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE )

	for _, ally in pairs( hAllyList )
	do
		if J.IsValid( ally )
			and not ally:IsIllusion()' '	local hAllyList = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE )

	if #hAllyList <= 1 then return false end

	for _, ally in pairs( hAllyList )
	do
		if J.IsValid( ally )
			and not ally:IsIllusion()'
score "S8 sibling grew the guard too " "J.IsAllysTarget grew an ally-count guard"

# S9 -- the zero-valued column's POLARITY, in the sweep's tally.
sub_or_die "$SWEEP" "        tally(armed, shipped, 'up')    -- FALSE -> TRUE, the allowed direction
        tally(shipped, armed, 'down')  -- TRUE  -> FALSE, forbidden" "        tally(shipped, armed, 'up')    -- FALSE -> TRUE, the allowed direction
        tally(armed, shipped, 'down')  -- TRUE  -> FALSE, forbidden"
echo -n "S9 tally legs swapped         "
lua5.1 "$SWEEP" > "$WORK/s9.log" 2>&1
S9RC=$?
TOTAL=$((TOTAL + 1))
if [ "$S9RC" -ne 0 ]; then
    echo " RED (exit $S9RC) -- wrong reason"; SURVIVED=$((SURVIVED + 1))
elif grep -qE '^C up 0$' "$WORK/s9.log" && grep -qE '^C down 184$' "$WORK/s9.log"; then
    echo " caught by the SWEEP: up 0 / down 184, i.e. the forbidden direction"
    echo "        now carries the whole population -- the direction claim inverts."
    CAUGHT=$((CAUGHT + 1))
else
    echo " SURVIVED -- the sweep reports the same tally with the legs swapped"
    grep -E '^C (up|down) ' "$WORK/s9.log" | sed 's/^/        /'
    SURVIVED=$((SURVIVED + 1))
fi
restore > /dev/null

# S10 -- the memoise trap: one load, GetGameMode flipped, for both answers.
sub_or_die "$TEST" 'local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end' 'local _one_load = nil
local function load(w)
    if _one_load ~= nil then return _one_load[1], _one_load[2] end
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    _one_load = { J, bot }
    return J, bot
end'
score "S10 ONE load serves both legs " "the gate is open on the un-armed leg" \
      "shipped already answers true"

# S11 -- THE CONTROL. A comment-only edit must survive.
sub_or_die "$TEST" '-- ========================================================= 5. [control]' '-- ============================================== 5. [control] (stand probe)'
score_control "S11 comment-only [control]    "

echo
echo "=== score ==="
echo "TOTAL=$TOTAL  CAUGHT=$CAUGHT  SURVIVED=$SURVIVED"
if [ "$SURVIVED" -ne 0 ]; then
    echo "⛔ $SURVIVED leg(s) the stand cannot see -- read them before quoting"
    echo "   any reading from tests/_soloclaim_sweep.lua."
    exit 1
fi
echo "every leg accounted for, control included"
