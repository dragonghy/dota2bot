#!/usr/bin/env bash
# Mutation stand for tests/test_weakhp_seed_family.lua -- the hero desk's census
# of the weakest-enemy-health seed FAMILY, and its finding that the committed
# rung-1 ratchet trips before the decision does.
#
# ⚠️ NO GATED ID SHIPS THIS ROUND, so this is not a "does the gate work" stand.
# What it prices is whether the file CAN STILL FAIL.  Almost every reading in it
# is a UNIVERSAL over a sweep ("all eleven sites", "all three controls") or a
# NEGATIVE over a corpus ("zero rows at or above the seed"), and both are
# satisfied for free by an instrument that finds nothing: a site reader that
# resolves no seeds, an occurrence counter that counts comments, a corpus walk
# that opens no files, a team grouping that puts every hero in its own group.
# Groups:
#   A  the SUBJECT: the family's own sites in shipped Lua        (M1-M4)
#   B  the CONTROL: the escaping sibling §5 rests on             (M5-M6)
#   C  the INSTRUMENT: seed reader, occurrence counter, walk,    (M7-M11)
#      the team grouping that makes rungs 2 and 3 mean anything
#   D  the PREMISES the finding rests on, incl. the sibling      (M12-M15)
#      file's trip point and its corrected text
#
# Usage:  bash tools/agent/mutstand_weakhpseed.sh
# Exit 0 iff every mutant is KILLED.  Reads and restores from a file copy (never
# from git), per .claude/skills/evidence-discipline.
#
# ⛔ EVERY FILE A MUTANT TOUCHES IS IN THE BACKUP LIST -- not "the files the
# stand is about" (the mutstand_cmkillscan.sh lesson, 2026-09-16: a leaked
# mutation does not merely dirty the tree, it MANUFACTURES kills for every
# mutant that runs after it).  This stand mutates two hero files, one shared
# scanner, one corpus fixture, the sibling test and the test itself; all six are
# backed up and every restore is verified.
#
# ⛔ tests/lua_source_scan.lua IS IN THAT LIST AND IT MATTERS MORE THAN THE
# OTHERS: it is the SHARED scanner (GH #346 -- it moved rather than being
# copied), so a leak there reddens source-shape tests belonging to other desks.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

TEST=tests/test_weakhp_seed_family.lua
SIB=tests/test_cm_weakest_sentinel_domain.lua
AXE=bots/BotLib/hero_axe.lua
LION=bots/BotLib/hero_lion.lua
# ⛔ THE CM PICKER IS IN THIS LIST BECAUSE M5 MUTATES IT, and the first run of
# this stand is the reason the line above the backup block is written the way it
# is.  M5 was authored against `bots/BotLib/hero_crystal_maiden.lua` while the
# list held only the two charter hero files, so its mutation LEAKED: the file
# stayed at `return nWeakestUnit` for the rest of the run, §5 was red from M5
# onward, and M6-M15 all scored "killed" for free.  The run reported 13 killed /
# 1 survived and every one of those thirteen was manufactured.
# ⭐ AND THE DIAGNOSTIC PATH IS THE PART WORTH KEEPING: the leak did not present
# as a leak.  It presented as M8 SURVIVING -- i.e. as "this file does not depend
# on the shared comment scanner after all", a plausible and completely wrong
# conclusion about tests/lua_source_scan.lua.  The leak was only found by
# printing the sweep's hits and noticing the `return` line had gone missing from
# a file nobody had meant to touch.  A survivor is a question about the stand
# before it is an answer about the file.
CM=bots/BotLib/hero_crystal_maiden.lua
SCAN=tests/lua_source_scan.lua
FIX=tests/frames/f_260828_124358_axe_cull_promise.lua

TMP="$(mktemp -d)"
cp "$TEST" "$TMP/test.bak"
cp "$SIB"  "$TMP/sib.bak"
cp "$AXE"  "$TMP/axe.bak"
cp "$LION" "$TMP/lion.bak"
cp "$CM"   "$TMP/cm.bak"
cp "$SCAN" "$TMP/scan.bak"
cp "$FIX"  "$TMP/fix.bak"

PAIRS="$TEST:test.bak $SIB:sib.bak $AXE:axe.bak $LION:lion.bak $CM:cm.bak $SCAN:scan.bak $FIX:fix.bak"

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
echo "=== group A: the subject -- the family's own sites in shipped Lua ==="

# M1  ⭐ THE HEADLINE MUTANT.  Give one site's dead local a single reader, in the
#     same file, and that site's sentinel ESCAPES -- which is the day the seed
#     stops being only a cap and the `cmrangedhp` defect shape applies to it.
#     A §1 that survives this is not measuring consumption at all, it is
#     restating a grep count.
mutant "M1  lion: one live read of the dead local (the sentinel escapes)" \
    "sub '$LION' \
'		if npcWeakestEnemy ~= nil' \
'		local nLeak = npcWeakestEnemyHealth
		if npcWeakestEnemy ~= nil'"

