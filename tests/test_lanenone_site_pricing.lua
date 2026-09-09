-- [GH #652] The three REMAINING sites of the GH #648 defect, priced on one
-- corpus walk, and the repair of the one site the readings picked.
--
-- THE FAMILY. `bot:GetAssignedLane()` answers one of four documented engine
-- constants (docs/BOT_API_REFERENCE.md:1910 -- LANE_NONE = 0, LANE_TOP = 1,
-- LANE_MID = 2, LANE_BOT = 3), so the engine's "this bot has no lane" is the
-- NUMBER 0, not nil. Four sites in bots/FunLib/jmz_func.lua guard their lane
-- geometry with `nLane == nil` / `nLane ~= nil` instead. GH #648 repaired the
-- first (J.ShouldPullNeutralCamp) and named the other three; this file is what
-- the naming was for.
--
-- ⭐ WHY THE PRICING COMES FIRST, AND WHAT IT COST THE OTHER TWO. "One lever at
-- a time" only means something if the lever is picked on a reading. All three
-- sites were driven on the same 1021 alive-hero-frame walk BEFORE a line of
-- bots/ was written (tests/_pullcamp_sweep.lua), and two of them lost:
--
--   * J.ShouldLaneRecoverFarm -- 0 frames REACH its lane block. Three guards
--     sit above it and one is J.GetDistanceFromLaneFront, which calls the
--     function the loader refuses (GH #61): `lrf_raise_lanefront` 631,
--     `lrf_false` 390, `lrf_true` 0, and 631 + 390 == 1021, so the population
--     closes with nothing left over. A repair there cannot be priced from this
--     corpus at all, and an unpriceable repair is not a lever.
--   * J.ShouldCreepPullLane -- its block reads GetLaneFrontAmount for BOTH
--     teams with the SAME lane id and compares them, so a bad lane id degrades
--     the two reads SYMMETRICALLY. `frontamt_differs` 0 / 1021 and
--     `frontamt_pushed` 0: a repair there is a measured no-op on the whole
--     corpus. And that site is inside a PROMOTED helper ('creeppull', live in
--     every turbo game), so the trade on offer was live-behaviour risk for a
--     measured zero.
--   * J.GetLanePullDragTarget -- `alongline_nonnil` 1021 / 1021, `drag_nonnil`
--     1021, `drag_nil` 0: with only its own 'pulldrag' gate armed the shipped
--     function answers a NON-NIL drag destination on EVERY frame, computed off
--     a lane id the engine cannot resolve. That is the lever.
--
-- ⭐⭐ THE REPAIR IS THE FUNCTION'S OWN DECLARED POLICY. Sixteen lines above
-- the guard, the shipped header already says the function "returns nil -- and
-- the caller then walks home-ward exactly as shipped -- when ... the engine
-- cannot say where the lane is. An engine that cannot answer must never
-- redirect a pull into the fog." LANE_NONE *is* the engine saying it cannot
-- say where the lane is. Nothing new is decided by 'dragnolane'; the declared
-- policy simply had no implementation on the value the engine uses to say it.
--
-- ⛔ WHAT THE CORPUS CANNOT SAY, said here rather than left for the wave (GH
-- #622's question, asked in advance). `drag_nonnil` 1021 is PARTLY a statement
-- about the loader: the mock answers Vector(0,0,0) for GetLocationAlongLane at
-- any lane id, and lane assignment is bot-VM state absent from the .dem (the
-- census's STOPPER 4). If the real engine answers nil for lane 0, the 21
-- samples produce an empty path, `#tPath >= 2` is false, and the shipped code
-- ALREADY degrades to nil -- the repair is then inert. It bites in exactly the
-- other case. What the corpus DOES settle, loader-independently, is that the
-- shipped guard cannot fire (`lane_nil` 0 / 1021 vs `lane_none` 1021 / 1021),
-- so the declared policy is unimplemented either way. GH #652 therefore
-- recommends promoting 'dragnolane' WITH 'pulldrag' rather than buying it a
-- wave, which would risk the 'pullcad' reading ("tested, no effect" while
-- check_armed_wiring.py says WIRED).
--
-- ⭐⭐⭐ THE SHARED PREDICATE IS THE POINT OF THE ROUND, not the one call site.
-- J.IsLaneAssigned is pure -- no gate, no side effect -- so the next two sites
-- become a call rather than a fourth copy of the constant, and section 2 below
-- RATCHETS the fact that they still carry the defect: a round that quietly
-- deletes one of those guards without pricing it goes red here.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local tests = {}

-- ------------------------------------------------------------- source reads --

local function jmz_source()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

local function body_of(name)
    local src = jmz_source()
    local at = assert(src:find('function ' .. name, 1, true), name .. ' moved')
    local fin = assert(src:find('\nend\n', at, true), name .. ' has no end')
    return src:sub(at, fin)
end

-- Comments are stripped before every structural read below: a claim about what
-- the CODE does must not be satisfiable by prose describing it. (The header of
-- J.GetLanePullDragTarget quotes 'dragnolane' and LANE_NONE several times.)
local function code_of(name)
    return (body_of(name):gsub('%-%-[^\n]*', ''))
end

-- ------------------------------------------------------------- the manifest --

local manifest_cache = nil

local function manifest()
    if manifest_cache then return manifest_cache end
    local p = assert(io.popen('lua5.1 tests/_pullcamp_sweep.lua 2>&1'),
        'could not start tests/_pullcamp_sweep.lua')
    local raw = p:read('*a')
    p:close()
    local m = { C = {}, DRG = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local kind = line:match('^(%S+)')
        if kind == 'C' then
            local k, n = line:match('^C (%S+) (%-?%d+)$')
            if k then m.C[k] = tonumber(n) end
        elseif kind == 'DRG' then
            local fx, hero, t, lane = line:match('^DRG (%S+) (%S+) (%S+) (%S+)$')
            table.insert(m.DRG, { fixture = fx, hero = hero,
                t = tonumber(t), lane = lane })
        elseif kind == 'DONE' then
            m.done = true
        end
    end
    assert(m.done, 'the corpus sweep did not finish -- run '
        .. '`lua5.1 tests/_pullcamp_sweep.lua` by hand to see why:\n'
        .. raw:sub(1, 800))
    manifest_cache = m
    return m
end

local function C(key)
    local n = manifest().C[key]
    assert(n ~= nil, 'the sweep did not report counter ' .. key)
    return n
end

-- =============================================== 1. the shared predicate

tests['[GH #652] J.IsLaneAssigned compares against the CONSTANT, not a 0'] =
function()
    local code = code_of('J.IsLaneAssigned')
    assert(code:find('LANE_NONE', 1, true),
        'J.IsLaneAssigned no longer names LANE_NONE -- a literal 0 here is the '
        .. 'M10 shape: byte-identical readings, and only the source pin can see '
        .. 'that the constant stopped being consulted')
    assert(code:find('nLane == nil', 1, true),
        'J.IsLaneAssigned stopped rejecting nil -- the guards it replaces all '
        .. 'did, and a predicate named "is a lane assigned" that answered true '
        .. 'for nil is wrong in the one direction that matters')
end

tests['[GH #652] J.IsLaneAssigned is PURE -- no gate lives inside it'] =
function()
    -- The whole reason the predicate can be shared by three sites with three
    -- different soak candidates is that it decides nothing about arming. If a
    -- gate ever migrates in here, the next site to adopt it inherits an
    -- unrelated candidate id silently.
    local code = code_of('J.IsLaneAssigned')
    assert(not code:find('IsSoakCandidate', 1, true),
        'a soak gate moved INSIDE J.IsLaneAssigned')
    assert(not code:find('IsModeTurbo', 1, true),
        'the turbo gate moved INSIDE J.IsLaneAssigned')
    assert(not code:find('IsLaneFixOn', 1, true),
        'a lanefix gate moved INSIDE J.IsLaneAssigned')
end

tests['[GH #652] real frame: LANE_NONE reads false, a real lane reads true'] =
function()
    -- Driven on a real frame rather than a hand-built bot: the corpus answers
    -- LANE_NONE everywhere (STOPPER 4), which is exactly the input the shipped
    -- guards mishandle.
    local J, bot = rf.load(manifest().DRG[1].fixture, manifest().DRG[1].hero)
    assert(bot:GetAssignedLane() == LANE_NONE,
        'the witness frame no longer reads LANE_NONE')
    assert(J.IsLaneAssigned(bot) == false,
        'J.IsLaneAssigned answered true on a LANE_NONE frame')

    -- Both directions, so a re-sentinelled LANE_NONE (or a predicate that just
    -- returns false) goes red instead of going quiet.
    bot.GetAssignedLane = function() return LANE_MID end
    assert(J.IsLaneAssigned(bot) == true,
        'J.IsLaneAssigned answered false for LANE_MID -- it is not reading the '
        .. 'lane, it is returning a constant')
    bot.GetAssignedLane = function() return nil end
    assert(J.IsLaneAssigned(bot) == false, 'nil lane no longer reads false')
    assert(J.IsLaneAssigned(nil) == false, 'a nil bot no longer reads false')
end

-- ===================================== 2. the other three sites, ratcheted

tests['[GH #652] the two unpicked sites still carry the defect'] = function()
    -- This is the ratchet the round exists to leave behind. Both readings in
    -- section 3 are claims ABOUT THESE TWO GUARDS; if a later round deletes or
    -- rewrites one without re-pricing it, the claims here would keep passing
    -- against code that no longer exists. So pin the shape itself.
    local a = code_of('J.ShouldLaneRecoverFarm')
    assert(a:find('nLane ~= nil', 1, true),
        'J.ShouldLaneRecoverFarm no longer guards on `nLane ~= nil` -- if that '
        .. 'is a repair, re-price it (GH #652 measured 0 frames reaching it)')
    local b = code_of('J.ShouldCreepPullLane')
    assert(b:find('nLane ~= nil', 1, true),
        'J.ShouldCreepPullLane no longer guards on `nLane ~= nil` -- if that is '
        .. 'a repair, re-price it; and note that helper is PROMOTED, so the '
        .. 'change is live in every turbo game')
    assert(b:find('GetLaneFrontAmount', 1, true),
        "the symmetry argument for site B's zero reads GetLaneFrontAmount for "
        .. 'both teams; that call is gone')
end

tests['[GH #652] the picked site is gated, turbo-scoped, and calls the helper']
= function()
    local code = code_of('J.GetLanePullDragTarget')
    assert(code:find("IsSoakCandidate%(%s*'dragnolane'%s*%)"),
        "J.GetLanePullDragTarget no longer gates the repair on 'dragnolane'")
    assert(code:find('not J.IsLaneAssigned', 1, true),
        'the repair no longer calls the shared predicate')
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared from J.GetLanePullDragTarget')
    -- Order matters and counting cannot see it (the M3 shape): a guard moved
    -- BELOW the lane sampler still names its id, still compares correctly, and
    -- still passes every existence check above -- while doing nothing.
    local at_gate = assert(code:find('dragnolane', 1, true))
    local at_use = assert(code:find('GetLocationAlongLane', 1, true))
    assert(at_gate < at_use,
        "the 'dragnolane' guard now sits BELOW the lane sampler it exists to "
        .. 'keep from running')
end

-- ============================================== 3. the pricing, per site

tests['[GH #652] the pricing columns still ASK, they do not assert'] =
function()
    -- The M10 shape, one level up. `alongline_nonnil` reads 1021 and so does
    -- an unconditional `bump()` -- a column that stopped consulting the engine
    -- ("we already know it always answers") is byte-identical in every count
    -- in the manifest, and no assertion over those counts can see it. Only a
    -- source pin can.
    local fh = assert(io.open('tests/_pullcamp_sweep.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    assert(s:find("if GetLocationAlongLane(lane, 0.5) ~= nil then", 1, true),
        "the sweep's alongline_nonnil column no longer asks the lane sampler")
    assert(s:find('GetLaneFrontAmount(GetTeam(), lane, false)', 1, true)
        and s:find('GetLaneFrontAmount(GetOpposingTeam(), lane, false)', 1, true),
        "the sweep's site-B columns no longer read both teams' lane fronts "
        .. 'with the same lane id -- the symmetry argument is what the zero '
        .. 'means')
    assert(s:find('pcall(J.GetLanePullDragTarget, bot, loc)', 1, true),
        'the sweep no longer drives the SHIPPED J.GetLanePullDragTarget -- a '
        .. 'column that re-implements the function measures the re-implementation')
    assert(s:find('pcall(J.ShouldLaneRecoverFarm, bot)', 1, true),
        'the sweep no longer drives the shipped J.ShouldLaneRecoverFarm')
end

tests['[GH #652] site A: no frame reaches its lane block'] = function()
    cs.ratchet(C('frames'), 1021, 'alive hero frames')
    -- The population closes: every frame either raised at the refused call or
    -- returned false above it. A pair of numbers that did not add up to the
    -- corpus would mean some third path exists and the "0 reach" claim is
    -- about a subset nobody named.
    assert(C('lrf_raise') + C('lrf_false') + C('lrf_true') == C('frames'),
        'site A drive does not account for every frame: '
        .. C('lrf_raise') .. ' + ' .. C('lrf_false') .. ' + ' .. C('lrf_true')
        .. ' vs ' .. C('frames'))
    cs.universal(C('lrf_raise_lanefront'), C('lrf_raise'),
        'site A raises that name the refused lane call')
    assert(C('lrf_true') == 0,
        'J.ShouldLaneRecoverFarm now answers true somewhere -- the "0 frames '
        .. 'reach the lane block" pricing must be re-taken')
end

tests['[GH #652] site B: the two lane-front reads never differ'] = function()
    cs.universal(C('frontamt_both_nonnil'), C('frames'),
        'frames where both lane-front reads answer')
    -- Kept as an equality on purpose (corpus_scale: a claim whose whole content
    -- is a zero is already growth-immune, and it is what the "measured no-op"
    -- verdict for site B is argued from). A new fixture that makes the two
    -- reads differ MUST turn this red.
    assert(C('frontamt_differs') == 0,
        'the two lane-front reads now differ on ' .. C('frontamt_differs')
        .. ' frame(s) -- site B is no longer a measured no-op, re-price it')
    assert(C('frontamt_pushed') == 0,
        'bWavePushedToUs is now reachable on ' .. C('frontamt_pushed')
        .. ' frame(s) -- re-price site B before touching it')
end

tests['[GH #652] site C: the shipped function answers off an unresolved lane'] =
function()
    cs.universal(C('alongline_nonnil'), C('frames'),
        'frames where the lane sampler answers at LANE_NONE')
    cs.universal(C('drag_nonnil'), C('frames'),
        'frames where the disarmed function returns a drag destination')
    assert(C('drag_nil') == 0 and C('drag_raise') == 0,
        'the disarmed drive no longer answers on every frame ('
        .. C('drag_nil') .. ' nil, ' .. C('drag_raise') .. ' raises)')
end

-- ======================================= 4. the differential, and its sign

tests['[GH #652] armed, the same function returns nil on the same frames'] =
function()
    cs.universal(C('drag2_nil'), C('frames'),
        'frames where the armed function returns nil')
    assert(C('drag2_nonnil') == 0 and C('drag2_raise') == 0,
        'armed, the function still answers non-nil on ' .. C('drag2_nonnil')
        .. ' frame(s) (' .. C('drag2_raise') .. ' raises)')
    -- The differential closes over the whole population that reaches the
    -- clause -- not "some frames changed", but "every frame that had an answer
    -- lost it".
    assert(C('drag_closes') == C('drag_nonnil'),
        'the differential does not cover the population: drag_closes '
        .. C('drag_closes') .. ' vs drag_nonnil ' .. C('drag_nonnil'))
    -- The forbidden direction. A guard can only ever REMOVE a destination.
    assert(C('drag_opens') == 0,
        "'dragnolane' produced a drag destination where the shipped code had "
        .. 'none, on ' .. C('drag_opens') .. ' frame(s)')
    -- ...and a column of zeros cannot tell "the direction holds" from "the
    -- tally never ran", which is why drag_closes above is driven by the same
    -- frames and must be the whole population.
    assert(#manifest().DRG == C('drag_closes'),
        'the witness lines and the counter disagree (' .. #manifest().DRG
        .. ' vs ' .. C('drag_closes') .. ')')
end

tests['[GH #652] GH #648 readings are not perturbed by this round'] =
function()
    -- 'pullnolane' lives in a different function, but both are driven by the
    -- same sweep on the same frames, and its differential is the evidence GH
    -- #648 is banked on. If this round moved it, the two rounds are no longer
    -- independent measurements.
    cs.ratchet(C('guard_closes'), 18, "'pullnolane' frames closed")
    assert(C('guard_opens') == 0, "'pullnolane' now opens somewhere")
    assert(C('lane_nil') == 0,
        'the corpus now reads a nil lane -- the whole family argument changes')
    cs.universal(C('lane_none'), C('frames'), 'frames reading LANE_NONE')
end

-- ============================================= 5. gate plumbing, unarmed

tests['[GH #652] disarmed and outside turbo, nothing this round changed'] =
function()
    local w = manifest().DRG[1]
    -- Armed 'dragnolane' ALONE, with 'pulldrag' disarmed: the function must
    -- still early-out on its own gate, so the repair cannot leak into a tree
    -- where its host candidate is off.
    local J, bot = rf.load(w.fixture, w.hero)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(sId) return sId == 'dragnolane' end
    local ok, v = pcall(J.GetLanePullDragTarget, bot, bot:GetLocation())
    assert(ok and v == nil, "'dragnolane' armed alone changed the answer with "
        .. "'pulldrag' disarmed")

    -- Outside turbo, with everything armed.
    local J2, bot2 = rf.load(w.fixture, w.hero)
    J2.IsModeTurbo = function() return false end
    J2.IsSoakCandidate = function() return true end
    local ok2, v2 = pcall(J2.GetLanePullDragTarget, bot2, bot2:GetLocation())
    assert(ok2 and v2 == nil, 'non-turbo no longer early-outs to nil')

    -- And the live default: turbo, nothing armed at all.
    local J3, bot3 = rf.load(w.fixture, w.hero)
    J3.IsModeTurbo = function() return true end
    J3.IsSoakCandidate = function() return false end
    local ok3, v3 = pcall(J3.GetLanePullDragTarget, bot3, bot3:GetLocation())
    assert(ok3 and v3 == nil,
        'the shipped default no longer returns nil with nothing armed')
end

return tests
