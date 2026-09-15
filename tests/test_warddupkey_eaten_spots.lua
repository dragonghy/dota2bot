-- [ratchet] [strategy 2026-09-15] Soak candidate 'warddupkey': the three
-- duplicate table keys in bots/, each of which silently deletes one ward spot.
--
-- THE DEFECT (shipped default, bots/FunLib/aba_ward_utility.lua)
-- -------------------------------------------------------------
-- Three spot groups write the same integer key twice:
--
--   WardLocationsBeforeAllyTowerFall__Dire[TOWER_MID_1]  [4] twice
--   WardLocationsBeforeAllyTowerFall__Dire[TOWER_TOP_3]  [4] twice
--   WardLocationsAfterEnemyTowerFall__Dire[TOWER_TOP_2]  [1] twice
--
-- Lua keeps the LAST assignment, so the first spot of each pair does not exist
-- at run time. The group is one shorter than it reads and nothing says so.
-- This file RE-RUNS the census instead of quoting it, because "there are
-- exactly three, and they are these three" is the whole reason to call this a
-- transcription slip rather than a convention. Neither automatic reader on the
-- push path can see it: a repeated key is valid Lua, so luacheck is silent, and
-- the file loads, so the smoke loader is too.
--
-- ⛔ A NOTE ON THE ATTRIBUTION, because it was wrong when this was filed. The
-- backlog entry that queued this work (strategy 0NEXT24) recorded the three as
-- `AfterEnemyTowerFall__Radiant[TOWER_MID_1]`, the same table's `[TOWER_TOP_3]`
-- and `AfterEnemyTowerFall__Dire[TOWER_TOP_2]`. Two of the three are in
-- `BeforeAllyTowerFall__Dire`, not `AfterEnemyTowerFall__Radiant`, and all
-- three are DIRE. That is not a clerical difference: `AfterEnemyTowerFall`
-- needs an enemy tower down, while `BeforeAllyTowerFall[TOWER_MID_1]` is read
-- while our OWN mid tier-1 still stands -- i.e. from minute zero of every dire
-- game. The domain was recorded an order of magnitude rarer than it is. The
-- `[source]` case below pins table AND side so the next reader cannot inherit
-- the same mistake from prose.
--
-- THE LEVER ('warddupkey', turbo-only). THREE SPOTS COME BACK. No spot is
-- moved, no spot is removed, no clause is relaxed, no coordinate is invented --
-- the armed values are the three literals already written in the file, read
-- with the keys they were meant to have.
--
-- WHAT THIS FILE CAN AND CANNOT BUY -- read before trusting a number below
-- ----------------------------------------------------------------------
-- The GEOMETRY half is real, all of it: every hero below is a real hero at its
-- real position off a real .dem frame, every J.GetPosition is the real one,
-- every distance is the real bot-to-spot distance, and both legs run the real
-- X.GetAvailabeObserverWardSpots through the real J.IsSoakCandidate reading the
-- real bots/Customize/soak_side.lua. No J.* function is stubbed in this file.
--
-- ⛔ THE ZERO IS STATED FIRST AND NOT EXPLAINED AWAY. Over the 126 dire
-- position->=4 frames in the corpus, armed grows the candidate list on 80 and
-- changes the ARGMIN -- the spot that actually gets planted on -- on ZERO.
-- `[domain]` asserts that zero rather than hiding it. What it is not is "a
-- distant also-ran": `[margin]` drives the nearest frame, where the restored
-- spot loses by 403u. That is the CORPUS-COVERAGE kind of zero (GH #838), not
-- the constructive kind (GH #838's other half): the host runs, the spot is
-- admitted, the corpus simply never samples a stance where it wins.
--
-- The DRAIN half is declared, and it is the only declared thing here. A spot is
-- filtered out for 360s after being planted on (`plant_time_obs`), so over a
-- game a group of 4 runs dry sooner than a group of 5 -- and when the last
-- unexpired spot is the one the duplicate key deleted, the shipped bot has no
-- spot for that tower at all. A single-frame corpus cannot show that by
-- construction, so `[drain]` DRIVES it: real frame, real filters, real
-- producers, with only the plant times declared.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local SRC = 'bots/FunLib/aba_ward_utility.lua'
local CAND = 'warddupkey'

-- The three swallowed points, and the survivor that swallowed each.
local EATEN = {
    mid1 = { x = -2400.793457, y =  1431.276611 },
    top3 = { x =   605.637573, y =  6996.875977 },
    top2 = { x = -5217.980957, y = -1648.555908 },
}
local SURVIVOR = {
    mid1 = { x =  1631.129028, y =  -604.961731 },
    top3 = { x =  2174.007812, y =  4253.548828 },
    top2 = { x = -4334.572266, y = -1036.464844 },
}

-- The bearing frame: the corpus frame on which a restored spot comes closest to
-- taking the plant. Lich, position 5, 951u from the restored MID_1 spot against
-- the shipped argmin's 548u.
local FIX  = 'f_260820_043524_wd_defend_alone.lua'
local SUBJ = 'npc_dota_hero_lich'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Structural facts are claims about CODE, and this lever ships with a long head
--- note that names all three tables, all three keys and the gate id. Reading the
--- raw source would let the COMMENT satisfy every assertion below.
local function strip_comments(s)
    s = s:gsub('%-%-%[%[.-%]%]', ' ')
    return (s:gsub('%-%-[^\n]*', ' '))
end

local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.01) end

local function is_at(loc, p)
    return loc ~= nil and near(loc[1], p.x) and near(loc[2], p.y)
end

--- Which restored point, if any, is this? nil for every other spot.
local function which_eaten(loc)
    for k, p in pairs(EATEN) do
        if is_at(loc, p) then return k end
    end
    return nil
end

--- Stand a real frame up and return the ward module. Nothing is declared here:
--- the tower state is whatever the frame's own building rows say.
local function stand(sFix, sSubj)
    local J, bot = rf.load('tests/fixtures/' .. sFix, sSubj)
    assert(bot ~= nil, sSubj .. ' is not in ' .. sFix)
    return J, bot, dofile(SRC)
end

--- Run `fn(J, bot, W)` on a freshly-loaded world, armed or provably unarmed.
--- The switch is written BEFORE the world is built, because J.IsSoakCandidate
--- reads the file through the module the fixture loader is about to create.
local function leg(sFix, sSubj, bArm, fn)
    if bArm then
        ss.arm(CAND, 'dire')
    else
        ss.assert_clean('the unarmed leg of ' .. sFix)
    end
    local ok, err = pcall(function()
        local J, bot, W = stand(sFix, sSubj)
        return fn(J, bot, W)
    end)
    if bArm then
        ss.finish(ok, err)
    elseif not ok then
        error(err, 0)
    end
    -- `finish` re-raises on failure, so reaching here means the body returned.
    -- Re-run is not needed: the body stores what it wants through upvalues.
end

--- Candidate list of `bot` as a plain array plus the two readings this file
--- cares about: how long it is, and which restored point (if any) is in it.
local function list_of(W, bot)
    local t = W.GetAvailabeObserverWardSpots(bot)
    local n, sEaten = 0, nil
    for _, s in pairs(t) do
        n = n + 1
        sEaten = which_eaten(s.location) or sEaten
    end
    return t, n, sEaten
end

ss.assert_clean('file load of test_warddupkey_eaten_spots.lua')

-- ==========================================================================
-- SOURCE. The duplicate keys are facts about the tree, and the tree is
-- re-scanned -- by the same census tool, not by a needle written here.
-- ==========================================================================

tests['[source] exactly three duplicate spot keys exist in bots/, and they are these three']
= function()
    local p = assert(io.popen(
        'python3 tools/agent/table_dup_key_census.py bots 2>&1'))
    local out = p:read('*a')
    p:close()

    -- The census prints one line per hit plus a trailing count line. Both are
    -- read: the count guards against a needle that silently matches nothing,
    -- the lines against a count that drifts from what it is counting.
    local nTotal = tonumber(out:match('duplicate_keys=(%d+)'))
    assert(nTotal ~= nil, 'the census produced no count line. Output was:\n' .. out)

    local nWard = 0
    for line in out:gmatch('[^\n]+') do
        if line:find('aba_ward_utility', 1, true) then nWard = nWard + 1 end
    end
    assert(nWard == 3, 'the ward file now holds ' .. nWard .. ' duplicate table '
        .. 'keys, not 3. If it grew, the new one needs the same treatment; if it '
        .. 'shrank the shipped default was changed UNGATED and this lever is '
        .. 'dead. Census output:\n' .. out)
    assert(nTotal == 7, 'bots/ now holds ' .. nTotal .. ' duplicate table keys, '
        .. 'not 7. The other four are FretBots sound tables (Soundboard LYRICAL '
        .. '/ WW13 / WW14 and VoiceoverHeroes npc_dota_hero_bloodseeker, which '
        .. 'is a real name-resolution bug filed separately, NOT bundled here). '
        .. '"Three, out of seven, in one file" is what makes this a slip rather '
        .. 'than a convention; if the denominator moved, re-read it before '
        .. 'trusting any number in this file. Census output:\n' .. out)
end

tests['[source] all three duplicates are DIRE tables, two of them BeforeAllyTowerFall']
= function()
    -- The filed attribution had these in AfterEnemyTowerFall__Radiant. Pin the
    -- enclosing table by walking the source, so prose cannot re-introduce it.
    local code = strip_comments(read_file(SRC))
    local sTbl, sTower = nil, nil
    local found = {}
    for line in code:gmatch('[^\n]+') do
        local t = line:match('local%s+(WardLocations[%w_]+)%s*=')
        if t then sTbl = t end
        local w = line:match('%[(TOWER_[%w_]+)%]%s*=%s*{')
        if w then sTower = w end
        -- `%w` excludes `_` in Lua patterns, so the class is spelled out; the
        -- names all contain underscores and a `%w+` needle would silently
        -- truncate every one of them to the same prefix.
        local var = line:match('location%s*=%s*(WARD_DUP_[%w_]+)')
        -- FIRST occurrence only: the resolver's tWardDupRestore holds the same
        -- three names further down the file, where `sTbl`/`sTower` no longer
        -- describe anything, and letting those win would make this case report
        -- whichever table happened to be declared last.
        if var and found[var] == nil then
            found[var] = (sTbl or '?') .. '|' .. (sTower or '?')
        end
    end

    assert(found.WARD_DUP_DIRE_MID1_EATEN
        == 'WardLocationsBeforeAllyTowerFall__Dire|TOWER_MID_1',
        'the MID_1 swallowed spot moved: ' .. tostring(found.WARD_DUP_DIRE_MID1_EATEN)
        .. '. Its table matters -- BeforeAllyTowerFall[TOWER_MID_1] is read while '
        .. 'our own mid tier-1 still STANDS, i.e. from minute zero, which is why '
        .. 'this lever has a live domain at all.')
    assert(found.WARD_DUP_DIRE_TOP3_EATEN
        == 'WardLocationsBeforeAllyTowerFall__Dire|TOWER_TOP_3',
        'the TOP_3 swallowed spot moved: ' .. tostring(found.WARD_DUP_DIRE_TOP3_EATEN))
    assert(found.WARD_DUP_DIRE_TOP2_EATEN
        == 'WardLocationsAfterEnemyTowerFall__Dire|TOWER_TOP_2',
        'the TOP_2 swallowed spot moved: ' .. tostring(found.WARD_DUP_DIRE_TOP2_EATEN))

    -- ...and none of them is radiant, which is the half the filing got wrong.
    for var, where in pairs(found) do
        assert(where:find('__Dire', 1, true) ~= nil, var .. ' is now in a RADIANT '
            .. 'table (' .. where .. '). This id is dire-only BY CONSTRUCTION, '
            .. 'and a mirrored A/B reader is told to expect a zero on the radiant '
            .. 'leg; if that stops being true the note must change with it.')
    end
end

tests['[source] the swallowed values are still swallowed by the shipped table']
= function()
    -- The whole lever assumes the shipped answer is the SECOND of each pair. If
    -- someone "tidied" the duplicate away, the shipped default changed ungated.
    ss.assert_clean('[source] shipped-table case')
    local probe = { mid1 = false, top3 = false, top2 = false }

    -- Read the groups through the module's own producers on a real frame rather
    -- than reaching into locals: the locals are not exported, and a copy would
    -- not be the table the readers use.
    local _, bot, W = stand(FIX, SUBJ)
    local t = W.GetAvailabeObserverWardSpots(bot)
    for _, s in pairs(t) do
        local k = which_eaten(s.location)
        if k then probe[k] = true end
    end
    assert(probe.mid1 == false and probe.top3 == false and probe.top2 == false,
        'a swallowed spot is in the SHIPPED candidate list. Either the duplicate '
        .. 'key was removed (the default changed ungated) or the gate leaked.')

    -- ...and the survivors are the ones that answer.
    local bSurv = false
    for _, s in pairs(t) do
        if is_at(s.location, SURVIVOR.mid1) then bSurv = true end
    end
    assert(bSurv, 'the MID_1 survivor spot ' .. SURVIVOR.mid1.x .. ',' ..
        SURVIVOR.mid1.y .. ' left the shipped list; this frame no longer '
        .. 'exercises the group the lever is about')
end

tests['[source] the gate is turbo-only, single-id, and names no other id']
= function()
    local code = strip_comments(read_file(SRC))
    local at = code:find('function X.ApplyWardDupKeyFix', 1, true)
    assert(at ~= nil, 'X.ApplyWardDupKeyFix is gone from ' .. SRC)
    local body = code:sub(at, (code:find('\nfunction ', at + 10) or #code))

    local nIds = 0
    for _ in body:gmatch('IsSoakCandidate') do nIds = nIds + 1 end
    assert(nIds == 1, 'the resolver now names ' .. nIds .. ' candidate ids. Two '
        .. "ids in one condition is the 'pullcad' trap: promoting either freezes "
        .. 'this gate FALSE forever (AGENTS.md).')
    assert(body:find("IsSoakCandidate('" .. CAND .. "')", 1, true), 'the id changed')

    local atTurbo = body:find('IsModeTurbo()', 1, true)
    local atGate = body:find("IsSoakCandidate('" .. CAND .. "')", 1, true)
    assert(atTurbo ~= nil and atTurbo < atGate,
        'J.IsModeTurbo() must stand BEFORE the candidate read, so a non-turbo '
        .. 'game never reaches the switch file at all')
end

tests['[source] the resolver is called by both producers and nobody else']
= function()
    local code = strip_comments(read_file(SRC))
    local nDefs, nAll = 0, 0
    for _ in code:gmatch('function%s+X%.ApplyWardDupKeyFix%(%)') do nDefs = nDefs + 1 end
    for _ in code:gmatch('X%.ApplyWardDupKeyFix%(%)') do nAll = nAll + 1 end
    assert(nDefs == 1, 'X.ApplyWardDupKeyFix is defined ' .. nDefs .. ' times')
    assert(nAll - nDefs == 2, 'X.ApplyWardDupKeyFix() is called ' .. (nAll - nDefs)
        .. ' times, not 2 (the observer producer and the sentry producer). A '
        .. 'third caller means a third path can see a different group.')
end

tests['[source] neither reader uses # on a spot group']
= function()
    -- The restored spot is appended at max-integer-key + 1, and one group in
    -- this file already has a hole (`AfterEnemyTowerFall__Dire[TOWER_MID_3]`
    -- has [1] and [3] but no [2], same family as GH #777). Both are safe only
    -- while every reader iterates with `pairs`. This asserts that rather than
    -- assuming it.
    --
    -- Eight, not four: each producer picks a table four ways (before/after
    -- tower fall x radiant/dire) and there are two producers. The count is
    -- asserted rather than the shape described, because "every reader uses
    -- pairs" is only worth anything if the readers were all counted.
    local code = strip_comments(read_file(SRC))
    local nOuter, nInner, nLen = 0, 0, 0
    for _ in code:gmatch('for%s+[%w_]+%s*,%s*spots%s+in%s+pairs%(') do nOuter = nOuter + 1 end
    for _ in code:gmatch('for%s+[%w_]+%s*,%s*spot%s+in%s+pairs%(%s*spots%s*%)') do nInner = nInner + 1 end
    for _ in code:gmatch('#%s*spots') do nLen = nLen + 1 end
    for _ in code:gmatch('#%s*WardLocations') do nLen = nLen + 1 end
    assert(nOuter == 8, 'the group selectors changed shape: ' .. nOuter
        .. ' `pairs(WardLocations...)` walks, expected 8 (4 table choices x 2 '
        .. 'producers)')
    -- Ten, and the split is named so a future drift can be attributed: eight
    -- are the group walks inside the two producers (the walks that see the
    -- appended key), two are list walks over an already-built candidate array
    -- (X.GetClosestObserverWardSpot's argmin and the sentry-side chooser).
    assert(nInner == 10, 'the spot readers changed shape: ' .. nInner
        .. ' `pairs(spots)` walks, expected 10 (8 group walks + 2 list walks). '
        .. 'One of them switching to an index loop is exactly the regression '
        .. 'this case exists for.')
    assert(nLen == 0, 'a reader now takes # of a spot group (' .. nLen
        .. ' places). `#` on a table with a hole is undefined in Lua 5.1, and '
        .. 'appending at max-key+1 stops being safe the moment one exists.')
end

-- ==========================================================================
-- DOMAIN. Real frames, each frame's own tower state, nothing declared.
-- ==========================================================================

tests['[domain] armed the list grows by exactly one on the bearing frame']
= function()
    local nBase, sBase
    ss.assert_clean('[domain] shipped leg')
    do
        local _, bot, W = stand(FIX, SUBJ)
        _, nBase, sBase = list_of(W, bot)
    end
    assert(sBase == nil, 'a restored spot is already in the SHIPPED list')

    local nArm, sArm
    leg(FIX, SUBJ, true, function(_, bot, W)
        local _, n, s = list_of(W, bot)
        nArm, sArm = n, s
    end)

    assert(sArm == 'mid1', 'armed, the restored spot in this frame\'s list should '
        .. 'be the MID_1 one, got ' .. tostring(sArm))
    assert(nArm == nBase + 1, string.format(
        'armed list is %d long, shipped is %d -- expected exactly one more. More '
        .. 'than one would mean a second group became reachable on this frame '
        .. 'and the reading below is about a different lever than it says.',
        nArm, nBase))
end

tests['[domain] ⛔ the argmin does NOT change on the bearing frame']
= function()
    -- The zero, driven rather than described. This is the case that would have
    -- to flip before anyone may call this lever a plant change.
    local bBase, bArm
    ss.assert_clean('[domain] argmin shipped leg')
    do
        local _, bot, W = stand(FIX, SUBJ)
        local t = W.GetAvailabeObserverWardSpots(bot)
        bBase = W.GetClosestObserverWardSpot(bot, t)
    end
    leg(FIX, SUBJ, true, function(_, bot, W)
        local t = W.GetAvailabeObserverWardSpots(bot)
        bArm = W.GetClosestObserverWardSpot(bot, t)
    end)

    assert(bBase ~= nil and bArm ~= nil, 'no spot was chosen on either leg')
    assert(which_eaten(bArm.location) == nil, 'the restored spot NOW takes the '
        .. 'plant on this frame. That is the reading `queue.json:strategy-49` '
        .. 'asked for -- update the head note in ' .. SRC .. ', which currently '
        .. 'says 0/126, before treating this as a pass.')
    assert(near(bBase.location[1], bArm.location[1])
        and near(bBase.location[2], bArm.location[2]),
        'armed picked a different spot than shipped, but not a restored one. '
        .. 'This lever only appends; it cannot move an existing spot, so this '
        .. 'means something else in the file changed.')
end

tests['[margin] the restored spot is a near miss, not a distant also-ran']
= function()
    -- 403u is the whole content of the zero above: it is the gap a reader has
    -- to weigh against "the corpus never sampled a stance where it wins".
    local dEaten, dBest
    leg(FIX, SUBJ, true, function(_, bot, W)
        local t = W.GetAvailabeObserverWardSpots(bot)
        local best = W.GetClosestObserverWardSpot(bot, t)
        dBest = GetUnitToLocationDistance(bot, best.location)
        for _, s in pairs(t) do
            if which_eaten(s.location) ~= nil then
                local d = GetUnitToLocationDistance(bot, s.location)
                if dEaten == nil or d < dEaten then dEaten = d end
            end
        end
    end)

    assert(dEaten ~= nil and dBest ~= nil, 'the bearing frame stopped producing '
        .. 'both distances')
    local gap = dEaten - dBest
    assert(gap > 0, 'the gap is now ' .. string.format('%.0f', gap)
        .. 'u, i.e. the restored spot is CLOSER -- the argmin case above should '
        .. 'have caught this first')
    assert(gap < 700, string.format('the nearest-miss gap grew to %.0fu (was '
        .. '403u: %.0fu vs %.0fu). The "near miss, not also-ran" reading in the '
        .. 'head note of %s is what this number backs; if it drifted this far '
        .. 'the note is now overstating the lever.', gap, dEaten, dBest, SRC))
end

-- ==========================================================================
-- DRAIN. The channel no single frame can show, driven with the plant times --
-- and ONLY the plant times -- declared.
-- ==========================================================================

tests['[drain] with the survivors on cooldown, shipped wards nowhere and armed still can']
= function()
    -- A spot is filtered out for 360s after it is planted on. This is the state
    -- a dire support reaches by doing its job: it warded the MID_1 group a
    -- minute ago and is asked again. With five spots one is still free; with
    -- four -- the shipped count -- the group is empty and the bot has no spot
    -- for that tower at all.
    local function drained(W, bot, nNow)
        -- Declare: every spot this frame offers for the MID_1 group was planted
        -- on 10s ago. Nothing else moves -- the geometry, the towers, the
        -- passability and the enemy sentries are all the frame's own.
        local t = W.GetAvailabeObserverWardSpots(bot)
        for _, s in pairs(t) do
            if which_eaten(s.location) == nil then
                s.plant_time_obs = nNow - 10
            end
        end
        return W.GetAvailabeObserverWardSpots(bot)
    end

    local nBaseLeft
    ss.assert_clean('[drain] shipped leg')
    do
        local _, bot, W = stand(FIX, SUBJ)
        local t2 = drained(W, bot, DotaTime())
        nBaseLeft = 0
        for _ in pairs(t2) do nBaseLeft = nBaseLeft + 1 end
    end

    local nArmLeft, bArmRestored = nil, false
    leg(FIX, SUBJ, true, function(_, bot, W)
        local t2 = drained(W, bot, DotaTime())
        nArmLeft = 0
        for _, s in pairs(t2) do
            nArmLeft = nArmLeft + 1
            if which_eaten(s.location) ~= nil then bArmRestored = true end
        end
    end)

    assert(nBaseLeft == 0, 'the shipped list still offers ' .. nBaseLeft
        .. ' spot(s) after every spot it offered was marked planted-on. The '
        .. 'declaration did not take, so this case is measuring nothing.')
    assert(nArmLeft == 1 and bArmRestored, 'armed offers ' .. tostring(nArmLeft)
        .. ' spot(s) (restored present: ' .. tostring(bArmRestored) .. '); '
        .. 'expected exactly the one restored spot. This is the whole cost of '
        .. 'being one spot short: the shipped bot wards nowhere here.')
end

-- ==========================================================================
-- GATE. Un-armed must be the shipped tree, identity and all.
-- ==========================================================================

tests['[gate] un-armed the groups are the shipped tables, by identity']
= function()
    ss.assert_clean('[gate] unarmed case')
    local _, bot, W = stand(FIX, SUBJ)
    local t1 = W.GetAvailabeObserverWardSpots(bot)
    -- Call the resolver directly, twice, on an unarmed switch: it must be a
    -- no-op, and calling it must not perturb the next producer call either.
    W.ApplyWardDupKeyFix()
    W.ApplyWardDupKeyFix()
    local t2 = W.GetAvailabeObserverWardSpots(bot)

    local n1, n2 = 0, 0
    for _, s in pairs(t1) do n1 = n1 + 1; assert(which_eaten(s.location) == nil) end
    for _, s in pairs(t2) do n2 = n2 + 1; assert(which_eaten(s.location) == nil) end
    assert(n1 == n2, 'the unarmed list changed length across resolver calls: '
        .. n1 .. ' then ' .. n2)
end

tests['[gate] armed twice appends once -- the resolver is idempotent']
= function()
    local n1, n2
    leg(FIX, SUBJ, true, function(_, bot, W)
        local _, a = list_of(W, bot)
        W.ApplyWardDupKeyFix()
        W.ApplyWardDupKeyFix()
        local _, b = list_of(W, bot)
        n1, n2 = a, b
    end)
    assert(n1 == n2, 'the armed list grew from ' .. n1 .. ' to ' .. n2
        .. ' across extra resolver calls. The producers call the resolver on '
        .. 'EVERY tick, so a non-idempotent append grows the group without '
        .. 'bound for the whole game.')
end

tests['[gate] the id is registered as gated-and-unpromoted']
= function()
    local s = read_file('iterations/state.json')
    assert(s:find(CAND, 1, true), CAND .. ' is not in '
        .. 'iterations/state.json. An id nobody can look up is an id nobody can '
        .. 'arm, and the wave that was supposed to price it reads back as '
        .. '"tested, no effect".')
end

return tests
