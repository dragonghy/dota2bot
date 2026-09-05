#!/usr/bin/env bash
# Mutation stand for tests/test_replay_creepthink_drag_order.lua (test_set.md §ER).
#
# WHAT IT IS FOR. This round buys condition (a) for soak candidate 'creepthink'
# at the fixture layer, after the replay desk ruled (GH #521) that the dump side
# structurally cannot sell it. The evidence is an ORDER LOG: the real Think()
# driven over a cadence beat on a real laning frame, shipped vs armed. Two
# things can forge that kind of evidence, and neither is exotic:
#
#   * THE TOGGLE STOPS TOGGLING, or toggles something else. The armed leg taken
#     disarmed reads "no effect" (the droppick/argfix shape, and the direction
#     that quietly kills a promote); the shipped leg taken armed reads "the
#     defect does not exist". Both still produce a plausible log.
#   * THE ARMING IS TOO WIDE. A stub that answers true for EVERY id also arms
#     'pullcad', which triples the cadence beat -- the reading would then be
#     about a configuration this file explicitly says it is not measuring.
#     (The §EP round learned this the hard way: its first all-ids mutant
#     SURVIVED, because on that corpus one-id and all-ids gave the same number.)
#
# and two more that live in the instrument rather than the driver:
#
#   * THE DOMAIN COLUMN COLLAPSES. The whole licence for declaring one lane
#     creep rests on `plan_shipped == 0` being the WORLD's zero and
#     `plan_declared > 0` proving the creeps are what the corpus is missing. If
#     the two columns are read off the same leg, or the stand-in creep is placed
#     outside the 500u aggro-redirect ring the helper tests, the pair still
#     prints two numbers and says nothing.
#   * A REACHABILITY BUCKET IS FORGED. "GetNearbyLaneCreeps answers a MEASURED
#     empty table" is what separates "the dumper writes no creeps" from "this
#     branch never ran" (GH #171). Bump that bucket outside its branch and the
#     forgery reads identically -- unless the four buckets are made to sum.
#
# CONTROL (must SURVIVE): M12 rewrites a COMMENT inside the gated conjunct's
# note in bots/mode_roam_generic.lua. Nothing in this suite may be satisfied by
# prose, so a comment edit must not be able to turn it red. A stand where every
# mutant is caught cannot tell a sharp assertion from one that fires on
# anything.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_creepthink.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, the
# control was CAUGHT, or an edit matched nothing (NO-OP counts as non-compliant,
# not as a pass: a mutant that never existed still prints a line).
#
# SLOW ON PURPOSE: every mutant re-runs the test file, and that file drives a
# 459-frame corpus sweep in a subprocess. The sweep is part of what is under
# test; running it once and reusing the output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MODE=bots/mode_roam_generic.lua
SWEEP=tests/_creepthink_sweep.lua
DRIVER=tests/test_replay_creepthink_drag_order.lua
TEST=creepthink_drag_order

TMP=$(mktemp -d)
nrun=0; ncaught=0; nbad=0
INFLIGHT=""

save() {
    cp "$1" "$TMP/$(basename "$1").orig"
    sha256sum "$1" > "$TMP/$(basename "$1").sha"
    INFLIGHT="$1"
}
restore() {
    cp "$TMP/$(basename "$1").orig" "$1"
    if ! sha256sum -c "$TMP/$(basename "$1").sha" >/dev/null; then
        echo "FATAL: restore of $1 did not verify -- stopping before anything else runs"
        exit 2
    fi
    INFLIGHT=""
}
# GH #418's trap: restore FIRST, delete the copies SECOND. The reverse leaves a
# mutant in the tree and destroys the only original.
on_exit() {
    if [ -n "$INFLIGHT" ]; then
        echo "INTERRUPTED with $INFLIGHT mutated -- restoring before exit"
        restore "$INFLIGHT"
    fi
    rm -rf "$TMP"
}
trap on_exit EXIT

# Rule 3: read the exit code directly, never through a pipe.
run_test() {
    local rc=0
    lua5.1 tests/run_tests.lua "$TEST" > "$TMP/$TEST.log" 2>&1 || rc=$?
    echo "$rc"
}

