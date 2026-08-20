-- [towerreach] "There is nothing around me" -- vetoed by a tower that cannot
-- reach the bot.
--
-- mode_retreat_generic.GetDesireHelper ends with a discount that says "nobody
-- is here, stop wanting to walk home":
--
--     if bot:DistanceFromFountain() > 4000 then
--         if (nEnemyNearbyCount == 0 and unseenCount == 0) and #nEnemyTowers == 0
--             then nDesire = nDesire - 0.25 end
--     end
--
-- The left half is calibrated: no enemy hero within 1600, and none whose
-- last-seen position is within 3200. The right half is not -- `nEnemyTowers` is
-- C.enemyTowers1200, so ANY enemy tower standing within 1200 kills the
-- discount. A tower's attack range is 700. A tower 1100 away cannot touch this
-- bot, and with no enemy hero within 3200 either there is nothing else on the
-- frame for it to be afraid of.
--
-- The file already contains the calibrated form of exactly this question.
-- buildContext computes
--     C.haveEnemyTowerThreat = (an enemy tower within 1200 whose 5s output is
--                               >= half this bot's health)
-- ...and NOTHING in the repository ever reads it (three writes, zero reads).
-- The crude test is the one that got wired to the consumer.
--
-- ARMED: the veto counts only towers that can actually reach the bot, at the
-- same 800 this file already uses elsewhere for "I am standing at an enemy
-- tower" (RetreatWhenTowerTargetedDesire's 800, ShouldRun's 898). The armed
-- veto set is a SUBSET of the shipped one, so the discount can only be applied
-- more often: the bid goes down or stays, never up. One lever.
--
-- WHY NOT GATE ON C.haveEnemyTowerThreat ITSELF, which is what the author
-- plainly meant: a tower's GetAttackDamage/GetAttackSpeed are not in the replay
-- dump, so no fixture can answer that flag truthfully and no real frame could
-- validate the change. tests/test_fixture_nearby_structures.lua pins that
-- limitation down so it fails the day the dump grows those fields.
--
-- WHAT THE BAND LOOKS LIKE. The discount is -0.25 on a bid that is a pure
-- function of health/mana on these frames (with no enemy within 3200 the whole
-- outnumbered block above is skipped). Against the 0.369 that mode_laning_
-- generic bids on an ordinary mid-game frame, armed still elects retreat below
-- roughly a fifth of effective health; between about a fifth and a half it no
-- longer abandons the map for a tower that cannot reach it.
--
-- DOMAIN (measured, not guessed). Five turbo replays from the 10:11Z soak
-- (20260820_101230/102030/102558/103216/103630, 63,350 live hero-frames):
--   * 15,563 frames are "past 4000 from my own fountain with no enemy hero
--     within 3200" -- the left half of the condition;
--   * on 695 of those an enemy tower within 1200 vetoes the discount;
--   * on 500 of THOSE (71.9%) no enemy tower is within 800, i.e. the veto comes
--     from a tower that cannot attack the bot;
--   * 28 of those 500 were sampled (spaced >= 6s apart per hero), 25 became
--     fixtures (3 refused: their game has no soak-seed attribution, GH #57) and
--     were driven through every mode file in both worlds: the retreat bid
--     changed on 23, the auction WINNER changed on 2 (8%), and no other mode's
--     bid moved on any of the 25.
--   * The 2 unchanged bids are honest structure, not noise: on those frames
--     X.ShouldRun fires and GetDesireHelper returns BOT_MODE_DESIRE_ABSOLUTE
--     * 1.1 long before the discount line is reached.
-- The fog model behind "no enemy within 3200" is the .dem's true positions, not
-- per-team vision (GH #27) -- reported as a model, as usual.
--
-- REAL FRAME: f_260820_102030_wk_tower_out_of_reach -- game 20260820_102030 at
-- t=436.0 (7:16). Wraith King (a focus hero), Dire, 284/1154 (24.6%), level 8,
-- 13,722 from its own fountain in the Radiant top jungle. No enemy hero within
-- 1600 and none in the 1600-3200 ring either. Exactly one enemy tower stands
-- within 1200, at 1090 -- outside its own 700 attack range. Shipped keeps the
-- discount off and bids 0.3836, which WINS the auction; armed bids 0.1336 and
-- mode_laning_generic's 0.369 wins instead.
-- GROUND TRUTH, recorded but NOT used as the argument: the WK stayed where it
-- was, used an item at t=438 and regenerated from 24.6% to 46% by t=468 without
-- being touched; it then moved north-east along the top lane and was killed at
-- t=480, reincarnated, and died again around t=502.
--
-- CONTROL FRAME: f_260820_102030_wk_tower_in_reach -- the SAME game and the
-- SAME hero 8.5s later (t=444.5), with the one thing that matters reversed: the
-- nearest enemy tower is at 787, inside the 800. Armed must be bit-for-bit
-- identical there. (Its shipped bid is a different number from the pin frame's
-- for an unrelated reason -- the laning-phase -0.75 applies on it and not on
-- the pin frame -- so this control proves the gate is a no-op when the tower is
-- in reach, not that the two frames are alike in every other way.)
--
-- SECOND FRAME: f_260820_103630_lina_tower_ring -- the honest half of the
-- footprint. Armed takes the same 0.25 off, and the decision does not change:
-- mode_laning_generic outbids the retreat mode in BOTH worlds. A lower bid is
-- not automatically a changed decision.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F_PIN  = 'tests/fixtures/f_260820_102030_wk_tower_out_of_reach.lua'
local F_CTRL = 'tests/fixtures/f_260820_102030_wk_tower_in_reach.lua'
local F_LINA = 'tests/fixtures/f_260820_103630_lina_tower_ring.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which makes
-- a cross-mode desire comparison a comparison of garbage (test_set.md SS F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local RETREAT = 'bots/mode_retreat_generic.lua'
local LANING  = 'bots/mode_laning_generic.lua'
local EPS = 1e-9

local function world(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end
    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == (opts.id or 'towerreach')
    end
    if opts.normal_mode then GetGameMode = function() return 1 end end -- luacheck: ignore
    -- Per-lane push/defend desire is engine state, not a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    if opts.lane_front ~= nil then
        -- GH #61: the loader never wired GetLaneFrontLocation, so every lane
        -- front sits at the map origin for both teams. Any claim about the
        -- final auction has to survive moving it, or it is a claim about the
        -- stub. MUTATION PROBE, not a reconstruction.
        GetLaneFrontLocation = function() -- luacheck: ignore
            return Vector(opts.lane_front[1], opts.lane_front[2], 0)
        end
    end
    return J, bot, heroes, fx
end

local MODE_FILES = {}
do
    local p = io.popen('ls bots/mode_*.lua')
    for line in p:lines() do MODE_FILES[#MODE_FILES + 1] = line end
    p:close()
end

--- Every mode script's bid on this frame. Files whose GetDesire cannot be
--- driven in the fixture world are RETURNED, not swallowed -- they are holes in
--- any "who won the auction" claim.
local function auction(path, opts)
    local bids, undrivable = {}, {}
    assert(#MODE_FILES >= 20, 'expected the full mode-file set; got ' .. #MODE_FILES)
    for _, f in ipairs(MODE_FILES) do
        world(path, opts)
        GetDesire, Think = nil, nil -- luacheck: ignore
        local ok, err = pcall(dofile, f)
        assert(ok, 'mode file failed to load: ' .. f .. ' -- ' .. tostring(err))
        if type(GetDesire) == 'function' then
            local ok2, d = pcall(GetDesire)
            if not ok2 then
                undrivable[#undrivable + 1] = f .. ' :: ' .. tostring(d)
            elseif type(d) == 'number' then
                bids[f] = d
            end
        end
        GetDesire, Think = nil, nil -- luacheck: ignore
    end
    return bids, undrivable
end

local function winner(bids)
    local bn, bv = nil, -math.huge
    for f, v in pairs(bids) do
        if v > bv then bn, bv = f, v end
    end
    return bn, bv
end

-- ---------------------------------------------------------------------------
-- Premises. Every number the argument uses is asserted off the frame.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: WK at 24.6%, alone, one enemy tower at 1090'] = function()
    local J, bot, heroes, fx = world(F_PIN)
    assert(J.IsModeTurbo(), 'the dump is turbo -- the gate is turbo-only')
    assert(math.abs(fx.time - 436.0) < EPS, 'pinned at t=436.0')
    assert(bot:GetUnitName() == 'npc_dota_hero_skeleton_king' and bot:GetTeam() == 3,
        'subject is the Dire wraith king')
    assert(bot:GetHealth() == 284 and bot:GetMaxHealth() == 1154, '284/1154 -- 24.6%')
    assert(bot:GetLevel() == 8, 'level 8')
    assert(bot:DistanceFromFountain() > 4000,
        'past the 4000 gate on the discount; got ' .. math.floor(bot:DistanceFromFountain()))

    local near, ring = 0, 0
    for _, u in pairs(heroes) do
        if u ~= bot and u:IsAlive() and u:GetTeam() ~= bot:GetTeam() then
            local d = GetUnitToUnitDistance(bot, u)
            if d <= 1600 then near = near + 1 elseif d <= 3200 then ring = ring + 1 end
        end
    end
    assert(near == 0, 'no enemy inside 1600; got ' .. near)
    assert(ring == 0, 'and none in the 1600-3200 ring either, so the LEFT half of '
        .. 'the condition is satisfied and only the tower veto is in play; got ' .. ring)

    local t1200 = bot:GetNearbyTowers(1200, true)
    local t800 = bot:GetNearbyTowers(800, true)
    assert(#t1200 == 1, 'exactly one live enemy tower within 1200; got ' .. #t1200)
    assert(#t800 == 0, 'and none within 800; got ' .. #t800)
    local d = GetUnitToUnitDistance(bot, t1200[1])
    assert(d > 1000 and d < 1150, 'it stands at 1090, i.e. 390 outside its own '
        .. '700 attack range; got ' .. string.format('%.1f', d))
end

tests['MECHANISM: the shipped veto counts 1, the armed veto counts 0'] = function()
    -- Driven through the same engine readers the mode file uses, so this is the
    -- arithmetic itself and not a restatement of it.
    local J, bot = world(F_PIN)
    local shippedVeto = #bot:GetNearbyTowers(1200, true)
    local armedVeto = 0
    for _, hTower in pairs(bot:GetNearbyTowers(1200, true)) do
        if J.IsValidBuilding(hTower) and GetUnitToUnitDistance(bot, hTower) <= 800 then
            armedVeto = armedVeto + 1
        end
    end
    assert(shippedVeto == 1, 'bare presence within 1200; got ' .. shippedVeto)
    assert(armedVeto == 0, 'reach within 800; got ' .. armedVeto)
end

-- ---------------------------------------------------------------------------
-- The defect at the layer test_set.md SS 8 requires: the final bid, and the
-- auction it is decided in.
-- ---------------------------------------------------------------------------

tests['DEFECT: shipped bids 0.384 and wins; armed bids 0.134 and laning wins'] = function()
    local shipped, undrivable = auction(F_PIN)
    local armed = auction(F_PIN, { armed = true })

    -- The holes in this reconstruction, named rather than swallowed: two mode
    -- files cannot be driven on ANY fixture because the mock has no
    -- GetRuneSpawnLocation / GetCourierState. Their bids are UNKNOWN in both
    -- worlds -- and identical in both, since this candidate does not touch
    -- them -- so the claim below is "of the mode files that can be driven".
    -- (Engine-owned modes are a further hole: a .dem carries no mode, GH #27.)
    assert(#undrivable == 2, 'exactly two undrivable mode files expected; got '
        .. #undrivable .. ' -- ' .. table.concat(undrivable, ' | '))
    local joined = table.concat(undrivable, ' | ')
    assert(joined:find('mode_rune_generic', 1, true)
       and joined:find('GetRuneSpawnLocation', 1, true),
        'the rune mode, for the missing rune-spawn reader; got ' .. joined)
    assert(joined:find('mode_secret_shop_generic', 1, true)
       and joined:find('GetCourierState', 1, true),
        'and the secret-shop mode, for the missing courier-state reader; got ' .. joined)

    assert(math.abs(shipped[RETREAT] - 0.38355423556998) < 1e-11,
        'shipped retreat bid; got ' .. tostring(shipped[RETREAT]))
    assert(math.abs(armed[RETREAT] - 0.13355423556998) < 1e-11,
        'armed retreat bid; got ' .. tostring(armed[RETREAT]))
    assert(math.abs((shipped[RETREAT] - armed[RETREAT]) - 0.25) < 1e-11,
        'the whole difference is the one discount, applied once')

    local sn, sv = winner(shipped)
    local an, av = winner(armed)
    assert(sn == RETREAT and math.abs(sv - 0.38355423556998) < 1e-11,
        'shipped: the retreat mode wins the frame; got ' .. tostring(sn))
    assert(an == LANING and math.abs(av - 0.369) < 1e-11,
        'armed: mode_laning_generic 0.369 wins instead; got ' .. tostring(an)
        .. ' ' .. tostring(av))

    -- Nothing else moved: this candidate touches one branch of one mode.
    for f, v in pairs(shipped) do
        if f ~= RETREAT then
            assert(math.abs((armed[f] or v) - v) < EPS,
                f .. ' changed too, so the footprint is wider than claimed')
        end
    end
end

tests['MONOTONE: armed can only lower the bid, never raise it'] = function()
    for _, path in ipairs({ F_PIN, F_CTRL, F_LINA }) do
        local shipped = auction(path)
        local armed = auction(path, { armed = true })
        assert(armed[RETREAT] <= shipped[RETREAT] + EPS,
            'the armed veto set is a subset of the shipped one, so the discount '
            .. 'can only be applied more often; ' .. path .. ' went UP')
    end
end

tests['MUTATION PROBE is live: it moves a bid on a frame that reads the front'] = function()
    -- Before claiming "nothing here depends on the lane front", show the probe
    -- can move something at all. The GH #65 frame is known to be sensitive: its
    -- top-lane defend bid holds 0.1275 against the origin stub.
    local F_SENS = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
    local TOP = 'bots/mode_defend_tower_top_generic.lua'
    local baseline = auction(F_SENS)[TOP]
    assert(math.abs(baseline - 0.12750881244548) < 1e-9,
        'the origin-stub value of that bid; got ' .. tostring(baseline))
    local moved = auction(F_SENS, { lane_front = { 3000, 3000 } })[TOP]
    assert(math.abs(moved - baseline) > 1e-6,
        'the probe must actually move it, or every "nothing moved" below is '
        .. 'evidence about the probe rather than about the frame; got '
        .. tostring(moved))
end

tests['the flip is NOT riding on the stubbed lane front (GH #61)'] = function()
    -- On THIS frame the stronger statement holds: with the lane front moved to
    -- three different non-origin places, NO mode bid moves at all, in either
    -- world. The whole auction here is lane-front-independent, so the winner
    -- flip cannot be an artefact of the origin stub.
    local base_shipped = auction(F_PIN)
    local base_armed = auction(F_PIN, { armed = true })
    for _, lf in ipairs({ { 3000, 3000 }, { -4000, 2000 }, { 6000, -6000 } }) do
        local shipped = auction(F_PIN, { lane_front = lf })
        local armed = auction(F_PIN, { armed = true, lane_front = lf })
        for f, v in pairs(base_shipped) do
            assert(math.abs((shipped[f] or v) - v) < 1e-9,
                f .. ' moved under the lane-front probe at (' .. lf[1] .. ','
                .. lf[2] .. '), so this frame is NOT front-independent after all')
            assert(math.abs((armed[f] or base_armed[f]) - base_armed[f]) < 1e-9,
                f .. ' moved in the ARMED world under the same probe')
        end
        assert(winner(shipped) == RETREAT, 'shipped still elects retreat')
        assert(winner(armed) == LANING, 'and armed still elects laning')
    end
end

-- ---------------------------------------------------------------------------
-- Controls.
-- ---------------------------------------------------------------------------

tests['CONTROL FRAME: the tower IS in reach -> armed is bit-identical'] = function()
    local _, bot, heroes, fx = world(F_CTRL)
    assert(math.abs(fx.time - 444.5) < EPS, 'same game, same hero, 8.5s later')
    assert(bot:GetUnitName() == 'npc_dota_hero_skeleton_king', 'same wraith king')
    local t800 = bot:GetNearbyTowers(800, true)
    assert(#t800 == 1, 'now a live enemy tower IS within 800; got ' .. #t800)
    local d = GetUnitToUnitDistance(bot, t800[1])
    assert(d > 750 and d < 800, 'at 787; got ' .. string.format('%.1f', d))
    local near = 0
    for _, u in pairs(heroes) do
        if u ~= bot and u:IsAlive() and u:GetTeam() ~= bot:GetTeam()
            and GetUnitToUnitDistance(bot, u) <= 3200 then near = near + 1 end
    end
    assert(near == 0, 'still nobody within 3200, so the discount line is reached '
        .. 'here too and the veto is the only thing deciding it; got ' .. near)

    local shipped = auction(F_CTRL)
    local armed = auction(F_CTRL, { armed = true })
    for f, v in pairs(shipped) do
        assert(math.abs((armed[f] or v) - v) < EPS,
            'no bid may move on this frame; ' .. f .. ' did')
    end
    assert(math.abs(shipped[RETREAT] - (-0.40150537288585)) < 1e-11,
        'and the retreat bid is the same number in both worlds; got '
        .. tostring(shipped[RETREAT]))
end

tests['SECOND FRAME: the bid drops 0.25 and the decision does not change'] = function()
    local shipped = auction(F_LINA)
    local armed = auction(F_LINA, { armed = true })
    assert(math.abs(shipped[RETREAT] - (-0.32984840029630)) < 1e-11,
        'shipped lina retreat bid; got ' .. tostring(shipped[RETREAT]))
    assert(math.abs(armed[RETREAT] - (-0.57984840029630)) < 1e-11,
        'armed lina retreat bid; got ' .. tostring(armed[RETREAT]))
    assert(winner(shipped) == LANING and winner(armed) == LANING,
        'laning wins in BOTH worlds -- the retreat mode was never going to win '
        .. 'this frame. Lower bid /= changed decision.')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    local shipped = auction(F_PIN, { normal_mode = true })
    local armed = auction(F_PIN, { armed = true, normal_mode = true })
    assert(math.abs(armed[RETREAT] - shipped[RETREAT]) < EPS,
        'the gate is turbo-only; got ' .. tostring(armed[RETREAT]))
    -- ...and both hold the SHIPPED number, not the armed one: a gate that
    -- ignored the mode check would keep the two sides equal while quietly
    -- moving the value.
    assert(math.abs(shipped[RETREAT] - 0.38355423556998) < 1e-11,
        'outside turbo the bid must still be the shipped one; got '
        .. tostring(shipped[RETREAT]))
end

tests['OFF: another candidate id does not arm this one'] = function()
    local shipped = auction(F_PIN)
    local other = auction(F_PIN, { armed = true, id = 'retnear' })
    assert(math.abs(other[RETREAT] - shipped[RETREAT]) < EPS,
        'arming retnear must leave this alone; got ' .. tostring(other[RETREAT]))
    assert(math.abs(other[RETREAT] - 0.38355423556998) < 1e-11,
        'and the value both sides hold is the SHIPPED one -- this is what an '
        .. 'always-open gate fails; got ' .. tostring(other[RETREAT]))
end

-- ---------------------------------------------------------------------------
-- Source-level reverse assertions: they fail if the shape of the fix changes.
-- ---------------------------------------------------------------------------

tests['REVERSE: the LEFT half of the condition is untouched'] = function()
    local src = io.open('bots/mode_retreat_generic.lua'):read('*a')
    assert(src:find('nEnemyNearbyCount == 0 and unseenCount == 0', 1, true),
        'the hero half of the discount must stay exactly as shipped -- if it '
        .. 'moves too, this candidate is no longer one lever')
    assert(src:find('bot:DistanceFromFountain() > 4000', 1, true),
        'and so must the 4000 gate around it')
end

tests['REVERSE: the calibrated tower-threat flag is still computed and unread'] = function()
    local src = io.open('bots/mode_retreat_generic.lua'):read('*a')
    -- Comment lines are stripped first: this file's own commentary names the
    -- flag, and the claim is about CODE.
    local code = {}
    for line in src:gmatch('[^\n]*') do
        if not line:match('^%s*%-%-') then code[#code + 1] = line end
    end
    code = table.concat(code, '\n')
    local writes = 0
    for _ in code:gmatch('haveEnemyTowerThreat') do writes = writes + 1 end
    assert(writes == 3, 'C.haveEnemyTowerThreat still appears exactly three times '
        .. '(declaration, reset, set) and never on the right-hand side of '
        .. 'anything -- that dead flag is the evidence that the author meant a '
        .. 'CALIBRATED tower test here. If someone wires it up, re-derive this '
        .. 'candidate against the new consumer; got ' .. writes)
    assert(src:find('towerDamage / botHealth >= 0.5', 1, true),
        'and the calibration it encodes is still "half my health in 5 seconds"')
end

return tests
