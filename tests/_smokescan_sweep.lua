-- Corpus sweep for [smokescan]: the gate on the Smoke of Deceit ally scan is an
-- OR of two "== 0" tests, so it is FALSE exactly when BOTH of the caster's
-- lists are non-empty -- and the loop it suppresses is the ONLY writer of the
-- flag that decides whether the smoke is cast.
--
--   -- bots/ability_item_usage_generic.lua, X.ConsiderItemDesire['item_smoke_of_deceit']
--   local nInRangeAlly   = J.GetAllyList(bot, 1200)
--   local nInRangeEnemy  = J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
--   local nInRangeTower  = bot:GetNearbyTowers(1200, true)
--   if (#nInRangeEnemy == 0) or (#nInRangeTower == 0) then       -- <= THIS
--       for _, allyHero in pairs(nInRangeAlly) do ...
--           isThereEnemyNearby = true                            -- only writer
--   end
--   if not isThereEnemyNearby then ... return BOT_ACTION_DESIRE_HIGH ... end
--
-- ⛔ WHAT THIS SWEEP PRICES, DECLARED FIRST, AND IT IS SMALLER THAN THE ONE THE
-- SIBLING SWEEP PRICED. `tests/_smokeself_sweep.lua` priced the FLAG's seed and
-- got 206 changed answers. This lever is the GATE, and its whole differing
-- domain is `gate_false` -- an enemy hero AND an enemy tower inside 1200, which
-- is case (A) of that sweep. Of those, only the frames where the suppressed scan
-- would have found a dirty ALLY are changed answers (`flip`); on the rest the
-- scan runs and finds nothing, so the flag lands on the same `false`.
--
-- ⛔ AND EVERY ONE OF THOSE FLIPS IS INSIDE 'smokeself''s DOMAIN, BY
-- CONSTRUCTION, NOT BY COINCIDENCE. `gate_false` means both lists non-empty;
-- 'smokeself' answers true when EITHER is. both ⊂ either. The sweep asserts that
-- containment (`flip_outside_smokeself` must print 0) rather than leaving the
-- reader to trust the algebra -- and it is the reason these two ids must never
-- be armed in the same wave: with 'smokeself' armed this lever moves nothing,
-- and a wave arming both would credit its whole reading to the wrong id.
--
-- ⚠️ THE UNCERTIFIABLE HALF BITES HARDER HERE THAN IT DID THERE. The real item
-- cannot be USED with an enemy hero or tower inside 1025 and whether the
-- engine's IsFullyCastable() models that is not answerable from this container
-- (no bot-side debugging; AGENTS.md). 'smokeself' could claim the flips whose
-- nearest breaker sits beyond 1025. Here the domain already requires ONE OF
-- EACH inside 1200, so a legal-whatever-the-answer frame needs BOTH of them in
-- the shell (1025, 1200]. `flip_far` counts exactly that and is the only number
-- this lever claims; `flip_near` is registered as UNCERTIFIABLE, which is
-- neither zero nor full.
--
-- ⛔ RUN BY HAND, not from the suite: it loads every fixture once per hero and
-- tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0.  Same reason tests/_smokeself_sweep.lua and
-- tests/_towerpow_sweep.lua sit outside the suite.
--
--   lua5.1 tests/_smokescan_sweep.lua        (counters on stderr, DONE last)
--
-- ⛔ NOTHING IS ARMED HERE.  Both legs are rebuilt from the same getters the
-- shipped site calls, so the sweep cannot race soak_side.lua on disk (GH
-- #848/#856).
--
-- ⛔ IT IS NOT A COUNT OF GAMES.  Item ownership and the enclosing desire
-- branches are not walked, and it is frames-by-subject, not situations.
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
            gate_false = 0,   -- both lists non-empty: the shipped gate suppresses the scan
            gate_true  = 0,
            dirty_ally = 0,   -- an ally within R whose own R-ring holds an enemy hero or tower
            flip = 0,         -- gate_false AND dirty_ally: armed says "someone sees us", shipped said no
            flip_far = 0,     -- BOTH breakers beyond 1025: cast legal whatever IsFullyCastable does
            flip_near = 0,    -- some breaker inside 1025: UNCERTIFIABLE half
            flip_outside_smokeself = 0 }  -- must be 0: every flip is inside 'smokeself''s domain
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
                    local nE, nT = #tEnemy, #tTower

                    -- the shipped gate, rebuilt term for term
                    local bGate = (nE == 0) or (nT == 0)
                    if bGate then c.gate_true = c.gate_true + 1
                    else c.gate_false = c.gate_false + 1 end

                    -- what the suppressed loop would have answered
                    local bDirtyAlly = false
                    for _, hAlly in pairs(tAlly) do
                        if J.IsValidHero(hAlly) then
                            local aE = J.GetNearbyHeroes(hAlly, R, true, BOT_MODE_NONE) or {}
                            local aT = hAlly:GetNearbyTowers(R, true) or {}
                            if #aE >= 1 or #aT >= 1 then bDirtyAlly = true break end
                        end
                    end
                    if bDirtyAlly then c.dirty_ally = c.dirty_ally + 1 end

                    if (not bGate) and bDirtyAlly then
                        c.flip = c.flip + 1
                        -- containment in 'smokeself''s domain, asserted not assumed
                        if not (nE > 0 or nT > 0) then
                            c.flip_outside_smokeself = c.flip_outside_smokeself + 1
                        end
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
                        witnesses[#witnesses + 1] = string.format(
                            '%s  %s  t=%.1f  e=%d tw=%d ally=%d nearest=%.0f',
                            path:gsub('tests/fixtures/', ''),
                            u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                            nE, nT, #tAlly, nNear or -1)
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

for _, k in ipairs({ 'fixtures', 'live', 'gate_true', 'gate_false', 'dirty_ally',
                     'flip', 'flip_far', 'flip_near', 'flip_outside_smokeself' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('P fixtures_with_a_change ', tostring(nfx), '\n')
for i, w in ipairs(witnesses) do
    if i <= 40 then out:write('W ', w, '\n') end
end
out:write('DONE\n')
