-- Corpus sweep for [helpring]: the two help-parity sites in
-- mode_team_roam_generic.lua read the two halves of ONE parity question off
-- two DIFFERENT rings -- allies 1200, enemies 1600 -- around the SAME point
-- (the ally/core being helped).
--
-- ⛔ RUN BY HAND, not from the suite: it loads all fixtures once per hero
-- (~1039 loads) and tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0.  Same reason tests/_roamring_sweep.lua sits
-- outside the suite.
--
--   lua5.1 tests/_helpring_sweep.lua      (counters on stderr, DONE last)
--
-- Columns, per SUBJECT FRAME (one row per live hero per fixture):
--   reached_a/reached_b  frames where the site's loop can run at all
--                        (a closest ally/core exists AND >=1 enemy in 1600)
--   ashell_a/ashell_b    of those, frames with an ally in the 1200-1600 shell
--   up_a/up_b            shipped FALSE -> armed TRUE   (the lever's direction)
--   down_a/down_b        shipped TRUE  -> armed FALSE  (must be 0)
--   tdown_a/tdown_b      the OTHER unification (enemies pulled to 1200),
--                        registered and NOT shipped -- see the helper header.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local ALLY_RING, ENGAGE_RING = 1200, 1600

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
            reached_a = 0, ashell_a = 0, up_a = 0, down_a = 0, tdown_a = 0, tup_a = 0,
            reached_b = 0, ashell_b = 0, up_b = 0, down_b = 0, tdown_b = 0, tup_b = 0,
            subjects_changed = 0 }
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
                if ok and bot ~= nil then
                    c.live = c.live + 1
                    local changed = false
                    local sites = {
                        { 'a', J.GetClosestAlly(bot, 3500) },
                        { 'b', J.GetClosestCore(bot, 3500) },
                    }
                    for _, s in ipairs(sites) do
                        local tag, hSubject = s[1], s[2]
                        if hSubject ~= nil then
                            local v = hSubject:GetLocation()
                            local aNarrow = #(J.GetAlliesNearLoc(v, ALLY_RING) or {})
                            local aWide   = #(J.GetAlliesNearLoc(v, ENGAGE_RING) or {})
                            local eWide   = #(J.GetEnemiesNearLoc(v, ENGAGE_RING) or {})
                            local eNarrow = #(J.GetEnemiesNearLoc(v, ALLY_RING) or {})
                            if eWide > 0 then
                                c['reached_' .. tag] = c['reached_' .. tag] + 1
                                if aWide > aNarrow then
                                    c['ashell_' .. tag] = c['ashell_' .. tag] + 1
                                end
                                -- shipped: allies off the 1200 ring, `+ 1` for the asker
                                local shipped = (aNarrow + 1 >= eWide)
                                local armed   = (aWide   + 1 >= eWide)   -- this lever
                                local tight   = (aNarrow + 1 >= eNarrow) -- the other one
                                if armed and not shipped then
                                    c['up_' .. tag] = c['up_' .. tag] + 1
                                    changed = true
                                    witnesses[#witnesses + 1] = string.format(
                                        '%s %s  %s  t=%.1f  subj=%s  a%d=%d a%d=%d e%d=%d',
                                        tag, path:gsub('tests/fixtures/', ''),
                                        u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                                        tostring(hSubject:GetUnitName()):gsub('npc_dota_hero_', ''),
                                        ALLY_RING, aNarrow, ENGAGE_RING, aWide,
                                        ENGAGE_RING, eWide)
                                    seen_fixture[path] = true
                                end
                                if shipped and not armed then
                                    c['down_' .. tag] = c['down_' .. tag] + 1
                                end
                                if tight and not shipped then
                                    c['tup_' .. tag] = c['tup_' .. tag] + 1
                                end
                                if shipped and not tight then
                                    c['tdown_' .. tag] = c['tdown_' .. tag] + 1
                                end
                            end
                        end
                    end
                    if changed then c.subjects_changed = c.subjects_changed + 1 end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

local nfx = 0
for _ in pairs(seen_fixture) do nfx = nfx + 1 end

for _, k in ipairs({ 'fixtures', 'live',
                     'reached_a', 'ashell_a', 'up_a', 'down_a', 'tup_a', 'tdown_a',
                     'reached_b', 'ashell_b', 'up_b', 'down_b', 'tup_b', 'tdown_b',
                     'subjects_changed' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('P fixtures_with_a_change ', tostring(nfx), '\n')
for _, w in ipairs(witnesses) do out:write('W ', w, '\n') end
out:write('DONE\n')
