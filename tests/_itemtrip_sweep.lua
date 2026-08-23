-- Corpus sweep for tests/test_itemtrip_wasteful_trip.lua, run as a SUBPROCESS
-- (the backlog 0q rule: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame -- ~940 loads -- must not run on run_tests.lua's long-lived
-- heap). The leading underscore keeps run_tests.lua from globbing it
-- (`^test_.*%.lua$`).
--
-- It prints a flat manifest to stdout; the test parses it and every census
-- assertion reads from it. NOTE: print() is not usable here -- the loaded
-- bots/ world replaces it -- so every line goes through io.write.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>            a counter bucket
--   WHY <clause> <n>       first clause that refused, over live hero frames:
--                          hp | ring | dist | dmg, and 'yes' for the frames
--                          where J.IsWastefulItemTrip holds
--   BAG <key> <n>          inventory occupancy WITHIN the wasteful domain --
--                          the clause this lever deliberately does NOT have.
--                          full = zero empty slots of nine.
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

-- The three constants are READ FROM SOURCE, not restated here (the M13 lesson:
-- a census that copies the constant it measures reports the old world unmoved
-- after the constant moves). The why-decomposition below has to ask the same
-- questions the shipped clauses ask, or it is measuring a different function.
local HP_FLOOR, RING, FOUNTAIN = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local body = src:match('\nfunction J%.IsWastefulItemTrip%( bot %)(.-)\nend\n')
    assert(body, 'J.IsWastefulItemTrip is gone or no longer a top-level function')
    local hp = body:match('J%.GetHP%( bot %) < ([%d%.]+)')
    local ring = body:match('J%.GetNearbyHeroes%( bot, (%d+), true')
    local fountain = body:match('J%.GetDistanceFromAllyFountain%( bot %) < (%d+)')
    assert(hp and ring and fountain,
        'the clause shapes moved; this sweep can no longer decompose them')
    return tonumber(hp), tonumber(ring), tonumber(fountain)
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

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                bump('live')
                local J, bot = rf.load(path, u.name)
                -- This predicate carries no gate of its own -- the gate is the
                -- load-time one in bots/mode_item_generic.lua -- so arming
                -- nothing is the honest world to measure it in.
                J.IsSoakCandidate = function() return false end

                local wasteful = J.IsWastefulItemTrip(bot)
                if wasteful then bump('wasteful') end

                -- First refusing clause, in the shipped order.
                local why
                if J.GetHP(bot) < HP_FLOOR then why = 'hp'
                elseif #J.GetNearbyHeroes(bot, RING, true, BOT_MODE_NONE) > 0 then why = 'ring'
                elseif J.GetDistanceFromAllyFountain(bot) < FOUNTAIN then why = 'dist'
                elseif not wasteful then why = 'dmg'
                else why = 'yes' end
                bump('why_' .. why)

                -- The bag, inside the domain only. This lever has NO inventory
                -- clause on purpose (see the head comment of
                -- J.IsWastefulItemTrip); this row is what makes that a measured
                -- decision instead of an omission somebody has to re-derive.
                if wasteful then
                    local empty = 0
                    for i = 0, 8 do
                        if bot:GetItemInSlot(i) == nil then empty = empty + 1 end
                    end
                    if empty == 0 then bump('bag_full') else bump('bag_room') end
                end
            end
        end
    end
end

for _, k in ipairs({ 'fixtures', 'live', 'wasteful' }) do
    out:write('C ', k, ' ', c[k], '\n')
end
for _, k in ipairs({ 'yes', 'hp', 'ring', 'dist', 'dmg' }) do
    out:write('WHY ', k, ' ', c['why_' .. k], '\n')
end
out:write('BAG full ', c.bag_full, '\n')
out:write('BAG room ', c.bag_room, '\n')
out:write('DONE\n')
