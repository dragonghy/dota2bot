-- `LVLQUEUE`: no focus-five build row asks for a rank before the hero level that
-- rank is legal at.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- `X['sSkillList']` is not a table of preferences, it is a QUEUE, and the code
-- that spends it is HEAD-BLOCKING.  bots/ability_item_usage_generic.lua takes
-- `sAbilityLevelUpList[1]`, and when that entry cannot be levelled yet
-- (`botLevel >= abilityToLevelup:GetHeroLevelRequiredToUpgrade()` is false) it
-- falls through every branch to a final `else` that prints a warning and does
-- NOT `table.remove` -- the pop is guarded by `botLevel > 25`.  So an entry that
-- arrives early does not get skipped: it parks at the head and every ability
-- point behind it parks with it, for as many levels as it takes.  Nothing says
-- so at runtime (`print()` never reaches the server console, AGENTS.md).
--
-- That makes the queue ORDER a correctness property, not a taste question, and
-- it is a property nothing checked.  tests/test_focus_level_claims.lua pins the
-- PROSE about these rows against the code (GH #134); it does not ask whether the
-- rows are legal.  A build edit that moves the ultimate one row earlier is a
-- one-character change that stalls the hero -- and hero_skeleton_king.lua ships a
-- SECOND row behind the gated soak candidate `wkbuild`, so a row edit is a thing
-- this project actually does.
--
-- WHAT IT PINS
-- ------------
-- 1. THE HEAD-BLOCKING SHAPE ITSELF, in the source.  Everything below is only
--    interesting because a blocked head does not pop.  If a future edit makes
--    the spender skip past an entry it cannot use, these assertions stop meaning
--    what they say, so the shape is asserted rather than described.
-- 2. LEGALITY, off the shipped mapping.  Ranks come from
--    tests/skill_level_map.rank_ladder, which DRIVES the real
--    J.Skill.GetSkillList rather than counting row indices -- the row index is
--    not the hero level (GH #134: levels 10 and 15 go to talents, so the row's
--    14th and 15th entries land at levels 16 and 17).
-- 3. THE ONE EXCEPTION, WITH ITS COST.  Every row's third ultimate point lands
--    at level 17 and the ultimate's rank 3 needs level 18, so all seven rows
--    hold one point idle for exactly one level.  That is registered as a
--    NON-DEFECT, and the reason is checked rather than asserted in prose: at
--    level 17 every basic ability is already at rank 4, so the idle point has no
--    legal alternative -- there is nothing the hero could have spent it on, and
--    rank 3 of the ultimate is taken at 18, the earliest level it exists.
--
-- WHAT IS NOT CLAIMED
-- -------------------
--   * The level requirements are the game's standard ladder (basic rank n at
--     2n-1, ultimate at 6/12/18), written here as constants.  The engine's
--     `GetHeroLevelRequiredToUpgrade()` is the authority and it is not readable
--     offline (the mock has no ability levels -- same family as GH #133/#145),
--     so a hero whose abilities carry a non-standard `RequiredLevel` would be
--     mis-judged.  None of the focus five does.
--   * Legal is not good.  This says a row does not STALL; which row wins a game
--     is the batch's question (GH #17's `wkbuild` is exactly that question and
--     is still gated).
--   * Beyond level 17 the queue holds only talents, and the rows put t20 at
--     queue position 18 and t25 at 19 -- both blocked until 20 / 25.  That is
--     out of this test's scope AND out of turbo's domain (GH #84 read level >= 20
--     on 0 of 210 hero-slots), and it costs nothing for the same reason the
--     level-17 park does: by then there is nothing else in the queue.

package.path = package.path .. ';./tests/?.lua;./tests/mock/?.lua'

local skillmap = require('skill_level_map')

local tests = {}
local function check(bCond, sMsg) assert(bCond, sMsg) end

--------------------------------------------------------------------------------
-- 1. The head-blocking shape, in bots/ability_item_usage_generic.lua
--------------------------------------------------------------------------------

local sSpender = skillmap.read_file('bots/ability_item_usage_generic.lua')

tests['1. the spender is head-blocking: an illegal head parks, it does not pop'] = function()
check(sSpender:find('local abilityName = sAbilityLevelUpList%[1%]', 1, false) ~= nil,
    'the spender no longer reads the HEAD of the list; this file assumes a queue')

check(sSpender:find('botLevel >= abilityToLevelup:GetHeroLevelRequiredToUpgrade%(%)') ~= nil,
    'the spender no longer tests GetHeroLevelRequiredToUpgrade -- the legality '
    .. 'this file checks is not the legality the code checks')

-- The final `else`: a warning, and a pop ONLY above level 25.  If a pop appears
-- outside that guard, an illegal head is skipped instead of parking and every
-- finding below changes meaning.
local sTail = sSpender:match(
    "print%(\"%[WARN%] Skipped to level up ability \"(.-)\n\tend")
