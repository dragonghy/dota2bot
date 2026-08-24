-- GH #117 §4 (replay desk hand-back 20260823T090937Z): the own-side selector
-- clause landed 20260822 and bought a real, two-wave-consistent SAFETY win --
-- 20s-deaths after aggro 2/97 -> 0/146, wrong-side pulls 7.2% -> 0.0% -- but the
-- thing the mechanic exists for, the CONNECT rate, did not follow: 21.5% before,
-- 12.1% / 9.9% after. The arithmetic of why was measured, not guessed: over the
-- same waves the followers walk a median 742u out of their box (p90 992u, max
-- 1,170u) while the box sits a median 1,068u short of the nearest lane creep --
-- and NEITHER number moved when the camps moved closer to home. Moving a camp
-- toward our ANCIENT does not move it toward THIS LANE.
--
-- The repair adds ONE clause on the perpendicular axis: a candidate camp must
-- sit within PULL_CAMP_LANE_GAP (1200u) of the lane path this bot is assigned
-- to. It is gated separately as 'pulllane' so the connect rate stays
-- attributable, and it ADDS to the own-side clause rather than replacing it
-- (§4's wording was "replace"; replacing would hand back the safety win above to
-- buy the connect rate -- two levers, not one).
--
-- WHAT THIS FILE DECLARES, AND WHY THAT IS ALLOWED
--   * the LANE PATH is a declared stand-in. `GetLocationAlongLane` is a mock
--     constant Vector(0,0,0) (tests/mock/bot_api.lua) -- the corpus carries no
--     lane geometry at all, so there is no honest way to read one. Every lane
--     here is therefore a polyline built from the frame's OWN two REAL ancients,
--     bent to pass a stated distance from the bot. This is the same class of
--     declaration tests/test_pullcamp_ownside_camp.lua makes for the midpoint.
--   * camp SPAWN POINTS are declared: `GetNeutralSpawners()` is `{}` on 930/930
--     corpus frames (STOPPER 2 of tests/test_pullcamp_trigger_census.lua). Camp
--     OCCUPANCY would be game state; this file never declares it.
--   * `GetLaneFrontLocation` is REFUSED by the loader (GH #61), declared per
--     frame from that frame's real ancient.
-- What is REAL and load-bearing: the bot, his team, his position, both ancients,
-- and every distance below is computed from them.
--
-- HONEST LIMIT, stated up front: this file cannot answer "does the real map's
-- textbook pull camp fit under 1200u?" -- that needs a camp table the corpus
-- does not have. The anti-SILENT side of the constant is a WAVE question, and it
-- is pre-registered as such in the report: if poke_episodes collapses toward 0
-- on the evidence wave, the reading is "the constant is too tight", NOT "the
-- scenario is rare".

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The constant under test, restated here so a silent edit in bots/ shows up as a
-- failure rather than as a quietly-passing suite (pinned again in §4 [reverse]).
local GAP = 1200

-- Frame C of the sister file: a REAL dire support deep in his OWN half, far
-- enough inside the midpoint that NO camp within the untouched 1500 reach can be
-- rejected by the own-side clause. That is the whole reason it is used here:
-- on this frame every rejection below is unambiguously the NEW clause.
local FIX = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local HERO = 'npc_dota_hero_ogre_magi'

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Distance from a point to a polyline, measured to its SEGMENTS. Used only by
-- the assertions, never by the code under test -- it is the reference the
-- 21-sample path handed to bots/ is checked against.
local function seg_dist(v, a, b)
    local abx, aby = b.x - a.x, b.y - a.y
    local l2 = abx * abx + aby * aby
    if l2 <= 0 then return dist(v, a) end
    local t = ((v.x - a.x) * abx + (v.y - a.y) * aby) / l2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return dist(v, Vector(a.x + abx * t, a.y + aby * t, 0))
end

local function gap_to_polyline(v, verts)
    local best = math.huge
    for i = 1, #verts - 1 do
        local d = seg_dist(v, verts[i], verts[i + 1])
        if d < best then best = d end
    end
    return best
end

-- Loads the frame, arms both gates, and DECLARES a lane: the ancient-to-ancient
-- axis (which is what mid lane literally is, and the only direction a frame can
-- supply) translated sideways so that it passes exactly `nBotGap` from the bot.
-- nBotGap = 0 puts the bot in his lane -- the ordinary laning support.
--
-- The sideways translation is what keeps this frame ISOLATING: the lane's own
-- midpoint stays at the map middle, so the own-side clause is still arithmetically
-- unable to reject anything within the 1500 reach (asserted below), and every
-- rejection is therefore the new clause.
--
-- Returns the helper, the bot, and a `geo` table of REAL distances plus the unit
-- vectors the camps below are placed with.
local function frame(nBotGap)
    local J, bot = rf.load(FIX, HERO)

    local vOwn = GetAncient(bot:GetTeam()):GetLocation()
    local vEnemy = GetAncient(
        bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT):GetLocation()
    assert(not (vOwn.x == 0 and vOwn.y == 0),
        'this fixture lost its buildings -- GetAncient fell back to the map '
        .. 'origin (world assertion 17) and every distance below is fiction')

    local vBot = bot:GetLocation()
    local dx, dy = vEnemy.x - vOwn.x, vEnemy.y - vOwn.y
    local n = math.sqrt(dx * dx + dy * dy)
    local ax, ay = dx / n, dy / n          -- along the lane
    local px, py = -ay, ax                 -- perpendicular to it

    -- Perpendicular coordinate of the bot relative to the ancient axis, so the
    -- translated lane can be placed a stated distance from HIM.
    local b = (vBot.x - vOwn.x) * px + (vBot.y - vOwn.y) * py
    local s = b + nBotGap
    local verts = { Vector(vOwn.x + px * s, vOwn.y + py * s, 0),
                    Vector(vEnemy.x + px * s, vEnemy.y + py * s, 0) }
    local at = function(t)
        return Vector(verts[1].x + (verts[2].x - verts[1].x) * t,
                      verts[1].y + (verts[2].y - verts[1].y) * t, 0)
    end

    GetLocationAlongLane = function(_, t) return at(t) end -- luacheck: ignore
    local vMid = at(0.5)
    -- Declared (GH #61): our lane front pushed 25% PAST that midpoint -- the
    -- unfavourable equilibrium this helper is written for.
    local vFront = Vector(vOwn.x + (vMid.x - vOwn.x) * 1.25,
                          vOwn.y + (vMid.y - vOwn.y) * 1.25, 0)
    GetLaneFrontLocation = function() return vFront end -- luacheck: ignore

    J.IsSoakCandidate = function(id) return id == 'pullcamp' or id == 'pulllane' end

    return J, bot, {
        vOwn = vOwn, vMid = vMid, vBot = vBot, verts = verts, at = at,
        ax = ax, ay = ay, px = px, py = py,
        boundary = dist(vMid, vOwn),
        botDepth = dist(vBot, vOwn),
    }
end

-- Declares a camp list; `specs` is {name = {x, y}}, all on the bot's own team.
local function declare_camps(bot, specs)
    local list, made = {}, {}
    for name, s in pairs(specs) do
        local v = Vector(s[1], s[2], 0)
        made[name] = v
        list[#list + 1] = { location = v, team = bot:GetTeam() }
    end
    GetNeutralSpawners = function() return list end -- luacheck: ignore
    return made
end

-- Places a camp `along` units up-lane and `off` units to the side of the bot.
local function camp_at(geo, along, off)
    return { geo.vBot.x + geo.ax * along + geo.px * off,
             geo.vBot.y + geo.ay * along + geo.py * off }
end

-- ------------------------------------------------- 1. the frame is the case --

tests['the frame really isolates the new clause: own-side cannot reject here'] = function()
    local _, bot, geo = frame(0)
    assert(bot:IsAlive())
    -- Structural, not a sample: every camp inside the reach is at most
    -- botDepth + 1500 from our ancient, and that is still short of the midpoint.
    assert(geo.botDepth + 1500 < geo.boundary,
        string.format('the frame stopped being the isolating case: bot %.0fu + '
            .. '1500 reach vs midpoint %.0fu -- a rejection below could now be '
            .. 'the OLD clause and the teeth would be unattributable',
            geo.botDepth, geo.boundary))
    -- And the bot really is standing in the declared lane.
    assert(gap_to_polyline(geo.vBot, geo.verts) < 1,
        'frame(0) no longer puts the bot on his own lane')
end

tests['the helper measures to the SEGMENTS, not to the sample points'] = function()
    -- The whole reason bots/ measures to segments: with 21 samples on this
    -- ~15,400u lane the spacing is ~770u, so a camp whose closest point on the
    -- lane falls MIDWAY between two samples reads ~60u too far under a
    -- min-over-samples rule. Placed exactly there, at a true gap of 1,180u --
    -- inside the line by 20u, i.e. inside that error bar -- the two rules give
    -- opposite answers, and this asserts the segment one.
    local J, bot, geo = frame(0)
    local along = dist(geo.verts[1], geo.verts[2]) / 20 / 2  -- half a sample step
    local base = (geo.vBot.x - geo.verts[1].x) * geo.ax
                 + (geo.vBot.y - geo.verts[1].y) * geo.ay
    -- Shift the camp so its foot on the lane lands midway between two samples.
    local k = math.floor(base / (dist(geo.verts[1], geo.verts[2]) / 20))
    local footAlong = (k + 0.5) * (dist(geo.verts[1], geo.verts[2]) / 20)
    local spec = camp_at(geo, footAlong - base, 1180)
    local vCamp = Vector(spec[1], spec[2], 0)
    assert(math.abs(gap_to_polyline(vCamp, geo.verts) - 1180) < 5,
        'the reference disagrees about where this camp is -- the declared lane '
        .. 'is not the stated distance from the bot any more')

    local path = {}
    for i = 0, 20 do path[#path + 1] = geo.at(i / 20) end
    -- The point-wise rule would refuse it...
    local nPointWise = math.huge
    for _, v in ipairs(path) do
        local d = dist(vCamp, v)
        if d < nPointWise then nPointWise = d end
    end
    assert(nPointWise > GAP, string.format(
        'this camp no longer sits in the sampling blind spot (%.0fu point-wise) '
        .. '-- the case below stops discriminating between the two rules',
        nPointWise))
    -- ...the segment rule accepts it, and so does the selector.
    assert(J.IsCampBesideLane(vCamp, path), string.format(
        'a camp %.0fu from the lane was refused because its foot fell between '
        .. 'two samples -- the helper is measuring to points, not segments',
        gap_to_polyline(vCamp, geo.verts)))
    assert(dist(geo.vBot, vCamp) < 1500, 'the blind-spot camp left the reach')
    declare_camps(bot, { near = spec })
    assert(J.ShouldPullNeutralCamp(bot) ~= nil,
        'the selector refused a camp the helper accepts -- the two disagree')
end

-- --------------------------------------------- 2. teeth: which camp is chosen --

-- The off-lane camp is placed NEARER the bot than the on-lane one, which is the
-- whole point: under "nearest to the bot" ranking it wins.
local function two_camps(geo)
    return {
        -- 600u off the lane, 1,200u up it: 1,342u from the bot.
        lane = camp_at(geo, 1200, 600),
        -- 1,300u off the lane, straight to the side: 1,300u from the bot.
        off  = camp_at(geo, 0, 1300),
    }
end

tests['control: the off-lane camp is the NEARER one, and both are in reach'] = function()
    local _, bot, geo = frame(0)
    local c = declare_camps(bot, two_camps(geo))
    assert(dist(geo.vBot, c.off) < dist(geo.vBot, c.lane),
        'the off-lane camp stopped being the nearer of the two -- this case no '
        .. 'longer controls for the ranking the clause has to beat')
    assert(dist(geo.vBot, c.off) < 1500 and dist(geo.vBot, c.lane) < 1500,
        'both camps must be inside the untouched 1500 reach, or the choice is '
        .. 'made by reach rather than by the new clause')
    assert(gap_to_polyline(c.lane, geo.verts) < GAP,
        'the on-lane camp is no longer within one drag-length of the lane')
    assert(gap_to_polyline(c.off, geo.verts) > GAP,
        'the off-lane camp is no longer beyond one drag-length of the lane')
    -- Both are own-side, so the OLD clause has nothing to say about either.
    assert(dist(c.off, geo.vOwn) < geo.boundary and dist(c.lane, geo.vOwn) < geo.boundary,
        'a camp drifted past the midpoint -- the old clause would decide this')
end

tests['DEFECT: with pulllane disarmed the nearer OFF-LANE camp is what gets picked'] = function()
    local J, bot, geo = frame(0)
    local c = declare_camps(bot, two_camps(geo))
    J.IsSoakCandidate = function(id) return id == 'pullcamp' end
    local v = J.ShouldPullNeutralCamp(bot)
    assert(v ~= nil, 'the pull went silent with a legal camp in reach')
    assert(dist(v, c.off) < 1,
        'the shipped selector no longer picks the nearer off-lane camp -- then '
        .. 'this file is not witnessing GH #117 §4 any more')
end

tests['REPAIRED: the further ON-LANE camp is chosen over the nearer off-lane one'] = function()
    local J, bot, geo = frame(0)
    local c = declare_camps(bot, two_camps(geo))
    local v = J.ShouldPullNeutralCamp(bot)
    assert(v ~= nil, 'the pull went silent on a frame with a camp beside the lane')
    assert(dist(v, c.lane) < 1,
        'the selector still returns the off-lane camp -- it is ranking by '
        .. 'distance to the bot while the neutrals can only be dragged 1,170u')
end

tests['REPAIRED: with only the off-lane camp on the map there is no pull'] = function()
    local J, bot, geo = frame(0)
    declare_camps(bot, { off = camp_at(geo, 0, 1300) })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'a camp beyond the drag length is still pullable when it is the only '
        .. 'one -- the clause is being treated as a preference, not a filter')
end

tests['the witness shape: a jakiro-style 1,630u camp is refused, and was not before'] = function()
    -- run_001127/20260823_003129_slot4 jakiro pos5 t=161.4: an own-half camp far
    -- enough off his lane that the followers' distance to the nearest lane creep
    -- rose MONOTONICALLY 1,696u -> 3,418u over six seconds. Reproduced by shape,
    -- not by frame (that replay is not in the corpus): the lane runs 500u to one
    -- side of the bot and the camp sits 1,130u to the other -- 1,630u of gap, and
    -- still only 1,130u from the bot, i.e. comfortably inside the 1500 reach.
    local J, bot, geo = frame(500)
    local spec = camp_at(geo, 0, -1130)
    local vCamp = Vector(spec[1], spec[2], 0)
    local g = gap_to_polyline(vCamp, geo.verts)
    assert(g > 1600 and g < 1660, string.format(
        'the witness camp is %.0fu off the lane, not the ~1,630u this case is '
        .. 'written for', g))
    assert(dist(geo.vBot, vCamp) < 1500,
        'the witness camp left the 1500 reach -- it would now be refused by the '
        .. 'reach rather than by the clause, and the case proves nothing')
    declare_camps(bot, { witness = spec })
    -- Shipped behaviour today: taken.
    J.IsSoakCandidate = function(id) return id == 'pullcamp' end
    local before = J.ShouldPullNeutralCamp(bot)
    assert(before ~= nil and dist(before, vCamp) < 1,
        'the disarmed selector no longer takes the witness camp')
    -- Armed: refused.
    J.IsSoakCandidate = function(id) return id == 'pullcamp' or id == 'pulllane' end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the witness camp is still selected with pulllane armed')
end

tests['the constant has teeth: 20u either side of 1200 flips the answer'] = function()
    for _, case in ipairs({ { -20, true }, { 20, false } }) do
        local J, bot, geo = frame(0)
        local spec = camp_at(geo, 0, GAP + case[1])
        local vCamp = Vector(spec[1], spec[2], 0)
        assert(dist(geo.vBot, vCamp) < 1500, 'the edge camp left the reach')
        declare_camps(bot, { edge = spec })
        local v = J.ShouldPullNeutralCamp(bot)
        if case[2] then
            assert(v ~= nil and dist(v, vCamp) < 1, string.format(
                'a camp %.0fu from the lane -- inside the 1200 line -- was refused',
                GAP + case[1]))
        else
            assert(v == nil, string.format(
                'a camp %.0fu from the lane -- outside the 1200 line -- was taken',
                GAP + case[1]))
        end
    end
end

tests['the comparison is strict: a camp AT exactly 1200u is out'] = function()
    -- Pure arithmetic, deliberately not a game frame: on the declared lane above
    -- the perpendicular unit vector is irrational, so "exactly 1200u" is not
    -- representable and `<` vs `<=` would be decided by float noise. On an
    -- axis-aligned path it IS exact (sqrt(1200^2) is exact in IEEE doubles), so
    -- this is where the operator can be pinned at all.
    local J = rf.load(FIX, HERO)
    local path = { Vector(0, 0, 0), Vector(10000, 0, 0) }
    assert(not J.IsCampBesideLane(Vector(5000, GAP, 0), path),
        'a camp exactly ON the 1200u line was accepted -- the comparison went '
        .. 'from < to <=')
    assert(J.IsCampBesideLane(Vector(5000, GAP - 1, 0), path),
        'a camp 1u inside the line was refused')
    -- And the foot must be allowed to fall on an endpoint rather than past it:
    -- a camp beyond the end of the lane is measured to the end, not to infinity.
    assert(J.IsCampBesideLane(Vector(10000 + 500, 0, 0), path),
        'a camp 500u past the end of the lane was refused -- the distance is '
        .. 'being measured to the infinite line instead of to the segment')
    assert(not J.IsCampBesideLane(Vector(10000 + 1500, 0, 0), path),
        'a camp 1,500u past the end of the lane was accepted')
end

-- ------------------------------------------------------ 3. gate containment --

tests['control: pulllane armed but pullcamp NOT is byte-for-byte inert'] = function()
    -- The whole helper returns before the selector without pullcamp, so this can
    -- only ever be nil. Asserted rather than argued, because the arm string for
    -- the evidence wave has to carry BOTH ids and nothing else would notice.
    local J, bot, geo = frame(0)
    declare_camps(bot, two_camps(geo))
    J.IsSoakCandidate = function(id) return id == 'pulllane' end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'pulllane alone started producing pulls -- pullcamp is no longer the '
        .. 'outer gate and the evidence wave cannot attribute anything')
end

tests['control: with nothing armed the helper is inert'] = function()
    local J, bot, geo = frame(0)
    declare_camps(bot, two_camps(geo))
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the repair leaked out of the soak gates -- shipped turbo games would '
        .. 'start pulling')
end

tests['control: a nil/empty lane path answers TRUE, so an unreadable lane cannot mute the pull'] = function()
    local J = rf.load(FIX, HERO)
    assert(J.IsCampBesideLane(Vector(9999, 9999, 0), nil),
        'a nil path started rejecting camps -- disarming pulllane would then '
        .. 'change shipped behaviour instead of being a no-op')
    assert(J.IsCampBesideLane(Vector(9999, 9999, 0), {}),
        'an empty path started rejecting camps -- a lane the engine cannot '
        .. 'answer for would silently kill the mechanic')
    assert(J.IsCampBesideLane(nil, { Vector(0, 0, 0) }),
        'a nil camp location started being rejected rather than ignored')
end

-- ------------------------------------------------- 4. source pins [reverse] --

local function source(fn, n)
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local at = assert(src:find('function ' .. fn, 1, true), fn .. ' moved')
    return src:sub(at, at + (n or 12000)), src
end

tests['[reverse] the selector filters on the lane path AND on the ancient'] = function()
    local body = source('J.ShouldPullNeutralCamp')
    assert(body:find('return vBest', 1, true),
        'the source window no longer reaches the end of the selector -- the '
        .. 'pins below would be reading only part of it')
    assert(body:find('J.IsCampBesideLane( camp.location, tLanePath )', 1, true),
        'the lane-gap clause is gone from the selector')
    assert(body:find('GetLocationToLocationDistance( camp.location, vOwn ) < nMidToOwn', 1, true),
        'the own-side clause was REPLACED rather than added to -- that hands '
        .. 'back the 2/97 -> 0/146 death win to buy the connect rate')
    assert(body:find("J.IsSoakCandidate( 'pulllane' )", 1, true),
        'the new clause lost its own gate -- the connect rate of the evidence '
        .. 'wave is no longer attributable to one id')
end

tests['[reverse] the constant is 1200 and the third lever was NOT pulled'] = function()
    local _, src = source('J.ShouldPullNeutralCamp', 1)
    assert(src:find('local PULL_CAMP_LANE_GAP = ' .. GAP, 1, true),
        'PULL_CAMP_LANE_GAP moved away from the measured max drag (1,170u '
        .. 'rounded up) without this file being updated')
    -- One variable at a time (the #117 director ruling): the reach, the window
    -- and the HP gate are all still someone else's id.
    local body = source('J.ShouldPullNeutralCamp')
    assert(body:find('local vBest, nBestDist = nil, 1500', 1, true),
        'the 1500 reach moved together with the lane clause -- the connect rate '
        .. 'can no longer be attributed')
    local safe = source('J.IsLanePullSafe', 2000)
    assert(safe:find('if J.GetHP( bot ) < 0.5 then return false end', 1, true),
        'the HP gate moved -- that is still the SEPARATE camp-strength lever')
end

tests['[reverse] the lane path is sampled 21 times, which is what the error bar assumes'] = function()
    local body = source('J.ShouldPullNeutralCamp')
    assert(body:find('for k = 0, 20 do', 1, true),
        'the sample count changed -- the 43u error bar in the comment above it '
        .. 'is computed from 21 samples on a ~13,000u lane')
    assert(body:find('GetLocationAlongLane( nLane, k / 20 )', 1, true),
        'the path is no longer sampled along the ASSIGNED lane')
end

return tests
