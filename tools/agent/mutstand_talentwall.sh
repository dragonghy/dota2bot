#!/usr/bin/env bash
# Mutation stand for tests/test_focus_talent_reach_wall.lua -- the file that
# carries GH #366's thirteen-point wall from one dump onto the five focus heroes'
# own build rows, and that retires the "level reached therefore talent trained"
# sentence in four places (hero, 2026-09-13).
#
# Run it when any of: the spender's final else branch, a focus build row, a
# focus t15+ talent read, or one of the four retraction paragraphs is edited --
# and before quoting any reading out of that file.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkidleshare.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant;
#   * every `want` is the FIRST thing the mutant makes the suite say.
#
# ⛔ WHAT THIS STAND IS FOR, and it is the same unusual shape as the wkidleshare
# stand: this file changes NO behaviour.  Its assertions are source readings and
# prose ratchets, and a prose ratchet is exactly the kind of assertion that looks
# load-bearing and is decoration.  A surviving mutant here does not mean "the
# claim is redundant"; it means "this file cannot tell whether the claim is
# there", which for a ratchet is the whole of its job.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK (GH #507).

set -u
cd "$(dirname "$0")/../.."

SPENDER=bots/ability_item_usage_generic.lua
AXE=bots/BotLib/hero_axe.lua
ZUUS=bots/BotLib/hero_zuus.lua

FILES=("$SPENDER" "$AXE" "$ZUUS")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_talentwall.XXXXXX")
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
    lua5.1 tests/run_tests.lua focus_talent_reach_wall > "$WORK/run.log" 2>&1
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
# M1: the head stops parking.  If the spender pops an unspendable entry at any
#     level, the queue is no longer head-blocking and the thirteen-point prefix
#     is not a prefix -- every count in this file changes meaning.
echo
echo "=== M1: the final else pops at any level, not only above 25 ==="
sub "$SPENDER" "			if botLevel > 25 then" "			if botLevel > 0 then"
score "M1" "no longer guards its pop"

# ---------------------------------------------------------------------------
# M2: a SECOND pop appears in the same branch, outside the level guard.  The
#     level-25 line is still there, so a reader checking only for it sees
#     nothing; section 1 counts the pops instead.
echo
echo "=== M2: a second, unguarded pop is added to the same branch ==="
sub "$SPENDER" \
'			print("[WARN] Skipped to level up ability "..abilityName.." for "..botName.." for this time because it may fail.")' \
'			print("[WARN] Skipped to level up ability "..abilityName.." for "..botName.." for this time because it may fail.")
			table.remove( sAbilityLevelUpList, 1 )'
score "M2" "table.remove calls, not 1"

# ---------------------------------------------------------------------------
# M3: Axe's last two row entries are swapped.  The reachable prefix and its
#     multiset are UNCHANGED -- only which ability owns the unreachable entry 15
#     moves -- so this mutant is invisible to section 2 and is section 2b's job.
echo
echo "=== M3: Axe's entry 15 is no longer the ultimate ==="
sub "$AXE" "	{2,3,1,3,3,6,3,2,2,2,6,1,1,1,6},--pos3" \
           "	{2,3,1,3,3,6,3,2,2,2,6,1,1,6,1},--pos3"
score "M3" "row entry 15 is sAbilityList"

# ---------------------------------------------------------------------------
# M4: one reachable point moves between abilities.  Entry 15 is still the ult,
#     so 2b stays green; the {4,4,3,2} agreement with GH #366's ten heroes is
#     what breaks, which is the reading this file leans on hardest.
echo
echo "=== M4: Axe's 13th point is spent on a different ability ==="
sub "$AXE" "	{2,3,1,3,3,6,3,2,2,2,6,1,1,1,6},--pos3" \
           "	{2,3,1,3,3,6,3,2,2,2,6,1,2,1,6},--pos3"
score "M4" "not {4,4,3,2}"

# ---------------------------------------------------------------------------
# M5: a dead t25 handle is read without asking whether it is trained.  This is
#     the `zusboltcap` shape (GH #175) and it is the only assertion in the file
#     that guards a RUNTIME consequence rather than a record.
echo
echo "=== M5: Axe reads talent7's special value with no IsTrained() test ==="
sub "$AXE" "	if talent7:IsTrained() then nRadius = nRadius + talent7:GetSpecialValueInt( 'value' ) end" \
           "	nRadius = nRadius + talent7:GetSpecialValueInt( 'value' )"
score "M5" "is read on a line that does not test"

# ---------------------------------------------------------------------------
# M6: the retired sentence loses its quotation marks and stands as prose again.
#     The retraction paragraph around it is untouched, which is exactly the
#     shape that would pass a reader's eye.
echo
echo "=== M6: Axe's retired sentence is unquoted ==="
sub "$AXE" '--     CORRECTED 2026-09-13.  This bullet used to open "talent7 is LIVE from level
--     25" and end "it used to be protected by the branch being unreachable as' \
'--     CORRECTED 2026-09-13.  This bullet notes that talent7 is LIVE from level
--     25, and ends "it used to be protected by the branch being unreachable as'
score "M6" "OUTSIDE a quotation"

# ---------------------------------------------------------------------------
# M7: the `cullthresh` band declaration is softened from a structural claim to a
#     frequency one.  A wave sized on "rare" budgets for a band that cannot be
#     occupied at all.
echo
echo "=== M7: the third band becomes rare instead of empty ==="
sub "$AXE" "---   * THE THIRD BAND IS AN EMPTY STRATUM." \
           "---   * THE THIRD BAND IS RARELY OCCUPIED."
score "M7" "no longer declares that Culling Blade"

# ---------------------------------------------------------------------------
# M8: the double-count declaration is softened the same way.  Without it the
#     armed/shipped difference is no longer stated as unconditional, which is the
#     half of the domain declaration the hero-2 wave actually consumes.
echo
echo "=== M8: the talent8 term becomes unlikely instead of impossible ==="
sub "$AXE" '---   * THE `talent8` TERM CAN NEVER FIRE, so the double-count risk this header' \
           '---   * THE `talent8` TERM ALMOST NEVER FIRES, so the double-count risk this header'
score "M8" "no longer states that the double-count"

# ---------------------------------------------------------------------------
# M9: a control on the OTHER hero's retraction.  Zeus's paragraph is the second
#     of the four sites and nothing above touches it; if the ratchet only ever
#     watched hero_axe.lua this is where it would show.
echo
echo "=== M9: Zeus's retired sentence loses its retraction marker and quotes ==="
sub "$ZUUS" '	-- RE-CORRECTED 2026-09-13.  This paragraph used to continue "`talent5:IsTrained()`
	-- is TRUE from level 20 on and the guarded term below really runs [...] the fold' \
'	-- NOTE 2026-09-13.  This paragraph states that `talent5:IsTrained()`
	-- is TRUE from level 20 on and the guarded term below really runs; the fold'
score "M9" "OUTSIDE a quotation"

echo
echo "=== score: $CAUGHT / $TOTAL caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
