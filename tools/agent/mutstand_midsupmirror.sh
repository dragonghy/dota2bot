#!/usr/bin/env bash
# Mutation stand for tests/test_midsupmirror_checkability.lua (test_set.md §EH).
#
# WHAT IT IS FOR. This round lands NO behaviour change: the whole product is a
# set of counts and the claim that four registered repairs are unwitnessable on
# the corpus. A census whose every headline is a ZERO is the easiest kind of
# green to get for the wrong reason -- a sweep that silently stops measuring
# reports the same zeros as a sweep that measured and found nothing, and a
# `pcall` with one bucket too few reports "no" for "could not tell". That is
# exactly the defect this file is ABOUT, so it is also the way this file itself
# would fail. Hence a stand whose mutants are mostly INSTRUMENT mutants.
#
# The shapes under test:
#   * the blocker is REMOVED (M1, M2) -- the mock gains extrapolation, or gains
#     a real active mode. These are the day the finding expires; the test must
#     go red and say "price it again" rather than stay quietly green;
#   * a leg gets REPAIRED into the mirror (M3, M4) -- the §EF.7 follow-up
#     actually being taken, which must lower the registered 4;
#   * a leg leaves the responder LOOP (M5) -- then the mirror is not short it
#     any more and the whole pricing is stale;
#   * a threshold the pricing is stated in terms of drifts (M6, M7, M8);
#   * the CENSUS loses a bucket (M9, M10, M11) -- the three-valued read folded
#     back to two, the censored frames stopping being named, the domain
#     classifier drifting off the guard's own radius;
#   * the census's shadow drifts from the shipped tree (M12) -- the mutant that
#     makes a census measure only itself.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_midsupmirror.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (rule 2: suspect the
# assertion before the mutation -- and per its converse, read the diff first: a
# regex that misses prints NO-OP, a regex that hits the wrong place prints
# SURVIVED while the subject is untouched). No AWS, no network.
#
# SLOW ON PURPOSE: every mutant re-runs a 109-fixture sweep (~31s), so the stand
# takes ~7 minutes. The sweep is the thing under test; running it once and
# reusing the output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
SWEEP=tests/_midsupmirror_sweep.lua
MOCK=tests/mock/replay_fixture.lua
TEST=test_midsupmirror_checkability

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
    lua5.1 tests/run_tests.lua "$TEST" > "$TMP/$TEST.log" 2>&1 || rc=$?
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

# --- M1: the mock gains extrapolation ----------------------------------------
# THE mutant: this is the day the blocker is removed. The interrupt guard stops
# raising, starts answering, and every number in the pricing has to be retaken.
# A file that stays green here is a finding that will outlive its own premise.
m1() { perl -0pi -e 's/\n            GetLocation = loc,/\n            GetLocation = loc,\n            GetExtrapolatedLocation = loc,/' "$MOCK"; }
mutant "M1 mock stubs GetExtrapolatedLocation (blocker removed)" "$MOCK" m1

# --- M2: the mock gains a real active mode -----------------------------------
# The other absence leg expiring. GetActiveMode is the only thing
# J.IsGoingOnSomeone reads, so a non-default answer makes that leg witnessable.
m2() { perl -0pi -e 's/\n            GetLocation = loc,/\n            GetLocation = loc,\n            GetActiveMode = 5,/' "$MOCK"; }
mutant "M2 mock answers a real active mode (BOT_MODE_ROAM)" "$MOCK" m2

# --- M3: the IsGoingOnSomeone leg is repaired into the mirror ----------------
# The §EF.7 follow-up actually taken. Registered-4 must fall to 3 and this file
# must say so -- otherwise the count silently drifts and the next round reprices
# a mirror that is no longer short what the comment says it is short.
m3() { perl -0pi -e 's/\t\tand not J\.IsRetreating\( hAlly \)\n\t\tand GetUnitToUnitDistance\( hAlly, hBuilding \)/\t\tand not J.IsRetreating( hAlly )\n\t\tand not J.IsGoingOnSomeone( hAlly )\n\t\tand GetUnitToUnitDistance( hAlly, hBuilding )/' "$JMZ"; }
mutant "M3 mirror repairs the IsGoingOnSomeone leg" "$JMZ" m3

# --- M4: the interrupt leg is repaired into the mirror -----------------------
# The one repair that would ALSO break the instrument: adding it makes the
# predicate inherit the raise on every in-domain frame.
m4() { perl -0pi -e 's/\t\tand not J\.IsRetreating\( hAlly \)\n\t\tand GetUnitToUnitDistance\( hAlly, hBuilding \)/\t\tand not J.IsRetreating( hAlly )\n\t\tand not J.CanEnemyInterruptTpChannel( hAlly )\n\t\tand GetUnitToUnitDistance( hAlly, hBuilding )/' "$JMZ"; }
mutant "M4 mirror repairs the interrupt leg (inherits the raise)" "$JMZ" m4

