
-- Corpus sweep for [towerpow]: J.WeAreStronger sums OUR nearby towers into our
-- side of the strength comparison and never sums THEIRS into theirs.
--
--   local nAllyTowers = bot:GetNearbyTowers(600, false)          -- jmz_func.lua
--   if J.IsValidBuilding(nAllyTowers[1]) then
--       ... ourPower = ourPower + power ; ourPowerRaw = ourPowerRaw + power
--   end
--   ...
--   local res = nOurPower > enemyPower      -- enemyPower has NO tower term
--
-- So a bot standing under its own tower is credited with the tower that shoots
-- for it (correct), and a bot standing under the enemy's is credited with
-- nothing for the tower that shoots AT it.  One column of a two-column
-- comparison carries structures; the other does not.
--
-- ⛔ RUN BY HAND, not from the suite: it loads every fixture once per hero
-- (~1039 loads) and tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0.  Same reason tests/_pipetower_sweep.lua sits
-- outside the suite.
--
--   lua5.1 tests/_towerpow_sweep.lua        (counters on stderr, DONE last)
--
-- ⛔ NOTHING IS ARMED HERE.  Both readings are rebuilt from the same getters the
-- shipped site calls, so the sweep cannot race soak_side.lua on disk (GH
-- #848/#856).
--
-- ⚠️ WHAT THIS SWEEP CANNOT COUNT, DECLARED FIRST.  The magnitude of either
-- tower term is `GetAttackDamage() * GetAttackSpeed()`, and BOTH are 0 on every
-- fixture unit -- a .dem slice carries neither (tests/mock/bot_api.lua:136, and
-- replay_fixture.lua:1052 says the same thing about structures by name).  On
-- this corpus `J.WeAreStronger` is therefore `0 > 0` = false on EVERY frame,
-- shipped and armed alike: the predicate is degenerate here for a reason that
-- predates this lever, so a flipped-decision witness is structurally
-- unavailable and is NOT claimed.  What IS ground truth in the dump is which
-- structures stand where and on whose team, so what this sweep prices is the
-- DOMAIN: the frames on which a real game would add a non-zero enemy-tower term
-- where shipped adds none.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local TOWER_RING = 600   -- the shipped ally-side radius, mirrored exactly

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

local c = { fixtures = 0, live = 0,
            with_buildings = 0,
            atower = 0,       -- subject frames with >= 1 own tower in the ring
            etower = 0,       -- subject frames with >= 1 ENEMY tower in the ring
            both = 0,
            etower_only = 0,  -- the asymmetry bites hardest: their tower, not ours
            adds = 0 }        -- frames where armed adds a term shipped omits
local witnesses = {}
local seen_fixture = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        c.fixtures = c.fixtures + 1
        if fx.buildings ~= nil and #fx.buildings > 0 then
            c.with_buildings = c.with_buildings + 1
        end
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                GAMEMODE_TURBO = nil                   -- luacheck: ignore
                local ok, _, bot = pcall(rf.load, path, u.name)
                GAMEMODE_TURBO = 23                    -- luacheck: ignore
                GetGameMode = function() return 23 end -- luacheck: ignore
                if ok and bot ~= nil then
                    c.live = c.live + 1
                    local tOwn   = bot:GetNearbyTowers(TOWER_RING, false) or {}
                    local tEnemy = bot:GetNearbyTowers(TOWER_RING, true) or {}
                    local nO, nE = #tOwn, #tEnemy
                    if nO > 0 then c.atower = c.atower + 1 end
                    if nE > 0 then c.etower = c.etower + 1 end
                    if nO > 0 and nE > 0 then c.both = c.both + 1 end
                    if nE > 0 and nO == 0 then c.etower_only = c.etower_only + 1 end
                    -- shipped adds a tower term iff nO > 0; armed additionally
                    -- adds one to the OTHER column iff nE > 0.
                    if nE > 0 then
                        c.adds = c.adds + 1
                        witnesses[#witnesses + 1] = string.format(
                            '%s  %s  t=%.1f  own=%d enemy=%d',
                            path:gsub('tests/fixtures/', ''),
                            u.name:gsub('npc_dota_hero_', ''), fx.time or -1, nO, nE)
                        seen_fixture[path] = true
                    end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

local nfx = 0
for _ in pairs(seen_fixture) do nfx = nfx + 1 end

for _, k in ipairs({ 'fixtures', 'with_buildings', 'live',
                     'atower', 'etower', 'both', 'etower_only', 'adds' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('P fixtures_with_a_change ', tostring(nfx), '\n')
for _, w in ipairs(witnesses) do out:write('W ', w, '\n') end
out:write('DONE\n')
