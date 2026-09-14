-- [hero] Every "ability X is rank R at hero level N" claim written in the focus
-- five's prose, checked against the level map the shipped code actually produces.
--
-- WHY THIS FILE EXISTS.  GH #134: the build row's index is NOT the hero level.
-- bots/FunLib/aba_skill.lua's X.GetSkillList spends levels 10 / 15 / 20 on
-- TALENTS, so from level 10 on every ability entry is pushed one level later per
-- talent already taken, and a 15-entry row has only THIRTEEN ability points down
-- at level 15.  Six write-ups had already been corrected one at a time when this
-- file was written; the sweep that produced it found five more surviving in
-- hero_axe.lua, hero_skeleton_king.lua and this suite's own Lion t10 header --
-- including one file that contradicted ITSELF (test_lion_t10_payoff.lua said
-- "rank 4 by hero level 10" in its honest bounds and "rank 3 at the moment of the
-- pick" in its section 3).  Correcting prose one sighting at a time does not
-- converge: the claims have to be pinned to the code that answers them.
--
-- HOW IT PINS THEM.  Each claim below carries a needle TEMPLATE with the level
-- left as %d.  The level is filled in from tests/skill_level_map.rank_ladder,
-- which runs the shipped J.Skill.GetSkillList; the test then requires that exact
-- string to be present in the file.  So there is one source for the number: change
-- a build row and the prose stops matching until somebody re-reads it, and edit
-- the prose to a hand-counted level and it stops matching immediately.  This is
-- the same shape as tests/test_gate_claim_consistency.lua, which stops a comment
-- from claiming a gate that is not there.
--
-- WHAT IT DOES NOT DO -- two limits, both load-bearing
--   * It checks the LEVEL half of each claim, not the ability NAME half.  For
--     hero_axe.lua / hero_lion.lua / hero_zuus.lua the file's own
--     abilityQ/W/E/R = sAbilityList[n] bindings tie a slot to a letter and those
--     are asserted below; the letter -> in-game name step is still prose.
--   * hero_skeleton_king.lua binds every ability by hardcoded name and never
--     indexes sAbilityList, so for WK the slot -> name step has NO offline
--     evidence at all.  It is deliberately NOT reconstructed from the fixture
--     corpus: the dump order is not the slot order (GH #151, and the standing
--     LIMIT in tools/agent/gen_ability_meta.py).  WK's claims are therefore
--     pinned as claims about BUILD-ROW INDICES, which is exactly how that file
--     words them ("Wraithfire Blast (index 1, the only lockdown)").

package.path = 'tests/?.lua;' .. package.path
local skillmap = require('skill_level_map')

local tests = {}

local SRC = {}
local function src_of(sPath)
    SRC[sPath] = SRC[sPath] or skillmap.read_file(sPath)
    return SRC[sPath]
end

local function occurrences(sHaystack, sNeedle)
    local n, pos = 0, 1
    while true do
        local i = sHaystack:find(sNeedle, pos, true)
        if not i then return n end
        n, pos = n + 1, i + 1
    end
end

--- The hero level at which `slot` reaches `rank` on the named build row.
local function level_of(spec, nSlot, nRank)
    local src = src_of(spec.file)
    local row = skillmap.build_row(src, spec.row, spec.table)
    local ladder = skillmap.rank_ladder(spec.hero, row, skillmap.talent_rows(src))
    assert(ladder[nSlot] ~= nil,
        spec.hero .. "'s build row " .. (spec.table or 'tAllAbilityBuildList')
        .. '#' .. (spec.row or 1) .. ' puts no points in slot ' .. nSlot
        .. ' -- the claim this test pins is about an ability the row no longer buys')
    local nLevel = ladder[nSlot][nRank]
    assert(nLevel ~= nil,
        spec.hero .. ' slot ' .. nSlot .. ' never reaches rank ' .. nRank
        .. ' on that row (it stops at rank ' .. #ladder[nSlot] .. ')')
    return nLevel
end

-- ---------------------------------------------------------------------------
-- 1. The interleave itself.  Every claim below inherits from it, so it is
--    asserted once, on every focus hero, before anything quotes it.

local FOCUS = {
    { hero = 'axe',            file = 'bots/BotLib/hero_axe.lua' },
    { hero = 'lion',           file = 'bots/BotLib/hero_lion.lua' },
    { hero = 'skeleton_king',  file = 'bots/BotLib/hero_skeleton_king.lua' },
    { hero = 'zuus',           file = 'bots/BotLib/hero_zuus.lua' },
    { hero = 'crystal_maiden', file = 'bots/BotLib/hero_crystal_maiden.lua' },
}

tests['[hero] the focus five spend 9 ability points by level 10 and 13 by level 15'] = function()
    for _, h in ipairs(FOCUS) do
        local src = src_of(h.file)
        local _, rows = skillmap.build_row(src)
        local trows = skillmap.talent_rows(src)
        for i = 1, #rows do
            local _, _, spent10 = skillmap.ranks_at(h.hero, rows[i], trows, 10)
            local _, _, spent15 = skillmap.ranks_at(h.hero, rows[i], trows, 15)
            assert(spent10 == 9, h.hero .. ' row #' .. i .. ' has ' .. spent10
                .. ' ability points down at level 10, not 9. If X.GetSkillList no '
                .. 'longer spends level 10 on a talent, EVERY level claim pinned in '
                .. 'this file was written against the old interleave (GH #134).')
            assert(spent15 == 13, h.hero .. ' row #' .. i .. ' has ' .. spent15
                .. ' ability points down at level 15, not 13 (same reason).')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 2. The slot -> letter bindings the prose leans on, read out of the hero files.

tests['[hero] the slots the level claims name are the slots the hero files bind'] = function()
    local WANT = {
        { file = 'bots/BotLib/hero_axe.lua',  handle = 'abilityW', slot = 2, what = 'Battle Hunger' },
        { file = 'bots/BotLib/hero_axe.lua',  handle = 'abilityQ', slot = 1, what = "Berserker's Call" },
        { file = 'bots/BotLib/hero_lion.lua', handle = 'abilityE', slot = 3, what = 'Mana Drain' },
        { file = 'bots/BotLib/hero_lion.lua', handle = 'abilityW', slot = 2, what = 'Hex' },
        { file = 'bots/BotLib/hero_zuus.lua', handle = 'abilityQ', slot = 1, what = 'Arc Lightning' },
    }
    for _, w in ipairs(WANT) do
        local slots = skillmap.ability_slots(src_of(w.file))
        assert(slots[w.handle] == w.slot,
            w.file .. ' binds ' .. w.handle .. ' to sAbilityList['
            .. tostring(slots[w.handle]) .. '], not [' .. w.slot .. ']. The level '
            .. 'claims about ' .. w.what .. ' are written against slot ' .. w.slot
            .. ' -- re-read them before changing the binding.')
    end
end

tests['[hero] hero_skeleton_king.lua still binds by name, so its claims stay index claims'] = function()
    local slots = skillmap.ability_slots(src_of('bots/BotLib/hero_skeleton_king.lua'))
    assert(next(slots) == nil,
        'hero_skeleton_king.lua now binds an ability through sAbilityList[n]. That '
        .. 'is an improvement -- it gives the WK level claims the slot -> letter leg '
        .. 'they currently lack (see this file\'s header) -- but this test recorded '
        .. 'the absence, so pin the new binding here instead of deleting the case.')
end

-- ---------------------------------------------------------------------------
-- 3. The claims.  `fmt` is filled from the driven ladder and must then be found
--    in the file verbatim.  `levels` lists {slot, rank} pairs in %d order;
--    `spec` names the build row each pair is read from.

local AXE  = { hero = 'axe',           file = 'bots/BotLib/hero_axe.lua' }
local LION = { hero = 'lion',          file = 'bots/BotLib/hero_lion.lua' }
local ZUUS = { hero = 'zuus',          file = 'bots/BotLib/hero_zuus.lua' }
local WK   = { hero = 'skeleton_king', file = 'bots/BotLib/hero_skeleton_king.lua' }
local ZUUS2 = { hero = 'zuus', file = 'bots/BotLib/hero_zuus.lua', row = 2 }
local WKILL = { hero = 'skeleton_king', file = 'bots/BotLib/hero_skeleton_king.lua',
                table = 'tKillBuildList' }

local CLAIMS = {
    {   -- hero_axe.lua, t10 rationale.  Was "is maxed by level 10" until 2026-08-24.
        name  = 'axe t10: Battle Hunger is rank 4 from level 11, not 10',
        file  = 'bots/BotLib/hero_axe.lua',
        fmt   = "rank 4 from level %d (the row's 10th entry",
        parts = { { AXE, 2, 4 } },
    },
    {   -- hero_axe.lua, t15 rationale (already correct; pinned so it stays so).
        name  = "axe t15: Berserker's Call's last point lands at level 16",
        file  = 'bots/BotLib/hero_axe.lua',
        fmt   = "Call's last point lands at level %d",
        parts = { { AXE, 1, 4 } },
    },
    {   -- tests/test_focus_talent_anchor.lua, the Axe t10 record (already correct).
        name  = 'the talent anchor quotes level 11 for Battle Hunger, not 10',
        file  = 'tests/test_focus_talent_anchor.lua',
        fmt   = "is maxed by level %d (the row",
        parts = { { AXE, 2, 4 } },
    },
    {   -- hero_zuus.lua, t15 rationale (already correct).
        name  = 'zeus t15: Arc Lightning is maxed at level 7 (pos_2) and 11 (pos_4/5)',
        file  = 'bots/BotLib/hero_zuus.lua',
        fmt   = 'pos_2 by level %d, pos_4/5 by level %d',
        parts = { { ZUUS, 1, 4 }, { ZUUS2, 1, 4 } },
    },
    {   -- hero_lion.lua, t10 honest bound (already correct).
        name  = "lion t10: Mana Drain's 4th point lands at level 11",
        file  = 'bots/BotLib/hero_lion.lua',
        fmt   = "the row's 10th entry lands at level %d",
        parts = { { LION, 3, 4 } },
    },
    {   -- hero_lion.lua, t15 rationale (already correct).
        name  = "lion t15: Hex's 2nd point lands at level 13, not 12",
        file  = 'bots/BotLib/hero_lion.lua',
        fmt   = 'rank 2 arriving at level 12; it arrives at %d',
        parts = { { LION, 2, 2 } },
    },
    {   -- hero_skeleton_king.lua, wkbuild rationale.  Was "until level 12".
        name  = 'wk: the default row leaves Wraithfire Blast at one point until 13',
        file  = 'bots/BotLib/hero_skeleton_king.lua',
        fmt   = 'at a SINGLE point until level %d',
        parts = { { WK, 1, 2 } },
    },
    {   -- Was "(1/9/10/12 vs 1/3/5/7)" -- row indices read as levels on both sides.
        name  = 'wk: both rows\' Bone Guard ladders are hero levels',
        file  = 'bots/BotLib/hero_skeleton_king.lua',
        fmt   = '(%d/%d/%d/%d vs %d/%d/%d/%d',
        parts = { { WKILL, 2, 1 }, { WKILL, 2, 2 }, { WKILL, 2, 3 }, { WKILL, 2, 4 },
                  { WK, 2, 1 }, { WK, 2, 2 }, { WK, 2, 3 }, { WK, 2, 4 } },
    },
    {   -- Was "at level 5 instead of 12".
        name  = 'wk: the kill row buys the 2nd stun at 5 against the default 13',
        file  = 'bots/BotLib/hero_skeleton_king.lua',
        fmt   = 'point at level %d instead of %d',
        parts = { { WKILL, 1, 2 }, { WK, 1, 2 } },
    },
    {   -- Was "at 8 instead of 10".
        name  = 'wk: the kill row maxes Mortal Strike at 8 against the default 11',
        file  = 'bots/BotLib/hero_skeleton_king.lua',
        fmt   = 'maxing Mortal Strike at %d instead of %d',
        parts = { { WKILL, 3, 4 }, { WK, 3, 4 } },
    },
    {   -- hero_skeleton_king.lua, the wkqaim pre-flight.  Was "level 2 to 11".
        name  = 'wk: the wkqaim supply argument spans levels 2 to 12',
        file  = 'bots/BotLib/hero_skeleton_king.lua',
        fmt   = 'from hero level 2 to %d',
        parts = { { WK, 1, 2, minus_one = true } },
    },
    {
        name  = 'wk: the wkqaim pre-flight names 13 as the level the 2nd point lands',
        file  = 'bots/BotLib/hero_skeleton_king.lua',
        fmt   = 'the 2nd point lands at %d',
        parts = { { WK, 1, 2 } },
    },
}

for _, claim in ipairs(CLAIMS) do
    tests['[hero] ' .. claim.name] = function()
        local args = {}
        for i, part in ipairs(claim.parts) do
            local nLevel = level_of(part[1], part[2], part[3])
            if part.minus_one then
                -- "rank 1 from level A to B" is the band that CLOSES one level
                -- before the next point lands, so it is the ladder entry minus 1.
                nLevel = nLevel - 1
            end
            args[i] = nLevel
        end
        local sWant = string.format(claim.fmt, unpack(args))
        local n = occurrences(src_of(claim.file), sWant)
        assert(n == 1,
            claim.file .. ' contains ' .. n .. ' copies of ' .. string.format('%q', sWant)
            .. ', expected exactly 1. Either the prose was hand-edited to a level '
            .. 'nobody drove out of J.Skill.GetSkillList (GH #134: the build row\'s '
            .. 'index is not the hero level), or the build row changed and the '
            .. 'write-up that prices it has not been re-read.')
    end
end

-- ---------------------------------------------------------------------------
-- 4. Two rank readings the prose states directly rather than as a level.

tests['[hero] lion t15: the build holds Hex at rank 3 when the t15 pick is made'] = function()
    local src = src_of('bots/BotLib/hero_lion.lua')
    local ranks = skillmap.ranks_at('lion', skillmap.build_row(src), skillmap.talent_rows(src), 15)
    assert(ranks[2] == 3, 'hero_lion.lua prices its t15 pair on Hex being rank 3 at '
        .. 'level 15; the shipped row now holds rank ' .. tostring(ranks[2]) .. '.')
    assert(occurrences(src, 'put three points in Hex: rank 3') == 1,
        'the rank-3 sentence is gone from hero_lion.lua, but the -2.0s cooldown '
        .. 'arithmetic (16/14 = +14.3%) is conditional on it.')
end

tests['[hero] lion t10: the build holds Mana Drain at rank 3 when the t10 pick is made'] = function()
    local src = src_of('bots/BotLib/hero_lion.lua')
    local ranks = skillmap.ranks_at('lion', skillmap.build_row(src), skillmap.talent_rows(src), 10)
    assert(ranks[3] == 3, 'hero_lion.lua and tests/test_lion_t10_payoff.lua both '
        .. 'state the abandoned t10 talent buys 25 -> 35 rather than its top-rank '
        .. '30 -> 40, which is true only while Mana Drain is rank 3 at level 10; '
        .. 'the shipped row now holds rank ' .. tostring(ranks[3]) .. '.')
    -- The level in this sentence is the TALENT TIER, not a ladder entry, so it is
    -- checked against the rank above rather than filled in from the ladder.
    assert(occurrences(src_of('tests/test_lion_t10_payoff.lua'),
        'Mana Drain at rank THREE at hero level 10') == 1,
        "tests/test_lion_t10_payoff.lua's honest bound no longer states the rank "
        .. 'Mana Drain holds at the moment of the t10 pick. It said "rank 4 by hero '
        .. 'level 10" until 2026-08-24, contradicting its own section 3 -- that is '
        .. 'the failure this assertion exists to stop recurring (GH #134).')
end

-- ---------------------------------------------------------------------------
-- 5. THE SPACER ARITHMETIC.  Added 2026-09-14 to pin what
--    iterations/streams/hero.md `-168` derived and deliberately did NOT assert
--    ("是推导不是判决"), which is why it is here: an unpinned derivation is read
--    as a ruling by the next person who needs it.
--
--    THE DERIVATION.  Every focus build row buys the ultimate as its 6th, 11th
--    and 15th ABILITY entry.  The engine makes those ranks legal at hero levels
--    6 / 12 / 18.  The row's 11th ability entry cannot arrive before hero level
--    11 whatever else is in the queue -- eleven points is eleven levels -- so on
--    the abilities alone the 2nd ultimate point arrives ONE LEVEL EARLY.  What
--    saves it is the t10 pick sitting at queue position 10: exactly one non-
--    ability entry ahead of it, lifting it to exactly 12.
--
--    ⭐ SO THE TALENT ROWS ARE LOAD-BEARING SPACERS, not clutter, and the slack
--    is ZERO.  "Move the talents behind the abilities" is the obvious tidy-up
--    and it drops the 2nd ultimate point to level 11, where it is illegal, where
--    the head-blocking spender parks it, and where every ability point behind it
--    parks too (tests/test_focus_build_level_legality.lua section 1 pins that
--    shape).  ⛔ Do not reorder a focus build row on tidiness grounds.
--
--    WHAT IS DRIVEN vs WHAT IS WRITTEN DOWN.  The arrival levels come from
--    skill_level_map.rank_ladder, which runs the shipped J.Skill.GetSkillList;
--    the entry indices come from the row literal.  The REQUIREMENTS (6/12/18)
--    are constants, for the same reason and with the same limit that
--    test_focus_build_level_legality.lua states: GetHeroLevelRequiredToUpgrade()
--    is the engine's and is not readable offline.  None of the focus five
--    carries a non-standard requirement.

local ULT_SLOT = 6
local ULT_REQ = { 6, 12, 18 }

local FOCUS_ROWS = {
    { name = 'axe',            spec = AXE },
    { name = 'lion',           spec = LION },
    { name = 'wk default',     spec = WK },
    { name = 'zuus pos_2',     spec = ZUUS },
    { name = 'zuus pos_4/5',   spec = ZUUS2 },
    { name = 'crystal_maiden', spec = { hero = 'crystal_maiden',
                                        file = 'bots/BotLib/hero_crystal_maiden.lua' } },
}

--- The row's ABILITY-entry index of the nRank-th point in nSlot, i.e. how many
--- ability points are down (inclusive) when that rank is bought.  This is the
--- floor on the hero level it can arrive at, and it is read off the row literal
--- rather than off the driven list on purpose: the two disagreeing is exactly
--- the arithmetic this section prices.
local function entry_index(spec, nSlot, nRank)
    local row = skillmap.build_row(src_of(spec.file), spec.row, spec.table)
    local nSeen = 0
    for i, v in ipairs(row) do
        if v == nSlot then
            nSeen = nSeen + 1
            if nSeen == nRank then return i end
        end
    end
    return nil
end

tests['[hero] the ultimate is still sAbilityList[6], so section 5 reads the right slot'] = function()
    assert(src_of('bots/FunLib/aba_skill.lua'):find('sAbilityList%[6%] = name') ~= nil,
        'bots/FunLib/aba_skill.lua no longer parks the ultimate at sAbilityList[6]; '
        .. 'every level in section 5 is then about some other ability.')
end

tests['[hero] every focus row buys the ultimate as its 6th / 11th / 15th ability entry'] = function()
    for _, r in ipairs(FOCUS_ROWS) do
        for nRank, nWantIdx in ipairs({ 6, 11, 15 }) do
            local nIdx = entry_index(r.spec, ULT_SLOT, nRank)
            assert(nIdx == nWantIdx, r.name .. ' buys ultimate rank ' .. nRank
                .. ' as ability entry #' .. tostring(nIdx) .. ', not #' .. nWantIdx
                .. '. The spacer arithmetic below is written against the shared '
                .. 'shape of the six rows; re-derive it for this row before '
                .. 'editing the number here.')
        end
    end
end

tests['[hero] the t10 pick is the spacer that lifts ultimate rank 2 to exactly level 12'] = function()
    for _, r in ipairs(FOCUS_ROWS) do
        local nIdx   = entry_index(r.spec, ULT_SLOT, 2)
        local nLevel = level_of(r.spec, ULT_SLOT, 2)
        local nReq   = ULT_REQ[2]
        assert(nLevel == nReq, r.name .. ' reaches ultimate rank 2 at level '
            .. nLevel .. ', and it is legal at ' .. nReq .. '. Early means the '
            .. 'head parks and the whole queue behind it parks; late means a '
            .. 'level of ultimate was given away.')
        -- The floor, and the spacers that clear it.  nLevel - nIdx is the number
        -- of NON-ability entries the queue spends before this point arrives.
        --
        -- ⚠️ The third assertion below is an IDENTITY once the first two hold
        -- (12 - 11 = 1), and tools/agent/mutstand_focus_spacer.sh records that
        -- no mutant can kill it alone.  It is kept for its failure TEXT: the
        -- first two say a level moved, this one says which structural fact
        -- moved it, and that is the sentence a reader needs before touching a
        -- build row.
        assert(nIdx == nReq - 1, r.name .. ': ultimate rank 2 is ability entry #'
            .. nIdx .. ', so the ability points alone put it at level ' .. nIdx
            .. ' against a requirement of ' .. nReq .. '. This section exists '
            .. 'because that gap is exactly 1.')
        assert(nLevel - nIdx == 1, r.name .. ' now has ' .. (nLevel - nIdx)
            .. ' non-ability entries ahead of ultimate rank 2, not 1. With ZERO '
            .. 'the point arrives at level ' .. nIdx .. ' and head-blocks; the '
            .. 't10 pick at queue position 10 is a load-bearing spacer, not '
            .. 'clutter (iterations/streams/hero.md -168).')
    end
end

tests['[hero] ultimate rank 3 arrives one level early on every focus row, by construction'] = function()
    for _, r in ipairs(FOCUS_ROWS) do
        local nIdx   = entry_index(r.spec, ULT_SLOT, 3)
        local nLevel = level_of(r.spec, ULT_SLOT, 3)
        local nReq   = ULT_REQ[3]
        assert(nLevel == 17 and nReq - nLevel == 1, r.name
            .. ' reaches ultimate rank 3 at level ' .. nLevel .. ' against a '
            .. 'requirement of ' .. nReq .. '. The "the warning is structural" '
            .. 'reading below is conditional on that shortfall being exactly 1 '
            .. 'level; re-take it.')
        assert(nLevel - nIdx == 2, r.name .. ' has ' .. (nLevel - nIdx)
            .. ' non-ability entries ahead of ultimate rank 3, not 2 (t10 and t15).')
    end
end

tests['[hero] so the level-up warning is structural, not an anomaly signal'] = function()
    -- ⚠️ THE CLAIM, stated at the strength the arithmetic supports and no
    -- higher.  `-168` wrote it as "the terminal else is entered at least once
    -- per hero per game"; driven, the honest form is CONDITIONAL ON REACHING
    -- LEVEL 17.  A focus hero that reaches 17 asks for a rank that is legal at
    -- 18, the head cannot be levelled, and the spender falls into the terminal
    -- `else` -- which prints "[WARN] Skipped to level up ability" and, below
    -- hero level 25, does NOT pop.  A hero that never reaches 17 never gets
    -- there.  This matters to whoever reads that warning out of a log: the
    -- DENOMINATOR is heroes that reached level 17, and a sighting is evidence
    -- of nothing by itself.
    local body = skillmap.terminal_else_body(src_of('bots/ability_item_usage_generic.lua'))
    local removals = skillmap.queue_removals(body)
    assert(#removals >= 1, 'the terminal else no longer pops the queue at all; '
        .. 'the parked-head reading above was taken against a branch that pops '
        .. 'only above hero level 25.')
    assert(body:find('botLevel > 25', 1, true) ~= nil,
        'the terminal else pops without the `botLevel > 25` guard -- an illegal '
        .. 'head is now SKIPPED rather than parked, so the level-17 park (and '
        .. 'everything section 5 says about it) has to be re-read.')
    -- And the wall itself: at 17 there is nothing else legal to buy, so the
    -- point has no alternative.  Every non-ultimate slot is already at its last
    -- rank by then on every focus row.
    for _, r in ipairs(FOCUS_ROWS) do
        local src = src_of(r.spec.file)
        local row = skillmap.build_row(src, r.spec.row, r.spec.table)
        local ladder = skillmap.rank_ladder(r.spec.hero, row, skillmap.talent_rows(src))
        for nSlot, tRanks in pairs(ladder) do
            if nSlot ~= ULT_SLOT then
                assert(tRanks[#tRanks] <= 17, r.name .. ' slot ' .. nSlot
                    .. ' still wants a point at level ' .. tRanks[#tRanks]
                    .. ', i.e. AFTER the level-17 ultimate park. The park is then '
                    .. 'no longer costless and this case is understating it.')
            end
        end
    end
end

return tests
