-- [ratchet] [strategy 2026-09-16] Soak candidate 'pushtier': the push-lane
-- selector says "prefer lanes with lower-tier outer buildings first" and spells
-- it as a STRICTLY UNIQUE minimum, so the normal state of the map runs no
-- branch at all.
--
-- THE DEFECT (bots/FunLib/aba_push.lua, WhichLaneToPush, shipped default)
-- ----------------------------------------------------------------------
-- Three lanes, each scored by how far the team stands from its front, then
-- adjusted for enemies seen, objective tier, and allies present.  The objective
-- term is this chain, transcribed from typescript/bots/FunLib/aba_push.ts whose
-- comment above it reads "Prefer lanes with lower-tier outer buildings first":
--
--     if midTier < topTier and midTier < botTier then        midLaneScore = ...
--     elseif topTier < midTier and topTier < botTier then    topLaneScore = ...
--     elseif botTier < topTier and botTier < midTier then    botLaneScore = ...
--     end
--
-- Every branch demands its lane beat BOTH others strictly.  GetLaneBuildingTier
-- (same file) returns an integer in {1,2,3,4}; three lanes drawn from four
-- values tie at the minimum constantly, and the moment two lanes tie there,
-- NO branch runs -- the objective term silently drops out of the lane choice
-- and the decision is made by ally distance alone.  Nothing reports this: the
-- code has no else, the variables are all live, and luacheck sees a perfectly
-- ordinary chain.
--
-- This is the same family as GH #851 (four `or`s that cannot refuse a mode) and
-- GH #837 (an existential quantifier that only reads the first three slots) --
-- a guard whose clauses are individually correct and whose domain is empty or
-- near-empty by construction.  What makes this one worth a lever rather than a
-- filing is that the empty half is not empty: 165 of the 690 drivable frames
-- below are two-way ties, and on 25 of them the lane actually chosen moves.
--
-- THE FIX (one lever): give the multiplier to EVERY lane that attains the
-- minimum tier.  Nothing else moves -- not the 0.5, not the barracks
-- sub-clause, and NOT the direction of the preference (lower tier = the enemy
-- still has his outer tower there = the cheaper objective; that is the shipped
-- intent and is not this lever's question).  The shipped chain is kept
-- byte-identical as the else-arm.
--
-- WHY A THREE-WAY TIE IS A NO-OP, AND WHY THAT IS ARITHMETIC RATHER THAN HOPE.
-- The selector below the chain compares the three scores against each other and
-- nothing else.  Multiplying all three by the same positive constant cannot
-- change an ordering, so a frame where all three lanes sit at the minimum tier
-- reads identically armed and unarmed.  (The barracks sub-clause can break the
-- uniformity, but only at tier >= 3, where a tied lane may have lost its rax
-- while another has not.)  [control] below drives that claim rather than
-- resting on it, and the sweep confirms it over all 465 such pairs.
--
-- WHAT IS REAL HERE AND WHAT IS DECLARED -- read before quoting a number
-- ---------------------------------------------------------------------
-- REAL, off the .dem frames: every hero position, every hero's team, and every
-- standing tower and barracks of both teams (tests/mock/replay_fixture.lua
-- resolves building slots positionally out of the dump).  The tier vector and
-- the lane choice are computed from those.
-- DECLARED, once, and named at the call: GetLaneFrontLocation is unresolved in
-- this corpus -- the dump carries no lane fronts and the loader REFUSES the
-- call rather than answering (0,0,0) (GH #61).  Each lane front is declared to
-- be the ENEMY'S FRONTMOST STANDING TOWER on that lane, a real coordinate off
-- the same real frame, moving with the same building state the tier ladder
-- reads.  A frame that cannot supply all three is SKIPPED, never guessed at.
--
-- The full 1,380-drive sweep is tests/_pushtier_sweep.lua (~30s, ten times the
-- Lua push gate's per-test cap, which is why it is not a test_ file).  This
-- file re-derives the cheap half of its census live and drives six named pairs.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

local SRC    = 'bots/FunLib/aba_push.lua'
local SRC_TS = 'typescript/bots/FunLib/aba_push.ts'
local CAND   = 'pushtier'

-- The bearing pair: lina, radiant, on a frame whose DIRE buildings read
-- top 1 / mid 2 / bot 1.  Mid's outer tower is already down, so mid is the
-- EXPENSIVE objective -- and the shipped chain, finding no unique minimum,
-- pushes mid anyway.
local BEAR_FIX  = 'tests/fixtures/f_260820_103644_necro_pinned_dying.lua'
local BEAR_SUBJ = 'npc_dota_hero_lina'

-- Controls, all three from the same fixture so a corpus edit cannot quietly
-- remove one class without the others noticing.
local CTL_FIX      = 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua'
local CTL_UNIQUE   = 'npc_dota_hero_crystal_maiden'   -- tiers 1,2,2, min unique
local CTL_TIE3     = 'npc_dota_hero_lion'             -- tiers 1,1,1
-- A two-way tie that does NOT move: being in the domain is not sufficiency.
local CTL_TIE2_FIX  = 'tests/fixtures/f_20260828_004757_venomancer_785.lua'
local CTL_TIE2_SUBJ = 'npc_dota_hero_axe'             -- tiers 1,1,2

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

-- ⛔ REBUILT PER FRAME, NEVER CACHED.  replay_fixture resolves tower/barracks
-- slots positionally out of the frame, so TOWER_TOP_1 and friends are NOT
-- constants across loads (0..8 on a frame with towers, unresolved sentinels
-- 1036.. on a frame with none).  A cached table asks a later frame for slots it
-- does not have and every lane comes back empty -- which reads as "this corpus
-- carries no buildings", a plausible statement about the CORPUS produced by a
-- defect in the READER.  Measured while writing this file: the cached version
-- reported 1120 of 1120 pairs unreadable.
local function lane_tables()
    return {
        [LANE_TOP] = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 },
        [LANE_MID] = { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 },
        [LANE_BOT] = { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 },
    }, {
        [LANE_TOP] = { BARRACKS_TOP_MELEE, BARRACKS_TOP_RANGED },
        [LANE_MID] = { BARRACKS_MID_MELEE, BARRACKS_MID_RANGED },
        [LANE_BOT] = { BARRACKS_BOT_MELEE, BARRACKS_BOT_RANGED },
    }
end

--- The enemy's frontmost standing tower per lane, and the tier vector, both
--- read off the live frame.  The ladder is re-derived here rather than calling
--- GetLaneBuildingTier, so this reader does not inherit the function under test.
local function fronts_and_tiers(enemy)
    local slots, rax = lane_tables()
    local fronts, tiers = {}, {}
    for lane, list in pairs(slots) do
        local tier = 4
        for i, s in ipairs(list) do
            local t = GetTower(enemy, s)
            if t ~= nil then
                if fronts[lane] == nil then fronts[lane] = t:GetLocation() end
                if tier == 4 then tier = i end
            end
        end
        if tier == 4 then
            for _, b in ipairs(rax[lane]) do
                if GetBarracks(enemy, b) ~= nil then tier = 3 end
            end
        end
        tiers[lane] = tier
    end
    return fronts, tiers
end

local function readable(fronts)
    return fronts[LANE_TOP] ~= nil and fronts[LANE_MID] ~= nil
        and fronts[LANE_BOT] ~= nil
end

--- Stand one (fixture, hero) pair up and drive the real WhichLaneToPush.
local function decide(sFix, sSubj)
    local _, bot = rf.load(sFix, sSubj)
    assert(bot ~= nil, sFix .. ' no longer carries ' .. sSubj)
    local fronts, tiers = fronts_and_tiers(GetOpposingTeam())
    assert(readable(fronts), sFix .. '/' .. sSubj .. ' no longer carries a '
        .. 'standing enemy tower on every lane, so the declared lane fronts '
        .. 'cannot be taken off the frame any more')
    _G.GetLaneFrontLocation = function(_, lane) return fronts[lane] end  -- luacheck: ignore
    local Push = dofile(SRC)
    return Push.WhichLaneToPush(bot, LANE_MID), tiers
end

local function tiers_of(sFix, sSubj)
    local _, tiers = decide(sFix, sSubj)
    return tiers
end

local function side_of(sFix, sSubj)
    local _, bot = rf.load(sFix, sSubj)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

local function armed_decide(sFix, sSubj, sCand, sSide)
    local lane
    ss.with_candidate(sCand or CAND, function()
        lane = decide(sFix, sSubj)
    end, sSide or side_of(sFix, sSubj))
    return lane
end

local function min_count(tiers)
    local nMin = math.min(tiers[LANE_TOP], tiers[LANE_MID], tiers[LANE_BOT])
    local n = 0
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        if tiers[lane] == nMin then n = n + 1 end
    end
    return n, nMin
end

-- ==========================================================================
-- [world] The frames are asserted, never described.
-- ==========================================================================

tests['[world] the bearing frame really is a two-way tie at the minimum tier']
= function()
    local tiers = tiers_of(BEAR_FIX, BEAR_SUBJ)
    assert(tiers[LANE_TOP] == 1 and tiers[LANE_MID] == 2 and tiers[LANE_BOT] == 1,
        string.format('the frame moved: the enemy tier vector used to be '
            .. '1,2,1 and is now %d,%d,%d',
            tiers[LANE_TOP], tiers[LANE_MID], tiers[LANE_BOT]))
    local n = min_count(tiers)
    assert(n == 2, 'the bearing frame is no longer a two-way tie (' .. n .. ')')
end

tests['[world] the declared lane fronts are three distinct real tower spots']
= function()
    rf.load(BEAR_FIX, BEAR_SUBJ)
    local fronts = fronts_and_tiers(GetOpposingTeam())
    assert(readable(fronts), 'the bearing frame lost a standing enemy tower')
    local seen = {}
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        local v = fronts[lane]
        local key = string.format('%.0f/%.0f', v.x, v.y)
        assert(not seen[key], 'two lanes resolved to the SAME tower ('
            .. key .. '), so the declared fronts are not lane-specific and '
            .. 'the three lane scores stop being three measurements')
        seen[key] = true
        assert(math.abs(v.x) > 1 or math.abs(v.y) > 1,
            'a lane front resolved to the origin -- that is the (0,0,0) the '
            .. 'loader refuses to hand out (GH #61), arriving by another door')
    end
end

tests['[world] the controls really are the three classes they are named for']
= function()
    local n1 = min_count(tiers_of(CTL_FIX, CTL_UNIQUE))
    assert(n1 == 1, CTL_UNIQUE .. ' is no longer the unique-minimum control ('
        .. n1 .. ')')
    local n3 = min_count(tiers_of(CTL_FIX, CTL_TIE3))
    assert(n3 == 3, CTL_TIE3 .. ' is no longer the three-way-tie control ('
        .. n3 .. ')')
    local n2 = min_count(tiers_of(CTL_TIE2_FIX, CTL_TIE2_SUBJ))
    assert(n2 == 2, CTL_TIE2_SUBJ .. ' is no longer a two-way tie (' .. n2 .. ')')
end

-- ==========================================================================
-- [fix] The lever, driven.
-- ==========================================================================

tests['[fix] ⭐ unarmed, the shipped chain fires on NO lane of the bearing frame']
= function()
    local t = tiers_of(BEAR_FIX, BEAR_SUBJ)
    local top, mid, bot = t[LANE_TOP], t[LANE_MID], t[LANE_BOT]
    assert(not (mid < top and mid < bot), 'the mid branch now fires')
    assert(not (top < mid and top < bot), 'the top branch now fires')
    assert(not (bot < top and bot < mid), 'the bot branch now fires')
end

tests['[fix] ⭐⭐ unarmed pushes the EXPENSIVE lane; armed pushes a minimum-tier one']
= function()
    local unarmed, tiers = decide(BEAR_FIX, BEAR_SUBJ)
    assert(unarmed == LANE_MID, 'the shipped selector no longer picks mid on '
        .. 'the bearing frame (' .. tostring(unarmed) .. '); this case exists '
        .. 'because mid is the one lane whose outer tower is already gone')
    local _, nMin = min_count(tiers)
    assert(tiers[unarmed] > nMin, 'the shipped pick is already a minimum-tier '
        .. 'lane, so this frame no longer shows the defect')

    local armed = armed_decide(BEAR_FIX, BEAR_SUBJ)
    assert(armed ~= unarmed, 'armed did not move the decision ('
        .. tostring(armed) .. ')')
    assert(tiers[armed] == nMin, 'armed moved the pick to a lane that is NOT '
        .. 'at the minimum tier (' .. tostring(armed) .. ', tier '
        .. tostring(tiers[armed]) .. ' vs min ' .. tostring(nMin) .. ') -- the '
        .. 'lever is supposed to prefer the cheapest objective, not merely to '
        .. 'change the answer')
end

-- ==========================================================================
-- [control] Where the lever must NOT move anything.
-- ==========================================================================

tests['[control] unique minimum: armed agrees with the shipped chain']
= function()
    local unarmed = decide(CTL_FIX, CTL_UNIQUE)
    local armed = armed_decide(CTL_FIX, CTL_UNIQUE)
    assert(armed == unarmed, 'armed moved a decision the shipped chain already '
        .. 'made: ' .. tostring(unarmed) .. ' -> ' .. tostring(armed))
end

tests['[control] three-way tie: a common factor cannot reorder the comparison']
= function()
    local unarmed = decide(CTL_FIX, CTL_TIE3)
    local armed = armed_decide(CTL_FIX, CTL_TIE3)
    assert(armed == unarmed, 'all three lanes sit at the minimum tier, so armed '
        .. 'halves all three scores and the selector compares them against each '
        .. 'other only -- this must be a no-op, and it moved '
        .. tostring(unarmed) .. ' -> ' .. tostring(armed))
end

tests['[control] a two-way tie whose decision does NOT move']
= function()
    local unarmed = decide(CTL_TIE2_FIX, CTL_TIE2_SUBJ)
    local armed = armed_decide(CTL_TIE2_FIX, CTL_TIE2_SUBJ)
    assert(armed == unarmed, 'this case pins that being inside the lever\'s '
        .. 'domain is not sufficient for the answer to change; it moved '
        .. tostring(unarmed) .. ' -> ' .. tostring(armed) .. ', which makes '
        .. 'the 25-of-165 reading in tests/_pushtier_sweep.lua stale')
end

-- ==========================================================================
-- [gate] Both directions.  An unarmed reading is what most of this file
-- expects, so the two ways of getting one by accident are named.
-- ==========================================================================

tests['[gate] with no switch on disk the bearing frame decides as shipped']
= function()
    local fh = io.open(ss.PATH)
    if fh then fh:close() end
    assert(fh == nil, 'a soak_side switch this process does not own is on '
        .. 'disk; this case cannot tell an unarmed gate from someone else\'s '
        .. 'armed one')
    assert(decide(BEAR_FIX, BEAR_SUBJ) == LANE_MID,
        'no switch on disk and the decision already moved')
end

tests['[gate] armed on the OTHER side, the bearing frame decides as shipped']
= function()
    local sOther = side_of(BEAR_FIX, BEAR_SUBJ) == 'radiant' and 'dire' or 'radiant'
    local lane = armed_decide(BEAR_FIX, BEAR_SUBJ, CAND, sOther)
    assert(lane == LANE_MID, 'the gate fired for a bot on the other side: '
        .. tostring(lane))
end

tests['[gate] armed under another id, the bearing frame decides as shipped']
= function()
    local lane = armed_decide(BEAR_FIX, BEAR_SUBJ, 'campfarm')
    assert(lane == LANE_MID, 'the gate fired under a different candidate id: '
        .. tostring(lane))
end

-- ==========================================================================
-- [source] What the lever deliberately did NOT touch.  GH #834 §5 bought this
-- the hard way: when a lever only changes where a value comes from, no
-- behavioural case can see a "simplification" that drops a retained clause,
-- because the retained clause is the same in both arms.  So the retained text
-- is pinned verbatim.
-- ==========================================================================

local function chain()
    local src = strip_comments(read(SRC))
    local body = src:match('local botTier = ____exports%.GetLaneBuildingTier%b()(.-)\n    topLaneScore = presence_adjust')
    assert(body, 'the tier block is no longer where this file looks for it in ' .. SRC)
    return body
end

tests['[source] the shipped chain still demands a STRICTLY unique minimum']
= function()
    local body = chain()
    for _, pair in ipairs({
        { 'midTier < topTier and midTier < botTier', 'mid' },
        { 'topTier < midTier and topTier < botTier', 'top' },
        { 'botTier < topTier and botTier < midTier', 'bot' },
    }) do
        assert(body:find(pair[1], 1, true), 'the shipped ' .. pair[2]
            .. ' branch changed. It is kept byte-identical on purpose: a '
            .. 'disarmed bot must walk the same branches in the same order, '
            .. 'and every reading banked against the shipped default depends '
            .. 'on that.')
    end
end

tests['[source] the armed arm reuses the same 0.5 and the same barracks clause']
= function()
    local body = chain()
    local nHalf = select(2, body:gsub('%* 0%.5', ''))
    assert(nHalf == 12, 'the tier block no longer carries six halvings per arm '
        .. '(' .. nHalf .. ' in total). The armed arm is supposed to be the '
        .. 'shipped arm with the uniqueness requirement removed -- a different '
        .. 'constant would be a second lever.')
    local nRax = select(2, body:gsub('IsAnyBarracksOnLaneAlive', ''))
    assert(nRax == 6, 'the barracks sub-clause count moved (' .. nRax .. ')')
end

tests['[source] the gate is turbo-only and named once, not conjoined']
= function()
    local body = chain()
    assert(body:find("jmz.IsModeTurbo() and jmz.IsSoakCandidate('" .. CAND .. "')", 1, true),
        'the gate line changed shape. A gate written as a conjunction of two '
        .. 'soak ids is the pullcad trap: it freezes FALSE the day the other '
        .. 'id is promoted, and check_armed_wiring.py still calls it WIRED.')
    local nCand = select(2, body:gsub('IsSoakCandidate', ''))
    assert(nCand == 1, 'the tier block now resolves ' .. nCand .. ' soak '
        .. 'candidates; it must resolve exactly one')
end

tests['[source] the TypeScript source carries the same lever']
= function()
    local ts = read(SRC_TS)
    assert(ts:find('jmz.IsSoakCandidate("' .. CAND .. '")', 1, true),
        SRC_TS .. ' does not carry the gate. bots/FunLib/aba_push.lua is '
        .. 'transpiler output; a Lua-only edit is reverted by the next '
        .. 'regeneration, silently.')
    assert(ts:find('Math.min(topTier, midTier, botTier)', 1, true),
        SRC_TS .. ' no longer computes the minimum tier')
end

-- ==========================================================================
-- [domain] The census, re-derived live.  This is the cheap half of
-- tests/_pushtier_sweep.lua: it classifies every (fixture, hero) pair by its
-- enemy tier vector without driving WhichLaneToPush, which is what keeps it at
-- ~2s instead of ~30s.  The move counts (0 / 25 / 0) live in the sweep.
-- ==========================================================================

tests['[domain] the shipped chain is dead on 630 of 690 drivable pairs']
= function()
    local pipe = io.popen('ls tests/fixtures/*.lua')
    local files = {}
    for line in pipe:lines() do files[#files + 1] = line end
    pipe:close()
    assert(#files > 100, 'the fixture corpus shrank to ' .. #files .. ' files')

    local cls = { unique = 0, tie2 = 0, tie3 = 0 }
    local nTotal, nSkipped = 0, 0
    for _, sFix in ipairs(files) do
        local _, _, heroes = rf.load(sFix)
        local perTeam = {}
        if heroes then
            for _, h in pairs(heroes) do
                local t = h:GetTeam()
                perTeam[t] = (perTeam[t] or 0) + 1
            end
        end
        for team, n in pairs(perTeam) do
            local enemy = (team == TEAM_RADIANT) and TEAM_DIRE or TEAM_RADIANT
            local fronts, tiers = fronts_and_tiers(enemy)
            nTotal = nTotal + n
            if not readable(fronts) then
                nSkipped = nSkipped + n
            else
                local c = min_count(tiers)
                local k = c == 1 and 'unique' or (c == 2 and 'tie2' or 'tie3')
                cls[k] = cls[k] + n
            end
        end
    end

    -- The arithmetic first: a census that does not close is not a census.
    assert(cls.unique + cls.tie2 + cls.tie3 + nSkipped == nTotal,
        'the classes do not sum to the corpus')
    assert(nTotal == 1120, 'pairs moved: 1120 -> ' .. nTotal)
    -- The 430 skipped pairs are an INSTRUMENT gap, not a game state: they are
    -- the fixtures whose dump carries no buildings at all.  They are reported
    -- separately rather than folded into any class, because a frame where the
    -- reader cannot see a tower is not a frame where the tower is gone.
    assert(nSkipped == 430, 'unreadable pairs moved: 430 -> ' .. nSkipped)
    assert(cls.unique == 60, 'unique-minimum pairs moved: 60 -> ' .. cls.unique)
    assert(cls.tie2 == 165, 'two-way-tie pairs moved: 165 -> ' .. cls.tie2)
    assert(cls.tie3 == 465, 'three-way-tie pairs moved: 465 -> ' .. cls.tie3)
    -- The headline, stated as the arithmetic that produces it rather than as a
    -- number copied out of a report.
    assert(cls.tie2 + cls.tie3 == 630 and cls.unique + cls.tie2 + cls.tie3 == 690,
        'the dead/live split moved')
end

return tests
