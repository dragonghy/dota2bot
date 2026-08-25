-- GH #117, director ruling 20260825T07:xxZ (owner P1 DoD step 4).  Soak
-- candidate 'pulldrag': WHERE THE DRAG WALKS.
--
-- The ruling handed this group one action -- tighten PULL_CAMP_LANE_GAP from
-- 1200 to a typical drag (p90 992 / median 742) -- and one precondition: check
-- FIRST whether the camps that produce the connects still fit under it.  The
-- check ran (tools/agent/pullcamp_lane_geometry.py, ratcheted by
-- tests/test_pullcamp_lane_geometry.py) and REFUSED the action: the two camps
-- that produce every connect are the two WIDEST-gap camps still firing, so a
-- distance threshold deletes the numerator before it deletes anything else.
--
-- What that check also produced is the lever this file validates.  Every camp
-- the engine can pull from sits 1.0-1.3k off the lane, while the followers'
-- leash breaks after a median 742u.  So the drag has to spend its whole budget
-- moving PERPENDICULAR to the lane -- and the shipped drag does not: it walks
-- toward J.GetTeamFountain().  Its own comment states the intent as "walk
-- home-ward in between so the camp follows into the lane path"; home is a proxy
-- for the lane path, and on the real map it is a very lossy one.
--
-- WHAT IS REAL HERE, AND WHAT IS DECLARED
--   REAL: the bot, his team and his position; both ancients; and every tower
--     on the map.  Towers are the reason this file can do what its sister
--     tests/test_pullcamp_lane_gap.lua could not: that file had to bend an
--     ancient-to-ancient axis into a stand-in lane, because it needed a lane
--     that could be placed at a chosen distance from the bot.  This file needs
--     the REAL lane, and the towers of a lane lie on it.  All 61 fixtures that
--     carry buildings agree on all 22 towers exactly (asserted by the python
--     ratchet), so the map here is a measured constant, not an assumption.
--   DECLARED: which tower belongs to which lane (checked against the frame's
--     own tower list below -- a mis-filed or absent tower turns this red), and
--     GetLocationAlongLane, which is a mock constant Vector(0,0,0) in every
--     fixture (world assertion; the corpus carries no lane geometry).
--   NOT DECLARED, and deliberately: camp OCCUPANCY, vision, and anything about
--     whether a pull would be chosen here.  This file tests one geometric
--     decision -- given a camp, which way does the drag walk -- and nothing
--     about when the drag happens.
--
-- HONEST LIMIT: this file cannot show that walking lane-ward CONNECTS.  Whether
-- the neutrals actually reach the wave is a wave question, and it is
-- pre-registered as such (queue.json).  What is local and settled here is the
-- arithmetic the wave question rests on: how much of each 500u step is spent
-- closing the gap that must be closed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The step length in mode_roam_generic's drag cadence.  Restated so that a
-- silent edit there shows up as a failure here rather than as a quietly
-- passing suite.
local STEP = 500

-- Lane ids.  The numeric values are irrelevant to the code under test -- it
-- only passes the assigned lane through to GetLocationAlongLane -- but they are
-- distinct on purpose, so the assertion "the path was sampled along the lane
-- this bot was ASSIGNED" has something to catch a hardcoded lane with.
local LANE_ID = { TOP = 1, MID = 2, BOT = 3 }

-- Which tower sits on which lane.  Every one of these is asserted to be present
-- in the frame's own tower list before it is used.
local LANE_TOWERS = {
    TOP = { radiant = { { -6592, -3408 }, { -6501, -872 }, { -6336, 1856 } },
            dire    = { { -5275, 6036 }, { -128, 6016 }, { 3552, 5776 } } },
    BOT = { radiant = { { -3952, -6112 }, { -360, -6256 }, { 4860, -6379 } },
            dire    = { { 6269, -2240 }, { 6400, 384 }, { 6336, 3032 } } },
}

