-- Mock of the Dota 2 Bot API for running bot scripts under plain Lua 5.1.
-- Used by the unit tests (tests/) to load and exercise bot code without the game.
--
-- Design:
--   * Explicit mocks for functions the load paths and tests actually need.
--   * ALL_CAPS names (BOT_MODE_*, DAMAGE_TYPE_*, ...) are auto-defined via a _G
--     metatable, each resolving to a distinct number, so constant comparisons work.
--   * Anything else undefined still resolves to nil — real nil-global bugs stay
--     visible in tests instead of being silently absorbed.
--   * MakeUnit()/MakeHero() build configurable fake units for behavioral tests.

local M = {}

local REPO_ROOT = arg and arg[0] and arg[0]:match('^(.*)/tests/') or '.'

----------------------------------------------------------------------
-- Vector
----------------------------------------------------------------------

local vector_mt
vector_mt = {
    -- The game's Vector answers numeric indexing too (v[1]=x, v[2]=y, v[3]=z);
    -- bot code (e.g. J.GetDistance) relies on it.
    __index = function(v, k)
        if k == 1 then return v.x end
        if k == 2 then return v.y end
        if k == 3 then return v.z end
        return nil
    end,
    __add = function(a, b) return M.Vector(a.x + b.x, a.y + b.y, a.z + b.z) end,
    __sub = function(a, b) return M.Vector(a.x - b.x, a.y - b.y, a.z - b.z) end,
    __mul = function(a, b)
        if type(a) == 'number' then return M.Vector(a * b.x, a * b.y, a * b.z) end
        return M.Vector(a.x * b, a.y * b, a.z * b)
    end,
    __eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
    __tostring = function(v) return string.format('Vector(%g, %g, %g)', v.x, v.y, v.z) end,
}

function M.Vector(x, y, z)
    return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, vector_mt)
end

local function dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

----------------------------------------------------------------------
-- Fake units (heroes, creeps, buildings) and abilities/items
----------------------------------------------------------------------

-- Getter defaults by prefix when a spec doesn't provide an override.
local function default_for(key)
    local first = key:sub(1, 2)
    if key:find('^Is') or key:find('^Has') or key:find('^Can') or key:find('^Was') then
        return false
    end
    if key:find('^GetNearby') then return {} end
    if key == 'GetLocation' then return M.Vector(0, 0, 0) end
    if key:find('^Get') then return 0 end
    return nil
end

local unit_mt = {
    __index = function(self, key)
        -- Only CamelCase names are API methods (GetHealth, IsAlive, Action_*).
        -- Lowercase keys (bot.isBear, bot.announcedRole, ...) are plain state
        -- properties the scripts store on units: absent means nil, as in-game.
        if type(key) ~= 'string' or not key:match('^[A-Z]') then return nil end
        local fn = function(_, ...)
            local spec = rawget(self, '__spec')
            local v = spec and spec[key]
            if type(v) == 'function' then return v(self, ...) end
            if v ~= nil then return v end
            return default_for(key)
        end
        rawset(self, key, fn)
        return fn
    end,
}

--- Build a fake unit. spec keys override method results by method name:
---   MakeUnit{ GetHealth = 350, GetUnitName = 'npc_dota_creep', IsAlive = true }
--- A spec value may be a function (self, ...) for dynamic behavior.
function M.MakeUnit(spec)
    return setmetatable({ __spec = spec or {} }, unit_mt)
end

--- Fake ability/item handle.
function M.MakeAbility(name, spec)
    spec = spec or {}
    spec.GetName = spec.GetName or name
    return M.MakeUnit(spec)
end

