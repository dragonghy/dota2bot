-- GH #488, answered at source level: the replay-side reconstruction of
-- X.ConsiderSanitysEclipse's SHIPPED exit reports "两个合取项都假" on the
-- baseline frame t=1211.8, and one of those two halves is not false.
--
-- WHAT #488 OBSERVED (replay-check 2026-09-04T13:02Z, W45 corpus). On a leg
-- where `odaoe` is provably disarmed, OD cast Sanity's Eclipse at t=1211.8.
-- The reconstruction evaluated the shipped predicate's two conjuncts --
--   (R) #nInRangeAlly >= #nTargetInRangeAlly     (the ally ring)
--   (K) J.CanKillTarget(enemyHero, base + |manaGap| * mult, MAGICAL)
-- -- and reported BOTH false, concluding the reconstruction must be incomplete
-- and that `odaoe`'s condition (a) cannot be bought until it is explained.
--
-- WHAT THIS FILE SHOWS. (R) was evaluated for exactly two enemies, juggernaut
-- (613u) and pudge (659u), who were standing next to each other -- so each one
-- carried the other in its own 1200 ring and the comparison read 1 >= 2. That
-- is a property of THAT PAIR, not of the frame. (R) is a `>=`, and against an
-- ISOLATED enemy both sides collapse to the same number, so it reads TRUE --
-- and it reads TRUE precisely when OD has NO allies nearby, which is the
-- situation #488 describes. Removing every ally from OD does not close the ring
-- conjunct; it opens it for every loner in cast range.
--
-- ⇒ the frame has ONE load-bearing conjunct, (K), and (K) is a pure function of
-- the three runtime inputs #488 already flagged as unreadable from the replay
-- (base_damage, damage_multiplier, GetCastRange). Section 4 closes that box:
-- across the WHOLE range the 2026-08-21 datafeed allows for those three, (K)
-- is still false on #488's own numbers, by a factor of 2.15 -- so none of the
-- issue's first three hypotheses can explain the cast, and the search has to
-- move. Section 5 hands over the probe that would explain it.
--
-- ZERO BEHAVIOUR CHANGE: no file under bots/ or game/ is touched by this
-- change, no gate id is added, nothing is armed or promoted.
--
-- THE FRAME IS REAL, THE MUTATIONS ARE LABELLED. #488's own frame is not
-- dumped (re-dumping it is replay-check's ball, behind GH #478), so every case
-- here runs on the REAL SOLO fixture from GH #54 --
-- f_260819_222559_od_eclipse_solo.lua, 20260819_222559_slot1 @ t=661.5 -- whose
-- topology is the one #488 describes: exactly one enemy hero (the lich, 583.1u)
-- inside the 700 cast range, and no ally of that lich within 1200 of it. Every
-- departure from that frame is applied through __spec and named in the case
-- that applies it. Nothing is written to tests/fixtures/.
--
-- EXTERNAL ANCHORS (same five as tests/test_replay_260819_od_eclipse_aoe.lua,
-- read from the game's own KV, because make_fixture.py extracts no ability
-- specs and the mock's generic Get* default is 0): AbilityCastRange 700,
-- radius 500/525/550, base_damage 200/300/400, damage_multiplier 0.4,
-- AbilityManaCost 200/300/400.
--
-- HONEST BOUNDARIES:
--   1. tests/mock/bot_api.lua's GetActualIncomingDamage default returns the RAW
--      damage -- "no reduction modelled", an explicit UPPER bound on what
--      reaches a unit. Sections 1-3 run on that default, so a branch that
--      REFUSES there refuses a fortiori in a real match. Section 4 additionally
--      installs #488's own 25% magic resistance per unit, so its verdict does
--      not depend on which of the two conventions the reader prefers.
--   2. This file says nothing about whether the ring conjunct is a GOOD
--      condition, and proposes no change to it. It measures what the shipped
--      code does, so that a reading taken off the replay can be checked
--      against it.
--   3. #488's HP figures are sampled at t=1211.4, 0.4s BEFORE the cast. Health
--      in a fight generally falls, so an earlier instant is generally HARDER to
--      kill, not easier -- the section 4 bound is conservative in the right
--      direction. It is NOT conservative against a heal, and it says nothing
--      about an enemy who was alive at the order instant and dead by the
--      sample (see section 5).
--   4. Whether the engine's GetNearbyHeroes includes the calling unit itself is
--      not settled here; the loader excludes it. Section 2 asserts the
--      conclusion under BOTH conventions, because (R) compares two rings built
--      the same way and a constant added to both sides cancels.
--
-- WHAT THE MUTATION STAND CHANGED ABOUT THIS FILE (tools/agent/mutstand_odring.sh,
-- 6/6 caught). The first draft was 10 cases, green on the first run, and BLIND
-- to the one operator it is about: with `>=` mutated to `>` it still passed
-- 10/10. Two independent reasons, both worth carrying:
--   * the stand's anchor was not unique -- the same ally-ring comparison
--     appears THREE times in hero_obsidian_destroyer.lua (:242 arcane orb,
--     :403, :558 eclipse) -- so the mutant landed on a different ability. The
--     stand now aborts on a non-unique anchor instead of scoring SURVIVED.
--   * and the draft genuinely had no case where (R) is what REFUSES: every
--     case ran on a topology where the ring conjunct was true, so deleting it
--     outright changed nothing either. Cases 2d and 2e are that missing pair --
--     2d rebuilds #488's own clustered topology and must refuse, 2e hands OD
--     one ally back and the same pair must cast.
-- A green suite over a claim nothing can falsify is the failure mode this
-- file's own subject is an instance of; it was also, for one run, the file.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SOLO = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'

local ULT_NAME       = 'obsidian_destroyer_sanity_eclipse'
local ULT_CAST_RANGE = 700   -- external anchors, see header
local ULT_RADIUS     = 500
local ULT_BASE_DMG   = 200
local ULT_MULTIPLIER = 0.4
local ULT_MANA_COST  = 200

local OD    = 'npc_dota_hero_obsidian_destroyer'
local LICH  = 'npc_dota_hero_lich'

-- #488's own numbers for the baseline frame 20260904_065910_slot5 @ t=1211.8.
local F488_OD_MANA_AT_CAST = 1874   -- back-computed in the issue: 1574 + 300
local F488_LOWEST_HP       = 1858   -- juggernaut, the cheapest kill in range
local F488_TARGET_MANA     = 616    -- the mana the issue's damage bound uses
local F488_MAGIC_RESIST    = 0.25   -- corroborated there by 556 actually dealt
local KV_BASE_DAMAGE_MAX   = 400    -- datafeed 2026-08-21: 200/300/400
local KV_MULTIPLIER        = 0.4

--- Load the SOLO frame with the ability's KV on spec, `odaoe` DISARMED (this
--- whole file is about the shipped exit), and OD in a mode J.IsGoingOnSomeone
--- accepts.
--- MUTATION, labelled: GetActiveMode is not in the dump.
local function load_shipped(nBaseDamage)
    local J, bot, heroes, fx = rf.load(SOLO)

    local sp = rawget(bot:GetAbilityByName(ULT_NAME), '__spec')
    sp.GetCastRange = ULT_CAST_RANGE
    sp.GetManaCost = ULT_MANA_COST
    sp.GetSpecialValueInt = function(_, key)
        if key == 'radius' then return ULT_RADIUS end
        return 0
    end
    sp.GetSpecialValueFloat = function(_, key)
        if key == 'base_damage' then return nBaseDamage or ULT_BASE_DMG end
        if key == 'damage_multiplier' then return ULT_MULTIPLIER end
        return 0
    end

    J.IsSoakCandidate = function() return false end   -- shipped exit only

    local X = rf.load_hero('obsidian_destroyer')
    rawget(bot, '__spec').GetActiveMode = BOT_MODE_ATTACK
    return X, J, bot, heroes, fx
end

--- MUTATION, labelled: park one hero far enough away that no 1200 ring holds
--- it. The frame's own coordinates are otherwise untouched.
local function park_far(hero)
    rawget(hero, '__spec').GetLocation = function()
        return { x = 20000, y = 20000, z = 0 }
    end
end

--- Every living ally of OD that the frame puts inside the 1200 ring.
local function ally_ring(J, unit)
    return J.GetNearbyHeroes(unit, 1200, false, BOT_MODE_NONE) or {}
end

--- Drive the real X.SkillsComplement() and report the eclipse's target point.
local function cast_location(X, bot)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    for _, e in ipairs(log) do
        local a = e.args[1]
        if e.fn:find('UseAbilityOnLocation')
            and type(a) == 'table' and a.GetName and a:GetName() == ULT_NAME
        then
            return e.args[2]
        end
    end
    return nil
end

local tests = {}

-- ------------------------------------------------- 1. the frame, unmutated

tests['1. ground truth: the SOLO frame has #488\'s topology -- one enemy in range, and that enemy is alone'] = function()
    local _, J, bot, heroes = load_shipped()

    local lich = heroes[LICH]
    local d = GetUnitToUnitDistance(bot, lich)
    assert(d > 580 and d < 590, 'the lich is 583.1u away, got ' .. math.floor(d))
    assert(d < ULT_CAST_RANGE, 'and inside the 700 cast range')

    local inRangeEnemy = J.GetNearbyHeroes(bot, ULT_CAST_RANGE, true, BOT_MODE_NONE)
    assert(#inRangeEnemy == 1,
        'exactly ONE enemy hero inside cast range, got ' .. #inRangeEnemy)
    assert(inRangeEnemy[1]:GetUnitName() == LICH, 'and it is the lich')

    -- The lich carries no ally of its own in 1200: this is what "isolated"
    -- means for the ring conjunct, and it is real frame data, not a mutation.
    assert(#ally_ring(J, lich) == 0,
        'the lich has no living ally within 1200, got ' .. #ally_ring(J, lich))

    assert(bot:GetAbilityByName(ULT_NAME):IsFullyCastable(),
        'the ultimate is ready and affordable on this frame')
end

tests['1b. on the unmutated frame the ring conjunct is ALREADY true, and only (K) refuses'] = function()
    local X, J, bot, heroes = load_shipped()

    local lich = heroes[LICH]
    local nOwn    = #ally_ring(J, bot)
    local nTarget = #ally_ring(J, lich)
    assert(nOwn == 3,
        'OD really does have 3 allies inside 1200 here (dragon_knight, '
        .. 'juggernaut, lina), got ' .. nOwn)
    assert(nTarget == 0, 'and the lich has none, got ' .. nTarget)
    assert(nOwn >= nTarget, '(R) is TRUE on the real frame')

    -- (K) is what refuses, and it refuses NARROWLY: raw damage 709.2 against
    -- 712 current health, under the mock's no-reduction upper bound.
    local nRaw = ULT_BASE_DMG + math.abs(bot:GetMana() - lich:GetMana()) * ULT_MULTIPLIER
    assert(math.abs(nRaw - 709.2) < 0.5, 'raw damage 709.2, got ' .. nRaw)
    assert(lich:GetHealth() == 712, 'lich health 712, got ' .. lich:GetHealth())
    assert(not J.CanKillTarget(lich, nRaw, DAMAGE_TYPE_MAGICAL), '(K) is FALSE')

    assert(cast_location(X, bot) == nil, 'so the shipped exit casts nothing')
end

-- ---------------------------------- 2. #488's claim about the ring conjunct

tests['2. THE FINDING: stripping every ally from OD does NOT make (R) false against a loner'] = function()
    local _, J, bot, heroes = load_shipped()

    -- MUTATION, labelled: park OD's three nearby allies outside every ring, so
    -- the frame matches #488's "零队友" exactly.
    for _, sName in ipairs({ 'npc_dota_hero_dragon_knight',
                             'npc_dota_hero_juggernaut',
                             'npc_dota_hero_lina' }) do
        park_far(heroes[sName])
    end

    local lich = heroes[LICH]
    local nOwn    = #ally_ring(J, bot)
    local nTarget = #ally_ring(J, lich)
    assert(nOwn == 0, 'OD now stands alone, got ' .. nOwn .. ' allies in 1200')
    assert(nTarget == 0, 'and so does the lich, got ' .. nTarget)

    -- This is the half of #488 that does not hold. `>=`, not `>`.
    assert(nOwn >= nTarget,
        '(R) is still TRUE with zero allies: 0 >= 0. #488 reports (R) false '
        .. 'for the frame, having evaluated it only for juggernaut and pudge, '
        .. 'who stood 46u apart and therefore each carried the other.')
end

tests['2b. the conclusion does not depend on whether GetNearbyHeroes counts self'] = function()
    -- (R) compares two rings built by the SAME call with the same radius, so a
    -- self term appears on both sides and cancels. #488 reads 1 >= 2 (self
    -- included); the loader reads 0 >= 1 for the same pair. Both are false, and
    -- for a loner both conventions give 1 >= 1 / 0 >= 0, both TRUE.
    local SELF_INCLUDED, SELF_EXCLUDED = 1, 0
    for _, nSelf in ipairs({ SELF_INCLUDED, SELF_EXCLUDED }) do
        -- the #488 pair: OD alone, target carries one ally
        assert(not ((0 + nSelf) >= (1 + nSelf)),
            'the clustered pair closes (R) under either convention')
        -- an isolated enemy, OD alone
        assert((0 + nSelf) >= (0 + nSelf),
            'a loner opens (R) under either convention')
    end
end

tests['2d. the clustered pair DOES close (R) -- reproducing #488\'s juggernaut/pudge topology'] = function()
    local X, J, bot, heroes = load_shipped()
    for _, sName in ipairs({ 'npc_dota_hero_dragon_knight',
                             'npc_dota_hero_juggernaut',
                             'npc_dota_hero_lina' }) do
        park_far(heroes[sName])
    end

    local lich, medusa = heroes[LICH], heroes['npc_dota_hero_medusa']
    -- MUTATION, labelled: stand the second enemy 46u from the first, the gap
    -- #488 reports between juggernaut (613u) and pudge (659u). Both stay inside
    -- the 700 cast range. Nothing else about the frame moves.
    local vLich = lich:GetLocation()
    rawget(medusa, '__spec').GetLocation = function()
        return { x = vLich.x + 46, y = vLich.y, z = vLich.z }
    end
    -- MUTATION, labelled: both are individually killable, so nothing but (R)
    -- can be what refuses.
    rawget(lich, '__spec').GetHealth = 300
    rawget(medusa, '__spec').GetHealth = 300

    assert(#ally_ring(J, bot) == 0, 'OD stands alone')
    assert(#ally_ring(J, lich) == 1, 'and each enemy now carries the other')
    assert(J.CanKillTarget(lich, 709.2, DAMAGE_TYPE_MAGICAL), '(K) is true for the lich')

    assert(cast_location(X, bot) == nil,
        'no cast: 0 >= 1 is FALSE. THIS is the reading #488 took, and it is '
        .. 'correct -- for a clustered pair.')
end

tests['2e. give OD one ally back and the same pair casts: (R) is a ring COMPARISON, not a headcount'] = function()
    local X, J, bot, heroes = load_shipped()
    -- Same mutations as 2d, except that ONE ally stays where the frame put it.
    for _, sName in ipairs({ 'npc_dota_hero_dragon_knight',
                             'npc_dota_hero_juggernaut' }) do
        park_far(heroes[sName])
    end

    local lich, medusa = heroes[LICH], heroes['npc_dota_hero_medusa']
    local vLich = lich:GetLocation()
    rawget(medusa, '__spec').GetLocation = function()
        return { x = vLich.x + 46, y = vLich.y, z = vLich.z }
    end
    rawget(lich, '__spec').GetHealth = 300
    rawget(medusa, '__spec').GetHealth = 300

    assert(#ally_ring(J, bot) == 1, 'lina alone is still with OD, got ' .. #ally_ring(J, bot))
    assert(#ally_ring(J, lich) == 1, 'against the pair, got ' .. #ally_ring(J, lich))

    assert(cast_location(X, bot) ~= nil,
        'it casts: 1 >= 1. The conjunct never asked for a majority.')
end

tests['2c. and with OD alone the shipped exit still refuses -- (K) is the whole barrier'] = function()
    local X, J, bot, heroes = load_shipped()
    for _, sName in ipairs({ 'npc_dota_hero_dragon_knight',
                             'npc_dota_hero_juggernaut',
                             'npc_dota_hero_lina' }) do
        park_far(heroes[sName])
    end
    assert(#ally_ring(J, bot) == 0, 'OD stands alone')
    assert(cast_location(X, bot) == nil,
        'no cast -- but the reason is (K), not (R)')
end

-- ------------------------------- 3. two-sided pin: (K) alone decides the frame

tests['3. drop the loner under the damage and the shipped exit FIRES, on the hero\'s own location'] = function()
    local X, J, bot, heroes = load_shipped()
    for _, sName in ipairs({ 'npc_dota_hero_dragon_knight',
                             'npc_dota_hero_juggernaut',
                             'npc_dota_hero_lina' }) do
        park_far(heroes[sName])
    end

    local lich = heroes[LICH]
    -- MUTATION, labelled: the ONE datum that separates this case from 2c.
    rawget(lich, '__spec').GetHealth = 709   -- raw damage is 709.2

    assert(J.CanKillTarget(lich, 709.2, DAMAGE_TYPE_MAGICAL), '(K) is now TRUE')

    local v = cast_location(X, bot)
    assert(v ~= nil, 'the shipped exit casts once (K) flips, with zero allies present')

    -- The shipped branch returns enemyHero:GetLocation(), never a midpoint --
    -- this is the source fact #488 leans on to build its non-hero-centre
    -- discriminator, pinned here so that discriminator keeps its meaning.
    local vLich = lich:GetLocation()
    assert(math.abs(v.x - vLich.x) < 0.01 and math.abs(v.y - vLich.y) < 0.01,
        'and the circle is centred exactly on the enemy hero')
end

tests['3b. one point of health the other way and it refuses again'] = function()
    local X, _, bot, heroes = load_shipped()
    for _, sName in ipairs({ 'npc_dota_hero_dragon_knight',
                             'npc_dota_hero_juggernaut',
                             'npc_dota_hero_lina' }) do
        park_far(heroes[sName])
    end
    rawget(heroes[LICH], '__spec').GetHealth = 710   -- one point above 709.2
    assert(cast_location(X, bot) == nil, 'refuses -- the pin is two-sided')
end

-- ---------------- 4. the KV box #488 flagged cannot produce the observed cast

tests['4. THE CLOSED BOX: no datafeed-legal KV assignment makes (K) true on #488\'s numbers'] = function()
    local X, J, bot, heroes = load_shipped(KV_BASE_DAMAGE_MAX)
    for _, sName in ipairs({ 'npc_dota_hero_dragon_knight',
                             'npc_dota_hero_juggernaut',
                             'npc_dota_hero_lina' }) do
        park_far(heroes[sName])
    end

    -- MUTATIONS, labelled: #488's own readings for the baseline frame, moved
    -- onto this frame's handles. Health/mana/resistance only; nobody moves.
    local lich = heroes[LICH]
    local spOD, spT = rawget(bot, '__spec'), rawget(lich, '__spec')
    spOD.GetMana   = F488_OD_MANA_AT_CAST
    spT.GetMana    = F488_TARGET_MANA
    spT.GetHealth  = F488_LOWEST_HP
    spT.GetActualIncomingDamage = function(_, dmg) return dmg * (1 - F488_MAGIC_RESIST) end

    -- The best case the datafeed allows: the top rank's base damage, the whole
    -- mana gap, and the multiplier as published.
    local nRawMax = KV_BASE_DAMAGE_MAX
        + math.abs(F488_OD_MANA_AT_CAST - F488_TARGET_MANA) * KV_MULTIPLIER
    assert(math.abs(nRawMax - 903.2) < 0.5, 'best-case raw damage 903.2, got ' .. nRawMax)

    -- What (K) demands, through the real helper rather than by hand.
    assert(not J.CanKillTarget(lich, nRawMax, DAMAGE_TYPE_MAGICAL),
        '(K) is false even at the top of the KV box')

    -- ...and by how much. 1858 / 0.75 = 2477.3 raw needed.
    local nNeeded = F488_LOWEST_HP / (1 - F488_MAGIC_RESIST)
    assert(nNeeded / nRawMax > 2.7,
        'the shortfall is 2.7x, got ' .. string.format('%.2f', nNeeded / nRawMax))

    assert(cast_location(X, bot) == nil,
        'so the shipped exit cannot have produced #488\'s cast on these numbers')
end

tests['4b. the multiplier would have to be 2.8x its published value, and cast range cannot help at all'] = function()
    -- The multiplier that would close the gap, if damage_multiplier were the
    -- misread input: (needed - base_max) / manaGap.
    local nNeeded  = F488_LOWEST_HP / (1 - F488_MAGIC_RESIST)
    local nManaGap = math.abs(F488_OD_MANA_AT_CAST - F488_TARGET_MANA)
    local nMultNeeded = (nNeeded - KV_BASE_DAMAGE_MAX) / nManaGap
    assert(nMultNeeded > 1.6,
        'needs multiplier > 1.6 against a published 0.4, got '
        .. string.format('%.3f', nMultNeeded))
    assert(nMultNeeded / KV_MULTIPLIER > 4.0,
        'i.e. more than 4x off, got ' .. string.format('%.2f', nMultNeeded / KV_MULTIPLIER))

    -- GetCastRange is the third suspect, and it is the one that cannot help in
    -- EITHER direction: enlarging it only admits enemies FARTHER away, and on
    -- #488's frame every farther enemy has MORE health than the 1858 this
    -- section already failed to reach (lina 1902 at 2165u, skeleton_king 3169
    -- at 5991u). Shrinking it admits fewer. There is no value of cast range at
    -- which the shipped exit fires on that frame.
    local F488_FARTHER_HP = { 1902, 3169 }
    for _, hp in ipairs(F488_FARTHER_HP) do
        assert(hp > F488_LOWEST_HP,
            'every enemy admitted by a larger cast range is tankier than the '
            .. 'one already out of reach, got ' .. hp)
    end
end

-- -------------------------------------- 5. the probe that WOULD explain it

tests['5. hand-off: the health at or below which the shipped exit does fire on that frame'] = function()
    -- Same box, solved for health instead of damage. An enemy hero inside cast
    -- range at or below this, isolated (or with no more allies around it than
    -- OD has), makes the shipped exit fire with no KV misread at all.
    local nRawMax = KV_BASE_DAMAGE_MAX
        + math.abs(F488_OD_MANA_AT_CAST - F488_TARGET_MANA) * KV_MULTIPLIER
    local nExplains = nRawMax * (1 - F488_MAGIC_RESIST)
    assert(math.abs(nExplains - 677.4) < 1.0,
        'the explanatory threshold is 677 effective health, got '
        .. string.format('%.1f', nExplains))

    -- #488 lists one enemy hero as ALREADY DEAD at its t=1211.4 sample: zuus.
    -- A hero who was alive and under this threshold at the ORDER instant and
    -- dead by the sample is invisible to a reconstruction taken at the sample,
    -- satisfies both conjuncts, and puts the circle on a hero's location --
    -- every observable #488 reports, with no unreadable input involved. That
    -- is the cheapest next probe: zuus's death timestamp against 1211.8.
    assert(nExplains < F488_LOWEST_HP,
        'and it sits well under the cheapest LIVING target in range, which is '
        .. 'why a dead-by-sample enemy is the leading explanation')
end

return tests
