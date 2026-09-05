#!/usr/bin/env bash
# Mutation stand for tests/test_staybag_backpack_salve.lua (test_set.md §FC).
#
# WHAT IT IS FOR. This round widens one clause of a PROMOTED function -- the
# SUPPLY read in J.ShouldStayAndRegen, live in every turbo game -- to see a salve
# sitting in the BACKPACK. The case for it has two halves and they forge
# differently:
#   (a) the behaviour: a driven before/after on two real frames plus a
#       1012-frame domain price, both legs from the same shipped function with
#       one soak id toggled;
#   (b) the REASON the id is standalone: the same behaviour is already reachable
#       through 'staysrc' AND 'bagsalve' armed together -- one id per site, so no
#       pullcad grep sees it -- and therefore is invisible to any single-arm
#       isolation wave. That claim rests entirely on the three-way column
#       (`flips_staysrc` / `flips_bagsalve` / `flips_pair`), and a column that
#       stops driving anything reads as a clean set of zeros.
#
# So the forgeable surfaces are the toggle (it stops toggling, or toggles too
# much), the census (a plausible number about the wrong population), and the
# two-id column (measured, or merely printed).
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2, M3) -- the widening is deleted, the
#     gate lands un-negated (so the widening applies to the SHIPPED path and
#     disappears when armed -- a change to shipped behaviour wearing the shape of
#     a gated one), or the item test is negated so the bot is held for carrying
#     anything EXCEPT a salve;
#   * THE PULLCAD TRAP (M4) -- a second soak id joins the SAME condition. Four
#     ids in one FUNCTION is the normal state here, so only the per-condition
#     maximum can see this;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M5) -- strip_comments leaves
#     the sweep, and this lever's ~50-line comment names IsSoakCandidate, both
#     sibling ids and the item name while explaining them.
#     ⚠️ THIS ONE FLIPPED CAUGHT -> SURVIVED MID-ROUND WITH NO CHANGE TO ITSELF.
#     What had been catching it was the EXACT `STAY_NIDS == 4` next door
#     (un-stripped, the comment's own `IsSoakCandidate(...)` examples inflate the
#     count). Relaxing that total to a floor was correct and unrelated -- an id
#     total is a ratchet trap, not an invariant, and this function has now had it
#     pinned `== 1`, `== 3` and `== 4`, each red on the next lever. But the
#     relaxation silently took the mutant's only detector with it. ⇒ A GUARD THAT
#     WORKS ONLY WHILE AN ADJACENT NUMBER HAPPENS TO BE EXACT IS NOT A GUARD:
#     the sweep now emits `STAY_STRIPPED` / `SRC_STRIPPED` and the test asserts
#     the stripping directly. Recorded because the flip is invisible on any
#     single run of this stand -- it takes running it twice across an unrelated
#     edit, which is not something anybody schedules;
#   * THE TOGGLE STOPS TOGGLING (M6, M7) -- the armed leg is driven disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction), or the
#     shipped baseline is driven armed;
#   * THE ARMING IS TOO WIDE (M8) -- the stub arms every candidate, so 'staysrc'
#     (44 flips on this corpus) can move the answer while 2 flips are still
#     attributed here. Inherited knowledge, not invention: the same mutant
#     SURVIVED the first run of the 'stayattr' stand;
#   * THE PARTITION STOPS PARTITIONING (M9) -- a vetoed frame lands in the wrong
#     bucket. The two buckets are the only thing keeping "the lever is inert on
#     this frame" apart from "the situation does not occur";
#   * A CONSTANT MOVES UNDER THE CENSUS (M10) -- the HP band changes, so every
#     ratcheted count is about a different population while still looking
#     reasonable, and both out-of-band controls dissolve;
#   * THE GOLD PROBE IS NOT A PROBE (M11, M11b) -- the honest bound this round
#     publishes ("the measured flip set is the GOLD-POOR SUPERSET") rests
#     entirely on `gold_nonzero == 0`. M11 feeds the probe a literal and must be
#     caught. ⚠️ M11b -- the probe stops calling the engine at all -- is DECLARED
#     UNMEASURABLE and says why at its call site;
#   * ⭐ THE TWO-ID COLUMN IS NOT MEASURED (M12) -- the pair drive arms nothing,
#     so `flips_pair` reads 0 and the whole "unbuyable one arm at a time" finding
#     reads as an unremarkable zero. This is the mutant this stand exists for:
#     the finding is a RELATION between four drives, and three of them are
#     otherwise unused;
#   * THE WIDENING STOPS BEING ONE ITEM WIDE (M14) -- it reads the backpacked
#     TANGO instead. Still gated, still one id, still additive -- and wrong for a
#     reason no gate can see: there is no shipped swapper for a tango, so the bot
#     is held next to something it cannot drink;
#   * THE CENSUS MEASURES THE WRONG POPULATION (M16) -- the sweep's own
#     backpack probe scans the main slots too, so `bag_carriers` and
#     `blocked_with_bag` grow while the lever's flips do not;
#   * THE JUSTIFICATION IS UNANCHORED (M18, M19) -- the shipped swapper that
#     makes a backpacked salve drinkable is renamed (the whole "one item wide"
#     argument evaporates and nothing in the tree notices), or J.IsItemAvailable
#     is widened to slot 8 (the defect is fixed upstream of the lever and the
#     lever becomes a no-op that still passes its own gate tests).
#
# ⚠️ DECLARED EQUIVALENT (M13): widening the lever's slot range to 0-8. Written
# as a `caught` mutant and it SURVIVED; the assertion was fine and the model was
# wrong. Control only reaches this block while `bHasRegen` is false, and
# `bHasRegen` starts as the shipped main-slot read, so a main-slot salve can
# never be here to be found. The full proof and the byte-identical manifest are
# at the call site. Kept rather than deleted: it is the shortest statement of why
# this lever is one HALF-INVENTORY wide.
#
# ⚠️ DECLARED UNMEASURABLE (M17): the sweep's `main_src` probe stops calling the
# engine. On this corpus NO backpack-salve frame carries a main-slot source, so
# "probed and found none" and "assumed none" produce byte-identical counters and
# no assertion here can separate them. The day a fixture carries both, this entry
# gets re-classified. It is recorded rather than dropped because
# `bag_with_main_src == 0` is the structural root of the disjointness claim.
#
# CONTROL (must SURVIVE): M15 rewrites a COMMENT inside the lever's own block.
# Nothing here is allowed to be satisfied by prose, so a comment edit must not
# turn it red. A stand where every mutant is caught cannot tell a sharp assertion
# from one that fires on anything.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_staybag.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, read the diff first: a regex that misses prints NO-OP, a
# regex that hits the wrong place prints SURVIVED while the subject is
# untouched).
#
# SLOW ON PURPOSE (~30s per mutant): every mutant re-runs a 109-fixture,
# 1012-frame sweep in which the guard is driven FIVE times per frame (shipped /
# staybag / staysrc / bagsalve / the pair). The sweep is the thing under test;
# running it once and reusing the output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
ROAM=bots/mode_team_roam_generic.lua
SWEEP=tests/_staybag_sweep.lua
TEST=staybag_backpack_salve

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

