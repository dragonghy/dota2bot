-- GH #137 §4 suggestion 2, and the replay desk's 2026-09-13T00:4xZ handoff to
-- the strategy desk: "把四个阈值对齐成同一个常量时,`IsValidCreep` 那条 `> 9`
-- 要一起算进去 -- 它今天是唯一一条在目标选择内部、且对每一只 creep 都求值的
-- 远古闸,漏掉它会让「对齐了」的读数在 10/11 两级上继续分叉."
--
-- THE DEFECT (shipped default, bots/FunLib/utils.lua IsValidCreep)
-- ----------------------------------------------------------------
-- The farm path's target selection validates every creep through
--
--     GetBot():GetLevel() > 9 or not target:IsAncientCreep()
--
-- so at levels 10 and 11 an ancient creep is a perfectly valid farm target,
-- while the camp ladder (ANCIENT_MIN_LEVEL = 12) says that bot may not take an
-- ancient camp at all. The replay desk measured that this is the bound that
-- decides the frame, not the ladder's: a level-10 sniper passes `10 > 9`, and a
-- level-9 viper in the SAME game does not -- one `if`, one level apart, opposite
-- worlds (GH #137, 2026-09-13T00:4xZ §2/§3).
--
-- For a maxHP farmer (viper, naga_siren, huskar, or a bfury / maelstrom /
-- mjollnir / radiance holder) the ancient is not a corner case but the ROUTINE
-- pick: it carries the most health on the field, so it is exactly what
-- GetMaxHPCreep returns.
--
-- THE LEVER ('camppick', turbo-only) AND WHY IT IS NOT 'campfarm' AGAIN
-- --------------------------------------------------------------------
-- Both levers drop ancients below the same tier. They differ in what ELSE
-- moves. 'campfarm' filters the sweep at NeutralFarmList, so every reader of the
-- list loses the ancients -- including the readers that only COUNT. GH #265
-- photographed the state that leaves behind: "may I attack a neutral here" and
-- "are there neutrals here" answer from different lists, the lane-creep escape
-- stays shut, and a level-4 Earthshaker crossed an ancient camp's aggro radius
-- six times in 19s with no damage of its own and died at t=238.1. Patching that
-- took a SECOND id ('campvoid').
--
-- 'camppick' filters only the copy the SELECTOR walks. The caller's table comes
-- back untouched, so list length, both `[1]` clauses, the `>= 3` latch,
-- UpdateCommonCamp and the presence axis read what they read today. That
-- difference is the point of the lever, so it is [presence] below -- an
-- assertion on object identity, not a sentence in a comment.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number
-- --------------------------------------------------------------------------
-- The SUBJECT half is real: every bot driven below is a real hero off a real
-- .dem frame carrying the level the game gave it, and level is the only bot
-- operand the lever reads. The ladder is walked by ONE hero -- viper, the maxHP
-- farmer the replay desk named -- at four real levels 9/10/11/12, two of which
-- (10 and 12) are the same viper in the same game 26 seconds apart.
--
-- The CREEP half is NOT in the corpus and is not pretended to be. The dumper
-- emits creep samples carrying position and team only -- "no entity id, no name,
-- no health" (tools/batch_test/replayscope/make_fixture.py) -- and
-- IsAncientCreep() is the one predicate this lever reads, so "which of these was
-- an ancient" is discarded at fixture-write time. That is the same wall the
-- replay desk hit on 2026-09-13 (§1: "那条断言结构上买不到"). The creeps below
-- are therefore a DECLARED STAND-IN carrying exactly the fields the shipped
-- selectors read. No count here is claimed as corpus data except [domain],
-- which reads the fixture tables directly.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

-- One hero, four real levels, straddling every bound in play: IsValidCreep's 9,
-- the two `nNeutrals[1]` clauses' 10, and the ladder's 12. L10 and L12 are the
-- same viper in the same game (t=043124, +26s), which is why that pair reads as
-- a level change rather than as two different heroes.
local VIPER_L9  = { 'tests/fixtures/f_260820_102645_cm_es_reach.lua',        9 }
local VIPER_L10 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua', 10 }
local VIPER_L11 = { 'tests/fixtures/f_260820_043120_viper_defend_poked.lua', 11 }
local VIPER_L12 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua', 12 }

local BAND = { VIPER_L10, VIPER_L11 }
local ALL  = { VIPER_L9, VIPER_L10, VIPER_L11, VIPER_L12 }

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

-- A declared neutral creep carrying exactly the fields the shipped selectors
-- read. `dist` places it away from the bot so the "nearest" selector has
-- something real to compare; health is what maxHP/minHP read.
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

-- The bearing shape GH #137 was filed on: an ogre camp and an ancient camp both
-- inside one 900u sweep (~590u apart in the replay desk's case), normal creep
-- first -- which is what opens the shipped `[1]` gate. Ancients carry the most
-- health; that ordering IS the mechanism, so it is stated here as data.
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
-- World facts. Asserted, not described.
--============================================================================

-- W1. The corpus cannot drive this end to end: creep rows carry no identity, so
-- IsAncientCreep() -- the lever's one creep predicate -- is unanswerable from a
-- fixture. This is why the creeps above are declared. If the dumper ever starts
-- emitting creep identity, this assertion goes red and the stand-in can retire.
tests['[world] the corpus carries no creep identity, so the creeps here are declared'] = function()
    local gen = read('tools/batch_test/replayscope/make_fixture.py')
    assert(gen:find('POSITION AND TEAM ONLY', 1, true)
        or gen:find('no entity id, no name, no health', 1, true),
        'make_fixture.py no longer says creep rows are position/team only -- '
        .. 'if creep identity is now emitted, this file can stop declaring creeps')
end

-- W2. viper really is a maxHP farmer, which is what makes the ancient the
-- ROUTINE pick rather than a corner case. Read off the shipped table.
tests['[world] viper is a maxHP farmer in the shipped selector table'] = function()
    local J = subject(VIPER_L10)
    local pick = J.Site.ConsiderFarmNeutralType[VIPER]
    assert(pick ~= nil, 'viper left ConsiderFarmNeutralType')
    assert(pick() == 'maxHP', 'viper is no longer a maxHP farmer: ' .. tostring(pick()))
end

--============================================================================
-- The four bounds, read from source. The lever's whole claim is that they
-- disagree; if a future edit aligns one of them by hand, these go red and the
-- claim gets re-read instead of silently becoming false.
--============================================================================

tests['[source] the four ancient bounds still read 9 / 10 / 10 / 12'] = function()
    local utils = strip_comments(read('bots/FunLib/utils.lua'))
    assert(utils:find('GetBot%(%):GetLevel%(%)%s*>%s*9'),
        "IsValidCreep's `> 9` moved -- re-read the handoff before trusting this file")

    local farm = strip_comments(read('bots/mode_farm_generic.lua'))
    local _, nTen = farm:gsub('GetLevel%(%)%s*>=%s*10', '')
    assert(nTen == 2, 'expected the two shipped `>= 10` [1] clauses, found ' .. nTen)

    local site = strip_comments(read('bots/FunLib/aba_site.lua'))
    assert(site:find('ANCIENT_MIN_LEVEL%s*=%s*12'),
        'ANCIENT_MIN_LEVEL is no longer 12 -- the ladder moved under this lever')
end

--============================================================================
-- Gate wiring. One id, turbo-only, one place, not conjoined with another id.
--============================================================================

tests['[gate] camppick is turbo-only, resolved once, and names no other id'] = function()
    local code = read('bots/mode_farm_generic.lua')
    local body = code:match('local function FarmNeutralTarget%b()%s*(.-)\nend')
    assert(body ~= nil, 'the FarmNeutralTarget wrapper is gone')
    assert(body:find('J%.IsModeTurbo%s*%(%s*%)'), 'the lever must be turbo-only')
    assert(body:find("J%.IsSoakCandidate%s*%(%s*'camppick'%s*%)"),
        'the wrapper no longer resolves camppick')

    local stripped = strip_comments(code)
    local _, nGates = stripped:gsub("J%.IsSoakCandidate%s*%(%s*'camppick'%s*%)", '')
    assert(nGates == 1, 'camppick must be resolved in exactly one place, found ' .. nGates)

    -- The pullcad trap (AGENTS.md): a gate written as `IsSoakCandidate('X') and
    -- IsSoakCandidate('Y')` freezes FALSE the day Y is promoted, and
    -- check_armed_wiring.py still calls it WIRED. So camppick's gate may name
    -- exactly one soak id -- its own.
    local _, nAnyId = body:gsub('IsSoakCandidate', '')
    assert(nAnyId == 1, 'camppick\'s gate names another soak id -- pullcad trap')
end

tests['[gate] every farm-path selection goes through the wrapper'] = function()
    local stripped = strip_comments(read('bots/mode_farm_generic.lua'))
    local _, nDirect = stripped:gsub('J%.Site%.FindFarmNeutralTarget%s*%(', '')
    assert(nDirect == 1, 'expected exactly one direct call (inside the wrapper), '
        .. 'found ' .. nDirect .. ' -- a call site drifted past the gate')
    local _, nWrapped = stripped:gsub('FarmNeutralTarget%s*%(%s*bot%s*,', '')
    assert(nWrapped == 4, 'expected the 4 shipped call sites on the wrapper, found ' .. nWrapped)

    -- Nothing outside this file may call the selector directly either.
    local p = assert(io.popen("grep -rl 'FindFarmNeutralTarget' bots/ 2>/dev/null"))
    local seen = {}
    for line in p:lines() do seen[#seen + 1] = line end
    p:close()
    table.sort(seen)
    assert(table.concat(seen, ',') == 'bots/FunLib/aba_site.lua,bots/mode_farm_generic.lua',
        'a new file calls FindFarmNeutralTarget: ' .. table.concat(seen, ','))
end

--============================================================================
-- Behaviour.
--============================================================================

tests['[fix] armed, the 10..11 band stops picking the ancient'] = function()
    for _, spec in ipairs(BAND) do
        local J, bot = subject(spec)
        local sweep = mixed_sweep(bot)

        local shipped = J.Site.FindFarmNeutralTarget(sweep)
        assert(shipped ~= nil and shipped:IsAncientCreep(), string.format(
            'level %d: the shipped selector no longer picks the ancient (%s) -- '
            .. 'the defect this lever closes is gone, re-read before editing',
            spec[2], shipped and shipped:GetUnitName() or 'nil'))

        local armed = J.Site.FindFarmNeutralTarget(sweep, true)
        assert(armed ~= nil, 'level ' .. spec[2] .. ': armed returned nil on a MIXED sweep')
        assert(not armed:IsAncientCreep(), string.format(
            'level %d: armed selection still lands on an ancient creep (%s)',
            spec[2], armed:GetUnitName()))
    end
end

tests['[fix] at the tier and above, armed is a no-op'] = function()
    local J, bot = subject(VIPER_L12)
    local sweep = mixed_sweep(bot)
    local shipped = J.Site.FindFarmNeutralTarget(sweep)
    local armed   = J.Site.FindFarmNeutralTarget(sweep, true)
    assert(rawequal(shipped, armed), 'level 12: armed changed the pick -- the >= 12 '
        .. 'population is the one GH #137 §4 forbids touching')
    assert(armed:IsAncientCreep(), 'level 12 should still take the ancient')
end

tests['[fix] below 10 armed is a no-op -- the shipped bound already refuses'] = function()
    local J, bot = subject(VIPER_L9)
    local sweep = mixed_sweep(bot)
    local shipped = J.Site.FindFarmNeutralTarget(sweep)
    assert(shipped ~= nil and not shipped:IsAncientCreep(),
        'level 9: IsValidCreep `> 9` no longer refuses the ancient')
    local armed = J.Site.FindFarmNeutralTarget(sweep, true)
    assert(rawequal(shipped, armed),
        'level 9: armed changed a decision the shipped bound already made correctly')
end

tests['[fix] unarmed is identity at every real level'] = function()
    for _, spec in ipairs(ALL) do
        local J, bot = subject(spec)
        local sweep = mixed_sweep(bot)
        local a = J.Site.FindFarmNeutralTarget(sweep)
        local b = J.Site.FindFarmNeutralTarget(sweep, false)
        local c = J.Site.FindFarmNeutralTarget(sweep, nil)
        assert(rawequal(a, b) and rawequal(a, c), 'level ' .. spec[2]
            .. ': the unarmed / explicit-false / nil paths disagree')
    end
end

-- The assertion that separates this lever from 'campfarm'. campfarm mutates what
-- every reader sees; camppick must hand the caller's table back byte-for-byte,
-- same object, same length, same head -- because `#nNeutrals`, the `>= 3` latch,
-- the two `[1]` clauses and campvoid's presence axis all read it afterwards.
tests['[presence] the caller\'s list survives the armed call untouched'] = function()
    for _, spec in ipairs(BAND) do
        local J, bot = subject(spec)
        local sweep = mixed_sweep(bot)
        local nBefore, headBefore = #sweep, sweep[1]
        local copy = {}
        for i, u in ipairs(sweep) do copy[i] = u end

        J.Site.FindFarmNeutralTarget(sweep, true)

        assert(#sweep == nBefore, string.format(
            'level %d: the armed call shortened the caller\'s list %d -> %d; '
            .. 'that is campfarm\'s mechanism (GH #265) and not this lever\'s',
            spec[2], nBefore, #sweep))
        assert(rawequal(sweep[1], headBefore),
            'level ' .. spec[2] .. ': the head of the caller\'s list moved')
        for i, u in ipairs(copy) do
            assert(rawequal(sweep[i], u),
                'level ' .. spec[2] .. ': entry ' .. i .. ' of the caller\'s list changed')
        end
    end
end

-- Declared consequence, pinned so it cannot be quietly "fixed" into the #265
-- shape later: an all-ancient sweep returns nil, and the caller's own ungated
-- `Action_AttackUnit(nNeutrals[1])` fallback then runs -- unchanged shipped
-- behaviour. The lever's domain is the MIXED sweep.
tests['[limit] an all-ancient sweep returns nil and the ungated fallback survives'] = function()
    local J, bot = subject(VIPER_L10)
    local armed = J.Site.FindFarmNeutralTarget(ancients_only(bot), true)
    assert(armed == nil, 'all-ancient sweep armed should yield nil, got '
        .. (armed and armed:GetUnitName() or 'nil'))

    local stripped = strip_comments(read('bots/mode_farm_generic.lua'))
    assert(stripped:find('Action_AttackUnit%s*%(%s*nNeutrals%[1%]'),
        'the ungated `[1]` fallback this limit refers to is gone -- re-read [limit]')
end

-- The排波 constraint, mechanical rather than prose: armed together, campfarm
-- hands this lever a list with no ancient left, so camppick cannot be read on
-- that leg. Directors排波 off this assertion, not off a report sentence.
tests['[domination] campfarm armed leaves camppick nothing to refuse'] = function()
    local J, bot = subject(VIPER_L10)
    local sweep = mixed_sweep(bot)
    local filtered = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
    assert(not rawequal(filtered, sweep), 'campfarm armed should hand back a new list')
    for _, u in ipairs(filtered) do
        assert(not u:IsAncientCreep(), 'campfarm left an ancient in the list')
    end
    local a = J.Site.FindFarmNeutralTarget(filtered)
    local b = J.Site.FindFarmNeutralTarget(filtered, true)
    assert(rawequal(a, b), 'camppick changed a decision on a campfarm-filtered list -- '
        .. 'the domination claim in both head notes is false, re-read before排波')
end

--============================================================================
-- Domain. These read the fixture tables directly and are the only corpus
-- numbers in this file. Floors, not equalities (GH #106).
--============================================================================

tests['[domain] the 10..11 band and the protected >= 12 population both exist'] = function()
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
    -- The first floor says the lever has a domain: the band where IsValidCreep's
    -- `> 9` passes but the ladder refuses. The second says the population GH #137
    -- §4 forbids collapsing still exists.
    assert(nBand >= 120, 'the 10..11 band collapsed: ' .. nBand)
    assert(nAbove >= 70, 'the >= 12 population collapsed: ' .. nAbove)
end

return tests
