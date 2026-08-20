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
--   {4, 5}        only pos 5 can ever win, at ANY distance; when no pos-5 hero
--                 is alive the answer is 4, also at any distance
--   {2, 3}        only pos 3; fallback 2
--   {2, 3, 4, 5}  pos 2 can never be the answer -- so ShouldDefend's under-fire
--                 gate ("only the closest of 2/3/4/5 keeps defending")
--                 disqualifies the mid outright, on top of pos 1 which is not
--                 in the list at all
--
-- The distance comparison the function exists for is therefore inert for the
-- first role of every list, and the tie-break degenerates to role number.
--
-- DOMAIN (measured, not guessed): over 2883 threatened-tower frames from six
-- turbo replays (an own tower still standing with at least one enemy hero
-- inside 1600 of it) the shipped answer differs from the true closest in
-- 35.5% of {4,5} frames, 47.4% of {2,3} frames and 20.3% of {2,3,4,5} frames.
--
-- REAL FRAME: f_260820_043637_viper_defend_token -- game 20260820_043637_slot1
-- at t=472.4 (7:52). Subject viper, Dire, role 4, level 11, FULL health,
-- standing 388u from its own 89%-hp mid tier-1 tower, which has exactly one
-- enemy (obsidian_destroyer) inside 1600. The teammate shipped hands the
-- defend token to is the role-5 crystal_maiden -- at 7% health, 6621u away on
-- the opposite side of the map. Nothing about that choice is a distance.
--
-- CONTROL FRAME: f_260820_043637_viper_defend_pos5 -- same game, same subject,
-- t=378.4, where the role-5 crystal_maiden really IS the closest (395u vs the
-- viper's 1321u). There armed must be a byte-for-byte no-op: the candidate
-- makes the comparison honest, it does not hand the token to role 4.
--
-- LIMITATION, stated rather than hidden: GetDefendLaneDesire(lane) is engine
-- state and the .dem does not carry it (same family as GH #27). The bid
-- assertions below therefore sweep it rather than pretend to know it, and say
-- at which values the mode auction changes hands.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local TOKEN = 'tests/fixtures/f_260820_043637_viper_defend_token.lua'
local POS5  = 'tests/fixtures/f_260820_043637_viper_defend_pos5.lua'

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

    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, heroes, fx, Defend
end

local function dist2d(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

--- The own tower nearest the subject that still stands.
local function nearest_own_tower(bot)
    local best, bestd = nil, math.huge
    for i = 0, 10 do
        local t = GetTower(bot:GetTeam(), i)
        if t ~= nil and t:IsAlive() then
            local d = dist2d(bot:GetLocation(), t:GetLocation())
            if d < bestd then best, bestd = t, d end
        end
    end
    return best, bestd
end

--- Bid every script mode on this frame and report the winner.
local function auction()
    local best, bestName = -1, 'none'
    local byName = {}
    local p = io.popen('ls bots/mode_*.lua')
    for path in p:lines() do
        GetDesire = nil -- luacheck: ignore
        local ok = pcall(dofile, path)
        if ok and type(GetDesire) == 'function' then
            local ok2, d = pcall(GetDesire)
            if ok2 and type(d) == 'number' then
                byName[path:match('mode_(.-)_generic') or path] = d
                if d > best then best, bestName = d, path:match('mode_(.-)_generic') or path end
            end
        end
    end
    p:close()
    return bestName, best, byName
end

-- ---------------------------------------------------------------------------
-- The frame. Every premise the defect rests on is asserted, not assumed.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: a full-hp role-4 standing on its own threatened tower'] = function()
    local J, bot, heroes, fx = world(TOKEN)
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(math.abs(fx.time - 472.4) < 1e-6, 'frame is t=472.4; got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_viper', 'subject is the viper')
    assert(J.GetPosition(bot) == 4, 'subject plays role 4; got ' .. J.GetPosition(bot))
    assert(bot:GetHealth() == bot:GetMaxHealth(),
        'subject is at FULL health -- it is not declining to defend because it is hurt')

    local tower, d = nearest_own_tower(bot)
    assert(tower ~= nil, 'the frame must carry the subject\'s own towers')
    assert(d > 380 and d < 400, 'subject is ~388u from it; got ' .. string.format('%.0f', d))
    assert(math.abs(tower:GetHealth() / tower:GetMaxHealth() - 0.892) < 0.002,
        'that tower is at 89% health, i.e. it is being chipped at right now')

    local atTower = J.GetLastSeenEnemiesNearLoc(tower:GetLocation(), 1600)
    assert(#atTower == 1, 'exactly one enemy inside 1600 of the tower; got ' .. #atTower)
    -- the list carries player ids, not handles
    local od = heroes['npc_dota_hero_obsidian_destroyer']
    assert(atTower[1] == od:GetPlayerID(),
        'and it is the obsidian_destroyer; got player id ' .. tostring(atTower[1]))

    -- ...while no enemy is inside 1600 of the SUBJECT, which is what lets the
    -- helper reach the ShouldDefend line at all (the guard above it returns
    -- VeryLow whenever ds.nInRangeEnemy is non-empty).
    assert(#J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600) == 0,
        'no enemy within 1600 of the subject, so GetDefendDesireHelper runs past '
        .. 'its in-range guard and actually consults ShouldDefend')

    local cm = heroes['npc_dota_hero_crystal_maiden']
    assert(J.GetPosition(cm) == 5, 'the crystal_maiden plays role 5')
    local dcm = dist2d(cm:GetLocation(), tower:GetLocation())
    assert(dcm > 6600 and dcm < 6650,
        'and it is 6621u from that tower; got ' .. string.format('%.0f', dcm))
    assert(cm:GetHealth() / cm:GetMaxHealth() < 0.1,
        'at 7% health -- the token holder cannot defend anything')
    assert(dcm / d > 15,
        'the role-5 is more than fifteen times further from the tower than the '
        .. 'subject, so no reading of "closest" picks it')
end

-- ---------------------------------------------------------------------------
-- The mechanism.
-- ---------------------------------------------------------------------------

tests['MECHANISM: shipped refuses the nearest hero, armed authorises it'] = function()
    local _, botS, _, _, DefS = world(TOKEN)
    local towerS = nearest_own_tower(botS)
    assert(DefS.ShouldDefend(botS, towerS, 1600) == false,
        'shipped: the only healthy hero standing on the tower is not allowed to defend it')

    local _, botA, _, _, DefA = world(TOKEN, { armed = true })
    local towerA = nearest_own_tower(botA)
    assert(DefA.ShouldDefend(botA, towerA, 1600) == true,
        'armed: once the scan covers the whole list, role 4 is the closest and is allowed')
end

tests['MECHANISM: the refusal is role arithmetic, not a distance'] = function()
    -- Both of the lists that could have authorised this hero exclude it
    -- structurally: {4,5} can only answer 5 (or 4 as a fallback when no role-5
    -- hero is alive -- and here one is, at 6621u), and the {2,3} fallback can
    -- never answer 4 at all.
    local J, bot, heroes = world(TOKEN)
    local cm = heroes['npc_dota_hero_crystal_maiden']
    assert(cm:IsAlive() and J.IsValidHero(cm),
        'a role-5 hero is alive, so the {4,5} fallback to role 4 cannot fire')
    assert(J.GetPosition(bot) == 4 and J.GetPosition(cm) == 5,
        'the two candidates are exactly roles 4 and 5')
    local roles = {}
    for i = 1, 5 do
        local m = GetTeamMember(i)
        if m ~= nil and J.IsValidHero(m) then roles[J.GetPosition(m)] = true end
    end
    assert(roles[3] == true,
        'a role-3 hero is alive too, so the {2,3} fallback answers 3 -- also not 4')
end

-- ---------------------------------------------------------------------------
-- The defect, at the final bid, driven through the real mode files.
-- ---------------------------------------------------------------------------

tests['DEFECT: the refusal pins the mid bid to VeryLow'] = function()
    local _, bot, _, _, Def = world(TOKEN, { laneBid = 0.30 })
    local mid = Def.GetDefendDesire(bot, LANE_MID)
    assert(math.abs(mid - BOT_MODE_DESIRE_VERYLOW) < 1e-9,
        'shipped mid bid is exactly VeryLow; got ' .. string.format('%.4f', mid))

    local _, botA, _, _, DefA = world(TOKEN, { armed = true, laneBid = 0.30 })
    local midA = DefA.GetDefendDesire(botA, LANE_MID)
    assert(midA > 0.45 and midA < 0.47,
        'armed the same frame bids 0.459; got ' .. string.format('%.4f', midA))
end

tests['DEFECT: the mode auction changes hands'] = function()
    local _, bot, _, _, Def = world(TOKEN, { laneBid = 0.30 })
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do Def.GetDefendDesire(bot, lane) end
    local nameS, bidS = auction()
    assert(nameS == 'laning',
        'shipped: the winner of the script auction is laning; got ' .. nameS)

    local _, botA, _, _, DefA = world(TOKEN, { armed = true, laneBid = 0.30 })
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do DefA.GetDefendDesire(botA, lane) end
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

tests['DEFECT: at higher lane urgency shipped defends the WRONG tower'] = function()
    for _, bid in ipairs({ 0.50, 0.70 }) do
        local _, bot, _, _, Def = world(TOKEN, { laneBid = bid })
        for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do Def.GetDefendDesire(bot, lane) end
        local nameS = auction()
        assert(nameS == 'defend_tower_top',
            'shipped at laneBid=' .. bid .. ': the winner is the TOP defend mode; got ' .. nameS)

        -- ...and the top tower is 8099u away with nothing near it.
        local J2, bot2 = world(TOKEN)
        local far, near2 = nil, math.huge
        for i = 0, 10 do
            local t = GetTower(bot2:GetTeam(), i)
            if t ~= nil and t:IsAlive() then
                local dd = dist2d(bot2:GetLocation(), t:GetLocation())
                if dd > 7000 and #J2.GetLastSeenEnemiesNearLoc(t:GetLocation(), 1600) == 0 then
                    far, near2 = t, dd
                end
            end
        end
        assert(far ~= nil and near2 > 7000,
            'there is such a far, unthreatened own tower on this frame')

        local _, botA, _, _, DefA = world(TOKEN, { armed = true, laneBid = bid })
        for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do DefA.GetDefendDesire(botA, lane) end
        local nameA = auction()
        assert(nameA == 'defend_tower_mid',
            'armed at laneBid=' .. bid .. ': the winner is the MID defend mode; got ' .. nameA)
    end
end

-- ---------------------------------------------------------------------------
-- Controls.
-- ---------------------------------------------------------------------------

tests['CONTROL: when the role-5 really is closest, armed is a no-op'] = function()
    local J, bot, heroes, _, Def = world(POS5)
    local tower = nearest_own_tower(bot)
    local cm = heroes['npc_dota_hero_crystal_maiden']
    local dme = dist2d(bot:GetLocation(), tower:GetLocation())
    local dcm = dist2d(cm:GetLocation(), tower:GetLocation())
    assert(J.GetPosition(bot) == 4 and J.GetPosition(cm) == 5, 'same two roles as the token frame')
    assert(dcm < dme,
        'on this frame the role-5 is genuinely nearer (' .. string.format('%.0f', dcm)
        .. ' vs ' .. string.format('%.0f', dme) .. ')')

    for _, bid in ipairs({ 0, 0.30, 0.50 }) do
        local _, b1, _, _, D1 = world(POS5, { laneBid = bid })
        local _, b2, _, _, D2 = world(POS5, { armed = true, laneBid = bid })
        for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
            local s = D1.GetDefendDesire(b1, lane)
            local a = D2.GetDefendDesire(b2, lane)
            assert(math.abs(s - a) < 1e-9,
                'armed must be byte-identical here (laneBid=' .. bid .. ', lane ' .. tostring(lane)
                .. '): ' .. string.format('%.4f vs %.4f', s, a))
        end
    end
    assert(Def ~= nil)
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