# want=caught (a real mutant), want=survive (a control), want=unmeasurable (a
# real mutant this corpus provably cannot catch, with the reason recorded at the
# call site), or want=equivalent (an edit that is provably a NO-OP on any corpus,
# kept because the proof is worth reading).
#
# The two non-binary classes are different claims and must not be collapsed:
#   UNMEASURABLE says "this corpus cannot witness the difference" -- a fixture
#     could change that tomorrow, and the entry gets re-classified when it does.
#   EQUIVALENT says "there is no difference to witness" -- the mutated program
#     computes the same function, so no corpus, ever, can catch it. Declaring one
#     as `caught` and watching it survive is the stand telling you your model of
#     the code was wrong; that is what M13 did here on its first run.
# Neither is a pass.
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
    elif [ "$want" = unmeasurable ] || [ "$want" = equivalent ]; then
        local word=UNMEASURABLE
        [ "$want" = equivalent ] && word=EQUIVALENT
        if [ "$rc" -eq 0 ]; then
            nunmeas=$((nunmeas + 1))
            printf '%-12s %-55s exit=%s  (declared; NOT a pass)\n' "$word" "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** re-classify as `caught` **\n' "$label" "$rc"
            echo "          ^ the suite can now witness this branch; the"
            echo "            $word note at the call site is out of date."
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
m1() { perl -0pi -e "s/\tif not bHasRegen and J\.IsSoakCandidate\( 'staybag' \) then\n\t\tfor i = 6, 8 do\n.*?\n\tend\n\tif not bHasRegen and bot:GetGold/\tif not bHasRegen and bot:GetGold/s" "$JMZ"; }
mutant caught "M1 the gated widening is deleted (shipped read restored)" "$JMZ" m1

