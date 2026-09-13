#!/usr/bin/env bash
# Mutation stand for tests/test_runring_target_in_ring.lua ('runring', landed
# 2026-09-13 by the strategy desk; soak id 'runring', turbo-only, NOT armed).
#
# WHAT THIS STAND HAS TO PROVE, AND WHY IT IS NOT THE 'chasering' STAND AGAIN.
# There the corpus supplied 40 (row, target) pairs and the branch counters had a
# population to stand on. HERE THE WHOLE CORPUS IS ONE ROW: 1 of 1,039 live hero
# rows reaches the host's outer gate, and the answer-level effect is zero by
# construction on top of that (the dump carries no attack damage, so
# J.CanKillTarget is false against every living unit -- test §2(c) pins that as
# 1039/1039). A stand built on answer counts would score nearly every mutant
# below GREEN, and a stand built only on the corpus sweep would miss the two
# that matter. Four legs carry this file:
#
#   * M1/M2 ⭐⭐ BRANCH LEGS. M1 unwraps the conjunct at the call site; M2
#     neuters J.IsExistInTable itself, leaving the call site byte-identical so
#     §1(b)'s text assertions still pass. Neither changes a single ANSWER
#     anywhere in the corpus. Only §3's branch counters -- which unit
#     J.CanKillTarget is asked about FIRST -- can see them.
#   * M3 ⭐ POSITIVE-CONTROL LEG. Inverting the membership test keeps the
#     off-ring reading perfect (b_off stays 0) while destroying the in-ring one.
#     Only §3(b) catches it. A narrowing that closes the branch everywhere is
#     indistinguishable from deleting the branch, and this is the leg that tells
#     them apart.
#   * M4 ⭐ ANSWER LEG. Breaking the leg's own `return true` is invisible to the
#     entire sweep -- the shipped leg cannot return true anywhere in the corpus
#     -- so §4's counterfactual, the one section that declares a fact instead of
#     measuring one, is the ONLY thing standing between that mutant and trunk.
#     This is the (卯) argument made executable.
#   * M5 CALLER LEG, M6/M7 TEST-SIDE LEGS: the caller stops supplying the
#     unbounded handle (every count here becomes a statement about nothing); arm
#     A silently collapses into arm B; the gauge itself collapses (corpus
#     truncated to one file, so every pinned integer goes free while nothing
#     about the subject is wrong).
#   * C0 is the CONTROL: a comment-only edit that MUST survive, so an
#     always-red stand cannot pass itself off as a sensitive one.
#
# DISCIPLINE (.claude/skills/evidence-discipline rules 1 and 3):
#   * restore from FILE COPIES kept OUTSIDE the tree, never `git checkout --`;
#   * `sha256sum -c` before and after every mutant, so "sed changed nothing"
#     can never be read as "the assertion did not catch it";
#   * exit codes read BARE, never through a pipe;
#   * a CONTROL leg that must SURVIVE;
#   * ⛔ every mutant must COMPILE. A `return` that does not end its block is a
#     Lua syntax error, and a file that will not load goes red for a reason that
#     has nothing to do with the assertion under examination -- on the
#     'chasering' stand this morning that scored as a false CAUGHT. M2 below is
#     written as `if true then return true end` for exactly that reason.
#
# ⛔ SCHEDULING: DO NOT RUN THIS CONCURRENTLY WITH tools/agent/routine_selfcheck.sh
# (a mutation stand writes real defects into git-tracked files by definition, and
# the selfcheck's trunk-health legs read those same files), and do not EDIT
# either mutated file while it runs -- the stand restores by sha.
#
# ⛔ THE FILE IS DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY (GH #200/#387):
# run directly it merely returns its table and exits 0 in silence, which would
# score EVERY mutant as SURVIVED. Scoring requires BOTH a non-zero runner exit
# AND the runner's own summary line.
#
# ⚠️ RUNTIME: the test drives the whole fixture corpus twice over in §2, so a
# leg is ~25s and the stand is a few minutes, not a few seconds.

set -u

RET=bots/mode_retreat_generic.lua
JMZ=bots/FunLib/jmz_func.lua
TEST=tests/test_runring_target_in_ring.lua
FILTER=runring
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/mode_retreat_generic.lua" "$RET"
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/test_runring.lua" "$TEST"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$RET" "$STAND/mode_retreat_generic.lua"
cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$TEST" "$STAND/test_runring.lua"
( cd "$STAND" && sha256sum mode_retreat_generic.lua jmz_func.lua \
    test_runring.lua > base.sha )

MUTATE=MUTATE
CAUGHT=0
SURVIVED=0

restore() {
    restore_quiet
    ( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) \
        || { echo "STAND BROKEN: restore did not reproduce the baseline hashes"; exit 9; }
}

# run_mutant <label> <mutated-file> <expect-red-text>
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

# M1 -- the narrowing never landed: the guard variable is still computed (so
# §1(b)'s text assertions all pass) but the admission ignores it.
MUTATE() {
    perl -0pi -e "s/        if bTargetInRing and J\.IsValidHero\(botTarget\)\n/        if J.IsValidHero(botTarget)\n/" "$RET"
}
run_mutant "M1 admission ignores the conjunct     " "$RET" \
    "armed still reached the unbounded leg"

