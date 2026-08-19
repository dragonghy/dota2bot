-- Replay-fixture regression for hero.md backlog #2 (CM ult timing). Real
-- frame: game spot_20260819_001007_1_main/20260819_003005_slot1, t=373.4
-- (6:13). Crystal Maiden opens Freezing Field (ConsiderR) while Jakiro --
-- ice_path off cooldown, a curated hard-CC ability (J.tHardCcAbilities) --
-- is closing from ~1139 units with no ally CC covering him. Ground truth:
-- Jakiro's Ice Path stunned CM 0.6s into the channel (cut from the 10s max
-- to 0.6s) and she died 5.9s later from the resulting chain-CC.
--
-- X.cm_IsRSafeToOpen must read false here with the fix armed (withhold R),
-- and stay byte-identical (true, the old always-allow behavior) with the
-- gate off.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_260819_003005_cm_selfpreserve.lua'

local tests = {}

tests['ground truth: real frame is CM at 6:13, 815/846 hp, Jakiro (ice_path ready) closing'] = function()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    assert(fx.self == 'npc_dota_hero_crystal_maiden')
    assert(bot:GetHealth() == 815, 'hp')
    assert(bot:GetMaxHealth() == 846, 'max hp')
    local jakiro = heroes['npc_dota_hero_jakiro']
    assert(jakiro ~= nil, 'jakiro present')
    local icePath = jakiro:GetAbilityByName('jakiro_ice_path')
    assert(icePath:GetCooldownTimeRemaining() == 0, 'ice_path off cooldown at the decision instant')
    assert(J.HasReadyHardCc(jakiro) == true, 'jakiro reads as a ready hard-CC threat via the curated table')
    assert(fx.observed.died_after == 5.9, 'ground truth: CM died for real 5.9s later')
end

tests['gate OFF: real frame allows the cast (byte-identical, even though it got her killed)'] = function()
    local J, bot = rf.load(FIXTURE)
    GetGameMode = function() return 1 end -- must set after rf.load() (install() forces turbo)
    J.IsSoakCandidate = function() return false end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'off the candidate, the shipped always-allow behavior must stay unchanged')
end

tests['gate OFF (turbo but candidate not armed): still always allows'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'turbo alone must not flip the gate without cmrguard')
end

tests['gate ON: real frame (Jakiro ice_path ready, 1139u away) correctly withholds R'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'the fix must catch the imminent hard-CC threat on the actual replay frame that got CM killed')
end

tests['gate ON, no ready hard CC nearby: allows the cast (proves the gate tracks the threat, not just presence)'] = function()
    local J, bot, heroes = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    local jakiro = heroes['npc_dota_hero_jakiro']
    local icePath = jakiro:GetAbilityByName('jakiro_ice_path')
    rawget(icePath, '__spec').GetCooldownTimeRemaining = 12.0
    rawget(icePath, '__spec').IsFullyCastable = false
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'with Jakiro\'s ice_path on cooldown, no other nearby enemy has a ready hard CC -- must allow')
end

return tests
