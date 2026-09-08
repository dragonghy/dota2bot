#!/usr/bin/env bash
# Mutation stand for tests/test_blind_a_cmrguard.lua.
#
# The file it defends records a BLINDNESS: `cmrguard`'s veto ring is
# `hCc:GetCastRange() + 400` read off an ENEMY's ability, and this lab's fixture
# loader never reads an enemy's cast range -- it comes back through
# tests/mock/bot_api.lua's `^Get -> 0` catch-all.  That is why the id was retired
# from the armed set on 2026-09-08 (test_set.md §GD), and why the armed gate does
# not fire on the very frame it was filed for.
#
# ⭐ SO EVERY MUTANT BELOW RUNS IN THE SAME DIRECTION: each one LIFTS the
# blindness or dissolves a reason for it, i.e. each one makes the ruling wrong.
# A test that stays green through those is a test that would let the tree buy the
# missing instrument -- or lose the reason it was missing -- without anybody
# noticing that a retired id has become re-proposable.  The file cannot go wrong
# by being too strict; it can only go wrong by outliving its own subject.
#
# SIX FILES ARE MUTATED, because the blindness spans the whole chain: the KV
# roster (special_value_shapes.lua), the loader that consults it
# (replay_fixture.lua), the catch-all underneath both (bot_api.lua), the lever
# and its constants (hero_crystal_maiden.lua), the green test that supplies the
# missing input (test_replay_260819_cm_r_range.lua) and the shipped second
# consumer (jmz_func.lua).  `restore` puts all six back.
#
# RESTORE IS FROM FILE COPIES AND IS VERIFIED WITH `git diff`, not with a
# checksum of the stand's own backups: a hash round-trip only proves a backup is
# self-consistent and stays green when the backup was taken from an ALREADY
# MUTATED file.  `git diff --quiet` compares against the index, so it catches
# that case too, and it can only err in the noisy direction.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

SHAPES='tests/mock/special_value_shapes.lua'
LOADER='tests/mock/replay_fixture.lua'
BOTAPI='tests/mock/bot_api.lua'
CM='bots/BotLib/hero_crystal_maiden.lua'
RTEST='tests/test_replay_260819_cm_r_range.lua'
JMZ='bots/FunLib/jmz_func.lua'

BAK_SHAPES="$(mktemp)"
BAK_LOADER="$(mktemp)"
BAK_BOTAPI="$(mktemp)"
BAK_CM="$(mktemp)"
BAK_RTEST="$(mktemp)"
BAK_JMZ="$(mktemp)"
RUNNER="$(mktemp /tmp/cmrgstand_runner.XXXXXX.lua)"

cp "$SHAPES" "$BAK_SHAPES" || exit 2
cp "$LOADER" "$BAK_LOADER" || exit 2
cp "$BOTAPI" "$BAK_BOTAPI" || exit 2
cp "$CM" "$BAK_CM" || exit 2
cp "$RTEST" "$BAK_RTEST" || exit 2
cp "$JMZ" "$BAK_JMZ" || exit 2

# `restore` is defined BEFORE the trap that calls it, and the trap calls it by
# NAME rather than repeating the copies inline -- the shape
# tests/test_mutstand_restore_trap.py exists to require (GH #418: a trap that
# reaches no restore is strictly worse than no trap, since it can also delete the
# only pristine copy).
restore() {
    cp "$BAK_SHAPES" "$SHAPES"
    cp "$BAK_LOADER" "$LOADER"
    cp "$BAK_BOTAPI" "$BOTAPI"
    cp "$BAK_CM" "$CM"
    cp "$BAK_RTEST" "$RTEST"
    cp "$BAK_JMZ" "$JMZ"
}

trap 'restore 2>/dev/null; rm -f "$BAK_SHAPES" "$BAK_LOADER" "$BAK_BOTAPI" "$BAK_CM" "$BAK_RTEST" "$BAK_JMZ" "$RUNNER"' EXIT

cat > "$RUNNER" <<'LUA'
package.path = 'tests/?.lua;' .. package.path
local ok, t = pcall(dofile, 'tests/test_blind_a_cmrguard.lua')
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

