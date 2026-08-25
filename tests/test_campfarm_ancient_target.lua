-- GH #137 §3 suggestion 2: the ancient gate on the neutral-farm path asks about
-- ONE creep and then lets the target be picked out of the WHOLE list. Gated soak
-- candidate 'campfarm' (turbo-only) filters the list instead.
--
-- THE DEFECT (bots/mode_farm_generic.lua, shipped default)
-- -------------------------------------------------------
-- The farm path sweeps neutrals three times (900u twice, 1000u once) and guards
-- the ancient camps with, twice:
--
--     bot:GetLevel() >= 10 or not nNeutrals[1]:IsAncientCreep()
--
-- and, in the 1000u branch, not at all. The clause asks about `nNeutrals[1]` --
-- whichever creep the engine happens to put first -- while the target actually
-- attacked comes out of `J.Site.FindFarmNeutralTarget(nNeutrals)`, which reads
-- the ENTIRE list. Two camps fit inside one sweep (the replay desk's bearing
-- case has an ogre camp and an ancient camp ~590u apart), so a normal creep at
-- [1] opens the gate and the target picked can still be an ancient one. For a
-- maxHP farmer -- viper, naga_siren, huskar, or anyone holding
-- bfury/maelstrom/mjollnir/radiance -- that is not a corner case but the
-- ROUTINE outcome: an ancient creep has the most health on the field, so it is
-- exactly the one `GetMaxHPCreep` returns.
--
-- The replay desk measured the consequence twice (GH #137, 2026-08-24T00:59Z on
-- 200 games and 2026-08-24T15:57Z on all 208): on the armed 'campgrade' leg, 22
-- of 49 ancient-tier violations happened in games where NO member of the team
-- ever reached the tier at all -- so that camp cannot have come from the camp
-- LIST, and a second path exists that the camp ladder does not manage. That
-- second path is this one, and its threshold (10) is not even the ladder's (12).
--
-- THE FIX (one lever): filter the sweep, don't re-ask the question. Armed and
-- below the ancient tier, ancient creeps are not in the list at all, so every
-- reader agrees -- both `[1]` clauses, the `#nNeutrals >= 3` latch, the
-- UpdateCommonCamp bookkeeping, the target selection, and the raw
-- `Action_AttackUnit(nNeutrals[1])` fallback, which has no ancient clause of its
-- own at any level. The gate is resolved once, in NeutralFarmList
-- (bots/mode_farm_generic.lua); the shipped clauses are left exactly where they
-- are, so unarmed the callers hold the very table GetNearbyCreeps returned.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number
-- --------------------------------------------------------------------------
-- The SUBJECT half is real: every bot driven below is a real hero off a real
-- .dem frame carrying the level the game gave it, and level is the only bot
-- operand the fix reads. The ladder is walked by ONE hero -- viper, the maxHP
-- farmer the replay desk named -- at four real levels, 9/10/11/12, two of which
-- (10 and 12) are the same viper in the same game 26 seconds apart.
--
-- The CREEP half is NOT in the corpus and is not pretended to be: world fact
-- (W1) below asserts that the dumper carries no creeps at all, so
-- `bot:GetNearbyCreeps()` answers `{}` on every fixture and an end-to-end drive
-- of the farm block would be measuring an empty sweep. The creeps below are a
-- DECLARED STAND-IN carrying exactly the fields the shipped selectors read
-- (IsNull / CanBeSeen / IsAlive / IsInvulnerable / IsHero / GetHealth /
-- IsAncientCreep / GetLocation). No count in this file is claimed to be corpus
-- data except the ones in [domain], which read the fixture tables directly.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

-- One hero, four real levels, straddling both thresholds in play: the shipped
-- family's 10 and the camp ladder's 12. L10 and L12 are the same viper in the
-- same game (t=043124, +26s), which is why the pair reads as a level change and
-- not as two different heroes.
local VIPER_L9  = { 'tests/fixtures/f_260820_102645_cm_es_reach.lua',        9 }
local VIPER_L10 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua', 10 }
local VIPER_L11 = { 'tests/fixtures/f_260820_043120_viper_defend_poked.lua', 11 }
local VIPER_L12 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua', 12 }

