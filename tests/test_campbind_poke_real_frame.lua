-- [ratchet] [replay-check] Condition (a) for the soak candidate `campbind`, bought on a
-- REAL FRAME instead of a wave's aggregate.  Claims
-- `owed_executions.json:campbind_condition_a_fixture`, exit (甲).
--
-- WHY THIS FILE EXISTS
--
-- `campbind` was RETURNED_FROM_ARMED_SET on 2026-09-07 (test_set.md §FX) with
-- disposition DOMAIN-NOT-REACHED-IN-WAVES: across two independent corpora and
-- 97 games the readable surface (planned camp /= nearest camp) came up 1, and
-- that single instant could not be ATTRIBUTED -- the displacement instrument
-- needed 250u of camp movement and measured 12-176u.  The ruling therefore
-- moved condition (a) off wave corpora and onto a fixture, and named the
-- instant: `20260904_125801_slot6` spirit_breaker, t = 330.7 and t = 334.7.
-- A fixture asserts the DECISION, so it needs no displacement attribution at
-- all; the 250u threshold that defeated the wave instrument does not exist here.
--
-- THE FRAME IS THE ONE THE RULING NAMED, AND IT IS REAL
--
-- Source .dem recovered 2026-09-17 from the 21-day bulk prefix
-- `dem21/spot_20260904_123127_1_efa7ba70095a9151930e8b1b96a9d16449c1a1f3_b77771/`
-- (W46's second run; the `soak/<run>/` archive keeps no .dem at REC_SLOTS>1).
-- Dumped at `-creep-interval 0.25`, so both fixtures carry a neutral sample
-- dt = 0.1 from the instant rather than the wave farm's 3.0s default.
-- Combat log at the two instants, verbatim from the dump's `events`:
--     330.7  DAMAGE spirit_breaker -> npc_dota_neutral_forest_troll_berserker
--     334.7  DAMAGE spirit_breaker -> npc_dota_neutral_kobold_taskmaster
-- i.e. the shipped poke hit two DIFFERENT camps four seconds apart -- which is
-- the behaviour `campbind` exists to stop.
--
-- WHY tNeut IS BUILT HERE AND NOT TAKEN FROM bot:GetNearbyNeutralCreeps
--
-- tests/mock/replay_fixture.lua synthesises neutral handles out of the
-- subject's `recent_damage` rows and gives every one of them the SUBJECT'S OWN
-- location (loader, `tOpts.neutrals` branch).  Every neutral is then at
-- distance 0 from the bot and from each other, so a decision whose whole
-- content is "which of these neutrals is near the planned camp" cannot be
-- asked through that path -- it is instrument-blind in exactly the §FW.2 sense.
-- The fixture's own `creeps` block is the real datum: team 4, real x/y, no
-- name and no health (all a .dem carries).  This file therefore builds tNeut
-- from that block, applying the engine's two documented properties of
-- `GetNearby*`: the radius filter (the call site asks 1400) and "sorted by
-- distance, closest first" (docs/BOT_API_REFERENCE.md:1229).  The ORDER is
-- stated, not dumped -- a .dem carries no list order -- and §7 records what
-- that does and does not license.
--
-- WHAT THE FRAME TURNED OUT TO SAY (and it is two different things)
--
--   t = 330.7  The two camps PARTITION under the helper's own radius: all 6
--              troll-camp neutrals are inside 1200 of the troll box and
--              outside 1200 of the kobold box, all 4 kobold-camp neutrals the
--              other way, and ZERO units are inside both.  Plan the kobold
--              camp and the helper answers a kobold while tNeut[1] is a troll
--              194u away -- a different box, which is the assertion the owed
--              row asks for, and the lever deciding correctly.
--   t = 334.7  The partition is GONE, and not because the camps moved: three
--              units sit inside 1200 of both boxes.  The nearest neutral to
--              the bot (175.6u) is one of them, and a backward nearest
--              neighbour trace through the 0.25s samples puts it, at 330.7, at
--              (-3953.4, 4818.3) -- 34.6u from the troll box, 1295.8u from the
--              kobold box, and MOTIONLESS there for the preceding 3 seconds.
--              It is a forest troll that has been dragged.  So under a kobold
--              plan the armed helper hands back a TROLL: the unit the lever
--              was written to exclude, admitted because "belongs to the
--              planned camp" is implemented as "within 1200u of a point", and
--              a neutral dragged out of the other camp satisfies that.
--
-- §6 pins that leak.  It is a defect of the PREDICATE, not of this frame: the
-- proof that the admitted unit belongs to the other camp is the trace, and the
-- trace does not depend on which camp was actually planned.  Which camp WAS
-- planned is not recoverable -- `bot.roamCampPull` comes from
-- GetNeutralSpawners(), engine map data no .dem carries -- so every section
-- below states its vCamp instead of guessing one, and §7 says so.
--
-- WHAT THIS FILE DOES NOT CLAIM
--   * Not that the armed side is better here.  Condition (b) is the batch's
--     question and §FX.4 already read it as noise.
--   * Not that the poke frames reached this helper.  The call site sits behind
--     bot.roamCampPull ~= nil and a 3s throttle, neither of which a dump
--     carries; the combat log shows the pokes landing, which is as close as
--     this corpus gets.
--   * Not a monotonicity failure.  The armed answer is still always a member
--     of tNeut, so the poked set stays a subset of the shipped one.  What §6
--     falsifies is the BINDING claim ("poke the camp we planned"), not the
--     safety argument.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local F_3307 = 'tests/frames/f_260904_125801_campbind_poke_3307.lua'
local F_3347 = 'tests/frames/f_260904_125801_campbind_poke_3347.lua'

local PULL_CAMP_NEUTRAL_RANGE = 1200 -- jmz_func.lua, the helper's own constant
local NEUT_QUERY_RADIUS = 1400       -- mode_roam_generic.lua's GetNearbyNeutralCreeps(1400)

local tests = {}

-- Load a fixture with the game forced to Turbo and one soak id armed.
-- GetGameMode must be set BEFORE rf.load, because the loader re-requires
-- jmz_func and J.IsModeTurbo memoises its answer on first call.
local function load_frame(sPath, sArmed)
    GAMEMODE_TURBO = 23                            -- luacheck: ignore
    GetGameMode = function() return 23 end         -- luacheck: ignore
    local J, bot, heroes, fx = rf.load(sPath)
    J.IsSoakCandidate = function(id) return sArmed ~= nil and id == sArmed end
    return J, bot, heroes, fx
end

local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

-- The subject's own position, read off the fixture rather than hand-copied.
local function subject_xy(fx)
    for _, u in ipairs(fx.units) do
        if u.name == fx.self then return u.x, u.y end
    end
    error('subject not in fixture units')
end

-- tNeut as the call site would receive it: team-4 creeps inside the query
-- radius, nearest first.  Each handle answers the four predicates J.IsValid
-- reads (the mock defaults every Is*/Can* to FALSE, so they are set here) plus
-- GetLocation, which is the only thing the helper itself calls.
local function neutrals_within(J, fx, bx, by, nRadius)
    local api = require('mock.bot_api')
    local rows = {}
    for _, c in ipairs(fx.creeps or {}) do
        if c.team == 4 then
            local d = dist(c.x, c.y, bx, by)
            if d <= nRadius then rows[#rows + 1] = { d = d, x = c.x, y = c.y } end
        end
    end
    table.sort(rows, function(a, b)
        if a.d == b.d then
            if a.x == b.x then return a.y < b.y end
            return a.x < b.x
        end
        return a.d < b.d
    end)
    local out = {}
    for i, r in ipairs(rows) do
        out[i] = api.MakeUnit({
            GetUnitName = 'npc_dota_neutral_unknown',
            GetTeam = 4,
            GetLocation = api.Vector(r.x, r.y, 0),
            IsNull = false,
            IsAlive = true,
            IsBuilding = false,
            CanBeSeen = true,
        })
        -- carry the raw numbers alongside, for the assertions
        out[i].__xy = { x = r.x, y = r.y, d = r.d }
    end
    assert(J.IsValid(out[1]), 'the synthesised neutral passes J.IsValid')
    return out
end

-- Single-link clustering at 600u: the camp boxes on this frame are far tighter
-- than that (max spread 73.6u) and far further apart (centroids 1310u), so the
-- threshold is not a tuned number -- any value in (150, 1200) gives the same
-- two clusters.  §1 asserts that separation rather than assuming it.
local function cluster(tNeut, nLink)
    local cl = {}
    for _, h in ipairs(tNeut) do
        local p = h.__xy
        local hit = nil
        for _, c in ipairs(cl) do
            for _, q in ipairs(c) do
                if dist(p.x, p.y, q.x, q.y) < nLink then hit = c break end
            end
            if hit then break end
        end
        if hit then hit[#hit + 1] = p else cl[#cl + 1] = { p } end
    end
    local out = {}
    for i, c in ipairs(cl) do
        local sx, sy = 0, 0
        for _, p in ipairs(c) do sx, sy = sx + p.x, sy + p.y end
        out[i] = { n = #c, x = sx / #c, y = sy / #c, pts = c }
    end
    return out
end

-- The two camp boxes, measured on the 330.7 frame where both camps are AT REST.
-- Returned as {troll, kobold}: the troll box is the one the subject is standing
-- next to at 330.7 (and the one the combat log says it hit at that instant).
local function camp_boxes()
    local J, _, _, fx = load_frame(F_3307, 'campbind')
    local bx, by = subject_xy(fx)
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    local cl = cluster(tNeut, 600)
    assert(#cl == 2, 'two camps on the 330.7 frame, got ' .. #cl)
    local a, b = cl[1], cl[2]
    if dist(a.x, a.y, bx, by) > dist(b.x, b.y, bx, by) then a, b = b, a end
    return a, b -- near box (forest trolls), far box (kobolds)
end

tests['§1 the 330.7 frame: two camps, and the helper radius separates them exactly'] = function()
    local J, _, _, fx = load_frame(F_3307, 'campbind')
    local bx, by = subject_xy(fx)
    assert(fx.self == 'npc_dota_hero_spirit_breaker', 'subject is spirit_breaker')
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    assert(#tNeut == 10, '10 neutrals inside the 1400 query, got ' .. #tNeut)

    local troll, kobold = camp_boxes()
    assert(troll.n == 6, 'near box holds 6 neutrals, got ' .. troll.n)
    assert(kobold.n == 4, 'far box holds 4 neutrals, got ' .. kobold.n)
    local sep = dist(troll.x, troll.y, kobold.x, kobold.y)
    assert(sep > PULL_CAMP_NEUTRAL_RANGE,
        string.format('box separation %.1f exceeds the helper radius %d', sep,
            PULL_CAMP_NEUTRAL_RANGE))

    -- The partition, which is what makes this frame readable at all: no unit
    -- is inside 1200 of both boxes.  (t = 334.7 loses exactly this -- §6.)
    local nBoth = 0
    for _, h in ipairs(tNeut) do
        local p = h.__xy
        if dist(p.x, p.y, troll.x, troll.y) <= PULL_CAMP_NEUTRAL_RANGE
            and dist(p.x, p.y, kobold.x, kobold.y) <= PULL_CAMP_NEUTRAL_RANGE then
            nBoth = nBoth + 1
        end
    end
    assert(nBoth == 0, 'no neutral is inside 1200 of both boxes, got ' .. nBoth)
end

tests['§2 shipped (gate off) pokes tNeut[1] -- the nearest neutral, troll box'] = function()
    local J, _, _, fx = load_frame(F_3307, nil) -- nothing armed
    local bx, by = subject_xy(fx)
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    local troll, kobold = camp_boxes()

    -- Under the shipped path the planned camp is passed but ignored, so the
    -- answer must be tNeut[1] whichever camp is handed in.
    for _, vCamp in ipairs({ troll, kobold }) do
        local h = J.GetCampPullPokeTarget(tNeut, Vector(vCamp.x, vCamp.y, 0))
        assert(h == tNeut[1], 'shipped answers tNeut[1] regardless of the plan')
    end
    local p = tNeut[1].__xy
    assert(dist(p.x, p.y, troll.x, troll.y) <= PULL_CAMP_NEUTRAL_RANGE,
        'tNeut[1] belongs to the troll box')
    assert(dist(p.x, p.y, kobold.x, kobold.y) > PULL_CAMP_NEUTRAL_RANGE,
        'tNeut[1] does NOT belong to the kobold box')
end

tests['§3 THE OWED ASSERTION: armed on the kobold plan answers a different box than tNeut[1]'] = function()
    local J, _, _, fx = load_frame(F_3307, 'campbind')
    local bx, by = subject_xy(fx)
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    local troll, kobold = camp_boxes()

    local h = J.GetCampPullPokeTarget(tNeut, Vector(kobold.x, kobold.y, 0))
    assert(h ~= nil, 'armed finds a poke target on the planned camp')
    assert(h ~= tNeut[1], 'armed does NOT answer the nearest neutral')

    local p, q = h.__xy, tNeut[1].__xy
    -- the returned unit is in the planned box ...
    assert(dist(p.x, p.y, kobold.x, kobold.y) <= PULL_CAMP_NEUTRAL_RANGE,
        'the answer belongs to the PLANNED (kobold) box')
    -- ... and tNeut[1] is in the other one: two different boxes, which is the
    -- readable surface §FX.4 measured as 1 (unattributable) over 97 games.
    assert(dist(q.x, q.y, troll.x, troll.y) <= PULL_CAMP_NEUTRAL_RANGE,
        'tNeut[1] belongs to the NEAREST (troll) box')
    assert(dist(p.x, p.y, q.x, q.y) > PULL_CAMP_NEUTRAL_RANGE,
        'the two units are further apart than the helper radius')
end

tests['§4 armed on the troll plan reproduces the shipped answer (the other assignment)'] = function()
    -- Which camp J.ShouldPullNeutralCamp actually planned is not recoverable
    -- from a .dem, so both assignments are asserted rather than one guessed.
    local J, _, _, fx = load_frame(F_3307, 'campbind')
    local bx, by = subject_xy(fx)
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    local troll = camp_boxes()
    local h = J.GetCampPullPokeTarget(tNeut, Vector(troll.x, troll.y, 0))
    assert(h == tNeut[1], 'on the near plan the armed answer is the shipped one')
end

tests['§5 outside Turbo the lever is inert on this same frame'] = function()
    -- ORDER IS LOAD-BEARING, and it cost this file one red run.  camp_boxes()
    -- loads a fixture of its own, and load_frame() re-arms the Turbo globals
    -- while doing so; J.IsModeTurbo reads those globals at CALL time (its
    -- memo is per-module and unset until first use).  Measuring the boxes
    -- after switching to non-Turbo therefore switches Turbo back on under the
    -- handle this section is holding, and the assertion below fails for a
    -- reason that has nothing to do with the lever.  Boxes first.
    --
    -- AND THE MODE MUST BE SET AFTER THE LOAD, NOT BEFORE -- that cost two
    -- more red runs, and the measurement is the only reason this file knows
    -- it.  tests/mock/replay_fixture.lua ends with
    -- `GetGameMode = function() return GAMEMODE_TURBO end`, i.e. EVERY fixture
    -- world is Turbo by construction and any pre-load assignment is
    -- overwritten.  (Nor does `GAMEMODE_TURBO = nil` say "not Turbo":
    -- J.IsModeTurbo consults GetGameMode only when both that function and the
    -- constant exist, and without the constant it falls through to the
    -- courier-speed heuristic.)  Setting it after the load is safe because
    -- J.IsModeTurbo memoises on FIRST CALL and nothing has called it yet.
    -- ⚠ `print` is hijacked in this harness -- debug through io.stderr.
    local troll, kobold = camp_boxes()
    local J, _, _, fx = rf.load(F_3307)
    GAMEMODE_TURBO = 23                             -- luacheck: ignore
    GetGameMode = function() return 22 end          -- luacheck: ignore
    J.IsSoakCandidate = function(id) return id == 'campbind' end
    local bx, by = subject_xy(fx)
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    local h = J.GetCampPullPokeTarget(tNeut, Vector(kobold.x, kobold.y, 0))
    assert(h == tNeut[1], 'non-Turbo answers tNeut[1] even with the id armed')
    assert(troll ~= nil)
end

tests['§6 BUGGY at t=334.7: the planned-camp test admits a neutral from the OTHER camp'] = function()
    local troll, kobold = camp_boxes() -- boxes measured on the at-rest 330.7 frame
    local J, _, _, fx = load_frame(F_3347, 'campbind')
    local bx, by = subject_xy(fx)
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    assert(#tNeut == 10, '10 neutrals inside the 1400 query at 334.7, got ' .. #tNeut)

    -- (a) the partition §1 asserted is gone: units now satisfy BOTH boxes.
    local nBoth = 0
    for _, h in ipairs(tNeut) do
        local p = h.__xy
        if dist(p.x, p.y, troll.x, troll.y) <= PULL_CAMP_NEUTRAL_RANGE
            and dist(p.x, p.y, kobold.x, kobold.y) <= PULL_CAMP_NEUTRAL_RANGE then
            nBoth = nBoth + 1
        end
    end
    assert(nBoth == 3, 'three neutrals are inside 1200 of both boxes, got ' .. nBoth)

    -- (b) and the FIRST such unit is tNeut[1], so under the kobold plan the
    -- armed helper hands back the nearest neutral -- the shipped answer.
    local h = J.GetCampPullPokeTarget(tNeut, Vector(kobold.x, kobold.y, 0))
    assert(h == tNeut[1], 'armed answers tNeut[1]: the binding did not bind')

    -- (c) and that unit is provably NOT a kobold.  At 330.7 it stood at
    -- (-3953.4, 4818.3): 34.6u from the troll box, 1295.8u from the kobold
    -- box, motionless for the preceding 3s.  The fixture carries no ids, so
    -- what is asserted here is the consequence that made the trace possible --
    -- no unit at 330.7 was anywhere near where this one now is, i.e. it walked.
    local p = h.__xy
    local _, _, fx0 = load_frame(F_3307, 'campbind')
    local nNearIts330Spot = 0
    for _, c in ipairs(fx0.creeps or {}) do
        if c.team == 4 and dist(c.x, c.y, p.x, p.y) <= 250 then
            nNearIts330Spot = nNearIts330Spot + 1
        end
    end
    assert(nNearIts330Spot == 0,
        'at 330.7 no neutral stood within 250u of where the admitted unit now is')
    -- the 330.7 position the trace lands on is inside the troll box and
    -- outside the kobold box, which is what makes it a dragged troll.
    assert(dist(-3953.4, 4818.3, troll.x, troll.y) <= PULL_CAMP_NEUTRAL_RANGE,
        'the traced origin is inside the troll box')
    assert(dist(-3953.4, 4818.3, kobold.x, kobold.y) > PULL_CAMP_NEUTRAL_RANGE,
        'the traced origin is outside the kobold box')
end

tests['§7 LIMIT: the list order is stated, and the plan is not recoverable'] = function()
    -- (i) A .dem carries no list order.  tNeut here is sorted nearest-first on
    -- the engine's documented promise; the helper walks it with `pairs` and
    -- returns the FIRST member inside the radius, so the answer of §6 depends
    -- on that order while §3's does not (there, the troll box is excluded
    -- wholesale, so every order gives a kobold).  Pin the asymmetry so the day
    -- someone changes the ordering rule this file says which half moved.
    local J, _, _, fx = load_frame(F_3307, 'campbind')
    local bx, by = subject_xy(fx)
    local tNeut = neutrals_within(J, fx, bx, by, NEUT_QUERY_RADIUS)
    local _, kobold = camp_boxes()
    local nInPlan = 0
    for _, h in ipairs(tNeut) do
        local p = h.__xy
        if dist(p.x, p.y, kobold.x, kobold.y) <= PULL_CAMP_NEUTRAL_RANGE then
            nInPlan = nInPlan + 1
        end
    end
    assert(nInPlan == 4, 'exactly the kobold box is eligible at 330.7, any order')

    -- (ii) The planned camp comes from GetNeutralSpawners(), which is engine
    -- map data; no fixture can carry it.  Assert that the helper reads vCamp
    -- and nothing else about the plan, which is what licenses §3/§4 asserting
    -- both assignments instead of one.
    local h = J.GetCampPullPokeTarget(tNeut, nil)
    assert(h == tNeut[1], 'a nil plan falls back to the shipped answer')
    assert(J.GetCampPullPokeTarget({}, Vector(0, 0, 0)) == nil, 'empty list -> nil')
    assert(fx ~= nil)
end

return tests
