-- [replay-review] Lane mana-discipline gating contract. J.ShouldConserveManaInLane
-- is inert unless turbo AND the 'lanefix' soak candidate is active. When armed it
-- fires ONLY in the laning phase, when mana is below the reserve, and no kill is
-- on the table (a killable enemy in range lets the cast through).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_zuus')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

tests['ShouldConserveManaInLane is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldConserveManaInLane(bot) == false, 'normal mode never conserves')
end

tests['ShouldConserveManaInLane is inert off the soak candidate'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldConserveManaInLane(bot) == false, 'off candidate: unchanged')
end

-- Armed: turbo + gate on + laning phase + no enemies near.
local function armed(bot_spec)
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function(id) return id == 'lanefix' end
    DotaTime = function() return 120 end          -- laning phase
    J.GetEnemiesNearLoc = function() return {} end
    for k, v in pairs(bot_spec or {}) do
        rawget(bot, '__spec')[k] = v
    end
    return J, bot
end

tests['fires when low mana in lane and no kill available'] = function()
    local J, bot = armed({ GetMana = 90, GetMaxMana = 600 })  -- 15%
    assert(J.ShouldConserveManaInLane(bot) == true, 'low mana, no kill -> conserve')
end

tests['does NOT fire when mana is above the reserve'] = function()
    local J, bot = armed({ GetMana = 300, GetMaxMana = 600 }) -- 50%
    assert(J.ShouldConserveManaInLane(bot) == false, 'enough mana -> cast freely')
end

tests['does NOT fire past the laning phase'] = function()
    local J, bot = armed({ GetMana = 90, GetMaxMana = 600 })
    DotaTime = function() return 11 * 60 end
    assert(J.ShouldConserveManaInLane(bot) == false, 'after laning -> unrestricted')
end

tests['does NOT fire when a killable enemy is in range'] = function()
    local J, bot = armed({ GetMana = 90, GetMaxMana = 600 })
    -- J.GetHP reads GetHealth/GetMaxHealth for an enemy-team unit.
    local e = api.MakeHero('npc_dota_hero_enemy_a',
        { GetTeam = 3, CanBeSeen = true, GetHealth = 100, GetMaxHealth = 600 })
    J.GetEnemiesNearLoc = function() return { e } end
    assert(J.ShouldConserveManaInLane(bot) == false, 'a kill on the table lets the cast through')
end

return tests
