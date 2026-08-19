-- Replay-fixture regression for hero.md backlog #3 (魔棒/芒果死手帧).
-- Real frame: game 20260722_181441_slot1, t=660.0 (11:00). Zeus (FOCUS hero)
-- sits at 214/1354 HP -- 15.8% -- roughly 2017 away from the nearest enemy
-- hero (nevermore), ~4599 from his own fountain, and took zero hero damage in
-- the following 5s. This is the d23 `lowhp_limbo` state: drifting at low HP,
-- not healing, not TP-ing, not farming. A magic wand is sitting in his
-- inventory the whole time.
--
-- Every shipped rule in X.ConsiderItemDesire['item_magic_wand'] requires an
-- enemy hero within 1000 (用途1/2/4); the one gated exception ('wandbleed')
-- requires fresh hero damage. On this frame neither holds, so the wand is a
-- dead hand: the bot walks around at 15.8% HP holding an instant heal.
--
-- J.ShouldDrinkWandInLimbo must fire here with 'wandlimbo' armed and stay
-- inert (false) with the gate off, so shipped behavior is byte-identical.
--
-- CAVEAT, stated plainly: the dumper does NOT record item charges (there is no
-- "charge" key anywhere in tools/batch_test/behavioral/dumper/), so the charge
-- count is the ONE number in these tests supplied from outside the frame.
-- Position, HP, max HP, roster, alive/dead and inventory contents are all real.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua'

local tests = {}

-- Load the frame and put `n` charges on the real magic wand handle.
local function load_with_charges(n)
    local J, bot, heroes, fx = rf.load(FIXTURE)
    local slot = bot:FindItemSlot('item_magic_wand')
    assert(slot >= 0, 'the real frame must carry a magic wand')
    local wand = bot:GetItemInSlot(slot)
    rawget(wand, '__spec').GetCurrentCharges = n
    J.IsSoakCandidate = function(id) return id == 'wandlimbo' end
    return J, bot, wand, heroes, fx
end

tests['ground truth: real frame is zuus at 11:00, 214/1354 HP, wand held, nearest enemy ~2017'] = function()
    local J, bot, wand, heroes, fx = load_with_charges(12)
    assert(fx.self == 'npc_dota_hero_zuus')
    assert(fx.time == 660.0, 'frame time')
    assert(bot:GetHealth() == 214 and bot:GetMaxHealth() == 1354, 'real HP')
    assert(bot:GetHealth() / bot:GetMaxHealth() < 0.16, 'real HP fraction')
    assert(wand:GetName() == 'item_magic_wand', 'wand handle')
    -- Nobody inside the shipped rules' 1000 radius, nobody inside our 1600.
    assert(#J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE) == 0, 'no enemy inside 1000')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0, 'no enemy inside 1600')
    local nm = heroes['npc_dota_hero_nevermore']
    local d = GetUnitToUnitDistance(bot, nm)
    assert(d > 2000 and d < 2050, 'nearest enemy really is ~2017 away, got ' .. tostring(d))
    assert(J.GetDistanceFromAllyFountain(bot) > 2500, 'really far from our own fountain')
    -- Ground truth from the replay: nobody damaged him in the next 5s and he
    -- did not die -- a quiet drift, not a fight.
    assert(next(fx.observed.burst) == nil, 'no enemy dealt damage in the window')
    assert(fx.observed.died_after == nil, 'he did not die in the window')
end

tests['gate OFF (not turbo): inert, shipped behavior unchanged'] = function()
    local J, bot, wand = load_with_charges(20)
    GetGameMode = function() return 1 end -- set after rf.load(); install() forces turbo
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == false,
        'outside turbo the helper must never fire')
end

tests['gate OFF (turbo, candidate not armed): inert, shipped behavior unchanged'] = function()
    local J, bot, wand = load_with_charges(20)
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == false,
        'turbo alone must not fire the fix without the wandlimbo id')
end

tests['gate ON: the real dead-hand frame drinks (12 charges)'] = function()
    local J, bot, wand = load_with_charges(12)
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == true,
        'at 15.8% HP with nobody within 1600 and a charged wand, drink it')
end

tests['gate ON: a token 3-charge sip is not worth the item'] = function()
    local J, bot, wand = load_with_charges(3)
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == false,
        'below the 6-charge floor the draught is not worth spending')
end

tests['gate ON: an enemy inside 1600 hands the frame back to the shipped rules'] = function()
    local J, bot, wand, heroes = load_with_charges(12)
    -- Walk the nearest enemy onto him: the same frame, but now it is a fight,
    -- which 用途1 (<40% HP, enemy inside 1000) already owns.
    local loc = bot:GetLocation()
    local nm = heroes['npc_dota_hero_nevermore']
    rawget(nm, '__spec').GetLocation = { x = loc.x + 900, y = loc.y, z = 0 }
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 1, 'enemy is now nearby')
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == false,
        'this branch is the quiet drift only; a live fight belongs to 用途1')
end

tests['gate ON: above a quarter HP the charges are still worth banking'] = function()
    local J, bot, wand = load_with_charges(12)
    rawget(bot, '__spec').GetHealth = 500 -- 500/1354 = 36.9%
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == false,
        '<=25% HP is the trigger; 36.9% must not fire')
end

tests['gate ON: on our own fountain doorstep the HP is free anyway'] = function()
    local J, bot, wand = load_with_charges(12)
    rawget(bot, '__spec').GetLocation = { x = -6619, y = -6336, z = 384 }
    assert(J.GetDistanceFromAllyFountain(bot) <= 2500, 'moved onto the fountain')
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == false,
        'no point spending charges where regeneration is free')
end

-- Synthetic (NOT from the frame): the no-overheal invariant. On this frame it
-- can never bind -- 25% HP of a 1354 pool leaves 1140 missing while 20 charges
-- restore only 300 -- so shrink the pool to exercise the guard directly.
tests['gate ON: never drink when part of the draught would overheal'] = function()
    local J, bot, wand = load_with_charges(20)
    -- Both halves stay under the 25% trigger so the HP guard cannot be what
    -- decides them; only the missing-HP-vs-draught check differs.
    rawget(bot, '__spec').GetMaxHealth = 380
    rawget(bot, '__spec').GetHealth = 90 -- 23.7% of the pool, 290 missing < 20 * 15
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == false, 'overheal guard')
    rawget(bot, '__spec').GetHealth = 60 -- 15.8%, 320 missing >= 20 * 15
    assert(J.ShouldDrinkWandInLimbo(bot, wand) == true, 'full draught lands')
end

return tests
