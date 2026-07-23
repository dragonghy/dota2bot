-- [GH #15] Mid 6-level TP support. When a fight breaks out at one of OUR towers
-- (an ally being dived / a lane under pressure), a level-6+ mid hero standing
-- idle away from it -- with a TP ready and the collapse WINNABLE -- should TP in
-- to help, instead of standing mid. But it must NEVER throw the TP into a lost
-- fight: J.ShouldTpSupportTowerFight fires only when J.SafeToCommitFight (lethal
-- or numbers) passes at the destination.
--
-- These exercise J.ShouldTpSupportTowerFight directly. The helper is gated
-- turbo-only (J.IsModeTurbo) AND behind the 'midtp' soak candidate; off the
-- candidate (shipped default, no Customize/soak_side.lua) it is inert -- the
-- shipped-behavior guarantee we assert in the OFF cases. We arm the gate the way
-- the replay tests do: override J.IsSoakCandidate after require.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local TOWER_LOC = api.Vector(5000, 0, 0)   -- far (>3500) from the bot at origin

-- A live allied tower the fight is happening at.
local function MakeTower()
    return api.MakeUnit({
        GetUnitName = 'npc_dota_goodguys_tower1_mid',
        GetLocation = TOWER_LOC,
        IsAlive = true, CanBeSeen = true, IsBuilding = true,
    })
end

-- An enemy hero pressuring the tower (placed AT the tower).
local function MakeEnemyAtTower(spec)
    spec = spec or {}
    spec.GetTeam = 3          -- TEAM_DIRE (opposing the default radiant bot)
    spec.CanBeSeen = true
    spec.GetLocation = TOWER_LOC
    return api.MakeHero('npc_dota_hero_enemy', spec)
end

-- An ally defending the tower (placed AT the tower).
local function MakeDefenderAtTower()
    return api.MakeHero('npc_dota_hero_ally', {
        GetTeam = 2, CanBeSeen = true, GetLocation = TOWER_LOC,
    })
end

-- A ready Town Portal scroll in slot 0 (J.GetItem2 scans GetItemInSlot 0..16).
local function TpItem()
    return api.MakeAbility('item_tpscroll', { IsFullyCastable = true })
end

-- Install a fresh jmz with a mid bot far from the tower, turbo on and the 'midtp'
-- candidate armed. `opts` tweaks the scenario:
--   level      (default 6)
--   hasTp      (default true)   TP scroll ready in inventory
--   enemies    (default 1 enemy at the tower)  -- fight participants
--   defender   (default true)   an ally defending the tower
--   inFight    (default false)  bot already in a team fight (2 attack allies)
--   turbo      (default true)
--   armed      (default true)   'midtp' soak candidate active
local function fresh(opts)
    opts = opts or {}
    api.reset_modules()

    local enemies = opts.enemies or { MakeEnemyAtTower() }
    local tower = MakeTower()
    local defender = nil
    if opts.defender ~= false then defender = MakeDefenderAtTower() end
    local tpItem = nil
    if opts.hasTp ~= false then tpItem = TpItem() end

    local fightAllies = {}
    if opts.inFight then
        fightAllies = {
            api.MakeHero('npc_dota_hero_a1', { GetTeam = 2, CanBeSeen = true }),
            api.MakeHero('npc_dota_hero_a2', { GetTeam = 2, CanBeSeen = true }),
        }
    end

    local bot = api.MakeHero('npc_dota_hero_lion', {
        GetLevel = opts.level or 6,
        GetLocation = api.Vector(0, 0, 0),  -- far from the tower fight
        CanBeSeen = true,
        GetItemInSlot = function(_, i) if i == 0 then return tpItem end return nil end,
        -- Drives J.IsInTeamFight (2+ attack-mode allies near = already fighting).
        GetNearbyHeroes = function() return fightAllies end,
    })
    api.install({ bot = bot })

    -- Engine lists the helper reads: allied buildings + enemy heroes.
    GetUnitList = function(t) -- luacheck: ignore
        if t == UNIT_LIST_ALLIED_BUILDINGS then return { tower } end
        if t == UNIT_LIST_ENEMY_HEROES then return enemies end
        return {}
    end
    -- Allies-near-a-location scan: i=1 is the (far) bot, i=2 is the defender at
    -- the tower. Keeps J.GetAlliesNearLoc / SafeToCommitFight honest.
    GetTeamPlayers = function() return { 0, 1 } end -- luacheck: ignore
    GetTeamMember = function(i) -- luacheck: ignore
        if i == 1 then return bot end
        if i == 2 then return defender end
        return nil
    end

    GetGameMode = function() return opts.turbo == false and 1 or GAMEMODE_TURBO end -- luacheck: ignore
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    J.IsSoakCandidate = function(id)
        return opts.armed ~= false and id == (opts.cand or 'midtp')
    end
    if opts.pos then J.GetPosition = function() return opts.pos end end
    return J, bot, tower
end

local tests = {}

-- ---- FIRE -------------------------------------------------------------------

tests['FIRE: lvl6 mid with TP, ally dived at our tower, winnable -> TP support'] = function()
    local J, bot, tower = fresh()
    assert(J.ShouldTpSupportTowerFight(bot) == tower,
        'a lvl6+ mid with TP should TP to a winnable fight at our tower')
end

-- ---- NO-FIRE ----------------------------------------------------------------

tests['NO-FIRE: no TP available -> nil'] = function()
    local J, bot = fresh({ hasTp = false })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'no TP ready -> nothing to support with')