mutant() {
    local want=$1 label=$2 target=$3; shift 3
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-56s (the edit matched nothing -- the mutant never existed)\n' "$label"
        nbad=$((nbad + 1))
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$want" = caught ]; then
        if [ "$rc" -ne 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'CAUGHT    %-56s exit=%s\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'SURVIVED  %-56s exit=%s\n' "$label" "$rc"
            echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
            echo "            per its converse, first confirm the edit landed where you meant."
        fi
    else
        if [ "$rc" -eq 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'SURVIVED  %-56s exit=%s  (control, as declared)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-56s exit=%s  ** CONTROL WENT RED **\n' "$label" "$rc"
            echo "          ^ a comment edit turned this suite red: something in it"
            echo "            is being satisfied by prose rather than by code."
        fi
    fi
}

# --- M1..M4: the line under test leaves, moves, or inverts --------------------

# The lever is deleted outright: Think falls back to the pure shipped throttle,
# so the armed leg goes silent and the whole condition-(a) reading evaporates.
m1() { perl -0pi -e "s/\n\tand not \(bot\.roamCreepPull ~= nil and J\.IsSoakCandidate\('creepthink'\)\)//" "$MODE"; }
mutant caught "M1 the creepthink conjunct is deleted" "$MODE" m1

# Pointed at the SIBLING field. Same id, same shape, reviewable-looking -- and
# it can never fire on a creep pull, because GetDesire nils roamCampPull when it
# sets roamCreepPull. This is the mutation a reader skims past.
m2() { perl -0pi -e "s/and not \(bot\.roamCreepPull ~= nil and J\.IsSoakCandidate\('creepthink'\)\)/and not (bot.roamCampPull ~= nil and J.IsSoakCandidate('creepthink'))/" "$MODE"; }
mutant caught "M2 the conjunct points at roamCampPull" "$MODE" m2

# The `not` is dropped: UNARMED behaviour changes -- the whole condition goes
# false on every frame with no pull plan, so the throttle stops guarding roam at
# all. The defect leg is what has to notice, and it is a change to SHIPPED code.
m3() { perl -0pi -e "s/and not \(bot\.roamCreepPull ~= nil and J\.IsSoakCandidate\('creepthink'\)\)/and (bot.roamCreepPull ~= nil and J.IsSoakCandidate('creepthink'))/" "$MODE"; }
mutant caught "M3 the conjunct is inverted (not dropped)" "$MODE" m3

# THE PULLCAD TRAP, written the way it always looks: a dependency expressed as a
# conjunction. 'pullbeat' was PROMOTED 2026-08-23 and a promoted id is in no
# armed string, so this freezes the lever FALSE in every wave while
# check_armed_wiring.py still calls it WIRED (it checks that a call site exists,
# not that the predicate can ever be true).
m4() { perl -0pi -e "s/J\.IsSoakCandidate\('creepthink'\)\)/J.IsSoakCandidate('creepthink') and J.IsSoakCandidate('pullbeat'))/" "$MODE"; }
mutant caught "M4 pullcad trap: 'creepthink' and 'pullbeat'" "$MODE" m4

# --- M5..M7: the toggle stops toggling, or toggles too much -------------------

# The armed leg taken DISARMED. Reads back as "the lever does nothing" -- the
# safe-looking direction, and the one that silently kills a promote.
m5() { perl -0pi -e "s/return bArmed and sId == 'creepthink'/return false/" "$DRIVER"; }
mutant caught "M5 the armed leg is driven disarmed" "$DRIVER" m5

# The shipped leg taken ARMED. Reads back as "there is no defect".
m6() { perl -0pi -e "s/return bArmed and sId == 'creepthink'/return sId == 'creepthink'/" "$DRIVER"; }
mutant caught "M6 the shipped leg is driven armed" "$DRIVER" m6

# ARM LEAK: the stub answers true for EVERY id, so 'pullcad' comes along and the
# cadence beat triples (1.2s -> 3.0s). The log is still plausible and still
# shows a poke and a drag -- it is simply about a different configuration than
# the one this file declares it measures.
m7() { perl -0pi -e "s/return bArmed and sId == 'creepthink'/return bArmed/" "$DRIVER"; }
mutant caught "M7 arm leak: the stub arms every candidate" "$DRIVER" m7

# --- M8..M11: the domain instrument stops answering the question --------------

# Both columns read off the SAME (declared) leg. `plan_shipped` then reports 73
# and the "the corpus cannot carry this decision" claim inverts -- while the
# manifest still prints two numbers that look like a comparison.
m8() { perl -0pi -e "s/local okp, plan = pcall\(J\.ShouldCreepPullLane, bot\)/local okp, plan = pcall(J.ShouldCreepPullLane, bot); if okp and plan == nil then plan = { enemy = 1 } end/" "$SWEEP"; }
mutant caught "M8 plan_shipped is read off the declared leg" "$SWEEP" m8

# The declaration never lands: plan_declared collapses to 0. Then the zero in
# column 1 stops being attributable to the creeps -- some other clause could be
# doing the refusing -- and the fixture's stand-in is buying a plan the shipped
# helper would reject anyway.
m9() { perl -0pi -e "s/\n                            sp\.GetNearbyLaneCreeps = function\(\) return \{ creep \} end//" "$SWEEP"; }
mutant caught "M9 the declared creep is never installed" "$SWEEP" m9

# The stand-in creep is placed OUTSIDE the 500u aggro-redirect ring the helper
# itself tests. A constant moving under the census: every count stays a
# plausible number and every one of them is about a different world.
m10() { perl -0pi -e "s/local CREEP_FROM_ENEMY = 250/local CREEP_FROM_ENEMY = 900/" "$SWEEP"; }
mutant caught "M10 the stand-in creep moves outside the 500u ring" "$SWEEP" m10

# A REACHABILITY BUCKET IS FORGED: `creeps_empty` is bumped before the branch
# that earns it, so a nil or a raise would be reported as a measured empty wave
# -- which is the exact difference between "the dumper writes no creeps" and
# "this branch never ran" (GH #171). Only the partition sum can see it.
m11() { perl -0pi -e "s/                        local okc, creeps = pcall\(function\(\)/                        bump('creeps_empty')\n                        local okc, creeps = pcall(function()/" "$SWEEP"; }
mutant caught "M11 creeps_empty is bumped outside its branch" "$SWEEP" m11

# --- M12: the control -------------------------------------------------------
m12() { perl -0pi -e "s/-- ITS OWN ID, NOT A SECOND CLAUSE OF 'pullthink'/-- ITS OWN ID, NOT A SECOND CLAUSE OF 'pullthink' (comment mutated)/" "$MODE"; }
mutant survive "M12 CONTROL: a comment in the gated note is rewritten" "$MODE" m12

echo
echo "mutants run: $nrun   landed as declared: $ncaught   non-compliant: $nbad"
if [ "$nbad" -ne 0 ]; then
    echo "STAND NOT CLEAN -- do not quote any reading from this suite until this is 0."
    exit 1
fi
echo "stand clean."
exit 0
