-- Replay-fixture regression: game 20260720_073148, t=5:50. Zeus (FOCUS hero)
-- at 82% HP stands 980u from the mid Lina who has ALREADY 100-0'd him twice
-- (2:48 burst 474, 4:39 burst 789) -- and she kills him again 5.9s after this
-- frame (904 damage), then once more at 10:02 (1063). No existing guard can
-- fire: he is healthy, 1v1, not diving. J.ShouldRespectProvenKiller adds the
-- missing memory: an enemy credited 2+ kills on me, in range, while I am solo
-- -> keep distance.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_073148_zuus_lina.lua'
local tests = {}

-- Arm the world and replay Zeus's two earlier deaths through the real
-- record-only path (dead frame next to Lina), exactly as mode_retreat_generic
-- records them in game.
local function armed(credits)
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'lf_threat' end
    local lina = heroes['npc_dota_hero_lina']
    local spec = rawget(bot, '__spec')
    local live_loc = bot:GetLocation()
    for i = 1, (credits or 2) do
        spec.IsAlive = false
        spec.GetLocation = lina:GetLocation()
        GameTime = function() return 100 * i end -- distinct deaths (>15s apart)
        J.NoteProvenKillerOnDeath(bot)
    end
    spec.IsAlive = true
    spec.GetLocation = live_loc
    GameTime = function() return fx.time end
    return J, bot, heroes, fx
end

tests['ground truth: she killed him again from this frame'] = function()
    local _, _, _, fx = armed()
    assert(fx.observed.died_after ~= nil and fx.observed.died_after < 10
        and (fx.observed.burst['npc_dota_hero_lina'] or 0) > 500,
        'fixture must capture the repeat Lina kill')
end

tests['fires: solo Zeus inside a 2-kill Lina range'] = function()
    local J, bot = armed(2)
    assert(J.GetHP(bot) > 0.7, 'the real frame is healthy HP -- memory-based, not HP-based')
    assert(J.ShouldRespectProvenKiller(bot) == true,
        'an enemy who proved she wins this 1v1 outright must be kept at distance')
end

tests['counterfactual: a single kill could be a fluke -> no fire'] = function()
    local J, bot = armed(1)
    assert(J.ShouldRespectProvenKiller(bot) == false,
        'one death does not make a proven killer')
end

tests['counterfactual: with backup the trade is no longer the proven 1v1'] = function()
    local J, bot, heroes = armed(2)
    rawget(heroes['npc_dota_hero_skywrath_mage'], '__spec').GetLocation = bot:GetLocation()
    assert(J.ShouldRespectProvenKiller(bot) == false,
        'an ally in range changes the matchup; do not flee a winnable 2v1')
end

tests['counterfactual: killer out of range -> farm in peace'] = function()
    local J, bot, heroes = armed(2)
    local lina = heroes['npc_dota_hero_lina']
    rawget(lina, '__spec').GetLocation = Vector(4000, 4000, 0)
    assert(J.ShouldRespectProvenKiller(bot) == false,
        'respect means distance, not abandoning the lane')
end

tests['gate off: shipped default is unchanged'] = function()
    local J, bot = armed(2)
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldRespectProvenKiller(bot) == false,
        'off the candidate the guard must stay inert')
end

return tests
