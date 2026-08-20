-- [loader contract] Fog memory in the fixture world.
--
-- One more undeclared world assertion of the director's §0b family (GetTower,
-- GetIncomingTrackingProjectiles, HasModifier, WasRecentlyDamagedBy*): the mock
-- answered `GetHeroLastSeenInfo(id) == {}` for every id, and the fixture loader
-- handed the SAME ally-index list back from `GetTeamPlayers(team)` no matter
-- which team was asked for. Both halves are needed, because every reader looks
-- like
--
--     for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
--         local info = GetHeroLastSeenInfo(id)
--         if info[1] and info[1].time_since_seen < 5.0 then ... end
--
-- With `{}` on the right the loop body was unreachable, so
-- J.GetLastSeenEnemiesNearLoc / J.GetLastSeenEnemies and every last-seen head
-- count in aba_defend returned an EMPTY LIST on every fixture, on every frame.
-- In plain words the old world asserted: "nobody has ever seen an enemy
-- anywhere." aba_defend alone reads it for the defend bid, the threatened-lane
-- pick, ShouldDefend's enemy count and DefendThink's path check.
--
-- What this file pins is the CONTRACT of the new wiring, not any hero logic:
-- the ids, the location, the staleness value, and the fact that the answer is
-- derived from the frame rather than from a hard-coded stub.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260819_223607_drow_defend_bail.lua'

local function dist2d(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

tests['GetTeamPlayers finally answers per team'] = function()
    local _, bot = rf.load(FIXTURE)
    local mine = GetTeamPlayers(GetTeam())
    local theirs = GetTeamPlayers(GetOpposingTeam())
    -- The ally half is the team ROSTER built by the GH #53 fix (dead members
    -- included, player-slot order) and is not touched here; assert only that it
    -- still resolves, so a regression there shows up in this file too.
    assert(#mine >= #GetUnitList(UNIT_LIST_ALLIED_HEROES),
        'the roster is a superset of the live allies; got ' .. #mine)
    for i = 1, #mine do
        assert(GetTeamMember(i) ~= nil, 'GetTeamMember(' .. i .. ') still resolves')
    end
    -- The enemy half is what this fix adds: one id per ALIVE enemy, which is the
    -- alive-only convention the unit lists already use (every shipped reader
    -- gates on IsHeroAlive, which the mock cannot answer per id).
    assert(#theirs == #GetUnitList(UNIT_LIST_ENEMY_HEROES),
        'one id per alive enemy; got ' .. #theirs)
    local seen = {}
    for _, id in ipairs(mine) do seen[id] = true end
    for _, id in ipairs(theirs) do
        assert(not seen[id], 'ally and enemy id spaces must be disjoint; ' ..
            tostring(id) .. ' is in both')
    end
    assert(bot ~= nil)
end

tests['GetHeroLastSeenInfo reports the real frame position, seen now'] = function()
    local _, bot = rf.load(FIXTURE)
    local byLoc = {}
    for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        byLoc[#byLoc + 1] = u
    end
    local matched = 0
    for _, id in ipairs(GetTeamPlayers(GetOpposingTeam())) do
        local info = GetHeroLastSeenInfo(id)
        assert(type(info) == 'table' and info[1] ~= nil,
            'every alive enemy must have a memory entry (id ' .. tostring(id) .. ')')
        assert(info[1].time_since_seen == 0,
            'no fixture carries per-hero vision yet (GH #27), so every sighting is '
            .. 'current; got ' .. tostring(info[1].time_since_seen))
        for _, u in ipairs(byLoc) do
            if dist2d(info[1].location, u:GetLocation()) < 1e-6 then matched = matched + 1 end
        end
    end
    assert(matched == #byLoc,
        'each remembered location must be some alive enemy\'s real frame position; '
        .. 'matched ' .. matched .. ' of ' .. #byLoc)
    assert(bot ~= nil)
end

tests['REVERSE: an id nobody owns has no memory'] = function()
    rf.load(FIXTURE)
    local info = GetHeroLastSeenInfo(987654)
    assert(type(info) == 'table' and info[1] == nil,
        'an unknown id must answer with an empty table, exactly like the engine '
        .. 'does for a player who has never been seen')
end

tests['J.GetLastSeenEnemiesNearLoc is no longer empty on every frame'] = function()
    local J, bot = rf.load(FIXTURE)
    local here = bot:GetLocation()
    local near = J.GetLastSeenEnemiesNearLoc(here, 1600)
    -- Independently recount from the unit list, so the helper is checked against
    -- the frame rather than against itself.
    local expect = 0
    for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if dist2d(here, u:GetLocation()) <= 1600 then expect = expect + 1 end
    end
    assert(expect > 0, 'this frame must actually have an enemy within 1600, '
        .. 'or it proves nothing')
    assert(#near == expect,
        'last-seen count must match the frame: expected ' .. expect .. ', got ' .. #near)
end

tests['the radius argument is honoured in both directions'] = function()
    local J, bot = rf.load(FIXTURE)
    local here = bot:GetLocation()
    assert(#J.GetLastSeenEnemiesNearLoc(here, 1) == 0,
        'nobody is standing exactly on the subject')
    assert(#J.GetLastSeenEnemiesNearLoc(here, 30000) ==
        #GetUnitList(UNIT_LIST_ENEMY_HEROES),
        'a map-sized radius must reach every alive enemy')
end

tests['TEAM_RADIANT / TEAM_DIRE are the engine values, not sentinels'] = function()
    local J = rf.load(FIXTURE)
    assert(TEAM_RADIANT == 2 and TEAM_DIRE == 3,
        'the shipped code compares GetTeam() (a real 2/3) against these names; '
        .. 'as auto-sentinels every such comparison was silently false')
    assert(GetTeam() == TEAM_DIRE,
        'this fixture subject is Dire -- the premise of the fountain check below')
    local ours, theirs = J.GetTeamFountain(), J.GetEnemyFountain()
    assert(ours.x > 0 and ours.y > 0,
        'the Dire fountain is the top-right corner; got ('
        .. tostring(ours.x) .. ', ' .. tostring(ours.y) .. ')')
    assert(ours.x ~= theirs.x or ours.y ~= theirs.y,
        'the two fountains must not be the same point')
end

return tests
