-- Heavy corpus sweep for tests/test_itemdesire_world_assertion.lua, run as a
-- SUBPROCESS so its ~1700 executions of the 8500-line item file happen in a
-- fresh, short-lived VM with a small heap -- not in run_tests.lua's single
-- long-lived process, where the same work on an already-large shared heap made
-- the whole suite run for the better part of an hour (measured 2026-08-22).
-- This is the 2026-08-21T20:35Z lesson written into the harness: a full-corpus
-- drive must be chunked across processes.
--
-- The leading underscore keeps run_tests.lua from picking it up (it globs
-- `^test_.*%.lua$`). It prints a flat, line-oriented manifest to stdout; the
-- test parses it and every assertion reads from it. Two sweeps in one process
-- (base, then honest-TP) so the "census half is identical" check the test makes
-- is meaningful -- both are measured off the same code path here.
--
-- Manifest grammar (one record per line, space-separated):
--   C <base|honest> <key> <n>            a counter bucket
--   MATURE <fixture> <hero> <level> <H|F> <rest01>
--   CAST <base|honest> <fixture> <hero> <fn> <item>
--   CRASHAT <base|honest> <n> <stripped jmz_func source line>   (text runs to EOL)
--   LOADFAIL <hero> <n>
--   DONE
-- The test treats absence of the final DONE line as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SLOTS = { 5, 4, 3, 2, 1, 0, 15, 16 }

