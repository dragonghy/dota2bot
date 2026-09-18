#!/usr/bin/env bash
# Mutation stand for tests/test_wk_q_fight_seed_domain.lua -- the verdict file
# that explains why the Wraith King copy of the `nMostDangerousDamage = 0`
# argmax seed (GH #870 §5.2) was NOT landed as a gated id (hero, 2026-09-18).
#
# WHY A STAND FOR A FILE THAT LANDS NOTHING.  Same reason as
# tools/agent/mutstand_wkqaim.sh: a verdict file is quoted by later rounds as
# the reason not to do something, so a reading it can no longer make is worse
# than a missing file.
#
# ⭐⭐ THIS STAND HAS TWO PARTS, AND THE FIRST ONE IS NOT A MUTANT.
#
#   * SECTION C (controls) is the MEASUREMENT the verdict rests on, and it is
#     here rather than in the test because it rewrites shipped source.  It marks
#     the 团战 branch's own return with a distinguishable desire and asks, twice,
#     whether that marker reaches a caller: seeded 0 (shipped) and seeded -1
#     (what arming would do).  0 hits then 1 hit is the whole claim -- the seed
#     really is the only thing between that branch and a cast on
#     f_260909_215040_wk_blast_sb_661.lua -- and the decision STILL does not
#     move, because firing point 10 answers with the same target.
#     ⛔ WITHOUT C2 THE VERDICT WOULD BE UNSOUND IN THE DANGEROUS DIRECTION: a
#     driver that cannot detect ANY difference also reports "no difference".
#     C2 is the positive control that separates those two readings.
#   * SECTION M (mutants) prices the test file's assertions in the usual way.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkqaim.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first edit (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS rather than scoring;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any
# concurrent reader (GH #507, GH #848).

set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_skeleton_king.lua
TEST=tests/test_wk_q_fight_seed_domain.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkqfightseed.XXXXXX")
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

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the wrong of two identical lines scores "survived" for the
# wrong reason.  This stand needs the ambiguity guard -- X.ConsiderQ holds TEN
# `return BOT_ACTION_DESIRE_HIGH` lines and they differ only in the target.
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

