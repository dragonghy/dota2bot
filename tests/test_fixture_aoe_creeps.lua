-- [ratchet] [hero] The fixture loader answers `FindAoELocation` for the CREEP
-- search from the fixture's own creep sample -- and refuses, in a named
-- direction, everything it cannot honestly answer.
--
-- Claims the second half of GH #354 section 5.  The first half (hero
-- 2026-08-31T05:02Z) taught `make_fixture.py` to carry the creep sample; that
-- alone changed no decision, because tests/mock/replay_fixture.lua still
-- answered every AoE search with the conservative stand-in `{count = 0}`, and
-- all eight shipped creep return sites in Crystal Maiden's ConsiderQImpl sit
-- behind a `.count >= 2..5` read of it.  So the branch was not "unexercised by
-- the corpus", it was UNREACHABLE BY CONSTRUCTION in every fixture ever
-- generated.  This file pins the loader half.
--
-- WHY A SYNTHETIC WORLD HERE AND A REAL FRAME NEXT DOOR.  This file is the
-- loader's CALIBRATION: it asks questions whose right answer is known by
-- construction (a cluster of exactly three, a creep one unit outside the reach,
-- a layout whose optimum can only sit on the range ring).
-- tests/test_cm_creep_reach_real_frame.lua then drives the real frame through
-- the wired loader and cross-checks the count against that file's own,
-- independently written, minimum-distance solver.  Two solvers, written for
-- different questions, agreeing on one frame.
--
-- WHAT IS DELIBERATELY STILL ZERO (each assertion below names its reason):
--   * the HERO search -- answerable, but every fixture carries heroes, so
--     switching it on moves readings in ~two dozen census tests at once;
--   * the KILL search (`nMaxHealth > 0`) -- the dumper writes {t, team, x, y}
--     and no creep health, so a "creeps this would kill" count does not exist
--     in the input at all;
--   * neutral creeps (team 4) -- whether the engine folds them into an enemy
--     search is not readable from the bot VM, and excluding them undercounts.
-- Each refusal errs the same way the old stand-in did: it understates
-- opportunities rather than inventing them.  A ratchet on the DIRECTION of a
-- refusal is the thing that keeps a later "make it answer something" from
-- quietly turning an upper bound into a claim.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local SUBJ = 'npc_dota_hero_crystal_maiden'
local FOE = 'npc_dota_hero_lion'
local SUBJ_TEAM, FOE_TEAM, NEUTRAL_TEAM = 2, 3, 4

local tmp_paths = {}

