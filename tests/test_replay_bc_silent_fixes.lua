-- [B/C diagnosis 20260723] Three fixes pinned on the B/C batch's own frames:
--
-- 1. homeroute SILENT root cause (f_113203, t=525): turbo's laning phase
--    soft-extends to 10min while net worth < 8000, so the wrecked-and-poor
--    pudge (28%, no consumables, 11307 from the fountain, conditions held
--    48s) was "still laning" and the router never fired. Now a hard 7-min
--    boundary.
-- 2. pushguard trigger contract (f_114311, t=411): drow's abort condition
--    held 4s+ while she chased 1100 deeper into a 3-man collapse and died
--    4.3s after this frame -- the helper must be TRUE here (the desire-side
--    fix, 0.92 > chase, is in mode_retreat_generic).
-- 3. chain-rescue guard (f_113638, t=256): Necro answered a rescue and died
--    to Lina in 5s, becoming the next trigger; CM answered THAT 7s later and
--    died to the same Lina. A spot answered <15s ago must not be answered
--    again.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

-- ---- 1. homeroute on the pudge frame ----------------------------------------

local function pudge(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load('tests/fixtures/f_113203_pudge_homeroute_silent.lua')
    J.IsSoakCandidate = function(id)
        return opts.off ~= true and id == 'homeroute'
    end
    rawget(bot, '__spec').DistanceFromFountain = 11307 -- ground truth at t=524
    return J, bot, heroes, fx
end

tests['[homeroute] the pudge frame now initiates (soft-laning block removed)'] = function()
    local J, bot, _, fx = pudge()
    assert(J.ShouldCommitFountainHeal(bot) == false, 'first sighting stamps')
    DotaTime = function() return fx.time + 21 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == true,
        'pudge at 28%, no consumables, 11307 from home, 48s of drifting -- '
        .. 'the NW<8000 soft-laning clause must no longer block the router')
end

tests['[homeroute] true early game (t<7min) still belongs to the lane candidates'] = function()
    local J, bot = pudge()
    DotaTime = function() return 300 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == false, 'stamp only at t=300')
    DotaTime = function() return 321 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == false,
        'before 7min the lane-phase candidates own low-HP handling')
end

-- ---- 2. pushguard on the drow frame ------------------------------------------

tests['[pushguard] the drow death frame trips the abort helper'] = function()
    local J, bot = rf.load('tests/fixtures/f_114311_drow_pushguard_silent.lua')
    J.IsSoakCandidate = function(id) return id == 'pushguard' end
    -- Drow is RADIANT (armed side): our ancient bottom-left.
    GetAncient = function(team) -- luacheck: ignore
        if team == GetTeam() then
            return api.MakeUnit({ GetLocation = api.Vector(-5900, -5300, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(5900, 5100, 0) })
    end
    assert(J.ShouldAbortDeepSoloPush(bot) == true,
        'depth +4393, no ally within 2500, three enemies converging -- drow '
        .. 'died 4.3s after this frame; the trigger must read TRUE here')
end

-- ---- 3. chain-rescue guard on the CM frame ------------------------------------

local function cm(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load('tests/fixtures/f_113638_cm_chain_rescue.lua')
    J.IsSoakCandidate = function(id) return id == 'lf_rescue' end
    J.IsCore = function() return false end -- CM is the pos-5
    return J, bot, heroes, fx
end

tests['[chain guard] a spot answered 7s ago refuses a second responder'] = function()
    local J, bot, heroes, fx = cm()
    local necro = heroes['npc_dota_hero_necrolyte']
    -- Ground truth: Necro's own rescue TP went out at t=250.4 toward the
    -- sniper/necro corner; CM considered hers at ~257.
    DotaTime = function() return fx.time - 6 end -- luacheck: ignore
    J.NoteRescueResponse(necro:GetLocation())
    DotaTime = function() return fx.time end -- luacheck: ignore
    -- Make necro a textbook rescue target (dying with Lina on it) so ONLY
    -- the chain guard can be the reason for refusal.
    local sp = rawget(necro, '__spec')
    sp.GetHealth = math.floor(necro:GetMaxHealth() * 0.30)
    sp.OriginalGetHealth = sp.GetHealth
    assert(J.IsChainedRescue(necro:GetLocation()) == true,
        'the guard itself must recognize the chained spot')
    assert(J.GetRescueTpTarget(bot) == nil,
        'the previous responder just died here to the same killer -- '
        .. 'feeding a second body changes nothing')
end

tests['[chain guard] the same rescue 20s later (memory expired) is allowed again'] = function()
    local J, bot, heroes, fx = cm()
    local necro = heroes['npc_dota_hero_necrolyte']
    DotaTime = function() return fx.time - 20 end -- luacheck: ignore
    J.NoteRescueResponse(necro:GetLocation())
    DotaTime = function() return fx.time end -- luacheck: ignore
    assert(J.IsChainedRescue(necro:GetLocation()) == false,
        'after 15s the memory expires and a genuine new rescue may go')
end

return tests
