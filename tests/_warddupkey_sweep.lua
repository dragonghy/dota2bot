-- Corpus walk behind tests/test_warddupkey_eaten_spots.lua, run as a SUBPROCESS
-- or by hand -- the leading underscore keeps run_tests.lua from globbing it (it
-- globs `^test_.*%.lua$`).
--
--     lua5.1 tests/_warddupkey_sweep.lua
--
-- WHAT IS MEASURED. Three groups in bots/FunLib/aba_ward_utility.lua write the
-- same integer key twice, so Lua keeps the second and the first spot does not
-- exist at run time:
--
--   BeforeAllyTowerFall__Dire[TOWER_MID_1][4]  eats (-2400.8, 1431.3)
--   BeforeAllyTowerFall__Dire[TOWER_TOP_3][4]  eats (  605.6, 6996.9)
--   AfterEnemyTowerFall__Dire[TOWER_TOP_2][1]  eats (-5218.0,-1648.6)
--
-- All three are DIRE tables, so this walk asks, over every real hero-frame in
-- tests/fixtures (recursively, subdirectories included):
--
--   sup       dire heroes at J.GetPosition >= 4, i.e. the population
--             mode_ward_generic's own first line admits;
--   mid1_up   how many of them still have their OWN mid tier-1 standing, which
--             is the state the MID_1 group is read in -- the live-domain column;
--   base_n    candidate-list length with the gate shut (the shipped answer);
--   arm_n     candidate-list length with 'warddupkey' armed;
--   listed    frames whose armed list contains a restored spot;
--   argmin    frames where X.GetClosestObserverWardSpot -- the spot
--             mode_ward_generic tests its 3200u gate against and finally plants
--             on -- CHANGES from the shipped answer to a restored spot.
--
-- Nothing is declared: the tower state is whatever each frame's own building
-- rows say, and the real X.GetAvailabeObserverWardSpots runs both legs.
--
-- ⚠️ `print` does not survive mock.replay_fixture, so output goes through a
-- reference captured before the require (the same shape as the other sweeps).

local P = print
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

local EATEN = {
    { name = 'mid1', x = -2400.793457, y = 1431.276611 },
    { name = 'top3', x =   605.637573, y = 6996.875977 },
    { name = 'top2', x = -5217.980957, y = -1648.555908 },
}

local function which_eaten(loc)
    if loc == nil then return nil end
    for _, e in ipairs(EATEN) do
        if math.abs(loc[1] - e.x) < 0.01 and math.abs(loc[2] - e.y) < 0.01 then
            return e.name
        end
    end
    return nil
end

local files = {}
local p = assert(io.popen("find tests/fixtures -name 'f_*.lua' -print"))
for f in p:lines() do files[#files + 1] = f end
p:close()
table.sort(files)

local c = { fixtures = 0, heroes = 0, dire = 0, sup = 0, mid1_up = 0,
            grew = 0, listed = 0, argmin = 0, rank3 = 0 }
local rows = {}
local nBestGap, sBestGap = math.huge, nil

--- One leg: reload the world, optionally armed, and return list + argmin.
local function leg(path, name, bArm)
    local J, bot = rf.load(path, name)
    if bot == nil then return nil end
    local W = dofile('bots/FunLib/aba_ward_utility.lua')
    local spots = W.GetAvailabeObserverWardSpots(bot)
    local n = 0
    local sListed = nil
    for _, s in pairs(spots) do
        n = n + 1
        sListed = which_eaten(s.location) or sListed
    end
    local best = W.GetClosestObserverWardSpot(bot, spots)

    -- Rank and margin of the nearest RESTORED spot among the whole list. A bare
    -- "the argmin never changed" is a zero with two very different causes --
    -- "it is always a distant also-ran" and "it keeps losing by a few hundred
    -- units" -- and those two read back identically unless the margin is taken.
    local dBest, dEaten, nRank = nil, nil, nil
    if best ~= nil then dBest = GetUnitToLocationDistance(bot, best.location) end
    for _, s in pairs(spots) do
        if which_eaten(s.location) ~= nil then
            local d = GetUnitToLocationDistance(bot, s.location)
            if dEaten == nil or d < dEaten then dEaten = d end
        end
    end
    if dEaten ~= nil then
        nRank = 1
        for _, s in pairs(spots) do
            if GetUnitToLocationDistance(bot, s.location) < dEaten then
                nRank = nRank + 1
            end
        end
    end
    return { n = n, listed = sListed, best = best, J = J, bot = bot,
             dBest = dBest, dEaten = dEaten, rank = nRank }
end

for _, path in ipairs(files) do
    local okf, fx = pcall(dofile, path)
    if okf and type(fx) == 'table' and fx.units ~= nil then
        c.fixtures = c.fixtures + 1
        for _, u in ipairs(fx.units) do
            if u.name ~= nil and u.name:match('^npc_dota_hero_') then
                c.heroes = c.heroes + 1
                local okl, J, bot = pcall(rf.load, path, u.name)
                if okl and bot ~= nil and bot:GetTeam() == TEAM_DIRE then
                    c.dire = c.dire + 1
                    local pos = J.GetPosition(bot)
                    if pos ~= nil and pos >= 4 then
                        c.sup = c.sup + 1
                        if GetTower(bot:GetTeam(), TOWER_MID_1) ~= nil then
                            c.mid1_up = c.mid1_up + 1
                        end

                        -- Shipped leg, on a provably clean switch.
                        local base = leg(path, u.name, false)
                        -- Armed leg.
                        ss.arm('warddupkey', 'dire')
                        local arm = leg(path, u.name, true)
                        ss.disarm()

                        if base ~= nil and arm ~= nil then
                            if arm.n > base.n then c.grew = c.grew + 1 end
                            if arm.listed ~= nil then
                                c.listed = c.listed + 1
                                if arm.rank ~= nil and arm.dBest ~= nil then
                                    if arm.rank <= 3 then c.rank3 = c.rank3 + 1 end
                                    local gap = arm.dEaten - arm.dBest
                                    if gap < nBestGap then
                                        nBestGap = gap
                                        sBestGap = string.format(
                                            '%s %s t=%.1f pos=%d site=%s rank=%d '
                                            .. 'd_eaten=%.0f d_argmin=%.0f gap=%.0f',
                                            path, u.name, fx.time or -1, pos,
                                            arm.listed, arm.rank, arm.dEaten,
                                            arm.dBest, gap)
                                    end
                                end
                                local sBase = base.best and which_eaten(base.best.location)
                                local sArm  = arm.best  and which_eaten(arm.best.location)
                                if sArm ~= nil and sBase == nil then
                                    c.argmin = c.argmin + 1
                                    rows[#rows + 1] = string.format(
                                        'A %s %s t=%.1f pos=%d site=%s n=%d->%d',
                                        path, u.name, fx.time or -1, pos, sArm,
                                        base.n, arm.n)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

for _, k in ipairs({ 'fixtures', 'heroes', 'dire', 'sup', 'mid1_up',
                     'grew', 'listed', 'argmin', 'rank3' }) do
    P('C ' .. k .. ' ' .. c[k])
end
P('CLOSEST ' .. tostring(sBestGap))
for _, r in ipairs(rows) do P(r) end
P('DONE')
