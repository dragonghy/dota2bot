-- The ninth undeclared world assumption: GetUnitList(UNIT_LIST_ALL) was EMPTY
-- in every fixture -- not "no creeps", NO UNITS AT ALL.
--
-- tests/mock/replay_fixture.lua answered only UNIT_LIST_ENEMY_HEROES and
-- UNIT_LIST_ALLIED_HEROES and fell through to `{}` for everything else. Two
-- heavily-read consumers sweep the world through UNIT_LIST_ALL instead:
--
--   * mode_retreat_generic.buildContext() builds BOTH of the retreat mode's
--     hero lists from it, so `#nAllyHeroes` and `#nEnemyHeroes` were 0 on
--     every frame of every fixture, and the retreat bid's whole "am I
--     outnumbered here" section compared 0 against 0;
--   * J.WeAreStronger(bot, radius) sums hero power over it, so it weighed an
--     empty team against an empty team -- in every fixture, at every radius.
--
-- Same family as the HasModifier / WasRecentlyDamagedBy* / GetHeroLastSeenInfo
-- / structure gaps before it (test_set.md §F): the harness answered a definite
-- number rather than refusing, so a test could asssert the wrong thing and
-- stay green. The heroes are ground truth in the dump, so they are restored.
--
-- WHAT IS STILL MISSING (declared, not faked -- see GH #61's thread): the
-- engine's UNIT_LIST_ALL also carries creeps, buildings, couriers, wards and
-- summons. The dump has creeps (3s cadence, no lane/alive attribution) but the
-- fixture generator does not write them, and buildings are deliberately not
-- injected into this list because the one shipped reader that would pick them
-- up (buildContext's tower-danger clause) needs GetAttackDamage() *
-- GetAttackSpeed(), which the dump does not carry. So any assertion that needs
-- a CREEP, a SUMMON or a TOWER to be seen through UNIT_LIST_ALL is still
-- reading an empty set, and must say so.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F_ALONE = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local F_CLOSE = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

tests['UNIT_LIST_ALL is the live hero set, both teams, self included'] = function()
    local _, bot = rf.load(F_ALONE)
    local all = GetUnitList(UNIT_LIST_ALL)
    local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)
    local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    assert(count(all) > 0, 'the world is no longer empty')
    assert(count(all) == count(allies) + count(enemies),
        'it is exactly allies + enemies; got ' .. count(all) .. ' vs '
        .. (count(allies) + count(enemies)))

    local seenSelf = false
    local byTeam = {}
    for _, u in pairs(all) do
        if u == bot then seenSelf = true end
        byTeam[u:GetTeam()] = (byTeam[u:GetTeam()] or 0) + 1
        assert(u:IsAlive(), 'only live units, exactly as the engine reports them')
    end
    assert(seenSelf, 'the bot is a unit in the world -- the engine lists it too, '
        .. 'which is why #nAllyHeroes is never 0 for a live bot')
    assert(count(byTeam) == 2, 'both teams are present; got ' .. count(byTeam))
end

tests['the retreat mode now sees its own two hero lists'] = function()
    -- The consumer that motivated this: buildContext's 1600-radius split.
    -- On this frame three enemies stand 2974/3086/3172 away and no ally is
    -- within 1600, so the honest answer is 0 enemies and 1 ally (self).
    local _, bot = rf.load(F_ALONE)
    local nEnemyNear, nAllyNear = 0, 0
    for _, u in pairs(GetUnitList(UNIT_LIST_ALL)) do
        if GetUnitToUnitDistance(bot, u) <= 1600 then
            if u:GetTeam() == bot:GetTeam() then nAllyNear = nAllyNear + 1
            else nEnemyNear = nEnemyNear + 1 end
        end
    end
    assert(nAllyNear == 1, 'only the bot itself is within 1600; got ' .. nAllyNear)
    assert(nEnemyNear == 0, 'no enemy is within 1600 of it; got ' .. nEnemyNear)
end

tests['J.WeAreStronger stops weighing an empty team against an empty team'] = function()
    -- Not an assertion about which side is stronger -- an assertion that the
    -- function has anything at all to weigh. Before the wiring both of its
    -- lists were empty on every frame.
    local J, bot = rf.load(F_CLOSE)
    local n = 0
    for _, u in pairs(GetUnitList(UNIT_LIST_ALL)) do
        if GetUnitToUnitDistance(bot, u) <= 1600 then n = n + 1 end
    end
    assert(n >= 3, 'this frame really does have units inside its radius: '
        .. 'axe, an ally, skywrath 188u and slardar 741u; got ' .. n)
    assert(type(J.WeAreStronger(bot, 1600)) == 'boolean',
        'and the comparison runs to a verdict')
end

tests['LIMITATION, asserted: no creeps, summons or structures in this list'] = function()
    -- When this starts failing somebody has widened the list. That is welcome,
    -- but every claim in this repo of the form "N units were nearby" was
    -- measured in the hero-only world and has to be re-read.
    local _, bot = rf.load(F_ALONE)
    for _, u in pairs(GetUnitList(UNIT_LIST_ALL)) do
        local name = u:GetUnitName()
        assert(name:find('npc_dota_hero_', 1, true) == 1,
            'hero-only world; found ' .. name)
    end
    assert(count(GetUnitList(UNIT_LIST_ALLIED_CREEPS)) == 0,
        'creeps are a SUPPLY gap (the generator writes none), not a claim that '
        .. 'the lane was empty')
    assert(bot:GetNearbyLaneCreeps(1200, true) ~= nil,
        'the creep readers still answer, they just answer nothing')
end

return tests
