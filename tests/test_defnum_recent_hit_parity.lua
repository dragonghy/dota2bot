-- [defnum] "Are we outnumbered here?" is asked about a list that is provably
-- empty at the point the question is asked.
--
-- GetDefendDesireHelper writes, near its top:
--
--     ds.nInRangeEnemy = jmz.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600)
--     if #ds.nInRangeEnemy > 0 or ... then return BotModeDesire.VeryLow end
--
-- so EVERY line below that point runs only when the list is empty. Three
-- consumers read it anyway, as if it varied:
--
--   line 1139  #ds.nInRangeEnemy >  #ds.nInRangeAlly   -- `0 > n`: dead code
--   line 1196  #ds.nInRangeEnemy >= #ds.nInRangeAlly   -- `0 >= n`: "am I alone"
--   line 1418  #ds.nInRangeAlly  >= #ds.nInRangeEnemy  -- `n >= 0`: a tautology
--              (in DefendThink, whose ds carries whatever the last helper call
--              left; a bid that came from below the early return leaves it
--              empty, so the veto there is near-dead too)
--
-- and a fourth, the already-gated [defstale] guard in DefendThink, whose
-- `#pathEnemies > #ds.nInRangeEnemy` therefore reduces to `#pathEnemies > 0`
-- -- stronger than the staleness argument written on it (see GH #55).
--
-- This candidate touches ONE of them: the `recentlyHit` cap at 1196. Written,
-- it means "cut me to Low when as many enemies as allies are on me and we are
-- not stronger". Read, it means "cut me to Low when I have no ally within
-- 1600" -- and no enemy is within 1600 of the bot at all when it fires.
--
-- WHY REMOVAL AND NOT A REWRITE. Re-pointing the comparison at the hub-centred
-- counts the function already computed (#lEnemies / nEffAllies, lines
-- 1111/1113) was implemented and measured first: over the six turbo replays it
-- fires on 541 of 549 in-domain frames where the shipped reading fires on 308,
-- i.e. it would turn an accident into a systematically more defeatist rule
-- (give the building away whenever two enemies stand near it). Rejected. The
-- candidate removes the cap and leaves the *0.4 decay two lines above to damp
-- proportionally.
--
-- DOMAIN (measured, not guessed). Over the six turbo replays, counting
-- (frame, lane) rows that actually reach this branch -- subject alive and
-- level >= 3, damaged by a hero or tower inside the last 5s, no enemy within
-- 1600 of the subject, and at least two enemies within 2500 of its own
-- furthest standing building on that lane -- there are 549 rows. The shipped
-- guard fires on 308 of them (56.1%). It only *binds*, though, when the
-- pre-decay desire exceeds 0.625, which after the health remap means a
-- near-full-health bot on a lane the engine wants defended hard.
--
-- REAL FRAME: f_260820_043120_viper_defend_poked -- game 20260820_043120_slot1
-- at t=398.5 (6:38). Subject viper, Radiant, 92.4% health, level 11, damaged
-- by ember_spirit 0.7s earlier, with NO enemy inside 1600 of it and NO ally
-- inside 1600 either, while three enemy heroes stand inside 1200 of its own
-- still-standing top tier-1 tower. Shipped: `0 >= 0` is true, so the desire is
-- capped at Low. Armed: it is not.
--
-- CONTROL FRAME: f_260820_043120_viper_defend_paired -- same game, same hero,
-- t=599.5, the one difference that matters being an ally inside 1600. There
-- `0 >= 1` is false, the cap never applied, and armed must be byte-for-byte
-- identical.
--
-- SECOND FRAME: f_260820_043524_wd_defend_alone -- a 97.8%-health witch_doctor
-- 981u from its own 24%-health mid tier-1 tower, alone, poked
-- 1.5s earlier. Kept because it is the honest half of the footprint: the guard
-- is reached, the cap is applied, arming moves the bid -- and the bid is still
-- far too small to win anything. A candidate that changes a number is not yet
-- a candidate that changes a decision.
--
-- LIMITATION, ASSERTED RATHER THAN HIDDEN (see the last test in this file).
-- The final-bid layer that test_set.md requires for a branch like this CANNOT
-- honestly be reconstructed on today's fixtures: the loader does not answer
-- GetLaneFrontLocation, so the bare mock's stub applies and every lane front,
-- for both teams and all three lanes, is the map ORIGIN. That makes
-- `ds.defendLoc` the middle of the river and `ds.distanceToLane[lane]` the
-- bot's distance to the river -- the same number for all three lanes -- which
-- in turn decides the `dist > 4000` damping at line 1156 and the early return
-- at line 1102. The three sampled frames where arming did flip the mode
-- auction (laning -> defend_tower_*) were all frames where the bot was 7-8k
-- from the tower in question but only ~2k from the river, i.e. the flip rides
-- on the stub. So this file asserts the mechanism and the desire layer, and
-- asserts the stub itself, so that the day the lane front becomes real this
-- test fails loudly and these conclusions get re-read. 125 call sites across
-- bots/ read that function; the gap is filed separately.

package.path = 'tests/?.lua;' .. package.path

local POKED  = 'tests/fixtures/f_260820_043120_viper_defend_poked.lua'
local PAIRED = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'
local WD     = 'tests/fixtures/f_260820_043524_wd_defend_alone.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- arithmetic on the desire constants (same reason as
-- tests/test_defclose_defender_arbitration.lua).
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

