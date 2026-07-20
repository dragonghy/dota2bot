-- [GH #4] Middle-broadness anti-dive tier gating contract ('nodive2').
--
-- J.ShouldSuppressDive ships with the SHARP near-certain-feed logic live: it
-- fires only when a dive into 2+ enemies is a near-certain feed (low HP /
-- lethal flanker burst / no escape). The gated 'nodive2' path adds a MIDDLE
-- tier: on the clear-but-not-lethal case (even HP, mobile) it fires when the
-- bot is WALKING INTO the enemy pocket (would deepen the sandwich), while still
-- letting an even trade / easy walk-out fall through.
--
-- This pins:
--   * gate OFF => byte-identical to the live sharp ShouldSuppressDive (the
--     walking-into-a-losing-sandwich even-HP case must stay false),
--   * gate ON + walking INTO the losing sandwich (2+ enemies, not safe, even HP,
--     heading in) => true (the discriminator the sharp path lacks),
--   * gate ON + even HP but able to step out / not heading in => false.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

-- Build a turbo scenario at the boundary the sharp version lets fall through:
-- 2+ enemies at the engage point, NOT safe to commit (outnumbered, no kill),
-- and the bot at even HP + mobile (so none of the sharp near-certain-feed
-- clauses fire). The enemy pocket sits at x=500; the bot sits at the origin.
-- `gate_on` toggles the 'nodive2' candidate; `extrap` is where the bot's
-- 0.5s-extrapolated position lands (the "heading in" signal).
local function scenario(gate_on, extrap)
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function(id) return gate_on and id == 'nodive2' end
    -- Enemy pocket centroid at (500, 0); bot at the origin.
    local e1 = api.MakeHero('npc_dota_hero_enemy_a',
        { GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(500, 0, 0) })
    local e2 = api.MakeHero('npc_dota_hero_enemy_b',
        { GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(500, 0, 0) })
    J.GetEnemiesNearLoc = function() return { e1, e2 } end
    J.GetAlliesNearLoc = function() return { bot } end -- outnumbered, no kill
    -- Even HP, mobile, negligible incoming: the sharp clauses all fall through.
    local spec = rawget(bot, '__spec')
    spec.OriginalGetHealth = 600
    spec.OriginalGetMaxHealth = 600
    spec.GetHealth = 600
    spec.GetCurrentMovementSpeed = 320
    spec.GetLocation = api.Vector(0, 0, 0)
    spec.GetExtrapolatedLocation = extrap
    return J, bot
end

-- The engage point for a generic attack-move / walk is the bot's own location.
local ENGAGE = api.Vector(0, 0, 0)

tests['gate OFF: even-HP walk INTO the pocket stays false (== live sharp path)'] = function()
    -- Heading straight in, but no gate: the sharp version has no direction clause
    -- and the near-certain-feed clauses do not hold, so it must fall through.
    local J, bot = scenario(false, api.Vector(300, 0, 0))
    assert(J.ShouldSuppressDive(bot, ENGAGE, nil) == false,
        'without nodive2 the guard must match the live sharp path (false here)')
end

tests['gate ON: walking INTO the losing sandwich fires (discriminator vs sharp)'] = function()
    -- Same even-HP, mobile spot where the SHARP path returns false, but the bot
    -- is heading into the pocket (extrapolated position much closer to it): the
    -- middle tier catches the sandwiched_walk pattern and suppresses the dive.
    local J, bot = scenario(true, api.Vector(300, 0, 0))
    assert(J.ShouldSuppressDive(bot, ENGAGE, nil) == true,
        'nodive2 must fire when the bot is walking into a losing sandwich')
end

tests['gate ON: even HP but able to step out (moving away) does NOT fire'] = function()
    -- Extrapolated position is FARTHER from the pocket -- the bot is stepping
    -- out, an even trade it can disengage from -- so the middle tier must not
    -- force a hard retreat.
    local J, bot = scenario(true, api.Vector(-200, 0, 0))
    assert(J.ShouldSuppressDive(bot, ENGAGE, nil) == false,
        'nodive2 must let an easy walk-out / step-out fall through')
end

tests['gate ON: standing still (not heading in) does NOT fire'] = function()
    -- Stationary: extrapolated position == current position, no direction into
    -- the pocket, engage point not deeper -> even trade in place, fall through.
    local J, bot = scenario(true, api.Vector(0, 0, 0))
    assert(J.ShouldSuppressDive(bot, ENGAGE, nil) == false,
        'nodive2 must not fire on an even trade in place (no heading-in signal)')
end

tests['gate ON: a deeper engage point (commit onto vLoc) fires even if stationary'] = function()
    -- Direction-by-engage: the bot is not moving, but the engage point vLoc is
    -- deeper into the pocket than the bot is now (a charge/blink/attack-move onto
    -- a target IN the pocket), which would deepen the sandwich.
    local J, bot = scenario(true, api.Vector(0, 0, 0))
    assert(J.ShouldSuppressDive(bot, api.Vector(450, 0, 0), nil) == true,
        'nodive2 must fire when the engage point itself deepens the sandwich')
end

tests['gate ON: sharp clauses still short-circuit (low HP fires regardless)'] = function()
    -- The middle tier is additive: the sharp near-certain-feed clauses above it
    -- must still fire on their own (low HP here) without needing a heading-in
    -- signal.
    local J, bot = scenario(true, api.Vector(0, 0, 0))
    local spec = rawget(bot, '__spec')
    spec.OriginalGetHealth = 180 -- GetHP = 0.30
    spec.GetHealth = 180
    assert(J.ShouldSuppressDive(bot, ENGAGE, nil) == true,
        'low-HP feed must still suppress via the sharp path under nodive2')
end

return tests
