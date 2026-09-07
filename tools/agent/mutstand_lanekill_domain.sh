#!/usr/bin/env bash
# Mutation stand for tests/test_lanekill_domain_census.lua (test_set.md §FW).
#
# WHAT IT IS FOR. That file's headline is a NEGATIVE claim -- "the last conjunct
# of both lane-kill helpers reads 0 because this corpus is blind to outgoing
# burst, not because the clause is false" -- and a negative claim built out of
# zeros is exactly the shape that can be true for the wrong reason. Four ways
# this suite could be printing green while saying nothing:
#
#   * THE BLINDNESS IS NOT REAL. If some third thing (an empty ally list, a
#     dead helper) were producing the zero, then the day someone repairs the
#     estimator the census would still read 0 and §FW's "unbuyable" half would
#     be permanently, invisibly wrong. M1 wakes the estimator up and the suite
#     must go RED -- that assertion is the one §FW rests on.
#   * THE CENSUS STOPPED TRACKING THE TREE. Every threshold is parsed out of
#     jmz_func precisely so a tuning edit moves the numbers (the M13 lesson). If
#     the parse silently fell back to a hardcoded default, the funnel would keep
#     printing yesterday's population. M2 and M3 move real thresholds.
#   * THE GATE SHAPE MOVED. §FW priced a single-site, single-id, turbo-only gate
#     for each id (the pullcad trap: a gate naming two ids freezes the day
#     either is promoted). M4 and M5 change that shape.
#   * IT IS SATISFIED BY PROSE. M6 (CONTROL, must SURVIVE) edits a comment
#     inside one of the helpers. A suite where a comment can turn things red is
#     not reading code.
#
# ⛔ TWO THINGS THIS STAND MEASURED ABOUT ITS OWN SUITE, both on the first run,
# both written down rather than tidied away:
#
#   * M4 SURVIVED the first version of the census. The suite claimed to check
#     the pullcad trap by counting each id's gate sites -- and `A and B` still
#     contains exactly one `A`, so a second id joining the gate line was
#     invisible to it. The assertion, not the mutant, was wrong; the census now
#     enumerates every id read in the guard prologue and requires it to be the
#     one id. M4 is declared CAUGHT because the repaired assertion catches it.
#   * M7 (l1trade's gate removed outright) is CAUGHT, but NOT by behaviour.
#     `[control] the shipped tree is silent` is 0EQUIV under the very blindness
#     this file documents: with the lethality clause unable to pass, the helper
#     returns nil with or without its gate, so `l1_shipped_fires` reads 0 in
#     both trees. What actually catches M7 is the `[source]` block's string pin.
#     ⇒ THE GUARD ON THESE TWO GATES IS A STRING, AND THAT IS A LIMITATION, NOT
#     A STRENGTH (the §FT lesson, second appearance): the day someone re-words
#     the gate while removing it, this suite is the wrong place to expect a
#     raised hand. Restoring a behavioural guard needs an outgoing-damage model
#     in the harness -- the same missing ingredient as condition (a) itself.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_lanekill_domain.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, the
# control was CAUGHT, or an edit matched nothing (NO-OP counts as
# non-compliant, not as a pass: a mutant that never existed still prints a line).
#
# SLOW ON PURPOSE: every mutant re-runs the census, which rebuilds jmz_func once
# per hero-frame over 110 fixtures.
set -u

JMZ=bots/FunLib/jmz_func.lua
FIX=tests/mock/replay_fixture.lua
TEST=lanekill_domain_census

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
            printf 'SURVIVED  %-56s exit=%s  (declared SURVIVE, as documented)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-56s exit=%s  ** DECLARED-SURVIVE MUTANT WENT RED **\n' "$label" "$rc"
            echo "          ^ re-read the declaration: either the suite grew a real"
            echo "            assertion here (good -- update this stand), or something"
            echo "            in it is satisfied by prose."
        fi
    fi
}

