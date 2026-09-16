#!/usr/bin/env bash
# Mutation stand for tests/test_focus_strand_identity.lua -- the hero desk's
# derivation of WHICH ability the skill-point wall strands, and its claim that
# the derivation matches GH #822's wave measurement 8 for 8.
#
# ⚠️ NO GATED ID SHIPS THIS ROUND, so this is not a "does the gate work" stand.
# What it prices is whether the file CAN STILL FAIL.  The headline is an
# AGREEMENT between a source derivation and a table of measured names, and an
# agreement is the single easiest thing to fake: a reader that returns the same
# slot for everybody, a name lookup that answers nil for everybody, a comparison
# that matches on a substring, a loop that never runs.  Groups:
#   A  the BUILD ROWS the derivation reads        (M1-M4)
#   B  the SHIPPED slot algorithm it is about     (M5-M6)
#   C  THE INSTRUMENT: reader, mock, slot map     (M7-M10)
#   D  the PREMISES the file says it rests on     (M11-M13)
#
# Usage:  bash tools/agent/mutstand_strandid.sh
# Exit 0 iff every mutant is KILLED.  Reads and restores from a file copy (never
# from git), per .claude/skills/evidence-discipline.
#
# ⛔ EVERY FILE A MUTANT TOUCHES IS IN THE BACKUP LIST -- not "the files the
# stand is about" (the mutstand_cmkillscan.sh lesson, 2026-09-16: a leaked
# mutation does not merely dirty the tree, it MANUFACTURES kills for every
# mutant that runs after it).  This stand mutates four hero files, the shipped
# aba_skill.lua, two mock files, the shared reader and one other test; all nine
# are backed up and every restore is verified.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

TEST=tests/test_focus_strand_identity.lua
CM=bots/BotLib/hero_crystal_maiden.lua
WK=bots/BotLib/hero_skeleton_king.lua
VS=bots/BotLib/hero_vengefulspirit.lua
DP=bots/BotLib/hero_death_prophet.lua
ABA=bots/FunLib/aba_skill.lua
SLOTS=tests/mock/hero_slots.lua
API=tests/mock/bot_api.lua
MAP=tests/skill_level_map.lua
WALL=tests/test_skill_point_stall_frame.lua

TMP="$(mktemp -d)"
cp "$TEST" "$TMP/test.bak"
cp "$CM"    "$TMP/cm.bak"
cp "$WK"    "$TMP/wk.bak"
cp "$VS"    "$TMP/vs.bak"
cp "$DP"    "$TMP/dp.bak"
cp "$ABA"   "$TMP/aba.bak"
cp "$SLOTS" "$TMP/slots.bak"
cp "$API"   "$TMP/api.bak"
cp "$MAP"   "$TMP/map.bak"
cp "$WALL"  "$TMP/wall.bak"

PAIRS="$TEST:test.bak $CM:cm.bak $WK:wk.bak $VS:vs.bak $DP:dp.bak \
$ABA:aba.bak $SLOTS:slots.bak $API:api.bak $MAP:map.bak $WALL:wall.bak"

restore() {
    local pair f b
    for pair in $PAIRS; do
        f="${pair%%:*}"; b="$TMP/${pair##*:}"
        cp "$b" "$f"
    done
}

# ⛔ RESTORING IS NOT THE SAME AS HAVING RESTORED.  Checked after every restore
# rather than once at the end, so a leak is caught on the mutant that caused it
# instead of five mutants later (tests/test_mutstand_restore_trap.py).
verify_restore() {
    local bad=0 f b pair
    for pair in $PAIRS; do
        f="${pair%%:*}"; b="$TMP/${pair##*:}"
        if [ "$(sha256sum < "$f")" != "$(sha256sum < "$b")" ]; then
            echo "  RESTORE LEAK: $f does not match its pristine copy"
            bad=1
        fi
    done
    return $bad
}
trap 'restore; rm -rf "$TMP"' EXIT

KILLED=0
SURVIVED=0
ABORTED=0

run_suite() {
    timeout 300 lua5.1 tests/run_tests.lua "$(basename "$TEST")" >"$TMP/out" 2>&1
    return $?
}

