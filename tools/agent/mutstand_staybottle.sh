#!/usr/bin/env bash
# Mutation stand for tests/test_staybottle_inflight_regen.lua (test_set.md §EZ).
#
# WHAT IT IS FOR. This round widens one clause of a PROMOTED function -- the
# SUPPLY read in J.ShouldStayAndRegen, live in every turbo game -- to accept the
# bottle's IN-FLIGHT modifier, the one member of that set the shipped line was
# never given. The case for it is a driven before/after on a real frame plus a
# 1012-frame domain price, both legs from the same shipped function with one
# soak id toggled. So the forgeable surfaces are the toggle (it stops toggling,
# or toggles too much) and the census (a plausible number about the wrong
# population).
#
# This stand has one subject the sibling's did not: THE DOMAIN IS ONE FRAME.
# A census whose headline count is 1 is the easiest kind to forge by accident --
# almost any mis-parse still prints a small number -- so M9, M10 and M13 all
# attack the population rather than the lever, and M15 replays the parse bug
# this file's own sweep shipped with on its first run.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2, M3) -- the widening is deleted, the
#     gate lands un-negated (so the widening applies to the SHIPPED path and
#     disappears when armed -- a change to shipped behaviour wearing the shape
#     of a gated one), or the modifier read is negated. M3 reads like the fix
#     and is its opposite: the bot is held precisely when it is NOT sipping;
#   * THE PULLCAD TRAP (M4) -- a second soak id joins the SAME condition, which
#     freezes it FALSE the day either id is promoted while check_armed_wiring.py
#     still calls it WIRED. Three ids in one FUNCTION is the normal state here,
#     so only the per-condition maximum can see this;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M5) -- strip_comments leaves
#     the sweep, and this lever's 40-line comment names IsSoakCandidate and the
#     modifier string while explaining them, so the id counts read the
#     explanation as the code;
#   * THE TOGGLE STOPS TOGGLING (M6, M7) -- the armed leg is taken disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction), or the
#     shipped baseline is taken armed;
#   * THE ARMING IS TOO WIDE (M8) -- the stub arms every candidate, so 'staysrc'
#     (44 flips on this corpus) can move the answer while 1 flip is still
#     attributed here. Inherited knowledge, not invention: the same mutant
#     SURVIVED the first run of the 'stayattr' stand;
#   * THE PARTITION STOPS PARTITIONING (M9) -- a vetoed frame lands in the wrong
#     bucket. The two buckets are the only thing keeping "the lever is inert on
#     this frame" apart from "the situation does not occur";
#   * A CONSTANT MOVES UNDER THE CENSUS (M10) -- the HP band changes, so every
#     ratcheted count is about a different population while still looking
#     reasonable. Here it also dissolves the two out-of-band controls, which are
#     the only thing separating this lever from the band's own work;
#   * THE GOLD PROBE IS NOT A PROBE (M11, M11b) -- the honest bound this round
#     publishes ("the measured flip set is the GOLD-POOR SUPERSET") rests
#     entirely on `gold_nonzero == 0`. M11 feeds the probe a literal and must be
#     caught. ⚠️ M11b -- the probe stops calling the engine at all -- is
#     DECLARED UNMEASURABLE and says why at its call site;
#   * THE DISJOINTNESS COLUMN IS NOT MEASURED (M12) -- the 'staysrc'-alone drive
#     arms nothing, so `flips_staysrc` reads 0 and `flips_both_levers` reads 0
#     for the wrong reason. The wave guidance this round hands the batch desk
#     (GH #532: these two CAN be armed separately) lives or dies on that column;
#   * THE SUBJECT IS SWAPPED FOR A MODIFIER THE SHIPPED LINE ALREADY READS (M13)
#     -- the lever reads 'modifier_flask_healing' instead. It is still gated,
#     still one id, still additive, and it is a guaranteed no-op, because the
#     shipped disjunction two lines up already answers TRUE on every frame that
#     could reach it;
#   * THE SHIPPED-SIDE SPAN GROWS OVER THE LEVER (M15) -- the sweep's
#     "how many in-flight modifiers does the SHIPPED read name" span is bounded
#     by the next statement; widen it back to a blank-line span and the lever's
#     own line lands inside the shipped count. This is not hypothetical: the
#     first run of this sweep reported 3 shipped modifier reads and a shipped
#     bottle read of 1, both off the lever's own line.
#
# CONTROL (must SURVIVE): M14 rewrites a COMMENT inside the lever's own block.
# Nothing here is allowed to be satisfied by prose, so a comment edit must not
# turn it red. A stand where every mutant is caught cannot tell a sharp
# assertion from one that fires on anything.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_staybottle.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, read the diff first: a regex that misses prints NO-OP, a
# regex that hits the wrong place prints SURVIVED while the subject is
# untouched).
#
# SLOW ON PURPOSE: every mutant re-runs a 109-fixture, 1012-frame sweep in which
# the guard is driven THREE times per frame (shipped / staybottle / staysrc).
# The sweep is the thing under test; running it once and reusing the output
# would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
SWEEP=tests/_staybottle_sweep.lua
TEST=staybottle_inflight_regen

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
m1() { perl -0pi -e "s/\tif not bHasRegen and J\.IsSoakCandidate\( 'staybottle' \) then\n\t\tbHasRegen = bot:HasModifier\( 'modifier_bottle_regeneration' \)\n\tend\n//" "$JMZ"; }
mutant caught "M1 the gated widening is deleted (shipped read restored)" "$JMZ" m1

