-- [GH #6] Aegis-carrier grouping (J.ShouldGroupWithAegis) contract. When our
-- team has taken Roshan and THIS bot holds the aegis, it must not solo-dive the
-- enemy jungle/triangle/backlines -- it should regroup and press WITH the team.
-- The shipped #6 J.ShouldRegroupNotSolo only suppresses solo overextension when
-- an enemy is already within 1500; the aegis feed is the carrier walking in
-- ALONE BEFORE contact, so this guard fires WITHOUT requiring a nearby enemy --
-- carrying the aegis alone deep in enemy territory is itself the mistake.
--
-- Like every gated fix it must NEVER ship untested: inert unless the game is
-- turbo AND this side is the active soak candidate carrying the 'aegisgroup'
-- id. Off the candidate side (the shipped default -- no Customize/soak_side
-- file) it must return false so baseline farm/push is untouched. Mirrors
-- tests/test_deathzone_gate.lua / test_regroup_gate.lua.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local tests = {}

-- Fresh jmz with the bot on TEAM_RADIANT, turbo on. Ancients pinned to opposite
-- map corners so the "deep in the enemy half" check (ancient-distance
-- convention) has real geometry: radiant base (-7000,-7000), dire base
-- (7000,7000). A spot like (5000,5000) is deep in the enemy (dire) half.
-- By default the bot carries the aegis, sits deep, and is alone (mock
-- teammates sit at the origin, ~7071u away). Each test flips one knob.
local function fresh_jmz(opts)
    opts = opts or {}
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skeleton_king', {
        CanBeSeen = true,
        GetLocation = api.Vector(5000, 5000, 0),   -- deep in the dire half
        HasModifier = function(_, name)
            if opts.noAegis then return false end
            return name == 'modifier_item_aegis'
        end,
    })
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    bot.GetTeam = function() return TEAM_RADIANT end
    GetAncient = function(team)
        if team == TEAM_RADIANT then
            return api.MakeUnit({ GetLocation = api.Vector(-7000, -7000, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(7000, 7000, 0) })
    end
    return J, bot
end

-- Activate the 'aegisgroup' soak candidate on radiant by writing the
-- (gitignored) soak_side file, running fn, then cleaning up. reset_modules
-- re-requires jmz_func so its cached GetSoakSideConf re-reads the file.
local function with_candidate(fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'aegisgroup' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

-- Stand a real allied hero at vLoc so "alone" is broken (grouped press).
local function with_ally_at(vLoc, fn)
    local ally = api.MakeHero('npc_dota_hero_ally', {
        CanBeSeen = true, GetPlayerID = 2, GetLocation = vLoc,
    })
    ally.is_suspicious_illusion = false
    local prev = GetTeamMember
    GetTeamMember = function(i)
        if i == 1 then return GetBot() end
        if i == 2 then return ally end
        return prev(i)
    end
    fn()
    GetTeamMember = prev
end

tests['FIRE: turbo + armed, holds aegis, deep, alone -> suppress (regroup)'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz()
        assert(J.ShouldGroupWithAegis(bot) == true,
            'a lone aegis-carrier deep in enemy territory must be told to regroup')
    end)
end

tests['NO-FIRE: grouped (ally within 1500) -> false'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz()
        with_ally_at(api.Vector(5200, 5200, 0), function()
            assert(J.ShouldGroupWithAegis(bot) == false,
                'with an ally near, pressing with the team is fine -> fall through')
        end)
    end)
end

tests['NO-FIRE: no aegis modifier -> false'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz({ noAegis = true })
        assert(J.ShouldGroupWithAegis(bot) == false,
            'without the aegis this guard adds no caution beyond the shipped ones')
    end)
end

tests['NO-FIRE: on our own half (not deep) -> false'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz()
        bot.__spec.GetLocation = api.Vector(-5000, -5000, 0)  -- our (radiant) half
        assert(J.ShouldGroupWithAegis(bot) == false,
            'carrying the aegis on our own half is not an overextension')
    end)
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz()
        GetGameMode = function() return 1 end
        assert(J.ShouldGroupWithAegis(bot) == false,
            'normal mode must never suppress via the aegis-grouping guard')
    end)
end

tests['OFF: inert off the soak candidate (shipped default)'] = function()
    -- No soak_side file written -> IsSoakCandidate('aegisgroup') is false.
    local J, bot = fresh_jmz()
    assert(J.ShouldGroupWithAegis(bot) == false,
        'off the candidate side the guard must stay inert (shipped default)')
end

return tests