-- The two camps that produced every connect in W7/W8 (replay desk 20260825T01:3xZ,
-- fine centroids from the 20260822T15:18Z position clustering).  These are the
-- camps the refusal is about, so they are the camps the lever is measured on.
local CAMP = {
    radiant = { 3994, -5137 },      -- reached from BOT
    dire    = { -4007, 4947 },      -- reached from TOP
}

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Distance from a point to a polyline, measured to its SEGMENTS.  This is the
-- reference the assertions use; the code under test computes its own.
local function seg_dist(v, a, b)
    local abx, aby = b.x - a.x, b.y - a.y
    local l2 = abx * abx + aby * aby
    if l2 <= 0 then return dist(v, a) end
    local t = ((v.x - a.x) * abx + (v.y - a.y) * aby) / l2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return dist(v, Vector(a.x + abx * t, a.y + aby * t, 0))
end

local function gap_to_lane(v, verts)
    local best = math.huge
    for i = 1, #verts - 1 do
        local d = seg_dist(v, verts[i], verts[i + 1])
        if d < best then best = d end
    end
    return best
end

-- One 500u step from `from` toward `to`.
local function step_toward(from, to)
    local dx, dy = to.x - from.x, to.y - from.y
    local n = math.sqrt(dx * dx + dy * dy)
    return Vector(from.x + dx / n * STEP, from.y + dy / n * STEP, from.z or 0)
end

