-- [GH #521 20260905] Soak candidate 'creepthink', condition (a), bought at the
-- ONLY layer that can sell it.
--
-- ==== WHY THIS FILE EXISTS =================================================
--
-- The replay desk ruled 2026-09-05 (GH #521, report 20260905T095535Z) that
-- 'creepthink' -- armed since W30, 155 reports, zero verdict, one of the three
-- ids in the entire 62-id armed set whose condition-(a) coverage is zero in BOTH
-- columns -- cannot be verified from the dump side at any price, and judged its
-- own frame-by-frame attempt INDETERMINATE rather than SILENT.  The argument is
-- structural, not a shortage of games:
--
--   * the only thing this id changes is whether Think() REACHES the line that
--     orders the drag, and the command stream is not in the dump;
--   * every displacement proxy for it is contaminated twice over -- an order
--     issued on an earlier frame keeps executing while the hero is throttled
--     (so a moving baseline hero proves nothing), and the other modes' Thinks
--     can turn the same hero on the same frame (so a reversal proves only that
--     SOME mode gave an order, never that the pull branch did).
--
-- "More batch games" cannot fix either.  What can is asking the question where
-- the orders are observable: drive the real Think() on a real frame and read the
-- order log.  That is this file.  It is condition-(a) evidence and nothing more
-- -- it is not a promote argument, and it does not claim the drag connects the
-- camp to the wave (see the honest limit at the bottom).
--
-- ==== THE LINE UNDER TEST ==================================================
--
-- bots/mode_roam_generic.lua, two statements into Think():
--
--     if not (bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink'))
--     and not (bot.roamCreepPull ~= nil and J.IsSoakCandidate('creepthink'))
--     and J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, "roam")
--     then return end
--
-- utils.lua's `meaningfulActivities` opens with ACTIVITY_RUN and ACTIVITY_ATTACK.
-- A hero that has just right-clicked its lane opponent -- which is what the
-- FIRST beat of the pull cadence orders it to do -- is in ACTIVITY_ATTACK by
-- construction for a whole attack cycle, and the enemy creeps hitting back keep
-- it re-acquiring.  So the frames on which the drag must be ordered are exactly
-- the frames this line eats.  Armed, the second conjunct is false whenever a
-- creep-pull plan is live, and Think falls through to the cadence.
--
-- ==== WHAT IS REAL ON THE FRAME, AND WHAT IS DECLARED ======================
--
--   REAL   the whole frame: chaos_knight at its real position on
--          20260721_230545 t=244.0 (4:04), a laning-phase core at 0.94 HP with
--          exactly ONE enemy hero (luna) inside 1000.
--   REAL   THE PULL PLAN ITSELF.  This file does NOT set bot.roamCreepPull.  It
--          drives the shipped GetDesire() every frame, exactly as the engine
--          does, and lets J.ShouldCreepPullLane + J.IsCreepPullSafe decide --
--          on the real frame -- whether a plan exists.  Nine of that helper's
--          ten clauses are therefore answered by the dump: turbo, alive, laning
--          phase, core, the 6:00 curfew, HP >= 0.5, the single-enemy safety
--          rule, the zoned/lane-front disadvantage test, and the target's
--          attackability.  `pull.enemy` is the real luna handle and
--          `pull.retreat` is computed off real coordinates.
--          (This is strictly stronger than tests/test_pullthink_anim_throttle.lua
--          and tests/test_pulldrag_lane_step.lua, which both DECLARE their plan.)
--   DECLARED  ONE enemy lane creep, at a constructed point 250 u from luna on
--          the segment toward the bot -- inside the 500 u aggro-redirect ring
--          the helper itself tests.  The dumper writes heroes and buildings and
--          no lane creeps, so `GetNearbyLaneCreeps` answers a MEASURED empty
--          table on 459 of 459 laning-phase corpus frames (never nil, never a
--          raise) and no frame in this repository can carry a creep pull
--          unaided.  tests/_creepthink_sweep.lua prices exactly that: the same
--          shipped helper, same frames, one declared creep -> 73 plans, 48 of
--          them also clearing IsCreepPullSafe.  Same shape as GH #511's missing
--          `buildings.modifiers`: a field the instrument omits, named and handed
--          back, not a defect in the lever.
--   DECLARED  the anim activity, which is the whole point -- see [W1] below and
--          the long note in tests/test_pullthink_anim_throttle.lua.  Declared as
--          a constant per world ('idle' = the mock's own fabricated reading,
--          'attack' = the hero the desk photographed, held in its attack
--          animation by the wave it just aggroed).
--
-- ==== THE READING ==========================================================
--
--   world      shipped                armed
--   'idle'     A...........MMMM...    IDENTICAL      <- anti-vacuity control
--   'attack'   ................       == shipped's 'idle' log
--
-- The second row is the defect and the fix in one line: with the animation the
-- engine actually reports, the shipped tree spends a whole cadence beat issuing
-- NOT ONE ORDER, and arming 'creepthink' restores precisely the cadence the
-- animation was eating -- not a new behaviour, the shipped one, un-eaten.
-- The first row is what stops that from being a vacuous pass: when the throttle
-- is not firing, arming the id changes nothing at all, so the entire measured
-- difference is attributable to the one line it gates and to nothing else.
--
-- ==== HONEST LIMITS ========================================================
--
--  (1) This file shows the DRAG ORDER IS ISSUED.  It does not show the wave
--      follows -- that needs lane creeps, and the corpus has none at any price.
--      GH #143's aggro reading is the evidence for that half and it is not
--      re-litigated here.
--  (2) The single declared creep is legitimate for the plumbing question and is
--      NOT legitimate for the lane-equilibrium question.  Nothing below claims
--      the latter.
--  (3) 'pullcad' is deliberately NOT armed here, so the beat is the shipped
--      1.2 s.  Arming both is a different (and per mode_roam_generic's own
--      duty-cycle table, strongly non-additive) configuration and is not what
--      this file measures.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local FRAME = 'tests/fixtures/f_230545_wk_laning_safe.lua'
local SUBJECT = 'npc_dota_hero_chaos_knight'
local OPPONENT = 'npc_dota_hero_luna'
local STEP = 1 / 30              -- engine Think rate
local BEAT = 1.2                 -- the shipped creep-pull cadence
local HOLD = 0.5                 -- the promoted 'pullbeat' wind-up hold
local CREEP_FROM_ENEMY = 250     -- inside the 500u aggro-redirect ring
local SWEEP = 'lua5.1 tests/_creepthink_sweep.lua'

--- Install the real frame, declare the one missing field (an enemy lane creep)
--- and the anim activity, then return a driver that runs N engine frames --
--- GetDesire() then Think(), as the engine does -- and answers the order log:
---   'A' Action_AttackUnit   'M' Action_MoveToLocation   '.' no order at all
local function drive(sAnim, bArmed)
    local J, bot = rf.load(FRAME, SUBJECT)
    local sp = rawget(bot, '__spec')

    -- The one field the dumper does not write.  Placed off the REAL geometry:
    -- 250u from the real luna, on the segment toward the real chaos_knight.
    local enemy
    for _, h in ipairs(J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE) or {}) do
        if h:GetUnitName() == OPPONENT then enemy = h end
    end
    assert(enemy ~= nil, OPPONENT .. ' is no longer within 1000 of ' .. SUBJECT)
    local vb, ve = bot:GetLocation(), enemy:GetLocation()
    local dx, dy = vb.x - ve.x, vb.y - ve.y
    local m = math.max(math.sqrt(dx * dx + dy * dy), 1)
    local creep = api.MakeUnit({
        CanBeSeen = true, IsAlive = true,
        GetTeam = 3,
        GetLocation = api.Vector(ve.x + dx / m * CREEP_FROM_ENEMY,
                                 ve.y + dy / m * CREEP_FROM_ENEMY, 0),
    })
    sp.GetNearbyLaneCreeps = function() return { creep } end
    rawset(bot, 'GetNearbyLaneCreeps', nil)

    -- The engine reading the corpus does not carry ([W1]).  ACTIVITY_ATTACK is
    -- read through the mock's own auto-constant table -- the SAME number
    -- utils.lua put in meaningfulActivities -- so no enum is injected here,
    -- which would risk handing the two sides different values for one name.
    sp.GetAnimActivity = function()
        if sAnim == 'attack' then return ACTIVITY_ATTACK end
        return 0
    end
    rawset(bot, 'GetAnimActivity', nil)

    local log = {}
    sp.Action_AttackUnit = function() log[#log + 1] = 'A' end
    sp.Action_MoveToLocation = function() log[#log + 1] = 'M' end
    rawset(bot, 'Action_AttackUnit', nil)
    rawset(bot, 'Action_MoveToLocation', nil)

    J.IsSoakCandidate = function(sId) return bArmed and sId == 'creepthink' end

    dofile('bots/mode_roam_generic.lua')

    -- ⚠ ONE WORLD AT A TIME, and the guard is not decoration.  The mode file
    -- installs `GetDesire`/`Think` as GLOBALS bound to the `bot` handle of the
    -- load that ran last, and every driver's action log lives on that handle's
    -- spec.  Building two worlds and only then running them therefore drives the
    -- SECOND world twice and appends both logs to it -- which is exactly how the
    -- first cut of this file read `..........` against `AMMM...A....`: a
    -- difference that looked like the lever and was the harness.  Comparisons
    -- below must run each world to completion before the next is built, and this
    -- token makes a violation fail loudly instead of producing a plausible log.
    local tok = {}
    _G.CREEPTHINK_WORLD = tok

    local t0 = DotaTime()
    return J, bot, function(nFrames)
        assert(_G.CREEPTHINK_WORLD == tok,
            'a second world was loaded before this one was driven -- the mode '
            .. 'globals no longer belong to this bot; run each world to '
            .. 'completion before building the next')
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

local function frames_for_a_beat() return math.floor(BEAT / STEP) + 2 end

-- ---------------------------------------------------------------- world -----

tests['[W1] GetAnimActivity is a fabricated 0 on this frame'] = function()
    -- The reason the driver has to manufacture the reading at all.  Narrow
    -- version of the corpus-wide census in test_pullthink_anim_throttle.lua:
    -- if this frame ever starts carrying a real activity, the declaration stops
    -- being the only way to ask the question and this file must be re-read.
    local _, bot = rf.load(FRAME, SUBJECT)
    assert(bot:GetAnimActivity() == 0,
        'GetAnimActivity is no longer the fabricated 0 on ' .. FRAME
        .. ' -- it reads ' .. tostring(bot:GetAnimActivity()))
end

tests['[W1 control] a real activity DOES fire the throttle on this frame'] = function()
    -- Without this, every leg below could pass while measuring an inert knob.
    local J, bot = rf.load(FRAME, SUBJECT)
    local sp = rawget(bot, '__spec')
    assert(J.Utils.IsBotThinkingMeaningfulAction(bot, 1, 'roam') == false,
        'the throttle already fires on the untouched frame -- W1 is stale')
    sp.GetAnimActivity = function() return ACTIVITY_ATTACK end
    rawset(bot, 'GetAnimActivity', nil)
    local t = DotaTime()
    DotaTime = function() return t + 10 end -- past the 0.11s result cache
    assert(J.Utils.IsBotThinkingMeaningfulAction(bot, 1, 'roam') == true,
        'ACTIVITY_ATTACK does not reach meaningfulActivities -- the list '
        .. 'changed, and the defect this file describes may no longer exist')
end

tests['[W2] the frame really is a laning core with one enemy in range'] = function()
    -- If this goes red the file is driving somebody else's decision and every
    -- order log below is about nothing.
    local J, bot = rf.load(FRAME, SUBJECT)
    assert(J.IsModeTurbo(), 'the fixture no longer reads as turbo')
    assert(J.IsInLaningPhase(), 'the frame is no longer in the laning phase')
    assert(J.IsCore(bot), SUBJECT .. ' is no longer a core on this frame')
    assert(J.GetHP(bot) >= 0.5, SUBJECT .. ' is below the pull HP floor')
    assert(DotaTime() <= 6 * 60,
        'the frame is past the helper own 6:00 curfew: ' .. DotaTime())
    local te = J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
    assert(te ~= nil and #te == 1,
        'the single-enemy safety shape is gone: ' .. tostring(te and #te))
    assert(te[1]:GetUnitName() == OPPONENT,
        'the lane opponent changed to ' .. te[1]:GetUnitName())
end

-- ------------------------------------------------------- the plan is REAL ---

tests['[GH #521] the pull plan is DERIVED by shipped code, not declared'] = function()
    -- The claim this whole file rests on: the only thing handed to the shipped
    -- helper is the creep the dumper omits.  Everything that makes this a pull
    -- -- the decision, the target, the retreat point -- comes back out of
    -- J.ShouldCreepPullLane running on the real frame.
    local J, bot, run = drive('idle', false)
    run(1)
    local pull = bot.roamCreepPull
    assert(pull ~= nil,
        'GetDesire did not commit a creep pull on the bearing frame -- the '
        .. 'fixture, the helper, or IsCreepPullSafe changed; re-price with '
        .. 'tests/_creepthink_sweep.lua before touching this file')
    assert(pull.enemy:GetUnitName() == OPPONENT,
        'the aggro target is not the real lane opponent: '
        .. pull.enemy:GetUnitName())
    local vb = bot:GetLocation()
    local rx, ry = pull.retreat.x - vb.x, pull.retreat.y - vb.y
    assert(math.sqrt(rx * rx + ry * ry) > 1,
        'the retreat point is not a real displacement off the real position')
    -- and it is genuinely the creeps that unlock it, on this very frame
    local J2, bot2 = rf.load(FRAME, SUBJECT)
    assert(J2.ShouldCreepPullLane(bot2) == nil,
        'the untouched frame now carries a plan without the declared creep -- '
        .. 'the dumper grew a lane-creep field and this file must be re-read')
end

-- ------------------------------------------------------------- the defect ---

tests['[GH #521 DEFECT] a whole beat of attack animation issues NO order'] = function()
    -- The shipped tree, on the real frame, in the animation the engine actually
    -- reports: an entire cadence beat -- poke included -- issuing nothing at
    -- all, because Think returns two statements before the cadence.
    local _, _, run = drive('attack', false)
    local log = run(frames_for_a_beat())
    assert(log:match('^%.+$'),
        'expected a beat of pure silence from the shipped tree, got: ' .. log)
end

tests['[GH #521 FIX] arming creepthink restores the poke and the drag'] = function()
    local _, _, run = drive('attack', true)
    local log = run(frames_for_a_beat())
    assert(log:sub(1, 1) == 'A',
        'armed, the first frame of a live pull plan must order the aggro poke, '
        .. 'got: ' .. log)
    assert(log:find('M') ~= nil,
        'armed, the drag order is still never issued: ' .. log)
    -- The wind-up hold (promoted 'pullbeat') is still respected: no order at
    -- all for HOLD seconds after the poke, then the drag.
    local nHold = math.floor(HOLD / STEP)
    assert(log:sub(2, nHold):match('^%.+$'),
        'the wind-up hold was overwritten -- the poke is being cancelled again: '
        .. log)
    assert(log:sub(nHold + 2, nHold + 2) == 'M',
        'the drag does not start when the hold ends: ' .. log)
end

tests['[GH #521] armed under the real animation == shipped with none'] = function()
    -- The sharpest statement of what this lever does: it is not a new
    -- behaviour, it is the SHIPPED cadence with the animation stopped from
    -- eating it.  Byte-identical order logs over a full beat.
    local n = frames_for_a_beat()
    local _, _, runArmed = drive('attack', true)
    local a = runArmed(n)
    local _, _, runIdle = drive('idle', false)
    local b = runIdle(n)
    assert(a == b, 'armed-under-attack diverges from shipped-under-idle:\n  '
        .. a .. '\n  ' .. b)
end

-- ------------------------------------------------------- anti-vacuity -------

tests['[control] with the throttle silent, arming changes NOTHING'] = function()
    -- If this ever goes red, the id is reaching something other than the line
    -- it is documented to gate, and every reading above is mis-attributed.
    local n = frames_for_a_beat()
    local _, _, runOff = drive('idle', false)
    local a = runOff(n)
    local _, _, runOn = drive('idle', true)
    local b = runOn(n)
    assert(a == b,
        'arming creepthink moved a frame with the throttle already silent -- '
        .. 'it is not confined to the throttle conjunct:\n  ' .. a .. '\n  ' .. b)
end

tests['[control] no pull plan => creepthink is inert in both worlds'] = function()
    -- The shipped-game guarantee: away from a live creep pull the added
    -- conjunct is one nil compare, so an armed wave cannot differ from an
    -- unarmed one anywhere else.  Driven by REMOVING the declared creep, which
    -- is the state every real dump frame is in.
    local function run_no_creep(bArmed)
        local J, bot = rf.load(FRAME, SUBJECT)
        local sp = rawget(bot, '__spec')
        sp.GetAnimActivity = function() return ACTIVITY_ATTACK end
        rawset(bot, 'GetAnimActivity', nil)
        local log = {}
        sp.Action_AttackUnit = function() log[#log + 1] = 'A' end
        sp.Action_MoveToLocation = function() log[#log + 1] = 'M' end
        rawset(bot, 'Action_AttackUnit', nil)
        rawset(bot, 'Action_MoveToLocation', nil)
        J.IsSoakCandidate = function(sId) return bArmed and sId == 'creepthink' end
        dofile('bots/mode_roam_generic.lua')
        local t0 = DotaTime()
        for i = 0, frames_for_a_beat() - 1 do
            local now = t0 + i * STEP
            DotaTime = function() return now end -- luacheck: ignore
            local n = #log
            GetDesire()
            Think()
            if #log == n then log[#log + 1] = '.' end
        end
        assert(bot.roamCreepPull == nil,
            'a pull plan formed with no lane creeps declared')
        return table.concat(log)
    end
    assert(run_no_creep(false) == run_no_creep(true),
        'creepthink moved a frame with no creep-pull plan live')
end

-- ------------------------------------------------------------- the domain ---

local function sweep()
    local p = assert(io.popen(SWEEP, 'r'))
    local c, bDone = {}, false
    for line in p:lines() do
        local k, v = line:match('^C (%S+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        if line == 'DONE' then bDone = true end
    end
    p:close()
    assert(bDone, 'tests/_creepthink_sweep.lua did not print DONE -- every '
        .. 'count below would be a partial read')
    return c
end

tests['[domain] the corpus cannot carry this decision, and the reason is one field'] = function()
    local c = sweep()
    assert(c.live >= 1000, 'the fixture corpus shrank below 1000 hero-frames: '
        .. tostring(c.live))
    assert(c.laning_frames > 0 and c.past_curfew > 0,
        'the laning/curfew split collapsed -- the domain reading below would '
        .. 'be about a different population')

    -- REACHABILITY (GH #171): the zero is the WORLD's, not an un-run branch.
    assert(c.creeps_raise == 0 and c.creeps_nil == 0,
        'GetNearbyLaneCreeps stopped answering a table -- the zero below would '
        .. 'no longer be a measured empty wave')
    assert(c.creeps_empty + c.creeps_nil + c.creeps_nonempty + c.creeps_raise
        == c.laning_frames,
        'the reachability buckets do not partition the driven frames -- one of '
        .. 'them is being bumped outside the branch that earns it, which is '
        .. 'exactly how a forged "measured empty" would read')
    assert(c.creeps_empty == c.laning_frames and c.creeps_nonempty == 0,
        'the dumper grew lane creeps (' .. tostring(c.creeps_nonempty)
        .. ' frames) -- re-read this file: the declaration it makes may no '
        .. 'longer be necessary, and may no longer be honest')

    -- Column 1: shipped tree, frame as the dumper wrote it.
    assert(c.plan_shipped_raise == 0, 'ShouldCreepPullLane raised on the corpus')
    assert(c.plan_shipped == 0,
        'a creep-pull plan formed with no lane creeps in the dump -- the '
        .. 'helper changed shape')

    -- Column 2: the anti-vacuity control.  If this were also 0 the zero above
    -- would be uninformative -- some OTHER clause would be doing the refusing,
    -- and the declaration would be buying a plan the shipped helper rejects.
    assert(c.plan_declared_raise == 0 and c.safe_raise == 0, 'the driven columns raised')
    assert(c.plan_declared > 0,
        'declaring the one missing field unlocks NO frame -- the refusal is '
        .. 'not the creeps, and this file declares the wrong thing')
    assert(c.plan_declared_safe > 0,
        'no frame clears IsCreepPullSafe, so GetDesire would never commit a '
        .. 'plan and the bearing frame below is not representative')
    assert(c.plan_declared_safe <= c.plan_declared
        and c.plan_declared <= c.declared_driven
        and c.declared_driven <= c.laning_frames,
        'the domain columns are not nested -- one of them is counting a '
        .. 'different population')

    -- Every plan the corpus can form targets a REAL hero and moves off a REAL
    -- position: the stand-in is the wave, never the decision or the target.
    assert(c.enemy_is_real_hero == c.plan_declared,
        'a plan formed whose aggro target is not a real dumped hero: '
        .. tostring(c.enemy_is_real_hero) .. '/' .. tostring(c.plan_declared))
    assert(c.retreat_moves == c.plan_declared,
        'a plan formed whose retreat point does not move the bot')
end

return tests
