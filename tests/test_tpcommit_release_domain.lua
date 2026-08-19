-- [tpdying / GH #35] The tpcommit landing floor's survival release is half
-- dead in the domain the floor actually runs in.
--
-- J.GetTpCommitDefendDesire pins a fresh TP responder in the DEFEND mode of the
-- lane it answered with a 0.85 floor. Its release is
--     J.GetHP(bot) < 0.40 or J.ShouldRetreatLaneBurst(bot)
-- and the second clause is the anticipatory one -- the whole reason the release
-- works, since a lander who waits until 40% has already eaten the burst. But
-- J.ShouldRetreatLaneBurst returns false outside the laning phase, and this
-- floor is only reachable from the two response-TP branches, which require
-- level 6+ and a >3500u trip. Post-laning the release therefore degrades to the
-- numeric clause alone.
--
-- THE RULE THIS TEST FOLLOWS (test_set.md 0b): assert the FINAL bid, the number
-- the engine sees, not the helper's return. So every desire assertion here
-- drives the real mode files -- bots/mode_defend_tower_mid_generic.lua and
-- bots/mode_retreat_generic.lua -- on the real frame, and the mock now carries
-- the real 0..1 desire constants so those numbers mean what they say.
--
-- The frame is real: f_182552_warlock_ult_hoard, t=626.0 (10:26).
--   * 10:26 is past turbo's 10-minute soft laning end, so IsInLaningPhase() is
--     false regardless of net worth -- the anticipatory clause cannot fire.
--   * Warlock is at 546/1022 = 53.4% HP, above the 0.40 numeric clause.
--   * Sniper stands 1008u away and, per the replay's ground truth, dealt 669
--     damage into that 546 HP pool. died_after = 2.3s.
-- The only synthetic part is the response stamp (bot.tpRespondLoc/-Until) and
-- the lane front, which are the floor's own preconditions -- a real responder
-- would have set them at cast time. Everything the decision reads (positions,
-- HP, the incoming burst, the clock) is the replay's.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FLOOR = 0.85   -- J.GetTpCommitDefendDesire's landing floor
local LANE = 2       -- any lane; the floor binds by distance, not by index

--- Load the frame and put the subject in the state a fresh TP responder is in:
--- stamped response, lane front at the trigger. `ids` is the armed soak set.
local function landed(ids)
    local J, bot, heroes, fx = rf.load('tests/fixtures/f_182552_warlock_ult_hoard.lua')
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    -- The responder stamped the spot it answered when it cast (item-usage
    -- wiring, ability_item_usage_generic.lua). 12s window, we are 5s in.
    bot.tpRespondLoc = bot:GetLocation()
    bot.tpRespondUntil = fx.time + 7.0
    -- The floor binds to the lane whose front is near the trigger; put the
    -- front on the fight, which is what answering a lane front means.
    GetLaneFrontLocation = function() return bot:GetLocation() end -- luacheck: ignore
    return J, bot, heroes, fx
end

--- The real mode files' GetDesire(), i.e. the bid the engine actually ranks.
local function defend_bid()
    dofile(GetScriptDirectory() .. '/mode_defend_tower_mid_generic.lua')
    return GetDesire()
end

local function retreat_bid()
    dofile(GetScriptDirectory() .. '/mode_retreat_generic.lua')
    return GetDesire()
end

-- ---- the domain gap itself ---------------------------------------------------

tests['[domain] the anticipatory half of the release cannot fire on this frame'] = function()
    local J, bot = landed({ 'tpcommit' })
    assert(J.IsInLaningPhase() == false,
        't=626 is past turbo\'s 10-minute soft laning end; if this ever reads '
        .. 'true the frame no longer demonstrates the post-laning domain')
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'the anticipatory clause of the tpcommit release is laning-gated, so '
        .. 'it is structurally dead here -- this is the defect, asserted')
    assert(J.GetHP(bot) > 0.40,
        'and the numeric clause is silent too: 546/1022 = 53.4%')
end

