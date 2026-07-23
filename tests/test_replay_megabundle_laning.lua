-- [mega-bundle fingerprint 20260723] The residual death signature's three
-- mechanisms, pinned on the batch's own frames (runs spot_20260723_0504*):
--
--   1. COMBAT-RESPONSE FLOOR (f_megabundle_051728_slardar_idle, t=231,
--      died_after=5.7): armed slardar stood at full HP while lion (749u) and
--      sniper (824u) killed it -- the replacement laning Think has no code
--      path that answers hero harassment. J.GetLaneHarassResponse must return
--      a response (fire or back), never nil, on this frame.
--   2. L1TRADE DEPTH LEASH (f_megabundle_052241_sniper_l1trade_chase, t=210,
--      died_after=8.2): sniper+lion chased a 16% zuus to +4400 depth for 20s;
--      ShouldInitiateLaneKill must return nil on a target past the midline.
--   3. DEEP-FRONT HOLD (f_megabundle_051728_ogre_lanefront_deep, t=318,
--      died_after=11.0): solo ogre held the shoved lane front at +2800..+3100;
--      J.IsLaneFrontTooDeepToHold must be TRUE for that spot.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

-- Both games: radiant subject convention for ancients (bottom-left ours).
local function installAncients(J, botTeam)
    GetAncient = function(team) -- luacheck: ignore
        local radiant = api.MakeUnit({ GetLocation = api.Vector(-5900, -5300, 0) })
        local dire = api.MakeUnit({ GetLocation = api.Vector(5900, 5100, 0) })
        if team == 2 then return radiant end
        return dire
    end
end

tests['[mech 1] slardar death frame: harass response exists (fire or back)'] = function()
    local J, bot = rf.load('tests/fixtures/f_megabundle_051728_slardar_idle.lua')
    -- Not captured by the dumper; event stream shows sniper/lion actively
    -- hitting slardar through this window.
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = true
    local sResp, xResp = J.GetLaneHarassResponse(bot)
    assert(sResp == 'fire' or sResp == 'back',
        'the floor must produce SOME combat response on the zero-retaliation '
        .. 'death frame, got: ' .. tostring(sResp))
    assert(xResp ~= nil, 'response payload (target or spot) required')
    if sResp == 'fire' then
        assert(xResp.GetTeam ~= nil and xResp:GetTeam() ~= bot:GetTeam(),
            'fire target must be an enemy hero')
    end
end

tests['[mech 1] no fresh hero damage -> nil (farming stays undisturbed)'] = function()
    local J, bot = rf.load('tests/fixtures/f_megabundle_051728_slardar_idle.lua')
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = false
    assert(J.GetLaneHarassResponse(bot) == nil,
        'the floor only answers active harassment; quiet lanes farm as before')
end

tests['[mech 2] the +4400 chase frame: initiation refuses a past-midline target'] = function()
    local J, bot, heroes = rf.load('tests/fixtures/f_megabundle_052241_sniper_l1trade_chase.lua')
    J.IsSoakCandidate = function(id) return id == 'l1trade' end
    J.IsInLaningPhase = function() return true end
    J.IsCore = function(u) return u == bot end
    installAncients(J)
    assert(J.ShouldInitiateLaneKill(bot) == nil,
        'a kill window deep past the midline is a chase, not a lane kill -- '
        .. 'the leash must refuse it (sniper died at +3667 doing this)')
end

tests['[mech 3] the real death frame: +3300 deep at 2v2 parity -> too deep'] = function()
    -- Ground truth at t=318: ogre+VS (147u apart) held +3300 depth with
    -- nevermore (1271) and CM (1518) visible and centaur closing from 2741.
    -- Both died. Far past the midline, visible parity is NOT safety.
    local J, bot = rf.load('tests/fixtures/f_megabundle_051728_ogre_lanefront_deep.lua')
    installAncients(J)
    assert(J.IsLaneFrontTooDeepToHold(bot, bot:GetLocation()) == true,
        'the exact spot the pair died holding must read as too deep (parity != safety)')
end

tests['[mech 3] shallow-deep front with company -> holdable; alone -> not'] = function()
    local J, bot, heroes = rf.load('tests/fixtures/f_megabundle_051728_ogre_lanefront_deep.lua')
    installAncients(J)
    -- A spot ~1050 past the midline: normal shoved-lane depth.
    local vShallow = api.Vector(4600, -4300, 0)
    assert(J.IsLaneFrontTooDeepToHold(bot, vShallow) == false,
        'with VS 147u beside the ogre a shallow-deep front is a normal stance')
    -- Push every ally out of company range: the same spot is a free pick.
    for _, h in pairs(heroes) do
        if h ~= bot and h:GetTeam() == bot:GetTeam() then
            rawget(h, '__spec').GetLocation = { x = -90000, y = -90000, z = 0 }
            rawset(h, 'GetLocation', nil)
        end
    end
    assert(J.IsLaneFrontTooDeepToHold(bot, vShallow) == true,
        'the same shallow-deep front held ALONE must be pulled back')
end

tests['[mech 3] own-half front is never "too deep"'] = function()
    local J, bot = rf.load('tests/fixtures/f_megabundle_051728_ogre_lanefront_deep.lua')
    installAncients(J)
    assert(J.IsLaneFrontTooDeepToHold(bot, api.Vector(-4000, -2000, 0)) == false,
        'the clamp only bites past the midline; our half holds as before')
end

return tests
