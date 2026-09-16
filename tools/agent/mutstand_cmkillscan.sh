#!/usr/bin/env bash
# Mutation stand for tests/test_cm_kill_confirm_quantifier.lua -- the hero desk's
# DO-NOT-ARM ruling on iterations/streams/hero.md backlog `-190`'s "下一轮主体
#候选·第 1 条" (the 击杀敌人 existential collapse).
#
# ⚠️ THIS ROUND SHIPS NO GATED ID, so this stand is NOT the usual "does the gate
# work" stand.  What it prices is whether the FILE CAN STILL FAIL: a ruling
# backed by a test that passes under every mutation is a ruling backed by
# nothing.  The mutants therefore fall in three groups, and the third is the one
# worth the effort:
#   A  the source facts the ruling reads       (M1-M4)
#   B  the corpus/loader facts it reports      (M5-M8)
#   C  THE INSTRUMENT ITSELF                   (M9-M13)
#      -- a broken driver produces PASSES for free: a baseline that never bids,
#      an injection that lands on nothing, an enumerator that yields no files.
#      Every one of those makes a "measured zero" indistinguishable from
#      "measured nothing", which is the failure mode this whole round is about.
#
# Usage:  bash tools/agent/mutstand_cmkillscan.sh
# Exit 0 iff every mutant is KILLED.  Reads and restores from a file copy (never
# from git), per .claude/skills/evidence-discipline.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

TEST=tests/test_cm_kill_confirm_quantifier.lua
CM=bots/BotLib/hero_crystal_maiden.lua
JMZ=bots/FunLib/jmz_func.lua
API=tests/mock/bot_api.lua
# ⚠️ M8 mutates a CORPUS FILE.  The first version of this stand backed up only
# the four files above, so M8's edit to the fixture SURVIVED the run and was
# still sitting in the working tree afterwards -- found by `git status`, not by
# this script, and it would have been committed.  The rule this cost:
# EVERY FILE A MUTANT TOUCHES BELONGS IN THE BACKUP LIST, and the list is not
# "the files the stand is about".
FIX=tests/frames/f_260905_004847_lion_drain_bkb.lua

TMP="$(mktemp -d)"
cp "$TEST" "$TMP/test.bak"
cp "$CM"   "$TMP/cm.bak"
cp "$JMZ"  "$TMP/jmz.bak"
cp "$API"  "$TMP/api.bak"
cp "$FIX"  "$TMP/fix.bak"

restore() {
    cp "$TMP/test.bak" "$TEST"
    cp "$TMP/cm.bak"   "$CM"
    cp "$TMP/jmz.bak"  "$JMZ"
    cp "$TMP/api.bak"  "$API"
    cp "$TMP/fix.bak"  "$FIX"
}

# ⛔ RESTORING IS NOT THE SAME AS HAVING RESTORED, and this stand paid for the
# difference before the check existed here: M8's edit to $FIX survived the whole
# run, because $FIX was not in the backup list at all, and it was still in the
# working tree afterwards -- found by `git status`, not by this script.  It also
# CONTAMINATED THE SCORE: every mutant after M8 ran against a corpus whose BKB
# modifier had been renamed, so M9-M13 each "killed" for a reason that had
# nothing to do with the mutation, and the run reported 13/13 when four of those
# mutants in fact SURVIVED.  ⇒ A leaked mutation does not merely dirty the tree,
# it manufactures kills -- the mirror image of GH #846's unapplied mutant
# scoring for free.  tests/test_mutstand_restore_trap.py requires a byte-level
# proof for exactly this reason; here it is a sha256sum comparison per managed
# file, run after every restore rather than only at the end, so a leak is caught
# on the mutant that caused it instead of five mutants later.
verify_restore() {
    local bad=0 f b
    for pair in "$TEST:test.bak" "$CM:cm.bak" "$JMZ:jmz.bak" "$API:api.bak" "$FIX:fix.bak"; do
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
    timeout 600 lua5.1 tests/run_tests.lua "$(basename "$TEST")" >"$TMP/out" 2>&1
    return $?
}

# $1 = label, $2 = a shell snippet that applies the mutation
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

