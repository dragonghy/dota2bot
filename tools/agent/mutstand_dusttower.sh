#!/usr/bin/env bash
# Mutation stand for tests/test_dusttower_dive_guard.lua ('dusttower', landed
# 2026-09-13 by the strategy desk; soak id 'dusttower', turbo-only, NOT armed).
#
# WHAT THIS STAND HAS TO PROVE. The lever is one boolean argument, and the file
# under it reads ONE real frame (20260820_043120 t=398.5) on which the shipped
# guard happens to answer backwards on two different enemies at once. A file
# that small is exactly the kind that can look green while half of it is
# unwitnessed, which is the trap the 'runring' stand named yesterday as (辰):
# ⭐⭐ EVERY ASSERTION MUST BE ABLE TO NAME A MUTANT THAT BREAKS ONLY IT. So the
# legs below are chosen per-assertion, not per-line:
#
#   * M1 / M2 ⭐ THE TWO DIRECTIONS, SEPARATELY. M1 freezes the helper on the
#     shipped question (the narrowing never lands); M2 freezes it on the enemy's
#     own ring (the shipped leg silently changes too). One stand leg per
#     direction is the whole point: a single "the argument is ignored" mutant
#     cannot tell "armed does nothing" from "unarmed does something".
#   * M3 EMPTINESS. `> 0` -> `>= 0` blocks everything with a live list. Both
#     answer-level cases see it; the nil counterfactual does NOT, which is what
#     makes M4 a different leg and not a duplicate of this one.
#   * M4 ⭐ THE DECLARED-NOT-OBSERVED LEG. Dropping the `~= nil` guard raises on
#     a nil tower list. The mock NEVER produces nil (it always returns a table),
#     so the entire real-frame corpus is blind to this mutant: the only thing
#     between it and trunk is the one case that DECLARES the nil world instead
#     of measuring it. That case exists precisely because the engine override
#     (bots/FunLib/aba_global_overrides.lua) does return nil for a non-hero.
#   * M5 / M6 / M7 ⭐ THE CENSUS LEGS, one per census assertion: the gate loses
#     its turbo conjunct (M5); the branch goes back to calling the inverted
#     expression inline, bypassing the single gate site (M6); the 700u dive ring
#     drifts (M7). None of the three changes ANY answer on the frame -- the test
#     calls the helper directly -- so if the census assertions were decoration,
#     these three would sail through.
#   * C0 is the CONTROL: a comment-only edit that MUST survive, so an
#     always-red stand cannot pass itself off as a sensitive one.
#
# ⚠️ TWO LEGS ARE NAMED FOR THEIR CASE, NOT FOR AN ASSERTION MESSAGE, and the
# expect strings below say so: M4 makes the helper RAISE, so the red text is a
# Lua runtime error rather than the assert message, and M6 trips its case at the
# "must consult the wrapper" assertion (the name count stays 1 -- the wrapper
# DEFINITION still names the helper). Both are the case this stand means; the
# first version of this file named the wrong string for each and scored them
# "CAUGHT, but by a DIFFERENT case", which is the (辰) reading exactly: the
# scoreboard was right about caught-ness and wrong about what caught it.
#
# DISCIPLINE (.claude/skills/evidence-discipline rules 1 and 3):
#   * restore from FILE COPIES kept OUTSIDE the tree, never `git checkout --`;
#   * `sha256sum -c` before and after every mutant, so "sed changed nothing"
#     can never be read as "the assertion did not catch it";
#   * exit codes read BARE, never through a pipe;
#   * a CONTROL leg that must SURVIVE;
#   * every mutant must COMPILE -- a mutant that will not load goes red for a
#     reason that has nothing to do with the assertion under examination, and
#     that scores as a false CAUGHT.
#
# ⛔ SCHEDULING: DO NOT RUN THIS CONCURRENTLY WITH tools/agent/routine_selfcheck.sh
# (a mutation stand writes real defects into git-tracked files by definition,
# and the selfcheck's trunk-health legs read those same files), and do not EDIT
# either mutated file while it runs -- the stand restores by sha.
#
# ⛔ THE FILE IS DRIVEN THROUGH tests/run_tests.lua, NOT DIRECTLY (GH #200/#387):
# run directly it merely returns its table and exits 0 in silence, which would
# score EVERY mutant as SURVIVED. Scoring requires BOTH a non-zero runner exit
# AND the runner's own summary line.

set -u

JMZ=bots/FunLib/jmz_func.lua
USAGE=bots/ability_item_usage_generic.lua
TEST=tests/test_dusttower_dive_guard.lua
FILTER=dusttower
STAND=$(mktemp -d)

