#!/usr/bin/env bash
# Mutation stand for tests/test_rescpost_outpost_narrow.lua ('rescpost', GH #782
# family, landed 2026-09-13).
#
# WHAT THIS STAND HAS TO PROVE THAT THE TWO SIBLING STANDS DID NOT.
# mutstand_tpdeftower_outpost.sh and mutstand_divepost.sh both defend a headline
# ZERO. This landing is the first of the family whose helper actually FIRES on
# the fixture corpus, and that changes which mutants matter:
#
#   * M5b ⭐⭐ NEUTERS THE HOST'S OWN GATE IN PLACE (`if false and not
#     J.IsLaneFixOn( 'rescue' ) ...`). The line stays, so the test's GATE_SUB
#     parser is satisfied and §1's "the gate stands above the conjunct" ordering
#     assertion is still true; §2's tree census and §3's domain are untouched.
#     Only arm D -- the UNARMED drive with the outpost predicate forced true --
#     can see that the helper, and with it this round's conjunct, now reaches
#     shipped play. That is the reason the file carries no gate id of its own:
#     criterion (甲) says a gated host IS the gate, and M5b is the mutant that
#     makes the claim falsifiable instead of decorative.
#     ⭐ M5 (delete the gate line outright) is kept beside it as the MEASURED
#     correction to this stand's first draft: it is caught at LOAD, by the
#     GATE_SUB parser, and never reaches a count -- so it does NOT exercise
#     arm D, which is what the first draft claimed.
#   * M7 ⭐ re-introduces the defect this file's own §6 control caught on its
#     FIRST run: one shared rf.load across the five arms. J.GetRescueTpTarget
#     mutates module state on a fire (J.TryTakeTpResponseSlot burns the team's
#     one-per-window slot; J.NoteRescueResponse stamps the 15s chain memory), so
#     arms B/C/D read a world arm A had already spent and 4 of 657 rows reported
#     a flip that was the harness, not the subject. ⭐ MEASURED: the section that
#     catches it is §5 (the armed/unarmed difference stops being exactly the fire
#     set), not §6 -- arm A burns the slot before the re-drive control can
#     disagree with itself.
#   * M8 ⭐ SURVIVED this stand's first run and is the reason the test file now
#     counts the real-predicate BRANCH: on a corpus where flip_ab is 0, nothing
#     separated "arm B reads the shipped predicate" from "arm B is arm A".
#
# ⛔ WHY THERE IS NO MUTANT FOR THE ADMISSION ORDER BEING *BEHAVIOUR*. §1 pins
# `valid < name < outpost < distance`, but the predicate null-checks its own
# argument, so hoisting it changes nothing the corpus could see. M9 therefore
# scores the STRUCTURAL assertion, and this header does not pretend the order is
# behaviour.
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
# ⛔ SCHEDULING (this desk's 2026-09-13 lesson): DO NOT RUN THIS CONCURRENTLY
# WITH tools/agent/routine_selfcheck.sh. A mutation stand writes real defects
# into git-tracked files by definition, and the selfcheck's trunk-health legs
# read those same files -- a half-written jmz_func.lua reads back to it as a
# syntax error that is not there.
#
# ⚠️ RUNTIME: the file under test takes ~5 fresh fixture loads per hero-row over
# the whole corpus, so ONE mutant costs minutes, not seconds. Budget for it;
# do not read a timeout as a SURVIVED.
#
# ⛔ THE FILE IS DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY (GH
# #200/#387): run directly it merely returns its table and exits 0 in silence,
# which would score EVERY mutant as SURVIVED. Scoring therefore requires BOTH a
# non-zero runner exit AND the runner's own summary line; a run missing the
# summary is scored NOT-RUN rather than passed.

set -u

JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_rescpost_outpost_narrow.lua
FILTER=rescpost_outpost_narrow
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/test_rescpost.lua" "$TEST"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$TEST" "$STAND/test_rescpost.lua"
( cd "$STAND" && sha256sum jmz_func.lua test_rescpost.lua > base.sha )

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

