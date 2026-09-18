-- [hero] [ratchet] `axebuild`: the Axe build row decides WHICH ability the
-- skill-point wall strands, and the shipped row picks Berserker's Call.
--
-- WHAT THIS FILE IS ABOUT
-- ----------------------
-- GH #366 / #822 / #864 settled the wall: the level-up queue head parks at entry
-- 15 (the t15 talent), thirteen ability points get spent in the multiset
-- {4,4,3,2}, and entries 16 and 17 are bought by nobody.  Entry 17 is always the
-- ultimate's third point.  Entry 16 is the FOURTH rank of whichever basic the
-- first thirteen points left at 3 -- and which basic that is is decided entirely
-- by the hero file's build-row literal.
--
-- ⛔ WHAT IS NOT CLAIMED, and it is the first thing a reader needs.  This
-- candidate does NOT remove the strand and cannot.  #864 LIMIT 2 and
-- tests/test_focus_strand_identity.lua section 5b establish over 14 rows that
-- thirteen points across three basics and an ultimate always leave exactly one
-- basic at rank 3.  Section 3 below re-establishes that for BOTH Axe rows rather
-- than citing it.  The only thing `axebuild` does is CHOOSE THE VICTIM.
--
-- ⚠️ AND IT DOES NOT FIX THE WALL.  The wall lives in
-- bots/ability_item_usage_generic.lua, which all 127 heroes run, and it has its
-- own gated look-ahead (`skillstall`, GH #799).  Moving one hero's strand is a
-- hero-group change to a hero-group file; it leaves the shared defect exactly
-- where it was.
--
-- WHY THE VICTIM IS WORTH CHOOSING (the reading, section 5 pins its inputs):
--
--     axe_berserkers_call  duration 2.1/2.4/2.7/3.0  cooldown 18/16/14/12
--     axe_battle_hunger    dps      12/16/20/24      cooldown 20/15/10/5
--
-- The shipped row spends Battle Hunger's fourth point (+4 dps on ONE target for
-- 12s) and strands Berserker's Call's (+0.3s on an AoE taunt, -2s cooldown).  It
-- also holds Call at RANK ONE from hero level 3 to hero level 12 -- section 2
-- drives that, it is not read off the literal.
--
-- ⚠️ Tagged [ratchet].  Sections 2-4 assert the shipped row's shape and the
-- armed row's difference from it.  Editing either literal turns them red; that is
-- the notification, and the prose in hero_axe.lua above `tCallMaxBuildList` is
-- what has to be re-read when it fires.

package.path = 'tests/?.lua;' .. package.path

local skillmap = require('skill_level_map')

local HERO = 'axe'
local SRC = 'bots/BotLib/hero_axe.lua'
local SHAPES = 'tests/mock/special_value_shapes.lua'
local HERO_SLOTS = 'tests/mock/hero_slots.lua'

local ARMED_TABLE = 'tCallMaxBuildList'
local GATE_ID = 'axebuild'

-- Same three constants test_focus_strand_identity.lua uses, and for the same
-- reason: entry 15 is where the head parks, so entry 16 is the stranded basic.
local WALL_ENTRY = 15
local STRAND_ENTRY = 16
local SPENT_AT_WALL = 13

local SLOT_CALL = 0   -- axe_berserkers_call
local SLOT_HUNGER = 1 -- axe_battle_hunger
local SLOT_HELIX = 2  -- axe_counter_helix
local SLOT_CULL = 5   -- axe_culling_blade

local tests = {}

local tSrcMemo
local function src()
    if tSrcMemo == nil then tSrcMemo = skillmap.read_file(SRC) end
    return tSrcMemo
end

--- Both rows plus the talent rows, read off the one file.
local function rows()
    local s = src()
    return skillmap.build_row(s, 1), skillmap.build_row(s, 1, ARMED_TABLE),
           skillmap.talent_rows(s)
end

