-- Corpus walk behind tests/test_wardcomma_mid3_spot.lua, run as a SUBPROCESS or
-- by hand -- the leading underscore keeps run_tests.lua from globbing it (it
-- globs `^test_.*%.lua$`). The test file re-drives only the eight frames this
-- walk names; this is where the 126 / 124 / 8 come from.
--
--     lua5.1 tests/_wardcomma_sweep.lua
--
-- WHAT IS MEASURED. bots/FunLib/aba_ward_utility.lua's
-- `WardLocationsBeforeAllyTowerFall__Radiant[TOWER_MID_3][3]` is written
-- `Vector(-2414.402100 -3802.327637)` -- no comma -- so it resolves to
-- (-6216.729737, 0) rather than (-2414.4, -3802.3). This walk asks, over every
-- real hero-frame in tests/fixtures (recursively, subdirectories included):
--
--   sup      radiant heroes at J.GetPosition >= 4, i.e. the population
--            mode_ward_generic's own first line admits;
--   mid2     how many of them already have their own mid tier-2 down, which is
--            the state the MID_3 spot group needs -- this is the DEBT column and
--            it is expected to read 0;
--   listed   with that one state DECLARED, how many candidate lists contain the
--            corrupted point;
--   argmin   on how many of those X.GetClosestObserverWardSpot -- the argmin
--            mode_ward_generic tests its 3200u gate against and finally plants
--            on -- returns it.
--
-- Nothing else is declared. Every hero, every position and every distance comes
-- off a real .dem frame, and the real X.GetAvailabeObserverWardSpots runs.
--
-- ⚠️ `print` does not survive mock.replay_fixture, so output goes through a
-- reference captured before the require (the same shape as the other sweeps).

local P = print
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SHIPPED_X = -2414.402100 - 3802.327637

local files = {}
local p = assert(io.popen("find tests/fixtures -name 'f_*.lua' -print"))
for f in p:lines() do files[#files + 1] = f end
p:close()
table.sort(files)

local c = { fixtures = 0, heroes = 0, rad = 0, sup = 0, mid2 = 0, listed = 0, argmin = 0 }
local rows = {}

for _, path in ipairs(files) do
    local okf, fx = pcall(dofile, path)
    if okf and type(fx) == 'table' and fx.units ~= nil then
        c.fixtures = c.fixtures + 1
        for _, u in ipairs(fx.units) do
            if u.name ~= nil and u.name:match('^npc_dota_hero_') then
                c.heroes = c.heroes + 1
                local okl, J, bot = pcall(rf.load, path, u.name)
                if okl and bot ~= nil and bot:GetTeam() == TEAM_RADIANT then
                    c.rad = c.rad + 1
                    local pos = J.GetPosition(bot)
                    if pos ~= nil and pos >= 4 then
                        c.sup = c.sup + 1
                        local shipped = GetTower
                        local myTeam = bot:GetTeam()
                        if shipped(myTeam, TOWER_MID_2) == nil then c.mid2 = c.mid2 + 1 end

                        -- The one declaration: our mid tier-2 is down, mid
                        -- tier-3 stands. Every other tower answers the frame.
                        _G.GetTower = function(team, i)
                            if team == myTeam and i == TOWER_MID_2 then return nil end
                            if team == myTeam and i == TOWER_MID_3 then
                                return shipped(team, TOWER_MID_3)
                                    or shipped(team, TOWER_MID_1)
                                    or shipped(team, TOWER_TOP_1)
                            end
                            return shipped(team, i)
                        end

                        local W = dofile('bots/FunLib/aba_ward_utility.lua')
                        local spots = W.GetAvailabeObserverWardSpots(bot)
                        local bListed = false
                        for _, s in pairs(spots) do
                            if math.abs(s.location[1] - SHIPPED_X) < 0.01
                                and math.abs(s.location[2]) < 0.01 then bListed = true end
                        end
                        if bListed then
                            c.listed = c.listed + 1
                            local best = W.GetClosestObserverWardSpot(bot, spots)
                            if best ~= nil and math.abs(best.location[1] - SHIPPED_X) < 0.01
                                and math.abs(best.location[2]) < 0.01 then
                                c.argmin = c.argmin + 1
                                rows[#rows + 1] = string.format(
                                    'A %s %s t=%.1f pos=%d d=%.0f', path, u.name,
                                    fx.time or -1, pos,
                                    GetUnitToLocationDistance(bot, best.location))
                            end
                        end
                        _G.GetTower = shipped
                    end
                end
            end
        end
    end
end

for _, k in ipairs({ 'fixtures', 'heroes', 'rad', 'sup', 'mid2', 'listed', 'argmin' }) do
    P('C ' .. k .. ' ' .. c[k])
end
for _, r in ipairs(rows) do P(r) end
P('DONE')
