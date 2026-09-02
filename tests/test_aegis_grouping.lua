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

local ss = require('mock.soak_side')               -- owns bots/Customize/soak_side.lua

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
-- [GH #365 §3 / GH #417 / GH #229, hero backlog `-78`] The write goes through
-- tests/mock/soak_side.lua, the switch's one owner: the bytes are read back,
-- an existing switch this process did not write is reported instead of
-- clobbered, and the switch is re-read after the case body so a concurrent
-- removal is reported as itself rather than as the unarmed false it produces.
local function with_candidate(fn)
    ss.with_candidate('aegisgroup', fn)
end

-- The state this process STARTED in, taken at file-load time -- the only
-- moment that sees it. Measured on this file (hero 20260902T225428Z): with a
-- leftover `cand = 'aegisgroup'` planted before the run, the whole file is
-- 6/6 GREEN, while the one unarmed case run ALONE under the same leftover is
-- RED -- the armed cases sort first and their unconditional `os.remove` threw
-- the stranger's switch away before the unarmed case could be told about it.
ss.assert_clean('test_aegis_grouping')

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
    -- The nil leg of the owner PROVES that rather than assuming it: it checks
    -- the switch is absent before the body and again after, so an inherited or
    -- concurrently-written switch is named here instead of quietly turning
    -- this case into a second armed one.
    ss.with_candidate(nil, function()
        local J, bot = fresh_jmz()
        assert(J.ShouldGroupWithAegis(bot) == false,
            'off the candidate side the guard must stay inert (shipped default)')
    end)
end

return tests