--- Drive the SHIPPED J.Skill.GetSkillList for a row.  Memoised on the row's own
--- digits so a mutated row never reads a pristine row's answer.
local tDriveMemo = {}
local function drive(tRow, tTalents)
    local sKey = table.concat(tRow, ',')
    if tDriveMemo[sKey] == nil then
        local tRanks, tList = skillmap.ranks_at(HERO, tRow, tTalents, WALL_ENTRY - 1)
        tDriveMemo[sKey] = { skillmap.rank_ladder(HERO, tRow, tTalents), tRanks, tList }
    end
    local m = tDriveMemo[sKey]
    return m[1], m[2], m[3]
end

--- The mock names slot N `axe_mock_slot_N`, which is the only thing tying a
--- driven entry back to an engine slot.  Read it, never recompute it.
local function slot_of_entry(tList, nEntry)
    local sEntry = tList[nEntry]
    assert(type(sEntry) == 'string',
        'entry ' .. nEntry .. ' of the driven skill list is ' .. type(sEntry)
        .. ', not an ability name.  Re-derive before touching anything below.')
    local nSlot = tonumber(sEntry:match('_mock_slot_(%d+)$'))
    assert(nSlot ~= nil,
        'entry ' .. nEntry .. ' is "' .. sEntry .. '", which carries no '
        .. '`_mock_slot_N` suffix; the index -> slot step is gone.')
    return nSlot
end

local tSlotMap = dofile(HERO_SLOTS)

local function slot_name(nSlot)
    local t = tSlotMap[HERO]
    assert(t ~= nil, HERO .. ' is not in ' .. HERO_SLOTS)
    return t[nSlot]
end

-- ---------------------------------------------------------------------------

tests['1. the gate is wired: turbo + `axebuild` selects the second row'] = function()
    local s = src()

    assert(s:match('local ' .. ARMED_TABLE .. ' = {'),
        SRC .. ' no longer declares `' .. ARMED_TABLE .. '`.  This whole file is '
        .. 'about that literal.')

    -- The selector, read as one expression rather than as two greps: an
    -- `IsSoakCandidate` call somewhere in the file and a `GetRandomBuild` call
    -- somewhere in the file would both be present even if they were wired to
    -- different things (the `pullcad` trap, AGENTS.md).
    local sSel = s:match('local nAbilityBuildList\n(.-)\nend\n')
    assert(sSel ~= nil,
        SRC .. ': the `local nAbilityBuildList` selector block is gone or no '
        .. 'longer ends with an `end` on its own line.  Gate wiring unreadable.')
    assert(sSel:match('J%.IsModeTurbo%(%)'),
        'the build selector is not turbo-gated: ' .. sSel)
    assert(sSel:match("J%.IsSoakCandidate%(%s*'" .. GATE_ID .. "'%s*%)"),
        "the build selector does not read J.IsSoakCandidate('" .. GATE_ID
        .. "'): " .. sSel)
    assert(sSel:match('GetRandomBuild%(%s*' .. ARMED_TABLE .. '%s*%)'),
        'the armed branch does not select ' .. ARMED_TABLE .. ': ' .. sSel)
    assert(sSel:match('GetRandomBuild%(%s*tAllAbilityBuildList%s*%)'),
        'the unarmed branch does not select tAllAbilityBuildList: ' .. sSel)

    -- ⛔ No OTHER candidate id may appear inside this gate's condition.  A gate
    -- written `IsSoakCandidate('X') and IsSoakCandidate('Y')` is frozen FALSE the
    -- day Y is promoted, and check_armed_wiring.py still calls it WIRED
    -- (AGENTS.md, the `pullcad` lesson).
    local nIds = 0
    for _ in sSel:gmatch('IsSoakCandidate') do nIds = nIds + 1 end
    assert(nIds == 1,
        'the build gate reads ' .. nIds .. ' soak-candidate ids, not 1.  A '
        .. 'conjunction of ids freezes FALSE the day any one of them is promoted.')
end