local SWEEP = { 0, 0.3, 0.5, 0.7, 0.9, 1.0 }

--- Load a real frame with the real aba_defend on top of it.
---   opts.armed   -- arm 'defnum'
---   opts.armId   -- arm some OTHER id instead (attribution control)
---   opts.turbo   -- false makes J.IsModeTurbo() report a non-turbo game
---   opts.laneBid -- what the engine's per-lane defend desire reports
local function world(path, opts)
    opts = opts or {}
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    local rf = require('mock.replay_fixture')
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end

    local want = opts.armId or 'defnum'
    J.IsSoakCandidate = function(id)
        return id == want and (opts.armed == true or opts.armId ~= nil)
    end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end

    local bid = opts.laneBid or 0
    GetPushLaneDesire = function() return 0 end     -- luacheck: ignore
    GetDefendLaneDesire = function() return bid end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, heroes, fx, Defend
end

local function dist2d(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

--- Every lane's defend desire on this frame, in lane order.
local function lane_bids(Defend, bot)
    local out = {}
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        out[#out + 1] = Defend.GetDefendDesire(bot, lane)
    end
    return out
end

--- Shipped vs armed lane bids at one engine lane-desire value.
local function both(path, bid, opts)
    opts = opts or {}
    local _, b1, _, _, D1 = world(path, { laneBid = bid, turbo = opts.turbo })
    local shipped = lane_bids(D1, b1)
    local _, b2, _, _, D2 = world(path, { laneBid = bid, armed = true,
                                          turbo = opts.turbo, armId = opts.armId })
    local armed = lane_bids(D2, b2)
    return shipped, armed
end

local tests = {}

-- ---------------------------------------------------------------------------
-- The frame. Every premise the defect rests on is asserted, not assumed.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: poked, alone, no enemy within 1600, own tower under three'] = function()
    local J, bot, _, fx, Defend = world(POKED, { laneBid = 1.0 })
    assert(J.IsModeTurbo(), 'the dump is turbo; the candidate is turbo-only')
    assert(math.abs(fx.time - 398.5) < 1e-6, 'frame is t=398.5; got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_viper', 'subject is the viper')
    assert(fx.roles ~= nil,
        'the fixture must carry DRAFTED roles -- without them GetPosition falls back '
        .. 'to the draft slot, which GH #57 measured at 47.3% accurate')

    local hp = bot:GetHealth() / bot:GetMaxHealth()
    assert(hp > 0.92 and hp < 0.93,
        'subject is at 92.4% health -- high enough that the health remap does not '
        .. 'already floor the desire below the cap; got ' .. string.format('%.3f', hp))

    -- The branch is gated on recentlyHit, which is a real read now that
    -- fixtures carry an incoming-damage history (state.json
    -- fixture_recent_damage_20260820).
    assert(bot:WasRecentlyDamagedByAnyHero(5),
        'the recentlyHit precondition must hold on the real frame')

    -- ...and the two counts the guard compares.
    assert(#J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600) == 0,
        'no enemy within 1600 of the subject -- which is exactly why the helper '
        .. 'gets past its in-range early return and reaches this branch at all')
    assert(#J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) == 0,
        'and no ally within 1600 either, so `0 >= 0` makes the shipped guard true')

    -- There is a real defence to be made: the subject's own top tier-1 is
    -- standing with three enemy heroes inside 1200 of it.
    local res = Defend.GetFurthestBuildingOnLane(LANE_TOP)
    local bld = res[1]
    assert(bld ~= nil and bld:IsAlive(), 'own furthest top building is standing')
    assert(#J.GetLastSeenEnemiesNearLoc(bld:GetLocation(), 1200) == 3,
        'three enemy heroes are inside 1200 of it')
    local d = dist2d(bot:GetLocation(), bld:GetLocation())
    assert(d > 8000 and d < 8200,
        'the subject is ~8084u away from it -- recorded because it is the reason '
        .. 'the auction-level claim is withheld; got ' .. string.format('%.0f', d))
end

-- ---------------------------------------------------------------------------
-- The mechanism: one side of the comparison is structurally empty.
-- ---------------------------------------------------------------------------

tests['MECHANISM: ds.nInRangeEnemy is empty on every lane below the early return'] = function()
    for _, path in ipairs({ POKED, PAIRED, WD }) do
        local _, bot, _, _, Defend = world(path, { laneBid = 1.0 })
        lane_bids(Defend, bot)
        local ds = rawget(bot, '_defend')
        assert(ds ~= nil, 'the helper ran and built its per-bot state')
        assert(#ds.nInRangeEnemy == 0,
            path .. ': the list the guard compares against is empty -- the early '
            .. 'return above guarantees it, so `0 >= #nInRangeAlly` is what the '
            .. 'branch really asks; got ' .. #ds.nInRangeEnemy)
    end
end

tests['MECHANISM: the guard therefore tracks "am I alone", nothing else'] = function()
    -- Pinned frame: no ally in 1600 -> guard true.  Control frame: one ally
    -- in 1600 -> guard false.  Same code, same helper, opposite answers, and
    -- the enemy count played no part in either.
    local J1, b1, _, _, D1 = world(POKED, { laneBid = 1.0 })
    lane_bids(D1, b1)
    local ds1 = rawget(b1, '_defend')
    assert(#ds1.nInRangeAlly == 0, 'pinned frame: no ally within 1600')
    assert(#ds1.nInRangeEnemy >= #ds1.nInRangeAlly, 'so the shipped guard is TRUE')
    assert(#J1.GetLastSeenEnemiesNearLoc(b1:GetLocation(), 1600) == 0,
        'while no enemy is anywhere near -- the opposite of what it claims to test')

    local _, b2, _, _, D2 = world(PAIRED, { laneBid = 1.0 })
    lane_bids(D2, b2)
    local ds2 = rawget(b2, '_defend')
    assert(#ds2.nInRangeAlly == 1, 'control frame: exactly one ally within 1600')
    assert(not (#ds2.nInRangeEnemy >= #ds2.nInRangeAlly), 'so the shipped guard is FALSE')
end

-- ---------------------------------------------------------------------------
-- Effect. Desire layer only -- see the limitation test at the bottom.
-- ---------------------------------------------------------------------------

tests['EFFECT: armed never lowers a bid, and raises the pinned frame'] = function()
    local raised = false
    for _, bid in ipairs(SWEEP) do
        local shipped, armed = both(POKED, bid)
        for i = 1, 3 do
            assert(armed[i] >= shipped[i] - 1e-9,
                string.format('the candidate only removes a cap, so no bid may fall '
                    .. '(bid=%.2f lane#%d: %.4f -> %.4f)', bid, i, shipped[i], armed[i]))
            if armed[i] > shipped[i] + 1e-9 then raised = true end
        end
    end
    assert(raised, 'and on this frame it must actually raise one, or the fixture is '
        .. 'not witnessing the defect')
end

tests['EFFECT: the cap it removes is exactly BotActionDesire.Low'] = function()
    -- At the top of the sweep the shipped bid sits ON the cap while the armed
    -- one is above it: that is the removal, not some other arithmetic.
    local shipped, armed = both(POKED, 1.0)
    local pinned = false
    for i = 1, 3 do
        if math.abs(shipped[i] - 0.25) < 1e-9 and armed[i] > 0.25 + 1e-9 then
            pinned = true
        end
    end
    assert(pinned,
        'at the engine lane-desire ceiling some lane must sit exactly at Low (0.25) '
        .. 'shipped and above it armed')
end

tests['SECOND FRAME: the bid moves there too, and stays small'] = function()
    local moved, biggest = false, 0
    for _, bid in ipairs(SWEEP) do
        local shipped, armed = both(WD, bid)
        for i = 1, 3 do
            assert(armed[i] >= shipped[i] - 1e-9, 'still monotone on this frame')
            if armed[i] > shipped[i] + 1e-9 then moved = true end
            if armed[i] > biggest then biggest = armed[i] end
        end
    end
    assert(moved, 'the guard is reached and binds on this frame too')
    -- Recorded as a fact about the footprint, not as an approval: the *0.4
    -- decay two lines above caps this whole branch at 0.4, so no bid leaving
    -- it can beat a laning bid of 0.446, let alone a retreat bid.
    assert(biggest < 0.4 + 1e-9,
        'every bid out of the recentlyHit branch is <= 0.4 by construction; got '
        .. string.format('%.4f', biggest))
end

-- ---------------------------------------------------------------------------
-- Controls. Each one must be a byte-for-byte no-op.
-- ---------------------------------------------------------------------------

tests['CONTROL frame: with an ally within 1600, armed changes nothing'] = function()
    for _, bid in ipairs(SWEEP) do
        local shipped, armed = both(PAIRED, bid)
        for i = 1, 3 do
            assert(math.abs(armed[i] - shipped[i]) < 1e-12,
                string.format('the cap never applied here, so arming must be a no-op '
                    .. '(bid=%.2f lane#%d: %.4f vs %.4f)', bid, i, shipped[i], armed[i]))
        end
    end
end

tests['CONTROL non-turbo: the candidate is inert outside turbo'] = function()
    for _, bid in ipairs(SWEEP) do
        local shipped, armed = both(POKED, bid, { turbo = false })
        for i = 1, 3 do
            assert(math.abs(armed[i] - shipped[i]) < 1e-12,
                string.format('non-turbo must be untouched (bid=%.2f lane#%d)', bid, i))
        end
    end
end

tests['CONTROL id isolation: arming a different id changes nothing'] = function()
    for _, bid in ipairs(SWEEP) do
        local shipped, armed = both(POKED, bid, { armId = 'defstale' })
        for i = 1, 3 do
            assert(math.abs(armed[i] - shipped[i]) < 1e-12,
                string.format('only defnum may reach this branch (bid=%.2f lane#%d)',
                    bid, i))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Reverse assertions: pin the shipped source, so a refactor cannot quietly
-- change what this file claims to be describing.
-- ---------------------------------------------------------------------------

tests['[reverse] the shipped guard and its early return are still where claimed'] = function()
    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    assert(src:find('#ds.nInRangeEnemy > 0 or', 1, true) ~= nil,
        'the early return that pins the left-hand side to zero must still exist -- '
        .. 'without it every claim in this file changes')
    assert(src:find('bParityCap and #ds.nInRangeEnemy >= #ds.nInRangeAlly', 1, true) ~= nil,
        'the gated cap must still read the pinned list; if it were re-pointed at a '
        .. 'live query this file is describing the wrong branch')
    assert(src:find('jmz.IsSoakCandidate("defnum")', 1, true) ~= nil,
        'and it must still be behind the defnum gate')
    -- The rewrite that was measured and rejected must NOT have crept in.
    assert(src:find('#lEnemies >= nEffAllies', 1, true) == nil,
        'the hub-centred rewrite was rejected (541/549 vs 308/549) -- it must not be '
        .. 'in the tree')
end

-- ---------------------------------------------------------------------------
-- The limitation, asserted. When this test starts failing, the auction-level
-- question this candidate could not answer has become answerable.
-- ---------------------------------------------------------------------------

tests['[limitation] the loader still answers every lane front with the map origin'] = function()
    local _, bot, _, _, Defend = world(POKED, { laneBid = 1.0 })
    for _, team in ipairs({ bot:GetTeam(), GetOpposingTeam() }) do
        for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
            local f = GetLaneFrontLocation(team, lane, 0)
            assert(math.abs(f.x) < 1e-9 and math.abs(f.y) < 1e-9,
                'lane fronts are still stubbed to (0,0). If this fails the stub has '
                .. 'been fixed -- re-read the footprint claims in this file and in '
                .. 'the report, because ds.distanceToLane now means something')
        end
    end
    lane_bids(Defend, bot)
    local ds = rawget(bot, '_defend')
    assert(math.abs(ds.defendLoc.x) < 1e-9 and math.abs(ds.defendLoc.y) < 1e-9,
        'so ds.defendLoc is the middle of the river, on every lane, for both teams')
    assert(math.abs(ds.distanceToLane[LANE_TOP] - ds.distanceToLane[LANE_MID]) < 1e-9
       and math.abs(ds.distanceToLane[LANE_MID] - ds.distanceToLane[LANE_BOT]) < 1e-9,
        'and "how far am I from this lane" cannot tell the three lanes apart -- which '
        .. 'is what decides the dist > 4000 damping this branch feeds into')
end

return tests
