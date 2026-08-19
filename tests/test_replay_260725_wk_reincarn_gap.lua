-- Replay-fixture regression for hero.md backlog #6 (follow-up to #1 / GH #17
-- kin). Real frame: game spot_20260725_102532_1_main/20260725_105305_slot1,
-- t=373.5 (6:13). Wraith King (FOCUS hero) is at hero level 6, Reincarnation
-- skill level 1, mana 189/387, ability off cooldown -- squarely inside the
-- 160-219 gap: the shipped hardcoded threshold (mana >= 160) reads ARMED, but
-- the ability's real level-1 mana cost (~220, Liquipedia 2026-08) means it is
-- NOT actually armed yet. mode_retreat_generic would tell WK "you have a free
-- life" here, a false safety net. (In this particular replay WK's mana had
-- regenerated back above 220 by the time he actually died 13.3s later --
-- events confirm an ~219 mana spend at the reincarnation trigger tick -- so
-- the real cost is empirically corroborated; the bug is the false ARMED read
-- at this earlier instant, which could suppress a retreat before mana
-- catches up.)
--
-- J.IsWkReincarnationArmed must read false here with the fix armed, and stay
-- byte-identical (true, the old wrong answer) with the gate off.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_260725_105305_wk_reincarn_gap.lua'
local REAL_COST = 220 -- Reincarnation skill level 1 mana cost (Liquipedia 2026-08)

local tests = {}

-- The fixture doesn't capture ability mana cost (make_fixture.py mines
-- level/cooldown, not spec data), so set it explicitly after loading -- same
-- as hero_skeleton_king.lua's X.ShouldSaveMana reads it via GetManaCost().
local function load_with_cost(cost)
    local J, bot, heroes, fx = rf.load(FIXTURE)
    local abilityR = bot:GetAbilityByName('skeleton_king_reincarnation')
    rawget(abilityR, '__spec').GetManaCost = cost
    return J, bot, heroes, fx
end

tests['ground truth: real frame is WK at 6:13, level 6, mp 189/387, Reincarnation lvl1 ready'] = function()
    local _, bot, _, fx = load_with_cost(REAL_COST)
    assert(fx.self == 'npc_dota_hero_skeleton_king')
    assert(bot:GetMana() == 189, 'mp')
    assert(bot:GetLevel() == 6, 'level')
    local abilityR = bot:GetAbilityByName('skeleton_king_reincarnation')
    assert(abilityR:GetLevel() == 1, 'skill level')
    assert(abilityR:GetCooldownTimeRemaining() == 0, 'ready')
    assert(fx.observed.died_after == 13.3, 'ground truth: he died for real 13.3s later')
end

tests['gate OFF: real frame reads ARMED at the shipped 160 threshold (byte-identical, even though wrong)'] = function()
    local J, bot = load_with_cost(REAL_COST)
    GetGameMode = function() return 1 end -- must set after rf.load() (install() forces turbo)
    J.IsSoakCandidate = function() return false end
    assert(J.IsWkReincarnationArmed(bot) == true,
        'off the candidate, the shipped 160 threshold must stay unchanged (189 >= 160)')
end

tests['gate OFF (turbo but candidate not armed): still the old 160 threshold'] = function()
    local J, bot = load_with_cost(REAL_COST)
    J.IsSoakCandidate = function() return false end
    assert(J.IsWkReincarnationArmed(bot) == true,
        'turbo alone must not flip the threshold without wkreincarnmp')
end

tests['gate ON: real frame (mp=189, skill lvl1, real cost 220) correctly reads NOT armed'] = function()
    local J, bot = load_with_cost(REAL_COST)
    J.IsSoakCandidate = function(id) return id == 'wkreincarnmp' end
    assert(J.IsWkReincarnationArmed(bot) == false,
        'the fix must catch the false-safety-net read: 189 < the real 220 cost, on the actual replay frame')
end

return tests
