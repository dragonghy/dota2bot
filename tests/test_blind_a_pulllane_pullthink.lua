-- BLIND-A: can condition (a) be BOUGHT for 'pulllane' and 'pullthink'?
-- Director ruling 2026-09-09, test_set.md §GF.  Same question as §GC
-- (wandlimbo/tpdead), §GD (cmrguard) and §GE (roamidle/campsel), asked of the
-- LAST two `narrat=1` ids in tools/agent/verify_coverage.py.
--
-- (a) is "the fix really executes in a real game, and its decision is right".
-- It is NOT "given this input, is the decision right" -- that is what each id's
-- existing GREEN test answers, and both of those write the pivotal input
-- themselves (test_pullthink_anim_throttle.lua injects the activity and says so
-- in its own header; the pulllane clause is exercised with a hand-built path).
-- This file measures the OTHER half: does the input ever reach the decision
-- from a real frame?
--
-- Readings quoted below come from tests/_blind_a_pulllane_pullthink_sweep.lua
-- over all 110 fixtures / 1100 alive-or-dead hero handles.
--
-- ============================================================================
-- ⭐⭐⭐ THE MAIN AXIS: THE SAME LOADER HOLDS BOTH FAILURE MODES, AND ONLY
--     ONE OF THEM RAISES A HAND.
-- ============================================================================
-- Two inputs are missing from the corpus.  The loader treats them oppositely:
--
--   GetLaneFrontLocation  -- REFUSES, loudly, by name:
--       "LOADER REFUSES: GetLaneFrontLocation is unresolved (GH #61). The dump
--        does not carry lane fronts; do not compare against (0,0,0). Declare
--        your assumption in the test with `GetLaneFrontLocation = ...`"
--
--   GetAnimActivity       -- ANSWERS 0, silently, via bot_api.lua's `^Get -> 0`
--       catch-all.  1100/1100 handles read 0; 0 is no ACTIVITY_* the engine
--       sends, so the throttle is false on every frame and armed 'pullthink'
--       is a no-op that no counter would report.
--
-- Same loader, same class of absent datum, opposite failure direction.  The
-- refusing form is the CURE and it is already implemented -- three rounds
-- running (§GD.5 AbilityDamage beside AbilityCastRange, §GE.3 GetItemSlotType
-- beside GetCurrentActionType, and now this) the finding has been "a fix that
-- was never generalised".  This round it is not a sibling getter that was
-- missed but a whole POLICY the loader applies to one getter and not the rest.
--
-- ============================================================================
-- 'pulllane' -- THE CLAUSE IS NEVER REACHED, AND NOT FOR THE OBVIOUS REASON
-- ============================================================================
-- The lever is the third clause of J.ShouldPullNeutralCamp's camp loop:
-- `J.IsCampBesideLane( camp.location, tLanePath )`, with tLanePath built from
-- 21 GetLocationAlongLane samples when 'pulllane' is armed.
--
-- ⚠️ THE FIRST HYPOTHESIS WAS WRONG, AND A POSITIVE CONTROL IS WHAT SAID SO.
-- GetNeutralSpawners() is `{}` on 110/110 frames (0 camp handles), so "the camp
-- roster is the wall" is the reading that suggests itself -- and it is the same
-- wall §GE ruled campsel on.  It is not the binding one here: arming the gates,
-- forcing turbo AND supplying a synthetic own-team camp 600u from the bot moved
-- the reading NOT AT ALL (non-nil 0/1100, and J.IsCampBesideLane reached 0
-- times).  Something earlier stops every frame.
--
-- Attribution over all 1100 handles -- where each one actually stops:
--     dead            79      \
--     IsCore         929       |  honest DOMAIN filters: the lever is a pos-4/5
--     time window     67       |  laning-phase support lever, and the corpus is
--     :12/:42 mark    14       |  mostly cores, mostly outside 60-360s
--     enemy within 800 2      /
--     nLane == nil     0      <- GH #648's point, confirmed: the engine answers
--                                LANE_NONE == 0, so that guard cannot fire
--     reached lane front 9    <- and on ALL NINE the loader REFUSES
--
-- So the corpus contains exactly NINE frames on which the question can even be
-- put, and the instrument declines to answer on all nine.  (a) is unbuyable --
-- but the honest statement is "the lane front is not in the dump", not "there
-- are no camps".  The 9 is also the useful number for whoever buys it: this is
-- a small, targeted purchase, not a corpus-wide one.
--
-- ============================================================================
-- 'pullthink' -- BOTH OPERANDS ARE DEAD, AND ITS OWN COMMENT HAS DECAYED
-- ============================================================================
-- The gate is a conjunction:
--     bot.roamCampPull ~= nil  and  J.IsSoakCandidate('pullthink')
-- guarding whether J.Utils.IsBotThinkingMeaningfulAction's early return is
-- skipped.  For the armed leg to differ from the baseline leg BOTH must hold,
-- and the corpus kills each independently:
--
--   scope operand -- bot.roamCampPull is set from J.ShouldPullNeutralCamp,
--       which returns nil on 1100/1100 handles even fully armed and in turbo,
--       for the 'pulllane' reason above.  Unreachable.
--   throttle operand -- IsBotThinkingMeaningfulAction is FALSE on 1100/1100.
--       When it is false the baseline leg does not return early either, so the
--       two legs are byte-identical on every frame of the corpus.
--
-- ⭐⭐ AND THE SOURCE COMMENT'S OWN REASON HAS EXPIRED UNDER IT.
-- mode_roam_generic.lua:210-211 states, verbatim, that
--     "ACTIVITY_* are undefined globals under the mock, so utils.lua builds
--      meaningfulActivities as an EMPTY table"
-- and offers that as the SECOND of "two independent reasons this line reads
-- false locally".  Measured, that is now false: api.install auto-resolves
-- unknown ALL_CAPS to sentinels >= 1001, so ACTIVITY_RUN = 1153, ACTIVITY_ATTACK
-- = 1154, and the table is FULL.  [2c] proves it the only way that settles it --
-- inject a real sentinel and the throttle flips to TRUE.
--
-- The comment's CONCLUSION survives; one of its two stated reasons does not.
-- That is evidence-discipline rule 4 in the wild (a right answer resting on a
-- reason that has since stopped being true) and it matters practically: with
-- the table full, GetAnimActivity is a getter the loader COULD serve, which
-- makes 'pullthink's throttle operand the cheapest of the four instrument gaps
-- these four rulings have found -- no dumper change at all.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  Neither id is REJECTED and neither lever
-- is said to be wrong.  Both keep their logical case (c) -- GH #117's drag
-- measurement for 'pulllane', GH #186's 42%-of-poke-frames reading for
-- 'pullthink'.  The finding is about the INSTRUMENT.  Retiring them from the
-- armed set frees two slots against owner P4.2's `armed <= 20` and costs no
-- behaviour: [3c] pins `bots/` zero-diff.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local tests = {}

