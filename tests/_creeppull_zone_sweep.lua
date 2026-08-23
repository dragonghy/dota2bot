-- Heavy corpus sweep for tests/test_creeppull_zone_clause.lua, run as a
-- SUBPROCESS (backlog 0q: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame -- ~960 loads -- must not run on run_tests.lua's long-lived heap).
-- The leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IT MEASURES, and the honest bound stated first: the END-TO-END predicate
-- J.ShouldCreepPullLane is STRUCTURALLY UNREACHABLE on this corpus -- it
-- requires `bot:GetNearbyLaneCreeps(900, true)` to be non-empty and the fixture
-- generator writes NO creeps at all (tests/mock/replay_fixture.lua declares that
-- supply gap for UNIT_LIST_ALL). So this sweep does NOT pretend to census the
-- function; it censuses the ONE disjunct that decides its DISADVANTAGED gate and
-- that IS readable on real frames -- J.IsLaneZonedByEnemy -- plus both counts of
-- the sibling disjunct so the reader can see which of the two is carrying the
-- gate.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                     a counter bucket
--   ZROW <fixture> <hero> <nEnemy> <dmg2> <dmg6>
--       one live hero frame where the OLD zoned disjunct holds AND the fixture
--       can answer the damage question at all (v2), i.e. the frames where the
--       new clause can be ASKED rather than merely answered false.
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

-- Every constant below is READ FROM THE SHIPPED SOURCE, never restated here
-- (M13 / backlog 0SRC: a census that copies the constant it measures reports the
-- old world unmoved after the constant moves, and `match` over a whole file
-- hands back the FIRST occurrence, which is usually some other function's).
local SRC = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end)()

local function fn_body(name)
    local at = assert(SRC:find('function J.' .. name .. '(', 1, true),
        'J.' .. name .. ' moved or was renamed')
    local stop = SRC:find('\nend\n', at, true)
    return SRC:sub(at, stop or (at + 6000))
end

local ZONE_BODY = fn_body('IsLaneZonedByEnemy')
local PULL_BODY = fn_body('ShouldCreepPullLane')

-- the zoning radius the disjunct compares strength over, and the harass
-- lookback the gated clause adds -- both out of the helper's own body.
local function num(v, msg)
    assert(v ~= nil, msg)
    return tonumber(v)
end

local ZONE_RADIUS = num(ZONE_BODY:match('J%.WeAreStronger%(%s*bot,%s*(%d+)%s*%)'),
    'the zoned disjunct no longer compares strength over a literal radius')
local HARASS = num(ZONE_BODY:match('WasRecentlyDamagedByAnyHero%(%s*([%d%.]+)%s*%)'),
    'the gated harass clause is no longer a literal WasRecentlyDamagedByAnyHero')
-- the enemy-hero scan radius and the SAFE-1b exclusion, out of the caller.
local NEAR = num(PULL_BODY:match('J%.GetNearbyHeroes%(%s*bot,%s*(%d+),%s*true'),
    'the caller no longer scans enemy heroes over a literal radius')
local SAFE1B = num(PULL_BODY:match(
    'if bot:WasRecentlyDamagedByAnyHero%(%s*([%d%.]+)%s*%) then return nil end'),
    'SAFE-1b is no longer a literal WasRecentlyDamagedByAnyHero bail')

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

local function hero_damage_within(u, window, rwin)
    local n = window
    if rwin ~= nil and n > rwin then n = rwin end
    local total = 0
    for _, d in ipairs(u.recent_damage or {}) do
        if d.dt <= n and d.kind == 'hero' then total = total + (tonumber(d.value) or 0) end
    end
    return total
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local v2 = (fx.recent_window ~= nil)
        -- The lookback the gated clause wants must be inside what the fixture
        -- actually saw, or the loader clamps it and the census silently
        -- measures a shorter window than the source asks for.
        if v2 and HARASS > fx.recent_window then bump('CLAMPED_window') end
        for _, u in ipairs(fx.units) do
            if u.alive then
                bump('live')
                if v2 then bump('live_v2') else bump('live_v1') end
                local J, bot = rf.load(path, u.name)
                J.IsSoakCandidate = function() return false end

                -- ---- the prefix of J.ShouldCreepPullLane, clause by clause.
                -- Reported so the reader can see that the end-to-end predicate
                -- is not merely rare here, it is unreachable, and WHERE.
                if J.IsInLaningPhase() then bump('laning') end
                if J.IsCore(bot) then bump('core') end
                if DotaTime() <= 6 * 60 then bump('t_le360') end
                if J.GetHP(bot) >= 0.5 then bump('hp_ok') end
                local tLaneCreeps = bot:GetNearbyLaneCreeps(900, true)
                if tLaneCreeps ~= nil and #tLaneCreeps > 0 then bump('lanecreeps') end

                -- ---- the two disjuncts of the DISADVANTAGED gate.
                -- (a) lane front. Both teams read the same mock constant, so
                -- this is UNREADABLE here, not false: counted in both
                -- directions so a future mock that answers honestly shows up as
                -- a moved number rather than as silence (backlog 0DIR).
                local nOur = GetLaneFrontAmount(GetTeam(), bot:GetAssignedLane(), false)
                local nEnemy = GetLaneFrontAmount(
                    (GetTeam() == TEAM_RADIANT) and TEAM_DIRE or TEAM_RADIANT,
                    bot:GetAssignedLane(), false)
                if nOur ~= nil and nEnemy ~= nil then
                    bump('front_readable')
                    if nEnemy > nOur then bump('front_pushed_to_us')
                    else bump('front_not_pushed') end
                    if nOur == nEnemy then bump('front_tied') end
                end

                -- (b) the zoned disjunct, unarmed then armed. The helper is
                -- pure and side-effect free, so the same loaded world is
                -- re-asked with the gate flipped rather than reloaded.
                local tEnemies = J.GetNearbyHeroes(bot, NEAR, true, BOT_MODE_NONE) or {}
                if #tEnemies >= 1 then bump('enemy_near') end
                if #tEnemies > 1 then bump('enemy_multi') end
                if J.WeAreStronger(bot, ZONE_RADIUS) then bump('stronger') end
                local dmg_harass = bot:WasRecentlyDamagedByAnyHero(HARASS)
                local dmg_safe1b = bot:WasRecentlyDamagedByAnyHero(SAFE1B)
                if dmg_harass then bump('hero_dmg_harass') end
                if dmg_safe1b then bump('hero_dmg_safe1b') end
                -- SAFE-1b sits BEFORE the disjunct and bails on it, so the
                -- window the armed clause can actually admit is the ring
                -- between the two lookbacks, not the whole harass window.
                if dmg_harass and not dmg_safe1b then bump('harass_ring') end

                local zoned_off = J.IsLaneZonedByEnemy(bot, tEnemies)
                J.IsSoakCandidate = function(id) return id == 'pullzone' end
                local zoned_on = J.IsLaneZonedByEnemy(bot, tEnemies)
                J.IsSoakCandidate = function() return false end

                if zoned_off then
                    bump('zoned_off')
                    if v2 then bump('zoned_off_v2') else bump('zoned_off_v1') end
                end
                if zoned_on then bump('zoned_on') end
                if zoned_off and not zoned_on then
                    bump('narrowed')
                    -- v1 fixtures carry no damage history at all, so the clause
                    -- answers false there for the WRONG reason (unaskable, not
                    -- calm). Split, never pooled.
                    if v2 then bump('narrowed_askable') else bump('narrowed_unaskable') end
                end
                -- The clause is append-only and can only subtract, so a frame
                -- it TURNS ON is structurally impossible. Asserted, not assumed.
                if zoned_on and not zoned_off then bump('IMPOSSIBLE_widened') end

                -- The frames where the question can be asked at all: the
                -- domain any (a)-evidence claim has to be quoted over.
                if zoned_off and v2 then
                    out:write(string.format('ZROW %s %s %d %d %d\n',
                        path, u.name, #tEnemies,
                        hero_damage_within(u, SAFE1B, fx.recent_window),
                        hero_damage_within(u, HARASS, fx.recent_window)))
                end
            end
        end
    end
end

for _, k in ipairs({
    'fixtures', 'live', 'live_v1', 'live_v2',
    'laning', 'core', 't_le360', 'hp_ok', 'lanecreeps',
    'front_readable', 'front_pushed_to_us', 'front_not_pushed', 'front_tied',
    'enemy_near', 'enemy_multi', 'stronger',
    'hero_dmg_harass', 'hero_dmg_safe1b', 'harass_ring',
    'zoned_off', 'zoned_off_v1', 'zoned_off_v2', 'zoned_on',
    'narrowed', 'narrowed_askable', 'narrowed_unaskable',
    'IMPOSSIBLE_widened', 'CLAMPED_window',
}) do
    out:write(string.format('C %s %d\n', k, c[k]))
end
out:write(string.format('C radius %d\n', ZONE_RADIUS))
out:write(string.format('C near %d\n', NEAR))
out:write(string.format('C harass_x10 %d\n', math.floor(HARASS * 10 + 0.5)))
out:write(string.format('C safe1b_x10 %d\n', math.floor(SAFE1B * 10 + 0.5)))
out:write('DONE\n')
