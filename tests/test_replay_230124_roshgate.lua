-- [roshgate / freehunt#4] Roshan attempt abort, pinned by the REAL failed
-- attempt: game 20260722_230124 t=630 (10:30). Viper had been tanking the pit
-- ALONE since ~10:06 (89% -> 57% at this frame -> dead at 10:45, died_after
-- =15.2 ground truth); Zeus stood 400-1900 from the pit with ZERO damage on
-- Roshan; nobody swapped and nobody called it off. After the death DK+Lion
-- re-opened the pit while the enemy took mid T1.
--
-- Contract of J.ShouldAbortRoshanAttempt on this roster:
--   * tank under 40% with Roshan still >60% -> abort (fires seconds after
--     this frame; at the frame's 57% the conservative bar still holds),
--   * a pressured own tower during an early attempt -> abort,
--   * nearly-dead Roshan -> never abort (finish it),
--   * off the candidate / non-turbo -> inert.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local FIXTURE = 'tests/fixtures/f_230124_viper_roshan_abort.lua'
local tests = {}

local function MakeRosh(hpFrac)
    return api.MakeUnit({
        GetUnitName = 'npc_dota_roshan',
        GetLocation = api.Vector(-3144, 2372, 0), -- the pit, at viper
        GetHealth = math.floor(4000 * hpFrac), GetMaxHealth = 4000,
        IsAlive = true, CanBeSeen = true,
    })
end

local function armed(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id)
        return opts.off ~= true and id == 'roshgate'
    end
    return J, bot, heroes, fx
end

tests['ABORT: tank breaking (<40%) while Roshan still >60%'] = function()
    local J, bot = armed()
    -- The event ledger has viper crossing 40% seconds after this frame
    -- (57% here, dead 15.2s later); pin the crossing instant.
    local sp = rawget(bot, '__spec')
    sp.GetHealth = 480 -- 35%
    sp.OriginalGetHealth = 480
    assert(J.ShouldAbortRoshanAttempt(bot, MakeRosh(0.72)) == true,
        'a breaking tank against a 72% Roshan means the attempt failed -- leave')
end

tests['NO-ABORT: at the frame itself (tank 57%) the conservative bar holds'] = function()
    local J, bot = armed()
    assert(J.ShouldAbortRoshanAttempt(bot, MakeRosh(0.72)) == false,
        'the 40% bar is deliberately conservative -- 57% keeps grinding')
end

tests['NO-ABORT: Roshan nearly dead -> always finish'] = function()
    local J, bot = armed()
    local sp = rawget(bot, '__spec')
    sp.GetHealth = 480
    sp.OriginalGetHealth = 480
    assert(J.ShouldAbortRoshanAttempt(bot, MakeRosh(0.15)) == false,
        'a 15% Roshan is a secured objective; aborting there throws it away')
end

tests['ABORT: own tower pressured during an early attempt (the re-open frame)'] = function()
    local J, bot, heroes = armed()
    -- The second attempt started while mid T1 was being taken: an allied
    -- tower with an enemy on it.
    local tower = api.MakeUnit({
        GetUnitName = 'npc_dota_badguys_tower1_mid',
        GetLocation = api.Vector(1000, 500, 0),
        IsAlive = true, CanBeSeen = true, IsBuilding = true,
    })
    local enemyAtTower
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            enemyAtTower = h
            rawget(h, '__spec').GetLocation = tower:GetLocation()
            rawset(h, 'GetLocation', nil)
            break
        end
    end
    assert(enemyAtTower ~= nil, 'test setup: need an enemy hero')
    local orig = GetUnitList
    GetUnitList = function(kind) -- luacheck: ignore
        if kind == UNIT_LIST_ALLIED_BUILDINGS then return { tower } end
        return orig(kind)
    end
    assert(J.ShouldAbortRoshanAttempt(bot, nil) == true,
        'towers do not wait for Roshan -- an early attempt yields to defense')
end

tests['OFF: inert off the candidate / in normal mode'] = function()
    local J, bot = armed({ off = true })
    local sp = rawget(bot, '__spec')
    sp.GetHealth = 480
    sp.OriginalGetHealth = 480
    assert(J.ShouldAbortRoshanAttempt(bot, MakeRosh(0.72)) == false,
        'candidate off -> inert (shipped default)')
    local J2, bot2 = armed()
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J2.ShouldAbortRoshanAttempt(bot2, MakeRosh(0.72)) == false,
        'normal mode -> inert')
end

return tests
