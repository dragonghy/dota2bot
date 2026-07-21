-- Replay-fixture regression: game 20260720_072738, t=2:40. Zeus in lane at
-- 148/495 mana (30%) with a 59%-HP enemy nearby -- no kill on the table. The
-- owner's review: "技能用得太频繁,蓝耗撑不住" -- harass casts at low mana leave
-- Zeus unable to trade or secure a real kill (he died 54s after this frame).
-- Real helpers on the real frame; no J.* stubs.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_072738_zuus_mana.lua'
local tests = {}

local function armed()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'lf_mana' end
    return J, bot, heroes, fx
end

tests['conserves mana on the real low-mana lane frame'] = function()
    local J, bot = armed()
    assert(bot:GetMana() / bot:GetMaxMana() < 0.35, 'fixture must be a low-mana frame')
    assert(J.ShouldConserveManaInLane(bot) == true,
        'low mana + no killable enemy in range -> hold the harass cast')
end

tests['counterfactual: a killable enemy in range lets the cast through'] = function()
    local J, bot, heroes = armed()
    -- Drop the nearby enemy to kill range: securing a kill is worth the mana.
    for name, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            local d = GetUnitToUnitDistance(bot, h)
            if d < 900 then
                rawget(h, '__spec').GetHealth = math.floor(h:GetMaxHealth() * 0.3)
                break
            end
        end
    end
    assert(J.ShouldConserveManaInLane(bot) == false,
        'a kill on the table must not be blocked by mana conservation')
end

tests['counterfactual: healthy mana pool casts freely'] = function()
    local J, bot = armed()
    rawget(bot, '__spec').GetMana = bot:GetMaxMana()
    assert(J.ShouldConserveManaInLane(bot) == false,
        'full mana -> no conservation')
end

tests['gate off: shipped default is unchanged'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldConserveManaInLane(bot) == false,
        'off the candidate the guard must stay inert')
end

return tests
