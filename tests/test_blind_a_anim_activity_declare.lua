-- BLIND-A: can condition (a) be ASKED at all through GetAnimActivity?
-- Director RULING 83 on GH #908 (2026-09-19), options (2)+(3).
--
-- (a) is "the fix really executes in a real game, and its decision is right".
-- For every id whose path runs through J.IsRunning / J.IsAttacking /
-- J.IsChasingTarget, (a) was not merely unanswered in this repo -- it was
-- UNASKABLE.  bot_api.lua's `key:find('^Get') then return 0` catch-all answers
-- a fabricated 0 for bot:GetAnimActivity() on every handle of every fixture,
-- and 0 is no ACTIVITY_* the engine sends (the mock resolves those ALL_CAPS
-- names to distinct ids seeded at 1000), so all three predicates were
-- identically FALSE over the whole corpus -- 1060 shipped call sites in 149
-- bots/ files, and not one verdict in tests/ had ever seen the true branch.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  It does not claim the ~66 existing cases
-- that press against those predicates are WRONG.  They are verdicts taken on
-- the not-running / not-attacking branch -- a state a real hero is in most of
-- the time.  What they lack is the DECLARATION that they chose it, so their
-- scope is narrower than their wording: certified over the false branch only.
-- That narrowing is RULING 83 option (3); this file buys option (2), the
-- ability to ask.
--
-- ⭐ The measured reason the refusal is opt-in rather than unconditional:
-- installing it on every handle was tried and priced (replay-check
-- 20260918T215806Z) at 18 files / 70 cases red, including the real-frame
-- verdict of a PROMOTED id, which stops every stream's pre-push hook.  And
-- GetAnimActivity is 1 of the 164 shipped getters that same catch-all answers
-- for (tests/test_mockscalar_return_shape.lua counts them), so the
-- unconditional form is not a bounded 70-case purchase -- it is instalment 1
-- of 164.  [5] below pins that this file changed nothing for the other 66.
--
-- ⭐⭐ [3] is the case worth reading twice: clearing the activity lock is NOT
-- enough to make J.IsAttacking answerable, because it has a SECOND fabricated
-- zero underneath it (GetAttackPoint and GetAnimCycle, both catch-all 0, whose
-- comparison `0 > 0 * 0.99` is false forever).  One getter was never the size
-- of this defect, and this file measures that on a real frame instead of
-- asserting it in prose.

