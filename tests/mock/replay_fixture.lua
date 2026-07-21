-- Rebuild a real replay instant (a make_fixture.py fixture) under the mock Bot
-- API, so the REAL decision helpers in jmz_func run on the REAL game state.
--
-- This is the local-validation keystone: no J.* function is stubbed. The loader
-- only lays down the ENGINE plumbing the helpers read —
--   * every hero as a mock unit at its real position/HP/mana/level/team,
--   * GetUnitList/GetTeamPlayers/GetTeamMember over the fixture roster,
--   * each enemy's GetEstimatedDamageToTarget = the damage it ACTUALLY dealt to
--     the subject in the following seconds (ground truth from the replay),
-- then loads jmz_func fresh. A test calls the real helper and asserts the
-- decision. Reproduce first, then fix, then this test pins it forever.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local M = {}

--- Load a fixture file. Returns J, bot (the subject), heroes (by full name), fx.
function M.load(path)
    api.reset_modules()
    local fx = dofile(path)

    local subj_team
    for _, u in ipairs(fx.units) do
        if u.name == fx.self then subj_team = u.team end
    end
    assert(subj_team, 'fixture subject not in units: ' .. tostring(fx.self))

    local heroes = {}
    for _, u in ipairs(fx.units) do
        local loc = api.Vector(u.x, u.y, 0)
        local burst = (fx.observed and fx.observed.burst and fx.observed.burst[u.name]) or 0
        -- Real inventory: slot-ordered item handles ('' = empty slot). The TP
        -- scroll's real cooldown state rides on tp_cd from the dump.
        local slots = {}
        for i, itname in ipairs(u.items or {}) do
            if itname ~= '' then
                slots[i - 1] = api.MakeAbility('item_' .. itname, {
                    IsFullyCastable = true,
                })
            end
        end
        -- The TP scroll lives in the dedicated slot (15), outside the 9 carried
        -- slots the dump lists; its real cooldown state rides on tp_cd. Every
        -- hero owns one, so synthesize the handle from the captured cooldown.
        if u.tp_cd ~= nil then
            slots[15] = api.MakeAbility('item_tpscroll', {
                IsFullyCastable = u.tp_cd <= 0,
                GetCooldownTimeRemaining = u.tp_cd,
            })
        end
        heroes[u.name] = api.MakeHero(u.name, {
            GetItemInSlot = function(_, i) return slots[i] end,
            GetTeam = u.team,
            GetLocation = loc,
            GetHealth = u.hp, GetMaxHealth = u.max_hp,
            OriginalGetHealth = u.hp, OriginalGetMaxHealth = u.max_hp,
            GetMana = u.mp, GetMaxMana = u.max_mp,
            GetLevel = u.level,
            IsAlive = u.alive,
            CanBeSeen = true,
            GetCurrentMovementSpeed = 300,
            -- Ground truth: what this hero actually did to the subject next.
            GetEstimatedDamageToTarget = function() return burst end,
        })
        -- Bypass the illusion heuristic via its own cache property: fixture
        -- units are canonical real heroes (illusions dropped at generation).
        heroes[u.name].is_suspicious_illusion = false
    end

    local bot = heroes[fx.self]
    api.install({ bot = bot, team = subj_team })

    -- Engine plumbing over the fixture roster (alive units only, like in game).
    local allies, enemies = {}, {}
    for _, u in ipairs(fx.units) do
        if u.alive then
            local h = heroes[u.name]
            if u.team == subj_team then allies[#allies + 1] = h
            else enemies[#enemies + 1] = h end
        end
    end
    GetTeamPlayers = function()
        local t = {}
        for i = 1, #allies do t[i] = i end
        return t
    end
    GetTeamMember = function(i) return allies[i] end
    GetUnitList = function(kind)
        if kind == UNIT_LIST_ENEMY_HEROES then return enemies end
        if kind == UNIT_LIST_ALLIED_HEROES then return allies end
        return {}
    end
    GetGameMode = function() return GAMEMODE_TURBO end
    DotaTime = function() return fx.time end

    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    return J, bot, heroes, fx
end

return M