check(sTail ~= nil, 'the spender\'s final else branch was not found by its own '
    .. 'warning text -- re-read it before trusting this file')
if sTail ~= nil then
    check(sTail:find('table%.remove') ~= nil,
        'the final else no longer pops at all')
    check(sTail:find('if botLevel > 25') ~= nil,
        'the final else pops without the botLevel > 25 guard -- an illegal head '
        .. 'is now SKIPPED, not parked, so this file over-states its findings')
end
end

--------------------------------------------------------------------------------
-- 2. Legality of every shipped focus-five row
--------------------------------------------------------------------------------

-- The game's standard ladder.  Index = rank.
local tBasicReq = { 1, 3, 5, 7 }
local tUltReq = { 6, 12, 18 }

-- sAbilityList[6] is the ultimate: bots/FunLib/aba_skill.lua assigns index 6 in
-- its `ability:IsUltimate() and slot >= 4` branch and nowhere else.
local ULT_SLOT = 6
tests['2a. the ultimate is sAbilityList[6]'] = function()
check(skillmap.read_file('bots/FunLib/aba_skill.lua')
        :find('sAbilityList%[6%] = name') ~= nil,
    'aba_skill.lua no longer parks the ultimate at sAbilityList[6]; the ULT_SLOT '
    .. 'constant below is then wrong')
end

local tRows = {
    { 'axe',            'npc_dota_hero_axe',            'tAllAbilityBuildList', 1 },
    { 'zuus pos_2',     'npc_dota_hero_zuus',           'tAllAbilityBuildList', 1 },
    { 'zuus pos_4/5',   'npc_dota_hero_zuus',           'tAllAbilityBuildList', 2 },
    { 'wk default',     'npc_dota_hero_skeleton_king',  'tAllAbilityBuildList', 1 },
    { 'wk wkbuild',     'npc_dota_hero_skeleton_king',  'tKillBuildList',       1 },
    { 'lion',           'npc_dota_hero_lion',           'tAllAbilityBuildList', 1 },
    { 'crystal_maiden', 'npc_dota_hero_crystal_maiden', 'tAllAbilityBuildList', 1 },
}

local tFile = {
    ['npc_dota_hero_axe']            = 'bots/BotLib/hero_axe.lua',
    ['npc_dota_hero_zuus']           = 'bots/BotLib/hero_zuus.lua',
    ['npc_dota_hero_skeleton_king']  = 'bots/BotLib/hero_skeleton_king.lua',
    ['npc_dota_hero_lion']           = 'bots/BotLib/hero_lion.lua',
    ['npc_dota_hero_crystal_maiden'] = 'bots/BotLib/hero_crystal_maiden.lua',
}

--- THE CRITERION, extracted so section 3 can drive it on synthetic input: the
--- hero level at which `nRank` of `nSlot` becomes legal.
local function required_level(nSlot, nRank)
    if nSlot == ULT_SLOT then return tUltReq[nRank] end
    return tBasicReq[nRank]
end

