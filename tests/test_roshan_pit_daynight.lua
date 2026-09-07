--- Soak candidate 'roshpit' -- J.RoshanPitForTimeOfDay / J.GetCurrentRoshanLocation
--- in bots/FunLib/jmz_func.lua.  GH #450 ([bug], replay-check 2026-09-03),
--- ruling iterations/streams/test_set.md §FK.3, owed row `roshan_pit_daynight_fix`.
--
-- THE DEFECT.  `J.GetCurrentRoshanLocation()` maps day -> DireRoshanLoc and
-- night -> RadiantRoshanLoc.  Over W41's 82 games the corpus carries 77 roshan
-- deaths and the heroes who were actually damaging roshan stood in the OTHER
-- pit all 77 times (agree 0 / DISAGREE 77 / unresolved 0,
-- tools/batch_test/behavioral/roshdist_domain.py §A).  The two pits are
-- 7889.6u apart, so this is an inversion, not a rounding error, and the
-- competing "roshan changes pit on every death" hypothesis is refused by the
-- same corpus (6 adjacent death pairs inside one day/night phase: 6 same pit,
-- 0 swaps; all 3 observed swaps crossed a phase boundary).
--
-- WHY IT LANDS GATED AND NOT AS A CONSTANT SWAP.  The function has NO gate
-- today and 25 call sites read it in every real game, so an ungated swap moves
-- shipped behaviour for the whole roshan subsystem in one step -- the shape
-- §FK.3 refused, and the shape GH #352 attributes to 23 earlier commits that
-- moved the side balance with nothing raising a hand.
--
-- ⛔ TWO THINGS THIS FILE DOES NOT BUY, STATED UP FRONT.
--
--   1. THE PHASE ITSELF.  Both legs ask `J.CheckTimeOfDay()`, which does not
--      ask the engine: it computes `DotaTime() % 600 < 300` and calls that
--      "day".  The engine's own `GetTimeOfDay()` (docs/BOT_API_REFERENCE.md:346)
--      has ZERO call sites in bots/.  If that modulo is out of phase then the
--      pit is wrong on BOTH legs and neither mapping is the thing to fix.  That
--      is a SECOND lever with its own id; it is deliberately not bundled here
--      (lanefix lesson) and is registered on GH #450.  What this file can and
--      does pin is that this candidate did not silently change the phase source
--      -- see [coupling].
--   2. CONDITION (a).  "It really fires in a real game" is bought by
--      roshdist_domain.py §A on a wave that arms `roshpit` (agree 77 /
--      DISAGREE 0 is the acceptance §FK.3 wrote).  A fixture is one instant and
--      cannot see a roshan death.
--
-- ⚠ CONFLICTING SECONDARY SOURCES, RECORDED BECAUSE THEY POINT THE OTHER WAY.
-- Three 7.38 write-ups say Roshan alternates "top at night, bottom at day"
-- (top = RadiantRoshanLoc, y > 0), which is what the SHIPPED mapping already
-- does; a 7.33 write-up says the opposite ("Radiant side during the day, Dire
-- during the night"), which is what the armed leg does.  The two summaries
-- contradict each other, so at most one of them describes 7.41, and AGENTS.md
-- already refuses patch-note summaries as evidence.  The measurement is on our
-- own patch and its one competing explanation -- a half-cycle offset between
-- the dumper's `t` and `DotaTime()` -- is excluded by construction: the dumper
-- subtracts `m_pGameRules.m_flGameStartTime` (the horn) from engine time
-- (behavioral/dumper/main.go:500-506, :735-742), which is the origin DotaTime()
-- uses.  Hence: measurement over summary, and gated either way.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')               -- owns the shared switch

local CAND = 'roshpit'

-- bots/FunLib/utils.lua:709-710 -- restated here so a silent edit of either
-- constant shows up as a red in [premise] instead of quietly redefining what
-- every case below means.
local RADIANT_PIT = { x = -2984, y = 2349 }
local DIRE_PIT    = { x = 2980,  y = -2816 }

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

local function fixture_paths()
    local p = assert(io.popen('ls tests/fixtures/f_*.lua'))
    local out = {}
    for path in p:lines() do out[#out + 1] = path end
    p:close()
    assert(#out > 0, 'the fixture corpus is empty -- nothing below can fail')
    return out
end

-- Farm-only switch files are skipped for the same reason every source-scanning
-- test in this suite skips them (GH #365 §2 / #438): they are gitignored,
-- transient, and written by concurrent gate tests.
local function lua_sources()
    local out = require('lua_source_scan').bots_files()
    assert(#out > 100, 'the bots/ tree shrank to ' .. #out .. ' files -- a census would be vacuous')
    return out
end

--- A fresh jmz on radiant, turbo on, with the clock parked at `nTime`.
--- The switch must already be written when this runs: reset_modules re-requires
--- jmz_func so its cached GetSoakSideConf re-reads the file.
local function fresh_jmz(nTime)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skeleton_king', { CanBeSeen = true })
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    -- The mock does not define the engine's mode enum, so J.IsModeTurbo would
    -- fall through to its courier-speed heuristic and answer false for reasons
    -- that have nothing to do with this file.  Define the enum and the getter
    -- together, which is the state a real turbo game is in.
    GAMEMODE_TURBO = 23
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    bot.GetTeam = function() return TEAM_RADIANT end
    DotaTime = function() return nTime end
    return J, bot
end

--- Same, but the engine reports a NON-turbo game.  Only the game mode differs.
local function fresh_jmz_normal(nTime)
    local J, bot = fresh_jmz(nTime)
    GetGameMode = function() return 1 end        -- all pick, not turbo
    return J, bot
end

--- Run `fn` with the candidate armed (`sCand`) or provably unarmed (nil).
local function with(sCand, fn, sSide)
    if sCand == nil then
        ss.assert_clean('unarmed leg')
        local ok, err = pcall(fn)
        if ok then ss.assert_clean('unarmed leg, after the case body') end
        if not ok then error(err, 0) end
        return
    end
    ss.arm(sCand, sSide or 'radiant')
    local ok, err = pcall(fn)
    ss.finish(ok, err)
end

-- The state this process STARTED in, taken at file-load time -- the only moment
-- that sees it (test_aegis_grouping measured what a leftover costs: 6/6 green).
ss.assert_clean('test_roshan_pit_daynight')

local function same_loc(v, want)
    return v ~= nil and math.abs(v.x - want.x) < 1.0 and math.abs(v.y - want.y) < 1.0
end

local function loc_name(v)
    if same_loc(v, RADIANT_PIT) then return 'RadiantRoshanLoc' end
    if same_loc(v, DIRE_PIT) then return 'DireRoshanLoc' end
    return 'NEITHER PIT (' .. tostring(v and v.x) .. ', ' .. tostring(v and v.y) .. ')'
end

--- Times that land in each half of the repo's own 600s cycle, several cycles
--- apart so a case cannot pass by sitting on one lucky instant.  Boundaries are
--- included on purpose: 0 and 300 are where an off-by-one in the phase test
--- would live.
local DAY_TIMES   = { 0, 1, 150, 299, 600, 899.9, 1200, 3899 }
local NIGHT_TIMES = { 300, 301, 450, 599, 900, 1199.9, 1500, 4199 }

--============================================================================
-- [premise] The instrument is not blind, and the error is not rounding.
--============================================================================
tests['[premise] the two pits are the utils constants, 7889.6u apart'] = function()
    with(nil, function()
        local J = fresh_jmz(0)
        assert(J.Utils ~= nil, 'J.Utils is nil under the mock -- nothing below measures anything')
        assert(same_loc(J.Utils.RadiantRoshanLoc, RADIANT_PIT),
            'RadiantRoshanLoc moved to ' .. loc_name(J.Utils.RadiantRoshanLoc))
        assert(same_loc(J.Utils.DireRoshanLoc, DIRE_PIT),
            'DireRoshanLoc moved to ' .. loc_name(J.Utils.DireRoshanLoc))
        local dx = J.Utils.RadiantRoshanLoc.x - J.Utils.DireRoshanLoc.x
        local dy = J.Utils.RadiantRoshanLoc.y - J.Utils.DireRoshanLoc.y
        local nApart = math.sqrt(dx * dx + dy * dy)
        assert(math.abs(nApart - 7889.6) < 1.0,
            'the pits are ' .. string.format('%.1f', nApart) .. 'u apart, not 7889.6 -- ' ..
            'the "an inversion is not a rounding error" argument has to be re-derived')
    end)
end

--============================================================================
-- The two legs.  Both are swept over both phases: a repair that answers one
-- pit unconditionally passes half of this and dies on the other half.
--============================================================================
tests['[off-candidate] unarmed IS the shipped mapping, at both phases'] = function()
    with(nil, function()
        for _, t in ipairs(DAY_TIMES) do
            local J = fresh_jmz(t)
            assert(J.CheckTimeOfDay() == 'day', 't=' .. t .. ' is not "day" -- fix the grid, not the case')
            local v = J.GetCurrentRoshanLocation()
            assert(same_loc(v, DIRE_PIT),
                't=' .. t .. ' (day), unarmed: expected DireRoshanLoc, got ' .. loc_name(v))
        end
        for _, t in ipairs(NIGHT_TIMES) do
            local J = fresh_jmz(t)
            assert(J.CheckTimeOfDay() == 'night', 't=' .. t .. ' is not "night" -- fix the grid, not the case')
            local v = J.GetCurrentRoshanLocation()
            assert(same_loc(v, RADIANT_PIT),
                't=' .. t .. ' (night), unarmed: expected RadiantRoshanLoc, got ' .. loc_name(v))
        end
    end)
end

tests['[flip] armed returns the OTHER pit, at both phases'] = function()
    with(CAND, function()
        for _, t in ipairs(DAY_TIMES) do
            local J = fresh_jmz(t)
            local v = J.GetCurrentRoshanLocation()
            assert(same_loc(v, RADIANT_PIT),
                't=' .. t .. ' (day), armed: expected RadiantRoshanLoc, got ' .. loc_name(v))
        end
        for _, t in ipairs(NIGHT_TIMES) do
            local J = fresh_jmz(t)
            local v = J.GetCurrentRoshanLocation()
            assert(same_loc(v, DIRE_PIT),
                't=' .. t .. ' (night), armed: expected DireRoshanLoc, got ' .. loc_name(v))
        end
    end)
end

tests['[worker] both mappings are readable on one frame, ungated'] = function()
    -- The worker is what a future reader (a detector, a promote) can use to
    -- compare legs without owning a switch file.  If it ever agrees with itself
    -- the candidate is a no-op and every reading taken through it is a zero
    -- that means nothing.
    with(nil, function()
        local nChecked = 0
        for _, t in ipairs(DAY_TIMES) do
            local J = fresh_jmz(t)
            local vOff = J.RoshanPitForTimeOfDay(false)
            local vOn = J.RoshanPitForTimeOfDay(true)
            assert(same_loc(vOff, DIRE_PIT), 't=' .. t .. ' worker(false) = ' .. loc_name(vOff))
            assert(same_loc(vOn, RADIANT_PIT), 't=' .. t .. ' worker(true) = ' .. loc_name(vOn))
            assert(not same_loc(vOff, vOn), 't=' .. t .. ': the two legs agree -- the candidate is a no-op')
            nChecked = nChecked + 1
        end
        for _, t in ipairs(NIGHT_TIMES) do
            local J = fresh_jmz(t)
            local vOff = J.RoshanPitForTimeOfDay(false)
            local vOn = J.RoshanPitForTimeOfDay(true)
            assert(same_loc(vOff, RADIANT_PIT), 't=' .. t .. ' worker(false) = ' .. loc_name(vOff))
            assert(same_loc(vOn, DIRE_PIT), 't=' .. t .. ' worker(true) = ' .. loc_name(vOn))
            assert(not same_loc(vOff, vOn), 't=' .. t .. ': the two legs agree -- the candidate is a no-op')
            nChecked = nChecked + 1
        end
        assert(nChecked == #DAY_TIMES + #NIGHT_TIMES, 'the sweep skipped instants')
    end)
end

--============================================================================
-- The gate's two other conjuncts.  Without these "armed" would mean "armed
-- anywhere", and a gated fix that fires in a normal game is not gated.
--============================================================================
tests['[turbo-only] armed in a NON-turbo game is the shipped mapping'] = function()
    with(CAND, function()
        local J = fresh_jmz_normal(0)
        assert(not J.IsModeTurbo(), 'the mock still reports turbo -- this case measures nothing')
        assert(same_loc(J.GetCurrentRoshanLocation(), DIRE_PIT),
            'a non-turbo game got the armed mapping')
    end)
end

tests['[side] armed for the OTHER side is the shipped mapping'] = function()
    -- The switch names dire; this bot is radiant, so the candidate is not on
    -- this side and the baseline leg of the wave must read shipped.
    with(CAND, function()
        local J = fresh_jmz(0)
        assert(same_loc(J.GetCurrentRoshanLocation(), DIRE_PIT),
            'the baseline side of the wave got the armed mapping')
    end, 'dire')
end

tests['[other id] a different armed id does not turn this one on'] = function()
    with('roshdist', function()
        local J = fresh_jmz(0)
        assert(same_loc(J.GetCurrentRoshanLocation(), DIRE_PIT),
            "arming 'roshdist' also flipped the pit -- the ids are not separable")
    end)
end

--============================================================================
-- Real frames.  A pit is a pure function of the clock, so what the corpus buys
-- here is that the live clock values in the archive land on BOTH sides of the
-- phase split -- i.e. the shipped mapping is reachable in both directions on
-- frames nobody constructed for this test.
--============================================================================
tests['[corpus] both phases occur on real frames, and each answers its pit'] = function()
    with(nil, function()
        local nDay, nNight, nFrames = 0, 0, 0
        for _, path in ipairs(fixture_paths()) do
            local J = rf.load(path)
            local sTod = J.CheckTimeOfDay()
            local v = J.GetCurrentRoshanLocation()
            nFrames = nFrames + 1
            if sTod == 'day' then
                nDay = nDay + 1
                assert(same_loc(v, DIRE_PIT), path .. ' (day): got ' .. loc_name(v))
            else
                nNight = nNight + 1
                assert(same_loc(v, RADIANT_PIT), path .. ' (night): got ' .. loc_name(v))
            end
        end
        assert(nFrames >= 100, 'only ' .. nFrames .. ' fixtures loaded')
        assert(nDay >= 1, 'NO fixture frame is in the day half any more -- one direction of ' ..
            'this mapping is unreachable on real frames; re-measure before trusting this file')
        assert(nNight >= 1, 'NO fixture frame is in the night half any more -- see above')
    end)
end

--============================================================================
-- [gate] / [coupling] / [call sites]: what the diff is allowed to be.
--============================================================================
tests['[gate] turbo AND the id, resolved in exactly one place'] = function()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local fn = src:match('function J%.GetCurrentRoshanLocation.-\nend')
    assert(fn, 'J.GetCurrentRoshanLocation is gone or reshaped')
    assert(fn:find("J%.IsSoakCandidate%s*%(%s*'" .. CAND .. "'%s*%)"),
        'the resolver does not read the ' .. CAND .. ' gate')
    assert(fn:find('J%.IsModeTurbo%s*%(%s*%)'), 'the gate is not turbo-only')
    assert(fn:find('J%.IsModeTurbo') < fn:find('J%.IsSoakCandidate'),
        'turbo must be the first operand of the gate')

    local _, nGates = src:gsub("IsSoakCandidate%s*%(%s*'" .. CAND .. "'%s*%)", '')
    assert(nGates == 1, 'the ' .. CAND .. ' id is read in ' .. nGates ..
        ' places; it must resolve in exactly one')

    local worker = src:match('function J%.RoshanPitForTimeOfDay.-\nend')
    assert(worker, 'J.RoshanPitForTimeOfDay is gone or reshaped')
    assert(not worker:find('IsSoakCandidate'),
        'the worker reads the gate -- then the resolver is not the one place')
    assert(not worker:find('IsModeTurbo'),
        'the worker reads the game mode -- then the resolver is not the one place')
end

tests['[coupling] this candidate did not also change the phase source'] = function()
    -- The premise the fix does NOT own (see the header): both legs must still
    -- get their day/night from the SAME reader, so the pit lever and the phase
    -- lever stay separable.  This goes red the day someone teaches one leg the
    -- engine's GetTimeOfDay() without teaching the other -- which is exactly
    -- the moment to stop and re-read, not a moment to re-baseline.
    local src = read_file('bots/FunLib/jmz_func.lua')
    local worker = src:match('function J%.RoshanPitForTimeOfDay.-\nend')
    assert(worker, 'J.RoshanPitForTimeOfDay is gone or reshaped')
    local _, nPhase = worker:gsub('J%.CheckTimeOfDay%s*%(%s*%)', '')
    assert(nPhase == 1, 'the worker reads the phase ' .. nPhase .. ' times; one read, ' ..
        'shared by both legs, is what keeps the two levers separable')
    assert(not worker:find('[^%w_]GetTimeOfDay%s*%('),
        'the worker calls the engine GetTimeOfDay() directly -- that is the OTHER lever ' ..
        '(GH #450), and it must not ride in on this one')
end

tests['[call sites] no bots/ file picks ONE pit constant by name'] = function()
    -- Load-bearing for the promote: if some file chose a pit itself, removing
    -- this gate would fix 25 call sites and miss that one.  Today exactly one
    -- file outside jmz_func names the constants -- mode_roshan_generic.lua --
    -- and it names BOTH in a disjunction ("am I at either pit"), which is
    -- mapping-agnostic.  A file that names one without the other is a second
    -- mapping decision and must be found before this id is promoted.
    local offenders = {}
    for _, path in ipairs(lua_sources()) do
        if path:find('jmz_func%.lua$') == nil then
            local src = read_file(path)
            local _, nRad = src:gsub('RadiantRoshanLoc', '')
            local _, nDire = src:gsub('DireRoshanLoc', '')
            if (nRad > 0) ~= (nDire > 0) then
                offenders[#offenders + 1] = path .. ' (radiant ' .. nRad .. ', dire ' .. nDire .. ')'
            end
        end
    end
    assert(#offenders == 0, 'these files pick one pit constant without the other, so they ' ..
        'carry a mapping decision this gate does not cover:\n  ' .. table.concat(offenders, '\n  '))
end

return tests
