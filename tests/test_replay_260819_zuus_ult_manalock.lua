-- Replay-fixture regression for hero.md backlog #4 (Zeus 大招击杀确认), the
-- non-vision half that GH #36 unblocked.
--
-- OBSERVATION (frame-by-frame, game 20260819_142047_slot1, dumper at 0.5s):
--   t=213.5  Zeus dings 6. Thundergod's Wrath goes to level 1, cooldown 0.
--            He is holding 55 mana. The ult costs 246 (see anchors below).
--   t=225.5  He spends 94 on Arc Lightning into a dragon_knight sitting at
--            971/1072 HP (90.6%), 573 units away.        <-- FIXTURE A
--   t=241.5  He spends 49 more on Heavenly Jump into the same fight.
--            The dragon_knight is back to 999 HP by t=251.
--   t=278.5  An enemy lich falls to 149 HP -- then 119, 63, 55, 39, 30, 28,
--            25, 11 -- 7678 units away, i.e. reachable by NOTHING Zeus owns
--            except the global ult, which is still off cooldown. Zeus has
--            190 mana against a 246 cost, so abilityR:IsFullyCastable() is
--            false and X.ConsiderR returns on its first line.  <-- FIXTURE B
--   t=283.0  The lich dies to somebody else. Zeus gets nothing.
--   t=296.2  Zeus finally casts his first ult of the game, at 253 mana --
--            reached by regeneration alone, 83 seconds after it came up.
--
-- The two chip casts cost 143 mana, which is the whole gap between t=278.5's
-- 190 and the 246 he needed. That is the decision this gate refuses.
--
-- FIX: X.zuus_ShouldSaveManaForUlt, gated turbo + 'zusult', consumed in
-- X.SkillsComplement where castQDesire / castWDesire become the final bid.
-- It fires only while the ult is trained, off cooldown and NOT yet affordable,
-- and only against a healthy enemy hero. A kill window (target under
-- X.nUltSaveHealthFloor), a creep, and retreating all outrank the reserve.
--
-- EXTERNAL ANCHOR -- exactly ONE number does not come from the frame:
--   Thundergod's Wrath level-1 mana cost = 246. make_fixture.py extracts no
--   ability specs (same caveat as wkreincarnmp's GetManaCost). This value is
--   MEASURED IN THIS VERY REPLAY rather than taken from a wiki: Zeus's mana
--   goes 253 -> 7 across the t=296.2 cast in this game, and the three level-1
--   casts in the sibling game 20260819_121901_slot1 show 257->15, 824->579 and
--   848->601 (242 / 245 / 247, spread by 0.5s of regen). Liquipedia's ability
--   page agrees the cost is in the 200s at level 1.
-- Everything else -- Zeus's mana, level, the ult's level and cooldown, every
-- hero's HP/position/inventory, alive/dead -- is real frame data.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local LOCK   = 'tests/fixtures/f_260819_142047_zuus_ult_manalock.lua'  -- must HOLD
local DENIED = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'    -- must RELEASE

local ULT_MANA_COST = 246           -- external anchor, see header
local ULT_NAME      = 'zuus_thundergods_wrath'

--- Load a frame, anchor the ultimate's mana cost, arm/disarm the candidate.
--- Returns X (the real hero module), J, bot, heroes, the ult handle and the fx.
local function load_zeus(path, bArmed, bTurbo)
    local J, bot, heroes, fx = rf.load(path)

    local sAbilityList = J.Skill.GetAbilityList(bot)
    -- GH #36: before ability_meta.lua taught the loader which name is the
    -- ultimate, this slot was nil in EVERY fixture and any ultimate logic
    -- short-circuited before it was reached. Assert it, so a regression there
    -- fails here loudly instead of turning these cases into a false green.
    assert(sAbilityList[6] == ULT_NAME,
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    rawget(abilityR, '__spec').GetManaCost = ULT_MANA_COST

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'zusult' end
        or function() return false end

    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, abilityR, fx
end

local tests = {}

-- ---------------------------------------------------------------- ground truth

tests['ground truth A: t=225.5, ult level 1 off cooldown, 99 mana vs 246 cost'] = function()
    local X, J, bot, heroes, abilityR, fx = load_zeus(LOCK, true)
    assert(fx.time == 225.5, 'fixture A is the Arc Lightning frame')
    assert(bot:GetUnitName() == 'npc_dota_hero_zuus', 'subject is Zeus')
    assert(bot:GetLevel() == 6, 'Zeus just dinged 6, got ' .. bot:GetLevel())
    assert(bot:GetMana() == 99, 'real mana on the frame, got ' .. bot:GetMana())
    assert(abilityR:IsTrained(), 'the ult is learned on this frame')
    assert(abilityR:GetLevel() == 1, 'ult level 1')
    assert(abilityR:GetCooldownTimeRemaining() == 0, 'ult is off cooldown')
    assert(not abilityR:IsFullyCastable(),
        '99 mana cannot pay 246 -- this is exactly why ConsiderR bails')
    local dk = heroes['npc_dota_hero_dragon_knight']
    assert(dk:IsAlive(), 'the harass target is alive')
    local nHP = dk:GetHealth() / dk:GetMaxHealth()
    assert(nHP > X.nUltSaveHealthFloor,
        'the target is healthy (' .. string.format('%.3f', nHP) .. '), i.e. chip')
    local d = GetUnitToUnitDistance(bot, dk)
    assert(d > 400 and d < 700, 'dragon_knight is ~573 away, got ' .. math.floor(d))
    assert(X.zuus_ShouldSaveManaForUlt ~= nil, 'the helper is exported')
end

tests['ground truth B: t=278.5, a 149-HP lich 7678 away and 190 mana vs 246'] = function()
    local _, J, bot, heroes, abilityR, fx = load_zeus(DENIED, true)
    assert(fx.time == 278.5, 'fixture B is the denied-execute frame')
    assert(bot:GetMana() == 190, 'real mana on the frame, got ' .. bot:GetMana())
    assert(abilityR:IsTrained() and abilityR:GetCooldownTimeRemaining() == 0,
        'the ult is trained and off cooldown -- only mana is missing')
    assert(not abilityR:IsFullyCastable(), '190 mana cannot pay 246')
    local lich = heroes['npc_dota_hero_lich']
    assert(lich:GetHealth() == 149, 'lich is at 149 HP, got ' .. lich:GetHealth())
    local d = GetUnitToUnitDistance(bot, lich)
    assert(d > 7000, 'lich is ~7678 away -- global ult only, got ' .. math.floor(d))
    -- 149 HP is far under a level-1 Thundergod's Wrath even through base magic
    -- resist; the kill was free and the mana was the only thing missing.
    assert(lich:GetHealth() < ULT_MANA_COST, 'sanity: a trivially lethal target')
end

-- ------------------------------------------------------------------- gate off

tests['gate OFF: nothing armed leaves the frame byte-identical to shipped'] = function()
    local X, _, bot, heroes = load_zeus(LOCK, false)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_dragon_knight']) == false,
        'unarmed, the helper must be inert')
end

tests['gate OFF: armed but NOT turbo is still inert'] = function()
    local X, _, bot, heroes = load_zeus(LOCK, true, false)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_dragon_knight']) == false,
        'the gate is turbo-only')
