-- [arbheart] The release must RETIRE the camp, not just unlatch it -- GH #456.
--
-- WHAT #456 MEASURED.  `arbheart` (GH #455, landed 2026-09-03T13:30Z) releases
-- a latched camp when an ally is inside 800u of it and reads `J.IsFarming`:
-- `preferedCamp = nil; old = nil`.  It did NOT call
-- `J.Site.UpdateAvailableCamp`, the retire path the shipped anti-steal guard
-- uses, so the just-released camp was still in `J.Role['availableCampTable']`
-- one line later when the fall-through `elseif preferedCamp == nil then
-- preferedCamp = ClosestCamp(bot, availableCamp)` re-picked over that same
-- table.  The only thing that could keep the re-pick from handing the camp
-- straight back was the `IsTheClosestOne` filter inside
-- `J.Site.GetClosestNeutralSpwan` -- which is exactly what soak candidate
-- `slotarb` fixes.  `tests/test_arbheart_repick_relatch.lua` §4 runs the real
-- function on this frame and gets the released camp back with `slotarb`
-- unarmed.  So on that frame the release was self-cancelling, 1s at a time,
-- unless a SECOND, separately-armed candidate happened to be on.
--
-- WHY THE EXISTING GATE TEST COULD NOT SEE IT.
-- `tests/test_arbheart_farm_camp_heartbeat.lua` stubs BOTH halves of the
-- mechanism: `GetClosestNeutralSpwan` is a call counter that returns CAMP_X
-- then CAMP_Y ("the re-pick lands elsewhere" holds by construction of the
-- stub), and `UpdateAvailableCamp` is `function(_,_,tbl) return tbl, CAMP_Y end`
-- (it retires nothing).  This file stubs NEITHER: the real
-- `J.Site.UpdateAvailableCamp`, the real `J.Site.GetClosestNeutralSpwan` and
-- the real `IsTheClosestOne` all run, on the real frame, and the observable is
-- the CONTENT of `J.Role['availableCampTable']` after the heartbeat -- a fact
-- about the table itself, not about which camp a stub chose to return.
--
-- REAL FRAME: tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua -- game
-- 20260903_101254_slot5 at t=850.1, the frame #455 §3 photographed and the
-- one `arbheart` itself is pinned on.  Subject crystal_maiden (dire, pid 9),
-- 5991.9u from the ancient frog camp at (-592.9, 4840.6); spirit_breaker
-- (dire, pid 5) is 574.8u from it, inside the 800u release window.
--
-- LIMITS (declared, not worked around).
--  L1. `GetActiveMode` is not in the dumper's output
--      (tests/test_replay_004757_veno_ancient.lua:249 ratchets that) and
--      `IsTheClosestOne` filters on `GetActiveMode() == BotMode.Farm`.  Every
--      roster member is given Farm here, the setting most FAVOURABLE to
--      exclusion, matching test_arbheart_repick_relatch.lua's world exactly so
--      the two files read the same frame the same way.
--  L2. `J.IsFarming` is mocked to name spirit_breaker, as in the sibling gate
--      test: the fixture carries positions, not mode state.  It is the gate's
--      INPUT predicate, and this file is about what the gate does AFTER that
--      predicate fires -- so the negative control below turns it off and
--      requires the table to come through untouched.
--  L3. This file does not claim the re-pick then finds a GOOD camp.  On this
--      frame with `slotarb` unarmed the reduced table yields nil (the second
--      camp is excluded for a different reason), which leaves `preferedCamp`
--      nil for the tick.  Asserted below as the recorded outcome, not as a
--      desirable one.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua'

-- The ancient frog camp centre, as GH #455 §1 measured it off `creeps[]`.
local CAMP_X_LOC = { -592.9, 4840.6 }
-- A second camp, deliberately far from every hero on the frame so that neither
-- the 500u disjunct inside UpdateAvailableCamp nor the switch-to-nearer branch
-- can reach it.  It exists only so the table has something left after a
-- correct retire -- an empty table cannot tell "retired the right one" from
-- "retired everything".
local CAMP_Y_LOC = { -8000.0, -8000.0 }

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

