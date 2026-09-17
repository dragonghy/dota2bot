-- Pricing probe for the ring-centre lever (backlog 0NEXT38 candidate (1), the
-- one the previous round registered as "next round's first choice").  Asks ONE
-- question BEFORE any code is written: is the population non-empty, and is it
-- non-empty in the sub-domain the SHIPPED `#hAllyList <= 1` guard still lets
-- through with nothing else armed?
--
-- ⛔ THE ANSWER WAS NO, AND THAT IS WHY THIS FILE IS KEPT.  Measured
-- 2026-09-17, 112 fixtures / 1039 live hero frames:
--
--   P live                    1039
--   P ally2plus                 55   <- the shipped guard FIRES on 984/1039
--   P enemies_seen             806
--   P unitring_nonempty        500
--   P pair_total               806
--   P pair_extra                43   <- (frame,enemy) pairs with an ally near
--                                       the enemy that the asker's ring misses
--   P frame_has_extra           31   <- the lever's raw population, 3.0%
--   P frame_has_extra_2plus      0   <- ⛔ ...intersected with "the guard lets
--                                       me through": ZERO of 1039
--   P extra_max                  2
--
-- So inside J.IsOtherAllysTarget the ring-centre repair has an EMPTY domain
-- while the shipped guard stands, and making the guard count the wider list
-- instead is live only when the UNPROMOTED 'soloclaim' is also armed -- the
-- 'pullcad' conjunction trap (GH #622).  Not a lever; see
-- tests/test_ring_subject_census.py for the whole triage.
--
-- ⚠️ `frame_has_extra_2plus = 0` is not a fluke of sampling: >=2 allies inside
-- 800 of me means the team is GROUPED, and a grouped ally near the enemy is
-- usually inside my ring too.  Reported as measured, with that reading.
--
-- Usage: lua5.1 tests/_claimring_probe.lua   (counters on stderr, DONE last)
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local t = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then t[#t + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(t)
    return t
end

local c = { live = 0, ally2plus = 0, enemies_seen = 0,
            frame_has_extra = 0, frame_has_extra_2plus = 0,
            pair_total = 0, pair_extra = 0, extra_max = 0,
            unitring_nonempty = 0 }

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                GAMEMODE_TURBO = nil                   -- luacheck: ignore
                local ok, J, bot = pcall(rf.load, path, u.name)
                GAMEMODE_TURBO = 23                    -- luacheck: ignore
                GetGameMode = function() return 23 end -- luacheck: ignore
                if ok and bot ~= nil then
                    c.live = c.live + 1
                    local ring = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE) or {}
                    local inring = {}
                    for _, a in pairs(ring) do inring[a] = true end
                    local b2 = #ring >= 2
                    if b2 then c.ally2plus = c.ally2plus + 1 end

                    -- The plausible arguments: every enemy hero the frame lets
                    -- this bot see.  Callers pass an enemy unit.
                    local foes = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}
                    local bExtraHere = false
                    for _, foe in pairs(foes) do
                        c.enemies_seen = c.enemies_seen + 1
                        c.pair_total = c.pair_total + 1
                        local near = J.GetAlliesNearLoc(foe:GetLocation(), 800) or {}
                        if #near > 0 then
                            c.unitring_nonempty = c.unitring_nonempty + 1
                        end
                        local nExtra = 0
                        for _, a in pairs(near) do
                            if a ~= bot and not inring[a] then nExtra = nExtra + 1 end
                        end
                        if nExtra > 0 then
                            c.pair_extra = c.pair_extra + 1
                            bExtraHere = true
                            if nExtra > c.extra_max then c.extra_max = nExtra end
                        end
                    end
                    if bExtraHere then
                        c.frame_has_extra = c.frame_has_extra + 1
                        if b2 then
                            c.frame_has_extra_2plus = c.frame_has_extra_2plus + 1
                        end
                    end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

for _, k in ipairs({ 'live', 'ally2plus', 'enemies_seen', 'unitring_nonempty',
                     'pair_total', 'pair_extra', 'frame_has_extra',
                     'frame_has_extra_2plus', 'extra_max' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('DONE\n')
