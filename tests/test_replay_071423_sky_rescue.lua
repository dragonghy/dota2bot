-- Replay-fixture regression: game 20260720_071423, t=3:55. Luna (13% HP) is
-- being chased down top by Jakiro+Slardar and dies 3.5s later; Skywrath Mage
-- idles near the fountain at 64% HP with TP READY and never uses it. The owner:
-- "如果天怒能TP上路一塔,大概率能反抓,至少能保护露娜". The fixed decision:
-- J.GetRescueTpTarget(sky) must pick Luna. Real helpers on the real frame.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_071423_sky_rescue.lua'
local tests = {}

local function armed()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'lf_rescue' end
    return J, bot, heroes, fx
end

tests['picks the dying far-away carry as the rescue target'] = function()
    local J, bot, heroes = armed()
    assert(J.GetRescueTpTarget(bot) == heroes['npc_dota_hero_luna'],
        'healthy Skywrath with TP ready must TP for the dived Luna')
end

tests['counterfactual: TP on cooldown -> no rescue'] = function()
    local J, bot, heroes = armed()
    -- Re-arm the TP slot as on-cooldown.
    local spec = rawget(bot, '__spec')
    local orig = spec.GetItemInSlot
    spec.GetItemInSlot = function(self, i)
        local it = orig(self, i)
        if it ~= nil and it:GetName() == 'item_tpscroll' then
            rawget(it, '__spec').IsFullyCastable = false
        end
        return it
    end
    assert(J.GetRescueTpTarget(bot) == nil, 'no TP, no rescue')
end

tests['counterfactual: rescuer too hurt -> no rescue'] = function()
    local J, bot = armed()
    rawget(bot, '__spec').GetHealth = 200
    rawget(bot, '__spec').OriginalGetHealth = 200
    assert(J.GetRescueTpTarget(bot) == nil,
        'a low-HP rescuer TPing in just feeds a second death')
end

tests['counterfactual: 3+ divers -> do not TP into the pile'] = function()
    -- At the real frame only Slardar is inside 900 (Jakiro sits at 907), so it
    -- takes TWO moved enemies to reach the 3-diver threshold.
    local J, bot, heroes = armed()
    local luna = heroes['npc_dota_hero_luna']
    rawget(heroes['npc_dota_hero_queen_of_pain'], '__spec').GetLocation =
        luna:GetLocation()
    rawget(heroes['npc_dota_hero_lich'], '__spec').GetLocation =
        luna:GetLocation()
    assert(J.GetRescueTpTarget(bot) == nil,
        'TPing into 3 enemies is not a rescue, it is a donation')
end

tests['counterfactual: healthy ally -> nothing to rescue'] = function()
    local J, bot, heroes = armed()
    local luna = heroes['npc_dota_hero_luna']
    rawget(luna, '__spec').GetHealth = luna:GetMaxHealth()
    rawget(luna, '__spec').OriginalGetHealth = luna:GetMaxHealth()
    assert(J.GetRescueTpTarget(bot) == nil, 'no one in danger, keep the TP')
end

tests['gate off: shipped default is unchanged'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    assert(J.GetRescueTpTarget(bot) == nil,
        'off the candidate the helper must stay inert')
end

return tests
