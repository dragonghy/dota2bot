-- Replay-fixture regression for hero.md backlog #5 (Axe 跳吼目标质量:
-- 跳进人堆 vs 跳单人).
--
-- Real frame: game 20260721_222428_slot1, t=314.0 (5:14), driven from AXE
-- (a focus hero) rather than the fixture's original subject. Everything the
-- guard reads is real on that frame:
--   * axe, level 7, 629/1719 HP, 151/459 mana,
--   * axe_berserkers_call level 1 with 6.7s of cooldown left -- NOT castable,
--   * lion (enemy, 354/823) ~741 away: inside the blink branch's 500..1200
--     window, so the shipped generic rule would blink onto him this instant,
--   * and NO second enemy hero anywhere near lion -- this is a lone-target
--     chase, not a crowd.
--
-- The shipped offensive-blink branch (X.ConsiderItemDesire['item_blink'], the
-- J.IsGoingOnSomeone case) never looks at Berserker's Call. J.ShouldHoldAxeBlink
-- ForCall must therefore:
--   * stay silent on THIS frame (single target -- finishing a lone hero is a
--     fine dagger use with or without Call), and
--   * fire once the same frame is a crowd and Call is unavailable.
--
-- CAVEATS, stated plainly:
--   1. Axe does NOT carry a blink on this frame (power_treads / vitality_booster
--      / quelling_blade / magic_wand / bracer). The frame pins the guard's
--      INPUTS -- Call level, Call cooldown, mana, and the positions that decide
--      lone-target-vs-crowd -- not the possession of the dagger, which is the
--      consumer's precondition. A real Axe-holding-a-dagger frame is the open
--      half of backlog #5.
--   2. The crowd cases move a real enemy hero from elsewhere on the same frame
--      to lion's side. Those are MUTATIONS, marked as such below; only the
--      non-firing case is the untouched frame.
--   3. Berserker's Call's mana cost is anchored from outside the frame
--      (70 at level 1, Liquipedia 2026-08): make_fixture.py does not dig
--      ability specs, exactly as with WK's Reincarnation cost in
--      tests/test_replay_260725_wk_reincarn_gap.lua.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_222428_lion_lich_burst.lua'
local CALL_MANA_COST_LV1 = 70 -- Liquipedia 2026-08; not carried by the dump.

local tests = {}

--- Load the real frame with AXE as the subject and the gate armed.
local function load_axe()
    local J, bot, heroes, fx = rf.load(FIXTURE, 'npc_dota_hero_axe')
    local call = bot:GetAbilityByName('axe_berserkers_call')
    rawget(call, '__spec').GetManaCost = CALL_MANA_COST_LV1
    J.IsSoakCandidate = function(id) return id == 'axeblink' end
    return J, bot, call, heroes, fx
end

--- The landing point the shipped branch would pick: on top of botTarget.
local function land_on(hTarget)
    return hTarget:GetLocation()
end

