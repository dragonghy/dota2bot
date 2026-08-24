-- GH #117: pullcamp picked "the own-team camp NEAREST THE BOT", while its own
-- equilibrium clause guarantees the bot is standing FORWARD -- so the camp it
-- picked was systematically a deep-jungle one, and the pull could not connect
-- (<= 20.3% over 283 games, neutrals walking a median 742u and stopping a
-- median 1,068u short of the wave).
--
-- The repair adds ONE clause to the selector: the camp must also be on our side
-- of the lane midpoint. The reach (1500), the pull window and the `>= 0.5` HP
-- gate are deliberately untouched -- the director's ruling on #117 is one lever
-- at a time, and the HP/camp-strength gate is a separate id later.
--
-- WHAT THIS FILE DECLARES, AND WHY THAT IS ALLOWED
--   * camp SPAWN POINTS are map constants, the same class of thing as the
--     ancient's position (`GetNeutralSpawners()` is `{}` on 930/930 corpus
--     frames -- STOPPER 2 of tests/test_pullcamp_trigger_census.lua). Camp
--     OCCUPANCY would be game state; this file never declares it.
--   * `GetLaneFrontLocation` is REFUSED by the loader (GH #61), so each frame
--     declares it on one visible line, derived from that frame's REAL ancient.
--   * `GetLocationAlongLane` is a mock constant, so the lane midpoint is
--     declared as the map midpoint between the two REAL ancients of the frame.
-- Everything the assertions turn on -- the bot's position, both ancients, the
-- distances -- is read off the real frame.
--
-- Frame A's camp is not invented either: (3994,-5137) is the single most
-- occupied poke location of the 283-game armed wave (95 of 267 poke frames;
-- its dire mirror another 41 -- 51% between them), i.e. the camp this defect
-- actually sent supports to.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Frame A: a REAL radiant pos 5 standing where those pulls started -- 10,527u
-- from his own ancient, 68% of the way across the map.
local A_FIX = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local A_HERO = 'npc_dota_hero_witch_doctor'
-- Frame B: a REAL dire support 51u INSIDE the midpoint boundary -- the only
-- geometry in the corpus where own-side and deep camps both fit in the 1500
-- reach, so it is the frame that can assert WHICH camp is chosen on both sides.
local B_FIX = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'
local B_HERO = 'npc_dota_hero_silencer'
-- Frame C: a REAL dire support deep in his OWN half -- far enough inside the
-- boundary that no camp within the reach can be a deep one, so the new clause
-- is structurally incapable of moving this frame.
local C_FIX = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local C_HERO = 'npc_dota_hero_ogre_magi'

-- The measured hot spot of the defect (GH #117 comment, 283 games).
local OBSERVED_DEEP_CAMP = { 3994, -5137 }

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Loads a frame, arms the gate, and declares the three map facts the loader
-- cannot answer. Returns the helper, the bot, and a `geo` table of the REAL
-- distances every assertion below is written against.
local function frame(path, hero)
    local J, bot = rf.load(path, hero)

    local vOwn = GetAncient(bot:GetTeam()):GetLocation()
    local vEnemy = GetAncient(
        bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT):GetLocation()
    assert(not (vOwn.x == 0 and vOwn.y == 0),
        'this fixture lost its buildings -- GetAncient fell back to the map '
        .. 'origin (world assertion 17) and every distance below is fiction')

    -- Declared: the lane midpoint is the midpoint between the two real ancients.
    local vMid = Vector((vOwn.x + vEnemy.x) / 2, (vOwn.y + vEnemy.y) / 2, 0)
    -- Declared (GH #61): our lane front pushed 25% PAST that midpoint, i.e. the
    -- unfavourable equilibrium this helper is written for.
    local vFront = Vector(vOwn.x + (vMid.x - vOwn.x) * 1.25,
                          vOwn.y + (vMid.y - vOwn.y) * 1.25, 0)
    GetLocationAlongLane = function() return vMid end -- luacheck: ignore
    GetLaneFrontLocation = function() return vFront end -- luacheck: ignore

    J.IsSoakCandidate = function(id) return id == 'pullcamp' end

    local vBot = bot:GetLocation()
    return J, bot, {
        vOwn = vOwn, vMid = vMid, vBot = vBot,
        boundary = dist(vMid, vOwn),      -- a camp must be nearer than this
        botDepth = dist(vBot, vOwn),
    }
end

-- Declares a camp list. Each entry is {x, y, team} with team defaulting to the
-- bot's own; returns the Vector list so assertions can name them.
local function declare_camps(bot, specs)
    local list, made = {}, {}
    for name, s in pairs(specs) do
        local v = Vector(s[1], s[2], 0)
        made[name] = v
        list[#list + 1] = {
            location = v,
            team = s.enemy and (bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT)
                or bot:GetTeam(),
        }
    end
    GetNeutralSpawners = function() return list end -- luacheck: ignore
    return made
end

-- ------------------------------------------------ 1. frame A: the defect --

tests['frame A: the frame really is the defect -- deep bot, deep camp in reach'] = function()
    local _, bot, geo = frame(A_FIX, A_HERO)
    assert(bot:IsAlive())
    assert(bot:GetTeam() == TEAM_RADIANT, 'frame A is no longer a radiant frame')
    -- The bot is past the middle of the map, which is what the equilibrium
    -- clause implies and what the batch measured (median 57% across).
    assert(geo.botDepth > geo.boundary,
        string.format('frame A stopped witnessing a forward-standing puller: '
            .. 'bot %.0fu from own ancient, midpoint %.0fu',
            geo.botDepth, geo.boundary))
    assert(geo.botDepth > 10000 and geo.botDepth < 11000,
        'frame A moved: ' .. string.format('%.0f', geo.botDepth))

    local vCamp = Vector(OBSERVED_DEEP_CAMP[1], OBSERVED_DEEP_CAMP[2], 0)
    -- The camp the defect actually used is inside the untouched 1500 reach on
    -- this frame -- so the OLD selector, being nearest-in-reach, would take it.
    assert(dist(geo.vBot, vCamp) < 1500,
        string.format('the observed hot-spot camp is no longer inside the reach '
            .. 'on this frame (%.0fu) -- frame A stops witnessing the defect',
            dist(geo.vBot, vCamp)))
    -- And it is deep: further from our ancient than the lane midpoint is.
    assert(dist(vCamp, geo.vOwn) > geo.boundary,
        string.format('the observed hot-spot camp is no longer a deep camp: '
            .. '%.0fu vs midpoint %.0fu', dist(vCamp, geo.vOwn), geo.boundary))
end

tests['frame A: REPAIRED -- the deep camp that took 51% of poke frames is refused'] = function()
    local J, bot = frame(A_FIX, A_HERO)
    declare_camps(bot, { deep = OBSERVED_DEEP_CAMP })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the selector still returns the deep jungle camp -- GH #117 is back, '
        .. 'and with it a pull that connects <= 20.3% of the time')
end

tests['frame A: nil is the ONLY correct answer here, and not because of teeth'] = function()
    -- Stated because the negative above must not be read as evidence that the
    -- clause discriminates. It does not discriminate on frame A: the bot is
    -- 2,811u past the boundary while the reach is 1500, so NO camp within reach
    -- can be own-side. Whatever the camp list, the repaired selector returns nil
    -- here -- correctly (a support 68% of the way across the map has no
    -- textbook pull), but the teeth are asserted on frame B, not here.
    local J, bot, geo = frame(A_FIX, A_HERO)
    assert(geo.botDepth - 1500 > geo.boundary,
        string.format('frame A stopped being the unreachable case: bot %.0fu, '
            .. 'reach 1500, midpoint %.0fu -- the claim below is now false',
            geo.botDepth, geo.boundary))
    -- Drive it anyway with a camp ring around the bot: every direction, nil.
    for i = 0, 7 do
        local a = i * math.pi / 4
        declare_camps(bot, {
            ring = { geo.vBot.x + math.cos(a) * 1400, geo.vBot.y + math.sin(a) * 1400 },
        })
        assert(J.ShouldPullNeutralCamp(bot) == nil,
            string.format('a camp %d/8 of the way around the bot was accepted on '
                .. 'frame A -- the arithmetic above says that is impossible', i))
    end
end

-- ------------------------------- 2. frame B: which camp, asserted both ways --

-- Frame B's bot sits just inside the boundary, so both a deep camp and an
-- own-side camp fit in the 1500 reach. The deep one is placed NEARER, which is
-- the whole point: under "nearest to the bot" it wins.
local function frame_b()
    local J, bot, geo = frame(B_FIX, B_HERO)
    local ux = (geo.vBot.x - geo.vOwn.x) / geo.botDepth
    local uy = (geo.vBot.y - geo.vOwn.y) / geo.botDepth
    local camps = declare_camps(bot, {
        -- 700u further out from home than the bot: past the midpoint.
        deep = { geo.vBot.x + ux * 700, geo.vBot.y + uy * 700 },
        -- 1200u back toward home: on our side, but FURTHER from the bot.
        home = { geo.vBot.x - ux * 1200, geo.vBot.y - uy * 1200 },
    })
    return J, bot, geo, camps
end

tests['frame B: the control -- the deep camp is the nearer one, so it used to win'] = function()
    local _, bot, geo, camps = frame_b()
    assert(bot:IsAlive())
    assert(dist(geo.vBot, camps.deep) < dist(geo.vBot, camps.home),
        'the deep camp is no longer the nearer of the two -- this frame has '
        .. 'stopped controlling for the thing GH #117 is about')
    assert(dist(geo.vBot, camps.deep) < 1500 and dist(geo.vBot, camps.home) < 1500,
        'both camps must be inside the untouched 1500 reach, or the choice '
        .. 'below is made by reach rather than by the new clause')
    assert(dist(camps.deep, geo.vOwn) > geo.boundary,
        'the deep camp is not past the midpoint any more')
    assert(dist(camps.home, geo.vOwn) < geo.boundary,
        'the home camp is not on our side any more')
end

tests['frame B: REPAIRED -- the further, own-side camp is chosen over the nearer deep one'] = function()
    local J, bot, _, camps = frame_b()
    local v = J.ShouldPullNeutralCamp(bot)
    assert(v ~= nil, 'the pull went silent on a frame with a legal camp in reach')
    assert(dist(v, camps.home) < 1,
        'the selector picked the nearer DEEP camp -- it is still ranking by '
        .. 'distance to the bot instead of by which side of the lane the camp '
        .. 'is on')
end

tests['frame B: with only the deep camp on the map there is no pull'] = function()
    local J, bot, geo = frame(B_FIX, B_HERO)
    local ux = (geo.vBot.x - geo.vOwn.x) / geo.botDepth
    local uy = (geo.vBot.y - geo.vOwn.y) / geo.botDepth
    declare_camps(bot, { deep = { geo.vBot.x + ux * 700, geo.vBot.y + uy * 700 } })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'a camp past the midpoint is still pullable when it is the only one -- '
        .. 'the clause is being treated as a preference instead of a filter')
end

tests['frame B: the boundary has teeth -- 1u either side of the midpoint flips it'] = function()
    -- The clause is `<`, so a camp AT the boundary is out and a camp just inside
    -- is in. Both cases are the same frame and the same reach.
    for _, case in ipairs({ { -20, true }, { 20, false } }) do
        local J, bot, geo = frame(B_FIX, B_HERO)
        local ux = (geo.vBot.x - geo.vOwn.x) / geo.botDepth
        local uy = (geo.vBot.y - geo.vOwn.y) / geo.botDepth
        -- A point exactly `boundary + case[1]` from our ancient along the ray.
        local r = geo.boundary + case[1]
        local camps = declare_camps(bot, { edge = { geo.vOwn.x + ux * r, geo.vOwn.y + uy * r } })
        assert(dist(geo.vBot, camps.edge) < 1500, 'the edge camp left the reach')
        local v = J.ShouldPullNeutralCamp(bot)
        if case[2] then
            assert(v ~= nil and dist(v, camps.edge) < 1,
                'a camp 20u INSIDE the midpoint was refused')
        else
            assert(v == nil, 'a camp 20u PAST the midpoint was accepted')
        end
    end
end

tests['frame B: control -- unarmed pullcamp is still inert'] = function()
    local J, bot = frame_b()
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the repair leaked out of the pullcamp gate -- shipped turbo games '
        .. 'would start pulling')
