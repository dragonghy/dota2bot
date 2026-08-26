-- [basesiege] "the defenders around me are at least as many as my friends",
-- written as `#hEnemyHeroList >= #hAllyHeroList` -- true when BOTH are zero.
--
-- THE DEFECT (shipped default, ungated, two files)
-- -----------------------------------------------
-- mode_retreat_generic.lua X.ShouldRun and mode_farm_generic.lua X.ShouldRun
-- carry the same copy-pasted block:
--
--     if #nEnemyBrracks >= 1 and aliveEnemyCount >= 2
--        and #hEnemyHeroList >= #hAllyHeroList
--     then
--         if #nEnemyTowers >= 2 or enemyAncientDistance <= 1314
--            or enemyFountainDistance <= 2828 then return 2 end
--     end
--
-- Both lists come from J.GetEnemyList(bot,1600) / J.GetAllyList(bot,1600), and
-- the ally list does NOT contain the bot itself -- bot:GetNearbyHeroes never
-- returns self, which the fixture loader implements the same way
-- (tests/mock/replay_fixture.lua, `other ~= self`). So both empty means "no
-- living hero of either team within 1600 of me", and the clause reads that as
-- outnumbered.
--
-- A non-zero ShouldRun is not a hint. Both callers convert it into
-- BOT_MODE_DESIRE_ABSOLUTE * 1.1 -- the highest desire in the system -- and
-- latch it for the returned number of seconds (2); the farm caller also drops
-- preferedCamp and calls Action_ClearActions(true). The situation it fires on
-- is a bot inside the enemy barracks ring with nobody in sight: a lone
-- backdoor push, one attack from a rax, turned around by a head-count of a
-- fight that is not happening.
--
-- THE LEVER, AND ITS EXACT WIDTH
-- ------------------------------
-- J.IsBasePresenceAdverse, gated 'basesiege', turbo-only. Armed it answers
-- false when the enemy count is zero. That differs from the shipped comparison
-- ONLY in the both-zero case: with zero enemies and any ally present the
-- shipped comparison is already false, and with one or more enemies the gate is
-- not consulted. [lever] below proves that exhaustively over 0..5 x 0..5 rather
-- than asserting it in prose.
--
-- WHAT THIS FILE MEASURES, AND WHAT IT DOES NOT -- read before quoting a number
-- ---------------------------------------------------------------------------
-- The PREDICATE runs on real frames here: every count below is produced by the
-- shipped J.GetEnemyList / J.GetAllyList against real hero positions and real
-- fog, not by a stub. Census over the whole fixture archive with those same
-- helpers, 966 live addressable hero frames: 302 read both-zero (31.3%), 161
-- read zero enemies with allies present, 151 read enemies with no ally, 352
-- read both non-empty. So the predicate's answer changes on about a third of
-- all live frames.
--
-- The enclosing BRANCH is a different question and is NOT answered here. It
-- needs an enemy barracks within 800 units, and no frame in the corpus puts any
-- hero closer than 4838 units to one -- games were capped at 10 game-minutes
-- until GH #108 raised the cap to 25, so nothing in the archive contains a
-- siege. [limit] asserts that unreachability on the frame instead of leaving it
-- to prose. The 31.3% is the predicate's domain; the branch's domain is open,
-- and the case for arming this id rests on value per firing, not on frequency.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- Both-zero: Zeus alone, the deepest such frame in the archive measured by
-- distance to the enemy ancient (7278 units).
local ALONE_FRAME = 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua'
local ALONE_HERO = 'npc_dota_hero_zuus'

-- Controls, all three of the other presence shapes, each on a real frame.
local ALLY_ONLY_FRAME = 'tests/fixtures/f_045650_lion_meatgrinder.lua'
local ALLY_ONLY_HERO = 'npc_dota_hero_venomancer'          -- e=0 a=1
local ENEMY_ONLY_FRAME = 'tests/fixtures/f_011405_jak_rescue_axe.lua'
local ENEMY_ONLY_HERO = 'npc_dota_hero_zuus'               -- e=1 a=0
local BOTH_FRAME = 'tests/fixtures/f_011405_jak_rescue_axe.lua'
local BOTH_HERO = 'npc_dota_hero_axe'                      -- e=2 a=1

local tests = {}

