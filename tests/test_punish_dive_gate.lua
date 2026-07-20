-- [GH #7] Punish-the-dive gating contract. The disciplined collapse-on-a-diver
-- trigger must NEVER ship untested: J.ShouldPunishDive is inert unless the game
-- is turbo AND this side is the active soak candidate carrying the 'punish' id.
-- Off the candidate side (the shipped default -- no Customize/soak_side file) it
-- must return nil so baseline aggression is untouched. This mirrors the
-- test_nodive_gate.lua contract for the anti-dive guard.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

tests['ShouldPunishDive is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldPunishDive(bot) == nil,
        'normal mode must never trigger a punish collapse')
end

tests['ShouldPunishDive in turbo is live but stays off with no dive present (PROMOTED)'] = function()
    -- PROMOTED under the Class-B micro-behavior policy (runbook §1): turbo no
    -- longer requires a soak candidate. The default mock has no allied buildings
    -- and no nearby overextended enemy, so the trigger must still return nil —
    -- proving promotion didn't make it collapse without an actual dive.
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    assert(J.ShouldPunishDive(bot) == nil,
        'turbo with no dive present must not trigger a punish collapse')
end

return tests
