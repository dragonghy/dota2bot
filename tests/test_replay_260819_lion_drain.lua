-- Replay-fixture regression for hero.md backlog: Lion's first individual pass.
--
-- OBSERVATION (5 turbo games from spot_20260819_180804_1_main, dumper at 0.5s;
-- channel windows read off the MODIFIER_ADD/REMOVE pair for
-- modifier_lion_mana_drain, so start and end are ground truth, not inferred):
--   13 Mana Drain channels / 5 games. 5 target creeps, 8 target enemy heroes.
--   In ALL 13, Lion's recorded position does not move by a single unit for the
--   whole channel -- it is a stationary root.
--   3 of the 8 hero-target channels are followed by Lion's death within 12s;
--   all 3 begin with an enemy hero <= 431 units away AND with Lion already
--   taking hero damage in the preceding 2 seconds.
--
-- THE PINNED FRAME (A), game 20260819_183409_slot1, t=255.9 -> death at 264.6:
--   t=255.9  Lion 606/874 HP (69%), 268 mana. Impale cd 12.9, Hex cd 6.9,
--            Finger not yet learned -> Mana Drain is THE ONLY castable spell.
--            earthshaker 261 units away, viper 635. In the previous 2s Lion has
--            taken 249 damage from those two heroes (fissure 71, viper 178).
--   t=256.0  He starts the channel.                              <-- FIXTURE A
--   t=255.9..259.4  He stands at (-6089, 3662) without moving. HP 606 -> 319.
--   t=259.4  The channel is gone; he finally walks, at 44%.
--   t=264.6  Dead. Ground truth in the fixture: died_after = 8.7s.
--
-- WHY THIS IS A BUG AND NOT JUST A LOST FIGHT: the two combat branches of
-- X.ConsiderE sit BELOW `if X.IsOtherAbilityFullyCastable() ... then return 0`,
-- so they only ever fire when Impale, Hex and Finger are ALL unavailable -- the
-- exact state in which a support at melee range should be leaving. Worse, once
-- the channel starts J.CanNotUseAbility( bot ) is true (IsChanneling), so
-- X.SkillsComplement returns on its second line and Lion cannot cast anything
-- at all until it ends; the shipped release, X.ConsiderStopDrain, only fires on
-- J.IsRetreating. Mana Drain has no defensive component whatsoever.
--
-- THE CONTROL FRAME (B), game 20260819_182323_slot1, t=278.0 -> survives:
--   Same structural state -- Impale cd 6, Hex cd 22, Finger unlearned, Mana
--   Drain ready, earthshaker 416 units away (264 half a second later, i.e. the
--   same geometry as frame A) -- but the only damage Lion has taken in the
--   preceding 2s is from CREEPS (16/11/14/12, no hero damage at all). He
--   channels, survives the channel, and does not die inside the 12s window
--   (fixture ground truth: died_after = 12.5s, i.e. past the horizon).
--
-- So A and B differ in the guard's inputs essentially ONLY in "is a hero
-- currently hitting me", and they differ in outcome. That is why the predicate
-- is `WasRecentlyDamagedByAnyHero AND an enemy hero inside the radius` rather
-- than proximity alone -- proximity alone would also refuse frame B.
--
-- FIX: X.lion_IsDrainSafeToStart, gated turbo + 'liondrain', consumed in
-- X.ConsiderE immediately after the IsOtherAbilityFullyCastable early-out, so
-- the mana-refill and illusion-clear branches (which sit above it) are
-- untouched.
--
-- EXTERNAL ANCHORS -- exactly two numbers do not come from the frame:
--   1. Mana Drain cast range = 600 (Liquipedia, 2026-08). make_fixture.py
--      extracts no ability specs, and the mock's generic Get* default is 0,
--      which would put every enemy out of range and make the shipped branch
--      unreachable. Both pinned enemies (261u, 416u) are inside 600 either way,
--      so the guard's verdict does not depend on the exact value.
--   2. Mana Drain mana cost is left at the mock default 0. Lion really held 268
--      and 205 mana on these frames, both above any level-2 cost, so this
--      cannot flip IsFullyCastable in the direction that matters.
--   GetActiveMode / GetAttackTarget are not in the dump either; the end-to-end
--   cases below set them as EXPLICITLY LABELLED mutations (see run_skills).
-- Everything else -- every hero's position, HP, mana, level, ability levels and
-- cooldowns, inventory, alive/dead, and the death ground truth -- is real frame
-- data.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FOCUSED = 'tests/fixtures/f_260819_183409_lion_drain_focused.lua' -- must REFUSE
local CALM    = 'tests/fixtures/f_260819_182323_lion_drain_calm.lua'    -- must ALLOW

