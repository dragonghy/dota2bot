#!/usr/bin/env bash
# Mutation stand for tests/test_blind_a_wandlimbo_tpdead.lua.
#
# The file it defends records a BLINDNESS: two armed soak candidates whose
# condition (a) cannot be bought from any instrument this lab owns, which is why
# both were retired from the armed set on 2026-09-08 (test_set.md §GC).
#
# ⭐ SO EVERY MUTANT BELOW RUNS IN THE SAME DIRECTION, AND IT IS THE DIRECTION
# THAT MATTERS: each one LIFTS a blindness or dissolves a reason, i.e. each one
# makes the ruling wrong.  A test that stays green through those is a test that
# would let the tree buy the missing instrument -- or lose the reason the
# instrument was missing -- without anybody noticing that two retired ids are now
# re-proposable.  That is the only failure mode this file has: it cannot go
# wrong by being too strict, it can only go wrong by outliving its own subject.
#
# THREE FILES ARE MUTATED, because the blindness spans the whole evidence chain:
# the helper (jmz_func.lua), the fixture end (tests/mock/replay_fixture.lua) and
# the replay end (the dumper).  `restore` puts all three back.
#
# RESTORE IS FROM FILE COPIES AND IS VERIFIED WITH `git diff`, not with a
# checksum of the stand's own backups: a hash round-trip only proves a backup is
# self-consistent, and it stays green when the backup was taken from an ALREADY
# MUTATED file.  `git diff --quiet` compares against the index, so it also
# catches that case, and it can only err in the noisy direction.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

JMZ='bots/FunLib/jmz_func.lua'
LOADER='tests/mock/replay_fixture.lua'
DUMPER='tools/batch_test/behavioral/dumper/main.go'
WLTEST='tests/test_replay_181441_wand_limbo.lua'
TDTEST='tests/test_tpdead_release.lua'

BAK_JMZ="$(mktemp)"
BAK_LOADER="$(mktemp)"
BAK_DUMPER="$(mktemp)"
BAK_WLTEST="$(mktemp)"
BAK_TDTEST="$(mktemp)"
RUNNER="$(mktemp /tmp/blindstand_runner.XXXXXX.lua)"

cp "$JMZ" "$BAK_JMZ" || exit 2
cp "$LOADER" "$BAK_LOADER" || exit 2
cp "$DUMPER" "$BAK_DUMPER" || exit 2
cp "$WLTEST" "$BAK_WLTEST" || exit 2
cp "$TDTEST" "$BAK_TDTEST" || exit 2

# `restore` is defined BEFORE the trap that calls it, and the trap calls it by
# NAME rather than repeating the copies inline.  Both halves are load-bearing:
# an interrupted run must put all three pristine files back, and a trap body
# that open-codes the copies is the shape tests/test_mutstand_restore_trap.py
# exists to refuse (GH #418 -- a last-armed trap that reaches no restore is
# strictly worse than no trap at all, because it can also delete the only
# pristine copy).
restore() {
    cp "$BAK_JMZ" "$JMZ"
    cp "$BAK_LOADER" "$LOADER"
    cp "$BAK_DUMPER" "$DUMPER"
    cp "$BAK_WLTEST" "$WLTEST"
    cp "$BAK_TDTEST" "$TDTEST"
}

trap 'restore 2>/dev/null; rm -f "$BAK_JMZ" "$BAK_LOADER" "$BAK_DUMPER" "$BAK_WLTEST" "$BAK_TDTEST" "$RUNNER"' EXIT

cat > "$RUNNER" <<'LUA'
package.path = 'tests/?.lua;' .. package.path
local ok, t = pcall(dofile, 'tests/test_blind_a_wandlimbo_tpdead.lua')
if not ok then os.exit(1) end
local bad = 0
for _, fn in pairs(t) do
    local s = pcall(fn)
    if not s then bad = bad + 1 end
end
os.exit(bad == 0 and 0 or 1)
LUA

run_test() { lua5.1 "$RUNNER" >/dev/null 2>&1; echo $?; }

caught=0; survived=0; ctrl_ok=0

