-- [ratchet] [test_set.md §CO.1(三) handoff, 20260831] Soak candidate 'pullcad':
-- the duty-cycle numbers its source comment states are RE-DERIVED under the
-- think-throttle, and the four rows of the corrected table are DRIVEN here.
--
-- ==== WHAT WAS WRONG WITH THE OLD SENTENCE, AND WHY NOTHING IS DELETED =====
--
-- mode_roam_generic's 'pullcad' block used to claim, bare:
--
--     "the drag owns 2.5s of every 3.0s (83%) against 0.7s of every 1.2s (58%)"
--
-- Those are (nBeat - 0.5)/nBeat at nBeat = 3.0 and 1.2.  The arithmetic is
-- exact; its PRESUPPOSITION is that the cadence is asked on every engine frame.
-- The throttle two lines above Think's top denies that (soak candidate
-- 'creepthink', GH #326 / §CK): the cadence is asked only on frames the
-- throttle reopens, and a hero that just right-clicked its lane opponent sits
-- in ACTIVITY_ATTACK for a whole attack cycle R.  So the two percentages
-- describe the R -> 0 world -- which is not the shipped world, it is the world
-- where 'creepthink' is armed, and 'creepthink' is gated and unpromoted.
--
-- The director's handoff was explicit that the numbers may not be silently
-- deleted.  They are not: [limit L1] below shows they ARE the R -> 0 reading,
-- reproduced to the tenth of a point, and [source S1] asserts the quoted
-- sentence survives verbatim in the source.
--
-- ==== THE CORRECTED TABLE (this file drives every row) =====================
--
--   R swept over 1.4 / 1.5 / 1.6 / 1.7 s -- the only attack-cycle band this
--   corpus has measured, GH #326's four right-clicks at 252.4 / 254.0 / 255.4 /
--   257.0 (gaps 1.6 / 1.4 / 1.6).  30 s = 901 frames per run.
--
--     neither armed          0.0%          (0/901 at every R in the band)
--     'pullcad' only         41.2-50.1%    (371..451 / 901)
--     'creepthink' only      58.4%         (526/901, flat in R by construction)
--     both armed             83.4%         (751/901, flat in R by construction)
--
-- ==== THE READING THAT MATTERS, AND IT IS NOT A DOWNGRADE ==================
--
-- In the world that actually ships -- throttle live, 'creepthink' gated --
-- 'pullcad' does not widen a drag that already owns 58% of the window.  It
-- lifts the drag OUT OF THE EMPTY SET: 0.0% -> 41.2-50.1%.  It does so by
-- raising nBeat above R, i.e. it attacks §CK's inequality R > nBeat from the
-- other side than 'creepthink' does (which drives R to ~0).  Hence [arith A1]:
-- the two levers are strongly SUB-additive (0 -> 50 and 0 -> 58 alone, 0 -> 83
-- together, against 108 if they added), which is the source-level half of
-- §CO.1 (ii) -- W30 'pullcad' readings may not be pooled with W25-W29.
--
-- ==== WHAT IS REAL AND WHAT IS DECLARED ====================================
--
--   REAL   every hero's position, team, level and HP on f_072738_zuus_mana --
--          the zoned-mid frame that pinned 'pullbeat' (GH #143).  The pull plan
--          under test is produced by the REAL GetDesire on that frame.  Both
--          nBeat literals and the wind-up hold are PARSED from the mode source,
--          never copied, so a constant that moves moves this file's arithmetic.
--   DECLARED  the enemy lane creep (dumps carry heroes, not creeps), an even
--          lane front, and the animation model: ACTIVITY_ATTACK for R seconds
--          after each poke, idle otherwise.  Same model, same frame and the
--          same driver as tests/test_creepthink_anim_throttle.lua -- this file
--          re-uses that world deliberately so the two readings are commensurate.
--
-- ==== HONEST BOUNDS ========================================================
--
--   * 41.2-50.1% is a LOWER bound.  The animation model does not put the
--     WALKING hero in ACTIVITY_RUN, which is also in meaningfulActivities; in
--     the engine that can only defer the NEXT poke, lengthening the drag.
--   * The 0.0% row leans on neither the model's gap nor the measured band: a
--     hero never ordered to move is never running, and [drive D1] holds for
--     every R >= nBeat, which [control C2] shows is where the band sits.
--   * R's band comes from ONE episode (three gaps).  It is quoted, not
--     re-measured; nothing here asserts a distribution over waves.
--   * This file rules on NOTHING.  'pullcad' is not promoted, not withdrawn and
--     not re-graded here, no gate moves, and bots/ changes by comment only.
--   * Whether the longer drag WINS games is a wave question, untouched.
--
-- ==== MUTATION RECORD (11 run: 10 CAUGHT, 1 SURVIVED BY DESIGN) ============
--
-- Restore from a FILE COPY (never `git checkout`), sha256 taken before AND
-- after every patch so "the patch did not land" can never be reported as
-- SURVIVED, exit codes read bare and never through a pipe, and a final
-- `sha256sum -c` on both files (OK).
--
--   M1  'pullcad' beat 3.0 -> 2.0                    CAUGHT  [S2] + [D2]
--   M2  shipped beat 1.2 -> 3.0                      CAUGHT  [S2] + [D1]
--   M3  empty the drag arm (no move order anywhere)  CAUGHT  [D2/D3/D4/C1]
--   M4  the promoted wind-up hold 0.5 -> 0.0         CAUGHT  [S2]
--         ^ NOT caught by [limit L1]: L1 parses the hold from the source, so
--           both sides of its comparison move together.  That is the intended
--           shape (L1 asks whether the OLD SENTENCE is the R -> 0 limit, not
--           whether the hold is 0.5) and S2 is where the constant is pinned.
--   M5  delete the "neither armed 0.0%" table row    CAUGHT  [S1]
--   M6  widen the stated band to 41.2-83.4%          CAUGHT  [S1]
--   M7  delete the quoted "(83%)" original           CAUGHT  [S1]
--   M8  conjoin the gate with 'pullbeat'             CAUGHT  [S2]
--         (the pullcad trap, tried against the block it is named after)
--   M9  delete the think-throttle clause             CAUGHT  [D1]
--   M10 [self] mode_code() returns the file unstripped  CAUGHT [S2]
--         (the comment quotes the gate, so an unstripped read counts two)
--   M11 [scope control] camp-pull beat 3.0 -> 2.0  SURVIVED, correct
--         ^ that beat is 'pullthink' territory one branch down.  This file
--           deliberately does not cover it, and the survival is the record
--           that it does not -- if it ever starts biting here, the two ids
--           have stopped being separately attributable.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

local ZONED_MID = 'tests/fixtures/f_072738_zuus_mana.lua'
local STEP = 1 / 30 -- engine Think rate
local MODE_SRC = 'bots/mode_roam_generic.lua'
local RUN_SECONDS = 30.0
-- GH #326's measured right-click gaps, plus the two half-steps between them.
local R_BAND = { 1.4, 1.5, 1.6, 1.7 }
local TOL_PP = 0.1 -- the table is stated to a tenth of a point

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

--- The two beats and the wind-up hold, READ from the source rather than copied.
local function beats()
    local code = mode_code()
    local nShipped = assert(code:match('local nBeat = ([%d%.]+)'),
        'the shipped creep-pull beat is no longer `local nBeat = <literal>`')
    local nArmed = assert(
        code:match("IsSoakCandidate%('pullcad'%)%s+then%s+nBeat = ([%d%.]+)"),
        "the 'pullcad' beat is no longer `nBeat = <literal>` inside its gate")
    local nHold = assert(
        code:match('creepPullAttackTime%)%s*<%s*([%d%.]+)%s*then'),
        'the wind-up hold threshold is no longer a literal in the elseif')
    return tonumber(nShipped), tonumber(nArmed), tonumber(nHold)
end

--- Install the fixture world, model the attack animation, and return a driver
--- that runs N engine frames and answers the order log as a string:
---   'A' Action_AttackUnit   'M' Action_MoveToLocation   '.' no order at all
---
--- @param tArmed  set of armed soak-candidate ids, e.g. { pullcad = true }
--- @param nCycle  seconds of ACTIVITY_ATTACK after each poke (0 = never, i.e.
---                the R -> 0 world in which the throttle can never fire)
local function drive(tArmed, nCycle)
    local J, bot, heroes = rf.load(ZONED_MID)
    local lina = heroes['npc_dota_hero_lina']
    local sp = rawget(bot, '__spec')

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

    -- The engine reading the corpus does not carry: GetAnimActivity answers a
    -- fabricated 0 on every dumped frame, and 0 is in no ACTIVITY_* list, so
    -- the throttle can never fire unless the animation is manufactured here.
    -- ([W1]/[W2] of tests/test_creepthink_anim_throttle.lua own that pair of
    -- world assertions; this file re-uses the model, not the argument.)
    sp.GetAnimActivity = function()
        if nCycle > 0 and tLastPoke ~= nil and (DotaTime() - tLastPoke) < nCycle then
            return ACTIVITY_ATTACK
        end
        return 0
    end
    rawset(bot, 'GetAnimActivity', nil)

    J.IsSoakCandidate = function(sId) return tArmed[sId] == true end

    dofile(MODE_SRC)

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
    end
end

local function count(sLog, sChar)
    return select(2, sLog:gsub(sChar, ''))
end

--- The drag's share of frames, in percent, for one arming and one R.
local function drag_pct(tArmed, nCycle)
    local _, _, run = drive(tArmed, nCycle)
    local log = run(RUN_SECONDS)
    return 100 * count(log, 'M') / #log, count(log, 'A'), #log
end

local function near(a, b) return math.abs(a - b) <= TOL_PP end

local function pct(x) return string.format('%.4f%%', x) end

-- ==========================================================================
-- The frame
-- ==========================================================================

tests['[frame F1] the real frame still bids the creep pull'] = function()
    -- If this goes red every row below is driving an empty world.
    local J, bot, run = drive({}, 0)
    assert(J.ShouldCreepPullLane(bot) ~= nil,
        'the zoned-lane frame no longer produces a pull plan -- the trigger '
        .. 'changed, not the cadence')
    assert(GetDesire() == 0.9, 'roam no longer bids the pull window')
    assert(bot.roamCreepPull ~= nil, 'GetDesire no longer sets the pull plan')
    assert(bot.roamCampPull == nil,
        "the camp plan is live on this frame -- this file would be measuring "
        .. "'pullthink' territory, not 'pullcad'")
    run(0.1)
end

-- ==========================================================================
-- The four rows of the corrected table
-- ==========================================================================

tests['[drive D1] neither armed: the drag is an EMPTY SET across the band']
= function()
    -- The row that replaces "0.7s of every 1.2s (58%)".  It is not a smaller
    -- number than 58%, it is a different kind of number: zero orders.
    for _, R in ipairs(R_BAND) do
        local share, nPoke, nFrames = drag_pct({}, R)
        assert(share == 0,
            'R=' .. R .. ': the shipped cadence ordered a drag (' .. pct(share)
            .. ' of ' .. nFrames .. ' frames) -- the `else` arm is reachable '
            .. 'at R > nBeat after all, and the corrected table is wrong')
        assert(nPoke >= 10,
            'R=' .. R .. ': only ' .. nPoke .. ' pokes -- the cadence stopped '
            .. 'poking too, which is a different defect from the one measured')
    end
end

tests["[drive D2] 'pullcad' only: 41.2-50.1% across the band"] = function()
    -- The row that replaces "2.5s of every 3.0s (83%)" for the shipped world.
    local lo, hi = math.huge, -math.huge
    for _, R in ipairs(R_BAND) do
        local share = drag_pct({ pullcad = true }, R)
        assert(share > 0, 'R=' .. R .. ": armed 'pullcad' still ordered no drag")
        lo, hi = math.min(lo, share), math.max(hi, share)
    end
    assert(near(lo, 41.2), 'band floor is ' .. pct(lo) .. ', table says 41.2%')
    assert(near(hi, 50.1), 'band ceiling is ' .. pct(hi) .. ', table says 50.1%')
end

tests["[drive D3] 'creepthink' only: 58.4%, and flat in R by construction"]
= function()
    -- Flat because arming 'creepthink' bypasses the throttle outright, so R
    -- stops being able to reach the cadence at all.  If this ever varies with
    -- R the bypass has stopped bypassing and D4 below is not measuring what it
    -- says either.
    for _, R in ipairs(R_BAND) do
        local share = drag_pct({ creepthink = true }, R)
        assert(near(share, 58.4),
            'R=' .. R .. ": 'creepthink' alone reads " .. pct(share)
            .. ', table says 58.4%')
    end
end

tests['[drive D4] both armed: 83.4%, and flat in R by construction'] = function()
    for _, R in ipairs(R_BAND) do
        local share = drag_pct({ pullcad = true, creepthink = true }, R)
        assert(near(share, 83.4),
            'R=' .. R .. ': both armed reads ' .. pct(share)
            .. ', table says 83.4%')
    end
end

-- ==========================================================================
-- Why the old numbers are kept rather than deleted
-- ==========================================================================

tests['[limit L1] the old 83/58 ARE the R -> 0 reading, to a tenth of a point']
= function()
    -- The whole justification for keeping them.  With the throttle unable to
    -- fire (nCycle = 0) the driven share must equal the closed form the old
    -- sentence used, (nBeat - hold)/nBeat, at BOTH beats -- and both constants
    -- are parsed from the source, so this leg follows the code if it moves.
    local nShipped, nArmed, nHold = beats()
    local tCases = {
        { {},                 nShipped },
        { { pullcad = true }, nArmed },
    }
    for _, case in ipairs(tCases) do
        local tArmed, nBeat = case[1], case[2]
        local share = drag_pct(tArmed, 0)
        local closed = 100 * (nBeat - nHold) / nBeat
        assert(math.abs(share - closed) <= 1.0,
            'at R -> 0 with nBeat=' .. nBeat .. ' the drive reads ' .. pct(share)
            .. ' but the closed form (nBeat - ' .. nHold .. ')/nBeat gives '
            .. pct(closed) .. ' -- the old sentence is not the R -> 0 limit '
            .. 'after all, and keeping its numbers is no longer justified')
    end
    -- And the two limits are precisely the two flat rows of the table, which is
    -- the sentence "R -> 0 is the world where 'creepthink' is armed" as an
    -- equality rather than as prose.
    assert(near(drag_pct({}, 0), drag_pct({ creepthink = true }, R_BAND[1])),
        "the R -> 0 shipped world and the 'creepthink'-armed world disagree")
    assert(near(drag_pct({ pullcad = true }, 0),
                drag_pct({ pullcad = true, creepthink = true }, R_BAND[1])),
        "the R -> 0 'pullcad' world and the both-armed world disagree")
end

-- ==========================================================================
-- Controls: the zero is a finding, not an inert harness
-- ==========================================================================

tests['[control C1] below the beat the SAME shipped harness does drag']
= function()
    -- Without this, [drive D1]'s zero could be the animation injection jamming
    -- Think outright rather than the inequality biting.
    local nShipped = select(1, beats())
    for _, R in ipairs({ 0.3, 0.6, 0.9 }) do
        assert(R < nShipped, 'sweep point ' .. R .. ' is no longer below the '
            .. 'shipped beat ' .. nShipped .. ' -- re-pick the sweep')
        local share = drag_pct({}, R)
        assert(share > 0, 'R=' .. R .. ' is BELOW the shipped beat and the '
            .. 'harness still ordered no drag -- D1 proves nothing')
    end
end

tests['[control C2] the measured band really does straddle the beats']
= function()
    -- The two rows of the table say opposite things about the same band, and
    -- that is only coherent if the band sits above the shipped beat and below
    -- the armed one.  Asserted so a future constant edit cannot leave the table
    -- reading plausibly while describing a different regime.
    local nShipped, nArmed = beats()
    for _, R in ipairs(R_BAND) do
        assert(R >= nShipped, 'R=' .. R .. ' is below the shipped beat '
            .. nShipped .. ' -- D1 is no longer the R >= nBeat regime')
        assert(R < nArmed, 'R=' .. R .. ' is at or above the armed beat '
            .. nArmed .. ' -- D2 is no longer the R < nBeat regime')
    end
end

-- ==========================================================================
-- The consequence the director's ruling rests on
-- ==========================================================================

tests['[arith A1] the two levers are strongly SUB-additive'] = function()
    -- §CO.1 (ii) says the two ids interact and their W30 readings may not be
    -- pooled with W25-W29.  Here that is arithmetic on one frame rather than
    -- prose: each lever alone lifts the drag from 0, and together they deliver
    -- far less than the sum.  Any future claim that 'pullcad' has an additive
    -- effect size has to come through this leg.
    local R = R_BAND[2]
    local nNeither = drag_pct({}, R)
    local nCad = drag_pct({ pullcad = true }, R)
    local nThink = drag_pct({ creepthink = true }, R)
    local nBoth = drag_pct({ pullcad = true, creepthink = true }, R)
    assert(nNeither == 0, 'the baseline row is no longer zero (' .. pct(nNeither)
        .. ') -- the deltas below are not lifts from an empty set')
    local nSum = nCad + nThink
    assert(nBoth < nSum - 10,
        'both armed reads ' .. pct(nBoth) .. ' against a naive sum of '
        .. pct(nSum) .. ' -- the sub-additivity §CO.1 (ii) rests on is gone, '
        .. 'and the no-pooling ruling needs a different reason')
    -- The marginal contribution of each id depends on whether the other is
    -- armed, which IS non-additivity, stated the way a wave would meet it.
    local nMarginalAlone = nCad - nNeither
    local nMarginalOnTop = nBoth - nThink
    assert(nMarginalOnTop < nMarginalAlone - 10,
        "'pullcad' contributes " .. pct(nMarginalAlone) .. ' alone but '
        .. pct(nMarginalOnTop) .. " on top of 'creepthink' -- if these ever "
        .. 'converge the two ids have stopped interacting and the pooling ban '
        .. 'can be revisited')
end

-- ==========================================================================
-- Source: the numbers may not be silently deleted
-- ==========================================================================

tests['[source S1] the old sentence and the corrected table both survive']
= function()
    -- The director's handoff forbade a silent deletion.  This leg is that
    -- prohibition made machine-checkable: the quoted original must stay quoted,
    -- and every row of the replacement table must stay in the comment with the
    -- value this file drives.
    local raw = read_file(MODE_SRC)
    -- Both halves of the original sentence, matched literally.  It is quoted
    -- across a line break in the source, so each half is asked for separately
    -- rather than reflowing the file to suit the test.
    for _, sHalf in ipairs({ '2.5s of every 3.0s (83%)', 'every 1.2s (58%)' }) do
        assert(raw:find(sHalf, 1, true),
            'the original duty-cycle sentence lost "' .. sHalf .. '" -- the '
            .. 'numbers were deleted instead of re-homed, and §CO.1 (三) '
            .. 'forbade exactly that')
    end
    assert(raw:find('DUTY-CYCLE CORRECTION', 1, true),
        'the correction block is gone but the old sentence remains -- the '
        .. 'source is back to stating the R -> 0 numbers as if they shipped')

    local nNeither = assert(raw:match('neither armed%s+([%d%.]+)%%'),
        'the corrected table has no "neither armed" row')
    local nLo, nHi = raw:match("'pullcad' only%s+([%d%.]+)%-([%d%.]+)%%")
    assert(nLo, 'the corrected table has no "\'pullcad\' only" band')
    local nThink = assert(raw:match("'creepthink' only%s+([%d%.]+)%%"),
        'the corrected table has no "\'creepthink\' only" row')
    local nBoth = assert(raw:match('both armed%s+([%d%.]+)%%'),
        'the corrected table has no "both armed" row')

    local function stated(sLabel, sValue, nDriven)
        assert(near(tonumber(sValue), nDriven),
            'the source table says ' .. sLabel .. ' = ' .. sValue .. '% but '
            .. 'this file drives ' .. pct(nDriven) .. ' -- comment and code '
            .. 'have drifted apart')
    end
    stated('neither armed', nNeither, drag_pct({}, R_BAND[1]))
    stated("'pullcad' only floor", nLo, drag_pct({ pullcad = true }, 1.7))
    stated("'pullcad' only ceiling", nHi, drag_pct({ pullcad = true }, 1.4))
    stated("'creepthink' only", nThink, drag_pct({ creepthink = true }, R_BAND[1]))
    stated('both armed', nBoth,
        drag_pct({ pullcad = true, creepthink = true }, R_BAND[1]))
end

tests['[source S2] the correction changed no code, and no gate moved']
= function()
    -- This round is comment-only by declaration; here it is by assertion.
    local code = mode_code()
    local n = select(2, code:gsub("IsSoakCandidate%('pullcad'%)", ''))
    assert(n == 1, "expected exactly one 'pullcad' gate in code, found " .. n)
    assert(not code:find("IsSoakCandidate%('pullcad'%)%s*and%s*J%.IsSoakCandidate"),
        "the 'pullcad' gate was conjoined with another candidate id -- that is "
        .. 'frozen FALSE the day the other id is promoted (the pullcad trap '
        .. 'named after this very block), while check_armed_wiring.py still '
        .. 'reads it WIRED')
    local nShipped, nArmed, nHold = beats()
    assert(nShipped == 1.2 and nArmed == 3.0 and nHold == 0.5,
        'a cadence constant moved (shipped=' .. nShipped .. ' armed=' .. nArmed
        .. ' hold=' .. nHold .. ') -- every percentage in the source table and '
        .. 'in this file was driven at 1.2 / 3.0 / 0.5 and must be re-driven')
end

return tests
