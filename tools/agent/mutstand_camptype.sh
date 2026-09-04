#!/usr/bin/env bash
# Mutation stand for tests/test_camp_type_premise_polarity.lua
# (OWNER_PRIORITIES P1 / GH #241 -- the `.type` half of the GetNeutralSpawners
# premise, and the polarity precondition on §BN.4).
#
# WHAT IT IS FOR. That test file's whole product is a CONCLUSION -- "no
# camp-record `.type` site fails closed, therefore §BN.4 cannot settle this
# premise from behaviour we already own" -- and a conclusion asserted as a
# count is worth exactly as much as the count's ability to change. Ten of its
# twelve legs passed on the first run; the two that did not are the reason this
# stand exists at all (one of them was the conclusion reporting a FAIL-CLOSED
# site that did not exist, because a selector's WINNER is not a monotone
# quantity -- now pinned as its own row).
#
# The shapes under test:
#   * the refuter stops being a refuter (M1, M7, M9) -- if a helper starts
#     answering TRUE for a non-string `.type`, or its string literal drifts,
#     the two columns stop being two columns and every subset below is vacuous;
#   * a tier is LOST (M2) -- the direction "the refuter is wider" survives
#     losing the ancient tier entirely (the large tier alone still widens 27 of
#     40 cells), which is why the ladder is pinned as three cells, not as a
#     direction;
#   * the invariance claim breaks (M3) -- RefreshCamp's fall-through chain is
#     the one reader no measurement can ever press, and that is a property of
#     the CHAIN, not of the function; make one branch discriminate and the
#     claim is false;
#   * a `.type` reader escapes the census (M4, M5) -- a new reader, or a
#     shipped clause that quietly flips its operator;
#   * the fix that makes the selector read the record is reverted (M6);
#   * ⭐ the CONCLUSION ITSELF is inverted (M8) -- one site made to fail closed.
#     That is the single finding that would let §BN.4 settle `.type` for free,
#     so a stand that cannot produce it is not testing the thing this file is
#     for.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_camptype.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation -- and per its converse, first read the
# diff and confirm the mutant landed where you think it did: a regex that
# misses prints NO-OP here, and a regex that hits the WRONG function prints
# SURVIVED while the target is untouched). No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SITE=bots/FunLib/aba_site.lua
TA=bots/BotLib/hero_templar_assassin.lua
TEST=camp_type_premise

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

# --- M1: the refuter is accommodated ----------------------------------------
# If IsAncientCamp starts answering TRUE for the int as well, the "int" column
# is no longer a refuting hypothesis and every subset relation below it becomes
# a comparison of a table with itself.
m1() { perl -0pi -e 's/return camp\.type == "ancient"\n/return camp.type == "ancient" or camp.type == 4\n/' "$SITE"; }
mutant "M1 IsAncientCamp also accepts the refuting int" "$SITE" m1

# --- M2: a whole tier is lost -----------------------------------------------
# The ancient tier deleted. The DIRECTION ("the refuter admits more") survives
# this untouched -- the large tier alone still widens 27 of the 40 level/damage
# cells -- so only the three pinned cells can see it.
m2() { perl -0pi -e 's/    if ____exports\.IsAncientCamp\(camp\) and botLevel < 12 then\n        return false\n    end\n//' "$SITE"; }
mutant "M2 campgrade ladder loses its ancient tier" "$SITE" m2

# --- M3: the fall-through chain starts discriminating ------------------------
# RefreshCamp's unconditional `else` is what makes the whole chain silent about
# `.type`. Turn it into a clause and the shipped, UNARMED list becomes
# `.type`-sensitive -- i.e. the "no measurement can press this reader" half of
# the conclusion is false.
m3() { perl -0pi -e 's/            else\n                allCampList\[#allCampList \+ 1\] = \{idx = camp\.idx, cattr = camp\}\n            end/            elseif not ____exports.IsAncientCamp(camp) then\n                allCampList[#allCampList + 1] = {idx = camp.idx, cattr = camp}\n            end/' "$SITE"; }
mutant "M3 RefreshCamp else-branch becomes a .type clause" "$SITE" m3

# --- M4: a shipped clause flips its operator ---------------------------------
# `~=` to `==` in Templar Assassin's camp filter. Under the refuter this site
# would then fail CLOSED (a number is never equal to "small"), which is exactly
# the classification the census must not miss.
m4() { perl -0pi -e 's/and camp\.type ~= "small"/and camp.type == "small"/' "$TA"; }
mutant "M4 templar_assassin small clause flips to ==" "$TA" m4

# --- M5: a new `.type` reader appears ----------------------------------------
# The census is a ratchet over a CLOSED set of sites; an unclassified reader
# voids the conclusion silently, because the conclusion only drives the sites
# it knows about.
m5() { perl -0pi -e 's/____exports\.IsEnemyCamp = function\(camp\)/____exports.IsAncientish = function(camp)\n    return camp.type ~= nil\nend\n____exports.IsEnemyCamp = function(camp)/' "$SITE"; }
mutant "M5 a new unclassified .type reader is added" "$SITE" m5

# --- M6: the campsel fix is reverted -----------------------------------------
# The selector goes back to reading the WRAPPER even when armed. Both columns
# then answer identically, so the one site that demonstrably fails open stops
# demonstrating anything -- and the shipped-vs-armed contrast in polarity 3
# collapses.
m6() { perl -0pi -e 's/        if bReadCampRecord and camp\.cattr ~= nil then\n            rec = camp\.cattr\n        end\n//' "$SITE"; }
mutant "M6 armed selector reads the wrapper again" "$SITE" m6

# --- M7 / M9: a string literal drifts ----------------------------------------
# `"ancient"` / `"large"` are the only reason the string column differs from
# the int column at all. A capitalisation drift makes the helper answer FALSE
# for both, which reads as "no domain" rather than as a typo.
m7() { perl -0pi -e 's/return camp\.type == "ancient"/return camp.type == "Ancient"/' "$SITE"; }
mutant "M7 IsAncientCamp literal capitalised" "$SITE" m7

m9() { perl -0pi -e 's/return camp\.type == "large"/return camp.type == "huge"/' "$SITE"; }
mutant "M9 IsLargeCamp literal drifts to \"huge\"" "$SITE" m9

# --- M8: ⭐ the conclusion is inverted ---------------------------------------
# One site made to FAIL CLOSED: negate the ladder's ancient test, so under the
# refuter (every tier predicate false) the clause refuses EVERY camp below 12,
# while the string column still admits the ancient one. That is a real
# fail-closed site -- the single finding that would let §BN.4 settle `.type`
# from games we already own -- and a stand that cannot produce it is not
# testing this file's product.
m8() { perl -0pi -e 's/    if ____exports\.IsAncientCamp\(camp\) and botLevel < 12 then/    if not ____exports.IsAncientCamp(camp) and botLevel < 12 then/' "$SITE"; }
mutant "M8 a site is made to FAIL CLOSED (inverts the conclusion)" "$SITE" m8

echo
echo "mutants: $nrun   caught: $ncaught"
[ "$ncaught" -eq "$nrun" ]