# Un-negated in effect: the widening now applies when the id is NOT armed, so
# the shipped tree changes and the armed leg is the old shipped read. Both legs
# still "work"; they have swapped.
m2() { perl -0pi -e "s/if not bHasRegen and J\.IsSoakCandidate\( 'staybottle' \) then/if not bHasRegen and not J.IsSoakCandidate( 'staybottle' ) then/" "$JMZ"; }
mutant caught "M2 the gate lands negated (shipped and armed legs swap)" "$JMZ" m2

# The one a reviewer skims: same read, same place, one `not`. Now the bot is
# held in the field precisely when nothing is being drunk.
m3() { perl -0pi -e "s/\t\tbHasRegen = bot:HasModifier\( 'modifier_bottle_regeneration' \)/\t\tbHasRegen = not bot:HasModifier( 'modifier_bottle_regeneration' )/" "$JMZ"; }
mutant caught "M3 the modifier read is negated (lever inverted)" "$JMZ" m3

# --- M4: the pullcad trap ----------------------------------------------------
m4() { perl -0pi -e "s/if not bHasRegen and J\.IsSoakCandidate\( 'staybottle' \) then/if not bHasRegen and J.IsSoakCandidate( 'staybottle' ) and J.IsSoakCandidate( 'staysrc' ) then/" "$JMZ"; }
mutant caught "M4 a second soak id joins the same condition (pullcad)" "$JMZ" m4

# --- M5: the instrument reads prose instead of code --------------------------
m5() { perl -0pi -e "s/local stay = strip_comments\(block\(src, 'function J\.ShouldStayAndRegen\( bot \)'\)\)/local stay = block(src, 'function J.ShouldStayAndRegen( bot )')/" "$SWEEP"; }
mutant caught "M5 the sweep stops stripping comments before parsing" "$SWEEP" m5

# --- M6, M7: the toggle stops toggling ---------------------------------------
m6() { perl -0pi -e "s/\n                    armed = true\n                    -- The arming must be ONE id wide/\n                    armed = false\n                    -- The arming must be ONE id wide/" "$SWEEP"; }
mutant caught "M6 the armed leg is driven disarmed (flips -> 0)" "$SWEEP" m6

m7() { perl -0pi -e "s/                    local ok1, shipped = pcall/                    armed = true\n                    local ok1, shipped = pcall/" "$SWEEP"; }
mutant caught "M7 the shipped baseline is driven armed" "$SWEEP" m7

# --- M8: the arming is too wide ----------------------------------------------
# SURVIVED the first run of the 'stayattr' stand; caught here by `arm_leak`,
# which names 'staysrc' explicitly because that is the id sharing this clause.
m8() { perl -0pi -e "s/                        return armed and sId == 'staybottle'\n                    end\n\n                    -- The gold term/                        return armed\n                    end\n\n                    -- The gold term/" "$SWEEP"; }
mutant caught "M8 the stub arms every candidate, not just this one" "$SWEEP" m8

