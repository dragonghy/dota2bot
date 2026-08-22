-- Heavy corpus sweep for tests/test_fieldcreep_veto.lua, run as a SUBPROCESS
-- (the 2026-08-21T20:35Z / backlog 0q rule: a full-corpus drive that rebuilds
-- jmz_func once per hero-frame -- ~930 loads, ~25s -- must not run on
-- run_tests.lua's long-lived heap). The leading underscore keeps run_tests.lua
-- from globbing it (`^test_.*%.lua$`).
--
-- It prints a flat manifest to stdout; the test parses it and every census
-- assertion reads from it. NOTE: print() is not usable here -- the loaded
-- bots/ world replaces it -- so every line goes through io.write.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                                   a counter bucket
--   ROW <fixture> <hero> <hp01> <creep3> <heal> <dmg3>
--       one live hero frame where J.IsFieldRegenSituation holds AND the
--       fixture carries a recent_damage history for it, i.e. the frames where
--       the new clause can be ASKED at all. dmg3 = creep-kind damage summed
--       over the same 3.0s lookback the clause uses.
--   BAND mass-le24 <n> / BAND tail-ge25 <n> / BAND max-hit <n>
--       every creep-kind damage row on a live hero frame, split at 24 -- the
--       gap the histogram actually shows -- plus the largest single hit
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

-- The lookback the shipped clause uses, READ FROM SOURCE rather than restated
-- here (the M13 lesson: a census that copies the constant it measures reports
-- the old world unmoved after the constant moves). The test additionally pins
-- this against the hero clause's own lookback.
local LOOKBACK = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local n = src:match('bot:WasRecentlyDamagedByCreep%(%s*([%d%.]+)%s*%)')
    assert(n, 'the fieldcreep clause is no longer a literal WasRecentlyDamagedByCreep')
    return tonumber(n)
end)()

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end

-- Creep damage inside the clause's own lookback, straight off the fixture row
-- (the same rows the loader answers WasRecentlyDamagedByCreep from).
local function creep_damage_within(u, window)
    local total = 0
    for _, d in ipairs(u.recent_damage or {}) do
        if d.dt <= window and d.kind == 'creep' then
            total = total + (tonumber(d.value) or 0)
        end
    end
    return total
end

-- light = per-hit rows at or below 24, heavy = the 25+ tail,
-- other = the largest single creep hit seen anywhere in the corpus.
local light, heavy, other = 0, 0, 0

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        -- v1 fixtures carry no recent_window and no recent_damage at all. On
        -- those frames the loader does not install the damage readers, so the
        -- clause is UNASKABLE, not false-for-the-right-reason. Counted apart.
        local v2 = (fx.recent_window ~= nil)
        if v2 then bump('fixtures_v2') end
        for _, u in ipairs(fx.units) do
            if u.alive then
                bump('live')
                for _, d in ipairs(u.recent_damage or {}) do
                    if d.kind == 'creep' then
                        local v = tonumber(d.value) or 0
                        if v <= 24 then light = light + 1
                        else heavy = heavy + 1 end
                        if v > other then other = v end
                    end
                end
                local J, bot = rf.load(path, u.name)
                -- Unarmed: the shipped default. Nothing below may move it.
                J.IsSoakCandidate = function() return false end
                local sit = J.IsFieldRegenSituation(bot)
                if sit then
                    bump('situation')
                    if v2 then bump('sit_v2') else bump('sit_v1') end
                    if u.recent_damage ~= nil then bump('sit_askable') end
                    if v2 and u.recent_damage == nil then bump('sit_v2_silent') end
                end
                if bot:WasRecentlyDamagedByCreep(LOOKBACK) then bump('creep_hit') end

                -- Armed: the only id that may change anything is this one. The
                -- predicate is side-effect free, so the same loaded world is
                -- re-asked with the gate flipped rather than reloaded -- one
                -- rf.load per hero-frame instead of two (85s -> ~45s of suite).
                J.IsSoakCandidate = function(id) return id == 'fieldcreep' end
                local sit2 = J.IsFieldRegenSituation(bot)
                if sit2 then bump('situation_armed') end
                if sit and not sit2 then
                    bump('vetoed')
                    if J.HasFieldRegenSource(bot) then bump('vetoed_heal')
                    else bump('vetoed_dry') end
                end
                -- The clause is append-only and can only `return false`, so a
                -- frame it TURNS ON is structurally impossible. Asserted rather
                -- than assumed: this is the counter a bad edit trips first.
                if sit2 and not sit then bump('IMPOSSIBLE_widened') end
                J.IsSoakCandidate = function() return false end

                if sit and u.recent_damage ~= nil then
                    out:write(string.format('ROW %s %s %.4f %d %d %d\n',
                        path, u.name, u.hp / u.max_hp,
                        bot:WasRecentlyDamagedByCreep(LOOKBACK) and 1 or 0,
                        J.HasFieldRegenSource(bot) and 1 or 0,
                        creep_damage_within(u, LOOKBACK)))
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write(string.format('BAND mass-le24 %d\n', light))
out:write(string.format('BAND tail-ge25 %d\n', heavy))
out:write(string.format('BAND max-hit %d\n', other))
out:write(string.format('C lookback_x10 %d\n', math.floor(LOOKBACK * 10 + 0.5)))
out:write('DONE\n')
