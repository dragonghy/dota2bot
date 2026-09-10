#!/usr/bin/env bash
# Mutation stand for the `tombhp` lever (strategy desk 2026-09-10).
# Not part of any suite -- run by hand when the tombstone branch of
# bots/mode_roam_generic.lua or tests/test_tombhp_list_to_unit_ruler.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while leaving
# the defect, or removing more than was argued:
#   * M3 + M10 are the pair THIS lever needs and no other lever's stand has.
#     The stand was built on the claim "the crash removal is the ORDERING: move
#     the gate one line down and the unarmed leg raises again". M3 said NO --
#     it went red for a different reason -- and the mutant was right: with the
#     index repaired, the unarmed leg reads a perfectly good element. The crash
#     removal is the INDEX. M10 (gate moved AND index reverted) is the mutant
#     that makes the unarmed leg raise, and it is what the ordering pin in
#     section 5 is actually worth: insurance against a half-revert. The header
#     of the test file carries the same correction, because a reader who trusts
#     the first claim would gate the wrong thing next time.
#   * M4 is the plain revert: the list goes back where the element is.
#   * M5 substitutes a DIFFERENT element. "Nearest" is the whole content of the
#     repair (the sibling branch at :1789 reads [1] too); [2] keeps every
#     structural shape and changes what is measured.
#   * M6 is the pullcad trap (AGENTS.md): conjoining an already-PROMOTED id
#     freezes the gate FALSE forever, because a promoted id is in no armed
#     string. `fight` is a real promoted id.
#   * M9 is the FORBIDDEN DIRECTION: "harmonising" the sibling branch onto the
#     broken reading instead of the reverse. Every behavioural assertion about
#     the tombstone branch stays green while the in-repo condition-(c) argument
#     is destroyed.
#   * M7 and M8 do not touch bots/ at all -- they move readings this round
#     published. A stand that cannot go red on a moved reading is not a stand.
#
# Usage: bash tools/agent/mutstand_tombhp.sh
set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_roam_generic.lua
TEST=tests/test_tombhp_list_to_unit_ruler.lua

FILES=("$SRC" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tombhp.XXXXXX")
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
    lua5.1 tests/run_tests.lua tombhp > "$WORK/run.log" 2>&1
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

GATE=$'\t\t\t\tand J.IsModeTurbo() and J.IsSoakCandidate(\'tombhp\')'
HPTERM=$'\t\t\t\tand J.GetHP(nInRangeEnemy[1]) > 0.35 then'

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
sub "$SRC" "$GATE" $'\t\t\t\tand J.IsModeTurbo()'
score "M1" "and it answers false"

# ---------------------------------------------------------------------------
# M2: turbo-only dropped, candidate check kept -- the narrower half of M1.
echo
echo "=== M2: turbo-only dropped, candidate check kept ==="
sub "$SRC" "$GATE" $'\t\t\t\tand J.IsSoakCandidate(\'tombhp\')'
score "M2" "the gate is not turbo-only"

# ---------------------------------------------------------------------------
# M3: THE ORDERING. Gate and repair both present, one line apart.
# ⚠️ This stand's first draft claimed M3 would bring the raise back and scored it
# WRONG-MESSAGE for saying otherwise -- the mutant was right and the claim was
# wrong: with the index repaired, the unarmed leg evaluates a perfectly good
# element read. The ordering is a SECOND layer, and M10 below is the mutant that
# shows it is worth anything at all.
echo
echo "=== M3: the gate is moved BELOW the J.GetHP term (short-circuit lost) ==="
sub "$SRC" "$GATE"$'\n'"$HPTERM" \
           $'\t\t\t\tand J.GetHP(nInRangeEnemy[1]) > 0.35\n\t\t\t\tand J.IsModeTurbo() and J.IsSoakCandidate(\'tombhp\') then'
score "M3" "the gate no longer sits BEFORE the J.GetHP term"

# ---------------------------------------------------------------------------
# M4: the plain revert -- the list goes back where the element belongs.
echo
echo "=== M4: J.GetHP is handed the whole list again ==="
sub "$SRC" "$HPTERM" $'\t\t\t\tand J.GetHP(nInRangeEnemy) > 0.35 then'
score "M4" "still hands the whole list to J.GetHP"

# ---------------------------------------------------------------------------
# M5: a DIFFERENT element -- every structure intact, the reading changed.
echo
echo "=== M5: the branch reads the second enemy instead of the nearest ==="
sub "$SRC" "$HPTERM" $'\t\t\t\tand J.GetHP(nInRangeEnemy[2]) > 0.35 then'
score "M5" "the armed leg completes without raising"

# ---------------------------------------------------------------------------
# M6: the pullcad trap -- conjoin an id that is already PROMOTED.
echo
echo "=== M6: the gate is conjoined with a PROMOTED id (frozen FALSE) ==="
sub "$SRC" "$GATE" "$GATE and J.IsSoakCandidate('fight')"
score "M6" "soak gates, expected 1"

# ---------------------------------------------------------------------------
# M7: a published reading moves -- the conjunct's own domain.
echo
echo "=== M7: the domain is taken over lists of two or more ==="
sub "$TEST" "                    if type(eList) == 'table' and #eList > 0 then" \
            "                    if type(eList) == 'table' and #eList > 1 then"
score "M7" "non-empty enemy-hero list in 1200 FELL"

# ---------------------------------------------------------------------------
# M8: the drive's own precondition moves -- 299 was measured, not chosen.
echo
echo "=== M8: the drive corpus is narrowed to hp < 0.4 ==="
sub "$TEST" "                        if J.GetHP(h) < 0.8" "                        if J.GetHP(h) < 0.4"
score "M8" "frames satisfying the branch preconditions FELL"

# ---------------------------------------------------------------------------
# M9: the forbidden direction -- harmonise the SIBLING onto the broken reading.
echo
echo "=== M9: the sibling branch at :1789 is 'harmonised' onto the list read ==="
sub "$SRC" "		and J.IsInRange(bot, nInRangeEnemy[1], math.max(bot:GetAttackRange(), nInRangeEnemy[1]:GetAttackRange()) - 250) then" \
           "		and J.GetHP(nInRangeEnemy) > 0.35 then"
score "M9" "still hands the whole list to J.GetHP"

# ---------------------------------------------------------------------------
# M10: BOTH halves of the ordering claim -- gate below the term AND the term
# un-indexed.  This is the only mutant that makes the UNARMED leg raise, and it
# is the reason section 5 pins the order at all: with the gate first, a future
# half-revert of the index still cannot raise off-candidate.
echo
echo "=== M10: gate below the term AND the list handed over (unarmed raises) ==="
sub "$SRC" "$GATE"$'\n'"$HPTERM" \
           $'\t\t\t\tand J.GetHP(nInRangeEnemy) > 0.35\n\t\t\t\tand J.IsModeTurbo() and J.IsSoakCandidate(\'tombhp\') then'
score "M10" "the unarmed leg completes without raising"

# ---------------------------------------------------------------------------
echo
echo "=== STAND: $CAUGHT of $TOTAL caught ==="
if [ "$CAUGHT" -eq "$TOTAL" ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED -- at least one mutant the tests cannot see"
exit 1
