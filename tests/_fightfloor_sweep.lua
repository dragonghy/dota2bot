-- Corpus sweep for [fightfloor]: J.SafeToCommitFight's NUMBERS branch counts
-- every ALIVE ally near the engage point as a full fighter, including one that
-- is about to die.  The file already documents the failure at ONE caller
-- (jmz_func.lua:9954, `[fixture f_080225_wk_lane]`, "counted a 13%-HP WK ... as
-- a full 2v2 against the dual lane that then killed him") and patched it THERE,
-- not in the predicate the other six call sites read.
--
-- ⛔ RUN BY HAND, not from the suite: it loads all fixtures once per hero and
-- tools/agent/lua_gate.py kills an unmeasured new test at hook_timeout_seconds
-- = 20.0.  Same reason tests/_roamring_sweep.lua sits outside the suite.
--
--   lua5.1 tests/_fightfloor_sweep.lua      (counters on stderr, DONE last)
--
-- ⛔ NOTHING IS ARMED HERE.  Both readings are rebuilt from the same two
-- producers the shipped predicate calls, so the sweep cannot race the global
-- switch on disk (GH #848/#856) and its numbers do not depend on soak_side.lua.
--
-- UNIT OF COUNT.  J.SafeToCommitFight ignores its `bot` argument entirely, so
-- the predicate is a function of (asking TEAM, target) alone.  Rows are
-- therefore (subject, target) PAIRS -- every visible enemy hero of every live
-- subject -- and `frames_*` re-counts the same events per subject frame.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local RING = 1200
local FLOOR = 0.35

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

local c = { fixtures = 0, live = 0, pairs_seen = 0, frames_with_target = 0,
            lethal_true = 0, parity_true = 0, shipped_true = 0, armed_true = 0,
            down = 0, up = 0, frames_down = 0,
            ally_max = 0, enemy_max = 0, lowally_pairs = 0, lowally_frames = 0,
            down_unique = 0 }
local witnesses = {}
-- ⛔ The predicate ignores its `bot` argument, so one (team, target) reading
-- repeats once per living subject. `down_unique` is that reading counted once.
local seen_down = {}
local down_fixtures = {}

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
                    local tTargets = J.GetEnemiesNearLoc(bot:GetLocation(), 25000) or {}
                    if #tTargets > 0 then
                        c.frames_with_target = c.frames_with_target + 1
                    end
                    local bFrameDown, bFrameLow = false, false
                    for _, hT in pairs(tTargets) do
                        local vLoc = hT:GetLocation()
                        local tAllies = J.GetAlliesNearLoc(vLoc, RING) or {}
                        local tEnemies = J.GetEnemiesNearLoc(vLoc, RING) or {}
                        local tFighters = {}
                        for _, a in pairs(tAllies) do
                            if J.GetHP(a) >= FLOOR then
                                tFighters[#tFighters + 1] = a
                            end
                        end
                        local nBurst = J.GetTotalEstimatedDamageToTarget(tAllies, hT)
                        local bLethal = nBurst >= hT:GetHealth() + hT:GetHealthRegen() * 5.0
                        local bParity = #tAllies >= #tEnemies
                        local bArmedParity = #tFighters >= #tEnemies
                        local shipped = bLethal or bParity
                        local armed = bLethal or bArmedParity

                        c.pairs_seen = c.pairs_seen + 1
                        if #tAllies > c.ally_max then c.ally_max = #tAllies end
                        if #tEnemies > c.enemy_max then c.enemy_max = #tEnemies end
                        if bLethal then c.lethal_true = c.lethal_true + 1 end
                        if bParity then c.parity_true = c.parity_true + 1 end
                        if shipped then c.shipped_true = c.shipped_true + 1 end
                        if armed then c.armed_true = c.armed_true + 1 end
                        if #tFighters < #tAllies then
                            c.lowally_pairs = c.lowally_pairs + 1
                            bFrameLow = true
                        end
                        if shipped and not armed then
                            c.down = c.down + 1
                            bFrameDown = true
                            local key = path .. '|' .. hT:GetUnitName()
                            if not seen_down[key] then
                                seen_down[key] = true
                                c.down_unique = c.down_unique + 1
                                down_fixtures[path] = true
                            end
                            witnesses[#witnesses + 1] = string.format(
                                '%s  %s -> %s  t=%.1f  allies=%d fighters=%d enemies=%d',
                                path:gsub('tests/fixtures/', ''),
                                u.name:gsub('npc_dota_hero_', ''),
                                hT:GetUnitName():gsub('npc_dota_hero_', ''),
                                fx.time or -1, #tAllies, #tFighters, #tEnemies)
                        end
                        if armed and not shipped then c.up = c.up + 1 end
                    end
                    if bFrameDown then c.frames_down = c.frames_down + 1 end
                    if bFrameLow then c.lowally_frames = c.lowally_frames + 1 end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

for _, k in ipairs({ 'fixtures', 'live', 'frames_with_target', 'pairs_seen',
                     'ally_max', 'enemy_max', 'lowally_pairs', 'lowally_frames',
                     'lethal_true', 'parity_true', 'shipped_true', 'armed_true',
                     'down', 'up', 'frames_down', 'down_unique' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
local nDownFixtures = 0
for _ in pairs(down_fixtures) do nDownFixtures = nDownFixtures + 1 end
out:write('P down_fixtures ', tostring(nDownFixtures), '\n')
for _, w in ipairs(witnesses) do out:write('W ', w, '\n') end
out:write('DONE\n')
