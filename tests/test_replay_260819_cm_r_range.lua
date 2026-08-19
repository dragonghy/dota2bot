-- Replay-fixture regression for GH #34: `cmrguard` (CM's Freezing Field
-- self-preservation gate) was RANGE-BLIND -- it asked the boolean wrapper
-- J.HasReadyHardCc and threw away the handle J.GetReadyHardCc deliberately
-- returns, so any enemy inside the 1600 scan holding a ready hard CC vetoed
-- the ultimate no matter whether he could deliver it.
--
-- The counterfactual replay of 14 mirror games (issue #34) reconstructed all 5
-- vetoes on real frames; this is the clean false positive:
--
--   game spot_20260819_001007_1_main/20260819_004858_slot1, t=423.4 (7:03).
--   CM 427/890 hp. The ONLY nearby enemy holding a ready curated hard CC is a
--   31%-hp Centaur at 1326 units whose hoof_stomp is a SELF-CENTERED 325-radius
--   AoE with no cast range -- and over the next 10s he walks monotonically away
--   (1326 -> 1459 -> 2043 -> 3077) and never casts it. Ogre Magi is closer
--   (346u) but his fireblast is 4s from ready, so he is not a vetoer.
--   Ground truth: CM opened Freezing Field here for real and lived another
--   44.1 seconds. The old gate would have eaten that ultimate for nothing.
--
-- The narrowed gate must release THIS frame while still catching the frame the
-- gate was opened for (Jakiro ice_path at 1139u, the other fixture below).
-- Both are pinned here together, deliberately: this is the `lanefix` lesson --
-- a narrowing that is locally right must not silently undo the original catch.
--
-- EXTERNAL ANCHORS (numbers that do NOT come from the dump -- make_fixture.py
-- extracts no ability specs, same caveat as wkreincarnmp's GetManaCost):
--   * hoof_stomp cast range: 0 (no-target self-radius ability). Tested at 0 AND
--     at 325 (its stomp radius, a generous upper bound) so the conclusion holds
--     whichever the engine reports.
--   * ice_path cast range: 1000, a deliberate UNDER-estimate (Liquipedia puts
--     the path at 1200 long, reaching ~1362). The predicate is monotone in cast
--     range, so blocking at 1000 blocks at the real value too.
--   * Freezing Field AoE radius: 835, and CM's distance-from-fountain, for the
--     end-to-end ConsiderR case only (the dump carries neither).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FAR   = 'tests/fixtures/f_260819_004858_cm_centaur_far.lua'   -- must ALLOW
local CLOSE = 'tests/fixtures/f_260819_003005_cm_selfpreserve.lua'  -- must BLOCK

local function hoof(heroes)
    return heroes['npc_dota_hero_centaur']:GetAbilityByName('centaur_hoof_stomp')
end

-- Place `unit` at `dist` units from `bot`, keeping the frame's real bearing.
local function move_to(bot, unit, dist)
    local b, u = bot:GetLocation(), unit:GetLocation()
    local dx, dy = u.x - b.x, u.y - b.y
    local d = math.sqrt(dx * dx + dy * dy)
    rawget(unit, '__spec').GetLocation = Vector(b.x + dx / d * dist, b.y + dy / d * dist, 0)
end

local tests = {}

tests['ground truth: the retreating Centaur at 1326u is the sole ready hard-CC holder in range'] = function()
    local J, bot, heroes, fx = rf.load(FAR)
    assert(fx.self == 'npc_dota_hero_crystal_maiden')
    assert(fx.time == 423.4, 'decision instant')
    assert(bot:GetHealth() == 427 and bot:GetMaxHealth() == 890, 'CM hp on the real frame')

    local centaur = heroes['npc_dota_hero_centaur']
    assert(math.floor(GetUnitToUnitDistance(bot, centaur)) == 1326, 'centaur distance')
    assert(J.GetReadyHardCc(centaur) ~= nil, 'his hoof_stomp is leveled and off cooldown')

    -- The closer enemy is NOT a vetoer: fireblast is 4s from ready.
    local ogre = heroes['npc_dota_hero_ogre_magi']
    assert(math.floor(GetUnitToUnitDistance(bot, ogre)) == 345, 'ogre distance')
    assert(J.GetReadyHardCc(ogre) == nil, 'ogre fireblast is on cooldown at this instant')

    -- Ground truth that makes this a false positive rather than a lucky escape.
    assert(fx.observed.died_after == 44.1, 'CM opened R for real and lived 44.1s')
end

tests['gate OFF: unchanged (always allows), byte-identical to the shipped path'] = function()
    local J, bot = rf.load(FAR)
    GetGameMode = function() return 1 end -- set after rf.load(): install() forces turbo
    J.IsSoakCandidate = function() return false end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'off the candidate nothing may change')
end

tests['gate ON: the 1326u retreating Centaur no longer vetoes (the GH #34 false positive)'] = function()
    local J, bot = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'a self-radius stomp 1326 units away cannot interrupt the channel -- must allow')
