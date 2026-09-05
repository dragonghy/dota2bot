#!/usr/bin/env bash
# Mutation stand for tests/test_midsupint_mirror_interrupt.lua (test_set.md §EN).
#
# WHAT IT IS FOR. This round lands a BEHAVIOUR change -- one conjunct in
# J.HasAvailableSupportResponder -- and the case for it is a comparison between
# the shipped tree and a PRE-REPAIR SHADOW that the tree can no longer produce
# (the repair carries no soak id; see the source note). A shadow comparison is
# the most forgeable evidence this stream produces: make the two legs the same
# and the flip count is 0, make them differ in the wrong place and the flip
# count is about something other than the repair. So most mutants here attack
# the INSTRUMENT, and the ones that attack the tree attack it in the two
# directions that would still look like a fix.
#
# The shapes under test:
#   * THE REPAIR LEAVES OR INVERTS (M1, M2) -- the conjunct is deleted, or lands
#     un-negated. M2 is the dangerous one: it still reads like the repair, still
#     compiles, and reverses which supports are accepted;
#   * THE PULLCAD TRAP (M3) -- a soak id appears inside the predicate. Its only
#     call site is already gated by 'midsupyield', so an id here makes the live
#     condition a two-id conjunction that freezes FALSE the day either is
#     promoted -- while check_armed_wiring.py still calls it WIRED, because it
#     checks that a call site exists, not that the predicate can be true;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M4) -- strip_comments is
#     removed from the sweep. Then MIRROR_SOAKID is satisfied by the repair's own
#     comment, which names IsSoakCandidate in an explanation of why there is not
#     one. This is not hypothetical: it read 1 off that comment on the first run
#     of this sweep, and M4 is that bug re-committed;
#   * THE TWO SHADOW LEGS COLLAPSE INTO ONE (M5, M6) -- the pre-repair leg gains
#     the conjunct (flips -> 0, the repair reads as a no-op) or the repaired leg
#     loses it (the anti-drift check is measuring the shadow against itself);
#   * THE CENSORING COMES BACK (M7, M8) -- the mock loses GetExtrapolatedLocation
#     and the guard raises again. THE dangerous direction, because a raise folds
#     into the "not interrupted" bucket: the corpus shrinks and every count below
#     it stays plausible. This is GH #492's defect re-committed;
#   * THE SUBSUMPTION CONTROL STOPS CONTROLLING (M9) -- the "already blocked by
#     IsInTeamFight" column is the live alternative explanation for the whole
#     finding. Break its bookkeeping and "not subsumed" is asserted against a
#     number that no longer means that;
#   * THE FRAME EVIDENCE LOSES ITS CAUSE (M10, M11) -- the named-ally probe stops
#     naming, or the pre-repair helper silently applies the conjunct so the
#     witnessed frame reports "nobody was offered" instead of "exactly the wrong
#     one was offered";
#   * A CONSTANT MOVES UNDER THE CENSUS (M12) -- the far floor changes, so every
#     ratcheted count is about a different domain than the one reported.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_midsupint.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (rule 2: suspect the
# assertion before the mutation -- and per its converse, read the diff first: a
# regex that misses prints NO-OP, a regex that hits the wrong place prints
# SURVIVED while the subject is untouched; that converse cost the midsupmirror
# stand two rounds on one `perl s///` without /g).
#
# SLOW ON PURPOSE: every mutant re-runs a 109-fixture, 7048-pair sweep, so the
# stand takes several minutes. The sweep is the thing under test; running it
# once and reusing the output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
SWEEP=tests/_midsupint_sweep.lua
MOCK=tests/mock/replay_fixture.lua
TESTF=tests/test_midsupint_mirror_interrupt.lua
TEST=test_midsupint_mirror_interrupt

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

# --- M1, M2: the repair leaves, or lands inverted ----------------------------
m1() { perl -0pi -e 's/\t\tand not J\.CanEnemyInterruptTpChannel\( hAlly \)\n//' "$JMZ"; }
mutant "M1 the conjunct is deleted from the predicate" "$JMZ" m1

# The reviewable-looking inversion: same call, same place, no `not`.
m2() { perl -0pi -e 's/\t\tand not J\.CanEnemyInterruptTpChannel\( hAlly \)/\t\tand J.CanEnemyInterruptTpChannel( hAlly )/' "$JMZ"; }
mutant "M2 the conjunct lands un-negated (accepts only the doomed)" "$JMZ" m2

# --- M3: the pullcad trap ----------------------------------------------------
m3() { perl -0pi -e "s/\t\tand not J\.CanEnemyInterruptTpChannel\( hAlly \)/\t\tand ( not J.IsSoakCandidate( 'midsupint' ) or not J.CanEnemyInterruptTpChannel( hAlly ) )/" "$JMZ"; }
mutant "M3 a soak id appears inside the predicate" "$JMZ" m3