# Un-negated in effect: the widening now applies when the id is NOT armed, so the
# shipped tree changes and the armed leg is the old shipped read. Both legs still
# "work"; they have swapped.
m2() { perl -0pi -e "s/if not bHasRegen and J\.IsSoakCandidate\( 'staybag' \) then/if not bHasRegen and not J.IsSoakCandidate( 'staybag' ) then/" "$JMZ"; }
mutant caught "M2 the gate lands negated (shipped and armed legs swap)" "$JMZ" m2

# The one a reviewer skims: same loop, same slots, one operator. Now the bot is
# held for carrying anything in the backpack EXCEPT a salve.
m3() { perl -0pi -e "s/\t\t\tif hItem ~= nil and hItem:GetName\(\) == 'item_flask' then/\t\t\tif hItem ~= nil and hItem:GetName() ~= 'item_flask' then/" "$JMZ"; }
mutant caught "M3 the item test is negated (lever inverted)" "$JMZ" m3

# --- M4: the pullcad trap ----------------------------------------------------
m4() { perl -0pi -e "s/if not bHasRegen and J\.IsSoakCandidate\( 'staybag' \) then/if not bHasRegen and J.IsSoakCandidate( 'staybag' ) and J.IsSoakCandidate( 'staysrc' ) then/" "$JMZ"; }
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
# which names all three siblings sharing this function.
m8() { perl -0pi -e "s/                        return armed and sId == 'staybag'\n                    end\n\n                    -- The gold term/                        return armed\n                    end\n\n                    -- The gold term/" "$SWEEP"; }
mutant caught "M8 the stub arms every candidate, not just this one" "$SWEEP" m8

# --- M9: the partition stops partitioning ------------------------------------
m9() { perl -0pi -e "s/                                    bump\('blocked_no_bag'\)/                                    bump('blocked_with_bag')/" "$SWEEP"; }
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

# --- M12: ⭐ the two-id column is not measured -------------------------------
# The mutant this stand exists for. The finding is a RELATION between four
# drives; kill the pair drive and it degrades into a set of zeros that no other
# assertion in the file contradicts unless the relation itself is asserted.
m12() { perl -0pi -e "s/                        return sId == 'staysrc' or sId == 'bagsalve'\n/                        return false\n/" "$SWEEP"; }
mutant caught "M12 the PAIR drive arms nothing (the finding faked)" "$SWEEP" m12

