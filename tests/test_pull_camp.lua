-- [GH #13] Gating + trigger contract for J.ShouldPullNeutralCamp -- the turbo
-- laning creep-pull that resets a bad lane equilibrium. A support (pos 4-5)
-- pulls the nearby friendly neutral camp in the ~:47/:55 window WHEN our lane
-- creep wave is pushed the wrong way (front past the lane midpoint toward the
-- enemy), a friendly camp is up and within reach, and no enemy is on us.
--
-- FIRE = every condition holds -> returns the camp's spawn location (pull intent).
-- NO-FIRE = favorable equilibrium / no camp up / wrong time / wrong role / under
--           threat -> nil (keep laning; never grief the lane).
-- OFF = not turbo / not the 'pullcamp' candidate -> nil (shipped default inert).
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
--   noCreeps    -> the camp is not up (no neutral creeps nearby)
--   underThreat -> an enemy hero is right on us
local function scenario(opts)
    opts = opts or {}
    api.reset_modules()

    local neutral = api.MakeUnit({ IsAlive = true, GetTeam = 4 }) -- TEAM_NEUTRAL-ish

    local bot = api.MakeHero('npc_dota_hero_lion', {
        GetLocation = api.Vector(0, 0, 0),
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
    -- :47/:55 pull window). Overridable for the wrong-time cases.
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
        return { { team = GetTeam(), type = 'small', location = api.Vector(500, 0, 0) } }
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

tests['NO-FIRE: no friendly camp in the spawner list -> nil'] = function()
    local J, bot = scenario({ noCamp = true })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'with no friendly camp in reach there is nothing to pull')
end

tests['NO-FIRE: camp not up (no neutral creeps nearby) -> nil'] = function()
    local J, bot = scenario({ noCreeps = true })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'an empty camp (no creeps present) cannot be pulled')
end

tests['NO-FIRE: outside the pull window (wrong seconds-into-minute) -> nil'] = function()
    local J, bot = scenario({ now = 100 }) -- 1:40 -> 40s into the minute, before the window
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'pulling only in the ~:47/:55 window; other times must fall through')
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
