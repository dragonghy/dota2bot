#!/usr/bin/env bash
# Mutation stand for the three ratchets GH #458 re-measured and re-pinned.
#
# WHAT IT IS FOR. All three repairs live in ASSERTIONS OVER THE FIXTURE CORPUS,
# and the failure mode this repo keeps buying is an assertion that reads clean
# because it can no longer discriminate -- a `nCreepKeys == 0` that a bumped `1`
# would have satisfied without saying anything, a `>= 1` floor nothing can
# violate, a roles block whose consumers never look at it. So every repair is
# put back under a mutant that a correct assertion MUST catch.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every single mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_fixture_debt.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (per rule 2, suspect
# the assertion before the mutation). No AWS, no network, ~30s.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FIX=tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua
ANCHOR=tests/test_focus_innate_index_anchor.lua
BIND=tests/test_cm_ability_index_binding.lua
CAMPFARM=tests/test_campfarm_ancient_target.lua
ROLES=tests/test_fixture_roles.lua

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

nrun=0; ncaught=0

save() { cp "$1" "$TMP/$(basename "$1").orig"; sha256sum "$1" > "$TMP/$(basename "$1").sha"; }
restore() {
    cp "$TMP/$(basename "$1").orig" "$1"
    if ! sha256sum -c "$TMP/$(basename "$1").sha" >/dev/null; then
        echo "FATAL: restore of $1 did not verify -- stopping before anything else runs"
        exit 2
    fi
}

# Run one test file and report its BARE exit code (rule 3: never through a pipe).
run_test() {
    lua5.1 tests/run_tests.lua "$1" > "$TMP/out.log" 2>&1
    echo $?
}

mutant() {
    local label=$1 target=$2 expect_file=$3; shift 3
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    local rc; rc=$(run_test "$expect_file")
    restore "$target"
    if [ "$rc" -ne 0 ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-46s %s exit=%s\n' "$label" "$expect_file" "$rc"
    else
        printf 'SURVIVED  %-46s %s exit=%s\n' "$label" "$expect_file" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first."
    fi
}

# --- M1/M2: the creep-identity zero in test_campfarm_ancient_target -----------
# M1 is the mutant the OLD assertion could not have caught in the useful
# direction: give a creep row a name. `nCreepKeys == 0` (and an equally wrong
# `== 1`) both stay satisfied -- the count of FILES did not move -- while the
# fact this file rests on ("no creep here has an identity, so every creep below
# is declared by the test") has just become false.
m1() { sed -i "0,/{ team = 3, x = -452.3/s//{ name = 'npc_dota_neutral_black_dragon', team = 3, x = -452.3/" "$FIX"; }
mutant "M1 a creep row grows a name (identity appears)" "$FIX" "$(basename $CAMPFARM)" m1

# M2: the corpus loses the creeps sample entirely. A ratchet must catch a count
# going DOWN -- that is a deleted fixture or a behaviour change, not growth.
m2() { python3 - "$FIX" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n  creeps = \{.*?\n  \},", "", s, flags=re.S)
open(p, 'w').write(s)
PY
}
mutant "M2 the creeps block is deleted (count falls)" "$FIX" "$(basename $CAMPFARM)" m2

# --- M3/M4: the granted-ability denominator, pinned in TWO files --------------
# This is the defect GH #458 is about: one corpus fact pinned twice, re-baselined
# in one file and not the other. Both pins must have teeth, so both are mutated.
m3() { sed -i "s/{ name = 'zuus_lightning_hands', level = 1, cd = 0 }, //" "$FIX"; }
mutant "M3 the 2nd granted-ability frame is removed" "$FIX" "$(basename $ANCHOR)" m3
mutant "M4 the same, read by the sibling pin"        "$FIX" "$(basename $BIND)"   m3

# --- M5: the drafted roles ----------------------------------------------------
# The red this repair cleared. Without the block the loader falls back to the
# draft SLOT, which GH #57 measured at 47.3%.
m5() { python3 - "$FIX" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"\n  roles = \{.*?\n  \},", "", s, flags=re.S)
open(p, 'w').write(s)
PY
}
mutant "M5 the drafted roles block is removed"       "$FIX" "$(basename $ROLES)"  m5

# --- M6: the ratchet floor itself --------------------------------------------
# A floor of 0 is a pin that nothing can violate. If lowering it keeps the file
# green, the assertion was never load-bearing (rule 2's dangerous direction).
# Caught by the file's OWN companion: the CORPUS record and the section-2 pin
# must agree, so section 1's ratchet fires when only one of them is lowered.
m6() { sed -i 's/        zuus_lightning_hands = 2 } },/        zuus_lightning_hands = 3 } },/' "$ANCHOR"; }
mutant "M6 the CORPUS floor is raised past the truth" "$ANCHOR" "$(basename $ANCHOR)" m6

echo
echo "mutants: $ncaught/$nrun CAUGHT"
[ "$ncaught" -eq "$nrun" ] || exit 1