local VIPER = 'npc_dota_hero_viper'

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], VIPER)
    local bot = heroes[VIPER]
    assert(bot ~= nil, 'fixture no longer carries viper -- ' .. spec[1])
    assert(bot:GetLevel() == spec[2], string.format(
        'the frame moved: %s used to carry viper at level %d, now %d',
        spec[1], spec[2], bot:GetLevel()))
    return J, bot
end

-- A declared neutral creep. `dist` places it away from the bot so the "nearest"
-- selectors have something real to compare; health is what the maxHP/minHP
-- selectors read.
local function creep(bot, sName, nHealth, bAncient, dist)
    local loc = bot:GetLocation()
    local d = (dist or 300) / math.sqrt(2)
    return api.MakeUnit({
        GetUnitName = sName,
        GetHealth = nHealth,
        GetMaxHealth = nHealth,
        IsAncientCreep = bAncient,
        IsNull = false,
        CanBeSeen = true,
        IsAlive = true,
        IsInvulnerable = false,
        IsHero = false,
        GetLocation = api.Vector(loc.x + d, loc.y + d, 0),
    })
end

-- The bearing shape: an ogre camp and an ancient camp both inside one 900u
-- sweep, with a normal creep first -- which is what opens the shipped gate.
-- Ancient creeps carry the most health on the field; that ordering is the whole
-- mechanism, so it is stated here as data rather than assumed in prose.
local function mixed_sweep(bot)
    return {
        creep(bot, 'npc_dota_neutral_ogre_mauler',      550,  false, 260),
        creep(bot, 'npc_dota_neutral_prowler_shaman',   1400, true,  620),
        creep(bot, 'npc_dota_neutral_ogre_magi',        450,  false, 300),
        creep(bot, 'npc_dota_neutral_prowler_acolyte',  1100, true,  680),
    }
end

local function ancients_only(bot)
    return {
        creep(bot, 'npc_dota_neutral_prowler_shaman',  1400, true, 620),
        creep(bot, 'npc_dota_neutral_prowler_acolyte', 1100, true, 680),
    }
end

local function normals_only(bot)
    return {
        creep(bot, 'npc_dota_neutral_ogre_mauler', 550, false, 260),
        creep(bot, 'npc_dota_neutral_ogre_magi',   450, false, 300),
    }
end

local function names(list)
    local out = {}
    for i, u in ipairs(list) do out[i] = u:GetUnitName() end
    return table.concat(out, ',')
end

local function nAncients(list)
    local n = 0
    for _, u in ipairs(list) do if u:IsAncientCreep() then n = n + 1 end end
    return n
end

-- The shipped gate, transcribed VERBATIM from bots/mode_farm_generic.lua. The
-- source is asserted to still read this way in [source] below, so this stays a
-- transcription and cannot quietly become a model of its own.
local function shipped_gate(bot, list)
    return bot:GetLevel() >= 10 or not list[1]:IsAncientCreep()
end

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

--============================================================================
-- World facts this file rests on. Asserted, not described.
--============================================================================

tests['[world W1] the corpus carries no creeps, so every creep here is declared'] = function()
    local J, bot = subject(VIPER_L10)
    assert(J ~= nil)
    for _, r in ipairs({ 900, 1000 }) do
        local got = bot:GetNearbyCreeps(r, true)
        assert(type(got) == 'table' and #got == 0, string.format(
            'GetNearbyCreeps(%d) is no longer empty on a fixture -- if the dumper ' ..
            'started carrying creeps, this file should drive the real sweep and ' ..
            'every claim below gets stronger', r))
    end
    -- and the same fact read off the fixture tables, corpus-wide
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local nFiles, nCreepKeys = 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' then
            nFiles = nFiles + 1
            if fx.creeps ~= nil then nCreepKeys = nCreepKeys + 1 end
        end
    end
    p:close()
    assert(nFiles >= 100, 'corpus shrank: ' .. nFiles .. ' fixtures')
    assert(nCreepKeys == 0, nCreepKeys .. ' fixtures now carry a creeps key')
end

