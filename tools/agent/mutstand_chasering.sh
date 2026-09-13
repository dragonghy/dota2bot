#!/usr/bin/env bash
# Mutation stand for tests/test_chasering_target_in_ring.lua ('chasering',
# landed 2026-09-13 by the strategy desk; no soak id -- the host is gated as a
# whole on J.IsLaneFixOn( 'chase' )).
#
# WHAT THIS STAND HAS TO PROVE THAT THE 'divepocket' STAND DID NOT.
# There the answer-level effect was measurable on the corpus (22 flips), so the
# flip counts carried the weight. HERE THE ANSWER-LEVEL EFFECT IS ZERO BY
# CONSTRUCTION: the mock answers ground-truth damage only for damage dealt TO
# the fixture subject, so an ALLY's burst on an enemy reads 0, the shipped
# exemption never fires anywhere in the corpus, and every arm agrees on every
# answer. A stand built on answer counts would therefore score almost every
# mutant below GREEN. Two legs carry this file instead:
#
#   * M2 ⭐⭐ NEUTERS THE MEMBERSHIP TEST INSIDE J.IsExistInTable, so the call
#     site is untouched and §1(c)'s text assertion still passes. Only §3's
#     BRANCH counters -- how many times the exemption was actually computed,
#     read by wrapping J.GetAlliesNearLoc -- can see that the repair has stopped
#     repairing. This is the (癸) lesson from this morning's 'divepocket' stand
#     (M4 SURVIVED an answer-count assertion there), applied before the fact
#     rather than after it.
#   * M4 ⭐ BREAKS THE EXEMPTION'S OWN `return false`. Nothing in the corpus
#     sweep can see that -- the exemption never fires there -- so §4's
#     counterfactual (one declared number on a real frame) is the ONLY leg that
#     catches it. If §4 were dropped as "just a counterfactual", this mutant
#     would ship.
#   * M6/M7 ⭐ are the TEST-SIDE legs this desk requires: arm A silently
#     collapsing into arm B, and the gauge itself collapsing (corpus truncated
#     to one file, so every pinned integer becomes free while nothing about the
#     subject is wrong).
#   * C0 is the CONTROL: a comment-only edit that MUST survive, so an
#     always-red stand cannot pass itself off as a sensitive one.
#
# DISCIPLINE (.claude/skills/evidence-discipline rules 1 and 3):
#   * restore from FILE COPIES kept OUTSIDE the tree, never `git checkout --`;
#   * `sha256sum -c` before and after every mutant, so "sed changed nothing"
#     can never be read as "the assertion did not catch it";
#   * exit codes read BARE, never through a pipe;
#   * a CONTROL leg that must SURVIVE.
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
# ⚠️ RUNTIME: ~3s per leg; the whole stand is well under a minute.

set -u

JMZ=bots/FunLib/jmz_func.lua
RET=bots/mode_retreat_generic.lua
TEST=tests/test_chasering_target_in_ring.lua
FILTER=chasering
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/mode_retreat_generic.lua" "$RET"
    cp -f "$STAND/test_chasering.lua" "$TEST"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$RET" "$STAND/mode_retreat_generic.lua"
cp -f "$TEST" "$STAND/test_chasering.lua"
( cd "$STAND" && sha256sum jmz_func.lua mode_retreat_generic.lua \
    test_chasering.lua > base.sha )

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

# M1 -- the narrowing never landed: the conjunct is there but admits everything.
MUTATE() {
    perl -0pi -e "s/\tif J\.IsExistInTable\( target, tEnemies \) then/\tif true then/" "$JMZ"
}
run_mutant "M1 unwrap the conjunct                " "$JMZ" \
    "ring-membership conjunct is gone"