# The CONTROL first, and it runs before any mutant so a stand that is simply
# broken cannot print CAUGHT for everything.  ⚠ Picking it needed care here:
# this test READS PROSE on purpose in three places (the two `stayfield`
# declarations, the writer's inertness note, the census row), because "the wall
# was already written down" is a claim about comments.  So the control edits a
# comment NO assertion reads -- the wandlimbo header's own frame citation.  If
# that edit is caught, the file is reading prose it did not mean to and every
# CAUGHT below is worthless.
control() {
    restore
    perl -0pi -e 's/-- Real frame: 20260722_181441_slot1/-- Real frame (control edit): 20260722_181441_slot1/' "$JMZ"
    if ! git diff --quiet -- "$JMZ"; then
        local rc; rc="$(run_test)"
        if [ "$rc" = "0" ]; then
            echo "CONTROL ok      : a pure comment edit is NOT caught"; ctrl_ok=1
        else
            echo "CONTROL BROKEN  : a comment-only edit turned the test red -- prose is being read as code"
        fi
    else
        echo "CONTROL BROKEN  : the control edit did not land (anchor missing)"
    fi
    restore
}

# $1 = label, $2 = file, $3 = perl program
mutate() {
    local label="$1"; local file="$2"; shift 2
    restore
    perl -0pi -e "$1" "$file"
    if git diff --quiet -- "$file"; then
        echo "ANCHOR MISS     : $label -- the mutation did not land, so its CAUGHT would be a lie"
        survived=$((survived + 1))
        restore
        return
    fi
    local rc; rc="$(run_test)"
    if [ "$rc" != "0" ]; then
        echo "CAUGHT          : $label"; caught=$((caught + 1))
    else
        echo "SURVIVED        : $label"; survived=$((survived + 1))
    fi
    restore
}

control

# ---------------------------------------------------------------- half 1
# M1 -- THE PURCHASE ITSELF, and the most important mutant in the file: the
# fixture loader starts serving charges.  This is exactly the instrument the
# ruling's owed row asks for, so the day it lands `wandlimbo` becomes
# re-proposable -- and the test must say so rather than keep asserting a
# blindness that has been lifted.  Note it is a BEHAVIOURAL mutant, not just a
# textual one: with 7 charges the helper fires on its own motivating frame, so
# it drives section 1c as well as parsing section 1b.
mutate "M1 fixture loader serves GetCurrentCharges (the blindness is lifted)" "$LOADER" \
    's/\{\n                    IsFullyCastable = true,\n                \}\)/{\n                    IsFullyCastable = true,\n                    GetCurrentCharges = function() return 7 end,\n                })/'

# M2 -- the OTHER end of the same chain.  If the dumper starts carrying charges,
# a behavioural detector can reconstruct the clause and the ruling's "no
# instrument" becomes "not from fixtures", which is a different and much weaker
# claim.
mutate "M2 dumper emits per-item charges (the replay half is buyable)" "$DUMPER" \
    's/\tItems     \[\]string      `json:"items"`/\tItems     []string      `json:"items"`\n\tCharges   []int32       `json:"item_charges"`/'

# M3 -- the CONSTANT this file quotes.  A silent move leaves the whole header
# describing a lever the tree no longer has, and the pinned corpus readings
# (taken at 6) describing a different predicate.
mutate "M3 charge floor moved 6 -> 4 (pinned readings describe another lever)" "$JMZ" \
    's/\tif nCharges < 6 then return false end/\tif nCharges < 4 then return false end/'

# M4 -- the ORDER, which is what makes the instrument's 0 fatal to the WHOLE
# predicate rather than to one conjunct.  Swap the charge read below the HP
# clause and `wl_full 0` stops meaning "the instrument short-circuited it";
# the file would then be pinning a number whose interpretation had changed
# underneath it.
mutate "M4 charge read moved after the HP clause (short-circuit claim dissolves)" "$JMZ" \
    's/\tlocal nCharges = hItem:GetCurrentCharges\(\)\n\tif nCharges < 6 then return false end\n\n\tif bot:GetHealth\(\) > bot:GetMaxHealth\(\) \* 0\.25 then return false end/\tif bot:GetHealth() > bot:GetMaxHealth() * 0.25 then return false end\n\n\tlocal nCharges = hItem:GetCurrentCharges()\n\tif nCharges < 6 then return false end/'

