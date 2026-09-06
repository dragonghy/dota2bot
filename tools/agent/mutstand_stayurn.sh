#!/usr/bin/env bash
# Mutation stand for tests/test_stayurn_ally_heal.lua (test_set.md §FN).
#
# WHAT IT IS FOR. J.ShouldStayAndRegen is PROMOTED -- live in every turbo game --
# and its supply read is a stack of SLOT reads: shipped `bHasFlask` asks
# J.IsItemAvailable (slots 0-5), 'staysrc' asks J.HasFieldRegenSource
# (`for i = 0, 5`), 'staybag'/'bagsalve' extend the same question to the
# backpack. An urn heal is cast BY AN ALLY, so the item and the patient sit in
# different inventories and no widening of any of those reads can ever see it.
# The 'stayurn' lever adds the one modifier this family's own vocabulary was
# missing, worth 2 frames on a 1012-frame corpus -- one of which holds no urn at
# all.
#
# The case has three halves and they forge differently:
#   (a) the BEHAVIOUR: a DRIVEN before/after of the shipped function on real
#       frames with one soak id toggled, cross-checked against a prefix walk;
#   (b) ⭐ the DIRECTION claim. Widening `bHasRegen` can only REMOVE vetoes, so
#       `flip_true_to_false` must be 0 -- and a counter whose content is all
#       zeros cannot tell "the direction holds" from "the tally never ran". Both
#       directions go through ONE tally() called twice with the legs swapped;
#       M11 and M11b attack that construction rather than the lever;
#   (c) ⭐ the "THE TREE ALREADY KNEW" claim, which is the whole condition-(c)
#       argument: three OTHER shipped sites treat 'modifier_item_urn_heal' as
#       "this hero is healing, do not send it home". Those are parsed off live
#       files, so removing one must go red (M6, M7) -- otherwise the argument is
#       prose that happens to be true today.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2);
#   * ⭐ THE DIRECTION IS BROKEN (M3) -- the `not bHasRegen` guard leaves, so the
#     assignment OVERWRITES a TRUE with false on every frame without the
#     modifier. Behaviourally this is the one mutation of this lever that can
#     make a bot go home MORE often, and the only thing standing between it and
#     a green suite is the flip_true_to_false counter;
#   * ⭐ THE BLOCK MOVES BELOW THE GOLD FALLBACK (M4) -- syntactically fine,
#     reachable, and dead: the veto it exists to remove has already returned;
#   * THE MODIFIER DRIFTS (M5) -- it reads the spirit vessel's modifier instead,
#     which 0 corpus frames carry. The mutant that looks like a widening;
#   * ⭐ A CORROBORATING SITE IS DELETED (M6, M7) -- the tpscroll '撤退:3' refusal
#     and aba_buff's `hero_is_healing` list. Condition (c) rests on those being
#     LIVE code, not on this comment's memory of them;
#   * ⭐ THE REFUSED WIDENING LANDS ANYWAY (M8) -- J.HasFieldRegenSource gains the
#     urn ITEM. That is the GH #542 pair-dependency this round priced and
#     refused; if it lands later, this suite must say so rather than let the
#     "standalone" argument lapse silently;
#   * THE TOGGLE STOPS TOGGLING (M9) -- the armed leg is driven disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction);
#   * THE ARMING IS TOO WIDE (M10) -- the stub arms every id, so a sibling
#     widening could move the answer while the flips are still credited here;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M11, M11b) -- the direction tally stops
#     being called. `flip_true_to_false` then reads exactly as it does when 1012
#     frames were driven and none went the wrong way: the GH #171 shape;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M12) -- strip_comments becomes
#     the identity, and this lever's comment quotes both modifier names, all
#     four sibling ids and the file paths verbatim;
#   * THE TWO ROUTES STOP BEING TWO (M13) -- the prefix walk drops the 1200 ring,
#     so `supply_tested` and the driven answer measure different sets;
#   * THE ANTI-VACUUM COLUMN GOES BLIND (M14) -- the carrier census reads the
#     vessel modifier, which nothing carries, so every carrier row disappears and
#     "the corpus has no urn heals" becomes indistinguishable from a measurement;
#   * THE CONTROL (C1) -- a comment-only edit inside the lever must SURVIVE. If
#     it is caught, something in the suite is satisfied by prose.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION, not a detail of the regex
# (GH #550, GH #555). `perl -0pi -e "s///"` without /g rewrites the FIRST match,
# so an anchor occurring twice cuts a site the label does not name -- and then
# prints CAUGHT, indistinguishable from a mutant that worked. This file is a
# minefield for that: `if not bHasRegen and J.IsSoakCandidate( '...' ) then`
# occurs FOUR times with only the id differing, and `bot:GetGold() < 90` occurs
# once as code and three times inside sibling comments. Every anchor declares its
# expected count and `anchor` proves it on every run.
#
# NOTE the quoting for multi-line needles: $'\n' (ANSI-C), never $(printf '\n')
# -- command substitution STRIPS trailing newlines, so the latter expands to the
# empty string and the needle silently collapses to one line and counts 0.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_stayurn.sh
#
# ⚠️ DO NOT EDIT THIS FILE WHILE IT IS RUNNING. bash reads a script by BYTE
# OFFSET as it executes; inserting bytes ahead of the current offset misaligns
# every later read and the run is void (paid for on 2026-09-06, one whole stand
# re-run).
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, first confirm the edit landed where you meant).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
SWEEP=tests/_stayurn_sweep.lua
AIUG=bots/ability_item_usage_generic.lua
BUFF=bots/FunLib/aba_buff.lua
TEST=stayurn

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

