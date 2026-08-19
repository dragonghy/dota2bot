-- [fixture fidelity] Every fixture world had NO buffs and NO debuffs.
--
-- The mock answers `false` to any Is*/Has*/Can* it was not given (bot_api
-- default_for), so until this change `unit:HasModifier(anything)` was false and
-- `NumModifiers()` was 0 for every hero on every frame ever pinned. That is not
-- a missing convenience: it is an undeclared statement about the world -- nobody
-- is rooted, stunned, silenced, hexed, channelling a teleport, or holding any
-- buff -- and the shipped code reads modifiers everywhere.
--
-- Two consequences, both silent:
--
--   1. WHOLE SHIPPED BRANCHES WERE UNREACHABLE IN FIXTURE-LAND. Every
--      continuous-attack branch in mode_roam_generic is entered through a
--      modifier (mask of madness berserk, WK reincarnation, chronosphere,
--      marci unleash, ...); the tpscroll consider function opens with a
--      ten-modifier veto list; J.ShouldAbandonTpChannel (the gated 'tpwatch'
--      candidate, in the eligible set) returns false on its FIRST LINE without
--      `modifier_teleporting`. None of them had ever executed on a real frame.
--   2. A TEST COULD ASSERT THE WRONG THING AND PASS. On the frame below the
--      subject is ROOTED by Frostbite; the old fixture world presents him as
--      free to walk, so "it should have retreated here" would have been
--      assertable about a hero who could not move.
--
-- Same class as the GetTower / GetIncomingTrackingProjectiles gaps
-- (test_set.md §F): a mock default that states a world assumption nobody made.
--
-- REAL FRAME: game 20260819_223607_slot1 @ t=563.5 (9:23), subject sniper.
-- Ground truth from the combat log for the seconds around it:
--
--   562.5  sniper activates Mask of Madness (MODIFIER_ADD berserk, 6.0s)
--   562.5  Crystal Maiden lands Frostbite on him -- he is ROOTED, and indeed
--          does not move between t=562 and t=572
--   560.3  Drow Ranger begins a teleport (MODIFIER_ADD modifier_teleporting)
--   565.3  that teleport COMPLETES -- she took no damage during the channel
--   568.5  berserk expires; 572.2 sniper kills CM; 578.0 sniper dies
--
-- So at t=563.5 the frame carries, simultaneously and for real: a disable
-- (Frostbite, 2.0s left), a self-buff (berserk, 5.0s left), and an enemy
-- mid-teleport (1.8s left). Nothing here is synthesised except where labelled.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F = 'tests/fixtures/f_260819_223607_sniper_rooted.lua'
local F_OLD = 'tests/fixtures/f_231411_ck_zoned.lua' -- pre-modifiers fixture

local SNIPER = 'npc_dota_hero_sniper'
local DROW   = 'npc_dota_hero_drow_ranger'
local CM     = 'npc_dota_hero_crystal_maiden'
local NEVER  = 'npc_dota_hero_nevermore'

local FROSTBITE = 'modifier_crystal_maiden_frostbite'
local BERSERK   = 'modifier_item_mask_of_madness_berserk'
local TELEPORT  = 'modifier_teleporting'

--- Set one already-defaulted engine getter on a mock unit.
local function force(unit, key, value)
    rawget(unit, '__spec')[key] = value
    rawset(unit, key, nil)
end

-- ---------------------------------------------------------------------------
-- Premises: the frame really carries these modifiers, with real durations.
-- ---------------------------------------------------------------------------

tests['premise: the real frame carries a disable, a buff and a live TP channel'] = function()
    local _, bot, heroes = rf.load(F)
    assert(bot:HasModifier(FROSTBITE), 'sniper must be rooted by Frostbite at t=563.5')
    assert(bot:HasModifier(BERSERK), 'sniper must be holding MoM berserk at t=563.5')
    assert(heroes[DROW]:HasModifier(TELEPORT), 'drow must be mid-teleport at t=563.5')
    -- ...and NOT things that were never there.
    assert(not bot:HasModifier('modifier_bloodseeker_rupture'),
        'a modifier the frame does not carry must still answer false')
end

