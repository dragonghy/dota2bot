-- Replay-fixture regression: game 20260819_005355_slot1, t=10:31. DIRE Dragon
-- Knight auto-attacked RADIANT Luna (333u away, 54% hp, 6892 net worth) while
-- RADIANT Lina (729u away, 93% hp, 11683 net worth -- 1.7x Luna's) sat
-- unengaged. Ground truth: Lina dealt 1299 dmg to DK over the next 5s (vs
-- Luna's 131) and DK died 4.2s later, killed by the hero it never targeted.
-- [strategy] issue #26 ("focus-fire ignores who's snowballing").
--
-- Investigation finding (see iterations/reports/strategy/ for this session):
-- Lina's distance (729u) is well outside Dragon Knight's melee attack range
-- (~150 + bounding radius) -- she was never a reachable auto-attack target at
-- this instant, so this frame does NOT exercise an in-range target-priority
-- decision (J.GetAttackableWeakestUnitFromList and friends). It instead pins
-- an out-of-range ranged-threat/disengage gap, a different lever than "target
-- scoring". This test only pins the tooling fix from this session (net worth
-- is now captured end-to-end: dumper -> make_fixture.py -> replay_fixture.lua
-- mock loader) plus the ground-truth story, so future work on either lever
-- (retreat-from-untouchable-threat, or a genuine same-range multi-candidate
-- fixture for target-priority scoring) can build on real, verified data
-- instead of re-deriving it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_631400_dragon_knight_snowballtarget.lua'
local tests = {}

tests['net worth is wired end-to-end from the fixture'] = function()
    local _, _, heroes = rf.load(FIXTURE)
    assert(heroes['npc_dota_hero_lina']:GetNetWorth() == 11683,
        'Lina net worth must come from the real dump, not a stub')
    assert(heroes['npc_dota_hero_luna']:GetNetWorth() == 6892,
        'Luna net worth must come from the real dump, not a stub')
    assert(heroes['npc_dota_hero_lina']:GetNetWorth() > heroes['npc_dota_hero_luna']:GetNetWorth() * 1.5,
        'Lina must be the clearly-ahead hero in this frame (the whole point of the fixture)')
end

tests['ground truth: Lina was the real threat, not Luna'] = function()
    local _, _, _, fx = rf.load(FIXTURE)
    assert(fx.observed.burst['npc_dota_hero_lina'] > fx.observed.burst['npc_dota_hero_luna'] * 5,
        'Lina must be captured as the dominant damage source, not the engaged Luna')
    assert(fx.observed.died_after ~= nil and fx.observed.died_after <= 5,
        'fixture must capture that the subject died within the window')
end

tests['Lina was out of Dragon Knight melee range at this instant'] = function()
    local _, bot, heroes = rf.load(FIXTURE)
    local dist = GetUnitToUnitDistance(bot, heroes['npc_dota_hero_lina'])
    local meleeRange = bot:GetAttackRange() + bot:GetBoundingRadius()
    assert(dist > meleeRange,
        'this frame must NOT be an in-range attack-priority decision -- Lina must be unreachable, ' ..
        'which is why no target-scoring fix was implemented against this fixture')
end

return tests
