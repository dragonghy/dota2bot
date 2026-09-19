-- [hero] [ratchet] `ZUUSSTRAND`: the Zeus build rows strand `zuus_heavenly_jump`
-- -- and unlike Axe's and Lion's rows, THAT IS THE RIGHT CHOICE.  This file is
-- the measurement that says so, and it is a NEGATIVE reading: no gate id, no
-- candidate, no row edit lands with it.
--
-- WHY A FILE FOR A NON-CHANGE
-- --------------------------
-- The hero desk has now put the same ruler on three focus heroes in three
-- rounds.  Twice it found a lever and landed one:
--
--     axebuild   (GH #911)  shipped strands axe_berserkers_call  -> gated row
--                           strands axe_battle_hunger instead
--     lionbuild  (GH #916)  shipped strands lion_voodoo (Hex)    -> gated row
--                           strands lion_mana_drain instead
--
-- Two for two invites the third round to land `zuusbuild` by pattern.  It must
-- not, and the reason has to be ASSERTED rather than remembered: sections 2-4
-- are the arithmetic that prices Zeus's strand, and they are driven off the
-- game's own KV so that a patch which moves the columns turns this file red
-- instead of leaving a stale paragraph behind.
--
-- ⭐ THE RULER, stated so the next hero (Crystal Maiden, Wraith King) can be
-- measured with the same one.  What decides whether a row is worth re-cutting is
-- NOT whether the stranded ability is a hard disable -- that was the hero desk's
-- working heuristic after Lion, and Zeus is its counterexample.  It is WHAT THE
-- STRANDED RANK BUYS, against what the alternatives' fourth ranks buy:
--
--     zuus_heavenly_jump  r3 -> r4   damage  75 -> 100  (+25, on 1-2 targets)
--                                    cooldown 18 -> 14
--     zuus_arc_lightning  r3 -> r4   arc_damage 155 -> 180  (+25 PER HIT)
--                                    jump_count   9 -> 11   (+2 hits)
--     zuus_lightning_bolt r3 -> r4   damage 300 -> 380      (+80 per cast)
--
-- The stranded rank is the cheapest of the three by the widest margin in the
-- focus five so far, and section 3 says why it is cheaper still than the numbers
-- alone suggest: Heavenly Jump's CONTROL payload -- an 80% move slow and a 100
-- attack-speed slow for 1.4s -- carries NO rank ladder at all.  Ranks buy Zeus
-- damage and cooldown on that ability; they do not buy him any more control.
-- That is the exact opposite of Lion's Hex, whose ranks buy disable uptime
-- (24s -> 12s cooldown, 2.0s -> 3.2s duration) and nothing else, which is why
-- `lionbuild` is a lever and this is not.
--
-- ⛔ WHAT THIS FILE DOES NOT SAY
-- -----------------------------
-- (1) It does not say the wall is fine.  The wall lives in
--     bots/ability_item_usage_generic.lua (all 127 heroes) with its own gated
--     look-ahead `skillstall` (GH #799).  Zeus reaching hero level 18 with
--     thirteen points spent is the same defect it is on every other hero; this
--     file only says that GIVEN the wall, Zeus's row puts the strand on the
--     right ability.
-- (2) It does not say Zeus's rows are optimal in every respect.  Section 5
--     measures the one other row question this round asked -- the pos_2 row
--     takes its Heavenly Jump value point at hero level 2, its second point
--     overall, while its own sibling row takes it at level 4 -- and finds the
--     difference lives on TWO hero levels and then vanishes.  That is why no
--     candidate was cut for it either: the domain, not the direction, is what
--     rules it out.  ⭐ And the domain is ARITHMETIC -- a swap of row entries i
--     and j moves the ranks held on exactly levels i..j-1 -- which a SURVIVING
--     mutant (mutstand_zuusstrand.sh M7) is what forced this file to say.
-- (3) ⛔ It is not a wave reading.  Nothing here was measured in a game.  It is
--     the KV, the shipped row literals, and the shipped GetSkillList.
--
-- ⚠️ Tagged [ratchet] deliberately.  Sections 1-5 assert that the shipped rows
-- still have this shape and that the KV still carries these columns.  A row edit
-- or a patch turns them red, and red here means: re-read the block above
-- `tAllAbilityBuildList` in bots/BotLib/hero_zuus.lua before doing anything,
-- because the negative reading recorded there may have expired.

package.path = 'tests/?.lua;' .. package.path

local skillmap = require('skill_level_map')

local HERO = 'zuus'
local SRC = 'bots/BotLib/hero_zuus.lua'
local SHAPES = 'tests/mock/special_value_shapes.lua'
local HERO_SLOTS = 'tests/mock/hero_slots.lua'

-- Same three constants test_focus_strand_identity.lua uses: entry 15 is where
-- the level-up queue head parks (GH #366), so entry 16 is the stranded basic.
local WALL_ENTRY = 15
local STRAND_ENTRY = 16
local SPENT_AT_WALL = 13

-- ENGINE slots (tests/mock/hero_slots.lua), not sAbilityList indices.  The two
-- numberings differ and confusing them is the readiest mistake in this family.
local SLOT_ARC = 0
local SLOT_BOLT = 1
local SLOT_JUMP = 2
local SLOT_ULT = 5

local tests = {}

local tSrcMemo
local function src()
    if tSrcMemo == nil then tSrcMemo = skillmap.read_file(SRC) end
    return tSrcMemo
end

--- Zeus ships TWO rows in one table and picks between them by role, so every
--- reading below has to hold for both.  `rows()` hands back the table.
local function rows()
    local s = src()
    local _, tRows = skillmap.build_row(s, 1)
    return tRows, skillmap.talent_rows(s)
end

--- Drive the SHIPPED J.Skill.GetSkillList for a row.  Memoised on the row's own
--- digits so a MUTATED row (section 5, and mutstand group A) never reads a
--- pristine row's cached answer.
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

--- The mock names engine slot N `zuus_mock_slot_N`; that suffix is the only
--- thing tying a driven entry back to a slot.  Read it, never recompute it.
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

--- Ranks held at the wall, counted directly off the driven list so no
--- sAbilityList-index arithmetic is needed: one pass, keyed by ENGINE slot.
local function ranks_by_slot(tList)
    local tOut = {}
    for i = 1, WALL_ENTRY - 1 do
        if type(tList[i]) == 'string' then
            local nSlot = slot_of_entry(tList, i)
            tOut[nSlot] = (tOut[nSlot] or 0) + 1
        end
    end
    return tOut
end

--- The ladder of one engine slot, found through the driven list rather than
--- through the sAbilityList index.
local function ladder_of(tLadder, tList, nSlot)
    for i = 1, 12 do
        local tAt = tLadder[i]
        if tAt ~= nil and tAt[1] ~= nil
            and slot_of_entry(tList, tAt[1]) == nSlot then
            return tAt
        end
    end
end

--- One KV column as numbers.  `base` is a space-separated ladder or a single
--- flat value; a flat value is a one-element list and section 3 leans on that.
local tShapesMemo
local function shapes()
    if tShapesMemo == nil then tShapesMemo = dofile(SHAPES) end
    return tShapesMemo
end

local function kv(sAbility, sKey)
    local t = shapes().SHAPES[HERO]
    assert(t ~= nil, HERO .. ' is not in ' .. SHAPES)
    local tAbil = t[sAbility]
    assert(tAbil ~= nil, sAbility .. ' is not in ' .. SHAPES .. ' for ' .. HERO)
    local tCol = tAbil[sKey]
    assert(tCol ~= nil, sAbility .. ' has no key ' .. sKey .. ' in ' .. SHAPES)
    assert(type(tCol.base) == 'string',
        sAbility .. '.' .. sKey .. ' has no base value (it is '
        .. type(tCol.base) .. ').  Every column this file prices must have one.')
    local tOut = {}
    for w in tCol.base:gmatch('%S+') do tOut[#tOut + 1] = tonumber(w) end
    return tOut, tCol.base
end

-- ---------------------------------------------------------------------------

tests['1. BOTH shipped rows strand zuus_heavenly_jump, at thirteen points'] = function()
    local tRows, tTalents = rows()
    assert(#tRows == 2,
        SRC .. ' now ships ' .. #tRows .. ' build rows, not 2.  Every reading '
        .. 'below is stated for BOTH rows; a third row has not been priced.')

    for nRow, tRow in ipairs(tRows) do
        local _, _, tList = drive(tRow, tTalents)

        -- Thirteen ability points, in the multiset {4,4,3,2} (GH #366 / #864).
        local tBySlot = ranks_by_slot(tList)
        local nSpent, tMultiset = 0, {}
        for _, nRank in pairs(tBySlot) do
            nSpent = nSpent + nRank
            tMultiset[#tMultiset + 1] = nRank
        end
        table.sort(tMultiset, function(a, b) return a > b end)
        assert(nSpent == SPENT_AT_WALL,
            'row ' .. nRow .. ' spends ' .. nSpent .. ' points before the wall, '
            .. 'not ' .. SPENT_AT_WALL .. '.  The wall reading (GH #366) is what '
            .. 'this whole file stands on.')
        assert(table.concat(tMultiset, ',') == '4,4,3,2',
            'row ' .. nRow .. ' holds {' .. table.concat(tMultiset, ',') .. '} at '
            .. 'the wall, not {4,4,3,2}.  A different multiset is a different '
            .. 'question than the one priced here -- see section 4.')

        -- And the `3` is Heavenly Jump, in BOTH rows.
        local nStrand = slot_of_entry(tList, STRAND_ENTRY)
        assert(nStrand == SLOT_JUMP,
            'row ' .. nRow .. ' strands engine slot ' .. nStrand .. ' ('
            .. tostring(slot_name(nStrand)) .. '), not '
            .. tostring(slot_name(SLOT_JUMP)) .. '.  The negative reading in '
            .. SRC .. ' prices the JUMP being stranded; if the row now strands '
            .. 'something else the reading has to be redone, not edited.')
        assert(tBySlot[SLOT_JUMP] == 3 and tBySlot[SLOT_ARC] == 4
            and tBySlot[SLOT_BOLT] == 4 and tBySlot[SLOT_ULT] == 2,
            'row ' .. nRow .. ' holds arc=' .. tostring(tBySlot[SLOT_ARC])
            .. ' bolt=' .. tostring(tBySlot[SLOT_BOLT]) .. ' jump='
            .. tostring(tBySlot[SLOT_JUMP]) .. ' ult=' .. tostring(tBySlot[SLOT_ULT])
            .. ' at the wall; the reading is arc=4 bolt=4 jump=3 ult=2.')
    end
end

tests['2. the stranded rank is the CHEAPEST of the three, off the game KV'] = function()
    -- ⚠️ QUOTED, not derived.  These are the columns the negative reading rests
    -- on; a patch that moves any of them has to re-open it.
    local EXPECT = {
        { 'zuus_heavenly_jump', 'damage', '25 50 75 100' },
        { 'zuus_heavenly_jump', 'AbilityCooldown', '26 22 18 14' },
        { 'zuus_heavenly_jump', 'AbilityManaCost', '50 60 70 80' },
        { 'zuus_heavenly_jump', 'range', '700 800 900 1000' },
        { 'zuus_heavenly_jump', 'hop_distance', '375 450 525 600' },
        { 'zuus_arc_lightning', 'arc_damage', '105 130 155 180' },
        { 'zuus_arc_lightning', 'jump_count', '5 7 9 11' },
        { 'zuus_arc_lightning', 'AbilityCooldown', '1.6' },
        { 'zuus_lightning_bolt', 'damage', '140 220 300 380' },
        { 'zuus_lightning_bolt', 'AbilityCooldown', '6.0 6.0 6.0 6.0' },
    }
    for _, e in ipairs(EXPECT) do
        local _, sBase = kv(e[1], e[2])
        assert(sBase == e[3],
            e[1] .. '.' .. e[2] .. ' is now "' .. sBase .. '", not "' .. e[3]
            .. '".  The negative reading above `tAllAbilityBuildList` in ' .. SRC
            .. ' is priced off these columns; re-read it before updating this line.')
    end

    -- The comparison itself, derived from the quoted columns so it cannot drift
    -- away from them.  ⛔ Damage deltas only -- this is NOT a claim about which
    -- ability wins a fight, it is the narrow claim that the point the row
    -- declines to buy is the smallest of the three points available to decline.
    local tJump = kv('zuus_heavenly_jump', 'damage')
    local tArc = kv('zuus_arc_lightning', 'arc_damage')
    local tBolt = kv('zuus_lightning_bolt', 'damage')
    local nJump = tJump[4] - tJump[3]
    local nArc = tArc[4] - tArc[3]
    local nBolt = tBolt[4] - tBolt[3]
    assert(nJump <= nArc and nJump <= nBolt,
        'the stranded fourth rank now buys ' .. nJump .. ' damage against '
        .. nArc .. ' (arc, PER HIT) and ' .. nBolt .. ' (bolt).  The reading is '
        .. 'that the row strands the CHEAPEST of the three; it no longer does.')

    -- ⭐ And the arc delta is understated by that comparison in the one direction
    -- that matters, which is why it is asserted separately rather than folded in:
    -- the arc's fourth rank ALSO buys two more hits, so its +25 is paid up to
    -- eleven times per cast while the jump's is paid once (twice with the t10
    -- talent, `targets` 1 +1).
    local tHits = kv('zuus_arc_lightning', 'jump_count')
    assert(tHits[4] > tHits[3],
        'zuus_arc_lightning no longer gains jump_count at rank 4.  That gain is '
        .. 'half of why the arc\'s fourth point is the expensive one to decline.')
    local tTargets = kv('zuus_heavenly_jump', 'targets')
    assert(#tTargets == 1 and tTargets[1] == 1,
        'zuus_heavenly_jump.targets is now "'
        .. table.concat(tTargets, ' ') .. '", not a flat 1.  The reading says the '
        .. 'jump\'s +25 lands on one unit (two with the t10 talent); a ladder '
        .. 'here would change that.')
end

tests['3. the jump\'s CONTROL carries no rank ladder -- the crux'] = function()
    -- This is the section that separates Zeus from Lion, and it is a statement
    -- about the SHAPE of the KV entry, not about its size: a flat column is a
    -- one-element base.  Ranks on this ability buy damage, cooldown, reach and
    -- hop length; they buy no additional control whatsoever.
    local FLAT = { 'move_slow', 'aspd_slow', 'duration', 'hop_duration',
                   'vision_duration' }
    for _, sKey in ipairs(FLAT) do
        local tCol, sBase = kv('zuus_heavenly_jump', sKey)
        assert(#tCol == 1,
            'zuus_heavenly_jump.' .. sKey .. ' is now a ladder ("' .. sBase
            .. '").  The whole reason Zeus\'s strand is cheap and Lion\'s was '
            .. 'not is that the jump\'s control payload is rank-INDEPENDENT; a '
            .. 'ladder here re-opens the question.')
    end

    -- Stated positively too, so the assertion above cannot be satisfied by the
    -- keys simply disappearing.
    local tSlow = kv('zuus_heavenly_jump', 'move_slow')
    local tDur = kv('zuus_heavenly_jump', 'duration')
    assert(tSlow[1] == 80 and tDur[1] == 1.4,
        'the jump\'s slow/duration read ' .. tostring(tSlow[1]) .. '% / '
        .. tostring(tDur[1]) .. 's, not 80% / 1.4s.')

    -- ⚠️ The contrast half, quoted from the hero it contrasts with.  Lion's Hex
    -- is the ability `lionbuild` (GH #916) moves the strand ONTO, and it is a
    -- ladder on exactly the axis Zeus's jump is flat on.  Asserted here rather
    -- than written in prose because "Lion's case does not transfer" is the one
    -- sentence a future round is most likely to skip.
    local tLion = shapes().SHAPES['lion']
    assert(tLion ~= nil and tLion['lion_voodoo'] ~= nil,
        'lion_voodoo has left ' .. SHAPES .. '; the contrast this section draws '
        .. 'cannot be checked.')
    local function ladder(t) local o = {} for w in t:gmatch('%S+') do o[#o+1] = tonumber(w) end return o end
    local tHexDur = ladder(tLion['lion_voodoo']['duration'].base)
    local tHexCd = ladder(tLion['lion_voodoo']['AbilityCooldown'].base)
    assert(#tHexDur == 4 and #tHexCd == 4 and tHexDur[4] > tHexDur[1]
        and tHexCd[4] < tHexCd[1],
        'lion_voodoo\'s duration/cooldown are no longer a ladder that buys '
        .. 'disable uptime.  That contrast is the reason the Lion lever does not '
        .. 'transfer to Zeus; if it is gone, re-derive rather than re-quote.')
end

tests['4. the {4,4,2,3} alternative is foreclosed by the ult\'s own mana ladder'] = function()
    -- The other row question a reader will ask: why not spend the thirteenth
    -- point on Thundergod's Wrath's THIRD rank and let a basic sit at 2?  The
    -- reading declines it, and the reason is a column, not a preference.
    local tUltDmg, sUltDmg = kv('zuus_thundergods_wrath', 'damage')
    local tUltMana, sUltMana = kv('zuus_thundergods_wrath', 'AbilityManaCost')
    assert(sUltDmg == '275 425 575',
        'zuus_thundergods_wrath.damage is now "' .. sUltDmg .. '".')
    assert(sUltMana == '250 375 500',
        'zuus_thundergods_wrath.AbilityManaCost is now "' .. sUltMana .. '".')
    assert(tUltDmg[3] > tUltDmg[2] and tUltMana[3] > tUltMana[2],
        'the ult\'s third rank no longer costs more mana than its second; the '
        .. 'foreclosure below rests on exactly that.')

    -- ⚠️ THE FORECLOSURE IS THIS FILE'S OWN AFFORDABILITY READING, QUOTED, NOT
    -- RE-MEASURED.  hero_zuus.lua's t15 block records that on the fixture corpus
    -- Thundergod's Wrath is learned and off cooldown on 16 frames and Zeus
    -- cannot pay for it on 7 of them -- at RANK ONE, i.e. against a 250 bill.
    -- A row that bought rank 3 would raise that bill to 500 on a hero whose
    -- binding constraint this file already calls mana.  ⛔ That is an argument
    -- against the swap, not a measurement of it: nothing here measured a rank-3
    -- ult, and no such frame exists in the corpus.
    local s = src()
    assert(s:match('cannot pay for it'),
        SRC .. ' no longer carries the affordability reading this section quotes '
        .. '("cannot pay for it").  The foreclosure above has lost its evidence; '
        .. 'do not restate it from memory.')
end

tests['5. the pos_2 / pos_4 early-order difference lives on two hero levels'] = function()
    local tRows, tTalents = rows()
    local tMid = tRows[1]

    -- The one other row lever this round looked at: the pos_2 row takes its
    -- Heavenly Jump value point at hero level 2 -- its SECOND point overall,
    -- ahead of the second nuke -- while its own sibling row takes the same value
    -- point at level 4, after two points in each of its two nukes.  Build the
    -- mid row with entries 2 and 4 swapped (which gives it the sibling's shape:
    -- nuke, nuke, nuke, jump) and diff the RANKS HELD.
    local tSwap = {}
    for i, n in ipairs(tMid) do tSwap[i] = n end
    tSwap[2], tSwap[4] = tMid[4], tMid[2]
    assert(tSwap[2] ~= tMid[2],
        'entries 2 and 4 of the pos_2 row are now the same ability; the swap '
        .. 'this section measures is not a swap any more.')

    local _, _, tListA = drive(tMid, tTalents)
    local _, _, tListB = drive(tSwap, tTalents)

    -- Ranks held at each hero level, per engine slot, for both rows.
    local function ranks_at_level(tList, nLevel)
        local t = {}
        for i = 1, nLevel do
            if type(tList[i]) == 'string' then
                local nSlot = slot_of_entry(tList, i)
                t[nSlot] = (t[nSlot] or 0) + 1
            end
        end
        return t
    end
    local function same(a, b)
        for nSlot = 0, 6 do
            if (a[nSlot] or 0) ~= (b[nSlot] or 0) then return false end
        end
        return true
    end

    local tDiffer = {}
    for nLevel = 1, WALL_ENTRY - 1 do
        if not same(ranks_at_level(tListA, nLevel), ranks_at_level(tListB, nLevel)) then
            tDiffer[#tDiffer + 1] = nLevel
        end
    end

    -- ⭐ The reading, and it is the whole reason no candidate was cut here: the
    -- two rows hold DIFFERENT ranks on hero levels 2 and 3 and identical ranks
    -- from level 4 to the wall.  In turbo (docs/PROJECT.md: doubled XP, ~20
    -- minute games) that is the opening minute or two.  A lever with a two-level
    -- domain cannot be read by a wave, whichever way it points.
    --
    -- ⚠️ AND THE DOMAIN IS ARITHMETIC, NOT A PROPERTY OF THESE DIGITS -- bought
    -- by tools/agent/mutstand_zuusstrand.sh M7, which re-cut the row around the
    -- swap and the assertion below did not move.  Swapping row entries i and j
    -- changes the ranks held on exactly hero levels i..j-1 (no talent sits
    -- between entry 2 and entry 4), because every entry outside [i, j) is
    -- common to both rows and the two swapped points are both spent by level j.
    -- Here i=2 and j=4, so the domain is {2,3} for ANY row whose entries 2 and 4
    -- differ.  ⇒ What rules this lever out is WHERE IN THE ROW the two points
    -- sit, not which abilities they are -- and that is a stronger statement than
    -- the empirical one it replaces, because it holds for every re-cut of the
    -- row that keeps the value point at entry 2.
    assert(table.concat(tDiffer, ',') == '2,3',
        'the pos_2 row and its entry-2/4 swap now differ on hero levels {'
        .. table.concat(tDiffer, ',') .. '}, not {2,3}.  The reading declines '
        .. 'this lever on DOMAIN, so the domain is the thing to re-read.')

    -- The arithmetic, demonstrated rather than asserted in prose: swap entries 2
    -- and 12 of the same row and the domain is levels 2..11 -- the assertion
    -- above tracks the POSITIONS, so it is not vacuous.  ⛔ This is a property
    -- of the driven list, not a proposal; nobody is suggesting that row.
    local tFar = {}
    for i, n in ipairs(tMid) do tFar[i] = n end
    tFar[2], tFar[12] = tMid[12], tMid[2]
    if tFar[2] ~= tMid[2] then
        local _, _, tListFar = drive(tFar, tTalents)
        local tFarDiffer = {}
        for nLevel = 1, WALL_ENTRY - 1 do
            if not same(ranks_at_level(tListA, nLevel), ranks_at_level(tListFar, nLevel)) then
                tFarDiffer[#tFarDiffer + 1] = nLevel
            end
        end
        assert(table.concat(tFarDiffer, ',') == '2,3,4,5,6,7,8,9,10,11',
            'an entry-2/12 swap of the same row differs on hero levels {'
            .. table.concat(tFarDiffer, ',') .. '}, not 2..11.  The domain claim '
            .. 'above is supposed to follow from the two entries\' POSITIONS; if '
            .. 'this does not hold, it does not.')
    end

    -- And the sibling row really is the thing being compared to: its jump value
    -- point arrives at level 4, and levels 1-3 carry no jump at all.
    -- ⚠️ CORRECTED while writing this file, by this very assertion: the first
    -- draft claimed the sibling spends level 2 on the BOLT.  It spends it on the
    -- arc -- the sibling maxes the bolt, so its level-2 point is its other nuke.
    -- The claim that survives is about WHEN the jump arrives, which is the thing
    -- the swap moves.
    local _, _, tListSib = drive(tRows[2], tTalents)
    assert(slot_of_entry(tListSib, 4) == SLOT_JUMP,
        'the pos_4/5 row no longer spends level 4 on the jump; the "its own '
        .. 'sibling disagrees" half of this reading is gone.')
    for nLevel = 1, 3 do
        assert(slot_of_entry(tListSib, nLevel) ~= SLOT_JUMP,
            'the pos_4/5 row now holds a jump point at hero level ' .. nLevel
            .. '; the two rows no longer disagree about when the value point '
            .. 'arrives, so there is nothing here to decline.')
    end
end

return tests