anchor() {
    local want=$1 file=$2 needle=$3
    local n
    n=$(NEEDLE="$needle" python3 -c 'import os,sys; sys.stdout.write(str(open(sys.argv[1]).read().count(os.environ["NEEDLE"])))' "$file" 2>/dev/null || true)
    [ -z "$n" ] && n=0
    if [ "$n" -ne "$want" ]; then
        printf 'ANCHOR    %-58s occurs %s time(s) in %s, expected %s\n' \
            "$needle" "$n" "$file" "$want"
        nbad=$((nbad + 1))
        return 1
    fi
    return 0
}

# want=caught (a real mutant), want=survive (a control), want=unmeasurable (a
# real mutant this corpus provably cannot catch, with the reason recorded at the
# call site). UNMEASURABLE is not a pass.
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

# --- M1, M2: the lever leaves, or lands inverted -----------------------------
# ⛔ The bare `if not bHasRegen and J.IsSoakCandidate( ` prefix occurs FOUR times
# in this function -- once per widening -- so every needle below carries the id.
anchor 1 "$JMZ" "	if not bHasRegen and J.IsSoakCandidate( 'stayurn' ) then"
m1() { perl -0pi -e "s/\tif not bHasRegen and J\.IsSoakCandidate\( 'stayurn' \) then/\tif not bHasRegen and not J.IsSoakCandidate( 'stayurn' ) then/" "$JMZ"; }
mutant caught "M1 the gate lands negated (shipped and armed legs swap)" "$JMZ" m1

anchor 1 "$JMZ" "	if not bHasRegen and J.IsSoakCandidate( 'stayurn' ) then"$'\n'"		bHasRegen = bot:HasModifier( 'modifier_item_urn_heal' )"$'\n'"	end"$'\n'
m2() { perl -0pi -e "s/\tif not bHasRegen and J\.IsSoakCandidate\( 'stayurn' \) then\n\t\tbHasRegen = bot:HasModifier\( 'modifier_item_urn_heal' \)\n\tend\n//" "$JMZ"; }
mutant caught "M2 the lever block is deleted outright" "$JMZ" m2

# --- M3: ⭐ the direction is broken -------------------------------------------
# Dropping `not bHasRegen` turns the assignment into an OVERWRITE: on every frame
# without the modifier a TRUE computed by the shipped read or by a sibling
# widening becomes false. This is the only mutation of this lever that can send a
# bot home MORE often, it passes every count that looks at the domain, and the
# only thing standing between it and a green suite is flip_true_to_false -- the
# counter that reads 0 on the real tree.
m3() { perl -0pi -e "s/\tif not bHasRegen and J\.IsSoakCandidate\( 'stayurn' \) then/\tif J.IsSoakCandidate( 'stayurn' ) then/" "$JMZ"; }
mutant caught "M3 the 'not bHasRegen' guard leaves (TRUE -> FALSE becomes possible)" "$JMZ" m3