# The CONTROL runs FIRST, so a stand that is simply broken cannot print CAUGHT
# for everything.  ⚠ Picking it needed care: this test reads PROSE on purpose in
# three places (the green test's stub, the loader's declared hazard, the shipped
# consumer's shape), because "the wall was already written down for the
# neighbouring key" is a claim about comments.  So the control edits a comment NO
# assertion reads -- the guard's own frame citation in hero_crystal_maiden.lua.
# If that edit is caught, the file is reading prose it did not mean to and every
# CAUGHT below is worthless.
control() {
    restore
    perl -0pi -e 's/-- had no check on CM\x27s own safety before committing/-- had no check (control edit) on CM\x27s own safety before committing/' "$CM"
    if ! git diff --quiet -- "$CM"; then
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
    local label="$1"; local file="$2"; local prog="$3"
    restore
    perl -0pi -e "$prog" "$file"
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

# ------------------------------------------------------------- the purchase
# M1 -- THE MOST IMPORTANT MUTANT IN THE FILE: the KV roster grows a hard-CC
# carrier.  This is half of the instrument the ruling's owed row asks for, and
# the day it lands `cmrguard`'s case in chief becomes readable -- the armed gate
# starts firing on its own motivating frame.  The test must say so rather than
# keep asserting a blindness that has been lifted.  BEHAVIOURAL, not just
# textual: it drives case 1b through a real ice_path cast range.
mutate "M1 the KV roster grows jakiro (the case in chief becomes readable)" "$SHAPES" \
    "s/X\.SHAPES = \{\n/X.SHAPES = {\n    ['jakiro'] = {\n        ['jakiro_ice_path'] = {\n            ['AbilityCastRange'] = { base = '1000 1000 1000 1000', bonus = {  } },\n        },\n    },\n/"

# M2 -- the OTHER half of the purchase: the loader stops making the cast-range
# getter conditional on the key being declared, which is exactly the shape it
# already uses one branch below for AbilityDamage.  After this a 0 means "the KV
# declares none", so "every zero in the corpus is the catch-all's" stops being
# true and the sweep's headline reading must be re-taken.
mutate "M2 the loader installs GetCastRange unconditionally (a zero means the KV)" "$LOADER" \
    's/                    if cast_range ~= nil then\n                        sp\.GetCastRange = function\(self\)\n                            return rank_step\(cast_range, self:GetLevel\(\)\)\n                        end\n                    end/                    sp.GetCastRange = function(self)\n                        if cast_range == nil then return 0 end\n                        return rank_step(cast_range, self:GetLevel())\n                    end/'

# M3 -- the FLOOR the whole blindness rests on.  If the catch-all stops answering
# 0 for an unserved getter, "the ring collapses to the buffer" is no longer the
# failure mode and the file is describing a mock that no longer exists.
mutate "M3 the catch-all stops answering 0 for unserved getters" "$BOTAPI" \
    "s/    if key:find\('\\^Get'\) then return 0 end/    if key == 'GetCastRange' then return 900 end\n    if key:find('^Get') then return 0 end/"

# ----------------------------------------------------------------- the lever
# M4 -- the CONSTANT that makes the collapse decisive.  At a wide enough buffer
# the gate fires on the motivating frame even while blind, so the blindness stops
# being what disarms it and the ruling's central reading dissolves.
mutate "M4 the closing buffer widens 400 -> 1200 (blind, the gate fires anyway)" "$CM" \
    's/X\.nRGuardCloseBuffer = 400/X.nRGuardCloseBuffer = 1200/'

# M5 -- the RANGE TERM ITSELF leaves the predicate, i.e. the GH #34 narrowing is
# reverted to the range-blind gate.  Then there is no enemy cast range to read
# and nothing for this file to be about -- but every assertion about the ring
# would still be sitting there looking green.
mutate "M5 the narrowing is reverted (no enemy cast range is read at all)" "$CM" \
    's/\t\t\t\t\tlocal nCcRange = hCc:GetCastRange\(\) or 0/\t\t\t\t\tlocal nCcRange = 1600/'

# ------------------------------------------------- the stubbed-pivot finding
# M6 -- the file leads with "the green test supplies the one input the lever
# turns on".  If that test ever starts READING the value from the frame instead,
# condition (a) is buyable and the retirement is due for re-reading -- so the
# section must go red then, not quietly keep describing a stub that is gone.
mutate "M6 the green test stops writing the cast range in (a becomes buyable)" "$RTEST" \
    "s/    rawget\(icePath, '__spec'\)\.GetCastRange = 1000 -- under-estimate; see header\n//"

# M7 -- the DECLARATION the ruling's sharpest sentence rests on: the loader's own
# note that a 0 must come from reading the KV, written for AbilityDamage and
# never applied to AbilityCastRange.  Lose it and "the house already diagnosed
# this and fixed the neighbouring key" becomes an unsourced claim about what
# somebody knew.
mutate "M7 the loader's declared hazard is reworded (the finding loses its citation)" "$LOADER" \
    's/-- two are indistinguishable from the read and are not/-- two are hard to tell apart from the read and are not/'

# M8 -- the SCOPE claim: the debt is not one retired candidate's, because the
# shipped ccburst window reads the same enemy-side range ungated.  Give that one
# a gate and it stops being evidence that the blindness is live in real games.
mutate "M8 the shipped consumer grows a gate (the debt stops being live)" "$JMZ" \
    's/\t\t\tif bCcAware then\n\t\t\t\tlocal hCc = J\.GetReadyHardCc\( hEnemy \)/\t\t\tif bCcAware and J.IsSoakCandidate( \x27ccburst\x27 ) then\n\t\t\t\tlocal hCc = J.GetReadyHardCc( hEnemy )/'

restore
rc=0
for f in "$SHAPES" "$LOADER" "$BOTAPI" "$CM" "$RTEST" "$JMZ"; do
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
