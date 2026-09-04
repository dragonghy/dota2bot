-- [ratchet] [director 20260904, test_set.md §EE] Admitting 'campbind' (60 -> 61,
-- test_set.md §EC.1) lit THREE new rows in
-- tests/test_coarmed_attribution_register.lua at once:
--
--     creepthink > campbind
--     pullcad    > campbind
--     pullthink  > campbind
--
-- The register is deliberately over-inclusive -- "nested" means the callee's
-- gated helper is called ANYWHERE in the caller's body -- and all three rows
-- come from ONE caller: mode_roam_generic.lua `Think`, whose body names all
-- three outer ids.  The register cannot tell them apart.  This file does, and
-- the answer differs per row:
--
--   creepthink > campbind  VACUOUS  by the same closed-form implication that
--                                   tests/test_creepthink_pulldrag_vacuous.lua
--                                   drives for the sibling call site, DRIVEN
--                                   here at campbind's own call site
--   pullcad    > campbind  VACUOUS  and this one is an UPGRADE on the record:
--                                   the sibling row `pullcad > pulldrag` is
--                                   acknowledged as WIDE "read and judged not
--                                   to meet on a frame".  Judged, not driven.
--                                   Drive D2 below drives it.
--   pullthink  > campbind  REAL, and NOT the same shape as
--                                   `pullthink > pulldrag`: at this call site
--                                   it is MONOTONE -- it only adds frames.
--                                   See [control C2].
--
-- ==== THE READING THAT IS NEW, AND WHY IT IS THE ONE WORTH HAVING =========
--
-- `pullthink > pulldrag` is acknowledged as REAL because armed 'pullthink'
-- BOTH adds frames (the :264 gated early return stops eating camp-pull frames)
-- AND removes them (the armed :411 `elseif` steals frames from the :441 arm
-- that pulldrag's call lives in).  Both halves land on pulldrag because its
-- call site is INSIDE the branch dispatch.
--
-- campbind's call site is not.  `local hPoke = J.GetCampPullPokeTarget(...)`
-- sits ABOVE `if bCampHere ...` -- it runs on every frame that reaches the
-- camp branch at all, whichever arm then executes.  So the wind-up hold cannot
-- reach it and only the throttle half applies: at THIS call site armed
-- 'pullthink' is add-only.  [control C2] measures the two call sites side by
-- side on the same frames and asserts the contrast, so "monotone" is a reading
-- and not a paraphrase of the source.
--
-- ==== THE COUPLING THAT RUNS THE OTHER WAY (the register cannot see it) ====
--
-- The register's key is directional: `outer > inner` says the outer id's per-id
-- (a) is really `outer AND inner`.  Here the sharper confound runs BACKWARD,
-- from the inner id to the outer one, and no key in that file spells it:
--
--   armed 'campbind' can answer nil ("no visible neutral belongs to the camp we
--   planned"), and then the poke arm issues no Action_AttackUnit AND DOES NOT
--   SET bot.campPullAttackTime.  'pullthink' part two is
--   `elseif bCampHere and IsSoakCandidate('pullthink')
--    and (now - bot.campPullAttackTime) < 0.5`.  Its eligibility is a function
--   of a timestamp that armed 'campbind' can withhold.
--
-- => on the all-on leg, 'pullthink''s own (a) -- the wind-up-hold trigger count
-- -- is depressed by 'campbind' being armed beside it, on exactly the frames
-- where 'campbind' does its work.  [drive D3] drives this.  Pre-admission and
-- post-admission 'pullthink' (a) readings are not the same measurement, and
-- that is true in the direction the register does NOT print.
--
-- ==== THE nil-ARITHMETIC QUESTION, ASKED BECAUSE THE ANSWER USED TO BE FREE ==
--
-- That elseif ends with a comment: "Reaching this elseif with bCampHere implies
-- campPullAttackTime is non-nil (the branch above claims the nil case)".  Before
-- 'campbind' the poke arm ALWAYS set the timestamp, so the invariant was
-- trivial.  Armed 'campbind' breaks the "always" -- so the invariant is now
-- load-bearing rather than free, and `now - nil` is a real Lua error away.
-- It still holds, and for a reason that survives: the poke arm's own condition
-- is `campPullAttackTime == nil or now - ... > 3.0`, so a nil timestamp keeps
-- taking the FIRST arm forever and the elseif is never reached with nil.
-- [source S3] pins that shape; [drive D3] is the dynamic half -- it runs 90
-- frames in exactly the state that would raise the error.
--
-- ==== WHAT IS REAL AND WHAT IS DECLARED ===================================
--
--   REAL   every hero's position, team, level and HP on
--          f_260819_123012_dp_landed_dead -- the same frame the sibling file
--          and tests/test_pullthink_anim_throttle.lua drive this branch on.
--   DECLARED  bot.roamCampPull / bot.roamCreepPull (our own bookkeeping;
--          GetDesire is not driven here, exactly as in the sibling file), the
--          camp's neutral creeps (dumps carry heroes, not creeps) and WHERE
--          they stand relative to the plan, and the animation reading
--          (bot:GetAnimActivity() answers a fabricated 0 on every corpus
--          frame -- the GH #133 shape).
--
-- ==== HONEST BOUNDS =======================================================
--
--   * VACUOUS IS A STATEMENT ABOUT THIS CALL SITE, NOT ABOUT THE WAVE.  Two ids
--     armed in the same wave still share a game; that dynamic coupling is
--     present between any two armed ids and is not what the register measures.
--   * The offset that makes 'campbind' answer nil is DECLARED geometry, not a
--     measured frequency.  How OFTEN it answers nil in a real game is the
--     replay desk's condition (a), not this file's -- §EC.1 put the domain
--     floor at 17/449 alive-hero frames and this file does not restate it.
--   * It asserts nothing about whether any of these four ids should be
--     promoted.
--
-- ==== MUTATION RECORD (bare exit codes; restored from FILE COPIES) =========
--
--   M1  drop `bot.roamCreepPull ~= nil and` from the creepthink conjunct
--                                                          CAUGHT [drive D1]
--   M2  point the creepthink guard at bot.roamCampPull      CAUGHT [control C3]
--   M3  delete the `return` ending the creep-pull branch     CAUGHT [source S4]
--   M4  PULL_CAMP_NEUTRAL_RANGE 1200 -> 99999                CAUGHT [drive D3]
--   M5  write bot.campPullAttackTime even when the poke was withheld
--                                                            CAUGHT [drive D3]
--   M6  replace the 'pullcad' gate with `true`               CAUGHT [control C4]
--   M7  move campbind's call site INSIDE the poke arm        CAUGHT [control C2]
--   M8  [scope control] rename J.ShouldPullNeutralCamp    SURVIVED, correct --
--       GetDesire is not driven here, so who CHOOSES the plan is out of scope
--       (the plan is declared); it is covered where it belongs.
--
--   7 real mutations: 7 CAUGHT / 0 SURVIVED.  sha256 taken before and after
--   each mutation so "did not land" is reported apart from "not caught", every
--   exit code read BARE, and the restore verified with `sha256sum -c`.
--
--   ⭐ THE STAND EARNED ITS KEEP, AND NOT BY GOING RED.  M5 and M7 were first
--   caught ONLY by [source S3] and [source S2] -- the two DRIVES that this
--   file's header advertises as carrying those claims both passed on the
--   mutated tree.  D3 asserted that the poke disappears (true under M5 as
--   well: the poke was already gone) and C2 asserted that the two counts stay
--   EQUAL (true under M7 as well: the wind-up hold steals from the drag arm,
--   not the poke arm).  Each claim was rewritten to a quantity the mutation
--   actually moves -- the drag-arm count going to 0, and the poke count being
--   90 of 90 rather than one per 3 s beat -- and only then did the drives
--   catch them.  A source check standing in for a drive is precisely the
--   "matching conclusion, wrong reason" shape.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local FRAME = 'tests/fixtures/f_260819_123012_dp_landed_dead.lua'
local SUBJECT = 'npc_dota_hero_medusa'
local CAMP = { x = 200, y = -5200 }      -- radiant easy camp (GH #117 table)
local STEP = 1 / 30                      -- engine Think rate
local MODE_SRC = 'bots/mode_roam_generic.lua'

-- Far enough that the planned camp cannot claim the neutral: the helper keeps
-- only neutrals within PULL_CAMP_NEUTRAL_RANGE (1200) of the plan.
local FAR = 1500

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

--- Install the real frame, declare one pull plan, and return a driver.
---
--- @param sAnim   'idle' (the mock's own reading) or 'attack' (the hero held in
---                its attack animation, which is what makes the throttle bite)
--- @param tArmed  list of soak ids to arm (possibly empty/nil = shipped)
--- @param sPlan   'camp' (declare bot.roamCampPull) or 'creep' (roamCreepPull)
--- @param nOffset how far the visible neutral stands from the PLANNED camp;
---                0 = it belongs to the plan, FAR = it does not
--- Returns run(nFrames) -> order log string, pokes() -> how many times
--- `J.GetCampPullPokeTarget` was called (campbind's call site) and drags() ->
--- the same for `J.GetLanePullDragTarget` (the sibling site C2 compares to).
local function drive(sAnim, tArmed, sPlan, nOffset)
    local J, bot = rf.load(FRAME, SUBJECT)
    local sp = rawget(bot, '__spec')
    nOffset = nOffset or 0

    -- The camp's creeps: not in the dump, placed relative to the real camp
    -- location.  GetNearbyNeutralCreeps still returns it whatever the offset,
    -- so bCampHere is held fixed and the only thing nOffset moves is whether
    -- the neutral belongs to the PLAN -- which is campbind's whole question.
    local neutral = api.MakeUnit({
        CanBeSeen = true, IsAlive = true,
        GetLocation = api.Vector(CAMP.x + nOffset, CAMP.y, 0),
    })
    sp.GetNearbyNeutralCreeps = function() return { neutral } end
    rawset(bot, 'GetNearbyNeutralCreeps', nil)
    sp.GetNearbyLaneCreeps = function(_, _radius, bEnemy)
        if bEnemy then return { neutral } end
        return {}
    end
    rawset(bot, 'GetNearbyLaneCreeps', nil)

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

    local armed = {}
    for _, sId in ipairs(tArmed or {}) do armed[sId] = true end
    J.IsSoakCandidate = function(sId) return armed[sId] == true end

    -- The probes: wrapped on the J table the mode file resolves through, so the
    -- real helpers still run and the counts are of REAL calls, not of stubs.
    local nPoke, nDrag = 0, 0
    local fPoke = J.GetCampPullPokeTarget
    J.GetCampPullPokeTarget = function(...)
        nPoke = nPoke + 1
        return fPoke(...)
    end
    local fDrag = J.GetLanePullDragTarget
    J.GetLanePullDragTarget = function(...)
        nDrag = nDrag + 1
        return fDrag(...)
    end

    dofile(MODE_SRC)

    -- Declared AFTER the mode file is loaded: the file-scope `local bot =
    -- GetBot()` there is this same handle.
    if sPlan == 'camp' then
        bot.roamCampPull = api.Vector(CAMP.x, CAMP.y, 0)
        bot.roamCreepPull = nil
    else
        bot.roamCreepPull = api.Vector(CAMP.x, CAMP.y, 0)
        bot.roamCampPull = nil
    end

    local t0 = DotaTime()
    return function(nFrames)
        for i = 0, nFrames - 1 do
            local now = t0 + i * STEP
            DotaTime = function() return now end -- luacheck: ignore
            local n = #log
            Think()
            if #log == n then log[#log + 1] = '.' end
        end
        return table.concat(log)
    end, function() return nPoke end, function() return nDrag end
end

local function run(sAnim, tArmed, sPlan, nFrames, nOffset)
    local step, pokes, drags = drive(sAnim, tArmed, sPlan, nOffset)
    local sLog = step(nFrames)
    return sLog, pokes(), drags()
end

-- ==== THE DRIVE ===========================================================

tests["[drive D1] arming 'creepthink' moves no frame at campbind's call site"]
= function()
    for _, sAnim in ipairs({ 'idle', 'attack' }) do
        local sBase, nBase = run(sAnim, nil, 'camp', 90)
        local sArmed, nArmed = run(sAnim, { 'creepthink' }, 'camp', 90)
        assert(nArmed == nBase, sAnim .. ': arming creepthink changed the '
            .. 'count of J.GetCampPullPokeTarget calls (' .. nBase .. ' -> '
            .. nArmed .. ') -- the implication `campbind call site => '
            .. 'roamCreepPull == nil` no longer holds, and the register row '
            .. '`creepthink > campbind` is no longer vacuous')
        assert(sArmed == sBase, sAnim .. ': arming creepthink changed the '
            .. 'order log on a camp-pull frame\n  base  ' .. sBase
            .. '\n  armed ' .. sArmed)
    end
end

tests["[drive D2] arming 'pullcad' moves no frame at campbind's call site"]
= function()
    -- The sibling register row `pullcad > pulldrag` is acknowledged as WIDE and
    -- "judged not to meet on a frame".  Same geometry here -- pullcad's gate is
    -- inside the creep-pull block, which returns -- but judged is weaker than
    -- driven, and driving it costs one more call of the same harness.
    for _, sAnim in ipairs({ 'idle', 'attack' }) do
        local sBase, nBase = run(sAnim, nil, 'camp', 90)
        local sArmed, nArmed = run(sAnim, { 'pullcad' }, 'camp', 90)
        assert(nArmed == nBase, sAnim .. ': arming pullcad changed the count '
            .. 'of J.GetCampPullPokeTarget calls (' .. nBase .. ' -> '
            .. nArmed .. ') -- its gate has left the creep-pull block, or that '
            .. 'block no longer returns')
        assert(sArmed == sBase, sAnim .. ': arming pullcad changed the order '
            .. 'log on a camp-pull frame\n  base  ' .. sBase
            .. '\n  armed ' .. sArmed)
    end
end

tests["[drive D3] armed 'campbind' takes 75 of 75 frames off pullthink's arms"]
= function()
    -- The backward coupling, measured rather than described.  Both ids armed
    -- (what an all-on wave does) and the neutral placed outside the plan's
    -- reach, so campbind answers nil.  Then no Action_AttackUnit fires, so
    -- bot.campPullAttackTime is never set, so the poke arm's own
    -- `campPullAttackTime == nil` keeps claiming EVERY frame -- and neither
    -- pullthink's wind-up arm nor the drag arm below it is ever reached again.
    --
    -- The drag-arm count is the probe that says so, and it is the one a
    -- mutation can move: with the timestamp written unconditionally the poke
    -- arm releases after 3 s and the drag arm resumes, so `== 0` is a reading
    -- about the withheld timestamp and not about the branch existing.
    local sPull, _, nDragPull = run('idle', { 'pullthink' }, 'camp', 90, FAR)
    local sBoth, _, nDragBoth = run('idle', { 'pullthink', 'campbind' },
        'camp', 90, FAR)
    assert(sPull:find('A', 1, true) and nDragPull > 0, 'the pullthink-only '
        .. 'leg neither poked nor reached the drag arm (log ' .. sPull
        .. ', drag ' .. nDragPull .. ') -- D3 is measuring nothing')
    assert(not sBoth:find('A', 1, true), 'arming campbind beside pullthink '
        .. 'still poked a neutral ' .. FAR .. 'u from the planned camp ('
        .. sBoth .. ') -- the lever is not reaching the poke arm, so this '
        .. 'file cannot speak for the coupling')
    assert(nDragBoth == 0, 'armed campbind left ' .. nDragBoth .. ' of '
        .. nDragPull .. " frames on pullthink's downstream arms -- the "
        .. 'withheld timestamp no longer holds the poke arm, so the backward '
        .. "coupling in this file's header is not what happens")
    -- THE SHAPE, PINNED: on this leg the bot issues NO ORDER on any of the 90
    -- frames.  test_set.md §EC.1 ruled on exactly this and bounded it -- the
    -- selector's own window makes the plan last at most 15 s and only between
    -- DotaTime 60 and 360 -- so it is a bounded hold, not a hang.  It is
    -- pinned here because the helper's own comment says the nil answer "leaves
    -- the walk toward bot.roamCampPull from the previous frame running", and
    -- when the FIRST frame already answers nil there is no such walk to leave.
    assert(sBoth == string.rep('.', 90), 'the both-armed leg issued an order '
        .. 'somewhere (' .. sBoth .. ') -- the standing-still shape §EC.1 '
        .. 'bounded is no longer the shape, so re-read that bound')
    -- The nil-arithmetic half, dynamically: 90 frames in exactly the state
    -- ("armed campbind withheld the timestamp, pullthink is armed and asking
    -- for a window around it") that `now - nil` would raise on.  Reaching this
    -- line at all is the assertion; the source shape is [source S3].
    assert(#sBoth == 90, 'the both-armed leg did not complete 90 frames')
end

tests['[drive D4] with the neutral INSIDE the plan, campbind is a no-op']
= function()
    -- The helper's own safety claim ("armed, the poked set is a strict SUBSET
    -- of the shipped one") has a second half that must also hold: on a neutral
    -- that DOES belong to the plan, armed and shipped are the same poke.  If
    -- this fails, D3's difference could be the lever mis-firing rather than
    -- the lever working.
    local sBase = run('idle', { 'pullthink' }, 'camp', 90, 0)
    local sBoth = run('idle', { 'pullthink', 'campbind' }, 'camp', 90, 0)
    assert(sBoth == sBase, 'armed campbind changed the order log on a neutral '
        .. 'standing AT the planned camp -- the subset claim in '
        .. 'J.GetCampPullPokeTarget is false\n  base  ' .. sBase
        .. '\n  armed ' .. sBoth)
end

-- ==== CONTROLS: the probe, the log and the arming all carry signal =========

tests["[control C1] arming 'pullthink' DOES reach the call site (throttle)"]
= function()
    local _, nBase = run('attack', nil, 'camp', 90)
    local _, nPull = run('attack', { 'pullthink' }, 'camp', 90)
    assert(nBase == 0 and nPull > 0, 'the REAL row no longer shows: pullthink '
        .. 'armed ' .. nPull .. ' vs shipped ' .. nBase .. ' poke-target '
        .. 'calls under the throttle')
end

tests["[control C2] pullthink is ADD-ONLY here and NOT at pulldrag's site"]
= function()
    -- The contrast that makes `pullthink > campbind` a different row from the
    -- acknowledged `pullthink > pulldrag`, measured on the same frames.  In the
    -- idle regime the throttle does not bite, so the add half is inert and only
    -- the wind-up hold can move anything -- and it can only reach the site that
    -- lives inside the branch dispatch.
    local _, nPokeBase, nDragBase = run('idle', nil, 'camp', 90)
    local _, nPokeArm, nDragArm = run('idle', { 'pullthink' }, 'camp', 90)
    assert(nDragArm < nDragBase, "the wind-up hold no longer steals frames "
        .. "from pulldrag's arm (" .. nDragBase .. ' -> ' .. nDragArm
        .. ') -- then this control cannot show a contrast and the '
        .. 'acknowledged `pullthink > pulldrag` row needs re-reading')
    assert(nPokeArm == nPokeBase, "the wind-up hold reached campbind's call "
        .. 'site (' .. nPokeBase .. ' -> ' .. nPokeArm .. ') -- it is no '
        .. 'longer above the branch dispatch, so `pullthink > campbind` is '
        .. 'no longer monotone and the register caveat must be rewritten')
    -- EQUALITY IS NOT ENOUGH, and the mutation stand is why this line exists.
    -- Moving the call INSIDE the poke arm keeps both counts equal to each
    -- other (the wind-up hold steals from the DRAG arm, not the poke arm), so
    -- the two assertions above still pass on a tree where the monotone reading
    -- is false.  What separates the two positions is the LEVEL of the count:
    -- above the dispatch the helper is asked on every frame that reaches the
    -- camp branch; inside the poke arm it is asked once per 3 s beat.
    assert(nPokeBase == 90, "campbind's helper was asked on " .. nPokeBase
        .. ' of 90 camp-branch frames -- above the dispatch it is asked on '
        .. 'every one of them, so a smaller number means the call site moved '
        .. 'into an arm and [source S2] is the only thing still holding the '
        .. 'monotone reading up')
end

tests["[control C3] 'creepthink' is a live lever on its OWN branch"] = function()
    local sBase, nBase = run('attack', nil, 'creep', 90)
    local sArmed, nArmed = run('attack', { 'creepthink' }, 'creep', 90)
    assert(sArmed ~= sBase, 'arming creepthink changed nothing even on a live '
        .. 'CREEP-pull frame -- then D1 is the arming being unplumbed, not the '
        .. 'row being vacuous\n  base  ' .. sBase .. '\n  armed ' .. sArmed)
    assert(nBase == 0 and nArmed == 0, "a live creep-pull plan reached "
        .. "campbind's call site (shipped " .. nBase .. ', armed ' .. nArmed
        .. ') -- the two branches are no longer exclusive at run time')
end

tests["[control C4] 'pullcad' is a live lever on its OWN branch"] = function()
    -- Same argument for D2: a "no difference" reading is worth nothing unless
    -- the id can be shown to move something somewhere.
    local sBase = run('idle', nil, 'creep', 90)
    local sArmed = run('idle', { 'pullcad' }, 'creep', 90)
    assert(sArmed ~= sBase, 'arming pullcad changed nothing even on a live '
        .. 'CREEP-pull frame -- then D2 is the arming being unplumbed, not the '
        .. 'row being vacuous\n  base  ' .. sBase .. '\n  armed ' .. sArmed)
end

-- ==== SOURCE: the closed-form reasons, parsed from the tree ================

tests['[source S1] campbind is read once, above the camp branch dispatch']
= function()
    local code = mode_code()
    assert(code:find('roamCampPull', 1, true),
        'the comment stripper ate the code as well as the prose')
    assert(not code:find('POKE THE CAMP', 1, true),
        'the comment stripper is returning its input unstripped')
    local n = select(2, code:gsub('J%.GetCampPullPokeTarget%(', ''))
    assert(n == 1, 'expected exactly one J.GetCampPullPokeTarget call site in '
        .. MODE_SRC .. ', found ' .. n .. ' -- more than one and "the" call '
        .. 'site is no longer a single address, so S2 pins the wrong one')
end

tests['[source S2] the call site is ABOVE the branch dispatch (monotone)']
= function()
    local code = mode_code()
    local iThink = assert(code:find('\nfunction Think%(%)'), 'Think is gone')
    local body = code:sub(iThink)
    local iCamp = assert(body:find('\n\tif bot%.roamCampPull ~= nil then'),
        'the camp-pull branch is no longer a top-level `if` in Think')
    local iPoke = assert(body:find('J%.GetCampPullPokeTarget%('),
        "campbind's call site left Think")
    local iDispatch = assert(body:find('\n\t\tif bCampHere'),
        'the camp branch no longer opens its dispatch with `if bCampHere`')
    assert(iCamp < iPoke and iPoke < iDispatch, "campbind's call site is no "
        .. 'longer between the camp-branch test and the arm dispatch (camp '
        .. iCamp .. ', poke ' .. iPoke .. ', dispatch ' .. iDispatch
        .. ') -- the add-only reading in [control C2] assumed that position')
    -- No gate is resolved between the branch test and the call: if one were,
    -- some other id would decide whether this call happens and the monotone
    -- claim would need that id in it too.
    local head = body:sub(iCamp, iPoke)
    assert(not head:find('IsSoakCandidate', 1, true), 'a soak gate now sits '
        .. "between the camp-branch test and campbind's call site -- read it "
        .. 'before trusting the add-only reading')
end

tests['[source S3] a withheld timestamp cannot reach the pullthink window']
= function()
    local code = mode_code()
    local iThink = assert(code:find('\nfunction Think%(%)'), 'Think is gone')
    local body = code:sub(iThink)
    -- The first arm must claim the nil case, or armed campbind (which can skip
    -- `bot.campPullAttackTime = now`) leaves a nil for the pullthink elseif to
    -- do arithmetic on.
    assert(body:find('if bCampHere%s+and %(bot%.campPullAttackTime == nil or '),
        'the poke arm no longer claims the nil-timestamp case -- armed '
        .. "campbind can now withhold the timestamp and reach pullthink's "
        .. '`now - bot.campPullAttackTime` with nil')
    -- ... and the timestamp is written INSIDE the armed-campbind-can-skip
    -- branch, which is the fact that makes the invariant load-bearing at all.
    assert(body:find('if hPoke ~= nil then%s+bot:Action_AttackUnit%(hPoke, true%)'
        .. '%s+bot%.campPullAttackTime = now'),
        'the poke/timestamp pair changed shape -- re-read whether armed '
        .. 'campbind can still withhold bot.campPullAttackTime')
end

tests['[source S4] the creep-pull branch returns before the camp branch']
= function()
    local code = mode_code()
    local iThink = assert(code:find('\nfunction Think%(%)'), 'Think is gone')
    local body = code:sub(iThink)
    local iCreep = assert(body:find('\n\tif bot%.roamCreepPull ~= nil then'),
        'the creep-pull branch is no longer a top-level `if` in Think')
    local iCamp = assert(body:find('\n\tif bot%.roamCampPull ~= nil then'),
        'the camp-pull branch is no longer a top-level `if` in Think')
    assert(iCreep < iCamp, 'the camp branch now precedes the creep branch -- '
        .. 'reason (1) of the vacuity argument assumed the other order')
    local between = body:sub(iCreep, iCamp)
    assert(between:find('\n\t\treturn\n\tend'), 'the creep-pull branch no '
        .. 'longer ends in an unconditional `return` -- control flow can now '
        .. 'fall through to the camp branch with a live creep-pull plan')
    assert(between:find("IsSoakCandidate%('pullcad'%)"), "pullcad's gate left "
        .. 'the creep-pull block -- D2 assumed it was in there')
end

return tests
