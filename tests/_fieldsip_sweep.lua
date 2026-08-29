-- Heavy corpus sweep for tests/test_fieldsip_magnitude.lua, run as a
-- SUBPROCESS (the backlog 0q rule: a full-corpus drive that rebuilds jmz_func
-- once per hero-frame must not run on run_tests.lua's long-lived heap). The
-- leading underscore keeps run_tests.lua from globbing it.
--
-- It prints a flat manifest to stdout; the test parses it and every census
-- assertion reads from it. NOTE: print() is not usable here -- the loaded
-- bots/ world replaces it -- so every line goes through io.write.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                     a counter bucket
--   ROW <fixture> <hero> <hp01> <maxhp> <sip> <frac4>
--       one live hero frame where J.IsFieldRegenSituation holds AND
--       J.HasFieldRegenSource is TRUE, i.e. the population 'fieldsip' can
--       speak on. sip = J.FieldRegenSipValue in health, frac4 = sip/maxhp
--       scaled by 10000 so the manifest stays integer.
--   GRID <threshold_x1000> <released>
--       how many of those rows a given threshold would release. This is what
--       makes the constant non-load-bearing: the test asserts the whole open
--       interval of the corpus gap gives one answer.
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

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

-- The impossible-state counters are zero-initialised so they are ALWAYS
-- emitted. Without this an absent key and a measured zero look identical to
-- the parser, and "the assertion never ran" would read as "the assertion
-- passed" -- the GH #171 shape.
for _, k in ipairs({ 'IMPOSSIBLE_partition_unarmed', 'IMPOSSIBLE_partition_armed',
    'IMPOSSIBLE_hold_widened', 'IMPOSSIBLE_buy_narrowed',
    'IMPOSSIBLE_source_without_value', 'released', 'now_buys' }) do
    rawset(c, k, 0)
end

local rows = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                bump('live')
                local J, bot = rf.load(path, u.name)
                J.IsSoakCandidate = function() return false end

                local sit = J.IsFieldRegenSituation(bot)
                if sit then
                    bump('situation')
                    local src = J.HasFieldRegenSource(bot)
                    if src then bump('with_source') else bump('dry') end

                    -- Unarmed both consumers, i.e. the shipped answers.
                    local hold0 = J.ShouldRegenNotGoHome(bot)
                    J.IsSoakCandidate = function(id) return id == 'fieldbuy' end
                    local buy0 = J.ShouldFieldBuyRegen(bot)

                    -- Armed. 'fieldbuy' stays armed for the buy read because
                    -- that id is its own on/off switch and is NOT what is
                    -- under test here.
                    J.IsSoakCandidate = function(id) return id == 'fieldsip' end
                    local hold1 = J.ShouldRegenNotGoHome(bot)
                    J.IsSoakCandidate = function(id)
                        return id == 'fieldbuy' or id == 'fieldsip'
                    end
                    local buy1 = J.ShouldFieldBuyRegen(bot)

                    -- The partition: on a situation frame with fieldbuy armed,
                    -- exactly one of hold/buy must be true, armed or not.
                    if hold0 == buy0 then bump('IMPOSSIBLE_partition_unarmed') end
                    if hold1 == buy1 then bump('IMPOSSIBLE_partition_armed') end
                    -- One-directionality: the hold may only lose frames and
                    -- the buy may only gain them.
                    if hold1 and not hold0 then bump('IMPOSSIBLE_hold_widened') end
                    if buy0 and not buy1 then bump('IMPOSSIBLE_buy_narrowed') end
                    if hold0 and not hold1 then bump('released') end
                    if buy1 and not buy0 then bump('now_buys') end

                    J.IsSoakCandidate = function() return false end

                    if src then
                        local sip = J.FieldRegenSipValue(bot)
                        local mx = bot:GetMaxHealth() or 0
                        -- A frame the presence test accepts must have a value:
                        -- the two helpers read the same slots and the same
                        -- bottle-charge test, so a zero here is a real drift.
                        if sip <= 0 then bump('IMPOSSIBLE_source_without_value') end
                        if mx > 0 then
                            rows[#rows + 1] = sip / mx
                            out:write(string.format('ROW %s %s %.4f %d %d %d\n',
                                path, u.name, u.hp / u.max_hp, mx, sip,
                                math.floor(sip / mx * 10000 + 0.5)))
                        end
                    end
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end

-- The grid that makes the constant non-load-bearing. Stepped at 0.005 across
-- the whole plausible range so the test can find the corpus's own gap rather
-- than being told where it is.
for i = 10, 500, 5 do
    local t = i / 1000
    local n = 0
    for _, f in ipairs(rows) do if f < t then n = n + 1 end end
    out:write(string.format('GRID %d %d\n', i, n))
end

out:write('DONE\n')
