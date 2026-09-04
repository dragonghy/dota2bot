#!/usr/bin/env bash
# Mutation stand for tests/test_fieldsrc_ff_premise.lua
# (owner priority P2 -- the "presence proves usability" premise under
# J.HasFieldRegenSource, measured on its faerie-fire leg).
#
# WHAT IT IS FOR. That test file's product is a CONCLUSION built out of zeros
# -- "no frame in the sole-faerie-fire population can eat the item it is being
# held for" -- and a zero is worth exactly as much as its ability to become
# non-zero. Three separate things have to be alive for the conclusion to mean
# anything, and each has its own mutants here:
#   * the census is tied to the SHIPPED consumer, not to numbers typed into a
#     test (M1, M2, M3, M5, M6, M11) -- every gate is parsed out of
#     ability_item_usage_generic.lua, so moving one must move the census;
#   * the census is tied to the SHIPPED presence test (M7, M9, M10) -- if the
#     faerie-fire leg leaves J.HasFieldRegenSource, or the situation band
#     narrows, the population this speaks about is not the one that was
#     measured;
#   * the MASKING claim is real (M8) -- "armed fieldsip already releases all 7"
#     is the reason nobody has seen this, and it stops being true the moment
#     the magnitude table says a faerie fire is worth staying for;
#   * ⭐ the CONCLUSION ITSELF is inverted (M4) -- the eat window opened and the
#     slot gate satisfied, so all 7 frames become eatable. A stand that cannot
#     produce that is not testing this file's product.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_fieldsrc_ff.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation -- and per its converse, first read the
# diff and confirm the mutant landed where you think it did: a regex that
# misses prints NO-OP here, and a regex that hits the WRONG function prints
# SURVIVED while the target is untouched). No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

AIUG=bots/ability_item_usage_generic.lua
JMZ=bots/FunLib/jmz_func.lua
TEST=fieldsrc_ff

TMP=$(mktemp -d)

nrun=0; ncaught=0

# INFLIGHT names the file that is mutated RIGHT NOW, or is empty when the tree
# is clean. Both targets are SHIPPED bot Lua, so leaving one mutated is the
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

# Every AIUG pattern below is anchored on the faerie-fire branch's own
# neighbouring line, never on the constant alone: `10 * 60`, `< 90` and `1800`
# all occur elsewhere in an 8,500-line file, and a stand that mutates the wrong
# occurrence reports SURVIVED about a site nobody is testing.

# --- M1: the eat window opens ------------------------------------------------
m1() { perl -0pi -e 's/if DotaTime\(\) > 10 \* 60\n\t\tand hItem:GetName\(\) == "item_faerie_fire"/if DotaTime() > 0 * 60\n\t\tand hItem:GetName() == "item_faerie_fire"/' "$AIUG"; }
mutant "M1 自己吃 time gate drops to 0" "$AIUG" m1

# --- M2: the slot gate inverts ----------------------------------------------
# `~= nil` to `== nil`: the branch then asks for an EMPTY backpack slot, which
# is what all 7 frames have. The census must follow the operator, not the
# constant -- this is why the sweep parses the operator at all.
m2() { perl -0pi -e 's/\t\tand bot:GetItemInSlot\( 6 \) ~= nil\n\t\tand bot:GetMaxHealth\(\)/\t\tand bot:GetItemInSlot( 6 ) == nil\n\t\tand bot:GetMaxHealth()/' "$AIUG"; }
mutant "M2 自己吃 slot gate inverts to 'slot 6 empty'" "$AIUG" m2

# --- M3: the slot gate disappears -------------------------------------------
# A deleted conjunct must not read as a satisfied one. The sweep cannot parse
# it, and the test has to say so instead of silently counting zero.
m3() { perl -0pi -e 's/\t\tand bot:GetItemInSlot\( 6 \) ~= nil\n//' "$AIUG"; }
mutant "M3 自己吃 slot gate deleted (parse must not read as 0)" "$AIUG" m3

