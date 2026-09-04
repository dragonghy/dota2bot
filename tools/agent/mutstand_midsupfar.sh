#!/usr/bin/env bash
# Mutation stand for the 'midsupfar' repair inside soak candidate 'midsupyield'
# (tests/test_midsupfar_yield_target.lua + tests/test_midsupyield_core_yields.lua,
# test_set.md §EE).
#
# WHAT IT IS FOR. The repair is ONE conjunct and a parameter, and the frame that
# motivates it was found by a corpus sweep after the fact -- so "green" is
# equally consistent with "the pairing clause is doing the work" and with "the
# driver never reaches it". Worse, this fix has a direction that makes a dead
# predicate look like a success: the fix REMOVES yields, so a predicate that
# answers false everywhere passes every negative assertion. That is why the two
# test files are run TOGETHER here -- the load-bearing half is the positive
# control (the death_prophet frame must STILL yield), and it lives in both.
#
# The shapes under test:
#   * the repair is REVERTED (M1, M2) -- either end of it;
#   * the FLOOR drifts (M3, M4, M5) -- a second literal in the predicate, the
#     shared constant moving, or the comparison flipping. 655 vs 3500 is the
#     whole finding, so any of these silently re-admits the drop;
#   * the pairing clause asks about the WRONG UNIT (M11) -- the near-miss
#     version of this very fix, and the shape the defect it repairs is made of
#     (campbind, GH #475: a downstream read of the wrong handle);
#   * the unaskable case stops failing toward shipped (M6);
#   * the GATE stops being a gate (M7, M8, M10) -- an id rename, the 'pullcad'
#     conjoined-gate trap, or the core-only clause going away;
#   * the SINGLE-SOURCE property is undone (M9) -- behaviourally a no-op today,
#     and deliberately a mutant anyway: two copies of 3500 are exactly the drift
#     that produced the defect, so the property is asserted, not assumed.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every single mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_midsupfar.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation -- and per its converse, first read the diff
# and confirm the mutant landed where you think it did: a regex that misses
# prints NO-OP here, and a regex that hits the WRONG function prints SURVIVED
# while the fix is untouched). No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
TESTS=(test_midsupfar_yield_target test_midsupyield_core_yields)

TMP=$(mktemp -d)

nrun=0; ncaught=0

# INFLIGHT names the file that is mutated RIGHT NOW, or is empty when the tree
# is clean. The target is SHIPPED bot Lua, so leaving it mutated is the
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

# Run BOTH test files and report the FIRST non-zero exit code (rule 3: never
# through a pipe). A mutant caught by either file is caught.
run_test() {
    local rc=0 t
    for t in "${TESTS[@]}"; do
        lua5.1 tests/run_tests.lua "$t" > "$TMP/$t.log" 2>&1 || rc=$?
        [ "$rc" -ne 0 ] && break
    done
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
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
        echo "            per its converse, first confirm the edit landed where you meant."
    fi
}

# --- M1: the call site stops naming the tower --------------------------------
# The defect itself, restored in one character group. Note the direction: with
# the nil guard in place this makes the yield NEVER fire, so every "armed does
# not yield" assertion still passes. Only the positive control catches it.
m1() { perl -0pi -e 's/J\.HasAvailableSupportResponder\( bot, building \)/J.HasAvailableSupportResponder( bot )/' "$JMZ"; }
mutant "M1 call site drops the building argument" "$JMZ" m1

# --- M2: the pairing clause is deleted from the predicate --------------------
# The other end of the same revert: the parameter is still passed and the call
# site still reads right, but the mirror is short its member again and the drop
# comes back.
m2() { perl -0pi -e 's/\t\tand GetUnitToUnitDistance\( hAlly, hBuilding \) > J\.TP_RESPONSE_FAR_FLOOR\n//' "$JMZ"; }
mutant "M2 pairing clause removed from the predicate" "$JMZ" m2

# --- M3: the predicate grows its own second floor ----------------------------
# 655 is the distance in the finding, so a floor of 500 accepts the support that
# cannot take the response while the responder loop keeps using 3500.
m3() { perl -0pi -e 's/and GetUnitToUnitDistance\( hAlly, hBuilding \) > J\.TP_RESPONSE_FAR_FLOOR/and GetUnitToUnitDistance( hAlly, hBuilding ) > 500/' "$JMZ"; }
mutant "M3 predicate uses its own literal floor (500)" "$JMZ" m3

