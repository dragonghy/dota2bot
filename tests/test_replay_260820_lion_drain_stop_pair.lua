-- The two frames GH #86 §6 asks to be pinned, and the fact they exist to pin:
-- `liondrainstop`'s predicate CANNOT SEPARATE THEM.
--
-- WHY THIS FILE EXISTS (director ruling 2026-08-21T15:0xZ on GH #86, recorded
-- in state.json:liondrainstop_REGISTRATION_RULING_20260821T1500Z): the
-- registered condition-(a) criterion for `liondrainstop` moves from "filter
-- in-domain channels to span >= 2.0s, then compare arms" to the continuous
-- `post-domain residual`, because the replay stream measured the old filter to
-- be COMMON-CAUSED with the outcome it was supposed to be neutral about
-- (in-domain channels shorter than 2.0s end with Lion dead within 12s in
-- 12/24 cases vs 6/40 for the ones the filter keeps; Fisher two-sided
-- p=0.0040 -- mechanism: Lion dies => modifier_lion_mana_drain disappears =>
-- the channel is short BECAUSE he died). The ruling's second constraint:
-- changing the criterion without pinning the frames just renames a known
-- defect. These are the frames.
--
-- FRAME A -- `20260820_162821_slot1` t=307.4, MUST RELEASE (the short-channel
-- class the old filter discarded; channel 307.2 -> 308.2 = 1.0s):
--   Lion 607/736 HP (82.5%), 200/608 mana, level 5, rooted at (5972, -5494)
--   and he does not move one unit for the whole channel. Enemy inside
--   X.nEDrainDangerRadius: luna at 353u (70% HP). crystal_maiden is at 616u,
--   outside it. Hero damage in the previous 2s: 200 across five rows
--   (crystal_nova 79, three frostbite ticks 18+18+18, one luna attack 67).
--   GROUND TRUTH: HP 642 -> 607 -> 462 -> 427 -> 38 and DEAD at t=308.9,
--   killed by luna -- 1.5s after this decision instant, still rooted on the
--   same coordinate. `observed.died_after = 1.5`.
--
-- FRAME B -- `20260820_182906_slot1` t=606.5, MUST NOT RELEASE (the honest
-- counterexample; channel 605.8 -> 610.8 = 5.0s, which the old filter keeps):
--   Lion 603/977 HP (61.7%), 501/776 mana, level 8, rooted at (6047, -2272).
--   Enemy inside the danger radius: luna again, at 178u -- but at 32% HP and
--   with Lion's obsidian_destroyer at 128u and necrolyte at 263u next to him.
--   Hero damage in the previous 2s: 182 across seven rows (luna attack 87 +
--   two moon glaives, four crystal_maiden frostbite ticks).
--   GROUND TRUTH: LUNA dies at t=609.6 (obsidian_destroyer), Lion's HP bottoms
--   at 448 and is climbing again by t=609.5, the channel runs its full 5s, and
--   Lion never dies again in the game (his last death is t=539.8, before this
--   frame). `observed.died_after = nil`. Releasing here would have thrown away
--   a completed drain in a fight his team won.
--
-- THE POINT: on every quantity the shipped-plus-gate predicate reads, these
-- two frames are the SAME FRAME.
--   * WasRecentlyDamagedByAnyHero(2.0): true on both.
--   * J.GetNearbyHeroes(bot, 500, true, BOT_MODE_NONE): exactly one enemy on
--     both -- and it is the same hero, luna, both times.
--   * IsAbilityEChanneling: true on both (and here that is REAL frame data,
--     not a mutation: the drain target carries modifier_lion_mana_drain in
--     both fixtures -- luna with 0.2s elapsed in A, crystal_maiden with 0.7s
--     elapsed in B).
-- So the gate answers HIGH on both, which is exactly one true positive and one
-- false positive, and no retune of X.nEDrainDangerRadius or of the 2.0s damage
-- window can change that: both clauses are equally satisfied on both frames.
--
-- AND THE OBVIOUS NARROWING IS WORSE THAN NOTHING. "Only release when Lion is
-- low" fails on these two in the WRONG DIRECTION: the frame that must release
-- is at 82.5% HP and the frame that must not is at 61.7%. In absolute HP they
-- are 607 and 603 -- four points apart. Any monotone HP floor that suppresses
-- B suppresses A first, i.e. it kills the true positive and keeps the false
-- one. That implication is machine-checked below over the whole threshold
-- range instead of being asserted in prose.
--
-- WHAT DOES separate them, recorded but NOT implemented (n=2 cannot set a
-- threshold; this is a starting point for a future proposal, not an endorsement):
--   * the HP of the enemy inside the radius: 70% (A) vs 32% (B) -- in B the
--     one "threat" was three seconds from dying to Lion's own team;
--   * allies within 1200u: 1 (A) vs 2 (B).
--
-- EXTERNAL ANCHORS -- what is NOT read off the frames (declared, not hidden):
--   1. IsChanneling() is a native engine call the .dem does not carry. Ground
--      truth is the MODIFIER_ADD/REMOVE pair of modifier_lion_mana_drain in
--      the same replay's event stream (307.2..308.2 for A, 605.8..610.8 for B),
--      declared as a labelled mutation in load_lion below. Everything else the
--      channel test reads -- the modifier ON THE TARGET -- is real frame data.
--   2. Mana Drain cast range = 600 (Liquipedia 2026-08). The stop lever does
--      not read cast range; set for symmetry with the older pair's test.
-- Every other number -- positions, HP, mana, levels, ability levels and
-- cooldowns, inventories, alive/dead, the damage history behind
-- WasRecentlyDamagedBy*, and the death ground truth -- is real frame data.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local LETHAL   = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'    -- frame A, must RELEASE
local SURVIVED = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua'  -- frame B, must NOT release

