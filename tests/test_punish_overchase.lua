-- [GH #20] Punish-the-over-chase gating + trigger contract. The INVERSE of the
-- anti-suicide-chase guard and the SISTER of J.ShouldPunishDive: when an enemy
-- over-chases one of our low-HP allies deep into our side, out-running its own
-- support, nearby allies should TURN AND COLLAPSE on it -- but ONLY when the
-- reverse-kill is winnable (J.SafeToCommitFight). J.ShouldPunishOverchase must be
-- inert unless the game is turbo AND this side carries the 'overchase' soak
-- candidate, and it fires ONLY on the narrow clear reverse-kill case; every other
-- case (not deep / not isolated / ally not low / not winnable) returns nil so the
-- team keeps fleeing (never hard-int).
--
-- J.SafeToCommitFight is exercised for real in the FIRE case (2 allies vs a lone
-- chaser at the engage point -> the numbers branch passes); the "not winnable"
-- case pins the branch by stubbing it false.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Build the full over-chase scenario: our low ally `ally` is being attacked by a
-- lone enemy `enemy` that has over-extended deep under one of our buildings, and
-- the collapsing `bot` sees it within collapse range. Returns J, bot, enemy, ally
-- with turbo + the 'overchase' candidate armed and the location helpers set so
-- the chaser reads as isolated, deep, and a winnable collapse. Tests tweak one
-- knob each to drive the NO-FIRE / OFF branches.
local function scenario(opts)
    opts = opts or {}
    api.reset_modules()

    -- Our low-HP ally being chased (same team as the bot). Same-team GetHP reads
    -- Original*, so set those to model its HP fraction.
    local ally = api.MakeHero('npc_dota_hero_ally', {
        GetTeam = 2, -- TEAM_RADIANT
        CanBeSeen = true,
        OriginalGetHealth = opts.allyHealth or 120, -- 0.2 HP by default -> low
        OriginalGetMaxHealth = 600,
        WasRecentlyDamagedByHero = true,
    })

    -- The over-extended chaser (opposing team), locked onto our ally.
    local enemy = api.MakeHero('npc_dota_hero_enemy', {
        GetTeam = 3, -- TEAM_DIRE
        CanBeSeen = true,
        GetLocation = api.Vector(0, 0, 0),
        GetAttackTarget = function() return ally end,
    })

    -- The collapsing bot: sees the chaser within collapse range (1600).
    local bot = api.MakeHero('npc_dota_hero_lion', {
        CanBeSeen = true,
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600,
        GetNearbyHeroes = function(_, _radius, bEnemy)
            if bEnemy then return { enemy } end
            return {}
        end,
    })
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    -- Arm the gate: turbo + the 'overchase' soak candidate on this side.
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
    J.IsSoakCandidate = function(id) return id == 'overchase' end

    -- (c) ISOLATED: only the chaser near the engage point. (also the enemy count
    -- SafeToCommitFight reads for its numbers branch.)
    if opts.notIsolated then
        local other = api.MakeHero('npc_dota_hero_enemy2', { GetTeam = 3, CanBeSeen = true })
        J.GetEnemiesNearLoc = function() return { enemy, other } end
    else
        J.GetEnemiesNearLoc = function() return { enemy } end
    end

    -- Our side at the engage point: the collapsing bot + the chased ally. With a
    -- lone chaser this is a 2-vs-1 -> SafeToCommitFight's numbers branch passes.
    J.GetAlliesNearLoc = function() return { bot, ally } end

    -- (b) DEEP: an allied building within 1200 of the chaser (a tower dive on our
    -- side). Omit it (opts.notDeep) and, with both ancients at the origin, the
    -- deep check is false.
    if not opts.notDeep then
        local building = api.MakeUnit({
            IsBuilding = true, IsAlive = true, CanBeSeen = true,
            GetLocation = api.Vector(0, 0, 0),
        })
        GetUnitList = function(t) -- luacheck: ignore
            if t == UNIT_LIST_ALLIED_BUILDINGS then return { building } end
            return {}
        end
    end

    return J, bot, enemy, ally
end

tests['FIRE: isolated chaser deep on our side chasing a low ally + winnable -> collapse'] = function()
    local J, bot, enemy = scenario()
    assert(J.ShouldPunishOverchase(bot) == enemy,
        'the clear reverse-kill case must return the over-extended chaser to collapse on')
end

tests['NO-FIRE: chaser not isolated (support present) -> nil'] = function()
    local J, bot = scenario({ notIsolated = true })
    assert(J.ShouldPunishOverchase(bot) == nil,
        'a chaser still with its support must not be punished (keep fleeing)')
end

tests['NO-FIRE: chaser not deep on our side -> nil'] = function()
    local J, bot = scenario({ notDeep = true })
    assert(J.ShouldPunishOverchase(bot) == nil,
        'an enemy that has not over-extended into our territory is not ours to punish')
end

tests['NO-FIRE: ally not low (healthy) -> nil'] = function()
    local J, bot = scenario({ allyHealth = 600 }) -- full HP ally -> not a rescue
    assert(J.ShouldPunishOverchase(bot) == nil,
        'no low-HP ally being chased -> no over-chase to punish')
end

tests['NO-FIRE: SafeToCommitFight false (not winnable) -> nil'] = function()
    local J, bot = scenario()
    J.SafeToCommitFight = function() return false end
    assert(J.ShouldPunishOverchase(bot) == nil,
        'an unwinnable collapse must fall through to fleeing, never hard-int')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    local J, bot = scenario()
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J.ShouldPunishOverchase(bot) == nil,
        'normal mode must never trigger an over-chase collapse')
end

tests['OFF: inert off the soak candidate'] = function()
    local J, bot = scenario()
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldPunishOverchase(bot) == nil,
        'off the candidate side the trigger must stay inert (shipped default)')
end

return tests
