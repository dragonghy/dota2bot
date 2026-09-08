-- Corpus census for the `tpChannelStartHealth` STAMP SITE, run as a SUBPROCESS
-- (backlog 0q: a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap). The leading underscore keeps
-- run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  `J.ShouldAbandonTpChannel` (soak id `tpwatch`) decides
-- "this TP channel is being eaten" by comparing current health against
-- `bot.tpChannelStartHealth`.  That stamp has exactly ONE writer, and the writer
-- lives INSIDE the predicate itself (bots/FunLib/jmz_func.lua, the
-- `if bot.tpChannelStartHealth == nil then ... = bot:GetHealth()` block).  So
-- the baseline is not "health when the channel began"; it is "health on the
-- first frame of the channel on which somebody CALLED the predicate".
--
-- Who calls it decides when that is, and both callers are conditional:
--   * mode_retreat_generic.lua's retreat chain -- but the call sits BELOW the
--     PROMOTED `J.ShouldAbortDeepSoloPush` floor, and that chain returns on the
--     first guard that fires.  A frame that trips pushguard never reaches the
--     stamp.
--   * J.ShouldLetTpChannelFinish -- which returns false at its own
--     `J.IsSoakCandidate('pgchannel')` line before it ever gets to the call.
--
-- Two consequences, and this census exists to price them rather than argue them:
--   (1) MISSED FRAMES.  On a channeling frame where an earlier guard returns,
--       no stamp is taken at all.  If the stamp is finally taken later in the
--       channel, it is taken AFTER some of the damage the guard exists to
--       notice -- a baseline biased in the direction that makes `tpwatch`
--       under-fire.
--   (2) ARM-DEPENDENT BASELINE.  Arming `pgchannel` moves the first call from
--       below pushguard to above it.  So which id is armed changes the OTHER
--       id's measurement -- the exact cross-id coupling mode_retreat_generic's
--       own GH #29 note calls out as breaking the "one variable at a time"
--       premise the soak-candidate A/B rests on.
--
-- Readings, so a zero can be attributed:
--   * how many live frames carry `modifier_teleporting` at all (can the mock
--     see a channel?),
--   * of those, on how many the SHIPPED chain leaves the stamp unwritten,
--   * the same count with `pgchannel` armed (the coupling, as a number), and
--   * which guard returned first on each missed frame.
--
-- NOT A PINNED INSTRUMENT.  The lever's own behavioural readings are pinned by
-- tests/test_tpstamp_channel_baseline.lua, which drives the same frames
-- directly rather than re-parsing this manifest.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   S <fixture> <hero> <shipped> <pgchannel> <tpwatch> <tpwatch+pgchannel> <shipped-desire>
--       each of the four arms reporting whether that drive left a stamp behind
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
local jmz = read_file('bots/FunLib/jmz_func.lua')
local retreat = read_file('bots/mode_retreat_generic.lua')

-- PARSED, never hardcoded (the M13 lesson). `nil` is a FAILED PARSE, not a
-- zero, so it is printed as such rather than silently skipped (the GH #171
-- shape).
G.PUSHGUARD_FLOOR = tonumber(retreat:match(
    'ShouldAbortDeepSoloPush%(bot%).-return ([%d%.]+)')
    or retreat:match('ShouldAbortDeepSoloPush%( bot %).-return ([%d%.]+)'))
-- How many places in bots/ assign tpChannelStartHealth a health value. The
-- whole defect is that this is 1 and it lives inside the predicate.
local nWriters = 0
for _ in jmz:gmatch('tpChannelStartHealth%s*=%s*bot:GetHealth') do
    nWriters = nWriters + 1
end
G.STAMP_WRITERS = nWriters
-- Does a record-only stamp call exist above the retreat chain yet?
G.STAMP_HOISTED = retreat:find('StampTpChannelHealth', 1, true) and 1 or 0

for _, k in ipairs({ 'PUSHGUARD_FLOOR', 'STAMP_WRITERS', 'STAMP_HOISTED' }) do
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
for _, k in ipairs({ 'fixtures', 'live', 'channeling',
    'shipped_stamped', 'shipped_missed',
    'pgchannel_stamped', 'pgchannel_missed',
    'tpwatch_stamped', 'tpwatch_missed',
    'tw_pg_stamped', 'tw_pg_missed',
    'coupling_frames', 'coupling_open_armed', 'drive_failed' }) do
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
                    if bot:HasModifier('modifier_teleporting') then
                        bump('channeling')
                        local okd, helper = pcall(function()
                            dofile('bots/mode_retreat_generic.lua')
                            return GetDesireHelper
                        end)
                        if not okd or helper == nil then
                            bump('drive_failed')
                        else
                            -- One arm per line. The stamp is cleared before each
                            -- drive so what is read back is what THIS drive
                            -- wrote, not a leftover from the previous arm.
                            local function drive(a)
                                bot.tpChannelStartHealth = nil
                                armed = a
                                local okr, d = pcall(helper)
                                local stamped = bot.tpChannelStartHealth ~= nil
                                return stamped, (okr and type(d) == 'number') and d or nil
                            end
                            local s0, d0 = drive({})
                            local s1 = drive({ pgchannel = true })
                            local s2 = drive({ tpwatch = true })
                            local s3 = drive({ tpwatch = true, pgchannel = true })
                            if s0 then bump('shipped_stamped') else bump('shipped_missed') end
                            if s1 then bump('pgchannel_stamped') else bump('pgchannel_missed') end
                            if s2 then bump('tpwatch_stamped') else bump('tpwatch_missed') end
                            if s3 then bump('tw_pg_stamped') else bump('tw_pg_missed') end
                            -- THE COUPLING, as two counters rather than a claim.
                            -- `coupling_frames` is the DEFECT: with the stamp
                            -- reachable only from inside the predicate, arming
                            -- `pgchannel` -- an id with nothing to do with this
                            -- stamp -- decides whether `tpwatch` has a baseline.
                            -- It is measured on the pair of arms that do NOT arm
                            -- tpwatch, so it keeps reporting the shipped-tree
                            -- shape after the fix; that is the point, not a bug.
                            -- `coupling_open_armed` is the one the fix closes:
                            -- on tpwatch's OWN arm, does adding pgchannel still
                            -- move tpwatch's baseline? A hoisted stamp makes it
                            -- 0 because the stamp no longer depends on which
                            -- guard the chain happens to reach.
                            if s0 ~= s1 then bump('coupling_frames') end
                            if s2 ~= s3 then bump('coupling_open_armed') end
                            out:write(string.format('S %s %s %s %s %s %s %s\n',
                                short, u.name, tostring(s0), tostring(s1),
                                tostring(s2), tostring(s3), tostring(d0)))
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
