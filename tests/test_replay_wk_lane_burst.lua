-- [obs 20260722] Laning trade-survival / burst-anticipation, pinned by REAL
-- replay frames (run spot_20260721_225025). Frame-by-frame review showed WK's
-- dominant death is being BURST from high HP by visible ranged nukers while
-- standing ground on its own half -- current-HP-threshold retreat reacts too
-- late. J.ShouldRetreatLaneBurst must fire on the two real death frames and
-- stay quiet on the real calm-lane frame:
--
--   f_230545_wk_sven_burst   5:06  WK 868/868hp, Ogre 230u beside it; Sven+Lich
--                            castable burst = 999 (ground truth: they dealt it,
--                            WK died 9.9s later). LETHAL even through peel -> flee.
--   f_232320_wk_od_burst     6:20  WK 870/1000hp, no ally within 700 (WD 786);
--                            OD castable burst = 915 (WK died 5.8s later) -> flee.
--   f_230545_wk_laning_safe  4:04  same lane, calm minute: total incoming 265
--                            vs 868hp (WK lived 37s+) -> do NOT flee.
--
-- The mock feeds the helper each enemy's GROUND-TRUTH burst (what it actually
-- dealt in the following window) through GetEstimatedDamageToTarget, so this
-- tests the decision on the exact frames that motivated it. Real jmz_func, no
-- J.* stubs.

package.path = 'tests/?.lua;' .. package.path
local fixture = require('mock.replay_fixture')

local tests = {}

local function arm(J)
    -- The fixture loader pins GAMEMODE_TURBO; arm the lanesurv candidate and
    -- pin the laning phase (fixture instants are all inside the laning window).
    J.IsSoakCandidate = function(id) return id == 'lanesurv' end
    J.IsInLaningPhase = function() return true end
end

tests['FLEE: WK 100% hp but Sven+Lich lethal burst (999 vs 868) even with Ogre peel'] = function()
    local J, bot = fixture.load('tests/fixtures/f_230545_wk_sven_burst.lua')
    arm(J)
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'the 5:15 death frame: 999 incoming >= 868 hp is lethal through peel -> must flee')
end

tests['FLEE: WK 87% hp next to OD (915 vs 870), no peel ally in range'] = function()
    local J, bot = fixture.load('tests/fixtures/f_232320_wk_od_burst.lua')
    arm(J)
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'the 6:25 death frame: 915 incoming >= 75% of 870 hp with no peel -> must flee')
end

tests['STAY: same lane, calm minute (265 incoming vs 868 hp) -> no flee'] = function()
    local J, bot = fixture.load('tests/fixtures/f_230545_wk_laning_safe.lua')
    arm(J)
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'a calm lane must not trigger the guard -- no over-fleeing, WK keeps farming')
end

tests['FLEE (cross-hero): Lion 48% hp, Lich+Axe lethal burst (520 vs 354) -> flee'] = function()
    -- Same pattern on a DIFFERENT focus hero (f_222428_lion_lich_burst, 5:14):
    -- Lion at 354 hp, visible Lich+Axe castable burst 520 (ground truth: dealt
    -- it, Lion died 6.9s later). The guard is pool-wide, not WK-specific.
    local J, bot = fixture.load('tests/fixtures/f_222428_lion_lich_burst.lua')
    arm(J)
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'the 5:20 Lion death frame: 520 incoming >= 354 hp -> must flee')
end

-- Known limitation (kept honest, no fixture forced): CM's 2:58 death to
-- Venomancer (f_221945, dropped) was mostly PLAGUE-WARD damage. Summons are
-- not hero-attributed, so neither the ground truth nor the in-game estimate
-- sees that burst -- the guard cannot catch summon-based kills. Tracked in
-- iterations/obs_20260722_focus_deaths.md.

tests['PROMOTED: fires with NO candidate armed (turbo default-on) on the death frame'] = function()
    -- lanesurv was PROMOTED 2026-07-22 (4-seed A/B: gpm +13.7, deaths -0.15,
    -- laning deaths -15%): the guard is now default-on in turbo.
    local J, bot = fixture.load('tests/fixtures/f_230545_wk_sven_burst.lua')
    J.IsSoakCandidate = function() return false end
    J.IsInLaningPhase = function() return true end
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'promoted: the burst guard fires in turbo without any soak candidate')
end

tests['OFF: still inert in normal (non-turbo) mode after promotion'] = function()
    local J, bot = fixture.load('tests/fixtures/f_230545_wk_sven_burst.lua')
    J.IsSoakCandidate = function() return false end
    J.IsInLaningPhase = function() return true end
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'normal-mode behavior stays byte-for-byte unchanged')
end

tests['OFF: inert outside the laning phase (post-laning layer is a later fix)'] = function()
    local J, bot = fixture.load('tests/fixtures/f_230545_wk_sven_burst.lua')
    J.IsSoakCandidate = function(id) return id == 'lanesurv' end
    J.IsInLaningPhase = function() return false end
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'the trade-survival guard is a LANING calc; fights/ult logic comes separately')
end

return tests