tests['[world W2] the shipped farm family bounds ancients at 10, the ladder at 12'] = function()
    -- The gap band 10..11 is the whole domain of this lever, so the two
    -- constants are read off the source rather than believed.
    local farm = strip_comments(read('bots/mode_farm_generic.lua'))
    local _, nTen = farm:gsub("GetLevel%(%)%s*>=%s*10%s*or%s*not%s*nNeutrals%[1%]:IsAncientCreep%(%)", '')
    assert(nTen == 2, 'expected the two shipped `>= 10 or not [1]:IsAncientCreep()` ' ..
        'clauses, found ' .. nTen .. ' -- the transcription in shipped_gate() is stale')
    local utils = strip_comments(read('bots/FunLib/utils.lua'))
    assert(utils:find('GetBot%(%):GetLevel%(%)%s*>%s*9%s*or%s*not%s*target:IsAncientCreep%(%)'),
        "IsValidCreep's own ancient bound moved -- W3 below reads it")
    local site = strip_comments(read('bots/FunLib/aba_site.lua'))
    local ancient = site:match('IsAncientCamp%(camp%)%s*and%s*botLevel%s*<%s*(%d+)')
    assert(ancient == '12', 'the camp ladder ancient tier is no longer 12: ' .. tostring(ancient))
end

tests['[world W3] below level 10 the shipped SELECTORS already skip ancients'] = function()
    -- IsValidCreep carries its own `GetBot():GetLevel() > 9 or not IsAncientCreep()`,
    -- so GetMaxHPCreep / GetMinHPCreep / GetNearestCreep refuse ancient creeps
    -- under level 10 without any help. This is what makes the defect band
    -- exactly 10..11 rather than "every level": the bug is not that low-level
    -- bots pick ancients through the selectors, it is that the 10..11 band does
    -- and that the raw `nNeutrals[1]` fallback does at any level.
    local J, bot = subject(VIPER_L9)
    local sweep = mixed_sweep(bot)
    local got = J.Site.FindFarmNeutralTarget(sweep)
    assert(got ~= nil and not got:IsAncientCreep(), 'at level 9 the shipped ' ..
        'selector picked an ancient creep: ' .. tostring(got and got:GetUnitName()))
    -- but the gate the block actually asks is about [1], and [1] is an ogre
    assert(shipped_gate(bot, sweep) == true,
        'the shipped gate refuses this sweep at level 9 -- the stand-in no ' ..
        'longer puts a normal creep first, and the bearing shape is gone')
end

--============================================================================
-- Today's defect, driving the real selector on real levels.
--============================================================================

tests["[today's defect] at level 10 and 11 the picked target is the ancient creep"] = function()
    for _, spec in ipairs({ VIPER_L10, VIPER_L11 }) do
        local J, bot = subject(spec)
        local sweep = mixed_sweep(bot)
        assert(shipped_gate(bot, sweep) == true, string.format(
            'level %d: the shipped gate should open -- it reads [1], an ogre', spec[2]))
        local got = J.Site.FindFarmNeutralTarget(sweep)
        assert(got ~= nil, 'level ' .. spec[2] .. ': no target at all')
        assert(got:IsAncientCreep(), string.format(
            'level %d: the shipped selector no longer picks the ancient creep ' ..
            '(got %s) -- either viper stopped being a maxHP farmer or the ' ..
            'stand-in stopped giving the ancient the most health',
            spec[2], got:GetUnitName()))
        assert(got:GetUnitName() == 'npc_dota_neutral_prowler_shaman',
            'level ' .. spec[2] .. ': expected the highest-health creep, got ' ..
            got:GetUnitName())
    end
end

tests["[today's defect] the raw fallback target is ungated at every level"] = function()
    -- When FindFarmNeutralTarget returns nil the block attacks nNeutrals[1]
    -- directly, and that line consults no ancient clause of its own. With an
    -- ancient-only sweep at level 10 the shipped gate opens and [1] IS the
    -- ancient creep, so the fallback would attack it.
    local _, bot = subject(VIPER_L10)
    local sweep = ancients_only(bot)
    assert(shipped_gate(bot, sweep) == true, 'level 10 opens the gate by level alone')
    assert(sweep[1]:IsAncientCreep(), 'stand-in changed shape')
end

--============================================================================
-- The fix.
--============================================================================

