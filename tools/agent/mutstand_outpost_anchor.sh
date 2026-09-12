#!/usr/bin/env bash
# Mutation stand for tests/test_ohnum_outpost_anchor.lua (GH #782 second family).
#
# WHY THIS EXISTS. The file under test makes a NEGATIVE claim ("the corpus flip
# set is 0") next to a POSITIVE one ("an outpost releases the un-narrowed
# refusal"). Six of its nine cases are source-shape assertions, and a source
# assertion that is satisfied by the wrong text is indistinguishable from one
# that works. So each mutant below breaks one thing and names the case that must
# go red for it.
#
# DISCIPLINE (.claude/skills/evidence-discipline rules 1 and 3):
#   * restore from a FILE COPY kept OUTSIDE the tree, never `git checkout --`
#     (a pathspec typo there silently restores nothing and the mutants then
#     ACCUMULATE into a plausible-looking increasing table -- the 2026-08-30
#     self-inflicted wound);
#   * `sha256sum -c` before and after every mutant, so "sed changed nothing"
#     can never be read as "the assertion did not catch it";
#   * exit codes read BARE, never through a pipe.
#
# ⛔ THE FILE UNDER TEST IS DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY.
# A test file that carries its own harness passes standalone and decapitates the
# runner the first time it goes red (GH #200/#387), so it has none -- run
# directly it merely returns its table and exits 0 in silence, which would score
# EVERY mutant as SURVIVED. The runner is also what keeps the reading honest
# about a run that executed zero test bodies: it exits non-zero for that (GH
# #200), so a filter typo cannot read as a pass. Scoring therefore requires BOTH
# a non-zero runner exit AND the runner's own summary line, and a run missing
# the summary is scored NOT-RUN rather than passed.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_ohnum_outpost_anchor.lua
FILTER=ohnum_outpost_anchor
STAND=$(mktemp -d)
# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() { cp -f "$STAND/jmz_func.lua" "$JMZ"; }
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
( cd "$STAND" && sha256sum jmz_func.lua > base.sha )

MUTATE=MUTATE
CAUGHT=0
SURVIVED=0

restore() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    ( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) \
        || { echo "STAND BROKEN: restore did not reproduce the baseline hash"; exit 9; }
}

# run_mutant <label> <expect-red-case-substring>
run_mutant() {
    local label="$1" expect="$2"
    local before after
    before=$(sha256sum "$JMZ" | cut -d' ' -f1)
    "$MUTATE"
    after=$(sha256sum "$JMZ" | cut -d' ' -f1)
    if [ "$before" = "$after" ]; then
        echo "$label  NON-MUTANT: the edit changed zero bytes (a green here is"
        echo "       'nothing was mutated', NOT 'the assertion missed it')"
        SURVIVED=$((SURVIVED + 1))
        restore
        return
    fi
    local out rc
    out=$(lua5.1 tests/run_tests.lua "$FILTER" 2>&1)
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
    elif printf '%s' "$out" | grep -q "FAIL.*$expect"; then
        echo "$label  CAUGHT by the named case ($expect)"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$label  CAUGHT, but by a DIFFERENT case than the one named ($expect):"
        printf '%s\n' "$out" | grep '^FAIL' | sed 's/^/         /'
        CAUGHT=$((CAUGHT + 1))
    fi
    restore
}

# M1 -- delete the narrowing conjunct outright.
MUTATE() { perl -0pi -e 's/\t\tand not J\.IsOutpostBuilding\( building \)\n//' "$JMZ"; }
run_mutant "M1 drop the narrowing conjunct        " "the narrowing is in the ohnum release loop"

# M2 -- keep it, but move it AFTER the distance test (order mutant).
MUTATE() {
    perl -0pi -e 's/(\t\tand not J\.IsOutpostBuilding\( building \)\n)(\t\tand GetUnitToUnitDistance\( target, building \) <= 1200\n)/$2$1/' "$JMZ"
}
run_mutant "M2 move it after the distance test    " "before the distance test"

# M3 -- break the outpost NAME inside the canonical predicate.
MUTATE() { perl -0pi -e "s/'watch_tower' \) ~= nil/'watch_towerZZ' ) ~= nil/" "$JMZ"; }
run_mutant "M3 misname the outpost unit           " "outpost"

# M4 -- add a second soak id to the host (the pullcad trap).
MUTATE() {
    perl -0pi -e "s/(\tif not J\.IsSoakCandidate\( 'ohnum' \) then return false end\n)/\$1\tif not J.IsSoakCandidate( 'ohanchor' ) then return false end\n/" "$JMZ"
}
run_mutant "M4 nest a second soak id in the host  " "no new soak id"

# M5 -- make the predicate a blanket true (every building reads as an outpost).
MUTATE() {
    perl -0pi -e "s/\t\t\tand string\.find\( nTarget:GetUnitName\(\), 'watch_tower' \) ~= nil/\t\t\tand true/" "$JMZ"
}
run_mutant "M5 blanket: every building an outpost " "not a blanket"

# M6 -- fix it upstream instead, inside J.IsValidBuilding (the precondition).
MUTATE() {
    perl -0pi -e "s/(function J\.IsValidBuilding\( nTarget \)\n)/\$1\tif nTarget ~= nil and not nTarget:IsNull() and string.find( nTarget:GetUnitName(), 'watch_tower' ) ~= nil then return false end\n/" "$JMZ"
}
run_mutant "M6 narrow J.IsValidBuilding instead   " "precondition still holds"

echo "MUTSTAND caught=$CAUGHT survived=$SURVIVED"
( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) \
    && echo "FINAL_SHA_OK=yes" || echo "FINAL_SHA_OK=no"
[ "$SURVIVED" -eq 0 ] && echo "STAND GREEN" || echo "STAND RED"
exit 0
