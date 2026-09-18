-- Corpus sweep for [smokeself]: the Smoke of Deceit desire asks whether an
-- enemy stands near any of the caster's ALLIES, and never whether one stands
-- near the CASTER -- who is the unit the smoke is centred on.
--
--   -- bots/ability_item_usage_generic.lua, X.ConsiderItemDesire['item_smoke_of_deceit']
--   local nInRangeAlly   = J.GetAllyList(bot, 1200)
--   local nInRangeEnemy  = J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
--   local nInRangeTower  = bot:GetNearbyTowers(1200, true)
--   local isThereEnemyNearby = false
--   if (#nInRangeEnemy == 0) or (#nInRangeTower == 0) then
--       for _, allyHero in pairs(nInRangeAlly) do ...
--           isThereEnemyNearby = true            -- the ONLY writer
--   end
--   if not isThereEnemyNearby then ... return BOT_ACTION_DESIRE_HIGH ... end
--
-- The caster's own two readings are computed and then spent on the GATE of the
-- ally scan; nothing lets them answer the question.  And the scan's subject is
-- always an ally: J.GetAllyList is J.GetNearbyHeroes(bot, ..., false, ...),
-- which never returns self (jmz_func.lua:9997).  So the caster is missing from
-- its own census in two independent ways:
--   (A) both > 0  -- an enemy hero AND an enemy tower within 1200 -- makes the
--       gate FALSE, the scan never runs, and the flag stays false;
--   (B) no ally within 1200 makes the scan body never run, whatever the gate
--       said, so a SOLO bot standing next to an enemy reads "clear".
--
-- ⛔ RUN BY HAND, not from the suite: it loads every fixture once per hero and
-- tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0.  Same reason tests/_towerpow_sweep.lua and
-- tests/_pipetower_sweep.lua sit outside the suite.
--
--   lua5.1 tests/_smokeself_sweep.lua        (counters on stderr, DONE last)
--
-- ⛔ NOTHING IS ARMED HERE.  Both readings are rebuilt from the same getters the
-- shipped site calls, so the sweep cannot race soak_side.lua on disk (GH
-- #848/#856).
--
-- ⚠️ WHAT THIS SWEEP PRICES, DECLARED FIRST.  Unlike 'towerpow' (whose terms
-- are GetAttackDamage()*GetAttackSpeed(), which a .dem slice does not carry),
-- every input here is pure geometry plus team membership, and BOTH are ground
-- truth in the dump.  So this sweep prices the DECISION, not just the domain:
-- `flip` counts frames where the shipped flag is false and the armed flag is
-- true, i.e. frames where arming withholds a smoke the shipped tree would
-- consider.  It does NOT price how often the bot actually HOLDS a smoke -- item
-- ownership and the enclosing desire branches are not walked here.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local R = 1200   -- the shipped radius at the call site, mirrored exactly

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
            self_enemy = 0,    -- subject frames with >= 1 enemy hero within R
            self_tower = 0,    -- subject frames with >= 1 enemy tower within R
            self_present = 0,  -- armed flag true (either of the two)
            shipped_true = 0,  -- the shipped ally-only scan answered true
            gate_skipped = 0,  -- case (A): both > 0, so the scan never ran
            no_ally = 0,       -- case (B): zero allies within R
            flip = 0,
            -- the three flip buckets are DISJOINT and exhaustive, so they add
            -- up to `flip` and no frame is counted twice:
            flip_A = 0,   -- (A) gate false (enemy hero AND enemy tower near me)
            flip_B = 0,   -- (B) gate true, but zero allies within R: body never ran
            flip_C = 0,   -- (C) gate true, allies scanned, none of THEM had one
            -- ⚠️ THE CAST-LEGALITY SPLIT, and why it is here. The real item
            -- cannot be USED while an enemy hero or tower is within 1025, and
            -- whether the engine's IsFullyCastable() already models that is NOT
            -- answerable from this container (no bot-side debugging; AGENTS.md).
            -- So the flips are split by the distance to the NEAREST breaker:
            -- the ones beyond 1025 are frames where the cast is legal whatever
            -- IsFullyCastable does, i.e. the part of the lever that survives the
            -- uncertifiable half.
            flip_far = 0,    -- nearest breaker > 1025: cast is legal, smoke would
                             -- be dispelled by the enemy already standing there
            flip_near = 0 }  -- nearest breaker <= 1025: the engine may already
                             -- refuse the cast; this half is UNCERTIFIABLE
local witnesses = {}
local seen_fixture = {}

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
                if ok and J ~= nil and bot ~= nil then
                    c.live = c.live + 1
                    local tEnemy = J.GetNearbyHeroes(bot, R, true, BOT_MODE_NONE) or {}
                    local tTower = bot:GetNearbyTowers(R, true) or {}
                    local tAlly  = J.GetAllyList(bot, R) or {}
                    local nE, nT, nA = #tEnemy, #tTower, #tAlly

                    if nE > 0 then c.self_enemy = c.self_enemy + 1 end
                    if nT > 0 then c.self_tower = c.self_tower + 1 end
                    local armed = (nE > 0) or (nT > 0)
                    if armed then c.self_present = c.self_present + 1 end
                    if nA == 0 then c.no_ally = c.no_ally + 1 end

                    -- the shipped expression, rebuilt line for line
                    local shipped = false
                    local bGate = (nE == 0) or (nT == 0)
                    if not bGate then c.gate_skipped = c.gate_skipped + 1 end
                    if bGate then
                        for _, hAlly in pairs(tAlly) do
                            if J.IsValidHero(hAlly) then
                                local aE = J.GetNearbyHeroes(hAlly, R, true, BOT_MODE_NONE) or {}
                                local aT = hAlly:GetNearbyTowers(R, true) or {}
                                if #aE >= 1 or #aT >= 1 then shipped = true break end
                            end
                        end
                    end
                    if shipped then c.shipped_true = c.shipped_true + 1 end

                    if armed and not shipped then
                        c.flip = c.flip + 1
                        local nNear = nil
                        for _, h in pairs(tEnemy) do
                            local d = GetUnitToUnitDistance(bot, h)
                            if nNear == nil or d < nNear then nNear = d end
                        end
                        for _, h in pairs(tTower) do
                            local d = GetUnitToUnitDistance(bot, h)
                            if nNear == nil or d < nNear then nNear = d end
                        end
                        if nNear ~= nil and nNear > 1025 then
                            c.flip_far = c.flip_far + 1
                        else
                            c.flip_near = c.flip_near + 1
                        end
                        local sCase
                        if not bGate then c.flip_A = c.flip_A + 1 ; sCase = 'A'
                        elseif nA == 0 then c.flip_B = c.flip_B + 1 ; sCase = 'B'
                        else c.flip_C = c.flip_C + 1 ; sCase = 'C' end
                        witnesses[#witnesses + 1] = string.format(
                            '%s  %s  %s  t=%.1f  e=%d tw=%d ally=%d gate=%s',
                            sCase, path:gsub('tests/fixtures/', ''),
                            u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                            nE, nT, nA, tostring(bGate))
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

for _, k in ipairs({ 'fixtures', 'live', 'self_enemy', 'self_tower', 'self_present',
                     'shipped_true', 'gate_skipped', 'no_ally', 'flip', 'flip_A', 'flip_B', 'flip_C',
                     'flip_far', 'flip_near' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('P fixtures_with_a_change ', tostring(nfx), '\n')
local shown = { A = 0, B = 0, C = 0 }
for _, w in ipairs(witnesses) do
    local k = w:sub(1, 1)
    if shown[k] ~= nil and shown[k] < 8 then
        shown[k] = shown[k] + 1
        out:write('W ', w, '\n')
    end
end
out:write('DONE\n')
