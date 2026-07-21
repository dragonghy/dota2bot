-- Replay-fixture regression: game 20260720_071903, t=4:05. Sven -- zoned out of
-- the bot lane by Lich+Medusa -- drifts 6000u from his lane front (rune spot /
-- river) and farms NOTHING from 2:30 to 5:00 while alive. Root cause found in
-- code review guided by this replay: mode_farm_generic hard-disables farm
-- desire for the entire laning phase, so an off-lane core has no farm option --
-- idling is architecturally forced. J.ShouldLaneRecoverFarm unlocks farm for
-- exactly this case (core + laning phase + >2500 from its lane front).
--
-- World config supplied to the mock: the lane front (where the lane holders
-- stand) and Sven's assigned lane + role. Decision logic runs unstubbed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_071903_sven_idle.lua'
local tests = {}

local ROLES = {
    npc_dota_hero_sven = 1, npc_dota_hero_skywrath_mage = 5,
    npc_dota_hero_dragon_knight = 2, npc_dota_hero_luna = 2,
    npc_dota_hero_silencer = 5,
}

local function armed()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'lf_recover' end
    J.Role.GetPosition = function(u) return ROLES[u:GetUnitName()] or 4 end
    rawget(bot, '__spec').GetAssignedLane = LANE_BOT
    -- The bot-lane front is where its holders stand (Lich at the tower line).
    local front = heroes['npc_dota_hero_lich']:GetLocation()
    GetLaneFrontLocation = function() return front end
    return J, bot, heroes, fx
end

tests['zoned-off core far from its lane may farm'] = function()
    local J, bot = armed()
    assert(J.GetDistanceFromLaneFront(bot) > 2500, 'fixture must be an off-lane frame')
    assert(J.ShouldLaneRecoverFarm(bot) == true,
        'a core 6000u off its lane in the laning phase must be allowed to farm')
end

tests['counterfactual: still on the lane front -> status quo (no farm)'] = function()
    local J, bot, heroes = armed()
    rawget(bot, '__spec').GetLocation = heroes['npc_dota_hero_lich']:GetLocation()
    assert(J.ShouldLaneRecoverFarm(bot) == false,
        'a core at its lane front keeps the laning status quo')
end

tests['counterfactual: supports are not covered'] = function()
    local J, _, heroes = armed()
    local sky = heroes['npc_dota_hero_skywrath_mage']
    rawget(sky, '__spec').GetAssignedLane = LANE_BOT
    assert(J.ShouldLaneRecoverFarm(sky) == false,
        'the unlock is for cores; supports have other jobs')
end

tests['gate off: shipped default is unchanged'] = function()
    local J, bot, heroes = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    GetLaneFrontLocation = function() return heroes['npc_dota_hero_lich']:GetLocation() end
    assert(J.ShouldLaneRecoverFarm(bot) == false,
        'off the candidate the laning-phase farm ban stays absolute')
end

return tests
