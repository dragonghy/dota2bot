#!/usr/bin/env bash
# Mutation stand for tests/test_wk_rank0_absence_join.lua -- the file that joins
# tests/test_wk_save_mana_lock_census.lua section 1 against
# tests/test_wkreinctr_untrained.lua and rules that "Reincarnation at ability
# level 0" is an ABSENCE on the three v1 fixtures, not recorded data.
# (hero, 2026-09-07, backlog -118, OWNER_PRIORITIES P4.4 (ii)).
#
# Run by hand when tests/mock/replay_fixture.lua, tests/mock/bot_api.lua,
# bots/mode_retreat_generic.lua's Wraith King block, J.IsWkReincarnationArmed,
# or the joined file itself are edited -- and before quoting any of that file's
# readings in a ruling.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wksaveidle.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor is absent OR ambiguous ABORTS instead of scoring;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  This stand
# rewrites tests/mock/*, which every other file in the suite reads -- the
# tearing window (GH #507) is wider here than for a hero-file stand, not
# narrower.
#
# ⭐ THE FILTER IS THIS ONE FILE, AND THAT IS THE OPPOSITE CHOICE FROM THE
# `wk_` STANDS.  Three of the mutants below edit a shared MOCK.  Under a broad
# filter every one of them would turn some unrelated census red and score
# "caught" without this file's assertions ever having looked -- the collision
# failure in its other direction.  So the filter is narrow and every mutant is
# additionally required to produce THIS file's own message.
#
# ⭐⭐ TWO OF THESE ARE BEHAVIOURAL NO-OPS AND MUST STILL BE CAUGHT:
#   * M2 duplicates an install line inside the loader's abilities loop.  Every
#     read answers exactly what it answered before.  What it destroys is the
#     "ONE install site, and it is inside the loop" property -- which is the
#     whole argument that an abilities-less unit CANNOT get real readers.  Only
#     a source assertion can see it.
#   * M6 loosens the call site's hero-level guard from 6 to 1.  On this corpus
#     the reachable set is 0 either way (J.IsInTeamFight is false on all 36 WK
#     frames), so nothing about the retreat mode moves today.  But section 3's
#     entire split of the untrained frames is cut by that 6, and section 4
#     exists to stop the split being quoted against a number the tree no longer
#     holds.
#
# ⛔ WHAT THIS STAND DOES NOT DO: it does not mutate 'wkreinctr', its helper's
# logic, or tests/test_wkreinctr_untrained.lua.  That is another stream's landed
# id (GH #582); this work unit delivers a reading, not a repair.
#
# Usage: bash tools/agent/mutstand_wkrank0join.sh
set -u
cd "$(dirname "$0")/../.."

LOADER=tests/mock/replay_fixture.lua
API=tests/mock/bot_api.lua
RETREAT=bots/mode_retreat_generic.lua
JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_wk_rank0_absence_join.lua

