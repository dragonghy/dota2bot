-- [GH #740 / RULING 13, 20260911] soak candidate 'pullreach': the pull-camp
-- selector's missing "can the neutrals reach a lane at all" criterion.
--
-- WHAT THE RULING HANDED OVER, AND WHAT IT FORBADE
-- `pullcamp`+`pulldrag` left the test set as ONE atom (armed 37 -> 34; ⛔ NOT a
-- reject -- gate, helper and call site are kept verbatim) because condition (a)
-- read BUGGY on three independent corpora (W62/W63/W64; W64 verbatim
-- `VERIFY id=pullcamp verdict=BUGGY episodes=20`, the `>1200u` share climbing
-- 38.5% -> 73.7%). The mechanism is geometric, not behavioural: the camps the
-- selector chose sat a minimum perpendicular 2912 / 2372 / 2907 from ANY lane,
-- while the drag leash measured on the same corpus reaches a maximum of 1272 --
-- so the pull could not connect at the instant of the poke, and it still charged
-- ~19pp of HP and ~13s of lane time (connect rate 6.7% on W63).
--
-- ⛔⛔ THE TRAP THE RULING NAMES IN AS MANY WORDS: do not copy 1200, and do not
-- copy the once-proposed 1350. The connects this project has actually observed
-- sit at camp gaps 1200 / 1268 / 1268 / 1271 / 1271 (W63's three and W64's two).
-- ⚠️ The two constants are forbidden for DIFFERENT reasons, and this file says so
-- because reading them as one claim is how §2's case first went red against its
-- own data: 1200 cuts INTO that class (4 of 5 by the ruling's `>1200` bin, 5 of 5
-- by the strict `<` the predicate really uses), while 1350 cuts into nothing --
-- its defect is that its whole margin over the class, 79u, fits INSIDE the
-- 20-82u calibration width of the reconstruction the numbers came from.
-- `pulllane` may not be re-admitted as it stands, and its PULL_CAMP_LANE_GAP is
-- left untouched here.
--
-- WHERE 1800 COMES FROM -- the rule is max-margin, and the reason it is a rule
-- rather than a preference is that the known error in this family is a
-- CALIBRATION OFFSET, not scatter:
--
--     observed connects, camp gap   1200 1268 1268 1271 1271     max  1271
--     impossible tier (RULING 13)   2336 2372 2907 2912          min  2336
--
-- The band (1271, 2336) is empty; 1800 is its midpoint, leaving 529u of margin
-- on each side against a reconstruction that reads 20-82u wide of the engine at
-- the decision line (tools/agent/pullcamp_lane_geometry.py, calibration
-- paragraph). A cutoff hugging either class sits INSIDE that error bar. That is
-- exactly what went wrong at 1200: the two connect-producing camps sit ON the
-- behaviour bracket [1220, 1282) the geometry module derived from W7->W8.
--
-- WHAT IS REAL ON THE FRAME AND WHAT IS DECLARED
--   * REAL: both ancients and all 22 towers, read out of the fixture's own
--     building table through the shipped mock's geometric slot derivation. The
--     lane polylines below are built from NOTHING ELSE -- and §1 asserts they
--     agree coordinate-for-coordinate with the table the geometry module
--     validated against the observed W7->W8 firing split, so this is a measured
--     constant of this engine build rather than a number this file invented.
--   * REAL: the bot, his team, his position, his liveness.
--   * DECLARED (and it must be, honestly): `GetLocationAlongLane` is a mock
--     constant and `GetNeutralSpawners()` is `{}` on every corpus frame
--     (STOPPER 2 of tests/test_pullcamp_trigger_census.lua), so the engine's own
--     lane samples and its camp list cannot be read off a replay. Camp
--     OCCUPANCY is game state and is never declared here.
--   * The camp coordinates are the replay desk's measured centroids (GH #117
--     comment 20260825T01:3xZ), i.e. harvested from the .dem corpus, not chosen.
--
-- HONEST LIMIT, up front: this file proves the criterion PARTITIONS the two
-- observed classes with margin on the corpus' own map. It cannot prove the
-- partition is the right one for camps nobody has pulled from yet -- that is a
-- wave question, and it is pre-registered as such in the report: if
-- poke_episodes collapses toward zero on the evidence wave the reading is "the
-- line is too tight", NOT "the scenario is rare".

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The constant under test, restated so a silent edit in bots/ turns this file
-- red rather than letting the suite pass quietly (pinned again in §6).
local REACH = 1800

