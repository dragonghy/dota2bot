-- [GH #186 20260825] Soak candidate 'pullthink': THE DRAG STEP IS NEVER
-- ORDERED, and the line that eats it is not in the drag.
--
-- The replay desk read W10 frame by frame (130 games, `pullcamp` + `pulllane` +
-- `pulldrag` + `pullcad` + `campsel` all armed) and found that 31 of 73 armed
-- poke frames -- 42%, ab 48% / ba 39%, same sign -- move LESS THAN 50 u in the
-- following second.  Its bearing frame is six consecutive seconds of identical
-- coordinates on a zuus standing 45 u from the camp while its HP falls 1.00 ->
-- 0.84, with the neutral sample changing every second underneath (so the dump
-- is live; the hero is genuinely standing in the camp being eaten).  That is
-- the wave13 "a puller stood and TANKED the neutrals" fingerprint that
-- mode_roam_generic's poke/drag cadence was written to remove -- reappearing
-- after the cadence itself was fixed.
--
-- The issue asked this group one question from the code side: why does the
-- `elseif bCampHere then <500u step>` branch not produce displacement?  The
-- answer is that on those frames THE BRANCH IS NEVER REACHED.  Two lines above
-- the cadence, Think() opens with
--
--     if J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, "roam")
--     then return end
--
-- and utils.lua's `meaningfulActivities` -- the list that predicate matches
-- bot:GetAnimActivity() against -- opens with ACTIVITY_RUN and ACTIVITY_ATTACK.
-- A hero mid-attack-animation on the camp it has just poked is in
-- ACTIVITY_ATTACK by construction, and the neutrals hitting back keep it there.
-- So the throttle returns on exactly the frames the drag has to be ordered on.
--
-- ==== WHY NO TEST IN THIS REPO COULD HAVE SEEN IT: ONE FABRICATED 0 =========
--
-- W1  bot:GetAnimActivity() answers a fabricated 0 on every corpus frame -- the
--     GH #133 GetPowerTreadsStat shape, a default that is not a member of the
--     value set it is compared against, so the comparison has one answer
--     forever.
-- W2  and the list is NOT the second lock, which is the part worth writing
--     down.  The mock auto-defines every unknown ALL_CAPS global to a distinct
--     id (bot_api's _G __index, counter seeded at 1000), so
--     `meaningfulActivities` is fully POPULATED under the mock -- with sixteen
--     fabricated ids, none of which can ever be 0.  W1 is therefore the SOLE
--     reason this predicate is dead locally, and it is dead at all NINE of its
--     call sites: mode_roam / mode_farm / mode_ward / mode_outpost /
--     mode_secret_shop / mode_side_shop / mode_team_roam plus aba_defend and
--     aba_push.  One fabricated number holds the first two lines of most of
--     this repo's mode Thinks permanently open in every test we own.
--
-- That is why tests/test_replay_pullbeat_attack_cancel.lua can drive this very
-- Think over 46 frames and never once meet the throttle.  Both facts are
-- asserted below, because this file has to MANUFACTURE the engine's reading to
-- make the defect visible at all -- and an assertion that stopped being true
-- would mean the manufacture, not the defect, is what it is measuring.
--
-- ==== WHAT IS REAL ON THE FRAME, AND WHAT IS DECLARED ======================
--
--   REAL   medusa's position (181, -4846), her team, and every other hero on
--          frame 20260819_123012 -- a radiant hero standing 355 u from the
--          radiant easy camp (200, -5200), the closest own-side camp approach in
--          the whole 104-fixture corpus (measured over every alive hero in every
--          fixture against the four camps the engine actually pulls from).  The
--          fountain the shipped drag walks toward is the real one
--          (J.GetTeamFountain), because 'pulldrag' is NOT armed anywhere in this
--          file: the drag destination is deliberately the SHIPPED one, so
--          nothing here rests on GetLocationAlongLane, which is a mock constant
--          Vector(0,0,0).
--   DECLARED  bot.roamCampPull.  That is OUR OWN bookkeeping, not an engine
--          getter -- GetDesire writes it and Think reads it -- so setting it
--          declares "a pull plan is live", which is this file's precondition,
--          not a thing it measures.  Same licence
--          tests/test_pulldrag_lane_step.lua takes, for the same reason.
--   DECLARED  the camp's neutral creeps.  GetNearbyCreeps answers {} on every
--          fixture and no fixture carries a creeps key (asserted in
--          tests/test_campfarm_ancient_target.lua W1); the dumper writes heroes.
--          A stand-in unit is placed AT the real camp.
--   DECLARED  the anim activity, which is the whole point -- see W1.  It is
--          declared as a constant per world ('idle' or 'attack'), not as a
--          timeline: 'attack' models the 42% population the desk photographed,
--          a hero that never leaves the attack animation because the camp keeps
--          hitting it, and 'idle' models the mock's own reading.
--
-- HONEST LIMIT: this file cannot show that the restored drag CONNECTS the camp
-- to the wave.  That is a wave question and GH #186 pre-registers it as one
-- (< 15% still-frames, both strata, with `pulldrag`'s lane_win share not
-- falling).  What is settled locally is the thing that question rests on:
-- whether a move order is issued at all.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local FRAME = 'tests/fixtures/f_260819_123012_dp_landed_dead.lua'
local SUBJECT = 'npc_dota_hero_medusa'
local CAMP = { x = 200, y = -5200 }      -- radiant easy camp (GH #117 table)
local STEP = 1 / 30                      -- engine Think rate
local BEAT = 3.0                         -- the cadence's poke interval
local HOLD = 0.5                         -- the wind-up hold, shipped on the creep side

--- Install the real frame, declare the pull plan and the camp's creeps, and
--- return a driver that runs N engine frames and answers the order log:
---   'A' Action_AttackUnit   'M' Action_MoveToLocation   '.' no order at all
---
--- sAnim is 'idle' (the mock's own reading -- W1) or 'attack' (the hero the
--- replay desk photographed, held in its attack animation by the camp).
local function drive(sAnim, bArmed)
    local J, bot = rf.load(FRAME, SUBJECT)
    local sp = rawget(bot, '__spec')

    -- The camp's creeps: not in the dump, placed at the real camp location.
    local neutral = api.MakeUnit({
        CanBeSeen = true, IsAlive = true,
        GetLocation = api.Vector(CAMP.x, CAMP.y, 0),
    })
    sp.GetNearbyNeutralCreeps = function() return { neutral } end
    rawset(bot, 'GetNearbyNeutralCreeps', nil)

    -- The engine reading the corpus does not carry (W1).  ACTIVITY_ATTACK is
    -- read through the mock's own auto-constant table (W2), i.e. the SAME
    -- number utils.lua put in meaningfulActivities -- no enum is injected here,
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

    J.IsSoakCandidate = function(sId) return bArmed and sId == 'pullthink' end

    dofile('bots/mode_roam_generic.lua')

    -- Declare the live pull plan AFTER the mode file is loaded: the file-scope
    -- `local bot = GetBot()` there is this same handle, and GetDesire is not
    -- driven in this file (whether a pull would be CHOSEN here is out of scope,
    -- exactly as in tests/test_pulldrag_lane_step.lua).
    bot.roamCampPull = api.Vector(CAMP.x, CAMP.y, 0)

    local t0 = DotaTime()
    return J, bot, function(nFrames)
        for i = 0, nFrames - 1 do
            local now = t0 + i * STEP
            DotaTime = function() return now end -- luacheck: ignore
            local n = #log
            Think()
            if #log == n then log[#log + 1] = '.' end
        end
        return table.concat(log)
    end
end

local function frames_for_a_beat()
    return math.floor(BEAT / STEP) + 2
end

tests['[W1] GetAnimActivity is a fabricated 0 on every corpus frame'] = function()
    -- The reason this defect is structurally invisible locally, and the reason
    -- the driver above has to manufacture the reading.  A census, not a sample:
    -- if ANY fixture ever starts carrying a real activity, this goes red and the
    -- injection stops being the only way to ask the question.
    local seen, nFrames = {}, 0
    local p = io.popen('ls tests/fixtures')
    for line in p:lines() do
        if line:match('^f_.*%.lua$') then
            local ok, _, bot = pcall(rf.load, 'tests/fixtures/' .. line)
            if ok then
                nFrames = nFrames + 1
                seen[tostring(bot:GetAnimActivity())] = true
            end
        end
    end
    p:close()
    assert(nFrames >= 100, 'the fixture corpus shrank below 100 frames: ' .. nFrames)
    local vals = {}
    for k in pairs(seen) do vals[#vals + 1] = k end
    assert(#vals == 1 and vals[1] == '0',
        'GetAnimActivity is no longer a constant 0 across ' .. nFrames
        .. ' corpus frames, it reads {' .. table.concat(vals, ', ')
        .. '} -- W1 is stale, re-read this file')
end

tests['[W2] the activity list IS populated -- 0 is what can never be in it'] = function()
    -- The correction that makes W1 load-bearing rather than one of two locks.
    -- The mock auto-defines unknown ALL_CAPS globals from a counter seeded at
    -- 1000, so every ACTIVITY_* name resolves to a real, distinct, POSITIVE
    -- number and meaningfulActivities is full.  Nothing in it can be 0, so the
    -- fabricated reading in W1 is the whole insulation -- at all nine call
    -- sites, not just this one.
    rf.load(FRAME, SUBJECT) -- installs the mock globals
    local names = {
        'ACTIVITY_RUN', 'ACTIVITY_ATTACK', 'ACTIVITY_ATTACK2',
        'ACTIVITY_ATTACK_EVENT', 'ACTIVITY_CHANNEL_ABILITY_6',
    }
    local seen = {}
    for _, k in ipairs(names) do
        local v = _G[k]
        assert(type(v) == 'number' and v > 0,
            k .. ' is not an auto-defined positive constant under the mock ('
            .. tostring(v) .. ') -- W2 is stale')
        assert(seen[v] == nil, k .. ' collides with ' .. tostring(seen[v]))
        seen[v] = k
    end
end

tests['[W1/W2 control] a real activity DOES fire the throttle'] = function()
    -- The control for the two assertions above: if handing the predicate an
    -- ACTIVITY_* did NOT flip it, every leg below would be measuring an inert
    -- knob and would pass for the wrong reason.
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

tests['[GH #186] the frame really does sit at the camp'] = function()
    -- If this goes red the file is measuring a hero standing somewhere else and
    -- every "the drag did not move" reading below is about nothing.
    local _, bot = rf.load(FRAME, SUBJECT)
    local v = bot:GetLocation()
    local d = math.sqrt((v.x - CAMP.x) ^ 2 + (v.y - CAMP.y) ^ 2)
    assert(d < 400, SUBJECT .. ' is ' .. math.floor(d) .. 'u from the camp, not '
        .. 'the ~355u the file was pinned on')
    assert(bot:GetTeam() == 2, 'the subject is no longer the radiant hero whose '
        .. 'own-side camp this is')
end

tests['[GH #186 DEFECT] a whole beat of attack animation issues NO order'] = function()
    -- The defect, on the real frame, in one line: the shipped cadence spends an
    -- entire 3s beat -- poke included -- issuing nothing at all, because Think
    -- returns two lines before the cadence.  This is what 42% of the desk's poke
    -- frames are.
    local _, _, run = drive('attack', false)
    local n = frames_for_a_beat()
    local log = run(n)
    assert(not log:find('M', 1, true),
        'the shipped drag issued a move order while the hero was in its attack '
        .. 'animation -- the GH #186 defect is gone and this file is stale: ' .. log)
    assert(not log:find('A', 1, true),
        'the shipped cadence poked while throttled, which it cannot do: ' .. log)
    assert(log == string.rep('.', n),
        'expected every frame of the beat to be held by the throttle, got ' .. log)
end

tests['[GH #186 FIX] armed, the same beat pokes, holds the wind-up, then drags'] = function()
    local _, _, run = drive('attack', true)
    local nFrames = frames_for_a_beat()
    local log = run(nFrames)
    assert(log:sub(1, 1) == 'A',
        'the armed beat no longer opens with the poke: ' .. log)
    assert(log:sub(-1) == 'A',
        'the next beat no longer lands after ' .. BEAT .. 's: ' .. log)
    local nMoves = select(2, log:gsub('M', ''))
    assert(nMoves > 0, 'armed, the drag STILL issues no move order -- the fix '
        .. 'does not reach the cadence: ' .. log)
    -- The hold: the frames right after the poke must issue nothing, or the move
    -- cancels an attack whose wind-up has not started (GH #143).
    local nHeld = math.floor(HOLD / STEP)
    assert(log:sub(2, nHeld) == string.rep('.', nHeld - 1),
        'the wind-up hold is missing or the wrong length -- a move order lands '
        .. 'inside the first ' .. HOLD .. 's: ' .. log)
    assert(log:sub(nHeld + 1, nHeld + 1) == 'M',
        'the drag does not resume the frame the hold ends: ' .. log)
    assert(nMoves == nFrames - nHeld - 1,
        'the drag does not own the rest of the beat: ' .. log)
end

tests['[GH #186] the fix is scoped to a live camp-pull plan'] = function()
    -- Armed but with no pull plan, the throttle must be asked exactly as
    -- shipped.  Without this, 'pullthink' would be a global "ignore ThinkLess"
    -- switch rather than a pull fix, and its wave reading would carry every
    -- other roam behaviour with it.
    local J, bot = rf.load(FRAME, SUBJECT)
    local sp = rawget(bot, '__spec')
    sp.GetAnimActivity = function() return ACTIVITY_ATTACK end
    rawset(bot, 'GetAnimActivity', nil)
    local log = rf.record_actions(bot)
    J.IsSoakCandidate = function(sId) return sId == 'pullthink' end
    dofile('bots/mode_roam_generic.lua')
    bot.roamCampPull = nil
    Think()
    assert(#log == 0, 'armed with no pull plan, roam still acted through the '
        .. 'throttle: ' .. #log .. ' order(s)')
end

tests['[unarmed identity] no anim, no arm: the shipped cadence, unchanged'] = function()
    -- The inert leg.  Unarmed and with the mock's own anim reading, the cadence
    -- must be exactly what it has always been: the poke, then a move order on
    -- every remaining frame of the beat, with NO held frame anywhere -- the
    -- shipped camp branch has no wind-up hold and this fix does not give it one
    -- unless armed.
    local _, _, run = drive('idle', false)
    local nFrames = frames_for_a_beat()
    local log = run(nFrames)
    assert(log:sub(1, 1) == 'A',
        'the shipped beat no longer opens with the poke: ' .. log)
    assert(not log:find('%.'),
        'an unarmed frame issued no order -- the hold leaked out of the gate: ' .. log)
    assert(log == 'A' .. string.rep('M', nFrames - 2) .. 'A',
        'the shipped cadence changed: ' .. log)
end

tests['[unarmed identity] armed changes nothing while the hero is not attacking'] = function()
    -- The other side of the same coin, and the reason the wave reading is
    -- attributable: the ONLY frames this lever can change are the ones the
    -- throttle was eating.  Anywhere else, armed and unarmed print the same log.
    -- Each leg is driven to completion BEFORE the next is built: `Think` is a
    -- global that dofile rebinds, so two live drivers would both run the
    -- second file's Think and one log would silently collect both legs.
    local n = frames_for_a_beat()
    local armed = select(3, drive('idle', true))(n)
    local base = select(3, drive('idle', false))(n)
    local nHeld = math.floor(HOLD / STEP)
    -- Armed still adds the wind-up hold, which is deliberate and is the ONLY
    -- difference; spelled out rather than asserted as equality so a change to
    -- either half cannot hide inside the other.
    assert(base == 'A' .. string.rep('M', n - 2) .. 'A', 'shipped leg moved: ' .. base)
    assert(armed == 'A' .. string.rep('.', nHeld - 1)
        .. string.rep('M', n - nHeld - 1) .. 'A',
        'armed leg differs from shipped by something other than the hold: ' .. armed)
end

tests['[source] both halves of the fix read ONE id'] = function()
    -- The pullcad trap, pinned.  A gate written as `IsSoakCandidate('pullthink')
    -- and IsSoakCandidate('pullbeat')` would freeze FALSE the moment 'pullbeat'
    -- is promoted -- and it already is (2026-08-23), so that spelling would be
    -- dead on arrival while check_armed_wiring.py still called it WIRED.
    local fh = assert(io.open('bots/mode_roam_generic.lua', 'r'))
    local src = fh:read('*a')
    fh:close()
    local code = src:gsub('%-%-[^\n]*', '') -- prose is not code (0DEAD judgement 1)
    assert(code:find('roamCampPull', 1, true),
        'the comment stripper ate the code as well as the prose')
    local n = select(2, code:gsub("IsSoakCandidate%('pullthink'%)", ''))
    assert(n == 2, "expected exactly two 'pullthink' gates in code (the throttle "
        .. 'bypass and the wind-up hold), found ' .. n)
    assert(not code:find("IsSoakCandidate%('pullthink'%)%s*and%s*J%.IsSoakCandidate"),
        'a pullthink gate was conjoined with another candidate id -- that is '
        .. 'frozen FALSE the day the other id is promoted')
    assert(code:find("bot%.roamCampPull ~= nil and J%.IsSoakCandidate%('pullthink'%)"),
        'the throttle bypass no longer requires a live camp-pull plan')
end

return tests