end

-- ---------------------------------------------------------------- gate armed

tests['armed: holds the chip spend on the real frame'] = function()
    local X, _, bot, heroes = load_zeus(LOCK, true)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_dragon_knight']) == true,
        'ult armed-but-unaffordable + healthy target => save the mana')
end

tests['armed: already affordable => nothing is being denied, so no hold'] = function()
    local X, _, bot, heroes = load_zeus(LOCK, true)
    rawget(bot, '__spec').GetMana = ULT_MANA_COST      -- MUTATION of the real frame
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_dragon_knight']) == false,
        'the reserve only matters while the ult is mana-locked')
end

tests['armed: ult on cooldown => no reserve to defend'] = function()
    local X, _, bot, heroes, abilityR = load_zeus(LOCK, true)
    rawget(abilityR, '__spec').GetCooldownTimeRemaining = 30  -- MUTATION
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_dragon_knight']) == false,
        'a 30s-away ult is not worth starving harass for')
end

tests['armed: ult not trained => no reserve to defend'] = function()
    local X, _, bot, heroes, abilityR = load_zeus(LOCK, true)
    rawget(abilityR, '__spec').GetLevel = 0                   -- MUTATION (pre-level-6)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_dragon_knight']) == false,
        'before level 6 there is nothing to save for')
end

tests['armed: a kill window outranks the reserve'] = function()
    local X, _, bot, heroes = load_zeus(LOCK, true)
    local dk = heroes['npc_dota_hero_dragon_knight']
    rawget(dk, '__spec').GetHealth = math.floor(dk:GetMaxHealth() * 0.30)  -- MUTATION
    assert(X.zuus_ShouldSaveManaForUlt(bot, dk) == false,
        'a kill in hand beats a snipe later')
end

tests['armed: the health floor is the hinge, and it is 0.6'] = function()
    local X, _, bot, heroes = load_zeus(LOCK, true)
    local dk = heroes['npc_dota_hero_dragon_knight']
    local nMax = dk:GetMaxHealth()
    -- Pin the constant itself: whoever retunes it makes this test say so.
    assert(X.nUltSaveHealthFloor == 0.6, 'health floor is 0.6')
    rawget(dk, '__spec').GetHealth = math.ceil(nMax * 0.61)   -- MUTATION
    assert(X.zuus_ShouldSaveManaForUlt(bot, dk) == true, 'just above the floor: hold')
    rawget(dk, '__spec').GetHealth = math.floor(nMax * 0.59)  -- MUTATION
    assert(X.zuus_ShouldSaveManaForUlt(bot, dk) == false, 'just below the floor: spend')
