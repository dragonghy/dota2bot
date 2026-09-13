#!/usr/bin/env bash
# Mutation stand for tests/test_roshpost_outpost_narrow.lua ('roshpost', GH #782
# family, landed 2026-09-13 -- the member that CLOSES the family's name-test
# half).
#
# WHAT THIS STAND HAS TO PROVE THAT THE THREE SIBLING STANDS DID NOT.
# mutstand_tpdeftower_outpost.sh and mutstand_divepost.sh each defend a headline
# ZERO; mutstand_rescpost.sh defends a fire count but still a zero flip. This is
# the first member of the family whose narrowing CHANGES THE ANSWER on real
# frames (flip_ab 4, witness f_260820_102030_wk_tower_out_of_reach.lua), so the
# mutants that matter here are different:
#
#   * M5b ⭐⭐ NEUTERS THE HOST'S OWN GATE IN PLACE (`if false and not
#     J.IsSoakCandidate( 'roshgate' ) ...`). The line stays, so the test's
#     GATE_ID parser is satisfied, §1's "the gate stands above the conjunct"
#     ordering assertion is still true, and §2/§3/§4 are all untouched. Only
#     arm D -- the UNARMED drive -- can see that the helper, and with it this
#     round's conjunct, now reaches shipped play. That is precisely why the
#     landing carries no gate id of its own: criterion (甲′) says a wholly gated
#     host IS the gate, and M5b is what makes that claim falsifiable instead of
#     decorative. ⭐ M5 (delete the gate line outright) sits beside it as the
#     sibling stand's MEASURED correction: it is caught at LOAD by the GATE_ID
#     parser and never reaches a count, so it does NOT exercise arm D.
#   * M7 ⭐ is the sibling's M8 defect (arm B driven with a nil sentinel, so it
#     silently becomes a second copy of arm A). On THIS corpus flip_ab is
#     non-zero, so it has a second catcher -- and the stand reports which one
#     actually fired rather than assuming the count is the guard.
#   * M8 ⭐ IS THE "GAUGE COLLAPSES" LEG this desk's 2026-09-13 rule requires:
#     it truncates the corpus to one fixture. Every `x == 0` in the file would
#     then be free, and nothing about the SUBJECT is wrong -- only the
#     instrument. A stand without such a leg cannot tell a sensitive file from
#     one that is merely measuring almost nothing.
#
# ⛔ WHY THERE IS NO MUTANT FOR THE ADMISSION ORDER BEING *BEHAVIOUR*. §1 pins
# `valid < name < outpost < pressure`, but J.IsOutpostBuilding null-checks its
# own argument, so moving it changes nothing the corpus could see. M9 therefore
# scores the STRUCTURAL assertion, and this header does not pretend the order is
# behaviour. (What the order DOES buy is that the narrowing runs before the
# enemy scan it exists to skip -- cost, not correctness.)
#
# DISCIPLINE (.claude/skills/evidence-discipline rules 1 and 3):
#   * restore from FILE COPIES kept OUTSIDE the tree, never `git checkout --`
#     (a pathspec typo silently restores nothing and mutants then ACCUMULATE
#     into a plausible-looking table);
#   * `sha256sum -c` before and after every mutant, so "sed changed nothing"
#     can never be read as "the assertion did not catch it";
#   * exit codes read BARE, never through a pipe;
#   * a CONTROL leg (C0) that must SURVIVE, so an always-red stand cannot pass
#     itself off as a sensitive one.
#
# ⛔ SCHEDULING (this desk's 2026-09-13 lesson, inherited): DO NOT RUN THIS
# CONCURRENTLY WITH tools/agent/routine_selfcheck.sh. A mutation stand writes
# real defects into git-tracked files by definition, and the selfcheck's
# trunk-health legs read those same files -- a half-written jmz_func.lua reads
# back to it as a syntax error that is not there. ⛔ And do not EDIT either file
# below while this is running: the stand restores by sha and a mid-run edit is
# eaten by FINAL_SHA_OK.
#
# ⛔ THE FILE IS DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY (GH
# #200/#387): run directly it merely returns its table and exits 0 in silence,
# which would score EVERY mutant as SURVIVED. Scoring therefore requires BOTH a
# non-zero runner exit AND the runner's own summary line; a run missing the
# summary is scored NOT-RUN rather than passed.
#
# ⚠️ RUNTIME: ~3s per leg (this helper is a pure read, so all five arms share one
# fixture load -- see §6). The whole stand is well under a minute.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_roshpost_outpost_narrow.lua
FILTER=roshpost_outpost_narrow
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/test_roshpost.lua" "$TEST"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$TEST" "$STAND/test_roshpost.lua"
( cd "$STAND" && sha256sum jmz_func.lua test_roshpost.lua > base.sha )

