-- Corpus census for the pushguard-vs-TP-channel collision, run as a SUBPROCESS
-- (backlog 0q: a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap). The leading underscore keeps
-- run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  J.ShouldAbortDeepSoloPush is PROMOTED -- live in every
-- turbo game -- and its retreat consumer (mode_retreat_generic, 0.92) is the
-- FIRST guard in the priority chain.  The helper never asks whether the bot is
-- already leaving by TP.  The tree states the consequence itself, in
-- J.ShouldAbandonTpChannel's own header: "the caller raises retreat desire so
-- the move order cancels the channel".  So on a frame where the bot is deep,
-- solo, two defenders converging AND mid-channel, the shipped chain cancels the
-- one exit that was already working.
--
-- Readings, so a zero can be attributed:
--   * how many live frames carry modifier_teleporting at all (is the mock able
--     to see a channel?),
--   * how many of those are ALSO in the pushguard trigger domain, and
--   * on EVERY channeling frame -- not only the pushguard ones -- what
--     mode_retreat_generic's real GetDesireHelper() returns shipped and armed.
--     That last one is why this census exists: the first draft of the fix was a
--     conjunct on the pushguard floor, and driving the real chain is what showed
--     it merely handing the frame to the NEXT floor (0.92 -> 0.75) instead of
--     releasing it.  A gate-plumbing test on that conjunct passed.
--
-- NOT A PINNED INSTRUMENT.  The readings quoted from this file are the corpus
-- SIZES (23 channeling / 1021 live, 4 high floors, 1 pushguard overlap); the
-- lever's own behavioural readings are pinned instead by
-- tests/test_pgchannel_veto.lua, which asserts them by driving the same frames
-- directly rather than by re-parsing this manifest.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   H <fixture> <hero> <shipped> <armed> <pushguard-fires>  one channeling frame
--   T <fixture> <hero> <shipped> <armed>   one frame in the pushguard overlap
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local G = {}
local retreat = read_file('bots/mode_retreat_generic.lua')
-- The floor value is PARSED, never hardcoded (the M13 lesson). `nil` here is a
-- FAILED PARSE, not a zero, so it is printed as such rather than skipped by a
-- pairs() walk -- the GH #171 shape.
G.PUSHGUARD_FLOOR = tonumber(retreat:match(
    'ShouldAbortDeepSoloPush%(bot%).-return ([%d%.]+)')
    or retreat:match('ShouldAbortDeepSoloPush%( bot %).-return ([%d%.]+)'))
G.EXEMPTION_ID = retreat:find("pgchannel", 1, true) and 1 or 0
for _, k in ipairs({ 'PUSHGUARD_FLOOR', 'EXEMPTION_ID' }) do
    out:write(string.format('G %s %s\n', k, tostring(G[k])))
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

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end
for _, k in ipairs({ 'fixtures', 'live', 'channeling', 'pg_fires',
    'pg_and_channeling', 'desire_raised', 'shipped_is_floor', 'armed_changed',
    'chan_floored_high', 'chan_at_pg_floor', 'chan_desire_raised',
    'chan_changed', 'chan_high_released', 'chan_armed_not_veto' }) do
    rawset(c, k, 0)
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local short = path:match('([^/]+)%.lua$')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local armed = {}
                    J.IsSoakCandidate = function(id) return armed[id] == true end
                    local bChan = bot:HasModifier('modifier_teleporting')
                    local okp, fired = pcall(J.ShouldAbortDeepSoloPush, bot)
                    local bFires = okp and fired == true
                    if bFires then bump('pg_fires') end
                    -- EVERY channeling frame gets the chain driven on it, not
                    -- only the pushguard ones: "how often does the shipped chain
                    -- order a channeling bot to walk" is the question that says
                    -- whether this lever belongs at pushguard or higher up, and
                    -- a census restricted to the lever's own domain cannot ask
                    -- it.
                    if bChan then
                        bump('channeling')
                        local okd, helper = pcall(function()
                            dofile('bots/mode_retreat_generic.lua')
                            return GetDesireHelper
                        end)
                        if okd and helper ~= nil then
                            armed = {}
                            local ok1, d1 = pcall(helper)
                            armed = { pgchannel = true }
                            local ok2, d2 = pcall(helper)
                            if ok1 and ok2 and type(d1) == 'number' and type(d2) == 'number' then
                                if d1 >= 0.75 then
                                    bump('chan_floored_high')
                                    if d2 < d1 then bump('chan_high_released') end
                                end
                                if d1 == G.PUSHGUARD_FLOOR then bump('chan_at_pg_floor') end
                                if d1 ~= d2 then bump('chan_changed') end
                                if d2 ~= 0 then bump('chan_armed_not_veto') end
                                out:write(string.format('H %s %s %s %s %s\n',
                                    short, u.name, tostring(d1), tostring(d2), tostring(bFires)))
                            else
                                bump('chan_desire_raised')
                            end
                        else
                            bump('chan_desire_raised')
                        end
                    end
                    if bFires and bChan then
                        bump('pg_and_channeling')
                        -- Drive the REAL chain, both arms, on the same frame.
                        local okd, helper = pcall(function()
                            dofile('bots/mode_retreat_generic.lua')
                            return GetDesireHelper
                        end)
                        if not okd or helper == nil then
                            bump('desire_raised')
                        else
                            armed = {}
                            local ok1, d1 = pcall(helper)
                            armed = { pgchannel = true }
                            local ok2, d2 = pcall(helper)
                            if not ok1 or not ok2 then
                                bump('desire_raised')
                            else
                                if d1 == G.PUSHGUARD_FLOOR then bump('shipped_is_floor') end
                                if d1 ~= d2 then bump('armed_changed') end
                                out:write(string.format('T %s %s %s %s\n',
                                    short, u.name, tostring(d1), tostring(d2)))
                            end
                        end
                    end
                end
            end
        end
    end
end

local ck = {}
for k in pairs(c) do ck[#ck + 1] = k end
table.sort(ck)
for _, k in ipairs(ck) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
