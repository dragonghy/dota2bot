-- Replay desk 2026-08-28T06:5xZ -- THE MOTIVATING FRAME ITSELF.
--
-- GH #265's pre-registered falsification (replay desk 03:52Z) found the
-- ancient-camp waste on the FACTORY leg, and named one episode as the
-- load-bearing photograph:
--
--     W19 run db92df, game 20260828_004757_slot1, venomancer, level 10,
--     dire team of a radiant-armed game -- i.e. the FACTORY leg.
--
-- 'campexit' landed against that photograph, but tests/test_campexit_tier_release.lua
-- reaches it with SUBSTITUTE subjects: a bristleback lifted out of three
-- unrelated fixtures and re-declared at L10/L11/L12, plus an earthshaker at L4.
-- Substitutes are allowed (replay-fixture skill, backlog 0FIX) and that file says
-- so -- but no fixture in the tree carried the bot the episode is about. This
-- file adds it: two frames off that .dem, cut from the same episode.
--
--   f_20260828_004757_venomancer_785.lua  t=785.4  the last frame BEFORE the
--                                         first attack (first DAMAGE event is
--                                         t=786.3). Charter rule: evaluate a
--                                         decision predicate on the frame BEFORE
--                                         the act, never on the rising edge after
--                                         it (#66 §0).
--   f_20260828_004757_venomancer_790.lua  t=790.4  four seconds INTO the 15.0s
--                                         stationary burn, i.e. a frame where the
--                                         bot is already latched in Think()'s
--                                         third neutral branch -- the branch
--                                         'campexit' is the one call site of.
--
-- WHAT THE CORPUS SAYS ABOUT THIS EPISODE (frame-by-frame, this session, on the
-- dumper timeline; cited here, asserted below only where the fixture carries it):
--
--   766.4-786.4  walks 3800u straight to the camp at full health and full mana
--   786.3        first contact is a RIGHT-CLICK on npc_dota_neutral_prowler_shaman
--                (a Prowler ancient) -- inflictor dota_unknown, 47 damage
--   786.4-801.4  position byte-identical at (-4800, 207) for 15.0s
--   hp           1.000 -> 0.550 (45pp of its own health)
--   damage       1026 out (703 right-clicks + 323 passive poison_sting)
--                 898 in  -> ratio 1.14x, a near 1:1 trade with an ancient camp
--   mana         1.00 the whole time: it never cast a single active ability
--   ⭐ kills     ZERO. No DEATH event names any prowler in 780-812.
--   ⭐ gold      net worth 5288 (784.4) -> 5320 (804.4) = +32 over 20 seconds,
--                i.e. the passive trickle. The episode bought NOTHING.
--   consumables  a tango at 791.8 and an urn_of_shadows charge at 795.1 were
--                spent to stay in it -- the burn is not only self-healing hp
--   enemies      nearest enemy hero storm_spirit 1735u away, full health,
--                not engaged; zero enemy-hero damage in the window
--   802.4        walks away, camp still alive
--
-- The +32 gold is the sharpest number here and it is new: the 03:52Z report read
-- this episode as a 1.1x damage trade. It was not a bad trade -- it was not a
-- trade at all.
--
-- WHAT THIS FILE CAN AND CANNOT BUY -- read before trusting a number.
-- The SUBJECT half is real and is the actual bot: level, health, mana, position
-- and every other hero's position come off the .dem. The CREEP half is NOT in the
-- corpus and is not pretended to be -- [world W1] below asserts both neutral
-- sweep APIs answer `{}` on these fixtures, so the camp is a DECLARED stand-in
-- carrying exactly the fields the shipped code reads. That makes this a test of
-- "given the camp, does the predicate read THIS bot correctly", not end to end.
--
-- BUGGY vs SILENT is still not separable offline (GH #265 §5): the bot's mode is
-- not in a .dem. What these frames do buy is the other half of that question --
-- whether the predicate, handed the real bot, answers the way the photograph says
-- it should.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local F785 = 'tests/fixtures/f_20260828_004757_venomancer_785.lua'
local F790 = 'tests/fixtures/f_20260828_004757_venomancer_790.lua'
local SUBJ = 'npc_dota_hero_venomancer'

-- [corpus] the two frames, and the health the bot had at each. Both are read
-- back off the fixture, so a regenerated fixture that moved cannot pass quietly.
local FRAMES = {
    { F785, 't=785.4 pre-contact', 1.000 },
    { F790, 't=790.4 mid-burn',    0.820 },
}

local function subject(frame)
    local J, _, heroes = rf.load(frame[1], SUBJ)
    -- Same declaration test_campexit_tier_release.lua makes and for the same
    -- reason: this lever is about a bot already committed to a camp, not about a
    -- lane under attack. A 'fresh' world kills the farm bid outright.
    rf.declare_defend_ping(J, 'stale')
    local bot = heroes[SUBJ]
    assert(bot ~= nil, 'fixture no longer carries ' .. SUBJ .. ' -- ' .. frame[1])
    return J, bot
end

-- A declared neutral carrying exactly the fields FilterFarmNeutrals and
-- J.IsRoshan read. Same shape as test_campexit_tier_release.lua's, deliberately:
-- if that stand-in drifts, both files should be edited together.
local function creep(bot, sName, nHealth, bAncient, dist)
    local loc = bot:GetLocation()
    local d = (dist or 300) / math.sqrt(2)
    return api.MakeUnit({
        GetUnitName = sName,
        GetHealth = nHealth,
        GetMaxHealth = nHealth,
        IsAncientCreep = bAncient,
        IsNull = false,
        CanBeSeen = true,
        IsAlive = true,
        IsInvulnerable = false,
        IsHero = false,
        GetLocation = api.Vector(loc.x + d, loc.y + d, 0),
    })
end

-- The camp this bot actually stood in: Prowler ancients, nothing else in range.
-- Names are the ones the event stream carried at 786.3 and in the 15s that
-- followed -- shaman and acolyte, no third species.
local function prowler_camp(bot)
    return {
        creep(bot, 'npc_dota_neutral_prowler_shaman',  1100, true, 250),
        creep(bot, 'npc_dota_neutral_prowler_acolyte',  850, true, 300),
        creep(bot, 'npc_dota_neutral_prowler_acolyte',  850, true, 340),
    }
end

tests['[corpus] both frames carry the real bot at level 10, the band the ladder refuses'] = function()
    for _, frame in ipairs(FRAMES) do
        local _, bot = subject(frame)
        assert(bot:GetLevel() == 10, string.format(
            '%s: the frame moved -- venomancer used to be level 10, now %d',
            frame[2], bot:GetLevel()))
        -- Level is the only bot operand J.IsOverTierCampOnly reads besides the
        -- sweep, so this is the whole real input, not a sample of it.
        assert(bot:GetLevel() < 12, frame[2] ..
            ': the subject stopped being under J.Site.ANCIENT_MIN_LEVEL')
    end
end

tests['[corpus] the burn is in the frames: full health before contact, 18pp gone 4s in'] = function()
    for _, frame in ipairs(FRAMES) do
        local _, bot = subject(frame)
        local pct = bot:GetHealth() / bot:GetMaxHealth()
        assert(math.abs(pct - frame[3]) < 0.005, string.format(
            '%s: health moved -- expected %.3f, fixture carries %.3f',
            frame[2], frame[3], pct))
    end
    -- and the direction is monotone: the episode only ever costs health.
    local _, b785 = subject(FRAMES[1])
    local _, b790 = subject(FRAMES[2])
    assert(b790:GetHealth() / b790:GetMaxHealth()
         < b785:GetHealth() / b785:GetMaxHealth(),
        'the 15s stationary burn stopped being a burn')
end

tests['[corpus] ⭐ it never cast anything: mana is full at both frames'] = function()
    -- The whole 15s cost is right-clicks plus a passive. Any read of this episode
    -- as "a fight it was committed to" has to survive this: it spent no mana.
    for _, frame in ipairs(FRAMES) do
        local _, bot = subject(frame)
        assert(bot:GetMana() == bot:GetMaxMana(), string.format(
            '%s: mana is no longer full (%d/%d) -- the "no active ability was ' ..
            'cast" reading rests on this', frame[2], bot:GetMana(), bot:GetMaxMana()))
    end
end

tests['[corpus] ⭐ nobody was pressuring it: nearest living enemy hero is far away'] = function()
    -- The 03:52Z report's "enemy hero damage 0" is a zero in an event stream, and
    -- a zero can also mean "not sampled". This is the independent witness: the
    -- nearest enemy is a kilometre and a half out, at full health.
    for _, frame in ipairs(FRAMES) do
        local J, bot = subject(frame)
        local best, who = 1e9, nil
        for _, e in ipairs(bot:GetNearbyHeroes(20000, true, BOT_MODE_NONE) or {}) do
            if not e:IsNull() and e:IsAlive() then
                local d = J.GetDistance(bot:GetLocation(), e:GetLocation())
                if d < best then best, who = d, e:GetUnitName() end
            end
        end
        assert(who ~= nil, frame[2] .. ': the fixture carries no living enemy at all')
        assert(best > 1500, string.format(
            '%s: nearest living enemy is %s at %.0fu -- under 1500u this episode ' ..
            'would need re-reading as a contested camp', frame[2], who, best))
    end
end

tests['[world W1] the neutral sweep is a DECLARED input on these frames, not corpus'] = function()
    -- Stated as an assertion rather than a footnote, so the day a dumper starts
    -- carrying neutrals this file fails and gets rewritten instead of quietly
    -- keeping a stand-in it no longer needs.
    for _, frame in ipairs(FRAMES) do
        local _, bot = subject(frame)
        local a = bot:GetNearbyCreeps(1000, true) or {}
        local b = bot.GetNearbyNeutralCreeps and (bot:GetNearbyNeutralCreeps(1000) or {}) or {}
        assert(#a == 0 and #b == 0, frame[2] ..
            ': a neutral sweep answered non-empty -- the declared camp below is ' ..
            'now shadowing real corpus data, rewrite this file end to end')
    end
end

tests['[fix] unarmed, the shipped branch keeps every byte on the real frame'] = function()
    for _, frame in ipairs(FRAMES) do
        local J, bot = subject(frame)
        local sweep = prowler_camp(bot)
        assert(J.IsOverTierCampOnly(bot, sweep, false) == false,
            frame[2] .. ': unarmed fired on the motivating camp')
        assert(J.IsOverTierCampOnly(bot, sweep, nil) == false,
            frame[2] .. ': a nil gate stopped behaving like false')
    end
end

tests['[fix] ⭐ armed, the predicate releases the camp the photograph is of'] = function()
    for _, frame in ipairs(FRAMES) do
        local J, bot = subject(frame)
        local sweep = prowler_camp(bot)
        assert(J.IsOverTierCampOnly(bot, sweep, true) == true, frame[2] ..
            ': armed did NOT fire on the exact bot and the exact camp of GH #265 ' ..
            '-- this is the frame the lever was written for')
        -- and it fires for the stated reason, not incidentally: the ladder keeps
        -- nothing at this level.
        assert(#J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true) == 0,
            frame[2] .. ': the ladder kept a prowler at level 10 -- the fire above ' ..
            'is passing for a different reason than the one claimed')
    end
end

tests['[fix] the control: two levels up, the same bot and camp are untouched'] = function()
    -- J.Site.ANCIENT_MIN_LEVEL is 12. The lever must be inert there or it is not
    -- a tier guard, it is an anti-ancient guard.
    for _, frame in ipairs(FRAMES) do
        local J, bot = subject(frame)
        bot.GetLevel = function() return 12 end
        local sweep = prowler_camp(bot)
        assert(#J.Site.FilterFarmNeutrals(sweep, 12, true) > 0, frame[2] ..
            ': the ladder refused a prowler at level 12 -- the control is vacuous')
        assert(J.IsOverTierCampOnly(bot, sweep, true) == false, frame[2] ..
            ': armed released a camp the bot is entitled to take')
    end
    -- ...and the counterfactual is honest about what it changed: the real frame
    -- carries 10, the line above declares 12. Re-read the level to prove the
    -- override is local to this test and did not leak into the fixture.
    local _, bot = subject(FRAMES[1])
    assert(bot:GetLevel() == 10, 'the level override leaked into the fixture loader')
end

tests['[limit reach] the frequency of BEING in the third branch is not measured here'] = function()
    -- Honesty ratchet, carried over from test_campexit_tier_release.lua's own
    -- [limit reach]: this lever needs the bot already latched into Think()'s third
    -- neutral branch. t=790.4 is four seconds into a 15s stationary burn on an
    -- ancient camp, which is the best offline evidence that such a state exists --
    -- but the fixture cannot read GetActiveMode or FARM_STATE, so "it was in that
    -- branch" stays an inference from the position trace, not a read.
    local _, bot = subject(FRAMES[2])
    assert(bot.GetActiveMode == nil or bot:GetActiveMode() == nil
        or type(bot:GetActiveMode()) == 'number',
        'GetActiveMode became readable -- if it now carries the real mode, this ' ..
        'file can upgrade the inference above into a read')
    -- What IS a read: the bot did not move between the two frames.
    local _, b785 = subject(FRAMES[1])
    local a, b = b785:GetLocation(), bot:GetLocation()
    local moved = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
    assert(moved < 400, string.format(
        'the two frames are %.0fu apart -- they were meant to bracket one ' ..
        'stationary episode', moved))
end

return tests
