#!/usr/bin/env bash
# Mutation stand for tests/test_staysrc_field_supply.lua (test_set.md §EY).
#
# WHAT IT IS FOR. This round widens one clause of a PROMOTED function -- the
# SUPPLY read in J.ShouldStayAndRegen, live in every turbo game -- from
# "item_flask only" to the sibling J.HasFieldRegenSource, and the case for it is
# a driven before/after on a real frame plus a 1012-frame domain price. Both
# legs come from the same shipped function with one soak id toggled, so the
# forgeable surfaces are the toggle (it stops toggling, or toggles too much) and
# the census (a plausible number about the wrong population).
#
# This stand also has a subject the previous one did not: THE FUNCTION NOW
# CARRIES TWO INDEPENDENT LEVERS, and the file's loudest finding is about their
# INTERACTION -- exactly one frame in 1012 flips only when both are armed, and
# it is owner priority P2's own pinned frame. M12 attacks that leg directly,
# because a pair claim that no mutant can break is a coincidence written down.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2, M3) -- the widening is deleted, the
#     gate lands un-negated (so the widening applies to the SHIPPED path and
#     disappears when armed -- a change to shipped behaviour wearing the shape
#     of a gated one), or the borrowed predicate is negated. M3 reads like the
#     fix and is its opposite;
#   * THE PULLCAD TRAP (M4) -- a second soak id joins the SAME condition, which
#     freezes it FALSE the day either id is promoted while check_armed_wiring.py
#     still calls it WIRED. Note what this stand may NOT assert: two ids in the
#     same FUNCTION is now the normal state here, so the assertion had to move
#     to the per-condition maximum. M4 is the mutant that proves the sharper
#     assertion still bites;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M5) -- strip_comments leaves
#     the sweep, and this function's comments name IsSoakCandidate while
#     explaining the trap, so the id counts read the warning as the violation.
#     The identical bug fired for real on the §EN sweep's first run;
#   * THE TOGGLE STOPS TOGGLING (M6, M7) -- the armed leg is taken disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction), or the
#     shipped baseline is taken armed;
#   * THE ARMING IS TOO WIDE (M8) -- the stub arms every candidate, so any of
#     the other 140 gates can move the answer while the flip is still attributed
#     here. This one is inherited knowledge, not invention: the same mutant
#     SURVIVED the first run of the 'stayattr' stand and had to be bought with a
#     new counter. Here `arm_leak` names 'bagsalve' explicitly, because that is
#     the id nested inside the callee;
#   * THE PARTITION STOPS PARTITIONING (M9) -- a vetoed frame lands in the wrong
#     bucket. The two buckets are the only thing keeping "the lever is inert on
#     this frame" apart from "the situation does not occur";
#   * A CONSTANT MOVES UNDER THE CENSUS (M10) -- the HP band changes, so every
#     ratcheted count is about a different population while still looking
#     reasonable;
#   * THE GOLD PROBE IS NOT A PROBE (M11, M11b) -- the honest bound this round
#     publishes ("the measured flip set is the GOLD-POOR SUPERSET") rests
#     entirely on `gold_nonzero == 0`. M11 feeds the probe a literal and must be
#     caught. ⚠️ M11b -- the probe stops calling the engine at all -- is
#     DECLARED UNMEASURABLE and says why at its call site;
#   * THE PAIR FINDING IS NOT MEASURED (M12) -- the "both armed" drive quietly
#     arms only one id, and the and-of-vetoes column reads 0. The wave guidance
#     this round hands to the batch desk lives or dies on that column;
#   * THE BORROWED HELPER GROWS A GATE (M13) -- J.HasFieldRegenSource picks up a
#     second soak id, so this lever silently becomes `staysrc AND <that>` and
#     the census row calling the nesting additive-only goes stale.
#
# CONTROL (must SURVIVE): M14 rewrites a COMMENT in the shipped clause. Nothing
# here is allowed to be satisfied by prose, so a comment edit must not turn it
# red. A stand where every mutant is caught cannot tell a sharp assertion from
# one that fires on anything.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_staysrc.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, read the diff first: a regex that misses prints NO-OP, a
# regex that hits the wrong place prints SURVIVED while the subject is
# untouched).
#
# SLOW ON PURPOSE: every mutant re-runs a 109-fixture, 1012-frame sweep in which
# the guard is driven FOUR times per frame (shipped / staysrc / stayattr /
# both). The sweep is the thing under test; running it once and reusing the
# output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
SWEEP=tests/_staysrc_sweep.lua
TEST=staysrc_field_supply

