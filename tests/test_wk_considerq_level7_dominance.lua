-- [hero, GH #17 / #104 lever A] Wraith King: what the Wraithfire Blast kill
-- check is actually worth, once you read it in the context of the branch that
-- sits BELOW it in the same function.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- GH #104 section 5 registered three levers on hero_skeleton_king.lua and named
-- lever A the priority one: X.ConsiderQ builds `nDamage = 40*(lv-1)+100` and
-- hands `nDamage * 1.68` to J.CanKillTarget, which is 168/235/302/370 CLAIMED
-- magical damage against an impact of 80/100/120/140 and an impact-plus-whole-dot
-- of 120/180/240/300 (the re-anchor in tests/test_wk_fact_anchor.lua and the
-- correction recorded in tests/test_wk_bone_guard_thresholds.lua section 5).
-- The overclaim is real and section 1 below reads it straight out of the shipped
-- function.
--
-- What section 5 left open was the SHAPE OF THE DOMAIN -- how often correcting
-- that number would change anything -- and it recorded that as a corpus question.
-- Half of it is not a corpus question.  X.ConsiderQ ends with an unconditional
-- catch-all:
--
--     if ( #nEnemysHerosInView > 0 or bot:WasRecentlyDamagedByAnyHero( 3.0 ) )
--         and ( bot:GetActiveMode() ~= BOT_MODE_RETREAT or #allyList >= 2 )
--         and #nEnemysHerosInRange >= 1
--         and nLV >= 7
--
-- and nEnemysHerosInRange is everything inside cast range + 43.  From hero level
-- 7 on, ANY enemy hero that walks inside 568 units gets Wraithfire Blast the
-- moment it is off cooldown, whatever its health, whatever the kill check said.
--
-- WHAT THIS FILE PINS
--   1. the claimed lethal threshold, per Q rank, read out of shipped code by
--      sweeping target health -- not asserted from my arithmetic;
--   2. the hero level at which the decision stops depending on the target at
--      all, also read out by sweeping;
--   3. DOMINANCE: at level >= 7 and inside 568 units the whether-to-cast answer
--      is HIGH for EVERY target health from 1 to full, so a correction to the
--      kill check cannot change whether the ability is spent there;
--   4. the cost side, which is the part that decides lever A: the correction is
--      not inert on AIM.  With two enemies in range, the kill check is what
--      points the stun at the 25%-health one; without it the catch-all takes
--      the head of the nearby-hero list, which the engine sorts NEAREST FIRST
--      (docs/BOT_API_REFERENCE.md:1229), and on the frame built here the
--      nearest hero is the full-health one.  So narrowing the kill check above
--      level 6 does not save the cooldown -- it spends the same cooldown on a
--      worse target;
--   5. the same level-7 cliff on a REAL frame (f_232320_wk_od_burst).  READ THE
--      2026-09-01 CORRECTION BELOW before quoting section 5: the cliff is still
--      there, but on this frame it is no longer reachable by moving one integer.
--
-- CONSEQUENCE FOR LEVER A (recorded, not acted on here -- this file changes no
-- behaviour and adds no gate): lever A as GH #104 specified it is confined to
-- hero levels 1-6 plus a 37-unit shell between cast range + 43 and cast range +
-- 80, and inside that shell above level 6 it only re-aims.  A corpus count for
-- lever A only has to count frames in THAT box.  The lever with the reach is the
-- catch-all itself, registered in the charter backlog as a separate id.
--
-- HONEST BOUNDS -- read before quoting
--   * Sections 1-4 are the shipped functions under the mock API, not real
--     frames.  What they measure is the shape of the code, and section 5 shows
--     the same cliff on real frame data.
--   * The mock target applies a flat 25% magic resistance
--     (GetActualIncomingDamage = 0.75 * dmg), the game's base value for heroes.
--     Every health figure below is therefore raw health and every damage figure
--     is pre-mitigation; the ratio between them is the anchor, not the absolutes.
--   * Cast range 525 is an external anchor (datafeed hero_id 42, read
--     2026-08-22).  The dumper reports 0 for it, so section 5 supplies it too.
--   * "Worse target" in section 4 is a claim about health only.  Which of two
--     enemies is the better stun target in a real fight is not decidable here,
--     and the catch-all does not decide it either -- it takes the nearest.
--   * CORRECTION (2026-08-22, after GH #104's section-4 comment was published):
--     this file first described the catch-all as taking "whoever the engine
--     listed first" and reasoned from list order being arbitrary.  It is not:
--     the engine sorts GetNearby* results by distance, closest first, and the
--     fixture loader now does the same (tests/test_mock_nearby_heroes_order.lua
--     -- until then the bench handed back ALPHABETICAL order).  Section 4's
--     RESULT is unaffected, because its frame puts the full-health sven at 300u
--     and the dying lion at 400u, so sven heads the list under either reading;
--     the reason is what changed, and the assertions below now say "nearest".
--
-- CORRECTION (2026-09-01, GH #392): section 5 was measured with a broken meter
-- ------------------------------------------------------------------------
-- `c386d5f3` wired tests/mock/special_value_shapes.lua's AbilityManaCost ladder
-- into the fixture loader.  Until that day every `GetManaCost()` on a fixture
-- handle answered 0, and X.ShouldSaveMana -- the reserve that guards Wraith
-- King's Reincarnation and is the FIRST statement of X.ConsiderQ -- read
--
--     bot:GetMana() - nAbility:GetManaCost() < abilityR:GetManaCost()
--
-- as `272 - 0 < 0`, which is false on every frame that has ever existed.  The
-- reserve was frozen OFF, so section 5's original read-out never went through
-- it.  With the ladder awake it fires on this frame, at BOTH hero levels, and
-- the level-7 case below went red.
--
-- The correction is NOT a moved number.  Sections 5b/5c/5d re-derive it:
--   * 5b rebuilds the pre-ladder meter (every price on this frame forced back
--     to 0) and gets the recorded reading back EXACTLY -- level 6 silent,
--     level 7 HIGH at Obsidian Destroyer.  The record was right about its own
--     world; that world is the one that stopped existing.
--   * 5c reads the real world: under the ladder both levels are silent and the
--     decision is made by the reserve, before any branch of ConsiderQ runs.
--     The boundary is exactly Reincarnation's price plus Wraithfire Blast's,
--     read off the two handles rather than typed (220 + 95 = 315).
--   * 5d shows the DOMINANCE result of sections 1-4 survives intact: hand the
--     frame 315 mana and the level-6/level-7 cliff is back, unchanged, at the
--     same target.  What died is only the claim that ONE integer flips it.
--   * 5e is the sharp end: this frame's Wraith King has 272 of 272 mana, so
--     315 is not a number he can hold at all.  At this hero level, with
--     Reincarnation rank 1 and ready, shipped ConsiderQ is CONSTRUCTIVELY
--     unable to cast Wraithfire Blast -- and that consequence has been live in
--     every real game all along (the engine always priced abilities; only our
--     fixtures answered 0).  Every archived "ConsiderQ decides X on frame F"
--     reading taken before c386d5f3 was taken with this reserve switched off.
--
-- Note what this does to the section-2 case, which stayed GREEN across the
-- change: "shipped ConsiderQ is silent at level 6" is still true, but its
-- stated reason ("every branch correctly declines") became false the same day.
-- A green assertion with a dead reason is the thing that gets inherited, so
-- 5c now pins the reason rather than the outcome.
--
-- MUTATION RECORD (2026-08-22): nine mutations of hero_skeleton_king.lua, eight
-- caught -- the 1.68 multiplier to 1.00, `nLV >= 7` to 6 and to 8, both reaches
-- (+43 -> +100, +80 -> +40), the nDamage slope, the kill branch's return
-- replaced by a break, and the honest correction itself (impact-plus-dot in
-- place of the claim).  M6 SURVIVED AND IS AN INTENDED EQUIVALENCE: deleting
-- `#nEnemysHerosInRange >= 1` from the catch-all changes nothing, because the
-- only thing that guard protects is a `for _ in pairs(nEnemysHerosInRange)`
-- loop that does nothing on an empty list.  It is a redundant clause, not a
-- load-bearing one, and "not caught" and "nothing to catch" are different
-- things.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local Q_NAME = 'skeleton_king_hellfire_blast'
local BONE   = 'skeleton_king_bone_guard'
local REINC  = 'skeleton_king_reincarnation'

local CAST_RANGE = 525          -- external anchor, see header
local MAGIC_RESIST = 0.75       -- external anchor, see header

-- Recorded from the datafeed re-anchor, used only for comparison in section 1.
local IMPACT       = { 80, 100, 120, 140 }
local IMPACT_PLUS_DOT = { 120, 180, 240, 300 }

local tests = {}

----------------------------------------------------------------------
-- A single-enemy frame with every mode term switched off, so that only the
-- level-gated branches and the kill check can answer.  Not laning, not
-- retreating, not ganking, no allies in ATTACK mode (so J.IsInTeamFight is
-- false), no creeps on the enemy (so the laning branch cannot fire), never
-- recently damaged (so the level-6 branch cannot fire), and every lane front
-- parked far away.

local function make_frame(opts)
    api.reset_modules()
    local qlv = opts.qlv or 4
    local q = api.MakeAbility(Q_NAME, {
        IsFullyCastable = true,
        GetLevel = qlv,
        GetCastRange = CAST_RANGE,
        GetCastPoint = 0.3,
        GetManaCost = 95 + 15 * (qlv - 1),      -- 95/110/125/140
    })
    local bone = api.MakeAbility(BONE, { IsFullyCastable = false, GetLevel = 1 })
    -- Reincarnation far from ready: X.ShouldSaveMana only bites inside 3s of it.
    local reincarnation = api.MakeAbility(REINC,
        { GetManaCost = 220, GetCooldownTimeRemaining = 180 })

    local function make_enemy(name, dist, hp)
        return api.MakeHero(name, {
            GetTeam = 3,                        -- bot is on TEAM_RADIANT (2)
            CanBeSeen = true,
            GetHealth = hp,
            GetMaxHealth = 1000,
            GetLocation = api.Vector(dist, 0, 0),
            -- 500 < CAST_RANGE keeps the +260 "ranged enemy" widening shut; the
            -- reach read-out in section 2 asserts the widening really is shut.
            GetAttackRange = 500,
            GetActualIncomingDamage = function(_, dmg) return dmg * MAGIC_RESIST end,
            IsChanneling = false,
            IsFacingLocation = false,
        })
    end

    local enemies = {}
    for _, e in ipairs(opts.enemies) do
        enemies[#enemies + 1] = make_enemy(e.name, e.dist, e.hp)
    end

    local bot = api.MakeHero('npc_dota_hero_skeleton_king', {
        GetLevel = opts.lv,
        CanBeSeen = true,
        GetLocation = api.Vector(0, 0, 0),
        GetMana = 900, GetMaxMana = 1000,       -- affordable at every rank
        GetHealth = 1500, GetMaxHealth = 1500,  -- not a self-preservation frame
        GetActiveMode = BOT_MODE_NONE,
        WasRecentlyDamagedByAnyHero = false,
        IsFacingLocation = true,
        GetNearbyHeroes = function(_, radius, bEnemy)
            if not bEnemy then return {} end    -- no allies: no teamfight branch
            local t = {}
            for i, e in ipairs(opts.enemies) do
                if e.dist <= radius then t[#t + 1] = enemies[i] end
            end
            return t
        end,
        GetAbilityByName = function(_, name)
            if name == Q_NAME then return q end
            if name == BONE then return bone end
            if name == REINC then return reincarnation end
            -- sTalentList is empty under the mock, so the file's talent lookup
            -- arrives here as nil; untrained is the turbo reality (GH #84).
            if name == nil then
                return api.MakeAbility('mock_t20_talent', { IsTrained = false })
            end
            return api.MakeAbility(name)
        end,
    })
    api.install({ bot = bot })
    _G.GetLaneFrontLocation = function() return api.Vector(90000, 0, 0) end

    local X = dofile(WK_SRC)
    X.SkillsComplement()   -- sets the file-level nLV / nMP / nHP the path reads
    return X, bot, enemies
end

--- desire, and the unit name it was aimed at (or nil).
local function decide(opts)
    local X = make_frame(opts)
    local d, t = X.ConsiderQ()
    local name = (type(t) == 'table' and t.GetUnitName) and t:GetUnitName() or nil
    return d, name
end

local function solo(lv, hp, dist, qlv)
    return decide({
        lv = lv, qlv = qlv,
        enemies = { { name = 'npc_dota_hero_lion', dist = dist or 300, hp = hp } },
    })
end

----------------------------------------------------------------------
-- 1. Read the claimed lethal threshold out of the shipped function.
--
-- Hero level 5 is the isolation level: below 6 and 7 no catch-all exists, the
-- laning branch needs 4 enemy-attacking creeps it does not have, and every mode
-- term is off.  So the largest health that still draws a cast IS the kill
-- check's claim, expressed in target health.

-- Every predicate swept in this file is monotone (more health / more distance
-- can only turn a cast off, more hero level can only turn one on), so the
-- boundary is found by bisection and then CONFIRMED on both sides -- reloading
-- the hero file a thousand times to walk there costs half a minute of suite
-- time and reads out the same number.
local function last_true(lo, hi, pred)
    assert(pred(lo), 'bisection needs a true low end, ' .. lo .. ' was false')
    if pred(hi) then return hi end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if pred(mid) then lo = mid else hi = mid end
    end
    assert(pred(lo) and not pred(lo + 1),
        'the sweep is not monotone around ' .. lo .. ' -- the read-out below '
        .. 'assumes a single boundary and would be meaningless without one')
    return lo
end

local function max_hp_that_fires(qlv)
    return last_true(1, 600, function(hp) return solo(5, hp, 300, qlv) > 0 end)
end

tests['[GH #104] the kill check claims 126/176/226/277 health, read out of the code'] = function()
    local got = {}
    for qlv = 1, 4 do got[qlv] = max_hp_that_fires(qlv) end
    assert(table.concat(got, '/') == '126/176/226/277',
        'sweeping target health at hero level 5 says Wraithfire Blast believes it '
        .. 'kills up to ' .. table.concat(got, '/') .. ' health by rank, recorded '
        .. '126/176/226/277 (= (40*(rank-1)+100) * 1.68 * 0.75 magic resistance). '
        .. 'If this moved, either nDamage, the 1.68 multiplier or J.CanKillTarget '
        .. 'changed, and the whole of lever A is written against these numbers.')
end

tests['[GH #104] the claim exceeds BOTH honest ceilings at every rank'] = function()
    -- The point of lever A in one assertion: at no rank is the claim reachable,
    -- not even by a target that stands in the dot until it expires.
    for qlv = 1, 4 do
        local claim = max_hp_that_fires(qlv)
        local impact = IMPACT[qlv] * MAGIC_RESIST
        local full = IMPACT_PLUS_DOT[qlv] * MAGIC_RESIST
        assert(claim > impact,
            ('rank %d: the cast commits at %d health but only %d arrives on impact')
                :format(qlv, claim, impact))
        assert(claim > full,
            ('rank %d: the cast commits at %d health while the whole cast, dot '
             .. 'included, is worth %d -- there is no way for the claim to come '
             .. 'true even against a target that never leaves the dot')
                :format(qlv, claim, full))
    end
end

----------------------------------------------------------------------
-- 2. Read the level cliff and the two reaches out of the code.
--
-- A HEALTHY target (900 of 1000) makes every kill claim false at every rank, so
-- whatever still fires is a branch that does not look at health.

local function first_level_that_fires(hp, dist)
    for lv = 1, 12 do
        if solo(lv, hp, dist) > 0 then return lv end
    end
    return nil
end

local function max_dist_that_fires(hp)
    return last_true(100, 1200, function(dist) return solo(7, hp, dist) > 0 end)
end

tests['[GH #104] against a full-health enemy the cast starts at hero level 7'] = function()
    local lv = first_level_that_fires(900, 300)
    assert(lv == 7,
        'sweeping hero level against a 90%-health enemy 300u away, the first level '
        .. 'that casts is ' .. tostring(lv) .. ', recorded 7. That is the catch-all '
        .. "branch's `nLV >= 7`, and it is the reason lever A has almost no domain: "
        .. 'from level 7 the target no longer decides anything.')
end

tests['[GH #104] the catch-all reaches 568 and the kill branch 605'] = function()
    local healthy = max_dist_that_fires(900)     -- only the catch-all can answer
    local doomed  = max_dist_that_fires(200)     -- the kill branch answers first
    assert(healthy == CAST_RANGE + 43,
        'the catch-all reaches ' .. tostring(healthy) .. 'u, recorded '
        .. (CAST_RANGE + 43) .. ' (nEnemysHerosInRange = cast range + 43). A '
        .. 'different number here also means the +260 ranged-enemy widening '
        .. 'opened, which would invalidate every read-out in this file.')
    assert(doomed == CAST_RANGE + 80,
        'the kill branch reaches ' .. tostring(doomed) .. 'u, recorded '
        .. (CAST_RANGE + 80) .. '. The difference between the two reaches is the '
        .. 'only geometry in which correcting the kill check can silence a cast '
        .. 'above hero level 6: a 37-unit shell.')
end

----------------------------------------------------------------------
-- 3. DOMINANCE: above level 6, inside 568u, the target's health is not an input
-- to whether the ability is spent.

tests['[GH #104] at level 7 inside 568u every health from 1 to full casts'] = function()
    local silent = {}
    for hp = 1, 1000, 111 do
        if solo(7, hp, 400) == 0 then silent[#silent + 1] = hp end
    end
    if solo(7, 1000, 400) == 0 then silent[#silent + 1] = 1000 end
    assert(#silent == 0,
        'these target healths did NOT draw a cast at hero level 7, 400u away: '
        .. table.concat(silent, ',') .. '. The claim being pinned is that there '
        .. 'are none -- the kill check has no influence on whether Wraithfire '
        .. 'Blast is spent there, so a correction to it cannot save the cooldown.')
end

tests['[GH #104] below level 6 the same sweep is decided by the kill check'] = function()
    -- The other half of the dominance claim: the sweep above is not vacuous,
    -- because the identical sweep one level band down does depend on health.
    local fired, silent = 0, 0
    for hp = 1, 1000, 111 do
        if solo(5, hp, 400) > 0 then fired = fired + 1 else silent = silent + 1 end
    end
    assert(fired > 0 and silent > 0,
        'at hero level 5 the same health sweep fired ' .. fired .. ' times and '
        .. 'stayed silent ' .. silent .. ' times; both must be non-zero or the '
        .. 'level-7 result above proves nothing about the kill check')
end

----------------------------------------------------------------------
-- 4. The cost side of lever A: above level 6 the correction re-aims rather than
-- withholds, and it re-aims by DISTANCE, not by health.
--
-- The two enemies are ordered nearest-first below, which is the engine's
-- documented contract for GetNearby* (docs/BOT_API_REFERENCE.md:1229) and now
-- also what the fixture loader guarantees.  The assertion right under this
-- helper pins that ordering, so the conclusions below cannot silently become
-- statements about an arbitrary order again.

local function two_enemy_aim(lv, weakHp)
    local _, name = decide({
        lv = lv,
        enemies = {
            { name = 'npc_dota_hero_sven', dist = 300, hp = 900 },   -- NEAREST
            { name = 'npc_dota_hero_lion', dist = 400, hp = weakHp },
        },
    })
    return name
end

tests['[GH #104] the two-enemy frame is ordered nearest-first, like the engine'] = function()
    local _, bot = make_frame({
        lv = 7,
        enemies = {
            { name = 'npc_dota_hero_sven', dist = 300, hp = 900 },
            { name = 'npc_dota_hero_lion', dist = 400, hp = 250 },
        },
    })
    local list = bot:GetNearbyHeroes(568, true, BOT_MODE_NONE)
    assert(#list == 2, 'both enemies are inside the catch-all reach')
    assert(list[1]:GetUnitName() == 'npc_dota_hero_sven',
        'the frame hands the branches its enemies nearest-first (sven 300u before '
        .. 'lion 400u). Everything section 4 concludes about aim depends on this '
        .. 'order being the engine order, not on it being arbitrary.')
end

tests['[GH #104] the kill check is what aims the stun at the dying enemy'] = function()
    assert(two_enemy_aim(7, 250) == 'npc_dota_hero_lion',
        'with a 25%-health enemy inside the claim, the kill branch must be the one '
        .. 'that answers, and it must aim at that enemy rather than at the '
        .. 'full-health hero standing closer')
end

tests['[GH #104] without the claim the SAME frame still casts, at the healthy one'] = function()
    -- 900 health is outside every rank's claim, which is exactly the state a
    -- corrected kill check would produce for a target in the overclaim band.
    assert(two_enemy_aim(7, 900) == 'npc_dota_hero_sven',
        'once no kill claim is available the catch-all answers instead and takes '
        .. 'the head of the nearby-hero list, i.e. the NEAREST enemy -- here the '
        .. 'full-health sven at 300u, not the dying one at 400u. This is why '
        .. 'narrowing the kill check above hero '
        .. 'level 6 is not a saving: the cooldown and the mana leave anyway, at a '
        .. 'target chosen by proximity. Lever A has to be argued on levels 1-6 '
        .. 'and the 37-unit shell, or paired with a change to the catch-all.')
end

tests['[GH #104] below level 7 the same loss of claim IS a withhold'] = function()
    assert(two_enemy_aim(5, 250) == 'npc_dota_hero_lion', 'sanity: level 5 aims at the weak one')
    assert(two_enemy_aim(5, 900) == nil,
        'at hero level 5 there is no catch-all underneath, so losing the kill '
        .. 'claim really does hold the ability -- the residual domain of lever A '
        .. 'is this band, and it is the band a corpus count has to measure')
end

----------------------------------------------------------------------
-- 5. The same cliff on a real frame.
--
-- f_232320_wk_od_burst: game 20260721_232320 at t=380.0 (6:20).  WK is level 6
-- with 272 of 272 mana, Wraithfire Blast rank 1 and off cooldown; Obsidian
-- Destroyer stands 377u away at 1180 of 1374 health (86%), and the fixture's
-- ground truth is that OD dealt WK 915 damage over the next 8 seconds and WK
-- died 5.8s later.  Everything the branches read here -- level, mana, ability
-- rank and cooldown, both positions, health -- is real frame data.  The single
-- mutation is hero level in the last case, and it is the whole point.

local FRAME = 'tests/fixtures/f_232320_wk_od_burst.lua'

-- opts.mana        : override the hero's mana pool (5c/5d only)
-- opts.zero_prices : rebuild the PRE-c386d5f3 meter -- every ability handle on
--                    this frame priced 0, which is what the loader answered
--                    before the mana ladder was wired in.  Applied by walking
--                    the engine slots, not a typed name list, so a renamed
--                    ability cannot quietly keep its price; the rebuild then
--                    asserts on Q and R that it actually took.
local function load_frame(nLevelOverride, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FRAME)
    local q = bot:GetAbilityByName(Q_NAME)
    -- The dumper reports no cast ranges (GH #27 family), so anchor it.
    rawget(q, '__spec').GetCastRange = CAST_RANGE
    if nLevelOverride then rawget(bot, '__spec').GetLevel = nLevelOverride end
    if opts.mana then rawget(bot, '__spec').GetMana = opts.mana end
    if opts.zero_prices then
        local zeroed = 0
        for slot = 0, 5 do
            local h = bot:GetAbilityInSlot(slot)
            if h ~= nil then
                rawget(h, '__spec').GetManaCost = function() return 0 end
                zeroed = zeroed + 1
            end
        end
        assert(zeroed > 0, 'the pre-ladder rebuild found no abilities in slots '
            .. '0-5, so it zeroed nothing and every reading under it would be '
            .. 'the real-ladder reading wearing the rebuild\'s name')
        assert(q:GetManaCost() == 0
            and bot:GetAbilityByName(REINC):GetManaCost() == 0,
            'the pre-ladder rebuild did not reach the two handles the reserve '
            .. 'reads (Wraithfire Blast and Reincarnation)')
    end
    J.IsSoakCandidate = function() return false end   -- shipped defaults
    local X = rf.load_hero('skeleton_king')
    X.SkillsComplement()
    return X, J, bot, heroes, fx, q
end

--- desire and aimed-at name on the real frame, in one call.
local function frame_decide(nLevelOverride, opts)
    local X = load_frame(nLevelOverride, opts)
    local d, t = X.ConsiderQ()
    local name = (type(t) == 'table' and t.GetUnitName) and t:GetUnitName() or nil
    return d, name
end

local OD = 'npc_dota_hero_obsidian_destroyer'

tests['[real frame] ground truth: level 6, rank-1 blast ready, OD 377u at 86%'] = function()
    local _, _, bot, heroes, fx, q = load_frame()
    assert(fx.time == 380.0, 'frame t=380.0, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_skeleton_king', 'subject is WK')
    assert(bot:GetLevel() == 6, 'WK is level 6 on this frame, got ' .. bot:GetLevel())
    assert(q:GetLevel() == 1 and q:GetCooldownTimeRemaining() == 0,
        'Wraithfire Blast is rank 1 and off cooldown -- the silence below is a '
        .. 'decision, not a missing precondition')
    assert(bot:GetMana() == 272, 'real mana, got ' .. bot:GetMana())
    local od = heroes[OD]
    assert(od ~= nil and GetUnitToUnitDistance(bot, od) < CAST_RANGE + 43,
        'OD must be inside the catch-all ring for the level flip to mean anything')
    assert(od:GetHealth() / od:GetMaxHealth() > 0.85,
        'OD is at 86% health: no kill check of any rank claims him')
end

-- The reserve's operands are ground truth too, since 2026-09-01 -- everything
-- in 5b..5e is a statement about them.
tests['[real frame] ground truth: Reincarnation rank 1 and READY, 272 of 272 mana'] = function()
    local _, _, bot, _, _, q = load_frame()
    local r = bot:GetAbilityByName(REINC)
    assert(r ~= nil and r:GetLevel() == 1,
        'Reincarnation is rank 1 on this frame, got ' .. tostring(r and r:GetLevel())
        .. '. If it were unlearned the reserve would still price it (the loader '
        .. 'clamps rank 0 to the rank-1 step) and 5c would be measuring a '
        .. 'reserve held for an ability that cannot be cast -- a different bug.')
    assert(r:GetCooldownTimeRemaining() == 0,
        'Reincarnation is off cooldown, so the reserve\'s `<= 3.0` term is true '
        .. 'for the honest reason rather than for a missing dumper field')
    assert(q:GetManaCost() == 95 and r:GetManaCost() == 220,
        'the ladder prices this frame at Q=' .. q:GetManaCost() .. ' R='
        .. r:GetManaCost() .. ', recorded 95/220 (special_value_shapes.lua, '
        .. 'AbilityManaCost `95 110 125 140` and `220 110 0`)')
    assert(bot:GetMana() == 272 and bot:GetMaxMana() == 272,
        'the pool is full at 272; 5e is the observation that 272 < 95 + 220')
end

tests['[real frame] shipped ConsiderQ is silent at level 6'] = function()
    local X = load_frame()
    -- CORRECTED 2026-09-01: this case has never gone red, and until c386d5f3 the
    -- sentence under it read "every branch of ConsiderQ correctly declines".
    -- That reason died with the mana ladder; the outcome did not.  Which one is
    -- doing the work today is 5c's job, not this case's.
    assert(X.ConsiderQ() == 0,
        'at level 6 the shipped function is silent. See 5c for WHY -- today the '
        .. 'reserve answers first, and 5b for the pre-ladder world in which the '
        .. 'branches were the ones declining.')
end

----------------------------------------------------------------------
-- 5b. The recorded reading, rebuilt in the world it was taken in.

tests['[real frame 5b] under the pre-ladder meter the recorded cliff is exact'] = function()
    local d6 = frame_decide(nil, { zero_prices = true })
    local d7, aim7 = frame_decide(7, { zero_prices = true })
    assert(d6 == 0,
        'with every price forced back to 0 -- the meter section 5 was originally '
        .. 'read on -- level 6 is silent, got ' .. tostring(d6))
    assert(d7 == BOT_ACTION_DESIRE_HIGH and aim7 == OD,
        'and level 7 casts at Obsidian Destroyer, got ' .. tostring(d7) .. '/'
        .. tostring(aim7) .. '. This is the whole content of the 2026-08-22 '
        .. 'record and it reproduces exactly, so the record was not wrong -- '
        .. 'its meter is what changed. If THIS goes red, the catch-all itself '
        .. 'moved and sections 1-4 are the place to look.')
end

----------------------------------------------------------------------
-- 5c. The real world: the reserve answers before any branch does.

tests['[real frame 5c] under the real meter BOTH levels are silent, by the reserve'] = function()
    local d6 = frame_decide()
    local d7 = frame_decide(7)
    assert(d6 == 0 and d7 == 0,
        'with Reincarnation priced, neither level casts (got ' .. tostring(d6)
        .. '/' .. tostring(d7) .. ')')
    for _, lv in ipairs({ 6, 7 }) do
        local X, _, bot, _, _, q = load_frame(lv)
        assert(X.ShouldSaveMana(q) == true,
            'and the silence at level ' .. lv .. ' is X.ShouldSaveMana, the '
            .. 'FIRST statement of ConsiderQ -- not a branch declining. This is '
            .. 'the assertion that keeps the level-6 case above from being green '
            .. 'for a reason that stopped being true on 2026-09-01.')
    end
end

tests['[real frame 5c] the reserve boundary is R price + Q price, read off the handles'] = function()
    local _, _, bot, _, _, q = load_frame(7)
    local need = bot:GetAbilityByName(REINC):GetManaCost() + q:GetManaCost()
    assert(need == 315, 'the two handles price the reserve at ' .. need
        .. ', recorded 315; every mana figure in 5c-5e is derived from them')
    local dBelow = frame_decide(7, { mana = need - 1 })
    local dAt    = frame_decide(7, { mana = need })
    assert(dBelow == 0,
        'one mana below the reserve the frame is still silent, got ' .. tostring(dBelow))
    assert(dAt == BOT_ACTION_DESIRE_HIGH,
        'and at exactly ' .. need .. ' it casts, got ' .. tostring(dAt)
        .. '. The boundary is `GetMana() - Qcost < Rcost` and nothing else.')
end

----------------------------------------------------------------------
-- 5d. The dominance result of sections 1-4 is intact -- pay the reserve and the
-- level cliff is back, unchanged, on the same real frame at the same target.

tests['[real frame 5d] above the reserve the level-7 cliff returns, unchanged'] = function()
    local fired, silent = {}, {}
    for lv = 5, 8 do
        local d, aim = frame_decide(lv, { mana = 315 })
        if d > 0 then
            fired[#fired + 1] = lv
            assert(aim == OD, 'level ' .. lv .. ' aimed at ' .. tostring(aim)
                .. ', expected the only enemy in range')
        else
            silent[#silent + 1] = lv
        end
    end
    assert(table.concat(silent, ',') == '5,6' and table.concat(fired, ',') == '7,8',
        'with the reserve paid, levels ' .. table.concat(silent, ',')
        .. ' are silent and ' .. table.concat(fired, ',') .. ' cast; recorded '
        .. '5,6 silent / 7,8 casting. The cliff sections 1-4 measured is the '
        .. 'same cliff, on real frame data -- what 2026-09-01 removed is only '
        .. 'the claim that ONE integer reaches it from this frame.')
end

----------------------------------------------------------------------
-- 5e. On this frame the reserve cannot be paid at all.

tests['[real frame 5e] 315 is more mana than this Wraith King can hold'] = function()
    local _, _, bot, _, _, q = load_frame()
    local need = bot:GetAbilityByName(REINC):GetManaCost() + q:GetManaCost()
    assert(bot:GetMaxMana() < need,
        'this frame\'s pool is ' .. bot:GetMaxMana() .. ' and the reserve wants '
        .. need .. '; if the pool ever reaches the reserve this case is the one '
        .. 'to re-derive, because 5e is the claim that it does not')
    -- The consequence, stated as the reading it is: at this hero level, with
    -- Reincarnation rank 1 and off cooldown, no mana state this frame can reach
    -- lets shipped ConsiderQ cast.  It is not a mock artefact -- the engine has
    -- always priced abilities, so this has been live in every real game; only
    -- our fixtures answered 0, and only until c386d5f3.
    local d = frame_decide(7, { mana = bot:GetMaxMana() })
    assert(d == 0,
        'at a FULL pool of ' .. bot:GetMaxMana() .. ' mana the level-7 frame is '
        .. 'still silent, got ' .. tostring(d) .. '. Wraithfire Blast is '
        .. 'constructively uncastable here, and every archived "ConsiderQ '
        .. 'decides X on frame F" reading taken before 2026-09-01 was taken '
        .. 'with this reserve switched off.')
end

----------------------------------------------------------------------
-- 6. Source ratchets for the constants every read-out above is written against.

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

tests['[GH #104] the overclaim multiplier and the catch-all are still there'] = function()
    local src = read_file(WK_SRC)
    assert(src:find('nDamage * 1.68', 1, true),
        'the 1.68 multiplier is gone from ' .. WK_SRC .. ' -- section 1 measures '
        .. 'it and the recorded 126/176/226/277 is derived from it')
    assert(src:find('nLV >= 7', 1, true),
        "the catch-all's level term is gone from " .. WK_SRC .. '. That term IS '
        .. 'the dominance result: without it, correcting the kill check would '
        .. 'withhold casts instead of re-aiming them, and lever A would be a much '
        .. 'bigger lever than this file says it is.')
    assert(src:find('nCastRange + 43', 1, true) and src:find('nCastRange + 80', 1, true),
        'the two reaches (cast range + 43 for the in-range list, + 80 for the kill '
        .. 'branch) are what make the residual shell 37 units wide')
end

return tests
