-- Corpus sweep for [tormring]: mode_side_shop_generic.lua reads the two halves
-- of ONE parity question off two DIFFERENT rings -- enemies 1600 (:61), allies
-- 1200 (:220) -- and the single consumer of both is the Tormentor bail
-- `if not J.IsRealInvisible(bot) and (#tInRangeEnemy > #tInRangeAlly)`.
--
-- ⛔ RUN BY HAND, not from the suite: it loads every fixture once per living
-- hero (~1000 loads) and tools/agent/lua_gate.py kills an unmeasured new test
-- at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which leaves the global
-- switch on disk and breaks every other gate test's "gate off" precondition.
-- Same reason tests/_roamring_sweep.lua sits outside the suite.
--
--   lua5.1 tests/_tormring_sweep.lua      (counters on stderr, DONE last)
--
-- ⚠️ THIS IS THE PREDICATE, NOT THE BRANCH. The consumer sits behind the
-- Tormentor chain (spawn window, average levels, `bot == ally`, tormentor_state
-- booleans that are bot-VM state a .dem does not carry, GH #27), so the
-- direction counters below are a CEILING on how often the bail changes, not a
-- fire rate. Said here rather than left for a wave to discover.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local ALLY_RING, ENEMY_RING = 1200, 1600

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
            shipped_bail = 0, wide_bail = 0, wide_down = 0, wide_up = 0,
            tight_bail = 0, tight_down = 0, tight_up = 0 }
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
                    local aTight = #(J.GetAlliesNearLoc(v, ALLY_RING) or {})
                    local aWide = #(J.GetAlliesNearLoc(v, ENEMY_RING) or {})
                    local eWide = #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {})
                    local eTight = #(J.GetEnemiesNearLoc(v, ALLY_RING) or {})

                    if aTight > 0 then c.allyloc_nonempty = c.allyloc_nonempty + 1 end
                    if eWide > 0 then c.enemyloc_nonempty = c.enemyloc_nonempty + 1 end
                    if aTight > c.ally_max then c.ally_max = aTight end
                    if eWide > c.enemy_max then c.enemy_max = eWide end
                    if aWide > aTight then c.ashell_nonempty = c.ashell_nonempty + 1 end
                    if eWide > eTight then c.eshell_nonempty = c.eshell_nonempty + 1 end

                    local shipped = (eWide > aTight)
                    local wide    = (eWide > aWide)     -- allies pulled out to 1600
                    local tight   = (eTight > aTight)   -- enemies pulled in to 1200
                    if shipped then c.shipped_bail = c.shipped_bail + 1 end
                    if wide then c.wide_bail = c.wide_bail + 1 end
                    if tight then c.tight_bail = c.tight_bail + 1 end
                    if shipped and not wide then
                        c.wide_down = c.wide_down + 1
                        witnesses[#witnesses + 1] = string.format(
                            'WIDE %s  %s  t=%.1f  a%d=%d a%d=%d e%d=%d e%d=%d',
                            path:gsub('tests/fixtures/', ''),
                            u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                            ALLY_RING, aTight, ENEMY_RING, aWide,
                            ENEMY_RING, eWide, ALLY_RING, eTight)
                    end
                    if wide and not shipped then c.wide_up = c.wide_up + 1 end
                    if shipped and not tight then
                        c.tight_down = c.tight_down + 1
                        witnesses[#witnesses + 1] = string.format(
                            'TIGHT %s  %s  t=%.1f  a%d=%d a%d=%d e%d=%d e%d=%d',
                            path:gsub('tests/fixtures/', ''),
                            u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                            ALLY_RING, aTight, ENEMY_RING, aWide,
                            ENEMY_RING, eWide, ALLY_RING, eTight)
                    end
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
                     'shipped_bail', 'wide_bail', 'wide_down', 'wide_up',
                     'tight_bail', 'tight_down', 'tight_up' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
for _, w in ipairs(witnesses) do out:write('W ', w, '\n') end
out:write('DONE\n')
