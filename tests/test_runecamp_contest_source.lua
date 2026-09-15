-- [ratchet] [strategy 2026-09-15] Soak candidate 'runecamp': the guard asks
-- a question about the RUNE and looks for the answer around ITSELF.
--
-- THE DEFECT (shipped default, bots/mode_rune_generic.lua X.IsEnemyPickRune)
-- -------------------------------------------------------------------------
-- Every clause of that guard is anchored on the rune:
--
--     enemy:IsFacingLocation(vRuneLocation, 30)
--     GetUnitToLocationDistance(enemy, vRuneLocation) < 600
--     GetUnitToLocationDistance(enemy, vRuneLocation)
--         < GetUnitToLocationDistance(bot, vRuneLocation) + 300
--
-- and the set it walks is anchored on the bot: `nEnemyHeroes`, which GetDesire
-- fills with `bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)`.
--
-- The domain that leaves is derivable, not a matter of taste. An enemy that can
-- satisfy the conjunction is within `dist(bot, rune) + 300` of the rune; one
-- actually STANDING on the rune is therefore `dist(bot, rune)` from the bot. The
-- guard's own early return drops everything closer than 600u, so a rune-camper
-- is visible to it only while `600 < dist(bot, rune) <= 1600` -- a 1000u
-- annulus -- while the desire it guards is scaled out to 3500u (bounty) and
-- 4000u (power, `nProximityRadius * 2.5`). Past 1600u the ambush the GetDesire
-- comment names in so many words ("This prevents bots from walking into 5-man
-- ambushes at rune spots") is invisible BY CONSTRUCTION -- and it is invisible
-- exactly when the walk is longest and the ambush most worth avoiding.
--
-- THE LEVER ('runecamp', turbo-only). One token moves: the set. Armed, the
-- candidates come from `J.GetEnemiesNearLoc(vRuneLocation, dist(bot, rune)+300)`
-- -- the conjunction's OWN domain, the bound its last clause already tests. No
-- clause is relaxed and no constant is invented.
--
-- WHAT THIS FILE CAN AND CANNOT BUY -- read this before trusting a number below
-- ---------------------------------------------------------------------------
-- The GEOMETRY half is real, all of it. Every hero below is a real hero at its
-- real position off a real .dem frame, and every distance the guard reads is a
-- real hero-to-hero distance from that frame.
--
-- The RUNE half is not in the corpus and is not pretended to be:
-- `tools/batch_test/behavioral/detect.py` says in so many words that "aegis/rune
-- state is NOT present in the replay dump", so no fixture can say where a rune
-- was or whether it was up. The declaration this file makes is therefore the
-- smallest one that lets the shipped decision run: A RUNE SPAWNS WHERE ONE REAL
-- ENEMY HERO IS STANDING. Nothing else is invented -- `dist(bot, rune)` is the
-- real bot-to-that-hero distance, `dist(enemy, rune)` for each other enemy is a
-- real hero-to-hero distance, and the 1600u ring the shipped guard reads is the
-- real one. [limit] pins the dump's silence on rune state so that the day the
-- dumper starts emitting runes, this stand-in goes red and retires itself.
--
-- WHAT IS DRIVEN, not declared: the real `GetDesire()` of the real
-- bots/mode_rune_generic.lua, through the real J.IsSoakCandidate reading the
-- real bots/Customize/soak_side.lua. No J.* function is stubbed anywhere here.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')
local ss = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local SRC = 'bots/mode_rune_generic.lua'

-- The bearing frame. Axe, alone, 2974u from three enemies standing together --
-- 1.9x the 1600u ring the shipped guard can see into. Axe is also the closest
-- living ally to that spot, which is what makes X.GetBestRune hand the rune to
-- HIM rather than to a team mate.
local FAR_FIX  = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local FAR_SUBJ = 'npc_dota_hero_axe'
local FAR_AT   = 'npc_dota_hero_slardar'

-- The in-annulus control: 1231u apart, inside the ring, so the SHIPPED guard
-- already sees this one. Armed must agree, not "improve" it.
local NEAR_FIX  = 'tests/fixtures/f_071423_luna_chase.lua'
local NEAR_SUBJ = 'npc_dota_hero_dragon_knight'
local NEAR_AT   = 'npc_dota_hero_queen_of_pain'

local tests = {}

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

--- Stand the frame up and declare the one thing the dump cannot carry: a rune
--- spawns at `sAt`'s real location, and it is up. Every other rune slot is put
--- off the map so X.GetBestRune has exactly one thing to choose.
local function world(sFix, sSubj, sAt)
    local J, bot, heroes, fx = rf.load(sFix, sSubj)
    local hAt = heroes[sAt]
    assert(hAt ~= nil, sFix .. ' no longer carries ' .. sAt)
    local vRune = hAt:GetLocation()
    local vOff = api.Vector(12000, 12000, 0)
    _G.GetRuneSpawnLocation = function(n)                    -- luacheck: ignore
        if n == RUNE_POWERUP_1 then return vRune end
        return vOff
    end
    _G.GetRuneType = function() return RUNE_DOUBLEDAMAGE end -- luacheck: ignore
    _G.GetRuneStatus = function(n)                           -- luacheck: ignore
        if n == RUNE_POWERUP_1 then return RUNE_STATUS_AVAILABLE end
        return RUNE_STATUS_MISSING
    end
    dofile(SRC)
    return J, bot, heroes, fx, vRune
end

local function desire(sFix, sSubj, sAt)
    local _, _, _, _, _ = world(sFix, sSubj, sAt)
    return GetDesire()
end

local function side_of(sFix, sSubj)
    local _, bot = rf.load(sFix, sSubj)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

-- ==========================================================================
-- WORLD FACTS. The frame is asserted, never described.
-- ==========================================================================

tests['[world] the bearing frame really is out of the shipped guard\'s reach']
= function()
    local _, bot, heroes = world(FAR_FIX, FAR_SUBJ, FAR_AT)
    local vRune = heroes[FAR_AT]:GetLocation()
    local d = GetUnitToLocationDistance(bot, vRune)
    assert(math.abs(d - 2974) < 5, 'the frame moved: axe used to stand 2974u '
        .. 'from slardar, now ' .. string.format('%.0f', d))
    assert(d > 1600, 'the bearing distance fell inside the ring; this file no '
        .. 'longer demonstrates anything')

    -- The shipped candidate set, read from the shipped call, not re-derived.
    local tRing = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    assert(#tRing == 0, 'the shipped 1600u ring now holds ' .. #tRing
        .. ' enemies on this frame -- the guard is no longer blind here')
end

tests['[world] three real enemies stand on the declared rune spot'] = function()
    local J, bot, heroes = world(FAR_FIX, FAR_SUBJ, FAR_AT)
    local vRune = heroes[FAR_AT]:GetLocation()
    local n = 0
    for _, e in ipairs(J.GetEnemiesNearLoc(vRune, 600)) do
        assert(e:GetTeam() ~= bot:GetTeam())
        n = n + 1
    end
    assert(n == 3, 'the enemy stack on the bearing frame is now ' .. n
        .. ', not 3 -- re-read the frame before quoting this file')
end

tests['[world] the subject is the closest living ally to that spot'] = function()
    local _, bot, heroes = world(FAR_FIX, FAR_SUBJ, FAR_AT)
    local vRune = heroes[FAR_AT]:GetLocation()
    local dBot = GetUnitToLocationDistance(bot, vRune)
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local m = GetTeamMember(i)
        if m ~= nil and m ~= bot and m:IsAlive() then
            assert(GetUnitToLocationDistance(m, vRune) >= dBot,
                m:GetUnitName() .. ' now stands closer to the spot than the '
                .. 'subject -- X.GetBestRune would hand the rune to it and this '
                .. 'file would be measuring a different bot')
        end
    end
end

tests['[world] the control frame really is INSIDE the ring'] = function()
    local _, bot, heroes = world(NEAR_FIX, NEAR_SUBJ, NEAR_AT)
    local d = GetUnitToLocationDistance(bot, heroes[NEAR_AT]:GetLocation())
    assert(math.abs(d - 1231) < 5, 'the control frame moved: 1231u -> '
        .. string.format('%.0f', d))
    assert(d > 600 and d <= 1600, 'the control frame left the annulus the '
        .. 'shipped guard can see into (600, 1600]')
end

-- ==========================================================================
-- [limit] The declaration, and the tripwire that retires it.
-- ==========================================================================

tests['[limit] the dump carries no rune state, which is why the spot is declared']
= function()
    local s = read('tools/batch_test/behavioral/detect.py')
    assert(s:find('rune state is NOT present in the replay dump', 1, true),
        'detect.py no longer states that the dump carries no rune state. If '
        .. 'the dumper started emitting runes, stop declaring the spot in '
        .. 'world() and take it off a real frame instead.')
    local gen = read('tools/batch_test/replayscope/make_fixture.py')
    assert(not gen:find('RUNE_POWERUP', 1, true),
        'make_fixture.py mentions rune slots now -- same retirement notice')
end

-- ==========================================================================
-- THE FIX. Both legs of one decision, driven through the shipped GetDesire.
-- ==========================================================================

tests['[fix] ⭐ unarmed, the bot bids to walk 2974u onto three enemies']
= function()
    local d = desire(FAR_FIX, FAR_SUBJ, FAR_AT)
    assert(d > 0, 'the shipped bid on the bearing frame is now ' .. tostring(d)
        .. '; with no bid left there is nothing for this lever to suppress')
    assert(math.abs(d - 0.4712) < 0.01, 'the shipped bid moved: 0.4712 -> '
        .. tostring(d) .. ' -- something else in GetDesire changed, re-read it')
end

tests['[fix] ⭐⭐ armed, the same frame reads BOT_MODE_DESIRE_NONE'] = function()
    ss.with_candidate('runecamp', function()
        local d = desire(FAR_FIX, FAR_SUBJ, FAR_AT)
        assert(d == BOT_MODE_DESIRE_NONE, 'armed bid is ' .. tostring(d)
            .. ', not NONE -- the rune-sourced candidate set did not reach the '
            .. 'guard')
    end, side_of(FAR_FIX, FAR_SUBJ))
end

tests['[fix] armed does not change the decision the shipped guard already makes']
= function()
    local dUnarmed = desire(NEAR_FIX, NEAR_SUBJ, NEAR_AT)
    assert(dUnarmed == BOT_MODE_DESIRE_NONE, 'the control frame no longer '
        .. 'refuses unarmed (' .. tostring(dUnarmed) .. '); it was chosen '
        .. 'because the SHIPPED guard sees this one')
    ss.with_candidate('runecamp', function()
        local dArmed = desire(NEAR_FIX, NEAR_SUBJ, NEAR_AT)
        assert(dArmed == dUnarmed, 'armed moved a decision the shipped code '
            .. 'already made correctly: ' .. tostring(dUnarmed) .. ' -> '
            .. tostring(dArmed))
    end, side_of(NEAR_FIX, NEAR_SUBJ))
end

-- ==========================================================================
-- [control] The gate, from both directions. An unarmed reading is what MOST of
-- this file expects, so the two ways of getting one by accident are named.
-- ==========================================================================

tests['[control] with no switch on disk the bearing frame bids as shipped']
= function()
    assert(io.open(ss.PATH) == nil or (function()
        local fh = io.open(ss.PATH); fh:close(); return false end)(),
        'a soak_side switch this process does not own is on disk; this case '
        .. 'cannot tell an unarmed gate from someone else\'s armed one')
    local d = desire(FAR_FIX, FAR_SUBJ, FAR_AT)
    assert(d > 0, 'no switch on disk and the bid is still ' .. tostring(d))
end

tests['[control] armed on the OTHER side, the bearing frame bids as shipped']
= function()
    local sOther = side_of(FAR_FIX, FAR_SUBJ) == 'radiant' and 'dire' or 'radiant'
    ss.with_candidate('runecamp', function()
        local d = desire(FAR_FIX, FAR_SUBJ, FAR_AT)
        assert(d > 0, 'the gate fired for a bot on the other side: '
            .. tostring(d))
    end, sOther)
end

tests['[control] armed under another id, the bearing frame bids as shipped']
= function()
    ss.with_candidate('campfarm', function()
        local d = desire(FAR_FIX, FAR_SUBJ, FAR_AT)
        assert(d > 0, 'the gate fired under a different candidate id: '
            .. tostring(d))
    end, side_of(FAR_FIX, FAR_SUBJ))
end

-- ==========================================================================
-- [gate] Source-level invariants. These hold for every pair of frames, which
-- is why they are not driven.
-- ==========================================================================

local function guard_body()
    local src = strip_comments(read(SRC))
    local body = src:match('function X%.IsEnemyPickRune%b()(.-)\nend')
    assert(body, 'X.IsEnemyPickRune is gone from ' .. SRC)
    return body
end

tests['[gate] the lever is turbo-only'] = function()
    assert(guard_body():find('J%.IsModeTurbo%s*%(%s*%)'),
        'the runecamp gate lost its J.IsModeTurbo() conjunct')
end

tests['[gate] the gate names exactly one soak id -- its own (pullcad trap)']
= function()
    local body = guard_body()
    local ids = {}
    for id in body:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1, 'the runecamp gate names ' .. #ids .. ' soak ids ('
        .. table.concat(ids, ' ') .. '). A gate conditioned on a SECOND id is '
        .. 'frozen false the day that id is promoted -- a promoted id is in no '
        .. 'armed string -- and check_armed_wiring.py still calls it WIRED.')
    assert(ids[1] == 'runecamp', 'the gate names ' .. ids[1])