--- Load a frame with `ids` armed. Returns J, bot.
local function frame(path, hero, ids)
    local J, bot = rf.load(path, hero)
    local armed = {}
    for _, id in ipairs(ids or {}) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    return J, bot
end

--- The two lists the call sites hand the predicate, built the shipped way.
local function lists(J, bot)
    return J.GetEnemyList(bot, 1600), J.GetAllyList(bot, 1600)
end

-- ---- world facts this file's reach depends on --------------------------------

tests['[W1] the ally list excludes the bot itself, so both-zero is reachable'] = function()
    local J, bot = frame(ALONE_FRAME, ALONE_HERO, {})
    for _, ally in ipairs(J.GetAllyList(bot, 1600)) do
        assert(ally ~= bot,
            'the bot appears in its own ally list. Then #hAllyHeroList is never '
            .. 'zero, the both-zero case cannot arise, and this whole file is '
            .. 'about a situation that does not exist')
    end
end

tests['[W2] this frame is Turbo, which the gate structurally requires'] = function()
    local J = frame(ALONE_FRAME, ALONE_HERO, {})
    assert(J.IsModeTurbo() == true,
        'the batch corpus is Turbo and the gate is turbo-only; if this frame '
        .. 'ever reads non-turbo, every [armed] case below is vacuously true '
        .. 'for the wrong reason')
end

