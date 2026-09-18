-- Corpus sweep for [helpself]: three "do we have the numbers to help this ally"
-- sites add `+ 1` FOR THE ASKING BOT to a list the asking bot is already in.
--
-- The producers differ, the belief does not.  mode_team_roam_generic.lua:507
-- and :1884 build the ally half with J.GetAlliesNearLoc, which walks the team
-- ROSTER around the ALLY's location and therefore holds `bot` whenever `bot` is
-- inside the ring.  jmz_func.lua:12667 (J.EvalTeamfightIdle, the PROMOTED
-- 'fight' path) builds it with J.GetNearbyHeroes( hFocusedAlly, 1200, ... ),
-- whose self-exclusion drops hFocusedAlly -- not `bot`.  All three then read
-- `#allies + 1 >= #enemies`.
--
-- ⛔ RUN BY HAND, not from the suite: it loads every fixture once per hero and
-- tools/agent/lua_gate.py kills an unmeasured new test at hook_timeout_seconds
-- = 20.0.  Same reason tests/_roamring_sweep.lua sits outside the suite.
--
--   lua5.1 tests/_helpself_sweep.lua      (counters on stderr, DONE last)
--
-- ⛔ NOTHING IS ARMED HERE.  Both readings are rebuilt from the same producers
-- the shipped sites call, so the sweep cannot race the global switch on disk
-- (GH #848/#856) and its numbers do not depend on soak_side.lua.
--
-- UNIT OF COUNT.  Every site is a function of the asking bot (site A/B through
-- J.GetClosestAlly/J.GetClosestCore, site C through its own 1000u scan), so a
-- row is one SUBJECT FRAME -- unlike tests/_fightfloor_sweep.lua, whose
-- predicate ignored its `bot` argument and whose rows had to be pairs.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local HELP_RADIUS   = 3500   -- ConsiderHelpAlly / ConsiderHelpWhenCoreIsTargeted
local ALLY_RING     = 1200
local ENEMY_RING    = 1600
local IDLE_ALLY     = 1000   -- EvalTeamfightIdle's focused-ally scan
local IDLE_RING     = 1200
local IDLE_ON_ALLY  = 900

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

local function holds(tList, hUnit)
    for _, v in pairs(tList or {}) do if v == hUnit then return true end end
    return false
end

local c = { fixtures = 0, live = 0,
            a_reached = 0, a_self = 0, a_shipped = 0, a_armed = 0, a_down = 0, a_up = 0,
            b_reached = 0, b_self = 0, b_shipped = 0, b_armed = 0, b_down = 0, b_up = 0,
            c_reached = 0, c_self = 0, c_shipped = 0, c_armed = 0, c_down = 0, c_up = 0,
            down_frames = 0 }
local witnesses = {}
local down_fixtures = {}

-- One site's reading.  `tAllies` is what the shipped line counts, `nEnemies`
-- what it compares against; the only difference between the two answers is
-- whether `bot` is allowed to be counted twice.
local function price(bot, tAllies, nEnemies, tag, c_reached, c_self, c_shipped, c_armed, c_down, c_up, path, name, t)
    c[c_reached] = c[c_reached] + 1
    local nAllies = #tAllies
    local bSelf = holds(tAllies, bot)
    if bSelf then c[c_self] = c[c_self] + 1 end
    local shipped = (nAllies + 1 >= nEnemies)
    local armed   = (nAllies + (bSelf and 0 or 1) >= nEnemies)
    if shipped then c[c_shipped] = c[c_shipped] + 1 end
    if armed then c[c_armed] = c[c_armed] + 1 end
    if shipped and not armed then
        c[c_down] = c[c_down] + 1
        witnesses[#witnesses + 1] = string.format(
            '%s  %s  %s  t=%.1f  allies=%d self=%s enemies=%d',
            tag, path:gsub('tests/fixtures/', ''), name:gsub('npc_dota_hero_', ''),
            t or -1, nAllies, tostring(bSelf), nEnemies)
        down_fixtures[path] = true
        return true
    end
    if armed and not shipped then c[c_up] = c[c_up] + 1 end
    return false
end

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
                    local bDown = false

                    -- Site A -- ConsiderHelpAlly (mode_team_roam_generic.lua:507)
                    local hAlly = J.GetClosestAlly(bot, HELP_RADIUS)
                    if hAlly ~= nil then
                        local v = hAlly:GetLocation()
                        bDown = price(bot, J.GetAlliesNearLoc(v, ALLY_RING) or {},
                                      #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {}),
                                      'A', 'a_reached', 'a_self', 'a_shipped',
                                      'a_armed', 'a_down', 'a_up', path, u.name, fx.time) or bDown
                    end

                    -- Site B -- ConsiderHelpWhenCoreIsTargeted (:1884)
                    local hCore = J.GetClosestCore(bot, HELP_RADIUS)
                    if hCore ~= nil then
                        local v = hCore:GetLocation()
                        bDown = price(bot, J.GetAlliesNearLoc(v, ALLY_RING) or {},
                                      #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {}),
                                      'B', 'b_reached', 'b_self', 'b_shipped',
                                      'b_armed', 'b_down', 'b_up', path, u.name, fx.time) or bDown
                    end

                    -- Site C -- J.EvalTeamfightIdle (jmz_func.lua:12667), the
                    -- PROMOTED 'fight' path.  Its own focused-ally scan, copied
                    -- so the sweep prices the same hFocusedAlly the branch does.
                    local hFocused = nil
                    for _, ally in pairs(J.GetNearbyHeroes(bot, IDLE_ALLY, false, BOT_MODE_NONE) or {}) do
                        if J.IsValidHero(ally) and ally ~= bot
                            and not J.IsSuspiciousIllusion(ally)
                        then
                            local onAlly = J.GetNearbyHeroes(ally, IDLE_ON_ALLY, true, BOT_MODE_NONE) or {}
                            if #onAlly > 0
                                and (ally:WasRecentlyDamagedByAnyHero(2.0) or J.GetHP(ally) < 0.5)
                            then
                                hFocused = ally
                                break
                            end
                        end
                    end
                    if hFocused ~= nil then
                        bDown = price(bot, J.GetNearbyHeroes(hFocused, IDLE_RING, false, BOT_MODE_NONE) or {},
                                      #(J.GetNearbyHeroes(hFocused, IDLE_RING, true, BOT_MODE_NONE) or {}),
                                      'C', 'c_reached', 'c_self', 'c_shipped',
                                      'c_armed', 'c_down', 'c_up', path, u.name, fx.time) or bDown
                    end

                    if bDown then c.down_frames = c.down_frames + 1 end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

local nDownFixtures = 0
for _ in pairs(down_fixtures) do nDownFixtures = nDownFixtures + 1 end

for _, k in ipairs({ 'fixtures', 'live',
                     'a_reached', 'a_self', 'a_shipped', 'a_armed', 'a_down', 'a_up',
                     'b_reached', 'b_self', 'b_shipped', 'b_armed', 'b_down', 'b_up',
                     'c_reached', 'c_self', 'c_shipped', 'c_armed', 'c_down', 'c_up',
                     'down_frames' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('P down_fixtures ', tostring(nDownFixtures), '\n')
for i, w in ipairs(witnesses) do
    if i <= 40 then out:write('W ', w, '\n') end
end
out:write('P witnesses_total ', tostring(#witnesses), '\n')
out:write('DONE\n')
