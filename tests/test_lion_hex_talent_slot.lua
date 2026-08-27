-- [hero] GH #166 -- a talent HANDLE that names the wrong half of its own t25
-- row, and the census that resolves talent slots so the next one is caught.
-- Behaviour change, so it ships GATED ('lionhexaoe', turbo-only).
--
-- WHAT WAS FOUND
--
-- `aba_skill.X.GetTalentList` walks `bot:GetAbilityInSlot(0..25)` and appends
-- every `IsTalent()` ability in slot order, so `sTalentList[N]` means "the Nth
-- talent row entry the game ships for this hero" -- 1 = t10 left, 2 = t10 right,
-- ... 8 = t25 right.  WHICH talent that is, is Valve's to change.
--
-- hero_lion.lua binds `talent8 = bot:GetAbilityByName( sTalentList[8] )` and
-- then reads it fifteen times to decide things about lion_voodoo (Hex): whether
-- to pick an AoE location, and whether the cast-legality check may be skipped.
-- Slot 8 today is `special_bonus_unique_lion_2`, and the game's own KV lists it
-- as an override on `lion_impale / AbilityValues / AbilityCastRange = +600`.  It
-- does not touch lion_voodoo at all.  The talent that gives Hex a radius is
-- `special_bonus_unique_lion_4` (`lion_voodoo / radius = +250`) and it is slot
-- **7** -- the other half of the same row.
--
-- This is not a dormant mismatch.  hero_lion.lua's own tTalentTreeList has
-- `['t25'] = {10, 0}`, which J.Skill.GetTalentBuild turns into index 4 = 8: the
-- shipped build trains exactly the half that makes those fifteen reads answer
-- true.  Section 2 reads that out of the file rather than restating it.
--
-- Two consequences, and only the first needs the engine:
--
--   * X.SkillsComplement swaps ActionQueue_UseAbilityOnEntity for
--     ActionQueue_UseAbilityOnLocation, while lion_voodoo's AbilityBehavior is
--     DOTA_ABILITY_BEHAVIOR_UNIT_TARGET with no talent override anywhere in the
--     KV.  A location order for a unit-target ability: what the engine actually
--     does with it cannot be settled offline (AGENTS.md -- print() never reaches
--     the server console and the error handler is broken), so it is written up
--     as a RISK, never as a measured no-op.
--   * `( J.CanCastOnTargetAdvanced( x ) or talent8:IsTrained() )` drops the
--     cast-legality check on the same false premise.  That half needs no engine
--     reading: Hex is unit-targeted under either talent, so there is never a
--     reason to skip it.
--
-- Same family as GH #162 (a renamed KV key read as if current), GH #137 and
-- GH #115/#104: a clause that reads true-looking but is anchored to a patch that
-- has moved.  The difference is where the drift lives -- not in a key NAME but
-- in a ROW POSITION, which no key census can see.
--
-- THE CENSUS BEHIND IT (tools/agent/talent_slot_census.py -> tests/mock/talent_slots.lua)
--
-- Two sources joined.  Slot ORDER from odota `dotaconstants build/hero_abilities.json`
-- (`talents[]`), the source GH #150 already used to price
-- special_bonus_unique_wraith_king_facet_3.  WHAT EACH TALENT DOES from the
-- game's `npc_dota_hero_<name>.txt` on the d2vpkr mirror, where a talent appears
-- as an override key inside the AbilityValues block it modifies.
--
-- The join is ONE-DIRECTIONAL, the same discipline as the key census and the
-- boots supply census:
--
--   * a non-empty `mods` list is a PROOF of what that talent modifies;
--   * an EMPTY `mods` list proves NOTHING.  Generic rows (special_bonus_hp_200,
--     special_bonus_intelligence_12) and facet rows live in npc_abilities.txt,
--     which the census does not read.  So section 1 is written as "slot 8 is
--     proven to modify lion_impale", never as "slot 8 is proven not to touch
--     Hex by omission" -- the proof runs through what slot 7 IS.
--
-- WHY THE ORDERING IS NOT TAKEN ON FAITH FROM ONE FEED (section 5)
--
-- Three claims already standing in this tree, written by three earlier passes
-- from a different source (the dota2.com datafeed), agree with the snapshot
-- slot for slot: hero_axe.lua's own binding comment (7 = special_bonus_unique_axe_2,
-- +Berserker's Call AoE), hero_zuus.lua's FACT block (5 = special_bonus_unique_zeus_2,
-- arc lightning, and 3 = the ult-damage talent) and GH #150 (6 =
-- special_bonus_unique_wraith_king_facet_3).  Section 5 asserts the agreement, so
-- a feed that reshuffles turns this file red rather than silently re-anchoring it.
--
-- THE SHAPE OF THE CHANGE (why gate-off equivalence is structural)
--
-- X.IsHexAoe runs the SHIPPED read FIRST and the only thing the armed path can
-- add is `return false`.  So it is a NARROWING gate whose gate-off path is the
-- shipped path by construction, not by measurement -- the dual of the widening
-- shape GH #154 wrote down, and the same lesson as GH #165 ("armed may only take
-- the min"): the direction of a gate is carried by the shape of the code, not by
-- today's constants.  Section 3 drives all five combinations.
--
-- ⚠️ LIMIT -- THE DOMAIN IS OUT OF REACH TODAY, AND THAT IS MEASURED (section 6)
--
-- Every read here is downstream of a level-25 talent.  GH #84 measured
-- `level >= 20` on 0 of 210 hero-slots (high-water 19) under SOAK_CAP_MIN=10,
-- and section 6 re-measures the same thing on this repo's fixture corpus rather
-- than citing it.  So: NOT armed, NOT proposed for the test set, and NO queue
-- request -- the same disposition GH #165 took for `alchrage`, and for the same
-- reason (an empty domain cannot buy condition (a) no matter how many games run).
-- Section 6 is written so that it goes RED when the corpus first contains a
-- level-25 hero, which is the moment this becomes proposable.
--
-- A GREEN RUN HERE IS NOT EVIDENCE THE GUARD IS UNNECESSARY.  The mock's talent
-- slots are empty (tests/mock/bot_api.lua returns nil for slot > 5), so the real
-- frames in tests/fixtures/ cannot exercise the true branch at all; section 3
-- drives it with a synthetic talent ladder and says so.
--
-- WHAT WAS ALSO CLOSED HERE
--
-- tests/test_focus_talent_anchor.lua pins t10/t15 and deliberately RECORDS
-- t20/t25 without pinning them, because GH #84 makes them dead rows in turbo.
-- That reasoning is about which talent the build COLLECTS; it says nothing about
-- a t25 row that a HANDLE reads.  This finding lived exactly in that gap, so the
-- t25 pair is pinned here for the second reason, not the first.
--
-- MUTATION RECORD (12 run, 11 caught, 1 no-op control escaped as designed)
--   M1  armed branch `return false` -> `return true`                    CAUGHT (2 cases)
--   M2  every call site reverted to a raw `talent8:IsTrained()`         CAUGHT (1 case)
--   M3  tTalentTreeList['t25'] {10,0} -> {0,10}                         CAUGHT (1 case)
--   M4  gate loses its J.IsModeTurbo() conjunct                         CAUGHT (2 cases)
--   M5  candidate id renamed 'lionhexaoe' -> 'lionhexaoez'              CAUGHT (3 cases)
--   M6  snapshot: lion slots 7 and 8 swapped                            CAUGHT (1 case)
--   M7  snapshot: lion slot 8's only `mods` entry deleted               CAUGHT (1 case)
--   M8  snapshot: lion slot 8 removed entirely                          CAUGHT (2 cases)
--   M9  snapshot: axe slot 7 renamed (the cross-check source moves)     CAUGHT (1 case)
--   M10 helper drops `not talent8:IsTrained()` (widening)               CAUGHT (2 cases)
--   M11 a synthetic level-25 fixture added to the corpus                CAUGHT (1 case)
--   M12 a comment line added above X.IsHexAoe (no-op control)           ESCAPED

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')

