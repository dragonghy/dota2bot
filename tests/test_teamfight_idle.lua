-- [GH #5] Team-fight anti-idle guard. A bot standing idle ~300-1000u from an
-- ally that is being focused/dying must resolve to a decision — 'help' (join
-- the fight) or 'flee' (leave, don't feed / don't abandon farm) — never keep
-- watching.
--
-- These exercise J.EvalTeamfightIdle (the un-gated core decision) directly, and
-- J.ResolveTeamfightIdle (the turbo + soak-candidate gated wrapper) for the gate
-- behavior. Off the farm (no Customize/soak_side.lua) the soak gate is always
-- false, so the wrapper stays inert — that is the shipped-behavior guarantee we
-- assert here.
--
-- STRICT contract (rewritten after a mirrored-draft A/B showed the first
-- `numbers OR can-contribute` cut was a net loss): 'help' is returned ONLY when
-- helping genuinely swings the fight — parity-or-better numbers AND HP/mana, OR
-- a lethal-or-numbers safe commit (J.SafeToCommitFight) — and only when the
-- fight is genuinely close. Everything else, INCLUDING an outnumbered bot that
-- merely has HP, is 'flee'. We pin that here.

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
-- so set those to model its HP fraction. `enemiesOnAlly` is returned for every
-- enemy scan radius (focus detection + the fight numbers/enemy count).
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

-- Install a fresh jmz with a bot whose ally/enemy scans we control.
local function fresh_jmz(botSpec)
    api.reset_modules()
    botSpec = botSpec or {}
    botSpec.CanBeSeen = true
    local bot = api.MakeHero('npc_dota_hero_lion', botSpec)
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

-- Make J.SafeToCommitFight see a real fight: it reads GetEnemiesNearLoc (from
-- GetUnitList) and GetAlliesNearLoc (from GetTeamPlayers/GetTeamMember). By
-- default the mock leaves GetUnitList empty (so SafeToCommitFight would falsely
-- read "no enemies -> numbers advantage"). Point the engine-wide enemy list at
-- the fight enemies and shrink our team to just the bot, so the commit gate
-- computes honest numbers around the engage point.
local function set_fight_globals(enemies)
    GetUnitList = function() return enemies end -- luacheck: ignore
    GetTeamPlayers = function() return { 0 } end -- luacheck: ignore
end

tests['EvalTeamfightIdle: healthy bot, numbers -> help'] = function()
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
    -- 1 ally (self) vs 1 enemy = parity, and full HP/mana -> genuine help.
    assert(J.EvalTeamfightIdle(GetBot()) == 'help',
        'full-HP bot at numbers parity next to a focused ally should join')
end

tests['EvalTeamfightIdle: outnumbered but has HP -> flee (the fixed bug)'] = function()
    -- THE regression the rewrite fixes: a bot with plenty of HP/mana but
    -- OUTNUMBERED used to "help" (numbers OR can-contribute) and dive a lost
    -- fight. Now can-contribute alone is not enough -> flee.
    local e1, e2, e3 = MakeEnemy(), MakeEnemy(), MakeEnemy()
    local ally = MakeFocusedAlly(0.3, { e1, e2, e3 })
    local J = fresh_jmz({
        GetHealth = 600, GetMaxHealth = 600, -- full HP: can-contribute TRUE
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600,
        GetMana = 300, GetMaxMana = 300,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    set_fight_globals({ e1, e2, e3 }) -- 3 enemies vs 1 (self) at the engage point
    assert(J.EvalTeamfightIdle(GetBot()) == 'flee',
        'healthy-but-outnumbered bot must retreat, not dive a lost fight')
end

tests['EvalTeamfightIdle: low-HP, outnumbered -> flee'] = function()
    local e1, e2, e3 = MakeEnemy(), MakeEnemy(), MakeEnemy()
    local ally = MakeFocusedAlly(0.25, { e1, e2, e3 })
    local J = fresh_jmz({
        GetHealth = 120, GetMaxHealth = 600, -- 0.2 HP -> cannot contribute
        OriginalGetHealth = 120, OriginalGetMaxHealth = 600,
        GetMana = 0, GetMaxMana = 300,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    set_fight_globals({ e1, e2, e3 })
    assert(J.EvalTeamfightIdle(GetBot()) == 'flee',
        'low-HP outnumbered bot should retreat instead of feeding')
end

tests['EvalTeamfightIdle: low-HP but lethal on the focus enemy -> help'] = function()
    -- Outnumbered and low HP (both simple gates fail), but the bot can burst
    -- down the enemy focusing our ally. J.SafeToCommitFight (lethal) is the
    -- "real edge" that still earns a 'help'.
    local e1 = MakeEnemy({ GetHealth = 100, GetMaxHealth = 100, GetHealthRegen = 0 })
    local e2, e3 = MakeEnemy(), MakeEnemy()
    local ally = MakeFocusedAlly(0.3, { e1, e2, e3 })
    local J = fresh_jmz({
        GetHealth = 120, GetMaxHealth = 600, -- low HP: can-contribute FALSE
        OriginalGetHealth = 120, OriginalGetMaxHealth = 600,
        GetMana = 0, GetMaxMana = 300,
        -- We can one-shot the focus enemy -> lethal commit.
        GetEstimatedDamageToTarget = 500,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    set_fight_globals({ e1, e2, e3 })
    assert(J.EvalTeamfightIdle(GetBot()) == 'help',
        'a lethal commit onto the enemy focusing our ally should still help')
end

tests['EvalTeamfightIdle: fight too far to reach -> flee (do not abandon farm)'] = function()
    -- The focused ally is nearby, but the enemies in the fight are far from the
    -- bot (> 1200u). Walking off our farm into a distant fight is not "help";
    -- the walk-distance gate resolves to flee before any numbers check.
    local far = MakeEnemy({ GetLocation = api.Vector(2000, 0, 0) })
    local ally = MakeFocusedAlly(0.3, { far })
    local J = fresh_jmz({
        GetHealth = 600, GetMaxHealth = 600,
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600,
        GetMana = 300, GetMaxMana = 300,
        GetLocation = api.Vector(0, 0, 0),
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    assert(J.EvalTeamfightIdle(GetBot()) == 'flee',
        'a fight the bot would have to walk far into must resolve to flee')
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

tests['ResolveTeamfightIdle: turbo -> delegates to the eval (PROMOTED)'] = function()
    -- PROMOTED under the Class-B micro-behavior policy (runbook §1): in turbo
    -- the wrapper now always delegates — no soak-candidate gate any more.
    local enemy = MakeEnemy()
    local ally = MakeFocusedAlly(0.3, { enemy })
    local J = fresh_jmz({
        GetHealth = 600, GetMaxHealth = 600,
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600,
        GetMana = 300, GetMaxMana = 300,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return {} end
            return { ally }
        end,
    })
    GetGameMode = function() return GAMEMODE_TURBO end
    assert(J.ResolveTeamfightIdle(GetBot()) == J.EvalTeamfightIdle(GetBot()),
        'in turbo the promoted wrapper must return exactly what the eval returns')
    assert(J.ResolveTeamfightIdle(GetBot()) ~= nil,
        'this scenario (focused ally, parity, full HP/mana) must resolve to a decision')
end

return tests
