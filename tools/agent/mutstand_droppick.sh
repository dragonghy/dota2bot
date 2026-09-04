#!/usr/bin/env bash
# Mutation stand for tests/test_droppick_domain.lua (test_set.md §EK).
#
# WHAT IT IS FOR. This round lands NO behaviour change: the whole product is
# three columns of counts plus one verdict ("the repair is two-part or it is
# nothing"). The headline is a COMPARISON between three legs of the same sweep,
# driven through the same two shipped functions, and two of those legs read
# zero. A zero leg is the cheapest possible green: a probe that stopped asking,
# a control that stopped controlling, and a censored raise bucket all produce
# exactly the numbers this file reports. So most mutants here are INSTRUMENT
# mutants -- and the ones that are not are the two halves of the repair, each
# landed alone, because "landing one half alone" is the specific mistake the
# file exists to make expensive.
#
# The shapes under test:
#   * ONE HALF OF THE REPAIR LANDS (M1, M2) -- the arity half or the index-space
#     half, alone. Both must turn this file red saying "re-read the pricing",
#     because the pricing's only claim is about the pair;
#   * the subject changes shape (M3, M4, M5) -- the write-only set gains a
#     reader, the set API loses its second parameter, a fourth read appears.
#     Each makes one sentence of the finding stale while every count stays
#     plausible;
#   * the second finding's subject moves (M6, M7) -- ItemOpsDesire's return
#     stops being discarded, or the housekeeping tail the early return starves
#     gets shorter;
#   * the DECOY COLUMN SILENTLY BECOMES THE CONTROL (M8) -- the argfix leg keys
#     by name instead of by handle. Then "the one-line repair is a no-op" is
#     measured against a leg that is not the one-line repair, and the file's
#     headline is a comparison of the control with itself;
#   * the CONTROL STOPS CONTROLLING (M9) -- bothfix keys by something no reader
#     asks for. Every column now reads zero, which is *consistent*, and the
#     anti-vacuum assertion is the only thing standing between that and a
#     published finding;
#   * a raise bucket is deleted (M10) -- GH #492's defect re-committed inside
#     the instrument that cites it: raises fold into "measured no" and the
#     denominator shrinks without saying so;
#   * the denominator collapses (M11) -- no handles are probed at all, and
#     "0 of 0" reads as "0 of 5932" to every assertion that is not anti-vacuum;
#   * the domain probe stops asking (M12) -- THE dangerous direction. The
#     reported 0 for dropped-item frames is what forbids landing a fix; if it
#     can be produced by not asking, the whole "unbuyable at any price" verdict
#     is unfalsifiable. This mutant answers `{}` from a literal instead of from
#     the engine getter and must still be caught.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_droppick.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (rule 2: suspect the
# assertion before the mutation -- and per its converse, read the diff first: a
# regex that misses prints NO-OP, a regex that hits the wrong place prints
# SURVIVED while the subject is untouched; that converse cost the midsupmirror
# stand two rounds on one `perl s///` without /g).
#
# SLOW ON PURPOSE: every mutant re-runs a 109-fixture, 5932-handle sweep (~38s),
# so the stand takes ~8 minutes. The sweep is the thing under test; running it
# once and reusing the output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MODE=bots/mode_team_roam_generic.lua
UTILS=bots/FunLib/utils.lua
SWEEP=tests/_droppick_sweep.lua
TEST=test_droppick_domain

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

# --- M1, M2: one half of the repair lands, alone -----------------------------
# The whole verdict is "two-part or nothing". Either half arriving on its own is
# the reviewable-looking no-op this file was written to price, so the file must
# stop being green the moment one shows up in the tree.
m1() { perl -0pi -e 's/SetContains\(itemName\)/SetContains(ignorePickupList, itemName)/g' "$MODE"; }
mutant "M1 the arity half lands alone (3 reads gain an arg)" "$MODE" m1

m2() { perl -0pi -e 's/Utils\.AddToSet\(ignorePickupList, PickedItem\.item\)/Utils.AddToSet(ignorePickupList, itemName)/' "$MODE"; }
mutant "M2 the index-space half lands alone (write keys by name)" "$MODE" m2

