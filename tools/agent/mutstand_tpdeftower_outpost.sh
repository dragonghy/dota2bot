#!/usr/bin/env bash
# Mutation stand for tests/test_tpdeftower_outpost_narrow.lua (GH #782, landed)
# and for the ONE assertion repaired in tests/test_tpdeftower_anchor_pricing.lua.
#
# WHY THIS EXISTS, AND WHY IT IS NOT THE SAME STAND AS mutstand_outpost_anchor.sh.
# The file under test makes its headline claim as a ZERO ("the shipped answer and
# the un-narrowed answer differ on 0 rows"), and on this corpus BOTH ARMS ANSWER
# IDENTICALLY -- which is the finding. That means no end-to-end count can tell a
# live counterfactual from a dead one: a `loose` arm that silently forgot to
# un-narrow the host would reproduce every number in the file. M6 is that mutant,
# and the only assertion that catches it is the direct read of the predicate off
# the J the driver itself returns. A stand that omitted M6 would certify a file
# whose central comparison was the tree against itself.
#
# M8 scores a DIFFERENT file on purpose. tests/test_tpdeftower_anchor_pricing.lua
# §7 carried a guard written the day before expressly to notice this narrowing
# landing -- `assert(host:find('watch_tower') == nil)` -- and it stayed GREEN
# through the landing, because the narrowing that got written calls the shared
# predicate and never spells `watch_tower` in the host. The guard was present and
# not load-bearing. M8 drops the conjunct and requires the REPAIRED guard to go
# red; under the old spelling that mutant was green in both directions, i.e. the
# guard was inert with respect to the very thing it named.
#
# DISCIPLINE (.claude/skills/evidence-discipline rules 1 and 3):
#   * restore from FILE COPIES kept OUTSIDE the tree, never `git checkout --`
#     (a pathspec typo there silently restores nothing and the mutants then
#     ACCUMULATE into a plausible-looking increasing table);
#   * `sha256sum -c` before and after every mutant, so "sed changed nothing"
#     can never be read as "the assertion did not catch it";
#   * exit codes read BARE, never through a pipe.
#
# ⛔ THE FILES UNDER TEST ARE DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY.
# Neither carries a private harness (GH #200/#387), so run directly each merely
# returns its table and exits 0 in silence -- which would score EVERY mutant as
# SURVIVED. Scoring therefore requires BOTH a non-zero runner exit AND the
# runner's own summary line; a run missing the summary is scored NOT-RUN rather
# than passed (a filter typo executes zero test bodies and must not read as a
# pass, GH #200).
#
# ⛔ TWO SITES SHARE THE CONJUNCT'S EXACT TEXT. `\t\tand not
# J.IsOutpostBuilding( building )` appears at BOTH J.ShouldRefuseUnsupportedPunish
# ('ohnum', jmz_func:9460) and this host (:10775). Every mutant below is anchored
# on the name-test line immediately above this one -- `building:GetUnitName()`
# with 'tower' -- which is unique to this host. An unanchored substitution would
# silently mutate the sibling lever and score its stand's failures as this one's.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_tpdeftower_outpost_narrow.lua
PRICE=tests/test_tpdeftower_anchor_pricing.lua
FILTER=tpdeftower_outpost_narrow
PFILTER=tpdeftower_anchor_pricing
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/test_narrow.lua" "$TEST"
    cp -f "$STAND/test_price.lua" "$PRICE"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$TEST" "$STAND/test_narrow.lua"
cp -f "$PRICE" "$STAND/test_price.lua"
( cd "$STAND" && sha256sum jmz_func.lua test_narrow.lua test_price.lua > base.sha )

MUTATE=MUTATE
CAUGHT=0
SURVIVED=0

restore() {
    restore_quiet
    ( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) \
        || { echo "STAND BROKEN: restore did not reproduce the baseline hashes"; exit 9; }
}

# run_mutant <label> <mutated-file> <filter> <expect-red-case-substring>
run_mutant() {
    local label="$1" target="$2" filter="$3" expect="$4"
    local before after
    before=$(sha256sum "$target" | cut -d' ' -f1)
    "$MUTATE"
    after=$(sha256sum "$target" | cut -d' ' -f1)
    if [ "$before" = "$after" ]; then
        echo "$label  NON-MUTANT: the edit changed zero bytes (a green here is"
        echo "       'nothing was mutated', NOT 'the assertion missed it')"
        SURVIVED=$((SURVIVED + 1))
        restore
        return
    fi
    local out rc
    out=$(lua5.1 tests/run_tests.lua "$filter" 2>&1)
    rc=$?
    if ! printf '%s' "$out" | grep -qE '[0-9]+ tests, [0-9]+ failures'; then
        echo "$label  NOT-RUN: the runner printed no summary line; rc=$rc"
        SURVIVED=$((SURVIVED + 1))
        restore
        return
    fi
    if [ "$rc" -eq 0 ]; then
        echo "$label  SURVIVED (rc=0 with the mutant in place)"
        SURVIVED=$((SURVIVED + 1))
    elif printf '%s' "$out" | grep -q "$expect"; then
        echo "$label  CAUGHT by the named case"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$label  CAUGHT, but by a DIFFERENT case than the one named ($expect):"
        printf '%s\n' "$out" | grep -i '^FAIL' | sed 's/^/         /'
        CAUGHT=$((CAUGHT + 1))
    fi
    restore
}

# The unique anchor: the name-test line that sits immediately above the conjunct
# in THIS host (see the header note on the two identical sites).
NAME_LINE="\t\tand string\.find\( building:GetUnitName\(\), 'tower' \) ~= nil\n"
CUT_LINE="\t\tand not J\.IsOutpostBuilding\( building \)\n"