# The EXIT trap must reach a FUNCTION DEFINED IN THIS FILE that restores the
# tree (tests/test_mutstand_restore_trap.py): a bare `cp` reads to that ratchet
# exactly like a trap that restores nothing, and a trap whose body only deletes
# the backup directory is strictly worse than no trap at all (GH #418).
restore_quiet() {
    cp -f "$STAND/jmz_func.lua" "$JMZ"
    cp -f "$STAND/ability_item_usage_generic.lua" "$USAGE"
    cp -f "$STAND/test_dusttower.lua" "$TEST"
}
trap 'restore_quiet; rm -rf "$STAND"' EXIT

cp -f "$JMZ" "$STAND/jmz_func.lua"
cp -f "$USAGE" "$STAND/ability_item_usage_generic.lua"
cp -f "$TEST" "$STAND/test_dusttower.lua"
( cd "$STAND" && sha256sum jmz_func.lua ability_item_usage_generic.lua \
    test_dusttower.lua > base.sha )

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

# M1 -- the narrowing never lands: the helper always asks the shipped question.
MUTATE() {
    perl -0pi -e "s/hEnemy:GetNearbyTowers\( nRadius, not bOwnTower \)/hEnemy:GetNearbyTowers( nRadius, true )/" "$JMZ"
}
run_mutant "M1 helper frozen on the shipped ring " "$JMZ" \
    "armed reading asks the enemy tower ring"

# M2 -- the other direction: the SHIPPED leg silently moves to the enemy's own
# ring. Every armed case still passes; only the parity/shipped cases see it.
MUTATE() {
    perl -0pi -e "s/hEnemy:GetNearbyTowers\( nRadius, not bOwnTower \)/hEnemy:GetNearbyTowers( nRadius, false )/" "$JMZ"
}
run_mutant "M2 shipped leg moved to the own ring " "$JMZ" \
    "unarmed reading diverged from the shipped expression"

# M3 -- emptiness test widened: anything with a live list is 'blocked'.
MUTATE() {
    perl -0pi -e "s/return tTowers ~= nil and #tTowers > 0/return tTowers ~= nil and #tTowers >= 0/" "$JMZ"
}
run_mutant "M3 emptiness widened to >= 0         " "$JMZ" \
    "shipped reading sees no tower of OURS near Ember"

# M4 ⭐ -- drop the nil guard. Invisible to every real frame in the corpus (the
# mock always returns a table); only the DECLARED nil world catches it.
MUTATE() {
    perl -0pi -e "s/return tTowers ~= nil and #tTowers > 0/return #tTowers > 0/" "$JMZ"
}
run_mutant "M4 nil guard dropped                 " "$JMZ" \
    "a nil tower list reads"

# M5 -- the gate loses its turbo conjunct. No answer on the frame changes.
MUTATE() {
    perl -0pi -e "s/\t\tJ\.IsModeTurbo\(\) and J\.IsSoakCandidate\( 'dusttower' \) \)/\t\tJ.IsSoakCandidate( 'dusttower' ) )/" "$USAGE"
}
run_mutant "M5 gate loses turbo-only             " "$USAGE" \
    "the gate must stay turbo-only"

# M6 -- the branch bypasses the single gate site and inlines the inverted
# expression again. Compiles, and the helper it no longer calls stays put.
MUTATE() {
    perl -0pi -e "s/\t\t\t\tif not DustDiveBlocked\(enemyHero\)\n/\t\t\t\tlocal nEnemyTowers = enemyHero:GetNearbyTowers(700, true)\n\t\t\t\tif nEnemyTowers == nil or #nEnemyTowers == 0\n/" "$USAGE"
}
run_mutant "M6 branch bypasses the gate site     " "$USAGE" \
    "the dust branch must consult the wrapper"

# M7 -- the dive ring drifts at the one gate site.
MUTATE() {
    perl -0pi -e "s/J\.IsDustDiveBlocked\( hEnemy, 700,/J.IsDustDiveBlocked( hEnemy, 400,/" "$USAGE"
}
run_mutant "M7 dive ring drifts 700 -> 400       " "$USAGE" \
    "the 700u dive ring is the shipped radius"

# C0 -- CONTROL: comment-only edit. MUST survive.
MUTATE() {
    perl -0pi -e "s/-- THE DEFECT\. GetNearbyTowers/-- THE DEFECT (control edit). GetNearbyTowers/" "$JMZ"
}
run_control "C0 control: comment-only edit        " "$JMZ"

restore
FINAL_OK=no
( cd "$STAND" && sha256sum -c base.sha >/dev/null 2>&1 ) && FINAL_OK=yes

echo
echo "caught=$CAUGHT survived=$SURVIVED (1 of them is the control) FINAL_SHA_OK=$FINAL_OK"
if [ "$CAUGHT" -eq 7 ] && [ "$SURVIVED" -eq 1 ] && [ "$FINAL_OK" = yes ]; then
    echo "STAND GREEN (seven legs, each caught by the assertion named for it)"
    exit 0
fi
echo "STAND RED"
exit 1