local DRAIN_CAST_RANGE = 600        -- external anchor, see header

local function load_lion(path, bArmed, bTurbo)
    local J, bot, heroes, fx = rf.load(path)

    rawget(bot:GetAbilityByName('lion_mana_drain'), '__spec').GetCastRange = DRAIN_CAST_RANGE

    -- The only mutation: the engine's channel flag (anchor 1). The drain
    -- modifier on the target is real fixture data in BOTH frames, so
    -- X.IsAbilityEChanneling's inner scan runs on the replay, not on a stub.
    rawget(bot, '__spec').IsChanneling = true

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'liondrainstop' end
        or function() return false end

    local X = rf.load_hero('lion')
    return X, J, bot, heroes, fx
end

--- Count of enemy heroes the gate's own call sees inside the danger radius.
local function n_in_radius(X, J, bot)
    local l = J.GetNearbyHeroes(bot, X.nEDrainDangerRadius, true, BOT_MODE_NONE)
    return l == nil and 0 or #l
end

local tests = {}

-- ---------------------------------------------------------------- ground truth

tests['ground truth A: rooted at 82.5% HP, luna 353u, dead 1.5s later'] = function()
    local X, _, bot, heroes, fx = load_lion(LETHAL, true)
    assert(fx.time == 307.4, 'frame A is the decision instant GH #86 pins, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_lion', 'subject is Lion')
    assert(bot:GetHealth() == 607 and bot:GetMaxHealth() == 736,
        'real HP on the frame, got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:GetMana() == 200, 'real mana on the frame, got ' .. bot:GetMana())

    -- The channel is REAL here: luna carries modifier_lion_mana_drain in the
    -- fixture (elapsed 0.2s of the 307.2 channel). Only IsChanneling is mutated.
    assert(heroes['npc_dota_hero_luna']:HasModifier('modifier_lion_mana_drain'),
        'the drain modifier on the target is real frame data, not a stub')
    assert(X.IsAbilityEChanneling() == true, 'Lion is mid-channel on luna')

    local d = GetUnitToUnitDistance(bot, heroes['npc_dota_hero_luna'])
    assert(d > 350 and d < 356, 'luna is ~353u away, got ' .. math.floor(d))
    assert(d < X.nEDrainDangerRadius, 'and inside the danger radius')
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_crystal_maiden'])
        > X.nEDrainDangerRadius, 'crystal_maiden (616u) is OUTSIDE it -- luna is the whole domain')

    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'five hero damage rows inside the last 2s (crystal_nova + frostbite ticks + a luna attack)')

    assert(fx.observed.died_after ~= nil and fx.observed.died_after < 2.0,
        'ground truth: Lion is killed by luna 1.5s later, still on this coordinate, got '
        .. tostring(fx.observed.died_after))