MUTATE=MUTATE
CAUGHT=0
SURVIVED=0

restore() {
    restore_quiet
    ( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) \
        || { echo "STAND BROKEN: restore did not reproduce the baseline hashes"; exit 9; }
}

# run_mutant <label> <mutated-file> <expect-red-case-substring>
run_mutant() {
    local label="$1" target="$2" expect="$3"
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

# run_control <label> <mutated-file> -- a legitimate edit that MUST survive.
run_control() {
    local label="$1" target="$2"
    local before after
    before=$(sha256sum "$target" | cut -d' ' -f1)
    "$MUTATE"
    after=$(sha256sum "$target" | cut -d' ' -f1)
    if [ "$before" = "$after" ]; then
        echo "$label  NON-MUTANT: the control edit changed zero bytes, so it"
        echo "       proves nothing about this stand's sensitivity"
        SURVIVED=$((SURVIVED + 1))
        restore
        return
    fi
    local out rc
    out=$(lua5.1 tests/run_tests.lua "$FILTER" 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$label  SURVIVED (correct: the stand is not simply always red)"
        SURVIVED=$((SURVIVED + 1))
    else
        echo "$label  CAUGHT -- WRONG. A comment-only edit turned the file red,"
        echo "       so every CAUGHT above is suspect."
        printf '%s\n' "$out" | grep -i '^FAIL' | sed 's/^/         /'
        CAUGHT=$((CAUGHT + 1))
    fi
    restore
}

# Anchors. ⛔ Each is anchored to the START of its line, because the bare text
# `and not J.IsOutpostBuilding( b )` also exists in J.GetRescueTpTarget -- at
# FOUR tabs of indent instead of this host's three. A regex without the leading
# newline would match the sibling's line and mutate the wrong site, which reads
# back as a perfectly plausible CAUGHT from the wrong assertion.
CUT_LINE="\n\t\t\tand not J\.IsOutpostBuilding\( b \)"
GATE_LINE="\tif not J\.IsSoakCandidate\( 'roshgate' \) then return false end\n"
PRESS_LINE="\n\t\t\tand #J\.GetEnemiesNearLoc\( b:GetLocation\(\), 900 \) > 0 then"

# M1 -- delete the narrowing conjunct outright (the change never landed).
MUTATE() { perl -0pi -e "s/$CUT_LINE//" "$JMZ"; }
run_mutant "M1 drop the narrowing conjunct        " "$JMZ" \
    "the outpost narrowing is GONE"

# M2 -- break the outpost NAME inside the canonical predicate so it matches
# nothing. The census parses that literal out of the source, so this is the
# mutant that would make the measured domain in §3 free.
MUTATE() { perl -0pi -e "s/'watch_tower' \) ~= nil/'watch_towerZZ' ) ~= nil/" "$JMZ"; }
run_mutant "M2 misname the outpost unit           " "$JMZ" \
    "not discriminating on real handles"

# M3 -- INVERT the predicate: every building EXCEPT an outpost reads as one.
# Both liveness readings (`pred_true` / `pred_false` non-zero) still pass, so
# only the cross-check against the literal lifted out of the predicate's own
# source can catch it.
MUTATE() {
    perl -0pi -e "s/\( nTarget:GetUnitName\(\), 'watch_tower' \) ~= nil/( nTarget:GetUnitName(), 'watch_tower' ) == nil/" "$JMZ"
}
run_mutant "M3 invert the outpost predicate       " "$JMZ" \
    "disagree"

# M4 -- the predicate stops testing a quoted literal at all. Caught at LOAD by
# the parser that lifts the outpost name out of the source instead of restating
# it: a file that hard-coded the name would sail past this and go on measuring a
# domain the shipped code had abandoned.
MUTATE() {
    perl -0pi -e "s/and string\.find\( nTarget:GetUnitName\(\), 'watch_tower' \) ~= nil/and true/" "$JMZ"
}
run_mutant "M4 predicate stops reading a literal  " "$JMZ" \
    "single quoted literal"

# M5 -- delete the HOST'S gate outright. Kept for the same reason the sibling
# stand kept it: it is NOT caught by arm D. Deleting the line removes the only
# `IsSoakCandidate` in the host, so the GATE_ID parser fires at LOAD time and
# the run never reaches a single count.
MUTATE() { perl -0pi -e "s/$GATE_LINE//" "$JMZ"; }
run_mutant "M5 delete the host gate               " "$JMZ" \
    "no longer opens on a bare J.IsSoakCandidate"

# M5b -- ⭐⭐ THE ONE THIS STAND EXISTS FOR. Neuter the gate IN PLACE: the line
# stays, so GATE_ID still parses, §1's ordering assertion is still true, and the
# census, the flip and the witness are all unchanged. Only arm D -- the UNARMED
# drive -- can see that the helper now reaches shipped play un-gated.
MUTATE() {
    perl -0pi -e "s/if not J\.IsSoakCandidate\( 'roshgate' \) then return false end/if false and not J.IsSoakCandidate( 'roshgate' ) then return false end/" "$JMZ"
}
run_mutant "M5b neuter the host gate in place     " "$JMZ" \
    "while the host was UNARMED"

# M6 -- kill the census. A zero read off a dead sweep is not a zero: `SWEEP[k]`
# becomes an index into nil and `nil == nil` reads TRUE (GH #171 shape). The
# guard must name the case, not merely fail somewhere.
MUTATE() {
    perl -0pi -e "s/            bump\('frames'\)\n/            error('mutant: census killed')\n/" "$TEST"
}
run_mutant "M6 kill the corpus census             " "$TEST" \
    "sweep DIED"

# M7 -- restore the nil-as-"real" sentinel bug in arm B, so arm B silently
# becomes a second copy of arm A. On the sibling's corpus (flip_ab 0) nothing
# could see this until the file counted the real-predicate BRANCH; here the
# flip count is a second witness, and the stand reports which guard fired.
MUTATE() {
    perl -0pi -e "s/name, true,  'real'\)/name, true,  nil)/" "$TEST"
}
run_mutant "M7 arm B collapses onto arm A         " "$TEST" \
    "not being driven against the shipped predicate"

# M8 -- ⭐ THE GAUGE ITSELF COLLAPSES: sweep one fixture instead of the corpus.
# Nothing about the subject is wrong; every `== 0` in the file simply becomes
# free, and flip_ab/site/wt counts shrink toward nothing. A stand with no such
# leg cannot distinguish a sensitive file from one that measures almost nothing.
MUTATE() {
    perl -0pi -e "s/    for _, path in ipairs\(corpus_paths\(\)\) do/    for _, path in ipairs({ corpus_paths()[1] }) do/" "$TEST"
}
run_mutant "M8 truncate the corpus to one fixture " "$TEST" \
    "the corpus shrank"

# M9 -- hoist the conjunct BELOW the pressure test, breaking §1's structural
# bracketing. Scored as a structural assertion, not as behaviour (see header).
MUTATE() {
    perl -0pi -e "s/($CUT_LINE)($PRESS_LINE)/\$2\$1/" "$JMZ"
}
run_mutant "M9 admission terms out of order       " "$JMZ" \
    "out of order"

# C0 -- CONTROL: a comment-only edit inside the host. Must SURVIVE. §1 reads a
# COMMENT-STRIPPED source, so a green here is the evidence that the CAUGHTs
# above are the assertions doing work rather than the file being brittle.
MUTATE() {
    perl -0pi -e "s/-- \[roshpost 20260913, GH #782 family/-- [roshpost 20260913 (control edit), GH #782 family/" "$JMZ"
}
run_control "C0 comment-only edit (must survive)  " "$JMZ"

echo
echo "caught=$CAUGHT survived=$SURVIVED"
restore
FINAL=$( ( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) && echo yes || echo NO )
echo "FINAL_SHA_OK=$FINAL"
# One control leg is EXPECTED to survive, so the green condition is
# "exactly the control survived", not "survived == 0".
if [ "$SURVIVED" -eq 1 ] && [ "$FINAL" = "yes" ]; then
    echo "STAND GREEN (10 mutants caught, 1 control survived)"
    exit 0
fi
echo "STAND RED"
exit 1
