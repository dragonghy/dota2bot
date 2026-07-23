-- [ownhalf / analyst 20260723] Own-half collapse domain for J.ShouldPunishDive,
-- pinned by the REAL standoff frames. The shipped domain (enemy within 1200 of
-- an allied building) leaves a punish DEAD ZONE between the river and T1-1200:
--
--   * f_232228 t=340 -- WK (100%, stun ready) + Sniper hovered ~1000u from a
--     69%-HP solo Juggernaut farming their lane for 17s, zero engagement; the
--     nearest allied tower was ~2100u from Jugg (dead zone).
--   * f_230510 t=230 -- DP + Veno stood ~1000u from a solo Luna for 38s while
--     it healed 42%->69% on their wave (they even ate glaive bounces).
--
-- Contract: OFF the 'ownhalf' candidate the dead zone reproduces (nil even
-- with a building present); armed, an invader clearly on OUR half (>=800
-- ancient-distance margin) with SafeToCommitFight passing is returned; the
-- lethal-or-numbers discipline still vetoes outnumbered collapses.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

-- Radiant subject in both fixtures: our ancient bottom-left, theirs top-right.
local function installAncients()
    GetAncient = function(team) -- luacheck: ignore
        if team == GetTeam() then
            return api.MakeUnit({ GetLocation = api.Vector(-5900, -5300, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(5900, 5100, 0) })
    end
end

local function loaded(fixture, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(fixture)
    J.IsSoakCandidate = function(id)
        return opts.armed ~= false and id == 'ownhalf'
    end
    installAncients()
    -- A real allied tower OUTSIDE the shipped 1200 domain (the dead zone the
    -- analyst measured: nearest T1 ~2100u from the invader).
    local tower = api.MakeUnit({
        GetUnitName = 'npc_dota_goodguys_tower1_top',
        GetLocation = api.Vector(-6200, 1800, 0),
        IsAlive = true, CanBeSeen = true, IsBuilding = true,
    })
    local orig = GetUnitList
    GetUnitList = function(kind) -- luacheck: ignore
        if kind == UNIT_LIST_ALLIED_BUILDINGS then return { tower } end
        return orig(kind)
    end
    return J, bot, heroes, fx
end

tests['[232228 WK] dead zone reproduces with candidate OFF (shipped unchanged)'] = function()
    local J, bot = loaded('tests/fixtures/f_232228_wk_ownhalf_standoff.lua',
        { armed = false })
    assert(J.ShouldPunishDive(bot) == nil,
        'shipped domain: Jugg is ~2190u from the tower -> nobody collapses (the hole)')
end

tests['[232228 WK] armed: invader on our half + numbers -> collapse target'] = function()
    local J, bot, heroes = loaded('tests/fixtures/f_232228_wk_ownhalf_standoff.lua')
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_juggernaut'],
        'WK+Sniper vs a solo 69% Jugg deep on our half is exactly the collapse case')
end

tests['[232228 WK] discipline: two more enemies on the invader -> nil (outnumbered)'] = function()
    local J, bot, heroes = loaded('tests/fixtures/f_232228_wk_ownhalf_standoff.lua')
    local jugg = heroes['npc_dota_hero_juggernaut']
    local moved = 0
    for _, h in pairs(heroes) do
        if h ~= jugg and h:GetTeam() == jugg:GetTeam() and moved < 2 then
            rawget(h, '__spec').GetLocation = jugg:GetLocation()
            rawset(h, 'GetLocation', nil)
            moved = moved + 1
        end
    end
    assert(moved == 2, 'test setup: need two moved enemies')
    assert(J.ShouldPunishDive(bot) == nil,
        'SafeToCommitFight must still veto a 2v3 collapse -- ownhalf widens the '
        .. 'domain, never the discipline')
end

tests['[230510 DP] armed: the Luna standoff frame converts to a collapse'] = function()
    local J, bot, heroes = loaded('tests/fixtures/f_230510_dp_luna_standoff.lua')
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_luna'],
        'DP+Veno stood 1000u from a solo Luna for 38s -- armed, it is a target')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    local J, bot = loaded('tests/fixtures/f_232228_wk_ownhalf_standoff.lua')
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J.ShouldPunishDive(bot) == nil, 'normal mode ships unchanged')
end

return tests