--- Fake hero with sensible defaults; abilities auto-created on request.
function M.MakeHero(unitName, spec)
    spec = spec or {}
    spec.GetUnitName = spec.GetUnitName or unitName
    spec.IsHero = true
    spec.IsAlive = (spec.IsAlive == nil) and true or spec.IsAlive
    spec.IsBot = (spec.IsBot == nil) and true or spec.IsBot
    spec.GetHealth = spec.GetHealth or 600
    spec.GetMaxHealth = spec.GetMaxHealth or 600
    spec.GetMana = spec.GetMana or 300
    spec.GetMaxMana = spec.GetMaxMana or 300
    spec.GetAttackRange = spec.GetAttackRange or 150
    spec.GetPlayerID = spec.GetPlayerID or 0
    spec.GetTeam = spec.GetTeam or 2 -- TEAM_RADIANT
    local abilities = {}
    spec.GetAbilityByName = spec.GetAbilityByName or function(_, name)
        -- Callers may probe with names from data tables that only exist for
        -- the real hero; treat unknown/nil lookups as "no such ability".
        if name == nil then return nil end
        if not abilities[name] then abilities[name] = M.MakeAbility(name) end
        return abilities[name]
    end
    -- Slots 0-5 hold ability handles (named after the hero for traceability);
    -- higher slots (talents) are empty in the mock.
    spec.GetAbilityInSlot = spec.GetAbilityInSlot or function(self, slot)
        if slot >= 0 and slot <= 5 then
            return self:GetAbilityByName(
                (spec.GetUnitName or 'unknown') .. '_mock_slot_' .. tostring(slot))
        end
        return nil
    end
    spec.GetItemInSlot = spec.GetItemInSlot or function() return nil end
    return M.MakeUnit(spec)
end

----------------------------------------------------------------------
-- Global environment installation
----------------------------------------------------------------------

