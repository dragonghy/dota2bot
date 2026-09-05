#!/usr/bin/env bash
# Mutation stand for the owed-registry CLAIM field (GH #518, test_set.md §ES).
#
# WHAT IT IS FOR. This round's product is a field that makes a row QUIETER --
# an owed row somebody has claimed stops reddening the selfcheck leg. That is
# the most dangerous shape of change this registry can take: every defect it
# can introduce looks exactly like the feature working. A claim honoured when
# it should not have been, a claim that never expires, a claim on a standing
# constraint -- all three print a calm, plausible line and leave a baton on the
# floor, which is the very failure (`§DR`, GH #413) the registry exists to stop.
#
# So the mutants are not "does the happy path work" (one test covers that);
# they are the four ways the SILENCE can be granted wrongly:
#
#   M1  the claim never expires        -- a session that died mid-round parks
#                                         the baton forever (backlog §6b's
#                                         false-abandonment cost, sign-flipped)
#   M2  a half-written claim is honoured -- `claimed_by` with no instant buys
#                                         six hours of quiet on a say-so the
#                                         tool cannot read
#   M3  an unparseable instant is honoured -- the house style fuzzes minutes
#                                         (`T07:xxZ`); that is the likeliest
#                                         wrong claim anybody will actually
#                                         write, so it must not be a hold
#   M4  `claimable: false` is ignored  -- THE mutant. A standing VETO row
#                                         (`mock_isprefix_ordering`) has no
#                                         completion state; reporting OWED in
#                                         every round IS its whole job, so a
#                                         claim silencing it would be this fix
#                                         manufacturing the silence it was
#                                         written against
#   M5  IN-FLIGHT still reddens        -- the INVERSE direction: if a claimed
#                                         row keeps exiting 3, the field buys
#                                         nothing and the test that says it
#                                         does is vacuous
#   M6  the in-flight summary line goes -- an all-in-flight registry exits 0;
#                                         without the line a clean read is
#                                         indistinguishable from "nothing owed"
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_owed_claim.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (rule 2: suspect the
# assertion before the mutation -- and per its converse, read the NO-OP line
# first: a regex that misses prints NO-OP, a regex that hits the wrong place
# prints SURVIVED while the subject is untouched).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SRC=tools/agent/pending_rulings.py
TEST=tests/test_pending_rulings.py

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
    find . -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null
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
    python3 "$TEST" > "$TMP/test.log" 2>&1 || rc=$?
    echo "$rc"
}

mutant() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-52s (the edit matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-52s exit=%s\n' "$label" "$rc"
        sed -n 's/^FAIL: /          caught by: /p' "$TMP/test.log" | head -3
    else
        printf 'SURVIVED  %-52s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
        echo "            per its converse, first confirm the edit landed where you meant."
    fi
}

# --- M1: the claim never expires ---------------------------------------------
m1() { perl -0pi -e 's/if age_h <= CLAIM_TTL_HOURS:/if True:/' "$SRC"; }
mutant "M1 a claim never expires" "$SRC" m1

# --- M2: half a claim is honoured --------------------------------------------
# `claimed_by` alone. Six hours of quiet bought by a say-so with no instant in
# it -- and, being un-timed, one that can never expire either.
#
# NOTE the shape of the mutation, because the first attempt here was a NO-OP
# that printed SURVIVED: deleting the half-claim BRANCH (`if not by or not at:`
# -> `if False:`) changes nothing, since `parse_utc(None)` catches the same case
# one line later and returns UNREADABLE anyway. Defence in depth means the
# branch alone is not the guard, so the mutant has to attack the ANSWER
# (UNREADABLE -> IN-FLIGHT), not the branch that computes it. Recorded because
# this is exactly the converse of rule 2 the header warns about.
m2() { perl -0pi -e 's/        return \("UNREADABLE",\n                "claim is half-written/        return ("IN-FLIGHT",\n                "claim is half-written/' "$SRC"; }
mutant "M2 half a claim (no instant) is honoured" "$SRC" m2

# --- M3: an unparseable instant is honoured ----------------------------------
# parse_utc stops being strict: anything that is a non-empty string is taken as
# "now", so the fuzzed `T07:xxZ` becomes a fresh claim.
m3() { perl -0pi -e 's/    if stamp is None:\n        return \("UNREADABLE",\n                "claimed_at=%r is not an ISO-8601 UTC instant/    if stamp is None:\n        return ("IN-FLIGHT",\n                "claimed_at=%r is not an ISO-8601 UTC instant/' "$SRC"; }
mutant "M3 an unparseable instant is honoured" "$SRC" m3

# --- M4: claimable:false is ignored ------------------------------------------
# THE mutant: a standing veto row can be claimed, and goes quiet for six hours.
m4() { perl -0pi -e 's/    if row\.get\("claimable"\) is False:/    if False:/' "$SRC"; }
mutant "M4 a standing constraint can be claimed quiet" "$SRC" m4

# --- M5: IN-FLIGHT still counts as a finding ---------------------------------
# The inverse direction. If this survives, the claim field changes nothing that
# any test can see, and the whole change is decorative.
m5() { perl -0pi -e 's/        shown = "IN-FLIGHT" if \(state == "OWED" and claim == "IN-FLIGHT"\) else state/        shown = state/' "$SRC"; }
mutant "M5 a claimed row still reddens the leg" "$SRC" m5

# --- M6: the in-flight summary line disappears -------------------------------
# Exit 0 with no line saying why. "Clean read, not a clean scene" -- the same
# sentence this file's orphan leg was built on.
m6() { perl -0pi -e 's/    if inflight:\n/    if False:\n/' "$SRC"; }
mutant "M6 the in-flight summary line is dropped" "$SRC" m6

echo "----"
echo "$ncaught/$nrun mutants caught"
[ "$ncaught" -eq "$nrun" ] || exit 1