TMP=$(mktemp -d)
nrun=0; ncaught=0; nbad=0; nunmeas=0
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

# want=caught (a real mutant), want=survive (a control), or want=unmeasurable
# (a real mutant this corpus provably cannot catch, with the reason recorded at
# the call site). An UNMEASURABLE is NOT a pass and NOT a failure: it is the
# stand admitting which of its own claims currently rest on a vacuous branch.
mutant() {
    local want=$1 label=$2 target=$3; shift 3
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-58s (the edit matched nothing -- the mutant never existed)\n' "$label"
        nbad=$((nbad + 1))
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$want" = caught ]; then
        if [ "$rc" -ne 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
            echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
            echo "            per its converse, first confirm the edit landed where you meant."
        fi
    elif [ "$want" = unmeasurable ]; then
        if [ "$rc" -eq 0 ]; then
            nunmeas=$((nunmeas + 1))
            printf 'UNMEASURABLE %-55s exit=%s  (declared; NOT a pass)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** re-classify as `caught` **\n' "$label" "$rc"
            echo "          ^ the corpus can now witness this branch; the"
            echo "            UNMEASURABLE note at the call site is out of date."
        fi
    else
        if [ "$rc" -eq 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'SURVIVED  %-58s exit=%s  (control, as declared)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** CONTROL WENT RED **\n' "$label" "$rc"
            echo "          ^ a comment edit turned this suite red: something in it"
            echo "            is being satisfied by prose rather than by code."
        fi
    fi
}

# --- M1, M2, M3: the lever leaves, or lands inverted -------------------------
m1() { perl -0pi -e "s/\tif not bHasRegen and J\.IsSoakCandidate\( 'staysrc' \) then\n\t\tbHasRegen = J\.HasFieldRegenSource\( bot \)\n\tend\n//" "$JMZ"; }
mutant caught "M1 the gated widening is deleted (shipped read restored)" "$JMZ" m1

# Un-negated in effect: the widening now applies when the id is NOT armed, so
# the shipped tree changes and the armed leg is the old shipped read. Both legs
# still "work"; they have swapped.
m2() { perl -0pi -e "s/if not bHasRegen and J\.IsSoakCandidate\( 'staysrc' \) then/if not bHasRegen and not J.IsSoakCandidate( 'staysrc' ) then/" "$JMZ"; }
mutant caught "M2 the gate lands negated (shipped and armed legs swap)" "$JMZ" m2

# The one a reviewer skims: same call, same place, one `not`. Now the bot is
# held in the field precisely when it has NOTHING to drink.
m3() { perl -0pi -e "s/\t\tbHasRegen = J\.HasFieldRegenSource\( bot \)/\t\tbHasRegen = not J.HasFieldRegenSource( bot )/" "$JMZ"; }
mutant caught "M3 the borrowed predicate is negated (lever inverted)" "$JMZ" m3

# --- M4: the pullcad trap ----------------------------------------------------
# Two ids in ONE condition. The per-condition assertion is the only thing that
# can see this now that two ids in one function is the normal state.
m4() { perl -0pi -e "s/if not bHasRegen and J\.IsSoakCandidate\( 'staysrc' \) then/if not bHasRegen and J.IsSoakCandidate( 'staysrc' ) and J.IsSoakCandidate( 'bagsalve' ) then/" "$JMZ"; }
mutant caught "M4 a second soak id joins the same condition (pullcad)" "$JMZ" m4

# --- M5: the instrument reads prose instead of code --------------------------
m5() { perl -0pi -e "s/local stay = strip_comments\(block\(src, 'function J\.ShouldStayAndRegen\( bot \)'\)\)/local stay = block(src, 'function J.ShouldStayAndRegen( bot )')/" "$SWEEP"; }
mutant caught "M5 the sweep stops stripping comments before parsing" "$SWEEP" m5

# --- M6, M7: the toggle stops toggling ---------------------------------------
m6() { perl -0pi -e "s/\n                    armed = true\n/\n                    armed = false\n/" "$SWEEP"; }
mutant caught "M6 the armed leg is driven disarmed (flips -> 0)" "$SWEEP" m6

m7() { perl -0pi -e "s/                    local ok1, shipped = pcall/                    armed = true\n                    local ok1, shipped = pcall/" "$SWEEP"; }
mutant caught "M7 the shipped baseline is driven armed" "$SWEEP" m7

# --- M8: the arming is too wide ----------------------------------------------
# SURVIVED the first run of the sibling stand. Caught here by `arm_leak`.
m8() { perl -0pi -e "s/                        return armed and sId == 'staysrc'\n                    end\n\n                    -- The gold term/                        return armed\n                    end\n\n                    -- The gold term/" "$SWEEP"; }
mutant caught "M8 the stub arms every candidate, not just this one" "$SWEEP" m8

# --- M9: the partition stops partitioning ------------------------------------
m9() { perl -0pi -e "s/                                    bump\('blocked_no_src'\)/                                    bump('blocked_with_src')/" "$SWEEP"; }
mutant caught "M9 the inert bucket is folded into the flip bucket" "$SWEEP" m9

# --- M10: a constant moves under the census ----------------------------------
m10() { perl -0pi -e "s/\tif nHP < 0\.18 or nHP > 0\.75 then return false end/\tif nHP < 0.30 or nHP > 0.75 then return false end/" "$JMZ"; }
mutant caught "M10 the HP band moves under every ratcheted count" "$JMZ" m10

# --- M11, M11b: the gold probe is not a probe --------------------------------
m11() { perl -0pi -e "s/if \(tonumber\(bot:GetGold\(\)\) or 0\) == 0 then/if (tonumber(1) or 0) == 0 then/" "$SWEEP"; }
mutant caught "M11 the gold probe reads a literal instead of the engine" "$SWEEP" m11

# ⚠️ DECLARED UNMEASURABLE, and the declaration is the point. This mutant makes
# the probe stop calling the engine at all -- it just counts every frame as
# gold-zero. On a corpus where gold IS zero on every frame, "probed and found 0"
# and "assumed 0" produce byte-identical counters, so no assertion in this
# suite can separate them. That is the same shape as the sibling stand's M8
# (armed-one vs armed-all agreeing on this corpus), and it is exactly the
# condition under which the honest bound would rot silently. The day a fixture
# carries real gold, M11 above goes red first and this entry gets re-classified.
m11b() { perl -0pi -e "s/if \(tonumber\(bot:GetGold\(\)\) or 0\) == 0 then/if true then/" "$SWEEP"; }
mutant unmeasurable "M11b the gold probe stops calling the engine" "$SWEEP" m11b

# --- M12: the pair finding is not measured -----------------------------------
m12() { perl -0pi -e "s/                        return sId == 'stayattr' or sId == 'staysrc'/                        return sId == 'stayattr'/" "$SWEEP"; }
mutant caught "M12 the 'both armed' drive quietly arms only one id" "$SWEEP" m12

# --- M13: the borrowed helper grows a gate -----------------------------------
m13() { perl -0pi -e "s/function J\.HasFieldRegenSource\( bot \)\n\tfor i = 0, 5 do/function J.HasFieldRegenSource( bot )\n\tif J.IsSoakCandidate( 'fieldsip' ) then return false end\n\tfor i = 0, 5 do/" "$JMZ"; }
mutant caught "M13 the borrowed helper grows a second soak gate" "$JMZ" m13

# --- M14: the control --------------------------------------------------------
m14() { perl -0pi -e "s/-- \[staysrc \/ owner priority P2, 2026-09-05\] The supply read/-- [staysrc \/ owner priority P2, 2026-09-05] The SUPPLY READ/" "$JMZ"; }
mutant survive "M14 a comment in the shipped clause is reworded" "$JMZ" m14

echo "---"
echo "mutants run: $nrun   landed as declared: $ncaught   unmeasurable: $nunmeas   NOT as declared: $nbad"
if [ "$nbad" -ne 0 ]; then
    echo "STAND RED: $nbad mutant(s) did not land as declared."
    exit 1
fi
echo "STAND GREEN"
exit 0
