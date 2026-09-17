-- Corpus sweep for [roamring]: mode_team_roam_generic.lua reads the two halves
-- of ONE parity question off two DIFFERENT rings (allies 2200, enemies 2000),
-- and the single consumer of both is `#nearbyAllies >= #nearbyEnemies`.
--
-- ⛔ RUN BY HAND, not from the suite: it loads all 112 fixtures once per hero
-- (~1039 loads) and tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0 -- mid-`ss.arm` that leaves the global switch on
-- disk and breaks every other gate test's "gate off" precondition. Same reason
-- tests/_soloclaim_sweep.lua sits outside the suite.
--
--   lua5.1 tests/_roamring_sweep.lua      (counters on stderr, DONE last)
--
-- MEASURED 2026-09-17 on 112 fixtures / 1039 live hero frames:
--
--   live                1039
--   allyloc_nonempty    1039   <- J.GetAlliesNearLoc includes the asker
--   enemyloc_nonempty    594
--   ally_max               5    enemy_max            4
--   eshell_nonempty       57   <- frames with an enemy in the 2000-2200 shell
--   ashell_nonempty       30   <- frames with an ally  in the same shell
--   shipped_true         954
--   wide_true            944   <- enemies read off the ALLY ring (this lever)
--   wide_down             10   wide_up            0
--   tight_true           952   <- the OTHER unification: allies pulled to 2000
--   tight_down             2   tight_up           0
--
-- ⛔ `wide_up 0` is a reading only because `wide_down` is 10 in the SAME tally:
-- a direction column of zeros cannot tell "the direction holds" from "the tally
-- never ran". Both unifications are one-directional, as the construction says
-- they must be (a superset can only grow #enemies; a subset can only shrink
-- #allies); the shipped lever takes the one with 5x the domain, and the reason
-- it is the right 5x rather than a bigger blunt instrument is in the header of
-- J.GetRoamParityRadius.
--
-- ⚠️ THIS IS THE PREDICATE, NOT THE BRANCH. The consumer at :398 sits behind a
-- long mode/activity chain that a fixture cannot reproduce (bot:GetActiveMode()
-- is bot-VM state the .dem does not carry, GH #27), so 10 is a CEILING on how
-- often the branch itself changes, not a fire rate. Said here rather than left
-- for a wave to discover.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local ALLY_RING, ENEMY_RING = 2200, 2000

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

local c = { fixtures = 0, live = 0, allyloc_nonempty = 0, enemyloc_nonempty = 0,
            ally_max = 0, enemy_max = 0, ashell_nonempty = 0, eshell_nonempty = 0,
            shipped_true = 0, wide_true = 0, wide_down = 0, wide_up = 0,
            tight_true = 0, tight_down = 0, tight_up = 0 }
local witnesses = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        c.fixtures = c.fixtures + 1
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                GAMEMODE_TURBO = nil                   -- luacheck: ignore
                local ok, J, bot = pcall(rf.load, path, u.name)
                GAMEMODE_TURBO = 23                    -- luacheck: ignore
                GetGameMode = function() return 23 end -- luacheck: ignore
                if ok and bot ~= nil then
                    c.live = c.live + 1
                    local v = bot:GetLocation()
                    local aWide = #(J.GetAlliesNearLoc(v, ALLY_RING) or {})
                    local aTight = #(J.GetAlliesNearLoc(v, ENEMY_RING) or {})
                    local eTight = #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {})
                    local eWide = #(J.GetEnemiesNearLoc(v, ALLY_RING) or {})

                    if aWide > 0 then c.allyloc_nonempty = c.allyloc_nonempty + 1 end
                    if eTight > 0 then c.enemyloc_nonempty = c.enemyloc_nonempty + 1 end
                    if aWide > c.ally_max then c.ally_max = aWide end
                    if eTight > c.enemy_max then c.enemy_max = eTight end
                    if aWide > aTight then c.ashell_nonempty = c.ashell_nonempty + 1 end
                    if eWide > eTight then c.eshell_nonempty = c.eshell_nonempty + 1 end

                    local shipped = (aWide >= eTight)
                    local wide    = (aWide >= eWide)    -- this lever
                    local tight   = (aTight >= eTight)  -- the other unification
                    if shipped then c.shipped_true = c.shipped_true + 1 end
                    if wide then c.wide_true = c.wide_true + 1 end
                    if tight then c.tight_true = c.tight_true + 1 end
                    if shipped and not wide then
                        c.wide_down = c.wide_down + 1
                        witnesses[#witnesses + 1] = string.format(
                            '%s  %s  t=%.1f  a%d=%d e%d=%d e%d=%d',
                            path:gsub('tests/fixtures/', ''),
                            u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                            ALLY_RING, aWide, ENEMY_RING, eTight, ALLY_RING, eWide)
                    end
                    if wide and not shipped then c.wide_up = c.wide_up + 1 end
                    if shipped and not tight then c.tight_down = c.tight_down + 1 end
                    if tight and not shipped then c.tight_up = c.tight_up + 1 end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

for _, k in ipairs({ 'fixtures', 'live', 'allyloc_nonempty', 'enemyloc_nonempty',
                     'ally_max', 'enemy_max', 'ashell_nonempty', 'eshell_nonempty',
                     'shipped_true', 'wide_true', 'wide_down', 'wide_up',
                     'tight_true', 'tight_down', 'tight_up' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
for _, w in ipairs(witnesses) do out:write('W ', w, '\n') end
out:write('DONE\n')