# M2  The other charter site, so the universality is over both and not just the
#     first one the sweep happens to reach.
mutant "M2  axe: one live read of the dead local (the sentinel escapes)" \
    "sub '$AXE' \
'		if npcWeakestEnemy ~= nil' \
'		local nLeak = npcWeakestEnemyHealth
		if npcWeakestEnemy ~= nil'"

# M3  Strict `<` is what makes the seed a CAP rather than an initial value.  §1
#     asserts the comparison for exactly that reason; if this survives, the file
#     has not established that the idiom is the one it describes.
mutant "M3  lion: '<' -> '<=' (the seed stops being a strict cap)" \
    "sub '$LION' 'if ( npcEnemyHealth < npcWeakestEnemyHealth )' \
'if ( npcEnemyHealth <= npcWeakestEnemyHealth )'"

# M4  ⭐ THE SEED, on the tight site.  §2's whole content is that every seed
#     clears the corpus by a margin; drop the tightest one to inside 3x of rung
#     2 (2585 * 3 = 7755) and §2 must say so.  A survivor means §2 is pricing
#     the seeds against each other rather than against the corpus.
mutant "M4  lion: seed 10000 -> 5000 (inside 3x of rung 2)" \
    "sub '$LION' 'local npcWeakestEnemyHealth = 10000' \
'local npcWeakestEnemyHealth = 5000'"

echo
echo "=== group B: the control -- the escaping sibling that makes §1 non-vacuous ==="

# M5  ⭐ Take the `return` off the control and the two shapes collapse to the
#     same occurrence count.  §5 exists precisely so that "eleven dead locals"
#     is a statement about the FILES; if it survives this, it is a statement
#     about the reader (last round's M12 shape, bought the hard way).
mutant "M5  CM picker: stop returning the sentinel (control stops escaping)" \
    "sub '$CM' \
'	return nWeakestUnit, nWeakestUnitLowestHealth' \
'	return nWeakestUnit'"

# M6  A DEGRADED control sweep, with the floor left standing -- because the
#     floor is what has to catch it.
#     ⚠️ TWO EARLIER VERSIONS OF THIS MUTANT SURVIVED and both failures are the
#     same mistake, recorded so it is not made a third time.  v1 dropped the
#     floor 2 -> 0 and nothing else: with the sweep still finding its three
#     sites, lowering a floor below a value that is already above it changes
#     nothing.  v2 then ALSO broke the sweep -- and that is worse, because a
#     test cannot detect the removal of its own assertion; the mutant deleted
#     the guard and the evidence together.  ⇒ A guard is priced by breaking what
#     it guards and LEAVING THE GUARD IN PLACE.
mutant "M6  §5: point the control sweep at a name no file has (floor must catch it)" \
    "sub '$TEST' \"local LIVE_NAME = 'nWeakestUnitLowestHealth'\" \
\"local LIVE_NAME = 'nNoSuchSentinelName'\""

echo
echo "=== group C: the instrument -- seed reader, counter, walk, grouping ==="

# M7  The occurrence counter is the whole discriminator between the two shapes
#     (3 vs 4), so an undercount must redden.  Skip the seed line and every
#     count drops by one: 3 -> 2 and 4 -> 3, which also collapses the two shapes
#     onto each other.
#     ⚠️ THE FIRST VERSION OF THIS MUTANT SURVIVED and the reason is recorded
#     rather than papered over: it broke only the MULTI-HIT branch (count one
#     occurrence per line instead of all of them), and no line at any of the
#     fourteen sites holds the name twice.  That branch is therefore DEFENSIVE
#     AND UNPRICED BY THIS CORPUS -- a real limit of this stand, not a kill it
#     can claim.  What is priced is that the count itself is load-bearing.
mutant "M7  §1 counter: skip the seed line, so every count is one short" \
    "sub '$TEST' '                    nOccurrences = nOccurrences + 1' \
'                    if sLine:find(\"local\", 1, true) == nil then
                    nOccurrences = nOccurrences + 1
                    end'"

# M8  ⛔ THE COMMENT CUT.  The counts 3 and 4 are over COMMENT-STRIPPED source;
#     the CM control has a fifth appearance of its name inside a comment, so a
#     reader that stops stripping reports 5 there.  This prices the dependency
#     on the shared scanner (GH #346) rather than assuming it.
mutant "M8  scanner: strip_line_comment becomes identity (comments counted)" \
    "sub '$SCAN' 'function M.strip_line_comment(line)' \
'function M.strip_line_comment(line)
    if true then return line end'"

