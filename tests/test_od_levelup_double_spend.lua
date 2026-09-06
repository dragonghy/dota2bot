-- [ratchet] [hero] GH #330 -- what the `generic_hidden` entry in Obsidian
-- Destroyer's shipped build row ACTUALLY costs, driven through the shipped
-- level-up spender instead of through a 1:1 "one entry, one point" model.
--
-- Tagged `[ratchet]` so routine_selfcheck.sh's fast Lua leg reads it every round:
-- §1 and §2 pin the two branches of bots/ability_item_usage_generic.lua that the
-- whole reading rests on, and an edit to either one changes what every number
-- below means. That has to be noticed the same round, not whenever the
-- ~100-minute full suite next completes (GH #124/#267).
--
-- WHAT THIS FILE ADDS TO tests/test_od_build_objurgation.lua.  That file asks
-- WHICH ability index 4 names (`generic_hidden`) and prices the four points aimed
-- at it as "points that buy nothing".  This file asks what the SPENDER does when
-- that entry reaches the head of the queue, and the answer is not "waste one
-- point": it is a DOUBLE SPEND that desynchronises the queue and then jams it.
--
-- ⭐ THE MECHANISM, read off bots/ability_item_usage_generic.lua:351-358.
-- When the head is `generic_hidden` the spender takes `sAbilityLevelUpList[2]`,
-- pops the HEAD, and calls ActionImmediate_LevelAbility on that second entry --
-- WITHOUT popping it.  So one hero level advances the queue by one entry while
-- advancing the ranks by one MORE than the queue believes.  Astral Imprisonment
-- therefore receives a fifth request it cannot take, and the final `else` of the
-- same function parks an untakeable head instead of skipping it (the pop there is
-- guarded by `botLevel > 25`).  From that level on the hero spends nothing.
--
-- ⭐ THE FRAMES CLOSE A DISJUNCTION THE SOURCE SAYS IS OFFLINE-UNDECIDABLE.
-- Two things could not be read offline, and GH #330's W28 corpus answers both:
--   (1) "whether the engine hands back a handle for the placeholder" -- if it did
--       not, the `generic_hidden` branch never runs.  W28's baseline OD is at
--       astral rank 2 on its THIRD point (t=69.5, hero level 3).  A 1:1 model
--       cannot produce rank 2 there; the double-spend produces exactly it.  So
--       the branch ran, and the handle exists.
--   (2) what the spender does when the head is already at max rank.  §4 drives
--       both worlds: PARK reproduces the corpus (6 points, level 7, frozen for
--       the rest of the game); POP does not (16 points, still levelling at 25).
--
-- WHAT IS NOT CLAIMED
--   * NOT an effect size and NOT a win.  n = 10 OD hero-games in GH #330; this
--     file is a mechanism, and whether `odbuild` wins games is conditions (b)
--     and (c), asked of a wave.
--   * NOT a promote argument.  `odbuild` is gated and turbo-only; §6 asserts the
--     shipped row is still the default, exactly as tests/test_od_build_objurgation
--     .lua §6 does.
--   * The rank->required-level ladder (basic 1/3/5/7, ultimate 6/12/18) is the
--     game's standard one, written here as constants, same premise and same
--     limit as tests/test_focus_build_level_legality.lua:123.  The engine's
--     GetHeroLevelRequiredToUpgrade() is the authority and is not readable
--     offline.  OD carries no non-standard RequiredLevel.
--   * ⚠️ THE MODEL IS KNOWN-INCOMPLETE ON THE TALENT HALF, and §7 records the
--     gap rather than tuning it away: it predicts the ARMED leg reaches 19 points
--     by level 25 (15 ability + 4 talent) and W28 read 16 (15 ability + 1
--     talent).  The three missing points are TALENT points on a leg with no
--     placeholder in it at all, so they are a SECOND defect that `odbuild` does
--     not touch and this file does not explain.
--   * The attribution "index 4 is the hole that stalls OD" is source + this
--     corpus's perfect correlation, not an independent mechanism experiment.
--     GH #330 declined to re-claim GH #286's attribution and so does this file;
--     what is asserted below is the ARITHMETIC of the shipped spender.

package.path = 'tests/?.lua;' .. package.path

local api     = require('mock.bot_api')
local rf      = require('mock.replay_fixture')
local meta    = require('mock.ability_meta')
local skillmap = require('skill_level_map')

local FRAME       = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local SOURCE      = 'bots/BotLib/hero_obsidian_destroyer.lua'
local SPENDER     = 'bots/ability_item_usage_generic.lua'
local SLOTS_LUA   = 'tests/mock/hero_slots.lua'
local HERO        = 'obsidian_destroyer'
local UNIT        = 'npc_dota_hero_' .. HERO
local PLACEHOLDER = 'generic_hidden'
local ASTRAL      = 'obsidian_destroyer_astral_imprisonment'
local ORB         = 'obsidian_destroyer_arcane_orb'
local OBJURGATION = 'obsidian_destroyer_objurgation'
local SANITY      = 'obsidian_destroyer_sanity_eclipse'
local SHIPPED_TABLE = 'tAllAbilityBuildList'
local GATED_TABLE   = 'tObjurgationBuildList'

-- GH #330's W28 readings, recorded so a later edit that moves a number below has
-- to say which corpus it is now describing.  `.dem`-backed, 10 OD hero-games,
-- 7 stamped; zero EC2.
local W28 = {
    baseline_ability_points = 6,   -- pts_abil, all four baseline legs
    baseline_talent_points  = 0,   -- pts_talent
    baseline_last_level     = 7,   -- last point spent at t=289.5, hero level 7
    baseline_objurgation    = 0,
    third_point_astral_rank = 2,   -- t=69.5, hero level 3, "第 3 点 -> astral:2"
    armed_third_point       = OBJURGATION, -- same second, same level, armed leg
    armed_total_points      = 16,  -- at t=1240.5, hero level 25
    armed_ranks = { [ORB] = 4, [ASTRAL] = 4, [OBJURGATION] = 4, [SANITY] = 3 },
}

-- The game's standard ladder.  Index = rank.  See "WHAT IS NOT CLAIMED".
local REQ_BASIC  = { 1, 3, 5, 7 }
local REQ_ULT    = { 6, 12, 18 }
local TIER_LEVEL = { 10, 15, 20, 25 }
local MAX_LEVEL  = 25

local SRC     = skillmap.read_file(SOURCE)
local SPEND_SRC = skillmap.read_file(SPENDER)
local SLOTS   = dofile(SLOTS_LUA)
local ULTS    = meta.ULTIMATES[UNIT] or {}

local function is_talent(sName)
    return sName ~= nil and sName:match('^special_bonus') ~= nil
end

--- A bot serving OD's real KV slot order to the shipped walk.  Same construction
--- as tests/test_od_build_objurgation.lua's slot_bot: empty slots hold the
--- placeholder, exactly as the engine reports them.
local function slot_bot()
    return api.MakeUnit{
        GetUnitName = UNIT,
        GetAbilityInSlot = function(_, nSlot)
            local sName = SLOTS[HERO][nSlot]
            if sName == nil or sName == '' then sName = PLACEHOLDER end
            return api.MakeUnit{
                GetName     = sName,
                IsUltimate  = ULTS[sName] == true,
                IsTalent    = is_talent(sName),
                IsHidden    = false,
                GetBehavior = 0,
            }
        end,
    }
end

--- The level-ordered queue the bot actually spends, built by the SHIPPED
--- J.Skill.GetSkillList off the SHIPPED build row -- the row index is not the
--- hero level (GH #134), so it is driven rather than counted.
local function queue_for(J, sTable)
    local tRow = skillmap.build_row(SRC, 1, sTable)
    local tAbil = J.Skill.GetAbilityList(slot_bot())
    local tTalentNames = {}
    for i = 1, 8 do tTalentNames[i] = 'special_bonus_' .. i end
    local tTalentBuild = J.Skill.GetTalentBuild(skillmap.talent_rows(SRC))
    return J.Skill.GetSkillList(tAbil, tRow, tTalentNames, tTalentBuild), tRow, tAbil
end

local function max_rank(sName) return ULTS[sName] and 3 or 4 end
local function req_of(sName)   return ULTS[sName] and REQ_ULT or REQ_BASIC end

--- The SHIPPED spender's semantics, level by level.  One ability point per hero
--- level; the function runs every frame, so a level drains as many heads as it
--- can before it stops making progress.
---
--- `bPopOnMaxed` is the one branch offline code cannot decide: when the head is
--- already at max rank, `botLevel >= GetHeroLevelRequiredToUpgrade()` decides
--- between the "still try it" branch (pops the head, engine no-ops, point NOT
--- consumed) and the final `else` (parks the head, pops only above level 25).
--- Both worlds are driven; §4 shows the corpus picks one.
---
--- `bDoubleSpend` switches the placeholder handling between the shipped branch
--- (level list[2] without popping it) and the 1:1 model the prose used to
--- assume (the point is simply wasted).  §5 is the difference between them.
--- `nStopAtLevel` runs only the first N hero levels, for reading a single
--- recorded instant (GH #330's divergence frame is hero level 3).
local function spend(tQueue, bPopOnMaxed, bDoubleSpend, nStopAtLevel)
    local tList = {}
    for i = 1, #tQueue do tList[i] = tQueue[i] end

    local tRanks, nSpent, nTalents, nLastLevel = {}, 0, 0, 0
    local nPoints = 0

    --- Engine-side legality of one level-up request.  Returns true if the rank
    --- was granted (and therefore a point consumed).
    local function grant(sName, nLevel)
        if sName == nil or is_talent(sName) or sName == PLACEHOLDER then return false end
        local nRank = tRanks[sName] or 0
        if nRank >= max_rank(sName) then return false end
        if nLevel < req_of(sName)[nRank + 1] then return false end
        tRanks[sName] = nRank + 1
        return true
    end

    for nLevel = 1, (nStopAtLevel or MAX_LEVEL) do
        nPoints = nPoints + 1
        local bProgress = true
        while bProgress and nPoints > 0 and #tList > 0 do
            bProgress = false
            local sHead = tList[1]

            if sHead == PLACEHOLDER then
                if bDoubleSpend then
                    -- the shipped branch: pop the HEAD, level list[2] in place
                    local sNext = tList[2]
                    table.remove(tList, 1)
                    bProgress = true
                    if grant(sNext, nLevel) then
                        nPoints, nSpent, nLastLevel = nPoints - 1, nSpent + 1, nLevel
                    end
                else
                    -- the 1:1 model: one entry, one point, nothing learned
                    table.remove(tList, 1)
                    nPoints, nSpent, nLastLevel = nPoints - 1, nSpent + 1, nLevel
                    bProgress = true
                end

            elseif is_talent(sHead) then
                local nTier = TIER_LEVEL[nTalents + 1]
                if nTier ~= nil and nLevel >= nTier then
                    nTalents = nTalents + 1
                    table.remove(tList, 1)
                    nPoints, nSpent, nLastLevel = nPoints - 1, nSpent + 1, nLevel
                    bProgress = true
                end

            elseif grant(sHead, nLevel) then
                table.remove(tList, 1)
                nPoints, nSpent, nLastLevel = nPoints - 1, nSpent + 1, nLevel
                bProgress = true

            elseif (tRanks[sHead] or 0) >= max_rank(sHead) and bPopOnMaxed then
                table.remove(tList, 1)   -- point NOT consumed: the engine no-ops
                bProgress = true
            end
            -- otherwise: parked.  No pop (the pop is guarded by botLevel > 25),
            -- no spend, and every point behind it parks too.
        end
    end

    return {
        ranks       = tRanks,
        spent       = nSpent,
        talents     = nTalents,
        last_level  = nLastLevel,
        head        = tList[1],
        unspent     = nPoints,
    }
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The double-spend, pinned in the source it is read from.

tests['[ratchet] [1] the generic_hidden branch levels list[2] without popping it'] = function()
    local sBranch = SPEND_SRC:match(
        "elseif abilityName == 'generic_hidden' then(.-)\n\t\telseif")
    assert(sBranch ~= nil,
        SPENDER .. ' no longer has an `elseif abilityName == \'generic_hidden\'` branch '
            .. 'closed by another elseif. Every number in this file is that branch\'s '
            .. 'arithmetic -- re-derive before editing the assertions.')

    assert(sBranch:find('sAbilityLevelUpList%[2%]') ~= nil,
        'the branch no longer reads sAbilityLevelUpList[2]. It is the SECOND entry '
            .. 'being levelled -- while the FIRST is the one popped -- that makes this '
            .. 'a double spend rather than a wasted point.')

    local nPops = 0
    for _ in sBranch:gmatch('table%.remove') do nPops = nPops + 1 end
    assert(nPops == 1,
        'the generic_hidden branch performs ' .. nPops .. ' table.remove calls, '
            .. 'expected exactly 1. A SECOND pop would remove the entry it just '
            .. 'levelled, the queue would stay in sync, and OD would not jam -- which '
            .. 'is a fix, not a test failure: re-read GH #330 and rewrite this file.')

    assert(sBranch:find('ActionImmediate_LevelAbility%(nextAbility%)') ~= nil,
        'the branch no longer levels `nextAbility` directly. The rank it grants '
            .. 'without consuming the queue entry is the whole mechanism.')

    -- The branch issues its level-up without asking whether the rank is legal at
    -- this hero level; the engine is the only thing that refuses.  Recorded
    -- because `grant()` above models exactly that.
    assert(sBranch:find('GetHeroLevelRequiredToUpgrade') == nil
       and sBranch:find('CanAbilityBeUpgraded') == nil,
        'the generic_hidden branch now checks legality itself. The model in this '
            .. 'file assumes only the engine refuses -- update spend() first.')
end

-- ---------------------------------------------------------------------------
-- 2. The park, pinned the same way.  Same shape tests/test_focus_build_level
--    _legality.lua:104 pins; asserted here too because §4's whole disjunction
--    is about which side of it an over-rank head falls on.

tests['[ratchet] [2] an untakeable head parks: the final else pops only above 25'] = function()
    local sTail = SPEND_SRC:match(
        'print%("%[WARN%] Skipped to level up ability "(.-)\n\tend')
    assert(sTail ~= nil,
        SPENDER .. '\'s final else branch was not found by its own warning text. '
            .. 'That branch is what turns one over-rank request into a permanent '
            .. 'stall -- find it and re-read before trusting anything below.')
    assert(sTail:find('table%.remove') ~= nil,
        'the final else no longer pops at all')
    assert(sTail:find('if botLevel > 25') ~= nil,
        'the final else pops without the `botLevel > 25` guard. An untakeable head '
            .. 'would then be SKIPPED, not parked, and the six-point reading in §4 '
            .. 'stops being what the code does.')

    -- ...and the branch above it is what decides which way a max-rank head goes.
    assert(SPEND_SRC:find('abilityToLevelup:GetLevel%(%) < abilityToLevelup:GetMaxLevel%(%)') ~= nil,
        'the training branch no longer compares GetLevel() to GetMaxLevel(). That '
            .. 'comparison is what makes a maxed head fall through to §4\'s disjunction.')
end

-- ---------------------------------------------------------------------------
-- 3. The queue itself, driven off the shipped row.

tests['[ratchet] [3] the shipped queue puts the placeholder third and objurgation nowhere'] = function()
    local J = rf.load(FRAME)
    local tQueue, tRow, tAbil = queue_for(J, SHIPPED_TABLE)

    assert(tAbil[3] == OBJURGATION and tAbil[4] == PLACEHOLDER,
        'sAbilityList is [3]=' .. tostring(tAbil[3]) .. ' [4]=' .. tostring(tAbil[4])
            .. ', expected objurgation and the placeholder. If the walk moved, the '
            .. 'row arithmetic below aims somewhere else.')

    assert(tQueue[3] == PLACEHOLDER,
        'the shipped queue\'s third entry is ' .. tostring(tQueue[3])
            .. ', expected ' .. PLACEHOLDER .. '. GH #330\'s divergence frame is the '
            .. 'THIRD point (t=69.5/69.4/77.4, all at hero level 3) precisely because '
            .. 'that is where the two rows first differ.')

    local nRefs = 0
    for _, n in ipairs(tRow) do if n == 4 then nRefs = nRefs + 1 end end
    assert(nRefs == 4, 'the shipped row names index 4 ' .. nRefs .. ' times, recorded 4')

    local bSeen = false
    for i = 1, #tQueue do if tQueue[i] == OBJURGATION then bSeen = true end end
    assert(not bSeen,
        'the shipped queue now contains objurgation. That is the defect being fixed, '
            .. 'so if it is gone the row was edited -- say so and retire this file.')
end

-- ---------------------------------------------------------------------------
-- 4. ⭐ The reading: the shipped queue stops at six points, at hero level 7.

tests['[ratchet] [4] shipped + park reproduces W28 exactly: 6 points, level 7, frozen'] = function()
    local J = rf.load(FRAME)
    local tQueue = queue_for(J, SHIPPED_TABLE)

    local tPark = spend(tQueue, false, true)
    assert(tPark.spent == W28.baseline_ability_points + W28.baseline_talent_points,
        'the shipped queue spends ' .. tPark.spent .. ' points; W28 read '
            .. W28.baseline_ability_points .. ' ability + ' .. W28.baseline_talent_points
            .. ' talent across 4 of 4 baseline legs. A model that does not land on the '
            .. 'corpus number is not describing the shipped spender.')
    assert(tPark.talents == W28.baseline_talent_points,
        'the model spends ' .. tPark.talents .. ' talent points; W28 read '
            .. W28.baseline_talent_points .. '. The first talent sits at queue '
            .. 'position 10 and the jam is at 7, which is why it is zero and not few.')
    assert(tPark.last_level == W28.baseline_last_level,
        'the model\'s last spend is at hero level ' .. tPark.last_level
            .. '; W28 read level ' .. W28.baseline_last_level .. ' (t=289.5). Two '
            .. 'independent numbers -- points AND level -- and both have to match.')
    assert((tPark.ranks[OBJURGATION] or 0) == W28.baseline_objurgation,
        'objurgation reaches rank ' .. tostring(tPark.ranks[OBJURGATION])
            .. ' on the shipped queue, W28 read ' .. W28.baseline_objurgation)
    assert(tPark.head == ASTRAL and tPark.ranks[ASTRAL] == 4,
        'the jam parks on ' .. tostring(tPark.head) .. ' at rank '
            .. tostring(tPark.ranks[ASTRAL]) .. '; recorded: astral, already at its max '
            .. 'rank 4. The fifth astral request is the desync the double spend caused.')

    -- The third point is the frame that proves the branch RAN.
    local tThird = spend(tQueue, false, true, 3)
    assert(tThird.spent == 3,
        'by hero level 3 the shipped queue has spent ' .. tThird.spent
            .. ' points, expected 3 -- W28\'s divergence frame is "the third point"')
    assert(tThird.ranks[ASTRAL] == W28.third_point_astral_rank,
        'at hero level 3 astral holds rank ' .. tostring(tThird.ranks[ASTRAL])
            .. '; W28 read rank ' .. W28.third_point_astral_rank .. ' on the THIRD '
            .. 'point (t=69.5). The 1:1 model gives rank 1 there -- see §5. This is '
            .. 'the frame that settles that the engine does hand back a handle for '
            .. 'the placeholder, which the shipped comment called unreadable offline.')

    local tThirdNaive = spend(tQueue, false, false, 3)
    assert(tThirdNaive.ranks[ASTRAL] == 1,
        'the 1:1 model now puts astral at rank ' .. tostring(tThirdNaive.ranks[ASTRAL])
            .. ' by level 3 as well, so the frame stops discriminating between the two '
            .. 'and the paragraph above over-claims')
end

tests['[ratchet] [4b] the pop-on-maxed world does NOT reproduce the corpus'] = function()
    local J = rf.load(FRAME)
    local tQueue = queue_for(J, SHIPPED_TABLE)

    local tPop = spend(tQueue, true, true)
    assert(tPop.spent ~= W28.baseline_ability_points,
        'the pop-on-maxed world now also lands on ' .. W28.baseline_ability_points
            .. ' points. The two worlds have stopped being distinguishable, so the '
            .. 'corpus no longer decides between them and §4 is over-claiming.')
    assert(tPop.spent > W28.baseline_ability_points and tPop.last_level > W28.baseline_last_level,
        'recorded: popping an over-rank head keeps the hero levelling (' .. tPop.spent
            .. ' points, last spend at level ' .. tPop.last_level .. ') instead of '
            .. 'freezing it. That is the world the corpus rules out.')
end

-- ---------------------------------------------------------------------------
-- 5. ⭐ The 1:1 model -- what the source comment used to assume -- is not just
--    imprecise, it predicts a hero that never stalls at all.

tests['[ratchet] [5] the "one entry, one wasted point" model predicts no stall'] = function()
    local J = rf.load(FRAME)
    local tQueue = queue_for(J, SHIPPED_TABLE)

    local tNaive = spend(tQueue, false, false)
    assert(tNaive.spent > W28.baseline_ability_points,
        'the 1:1 model spends ' .. tNaive.spent .. ' points, the shipped spender '
            .. W28.baseline_ability_points .. '. If these ever agree, the double spend '
            .. 'stopped mattering and the correction in ' .. SOURCE .. ' should be '
            .. 're-read, not this assertion relaxed.')
    assert(tNaive.last_level > W28.baseline_last_level,
        'under the 1:1 model OD is still spending points at level '
            .. tNaive.last_level .. ' -- i.e. it predicts a hero with a rank-0 '
            .. 'objurgation and nothing else wrong. That prediction is what W28 '
            .. 'falsified, and it is the half of the shipped comment being corrected.')
    assert((tNaive.ranks[OBJURGATION] or 0) == 0,
        'both models agree objurgation never trains -- that part of the old comment '
            .. 'was right and is not being withdrawn')
end

-- ---------------------------------------------------------------------------
-- 6. The armed row: no placeholder, so no double spend, so no jam.

tests['[ratchet] [6] odbuild trains the whole row and is identical in both worlds'] = function()
    local J = rf.load(FRAME)
    local tQueue, tRow = queue_for(J, GATED_TABLE)

    for _, n in ipairs(tRow) do
        assert(n ~= 4,
            'the gated row names index 4 (the placeholder). It is the ABSENCE of any '
                .. 'index-4 reference that removes the double spend -- if the row '
                .. 'gained one, this file\'s conclusion about it is void.')
    end

    local tPark = spend(tQueue, false, true)
    local tPop  = spend(tQueue, true, true)
    assert(tPark.spent == tPop.spent and tPark.last_level == tPop.last_level,
        'the two worlds disagree on the armed queue (' .. tPark.spent .. ' vs '
            .. tPop.spent .. ' points). With no placeholder the queue never '
            .. 'desynchronises, so no head is ever over-rank and the disjunction of '
            .. '§4 cannot even be reached. If they differ, it can.')

    for sName, nRank in pairs(W28.armed_ranks) do
        assert(tPark.ranks[sName] == nRank,
            'armed leg: ' .. sName .. ' reaches rank ' .. tostring(tPark.ranks[sName])
                .. ', W28 read ' .. nRank .. ' (orb:4 astral:4 objurgation:4 sanity:3)')
    end

    -- PROMOTED 2026-09-06 (director, stable-v4). This assertion used to demand
    -- the gate `IsModeTurbo() and IsSoakCandidate('odbuild')`; the gate was
    -- removed ON PURPOSE, which is the exit the sentence it replaces named. What
    -- it now pins is the promoted shape, and the id's ABSENCE is the
    -- load-bearing half: a promoted row that quietly grows a gate again is inert
    -- in every real game while every armed-wiring check still reads clean
    -- (AGENTS.md calls that the pullcad trap). The readings above are now about
    -- the row every turbo game runs.
    assert(SRC:find('if J.IsModeTurbo%(%) then') ~= nil,
        SOURCE .. ' no longer selects the objurgation row on IsModeTurbo() alone')
    assert(SRC:find("IsSoakCandidate%(%s*'odbuild'%s*%)") == nil,
        SOURCE .. " still names the soak candidate 'odbuild'; PROMOTED means the "
            .. 'gate is gone, not renamed')
end

-- ---------------------------------------------------------------------------
-- 7. ⚠️ The residual, recorded rather than tuned away.

tests['[ratchet] [7] the armed leg loses talent points this file does NOT explain'] = function()
    local J = rf.load(FRAME)
    local tQueue = queue_for(J, GATED_TABLE)
    local tPark = spend(tQueue, false, true)

    assert(tPark.spent > W28.armed_total_points,
        'the model now predicts ' .. tPark.spent .. ' armed points and W28 read '
            .. W28.armed_total_points .. '. If the model has come DOWN to the corpus '
            .. 'number the second defect is gone -- check what changed and retire this '
            .. 'section instead of loosening it.')

    local nAbility = 0
    for sName, nRank in pairs(tPark.ranks) do
        if not is_talent(sName) then nAbility = nAbility + nRank end
    end
    assert(nAbility == 15,
        'the armed queue trains ' .. nAbility .. ' ability ranks, recorded 15 (4+4+4+3). '
            .. 'W28 read the same 15 -- the ability half of the model and the corpus '
            .. 'agree exactly.')

    local nGap = tPark.spent - W28.armed_total_points
    assert(nGap == tPark.talents - 1,
        'the whole model/corpus gap on the armed leg is ' .. nGap .. ' point(s) but the '
            .. 'model spends ' .. tPark.talents .. ' talents against W28\'s 1, so the gap '
            .. 'is no longer purely talent-side. That would make it a NEW finding: say '
            .. 'what it is rather than adjusting the number.')

    -- Recorded, and handed on: a leg with no placeholder in it still freezes 5-24%
    -- of the game (GH #330).  `odbuild` does not touch that, and neither does this
    -- file; the talent-side stall is its own defect (same family as
    -- tests/test_lion_hex_talent_slot.lua and GH #134).
end

return tests
