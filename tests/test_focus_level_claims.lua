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

return tests
