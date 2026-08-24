-- Cheap predicate-level census for the early-tower-fear clock legs in
-- mode_farm_generic.X.ShouldRun ("前期谨慎冲塔" block).  Run as a SUBPROCESS
-- (backlog 0q): it rebuilds jmz_func once per hero-frame.  The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHAT IT MEASURES.  mode_farm_generic carries a SECOND copy of the same
-- "前期谨慎冲塔" block that mode_retreat_generic has (the one [towerfear]
-- narrowed).  The farm copy is not a duplicate: it has TWO crude clauses
-- instead of one, and the whole thing is written twice, back to back:
--
--   -- BLOCK 1 (rings 1200 / mid 1100 + 980, latch 2s)
--   if botLevel <= 10 and DotaTime() > 0 and (#enemies > 0 or hp < 700) then
--       if ( botLevel <= 2 or DotaTime() < 2*60 ) and nLongEnemyTowers[1] then return 2 end
--       if ( botLevel <= 4 or DotaTime() < 3*60 ) and nEnemyTowers[1]     then return 2 end
--       if botLevel <= 9 and nEnemyTowers[1] ... GetAttackTarget() == bot
--           and #allies <= 1                                             then return 2 end
--   end
--   -- BLOCK 2 (rings 999 / mid 988 + 966, latch 1s), same three clauses
--
-- Two independent questions, so two independent counter families:
--
--  (1) THE LEVER.  Each crude clause's disjunction is ONE question ("am I still
--      an early-game-fragile hero") written twice.  Turbo doubles xp, so the
--      clock leg goes on firing for exactly the levels the level leg has
--      already released.  Counted per clause: how often the clause is asked,
--      how often it fires, and how much of that firing the CLOCK LEG HOLDS
--      ALONE (the only frames a halving can move), split by whether the
--      calibrated clause below would have caught the frame anyway.
--
--  (2) THE REACHABILITY OF BLOCK 2.  Every ring in block 2 is a SUBSET of the
--      matching ring in block 1 (999 < 1200, 988 < 1100, 966 < 980, and off
--      mid both near clauses read the same outer 898 local), and the level and
--      clock legs are byte-identical.  So a frame that fires a block-2 clause
--      fired the matching block-1 clause first and already returned -- except
--      when block 1's outer gate is closed, and the ONLY difference between
--      the two outer gates is block 1's extra `DotaTime() > 0`.  Counted here
--      rather than argued: `b2_live_*` is the population where block 2 decides
--      anything at all.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                          a counter bucket
--   ROW <fixture> <hero> <t> <level> <lane> <clause> <tag> <calib> <allies> <dist>
--       one live hero frame that reaches a crude clause in block 1
--   DONE
-- Absence of the final DONE line is treated by the caller as a failed run.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

-- Every constant is READ FROM THE SHIPPED SOURCE, never restated here
-- (backlog 0SRC/0CST: a census that copies the constant it measures reports the
-- old world unmoved after the constant moves).
local SRC = (function()
    local fh = assert(io.open('bots/mode_farm_generic.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end)()

-- ShouldRun's OWN body: the same `local nEnemyTowers = bot:GetNearbyTowers(N)`
-- line exists earlier in the file with a different N, and a whole-file `match`
-- hands back that one (backlog 0SRC, third 实证).
local SHOULDRUN = (function()
    local at = assert(SRC:find('function X.ShouldRun(bot)', 1, true),
        'X.ShouldRun moved or was renamed')
    return SRC:sub(at, at + 9000)
end)()

local function num(v, msg)
    assert(v ~= nil, msg)
    return tonumber(v)
end

local BLOCK = (function()
    local at = assert(SHOULDRUN:find('前期谨慎冲塔', 1, true),
        'the 前期谨慎冲塔 block lost its comment anchor inside X.ShouldRun')
    -- The window must reach the SECOND copy's calibrated clause, or every
    -- extraction below silently measures a truncated block and the failure
    -- message names the wrong thing.  Self-witnessing (charter 0LN2).
    local block = SHOULDRUN:sub(at, at + 2600)
    local _, nCalib = block:gsub('GetAttackTarget%(%) == bot', '')
    assert(nCalib == 2, ('the source window from 前期谨慎冲塔 reaches %d '
        .. 'calibrated clause(s), not 2 -- widen it; the block may be intact')
        :format(nCalib))
    return block
end)()

-- The outer near ring is ShouldRun's own local; the two blocks only override it
-- on mid.
local NEAR_RING = num(SHOULDRUN:match('local nEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
    'ShouldRun no longer reads a literal near tower ring')
local HERO_RING = num(SHOULDRUN:match('local hEnemyHeroList%s*=%s*J%.GetEnemyList%(bot,(%d+)%)'),
    'ShouldRun no longer builds hEnemyHeroList over a literal radius')

-- Split the window into its two blocks at the second outer gate.
local B1, B2 = (function()
    local starts = {}
    for at in BLOCK:gmatch('()botLevel <= 10') do starts[#starts + 1] = at end
    assert(#starts == 2, ('expected 2 `botLevel <= 10` outer gates in the '
        .. 'window, found %d'):format(#starts))
    return BLOCK:sub(starts[1], starts[2] - 1), BLOCK:sub(starts[2])
end)()

local function legs(part, what)
    local outer_hp = num(part:match('bot:GetHealth%(%)%s*<%s*(%d+)'),
        what .. ': the outer gate no longer has a literal GetHealth() floor')
    local ring_long = num(part:match('local nLongEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
        what .. ': the block no longer opens with a literal long tower ring')
    -- The mid override must be read out of the MID BRANCH, not the block: the
    -- `local nLongEnemyTowers = ...` line above it matches the same pattern and
    -- a block-wide `match` hands back the off-mid ring instead (backlog 0SRC --
    -- this census tripped over it on its first run and reported 1200/999 as the
    -- mid rings, i.e. the override measured as if it did not exist).
    local mid = assert(part:match('LANE_MID(.-)\n%s*end'),
        what .. ': the mid override branch is gone or no longer ends with `end`')
    local ring_mid_long = num(mid:match('nLongEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
        what .. ': the mid override no longer re-reads a literal long ring')
    local ring_mid = num(mid:match('nEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
        what .. ': the mid override no longer re-reads a literal near ring')
    assert(ring_mid_long ~= ring_long, what .. ': the mid long ring equals the '
        .. 'off-mid one -- the extraction is reading the same line twice')
    -- Each crude clause reads its clock bound from a local (the gated variant
    -- reassigns it); before the gate lands the local is the literal itself.
    local lvl_long, clk_long = part:match('botLevel%s*<=%s*(%d+)%s*or%s*DotaTime%(%)%s*<%s*([^%)]-)%s*%)%s*\n%s*and nLongEnemyTowers')
    local lvl_near, clk_near = part:match('botLevel%s*<=%s*(%d+)%s*or%s*DotaTime%(%)%s*<%s*([^%)]-)%s*%)%s*\n%s*and nEnemyTowers')
    assert(lvl_long and lvl_near,
        what .. ': the two crude clauses no longer read '
        .. '"botLevel <= N or DotaTime() < X" over the long/near tower list')
    local function clock(expr, tag)
        -- either the literal `N * 60` still inlined in the clause, or the name
        -- of the local the gated variant reassigns.
        local n = expr:match('^(%d+)%s*%*%s*60$')
        if n ~= nil then return tonumber(n) * 60 end
        assert(expr:match('^[%w_]+$'), ('%s: the %s clock bound `%s` is neither '
            .. 'a literal `N * 60` nor a bare local name'):format(what, tag, expr))
        local d = part:match('local ' .. expr .. '%s*=%s*(%d+)%s*%*%s*60')
            or SHOULDRUN:match('local ' .. expr .. '%s*=%s*(%d+)%s*%*%s*60')
        assert(d ~= nil, ('%s: the %s clock bound is the local `%s`, and no '
            .. '`local %s = N * 60` default was found'):format(what, tag, expr, expr))
        return tonumber(d) * 60
    end
    local calib_level = num(part:match('botLevel%s*<=%s*(%d+)%s*\n%s*and nEnemyTowers'),
        what .. ': the calibrated clause no longer opens with a literal level bound')
    return {
        outer_hp = outer_hp, ring_long = ring_long,
        ring_mid_long = ring_mid_long, ring_mid = ring_mid,
        lvl_long = tonumber(lvl_long), clk_long = clock(clk_long, 'long'),
        lvl_near = tonumber(lvl_near), clk_near = clock(clk_near, 'near'),
        calib_level = calib_level,
        -- block 1 alone carries the pre-horn guard; block 2 does not.
        pre_horn = part:match('DotaTime%(%)%s*>%s*0') ~= nil,
    }
end

local L1, L2 = legs(B1, 'block1'), legs(B2, 'block2')
assert(L1.pre_horn, 'block 1 lost its `DotaTime() > 0` outer guard -- the '
    .. 'reachability arithmetic for block 2 below is about that guard')
assert(not L2.pre_horn, 'block 2 GREW a `DotaTime() > 0` guard -- it is now '
    .. 'dead in every direction; re-derive before trusting b2_live_*')

out:write(('C src_near_ring %d\n'):format(NEAR_RING))
out:write(('C src_hero_ring %d\n'):format(HERO_RING))
for tag, L in pairs({ b1 = L1, b2 = L2 }) do
    out:write(('C src_%s_outer_hp %d\n'):format(tag, L.outer_hp))
    out:write(('C src_%s_ring_long %d\n'):format(tag, L.ring_long))
    out:write(('C src_%s_ring_mid_long %d\n'):format(tag, L.ring_mid_long))
    out:write(('C src_%s_ring_mid %d\n'):format(tag, L.ring_mid))
    out:write(('C src_%s_lvl_long %d\n'):format(tag, L.lvl_long))
    out:write(('C src_%s_clk_long %d\n'):format(tag, L.clk_long))
    out:write(('C src_%s_lvl_near %d\n'):format(tag, L.lvl_near))
    out:write(('C src_%s_clk_near %d\n'):format(tag, L.clk_near))
    out:write(('C src_%s_calib_level %d\n'):format(tag, L.calib_level))
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
                local nLane = bot:GetAssignedLane()
                local bMid = (nLane == LANE_MID)
                if bMid then bump('lane_mid') else bump('lane_not_mid') end
                -- WORLD ASSERTION, both directions.  GetAssignedLane is not in
                -- the mock, so it falls through to the `^Get` default (0), while
                -- every unknown ALL_CAPS global resolves to a distinct id >=1001
                -- -- so `== LANE_*` is structurally false here, and every
                -- lane-specific branch in bots/ is unreachable in fixtures.
                -- Reported as a count, not as a comment, so the day the mock
                -- learns the method the number moves instead of the prose.
                if nLane == 0 then bump('lane_reads_mock_default') end
                if nLane == LANE_MID or nLane == LANE_TOP or nLane == LANE_BOT then
                    bump('lane_matches_some_lane_const')
                else
                    bump('lane_matches_no_lane_const')
                end

                -- both directions of every leg (backlog 0DIR)
                if t > 0 then bump('t_positive') else bump('t_nonpositive') end
                if lvl <= 10 then bump('outer_level_ok') else bump('outer_level_no') end

                -- Where a halving COULD bite, before any gate or ring is asked:
                -- the clock leg holds a frame alone exactly when the level leg
                -- has released it and the clock has not.  Counting this without
                -- the tower ring separates "the constant is already tight" from
                -- "the corpus has no tower frames there" -- two very different
                -- reasons for a zero, and only the first is about the code.
                if t < L1.clk_long then
                    bump('band_long_clock')
                    if lvl > L1.lvl_long then bump('band_long_clock_only') end
                end
                if t < L1.clk_near then
                    bump('band_near_clock')
                    if lvl > L1.lvl_near then bump('band_near_clock_only') end
                end

                local tEnemyHeroes = J.GetEnemyList(bot, HERO_RING) or {}
                local tAllyHeroes  = J.GetAllyList(bot, HERO_RING) or {}

                local function rings(L)
                    local long = bot:GetNearbyTowers(bMid and L.ring_mid_long or L.ring_long, true) or {}
                    local near = bot:GetNearbyTowers(bMid and L.ring_mid or NEAR_RING, true) or {}
                    return long, near
                end

                local function outer(L)
                    return lvl <= 10 and (not L.pre_horn or t > 0)
                        and (#tEnemyHeroes > 0 or bot:GetHealth() < L.outer_hp)
                end

                local b1Outer, b2Outer = outer(L1), outer(L2)
                if b1Outer then bump('b1_outer_gate') else bump('b1_outer_shut') end
                if b2Outer then bump('b2_outer_gate') else bump('b2_outer_shut') end
                -- The ONLY population where block 2 can decide anything: its
                -- own gate open while block 1's is shut.
                if b2Outer and not b1Outer then bump('b2_live_outer') end

                local lg1, nr1 = rings(L1)
                if #lg1 > 0 then bump('b1_tower_long') else bump('b1_tower_long_absent') end
                if #nr1 > 0 then bump('b1_tower_near') else bump('b1_tower_near_absent') end
                local lg2, nr2 = rings(L2)
                if #lg2 > 0 then bump('b2_tower_long') end
                if #nr2 > 0 then bump('b2_tower_near') end
                -- Subset arithmetic, measured not asserted: a block-2 ring hit
                -- that block 1's matching ring missed would break the whole
                -- reachability claim.
                if #lg2 > 0 and #lg1 == 0 then bump('b2_long_outside_b1') end
                if #nr2 > 0 and #nr1 == 0 then bump('b2_near_outside_b1') end

                local function clause(L, name, lvlBound, clkBound, towers, allowed)
                    if not allowed or #towers == 0 then return false end
                    bump(name .. '_asked')
                    local bLvl, bClk = lvl <= lvlBound, t < clkBound
                    if bLvl then bump(name .. '_level_leg') end
                    if bClk then bump(name .. '_clock_leg') end
                    if not (bLvl or bClk) then bump(name .. '_nofire'); return false end
                    bump(name .. '_fires')
                    if bLvl then
                        bump(name .. '_level_holds')
                    else
                        bump(name .. '_clock_only')
                        if t >= clkBound / 2 then bump(name .. '_clock_only_released_by_half') end
                    end
                    return true, bLvl
                end

                local hT1 = nr1[1]
                local bCalib1 = hT1 ~= nil and lvl <= L1.calib_level
                    and hT1:CanBeSeen() and hT1:GetAttackTarget() == bot
                    and #tAllyHeroes <= 1
                if bCalib1 then bump('b1_calibrated_true') end

                local fired, byLevel = clause(L1, 'b1_long', L1.lvl_long, L1.clk_long, lg1, b1Outer)
                if fired then
                    out:write(('ROW %s %s %.1f %d %s long %s %s %d %.0f\n'):format(
                        path:match('([^/]+)%.lua$'), u.name, t, lvl,
                        bMid and 'MID' or 'off-mid',
                        byLevel and 'LEVELLEG' or 'CLOCKONLY',
                        bCalib1 and 'CALIB' or 'crude-only', #tAllyHeroes,
                        GetUnitToUnitDistance(bot, lg1[1])))
                else
                    local f2, b2 = clause(L1, 'b1_near', L1.lvl_near, L1.clk_near, nr1, b1Outer)
                    if f2 then
                        out:write(('ROW %s %s %.1f %d %s near %s %s %d %.0f\n'):format(
                            path:match('([^/]+)%.lua$'), u.name, t, lvl,
                            bMid and 'MID' or 'off-mid',
                            b2 and 'LEVELLEG' or 'CLOCKONLY',
                            bCalib1 and 'CALIB' or 'crude-only', #tAllyHeroes,
                            GetUnitToUnitDistance(bot, nr1[1])))
                    elseif b1Outer and #nr1 > 0 and bCalib1 then
                        bump('b1_calibrated_catches')
                    end
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