# --- M4: the shared constant drifts under the finding ------------------------
# Both sites move together, so nothing looks inconsistent -- and the drop frame
# silently becomes a yield again.
m4() { perl -0pi -e 's/J\.TP_RESPONSE_FAR_FLOOR = 3500/J.TP_RESPONSE_FAR_FLOOR = 300/' "$JMZ"; }
mutant "M4 shared far floor drifts to 300" "$JMZ" m4

# --- M5: the comparison flips ------------------------------------------------
# Reads almost identically and inverts the whole clause: only supports ALREADY
# at the tower would be accepted as the ones who can TP to it.
m5() { perl -0pi -e 's/and GetUnitToUnitDistance\( hAlly, hBuilding \) > J\.TP_RESPONSE_FAR_FLOOR/and GetUnitToUnitDistance( hAlly, hBuilding ) < J.TP_RESPONSE_FAR_FLOOR/' "$JMZ"; }
mutant "M5 pairing comparison flipped to <" "$JMZ" m5

# --- M6: the unaskable case stops failing toward shipped ---------------------
# Without the guard a nil building reaches GetUnitToUnitDistance. The point of
# the guard is the POLARITY, not the crash: a caller that cannot name the tower
# must not be able to produce a yield.
m6() { perl -0pi -e 's/\tif hBuilding == nil then return false end\n//' "$JMZ"; }
mutant "M6 nil-building guard removed" "$JMZ" m6

# --- M7: the gate id is renamed ----------------------------------------------
# A rename makes the lever unarmable in every wave while the code reads fine.
# The verdict then comes back "tested, no effect" with nothing raising a hand.
m7() { perl -0pi -e "s/J\.IsSoakCandidate\( 'midsupyield' \)/J.IsSoakCandidate( 'midsupyeild' )/" "$JMZ"; }
mutant "M7 gate id typo'd" "$JMZ" m7

# --- M8: the gate is conjoined with a second soak id -------------------------
# The 'pullcad' trap, verbatim -- and the exact shape this round DECLINED to
# write. Frozen FALSE the day either id is promoted, while the call site still
# exists and check_armed_wiring.py still says WIRED.
m8() { perl -0pi -e "s/and not \( J\.IsSoakCandidate\( 'midsupyield' \)/and not ( J.IsSoakCandidate( 'midsupyield' ) and J.IsSoakCandidate( 'midsupfar' )/" "$JMZ"; }
mutant "M8 gate conjoined with a second id (pullcad trap)" "$JMZ" m8

# --- M9: the single-source property is undone --------------------------------
# Behaviourally a no-op TODAY, and a mutant on purpose: the defect being
# repaired is a mirror that drifted out of sync with this loop, so a re-inlined
# literal is the first step of the next drift. The [source] leg must object.
m9() { perl -0pi -e 's/and GetUnitToUnitDistance\( bot, building \) > J\.TP_RESPONSE_FAR_FLOOR/and GetUnitToUnitDistance( bot, building ) > 3500/' "$JMZ"; }
mutant "M9 responder loop re-inlines the literal 3500" "$JMZ" m9

# --- M10: the core-only clause goes away -------------------------------------
# Supports would then yield to each other -- the arbitration eats its own
# recipients. Caught by the core-only monkeypatch leg in the older file.
m10() { perl -0pi -e 's/\t\t\t\t\tand J\.IsCore\( bot \)\n//' "$JMZ"; }
mutant "M10 core-only clause removed from the yield" "$JMZ" m10

# --- M11: the clause asks about the WRONG UNIT -------------------------------
# The near-miss version of this fix, and the shape of the defect it repairs: the
# core is beyond the floor BY CONSTRUCTION (the responder loop already required
# it), so measuring `bot` makes the clause a tautology and the drop returns --
# with a diff that reads exactly like the fix.
m11() { perl -0pi -e 's/and GetUnitToUnitDistance\( hAlly, hBuilding \) > J\.TP_RESPONSE_FAR_FLOOR/and GetUnitToUnitDistance( bot, hBuilding ) > J.TP_RESPONSE_FAR_FLOOR/' "$JMZ"; }
mutant "M11 pairing clause measures the core, not the ally" "$JMZ" m11

echo
echo "mutants: $nrun   caught: $ncaught"
[ "$ncaught" -eq "$nrun" ]
