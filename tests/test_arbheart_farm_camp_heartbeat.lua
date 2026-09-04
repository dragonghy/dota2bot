-- [arbheart] Camp arbitration only enters behaviour the tick preferedCamp is
-- latched, and never re-asks. GH #455 §3 photographed the tail: at t=850,
-- crystal_maiden was 5744u from the ancient frog camp and spirit_breaker was
-- 340u into farming it. The latch had closed at t=816 (SB then 5003u away)
-- and none of the three shipped anti-steal guards
-- (mode_farm_generic.lua:589, :811, plus armed slotarb) fired again -- the
-- initial arbitration `IsTheClosestOne` is only queried the tick the latch
-- is set (six call sites all read `if preferedCamp == nil then
-- preferedCamp = ClosestCamp(...) end`), and the two anti-steal guards need
-- both `J.IsFarming` and `J.IsAttacking` returning true at the CM tick --
-- signals that lag during the SB "walk-then-open-fire" transition and can
-- miss the whole window while CM crosses the map.
--
-- Soak candidate 'arbheart' (turbo-only) inserts the re-ask into the 1s
-- `_farm_repick_at` heartbeat: every heartbeat, if any alive team member
-- (scanned via `for i = 1, #GetTeamPlayers` + `GetTeamMember(i)`, the slot-
-- correct pattern) sits within 800u of the currently latched camp and reads
-- `J.IsFarming`, the latch is released and the fall-through
-- `elseif preferedCamp == nil` re-picks through the same `ClosestCamp`
-- wrapper (which already threads slotarb when armed).
--
-- REAL FRAME: f_260903_101254_cm_farm_stealcamp.lua -- game
-- 20260903_101254_slot5 at t=850.1 (from the same wave #455 §1 reports on).
-- The subject is crystal_maiden, dire, pid=9 (slot 5); spirit_breaker is
-- dire, pid=5 (slot 1), 575u from the ancient frog camp centre at
-- (-593, 4841). Every world fact below runs on the unmodified fixture and is
-- asserted, not assumed.
--
-- OBSERVABLE. Both shipped and armed call `J.Site.GetClosestNeutralSpwan`
-- the same number of times per heartbeat, so a call-count metric would be
-- ambiguous. What separates them is WHICH camp `preferedCamp` points at
-- after the heartbeat: shipped keeps CAMP_X (the currently-latched one);
-- armed releases it and the fall-through re-picks CAMP_Y. We read that off
-- the LAST location `J.GetAlliesNearLoc(targetFarmLoc, 800)` was called
-- with in the shipped 811-block, right after the heartbeat -- that call is
-- unconditional and its first argument IS `preferedCamp.cattr.location`.
--
-- STRICT SUBSET: armed can only ever RELEASE a latched camp -- it makes no
-- bid, latches no new camp of its own, and the fall-through re-pick uses the
-- shipped wrapper. Unarmed the added block is a no-op and the outer
-- if/elseif is byte-for-byte the shipped switch-to-nearer branch.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua'

-- Real camp centre, exactly as #455 §1 measured off `creeps[] team==4`
-- samples. CAMP_Y is placed FARTHER from CM than CAMP_X so the shipped
-- switch-to-nearer branch cannot fire (its gate is `newDist + 200 <
-- oldDist`); armed, the fall-through re-pick picks CAMP_Y anyway.
local CAMP_X = { cattr = { location = api.Vector(-592.9, 4840.6, 0) } }
local CAMP_Y = { cattr = { location = api.Vector(-8000.0, -8000.0, 0) } }

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

-- Load the real frame and drop the SHIPPED farm mode file on top of it.
-- opts:
--   armed       = true -> arbheart is armed (turbo-only)
--   ally_farms  = true -> J.IsFarming(SB) returns true (negative control:
--                         false; the release must not fire without a farmer)
local function world(opts)
    opts = opts or {}
    -- Subject named explicitly even though it matches the fixture's own
    -- `self`. It briefly did NOT: an earlier cut of this fixture declared
    -- spirit_breaker as subject to keep it out of a hero-group CM ratchet,
    -- and that turned out to be the wrong trade -- the dumper captures creeps
    -- RELATIVE TO THE SUBJECT, so an SB-subject cut carried 48 neutral creeps
    -- (SB is meleeing the camp) and became the first fixture in the corpus
    -- with a creeps key, breaking the cross-group "the corpus carries no
    -- creeps" world assertion at test_campfarm_ancient_target.lua:187. Only a
    -- CM subject reads 0 (she is walking half a map from anything). Naming the
    -- subject here keeps this test pinned to CM regardless of what the
    -- fixture header says, so that trade can never silently move it again.
    local J, bot, heroes = rf.load(FIXTURE, 'npc_dota_hero_crystal_maiden')
    for k, v in pairs(DESIRE) do _G[k] = v end

    -- Turbo, so the gate can be reached at all.
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id)
        if id == 'arbheart' then return opts.armed == true end
        return false
    end
    local sb = heroes['npc_dota_hero_spirit_breaker']
    assert(sb, 'setup: SB missing from the fixture roster')
    J.IsFarming = function(who)
        if opts.ally_farms == false then return false end
        return who == sb
    end
    -- IsAttacking is deliberately NOT mocked true: the shipped 811-block
    -- requires `IsFarming AND IsAttacking`, so its own release path stays
    -- silent in this test. That is the same shape #455 §1 reports (the
    -- shipped guard did not stop it in the real game); here it lets us read
    -- shipped-vs-armed cleanly off preferedCamp without the shipped guard
    -- also releasing.
    J.IsCampSwitchSafe = function() return true end

    -- Camp roster + swap helpers. Fresh-per-test.
    J.Role = J.Role or {}
    J.Role['availableCampTable'] = { CAMP_X, CAMP_Y }
    J.Site = J.Site or {}
    J.Site.UpdateAvailableCamp = function(_, _, tbl) return tbl, CAMP_Y end
    J.Site.FilterFarmNeutrals = function(t) return t or {} end
    J.Site.GetFarmLaneTarget = function() return nil end
    J.Site.FindFarmNeutralTarget = function() return nil end
    J.Site.IsModeSuitableToFarm = function() return true end
    J.Site.GetClosestNeutralSpwan =
        J.Site.GetClosestNeutralSpwan or function() return nil end
    local ccCalls = 0
    J.Site.GetClosestNeutralSpwan = function()
        ccCalls = ccCalls + 1
        if ccCalls == 1 then return CAMP_X end
        return CAMP_Y
    end

    -- Spy on J.GetAlliesNearLoc: return a real list (the shipped scan) and
    -- ALSO record the location it was called with. The 811-block's call is
    -- unconditional (runs whenever preferedCamp ~= nil), so the last entry
    -- after Think() names the camp preferedCamp was pointing at.
    local origGANL = J.GetAlliesNearLoc
    local ganlCalls = {}
    J.GetAlliesNearLoc = function(vLoc, nRadius)
        ganlCalls[#ganlCalls + 1] = vLoc
        return origGANL(vLoc, nRadius)
    end

    -- Time control -- GameTime() drives the heartbeat.
    _G._testTime = 850.1
    GameTime = function() return _G._testTime end -- luacheck: ignore

    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore

    -- GH #91 declaration ratchet: this test drives mode_farm_generic which
    -- carries a defence-ping-gated bid. We do NOT read that bid (Think()
    -- only, no GetDesire), but the ratchet checks the declaration by source
    -- shape. Declare 'stale' -- the ordinary case; this test's frame is
    -- t=850, hours past any conceivable defence ping on the reference
    -- fixture (the whole world it captured is a farming CM walking to a
    -- neutral camp, not a defence event).
    rf.declare_defend_ping(J, 'stale')

    dofile('bots/mode_farm_generic.lua')
    return {
        J = J, bot = bot, heroes = heroes, sb = sb,
        ccCalls = function() return ccCalls end,
        ganlCalls = ganlCalls,
    }
end

-- Nearest camp = the location whose vector best matches (within 1u).
local function last_camp_loc(w)
    local last = w.ganlCalls[#w.ganlCalls]
    assert(last, 'J.GetAlliesNearLoc was not called; the 811-block never ran')
    if math.abs(last.x - CAMP_X.cattr.location.x) < 1 and math.abs(last.y - CAMP_X.cattr.location.y) < 1 then
        return 'X'
    elseif math.abs(last.x - CAMP_Y.cattr.location.x) < 1 and math.abs(last.y - CAMP_Y.cattr.location.y) < 1 then
        return 'Y'
    end
    return 'OTHER(' .. last.x .. ', ' .. last.y .. ')'
end

-- ---------------------------------------------------------------------------
-- WORLD FACTS -- everything the defect rests on is asserted, not assumed.
-- ---------------------------------------------------------------------------

tests['[world W1] the fixture puts SB at 575u from the camp and CM at 5992u'] = function()
    local w = world()
    local sb, cm = w.sb, w.bot
    local camp = CAMP_X.cattr.location
    local dSB = GetUnitToLocationDistance(sb, camp)
    local dCM = GetUnitToLocationDistance(cm, camp)
    assert(math.abs(dSB - 575) < 5, 'SB->camp moved: ' .. dSB)
    assert(math.abs(dCM - 5992) < 5, 'CM->camp moved: ' .. dCM)
    assert(cm:GetUnitName() == 'npc_dota_hero_crystal_maiden')
    assert(cm:GetTeam() == 3, 'the frame this issue reports is dire; CM is on team ' .. cm:GetTeam())
    assert(sb:GetTeam() == 3, 'SB is on team ' .. sb:GetTeam())
end

tests['[world W2] the slot-correct roster walk sees SB at slot 1 on dire'] = function()
    -- This is the pattern arbheart uses (`for i = 1, #GetTeamPlayers` +
    -- `GetTeamMember(i)`). The corrected mock in tests/mock/replay_fixture.lua
    -- returns members by slot; a real engine that ever regressed to answering
    -- by pid would fail this assertion first.
    local w = world()
    local tPlayers = GetTeamPlayers(GetTeam())
    assert(#tPlayers == 5, 'dire has 5 team players; got ' .. #tPlayers)
    assert(GetTeamMember(1) == w.sb, 'slot 1 on this fixture must be SB (pid=5); ' ..
        'if this drifts the arbheart scan lands on a different hero')
    assert(GetTeamMember(5) == w.bot, 'slot 5 on this fixture must be CM (pid=9)')
end

tests['[world W3] the fix wires the gate at exactly one place, inside Think'] = function()
    -- Guard against a copy/paste of the block that would silently widen the
    -- lever past this one call site.
    local f = assert(io.open('bots/mode_farm_generic.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local _, n = src:gsub("IsSoakCandidate%s*%(%s*['\"]arbheart['\"]%s*%)", '')
    assert(n == 1, "'arbheart' is now referenced " .. n .. " times in the farm mode file -- should be 1")
    local think = src:match('function%s+Think%s*%(%).*')
    assert(think, 'Think() reshaped or gone')
    local _, nInThink = think:gsub("IsSoakCandidate%s*%(%s*['\"]arbheart['\"]%s*%)", '')
    assert(nInThink == 1, "'arbheart' moved out of Think() -- the whole point of the gate was to " ..
        'run in the heartbeat')
end

-- ---------------------------------------------------------------------------
-- THE DEFECT (unarmed): once the latch is set, no heartbeat releases it even
-- though an ally is farming the camp.
-- ---------------------------------------------------------------------------

tests['[unarmed] the heartbeat does not release preferedCamp -- shipped defect reproduced'] = function()
    local w = world({ armed = false })
    Think()  -- tick 1 @ t=850.1 -- latches CAMP_X (heartbeat ELSE arm)
    assert(last_camp_loc(w) == 'X', 'tick 1: preferedCamp must latch CAMP_X; got ' .. last_camp_loc(w))
    _G._testTime = 851.15  -- 1s later; heartbeat fires
    Think()
    assert(last_camp_loc(w) == 'X', 'shipped: preferedCamp must STAY at CAMP_X after the ' ..
        'heartbeat (no re-arbitration); got ' .. last_camp_loc(w) ..
        ' -- if this reads Y, either the shipped body grew a re-pick or the ' ..
        'shipped 811-block released; both make arbheart redundant and this ' ..
        'gate should be dropped')
end

-- ---------------------------------------------------------------------------
-- THE FIX (armed): the heartbeat asks the anti-steal predicate, and when SB
-- is farming the latched camp, releases and re-picks.
-- ---------------------------------------------------------------------------

tests['[armed] the heartbeat releases the latch and re-picks the next tick'] = function()
    local w = world({ armed = true, ally_farms = true })
    Think()
    assert(last_camp_loc(w) == 'X', 'tick 1 must latch CAMP_X; got ' .. last_camp_loc(w))
    _G._testTime = 851.15
    Think()
    assert(last_camp_loc(w) == 'Y', 'armed: preferedCamp must be re-picked to CAMP_Y ' ..
        'after the heartbeat releases the latched CAMP_X; got ' .. last_camp_loc(w))
end

tests['[armed / no ally farming] the release does NOT fire, latch stays'] = function()
    -- Negative control: even armed, without an ally-farming signal on this
    -- camp the guard must not release.
    local w = world({ armed = true, ally_farms = false })
    Think()
    assert(last_camp_loc(w) == 'X', 'tick 1 must latch CAMP_X')
    _G._testTime = 851.15
    Think()
    assert(last_camp_loc(w) == 'X', 'without an ally farming the camp, armed must NOT ' ..
        'release the latch; got ' .. last_camp_loc(w) ..
        ' -- the guard is not gated on the predicate')
end

tests['[armed / not turbo] the gate is inert outside turbo'] = function()
    -- The mode gate is `J.IsModeTurbo() and J.IsSoakCandidate('arbheart')`.
    local w = world({ armed = true, ally_farms = true })
    w.J.IsModeTurbo = function() return false end
    Think()
    assert(last_camp_loc(w) == 'X', 'tick 1 must latch CAMP_X')
    _G._testTime = 851.15
    Think()
    assert(last_camp_loc(w) == 'X', 'outside turbo the gate must be inert; got ' ..
        last_camp_loc(w))
end

-- ---------------------------------------------------------------------------
-- MECHANISM: the arbheart block is the only reason armed differs from
-- shipped. Delete the guard and armed collapses back to shipped.
-- ---------------------------------------------------------------------------

tests['[mutation M1] deleting the arbheart block collapses armed to shipped'] = function()
    -- Load the shipped source, strip the arbheart guard, and drive the same
    -- armed sequence against the mutated chunk in the SAME global env world()
    -- has set up.
    local f = assert(io.open('bots/mode_farm_generic.lua', 'r'))
    local src = f:read('*a')
    f:close()
    -- Match the whole guard by anchoring on its opening line and its double-
    -- `end` closer (the inner `end` for the loop + the outer `end` for the
    -- if). Non-greedy on the body so we do not accidentally swallow the
    -- following switch-to-nearer block.
    local pattern = "\t\t\tif J%.IsModeTurbo%(%) and J%.IsSoakCandidate%(%s*'arbheart'%s*%).-\n\t\t\tend\n"
    local mutated, n = src:gsub(pattern, '', 1)
    assert(n == 1, 'M1: the mutation pattern did not match exactly one occurrence (n=' .. n ..
        ') -- if the fix reshaped, re-anchor this test')
    assert(mutated ~= src, 'M1: the mutation must actually change the source')
    -- Prime world (fresh env, fresh globals) then replace Think/GetDesire
    -- with the mutated chunk's versions.
    local w = world({ armed = true, ally_farms = true })
    local chunk, err = loadstring(mutated, 'mode_farm_generic_mutated')
    assert(chunk, 'M1: mutant source failed to parse: ' .. tostring(err))
    chunk()
    Think()
    assert(last_camp_loc(w) == 'X', 'M1 setup: tick 1 must still latch CAMP_X')
    _G._testTime = 851.15
    Think()
    assert(last_camp_loc(w) == 'X', 'M1: with arbheart deleted, armed must collapse to the ' ..
        'shipped behaviour (preferedCamp stays CAMP_X); got ' .. last_camp_loc(w) ..
        ' -- if this reads Y, the arbheart guard is NOT the only reason armed differs from shipped')
end

-- ---------------------------------------------------------------------------
-- MUTATION 2: freeze the gate always-on inside turbo (drop the IsSoakCandidate
-- half). The negative-control test above already forbids the release from
-- firing without a farmer, so an always-on mutation would still not release
-- there -- but it WOULD release in every armed=false test that has a farmer.
-- Assert the source shape so a mutation that drops IsSoakCandidate is caught.
-- ---------------------------------------------------------------------------

tests['[mutation M2] gate-always-on is caught by the source-shape assertion'] = function()
    local f = assert(io.open('bots/mode_farm_generic.lua', 'r'))
    local src = f:read('*a')
    f:close()
    assert(src:find("J%.IsModeTurbo%(%)%s+and%s+J%.IsSoakCandidate%(%s*['\"]arbheart['\"]%s*%)"),
        'the gate is no longer `IsModeTurbo() and IsSoakCandidate("arbheart")` -- ' ..
        'that is the ONE textual pattern the rest of the file uses; if the mutation ' ..
        'drops IsSoakCandidate, this fails')
end

return tests
