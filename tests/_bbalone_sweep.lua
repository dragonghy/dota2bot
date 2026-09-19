-- Corpus sweep for [bbalone]: buyback path 1 compares a TABLE with a number.
--
--   -- bots/ability_item_usage_generic.lua, X.ConsiderBuyback
--   local nEnemyUnitsAroundAncient = J.GetEnemiesAroundLoc( ancientLoc, 1500 )  -- a NUMBER
--   local nAllyUnitsAroundAncient  = J.GetAlliesNearLoc(   ancientLoc, 1500 )  -- a TABLE
--   if nEnemyUnitsAroundAncient > 1 and nAllyUnitsAroundAncient == 0 ...       -- <= THIS
--
-- `{} == 0` is false in Lua 5.1 on every frame, silently (equality across
-- types is not an error; ORDER comparison is -- which is why the sibling term
-- one operator away would have crashed on day one).
--
-- ⛔ WHAT THIS SWEEP PRICES, DECLARED FIRST, AND IT IS A TERM, NOT A BRANCH.
-- The enclosing branch needs the bot DEAD with a buyback, level > 15, and
-- J.IsAncientBadlyHurt -- none of which a live-hero frame carries, and the
-- last of which is ITSELF constant-false in the shipped tree (soak candidate
-- 'bbancient'). So the branch's live domain on this corpus is ZERO and is
-- registered as such; what is priced here is the TERM's own answer on real
-- frames, plus the sibling enemy-weight term it is ANDed with.
--
-- ⛔ AND THE POPULATION IS GUARDED, not assumed. tests/mock/replay_fixture.lua
-- only overrides GetAncient when the fixture's own unit table carries one
-- (:1289); on an older fixture that carries no buildings the BARE mock answers
-- with a 4500-hp stand-in at the map ORIGIN, and a 1500 ring around the map
-- origin is a different question than a 1500 ring around our base. Frames
-- whose fixture has no ancient for the subject's team are REFUSED and counted
-- separately (`refused_no_ancient`) rather than being read in the river.
--
-- ⛔ RUN BY HAND, not from the suite: it loads every fixture once per hero and
-- tools/agent/lua_gate.py kills an unmeasured new test at
-- hook_timeout_seconds = 20.0. Same reason tests/_smokescan_sweep.lua and
-- tests/_smokeself_sweep.lua sit outside the suite.
--
--   lua5.1 tests/_bbalone_sweep.lua        (counters on stderr, DONE last)
--
-- ⛔ NOTHING IS ARMED HERE. Both legs are rebuilt from the same getters the
-- shipped site calls, so the sweep cannot race soak_side.lua on disk.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local out = io.stderr

local R = 1500   -- the shipped radius at the call site, mirrored exactly

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

-- Does THIS fixture carry an ancient for the subject's team? Read off the
-- fixture table itself, the same way the loader decides whether to override
-- GetAncient -- not off GetAncient's answer, which is never nil.
local function fixture_ancient_teams(fx)
    local teams = {}
    for _, b in ipairs(fx.buildings or {}) do
        if b.name == 'ancient' and b.team ~= nil and b.alive then teams[b.team] = true end
    end
    return teams
end

local c = { fixtures = 0, fixtures_with_ancient = 0, live = 0,
            refused_no_ancient = 0,
            shipped_true = 0,   -- `{} == 0` -- must print 0, it is the defect
            armed_true  = 0,    -- #allies == 0: nobody alive defending the ancient
            armed_false = 0,
            flip = 0,           -- armed true while shipped false = every armed_true
            pair = 0,           -- flip AND the sibling term (enemy weight > 1) also true
            outer_shipped = 0,  -- IsAncientBadlyHurt as shipped: hp(abs) < 0.8
            outer_armed = 0,    -- ...as 'bbancient' would read it: J.GetHP < 0.8
            live_branch = 0 }   -- flip AND pair AND outer_armed: what a wave could see
local witnesses = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        c.fixtures = c.fixtures + 1
        local anc_teams = fixture_ancient_teams(fx)
        if next(anc_teams) ~= nil then c.fixtures_with_ancient = c.fixtures_with_ancient + 1 end
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                GAMEMODE_TURBO = nil                   -- luacheck: ignore
                local ok, J, bot = pcall(rf.load, path, u.name)
                GAMEMODE_TURBO = 23                    -- luacheck: ignore
                GetGameMode = function() return 23 end -- luacheck: ignore
                if ok and J ~= nil and bot ~= nil then
                    c.live = c.live + 1
                    local hAnc = GetAncient(bot:GetTeam())
                    if hAnc == nil or not anc_teams[bot:GetTeam()] then
                        c.refused_no_ancient = c.refused_no_ancient + 1
                    else
                        local vLoc = hAnc:GetLocation()
                        local tAllies = J.GetAlliesNearLoc(vLoc, R)
                        local nEnemyW = J.GetEnemiesAroundLoc(vLoc, R)

                        -- the shipped term, rebuilt character for character
                        if tAllies == 0 then c.shipped_true = c.shipped_true + 1 end

                        local bArmed = (tAllies ~= nil and #tAllies == 0)
                        if bArmed then c.armed_true = c.armed_true + 1
                        else c.armed_false = c.armed_false + 1 end

                        local bOuterShipped = hAnc:GetHealth() < 0.8
                        local bOuterArmed   = J.GetHP(hAnc) < 0.8
                        if bOuterShipped then c.outer_shipped = c.outer_shipped + 1 end
                        if bOuterArmed   then c.outer_armed   = c.outer_armed   + 1 end

                        if bArmed and (tAllies == 0) == false then
                            c.flip = c.flip + 1
                            if nEnemyW > 1 then
                                c.pair = c.pair + 1
                                if bOuterArmed then c.live_branch = c.live_branch + 1 end
                                witnesses[#witnesses + 1] = string.format(
                                    '%s  %s  t=%.1f  allies=%d enemyW=%.2f ancHP=%.2f',
                                    path:gsub('tests/fixtures/', ''),
                                    u.name:gsub('npc_dota_hero_', ''), fx.time or -1,
                                    #tAllies, nEnemyW, J.GetHP(hAnc))
                            end
                        end
                    end
                end
            end
        end
    end
end

GAMEMODE_TURBO = nil                               -- luacheck: ignore
GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore

for _, k in ipairs({ 'fixtures', 'fixtures_with_ancient', 'live', 'refused_no_ancient',
                     'shipped_true', 'armed_true', 'armed_false', 'flip', 'pair',
                     'outer_shipped', 'outer_armed', 'live_branch' }) do
    out:write('P ', k, ' ', tostring(c[k]), '\n')
end
for i, w in ipairs(witnesses) do
    if i <= 40 then out:write('W ', w, '\n') end
end
out:write('DONE\n')