local F = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'

local function read_file(sPath)
    local f = io.open(sPath)
    assert(f, 'missing file: ' .. sPath)
    local s = f:read('*a')
    f:close()
    return s
end

--- Blank whole-line Lua comments while preserving line numbering, so a count
--- means "in code", not "anywhere in the file" -- the doc comment above each
--- fix quotes the very lines being counted.
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local function corpus()
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local files = {}
    for l in p:lines() do files[#files + 1] = l end
    p:close()
    return files
end

-- ===========================================================================
-- [1] 'pulllane' -- the pivot is never reached from a real frame
-- ===========================================================================

tests['[1a] GetNeutralSpawners is empty on every corpus frame'] = function()
    local nFrames, nEmpty, nHandles = 0, 0, 0
    for _, f in ipairs(corpus()) do
        local ok, J = pcall(rf.load, f)
        if ok and J ~= nil then
            nFrames = nFrames + 1
            local t = GetNeutralSpawners()
            local n = 0
            if type(t) == 'table' then for _ in pairs(t) do n = n + 1 end end
            nHandles = nHandles + n
            if n == 0 then nEmpty = nEmpty + 1 end
        end
    end
    cs.corpus(nFrames, 'blind-a pulllane frames')
    -- "all of them", not "all 110 of them": strictly stronger, and it keeps
    -- holding over the fixtures nobody has written yet (GH #106 / #127).
    cs.universal(nEmpty, nFrames, 'frames with an empty camp roster')
    assert(nHandles == 0,
        'GetNeutralSpawners now serves camps (' .. nHandles .. ' handle(s)) -- '
        .. 'the camp half of §GF may be buyable; re-derive the ruling')
end

tests['[1b] the lane path is one constant point, not a path'] = function()
    local J = select(2, pcall(rf.load, F))
    assert(J ~= nil)
    local seen, nSamples = {}, 0
    for _, nLane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        for k = 0, 20 do
            local v = GetLocationAlongLane(nLane, k / 20)
            if v ~= nil then
                nSamples = nSamples + 1
                seen[v.x .. ',' .. v.y] = true
            end
        end
    end
    local nDistinct = 0
    for _ in pairs(seen) do nDistinct = nDistinct + 1 end
    assert(nSamples == 63, 'expected 21 samples x 3 lanes, got ' .. nSamples)
    assert(nDistinct == 1 and seen['0,0'],
        'GetLocationAlongLane now varies -- tLanePath would be a real path and '
        .. "'pulllane' could be measurable; re-derive §GF")
end

tests['[1c] POSITIVE CONTROL: supplying a camp does NOT reach the clause'] = function()
    local J, bot = rf.load(F)
    local realSoak, realTurbo = J.IsSoakCandidate, J.IsModeTurbo
    local realSpawn, realBeside = _G.GetNeutralSpawners, J.IsCampBesideLane
    local nBeside = 0
    local v = bot:GetLocation()

    J.IsSoakCandidate = function(sId)
        return sId == 'pullcamp' or sId == 'pulllane' or sId == 'pullthink'
    end
    J.IsModeTurbo = function() return true end
    _G.GetNeutralSpawners = function()
        return { { team = bot:GetTeam(), location = { x = v.x + 600, y = v.y, z = 0 } } }
    end
    J.IsCampBesideLane = function(a, b) nBeside = nBeside + 1; return realBeside(a, b) end

    local ok, res = pcall(J.ShouldPullNeutralCamp, bot)

    J.IsSoakCandidate, J.IsModeTurbo = realSoak, realTurbo
    _G.GetNeutralSpawners, J.IsCampBesideLane = realSpawn, realBeside

    -- The point of the control: had the empty roster been the binding wall,
    -- filling it would have driven the loop and called the clause.
    assert(nBeside == 0,
        "the 'pulllane' clause is now reachable with a camp supplied -- the "
        .. 'binding wall moved; §GF must be re-derived')
    assert(not ok or res == nil,
        'ShouldPullNeutralCamp now returns a plan on this frame')
end

tests['[1d] the binding wall is the loader REFUSING the lane front'] = function()
    local J, bot = rf.load(F)
    local ok, err = pcall(GetLaneFrontLocation, bot:GetTeam(), 1, 0)
    assert(not ok, 'GetLaneFrontLocation now answers -- the 9 candidate frames '
        .. "of §GF are answerable and 'pulllane' may be re-admittable")
    err = tostring(err)
    assert(err:find('LOADER REFUSES', 1, true) and err:find('GH #61', 1, true),
        'the loader stopped naming its refusal: ' .. err)
end

tests['[1e] exactly 9 corpus frames survive every domain filter'] = function()
    -- ⚠️ THIS ASSERTION IS DRIVEN, NOT TRANSCRIBED, AND THAT IS THE POINT.
    -- The first cut re-implemented the helper's five domain filters inline and
    -- counted the survivors.  It was GREEN through a mutant that widened the
    -- helper's own pull window 6min -> 12min (M8): a transcribed domain cannot
    -- notice the domain moving, so the "9" it defended was a number about the
    -- TEST, not about the helper.  Driving the real helper and counting the
    -- frames that reach the loader's refusal measures the same quantity with
    -- nothing transcribed -- and it is the quantity §GF quotes, because
    -- reaching the refusal IS surviving every filter.
    local nRefused, nOther, nNonNil = 0, 0, 0
    for _, f in ipairs(corpus()) do
        local ok, J, _, heroes = pcall(rf.load, f)
        if ok and J ~= nil and heroes ~= nil then
            local realSoak, realTurbo = J.IsSoakCandidate, J.IsModeTurbo
            J.IsSoakCandidate = function(sId)
                return sId == 'pullcamp' or sId == 'pulllane' or sId == 'pullthink'
            end
            J.IsModeTurbo = function() return true end
            for _, h in pairs(heroes) do
                local okP, res = pcall(J.ShouldPullNeutralCamp, h)
                if okP then
                    if res ~= nil then nNonNil = nNonNil + 1 end
                elseif tostring(res):find('LOADER REFUSES', 1, true) then
                    nRefused = nRefused + 1
                else
                    nOther = nOther + 1
                end
            end
            J.IsSoakCandidate, J.IsModeTurbo = realSoak, realTurbo
        end
    end
    assert(nOther == 0, nOther .. ' handle(s) failed for a reason that is not '
        .. "the loader's refusal -- §GF's attribution is incomplete")
    assert(nNonNil == 0, 'ShouldPullNeutralCamp now returns a plan')
    -- Pinned on BOTH sides on purpose: M8 widened the helper's own pull window
    -- and drove this number UP, so a one-sided ratchet would not have caught
    -- the domain moving.  9 is not the corpus size, so it is not the GH #106
    -- coupling -- it is the size of the purchase §GF quotes.
    assert(nRefused == 9,
        'the candidate-frame count moved from 9 to ' .. nRefused
        .. ' -- §GF quotes 9 as the size of the purchase; re-derive it')
end

tests['[1f] GH #648: GetAssignedLane answers a number, never nil'] = function()
    local nNil, nHandles = 0, 0
    for _, f in ipairs(corpus()) do
        local ok, J, _, heroes = pcall(rf.load, f)
        if ok and J ~= nil and heroes ~= nil then
            for _, h in pairs(heroes) do
                nHandles = nHandles + 1
                if h:GetAssignedLane() == nil then nNil = nNil + 1 end
            end
        end
    end
    cs.ratchet(nHandles, 1100, 'GetAssignedLane reads')
    assert(nNil == 0,
        'GetAssignedLane now answers nil on ' .. nNil .. ' handle(s) -- the '
        .. "`nLane == nil` guard GH #648 calls unreachable can now fire")
end

-- ===========================================================================
-- [2] 'pullthink' -- both operands are dead, and one stated reason is stale
-- ===========================================================================

tests['[2a] the throttle it skips is false on every corpus frame'] = function()
    local nTrue, nFalse = 0, 0
    for _, f in ipairs(corpus()) do
        local ok, J, _, heroes = pcall(rf.load, f)
        if ok and J ~= nil and heroes ~= nil then
            for _, h in pairs(heroes) do
                if J.Utils.IsBotThinkingMeaningfulAction(h, 0, 'roam') then
                    nTrue = nTrue + 1
                else
                    nFalse = nFalse + 1
                end
            end
        end
    end
    cs.ratchet(nTrue + nFalse, 1100, 'throttle reads taken')
    cs.universal(nFalse, nTrue + nFalse, 'handles where the throttle is false')
    assert(nTrue == 0,
        'IsBotThinkingMeaningfulAction now reads true on ' .. nTrue
        .. " frame(s) -- 'pullthink's throttle operand became measurable")
end

tests['[2b] GetAnimActivity is the catch-all zero, on all 1100 handles'] = function()
    local nZero, nCalls = 0, 0
    for _, f in ipairs(corpus()) do
        local ok, J, _, heroes = pcall(rf.load, f)
        if ok and J ~= nil and heroes ~= nil then
            for _, h in pairs(heroes) do
                nCalls = nCalls + 1
                if h:GetAnimActivity() == 0 then nZero = nZero + 1 end
            end
        end
    end
    cs.ratchet(nCalls, 1100, 'GetAnimActivity calls')
    cs.universal(nZero, nCalls, 'handles reading the catch-all zero')
    -- and the loader still does not spec it
    local mock = codeOnly(read_file('tests/mock/replay_fixture.lua'))
    assert(not mock:find('GetAnimActivity', 1, true),
        'the loader now serves GetAnimActivity -- the gap §GF is about was '
        .. "closed; 'pullthink' may be re-admittable")
end

tests['[2c] STALE REASON: meaningfulActivities is NOT empty'] = function()
    local J, bot = rf.load(F)
    -- The comment's own claim, restated as a test: if the table were empty,
    -- NO value could make the throttle true.  A real sentinel does.
    assert(ACTIVITY_ATTACK ~= nil and ACTIVITY_ATTACK >= 1001,
        'ACTIVITY_ATTACK is no longer an auto-resolved sentinel')
    local spec = rawget(bot, '__spec')
    spec.GetAnimActivity = ACTIVITY_ATTACK
    rawset(bot, 'GetAnimActivity', nil)
    assert(J.Utils.IsBotThinkingMeaningfulAction(bot, 0, 'blind_a_2c') == true,
        'injecting ACTIVITY_ATTACK no longer makes the throttle true -- the '
        .. 'table really is empty now and §GF.2 is wrong')

    -- The claim that decayed, still present in the source, so this test goes
    -- red the day someone repairs the comment (which is the point).
    local mode = read_file('bots/mode_roam_generic.lua')
    assert(mode:find('builds meaningfulActivities as an EMPTY table', 1, true),
        'the stale comment was repaired -- retire this assertion with §GF.2')
end

tests['[2d] the scope operand is unreachable even fully armed'] = function()
    local nNonNil, nHandles = 0, 0
    for _, f in ipairs(corpus()) do
        local ok, J, _, heroes = pcall(rf.load, f)
        if ok and J ~= nil and heroes ~= nil then
            local realSoak, realTurbo = J.IsSoakCandidate, J.IsModeTurbo
            J.IsSoakCandidate = function(sId)
                return sId == 'pullcamp' or sId == 'pulllane' or sId == 'pullthink'
            end
            J.IsModeTurbo = function() return true end
            for _, h in pairs(heroes) do
                nHandles = nHandles + 1
                local okP, plan = pcall(J.ShouldPullNeutralCamp, h)
                if okP and plan ~= nil then nNonNil = nNonNil + 1 end
            end
            J.IsSoakCandidate, J.IsModeTurbo = realSoak, realTurbo
        end
    end
    cs.ratchet(nHandles, 1100, 'hero handles swept')
    assert(nNonNil == 0,
        'ShouldPullNeutralCamp now returns a plan on ' .. nNonNil
        .. " frame(s) -- 'pullthink's scope operand became reachable")
end

-- ===========================================================================
-- [3] the ruling's own guard rails
-- ===========================================================================

tests['[3a] both ids still have exactly the call sites §GF assumed'] = function()
    local jmz  = codeOnly(read_file('bots/FunLib/jmz_func.lua'))
    local mode = codeOnly(read_file('bots/mode_roam_generic.lua'))

    -- ⚠️ 'pulllane's gate is written WITH SPACES inside the parens.  A grep for
    -- the spaceless form reads back "no call site" and would retire a live
    -- lever as dead -- the 2026-09-09 round walked into exactly that.
    assert(jmz:find("J.IsSoakCandidate( 'pulllane' )", 1, true),
        "the 'pulllane' gate moved or changed spelling")
    assert(select(2, jmz:gsub("IsSoakCandidate%(%s*'pulllane'%s*%)", '')) == 1,
        "'pulllane' gained a second call site; §GF assumed exactly one")

    assert(select(2, mode:gsub("IsSoakCandidate%(%s*'pullthink'%s*%)", '')) == 2,
        "'pullthink' no longer has exactly the two call sites §GF assumed "
        .. '(the throttle skip and the wind-up hold are ONE id by design)')
end

tests['[3b] pullcad trap: no promote atom names either id'] = function()
    local atoms = read_file('iterations/promote_atoms.json')
    for _, id in ipairs({ 'pulllane', 'pullthink' }) do
        assert(not atoms:find(id, 1, true),
            'promote_atoms.json now names ' .. id .. ' -- retiring it could '
            .. 'freeze another lever (the pullcad trap); resolve before ruling')
    end
end

tests['[3c] REVERSE: gates, helpers and call sites are untouched'] = function()
    local jmz  = codeOnly(read_file('bots/FunLib/jmz_func.lua'))
    local mode = codeOnly(read_file('bots/mode_roam_generic.lua'))

    -- pulllane: the gate, the path build and the clause all stay.
    assert(jmz:find('tLanePath = {}', 1, true)
        and jmz:find('J.IsCampBesideLane( camp.location, tLanePath )', 1, true),
        "the 'pulllane' lever body changed -- a retirement from the armed set "
        .. 'is NOT a reject, and must leave bots/ byte-identical')
    assert(jmz:find('local PULL_CAMP_LANE_GAP = 1200', 1, true),
        'PULL_CAMP_LANE_GAP changed; §GF retires the id, not the constant')

    -- pullthink: both halves stay, and stay written the way the pullcad trap
    -- requires (standalone ids, never conjoined with a promoted one).
    assert(mode:find("bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink')", 1, true),
        "the 'pullthink' scope operand changed")
    assert(not mode:find("IsSoakCandidate%('pullthink'%)%s*and%s*J%.IsSoakCandidate"),
        "'pullthink' was conjoined with another id -- the pullcad trap")
end

return tests
