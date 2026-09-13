#!/usr/bin/env bash
# Mutation stand for tests/test_divepocket_target_in_pocket.lua ('divepocket',
# landed 2026-09-13 by the strategy desk).
#
# WHAT THIS STAND HAS TO PROVE THAT THE GH #782 FAMILY'S FOUR STANDS DID NOT.
# Every member of that family defends a narrowing whose DIRECTION IS CLOSED FORM
# (a conjunct added to an admission test -> the admitted set can only shrink).
# This one is not: swapping the representative target can move the answer either
# way, and the corpus says it does -- 21 flips one way and ONE the other. So the
# assertions that carry weight here are different in kind:
#
#   * M2 ⭐⭐ NEUTERS THE GATE IN PLACE (`and false and J.IsSoakCandidate(...)`).
#     The call stays, so §1(c)'s text assertion is satisfied and the host still
#     "has a gate". Only §3's flip_ab -- a count of the DIFFERENCE between the
#     armed and unarmed arms -- can see that the two arms have collapsed into
#     one. That is the whole reason arm A and arm B are driven separately rather
#     than asserted from the source.
#   * M4 ⭐⭐ DISCARDS THE TARGET UNCONDITIONALLY (the membership test is
#     computed and then ignored). Every OFF-pocket reading is unchanged by that
#     -- those targets were going to be discarded anyway -- so fire_a, fire_b,
#     flip_ab, both flip signs AND the named witness all stay GREEN. It reaches
#     only the in-pocket pairs, which the gate exists to leave alone.
#     ⭐ THIS MUTANT SURVIVED ON THE FIRST RUN OF THIS STAND, and that was the
#     product, not rework. §3 asserted arm C as `flip_ac == 0` -- a count of
#     ANSWERS -- and on this corpus swapping an in-pocket representative for the
#     pocket's lowest-HP enemy changes no answer, so the assertion was true
#     under the mutant too. The repair was to COUNT THE BRANCH, NOT THE ANSWER:
#     the test now wraps J.SafeToCommitFight and reads back which handle was
#     actually spent as the representative (`in_rep_swapped` / `far_rep_kept`),
#     which is what catches M4 today. This desk's (戊) rule, earned again.
#   * M7 ⭐ collapses the TEST's arm B into a second copy of arm A (the sibling
#     stands' M8 defect, ported to this file's drive signature).
#   * M8 ⭐ IS THE "GAUGE COLLAPSES" LEG this desk requires of every stand: it
#     truncates the corpus to a single file. Nothing about the SUBJECT is then
#     wrong -- only the instrument -- and a file whose counts are pinned to
#     exact integers is the only kind that notices.
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
TEST=tests/test_divepocket_target_in_pocket.lua
FILTER=divepocket
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/mode_retreat_generic.lua" "$RET"
    cp -f "$STAND/test_divepocket.lua" "$TEST"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$RET" "$STAND/mode_retreat_generic.lua"
cp -f "$TEST" "$STAND/test_divepocket.lua"
( cd "$STAND" && sha256sum jmz_func.lua mode_retreat_generic.lua \
    test_divepocket.lua > base.sha )

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

# Anchors. ⛔ Anchored with their own indentation, because `J.IsSoakCandidate(`
# appears ~200 times in this file and `hTarget` appears in two other helpers.
GATE_LINE="\tif hTarget ~= nil and J\.IsSoakCandidate\( 'divepocket' \) then"
DISCARD_LINE="\t\tif not bInPocket then hTarget = nil end"

# M1 -- the narrowing never landed: delete the whole gated block. Arm A and arm
# B collapse into one and §1(c) loses its text as well.
MUTATE() {
    perl -0pi -e "s/$GATE_LINE.*?\n\t\tif not bInPocket then hTarget = nil end\n\tend\n\n//s" "$JMZ"
}
run_mutant "M1 drop the gated narrowing block     " "$JMZ" \
    "gate is gone from J.ShouldSuppressDive"