# --- M4: ⭐ the block moves below the gold fallback ----------------------------
# Syntactically fine, reachable, and DEAD: `if not bHasRegen and GetGold() < 90
# then return false end` has already taken the frame away. Every structural fact
# about the lever's existence still reads TRUE; STAY_ORDER_OK and the flip count
# are what notice.
# ⛔ `bot:GetGold() < 90` appears once as CODE and three times inside sibling
# comments, so the anchor spans the two statements together.
anchor 1 "$JMZ" "		bHasRegen = bot:HasModifier( 'modifier_item_urn_heal' )"$'\n'"	end"$'\n'"	if not bHasRegen and bot:GetGold() < 90 then return false end"$'\n'
m4() { perl -0pi -e "s/\tif not bHasRegen and J\.IsSoakCandidate\( 'stayurn' \) then\n\t\tbHasRegen = bot:HasModifier\( 'modifier_item_urn_heal' \)\n\tend\n\tif not bHasRegen and bot:GetGold\(\) < 90 then return false end\n/\tif not bHasRegen and bot:GetGold() < 90 then return false end\n\tif not bHasRegen and J.IsSoakCandidate( 'stayurn' ) then\n\t\tbHasRegen = bot:HasModifier( 'modifier_item_urn_heal' )\n\tend\n/" "$JMZ"; }
mutant caught "M4 the block moves BELOW the gold fallback (reachable and dead)" "$JMZ" m4

# --- M5: the modifier drifts --------------------------------------------------
# It reads the spirit vessel's heal instead -- the urn's own upgrade, the fifth
# member of the same word list, and a modifier 0 of 1012 corpus frames carry.
# The mutant that looks like a generalisation.
m5() { perl -0pi -e "s/\t\tbHasRegen = bot:HasModifier\( 'modifier_item_urn_heal' \)/\t\tbHasRegen = bot:HasModifier( 'modifier_item_spirit_vessel_heal' )/" "$JMZ"; }
mutant caught "M5 the lever reads the vessel modifier instead (domain -> 0)" "$JMZ" m5

# --- M6, M7: ⭐ a corroborating site is deleted --------------------------------
# Condition (c) for this lever IS the other three sites. If deleting one leaves
# the suite green, the argument was this comment's memory rather than the tree's
# behaviour.
# ⛔ FIVE, NOT ONE -- and the anchor check is what said so, on this stand's first
# run. The item layer refuses a heal-or-go-home action on this modifier at five
# separate sites (5585, 5619, 5663 = the '撤退:3' branch, 5977, 6230; 5663 and
# 5977 are byte-identical for five lines). The first version of this mutant
# declared `anchor 1`, `perl s///` without /g deleted the FIRST of the five, the
# '撤退:3' copy survived untouched, the sweep's presence flag still read 1 and the
# mutant printed SURVIVED. Two things were wrong and only one of them was the
# mutant: the needle was not unique AND the fact it attacked was a presence flag
# where the argument is a COUNT. Both fixed -- the sweep counts the sites now, so
# deleting ANY of the five moves 5 -> 4 and the mutant no longer depends on which
# one perl reaches first.
anchor 5 "$AIUG" '			and not bot:HasModifier( "modifier_item_urn_heal" )'
m6() { perl -0pi -e 's/\t\t\tand not bot:HasModifier\( "modifier_item_urn_heal" \)\n//' "$AIUG"; }
mutant caught "M6 one of the FIVE item-layer urn-heal refusals is deleted" "$AIUG" m6

anchor 1 "$BUFF" '    "modifier_item_urn_heal",'
m7() { perl -0pi -e 's/    "modifier_item_urn_heal",\n//' "$BUFF"; }
mutant caught "M7 aba_buff's hero_is_healing list drops the urn modifier" "$BUFF" m7

# --- M8: ⭐ the refused widening lands anyway ----------------------------------
# Adding item_urn_of_shadows to J.HasFieldRegenSource is the move this round
# PRICED AND REFUSED (GH #542: it is only honest once 'urnself' is armed at a
# different site, and no single-arm wave can buy that pair). If a later round
# lands it, this suite has to say so -- otherwise the "standalone, unlike the
# carrier widening" argument lapses without anyone reading it again.
anchor 1 "$JMZ" "			if sName == 'item_flask'"
m8() { perl -0pi -e "s/\t\t\tif sName == 'item_flask'/\t\t\tif sName == 'item_urn_of_shadows'\n\t\t\t\tor sName == 'item_flask'/" "$JMZ"; }
mutant caught "M8 J.HasFieldRegenSource gains the urn ITEM (the refused widening)" "$JMZ" m8

# --- M9: the toggle stops toggling -------------------------------------------
# flips -> 0, i.e. "tested, no effect": the safe-looking direction.
# ⛔ TWICE, NOT ONCE. The sweep installs this stub, then swaps in a 'staysrc'-only
# stub for the sibling-overlap drive, then puts THIS ONE BACK -- so the line
# occurs twice and a bare needle rewrites whichever comes first. Declared as 1
# by the first version of this stand; the anchor check answered 2, and both
# mutants had been printing CAUGHT off a rewrite of a line their labels do not
# name. Pinned by the blank line that follows the FIRST copy (the restore is
# followed by `armed = false`).
anchor 1 "$SWEEP" "                        return armed and sId == 'stayurn'"$'\n'"                    end"$'\n'$'\n'
m9() { perl -0pi -e "s/                        return armed and sId == 'stayurn'\n                    end\n\n/                        return false\n                    end\n\n/" "$SWEEP"; }
mutant caught "M9 the armed leg is driven disarmed (flips -> 0)" "$SWEEP" m9