# --- M13: DECLARED EQUIVALENT, and the declaration was earned the hard way ----
# This was written as `caught` -- "widen the slot range to 0-8 and the lever
# quietly does 'staysrc''s job too, destroying the disjointness the wave design
# rests on" -- and it SURVIVED. Rule 2 says suspect the assertion; the assertion
# was fine and the MODEL was wrong. The proof: control only reaches this block
# when `bHasRegen` is still false, and `bHasRegen` starts as the shipped
# `J.IsItemAvailable('item_flask')`, which already scans slots 0-5. So a
# main-slot salve can never be here to be found -- the frame was never vetoed in
# the first place. Adding slots 0-5 to THIS loop is a no-op on any corpus.
# Measured as well as argued: with the mutation applied, tests/_staybag_sweep.lua
# emits a byte-identical manifest (all 25 counters, all 15 carrier rows, both
# flip rows).
# ⭐ AND THE PROOF IS THE INTERESTING PART: this lever is one HALF-INVENTORY wide
# for the same reason it is one ITEM wide -- not because a gate keeps it there,
# but because everything else it could read is already answered above it. The
# thing that would genuinely destroy the disjointness is reading the other three
# consumables (that is M14), not reading more slots.
m13() { perl -0pi -e "s/\t\tfor i = 6, 8 do\n\t\t\tlocal hItem = bot:GetItemInSlot\( i \)\n\t\t\tif hItem ~= nil and hItem:GetName\(\) == 'item_flask' then/\t\tfor i = 0, 8 do\n\t\t\tlocal hItem = bot:GetItemInSlot( i )\n\t\t\tif hItem ~= nil and hItem:GetName() == 'item_flask' then/" "$JMZ"; }
mutant equivalent "M13 the slot range widens to 0-8 (provably a no-op)" "$JMZ" m13

# --- M14: the widening stops being one item wide -----------------------------
m14() { perl -0pi -e "s/\t\t\tif hItem ~= nil and hItem:GetName\(\) == 'item_flask' then/\t\t\tif hItem ~= nil and hItem:GetName() == 'item_tango' then/" "$JMZ"; }
mutant caught "M14 it reads the backpacked TANGO (no swapper exists)" "$JMZ" m14

# --- M15: the control --------------------------------------------------------
m15() { perl -0pi -e "s/-- \[staybag \/ owner priority P2, 2026-09-05\] The BACKPACK half/-- [staybag \/ owner priority P2, 2026-09-05] The backpack HALF/" "$JMZ"; }
mutant survive "M15 a comment inside the lever's own block is reworded" "$JMZ" m15

# --- M16: the census measures the wrong population ---------------------------
m16() { perl -0pi -e "s/local function bag_salve\(bot\)\n    for i = 6, 8 do/local function bag_salve(bot)\n    for i = 0, 8 do/" "$SWEEP"; }
mutant caught "M16 the backpack probe scans the main slots too" "$SWEEP" m16

# --- M17: DECLARED UNMEASURABLE ----------------------------------------------
# See the header: no backpack-salve frame in this corpus carries a main-slot
# source, so a constant-false probe and a real one print the same 0.
m17() { perl -0pi -e "s/local function main_src\(bot\)\n    for i = 0, 5 do/local function main_src()\n    if true then return false end\n    for i = 0, 5 do/" "$SWEEP"; }
mutant unmeasurable "M17 the main-slot probe stops calling the engine" "$SWEEP" m17

# --- M18, M19: the justification is unanchored -------------------------------
# The shipped, ungated swapper is the ENTIRE argument for widening by one item.
# Rename it and the argument evaporates while the lever still passes every gate
# test that only looks at itself.
m18() { perl -0pi -e "s/function TrySwapInvItemForFlask\(\)/function TrySwapInvItemForFlaskDisabled()/" "$ROAM"; }
mutant caught "M18 the shipped flask swapper is renamed away" "$ROAM" m18

# The defect fixed UPSTREAM of the lever: the shipped stock read starts seeing
# the backpack, so this lever is a no-op that still passes its own gate tests.
m19() { perl -0pi -e "s/\tif slot >= 0 and slot <= 5\n/\tif slot >= 0 and slot <= 8\n/" "$JMZ"; }
mutant caught "M19 J.IsItemAvailable widens to slot 8 (lever no-ops)" "$JMZ" m19

echo "---"
echo "mutants run: $nrun   landed as declared: $ncaught   unmeasurable+equivalent: $nunmeas   NOT as declared: $nbad"
if [ "$nbad" -ne 0 ]; then
    echo "STAND RED: $nbad mutant(s) did not land as declared."
    exit 1
fi
echo "STAND GREEN"
exit 0
