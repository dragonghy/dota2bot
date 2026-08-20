-- [defclose] "Which of us is closest to the tower?" never looks at the first
-- role in the list.
--
-- aba_defend.GetClosestAllyPos(tPosList, vLocation) is the arbiter for every
-- "only the nearest teammate of these roles may defend this building" rule.
-- The scan is written as if the list were 1-based -- in the TS source it walks
-- j = 1..length and reads tPosList[j] (typescript/bots/FunLib/aba_defend.ts),
-- which tstl renders here as tPosList[j + 1], i.e. indices 2..#+1. So the
-- FIRST role in the list is never compared, index #+1 is nil, and
-- `bestPos or tPosList[1]` falls back to precisely the role that was never
-- compared. Per call site:
--
--   {4, 5}        only role 5 can ever win, at ANY distance; when no role-5
--                 hero is alive the answer is 4, also at any distance
--   {2, 3}        only role 3; fallback 2
--   {2, 3, 4, 5}  role 2 can never be the answer -- so ShouldDefend's
--                 under-fire gate ("only the closest of 2/3/4/5 keeps
--                 defending") disqualifies the mid outright, on top of role 1
--                 which is not in the list at all
--
-- The distance comparison the function exists for is therefore inert for the
-- first role of every list, and the tie-break degenerates to role number.
--
-- DOMAIN (measured, not guessed): over 2883 threatened-tower frames from six
-- turbo replays (an own tower still standing with at least one enemy hero
-- inside 1600 of it) the shipped answer differs from the true closest in
-- 32.8% of {4,5} frames, 59.8% of {2,3} frames and 37.6% of {2,3,4,5} frames.
-- Roles there are the DRAFTED roles from each game's soak seed
-- (tools/batch_test/soak/seed_draft.py), not the draft slot -- see GH #57.
--
-- REAL FRAME: f_260820_043140_wd_defend_token -- game 20260820_043140_slot1 at
-- t=297.5 (4:57). Subject witch_doctor, Dire, drafted role 4, FULL health,
-- standing 915u from its own 99%-hp mid tier-1 tower, which has exactly one
-- enemy (death_prophet) inside 1600. It is the closest hero on its team to
-- that tower by a factor of four. Shipped hands the token to role 5 at 3981u
-- via {4,5}, and -- because the role-3 tidehunter is dead, so the {2,3} scan
-- finds no candidate at all -- the fallback then names role 2, at 6996u.
--
-- The frame is pinned for the MECHANISM, not as proof the alternative was
-- better. What followed, recorded here so nobody has to re-derive it: the
-- witch_doctor walked away from that tower to the far bottom-right of the map
-- (t=302.5 (1994,83) -> t=322.5 (6006,-2532)), traded there, killed the
-- vengeful_spirit at t=334, and died at t=368 (70.5s after this frame). The
-- tower it left fell at t=599.5.
--
-- CONTROL FRAME: f_260820_043710_lich_defend_pos5 -- a role-4 lich 1118u from
-- its own threatened bot tier-1 tower where the role-5 vengeful_spirit really
-- IS closer (800u). There armed must be a byte-for-byte no-op: the candidate
-- makes the comparison honest, it does not hand the token to role 4.
--
-- LIMITATION, stated rather than hidden: GetDefendLaneDesire(lane) is engine
-- state and the .dem does not carry it (same family as GH #27). The bid
-- assertions below therefore sweep it rather than pretend to know it, and say
-- at which values the mode auction changes hands.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local TOKEN = 'tests/fixtures/f_260820_043140_wd_defend_token.lua'
local POS5  = 'tests/fixtures/f_260820_043710_lich_defend_pos5.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- arithmetic on the desire constants (same reason as
-- tests/test_defstale_defend_bail.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
    BOT_ACTION_DESIRE_NONE     = 0.0,
    BOT_ACTION_DESIRE_VERYLOW  = 0.1,
    BOT_ACTION_DESIRE_LOW      = 0.25,
    BOT_ACTION_DESIRE_MODERATE = 0.5,
    BOT_ACTION_DESIRE_HIGH     = 0.75,
    BOT_ACTION_DESIRE_VERYHIGH = 0.9,
    BOT_ACTION_DESIRE_ABSOLUTE = 1.0,
}

--- Load a real frame with the real aba_defend on top of it.
---   opts.armed    -- arm 'defclose' (nothing else is ever armed)
---   opts.turbo    -- false makes J.IsModeTurbo() report a non-turbo game
---   opts.laneBid  -- what the engine's per-lane defend desire reports
local function world(path, opts)
    opts = opts or {}
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    rf = require('mock.replay_fixture')
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end

    J.IsSoakCandidate = function(id)
        return id == 'defclose' and opts.armed == true
    end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end

    local bid = opts.laneBid or 0
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return bid end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    -- GH #61: rf.load refuses to answer GetLaneFrontLocation. This file's
    -- claims about the arbitration are about who defends WHICH tower, decided
    -- by `#J.GetLastSeenEnemiesNearLoc(tower:GetLocation(), 1600)` -- lane
    -- fronts do not enter the arbitration. Declaring the origin here is the
    -- explicit continuation of the pre-#61 world: it lands at the middle of
    -- the river and `ds.distanceToLane` is identical across lanes, which is
    -- fine BECAUSE this file's assertions never read it.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore

    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, heroes, fx, Defend
end

local function dist2d(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

--- The one own tower that has an enemy hero inside 1600 of it.
local function threatened_own_tower(J, bot)
    local found = nil
    for i = 0, 10 do
        local t = GetTower(bot:GetTeam(), i)
        if t ~= nil and t:IsAlive()
        and #J.GetLastSeenEnemiesNearLoc(t:GetLocation(), 1600) > 0 then
            assert(found == nil, 'these frames were chosen to have exactly one')
            found = t
        end
    end
    return found
end

--- Every living teammate's distance to a location, keyed by drafted role.
local function role_distances(J, loc)
    local out = {}
    for i = 1, 5 do
        local m = GetTeamMember(i)
        if m ~= nil and J.IsValidHero(m) then
            out[J.GetPosition(m)] = dist2d(m:GetLocation(), loc)
        end
    end
    return out
end

--- Bid every script mode on this frame and report the winner.
local function auction()
    local best, bestName = -1, 'none'
    local p = io.popen('ls bots/mode_*.lua')
    for path in p:lines() do
        GetDesire = nil -- luacheck: ignore
        local ok = pcall(dofile, path)
        if ok and type(GetDesire) == 'function' then
            local ok2, d = pcall(GetDesire)
            if ok2 and type(d) == 'number' and d > best then
                best, bestName = d, path:match('mode_(.-)_generic') or path
            end
        end
    end
    p:close()
    return bestName, best
end

local function bid_all(Def, bot)
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do Def.GetDefendDesire(bot, lane) end
end

-- ---------------------------------------------------------------------------
-- The frame. Every premise the defect rests on is asserted, not assumed.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: a full-hp role-4 is the nearest hero to its threatened tower'] = function()
    local J, bot, _, fx = world(TOKEN)
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(math.abs(fx.time - 297.5) < 1e-6, 'frame is t=297.5; got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_witch_doctor', 'subject is the witch_doctor')
    assert(fx.roles ~= nil,
        'the fixture must carry DRAFTED roles -- without them GetPosition falls back '
        .. 'to the draft slot, which GH #57 measured at 47.3% accurate')
    assert(J.GetPosition(bot) == 4, 'subject was drafted role 4; got ' .. J.GetPosition(bot))
    assert(bot:GetHealth() == bot:GetMaxHealth(),
        'subject is at FULL health -- it is not declining to defend because it is hurt')

    local tower = threatened_own_tower(J, bot)
    assert(tower ~= nil, 'the frame must carry the subject\'s own towers')
    local d = dist2d(bot:GetLocation(), tower:GetLocation())
    assert(d > 910 and d < 920, 'subject is ~915u from it; got ' .. string.format('%.0f', d))
    assert(tower:GetHealth() / tower:GetMaxHealth() > 0.99,
        'that tower is still at 99% health -- there is everything left to defend')
    assert(#J.GetLastSeenEnemiesNearLoc(tower:GetLocation(), 1600) == 1,
        'exactly one enemy inside 1600 of it')

    -- ...while no enemy is inside 1600 of the SUBJECT, which is what lets the
    -- helper reach the ShouldDefend line at all (the guard above it returns
    -- VeryLow whenever ds.nInRangeEnemy is non-empty).
    assert(#J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600) == 0,
        'no enemy within 1600 of the subject, so GetDefendDesireHelper runs past '
        .. 'its in-range guard and actually consults ShouldDefend')

    local byRole = role_distances(J, tower:GetLocation())
    assert(byRole[4] ~= nil and byRole[3] == nil,
        'the role-3 teammate is dead on this frame, which is what empties the {2,3} scan')
    for role, dd in pairs(byRole) do
        if role ~= 4 then
            assert(dd > byRole[4] * 4,
                'role ' .. role .. ' is more than four times further from the tower than '
                .. 'the subject (' .. string.format('%.0f vs %.0f', dd, byRole[4])
                .. '), so no reading of "closest" picks it')
        end
    end
end

-- ---------------------------------------------------------------------------
-- The mechanism.
-- ---------------------------------------------------------------------------

tests['MECHANISM: shipped refuses the nearest hero, armed authorises it'] = function()
    local JS, botS, _, _, DefS = world(TOKEN)
    local towerS = threatened_own_tower(JS, botS)
    assert(DefS.ShouldDefend(botS, towerS, 1600) == false,
        'shipped: the nearest hero on the team is not allowed to defend its own tower')

    local JA, botA, _, _, DefA = world(TOKEN, { armed = true })
    local towerA = threatened_own_tower(JA, botA)
    assert(DefA.ShouldDefend(botA, towerA, 1600) == true,
        'armed: once the scan covers the whole list, role 4 is the closest and is allowed')
end

tests['MECHANISM: both lists that could authorise it name someone far away'] = function()
    local J, bot = world(TOKEN)
    local tower = threatened_own_tower(J, bot)
    local byRole = role_distances(J, tower:GetLocation())
    -- {4,5}: shipped can only ever answer 5 -- and a role-5 hero is alive here,
    -- so the "no candidate" fallback to 4 cannot rescue the subject either.
    assert(byRole[5] ~= nil, 'a role-5 hero is alive, so the {4,5} fallback cannot fire')
    assert(byRole[5] > 3900 and byRole[5] < 4050,
        'and it is 3981u from the tower; got ' .. string.format('%.0f', byRole[5]))
    -- {2,3}: the only role shipped compares is 3, and role 3 is dead, so
    -- bestPos stays nil and the fallback names tPosList[1] = 2.
    assert(byRole[3] == nil, 'no living role-3, so the shipped {2,3} scan finds nothing')
    assert(byRole[2] ~= nil and byRole[2] > 6900,
        'and the fallback names role 2, ' .. string.format('%.0f', byRole[2] or -1)
        .. 'u away -- the single furthest teammate from this tower')
end

-- ---------------------------------------------------------------------------
-- The defect, at the final bid, driven through the real mode files.
-- ---------------------------------------------------------------------------

tests['DEFECT: the refusal costs the mid lane its floor and its cap boost'] = function()
    local _, bot0, _, _, Def0 = world(TOKEN, { laneBid = 0 })
    local mid0 = Def0.GetDefendDesire(bot0, LANE_MID)
    assert(math.abs(mid0 - BOT_MODE_DESIRE_VERYLOW) < 1e-9,
        'with no engine lane urgency the shipped mid bid is exactly VeryLow; got '
        .. string.format('%.4f', mid0))
    local _, bot0a, _, _, Def0a = world(TOKEN, { armed = true, laneBid = 0 })
    local mid0a = Def0a.GetDefendDesire(bot0a, LANE_MID)
    assert(math.abs(mid0a - BOT_MODE_DESIRE_LOW) < 1e-9,
        'armed it is exactly Low, the shouldDef floor; got ' .. string.format('%.4f', mid0a))

    local _, bot, _, _, Def = world(TOKEN, { laneBid = 0.30 })
    local mid = Def.GetDefendDesire(bot, LANE_MID)
    assert(mid > 0.36 and mid < 0.37,
        'at laneBid 0.30 shipped bids 0.363; got ' .. string.format('%.4f', mid))
    local _, botA, _, _, DefA = world(TOKEN, { armed = true, laneBid = 0.30 })
    local midA = DefA.GetDefendDesire(botA, LANE_MID)
    assert(midA > 0.47 and midA < 0.48,
        'armed the same frame bids 0.474; got ' .. string.format('%.4f', midA))
end

tests['DEFECT: the mode auction changes hands'] = function()
    local _, bot, _, _, Def = world(TOKEN, { laneBid = 0.30 })
    bid_all(Def, bot)
    local nameS, bidS = auction()
    assert(nameS == 'laning',
        'shipped: the winner of the script auction is laning; got ' .. nameS)

    local _, botA, _, _, DefA = world(TOKEN, { armed = true, laneBid = 0.30 })
    bid_all(DefA, botA)
    local nameA, bidA = auction()
    assert(nameA == 'defend_tower_mid',
        'armed: the winner is the defend mode for the lane the hero is standing in; got '
        .. nameA)
    assert(bidA > bidS,
        'and it wins by outbidding, not by anything else being removed')
    -- LIMITATION (GH #27): the engine's own built-in modes have no script
    -- GetDesire, so this auction covers the SCRIPT modes only. It is a
    -- necessary condition for the mode change, not a proof of it.
end

tests['DEFECT: at higher lane urgency shipped defends a different lane'] = function()
    for _, bid in ipairs({ 0.50, 0.70 }) do
        local _, bot, _, _, Def = world(TOKEN, { laneBid = bid })
        bid_all(Def, bot)
        local nameS = auction()
        assert(nameS == 'defend_tower_bot',
            'shipped at laneBid=' .. bid .. ': the winner is the BOT defend mode; got '
            .. nameS)

        local _, botA, _, _, DefA = world(TOKEN, { armed = true, laneBid = bid })
        bid_all(DefA, botA)
        local nameA = auction()
        assert(nameA == 'defend_tower_mid',
            'armed at laneBid=' .. bid .. ': the winner is the MID defend mode -- the lane '
            .. 'with the enemy on the tower and the hero standing next to it; got ' .. nameA)
    end
end

-- ---------------------------------------------------------------------------
-- Controls.
-- ---------------------------------------------------------------------------

tests['CONTROL: when the role-5 really is closest, armed is a no-op'] = function()
    local J, bot = world(POS5)
    local tower = threatened_own_tower(J, bot)
    local byRole = role_distances(J, tower:GetLocation())
    assert(J.GetPosition(bot) == 4, 'same role as the token frame')
    assert(byRole[5] < byRole[4],
        'on this frame the role-5 is genuinely nearer (' .. string.format('%.0f', byRole[5])
        .. ' vs ' .. string.format('%.0f', byRole[4]) .. ')')

    for _, bid in ipairs({ 0, 0.30, 0.50, 0.70 }) do
        local _, b1, _, _, D1 = world(POS5, { laneBid = bid })
        local _, b2, _, _, D2 = world(POS5, { armed = true, laneBid = bid })
        for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
            local s = D1.GetDefendDesire(b1, lane)
            local a = D2.GetDefendDesire(b2, lane)
            assert(math.abs(s - a) < 1e-9,
                'armed must be byte-identical here (laneBid=' .. bid .. ', lane '
                .. tostring(lane) .. '): ' .. string.format('%.4f vs %.4f', s, a))
        end
    end
end

tests['CONTROL: outside turbo the candidate is inert'] = function()
    local _, bot, _, _, Def = world(TOKEN, { laneBid = 0.30 })
    local shipped = Def.GetDefendDesire(bot, LANE_MID)
    local _, botN, _, _, DefN = world(TOKEN, { armed = true, turbo = false, laneBid = 0.30 })
    local nonTurbo = DefN.GetDefendDesire(botN, LANE_MID)
    assert(math.abs(shipped - nonTurbo) < 1e-9,
        'armed but not turbo must equal shipped; got '
        .. string.format('%.4f vs %.4f', shipped, nonTurbo))
end

tests['CONTROL: only defclose is armed, nothing else in the tree'] = function()
    local J = world(TOKEN, { armed = true })
    assert(J.IsSoakCandidate('defclose') == true, 'the candidate under test is armed')
    for _, other in ipairs({ 'defstale', 'roamstale', 'tpdying', 'tpdead', 'ownhalf', 'all' }) do
        assert(J.IsSoakCandidate(other) == false, other .. ' must stay disarmed')
    end
end

-- ---------------------------------------------------------------------------
-- Reverse assertions: if somebody repairs this properly, this file must say so.
-- ---------------------------------------------------------------------------

tests['REVERSE: the off-by-one and its fallback are still what shipped does'] = function()
    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    assert(src:find('return bestPos or tPosList[1]', 1, true),
        'the fallback still returns the first entry -- the very one the shipped scan '
        .. 'never compares. If this line has changed, re-derive this whole file')
    assert(src:find('while j <= jLast do', 1, true) and src:find('p == tPosList[j + 1]', 1, true),
        'the scan is still index-shifted by one, gated open only by defclose')
    local n = select(2, src:gsub('GetClosestAllyPos%(', ''))
    assert(n == 6,
        'GetClosestAllyPos still has its one definition and five call sites; got '
        .. n .. ' occurrences -- if a call site moved, the domain numbers above must be redone')
end

tests['REVERSE: the gate is turbo-only and has exactly one call site'] = function()
    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    local n = select(2, src:gsub('IsSoakCandidate%("defclose"%)', ''))
    assert(n == 1, 'defclose must have exactly one call site in aba_defend; got ' .. n)
    local guard = src:match('\n([^\n]*bDefClose[^\n]*=[^\n]*)\n')
    assert(guard and guard:find('IsModeTurbo', 1, true),
        'the candidate must stay turbo-gated; got: ' .. tostring(guard))
    local ts = io.open('typescript/bots/FunLib/aba_defend.ts'):read('*a')
    assert(ts:find('IsSoakCandidate("defclose")', 1, true),
        'the TS source must carry the same gate, or the next regeneration reverts it')
end

return tests