tests['[ground truth] the burst on this frame is already lethal'] = function()
    local J, bot, heroes = landed({ 'tpcommit' })
    local sniper = heroes['npc_dota_hero_sniper']
    assert(math.abs(GetUnitToUnitDistance(bot, sniper) - 1008) < 2,
        'sniper is inside the 1100 estimator radius (1008u)')
    assert(sniper:GetEstimatedDamageToTarget(true, bot, 3.0, 0) == 669,
        'replay ground truth: sniper dealt 669 in the following window')
    assert(669 > bot:GetHealth(),
        '669 into a 546 HP pool -- the replay says dead 2.3s after this frame')
    assert(J.IsIncomingBurstLethal(bot, 3.0) == true,
        'the domain-matched predicate reads that, where the laning one cannot')
end

-- ---- the final bid: what the engine ranks ------------------------------------

tests['[final bid] armed tpcommit pins the lander at 0.85 over the retreat bid'] = function()
    landed({ 'tpcommit' })
    local nDefend = defend_bid()
    local nRetreat = retreat_bid()
    assert(nDefend == FLOOR,
        'the real defend mode bids the floor, not the helper value: got '
        .. tostring(nDefend))
    assert(nRetreat < nDefend,
        'and it outbids retreat on the very frame the hero was being killed: '
        .. 'retreat ' .. tostring(nRetreat) .. ' vs defend ' .. tostring(nDefend))
end

tests['[final bid] the shipped defend term alone is far below the floor'] = function()
    landed({})   -- nothing armed: shipped behavior
    local nShipped = defend_bid()
    assert(nShipped < FLOOR,
        'without the floor the same frame bids ' .. tostring(nShipped)
        .. ' -- so the 0.85 really is the pin, not a coincidence')
end

tests['[final bid] arming tpdying drops the pin on this frame'] = function()
    landed({ 'tpcommit', 'tpdying' })
    local nDefend = defend_bid()
    assert(nDefend < FLOOR,
        'the release fires and the engine-visible defend bid falls off the '
        .. 'floor: got ' .. tostring(nDefend))
    assert(nDefend == 0.1,
        'down to the shipped defend term for this frame (0.1), i.e. the floor '
        .. 'contributes nothing: got ' .. tostring(nDefend))
end

-- ---- containment: nothing moves until this id is armed -----------------------

tests['[containment] tpdying alone changes nothing (the floor needs tpcommit)'] = function()
    landed({ 'tpdying' })
    local nDefend = defend_bid()
    assert(nDefend == 0.1,
        'without tpcommit there is no floor to release; shipped bid stands')
end

tests['[containment] a survivable burst keeps the pin even with tpdying armed'] = function()
    local J, bot, heroes = landed({ 'tpcommit', 'tpdying' })
    local sniper = heroes['npc_dota_hero_sniper']
    rawget(sniper, '__spec').GetEstimatedDamageToTarget = function() return 100 end
    assert(J.IsIncomingBurstLethal(bot, 3.0) == false,
        '100 damage against 546 HP is a trade, not a death')
    assert(defend_bid() == FLOOR,
        'the release is for landers who are dying, not for everyone under fire')
end

tests['[containment] the release still cannot fire in normal (non-turbo) mode'] = function()
    landed({ 'tpcommit', 'tpdying' })
    GetGameMode = function() return 1 end -- luacheck: ignore
    local nDefend = defend_bid()
    assert(nDefend == 0.1,
        'the whole floor is turbo-gated, so outside turbo there is no pin and '
        .. 'no release: got ' .. tostring(nDefend))
end

-- ---- reverse assertion: this test expires if the shipped release is fixed -----

tests['[reverse] the shipped release is still the laning-only pair'] = function()
    local J, bot = landed({ 'tpcommit' })
    -- Push the bot under 40%: the surviving clause must still be the ONLY thing
    -- that releases the pin without tpdying. If someone later makes the shipped
    -- release domain-correct, this assertion fails and the id is obsolete.
    local sp = rawget(bot, '__spec')
    sp.GetHealth = math.floor(bot:GetMaxHealth() * 0.39)
    sp.OriginalGetHealth = sp.GetHealth
    assert(J.GetTpCommitDefendDesire(bot, LANE) == nil,
        'under 40% the numeric clause releases')
    sp.GetHealth = math.floor(bot:GetMaxHealth() * 0.41)
    sp.OriginalGetHealth = sp.GetHealth
    bot.tpRespondUntil = DotaTime() + 7.0   -- the release above cleared it
    assert(J.GetTpCommitDefendDesire(bot, LANE) == FLOOR,
        'one percent above it the pin is back, with lethal burst incoming and '
        .. 'no laning phase to notice -- the gap this id exists for')
end

return tests
