#!/usr/bin/env bash
# Mutation stand for the `fbnoally` lever (strategy desk 2026-09-10).
# Not part of any suite -- run by hand when the item_force_boots consider entry
# or tests/test_fbnoally_ally_center_origin.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while moving
# nothing, or moving the wrong thing:
#   * M3 is DEAD WIRING: gate, id and call site all present, and armed still
#     casts. check_armed_wiring.py would call it WIRED and a wave would read
#     back "tested, no effect".
#   * M4 is the WIDENING: the emptiness test stops being a test, so the refusal
#     fires on frames whose ally list HAS members. That is no longer a sentinel
#     repair, it is "never force-push a chase target", which is neither what was
#     argued nor what was measured.
#   * M5 keeps gate, id and emptiness test and only swaps the location for
#     another plausible-looking one. Substituting an anchor is the shape the
#     PREVIOUS round's lever (`tfnull`) took, so it is the one a reader of that
#     round would least suspect here -- and it is wrong here, because this
#     branch's premise (a group to push the target into) is absent, not merely
#     mislocated.
#   * M6 is the pullcad trap (AGENTS.md): conjoining an already-PROMOTED id
#     freezes the gate FALSE forever, because a promoted id appears in no armed
#     string. `fight` is a real promoted id.
#   * M7 and M8 do not touch bots/ at all -- they move readings this round
#     published. A stand that cannot go red on a moved reading is not a stand.
#   * M9 is the forbidden direction: deleting the SIBLING's guard would make
#     both entries agree, and the condition-(c) argument would evaporate while
#     every behavioural assertion stayed green.
#
# Usage: bash tools/agent/mutstand_fbnoally.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/ability_item_usage_generic.lua
TEST=tests/test_fbnoally_ally_center_origin.lua

FILES=("$SRC" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_fbnoally.XXXXXX")
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
    lua5.1 tests/run_tests.lua fbnoally > "$WORK/run.log" 2>&1
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
        grep -m1 -i 'fail\|assert' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the candidate check is dropped -- a defaults change wearing a gate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$SRC" "					and J.IsModeTurbo() and J.IsSoakCandidate('fbnoally')" \
           "					and J.IsModeTurbo()"
score "M1" "unarmed must keep the shipped cast"

# ---------------------------------------------------------------------------
# M2: turbo-only dropped, candidate check kept -- the narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "					and J.IsModeTurbo() and J.IsSoakCandidate('fbnoally')" \
           "					and J.IsSoakCandidate('fbnoally')"
score "M2" "the fix fired outside Turbo"

# ---------------------------------------------------------------------------
# M3: DEAD WIRING -- the refusal is computed and then not consulted.
echo
echo "=== M3: the refusal is computed but the branch ignores it ==="
sub "$SRC" "				if not bNoAllyRefuse" "				if not false"
score "M3" "armed, the refusal did not stop the cast"

# ---------------------------------------------------------------------------
# M4: WIDENING -- the emptiness test stops being a test.
echo
echo "=== M4: the refusal stops asking whether the ally list is empty ==="
sub "$SRC" "				local bNoAllyRefuse = #nInRangeAlly == 0" \
           "				local bNoAllyRefuse = #nInRangeAlly >= 0"
score "M4" "the guard leaked out of its own domain"

# ---------------------------------------------------------------------------
# M5: substitute an anchor instead of refusing -- the previous round's shape,
# applied where the premise itself is missing.
echo
echo "=== M5: the sentinel is replaced by the bot's own location ==="
sub "$SRC" "				local allyCenterLocation = J.GetCenterOfUnits(nInRangeAlly)" \
           "				local allyCenterLocation = bot:GetLocation()"
score "M5" "the defect this lever removes is not reachable on the pin any more"

# ---------------------------------------------------------------------------
# M6: the pullcad trap -- conjoin an id that is already PROMOTED.
echo
echo "=== M6: the gate is conjoined with a PROMOTED id (frozen FALSE) ==="
sub "$SRC" "					and J.IsModeTurbo() and J.IsSoakCandidate('fbnoally')" \
           "					and J.IsModeTurbo() and J.IsSoakCandidate('fbnoally') and J.IsSoakCandidate('fight')"
score "M6" "expected exactly one soak gate in the force_boots entry"

# ---------------------------------------------------------------------------
# M7: a published reading moves -- the consequence count.
echo
echo "=== M7: the joint consequence count is measured on a wider set ==="
sub "$TEST" "                            if #a >= nT and d >= 750 then bump('ally0_joint') end" \
            "                            if #a >= nT then bump('ally0_joint') end"
score "M7" "recorded 48"

# ---------------------------------------------------------------------------
# M8: the self-inclusion reading -- the fact the CONSTANT rests on.
echo
echo "=== M8: the self-inclusion reading is taken from the wrong helper ==="
sub "$TEST" "                        for _, m in pairs(J.GetAlliesNearLoc(h:GetLocation(), 600)) do" \
            "                        for _, m in pairs(J.GetNearbyHeroes(h, 600, false, BOT_MODE_NONE)) do"
score "M8" 'no longer means "me plus one"'

# ---------------------------------------------------------------------------
# M9: the forbidden direction -- delete the SIBLING's guard instead.
echo
echo "=== M9: the sibling entry's guard is deleted (both entries now agree) ==="
sub "$SRC" "	if J.IsGoingOnSomeone(bot) and #hAllyList >= 2" \
           "	if J.IsGoingOnSomeone(bot)"
score "M9" "the in-repo condition-(c) argument for this"

# ---------------------------------------------------------------------------
echo
echo "=== STAND: $CAUGHT of $TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED -- at least one mutant the tests cannot see"
exit 1
