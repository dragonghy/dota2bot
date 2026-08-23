-- [owner P1 condition (c) 20260823] The creep pull re-pokes every 1.2s, and the
-- engine mechanic it is imitating cannot answer more often than every ~3s.
-- Pinned by DRIVING the shipped roam Think on a real laning frame.
--
-- WHY THIS IS A (c) FINDING AND NOT A TUNING PREFERENCE. Owner's validation
-- philosophy asks a shipped behaviour for a mechanism, searchable against
-- standard play. The published creep-aggro numbers are:
--   * a drawn aggro is kept for 2.3s, then the creeps revert;
--   * drawing it again is on a cooldown, read as 2s by some sources and 3s by
--     others (Liquipedia Lane Creeps; Hotspawn "How does creep aggro work";
--     player.one / sportskeeda repeat the same pair);
--   * the draw needs the attacked enemy hero within 500 of the creep -- which
--     is the one constant J.ShouldCreepPullLane already gets exactly right.
-- And the replay desk measured the SAME 2.3s from the other side without
-- knowing it: GH #143's headline is "one right-click buys a median 2.2s of
-- creep chase", reported there as the defect. It is not the defect. It is the
-- mechanic behaving exactly as documented, and it means the 1.2s cadence spends
-- beats 2 and 3 of every draw on an aggro that is either still live or still on
-- cooldown -- structurally unable to draw anything.
--
-- An ineffective re-poke is not a free no-op. Action_AttackUnit on a hero we
-- are not in range of walks us TOWARD that hero, so the re-poke drags an
-- already-aggroed wave the WRONG WAY, back up the lane. That is the mechanism
-- behind the desk's other two numbers (26.8% of armed episodes with no creep
-- ever turning around; zero armed excess on the wave-displacement axis).
--
-- THE LEVER (soak candidate 'pullcad'): beat 1.2s -> 3.0s, which clears the
-- 2.3s aggro and the 3s upper reading of the cooldown at once. The drag then
-- owns 2.5s of every 3.0s (83%) instead of 0.7s of every 1.2s (58%), and the
-- drag window matches the 2.3s the creeps will actually follow for. 3.0s is
-- also the beat the sister camp pull in the same file has used since wave13 --
-- asserted below, so the two cadences cannot silently drift apart.
--
-- THE WIND-UP HOLD IS A STRUCTURAL PRECONDITION of this lever. Without it the
-- poke is cancelled 33ms after it is ordered, so aggro is drawn only by luck --
-- and a longer beat then buys FEWER lucky draws, i.e. strictly worse than
-- shipped.
-- [PROMOTE 20260823] When this file was written the hold was soak candidate
-- 'pullbeat' and the gate here was the conjunction `pullcad and pullbeat`, so
-- that the precondition was code rather than prose and 'pullcad' armed alone
-- was a byte-for-byte no-op. 'creeppull' and 'pullbeat' have since been
-- promoted to turbo defaults (director ruling, owner rule 2 on the pair), and
-- the conjunct had to go WITH that promote: a promoted id is in no armed
-- string, so `pullcad and pullbeat` would have been frozen false forever --
-- 'pullcad' inert in every wave it could be armed in, check_armed_wiring.py
-- still calling it WIRED because the call site exists, and the verdict reading
-- back "tested, no effect". The precondition is now satisfied BY CONSTRUCTION,
-- which is strictly stronger than a gate. ARM-CHAIN CONSTRAINT for the
-- admission desk is therefore GONE: 'pullcad' is armed alone.
--
-- Honest notes on what is real here and what is not (identical in kind to the
-- sister file tests/test_replay_pullbeat_attack_cancel.lua, which pins the same
-- frame for the neighbouring constant):
--   * REAL from the replay dump: every hero's position, HP, mana, level, team,
--     items and abilities on frame 20260720_072738_slot1 @ t=160.4 -- a zoned
--     Zeus mid with Lina the only visible enemy inside the aggro-draw ring at
--     621u. Everything deciding WHETHER the pull fires is real.
--   * SYNTHESIZED: the enemy lane creep wave. make_fixture.py dumps HEROES
--     ONLY -- GetNearbyLaneCreeps(900,true) is empty on 966/966 corpus frames
--     -- so no real frame can reach the pull branch without one. It is placed
--     at Lina's real position, so the real 621u geometry is what decides the
--     <= 500 hero-to-creep adjacency.
--   * The 1/30s frame step is the engine Think rate; DotaTime is advanced by
--     the test because a fixture is ONE instant -- the world never moves, only
--     the clock does. That clock difference IS the quantity the beat reads
--     (`now - bot.creepPullAttackTime` is our own bookkeeping, set from
--     DotaTime() by the branch above it, never an engine getter), and it goes
--     both ways inside every configuration below, so this is not backlog
--     0DIR's constant-answer trap.
--   * NOT MEASURED, and deliberately: whether the aggro actually flips. The Bot
--     API exposes no such signal (the sister file's header says the same), so
--     this file measures the ORDER LOG -- how much of each beat is spent
--     dragging -- and leaves "did the wave turn around" to the batch's own
--     replays, where GH #143's FLIP axis already counts it.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local ZONED_MID = 'tests/fixtures/f_072738_zuus_mana.lua'
local STEP = 1 / 30 -- engine Think rate

-- The published mechanic this lever is aligned to. Kept as named constants so
-- an assertion that goes red names the number it was checking.
local AGGRO_HOLD_S = 2.3 -- creeps keep a drawn aggro this long
local AGGRO_CD_S = 3.0 -- upper of the two published re-draw cooldowns (2-3s)

local function read_file(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a')
    fh:close()
    return s
end

--- The creep-pull branch of roam's Think, ISOLATED before any constant is read
--- out of it (backlog 0SRC: 1.2 / 3.0 / 0.5 all occur elsewhere in this file,
--- so a whole-file match would silently report some other branch's numbers).
local function pull_branch()
    local src = read_file('bots/mode_roam_generic.lua')
    local at = assert(src:find('if bot.roamCreepPull ~= nil then', 1, true),
        'roam Think no longer has the creep-pull branch')
    local to = assert(src:find('if bot.roamCampPull ~= nil then', at, true),
        'the camp-pull branch that ends the creep-pull branch moved')
    return src:sub(at, to)
end

--- The same branch with every `--` comment removed, i.e. the CODE surface.
--- [20260823] Added during the promote of 'creeppull'/'pullbeat', which cost
--- this file four false reds in one run: the promote note explaining why the
--- old `IsSoakCandidate('pullcad') and IsSoakCandidate('pullbeat')` conjunction
--- was dropped contains that expression verbatim, so cadence()'s
--- "IsSoakCandidate('pullcad') .- nBeat = N" matcher anchored on the COMMENT
--- and then read the first `nBeat =` after it -- the SHIPPED 1.2, reported as
--- the armed beat. Every downstream assertion about the armed cadence was then
--- comparing 1.2 against itself. A source census that reads prose is measuring
--- documentation, not code (test_detector_source_constants.py §2b, same lesson
--- in Python). Assertions ABOUT prose still read pull_branch().
local function pull_code()
    return (pull_branch():gsub('%-%-[^\n]*', ''))
end

--- The camp-pull branch, isolated the same way -- it carries the 3.0s beat this
--- lever is being brought into line with.
local function camp_branch()
    local src = read_file('bots/mode_roam_generic.lua')
    local at = assert(src:find('if bot.roamCampPull ~= nil then', 1, true),
        'roam Think no longer has the camp-pull branch')
    local to = assert(src:find('campPullAttackTime = now', at, true),
        'the camp-pull cadence moved out of its branch')
    return src:sub(at, to)
end

--- The three constants that shape the creep-pull cadence, read from source.
local function cadence()
    local body = pull_code()
    local shipped = assert(body:match('local nBeat = ([%d%.]+)'),
        'the shipped attack beat is no longer a literal in the creep-pull branch')
    local armed = assert(body:match("IsSoakCandidate%('pullcad'%).-nBeat = ([%d%.]+)"),
        "the 'pullcad' beat is no longer a literal next to its gate")
    local hold = assert(body:match('bot%.creepPullAttackTime%) < ([%d%.]+) then'),
        'the pullbeat hold is no longer a literal in the creep-pull branch')
    return tonumber(shipped), tonumber(armed), tonumber(hold)
end

--- Install the fixture world, make the pull branch reachable, and return a
--- driver that runs N engine frames and answers the order log as a string:
---   'A' Action_AttackUnit   'M' Action_MoveToLocation   '.' no order at all
--- `tArmed` is the set of soak ids armed on top of 'creeppull' (which only
--- opens the branch; without it there is no plan and nothing to measure).
local function drive(tArmed)
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

    -- [PROMOTE 20260823] 'creeppull' and 'pullbeat' are turbo defaults now, so
    -- neither is armable and neither needs to be: the branch opens on turbo
    -- alone and the wind-up hold is unconditional. 'pullcad' is the only
    -- candidate this file can arm, and after the promote it is the WHOLE lever
    -- rather than half of a conjunction.
    J.IsSoakCandidate = function(id)
        return (tArmed or {})[id] == true
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

local function count(sLog, sChar)
    return select(2, sLog:gsub(sChar, ''))
end

tests['[P1 (c)] the pull bid is still reachable on the real frame'] = function()
    -- If this goes red the rest of the file is measuring an empty world rather
    -- than a cadence.
    local J, bot, run = drive(nil)
    assert(J.ShouldCreepPullLane(bot) ~= nil,
        'the real zoned-lane frame no longer produces a pull plan -- the '
        .. 'trigger changed, not the cadence')
    assert(J.IsCreepPullSafe(bot) == true, 'the frame is no longer pull-safe')
    assert(GetDesire() == 0.9, 'roam no longer bids the pull window')
    assert(bot.roamCreepPull ~= nil, 'GetDesire no longer sets the pull plan')
    run(1)
end

tests['[PROMOTE] pullcad armed ALONE is now the whole lever'] = function()
    -- The exact inversion of what this case asserted before 2026-08-23, and the
    -- reason it had to be inverted rather than deleted:
    --
    -- Pre-promote the gate read `IsSoakCandidate('pullcad') and
    -- IsSoakCandidate('pullbeat')`, so that arming 'pullcad' by itself was a
    -- byte-for-byte no-op -- the dependency on the wind-up hold expressed as
    -- code instead of prose, which was the right call while the hold was a
    -- candidate. Promoting 'pullbeat' deletes it from every armed string, which
    -- would have frozen that conjunction FALSE forever: 'pullcad' inert in
    -- every wave, check_armed_wiring.py still reporting it WIRED because the
    -- call site exists, and the verdict coming back "no effect" with nothing
    -- raising a hand. So the conjunct went, and this case now pins the opposite
    -- property -- arming 'pullcad' alone must MOVE the cadence.
    local _, armedBeat = cadence()
    local nFrames = math.floor(armedBeat / STEP) + 2
    -- One driver at a time: drive() rebinds the global GetDesire/Think, so a
    -- second driver built before the first has run would steal its frames.
    local _, _, runOff = drive(nil)
    local off = runOff(nFrames)
    local _, _, runOn = drive({ pullcad = true })
    local on = runOn(nFrames)
    assert(off ~= on, "'pullcad' armed alone changes nothing -- it is a no-op "
        .. 'in every wave that can arm it, and no wiring check would say so: '
        .. off)
    assert(count(on, 'A') < count(off, 'A'),
        "'pullcad' armed alone did not remove any of the pokes that cannot "
        .. 'draw: ' .. off .. ' -> ' .. on)
end

tests['[P1 (c) DEFECT] the shipped beat re-pokes inside the live aggro'] = function()
    -- Three pokes inside one aggro-plus-cooldown cycle, on the real frame. The
    -- second and third cannot draw anything (the first is inside the 2.3s the
    -- creeps are already following us, the second inside the re-draw cooldown)
    -- and each of them walks the bot back toward the enemy hero.
    local shipped = cadence()
    assert(shipped < AGGRO_HOLD_S, 'the shipped beat (' .. shipped
        .. 's) no longer lands inside the ' .. AGGRO_HOLD_S
        .. 's aggro -- this defect is gone and this test is stale')
    local _, _, run = drive(nil)
    local nFrames = math.floor(AGGRO_CD_S / STEP) + 2
    local log = run(nFrames)
    assert(count(log, 'A') >= 3, 'expected at least three pokes inside one '
        .. AGGRO_CD_S .. 's aggro cycle at a ' .. shipped .. 's beat, got '
        .. count(log, 'A') .. ' in ' .. log)
end

tests['[P1 (c) FIX] armed, one poke per aggro cycle and the rest is drag'] =
function()
    local _, armedBeat, hold = cadence()
    local _, _, run = drive({ pullcad = true })
    -- One full armed beat plus one frame: the next poke must be the last entry.
    local nFrames = math.floor(armedBeat / STEP) + 2
    local log = run(nFrames)

    assert(log:sub(1, 1) == 'A', 'the beat no longer opens with the poke')
    assert(log:sub(-1) == 'A', 'the next beat no longer lands after '
        .. armedBeat .. 's, got ' .. log)
    assert(count(log, 'A') == 2, 'expected exactly the opening poke and the '
        .. 'next one -- a poke in between is a draw inside the live aggro: '
        .. log)

    -- The wind-up hold is still first and still contiguous ('pullbeat' is armed
    -- here, and the longer beat must not have swallowed or moved it).
    local held = log:match('^A(%.*)M')
    assert(held ~= nil, 'the protected wind-up is no longer the first thing '
        .. 'after the poke: ' .. log)
    assert(math.abs(#held - hold / STEP) <= 1,
        'expected about ' .. (hold / STEP) .. ' held frames, got ' .. #held)

    -- ...and the drag owns the window, which is the whole point of the lever.
    local nDrag = count(log, 'M')
    assert(nDrag / (nFrames - 1) >= 0.8, 'the drag owns only '
        .. math.floor(nDrag / (nFrames - 1) * 100) .. '% of the armed beat')
end

tests['[P1 (c) FIX] arming strictly increases the share spent dragging'] =
function()
    -- Measured on the SAME window on both legs, so the two shares are
    -- comparable: this is the quantity the lever claims to move.
    local _, armedBeat = cadence()
    local nFrames = math.floor(armedBeat / STEP) + 2
    -- One driver at a time (see the GATE test above).
    local _, _, runOff = drive(nil)
    local off = runOff(nFrames)
    local _, _, runOn = drive({ pullcad = true })
    local on = runOn(nFrames)
    assert(count(on, 'M') > count(off, 'M'), 'arming did not buy any extra '
        .. 'drag frames: ' .. count(off, 'M') .. ' -> ' .. count(on, 'M'))
    assert(count(on, 'A') < count(off, 'A'), 'arming did not remove any of '
        .. 'the pokes that cannot draw: ' .. off)
end

tests['[P1 (c)] the armed beat clears both published aggro numbers'] = function()
    local shipped, armed, hold = cadence()
    assert(armed >= AGGRO_HOLD_S, 'the armed beat (' .. armed .. 's) re-pokes '
        .. 'while the ' .. AGGRO_HOLD_S .. 's aggro is still live')
    assert(armed >= AGGRO_CD_S, 'the armed beat (' .. armed .. 's) re-pokes '
        .. 'inside the ' .. AGGRO_CD_S .. 's re-draw cooldown -- the poke '
        .. 'cannot draw anything and walks us toward the enemy')
    assert(armed > shipped, 'the candidate no longer lengthens the beat')
    assert(hold < armed, 'the wind-up hold (' .. hold .. 's) is not shorter '
        .. 'than the armed beat -- the bot would never drag')
end

tests['[PROMOTE] the pullcad gate names no promoted id'] = function()
    -- The general hazard this promote surfaced, pinned so the next one cannot
    -- repeat it: a gate whose condition conjoins ANOTHER candidate id goes
    -- permanently false the day that id is promoted, and nothing warns --
    -- check_armed_wiring.py checks that a call site exists, not that the
    -- condition can ever be true, so the wave comes back "no effect" and the
    -- lever is quietly written off. Every id named in this condition must
    -- therefore still be an armable candidate.
    local body = pull_code()
    local cond = assert(body:match("(if J%.IsSoakCandidate%('pullcad'%)[^\n]*)"),
        "the 'pullcad' gate is gone from the creep-pull branch")
    local PROMOTED = { creeppull = true, pullbeat = true }
    for id in cond:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do
        assert(not PROMOTED[id], "the 'pullcad' gate conjoins '" .. id
            .. "', which was PROMOTED and so is in no armed string -- this "
            .. 'gate can never be true and no wiring check would say so')
    end
    -- ...and it is still a gate: 'pullcad' itself is unpromoted.
    assert(cond:find("IsSoakCandidate('pullcad')", 1, true),
        "the 'pullcad' gate no longer names its own id")
    -- Turbo is structural, not restated: the plan only exists because
    -- J.ShouldCreepPullLane returned non-nil, and that opens with IsModeTurbo.
    -- Read on the PROSE surface -- this asserts an explanation exists.
    assert(pull_branch():find('IsModeTurbo', 1, true),
        'the branch no longer records WHY it does not re-check turbo')
end

tests['[control] the comment stripper actually strips'] = function()
    -- A stripper that quietly returned its input would put cadence() and the
    -- gate census back on the prose surface -- the exact failure it was added
    -- to fix, in a form where nothing goes red.
    local raw, code = pull_branch(), pull_code()
    assert(#code < #raw, 'pull_code() removed nothing from the branch')
    assert(raw:find('PROMOTED', 1, true),
        'the creep-pull branch no longer records that it was promoted')
    assert(not code:find('PROMOTED', 1, true),
        'pull_code() left comment text behind: it is not a code surface')
    assert(code:find('creepPullAttackTime', 1, true),
        'pull_code() stripped the code as well as the comments')
end

tests['[P1 (c)] the two pull cadences in this file agree'] = function()
    -- The camp pull has poked every 3.0s since wave13 for the same mechanical
    -- reason. If someone retunes one of them, this names the other.
    local _, armed = cadence()
    local camp = assert(camp_branch():match('campPullAttackTime > ([%d%.]+)'),
        'the camp-pull beat is no longer a literal in its branch')
    assert(tonumber(camp) == armed, 'the camp pull now pokes every ' .. camp
        .. 's while the armed creep pull pokes every ' .. armed
        .. 's -- the two cadences imitate the same engine mechanic')
end

tests['[reverse] no other caller sets the creep-pull poke clock'] = function()
    -- The beat is only meaningful because ONE place writes
    -- bot.creepPullAttackTime. A second writer (a retreat guard clearing it, a
    -- hero file poking on its own) would reset the cadence from outside and
    -- this whole file would be measuring a fiction.
    local hits = 0
    local p = io.popen("grep -rl 'creepPullAttackTime' bots/ 2>/dev/null")
    for line in p:lines() do
        hits = hits + 1
        assert(line == 'bots/mode_roam_generic.lua',
            'a second file now touches the creep-pull poke clock: ' .. line)
    end
    p:close()
    assert(hits == 1, 'expected exactly one file to own the poke clock, got '
        .. hits)
end

return tests