# --- M3..M5: the subject changes shape ---------------------------------------
# "write-only set", "(set, key) API", "exactly three reads" are three separate
# sentences of the finding. Each can go stale on its own while every measured
# count stays exactly as reported.
m3() { perl -0pi -e 's/            if tryPickCount >= 3 and not Utils\.SetContains\(itemName\) then/            if tryPickCount >= 3 and ignorePickupList ~= nil and not Utils.SetContains(itemName) then/' "$MODE"; }
mutant "M3 the write-only ignore set gains a reader" "$MODE" m3

m4() { perl -0pi -e 's/function ____exports\.SetContains\(set, key\)/function ____exports.SetContains(set)/' "$UTILS"; }
mutant "M4 SetContains loses its second parameter" "$UTILS" m4

m5() { perl -0pi -e 's/            local itemName = PickedItem\.item:GetName\(\)/            local itemName = PickedItem.item:GetName()\n            local nIgnored = Utils.SetContains(itemName)/' "$MODE"; }
mutant "M5 a fourth SetContains read appears" "$MODE" m5

# --- M6, M7: the discarded-desire finding loses its subject ------------------
# The second finding is that the retry loop's `return` is only a skip. Give the
# value a consumer, or shorten the tail it skips, and that sentence is no longer
# something the tree says.
m6() { perl -0pi -e 's/\n    ItemOpsDesire\(\)\n/\n    local nItemDesire = ItemOpsDesire()\n/' "$MODE"; }
mutant "M6 ItemOpsDesire's return value gains a consumer" "$MODE" m6

m7() { perl -0pi -e 's/\n    SwapSmokeSupport\(\)//' "$MODE"; }
mutant "M7 one starved housekeeping call leaves the tail" "$MODE" m7

# --- M8: the decoy column silently becomes the control -----------------------
# THE mutant. `argfix` is supposed to be line 1821 verbatim -- keyed by the item
# HANDLE. Key it by name instead and the leg still runs, still produces a
# number, and the number is the control's. The file would then be reporting
# "the one-line repair does nothing" about a leg that is not the one-line
# repair, and would report it in the opposite direction without complaining.
m8() { perl -0pi -e 's/                                    AddToSet\(ignoreA, hItem\)/                                    AddToSet(ignoreA, itemName)/' "$SWEEP"; }
mutant "M8 the argfix leg keys by name instead of by handle" "$SWEEP" m8

# --- M9: the control stops controlling ---------------------------------------
# With bothfix keyed by something no reader asks for, all three columns read
# zero. That is internally consistent, matches every "is a no-op" assertion, and
# is exactly what a stuck probe looks like. Only the anti-vacuum universal
# stands between it and a published finding.
m9() { perl -0pi -e 's/                                    AddToSet\(ignoreB, itemName\)/                                    AddToSet(ignoreB, {})/' "$SWEEP"; }
mutant "M9 the bothfix control keys by nothing any reader asks" "$SWEEP" m9

# --- M10: a raise bucket is deleted ------------------------------------------
# GH #492's own defect, re-committed inside the instrument that cites it. Drop
# the counter from the initialiser and it is emitted only if something raises --
# so on a clean corpus it vanishes entirely, and every downstream reader that
# treats an absent counter as a zero silently loses the three-valued discipline.
m10() { perl -0pi -e "s/    'shipped_ignored', 'shipped_raise',/    'shipped_ignored',/" "$SWEEP"; }
mutant "M10 the shipped raise bucket stops being emitted" "$SWEEP" m10

# --- M11: the denominator collapses ------------------------------------------
# No handles probed at all. Every "0 of them" assertion is then satisfied by
# vacuum, and the reported zeros are indistinguishable from the real ones.
m11() { perl -0pi -e 's/                    for slot = 0, 8 do/                    for slot = 0, -1 do/' "$SWEEP"; }
mutant "M11 no item handles are probed at all" "$SWEEP" m11

# --- M12: the domain probe stops asking --------------------------------------
# The dangerous direction, and the reason this file may say "do not land a fix".
# `drop_frames == 0` is what makes the decision unbuyable; if that zero can come
# from a literal instead of from the engine getter the shipped tree reads, the
# verdict is unfalsifiable rather than measured.
m12() { perl -0pi -e 's/                    local okd, drops = pcall\(GetDroppedItemList\)/                    local okd, drops = pcall(function() return {} end)/' "$SWEEP"; }
mutant "M12 the dropped-item probe answers from a literal" "$SWEEP" m12

echo
echo "$ncaught/$nrun mutants CAUGHT"
[ "$ncaught" -eq "$nrun" ] || exit 1
