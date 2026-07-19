-- [GH #6] Anti-solo-overextend (regroup) gating contract. The solo farm/push
-- suppression must NEVER ship untested: J.ShouldRegroupNotSolo is inert unless
-- the game is turbo AND this side is the active soak candidate carrying the
-- 'regroup' id. Off the candidate side (the shipped default -- no Customize/
-- soak_side file) it must return false so baseline farming/pushing is
-- untouched. Mirrors tests/test_nodive_gate.lua.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skeleton_king')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

tests['ShouldRegroupNotSolo is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldRegroupNotSolo(bot) == false,
        'normal mode must never suppress solo farm/push')
end

tests['ShouldRegroupNotSolo is inert in turbo without an active regroup candidate'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    -- No Customize/soak_side file in CI => IsSoakCandidate('regroup') is false,
    -- so the gate stays off even in turbo (shipped baseline behavior).
    assert(J.ShouldRegroupNotSolo(bot) == false,
        'turbo but off-candidate must never suppress solo farm/push')
end

return tests
