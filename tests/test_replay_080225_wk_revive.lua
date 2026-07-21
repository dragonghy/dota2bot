-- Replay-fixture regression: game 20260720_080225, t=6:43. Wraith King (FOCUS
-- hero) died at 6:37 at (6437,-5314); Reincarnation revived him IN PLACE at
-- 79% HP -- still 1v2 (Juggernaut 406u, Shadow Shaman 530u, no ally within
-- 2000) -- and he re-engaged and died again at 6:50. Same at 11:00->11:12. The
-- ultimate is repeatedly spent for nothing. #17's death-zone guard covers only
-- enemy-half deaths, so this own-half revive-feed falls through it.
--
-- J.ShouldFleeAfterRevive must fire here. Numbers-based on purpose: the real
-- frame is 79% HP, so an HP-threshold guard would miss it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_080225_wk_revive.lua'
local DEATH_SPOT = { x = 6437, y = -5314 }
local DEATH_T, NOW = 397.5, 403.0

local tests = {}

-- Build the armed world: record the 6:37 death via the real dead-frame path
-- (exactly how mode_retreat_generic records it), then return to the live
-- fixture frame at t=6:43.
local function armed()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'lf_revive' end
    local spec = rawget(bot, '__spec')
    local live_loc = bot:GetLocation()
    spec.IsAlive = false
    spec.GetLocation = Vector(DEATH_SPOT.x, DEATH_SPOT.y, 0)
    GameTime = function() return DEATH_T end
    J.ShouldAvoidDeathZone(bot) -- dead frame: records spot+time
    spec.IsAlive = true
    spec.GetLocation = live_loc
    GameTime = function() return NOW end
    return J, bot, heroes, fx
end

tests['ground truth: he re-engaged and died again'] = function()
    local _, _, _, fx = armed()
    assert(fx.observed.died_after ~= nil and fx.observed.died_after < 10,
        'WK died again within seconds of the revive frame')
end

tests['fires: revived in place, 1v2, no help'] = function()
    local J, bot = armed()
    assert(J.GetHP(bot) > 0.7, 'the real frame is HIGH HP -- guard must be numbers-based')
    assert(J.ShouldFleeAfterRevive(bot) == true,
        'reincarnated into an unwinnable 1v2 -> leave, do not re-engage')
end

tests['counterfactual: an ally arrives -> the fight is takeable'] = function()
    local J, bot, heroes = armed()
    rawget(heroes['npc_dota_hero_earthshaker'], '__spec').GetLocation = bot:GetLocation()
    assert(J.ShouldFleeAfterRevive(bot) == false,
        '2v2 after reviving is a real fight, not a guaranteed feed')
end

tests['counterfactual: fountain respawn (far from spot) is unaffected'] = function()
    local J, bot = armed()
    rawget(bot, '__spec').GetLocation = Vector(6437 + 4000, -5314 + 4000, 0)
    assert(J.ShouldFleeAfterRevive(bot) == false,
        'a normal respawn walks out of the fountain as usual')
end

tests['counterfactual: long after the revive window -> inert'] = function()
    local J, bot = armed()
    GameTime = function() return DEATH_T + 30 end
    assert(J.ShouldFleeAfterRevive(bot) == false,
        'the guard only covers the seconds right after reviving')
end

tests['gate off: shipped default is unchanged'] = function()
    local J, bot = armed()
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldFleeAfterRevive(bot) == false,
        'off the candidate the guard must stay inert')
end

return tests
