-- [GH #14] Support-core last-hit division ('suplh'). During laning a support
-- (pos 4-5) should deny + harass and leave last-hits to an allied core that can
-- take them, only securing a creep itself when no core is near enough to
-- contest it (so a lone support isn't starved of gold). The load-bearing
-- decision is the pure predicate _suplh_IsCoreContestingCreep(hSelf, hCreep) in
-- bots/mode_laning_generic.lua: is an allied core close enough -- within ~800 of
-- the creep AND within its own attack reach + a walk buffer -- to take the last
-- hit itself? We drive it directly with crafted allies/creeps rather than
-- steering the whole laning Think. Mirrors tests/test_corefarm_gate.lua.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Load mode_laning_generic under the mock with a pos-5 support bot on radiant,
-- turbo on. dofile defines the global predicate _suplh_IsCoreContestingCreep
-- regardless of the soak gate (the gate only affects Think/GetDesire, not the
-- predicate definition). Returns the support bot to use as hSelf.
local function load_mode()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion', { CanBeSeen = true })
    api.install({ bot = bot })
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    bot.GetTeam = function() return TEAM_RADIANT end
    bot.assignedRole = 5
    dofile('bots/mode_laning_generic.lua')
    return bot
end

-- A creep sitting `dist` away from the origin (where cores are placed below).
local function make_creep(dist)
    return api.MakeUnit({
        GetUnitName = 'npc_dota_creep_badguys_melee',
        CanBeSeen = true,
        IsAlive = true,
        GetLocation = api.Vector(dist, 0, 0),
    })
end

-- An allied hero at the origin. opts: role (default 1 = core), range (attack
-- range, default 150 melee), illusion.
local function make_ally(opts)
    opts = opts or {}
    local ally = api.MakeHero('npc_dota_hero_juggernaut', {
        CanBeSeen = true,
        GetTeam = TEAM_RADIANT,
        GetPlayerID = 1,
        GetAttackRange = opts.range or 150,
        GetLocation = api.Vector(0, 0, 0),
        IsIllusion = opts.illusion or false,
    })
    ally.assignedRole = opts.role or 1
    return ally
end

-- Point GetUnitList (any list) at a fixed roster of allied heroes.
local function set_allies(list)
    GetUnitList = function() return list end
end

tests['a melee core in reach of the creep contests it'] = function()
    local bot = load_mode()
    set_allies({ make_ally({ role = 1, range = 150 }) })
    -- creep 300 away: within 800 AND within 150+250=400 reach -> contested.
    assert(_suplh_IsCoreContestingCreep(bot, make_creep(300)) == true,
        'a nearby core that can reach the creep should own the last hit')
end

tests['a melee core too far to reach the creep does NOT contest it'] = function()
    local bot = load_mode()
    set_allies({ make_ally({ role = 1, range = 150 }) })
    -- creep 700 away: within 800 but beyond 400 reach -> support may take it.
    assert(_suplh_IsCoreContestingCreep(bot, make_creep(700)) == false,
        'a core that cannot reach the creep must not starve the support')
end

tests['a ranged core contests a creep inside its reach and the 800 gate'] = function()
    local bot = load_mode()
    set_allies({ make_ally({ role = 2, range = 600 }) })
    -- creep 700 away: within 800 AND within 600+250=850 -> contested.
    assert(_suplh_IsCoreContestingCreep(bot, make_creep(700)) == true,
        'a ranged core within reach and same-lane proximity should contest')
end

tests['the 800 same-lane gate binds even when reach would allow it'] = function()
    local bot = load_mode()
    set_allies({ make_ally({ role = 2, range = 600 }) })
    -- creep 820 away: within 600+250=850 reach but beyond the 800 gate -> free.
    assert(_suplh_IsCoreContestingCreep(bot, make_creep(820)) == false,
        'beyond ~800 the core is treated as not same-lane -> support may take')
end

tests['a nearby support ally is not a core and does not contest'] = function()
    local bot = load_mode()
    set_allies({ make_ally({ role = 4, range = 150 }) })
    assert(_suplh_IsCoreContestingCreep(bot, make_creep(300)) == false,
        'only pos 1-3 cores divide farm; a support ally never contests')
end

tests['an illusion core does not contest'] = function()
    local bot = load_mode()
    set_allies({ make_ally({ role = 1, range = 150, illusion = true }) })
    assert(_suplh_IsCoreContestingCreep(bot, make_creep(300)) == false,
        'an illusion is not a real core taking the last hit')
end

tests['with no allied cores at all the support is free to farm'] = function()
    local bot = load_mode()
    set_allies({})
    assert(_suplh_IsCoreContestingCreep(bot, make_creep(300)) == false,
        'a lone support must not be suppressed when no core is present')
end

tests['a nil creep is never contested'] = function()
    local bot = load_mode()
    set_allies({ make_ally({ role = 1, range = 150 }) })
    assert(_suplh_IsCoreContestingCreep(bot, nil) == false,
        'invalid/absent creep must be safe (false), not error')
end

return tests