# M1 -- delete the narrowing conjunct outright (the change never landed).
MUTATE() { perl -0pi -e "s/($NAME_LINE)$CUT_LINE/\$1/" "$JMZ"; }
run_mutant "M1 drop the narrowing conjunct        " "$JMZ" "$FILTER" \
    "the outpost narrowing is GONE"

# M2 -- keep it, but ahead of the name test (order mutant). Not cosmetic:
# `admitted_loose` in the file under test is this conjunction MINUS the cut, and
# §3 subtracts one from the other.
MUTATE() { perl -0pi -e "s/($NAME_LINE)($CUT_LINE)/\$2\$1/" "$JMZ"; }
run_mutant "M2 hoist it above the name test       " "$JMZ" "$FILTER" \
    "out of order"

# M3 -- break the outpost NAME inside the canonical predicate, so it matches
# nothing. The census parses that literal out of the source, so this is the
# mutant that would make every zero in §3 free.
MUTATE() { perl -0pi -e "s/'watch_tower' \) ~= nil/'watch_towerZZ' ) ~= nil/" "$JMZ"; }
run_mutant "M3 misname the outpost unit           " "$JMZ" "$FILTER" \
    "matched NOTHING"

# M4 -- nest a second soak id in the host (the pullcad trap, GH #606/#576).
MUTATE() {
    perl -0pi -e "s/(\tif not \( J\.IsSoakCandidate\( 'midtp' \) or bSup \) then return nil end\n)/\$1\tif not J.IsSoakCandidate( 'tpoutpost' ) then return nil end\n/" "$JMZ"
}
run_mutant "M4 nest a second soak id in the host  " "$JMZ" "$FILTER" \
    "a new soak id"

# M5 -- INVERT the predicate: every building EXCEPT an outpost reads as one, so
# the narrowing empties the tower loop and keeps exactly the outposts. Spelled so
# the census can still parse the literal, which is the point: this is the mutant
# that reaches §2's cross-check between the shipped predicate and the name lifted
# out of its own source. `pred_true` and `pred_false` are both still non-zero
# here -- the two liveness readings pass -- so nothing but the cross-check can
# catch it.
#
# ⚠️ A blanket-TRUE mutant that reaches §2 turns out not to exist on this corpus:
# the building names are `ancient` / `barracks` / `tower...` / `watch_tower`, and
# no single `[%w_]+` literal is a substring of all of them. Every blanket-true
# spelling is therefore either M9 (unparseable) or M3 (matches nothing).
MUTATE() {
    perl -0pi -e "s/\( nTarget:GetUnitName\(\), 'watch_tower' \) ~= nil/( nTarget:GetUnitName(), 'watch_tower' ) == nil/" "$JMZ"
}
run_mutant "M5 invert the outpost predicate       " "$JMZ" "$FILTER" \
    "disagrees with the literal"

# M9 -- the predicate stops testing a quoted literal at all (`and true`). Caught
# at LOAD, by the parser that lifts the outpost name out of the source instead
# of restating it -- the cure this round's header argues for. Kept separate from
# M5 because it never reaches a single count: a file that hard-coded the name
# would sail past this one and go on measuring a domain the code had abandoned.
MUTATE() {
    perl -0pi -e "s/\t\t\tand string\.find\( nTarget:GetUnitName\(\), 'watch_tower' \) ~= nil/\t\t\tand true/" "$JMZ"
}
run_mutant "M9 predicate loses its literal        " "$JMZ" "$FILTER" \
    "no longer tests a single quoted literal"

# M6 -- ⭐⭐ THE ONE THIS STAND EXISTS FOR. Make the `loose` arm forget to
# un-narrow the host. Every end-to-end count in §3 is unchanged (both arms
# already answer identically on this corpus), so ONLY the direct predicate read
# can catch it. If this ever survives, §3 is comparing the tree against itself.
MUTATE() {
    perl -0pi -e "s/    if loose then J\.IsOutpostBuilding = function\(\) return false end end\n//" "$TEST"
}
run_mutant "M6 dead counterfactual arm            " "$TEST" "$FILTER" \
    "did NOT neuter"

# M7 -- kill the census. A zero read off a dead sweep is not a zero: `SWEEP[k]`
# becomes an index into nil and `nil == nil` reads TRUE (GH #171 shape). The
# guard must name the case, not merely fail somewhere.
MUTATE() {
    perl -0pi -e "s/                bump\('frames'\)\n/                error('mutant: census killed')\n/" "$TEST"
}
run_mutant "M7 kill the corpus census             " "$TEST" "$FILTER" \
    "sweep DIED"

# M8 -- the sibling file's REPAIRED guard. Drop the conjunct again and score the
# PRICING file: it must notice that its sections 2-6 have stopped being history.
# Under the guard's previous spelling (`host:find('watch_tower') == nil`) this
# mutant was green, and so was its absence -- the guard was inert in both
# directions with respect to the event it named.
MUTATE() { perl -0pi -e "s/($NAME_LINE)$CUT_LINE/\$1/" "$JMZ"; }
run_mutant "M8 pricing guard notices the removal  " "$JMZ" "$PFILTER" \
    "outpost narrowing has been REMOVED"

echo "MUTSTAND caught=$CAUGHT survived=$SURVIVED"
( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) \
    && echo "FINAL_SHA_OK=yes" || echo "FINAL_SHA_OK=no"
[ "$SURVIVED" -eq 0 ] && echo "STAND GREEN" || echo "STAND RED"
exit 0