-- The ancient-guard level term, READ FROM THE SHIPPED SOURCE (not hardcoded),
-- so a mutation of the shipped constant moves this census -- the M13 lesson.
local ANCIENT_GUARD_LEVEL = (function()
    local fh = assert(io.open('bots/ability_item_usage_generic.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local at = assert(src:find('\n\t\t--守护遗迹\n', 1, true),
        'the ancient-guard block moved')
    local n = src:sub(at, at + 200):match('if bot:GetLevel%(%) >= (%d+)')
    return assert(tonumber(n), 'the level term is no longer a literal comparison')
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

-- [director 2026-08-29, GH #221] A CRASH SITE IS NAMED BY ITS SOURCE TEXT, NOT
-- BY ITS LINE NUMBER.  The counters used to be keyed `crash_<lineno>` off the
-- runtime error text, and the test pinned `crash_2704 == 178`.  A line number is
-- a COORDINATE: any insertion above the site in jmz_func.lua renames the key,
-- the old name falls through the default-0 metatable, and the pin reads 0 --
-- which is why the recorded failures said `moved: 0` rather than some
-- neighbouring count.  That happened at least twice (2597 -> 2704 -> ?, both
-- caused by unrelated landings in a file two parties never read together), each
-- time costing a red trunk and a re-pin round, and each time the STATEMENT at
-- the site was byte-identical.  Keying on the statement makes the rename
-- impossible for a pure insertion and keeps a genuine move of the crashing
-- expression loud.  Same remedy as test_level_gate_census.lua's
-- `(file, whitespace-stripped source text)` key.
local jmz_source_line = (function()
    local lines = {}
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'),
        'jmz_func.lua is not readable -- crash sites cannot be named')
    for line in fh:lines() do lines[#lines + 1] = line end
    fh:close()
    return function(nLine)
        if not nLine then return '(not in jmz_func.lua)' end
        local s = lines[tonumber(nLine)]
        if not s then return '(jmz_func.lua:' .. nLine .. ' is past end of file)' end
        -- Whitespace-stripped, so re-indentation is not a rename.
        return (s:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', ''))
    end
end)()

local out = io.stdout

--- One full pass. `honest_tp` supplies the TP scroll handle the two clauses the
--- loader never wires (IsTrained / IsActivated) and nothing else -- everything
--- measured before that probe is identical to the base pass, which is why the
--- test can assert the census half unchanged across the two.
local function sweep(tag, honest_tp)
    local aiug = assert(loadfile('bots/ability_item_usage_generic.lua'))
    local c = setmetatable({}, { __index = function() return 0 end })
    local order = {}
    local function bump(k)
        if c[k] == 0 then order[#order + 1] = k end
        c[k] = c[k] + 1
    end
    local load_fail = {}
    local crash_src = {}

    for _, path in ipairs(fixture_files()) do
        local ok0, _, _, heroes = pcall(rf.load, path)
        if ok0 then
            bump('fixtures')
            local names = {}
            for n in pairs(heroes) do names[#names + 1] = n end
            table.sort(names)
            for _, n in ipairs(names) do
                local ok, J, bot, _h, fx = pcall(rf.load, path, n)
                if ok and bot ~= nil then
                    bump('subjects')
                    if not bot:IsAlive() then bump('dead') else
                        bump('alive')
                        local HON = (fx.buildings ~= nil) and 'H' or 'F'
                        bump('alive_' .. HON)

                        local castable = 0
                        for _, s in ipairs(SLOTS) do
                            local it = bot:GetItemInSlot(s)
                            if type(it) == 'table' then
                                bump('slot_occupied')
                                if J.CanCastAbility(it) then
                                    castable = castable + 1
                                    bump('slot_castable')
                                end
                            end
                        end
                        if castable == 0 then bump('frames_zero_castable') end

                        local tp = bot:GetItemInSlot(15)
                        if type(tp) == 'table' and tp:GetName() == 'item_tpscroll' then
                            bump('has_tp')
                            if tp:IsFullyCastable() then bump('tp_cooldown_ready') end
                            if J.CanCastAbility(tp) then bump('tp_castable') end
                            if honest_tp then
                                tp.IsTrained = function() return true end
                                tp.IsActivated = function() return true end
                            end
                        end

                        local team = bot:GetTeam()
                        local anc = GetAncient(team)
                        local nMin = 5500
                        if bot:GetLevel() > 12 and bot:DistanceFromFountain() < 600 then
                            nMin = nMin + 600
                        end
                        local o1 = bot:GetLevel() >= ANCIENT_GUARD_LEVEL
                        local o2 = #J.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE) == 0
                        local o3 = J.Role.ShouldTpToFarm()
                        local o4 = bot:DistanceFromFountain() > 2000
                        local o5 = GetUnitToUnitDistance(bot, anc) > nMin - 200
                        local o6 = J.GetAroundTargetAllyHeroCount(anc, 1400) == 0
                        local rest = o2 and o3 and o4 and o5 and o6
                        if o1 then
                            bump('level15')
                            -- MATURE roster only needs to be emitted once; the
                            -- census is identical across sweeps, so emit it on
                            -- the base pass only.
                            if not honest_tp then
                                out:write(string.format('MATURE %s %s %d %s %d\n',
                                    path:match('[^/]+$'), n, bot:GetLevel(), HON,
                                    rest and 1 or 0))
                            end
                        end
                        if rest then
                            bump('rest5_' .. HON)
                            if o1 then bump('outer_and_' .. HON)
                            else bump('sole_blocker_' .. HON) end
                        end
                        if GetTower(team, 9) == nil and GetTower(team, 10) == nil then
                            bump('both_t4_absent_' .. HON)
                        end

                        if not pcall(aiug) then
                            bump('aiug_load_fail')
                            load_fail[n] = (load_fail[n] or 0) + 1
                        else
                            bump('driven')
                            local log = rf.record_actions(bot)
                            bot.lastItemFrameProcessTime = DotaTime() - 100
                            local okt, terr = pcall(_G.ItemUsageThink)
                            if not okt then
                                bump('crash_total')
                                local nLine = tostring(terr):match('jmz_func%.lua:(%d+)')
                                bump('crash_' .. (nLine or 'other'))
                                local sSrc = jmz_source_line(nLine)
                                crash_src[sSrc] = (crash_src[sSrc] or 0) + 1
                            elseif #log == 0 then
                                bump('no_action')
                            else
                                for _, e in ipairs(log) do
                                    bump('action_total')
                                    local a = e.args[1]
                                    local nm = (type(a) == 'table' and a.GetName) and a:GetName() or '?'
                                    bump('item_' .. nm)
                                    out:write(string.format('CAST %s %s %s %s %s\n',
                                        tag, path:match('[^/]+$'), n, e.fn, nm))
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for _, k in ipairs(order) do
        out:write(string.format('C %s %s %d\n', tag, k, c[k]))
    end
    -- The source text is the LAST field precisely because it contains spaces;
    -- the `C` grammar's `%S+` key could never have carried it.
    for s, v in pairs(crash_src) do
        out:write(string.format('CRASHAT %s %d %s\n', tag, v, s))
    end
    if not honest_tp then
        for n, v in pairs(load_fail) do
            out:write(string.format('LOADFAIL %s %d\n', n, v))
        end
    end
end

sweep('base', false)
sweep('honest', true)
out:write('DONE\n')