end

tests['[gate] ⭐ not one clause of the guard moved -- only the set it walks']
= function()
    local body = guard_body()
    -- The three rune-anchored clauses, verbatim. If a future edit "helps" the
    -- lever by loosening one of them, this file stops describing what shipped.
    for _, clause in ipairs({
        'enemy:IsFacingLocation%(vRuneLocation, 30%)',
        'GetUnitToLocationDistance%(enemy, vRuneLocation%) < 600',
        'GetUnitToLocationDistance%(enemy, vRuneLocation%) < '
            .. 'GetUnitToLocationDistance%(bot, vRuneLocation%) %+ 300',
    }) do
        assert(body:find(clause), 'a clause of the guard changed; the lever is '
            .. 'supposed to change only the candidate set. Missing: ' .. clause)
    end
    assert(body:find('if GetUnitToLocationDistance%(bot, vRuneLocation%) < 600 '
        .. 'then return false end'),
        'the < 600 early return moved; the annulus this file prices is derived '
        .. 'from it')
end

tests['[gate] ⭐ the armed radius is the last clause\'s own bound, not a new one']
= function()
    local body = guard_body()
    assert(body:find('J%.GetEnemiesNearLoc%(vRuneLocation,%s*\n?%s*'
        .. 'GetUnitToLocationDistance%(bot, vRuneLocation%) %+ 300%)'),
        'the armed radius is no longer `dist(bot, rune) + 300`. Any other '
        .. 'number is a constant this lever invented, and the claim that the '
        .. 'armed set is exactly the conjunction\'s own domain stops holding.')
    -- No literal ring of the shipped kind may appear in the gated branch.
    local gated = body:match('IsSoakCandidate.-\n(.-)\n%s*end')
    assert(gated and not gated:find('1600'),
        'a 1600 literal appeared in the gated branch')
