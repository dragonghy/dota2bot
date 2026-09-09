-- [GH #648] The lane guard in J.ShouldPullNeutralCamp tested for a value the
-- engine never returns, and the corpus reads it both ways on every frame.
--
-- THE DEFECT. `bot:GetAssignedLane()` answers one of four documented engine
-- constants (docs/BOT_API_REFERENCE.md:1910 -- LANE_NONE = 0, LANE_TOP = 1,
-- LANE_MID = 2, LANE_BOT = 3). The engine's way of saying "this bot has no
-- lane" is therefore LANE_NONE, which is the NUMBER 0. The shipped guard was
-- `if nLane == nil then return nil end`, so the state it was written to reject
-- walked past it and was handed to GetLaneFrontLocation / GetLocationAlongLane
-- as a lane id neither can resolve.
--
-- IT IS NOT A NEW OBSERVATION, WHICH IS THE POINT. This exact shape has been
-- recorded since 20260822 as the fourth STOPPER of
-- tests/test_pullcamp_trigger_census.lua ("It is not nil, so the `nLane == nil`
-- guard passes and a bogus lane id is handed to GetLocationAlongLane"). It was
-- filed there as a fact about the LOADER -- a reason the chain cannot be driven
-- end to end -- and so nothing in bots/ was ever changed. The same sentence
-- read as a fact about the GUARD says the guard cannot fire, and that is the
-- `pullcamp` family's own recurring defect for the third time: GH #13's vision
-- clause, GH #277's 800 veto, and now this.
--
-- ⭐ THE NUMBERS, AND WHICH WAY EACH ONE CUTS (1021 alive hero frames, 110
-- fixtures, tests/_pullcamp_sweep.lua):
--   * `lane_nil` 0 / 1021 -- the SHIPPED guard fires on no frame at all;
--   * `lane_none` 1021 / 1021 -- the state it means to reject is on every one;
--   * `spnc_raise_lanefront` 18 -- with 'pullnolane' disarmed, 18 frames reach
--     the line BELOW the guard and raise there;
--   * `guard_raise` 0 and `guard_closes` 18 -- with it armed, all 18 stop at
--     the guard instead;
--   * `guard_opens` 0 -- and never the other way.
--
-- ⭐⭐ THE ORACLE IS STOPPER 3 TURNED INTO AN INSTRUMENT, so nothing is
-- declared to read it. The loader REFUSES GetLaneFrontLocation (GH #61) and
-- that call sits immediately below the guard, so on a frame that reaches the
-- clause the two answers are distinguishable without inventing a world: a
-- raise naming GetLaneFrontLocation is positive proof the guard let the frame
-- through, and a clean nil in its place is positive proof it stopped it. A
-- census that had to declare a lane geometry to see this would be measuring
-- its own declaration.
--
-- ⛔ WHAT THE CORPUS CANNOT SAY, said here rather than left for the wave. The
-- 1021/1021 above is a statement about the LOADER, not about Dota: lane
-- assignment is bot-VM state, not entity state, so it is absent from the .dem
-- and the loader answers a constant 0. The real-game domain of this guard is
-- the frequency of LANE_NONE among pos-4/5 bots inside the 60-360s laning
-- window, and that number is not knowable from here. On every frame where a
-- lane IS assigned the clause is exactly a unit element (GH #622's question,
-- asked before the wave instead of after): a wave that arms 'pullnolane'
-- expecting a behavioural delta would read back "tested, no effect" while
-- check_armed_wiring.py still called it WIRED -- the 'pullcad' shape. GH #648
-- therefore recommends promoting it WITH 'pullcamp', as part of that
-- candidate's own repair, rather than buying it a wave of its own.
--
-- ⭐⭐⭐ WHY tests/mock/bot_api.lua CHANGED IN THE SAME ROUND, and why that is
-- not scope creep. The mock's sentinel table auto-numbered every unknown
-- ALL_CAPS global, so LANE_NONE read 1024 there. A mock that cannot express
-- the no-lane state cannot test a guard against it -- and worse, `== LANE_NONE`
-- was false in the fixture world for a reason having nothing to do with the
-- frame. That is verbatim the TEAM_RADIANT/TEAM_DIRE defect the same file
-- already pinned three lines above (sentinels made `Team == TEAM_DIRE` false
-- and pointed every Dire retreat at the Radiant fountain). The fix is the same
-- fix, and section 1 asserts it in BOTH directions so a future re-sentinelling
-- goes red instead of going quiet.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local tests = {}

local WITNESS = 'tests/fixtures/f_260819_181742_ss_chase_stalled.lua'
local WITNESS_HERO = 'npc_dota_hero_silencer'

-- ------------------------------------------------------------ source reads --

local function jmz_source()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

local function helper_body()
    local src = jmz_source()
    local at = assert(src:find('function J.ShouldPullNeutralCamp', 1, true),
        'J.ShouldPullNeutralCamp moved')
    local fin = assert(src:find('\nend\n', at, true), 'helper has no end')
    return src:sub(at, fin)
end

-- Comments are stripped before any structural read: the header of this helper
-- quotes both `nLane == nil` and `GetLaneFrontLocation` in prose, so an
-- unstripped search would anchor on the explanation instead of the code.
local function stripped_body()
    local out = {}
    for line in (helper_body() .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

-- ------------------------------------------------------------- the manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_pullcamp_sweep.lua 2>&1'),
        'could not start tests/_pullcamp_sweep.lua')
    local raw = p:read('*a')
    p:close()
    local m = { C = {}, GRD = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local kind = line:match('^(%S+)')
        if kind == 'C' then
            local k, n = line:match('^C (%S+) (%-?%d+)$')
            if k then m.C[k] = tonumber(n) end
        elseif kind == 'GRD' then
            local fx, hero, t, lane = line:match('^GRD (%S+) (%S+) (%S+) (%S+)$')
            table.insert(m.GRD, { fixture = fx, hero = hero,
                t = tonumber(t), lane = lane })
        elseif kind == 'DONE' then
            m.done = true
        end
    end
    assert(m.done, 'the corpus sweep did not finish -- run '
        .. '`lua5.1 tests/_pullcamp_sweep.lua` by hand to see why:\n'
        .. raw:sub(1, 800))
    manifest_cache = m
    return m
end

local function C(key)
    local n = manifest().C[key]
    assert(n ~= nil, 'the sweep did not report counter ' .. key)
    return n
end

-- ================================================== 1. the constants are real

tests['[GH #648] the documented value of LANE_NONE is parsed, not restated'] =
function()
    -- The guard's whole licence is that LANE_NONE is the engine's no-lane
    -- answer AND that it is 0. Both halves come off the API reference; a
    -- patch that renumbered the family must redden this file, not survive it.
    local fh = assert(io.open('docs/BOT_API_REFERENCE.md', 'r'))
    local doc = fh:read('*a'); fh:close()
    local none = doc:match('LANE_NONE%s*=%s*(%d+)')
    local top = doc:match('LANE_TOP%s*=%s*(%d+)')
    local mid = doc:match('LANE_MID%s*=%s*(%d+)')
    local bot_ = doc:match('LANE_BOT%s*=%s*(%d+)')
    assert(none, 'docs/BOT_API_REFERENCE.md no longer states LANE_NONE')
    assert(tonumber(none) == 0,
        'the API reference now says LANE_NONE = ' .. none .. ', not 0 -- the '
        .. 'guard in J.ShouldPullNeutralCamp compares against 0')
    assert(tonumber(top) == 1 and tonumber(mid) == 2 and tonumber(bot_) == 3,
        'the LANE_* family renumbered in the API reference')
end

tests['[GH #648] the mock answers the documented LANE_* values, both ways'] =
function()
    -- Forward: the four constants are the engine's. Reverse: they are NOT the
    -- sentinel table's auto-numbers (>= 1000), which is what they were before
    -- this round and what a future re-sentinelling would silently restore.
    rf.load(WITNESS, WITNESS_HERO)
    assert(LANE_NONE == 0, 'LANE_NONE reads ' .. tostring(LANE_NONE)
        .. ' in the fixture world, not the engine 0')
    assert(LANE_TOP == 1 and LANE_MID == 2 and LANE_BOT == 3,
        'the mock LANE_* family no longer matches the API reference')
    for _, k in ipairs({ 'LANE_NONE', 'LANE_TOP', 'LANE_MID', 'LANE_BOT' }) do
        assert(_G[k] < 1000, k .. ' is back on the auto-numbering sentinel '
            .. '(' .. tostring(_G[k]) .. ') -- every `== ' .. k .. '` in bots/ '
            .. 'is false again for a reason unrelated to the frame')
    end
end

-- ============================================ 2. the guard, as a source shape

tests['[GH #648] the guard exists, names its own id, and compares to LANE_NONE']
= function()
    local body = stripped_body()
    assert(body:find("IsSoakCandidate( 'pullnolane' )", 1, true),
        "the 'pullnolane' gate is gone from J.ShouldPullNeutralCamp")
    assert(body:find('LANE_NONE', 1, true),
        'the guard no longer compares against LANE_NONE')
    -- The pullcad trap, checked rather than promised: this clause may name
    -- exactly one candidate id, or it freezes FALSE the day the other is
    -- promoted. 'pullcamp' appears once (the function's own gate) and
    -- 'pullnolane' once; no line names both.
    for line in (body .. '\n'):gmatch('([^\n]*)\n') do
        local n = 0
        for _ in line:gmatch('IsSoakCandidate') do n = n + 1 end
        assert(n <= 1, 'two soak-candidate ids on one line: ' .. line)
    end
end

tests['[GH #648] the guard sits between the nil test and the first lane read']
= function()
    -- ORDER, not presence. The differential in section 4 reads a raise from
    -- GetLaneFrontLocation as "the guard let it through", which is only true
    -- while the guard is strictly above that call; and it must stay below the
    -- nil test, because it is that test's repair and not its replacement.
    local body = stripped_body()
    local at_nil = assert(body:find('nLane == nil', 1, true),
        'the nil guard is gone -- this file repairs it, it does not replace it')
    local at_guard = assert(body:find('pullnolane', 1, true))
    local at_front = assert(body:find('GetLaneFrontLocation', 1, true))
    local at_along = assert(body:find('GetLocationAlongLane', 1, true))
    assert(at_nil < at_guard, 'the LANE_NONE guard moved above the nil guard')
    assert(at_guard < at_front and at_guard < at_along,
        'a lane read now happens BEFORE the LANE_NONE guard -- the bogus lane '
        .. 'id reaches the engine again and section 4 no longer measures it')
end

tests['[GH #648] the sweep measures the CONSTANT, not a literal 0'] = function()
    -- `lane_zero` and `lane_none` are only a cross-check while they are read
    -- off different things. Rewriting the second one as `lane == 0` looks like
    -- cleanup, makes the two columns identical by construction, and silently
    -- deletes the only assertion that LANE_NONE is still 0 in this world --
    -- so the shape is pinned in the sweep's source, not inferred from its
    -- counts (the counts cannot tell the difference; that is the point).
    local fh = assert(io.open('tests/_pullcamp_sweep.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    assert(s:find("lane == (LANE_NONE or 0) then bump('lane_none')", 1, true),
        "the sweep's lane_none column no longer reads LANE_NONE -- it and "
        .. 'lane_zero are now the same measurement twice')
    assert(s:find("lane == 0 then bump('lane_zero')", 1, true),
        "the sweep's lane_zero column no longer reads the literal 0")
end

-- =================================== 3. the corpus columns (real frames only)

tests['[GH #648] the shipped nil guard fires on 0 frames; LANE_NONE on all'] =
function()
    cs.ratchet(C('frames'), 1021, 'alive hero frames')
    assert(C('lane_nil') == 0,
        'GetAssignedLane now answers nil somewhere (' .. C('lane_nil')
        .. ') -- the shipped guard has become reachable; re-read this file')
    assert(C('lane_none') == C('frames'),
        'GetAssignedLane no longer reads LANE_NONE on every frame ('
        .. C('lane_none') .. '/' .. C('frames') .. ')')
    -- The two columns are deliberately separate measurements -- one against
    -- the literal 0 the loader answers, one against the constant the shipped
    -- guard compares to -- and they must agree.
    assert(C('lane_zero') == C('lane_none'),
        'lane_zero and lane_none disagree (' .. C('lane_zero') .. ' vs '
        .. C('lane_none') .. ') -- LANE_NONE is no longer 0 in this world')
end

tests['[GH #648] armed, the guard closes every frame that reached the lane read']
= function()
    -- The population is not asserted to be large -- it is 18 frames, and the
    -- header says why the corpus cannot price the real one. What is asserted
    -- is that it is not EMPTY (a zero here would make every claim below
    -- vacuous) and that the two drives disagree on exactly it.
    cs.ratchet(C('spnc_raise_lanefront'), 18, 'frames reaching the lane read')
    assert(C('spnc_raise') == C('spnc_raise_lanefront'),
        'a raise from somewhere other than GetLaneFrontLocation appeared -- '
        .. 'the oracle in section 4 is no longer single-cause')
    assert(C('guard_closes') > 0,
        'the guard closes no frame at all -- every assertion here is vacuous')
    assert(C('guard_closes') == C('spnc_raise'),
        'the guard closes ' .. C('guard_closes') .. ' of ' .. C('spnc_raise')
        .. ' frames that fell through -- it is meant to close all of them')
    assert(C('guard_raise') == 0,
        'with the guard armed ' .. C('guard_raise') .. ' frames still reach '
        .. 'GetLaneFrontLocation')
    assert(#manifest().GRD == C('guard_closes'),
        'the witness rows and the counter disagree ('
        .. #manifest().GRD .. ' vs ' .. C('guard_closes') .. ')')
end

tests['[reverse][GH #648] the guard never OPENS a pull, on any frame'] =
function()
    -- The forbidden direction. A guard can only remove pulls; if arming it
    -- ever turned a nil into a camp (or into a raise), it is not a guard.
    assert(C('guard_opens') == 0,
        'arming pullnolane opened ' .. C('guard_opens') .. ' frame(s)')
    assert(C('guard_nonnil') == 0 and C('spnc_nonnil') == 0,
        'the helper now returns a camp somewhere in the corpus -- '
        .. 'GetNeutralSpawners has stopped being empty; re-derive this file')
    -- And the arithmetic closes: every frame is nil or raise, both ways.
    assert(C('spnc_nil') + C('spnc_raise') == C('frames'),
        'the disarmed drive does not account for every frame')
    assert(C('guard_nil') + C('guard_raise') == C('frames'),
        'the armed drive does not account for every frame')
end

-- ============================ 4. the differential on ONE real frame, in-process

local function drive(bot, J, bGuard)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(sId)
        return sId == 'pullcamp' or (bGuard and sId == 'pullnolane')
    end
    return pcall(J.ShouldPullNeutralCamp, bot)
end

tests['[GH #648] real frame: disarmed reaches the lane read, armed stops'] =
function()
    -- The same instant, driven twice, with nothing declared. The witness is a
    -- frame the sweep names; it is re-driven HERE so the claim does not
    -- depend on the subprocess having run the function the same way.
    local J, bot = rf.load(WITNESS, WITNESS_HERO)
    -- Anti-vacuum: the frame really does reach the clause, and for the
    -- reasons the chain requires rather than by accident.
    assert(bot:IsAlive(), 'the witness hero is not alive on this frame')
    assert(not J.IsCore(bot), 'the witness is no longer a support')
    assert(bot:GetAssignedLane() == LANE_NONE,
        'the witness frame no longer reads LANE_NONE')

    local ok, v = drive(bot, J, false)
    assert(not ok, 'disarmed, the helper no longer reaches the lane read on '
        .. WITNESS .. ' -- it answered ' .. tostring(v))
    assert(tostring(v):find('GetLaneFrontLocation', 1, true),
        'disarmed, the helper raises somewhere else now: ' .. tostring(v))

    local J2, bot2 = rf.load(WITNESS, WITNESS_HERO)
    local ok2, v2 = drive(bot2, J2, true)
    assert(ok2, 'armed, the helper still raises: ' .. tostring(v2))
    assert(v2 == nil, 'armed, the helper returned ' .. tostring(v2)
        .. ' instead of nil')
end

tests['[GH #648] gate plumbing: outside turbo and outside pullcamp, no change']
= function()
    -- The two structural early-outs still run above everything this round
    -- touched, so a normal-mode game and a disarmed 'pullcamp' are unchanged
    -- whatever 'pullnolane' says.
    local J, bot = rf.load(WITNESS, WITNESS_HERO)
    J.IsModeTurbo = function() return false end
    J.IsSoakCandidate = function() return true end
    local ok, v = pcall(J.ShouldPullNeutralCamp, bot)
    assert(ok and v == nil, 'non-turbo no longer early-outs to nil')

    local J2, bot2 = rf.load(WITNESS, WITNESS_HERO)
    J2.IsModeTurbo = function() return true end
    J2.IsSoakCandidate = function(sId) return sId == 'pullnolane' end
    local ok2, v2 = pcall(J2.ShouldPullNeutralCamp, bot2)
    assert(ok2 and v2 == nil,
        "'pullnolane' armed alone now does something with 'pullcamp' disarmed")
end

return tests