tests['[frame] the presence readings the cases rest on have not moved'] = function()
    local expected = {
        { ALONE_FRAME, ALONE_HERO, 0, 0 },
        { ALLY_ONLY_FRAME, ALLY_ONLY_HERO, 0, 1 },
        { ENEMY_ONLY_FRAME, ENEMY_ONLY_HERO, 1, 0 },
        { BOTH_FRAME, BOTH_HERO, 2, 1 },
    }
    for _, row in ipairs(expected) do
        local J, bot = frame(row[1], row[2], {})
        local e, a = lists(J, bot)
        assert(#e == row[3] and #a == row[4], string.format(
            '%s / %s used to read e=%d a=%d, now e=%d a=%d -- the corpus moved '
            .. 'and the case below it is no longer the case it claims to be',
            row[1], row[2], row[3], row[4], #e, #a))
    end
end

tests['[limit] the enclosing branch is unreachable on this frame, and says so'] = function()
    local _, bot = frame(ALONE_FRAME, ALONE_HERO, {})
    assert(#bot:GetNearbyBarracks(800, true) == 0,
        'a fixture now puts a hero within 800 of an enemy barracks. That is '
        .. 'good news and it obsoletes this limit: the branch should then be '
        .. 'driven end to end through X.ShouldRun instead of at the predicate')
end

-- ---- the defect itself, on the real frame ------------------------------------

tests['[unarmed] a lone bot with nobody in sight reads as outnumbered'] = function()
    local J, bot = frame(ALONE_FRAME, ALONE_HERO, {})
    local e, a = lists(J, bot)
    assert(J.IsBasePresenceAdverse(e, a) == true,
        'unarmed the predicate must answer exactly what the shipped comparison '
        .. 'answered -- and `0 >= 0` is true. If this reads false unarmed the '
        .. 'repair stopped being dark and changed shipped behaviour')
end

tests['[armed] the same frame reads as no defenders present'] = function()
    local J, bot = frame(ALONE_FRAME, ALONE_HERO, { 'basesiege' })
    local e, a = lists(J, bot)
    assert(J.IsBasePresenceAdverse(e, a) == false,
        'armed, an empty 1600 ring must not read as outnumbered -- that is the '
        .. 'whole lever')
end

tests['[armed] outside Turbo the gate is shut and the shipped answer returns'] = function()
    local J, bot = frame(ALONE_FRAME, ALONE_HERO, { 'basesiege' })
    J.IsModeTurbo = function() return false end
    local e, a = lists(J, bot)
    assert(J.IsBasePresenceAdverse(e, a) == true,
        'the predicate is turbo-only; outside turbo it must answer the shipped '
        .. '`0 >= 0`, exactly as if nothing were armed')
end

-- ---- the three controls: real frames the lever must NOT touch -----------------

tests['[control] zero enemies with an ally present was already false'] = function()
    for _, ids in ipairs({ {}, { 'basesiege' } }) do
        local J, bot = frame(ALLY_ONLY_FRAME, ALLY_ONLY_HERO, ids)
        local e, a = lists(J, bot)
        assert(J.IsBasePresenceAdverse(e, a) == false,
            'with an ally in the ring the shipped comparison is already false; '
            .. 'the gate must not be what produces that answer')
    end
end

tests['[control] a visible enemy and no ally stays adverse, armed or not'] = function()
    for _, ids in ipairs({ {}, { 'basesiege' } }) do
        local J, bot = frame(ENEMY_ONLY_FRAME, ENEMY_ONLY_HERO, ids)
        local e, a = lists(J, bot)
        assert(J.IsBasePresenceAdverse(e, a) == true,
            'a real defender is standing there and the bot is alone. Arming '
            .. 'this id must not make a genuinely outnumbered bot stay')
    end
end

tests['[control] outnumbered with allies present stays adverse, armed or not'] = function()
    for _, ids in ipairs({ {}, { 'basesiege' } }) do
        local J, bot = frame(BOTH_FRAME, BOTH_HERO, ids)
        local e, a = lists(J, bot)
        assert(J.IsBasePresenceAdverse(e, a) == true,
            'two enemies against one ally is the situation the clause was '
            .. 'written for and it must survive the repair untouched')
    end
end

-- ---- exactly one lever, proved rather than asserted --------------------------

tests['[lever] armed and shipped differ on the both-zero cell and nowhere else'] = function()
    local J = frame(ALONE_FRAME, ALONE_HERO, { 'basesiege' })
    local Junarmed = frame(ALONE_FRAME, ALONE_HERO, {})
    local function listOf(n)
        local t = {}
        for i = 1, n do t[i] = i end
        return t
    end
    local differ = {}
    for nEnemies = 0, 5 do
        for nAllies = 0, 5 do
            local e, a = listOf(nEnemies), listOf(nAllies)
            local shipped = nEnemies >= nAllies
            assert(Junarmed.IsBasePresenceAdverse(e, a) == shipped, string.format(
                'unarmed the predicate must equal `#enemies >= #allies`; it '
                .. 'disagreed at e=%d a=%d', nEnemies, nAllies))
            if J.IsBasePresenceAdverse(e, a) ~= shipped then
                differ[#differ + 1] = string.format('e=%d a=%d', nEnemies, nAllies)
            end
        end
    end
    assert(#differ == 1 and differ[1] == 'e=0 a=0', string.format(
        'the armed predicate must differ from the shipped one in exactly the '
        .. 'both-zero cell. It differs in {%s}', table.concat(differ, ', ')))
end

-- ---- the call sites, pinned ---------------------------------------------------

local function source(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a')
    fh:close()
    -- Strip line comments: the block above each call site quotes the old shape
    -- in prose, and a whole-file match would find the description instead of
    -- live code (charter 0NIL judgement two).
    return (s:gsub('%-%-[^\n]*', ''))
end

tests['[source] both ShouldRun blocks route through the repaired predicate'] = function()
    for _, path in ipairs({ 'bots/mode_retreat_generic.lua', 'bots/mode_farm_generic.lua' }) do
        local src = source(path)
        local _, nCall = src:gsub('J%.IsBasePresenceAdverse%(hEnemyHeroList, hAllyHeroList%)', '')
        assert(nCall == 1, string.format(
            'expected exactly one J.IsBasePresenceAdverse call site in %s, '
            .. 'found %d', path, nCall))
        assert(src:find('#hEnemyHeroList >= #hAllyHeroList', 1, true) == nil, string.format(
            'the bare comparison is back in live code in %s (comments are '
            .. 'stripped before this match, so this is not the explanatory '
            .. 'block)', path))
    end
end

tests['[source] the barracks test still short-circuits ahead of the predicate'] = function()
    for _, path in ipairs({ 'bots/mode_retreat_generic.lua', 'bots/mode_farm_generic.lua' }) do
        local src = source(path)
        assert(src:find('#nEnemyBrracks >= 1 and aliveEnemyCount >= 2 and J.IsBasePresenceAdverse', 1, true) ~= nil,
            string.format('the conjunct order changed in %s. The barracks test '
                .. 'must stay on the left: it is what keeps this predicate off '
                .. 'the overwhelming majority of frames', path))
    end
end

return tests
