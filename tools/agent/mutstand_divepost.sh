#!/usr/bin/env bash
# Mutation stand for tests/test_divepost_outpost_narrow.lua (GH #796, landed).
#
# WHAT THIS STAND HAS TO PROVE THAT THE SIBLING STANDS DID NOT. The file under
# test makes its headline claim as a ZERO ("arming divepost changes 0 answers"),
# so no end-to-end count can separate a live knife from dead code. The sibling
# stand (mutstand_tpdeftower_outpost.sh) answered that with ONE counterfactual
# arm. This landing sits under a PROMOTED helper -- J.ShouldPunishDive runs in
# every turbo game -- so the file must answer a SECOND question the gated
# siblings never had to: is the conjunct actually GATED, or is it changing
# shipped play right now? Two mutants carry those two questions:
#
#   * M6 kills the counterfactual arm C  => only "load-bearing" is at risk.
#   * M4 ⭐⭐ leaves every byte §1 reads in place and overwrites the gate one
#     line later (`bDivePost = true`). Every text assertion passes, §2 and §3
#     pass, and the ONLY thing that goes red is arm D -- the arm that drives the
#     UNARMED helper with the outpost predicate forced true. M4 is the mutant
#     that says whether arm D is load-bearing, and arm D is the assertion that
#     says whether this landing is inert in shipped play.
#
# ⛔ WHY THERE IS NO MUTANT FOR THE ADMISSION ORDER. The conjunct's position
# between `J.IsValidBuilding` and the distance test is a STRUCTURAL claim (it is
# inside the one `if` condition), not an execution-order requirement: the
# predicate null-checks its own argument, so hoisting it would change nothing
# the corpus could see. §1 pins the bracketing for that reason and this stand
# does not pretend the order is behaviour. (The sibling file's order assertion
# IS behaviour: its test recomputes the same conjunction minus one term.)
#
# DISCIPLINE (.claude/skills/evidence-discipline rules 1 and 3):
#   * restore from FILE COPIES kept OUTSIDE the tree, never `git checkout --`
#     (a pathspec typo silently restores nothing and mutants then ACCUMULATE
#     into a plausible-looking table);
#   * `sha256sum -c` before and after every mutant, so "sed changed nothing"
#     can never be read as "the assertion did not catch it";
#   * exit codes read BARE, never through a pipe.
#
# ⛔ SCHEDULING (this desk's own 2026-09-13 lesson): DO NOT RUN THIS
# CONCURRENTLY WITH tools/agent/routine_selfcheck.sh. A mutation stand writes
# real defects into git-tracked files by definition, and the selfcheck's
# trunk-health legs read those same files -- a half-written jmz_func.lua reads
# back to it as a syntax error that is not there.
#
# ⛔ THE FILES ARE DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY (GH
# #200/#387): run directly the file merely returns its table and exits 0 in
# silence, which would score EVERY mutant as SURVIVED. Scoring therefore
# requires BOTH a non-zero runner exit AND the runner's own summary line; a run
# missing the summary is scored NOT-RUN rather than passed.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_divepost_outpost_narrow.lua
FILTER=divepost_outpost_narrow
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/test_divepost.lua" "$TEST"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$TEST" "$STAND/test_divepost.lua"
( cd "$STAND" && sha256sum jmz_func.lua test_divepost.lua > base.sha )

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

# The conjunct, and the unique anchor line above it. The bare text `and not
# J.IsOutpostBuilding( building )` exists at TWO other sites in this file
# (J.ShouldRefuseUnsupportedPunish and J.ShouldTpSupportTowerFight); the gated
# spelling below is unique to this host, so every substitution is anchored on it.
CUT_LINE="\t\t\t\tand not \( bDivePost and J\.IsOutpostBuilding\( building \) \)\n"
GATE_LINE="\tlocal bDivePost = J\.IsSoakCandidate\( 'divepost' \)\n"

# M1 -- delete the narrowing conjunct outright (the change never landed).
MUTATE() { perl -0pi -e "s/$CUT_LINE//" "$JMZ"; }
run_mutant "M1 drop the narrowing conjunct        " "$JMZ" "$FILTER" \
    "the outpost narrowing is GONE"

# M2 -- land it UN-GATED (the shape that changes shipped play under a promoted
# helper). Caught at the text level here; M4 is the version of this defect that
# text cannot see.
MUTATE() {
    perl -0pi -e "s/$CUT_LINE/\t\t\t\tand not J.IsOutpostBuilding( building )\n/" "$JMZ"
}
run_mutant "M2 land the conjunct un-gated        " "$JMZ" "$FILTER" \
    "the outpost narrowing is GONE"

