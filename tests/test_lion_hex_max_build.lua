-- [hero] [ratchet] `lionbuild`: the Lion build row decides WHICH ability the
-- skill-point wall strands, and the shipped row picks Hex.
--
-- WHAT THIS FILE IS ABOUT
-- ----------------------
-- GH #366 / #822 / #864 settled the wall: the level-up queue head parks at entry
-- 15 (the t15 talent), thirteen ability points get spent in the multiset
-- {4,4,3,2}, and entries 16 and 17 are bought by nobody.  Entry 17 is always the
-- ultimate's third point.  Entry 16 is the FOURTH rank of whichever basic the
-- first thirteen points left at 3 -- and which basic that is is decided entirely
-- by the hero file's build-row literal.  #864's focus table names Lion's:
-- `lion_voodoo`, engine slot 1.
--
-- ⛔ WHAT IS NOT CLAIMED, and it is the first thing a reader needs.  This
-- candidate does NOT remove the strand and cannot.  #864 LIMIT 2 and
-- tests/test_focus_strand_identity.lua section 5b establish over 14 rows that
-- thirteen points across three basics and an ultimate always leave exactly one
-- basic at rank 3.  Section 3 below re-establishes that for BOTH Lion rows
-- rather than citing it.  The only thing `lionbuild` does is CHOOSE THE VICTIM.
--
-- ⚠️ AND IT DOES NOT FIX THE WALL.  The wall lives in
-- bots/ability_item_usage_generic.lua, which all 127 heroes run, and it has its
-- own gated look-ahead (`skillstall`, GH #799).  Moving one hero's strand is a
-- hero-group change to a hero-group file; it leaves the shared defect exactly
-- where it was.
--
-- WHY THE VICTIM IS WORTH CHOOSING (the reading, section 5 pins its inputs):
--
--     lion_voodoo      duration 2/2.4/2.8/3.2  cooldown 24/20/16/12
--     lion_mana_drain  mana_per_second 20/40/60/120  cooldown 15/12/9/6
--
-- The shipped row spends Mana Drain's fourth point (a bigger refill on a 5.1s
-- channel) and strands Hex's (-4s on the cooldown of Lion's only non-ultimate
-- hard disable, +0.4s of it).  It also holds Hex at RANK ONE from hero level 4
-- to hero level 12 -- section 2 drives that, it is not read off the literal.
--
-- ⚠️ Tagged [ratchet].  Sections 2-4 assert the shipped row's shape and the
-- armed row's difference from it.  Editing either literal turns them red; that
-- is the notification, and the prose in hero_lion.lua above `tHexMaxBuildList`
-- is what has to be re-read when it fires.

package.path = 'tests/?.lua;' .. package.path

local skillmap = require('skill_level_map')

local HERO = 'lion'
local SRC = 'bots/BotLib/hero_lion.lua'
local SHAPES = 'tests/mock/special_value_shapes.lua'
local HERO_SLOTS = 'tests/mock/hero_slots.lua'

local ARMED_TABLE = 'tHexMaxBuildList'
local GATE_ID = 'lionbuild'

-- Same three constants test_focus_strand_identity.lua uses, and for the same
-- reason: entry 15 is where the head parks, so entry 16 is the stranded basic.
local WALL_ENTRY = 15
local STRAND_ENTRY = 16
local SPENT_AT_WALL = 13

local SLOT_SPIKE = 0  -- lion_impale
local SLOT_HEX = 1    -- lion_voodoo
local SLOT_DRAIN = 2  -- lion_mana_drain
local SLOT_FINGER = 5 -- lion_finger_of_death

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

--- The mock names slot N `lion_mock_slot_N`, which is the only thing tying a
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

--- The ladder of one engine slot, found through the driven list rather than
--- through the sAbilityList index (which is a different numbering and the one
--- thing a reader of this file most easily confuses).
local function ladder_of(tLadder, tList, nSlot)
    for i = 1, 12 do
        local tAt = tLadder[i]
        if tAt ~= nil and tAt[1] ~= nil
            and slot_of_entry(tList, tAt[1]) == nSlot then
            return tAt
        end
    end
end

-- ---------------------------------------------------------------------------

tests['1. the gate is wired: turbo + `lionbuild` selects the second row'] = function()
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
    -- (AGENTS.md, the `pullcad` lesson).  Lion carries fourteen other ids in this
    -- file, so "a sibling id got ANDed in here" is the likely edit, not a
    -- hypothetical one.
    local nIds = 0
    for _ in sSel:gmatch('IsSoakCandidate') do nIds = nIds + 1 end
    assert(nIds == 1,
        'the build gate reads ' .. nIds .. ' soak-candidate ids, not 1.  A '
        .. 'conjunction of ids freezes FALSE the day any one of them is promoted.')
