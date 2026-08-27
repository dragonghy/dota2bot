-- Replay-fixture regression for soak candidate 'tpgap' (GH #159) -- the ONE
-- frame in the W14 corpus where J.ShouldNotTpUnderLethalPressure was armed and
-- should have refused a retreat TP, but the bot pressed it and died in the
-- channel.
--
-- REAL FRAME (verified against the .dem in this session, not copied from prose):
--   run  spot_20260826_151427_1_039cb1ae..._a2baf3   <-- NOT _2c6d8e
--   seed 895, dire = armed leg                       <-- NOT seed 906
--   game 20260826_155416_slot4, t=1382.2 (23:02), subject slardar (team 3/dire)
--
-- The 2026-08-26T19:16Z replay-check report cited this frame as
-- `2c6d8e/20260826_155416_slot4 ... seed 906`. Both the run id and the seed are
-- wrong: `155416_slot4` exists in run a2baf3 only (2c6d8e's last game is
-- 154713_slot2), and a2baf3's script_version stamp reads `:s895:dire`. The
-- FRAME itself reproduces byte-for-byte -- positions, HP, the 451 burst and the
-- 2.8s death are all confirmed below -- so the finding stands; only its address
-- was mis-joined. See GH #234.
--
-- WHAT HAPPENED. slardar retreats north toward his own fountain at 560 u/s,
-- hp 320/4324 (7.4%). bristleback sits 531.8u away -- inside the (350, 700]
-- gap band that promoted `tpsafe` (350) cannot see. slardar presses the TP
-- scroll, freezes for the 3s channel, and bristleback alone deals 85+162+204 =
-- 451 damage: dead at channel second 2.8. Every point of the lethal damage
-- comes from that one in-band enemy (jakiro's dual_breath burn had already
-- MODIFIER_REMOVE'd at t=1381.5).
--
-- WHAT THIS FIXTURE CAN AND CANNOT PROVE. The guard's last clause reads
-- `GetEstimatedDamageToTarget(true, bot, 3.0, ALL)`, an ENGINE estimate that no
-- .dem carries. replay_fixture.lua substitutes the damage each enemy ACTUALLY
-- dealt in the next `window` seconds (here window = 3.0 = the guard's own
-- nChannelSeconds, so the substitution is dimensionally the right one). So the
-- honest reading of the 'gate ON' case below is:
--
--     GIVEN the engine's 3s estimate for bristleback equalled what bristleback
--     actually went on to deal, the shipped guard refuses this TP.
--
-- It does NOT prove the engine estimated >= 320 at t=1382.2; the guard may have
-- correctly returned false on a lower estimate. That gap is the one link the
-- 19:16Z report also declined to claim, and it is pinned here as an explicit
-- test (see 'estimator floor') rather than left implicit.
--
-- Two further scope notes, stated rather than hidden:
--   * this timeline carries no per-team fog (the dumper's vision_note: Source2
--     replays have no m_iTaggedAsVisibleByTeam), so the fixture is v1 and every
--     unit is visible to every unit. The frame-level vision claim -- dire could
--     see bristleback -- was established independently in the 19:16Z report
--     from an ally auto-attack on him inside the lookback window.
--   * slardar carries `modifier_teleporting` (elapsed 0.0) because t is the
--     press instant itself. This guard never reads it. The world state is the
--     last snapshot at or before t (1381.5), i.e. genuinely pre-press.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_260826_155416_slardar_tpgap.lua'

-- Both radii are READ FROM THE SHIPPED SOURCE, never restated (same discipline
-- as tests/_tpgap_band_sweep.lua: a test that copies the constant it measures
-- keeps passing after the constant moves).
local INNER, OUTER, CHANNEL = (function()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    local at = assert(s:find('function J.ShouldNotTpUnderLethalPressure', 1, true),
        'J.ShouldNotTpUnderLethalPressure moved or was renamed')
    local body = s:sub(at, at + 1600)
    local radii = {}
    for n in body:gmatch('J%.GetNearbyHeroes%(%s*bot%s*,%s*(%d+)') do
        radii[#radii + 1] = tonumber(n)
    end
    assert(#radii == 2, 'expected exactly two GetNearbyHeroes radii, got ' .. #radii)
    assert(radii[1] < radii[2], 'source order must stay inner-then-outer')
    local ch = tonumber(body:match('nChannelSeconds%s*=%s*([%d%.]+)'))
    assert(ch, 'nChannelSeconds vanished from the guard')
    return radii[1], radii[2], ch
end)()

local function dist(a, b)
    local dx, dy = a:GetLocation().x - b:GetLocation().x, a:GetLocation().y - b:GetLocation().y
    return math.sqrt(dx * dx + dy * dy)
end

local tests = {}

tests['ground truth: the replay frame reproduces (hp, band occupancy, burst, death)'] = function()
    local _, bot, heroes, fx = rf.load(FIXTURE)
    assert(fx.self == 'npc_dota_hero_slardar')
    assert(fx.time == 1382.2, 'decision instant')
    assert(fx.window == CHANNEL,
        'the fixture window must equal the guard nChannelSeconds so observed.burst '
        .. 'is a dimensionally honest stand-in for the 3s estimate')
    assert(bot:GetHealth() == 320, 'hp at the last pre-press snapshot')
    assert(bot:GetMaxHealth() == 4324, 'max hp')
    assert(bot:IsAlive(), 'alive when he pressed it')

    -- Exactly one enemy hero in the gap band, none inside tpsafe's radius.
    local bb = heroes['npc_dota_hero_bristleback']
    local d = dist(bot, bb)
    assert(d > INNER and d <= OUTER,
        string.format('bristleback must sit in the (%d, %d] gap band; measured %.1f',
            INNER, OUTER, d))
    local inner_count, band_count = 0, 0
    for name, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() and name ~= fx.self then
            local dd = dist(bot, h)
            if dd <= INNER then inner_count = inner_count + 1 end
            if dd > INNER and dd <= OUTER then band_count = band_count + 1 end
        end
    end
    assert(inner_count == 0, 'tpsafe owns <=350 and must be empty here, else it, not tpgap, rules')
    assert(band_count == 1, 'exactly one enemy in the band; got ' .. band_count)

    -- Ground truth about what followed.
    assert(fx.observed.burst['npc_dota_hero_bristleback'] == 451,
        'bristleback alone dealt 451 in the 3s channel')
    assert(fx.observed.died_after == 2.8, 'he died at channel second 2.8')
    assert(not fx.observed.ground_truth_ambiguous,
        'no illusion on the field -- the 451 is attributable')
end

tests['fall-throughs: none of the three offline-checkable escapes applies'] = function()
    local _, bot = rf.load(FIXTURE)
    assert(not bot:IsRooted(), 'not rooted -- he could have kept walking')
    assert(not bot:IsStunned(), 'not stunned')
    assert(not bot:IsHexed(), 'not hexed')
    assert(not bot:IsNightmared(), 'not nightmared')
    assert(bot:GetCurrentMovementSpeed() >= 285,
        'above the guard floor (real frame: 350u and 390u in the two seconds before the press)')
end

tests['gate OFF (turbo, tpgap not armed): shipped behaviour byte-identical -- no refusal'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'with the candidate disarmed the guard must be a no-op on every frame')
end

tests['gate OFF (armed but not turbo): still a no-op'] = function()
    local J, bot = rf.load(FIXTURE)
    -- must be set AFTER rf.load(), which forces turbo
    GetGameMode = function() return 1 end    -- luacheck: ignore
    J.IsSoakCandidate = function(id) return id == 'tpgap' end
    assert(J.ShouldNotTpUnderLethalPressure(bot) == false,
        'tpgap is turbo-only by construction')
end

tests['gate ON: the guard refuses this TP -- the frame it was written for'] = function()
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'tpgap' end
    assert(J.ShouldNotTpUnderLethalPressure(bot) == true,
        'armed, on the real frame, with the engine estimate standing in as the damage '
        .. 'bristleback actually dealt (451 >= 320), the shipped guard must refuse. '
        .. 'In the W14 armed leg it did not refuse -- this is the SHOULD-HAVE-REFUSED '
        .. 'frame of GH #159.')
end

tests['estimator floor: the one link the corpus cannot prove, pinned explicitly'] = function()
    -- If the engine's 3s estimate had come in BELOW his health, the same shipped
    -- guard correctly returns false. Driving another hero as the subject zeroes
    -- every GetEstimatedDamageToTarget (the observed block is ground truth about
    -- fx.self only), which is the cheapest honest way to exhibit that world --
    -- so this asserts the guard is estimate-driven, not position-driven, and
    -- that 'it did not refuse' is therefore not by itself proof of a bug.
    local J, bot = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id) return id == 'tpgap' end
    assert(J.ShouldNotTpUnderLethalPressure(bot) == true, 'precondition: refuses on ground truth')

    -- Same frame, same subject, estimator forced one point short of lethal.
    local J2, bot2, heroes2 = rf.load(FIXTURE)
    J2.IsSoakCandidate = function(id) return id == 'tpgap' end
    local bb = heroes2['npc_dota_hero_bristleback']
    local lethal_floor = bot2:GetHealth()
    rawget(bb, '__spec').GetEstimatedDamageToTarget = function() return lethal_floor - 1 end
    assert(J2.ShouldNotTpUnderLethalPressure(bot2) == false,
        'one point short of lethal and the guard lets the TP through -- so the '
        .. 'W14 non-refusal is only a bug IF the engine estimate reached 320, '
        .. 'which no .dem can say. Scope of GH #159 stated as a test, not as prose.')
end

return tests