end

tests['gate ON: still allows if the engine reports hoof_stomp cast range as its 325 radius'] = function()
    local J, bot, heroes = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    rawget(hoof(heroes), '__spec').GetCastRange = 325 -- generous upper bound
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'the release must not hinge on which of the two plausible values the engine reports')
end

tests['gate ON [MUTATED frame]: same Centaur walked in to 350u -> vetoes again'] = function()
    local J, bot, heroes = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    move_to(bot, heroes['npc_dota_hero_centaur'], 350) -- MUTATION of the real frame
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'the narrowing must not disarm the gate -- a stomp that can actually land still withholds R')
end

tests['gate ON [MUTATED ability]: the same enemy at his real 1326u with a 1000-range CC vetoes'] = function()
    local J, bot, heroes = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    rawget(hoof(heroes), '__spec').GetCastRange = 1000 -- MUTATION: pretend it is ranged
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'the release is caused by DELIVERY RANGE, not by the ability dropping out of the curated table')
end

tests['gate ON: the frame the gate was opened for (Jakiro ice_path, 1139u) is still caught'] = function()
    local J, bot, heroes = rf.load(CLOSE)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    local icePath = heroes['npc_dota_hero_jakiro']:GetAbilityByName('jakiro_ice_path')
    rawget(icePath, '__spec').GetCastRange = 1000 -- under-estimate; see header
    local X = rf.load_hero('crystal_maiden')
    assert(math.floor(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_jakiro'])) == 1138,
        'the original motivating frame, unchanged')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'narrowing must not undo the original catch (lanefix lesson: pin both frames together)')
end

tests['the closing buffer stays inside the window the two real frames bound'] = function()
    rf.load(FAR)
    local X = rf.load_hero('crystal_maiden')
    -- Lower bound: ice_path (>=1000 range) must still cover the 1139u frame.
    assert(X.nRGuardCloseBuffer >= 139,
        'below 139 the Jakiro frame that motivated the whole gate stops being caught')
    -- Upper bound: hoof_stomp (0..325 range) must not cover the 1326u frame.
    assert(X.nRGuardCloseBuffer < 1326 - 325,
        'at or above 1001 the GH #34 false positive comes back')
end

-- Wiring, per the director's rule 0b (test_set.md 2026-08-19): a helper that is
-- right but unreachable is worth nothing, so pin that the guard actually sits on
-- the decision ConsiderR returns.
--
-- KNOWN GAP (why this is source-level rather than a driven ConsiderR call):
-- ConsiderR's first term is `abilityR:IsFullyCastable()`, and abilityR is
-- `bot:GetAbilityByName(sAbilityList[6])`. J.Skill.GetAbilityList (aba_skill.lua
-- :82) only files a name under index 6 when `ability:IsUltimate()` and its slot
-- is >= 4 -- but the behavioral dump compacts ability slots (CM comes back with
-- exactly 4 entries, ultimate at index 3) and carries no IsUltimate/IsHidden
-- flag. So in EVERY fixture `sAbilityList[6]` is nil, abilityR is the loader's
-- untrained nil-stub, and ConsiderR short-circuits to NONE before reaching any
-- guard. That is a pipeline gap affecting every hero's ultimate logic, not
-- something to paper over in this test -- filed as its own harness issue.
tests['wiring: the guard gates the ConsiderR entry, ahead of every bid branch'] = function()
    local f = assert(io.open('bots/BotLib/hero_crystal_maiden.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local body = src:match('function X%.ConsiderR%(%)(.-)\nend')
    assert(body, 'could not locate X.ConsiderR')
    assert(body:match('or not X%.cm_IsRSafeToOpen%( bot %)%s*\n%s*then%s*\n%s*return BOT_ACTION_DESIRE_NONE'),
        'the guard must sit on the early return that yields BOT_ACTION_DESIRE_NONE')
    assert(body:find('cm_IsRSafeToOpen', 1, true) < body:find('BOT_ACTION_DESIRE_HIGH', 1, true),
        'and it must be evaluated before any branch that bids for the ultimate')
end

tests['wiring: nothing calls the range-blind boolean wrapper any more'] = function()
    local f = assert(io.open('bots/BotLib/hero_crystal_maiden.lua', 'r'))
    local src = f:read('*a')
    f:close()
    assert(src:find('J.GetReadyHardCc', 1, true), 'the gate must take the handle')
    assert(src:match('J%.HasReadyHardCc%s*%(') == nil,
        'the boolean wrapper discards the handle -- that IS the GH #34 defect')
end

return tests