# M3 -- break the outpost NAME inside the canonical predicate so it matches
# nothing. The census parses that literal out of the source, so this is the
# mutant that would make every zero in §3 free.
MUTATE() { perl -0pi -e "s/'watch_tower' \) ~= nil/'watch_towerZZ' ) ~= nil/" "$JMZ"; }
run_mutant "M3 misname the outpost unit           " "$JMZ" "$FILTER" \
    "matched NOTHING"

# M4 -- ⭐⭐ THE ONE THIS STAND EXISTS FOR. Read the gate exactly as §1 requires,
# then overwrite it one line later. Every text assertion in §1 still passes
# (the bytes it reads are untouched), §2's census is unchanged, and §3 still
# reads a zero because the ARMED arm was already narrowing. Only arm D -- the
# UNARMED drive with the outpost predicate forced true -- can see it, and what
# it sees is the landing reaching shipped play.
MUTATE() {
    perl -0pi -e "s/$GATE_LINE/\$&\tbDivePost = true\n/" "$JMZ"
}
run_mutant "M4 gate read, then overwritten       " "$JMZ" "$FILTER" \
    "while divepost is UNARMED"

# M5 -- INVERT the predicate: every building EXCEPT an outpost reads as one.
# Both liveness readings (`pred_true` / `pred_false` non-zero) still pass, so
# only §2's cross-check against the literal lifted out of the predicate's own
# source can catch it.
MUTATE() {
    perl -0pi -e "s/\( nTarget:GetUnitName\(\), 'watch_tower' \) ~= nil/( nTarget:GetUnitName(), 'watch_tower' ) == nil/" "$JMZ"
}
run_mutant "M5 invert the outpost predicate       " "$JMZ" "$FILTER" \
    "disagrees with the literal"

# M6 -- ⭐ kill the counterfactual arm C: drive it WITHOUT forcing the predicate,
# so the "load-bearing" reading is taken against the tree itself. Every count in
# §2 and §3 is unchanged (both real arms already answer identically), so §4 is
# the only section that can notice.
MUTATE() {
    perl -0pi -e "s/local cc = drive\(\{ 'divepost' \}, true\)/local cc = drive({ 'divepost' }, false)/" "$TEST"
}
run_mutant "M6 dead counterfactual arm C          " "$TEST" "$FILTER" \
    "still fire with every building forced"

# M7 -- kill the census. A zero read off a dead sweep is not a zero: `SWEEP[k]`
# becomes an index into nil and `nil == nil` reads TRUE (GH #171 shape). The
# guard must name the case, not merely fail somewhere.
MUTATE() {
    perl -0pi -e "s/            bump\('frames'\)\n/            error('mutant: census killed')\n/" "$TEST"
}
run_mutant "M7 kill the corpus census             " "$TEST" "$FILTER" \
    "sweep DIED"

# M8 -- the predicate stops testing a quoted literal at all (`and true`). Caught
# at LOAD by the parser that lifts the outpost name out of the source instead of
# restating it. Kept separate from M5 because it never reaches a single count: a
# file that hard-coded the name would sail past it and go on measuring a domain
# the shipped code had abandoned.
MUTATE() {
    perl -0pi -e "s/\t\t\tand string\.find\( nTarget:GetUnitName\(\), 'watch_tower' \) ~= nil/\t\t\tand true/" "$JMZ"
}
run_mutant "M8 predicate loses its literal        " "$JMZ" "$FILTER" \
    "no longer tests a single quoted literal"

# M9 -- ⭐ a NEW un-narrowed member of the family lands. This is the mutant for
# §1's census-by-tree: the prose list in tests/_outpost_anchor_sweep.lua said
# "the two no-name-test anchor sites" while there were three, and the cure is a
# count taken off the tree that goes red when a fourth appears.
MUTATE() {
    printf '\nfunction J.__MutantAnchor( enemy, building )\n\treturn J.IsValidBuilding( building )\n\t\tand GetUnitToUnitDistance( enemy, building ) <= 1200\nend\n' >> "$JMZ"
}
run_mutant "M9 a new un-narrowed anchor lands     " "$JMZ" "$FILTER" \
    "do not narrow away outposts"

echo "MUTSTAND caught=$CAUGHT survived=$SURVIVED"
( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) \
    && echo "FINAL_SHA_OK=yes" || echo "FINAL_SHA_OK=no"
[ "$SURVIVED" -eq 0 ] && echo "STAND GREEN" || echo "STAND RED"
exit 0
