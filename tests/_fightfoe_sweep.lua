-- Heavy corpus sweep for tests/test_fightfoe_enemyless_fight.lua, run as a
-- SUBPROCESS.  The leading underscore keeps run_tests.lua from globbing it
-- (it globs `^test_.*%.lua$`), and that is not cosmetic here -- it is the
-- repair for a MEASURED incident, recorded so nobody re-creates it:
--
-- ⛔ THE INCIDENT.  These two walks first lived inside the test file itself,
-- which made it ~120s.  `tools/agent/lua_gate.py` runs every unmeasured new
-- test with `hook_timeout_seconds` = 20.0 and KILLS it at the timeout.  The
-- kill landed between `ss.arm` and `ss.disarm`, so the global switch
-- `bots/Customize/soak_side.lua` was left on disk holding
-- `{ side = 'radiant', cand = 'fightfoe' }` -- and every OTHER gate test then
-- failed its "gate off" precondition against that leftover.  The push was
-- refused with 11 findings, NONE of which was about the code under test.
-- ⇒ A test that can be killed mid-arm is a hazard to every other test in the
-- suite (the GH #229 / GH #365 §3 family), and the per-test cap is what
-- enforces that.  The fix is the one the manifest's own `hand_added_note`
-- records for 'tpstash' and 'WEAKHPSEED': MAKE THE FILE CHEAP, never shave
-- the recorded number.
--
-- WHAT IS MEASURED.  Two passes over every live hero frame, one with
-- 'fightfoe' armed on ONE side and one with nothing armed, paired by
-- `fixture|hero`:
--   C live / enemyless / ally2 / ally2_enemyless   the §3 census
--   C flippable                                    shipped-TRUE ∩ empty ring
--                                                  ∩ the gate is open here
--   C down / up                                    the §4 direction tally
--
-- ⛔ WHY TWO PASSES AND NOT ONE, and it is a MEASURED trap.  The first version
-- read the shipped answer on the SAME load by flipping `GetGameMode` back to
-- 22.  That reads nothing: `J.IsModeTurbo` memoises into a module-level
-- `bModeTurboCache` (jmz_func.lua:13236), so the second call returns the FIRST
-- answer and `shipped` is byte-identical to `armed` on every frame.  The tally
-- then read `down = 0` AND `up = 0` -- indistinguishable from a perfect
-- direction proof.  The swapped leg's `down > 0` is what refused it.
--
-- Usage: lua5.1 tests/_fightfoe_sweep.lua   (manifest on stderr, DONE last)

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')
local out = io.stderr

local function ring(J, bot)
    return #J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_ATTACK),
           #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

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

local function corpus()
    local c = { live = 0, shipped_live = 0, enemyless = 0, ally2 = 0,
                ally2_enemyless = 0, flippable = 0, down = 0, up = 0 }
    local armed_by, shipped_by = {}, {}

    local function walk(fn)
        for _, path in ipairs(fixture_files()) do
            local fx = dofile(path)
            if type(fx) == 'table' and fx.units and fx.time then
                for _, u in ipairs(fx.units) do
                    if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                        GAMEMODE_TURBO = nil                   -- luacheck: ignore
                        local ok, J, bot = pcall(rf.load, path, u.name)
                        GAMEMODE_TURBO = 23                    -- luacheck: ignore
                        GetGameMode = function() return 23 end -- luacheck: ignore
                        if ok and bot ~= nil then
                            fn(path .. '|' .. u.name, J, bot)
                        end
                    end
                end
            end
        end
        unprobe()
    end

    -- PASS 1 -- the id armed on ONE side.
    ss.with_candidate('fightfoe', function()
        walk(function(sKey, J, bot)
            c.live = c.live + 1
            local nAlly, nEnemy = ring(J, bot)
            if nEnemy == 0 then c.enemyless = c.enemyless + 1 end
            if nAlly >= 2 then
                c.ally2 = c.ally2 + 1
                if nEnemy == 0 then c.ally2_enemyless = c.ally2_enemyless + 1 end
            end
            -- ⛔ THE SWITCH IS SIDE-SCOPED: read "is the gate open for this
            -- bot" from the GATE, never from the bot's team.
            if J.IsSoakCandidate('fightfoe') and nAlly >= 2 and nEnemy == 0 then
                c.flippable = c.flippable + 1
            end
            armed_by[sKey] = J.IsInTeamFight(bot, 1600)
        end)
    end, 'radiant')
    unprobe()

    -- PASS 2 -- nothing armed. ⛔ The switch must be GONE, not merely pointed
    -- elsewhere: without this a leftover would make this pass measure the
    -- armed tree and every flip below would silently read zero.
    ss.assert_clean('fightfoe corpus pass 2')
    walk(function(sKey, J, bot)
        c.shipped_live = c.shipped_live + 1
        assert(J.IsSoakCandidate('fightfoe') == false,
            'the gate is open during the un-armed pass')
        shipped_by[sKey] = J.IsInTeamFight(bot, 1600)
    end)
    unprobe()

    --- ONE tally, called twice with the legs SWAPPED.
    local function tally(a, b, sKey)
        if a and not b then c[sKey] = c[sKey] + 1 end
    end
    for sKey, armed in pairs(armed_by) do
        local shipped = shipped_by[sKey]
        tally(shipped, armed, 'down')  -- TRUE  -> FALSE
        tally(armed, shipped, 'up')    -- FALSE -> TRUE
    end
    return c
end

local c = corpus()
for _, k in ipairs({ 'live', 'shipped_live', 'enemyless', 'ally2',
                     'ally2_enemyless', 'flippable', 'down', 'up' }) do
    out:write('C ', k, ' ', tostring(c[k]), '\n')
end
out:write('DONE\n')