# Anchors. Each is verified unique in the tree before use: the bare text
# `and not J.IsOutpostBuilding( ... )` exists at three other sites in this file,
# but only this host spells the loop variable `b`.
CUT_LINE="\t\t\t\tand not J\.IsOutpostBuilding\( b \)\n"
GATE_LINE="\tif not J\.IsLaneFixOn\( 'rescue' \) then return nil end\n"
DIST_LINE="\t\t\t\tand GetUnitToLocationDistance\( b, ally:GetLocation\(\) \) <= 900\n"

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

# M5 -- delete the HOST'S gate outright. ⭐ MEASURED CORRECTION to this stand's
# first draft, kept because getting it wrong is the instructive part: this is
# NOT caught by arm D. Deleting the line removes the only `IsLaneFixOn` in the
# host, so the test file's GATE_SUB parser fires at LOAD time and the run never
# reaches a single count. The header's earlier claim that "only arm D can see
# it" was wrong, and M5b below is the mutant that actually exercises arm D.
MUTATE() { perl -0pi -e "s/$GATE_LINE//" "$JMZ"; }
run_mutant "M5 delete the host gate               " "$JMZ" \
    "no longer opens on J.IsLaneFixOn"

# M5b -- ⭐⭐ THE ONE THIS STAND EXISTS FOR. Neuter the gate IN PLACE: the line
# stays, so GATE_SUB still parses and §1's `gate stands above the conjunct`
# ordering assertion is still true -- but the early return never happens. §1,
# §2, §3 and §4 all stay green. Only arm D -- the UNARMED drive -- can see that
# the helper, and with it this round's conjunct, now reaches shipped play.
MUTATE() {
    perl -0pi -e "s/if not J\.IsLaneFixOn\( 'rescue' \) then return nil end/if false and not J.IsLaneFixOn( 'rescue' ) then return nil end/" "$JMZ"
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

# M7 -- ⭐ memoise the per-arm load, which is exactly the defect §6 caught the
# first time this file ran. Every other section is unaffected (the census takes
# its own load), so §6 is the only place it can surface.
MUTATE() {
    perl -0pi -e "s/    local function fresh_load\(path\) return pcall\(rf\.load, path\) end/    local _C = {} local function fresh_load(path) if _C[path] == nil then _C[path] = { pcall(rf.load, path) } end return unpack(_C[path]) end/" "$TEST"
}
# ⭐ MEASURED, and the stand says so out loud rather than being tuned to agree:
# the catcher is §5, NOT §6 -- sharing a load lets arm A burn the team's
# response slot, and what goes red is §5's `fire_d == 0` leg, not the
# `flip_ad == fire_a` leg named below. The run therefore prints "CAUGHT, but by
# a DIFFERENT case than the one named", which is this stand's honest output for
# "caught, by a neighbour" -- left as-is deliberately: renaming the expectation
# to whatever fired would make the label agree with the run by construction and
# stop being evidence about which assertion carries the weight.
run_mutant "M7 share one load across the arms     " "$TEST" \
    "is not exactly the fire set"

# M8 -- restore the nil-as-"real" sentinel bug in arm B, so arm B silently
# becomes a second copy of arm A. The flip count then reads 0 for a reason that
# has nothing to do with the corpus.
MUTATE() {
    perl -0pi -e "s/armed_id, 'real'\)/armed_id, nil)/" "$TEST"
}
# ⭐ This one SURVIVED the stand's first run: with flip_ab == 0 on this corpus,
# no count could separate arm B from arm A. The test file now counts the
# real-predicate BRANCH (not its spelling), which is what catches it.
run_mutant "M8 arm B collapses onto arm A         " "$TEST" \
    "not being driven against the shipped predicate"

# M9 -- hoist the conjunct BELOW the distance test, breaking §1's structural
# bracketing. Scored as a structural assertion, not as behaviour (see header).
MUTATE() {
    perl -0pi -e "s/($CUT_LINE)($DIST_LINE)/\$2\$1/" "$JMZ"
}
run_mutant "M9 admission terms out of order       " "$JMZ" \
    "out of order"

# C0 -- CONTROL: a comment-only edit inside the host. Must SURVIVE. §1 reads a
# COMMENT-STRIPPED source, so a green here is the evidence that the CAUGHTs
# above are the assertions doing work rather than the file being brittle.
MUTATE() {
    perl -0pi -e "s/-- \[rescpost 20260913, GH #782 family\]/-- [rescpost 20260913, GH #782 family] (control edit)/" "$JMZ"
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