end

tests['armed: retreating outranks the reserve'] = function()
    local X, J, bot, heroes = load_zeus(LOCK, true)
    rawget(bot, '__spec').GetActiveMode = BOT_MODE_RETREAT           -- MUTATION
    rawget(bot, '__spec').GetActiveModeDesire = BOT_MODE_DESIRE_HIGH -- MUTATION
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = true         -- MUTATION
    assert(J.IsRetreating(bot), 'the mutation really put the bot in retreat')
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_dragon_knight']) == false,
        'fleeing beats hoarding')
end

tests['armed: creeps keep the shipped rules -- farm is not this gate\'s business'] = function()
    local X, _, bot = load_zeus(LOCK, true)
    local tCreeps = bot:GetNearbyLaneCreeps(2000, true)
    assert(X.zuus_ShouldSaveManaForUlt(bot, tCreeps[1]) == false,
        'a nil/creep target must never be held (got a hold)')
end

tests['armed on frame B: the 21%-HP lich is a kill window, not chip'] = function()
    local X, _, bot, heroes = load_zeus(DENIED, true)
    local lich = heroes['npc_dota_hero_lich']
    assert(lich:GetHealth() / lich:GetMaxHealth() < X.nUltSaveHealthFloor,
        'the lich is under the floor on the real frame')
    assert(X.zuus_ShouldSaveManaForUlt(bot, lich) == false,
        'the gate must never stand between Zeus and a dying enemy')
end

-- ------------------------------------------------------------------ end to end
-- Per test_set.md §0b: assert the FINAL decision, not the helper's return value.
-- X.SkillsComplement is the only caller of ConsiderQ/ConsiderW, and the gate sits
-- between their bid and the ActionQueue_* call, so driving it here covers the
-- whole consumption path.