tests['ground truth: real frame is axe at 5:14, Call on 6.7s cd, lone lion ~741 away'] = function()
    local J, bot, call, heroes, fx = load_axe()
    assert(fx.time == 314.0, 'frame time')
    assert(bot:GetUnitName() == 'npc_dota_hero_axe', 'subject override took')
    assert(bot:GetHealth() == 629 and bot:GetMaxHealth() == 1719, 'real HP')
    assert(bot:GetMana() == 151 and bot:GetMaxMana() == 459, 'real mana')
    assert(bot:GetLevel() == 7, 'real level')
    assert(call:GetLevel() == 1, 'Call really is learned')
    assert(call:GetCooldownTimeRemaining() == 6.7, 'Call really is on cooldown')
    assert(call:IsFullyCastable() == false, 'so it is not castable this instant')

    local lion = heroes['npc_dota_hero_lion']
    assert(lion:GetTeam() ~= bot:GetTeam(), 'lion is the enemy here')
    local d = GetUnitToUnitDistance(bot, lion)
    assert(d > 700 and d < 780, 'lion really is ~741 away, got ' .. tostring(d))
    -- The shipped branch's own window: > 500 and <= blink cast range.
    assert(d > 500 and d <= 1200, 'the shipped blink branch would fire on this gap')
    -- Lone target: nobody else of lion's team stands with him.
    assert(#J.GetEnemiesNearLoc(land_on(lion), 315) == 1, 'exactly one enemy at the landing point')
end

tests['gate OFF (not turbo): inert, shipped behavior unchanged'] = function()
    local J, bot, _, heroes = load_axe()
    GetGameMode = function() return 1 end -- set after rf.load(); install() forces turbo
    local dp = heroes['npc_dota_hero_death_prophet']
    rawget(dp, '__spec').GetLocation = heroes['npc_dota_hero_lion']:GetLocation()
    assert(J.ShouldHoldAxeBlinkForCall(bot, land_on(heroes['npc_dota_hero_lion'])) == false,
        'outside turbo the guard must never hold a blink')
end

tests['gate OFF (turbo, candidate not armed): inert, shipped behavior unchanged'] = function()
    local J, bot, _, heroes = load_axe()
    J.IsSoakCandidate = function() return false end
    local dp = heroes['npc_dota_hero_death_prophet']
    rawget(dp, '__spec').GetLocation = heroes['npc_dota_hero_lion']:GetLocation()
    assert(J.ShouldHoldAxeBlinkForCall(bot, land_on(heroes['npc_dota_hero_lion'])) == false,
        'turbo alone must not hold a blink without the axeblink id')
end

tests['gate ON, UNTOUCHED real frame: lone target -- the blink is NOT held'] = function()
    local J, bot, _, heroes = load_axe()
    assert(J.ShouldHoldAxeBlinkForCall(bot, land_on(heroes['npc_dota_hero_lion'])) == false,
        'jumping a single hero to finish it stays allowed even with Call down')
end

-- MUTATION of the real frame: bring a second enemy (death prophet, alive on this
-- frame) to lion's side, so the same blink now lands on two heroes.
tests['gate ON, crowd + Call on cooldown: the blink IS held'] = function()
    local J, bot, _, heroes = load_axe()
    local lion = heroes['npc_dota_hero_lion']
    rawget(heroes['npc_dota_hero_death_prophet'], '__spec').GetLocation = lion:GetLocation()
    assert(#J.GetEnemiesNearLoc(land_on(lion), 315) == 2, 'the landing point is now a crowd')
    assert(J.ShouldHoldAxeBlinkForCall(bot, land_on(lion)) == true,
        'no Call, two enemies: a melee body with no lockdown -- hold the dagger')
end

-- The guard keys on CALL AVAILABILITY, not on enemy count: same crowd, Call up.
tests['gate ON, crowd but Call ready: the blink is NOT held'] = function()
    local J, bot, call, heroes = load_axe()
    local lion = heroes['npc_dota_hero_lion']
    rawget(heroes['npc_dota_hero_death_prophet'], '__spec').GetLocation = lion:GetLocation()
    local sp = rawget(call, '__spec')
    sp.GetCooldownTimeRemaining = 0
    sp.IsFullyCastable = true
    assert(bot:GetMana() >= CALL_MANA_COST_LV1, 'and he can pay for it')
    assert(J.ShouldHoldAxeBlinkForCall(bot, land_on(lion)) == false,
        'blink into a crowd WITH Call is exactly what the dagger is for')
end

-- Mana is the other way Call can be unavailable on landing.
tests['gate ON, crowd, Call off cooldown but unaffordable: the blink IS held'] = function()
    local J, bot, call, heroes = load_axe()
    local lion = heroes['npc_dota_hero_lion']
    rawget(heroes['npc_dota_hero_death_prophet'], '__spec').GetLocation = lion:GetLocation()
    local sp = rawget(call, '__spec')
    sp.GetCooldownTimeRemaining = 0
    sp.IsFullyCastable = true
    rawget(bot, '__spec').GetMana = CALL_MANA_COST_LV1 - 1
    assert(J.ShouldHoldAxeBlinkForCall(bot, land_on(lion)) == true,
        'a Call he cannot pay for is a Call he does not have')
end

tests['gate ON, crowd but Call never learned: the blink is NOT held'] = function()
    local J, bot, call, heroes = load_axe()
    local lion = heroes['npc_dota_hero_lion']
    rawget(heroes['npc_dota_hero_death_prophet'], '__spec').GetLocation = lion:GetLocation()
    local sp = rawget(call, '__spec')
    sp.GetLevel = 0
    sp.IsTrained = false
    sp.IsFullyCastable = false
    assert(J.ShouldHoldAxeBlinkForCall(bot, land_on(lion)) == false,
        'with no Call in the build there is no combo to wait for')
end

tests['gate ON, non-Axe subject on the same frame: never held'] = function()
    local J, bot, heroes = rf.load(FIXTURE) -- default subject: lion
    J.IsSoakCandidate = function(id) return id == 'axeblink' end
    assert(bot:GetUnitName() == 'npc_dota_hero_lion', 'default subject unchanged')
    local axe = heroes['npc_dota_hero_axe']
    assert(J.ShouldHoldAxeBlinkForCall(bot, axe:GetLocation()) == false,
        'the guard is Axe-only; it must not touch any other hero blinking')
end

-- Wiring, per the director's #0b lesson (2026-08-19 test_set.md): a helper that
-- is right but unreachable is worth nothing, so pin that the guard actually
-- sits on the offensive-blink decision -- inside the J.IsGoingOnSomeone branch,
-- on the path that returns the HIGH desire.
tests['wiring: the guard gates the offensive blink return in the consumer'] = function()
    local f = assert(io.open('bots/ability_item_usage_generic.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local branch = src:match('X%.ConsiderItemDesire%["item_blink"%].-\n end')
        or src:match('X%.ConsiderItemDesire%["item_blink"%].-\nend')
    assert(branch, 'could not locate the item_blink consider function')
    local guarded = branch:match(
        'and not J%.ShouldHoldAxeBlinkForCall%(bot, vLocation%)%s*\n%s*then%s*\n%s*return BOT_ACTION_DESIRE_HIGH')
    assert(guarded, 'the axeblink guard must gate the offensive blink HIGH return')
    assert(branch:find('J.IsGoingOnSomeone(bot)', 1, true) < branch:find('ShouldHoldAxeBlinkForCall', 1, true),
        'and it must sit inside the going-on-someone (offensive) branch')
end

return tests
