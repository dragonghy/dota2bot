#!/usr/bin/env bash
# Mutation stand for tests/test_outcommit_channel_hold.lua (test_set.md §EV,
# GH #511 handoff 乙).
#
# WHAT IT IS FOR. This round lands a BEHAVIOUR change -- the first one in the
# outpost family -- so the thing most worth attacking is the pair of claims the
# test file makes about it: (a) armed, the bid on the pinned frame becomes
# BOT_MODE_DESIRE_VERYHIGH; (b) disarmed, out of turbo, without a live channel,
# or without the capture modifier, the bid is byte-identical to the shipped
# distance remap. Claim (b) is four separate "nothing happened" readings, and a
# "nothing happened" is exactly what a probe that is simply not reaching the
# code also reports. So half the mutants below aim at the instrument.
#
# The shapes under test:
#   * THE LEVER STOPS EXISTING (M1) -- the gated block is deleted. The one
#     assertion whose failure means the fix is gone;
#   * THE GATE STOPS GATING (M2, M3, M7) -- turbo drops out of the conjunction,
#     the id is replaced by a neighbouring one, or a second arming point
#     appears. Each of these ships behaviour that is supposed to be dark;
#   * A CONJUNCT LEAVES (M4, M5) -- `bot:IsChanneling()` or the outpost's
#     capture modifier. Both keep the armed frame passing while widening the
#     lever onto frames it has no evidence for; they are caught only by the
#     two controls, which is the whole reason those controls exist;
#   * THE RAISE STOPS CLEARING THE BID IT IS ABOUT (M6) -- the return value
#     drops to BOT_ACTION_DESIRE_HIGH. The number still changes on the armed
#     frame relative to the remap, so a test that only asserted "armed !=
#     shipped" would pass a lever that cannot win the arbitration it was
#     written for;
#   * THE LEVER MOVES ABOVE A VETO (M8) -- ordering, not presence. A gate that
#     sits above the in-vision abort can pin a bot inside a fight, and the file
#     still reads clean to a grep;
#   * THE #511 PREMISE LEAVES (M9, M10) -- J.CanNotUseAction loses its
#     IsChanneling disjunct, or #511's literal one-liner lands in Think(). The
#     first turns the rejected one-liner into a real fix and must raise a hand
#     in the file that says it is redundant; the second is the no-op this whole
#     line of work exists to keep out of the tree;
#   * THE CORPUS IS REPLACED BY A CONVENIENT ONE (M11, M12) -- the pinned
#     frame's capture modifier is stripped, or the subject is moved away from
#     the outpost. The frame is the subject; a stand that passes on a frame
#     that no longer shows the situation is testing its own defaults;
#   * THE CONTROL STOPS CONTROLLING (M13) -- the injected outpost handle stops
#     delegating and answers `true` to every HasModifier. Both "no modifier"
#     readings then become vacuous while still printing as passes.
#
# Two CONTROLS (must NOT fire) close the converse hazard: a comment carrying
# the gate's own tokens must not satisfy the source census (that is what
# codeOnly is for), and an ordinary comment must not move any verdict.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, verified with `sha256sum -c` after every mutant (evidence-discipline
# rule 1: `git checkout --` would silently discard the uncommitted work that is
# the whole subject here).
#
#   bash tools/agent/mutstand_outcommit.sh
#
# Exit 0 = every mutant CAUGHT and every control quiet. Exit 1 = a mutant
# SURVIVED (rule 2: suspect the ASSERTION before the mutation -- and per its
# converse, confirm the edit landed where you meant: a regex that matches
# nothing prints NO-OP, a regex that matches the wrong place prints SURVIVED
# while the subject is untouched).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MODE=bots/mode_outpost_generic.lua
JMZ=bots/FunLib/jmz_func.lua
TESTF=tests/test_outcommit_channel_hold.lua
FX_CHAN=tests/fixtures/outchan/f_260905_010205_luna_channel.lua
FX_PRE=tests/fixtures/outchan/f_260905_010205_luna_precast.lua

TMP=$(mktemp -d)
nrun=0; ncaught=0
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
    lua5.1 tests/run_tests.lua outcommit_channel_hold > "$TMP/out.log" 2>&1 || rc=$?
    # A Lua error is a CAUGHT, but it must not be mistaken for an assertion
    # firing: name it so the reader can tell the two apart.
    if grep -q 'stack traceback' "$TMP/out.log"; then
        echo "${rc}T"
        return
    fi
    echo "$rc"
}

