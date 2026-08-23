-- Heavy corpus sweep for tests/test_fightback_world_assertion.lua, run as a
-- SUBPROCESS (backlog 0q: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame -- ~966 loads, ~27s -- must not run on run_tests.lua's long-lived
-- heap). The leading underscore keeps run_tests.lua from globbing it.
--
-- It answers ONE question, over every live hero frame in tests/fixtures/:
-- can this corpus tell whether the bot is FIGHTING BACK? That is the predicate
-- GH #119's replay-desk follow-ups (02:36Z and 06:55Z) named as `fieldcreep`'s
-- next lever -- "判据要读方向,不要读量级" -- with two suggested spellings.
-- Both spellings are evaluated here, plus the shipped J.IsAttacking, plus the
-- two creep-list readers, and each one is then applied AS AN EXCLUSION to the
-- frames `fieldcreep` actually vetoes so the effect is measured, not argued.
--
-- print() is not usable here (the loaded bots/ world replaces it): io.write.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                         a counter bucket
--   VROW <fixture> <hero> <at> <idle> <atk> <idlefix>
--       one frame where the shipped `fieldcreep` clause turns the situation
--       OFF, with each candidate exclusion's answer on that same frame
--       (1 = the exclusion would fire and hand the frame back).
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

-- Constants READ FROM SOURCE, never restated (the M13 lesson: a census that
-- copies the constant it measures reports the old world unmoved after the
-- constant moves).
local SRC = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end)()

local LOOKBACK = (function()
    local n = SRC:match('bot:WasRecentlyDamagedByCreep%(%s*([%d%.]+)%s*%)')
    assert(n, 'the fieldcreep clause is no longer a literal WasRecentlyDamagedByCreep')
    return tonumber(n)
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

-- Every bucket is REGISTERED at zero before the sweep runs, so a counter that
-- never fires prints `C <key> 0` instead of being absent. The reason is not
-- tidiness: an absent key reaches the test as nil, and nil arriving at
-- cs.universal's string.format raises "bad argument #3" -- a crash where the
-- finding should have been. Caught by this file's own mutation M2 (teach the
-- loader to answer GetAttackTarget: the honest failure is "0 of 966", and what
-- actually came out was a format error two frames deep in corpus_scale).
for _, k in ipairs({
    'fixtures', 'live',
    'at_nil', 'at_REAL', 'lat_zero', 'lat_REAL', 'anim_zero', 'anim_REAL',
    'idle_TRUE', 'idle_false', 'atk_TRUE', 'atk_false',
    'idlefix_TRUE', 'idlefix_false',
    'neutralcreeps', 'enemycreeps', 'allycreeps',
    'situation', 'situation_armed', 'vetoed', 'IMPOSSIBLE_widened',
    'vetoed_excl_at', 'vetoed_excl_idle', 'vetoed_excl_atk', 'vetoed_excl_idlefix',
}) do rawset(c, k, 0) end

-- The two spellings the replay desk proposed, plus the one the repository
-- already ships. Each takes the loaded bot and answers "am I fighting back".
--   at   -- bot:GetAttackTarget() ~= nil          (#119 comment, 02:36Z)
--   idle -- GameTime() - GetLastAttackTime() <= LOOKBACK
--           ("同窗口内自己打出过伤害", spelled with the only engine reader that
--            exists for it: bots/FunLib/jmz_func.lua:2052 uses this shape)
--   atk  -- J.IsAttacking(bot)                    (shipped, jmz_func.lua:3067)
local function probe_at(_, bot) return bot:GetAttackTarget() ~= nil end
local function probe_idle(_, bot)
    return (GameTime() - bot:GetLastAttackTime()) <= LOOKBACK
end
local function probe_atk(J, bot) return J.IsAttacking(bot) end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                bump('live')
                local J, bot = rf.load(path, u.name)
                J.IsSoakCandidate = function() return false end

                -- ---- the four readers, as the corpus answers them ----------
                if bot:GetAttackTarget() == nil then bump('at_nil') else bump('at_REAL') end
                if bot:GetLastAttackTime() == 0 then bump('lat_zero') else bump('lat_REAL') end
                if bot:GetAnimActivity() == 0 then bump('anim_zero') else bump('anim_REAL') end
                if probe_idle(J, bot) then bump('idle_TRUE') else bump('idle_false') end
                if probe_atk(J, bot) then bump('atk_TRUE') else bump('atk_false') end
                bump('neutralcreeps', #bot:GetNearbyNeutralCreeps(1600))
                bump('enemycreeps', #bot:GetNearbyCreeps(1600, true))
                bump('allycreeps', #bot:GetNearbyCreeps(1600, false))

                -- ---- the same `idle` probe with the clock REPAIRED ---------
                -- The mock's GameTime() is a constant 0 while the loader
                -- answers DotaTime() with the real frame time (the FOURTEENTH
                -- world assertion's cause (1), tests/test_pingstamp_world_
                -- assertion.lua:55). Anyone reaching for the obvious repair
                -- gets a DIFFERENT structural answer, not a real one -- that is
                -- what this second reading is for.
                local real_gametime = GameTime
                GameTime = function() return DotaTime() end -- luacheck: ignore
                local idlefix = probe_idle(J, bot)
                GameTime = real_gametime -- luacheck: ignore
                if idlefix then bump('idlefix_TRUE') else bump('idlefix_false') end

                -- ---- the fieldcreep domain, and what each exclusion does ---
                local sit = J.IsFieldRegenSituation(bot)
                if sit then bump('situation') end
                J.IsSoakCandidate = function(id) return id == 'fieldcreep' end
                local sit2 = J.IsFieldRegenSituation(bot)
                if sit2 then bump('situation_armed') end
                J.IsSoakCandidate = function() return false end

                if sit and not sit2 then
                    bump('vetoed')
                    local at, idle, atk = probe_at(J, bot), probe_idle(J, bot), probe_atk(J, bot)
                    if at then bump('vetoed_excl_at') end
                    if idle then bump('vetoed_excl_idle') end
                    if atk then bump('vetoed_excl_atk') end
                    if idlefix then bump('vetoed_excl_idlefix') end
                    out:write(string.format('VROW %s %s %d %d %d %d\n', path, u.name,
                        at and 1 or 0, idle and 1 or 0, atk and 1 or 0, idlefix and 1 or 0))
                end
                -- The clause is append-only and can only `return false`, so a
                -- frame it turns ON is structurally impossible.
                if sit2 and not sit then bump('IMPOSSIBLE_widened') end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write(string.format('C lookback_x10 %d\n', math.floor(LOOKBACK * 10 + 0.5)))
out:write('DONE\n')
