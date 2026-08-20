-- [tpdying / GH #35, GH #68] What "post-laning" actually means in turbo, and
-- what that does to this id's domain and to its first condition-(a) verdict.
--
-- J.GetTpCommitDefendDesire's shipped release is
--     J.GetHP(bot) < 0.40 or J.ShouldRetreatLaneBurst(bot)
-- and `tpdying` exists because the second, anticipatory clause is laning-gated
-- while the floor's own frames are "overwhelmingly POST-laning" (the comment at
-- the call site, and GH #35). That premise reads J.IsInLaningPhase as a clock.
-- It is not one. In turbo it is
--     t < 8*60                                   -> laning
--     t < 10*60 and GetBot():GetNetWorth() < 8000 -> still laning
-- so between 8:00 and 10:00 the answer depends on the RESPONDER'S OWN WALLET.
-- Two landers in the same fight, same HP, same enemies, get different releases
-- because one is richer -- and under 8000 net worth at nine minutes is the
-- ordinary case, not the exception.
--
-- Three real frames, all from the 10:11Z wave GH #68 read:
--   * 20260820_103644 t=492.4 (8:12) necrolyte, 3997 net worth -> STILL LANING.
--     The shipped release fires here on its own; `tpdying` is a no-op.
--   * 20260820_102645 t=556.5 (9:16) crystal_maiden, 3068 net worth -> STILL
--     LANING. This is the frame GH #68 section 1.1 attributes to `tpdying` by
--     elimination, and the elimination step it uses is "t=556 > 480, so
--     ShouldRetreatLaneBurst structurally returns false". It does not.
--   * 20260820_102030 t=639.5 (10:39) tidehunter -> past 10:00, laning is over
--     for anyone. The id's premise is real here; it is just narrower than the
--     comment claims.
--
-- HONEST SCOPE, stated once and asserted below: GetEstimatedDamageToTarget is
-- not in a .dem (GH #27 family). The loader substitutes the damage the enemy
-- ACTUALLY dealt over the window -- a ground-truth stand-in that is blind to
-- the engine's mana/cd awareness, which is precisely the mechanism GH #68
-- section 2.3 blames. So nothing here can prove what the predicate returned in
-- the live game. What it CAN settle is the laning arithmetic, which involves no
-- estimator at all.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FLOOR = 0.85   -- J.GetTpCommitDefendDesire's landing floor
local LANE = 2

local NECRO = 'tests/fixtures/f_260820_103644_necro_pinned_dying.lua'
local CM    = 'tests/fixtures/f_260820_102645_cm_laning_release.lua'
local TIDE  = 'tests/fixtures/f_260820_102030_tide_illusion_burst.lua'

--- The frame with the subject in a fresh responder's state, as in
--- tests/test_tpcommit_release_domain.lua: stamped response, lane front on the
--- trigger. Those two are the floor's own preconditions, which a real responder
--- sets at cast time; everything the decision reads is the replay's.
local function landed(path, ids)
    local J, bot, heroes, fx = rf.load(path)
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    bot.tpRespondLoc = bot:GetLocation()
    bot.tpRespondUntil = fx.time + 7.0
    GetLaneFrontLocation = function() return bot:GetLocation() end -- luacheck: ignore
    return J, bot, heroes, fx
end

local function defend_bid()
    dofile(GetScriptDirectory() .. '/mode_defend_tower_mid_generic.lua')
    return GetDesire()
end

local function retreat_bid()
    dofile(GetScriptDirectory() .. '/mode_retreat_generic.lua')
    return GetDesire()
end

-- ---- the arithmetic, which needs no estimator ---------------------------------

tests['[domain] turbo laning does not end at 8:00 -- it ends at the wallet'] = function()
    local J, bot = landed(NECRO, { 'tpcommit' })
    assert(DotaTime() == 492.4, 'the frame is 8:12, past the 8-minute floor')
    assert(J.IsModeTurbo() == true, 'and it is turbo, where that floor applies')
    assert(bot:GetNetWorth() == 3997,
        'the responder is worth 3997 at 8:12 -- under the 8000 soft-extension '
        .. 'threshold, which is the ordinary case for anyone but a fed core')
    assert(J.IsInLaningPhase() == true,
        'so the engine still calls this the laning phase, two minutes after '
        .. 'the clock the tpdying rationale reads it as')
end

tests['[domain] so the clause the rationale calls structurally dead is live here'] = function()
    local J, bot = landed(NECRO, { 'tpcommit' })
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'the SHIPPED anticipatory release fires on this frame on its own')
    assert(J.GetHP(bot) > 0.40,
        'and it is doing it before the numeric clause could -- 965/1183 = 81.6%')
end

tests['[final bid] shipped tpcommit already drops this pin; tpdying adds nothing'] = function()
    local J, bot = landed(NECRO, { 'tpcommit' })
    assert(J.GetTpCommitDefendDesire(bot, LANE) == nil, 'released, unarmed')
    local nDefendShipped, nRetreatShipped = defend_bid(), retreat_bid()
    landed(NECRO, { 'tpcommit', 'tpdying' })
    local nDefendArmed, nRetreatArmed = defend_bid(), retreat_bid()
    assert(nDefendShipped == nDefendArmed and nRetreatShipped == nRetreatArmed,
        'bit-identical with the id armed: defend ' .. tostring(nDefendShipped)
        .. '/' .. tostring(nDefendArmed) .. ', retreat '
        .. tostring(nRetreatShipped) .. '/' .. tostring(nRetreatArmed))
    assert(nDefendShipped < FLOOR and nRetreatShipped > nDefendShipped,
        'and retreat wins the frame either way: retreat '
        .. tostring(nRetreatShipped) .. ' vs defend ' .. tostring(nDefendShipped))
end

-- ---- GH #68 section 1.1: the frame the (a) verdict rests on --------------------

tests['[GH #68 1.1] the elimination step fails: that frame is still laning too'] = function()
    local J, bot = landed(CM, { 'tpcommit' })
    assert(DotaTime() == 556.5 and bot:GetNetWorth() == 3068,
        'crystal_maiden at 9:16 with 3068 net worth')
    assert(J.IsInLaningPhase() == true,
        'GH #68 excludes the anticipatory clause with "t=556 > 480, so it '
        .. 'structurally returns false". Under 8000 net worth before 10:00 it '
        .. 'does not -- the laning half of the shipped release was LIVE, so it '
        .. 'is not eliminated and the attribution is not closed')
end

tests['[GH #68 1.1] and under the observable proxy tpdying would not have fired'] = function()
    local J, bot, _, fx = landed(CM, { 'tpcommit', 'tpdying' })
    assert(J.IsIncomingBurstLethal(bot, 3.0) == false,
        'the enemies inside 1100 (bristleback 377u, earthshaker 520u) went on '
        .. 'to deal 261 into a 504 HP pool -- half of what this predicate asks')
    assert(J.GetTpCommitDefendDesire(bot, LANE) == FLOOR,
        'so the pin is still standing on the very frame GH #68 credits this '
        .. 'id with dropping it')
    assert(defend_bid() == FLOOR and retreat_bid() < FLOOR,
        'and the engine-visible bids agree: the lander stays pinned')
    assert(fx.observed.died_after == 39.0,
        'ground truth, recorded and NOT used as an argument: she lived another '
        .. '39 seconds')
end

-- ---- the premise IS true past ten minutes -------------------------------------

tests['[domain] past 10:00 the premise holds and the id has a real domain'] = function()
    local J, bot = landed(TIDE, { 'tpcommit' })
    assert(DotaTime() == 639.5, 'the third frame is 10:39')
    assert(J.IsInLaningPhase() == false,
        'past the soft end no wallet keeps a hero laning')
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'so the anticipatory clause really is structurally dead here -- the '
        .. 'gap tpdying was written for is real, just later than claimed')
