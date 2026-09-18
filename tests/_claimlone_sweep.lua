-- Heavy corpus sweep for tests/test_claimlone_roam_lone_ally.lua, run as a
-- SUBPROCESS.  The leading underscore keeps run_tests.lua from globbing it (it
-- globs `^test_.*%.lua$`), and that is not cosmetic: a corpus walk inside the
-- test file itself is what made tests/test_fightfoe_enemyless_fight.lua ~120s,
-- and `tools/agent/lua_gate.py` KILLS an unmeasured new test at
-- `hook_timeout_seconds` = 20.0.
--
-- WHAT IS MEASURED.  Two passes over every live hero frame, paired by
-- `fixture|hero`, one with 'claimlone' armed on ONE side and one with nothing
-- armed at all:
--   C live / self_in_list / ally0 / ally1 / ally2plus    the census at r=1000
--   C target_nonnil                                      the instrument wall
--   C armable                                            ally1 ∩ gate open here
--   C up / down                                          the direction tally
--
-- ⛔ WHY r = 1000 AND NOT 800.  This is the THIRD copy of the belief, not the
-- one 'soloclaim' repaired.  J.IsOtherAllysTarget (jmz_func.lua) rings at 800;
-- X.IsAllysTarget (mode_team_roam_generic.lua) rings at 1000 and reads
-- `ally:GetTarget()` / `ally:GetAttackTarget()` rather than J.GetProperTarget.
-- Reading the 800 census here would answer a question about a DIFFERENT
-- function and call it this one's domain.
--
-- ⛔ WHY TWO REAL LOADS AND NOT ONE FLIPPED GLOBAL.  Reading the shipped answer
-- on the SAME load by putting `GetGameMode` back to 22 reads NOTHING:
-- `J.IsModeTurbo` memoises into a module-level `bModeTurboCache`, so the second
-- call returns the FIRST answer, `shipped` comes back byte-identical to `armed`
-- on every frame, and the tally reads `up = 0` AND `down = 0` -- which is
-- indistinguishable from a perfect direction proof.  The swapped leg's
-- `up > 0` is what refuses that.
--
-- ⛔ THE ONE CONSTRUCTED ELEMENT, declared because it stands on the side that
-- SUPPORTS the conclusion.  `GetTarget` / `GetAttackTarget` answer nil for
-- every ally on every frame (`target_nonnil` is reported): an attack target is
-- bot-VM state the .dem does not carry (GH #27 / STOPPER 4).  The direction
-- tally therefore stubs that ONE read, for the lone ally only, to return the
-- unit being asked about -- i.e. it supplies exactly the fact the corpus is
-- missing and nothing else.  Every other input (who is in the ring, how far,
-- valid, illusion) is the real frame.  The census columns are taken with NO
-- stub at all.
--
-- Usage: lua5.1 tests/_claimlone_sweep.lua   (manifest on stderr, DONE last)

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')
local out = io.stderr

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

--- A unit `unit` that the lone ally is holding.  Both passes ask the identical
--- question of the SAME production entry point, J.IsRoamAllysTarget.
local function ask(J, bot, ring)
    if #ring ~= 1 then return nil end
    local ally = ring[1]
    local unit = { GetLocation = function() return bot:GetLocation() end }
    local spec = rawget(ally, '__spec')
    if spec == nil then return nil end
    local prior = spec.GetTarget
    spec.GetTarget = function() return unit end
    rawset(ally, 'GetTarget', nil)
    local ok, v = pcall(J.IsRoamAllysTarget, unit)
    spec.GetTarget = prior
    rawset(ally, 'GetTarget', nil)
    if not ok then return nil end
    return v
end

local function corpus()
    local c = { live = 0, shipped_live = 0, self_in_list = 0, ally0 = 0,
                ally1 = 0, ally2plus = 0, target_nonnil = 0,
                armable = 0, up = 0, down = 0 }
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
    ss.with_candidate('claimlone', function()
        walk(function(sKey, J, bot)
            c.live = c.live + 1
            local ring = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE) or {}
            for _, a in pairs(ring) do
                if a == bot then c.self_in_list = c.self_in_list + 1 end
                local okt, t = pcall(function() return a:GetTarget() end)
                local oka, t2 = pcall(function() return a:GetAttackTarget() end)
                if (okt and t ~= nil) or (oka and t2 ~= nil) then
                    c.target_nonnil = c.target_nonnil + 1
                end
            end
            if #ring == 0 then c.ally0 = c.ally0 + 1
            elseif #ring == 1 then c.ally1 = c.ally1 + 1
            else c.ally2plus = c.ally2plus + 1 end
            -- ⛔ THE SWITCH IS SIDE-SCOPED: read "is the gate open for this
            -- bot" from the GATE, never from the bot's team.
            if J.IsSoakCandidate('claimlone') and #ring == 1 then
                c.armable = c.armable + 1
            end
            armed_by[sKey] = ask(J, bot, ring)
        end)
    end, 'radiant')
    unprobe()

    -- PASS 2 -- nothing armed.  ⛔ The switch must be GONE, not merely pointed
    -- elsewhere: a leftover would make this pass measure the armed tree and
    -- every flip below would silently read zero.
    ss.assert_clean('claimlone corpus pass 2')
    walk(function(sKey, J, bot)
        c.shipped_live = c.shipped_live + 1
        assert(J.IsSoakCandidate('claimlone') == false,
            'the gate is open during the un-armed pass')
        local ring = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE) or {}
        shipped_by[sKey] = ask(J, bot, ring)
    end)
    unprobe()

    --- ONE tally, called twice with the legs SWAPPED.
    local function tally(a, b, sKey)
        if a == true and b == false then c[sKey] = c[sKey] + 1 end
    end
    for sKey, armed in pairs(armed_by) do
        local shipped = shipped_by[sKey]
        tally(armed, shipped, 'up')    -- FALSE -> TRUE, the allowed direction
        tally(shipped, armed, 'down')  -- TRUE  -> FALSE, forbidden
    end
    return c
end

local c = corpus()
for _, k in ipairs({ 'live', 'shipped_live', 'self_in_list', 'ally0', 'ally1',
                     'ally2plus', 'target_nonnil', 'armable',
                     'up', 'down' }) do
    out:write('C ', k, ' ', tostring(c[k]), '\n')
end
out:write('DONE\n')