tests['[fix] armed, the 10..11 band picks the ogre instead of the ancient'] = function()
    for _, spec in ipairs({ VIPER_L10, VIPER_L11 }) do
        local J, bot = subject(spec)
        local sweep = mixed_sweep(bot)
        local filtered = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
        assert(#filtered == 2 and nAncients(filtered) == 0, string.format(
            'level %d: expected the two ogres, got [%s]', spec[2], names(filtered)))
        local got = J.Site.FindFarmNeutralTarget(filtered)
        assert(got ~= nil and not got:IsAncientCreep(), string.format(
            'level %d: armed selection still lands on an ancient creep (%s)',
            spec[2], tostring(got and got:GetUnitName())))
        assert(got:GetUnitName() == 'npc_dota_neutral_ogre_mauler', string.format(
            'level %d: expected the highest-health NON-ancient creep, got %s',
            spec[2], got:GetUnitName()))
        -- and the [1] clause now agrees with the selection instead of being
        -- answered by a creep nobody attacks
        assert(shipped_gate(bot, filtered) == true and not filtered[1]:IsAncientCreep(),
            'level ' .. spec[2] .. ': the head of the armed list is still ancient')
    end
end

tests['[fix] armed below the tier the list loses ancients even where selection agreed'] = function()
    -- Level 9: the selector already refused ancients (W3), but the LIST still
    -- carried them -- which is what the `[1]` clauses and the raw fallback read.
    -- Armed, they are gone, and the target is unchanged. Both halves matter.
    local J, bot = subject(VIPER_L9)
    local sweep = mixed_sweep(bot)
    local before = J.Site.FindFarmNeutralTarget(sweep)
    local filtered = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
    assert(nAncients(sweep) == 2, 'the unfiltered sweep must still carry both ancients')
    assert(nAncients(filtered) == 0, 'level 9 armed: ancients survived the filter')
    local after = J.Site.FindFarmNeutralTarget(filtered)
    assert(after == before, 'level 9: filtering changed the picked target -- it ' ..
        'should not, the selector already refused ancients there')
end

tests['[fix] at the tier and above, armed is a no-op -- same table, same target'] = function()
    local J, bot = subject(VIPER_L12)
    local sweep = mixed_sweep(bot)
    local filtered = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
    assert(rawequal(filtered, sweep), 'level 12 armed returned a different table -- ' ..
        'at or above the tier the fix must not touch the list at all')
    local got = J.Site.FindFarmNeutralTarget(filtered)
    assert(got ~= nil and got:IsAncientCreep(), 'level 12 must still be allowed to ' ..
        'farm ancient camps -- got ' .. tostring(got and got:GetUnitName()))
end

tests['[fix] unarmed is identity, not equivalence, at every real level'] = function()
    for _, spec in ipairs({ VIPER_L9, VIPER_L10, VIPER_L11, VIPER_L12 }) do
        local J, bot = subject(spec)
        for _, mk in ipairs({ mixed_sweep, ancients_only, normals_only }) do
            local sweep = mk(bot)
            assert(rawequal(J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), false), sweep),
                'level ' .. spec[2] .. ': unarmed returned a copy instead of the table')
            assert(rawequal(J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), nil), sweep),
                'level ' .. spec[2] .. ': a nil gate must behave exactly like false')
        end
    end
end

tests['[fix] armed with nothing to drop is also identity'] = function()
    local J, bot = subject(VIPER_L10)
    local sweep = normals_only(bot)
    assert(rawequal(J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true), sweep),
        'a sweep with no ancient creep in it must come back as the same table')
end

