-- [ratchet] [GH #326 20260830] Soak candidate 'creepthink': the creep-pull DRAG
-- IS STRUCTURALLY UNREACHABLE, and the line that eats it is not in the drag.
--
-- ==== THE MAIN CRITERION, AND IT IS AN INEQUALITY ==========================
--
-- mode_roam_generic's creep-pull cadence is one if/elseif/else, and all three
-- arms sit BEHIND the same think-throttle two lines above Think's top:
--
--     if <no bypass> and J.Utils.IsBotThinkingMeaningfulAction(...) then return end
--     ...
--     if  now - creepPullAttackTime > nBeat then  POKE                -- the `if`
--     elseif now - creepPullAttackTime < 0.5 then  hold (no order)    -- 'pullbeat'
--     else                                         DRAG               -- the `else`
--
-- The throttle matches bot:GetAnimActivity() against utils.lua's
-- meaningfulActivities, a list that opens with ACTIVITY_RUN and ACTIVITY_ATTACK.
-- A hero that just right-clicked its lane opponent is in ACTIVITY_ATTACK BY
-- CONSTRUCTION for the length of its attack cycle, so Think returns on those
-- frames and the cadence is asked NOTHING at all.
--
-- Write R for the interval at which the throttle reopens (in practice the
-- attack cycle: the hero is animating between pokes and idle only in the seam).
-- The cadence is therefore evaluated ONLY on reopened frames, and on such a
-- frame the elapsed time since the last poke is already >= R.  So:
--
--     R > nBeat  =>  the `if` is true on EVERY frame the cadence is reached
--                =>  the `else` (the DRAG) is reached on NONE of them.
--
-- That is not "the drag runs rarely".  It is an empty set.  The shipped beat is
-- 1.2 s and an early-game attack cycle is ~1.4-1.7 s, so the shipped
-- configuration sits on the wrong side of the inequality and the wave is never
-- walked back.  What the hero does instead is stand in the aggro it drew.
--
-- ==== THE BEARING FRAME (GH #326's, read the other way) ====================
--
-- 20260830_003408_slot1 (seed 1828, ab/armed, W27), necrolyte -> jakiro, inside
-- a pull-certified episode: SIX consecutive seconds of byte-identical
-- coordinates (-5847, 5064) while four melee lane creeps ate it from 0.96 HP to
-- 0.37, with four right-clicks at 252.4 / 254.0 / 255.4 / 257.0 -- gaps
-- 1.6 / 1.4 / 1.6, every one of them LONGER than the shipped 1.2 s beat and
-- none shorter.  That is this inequality photographed: R ~ 1.5 s, nBeat 1.2 s,
-- pokes arriving one per reopened frame and not one drag order between them.
-- It is the GH #186 zuus camp frame with lane creeps swapped in.
--
-- GH #326 reads the same table and concludes the opposite -- "neither leg can
-- write zero-displacement + 1.5 s right-clicks", therefore these frames are
-- DOMAIN LEAKAGE, therefore the non-branch population is at least 40.0-51.8%.
-- The branch can write exactly that shape, and this file drives it doing so.
-- The 40.0-51.8% figure is a lower bound on "still frames", which is sound; it
-- is its reading as a lower bound on NON-BRANCH frames that this file denies.
-- Note the sign check the issue's own numbers pass: a poke deferred to the
-- first frame the throttle reopens is LATE, never early, which is why all three
-- observed gaps exceed 1.2 s.  A domain leak has no reason to be one-sided.
--
-- ==== WHY NO TEST IN THIS REPO COULD HAVE SEEN IT ==========================
--
-- The same single fabricated number that hid GH #186: bot:GetAnimActivity()
-- answers 0 on every corpus frame, and 0 is in no ACTIVITY_* list, so the
-- predicate has one answer forever at all nine of its call sites.  The list
-- itself is NOT a second lock -- the mock auto-defines unknown ALL_CAPS globals
-- to distinct positive ids, so meaningfulActivities is fully populated with
-- numbers none of which can be 0.  Both facts are re-asserted below ([W1],
-- [W2]), because this file has to MANUFACTURE the engine's reading to make the
-- defect visible, and an assertion that stopped being true would mean the
-- manufacture -- not the defect -- is what the file measures.
--
-- ==== WHAT IS REAL AND WHAT IS DECLARED ====================================
--
--   REAL   every hero's position, team, level and HP on f_072738_zuus_mana --
--          the zoned-mid frame that pinned 'pullbeat' (GH #143) and the frame
--          J.ShouldCreepPullLane still bids a pull on.  The pull plan under
--          test is produced by the REAL GetDesire on that frame, not declared.
--   DECLARED  the enemy lane creep (dumps carry heroes, not creeps), placed at
--          the real lina's real location; an even lane front, so the pull is
--          justified by the real zoning and never by a stacked wave; and the
--          animation model -- ACTIVITY_ATTACK for nCycle seconds after each
--          poke, idle otherwise.  nCycle is the one free parameter and it is
--          SWEPT ([arith A1]) rather than tuned: the claim is about which side
--          of nBeat it falls on, not about its value.
--
-- ==== HONEST BOUNDS ========================================================
--
--   * This file does NOT re-derive #326's W25/W27 percentages and does not
--     refute them as still-frame counts.  It refutes one inferential step.
--   * The animation model is a model.  It is not read from the dump (W1 is why),
--     and no fixture can supply it.  What is not modelled is exonerated by the
--     sweep: for nCycle < nBeat the drag DOES fire, so a green result here is
--     not the injection being inert.
--   * Whether walking the wave back WINS games is a wave question, unchanged.
--     What is settled locally is whether a move order is issued at all.
--   * 'creepthink' is GATED and unpromoted: nothing here ships live.
--
-- ==== MUTATION RECORD (11 run: 10 CAUGHT, 1 SURVIVED BY DESIGN) ============
--
--   M1  delete the creepthink clause                       CAUGHT  [gate G1]
--   M2  conjoin the gate with 'pullbeat' (pullcad trap)    CAUGHT  [gate G1]
--   M3  drop `bot.roamCreepPull ~= nil` from the bypass    CAUGHT  [G1] + [C2]
--       ^ ON THE FIRST PASS THIS WAS CAUGHT BY THE SOURCE ASSERTION ONLY, and
--         that is the self-inflicted flaw of this round: [control C2] compared
--         two ORDER LOGS, and in a world with no pull plan there is no order to
--         differ -- a bypass firing on every roam frame still prints two equal
--         strings of dots.  The control was green for the absence of a signal
--         it could not carry.  Fixed by adding the past-throttle probe, which
--         reads the widening directly; M3 and M7 now both bite behaviourally.
--   M4  point the guard at bot.roamCampPull instead        CAUGHT  [gate G1]
--   M5  shipped nBeat 1.2 -> 3.0                           CAUGHT  [DEFECT/A2]
--   M6  shipped nBeat 1.2 -> 0.2                           CAUGHT  [control C1]
--   M7  invert the bypass polarity (drop the `not`)        CAUGHT  [control C2]
--         (probe reads 482 past-throttle frames with NO plan live)
--   M8  the promoted 'pullbeat' hold 0.5 -> 0.0          SURVIVED, by design
--         ^ not this lever's guard and deliberately not re-tested here.  It is
--           covered where it belongs: the same patch under
--           tests/test_replay_pullbeat_attack_cancel.lua goes red (4 failures,
--           "the shipped leg holds no frame: AMMMM...").  Registered rather
--           than papered over -- if that file ever stops covering it, this
--           line is the record that nothing else does.
--   M9  empty the `else` arm (drag ordered nowhere)        CAUGHT  [control C1]
--   M10 [self] neuter the stripper's own sanity assert   SURVIVED, expected
--         (a guard that only fires when the stripper breaks; M11 is the real
--          test of the stripper, and it bites)
--   M11 [self] make mode_code() return its input unstripped CAUGHT [gate G2]

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local ZONED_MID = 'tests/fixtures/f_072738_zuus_mana.lua'
local STEP = 1 / 30 -- engine Think rate
local MODE_SRC = 'bots/mode_roam_generic.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- The mode source with every comment removed: prose is not code.
local function mode_code()
    return (read_file(MODE_SRC):gsub('%-%-[^\n]*', ''))
end

--- The SHIPPED beat, read from the source rather than copied (0SRC): a constant
--- that moves must move this file's arithmetic with it.
local function shipped_beat()
    local code = mode_code()
    local beat = assert(code:match('local nBeat = ([%d%.]+)'),
        'the shipped creep-pull beat is no longer `local nBeat = <literal>`')
    return tonumber(beat)
end

--- Install the fixture world, model the attack animation, and return a driver
--- that runs N engine frames and answers the order log as a string:
---   'A' Action_AttackUnit   'M' Action_MoveToLocation   '.' no order at all
---
--- A fourth return value, probe(), answers how many times Think ran PAST the
--- throttle and past both pull branches (it counts ThinkIndividualRoaming
--- calls).  Comparing order logs cannot see a bypass that fires on frames with
--- no pull plan -- there is no order to differ -- so the no-plan control needs
--- this instead: see [control C2], and mutation M3 in the record at the foot.
---
--- @param bArmed     arm soak candidate 'creepthink' (nothing else is armed)
--- @param nCycle     seconds of ACTIVITY_ATTACK after each poke (0 = never)
--- @param opts       { noPlan = suppress the pull plan,
---                     alwaysAnim = ACTIVITY_ATTACK on every frame, poke or not }
local function drive(bArmed, nCycle, opts)
    opts = opts or {}
    local J, bot, heroes = rf.load(ZONED_MID)
    local lina = heroes['npc_dota_hero_lina']
    local sp = rawget(bot, '__spec')

    -- Engine plumbing the hero dump does not carry, identical to the setup
    -- tests/test_replay_pullbeat_attack_cancel.lua drives this branch with.
    local creep = api.MakeUnit({
        CanBeSeen = true, IsAlive = true, GetLocation = lina:GetLocation(),
    })
    sp.GetNearbyLaneCreeps = function(_, _radius, bEnemy)
        if bEnemy then return { creep } end
        return {}
    end
    rawset(bot, 'GetNearbyLaneCreeps', nil)
    GetLaneFrontAmount = function() return 0.5 end -- luacheck: ignore

    local log, tLastPoke = {}, nil
    sp.Action_AttackUnit = function()
        log[#log + 1] = 'A'
        tLastPoke = DotaTime()
    end
    sp.Action_MoveToLocation = function() log[#log + 1] = 'M' end
    rawset(bot, 'Action_AttackUnit', nil)
    rawset(bot, 'Action_MoveToLocation', nil)

    -- The engine reading the corpus does not carry (W1).  ACTIVITY_ATTACK is
    -- read through the mock's own auto-constant table (W2), i.e. the SAME
    -- number utils.lua put in meaningfulActivities -- no enum is injected here,
    -- which would risk handing the two sides different values for one name.
    sp.GetAnimActivity = function()
        if opts.alwaysAnim then return ACTIVITY_ATTACK end
        if nCycle > 0 and tLastPoke ~= nil and (DotaTime() - tLastPoke) < nCycle then
            return ACTIVITY_ATTACK
        end
        return 0
    end
    rawset(bot, 'GetAnimActivity', nil)

    J.IsSoakCandidate = function(sId) return bArmed and sId == 'creepthink' end
    if opts.noPlan then
        J.ShouldCreepPullLane = function() return nil end
    end

    dofile(MODE_SRC)

    -- Past-throttle probe.  ThinkIndividualRoaming is a global defined by the
    -- mode file and is called only after the throttle AND after both pull
    -- branches (each of which returns), so a non-zero count means Think ran on
    -- past the line under test.
    local nPastThrottle = 0
    local fReal = ThinkIndividualRoaming
    ThinkIndividualRoaming = function(...) -- luacheck: ignore
        nPastThrottle = nPastThrottle + 1
        return fReal(...)
    end

    local t0 = DotaTime()
    return J, bot, function(nSeconds)
        for i = 0, math.floor(nSeconds / STEP) do
            local now = t0 + i * STEP
            DotaTime = function() return now end -- luacheck: ignore
            local n = #log
            GetDesire()
            Think()
            if #log == n then log[#log + 1] = '.' end
        end
        return table.concat(log)
    end, function() return nPastThrottle end
end

local function count(sLog, sChar)
    return select(2, sLog:gsub(sChar, ''))
end

-- ==========================================================================
-- The frame, and the two world readings the injection rests on
-- ==========================================================================

tests['[frame F1] the real frame still bids the creep pull'] = function()
    -- If this goes red every leg below is driving an empty world rather than
    -- the cadence, and the file measures nothing.
    local J, bot, run = drive(false, 0)
    assert(J.ShouldCreepPullLane(bot) ~= nil,
        'the zoned-lane frame no longer produces a pull plan -- the trigger '
        .. 'changed, not the throttle')
    assert(GetDesire() == 0.9, 'roam no longer bids the pull window')
    assert(bot.roamCreepPull ~= nil, 'GetDesire no longer sets the pull plan')
    assert(bot.roamCampPull == nil,
        'the camp plan is live on this frame -- this file would be measuring '
        .. "'pullthink' territory, not 'creepthink'")
    run(0.1)
end

tests['[W1] the untouched frame reads a fabricated 0 and the throttle is open']
= function()
    -- The whole reason the animation has to be manufactured.  If a fixture ever
    -- starts carrying a real activity this goes red, and the injection stops
    -- being the only way to ask the question.
    local J, bot = rf.load(ZONED_MID)
    assert(bot:GetAnimActivity() == 0,
        'GetAnimActivity is no longer a fabricated 0 on this frame -- W1 is '
        .. 'stale, re-read this file')
    assert(J.Utils.IsBotThinkingMeaningfulAction(bot, 1, 'roam') == false,
        'the throttle already fires on the untouched frame -- W1 is stale')
end

tests['[W2 control] a real activity DOES fire the throttle'] = function()
    -- The control for [W1]: if handing the predicate an ACTIVITY_* did not flip
    -- it, every leg below would be measuring an inert knob and would pass for
    -- the wrong reason.  Also pins that ACTIVITY_ATTACK resolves to a real,
    -- positive, auto-defined constant -- so 0 is what can never be in the list.
    local J, bot = rf.load(ZONED_MID)
    local sp = rawget(bot, '__spec')
    assert(type(ACTIVITY_ATTACK) == 'number' and ACTIVITY_ATTACK > 0,
        'ACTIVITY_ATTACK is not an auto-defined positive constant under the '
        .. 'mock (' .. tostring(ACTIVITY_ATTACK) .. ') -- W2 is stale')
    sp.GetAnimActivity = function() return ACTIVITY_ATTACK end
    rawset(bot, 'GetAnimActivity', nil)
    local t = DotaTime()
    DotaTime = function() return t + 10 end -- past the 0.11s result cache
    assert(J.Utils.IsBotThinkingMeaningfulAction(bot, 1, 'roam') == true,
        'ACTIVITY_ATTACK does not reach meaningfulActivities -- the list '
        .. 'changed, and the defect this file describes may no longer exist')
end

-- ==========================================================================
-- The defect
-- ==========================================================================

tests['[GH #326 DEFECT] shipped: pokes fire, the drag is never ordered'] = function()
    -- The bearing frame's shape, produced by the branch itself: eight seconds
    -- of an attack cycle LONGER than the shipped beat yields right-clicks and
    -- not one move order.  Zero move orders is zero displacement, which is what
    -- the desk photographed as six seconds of identical coordinates.
    local nBeat = shipped_beat()
    local nCycle = 1.5 -- an early-game attack cycle; the sweep below owns this
    assert(nCycle > nBeat,
        'the shipped beat is now >= the modelled attack cycle -- the inequality '
        .. 'this file is about no longer holds at these numbers')
    local _, _, run = drive(false, nCycle)
    local log = run(8.0)
    assert(count(log, 'A') >= 4,
        'the shipped cadence stopped poking entirely (' .. count(log, 'A')
        .. ' pokes) -- that is a different defect from the one under test')
    assert(count(log, 'M') == 0,
        'the drag was ordered ' .. count(log, 'M') .. ' times -- the `else` arm '
        .. 'is reachable at R > nBeat, and the main criterion is wrong')
end

tests['[arith A1] the separator is the inequality, not the injection'] = function()
    -- The control that makes the leg above mean something: sweep the attack
    -- cycle across the shipped beat and show the drag-order count is zero
    -- EXACTLY on the side the criterion predicts.  If the drag never fired at
    -- any cycle, the animation injection would simply be jamming Think and the
    -- file would be green for the wrong reason.
    local nBeat = shipped_beat()
    local below, above = {}, {}
    for _, nCycle in ipairs({ 0.3, 0.6, 0.9 }) do
        assert(nCycle < nBeat, 'sweep point ' .. nCycle .. ' is no longer below '
            .. 'the shipped beat ' .. nBeat .. ' -- the sweep needs re-picking')
        local _, _, run = drive(false, nCycle)
        below[#below + 1] = count(run(8.0), 'M')
    end
    for _, nCycle in ipairs({ 1.4, 1.8, 2.2 }) do
        assert(nCycle > nBeat, 'sweep point ' .. nCycle .. ' is no longer above '
            .. 'the shipped beat ' .. nBeat .. ' -- the sweep needs re-picking')
        local _, _, run = drive(false, nCycle)
        above[#above + 1] = count(run(8.0), 'M')
    end
    for i, n in ipairs(below) do
        assert(n > 0, 'sweep point ' .. i .. ' BELOW the beat ordered no drag '
            .. 'either -- the injection is jamming Think outright, and the '
            .. 'DEFECT leg above proves nothing')
    end
    for i, n in ipairs(above) do
        assert(n == 0, 'sweep point ' .. i .. ' ABOVE the beat ordered ' .. n
            .. ' drags -- the `else` arm is reachable there after all')
    end
end

tests['[arith A2] a throttled poke is LATE, never early'] = function()
    -- The sign check GH #326's own gap column passes: 1.6 / 1.4 / 1.6, all
    -- longer than the 1.2 s beat, none shorter.  A poke can only be deferred by
    -- the throttle, never advanced -- so every observed gap must exceed the
    -- beat.  This is what makes the still frames one-sided; a domain leak has no
    -- reason to be.  Asserted on the drive, not on the issue's table.
    local nBeat = shipped_beat()
    local nCycle = 1.5
    local _, _, run = drive(false, nCycle)
    local log = run(8.0)
    -- Reconstruct poke times from the log: one frame per character.
    local tPokes = {}
    for i = 1, #log do
        if log:sub(i, i) == 'A' then tPokes[#tPokes + 1] = (i - 1) * STEP end
    end
    assert(#tPokes >= 4, 'not enough pokes to read gaps (' .. #tPokes .. ')')
    for i = 2, #tPokes do
        local gap = tPokes[i] - tPokes[i - 1]
        assert(gap >= nBeat - 1e-9, 'gap ' .. string.format('%.3f', gap)
            .. 's is SHORTER than the beat ' .. nBeat .. 's -- a poke was '
            .. 'advanced, which the throttle cannot do')
        assert(gap >= nCycle - 1e-9, 'gap ' .. string.format('%.3f', gap)
            .. 's is shorter than the reopen interval ' .. nCycle
            .. 's -- the cadence ran on a frame the throttle should have eaten')
    end
end

-- ==========================================================================
-- The lever
-- ==========================================================================

tests["[FIX] armed 'creepthink' makes the drag reachable again"] = function()
    local nCycle = 1.5
    local _, _, run = drive(true, nCycle)
    local log = run(8.0)
    assert(count(log, 'A') >= 2,
        'the armed leg stopped poking (' .. count(log, 'A') .. ')')
    assert(count(log, 'M') > 0,
        'armed, the drag is STILL never ordered -- the bypass does not reach '
        .. 'the branch it was written for')
end

tests['[control C1] with the throttle open the lever is byte-identical']
= function()
    -- Where the throttle never fires there is nothing to bypass, so arming must
    -- change nothing at all.  If this goes red the bypass is doing something
    -- besides bypassing.
    local shipped = select(3, drive(false, 0))(8.0)
    local armed = select(3, drive(true, 0))(8.0)
    assert(shipped == armed,
        'arming changed the order log on frames where the throttle never '
        .. 'fires:\n  shipped ' .. shipped .. '\n  armed   ' .. armed)
    assert(count(shipped, 'M') > 0,
        'the open-throttle log has no drag order at all -- this control is '
        .. 'comparing two empty worlds')
end

tests['[control C2] with no pull plan the lever does not open the throttle']
= function()
    -- The clause is guarded on a LIVE creep-pull plan.  With none, an armed
    -- 'creepthink' must leave the throttle exactly as shipped -- otherwise the
    -- id would be silently widening every roam frame in the game.
    --
    -- Comparing ORDER LOGS cannot ask this: with no plan there is no order to
    -- differ, so a bypass that fired on every roam frame would still print two
    -- identical strings of dots.  That is not hypothetical -- it is mutation M3
    -- (drop `bot.roamCreepPull ~= nil` from the bypass), which the log
    -- comparison passed and only the source assertion caught.  So this control
    -- reads the past-throttle probe, which sees the widening directly.
    local opts = { noPlan = true, alwaysAnim = true }
    local _, _, runS, probeS = drive(false, 1.5, opts)
    local _, _, runA, probeA = drive(true, 1.5, opts)
    local shipped, armed = runS(8.0), runA(8.0)
    assert(probeS() == 0,
        'the SHIPPED no-plan world already ran past the throttle ' .. probeS()
        .. ' times -- the throttle is not firing and this control is vacuous')
    assert(probeA() == 0,
        'armed, Think ran past the throttle ' .. probeA() .. ' times on frames '
        .. 'with NO pull plan -- the bypass is widening every roam frame')
    assert(shipped == armed,
        'arming changed the order log on frames with no pull plan:\n  shipped '
        .. shipped .. '\n  armed   ' .. armed)
    assert(count(shipped, 'A') == 0 and count(shipped, 'M') == 0,
        'the no-plan world is still issuing pull orders -- the suppression in '
        .. 'the driver did not take')
end

-- ==========================================================================
-- Gate shape (the 'pullcad' trap, and the packaging argument)
-- ==========================================================================

tests['[gate G1] one standalone creepthink gate, guarded on a live plan']
= function()
    local code = mode_code()
    assert(code:find('roamCreepPull', 1, true),
        'the comment stripper ate the code as well as the prose')
    local n = select(2, code:gsub("IsSoakCandidate%('creepthink'%)", ''))
    assert(n == 1, "expected exactly one 'creepthink' gate in code, found " .. n)
    assert(not code:find("IsSoakCandidate%('creepthink'%)%s*and%s*J%.IsSoakCandidate"),
        "the creepthink gate was conjoined with another candidate id -- that is "
        .. 'frozen FALSE the day the other id is promoted (the pullcad trap), '
        .. 'while check_armed_wiring.py still reads it WIRED')
    assert(code:find("bot%.roamCreepPull ~= nil and J%.IsSoakCandidate%('creepthink'%)"),
        'the throttle bypass no longer requires a live creep-pull plan')
end

tests["[gate G2] 'pullthink' is untouched: still two gates, still camp-scoped"]
= function()
    -- This change sits one line from the camp lever.  If its gate count or
    -- guard moved, the two ids stop being separately attributable and both
    -- condition-(a) readings become unreadable.
    local code = mode_code()
    local n = select(2, code:gsub("IsSoakCandidate%('pullthink'%)", ''))
    assert(n == 2, "expected exactly two 'pullthink' gates in code (the "
        .. 'throttle bypass and the wind-up hold), found ' .. n)
    assert(code:find("bot%.roamCampPull ~= nil and J%.IsSoakCandidate%('pullthink'%)"),
        "the camp bypass no longer requires a live camp-pull plan")
end

tests['[gate G3] the two domains are disjoint BY CONSTRUCTION'] = function()
    -- The packaging argument, asserted rather than left in prose: separate ids
    -- are correct because GetDesire nils each plan when it sets the other, so
    -- no frame can be in both domains and each (a) reading is attributable.
    -- If this ever stops holding, the two levers start co-arming on the same
    -- frames and the ids must be merged.
    local code = mode_code()
    assert(code:find('bot%.roamCreepPull = pull%s+bot%.roamCampPull = nil'),
        'the creep-pull bid no longer nils the camp plan -- the two domains '
        .. 'may now overlap, and creepthink/pullthink stop being attributable')
    assert(code:find('bot%.roamCampPull = vCamp%s+bot%.roamCreepPull = nil'),
        'the camp-pull bid no longer nils the creep plan -- same consequence')
    -- And on the real frame, empirically.
    local _, bot, run = drive(false, 1.5)
    run(2.0)
    assert(not (bot.roamCreepPull ~= nil and bot.roamCampPull ~= nil),
        'both pull plans are live on the same frame')
end

return tests