FILES=("$LOADER" "$API" "$RETREAT" "$JMZ" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_wkr0j.XXXXXX")
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
    lua5.1 tests/run_tests.lua wk_rank0_absence_join > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the wrong of two identical sites scores "survived" for the
# wrong reason.
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
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the `or {}` becomes a REAL default.  A unit with no abilities list now
#     gets a trained Reincarnation installed, the three v1 frames stop being
#     absences, and the contradiction this file settles evaporates without
#     anybody having re-cut a fixture.  This is the mutant that makes the
#     finding untrue, and it must not pass quietly.
echo
echo "=== M1: the loader invents an abilities list for units that carry none ==="
sub "$LOADER" "local resolved = resolve_slots(u.name, u.abilities or {})" \
              "local resolved = resolve_slots(u.name, u.abilities or { { name = 'skeleton_king_reincarnation', level = 1, cd = 0 } })"
sub "$LOADER" "for i, a in ipairs(u.abilities or {}) do" \
              "for i, a in ipairs(u.abilities or { { name = 'skeleton_king_reincarnation', level = 1, cd = 0 } }) do"
score "M1" "the loader now installs"

# ---------------------------------------------------------------------------
# M2: THE SHAPE MUTANT, behaviourally a no-op (see the header).  A second
#     assignment of the same reader, same value, same loop.  Every read is
#     unchanged; what is gone is the uniqueness that makes "an abilities-less
#     unit gets no readers" a property of the loader rather than a coincidence.
echo
echo "=== M2: the loader assigns GetLevel at two sites (behaviourally a no-op) ==="
sub "$LOADER" "                sp.GetLevel = a.level
                sp.GetCooldownTimeRemaining = a.cd" \
              "                sp.GetLevel = a.level
                sp.GetLevel = a.level
                sp.GetCooldownTimeRemaining = a.cd"
score "M2" "is now assigned at 2 sites in the loader"

# ---------------------------------------------------------------------------
# M3: the loader serves a rank the fixture never recorded.  This is the mutant
#     that section 3's raw/driven check exists for: without it, `raw_rank == nil`
#     would stop meaning "the loader had nothing to serve" and the whole
#     absence/data distinction would rest on an unvalidated parallel reading.
echo
echo "=== M3: the loader serves recorded_rank + 1 ==="
sub "$LOADER" "                sp.GetLevel = a.level
                sp.GetCooldownTimeRemaining = a.cd" \
              "                sp.GetLevel = a.level + 1
                sp.GetCooldownTimeRemaining = a.cd"
score "M3" "the loader serves rank"

# ---------------------------------------------------------------------------
# M4: the generic `^Get` default stops answering 0.  The blank handle the three
#     absence frames read through starts reporting a rank, which is exactly the
#     shape section 1 says is indistinguishable from data -- so the file must
#     notice when it becomes distinguishable.
echo
echo "=== M4: bot_api's generic ^Get default answers 1 instead of 0 ==="
sub "$API" "    if key:find('^Get') then return 0 end" \
           "    if key:find('^Get') then return 1 end"
score "M4" "with nothing installed"

# ---------------------------------------------------------------------------
# M5: the generic `^Is` default answers true.  IsTrained() on a blank handle now
#     reports a LEARNED ultimate, the untrained set loses the three absence
#     frames, and the join's set B empties.  The anti-vacuum guard in section 2
#     is what stops that reading as "the two sets still agree".
echo
echo "=== M5: bot_api's generic ^Is default answers true ==="
sub "$API" "    if key:find('^Is') or key:find('^Has') or key:find('^Can') or key:find('^Was') then
        return false
    end" \
           "    if key:find('^Is') or key:find('^Has') or key:find('^Can') or key:find('^Was') then
        return true
    end"
score "M5" "it used to answer 0/false/0"

# ---------------------------------------------------------------------------
# M6: THE SECOND NO-OP (see the header).  The call site's hero-level guard drops
#     from 6 to 1.  Reachability does not move on this corpus, but section 3's
#     split is cut by that 6 and section 4 is the only thing tying the two
#     together.
echo
echo "=== M6: the call site's hero-level guard drops from 6 to 1 ==="
sub "$RETREAT" "        and bot:GetLevel() >= 6
        and J.IsWkReincarnationArmed(bot)" \
               "        and bot:GetLevel() >= 1
        and J.IsWkReincarnationArmed(bot)"
score "M6" "the call site no longer guards"

# ---------------------------------------------------------------------------
# M7: the call site stops calling the helper at all.  Section 3's split then
#     describes nothing -- a dead reading is worse than a wrong one, because it
#     keeps passing.
echo
echo "=== M7: the call site stops calling J.IsWkReincarnationArmed ==="
sub "$RETREAT" "        and J.IsWkReincarnationArmed(bot)" \
               "        and true"
score "M7" "no longer calls J.IsWkReincarnationArmed"

# ---------------------------------------------------------------------------
# M8: a third candidate id appears in the shipped helper.  The readings above
#     were taken against a two-id helper; a third clause is somebody else's
#     change and must force a re-take rather than ride along.
echo
echo "=== M8: the shipped helper grows a third candidate id ==="
sub "$JMZ" "	local nReq = 160
	if J.IsModeTurbo() and J.IsSoakCandidate( 'wkreincarnmp' ) then" \
            "	local nReq = 160
	if J.IsSoakCandidate( 'wkreinmpfloor' ) then nReq = 999 end
	if J.IsModeTurbo() and J.IsSoakCandidate( 'wkreincarnmp' ) then" \

score "M8" "candidate ids, not the 2 it carried"

# ---------------------------------------------------------------------------
# M9: THE ANTI-VACUUM MUTANT.  The corpus walk stops finding Wraith Kings.
#     Every set in section 2 is then empty, and empty sets are EQUAL -- the join
#     would pass while measuring nothing.  This is the M15 lesson of the
#     'wkreinctr' round landing on this file's own instrument.
echo
echo "=== M9: the corpus walk matches no Wraith King (all sets empty) ==="
sub "$TEST" "                if u.name == WK and u.alive then" \
            "                if u.name == WK .. '_nope' and u.alive then"
score "M9" "the contradiction this file settles is gone"

# ---------------------------------------------------------------------------
# M10: the file arms a candidate while calling itself a reading of the shipped
#      tree.  Section 6 is the only thing that can see this.
echo
echo "=== M10: the corpus walk drives the helper with a candidate armed ==="
sub "$TEST" "                        J.IsSoakCandidate = function() return false end" \
            "                        J.IsSoakCandidate = function() return true end"
score "M10" "now drives the helper with a gate that returns"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1