# M2 ⭐⭐ -- neuter the gate IN PLACE. The J.IsSoakCandidate call survives, so
# §1(c)'s text assertion still passes; only the behavioural difference between
# the two arms can see it.
MUTATE() {
    perl -0pi -e "s/if hTarget ~= nil and J\.IsSoakCandidate\( 'divepocket' \) then/if hTarget ~= nil and false and J.IsSoakCandidate( 'divepocket' ) then/" "$JMZ"
}
run_mutant "M2 neuter the gate in place           " "$JMZ" \
    "arm B (narrowed) fires"

# M3 -- make the narrowing UNCONDITIONAL (drop the gate, keep the repair). This
# is the mutant that would change SHIPPED play with no wave behind it, which is
# the entire reason this landing carries an id of its own.
MUTATE() {
    perl -0pi -e "s/if hTarget ~= nil and J\.IsSoakCandidate\( 'divepocket' \) then/if hTarget ~= nil then/" "$JMZ"
}
run_mutant "M3 make the narrowing unconditional   " "$JMZ" \
    "gate is gone from J.ShouldSuppressDive"

# M4 ⭐ -- DISCARD UNCONDITIONALLY: the membership test is computed and then
# ignored. Every OFF-pocket reading in §3/§4/§5 is unchanged by this (those
# targets were going to be discarded anyway), so fire_a / fire_b / flip_ab /
# a1b0 / a0b1 and the named witness all stay GREEN. Only arm C -- the 126
# IN-pocket pairs the gate must leave alone -- can see that the repair now
# throws away exactly the targets it exists to keep. A stand without an arm C
# scores this mutant green.
MUTATE() { perl -0pi -e "s/$DISCARD_LINE/\t\thTarget = nil/" "$JMZ"; }
run_mutant "M4 discard the target unconditionally " "$JMZ" \
    "were REPLACED as the"

# M5 -- membership always answers "yes", so the caller's target is never
# discarded and the repair is a no-op under its own gate.
MUTATE() { perl -0pi -e "s/$DISCARD_LINE/\t\tif false then hTarget = nil end/" "$JMZ"; }
run_mutant "M5 never discard the off-pocket target" "$JMZ" \
    "arm B (narrowed) fires"

# M6 -- the CALLER stops handing over its order target. The domain argument in
# this file is entirely about what that third argument can be, so a caller that
# passes nil makes every count here a statement about nothing.
MUTATE() {
    perl -0pi -e "s/J\.ShouldSuppressDive\(bot, botLocation, botTarget\)/J.ShouldSuppressDive(bot, botLocation, nil)/" "$RET"
}
run_mutant "M6 caller stops passing its target    " "$RET" \
    "no longer passes (botLocation, botTarget)"

# M7 ⭐ -- TEST-SIDE: arm B is driven unarmed, so it silently becomes a second
# copy of arm A. The sibling stands' M8 defect in this file's drive signature.
MUTATE() {
    perl -0pi -e "s/local rB, pB = drive\(h, vLoc, true, e\)/local rB, pB = drive(h, vLoc, false, e)/" "$TEST"
}
run_mutant "M7 arm B collapses into arm A         " "$TEST" \
    "arm B (narrowed) fires"

# M8 ⭐ -- TEST-SIDE GAUGE COLLAPSE: the corpus is truncated to one file. Every
# count in §2/§3/§5 is then free, and nothing about the subject is wrong.
MUTATE() {
    perl -0pi -e "s/    assert\(#out > 100, 'expected the frame corpus, got ' \.\. #out\)/    while #out > 1 do table.remove(out) end/" "$TEST"
}
run_mutant "M8 truncate the corpus to one file    " "$TEST" \
    "corpus size moved"

# C0 -- CONTROL: a comment-only edit. MUST survive.
MUTATE() {
    perl -0pi -e "s/-- THE REPAIR IS THE COMMENT: keep the caller's target only when it is one of/-- THE REPAIR IS THE COMMENT (control edit): keep the caller's target only when it is one of/" "$JMZ"
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