local DRAIN_CAST_RANGE = 600        -- external anchor, see header

--- Load a frame, arm/disarm the candidate, return the real hero module.
--- `bDamaged` overrides WasRecentlyDamagedByAnyHero: the dumper's snapshots do
--- not carry it, but the DAMAGE event stream of the very same replay does, and
--- the header records what it says for each frame (A: 249 hero damage in the
--- previous 2s; B: none, creeps only). Passing it explicitly keeps that fact
--- visible instead of hiding it behind the mock's Was* default of false.
local function load_lion(path, bArmed, bDamaged, bTurbo)
    local J, bot, heroes, fx = rf.load(path)

    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function() return bDamaged end
    rawget(bot:GetAbilityByName('lion_mana_drain'), '__spec').GetCastRange = DRAIN_CAST_RANGE

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'liondrain' end
        or function() return false end

    local X = rf.load_hero('lion')
    return X, J, bot, heroes, fx
end

local tests = {}

-- ---------------------------------------------------------------- ground truth

tests['ground truth A: only Mana Drain is castable, a hero is 261 away, Lion dies'] = function()
    local X, _, bot, heroes, fx = load_lion(FOCUSED, true, true)
    assert(fx.time == 255.9, 'fixture A is the pre-channel frame, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_lion', 'subject is Lion')
    assert(bot:GetHealth() == 606 and bot:GetMaxHealth() == 874,
        'real HP on the frame, got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:GetMana() == 268, 'real mana on the frame, got ' .. bot:GetMana())

    -- The precondition that makes this branch reachable at all.
    local abilityQ = bot:GetAbilityByName('lion_impale')
    local abilityW = bot:GetAbilityByName('lion_voodoo')
    local abilityR = bot:GetAbilityByName('lion_finger_of_death')
    local abilityE = bot:GetAbilityByName('lion_mana_drain')
    assert(not abilityQ:IsFullyCastable(), 'Impale is on cooldown (12.9)')
    assert(not abilityW:IsFullyCastable(), 'Hex is on cooldown (6.9)')
    assert(not abilityR:IsTrained(), 'Finger is not learned yet (level 0)')
    assert(abilityE:IsFullyCastable(), 'Mana Drain is the one thing he can cast')
    assert(abilityE:GetLevel() == 2, 'level 2 -- past the nSkillLV <= 1 early-out')
    assert(X.IsOtherAbilityFullyCastable() == false,
        'the shipped guard above the call site must let this frame through')

    local es = heroes['npc_dota_hero_earthshaker']
    assert(es:IsAlive(), 'the threat is alive')
    local d = GetUnitToUnitDistance(bot, es)
    assert(d > 250 and d < 275, 'earthshaker is ~261 away, got ' .. math.floor(d))
    assert(d < X.nEDrainDangerRadius, 'and inside the danger radius')

    -- Ground truth recorded by make_fixture.py from the following 12 seconds.
    assert(fx.observed.died_after ~= nil and fx.observed.died_after < 9.0,
        'Lion really died 8.7s after this frame, got ' .. tostring(fx.observed.died_after))
end

tests['ground truth B: same structural state, no hero damage, Lion survives'] = function()
    local X, _, bot, heroes, fx = load_lion(CALM, true, false)
    assert(fx.time == 278.0, 'fixture B is the control frame, got ' .. tostring(fx.time))
    assert(bot:GetHealth() == 616, 'real HP on the frame, got ' .. bot:GetHealth())
    assert(not bot:GetAbilityByName('lion_impale'):IsFullyCastable(), 'Impale on cooldown (6)')
    assert(not bot:GetAbilityByName('lion_voodoo'):IsFullyCastable(), 'Hex on cooldown (22)')
    assert(not bot:GetAbilityByName('lion_finger_of_death'):IsTrained(), 'Finger unlearned')
    assert(bot:GetAbilityByName('lion_mana_drain'):IsFullyCastable(), 'Mana Drain ready')
    assert(X.IsOtherAbilityFullyCastable() == false,
        'frame B reaches the call site by the same route as frame A')

    local d = GetUnitToUnitDistance(bot, heroes['npc_dota_hero_earthshaker'])
    assert(d > 400 and d < 430, 'earthshaker is ~416 away, got ' .. math.floor(d))
    assert(d < X.nEDrainDangerRadius,
        'and it is INSIDE the danger radius -- so distance alone cannot be the '
        .. 'discriminator between the two frames')
    assert(fx.observed.died_after == nil or fx.observed.died_after >= 12.0,
        'Lion did not die inside the 12s window, got ' .. tostring(fx.observed.died_after))
end

-- ------------------------------------------------------------------- gate off

tests['gate OFF: nothing armed leaves the decision byte-identical to shipped'] = function()
    local X, _, bot = load_lion(FOCUSED, false, true)
    assert(X.lion_IsDrainSafeToStart(bot) == true,
        'unarmed, the helper must be inert (shipped behaviour = always safe)')
end

tests['gate OFF: armed but NOT turbo is still inert'] = function()
    local X, _, bot = load_lion(FOCUSED, true, true, false)
    assert(X.lion_IsDrainSafeToStart(bot) == true, 'the gate is turbo-only')
end

-- ---------------------------------------------------------------- gate armed

tests['armed: refuses the channel on the real frame that got Lion killed'] = function()
    local X, _, bot = load_lion(FOCUSED, true, true)
    assert(X.lion_IsDrainSafeToStart(bot) == false,
        'being hit by a hero with one 261 units away => do not root yourself')
end

tests['armed: allows the control frame (close enemy, but nobody is hitting him)'] = function()
    local X, _, bot = load_lion(CALM, true, false)
    assert(X.lion_IsDrainSafeToStart(bot) == true,
        'creep damage is not hero pressure -- frame B must still channel')
end

tests['armed: frame A without the hero damage would be allowed'] = function()
    -- MUTATION of the real frame: keep the 261-unit earthshaker, drop the
    -- damage clause. Proves the refusal is not distance alone.
    local X, _, bot = load_lion(FOCUSED, true, false)
    assert(X.lion_IsDrainSafeToStart(bot) == true,
        'without incoming hero damage the geometry alone must not refuse')
end

tests['armed: frame B with hero damage added would be refused'] = function()
    -- MUTATION of the real frame: keep the 416-unit earthshaker, add the damage
    -- clause. The mirror of the case above -- both halves of the AND are load
    -- bearing in both directions.
    local X, _, bot = load_lion(CALM, true, true)
    assert(X.lion_IsDrainSafeToStart(bot) == false,
        'a hero hitting him at 416 units is the refusable state')
end

tests['armed: an enemy pushed outside the radius is allowed again'] = function()
    local X, _, bot, heroes = load_lion(FOCUSED, true, true)
    -- MUTATION: move BOTH nearby enemies out past the radius. viper is already
    -- at 635; earthshaker is the one inside, so relocate him to viper's ring.
    local vBot = bot:GetLocation()
    rawget(heroes['npc_dota_hero_earthshaker'], '__spec').GetLocation =
        Vector(vBot.x + 900, vBot.y, vBot.z)
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_earthshaker'])
        > X.nEDrainDangerRadius, 'the mutation really moved him out')
    assert(X.lion_IsDrainSafeToStart(bot) == true,
        'damage from far away does not root-lock him; the channel may start')
