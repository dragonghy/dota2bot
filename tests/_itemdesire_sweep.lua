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
                                bump('crash_' .. (tostring(terr):match('jmz_func%.lua:(%d+)') or 'other'))
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
    if not honest_tp then
        for n, v in pairs(load_fail) do
            out:write(string.format('LOADFAIL %s %d\n', n, v))
        end
    end
end

sweep('base', false)
sweep('honest', true)
out:write('DONE\n')