# M9  The corpus walk.  A walk that opens nothing makes every negative in §3
#     true for free -- and §3 carries the empty-set claim the DO-NOT-ARM verdict
#     is argued from.
mutant "M9  §3 walk: find pattern 'f_*.lua' -> 'zz_*.lua' (empty corpus)" \
    "sub '$TEST' \"name 'f_*.lua'\" \"name 'zz_*.lua'\""

# M10 ⭐ THE GROUPING, which is what rungs 2 and 3 are made of.  Group by unit
#     instead of by team and every group has size 1, so the rung-2 maximum
#     becomes the global hp ceiling and the rung-3 floor collapses.  Nothing
#     else in this stand asks whether the grouping is real.
mutant "M10 §3 grouping: group by unit name instead of by team" \
    "sub '$TEST' \"local sTeam = tostring(tUnit.team)\" \
\"local sTeam = tostring(tUnit.team) .. tUnit.name\""

# M11 The liveness filter (GH #794).  A dead row carries hp 0, so admitting the
#     dead drags every group minimum to zero -- which would make rung 2 look
#     arbitrarily safe.  A §3 that survives this is reading a rung 2 that any
#     corpse can satisfy.
mutant "M11 §3: admit dead rows into the groups (corpses pin every minimum)" \
    "sub '$TEST' 'if tUnit.alive ~= false then' 'if true then'"

echo
echo "=== group D: the premises the finding rests on ==="

# M12 ⭐⭐ THE FINDING ITSELF, as it would be answered the one way it must not be:
#     move the sibling file's trip point instead of its text.  §4(a) exists for
#     this exact mutant and nothing else in the suite would notice.
mutant "M12 sibling: loosen the rung-1 margin clause (answer the finding by moving the bound)" \
    "sub '$SIB' 'assert(nMaxMaxHp * 2 < SENTINEL,' 'assert(nMaxMaxHp * 1 < SENTINEL,'"

# M13 The corrected TEXT, reverted.  §4(b) is the half that keeps a future
#     rung-1 red from misinstructing whoever reads it.
mutant "M13 sibling: drop the ladder from the corrected failure text" \
    "sub '$SIB' 'read rungs 2 and 3 in ' 'read the corpus in '"

# M14 ⭐ THE ORDERING, which IS the finding: rung 1 nearer its trip point than
#     rung 2 is to mattering.  §4(c) asserts nTrip1 < nTrip2, so the mutant has
#     to flip it.  nTrip1 = (SENTINEL/2)/max_max_hp RISES as the ceiling falls,
#     so capping the ceiling read at 1200 gives nTrip1 = 5000/1200 = 4.17
#     against nTrip2 = 10000/2585 = 3.87 -- flipped.  A §4(c) that survives this
#     is printing the two distances rather than comparing them.
#     ⚠️ The pattern is the WHOLE guarded line: the first version anchored on
#     `if tUnit.max_hp > r.max_max_hp then`, which is not what the file says
#     (the type check is part of the same condition), so the stand ABORTED --
#     not a survival, but not a kill either (GH #846).
mutant "M14 §4(c): cap the ceiling read at 1200 so the ordering flips" \
    "sub '$TEST' \
\"if type(tUnit.max_hp) == 'number' and tUnit.max_hp > r.max_max_hp then\" \
\"if type(tUnit.max_hp) == 'number' and tUnit.max_hp > r.max_max_hp and tUnit.max_hp < 1200 then\""

# M15 ⛔ THE ANTI-VACUITY GUARD in §3.  Without it, every "nothing reaches the
#     seed" below is satisfied by a reader that parsed no health at all -- and
#     §3 holds the empty-set claim the verdict rests on.  Paired with a parse
#     break so the guard has something to catch.
mutant "M15 §3: drop the 4000-hp anti-vacuity guard, then break the hp parse" \
    "sub '$TEST' \"assert(r.above_4k >= 1,\" \"assert(r.above_4k >= 0,\" \
     && sub '$TEST' \"and type(tUnit.hp) == 'number'\" \"and type(tUnit.hp) == 'nosuchtype'\""

echo
restore
if ! verify_restore; then
    echo "FINAL RESTORE LEAKED -- the tree is NOT pristine.  Fix before pushing."
    exit 2
fi

TOTAL=$((KILLED + SURVIVED + ABORTED))
echo "=== $KILLED killed / $SURVIVED survived / $ABORTED aborted  (of $TOTAL) ==="
if [ "$SURVIVED" -ne 0 ] || [ "$ABORTED" -ne 0 ]; then
    echo "NOT CLEAN.  A survivor means the file cannot fail for that reason; an"
    echo "abort means the question was never asked.  Neither is a pass."
    exit 3
fi
echo "every mutant killed"
