-- Heavy corpus sweep for tests/test_pullcamp_trigger_census.lua, run as a
-- SUBPROCESS (the 2026-08-21T20:35Z / backlog 0q rule: a full-corpus drive that
-- rebuilds jmz_func once per hero-frame -- ~900 loads, ~25s -- must not run on
-- run_tests.lua's long-lived heap). The leading underscore keeps run_tests.lua
-- from globbing it (`^test_.*%.lua$`).
--
-- It prints a flat manifest to stdout; the test parses it and every census
-- assertion reads from it.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                         a counter bucket
--   CHAIN <fixture> <hero> <sec>        frame reaching the lane clause, OLD window
--   NEWONLY <fixture> <hero> <sec>      frame the travel lead newly admits
--   WIT <fixture> <hero> <team> <pos> <x> <y> <hp01> <pullsafe> <neut1400>
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The two pull-window edge pairs, READ FROM THE SHIPPED SOURCE rather than
-- restated here -- the M13 lesson (a census that copies the constant it is
-- measuring reports the old world unmoved after the constant changes).
local WINDOW = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local at = assert(src:find('function J.ShouldPullNeutralCamp', 1, true),
        'J.ShouldPullNeutralCamp moved')
    local body = src:sub(at, at + 4000)
    local a, b, c, d = body:match(
        'nSec >= (%d+) and nSec <= (%d+)%) or %(nSec >= (%d+) and nSec <= (%d+)')
    assert(a, 'the pull window is no longer two literal nSec ranges')
    return { tonumber(a), tonumber(b), tonumber(c), tonumber(d) }
end)()

-- The window BEFORE the GH #13 repair: the aggro marks with no travel lead.
-- Restated (the pre-repair source is gone), and pinned as such by the test's
-- source assertions, which check the shipped edges against WINDOW above.
local OLD = { 10, 20, 40, 50 }

local function in_window(sec, w)
    return (sec >= w[1] and sec <= w[2]) or (sec >= w[3] and sec <= w[4])
end

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

local out = io.stdout
local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end

local WITNESS_FIXTURE = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local WITNESS_HERO = 'npc_dota_hero_ogre_magi'

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local t = fx.time
        local sec = t % 60
        local tw = (t >= 60 and t <= 360)
        local sw_new = in_window(sec, WINDOW)
        local sw_old = in_window(sec, OLD)
        for _, u in ipairs(fx.units) do
            if u.alive then
                local J, bot = rf.load(path, u.name)
                bump('frames')
                local support = not J.IsCore(bot)
                local loc = bot:GetLocation()
                local no800 = #(J.GetEnemiesNearLoc(loc, 800) or {}) == 0
                local lane = bot:GetAssignedLane()
                local tn = bot:GetNearbyNeutralCreeps(1400)
                local camp_up = (tn ~= nil and #tn > 0)
                local sp = GetNeutralSpawners()
                local spawners = (sp ~= nil and next(sp) ~= nil)

                if tw then bump('timewin') end
                if sw_old then bump('secwin_old') end
                if sw_new then bump('secwin_new') end
                if support then bump('support') end
                if no800 then bump('no800') end
                if lane == nil then bump('lane_nil') end
                if lane == 0 then bump('lane_zero') end
                if camp_up then bump('camp_up') end
                if spawners then bump('spawners_nonempty') end
                if J.IsLanePullSafe(bot) then bump('pullsafe') end

                if tw and support and no800 then
                    bump('peacetime_lane_support')
                    if sw_new then
                        -- [GH #117] Where does a frame that reaches the camp
                        -- selector actually STAND? The new own-side clause
                        -- compares a camp against the lane midpoint, so what
                        -- decides whether it can bite is the bot's own depth
                        -- measured the same way. Honest ancients only (43 of
                        -- the fixtures have no buildings and GetAncient then
                        -- answers the map origin for both teams -- world
                        -- assertion 17), and the midpoint is taken between the
                        -- two real ancients, which is what the test declares.
                        local own = GetAncient(bot:GetTeam())
                        local enemy = GetAncient(
                            bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT)
                        local lo, le = own:GetLocation(), enemy:GetLocation()
                        if not (lo.x == 0 and lo.y == 0 and le.x == 0 and le.y == 0) then
                            bump('depth_honest')
                            local half = J.GetLocationToLocationDistance(lo, le) / 2
                            local d = J.GetLocationToLocationDistance(loc, lo)
                            if d > half then
                                bump('depth_past_mid')
                                -- Past the midpoint by more than the untouched
                                -- 1500 reach: no camp the bot can reach is on
                                -- our side, so the repaired selector returns
                                -- nil whatever the camp list.
                                if d - 1500 > half then bump('depth_forced_nil') end
                            else
                                bump('depth_own_half')
                                -- Inside by more than the reach: every camp the
                                -- bot can reach is on our side, so the clause is
                                -- arithmetically incapable of changing anything.
                                if d + 1500 < half then bump('depth_inert') end
                            end
                        end
                    end
                    if sw_old then
                        bump('chain_old')
                        out:write(string.format('CHAIN %s %s %.1f\n', path, u.name, sec))
                    end
                    if sw_new then bump('chain_new') end
                    if sw_new and not sw_old then
                        out:write(string.format('NEWONLY %s %s %.1f\n', path, u.name, sec))
                    end
                end

                if path == WITNESS_FIXTURE and u.name == WITNESS_HERO then
                    out:write(string.format('WIT %s %s %d %s %.0f %.0f %.2f %s %s\n',
                        path, u.name, bot:GetTeam(), tostring(J.GetPosition(bot)),
                        loc.x, loc.y, J.GetHP(bot),
                        tostring(J.IsLanePullSafe(bot)), tostring(camp_up)))
                end
            end
        end
    end
end

for _, k in ipairs({
    'fixtures', 'frames', 'timewin', 'secwin_old', 'secwin_new', 'support',
    'no800', 'lane_nil', 'lane_zero', 'camp_up', 'spawners_nonempty',
    'pullsafe', 'peacetime_lane_support', 'chain_old', 'chain_new',
    'depth_honest', 'depth_past_mid', 'depth_forced_nil', 'depth_own_half',
    'depth_inert',
}) do
    out:write(string.format('C %s %d\n', k, c[k]))
end
out:write('DONE\n')
