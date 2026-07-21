-- Replay-fixture regression: game 20260720_071423, t=5:09. Luna (354/934 HP,
-- 38%) kept chasing a 26%-HP Jakiro past the enemy tower while a FULL-HP
-- Slardar stood 120u away; Slardar dealt her 286 damage over the next 5s
-- (fixture ground truth) and she died 4.0s later. Silencer followed and died
-- too. The owner called this chase "非常不理智" watching the replay.
--
-- This test rebuilds that exact instant under the mock API (no J.* stubs -- the
-- real helpers run on the real positions/HP/teams) and pins the fixed decision:
-- J.ShouldNotChaseWhenLow must FIRE here. It also pins why the first cut was
-- wrong: SafeToCommitFight reads the visible 2v2 as parity=safe, which is the
-- wrong exemption when the bot itself is the low one.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_071423_luna_chase.lua'
local tests = {}

local function armed()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'lf_chase' end
    return J, bot, heroes, fx
end

tests['ground truth: the frame really was fatal'] = function()
    local _, _, _, fx = armed()
    assert(fx.observed.died_after ~= nil and fx.observed.died_after <= 5,
        'fixture must capture that Luna died within the window')
    assert((fx.observed.burst['npc_dota_hero_slardar'] or 0) > 200,
        'fixture must capture Slardar as the real punisher')
end

tests['the guard FIRES on the real fatal chase frame'] = function()
    local J, bot, heroes = armed()
    assert(J.ShouldNotChaseWhenLow(bot, heroes['npc_dota_hero_jakiro']) == true,
        'Luna at 38% chasing into a full-HP Slardar must stop chasing')
end

tests['why the first cut failed: visible numbers parity reads this as safe'] = function()
    -- Documents the trap: 2v2 on paper (38%-Luna + lvl4-Silencer vs Jakiro +
    -- full Slardar) makes SafeToCommitFight true. The guard must NOT delegate
    -- its exception to it. If this assert ever flips, re-examine the guard.
    local J, bot, heroes = armed()
    assert(J.SafeToCommitFight(bot, heroes['npc_dota_hero_jakiro']) == true,
        'expected the numbers branch to (wrongly) call this frame safe')
end

tests['counterfactual: a healthy Luna may keep chasing'] = function()
    local J, bot, heroes = armed()
    rawget(bot, '__spec').GetHealth = bot:GetMaxHealth()
    assert(J.ShouldNotChaseWhenLow(bot, heroes['npc_dota_hero_jakiro']) == false,
        'full-HP Luna in the same spot is allowed to fight')
end

tests['counterfactual: kill secured without her -> yield'] = function()
    local J, bot, heroes = armed()
    rawget(heroes['npc_dota_hero_silencer'], '__spec').GetEstimatedDamageToTarget =
        function() return 400 end -- Silencer alone finishes the 274-HP Jakiro
    assert(J.ShouldNotChaseWhenLow(bot, heroes['npc_dota_hero_jakiro']) == false,
        'if allies secure the kill without her tanking, do not block it')
end

tests['gate off: shipped default is unchanged'] = function()
    local J, bot, heroes = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldNotChaseWhenLow(bot, heroes['npc_dota_hero_jakiro']) == false,
        'off the candidate the guard must stay inert')
end

return tests
