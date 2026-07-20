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

tests['ShouldRegroupNotSolo in turbo is live but stays off on our own half (PROMOTED)'] = function()
    -- PROMOTED under the Class-B micro-behavior policy (runbook §1): turbo no
    -- longer requires a soak candidate. The default mock bot sits at the origin
    -- (own half / not past the enemy ancient midline), so the guard must still
    -- fall through — proving promotion didn't make it fire outside the narrow
    -- "deep + alone + contested" case.
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    assert(J.ShouldRegroupNotSolo(bot) == false,
        'turbo bot on its own half must not be regroup-suppressed')
end

return tests