end

tests['ground truth B: rooted at 61.7% HP, luna 178u but at 32% HP, and he survives'] = function()
    local X, _, bot, heroes, fx = load_lion(SURVIVED, true)
    assert(fx.time == 606.5, 'frame B is the decision instant GH #86 pins, got ' .. tostring(fx.time))
    assert(bot:GetHealth() == 603 and bot:GetMaxHealth() == 977,
        'real HP on the frame, got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:GetMana() == 501, 'real mana on the frame, got ' .. bot:GetMana())

    assert(heroes['npc_dota_hero_crystal_maiden']:HasModifier('modifier_lion_mana_drain'),
        'the drain target on this frame is crystal_maiden -- real frame data')
    assert(X.IsAbilityEChanneling() == true, 'Lion is mid-channel on crystal_maiden')

    local luna = heroes['npc_dota_hero_luna']
    local d = GetUnitToUnitDistance(bot, luna)
    assert(d > 175 and d < 181, 'luna is ~178u away, got ' .. math.floor(d))
    assert(d < X.nEDrainDangerRadius, 'and well inside the danger radius')
    assert(luna:GetHealth() / luna:GetMaxHealth() < 0.35,
        'but she is at 32% HP -- she dies to obsidian_destroyer 3.1s later')

    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'seven hero damage rows inside the last 2s -- he IS being hit, just not lethally')

    assert(fx.observed.died_after == nil,
        'ground truth: Lion never dies again in this game (last death t=539.8, before this frame), got '
        .. tostring(fx.observed.died_after))
end

-- ------------------------------------------------------- the pinned decisions

tests['armed: frame A releases -- the true positive the old span filter threw away'] = function()
    local X, _, bot = load_lion(LETHAL, true)
    assert(X.lion_ShouldStopDrain(bot) == true,
        'hero damage + luna inside 500u => break the root')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_HIGH,
        'ConsiderStopDrain must surface the release as HIGH')
end

tests['armed: frame B ALSO releases -- the pinned false positive'] = function()
    -- This is not the behaviour anyone wants; it is the behaviour the gate has,
    -- pinned so that a narrowing proposal has to move THIS assertion and say why.
    local X, _, bot = load_lion(SURVIVED, true)
    assert(X.lion_ShouldStopDrain(bot) == true,
        'the same two clauses hold on frame B, so the gate answers the same way')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_HIGH,
        'and it releases a channel that a won fight was about to make free')
end

tests['both clauses are load-bearing on BOTH frames (damage clause isolated)'] = function()
    -- FRAME MUTATION, not source: keep the geometry exactly as recorded and
    -- take away only the hero-damage answer. Without this pair, deleting the
    -- damage clause from the predicate would leave every assertion in this
    -- file green -- the two frames agree on the radius clause, so the radius
    -- clause alone reproduces both verdicts.
    for _, path in ipairs({ LETHAL, SURVIVED }) do
        local X, _, bot = load_lion(path, true)
        rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function() return false end
        assert(X.lion_ShouldStopDrain(bot) == false,
            'proximity alone must not release the channel, on ' .. path)
        assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE,
            'and ConsiderStopDrain stays at NONE, on ' .. path)
    end
