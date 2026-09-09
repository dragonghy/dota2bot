#!/usr/bin/env bash
# Mutation stand for tests/test_blind_a_roamidle_campsel.lua.
#
# The file it defends records a BLINDNESS, so -- as in the cmrguard stand --
# EVERY MUTANT BELOW RUNS IN THE SAME DIRECTION: each one either LIFTS the
# blindness (the instrument gains the reading) or DISSOLVES A REASON for it
# (the lever, the gate or the declaration moves).  A test that stays green
# through those is a test that would let a retired id silently become
# re-proposable, or that would outlive its own subject.
#
# roamidle's blindness: J.CheckBotIdleState reaches `bRelocated = true` only
# through `GetCurrentActionType() == BOT_ACTION_TYPE_IDLE` (or two BOT_MODE_*
# comparisons).  api.install resolves the ALL_CAPS names to sentinels >= 1001
# while an unspecced `^Get` answers 0, so all three are `0 == <non-zero>` on
# every frame of the corpus -- failing CLOSED and silently.
# campsel's blindness: its pivot is `camp.cattr.{team,type}`, and neither the
# fixture corpus nor the dumper's creepSnap carries a camp record.
#
# SIX FILES ARE MUTATED, because the blindness spans the whole chain: the
# catch-all getter (bot_api.lua), the loader that could serve it
# (replay_fixture.lua), the helper holding the arm (jmz_func.lua), the green
# test that supplies the missing input (test_roamidle_recovery_clobber.lua),
# the dumper that is the other instrument (main.go) and campsel's own gate
# site (mode_farm_generic.lua).
#
# RESTORE IS FROM FILE COPIES TAKEN OUTSIDE THE TREE and is verified with
# `git diff --quiet` rather than a checksum of the stand's own backups: a hash
# round-trip only proves a backup is self-consistent, and stays green when the
# backup was taken from an ALREADY MUTATED file.  `git diff` compares against
# the index, so it catches that case too and can only err noisily.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

BOTAPI='tests/mock/bot_api.lua'
LOADER='tests/mock/replay_fixture.lua'
JMZ='bots/FunLib/jmz_func.lua'
RTEST='tests/test_roamidle_recovery_clobber.lua'
DUMPER='tools/batch_test/behavioral/dumper/main.go'
FARM='bots/mode_farm_generic.lua'
ATOMS='iterations/promote_atoms.json'
FIXTURE='tests/fixtures/f_260819_181742_ss_chase_start.lua'

FILES=("$BOTAPI" "$LOADER" "$JMZ" "$RTEST" "$DUMPER" "$FARM" "$ATOMS" "$FIXTURE")

BAKDIR="$(mktemp -d)"
for f in "${FILES[@]}"; do
    cp "$f" "$BAKDIR/$(echo "$f" | tr '/' '_')" || exit 2
done

restore() {
    for f in "${FILES[@]}"; do
        cp "$BAKDIR/$(echo "$f" | tr '/' '_')" "$f" || exit 2
    done
    if ! git diff --quiet -- "${FILES[@]}"; then
        echo "RESTORE FAILED -- the tree still differs from the index. STOP."
        git diff --stat -- "${FILES[@]}"
        exit 2
    fi
}
trap restore EXIT

TEST='test_blind_a_roamidle_campsel'

CAUGHT=0
SURVIVED=0

# Run the defended test; echo CAUGHT if it goes red (the mutant was detected).
run_mutant() {
    local label="$1"
    local out rc
    out="$(lua5.1 tests/run_tests.lua "$TEST" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        CAUGHT=$((CAUGHT + 1))
        echo "  CAUGHT    $label"
    else
        SURVIVED=$((SURVIVED + 1))
        echo "  SURVIVED  $label   <-- the test does not defend this"
        echo "$out" | tail -3 | sed 's/^/            /'
    fi
    restore
}

