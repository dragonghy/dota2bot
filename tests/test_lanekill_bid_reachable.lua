-- [GH #31] The L1-TRADE / L5-COMBO lane-kill bid must survive CapForLanePush.
--
-- The bug: both branches bid 0.92, a value chosen (see their comments in
-- mode_team_roam_generic) precisely to outbid the PROMOTED lanesurv retreat at
-- BOT_MODE_DESIRE_HIGH = 0.75. But CapForLanePush soft-ceils any roam desire
-- >0.9 to 0.72 whenever J.IsInLaningPhase(), and BOTH helpers hard-require
-- J.IsInLaningPhase() -- so the cap's trigger is a SUPERSET of the branches'
-- entire domain. The 0.92 literal was unreachable, the effective bid (0.72)
-- landed BELOW the 0.75 it was picked to beat, and the effective bid was
-- non-monotonic in HP: a healthy core bid 0.72 while a half-HP one bid ~0.90.
--
-- Why this file drives the REAL GetDesire() and not the helpers: the two
-- existing suites (test_l1_trade.lua / test_l5_combo.lua) both assert on
-- J.ShouldInitiateLaneKill / J.ShouldSupportComboKill, i.e. on the TRIGGER, and
-- test_divecap_gate.lua asserts on the cap predicate in isolation. Nothing
-- covered their COMPOSITION -- the number the engine actually receives -- which
-- is exactly why the bug survived. These tests fail on the pre-fix source.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local HIGH = 0.75     -- BOT_MODE_DESIRE_HIGH, the bid this must beat (lanesurv)
local BID  = 0.92     -- the literal both branches ask for
local CAP  = 0.72     -- what the cap clobbered it to

-- The mock resolves any unknown ALL_CAPS global to a distinct sentinel INTEGER
-- (1001, 1002, ...), which is fine for identity comparisons but ruins the
-- RemapValClamped arithmetic these branches run -- BOT_MODE_DESIRE_NONE as the
-- low end of a remap must genuinely be 0. Pin the real engine values, same as
-- tests/test_retreat_priority_order.lua does.
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = HIGH,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

-- Load mode_team_roam_generic under the mock and neutralize every decision that
-- sits ABOVE the lane-kill branches in GetDesireHelper, so a GetDesire() call
-- lands on the branch under test. opts:
--   which  = 'l1trade' | 'l5combo' | nil (arm neither -> shipped default)
--   hp     = J.GetHP(bot) to report (default 1.0 = healthy)
--   laning = J.IsInLaningPhase (default true; the helpers require it anyway)
local function load_mode(opts)
    opts = opts or {}
    api.reset_modules()

    local enemy = api.MakeHero('npc_dota_hero_sven', {
        GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(400, 0, 0),
    })
    local bot = api.MakeHero('npc_dota_hero_juggernaut', {
        CanBeSeen = true, GetLocation = api.Vector(0, 0, 0),
    })
    api.install({ bot = bot })
    for k, v in pairs(DESIRE) do _G[k] = v end
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
    GetTeam = function() return TEAM_RADIANT end -- luacheck: ignore
    bot.GetTeam = function() return TEAM_RADIANT end

    dofile('bots/mode_team_roam_generic.lua')
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    J.IsInLaningPhase = function() return opts.laning ~= false end
    J.IsPushing       = function() return false end
    J.GetHP           = function() return opts.hp or 1.0 end
    J.IsSoakCandidate = function(id) return opts.which ~= nil and id == opts.which end

    -- Quiet everything upstream of the branch under test: no help-ally target,
    -- no dive/over-chase punish, no last-hit creep, nobody nearby.
    J.GetMostPushLaneDesire   = function() return 0 end
    J.GetMostDefendLaneDesire = function() return 0 end
    J.CheckBotIdleState       = function() return false end
    J.GetAlliesNearLoc        = function() return {} end
    J.GetEnemiesNearLoc       = function() return {} end
    J.GetNearbyHeroes         = function() return {} end
    J.GetNearbyLaneCreeps     = function() return {} end
    J.GetNearbyCreeps         = function() return {} end
    J.IsValid                 = function() return false end
    J.IsValidHero             = function() return false end
    J.CanBeAttacked           = function() return false end
    J.ShouldPunishDive        = function() return nil end
    J.ShouldPunishOverchase   = function() return nil end
    J.ShouldReleaseLaneCommit = function() return false end

    -- Arm exactly one lane-kill trigger (the other stays nil).
    J.ShouldInitiateLaneKill  = function()
        if opts.which == 'l1trade' then return enemy end
        return nil
    end
    J.ShouldSupportComboKill  = function()
        if opts.which == 'l5combo' then return enemy end
        return nil
    end

    return J, bot, enemy
end

-- The load-bearing pair: the number the engine sees must be the number the
-- branch asked for, and it must beat the retreat it was chosen to beat.
tests['L1-TRADE: GetDesire() delivers the full 0.92 bid, not the 0.72 cap'] = function()
    load_mode({ which = 'l1trade' })
    local res = GetDesire()
    assert(math.abs(res - BID) < 1e-9,
        'the lane-kill commit must reach the engine uncapped; got ' .. tostring(res)
        .. (math.abs(res - CAP) < 1e-9 and ' (the CapForLanePush clobber -- GH #31)' or ''))
    assert(res > HIGH,
        'a lane-kill bid that does not outbid lanesurv (0.75) can never initiate')
end

tests['L5-COMBO: GetDesire() delivers the full 0.92 bid, not the 0.72 cap'] = function()
    load_mode({ which = 'l5combo' })
    local res = GetDesire()
    assert(math.abs(res - BID) < 1e-9,
        'the support kill-call must reach the engine uncapped; got ' .. tostring(res)
        .. (math.abs(res - CAP) < 1e-9 and ' (the CapForLanePush clobber -- GH #31)' or ''))
    assert(res > HIGH,
        'a lane-kill bid that does not outbid lanesurv (0.75) can never initiate')
end

-- The perverse symptom of the clobber: effective bid DECREASING in HP, so a
-- healthy core wanted the kill less than a half-dead one. Asserted as a shape
-- property over a sweep rather than at one point, so any future re-introduction
-- of a >0.9-only ceiling on this path is caught wherever its knee sits.
tests['MONOTONIC: the effective lane-kill bid never decreases as HP rises'] = function()
    local prev = -1
    for i = 0, 20 do
        local hp = i / 20
        load_mode({ which = 'l1trade', hp = hp })
        local res = GetDesire()
        assert(res >= prev - 1e-9,
            'effective bid fell from ' .. tostring(prev) .. ' to ' .. tostring(res)
            .. ' as HP rose to ' .. tostring(hp)
            .. ' -- a healthier hero must never want a winnable kill LESS (GH #31)')
        prev = res
    end
    assert(math.abs(prev - BID) < 1e-9, 'a full-HP core must bid the full 0.92')
end

-- Shipped-default guard, half 1: for everything that is NOT a lane-kill commit
-- the cap behaves exactly as it did before. (The trigger-side "off the candidate
-- -> nil" contract is already pinned by test_l1_trade.lua / test_l5_combo.lua.)
tests['SHIPPED: a non-exempt roam desire is still soft-ceiled to 0.72'] = function()
    local _, bot = load_mode({ which = nil })
    assert(math.abs(_divecap_CapForLanePush(0.98, false, bot, false) - CAP) < 1e-9,
        'an ordinary roam desire >0.9 must still be capped during laning')
    assert(math.abs(_divecap_CapForLanePush(0.6, false, bot, false) - 0.6) < 1e-9,
        'a desire <=0.9 still passes through untouched')
end

-- Shipped-default guard, half 2: the exemption is reachable ONLY from inside the
-- two branches that are themselves gated on 'l1trade'/'l5combo', so no shipped
-- (ungated) code path can raise it. Checked at the source level because that is
-- what the claim is about -- a runtime probe can only sample the paths it happens
-- to walk, whereas "there are exactly two assignments and both sit inside a
-- gated lane-kill commit" is the invariant that makes the fix inert by default.
tests['SHIPPED: the cap exemption flag is raised only inside the gated branches'] = function()
    local fh = assert(io.open('bots/mode_team_roam_generic.lua', 'r'))
    local lines = {}
    for line in fh:lines() do lines[#lines + 1] = line end
    fh:close()

    local sites = {}
    for i, line in ipairs(lines) do
        -- the declaration/reset assign false; only "= true" raises it
        if line:match('bLaneKillCommit%s*=%s*true') then sites[#sites + 1] = i end
    end
    assert(#sites == 2,
        'expected exactly 2 flag-raising sites (L1-TRADE + L5-COMBO), found ' .. #sites
        .. ' -- a new raise site must be re-argued: it would exempt itself from the cap')

    -- Structural containment rather than a magic line window: walking up from a
    -- raise site we must reach one of the two gated triggers WITHOUT crossing a
    -- `return` (every sibling branch in GetDesireHelper ends in one, so crossing
    -- a return means the raise sits in some other branch's body), and the guard
    -- line in between must be the commit condition.
    for _, at in ipairs(sites) do
        local trigger, guard = nil, false
        for j = at - 1, 1, -1 do
            local line = lines[j]
            if line:match('ShouldReleaseLaneCommit') then guard = true end
            if line:match('J%.ShouldInitiateLaneKill%s*%(')
                or line:match('J%.ShouldSupportComboKill%s*%(') then
                trigger = j
                break
            end
            -- ignore returns that are inside comments
            if line:match('^%s*return%s') then break end
        end
        assert(trigger ~= nil,
            'flag raised at line ' .. at .. ' is not inside a lane-kill trigger branch'
            .. ' -- that would uncap a path which never passed l1trade/l5combo')
        assert(guard,
            'flag raised at line ' .. at .. ' without the ShouldReleaseLaneCommit guard'
            .. ' -- an uncapped commit with no self-release is the wave13 pin-into-death bug')
    end
end

-- Predicate level: unlike the 'divecap' collapse exemption, the lane-kill
-- exemption carries NO turbo/candidate condition of its own -- it cannot be
-- reached without one, so re-checking here would be dead weight that reads as a
-- second safety net. Pin that this is deliberate.
tests['PREDICATE: the lane-kill exemption is unconditional once the flag is set'] = function()
    local _, bot = load_mode({ which = 'l1trade' })
    assert(math.abs(_divecap_CapForLanePush(BID, false, bot, true) - BID) < 1e-9,
        'flag set -> exempt')
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(math.abs(_divecap_CapForLanePush(BID, false, bot, true) - BID) < 1e-9,
        'the exemption does not re-check turbo: the branch that sets the flag already did')
end

return tests
