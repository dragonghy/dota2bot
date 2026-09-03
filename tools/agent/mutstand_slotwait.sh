#!/usr/bin/env bash
# Mutation stand for soak candidate 'slotwait' (GH #467) and its test file,
# tests/test_slotwait_cooldown_scan.lua.
#
# WHAT IT IS FOR. The corpus cannot exercise the DECISION these two predicates
# make -- 98 evaluations, 0 TRUE, 0 flips, for two independent reasons the test
# file documents at the top. When the outcome never moves, a test that only
# compares outcomes is indistinguishable from a test that measures nothing, and
# that is exactly the shape this repo keeps paying for (`0EQUIV`, the
# `slotpush` `i + 1` mutant that survived until the trace test existed). So
# every claim the file makes is put back under a mutant that a correct
# assertion MUST catch: the scan, the arguments, the one-read gate, the order,
# the consumer's route, and the TS parity.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every single mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_slotwait.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation). No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

UTILS=bots/FunLib/utils.lua
JMZ=bots/FunLib/jmz_func.lua
PUSH=bots/FunLib/aba_push.lua
TS=typescript/bots/FunLib/utils.ts
TEST=test_slotwait_cooldown_scan.lua

TMP=$(mktemp -d)

nrun=0; ncaught=0

# INFLIGHT names the file that is mutated RIGHT NOW, or is empty when the tree
# is clean.  See the EXIT trap below for why this stand needs it and the sibling
# stands do not.
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

# GH #418's trap.  This stand landed at 22:45Z carrying the defect GH #468 had
# fixed in mutstand_fixture_debt.sh twenty minutes earlier, because it was
# copied from that stand's pre-fix shape -- so the repair is copied forward too,
# and tests/test_mutstand_restore_trap.py is what caught it on the day it landed.
# The old line was `trap 'rm -rf "$TMP"' EXIT`, which is WORSE than no trap at
# all here: on an interrupt it left the mutant in the working tree AND deleted
# $TMP, the only copy of the original.  `trap restore EXIT` is not available
# because this stand's `restore` takes an argument and would die on $1 under
# `set -u`; that is what INFLIGHT above is for.  Order inside the handler is
# content, not style: restore first, remove the copies second.
on_exit() {
    if [ -n "$INFLIGHT" ]; then
        echo "INTERRUPTED with $INFLIGHT mutated -- restoring before exit"
        restore "$INFLIGHT"
    fi
    rm -rf "$TMP"
}
trap on_exit EXIT

# Run the test file and report its BARE exit code (rule 3: never through a pipe).
run_test() {
    lua5.1 tests/run_tests.lua "$TEST" > "$TMP/out.log" 2>&1
    echo $?
}

mutant() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-52s (the sed matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-52s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-52s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first."
    fi
}

# --- M1: the whole fix, reverted ---------------------------------------------
# The state of the tree before GH #467. It must be caught by the DENOMINATOR
# (the trace and the counterfactuals), not by some incidental structural string
# -- a finding that has already disappeared cannot raise its own hand.
m1() { perl -0pi -e 's/        local nSlot = playerId\n        if bSlotWait then\n            nSlot = i\n        end\n        local teamMember = GetTeamMember\(nSlot\)/        local teamMember = GetTeamMember(playerId)/g' "$UTILS"; }
mutant "M1 the pid->slot fix is reverted in both functions" "$UTILS" m1

# --- M2: off-by-one in the armed index ---------------------------------------
# The mutant that survived the whole slotpush file until its trace test existed:
# armed scans slots 2..6, so it still reaches four real members and every
# outcome comparison still passes. Only the ARGUMENT trace can see it.
#
# ⚠️ THE MUTATION MUST BE ANCHORED ON `bSlotWait`, and the first draft was not.
# `nSlot = i` appears in THREE functions in this file -- these two and
# IsTeamPushingSecondTierOrHighGround ('slotpush', line ~1723) -- and an
# unanchored pattern hits the slotpush one first, because it comes earlier in
# the file and the shorter indent matches inside the longer one. That mutant
# then edits a function THIS test file does not cover, the run comes back
# green, and the stand reports SURVIVED for a test that is in fact watching.
# A mis-aimed mutant and a blind assertion are the same output; only reading
# the diff tells them apart (evidence-discipline rule 2's converse).
m2() { perl -0pi -e 's/if bSlotWait then\n            nSlot = i\n/if bSlotWait then\n            nSlot = i + 1\n/g' "$UTILS"; }
mutant "M2 armed scans slots 2..6 (off by one)" "$UTILS" m2