echo "=== control: unmutated tree must be GREEN ==="
control_out="$(lua5.1 tests/run_tests.lua "$TEST" 2>&1)"; control_rc=$?
if [ "$control_rc" -ne 0 ]; then
    echo "CONTROL FAILED (exit $control_rc) -- the stand proves nothing. STOP."
    echo "$control_out" | tail -20
    exit 2
fi
echo "  control_ok=1  ($(echo "$control_out" | tail -1))"
echo

echo "=== mutants: each LIFTS the blindness or dissolves a reason for it ==="

# M1  The catch-all stops answering 0 -- the arm's comparison could now match.
sed -i "s|if key:find('\^Get') then return 0 end|if key:find('^Get') then return 1174 end|" "$BOTAPI"
run_mutant "M1  bot_api ^Get catch-all answers 1174 instead of 0"

# M2  The helper relocates unconditionally -- the arm is no longer selective.
perl -0pi -e "s/if bot:GetCurrentActionType\(\) == BOT_ACTION_TYPE_IDLE\n\t\t\t\tor botMode == BOT_MODE_ITEM\n\t\t\t\tor botMode == BOT_MODE_FARM then/if true then/" "$JMZ"
run_mutant "M2  jmz_func: the recovery arm becomes unconditional"

# M3  The loader starts serving the pivot -- the gap [3a] is about is closed.
perl -0pi -e "s/(    -- GH #61: refuse to answer GetLaneFrontLocation)/    rawget(bot, '__spec').GetCurrentActionType = 1174\n\n\$1/" "$LOADER"
run_mutant "M3  loader serves GetCurrentActionType (the never-generalised fix, generalised)"

# M4  The loader's diagnosis of the mechanism disappears -- the witness is lost.
perl -0pi -e 's/was `0 == 1174`/was zero-versus-sentinel/' "$LOADER"
run_mutant "M4  loader note stops naming the 0 == 1174 mechanism"

# M5  The green test stops declaring its synthetic -- S-B becomes invisible.
perl -0pi -e 's/--   S-B  /--   S-Z  /' "$RTEST"
run_mutant "M5  roamidle test drops the S-B label"

# M6  The green test's replay-side declaration disappears.
perl -0pi -e 's/the behavioural dump carries no action/the behavioural dump has an action/' "$RTEST"
run_mutant "M6  roamidle test drops its replay-side wall declaration"

# M7  The dumper gains an action type -- the replay path buys the reading.
perl -0pi -e 's/(\tTeam int32   `json:"team"`\n\tX    float64 `json:"x"`)/\tAType int32 `json:"action_type"`\n$1/' "$DUMPER"
run_mutant "M7  dumper emits action_type"

# M8  The dumper's creep snapshot gains a name -- camp type becomes derivable.
perl -0pi -e 's/(type creepSnap struct \{\n\tT    float64 `json:"t"`)/$1\n\tName string  `json:"name"`/' "$DUMPER"
run_mutant "M8  dumper creepSnap gains a name field"

# M9  A promote atom names a retired id -- the pullcad trap becomes live.
perl -0pi -e 's/^\{/\{\n  "_mut": { "kind": "no_promote_without", "subject": ["roamidle"] },/' "$ATOMS"
run_mutant "M9  promote_atoms.json names roamidle"

# M10 campsel's gate is deleted -- a retirement silently became a reject.
perl -0pi -e "s/J\.IsSoakCandidate\('campsel'\)/false/" "$FARM"
run_mutant "M10 campsel gate removed from bots/ (retirement turned into a reject)"

# M11 A fixture gains the pivot -- the corpus buys the reading.
printf "\n-- mut\nlocal _ = 'GetCurrentActionType'\n" >> "$FIXTURE"
run_mutant "M11 a fixture gains GetCurrentActionType"

# M12 A fixture gains a camp record -- campsel's corpus wall lifts.
printf "\n-- mut\nlocal _ = 'cattr'\n" >> "$FIXTURE"
run_mutant "M12 a fixture gains a camp record (cattr)"

echo
echo "MUTSTAND  $CAUGHT CAUGHT / $SURVIVED SURVIVED / control_ok=1"
[ "$SURVIVED" -eq 0 ] || exit 3
