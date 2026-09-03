-- [replay-check] `arbheart`'s release is undone by its own re-pick unless
-- `slotarb` is also armed -- measured on the SAME real frame `arbheart` pins.
--
-- WHY THIS FILE EXISTS.  `arbheart` (GH #455, landed 2026-09-03T13:30Z) makes
-- the 1s farm heartbeat re-ask camp arbitration: if an ally is within 800u of
-- the latched camp and reads `J.IsFarming`, it sets `preferedCamp = nil` and
-- `old = nil`, and the fall-through `elseif preferedCamp == nil then
-- preferedCamp = ClosestCamp(bot, availableCamp)` re-picks
-- (bots/mode_farm_generic.lua:812-844).
--
-- The release does NOT retire the camp: it never calls
-- `J.Site.UpdateAvailableCamp`, which is the retire path the shipped
-- anti-steal guard at :868 uses.  So the just-released camp is still in
-- `availableCamp` when the re-pick runs, and the ONLY thing that can keep the
-- re-pick from handing it straight back is the `IsTheClosestOne` filter inside
-- `J.Site.GetClosestNeutralSpwan` (bots/FunLib/aba_site.lua:528).
--
-- That filter is exactly what soak candidate `slotarb` fixes.  Unarmed, it
-- feeds a PLAYER ID to `GetTeamMember`, whose argument is a team SLOT, so on
-- the dire side only slot 5 is ever reached (aba_site.lua:536-556).  On this
-- frame the bot IS slot 5, so the shipped scan reaches nobody but herself and
-- the filter cannot exclude anything.
--
-- WHAT `tests/test_arbheart_farm_camp_heartbeat.lua` CANNOT SEE.  That test
-- replaces `J.Site.GetClosestNeutralSpwan` with a call counter that returns
-- CAMP_X on call 1 and CAMP_Y on call 2, and arms ONLY `arbheart`
-- (`if id == 'arbheart' ... return false`).  The real re-pick -- filter and
-- distance ordering both -- never runs, so "armed lands on a different camp"
-- holds by construction of the stub.  This file runs the real function.
--
-- REAL FRAME: tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua --
-- game 20260903_101254_slot5 at t=850.1, the frame GH #455 §3 photographed.
-- Subject crystal_maiden (dire, pid 9); spirit_breaker (dire, pid 5) is 574.8u
-- from the ancient frog camp at (-592.9, 4840.6), crystal_maiden 5991.9u.
--
-- LIMIT (declared, not worked around).  `GetActiveMode` is not in the dumper's
-- output -- tests/test_replay_004757_veno_ancient.lua:249 ratchets that -- and
-- `IsTheClosestOne` filters on `member:GetActiveMode() == BotMode.Farm`.  Every
-- roster member here is given Farm, which is the setting most FAVOURABLE to
-- exclusion: it can only make the filter reject more.  The shipped reading
-- below is therefore a lower bound in the safe direction (it says "cannot
-- exclude" under the most exclusion-friendly world available).  The armed
-- reading is conditional on spirit_breaker actually reading Farm in game.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua'
-- The ancient frog camp centre, as GH #455 §1 measured it off `creeps[]`.
local CAMP_X_LOC = { -592.9, 4840.6 }

local function world()
    local J, bot, heroes = rf.load(FIXTURE, 'npc_dota_hero_crystal_maiden')
    local dota = require(GetScriptDirectory() .. '/ts_libs/dota/index')
    for _, h in pairs(heroes) do
        h.GetActiveMode = function() return dota.BotMode.Farm end
    end
    return J, bot, heroes
end

-- 1. The frame is the one the finding claims it is.
tests.frame_is_the_steal_frame = function()
    local _, bot, heroes = world()
    local camp = api.Vector(CAMP_X_LOC[1], CAMP_X_LOC[2], 0)
    assert(bot:GetPlayerID() == 9, 'subject should be crystal_maiden pid 9')
    local sb = heroes['npc_dota_hero_spirit_breaker']
    assert(sb ~= nil, 'spirit_breaker missing from the fixture roster')
    local dSB = GetUnitToLocationDistance(sb, camp)
    local dCM = GetUnitToLocationDistance(bot, camp)
    assert(dSB < 800, ('spirit_breaker should be inside the 800u release ' ..
        'window, measured %.1f'):format(dSB))
    assert(dCM > dSB, ('the bot should be the FARTHER of the two, measured ' ..
        'CM %.1f vs SB %.1f'):format(dCM, dSB))
end

-- 2. The shipped scan reaches exactly one roster member, and it is the bot.
tests.shipped_scan_reaches_only_the_bot = function()
    local _, bot = world()
    local reached = {}
    for _, id in ipairs(GetTeamPlayers(GetTeam())) do
        local m = GetTeamMember(id)          -- the shipped line: slot := player id
        if m ~= nil then reached[#reached + 1] = m end
    end
    assert(#reached == 1, ('shipped scan should reach exactly 1 roster member ' ..
        'on this dire frame, reached %d'):format(#reached))
    assert(reached[1] == bot, 'the one member the shipped scan reaches should ' ..
        'be the bot herself (pid 9 sorts to slot 5)')
end

-- 3. THE FINDING.  The released camp survives the shipped filter and is
--    excluded only once `slotarb` is armed.
tests.released_camp_survives_shipped_filter = function()
    local _, bot = world()
    local Site = require(GetScriptDirectory() .. '/FunLib/aba_site')
    local camp = api.Vector(CAMP_X_LOC[1], CAMP_X_LOC[2], 0)
    assert(Site.IsTheClosestOne(bot, camp, false) == true,
        'shipped (slotarb unarmed): the just-released camp must still read as ' ..
        '"mine", i.e. the re-pick is free to hand it straight back')
    assert(Site.IsTheClosestOne(bot, camp, true) == false,
        'slotarb armed: the wider scan reaches spirit_breaker at 574.8u and ' ..
        'excludes the camp (conditional on SB reading Farm -- see LIMIT)')
end

-- 4. End to end through the REAL re-pick: the same call `arbheart` falls
--    through to returns the released camp when `slotarb` is unarmed.
tests.real_repick_returns_the_released_camp = function()
    local _, bot = world()
    local Site = require(GetScriptDirectory() .. '/FunLib/aba_site')
    local CAMP_X = { cattr = { location = api.Vector(CAMP_X_LOC[1], CAMP_X_LOC[2], 0) } }
    -- A second camp, deliberately FARTHER from the bot than CAMP_X, so that
    -- distance alone cannot be what decides the outcome -- only the filter can.
    local CAMP_Y = { cattr = { location = api.Vector(-8000.0, -8000.0, 0) } }
    local avail = { CAMP_X, CAMP_Y }
    local dX = GetUnitToLocationDistance(bot, CAMP_X.cattr.location)
    local dY = GetUnitToLocationDistance(bot, CAMP_Y.cattr.location)
    assert(dX < dY, ('setup: CAMP_X must be the nearer one, measured %.1f vs %.1f')
        :format(dX, dY))

    -- The two arguments are exactly what ClosestCamp() passes:
    --   bReadCampRecord := IsSoakCandidate('campsel'), bSlotArb := IsSoakCandidate('slotarb')
    local shipped = Site.GetClosestNeutralSpwan(bot, avail, false, false)
    assert(shipped == CAMP_X, 'slotarb unarmed: the re-pick hands back the camp ' ..
        'arbheart just released -- the release is a no-op on this frame')

    local armed = Site.GetClosestNeutralSpwan(bot, avail, false, true)
    assert(armed ~= CAMP_X, 'slotarb armed: the re-pick must not return the ' ..
        'released camp')
    -- It returns nil here, not CAMP_Y: the wider scan also finds dragon_knight
    -- nearer to CAMP_Y than the bot, so BOTH camps are excluded.  Recorded
    -- rather than engineered away -- a nil re-pick leaves `preferedCamp` nil
    -- through the heartbeat, which is a THIRD outcome neither the shipped
    -- switch branch nor test_arbheart_farm_camp_heartbeat.lua's two-camp stub
    -- world can produce.
    assert(armed == nil, ('slotarb armed: both camps are excluded on this ' ..
        'frame, so the re-pick yields nil; got %s'):format(tostring(armed)))
end

-- 5. `J.IsCampSwitchSafe` is inert on trunk, so the fall-through re-pick is
--    not currently bypassing an ACTIVE safety predicate -- but it will be the
--    moment `campdanger` is armed or promoted.  Registered so that day is not
--    silent.
tests.camp_switch_safe_is_currently_inert = function()
    local J = world()
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return id == 'campdanger' end
    local camp = { cattr = { location = api.Vector(CAMP_X_LOC[1], CAMP_X_LOC[2], 0) } }
    local armed_reachable = pcall(function() return J.IsCampSwitchSafe(camp) end)
    assert(armed_reachable, 'IsCampSwitchSafe should be callable with campdanger armed')
    J.IsSoakCandidate = function() return false end
    assert(J.IsCampSwitchSafe(camp) == false,
        'with campdanger unarmed IsCampSwitchSafe is false for every camp, so ' ..
        'the shipped switch-to-nearer branch on the heartbeat can never fire')
end

return tests