# --- M1: the finding itself -------------------------------------------------
# Give every hero a real OUTGOING burst number. This is the repaired-harness
# future, simulated: `*_est_live` goes non-zero, both funnels start firing, and
# the "condition (a) is structurally unbuyable from fixtures" half of §FW stops
# being true. The suite MUST notice, or that half can rot undetected forever.
m1() { perl -0pi -e "s/GetEstimatedDamageToTarget = function\(\) return burst end,/GetEstimatedDamageToTarget = function() return burst + 99999 end,/" "$FIX"; }
mutant caught "M1 the corpus can see outgoing burst" "$FIX" m1

# --- M2, M3: the census must track the tree ---------------------------------
# The shared ceiling both helpers sit behind. Shortening the turbo laning floor
# shrinks the laning population, and every count under it, at once.
m2() { perl -0pi -e "s/local nFloor = bTurbo and 8 \* 60 or 10 \* 60/local nFloor = bTurbo and 4 * 60 or 10 * 60/" "$JMZ"; }
mutant caught "M2 the turbo laning floor moves 8min -> 4min" "$JMZ" m2

# A tuning edit to l1trade's own self-risk bar -- the clause measured to be the
# one that actually vetoes frames (7 of 138), i.e. the evidence that the
# incoming direction is live. Tightening it must move `l1_selfrisk_ok`.
m3() { perl -0pi -e "s/if nIncoming >= bot:GetHealth\(\) \* 0\.75 then return nil end/if nIncoming >= bot:GetHealth() * 0.05 then return nil end/" "$JMZ"; }
mutant caught "M3 l1trade self-risk bar tightened 0.75 -> 0.05" "$JMZ" m3

# --- M4, M5: the gate shape §FW priced --------------------------------------
# The pullcad trap, planted: a second id joins the gate line, so the lever
# freezes silently the day either id is promoted.
m4() { perl -0pi -e "s/if not J\.IsSoakCandidate\( 'l5combo' \) then return nil end/if not ( J.IsSoakCandidate( 'l5combo' ) and J.IsSoakCandidate( 'pullcad' ) ) then return nil end/" "$JMZ"; }
mutant caught "M4 l5combo's gate becomes a two-id conjunction" "$JMZ" m4

# The turbo guard leaves l1trade: a soak candidate that can fire in normal mode
# is not the thing §FW ruled on.
m5() { perl -0pi -e "s/function J\.ShouldInitiateLaneKill\( bot \)\n\tif not J\.IsModeTurbo\(\) then return nil end\n/function J.ShouldInitiateLaneKill( bot )\n/" "$JMZ"; }
mutant caught "M5 l1trade loses its turbo-only guard" "$JMZ" m5

# --- M6: CONTROL, must SURVIVE ----------------------------------------------
# A comment inside the helper's own header block. Nothing here may be satisfied
# by prose.
m6() { perl -0pi -e "s/-- The backing ally \(\"support beside me\"\)\./-- MUTANT COMMENT: this sentence carries no behaviour./" "$JMZ"; }
mutant survive "M6 CONTROL: a comment inside the helper is rewritten" "$JMZ" m6

# --- M7: caught, but read the header before calling that a strength ---------
# Someone un-gates the lever. The runtime control cannot see it (a helper
# blocked by a blind clause is silent with or without its gate); the `[source]`
# string pin is what turns this red. Declared CAUGHT so a future regression in
# the pin shows up here -- and documented as a string pin so nobody reads it as
# behavioural coverage.
m7() { perl -0pi -e "s/if not J\.IsSoakCandidate\( 'l1trade' \) then return nil end/if false then return nil end/" "$JMZ"; }
mutant caught "M7 l1trade's gate is removed outright (string pin only)" "$JMZ" m7

echo
printf '%d mutant(s): %d as declared, %d NOT as declared\n' "$nrun" "$ncaught" "$nbad"
if [ "$nbad" -ne 0 ]; then exit 1; fi
exit 0
