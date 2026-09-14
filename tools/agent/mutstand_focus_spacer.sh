#!/usr/bin/env bash
# Mutation stand for section 5 of tests/test_focus_level_claims.lua -- the SPACER
# ARITHMETIC: every focus build row buys the ultimate's 2nd point as its 11th
# ability entry, the engine makes that rank legal at hero level 12, and the one
# thing that closes the gap is the t10 pick sitting at queue position 10
# (hero, 2026-09-14; iterations/streams/hero.md -168 derived this and explicitly
# did NOT assert it).  Run by hand when a focus build row, tTalentTreeList,
# J.Skill.GetSkillList, or section 5 of that test file is edited, and before
# quoting any of its readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_cmrspeed.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring
#     (hero_axe.lua carries its build row TWICE -- once as code and once inside
#     a comment that diagrams it -- so this is not hypothetical here);
#   * the baseline is proven GREEN before the first mutant;
#   * a `want` string NEVER contains a backtick.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR -- the ways the pinned arithmetic could go stale while
# the file stays green:
#   * M1 IS THE REASON THE STAND EXISTS.  Take the talent interleave out of
#     J.Skill.GetSkillList and every focus hero's 2nd ultimate point arrives at
#     level 11, one level before it is legal, where the head-blocking spender
#     parks it and the whole queue behind it.  This is the "tidy the talents to
#     the end of the row" edit, and nothing about either file's shape says it is
#     load-bearing.
#   * M2 is the one-character build-row edit: the ultimate moved one entry
#     earlier.  Same stall, reached from the row rather than from the dispatcher.
#   * M3 mutates the TEST'S OWN constant.  A requirement table nobody can drive
#     offline (GetHeroLevelRequiredToUpgrade is the engine's) is the half of this
#     section that can rot silently, so it is mutated deliberately.
#   * M4 removes the botLevel > 25 guard from the terminal else.  An illegal head
#     would then be SKIPPED rather than parked -- which would make the level-17
#     reading harmless and section 5's last case is the only thing that says so.
#   * M5 moves the 3rd ultimate point one entry earlier, so its shortfall against
#     level 18 becomes 2 rather than 1.
#   * M6 is a control ON THE STAND: point the section at the wrong sAbilityList
#     slot and every reading below becomes vacuous.  A census that cannot go red
#     is not a reading.
#
# ⛔ WHAT THIS STAND CANNOT KILL, said out loud:
#   * the third assertion in the rank-2 case (`nLevel - nIdx == 1`) is an
#     IDENTITY given the two before it (12 - 11 = 1).  No mutant kills it alone;
#     it is kept for its failure text, and the test file says so at the spot.
#   * the "nothing else is legal at 17" case cannot be violated by reordering a
#     15-entry row (entry 15 lands at 17 at the latest), so it is not mutated
#     here.  It restates a legality fact that
#     tests/test_focus_build_level_legality.lua grades directly.

set -u
cd "$(dirname "$0")/../.."

SKILL=bots/FunLib/aba_skill.lua
AXE=bots/BotLib/hero_axe.lua
SPEND=bots/ability_item_usage_generic.lua
TEST=tests/test_focus_level_claims.lua

FILES=("$SKILL" "$AXE" "$SPEND" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_focus_spacer.XXXXXX")
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

# ONE filter, and the reason is measured rather than assumed: the sibling that
# grades the same rows (tests/test_focus_build_level_legality.lua) is a DIFFERENT
# reading of the same source, so running it here would score this stand on its
# assertions instead of on section 5's.  It is run once at the end, unmutated,
# as a check that the restore really restored.
run_tests() {
    lua5.1 tests/run_tests.lua test_focus_level_claims.lua > "$WORK/run.log" 2>&1
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
        grep -m1 -i 'FAIL' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the talent interleave is pushed out of reach, so GetSkillList emits the
#     abilities first and the talents behind them -- the obvious tidy-up.  Every
#     focus hero's 2nd ultimate point then arrives at level 11.
echo
echo "=== M1: the talent interleave never fires (talents move behind the row) ==="
sub "$SKILL" "		if (i >= 10 and (i % 5 == 0 or ability_idx > #nAbilityBuildList)) then" \
             "		if (i >= 100 and (i % 5 == 0 or ability_idx > #nAbilityBuildList)) then"
score "M1" "reaches ultimate rank 2 at level 11, and it is legal at 12"

# ---------------------------------------------------------------------------
# M2: the build row buys the 2nd ultimate point one entry earlier.  One
#     character of diff; same stall as M1, reached from the row.
echo
echo "=== M2: axe's row moves ultimate rank 2 to ability entry #10 ==="
sub "$AXE" "	{2,3,1,3,3,6,3,2,2,2,6,1,1,1,6},--pos3" \
           "	{2,3,1,3,3,6,3,2,2,6,2,1,1,1,6},--pos3"
score "M2" "as ability entry #10, not #11"

# ---------------------------------------------------------------------------
# M3: the TEST'S OWN requirement constant drifts.  This is the half of the
#     section nothing offline can drive, so a wrong constant would otherwise
#     read as a measurement.
echo
echo "=== M3: the ultimate requirement table is retuned to 6/11/18 ==="
sub "$TEST" "local ULT_REQ = { 6, 12, 18 }" "local ULT_REQ = { 6, 11, 18 }"
score "M3" "reaches ultimate rank 2 at level 12, and it is legal at 11"

# ---------------------------------------------------------------------------
# M4: the terminal else pops at any level.  An illegal head is then SKIPPED
#     rather than parked, and the whole level-17 reading changes meaning.
echo
echo "=== M4: the terminal else loses its botLevel > 25 pop guard ==="
sub "$SPEND" "			if botLevel > 25 then" "			if botLevel > 0 then"
score "M4" "head is now SKIPPED rather than parked"

# ---------------------------------------------------------------------------
# M5: the 3rd ultimate point moves one entry earlier, so the shortfall against
#     level 18 becomes 2 -- a bigger park than the one that was priced.
echo
echo "=== M5: axe's row moves ultimate rank 3 to ability entry #14 ==="
sub "$AXE" "	{2,3,1,3,3,6,3,2,2,2,6,1,1,1,6},--pos3" \
           "	{2,3,1,3,3,6,3,2,2,2,6,1,1,6,1},--pos3"
score "M5" "reaches ultimate rank 3 at level 16"

# ---------------------------------------------------------------------------
# M6: CONTROL ON THE STAND.  Section 5 reads the wrong sAbilityList slot; every
#     entry index goes nil and every level below is about some other ability.
echo
echo "=== M6 (control): section 5 reads sAbilityList[5] instead of [6] ==="
sub "$TEST" "local ULT_SLOT = 6" "local ULT_SLOT = 5"
score "M6" "as ability entry #nil, not #6"

# ---------------------------------------------------------------------------
echo
echo "=== restore check: the sibling grader on a restored tree ==="
lua5.1 tests/run_tests.lua test_focus_build_level_legality.lua > "$WORK/sib.log" 2>&1
SIB=$?
tail -2 "$WORK/sib.log"
if [ "$SIB" -ne 0 ]; then
    echo "SIBLING RED (exit $SIB) after restore -- the tree may still hold a mutant"
fi

echo
echo "SCORE: $CAUGHT/$TOTAL caught"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
