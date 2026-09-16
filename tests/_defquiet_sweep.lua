-- The instrument behind tests/test_defquiet_idle_defender.lua.  NOT collected
-- by run_tests.lua (it runs tests/test_*.lua only): a full sweep reloads
-- aba_defend once per (fixture, hero, lane, leg) and measures far past the Lua
-- push gate's per-test cap.
--
--   lua5.1 tests/_defquiet_sweep.lua
--
-- WHAT IT ANSWERS.  aba_defend.ShouldDefend counts the enemies near a building
-- (`nNearby` = recently-seen enemy heroes inside 1600 + floor of a weighted
-- creep sum inside nRadius) and then runs a role ladder over that count: the
-- ladder has branches for nNearby == 1, == 2, == 3 and >= 4, and NO branch for
-- nNearby == 0.  Everything the ladder declines then falls into the escalation
-- block, whose last clause is
--
--     if not result and pos == GetClosestAllyPos({2, 3}, building) then
--         result = true
--
-- -- a clause with no threat precondition at all.  So on a building with zero
-- enemies near it, exactly one hero per team still answers "yes, defend this",
-- and in GetDefendDesireHelper that answer is not cosmetic: it skips the
-- `if not shouldDef` bail-out to VeryLow, adds +0.1 to the desire cap
-- (`capBoost`) and lifts the desire floor from VeryLow to Low (`baseFloor`).
--
-- For every (fixture, hero, lane) triple this sweep drives the real
-- Defend.ShouldDefend on the real frame, shipped and with 'defquiet' armed,
-- and reports where the answer moves.  Because armed only ever suppresses the
-- fallback when nNearby == 0, the differing set IS the measured
-- "nobody is attacking this building and we designate a defender anyway" set --
-- the sweep does not have to re-derive nNearby to name it.
--
-- The enemy-hero count printed next to each hit is re-derived here from
-- J.GetLastSeenEnemiesNearLoc rather than taken from the function under
-- measurement, for the same reason tests/_pushtier_sweep.lua re-derives the
-- tier vector.  It is the HERO half of nNearby only; the creep half cannot be
-- read back out of ShouldDefend, which is precisely why the differing set, not
-- this number, is the headline.
--
-- ONE DECLARED STAND-IN.  GetLaneFrontLocation is unresolved in this corpus and
-- tests/mock/replay_fixture.lua REFUSES the call rather than answering (0,0,0)
-- (GH #61).  ShouldDefend never reads a lane front -- it reads the building it
-- is handed -- so this sweep declares the call only to keep aba_defend's
-- module-level state constructible, and every claim below is about buildings.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local W = io.stdout          -- NOT print: tests/mock/bot_api.lua sets `print`
                             -- to an empty function, so a print probe in this
                             -- world is EXIT=0 with zero lines -- the same
                             -- shape as "nothing had an answer".

--- Load one real frame with the real aba_defend on top of it.
--- opts.armed arms 'defquiet' and nothing else.
local function world(sFix, sSubj, bArmed)
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    rf = require('mock.replay_fixture')
    local J, bot = rf.load(sFix, sSubj)
    if bot == nil then return nil end
    J.IsSoakCandidate = function(id) return id == 'defquiet' and bArmed == true end
    _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end  -- luacheck: ignore
    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, Defend
end

-- ⛔ REBUILT PER FRAME, NEVER MEMOISED, and never read before a frame is
-- loaded.  LANE_TOP and friends do not exist until tests/mock/bot_api.lua has
-- run; at module scope they are plain nil, and `{ [LANE_TOP] = 'top' }` is a
-- "table index is nil" abort (measured, first run of this file).  The same
-- shape in a place that does NOT abort is 0NEXT31: a cross-frame cached key
-- reads as a plausible statement about the corpus.
local function lanes()
    return { LANE_TOP, LANE_MID, LANE_BOT },
           { [LANE_TOP] = 'top', [LANE_MID] = 'mid', [LANE_BOT] = 'bot' }
end

--- Drive ShouldDefend on all three lanes of one (fixture, hero) pair.
--- Returns a lane-keyed table of booleans, plus the lane-keyed enemy-hero
--- count near each furthest building.  nil when the frame carries no readable
--- building at all (an instrument gap, reported separately, never folded in).
local function decide(sFix, sSubj, bArmed)
    local J, bot, Defend = world(sFix, sSubj, bArmed)
    if bot == nil then return nil end
    local answer, near, any = {}, {}, false
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        local ok, res = pcall(Defend.GetFurthestBuildingOnLane, lane)
        local bld = ok and res ~= nil and res[1] or nil
        if bld ~= nil and bld.IsAlive ~= nil and bld:IsAlive() then
            local ok2, should = pcall(Defend.ShouldDefend, bot, bld, 1600)
            if ok2 then
                any = true
                answer[lane] = should and true or false
                near[lane] = #J.GetLastSeenEnemiesNearLoc(bld:GetLocation(), 1600)
            end
        end
    end
    if not any then return nil end
    return answer, near, J.GetPosition(bot)
end

local function fixtures()
    local out = {}
    local pipe = io.popen('ls tests/fixtures/*.lua')
    for line in pipe:lines() do out[#out + 1] = line end
    pipe:close()
    return out
end

local nPairs, nSkipped, nTriples = 0, 0, 0
local nShipped, nArmed, nMoved = 0, 0, 0
local movedQuiet, movedLoud = 0, 0
local byPos = {}

for _, sFix in ipairs(fixtures()) do
    local _, _, heroes = rf.load(sFix)
    local names = {}
    if heroes then for name in pairs(heroes) do names[#names + 1] = name end end
    table.sort(names)
    for _, sSubj in ipairs(names) do
        nPairs = nPairs + 1
        local shipped, near, pos = decide(sFix, sSubj, false)
        if shipped == nil then
            nSkipped = nSkipped + 1
        else
            local armed = decide(sFix, sSubj, true)
            local LANES, LANE_NAME = lanes()
            for _, lane in ipairs(LANES) do
                if shipped[lane] ~= nil and armed[lane] ~= nil then
                    nTriples = nTriples + 1
                    if shipped[lane] then nShipped = nShipped + 1 end
                    if armed[lane] then nArmed = nArmed + 1 end
                    if shipped[lane] ~= armed[lane] then
                        nMoved = nMoved + 1
                        if near[lane] == 0 then movedQuiet = movedQuiet + 1
                        else movedLoud = movedLoud + 1 end
                        byPos[pos] = (byPos[pos] or 0) + 1
                        W:write(string.format(
                            'MOVED %-50s %-20s pos=%s %s  enemies_near=%d  %s -> %s\n',
                            (sFix:gsub('tests/fixtures/', '')),
                            (sSubj:gsub('npc_dota_hero_', '')), tostring(pos),
                            LANE_NAME[lane], near[lane],
                            tostring(shipped[lane]), tostring(armed[lane])))
                    end
                end
            end
        end
    end
end

W:write(string.format(
    '\nPAIRS %d   skipped(no readable building on any lane) %d\n', nPairs, nSkipped))
W:write(string.format('TRIPLES driven %d\n', nTriples))
W:write(string.format('ShouldDefend TRUE   shipped %d (%.1f%%)   armed %d (%.1f%%)\n',
    nShipped, nTriples > 0 and nShipped / nTriples * 100 or 0,
    nArmed, nTriples > 0 and nArmed / nTriples * 100 or 0))
W:write(string.format('MOVED %d   of which enemies_near==0 %d   enemies_near>0 %d\n',
    nMoved, movedQuiet, movedLoud))
local poss = {}
for p in pairs(byPos) do poss[#poss + 1] = p end
table.sort(poss)
for _, p in ipairs(poss) do
    W:write(string.format('  moved at drafted role %s: %d\n', tostring(p), byPos[p]))
end