--- Install the mock API into _G. opts:
---   bot:  the unit returned by GetBot() (default: a generic hero)
---   team: TEAM value returned by GetTeam() (default 2)
function M.install(opts)
    opts = opts or {}
    local G = _G

    G.Vector = M.Vector

    local bot = opts.bot or M.MakeHero('npc_dota_hero_axe')
    local team = opts.team or 2

    G.GetBot = function() return bot end
    G.GetTeam = function() return team end
    G.GetOpposingTeam = function() return team == 2 and 3 or 2 end
    G.GetTeamPlayers = function() return { 0, 1, 2, 3, 4 } end
    G.GetTeamMember = function(i)
        if i == 1 then return bot end
        return M.MakeHero('npc_dota_hero_teammate_' .. tostring(i), { GetPlayerID = i - 1 })
    end
    G.IsPlayerBot = function() return true end
    G.IsTeamPlayer = function() return true end

    G.GetScriptDirectory = function() return REPO_ROOT .. '/bots' end

    G.DotaTime = function() return 0 end
    G.GameTime = function() return 0 end
    G.RealTime = function() return 0 end
    G.GetSystemTime = function() return 0 end

    -- Real randomness (seeded for reproducibility): code like
    -- `repeat i = RandomInt(...) until ...` must be able to make progress.
    math.randomseed(42)
    G.RandomInt = function(lo, hi) return math.random(lo, hi) end
    G.RandomFloat = function(lo, hi) return lo + (hi - lo) * math.random() end
    G.RandomVector = function(len)
        local a = math.random() * 2 * math.pi
        len = len or 0
        return M.Vector(len * math.cos(a), len * math.sin(a), 0)
    end
    G.RollPercentage = function(p) return math.random(1, 100) <= (p or 0) end

    G.Min = math.min
    G.Max = math.max
    G.Clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
    G.RemapVal = function(v, a, b, c, d)
        if a == b then return c end
        return c + (d - c) * (v - a) / (b - a)
    end
    G.RemapValClamped = function(v, a, b, c, d)
        local r = G.RemapVal(v, a, b, c, d)
        if c < d then return G.Clamp(r, c, d) else return G.Clamp(r, d, c) end
    end

    G.GetUnitToUnitDistance = function(a, b) return dist2d(a:GetLocation(), b:GetLocation()) end
    G.GetUnitToLocationDistance = function(u, loc) return dist2d(u:GetLocation(), loc) end
    G.GetLocationToLocationDistance = function(a, b) return dist2d(a, b) end

    G.GetUnitList = function() return {} end
    G.GetTower = function() return nil end
    G.GetBarracks = function() return nil end
    G.GetAncient = function() return M.MakeUnit({ GetLocation = M.Vector(0, 0, 0), GetHealth = 4500 }) end
    G.GetShrine = function() return nil end
    G.GetCourier = function() return nil end
    G.GetLaneFrontLocation = function() return M.Vector(0, 0, 0) end
    G.GetLaneFrontAmount = function() return 0.5 end
    G.GetLocationAlongLane = function() return M.Vector(0, 0, 0) end
    G.IsLocationPassable = function() return true end
    G.IsLocationVisible = function() return false end
    G.GetHeightLevel = function() return 0 end
    G.GetNeutralSpawners = function() return {} end
    G.GetItemComponents = function() return {} end
    G.GetItemCost = function() return 0 end
    G.IsItemPurchasedFromSecretShop = function() return false end
    G.IsItemPurchasedFromSideShop = function() return false end
    G.GetItemStockCount = function() return 1 end
    G.GetDroppedItemList = function() return {} end
    G.GetRuneSpawnTimeForRune = function() return 0 end
    G.GetRuneStatus = function() return 0 end
    G.GetRoshanKillTime = function() return 0 end
    G.IsRoshanAlive = function() return true end
    G.GetGameMode = function() return 1 end
    G.GetGameState = function() return 5 end
    G.GetHeroPickState = function() return 0 end
    G.IsPlayerInHeroSelectionControl = function() return false end
    G.GetSelectedHeroName = function() return '' end
    G.IsInCMBanPhase = function() return false end
    G.GetCMPhaseTimeRemaining = function() return 0 end
    G.GetCMCaptain = function() return -1 end
    G.GetTeamForPlayer = function() return team end
    G.GetHeroKills = function() return 0 end
    G.GetHeroDeaths = function() return 0 end
    G.GetHeroAssists = function() return 0 end
    G.GetHeroLastHits = function() return 0 end
    G.GetHeroDenies = function() return 0 end
    -- Per-playerID hero queries (used by illusion-detection heuristics). Default
    -- to "alive, level 0" so a mock enemy isn't flagged as a suspicious illusion.
    G.IsHeroAlive = function() return true end
    G.GetHeroLevel = function() return 0 end

    G.print = function() end -- keep test output clean; tests use the runner's reporting

    -- Engine script classes whose methods bot code wraps/overrides at load time
    G.CDOTA_Bot_Script = {}

    -- LuaJIT bitop subset (the game VM provides `bit`; plain Lua 5.1 doesn't)
    if not G.bit then
        local function to_bits_op(op)
            return function(a, b)
                local result, bitval = 0, 1
                a, b = a % 2 ^ 32, b % 2 ^ 32
                for _ = 1, 32 do
                    local abit, bbit = a % 2, b % 2
                    if op(abit == 1, bbit == 1) then result = result + bitval end
                    a, b = (a - abit) / 2, (b - bbit) / 2
                    bitval = bitval * 2
                end
                return result
            end
        end
        G.bit = {
            band = to_bits_op(function(x, y) return x and y end),
            bor = to_bits_op(function(x, y) return x or y end),
            bxor = to_bits_op(function(x, y) return x ~= y end),
            bnot = function(a) return (2 ^ 32 - 1) - (a % 2 ^ 32) end,
            lshift = function(a, n) return (a * 2 ^ n) % 2 ^ 32 end,
            rshift = function(a, n) return math.floor((a % 2 ^ 32) / 2 ^ n) end,
        }
    end

    -- dofile in the game VM resolves without the .lua extension and relative
    -- to the mod; emulate that on top of stock dofile.
    local real_dofile = dofile
    G.dofile = function(path)
        if not path:find('%.lua$') then path = path .. '.lua' end
        return real_dofile(path)
    end

    package.path = table.concat({
        REPO_ROOT .. '/?.lua',
        REPO_ROOT .. '/bots/?.lua',
        package.path,
    }, ';')

    -- Auto-define ALL_CAPS engine constants: each unknown ALL_CAPS global
    -- resolves to a distinct, stable number. Everything else stays nil.
    local const_ids = {}
    local next_id = 1000
    setmetatable(G, {
        __index = function(_, key)
            if type(key) == 'string' and key:match('^[A-Z][A-Z0-9_]*$') then
                if not const_ids[key] then
                    next_id = next_id + 1
                    const_ids[key] = next_id
                end
                return const_ids[key]
            end
            return nil
        end,
    })

    return bot
end

--- Reset module cache for bot scripts so the next install() reloads them fresh.
function M.reset_modules()
    for name in pairs(package.loaded) do
        if name:find('bots/', 1, true) or name:find('/FunLib/', 1, true)
            or name:find('/BotLib/', 1, true) or name:find('/ts_libs/', 1, true) then
            package.loaded[name] = nil
        end
    end
end

return M
