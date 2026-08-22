-- GH #13 / OWNER_PRIORITIES P1(1): WHY THE CAMP PULL WAS SILENT.
--
-- The replay desk measured 10/10 batch games with zero pull traces on either
-- side and the director pulled `pullcamp` out of the armed line because
-- condition (a) never held. Nobody had a root cause. This file is the root
-- cause, the repair, and the honest boundary of what the fixture corpus can
-- and cannot say about either.
--
-- THE ROOT CAUSE, in one line: the trigger demanded the state its own action
-- exists to produce.
--
-- `J.ShouldPullNeutralCamp` required, before it would authorise anything,
--
--     local tNeut = bot:GetNearbyNeutralCreeps( 1400 )
--     if tNeut == nil or #tNeut == 0 then return nil end
--
-- i.e. "the puller can already SEE neutral creeps 1400u away". A support
-- standing in its lane cannot: the camp box sits behind trees, unlit, outside
-- vision. So the plan was never set; and because `mode_roam_generic`'s Think
-- only reaches its walk-to-the-camp branch once the plan EXISTS
-- (`bot.roamCampPull ~= nil`), nothing ever moved the bot toward the camp
-- either. Trigger waits for arrival, arrival waits for trigger. That is the
-- same mutually-exclusive shape as the creep pull's dead branch (GH #13,
-- 2026-08-19: `IsLanePullSafe` demanded no enemy within 1800 while
-- `ShouldCreepPullLane` demanded one within 1000) -- the second half of the
-- same issue, found the same way.
--
-- THE SECOND HALF OF THE REPAIR. Removing the vision precondition alone would
-- still not pull: the :12 / :42 marks are when the neutrals must be AGGROED,
-- so a bot that starts walking at :12 arrives after the wave has gone. The
-- window now opens a travel lead earlier (:05 and :35) -- 1500u of camp reach
-- at a support's ~300 u/s is 5s of walking. Leaving at :05 to aggro at :12 is
-- the human cadence; it is not a widened tolerance, and the mark itself is
-- unchanged. Both edits are one mechanism ("authorise the approach"), and
-- both are needed: section 2's witness frame sits at :07.4 and would be
-- rejected by the old window even with the vision clause gone.
--
-- WHAT THE CORPUS CANNOT SAY (the backlog 0p rule: an attribution must first
-- declare which branches are structurally unreachable on the frame it uses).
-- The chain cannot be driven end-to-end on ANY fixture. Four independent
-- stoppers, all measured below rather than argued:
--   (1) `bot:GetNearbyNeutralCreeps(1400)` is empty on 930/930 alive hero
--       frames -- the dumper carries no creeps at all, so the old clause was
--       false on 100% of the corpus for a reason that has nothing to do with
--       the game;
--   (2) `GetNeutralSpawners()` is `{}` on 930/930 -- the mock's stub; the
--       camp-reach loop therefore selects nothing;
--   (3) `GetLaneFrontLocation` is REFUSED by the loader (GH #61), so the
--       equilibrium clause raises unless a test declares it;
--   (4) `bot:GetAssignedLane()` is 0 on 930/930 -- lane assignment is bot-VM
--       state, not entity state, so it is not in the .dem (the thirteenth
--       world assertion's shape, GH #89). It is not nil, so the `nLane == nil`
--       guard passes and a bogus lane id is handed to `GetLocationAlongLane`.
-- Consequently section 2 is a DECLARED-WORLD test, labelled as such: its
-- teeth are on the clauses this repair touched, and its lane geometry and
-- camp list are visible declarations, not measurements. Section 1 is the
-- opposite: every number there is measured on real frames with nothing
-- declared.
--
-- WHAT THE CORPUS CAN SAY, and it is the number the owner's DoD asked for.
-- Of 930 alive hero frames, 36 are "a support, in the laning window
-- (60-360s), with no enemy inside 800" -- the peacetime lane-support state a
-- pull starts from. The old window admitted 10 of those 36; the widened one
-- admits 15. That is scenario frequency, not a dead condition: the timing
-- filter costs what a 22-of-60 (now 32-of-60) seconds-per-minute filter
-- should cost. And `J.IsLanePullSafe` -- the clause the owner suspected of
-- being a second dead condition -- passes on 339/930 frames, on a corpus
-- deliberately sampled at combat instants. IT IS NOT THE DEAD CONDITION;
-- the vision clause was.
--
-- CORPUS NOTE (2026-08-22T10:xxZ): first measured on 98 fixtures / 911 frames
-- and re-measured on 100 / 930 when the branch rebased onto main. What moved:
-- 33 -> 36 peacetime frames, 7 -> 10 old-window, 12 -> 15 new-window, 334 ->
-- 339 IsLanePullSafe. Every qualitative claim is unchanged. Two of the three
-- new chain frames come from a fixture that is not a lane either
-- (f_260822_063722_lina_tp_home, t=349.0, a TP-home episode), and the
-- lion_drain_jungle heal (cf7bb4c) permuted which heroes on that frame read as
-- supports -- the NEWONLY witness heroes changed name while the count did not.
--
-- ROLE-CENSUS HONESTY: "support" here is `not J.IsCore(bot)`, and by the
-- twelfth world assertion (GH #81) every ENEMY of the driven subject reads
-- pos 3 / IsCore, so the support count is an ally-side count. It biases the
-- 33 DOWN, never up, so the frequency read above is a floor.
--
-- The heavy sweep runs in a SUBPROCESS (tests/_pullcamp_sweep.lua) -- ~930
-- fresh loads of jmz_func, ~25s -- per the backlog 0q rule.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- ---------------------------------------------------------------- manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_pullcamp_sweep.lua 2>&1'),
        'could not start tests/_pullcamp_sweep.lua')
    local raw = p:read('*a')
    p:close()

    local m = { C = {}, CHAIN = {}, NEWONLY = {}, WIT = nil, done = false }
    for line in raw:gmatch('[^\n]+') do
        local kind = line:match('^(%S+)')
        if kind == 'C' then
            local k, n = line:match('^C (%S+) (%-?%d+)$')
            if k then m.C[k] = tonumber(n) end
        elseif kind == 'CHAIN' or kind == 'NEWONLY' then
            local fx, hero, sec = line:match('^%S+ (%S+) (%S+) (%S+)$')
            table.insert(m[kind], { fixture = fx, hero = hero, sec = tonumber(sec) })
        elseif kind == 'WIT' then
            local fx, hero, team, pos, x, y, hp, safe, neut = line:match(
                '^WIT (%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$')
            m.WIT = {
                fixture = fx, hero = hero, team = tonumber(team), pos = pos,
                x = tonumber(x), y = tonumber(y), hp = tonumber(hp),
                pullsafe = safe == 'true', camp_up = neut == 'true',
            }
        elseif kind == 'DONE' then
            m.done = true
        end
    end
    assert(m.done, 'the corpus sweep did not finish -- run '
        .. '`lua5.1 tests/_pullcamp_sweep.lua` by hand to see why:\n'
        .. raw:sub(1, 800))
    manifest_cache = m
    return m
end

local function C(key)
    local n = manifest().C[key]
    assert(n ~= nil, 'the sweep did not report counter ' .. key)
    return n
end

-- ------------------------------------------- 1. CENSUS on real frames only --

tests['census: the corpus is what the counts are measured over'] = function()
    assert(C('fixtures') == 100, 'fixture count moved: ' .. C('fixtures'))
    assert(C('frames') == 930, 'alive hero frames moved: ' .. C('frames'))
end

tests['census: STOPPER 1 -- camp occupancy is false on every single frame'] = function()
    -- The clause this repair removed from the trigger. Not "rarely true":
    -- never true, independent of every other clause, because the dumper
    -- carries no creeps. Any pre-repair isolation loop over this behaviour
    -- read zero for a reason that had nothing to do with the game.
    assert(C('camp_up') == 0,
        'GetNearbyNeutralCreeps(1400) is no longer empty everywhere ('
        .. C('camp_up') .. ') -- the corpus grew creeps; re-read this file')
end

tests['census: STOPPER 2 -- GetNeutralSpawners is empty on every frame'] = function()
    assert(C('spawners_nonempty') == 0,
        'the mock now answers GetNeutralSpawners (' .. C('spawners_nonempty')
        .. ' frames) -- section 2 no longer needs to declare a camp list')
end

tests['census: STOPPER 4 -- GetAssignedLane is 0, never nil, on every frame'] = function()
    -- Lane assignment is bot-VM state, so it is not in the .dem. The guard in
    -- the helper tests for nil, which never happens; the value that does reach
    -- GetLocationAlongLane is a constant 0 with no relation to the game the
    -- frame came from.
    assert(C('lane_zero') == C('frames'),
        'GetAssignedLane is no longer 0 on every frame')
    assert(C('lane_nil') == 0, 'GetAssignedLane now answers nil somewhere')
end

tests['census: IsLanePullSafe is NOT a dead condition (334/911)'] = function()
    -- The owner's standing suspicion, tested and rejected. A third of a
    -- combat-sampled corpus passes hp>=50% + untouched 2s + nobody inside
    -- 1800; on peacetime laning frames it can only be commoner.
    assert(C('pullsafe') == 339, 'IsLanePullSafe pass count moved: ' .. C('pullsafe'))
    assert(C('pullsafe') > C('frames') * 0.3,
        'IsLanePullSafe now passes on less than 30% of frames -- if it has '
        .. 'become rare, the SILENT verdict needs a second look')
end

tests['census: the scenario frequency the DoD asked for (36 / 10 / 15)'] = function()
    -- The peacetime lane-support state a pull starts from, and what each
    -- window admits out of it. This is the "scenario scarcity" half of the
    -- answer: a timing filter costs what a timing filter costs.
    assert(C('peacetime_lane_support') == 36,
        'peacetime lane-support frames moved: ' .. C('peacetime_lane_support'))
    assert(C('chain_old') == 10, 'old-window chain frames moved: ' .. C('chain_old'))
    assert(C('chain_new') == 15, 'new-window chain frames moved: ' .. C('chain_new'))
    assert(C('chain_new') > C('chain_old'),
        'the travel lead admits no frame the aggro-mark window rejected -- '
        .. 'the second half of the repair would be untestable on this corpus')
end

tests['census: the travel lead is what admits the witness frame'] = function()
    local m = manifest()
    assert(#m.NEWONLY == 5, '#NEWONLY moved: ' .. #m.NEWONLY)
    local seen = {}
    for _, r in ipairs(m.NEWONLY) do
        seen[r.hero] = r
        assert(r.sec >= 5 and r.sec < 10,
            'a NEWONLY frame is not in the lead band: ' .. r.sec)
    end
    assert(seen['npc_dota_hero_ogre_magi'], 'the witness frame is no longer NEWONLY')
end

tests['census: the old window`s 10 frames are none of them a lane'] = function()
    -- Non-empty witness for chain_old, and the honest note about it: 7 of those
    -- frames are chase instants at t~315 (the ss_chase pair) and 3 are a
    -- TP-home episode at t=349. The corpus contains ZERO in-lane pull-window
    -- frames -- which is why section 2 has to declare its lane geometry rather
    -- than read it.
    local m = manifest()
    assert(#m.CHAIN == 10, '#CHAIN moved: ' .. #m.CHAIN)
    local by_kind = { ss_chase = 0, lina_tp_home = 0 }
    for _, r in ipairs(m.CHAIN) do
        local kind = r.fixture:find('ss_chase', 1, true) and 'ss_chase'
            or (r.fixture:find('lina_tp_home', 1, true) and 'lina_tp_home' or nil)
        assert(kind, 'a chain frame comes from a fixture this census has not '
            .. 'classified as a non-lane episode: ' .. r.fixture
            .. ' -- read it before assuming the corpus now has a laning frame')
        by_kind[kind] = by_kind[kind] + 1
    end
    assert(by_kind.ss_chase == 7 and by_kind.lina_tp_home == 3,
        'the chain composition moved: ' .. by_kind.ss_chase .. ' / '
        .. by_kind.lina_tp_home)
end

-- ------------------------- 2. DECLARED-WORLD behaviour on ONE real frame ----
--
-- Everything the frame itself supplies is real: the subject (dire pos 5 Ogre
-- Magi at (-439, 4470), full HP, nobody inside 1800), the clock (t=307.4, so
-- :07.4 -- inside the travel lead, outside the aggro mark), the ancient
-- positions (the fixture carries buildings).
--
-- Three things are DECLARED, and they are declared because the corpus cannot
-- answer them (see stoppers 2/3/4 above), not because they were convenient:
--   * the lane front and the lane midpoint (GH #61 refuses the first; the
--     mock answers the second with the map origin) -- declared so that the
--     equilibrium clause reads "our wave is pushed out", the case a pull is
--     for;
--   * the camp list. Camp SPAWN POINTS are map constants, the same class of
--     thing as the ancient's position, so declaring them is not modelling
--     game state -- camp OCCUPANCY would be, and this test never declares it.
-- The teeth are therefore on the two clauses the repair touched. Stated
-- plainly so nobody later reads this as an end-to-end pull test.

local WITNESS = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local OGRE = 'npc_dota_hero_ogre_magi'

-- Declared map constants: one own-team camp inside the 1500 reach, one own-team
-- camp far away, one ENEMY camp right on top of the bot (the team filter must
-- reject it even though it is nearest).
local CAMP_XY = {
    near = { -1000, 3800 },  -- own team, 874u away: inside the 1500 reach
    far = { 4000, 1000 },    -- own team, ~5800u away: outside it
    enemy = { -500, 4400 },  -- RADIANT, ~90u away: nearest of the three
}

-- Declared camps are built INSIDE the loader (they need the loaded subject's
-- team), and named by the caller -- building them at the call site would hand
-- the helper a table of nils and make every control below pass for the wrong
-- reason. That happened once while writing this file.
local CAMPS = {}

local function load_witness(names)
    local J, bot, heroes, fx = rf.load(WITNESS, OGRE)

    -- GH #61: rf.load refuses GetLaneFrontLocation, so this test declares it,
    -- on one visible line, as the case the helper is written for: our front
    -- pushed past the midpoint toward the enemy.
    GetLaneFrontLocation = function() return Vector(-6000, 3000, 0) end -- luacheck: ignore
    GetLocationAlongLane = function() return Vector(0, 0, 0) end -- luacheck: ignore

    CAMPS = {
        near = { location = Vector(CAMP_XY.near[1], CAMP_XY.near[2], 0), team = bot:GetTeam() },
        far = { location = Vector(CAMP_XY.far[1], CAMP_XY.far[2], 0), team = bot:GetTeam() },
        enemy = { location = Vector(CAMP_XY.enemy[1], CAMP_XY.enemy[2], 0),
                  team = bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT },
    }
    local list = {}
    for _, n in ipairs(names) do
        list[#list + 1] = assert(CAMPS[n], 'no declared camp named ' .. n)
        assert(list[#list].location ~= nil, 'declared camp ' .. n .. ' has no location')
    end
    GetNeutralSpawners = function() return list end -- luacheck: ignore

    J.IsSoakCandidate = function(id) return id == 'pullcamp' end
    return J, bot, heroes, fx
end

local function dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

tests['frame A: the witness frame is real and is what the sweep said it is'] = function()
    local m = manifest()
    assert(m.WIT, 'the sweep no longer reports the witness frame')
    assert(m.WIT.team == 3 and m.WIT.pos == '5', 'the witness is no longer a dire pos 5')
    assert(m.WIT.hp == 1.00, 'the witness is no longer at full HP')
    assert(m.WIT.pullsafe, 'the witness no longer passes IsLanePullSafe')
    assert(m.WIT.camp_up == false,
        'the witness frame now sees neutral creeps -- the counterfactual below '
        .. 'is no longer the reason the pre-repair trigger returned nil')

    local _, bot, _, fx = load_witness({ 'near' })
    assert(math.abs(fx.time - 307.4) < 0.01, 'the witness frame time moved: ' .. fx.time)
    local sec = fx.time % 60
    assert(sec >= 5 and sec < 10, 'the witness is no longer inside the travel lead')
    assert(not (sec >= 10 and sec <= 20),
        'the witness is now inside the OLD aggro-mark window -- it no longer '
        .. 'witnesses the travel lead')
    assert(bot:IsAlive())
end

tests['frame A: REPAIRED -- the trigger authorises the approach'] = function()
    local J, bot = load_witness({ 'near', 'far', 'enemy' })
    local v = J.ShouldPullNeutralCamp(bot)
    assert(v ~= nil, 'the camp pull is still silent on a frame that qualifies')
    assert(dist2d(v, CAMPS.near.location) < 1,
        'the trigger picked something other than the reachable own-team camp')
end

tests['frame A: the counterfactual -- why the pre-repair trigger said nil'] = function()
    -- Not an argument: the same frame, the same declarations, and the read the
    -- removed clause performed. It is empty. Under the pre-repair trigger this
    -- frame returned nil no matter how good the pull was.
    local _, bot = load_witness({ 'near', 'far', 'enemy' })
    local tNeut = bot:GetNearbyNeutralCreeps(1400)
    assert(tNeut == nil or #tNeut == 0,
        'the removed clause would now pass here -- the counterfactual is stale')
end

tests['frame A: control -- unarmed pullcamp is still inert'] = function()
    local J, bot = load_witness({ 'near', 'far', 'enemy' })
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the repair leaked out of the pullcamp gate -- shipped turbo games '
        .. 'would start pulling')
end

tests['frame A: control -- an out-of-reach camp is still rejected'] = function()
    local J, bot = load_witness({ 'far' })
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the 1500 reach test stopped rejecting a camp 5800u away')
end

tests['frame A: control -- the enemy`s camp is rejected though it is nearest'] = function()
    local J, bot = load_witness({ 'enemy' })
    assert(dist2d(CAMPS.enemy.location, bot:GetLocation())
        < dist2d(CAMPS.near.location, bot:GetLocation()),
        'the enemy camp is no longer the nearer of the two -- this control has '
        .. 'stopped controlling for anything')
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the team filter stopped rejecting the enemy jungle -- the scoped '
        .. 'non-goal in the helper header just became shipped behaviour')
end

tests['frame A: control -- an even lane is still not worth a pull'] = function()
    local J, bot = load_witness({ 'near' })
    -- Front AT the midpoint: nothing to reset.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    assert(J.ShouldPullNeutralCamp(bot) == nil,
        'the equilibrium clause stopped requiring a pushed-out wave')
end

-- ------------------------------------------------- 3. source pins [reverse] --

local function source(path)
    local fh = assert(io.open(path, 'r'))
    local src = fh:read('*a')
    fh:close()
    return src
end

local function helper_body()
    local src = source('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.ShouldPullNeutralCamp', 1, true),
        'J.ShouldPullNeutralCamp moved')
    local stop = assert(src:find('\nend\n', at, true), 'the helper has no end')
    return src:sub(at, stop)
end

tests['[reverse] the vision precondition is gone from the trigger'] = function()
    -- CODE only: the helper's own comment block quotes the removed clause on
    -- purpose (that is how the next reader learns why it is not there), so a
    -- bare substring search over the body would pin the comment, not the call.
    local code_hits, comment_hits = 0, 0
    for line in helper_body():gmatch('[^\n]+') do
        if line:find('GetNearbyNeutralCreeps', 1, true) then
            if line:match('^%s*%-%-') then
                comment_hits = comment_hits + 1
            else
                code_hits = code_hits + 1
            end
        end
    end
    assert(code_hits == 0,
        'the trigger asks for visible neutrals again -- that is the dead '
        .. 'condition this file exists to document')
    assert(comment_hits > 0,
        'the helper no longer records WHICH clause was removed and why -- '
        .. 'without that the next reader re-adds it')
end

tests['[reverse] the occupancy question MOVED, it was not deleted'] = function()
    -- The repair is only defensible because roam's Think still refuses to poke
    -- an empty camp. If this ever goes, a puller walks to a cleared camp and
    -- stands there.
    local roam = source('bots/mode_roam_generic.lua')
    assert(roam:find('GetNearbyNeutralCreeps(1400)', 1, true),
        'roam Think no longer asks whether the camp is up on arrival')
    assert(roam:find('Action_MoveToLocation(bot.roamCampPull)', 1, true),
        'roam Think no longer has the approach branch -- the branch the '
        .. 'repaired trigger exists to make reachable')
end

tests['[reverse] the window carries a travel lead before each aggro mark'] = function()
    local a, b, c2, d = helper_body():match(
        'nSec >= (%d+) and nSec <= (%d+)%) or %(nSec >= (%d+) and nSec <= (%d+)')
    assert(a, 'the pull window is no longer two literal nSec ranges')
    assert(tonumber(a) == 5 and tonumber(b) == 20, 'the first window moved')
    assert(tonumber(c2) == 35 and tonumber(d) == 50, 'the second window moved')
    -- The marks themselves (:12 / :42) are unchanged -- the lead is in front
    -- of them, it does not move them.
    assert(tonumber(a) < 12 and tonumber(b) >= 12, 'the :12 mark left the window')
    assert(tonumber(c2) < 42 and tonumber(d) >= 42, 'the :42 mark left the window')
end

tests['[reverse] the repair is still behind the pullcamp gate and turbo'] = function()
    local body = helper_body()
    assert(body:find("J.IsSoakCandidate( 'pullcamp' )", 1, true),
        'the pullcamp gate is gone from the helper')
    assert(body:find('J.IsModeTurbo()', 1, true),
        'the turbo gate is gone from the helper')
    -- ...and the camp reach the travel lead is sized against.
    assert(body:find('1500', 1, true), 'the 1500 camp reach moved')
end

tests['[reverse] the helper header no longer claims the removed clause'] = function()
    -- The 0q lesson: a comment that describes behaviour the code no longer has
    -- is as expensive as a gate claim that outlived its gate.
    local src = source('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.ShouldPullNeutralCamp', 1, true))
    local header = src:sub(math.max(1, at - 4200), at)
    assert(not header:find('is actually up\n--     (neutral creeps present nearby)', 1, true),
        'the header still lists the removed occupancy precondition')
    assert(header:find('occupancy is asked', 1, true),
        'the header no longer says where the occupancy question went')
end

return tests