end

-- ------------------------------------- 3. frame C: where it cannot do harm --

tests['frame C: a bot in his own half cannot be affected by the clause at all'] = function()
    local J, bot, geo = frame(C_FIX, C_HERO)
    -- Structural, not a sample: every camp inside the reach is at most
    -- botDepth + 1500 from our ancient, and on this frame that is still short
    -- of the midpoint. So the new clause cannot reject anything the old
    -- selector would have taken here.
    assert(geo.botDepth + 1500 < geo.boundary,
        string.format('frame C stopped being the safe case: bot %.0fu + 1500 '
            .. 'reach vs midpoint %.0fu', geo.botDepth, geo.boundary))
    local ux = (geo.vBot.x - geo.vOwn.x) / geo.botDepth
    local uy = (geo.vBot.y - geo.vOwn.y) / geo.botDepth
    local camps = declare_camps(bot, {
        out = { geo.vBot.x + ux * 1400, geo.vBot.y + uy * 1400 },
    })
    local v = J.ShouldPullNeutralCamp(bot)
    assert(v ~= nil and dist(v, camps.out) < 1,
        'the clause rejected a camp on a frame where it is arithmetically '
        .. 'impossible for a reachable camp to be deep -- it is reading '
        .. 'something other than the two ancients')
end

-- --------------------------------------------------- 4. source pins [reverse] --

