#!/usr/bin/env bash
# Mutation stand for tests/test_zeus_aether_cast_range.lua -- the `zusaether`
# candidate (hero, 2026-09-04).  Run by hand when that file or the Zeus
# cast-range wiring is edited, and before quoting any of its numbers.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418: an
#     interrupted stand otherwise leaves the MUTANT in the working tree);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS FOR.  This candidate has one failure mode that ordinary
# gate tests do not: the subject is a SEARCH RADIUS, not an action.  A test that
# only watched the returned desire would be green under every mutant below,
# because neither pinned frame flips its desire (that limit is registered in the
# test file itself).  The instrument is the radius spy, and M1/M2 exist to prove
# the spy is what is holding the file up.
#
# Usage: bash tools/agent/mutstand_zusaether.sh
set -u
cd "$(dirname "$0")/../.."

TEST=tests/test_zeus_aether_cast_range.lua
HERO=bots/BotLib/hero_zuus.lua

FILES=("$TEST" "$HERO")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_za.XXXXXX")
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
    lua5.1 tests/run_tests.lua test_zeus_aether_cast_range > "$WORK/run.log" 2>&1
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
# M1: the half-wiring comes back on the Q site -- literally the shipped defect
#     this round found.  This is the regression the whole file exists to stop.
echo
echo "=== M1: ConsiderQ loses the aether term again (the shipped defect) ==="
sub "$HERO" 'local nCastRange = abilityQ:GetCastRange() + AetherReach()' \
            'local nCastRange = abilityQ:GetCastRange()'
score "M1" "must route exactly 3 cast-range reads"

# ---------------------------------------------------------------------------
# M2: the gate is dropped -- the bonus applies in every game, including normal
#     mode.  A shipped-defaults change wearing a candidate's name.
echo
echo "=== M2: AetherReach stops asking whether the candidate is armed ==="
sub "$HERO" '	if J.IsModeTurbo() and J.IsSoakCandidate( '"'"'zusaether'"'"' )
	then
		return aetherRange
	end

	return 0' '	return aetherRange'
score "M2" "unarmed must search the bare"

# ---------------------------------------------------------------------------
# M3: turbo-only is dropped, the gate itself kept.  The narrower half of M2 and
#     the one a gate-plumbing test would miss.
echo
echo "=== M3: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" 'if J.IsModeTurbo() and J.IsSoakCandidate( '"'"'zusaether'"'"' )' \
            'if J.IsSoakCandidate( '"'"'zusaether'"'"' )'
score "M3" "the gate is turbo-only"

# ---------------------------------------------------------------------------
# M4: the producer routing is reverted to the inherited literal.  The two levers
#     stop composing: 'aetherlens' can no longer correct 250 -> 225 here.  This
#     is the mutant a test that only drove ONE gate combination would survive.
echo
echo "=== M4: the producer goes back to a hand-written 250 ==="
sub "$HERO" 'aetherRange = J.GetAetherLensRangeBonus( aether, 250 )' \
            'aetherRange = 250'
score "M4" "must hand the helper the shipped"

# ---------------------------------------------------------------------------
# M5: THE pullcad TRAP, applied deliberately.  The two ids are conjoined, so the
#     candidate freezes FALSE the day either one is promoted -- and, crucially,
#     check_armed_wiring.py would still call it WIRED, because a call site
#     exists.  The isolation case is the only thing standing between this shape
#     and a verdict that reads "tested, no effect".
echo
echo "=== M5: the two candidate ids are conjoined (the pullcad shape) ==="
sub "$HERO" "if J.IsModeTurbo() and J.IsSoakCandidate( 'zusaether' )" \
            "if J.IsModeTurbo() and J.IsSoakCandidate( 'zusaether' ) and J.IsSoakCandidate( 'aetherlens' )"
score "M5" "zusaether alone must use the shipped 250"

# ---------------------------------------------------------------------------
# M6: the gate stops asking whether the hero actually HOLDS a lens, by giving
#     the file-local a non-zero default.  Reach the hero never bought.
echo
echo "=== M6: aetherRange defaults non-zero (reach without the item) ==="
sub "$HERO" '	aetherRange = 0
	abilityASBonus = 0' '	aetherRange = 250
	abilityASBonus = 0'
score "M6" "without the item there is no bonus to add"

# ---------------------------------------------------------------------------
# M7: THE INSTRUMENT ITSELF.  The radius spy stops recording, so every lever
#     case reads an empty list.  If this survives, the file is green for a
#     reason unrelated to the subject and nothing above can be quoted.
echo
echo "=== M7: the radius spy goes blind (control on the instrument) ==="
sub "$TEST" 'J.GetNearbyHeroes = function(b, r, e, m) out[#out + 1] = r; return fNear(b, r, e, m) end' \
            'J.GetNearbyHeroes = function(b, r, e, m) return fNear(b, r, e, m) end'
score "M7" "unarmed must search the bare"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT / $TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
