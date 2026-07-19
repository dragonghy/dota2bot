-- [GH #16] Turbo core farm-desire preservation (J.ShouldCoreKeepFarming) gating
-- contract. The farm-cap lift must NEVER ship untested: it is inert unless the
-- game is turbo AND this side is the active soak candidate carrying the
-- 'corefarm' id. Off the candidate side (the shipped default -- no Customize/
-- soak_side file) it must return false so baseline farm desire is untouched.
-- It is also CORE-only (pos 1-3): supports under-farming is expected/fine.
-- Mirrors tests/test_regroup_gate.lua and tests/test_tpsafe_gate.lua.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local tests = {}

-- Fresh jmz with the bot on TEAM_RADIANT, turbo on. `role` (optional) pins the
-- bot's position via the assignedRole property J.GetPosition reads; the bot is
-- also pinned to TEAM_RADIANT so GetPosition doesn't treat it as an enemy.
local function fresh_jmz(role, botSpec)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skeleton_king', botSpec)
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    bot.GetTeam = function() return TEAM_RADIANT end   -- same team => not enemy
    if role ~= nil then bot.assignedRole = role end
    return J, bot
end

-- Activate the 'corefarm' soak candidate on radiant by writing the (gitignored)
-- soak_side file, running fn, then cleaning up. reset_modules re-requires
-- jmz_func so its cached GetSoakSideConf re-reads the file.
local function with_candidate(fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'corefarm' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

tests['ShouldCoreKeepFarming is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldCoreKeepFarming(bot) == false,
        'normal mode must never lift the farm cap')
end

tests['ShouldCoreKeepFarming is inert in turbo without an active corefarm candidate'] = function()
    local J, bot = fresh_jmz()
    -- No soak_side file => IsSoakCandidate('corefarm') false => gate off,
    -- shipped baseline farm desire untouched even in turbo.
    assert(J.ShouldCoreKeepFarming(bot) == false,
        'turbo but off-candidate must never lift the farm cap')
end

tests['ShouldCoreKeepFarming fires for a safe idle core on the candidate side'] = function()
    with_candidate(function()
        -- role 1 => a carry core; CanBeSeen makes it a valid hero; no hero
        -- damage / no nearby enemies / no team fight all come from mock
        -- defaults (Was*/GetNearby* => false/{}).
        local J, bot = fresh_jmz(1, { CanBeSeen = true })
        assert(J.ShouldCoreKeepFarming(bot) == true,
            'a safe, idle core with no worthwhile fight should keep farming')
    end)
end

tests['ShouldCoreKeepFarming does NOT fire for a support (pos 5)'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz(5, { CanBeSeen = true })
        assert(J.ShouldCoreKeepFarming(bot) == false,
            'supports farming less is fine -- gate is core-only')
    end)
end

tests['ShouldCoreKeepFarming does NOT fire for a core being hero-focused'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz(2, {
            CanBeSeen = true,
            WasRecentlyDamagedByAnyHero = true,   -- under hero fire => go answer it
        })
        assert(J.ShouldCoreKeepFarming(bot) == false,
            'a focused core should retreat/fight, not tunnel creeps')
    end)
end

return tests