end

tests['[novision] ⭐ armed buys no fog: the loop\'s first clause is CanBeSeen']
= function()
    assert(guard_body():find('J%.IsValidHero%(enemy%)'),
        'the loop no longer opens on J.IsValidHero -- that clause is the only '
        .. 'reason the rune-sourced set cannot see through fog')
    local utils = strip_comments(read('bots/FunLib/utils.lua'))
    local valid = utils:match('function ____exports%.IsValidUnit%b()(.-)\nend')
    assert(valid and valid:find('CanBeSeen%(%)'),
        'utils.IsValidUnit no longer checks CanBeSeen(); the "no fog is bought" '
        .. 'claim in mode_rune_generic.lua rests on exactly this')
    local hero = utils:match('function ____exports%.IsValidHero%b()(.-)\nend')
    assert(hero and hero:find('IsValidUnit'),
        'IsValidHero no longer routes through IsValidUnit')
end

-- ==========================================================================
-- [domain] What the blindness is worth, on the corpus. The numbers quoted in
-- the header of bots/mode_rune_generic.lua are computed here, not asserted
-- there.
--
-- ⭐ Both counters below are called a SECOND time with the leg swapped (the
-- ring opened to the whole map), because a walk that loaded nothing, a parser
-- that resolved no names and a ring that admitted nobody all report the same
-- number, and it is the number this section is built on.
-- ==========================================================================

