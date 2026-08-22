-- Corpus census behind tests/test_replay_260822_fieldbuy_supply.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$' and
-- this file is meant to run in its OWN process, driven by that test via
-- io.popen. Reason is the strategy charter's 0q rule -- rebuilding jmz_func
-- once per hero-frame (~930 loads) inside the suite's long-lived heap makes
-- the cost depend on where the calling file lands in the alphabet.
--
-- Usage: lua5.1 tests/_fieldbuy_supply_sweep.lua
-- Manifest grammar (one record per line, space separated):
--   CONST <name> <value>          a shipped constant, READ FROM SOURCE
--   C <key> <n>                   a counter bucket
--   GAPF <fixture> <hero> <hp> <level> <t> <laning>
--   DONE                          absence of this line = failed subprocess
--
-- Every predicate below is the SHIPPED helper called on the real frame. None
-- of them is restated here: the M13 lesson is that a census which copies the
-- constant it measures reports the old world unmoved after the constant moves,
-- so the four thresholds this file reasons about are parsed out of the two
-- shipped files and asserted to still be there.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

local JMZ = read_file('bots/FunLib/jmz_func.lua')
local PURCHASE = read_file('bots/item_purchase_generic.lua')

-- The HP band the whole stayfield/fieldbuy family reads, from its own source.
local BAND_LO, BAND_HI = (function()
    local at = assert(JMZ:find('function J.IsFieldRegenSituation', 1, true),
        'J.IsFieldRegenSituation moved')
    local body = JMZ:sub(at, at + 3000)
    local lo, hi = body:match('nHP < ([%d%.]+) or nHP > ([%d%.]+)')
    assert(lo, 'the HP band is no longer a single two-sided comparison')
    return tonumber(lo), tonumber(hi)
end)()

-- 'fieldregen' -- the shipped mid-game salve re-purchase, gated and already in
-- the armed test set. Its HP ceiling and its laning-phase clause are the two
-- reasons it cannot reach this lever's frames.
local FR_CEILING = (function()
    local at = assert(PURCHASE:find("J.IsSoakCandidate('fieldregen')", 1, true),
        'the fieldregen block moved')
    local body = PURCHASE:sub(at, at + 1200)
    local v = body:match('J%.GetHP%(bot%) < ([%d%.]+)')
    assert(v, 'fieldregen no longer carries a single HP ceiling')
    assert(body:find('not J.IsInLaningPhase()', 1, true),
        'fieldregen no longer carries its laning-phase clause -- this census '
        .. 'is built on the claim that it is silent during laning')
    return tonumber(v)
end)()

-- The shipped in-lane re-supply block, which stops at a level cap.
local LANE_LEVEL_CAP = (function()
    local at = assert(PURCHASE:find('-- Init Healing Items in Lane', 1, true),
        'the in-lane healing block moved')
    local body = PURCHASE:sub(at, at + 600)
    local v = body:match('botLevel < (%d+)')
    assert(v, 'the in-lane healing block no longer carries a level cap')
    return tonumber(v)
end)()

-- Turbo's hard laning floor: the part of J.IsInLaningPhase that does not
-- depend on net worth, so a frame below it is laning on every fixture,
-- including the v1 ones whose net worth reads 0.
local TURBO_LANE_FLOOR = (function()
    local at = assert(JMZ:find('function J.IsInLaningPhase', 1, true),
        'J.IsInLaningPhase moved')
    local body = JMZ:sub(at, at + 1200)
    local v = body:match('local nFloor = bTurbo and (%d+) %* 60')
    assert(v, 'the turbo laning floor is no longer a literal')
    return tonumber(v) * 60
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

local out = io.stdout
local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k) rawset(c, k, c[k] + 1) end

local gapf = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, err = pcall(function()
                    local J, bot = rf.load(path, u.name)
                    bump('live')
                    J.IsSoakCandidate = function(id) return id == 'fieldbuy' end

                    local nHP = J.GetHP(bot)
                    local bBand = nHP >= BAND_LO and nHP <= BAND_HI
                    local bHeal = J.HasFieldRegenSource(bot)
                    local bSituation = J.IsFieldRegenSituation(bot)
                    local bGap = J.ShouldBuyFieldRegen(bot)
                    local bStay = J.ShouldRegenNotGoHome(bot)

                    if bBand then bump('band') end
                    if bBand and not bHeal then bump('band_noheal') end
                    if bSituation then bump('situation') end
                    if bStay then bump('stayfield_domain') end

                    -- Corpus-wide inertness: with no candidate armed the gated
                    -- helper must be false on every frame in the corpus, not
                    -- just on the pinned ones.
                    J.IsSoakCandidate = function() return false end
                    if J.ShouldBuyFieldRegen(bot) then bump('gap_gate_off') end
                    J.IsSoakCandidate = function(id) return id == 'fieldbuy' end

                    if bGap then
                        bump('gap')
                        local nLevel = bot:GetLevel()
                        local nT = fx.time or -1
                        local bLaning = J.IsInLaningPhase()
                        if nHP < FR_CEILING then bump('gap_under_fr_ceiling') end
                        if nT < TURBO_LANE_FLOOR then bump('gap_hard_laning') end
                        if nLevel >= LANE_LEVEL_CAP then bump('gap_level_ge_cap') end
                        if nT < TURBO_LANE_FLOOR and nLevel >= LANE_LEVEL_CAP then
                            bump('gap_both_holes')
                        end
                        -- What the purchase call site additionally requires.
                        local bOwns = bot:FindItemSlot('item_flask') >= 0
                            or bot:FindItemSlot('item_tango') >= 0
                        local nEmpty = 0
                        for i = 0, 8 do
                            if bot:GetItemInSlot(i) == nil then nEmpty = nEmpty + 1 end
                        end
                        local bHealing = bot:HasModifier('modifier_flask_healing')
                            or bot:HasModifier('modifier_fountain_aura_buff')
                        if bHealing then bump('gap_already_healing') end
                        if not bOwns and nEmpty >= 1 and not bHealing then
                            bump('gap_buyable')
                        end
                        gapf[#gapf + 1] = string.format('GAPF %s %s %.4f %d %.1f %s',
                            path:gsub('tests/fixtures/', ''), u.name, nHP, nLevel,
                            nT, tostring(bLaning))
                    end
                end)
                if not ok then
                    bump('err')
                    out:write('ERR ' .. path .. ' ' .. tostring(err) .. '\n')
                end
            end
        end
    end
end

for _, kv in ipairs({ { 'band_lo', BAND_LO }, { 'band_hi', BAND_HI },
                      { 'fr_ceiling', FR_CEILING },
                      { 'lane_level_cap', LANE_LEVEL_CAP },
                      { 'turbo_lane_floor', TURBO_LANE_FLOOR } }) do
    out:write(string.format('CONST %s %s\n', kv[1], tostring(kv[2])))
end
for _, k in ipairs({ 'fixtures', 'live', 'err', 'band', 'band_noheal', 'situation',
                     'stayfield_domain', 'gap', 'gap_gate_off', 'gap_under_fr_ceiling',
                     'gap_hard_laning', 'gap_level_ge_cap', 'gap_both_holes',
                     'gap_already_healing', 'gap_buyable' }) do
    out:write(string.format('C %s %d\n', k, c[k]))
end
for _, l in ipairs(gapf) do out:write(l .. '\n') end
out:write('DONE\n')
