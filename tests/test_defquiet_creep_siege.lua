-- [defquiet, narrowing] "Nobody is attacking this building" was being asked as
-- `nNearby >= 1`, and nNearby cannot see a creep wave.
--
-- aba_defend.ShouldDefend builds its threat count as
--
--     local nNearby = enemyHeroNearby + math.floor(creepWeights)
--
-- where a lane creep is priced at 0.2. A FULL enemy wave is four creeps. Four
-- times 0.2 is 0.8, and math.floor(0.8) is ZERO -- the creep half of this
-- count does not start counting until the FIFTH body. So a tower being taken
-- by a wave with no hero in sight is `nNearby == 0`: "quiet".
--
-- That truncation was harmless while the only consumer was the 1/2/3/>=4 role
-- ladder, because everything the ladder declines falls through to the
-- unconditioned `pos == GetClosestAllyPos({2,3}, building)` fallback, which
-- names a defender anyway. [defquiet] removed that fallback on quiet buildings
-- -- and asked "quiet?" with the truncating count. The two together take the
-- defender off exactly the building that is being taken.
--
-- THE FIX IS ONE DISJUNCT: `creepWeights > 0` joins `nNearby >= 1` in the
-- precondition. It only ever RESTORES shipped behaviour, so [defquiet]'s
-- one-directional property (armed can only remove a defender, never add one)
-- survives verbatim and is re-asserted here. The truncation itself is NOT
-- touched: it feeds the role ladder, and moving it would move every rung.
--
-- ⛔ WHY THIS FILE EXISTS AT ALL, AND WHY NO SWEEP BACKS IT.
-- tests/mock/replay_fixture.lua answers GetUnitList(UnitType.Enemies) with an
-- empty table. Measured 2026-09-16 across every loadable fixture: 112 frames,
-- 0 units returned. So `creepWeights` is 0 BY CONSTRUCTION in every sweep this
-- repo can run, including tests/_defquiet_sweep.lua, whose 192 MOVED triples
-- are therefore "no enemy HERO within 1600", not "no enemy within 1600". The
-- disjunct is inert on the corpus; §1 asserts that, so that the day the loader
-- starts injecting creeps this file says so out loud instead of quietly
-- changing what [defquiet] means.
--
-- ONE DECLARED STAND-IN, and it is the whole instrument. §3 and §4 feed
-- ShouldDefend the fixture's OWN creep sample -- {team, x, y} straight off the
-- dump, real positions, real teams -- through a local GetUnitList wrapper.
-- The dump carries NO creep NAME, and ShouldDefend prices by name
-- ("siege" 0.5, "upgraded_mega" 0.6, "upgraded" 0.4, warlock_golem /
-- shadow_shaman_ward 1.0, anything else that IsCreep() 0.2). Every sampled
-- creep is therefore priced at the MINIMUM bucket, 0.2. That is the
-- conservative side on purpose: mispricing can only make creepWeights SMALLER,
-- i.e. can only make the truncation look LESS severe than it is.
--
-- REAL FRAME: f_20260912_094042_sniper_546 at t=546, turbo, Radiant.
-- Subject bristleback, drafted role 3. Its top-lane building has ZERO enemy
-- heroes within 1600 -- and the dump's own creep sample puts an enemy creep
-- 270 units from it. Shipped names bristleback that tower's defender;
-- [defquiet] as landed last round takes him off it.
--
-- CONTROL, ON THE SAME FRAME rather than a separate one: mid and bot. Both are
-- quiet on BOTH halves (no enemy hero, no enemy creep within 1600), and armed
-- must still drop them. Same clause, same frame, same subject: what moves the
-- top lane is the creep, not the narrowing being a no-op.
--
-- ANOTHER DECLARED STAND-IN, §2 only: the count. The dump's sample near that
-- tower is one creep, so the "a full wave floors to zero" arithmetic is driven
-- by REPLICATING that real creep's position 1..5 times. Real geometry,
-- constructed multiplicity, said here rather than implied.
--
-- GH #61: GetLaneFrontLocation is unresolved in this corpus and the loader
-- REFUSES the call rather than answering (0,0,0). ShouldDefend never reads a
-- lane front -- it reads the building it is handed -- so the declaration below
-- only keeps aba_defend's module state constructible.
--
-- [ratchet]

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FRAME = 'tests/fixtures/f_20260912_094042_sniper_546.lua'
local SUBJECT = 'npc_dota_hero_bristleback'