# --- M10: the arming is too wide ---------------------------------------------
m10() { perl -0pi -e "s/                        return armed and sId == 'stayurn'\n                    end\n\n/                        return armed\n                    end\n\n/" "$SWEEP"; }
mutant caught "M10 the stub arms EVERY id (flips credited to the wrong lever)" "$SWEEP" m10

# --- M11, M11b: ⭐ a zero that was never measured ------------------------------
# `flip_true_to_false` must be 0. Its content is all zeros on this corpus, so
# deleting the real call leaves it reading exactly as a measured 0 -- unless the
# SWAPPED call is what makes it falsifiable. Both removals must go red, and that
# is the whole construction: the branch asserted to be 0 is the branch that must
# report the whole domain when the legs are exchanged.
anchor 1 "$SWEEP" "                        tally(shipped, arm, 'flip_true_to_false', 'flips')"
m11() { perl -0pi -e "s/                        tally\(shipped, arm, 'flip_true_to_false', 'flips'\)\n//" "$SWEEP"; }
mutant caught "M11 the real direction tally is removed" "$SWEEP" m11

anchor 1 "$SWEEP" "                        tally(arm, shipped, 'flip_true_to_false_swapped',"
m11b() { perl -0pi -e "s/                        tally\(arm, shipped, 'flip_true_to_false_swapped',\n                            'flips_swapped'\)\n//" "$SWEEP"; }
mutant caught "M11b the SWAPPED tally is removed (the 0 becomes vacuous)" "$SWEEP" m11b

# --- M12: the instrument reads prose instead of code -------------------------
anchor 1 "$SWEEP" "    return (s:gsub('%-%-[^\\n]*', ''))"
m12() { perl -0pi -e "s/    return \(s:gsub\('%-%-\[\^\\\\n\]\*', ''\)\)/    return s/" "$SWEEP"; }
mutant caught "M12 strip_comments becomes the identity (prose satisfies code)" "$SWEEP" m12

# --- M13: the two routes stop being two --------------------------------------
anchor 1 "$SWEEP" "                        local bReach = bChase"
m13() { perl -0pi -e "s/                        local bReach = bChase\n                            and #J\.GetNearbyHeroes\(bot, RING, true,\n                                BOT_MODE_NONE\) == 0\n/                        local bReach = bChase\n/" "$SWEEP"; }
mutant caught "M13 the prefix walk drops the 1200 ring (routes diverge)" "$SWEEP" m13

# --- M14: the anti-vacuum column goes blind ----------------------------------
# With the census reading a modifier nothing carries, every carrier row and every
# stop-reason bucket empties. "The corpus has no urn heals" then reads exactly
# like a measurement, which is the shape the B rows exist to prevent.
anchor 1 "$SWEEP" "                    local bMod = bot:HasModifier(MOD) and true or false"
m14() { perl -0pi -e "s/                    local bMod = bot:HasModifier\(MOD\) and true or false/                    local bMod = bot:HasModifier(VESSEL) and true or false/" "$SWEEP"; }
mutant caught "M14 the carrier census reads the vessel modifier (rows vanish)" "$SWEEP" m14

# --- C1: the control ---------------------------------------------------------
anchor 1 "$JMZ" "	-- [stayurn / owner priority P2, 2026-09-06] The member of this family's own"
c1() { perl -0pi -e "s/\t-- \[stayurn \/ owner priority P2, 2026-09-06\] The member of this family's own/\t-- [stayurn \/ owner priority P2, 2026-09-06] THE MEMBER of this family's own/" "$JMZ"; }
mutant survive "C1 comment-only edit inside the lever" "$JMZ" c1

printf '\nSTAND: %d mutants run, %d landed as declared, %d unmeasurable, %d unexpected\n' \
    "$nrun" "$ncaught" "$nunmeas" "$nbad"
if [ "$nbad" -eq 0 ] && [ "$nunmeas" -eq 0 ]; then
    echo 'STAND GREEN'
    exit 0
fi
if [ "$nbad" -eq 0 ]; then
    echo 'STAND AMBER -- every mutant landed as declared, but some are UNMEASURABLE'
    exit 0
fi
echo 'STAND RED'
exit 1