# --- M9: the partition stops partitioning ------------------------------------
m9() { perl -0pi -e "s/                                    bump\('blocked_no_mod'\)/                                    bump('blocked_with_mod')/" "$SWEEP"; }
mutant caught "M9 the inert bucket is folded into the flip bucket" "$SWEEP" m9

# --- M10: a constant moves under the census ----------------------------------
m10() { perl -0pi -e "s/\tif nHP < 0\.18 or nHP > 0\.75 then return false end/\tif nHP < 0.18 or nHP > 0.95 then return false end/" "$JMZ"; }
mutant caught "M10 the HP ceiling moves, dissolving both controls" "$JMZ" m10

# --- M11, M11b: the gold probe is not a probe --------------------------------
m11() { perl -0pi -e "s/if \(tonumber\(bot:GetGold\(\)\) or 0\) == 0 then/if (tonumber(1) or 0) == 0 then/" "$SWEEP"; }
mutant caught "M11 the gold probe reads a literal instead of the engine" "$SWEEP" m11

# ⚠️ DECLARED UNMEASURABLE, and the declaration is the point. This mutant makes
# the probe stop calling the engine at all -- it just counts every frame as
# gold-zero. On a corpus where gold IS zero on every frame, "probed and found 0"
# and "assumed 0" produce byte-identical counters, so no assertion in this suite
# can separate them. The day a fixture carries real gold, M11 above goes red
# first and this entry gets re-classified.
m11b() { perl -0pi -e "s/if \(tonumber\(bot:GetGold\(\)\) or 0\) == 0 then/if true then/" "$SWEEP"; }
mutant unmeasurable "M11b the gold probe stops calling the engine" "$SWEEP" m11b

# --- M12: the disjointness column is not measured ----------------------------
m12() { perl -0pi -e "s/                    J\.IsSoakCandidate = function\(sId\) return sId == 'staysrc' end/                    J.IsSoakCandidate = function() return false end/" "$SWEEP"; }
mutant caught "M12 the sibling-alone drive arms nothing (disjointness faked)" "$SWEEP" m12

# --- M13: the subject is swapped for a modifier the shipped line already reads
# Still gated, still one id, still additive -- and a guaranteed no-op, because
# the shipped disjunction two lines up already answers TRUE wherever this could.
m13() { perl -0pi -e "s/\t\tbHasRegen = bot:HasModifier\( 'modifier_bottle_regeneration' \)/\t\tbHasRegen = bot:HasModifier( 'modifier_flask_healing' )/" "$JMZ"; }
mutant caught "M13 the lever reads a modifier the shipped line already has" "$JMZ" m13

# --- M14: the control --------------------------------------------------------
m14() { perl -0pi -e "s/-- \[staybottle \/ owner priority P2, 2026-09-05\] The IN-FLIGHT half/-- [staybottle \/ owner priority P2, 2026-09-05] The in-flight HALF/" "$JMZ"; }
mutant survive "M14 a comment inside the lever's own block is reworded" "$JMZ" m14

# --- M15: the shipped-side span grows over the lever -------------------------
# The bug this sweep actually shipped with on its first run, replayed: bound the
# "shipped in-flight modifiers" span by a blank line instead of by the next
# statement and the lever's own line lands inside the shipped count.
m15() { perl -0pi -e "s/local shipped_supply = stay and stay:match\('local bHasFlask\.-local bHasRegen'\)/local shipped_supply = stay and stay:match('local bHasFlask.-\\\\n\\\\n')/" "$SWEEP"; }
mutant caught "M15 the shipped-side span swallows the lever's own line" "$SWEEP" m15

echo "---"
echo "mutants run: $nrun   landed as declared: $ncaught   unmeasurable: $nunmeas   NOT as declared: $nbad"
if [ "$nbad" -ne 0 ]; then
    echo "STAND RED: $nbad mutant(s) did not land as declared."
    exit 1
fi
echo "STAND GREEN"
exit 0