end

tests['armed: a dead enemy inside the radius does not count'] = function()
    local X, _, bot, heroes = load_lion(FOCUSED, true, true)
    -- MUTATION: kill the only enemy inside the radius (viper is at 635).
    -- HONESTY NOTE: the corpse is dropped by J.GetNearbyHeroes, which filters
    -- every element through J.IsValidHero -- NOT by a line in the helper (an
    -- earlier draft re-checked validity there; a mutation run showed that check
    -- was unreachable dead code and it was removed). This case is therefore a
    -- CROSS-LAYER tripwire on the contract "a corpse must not keep the guard
    -- latched after a kill", not a test of the helper's own branch.
    rawget(heroes['npc_dota_hero_earthshaker'], '__spec').IsAlive = false
    assert(X.lion_IsDrainSafeToStart(bot) == true,
        'a corpse must not keep the guard latched after a kill')
end

-- ------------------------------------------------------------ radius interval
-- The two frames bound the constant; if someone retunes it, this fails loudly.
-- Lower bound 484: the closest channel in the 5-game census that must still be
-- refused (game 182855 t=297.2, Lion lost 396 HP to it). Upper bound 781: the
-- nearest channel that must stay allowed (game 181755 t=474.4, hero damage
-- present, Lion lost only 67 HP and lived).

