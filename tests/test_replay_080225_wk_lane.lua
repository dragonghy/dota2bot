-- Replay-fixture regression: game 20260720_080225, t=0:47. Wraith King (FOCUS
-- hero) at 13% HP (88/693) stands inside the Shadow Shaman + Juggernaut dual
-- lane (291u / 539u away) and dies 6.1s later -- his first of SEVEN deaths that
-- game (two more by 2:07 in the same spot).
--
-- The fixture caught the PROMOTED anti-dive guard structurally inert here:
-- SafeToCommitFight's numbers branch counted the dying WK plus a lvl-1 support
-- as a full 2v2 -> "parity = safe" -> the documented low-HP clause never ran.
-- Fixed: below 35% HP, parity cannot exempt; only a kill secured WITHOUT the
-- critical bot does. Same lesson as f_071423_luna_chase, now pinned on the
-- promoted guard too.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_080225_wk_lane.lua'
local tests = {}

tests['ground truth: the frame was a feed'] = function()
    local _, _, _, fx = rf.load(FIXTURE)
    assert(fx.observed.died_after ~= nil and fx.observed.died_after < 10,
        'WK died within seconds of this frame')
end

tests['promoted dive guard now fires on the critical-HP lane frame'] = function()
    local J, bot = rf.load(FIXTURE)
    assert(J.GetHP(bot) < 0.35, 'fixture must be a critical-HP frame')
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == true,
        '13%-HP WK inside a dual-lane pocket must hard-retreat')
end

tests['counterfactual: kill secured without him -> guard yields'] = function()
    local J, bot, heroes = rf.load(FIXTURE)
    -- Earthshaker (210u away) alone can finish the low flanker: the pocket is
    -- actually a won fight that does not need WK to tank.
    local es = heroes['npc_dota_hero_earthshaker']
    rawget(es, '__spec').GetEstimatedDamageToTarget = function() return 2000 end
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == false,
        'a kill secured by allies exempts even a critical bot')
end

tests['counterfactual: healthy WK falls through to the sharp clauses'] = function()
    local J, bot = rf.load(FIXTURE)
    rawget(bot, '__spec').GetHealth = bot:GetMaxHealth()
    rawget(bot, '__spec').OriginalGetHealth = bot:GetMaxHealth()
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == false,
        'full-HP WK in the same spot: parity exemption + sharp clauses as before')
end

return tests
