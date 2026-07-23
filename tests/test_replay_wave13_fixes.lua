-- [wave13 fingerprint 20260723] The two mechanism fixes, pinned on the
-- REJECT wave's own frames:
--
--   1. COMMIT SELF-RELEASE (f_163714, t=35): level-1 zuus stood at 188u of
--      Sven for 5s while being ground 100->34% (died 5.7s after the frame) --
--      the 0.95 collapse bid outbid the promoted lanesurv retreat (0.75) and
--      the per-frame-renewed commit-lock made kiting impossible.
--      J.ShouldReleaseLaneCommit must be TRUE on this frame.
--   2. PULL PEACETIME VETO (f_163732, t=305): SK left lane and paced beside
--      the camp waiting for the :12 window while Ogre watched from ~1700 for
--      10 straight seconds; PA arrived, SK died 6s later (died_after=18 from
--      the earlier pin). J.IsLanePullSafe must be FALSE on this frame.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

tests['[commit release] the dying zuus frame releases the collapse'] = function()
    local J, bot = rf.load('tests/fixtures/f_163714_zuus_commit_pin.lua')
    -- Event-stream ground truth for the instant between the 1Hz snapshots:
    -- sven actively hitting zuus (100->34% over 4s), hp ~50% at t=35.
    local sp = rawget(bot, '__spec')
    sp.WasRecentlyDamagedByAnyHero = true
    sp.GetHealth = math.floor(bot:GetMaxHealth() * 0.50)
    sp.OriginalGetHealth = sp.GetHealth
    assert(J.ShouldReleaseLaneCommit(bot) == true,
        'zuus died 5.7s after this frame -- the collapse must release and '
        .. 'let retreat win the desire auction')
end

tests['[commit release] a healthy untouched initiator keeps the commit'] = function()
    local J, bot = rf.load('tests/fixtures/f_163714_zuus_commit_pin.lua')
    local sp = rawget(bot, '__spec')
    sp.WasRecentlyDamagedByAnyHero = false
    sp.GetHealth = bot:GetMaxHealth()
    sp.OriginalGetHealth = bot:GetMaxHealth()
    -- lanesurv must also stay quiet for the keep-commit case.
    J.ShouldRetreatLaneBurst = function() return false end
    assert(J.ShouldReleaseLaneCommit(bot) == false,
        'full-HP, untouched, no burst threat -> finish the trade (anti-osc)')
end

tests['[pull veto] the SK ambush frame is NOT pull-safe (Ogre visible 1700)'] = function()
    local J, bot = rf.load('tests/fixtures/f_163732_sk_pull_ambush.lua')
    assert(J.IsLanePullSafe(bot) == false,
        'an enemy watching from 1700 makes the pull window a trap -- SK died '
        .. 'mid-pull-wait doing exactly this')
end

tests['[pull veto] same spot with every enemy far away IS pull-safe'] = function()
    local J, bot, heroes = rf.load('tests/fixtures/f_163732_sk_pull_ambush.lua')
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() then
            rawget(h, '__spec').GetLocation = { x = -90000, y = -90000, z = 0 }
            rawset(h, 'GetLocation', nil)
        end
    end
    assert(J.IsLanePullSafe(bot) == true,
        'with nobody visible the pull proceeds as designed (peacetime)')
end

tests['[pull veto] a half-HP puller is vetoed even in an empty jungle'] = function()
    local J, bot, heroes = rf.load('tests/fixtures/f_163732_sk_pull_ambush.lua')
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() then
            rawget(h, '__spec').GetLocation = { x = -90000, y = -90000, z = 0 }
            rawset(h, 'GetLocation', nil)
        end
    end
    local sp = rawget(bot, '__spec')
    sp.GetHealth = math.floor(bot:GetMaxHealth() * 0.4)
    sp.OriginalGetHealth = sp.GetHealth
    assert(J.IsLanePullSafe(bot) == false,
        'a wrecked puller tanks the camp and dies (watched skywrath at 50%/0 mana)')
end

return tests
