-- Heavy corpus sweep for tests/test_replay_creepthink_drag_order.lua, run as a
-- SUBPROCESS (the backlog rule: a full-corpus drive that rebuilds jmz_func once
-- per hero-frame must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS PRICED.  GH #521 (replay desk, 2026-09-05) ruled that soak candidate
-- 'creepthink' -- armed since W30, 155 reports, ZERO condition-(a) verdict, one
-- of the three ids in the whole armed set with both coverage columns at zero --
-- CANNOT have its condition (a) bought from the dump side at any price, and
-- handed this group the fixture layer as its only live route.  The reason is
-- structural and worth restating, because it decides what this sweep may claim:
-- the only thing 'creepthink' changes is WHETHER Think() reaches the line that
-- orders the drag, and the command stream is not in the dump.  Every
-- displacement proxy for it is contaminated by orders issued on earlier frames
-- (a throttled hero keeps walking) and by the other modes' Thinks, which can
-- turn the same hero on the same frame.
--
-- So this file does not measure behaviour.  It prices the DOMAIN of the fixture
-- test next door: on how many real corpus frames can a creep-pull plan exist at
-- all, what is missing when it cannot, and is what remains a declaration this
-- group is allowed to make.
--
-- THE ONE MISSING FIELD.  `J.ShouldCreepPullLane` needs, among nine other
-- clauses, `bot:GetNearbyLaneCreeps(900, true)` to be non-empty -- the wave
-- whose aggro the pull draws.  The dumper writes heroes and buildings; it
-- writes no lane creeps, and the mock answers `{}`.  That single absence is
-- measured here as `plan_shipped == 0` on EVERY frame in the corpus, and it is
-- the same shape as GH #511's `buildings.modifiers` hand-off: not a bug in the
-- lever, a field the instrument does not carry.
--
-- WHAT THE THREE COLUMNS ARE FOR.  A bare `0` cannot tell "the world says no"
-- from "this branch never ran" (GH #171).  So the sweep also drives the SAME
-- shipped helper on the SAME frames with ONE enemy lane creep declared -- placed
-- on the segment between the bot and its nearest enemy hero, 250 u from that
-- hero, i.e. inside the 500 u aggro-redirect ring the helper itself tests -- and
-- reports how many frames then produce a plan (`plan_declared`), and how many of
-- those also clear `J.IsCreepPullSafe`, which is what GetDesire additionally
-- demands before it writes `bot.roamCreepPull` (`plan_declared_safe`).
--
--   plan_shipped        0     the corpus cannot carry this decision unaided
--   plan_declared       > 0   and the reason is the creeps, nothing else
--   plan_declared_safe  > 0   and GetDesire would really commit on those frames
--
-- The middle column is the anti-vacuity control: if it were also 0, the zero
-- above would be uninformative (some other clause would be doing the refusing)
-- and the fixture test's declaration would be buying a plan the shipped helper
-- would reject anyway.  It is not: the declaration restores exactly the one
-- field the dumper omits, and the other nine clauses are then answered by the
-- REAL frame -- role, HP, laning phase, enemy count, the zoning/lane-front
-- disadvantage test, and the attackability of the target.
--
-- HONEST BOUNDARY.  A stand-in creep at a constructed location is legitimate for
-- the PLUMBING question (does the pull plan form, and does Think then order the
-- drag) and is NOT legitimate for the lane question (would this pull actually
-- reset the equilibrium).  That second question needs the wave, and the wave is
-- not in this corpus at any price.  Nothing here or in the test next door is a
-- promote argument; both are condition-(a) evidence that the gated line changes
-- the ORDERS ISSUED on a real frame.
--
-- Three-valued throughout (GH #492): a raise is bucketed on its own and is never
-- folded into a measured "no".
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>    a counter bucket
--   DONE
-- The test treats absence of the final DONE line as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local out = io.stdout

-- The helper's own late-game curfew: `if DotaTime() > 6 * 60 then return nil end`.
-- Frames past it can never carry a plan, so they are counted but not driven --
-- and the split is reported so a shrinking laning corpus is visible, not silent.
local CURFEW = 6 * 60
local CREEP_FROM_ENEMY = 250 -- inside the 500u aggro-redirect ring

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
for _, k in ipairs({
    'fixtures', 'live', 'laning_frames', 'past_curfew',
    'creeps_nil', 'creeps_empty', 'creeps_nonempty', 'creeps_raise',
    'plan_shipped', 'plan_shipped_raise',
    'declared_driven', 'plan_declared', 'plan_declared_raise',
    'plan_declared_safe', 'safe_raise',
    'enemy_is_real_hero', 'retreat_moves',
}) do rawset(c, k, 0) end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local bLaning = fx.time <= CURFEW
        for _, u in ipairs(fx.units) do
            if u.alive and type(u.name) == 'string' and u.name:match('^npc_dota_hero_') then
                local okl, J, bot = pcall(rf.load, path, u.name)
                if okl and bot ~= nil and J ~= nil then
                    bump('live')
                    if not bLaning then bump('past_curfew') else
                        bump('laning_frames')

                        -- REACHABILITY (GH #171): the zero below has to be the
                        -- world's, not an un-run branch.  Ask the same getter
                        -- the helper asks, and bucket nil / empty / non-empty /
                        -- raise apart, so "the dumper writes no creeps" is a
                        -- MEASURED empty table rather than a missing method.
                        local okc, creeps = pcall(function()
                            return bot:GetNearbyLaneCreeps(900, true)
                        end)
                        if not okc then bump('creeps_raise')
                        elseif creeps == nil then bump('creeps_nil')
                        elseif #creeps == 0 then bump('creeps_empty')
                        else bump('creeps_nonempty') end

                        -- Column 1: the tree exactly as it stands, on the frame
                        -- exactly as the dumper wrote it.
                        local okp, plan = pcall(J.ShouldCreepPullLane, bot)
                        if not okp then bump('plan_shipped_raise')
                        elseif plan ~= nil then bump('plan_shipped') end

                        -- Column 2: the same shipped helper with ONE enemy lane
                        -- creep declared.  Everything else still comes off the
                        -- real frame.
                        local te = J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
                        if te ~= nil and #te >= 1 then
                            bump('declared_driven')
                            local e = te[1]
                            local vb, ve = bot:GetLocation(), e:GetLocation()
                            local dx, dy = vb.x - ve.x, vb.y - ve.y
                            local m = math.max(math.sqrt(dx * dx + dy * dy), 1)
                            local creep = api.MakeUnit({
                                CanBeSeen = true, IsAlive = true,
                                GetTeam = (u.team == 2) and 3 or 2,
                                GetLocation = api.Vector(
                                    ve.x + dx / m * CREEP_FROM_ENEMY,
                                    ve.y + dy / m * CREEP_FROM_ENEMY, 0),
                            })
                            local sp = rawget(bot, '__spec')
                            sp.GetNearbyLaneCreeps = function() return { creep } end
                            rawset(bot, 'GetNearbyLaneCreeps', nil)

                            local okd, plan2 = pcall(J.ShouldCreepPullLane, bot)
                            if not okd then bump('plan_declared_raise')
                            elseif plan2 ~= nil then
                                bump('plan_declared')
                                -- The target is a REAL hero out of the dump, not
                                -- the stand-in creep: the thing the drag branch
                                -- right-clicks is real even though the wave is not.
                                local nm = plan2.enemy ~= nil and plan2.enemy.GetUnitName ~= nil
                                    and plan2.enemy:GetUnitName() or ''
                                if type(nm) == 'string' and nm:match('^npc_dota_hero_') then
                                    bump('enemy_is_real_hero')
                                end
                                -- And the retreat point is a real displacement
                                -- off the bot's real position, not the origin.
                                local vr = plan2.retreat
                                if vr ~= nil then
                                    local rx, ry = vr.x - vb.x, vr.y - vb.y
                                    if math.sqrt(rx * rx + ry * ry) > 1 then bump('retreat_moves') end
                                end
                                local oks, bSafe = pcall(J.IsCreepPullSafe, bot)
                                if not oks then bump('safe_raise')
                                elseif bSafe then bump('plan_declared_safe') end
                            end
                        end
                    end
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
