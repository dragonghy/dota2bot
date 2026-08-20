-- The fixture world had no towers and no barracks near anybody.
--
-- tests/mock/bot_api.lua answers every unit method whose name starts with
-- `GetNearby` with `{}` (default_for). The replay loader had overridden exactly
-- one of them, GetNearbyHeroes. So in every fixture in this repo:
--
--     bot:GetNearbyTowers(r, bEnemies)    -- 183 call sites in bots/
--     bot:GetNearbyBarracks(r, bEnemies)  --  20 call sites
--
-- both answered "there is no tower and no barracks anywhere near anybody" --
-- while the same fixture already carried every structure with its real team,
-- position, alive flag and health (reachable only through GetTower / GetAncient
-- / UNIT_LIST_*_BUILDINGS, wired in the GH #58 round). Same family as the
-- HasModifier, WasRecentlyDamagedBy*, GetHeroLastSeenInfo, GetTower-slot and
-- UNIT_LIST_ALL gaps before it: an undeclared world assumption sitting under an
-- otherwise real frame, silently deciding branches nobody was watching.
--
-- The wiring is a RESTORATION: team, position and alive state are dump ground
-- truth. Two things are stated rather than reconstructed, and both are asserted
-- here so a later change to either one trips a test:
--   * ALIVE only -- a destroyed structure is absent, which is what every reader
--     already assumes when it treats `nEnemyTowers[1]` as "the nearest tower
--     still standing";
--   * SORTED BY DISTANCE ascending -- the engine promises no order, but every
--     shipped consumer reads [1] as "the closest one".
--
-- Wiring these two changed NO existing test outcome (745/745 before and after).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F = 'tests/fixtures/f_260820_102030_wk_tower_out_of_reach.lua'

local function dist(bot, u)
    return GetUnitToUnitDistance(bot, u)
end

tests['towers: the list matches the fixture, filtered by team, alive and radius'] = function()
    local _, bot, _, fx = rf.load(F)
    local subj = bot:GetTeam()

    -- Ground truth straight out of the fixture table, computed independently of
    -- the loader.
    local expect_enemy, expect_ally, dead = {}, {}, 0
    for _, b in ipairs(fx.buildings) do
        if b.name == 'tower' then
            if not b.alive then dead = dead + 1 end
            local d = math.sqrt((b.x - bot:GetLocation().x) ^ 2 + (b.y - bot:GetLocation().y) ^ 2)
            if b.alive and d <= 1200 then
                if b.team ~= subj then expect_enemy[#expect_enemy + 1] = d
                else expect_ally[#expect_ally + 1] = d end
            end
        end
    end
    assert(dead == 1, 'this frame has a fallen tower, so the alive filter is '
        .. 'actually exercised; got ' .. dead)
    assert(#expect_enemy == 1, 'exactly one live enemy tower within 1200; got ' .. #expect_enemy)
    assert(#expect_ally == 0, 'and no friendly tower within 1200; got ' .. #expect_ally)

    local got_enemy = bot:GetNearbyTowers(1200, true)
    local got_ally = bot:GetNearbyTowers(1200, false)
    assert(#got_enemy == 1, 'GetNearbyTowers(1200, true) must find it; got ' .. #got_enemy)
    assert(#got_ally == 0, 'and must not hand back the enemy one for bEnemies=false; got '
        .. #got_ally)
    assert(math.abs(dist(bot, got_enemy[1]) - expect_enemy[1]) < 1e-6,
        'and at the fixture distance')
    assert(got_enemy[1]:GetTeam() ~= subj and got_enemy[1]:GetUnitName() == 'tower',
        'the handle is an enemy tower')
    assert(got_enemy[1]:IsAlive(), 'and it is standing')
end

tests['towers: radius is honoured, and 800 vs 1200 really separate on this frame'] = function()
    local _, bot = rf.load(F)
    assert(#bot:GetNearbyTowers(1200, true) == 1, 'one inside 1200')
    assert(#bot:GetNearbyTowers(800, true) == 0, 'none inside 800')
    local d = dist(bot, bot:GetNearbyTowers(1200, true)[1])
    assert(d > 800 and d < 1200, 'the tower sits between the two radii at '
        .. string.format('%.1f', d))
end

tests['towers: the list is sorted nearest-first'] = function()
    local _, bot = rf.load(F)
    -- A radius wide enough to pick up several, so the ordering claim has teeth.
    local wide = bot:GetNearbyTowers(20000, true)
    assert(#wide >= 5, 'a map-wide radius finds most of the enemy towers; got ' .. #wide)
    for i = 2, #wide do
        assert(dist(bot, wide[i - 1]) <= dist(bot, wide[i]),
            'entry ' .. i .. ' is closer than the one before it -- every shipped '
            .. 'reader of [1] means "the closest", so the order is part of the wiring')
    end
end

tests['towers: outposts are not towers'] = function()
    local _, bot, _, fx = rf.load(F)
    local outposts = 0
    for _, b in ipairs(fx.buildings) do
        if b.name == 'watch_tower' then outposts = outposts + 1 end
    end
    assert(outposts == 2, 'the fixture carries both outposts; got ' .. outposts)
    for _, h in ipairs(bot:GetNearbyTowers(20000, true)) do
        assert(h:GetUnitName() == 'tower',
            'GetNearbyTowers returns tower-class structures only; got ' .. h:GetUnitName())
    end
    for _, h in ipairs(bot:GetNearbyTowers(20000, false)) do
        assert(h:GetUnitName() == 'tower', 'same for the friendly side')
    end
end

tests['barracks: wired from the same set, team-split the same way'] = function()
    local _, bot, _, fx = rf.load(F)
    local subj = bot:GetTeam()
    local n_enemy, n_ally = 0, 0
    for _, b in ipairs(fx.buildings) do
        if b.name == 'barracks' and b.alive then
            if b.team ~= subj then n_enemy = n_enemy + 1 else n_ally = n_ally + 1 end
        end
    end
    assert(n_enemy == 6 and n_ally == 6, 'twelve barracks, six a side, all standing on '
        .. 'this frame; got ' .. n_enemy .. '/' .. n_ally)
    assert(#bot:GetNearbyBarracks(20000, true) == n_enemy,
        'map-wide, the enemy six come back')
    assert(#bot:GetNearbyBarracks(20000, false) == n_ally, 'and the friendly six')
    assert(#bot:GetNearbyBarracks(800, true) == 0,
        'and none is within 800 of this bot -- the corpus never reaches a base '
        .. '(no frame in five turbo replays puts a hero within 800 of an enemy '
        .. 'barracks), which is why mode_retreat_generic ShouldRun 774 stays '
        .. 'unvalidated; see the report')
end

tests['LIMITATION: a structure still cannot answer how hard it hits'] = function()
    -- buildContext computes C.haveEnemyTowerThreat from
    -- GetAttackDamage() * GetAttackSpeed(); the dump carries neither, so the
    -- mock default answers 0 and the flag can never be true in a fixture. This
    -- is asserted rather than left implicit: whoever adds tower combat stats to
    -- the dump will fail this test and know to re-read every conclusion that
    -- leaned on the flag being unreachable.
    local _, bot = rf.load(F)
    local hTower = bot:GetNearbyTowers(20000, true)[1]
    assert(hTower ~= nil, 'a tower to ask')
    assert(hTower:GetAttackDamage() == 0 and hTower:GetAttackSpeed() == 0,
        'both are the mock GetX default, i.e. UNKNOWN, not "a tower that does '
        .. 'no damage"')
    assert(hTower:GetHealth() > 0 and hTower:GetMaxHealth() > 0,
        'health, by contrast, is real -- it comes from the dump')
end

return tests