local memo = {}
local function corpus()
    if memo.done then return memo end
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    memo.frames = {}      -- one entry per live hero frame: list of enemy distances
    memo.fixtures = 0
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            memo.fixtures = memo.fixtures + 1
            local live = {}
            for _, u in ipairs(fx.units) do
                if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                    live[#live + 1] = u
                end
            end
            for _, a in ipairs(live) do
                local ds = {}
                for _, b in ipairs(live) do
                    if a.team ~= b.team then
                        ds[#ds + 1] = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
                    end
                end
                memo.frames[#memo.frames + 1] = ds
            end
        end
    end
    memo.done = true
    return memo
end

--- ONE counter, both legs. `nRing` is the radius the candidate set is drawn
--- with; returns (pairs total, pairs outside the ring, frames whose candidate
--- set is empty).
local function blindness(nRing)
    local C = corpus()
    local nPairs, nOut, nEmpty = 0, 0, 0
    for _, ds in ipairs(C.frames) do
        local seen = 0
        for _, d in ipairs(ds) do
            nPairs = nPairs + 1
            if d > nRing then nOut = nOut + 1 else seen = seen + 1 end
        end
        if #ds > 0 and seen == 0 then nEmpty = nEmpty + 1 end
    end
    return nPairs, nOut, nEmpty
end

tests['[domain] the corpus walk covered the corpus it thinks it did'] = function()
    local C = corpus()
    assert(C.fixtures >= 100, 'the fixture walk loaded only ' .. C.fixtures
        .. ' files -- a short walk makes every number below cheap')
    assert(#C.frames >= 1000, 'the walk found only ' .. #C.frames
        .. ' live hero frames')
end

tests['[domain] ⭐ 83% of live enemy pairs stand outside the shipped ring']
= function()
    local nPairs, nOut, nEmpty = blindness(1600)
    local pctOut = 100 * nOut / nPairs
    local pctEmpty = 100 * nEmpty / #corpus().frames
    assert(math.abs(pctOut - 83.3) < 2.0, string.format(
        'pairs beyond 1600u is now %.1f%% (%d/%d), not ~83.3%% -- re-price the '
        .. 'header of %s', pctOut, nOut, nPairs, SRC))
    assert(math.abs(pctEmpty - 50.1) < 2.0, string.format(
        'frames whose candidate set is EMPTY before a clause runs is now '
        .. '%.1f%% (%d), not ~50.1%% -- re-price the header of %s',
        pctEmpty, nEmpty, SRC))
end

tests['[domain] ⭐ the same counter, ring opened to the map, reports zero blind']
= function()
    local nPairs, nOut, nEmpty = blindness(math.huge)
    assert(nOut == 0, 'the counter that reported 4034 blind pairs at 1600u '
        .. 'reports ' .. nOut .. ' with no ring at all -- it is not measuring '
        .. 'the ring')
    assert(nEmpty == 0, 'the counter that reported 521 empty frames at 1600u '
        .. 'reports ' .. nEmpty .. ' with no ring at all')
    local nPairs2 = select(1, blindness(1600))
    assert(nPairs == nPairs2 and nPairs > 4000, 'the two legs walked different '
        .. 'corpora: ' .. nPairs .. ' vs ' .. nPairs2)
end

tests['[domain] and with the ring shut, every pair is blind'] = function()
    local nPairs, nOut, nEmpty = blindness(0)
    assert(nOut == nPairs, 'ring 0 leaves ' .. (nPairs - nOut)
        .. ' pairs inside; the comparator is not the thing being varied')
    assert(nEmpty == #corpus().frames, 'ring 0 leaves '
        .. (#corpus().frames - nEmpty) .. ' frames with a non-empty set')
end

return tests