end

tests['NO-FIRE: fight not winnable (outnumbered, no lethal) -> nil'] = function()
    -- Two enemies on the tower, one defender -> SafeToCommitFight numbers 1>=2
    -- is false and no lethal burst -> do NOT throw the TP away.
    local J, bot = fresh({ enemies = { MakeEnemyAtTower(), MakeEnemyAtTower() } })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'a losing (outnumbered) tower fight must not pull a wasted TP')
end

tests['NO-FIRE: no fight at a friendly tower -> nil'] = function()
    local J, bot = fresh({ enemies = {} })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'no enemy pressuring the tower -> no support TP')
end

tests['NO-FIRE: no ally present at the tower -> nil'] = function()
    -- Enemy at an empty tower (no defender): nobody to help, so not this fix.
    local J, bot = fresh({ defender = false })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'collapsing onto an empty structure is not the mid-TP-support case')
end

tests['NO-FIRE: bot already in a team fight -> nil'] = function()
    local J, bot = fresh({ inFight = true })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'a bot already fighting has its own logic; do not override with a TP')
end

tests['NO-FIRE: below level 6 -> nil'] = function()
    local J, bot = fresh({ level = 5 })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'pre-6 (no ult / longer TP CD) is outside the mid-TP profile')
end

-- ---- OFF (gate) -------------------------------------------------------------

tests['OFF: not turbo -> inert'] = function()
    local J, bot = fresh({ turbo = false })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'non-turbo must stay inert regardless of the situation')
end

tests['OFF: not armed (shipped default) -> inert'] = function()
    local J, bot = fresh({ armed = false })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'off the midtp soak candidate the helper must be a no-op')
end

tests['[suptp] FIRE: pos-5 support with suptp armed -> same TP-support logic'] = function()
    -- L5-TPDEF (LANING_PLAYBOOK): the support watching the minimap TPs to
    -- defend a sibling lane's tower; shares the midtp winnability/TP checks.
    local J, bot, tower = fresh({ cand = 'suptp', pos = 5 })
    assert(J.ShouldTpSupportTowerFight(bot) == tower,
        'a pos-5 with suptp armed must fire exactly like the mid profile')
end

tests['[suptp] NO-FIRE: a CORE with only suptp armed -> nil (pos 4-5 only)'] = function()
    local J, bot = fresh({ cand = 'suptp', pos = 2 })
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'suptp is the support id; cores ride midtp instead')
end

tests['NO-FIRE (watched 181046): the defended ally will die before the TP lands -> nil'] = function()
    -- Big-batch pathology: Ogre TP'd across the map and landed the second
    -- Viper died. The defended ally must survive the ~4s TP window.
    local J, bot = fresh()
    J.WillAllySurviveTpWindow = function() return false end
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'never TP to an ally that will be a corpse before we land')
end

tests['NO-FIRE (watched 230652): within 15s of my own respawn -> nil (no revive-TP)'] = function()
    local J, bot = fresh()
    DotaTime = function() return 100 end -- luacheck: ignore
    bot.lastDeadFrameTime = 95  -- died 5s ago: walk back and reassess, no TP
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'fresh respawn must not TP straight back toward the fight that killed it')
    bot.lastDeadFrameTime = 80  -- 20s ago: cooldown over
    assert(J.ShouldTpSupportTowerFight(bot) ~= nil,
        'after the cooldown the TP support works as before')
end

tests['QUOTA (audit fix B): second gated TP responder in the same window -> nil'] = function()
    local J, bot, tower = fresh()
    DotaTime = function() return 200 end -- luacheck: ignore
    assert(J.ShouldTpSupportTowerFight(bot) == tower,
        'first responder takes the team TP slot')
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'a second gated TP in the same 6s window must refuse (collective-TP dedup)')
    DotaTime = function() return 210 end -- luacheck: ignore
    assert(J.ShouldTpSupportTowerFight(bot) == tower,
        'a new window frees the slot')
end

return tests
