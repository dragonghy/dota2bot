-- Farm-only overtime forfeit (J.IsSoakOvertime): past 40 game-minutes on a
-- soak-farm instance the match must wind down (defend released, push maxed).
-- Ship safety is the critical property: without the farm-only
-- Customize/soak_pool.lua file it must ALWAYS be false.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local POOL_PATH = 'bots/Customize/soak_pool.lua'   -- gitignored, farm-only

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func')
end

local function write_pool()
    local f = assert(io.open(POOL_PATH, 'w'))
    f:write("return { 'axe', 'zuus', 'lion', 'lich', 'sven', 'luna', 'viper', 'medusa', 'jakiro', 'sniper', 'tidehunter' }\n")
    f:close()
end

local tests = {}

tests['overtime: false before the cap, true after, on a farm instance'] = function()
    write_pool()
    local ok, err = pcall(function()
        local J = fresh_jmz()
        DotaTime = function() return 39 * 60 end
        assert(J.IsSoakOvertime() == false, 'before 40 game-min must not be overtime')
        DotaTime = function() return 41 * 60 end
        assert(J.IsSoakOvertime() == true, 'past 40 game-min on the farm must be overtime')
    end)
    os.remove(POOL_PATH)
    if not ok then error(err, 0) end
end

tests['overtime: always false without the farm pool file (ship safety)'] = function()
    os.remove(POOL_PATH)
    local J = fresh_jmz()
    DotaTime = function() return 300 * 60 end
    assert(J.IsSoakOvertime() == false, 'must be inert without Customize/soak_pool.lua')
end

return tests
