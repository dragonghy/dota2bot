-- [OWNER_PRIORITIES P1 20260904] Soak candidate 'campbind': THE CAMP PULL POKES
-- WHATEVER IS NEAREST, NOT THE CAMP IT PLANNED.
--
-- J.ShouldPullNeutralCamp spends four clauses choosing WHICH camp to pull -- our
-- team's camp (the "never walk a support into the enemy jungle" scoped
-- non-goal), on our own half (GH #117: a deep camp is not a worse pull, it is a
-- non-pull), beside this bot's own lane ('pulllane'), within 1500 -- and hands
-- the winner back as bot.roamCampPull. mode_roam_generic's Think then walked to
-- that plan and, on arrival, poked
--
--     local tNeut = bot:GetNearbyNeutralCreeps( 1400 )
--     bot:Action_AttackUnit( tNeut[1], true )
--
-- tNeut[1] is the neutral nearest THE BOT. Nothing ties it to the plan. So a
-- camp any of those four clauses rejected is poked anyway the moment its creeps
-- are the nearest ones, and the pull that actually happens is at a camp no
-- clause ever approved -- while J.GetLanePullDragTarget, which IS asked about
-- bot.roamCampPull, aims the drag at the planned camp's lane point. The
-- selector governs where the bot walks, and nothing else.
--
-- ==== WHAT IS REAL ON THIS FRAME, AND WHAT IS DECLARED =====================
--
--   REAL  the subject: lich, DIRE, pos 5 by the fixture's own roles table,
--         standing at (-1660.6, 4279.4) on 20260820_042009_slot1. Its distances
--         to the two dire camps below -- 1055u and 1122u -- are real map
--         arithmetic, and BOTH are inside the 1400 poke radius, with the camp
--         the selector rejects being the NEARER of the two. That is the whole
--         defect in one hero position, and it was not constructed: it came out
--         of a sweep of every alive hero in the corpus against the harvested
--         camp table (the census leg below).
--   REAL  the two camp centroids, (-2600,3800) and (-800,5000). These are the
--         replay desk's own measurements off the .dem corpus (the CAMPS table
--         in tools/agent/pullcamp_lane_geometry.py, GH #117 W7/W8), not map
--         constants invented here.
--   REAL  the dire ancient at (5528,5000), read off the fixture's buildings, so
--         "the nearer camp is the DEEPER one" is asserted against the same
--         geometry J.ShouldPullNeutralCamp's own-half clause uses.
--   DECLARED  bot.roamCampPull. Our own bookkeeping, not an engine getter --
--         GetDesire writes it, Think reads it -- so setting it declares "a pull
--         plan is live", which is this file's precondition. Same licence
--         tests/test_pullthink_anim_throttle.lua and
--         tests/test_pulldrag_lane_step.lua take, for the same reason.
--   DECLARED  the camps' neutral creeps. No fixture carries a creeps key with
--         unit identity and GetNearbyNeutralCreeps answers {} on every corpus
--         frame (world assertion, tests/test_pullcamp_trigger_census.lua
--         STOPPER 1). Stand-in units are placed AT the two real camp centroids.
--
-- HONEST LIMIT, stated so nobody reads this file as more than it is: it cannot
-- show that binding the poke RAISES the connect rate. That is a wave question.
-- What is settled locally is the thing that question rests on -- which unit the
-- order is issued against.
--
-- SECOND LIMIT: the domain census below runs over the ELEVEN camps the harvested
-- corpus has centroids for, not the whole map. Its 17/449 is therefore a FLOOR
-- in both directions of the argument: every camp the table does not list can
-- only add frames on which two camps are in poke range at once.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local tests = {}

local FRAME = 'tests/fixtures/f_260820_042009_cm_cask_far.lua'
local SUBJECT = 'npc_dota_hero_lich'

-- Both are DIRE camps and lich is dire, so the team clause cannot be what
-- separates them: the only clause that does is the own-half one.
local DEEP = { x = -2600, y = 3800 }     -- 1055u from lich -- the NEARER camp
local SHALLOW = { x = -800, y = 5000 }   -- 1122u from lich -- the plan

local STEP = 1 / 30                      -- engine Think rate
local BEAT = 3.0                         -- the camp cadence's poke interval
local RANGE = 1200                       -- PULL_CAMP_NEUTRAL_RANGE, jmz_func