-- opts.armed      -> arm 'arbheart' (turbo-only gate)
-- opts.ally_farms -> J.IsFarming names spirit_breaker (default true)
local function world(opts)
    opts = opts or {}
    local J, bot, heroes = rf.load(FIXTURE, 'npc_dota_hero_crystal_maiden')
    for k, v in pairs(DESIRE) do _G[k] = v end

    local dota = require(GetScriptDirectory() .. '/ts_libs/dota/index')
    for _, h in pairs(heroes) do
        h.GetActiveMode = function() return dota.BotMode.Farm end   -- L1
    end

    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id)
        if id == 'arbheart' then return opts.armed == true end
        return false                       -- slotarb in particular stays OFF
    end

    local sb = heroes['npc_dota_hero_spirit_breaker']
    assert(sb, 'setup: spirit_breaker missing from the fixture roster')
    J.IsFarming = function(who)            -- L2
        if opts.ally_farms == false then return false end
        return who == sb
    end
    J.IsCampSwitchSafe = function() return true end

    local CAMP_X = { cattr = { location = api.Vector(CAMP_X_LOC[1], CAMP_X_LOC[2], 0) } }
    local CAMP_Y = { cattr = { location = api.Vector(CAMP_Y_LOC[1], CAMP_Y_LOC[2], 0) } }

    J.Role = J.Role or {}
    J.Role['availableCampTable'] = { CAMP_X, CAMP_Y }
    -- NOT stubbed, on purpose: J.Site.UpdateAvailableCamp,
    -- J.Site.GetClosestNeutralSpwan, J.Site.IsTheClosestOne.
    J.Site.FilterFarmNeutrals = function(t) return t or {} end
    J.Site.GetFarmLaneTarget = function() return nil end
    J.Site.FindFarmNeutralTarget = function() return nil end
    J.Site.IsModeSuitableToFarm = function() return true end

    -- Record how big a table each re-pick was actually offered.  This is the
    -- trap the sibling gate test fell into and the reason S1 below exists --
    -- see the note on GetDesire().
    local offered = {}
    local realGCNS = J.Site.GetClosestNeutralSpwan
    J.Site.GetClosestNeutralSpwan = function(hBot, tCamps, a, b)
        offered[#offered + 1] = #tCamps
        return realGCNS(hBot, tCamps, a, b)
    end

    _G._testTime = 850.1
    GameTime = function() return _G._testTime end -- luacheck: ignore
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    -- Engine globals GetDesireHelper reaches on the way to the line this test
    -- depends on; the mock Bot API does not carry them.
    GetRoshanDesire = function() return 0 end     -- luacheck: ignore

    rf.declare_defend_ping(J, 'stale')

    dofile('bots/mode_farm_generic.lua')

    -- GetDesire() is what binds the module-local `availableCamp` to
    -- J.Role['availableCampTable'] (mode_farm_generic.lua:313, inside
    -- GetDesireHelper).  In game it runs every frame before Think(); in a test
    -- that calls Think() alone, `availableCamp` stays the module's initial `{}`
    -- and EVERY re-pick is handed an empty table.  That is not a detail: it is
    -- how `tests/test_arbheart_farm_camp_heartbeat.lua` can assert "armed
    -- re-picks CAMP_Y" while the real re-pick was never offered a camp at all
    -- -- its stub ignores the argument.  S1 asserts the binding took.
    local desire = GetDesire()
    assert(type(desire) == 'number',
        'setup: GetDesire() must run to completion, since it is what binds the ' ..
        "module-local `availableCamp`; got " .. type(desire))

    return {
        J = J, bot = bot, heroes = heroes, sb = sb,
        CAMP_X = CAMP_X, CAMP_Y = CAMP_Y,
        offered = offered,
        table_now = function() return J.Role['availableCampTable'] end,
    }
end

local function has_camp(tbl, camp)
    for _, c in ipairs(tbl) do if c == camp then return true end end
    return false
end

local function names(w, tbl)
    local out = {}
    for _, c in ipairs(tbl) do
        out[#out + 1] = (c == w.CAMP_X and 'X') or (c == w.CAMP_Y and 'Y') or 'OTHER'
    end
    return '{' .. table.concat(out, ',') .. '}'
end

-- ---------------------------------------------------------------------------
-- WORLD FACTS -- what the finding rests on, asserted rather than assumed.
-- ---------------------------------------------------------------------------

tests['[world W1] the shipped anti-steal guard does not retire on this frame'] = function()
    -- The guard at :899 needs `IsFarming AND IsAttacking`.  IsAttacking is NOT
    -- mocked, so this reads the fixture's own answer.  If it ever became true
    -- the shipped guard would retire the camp by itself and every reading
    -- below would be ambiguous about which block did the work -- so pin it.
    local w = world({ armed = false })
    assert(w.J.IsAttacking(w.sb) == false,
        'spirit_breaker reads IsAttacking on this frame, so the shipped ' ..
        ':899 guard could retire the camp on its own -- the unarmed control ' ..
        'below would no longer isolate arbheart')
end

tests['[setup S1] the re-pick is offered the real camp table, not an empty one'] = function()
    -- Without this the whole file could go green while measuring nothing: an
    -- unbound `availableCamp` makes every ClosestCamp() call return nil, no
    -- camp ever latches, `old` is nil at the heartbeat and the arbheart block
    -- is never entered -- so "the released camp is gone from the table" would
    -- hold because nothing was ever released.
    local w = world({ armed = false })
    Think()
    assert(#w.offered >= 1, 'the latch tick must call the re-pick at least once')
    assert(w.offered[1] == 2, ('the first re-pick must be offered both camps; ' ..
        'got a table of %d -- `availableCamp` is not bound'):format(w.offered[1]))
end

tests['[world W2] the released camp is the one an ally holds, not the bot'] = function()
    local w = world({ armed = false })
    local camp = w.CAMP_X.cattr.location
    local dSB = GetUnitToLocationDistance(w.sb, camp)
    local dCM = GetUnitToLocationDistance(w.bot, camp)
    assert(dSB <= 800, ('SB must sit inside the 800u release window; %.1f'):format(dSB))
    assert(dCM > 500, ('the bot must be outside UpdateAvailableCamp\'s own 500u ' ..
        'disjunct, so a retire here can only be by location match; %.1f'):format(dCM))
end

-- ---------------------------------------------------------------------------
-- THE DEFECT #456 REPORTED, at the level it actually lives: after the release,
-- is the camp still on the table the re-pick reads?
-- ---------------------------------------------------------------------------

tests['[unarmed] the table is untouched -- the gate is inert'] = function()
    local w = world({ armed = false })
    Think()
    _G._testTime = 851.15
    Think()
    local tbl = w.table_now()
    assert(#tbl == 2 and has_camp(tbl, w.CAMP_X) and has_camp(tbl, w.CAMP_Y),
        'unarmed, arbheart must leave availableCampTable byte-for-byte alone; got ' ..
        names(w, tbl))
end

tests['[armed] the release retires the camp it just let go of'] = function()
    local w = world({ armed = true })
    Think()                                  -- tick 1: latch CAMP_X
    assert(#w.table_now() == 2, 'setup: the latch tick must not retire anything')
    _G._testTime = 851.15
    Think()                                  -- tick 2: heartbeat releases
    local tbl = w.table_now()
    assert(not has_camp(tbl, w.CAMP_X),
        'THE FIX: after the release, the camp must be OUT of availableCampTable ' ..
        '-- otherwise the fall-through re-pick reads it right back (GH #456); got ' ..
        names(w, tbl))
    assert(has_camp(tbl, w.CAMP_Y),
        'the retire must remove exactly the released camp, not clear the table; got ' ..
        names(w, tbl))
end

tests['[armed / no ally farming] no release, so no retire'] = function()
    -- Negative control: the retire must be downstream of the release
    -- predicate, not an unconditional side effect of arming the gate.
    local w = world({ armed = true, ally_farms = false })
    Think()
    _G._testTime = 851.15
    Think()
    local tbl = w.table_now()
    assert(#tbl == 2 and has_camp(tbl, w.CAMP_X),
        'with no ally farming the camp there is no release, so nothing may be ' ..
        'retired; got ' .. names(w, tbl))
end

tests['[armed / not turbo] the gate is inert outside turbo'] = function()
    local w = world({ armed = true })
    w.J.IsModeTurbo = function() return false end
    Think()
    _G._testTime = 851.15
    Think()
    local tbl = w.table_now()
    assert(#tbl == 2 and has_camp(tbl, w.CAMP_X),
        'outside turbo neither the release nor the retire may run; got ' ..
        names(w, tbl))
end

-- ---------------------------------------------------------------------------
-- END TO END through the REAL re-pick: the call `arbheart` falls through to,
-- run on the table the retire actually left behind.  This is the assertion
-- #456 §4 could not make -- it ran GetClosestNeutralSpwan on the FULL table.
-- ---------------------------------------------------------------------------

tests['[armed] the real re-pick can no longer return the released camp'] = function()
    local w = world({ armed = true })
    local Site = require(GetScriptDirectory() .. '/FunLib/aba_site')

    -- Before: the released camp is still reachable -- this is the defect, and
    -- it is what the fall-through would have picked (relatch_test §4).
    local before = Site.GetClosestNeutralSpwan(w.bot, { w.CAMP_X, w.CAMP_Y }, false, false)
    assert(before == w.CAMP_X,
        'precondition: with slotarb unarmed the real re-pick over the FULL ' ..
        'table returns the camp arbheart releases -- if this ever stops being ' ..
        'true the retire is no longer load-bearing and this gate should be ' ..
        're-argued, not silently kept')

    Think()
    _G._testTime = 851.15
    Think()

    local after = Site.GetClosestNeutralSpwan(w.bot, w.table_now(), false, false)
    assert(after ~= w.CAMP_X,
        'after the retire the re-pick must not be able to hand back the ' ..
        'released camp, with slotarb still unarmed')
    -- L3: it returns nil here, not CAMP_Y.  Recorded, not engineered away --
    -- CAMP_Y is excluded on this frame for its own reasons, so the heartbeat
    -- leaves preferedCamp nil.  That is a strictly better outcome than
    -- re-latching a camp an ally is already farming, but it is not "found a
    -- better camp", and this file does not claim it is.
    assert(after == nil, ('recorded outcome on this frame: nil; got %s')
        :format(tostring(after)))
end

-- ---------------------------------------------------------------------------
-- MUTATION: drop the retire call and the finding comes back.  Without this the
-- suite could pass with the retire deleted, since every other assertion in the
-- repo about arbheart is satisfied by the release alone.
-- ---------------------------------------------------------------------------

tests['[mutation M1] deleting the retire call restores the #456 defect'] = function()
    local f = assert(io.open('bots/mode_farm_generic.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local pattern = "J%.Role%['availableCampTable'%]%s*=\n%s*J%.Site%.UpdateAvailableCamp%(bot, old, J%.Role%['availableCampTable'%]%)\n"
    local mutated, n = src:gsub(pattern, '', 1)
    assert(n == 1, 'M1: the retire call did not match exactly once (n=' .. n ..
        ') -- if the fix reshaped, re-anchor this mutation')
    assert(mutated ~= src, 'M1: the mutation must actually change the source')

    local w = world({ armed = true })
    local chunk, err = loadstring(mutated, 'mode_farm_generic_mutated')
    assert(chunk, 'M1: mutant source failed to parse: ' .. tostring(err))
    chunk()
    Think()
    _G._testTime = 851.15
    Think()
    local tbl = w.table_now()
    assert(has_camp(tbl, w.CAMP_X),
        'M1: with the retire deleted the released camp must still be on the ' ..
        'table -- that IS the #456 defect.  If it is gone, something else in ' ..
        'this file is doing the retiring and the assertions above are not ' ..
        'measuring the fix; got ' .. names(w, tbl))
end

return tests
