-- The instrument behind tests/test_threatcreep_lane_tiebreak.lua.  NOT
-- collected by run_tests.lua (it runs tests/test_*.lua only): it reloads
-- aba_defend once per fixture and measures far past the Lua push gate's
-- per-test cap.
--
--   lua5.1 tests/_threatcreep_sweep.lua
--
-- WHAT IT ANSWERS.  aba_defend.GetThreatenedLane scores {Top, Mid, Bot} and
-- takes the strict maximum from a `bestScore = -1` seed, so EVERY TIE RESOLVES
-- TO THE FIRST LANE.  A lane's score is `recentHeroCount * 10`, plus -- only
-- when that count is zero -- a creep term `math.min(w * 0.4, 0.9)` where `w` is
-- WeightedEnemiesAroundLocation's FLOORED weighted sum.  A lane creep is priced
-- 0.2 and a full wave is four of them, so 4 * 0.2 = 0.8 floors to 0: the same
-- score an EMPTY lane gets.  This sweep measures how often that matters, in two
-- separate readings that are never folded together:
--
--   (1) THE TIE READING.  Per frame, how many lanes have zero recently-seen
--       enemy heroes within 1800 of their anchor.  Three-of-three is the frame
--       where the answer is decided by the creep term alone -- i.e. where the
--       floor is the whole difference between "which lane is being pushed" and
--       the constant Top.
--   (2) THE CREEP READING.  Per frame and per lane, the floored and UNFLOORED
--       weighted sums the real function returns.
--
-- ⛔ READING (2) IS AN INSTRUMENT GAP, NOT A FACT ABOUT DOTA, and this file
-- prints it as such.  tests/mock/replay_fixture.lua answers
-- GetUnitList(UnitType.Enemies) -- the sole input to
-- WeightedEnemiesAroundLocation -- with an empty table (GH #863).  So `raw` is
-- 0 by CONSTRUCTION here and a zero in that column says nothing whatever about
-- how many creeps were near that tower.  Per the charter's rule for reading a
-- zero (0NEXT33 §丙: find the same reader's non-zero first), this file also
-- prints reading (1), which comes from a DIFFERENT reader
-- (GetHeroLastSeenInfo) and does produce non-zeros -- that is what says the
-- loader is not simply blind to everything.
--
-- HOW THE FILE-LOCAL IS REACHED, and why this is not a copy of the code.
-- GetThreatenedLane, WeightedEnemiesAroundLocation and _recentHeroCountNear are
-- file-locals of bots/FunLib/aba_defend.lua; the module's only exported
-- consumer, GetDefendDesireHelper, returns VeryLow long before reaching them on
-- this corpus.  So this sweep reads the SHIPPED SOURCE TEXT, splices one
-- `____exports.__probe = {...}` line in front of its final `return ____exports`
-- and loads that.  Every byte under measurement is the shipped byte; the splice
-- adds an export and changes no statement.  If the tail of the file ever stops
-- being `return ____exports`, the assert below aborts rather than measuring
-- something else.
--
-- ONE DECLARED STAND-IN.  GetLaneFrontLocation is unresolved in this corpus and
-- the loader REFUSES the call rather than answering (0,0,0) (GH #61).  Nothing
-- on the GetThreatenedLane path reads a lane front, so the declaration below
-- only keeps aba_defend's module-level state constructible.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local W = io.stdout          -- NOT print: tests/mock/bot_api.lua sets `print`
                             -- to an empty function, so a print probe in this
                             -- world is EXIT=0 with zero lines -- the same
                             -- shape as "nothing had an answer".

local SRC = 'bots/FunLib/aba_defend.lua'
local TAIL = 'return ____exports\n'
local PROBE = '____exports.__probe = {GetThreatenedLane = GetThreatenedLane,'
    .. ' WeightedEnemiesAroundLocation = WeightedEnemiesAroundLocation,'
    .. ' recentHeroCountNear = _recentHeroCountNear,'
    .. ' GetHighGroundEdgeWaitPoint = GetHighGroundEdgeWaitPoint,'
    .. ' IsValidBuildingTarget = IsValidBuildingTarget}\n'

--- The shipped source with one export spliced in ahead of its final return.
local function probed_source()
    local f = assert(io.open(SRC, 'r'))
    local src = f:read('*a')
    f:close()
    assert(src:sub(-#TAIL) == TAIL,
        SRC .. ' no longer ends in `' .. TAIL:gsub('\n', '') .. '` -- the '
        .. 'splice below would land somewhere else. Fix the splice, do not '
        .. 'loosen this assert.')
    return src:sub(1, #src - #TAIL) .. PROBE .. TAIL
end

--- Load one real frame with the real aba_defend (plus the probe export).
local function world(sFix, sSubj, bArmed)
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    rf = require('mock.replay_fixture')
    local J, bot = rf.load(sFix, sSubj)
    if bot == nil then return nil end
    J.IsSoakCandidate = function(id) return id == 'threatcreep' and bArmed == true end
    _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end  -- luacheck: ignore
    local chunk = assert(loadstring(probed_source(), '@' .. SRC .. '[probe]'))
    return J, bot, chunk()
end

-- ⛔ REBUILT PER FRAME, NEVER MEMOISED (0NEXT31): LANE_TOP and friends do not
-- exist until tests/mock/bot_api.lua has run.
local function lanes()
    return { LANE_TOP, LANE_MID, LANE_BOT },
           { [LANE_TOP] = 'top', [LANE_MID] = 'mid', [LANE_BOT] = 'bot' }
end

--- The per-lane inputs GetThreatenedLane scores, re-derived through the SAME
--- file-local helpers the function itself calls (never a re-implementation).
local function inputs(D, bot)
    local out = {}
    local LANES = lanes()
    for _, ln in ipairs(LANES) do
        local ok, res = pcall(D.GetFurthestBuildingOnLane, ln)
        if not ok or res == nil then return nil end
        local bld, _urgent, tier = unpack(res)
        local ok2, anchor = pcall(function()
            return D.__probe.IsValidBuildingTarget(bld) and tier < 3
                and bld:GetLocation()
                or D.__probe.GetHighGroundEdgeWaitPoint(bot:GetTeam(), ln)
        end)
        if not ok2 or anchor == nil then return nil end
        local heroCnt = D.__probe.recentHeroCountNear(anchor, 1800)
        local w, raw = D.__probe.WeightedEnemiesAroundLocation(anchor, 1200)
        out[ln] = { tier = tier, hero = heroCnt, w = w, raw = raw }
    end
    return out
end

local function fixtures()
    local out = {}
    local pipe = io.popen('ls tests/fixtures/*.lua')
    for line in pipe:lines() do out[#out + 1] = line end
    pipe:close()
    return out
end

local nFrames, nSkipped = 0, 0
local nAllQuiet, nSomeLoud = 0, 0
local nTopWhenAllQuiet, nMoved = 0, 0
local heroNonZeroLanes, creepNonZeroLanes, nLanes = 0, 0, 0
local quietByCount = { [0] = 0, 0, 0, 0 }

for _, sFix in ipairs(fixtures()) do
    -- One subject per fixture: GetThreatenedLane reads no per-bot state, so a
    -- second hero on the same frame would be the SAME reading counted twice.
    local _, _, heroes = rf.load(sFix)
    local names = {}
    if heroes then for name in pairs(heroes) do names[#names + 1] = name end end
    table.sort(names)
    if #names == 0 then
        nSkipped = nSkipped + 1
    else
        local J, bot, D = world(sFix, names[1], false)
        local inp = bot and inputs(D, bot) or nil
        if inp == nil then
            nSkipped = nSkipped + 1
        else
            nFrames = nFrames + 1
            local LANES, LANE_NAME = lanes()
            local quiet = 0
            for _, ln in ipairs(LANES) do
                nLanes = nLanes + 1
                if inp[ln].hero == 0 then quiet = quiet + 1
                else heroNonZeroLanes = heroNonZeroLanes + 1 end
                if inp[ln].raw > 0 then creepNonZeroLanes = creepNonZeroLanes + 1 end
            end
            quietByCount[quiet] = (quietByCount[quiet] or 0) + 1
            local shipped = D.__probe.GetThreatenedLane()
            local _, _, D2 = world(sFix, names[1], true)
            local armed = D2.__probe.GetThreatenedLane()
            if armed ~= shipped then nMoved = nMoved + 1 end
            if quiet == 3 then
                nAllQuiet = nAllQuiet + 1
                if shipped == LANES[1] then nTopWhenAllQuiet = nTopWhenAllQuiet + 1 end
            else
                nSomeLoud = nSomeLoud + 1
            end
            W:write(string.format('%-58s quiet=%d shipped=%-3s armed=%-3s\n',
                sFix:gsub('^tests/fixtures/', ''), quiet,
                LANE_NAME[shipped] or '?', LANE_NAME[armed] or '?'))
        end
    end
end

W:write('\n')
W:write(string.format('frames %d  skipped %d  lanes %d\n', nFrames, nSkipped, nLanes))
W:write(string.format('quiet-lane histogram (lanes with 0 recently-seen enemy heroes within 1800):\n'))
for k = 0, 3 do
    W:write(string.format('  %d/3 quiet : %d frames\n', k, quietByCount[k] or 0))
end
W:write(string.format('all-three-quiet frames %d  of which shipped answers Top %d\n',
    nAllQuiet, nTopWhenAllQuiet))
W:write(string.format('frames with at least one loud lane %d\n', nSomeLoud))
W:write(string.format('READING 1 (GetHeroLastSeenInfo, a DIFFERENT reader): lanes with a non-zero hero count %d / %d\n',
    heroNonZeroLanes, nLanes))
W:write(string.format('READING 2 (GetUnitList(Enemies), the gapped reader): lanes with a non-zero raw creep weight %d / %d\n',
    creepNonZeroLanes, nLanes))
W:write(string.format('armed MOVED the answer on %d / %d frames (expected 0: reading 2 is 0 by construction)\n',
    nMoved, nFrames))
