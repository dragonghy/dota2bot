-- Corpus census for the RETREAT-branch TP gap band (soak candidate 'tpgap',
-- GH #159).  Run as a SUBPROCESS (~32s): it rebuilds jmz_func once per
-- hero-frame, driving EVERY hero on every fixture as the subject, not just
-- fx.self.  The leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IT MEASURES.  Two promoted guards decide whether a retreat TP may be
-- pressed, and their domains do not meet:
--
--     tpsafe  (J.ShouldWalkNotTp)              -- runs on retreat, scans 350
--     tpsafe2 (J.ShouldNotStartInterruptibleTp)-- scans 700, but its call site
--                                                 is scoped to NON-retreat
--
-- so a nearest enemy in (350, 700] is refused by neither.  This sweep sizes
-- that band on real frames, and -- the reason it is a separate file rather than
-- a line in the test -- witnesses the harness fact that makes any REACH-based
-- fix locally unfalsifiable: GetAttackRange answers the mock default 150 on
-- every fixture hero (GH #145), so `nNow <= GetAttackRange() + 150` can only be
-- true inside 300, i.e. strictly BELOW the band this whole issue is about.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>      a counter bucket
--   DONE
-- Absence of the final DONE line is treated by the caller as a failed run.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

-- Both radii are READ FROM THE SHIPPED SOURCE, never restated here (backlog
-- 0SRC: a census that copies the constant it measures reports the old world
-- unmoved after the constant moves).
local BODY = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    local at = assert(s:find('function J.ShouldNotTpUnderLethalPressure', 1, true),
        'J.ShouldNotTpUnderLethalPressure moved or was renamed')
    local body = s:sub(at, at + 1600)
    assert(body:find('GetEstimatedDamageToTarget', 1, true),
        'the source window no longer reaches the burst comparison -- widen it; '
        .. 'the helper itself may be intact')
    return body
end)()

local function num(pat, msg)
    local v = BODY:match(pat)
    assert(v ~= nil, msg)
    return tonumber(v)
end

local ONFACE = num('hOnFaceEnemies%s*=%s*J%.GetNearbyHeroes%(%s*bot,%s*(%d+)',
    'the helper no longer opens with a literal on-face radius')
local BAND = num('hGapEnemies%s*=%s*J%.GetNearbyHeroes%(%s*bot,%s*(%d+)',
    'the helper no longer reads a literal gap-band radius')
local SLOW = num('GetCurrentMovementSpeed%(%)%s*<%s*(%d+)',
    'the helper no longer carries a literal movement-speed fall-through')
assert(ONFACE < BAND, 'the on-face radius must sit strictly inside the band '
    .. 'radius, else there is no band to measure')

out:write(('C src_onface %d\n'):format(ONFACE))
out:write(('C src_band %d\n'):format(BAND))
out:write(('C src_slow %d\n'):format(SLOW))

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
                local J, bot, heroes = rf.load(path, u.name)
                J.IsSoakCandidate = function() return false end

                -- The dumper captures no velocities, so extrapolation is
                -- DECLARED stationary here.  That is the CONSERVATIVE
                -- declaration for the reach census below: it switches off
                -- CanEnemyInterruptTpChannel's "closing the gap" leg, so any
                -- TRUE it still returns comes from the reach leg alone.
                for _, h in pairs(heroes) do
                    local sp = rawget(h, '__spec')
                    if sp ~= nil then sp.GetExtrapolatedLocation = h:GetLocation() end
                end

                local tOnFace = J.GetNearbyHeroes(bot, ONFACE, true, BOT_MODE_NONE) or {}
                local tBand = J.GetNearbyHeroes(bot, BAND, true, BOT_MODE_NONE) or {}

                -- both directions of every leg (backlog 0DIR)
                if #tOnFace > 0 then bump('onface') else bump('onface_clear') end
                if #tBand > 0 then bump('band_any') else bump('band_clear') end

                if #tOnFace == 0 and #tBand > 0 then
                    bump('gap')                       -- the uncovered band
                    if bot:GetCurrentMovementSpeed() < SLOW then bump('gap_slow')
                    else bump('gap_mobile') end
                    if bot:IsRooted() or bot:IsStunned()
                        or bot:IsHexed() or bot:IsNightmared()
                    then bump('gap_rooted') else bump('gap_free') end
                    -- The naive fix ("just run the 700 veto on retreat too")
                    -- measured on the same frames, with the mock's attack range.
                    if J.CanEnemyInterruptTpChannel(bot) then
                        bump('gap_core_true_mockrange')
                    else
                        bump('gap_core_false_mockrange')
                    end
                    if bot:GetAttackRange() == 150 then bump('gap_mock_range_150') end
                end
            end
        end
    end
end

for _, k in ipairs({ 'fixtures', 'live', 'onface', 'onface_clear', 'band_any',
    'band_clear', 'gap', 'gap_slow', 'gap_mobile', 'gap_rooted', 'gap_free',
    'gap_core_true_mockrange', 'gap_core_false_mockrange', 'gap_mock_range_150' })
do
    out:write(('C %s %d\n'):format(k, c[k]))
end
out:write('DONE\n')