end

tests['2. gate OFF is the shipped row, and the shipped row strands the Hex'] = function()
    local tShipped, _, tTalents = rows()

    assert(table.concat(tShipped, ',') == '1,3,1,2,3,6,1,1,3,3,6,2,2,2,6',
        'the SHIPPED Lion row changed to {' .. table.concat(tShipped, ',')
        .. '}.  `' .. GATE_ID .. '` is sold as inert when unarmed, and that claim '
        .. 'is about THIS literal; a default-behaviour change hid here would not '
        .. 'be gated at all.')

    local tLadder, tRanks, tList = drive(tShipped, tTalents)

    local nSpent = 0
    for _, nRank in pairs(tRanks) do nSpent = nSpent + nRank end
    assert(nSpent == SPENT_AT_WALL,
        'the shipped row spends ' .. nSpent .. ' points by the wall, not '
        .. SPENT_AT_WALL .. '.  The wall reading (#366) is the premise of this file.')

    assert(slot_of_entry(tList, STRAND_ENTRY) == SLOT_HEX,
        'the shipped row no longer strands engine slot ' .. SLOT_HEX
        .. ' (lion_voodoo) at entry ' .. STRAND_ENTRY .. '.  That is the defect '
        .. 'this candidate exists to move; re-read GH #864 before editing this '
        .. 'line.')
    assert(slot_name(SLOT_HEX) == 'lion_voodoo',
        'engine slot ' .. SLOT_HEX .. ' is no longer lion_voodoo.')

    -- ⭐ The reading the prose leans on, DRIVEN rather than counted off the
    -- literal: Hex holds rank 1 from hero level 4 to hero level 12.  (Counting
    -- row entries gives a different, wrong answer -- GH #134.)
    local tHexIdx = ladder_of(tLadder, tList, SLOT_HEX)
    local tDrainIdx = ladder_of(tLadder, tList, SLOT_DRAIN)
    assert(tHexIdx ~= nil and tDrainIdx ~= nil,
        'could not find the Hex / Mana Drain ladders in the shipped row.')

    assert(tHexIdx[1] == 4 and tHexIdx[2] == 13 and tHexIdx[3] == 14
            and tHexIdx[4] == 16,
        'shipped Hex ladder is now {' .. table.concat(tHexIdx, ',')
        .. '}, not {4,13,14,16}.  The candidate\'s whole case is that rank 2 does '
        .. 'not arrive until hero level 13 and rank 4 sits at entry 16.')
    assert(tDrainIdx[1] == 2 and tDrainIdx[2] == 5 and tDrainIdx[3] == 9
            and tDrainIdx[4] == 11,
        'shipped Mana Drain ladder is now {' .. table.concat(tDrainIdx, ',')
        .. '}, not {2,5,9,11}.')
end

tests['3. armed is a PERMUTATION that moves the strand to Mana Drain'] = function()
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

    local tLadder, tRanks, tList = drive(tArmed, tTalents)

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

    assert(slot_of_entry(tList, STRAND_ENTRY) == SLOT_DRAIN,
        'the armed row strands engine slot ' .. slot_of_entry(tList, STRAND_ENTRY)
        .. ', not ' .. SLOT_DRAIN .. ' (lion_mana_drain).  Moving the strand from '
        .. 'the Hex to Mana Drain is the entire content of `' .. GATE_ID
        .. '`; if it no longer does that, the candidate does nothing.')
    assert(slot_name(SLOT_DRAIN) == 'lion_mana_drain',
        'engine slot ' .. SLOT_DRAIN .. ' is no longer lion_mana_drain.')

    -- The gain the prose sells, driven: Hex is maxed by hero level 11 under the
    -- armed row, where the shipped row has it at rank 1 until 13.
    local tHexIdx = ladder_of(tLadder, tList, SLOT_HEX)
    assert(tHexIdx ~= nil and tHexIdx[1] == 4 and tHexIdx[2] == 5
            and tHexIdx[3] == 9 and tHexIdx[4] == 11,
        'armed Hex ladder is now {' .. table.concat(tHexIdx or {}, ',')
        .. '}, not {4,5,9,11}.  "Hex maxed by level 11" is the whole payoff side '
        .. 'of this candidate.')
end

tests['4. narrowness: Spike and Finger are untouched, divergence starts at lv5'] = function()
    local tShipped, tArmed, tTalents = rows()

    local _, _, tListS = drive(tShipped, tTalents)
    local _, _, tListA = drive(tArmed, tTalents)

    -- ⭐ The attribution claim, asserted rather than asserted-in-prose: a wave
    -- reading on this candidate must be attributable to the W/E allocation alone.
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

    assert(nFirstDiff == 5,
        'the two rows first differ at hero level ' .. tostring(nFirstDiff)
        .. ', not 5.  "levels 1-4 are byte-identical" is a claim in the '
        .. 'candidate\'s prose about what a wave reading can be blamed on.  '
        .. 'Differences: ' .. table.concat(tDiff, '; '))

    -- Every differing entry is a Hex <-> Drain swap; no Spike or Finger entry
    -- moves.  This is the part that makes the wave reading single-lever.
    for i = 1, math.max(#tListS, #tListA) do
        local x, y = tListS[i], tListA[i]
        if x ~= y then
            for _, s in ipairs({ x, y }) do
                if type(s) == 'string' then
                    local nSlot = tonumber(s:match('_mock_slot_(%d+)$'))
                    assert(nSlot == SLOT_HEX or nSlot == SLOT_DRAIN,
                        'hero level ' .. i .. ' changes engine slot ' .. tostring(nSlot)
                        .. ', which is neither the Hex (' .. SLOT_HEX .. ') nor '
                        .. 'Mana Drain (' .. SLOT_DRAIN .. ').  The candidate '
                        .. 'claims Earth Spike and Finger of Death do not move; '
                        .. 'they do, so the lever is no longer single.')
                end
            end
        end
    end

    -- And the two untouched ladders, stated positively so a future row edit that
    -- happens to keep the diff inside {Hex, Drain} while shifting Earth Spike's
    -- ARRIVAL is still caught.
    local tLadS = drive(tShipped, tTalents)
    local tLadA = drive(tArmed, tTalents)
    for _, nSlot in ipairs({ SLOT_SPIKE, SLOT_FINGER }) do
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

    -- ⚠️ These are QUOTED, not derived.  The candidate's prose argues "half the
    -- cooldown of Lion's only non-ultimate hard disable beats a bigger refill on
    -- a 5.1s channel"; if a patch moves either column the argument has to be
    -- re-read, and this assertion is how the next reader finds out rather than
    -- inheriting stale prose.
    local EXPECT = {
        { 'lion_voodoo', 'duration', '2 2.4 2.8 3.2' },
        { 'lion_voodoo', 'AbilityCooldown', '24 20 16 12' },
        { 'lion_voodoo', 'AbilityCastRange', '575 600 625 650' },
        { 'lion_voodoo', 'AbilityManaCost', '110 140 170 200' },
        { 'lion_mana_drain', 'mana_per_second', '20 40 60 120' },
        { 'lion_mana_drain', 'AbilityCooldown', '15 12 9 6' },
        { 'lion_mana_drain', 'movespeed', '15 20 25 30' },
        { 'lion_mana_drain', 'duration', '5.0' },
        { 'lion_mana_drain', 'AbilityCastRange', '850' },
        { 'lion_mana_drain', 'break_distance', '1100' },
        -- ⭐ Not decoration: the prose says the Drain's ranks buy mana economy
        -- and NOT damage, and this is the column that says so.
        { 'lion_mana_drain', 'damage_pct', '0' },
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

    -- The directions the case actually needs, derived from the quoted strings so
    -- they cannot drift away from them.
    local function nth(s, n)
        local t2 = {}
        for w in s:gmatch('%S+') do t2[#t2 + 1] = tonumber(w) end
        return t2[n]
    end
    local sDur = t['lion_voodoo']['duration'].base
    local sCd = t['lion_voodoo']['AbilityCooldown'].base
    assert(nth(sDur, 4) - nth(sDur, 3) > 0 and nth(sCd, 3) - nth(sCd, 4) > 0,
        'the Hex\'s fourth rank no longer adds duration and removes cooldown; '
        .. 'the candidate\'s case is exactly that it does.')

    -- ⚠️ And the cost side, asserted in the same breath so nobody reads this
    -- file as claiming the swap is free: the rank the armed row gives up on the
    -- Drain is a real one, and the Hex ranks it buys cost MORE mana to cast.
    local sDrain = t['lion_mana_drain']['mana_per_second'].base
    local sHexMana = t['lion_voodoo']['AbilityManaCost'].base
    assert(nth(sDrain, 4) > nth(sDrain, 3) and nth(sHexMana, 4) > nth(sHexMana, 1),
        'the Drain\'s fourth rank no longer refills more, or Hex no longer costs '
        .. 'more at rank 4 than at rank 1.  Both are stated as the PRICE of this '
        .. 'candidate in ' .. SRC .. '; a patch that changed either one changed '
        .. 'the trade.')
end

return tests
