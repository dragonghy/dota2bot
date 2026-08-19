-- [GH #13 20260819] The creep pull (勾线) was a DEAD BRANCH, pinned on real frames.
--
-- The replay desk measured zero pull behavior in 13/13 batch games across three
-- seeds, on BOTH sides, with 'creeppull'/'pullcamp' armed. The cause is a logical
-- contradiction between the trigger and its caller's gate, not a threshold that
-- was merely too tight:
--
--   * J.ShouldCreepPullLane REQUIRES a valid enemy hero within 1000 -- that hero
--     is the aggro-draw target we attack-order so its creeps follow us home.
--   * mode_roam_generic gated the bid on J.IsLanePullSafe, which is FALSE as soon
--     as any enemy hero is visible within 1800.
--
-- A hero inside 1000 is inside 1800, so the gate was false on exactly the frames
-- the trigger wanted. These tests use REAL laning frames (hero positions, HP,
-- levels, teams straight from the replay dumps) to pin:
--   1. the contradiction itself, on a textbook zoned-mid frame,
--   2. that J.IsCreepPullSafe unblocks it there,
--   3. that it still vetoes the wave13 ambush shape the old gate was written for
--      (163732: SK paced beside a camp while an Ogre watched from ~1700, died 6s
--      after the pinned frame) and the rotation shape (a third hero in the ring).
--
-- Honest note on synthesis: make_fixture.py dumps HEROES only, so the lane creep
-- wave in the end-to-end case is synthesized (placed at the real Lina's real
-- position, which is what makes the <= 500 aggro adjacency hold). Everything that
-- decides the SAFETY question -- who is visible and how far -- is real frame data.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local tests = {}

-- 20260720_072738_slot1 @ t=160.4: zuus laning mid at 65% HP with Lina, the only
-- visible enemy anywhere within 1800, standing 621u away. This is the canonical
-- "I am being zoned off my lane, drag the wave back" frame.
local ZONED_MID = 'tests/fixtures/f_072738_zuus_mana.lua'

tests['[GH #13] the old shared gate is FALSE on a textbook pull frame'] = function()
    local J, bot = rf.load(ZONED_MID)
    -- The pull mechanic's own precondition, from the real frame.
    local tNear = J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
    assert(#tNear == 1,
        'this frame must carry exactly one lane opponent inside the aggro-draw '
        .. 'radius -- that hero IS the pull target')
    -- ...and the gate that used to guard the bid says no, because of that very hero.
    assert(J.IsLanePullSafe(bot) == false,
        'the peacetime rule vetoes any frame with a visible enemy within 1800, '
        .. 'i.e. every frame the creep pull could ever fire on -- dead branch')
end

tests['[GH #13] J.IsCreepPullSafe allows the lane trade it is performed in'] = function()
    local J, bot = rf.load(ZONED_MID)
    assert(J.IsCreepPullSafe(bot) == true,
        'a healthy core zoned by a lone laner, nobody else visible in the ring, '
        .. 'is exactly when a human drags the wave back')
end

tests['[GH #13] end-to-end: the pull bid is reachable on the real frame'] = function()
    local J, bot, heroes = rf.load(ZONED_MID)
    local lina = heroes['npc_dota_hero_lina']

    -- Engine plumbing the hero dump does not carry: the enemy lane creep wave
    -- (placed at Lina's real position so the real 621u geometry decides the
    -- <= 500 hero-to-creep adjacency) and an EVEN lane front, so the pull has to
    -- be justified by the real zoning, never by a stacked wave signal.
    local creep = api.MakeUnit({
        CanBeSeen = true, IsAlive = true, GetLocation = lina:GetLocation(),
    })
    local sp = rawget(bot, '__spec')
    sp.GetNearbyLaneCreeps = function(_, _radius, bEnemy)
        if bEnemy then return { creep } end
        return {}
    end
    rawset(bot, 'GetNearbyLaneCreeps', nil)
    GetLaneFrontAmount = function() return 0.5 end -- luacheck: ignore

    -- Arm the candidate side (turbo comes from the fixture loader).
    J.IsSoakCandidate = function(id) return id == 'creeppull' end

    local pull = J.ShouldCreepPullLane(bot)
    assert(type(pull) == 'table',
        'with the lane trade allowed, the real zoned frame must yield a pull intent')
    assert(pull.enemy == lina,
        'the intent must name the real lane opponent as the aggro-draw target')
    assert(J.IsCreepPullSafe(bot) == true,
        'and the caller-side safety check must pass on the same frame, or the '
        .. 'bid is still dead')
end

tests['[GH #13] the 163732 ambush frame stays vetoed (no lane trade at all)'] = function()
    local J, bot = rf.load('tests/fixtures/f_163732_sk_pull_ambush.lua')
    -- Ogre watching from ~1691 with nobody inside 1000: this is a lurker, not a
    -- laner, and there is no wave to draw off him either way.
    assert(J.IsCreepPullSafe(bot) == false,
        'the frame SK died 6s after must not become pullable through the new gate')
end

tests['[GH #13] a third hero in the 1000-1800 ring vetoes the pull'] = function()
    -- 20260819_003005 @ t=373.4: nevermore at 539 (the lane trade) but jakiro
    -- also visible at 1139 -- a rotation closing in. Walking at the near one to
    -- aggro creeps is how you get sandwiched.
    local J, bot = rf.load('tests/fixtures/f_260819_003005_cm_selfpreserve.lua')
    assert(#J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE) == 1
        and #J.GetNearbyHeroes(bot, 1800, true, BOT_MODE_NONE) == 2,
        'frame shape check: one enemy in the trade, one extra body in the ring')
    assert(J.IsCreepPullSafe(bot) == false,
        'an enemy visible beyond the lane trade is a rotation -- never pull into it')
end

tests['[GH #13] a hurt core is still vetoed on a real frame'] = function()
    -- 20260721_071423 @ t=309.5: Luna at 38% HP with two enemies on top of her.
    local J, bot = rf.load('tests/fixtures/f_071423_luna_chase.lua')
    assert(J.IsCreepPullSafe(bot) == false,
        'below the 50% bar the pull walk is a death, same bar as the camp pull')
end

return tests