# --- M4: ⭐ the conclusion is inverted ---------------------------------------
# Time gate open AND slot gate inverted, in one edit: every one of the 7 frames
# can now eat its faerie fire, i.e. the premise this file says is broken would
# hold. This is the single mutant the file exists to be able to fail on.
m4() { perl -0pi -e 's/if DotaTime\(\) > 10 \* 60\n\t\tand hItem:GetName\(\) == "item_faerie_fire"\n\t\tand bot:GetItemInSlot\( 6 \) ~= nil/if DotaTime() > 0 * 60\n\t\tand hItem:GetName() == "item_faerie_fire"\n\t\tand bot:GetItemInSlot( 6 ) == nil/' "$AIUG"; }
mutant "M4 the population becomes able to eat the item (inverts it)" "$AIUG" m4

# --- M5: the 撤退 branch floor stops being absolute-90 ------------------------
m5() { perl -0pi -e 's/\t\t and bot:WasRecentlyDamagedByAnyHero\( 3\.0 \)\n\t\t and bot:OriginalGetHealth\(\) < 90/\t\t and bot:WasRecentlyDamagedByAnyHero( 3.0 )\n\t\t and bot:OriginalGetHealth() < 900/' "$AIUG"; }
mutant "M5 撤退 branch health floor 90 -> 900" "$AIUG" m5

# --- M6: the function-wide fountain floor swallows the population ------------
m6() { perl -0pi -e 's/\tif bot:DistanceFromFountain\(\) < 1800 then return BOT_ACTION_DESIRE_NONE end/\tif bot:DistanceFromFountain() < 12000 then return BOT_ACTION_DESIRE_NONE end/' "$AIUG"; }
mutant "M6 faerie-fire fountain floor 1800 -> 12000" "$AIUG" m6

# --- M11: the 攻击 branch HP gate widens -------------------------------------
# The honest bound is a COUNT (2 of 7 unmeasurable). Widen the one conjunct a
# fixture can evaluate and the conclusion's 5 provable frames become 0.
m11() { perl -0pi -e 's/\t\tand J\.GetHP\( bot \) < 0\.3\n\t\tand J\.IsValidHero\( botTarget \)/\t\tand J.GetHP( bot ) < 0.9\n\t\tand J.IsValidHero( botTarget )/' "$AIUG"; }
mutant "M11 攻击 branch HP gate 0.3 -> 0.9 (eats the 5 proven frames)" "$AIUG" m11

# --- M7: the leg leaves the presence test ------------------------------------
# This is the FIX direction, and it must be loud: the population goes to zero,
# so every zero above becomes vacuously true and the ratchet is the only thing
# that notices.
m7() { perl -0pi -e "s/\t\t\t\tor sName == 'item_tango_single' or sName == 'item_faerie_fire'/\t\t\t\tor sName == 'item_tango_single'/" "$JMZ"; }
mutant "M7 faerie-fire leg removed from J.HasFieldRegenSource" "$JMZ" m7

# --- M8: the masking claim breaks -------------------------------------------
# fieldsip's table says a faerie fire is worth 400 -- then armed fieldsip stops
# releasing these frames, and the "it is currently masked" reading is false.
m8() { perl -0pi -e 's/\titem_faerie_fire  =  85,/\titem_faerie_fire  = 400,/' "$JMZ"; }
mutant "M8 FIELD_SIP_HEAL faerie fire 85 -> 400 (unmasks)" "$JMZ" m8

# --- M9: the situation band narrows -----------------------------------------
# The population is defined by J.IsFieldRegenSituation; move its ceiling and
# the census is about a different set of frames.
m9() { perl -0pi -e 's/\tif nHP < 0\.18 or nHP > 0\.55 then return false end/\tif nHP < 0.18 or nHP > 0.20 then return false end/' "$JMZ"; }
mutant "M9 field-regen HP band ceiling 0.55 -> 0.20" "$JMZ" m9

# --- M10: the contract sentence is rewritten ---------------------------------
# The finding is that a STATED contract is false for one leg. If the statement
# goes, the next reader has no way to know what the census is measuring against.
m10() { perl -0pi -e 's/already proves they are usable/are plausibly useful/' "$JMZ"; }
mutant "M10 the 'presence proves usability' contract sentence rewritten" "$JMZ" m10

echo
echo "mutants: $nrun   caught: $ncaught"
[ "$ncaught" -eq "$nrun" ]
