-- IsModeTurbo must use the engine's GetGameMode() when available instead of
-- the courier-speed heuristic (which silently reports "normal mode" if a
-- patch changes courier speed, turning off every turbo pacing adaptation).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func')
end

tests['IsModeTurbo detects turbo via GetGameMode and caches it'] = function()
    local J = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    assert(J.IsModeTurbo() == true, 'should detect turbo via GetGameMode')
    GetGameMode = function() return 1 end
    assert(J.IsModeTurbo() == true, 'mode result must be cached for the match')
end

tests['IsModeTurbo reports non-turbo for other modes'] = function()
    local J = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.IsModeTurbo() == false, 'all-pick must not read as turbo')
end

return tests