# --- M3: only ONE of the two functions is fixed ------------------------------
# The half-landed fix. 'slotwait' covers two functions on purpose; a test that
# only ever drove the spell leg would call this green.
m3() { perl -0pi -e 's/(HasTeamMemberWithCriticalItemInCooldown\(targetLoc, bSlotWait\)\n.*?\n)        local nSlot = playerId\n        if bSlotWait then\n            nSlot = i\n        end\n        local teamMember = GetTeamMember\(nSlot\)/$1        local teamMember = GetTeamMember(playerId)/s' "$UTILS"; }
mutant "M3 only the spell leg is fixed; the item leg is not" "$UTILS" m3

# --- M4: the gate is read twice ----------------------------------------------
# The reason this is ONE wrapper for TWO functions. Two independent reads are
# not a style difference: they are two conjuncts that can drift apart, which is
# the `pullcad` shape one level down.
m4() { perl -0pi -e "s/\tlocal bSlotWait = J.IsModeTurbo\(\) and J.IsSoakCandidate\( 'slotwait' \)\n\treturn J.Utils.HasTeamMemberWithCriticalItemInCooldown\( vLocation, bSlotWait \)\n\t\tor J.Utils.HasTeamMemberWithCriticalSpellInCooldown\( vLocation, bSlotWait \)/\treturn J.Utils.HasTeamMemberWithCriticalItemInCooldown( vLocation, J.IsModeTurbo() and J.IsSoakCandidate( 'slotwait' ) )\n\t\tor J.Utils.HasTeamMemberWithCriticalSpellInCooldown( vLocation, J.IsModeTurbo() and J.IsSoakCandidate( 'slotwait' ) )/" "$JMZ"; }
mutant "M4 the gate is read once per leg, not once total" "$JMZ" m4

# --- M5: the turbo guard is dropped ------------------------------------------
# Every gated fix in this repo is turbo-only. Without IsModeTurbo the candidate
# would be live in normal games the moment it is armed on the farm.
m5() { perl -0pi -e "s/J.IsModeTurbo\(\) and J.IsSoakCandidate\( 'slotwait' \)/J.IsSoakCandidate( 'slotwait' )/" "$JMZ"; }
mutant "M5 the wrapper stops being turbo-only" "$JMZ" m5

# --- M6: the evaluation order is swapped -------------------------------------
# Un-armed the wrapper must be the shipped decision BYTE FOR BYTE, and the
# shipped consumer asked the item leg first.
m6() { perl -0pi -e 's/\treturn J.Utils.HasTeamMemberWithCriticalItemInCooldown\( vLocation, bSlotWait \)\n\t\tor J.Utils.HasTeamMemberWithCriticalSpellInCooldown\( vLocation, bSlotWait \)/\treturn J.Utils.HasTeamMemberWithCriticalSpellInCooldown( vLocation, bSlotWait )\n\t\tor J.Utils.HasTeamMemberWithCriticalItemInCooldown( vLocation, bSlotWait )/' "$JMZ"; }
mutant "M6 the wrapper swaps the shipped item/spell order" "$JMZ" m6

# --- M7: the consumer goes around the wrapper --------------------------------
# A second, ungated call site is the failure this whole shape exists to prevent
# -- and it is invisible to every outcome test, because on this corpus both
# routes answer FALSE.
m7() { perl -0pi -e 's/        if jmz.ShouldWaitForTeamCooldowns\(vLocation\) then\n            return true\n        end/        if jmz.Utils.HasTeamMemberWithCriticalItemInCooldown(vLocation) then\n            return true\n        end/' "$PUSH"; }
mutant "M7 the consumer calls the ungated predicate again" "$PUSH" m7

# --- M8: the mid/late-game guard is widened ----------------------------------
# A gated fix must not quietly widen the domain it is measured on.
m8() { perl -0pi -e 's/    if gameState.isMidGame or gameState.isLateGame then/    if true then/' "$PUSH"; }
mutant "M8 the mid/late-game guard is dropped" "$PUSH" m8

# --- M9: the TS source drifts from the Lua -----------------------------------
# bots/ is the deliverable and typescript/ is its source; a fix in one and not
# the other is a regression waiting for the next transpile.
m9() { perl -0pi -e 's/GetTeamMember\(bSlotWait \? i : playerId\)/GetTeamMember(playerId)/' "$TS"; }
mutant "M9 the TypeScript source loses the argument fix" "$TS" m9

echo
echo "mutants: $ncaught/$nrun CAUGHT"
[ "$ncaught" -eq "$nrun" ] || exit 1