end

-- ---- the negative result on GH #68 section 5.1 --------------------------------

tests['[negative] the proposed threshold decoupling is a no-op on both named frames'] = function()
    -- GH #68 section 5.1 proposes comparing the burst against something other
    -- than current health -- e.g. a band above the 40% clause. On the two
    -- frames the report names, that change cannot be told apart from shipped:
    local J, bot = landed(NECRO, { 'tpcommit', 'tpdying' })
    local nBand = bot:GetHealth() - 0.40 * bot:GetMaxHealth()
    assert(nBand > 0 and nBand < bot:GetHealth(),
        'the proposal is strictly looser: ' .. tostring(math.floor(nBand))
        .. ' instead of ' .. tostring(bot:GetHealth()))
    assert(J.IsIncomingBurstLethal(bot, 3.0) == true,
        'but the strict comparison ALREADY passes here (1080 vs 965), so a '
        .. 'looser one changes nothing')
    local _, botT = landed(TIDE, { 'tpcommit', 'tpdying' })
    assert(botT:GetHealth() - 0.40 * botT:GetMaxHealth() > 0,
        'and on the other named frame there is no attributable burst at all '
        .. '(illusion contamination, test_fixture_illusion_ground_truth), so '
        .. 'no threshold on it can be exercised')
end

tests['[limitation] the estimator this id turns on cannot be replayed offline'] = function()
    local _, bot, heroes = landed(NECRO, { 'tpcommit', 'tpdying' })
    local zuus = heroes['npc_dota_hero_zuus']
    assert(zuus:GetEstimatedDamageToTarget(true, bot, 3.0, 0)
        == zuus:GetEstimatedDamageToTarget(false, bot, 3.0, 0),
        'the fixture answers the same number whether or not the caller asks '
        .. 'for CURRENTLY CASTABLE abilities -- it substitutes realized damage. '
        .. 'GH #68 section 2.3 blames exactly that flag (the estimate collapses '
        .. 'once the burst is spent), so no fixture can measure the effect. A '
        .. 'corpus carrying the engine estimate is the prerequisite for any '
        .. 'threshold work on this id')
end

-- ---- reverse assertion --------------------------------------------------------

tests['[reverse] the shipped release is still the laning-gated pair'] = function()
    local src = io.open('bots/FunLib/jmz_func.lua'):read('*a')
    assert(src:find('if J.GetHP( bot ) < 0.40 or J.ShouldRetreatLaneBurst( bot ) then',
        1, true) ~= nil,
        'if the shipped release stops depending on IsInLaningPhase, the whole '
        .. 'domain question here is obsolete and so is this file')
    assert(src:find('nFloor = bTurbo and 8 * 60 or 10 * 60', 1, true) ~= nil
        and src:find('GetBot():GetNetWorth() < 8000', 1, true) ~= nil,
        'and the two numbers the arithmetic above turns on are still the ones '
        .. 'J.IsInLaningPhase uses')
end

return tests