mutant() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-58s (the edit matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" != "0" ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
        echo "            per its converse, first confirm the edit landed where you meant."
    fi
}

# A control, not a mutant: an edit that MUST NOT move the verdict. It counts
# toward the tally only when it behaves -- an assertion that fires on a benign
# comment is a false-alarm generator, and this is where that shows up.
mutant_expect_pass() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-58s (the edit matched nothing)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" = "0" ]; then
        ncaught=$((ncaught + 1))
        printf 'CONTROL   %-58s exit=%s (correctly did not fire)\n' "$label" "$rc"
    else
        printf 'FALSE-RED %-58s exit=%s\n' "$label" "$rc"
        echo "          ^ a benign comment moved the verdict: the assertion is"
        echo "            reading prose, not code."
    fi
}

echo "=== mutants against the tree (the behaviour change itself) ==="

# --- M1: the lever is gone ----------------------------------------------------
m1() {
    perl -0pi -e "s/\t\tif J\.IsModeTurbo\(\) and J\.IsSoakCandidate\('outcommit'\)\n\t\tand bot:IsChanneling\(\)\n\t\tand ClosestOutpost:HasModifier\('modifier_watch_tower_capturing'\)\n\t\tthen\n\t\t\treturn BOT_MODE_DESIRE_VERYHIGH\n\t\tend\n\n//" "$MODE"
}
mutant "M1 the gated block is deleted" "$MODE" m1

# --- M2: the gate stops being turbo-only --------------------------------------
m2() { perl -0pi -e "s/if J\.IsModeTurbo\(\) and J\.IsSoakCandidate\('outcommit'\)/if J.IsSoakCandidate('outcommit')/" "$MODE"; }
mutant "M2 the turbo conjunct leaves the gate" "$MODE" m2

# --- M3: the gate ignores the armed string ------------------------------------
m3() { perl -0pi -e "s/J\.IsModeTurbo\(\) and J\.IsSoakCandidate\('outcommit'\)/J.IsModeTurbo()/" "$MODE"; }
mutant "M3 the soak id leaves the gate (ships dark behaviour)" "$MODE" m3

# --- M4, M5: a conjunct leaves, widening the lever ----------------------------
m4() { perl -0pi -e "s/\t\tand bot:IsChanneling\(\)\n//" "$MODE"; }
mutant "M4 the IsChanneling conjunct leaves" "$MODE" m4

m5() { perl -0pi -e "s/\t\tand ClosestOutpost:HasModifier\('modifier_watch_tower_capturing'\)\n//" "$MODE"; }
mutant "M5 the capture-modifier conjunct leaves" "$MODE" m5

# --- M6: the raise no longer clears the bid it is about -----------------------
# The armed number still differs from the shipped remap, so a test asserting
# only "armed != shipped" passes a lever that cannot win its arbitration.
m6() { perl -0pi -e 's/\t\t\treturn BOT_MODE_DESIRE_VERYHIGH\n/\t\t\treturn BOT_ACTION_DESIRE_HIGH\n/' "$MODE"; }
mutant "M6 the raise drops to 0.75 (below farm's ceiling)" "$MODE" m6

# --- M7: a second arming point ------------------------------------------------
m7() { perl -0pi -e "s/(\t\tand bot:IsChanneling\(\)\n)/\$1\t\tand not J.IsSoakCandidate('outcommit')\n/" "$MODE"; }
mutant "M7 a second arming point for the same id appears" "$MODE" m7

