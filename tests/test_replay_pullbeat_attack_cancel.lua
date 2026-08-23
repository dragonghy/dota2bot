-- [GH #143 20260823] The creep pull's aggro poke is cancelled 1/30 s after it
-- is ordered -- pinned by DRIVING the shipped roam Think on a real laning frame.
--
-- The replay desk sweep (54/54 non-warmup games, 7 read frame by frame) found
-- that `creeppull`'s trigger fires but the mechanic does not pay: 26.8% of armed
-- pull episodes have NO enemy creep ever turning around, 47.5% carry a single
-- right-click in the whole episode, and the wave-displacement axis shows zero
-- armed excess. Its recommended repair was an END condition ("stop dragging
-- ~2.5 s after the last attack").
--
-- THAT REPAIR TARGETS A MECHANISM THIS CODE DOES NOT HAVE. `bot.roamCreepPull`
-- is re-derived by GetDesire EVERY frame and J.ShouldCreepPullLane requires an
-- aggro target within 1000 AND enemy lane creeps within 900 on that same frame,
-- so the drag already self-terminates the moment the wave or the target leaves.
-- The desk's own number agrees: across 5,105 episodes the longest run of
-- consecutive pull frames is 2, on BOTH legs -- there is no long drag to cut
-- short. The long walks home it measured are not pull frames.
--
-- What IS wrong is one frame earlier. The cadence orders the attack and then,
-- on the very next Think, issues `Action_MoveToLocation(pull.retreat)` -- which
-- cancels an attack whose wind-up has not started. Creep aggro only redirects
-- once the attack actually BEGINS (the human 勾线 is attack-then-cancel AFTER
-- the wind-up), so the pre-fix cadence draws aggro only by luck. Driving the
-- shipped Think over 46 frames on the frame below prints the defect literally:
--
--     A M M M M M M M M M M M M M M M M M M M M M M M M M M M M M M M M M M M M A
--     ^ ordered                                                                 ^ next beat
--       ^ cancelled 33 ms later, and again every beat for the rest of the pull
--
-- The fix (soak candidate 'pullbeat') issues NO ORDER for one attack wind-up
-- after the poke, which leaves the attack order running. Armed, the same drive
-- prints `A` + 14 held frames + 22 drag frames + `A`.
--
-- Honest notes on what is real here and what is not:
--   * REAL from the replay dump: every hero's position, HP, mana, level, team,
--     items and abilities on frame 20260720_072738_slot1 @ t=160.4 -- a zoned
--     Zeus mid, with Lina the only visible enemy inside the aggro-draw ring at
--     621 u. Everything that decides WHETHER the pull fires is real.
--   * SYNTHESIZED, exactly as tests/test_replay_creeppull_reachable.lua already
--     does and for the same reason: the enemy lane creep wave. make_fixture.py
--     dumps HEROES ONLY -- measured this round, `GetNearbyLaneCreeps(900,true)`
--     is EMPTY on 966/966 corpus frames -- so no real frame can reach the pull
--     branch without one. It is placed at Lina's real position, which is what
--     makes the real 621 u geometry decide the <= 500 hero-to-creep adjacency.
--   * SUBSTITUTED (backlog 0FIX): GH #143 asks for two new fixtures from
--     `20260823_062509_slot7` / `20260823_062455_slot4`. Those replays are not
--     in this container and make_fixture.py cannot reach them, so the pin falls
--     back to the corpus's canonical zoned-lane frame. It carries the same
--     shape the issue describes (a core, zoned by exactly one laner, wave on
--     our side) and it is the frame GH #13's repair was validated on.
--   * The 1/30 s frame step is the engine's Think rate; DotaTime is advanced by
--     the test because a fixture is ONE instant -- the world (positions, HP,
--     ranges) never moves, only the clock does. That is the whole quantity the
--     fix reads: `now - bot.creepPullAttackTime` is OUR OWN bookkeeping, set
--     from DotaTime() by the branch above it, never an engine getter. It goes
--     BOTH ways inside a single beat below (14 frames true, 22 false), so this
--     is not backlog 0DIR's constant-answer trap.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local ZONED_MID = 'tests/fixtures/f_072738_zuus_mana.lua'
local STEP = 1 / 30 -- engine Think rate

local function read_file(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a')
    fh:close()
    return s
end

--- The creep-pull branch of roam's Think, ISOLATED before any constant is read
--- out of it (backlog 0SRC: `1.2` and `0.5` both occur elsewhere in this file,
--- so a whole-file match would silently report some other branch's numbers).
local function pull_branch()
    local src = read_file('bots/mode_roam_generic.lua')
    local at = assert(src:find('if bot.roamCreepPull ~= nil then', 1, true),
        'roam Think no longer has the creep-pull branch')
    local to = assert(src:find('if bot.roamCampPull ~= nil then', at, true),
        'the camp-pull branch that ends the creep-pull branch moved')
    return src:sub(at, to)
end

--- The two constants that shape the cadence, read from that branch.
--- [20260823] The beat moved from a literal in the `if` line to `local nBeat`
--- when soak candidate 'pullcad' gave it a second value; this reads the SHIPPED
--- one, which is what every assertion in this file is about (`pullcad` is never
--- armed here). Both spellings are accepted so the reader survives either shape.
local function cadence()
    local body = pull_branch()
    local beat = body:match('bot%.creepPullAttackTime%) > ([%d%.]+) then')
        or assert(body:match('local nBeat = ([%d%.]+)'),
            'the shipped attack beat is no longer a literal in the creep-pull branch')
    local hold = assert(body:match('bot%.creepPullAttackTime%) < ([%d%.]+) then'),
        'the pullbeat hold is no longer a literal in the creep-pull branch')
    return tonumber(beat), tonumber(hold)
end

--- Install the fixture world, make the pull branch reachable, and return a
--- driver that runs N engine frames and answers the order log as a string:
---   'A' Action_AttackUnit   'M' Action_MoveToLocation   '.' no order at all
local function drive(sArmed)
    local J, bot, heroes = rf.load(ZONED_MID)
    local lina = heroes['npc_dota_hero_lina']
    local sp = rawget(bot, '__spec')

    -- Engine plumbing the hero dump does not carry (see header).
    local creep = api.MakeUnit({
        CanBeSeen = true, IsAlive = true, GetLocation = lina:GetLocation(),
    })
    sp.GetNearbyLaneCreeps = function(_, _radius, bEnemy)
        if bEnemy then return { creep } end
        return {}
    end
    rawset(bot, 'GetNearbyLaneCreeps', nil)
    -- An EVEN lane front, so the pull is justified by the real zoning and never
    -- by a stacked-wave signal.
    GetLaneFrontAmount = function() return 0.5 end -- luacheck: ignore

    local log = {}
    sp.Action_AttackUnit = function() log[#log + 1] = 'A' end
    sp.Action_MoveToLocation = function() log[#log + 1] = 'M' end
    rawset(bot, 'Action_AttackUnit', nil)
    rawset(bot, 'Action_MoveToLocation', nil)

    -- 'creeppull' opens the branch at all; 'pullbeat' is the candidate under test.
    J.IsSoakCandidate = function(id)
        if id == 'creeppull' then return true end
        return sArmed == true and id == 'pullbeat'
    end

    dofile('bots/mode_roam_generic.lua')

    local t0 = DotaTime()
    return J, bot, function(nFrames)
        for i = 0, nFrames - 1 do
            local now = t0 + i * STEP
            DotaTime = function() return now end -- luacheck: ignore
            local n = #log
            GetDesire()
            Think()
            if #log == n then log[#log + 1] = '.' end
        end
        return table.concat(log)
    end
end

tests['[GH #143] the pull bid is still reachable on the real frame'] = function()
    -- The trigger is untouched by this fix; if this goes red the rest of the
    -- file is measuring an empty world rather than the cadence.
    local J, bot, run = drive(false)
    assert(J.ShouldCreepPullLane(bot) ~= nil,
        'the real zoned-lane frame no longer produces a pull plan -- the '
        .. 'trigger changed, not the cadence')
    assert(J.IsCreepPullSafe(bot) == true, 'the frame is no longer pull-safe')
    assert(GetDesire() == 0.9, 'roam no longer bids the pull window')
    assert(bot.roamCreepPull ~= nil, 'GetDesire no longer sets the pull plan')
    run(1)
end

tests['[GH #143 DEFECT] unarmed, the poke is cancelled on the very next frame'] = function()
    local _, _, run = drive(false)
    local log = run(2)
    assert(log == 'AM', 'expected the poke then an immediate cancelling move '
        .. 'order, got ' .. log)
end

tests['[GH #143 DEFECT] unarmed, every frame of the beat cancels'] = function()
    local beat = cadence()
    local _, _, run = drive(false)
    -- One full beat plus one frame: the next poke must be the last entry.
    local nFrames = math.floor(beat / STEP) + 2
    local log = run(nFrames)
    assert(log:sub(1, 1) == 'A', 'the beat no longer opens with the poke')
    assert(log:sub(-1) == 'A', 'the next beat no longer lands after ' .. beat
        .. 's, got ' .. log)
    assert(not log:find('%.'),
        'the shipped default must issue an order on EVERY frame -- a held '
        .. 'frame means the gate leaked into default behaviour: ' .. log)
    local nMoves = select(2, log:gsub('M', ''))
    assert(nMoves == nFrames - 2,
        'expected every non-poke frame of the beat to issue a move order, got '
        .. nMoves .. ' of ' .. (nFrames - 2))
end

tests['[GH #143 FIX] armed, the wind-up is held and then the drag resumes'] = function()
    local beat, hold = cadence()
    local _, _, run = drive(true)
    local nFrames = math.floor(beat / STEP) + 2
    local log = run(nFrames)

    assert(log:sub(1, 1) == 'A', 'the beat no longer opens with the poke')
    -- The held frames are contiguous and come FIRST -- a hold anywhere else
    -- would be a stall in the middle of the drag, not a protected wind-up.
    local held = log:match('^A(%.*)M')
    assert(held ~= nil,
        'armed, the poke is not followed by held frames and then the drag: '
        .. log)
    -- The held span must BE the configured wind-up, to within one engine frame.
    -- (Not an exact frame count: `now - creepPullAttackTime` is a float
    -- difference of two absolute DotaTime values, so which side of the boundary
    -- the last frame lands on is decided by rounding at t = 160.4, not by the
    -- constant. Asserting the exact count would pin that rounding.)
    local nIdeal = hold / STEP
    assert(math.abs(#held - nIdeal) <= 1,
        'expected about ' .. nIdeal .. ' held frames for a ' .. hold
        .. 's wind-up at ' .. STEP .. 's per frame, got ' .. #held)

    -- ...and the drag still owns the rest of the beat, and the next poke lands
    -- on time. A hold that swallowed the beat would trade one defect for a bot
    -- that pokes and then stands still.
    local nMoves = select(2, log:gsub('M', ''))
    assert(nMoves > #held,
        'the hold now owns more of the beat than the drag does (' .. #held
        .. ' held vs ' .. nMoves .. ' dragging) -- the wave is no longer '
        .. 'being pulled anywhere')
    assert(log:sub(-1) == 'A', 'the next beat no longer lands on time: ' .. log)
end

tests['[GH #143 FIX] the hold is strictly shorter than the beat'] = function()
    local beat, hold = cadence()
    assert(hold > 0, 'the wind-up hold is not positive')
    assert(hold < beat, 'the hold (' .. hold .. 's) is not shorter than the '
        .. 'attack beat (' .. beat .. 's) -- the bot would never drag')
    -- The wind-up it protects: hero attack points run ~0.3-0.65s. A hold under
    -- a third of that would not survive a single hero's animation.
    assert(hold >= 0.3, 'a ' .. hold .. 's hold is shorter than every hero '
        .. 'attack point -- it protects nothing')
end

tests['[GH #143 GATE] with pullbeat unarmed the cadence is byte-identical'] = function()
    local beat = cadence()
    local nFrames = math.floor(beat / STEP) + 2
    local _, _, runOff = drive(false)
    local off = runOff(nFrames)
    local _, _, runOn = drive(true)
    local on = runOn(nFrames)
    assert(off ~= on, 'the candidate changes nothing when armed -- it is a no-op')
    assert(not off:find('%.'), 'the unarmed leg held a frame: ' .. off)
    -- ...and the gate is the ONLY thing separating them: same poke, same beat.
    assert(off:sub(1, 1) == on:sub(1, 1) and off:sub(-1) == on:sub(-1),
        'arming moved the poke itself, not just the frames after it')
end

tests['[GH #143] the branch is behind the pullbeat gate'] = function()
    local body = pull_branch()
    assert(body:find("J.IsSoakCandidate('pullbeat')", 1, true),
        'the pullbeat gate is gone from the creep-pull branch')
    -- Turbo is structural, not stated -- the header says so, and the reason
    -- must stay readable or the next reader adds a redundant check.
    assert(body:find('IsModeTurbo', 1, true),
        'the branch no longer records WHY it does not re-check turbo')
end

tests['[world assertion 21] GetAttackRange is the mock default on every hero'] = function()
    -- Why the fix spends this frame on our own bookkeeping instead of the
    -- obvious alternative ("only hold when the target is in attack range"):
    -- the corpus cannot answer that question. tests/mock/bot_api.lua defaults
    -- GetAttackRange to 150 and no fixture carries the field, so a ranged Zeus
    -- (380), Lina (550) and Luna (330) all read melee range. Measured this
    -- round over the whole corpus: 150 on 966/966 frames. Pinned here on the
    -- ten real heroes of this frame so the day the dumper starts recording it,
    -- this test says so.
    local fx = dofile(ZONED_MID)
    local nRanged = 0
    for _, u in ipairs(fx.units) do
        if u.alive then
            local _, bot = rf.load(ZONED_MID, u.name)
            assert(bot:GetAttackRange() == 150,
                u.name .. ' now carries a real attack range -- world assertion '
                .. '21 is stale, and the in-range clause this fix avoided may '
                .. 'now be writable')
            if u.name:find('zuus') or u.name:find('lina')
            or u.name:find('luna') or u.name:find('lich') then
                nRanged = nRanged + 1
            end
        end
    end
    assert(nRanged >= 3,
        'this frame no longer carries the ranged heroes that make the '
        .. 'fabricated 150 visible')
end

return tests