--- THE SECOND CRITERION: is a point parked at `nLevel` costless?  It is exactly
--- when every non-ultimate slot is already at its last rank by then, i.e. the
--- hero has nothing else legal to spend it on.  Extracted for the same reason as
--- the other two: on a clean tree this one has NO live counterexample (the real
--- rows max their basics at 16, four levels clear of the bound), so loosening it
--- escapes green unless section 3 feeds it an offender.  That escape was
--- observed, not assumed -- mutation M5, 2026-08-25.
--- Returns nil when costless, or the slot that still wants a point.
local function unmaxed_slot_at(tLadder, nLevel)
    for nSlot, tRanks in pairs(tLadder) do
        if nSlot ~= ULT_SLOT and tRanks[#tRanks] > nLevel then return nSlot end
    end
    return nil
end

--- THE REPORT, likewise extracted.  Returns { slot, rank, level, required }
--- for every entry the queue asks for before it is legal.
local function stalls_in(tLadder)
    local tOut = {}
    for nSlot, tRanks in pairs(tLadder) do
        for nRank = 1, #tRanks do
            local nReq = required_level(nSlot, nRank)
            if nReq ~= nil and tRanks[nRank] < nReq then
                tOut[#tOut + 1] = { nSlot, nRank, tRanks[nRank], nReq }
            end
        end
    end
    table.sort(tOut, function(a, b) return a[3] < b[3] end)
    return tOut
end

-- The only stall this tree ships, and it is registered as costless.
local REGISTERED = { ULT_SLOT, 3, 17, 18 }

tests['2b. every shipped focus-five row is legal at every queue position'] = function()
local nRowsChecked = 0
for _, tRow in ipairs(tRows) do
    local sLabel, sHero, sTable, nWhich = tRow[1], tRow[2], tRow[3], tRow[4]
    local sSrc = skillmap.read_file(tFile[sHero])
    local tBuild = skillmap.build_row(sSrc, nWhich, sTable)
    local tLadder = skillmap.rank_ladder(sHero, tBuild, skillmap.talent_rows(sSrc))
    nRowsChecked = nRowsChecked + 1

    local tStall = stalls_in(tLadder)
    check(#tStall == 1, sLabel .. ': ' .. #tStall .. ' stall(s), expected exactly '
        .. 'the registered level-17 ultimate')
    if #tStall == 1 then
        local s = tStall[1]
        check(s[1] == REGISTERED[1] and s[2] == REGISTERED[2]
              and s[3] == REGISTERED[3] and s[4] == REGISTERED[4],
            sLabel .. ': stall is slot ' .. s[1] .. ' rank ' .. s[2] .. ' at level '
            .. s[3] .. ' (needs ' .. s[4] .. '), not the registered one')
    end

    -- THE REASON THE REGISTERED STALL IS COSTLESS, checked and not asserted in
    -- prose: at level 17 every basic ability is already maxed, so the parked
    -- point has no legal alternative to be spent on.
    for nSlot, tRanks in pairs(tLadder) do
        if nSlot ~= ULT_SLOT then
            check(#tRanks == 4, sLabel .. ': slot ' .. nSlot .. ' takes '
                .. #tRanks .. ' points, not 4 -- the "nothing else to spend it '
                .. 'on" argument for the level-17 park assumes 3 basics x 4')
        end
    end
    local nWants = unmaxed_slot_at(tLadder, REGISTERED[3])
    check(nWants == nil, sLabel .. ': slot ' .. tostring(nWants) .. ' is still '
        .. 'unmaxed at level ' .. REGISTERED[3] .. ', so the parked point DOES '
        .. 'have somewhere to go and the registered stall is no longer costless')

    -- And the ultimate takes its rank 3 at the first level it exists.
    check(tLadder[ULT_SLOT] ~= nil and #tLadder[ULT_SLOT] == 3,
        sLabel .. ': the row does not spend exactly 3 ultimate points')
end

check(nRowsChecked == 7, 'checked ' .. nRowsChecked .. ' rows, expected 7')
end

--------------------------------------------------------------------------------
-- 3. The criterion and the report, on synthetic input
--------------------------------------------------------------------------------
-- On a legal tree section 2 never drives the positive branch of `stalls_in`
-- except through the one registered entry, so a loosened criterion escapes
-- (charter §24).  Feed both directions.
--
-- Does the tree carry a legal-but-adjacent shape a LOOSENED criterion would
-- swallow?  Yes: the registered level-17 entry is itself one level away from
-- legal, so any criterion that stopped reporting it turns section 2 red.  The
-- silent direction is the one with no live counterexample, so an offender is
-- built here.

tests['3a. the level criterion, both directions'] = function()
check(required_level(1, 4) == 7, 'basic rank 4 is legal at level 7')
check(required_level(ULT_SLOT, 1) == 6, 'ultimate rank 1 is legal at level 6')
check(required_level(ULT_SLOT, 3) == 18, 'ultimate rank 3 is legal at level 18')

-- Offender: the ultimate one level early at rank 1, plus a basic rank 2 taken at
-- level 2.  Near miss: the same ranks exactly ON their legal level.
end

tests['3b. the stall report, on synthetic input'] = function()
local tOffender = { [1] = { 1, 2, 5, 7 }, [ULT_SLOT] = { 5, 12, 18 } }
local tGot = stalls_in(tOffender)
check(#tGot == 2, 'synthetic offender produced ' .. #tGot .. ' stall(s), expected 2')
if #tGot == 2 then
    check(tGot[1][1] == 1 and tGot[1][3] == 2 and tGot[1][4] == 3,
        'first synthetic stall was slot ' .. tGot[1][1] .. ' at level ' .. tGot[1][3])
    check(tGot[2][1] == ULT_SLOT and tGot[2][3] == 5 and tGot[2][4] == 6,
        'second synthetic stall was slot ' .. tGot[2][1] .. ' at level ' .. tGot[2][3])
end

local tNearMiss = { [1] = { 1, 3, 5, 7 }, [ULT_SLOT] = { 6, 12, 18 } }
check(#stalls_in(tNearMiss) == 0,
    'a row that takes every rank on exactly its legal level was reported as stalling')
end

-- The costless criterion, both directions.  Offender: a basic still unmaxed at
-- the parked level, so the point had somewhere to go.  Near miss: that same slot
-- maxed on exactly the parked level.
tests['3c. the costless criterion, both directions'] = function()
check(unmaxed_slot_at({ [2] = { 1, 3, 5, 18 }, [ULT_SLOT] = { 6, 12, 17 } }, 17) == 2,
    'a slot still unmaxed at the parked level was read as costless')
check(unmaxed_slot_at({ [2] = { 1, 3, 5, 17 }, [ULT_SLOT] = { 6, 12, 17 } }, 17) == nil,
    'a slot maxed on exactly the parked level was read as still wanting a point')
end

return tests