# The filter is `wk_q_fight_seed`: the mutants below edit X.ConsiderQ, but every
# assertion that reads it lives in this one file.  ⚠️ Stated rather than papered
# over: the sibling X.ConsiderQ files (wk_q_aim_preflight, wk_qdmg_domain,
# wk_q_castrange_meter_domain) are NOT in this filter, so a mutant that also
# breaks one of them is scored here only through this file's own message.
run_tests() {
    lua5.1 tests/run_tests.lua wk_q_fight_seed > "$WORK/run.log" 2>&1
    return $?
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

# ===========================================================================
# SECTION C -- THE CONTROLS.  Not scored; they are the measurement.
# ===========================================================================
#
# The driver walks every live-WK frame, drives the shipped dispatch and the
# shipped X.ConsiderQ, and prints `<path>|<desire>|<target>`.  A marker on the
# 团战 branch's return therefore shows up as a desire nobody else returns.

DRIVER="$WORK/drive.lua"
cat > "$DRIVER" <<'LUA'
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local WK = 'npc_dota_hero_skeleton_king'
-- ⛔ io.stderr, never print: the Bot API mock stubs `print` out (it does not
-- reach a server console in play), so a stand that reports through print
-- reports nothing and looks like a clean run.
local W = function(s) io.stderr:write(s .. '\n') end
local paths = {}
for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
    local p = io.popen('ls ' .. dir .. ' 2>/dev/null')
    if p then
        for name in p:lines() do
            if name:match('^f_.+%.lua$') then paths[#paths + 1] = dir .. '/' .. name end
        end
        p:close()
    end
end
table.sort(paths)
local function alive(path, unit)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return false end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == unit and u.alive == true then return true end
    end
    return false
end
for _, path in ipairs(paths) do
    if alive(path, WK) then
        local ok, line = pcall(function()
            local J, bot = rf.load(path, WK)
            J.IsModeTurbo = function() return true end
            J.IsSoakCandidate = function() return false end
            local X = rf.load_hero('skeleton_king')
            X.SkillsComplement()
            local d, t = X.ConsiderQ()
            return string.format('%s|%s|%s', path, tostring(d),
                (type(t) == 'table' and t.GetUnitName and t:GetUnitName()) or tostring(t))
        end)
        W(ok and line or (path .. '|ERR|' .. tostring(line)))
    end
end
LUA

MARKER='return 0.4242, npcMostDangerousEnemy'
SHIPPED='return BOT_ACTION_DESIRE_HIGH, npcMostDangerousEnemy'
SEED0='local nMostDangerousDamage = 0'
SEEDM1='local nMostDangerousDamage = -1'

drive_to() {  # $1 = output file
    lua5.1 "$DRIVER" 2> "$1" > /dev/null
}

echo
echo "=== C  controls (measurement, not scored) ==="

# Shipped tree, untouched: the record every later reading is diffed against.
drive_to "$WORK/ship.txt"
echo "C0 shipped: $(wc -l < "$WORK/ship.txt") live-WK frames driven, $(grep -c '|ERR|' "$WORK/ship.txt") errors"

# C1 -- marker on the 团战 branch, SHIPPED seed.  Expect ZERO hits: the branch is
# vetoed by its own seed wherever the candidate set is all-zero.
sub "$HERO" "$SHIPPED" "$MARKER" || exit 3
drive_to "$WORK/mark0.txt"
C1=$(grep -c '|0.4242|' "$WORK/mark0.txt")
restore > /dev/null

# C2 -- the SAME marker with the seed moved to -1, which is what arming would
# do.  Expect exactly ONE hit.  ⭐ This is the positive control: without it,
# "no decision moved" cannot be told apart from "this driver detects nothing".
sub "$HERO" "$SHIPPED" "$MARKER" || exit 3
sub "$HERO" "$SEED0" "$SEEDM1" || exit 3
drive_to "$WORK/mark1.txt"
C2=$(grep -c '|0.4242|' "$WORK/mark1.txt")
C2_WHERE=$(grep '|0.4242|' "$WORK/mark1.txt" | head -1)
restore > /dev/null

# C3 -- seed -1 with NO marker: the end-to-end decision record.  Expect it to be
# byte-identical to the shipped one, on every frame.
sub "$HERO" "$SEED0" "$SEEDM1" || exit 3
drive_to "$WORK/seedm1.txt"
restore > /dev/null

echo "C1 marker reachable with the SHIPPED seed (0) ....... $C1 frame(s)   [want 0 -- the branch is vetoed]"
echo "C2 marker reachable with the seed at -1 ............. $C2 frame(s)   [want 1 -- the seed IS the veto]"
[ -n "$C2_WHERE" ] && echo "       $C2_WHERE"
if diff -q "$WORK/ship.txt" "$WORK/seedm1.txt" > /dev/null; then
    echo "C3 end-to-end decisions, seed 0 vs seed -1 .......... IDENTICAL on all frames"
    echo "   ⇒ the branch fires when armed (C2) and the DECISION still does not move (C3):"
    echo "     firing point 10 answers with the same target.  THAT is the empty domain."
else
    echo "C3 end-to-end decisions, seed 0 vs seed -1 .......... DIFFER:"
    diff "$WORK/ship.txt" "$WORK/seedm1.txt" | sed 's/^/       /'
    echo "   ⭐ THE DECISION DOMAIN IS NO LONGER EMPTY -- this is the reading"
    echo "     tests/test_wk_q_fight_seed_domain.lua §5 is the tripwire for, and it means"
    echo "     the WK seed is now worth landing as a gated id.  Re-read §0 before quoting it."
fi
if [ "$C1" -ne 0 ] || [ "$C2" -ne 1 ]; then
    echo "   ⚠️ THE CONTROLS MOVED (want 0 then 1).  Everything the verdict says about"
    echo "     WHY the domain is empty is derived from these two numbers -- re-measure"
    echo "     before quoting §0."
fi

# ===========================================================================
# SECTION M -- THE MUTANTS.
# ===========================================================================

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

echo
echo "=== M  mutants ==="

# --------------------------------------------------------------- M1 --------
# THE DEFECT THAT HAS ALREADY HAPPENED TWICE IN THIS FAMILY (charter -201, -203):
# a universal that ranges over one corpus directory while the tree holds two.
# Both teamfight frames live in tests/frames, so narrowing the walk empties the
# census silently -- exactly the failure mode that is invisible without a guard.
sub "$TEST" \
    "local CORPUS_DIRS = { 'tests/fixtures', 'tests/frames' }" \
    "local CORPUS_DIRS = { 'tests/fixtures' }" || exit 3
score "M1 corpus narrowed back to tests/fixtures only" "REQUIRED corpus directory tests/frames contributed no"

# --------------------------------------------------------------- M2 --------
# THE RETIREMENT GUARD.  A later round lands the gated seed for real while this
# file goes on explaining that nobody has.
sub "$HERO" "$SEED0" "$SEEDM1" || exit 3
score "M2 the seed is landed in bots/ (0 -> -1) and the verdict is stale" "THIS FILE IS RETIRED"

# --------------------------------------------------------------- M3 --------
# THE TRANSCRIPTION GUARD, which is what buys the right to transcribe at all:
# move the shipped legality chain and the census is counting a different set.
sub "$HERO" \
    "				and not npcEnemy:IsDisarmed()
			then
				local npcEnemyDamage = npcEnemy:GetEstimatedDamageToTarget( false, bot, 3.0, DAMAGE_TYPE_PHYSICAL )" \
    "			then
				local npcEnemyDamage = npcEnemy:GetEstimatedDamageToTarget( false, bot, 3.0, DAMAGE_TYPE_PHYSICAL )" || exit 3
score "M3 shipped 团战 loop drops a legality conjunct" "no longer contains"

# --------------------------------------------------------------- M4 --------
# THE FIRING-POINT COUNT.  §3.2's whole argument is that all ten points return
# the same constant, so target identity is the only observable; a point that
# starts returning something else breaks the argument, not just the count.
sub "$HERO" \
    "			return BOT_ACTION_DESIRE_HIGH, targetCreep" \
    "			return BOT_ACTION_DESIRE_MODERATE, targetCreep" || exit 3
score "M4 one firing point stops returning the shared desire constant" "firing points returning"

# ------------------------------------------------- M5 (EQUIVALENT) --------
# ⛔ REPORTED, NEVER SCORED, AND THE REASON IS MEASURED RATHER THAN ARGUED.
# Weakening §3.2's last conjunct (`first_legal == target` -> `first_legal ~= nil`)
# is the mutation that would let this file publish an empty domain on a frame
# where the armed leg picks a DIFFERENT target.  On THIS corpus the two
# predicates cannot disagree: §5.2 measures that the set of frames where they
# differ is EMPTY (that is its whole content), so no corpus state separates the
# mutant from the original.  ⛔ Do not read this SURVIVED as "the comparison is
# uncovered" -- read it as "the stand cannot price it until the corpus holds the
# frame queue.json:hero-104 asks for", which is the same frame §5.2 waits on.
sub "$TEST" \
    "    assert(r.first_legal == r.target, 'the masked pin" \
    "    assert(r.first_legal ~= nil, 'the masked pin" || exit 3
run_tests; M5RC=$?
restore > /dev/null
echo "M5 §3.2 stops comparing the two targets  EQUIVALENT (exit $M5RC) -- measured, not scored; see the block above"

# ------------------------------------------------- M6 (EQUIVALENT) --------
# ⛔ ALSO REPORTED, NEVER SCORED, AND FOR A REASON THAT GENERALISES:
# A ZERO-ASSERTION CANNOT BE KILLED BY DELETING IT.  §5.1 asserts that a set is
# empty; on a corpus where it IS empty, a disarmed tripwire and an armed one
# print the same thing.  Deleting it is therefore equivalent BY CONSTRUCTION,
# not by accident of this corpus -- which is why M7 below exists: the honest
# question is not "does removing the tripwire hurt" but "does the tripwire fire
# when its condition is met".
sub "$TEST" \
    "        if r.teamfight and r.all_zero and r.castable and r.desire == 0 then" \
    "        if false and r.teamfight and r.all_zero and r.castable and r.desire == 0 then" || exit 3
run_tests; M6RC=$?
restore > /dev/null
echo "M6 §5.1 tripwire disarmed  EQUIVALENT (exit $M6RC) -- measured, not scored; see the block above"

# --------------------------------------------------------------- M7 --------
# ⭐ THE SCORED HALF OF M6: plant a condition the corpus DOES meet and require
# the tripwire to fire, with the message the next round is supposed to act on.
sub "$TEST" \
    "        if r.teamfight and r.all_zero and r.castable and r.desire == 0 then" \
    "        if r.teamfight and r.all_zero and r.castable then" || exit 3
score "M7 §5.1 widened to a condition the corpus DOES meet (tripwire must fire)" "DECISION DOMAIN IS NO LONGER EMPTY"

# --------------------------------------------------------------- M8 --------
# The two pins are the two MECHANISMS (limit 2).  Swapping them makes §3 read
# the upstream-refused frame, where the cooldown assertion has to refuse it.
sub "$TEST" \
    "local PIN_MASKED  = 'tests/frames/f_260909_215040_wk_blast_sb_661.lua'" \
    "local PIN_MASKED  = 'tests/frames/f_260909_215227_zeus_ult_1008.lua'" || exit 3
score "M8 the masked pin is swapped for the refused one" "of cooldown on the masked"

echo
echo "=== $CAUGHT/$TOTAL caught (M5 and M6 are measured equivalent mutants: reported, not scored) ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