tests['[declared consequence] an ancient-only sweep becomes an EMPTY list'] = function()
    -- Stated, not hidden: armed, a level-10/11 bot standing at an ancient camp
    -- with nothing else in range gets an empty sweep, and the farm block then
    -- takes its own existing "nothing here" path. The branch that path needs is
    -- asserted to still exist in the source, so this consequence cannot quietly
    -- turn into a fall-through to the map-centre walk.
    local J, bot = subject(VIPER_L11)
    local sweep = ancients_only(bot)
    local filtered = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
    assert(#filtered == 0, 'expected an empty list, got [' .. names(filtered) .. ']')
    local farm = strip_comments(read('bots/mode_farm_generic.lua'))
    assert(farm:find('#nNeutrals%s*==%s*0'),
        "the farm block's own empty-sweep branch is gone -- the declared " ..
        'consequence of this fix landed somewhere else and needs re-reading')
end

--============================================================================
-- Structure: the gate cannot be missed, and the two constants cannot drift.
--============================================================================

tests['[source] every neutral sweep in the farm mode goes through the one gate'] = function()
    local code = strip_comments(read('bots/mode_farm_generic.lua'))
    local _, nSweeps = code:gsub('bot:GetNearbyCreeps%s*%(', '')
    assert(nSweeps == 3, 'the farm mode now sweeps neutrals ' .. nSweeps ..
        ' times, not 3 -- a new sweep needs to come through NeutralFarmList too')
    local _, nWrapped = code:gsub('NeutralFarmList%s*%(%s*bot%s*,%s*bot:GetNearbyCreeps%s*%(', '')
    assert(nWrapped == 3, 'only ' .. nWrapped .. ' of the 3 sweeps are wrapped -- ' ..
        'an unwrapped sweep silently misses the gate and reads unfiltered creeps')
end

tests['[source] the wrapper is the only gate, and it is turbo-only'] = function()
    local code = strip_comments(read('bots/mode_farm_generic.lua'))
    local body = code:match('local function NeutralFarmList.-\nend')
    assert(body, 'NeutralFarmList is gone or reshaped')
    assert(body:find('J%.IsModeTurbo%s*%(%s*%)'), 'the filter must be turbo-only')
    assert(body:find("J%.IsSoakCandidate%s*%(%s*'campfarm'%s*%)"),
        "the filter must be gated on 'campfarm'")
    local _, nGates = code:gsub("J%.IsSoakCandidate%s*%(%s*'campfarm'%s*%)", '')
    assert(nGates == 1, "'campfarm' is resolved in " .. nGates .. ' places -- a ' ..
        'second resolution point is a second gate to keep in step')
    -- and no other file in bots/ calls the filter directly
    local p = assert(io.popen("grep -rl 'FilterFarmNeutrals' bots/ | sort"))
    local files = {}
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    table.sort(files)
    assert(#files == 2 and files[1] == 'bots/FunLib/aba_site.lua'
        and files[2] == 'bots/mode_farm_generic.lua',
        'FilterFarmNeutrals gained a call site outside the single wrapper: ' ..
        table.concat(files, ' '))
end

tests['[source] the farm bound and the camp ladder read the same number'] = function()
    local J = subject(VIPER_L10)
    assert(J.Site.ANCIENT_MIN_LEVEL == 12,
        'J.Site.ANCIENT_MIN_LEVEL is ' .. tostring(J.Site.ANCIENT_MIN_LEVEL))
    local site = strip_comments(read('bots/FunLib/aba_site.lua'))
    local body = site:match('IsCampAllowedForLevel%s*=%s*function.-\nend')
    assert(body, 'IsCampAllowedForLevel is gone or reshaped')
    local ancient = body:match('IsAncientCamp[^\n]*\n')
    assert(ancient and ancient:find('botLevel%s*<%s*' .. J.Site.ANCIENT_MIN_LEVEL),
        'the ladder tier and J.Site.ANCIENT_MIN_LEVEL disagree -- the farm path ' ..
        'and the camp list would then refuse ancient camps at different levels')
end

tests['[ts parity] the TypeScript source carries the same filter'] = function()
    local ts = read('typescript/bots/FunLib/aba_site.ts')
    ts = ts:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    assert(ts:find('FilterFarmNeutrals'), 'the TS source was not kept in lockstep')
    assert(ts:find('ANCIENT_MIN_LEVEL%s*=%s*12'), 'the TS ancient bound drifted')
    assert(ts:find('bStrictAncient'), 'the TS filter lost its gate parameter')
end

--============================================================================
-- Domain: how much of the corpus sits in the band this lever owns.
--============================================================================

tests['[domain] the 10..11 gap band is a real population, and so is 12+'] = function()
    -- Floors, not equalities (GH #106): adding a fixture must not turn this red.
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local nSlots, nBand, nAbove = 0, 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.level then
                    nSlots = nSlots + 1
                    if u.level == 10 or u.level == 11 then nBand = nBand + 1
                    elseif u.level >= 12 then nAbove = nAbove + 1 end
                end
            end
        end
    end
    p:close()
    assert(nSlots >= 1000, 'corpus shrank: ' .. nSlots .. ' hero-slots')
    -- Measured 2026-08-25 on 104 fixtures / 1040 hero-slots: 140 in the 10..11
    -- band (13.5%), 82 at or above 12. The first floor says the lever has a domain --
    -- the band where the shipped `>= 10` clauses pass but the ladder refuses.
    -- The second says the population it must NOT touch still exists.
    assert(nBand >= 120, 'the 10..11 band collapsed: ' .. nBand)
    assert(nAbove >= 70, 'the >= 12 population collapsed: ' .. nAbove)
end

return tests