end

tests['both clauses are load-bearing on BOTH frames (radius clause isolated)'] = function()
    -- Mirror: keep the real damage history and push the single enemy inside
    -- the radius (luna, on both frames) out past it.
    for _, path in ipairs({ LETHAL, SURVIVED }) do
        local X, _, bot, heroes = load_lion(path, true)
        local v = bot:GetLocation()
        rawget(heroes['npc_dota_hero_luna'], '__spec').GetLocation =
            Vector(v.x + 900, v.y, v.z)
        assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_luna'])
            > X.nEDrainDangerRadius, 'the mutation really moved luna out, on ' .. path)
        assert(X.lion_ShouldStopDrain(bot) == false,
            'damage from outside the radius does not root-lock him, on ' .. path)
    end
end

tests['THE POINT: every input the predicate reads is verdict-identical on the two frames'] = function()
    local XA, JA, botA = load_lion(LETHAL, true)
    local XB, JB, botB = load_lion(SURVIVED, true)

    -- Clause 1 -- the 2.0s hero-damage window.
    assert(botA:WasRecentlyDamagedByAnyHero(2.0) == botB:WasRecentlyDamagedByAnyHero(2.0),
        'clause 1 cannot separate the frames')
    assert(botA:WasRecentlyDamagedByAnyHero(2.0) == true, 'and it is true on both')

    -- Clause 2 -- the danger-radius scan. Same COUNT and the same hero.
    assert(n_in_radius(XA, JA, botA) == 1, 'exactly one enemy inside 500u on frame A')
    assert(n_in_radius(XB, JB, botB) == 1, 'exactly one enemy inside 500u on frame B')
    local nearA = JA.GetNearbyHeroes(botA, XA.nEDrainDangerRadius, true, BOT_MODE_NONE)
    local nearB = JB.GetNearbyHeroes(botB, XB.nEDrainDangerRadius, true, BOT_MODE_NONE)
    assert(nearA[1]:GetUnitName() == 'npc_dota_hero_luna'
       and nearB[1]:GetUnitName() == 'npc_dota_hero_luna',
        'and it is the same hero -- luna -- in both frames')

    -- Outer precondition -- also identical, and on real modifier data.
    assert(XA.IsAbilityEChanneling() == XB.IsAbilityEChanneling(),
        'the channel precondition cannot separate them either')

    -- Therefore the verdicts are equal, and the two ground truths are opposite.
    assert(XA.lion_ShouldStopDrain(botA) == XB.lion_ShouldStopDrain(botB),
        'same inputs => same verdict: the gate is blind to the difference that matters')
end

tests['THE POINT (2): no HP floor can fix it -- the frames are inverted on HP'] = function()
    local _, _, botA = load_lion(LETHAL, true)
    local _, _, botB = load_lion(SURVIVED, true)

    local pctA = botA:GetHealth() / botA:GetMaxHealth()   -- 0.825, MUST release
    local pctB = botB:GetHealth() / botB:GetMaxHealth()   -- 0.617, must NOT release
    assert(pctA > pctB,
        'the frame that must release is the HEALTHIER one: ' .. string.format('%.3f > %.3f', pctA, pctB))

    -- Machine-checked over the whole threshold range: a rule of the shape
    -- "release only while HP% < floor" that suppresses B necessarily
    -- suppresses A as well. There is no floor with the wanted polarity.
    for i = 1, 99 do
        local floor = i / 100
        local keepsA = pctA < floor
        local keepsB = pctB < floor
        if not keepsB then
            assert(not keepsA,
                'floor ' .. floor .. ' drops the false positive but also drops the true positive')
        end
    end

    -- Absolute HP is even flatter: 607 vs 603, four points apart.
    assert(math.abs(botA:GetHealth() - botB:GetHealth()) <= 10,
        'an absolute-HP floor has 4 points of room to work with, got '
        .. math.abs(botA:GetHealth() - botB:GetHealth()))