# --- M5: a leg leaves the responder loop -------------------------------------
# "The mirror is short four" is a statement about a DIFFERENCE. Deleting the
# clause from the loop makes it false from the other side, and a pricing that
# only looked at the mirror would not notice.
m5() { perl -0pi -e 's/\tif J\.IsGoingOnSomeone\( bot \) then return nil end\n//' "$JMZ"; }
mutant "M5 responder loop drops its own IsGoingOnSomeone gate" "$JMZ" m5

# --- M6, M7, M8: the thresholds the pricing is stated in terms of ------------
# Each number is quoted in the finding ("inside the 700 scan", "the 15s window",
# "the 45s memory"); if one moves under the text, the text is measuring a world
# that no longer exists.
m6() { perl -0pi -e 's/bWide and 1200 or 700/bWide and 1200 or 1100/' "$JMZ"; }
mutant "M6 interrupt narrow scan drifts 700 -> 1100" "$JMZ" m6
# M7's anchor is not decoration. The 15s window is written IDENTICALLY in two
# functions (J.GetRescueTpTarget first, J.ShouldTpSupportTowerFight second), and
# `perl -0pi -e s///` without /g replaces the FIRST one -- so the unanchored
# version of this mutant edited a function this file does not measure, ran green,
# and printed SURVIVED while the threshold under test was never touched. That is
# the converse of evidence-discipline rule 2 caught live: a SURVIVED is a claim
# about the assertion only once the edit is shown to have landed where meant.
# And the FIRST anchor tried was `watched 230652`, which is written above BOTH
# copies -- so the non-greedy reach from its first occurrence still landed on the
# rescue-TP copy, and the mutant printed SURVIVED a second time for the same
# reason. `see GetRescueTpTarget` is the text that belongs to the responder
# loop's copy alone. Two rounds of the same mistake is why the rule is "confirm
# the edit landed", not "pick a plausible anchor".
m7() { perl -0pi -e 's/(see GetRescueTpTarget.*?lastRespawnTime or -999 \) < )15\.0/${1}20.0/s' "$JMZ"; }
mutant "M7 fresh-respawn window drifts 15s -> 20s" "$JMZ" m7
m8() { perl -0pi -e 's/(bot\.lastFrontAnswerT < )45\.0/${1}60.0/' "$JMZ"; }
mutant "M8 repeat-front memory drifts 45s -> 60s" "$JMZ" m8

# --- M9: the census folds three buckets back into two ------------------------
# The defect this round FOUND, reintroduced into the instrument that found it: a
# raise scored as "did not fire". The censored count collapses to zero and the
# domain reads clean.
m9() { perl -0pi -e "s/\n                        bump\('trigger_raised'\)/\n                        local _ = 0/" "$SWEEP"; }
mutant "M9 census stops counting trigger raises (the old two-bucket read)" "$SWEEP" m9

# --- M10: the censored frames stop being named -------------------------------
# A count with no roster cannot be audited; the test requires the two to agree.
m10() { perl -0pi -e "s/\n                        out:write\(string\.format\('X %s %s\\\\n',/\n                        if false then out:write(string.format('X %s %s\\\\n',/" "$SWEEP"; }
mutant "M10 census counts censored frames but stops naming them" "$SWEEP" m10

# --- M11: the domain classifier drifts off the guard's own radius ------------
# "It raises on 257/257 of the frames where it has anything to say" is only a
# finding if `has anything to say` is the guard's OWN early-return condition.
# Widen the classifier and the ratio silently stops being that claim.
m11() { perl -0pi -e 's/pcall\(J\.GetNearbyHeroes, bot, G\.INT_R or 700,/pcall(J.GetNearbyHeroes, bot, 1600,/' "$SWEEP"; }
mutant "M11 census classifies the guard domain with the wrong radius" "$SWEEP" m11

# --- M12: the census's shadow drifts from the shipped predicate --------------
# The shadow exists so accepted supports can be NAMED; the moment it stops
# agreeing with J.HasAvailableSupportResponder the census measures only itself.
m12() { perl -0pi -e 's/\n *and GetUnitToUnitDistance\(hAlly, building\)\n *> J\.TP_RESPONSE_FAR_FLOOR then/ then/' "$SWEEP"; }
mutant "M12 census shadow drops the pairing clause" "$SWEEP" m12

echo
echo "mutants: $nrun   caught: $ncaught"
[ "$ncaught" -eq "$nrun" ]
