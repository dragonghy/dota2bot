-- The soak-farm drafter (custom_loader.ApplySoakDraft) must produce a valid,
-- per-launch-rotating draft. Locks the iteration-0001 fix: with the pre-fix
-- code, RealTime()-bucket seeding was constant (RealTime is elapsed time, not
-- wall clock) and load-time RandomInt repeats per launch, so radiant drafted
-- the identical 5 heroes in 18/18 farm games (radiant won all 18).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local POOL_PATH = 'bots/Customize/soak_pool.lua'   -- gitignored, farm-only

local POOL = {
    'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden',
    'luna', 'sniper', 'death_prophet', 'tidehunter', 'dragon_knight',
    'witch_doctor', 'lich', 'warlock', 'sven', 'ogre_magi',
    'chaos_knight', 'medusa', 'drow_ranger', 'viper', 'bristleback',
}

local function write_pool()
    local f = assert(io.open(POOL_PATH, 'w'))
    f:write('return {\n')
    for _, name in ipairs(POOL) do f:write("    '" .. name .. "',\n") end
    f:write('}\n')
    f:close()
end

-- Load custom_loader fresh, as one team scope would at game launch.
-- real_time emulates the load-timing jitter; RandomInt is deliberately
-- reseeded identically every launch (api.install does math.randomseed(42)),
-- matching the deterministic engine RNG observed at file-load time.
local function launch_scope(real_time)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    RealTime = function() return real_time end
    local real_print = print
    print = function() end
    local ok, customize = pcall(dofile, 'bots/FunLib/custom_loader.lua')
    print = real_print
    assert(ok, 'custom_loader failed to load: ' .. tostring(customize))
    return customize
end

local function set_of(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end

local function same_set(a, b)
    local sa, sb = set_of(a), set_of(b)
    for k in pairs(sa) do if not sb[k] then return false end end
    for k in pairs(sb) do if not sa[k] then return false end end
    return true
end

local function with_pool(fn)
    write_pool()
    _G.__SOAK_DRAFT_SEED = nil
    local ok, err = pcall(fn)
    os.remove(POOL_PATH)
    _G.__SOAK_DRAFT_SEED = nil
    if not ok then error(err, 0) end
end

local tests = {}

tests['soak draft: valid 5v5 draft from the pool, no cross-team duplicates'] = function()
    with_pool(function()
        local c = launch_scope(7.123456)
        assert(#c.Radiant_Heros == 5, 'radiant should get 5 picks, got ' .. #c.Radiant_Heros)
        assert(#c.Dire_Heros == 5, 'dire should get 5 picks, got ' .. #c.Dire_Heros)
        local pool_set = {}
        for _, name in ipairs(POOL) do pool_set['npc_dota_hero_' .. name] = true end
        local seen = {}
        for _, list in ipairs({ c.Radiant_Heros, c.Dire_Heros }) do
            for _, hero in ipairs(list) do
                assert(pool_set[hero], 'pick not from pool: ' .. tostring(hero))
                assert(not seen[hero], 'duplicate pick across teams: ' .. hero)
                seen[hero] = true
            end
        end
    end)
end

tests['soak draft: rotates per launch despite deterministic load-time RandomInt'] = function()
    with_pool(function()
        local a = launch_scope(5.123456)
        _G.__SOAK_DRAFT_SEED = nil            -- separate game process
        local b = launch_scope(9.654321)
        assert(not same_set(a.Radiant_Heros, b.Radiant_Heros)
            or not same_set(a.Dire_Heros, b.Dire_Heros),
            'two launches with different load jitter produced the identical draft')
    end)
end

tests['soak draft: second scope in the same VM reuses the stashed seed'] = function()
    with_pool(function()
        local a = launch_scope(5.123456)
        local rad_a, dire_a = a.Radiant_Heros, a.Dire_Heros
        -- same process, later load time: must reproduce the same draft
        local b = launch_scope(6.777777)
        assert(same_set(rad_a, b.Radiant_Heros) and same_set(dire_a, b.Dire_Heros),
            'second scope with stashed seed disagreed with the first scope')
    end)
end

tests['soak draft: silent no-op without the pool file'] = function()
    _G.__SOAK_DRAFT_SEED = nil
    os.remove(POOL_PATH)
    local c = launch_scope(7.123456)
    assert(#c.Radiant_Heros == 2 and c.Radiant_Heros[1] == 'Random',
        'without a pool file the default Customize picks must be untouched')
    _G.__SOAK_DRAFT_SEED = nil
end

return tests
