#!/usr/bin/env bash
# Mutation stand for the `cullthresh` candidate -- Axe's Culling Blade execute
# threshold read off the ability instead of hardcoded (hero, 2026-09-05, the
# registered hero-2 lever, GH #115 section 5).  Run by hand when
# X.CullKillThreshold, X.IsCullThresholdOn, X.ConsiderR or any of the four Axe
# threshold test files are edited, and before quoting any of their readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusboltdom.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader; the 2026-09-05T01:50Z round produced a Lua syntax error at a line number
# that exists in no version of the file that way (GH #507).
#
# WHAT THIS STAND IS FOR.  Two of the mutants are the ones that actually happened
# while this lever was being written, kept because a stand that only contains
# invented failures is a stand nobody has calibrated:
#   * M4 is the FIRST DRAFT of the guard (`nLive > 0`).  It is not a strawman --
#     it looks obviously sufficient, it passes every gate-plumbing check, and it
#     lets a small positive read NARROW the execute test, which is the one
#     direction this lever is forbidden to move in.
#   * M8 is a control on the INSTRUMENT, not on the subject: if the anchor ladder
#     and the loader stopped being cross-checked, section 1 would be reading its
#     own constant back and calling it a measurement.
#
# Usage: bash tools/agent/mutstand_cullthresh.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_cull_threshold_gate.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_cth.XXXXXX")
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

# The filter is `axe`, not this one file: three SIBLING files carry threshold
# ratchets (preflight, band_power, bkb_supply_staged_frame) and several mutants
# below are meant to be caught by them.  A stand scoped to the new file only
# would report those as SURVIVED and hide that the ratchets are load-bearing.
run_tests() {
    lua5.1 tests/run_tests.lua axe > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex), and abort if the anchor is gone -- a mutant
# that silently applied to nothing scores "caught" for the wrong reason.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
if old not in s:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
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
# M1: the armed read is replaced by a re-hardcode of TODAY's ladder.  Behaviour
#     is byte-identical on this patch and stale on the next one -- exactly the
#     defect being fixed, wearing the fix's name.  No behavioural case can see
#     it; only the pre-flight's "the fix that landed is the READ" ratchet can.
echo
echo "=== M1: the armed path hardcodes today's numbers instead of reading them ==="
sub "$HERO" "		local nLive = abilityR:GetSpecialValueInt( 'damage' )" \
            "		local nLive = ({ 275, 375, 475 })[math.min( nSkillLV, 3 )]"
score "M1" "The armed path no longer reads abilityR:GetSpecialValueInt"

# ---------------------------------------------------------------------------
# M2: the candidate check is dropped.  The wider threshold is now the shipped
#     default in every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M2: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "	return J.IsModeTurbo() and J.IsSoakCandidate( 'cullthresh' )" \
            "	return J.IsModeTurbo()"
score "M2" "rank 1 unarmed must be 250"

# ---------------------------------------------------------------------------
# M3: turbo-only is dropped, the candidate check kept.  The narrower half of M2,
#     and the one a gate-plumbing test would miss.
echo
echo "=== M3: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "	return J.IsModeTurbo() and J.IsSoakCandidate( 'cullthresh' )" \
            "	return J.IsSoakCandidate( 'cullthresh' )"
score "M3" "the mode half of the gate did not hold"

# ---------------------------------------------------------------------------
# M4: THE FIRST DRAFT.  The shipped value stops being the floor and the guard is
#     back to "is the read positive".  Today's loader answers 275 so every
#     behavioural case still passes; a degenerate small read (1) then NARROWS the
#     execute test and Axe declines kills it used to take.  This is the mutant the
#     direction case exists for, and the reason that case sweeps a read ladder
#     rather than checking one value.
echo
echo "=== M4: the shipped floor is weakened back to \`nLive > 0\` (the first draft) ==="
sub "$HERO" "		if type( nLive ) == 'number' and nLive > nKillDamage" \
            "		if type( nLive ) == 'number' and nLive > 0"
score "M4" "This lever is allowed to widen the execute test and nothing else"

# ---------------------------------------------------------------------------
# M5: the dead-helper twin.  The armed branch never returns, so the helper always
#     answers the shipped value -- which is EXACTLY what a correct helper answers
#     whenever the gate is off, i.e. in every shipped game.  Without this mutant
#     the stand could not tell "gated" from "wired to nothing".
echo
echo "=== M5: the armed branch never returns (the dead-helper twin) ==="
sub "$HERO" "			return nLive
		end" "			return nKillDamage
		end"
score "M5" "armed must return the ability value"

# ---------------------------------------------------------------------------
# M6: the talent term is added on top of the ability's own value -- the
#     double-count the old comment at the call site warned about, and the one the
#     shipped tree hides because that talent handle answers 0.  Only a case that
#     builds the world where the handle answers a real number can see it.
echo
echo "=== M6: the armed value double-counts the talent the engine already folded ==="
sub "$HERO" "			return nLive
		end" "			return nLive + nKillDamage - ( 150 + 100 * nSkillLV )
		end"
score "M6" "the talent was added a second time"

# ---------------------------------------------------------------------------
# M7: the call site goes around the gate and computes the threshold inline again.
#     The helper is untouched and every helper-level case still passes -- the gate
#     is simply not on the path any more.  Three files check this, on purpose.
echo
echo "=== M7: X.ConsiderR bypasses the helper and inlines the constant ==="
sub "$HERO" "	local nKillDamage = X.CullKillThreshold( nSkillLV )" \
            "	local nKillDamage = 150 + 100 * nSkillLV"
score "M7" "X.ConsiderR no longer calls the helper"

# ---------------------------------------------------------------------------
# M8: a control on the INSTRUMENT rather than the subject.  Section 1 claims to
#     have MEASURED the 25-point gap on a real frame; that claim rests entirely on
#     the KV anchor and the loader being cross-checked against each other.  Move
#     the anchor to the stale ladder: if the file still passes, section 1 was
#     reading its own constant back and calling it a measurement.
echo
echo "=== M8: the KV anchor is moved to the stale ladder (control on the instrument) ==="
sub "$TEST" "local R_DAMAGE = { 275, 375, 475 }" \
            "local R_DAMAGE = { 250, 350, 450 }"
score "M8" "the KV snapshot"

# ---------------------------------------------------------------------------
# The EXIT trap restores and verifies; do not restore-and-delete here, or the
# trap fires against a work dir that is already gone and reports a false
# "the working tree still holds a mutant".
echo
echo "=== $CAUGHT / $TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
