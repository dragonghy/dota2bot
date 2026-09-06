-- Cheap predicate-level census for the early-tower-fear clock leg in
-- mode_retreat_generic.X.ShouldRun ("前期谨慎冲塔" block).  Run as a SUBPROCESS
-- (backlog 0q): it rebuilds jmz_func once per hero-frame.  The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHAT IT MEASURES.  The block is
--
--     if botLevel <= 10 and DotaTime() > 0
--     and (#hEnemyHeroList > 0 or bot:GetHealth() < 800) then
--         ... (mid re-reads the tower rings at 1100/980)
--         if ( botLevel <= 5 or DotaTime() < 5 * 60 ) and nEnemyTowers[1] ~= nil
--             then return 2 end                              -- CRUDE clause
--         if botLevel <= 9 and nEnemyTowers[1] ~= nil
--             and nEnemyTowers[1]:CanBeSeen()
--             and nEnemyTowers[1]:GetAttackTarget() == bot
--             and #hAllyHeroList <= 1 then return 2 end       -- CALIBRATED clause
--     end
--
-- The two legs of the crude clause's disjunction are two encodings of ONE
-- question ("am I still an early-game-fragile hero").  In normal mode they
-- nearly coincide (level ~5 at 5:00); turbo doubles xp, so the clock leg keeps
-- firing for levels 6-10 that the level leg has already released.  This sweep
-- counts, on real frames, how much of the crude clause's domain is carried by
-- the clock leg ALONE, and how much of that the calibrated clause below would
-- catch anyway (where a narrowing is a no-op, not a behaviour change).
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                          a counter bucket
--   ROW <fixture> <hero> <t> <level> <towerDist> <calibrated> <allies>
--       one live hero frame in the clock-leg-only band
--   DONE
-- Absence of the final DONE line is treated by the caller as a failed run.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

-- Every constant is READ FROM THE SHIPPED SOURCE, never restated here
-- (backlog 0SRC/0CST: a census that copies the constant it measures reports the
-- old world unmoved after the constant moves).
local SRC = (function()
    local fh = assert(io.open('bots/mode_retreat_generic.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end)()

local BLOCK = (function()
    local at = assert(SRC:find('前期谨慎冲塔', 1, true),
        'the 前期谨慎冲塔 block lost its comment anchor')
    -- The window must reach the SECOND (calibrated) clause, or every extraction
    -- below silently measures a truncated block and the failure message names
    -- the wrong thing ("the clause is gone" when it is merely past the window).
    -- Self-witnessing, as the charter's 0LN2 note demands: fail with the truth.
    --
    -- It used to be a BYTE window (3400, widened to 4800 on 2026-08-25 when the
    -- GH #178 comment rewrite added ~1.2 kB of prose). A byte window measures
    -- PROSE, so every comment written inside the block is a tripwire on a file
    -- that has nothing to do with the comment: the 2026-09-06 `towerring`
    -- rationale (GH #558) blew 4800 the same way. Replaced by an END ANCHOR --
    -- the calibrated clause itself, which is the very thing the old assert was
    -- checking for. The block now ends where it is supposed to end, and prose
    -- inside it costs nothing. A missing end anchor is now what it always
    -- should have been: "the calibrated clause is gone", not "widen me".
    local to = SRC:find('nEnemyTowers%[1%]:GetAttackTarget%(%) == bot', at)
    assert(to ~= nil,
        'no calibrated clause (`nEnemyTowers[1]:GetAttackTarget() == bot`) '
        .. 'after the 前期谨慎冲塔 anchor -- the block was cut, not truncated')
    -- +400 so the trailing `#hAllyHeroList <= 1 then return 2 end` tail of the
    -- calibrated clause is inside the block, not just its first line.
    return SRC:sub(at, to + 400)
end)()

local function num(v, msg)
    assert(v ~= nil, msg)
    return tonumber(v)
end

local OUTER_LEVEL = num(BLOCK:match('botLevel%s*<=%s*(%d+)%s*and%s*DotaTime%(%)%s*>%s*0'),
    'the outer gate is no longer "botLevel <= N and DotaTime() > 0"')
local OUTER_HP    = num(BLOCK:match('bot:GetHealth%(%)%s*<%s*(%d+)'),
    'the outer gate no longer has a literal GetHealth() floor')
local RING_LONG   = num(BLOCK:match('GetNearbyTowers%((%d+),%s*true%)'),
    'the block no longer opens with a literal long tower ring')
local RING_MID_L  = num(BLOCK:match('nLongEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
    'the mid override no longer re-reads a literal long ring')
local RING_MID    = num(BLOCK:match('nEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
    'the mid override no longer re-reads a literal near ring')
local CRUDE_LEVEL = num(BLOCK:match('botLevel%s*<=%s*(%d+)%s*or%s*DotaTime%(%)'),
    'the crude clause no longer reads "botLevel <= N or DotaTime() < ..."')
-- The shipped clock leg is the DEFAULT of the local the clause reads, not a
-- literal in the clause itself (the gated variant reassigns it).
local CRUDE_CLOCK = num(BLOCK:match('local nFearClock%s*=%s*(%d+)%s*%*%s*60'),
    'the crude clause no longer reads a nFearClock local with a literal N * 60 default') * 60
assert(BLOCK:match('or%s*DotaTime%(%)%s*<%s*nFearClock'),
    'the crude clause no longer compares DotaTime() against nFearClock with a '
    .. 'STRICT < (a `<=` fails here too, and it moves the boundary by one frame)')
local CALIB_LEVEL = num(BLOCK:match('botLevel%s*<=%s*(%d+)%s*\n%s*and%s*nEnemyTowers'),
    'the calibrated clause no longer opens with a literal level bound')

-- The near ring outside the mid override comes from ShouldRun's own local, not
-- from the block.  It must be read out of ShouldRun's OWN body: the same
-- `local nEnemyTowers = bot:GetNearbyTowers(N, true)` line exists earlier in
-- the file inside X.RetreatWhenTowerTargetedDesire with a different N, and a
-- whole-file `match` hands back that one (backlog 0SRC, second实证 in this file).
local SHOULDRUN = (function()
    local at = assert(SRC:find('function X.ShouldRun()', 1, true),
        'X.ShouldRun moved or was renamed')
    return SRC:sub(at, at + 6000)
end)()
local NEAR_RING = num(SHOULDRUN:match('local nEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
    'ShouldRun no longer reads a literal near tower ring')
-- and the enemy/ally hero lists it counts.
local HERO_RING = num(SHOULDRUN:match('local hEnemyHeroList%s*=%s*J%.GetEnemyList%(bot,(%d+)%)'),
    'ShouldRun no longer builds hEnemyHeroList over a literal radius')

out:write(('C src_outer_level %d\n'):format(OUTER_LEVEL))
out:write(('C src_outer_hp %d\n'):format(OUTER_HP))
out:write(('C src_ring_long %d\n'):format(RING_LONG))
out:write(('C src_ring_mid_long %d\n'):format(RING_MID_L))
out:write(('C src_ring_mid %d\n'):format(RING_MID))
out:write(('C src_near_ring %d\n'):format(NEAR_RING))
out:write(('C src_hero_ring %d\n'):format(HERO_RING))
out:write(('C src_crude_level %d\n'):format(CRUDE_LEVEL))
out:write(('C src_crude_clock %d\n'):format(CRUDE_CLOCK))
out:write(('C src_calib_level %d\n'):format(CALIB_LEVEL))

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
        if fx.buildings ~= nil and #fx.buildings > 0 then bump('fixtures_with_buildings') end
        for _, u in ipairs(fx.units) do
            if u.alive then
                bump('live')
                local J, bot = rf.load(path, u.name)
                J.IsSoakCandidate = function() return false end

                local t = DotaTime()
                local lvl = bot:GetLevel()
                if fx.buildings ~= nil and #fx.buildings > 0 then bump('live_with_buildings') end

                -- both directions of every leg (backlog 0DIR)
                if t > 0 then bump('t_positive') else bump('t_nonpositive') end
                if lvl <= OUTER_LEVEL then bump('outer_level_ok') else bump('outer_level_no') end
                if t < CRUDE_CLOCK then bump('clock_leg_true') else bump('clock_leg_false') end
                if lvl <= CRUDE_LEVEL then bump('level_leg_true') else bump('level_leg_false') end
                if lvl > CRUDE_LEVEL and t < CRUDE_CLOCK then bump('clock_only_band') end
                -- The window the halving actually releases, and the turbo fact
                -- that motivates it: how mature is a hero while the clock leg
                -- still calls it fragile?
                if t >= CRUDE_CLOCK / 2 and t < CRUDE_CLOCK then
                    bump('band_half_to_full')
                    if lvl > CRUDE_LEVEL then bump('band_half_to_full_lvl6plus') end
                    bump('band_level_sum', lvl)
                end
                if t < CRUDE_CLOCK / 2 then
                    bump('band_below_half')
                    if lvl > CRUDE_LEVEL then bump('band_below_half_lvl6plus') end
                end

                local tEnemyHeroes = J.GetEnemyList(bot, HERO_RING) or {}
                local tAllyHeroes  = J.GetAllyList(bot, HERO_RING) or {}
                local bOuter = lvl <= OUTER_LEVEL and t > 0
                    and (#tEnemyHeroes > 0 or bot:GetHealth() < OUTER_HP)
                if bOuter then bump('outer_gate') end

                local bMid = (bot:GetAssignedLane() == LANE_MID)
                local nNear = bMid and RING_MID or NEAR_RING
                local tTowers = bot:GetNearbyTowers(nNear, true) or {}
                if #tTowers > 0 then bump('tower_in_ring') else bump('tower_absent') end

                if bOuter and #tTowers > 0 then
                    bump('crude_reachable')            -- the clause is asked
                    local bCrude = (lvl <= CRUDE_LEVEL or t < CRUDE_CLOCK)
                    if bCrude then bump('crude_fires') end
                    local hT = tTowers[1]
                    local bCalib = lvl <= CALIB_LEVEL
                        and hT:CanBeSeen()
                        and hT:GetAttackTarget() == bot
                        and #tAllyHeroes <= 1
                    local tag
                    if not bCrude then tag = 'NOFIRE'
                    elseif lvl <= CRUDE_LEVEL then
                        -- the level leg holds it; halving the clock leg is a
                        -- no-op here, which is what makes these the controls
                        bump('level_leg_holds')
                        tag = (t < CRUDE_CLOCK / 2) and 'LEVELLEG_early' or 'LEVELLEG'
                    else
                        -- the clock leg is the ONLY leg holding this frame
                        bump('clock_only_fires')
                        if bCalib then bump('clock_only_but_calibrated') end
                        tag = 'CLOCKONLY'
                    end
                    out:write(('ROW %s %s %.1f %d %.0f %s %s %d\n'):format(
                        path:match('([^/]+)%.lua$'), u.name, t, lvl,
                        GetUnitToUnitDistance(bot, hT), tag,
                        bCalib and 'CALIB' or 'crude-only', #tAllyHeroes))
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(('C %s %d\n'):format(k, c[k])) end
out:write('DONE\n')