-- The camps the replay desk harvested off the .dem corpus, verbatim from
-- tools/agent/pullcamp_lane_geometry.py's CAMPS table. Used by the census leg.
local HARVESTED_CAMPS = {
    { 4000, -5000 }, { 200, -5200 }, { -4000, 1000 }, { -1400, -3400 },
    { -5000, -200 }, { -4000, 4800 }, { -800, 5000 }, { -2600, 3800 },
    { 1000, 2600 }, { 3400, -1400 }, { 1200, 4200 },
}

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

--- Install the real frame, declare the pull plan and the neutral stand-ins, and
--- return a driver that runs N engine frames and answers the order log:
---   'A' Action_AttackUnit   'M' Action_MoveToLocation   '.' no order at all
--- plus the unit each attack order was issued against.
---
--- tCampXY lists the camps whose creeps are visible, NEAREST FIRST -- that order
--- is what bot:GetNearbyNeutralCreeps promises and what tNeut[1] means.
local function drive(tCampXY, bArmed, vPlan)
    local J, bot = rf.load(FRAME, SUBJECT)
    local sp = rawget(bot, '__spec')

    local units, byUnit = {}, {}
    for _, c in ipairs(tCampXY) do
        local u = api.MakeUnit({
            CanBeSeen = true, IsAlive = true,
            GetLocation = api.Vector(c.x, c.y, 0),
        })
        units[#units + 1] = u
        byUnit[u] = c
    end
    sp.GetNearbyNeutralCreeps = function() return units end
    rawset(bot, 'GetNearbyNeutralCreeps', nil)

    local log, tPoked = {}, {}
    sp.Action_AttackUnit = function(_, hTarget)
        log[#log + 1] = 'A'
        tPoked[#tPoked + 1] = byUnit[hTarget]
    end
    sp.Action_MoveToLocation = function() log[#log + 1] = 'M' end
    rawset(bot, 'Action_AttackUnit', nil)
    rawset(bot, 'Action_MoveToLocation', nil)

    J.IsSoakCandidate = function(sId) return bArmed and sId == 'campbind' end

    dofile('bots/mode_roam_generic.lua')

    -- Declared AFTER the mode file loads: the file-scope `local bot = GetBot()`
    -- there is this same handle, and GetDesire is not driven here (whether a
    -- pull would be CHOSEN on this frame is a different file's question).
    bot.roamCampPull = api.Vector((vPlan or SHALLOW).x, (vPlan or SHALLOW).y, 0)

    local t0 = DotaTime()
    return J, bot, function(nFrames)
        for i = 0, nFrames - 1 do
            local now = t0 + i * STEP
            DotaTime = function() return now end -- luacheck: ignore
            local n = #log
            Think()
            if #log == n then log[#log + 1] = '.' end
        end
        return table.concat(log), tPoked
    end
end

-- --------------------------------------------- 1. the frame is what it says --

tests['[real frame] a dire pos 5 stands inside TWO camps` poke radius'] = function()
    local _, bot = rf.load(FRAME, SUBJECT)
    local v = bot:GetLocation()
    assert(bot:GetTeam() == 3, 'the subject is no longer dire -- both camps below '
        .. 'are dire camps and the team clause would now be doing the separating')
    assert(bot:IsAlive(), 'the subject is no longer alive on this frame')

    local dDeep = dist(v.x, v.y, DEEP.x, DEEP.y)
    local dShallow = dist(v.x, v.y, SHALLOW.x, SHALLOW.y)
    assert(dDeep < 1400 and dShallow < 1400,
        'the subject no longer stands inside both camps` 1400 poke radius ('
        .. math.floor(dDeep) .. 'u / ' .. math.floor(dShallow) .. 'u) -- the '
        .. 'frame stopped witnessing the defect')
    assert(dDeep < dShallow,
        'the rejected camp is no longer the NEARER one (' .. math.floor(dDeep)
        .. 'u vs ' .. math.floor(dShallow) .. 'u), so tNeut[1] would pick the '
        .. 'plan anyway and this frame proves nothing')
end

tests['[real frame] the nearer camp is the one the own-half clause rejects'] = function()
    -- Asserted against the fixture's OWN ancient, i.e. the same geometry
    -- J.ShouldPullNeutralCamp measures its own-half clause with. Without this
    -- the file would only be showing "the poke picked a different camp", not
    -- "the poke picked the camp the selector exists to refuse".
    local _, bot, _, fx = rf.load(FRAME, SUBJECT)
    local vOwn = nil
    for _, b in ipairs(fx.buildings or {}) do
        if b.name == 'ancient' and b.team == bot:GetTeam() then vOwn = b end
    end
    assert(vOwn ~= nil, 'the fixture no longer carries our own ancient')
    local dDeep = dist(DEEP.x, DEEP.y, vOwn.x, vOwn.y)
    local dShallow = dist(SHALLOW.x, SHALLOW.y, vOwn.x, vOwn.y)
    assert(dDeep > dShallow,
        'the camp the poke reaches for is no longer the deeper of the two ('
        .. math.floor(dDeep) .. 'u vs ' .. math.floor(dShallow)
        .. 'u from our ancient) -- re-read this file')
end

-- ------------------------------------------------ 2. the defect and the fix --

tests['[DEFECT] shipped, the poke lands on the camp that is NOT the plan'] = function()
    local _, _, run = drive({ DEEP, SHALLOW }, false)
    local log, poked = run(1)
    assert(log == 'A', 'the shipped cadence no longer opens with a poke: ' .. log)
    assert(poked[1] == DEEP,
        'the shipped poke no longer lands on the nearest camp -- either '
        .. 'tNeut[1] stopped being the poke target or this file is stale')
end

tests['[FIX] armed, the un-planned camp is not poked and the walk stands'] = function()
    local _, _, run = drive({ DEEP, SHALLOW }, true, SHALLOW)
    -- SHALLOW is 1533u from DEEP, i.e. outside PULL_CAMP_NEUTRAL_RANGE, so the
    -- deep camp's creep is not the plan's; but the shallow camp's creep IS
    -- visible here, so the fix must still poke -- and poke the RIGHT one.
    local log, poked = run(1)
    assert(log == 'A', 'armed, the cadence stopped poking entirely: ' .. log)
    assert(poked[1] == SHALLOW,
        'armed, the poke still lands on the camp the selector rejected')
end

tests['[FIX] armed with ONLY the un-planned camp visible: no order at all'] = function()
    -- The frame the walk depends on. Armed, with nothing from the planned camp
    -- in sight, the cadence must issue NOTHING -- which leaves the previous
    -- frame's Action_MoveToLocation(bot.roamCampPull) running, i.e. the bot keeps
    -- walking to its camp. An order of any kind here would either poke the wrong
    -- camp (the defect) or cancel the approach.
    local _, _, run = drive({ DEEP }, true, SHALLOW)
    local log, poked = run(1)
    assert(log == '.', 'armed, a frame with no planned-camp creep still issued '
        .. 'an order: ' .. log)
    assert(#poked == 0, 'armed, the un-planned camp was poked anyway')
end

tests['[FIX] the held frames really are held -- a whole beat issues nothing'] = function()
    -- One frame is not enough to see the second half of the hold: if the branch
    -- stamped bot.campPullAttackTime while poking nothing, every later frame of
    -- the beat would fall through to the drag step and walk the bot lane-ward
    -- away from a camp it has not reached. Over a full beat the log must stay
    -- empty, which is what "keep approaching" looks like in orders.
    local _, _, run = drive({ DEEP }, true, SHALLOW)
    local n = math.floor(BEAT / STEP) + 2
    local log = run(n)
    assert(log == string.rep('.', n),
        'armed, a beat with no planned-camp creep issued orders: ' .. log)
end

tests['[gate] non-turbo is the shipped poke, armed or not'] = function()
    -- The turbo half of the gate. It is structural at the call site (the plan
    -- only exists downstream of J.ShouldPullNeutralCamp, which opens with
    -- J.IsModeTurbo) -- but the helper is a public J.* function and the gate is
    -- written into it, so it has to be the gate it claims to be.
    local J = rf.load(FRAME, SUBJECT)
    J.IsSoakCandidate = function(sId) return sId == 'campbind' end
    J.IsModeTurbo = function() return false end
    local h = api.MakeUnit({ CanBeSeen = true, IsAlive = true,
        GetLocation = api.Vector(DEEP.x, DEEP.y, 0) })
    assert(J.GetCampPullPokeTarget({ h }, api.Vector(SHALLOW.x, SHALLOW.y, 0)) == h,
        'the helper binds the poke outside Turbo -- normal-mode behaviour is no '
        .. 'longer byte-for-byte the shipped one')
end

tests['[FIX] the lever cannot mute a pull at the planned camp'] = function()
    -- The anti-vacuum leg: if 'campbind' merely stopped pulls, every assertion
    -- above would pass for the wrong reason. With the plan's own creeps in
    -- sight, armed pokes exactly as shipped.
    local _, _, run = drive({ SHALLOW }, true, SHALLOW)
    local log, poked = run(1)
    assert(log == 'A' and poked[1] == SHALLOW,
        'armed, the planned camp itself is not poked: ' .. log)
end

tests['[unarmed identity] one camp, one beat: armed and shipped agree'] = function()
    -- Driven to completion one leg at a time: `Think` is a global that dofile
    -- rebinds, so two live drivers would both run the second file's Think.
    local n = math.floor(BEAT / STEP) + 2
    local base = select(3, drive({ SHALLOW }, false, SHALLOW))(n)
    local armed = select(3, drive({ SHALLOW }, true, SHALLOW))(n)
    assert(base == 'A' .. string.rep('M', n - 2) .. 'A',
        'the shipped camp cadence moved: ' .. base)
    assert(armed == base,
        'armed differs from shipped on a frame where the only visible camp IS '
        .. 'the plan -- the lever reaches past the poke target: ' .. armed
        .. ' vs ' .. base)
end

tests['[unarmed identity] two camps, unarmed: the shipped log, unchanged'] = function()
    local n = math.floor(BEAT / STEP) + 2
    local log = select(3, drive({ DEEP, SHALLOW }, false))(n)
    assert(log == 'A' .. string.rep('M', n - 2) .. 'A',
        'the unarmed cadence changed shape with two camps in range: ' .. log)
end

-- ------------------------------------------------------- 3. the helper edge --

tests['[boundary] the leash is the constant, and it is inclusive'] = function()
    local J, bot = rf.load(FRAME, SUBJECT)
    J.IsSoakCandidate = function(sId) return sId == 'campbind' end
    local vPlan = api.Vector(SHALLOW.x, SHALLOW.y, 0)
    local function at(d)
        return api.MakeUnit({ CanBeSeen = true, IsAlive = true,
            GetLocation = api.Vector(SHALLOW.x + d, SHALLOW.y, 0) })
    end
    local hIn, hOut = at(RANGE), at(RANGE + 1)
    assert(J.GetCampPullPokeTarget({ hIn }, vPlan) == hIn,
        'a neutral exactly ' .. RANGE .. 'u from the plan is refused -- the '
        .. 'longest drag the desk ever measured (1,170u) no longer fits')
    assert(J.GetCampPullPokeTarget({ hOut }, vPlan) == nil,
        'a neutral ' .. (RANGE + 1) .. 'u from the plan is accepted -- the '
        .. 'binding has no edge')
    assert(bot ~= nil)
end

tests['[scope] no plan, no change: the helper answers tNeut[1]'] = function()
    -- Think only reaches this helper inside `if bot.roamCampPull ~= nil`, so a
    -- nil plan cannot happen there today. Pinned anyway, because the failure
    -- direction matters: a nil plan must fall back to the shipped poke, never to
    -- "poke nothing", or a future caller silently loses the mechanic.
    local J = rf.load(FRAME, SUBJECT)
    J.IsSoakCandidate = function(sId) return sId == 'campbind' end
    local h = api.MakeUnit({ CanBeSeen = true, IsAlive = true,
        GetLocation = api.Vector(DEEP.x, DEEP.y, 0) })
    assert(J.GetCampPullPokeTarget({ h }, nil) == h,
        'a nil plan now mutes the poke instead of falling back to tNeut[1]')
    assert(J.GetCampPullPokeTarget({}, nil) == nil,
        'an empty neutral list no longer answers nil')
    assert(J.GetCampPullPokeTarget(nil, nil) == nil,
        'a nil neutral list no longer answers nil')
end

tests['[scope] invalid nearest unit: unarmed answer matches bCampHere'] = function()
    -- bCampHere at the call site is `#tNeut > 0 and J.IsValid(tNeut[1])`, so the
    -- unarmed helper has to apply the SAME test to the SAME element -- otherwise
    -- the branch could be entered with a nil poke target and the cadence would
    -- silently stall on a frame the shipped code pokes on.
    local J = rf.load(FRAME, SUBJECT)
    J.IsSoakCandidate = function() return false end
    local dead = api.MakeUnit({ CanBeSeen = true, IsAlive = false,
        GetLocation = api.Vector(DEEP.x, DEEP.y, 0) })
    local live = api.MakeUnit({ CanBeSeen = true, IsAlive = true,
        GetLocation = api.Vector(SHALLOW.x, SHALLOW.y, 0) })
    assert(J.GetCampPullPokeTarget({ dead, live }, nil) == nil,
        'unarmed, the helper looked past an invalid tNeut[1] -- it no longer '
        .. 'agrees with bCampHere and the two can now disagree about the frame')

    -- Armed, the scan MUST skip invalid units rather than hand one back: a dead
    -- or unseen neutral inside the plan's leash would otherwise become the
    -- attack order's target.
    J.IsSoakCandidate = function(sId) return sId == 'campbind' end
    local vPlan = api.Vector(SHALLOW.x, SHALLOW.y, 0)
    local deadAtPlan = api.MakeUnit({ CanBeSeen = true, IsAlive = false,
        GetLocation = api.Vector(SHALLOW.x, SHALLOW.y, 0) })
    assert(J.GetCampPullPokeTarget({ deadAtPlan, live }, vPlan) == live,
        'armed, the scan returned an invalid unit standing at the planned camp')
    assert(J.GetCampPullPokeTarget({ deadAtPlan }, vPlan) == nil,
        'armed, an invalid unit at the planned camp is still a poke target')
end

-- --------------------------------------------------------- 4. domain census --

tests['[census] how many real frames have two camps in poke range'] = function()
    -- The domain, measured rather than argued. A FLOOR twice over: the camp
    -- table holds only the camps the harvested corpus saw poked, and the count
    -- ratchets with the fixture corpus.
    local p = assert(io.popen('ls tests/fixtures'))
    local nFixtures, nAlive, nTwo = 0, 0, 0
    for line in p:lines() do
        if line:match('^f_.*%.lua$') then
            local ok, fx = pcall(dofile, 'tests/fixtures/' .. line)
            if ok and type(fx) == 'table' and fx.units then
                nFixtures = nFixtures + 1
                for _, u in ipairs(fx.units) do
                    if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                        nAlive = nAlive + 1
                        local n = 0
                        for _, c in ipairs(HARVESTED_CAMPS) do
                            if dist(u.x, u.y, c[1], c[2]) <= 1400 then n = n + 1 end
                        end
                        if n >= 2 then nTwo = nTwo + 1 end
                    end
                end
            end
        end
    end
    p:close()
    cs.corpus(nFixtures, 'campbind corpus')
    cs.ratchet(nAlive, 449, 'alive hero frames')
    cs.ratchet(nTwo, 17, 'frames with two harvested camps inside 1400')
    assert(nTwo > 0,
        'no corpus frame stands inside two harvested camps at once any more -- '
        .. 'the domain this lever addresses is empty on real frames, which is '
        .. 'the news, not noise')
end

-- ---------------------------------------------------------------- 5. source --

tests['[source] the gate is standalone and lives at one call site'] = function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local code = src:gsub('%-%-[^\n]*', '') -- prose is not code
    assert(code:find('GetCampPullPokeTarget', 1, true),
        'the comment stripper ate the code as well as the prose')
    local n = select(2, code:gsub("IsSoakCandidate%(%s*'campbind'%s*%)", ''))
    assert(n == 1, "expected exactly one 'campbind' gate in jmz_func code, found " .. n)
    assert(not code:find("IsSoakCandidate%(%s*'campbind'%s*%)%s*and%s*J%.IsSoakCandidate"),
        "the 'campbind' gate was conjoined with another candidate id -- that is "
        .. 'frozen FALSE the day the other id is promoted (the pullcad trap)')

    -- The constant is read from source, not from this file's copy of it: a
    -- silent edit there would otherwise leave the boundary leg above testing
    -- 1200 while the bots run something else.
    local v = code:match('PULL_CAMP_NEUTRAL_RANGE%s*=%s*(%d+)')
    assert(tonumber(v) == RANGE,
        'PULL_CAMP_NEUTRAL_RANGE is ' .. tostring(v) .. ', not the ' .. RANGE
        .. 'u this file measured the boundary at')

    local fh2 = assert(io.open('bots/mode_roam_generic.lua', 'r'))
    local roam = fh2:read('*a'); fh2:close()
    local rcode = roam:gsub('%-%-[^\n]*', '')
    assert(rcode:find('J.GetCampPullPokeTarget(tNeut, bot.roamCampPull)', 1, true),
        'the camp cadence no longer asks the helper about the PLANNED camp')
    assert(not rcode:find('Action_AttackUnit(tNeut[1]', 1, true),
        'the unbound poke is back at the call site')
end

return tests
