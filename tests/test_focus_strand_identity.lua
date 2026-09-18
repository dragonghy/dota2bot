-- [hero] [ratchet] `STRANDID`: WHICH ability the skill-point wall strands is a
-- function of the build row, it is derivable offline, and the derivation agrees
-- with GH #822's wave measurement on all EIGHT heroes that issue names.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- Two readings of the skill-point wall already exist and neither answers this
-- question:
--
--   * tests/test_skill_point_stall_frame.lua (GH #366) settled WHERE the wall is
--     -- entry 15, the t15 talent -- and that thirteen ability points sit in
--     front of it in the multiset {4,4,3,2}.
--   * tests/test_focus_talent_reach_wall.lua carried that to the focus rows and
--     pinned what happens to entry 17: every focus ultimate holds its THIRD
--     point there, so `ranks[6] == 2` forever.
--
-- Entry SIXTEEN is the one neither file names.  It is the other stranded ability
-- point, it is the `3` of {4,4,3,2}, and unlike entry 17 (always the ultimate)
-- WHICH ability it is differs per hero and is decided entirely by the build row.
--
-- ⭐ WHAT IS NEW, AND WHY IT IS WORTH A FILE
-- ------------------------------------------
-- GH #822 measured, on 8 games / 80 bodies, that in hero-level band 18-22 each
-- hero's gap is carried by EXACTLY ONE basic ability, the gap is EXACTLY one
-- rank, and it is the SAME ability across all 8 games.  It reported that shape
-- as a shape -- its own LIMIT 5 says the per-hero table "只作选点不作结论",
-- because the talent blind spot is uneven between heroes so the columns are not
-- comparable to each other.
--
-- That table is not a selection aid any more.  Section 3 derives the same column
-- from source -- build row -> shipped GetSkillList -> entry 16 -> engine slot ->
-- npc_heroes.txt -- with no dump in the room, and it matches the measured column
-- EIGHT for EIGHT:
--
--     vengeful_spirit  command_aura        crystal_maiden  brilliance_aura
--     death_prophet    silence             witch_doctor    voodoo_restoration
--     bristleback      viscous_nasal_goo   shadow_shaman   shackles
--     skywrath_mage    concussive_shot     skeleton_king   hellfire_blast
--
-- ⭐ The consequence is about MECHANISM, not about a prettier table.  #822 could
-- say a gap existed and could not say which mechanism opened it -- "banked > 0
-- AND a basic tier unbought" is a symptom that several stories fit.  A story
-- that also predicts, per hero, WHICH of the three basics carries it, and gets
-- eight for eight against rows it never saw, is not a fit any more.  The 229
-- PROVEN rows are THIS wall.
--
-- ⭐ AND THE ARITHMETIC EXPLAINS #822's OWN UNEXPLAINED SHAPE.  "Exactly one
-- ability, exactly one rank" is not an empirical regularity, it is what entry 16
-- IS: one entry, holding one rank, of the one slot the first thirteen points
-- left at 3.  #822 wrote that shape down without a reason; the reason is the
-- slot loop.
--
-- ⚠️ WHY THE CORROBORATION IS WELL-POSED AT ALL -- section 4, and it is load-
-- bearing rather than tidy.  Three of the eight heroes ship MORE THAN ONE build
-- row and pick between them at runtime (`GetRandomBuild`, a role test, or the
-- gated `wkbuild`), so the wave measured whatever row each body happened to roll
-- and the dump does not record which.  A prediction that differed between rows
-- would have nothing to compare against.  It does not: every multi-row hero here
-- strands the SAME ability from every one of its rows.  Section 4 asserts that
-- rather than noting it, because it is the premise the 8/8 rests on.
--
-- WHAT THIS FILE DOES NOT ESTABLISH -- READ BEFORE QUOTING IT
-- -----------------------------------------------------------
-- (1) It does not re-establish the wall.  That entry 15 is where the head parks
--     is #366's reading, off a frame plus the shipped spender; section 1 asserts
--     the dependency on it instead of restating its argument.  If that reading
--     falls, everything here is about an entry that is never reached and says
--     nothing about any game.
-- (2) ⛔ IT IS NOT A RATE, AND IT IS NOT A LOSS.  #822's LIMIT B carries over
--     verbatim: what is measured is a DELAY at the hero levels observed, not
--     "the hero finished the game without it".  Nothing here licenses a sentence
--     of the form "N ranks were thrown away".
-- (3) The index -> NAME step is not free, and section 2 buys it rather than
--     assuming it.  `sAbilityList[N]` is a compaction of a slot walk, so N names
--     an engine slot only under the KV convention that Ability1..3 are the three
--     basics (tests/test_hero_slot_order_anchor.lua).  Section 2 checks that
--     convention holds for every hero this file reads instead of trusting the
--     mock, whose hero carries a synthetic ability in all of slots 0-5 and so
--     CANNOT witness a hero that breaks it.
-- (4) ⛔ NO FIX IS PROPOSED HERE AND NONE SHOULD BE INFERRED.  The wall lives in
--     bots/ability_item_usage_generic.lua, a file all 127 heroes run, and it
--     already has a gated look-ahead (`skillstall`, GH #799).  Reordering a
--     focus build row to move the strand would be a hero-group change that
--     treats a shared-file defect one hero at a time -- and, per section 5, it
--     cannot even do that: the strand is whichever slot ends at rank 3, so any
--     row that spends thirteen points into {4,4,3,2} strands SOMETHING.
--     ⚠️ AMENDED 2026-09-19 (hero, gated candidate `axebuild`,
--     tests/test_axe_call_max_build.lua).  The last clause above is right about
--     REMOVING the strand and was read as also foreclosing CHOOSING it, which is
--     a different question and the one a row edit does answer.  Section 5b's own
--     verb is "it only moves" -- moving is the affordance.  Axe's shipped row
--     strands `axe_berserkers_call`; the gated row in this file's FOCUS list
--     strands `axe_battle_hunger` instead, at the same thirteen points and the
--     same {4,4,3,2}.  Nothing above changes: the wall is untouched, the strand
--     is not removed, and this file still says no row escapes it.
--
-- ⚠️ Tagged [ratchet].  Sections 3-5 assert that the defect is still there and
-- still has this shape.  The day the wall is fixed they go red; that is the
-- notification.  Delete them then -- do not loosen them.

package.path = 'tests/?.lua;' .. package.path

local skillmap = require('skill_level_map')

local HERO_SLOTS = 'tests/mock/hero_slots.lua'
local WALL_SRC = 'tests/test_skill_point_stall_frame.lua'

-- The entry the head parks ON (#366) and the two entries behind it.
local WALL_ENTRY = 15
local STRAND_ENTRY = 16 -- the basic's fourth rank -- this file's subject
local ULT_ENTRY = 17 -- the ultimate's third rank -- test_focus_talent_reach_wall

-- Points spent by the time the head reaches the wall, and the multiset they buy.
local SPENT_AT_WALL = 13
local STRANDED_RANK = 3 -- the `3` of {4,4,3,2}: the slot entry 16 would have maxed

--- Every build row this file drives.  `hero` is the key BOTH the mock world and
--- tests/mock/hero_slots.lua use; `file` is the BotLib basename, which differs
--- from it for vengefulspirit and is exactly the kind of thing a hand-kept table
--- gets wrong, so the loader below raises rather than skipping on a miss.
local FOCUS = {
    { hero = 'axe', file = 'hero_axe' },
    { hero = 'axe', file = 'hero_axe', tbl = 'tCallMaxBuildList' },
    { hero = 'zuus', file = 'hero_zuus' },
    { hero = 'skeleton_king', file = 'hero_skeleton_king' },
    { hero = 'skeleton_king', file = 'hero_skeleton_king', tbl = 'tKillBuildList' },
    { hero = 'lion', file = 'hero_lion' },
    { hero = 'crystal_maiden', file = 'hero_crystal_maiden' },
}

--- GH #822's measured column, quoted verbatim from the issue body's per-hero
--- table ("扛缺口的能力"), together with the PROVEN row count it reported.  These
--- are the wave's numbers, not this file's; they are here to be compared against,
--- never to be recomputed.
local MEASURED = {
    { hero = 'vengefulspirit', file = 'hero_vengefulspirit', gap = 'command_aura', rows = 34 },
    { hero = 'death_prophet', file = 'hero_death_prophet', gap = 'silence', rows = 33 },
    { hero = 'crystal_maiden', file = 'hero_crystal_maiden', gap = 'brilliance_aura', rows = 32 },
    { hero = 'witch_doctor', file = 'hero_witch_doctor', gap = 'voodoo_restoration', rows = 31 },
    { hero = 'bristleback', file = 'hero_bristleback', gap = 'viscous_nasal_goo', rows = 27 },
    { hero = 'shadow_shaman', file = 'hero_shadow_shaman', gap = 'shackles', rows = 27 },
    { hero = 'skywrath_mage', file = 'hero_skywrath_mage', gap = 'concussive_shot', rows = 26 },
    { hero = 'skeleton_king', file = 'hero_skeleton_king', gap = 'hellfire_blast', rows = 19 },
}

local tests = {}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a')
    fh:close()
    return s
end

local tSlotMap = dofile(HERO_SLOTS)

--- Every build row of one hero file, as lists of sAbilityList indices.
--- Memoised per (file, table) for the same reason strand_of is: the sections
--- below ask overlapping questions and each miss re-reads and re-parses a
--- multi-thousand-line hero file.  Safe because nothing here writes bots/, and
--- mutstand_strandid.sh mutates between PROCESSES, never inside one.
local tRowsMemo = {}

local function rows_of(sFile, sTable)
    local sKey = sFile .. '|' .. (sTable or 'tAllAbilityBuildList')
    if tRowsMemo[sKey] == nil then
        local sSrc = read_file('bots/BotLib/' .. sFile .. '.lua')
        local _, tRows = skillmap.build_row(sSrc, 1, sTable)
        tRowsMemo[sKey] = { tRows, skillmap.talent_rows(sSrc) }
    end
    return tRowsMemo[sKey][1], tRowsMemo[sKey][2]
end

--- Drive the SHIPPED J.Skill.GetSkillList for one row and report what it strands.
---
--- Returns the sAbilityList index at entry 16, the engine slot that index is a
--- compaction of, the rank that slot holds when the head reaches the wall, and
--- the whole rank table at the wall.
---
--- ⚠️ The engine slot is read off the MOCK's synthetic name rather than
--- recomputed: the mock names slot N `<hero>_mock_slot_N`, so the name preserves
--- exactly the datum the compaction would otherwise destroy.  Recomputing it here
--- would mean re-implementing X.GetAbilityList beside itself, which is the M8
--- mistake tests/skill_level_map.lua's own header names.
--- ⭐ The window ends at WALL_ENTRY - 1, and the choice is NOT delicate: entry 15
--- is the t15 talent, the mock's GetTalentList answers nils, so that entry has no
--- slot and ranks_at skips it.  Counting to 14 and counting to 15 give the same
--- thirteen points.  (Bought by mutstand_strandid.sh M7, whose first version
--- shifted exactly that boundary and survived for this reason -- recorded here so
--- the next reader does not mistake the survivor for a weak assertion.)
---
--- ⚠️ MEMOISED, and the memo is why this file fits inside the push gate.  Every
--- reading below is a question about the same handful of (hero, row) pairs, and
--- each uncached answer stands up TWO fresh mock worlds (ranks_at and
--- rank_ladder each drive one).  Six sections asking overlapping questions paid
--- for the same worlds five and six times over.  The key is the hero plus the
--- row's own digits, so a MUTATED row -- which is the whole point of
--- mutstand_strandid.sh group A -- is a different key and never reads a
--- pristine row's cached answer.
local tStrandMemo = {}

local function strand_of(sHero, tRow, tTalents)
    local sKey = sHero .. '|' .. table.concat(tRow, ',')
    local tHit = tStrandMemo[sKey]
    if tHit ~= nil then return tHit[1], tHit[2], tHit[3], tHit[4] end

    local tRanks, tList = skillmap.ranks_at(sHero, tRow, tTalents, WALL_ENTRY - 1)

    local sEntry = tList[STRAND_ENTRY]
    assert(type(sEntry) == 'string',
        sHero .. ': entry ' .. STRAND_ENTRY .. ' of the driven skill list is '
        .. type(sEntry) .. ', not an ability name.  The strand this file is about '
        .. 'is that entry; if the slot loop no longer puts an ability there, '
        .. 're-derive before touching anything below.')

    local nSlot = tonumber(sEntry:match('_mock_slot_(%d+)$'))
    assert(nSlot ~= nil,
        sHero .. ': entry ' .. STRAND_ENTRY .. ' is "' .. sEntry .. '", which does '
        .. 'not carry a `_mock_slot_N` suffix.  That suffix is the only thing '
        .. 'connecting a driven entry back to an engine slot; if the mock stopped '
        .. 'naming slots, this whole file loses its index -> name step.')

    -- Which sAbilityList index that entry is, read the same way skill_level_map
    -- reads it -- by identity of the name, never by position.
    -- ⚠️ The ladder is driven ONCE and then indexed.  The first version called
    -- rank_ladder inside the loop, i.e. it stood up a fresh mock world twelve
    -- times per row for one table; same answer, ~12x the wall clock, and wall
    -- clock is what decides whether this file is inside the push gate at all
    -- (tools/agent/lua_gate_manifest.json, per_test_cap_seconds).
    local tLadder = skillmap.rank_ladder(sHero, tRow, tTalents)
    local nIndex
    for i = 1, 12 do
        local tAt = tLadder[i]
        if tAt ~= nil and tAt[4] == STRAND_ENTRY then nIndex = i end
    end

    tStrandMemo[sKey] = { nSlot, nIndex, tRanks, tList }
    return nSlot, nIndex, tRanks, tList
end

--- The engine name of slot `nSlot` for `sHero`, under the convention section 2
--- checks.
local function slot_name(sHero, nSlot)
    local tRow = tSlotMap[sHero]
    assert(tRow ~= nil,
        'tests/mock/hero_slots.lua has no row for "' .. sHero .. '".  That file is '
        .. 'GENERATED (tools/agent/hero_slot_map.py) and only emits heroes shipped '
        .. 'in bots/BotLib; a miss here is a real gap, not a typo to work around.')
    return tRow[nSlot]
end

-- ---------------------------------------------------------------------------
-- 1. THE PREMISE THIS FILE RESTS ON, asserted rather than assumed.
--
-- Everything below is about entries 16 and 17.  Those are only interesting
-- because the head parks on entry 15 and the spender does not pop it -- #366's
-- reading.  This section does not re-argue that; it asserts that the file
-- carrying it still carries it, so that a future edit which RETIRES the wall
-- turns this file red instead of leaving it quietly measuring an entry every
-- hero now reaches.

tests['1. the wall reading this file depends on is still on trunk'] = function()
    local sWall = read_file(WALL_SRC)

    assert(sWall:find('entry 15 is a wall', 1, true) ~= nil,
        WALL_SRC .. ' no longer states that entry 15 is a wall.  This file is '
        .. 'ABOUT the two entries behind that wall; if the wall was fixed, delete '
        .. 'the ratchets below rather than re-pointing them.')

    -- And that it is the t15 TALENT parked there -- the reason entries 16/17 are
    -- unreachable rather than merely late.
    assert(sWall:find('the head at the moment of the stall is the t15 talent', 1, true) ~= nil,
        WALL_SRC .. ' no longer derives that the parked head is the t15 talent.  '
        .. 'That identification is what makes entries 16-17 unreachable at EVERY '
        .. 'hero level rather than just early ones.')
end

-- ---------------------------------------------------------------------------
-- 2. THE INDEX -> NAME STEP, bought rather than assumed.
--
-- `sAbilityList[N]` is what X.GetAbilityList's slot walk COMPACTED into position
-- N, so reading N as "engine slot N-1" is a claim about the hero's KV layout: it
-- holds while Ability1..3 are three real learnable basics, and breaks the moment
-- a placeholder or an unlearnable innate sits in slots 0-2.
--
-- ⚠️ The mock cannot witness this.  Its hero carries a synthetic ability in ALL
-- of slots 0-5 and none of them is `generic_hidden`, so the compaction is the
-- identity there whatever the real hero looks like.  The check therefore reads
-- the game's own npc_heroes.txt map, not the mock.

tests['2. every hero read here keeps its three basics in engine slots 0-2'] = function()
    local tSeen, tBad = {}, {}

    local function check(sHero)
        if tSeen[sHero] then return end
        tSeen[sHero] = true
        for nSlot = 0, 2 do
            local sName = slot_name(sHero, nSlot)
            if sName == nil or sName == '' or sName == 'generic_hidden'
                or sName:find('special_bonus', 1, true) == 1 then
                tBad[#tBad + 1] = sHero .. ' slot ' .. nSlot .. ' = ' .. tostring(sName)
            end
        end
    end

    for _, e in ipairs(FOCUS) do check(e.hero) end
    for _, e in ipairs(MEASURED) do check(e.hero) end

    assert(#tBad == 0,
        'the "Ability1..3 are the three basics" convention fails for: '
        .. table.concat(tBad, ', ') .. '.  Every index -> name step in this file '
        .. 'reads sAbilityList[N] as engine slot N-1, and that reading is exactly '
        .. 'this convention.  Re-derive the compaction for those heroes; do not '
        .. 'special-case them.')

    -- Non-vacuity: this must actually be reading rows, not an empty loop over a
    -- table someone emptied.
    local nHeroes = 0
    for _ in pairs(tSeen) do nHeroes = nHeroes + 1 end
    assert(nHeroes >= 11,
        'only ' .. nHeroes .. ' heroes were checked; FOCUS + MEASURED name eleven '
        .. 'distinct ones.  An assertion that passes because its loop is empty is '
        .. 'the failure this line exists to catch.')
end

-- ---------------------------------------------------------------------------
-- 3. ⭐ THE CLAIM: the derived strand equals GH #822's measured gap, 8 for 8.

tests['3. the derived strand matches the wave-measured gap ability for all eight'] = function()
    local tMiss, nHit = {}, 0

    for _, e in ipairs(MEASURED) do
        local tRows, tTalents = rows_of(e.file)
        local nSlot = strand_of(e.hero, tRows[1], tTalents)
        local sName = slot_name(e.hero, nSlot)

        -- Compared by full engine name against the issue's short name, so a
        -- coincidental substring on a DIFFERENT hero cannot score a hit.
        if sName == e.hero .. '_' .. e.gap then
            nHit = nHit + 1
        else
            tMiss[#tMiss + 1] = e.hero .. ': derived ' .. tostring(sName)
                .. ', GH #822 measured ' .. e.gap
        end
    end

    assert(#tMiss == 0,
        'the source derivation and GH #822s wave measurement have come apart for: '
        .. table.concat(tMiss, '; ') .. '.  This is the file whole claim.  A '
        .. 'mismatch means either a build row was edited (re-derive, and the '
        .. 'issue table is now historical) or the mechanism is not the wall after '
        .. 'all (much more interesting -- do not paper over it).')

    assert(nHit == 8,
        'only ' .. nHit .. ' of the eight measured heroes were derived.  The claim '
        .. 'is eight for eight; a shrunken corpus makes it a weaker claim wearing '
        .. 'the same sentence.')
end

--- The strand must be DRIVEN BY THE ROW, not a constant that would match any
--- column.  Two independent ways of being non-vacuous are checked, because
--- either alone is satisfiable by an accident.
tests['3b. the prediction is row-driven, not a constant'] = function()
    -- (a) The eight predictions are not all the same engine slot.
    local tSlots, tDistinct = {}, {}
    for _, e in ipairs(MEASURED) do
        local tRows, tTalents = rows_of(e.file)
        local nSlot = strand_of(e.hero, tRows[1], tTalents)
        tSlots[#tSlots + 1] = nSlot
        tDistinct[nSlot] = true
    end
    local nDistinct = 0
    for _ in pairs(tDistinct) do nDistinct = nDistinct + 1 end
    assert(nDistinct >= 3,
        'the eight derived strands land on only ' .. nDistinct .. ' distinct engine '
        .. 'slot(s) (' .. table.concat(tSlots, ',') .. ').  A prediction that always '
        .. 'answers the same slot would match a measured column of mostly-that-slot '
        .. 'without carrying any information; section 3 leans on this line.')

    -- (b) ⭐ The real negative control: perturb ONE row and the prediction moves.
    -- The strand is whichever slot the first thirteen points leave at rank 3, so
    -- swapping which index those points favour must relocate it.  Without this,
    -- "the row decides" is untested -- every row in the corpus could agree with
    -- the measurement for a reason that has nothing to do with the row.
    local tRows, tTalents = rows_of('hero_crystal_maiden')
    local nBase = strand_of('crystal_maiden', tRows[1], tTalents)

    -- Move the three late points from whichever index holds them onto index 1,
    -- which the shipped row maxes early; index 1 then ends at rank 3 instead.
    local tMutant = {}
    for i, v in ipairs(tRows[1]) do tMutant[i] = v end
    local nLate = tMutant[14]
    for i = 12, 14 do tMutant[i] = 1 end
    -- Give the displaced index the early points so the row still spends 15.
    for i = 1, 11 do if tMutant[i] == 1 then tMutant[i] = nLate end end

    local nMoved = strand_of('crystal_maiden', tMutant, tTalents)
    assert(nMoved ~= nBase,
        'perturbing which ability the build row favours late left the derived '
        .. 'strand on engine slot ' .. nBase .. ' regardless.  Then the derivation '
        .. 'is not reading the row, and section 3s eight-for-eight is eight '
        .. 'coincidences.')
end

-- ---------------------------------------------------------------------------
-- 4. WHY THE COMPARISON IS WELL-POSED: the strand does not depend on which row
--    a body rolled.
--
-- Three of the eight ship more than one row and choose at runtime, and the dump
-- does not record the choice.  If two rows of one hero stranded different
-- abilities, "GH #822 measured X" would not be comparable to any single
-- prediction.  They do not.

tests['4. every multi-row hero strands the same ability from all of its rows'] = function()
    local tSplit, nMulti = {}, 0

    local function check(sHero, sFile, sTable)
        local tRows, tTalents = rows_of(sFile, sTable)
        if #tRows < 2 then return end
        nMulti = nMulti + 1
        local nFirst = strand_of(sHero, tRows[1], tTalents)
        for i = 2, #tRows do
            local nThis = strand_of(sHero, tRows[i], tTalents)
            if nThis ~= nFirst then
                tSplit[#tSplit + 1] = sHero .. ' (' .. (sTable or 'tAllAbilityBuildList')
                    .. ') row 1 -> slot ' .. nFirst .. ', row ' .. i .. ' -> slot ' .. nThis
            end
        end
    end

    -- Both tables, because both are heroes this file predicts a strand for.
    -- ⚠️ Among the eight MEASURED heroes only death_prophet ships a second row in
    -- tAllAbilityBuildList (WK's second row lives in tKillBuildList behind
    -- `wkbuild`, which is section 4b's subject); Zeus is the other multi-row
    -- hero and it is in FOCUS, not MEASURED.
    for _, e in ipairs(MEASURED) do check(e.hero, e.file) end
    for _, e in ipairs(FOCUS) do check(e.hero, e.file, e.tbl) end

    assert(nMulti >= 2,
        'only ' .. nMulti .. ' hero(es) across both tables were found to ship '
        .. 'multiple rows in one build table.  death_prophet and zuus both do; if '
        .. 'the reader now sees one row each, build_row stopped parsing the second '
        .. 'and section 3 is reading half a corpus.')

    assert(#tSplit == 0,
        'a hero strands DIFFERENT abilities depending on which build row it rolls: '
        .. table.concat(tSplit, '; ') .. '.  GH #822s measurement cannot see which '
        .. 'row a body took, so the 8/8 in section 3 stops being a comparison of '
        .. 'like with like.  Re-state it per row before quoting it again.')
end

--- ⭐ WK carries the project's only GATED build row (`wkbuild`, GH #17), whose
--- own prose sells it as fixing WK's lockdown: it takes the second stun point at
--- level 5 instead of 13.  It does -- and it leaves the FOURTH rank of that same
--- stun stranded at entry 16 exactly as the shipped row does.  Pinned here so the
--- candidate is not read as reaching further than it does.
tests['4b. arming `wkbuild` does not move WK strand'] = function()
    local tShipped, tTalents = rows_of('hero_skeleton_king')
    local tGated = rows_of('hero_skeleton_king', 'tKillBuildList')

    local nShipped = strand_of('skeleton_king', tShipped[1], tTalents)
    local nGated = strand_of('skeleton_king', tGated[1], tTalents)

    assert(nShipped == nGated,
        'the gated `wkbuild` row now strands engine slot ' .. nGated
        .. ' where the shipped row strands ' .. nShipped .. '.  That is a real '
        .. 'change in what arming the candidate does and it belongs in the '
        .. 'candidate own prose (GH #17) before the next wave reads it.')

    assert(slot_name('skeleton_king', nShipped) == 'skeleton_king_hellfire_blast',
        'WK strand is no longer hellfire_blast.  GH #17s case for `wkbuild` is '
        .. 'written entirely about that ability lockdown, so re-read the candidate '
        .. 'rather than just updating this line.')
end

-- ---------------------------------------------------------------------------
-- 5. THE FOCUS FIVE, named -- and the reason no row edit can escape this.

tests['5. each focus row strands exactly one basic, at rank 3'] = function()
    local tBad = {}

    for _, e in ipairs(FOCUS) do
        local tRows, tTalents = rows_of(e.file, e.tbl)
        for nRow = 1, #tRows do
            local nSlot, nIndex, tRanks = strand_of(e.hero, tRows[nRow], tTalents)
            local sWhere = e.hero .. ' ' .. (e.tbl or 'tAllAbilityBuildList')
                .. ' row ' .. nRow

            -- The stranded index held rank 3 when the head reached the wall --
            -- i.e. entry 16 is the fourth rank, and the gap is one rank, not two.
            if nIndex == nil or tRanks[nIndex] ~= STRANDED_RANK then
                tBad[#tBad + 1] = sWhere .. ': entry ' .. STRAND_ENTRY
                    .. ' belongs to index ' .. tostring(nIndex) .. ' which holds rank '
                    .. tostring(nIndex and tRanks[nIndex]) .. ' at the wall, not '
                    .. STRANDED_RANK
            end

            -- It is a BASIC, not the ultimate: the ultimate's stranded point is
            -- entry 17 and belongs to test_focus_talent_reach_wall.lua.
            local sName = slot_name(e.hero, nSlot)
            if sName == nil or sName == '' or sName == 'generic_hidden' then
                tBad[#tBad + 1] = sWhere .. ': entry ' .. STRAND_ENTRY
                    .. ' names engine slot ' .. nSlot .. ' = ' .. tostring(sName)
            end

            -- And exactly one slot is at rank 3 -- "exactly one ability carries
            -- the gap" is arithmetic, not an empirical regularity (#822 shape).
            local nAtThree, nSpent = 0, 0
            for _, nRank in pairs(tRanks) do
                nSpent = nSpent + nRank
                if nRank == STRANDED_RANK then nAtThree = nAtThree + 1 end
            end
            if nAtThree ~= 1 then
                tBad[#tBad + 1] = sWhere .. ': ' .. nAtThree
                    .. ' slots hold rank 3 at the wall, not exactly one'
            end
            if nSpent ~= SPENT_AT_WALL then
                tBad[#tBad + 1] = sWhere .. ': ' .. nSpent .. ' points spent at the '
                    .. 'wall, not ' .. SPENT_AT_WALL
            end
        end
    end

    assert(#tBad == 0, table.concat(tBad, '\n  '))
end

--- ⛔ The line that forecloses "just reorder the row".  Entry 16 is the fourth
--- rank of whichever slot the first thirteen points left at 3, and thirteen
--- points across three basics and an ultimate cannot leave all four at a rank
--- they are happy with.  So a row edit RELOCATES the strand; it never removes
--- one.  Checked by construction over the corpus rather than argued.
tests['5b. no row in the corpus escapes the strand -- it only moves'] = function()
    local nRows, tEscaped = 0, {}

    local function sweep(sHero, sFile, sTable)
        local tRows, tTalents = rows_of(sFile, sTable)
        for nRow = 1, #tRows do
            nRows = nRows + 1
            local _, _, tRanks, tList = strand_of(sHero, tRows[nRow], tTalents)
            local nSpent = 0
            for _, nRank in pairs(tRanks) do nSpent = nSpent + nRank end
            -- An escape would be a row that has nothing left behind the wall.
            if tList[STRAND_ENTRY] == nil and tList[ULT_ENTRY] == nil then
                tEscaped[#tEscaped + 1] = sHero .. ' ' .. (sTable or 'tAllAbilityBuildList')
                    .. ' row ' .. nRow .. ' (' .. nSpent .. ' points at the wall)'
            end
        end
    end

    for _, e in ipairs(FOCUS) do sweep(e.hero, e.file, e.tbl) end
    for _, e in ipairs(MEASURED) do sweep(e.hero, e.file) end

    assert(nRows >= 14,
        'only ' .. nRows .. ' build rows were swept; FOCUS + MEASURED carry more '
        .. 'than that between them.  A sweep that shrank is not a sweep that passed.')

    assert(#tEscaped == 0,
        'these rows leave NOTHING behind the wall: ' .. table.concat(tEscaped, '; ')
        .. '.  If that is real it is the first row shape that dodges the strand '
        .. 'and it is worth a report of its own -- verify it before celebrating, '
        .. 'because the likelier cause is that build_row parsed a short row.')
end

return tests
