-- Corpus sweep for tests/test_zuus_fight_quorum.lua, run as a SUBPROCESS (the
-- backlog 0q rule keeps corpus-wide dofile loops off run_tests.lua's long-lived
-- heap).  The leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IT MEASURES
-- ----------------
-- Exactly the quantity Zeus's team-fight ult branch thresholds:
--
--     J.GetInvUnitCount( false, J.GetNearbyHeroes( me, R, true, BOT_MODE_NONE ) )
--
-- evaluated at EVERY alive hero of EVERY fixture -- not only at the subject.
-- The vantage points that are not the subject are real geometry and real
-- visibility off the same dumped frame; they are NOT creation frames for the
-- branch, and the test file that reads these rows says so where it uses them.
--
-- Two reasons the sweep goes wide rather than staying on the ten Zeus-subject
-- frames.  First, the load-bearing sentence of the round is a claim about the
-- RANGE of the count ("5 is its ceiling, not a point inside it"), and a claim
-- about a range is worth exactly as many vantage points as you can pay for.
-- Second, the same rows price the vantage BIAS that the round registers but
-- does not fix: a global nuke whose fight size is measured from the caster is
-- measured from the one position a backline mage should not be in.
--
-- THE RADIUS IS READ FROM THE HERO SOURCE, NOT RE-TYPED.  A census that copies
-- the constant it measures reports the old world unmoved after the constant
-- moves (the M13 lesson, inherited from tests/_cm_pos5_boots_sweep.lua).
--
-- Rows written to stdout:
--   RADIUS <r>                  the radius this sweep actually used
--   HIST <n> <count>            vantage points that counted exactly n enemies
--   VP <fixture> <unit> <n> <isSubject>     every vantage point with n >= 3
--   ZSUBJ <fixture> <n>         each Zeus-SUBJECT frame's own count
--   C <key> <int>               scalars (fixtures, vantage_points, max, teamcap)
--   DONE
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

local paths = {}
do
    local p = assert(io.popen('ls tests/fixtures'))
    for name in p:lines() do
        if name:match('%.lua$') then paths[#paths + 1] = 'tests/fixtures/' .. name end
    end
    p:close()
end
table.sort(paths)

-- The radius, off the shipped hero file.  Loading one frame first is what makes
-- rf.load_hero legal; the frame chosen does not enter any reading below.
local RADIUS
do
    rf.load(paths[1])
    local X = rf.load_hero('zuus')
    RADIUS = assert(X.nUltFightRadius,
        'bots/BotLib/hero_zuus.lua no longer exposes X.nUltFightRadius; this sweep '
        .. 'reads that constant rather than re-typing it, so re-anchor it deliberately.')
end
out:write(string.format('RADIUS %d\n', RADIUS))

local hist, nVantage, nMax, nTeamCap = {}, 0, 0, 0

for _, path in ipairs(paths) do
    local ok, res = pcall(function()
        local a, b, c, d = rf.load(path)
        return { a, b, c, d }
    end)
    if ok then
        local J, _, heroes, fx = res[1], res[2], res[3], res[4]

        -- The team-size ceiling, measured rather than assumed: the shipped
        -- quorum's whole defect is that it equals this number.
        local perTeam = {}
        for _, u in ipairs(fx.units) do
            perTeam[u.team] = (perTeam[u.team] or 0) + 1
        end
        for _, n in pairs(perTeam) do
            if n > nTeamCap then nTeamCap = n end
        end

        for _, u in ipairs(fx.units) do
            local h = heroes[u.name]
            if u.alive and h ~= nil and h.GetNearbyHeroes ~= nil then
                local n = J.GetInvUnitCount(false,
                    h:GetNearbyHeroes(RADIUS, true, BOT_MODE_NONE))
                hist[n] = (hist[n] or 0) + 1
                nVantage = nVantage + 1
                if n > nMax then nMax = n end
                if n >= 3 then
                    out:write(string.format('VP %s %s %d %d\n',
                        path, u.name, n, (u.name == fx.self) and 1 or 0))
                end
                if u.name == fx.self and u.name == 'npc_dota_hero_zuus' then
                    out:write(string.format('ZSUBJ %s %d\n', path, n))
                end
            end
        end
    end
end

local keys = {}
for k in pairs(hist) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('HIST %d %d\n', k, hist[k])) end

out:write(string.format('C fixtures %d\n', #paths))
out:write(string.format('C vantage_points %d\n', nVantage))
out:write(string.format('C max %d\n', nMax))
out:write(string.format('C teamcap %d\n', nTeamCap))
out:write('DONE\n')