# --- M8: the lever moves above a veto -----------------------------------------
# Presence unchanged, order wrong: the block now runs before the in-vision
# abort, so an armed bot can be pinned inside a fight.
m8() {
    perl -0pi -e "s/\t\tif J\.IsModeTurbo\(\) and J\.IsSoakCandidate\('outcommit'\)\n\t\tand bot:IsChanneling\(\)\n\t\tand ClosestOutpost:HasModifier\('modifier_watch_tower_capturing'\)\n\t\tthen\n\t\t\treturn BOT_MODE_DESIRE_VERYHIGH\n\t\tend\n\n//" "$MODE"
    perl -0pi -e "s/(\tif not IsEnemyTier2Down then return BOT_ACTION_DESIRE_NONE end\n)/\$1\n\tif J.IsModeTurbo() and J.IsSoakCandidate('outcommit')\n\tand bot:IsChanneling()\n\tand ClosestOutpost ~= nil and ClosestOutpost:HasModifier('modifier_watch_tower_capturing')\n\tthen\n\t\treturn BOT_MODE_DESIRE_VERYHIGH\n\tend\n/" "$MODE"
}
mutant "M8 the lever moves above the shipped vetoes" "$MODE" m8

echo
echo "=== mutants against the premise this lever replaced (GH #511's own fix) ==="

# --- M9: the premise that makes #511's one-liner redundant leaves -------------
m9() { perl -0pi -e 's/\t\t\tor bot:IsChanneling\(\)\n//' "$JMZ"; }
mutant "M9 J.CanNotUseAction loses its IsChanneling disjunct" "$JMZ" m9

# --- M10: the no-op lands anyway ----------------------------------------------
m10() { perl -0pi -e 's/(function Think\(\)\n)/$1\tif bot:IsChanneling\(\) then return end\n/' "$MODE"; }
mutant "M10 #511's redundant guard is added to Think()" "$MODE" m10

echo
echo "=== mutants against the instrument (how a 'nothing happened' gets forged) ==="

# --- M11, M12: the pinned frame stops showing the situation -------------------
m11() { perl -0pi -e "s/\n      modifiers = \{ \{ name = 'modifier_watch_tower_capturing'[^\n]*\n//" "$FX_CHAN"; }
mutant "M11 the pinned frame loses its capture modifier" "$FX_CHAN" m11

m12() { perl -0pi -e "s/(name = 'npc_dota_hero_luna', team = 2, x = )3433\.3, y = -581\.8/\${1}-9000.0, y = 9000.0/" "$FX_CHAN"; }
mutant "M12 the subject is moved away from the outpost" "$FX_CHAN" m12

# --- M13: the injected handle stops delegating --------------------------------
# Then "this frame carries no capture modifier" is answered by the proxy's own
# opinion, and both no-modifier readings become vacuous passes.
m13() { perl -0pi -e "s/HasModifier    = function\(_, s\) return u:HasModifier\(s\) end,/HasModifier    = true,/" "$TESTF"; }
mutant "M13 the injected outpost stops delegating HasModifier" "$TESTF" m13

# --- M14: the control frame stops reaching the code it controls ---------------
# THIS IS THE MUTANT THIS STAND WAS ALREADY WRONG ABOUT ONCE. The file's first
# anti-vacuum control (t=1364.5) never reached the lever -- the mode returned
# NONE five clauses earlier -- so "arming changed nothing" was true for a reason
# that had nothing to do with the capture modifier, and M5 SURVIVED. Moving the
# subject away on the CONTROL frame reproduces exactly that state, and the
# non-vacuity assertion added to [frame F5] is what must now fire.
m14() { perl -0pi -e "s/(name = 'npc_dota_hero_luna', team = 2, x = )3474\.5, y = -715\.5/\${1}-9000.0, y = 9000.0/" "$FX_PRE"; }
mutant "M14 the CONTROL frame no longer reaches the lever" "$FX_PRE" m14

echo
echo "=== controls (must NOT fire) ==="

# --- C1: the gate's own tokens, in a comment ----------------------------------
# This is what codeOnly() is for. Without it the source census counts the
# sentence explaining the gate as a second arming point.
c1() {
    perl -0pi -e "s/(function GetDesire\(\)\n)/\t-- see J.IsSoakCandidate('outcommit') and J.IsModeTurbo() below\n\$1/" "$MODE"
}
mutant_expect_pass "C1 a comment carrying the gate's own tokens" "$MODE" c1

# --- C2: an ordinary comment --------------------------------------------------
c2() { perl -0pi -e "s/(function OnStart\(\)\n)/\t-- nothing to set up here\n\$1/" "$MODE"; }
mutant_expect_pass "C2 an ordinary comment elsewhere in the file" "$MODE" c2

echo
echo "=== $ncaught / $nrun as declared ==="
[ "$ncaught" = "$nrun" ] || exit 1