tests['premise: durations are the real remaining seconds, not a placeholder'] = function()
    local J, bot, heroes = rf.load(F)
    -- Frostbite landed at 562.5, so 2.0s of its 3.0s remain at 563.5.
    assert(math.abs(J.GetModifierTime(bot, FROSTBITE) - 2.0) < 0.01,
        'frostbite remaining, got ' .. J.GetModifierTime(bot, FROSTBITE))
    -- Berserk landed at 562.5 and was removed at 568.5 -> 5.0s left.
    assert(math.abs(J.GetModifierTime(bot, BERSERK) - 5.0) < 0.01,
        'berserk remaining, got ' .. J.GetModifierTime(bot, BERSERK))
    -- The channel began at 560.3 and completed at 565.3 -> 1.8s left.
    assert(math.abs(J.GetModifierTime(heroes[DROW], TELEPORT) - 1.8) < 0.01,
        'teleport remaining, got ' .. J.GetModifierTime(heroes[DROW], TELEPORT))
    assert(J.GetModifierTime(bot, 'modifier_nothing_here') == 0,
        'an absent modifier must read 0 seconds, not the first entry')
end

tests['premise: modifiers are per unit, not a shared bag'] = function()
    local _, bot, heroes = rf.load(F)
    assert(not heroes[CM]:HasModifier(BERSERK),
        "the subject's own buff must not leak onto another hero")
    assert(not bot:HasModifier(TELEPORT),
        "another hero's TP channel must not leak onto the subject")
    assert(heroes[CM]:NumModifiers() > 0 and bot:NumModifiers() > 0,
        'both heroes carry their own list')
end

-- ---------------------------------------------------------------------------
-- The gap itself, on a SHIPPED and UNGATED helper: same call, opposite answer.
-- ---------------------------------------------------------------------------

tests['gap: J.CanBeAttacked answers the opposite thing on this frame'] = function()
    -- J.CanBeAttacked is shipped, ungated, and sits under the whole target
    -- selection path. Its second-to-last clause vetoes an ENEMY carrying
    -- modifier_crystal_maiden_frostbite. Sniper is carrying exactly that at
    -- t=563.5, so from Crystal Maiden's side the shipped answer is "no".
    local J, _, heroes = rf.load(F, CM)
    local sniper = heroes[SNIPER]
    assert(sniper:GetTeam() ~= GetTeam(), 'setup: sniper is the enemy here')
    assert(J.CanBeAttacked(sniper) == false,
        'a frostbitten enemy is vetoed by the shipped clause')

    -- Drop only the Frostbite -- everything else about the frame identical --
    -- and the same call flips. That difference is precisely what every fixture
    -- in this repo silently answered before this change.
    local J2, _, heroes2 = rf.load(F, CM)
    local sniper2 = heroes2[SNIPER]
    local kept = {}
    for i = 0, sniper2:NumModifiers() - 1 do
        local n = sniper2:GetModifierName(i)
        if n ~= FROSTBITE then kept[n] = true end
    end
    force(sniper2, 'HasModifier', function(_, s) return kept[s] == true end)
    assert(J2.CanBeAttacked(sniper2) == true,
        'without the root the same enemy is attackable -- so Frostbite, and '
        .. 'nothing else on this frame, is what the veto is reading')
end