-- ⭐ TWO CASES CARRY A `[ratchet]` TAG, AND THE TAG IS LOAD-BEARING, NOT
-- DECORATION.  开工自检's fast Lua leg discovers files BY TAG, and the two
-- tagged claims are the standing invariants the rest of this file rests on:
-- [1] that the undeclared world is still identically false (it changes the day
-- anyone touches bot_api's `^Get -> 0`), and [5] that the switch is still
-- opt-in (it changes the day anyone "generalises" this into the unconditional
-- form RULING 83 priced and refused).  Measured cost of the whole file on this
-- container: 0.16s over three runs -- the leg's own rule is TIME the set before
-- tagging into it, so the number is written down rather than assumed.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local tests = {}

local F = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'
local SUBJ = 'npc_dota_hero_shadow_shaman'   -- team 2, alive
local FOE  = 'npc_dota_hero_ember_spirit'    -- team 3, alive

local function eq(sWhat, actual, expected)
    if actual ~= expected then
        error(sWhat .. ': got ' .. tostring(actual)
            .. ', want ' .. tostring(expected), 2)
    end
end

tests['[ratchet] [1] undeclared, the predicate family is identically FALSE'] =
function()
    local J, bot = rf.load(F)
    eq('the catch-all answer', bot:GetAnimActivity(), 0)
    if not (ACTIVITY_RUN > 1000) then
        error('ACTIVITY_RUN did not resolve to a mock sentinel: '
            .. tostring(ACTIVITY_RUN))
    end
    eq('J.IsRunning on a real frame', J.IsRunning(bot), false)
    eq('J.IsAttacking on a real frame', J.IsAttacking(bot), false)
end

tests['[2] declaring run makes J.IsRunning answer from the declaration'] =
function()
    local J, bot, heroes = rf.load(F)
    local n = rf.declare_anim_activity(heroes, { [SUBJ] = 'run' })
    eq('declared count', n.declared, 1)
    if n.refused < 1 then error('nobody refused; the roster looks empty') end
    eq('GetAnimActivity', bot:GetAnimActivity(), ACTIVITY_RUN)
    eq('J.IsRunning', J.IsRunning(bot), true)
end

tests['[3] the activity lock is not the only fabricated zero under IsAttacking']
= function()
    local J, bot, heroes = rf.load(F)
    rf.declare_anim_activity(heroes, { [SUBJ] = 'attack' })
    eq('the activity lock is cleared', bot:GetAnimActivity(), ACTIVITY_ATTACK)
    -- ...and the verdict still cannot be bought, for a reason one layer down.
    eq('GetAttackPoint', bot:GetAttackPoint(), 0)
    eq('GetAnimCycle', bot:GetAnimCycle(), 0)
    eq('J.IsAttacking is still unanswerable', J.IsAttacking(bot), false)
end

tests['[4] an undeclared unit REFUSES; the refusal reaches IsChasingTarget'] =
function()
    local J, bot, heroes = rf.load(F)
    rf.declare_anim_activity(heroes, { [SUBJ] = 'run' })

    local ok, err = pcall(function() return heroes[FOE]:GetAnimActivity() end)
    eq('an undeclared unit answered instead of refusing', ok, false)
    if not tostring(err):find('LOADER REFUSES', 1, true) then
        error('wrong error from an undeclared unit: ' .. tostring(err))
    end

    -- The point of the refusal: J.IsChasingTarget reads BOTH sides, so a test
    -- that declares only its subject must be told, not handed a false.
    local ok2 = pcall(function() return J.IsChasingTarget(bot, heroes[FOE]) end)
    eq('IsChasingTarget swallowed the undeclared side', ok2, false)

    -- Declaring the other side too makes the predicate evaluable again.
    rf.declare_anim_activity(heroes, { [SUBJ] = 'run', [FOE] = 'run' })
    eq('J.IsRunning(subject)', J.IsRunning(bot), true)
    eq('J.IsRunning(target)', J.IsRunning(heroes[FOE]), true)
    local ok3 = pcall(function() return J.IsChasingTarget(bot, heroes[FOE]) end)
    eq('IsChasingTarget still raised with both sides declared', ok3, true)
end

tests['[ratchet] [5] opt-in: a plain load() installs nothing, so the other 66 stand'] =
function()
    local _, bot, heroes = rf.load(F)
    for sName, h in pairs(heroes) do
        if rawget(h, '__spec').GetAnimActivity ~= nil then
            error('load() installed GetAnimActivity on ' .. sName
                .. '; this switch must stay opt-in (RULING 83)')
        end
    end
    eq('the pre-#908 world is untouched', bot:GetAnimActivity(), 0)
end

tests['[6] idle is a DECLARED non-zero, not the fabricated 0'] = function()
    local J, bot, heroes = rf.load(F)
    rf.declare_anim_activity(heroes, { [SUBJ] = 'idle' })
    if bot:GetAnimActivity() == 0 then
        error("'idle' handed back the fabricated 0; a test taking the pre-#908"
            .. ' stub must say so with a real ACTIVITY_* value')
    end
    eq("'idle' resolves to ACTIVITY_IDLE", bot:GetAnimActivity(), ACTIVITY_IDLE)
    eq('J.IsRunning under idle', J.IsRunning(bot), false)
end

tests['[7] a typo raises instead of silently no-opping'] = function()
    local _, _, heroes = rf.load(F)

    local ok, err = pcall(rf.declare_anim_activity, heroes,
        { npc_dota_hero_not_in_this_fixture = 'run' })
    eq('an unknown unit name was accepted', ok, false)
    if not tostring(err):find('no unit named', 1, true) then
        error('wrong error for an unknown unit: ' .. tostring(err))
    end

    local ok2, err2 = pcall(rf.declare_anim_activity, heroes,
        { [SUBJ] = 'running' })
    eq('an unknown activity word was accepted', ok2, false)
    if not tostring(err2):find("want 'run'", 1, true) then
        error('wrong error for an unknown word: ' .. tostring(err2))
    end
end

return tests