# M5 -- the DECLARATION.  "The wall was already written down" is this round's
# whole finding, and it rests on two sentences in the `stayfield` note.  Lose one
# and the finding is an unsourced assertion about what somebody knew.
mutate "M5 the stayfield mock declaration is reworded (finding loses its citation)" "$JMZ" \
    's/GetCurrentCharges default is 0\. Declared, not hidden\./GetCurrentCharges default is 0 by default./'

# ---------------------------------------------------------------- half 2
# M6 -- INVERTED 2026-09-12 with the tpcommit PROMOTE (director RULING 20).
# It used to REMOVE the `tpcommit` gate, because the gate was what made `tpdead`
# unreachable alone.  The promote removed it for real, so the old mutation no
# longer lands (the stand's ANCHOR MISS guard would have said so rather than
# quietly scoring a CAUGHT -- that guard is why this was visible at all).  The
# mutation worth making now is the REVERSE: re-gate the promoted floor.  That is
# the shape a future round can drift into by accident, it silently un-ships a
# turbo default, and it puts `tpdead` back out of single-arm reach.
mutate "M6 a tpcommit gate returns to the promoted floor (turbo default un-ships)" "$JMZ" \
    's/function J\.GetTpCommitDefendDesire\( bot, nLane \)\n\tif not J\.IsModeTurbo\(\) then return nil end/function J.GetTpCommitDefendDesire( bot, nLane )\n\tif not J.IsModeTurbo() then return nil end\n\tif not J.IsSoakCandidate( \x27tpcommit\x27 ) then return nil end/'

# M7 -- the OTHER half of "armed alone is a no-op".  The stamp having exactly one
# reader is what makes the ungated writer inert; give it a second reader outside
# the gated function and arming `tpdead` alone can change behaviour again.
# ⚠ The anchor is the wandlimbo charge line, which is unique in this file and --
# the point -- lives in a DIFFERENT function, so the inserted read really is
# outside J.GetTpCommitDefendDesire.
mutate "M7 a second reader of the stamp appears outside the gate (no-op claim dies)" "$JMZ" \
    's/\tlocal nCharges = hItem:GetCurrentCharges\(\)/\tlocal _stale = bot.tpRespondAlly\n\tlocal nCharges = hItem:GetCurrentCharges()/'

# M8 -- the STATE GATE the sweep's control died on.  Remove it and the corpus can
# reach the function, so `td_armed_alone_nonnil 0` would become a real reading
# instead of a blindness -- and half 2 could be upgraded from source to driven.
# The test must demand that re-run rather than keep quoting an unreachability
# that no longer holds.
mutate "M8 the response-TP state gate is dropped (the corpus can reach it now)" "$JMZ" \
    's/\tif bot\.tpRespondLoc == nil or bot\.tpRespondUntil == nil then return nil end\n//'

# -------------------------------------------------- the stubbed-input sections
# M9/M10 defend the finding this file leads with: each id has a GREEN fixture
# test on a real frame that supplies, by hand, the one input its lever turns on.
# If those tests ever start READING that input from the frame, condition (a)
# becomes buyable and both retirements are due for re-reading -- so the sections
# must go red then, not quietly keep describing a stub that is gone.
mutate "M9 the wandlimbo fixture test stops stubbing charges (a becomes buyable)" "$WLTEST" \
    "s/    rawget\(wand, '__spec'\)\.GetCurrentCharges = n\n/    local _ = n\n/"

mutate "M10 the tpdead release test stops writing the commitment state" "$TDTEST" \
    's/    bot\.tpRespondUntil = f\.cast \+ COMMIT\n//'

restore
rc=0
for f in "$JMZ" "$LOADER" "$DUMPER" "$WLTEST" "$TDTEST"; do
    if git diff --quiet -- "$f"; then
        echo "RESTORE         : YES -- $f is byte-identical to the index"
    else
        echo "RESTORE         : NO -- $f still differs from the index; FIX THIS"
        rc=2
    fi
done
[ "$rc" = "0" ] || exit 2

echo "----"
echo "control_ok=$ctrl_ok caught=$caught survived=$survived"
if [ "$ctrl_ok" != "1" ]; then exit 3; fi
if [ "$survived" != "0" ]; then exit 3; fi
exit 0