end

tests['recorded, not implemented: the two axes that DO separate the frames'] = function()
    -- Tripwire, not a proposal. If a future narrowing uses either axis it must
    -- restate these numbers; if the fixtures ever drift, this fails loudly.
    local _, _, botA, heroesA = load_lion(LETHAL, true)
    local _, _, botB, heroesB = load_lion(SURVIVED, true)

    local lunaA, lunaB = heroesA['npc_dota_hero_luna'], heroesB['npc_dota_hero_luna']
    local hpA = lunaA:GetHealth() / lunaA:GetMaxHealth()
    local hpB = lunaB:GetHealth() / lunaB:GetMaxHealth()
    assert(hpA > 0.65 and hpB < 0.35,
        'the threat inside the radius: 70% HP on A vs 32% on B, got '
        .. string.format('%.2f / %.2f', hpA, hpB))

    local function allies_within(bot, heroes, r)
        local n = 0
        for _, u in pairs(heroes) do
            if u ~= bot and u:GetTeam() == bot:GetTeam() and u:IsAlive()
                and GetUnitToUnitDistance(bot, u) <= r then
                n = n + 1
            end
        end
        return n
    end
    assert(allies_within(botA, heroesA, 1200) == 1, 'one ally beside Lion on frame A (necrolyte 60u)')
    assert(allies_within(botB, heroesB, 1200) == 2,
        'two on frame B (obsidian_destroyer 128u, necrolyte 263u) -- the ones who kill luna')
end

-- ------------------------------------------------------------------- gate off

tests['gate OFF: both frames are byte-identical to shipped'] = function()
    for _, path in ipairs({ LETHAL, SURVIVED }) do
        local X, _, bot = load_lion(path, false)
        assert(X.lion_ShouldStopDrain(bot) == false, 'unarmed the helper is inert on ' .. path)
        assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE,
            'unarmed + not retreating: shipped returns NONE on ' .. path)
    end
end

tests['gate OFF: armed but not turbo is inert on both frames'] = function()
    for _, path in ipairs({ LETHAL, SURVIVED }) do
        local X, _, bot = load_lion(path, true, false)
        assert(X.lion_ShouldStopDrain(bot) == false, 'the gate is turbo-only, on ' .. path)
        assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE, 'non-turbo: NONE on ' .. path)
    end
end

-- ---------------------------------------------------------- source tripwires

tests['source: the release predicate reads no HP term at all'] = function()
    -- The "cannot separate" claim above is a property of the CODE, not only of
    -- these two frames: X.lion_ShouldStopDrain reads a damage window and a
    -- radius scan and nothing else. If someone adds an HP term, this fails and
    -- they are sent to the two frames above to explain the polarity.
    local src = assert(io.open('bots/BotLib/hero_lion.lua')):read('*a')
    local body = src:match('function X%.lion_ShouldStopDrain.-\nend')
    assert(body, 'X.lion_ShouldStopDrain must exist in hero_lion.lua')
    local code = body:gsub('%-%-[^\n]*', '')
    assert(not code:find('GetHealth') and not code:find('GetHP'),
        'the release predicate must not read HP without revisiting the inverted pair above')
end

tests['source: the danger radius is still the shared constant, not a literal'] = function()
    -- Same self-reporting property the older pair asserts: a retune of
    -- X.nEDrainDangerRadius must move BOTH levers, so neither may hardcode it.
    local src = assert(io.open('bots/BotLib/hero_lion.lua')):read('*a')
    local body = src:match('function X%.lion_ShouldStopDrain.-\nend')
    local code = body:gsub('%-%-[^\n]*', '')
    assert(code:find('X%.nEDrainDangerRadius'),
        'the release predicate must read the shared radius constant')
    assert(not code:find('GetNearbyHeroes%s*%(%s*hBot%s*,%s*%d'),
        'and must not pass a numeric literal radius')
end

return tests
