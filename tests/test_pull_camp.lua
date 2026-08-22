-- [GH #13] Gating + trigger contract for J.ShouldPullNeutralCamp -- the turbo
-- laning creep-pull that resets a bad lane equilibrium. A support (pos 4-5)
-- pulls the nearby friendly neutral camp in the :12/:42 windows WHEN our lane
-- creep wave is pushed the wrong way (front past the lane midpoint toward the
-- enemy), a friendly camp is up and within reach, and no enemy is on us.
--
-- FIRE = every condition holds -> returns the camp's spawn location (pull intent).
-- NO-FIRE = favorable equilibrium / no camp in reach / wrong time / wrong role /
--           under threat -> nil (keep laning; never grief the lane).
-- OFF = not turbo / not the 'pullcamp' candidate -> nil (shipped default inert).
--
-- [GH #13 SILENT root cause, 20260822] THIS CONTRACT CHANGED, and this file
-- caught the change -- the `noCreeps` case below used to be a NO-FIRE and is now
-- a FIRE. "Is the camp up" is no longer a trigger condition: a support standing
-- in its lane has no vision into a camp box behind trees, so
-- `GetNearbyNeutralCreeps(1400)` was empty on exactly the frames the pull wanted
-- to start (measured 0 / 911 alive hero frames over the whole fixture corpus)
-- while `mode_roam_generic`'s walk-to-the-camp branch was only reachable once
-- the plan already existed. Trigger waited for arrival, arrival waited for
-- trigger, and the replay desk measured 10/10 games SILENT. The question MOVED
-- to roam's Think, which asks the same read on ARRIVAL (bCampHere) and pokes
-- only when the neutrals are really there. The window also gained a 5s travel
-- lead (:05-:20 / :35-:50) so the walk out of lane finishes by the :12 / :42
-- aggro marks, which are themselves unchanged.
-- See tests/test_pullcamp_trigger_census.lua and
-- iterations/reports/strategy/20260822T073000Z.md.
--
-- The clock is mocked via DotaTime; the lane-front / midpoint / ancient and the
-- neutral-camp spawner list are stubbed so the equilibrium and camp-reach reads
-- are deterministic under the mock Bot API.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Build the full pull scenario with every condition satisfied (FIRE). Each opt
-- flips exactly one knob to drive a NO-FIRE / OFF branch:
--   core        -> bot is a core (pos <= 3), not a support puller
--   now         -> DotaTime override (wrong pull window / outside laning)
--   favorable   -> lane front NOT past the midpoint (equilibrium is fine)
--   noCamp      -> the neutral spawner list has no friendly camp in reach
--   noCreeps    -> the camp is not visibly up (no neutral creeps nearby). Since
--                  the GH #13 repair this is NOT a veto -- see the header.
--   underThreat -> an enemy hero is right on us
--   botX/campX  -> move the bot / the friendly camp along the lane axis, to
--                  place the camp on either side of the midpoint (GH #117)
local function scenario(opts)
    opts = opts or {}
    api.reset_modules()

    local neutral = api.MakeUnit({ IsAlive = true, GetTeam = 4 }) -- TEAM_NEUTRAL-ish

    local bot = api.MakeHero('npc_dota_hero_lion', {
        GetLocation = api.Vector(opts.botX or 0, 0, 0),
        GetAssignedLane = 1, -- non-nil lane id
        GetNearbyNeutralCreeps = function()
            if opts.noCreeps then return {} end
            return { neutral }
        end,
    })
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    -- Arm the gate: turbo + the 'pullcamp' soak candidate on this side.
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
    J.IsSoakCandidate = function(id) return id == 'pullcamp' end

    -- Role: support (not a core) unless the wrong-role knob is flipped.
    J.IsCore = function() return opts.core == true end

    -- Clock: 1:45 by default -> laning window, seconds-into-minute 45 (in the
    -- :42 pull window [40,50]). Overridable for the wrong-time cases.
    DotaTime = function() return opts.now or 105 end -- luacheck: ignore

    -- Threat: nobody on us unless underThreat.
    J.GetEnemiesNearLoc = function()
        if opts.underThreat then
            return { api.MakeHero('npc_dota_hero_enemy', { GetTeam = 3 }) }
        end
        return {}
    end

    -- Lane equilibrium. Own ancient at origin; midpoint 3000 out; the lane front
    -- is pushed to 4000 (PAST the midpoint toward the enemy -> unfavorable) unless
    -- 'favorable', where it sits at 2000 (short of the midpoint -> nothing to fix).
    GetAncient = function() return api.MakeUnit({ GetLocation = api.Vector(0, 0, 0) }) end -- luacheck: ignore
    GetLocationAlongLane = function() return api.Vector(3000, 0, 0) end -- luacheck: ignore
    GetLaneFrontLocation = function() -- luacheck: ignore
        if opts.favorable then return api.Vector(2000, 0, 0) end
        return api.Vector(4000, 0, 0)
    end

    -- Neutral spawners: one friendly camp 500u away (within the 1500 reach) unless
    -- 'noCamp' (empty list -> no camp to pull).
    GetNeutralSpawners = function() -- luacheck: ignore
        if opts.noCamp then return {} end
        return { { team = GetTeam(), type = 'small',
                   location = api.Vector(opts.campX or 500, 0, 0) } }
    end

    return J, bot
end

tests['FIRE: support, bad equilibrium, camp up in reach, pull window -> camp loc'] = function()
    local J, bot = scenario()
    local res = J.ShouldPullNeutralCamp(bot)
    assert(res ~= nil and res.x == 500,
        'the clear pull case must return the friendly camp spawn location as the pull intent')
end

tests['NO-FIRE: favorable equilibrium (lane not pushed) -> nil'] = function()
    local J, bot = scenario({ favorable = true })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'a lane that is even/in our favor has nothing to reset -- never pull')
end

tests['NO-FIRE: a friendly camp PAST the lane midpoint -> nil (GH #117)'] = function()
    -- Same scenario, camp moved from 500u out to 3500u out: still ours, still
    -- inside the 1500 reach of a bot standing at 3000, but now deeper than the
    -- midpoint (3000) and therefore not a pull camp -- neutrals dragged from
    -- there cannot meet our wave. Real-frame coverage of this clause lives in
    -- tests/test_pullcamp_ownside_camp.lua; this is the contract statement.
    local J, bot = scenario({ campX = 3500, botX = 3000 })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'a camp past the lane midpoint is pullable again -- that is the GH #117 '
        .. 'defect, and it connects <= 20.3% of the time')
end

tests['NO-FIRE: no friendly camp in the spawner list -> nil'] = function()
    local J, bot = scenario({ noCamp = true })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'with no friendly camp in reach there is nothing to pull')
