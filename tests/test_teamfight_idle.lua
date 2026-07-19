-- [GH #5] Team-fight anti-idle guard. A bot standing idle 300-1500u from an
-- ally that is being focused/dying must resolve to a decision — 'help' (join
-- the fight) or 'flee' (leave, don't feed) — never keep watching.
--
-- These exercise J.EvalTeamfightIdle (the un-gated core decision) directly, and
-- J.ResolveTeamfightIdle (the turbo + soak-candidate gated wrapper) for the gate
-- behavior. Off the farm (no Customize/soak_side.lua) the soak gate is always
-- false, so the wrapper stays inert — that is the shipped-behavior guarantee we
-- assert here.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Build a valid enemy hero the on-ally / on-fight scans will return.
local function MakeEnemy(spec)
    spec = spec or {}
    spec.GetTeam = 3 -- TEAM_DIRE (opposing the default radiant bot)
    spec.CanBeSeen = true
    return api.MakeHero('npc_dota_hero_enemy', spec)
end

-- Build an ally hero (same team as the bot) that reports itself as focused:
-- enemies on it and recently damaged. Same-team GetHP reads OriginalGetHealth,
-- so set those to model its HP fraction.
local function MakeFocusedAlly(hpFrac, enemiesOnAlly)
    return api.MakeHero('npc_dota_hero_ally', {
        GetTeam = 2, -- TEAM_RADIANT
        CanBeSeen = true,
        OriginalGetHealth = math.floor(600 * (hpFrac or 0.3)),
        OriginalGetMaxHealth = 600,
        WasRecentlyDamagedByAnyHero = true,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return enemiesOnAlly or {} end
            return {}
        end,
    })
end

-- Install a fresh jmz with a bot whose ally/enemy scans we control. `allies`
-- and `enemies` are the lists returned by bot:GetNearbyHeroes for each flag.
local function fresh_jmz(botSpec)
    api.reset_modules()
    botSpec = botSpec or {}
    botSpec.CanBeSeen = true
    local bot = api.MakeHero('npc_dota_hero_lion', botSpec)
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

tests['EvalTeamfightIdle: healthy bot near focused ally -> help'] = function()
    local enemy = MakeEnemy()
    local ally = MakeFocusedAlly(0.3, { enemy })
    local J = fresh_jmz({
        -- same-team GetHP reads Original*; set both so the bot reads full HP
        GetHealth = 600, GetMaxHealth = 600,
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600,
        GetMana = 300, GetMaxMana = 300,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    assert(J.EvalTeamfightIdle(GetBot()) == 'help',
        'full-HP bot next to a focused ally should join the fight')
end

tests['EvalTeamfightIdle: low-HP bot, outnumbered -> flee'] = function()
    -- Bot is low HP (cannot contribute) and the fight around the ally is
    -- lopsided: 3 enemies, no other allies -> leaving beats feeding.
    local e1, e2, e3 = MakeEnemy(), MakeEnemy(), MakeEnemy()
    local ally = MakeFocusedAlly(0.25, { e1 })
    -- ally-centered scans decide numbers: 0 allies vs 3 enemies near the ally.
    ally.__spec.GetNearbyHeroes = function(_, radius, bEnemy)
        if bEnemy then
            if radius >= 1200 then return { e1, e2, e3 } end
            return { e1 }
        end
        return {}
    end
    local J = fresh_jmz({
        GetHealth = 120, GetMaxHealth = 600, -- 0.2 HP -> cannot contribute
        OriginalGetHealth = 120, OriginalGetMaxHealth = 600,
        GetMana = 0, GetMaxMana = 300,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    assert(J.EvalTeamfightIdle(GetBot()) == 'flee',
        'low-HP outnumbered bot should retreat instead of feeding')
end

tests['EvalTeamfightIdle: no focused ally nearby -> nil'] = function()
    -- Ally present but not under focus (no enemies on it, full HP).
    local ally = api.MakeHero('npc_dota_hero_ally', {
        GetTeam = 2, CanBeSeen = true,
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600,
    })
    local J = fresh_jmz({
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    assert(J.EvalTeamfightIdle(GetBot()) == nil,
        'no focused/dying ally -> no anti-idle decision')
end

tests['EvalTeamfightIdle: already attacking -> nil (normal logic owns it)'] = function()
    local enemy = MakeEnemy()
    local ally = MakeFocusedAlly(0.3, { enemy })
    local J = fresh_jmz({
        GetActiveMode = function() return BOT_MODE_ATTACK end,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    assert(J.EvalTeamfightIdle(GetBot()) == nil,
        'a bot already going on someone is not idle')
end

tests['ResolveTeamfightIdle: gated off in normal mode'] = function()
    local enemy = MakeEnemy()
    local ally = MakeFocusedAlly(0.3, { enemy })
    local J = fresh_jmz({
        GetHealth = 600, GetMaxHealth = 600,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    GetGameMode = function() return 1 end -- all-pick, not turbo
    assert(J.ResolveTeamfightIdle(GetBot()) == nil,
        'non-turbo must stay inert regardless of the situation')
end

tests['ResolveTeamfightIdle: turbo but not a soak candidate -> nil'] = function()
    -- Off the farm there is no Customize/soak_side.lua, so IsSoakCandidate is
    -- always false and the wrapper stays inert even in turbo.
    local enemy = MakeEnemy()
    local ally = MakeFocusedAlly(0.3, { enemy })
    local J = fresh_jmz({
        GetHealth = 600, GetMaxHealth = 600,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    GetGameMode = function() return GAMEMODE_TURBO end
    assert(J.ResolveTeamfightIdle(GetBot()) == nil,
        'turbo alone must not fire without the soak-candidate gate')
end

return tests
