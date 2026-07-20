-- [GH #17] Death-zone avoidance (J.ShouldAvoidDeathZone) gating contract. The
-- "don't walk straight back to the spot you just died at" guard must NEVER
-- ship untested: it is inert unless the game is turbo AND this side is the
-- active soak candidate carrying the 'deathzone' id. Off the candidate side
-- (the shipped default -- no Customize/soak_side file) it must return false so
-- baseline retreat behavior is untouched. It also must only fire on a genuine
-- solo return: with 2+ allies at the death spot, going back is a regroup, not
-- a repeat feed. Mirrors tests/test_corefarm_gate.lua / test_regroup_gate.lua.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local tests = {}

-- Fresh jmz with the bot on TEAM_RADIANT, turbo on. Ancients are pinned to
-- opposite map corners so the "death spot in the enemy half" check (ancient-
-- distance convention) has real geometry: radiant base (-7000,-7000), dire
-- base (7000,7000). A spot like (5000,5000) is deep in the enemy (dire) half.
local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skeleton_king', { CanBeSeen = true })
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    bot.GetTeam = function() return TEAM_RADIANT end   -- same team => not enemy
    GetAncient = function(team)
        if team == TEAM_RADIANT then
            return api.MakeUnit({ GetLocation = api.Vector(-7000, -7000, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(7000, 7000, 0) })
    end
    return J, bot
end

-- Activate the 'deathzone' soak candidate on radiant by writing the
-- (gitignored) soak_side file, running fn, then cleaning up. reset_modules
-- re-requires jmz_func so its cached GetSoakSideConf re-reads the file.
local function with_candidate(fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'deathzone' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

-- Record a death at vSpot: one dead frame at the spot (the helper records
-- location+time on dead frames and must return false there), then respawn.
local function record_death_at(J, bot, vSpot)
    bot.__spec.IsAlive = false
    bot.__spec.GetLocation = vSpot
    assert(J.ShouldAvoidDeathZone(bot) == false,
        'dead frames record the spot and must return false')
    bot.__spec.IsAlive = true
end

tests['ShouldAvoidDeathZone is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldAvoidDeathZone(bot) == false,
        'normal mode must never raise retreat desire via the death-zone guard')
end

tests['ShouldAvoidDeathZone is inert in turbo without an active deathzone candidate'] = function()
    local J, bot = fresh_jmz()
    -- No soak_side file => IsSoakCandidate('deathzone') false => gate off,
    -- shipped baseline retreat behavior untouched even in turbo -- even with
    -- a recorded enemy-half death and the bot right back on the spot.
    bot.__spec.IsAlive = false
    bot.__spec.GetLocation = api.Vector(5000, 5000, 0)
    assert(J.ShouldAvoidDeathZone(bot) == false)
    bot.__spec.IsAlive = true
    assert(J.ShouldAvoidDeathZone(bot) == false,
        'turbo but off-candidate must never fire')
end

tests['ShouldAvoidDeathZone fires on a solo return to a recent enemy-half death spot'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz()
        record_death_at(J, bot, api.Vector(5000, 5000, 0))
        -- Respawned and walked back to ~707u from the spot (< 2200), alone:
        -- mock teammates sit at the origin, ~7071u from the spot, so no ally
        -- is anywhere near it. GameTime() is 0 in the mock => well inside the
        -- 60s post-respawn window.
        bot.__spec.GetLocation = api.Vector(4500, 4500, 0)
        assert(J.ShouldAvoidDeathZone(bot) == true,
            'solo return to a fresh enemy-half death spot must raise retreat')
    end)
end

tests['ShouldAvoidDeathZone does NOT fire when 2+ allies hold the death spot'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz()
        record_death_at(J, bot, api.Vector(5000, 5000, 0))
        bot.__spec.GetLocation = api.Vector(4500, 4500, 0)
        -- Two real allied heroes standing on the spot => returning is a
        -- regroup/push, not a repeat feed. GetAlliesNearLoc walks
        -- GetTeamMember(1..#GetTeamPlayers); slot 1 is the bot itself.
        local function make_ally(i)
            local ally = api.MakeHero('npc_dota_hero_ally_' .. i, {
                CanBeSeen = true,
                GetPlayerID = i,
                GetLocation = api.Vector(5000, 5000, 0),
            })
            ally.is_suspicious_illusion = false
            return ally
        end
        local allies = { [2] = make_ally(2), [3] = make_ally(3) }
        GetTeamMember = function(i)
            if i == 1 then return bot end
            return allies[i]
        end
        assert(J.ShouldAvoidDeathZone(bot) == false,
            'with 2+ allies at the spot, returning is a regroup -> stand down')
    end)
end

return tests