mutant() {
    local label="$1"; shift
    restore
    if ! verify_restore; then
        echo "  ABORT   $label -- the tree was not pristine going in"
        ABORTED=$((ABORTED + 1))
        return
    fi
    if ! eval "$@"; then
        echo "  ABORT   $label -- the mutation did not apply (GH #846: an"
        echo "          unapplied mutant scores for free)"
        ABORTED=$((ABORTED + 1))
        return
    fi
    if run_suite; then
        echo "  SURVIVED $label"
        SURVIVED=$((SURVIVED + 1))
    else
        echo "  killed   $label"
        KILLED=$((KILLED + 1))
    fi
}

sub() {
    local file="$1" from="$2" to="$3"
    # `--` is load-bearing: a replacement starting with `-` is otherwise read as
    # an option, and the stand reports ABORT for a quoting reason -- which is not
    # a survival, but is also not a kill (mutstand_lionraoequorum.sh M11).
    grep -qF -- "$from" "$file" || return 1
    python3 - "$file" "$from" "$to" <<'PY' || return 1
import sys
path, frm, to = sys.argv[1], sys.argv[2], sys.argv[3]
body = open(path, encoding='utf-8').read()
if frm not in body:
    sys.exit(1)
open(path, 'w', encoding='utf-8').write(body.replace(frm, to, 1))
PY
    grep -qF -- "$to" "$file" || return 1
}

echo "=== baseline (unmutated) ==="
restore
if ! run_suite; then
    echo "BASELINE IS RED -- nothing below means anything."
    tail -20 "$TMP/out"
    exit 2
fi
echo "  baseline green"

echo
echo "=== group A: the build rows the derivation reads ==="

# M1  ⭐ THE HEADLINE MUTANT.  Move CM's three late points onto a different
#     ability and the derived strand must move off brilliance_aura -- i.e. §3
#     must stop agreeing with GH #822's measured column.  If this survives, the
#     8/8 is not reading the rows at all.
mutant "M1  CM row: late points 3,3,3 -> 1,1,1" \
    "sub '$CM' '{1,2,3,2,2,6,2,1,1,1,6,3,3,3,6}' '{1,2,3,2,2,6,2,3,3,3,6,1,1,1,6}'"

# M2  the same attack on WK, which §3 AND §4b both read.  Two sections must go
#     red together; one alone would mean the other is not looking at the row.
mutant "M2  WK row: swap which basic ends at rank 3" \
    "sub '$WK' '{2,1,2,3,2,6,2,3,3,3,6,1,1,1,6}' '{2,1,2,3,2,6,2,1,1,1,6,3,3,3,6}'"

# M3  vengeful_spirit -- the hero GH #822 gave its frame-by-frame ledger for
#     (command_aura stuck at rank 3 for 828 s).  The derivation names that
#     ability; moving the row must break the naming.
mutant "M3  VS row: move the late points off command_aura" \
    "sub '$VS' '{2,1,1,2,1,6,1,2,2,3,6,3,3,3,6}' '{2,3,3,2,3,6,3,2,2,1,6,1,1,1,6}'"

# M4  ⭐ the WELL-POSEDNESS premise (§4).  Make death_prophet's two rows strand
#     DIFFERENT abilities.  The 8/8 compares one prediction against a
#     measurement that could not see which row a body rolled; if the rows can
#     disagree and nothing says so, the comparison is not like-for-like.
mutant "M4  DP row 2 strands a different ability than row 1" \
    "sub '$DP' '{1,3,3,1,3,6,3,2,1,1,6,2,2,2,6}' '{2,3,3,2,3,6,3,1,2,2,6,1,1,1,6}'"

echo
echo "=== group B: the shipped slot algorithm this is all about ==="

# M5  the interleave itself.  Entry 16 is entry 16 only because talents land at
#     10 and 15; re-tune the modulus and both stranded entries move.  This is the
#     shipped line, in a file all 127 heroes run.
mutant "M5  aba_skill talent interleave i%5 -> i%4" \
    "sub '$ABA' 'i % 5 == 0 or ability_idx' 'i % 4 == 0 or ability_idx'"

# M6  the slot budget.  Drop the talent term and the list ends at 15, so entries
#     16/17 stop existing -- §5b's "no row escapes the strand" is the line that
#     must notice, and it is the one most likely to pass an empty sweep.
mutant "M6  aba_skill totalSlots loses its talent term" \
    "sub '$ABA' 'local totalSlots = #nAbilityBuildList + #nTalentBuildList' 'local totalSlots = #nAbilityBuildList'"

echo
echo "=== group C: the instrument -- reader, mock, slot map ==="

