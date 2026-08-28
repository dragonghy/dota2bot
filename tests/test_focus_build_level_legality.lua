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
--   * Beyond level 17 the queue holds only talents, and the rows put the t20 pick
--     at queue position 18 and the t25 pick at 19 -- so a point ARRIVES before
--     each is legal and parks, at level 19 and again at 21-24.  Which rank each
--     ability holds there is still out of this test's scope (section 2 grades
--     ability ranks and every one of them is spent by 18).  What the parks COST
--     is section 4's, and it is priced there rather than waved away.
--
--     RE-READ 2026-08-28 (GH #235).  The wording this bullet used to carry waved
--     them away on two grounds and both are retired.  It said the band was "out
--     of turbo's domain (GH #84 read level >= 20 on 0 of 210 hero-slots)": that
--     zero was the batch harness's 10-minute economy cap, not turbo.  The first
--     frame taken past the raised cap reads ten heroes at level 22-27 -- with
--     crystal_maiden 22 and zuus 23 sitting INSIDE the 21-24 park, and
--     skeleton_king 26 past it.  And it said the parks "cost nothing for the same
--     reason the level-17 park does: by then there is nothing else in the queue".
--     Driven, that is false: the queue runs to position 23, because
--     J.Skill.GetTalentBuild returns all EIGHT talent rows and GetSkillList
--     appends the four ABANDONED halves behind the four picks.  There is
--     something else in the queue; the bot asks for all of it.
--
--     The verdict outlives its reason.  Section 4 replaces the level argument
--     with one that never looks at a level: every entry behind the last pick is
--     the other half of a tier whose pick sits earlier in the SAME queue, and a
--     hero takes one talent per tier, so no hero level makes any of them
--     spendable.  The level-19 park needs one level fact and gets exactly one
--     (the single entry behind it is the t25 pick, and 25 > 19).

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

-- The key tests/mock/talent_slots.lua files each hero under (unit short name).
local sShort = {
    ['npc_dota_hero_axe']            = 'axe',
    ['npc_dota_hero_zuus']           = 'zuus',
    ['npc_dota_hero_skeleton_king']  = 'skeleton_king',
    ['npc_dota_hero_lion']           = 'lion',
    ['npc_dota_hero_crystal_maiden'] = 'crystal_maiden',
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

--------------------------------------------------------------------------------
-- 4. The t20 / t25 parks, priced (2026-08-28 re-read of the scope bullet)
--------------------------------------------------------------------------------
-- The header's fourth "not claimed" bullet used to excuse queue positions 18 and
-- 19 twice over, and this section is what replaced both excuses.  It is here and
-- not in prose for the reason section 3 exists: an argument nothing drives is an
-- argument nothing can contradict.
--
-- HONEST BOUNDS
--   * The build rows come from the source literal (skillmap.build_row), the same
--     reader section 2 uses, not from a captured call -- two of the seven rows
--     (zuus pos_4/5, the gated wkbuild) are alternates the file never passes at
--     load, so there is no call to capture for them.  4a pins the ROUTING once,
--     on axe, so "the queue built here" and "the queue the bot spends" are the
--     same object for at least one row.
--   * The talent NAMES come from tests/mock/talent_slots.lua, because the mock
--     bot's ability slots above 5 are empty (same limitation
--     tests/test_lion_hex_talent_slot.lua records).  Slot->tier is arithmetic on
--     the snapshot's own documented order (1-2 = t10 ... 7-8 = t25), not a guess.
--   * "Permanently illegal" is the game's one-talent-per-tier rule, which is not
--     readable offline any more than GetHeroLevelRequiredToUpgrade is -- it is a
--     constant here, exactly like tBasicReq / tUltReq above.  What is DRIVEN is
--     that positions 20-23 really are the other halves of the picked tiers.
--   * Whether the engine accepts the four doomed orders the spender issues at
--     level 25 is not decided here and cannot be: print() never reaches the
--     server console (AGENTS.md).

local api = require('mock.bot_api')
local SNAPSHOT = 'tests/mock/talent_slots.lua'

-- The snapshot's documented slot order: 1-2 = t10, 3-4 = t15, 5-6 = t20, 7-8 = t25.
local function tier_of_slot(nSlot) return math.floor((nSlot - 1) / 2) + 1 end
local tTierLevel = { 10, 15, 20, 25 }

--- Build the real upgrade queue for one row, by driving the shipped functions.
--- Returns the queue, the talent build (8 rows) and name->tier.
local function queue_for(sHero, sShort, sFile, nWhich, sTable)
    local sSrc = skillmap.read_file(sFile)
    local tBuild = skillmap.build_row(sSrc, nWhich, sTable)
    local tTalentRows = skillmap.talent_rows(sSrc)

    api.reset_modules()
    api.install({ bot = api.MakeHero(sHero) })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    local bot = GetBot()

    local tSlots = assert(dofile(SNAPSHOT).SLOTS[sShort],
        'no talent snapshot for ' .. sShort)
    local sTalentList, tTierOf = {}, {}
    for i = 1, 8 do
        sTalentList[i] = assert(tSlots[i], 'snapshot slot ' .. i .. ' missing').name
        tTierOf[sTalentList[i]] = tier_of_slot(i)
    end

    local nTalentBuild = J.Skill.GetTalentBuild(tTalentRows)
    local tQueue = J.Skill.GetSkillList(J.Skill.GetAbilityList(bot), tBuild,
                                        sTalentList, nTalentBuild)
    return tQueue, nTalentBuild, tTierOf, sTalentList, #tBuild
end

--- THE REPLACEMENT CRITERION, extracted so 4c can drive it on synthetic input.
--- From position `nFrom` to the end of the queue, is there an entry a hero at
--- `nLevel` could legally spend a point on?  A talent is spendable only if its
--- tier is not already picked EARLIER in the same queue (one talent per tier) and
--- its tier level has been reached; anything that is not a known talent is
--- treated as live, which is the conservative direction for a "nothing to spend
--- it on" claim.  Returns nil when the tail is dead, else the first live position.
local function live_entry_behind(tQueue, nFrom, tTierOf, nLevel)
    local nLast = 0
    for k in pairs(tQueue) do if k > nLast then nLast = k end end

    local tPicked = {}
    for i = 1, nFrom - 1 do
        local nTier = tTierOf[tQueue[i]]
        if nTier ~= nil then tPicked[nTier] = true end
    end

    for i = nFrom, nLast do
        local sName = tQueue[i]
        if sName ~= nil then
            local nTier = tTierOf[sName]
            if nTier == nil then return i end
            if not tPicked[nTier] and nLevel >= tTierLevel[nTier] then return i end
        end
    end
    return nil
end

local TAIL = 20        -- first abandoned half
local PICK_POS = { 10, 15, 18, 19 }

tests['4a. the queue does not end at the t25 pick: it runs to 23, abandoned halves behind'] = function()
-- The routing, once: the shipped file really hands its build to GetSkillList, so
-- the queue this section constructs is the queue the level-up routine spends.
api.reset_modules()
api.install({ bot = api.MakeHero('npc_dota_hero_axe') })
local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
local fnReal, tSeen = J.Skill.GetSkillList, nil
J.Skill.GetSkillList = function(sAbil, nAbil, sTal, nTal)
    tSeen = { nAbil = nAbil, nTal = nTal }
    return fnReal(sAbil, nAbil, sTal, nTal)
end
local bOk, sErr = pcall(dofile, tFile['npc_dota_hero_axe'])
J.Skill.GetSkillList = fnReal
check(bOk, 'loading hero_axe.lua failed: ' .. tostring(sErr))
check(type(tSeen) == 'table' and type(tSeen.nTal) == 'table',
    'hero_axe.lua no longer routes its build through J.Skill.GetSkillList, so the '
    .. 'queue built below is no longer the queue the bot spends')
check(#tSeen.nTal == 8,
    'the talent build carries ' .. #tSeen.nTal .. ' rows, not 8 -- this whole '
    .. 'section is about the four it carries BEHIND the picks')

for _, tRow in ipairs(tRows) do
    local sLabel, sHero, sTable, nWhich = tRow[1], tRow[2], tRow[3], tRow[4]
    local tQueue, nTalentBuild, _, sTalentList, nRowLen =
        queue_for(sHero, sShort[sHero], tFile[sHero], nWhich, sTable)

    check(nRowLen == 15, sLabel .. ': the ability build has ' .. nRowLen
        .. ' entries, not 15. The queue positions below are ARITHMETIC on that '
        .. 'length (a talent goes in once the abilities run out), so re-derive '
        .. 'them instead of loosening this.')

    for nPick, nPos in ipairs(PICK_POS) do
        check(tQueue[nPos] == sTalentList[nTalentBuild[nPick]],
            sLabel .. ': queue position ' .. nPos .. ' holds ' .. tostring(tQueue[nPos])
            .. ', not the t' .. tTierLevel[nPick] .. ' pick. The picks land at '
            .. '10/15/18/19, NOT 10/15/20/25 -- which is why a point parks at 19 '
            .. 'and again at 21-24.')
    end
    -- Non-vacuity first: `tQueue[p] == sTalentList[nTalentBuild[k]]` is satisfied
    -- by nil == nil, which is exactly what a talent build that stopped returning
    -- its abandoned halves would produce (mutation M1, 2026-08-28).
    check(#nTalentBuild == 8, sLabel .. ': the talent build returned '
        .. #nTalentBuild .. ' rows, not 8 -- indices 5-8 ARE the abandoned halves')
    for i = 0, 3 do
        check(type(tQueue[TAIL + i]) == 'string', sLabel .. ': queue position '
            .. (TAIL + i) .. ' is empty; the tail this section prices is not there')
        check(tQueue[TAIL + i] == sTalentList[nTalentBuild[5 + i]],
            sLabel .. ': queue position ' .. (TAIL + i) .. ' holds '
            .. tostring(tQueue[TAIL + i]) .. ', not the abandoned half of tier '
            .. (i + 1) .. '. The retired scope bullet said there was "nothing else '
            .. 'in the queue" past the picks; these four are what there is.')
    end
    check(tQueue[24] == nil, sLabel .. ': the queue runs past position 23, so '
        .. 'something now sits behind the abandoned t25 half and the dead-tail '
        .. 'argument in 4b has an entry it has never reasoned about')
end
end

tests['4b. every entry behind the last pick is a picked tier\'s other half, at any level'] = function()
for _, tRow in ipairs(tRows) do
    local sLabel, sHero, sTable, nWhich = tRow[1], tRow[2], tRow[3], tRow[4]
    local tQueue, _, tTierOf = queue_for(sHero, sShort[sHero], tFile[sHero], nWhich, sTable)

    -- The pick and the abandoned half of a tier are two different handles.
    for i = 0, 3 do
        check(tQueue[TAIL + i] ~= tQueue[PICK_POS[i + 1]],
            sLabel .. ': tier ' .. (i + 1) .. "'s abandoned half and its pick are the "
            .. 'same name, so "the other half" is not what position ' .. (TAIL + i)
            .. ' holds and the illegality argument below is empty')
        check(tTierOf[tQueue[TAIL + i]] == i + 1,
            sLabel .. ': position ' .. (TAIL + i) .. ' is a tier '
            .. tostring(tTierOf[tQueue[TAIL + i]]) .. ' talent, not tier ' .. (i + 1))
    end

    -- The level-free half: dead even at 25, the highest level the ladder has.
    check(live_entry_behind(tQueue, TAIL, tTierOf, 25) == nil,
        sLabel .. ': something behind the t25 pick is spendable at level 25, so the '
        .. 'park at 21-24 is holding a point that HAD somewhere to go')

    -- The one level fact the level-19 park needs, and no more: the single entry
    -- behind the t20 pick is the t25 pick, and 25 > 19.
    check(live_entry_behind(tQueue, PICK_POS[4], tTierOf, 19) == nil,
        sLabel .. ': the point parked at level 19 had a legal alternative behind '
        .. 'the head')
    check(live_entry_behind(tQueue, PICK_POS[4], tTierOf, 25) == PICK_POS[4],
        sLabel .. ': the t25 pick is not read as spendable at level 25 -- the '
        .. 'criterion has stopped seeing the one live entry this queue has')
end
end

tests['4c. the dead-tail criterion, both directions'] = function()
-- A queue shaped like the shipped one: picks at 10/15/18/19, halves at 20-23.
local tTierOf = {}
local function mk()
    local q = {}
    for i = 1, 9 do q[i] = 'ability_' .. i end
    for i = 11, 14 do q[i] = 'ability_' .. i end
    for i = 16, 17 do q[i] = 'ability_' .. i end
    for k, nPos in ipairs(PICK_POS) do
        q[nPos] = 'pick_t' .. k
        tTierOf['pick_t' .. k] = k
        q[TAIL + k - 1] = 'drop_t' .. k
        tTierOf['drop_t' .. k] = k
    end
    return q
end

local tClean = mk()
check(live_entry_behind(tClean, TAIL, tTierOf, 25) == nil,
    'the clean tail was reported live')

-- Offender 1: an ability entry in the tail (what a 16-entry build row would put
-- there).  It is not a talent, so no tier argument covers it.
local tOffA = mk(); tOffA[22] = 'ability_late'
check(live_entry_behind(tOffA, TAIL, tTierOf, 25) == 22,
    'an ability entry sitting behind the t25 pick was swallowed as dead tail')

-- Offender 2: a tier whose pick is NOT ahead of it -- the shape a build row that
-- skipped a tier would produce.  Reachable at 25, so it is a real alternative.
local tOffB = mk(); tOffB[19] = nil
check(live_entry_behind(tOffB, TAIL, tTierOf, 25) == 23,
    'the abandoned half of an UNPICKED tier was read as permanently illegal')

-- Near miss: that same unpicked tier, at a level its tier has not reached.
check(live_entry_behind(tOffB, TAIL, tTierOf, 24) == nil,
    'an unpicked t25 half was called spendable at level 24')
end

tests['4d. the park band is a level band shipped turbo actually reaches'] = function()
-- The reason this section had to be written at all: the retired bullet ruled the
-- band out of turbo's domain on GH #84's zero, which was the 10-minute cap.
local tFrame = dofile('tests/mock/lategame_talent_frame.lua')
local tSeen, nInBand = {}, 0
for _, tSlot in ipairs(tFrame.slots) do
    tSeen[tSlot.hero] = tSlot.level
    if tSlot.level >= 19 then nInBand = nInBand + 1 end
end
check(nInBand == 10, 'only ' .. nInBand .. ' of the frame\'s hero-slots are at '
    .. 'level 19+; the park band this section prices was read as reachable off '
    .. 'this snapshot and that reading has changed')
check(tSeen['crystal_maiden'] == 22 and tSeen['zuus'] == 23,
    'the two focus heroes that sit INSIDE the 21-24 park in the recorded frame '
    .. 'are no longer at 22 / 23 -- re-read the band before trusting section 4')
check(tSeen['skeleton_king'] == 26,
    'skeleton_king is no longer past the band in the recorded frame')
end

return tests
