-- Corpus sweep for [pipetower]: the "protect the team" branch of
-- ability_item_usage_generic.lua's item_pipe desire adds a tower count to OUR
-- side of a strength comparison, and the list it adds was fetched on the
-- ENEMY side.
--
--   local nNearbyAllyTowers = bot:GetNearbyTowers( 1200, true )   -- :4068
--   if ( #nNearbyAllyHeroes >= 2 and #nNearbyEnemyHeroes >= 2 )
--     or ( #nNearbyEnemyHeroes >= 2 and #nNearbyAllyHeroes + #nNearbyAllyTowers >= 2 )
--
-- `bEnemies` is relative to the ANCHOR (tests/test_ring_subject_census.py §2),
-- the anchor is `bot`, so `true` is the ENEMY's towers.  Standing under a tower
-- that shoots at us therefore reads as backup, and standing under our own
-- reads as nothing.
--
-- ⛔ RUN BY HAND, not from the suite: it loads every fixture once per hero
-- (~1039 loads) and tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0.  Same reason tests/_roamring_sweep.lua sits
-- outside the suite.
--
--   lua5.1 tests/_pipetower_sweep.lua      (counters on stderr, DONE last)
--
-- ⛔ NOTHING IS ARMED HERE.  Both readings are rebuilt from the same getters
-- the shipped site calls, so the sweep cannot race soak_side.lua on disk
-- (GH #848/#856).
--
-- TWO UNITS OF COUNT, and the difference is the point (0NEXT42 §three):
--   live_*   = the LIVE domain -- subject frames where the subject actually
--              HOLDS a pipe, i.e. frames on which the shipped branch can run.
--   shape_*  = the PREDICATE's domain -- every subject frame, pipe or not.
--              A ceiling for "what this branch would do if the corpus reached
--              the game minute a pipe exists in", NOT a fire rate.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local ALLY_RING, ENEMY_RING, TOWER_RING = 1200, 1600, 1200

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local t = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then t[#t + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(t)
    return t
end

local function has_pipe(hUnit)
    for i = 0, 8 do
        local it = hUnit:GetItemInSlot(i)
        if it ~= nil and it.GetName ~= nil and it:GetName() == 'item_pipe' then
            return true
        end
    end
    return false
end

local c = { fixtures = 0, live = 0, towers_seen = 0, pipes = 0,
            live_reached = 0, live_up = 0, live_down = 0,
            shape_reached = 0, shape_etower = 0, shape_atower = 0,
            shape_up = 0, shape_down = 0, shape_decides = 0 }
local witnesses = {}
local seen_fixture = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        c.fixtures = c.fixtures + 1
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                GAMEMODE_TURBO = nil                   -- luacheck: ignore
                local ok, J, bot = pcall(rf.load, path, u.name)
                GAMEMODE_TURBO = 23                    -- luacheck: ignore
                GetGameMode = function() return 23 end -- luacheck: ignore
                if ok and bot ~= nil then
                    c.live = c.live + 1
                    local bPipe = has_pipe(bot)
                    if bPipe then c.pipes = c.pipes + 1 end

                    local nAlly  = #(J.GetNearbyHeroes(bot, ALLY_RING, false, BOT_MODE_NONE) or {})
                    local nEnemy = #(J.GetNearbyHeroes(bot, ENEMY_RING, true, BOT_MODE_NONE) or {})
                    local tEnemyTowers = bot:GetNearbyTowers(TOWER_RING, true) or {}
                    local tOwnTowers   = bot:GetNearbyTowers(TOWER_RING, false) or {}
                    local nE, nO = #tEnemyTowers, #tOwnTowers
                    if nE > 0 or nO > 0 then c.towers_seen = c.towers_seen + 1 end

                    local shipped = (nAlly >= 2 and nEnemy >= 2)
                                    or (nEnemy >= 2 and nAlly + nE >= 2)
                    local armed   = (nAlly >= 2 and nEnemy >= 2)
                                    or (nEnemy >= 2 and nAlly + nO >= 2)

                    -- SHAPE: every subject frame, whether or not a pipe exists.
                    c.shape_reached = c.shape_reached + 1
                    if nE > 0 then c.shape_etower = c.shape_etower + 1 end
                    if nO > 0 then c.shape_atower = c.shape_atower + 1 end
                    -- the tower term DECIDES only when the ally half is short
                    if nEnemy >= 2 and nAlly <= 1 then
                        c.shape_decides = c.shape_decides + 1
                    end
                    if armed and not shipped then c.shape_up = c.shape_up + 1 end
                    if shipped and not armed then c.shape_down = c.shape_down + 1 end

                    -- LIVE: only frames whose subject carries the item.
                    if bPipe then
                        c.live_reached = c.live_reached + 1
                        if armed ~= shipped then
                            if armed then c.live_up = c.live_up + 1
                            else c.live_down = c.live_down + 1 end
                        end
                    end

                    if armed ~= shipped then
                        witnesses[#witnesses + 1] = string.format(
                            '%s %s  %s  t=%.1f  pipe=%s ally=%d enemy=%d etower=%d atower=%d  shipped=%s armed=%s',
                            armed and 'UP  ' or 'DOWN', path:gsub('tests/fixtures/', ''),
                            u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                            tostring(bPipe), nAlly, nEnemy, nE, nO,
                            tostring(shipped), tostring(armed))
                        seen_fixture[path] = true
                    end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

local nfx = 0
for _ in pairs(seen_fixture) do nfx = nfx + 1 end

for _, k in ipairs({ 'fixtures', 'live', 'towers_seen', 'pipes',
                     'live_reached', 'live_up', 'live_down',
                     'shape_reached', 'shape_etower', 'shape_atower',
                     'shape_decides', 'shape_up', 'shape_down' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
out:write('P fixtures_with_a_change ', tostring(nfx), '\n')
for _, w in ipairs(witnesses) do out:write('W ', w, '\n') end
out:write('DONE\n')