# M7  the reader's spend window.  §5 prices "thirteen points at the wall"; widen
#     the window and that count, and the rank-3 identification built on it, are
#     both off in a direction nobody reading the output would see.
#
# ⚠️ FIRST VERSION WAS `nLevel + 1` AND IT SURVIVED -- and the survivor was the
# stand being right, not the file being weak (evidence-discipline rule 2 says
# suspect the assertion; here the assertion is innocent and the MUTANT had no
# content).  Entry 15 is the t15 TALENT, and the mock's GetTalentList answers
# nils, so `sSkillList[15]` is nil, `slot_of[nil]` is nil, and ranks_at's own
# `if nSlot ~= nil` skips it.  Counting to 15 instead of 14 is therefore a
# provable no-op ON THIS CORPUS, not a defect that slipped through.
# ⭐ Worth keeping because it is a fact the stand BOUGHT: the "thirteen points"
# reading does not depend on where you put the boundary between entry 14 and
# entry 15 -- the wall entry contributes nothing either way.  `+2` reaches entry
# 16, which is an ability, and that is the first widening with any content.
mutant "M7  skill_level_map.ranks_at reaches past the wall to entry 16" \
    "sub '$MAP' 'for i = 1, nLevel do' 'for i = 1, nLevel + 2 do'"

# M8  the rank ladder, which is how strand_of recovers WHICH index entry 16
#     belongs to.  Off-by-one here silently breaks the index -> rank link while
#     leaving the slot -> name link intact, so a file that only checked names
#     would still pass.
mutant "M8  skill_level_map.rank_ladder records level+1" \
    "sub '$MAP' 'tLadder[nSlot][tSeen[nSlot]] = nLevel' 'tLadder[nSlot][tSeen[nSlot]] = nLevel + 1'"

# M9  ⭐ the mock's slot naming -- the ONLY thread connecting a driven entry back
#     to an engine slot.  Cut it and every index -> name step in the file is
#     guessing; the file must raise rather than quietly answer nil.
mutant "M9  mock stops encoding the slot in the ability name" \
    "sub '$API' \"'_mock_slot_' .. tostring(slot)\" \"'_ability_' .. tostring(slot)\""

# M10 the slot map's own content.  §3 reads CM's engine slot 2 for the name it
#     compares; repoint it and the agreement must break.  This prices the
#     comparison rather than the derivation: a §3 that matched on a substring, or
#     on nil == nil, would survive.
mutant "M10 hero_slots: CM slot 2 renamed" \
    "sub '$SLOTS' \"[2]='crystal_maiden_brilliance_aura'\" \"[2]='crystal_maiden_not_the_aura'\""

echo
echo "=== group D: the premises the file says it rests on ==="

# M11 §2's convention check.  Put a placeholder in a basic slot: the index ->
#     name step is unsound for that hero and §2 is the only thing that says so.
#     ⚠️ Axe is chosen because he is in FOCUS but NOT in MEASURED, so a §3 that
#     happened to cover him cannot take the credit for this kill.
mutant "M11 hero_slots: axe slot 1 becomes a placeholder" \
    "sub '$SLOTS' \"[1]='axe_battle_hunger'\" \"[1]='generic_hidden'\""

# M12 §1's dependency anchor.  This file is ABOUT the two entries behind a wall
#     it does not itself establish; if that reading is retired, the ratchets
#     below become measurements of an entry every hero reaches.
mutant "M12 the wall reading loses its 'entry 15 is a wall' sentence" \
    "sub '$WALL' 'So entry 15 is a wall' 'So entry 15 is reached normally'"

# M13 ⭐ the comparison's OTHER half -- the measured column itself.  Mutating the
#     file's own DATA (not its assertions) is a fair question: it asks whether §3
#     compares two things or merely reports one.  ⚠️ Mutating an ASSERTION would
#     not be: a suite cannot kill its own assertion (the mutstand_cmkillscan.sh
#     M7 lesson), which is why no mutant here touches one.
mutant "M13 the quoted GH #822 column is altered for one hero" \
    "sub '$TEST' \"gap = 'shackles'\" \"gap = 'ether_shock'\""

restore
verify_restore || echo "  (final restore leaked -- inspect before trusting anything above)"

echo
echo "=== totals ==="
echo "  killed   $KILLED"
echo "  SURVIVED $SURVIVED"
echo "  ABORTED  $ABORTED"

if [ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]; then
    echo "ALL MUTANTS KILLED"
    exit 0
fi
echo "STAND INCOMPLETE -- a survivor or an abort means the reading is not priced."
exit 1