local SRC      = 'bots/BotLib/hero_lion.lua'
local SNAPSHOT = 'tests/mock/talent_slots.lua'
local CAND_ID  = 'lionhexaoe'

-- The two halves of Lion's t25 row, and what the game says each one modifies.
local HEX_TALENT    = 'special_bonus_unique_lion_4'
local IMPALE_TALENT = 'special_bonus_unique_lion_2'
local HEX_ABILITY   = 'lion_voodoo'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE anything is counted.  The reasoning block in
--- hero_lion.lua quotes `talent8:IsTrained()` while explaining it, and a parser
--- that reads prose reports the prose (the mistake GH #136's first census made).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Does any entry of a snapshot slot's `mods` name this ability?
local function modifies(tSlot, sAbility)
    for _, s in ipairs(tSlot.mods) do
        if s:sub(1, #sAbility + 1) == sAbility .. '/' then return true end
    end
    return false
end

--- Load hero_lion.lua under a synthetic talent ladder.
---
--- The mock leaves ability slots > 5 empty, so sTalentList is normally EMPTY and
--- talent8 resolves to the shared untrained stub -- the true branch would be
--- unreachable.  Slots 10..17 are filled here with IsTalent() handles so the
--- ladder exists at all; only that makes section 3 a drive rather than a read.
local function load_lion(bTrained8, bTurbo, bArmed)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    local realSlot = bot.GetAbilityInSlot
    bot.GetAbilityInSlot = function(self, slot)
        if slot >= 10 and slot <= 17 then
            local nIdx = slot - 9
            local hAbility = self:GetAbilityByName('special_bonus_probe_' .. nIdx)
            hAbility.IsTalent = function() return true end
            hAbility.IsTrained = function() return nIdx == 8 and bTrained8 or false end
            return hAbility
        end
        return realSlot(self, slot)
    end
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    J.IsModeTurbo = function() return bTurbo end
    J.IsSoakCandidate = function(sId) return bArmed and sId == CAND_ID end
    local ok, X = pcall(dofile, SRC)
    if not ok then error('loading ' .. SRC .. ' failed: ' .. tostring(X)) end
    return X
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The finding itself, read out of the generated snapshot.

tests['[hero] lion t25: slot 8 modifies Earth Spike, slot 7 is the Hex one'] = function()
    api.install({})
    local tLion = assert(dofile(SNAPSHOT).SLOTS['lion'], 'no talent snapshot for lion')

    assert(tLion[8] ~= nil and tLion[7] ~= nil, 'lion snapshot is missing the t25 pair')
    assert(tLion[8].name == IMPALE_TALENT,
        'sTalentList[8] is ' .. tostring(tLion[8].name) .. ', not ' .. IMPALE_TALENT
        .. ' -- the row moved, so re-read hero_lion.lua`s talent8 binding before trusting it')
    assert(tLion[7].name == HEX_TALENT,
        'sTalentList[7] is ' .. tostring(tLion[7].name) .. ', not ' .. HEX_TALENT)

    -- The PROOF direction: what each one is shown to modify.
    assert(modifies(tLion[7], HEX_ABILITY),
        HEX_TALENT .. ' no longer modifies ' .. HEX_ABILITY .. ' in the hero KV; '
        .. 'the whole finding rests on it being the Hex talent')
    assert(modifies(tLion[8], 'lion_impale'),
        IMPALE_TALENT .. ' no longer modifies lion_impale in the hero KV')

    -- And the mismatch that hero_lion.lua's fifteen reads sat on.  Stated as
    -- "what slot 8 IS", not as "what its mods list omits" -- an empty mods list
    -- would prove nothing (see the header), so lean on the non-empty one.
    assert(#tLion[8].mods > 0, 'slot 8 has no proven effect at all; the census '
        .. 'cannot support the claim that it is the wrong handle')
    assert(not modifies(tLion[8], HEX_ABILITY),
        'slot 8 now modifies ' .. HEX_ABILITY .. ' too -- the handle hero_lion.lua '
        .. 'binds would no longer be the wrong one, so re-open GH #166')
end

-- ---------------------------------------------------------------------------
-- 2. ...and this build NO LONGER trains it.  Read out of the file, never restated.
--
-- CHANGED 2026-08-27.  This case used to assert index 8 -- the half that makes
-- every `talent8` read answer true -- and its failure message said "if it now
-- takes 7 the shipped reads would name the RIGHT talent and the gate has nothing
-- left to narrow".  That is exactly what happened, and it happened on purpose:
-- the t25 row was re-priced to {0, 10} = [7], the real +250 Hex radius, on the
-- three grounds recorded in hero_lion.lua's t25 block (marquee talent; worth more
-- to a bot, since Hex is UNIT_TARGET and needs no aiming while Earth Spike is a
-- led line skillshot; and it removes this issue's defect BY CONSTRUCTION).
-- The assertion is inverted rather than deleted, because the thing worth pinning
-- did not change -- it is still "which half of the t25 row does the shipped build
-- train", and it must still self-report if anyone moves it back.
-- The gate in X.IsHexAoe is deliberately KEPT (section 3 still drives it): one
-- talent per tier makes `talent8` structurally untrained TODAY, but neither the
-- row nor Valve's slot order is hero_lion.lua's to guarantee.

tests['[hero] lion`s own t25 row selects sTalentList index 7, not 8'] = function()
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_lion') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    local fnReal, tCaptured = J.Skill.GetTalentBuild, nil
    J.Skill.GetTalentBuild = function(cfg) tCaptured = cfg; return fnReal(cfg) end
    local ok, err = pcall(dofile, SRC)
    J.Skill.GetTalentBuild = fnReal
    if not ok then error('loading ' .. SRC .. ' failed: ' .. tostring(err)) end

    assert(type(tCaptured) == 'table' and type(tCaptured.t25) == 'table',
        'hero_lion.lua no longer routes its talent tree through J.Skill.GetTalentBuild, '
        .. 'so which t25 index it takes cannot be read this way any more')

    local tPicks = fnReal(tCaptured)
    assert(tPicks[4] == 7, 'this build takes sTalentList index ' .. tostring(tPicks[4])
        .. ' at t25, not 7. Index 7 is special_bonus_unique_lion_4 (+250 Hex '
        .. 'radius), chosen 2026-08-27. If this reads 8 again, the build is back on '
        .. 'special_bonus_unique_lion_2 (+600 Earth Spike cast range) and every '
        .. '`talent8` read in hero_lion.lua goes live from level 25 believing it '
        .. 'means "Hex is an area spell now" -- see GH #166.')

    -- The other half of the same statement, and the one that makes the gate's
    -- domain structural rather than corpus-measured: a hero trains ONE talent per
    -- tier, so picking 7 at t25 is what makes talent8 unreachable. Pin the pair,
    -- not just the winner, so a build that somehow took both would not read green.
    assert(tPicks[8] == 8, 'the t25 pair no longer resolves to {7, 8}; '
        .. 'tPicks[4]=' .. tostring(tPicks[4]) .. ' tPicks[8]=' .. tostring(tPicks[8])
        .. '. Index 4 is the trained pick and index 8 the abandoned half of the '
        .. 'same row, so "talent8 is structurally untrained" is only true while '
        .. 'these two are the two halves of one tier.')
end

-- ---------------------------------------------------------------------------
-- 3. The gate, driven.  Five combinations, not a source read.

tests['[hero] X.IsHexAoe: gate-off is exactly the shipped read'] = function()
    assert(load_lion(false, false, false).IsHexAoe() == false,
        'untrained talent must answer false with the gate off')
    assert(load_lion(true, false, false).IsHexAoe() == true,
        'gate off, trained talent: must reproduce the shipped `talent8:IsTrained()`')
    assert(load_lion(true, true, false).IsHexAoe() == true,
        'turbo but NOT armed must still be the shipped answer')
    assert(load_lion(true, false, true).IsHexAoe() == true,
        'armed but NOT turbo must still be the shipped answer (turbo-only gate)')
end

tests['[hero] X.IsHexAoe: armed in turbo narrows the trained case to false'] = function()
    assert(load_lion(true, true, true).IsHexAoe() == false,
        'armed in turbo must answer false, which is the whole change')
    -- ...and narrowing only.  There is no input on which arming ADDS a true.
    assert(load_lion(false, true, true).IsHexAoe() == false,
        'arming must never manufacture an AoE Hex out of an untrained talent')
end

tests['[hero] X.IsHexAoe answers only under the candidate id it claims'] = function()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    local realSlot = bot.GetAbilityInSlot
    bot.GetAbilityInSlot = function(self, slot)
        if slot >= 10 and slot <= 17 then
            local h = self:GetAbilityByName('special_bonus_probe_' .. (slot - 9))
            h.IsTalent = function() return true end
            h.IsTrained = function() return true end
            return h
        end
        return realSlot(self, slot)
    end
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    J.IsModeTurbo = function() return true end
    local tAsked = {}
    J.IsSoakCandidate = function(sId) tAsked[sId] = true; return false end
    local ok, X = pcall(dofile, SRC)
    if not ok then error('loading ' .. SRC .. ' failed: ' .. tostring(X)) end

    tAsked = {}
    assert(X.IsHexAoe() == true, 'nothing armed: shipped answer')
    assert(tAsked[CAND_ID], 'X.IsHexAoe never asked about `' .. CAND_ID
        .. '`; the gate is not wired to the id this file and state.json register')
end

-- ---------------------------------------------------------------------------
-- 4. Every consumer goes through the helper.
--
-- Section 3 can only speak for the helper's own arithmetic.  A call site that
-- still reads the handle raw would be untouched by the gate and invisible to
-- every assertion above -- the escape route GH #144's M7 took.

tests['[hero] no raw talent8 read survives outside X.IsHexAoe'] = function()
    local sSrc = strip_comments(read_file(SRC))

    local nRaw = 0
    for _ in sSrc:gmatch('talent8:IsTrained%(%)') do nRaw = nRaw + 1 end
    assert(nRaw == 1, 'expected exactly one `talent8:IsTrained()` in live code (the '
        .. 'one inside X.IsHexAoe), found ' .. nRaw)

    -- ...and it is the one inside the helper: nothing else may name the handle.
    local sBody = sSrc:match('function X%.IsHexAoe%(%)(.-)\nend')
    assert(sBody ~= nil, 'X.IsHexAoe is gone; the call sites have nowhere to route through')
    assert(sBody:find('talent8:IsTrained%(%)') ~= nil,
        'the single raw read is NOT inside X.IsHexAoe -- so some call site kept it')

    local nCalls = 0
    for _ in sSrc:gmatch('X%.IsHexAoe%(%)') do nCalls = nCalls + 1 end
    assert(nCalls >= 15, 'only ' .. nCalls .. ' call sites route through X.IsHexAoe; '
        .. 'the shipped file had fifteen `talent8:IsTrained()` reads, so some were dropped '
        .. 'rather than routed')

    -- ADDED 2026-08-27, and it is not decoration.  With the t25 row on [7],
    -- `talent8` is structurally untrained, so EVERY assertion in sections 3 and 4
    -- now runs on a handle no shipped game will ever train.  A later reader who
    -- notices that has one obvious cheap move -- delete the helper and the fifteen
    -- call sites as dead weight -- and it is the wrong move: the row and Valve's
    -- slot order are not this file's to guarantee, and the guard is the only thing
    -- between a change to either and fifteen location orders on a unit-target
    -- ability.  Pin the count so "clean up the dead branch" cannot pass quietly.
    assert(nCalls >= 15, 'the IsHexAoe call sites were pruned to ' .. nCalls
        .. '. If the reason was "talent8 is untrained anyway": that is true only '
        .. 'while the t25 row takes [7] (section 2). Move the row back and every '
        .. 'pruned site is a silent GH #166 regression with no guard left.')

    -- The gate must stay turbo-only, and it must stay a NARROWING one: the only
    -- thing the armed branch may do is return false.
    assert(sBody:find('J%.IsModeTurbo%(%)') ~= nil, 'the gate lost its turbo-only clause')
    assert(sBody:find("J%.IsSoakCandidate%(%s*'" .. CAND_ID .. "'%s*%)") ~= nil,
        'the gate no longer names ' .. CAND_ID)
    local sArmed = sBody:match("IsSoakCandidate%(%s*'" .. CAND_ID .. "'%s*%)%s*then(.-)end")
    assert(sArmed ~= nil and sArmed:find('return%s+false') ~= nil,
        'the armed branch no longer returns false; a narrowing gate that can return '
        .. 'true has stopped being structurally gate-off-equivalent')
end

-- ---------------------------------------------------------------------------
-- 4b. The three decisions of 2026-08-27, pinned as source prose.
--
-- The t25 change carries two disclosures that no assertion elsewhere can make,
-- because they are about what was DELIBERATELY not done:
--   * the clustered-target branch ("W-团控") is given up, and giving it up is a
--     missed optimisation left open as a WIDENING, not a thing nobody noticed;
--   * the gate is kept on purpose even though its domain is now structural.
-- And one that records a decision people will otherwise re-litigate from scratch:
--   * t20 was priced this round and deliberately NOT changed.
-- Deleting any of the three costs nothing today and loses the reason later, which
-- is the failure this stream has now paid for three times.  Each is asserted
-- against a sentence that occupies ONE source line, because the same three rounds
-- also taught that an assertion written against prose that wraps goes red on the
-- very comment it is protecting -- the cheap repair is to keep the load-bearing
-- sentence unwrapped in the source, never to loosen the assertion.

tests['[hero] the t25/t20 decisions of 2026-08-27 are still stated in the source'] = function()
    local sSrc = read_file(SRC)

    local tClaims = {
        {
            what = 'the widening that taking [7] gives up',
            -- Deliberately stops before the section mark: this file is read by
            -- lua5.1, which has no \x escape, and a literal multi-byte char in a
            -- test anchor is one more thing that can go wrong for a reason that
            -- has nothing to do with the claim being protected.
            find = 'a WIDENING, which GH #166 ',
            why  = 'without it, the skipped clustered-target branch reads as an '
                .. 'oversight instead of a filed follow-up',
        },
        {
            what = 'why the gate is kept once its domain went structural',
            find = 'order is this file\'s to guarantee, and a green test is not a promise.',
            why  = 'without it, the next reader deletes a guard whose domain is '
                .. 'empty only while the t25 row stays on [7]',
        },
        {
            what = 'that t20 was priced this round and left alone',
            find = 't20 PRICED 2026-08-27 and NOT CHANGED -- the row already takes [6].',
            why  = 'without it, [6] reads as an unexamined OpenHyperAI default and '
                .. 'gets re-priced from zero',
        },
    }

    for _, c in ipairs(tClaims) do
        assert(sSrc:find(c.find, 1, true) ~= nil,
            'hero_lion.lua no longer states ' .. c.what .. ' on one line. '
            .. 'Expected to find, verbatim: "' .. c.find .. '". ' .. c.why .. '. '
            .. 'If the sentence was rewritten rather than deleted, update this '
            .. 'assertion in the same change -- and keep the replacement on a '
            .. 'single source line.')
    end
end

-- ---------------------------------------------------------------------------
-- 5. The slot ordering, cross-checked against three claims already in the tree.
--
-- Those three were written from the dota2.com datafeed by earlier passes; the
-- snapshot comes from odota + the game KV.  Agreement between two independent
-- sources is what lets section 1 lean on a row position at all.

tests['[hero] talent slot order agrees with the claims already standing in bots/'] = function()
    api.install({})
    local tSlots = dofile(SNAPSHOT).SLOTS

    local tClaims = {
        -- hero, slot, expected talent, ability it must be proven to modify, who says so
        { 'axe',           7, 'special_bonus_unique_axe_2',   'axe_berserkers_call',
          'hero_axe.lua:280 binds talent7 as "+Berserker`s Call AoE"' },
        { 'axe',           8, 'special_bonus_unique_axe_5',   'axe_culling_blade',
          'hero_axe.lua adds talent8 to nKillDamage in the Culling Blade branch' },
        { 'zuus',          5, 'special_bonus_unique_zeus_2',  'zuus_arc_lightning',
          'hero_zuus.lua`s FACT block: index 5 is the ARC talent, not the ult one' },
        { 'zuus',          3, 'special_bonus_unique_zeus_4',  'zuus_thundergods_wrath',
          'the same block: the ult-damage talent is index 3' },
        { 'skeleton_king', 6, 'special_bonus_unique_wraith_king_facet_3', 'skeleton_king_bone_guard',
          'GH #150 priced talent6 as the Bone Guard facet talent' },
        { 'lion',          5, 'special_bonus_unique_lion_8',  'lion_finger_of_death',
          'X.GetAbilityRDamageBonus adds talent5 to damage_per_kill' },
    }

    for _, c in ipairs(tClaims) do
        local sHero, nSlot, sName, sAbility, sWho = c[1], c[2], c[3], c[4], c[5]
        local tSlot = assert(tSlots[sHero], 'no talent snapshot for ' .. sHero)[nSlot]
        assert(tSlot ~= nil, sHero .. ' snapshot has no slot ' .. nSlot)
        assert(tSlot.name == sName, sHero .. ' slot ' .. nSlot .. ' is ' .. tostring(tSlot.name)
            .. ', but ' .. sWho .. ' -- one of the two sources moved, so re-anchor before '
            .. 'trusting any slot claim in this repo')
        assert(modifies(tSlot, sAbility), sHero .. ' slot ' .. nSlot .. ' (' .. sName
            .. ') is no longer shown modifying ' .. sAbility .. '; ' .. sWho)
    end
end

tests['[hero] the talent snapshot covers all five focus heroes, all eight rows'] = function()
    local tSlots = dofile(SNAPSHOT).SLOTS
    for _, sHero in ipairs({ 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }) do
        local t = assert(tSlots[sHero], 'missing ' .. sHero)
        for i = 1, 8 do
            assert(type(t[i]) == 'table' and type(t[i].name) == 'string' and #t[i].name > 0,
                sHero .. ' slot ' .. i .. ' is missing; a truncated fetch would make the '
                .. 'sections above pass or fail for the wrong reason')
        end
        assert(t[9] == nil, sHero .. ' has a ninth talent row; the 1..8 tier arithmetic in '
            .. 'J.Skill.GetTalentBuild would no longer describe this hero')
    end
end

-- ---------------------------------------------------------------------------
-- 6. The domain -- and WHY it is empty, which is not what it was.
--
-- RE-DERIVED 2026-08-27.  This section used to BE the domain ruling: the corpus
-- held no level-25 hero, therefore no frame could reach the true branch,
-- therefore `lionhexaoe` could not buy condition (a) and was not proposed.
-- That reasoning inherited GH #84's `level >= 20 on 0 of 210 hero-slots`, and
-- that zero was a property of the measuring rig, not of turbo: every batch game
-- self-terminated at a 10-minute economy cap.  GH #108 removed the cap and the
-- first frame past it reads ten heroes at 22-27 (GH #235).  So the old ruling was
-- retired even though this assertion is still green -- the corpus simply has not
-- caught up yet, and a green that survives only because the harvest lags is not
-- a reading anyone should have leaned on.
--
-- The domain is STILL empty, for a reason that does not depend on any corpus:
-- the t25 row now takes [7] (section 2), a hero trains one talent per tier, so
-- `talent8` is structurally untrained and X.IsHexAoe returns false at its FIRST
-- statement, before the gate is ever consulted.  Section 2 is therefore the load-
-- bearing assertion now, and this one measures harvest lag: it is kept because
-- the day it goes red is the day this corpus can finally speak about level-25
-- Lions at all -- including about the widening (prefer clustered targets once Hex
-- really is AoE) that GH #166 §9 left to a later hand.

tests['[hero] the corpus still holds no level-25 hero -- harvest lag, not the ruling'] = function()
    api.install({})
    local sDir = 'tests/fixtures'
    local fh = io.popen('ls ' .. sDir .. '/*.lua 2>/dev/null')
    local tPaths = {}
    for sLine in fh:lines() do tPaths[#tPaths + 1] = sLine end
    fh:close()
    assert(#tPaths > 50, 'only ' .. #tPaths .. ' fixtures found; a scan that reads an '
        .. 'empty corpus would report "no domain" for the wrong reason')

    local nMax, nFrames = 0, 0
    for _, sPath in ipairs(tPaths) do
        local ok, fx = pcall(dofile, sPath)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            nFrames = nFrames + 1
            for _, u in ipairs(fx.units) do
                if type(u.level) == 'number' and u.level > nMax then nMax = u.level end
            end
        end
    end
    assert(nFrames > 50, 'only ' .. nFrames .. ' fixtures parsed into unit tables')
    assert(nMax > 0, 'no hero level read at all; the scan lost its field, so the '
        .. 'verdict below would be an artefact of the parser')

    -- GH #108 landed the cap 10 -> 25 on 2026-08-25, so the farm side is done;
    -- this stays green only until frames harvested under the new cap reach
    -- tests/fixtures/.  That lag is the whole of what this measures now -- read
    -- the section header before quoting a green run for anything else.
    assert(nMax < 25, 'the corpus now reaches level ' .. nMax .. '. This is the '
        .. 'harvest lag closing, NOT `' .. CAND_ID .. '` acquiring a domain -- that '
        .. 'is settled by section 2 (the t25 row takes [7], so talent8 is '
        .. 'structurally untrained). What the new frames DO unlock is the widening '
        .. 'GH #166 §9 left open: prefer clustered targets now that Hex really is '
        .. 'AoE. Rewrite this assertion when you take that up.')
end

return tests