# --- M4: the instrument reads prose instead of code --------------------------
# Caught once already, for real, on this sweep's first run.
m4() { perl -0pi -e 's/local mirror = strip_comments\(\n    block\(src, .function J\.HasAvailableSupportResponder\( bot, hBuilding \).\)\)/local mirror = block(src, "function J.HasAvailableSupportResponder( bot, hBuilding )")/' "$SWEEP"; }
mutant "M4 the sweep stops stripping comments before parsing" "$SWEEP" m4

# --- M5, M6: the two shadow legs collapse into one ---------------------------
# M5: the pre-repair leg silently gains the conjunct. flips -> 0, and the round's
# whole claim ("this changes 151 decisions") becomes "this is a no-op" -- which
# is the droppick/slotarb shape, reported in the safe-looking direction.
m5() { perl -0pi -e 's/local pre = shadow\(J, bot, b, tP, false\)/local pre = shadow(J, bot, b, tP, true)/' "$SWEEP"; }
mutant "M5 the pre-repair shadow leg gains the conjunct" "$SWEEP" m5

# M6: the repaired leg loses it, so the anti-drift check compares the shadow
# with a tree it no longer mirrors -- and shipped_disagrees is the only witness.
m6() { perl -0pi -e 's/local rep, sRej = shadow\(J, bot, b, tP, true\)/local rep, sRej = shadow(J, bot, b, tP, false)/' "$SWEEP"; }
mutant "M6 the repaired shadow leg loses the conjunct" "$SWEEP" m6

# --- M7, M8: the censoring comes back ----------------------------------------
# GH #492's defect, re-committed in the mock this file's counts rest on. A raise
# lands in the "not interrupted" bucket, so the corpus silently shrinks.
m7() { perl -0pi -e 's/GetExtrapolatedLocation/GetExtrapolatedLocationXX/g' "$MOCK"; }
mutant "M7 the mock loses GetExtrapolatedLocation entirely" "$MOCK" m7

# The subtler half: it answers, but answers a scalar again -- which is exactly
# what it did before the repair, and what made the guard index a number.
m8() { perl -0pi -e 's/            GetExtrapolatedLocation = function\(self, _fTimeInFuture\)\n                return self:GetLocation\(\)\n            end,/            GetExtrapolatedLocation = function(self, _fTimeInFuture)\n                return 0\n            end,/' "$MOCK"; }
mutant "M8 GetExtrapolatedLocation answers a scalar again" "$MOCK" m8

# --- M9: the subsumption control stops controlling ---------------------------
# "Not subsumed by the fight leg" is the finding's live alternative explanation.
# Move a guard-true ally into the wrong column and the comparison still runs,
# still produces two numbers, and no longer means what it is asserted to mean.
m9() { perl -0pi -e 's/                                elseif oki and itp then\n                                    bump\(.blocked_fight_int_true.\)/                                elseif oki and itp then\n                                    bump("cand_int_true")/' "$SWEEP"; }
mutant "M9 guard-true allies blocked upstream land in the wrong column" "$SWEEP" m9

# --- M10, M11: the frame evidence loses its cause ----------------------------
# M10: the sweep stops naming which ally it rejected, so the hand-picked frame
# and the census can no longer be shown to be about the same support.
m10() { perl -0pi -e 's/^(\s*)sRejected = hAlly:GetUnitName\(\)$/$1sRejected = nil/m' "$SWEEP"; }
mutant "M10 the sweep stops naming the rejected support" "$SWEEP" m10

# M11: the test's own pre-repair helper silently applies the conjunct. The
# witnessed frame then reports "no support was on offer" -- true of the repaired
# tree, and it would quietly delete the finding's whole point, which is that the
# pre-repair mirror offered EXACTLY the hero who could not go.
m11() { perl -0pi -e 's/                names\[#names \+ 1\] = hAlly:GetUnitName\(\)/                if not J.CanEnemyInterruptTpChannel(hAlly) then names[#names + 1] = hAlly:GetUnitName() end/' "$TESTF"; }
mutant "M11 the test's pre-repair helper applies the conjunct too" "$TESTF" m11

# --- M12: a constant moves under the census ----------------------------------
m12() { perl -0pi -e 's/J\.TP_RESPONSE_FAR_FLOOR = 3500/J.TP_RESPONSE_FAR_FLOOR = 3000/' "$JMZ"; }
mutant "M12 the far floor moves under every ratcheted count" "$JMZ" m12

echo
echo "mutants: $nrun   caught: $ncaught"
[ "$ncaught" -eq "$nrun" ] || exit 1
