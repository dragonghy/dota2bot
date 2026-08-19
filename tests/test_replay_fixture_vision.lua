-- Engine-plumbing regression for the replay-fixture loader's VISION model.
--
-- Charter step 2 ("find a concrete bad decision, with vision context -- what
-- could the bot actually see?") was not reproducible before this: make_fixture.py
-- dropped the v2 timeline's per-hero `vis` field and tests/mock/replay_fixture.lua
-- hardcoded CanBeSeen = true, so every fixture pretended the whole enemy team was
-- lit up. Any shipped decision that gates on visibility -- J.IsValid and
-- J.CanCastOnNonMagicImmune both require CanBeSeen(), and bot:GetNearbyHeroes is
-- vision-limited in the engine -- was therefore validated against a world the bot
-- never sees in game.
--
-- This is tooling, not a gated behavior change: no bot Lua is touched. The
-- contract pinned here is
--   * seen_by present -> CanBeSeen / GetNearbyHeroes honor it,
--   * seen_by absent (every pre-existing v1 fixture) -> fully visible, exactly
--     the old behavior, so no existing fixture test shifts,
--   * GetUnitList(UNIT_LIST_ENEMY_HEROES) still returns fogged enemies, matching
--     the engine ("all matching unit handles across the entire map",
--     docs/BOT_API_REFERENCE.md) -- vision filtering there is the caller's job.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local SUBJ_TEAM, ENEMY_TEAM = 2, 3

-- Written to a temp path rather than tests/fixtures/, which is reserved for
-- real make_fixture.py output. The unit shape mirrors that output exactly.
-- NOTE the .lua suffix: tests/mock/bot_api.lua shims the global dofile to
-- emulate the game VM (which resolves without an extension) by appending
-- '.lua', so a bare os.tmpname() path is unreadable once any test has installed
-- the mock API.
local function write_fixture(seen_by_clause)
    local stem = os.tmpname()
    local path = stem .. '.lua'
    os.remove(stem)
    local f = assert(io.open(path, 'w'))
    f:write([[
return {
  game = 'synthetic_vision', time = 300.0, window = 5.0,
  self = 'npc_dota_hero_zuus',
  units = {
    { name = 'npc_dota_hero_zuus', team = 2, x = 0.0, y = 0.0, hp = 900, max_hp = 1000,
      mp = 700, max_mp = 800, level = 9, alive = true, tp_cd = 0, net_worth = 5000,
      seen_by = { 2, 3 }, items = { }, abilities = { } },
    { name = 'npc_dota_hero_lion', team = 2, x = 200.0, y = 0.0, hp = 800, max_hp = 1000,
      mp = 400, max_mp = 800, level = 9, alive = true, tp_cd = 0, net_worth = 4000,
      seen_by = { 2, 3 }, items = { }, abilities = { } },
    -- lit up: both teams see him
    { name = 'npc_dota_hero_luna', team = 3, x = 500.0, y = 0.0, hp = 300, max_hp = 1000,
      mp = 400, max_mp = 500, level = 9, alive = true, tp_cd = 0, net_worth = 6000,
      seen_by = { 2, 3 }, items = { }, abilities = { } },
    -- IN FOG from the subject's team: only his own team sees him, and he is
    -- standing well inside the subject's 1600 search radius.
    { name = 'npc_dota_hero_lina', team = 3, x = 700.0, y = 0.0, hp = 150, max_hp = 1000,
      mp = 400, max_mp = 500, level = 9, alive = true, tp_cd = 0, net_worth = 9000,
]] .. seen_by_clause .. [[
      items = { }, abilities = { } },
  },
  observed = { burst = { }, died_after = nil },
}
]])
    f:close()
    return path
end

local function load(seen_by_clause)
    local path = write_fixture(seen_by_clause)
    local J, bot, heroes, fx = rf.load(path)
    os.remove(path)
    return J, bot, heroes, fx
end

local FOGGED = "      seen_by = { 3 },\n"
local V1 = "" -- pre-vision fixture: the field is simply absent

tests['fogged enemy reads CanBeSeen() == false'] = function()
    local _, _, heroes = load(FOGGED)
    assert(heroes['npc_dota_hero_lina']:CanBeSeen() == false,
        'lina is seen only by her own team (3); the subject team (2) is blind to her')
end

tests['lit enemy still reads CanBeSeen() == true'] = function()
    local _, _, heroes = load(FOGGED)
    assert(heroes['npc_dota_hero_luna']:CanBeSeen() == true,
        'luna is in seen_by = {2,3}; fog must not leak onto visible heroes')
end

tests['ally is always visible to its own team'] = function()
    local _, _, heroes = load(FOGGED)
    assert(heroes['npc_dota_hero_lion']:CanBeSeen() == true)
end

tests['J.CanCastOnNonMagicImmune rejects the fogged enemy'] = function()
    local J, _, heroes = load(FOGGED)
    assert(J.CanCastOnNonMagicImmune(heroes['npc_dota_hero_lina']) == false,
        'the real shipped predicate gates on CanBeSeen -- a fogged hero is not '
        .. 'a legal single-target cast, and a fixture must reproduce that')
    assert(J.CanCastOnNonMagicImmune(heroes['npc_dota_hero_luna']) == true)
end

tests['J.IsValid rejects the fogged enemy'] = function()
    local J, _, heroes = load(FOGGED)
    assert(J.IsValid(heroes['npc_dota_hero_lina']) == false)
    assert(J.IsValid(heroes['npc_dota_hero_luna']) == true)
end

tests['GetNearbyHeroes is vision-limited: fogged enemy is not nearby'] = function()
    local _, bot = load(FOGGED)
    local near = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    local names = {}
    for _, h in ipairs(near) do names[h:GetUnitName()] = true end
    assert(names['npc_dota_hero_luna'] == true, 'the lit enemy must still be nearby')
    assert(names['npc_dota_hero_lina'] == nil,
        'lina is 700u away but invisible to team 2 -- the engine would not '
        .. 'return her from GetNearbyHeroes, so neither may the mock')
end

tests['GetUnitList keeps the fogged enemy (global, not vision-limited)'] = function()
    local _, _, _ = load(FOGGED)
    local all = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    local names = {}
    for _, h in ipairs(all) do names[h:GetUnitName()] = true end
    assert(names['npc_dota_hero_lina'] == true and names['npc_dota_hero_luna'] == true,
        'GetUnitList returns handles across the entire map; callers that need '
        .. 'visibility filter it themselves (and global abilities legitimately '
        .. 'do not need to)')
end

tests['v1 fixture without seen_by stays fully visible (no behavior shift)'] = function()
    local J, bot, heroes = load(V1)
    assert(heroes['npc_dota_hero_lina']:CanBeSeen() == true,
        'every pre-existing fixture omits seen_by and must keep the old default')
    assert(J.CanCastOnNonMagicImmune(heroes['npc_dota_hero_lina']) == true)
    local near = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    assert(#near == 2, 'both enemies remain nearby on a v1 fixture, got ' .. #near)
end

tests['fog does not depend on which side is the subject'] = function()
    -- Sanity on the team arithmetic: the subject is team 2, so seen_by = {3}
    -- means fogged. Assert the loader read the subject's team from the fixture
    -- rather than assuming a constant.
    local _, bot = load(FOGGED)
    assert(bot:GetTeam() == SUBJ_TEAM)
    local _, _, heroes = load("      seen_by = { " .. ENEMY_TEAM .. ", " .. SUBJ_TEAM .. " },\n")
    assert(heroes['npc_dota_hero_lina']:CanBeSeen() == true,
        'adding the subject team to seen_by must light her up')
end

return tests
