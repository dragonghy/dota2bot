-- Heavy corpus sweep for tests/test_pullcamp_trigger_census.lua, run as a
-- SUBPROCESS (the 2026-08-21T20:35Z / backlog 0q rule: a full-corpus drive that
-- rebuilds jmz_func once per hero-frame -- ~900 loads, ~25s -- must not run on
-- run_tests.lua's long-lived heap). The leading underscore keeps run_tests.lua
-- from globbing it (`^test_.*%.lua$`).
--
-- It prints a flat manifest to stdout; the test parses it and every census
-- assertion reads from it.
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>                         a counter bucket
--   CHAIN <fixture> <hero> <sec>        frame reaching the lane clause, OLD window
--   NEWONLY <fixture> <hero> <sec>      frame the travel lead newly admits
--   WIT <fixture> <hero> <team> <pos> <x> <y> <hp01> <pullsafe> <neut1400>
--   NEUTDMG <fixture> <hero> <support> <hits> <value> <t>
--   DRG <fixture> <hero> <t> <lane>   one frame where the 'dragnolane' guard
--       (GH #652) turns J.GetLanePullDragTarget's answer from a drag
--       destination computed off an unresolvable lane id into a clean nil
--   GRD <fixture> <hero> <t> <lane>   one frame where the 'pullnolane' guard
--       (GH #648) turns the shipped function's answer from "fell through the
--       lane guard and raised at GetLaneFrontLocation" into a clean nil
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The two pull-window edge pairs, READ FROM THE SHIPPED SOURCE rather than
-- restated here -- the M13 lesson (a census that copies the constant it is
-- measuring reports the old world unmoved after the constant changes).
local WINDOW = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = fh:read('*a'); fh:close()
    local at = assert(src:find('function J.ShouldPullNeutralCamp', 1, true),
        'J.ShouldPullNeutralCamp moved')
    local body = src:sub(at, at + 4000)
    local a, b, c, d = body:match(
        'nSec >= (%d+) and nSec <= (%d+)%) or %(nSec >= (%d+) and nSec <= (%d+)')
    assert(a, 'the pull window is no longer two literal nSec ranges')
    return { tonumber(a), tonumber(b), tonumber(c), tonumber(d) }
end)()

-- The window BEFORE the GH #13 repair: the aggro marks with no travel lead.
-- Restated (the pre-repair source is gone), and pinned as such by the test's
-- source assertions, which check the shipped edges against WINDOW above.
local OLD = { 10, 20, 40, 50 }

local function in_window(sec, w)
    return (sec >= w[1] and sec <= w[2]) or (sec >= w[3] and sec <= w[4])
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

local out = io.stdout
local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end

local WITNESS_FIXTURE = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local WITNESS_HERO = 'npc_dota_hero_ogre_magi'

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        local t = fx.time
        local sec = t % 60
        local tw = (t >= 60 and t <= 360)
        local sw_new = in_window(sec, WINDOW)
        local sw_old = in_window(sec, OLD)
        for _, u in ipairs(fx.units) do
            if u.alive then
                local J, bot = rf.load(path, u.name)
                bump('frames')
                local support = not J.IsCore(bot)
                local loc = bot:GetLocation()
                local no800 = #(J.GetEnemiesNearLoc(loc, 800) or {}) == 0
                local lane = bot:GetAssignedLane()
                local tn = bot:GetNearbyNeutralCreeps(1400)
                local camp_up = (tn ~= nil and #tn > 0)
                local sp = GetNeutralSpawners()
                local spawners = (sp ~= nil and next(sp) ~= nil)

                if tw then bump('timewin') end
                if sw_old then bump('secwin_old') end
                if sw_new then bump('secwin_new') end
                if support then bump('support') end
                if no800 then bump('no800') end
                if lane == nil then bump('lane_nil') end
                if lane == 0 then bump('lane_zero') end
                -- [GH #648 20260909] The same frame counted against the
                -- engine's own no-lane sentinel rather than against nil.
                -- Kept separate from `lane_zero` on purpose: that column is a
                -- statement about the LOADER (it answers a constant 0), this
                -- one is a statement about the CONSTANT the shipped guard now
                -- compares to, and the test asserts they agree.
                if lane == (LANE_NONE or 0) then bump('lane_none') end
                if camp_up then bump('camp_up') end
                if spawners then bump('spawners_nonempty') end
                -- [GH #277 20260828] The 800 clause vs the clause that
                -- actually gates the chain. `no800` above is
                -- J.ShouldPullNeutralCamp's OWN threat veto; `pullsafe` is
                -- J.IsLanePullSafe, which mode_roam_generic conjoins onto the
                -- helper's answer at the single call site. Both are counted
                -- HERE, on the same frame, so the two populations below are
                -- differences of measurement rather than of argument.
                local pullsafe = J.IsLanePullSafe(bot)
                if pullsafe then bump('pullsafe') end
                -- Subsumption, measured: an enemy hero inside 800 of the bot is
                -- inside 1800 of the bot, and both predicates gate on the same
                -- J.IsValidHero (which requires CanBeSeen) and the same
                -- IsSuspiciousIllusion filter. So `pullsafe` should IMPLY
                -- `no800` on every frame; a non-zero count here is the news.
                if pullsafe and not no800 then bump('pullsafe_not_no800') end
                -- The converse is the size of the gap, and it is not small.
                if no800 and not pullsafe then bump('no800_not_pullsafe') end

                -- [GH #277 20260828] The SAME three-clause population, but with
                -- the threat clause the shipped chain actually applies. The
                -- block below defines "peacetime lane support" with `no800`,
                -- which is J.ShouldPullNeutralCamp's internal veto -- and that
                -- veto cannot change the chain's answer, because the only call
                -- site conjoins J.IsLanePullSafe onto it. These counters use
                -- `pullsafe` in its place and are otherwise line-for-line the
                -- same question; the test compares the two readings.
                if tw and support and pullsafe then
                    bump('peacetime_live')
                    if sw_old then bump('chain_old_live') end
                    if sw_new then bump('chain_new_live') end
                end

                if tw and support and no800 then
                    bump('peacetime_lane_support')
                    if sw_new then
                        -- [GH #117] Where does a frame that reaches the camp
                        -- selector actually STAND? The new own-side clause
                        -- compares a camp against the lane midpoint, so what
                        -- decides whether it can bite is the bot's own depth
                        -- measured the same way. Honest ancients only (43 of
                        -- the fixtures have no buildings and GetAncient then
                        -- answers the map origin for both teams -- world
                        -- assertion 17), and the midpoint is taken between the
                        -- two real ancients, which is what the test declares.
                        local own = GetAncient(bot:GetTeam())
                        local enemy = GetAncient(
                            bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT)
                        local lo, le = own:GetLocation(), enemy:GetLocation()
                        if not (lo.x == 0 and lo.y == 0 and le.x == 0 and le.y == 0) then
                            bump('depth_honest')
                            local half = J.GetLocationToLocationDistance(lo, le) / 2
                            local d = J.GetLocationToLocationDistance(loc, lo)
                            if d > half then
                                bump('depth_past_mid')
                                -- Past the midpoint by more than the untouched
                                -- 1500 reach: no camp the bot can reach is on
                                -- our side, so the repaired selector returns
                                -- nil whatever the camp list.
                                if d - 1500 > half then bump('depth_forced_nil') end
                            else
                                bump('depth_own_half')
                                -- Inside by more than the reach: every camp the
                                -- bot can reach is on our side, so the clause is
                                -- arithmetically incapable of changing anything.
                                if d + 1500 < half then bump('depth_inert') end
                            end
                        end
                    end
                    if sw_old then
                        bump('chain_old')
                        out:write(string.format('CHAIN %s %s %.1f\n', path, u.name, sec))
                    end
                    if sw_new then bump('chain_new') end
                    if sw_new and not sw_old then
                        out:write(string.format('NEWONLY %s %s %.1f\n', path, u.name, sec))
                    end
                end

                if path == WITNESS_FIXTURE and u.name == WITNESS_HERO then
                    out:write(string.format('WIT %s %s %d %s %.0f %.0f %.2f %s %s\n',
                        path, u.name, bot:GetTeam(), tostring(J.GetPosition(bot)),
                        loc.x, loc.y, J.GetHP(bot),
                        tostring(J.IsLanePullSafe(bot)), tostring(camp_up)))
                end

                -- [GH #250 20260827] What does the WHOLE trigger answer on a
                -- real frame, with its two shipped preconditions handed to it?
                -- Runs LAST in the frame body and on a per-frame-fresh J, so
                -- the overrides below cannot reach any counter above.
                do
                    local nd, ndv = 0, 0
                    for _, r in ipairs(u.recent_damage or {}) do
                        if type(r.src) == 'string'
                            and r.src:find('neutral', 1, true)
                        then
                            nd, ndv = nd + 1, ndv + (r.value or 0)
                        end
                    end
                    if nd > 0 then
                        bump('neut_dmg')
                        if support then
                            bump('neut_dmg_support')
                            if tw then bump('neut_dmg_support_window') end
                        end
                        out:write(string.format('NEUTDMG %s %s %s %d %d %.1f\n',
                            path, u.name, tostring(support), nd, ndv, t))
                    end

                    J.IsModeTurbo = function() return true end
                    J.IsSoakCandidate = function(sId) return sId == 'pullcamp' end
                    local ok, v = pcall(J.ShouldPullNeutralCamp, bot)
                    if not ok then
                        bump('spnc_raise')
                        if tostring(v):find('GetLaneFrontLocation', 1, true) then
                            bump('spnc_raise_lanefront')
                        end
                    elseif v ~= nil then
                        bump('spnc_nonnil')
                    else
                        bump('spnc_nil')
                    end

                    -- [GH #648 20260909] The SAME shipped function, driven a
                    -- second time with 'pullnolane' armed on top of the same
                    -- 'pullcamp'.  Two drives of one function, not one drive
                    -- of two implementations: the differential below is a
                    -- measurement, not an argument.
                    --
                    -- The oracle is STOPPER 3 turned into an instrument.  The
                    -- loader refuses GetLaneFrontLocation (GH #61), and that
                    -- call sits immediately BELOW the lane guard -- so a raise
                    -- naming GetLaneFrontLocation is positive proof that the
                    -- guard let the frame through, and a clean nil in its
                    -- place is positive proof that the guard stopped it.  No
                    -- world is declared to read this.
                    J.IsSoakCandidate = function(sId)
                        return sId == 'pullcamp' or sId == 'pullnolane'
                    end
                    local ok2, v2 = pcall(J.ShouldPullNeutralCamp, bot)
                    if not ok2 then
                        bump('guard_raise')
                    elseif v2 ~= nil then
                        bump('guard_nonnil')
                    else
                        bump('guard_nil')
                    end
                    -- The differential, and its forbidden direction.  A guard
                    -- can only ever REMOVE a pull, so `guard_opens` must be 0
                    -- over the whole corpus; and a counter of all zeros cannot
                    -- tell "the direction holds" from "the tally never ran",
                    -- so the same frames drive `guard_closes`, which must be
                    -- the whole population of frames that reach the clause.
                    if (not ok) and ok2 and v2 == nil then
                        bump('guard_closes')
                        out:write(string.format('GRD %s %s %.1f %s\n',
                            path, u.name, t, tostring(lane)))
                    end
                    if ok and v == nil and not ok2 then bump('guard_opens') end
                    if ok and v == nil and ok2 and v2 ~= nil then
                        bump('guard_opens')
                    end
                end

                -- [GH #652 20260909] PRICING THE THREE REMAINING SITES that
                -- carry the GH #648 defect (a lane guard written against `nil`
                -- while the engine says "no lane" with LANE_NONE == 0).  The
                -- previous round repaired ONE of the four and named the other
                -- three explicitly; this block prices each of them BEFORE
                -- anything is written, so "one lever at a time" picks the
                -- lever on a reading rather than on which line was easiest.
                --
                -- Runs last in the frame body, on the same per-frame-fresh J,
                -- and sets its own gate overrides -- nothing here can reach a
                -- counter above.
                do
                    -- (A) J.ShouldLaneRecoverFarm (jmz_func.lua:7960).  Its
                    -- lane block is `if nLane ~= nil then ... end`, so on a
                    -- LANE_NONE frame the block RUNS with 0 as a lane id.  But
                    -- three guards sit above it and one of them is
                    -- J.GetDistanceFromLaneFront, which calls the function the
                    -- loader refuses (GH #61) -- so the question "can this site
                    -- flip here" is answered before it is asked.  A raise
                    -- naming GetLaneFrontLocation is positive proof the frame
                    -- never reached the lane block.
                    J.IsModeTurbo = function() return true end
                    J.IsSoakCandidate = function(sId) return sId == 'lf_recover' end
                    local okA, vA = pcall(J.ShouldLaneRecoverFarm, bot)
                    if not okA then
                        bump('lrf_raise')
                        if tostring(vA):find('GetLaneFrontLocation', 1, true) then
                            bump('lrf_raise_lanefront')
                        end
                    elseif vA then
                        bump('lrf_true')
                    else
                        bump('lrf_false')
                    end

                    -- (B) J.ShouldCreepPullLane (jmz_func.lua:9440).  Its lane
                    -- block reads GetLaneFrontAmount for BOTH teams with the
                    -- same lane id and compares them, so whatever LANE_NONE
                    -- does to that read, it does to it SYMMETRICALLY.  The
                    -- flip domain of a repair here is therefore exactly the
                    -- frames where the two reads differ; counted directly
                    -- rather than argued, because this site is inside a
                    -- PROMOTED helper ('creeppull', live in every turbo game).
                    local fo = GetLaneFrontAmount(GetTeam(), lane, false)
                    local fe = GetLaneFrontAmount(GetOpposingTeam(), lane, false)
                    if fo ~= nil and fe ~= nil then
                        bump('frontamt_both_nonnil')
                        if fo ~= fe then bump('frontamt_differs') end
                        if fe > fo then bump('frontamt_pushed') end
                    end

                    -- (C) J.GetLanePullDragTarget (jmz_func.lua:10523).  Its
                    -- guard is `if nLane == nil then return nil end` -- the
                    -- same unreachable condition GH #648 repaired one function
                    -- earlier -- and below it the function samples 21 points
                    -- along the lane and returns the closest one to the camp.
                    -- So on a LANE_NONE frame the answer is a point derived
                    -- from a lane id the engine cannot resolve, handed back to
                    -- mode_roam_generic as a drag destination.  Two facts are
                    -- counted: whether the lane sampler answers at all here,
                    -- and what the shipped function returns with its own gate
                    -- ('pulldrag', turbo) armed and nothing else.
                    if GetLocationAlongLane(lane, 0.5) ~= nil then
                        bump('alongline_nonnil')
                    end
                    J.IsSoakCandidate = function(sId) return sId == 'pulldrag' end
                    local okC, vC = pcall(J.GetLanePullDragTarget, bot, loc)
                    if not okC then
                        bump('drag_raise')
                    elseif vC ~= nil then
                        bump('drag_nonnil')
                    else
                        bump('drag_nil')
                    end

                    -- The SAME shipped function, driven a second time with
                    -- 'dragnolane' armed on top of the same 'pulldrag'.  Two
                    -- drives of one function, not one drive of two
                    -- implementations: the differential is a measurement.
                    -- The oracle needs no refused call here -- this function
                    -- returns a value rather than raising, so nil vs non-nil
                    -- IS the answer.  `drag_opens` is the forbidden direction
                    -- (a guard can only ever REMOVE a destination), and it is
                    -- a column that reads 0 on a clean tree, so the mutation
                    -- stand varies its POLARITY rather than its name.
                    J.IsSoakCandidate = function(sId)
                        return sId == 'pulldrag' or sId == 'dragnolane'
                    end
                    local okD, vD = pcall(J.GetLanePullDragTarget, bot, loc)
                    if not okD then
                        bump('drag2_raise')
                    elseif vD ~= nil then
                        bump('drag2_nonnil')
                    else
                        bump('drag2_nil')
                    end
                    if okC and vC ~= nil and okD and vD == nil then
                        bump('drag_closes')
                        out:write(string.format('DRG %s %s %.1f %s\n',
                            path, u.name, t, tostring(lane)))
                    end
                    if okC and vC == nil and okD and vD ~= nil then
                        bump('drag_opens')
                    end
                    if okC and vC == nil and not okD then bump('drag_opens') end
                end
            end
        end
    end
end

for _, k in ipairs({
    'fixtures', 'frames', 'timewin', 'secwin_old', 'secwin_new', 'support',
    'no800', 'lane_nil', 'lane_zero', 'camp_up', 'spawners_nonempty',
    'pullsafe', 'peacetime_lane_support', 'chain_old', 'chain_new',
    'pullsafe_not_no800', 'no800_not_pullsafe',
    'peacetime_live', 'chain_old_live', 'chain_new_live',
    'depth_honest', 'depth_past_mid', 'depth_forced_nil', 'depth_own_half',
    'depth_inert',
    'spnc_nil', 'spnc_nonnil', 'spnc_raise', 'spnc_raise_lanefront',
    'lane_none', 'guard_nil', 'guard_nonnil', 'guard_raise',
    'guard_closes', 'guard_opens',
    'lrf_raise', 'lrf_raise_lanefront', 'lrf_true', 'lrf_false',
    'frontamt_both_nonnil', 'frontamt_differs', 'frontamt_pushed',
    'alongline_nonnil', 'drag_raise', 'drag_nonnil', 'drag_nil',
    'drag2_raise', 'drag2_nonnil', 'drag2_nil', 'drag_closes', 'drag_opens',
    'neut_dmg', 'neut_dmg_support', 'neut_dmg_support_window',
}) do
    out:write(string.format('C %s %d\n', k, c[k]))
end
out:write('DONE\n')
