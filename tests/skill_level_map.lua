-- Shared reader for "what rank does ability X hold at hero level N", used by the
-- talent-ladder payoff tests (tests/test_axe_t15_payoff.lua,
-- tests/test_lion_t15_payoff.lua).
--
-- WHY THIS FILE EXISTS.  A talent tier is a question about ONE hero level: a t15
-- talent is chosen at level 15 and at no other moment, so every "how big is this
-- talent" reading is conditional on the ranks the build row holds AT THAT LEVEL.
-- The obvious way to get those ranks -- count the first N entries of
-- tAllAbilityBuildList -- is WRONG, and test_axe_t15_payoff.lua shipped it wrong
-- on 2026-08-23: the row index is NOT the hero level.  bots/FunLib/aba_skill.lua's
-- X.GetSkillList interleaves a TALENT at levels 10 / 15 / 20 (`i >= 10 and
-- (i % 5 == 0 or ability_idx > #nAbilityBuildList)`), and every ability entry
-- after level 9 is pushed one level later per talent already taken.  So a 15-entry
-- row has spent only THIRTEEN ability points by level 15, and the row's 14th and
-- 15th entries land at levels 16 and 17.
--
-- Rather than restate that rule (the M8 lesson: a mapping read out of code has to
-- be pinned to the code, not paraphrased next to it), this file DRIVES the real
-- J.Skill.GetSkillList under the mock Bot API and reads the answer off the list
-- the bot would actually level up from.  If the interleave changes, this changes
-- with it and the tests that depend on it move.
--
-- The mock names abilities synthetically (npc_dota_hero_x_mock_slot_N), which is
-- fine here: the question is which sAbilityList SLOT is levelled when, and the
-- slot index is exactly what the synthetic names preserve.  It is NOT fine for
-- questions about what a slot is NAMED -- for that the fixture corpus is the only
-- offline evidence (see the slot-name assertions in the payoff tests).

local M = {}

function M.read_file(sPath)
    local f = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = f:read('*a')
    f:close()
    return s
end

--- The hero file's own ability build row, as a list of sAbilityList indices.
--- `nWhich` selects among multiple rows (heroes with per-role builds); default 1.
--- `sTable` selects which build-row literal to read; default tAllAbilityBuildList.
--- (hero_skeleton_king.lua keeps its gated 'wkbuild' row in tKillBuildList, and
--- the prose that prices that row makes level claims too -- GH #134.)
function M.build_row(sSrc, nWhich, sTable)
    sTable = sTable or 'tAllAbilityBuildList'
    local body = sSrc:match('local ' .. sTable .. ' = {(.-)\n}')
    assert(body, 'source has no ' .. sTable .. ' literal')
    local rows = {}
    for sRow in body:gmatch('{(.-)}') do
        local row = {}
        for n in sRow:gmatch('%d+') do row[#row + 1] = tonumber(n) end
        if #row > 0 then rows[#rows + 1] = row end
    end
    assert(#rows > 0, sTable .. ' has no rows')
    return rows[nWhich or 1], rows
end

--- The hero file's own talent tree rows, keyed 't10'/'t15'/'t20'/'t25'.
function M.talent_rows(sSrc)
    local body = sSrc:match('local tTalentTreeList = {(.-)\n}')
    assert(body, 'source has no tTalentTreeList literal')
    local rows = {}
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        rows[tier] = { tonumber(a), tonumber(b) }
    end
    assert(rows.t15, 'tTalentTreeList has no t15 row')
    return rows
end

--- Which sAbilityList slot each abilityQ/W/E/R handle is bound to.
function M.ability_slots(sSrc)
    local slot = {}
    for name, idx in sSrc:gmatch('local (ability[QWER])%s*=%s*bot:GetAbilityByName%(%s*sAbilityList%[(%d)%]') do
        slot[name] = tonumber(idx)
    end
    return slot
end

--- Ranks held at hero level `nLevel`, keyed by sAbilityList slot index, obtained
--- by running the shipped J.Skill.GetSkillList for `sHero`.  Also returns the
--- level-ordered skill list and the number of ability points spent by nLevel.
---
--- Installs its own mock world first: every caller gets the same answer whatever
--- ran before it in the same process (the 2026-08-23 ordering-bug lesson -- a test
--- that depends on another file's leftover globals only passes when the suite is
--- run in one process).
local function drive(sHero, tRow, tTalentRows)
    local api = require('mock.bot_api')
    api.reset_modules()
    api.install({ bot = api.MakeHero(sHero) })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    local bot = GetBot()

    local sAbilityList = J.Skill.GetAbilityList(bot)
    local sTalentList = J.Skill.GetTalentList(bot)
    local nTalentBuild = J.Skill.GetTalentBuild(tTalentRows)
    local sSkillList = J.Skill.GetSkillList(sAbilityList, tRow, sTalentList, nTalentBuild)

    local slot_of = {}
    for i, sName in pairs(sAbilityList) do
        assert(slot_of[sName] == nil,
            'the mock handed two sAbilityList slots the same name (' .. tostring(sName)
            .. '); slot identity is what this reader is built on')
        slot_of[sName] = i
    end
    return sSkillList, slot_of
end

function M.ranks_at(sHero, tRow, tTalentRows, nLevel)
    local sSkillList, slot_of = drive(sHero, tRow, tTalentRows)

    local tRanks, nSpent = {}, 0
    for i = 1, nLevel do
        local nSlot = slot_of[sSkillList[i]]
        if nSlot ~= nil then
            tRanks[nSlot] = (tRanks[nSlot] or 0) + 1
            nSpent = nSpent + 1
        end
    end
    return tRanks, sSkillList, nSpent
end

--- The hero level at which each sAbilityList slot reaches each rank, as
--- tLadder[nSlot][nRank] = nLevel, read off the same driven list as ranks_at.
--- This is the reader for prose of the form "X is maxed by level N": counting
--- build-row entries answers a DIFFERENT question (the row's Nth entry), and the
--- two differ by one per talent already taken (GH #134).
function M.rank_ladder(sHero, tRow, tTalentRows)
    local sSkillList, slot_of = drive(sHero, tRow, tTalentRows)

    local tLadder, tSeen = {}, {}
    for nLevel = 1, #sSkillList do
        local nSlot = slot_of[sSkillList[nLevel]]
        if nSlot ~= nil then
            tSeen[nSlot] = (tSeen[nSlot] or 0) + 1
            tLadder[nSlot] = tLadder[nSlot] or {}
            tLadder[nSlot][tSeen[nSlot]] = nLevel
        end
    end
    return tLadder
end

return M