-- The two classes, verbatim from RULING 13 (GH #740). These are the whole
-- derivation of REACH, so they are data in this file, not prose in a comment.
local CONNECT_GAPS = { 1200, 1268, 1268, 1271, 1271 }
local IMPOSSIBLE_GAPS = { 2336, 2372, 2907, 2912 }

-- A dire support standing deep in his OWN half -- the same frame the sister file
-- tests/test_pullcamp_lane_gap.lua uses, chosen there because no camp inside the
-- untouched 1500 reach can be refused by the own-side clause on it. Every
-- rejection below is therefore attributable to the new clause alone.
local FIX = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local HERO = 'npc_dota_hero_ogre_magi'

-- Lane membership of the 18 lane towers, tier 3 -> tier 1 outward on the radiant
-- side and tier 1 -> tier 3 inward on the dire side. Same partition as
-- tools/agent/pullcamp_lane_geometry.py:LANE_TOWERS, which asserts it covers the
-- corpus' 22 towers exactly once; §1 re-asserts every coordinate against THIS
-- frame so the two cannot drift apart silently.
local LANE_SLOTS = {
    TOP = { 'TOWER_TOP_3', 'TOWER_TOP_2', 'TOWER_TOP_1' },
    MID = { 'TOWER_MID_3', 'TOWER_MID_2', 'TOWER_MID_1' },
    BOT = { 'TOWER_BOT_3', 'TOWER_BOT_2', 'TOWER_BOT_1' },
}
local LANE_TOWERS = {
    radiant = {
        TOP = { { -6592, -3408 }, { -6501, -872 }, { -6336, 1856 } },
        MID = { { -4640, -4144 }, { -3190, -2926 }, { -1544, -1408 } },
        BOT = { { -3952, -6112 }, { -360, -6256 }, { 4860, -6379 } },
    },
    dire = {
        TOP = { { -5275, 6036 }, { -128, 6016 }, { 3552, 5776 } },
        MID = { { 524, 652 }, { 2496, 2112 }, { 4272, 3759 } },
        BOT = { { 6269, -2240 }, { 6400, 384 }, { 6336, 3032 } },
    },
}

-- The measured camp centroids and what the corpus says about each one. `class`
-- is the OBSERVED fact, never a prediction: 'connect' = this camp produced
-- connects on W7/W8; 'impossible' = it is in the tier RULING 13 says cannot
-- deliver neutrals to any lane; 'quiet' = it fired and produced none, which is
-- evidence about the camp and not about this constant.
local CAMPS = {
    { name = 'radiant hot camp (fine centroid)', x = 3994, y = -5137, class = 'connect' },
    { name = 'dire hot camp (fine centroid)',    x = -4007, y = 4947, class = 'connect' },
    { name = 'radiant safe-lane camp',           x = 4000, y = -5000, class = 'connect' },
    { name = 'dire safe-lane camp',              x = -4000, y = 4800, class = 'connect' },
    { name = 'radiant (200,-5200)',              x = 200,  y = -5200, class = 'quiet' },
    { name = 'dire (-800,5000)',                 x = -800, y = 5000,  class = 'quiet' },
    { name = 'radiant (-4000,1000)',             x = -4000, y = 1000, class = 'impossible' },
    { name = 'dire (-2600,3800)',                x = -2600, y = 3800, class = 'impossible' },
    { name = 'dire (3400,-1400)',                x = 3400, y = -1400, class = 'impossible' },
}

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Distance to the SEGMENTS of a polyline. Used only by the assertions -- it is
-- the reference the code under test is checked against, never the code itself.
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

-- Loads the frame and reconstructs the three lane polylines from the frame's OWN
-- ancients and towers: radiant ancient -> radiant t3,t2,t1 -> dire t1,t2,t3 ->
-- dire ancient. Identical construction to pullcamp_lane_geometry.lane_paths.
local function map_from_frame()
    local J, bot = rf.load(FIX, HERO)
    local vRad = GetAncient(TEAM_RADIANT):GetLocation()
    local vDire = GetAncient(TEAM_DIRE):GetLocation()
    assert(not (vRad.x == 0 and vRad.y == 0),
        'this fixture lost its buildings -- GetAncient fell back to the map '
        .. 'origin and every distance below would be fiction')

    local paths = {}
    for lane, slots in pairs(LANE_SLOTS) do
        local verts = { vRad }
        for _, slot in ipairs(slots) do
            local h = GetTower(TEAM_RADIANT, _G[slot])
            assert(h ~= nil, 'radiant ' .. slot .. ' is missing from this frame')
            verts[#verts + 1] = h:GetLocation()
        end
        for i = #slots, 1, -1 do
            local h = GetTower(TEAM_DIRE, _G[slots[i]])
            assert(h ~= nil, 'dire ' .. slots[i] .. ' is missing from this frame')
            verts[#verts + 1] = h:GetLocation()
        end
        verts[#verts + 1] = vDire
        paths[lane] = verts
    end
    return J, bot, paths, vRad, vDire
end

local function min_gap(v, paths)
    local best, which = math.huge, nil
    for lane, verts in pairs(paths) do
        local g = gap_to_polyline(v, verts)
        if g < best then best, which = g, lane end
    end
    return best, which
end

-- --------------------------------- 1. the map this file measures against is real

tests['the frame carries the corpus map: 18 lane towers, coordinate for coordinate'] = function()
    local _, _, _, vRad, vDire = map_from_frame()
    local teams = { radiant = TEAM_RADIANT, dire = TEAM_DIRE }
    local n = 0
    for side, byLane in pairs(LANE_TOWERS) do
        for lane, pts in pairs(byLane) do
            for i, p in ipairs(pts) do
                -- LANE_SLOTS runs t3 -> t1; the geometry module's rows run
                -- OUTWARD from the radiant base, i.e. t3,t2,t1 on the radiant
                -- side and t1,t2,t3 on the dire side. Reading both with the same
                -- index is how this assertion first went red -- it compared dire
                -- t3 against dire t1 -- and the fix is the reversal, not a
                -- loosened tolerance.
                local slot = LANE_SLOTS[lane][side == 'dire' and (#pts + 1 - i) or i]
                local h = GetTower(teams[side], _G[slot])
                assert(h ~= nil, side .. ' ' .. slot .. ' missing')
                local v = h:GetLocation()
                assert(math.abs(v.x - p[1]) < 1 and math.abs(v.y - p[2]) < 1,
                    string.format(
                        'this frame puts %s %s at (%.0f,%.0f), the geometry '
                        .. 'module has it at (%d,%d) -- the map moved, or the '
                        .. 'mock renumbered the slots, and every gap below is '
                        .. 'measured against the wrong line',
                        side, slot, v.x, v.y, p[1], p[2]))
                n = n + 1
            end
        end
    end
    assert(n == 18, 'expected 18 lane towers, read ' .. n)
    -- The ancients are the polyline endpoints, so they are load-bearing too.
    assert(vRad.x < 0 and vRad.y < 0 and vDire.x > 0 and vDire.y > 0,
        'the two ancients are not on the diagonal they have been on in every '
        .. 'fixture -- the lane reconstruction is no longer this map')
end

tests['the reconstruction reproduces the corpus reading, not just itself'] = function()
    -- The geometry module's published table is the edge control: the camps that
    -- KEPT firing under pulllane's 1200 must read below the ones that went to
    -- 0.0, and the two connect-producing camps must be the two widest survivors.
    -- If this frame's reconstruction cannot reproduce that ORDER, nothing below
    -- is a reading of the real map.
    local _, _, paths = map_from_frame()
    local hot_r = min_gap(Vector(3994, -5137, 0), paths)
    local hot_d = min_gap(Vector(-4007, 4947, 0), paths)
    local quiet_r = min_gap(Vector(200, -5200, 0), paths)
    local quiet_d = min_gap(Vector(-800, 5000, 0), paths)
    local cleared = min_gap(Vector(1000, 2600, 0), paths)
    assert(hot_r > quiet_r and hot_d > quiet_d, string.format(
        'the connect-producing camps are no longer the WIDEST survivors '
        .. '(%.0f/%.0f vs %.0f/%.0f) -- the published W7->W8 order is not '
        .. 'reproduced and the reconstruction is not this map',
        hot_r, hot_d, quiet_r, quiet_d))
    assert(cleared > hot_r, string.format(
        'a camp that pulllane cleared (%.0f) now reads below one it kept '
        .. '(%.0f) -- the behaviour bracket the calibration rests on is gone',
        cleared, hot_r))
end

-- ------------------------------------ 2. the band, as arithmetic not as a taste

tests['REACH is the midpoint of an EMPTY band between the two observed classes'] = function()
    local maxConnect, minImpossible = -math.huge, math.huge
    for _, g in ipairs(CONNECT_GAPS) do
        if g > maxConnect then maxConnect = g end
    end
    for _, g in ipairs(IMPOSSIBLE_GAPS) do
        if g < minImpossible then minImpossible = g end
    end
    assert(maxConnect == 1271 and minImpossible == 2336,
        'the two classes changed -- re-derive REACH before editing this file')
    assert(maxConnect < REACH and REACH < minImpossible, string.format(
        'REACH %d fell out of the empty band (%d, %d): it now either refuses a '
        .. 'measured connect or admits a camp the ruling calls impossible',
        REACH, maxConnect, minImpossible))
    -- Max-margin: the midpoint is 1803.5 and 1800 is the round number just
    -- inside it, so the two margins must stay within 8u of each other.
    local lower, upper = REACH - maxConnect, minImpossible - REACH
    assert(math.abs(lower - upper) <= 8, string.format(
        'REACH stopped being the max-margin placement (%du below, %du above) '
        .. '-- a cutoff hugging either class sits inside the calibration error',
        lower, upper))
    -- ...and that margin has to dominate the one error that is actually known:
    -- the reconstruction reads 20-82u wide of the engine at the decision line.
    assert(lower >= 6 * 82, string.format(
        'the margin (%du) no longer dominates the 82u calibration width by 6x '
        .. '-- the placement is inside its own error bar again', lower))
end

tests['⛔ the two forbidden constants, each refused for its OWN reason'] = function()
    -- Stated as arithmetic so the refusal is checkable rather than quoted. The
    -- two constants the ruling forbids fail for DIFFERENT reasons, and lumping
    -- them together is how this case first went red against its own data.
    --
    -- 1200 -- it cuts INTO the connect class. Registered with the slicing rule
    -- alongside it (iron rule 4 (iii)): under the ruling's own `>1200` bin it
    -- refuses 4 of the 5 measured connects; under the comparison the shipped
    -- predicate actually uses (strict `<`, so a camp exactly ON the line is
    -- out) it refuses all 5. Both readings are damning; neither is quoted
    -- without saying which cut produced it.
    local strictly_out, bin_above = 0, 0
    for _, g in ipairs(CONNECT_GAPS) do
        if not (g < 1200) then strictly_out = strictly_out + 1 end
        if g > 1200 then bin_above = bin_above + 1 end
    end
    assert(bin_above == 4 and strictly_out == 5, string.format(
        "the connect class moved: RULING 13's `>1200` bin now reads %d of 5 "
        .. '(was 4) and the shipped strict `<` reads %d of 5 (was 5) -- '
        .. 're-read the ruling before touching REACH', bin_above, strictly_out))

    -- 1350 -- it does NOT cut into the class (nothing observed sits above it),
    -- and that is exactly why quoting "it refuses 4 of 5" would be false. Its
    -- defect is the other one: it clears the widest measured connect by 79u,
    -- which is INSIDE the 20-82u calibration width of the reconstruction that
    -- produced these numbers. A cutoff whose entire margin fits inside its own
    -- error bar is not a measurement, it is a coin flip on the numerator.
    local maxConnect = 0
    for _, g in ipairs(CONNECT_GAPS) do
        if g > maxConnect then maxConnect = g end
    end
    local refusedAt1350 = 0
    for _, g in ipairs(CONNECT_GAPS) do
        if not (g < 1350) then refusedAt1350 = refusedAt1350 + 1 end
    end
    assert(refusedAt1350 == 0,
        '1350 now cuts into the connect class -- then it fails for 1200\'s '
        .. 'reason as well and this case is understating it')
    assert(1350 - maxConnect <= 82, string.format(
        "1350's margin over the widest measured connect is %du, no longer "
        .. 'inside the 82u calibration width -- the stated reason for refusing '
        .. 'it has changed', 1350 - maxConnect))

    -- ...and the landed constant fails neither way.
    local refusedAtReach = 0
    for _, g in ipairs(CONNECT_GAPS) do
        if not (g < REACH) then refusedAtReach = refusedAtReach + 1 end
    end
    assert(refusedAtReach == 0,
        'the landed constant refuses a measured connect -- that is the exact '
        .. 'failure the ruling told this round not to repeat')
    assert(REACH - maxConnect > 82,
        'the landed constant is now inside the calibration width as well')
end

-- ---------------------------------- 3. teeth on the corpus' own camps and map

tests['the impossible tier is refused on EVERY lane, with margin'] = function()
    local J, _, paths = map_from_frame()
    local n = 0
    for _, c in ipairs(CAMPS) do
        if c.class == 'impossible' then
            local v = Vector(c.x, c.y, 0)
            local g, lane = min_gap(v, paths)
            assert(g > REACH + 300, string.format(
                '%s reads %.0fu from the %s lane -- it is no longer clear of '
                .. 'REACH by a margin the calibration can survive',
                c.name, g, lane))
            for laneName, verts in pairs(paths) do
                assert(not J.IsCampWithinPullReach(v, verts), string.format(
                    '%s (%.0fu off the %s lane) was ADMITTED -- this is the '
                    .. 'tier the neutrals provably cannot be dragged out of',
                    c.name, gap_to_polyline(v, verts), laneName))
            end
            n = n + 1
        end
    end
    assert(n == 3, 'expected 3 impossible-tier camps, checked ' .. n)
end

tests['every camp that ever produced a connect is still ADMITTED'] = function()
    -- The anti-SILENT side, and the reason it comes with the same weight as the
    -- teeth: tightening a distance threshold removes camps widest-first, so the
    -- connect numerator is the FIRST thing a badly placed cutoff deletes.
    local J, _, paths = map_from_frame()
    local n = 0
    for _, c in ipairs(CAMPS) do
        if c.class == 'connect' then
            local v = Vector(c.x, c.y, 0)
            local g, lane = min_gap(v, paths)
            assert(g < REACH - 300, string.format(
                '%s reads %.0fu from the %s lane, no longer comfortably inside '
                .. 'REACH -- the numerator is sitting on the line again',
                c.name, g, lane))
            local verts = paths[lane]
            assert(J.IsCampWithinPullReach(v, verts), string.format(
                '%s was REFUSED against its own %s lane -- the criterion just '
                .. 'deleted the entire connect numerator', c.name, lane))
            n = n + 1
        end
    end
    assert(n == 4, 'expected 4 connect-producing camps, checked ' .. n)
end

tests['the comparison is strict, and measured to segments not endpoints'] = function()
    -- Axis-aligned on purpose: sqrt(1800^2) is exact in IEEE doubles, so this is
    -- the only place the < vs <= choice can be pinned without float noise.
    local J = rf.load(FIX, HERO)
    local path = { Vector(0, 0, 0), Vector(10000, 0, 0) }
    assert(not J.IsCampWithinPullReach(Vector(5000, REACH, 0), path),
        'a camp exactly ON the line was accepted -- the comparison went from < '
        .. 'to <=, and this file no longer measures the constant it names')
    assert(J.IsCampWithinPullReach(Vector(5000, REACH - 1, 0), path),
        'a camp 1u inside the line was refused')
    assert(J.IsCampWithinPullReach(Vector(10500, 0, 0), path),
        'a camp 500u past the END of the lane was refused -- the distance is '
        .. 'being measured to the infinite line instead of to the segment')
    assert(not J.IsCampWithinPullReach(Vector(12000, 0, 0), path),
        'a camp 2,000u past the end of the lane was accepted')
end

-- ---------------------------- 4. the two filters must not become one bundle --

-- A lane declared straight along the two ancients and translated so it passes a
-- stated distance from the bot -- the sister file's construction, reused because
-- it is what lets a camp be placed at an exact gap. Returns the helper, the bot,
-- and the pieces needed to place camps.
local function declared_frame(nBotGap)
    local J, bot = rf.load(FIX, HERO)
    local vOwn = GetAncient(bot:GetTeam()):GetLocation()
    local vEnemy = GetAncient(
        bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT):GetLocation()
    local vBot = bot:GetLocation()
    local dx, dy = vEnemy.x - vOwn.x, vEnemy.y - vOwn.y
    local n = math.sqrt(dx * dx + dy * dy)
    local ax, ay = dx / n, dy / n
    local px, py = -ay, ax
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
    GetLaneFrontLocation = function() -- luacheck: ignore
        return Vector(vOwn.x + (vMid.x - vOwn.x) * 1.25,
                      vOwn.y + (vMid.y - vOwn.y) * 1.25, 0)
    end
    J.IsSoakCandidate = function(id) return id == 'pullcamp' or id == 'pullreach' end
    return J, bot, { vOwn = vOwn, vBot = vBot, verts = verts,
                     ax = ax, ay = ay, px = px, py = py,
                     boundary = dist(vMid, vOwn), botDepth = dist(vBot, vOwn) }
end

local function camp_at(geo, along, off)
    return { geo.vBot.x + geo.ax * along + geo.px * off,
             geo.vBot.y + geo.ay * along + geo.py * off }
end

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

tests['control: on this frame the own-side clause cannot decide anything'] = function()
    local _, bot, geo = declared_frame(0)
    assert(bot:IsAlive())
    assert(geo.botDepth + 1500 < geo.boundary, string.format(
        'the frame stopped isolating the new clause: bot %.0fu + 1500 reach vs '
        .. 'midpoint %.0fu -- a rejection below could be the OLD clause',
        geo.botDepth, geo.boundary))
end

tests['⛔ arming pullreach ALONE must not switch pulllane on underneath it'] = function()
    -- The bundling failure this family paid for twice, said as a case. A camp at
    -- 1500u of gap is OUTSIDE pulllane's 1200 and INSIDE pullreach's 1800, so it
    -- is the only witness that can tell the two constants apart.
    local J, bot, geo = declared_frame(0)
    local spec = camp_at(geo, 0, 1450)
    local vCamp = Vector(spec[1], spec[2], 0)
    local g = gap_to_polyline(vCamp, geo.verts)
    assert(g > 1200 and g < REACH, string.format(
        'the witness camp is %.0fu off the lane -- it no longer separates the '
        .. '1200 constant from the %d one', g, REACH))
    assert(dist(geo.vBot, vCamp) < 1500, 'the witness camp left the 1500 reach')
    declare_camps(bot, { witness = spec })
    local v = J.ShouldPullNeutralCamp(bot)
    assert(v ~= nil and dist(v, vCamp) < 1,
        'with only pullreach armed the camp was refused -- tReachPath is being '
        .. 'handed to J.IsCampBesideLane as well, so the two constants apply at '
        .. 'once and neither id is attributable')
    -- ...and with pulllane armed too, the same camp is refused by the 1200.
    J.IsSoakCandidate = function(id)
        return id == 'pullcamp' or id == 'pullreach' or id == 'pulllane'
    end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'pulllane stopped refusing a 1,450u camp -- its own constant moved')
end

tests['⛔ arming pulllane ALONE is byte-for-byte what it was before pullreach'] = function()
    -- The other direction of the same claim: the landed change must not alter
    -- what the banked `pulllane` readings measured.
    local J, bot, geo = declared_frame(0)
    local inside = camp_at(geo, 0, 900)     -- inside 1200, inside 1800
    local between = camp_at(geo, 0, 1450)   -- outside 1200, inside 1800
    J.IsSoakCandidate = function(id) return id == 'pullcamp' or id == 'pulllane' end
    declare_camps(bot, { c = between })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'pulllane alone stopped refusing the 1,450u camp')
    declare_camps(bot, { c = inside })
    local v = J.ShouldPullNeutralCamp(bot)
    assert(v ~= nil and dist(v, Vector(inside[1], inside[2], 0)) < 1,
        'pulllane alone stopped accepting a 900u camp -- the shipped clause '
        .. 'changed under a candidate that has readings banked against it')
end

tests['the far tier is refused end to end, through the selector'] = function()
    -- ⚠️ The witness has to be beyond REACH (1800) while staying inside the
    -- untouched 1500 reach-from-the-bot, so it CANNOT be placed with the bot
    -- standing in his own lane: from there the gap never exceeds the distance to
    -- the bot. The lane is therefore declared 600u to one side of him and the
    -- camp put 1,250u to the other -- 1,850u of gap, 1,250u from the bot. That is
    -- the geometry of the filed defect too: a support pulled out of position
    -- picks a camp that is near HIM and nowhere near his wave.
    local J, bot, geo = declared_frame(600)
    local spec = camp_at(geo, 0, -1250)
    local vCamp = Vector(spec[1], spec[2], 0)
    local g = gap_to_polyline(vCamp, geo.verts)
    assert(g > REACH and g < REACH + 200, string.format(
        'the witness camp is %.0fu off the lane -- it is no longer the just-'
        .. 'outside case this test is written for', g))
    assert(dist(geo.vBot, vCamp) < 1500, 'the witness camp left the 1500 reach')
    assert(geo.botDepth + 1500 < geo.boundary,
        'the translated lane stopped isolating the new clause -- a rejection '
        .. 'below could now be the own-side clause')
    declare_camps(bot, { far = spec })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'a camp beyond the reach criterion is still pullable when it is the '
        .. 'only one -- the clause is being treated as a preference, not a filter')
    -- ...and today, with pullreach disarmed, it IS taken. Without this leg the
    -- case above could be passing because the frame produces no pull at all.
    J.IsSoakCandidate = function(id) return id == 'pullcamp' end
    local before = J.ShouldPullNeutralCamp(bot)
    assert(before ~= nil and dist(before, vCamp) < 1,
        'the disarmed selector no longer takes the far camp -- this file has '
        .. 'stopped witnessing the defect GH #740 filed')
end

-- ------------------------------------------------------- 5. gate containment

tests['control: pullreach armed but pullcamp NOT is inert'] = function()
    local J, bot, geo = declared_frame(0)
    declare_camps(bot, { c = camp_at(geo, 0, 900) })
    J.IsSoakCandidate = function(id) return id == 'pullreach' end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'pullreach alone started producing pulls -- pullcamp is no longer the '
        .. 'outer gate and an evidence wave could not attribute anything')
end

tests['control: with nothing armed the shipped selector is untouched'] = function()
    local J, bot, geo = declared_frame(0)
    declare_camps(bot, { c = camp_at(geo, 0, 900) })
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the repair leaked out of the soak gates -- shipped turbo games would '
        .. 'start pulling')
end

tests['control: a nil/empty path answers TRUE, so an unreadable lane cannot mute the pull'] = function()
    local J = rf.load(FIX, HERO)
    assert(J.IsCampWithinPullReach(Vector(9999, 9999, 0), nil),
        'a nil path started rejecting camps -- disarming pullreach would then '
        .. 'change shipped behaviour instead of being a no-op')
    assert(J.IsCampWithinPullReach(Vector(9999, 9999, 0), {}),
        'an empty path started rejecting camps -- a lane the engine cannot '
        .. 'answer for would silently kill the mechanic')
    assert(J.IsCampWithinPullReach(Vector(9999, 9999, 0), { Vector(0, 0, 0) }),
        'a one-vertex path has no segment to measure against and must not '
        .. 'reject anything')
    assert(J.IsCampWithinPullReach(nil, { Vector(0, 0, 0), Vector(1, 1, 0) }),
        'a nil camp location started being rejected rather than ignored')
end

-- --------------------------------------------------- 6. source pins [reverse]

local function source(fn, n)
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local at = assert(src:find('function ' .. fn, 1, true), fn .. ' moved')
    return src:sub(at, at + (n or 16000)), src
end

tests['[reverse] the selector asks the reach question, and asks it separately'] = function()
    local body = source('J.ShouldPullNeutralCamp')
    assert(body:find('return vBest', 1, true),
        'the source window no longer reaches the end of the selector -- the '
        .. 'pins below would be reading only part of it')
    assert(body:find('J.IsCampWithinPullReach( camp.location, tReachPath )', 1, true),
        'the reach clause is gone from the selector')
    assert(body:find('J.IsCampBesideLane( camp.location, tLanePath )', 1, true),
        'the pulllane clause was REPLACED rather than added beside -- that is '
        .. 'two levers in one change')
    -- The two samplings are separate blocks, each under its OWN single gate.
    -- Sharing one loop between them is what two sister files forbid (a retired
    -- id's lever body must stay byte-identical; two soak ids on one line is the
    -- pullcad shape), so the duplication is pinned rather than tolerated.
    assert(body:find("if J.IsSoakCandidate( 'pulllane' ) then\n\t\ttLanePath = {}", 1, true),
        "the 'pulllane' sampling block changed shape -- that id is RETIRED, not "
        .. 'rejected, and its lever body must stay byte-identical')
    assert(body:find("if J.IsSoakCandidate( 'pullreach' ) then\n\t\ttReachPath = {}", 1, true),
        "the 'pullreach' path is no longer sampled under its own single gate")
    assert(not body:find("IsSoakCandidate( 'pulllane' ) or", 1, true),
        'the two samplings were merged back under one condition -- one id can '
        .. "no longer be armed without entering the other's code path")
end

tests['[reverse] the gate is STANDALONE, not conjoined with an id that can be promoted'] = function()
    local body = source('J.ShouldPullNeutralCamp')
    -- The pullcad trap, as a pattern rather than as prose: a conjunction of two
    -- soak ids freezes FALSE the day either is promoted.
    -- `creeppull` and `pullbeat` are already PROMOTED, so a conjunction naming
    -- either is frozen FALSE today, not one day -- they lead the list for that
    -- reason rather than for tidiness.
    for _, other in ipairs({ 'creeppull', 'pullbeat',
                             'pullcamp', 'pulllane', 'pulldrag', 'pullnolane' }) do
        assert(not body:find("IsSoakCandidate( 'pullreach' ) and J.IsSoakCandidate( '"
            .. other .. "' )", 1, true),
            "'pullreach' was conjoined with '" .. other .. "' -- promoting that "
            .. 'id freezes this gate FALSE and the lever silently no-ops')
        assert(not body:find("IsSoakCandidate( '" .. other
            .. "' ) and J.IsSoakCandidate( 'pullreach' )", 1, true),
            "'pullreach' was conjoined with '" .. other .. "' (other order)")
    end
end

tests['[reverse] the constant is 1800 and pulllane\'s 1200 was NOT touched'] = function()
    local _, src = source('J.ShouldPullNeutralCamp', 1)
    assert(src:find('local PULL_CAMP_LANE_REACH = ' .. REACH, 1, true),
        'PULL_CAMP_LANE_REACH moved away from the max-margin placement this '
        .. 'file derives, without this file being updated')
    assert(src:find('local PULL_CAMP_LANE_GAP = 1200', 1, true),
        "pulllane's constant moved -- RULING 13 forbids re-admitting it as it "
        .. 'stands, and retuning it here would be a second lever')
    -- One lever at a time: the reach, the window and the HP gate stay elsewhere.
    local body = source('J.ShouldPullNeutralCamp')
    assert(body:find('local vBest, nBestDist = nil, 1500', 1, true),
        'the 1500 reach moved together with this clause -- the reading would '
        .. 'no longer be attributable to one id')
    assert(body:find('if nNow < 60 or nNow > 6 * 60 then return nil end', 1, true),
        'the pull window moved in the same change as the reach criterion')
end

tests['[reverse] the reach helper is its own function, not the gap one reused'] = function()
    local _, src = source('J.ShouldPullNeutralCamp', 1)
    assert(src:find('function J.IsCampWithinPullReach( vCamp, tLanePath )', 1, true),
        'J.IsCampWithinPullReach is gone or was renamed')
    assert(src:find('function J.IsCampBesideLane( vCamp, tLanePath )', 1, true),
        'J.IsCampBesideLane was folded into the new helper -- one helper '
        .. 'carrying two soak ids is the pullcad shape')
end

return tests