# Apply a literal substitution and PROVE it landed (a sed that matched nothing
# is the silent-mutant failure of GH #846).
sub() {
    local file="$1" from="$2" to="$3"
    grep -qF "$from" "$file" || return 1
    python3 - "$file" "$from" "$to" <<'PY' || return 1
import sys
path, frm, to = sys.argv[1], sys.argv[2], sys.argv[3]
body = open(path, encoding='utf-8').read()
if frm not in body:
    sys.exit(1)
open(path, 'w', encoding='utf-8').write(body.replace(frm, to, 1))
PY
    grep -qF "$to" "$file" || return 1
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
echo "=== group A: the source facts the ruling reads ==="

# M1  The selector's filter -- the single fact the DO-NOT-ARM ruling rests on.
mutant "M1  selector loses its CanCastOnNonMagicImmune filter" \
    "sub $CM 'if 	J.CanCastOnNonMagicImmune( unit )' 'if 	true'"

# M2  Somebody 'repairs' the kill confirm with the dead conjunct after all.
mutant "M2  kill confirm gains an immunity conjunct" \
    "sub $CM 'and J.CanCastOnTargetAdvanced( nWeakestEnemyHeroInRange )' \
             'and J.CanCastOnNonMagicImmune( nWeakestEnemyHeroInRange )'"

# M3  The in-file evidence for the ruling: the ONE lane sub-branch whose target
#     is not selector-derived is the one that writes the immunity test.
mutant "M3  the raw-view lane sub-branch drops its IsMagicImmune term" \
    "sub $CM 'and not nEnemysHeroesInView[1]:IsMagicImmune()' 'and true'"

# M4  The other half of the split: a selector-derived sub-branch grows one.
mutant "M4  a selector-derived lane sub-branch grows an immunity term" \
    "sub $CM 'and not J.IsDisabled( nWeakestEnemyHeroInBonus )' \
             'and J.CanCastOnNonMagicImmune( nWeakestEnemyHeroInBonus )'"

echo
echo "=== group B: the corpus and loader facts it reports ==="

# M5  The loader starts deriving IsMagicImmune -> section 5's gap is closed and
#     the file must SAY so rather than keep reporting an UNASKABLE.
mutant "M5  the mock derives IsMagicImmune from the modifier list" \
    "sub $API \"if key:find('^Is') or key:find('^Has') or key:find('^Can') or key:find('^Was') then\" \
              \"if key == 'IsMagicImmune' then return true end
    if key:find('^Is') or key:find('^Has') or key:find('^Can') or key:find('^Was') then\""

# M6  A spell-block modifier appears in the corpus -> the DO-NOT-ARM ruling
#     expires and the file must notice, not keep quoting its zero.
mutant "M6  BLOCK_MODS names a modifier the shipped helper does not" \
    "sub $TEST \"'modifier_roshan_spell_block',\" \"'modifier_not_in_the_helper',\""

# M7  J.CanCastOnTargetAdvanced stops reading the spell-block family -> section
#     4's 'this zero is askable' claim is no longer true.
mutant "M7  CanCastOnTargetAdvanced loses the sphere check" \
    "sub $JMZ 'return not npcTarget:HasModifier( \"modifier_item_sphere_target\" )' \
              'return true and not npcTarget:HasModifier( \"modifier_none\" )'"

# M8  The BKB row section 5 stands on loses its modifier.
mutant "M8  the BKB frame's recorded modifier is renamed" \
    "sub $FIX 'modifier_black_king_bar_immune' 'modifier_black_king_bar_nothing'"

echo
echo "=== group C: the instrument (a broken driver passes for free) ==="

# M9  The corpus walk quietly loses tests/frames/ -- the failure mode
#     tests/test_lion_ult_reserve_domain.lua has on record.
mutant "M9  corpus walk drops the staged-frames directory" \
    "sub $TEST 'for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do' \
               'for _, dir in ipairs({ FIXTURE_DIR }) do'"

# ⚠️ ALL FOUR MUTANTS BELOW ARE THE SECOND VERSION.  The first four SURVIVED,
# and every one of them survived because THIS DESK'S CLAIM WAS WRONG, not
# because the file was weak -- evidence-discipline rule 2, four times in one
# run.  The first versions were:
#   M10 deleted `inject(hW, 'IsFullyCastable', true)` -- redundant: the loader
#       DERIVES IsFullyCastable from the recorded cooldown, so the cooldown
#       injection alone already did it.  ready() now carries one injection.
#   M11 deleted the X.SkillsComplement() call -- not load-bearing for THIS
#       branch: the kill confirm reads none of the per-frame locals the
#       dispatch assigns.
#   M12 deleted inject()'s cache-drop line -- defensive here, not load-bearing,
#       exactly as test_cm_lane_fallback_wallet.lua found for its own M12.
#   M13 flipped the gates from down to up -- inert: no CM soak candidate
#       reaches the kill confirm today.
# Each claim is now corrected in the test file's own comments, and each mutant
# re-aimed at the line that IS load-bearing.  ⛔ A surviving mutant is a
# question about the assertion first and about the score second.

# M10 The baseline bid disappears -> sections 2 and 3 become differences from
#     nothing, and both would still 'pass'.  The cooldown is the real injection.
mutant "M10 ready() stops taking Frostbite off cooldown" \
    "sub $TEST \"    inject(hW, 'GetCooldownTimeRemaining', 0)\" \"    local _ = hW\""

# M11 The section-2/3 prep never runs -- the injection-never-applied shape of
#     GH #846, on the driver side rather than the stand side.
mutant "M11 drive() ignores its fPrep, so no injection is ever applied" \
    "sub $TEST '    if fPrep then fPrep(J, bot, hW) end' '    local _ = fPrep'"

# M12 inject() stops writing the spec -- the line that IS load-bearing.
mutant "M12 inject() stops writing the spec" \
    "sub $TEST \"    rawget(h, '__spec')[k] = v\" \"    local _ = v\""

# M13 The corpus liveness filter goes -- section 4's population is then 'every
#     CM row' rather than 'every LIVE CM instant', which is the GH #794 defect
#     this repo has already paid for once.
mutant "M13 the section-4 population drops its liveness filter" \
    "sub $TEST 'if u.name == UNIT and u.alive ~= false then present = true end' \
               'if u.name == UNIT then present = true end'"

echo
echo "=== result ==="
restore
if ! verify_restore; then
    echo "  killed=$KILLED  survived=$SURVIVED  aborted=$ABORTED"
    echo "STAND FAILED -- the tree did not come back; the score above is not trustworthy"
    exit 1
fi
echo "  every managed file matches its pristine copy (sha256)"
echo "  killed=$KILLED  survived=$SURVIVED  aborted=$ABORTED"
if [ "$SURVIVED" -ne 0 ] || [ "$ABORTED" -ne 0 ]; then
    echo "STAND FAILED"
    exit 1
fi
echo "STAND CLEAN -- every mutant killed"
exit 0