tests['radius: the danger radius stays inside the interval the frames support'] = function()
    local X = load_lion(FOCUSED, true, true)
    assert(X.nEDrainDangerRadius >= 484 and X.nEDrainDangerRadius < 781,
        'observed channels bound this to [484, 781), got ' .. X.nEDrainDangerRadius)
end

-- ---------------------------------------------------- end to end (final bid)
-- Drive the real X.ConsiderE through X.SkillsComplement and assert what reaches
-- the action queue, not just the helper's boolean.

local function run_skills(path, bArmed, bDamaged)
    local X, J, bot, heroes, fx = load_lion(path, bArmed, bDamaged)
    local es = heroes['npc_dota_hero_earthshaker']
    -- MUTATIONS: the dump records neither the bot's active mode nor its attack
    -- target, and without them J.IsGoingOnSomeone / J.GetProperTarget cannot
    -- resolve, so the combat branch would be structurally unreachable and every
    -- case below would be a false green. Everything the GUARD itself reads
    -- (position, HP, mana, ability levels/cooldowns, alive) is still real.
    rawget(bot, '__spec').GetActiveMode = BOT_MODE_ATTACK
    rawget(bot, '__spec').GetActiveModeDesire = 0.8
    rawget(bot, '__spec').GetAttackTarget = es
    rawget(bot, '__spec').GetTarget = es
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, X, J, bot, heroes, fx
end

local function ability_names(log)
    local t = {}
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') then
            local a = e.args[1]
            t[#t + 1] = (type(a) == 'table' and a.GetName) and a:GetName() or tostring(a)
        end
    end
    return t
end

local function contains(t, s)
    for _, v in ipairs(t) do if v == s then return true end end
    return false
end

tests['end to end: shipped starts the channel on the frame that killed him'] = function()
    local log = run_skills(FOCUSED, false, true)
    local names = ability_names(log)
    assert(contains(names, 'lion_mana_drain'),
        'shipped Lion queues Mana Drain here -- that is the decision under test, got {'
        .. table.concat(names, ',') .. '}')
end

tests['end to end: armed keeps Mana Drain out of the action queue'] = function()
    local names = ability_names((run_skills(FOCUSED, true, true)))
    assert(not contains(names, 'lion_mana_drain'),
        'the refused channel must not reach the queue, got {'
        .. table.concat(names, ',') .. '}')
end

tests['end to end: the control frame is untouched by the gate'] = function()
    local shipped = ability_names((run_skills(CALM, false, false)))
    local armed   = ability_names((run_skills(CALM, true, false)))
    assert(#armed == #shipped,
        'frame B must decide identically with and without the gate (shipped='
        .. #shipped .. ' armed=' .. #armed .. ')')
    for i = 1, #shipped do
        assert(armed[i] == shipped[i], 'frame B decisions must be identical')
    end
end

-- ------------------------------------------------------- source-level wiring
-- Cheap tripwire: the guard must stay BELOW the IsOtherAbilityFullyCastable
-- early-out (so the mana-refill and illusion branches keep their shipped
-- behaviour) and stay behind its candidate id.

tests['wiring: the guard is consumed in ConsiderE and stays gated'] = function()
    local f = assert(io.open('bots/BotLib/hero_lion.lua'))
    local src = f:read('*a')
    f:close()
    assert(src:find('if not X.lion_IsDrainSafeToStart( bot ) then return 0 end', 1, true),
        'ConsiderE must consume the guard')
    assert(src:find("J.IsSoakCandidate( 'liondrain' )", 1, true),
        'the helper must stay gated behind the liondrain candidate id')
    local iEarlyOut = src:find('if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1', 1, true)
    local iGuard    = src:find('if not X.lion_IsDrainSafeToStart( bot )', 1, true)
    local iRefill   = src:find('--缺蓝的时候抽蓝', 1, true)
    local iIllusion = src:find('--秒杀幻像', 1, true)
    assert(iEarlyOut and iGuard and iRefill and iIllusion, 'all four landmarks exist')
    assert(iRefill < iEarlyOut and iIllusion < iEarlyOut,
        'the refill and illusion branches sit above the shipped early-out')
    assert(iGuard > iEarlyOut,
        'the guard must sit BELOW it, so only the two combat branches are gated')
end

return tests