local DEFEND_LUA = 'bots/FunLib/aba_defend.lua'
local DEFEND_TS = 'typescript/bots/FunLib/aba_defend.ts'

--- One enemy creep as ShouldDefend's loop needs to see it. Position and team
--- come from the dump; the NAME does not exist there, so this is the minimum
--- price bucket (see the stand-in note in the header).
local function creep_unit(x, y)
    local u
    u = {
        IsNull = function() return false end,
        CanBeSeen = function() return true end,
        IsAlive = function() return true end,
        IsBuilding = function() return false end,
        -- Deliberate, not a default: jmz.IsValid delegates to
        -- utils.IsValidUnit, whose last conjunct is `not IsInvulnerable()`. A
        -- lane creep walking at a tower is not invulnerable. (The loader does
        -- not derive this predicate for anybody -- GH #858 -- which is why the
        -- stand-in has to answer it rather than inherit it.)
        IsInvulnerable = function() return false end,
        IsMagicImmune = function() return false end,
        IsHero = function() return false end,
        IsIllusion = function() return false end,
        IsCreep = function() return true end,
        IsAncientCreep = function() return false end,
        IsDominated = function() return false end,
        HasModifier = function() return false end,
        GetUnitName = function() return 'npc_dota_creep_badguys_melee' end,
        GetLocation = function() return Vector(x, y, 128) end,
        GetTeam = function() return u.__team end,
    }
    u.__team = 0
    return setmetatable(u, {
        __index = function(_, k)
            error('creep stand-in has no ' .. tostring(k)
                .. ' -- add it deliberately or stop reading it', 2)
        end,
    })
end

