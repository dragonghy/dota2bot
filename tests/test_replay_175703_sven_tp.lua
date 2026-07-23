-- Replay-fixture regression for TP audit fix D, pinned by the REAL frame that
-- motivated it: game 20260722_175703 t=47.4 (0:47), Sven at the radiant
-- safelane with Viper ~428u and Shadow Shaman ~419u on him -- and it STARTED a
-- 3s TP channel anyway, eating 7 more hits while channeling (audit waste type
-- 1; observed.burst: viper 124 + SS 58 over the window). The fixed decision:
-- an on-face enemy makes the channel interruptible -> do not start the TP.
--
-- The dumper does not capture attack ranges or velocities, so the tests set
-- the real attack ranges (Viper 575, SS 400 -- both ranged laners) and
-- stationary extrapolation; everything else is the real frame.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_175703_sven_tp47.lua'
local tests = {}

local RANGES = {
    ['npc_dota_hero_viper'] = 575,
    ['npc_dota_hero_shadow_shaman'] = 400,
}

local function loaded()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    for name, range in pairs(RANGES) do
        local sp = rawget(heroes[name], '__spec')
        sp.GetAttackRange = range
        sp.GetExtrapolatedLocation = heroes[name]:GetLocation()
    end
    return J, bot, heroes, fx
end

tests['fix D core: Viper+SS on-face -> the 3s channel IS interruptible'] = function()
    local J, bot = loaded()
    assert(J.CanEnemyInterruptTpChannel(bot) == true,
        'the 0:47 frame: two ranged enemies inside attack reach must veto the channel')
end

tests['counterfactual: both enemies out of the 700 scan -> channel is safe'] = function()
    local J, bot, heroes = loaded()
    for name in pairs(RANGES) do
        local sp = rawget(heroes[name], '__spec')
        sp.GetLocation = { x = 90000, y = 90000, z = 0 }
        sp.GetExtrapolatedLocation = { x = 90000, y = 90000, z = 0 }
        rawset(heroes[name], 'GetLocation', nil)
    end
    assert(J.CanEnemyInterruptTpChannel(bot) == false,
        'with the laners gone the same TP would complete -- no veto')
end

tests['tpsafe2 wrapper fires on this frame when armed (travel-TP guard)'] = function()
    local J, bot = loaded()
    J.IsSoakCandidate = function(id) return id == 'tpsafe2' end
    assert(J.ShouldNotStartInterruptibleTp(bot) == true,
        'armed tpsafe2 must refuse to start the 0:47 travel TP')
end

tests['tpsafe2 wrapper stays inert off the candidate (shipped default)'] = function()
    local J, bot = loaded()
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldNotStartInterruptibleTp(bot) == false,
        'off the candidate the gated wrapper must not change shipped behavior')
end

return tests