tests['2. gate OFF is the shipped row, and the shipped row strands the Call'] = function()
    local tShipped, _, tTalents = rows()

    assert(table.concat(tShipped, ',') == '2,3,1,3,3,6,3,2,2,2,6,1,1,1,6',
        'the SHIPPED Axe row changed to {' .. table.concat(tShipped, ',')
        .. '}.  `' .. GATE_ID .. '` is sold as inert when unarmed, and that claim '
        .. 'is about THIS literal; a default-behaviour change hid here would not '
        .. 'be gated at all.')

    local tLadder, tRanks, tList = drive(tShipped, tTalents)

    local nSpent = 0
    for _, nRank in pairs(tRanks) do nSpent = nSpent + nRank end
    assert(nSpent == SPENT_AT_WALL,
        'the shipped row spends ' .. nSpent .. ' points by the wall, not '
        .. SPENT_AT_WALL .. '.  The wall reading (#366) is the premise of this file.')

    assert(slot_of_entry(tList, STRAND_ENTRY) == SLOT_CALL,
        'the shipped row no longer strands engine slot ' .. SLOT_CALL
        .. ' (axe_berserkers_call) at entry ' .. STRAND_ENTRY .. '.  That is the '
        .. 'defect this candidate exists to move; re-read GH #864 before editing '
        .. 'this line.')
    assert(slot_name(SLOT_CALL) == 'axe_berserkers_call',
        'engine slot ' .. SLOT_CALL .. ' is no longer axe_berserkers_call.')

    -- ⭐ The reading the prose leans on, DRIVEN rather than counted off the
    -- literal: Berserker's Call holds rank 1 from hero level 3 to hero level 12.
    -- (Counting row entries gives a different, wrong answer -- GH #134.)
    local tCallIdx, tHungerIdx
    for i = 1, 12 do
        local tAt = tLadder[i]
        if tAt ~= nil and tAt[1] ~= nil then
            local nSlot = slot_of_entry(tList, tAt[1])
            if nSlot == SLOT_CALL then tCallIdx = tAt end
            if nSlot == SLOT_HUNGER then tHungerIdx = tAt end
        end
    end
    assert(tCallIdx ~= nil and tHungerIdx ~= nil,
        'could not find the Call / Battle Hunger ladders in the shipped row.')

    assert(tCallIdx[1] == 3 and tCallIdx[2] == 13 and tCallIdx[3] == 14
            and tCallIdx[4] == 16,
        'shipped Berserker\'s Call ladder is now {' .. table.concat(tCallIdx, ',')
        .. '}, not {3,13,14,16}.  The candidate\'s whole case is that rank 2 does '
        .. 'not arrive until hero level 13 and rank 4 sits at entry 16.')
    assert(tHungerIdx[1] == 1 and tHungerIdx[2] == 8 and tHungerIdx[3] == 9
            and tHungerIdx[4] == 11,
        'shipped Battle Hunger ladder is now {' .. table.concat(tHungerIdx, ',')
        .. '}, not {1,8,9,11}.')
end

tests['3. armed is a PERMUTATION that moves the strand to Battle Hunger'] = function()
    local tShipped, tArmed, tTalents = rows()

    assert(#tShipped == #tArmed,
        'the two rows have different lengths (' .. #tShipped .. ' vs ' .. #tArmed
        .. ').  `' .. GATE_ID .. '` is sold as a pure permutation.')

    local function multiset(tRow)
        local t = {}
        for _, n in ipairs(tRow) do t[n] = (t[n] or 0) + 1 end
        return t
    end
    local a, b = multiset(tShipped), multiset(tArmed)
    for k, v in pairs(a) do
        assert(b[k] == v, 'index ' .. k .. ' appears ' .. v .. ' times in the '
            .. 'shipped row and ' .. tostring(b[k]) .. ' in the armed row.  The '
            .. 'candidate claims a PERMUTATION: same points, different order.')
    end
    for k, v in pairs(b) do
        assert(a[k] == v, 'index ' .. k .. ' appears ' .. v .. ' times in the '
            .. 'armed row and ' .. tostring(a[k]) .. ' in the shipped row.')
    end

    local _, tRanks, tList = drive(tArmed, tTalents)

    local nSpent, nAtThree = 0, 0
    for _, nRank in pairs(tRanks) do
        nSpent = nSpent + nRank
        if nRank == 3 then nAtThree = nAtThree + 1 end
    end
    assert(nSpent == SPENT_AT_WALL,
        'the armed row spends ' .. nSpent .. ' points by the wall, not ' .. SPENT_AT_WALL)
    -- ⛔ The strand is NOT removed -- it is moved.  Re-established here rather
    -- than cited, because "the candidate fixed the wall" is the misreading this
    -- assertion exists to make impossible.
    assert(nAtThree == 1,
        'the armed row leaves ' .. nAtThree .. ' slots at rank 3, not exactly one.'
        .. '  A row that left none would be the first to dodge the strand and is '
        .. 'a report of its own (#864 LIMIT 2) -- verify before celebrating.')

    assert(slot_of_entry(tList, STRAND_ENTRY) == SLOT_HUNGER,
        'the armed row strands engine slot ' .. slot_of_entry(tList, STRAND_ENTRY)
        .. ', not ' .. SLOT_HUNGER .. ' (axe_battle_hunger).  Moving the strand '
        .. 'from the Call to Battle Hunger is the entire content of `' .. GATE_ID
        .. '`; if it no longer does that, the candidate does nothing.')
    assert(slot_name(SLOT_HUNGER) == 'axe_battle_hunger',
        'engine slot ' .. SLOT_HUNGER .. ' is no longer axe_battle_hunger.')
end

tests['4. narrowness: Helix and Culling are untouched, divergence starts at lv8'] = function()
    local tShipped, tArmed, tTalents = rows()

    local _, _, tListS = drive(tShipped, tTalents)
    local _, _, tListA = drive(tArmed, tTalents)

    -- ⭐ The attribution claim, asserted rather than asserted-in-prose: a wave
    -- reading on this candidate must be attributable to the Q/W allocation alone.
    -- Both full driven lists are compared entry by entry.
    local nFirstDiff
    local tDiff = {}
    for i = 1, math.max(#tListS, #tListA) do
        local x, y = tListS[i], tListA[i]
        if x ~= y then
            nFirstDiff = nFirstDiff or i
            tDiff[#tDiff + 1] = 'lv' .. i .. ': ' .. tostring(x) .. ' -> ' .. tostring(y)
        end
    end

    assert(nFirstDiff == 8,
        'the two rows first differ at hero level ' .. tostring(nFirstDiff)
        .. ', not 8.  "levels 1-7 are byte-identical" is a claim in the '
        .. 'candidate\'s prose about what a wave reading can be blamed on.  '
        .. 'Differences: ' .. table.concat(tDiff, '; '))

    -- Every differing entry is a Call <-> Hunger swap; no Helix or Culling entry
    -- moves.  This is the part that makes the wave reading single-lever.
    for i = 1, math.max(#tListS, #tListA) do
        local x, y = tListS[i], tListA[i]
        if x ~= y then
            for _, s in ipairs({ x, y }) do
                if type(s) == 'string' then
                    local nSlot = tonumber(s:match('_mock_slot_(%d+)$'))
                    assert(nSlot == SLOT_CALL or nSlot == SLOT_HUNGER,
                        'hero level ' .. i .. ' changes engine slot ' .. tostring(nSlot)
                        .. ', which is neither the Call (' .. SLOT_CALL .. ') nor '
                        .. 'Battle Hunger (' .. SLOT_HUNGER .. ').  The candidate '
                        .. 'claims Counter Helix and Culling Blade do not move; '
                        .. 'they do, so the lever is no longer single.')
                end
            end
        end
    end

    -- And the two untouched ladders, stated positively so a future row edit that
    -- happens to keep the diff inside {Call, Hunger} while shifting Helix's
    -- ARRIVAL is still caught.
    local tLadS = drive(tShipped, tTalents)
    local tLadA = drive(tArmed, tTalents)
    local function ladder_of(tLadder, tList, nSlot)
        for i = 1, 12 do
            local tAt = tLadder[i]
            if tAt ~= nil and tAt[1] ~= nil
                and slot_of_entry(tList, tAt[1]) == nSlot then
                return tAt
            end
        end
    end
    for _, nSlot in ipairs({ SLOT_HELIX, SLOT_CULL }) do
        local s = ladder_of(tLadS, tListS, nSlot)
        local a = ladder_of(tLadA, tListA, nSlot)
        assert(s ~= nil and a ~= nil, 'slot ' .. nSlot .. ' has no ladder in one row')
        assert(table.concat(s, ',') == table.concat(a, ','),
            'engine slot ' .. nSlot .. ' (' .. tostring(slot_name(nSlot)) .. ') '
            .. 'levels at {' .. table.concat(s, ',') .. '} shipped and {'
            .. table.concat(a, ',') .. '} armed.  The candidate claims both are '
            .. 'untouched.')
    end
end

tests['5. the KV numbers the case rests on are the numbers in the tree'] = function()
    local shapes = dofile(SHAPES)
    local t = shapes.SHAPES[HERO]
    assert(t ~= nil, HERO .. ' is not in ' .. SHAPES)

    -- ⚠️ These are QUOTED, not derived.  The candidate's prose argues "+0.3s of
    -- AoE taunt and -2s cooldown beats +4 dps on one target"; if a patch moves
    -- either column the argument has to be re-read, and this assertion is how the
    -- next reader finds out rather than inheriting stale prose (the `-207`
    -- headline: a published reading that nothing re-takes when its inputs move).
    local EXPECT = {
        { 'axe_berserkers_call', 'duration', '2.1 2.4 2.7 3.0' },
        { 'axe_berserkers_call', 'AbilityCooldown', '18 16 14 12' },
        { 'axe_berserkers_call', 'bonus_armor', '12 13 14 15' },
        { 'axe_berserkers_call', 'radius', '315' },
        { 'axe_battle_hunger', 'damage_per_second', '12 16 20 24' },
        { 'axe_battle_hunger', 'slow', '18 22 26 30' },
        { 'axe_battle_hunger', 'AbilityCooldown', '20 15 10 5' },
        { 'axe_battle_hunger', 'duration', '12.0' },
    }
    for _, e in ipairs(EXPECT) do
        local sAbil, sKey, sWant = e[1], e[2], e[3]
        local tAbil = t[sAbil]
        assert(tAbil ~= nil, sAbil .. ' is not in ' .. SHAPES .. ' for ' .. HERO)
        local tKey = tAbil[sKey]
        assert(tKey ~= nil, sAbil .. ' has no key ' .. sKey)
        assert(tKey.base == sWant,
            sAbil .. '.' .. sKey .. ' is now "' .. tostring(tKey.base) .. '", not "'
            .. sWant .. '".  The `' .. GATE_ID .. '` prose in ' .. SRC .. ' prices '
            .. 'the swap off these columns; re-read it before updating this line.')
    end

    -- The direction the case actually needs, derived from the quoted strings so
    -- it cannot drift away from them.
    local function nth(s, n)
        local t2 = {}
        for w in s:gmatch('%S+') do t2[#t2 + 1] = tonumber(w) end
        return t2[n]
    end
    local sDur = t['axe_berserkers_call']['duration'].base
    local sCd = t['axe_berserkers_call']['AbilityCooldown'].base
    assert(nth(sDur, 4) - nth(sDur, 3) > 0 and nth(sCd, 3) - nth(sCd, 4) > 0,
        'the Call\'s fourth rank no longer adds duration and removes cooldown; '
        .. 'the candidate\'s case is exactly that it does.')
end

return tests
