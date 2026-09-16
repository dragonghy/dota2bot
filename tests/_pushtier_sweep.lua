-- The instrument behind tests/test_pushtier_min_tie.lua.  NOT collected by
-- run_tests.lua (it runs tests/test_*.lua only) because a full sweep drives
-- Push.WhichLaneToPush 1,380 times and measures ~30s, which is ten times the
-- Lua push gate's per-test cap.
--
--   lua5.1 tests/_pushtier_sweep.lua
--
-- WHAT IT ANSWERS.  For every (fixture, hero) pair in tests/fixtures/, with
-- that hero as the bot:
--   * the ENEMY lane-tier vector on that frame (GetLaneBuildingTier's own
--     ladder, re-derived here from GetTower/GetBarracks so the sweep does not
--     inherit the function it is measuring);
--   * whether the minimum tier is attained once (the shipped chain fires),
--     twice, or three times (it fires on nobody);
--   * whether arming 'pushtier' moves the lane WhichLaneToPush returns.
--
-- THE ONE DECLARED STAND-IN, and why it is not free-hand.  GetLaneFrontLocation
-- is unresolved in the corpus -- the dump carries no lane fronts, and
-- tests/mock/replay_fixture.lua REFUSES the call rather than answering (0,0,0)
-- (GH #61).  This sweep declares each lane front to be the location of the
-- ENEMY'S FRONTMOST STANDING TOWER on that lane, which is a real coordinate off
-- the real frame rather than an invented one, and which moves with the same
-- building state the tier ladder reads.  A pair whose enemy has no standing
-- tower on some lane is SKIPPED, not guessed at; those 430 pairs are the 43
-- fixtures that carry no buildings at all, i.e. an instrument gap and not a
-- game state.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

local W = io.stdout          -- NOT print: tests/mock/bot_api.lua sets `print`
                             -- to an empty function, so a print probe in this
                             -- world is EXIT=0 with zero lines -- the same
                             -- shape as "nothing had an answer".

-- ⛔ REBUILT PER FRAME, NEVER MEMOISED.  tests/mock/replay_fixture.lua resolves
-- tower and barracks slots POSITIONALLY out of whatever buildings the frame
-- carries, so TOWER_TOP_1 and friends are not constants across loads: on a
-- frame with towers they read 0..8, on a frame with none they read unresolved
-- sentinels (1036..).  Caching the first frame's numbers therefore asks a
-- later frame for slots it does not have, and every lane comes back EMPTY --
-- which presents as "this corpus carries no buildings", i.e. as a plausible
-- reading of the corpus rather than as a failure of the sweep.  Measured: the
-- memoised version read 1120 of 1120 pairs as unreadable.
local function lane_tables()
    return {
        [LANE_TOP] = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 },
        [LANE_MID] = { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 },
        [LANE_BOT] = { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 },
    }, {
        [LANE_TOP] = { BARRACKS_TOP_MELEE, BARRACKS_TOP_RANGED },
        [LANE_MID] = { BARRACKS_MID_MELEE, BARRACKS_MID_RANGED },
        [LANE_BOT] = { BARRACKS_BOT_MELEE, BARRACKS_BOT_RANGED },
    }
end

--- Enemy lane fronts (frontmost standing tower) and the tier vector, both read
--- off the live frame.
local function fronts_and_tiers(enemy)
    local slots, rax = lane_tables()
    local fronts, tiers = {}, {}
    for lane, list in pairs(slots) do
        local tier = 4
        for i, s in ipairs(list) do
            local t = GetTower(enemy, s)
            if t ~= nil then
                if fronts[lane] == nil then fronts[lane] = t:GetLocation() end
                if tier == 4 then tier = i end
            end
        end
        if tier == 4 then
            for _, b in ipairs(rax[lane]) do
                if GetBarracks(enemy, b) ~= nil then tier = 3 end
            end
        end
        tiers[lane] = tier
    end
    return fronts, tiers
end

--- Drive the real Push.WhichLaneToPush on one (fixture, hero) pair.
--- Returns nil when the frame cannot supply all three lane fronts.
local function decide(sFix, sSubj)
    local _, bot = rf.load(sFix, sSubj)
    if bot == nil then return nil end
    local fronts, tiers = fronts_and_tiers(GetOpposingTeam())
    if fronts[LANE_TOP] == nil or fronts[LANE_MID] == nil
        or fronts[LANE_BOT] == nil then
        return nil
    end
    _G.GetLaneFrontLocation = function(_, lane) return fronts[lane] end  -- luacheck: ignore
    local Push = dofile('bots/FunLib/aba_push.lua')
    local ok, lane = pcall(Push.WhichLaneToPush, bot, LANE_MID)
    if not ok then return nil end
    return lane, tiers, bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

local function tie_class(tiers)
    local nMin = math.min(tiers[LANE_TOP], tiers[LANE_MID], tiers[LANE_BOT])
    local n = 0
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        if tiers[lane] == nMin then n = n + 1 end
    end
    return n == 1 and 'unique' or (n == 2 and 'tie2' or 'tie3')
end

local function fixtures()
    local out = {}
    local pipe = io.popen('ls tests/fixtures/*.lua')
    for line in pipe:lines() do out[#out + 1] = line end
    pipe:close()
    return out
end

local driven = { unique = 0, tie2 = 0, tie3 = 0 }
local moved  = { unique = 0, tie2 = 0, tie3 = 0 }
local nTotal, nSkipped = 0, 0

for _, sFix in ipairs(fixtures()) do
    local _, _, heroes = rf.load(sFix)
    local names = {}
    if heroes then for name in pairs(heroes) do names[#names + 1] = name end end
    table.sort(names)
    for _, sSubj in ipairs(names) do
        nTotal = nTotal + 1
        local lane, tiers, side = decide(sFix, sSubj)
        if lane == nil then
            nSkipped = nSkipped + 1
        else
            local class = tie_class(tiers)
            driven[class] = driven[class] + 1
            local armed
            ss.with_candidate('pushtier', function()
                armed = decide(sFix, sSubj)
            end, side)
            if armed ~= lane then
                moved[class] = moved[class] + 1
                W:write(string.format('MOVED %-52s %-22s %-7s tiers=%d,%d,%d  %s -> %s\n',
                    (sFix:gsub('tests/fixtures/', '')),
                    (sSubj:gsub('npc_dota_hero_', '')), side,
                    tiers[LANE_TOP], tiers[LANE_MID], tiers[LANE_BOT],
                    tostring(lane), tostring(armed)))
            end
        end
    end
end

W:write(string.format('\nPAIRS %d   skipped(no readable enemy lane front) %d   driven %d\n',
    nTotal, nSkipped, nTotal - nSkipped))
for _, class in ipairs({ 'unique', 'tie2', 'tie3' }) do
    W:write(string.format('%-7s driven %4d   moved %3d\n',
        class, driven[class], moved[class]))
end