--
-- LABELLED MUTATIONS, and why they are unavoidable: the harass branches of
-- ConsiderQ/ConsiderW are reached through J.IsGoingOnSomeone + J.GetProperTarget,
-- i.e. through GetActiveMode() and the current attack target -- and the dumper
-- records NEITHER (the same offline gap the cmrguard work hit, GH #27 family).
-- Untouched, this frame bids DESIRE_NONE for every spell, so the gate's effect
-- on the final decision would be unobservable. So the run below (a) puts Zeus in
-- BOT_MODE_ATTACK on the dragon_knight he was in fact fighting on this frame,
-- and (b) anchors the two harass cast ranges, which make_fixture.py cannot
-- extract: Arc Lightning 900, Lightning Bolt 700 (Liquipedia). Everything the
-- gate itself reads -- ult level, ult cooldown, ult mana cost, Zeus's mana, the
-- target's HP fraction, the retreat flag -- stays real frame data, and the
-- ground-truth cases above assert those directly.
local ARC_RANGE, BOLT_RANGE = 900, 700     -- external anchors, see above

--- Run the real X.SkillsComplement() on a frame and return the recorded actions.
local function run_skills(path, bArmed)
    local X, J, bot, heroes, abilityR, fx = load_zeus(path, bArmed)
    local dk = heroes['npc_dota_hero_dragon_knight']
    rawget(bot, '__spec').GetActiveMode = BOT_MODE_ATTACK           -- MUTATION
    rawget(bot, '__spec').GetActiveModeDesire = 0.8                 -- MUTATION
    rawget(bot, '__spec').GetAttackTarget = dk                      -- MUTATION
    rawget(bot, '__spec').GetTarget = dk                            -- MUTATION
    rawget(bot:GetAbilityByName('zuus_arc_lightning'), '__spec').GetCastRange = ARC_RANGE
    rawget(bot:GetAbilityByName('zuus_lightning_bolt'), '__spec').GetCastRange = BOLT_RANGE
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, X, J, bot, heroes, abilityR, fx
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

-- CORRECTED 2026-09-01 (hero).  This case used to assert that shipped Zeus
-- fires LIGHTNING BOLT here, and it was green -- against this file's own header,
-- which records the replay's ground truth as "t=225.5 he spends 94 on ARC
-- LIGHTNING".  The assertion and the observation named different spells for two
-- weeks and nothing raised a hand, because tests/mock/replay_fixture.lua left
-- `GetManaCost` off the ability spec: it fell through to bot_api's generic
-- `^Get` default, answered 0 for every ability, and made the mana term of
-- IsFullyCastable the tautology `GetMana() >= 0`.  In that world Lightning Bolt
-- was affordable at any mana and outbid Arc Lightning.
--
-- This file was ALSO the one place the price was partly charged -- load_zeus
-- anchors the ultimate's handle to 246 -- which is precisely why the two
-- ground-truth cases above have always been honest while this one was not: the
-- workaround covered the ult and nothing else, so the basic abilities stayed
-- free and the end-to-end leg drifted off the frame it claims to reproduce.
--
-- With the loader charging the KV ladder, the arithmetic on this frame is:
--   99 mana | Arc Lightning rank 3 = 95  AFFORDABLE (leaves 4)
--           | Lightning Bolt rank 1 = 120  NOT
--           | Thundergod's Wrath    = 246  NOT
-- So the lever's premise is unchanged and SHARPER, not weakened: shipped Zeus
-- still leaks the ult reserve into a 90.6%-HP target, and it leaks 95 of the 99
-- mana he is holding.  Lightning Bolt is asserted UNAFFORDABLE rather than
-- merely unchosen, so this case cannot go green again on a free-mana world.
tests['end to end: shipped spends the reserve on the healthy target'] = function()
    local log, _, _, bot, _, abilityR = run_skills(LOCK, false)
    local names = ability_names(log)

    local arc  = bot:GetAbilityByName('zuus_arc_lightning')
    local bolt = bot:GetAbilityByName('zuus_lightning_bolt')
    assert(arc:GetManaCost() == 95, 'Arc Lightning rank 3 costs 95, got ' .. arc:GetManaCost())
    assert(bolt:GetManaCost() == 120, 'Lightning Bolt rank 1 costs 120, got ' .. bolt:GetManaCost())
    assert(not bolt:IsFullyCastable(),
        'Lightning Bolt is UNAFFORDABLE at 99 mana -- the free-mana world is what '
        .. 'used to let this case name it')

    assert(contains(names, 'zuus_arc_lightning'),
        'shipped Zeus fires Arc Lightning into the 90.6%-HP dragon_knight, as the '
        .. 'replay itself did at t=225.5, got {' .. table.concat(names, ',') .. '}')
    assert(not contains(names, ULT_NAME),
        'and it is NOT the ult: ' .. bot:GetMana() .. ' mana cannot pay '
        .. abilityR:GetManaCost())

    -- The leak, stated as the number the reserve loses.
    assert(bot:GetMana() - arc:GetManaCost() == 4,
        'the chip cast leaves 4 of 99 mana against a 246 ult, got '
        .. (bot:GetMana() - arc:GetManaCost()))
end

tests['end to end: armed holds it -- the final decision changes, not just the helper'] = function()
    local armed = ability_names((run_skills(LOCK, true)))
    assert(not contains(armed, 'zuus_lightning_bolt'),
        'the held Lightning Bolt must not reach the action queue, got {'
        .. table.concat(armed, ',') .. '}')
    assert(not contains(armed, 'zuus_arc_lightning'),
        'nor may the bid fall through to Arc Lightning on the same target, got {'
        .. table.concat(armed, ',') .. '}')
end

tests['end to end: frame B is untouched by the gate'] = function()
    local shipped = ability_names((run_skills(DENIED, false)))
    local armed   = ability_names((run_skills(DENIED, true)))
    assert(#armed == #shipped,
        'the nearest enemy on frame B is 7000+ away, so the gate holds nothing '
        .. '(shipped=' .. #shipped .. ' armed=' .. #armed .. ')')
    for i = 1, #shipped do
        assert(armed[i] == shipped[i], 'frame B decisions must be identical')
    end
end

-- ------------------------------------------------------- source-level wiring
-- Cheap tripwire: the consumption point must stay attached to BOTH bids. The
-- end-to-end cases above only exercise whichever spell wins on these two frames.

tests['wiring: SkillsComplement gates both the Q and the W bid'] = function()
    local f = assert(io.open('bots/BotLib/hero_zuus.lua'))
    local src = f:read('*a')
    f:close()
    -- GH #59 added a third argument (the bidding ability's own handle, so the
    -- `zusultx` domain can price the spend). The literals below move with it;
    -- what they pin -- that both bids still route through the one gate -- does not.
    assert(src:find('castQDesire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castQTarget, abilityQ )', 1, true),
        'the Arc Lightning bid must pass through the reserve gate')
    assert(src:find('castWDesire > 0 and X.zuus_ShouldSaveManaForUlt( bot, castWTarget, abilityW )', 1, true),
        'the Lightning Bolt bid must pass through the reserve gate')
    assert(src:find("J.IsSoakCandidate( 'zusult' )", 1, true),
        'the helper must stay gated behind the zusult candidate id')
end

return tests
