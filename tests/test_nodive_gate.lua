-- [GH #4] Anti-suicide-dive guard gating contract. The dive suppression must
-- NEVER ship untested: J.ShouldSuppressDive is inert unless the game is turbo
-- AND this side is the active soak candidate carrying the 'nodive' id. Off the
-- candidate side (the shipped default -- no Customize/soak_side file) it must
-- return false so baseline aggression is untouched. Also pins the trivial
-- J.SafeToCommitFight contract for a missing target (nothing to gate => safe).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

tests['ShouldSuppressDive is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == false,
        'normal mode must never suppress a dive')
end

tests['ShouldSuppressDive is inert in turbo without an active nodive candidate'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    -- No Customize/soak_side file in CI => IsSoakCandidate('nodive') is false,
    -- so the guard stays off even in turbo (shipped baseline behavior).
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == false,
        'turbo but off-candidate must never suppress a dive')
end

tests['SafeToCommitFight treats a missing target as safe'] = function()
    local J, bot = fresh_jmz()
    assert(J.SafeToCommitFight(bot, nil) == true,
        'no valid target means there is no dive to gate')
end

return tests
