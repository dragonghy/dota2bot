-- [GH #12] 'nopush' laning wave-shove guard contract. Focus heroes cast AOE
-- damage nukes (Crystal Maiden Crystal Nova, Jakiro Dual Breath, ...) that
-- splash the enemy lane creep wave and shove the lane during laning, costing
-- lane control and last-hits. X._nopush_ShouldSuppressWaveShove must return
-- true (suppress the cast) ONLY for a pure wave-clear during the laning phase
-- while NOT pushing/defending/teamfighting -- and stay inert off the soak
-- candidate side (the shipped default) so baseline behavior is untouched.
-- The guard is a plain decision function, so we drive it directly with a
-- crafted bot rather than steering the whole ConsiderQ branch tree.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local ss = require('mock.soak_side')               -- owns bots/Customize/soak_side.lua
local RADIUS = 400

local tests = {}

-- Load the Crystal Maiden hero module under the mock, on TEAM_RADIANT.
-- bTurbo=false installs normal mode (to prove the gate is turbo-only).
local function load_cm(bTurbo)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_crystal_maiden', { CanBeSeen = true })
    api.install({ bot = bot })
    GetTeam = function() return TEAM_RADIANT end
    if bTurbo == false then
        GetGameMode = function() return 1 end
    else
        GetGameMode = function() return GAMEMODE_TURBO end
    end
    return dofile('bots/BotLib/hero_crystal_maiden.lua')
end

-- Activate the 'nopush' soak candidate on radiant by writing the (gitignored)
-- soak_side file, running fn, then cleaning up. Mirrors the other gate tests.
-- [GH #365 §3 / GH #229, hero backlog `-78`] The write goes through
-- tests/mock/soak_side.lua, the switch's one owner: the bytes are read back
-- (an unchecked write presents as "the guard did not suppress", which four of
-- the six cases here EXPECT), an existing switch is reported instead of
-- clobbered, and the switch is re-read after the case body so a concurrent
-- removal is named instead of being argued about as a suppression bug.
local function with_candidate(fn)
    ss.with_candidate('nopush', fn)
end

--- The off-candidate case's premise, made observable.
local function assert_unarmed()
    ss.assert_clean('test_nopush_gate')
end

-- ...and once at file-load time, the only moment that sees the state this
-- process STARTED in (an inherited leftover is deleted by the first armed
-- case, before any per-case guard runs -- GH #417).
assert_unarmed()

local function make_creep(x, y)
    return api.MakeUnit({ GetLocation = api.Vector(x, y, 0) })
end

local function make_enemy(x, y)
    local e = api.MakeHero('npc_dota_hero_lion',
        { CanBeSeen = true, GetLocation = api.Vector(x, y, 0) })
    e.is_suspicious_illusion = false
    return e
end

-- A bot whose GetNearbyLaneCreeps / GetNearbyHeroes return the supplied units.
-- GetNearbyHeroes only yields the enemy list when bEnemy is true, so the
-- teamfight probe (allies in ATTACK mode) sees nobody.
local function make_hbot(creeps, enemyHeroes, mode)
    return api.MakeHero('npc_dota_hero_crystal_maiden', {
        CanBeSeen = true,
        GetActiveMode = mode or 0,
        GetNearbyLaneCreeps = function() return creeps end,
        GetNearbyHeroes = function(_, _, bEnemy)
            if bEnemy then return enemyHeroes end
            return {}
        end,
    })
end

local TARGET = api.Vector(1000, 0, 0)

tests['suppresses a pure wave-clear during laning on the candidate side'] = function()
    with_candidate(function()
        local X = load_cm(true)
        local hbot = make_hbot({ make_creep(1000, 0), make_creep(1050, 0) }, {})
        assert(X._nopush_ShouldSuppressWaveShove(hbot, TARGET, RADIUS) == true,
            '2 enemy creeps in AOE, no hero, laning, not pushing -> suppress')
    end)
end

tests['allows the cast when an enemy hero sits inside the AOE (harass)'] = function()
    with_candidate(function()
        local X = load_cm(true)
        local hbot = make_hbot(
            { make_creep(1000, 0), make_creep(1050, 0) },
            { make_enemy(1000, 0) })
        assert(X._nopush_ShouldSuppressWaveShove(hbot, TARGET, RADIUS) == false,
            'a hero in the AOE makes this harass -> must pass through')
    end)
end

tests['allows the cast when fewer than 2 lane creeps are caught'] = function()
    with_candidate(function()
        local X = load_cm(true)
        local hbot = make_hbot({ make_creep(1000, 0) }, {})
        assert(X._nopush_ShouldSuppressWaveShove(hbot, TARGET, RADIUS) == false,
            'a single creep is not a wave-clear -> must pass through')
    end)
end

tests['allows the cast while explicitly pushing a tower'] = function()
    with_candidate(function()
        local X = load_cm(true)
        local hbot = make_hbot(
            { make_creep(1000, 0), make_creep(1050, 0) }, {},
            BOT_MODE_PUSH_TOWER_MID)
        assert(X._nopush_ShouldSuppressWaveShove(hbot, TARGET, RADIUS) == false,
            'pushing means the shove is intended -> must pass through')
    end)
end

tests['is inert off the soak candidate side (shipped default)'] = function()
    assert_unarmed()
    local X = load_cm(true)   -- no soak_side file written
    local hbot = make_hbot({ make_creep(1000, 0), make_creep(1050, 0) }, {})
    assert(X._nopush_ShouldSuppressWaveShove(hbot, TARGET, RADIUS) == false,
        'without the nopush candidate the guard must never suppress')
end

tests['is inert in normal (non-turbo) mode even on the candidate side'] = function()
    with_candidate(function()
        local X = load_cm(false)
        local hbot = make_hbot({ make_creep(1000, 0), make_creep(1050, 0) }, {})
        assert(X._nopush_ShouldSuppressWaveShove(hbot, TARGET, RADIUS) == false,
            'the guard is turbo-only -> normal mode must be untouched')
    end)
end

return tests
