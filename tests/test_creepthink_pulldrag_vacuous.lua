-- [ratchet] [GH #349 20260831] The co-armed row `creepthink > pulldrag` is
-- VACUOUS, and it is vacuous in closed form -- not "read and judged".
--
-- ==== WHAT REDDENED, AND WHY IT IS NOT A CODE DEFECT =======================
--
-- Admitting 'creepthink' (44 -> 47, test_set.md SS CO) made
-- tests/test_coarmed_attribution_register.lua report a NEW co-armed pair:
--
--     creepthink > pulldrag
--
-- That register is deliberately over-inclusive: "nested" means the callee's
-- gated helper is called ANYWHERE in the caller's body, so one long dispatch
-- body can pair two ids whose gates never meet on a frame.  Here the caller is
-- mode_roam_generic.lua `Think`, whose body names 'pullthink', 'creepthink' and
-- 'pullcad', and the callee is `J.GetLanePullDragTarget` ('pulldrag'), called
-- once at the camp-pull branch.  The register cannot tell the three apart; this
-- file does, and the answer differs per id:
--
--   pullthink > pulldrag  REAL      (already acknowledged: the gated early
--                                    return both adds and removes frames)
--   pullcad   > pulldrag  vacuous   (acknowledged as WIDE, "judged")
--   creepthink> pulldrag  VACUOUS   this file, and by an implication, not a
--                                   judgement call
--
-- ==== THE MAIN CRITERION: TWO INDEPENDENT REASONS, BOTH CLOSED FORM ========
--
-- 'creepthink' occurs EXACTLY ONCE in bots/, as the right operand of an `and`
-- whose left operand is `bot.roamCreepPull ~= nil`:
--
--     if not (bot.roamCampPull  ~= nil and J.IsSoakCandidate('pullthink'))
--     and not (bot.roamCreepPull ~= nil and J.IsSoakCandidate('creepthink'))
--     and J.Utils.IsBotThinkingMeaningfulAction(...) then return end
--
-- Lua `and` short-circuits, so on any frame with `bot.roamCreepPull == nil` the
-- literal is not merely false -- IsSoakCandidate is never called, and the whole
-- conjunct is `not false` = true whether or not the id is armed.  Write R for
-- `bot.roamCreepPull ~= nil` and C for `bot.roamCampPull ~= nil`.  Then:
--
--   (1) CONTROL FLOW.  `J.GetLanePullDragTarget` is called inside the
--       `if C then ... return end` block, which is reached only after the
--       `if R then ... return end` block above it did NOT run.  So
--       reaching the call site implies NOT R -- from Think's own body alone,
--       with no knowledge of who writes the two fields.
--   (2) MUTUAL EXCLUSIVITY.  Independently: the two fields are written at
--       exactly three sites, all in GetDesireHelper, and every one of them
--       makes at most one of them non-nil (`roamCreepPull = pull;
--       roamCampPull = nil`, the mirror image, and `= nil, nil`).  So
--       `C => NOT R` globally, at every instant, for any caller.
--
-- Either one alone gives: at `pulldrag`'s call site, the 'creepthink' literal
-- is unreachable code.  Arming it cannot add or remove a single frame there.
-- => the pair is registered as WIDE with a reason, which is what the register
-- asks for.  It is NOT registered to make the file green: the drive below
-- would fail if the implication broke.
--
-- ==== WHY THIS IS NOT "the instrument is dead" ============================
--
-- The same drive shows all three of these on the SAME real frame:
--   * arming 'pullthink' DOES change the call count, in both animation
--     regimes and for two different mechanisms (the throttle bypass, and the
--     0.5 s wind-up hold that steals the third arm) -- so the probe can see
--     an id reach this call site;
--   * arming 'creepthink' changes NOTHING there, in either regime;
--   * arming 'creepthink' on a frame with a live CREEP pull plan DOES change
--     the order log -- so the arming is plumbed and the id is a live lever.
-- A "no difference" reading that cannot produce a difference anywhere is the
-- failure mode this triple exists to exclude.
--
-- ==== WHAT IS REAL AND WHAT IS DECLARED ===================================
--
--   REAL   every hero's position, team, level and HP on
--          f_260819_123012_dp_landed_dead -- the same frame
--          tests/test_pullthink_anim_throttle.lua drives this branch on.
--   DECLARED  bot.roamCampPull / bot.roamCreepPull (our own bookkeeping, and
--          GetDesire is not driven here -- whether a pull would be CHOSEN on
--          this frame is a different question, out of scope exactly as in
--          test_pullthink_anim_throttle.lua); the camp's neutral creeps
--          (dumps carry heroes, not creeps), placed at the real camp
--          location; and the animation reading, which no fixture can supply
--          (bot:GetAnimActivity() answers a fabricated 0 on every corpus
--          frame -- the GH #133 shape).
--
-- ==== HONEST BOUNDS =======================================================
--
--   * VACUOUS IS A STATEMENT ABOUT THIS CALL SITE, NOT ABOUT THE WAVE.  Two
--     ids armed in the same wave still share a game: 'creepthink' changes what
--     the hero does during a creep pull, which changes the game state that
--     later decides whether a camp pull is ever planned.  That DYNAMIC
--     coupling is present between any two armed ids and is not what the
--     register measures (it measures static call-site nesting, so that the
--     per-id (a) frame count can be attributed).  Nothing here licenses
--     pooling readings across the arm-string change; test_set.md SS CO.1 (ii)
--     stands unchanged, and it is about 'pullcad', not 'pulldrag'.
--   * This file does NOT re-open 'pullthink > pulldrag'.  That row is REAL and
--     stays acknowledged; the control below is the third independent
--     demonstration of it.
--   * It asserts nothing about whether any of these ids should be promoted.
--
-- ==== MUTATION RECORD (see the report for hashes and bare exit codes) =====
--
--   M1  drop `bot.roamCreepPull ~= nil and` from the creepthink conjunct
--                                                        CAUGHT [drive D1/D2]
--   M2  point the creepthink guard at bot.roamCampPull   CAUGHT [drive D1]
--   M3  delete the `return` ending the creep-pull branch CAUGHT [source S3]
--   M4  drop `bot.roamCampPull = nil` from the creep-pull plan assignment
--                                                        CAUGHT [source S2]
--   M5  the pullthink wind-up hold 0.5 -> 0.0            CAUGHT [control C2]
--   M6  invert the creepthink conjunct (drop the `not`)  CAUGHT [D2] + [C1]
--   M7  [self] make the comment stripper return its input unstripped
--                                                        CAUGHT [source S1]
--   M8  [self, scope control] kill the 'pullcad' gate  SURVIVED, correct --
--       this file makes no claim about 'pullcad'; it is covered where it
--       belongs (tests/test_pullcamp_trigger_census.lua and the pullbeat
--       fixture test).
--
-- 7 real mutations: 7 CAUGHT / 0 SURVIVED.  Restored from a FILE COPY (never
-- `git checkout`), sha256 taken before and after each mutation so "did not
-- land" is reported apart from "not caught", and every exit code read BARE.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local FRAME = 'tests/fixtures/f_260819_123012_dp_landed_dead.lua'
local SUBJECT = 'npc_dota_hero_medusa'
local CAMP = { x = 200, y = -5200 }      -- radiant easy camp (GH #117 table)
local STEP = 1 / 30                      -- engine Think rate
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

--- Install the real frame, declare one pull plan, and return a driver.
---
--- @param sAnim  'idle' (the mock's own reading) or 'attack' (the hero held in
---               its attack animation, which is what makes the throttle bite)
--- @param sArmed the single soak id to arm, or nil for the shipped default
--- @param sPlan  'camp' (declare bot.roamCampPull) or 'creep' (roamCreepPull)
--- Returns run(nFrames) -> order log string, and drags() -> how many times
--- `J.GetLanePullDragTarget` was actually called ('pulldrag''s call site).
local function drive(sAnim, sArmed, sPlan)
    local J, bot = rf.load(FRAME, SUBJECT)
    local sp = rawget(bot, '__spec')

    -- The camp's creeps: not in the dump, placed at the real camp location.
    local neutral = api.MakeUnit({
        CanBeSeen = true, IsAlive = true,
        GetLocation = api.Vector(CAMP.x, CAMP.y, 0),
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

    J.IsSoakCandidate = function(sId) return sArmed ~= nil and sId == sArmed end

    -- The probe: count the calls at 'pulldrag''s own call site.  Wrapped on the
    -- J table the mode file resolves through, so the real helper still runs.
    local nDrag = 0
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
    end, function() return nDrag end
end

local function run(sAnim, sArmed, sPlan, nFrames)
    local step, drags = drive(sAnim, sArmed, sPlan)
    local sLog = step(nFrames)
    return sLog, drags()
end

-- ==== THE DRIVE ===========================================================

tests["[drive D1] arming 'creepthink' moves no frame at pulldrag's call site"]
= function()
    for _, sAnim in ipairs({ 'idle', 'attack' }) do
        local sBase, nBase = run(sAnim, nil, 'camp', 90)
        local sCreep, nCreep = run(sAnim, 'creepthink', 'camp', 90)
        assert(nCreep == nBase, sAnim .. ': arming creepthink changed the '
            .. "count of J.GetLanePullDragTarget calls (" .. nBase .. ' -> '
            .. nCreep .. ') -- the implication `pulldrag call site => '
            .. 'roamCreepPull == nil` no longer holds, and the register row '
            .. 'is no longer vacuous')
        assert(sCreep == sBase, sAnim .. ': arming creepthink changed the '
            .. 'order log on a camp-pull frame\n  base  ' .. sBase
            .. '\n  armed ' .. sCreep)
    end
end

tests['[drive D2] the throttle regime is the one where arming can matter']
= function()
    -- Un-armed, the attack animation makes Think return before either pull
    -- branch: zero drag calls.  This is the frame population the register is
    -- worried about, and it is exactly where creepthink still does nothing.
    local _, nIdle = run('idle', nil, 'camp', 90)
    local _, nAttack = run('attack', nil, 'camp', 90)
    assert(nIdle > 0, "the idle regime never reached pulldrag's call site ("
        .. nIdle .. ' calls) -- the drive is measuring nothing')
    assert(nAttack == 0, 'the attack regime was expected to be eaten by the '
        .. 'think throttle, but reached the call site ' .. nAttack .. ' times')
    local _, nAttackCreep = run('attack', 'creepthink', 'camp', 90)
    assert(nAttackCreep == 0, 'arming creepthink bypassed the throttle on a '
        .. 'CAMP-pull frame (' .. nAttackCreep .. ' drag calls) -- its guard '
        .. 'is no longer scoped to a live creep-pull plan')
end

-- ==== CONTROLS: the probe, the log and the arming all carry signal =========

tests["[control C1] arming 'pullthink' DOES reach the call site (throttle)"]
= function()
    local _, nBase = run('attack', nil, 'camp', 90)
    local _, nPull = run('attack', 'pullthink', 'camp', 90)
    assert(nBase == 0 and nPull > 0, 'the acknowledged REAL row no longer '
        .. 'shows: pullthink armed ' .. nPull .. ' vs shipped ' .. nBase
        .. ' drag calls under the throttle')
end

tests["[control C2] arming 'pullthink' also REMOVES frames (the wind-up hold)"]
= function()
    local _, nBase = run('idle', nil, 'camp', 90)
    local _, nPull = run('idle', 'pullthink', 'camp', 90)
    assert(nPull < nBase, 'the 0.5 s wind-up hold no longer steals frames from '
        .. 'the drag arm (' .. nBase .. ' -> ' .. nPull .. ') -- this control '
        .. 'is what makes "creepthink changed nothing" a reading rather than '
        .. 'an instrument that cannot move')
end

tests["[control C3] 'creepthink' is a live lever on its OWN branch"] = function()
    local sBase, nBase = run('attack', nil, 'creep', 90)
    local sArmed, nArmed = run('attack', 'creepthink', 'creep', 90)
    assert(sArmed ~= sBase, 'arming creepthink changed nothing even on a live '
        .. 'CREEP-pull frame -- then D1 is the arming being unplumbed, not the '
        .. 'row being vacuous\n  base  ' .. sBase .. '\n  armed ' .. sArmed)
    -- ... and the frames it wins are won on the OTHER branch: the creep-pull
    -- block returns, so pulldrag's call site stays at zero on the very leg
    -- where this id is maximally live.  That is the whole claim, in one line.
    assert(nBase == 0 and nArmed == 0, 'a live creep-pull plan reached '
        .. "pulldrag's call site (shipped " .. nBase .. ', armed ' .. nArmed
        .. ') -- the two branches are no longer exclusive at run time')
end

-- ==== SOURCE: the two closed-form reasons, parsed from the tree ============

tests['[source S1] creepthink occurs once, guarded by a live creep-pull plan']
= function()
    local code = mode_code()
    assert(code:find('roamCampPull', 1, true),
        'the comment stripper ate the code as well as the prose')
    assert(not code:find('THE DEFERRED HALF ABOVE', 1, true),
        'the comment stripper is returning its input unstripped')
    local n = select(2, code:gsub("IsSoakCandidate%('creepthink'%)", ''))
    assert(n == 1, "expected exactly one 'creepthink' gate in code, found " .. n)
    assert(code:find("bot%.roamCreepPull ~= nil and J%.IsSoakCandidate%('creepthink'%)"),
        'the creepthink guard no longer short-circuits on a nil creep-pull '
        .. 'plan -- reason (1) of the vacuity argument is gone')
end

tests['[source S2] the two pull plans are never non-nil together'] = function()
    local code = mode_code()
    -- Every write to either field.  The claim is about the SET of writes, so a
    -- new one anywhere has to be read before this passes.  A write is a line
    -- that STARTS with the field(s) and assigns; that shape excludes the reads
    -- (`if bot.roamCampPull ~= nil then`, the call argument at pulldrag's site).
    local writes = {}
    for line in (code .. '\n'):gmatch('([^\n]*)\n') do
        local lhs = line:match('^%s*(bot%.roam%a-Pull[%w%s%.,]-)=%s*[^=]')
        if lhs then writes[#writes + 1] = (lhs:gsub('%s+$', '')) end
    end
    -- Three paths, five statements: each of the two plan-setting paths writes
    -- BOTH fields, and the no-plan tail clears both in one statement.
    local sSig = table.concat(writes, ' | ')
    assert(sSig == 'bot.roamCreepPull | bot.roamCampPull | bot.roamCampPull'
        .. ' | bot.roamCreepPull | bot.roamCreepPull, bot.roamCampPull',
        'the pull plans are assigned at a new place or in a new order ('
        .. #writes .. ' statement(s)):\n      '
        .. table.concat(writes, '\n      ')
        .. '\n    Re-read them before trusting the mutual-exclusivity half.')
    assert(code:find('bot%.roamCreepPull = pull%s+bot%.roamCampPull = nil'),
        'the creep-pull plan no longer nils the camp plan')
    assert(code:find('bot%.roamCampPull = vCamp%s+bot%.roamCreepPull = nil'),
        'the camp-pull plan no longer nils the creep plan')
    assert(code:find('bot%.roamCreepPull, bot%.roamCampPull = nil, nil'),
        'the no-plan path no longer clears both fields')
    -- and nothing outside this file writes them at all
    local p = assert(io.popen(
        'grep -rl "roam\\(Creep\\|Camp\\)Pull\\s*=" bots/ | sort'))
    local files = p:read('*a')
    p:close()
    assert(files == MODE_SRC .. '\n', 'the pull plan fields are now written '
        .. 'outside ' .. MODE_SRC .. ':\n' .. files)
end

tests['[source S3] the creep-pull branch returns before the camp branch']
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
    local iDrag = assert(body:find('J%.GetLanePullDragTarget%('),
        "pulldrag's call site left Think")
    assert(iDrag > iCamp, "pulldrag's call site is no longer inside the "
        .. 'camp-pull branch')
end

return tests
