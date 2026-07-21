-- Replay-fixture regression: game 20260720_071859, t=3:12. Queen of Pain at 34%
-- HP, SAFE (no enemy hero within 1000), holding an unused Healing Salve -- and
-- she stayed hurt for the next 10+ s. The owner's review (of the same pattern
-- on Luna/Sven): "状态变差了却不买/不用大药,对线打得很僵". The fixed decision:
-- use the salve. Real helpers on the real frame; no J.* stubs.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_071859_qop_salve.lua'
local tests = {}

local function armed()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'lf_salve' end
    return J, bot, heroes, fx
end

tests['uses the held salve on the real hurt-and-safe frame'] = function()
    local J, bot = armed()
    assert(J.GetHP(bot) < 0.55, 'fixture must be a hurt frame')
    local item = J.LaneRegenItemToUse(bot)
    assert(item ~= nil and item:GetName() == 'item_flask',
        'hurt + safe + salve in inventory -> drink it')
end

tests['counterfactual: an enemy nearby means it is not safe to salve'] = function()
    local J, bot, heroes = armed()
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            -- Walk one enemy on top of QoP: channel would be broken / punished.
            rawget(h, '__spec').GetLocation = bot:GetLocation()
            break
        end
    end
    assert(J.LaneRegenItemToUse(bot) == nil,
        'enemy in range -> do not stand still drinking')
end

tests['counterfactual: healthy hero saves the salve'] = function()
    local J, bot = armed()
    rawget(bot, '__spec').GetHealth = bot:GetMaxHealth()
    rawget(bot, '__spec').OriginalGetHealth = bot:GetMaxHealth()
    assert(J.LaneRegenItemToUse(bot) == nil,
        'healthy -> keep the salve for later')
end

tests['gate off: shipped default is unchanged'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    assert(J.LaneRegenItemToUse(bot) == nil,
        'off the candidate the helper must stay inert')
end

return tests
