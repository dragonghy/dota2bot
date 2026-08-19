-- [capmono / GH #31 follow-up] CapForLanePush must be a CEILING, not a cliff.
--
-- GH #31 established the defect class: the number the author reasons about in a
-- comment is not the number the engine receives, because a downstream transform
-- silently rewrites it. The director's fix EXEMPTED the two lane-kill branches
-- (they hard-require laning phase, so the cap's domain was a strict superset of
-- theirs and 0.92 was unreachable). This file is the other half of that finding,
-- for the branches that stay capped.
--
-- The cliff:  `if desire > 0.9 then return 0.72 end  -- soft ceiling`
-- Everything still routed through it bids
-- `RemapValClamped(J.GetHP(bot), 0, 0.5|0.6, BOT_MODE_DESIRE_NONE, 0.98)`
-- (ConsiderHelpWhenCoreIsTargeted, ConsiderHelpAlly, the tower-dive punish and
-- the over-chase punish -- the last of which, 'overchase', is in the armed test
-- set right now). So the effective bid is NON-MONOTONIC in HP, peaking at ~46%:
--
--     HP 100%  ->  raw 0.98  -> clobbered to 0.72   (loses to lanesurv 0.75)
--     HP  46%  ->  raw 0.90  -> passes at    0.90   (BEATS lanesurv 0.75)
--     HP  43%  ->  raw 0.84  -> passes at    0.84   (BEATS lanesurv 0.75)
--     HP  36%  ->  raw 0.71  -> passes at    0.71   (loses again)
--
-- i.e. the hero LEAST able to survive the collapse is the only one who wins the
-- desire auction against the promoted retreat and gets pinned into it. That is
-- the wave13 pin-into-death shape; the lane-kill branches carry
-- J.ShouldReleaseLaneCommit precisely to escape it, and none of these four do.
--
-- The fix (gated turbo + 'capmono') makes the ceiling a real ceiling:
-- `min(desire, 0.72)` for everything still capped. It can only ever LOWER a
-- desire, so unlike the still-gated 'divecap' exemption it cannot cause the
-- over-commitment that kept that one dark.
--
-- REAL FRAME: f_222428_lion_lich_burst -- Lion 354/823 hp (43.0%) at t=314.0,
-- Lich 660u and Axe 800u on him, no ally within 2200. Ground truth from the
-- replay: Lich dealt 436 damage and Lion died 6.9s later. This frame is inside
-- turbo's laning phase (t < 480), so the cap is genuinely live on it, and the
-- promoted lanesurv retreat genuinely fires on it -- which is what makes the
-- inversion observable rather than hypothetical.

package.path = 'tests/?.lua;' .. package.path
local fixture = require('mock.replay_fixture')

local tests = {}

local HIGH = 0.75    -- BOT_MODE_DESIRE_HIGH: what the promoted lanesurv retreat bids
local CEIL = 0.72    -- the lane-push ceiling
local FIXTURE = 'tests/fixtures/f_222428_lion_lich_burst.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- the RemapValClamped arithmetic these branches run. Pin the real engine values
-- (same reason as tests/test_lanekill_bid_reachable.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = HIGH,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

-- Load the real frame, then load mode_team_roam_generic into that world so the
-- REAL global GetDesire()/_divecap_CapForLanePush run on it.
--   armed = arm the 'capmono' soak candidate (nothing else is ever armed)
--   hp    = override the subject's ENGINE health (J.GetHP stays the real helper)
local function real_frame(opts)
    opts = opts or {}
    local J, bot, heroes, fx = fixture.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end

    if opts.hp ~= nil then
        local spec = rawget(bot, '__spec')
        spec.GetHealth = math.floor(opts.hp * bot:GetMaxHealth() + 0.5)
        spec.OriginalGetHealth = spec.GetHealth
        rawset(bot, 'GetHealth', nil)
        rawset(bot, 'OriginalGetHealth', nil)
    end

    J.IsSoakCandidate = function(id) return opts.armed == true and id == 'capmono' end

    -- Engine plumbing the behavioural dump does not carry (per-lane push/defend
    -- desire is engine state, not a snapshot field). Neutral values: GetDesire's
    -- preamble reads them, no branch under test depends on them.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    -- ...and the per-bot overrides J.GetDefendLaneDesire reads off the handle
    -- (the mock would otherwise resolve the missing field to a function).
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    dofile('bots/mode_team_roam_generic.lua')
    return J, bot, heroes, fx
end

-- The raw bid the four capped branches ask for, computed from the frame's REAL
-- health through the REAL engine remap -- not a hand-typed constant.
local function raw_bid(J, bot, nKnee)
    return RemapValClamped(J.GetHP(bot), 0, nKnee or 0.5, BOT_MODE_DESIRE_NONE, 0.98)
end

-- ---------------------------------------------------------------------------
-- The real frame: the inversion is live here, and it is what killed this Lion.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: the cap is live and the promoted retreat fires on it'] = function()
    local J, bot = real_frame()
    assert(J.IsModeTurbo(), 'fixture world must be turbo (the dump is turbo)')
    assert(J.IsInLaningPhase(),
        't=314 is inside turbo laning (floor 480s), so CapForLanePush is live here')
    assert(J.ShouldRetreatLaneBurst(bot) == true,
        'lanesurv (PROMOTED, bids 0.75) must fire on this frame -- Lich 436 burst vs '
        .. bot:GetHealth() .. ' hp; without that there is nothing for the roam bid to outbid')
end

tests['REAL FRAME: at 43% HP the capped collapse bid OUTBIDS the retreat (the bug)'] = function()
    local J, bot = real_frame()
    local raw = raw_bid(J, bot)
    local eff = _divecap_CapForLanePush(raw, false, bot, false)
    assert(eff > HIGH,
        'expected the pre-fix cliff to let this half-dead Lion through above 0.75; got '
        .. tostring(eff) .. ' from raw ' .. tostring(raw))
    assert(math.abs(eff - raw) < 1e-9,
        'the cliff only touches desires >0.9, so a 43%-HP bid passes untouched')
end

tests['REAL FRAME: a FULL-HP Lion on the same frame bids LESS (the inversion)'] = function()
    local Jl, botl = real_frame({ hp = 0.43 })
    local low = _divecap_CapForLanePush(raw_bid(Jl, botl), false, botl, false)
    local Jh, both = real_frame({ hp = 1.00 })
    local high = _divecap_CapForLanePush(raw_bid(Jh, both), false, both, false)
    assert(high < low,
        'setup check: the pre-fix cliff must invert these two (healthy ' .. tostring(high)
        .. ' vs dying ' .. tostring(low) .. ')')
    assert(high < HIGH and low > HIGH,
        'and the inversion straddles the retreat bid: only the DYING hero wins the auction')
end

tests['REAL FRAME armed: the ceiling puts the dying Lion back under the retreat'] = function()
    local J, bot = real_frame({ armed = true })
    local eff = _divecap_CapForLanePush(raw_bid(J, bot), false, bot, false)
    assert(math.abs(eff - CEIL) < 1e-9,
        'armed, the bid must land on the ceiling; got ' .. tostring(eff))
    assert(eff < HIGH,
        'and the ceiling must sit below lanesurv 0.75, so the retreat wins this frame')
end

-- ---------------------------------------------------------------------------
-- Shape property, driven through the REAL GetDesire() on the real frame.
-- The only thing forced is the TRIGGER (J.ShouldPunishOverchase returns the real
-- Lich handle from the fixture): the bid arithmetic, the branch, the cap and the
-- laning-phase test are all the real code running on the real world.
-- ---------------------------------------------------------------------------

local function overchase_desire(opts)
    local J, bot, heroes = real_frame(opts)
    J.ShouldPunishOverchase = function() return heroes['npc_dota_hero_lich'] end
    return GetDesire(), J, bot
end

tests['GetDesire: the real over-chase branch is reached and shows the raw 0.98 ceiling'] = function()
    local res = overchase_desire({ hp = 1.00 })
    assert(math.abs(res - CEIL) < 1e-9,
        'a full-HP over-chase punish must arrive as the clobbered 0.72; got ' .. tostring(res)
        .. ' -- if this is 0.98 the branch was not reached at all')
end

tests['MONOTONIC: the effective collapse bid never falls as HP rises (armed)'] = function()
    local prev = -1
    for i = 0, 20 do
        local hp = i / 20
        local res = overchase_desire({ hp = hp, armed = true })
        assert(res >= prev - 1e-9,
            'effective bid fell from ' .. tostring(prev) .. ' to ' .. tostring(res)
            .. ' as HP rose to ' .. tostring(hp)
            .. ' -- a healthier hero must never commit to a collapse MORE reluctantly')
        prev = res
    end
    assert(math.abs(prev - CEIL) < 1e-9, 'a full-HP collapse must bid the ceiling')
end

tests['MONOTONIC: the shipped default is NOT monotonic (this is the defect)'] = function()
    local seen = {}
    for i = 0, 20 do
        local hp = i / 20
        seen[#seen + 1] = overchase_desire({ hp = hp })
    end
    local fell = false
    for i = 2, #seen do
        if seen[i] < seen[i - 1] - 1e-9 then fell = true end
    end
    assert(fell,
        'the pre-fix cliff MUST show the inversion somewhere on the sweep; if this test'
        .. ' starts passing-by-absence the cliff was changed and capmono is obsolete')
end

-- ---------------------------------------------------------------------------
-- Shipped-default containment: gate off -> byte-for-byte the old cliff.
-- ---------------------------------------------------------------------------

tests['SHIPPED: gate off leaves the cliff exactly as it was'] = function()
    local _, bot = real_frame()
    local cases = {
        { 0.98, CEIL }, -- >0.9 clobbered
        { 0.95, CEIL },
        { 0.90, 0.90 }, -- the knee itself passes untouched
        { 0.84, 0.84 }, -- the whole (0.72, 0.9] band passes untouched
        { 0.60, 0.60 },
    }
    for _, c in ipairs(cases) do
        local got = _divecap_CapForLanePush(c[1], false, bot, false)
        assert(math.abs(got - c[2]) < 1e-9,
            'shipped cap changed: ' .. c[1] .. ' -> ' .. got .. ', expected ' .. c[2])
    end
end

tests['SHIPPED: armed, the ceiling is a pure min() -- it never RAISES a desire'] = function()
    local _, bot = real_frame({ armed = true })
    for i = 0, 100 do
        local d = i / 100
        local got = _divecap_CapForLanePush(d, false, bot, false)
        assert(got <= d + 1e-9,
            'the ceiling raised ' .. d .. ' to ' .. got .. ' -- it must only ever lower')
        assert(got <= CEIL + 1e-9, 'nothing may exceed the ceiling while armed')
    end
end

tests['SHIPPED: the exemptions still win over the ceiling'] = function()
    local _, bot = real_frame({ armed = true })
    assert(math.abs(_divecap_CapForLanePush(0.92, false, bot, true) - 0.92) < 1e-9,
        'the GH #31 lane-kill exemption must still bypass the cap when armed')
end

tests['SHIPPED: outside laning/pushing the ceiling does nothing'] = function()
    local J, bot = real_frame({ armed = true })
    J.IsInLaningPhase = function() return false end
    J.IsPushing = function() return false end
    assert(math.abs(_divecap_CapForLanePush(0.98, false, bot, false) - 0.98) < 1e-9,
        'the cap (and so the ceiling) is scoped to laning/pushing only')
end

tests['SHIPPED: the gate is turbo-only'] = function()
    local J, bot = real_frame({ armed = true })
    J.IsModeTurbo = function() return false end
    assert(math.abs(_divecap_CapForLanePush(0.84, false, bot, false) - 0.84) < 1e-9,
        'outside turbo the shipped cliff must run, leaving the (0.72,0.9] band alone')
end

return tests