end

tests['FIRE: no VISIBLE neutrals is no longer a veto (the GH #13 repair)'] = function()
    -- The case that used to read `NO-FIRE: camp not up -> nil`. It is inverted
    -- deliberately: from the lane this read is empty whether or not the camp is
    -- up, so vetoing on it vetoed every real pull. Occupancy is now decided on
    -- arrival by roam's Think.
    local J, bot = scenario({ noCreeps = true })
    local res = J.ShouldPullNeutralCamp(bot)
    assert(res ~= nil and res.x == 500,
        'the trigger vetoes on camp vision again -- that is the dead condition '
        .. 'that made pullcamp SILENT in 10/10 batch games')
end

tests['FIRE: the travel lead opens the window at :05 (walk, then aggro at :12)'] = function()
    local J, bot = scenario({ now = 65 }) -- 1:05 -> 5s into the minute
    local res = J.ShouldPullNeutralCamp(bot)
    assert(res ~= nil and res.x == 500,
        'the window no longer opens early enough to walk to the camp -- a bot '
        .. 'that leaves lane at :12 arrives after the wave has gone')
end

tests['FIRE: the travel lead opens the second window at :35'] = function()
    local J, bot = scenario({ now = 95 }) -- 1:35 -> 35s into the minute
    local res = J.ShouldPullNeutralCamp(bot)
    assert(res ~= nil and res.x == 500, 'the :35 lead into the :42 mark is gone')
end

tests['NO-FIRE: the lead is a lead, not an open door (:25 is still nothing)'] = function()
    local J, bot = scenario({ now = 85 }) -- 1:25 -> 25s into the minute
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the travel lead widened the window into an always-on pull')
end

tests['NO-FIRE: :04 is before the lead (nothing to walk toward yet)'] = function()
    local J, bot = scenario({ now = 124 }) -- 2:04 -> 4s into the minute
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the window lost its lower edge')
end

tests['FIRE: the :12 window also pulls (catch the :00 wave)'] = function()
    local J, bot = scenario({ now = 73 }) -- 1:13 -> 13s into the minute, in [10,20]
    local res = J.ShouldPullNeutralCamp(bot)
    assert(res ~= nil and res.x == 500,
        'the :12 window (to intercept the :00 wave) must pull just like the :42 window')
end

tests['NO-FIRE: outside both pull windows (mid-minute) -> nil'] = function()
    local J, bot = scenario({ now = 90 }) -- 1:30 -> 30s into the minute, between the windows
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'pulling only in the :12 [5,20] / :42 [35,50] windows (each opens a 5s '
        .. 'travel lead before its aggro mark); :30 must fall through')
end

tests['NO-FIRE: before camps spawn / outside laning -> nil'] = function()
    local J, bot = scenario({ now = 45 }) -- 0:45, camps not spawned yet
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'before 1:00 (camps not up) the pull must not fire')
end

tests['NO-FIRE: wrong role (a core) -> nil'] = function()
    local J, bot = scenario({ core = true })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'cores stay to farm/deny -- only supports leave the lane to pull')
end

tests['NO-FIRE: an enemy is right on us -> nil'] = function()
    local J, bot = scenario({ underThreat = true })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'pulling under threat feeds a death -- never pull with an enemy on us')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    local J, bot = scenario()
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'normal mode must never trigger a pull (shipped default unchanged)')
end

tests['OFF: inert off the soak candidate'] = function()
    local J, bot = scenario()
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'off the pullcamp candidate the trigger stays inert (shipped default)')
end

return tests