--- Load the real frame with the real aba_defend on top of it.
---   opts.armed  -- arm 'defquiet' (nothing else is ever armed)
---   opts.turbo  -- false makes J.IsModeTurbo() report a non-turbo game
---   opts.creeps -- inject a list of {x=, y=} as the enemy creep sample;
---                  omitted means the corpus's own answer, which is none
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
    if opts.creeps ~= nil then
        local units = {}
        for _, c in ipairs(opts.creeps) do
            units[#units + 1] = creep_unit(c.x, c.y)
        end
        local prev = GetUnitList
        GetUnitList = function(kind) -- luacheck: ignore
            if kind == UNIT_LIST_ENEMIES then return units end
            return prev(kind)
        end
    end
    -- GH #61, declared above. Nothing below reads it.
    _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, heroes, fx, Defend
end

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

--- The dump's own enemy-creep sample, in world coordinates, plus the distance
--- from each to the given building. Read off the fixture file, never off the
--- function under measurement.
local function dump_creeps_near(fx, bot, bld, radius)
    local loc = bld:GetLocation()
    local out = {}
    for _, c in ipairs(fx.creeps or {}) do
        if c.team ~= bot:GetTeam() and (c.team == TEAM_RADIANT or c.team == TEAM_DIRE) then
            local d = math.sqrt((c.x - loc.x) ^ 2 + (c.y - loc.y) ^ 2)
            if d <= radius then out[#out + 1] = { x = c.x, y = c.y, d = d } end
        end
    end
    return out
end

local function slurp(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- ---------------------------------------------------------------------------
-- §1 [instrument] The corpus cannot see a creep. Assert it, do not assume it.
-- ---------------------------------------------------------------------------

tests['[instrument] the fixture loader returns no enemy units at all'] = function()
    world()
    local lst = GetUnitList(UNIT_LIST_ENEMIES)
    assert(type(lst) == 'table', 'GetUnitList must answer a table')
    assert(#lst == 0,
        'tests/mock/replay_fixture.lua answers GetUnitList(UnitType.Enemies) '
        .. 'with {} -- if this is no longer 0 (' .. #lst .. '), the creep half '
        .. 'of nNearby has become drivable and every "quiet" reading in '
        .. 'tests/_defquiet_sweep.lua and test_defquiet_idle_defender.lua has '
        .. 'to be re-read: they say "no enemy HERO", not "no enemy"')
end

tests['[instrument] so arming defquiet is unchanged by this narrowing'] = function()
    -- creepWeights is 0 by construction above ⇒ the new disjunct is false on
    -- every frame this repo can drive ⇒ the sweep's 192 MOVED triples are the
    -- same 192 before and after. This is the assertion that says the narrowing
    -- cost the measured domain nothing.
    local J, bot, _, _, Defend = world({ armed = true })
    local a = answers(Defend, J, bot)
    assert(a[LANE_TOP] == false and a[LANE_MID] == false and a[LANE_BOT] == false,
        'with no creep sample injected, armed still drops all three quiet '
        .. 'lanes exactly as it did before the disjunct existed')
end

-- ---------------------------------------------------------------------------
-- §2 [frame] Every premise the defect rests on, off the frame.
-- ---------------------------------------------------------------------------

tests['[frame] subject is a role 3 in a turbo game, top building is hero-quiet'] = function()
    local J, bot, _, fx, Defend = world()
    assert(J.IsModeTurbo(), 'the dump is turbo -- a turbo-only gate needs that')
    assert(bot:GetUnitName() == SUBJECT, 'subject is the bristleback')
    assert(fx.roles ~= nil,
        'the fixture must carry DRAFTED roles -- without them GetPosition '
        .. 'falls back to the draft slot (GH #57: 47.3% accurate)')
    assert(J.GetPosition(bot) == 3,
        'subject was drafted role 3; got ' .. tostring(J.GetPosition(bot)))
    local _, near = answers(Defend, J, bot)
    assert(near[LANE_TOP] == 0,
        'top building has ZERO enemy heroes within 1600; got ' .. near[LANE_TOP])
    assert(near[LANE_MID] == 0 and near[LANE_BOT] == 0,
        'mid and bot are hero-quiet too -- the control lanes')
end

tests['[frame] the dump puts an enemy creep 270u from that same top building'] = function()
    local _, bot, _, fx, Defend = world()
    local top = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    local near = dump_creeps_near(fx, bot, top, 1600)
    assert(#near == 1,
        'the dump\'s own creep sample has exactly one enemy creep within 1600 '
        .. 'of the top building; got ' .. #near)
    assert(near[1].d < 300,
        'and it is inside 300u of the tower; got ' .. string.format('%.0f', near[1].d))
    -- the controls are creep-quiet as well, which is what makes them controls
    for _, lane in ipairs({ LANE_MID, LANE_BOT }) do
        local bld = Defend.GetFurthestBuildingOnLane(lane)[1]
        assert(#dump_creeps_near(fx, bot, bld, 1600) == 0,
            'control lane must have no enemy creep within 1600 either')
    end
end

tests['[arith] the creep half of nNearby does not count until the fifth body'] = function()
    -- CONSTRUCTED MULTIPLICITY, REAL POSITION (declared in the header): the
    -- real creep's coordinates replicated k times. Driven through the shipped
    -- role ladder using a role 2 subject, because pos == 2 is the one rung
    -- that nNearby == 1 opens and nNearby == 0 does not.
    local _, bot, _, fx, Defend = world()
    local top = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    local spot = dump_creeps_near(fx, bot, top, 1600)[1]
    local function ladder_entered(k)
        local sample = {}
        for _ = 1, k do sample[#sample + 1] = { x = spot.x, y = spot.y } end
        -- role 2 on this frame is the sniper; shipped answers FALSE for it on
        -- the top lane while nNearby == 0, and TRUE the moment the ladder opens
        for key in pairs(package.loaded) do
            if key:find('FunLib') or key:find('mock') then package.loaded[key] = nil end
        end
        local r = require('mock.replay_fixture')
        local J2, bot2 = r.load(FRAME, 'npc_dota_hero_sniper')
        J2.IsSoakCandidate = function() return false end
        local units = {}
        for _, c in ipairs(sample) do units[#units + 1] = creep_unit(c.x, c.y) end
        local prev = GetUnitList
        GetUnitList = function(kind) -- luacheck: ignore
            if kind == UNIT_LIST_ENEMIES then return units end
            return prev(kind)
        end
        _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
        local D2 = require(GetScriptDirectory() .. '/FunLib/aba_defend')
        assert(J2.GetPosition(bot2) == 2, 'the arithmetic probe needs a role 2')
        return D2.ShouldDefend(bot2, D2.GetFurthestBuildingOnLane(LANE_TOP)[1], 1600)
            and true or false
    end
    for k = 1, 4 do
        assert(ladder_entered(k) == false,
            k .. ' creeps weigh ' .. (0.2 * k) .. ', which floors to 0 -- a FULL '
            .. 'wave of four is still "nobody is here" to the ladder')
    end
    assert(ladder_entered(5) == true,
        'the fifth body is what finally makes floor(creepWeights) == 1 and '
        .. 'opens the nNearby == 1 rung -- this is the truncation, driven')
end

-- ---------------------------------------------------------------------------
-- §3 [fix] The load-bearing frame: shipped keeps the defender, defquiet as
-- landed took him off, the narrowing puts him back -- and nowhere else.
-- ---------------------------------------------------------------------------

tests['[fix] shipped names this hero defender of the creep-sieged tower'] = function()
    local _, bot, _, fx, Defend = world()
    local top = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    local sample = dump_creeps_near(fx, bot, top, 1600)
    local J2, bot2, _, _, D2 = world({ creeps = sample })
    local a = answers(D2, J2, bot2)
    assert(a[LANE_TOP] == true,
        'SHIPPED: the fallback clause names role 3 the defender of the tower a '
        .. 'creep is standing 270u from')
end

tests['[fix] armed KEEPS the defender on the creep-sieged tower'] = function()
    local _, bot, _, fx, Defend = world()
    local top = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    local sample = dump_creeps_near(fx, bot, top, 1600)
    local J2, bot2, _, _, D2 = world({ armed = true, creeps = sample })
    local a, near = answers(D2, J2, bot2)
    assert(a[LANE_TOP] == true,
        'ARMED: creepWeights > 0 holds the precondition open -- without this '
        .. 'disjunct defquiet pulls the defender off a tower under a wave')
    assert(near[LANE_TOP] == 0,
        'and it is NOT the hero half doing it: zero enemy heroes within 1600, '
        .. 'so nNearby == 0 and `nNearby >= 1` is false here')
    assert(a[LANE_MID] == false and a[LANE_BOT] == false,
        'CONTROL, same frame, same clause: the two lanes with neither a hero '
        .. 'nor a creep near them still lose their defender')
end

tests['[fix] armed can only REMOVE a defender, never add one'] = function()
    local _, bot, _, fx, Defend = world()
    local top = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    local sample = dump_creeps_near(fx, bot, top, 1600)
    local Js, bs, _, _, Ds = world({ creeps = sample })
    local shipped = answers(Ds, Js, bs)
    local Ja, ba, _, _, Da = world({ armed = true, creeps = sample })
    local armed = answers(Da, Ja, ba)
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        assert(not (armed[lane] and not shipped[lane]),
            'armed answered TRUE where shipped answered FALSE on lane '
            .. tostring(lane) .. ' -- the gate must stay one-directional')
    end
end

-- ---------------------------------------------------------------------------
-- §4 [gate] Unarmed and non-turbo stay byte-for-byte shipped.
-- ---------------------------------------------------------------------------

tests['[gate] unarmed is shipped, with or without creeps in sight'] = function()
    local _, bot, _, fx, Defend = world()
    local top = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    local sample = dump_creeps_near(fx, bot, top, 1600)
    local J1, b1, _, _, D1 = world({ creeps = sample })
    local J2, b2, _, _, D2 = world({ armed = true, id = 'somethingelse', creeps = sample })
    local a1, a2 = answers(D1, J1, b1), answers(D2, J2, b2)
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        assert(a1[lane] == a2[lane],
            'arming some OTHER id must not move this function on lane ' .. tostring(lane))
    end
end

tests['[gate] a non-turbo game is shipped even with defquiet armed'] = function()
    local _, bot, _, fx, Defend = world()
    local top = Defend.GetFurthestBuildingOnLane(LANE_TOP)[1]
    local sample = dump_creeps_near(fx, bot, top, 1600)
    local J1, b1, _, _, D1 = world({ creeps = sample })
    local J2, b2, _, _, D2 = world({ armed = true, turbo = false, creeps = sample })
    local a1, a2 = answers(D1, J1, b1), answers(D2, J2, b2)
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        assert(a1[lane] == a2[lane],
            'non-turbo must be shipped byte for byte on lane ' .. tostring(lane))
    end
end

-- ---------------------------------------------------------------------------
-- §5 [source] The predicates this lever KEEPS, pinned verbatim.
--
-- 0NEXT31 §乙, third time it has paid: a lever that only changes where a value
-- comes from leaves identical behaviour on both legs for everything it
-- preserved, so no behavioural case can see somebody "simplifying" a retained
-- clause away. These assertions are the only thing that would go red.
-- ---------------------------------------------------------------------------

tests['[source] the precondition is a three-way disjunction, turbo-gated'] = function()
    local lua = slurp(DEFEND_LUA)
    assert(lua:find('if (not bDefQuiet or nNearby >= 1 or creepWeights > 0) and not result',
        1, true),
        'the fallback precondition must read exactly '
        .. '`not bDefQuiet or nNearby >= 1 or creepWeights > 0`')
    assert(lua:find('local bDefQuiet = jmz.IsSoakCandidate("defquiet") and jmz.IsModeTurbo()',
        1, true),
        'and it must stay turbo-only, and gated on defquiet ALONE -- a gate '
        .. 'written as IsSoakCandidate(X) and IsSoakCandidate(Y) freezes FALSE '
        .. 'the day Y is promoted')
end

tests['[source] the truncation and the role ladder are NOT touched'] = function()
    local lua = slurp(DEFEND_LUA)
    assert(lua:find('local nNearby = enemyHeroNearby + math.floor(creepWeights)', 1, true),
        'math.floor stays: it feeds the 1/2/3/>=4 ladder, and moving it would '
        .. 'move every rung. This lever repairs the PRECONDITION, not the count')
    for _, rung in ipairs({ 'if nNearby == 1 then', 'elseif nNearby == 2 then',
                            'elseif nNearby == 3 then', 'elseif nNearby >= 4 then' }) do
        assert(lua:find(rung, 1, true), 'ladder rung missing: ' .. rung)
    end
    assert(lua:find('creepWeights = creepWeights + 0.2', 1, true),
        'the 0.2 lane-creep price is what makes a four-creep wave floor to 0; '
        .. 'if this number moved, the arithmetic in §2 has to be re-read')
    assert(lua:find('pos == GetClosestAllyPos(\n            {2, 3},', 1, true)
        or lua:find('{2, 3},', 1, true),
        'the {2, 3} role table belongs to [defclose] -- this lever does not '
        .. 'touch which role the fallback picks, only whether it fires')
end

tests['[source] the travel-boots escalation above is still untouched'] = function()
    local lua = slurp(DEFEND_LUA)
    local i = lua:find('local bDefQuiet', 1, true)
    local head = lua:sub(1, i)
    assert(head:find('bot.travel_boots_defender = true', 1, true),
        'the escalation block must still be above the gate, unguarded: it has '
        .. 'the SAME missing precondition and writes state on a quiet frame. '
        .. 'Registered, not fixed -- 0 of 1120 (fixture, hero) pairs in this '
        .. 'corpus hold travel boots, so it has a constructive zero domain here')
end

tests['[source] the lua and the ts carry the same predicate'] = function()
    local ts = slurp(DEFEND_TS)
    assert(ts:find('(!bDefQuiet || nNearby >= 1 || creepWeights > 0)', 1, true),
        'the .ts is the source and the .lua is its transpile output -- a Lua '
        .. 'only edit is silently reverted by the next transpile')
end

return tests
