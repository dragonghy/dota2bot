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
-- It also PRICES, corpus-wide, the terminus the swap removes: who owns Boots of
-- Bearing, when they bought it (the item's own modifier carries its age), what
-- the recipe consumed to get there, and how far the aura reaches in the same
-- frame.  Until 2026-08-28 there were no owners and this channel could only
-- report the observation window, so the zero was read as OUT-OF-WINDOW rather
-- than as EMPTY; it now has owners and reports the purchase instead.
--
-- CLOCK CONVENTION, measured rather than assumed.  A modifier's `elapsed` runs
-- on an engine clock whose origin PRECEDES the frame's `time` (which starts at
-- the horn): the corpus contains modifiers with elapsed > time, and the counter
-- `pregame_mods` below reports how many.  So an acquisition instant is
-- `time - elapsed`, and it is allowed to come out negative for something held
-- from spawn.  A small elapsed on a bought item is therefore safe to read
-- directly -- 11.9s of age at t=785.4 cannot be a clock-origin artefact.
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
--   TERM <fixture> <unit> <t> <lv> <nw> <mp> <maxmp> <acq> <tranq01> <janggo01>
--                                   <aura_allies> <team_alive>
--                                   one per Bearing owner: the terminus, priced.
--                                   <acq> = t - elapsed of the item's own
--                                   modifier, i.e. when it entered the
--                                   inventory (see CLOCK CONVENTION above).
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

--- Age of a named modifier on a unit, in seconds, or nil if it is not there.
local function modifier_age(u, sName)
    for _, m in ipairs(u.modifiers or {}) do
        if m.name == sName then return m.elapsed end
    end
    return nil
end

local BEARING_AURA = 'modifier_item_boots_of_bearing_aura'

--- How far the Bearing aura reached in this frame: allies (excluding the owner
--- itself, which always carries it) holding the aura modifier, and how many
--- living units the owner's team has on the frame at all -- the denominator,
--- so a "1 of 1" cannot be read as a "1 of 5".
local function aura_reach(fx, nOwner)
    local u = fx.units[nOwner]
    local nHit, nTeam = 0, 0
    for i, o in ipairs(fx.units) do
        if o.team == u.team and o.alive and i ~= nOwner then
            nTeam = nTeam + 1
            if modifier_age(o, BEARING_AURA) ~= nil then nHit = nHit + 1 end
        end
    end
    return nHit, nTeam
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
        for iU, u in ipairs(fx.units) do
            local tHeld = {}
            for _, s in ipairs(u.items or {}) do
                if s ~= '' then tHeld[s] = true end
            end
            -- The clock-origin control (see CLOCK CONVENTION in the header):
            -- modifiers older than the frame's own clock exist, so `elapsed`
            -- is not measured from the horn.
            for _, m in ipairs(u.modifiers or {}) do
                bump('mods_total')
                if (m.elapsed or 0) > fx.time then bump('pregame_mods') end
            end
            if tHeld.boots_of_bearing then
                bump('bearing_owners')
                out:write(string.format('BEARING %s %s\n', path, u.name))
                local nAge = modifier_age(u, 'modifier_item_boots_of_bearing')
                local nHit, nTeam = aura_reach(fx, iU)
                out:write(string.format(
                    'TERM %s %s %.1f %d %d %d %d %.1f %d %d %d %d\n',
                    path, u.name, fx.time, u.level or 0, u.net_worth or 0,
                    u.mp or 0, u.max_mp or 0,
                    nAge and (fx.time - nAge) or -99999,
                    tHeld.tranquil_boots and 1 or 0,
                    tHeld.ancient_janggo and 1 or 0, nHit, nTeam))
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
