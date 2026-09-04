#!/usr/bin/env bash
# Mutation stand for tests/test_campbind_poke_target.lua
# (OWNER_PRIORITIES P1, soak candidate 'campbind', test_set.md §DY).
#
# WHAT IT IS FOR. Every leg of that test file passed on its FIRST run, which is
# exactly when an assertion is most likely to be measuring nothing: the fix is a
# few lines and the frame was chosen after the fact from a corpus sweep, so
# "green" is equally consistent with "the binding works" and with "the driver
# never reaches the line". Each mutant below is a way the fix could be broken or
# silently undone; a correct test file MUST go red on every one.
#
# The four shapes under test:
#   * the fix is REVERTED at the call site or inside the helper (M1, M2) -- the
#     unbound poke coming back is the whole defect;
#   * the LEASH drifts (M3, M4) -- 1200u is the desk's measured max drag, and a
#     wider one silently re-admits the neighbouring camp (DEEP and SHALLOW are
#     1533u apart, so 2000 makes the binding vacuous on this very frame);
#   * the GATE stops being a gate (M5, M6, M7) -- an id rename, a conjoined
#     gate (the 'pullcad' trap), or a turbo check that no longer holds;
#   * the HOLD is not a hold (M8) -- stamping campPullAttackTime on a frame that
#     poked nothing turns every later frame of the beat into a drag step, i.e.
#     the bot walks lane-ward away from a camp it never reached. That mutant is
#     invisible to a one-frame driver, which is why the beat-long leg exists.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every single mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_campbind.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation -- and per its converse, first read the diff
# and confirm the mutant landed where you think it did: a regex that misses
# prints NO-OP here, and a regex that hits the WRONG function prints SURVIVED
# while the fix is untouched, which is how mutstand_slotwait.sh's M2 lied once).
# No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
ROAM=bots/mode_roam_generic.lua
TEST=test_campbind_poke_target

TMP=$(mktemp -d)

nrun=0; ncaught=0

# INFLIGHT names the file that is mutated RIGHT NOW, or is empty when the tree
# is clean. Both targets here are SHIPPED bot Lua, so leaving one mutated is the
# expensive failure: it would ride a commit.
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

# GH #418's trap. `trap 'rm -rf "$TMP"' EXIT` is WORSE than no trap at all: on
# an interrupt it leaves the mutant in the working tree AND deletes $TMP, the
# only copy of the original. Restore first, remove the copies second.
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
        printf 'NO-OP     %-56s (the edit matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-56s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-56s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
        echo "            per its converse, first confirm the edit landed where you meant."
    fi
}

# --- M1: the call site goes back to the unbound poke -------------------------
# The defect itself, restored in one line. Anything green under this is not
# testing the fix at all.
m1() { perl -0pi -e 's/bot:Action_AttackUnit\(hPoke, true\)/bot:Action_AttackUnit(tNeut[1], true)/' "$ROAM"; }
mutant "M1 call site pokes tNeut[1] again" "$ROAM" m1

# --- M2: the helper stops binding and always answers the nearest -------------
# The other end of the same revert. The gate and the call site both still LOOK
# right; check_armed_wiring.py would still call the id WIRED.
m2() { perl -0pi -e 's/\n\treturn nil\nend\n(\n-- \[GH #5\])/\n\treturn hFirst\nend\n$1/' "$JMZ"; }
mutant "M2 helper falls back to tNeut[1] instead of nil" "$JMZ" m2

# --- M3: the leash widens past the gap between the two real camps ------------
# DEEP and SHALLOW are 1533u apart, so 2000 re-admits the rejected camp on the
# witness frame while every gate-plumbing assertion stays green.
m3() { perl -0pi -e 's/local PULL_CAMP_NEUTRAL_RANGE = 1200/local PULL_CAMP_NEUTRAL_RANGE = 2000/' "$JMZ"; }
mutant "M3 leash widened to 2000u" "$JMZ" m3

# --- M4: the leash tightens below the longest drag the desk measured ---------
# 1,170u is the maximum follower walk in GH #117's 165 episodes. A leash under
# it stops the cadence re-poking creeps it is already dragging -- the failure
# this constant's comment exists to prevent.
m4() { perl -0pi -e 's/local PULL_CAMP_NEUTRAL_RANGE = 1200/local PULL_CAMP_NEUTRAL_RANGE = 900/' "$JMZ"; }
mutant "M4 leash tightened to 900u (under the max drag)" "$JMZ" m4

# --- M5: the gate id is renamed ----------------------------------------------
# A rename makes the lever unarmable in every wave while the code reads fine.
# The verdict then comes back "tested, no effect" with nothing raising a hand.
m5() { perl -0pi -e "s/IsSoakCandidate\( 'campbind' \)/IsSoakCandidate( 'campbnid' )/" "$JMZ"; }
mutant "M5 gate id typo'd" "$JMZ" m5

# --- M6: the gate is conjoined with 'pullcamp' -------------------------------
# The 'pullcad' trap, verbatim: frozen FALSE the day 'pullcamp' is promoted,
# while the call site still exists and the wiring check still says WIRED.
m6() { perl -0pi -e "s/if not J\.IsSoakCandidate\( 'campbind' \) then return hFirst end/if not (J.IsSoakCandidate( 'campbind' ) and J.IsSoakCandidate( 'pullcamp' )) then return hFirst end/" "$JMZ"; }
mutant "M6 gate conjoined with pullcamp" "$JMZ" m6

# --- M7: the turbo half of the gate is deleted -------------------------------
# The lever must not reach normal-mode games. Structural at the one call site is
# not the same as absent from a public J.* helper.
m7() { perl -0pi -e 's/\tif not J\.IsModeTurbo\(\) then return hFirst end\n//' "$JMZ"; }
mutant "M7 turbo check removed from the helper" "$JMZ" m7

# --- M8: the poke clock is stamped on a frame that poked nothing -------------
# Invisible to a one-frame driver: the first frame still issues no order. From
# the second frame on the cadence falls through to the drag step and walks the
# bot lane-ward away from a camp it has not reached -- the approach is lost and
# nothing anywhere reports a pull that failed to start.
m8() { perl -0pi -e 's/\t\t\tif hPoke ~= nil then\n\t\t\t\tbot:Action_AttackUnit\(hPoke, true\)\n\t\t\t\tbot\.campPullAttackTime = now\n\t\t\tend/\t\t\tif hPoke ~= nil then\n\t\t\t\tbot:Action_AttackUnit(hPoke, true)\n\t\t\tend\n\t\t\tbot.campPullAttackTime = now/' "$ROAM"; }
mutant "M8 poke clock stamped without a poke" "$ROAM" m8

echo
echo "mutants: $nrun   caught: $ncaught"
[ "$ncaught" -eq "$nrun" ]
