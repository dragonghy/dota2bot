-- Corpus sweep for tests/test_cm_pos5_boots.lua, run as a SUBPROCESS (the
-- backlog 0q rule keeps corpus-wide dofile loops off run_tests.lua's long-lived
-- heap). The leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IT MEASURES
-- ----------------
-- Crystal Maiden's pos_5 boots, the lever GH #126 asked for: tranquil (what the
-- build shipped until 2026-08-23) vs arcane (what it ships now), priced on the
-- frames this repo actually has.  Two channels, kept apart on purpose:
--
--   (1) COUNTERFACTUAL, on tranquil-carrying CM frames: ready ability slots
--       (trained, off cooldown) that cannot pay their own mana cost, and how
--       many of those a mana delta would unblock.  Static -- it adds mana to a
--       frame whose whole history would have differed -- so it is an upper
--       bound on the flip rate, never a rate.
--   (2) OBSERVATIONAL, the natural experiment already in the corpus: CM frames
--       that carry ARCANE boots today (the pos_4 priest_outfit line) against
--       the tranquil-carrying ones.  Confounded -- pos_4 and pos_5 differ in
--       the whole build, not just the boots -- and the confound is reported
--       (mean level per arm) rather than argued away.
--
-- It also counts, corpus-wide, who owns Boots of Bearing (the terminus the
-- swap removes) and how long the observation window is, so that zero can be
-- read as OUT-OF-WINDOW rather than as EMPTY.
--
-- EXTERNAL ANCHORS (the dump carries no ability or item specs):
--   * mana costs by rank, datafeed hero_id=5 read 2026-08-23 -- same table as
--     tests/_cm_t10_payoff_sweep.lua, deliberately duplicated rather than
--     shared so a change to one investigation cannot silently move the other.
--   * item numbers, api.opendota.com/api/constants/items read 2026-08-23:
--       arcane_boots   1500g  +125 mana, +45 ms, +0.25 mana regen,
--                             Basilius aura +1 mana regen (1200),
--                             Replenish 150 mana to allies in 1200, cd 55s
--       tranquil_boots  900g  +65 ms (40 while broken, 13s on any hit),
--                             +14 hp regen, lost while broken
--       boots_of_bearing 4225g = tranquil_boots + ancient_janggo
--                             + ring_of_tarrasque
--     The three mana deltas below are named after those numbers but reported
--     side by side so no verdict hangs off a single one.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                     counter bucket
--   ARM <T|A|X> <frames> <levelsum> <slots> <blocked>
--   ROW <fixture> <T|A|X> <lv> <mp> <maxmp> <hp> <maxhp> <slots> <blocked> <janggo01>
--   SLOT <fixture> <T|A|X> <ability> <rank> <cost> <mp> <blocked01>
--   DELTA <mana_delta> <unblocked>  on arm T only
--   BEARING <fixture> <unit>        any corpus unit holding boots_of_bearing
--   WINDOW <min> <median> <max>     fixture timestamps, seconds
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

local out = io.stdout

-- datafeed hero_id=5, 2026-08-23; index = ability rank.
local COSTS = {
    crystal_maiden_crystal_nova   = { 115, 135, 155, 175 },
    crystal_maiden_frostbite      = { 125, 135, 145, 155 },
    crystal_maiden_freezing_field = { 200, 400, 600 },
}

-- +125  arcane's flat mana, and nothing else
-- +144  the +12 INT talent this desk declined at t10 (GH #126 part one), kept
--       here as the calibration point: arcane's STATIC half is smaller than the
--       talent that was judged insufficient on its own.
-- +275  arcane after one Replenish, i.e. the repeatable half (cd 55s)
local DELTAS = { 125, 144, 275 }

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end

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

--- Which boots arm a frame belongs to. 'T' tranquil, 'A' arcane, 'X' neither.
local function arm_of(tHeld)
    if tHeld.tranquil_boots then return 'T' end
    if tHeld.arcane_boots then return 'A' end
    return 'X'
end

local arms = { T = { n = 0, lv = 0, slots = 0, blocked = 0 },
               A = { n = 0, lv = 0, slots = 0, blocked = 0 },
               X = { n = 0, lv = 0, slots = 0, blocked = 0 } }
local unblocked = {}
for _, d in ipairs(DELTAS) do unblocked[d] = 0 end
local times = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        times[#times + 1] = fx.time
        for _, u in ipairs(fx.units) do
            local tHeld = {}
            for _, s in ipairs(u.items or {}) do
                if s ~= '' then
                    tHeld[s] = true
                    if s == 'boots_of_bearing' then
                        bump('bearing_owners')
                        out:write(string.format('BEARING %s %s\n', path, u.name))
                    end
                end
            end
            if u.name == 'npc_dota_hero_crystal_maiden' and u.alive then
                bump('cm_frames')
                local sArm = arm_of(tHeld)
                local a = arms[sArm]
                a.n = a.n + 1
                a.lv = a.lv + (u.level or 0)
                if tHeld.ancient_janggo then bump('cm_janggo') end

                local nSlots, nBlocked = 0, 0
                for _, ab in ipairs(u.abilities or {}) do
                    local tCosts = COSTS[ab.name]
                    if tCosts ~= nil and (ab.level or 0) > 0 and (ab.cd or 0) <= 0 then
                        nSlots = nSlots + 1
                        a.slots = a.slots + 1
                        local nCost = tCosts[math.min(ab.level, #tCosts)]
                        local bBlocked = u.mp < nCost
                        if bBlocked then
                            nBlocked = nBlocked + 1
                            a.blocked = a.blocked + 1
                            if sArm == 'T' then
                                for _, d in ipairs(DELTAS) do
                                    if u.mp + d >= nCost then
                                        unblocked[d] = unblocked[d] + 1
                                    end
                                end
                            end
                        end
                        out:write(string.format('SLOT %s %s %s %d %d %d %d\n',
                            path, sArm, ab.name, ab.level, nCost, u.mp,
                            bBlocked and 1 or 0))
                    end
                end
                out:write(string.format('ROW %s %s %d %d %d %d %d %d %d %d\n',
                    path, sArm, u.level or 0, u.mp, u.max_mp, u.hp, u.max_hp,
                    nSlots, nBlocked, tHeld.ancient_janggo and 1 or 0))
            end
        end
    end
end

table.sort(times)
out:write(string.format('WINDOW %.1f %.1f %.1f\n',
    times[1] or 0, times[math.ceil(#times / 2)] or 0, times[#times] or 0))
for _, k in ipairs({ 'T', 'A', 'X' }) do
    local a = arms[k]
    out:write(string.format('ARM %s %d %d %d %d\n', k, a.n, a.lv, a.slots, a.blocked))
end
for _, d in ipairs(DELTAS) do out:write(string.format('DELTA %d %d\n', d, unblocked[d])) end
local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
