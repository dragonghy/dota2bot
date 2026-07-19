-- [GH #3] Turbo "walk, don't channel TP under threat" guard (J.ShouldWalkNotTp).
-- Two contracts:
--   1. Gating: the guard must NEVER ship untested — inert unless the game is
--      turbo AND this side is the active soak candidate carrying 'tpsafe'.
--      Off the candidate side (shipped default, no soak_side file) => false.
--   2. Tightened firing: on the candidate side, it fires ONLY in the narrow
--      "walk two steps and you're safe" case — an enemy ON OUR FACE (~350) that
--      is actively CHASING, with a closer refuge (ally / tower / trees) within a
--      short step. A stationary enemy, an enemy merely "nearby" (>350), or no
--      refuge must all fall through to "let it TP" (false).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local tests = {}

-- Fresh jmz with the bot on TEAM_RADIANT, turbo mode on. (TEAM_RADIANT is 1001
-- once constants load, so GetTeam is pinned after require — the soak-side gate
-- matches this team against side='radiant'.)
local function fresh_jmz(botSpec)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion', botSpec)
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    return J, bot
end

-- Activate the 'tpsafe' soak candidate on radiant by writing the (gitignored)
-- soak_side file, running fn, then cleaning up. reset_modules re-requires
-- jmz_func so its cached GetSoakSideConf re-reads the file.
local function with_candidate(fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'tpsafe' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

-- An enemy hero handle at `loc` that either closes on origin or holds still.
local function make_enemy(loc, futureLoc)
    return api.MakeHero('npc_dota_hero_axe', {
        GetTeam = 3,
        GetLocation = loc,
        GetExtrapolatedLocation = futureLoc or loc,
        GetHealth = 600,
        CanBeSeen = true,   -- J.IsValidHero requires a visible, alive target
    })
end

tests['ShouldWalkNotTp is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldWalkNotTp(bot) == false, 'normal mode must never fire')
end

tests['ShouldWalkNotTp is inert in turbo without an active tpsafe candidate'] = function()
    local J, bot = fresh_jmz()
    -- No soak_side file => IsSoakCandidate('tpsafe') false => guard off.
    assert(J.ShouldWalkNotTp(bot) == false, 'off-candidate must never fire')
end

tests['ShouldWalkNotTp fires: on-face chaser + a tree-line refuge'] = function()
    with_candidate(function()
        local enemy = make_enemy(api.Vector(300, 0, 0), api.Vector(150, 0, 0))
        local J, bot = fresh_jmz({
            GetCurrentMovementSpeed = 300,
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 300 then return { enemy } end
                return {}
            end,
            GetNearbyTrees = function(_, r) return r >= 400 and { 1 } or {} end,
        })
        assert(J.ShouldWalkNotTp(bot) == true,
            'on-face chaser with a tree-line refuge should fire')
    end)
end

tests['ShouldWalkNotTp does NOT fire: enemy is nearby but beyond ~350'] = function()
    with_candidate(function()
        -- Closing, but the ~350 on-face query returns nobody => channel away.
        local enemy = make_enemy(api.Vector(500, 0, 0), api.Vector(350, 0, 0))
        local J, bot = fresh_jmz({
            GetCurrentMovementSpeed = 300,
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 500 then return { enemy } end
                return {}
            end,
            GetNearbyTrees = function() return { 1 } end,
        })
        assert(J.ShouldWalkNotTp(bot) == false,
            'an enemy beyond ~350 can be channelled away from')
    end)
end

tests['ShouldWalkNotTp does NOT fire: on-face enemy is stationary (not chasing)'] = function()
    with_candidate(function()
        local enemy = make_enemy(api.Vector(300, 0, 0), api.Vector(300, 0, 0))
        local J, bot = fresh_jmz({
            GetCurrentMovementSpeed = 300,
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 300 then return { enemy } end
                return {}
            end,
            GetNearbyTrees = function() return { 1 } end,
        })
        assert(J.ShouldWalkNotTp(bot) == false,
            'a stationary on-face enemy can be channelled away from')
    end)
end

tests['ShouldWalkNotTp does NOT fire: chaser on our face but NO closer refuge'] = function()
    with_candidate(function()
        local enemy = make_enemy(api.Vector(300, 0, 0), api.Vector(150, 0, 0))
        local J, bot = fresh_jmz({
            GetCurrentMovementSpeed = 300,
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 300 then return { enemy } end
                return {}   -- no allies within 600
            end,
            GetNearbyTowers = function() return {} end,
            GetNearbyTrees = function() return {} end,
        })
        assert(J.ShouldWalkNotTp(bot) == false,
            'no closer safe point => channeling the TP here is the best option')
    end)
end

tests['ShouldWalkNotTp does NOT fire: too slow to outrun'] = function()
    with_candidate(function()
        local enemy = make_enemy(api.Vector(300, 0, 0), api.Vector(150, 0, 0))
        local J, bot = fresh_jmz({
            GetCurrentMovementSpeed = 200,   -- rooted-slow
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 300 then return { enemy } end
                return {}
            end,
            GetNearbyTrees = function() return { 1 } end,
        })
        assert(J.ShouldWalkNotTp(bot) == false,
            'a near-immobile bot cannot outrun the threat => let it TP')
    end)
end

return tests
