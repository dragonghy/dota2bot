-- [lanehyst / GH #28] Exit hysteresis for the PROMOTED lane burst-anticipation
-- rule (J.ShouldRetreatLaneBurst). The base rule is recomputed every frame off
-- GetEstimatedDamageToTarget, a mana/cooldown-aware quantity that BLINKS: a
-- nuke coming off cooldown, an enemy stepping 20u past 1100 or a mana tick
-- flips the retreat decision between adjacent frames, and a retreat mode that
-- wins the desire auction for one frame and loses it the next issues a move
-- order and cancels it -- neither retreating nor laning.
--
--   HOLD    = base rule said retreat within the last 2.0s, the threat has not
--             clearly improved (no peel ally, incoming still >= 40% of my hp)
--             -> keep returning true through the blink.
--   RELEASE = window expired / peel ally arrived / incoming under the floor /
--             every enemy left 1100 -> false, lane normally again.
--   OFF     = not turbo / candidate off -> the shipped decision is byte-for-
--             byte the base rule, hysteresis included frames and all.
--
-- This is what is LEFT of the retired 'l1xpsoak' (GH #28: its entry bar was a
-- strict subset of this rule's and its anchor Vector was discarded by the only
-- consumer, so 97.3% of its 335 entry episodes were judged identically by this
-- rule). Deliberately TIME-BOUNDED, unlike the l1xpsoak hold: it can smooth a
-- blink, it can never become a parking brake (the force-passivity failure mode
-- that rejected lf_recover / corefarm / l1xpsoak wave 1).
--
-- The real zoned frame (f_231411_ck_zoned: CK 126/1068 hp, Lina 1052 + Tide
-- 584 both inside 1100, no peel ally within 700) drives every case below --
-- entry bar 75% of 126 = 94.5, release floor 40% = 50.4.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local fixture = require('mock.replay_fixture')

local tests = {}

-- The real frame with engine-grade castable estimates injected on the two real
-- zoners (the observed burst on this frame is low precisely because CK was
-- already backing off -- the counterfactual problem; ~lvl-4 Lina kit is ~310).
-- Returns J, bot, heroes plus a setter for the frame clock.
local function real_frame(opts)
    opts = opts or {}
    local J, bot, heroes = fixture.load('tests/fixtures/f_231411_ck_zoned.lua')
    J.IsSoakCandidate = function(id) return opts.armed ~= false and id == 'lanehyst' end
    J.IsInLaningPhase = function() return true end

    local now = 192.0
    DotaTime = function() return now end -- luacheck: ignore
    local function set_time(t) now = t end

    local function set_burst(n1, n2)
        rawget(heroes['npc_dota_hero_lina'], '__spec').GetEstimatedDamageToTarget = n1
        rawget(heroes['npc_dota_hero_tidehunter'], '__spec').GetEstimatedDamageToTarget = n2
    end
    set_burst(310, 310)

    return J, bot, heroes, set_burst, set_time
end

tests['REAL FRAME setup: the base rule fires on the zoned frame (620 vs 94.5 bar)'] = function()
    local J, bot = real_frame()
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'two castable zoners inside 1100 with no peel must trip the promoted rule')
end

tests['HOLD: a one-frame blink under the entry bar does not flip the retreat off'] = function()
    local J, bot, _, set_burst, set_time = real_frame()
    assert(J.ShouldRetreatLaneBurst(bot) == true, 'setup: must fire on the real frame')

    -- Next frame: Lina's nuke went on cooldown, so the estimate drops under the
    -- 94.5 entry bar but stays well over the 50.4 release floor (70). Without
    -- hysteresis the retreat desire vanishes here and comes back a frame later.
    set_time(192.1)
    set_burst(40, 30)
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'a blink in the castable estimate must not cancel a retreat already in flight')
end

tests['RELEASE: the hold expires 2.0s after the last true frame (never a parking brake)'] = function()
    local J, bot, _, set_burst, set_time = real_frame()
    assert(J.ShouldRetreatLaneBurst(bot) == true, 'setup: must fire on the real frame')

    set_burst(40, 30)
    set_time(193.9)
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'inside the 2s window the hold is still on')
    set_time(194.2)
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'past the window the bot must lane again -- the hysteresis is a blink filter, not a stance')
end

tests['RELEASE: incoming under the 40% floor clears the hold immediately'] = function()
    local J, bot, _, set_burst, set_time = real_frame()
    assert(J.ShouldRetreatLaneBurst(bot) == true, 'setup: must fire on the real frame')

    set_time(192.1)
    set_burst(10, 10)
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'the threat is clearly gone (20 < 50.4) -- hold only through borderline frames')
end

tests['RELEASE: a peel-capable ally arriving clears the hold'] = function()
    local J, bot, heroes, set_burst, set_time = real_frame()
    assert(J.ShouldRetreatLaneBurst(bot) == true, 'setup: must fire on the real frame')

    -- Skywrath (same team, 92% hp, full kit) sits ~1428 away on the real frame,
    -- outside the 700 peel radius -- which is why the rule could fire alone.
    -- Pull it beside CK: peel present -> hold releases even mid-window.
    rawget(heroes['npc_dota_hero_skywrath_mage'], '__spec').GetLocation =
        api.Vector(bot:GetLocation().x + 200, bot:GetLocation().y, 0)
    set_time(192.1)
    set_burst(40, 30)
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'with peel beside me the lane is contestable again -- do not coast on a stale stamp')
end

tests['OFF the candidate: the blink frame reverts to the shipped (base-rule) decision'] = function()
    local J, bot, _, set_burst, set_time = real_frame({ armed = false })
    assert(J.ShouldRetreatLaneBurst(bot) == true, 'the PROMOTED base rule still fires off the gate')

    set_time(192.1)
    set_burst(40, 30)
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'off the candidate the shipped decision must be the plain base rule -- 70 < 94.5')
end

tests['OFF in normal mode: the whole rule stays turbo-only'] = function()
    local J, bot = real_frame()
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J.ShouldRetreatLaneBurst(bot) == false, 'normal mode is untouched by both')
end

return tests