-- ---------------------------------------------------------------------------
-- Reachability: 'tpwatch' (this group's gated id, in the eligible set) had
-- never executed a single line of its own logic on a real frame.
-- ---------------------------------------------------------------------------

tests['gap: tpwatch bailed on line 1 in every fixture; now it reaches its body'] = function()
    local J, drow = rf.load(F, DROW)
    J.IsSoakCandidate = function(id) return id == 'tpwatch' end

    -- Entering the body has an observable side effect: the helper stamps the
    -- channel's starting health. Without modifier_teleporting it does the
    -- opposite -- clears the stamp and returns false from the first branch.
    local res = J.ShouldAbandonTpChannel(drow)
    assert(rawget(drow, 'tpChannelStartHealth') == drow:GetHealth(),
        'the channel branch must have been entered (stamp written)')
    -- Correct answer, and for the RIGHT reason: she took zero damage during
    -- this channel and it completed at t=565.3.
    assert(res == false, 'no incoming damage -> do not abandon this channel')

    local J2, sniper = rf.load(F, SNIPER)
    J2.IsSoakCandidate = function(id) return id == 'tpwatch' end
    assert(J2.ShouldAbandonTpChannel(sniper) == false,
        'a hero who is not channelling must answer false')
    assert(rawget(sniper, 'tpChannelStartHealth') == nil,
        'and must NOT have been stamped -- that is the line-1 exit')
end

tests['gap: with the channel present the tpwatch body can also answer true'] = function()
    -- LABELLED SYNTHETIC: the incoming-damage half. This frame's channel was
    -- never contested, so the "yes, abandon" leg needs a hypothetical -- the
    -- point being only that the leg is now REACHABLE at all, which it was not
    -- while modifier_teleporting could never exist.
    local J, drow = rf.load(F, DROW)
    J.IsSoakCandidate = function(id) return id == 'tpwatch' end
    rawset(drow, 'tpChannelStartHealth', drow:GetMaxHealth())
    force(drow, 'GetHealth', math.floor(drow:GetMaxHealth() * 0.6))
    force(drow, 'WasRecentlyDamagedByAnyHero', function() return true end)
    assert(J.ShouldAbandonTpChannel(drow) == true,
        '40% of max HP lost under fresh hero damage must abandon the channel')
end

-- ---------------------------------------------------------------------------
-- Stack counts, and the engine's 0-based indexing the jmz readers assume.
-- ---------------------------------------------------------------------------

tests['stacks come through where the log showed stacking, 0 where it did not'] = function()
    local J, _, heroes = rf.load(F)
    -- Shadow Fiend's Necromastery souls: the log shows repeated stack events on
    -- a single live instance, so the reconstruction reports a count > 1.
    assert(J.GetModifierCount(heroes[NEVER], 'modifier_nevermore_necromastery') > 1,
        'a stacking modifier must report more than one stack')
    -- A plain one-shot debuff has no stack evidence; the engine answers 0 for a
    -- non-stacking modifier and so must the fixture.
    local _, bot = rf.load(F)
    assert(J.GetModifierCount(bot, FROSTBITE) == 0,
        'a non-stacking modifier must report 0, not 1')
end

tests['index reads tolerate the one-past-the-end scan jmz does'] = function()
    local _, bot = rf.load(F)
    local n = bot:NumModifiers()
    assert(n > 0, 'setup: the subject carries modifiers')
    -- J.GetModifierTime / J.GetModifierCount both loop `for i = 0, NumModifiers()`
    -- -- one past the last index. That extra read must be harmless.
    assert(bot:GetModifierName(n) == '', 'one past the end must read as empty')
    assert(bot:GetModifierRemainingDuration(n) == 0, 'and 0 seconds')
    assert(bot:GetModifierStackCount(n) == 0, 'and 0 stacks')
    assert(bot:GetModifierName(0) ~= '', 'index 0 must be the first real entry')
end

-- ---------------------------------------------------------------------------
-- Regression guard: fixtures generated before this field keep the old world.
-- ---------------------------------------------------------------------------

tests['REGRESSION: a pre-modifiers fixture is unchanged'] = function()
    local J, bot = rf.load(F_OLD)
    assert(bot:NumModifiers() == 0, 'no modifier list -> no modifiers')
    assert(bot:HasModifier(FROSTBITE) == false, 'and HasModifier stays false')
    assert(J.GetModifierTime(bot, FROSTBITE) == 0, 'and durations stay 0')
    assert(J.GetModifierCount(bot, FROSTBITE) == 0, 'and stacks stay 0')
end

-- ---------------------------------------------------------------------------
-- Reverse assertions: if either end of the chain is rewritten, say so loudly
-- instead of passing by absence.
-- ---------------------------------------------------------------------------

tests['REVERSE: the fixture must still carry the modifier block'] = function()
    local src = io.open(F, 'r'):read('*a')
    assert(src:find('modifiers = {', 1, true), 'fixture lost its modifiers block')
    assert(src:find(TELEPORT, 1, true), 'fixture lost the live TP channel')
    assert(src:find(FROSTBITE, 1, true), 'fixture lost the root')
end

tests['REVERSE: tpwatch must still gate on the teleport modifier first'] = function()
    local src = io.open('bots/FunLib/jmz_func.lua', 'r'):read('*a')
    assert(src:find("if not bot:HasModifier( 'modifier_teleporting' ) then", 1, true),
        'J.ShouldAbandonTpChannel no longer opens with the channel check -- the '
        .. 'reachability claim in this file must be re-derived')
end

return tests
