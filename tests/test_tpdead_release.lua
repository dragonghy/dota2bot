-- [GH #37 20260819] tpdead: drop the landing commitment once the ally the
-- rescue was FOR is already dead.
--
-- The replay desk tracked 11 real `lf_rescue` casts: exactly ONE arrived inside
-- the ~4s window J.WillAllySurviveTpWindow models, and the landing point ran a
-- median 2289 units from the ally. So the ordinary outcome is: the responder
-- lands at a tower, the ally dies mid-trip, and J.GetTpCommitDefendDesire then
-- pins the responder in DEFEND at 0.85 for the remainder of the 12s commitment
-- -- walking at a fight that is already over.
--
-- Why THIS lever and not the two the director listed first: both of those were
-- falsified on this very triple.
--   * candidate 1 (a ceiling on the landing distance) -- the frame that must be
--     REJECTED lands closer (1579) than the frame that must be ALLOWED (1746),
--     so no ceiling separates them (pinned in test_lf_rescue_landing_reach).
--   * candidate 2 (feed the walk time back into the survival window) -- with the
--     arrival window the ground-truth damage on the ALLOWED frame already
--     covers Axe's health (258 >= 246 by 8.8s; he lived on regen the gate does
--     not model), so widening the window vetoes the one rescue that worked.
--     Also pinned there, off the new observed.damage timeline.
-- What is left is the half that needs no estimate at all: the ally is dead, or
-- it is not. DEATH events are exact replay ground truth.
--
-- Every number below is a frame fact from the same three games, taken 6.0s after
-- each cast -- i.e. the responder has landed (3s channel) and is inside its 12s
-- commitment. Only the two stamps the item-usage wiring writes at cast time are
-- supplied by the test, and the lane front is placed on the trigger (the dump
-- carries no creep positions, so the engine's lane front cannot be
-- reconstructed; it only makes the floor REACHABLE and is identical in every
-- arm, so it cannot be what separates them).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FLOOR = 0.85    -- J.GetTpCommitDefendDesire's landing floor
local COMMIT = 12.0   -- the commitment window stamped at cast time