-- Loads a frame and wires the REAL lane.  Returns J, bot and a geo table.
--
-- `sLane` picks the polyline; `sSide` picks which camp (the bot's own side).
-- The polyline runs radiant-ancient -> radiant t3,t2,t1 -> dire t1,t2,t3 ->
-- dire-ancient, i.e. the direction the engine's lane parameter runs.
local function frame(sFixture, sHero, sLane, sSide)
    local J, bot, _, fx = rf.load(sFixture, sHero)

    local vRad = GetAncient(TEAM_RADIANT):GetLocation()
    local vDire = GetAncient(TEAM_DIRE):GetLocation()
    assert(not (vRad.x == 0 and vRad.y == 0),
        'this fixture lost its buildings -- GetAncient fell back to the map '
        .. 'origin and every distance below would be fiction')

    -- The frame's OWN tower list, so the declaration above is checked against
    -- data rather than trusted.
    --
    -- Read from fx.buildings and NOT from bot:GetNearbyTowers: that API filters
    -- to towers still standing (correct for it -- every shipped reader means
    -- "the nearest tower still there"), and this file is asking where the LANE
    -- is.  A lane does not move when its tower dies.  Using the live list would
    -- silently drop a vertex on any late-game frame, which is exactly what it
    -- did on the first run of this file.
    local seen = {}
    for _, b in ipairs(fx.buildings or {}) do
        if b.name == 'tower' then
            seen[math.floor(b.x + 0.5) .. ',' .. math.floor(b.y + 0.5)] = true
        end
    end

    local verts = { vRad }
    for _, entry in ipairs({ { 'radiant', false }, { 'dire', true } }) do
        for _, p in ipairs(LANE_TOWERS[sLane][entry[1]]) do
            local key = p[1] .. ',' .. p[2]
            assert(seen[key], 'declared ' .. sLane .. ' tower ' .. key
                .. ' is not in this frame -- the lane polyline would be fiction')
            verts[#verts + 1] = Vector(p[1], p[2], 0)
        end
    end
    verts[#verts + 1] = vDire

    -- Arc-length parameterisation, which is what "fraction along the lane"
    -- means.  A vertex-index parameterisation would bunch the 21 samples on the
    -- short segments and is not what the engine hands back.
    local cum, total = { 0 }, 0
    for i = 1, #verts - 1 do
        total = total + dist(verts[i], verts[i + 1])
        cum[i + 1] = total
    end
    local function at(t)
        local want = t * total
        for i = 1, #verts - 1 do
            if want <= cum[i + 1] or i == #verts - 1 then
                local seg = cum[i + 1] - cum[i]
                local f = seg > 0 and (want - cum[i]) / seg or 0
                return Vector(verts[i].x + (verts[i + 1].x - verts[i].x) * f,
                              verts[i].y + (verts[i + 1].y - verts[i].y) * f, 0)
            end
        end
    end

    local nCalls, tLanesAsked = 0, {}
    GetLocationAlongLane = function(nLane, t) -- luacheck: ignore
        nCalls = nCalls + 1
        tLanesAsked[nLane] = (tLanesAsked[nLane] or 0) + 1
        return at(t)
    end

    rawget(bot, '__spec').GetAssignedLane = LANE_ID[sLane]
    J.IsSoakCandidate = function(id) return id == 'pulldrag' end

    local vCamp = Vector(CAMP[sSide][1], CAMP[sSide][2], 0)
    -- The 21-point polyline the code under test actually sees.  It is NOT the
    -- tower polyline: 21 samples on a ~19,000u lane sit ~950u apart, so at a
    -- bend the sampled chain chords the corner.  That is a property of the
    -- engine's predicate too (it samples the same way), so the right reference
    -- for "did it pick the closest point" is this chain, and the right
    -- reference for "did the walk close the real gap" is the tower polyline.
    local sampled = {}
    for k = 0, 20 do sampled[#sampled + 1] = at(k / 20) end

    return J, bot, {
        verts = verts, sampled = sampled, vCamp = vCamp,
        vBot = bot:GetLocation(),
        vFountain = J.GetTeamFountain(),
        calls = function() return nCalls end,
        lanes_asked = function() return tLanesAsked end,
        gap = function(v) return gap_to_lane(v, verts) end,
        sampled_gap = function(v) return gap_to_lane(v, sampled) end,
    }
end

-- The two frames the numbers are quoted on.  Both are REAL supports standing
-- inside the 1400u the drag cadence uses to decide the camp is here, and both
-- sit on an ordinary tower-to-tower stretch rather than in the map corner --
-- the corner is the one place a straight-segment polyline reads differently
-- from the engine's 21 samples, so the load-bearing numbers are kept out of it.
local DIRE_A = { 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
                 'npc_dota_hero_lich', 'TOP', 'dire' }
local DIRE_B = { 'tests/fixtures/f_221200_od_roles.lua',
                 'npc_dota_hero_medusa', 'TOP', 'dire' }
-- Radiant, for the other physical side.  Its own reading IS corner-sensitive,
-- so only the inequality is asserted on it, never the two magnitudes.
local RADIANT = { 'tests/fixtures/f_260820_043039_cm_cask_close.lua',
                  'npc_dota_hero_witch_doctor', 'BOT', 'radiant' }

local function drag_target(f)
    local J, bot, geo = frame(f[1], f[2], f[3], f[4])
    return J.GetLanePullDragTarget(bot, geo.vCamp), J, bot, geo
end

tests['the drag target is a point ON the sampled lane path'] = function()
    for _, f in ipairs({ DIRE_A, DIRE_B, RADIANT }) do
        local v, _, _, geo = drag_target(f)
        assert(v ~= nil, f[2] .. ': armed and the lane is readable, so there '
            .. 'must be a target')
        assert(geo.sampled_gap(v) < 0.01, f[2] .. ': target is '
            .. math.floor(geo.sampled_gap(v)) .. 'u off the path it was given')
        -- And that path is a fair stand-in for the real lane HERE.  Quoted, not
        -- assumed: this is the sampling error the radiant frame is kept out of.
        assert(geo.gap(v) < 200, f[2] .. ': the sampled path drifts '
            .. math.floor(geo.gap(v)) .. 'u from the tower line at the target')
    end
end

tests['the drag target is the CLOSEST point on that path to the camp'] = function()
    -- Not merely on the path: the whole value of the lever is that it is the
    -- shortest way from the camp to the wave's road.  Measured against the
    -- polyline the code was handed, so a sampling artifact cannot be mistaken
    -- for the code picking a worse point.
    for _, f in ipairs({ DIRE_A, DIRE_B, RADIANT }) do
        local v, _, _, geo = drag_target(f)
        local d = dist(geo.vCamp, v)
        local best = geo.sampled_gap(geo.vCamp)
        assert(math.abs(d - best) < 2.0, f[2] .. ': target is ' .. math.floor(d)
            .. 'u from the camp but the path passes ' .. math.floor(best)
            .. 'u away -- some nearer point on it was not chosen')
    end
end

tests['the shipped home-ward step spends almost nothing on the gap it must close'] = function()
    -- The load-bearing measurement, on the two corner-free frames.
    for _, f in ipairs({ DIRE_A, DIRE_B }) do
        local vLane, _, _, geo = drag_target(f)
        local d0 = geo.gap(geo.vBot)
        local nHome = d0 - geo.gap(step_toward(geo.vBot, geo.vFountain))
        local nLane = d0 - geo.gap(step_toward(geo.vBot, vLane))
        assert(nHome <= 150, f[2] .. ': home-ward step closed ' .. math.floor(nHome)
            .. 'u -- this test is quoting it as <=150')
        assert(nLane >= 450, f[2] .. ': lane-ward step closed only '
            .. math.floor(nLane) .. 'u of a ' .. STEP .. 'u walk')
        assert(nLane >= nHome * 3, f[2] .. ': lane-ward is not decisively better')
    end
end

tests['the same holds on the other physical side (inequality only)'] = function()
    -- The radiant camp sits near the map corner, where a polyline drawn
    -- straight between towers and the engine's 21-sample polyline disagree by
    -- more than the numbers above can tolerate.  The ORDERING survives that
    -- disagreement (checked under both models in the python ratchet), so the
    -- ordering is all that is asserted here.  Asserting the magnitudes on this
    -- frame would be asserting the corner.
    local vLane, _, _, geo = drag_target(RADIANT)
    local d0 = geo.gap(geo.vBot)
    local nHome = d0 - geo.gap(step_toward(geo.vBot, geo.vFountain))
    local nLane = d0 - geo.gap(step_toward(geo.vBot, vLane))
    assert(nLane - nHome >= 300, 'radiant: lane-ward beat home-ward by only '
        .. math.floor(nLane - nHome) .. 'u')
end

tests['the path is sampled along the lane this bot was ASSIGNED'] = function()
    local _, _, _, geo = drag_target(DIRE_A)
    local asked = geo.lanes_asked()
    assert(asked[LANE_ID.TOP] ~= nil, 'the assigned lane was never sampled')
    assert(asked[LANE_ID.BOT] == nil and asked[LANE_ID.MID] == nil,
        'a lane other than the assigned one was sampled -- a hardcoded lane '
        .. 'would pass every distance assertion in this file')
end

tests['gate closed -> nil, so the shipped home-ward walk is byte-identical'] = function()
    local J, bot, geo = frame(DIRE_A[1], DIRE_A[2], DIRE_A[3], DIRE_A[4])
    J.IsSoakCandidate = function() return false end
    assert(J.GetLanePullDragTarget(bot, geo.vCamp) == nil,
        'the lever answers while disarmed')
    assert(geo.calls() == 0,
        'the disarmed path still sampled the lane -- a disarmed candidate must '
        .. 'not even cost the engine calls')
end

tests['not turbo -> nil'] = function()
    local J, bot, geo = frame(DIRE_A[1], DIRE_A[2], DIRE_A[3], DIRE_A[4])
    local prev = GetGameMode
    GetGameMode = function() return 22 end -- luacheck: ignore
    local v = J.GetLanePullDragTarget(bot, geo.vCamp)
    GetGameMode = prev -- luacheck: ignore
    assert(v == nil, 'the lever answers outside turbo')
end

tests['an engine that cannot say where the lane is falls back, never mutes'] = function()
    -- Two ways the world can refuse, and both must land on the SHIPPED walk
    -- rather than on a redirected one.  "Falls back" is the whole reason this
    -- returns nil instead of, say, the camp itself.
    local J, bot, geo = frame(DIRE_A[1], DIRE_A[2], DIRE_A[3], DIRE_A[4])
    -- Declared as a function, not by clearing the spec entry: an UNSET method
    -- in this harness does not read nil, it falls through to the mock's `^Get`
    -- default.  Clearing it would therefore test the default, not the refusal.
    rawget(bot, '__spec').GetAssignedLane = function() return nil end
    assert(J.GetLanePullDragTarget(bot, geo.vCamp) == nil, 'no assigned lane')

    local J2, bot2, geo2 = frame(DIRE_B[1], DIRE_B[2], DIRE_B[3], DIRE_B[4])
    GetLocationAlongLane = function() return nil end -- luacheck: ignore
    assert(J2.GetLanePullDragTarget(bot2, geo2.vCamp) == nil, 'unreadable lane')
end

tests['nil camp -> nil (the caller has no plan yet)'] = function()
    local J, bot = frame(DIRE_A[1], DIRE_A[2], DIRE_A[3], DIRE_A[4])
    assert(J.GetLanePullDragTarget(bot, nil) == nil)
    assert(J.GetLanePullDragTarget(nil, Vector(0, 0, 0)) == nil)
end

tests['the 21 samples are paid once per pull, not once per frame'] = function()
    -- The drag runs for ~10s of frames.  Without the cache this would be 21
    -- engine calls per frame for a value that cannot change.
    local J, bot, geo = frame(DIRE_A[1], DIRE_A[2], DIRE_A[3], DIRE_A[4])
    local v1 = J.GetLanePullDragTarget(bot, geo.vCamp)
    local nFirst = geo.calls()
    assert(nFirst == 21, 'expected 21 samples, saw ' .. nFirst)
    local v2 = J.GetLanePullDragTarget(bot, geo.vCamp)
    assert(geo.calls() == nFirst, 'the second call re-sampled the lane')
    assert(v1 == v2 or dist(v1, v2) < 0.001, 'the cached answer changed')
end

tests['[reverse] a DIFFERENT camp must re-sample, not reuse the cache'] = function()
    -- The cheap wrong cache keys on the bot alone.  A support who abandons one
    -- camp for another would then drag toward the first camp's lane point
    -- forever, and every assertion above would still pass.
    local J, bot, geo = frame(DIRE_A[1], DIRE_A[2], DIRE_A[3], DIRE_A[4])
    local v1 = J.GetLanePullDragTarget(bot, geo.vCamp)
    local n1 = geo.calls()
    local vOther = Vector(geo.vCamp.x + 2200, geo.vCamp.y - 1800, 0)
    local v2 = J.GetLanePullDragTarget(bot, vOther)
    assert(geo.calls() > n1, 'a different camp reused the cached target')
    assert(dist(v1, v2) > 100, 'a camp 2,800u away produced the same target')
end

tests['[reverse] a DIFFERENT assigned lane must re-sample'] = function()
    -- Same failure one level up: a bot reassigned mid-laning-phase.
    local J, bot, geo = frame(DIRE_A[1], DIRE_A[2], DIRE_A[3], DIRE_A[4])
    J.GetLanePullDragTarget(bot, geo.vCamp)
    local n1 = geo.calls()
    rawget(bot, '__spec').GetAssignedLane = LANE_ID.BOT
    J.GetLanePullDragTarget(bot, geo.vCamp)
    assert(geo.calls() > n1, 'a lane reassignment reused the cached target')
    assert(geo.lanes_asked()[LANE_ID.BOT] ~= nil, 'the new lane was never sampled')
end

tests['[reverse] the lever changed the DIRECTION and nothing else'] = function()
    -- One lever at a time.  The camp filter this ruling proposed tightening,
    -- the reach, the poke cadence and the step length are all still someone
    -- else's id -- and PULL_CAMP_LANE_GAP in particular must NOT have been
    -- tightened, because the geometry check refused that.
    local fh = assert(io.open('bots/FunLib/jmz_func.lua'))
    local src = fh:read('*a'); fh:close()
    assert(src:find('local PULL_CAMP_LANE_GAP = 1200', 1, true),
        'PULL_CAMP_LANE_GAP moved -- the geometry check REFUSED tightening it '
        .. '(see tools/agent/pullcamp_lane_geometry.py); re-read that verdict')
    assert(src:find('local vBest, nBestDist = nil, 1500', 1, true),
        'the 1500 reach moved together with the drag lever')

    local rh = assert(io.open('bots/mode_roam_generic.lua'))
    local roam = rh:read('*a'); rh:close()
    assert(roam:find('now - bot.campPullAttackTime > 3.0', 1, true),
        'the poke cadence moved together with the drag lever')
    assert(roam:find('dx / n * ' .. STEP, 1, true),
        'the drag step length moved -- the numbers in this file are per '
        .. STEP .. 'u walked')
    assert(roam:find('J.GetTeamFountain()', 1, true),
        'the shipped home-ward walk is gone -- with the gate closed there must '
        .. 'still be something to fall back to')
end

return tests