-- [20260824] The window was 8000 chars until GH #117 §4 added ~2,300 chars of
-- clause and comment to the selector, which pushed `return vBest` out of it --
-- and every pin below then failed reading "the clause is gone" when the clause
-- was right there. A source window is a LINE ANCHOR wearing a different hat, so
-- it gets the same treatment: widen it, and assert that it still reaches the end
-- of the function so the next insertion fails with a message that is true.
local function source()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local at = assert(src:find('function J.ShouldPullNeutralCamp', 1, true),
        'J.ShouldPullNeutralCamp moved')
    local body = src:sub(at, at + 14000)
    assert(body:find('return vBest', 1, true),
        'the source window no longer reaches the end of J.ShouldPullNeutralCamp '
        .. '-- widen it; the pins below are about the clauses, not about length')
    return body
end

tests['[reverse] the selector filters on distance to our ancient, not just the bot'] = function()
    local body = source()
    assert(body:find('GetLocationToLocationDistance( camp.location, vOwn ) < nMidToOwn', 1, true),
        'the own-side clause is gone from the selector')
    assert(body:find('GetUnitToLocationDistance( bot, camp.location )', 1, true),
        'the reach-from-the-bot read is gone -- the two are meant to coexist, '
        .. 'the new clause filters and the old one ranks')
end

tests['[reverse] the second lever was NOT pulled: reach 1500 and HP gate 0.5 stand'] = function()
    -- The #117 ruling is one variable at a time. If a later change moves either
    -- of these in the same breath as the selector, the connect-rate readout of
    -- the next wave stops being attributable, and this test says so.
    local body = source()
    assert(body:find('local vBest, nBestDist = nil, 1500', 1, true),
        'the 1500 reach moved together with the selector -- #117 asked for one '
        .. 'lever, and the connect rate can no longer be attributed')

    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local at = assert(src:find('function J.IsLanePullSafe', 1, true),
        'J.IsLanePullSafe moved')
    assert(src:sub(at, at + 2000):find('if J.GetHP( bot ) < 0.5 then return false end', 1, true),
        'the HP gate moved -- that is the SECOND lever of #117 (camp strength), '
        .. 'and it is supposed to get its own id after this one is accepted')
end

return tests
