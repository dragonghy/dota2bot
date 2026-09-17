-- [threatcreep, selector] "Which lane is being pushed" is decided by a creep
-- term that cannot see a creep wave, so it answers Top.
--
-- aba_defend.GetThreatenedLane scores {Top, Mid, Bot} and takes the STRICT
-- maximum from a `bestScore = -1` seed, so every tie resolves to the FIRST
-- lane. A lane's score is `recentHeroCount * 10`, plus -- only when that count
-- is zero -- `math.min(w * 0.4, 0.9)`, where `w` is
-- WeightedEnemiesAroundLocation's FLOORED weighted sum.
--
-- ⭐⭐ THAT `w` IS ZERO FOR A CREEP WAVE, AND THERE ARE TWO INDEPENDENT WALLS
-- MAKING IT ZERO. Repairing either alone ships a no-op, which is why they are
-- one id and why this file drives BOTH.
--
--   WALL 1 -- THE LIST. WeightedEnemiesAroundLocation prices its units off
--   `unitState.enemyHeroes`, and that field is built as
--       GetUnitList(UnitType.Enemies) filtered by jmz.IsValidHero
--   so every unit reaching the pricing ladder has already answered IsValidHero,
--   and the ladder's FIRST branch takes exactly those. Its `siege` 0.5,
--   `upgraded` 0.4/0.6, `warlock_golem` 1 and `IsCreep()` 0.2 rungs are
--   UNREACHABLE: a creep is filtered out one struct field earlier and is never
--   priced at all. ⭐ The judge is in this same file, reading the same struct:
--   ShouldDefend's own creep loop walks `unitState.enemyCreeps` for the same
--   ladder. Two loops, the same intent, and only one was given the list it
--   prices. §2 drives that contrast rather than citing it.
--
--   WALL 2 -- THE FLOOR. Suppose wall 1 gone. A lane creep is priced 0.2 and a
--   full enemy wave is FOUR creeps:
--
--       4 * 0.2 = 0.8   and   math.floor(0.8) == 0
--
--   -- the same score an EMPTY lane gets. The creep half does not start
--   counting until the FIFTH body, and a wave is not five.
--
-- So the two inputs the tie-break exists to distinguish collapse onto each
-- other, and the answer falls out of the seed order: Top. Measured
-- (tests/_threatcreep_sweep.lua): on 47 of 112 corpus frames all three lanes
-- are hero-quiet, i.e. the creep term is the only thing deciding -- and the
-- shipped answer is Top on 47 of 47.
--
-- ⭐ WHY THIS CONSUMER AND NOT THE OTHER TWO. The floor has three consumers in
-- aba_defend and two are provable no-ops:
--   * `creepWeight >= 2` (base-threat re-arm): `math.floor(x) >= 2` iff
--     `x >= 2` for any real x. The floor cannot change that answer.
--   * the ShouldDefend `nNearby` role ladder: load-bearing there, priced last
--     round ([defcreep], tests/test_defquiet_creep_siege.lua). NOT touched.
-- Only the tie-break turns a 0.32 into a 0.00. So the fix builds a PARALLEL
-- sum -- creeps included, unfloored -- read only HERE and only when armed, and
-- leaves both `count` and `math.floor` untouched. Moving either would move all
-- three consumers in one edit, which is the lanefix bundle mistake.
--
-- ⛔ DIRECTION, said plainly: this is a SELECTOR, not a veto. Arming can move
-- the answer. What it cannot do is bounded and the bound is arithmetic -- the
-- creep term is capped at 0.9 and one visible enemy hero is worth 10, so arming
-- can NEVER move the answer off a lane with a visible enemy hero onto one
-- without. §4 drives that bound rather than asserting it from the comment.
--
-- ⛔ THE INSTRUMENT GAP, SAME ONE [defcreep] HIT (GH #863).
-- tests/mock/replay_fixture.lua answers GetUnitList(UnitType.Enemies) with an
-- empty table, and that list is the SOLE input to
-- WeightedEnemiesAroundLocation. So on this corpus the creep term is 0 by
-- CONSTRUCTION and armed reads baseline-identical (sweep: 0 of 112 frames
-- moved). §1 asserts that gap out loud, so the day the loader starts injecting
-- creeps this file says so instead of quietly changing what [threatcreep]
-- means. Per the charter's rule for reading a zero, §1 also asserts a NON-zero
-- from a DIFFERENT reader on the same frames (GetHeroLastSeenInfo: 120 of 336
-- lanes carry a non-zero hero count) -- the loader is gapped, not blind.
--
-- HOW A FILE-LOCAL IS REACHED, and why this is not a copy of the code.
-- GetThreatenedLane is a file-local, and its only exported consumer
-- (GetDefendDesireHelper) returns VeryLow long before reaching it on every
-- corpus frame. So this file reads the SHIPPED SOURCE TEXT and splices one
-- `____exports.__probe = {...}` line in ahead of its final `return ____exports`.
-- Every byte under measurement is the shipped byte; the splice adds an export
-- and changes no statement. If the tail stops being `return ____exports` the
-- assert aborts rather than measuring something else.
--
-- THE STAND-INS, each named with what it costs.
--   (1) §3 REAL CREEPS, REAL COORDINATES, REAL MULTIPLICITY. The dump of
--       f_20260909_212625_lion_235 carries FIVE enemy creeps within 1200 of the
--       radiant top anchor (nearest 218u). §3 feeds SUBSETS of that real sample,
--       k = 1..5, and nothing is replicated or moved. The dump carries no creep
--       NAME and the function prices by name, so every one is priced at the
--       MINIMUM bucket 0.2 -- the conservative side: mispricing can only make
--       the truncation look LESS severe than it is.
--   (2) §5 A CONSTRUCTED CHOICE OF TOWER, and it is the only constructed thing
--       in this file. No corpus frame carries an enemy creep near a non-Top
--       lane anchor (measured over all three creep-bearing fixtures and every
--       subject in them), so a demonstration that the answer MOVES has to place
--       creeps at the mid anchor. What is kept real is each creep's offset from
--       a tower -- the sample is translated as a rigid body, real distances and
--       real bearings -- and what is constructed is WHICH tower. Said here
--       rather than implied.
--   (3) §4 THE SAME TRANSLATION, WORKING AGAINST THE CLAIM. The bound test puts
--       the translated creeps on the hero-QUIET lane of a frame whose answer is
--       a LOUD lane, and asserts the answer does not move. More creep weight is
--       the direction that would BREAK that assertion, so the stand-in is
--       conservative there.
--
-- GH #61: GetLaneFrontLocation is unresolved in this corpus and the loader
-- REFUSES the call rather than answering (0,0,0). Nothing on the
-- GetThreatenedLane path reads a lane front -- the declaration below only keeps
-- aba_defend's module state constructible.
--
-- [ratchet]

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- All three lanes hero-quiet; one real enemy creep 270u from the top anchor.
local FRAME_QUIET = 'tests/fixtures/f_20260912_094042_sniper_546.lua'
local SUBJ_QUIET = 'npc_dota_hero_sniper'

-- Five real enemy creeps inside 1200 of the top anchor (nearest 218u).
local FRAME_WAVE = 'tests/fixtures/f_20260909_212625_lion_235.lua'
local SUBJ_WAVE = 'npc_dota_hero_axe'

-- Two lanes hero-quiet, one loud; the shipped answer is the loud lane.
local FRAME_LOUD = 'tests/fixtures/f_260822_182012_sb_fieldbuy_gate_307.lua'
local SUBJ_LOUD = 'npc_dota_hero_jakiro'

local DEFEND_LUA = 'bots/FunLib/aba_defend.lua'
local DEFEND_TS = 'typescript/bots/FunLib/aba_defend.ts'

local TAIL = 'return ____exports\n'
local PROBE = '____exports.__probe = {GetThreatenedLane = GetThreatenedLane,'
    .. ' WeightedEnemiesAroundLocation = WeightedEnemiesAroundLocation,'
    .. ' recentHeroCountNear = _recentHeroCountNear,'
    .. ' GetHighGroundEdgeWaitPoint = GetHighGroundEdgeWaitPoint,'
    .. ' IsValidBuildingTarget = IsValidBuildingTarget}\n'

local function slurp(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- The shipped source with one export spliced in ahead of its final return.
local function probed_source()
    local src = slurp(DEFEND_LUA)
    assert(src:sub(-#TAIL) == TAIL,
        DEFEND_LUA .. ' no longer ends in `' .. TAIL:gsub('\n', '') .. '`. The '
        .. 'probe splice below would land somewhere else -- fix the splice, do '
        .. 'not loosen this assert.')
    return src:sub(1, #src - #TAIL) .. PROBE .. TAIL
end

--- One enemy creep as WeightedEnemiesAroundLocation's loop needs to see it.
--- Position and team come from the dump; the NAME does not exist there, so this
--- is the minimum price bucket (see the stand-in note in the header).
local function creep_unit(x, y, team)
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
        GetTeam = function() return team end,
    }
    return setmetatable(u, {
        __index = function(_, k)
            error('creep stand-in has no ' .. tostring(k)
                .. ' -- add it deliberately or stop reading it', 2)
        end,
    })
end

--- Load one real frame with the real aba_defend (plus the probe export).
---   opts.armed  -- arm 'threatcreep' (nothing else is ever armed)
---   opts.id     -- arm a different id instead, for the gate section
---   opts.turbo  -- false makes J.IsModeTurbo() report a non-turbo game
---   opts.creeps -- {{x=,y=}, ...} injected as the enemy unit list; omitted
---                  means the corpus's own answer, which is none
local function world(frame, subject, opts)
    opts = opts or {}
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    rf = require('mock.replay_fixture')
    local J, bot, heroes, fx = rf.load(frame, subject)
    assert(bot ~= nil, 'fixture ' .. frame .. ' has no subject ' .. subject)
    J.IsSoakCandidate = function(id)
        return id == (opts.id or 'threatcreep') and opts.armed == true
    end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end
    if opts.creeps ~= nil then
        local enemyTeam = bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
        local units = {}
        for _, c in ipairs(opts.creeps) do
            units[#units + 1] = creep_unit(c.x, c.y, enemyTeam)
        end
        local prev = GetUnitList
        GetUnitList = function(kind) -- luacheck: ignore
            if kind == UNIT_LIST_ENEMIES then return units end
            return prev(kind)
        end
    end
    -- GH #61, declared above. Nothing below reads it.
    _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    local D = assert(loadstring(probed_source(), '@' .. DEFEND_LUA .. '[probe]'))()
    return J, bot, D, fx
end

--- Rebuilt per frame on purpose: LANE_* do not exist until the mock has run.
local function lanes()
    return { LANE_TOP, LANE_MID, LANE_BOT },
           { [LANE_TOP] = 'top', [LANE_MID] = 'mid', [LANE_BOT] = 'bot' }
end

--- The anchor GetThreatenedLane scores for one lane, through the SAME
--- file-local helpers the function itself calls -- never re-implemented here.
local function anchor_of(D, bot, lane)
    local bld, _urgent, tier = unpack(D.GetFurthestBuildingOnLane(lane))
    if D.__probe.IsValidBuildingTarget(bld) and tier < 3 then
        return bld:GetLocation()
    end
    return D.__probe.GetHighGroundEdgeWaitPoint(bot:GetTeam(), lane)
end

--- The dump's own enemy creeps within `radius` of `loc`, in world coordinates.
--- Read off the fixture file, never off the function under measurement.
local function dump_creeps_near(fx, bot, loc, radius)
    local out = {}
    for _, c in ipairs(fx.creeps or {}) do
        if c.team ~= bot:GetTeam() and (c.team == TEAM_RADIANT or c.team == TEAM_DIRE) then
            local d = math.sqrt((c.x - loc.x) ^ 2 + (c.y - loc.y) ^ 2)
            if d <= radius then out[#out + 1] = { x = c.x, y = c.y, d = d } end
        end
    end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

--- Translate a real creep sample rigidly from one anchor to another: every
--- offset, distance and bearing is preserved, only the tower is constructed.
local function translate(sample, from, to)
    local out = {}
    for _, c in ipairs(sample) do
        out[#out + 1] = { x = c.x - from.x + to.x, y = c.y - from.y + to.y }
    end
    return out
end

-- ---------------------------------------------------------------------------
-- §1 [instrument] The corpus cannot see a creep -- and is not blind either.
-- ---------------------------------------------------------------------------

tests['[instrument] the fixture loader returns no enemy units at all'] = function()
    world(FRAME_QUIET, SUBJ_QUIET)
    local lst = GetUnitList(UNIT_LIST_ENEMIES)
    assert(type(lst) == 'table', 'GetUnitList must answer a table')
    assert(#lst == 0,
        'tests/mock/replay_fixture.lua answers GetUnitList(UnitType.Enemies) '
        .. 'with {} -- if this is no longer 0 (' .. #lst .. '), the creep term '
        .. 'in GetThreatenedLane has stopped being 0 by construction and every '
        .. 'sweep reading in this family has to be re-taken, starting with '
        .. 'tests/_threatcreep_sweep.lua.')
end

tests['[instrument] the weighted sum is therefore zero on every lane'] = function()
    local _, bot, D = world(FRAME_QUIET, SUBJ_QUIET)
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        local w, raw = D.__probe.WeightedEnemiesAroundLocation(anchor_of(D, bot, lane), 1200)
        assert(w == 0 and raw == 0,
            'lane ' .. tostring(lane) .. ' weighted sum is ' .. tostring(w)
            .. '/' .. tostring(raw) .. ', not 0/0 -- see the instrument test above')
    end
end

tests['[instrument] a DIFFERENT reader does produce non-zeros on this frame'] = function()
    -- The zero above is a construction, not a fact about Dota. This is the
    -- same-frame non-zero the charter's rule for reading a zero asks for: the
    -- hero half of the same score, from GetHeroLastSeenInfo, on a frame the
    -- sweep classifies as having a loud lane.
    local _, bot, D = world(FRAME_LOUD, SUBJ_LOUD)
    local LANES = lanes()
    local loud = 0
    for _, lane in ipairs(LANES) do
        if D.__probe.recentHeroCountNear(anchor_of(D, bot, lane), 1800) > 0 then
            loud = loud + 1
        end
    end
    assert(loud >= 1,
        'no lane on ' .. FRAME_LOUD .. ' has a recently-seen enemy hero. If '
        .. 'BOTH readers answer zero everywhere, the loader is blind rather '
        .. 'than gapped and nothing in this file is a reading about Dota.')
end

-- ---------------------------------------------------------------------------
-- §2 [tie] The shipped answer on a hero-quiet frame is the seed order.
-- ---------------------------------------------------------------------------

tests['[tie] all three lanes hero-quiet, and the answer is the first lane'] = function()
    local _, bot, D = world(FRAME_QUIET, SUBJ_QUIET)
    local LANES = lanes()
    for _, lane in ipairs(LANES) do
        assert(D.__probe.recentHeroCountNear(anchor_of(D, bot, lane), 1800) == 0,
            'lane ' .. tostring(lane) .. ' is not hero-quiet on ' .. FRAME_QUIET
            .. ' -- this frame was chosen because all three are')
    end
    assert(D.__probe.GetThreatenedLane() == LANES[1],
        'with every lane scoring 0 the strict maximum must fall to the first '
        .. 'lane in the seed order')
end

-- ---------------------------------------------------------------------------
-- §3 [arith] The floor, driven by REAL creeps at REAL coordinates.
-- ---------------------------------------------------------------------------

tests['[arith] a real four-creep wave floors to zero; the fifth body starts it'] = function()
    local _, bot, D, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local top = anchor_of(D, bot, lanes()[1])
    local sample = dump_creeps_near(fx, bot, top, 1200)
    assert(#sample >= 5,
        FRAME_WAVE .. ' carries only ' .. #sample .. ' enemy creeps within '
        .. '1200 of the top anchor; this test needs 5 to reach the floor\'s '
        .. 'first non-zero without replicating anything.')

    for k = 1, 5 do
        local subset = {}
        for i = 1, k do subset[i] = sample[i] end
        local _, bot2, D2 = world(FRAME_WAVE, SUBJ_WAVE, { creeps = subset })
        local w, raw = D2.__probe.WeightedEnemiesAroundLocation(
            anchor_of(D2, bot2, lanes()[1]), 1200)
        -- Every creep is priced at the minimum bucket 0.2 (no name in the dump).
        assert(math.abs(raw - 0.2 * k) < 1e-9,
            k .. ' real creeps must weigh ' .. (0.2 * k) .. ', got ' .. tostring(raw))
        -- WALL 2, on the real sum: this is what the shipped `math.floor` would
        -- have done to it if wall 1 had ever let it through.
        local expected = k < 5 and 0 or 1
        assert(math.floor(raw) == expected,
            k .. ' real creeps floor to ' .. tostring(math.floor(raw))
            .. ', expected ' .. expected
            .. ' -- a FULL WAVE IS FOUR, and four times 0.2 is 0.8')
        assert(w == 0, 'wall 1: the shipped sum must stay 0 (see the test above)')
    end
end

tests['[arith] WALL 1: shipped prices a real creep at zero, the fix at 0.2'] = function()
    -- The judge for wall 1, driven rather than cited. Same frame, same creep,
    -- same function: the shipped (floored, hero-list) value stays 0 no matter
    -- how many real creeps stand on the tower, because they never reach the
    -- ladder at all. If shipped ever starts counting them, the whole two-wall
    -- derivation in the header is stale and this test says so.
    local _, bot, D, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local top = anchor_of(D, bot, lanes()[1])
    local sample = dump_creeps_near(fx, bot, top, 1200)
    local _, bot2, D2 = world(FRAME_WAVE, SUBJ_WAVE, { creeps = sample })
    local w, raw = D2.__probe.WeightedEnemiesAroundLocation(
        anchor_of(D2, bot2, lanes()[1]), 1200)
    assert(w == 0,
        #sample .. ' real enemy creeps on the top tower and the SHIPPED weighted '
        .. 'sum is ' .. tostring(w) .. ', not 0. `unitState.enemyHeroes` is '
        .. 'GetUnitList(Enemies) filtered by IsValidHero, so no creep can reach '
        .. 'the pricing ladder -- if that filter changed, re-derive the header.')
    assert(math.abs(raw - 0.2 * #sample) < 1e-9,
        'the fix must price ' .. #sample .. ' real creeps at ' .. (0.2 * #sample)
        .. ', got ' .. tostring(raw))
end

tests['[arith] the floor is a provable no-op at the other consumer\'s threshold'] = function()
    -- `creepWeight >= 2` (the base-threat re-arm) cannot be moved by the floor:
    -- math.floor(x) >= 2 iff x >= 2. Driven rather than argued, so that a future
    -- change to the pricing cannot quietly make that comment false.
    local _, bot, D, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local top = anchor_of(D, bot, lanes()[1])
    local sample = dump_creeps_near(fx, bot, top, 1200)
    for k = 1, #sample do
        local subset = {}
        for i = 1, k do subset[i] = sample[i] end
        local _, bot2, D2 = world(FRAME_WAVE, SUBJ_WAVE, { creeps = subset })
        local _w, raw = D2.__probe.WeightedEnemiesAroundLocation(
            anchor_of(D2, bot2, lanes()[1]), 1200)
        assert((math.floor(raw) >= 2) == (raw >= 2),
            'at k=' .. k .. ' the floored sum ' .. tostring(math.floor(raw))
            .. ' and the raw sum ' .. tostring(raw) .. ' disagree about the '
            .. '>= 2 threshold')
    end
end

-- ---------------------------------------------------------------------------
-- §4 [bound] Arming can never take the answer off a lane that has a hero.
-- The stand-in works AGAINST this assertion, so it is the conservative side.
-- ---------------------------------------------------------------------------

tests['[bound] a loud lane still wins even when a quiet lane is full of creeps'] = function()
    local _, bot, D, fxW = world(FRAME_LOUD, SUBJ_LOUD)
    local LANES = lanes()
    local shipped = D.__probe.GetThreatenedLane()
    assert(D.__probe.recentHeroCountNear(anchor_of(D, bot, shipped), 1800) > 0,
        'the shipped answer on ' .. FRAME_LOUD .. ' is not a lane with a '
        .. 'visible enemy hero -- this test picked the wrong frame')

    -- A quiet lane to load up with creeps.
    local quiet = nil
    for _, lane in ipairs(LANES) do
        if lane ~= shipped
            and D.__probe.recentHeroCountNear(anchor_of(D, bot, lane), 1800) == 0
        then quiet = lane break end
    end
    assert(quiet ~= nil, FRAME_LOUD .. ' has no hero-quiet lane to load')

    local _, botW, DW, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local fromAnchor = anchor_of(DW, botW, lanes()[1])
    local sample = dump_creeps_near(fx, botW, fromAnchor, 1200)
    local _, bot2, D2 = world(FRAME_LOUD, SUBJ_LOUD, {
        armed = true,
        creeps = translate(sample, fromAnchor, anchor_of(D, bot, quiet)),
    })
    assert(D2.__probe.GetThreatenedLane() == shipped,
        'armed moved the answer off a lane with a visible enemy hero. The creep '
        .. 'term is capped at 0.9 and one hero is worth 10, so this cannot '
        .. 'happen unless the cap or the scale moved.')
    local _ = fxW
end

-- ---------------------------------------------------------------------------
-- §5 [fix] The answer moves to the lane the creeps are actually on.
-- One constructed thing in this file: WHICH tower (see the header).
-- ---------------------------------------------------------------------------

tests['[fix] shipped answers Top with a wave on mid; armed answers mid'] = function()
    local _, botW, DW, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local fromAnchor = anchor_of(DW, botW, lanes()[1])
    local sample = dump_creeps_near(fx, botW, fromAnchor, 1200)
    local wave = {}
    for i = 1, 4 do wave[i] = sample[i] end   -- a FULL WAVE, four creeps

    local _, bot, D = world(FRAME_QUIET, SUBJ_QUIET)
    local LANES = lanes()
    local mid = LANES[2]
    local creeps = translate(wave, fromAnchor, anchor_of(D, bot, mid))

    local _, _, Dship = world(FRAME_QUIET, SUBJ_QUIET, { creeps = creeps })
    assert(Dship.__probe.GetThreatenedLane() == LANES[1],
        'shipped must still answer the first lane: four creeps weigh 0.8 and '
        .. 'floor to 0, the same as an empty lane, so the tie stands')

    local _, _, Darm = world(FRAME_QUIET, SUBJ_QUIET, { creeps = creeps, armed = true })
    assert(Darm.__probe.GetThreatenedLane() == mid,
        'armed must answer the lane the wave is on: 4 * 0.2 * 0.4 = 0.32 beats '
        .. 'the 0 the other two lanes score')
end

tests['[fix] control, same frame, same clause: no creeps and the tie still holds'] = function()
    -- The in-frame control 0NEXT32 asks for: what moves the answer is the wave,
    -- not arming being a rewrite of the tie-break.
    local _, _, D = world(FRAME_QUIET, SUBJ_QUIET, { armed = true })
    assert(D.__probe.GetThreatenedLane() == lanes()[1],
        'with no creeps anywhere, armed and shipped must agree -- an EXACT tie '
        .. 'still resolves to the first lane')
end

-- ---------------------------------------------------------------------------
-- §6 [gate] Inert unarmed, inert outside turbo.
-- ---------------------------------------------------------------------------

tests['[gate] unarmed, a wave on mid does not move the answer'] = function()
    local _, botW, DW, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local fromAnchor = anchor_of(DW, botW, lanes()[1])
    local sample = dump_creeps_near(fx, botW, fromAnchor, 1200)
    local wave = {}
    for i = 1, 4 do wave[i] = sample[i] end

    local _, bot, D = world(FRAME_QUIET, SUBJ_QUIET)
    local creeps = translate(wave, fromAnchor, anchor_of(D, bot, lanes()[2]))

    local _, _, Dother = world(FRAME_QUIET, SUBJ_QUIET,
        { creeps = creeps, armed = true, id = 'defquiet' })
    assert(Dother.__probe.GetThreatenedLane() == lanes()[1],
        'arming some OTHER id moved this answer -- the gate is not reading '
        .. '"threatcreep"')
end

tests['[gate] armed but not turbo, a wave on mid does not move the answer'] = function()
    local _, botW, DW, fx = world(FRAME_WAVE, SUBJ_WAVE)
    local fromAnchor = anchor_of(DW, botW, lanes()[1])
    local sample = dump_creeps_near(fx, botW, fromAnchor, 1200)
    local wave = {}
    for i = 1, 4 do wave[i] = sample[i] end

    local _, bot, D = world(FRAME_QUIET, SUBJ_QUIET)
    local creeps = translate(wave, fromAnchor, anchor_of(D, bot, lanes()[2]))

    local _, _, Dnt = world(FRAME_QUIET, SUBJ_QUIET,
        { creeps = creeps, armed = true, turbo = false })
    assert(Dnt.__probe.GetThreatenedLane() == lanes()[1],
        'the turbo conjunct is not being asked: this id is turbo-only')
end

-- ---------------------------------------------------------------------------
-- §7 [source] The retained criteria, pinned verbatim.
--
-- 0NEXT33 §乙, the cost of which was measured last round: a bare string anchor
-- is matched by the EXPLANATORY COMMENT that has to name the same value, so
-- every anchor below carries its syntactic position (`local `, `math.min(`,
-- `if `) and none of them is a bare literal.
-- ---------------------------------------------------------------------------

tests['[source] math.floor survives in WeightedEnemiesAroundLocation'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('\n    count = math.floor(count)\n    _cacheEnemyAroundLoc[key]', 1, true),
        'the floor itself must stay, immediately before the cache write: it '
        .. 'feeds the `creepWeight >= 2` re-arm and the ShouldDefend role '
        .. 'ladder. [threatcreep] keeps the raw sum ALONGSIDE it, never '
        .. 'instead of it.')
    assert(s:find('\n    local rawCount = count\n    for ____, unit in ipairs(unitState.enemyCreeps) do', 1, true),
        'the parallel sum must start from the shipped hero sum and then walk '
        .. '`unitState.enemyCreeps` -- that list IS the wall-1 repair')
end

tests['[source] the cap, the scale and the radius are untouched'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('WeightedEnemiesAroundLocation(anchor, 1200)', 1, true),
        'the 1200 radius moved')
    assert(s:find('nWeightedRaw or nWeighted) * 0.4', 1, true),
        'the 0.4 scale moved')
    assert(s:find('%* 0%.4,\n%s*0%.9\n%s*%)'),
        'the 0.9 cap moved -- and the cap is what bounds the selector (§4)')
end

tests['[source] the gate is standalone and turbo-only'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('local bThreatCreep = jmz.IsSoakCandidate("threatcreep") and jmz.IsModeTurbo()', 1, true),
        'the [threatcreep] gate must be exactly one id conjoined with turbo -- '
        .. 'a conjunction of two soak ids is the pullcad trap')
    local _, n = s:gsub('IsSoakCandidate%("threatcreep"%)', '')
    assert(n == 1, 'threatcreep is gated in ' .. n .. ' places, expected 1')
end

tests['[source] the creep term still only runs on a hero-quiet lane'] = function()
    local s = slurp(DEFEND_LUA)
    assert(s:find('if enemyHeroCnt == 0 then\n%s*local nWeighted, nWeightedRaw'),
        'the `enemyHeroCnt == 0` guard is the reason the bound in §4 holds; it '
        .. 'must still be the thing the creep term hangs off')
end

tests['[source] the TypeScript source carries the same three edits'] = function()
    local s = slurp(DEFEND_TS)
    assert(s:find('    let rawCount = count;\n    for (const unit of unitState.enemyCreeps) {', 1, true),
        'TS: the parallel sum must start from the shipped hero sum and then '
        .. 'walk `unitState.enemyCreeps` -- that list IS the wall-1 repair')
    assert(s:find('return $multi(count, rawCount);', 1, true), 'TS: second return missing')
    assert(s:find('const bThreatCreep = jmz.IsSoakCandidate("threatcreep") && jmz.IsModeTurbo();', 1, true),
        'TS: gate missing')
    assert(s:find('raw?: number', 1, true), 'TS: cache type not widened')
end

return tests
