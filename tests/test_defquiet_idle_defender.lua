-- [defquiet] The enemy count that ShouldDefend exists to take has no branch
-- for zero, so half of every "defend this" it hands out is for a building
-- nobody is attacking.
--
-- aba_defend.ShouldDefend(bot, hBuilding, nRadius) counts the enemies near a
-- building -- `nNearby` = recently-seen enemy heroes inside 1600 plus the floor
-- of a weighted creep sum inside nRadius -- and runs a role ladder over that
-- count. The ladder has branches for nNearby == 1, == 2, == 3 and >= 4, and
-- NO branch for nNearby == 0. Everything it declines falls into the escalation
-- block below it, whose last clause is
--
--     if not result and pos == GetClosestAllyPos({2, 3}, building) then
--         result = true
--
-- -- a clause with no threat precondition at all. So on a building with
-- nothing near it, the closest of {2, 3} is still named its defender, every
-- frame, for the whole game. In GetDefendDesireHelper that answer is not
-- cosmetic: `shouldDef` skips the bail-out to VeryLow, adds +0.1 to the desire
-- cap (capBoost) and lifts the desire floor from VeryLow to Low (baseFloor).
--
-- DOMAIN (measured, not guessed -- tests/_defquiet_sweep.lua, 1120
-- (fixture, hero) pairs x 3 lanes = 3360 triples driven, 0 skipped):
--   shipped answers TRUE 385 times (11.5% of triples)
--   armed   answers TRUE 193 times (5.7%)
--   MOVED 192, and all 192 have zero enemy heroes within 1600 of the building
--   (the count re-derived independently from J.GetLastSeenEnemiesNearLoc, not
--   read back out of the function under measurement)
-- ⇒ 192 of 385 = 49.9% of every defend designation in this corpus is on a
-- quiet building. The 193 that armed keeps and the 193 shipped-TRUE answers
-- that have at least one enemy near them are the same count: the split is
-- exactly "is anybody actually there".
-- By drafted role the 192 fall 182 on role 3 and 10 on role 2, which is the
-- shipped GetClosestAllyPos({2,3}) scan showing through -- see [defclose]:
-- only role 3 can win that scan, role 2 is the fallback when no role 3 is
-- alive. This candidate does NOT touch that scan.
--
-- REAL FRAME: f_20260827_091703_slot12_zuus_473_1 at t=473.1, turbo, Dire.
-- Subject necrolyte, drafted role 3, full health, standing 294u from its own
-- bot tier-2 tower -- the one tower on the map with an enemy inside 1600 of it.
-- Shipped tells it to defend all three lanes, including a tier-1 tower 12,684
-- units away with nobody near it.
--
-- CONTROL, on the SAME frame rather than a separate one: the bot lane. It has
-- one enemy inside 1600, so nNearby >= 1, and armed must answer TRUE there
-- byte for byte as shipped does. That is what makes this a precondition and
-- not a knob: armed can only ever REMOVE a defender, never add one, and it
-- removes none from the lane that is actually under threat. Note the bot-lane
-- answer comes from the SAME fallback clause (role 3 is not in the nNearby==1
-- ladder), so the control is testing the clause, not a different path.
--
-- NOT TOUCHED, deliberately, and registered rather than fixed: the
-- travel-boots/tinker escalation immediately above the clause has the same
-- missing precondition AND writes `travel_boots_defender` state on a quiet
-- frame. One lever at a time.
--
-- ONE DECLARED STAND-IN: GetLaneFrontLocation is unresolved in this corpus and
-- tests/mock/replay_fixture.lua REFUSES the call rather than answering (0,0,0)
-- (GH #61). ShouldDefend never reads a lane front -- it reads the building it
-- is handed -- so the declaration below only keeps aba_defend's module state
-- constructible, and no assertion in this file depends on its value.
--
-- [ratchet]

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FRAME = 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua'
local SUBJECT = 'npc_dota_hero_necrolyte'

local DEFEND_LUA = 'bots/FunLib/aba_defend.lua'
local DEFEND_TS = 'typescript/bots/FunLib/aba_defend.ts'

--- Load the real frame with the real aba_defend on top of it.
---   opts.armed -- arm 'defquiet' (nothing else is ever armed)
---   opts.turbo -- false makes J.IsModeTurbo() report a non-turbo game
local function world(opts)
    opts = opts or {}
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    rf = require('mock.replay_fixture')
    local J, bot, heroes, fx = rf.load(FRAME, SUBJECT)
    J.IsSoakCandidate = function(id)
        return id == (opts.id or 'defquiet') and opts.armed == true
    end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end
    -- GH #61, declared above. Nothing below reads it.
    _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, heroes, fx, Defend
end

--- The furthest standing building on each lane, keyed by the lane constant.
--- Rebuilt per frame on purpose: LANE_* do not exist until the mock has run.
local function lanes()
    return { LANE_TOP, LANE_MID, LANE_BOT },
           { [LANE_TOP] = 'top', [LANE_MID] = 'mid', [LANE_BOT] = 'bot' }
end

local function answers(Defend, J, bot)
    local out, near = {}, {}
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        local bld = Defend.GetFurthestBuildingOnLane(lane)[1]
        out[lane] = Defend.ShouldDefend(bot, bld, 1600) and true or false
        near[lane] = #J.GetLastSeenEnemiesNearLoc(bld:GetLocation(), 1600)
    end
    return out, near
end

local function slurp(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- ---------------------------------------------------------------------------
-- [frame] Every premise the defect rests on is asserted off the frame, not
-- assumed from the prose above.
-- ---------------------------------------------------------------------------

tests['[frame] the subject is a full-hp role 3 in a turbo game'] = function()
    local J, bot, _, fx = world()
    assert(J.IsModeTurbo(), 'the dump is turbo -- a turbo-only gate needs that')
    assert(math.abs(fx.time - 473.1) < 1e-6,
        'frame is t=473.1; got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == SUBJECT, 'subject is the necrolyte')
    assert(fx.roles ~= nil,
        'the fixture must carry DRAFTED roles -- without them GetPosition '
        .. 'falls back to the draft slot, which GH #57 measured at 47.3% accurate')
    assert(J.GetPosition(bot) == 3,
        'subject was drafted role 3; got ' .. tostring(J.GetPosition(bot)))
    assert(bot:GetHealth() == bot:GetMaxHealth(),
        'subject is at FULL health -- nothing here is about being hurt')
end

tests['[frame] exactly one of the three lanes has an enemy near its building'] = function()
    local J, bot, _, _, Defend = world()
    local _, near = answers(Defend, J, bot)
    local LANES, NAME = lanes()
    assert(near[LANE_TOP] == 0, 'top building is quiet; got ' .. near[LANE_TOP])
    assert(near[LANE_MID] == 0, 'mid building is quiet; got ' .. near[LANE_MID])
    assert(near[LANE_BOT] == 1,
        'bot building has exactly one enemy inside 1600; got ' .. near[LANE_BOT])
    -- and the subject is standing on the one that is threatened
    local bot_bld = Defend.GetFurthestBuildingOnLane(LANE_BOT)[1]
    local top_bld = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    assert(GetUnitToUnitDistance(bot, bot_bld) < 400,
        'subject is at the threatened tower (<400u)')
    assert(GetUnitToUnitDistance(bot, top_bld) > 12000,
        'and 12k+ units from the quiet top tower it is also told to defend')
    assert(#LANES == 3 and NAME[LANE_TOP] == 'top', 'lane tables built per frame')
end

-- ---------------------------------------------------------------------------
-- [fix] What shipped answers, and what armed changes -- including what it must
-- NOT change.
-- ---------------------------------------------------------------------------

tests['[fix] shipped names this hero the defender of all three lanes'] = function()
    local J, bot, _, _, Defend = world()
    local a = answers(Defend, J, bot)
    assert(a[LANE_TOP] == true,
        'SHIPPED: the 12,684u-away tower with nobody near it is "defend this"')
    assert(a[LANE_MID] == true, 'SHIPPED: the quiet mid tower too')
    assert(a[LANE_BOT] == true, 'SHIPPED: and the one that is genuinely threatened')
end

tests['[fix] armed drops the two quiet lanes and KEEPS the threatened one'] = function()
    local J, bot, _, _, Defend = world({ armed = true })
    local a, near = answers(Defend, J, bot)
    assert(a[LANE_TOP] == false, 'ARMED: no defender for a building nobody is at')
    assert(a[LANE_MID] == false, 'ARMED: same for mid')
    assert(a[LANE_BOT] == true,
        'ARMED CONTROL: the lane with an enemy inside 1600 is untouched -- this '
        .. 'is a precondition, not a knob')
    assert(near[LANE_BOT] >= 1,
        'and the reason it is kept is the threat itself, asserted not assumed')
end

tests['[fix] armed can only REMOVE a defender, never add one'] = function()
    local J, bot, _, _, Defend = world()
    local shipped = answers(Defend, J, bot)
    local J2, bot2, _, _, Defend2 = world({ armed = true })
    local armed = answers(Defend2, J2, bot2)
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        assert(not (armed[lane] and not shipped[lane]),
            'armed answered TRUE where shipped answered FALSE on lane '
            .. tostring(lane) .. ' -- the gate is supposed to be one-directional')
    end
end

-- ---------------------------------------------------------------------------
-- [gate] The gate itself: unarmed and non-turbo are byte-for-byte shipped.
-- ---------------------------------------------------------------------------

tests['[gate] unarmed is shipped behaviour'] = function()
    local J, bot, _, _, Defend = world({ armed = false })
    local a = answers(Defend, J, bot)
    assert(a[LANE_TOP] and a[LANE_MID] and a[LANE_BOT],
        'with the id unarmed every lane must answer exactly as shipped does')
end

tests['[gate] armed but NOT turbo is shipped behaviour'] = function()
    local J, bot, _, _, Defend = world({ armed = true, turbo = false })
    assert(not J.IsModeTurbo(), 'this leg is the non-turbo world')
    local a = answers(Defend, J, bot)
    assert(a[LANE_TOP] and a[LANE_MID] and a[LANE_BOT],
        'the candidate is turbo-only; in a non-turbo game it must not fire')
end

tests['[gate] arming some OTHER id does not fire this lever'] = function()
    -- 'roshdps' is a real armed-set id that this file does not mention at all
    -- (aba_defend gates exactly defclose / defnum / defstale / defquiet).
    -- Picking a live id from ANOTHER file is the point: it proves the gate is
    -- keyed to its own name, not merely to "something was armed".
    local J, bot, _, _, Defend = world({ armed = true, id = 'roshdps' })
    assert(J.IsSoakCandidate('roshdps') and not J.IsSoakCandidate('defquiet'),
        'this leg arms a different id on purpose')
    local a = answers(Defend, J, bot)
    assert(a[LANE_TOP] and a[LANE_MID] and a[LANE_BOT],
        'only defquiet may open this gate')
end

tests['[source] defclose ALSO moves this frame -- registered, not bundled'] = function()
    -- Measured while writing this file, and kept as an assertion rather than a
    -- sentence: arming 'defclose' ALONE (this lever untouched) already changes
    -- the answer on this frame, because defclose repairs the very
    -- GetClosestAllyPos({2,3}) scan that decides WHO the fallback names. The
    -- two candidates are in the same file, on the same clause, and they are
    -- NOT independent.
    --
    -- That is exactly the lanefix lesson (locally correct != emergently good),
    -- so it is written down here where the next person lands: if both ids ever
    -- ride the same wave, this frame is the one to read first. Nothing in this
    -- candidate depends on defclose being armed or unarmed -- every other leg
    -- in this file arms defquiet and nothing else.
    local J, bot, _, _, Defend = world({ armed = true, id = 'defclose' })
    local a = answers(Defend, J, bot)
    assert(not (a[LANE_TOP] and a[LANE_MID] and a[LANE_BOT]),
        'defclose alone is expected to move this frame; if it has stopped '
        .. 'doing so, the interaction note above is stale and needs re-measuring')
end

-- ---------------------------------------------------------------------------
-- [source] The clauses this lever DELIBERATELY leaves alone, pinned verbatim.
--
-- 0NEXT31 (乙): a lever that only changes "where the value comes from" keeps
-- criteria that read identically on the armed and unarmed legs, so no
-- behavioural case can see one being simplified away later. These assertions
-- are the thing that goes red instead. They are about the SHIPPED source file,
-- which is why they read it rather than drive it.
-- ---------------------------------------------------------------------------

tests['[source] the {2,3} role list and the ladder above it are unchanged'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('local bDefQuiet = jmz.IsSoakCandidate("defquiet") and jmz.IsModeTurbo()', 1, true),
        'the gate is turbo-only and named defquiet, as one independent conjunction')
    -- AMENDED 2026-09-16 (the same round that landed this file's successor,
    -- tests/test_defquiet_creep_siege.lua). The precondition grew a third
    -- disjunct, `creepWeights > 0`, because `nNearby >= 1` CANNOT see a creep
    -- wave: nNearby floors the creep sum and a lane creep is priced 0.2, so a
    -- full four-creep wave weighs 0.8 and reads as zero. Without the disjunct
    -- this candidate pulls the defender off a tower that is being taken.
    -- ⛔ The amendment costs this file's measured domain NOTHING and that is
    -- checked, not asserted by hand: the loader answers
    -- GetUnitList(UnitType.Enemies) with {} on all 112 fixtures, so
    -- creepWeights is 0 by construction here, and tests/_defquiet_sweep.lua
    -- re-run after the change reports the same 3360 / 385 / 193 / 192 it does
    -- above, split 182 role 3 + 10 role 2.
    assert(s:find('if (not bDefQuiet or nNearby >= 1 or creepWeights > 0) and not result and pos == GetClosestAllyPos(', 1, true),
        'the precondition is exactly "nNearby >= 1 or creepWeights > 0", and the '
        .. 'clause it guards is otherwise the shipped one, verbatim')
    assert(s:find('local nNearby = enemyHeroNearby + math.floor(creepWeights)', 1, true),
        'and the truncation that made the third disjunct necessary is itself '
        .. 'UNTOUCHED -- it feeds the ladder below, so moving it moves every rung')
    assert(s:find('{2, 3},', 1, true),
        'the role list stays {2, 3} -- this candidate does not touch WHICH roles '
        .. 'are eligible, only whether anybody is attacking the building')
    for _, n in ipairs({ 1, 2, 3 }) do
        assert(s:find('nNearby == ' .. n, 1, true),
            'the shipped ladder branch nNearby == ' .. n .. ' is still there')
    end
    assert(s:find('nNearby >= 4', 1, true), 'and the >= 4 branch')
    -- ⛔ ANCHORED TO THE RUNG, NOT TO THE STRING (fixed 2026-09-16, and it
    -- had already fired once by then). This used to read
    -- `not s:find('nNearby == 0')`, which is a claim about the WHOLE FILE,
    -- comments included -- so the next round's explanatory comment, which has
    -- to name the value it is talking about, turned this red while the ladder
    -- was untouched. The failure message said "the ladder has a zero branch";
    -- the assertion said "the three characters never occur". 0NEXT30's family,
    -- one storey up: the message named one proposition and the predicate
    -- tested another, and here BOTH were about the same file, which is why
    -- nothing about the red looked wrong.
    assert(not s:find('if nNearby == 0', 1, true)
        and not s:find('elseif nNearby == 0', 1, true),
        'the ladder still has NO rung for zero -- that absence IS the defect; '
        .. 'if somebody adds one, this lever needs rereading, not keeping')
end

tests['[source] the travel-boots escalation is left alone on purpose'] = function()
    local s = slurp(DEFEND_LUA)
    local i = s:find('local bDefQuiet', 1, true)
    assert(i ~= nil, 'the gate is in the file')
    local before = s:sub(1, i)
    assert(before:find('bot.travel_boots_defender = true', 1, true),
        'the travel-boots escalation sits ABOVE this clause and is untouched')
    assert(not s:find('bDefQuiet and bot.travel_boots_defender', 1, true),
        'this candidate must not have grown a second lever into that block')
end

tests['[source] the TypeScript source carries the same lever'] = function()
    local s = slurp(DEFEND_TS)
    assert(s:find('jmz.IsSoakCandidate("defquiet") && jmz.IsModeTurbo()', 1, true),
        'aba_defend.lua is transpiler output: a Lua-only lever is silently '
        .. 'reverted by the next regeneration')
    assert(s:find('(!bDefQuiet || nNearby >= 1 || creepWeights > 0) && !result && pos === GetClosestAllyPos([2, 3]', 1, true),
        'and it must be the SAME precondition, not a paraphrase of it '
        .. '(amended 2026-09-16 with the creepWeights disjunct -- see the note '
        .. 'on the Lua half above)')
end

return tests