-- The acceptance triple (director, GH #37), 6.0s after each cast.
local FRAMES = {
    {
        -- 20260819_123012_slot1. Death Prophet (pos 3) rescued Dragon Knight at
        -- t=568.4 from 13786 units away; DK died 4.7s later, 5623 units from
        -- where the TP put her.
        name = 'A corpse', cast = 568.4, ally_alive = false,
        path = 'tests/fixtures/f_260819_123012_dp_landed_dead.lua',
        ally = 'npc_dota_hero_dragon_knight',
    },
    {
        -- 20260819_122930_slot1. Lina rescued Lich at t=201.3; Lich died 2.9s
        -- later -- before the 3s channel even finished.
        name = 'B corpse', cast = 201.3, ally_alive = false,
        path = 'tests/fixtures/f_260819_122930_lina_landed_dead.lua',
        ally = 'npc_dota_hero_lich',
    },
    {
        -- 20260819_123546_slot1. Jakiro rescued Axe at t=145.4 and ARRIVED --
        -- the one rescue in the wave that worked. Axe lives another 151.2s.
        -- This commitment must come through untouched.
        name = 'C alive', cast = 145.4, ally_alive = true,
        path = 'tests/fixtures/f_260819_123546_jakiro_landed_ok.lua',
        ally = 'npc_dota_hero_axe',
    },
}

--- Rebuild the frame with the subject in the state the rescue branch of
--- ability_item_usage_generic.lua leaves it in at cast time. `ids` is the armed
--- soak set.
local function landed(f, ids)
    local J, bot, heroes, fx = rf.load(f.path)
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    local ally = heroes[f.ally]
    bot.tpRespondLoc = ally:GetLocation()
    bot.tpRespondUntil = f.cast + COMMIT
    bot.tpRespondAlly = ally
    GetLaneFrontLocation = function() return ally:GetLocation() end -- luacheck: ignore
    return J, bot, ally, fx
end

--- The real mode file's GetDesire(), i.e. the bid the engine actually ranks.
local function defend_bid()
    dofile(GetScriptDirectory() .. '/mode_defend_tower_mid_generic.lua')
    return GetDesire()
end

-- ---- the frame facts every assertion below rests on --------------------------

tests['[frame] each frame really is a landed responder inside its commitment'] = function()
    for _, f in ipairs(FRAMES) do
        local J, bot, ally, fx = landed(f, { 'tpcommit' })
        assert(math.abs(fx.time - (f.cast + 6.0)) < 0.05,
            f.name .. ': the frame must be 6.0s after the cast (3s channel + '
            .. 'landed), got t=' .. tostring(fx.time))
        assert(DotaTime() < bot.tpRespondUntil,
            f.name .. ': still inside the 12s commitment window')
        assert(bot:IsAlive(), f.name .. ': the responder survived the trip')
        -- Neither shipped release may fire, or the frame would not isolate the
        -- one under test.
        assert(J.GetHP(bot) > 0.40,
            f.name .. ': the numeric release clause must be silent, HP is '
            .. string.format('%.2f', J.GetHP(bot)))
        assert(J.ShouldRetreatLaneBurst(bot) == false,
            f.name .. ': the anticipatory release clause must be silent too')
        assert(#J.GetEnemiesNearLoc(bot.tpRespondLoc, 1600) >= 1,
            f.name .. ': someone is still visible at the trigger, so the floor '
            .. 'is not skipped for lack of a target')
        -- ...and the one thing that DOES differ: exact DEATH-event ground truth.
        assert(ally:IsAlive() == f.ally_alive,
            f.name .. ': ally alive should be ' .. tostring(f.ally_alive))
    end
end

tests['[frame] the responder is nowhere near the ally it answered for'] = function()
    -- The mechanism, in one number: this is the distance the pin would spend
    -- the rest of the commitment walking.
    local f = FRAMES[1]
    local _, bot, ally = landed(f, { 'tpcommit' })
    local nGap = GetUnitToLocationDistance(bot, ally:GetLocation())
    assert(nGap > 5000,
        'A: the responder landed ' .. string.format('%.0f', nGap)
        .. ' units from the ally it came for; expected over 5000')
end

-- ---- the defect: shipped pins the responder to two corpses -------------------

tests['[final bid] shipped tpcommit holds the pin on all three, corpses included'] = function()
    for _, f in ipairs(FRAMES) do
        landed(f, { 'tpcommit' })
        local nBid = defend_bid()
        assert(nBid == FLOOR,
            f.name .. ': expected the real defend mode to bid the ' .. FLOOR
            .. ' floor, got ' .. tostring(nBid))
    end
end

tests['[final bid] without tpcommit the same frames bid far below the floor'] = function()
    -- So the 0.85 above really is the pin and not the lane's own defend term.
    for _, f in ipairs(FRAMES) do
        landed(f, {})
        local nBid = defend_bid()
        assert(nBid < FLOOR,
            f.name .. ': shipped defend term should be under the floor, got '
            .. tostring(nBid))
    end
end

-- ---- the fix: the triple separates on the ally, and only on the ally ---------

tests['[final bid] armed tpdead drops both corpse pins and keeps the live one'] = function()
    for _, f in ipairs(FRAMES) do
        landed(f, { 'tpcommit', 'tpdead' })
        local nBid = defend_bid()
        if f.ally_alive then
            assert(nBid == FLOOR,
                f.name .. ': the rescue that WORKED must keep its commitment, '
                .. 'got ' .. tostring(nBid))
        else
            assert(nBid < FLOOR,
                f.name .. ': the ally is a corpse, the pin must go, got '
                .. tostring(nBid))
        end
    end
end

tests['[state] the release clears the stamp, so it cannot come back next frame'] = function()
    for _, f in ipairs(FRAMES) do
        local J, bot = landed(f, { 'tpcommit', 'tpdead' })
        J.GetTpCommitDefendDesire(bot, 2)
        if f.ally_alive then
            assert(bot.tpRespondUntil ~= nil and bot.tpRespondAlly ~= nil,
                f.name .. ': a live rescue keeps its stamps')
        else
            assert(bot.tpRespondUntil == nil and bot.tpRespondAlly == nil,
                f.name .. ': a finished rescue must drop both stamps')
        end
    end
end

-- ---- separability: what the candidate can and cannot touch -------------------

tests['[separability] tpdead alone, without tpcommit, changes nothing'] = function()
    -- The release sits under the tpcommit gate, so the id is a no-op on its own
    -- -- the same scheduling note tpdying carries: never bisect it by itself.
    for _, f in ipairs(FRAMES) do
        landed(f, { 'tpdead' })
        local nBid = defend_bid()
        landed(f, {})
        assert(nBid == defend_bid(),
            f.name .. ': tpdead without tpcommit must be bit-identical to '
            .. 'shipped')
    end
end

tests['[separability] a non-rescue commitment is untouched by a dead ally'] = function()
    -- The stamp is the discriminator, not "is anyone on my team dead". The two
    -- other response TPs (mid tower fight, defend TP) answer a PLACE, clear
    -- tpRespondAlly, and must keep their pin with a corpse in the frame.
    local f = FRAMES[1]
    local J, bot, ally = landed(f, { 'tpcommit', 'tpdead' })
    assert(ally:IsAlive() == false, 'this frame does contain the corpse')
    bot.tpRespondAlly = nil          -- what a tower-fight / defend TP stamps
    assert(J.GetTpCommitDefendDesire(bot, 2) == FLOOR,
        'a place-answering commitment must survive the corpse')
    assert(bot.tpRespondUntil ~= nil, 'and must keep its stamp')
end

tests['[reverse] the release is one-directional: it can only ever drop a pin'] = function()
    -- Arming tpdead may never turn a nil into a floor, on any of the frames or
    -- with either stamp shape. If a future edit gives this branch the power to
    -- CREATE a commitment, this fails.
    for _, f in ipairs(FRAMES) do
        for _, ally_stamp in ipairs({ true, false }) do
            local Js, bots = landed(f, { 'tpcommit' })
            if not ally_stamp then bots.tpRespondAlly = nil end
            local nShipped = Js.GetTpCommitDefendDesire(bots, 2)
            local Ja, bota = landed(f, { 'tpcommit', 'tpdead' })
            if not ally_stamp then bota.tpRespondAlly = nil end
            local nArmed = Ja.GetTpCommitDefendDesire(bota, 2)
            assert(nArmed == nil or nArmed == nShipped,
                f.name .. ': armed produced ' .. tostring(nArmed)
                .. ' where shipped produced ' .. tostring(nShipped))
        end
    end
end

return tests
