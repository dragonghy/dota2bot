-- Corpus sweep for [helpnear]: J.GetClosestAlly returns the FIRST alive ally
-- in team-ROSTER order within nRadius, not the nearest one.  Its only
-- production consumer is ConsiderHelpAlly (mode_team_roam_generic.lua:500),
-- which names the result `nClosestAlly` and then anchors every downstream
-- guard on it.
--
-- ⛔ RUN BY HAND, not from the suite: it loads all fixtures once per hero
-- (~1039 loads) and tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0.  Same reason tests/_roamring_sweep.lua sits
-- outside the suite.
--
--   lua5.1 tests/_helpnear_sweep.lua      (counters on stderr, DONE last)
--
-- Columns, per SUBJECT FRAME (one row per live hero per fixture):
--   reached        frames where the shipped picker answers somebody
--   differ         of those, frames where the nearest ally is a DIFFERENT hero
--   gap_max        largest (shipped distance - nearest distance), in units
--   hpguard_flip   frames where `J.GetHP(bot) >= J.GetHP(anchor)` -- the very
--                  next line at the call site -- answers differently
--   parity_flip    frames where the help parity around the anchor flips
--   cand_max       max number of eligible allies in the 3500 ring (the picker
--                  only has a choice to get wrong when this is >= 2)
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local HELP_RADIUS = 3500

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

-- The nearest eligible ally, using the shipped picker's OWN eligibility test.
local function nearest_ally(J, bot)
    local best, bestd = nil, nil
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local member = GetTeamMember(i)
        if member ~= nil and member:IsAlive() and member ~= bot
            and not J.IsSuspiciousIllusion(member)
        then
            local d = GetUnitToUnitDistance(bot, member)
            if d <= HELP_RADIUS and (bestd == nil or d < bestd) then
                best, bestd = member, d
            end
        end
    end
    return best, bestd
end

local function eligible_count(J, bot)
    local n = 0
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local member = GetTeamMember(i)
        if member ~= nil and member:IsAlive() and member ~= bot
            and not J.IsSuspiciousIllusion(member)
            and GetUnitToUnitDistance(bot, member) <= HELP_RADIUS
        then n = n + 1 end
    end
    return n
end

local function parity_true(J, bot, anchor)
    local v = anchor:GetLocation()
    local a = #(J.GetAlliesNearLoc(v, 1200) or {})
    local e = #(J.GetEnemiesNearLoc(v, 1600) or {})
    return (a + 1 >= e)
end

local c = { fixtures = 0, live = 0, reached = 0, differ = 0, cand_max = 0,
            gap_max = 0, hpguard_flip = 0, parity_flip = 0, both_same_hero = 0 }
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
                    local shipped = J.GetClosestAlly(bot, HELP_RADIUS)
                    local n = eligible_count(J, bot)
                    if n > c.cand_max then c.cand_max = n end
                    if shipped ~= nil then
                        c.reached = c.reached + 1
                        local near, neard = nearest_ally(J, bot)
                        local shipd = GetUnitToUnitDistance(bot, shipped)
                        if near ~= shipped then
                            c.differ = c.differ + 1
                            local gap = shipd - neard
                            if gap > c.gap_max then c.gap_max = gap end
                            local hp_ship = (J.GetHP(bot) >= J.GetHP(shipped))
                            local hp_near = (J.GetHP(bot) >= J.GetHP(near))
                            if hp_ship ~= hp_near then
                                c.hpguard_flip = c.hpguard_flip + 1
                            end
                            if parity_true(J, bot, shipped) ~= parity_true(J, bot, near) then
                                c.parity_flip = c.parity_flip + 1
                            end
                            seen_fixture[path] = true
                            witnesses[#witnesses + 1] = string.format(
                                '%s  %s  t=%.1f  shipped=%s@%.0f  nearest=%s@%.0f  gap=%.0f  cand=%d hpflip=%s parflip=%s',
                                path:gsub('tests/fixtures/', ''),
                                u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                                shipped:GetUnitName():gsub('npc_dota_hero_', ''), shipd,
                                near:GetUnitName():gsub('npc_dota_hero_', ''), neard,
                                gap, n,
                                tostring(hp_ship ~= hp_near),
                                tostring(parity_true(J, bot, shipped) ~= parity_true(J, bot, near)))
                        else
                            c.both_same_hero = c.both_same_hero + 1
                        end
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

for _, k in ipairs({ 'fixtures', 'live', 'reached', 'both_same_hero', 'differ',
                     'cand_max', 'gap_max', 'hpguard_flip', 'parity_flip' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('P fixtures_with_a_difference ', tostring(nfx), '\n')
for _, w in ipairs(witnesses) do out:write('W ', w, '\n') end
out:write('DONE\n')