--- Write a synthetic fixture in the generator's own shape. `tCreeps` is nil for
--- a pre-creeps (v1/v2) fixture, which must keep the old creep-free world.
local function write_fixture(tCreeps)
    local buf = {}
    buf[#buf + 1] = 'return {\n'
    buf[#buf + 1] = "  game = 'synth', time = 100.0, window = 5.0,\n"
    buf[#buf + 1] = "  self = '" .. SUBJ .. "',\n"
    buf[#buf + 1] = '  units = {\n'
    for _, u in ipairs({ { SUBJ, SUBJ_TEAM, 0.0, 0.0 }, { FOE, FOE_TEAM, 3000.0, 0.0 } }) do
        buf[#buf + 1] = string.format(
            "    { name = '%s', team = %d, x = %.1f, y = %.1f, hp = 600, "
            .. 'max_hp = 600, mp = 500, max_mp = 500, level = 10, alive = true, '
            .. "tp_cd = 0, items = { '', '', '', '', '', '', '', '', '' }, "
            .. 'abilities = {} },\n', u[1], u[2], u[3], u[4])
    end
    buf[#buf + 1] = '  },\n'
    if tCreeps ~= nil then
        buf[#buf + 1] = '  creep_interval = 0.5,\n  creeps = {\n'
        for _, c in ipairs(tCreeps) do
            buf[#buf + 1] = string.format(
                '    { dt = 0.0, team = %d, x = %.1f, y = %.1f },\n',
                c.team, c.x, c.y)
        end
        buf[#buf + 1] = '  },\n'
    end
    buf[#buf + 1] = '  observed = { burst = {}, died_after = nil },\n}\n'

    local path = os.tmpname() .. '.lua'
    local fh = assert(io.open(path, 'w'))
    fh:write(table.concat(buf))
    fh:close()
    tmp_paths[#tmp_paths + 1] = path
    return path
end

local function load_with(tCreeps)
    local _, bot = rf.load(write_fixture(tCreeps))
    return bot
end

--- The shipped call shape: enemies, creeps, from the hero, no health filter.
local function hurt_creeps(bot, nMax, nRadius)
    return bot:FindAoELocation(true, false, bot:GetLocation(), nMax, nRadius, 0.5, 0)
end

local function enemy(x, y) return { team = FOE_TEAM, x = x, y = y } end
local function ally(x, y) return { team = SUBJ_TEAM, x = x, y = y } end
local function neutral(x, y) return { team = NEUTRAL_TEAM, x = x, y = y } end

local function dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

--- How many of `tCreeps` (of team `nTeam`) a radius-`r` disk at (qx,qy) covers.
local function covered(tCreeps, nTeam, qx, qy, r)
    local n = 0
    for _, c in ipairs(tCreeps) do
        if c.team == nTeam and dist(qx, qy, c.x, c.y) <= r + 1e-6 then n = n + 1 end
    end
    return n
end

-- =====================================================================
-- §1  A fixture without a creep sample keeps its old world
-- =====================================================================

tests['§1 no creeps key: the loader still answers the conservative stand-in'] = function()
    local bot = load_with(nil)
    local r = hurt_creeps(bot, 1157, 425)
    assert(r.count == 0, 'a pre-creeps fixture must read exactly as before: ' .. r.count)
    assert(r.targetloc ~= nil, 'and must still hand back a point to index')
    -- The reason this matters beyond nostalgia: no fixture under
    -- tests/fixtures/ carries a creep sample today, so this branch is the one
    -- the entire census corpus takes. If it ever stops being count = 0, every
    -- reading taken over that corpus moves at once.
end

tests['§1 an empty creep list is not a claim that the field was empty'] = function()
    local bot = load_with({})
    assert(hurt_creeps(bot, 1157, 425).count == 0,
        'zero samples answers like no samples, not like an empty battlefield')
end

-- =====================================================================
-- §2  The creep search, answered from the sample
-- =====================================================================

tests['§2 a real cluster is found, and the point it returns really covers it'] = function()
    local tCreeps = { enemy(600, 0), enemy(700, 60), enemy(650, -80) }
    local bot = load_with(tCreeps)
    local r = hurt_creeps(bot, 1157, 425)
    assert(r.count == 3, 'all three creeps fit one 425 disk: got ' .. r.count)
    -- Not "a number came back": the POINT must be legal and must actually
    -- cover that many. This is the self-check that makes over-counting
    -- impossible to pass off, whatever the candidate set does.
    assert(dist(0, 0, r.targetloc.x, r.targetloc.y) <= 1157 + 1e-6,
        'the centre must be inside nMaxDistanceFromBase')
    assert(covered(tCreeps, FOE_TEAM, r.targetloc.x, r.targetloc.y, 425) == 3,
        'the returned centre must cover the count it reports')
end

tests['§2 the count is the MAXIMUM, not the first cluster it walks into'] = function()
    -- Two clusters, the near one smaller. A search that stopped at the first
    -- coverable creep would answer 2.
    local tCreeps = { enemy(500, 0), enemy(560, 40),
                      enemy(-900, 0), enemy(-980, 60), enemy(-940, -70), enemy(-1000, -20) }
    local bot = load_with(tCreeps)
    local r = hurt_creeps(bot, 1157, 425)
    assert(r.count == 4, 'the far cluster of four wins over the near two: ' .. r.count)
    assert(covered(tCreeps, FOE_TEAM, r.targetloc.x, r.targetloc.y, 425) == 4,
        'and the point it names is on the four')
end

tests['§2 own creeps are not enemies, and neutrals are in neither set'] = function()
    local tCreeps = { ally(600, 0), ally(650, 40), neutral(620, -30) }
    local bot = load_with(tCreeps)
    assert(hurt_creeps(bot, 1157, 425).count == 0,
        'an enemy search must not count her own creeps or the neutral camp')
    -- The ally side is the same computation with the team predicate inverted;
    -- assert it rather than leaving the branch unexercised.
    local rAlly = bot:FindAoELocation(false, false, bot:GetLocation(), 1157, 425, 0.5, 0)
    assert(rAlly.count == 2, 'the two allied creeps, and not the neutral: ' .. rAlly.count)
end

-- =====================================================================
-- §3  What stays zero, and why (the refusals, each in its own node)
-- =====================================================================

tests['§3 REFUSAL: the KILL search stays 0 -- the dump carries no creep health'] = function()
    -- `nCanKillCreepsLocationAoE` passes nMaxHealth = nova_damage, i.e. it asks
    -- for creeps the cast would KILL. The dumper writes {t, team, x, y}; there
    -- is no health to filter on. Answering the HURT count here would silently
    -- promote an upper bound into a kill claim.
    local bot = load_with({ enemy(600, 0), enemy(700, 60), enemy(650, -80) })
    local rHurt = hurt_creeps(bot, 1157, 425)
    local rKill = bot:FindAoELocation(true, false, bot:GetLocation(), 1157, 425, 0.5, 300)
    assert(rHurt.count == 3, 'anti-vacuity: the same world answers 3 without the filter')
    assert(rKill.count == 0, 'the kill search must refuse, not reuse: ' .. rKill.count)
end

tests['§3 REFUSAL: the HERO search stays 0 even on a creep-carrying fixture'] = function()
    -- Answerable in principle (every fixture carries heroes with real HP) and
    -- deliberately not answered: every fixture carries them, so switching it on
    -- moves readings in ~two dozen census tests at once. That is a decision to
    -- take with the reopen list in hand (tests/frames/README.md), not a side
    -- effect of wiring the creep half.
    local bot = load_with({ enemy(600, 0), enemy(700, 60) })
    local r = bot:FindAoELocation(true, true, bot:GetLocation(), 1157, 425, 0.8, 0)
    assert(r.count == 0, 'the hero search is still the stand-in: ' .. r.count)
    assert(hurt_creeps(bot, 1157, 425).count == 2,
        'anti-vacuity: the creep search on the same world is live')
end

-- =====================================================================
-- §4  The range constraint is real, and it binds on the ring
-- =====================================================================

tests['§4 a creep beyond nMax + nRadius cannot be reached by any centre'] = function()
    local bot = load_with({ enemy(1583, 0) })   -- 1157 + 425 = 1582
    assert(hurt_creeps(bot, 1157, 425).count == 0,
        'one unit past the far edge is out of reach')
end

tests['§4 exactly at nMax + nRadius it IS reachable (the boundary is included)'] = function()
    local bot = load_with({ enemy(1582, 0) })
    local r = hurt_creeps(bot, 1157, 425)
    assert(r.count == 1, 'the creep exactly on the edge counts: ' .. r.count)
    assert(math.abs(dist(0, 0, r.targetloc.x, r.targetloc.y) - 1157) <= 1.0,
        'and the only centre that reaches it sits ON the ring: '
        .. dist(0, 0, r.targetloc.x, r.targetloc.y))
end

tests['§4 the range narrows the ANSWER, not just the point: same field, two rings'] = function()
    -- One field, two search radii -- exactly the pair the `cmqreach` fix is
    -- about (shipped 1157 vs armed 732 on Crystal Maiden). A loader that
    -- ignored nMaxDistanceFromBase would answer the same count twice, and the
    -- whole comparison the fix rests on would be invisible in fixtures.
    local tCreeps = { enemy(1400, 0), enemy(1450, 200), enemy(1350, -150) }
    local bot = load_with(tCreeps)
    local rWide = hurt_creeps(bot, 1157, 425)
    local rTight = hurt_creeps(bot, 732, 425)
    assert(rWide.count == 3, 'the wide ring reaches all three: ' .. rWide.count)
    assert(covered(tCreeps, FOE_TEAM, rWide.targetloc.x, rWide.targetloc.y, 425) == 3,
        'and names a point on all three')
    assert(rTight.count == 0,
        'the tight ring reaches none of them (nearest creep 1350 > 732 + 425): '
        .. rTight.count)
end

tests['§4 a creep the base cannot stand on is still covered from short of it'] = function()
    -- The centre is NOT the creep and NOT the base: it is the base pushed out
    -- until the creep is just inside the disk. That family is load-bearing --
    -- with only "centre on a creep" and "centre where two circles cross", a
    -- 4000-layout sweep against the grid in §5 misses the true maximum in about
    -- a fifth of the layouts (measured while writing this file).
    local tCreeps = { enemy(1300, 0) }
    local bot = load_with(tCreeps)
    local r = hurt_creeps(bot, 900, 425)
    assert(r.count == 1, 'reachable from short of it: ' .. r.count)
    local dCentre = dist(0, 0, r.targetloc.x, r.targetloc.y)
    assert(dCentre <= 900 + 1e-6, 'and the centre is legal: ' .. dCentre)
    assert(math.abs(dCentre - 875) <= 1.0,
        'the nearest such centre is 1300 - 425 = 875 out, not the ring at 900 '
        .. 'and not the creep at 1300: ' .. dCentre)
end

tests['§4 the range filter, isolated from the cheap distance prune'] = function()
    -- WHY THIS NODE EXISTS.  A mutation stand caught the first version of this
    -- file passing with the range test `dq <= nMax` DELETED -- because for a
    -- single creep the up-front prune (`nMax + nRadius`) and the range test are
    -- the same bound, so every other node here was satisfied by the prune alone
    -- and never exercised the filter it was supposed to pin.  The two bounds
    -- come apart only on a PAIR: each of these creeps is individually
    -- reachable, and the nearest centre covering BOTH sits 829.4 out, past the
    -- 732 ring.  Numbers, so a later edit has to re-derive rather than re-guess:
    --   |A| =  840.0, |B| = 1145.6   (both inside the 732+425 = 1157 prune)
    --    840.0 - 425 = 415.0  and  1145.6 - 425 = 720.6  (each alone: reachable)
    --   nearest centre covering both = 793.0 > 732        (together: not)
    --
    -- The first attempt at this node used a pair whose two circles cross at
    -- 829.4 and asserted 1 -- and the loader answered 2, correctly: the nearest
    -- centre covering both was not a crossing point at all but a point on ONE
    -- creep's arc, 679.5 out.  Same shape as the k=4 = 1157.0 slip in
    -- test_cm_creep_reach_real_frame.lua's header: a hand-derived "nearest"
    -- that skipped a candidate family and looked reasonable.  §5's grid is the
    -- instrument that keeps that honest; this comment is the reminder.
    local tCreeps = { enemy(840, 0), enemy(820, 800) }
    local bot = load_with(tCreeps)
    local r = hurt_creeps(bot, 732, 425)
    assert(r.count == 1,
        'both creeps survive the prune and each is reachable alone, but no '
        .. 'LEGAL centre covers the pair: ' .. r.count)
    assert(covered(tCreeps, FOE_TEAM, r.targetloc.x, r.targetloc.y, 425) == 1,
        'and the point it names is on exactly one of them')
    -- The other half of the isolation: widen the ring past 793 and the same
    -- field answers 2, so the 1 above is the constraint talking, not the
    -- geometry.
    assert(hurt_creeps(bot, 850, 425).count == 2,
        'with an 850 ring the same pair IS coverable')
end

-- =====================================================================
-- §5  Calibration against a brute-force grid
-- =====================================================================

tests['§5 the exact search matches a brute-force grid on a scattered field'] = function()
    -- Deterministic pseudo-scatter (a fixed linear congruential walk, so this
    -- is the same field every run and every machine) -- the point is a layout
    -- nobody hand-tuned to the candidate set.
    local tCreeps, seed = {}, 12345
    local function nxt(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return (seed % n) - n / 2
    end
    for _ = 1, 14 do tCreeps[#tCreeps + 1] = enemy(nxt(2400), nxt(2400)) end
    local bot = load_with(tCreeps)

    -- Three rings on the SAME field: unconstrained-ish, the shipped Nova creep
    -- ring, and the armed one. The narrow rings are where a missing candidate
    -- family shows up, so a single generous radius would not calibrate much.
    local R = 425
    local nBindingRings, nMaxSeen = 0, 0
    for _, NMAX in ipairs({ 1157, 900, 732 }) do
        local r = hurt_creeps(bot, NMAX, R)

        -- (a) the answer is self-consistent: the point it names is legal and
        --     really covers the count it claims. Rules out over-counting exactly.
        assert(dist(0, 0, r.targetloc.x, r.targetloc.y) <= NMAX + 1e-6,
            'legal centre at nMax=' .. NMAX)
        assert(covered(tCreeps, FOE_TEAM, r.targetloc.x, r.targetloc.y, R) == r.count,
            'the centre covers exactly the reported count at nMax=' .. NMAX)

        -- (b) the answer is not BELOW a fine grid over the same region. A grid
        --     can only ever find a lower bound, so this is the under-counting
        --     side -- together with (a) it brackets the exact optimum.
        local best = 0
        for gx = -NMAX, NMAX, 15 do
            for gy = -NMAX, NMAX, 15 do
                if dist(0, 0, gx, gy) <= NMAX then
                    local n = covered(tCreeps, FOE_TEAM, gx, gy, R)
                    if n > best then best = n end
                end
            end
        end
        assert(best >= 2, 'anti-vacuity: the grid itself must find a real cluster '
            .. 'at nMax=' .. NMAX .. ', or (b) passes on an empty field. Grid best: '
            .. best)
        assert(r.count >= best,
            'at nMax=' .. NMAX .. ' the exact search found ' .. r.count
            .. ' but a 15-unit grid found ' .. best .. ' -- a missing candidate family')
        if r.count > nMaxSeen then nMaxSeen = r.count end
        if r.count < nMaxSeen then nBindingRings = nBindingRings + 1 end
    end
    -- Anti-vacuity for the sweep itself: if every ring answered the same, the
    -- three passes were one pass written three times.
    assert(nBindingRings > 0,
        'the three rings must not all answer alike, or this sweep tests one ring')
end

tests['§5 the same question twice gets the same point (deterministic tie-break)'] = function()
    -- Four creeps in two identical pairs mirrored about the base: the maximum
    -- is attained at two different centres. The engine's own tie-break is
    -- unreadable from the bot VM, so a test must never depend on WHICH -- but
    -- the loader must at least not wobble between runs.
    local bot = load_with({ enemy(600, 0), enemy(700, 0), enemy(-600, 0), enemy(-700, 0) })
    local a = hurt_creeps(bot, 1157, 425)
    local b = hurt_creeps(bot, 1157, 425)
    assert(a.count == 2 and b.count == 2, 'each pair is a 2: ' .. a.count)
    assert(a.targetloc.x == b.targetloc.x and a.targetloc.y == b.targetloc.y,
        'the same call must answer the same point')
end

-- =====================================================================
-- §6  Housekeeping
-- =====================================================================

tests['§6 the synthetic fixtures are cleaned up'] = function()
    assert(#tmp_paths > 0, 'anti-vacuity: this run actually wrote fixtures')
    for _, p in ipairs(tmp_paths) do os.remove(p) end
end

return tests
