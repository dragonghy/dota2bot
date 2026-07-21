-- [GH #7] Defensive-collapse lane-cap exemption ('divecap'). mode_team_roam's
-- CapForLanePush soft-ceils any roam desire >0.9 down to 0.72 during the laning
-- phase, to keep ordinary roam/gank from overpowering laning micro. But the
-- tower-dive punish (#7) and over-chase punish (#20) deliberately return 0.98 as
-- an EMERGENCY local collapse -- and were being clobbered to 0.72 exactly during
-- laning, when tower dives happen, so the punish lost to the bot's own laning
-- desire and dives went unpunished (~4.6/game with #7 nominally shipped).
--
-- The load-bearing decision is the pure predicate _divecap_CapForLanePush(desire,
-- bCollapse, bot): a collapse desire is exempt from the cap ONLY when turbo AND
-- the 'divecap' soak candidate is armed; everything else keeps the old cap. We
-- drive the predicate directly (mirrors tests/test_suplh_gate.lua).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Load mode_team_roam_generic under the mock so it defines the global predicate
-- _divecap_CapForLanePush. Returns (J, bot). opts: laning (IsInLaningPhase),
-- pushing (IsPushing), turbo (game mode), cand (arm 'divecap').
local function load_mode(opts)
    opts = opts or {}
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion', { CanBeSeen = true })
    api.install({ bot = bot })
    GetGameMode = function() return opts.turbo == false and 1 or GAMEMODE_TURBO end -- luacheck: ignore
    GetTeam = function() return TEAM_RADIANT end -- luacheck: ignore
    bot.GetTeam = function() return TEAM_RADIANT end
    dofile('bots/mode_team_roam_generic.lua')

    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    J.IsInLaningPhase = function() return opts.laning ~= false end
    J.IsPushing = function() return opts.pushing == true end
    J.IsSoakCandidate = function(id) return opts.cand and id == 'divecap' end
    return J, bot
end

-- The collapse desire the punish branches return (0.98).
local COLLAPSE = 0.98

tests['FIRE: divecap armed + turbo + collapse during laning -> desire NOT capped'] = function()
    local _, bot = load_mode({ laning = true, turbo = true, cand = true })
    local res = _divecap_CapForLanePush(COLLAPSE, true, bot)
    assert(math.abs(res - COLLAPSE) < 1e-9,
        'an armed defensive collapse must bypass the lane cap (got ' .. tostring(res) .. ')')
end

tests['NO-EXEMPT: collapse during laning but divecap OFF -> capped to 0.72'] = function()
    local _, bot = load_mode({ laning = true, turbo = true, cand = false })
    local res = _divecap_CapForLanePush(COLLAPSE, true, bot)
    assert(math.abs(res - 0.72) < 1e-9,
        'off the candidate the old cap still applies -- shipped behavior unchanged (got '
        .. tostring(res) .. ')')
end

tests['NO-EXEMPT: divecap armed but NOT turbo -> capped to 0.72'] = function()
    local _, bot = load_mode({ laning = true, turbo = false, cand = true })
    local res = _divecap_CapForLanePush(COLLAPSE, true, bot)
    assert(math.abs(res - 0.72) < 1e-9,
        'normal mode is never exempt (got ' .. tostring(res) .. ')')
end

tests['NO-EXEMPT: armed + turbo but NOT a collapse (ordinary roam) -> capped'] = function()
    local _, bot = load_mode({ laning = true, turbo = true, cand = true })
    local res = _divecap_CapForLanePush(COLLAPSE, false, bot)
    assert(math.abs(res - 0.72) < 1e-9,
        'an ordinary roam desire (not a collapse) is still capped even with divecap on (got '
        .. tostring(res) .. ')')
end

tests['PASSTHROUGH: outside laning/pushing -> desire unchanged regardless'] = function()
    local _, bot = load_mode({ laning = false, pushing = false, turbo = true, cand = false })
    local res = _divecap_CapForLanePush(COLLAPSE, false, bot)
    assert(math.abs(res - COLLAPSE) < 1e-9,
        'no cap applies outside the laning/pushing phase (got ' .. tostring(res) .. ')')
end

tests['PASSTHROUGH: a low desire (<=0.9) is never capped even during laning'] = function()
    local _, bot = load_mode({ laning = true, turbo = true, cand = false })
    local res = _divecap_CapForLanePush(0.6, false, bot)
    assert(math.abs(res - 0.6) < 1e-9,
        'the cap only bites desires >0.9; a 0.6 desire passes through (got '
        .. tostring(res) .. ')')
end

tests['NO-EXEMPT: collapse while PUSHING (divecap off) -> capped'] = function()
    local _, bot = load_mode({ laning = false, pushing = true, turbo = true, cand = false })
    local res = _divecap_CapForLanePush(COLLAPSE, true, bot)
    assert(math.abs(res - 0.72) < 1e-9,
        'the push-phase cap also applies to a collapse when divecap is off (got '
        .. tostring(res) .. ')')
end

return tests