# M2 ⭐⭐ -- neuter the membership test INSIDE the helper. The call site is
# byte-identical, so every source assertion in §1 still passes, and no ANSWER
# anywhere in the corpus changes. Only §3's branch counters can see it.
MUTATE() {
    perl -0pi -e "s/function J\.IsExistInTable\( u, tUnit \)\n/function J.IsExistInTable( u, tUnit )\n\tif true then return true end\n/" "$JMZ"
}
run_mutant "M2 membership always answers yes      " "$JMZ" \
    "armed still reached the unbounded leg"

# M3 -- invert the membership: the leg is now computed ONLY for the targets it
# was written to stop being computed for.
# ⚠️ MEASURED, NOT PREDICTED: the first run of this stand named §3(b) here and
# was WRONG. Inversion breaks the OFF-ring reading first (b_off goes 1), so
# §3(a) fires before §3(b) is ever reached, and §4 goes red too. The label now
# says what actually catches it -- and M3b below exists precisely because that
# left §3(b) with no mutant of its own.
MUTATE() {
    perl -0pi -e "s/                              or J\.IsExistInTable\(botTarget, nEnemysHeroes\)/                              or not J.IsExistInTable(botTarget, nEnemysHeroes)/" "$RET"
}
run_mutant "M3 invert the membership test         " "$RET" \
    "armed still reached the unbounded leg"

# M3b ⭐⭐ -- THE ISOLATING MUTANT FOR THE POSITIVE CONTROL. Close the leg
# everywhere instead of narrowing it. §3(a) stays perfectly green -- armed
# reaches the leg on zero off-ring pairs, which is exactly what it asks for --
# and the off-ring counterfactual in §4 stays green too, because armed is
# SUPPOSED to answer false there. Only §3(b) and §5 can see that the repair has
# stopped being a narrowing and become a deletion. Without this leg, "the branch
# is still alive in the ring" would be an unexamined claim, and a stand cannot
# certify an assertion no mutant ever points at.
MUTATE() {
    perl -0pi -e "s/                              or J\.IsExistInTable\(botTarget, nEnemysHeroes\)/                              or false/" "$RET"
}
run_mutant "M3b close the leg everywhere          " "$RET" \
    "armed reached the leg on only"

# M4 ⭐ -- break the leg's own answer. The sweep cannot see this at all: the
# shipped leg is structurally incapable of returning true anywhere in this
# corpus, so every arm keeps agreeing. §4's counterfactual is the only leg that
# catches it -- which is the argument for keeping a declared-fact section.
MUTATE() {
    perl -0pi -e "s/(DAMAGE_TYPE_PHYSICAL\) then\n            )return true/\${1}return false/s" "$RET"
}
run_mutant "M4 the leg stops answering true       " "$RET" \
    "shipped did not answer"

# M5 -- the CALLER stops handing over its order target. The domain argument in
# this file is entirely about what that handle can hold, so a caller that
# supplies nil makes every count here a statement about nothing.
MUTATE() {
    perl -0pi -e "s/    botTarget      = J\.GetProperTarget\(bot\)/    botTarget      = nil/" "$RET"
}
run_mutant "M5 caller stops supplying the handle  " "$RET" \
    "shipped reached the unbounded leg on"

# M6 ⭐ -- TEST-SIDE: arm A is driven WITH the narrowing, so it silently becomes
# a second copy of arm B and the stand's whole comparison collapses.
MUTATE() {
    perl -0pi -e "s/                \{ armed = \(arm == 'b'\), target = nm \}\)/                { armed = true, target = nm })/" "$TEST"
}
run_mutant "M6 arm A collapses into arm B         " "$TEST" \
    "shipped reached the unbounded leg on"

# M7 ⭐ -- TEST-SIDE GAUGE COLLAPSE: the §2 corpus is truncated to one file.
# Every pinned integer in §2 goes free and nothing about the subject is wrong.
MUTATE() {
    perl -0pi -e "s/    for line in p:lines\(\) do files\[#files \+ 1\] = line end\n    p:close\(\)/    for line in p:lines() do files[#files + 1] = line end\n    p:close()\n    while #files > 1 do table.remove(files) end/" "$TEST"
}
run_mutant "M7 truncate the corpus to one file    " "$TEST" \
    "the corpus changed size"

# C0 -- CONTROL: a comment-only edit. MUST survive.
MUTATE() {
    perl -0pi -e "s/        -- \[runring, soak-candidate, turbo-only\] \"I cannot run, but I can kill/        -- [runring, soak-candidate, turbo-only] (control edit) \"I cannot run, but I can kill/" "$RET"
}
run_control "C0 comment-only control edit         " "$RET"

FINAL_OK=no
( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) && FINAL_OK=yes
echo
echo "caught=$CAUGHT survived=$SURVIVED  FINAL_SHA_OK=$FINAL_OK"
if [ "$FINAL_OK" != "yes" ] || [ "$SURVIVED" -ne 1 ]; then
    echo "STAND RED (expected exactly 1 survivor: the C0 control)"
    exit 1
fi
echo "STAND GREEN"