# M2 ⭐⭐ -- neuter the membership test INSIDE the helper. The call site is
# byte-identical, so §1(c) still passes and no answer anywhere in the corpus
# changes (the exemption never fires on this corpus in any arm). Only §3's
# branch counters -- taken by wrapping J.GetAlliesNearLoc -- can see it.
MUTATE() {
    # ⛔ `return true` as a BARE statement here is a Lua SYNTAX error (a return
    # must end its block), and a mutant that does not parse is not a mutant of
    # the subject: the first run of this stand scored M2 "CAUGHT" by §2's
    # load_fail, i.e. by the file refusing to load. `if true then return true
    # end` is the same defect that actually compiles.
    perl -0pi -e "s/function J\.IsExistInTable\( u, tUnit \)\n/function J.IsExistInTable( u, tUnit )\n\tif true then return true end\n/" "$JMZ"
}
run_mutant "M2 membership always answers yes      " "$JMZ" \
    "still reached the exemption"

# M3 -- invert the membership: the exemption is now computed ONLY for the
# targets it was supposed to stop being computed for.
MUTATE() {
    perl -0pi -e "s/\tif J\.IsExistInTable\( target, tEnemies \) then/\tif not J.IsExistInTable( target, tEnemies ) then/" "$JMZ"
}
run_mutant "M3 invert the membership test         " "$JMZ" \
    "entered the exemption on"

# M4 ⭐ -- break the exemption's own answer. Nothing in the sweep can see this:
# the exemption never fires there, so every arm keeps agreeing. §4's
# counterfactual is the only leg that catches it -- which is the argument for
# keeping a declared-number section at all.
MUTATE() {
    perl -0pi -e "s/(if nKillBurst >= target:GetHealth\(\) \+ target:GetHealthRegen\(\) \* 3 then\n\t\t\t)return false/\${1}return true/s" "$JMZ"
}
run_mutant "M4 exemption stops exempting          " "$JMZ" \
    "SHIPPED no longer exempts this bot"

# M5 -- the CALLER stops handing over its order target. The domain argument in
# this file is entirely about what that second argument can be, so a caller that
# passes nil makes every count here a statement about nothing.
MUTATE() {
    perl -0pi -e "s/J\.ShouldNotChaseWhenLow\(bot, botTarget\)/J.ShouldNotChaseWhenLow(bot, nil)/" "$RET"
}
run_mutant "M5 caller stops passing its target    " "$RET" \
    "no longer passes botTarget"

# M6 ⭐ -- TEST-SIDE: arm A is driven WITH the narrowing, so it silently becomes
# a second copy of arm B and the stand's whole comparison collapses.
MUTATE() {
    perl -0pi -e "s/local rA, xA = drive\(false, e\)/local rA, xA = drive(true, e)/" "$TEST"
}
run_mutant "M6 arm A collapses into arm B         " "$TEST" \
    "shipped entered the exemption on"

# M7 ⭐ -- TEST-SIDE GAUGE COLLAPSE: the corpus is truncated to one file. Every
# count in §2/§3/§5 is then free, and nothing about the subject is wrong.
MUTATE() {
    perl -0pi -e "s/    assert\(#out > 100, 'expected the frame corpus, got ' \.\. #out\)/    while #out > 1 do table.remove(out) end/" "$TEST"
}
run_mutant "M7 truncate the corpus to one file    " "$TEST" \
    "corpus size moved"

# C0 -- CONTROL: a comment-only edit. MUST survive.
MUTATE() {
    perl -0pi -e "s/-- THE REPAIR IS THE SENTENCE ABOVE IT: the exemption counts only when the/-- THE REPAIR IS THE SENTENCE ABOVE IT (control edit): the exemption counts only when the/" "$JMZ"
}
run_control "C0 comment-only control edit         " "$JMZ"

FINAL_OK=no
( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) && FINAL_OK=yes
echo
echo "caught=$CAUGHT survived=$SURVIVED  FINAL_SHA_OK=$FINAL_OK"
if [ "$FINAL_OK" != "yes" ] || [ "$SURVIVED" -ne 1 ]; then
    echo "STAND RED (expected exactly 1 survivor: the C0 control)"
    exit 1
fi
echo "STAND GREEN"
