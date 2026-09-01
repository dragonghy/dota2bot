-- [hero, GH #104] The bench used to hand shipped code its nearby-HERO lists in
-- alphabetical order, while the engine hands them out nearest-first.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- docs/BOT_API_REFERENCE.md:1229 states the contract for the whole GetNearby*
-- family: "All return tables sorted by distance (closest first)."  The fixture
-- loader honoured that for STRUCTURES (tests/mock/replay_fixture.lua's
-- nearby_structures sorts, and carries a comment saying why) but not for
-- HEROES: it walked `fx.units` and handed the result back untouched.  And
-- `fx.units` is written by tools/batch_test/replayscope/make_fixture.py with
-- `for h in sorted(per)` -- ALPHABETICAL HERO NAME order.
--
-- So in every fixture-driven test, `list[1]` -- and "the first thing a
-- `for _ in pairs(...)` loop touches" -- was the alphabetically-first hero in
-- the radius, not the nearest one.  2277 GetNearbyHeroes call sites in bots/
-- read that list, and J.GetNearbyHeroes (jmz_func.lua:2517) only filters it --
-- it never reorders -- so the loader was the only place the order could be
-- wrong, and the only place it can be restored.
--
-- The defect is invisible to gate tests, which ask "does it fire", and lethal
-- to aiming tests, which ask "at whom".  It had already reached a published
-- conclusion: GH #104 section 4 described X.ConsiderQ's catch-all as taking
-- "whoever the engine listed first" and argued from list order being
-- arbitrary.  The engine's order is not arbitrary; it is nearest-first.  (That
-- section's RESULT survives -- its frame puts the full-health sven at 300u and
-- the dying lion at 400u, so sven is first under both readings -- but its
-- REASON was wrong, and it has been corrected in place.)
--
-- WHAT THIS FILE PINS
--   1. the three source facts the fix rests on: the documented contract, the
--      alphabetical writer, and the non-reordering J wrapper;
--   2. a census over the whole fixture library showing the two orders really do
--      disagree -- this is not a theoretical difference;
--   3. the fix itself: across every fixture, every alive subject, three radii
--      and both team polarities, the list the bench returns is non-decreasing
--      in distance;
--   4. that the order is a TOTAL order (equidistant heroes break on name), so a
--      test that pins a target cannot flap between runs;
--   5. on a REAL frame, that shipped code is genuinely order-sensitive: reverse
--      the list and Wraith King's only hard disable moves off the 36%-health
--      enemy that went on to kill him and onto the 76%-health one.
--
-- HONEST BOUNDS -- read before quoting
--   * The ordering is STATED, not dumped.  A .dem carries no list order; what
--     the fixture carries is positions, and the sort is derived from them.
--     Same standing as the structure sort above it.
--   * The tie-break (unit name) is OURS.  The engine promises nothing about two
--     equidistant heroes.  No reading anywhere may depend on it; it exists so
--     that a pinned target is reproducible.
--   * The census in section 2 measures the fixture LIBRARY, not the game.  It
--     says how often the bench's old answer differed from the engine's, in the
--     frames we happen to have.  It is not a claim about live games.
--   * Section 5 shows shipped code is order-sensitive on a real frame.  It does
--     NOT show that this particular frame's answer used to be wrong: lich sorts
--     before nevermore alphabetically AND stands closer, so both orders agree
--     here.  The reversal is a declared mutation of the bench, used as an
--     instrument.
--   * Counts in section 2 are asserted as BOUNDS, not equalities, on purpose.
--     GH #106: corpus size is already pinned by equality in several files, so
--     adding one fixture is a cross-file breaking change.  This file does not
--     add another such equality; the exact readings of the day are recorded
--     here in the header instead.
--
-- READINGS ON THE DAY (2026-08-22, 98 fixtures):
--     alive hero subjects                          911
--     (subject, radius) pairs with >= 2 enemies     502
--     ... where alphabetical-first ~= nearest       200  (39.8%)
--         r=568   50 pairs,  12 differ (24.0%)
--         r=1200 197 pairs,  80 differ (40.6%)
--         r=1600 255 pairs, 108 differ (42.4%)
--
-- MUTATION RECORD (2026-08-22): seven mutations, six caught.
--   M1 delete the table.sort from the loader's GetNearbyHeroes  -> CAUGHT (3)
--   M2 sort descending (farthest first)                         -> CAUGHT (3, 5)
--   M3 tie-break reversed (b < a)                               -> CAUGHT (4)
--   M4 sort allies only (leave the enemy list unsorted)         -> CAUGHT (3)
--   M5 sort by health instead of distance                       -> CAUGHT (3)
--   M6 make_fixture.py `sorted(per)` -> `per` (unordered)       -> CAUGHT (1)
--   M7 drop the tie-break, keep `da < db`                       -> SURVIVED, and
--      it is a DECLARED EQUIVALENCE: with the tie built in section 4 the tied
--      pair is two elements long, table.sort leaves a pair its comparator calls
--      equal in input order, and input order IS alphabetical (fx.units) -- so
--      the tie-break agrees with doing nothing.  It stops being an equivalence
--      the moment three or more heroes tie, or the generator stops writing
--      alphabetically (which M6's ratchet is there to notice).  "Not caught"
--      and "nothing to catch" are different things.
--   One reading worth keeping from the record: M1 -- the defect this file
--   fixes -- is NOT caught by section 5, because on that frame the nearest
--   enemy is also the alphabetically first one.  That is the whole hazard in
--   one line: a wrong list order is invisible on any frame where the two
--   orders happen to agree, which is 60% of this library.
--
-- WHAT MOVED ELSEWHERE IN THE SUITE: NOTHING, and that is measured rather than
-- assumed.  tests/_itemdesire_sweep.lua -- the heaviest fixture-driven sweep in
-- the repo, 882 driven frames -- was run twice, once on this tree and once on a
-- copy of it with the sort deleted.  The two runs produce BYTE-IDENTICAL crash
-- sets (177 at jmz_func:2597 + 30 at jmz_func:3325, same fixtures, same
-- heroes).  So correcting the order changed no reading anywhere in the suite.
--
-- That is worth stating because it is the trap this file was nearly written
-- into.  The sweep's pinned counts DID move recently (209 -> 207 crashes,
-- 179 -> 177 at 2597, 672 -> 674 silent), and the obvious story -- "the order
-- fix took two frames off a crash path" -- is FALSE.  Bisected: the mover is
-- commit cf7bb4c, which regenerated tests/fixtures/f_260819_182855_lion_drain_jungle
-- onto a snapshot ~0.33s earlier (GH #107).  Restore just that one fixture to
-- its pre-heal bytes and the count returns to exactly 209 / 179, with the two
-- missing crashes named: earthshaker and phantom_assassin on that fixture.
-- tests/test_itemdesire_world_assertion.lua carries the re-pin and the same
-- attribution.
--
-- And note what that sweep could and could not see, since it is the only place
-- in the suite that reacts to frame-level change at all: it sees drift only as
-- an unexplained integer in a census pinned by equality. Nothing in the suite
-- could see the thing that actually mattered here -- that a stun was being
-- aimed at the wrong hero.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local RADII = { 568, 1200, 1600 }

local function read(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

local function fixture_paths()
    local out = {}
    local p = io.popen('ls tests/fixtures/*.lua')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

local tests = {}

----------------------------------------------------------------------
-- 1. The three source facts the fix rests on.

tests['[source] the engine contract this file restores is documented'] = function()
    local doc = read('docs/BOT_API_REFERENCE.md')
    assert(doc:find('sorted by distance', 1, true),
        'docs/BOT_API_REFERENCE.md no longer states the GetNearby* ordering '
        .. 'contract. This file, and the loader sort it pins, exist only because '
        .. 'of that line -- if the documented contract changed, re-derive before '
        .. 'trusting anything below.')
end

tests['[source] make_fixture.py writes fx.units in alphabetical order'] = function()
    local src = read('tools/batch_test/replayscope/make_fixture.py')
    assert(src:find('for h in sorted(per)', 1, true),
        'the generator no longer emits units in sorted(name) order. That order '
        .. 'is the whole reason the unsorted loader had a systematic bias rather '
        .. 'than a random one -- re-measure the census in section 2 before '
        .. 'quoting the header readings.')
end

tests['[source] J.GetNearbyHeroes filters but never reorders'] = function()
    local src = read('bots/FunLib/jmz_func.lua')
    local body = src:match('function J%.GetNearbyHeroes.-\nend')
    assert(body, 'J.GetNearbyHeroes not found in jmz_func.lua')
    assert(not body:find('table.sort', 1, true),
        'J.GetNearbyHeroes now sorts. If the shipped wrapper imposes its own '
        .. 'order, the loader is no longer the only place the order is decided '
        .. 'and the argument in this header needs redoing.')
    assert(body:find('bot:GetNearbyHeroes', 1, true),
        'J.GetNearbyHeroes no longer sources its list from bot:GetNearbyHeroes')
end

----------------------------------------------------------------------
-- 2. Census: the two orders disagree often, over the whole library.
--
-- Computed from fixture DATA only (positions and teams), so it measures the
-- disagreement itself and does not depend on the loader being fixed.

local function census()
    local subjects, pairs_ge2, differ = 0, 0, 0
    local by_radius = {}
    for _, r in ipairs(RADII) do by_radius[r] = { n = 0, d = 0 } end
    local nfixtures = 0
    for _, path in ipairs(fixture_paths()) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            nfixtures = nfixtures + 1
            for _, s in ipairs(fx.units) do
                if s.alive then
                    subjects = subjects + 1
                    for _, r in ipairs(RADII) do
                        local list = {}
                        for _, v in ipairs(fx.units) do
                            if v ~= s and v.alive and v.team ~= s.team then
                                local dx, dy = v.x - s.x, v.y - s.y
                                local d = math.sqrt(dx * dx + dy * dy)
                                if d <= r then list[#list + 1] = { name = v.name, d = d } end
                            end
                        end
                        if #list >= 2 then
                            pairs_ge2 = pairs_ge2 + 1
                            by_radius[r].n = by_radius[r].n + 1
                            local alpha, near, nd = list[1].name, list[1].name, list[1].d
                            for _, e in ipairs(list) do
                                if e.name < alpha then alpha = e.name end
                                if e.d < nd then near, nd = e.name, e.d end
                            end
                            if alpha ~= near then
                                differ = differ + 1
                                by_radius[r].d = by_radius[r].d + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return { fixtures = nfixtures, subjects = subjects, pairs = pairs_ge2,
             differ = differ, by_radius = by_radius }
end

tests['[census] alphabetical-first and nearest disagree on a large minority'] = function()
    local c = census()
    assert(c.fixtures >= 90, 'expected the fixture library, got ' .. c.fixtures .. ' files')
    assert(c.pairs >= 400,
        'only ' .. c.pairs .. ' (subject, radius) pairs carry two or more '
        .. 'enemies; the census is too thin to support the header readings')
    local frac = c.differ / c.pairs
    assert(frac > 0.20,
        string.format('alphabetical-first equalled nearest on %.1f%% of %d pairs. '
            .. 'The header records 39.8%% disagreement on 502 pairs; a collapse '
            .. 'to near zero would mean the two orders had become the same '
            .. 'question and this whole file is measuring nothing.',
            100 * (1 - frac), c.pairs))
    -- Bound rather than equality (GH #106): adding fixtures must not break this.
    assert(frac < 0.80,
        string.format('%.1f%% disagreement is higher than anything this library '
            .. 'has shown (39.8%% on the day); check the census, not the fix', 100 * frac))
end

tests['[census] the disagreement is present at combat range too'] = function()
    -- 568 is X.ConsiderQ's catch-all reach, the radius that produced GH #104's
    -- wrong reason. The tight radius has the fewest pairs, so it is the one
    -- worth stating separately: a fix argued only from 1600u lists would not
    -- cover the frames the issue was actually about.
    local c = census()
    local tight = c.by_radius[568]
    assert(tight.n >= 30,
        'only ' .. tight.n .. ' subject-frames carry two enemies inside 568u')
    assert(tight.d > 0,
        'inside 568u the two orders never disagreed. The header records 12 of '
        .. '50; if that is now zero, the library changed and section 5 needs '
        .. 'a fresh frame.')
end

----------------------------------------------------------------------
-- 3. The fix: every list the bench hands out is nearest-first.

tests['[fix] every nearby-hero list in the library is sorted by distance'] = function()
    local checked, bad = 0, {}
    for _, path in ipairs(fixture_paths()) do
        local _, _, heroes, fx = rf.load(path)
        for _, u in ipairs(fx.units) do
            if u.alive then
                local me = heroes[u.name]
                for _, r in ipairs(RADII) do
                    for _, enemies in ipairs({ true, false }) do
                        local list = me:GetNearbyHeroes(r, enemies, BOT_MODE_NONE)
                        checked = checked + 1
                        local prev = -1
                        for i, h in ipairs(list) do
                            local d = GetUnitToUnitDistance(me, h)
                            if d < prev - 1e-6 and #bad < 5 then
                                bad[#bad + 1] = string.format(
                                    '%s subject=%s r=%d enemies=%s position %d (%s) is %.1f '
                                    .. 'after %.1f', path, u.name, r, tostring(enemies), i,
                                    h:GetUnitName(), d, prev)
                            end
                            prev = math.max(prev, d)
                        end
                    end
                end
            end
        end
    end
    assert(checked > 4000,
        'only ' .. checked .. ' lists were checked; the sweep did not run')
    assert(#bad == 0,
        'lists came back out of distance order:\n  ' .. table.concat(bad, '\n  '))
end

tests['[fix] the nearest enemy really is list[1] on a frame with three'] = function()
    -- A positive, readable instance of section 3's sweep, so a reader does not
    -- have to trust an aggregate: pick the busiest 1600u enemy list in the
    -- library and check its head against a straight minimum over distances.
    local best, best_bot, best_fx
    for _, path in ipairs(fixture_paths()) do
        local _, bot, _, fx = rf.load(path)
        local list = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
        if not best or #list > #best then best, best_bot, best_fx = list, bot, fx end
    end
    assert(#best >= 3,
        'the busiest enemy list in the library holds only ' .. #best .. ' heroes')
    local nearest, nd = nil, math.huge
    for _, h in ipairs(best) do
        local d = GetUnitToUnitDistance(best_bot, h)
        if d < nd then nearest, nd = h, d end
    end
    assert(best[1] == nearest,
        string.format('in %s the list starts with %s but the nearest enemy is %s',
            best_fx.game, best[1]:GetUnitName(), nearest:GetUnitName()))
end

----------------------------------------------------------------------
-- 4. Ties break deterministically, so a pinned target cannot flap.
--
-- DECLARED MUTATION: no fixture in the library holds two equidistant visible
-- heroes, so the tie is constructed by moving two enemies onto one point.
-- Everything else on the frame is real.

tests['[fix] equidistant heroes come back in a stable, name-broken order'] = function()
    local function ordered()
        local _, bot, heroes = rf.load('tests/fixtures/f_225947_wk_trade_kite.lua')
        local here = bot:GetLocation()
        local twin = Vector(here.x + 300, here.y, here.z)
        for _, n in ipairs({ 'npc_dota_hero_lich', 'npc_dota_hero_nevermore' }) do
            rawget(heroes[n], '__spec').GetLocation = twin
        end
        local list = bot:GetNearbyHeroes(568, true, BOT_MODE_NONE)
        local names = {}
        for _, h in ipairs(list) do names[#names + 1] = h:GetUnitName() end
        return names
    end
    local a, b = ordered(), ordered()
    assert(#a == 2, 'expected both enemies in range after the move, got ' .. #a)
    assert(a[1] == b[1] and a[2] == b[2],
        'two loads of the same frame produced different orders (' .. a[1] .. ' vs '
        .. b[1] .. '): the tie-break is not deterministic and any test that pins '
        .. 'a target can flap')
    assert(a[1] == 'npc_dota_hero_lich' and a[2] == 'npc_dota_hero_nevermore',
        'the declared tie-break is unit name ascending; got ' .. a[1] .. ' first')
end

----------------------------------------------------------------------
-- 5. Shipped code is order-sensitive, on a real frame.
--
-- f_225947_wk_trade_kite: game 20260721_225947 at t=367.0 (6:07).  Wraith King
-- is level 7 with Wraithfire Blast at rank 1, 222 of 375 mana.  Lich stands
-- 197u away at 299 of 824 health (36%); Nevermore stands 394u away at 982 of
-- 1285 (76%).  Both are inside the catch-all's 568u reach.  Ground truth from
-- the dump: lich dealt WK 750 damage over the following window and WK died
-- 4.6s later.
--
-- The only mutation in the base case is the Q cooldown (13.4 -> 0), which is
-- what makes the frame a decision at all, plus the cast-range anchor the dumper
-- does not carry (GH #27 family).  The reversal in the second case is the
-- instrument.

local FRAME = 'tests/fixtures/f_225947_wk_trade_kite.lua'
local CAST_RANGE = 525          -- datafeed hero_id 42, read 2026-08-22

--- DECLARED MUTATION, added 2026-09-01 (hero) -- the mana that keeps this
--- ordering probe alive.
---
--- This frame's real mana is 222, Hellfire Blast costs 95 and Reincarnation 220,
--- so X.ShouldSaveMana's reserve clause -- `GetMana() - Q:GetManaCost() <
--- R:GetManaCost()`, i.e. 222 - 95 = 127 < 220 -- is TRUE and shipped
--- X.ConsiderQ correctly declines to cast anything at all.
---
--- It did not decline before, and the reason is not this file's: until
--- 2026-09-01 tests/mock/replay_fixture.lua left `GetManaCost` off the ability
--- spec, so it answered 0 for every ability and the reserve clause read
--- `222 - 0 < 0` -- FALSE on every frame, for every hero, forever.  That is the
--- SECOND consumer of that defect found (the first is X.ConsiderR's first line,
--- tests/test_fixture_mana_price.lua): a shipped, heavily-argued reserve rule
--- that has never once been able to fire in the fixture world.
---
--- This probe is about GetNearbyHeroes ORDER deciding WHO gets hit, not about
--- Wraith King's mana, so the reserve is lifted rather than argued with: mana is
--- raised to exactly 315 = 95 + 220, the least value that clears the clause, so
--- the cast happens and the ordering defect stays visible.  Anything larger would
--- hide how tight the margin is.  This joins the cast range and cooldown this
--- function already fabricates; the ground-truth case below reads the frame's own
--- distances, healths and burst and is untouched by it.
local RESERVE_CLEARING_MANA = 315       -- Hellfire Blast 95 + Reincarnation 220

local function wk_decision(reverse)
    local J, bot, heroes, fx = rf.load(FRAME)
    local q = bot:GetAbilityByName('skeleton_king_hellfire_blast')
    rawget(q, '__spec').GetCastRange = CAST_RANGE
    rawget(q, '__spec').GetCooldownTimeRemaining = 0
    rawget(bot, '__spec').GetMana = RESERVE_CLEARING_MANA   -- MUTATION, see above
    if reverse then
        local spec = rawget(bot, '__spec')
        local sorted_impl = spec.GetNearbyHeroes
        spec.GetNearbyHeroes = function(self, r, e, m)
            local t, out = sorted_impl(self, r, e, m), {}
            for i = #t, 1, -1 do out[#out + 1] = t[i] end
            return out
        end
    end
    J.IsSoakCandidate = function() return false end      -- shipped defaults
    local X = rf.load_hero('skeleton_king')
    X.SkillsComplement()
    local d, t = X.ConsiderQ()
    local name = (type(t) == 'table' and t.GetUnitName) and t:GetUnitName() or nil
    return d, name, bot, heroes, fx
end

tests['[real frame] ground truth: two enemies inside 568u, the nearer one dying'] = function()
    local _, _, bot, heroes, fx = wk_decision(false)
    assert(fx.time == 367.0, 'frame t=367.0, got ' .. tostring(fx.time))
    assert(bot:GetLevel() == 7,
        'WK is level 7 on this frame -- above the catch-all cliff, which is why '
        .. 'the catch-all is what answers; got ' .. bot:GetLevel())
    local lich, sf = heroes['npc_dota_hero_lich'], heroes['npc_dota_hero_nevermore']
    local dl, ds = GetUnitToUnitDistance(bot, lich), GetUnitToUnitDistance(bot, sf)
    assert(math.abs(dl - 197.3) < 1 and math.abs(ds - 394.5) < 1,
        string.format('real distances 197.3 / 394.5, got %.1f / %.1f', dl, ds))
    assert(dl < 568 and ds < 568, 'both enemies are inside the catch-all reach')
    assert(lich:GetHealth() == 299 and sf:GetHealth() == 982,
        'real healths 299 and 982')
    assert(fx.observed.burst['npc_dota_hero_lich'] == 750 and fx.observed.died_after == 4.6,
        'ground truth: the nearer, weaker enemy is the one that went on to deal '
        .. '750 damage, and WK died 4.6s later')
end

--- The other half of the mutation above, asserted rather than described.
---
--- Without the lift, shipped Wraith King on this frame casts NOTHING, and that
--- is correct behaviour: he cannot pay for the blast and still hold his
--- Reincarnation mana, which is the rule X.ShouldSaveMana exists to enforce and
--- which bots/BotLib/hero_skeleton_king.lua argues for at length above
--- X.GetRoshanManaFloor.  Pinning it here does two things: it keeps the lift
--- above honest (a reader can see exactly what was suppressed and why), and it
--- guards the reserve clause itself, which spent its whole life reading
--- `GetMana() - 0 < 0` and is live for the first time as of 2026-09-01.
tests['[real frame] the reserve rule is live: at the frame\'s real 222 mana, WK holds'] = function()
    local J, bot, heroes = rf.load(FRAME)
    local q = bot:GetAbilityByName('skeleton_king_hellfire_blast')
    rawget(q, '__spec').GetCastRange = CAST_RANGE
    rawget(q, '__spec').GetCooldownTimeRemaining = 0
    -- deliberately NO mana lift here
    local r = bot:GetAbilityByName('skeleton_king_reincarnation')

    assert(bot:GetMana() == 222, 'the frame\'s real mana, got ' .. bot:GetMana())
    assert(q:GetManaCost() == 95, 'Hellfire Blast rank 1 costs 95, got ' .. q:GetManaCost())
    assert(r:GetManaCost() == 220, 'Reincarnation rank 1 costs 220, got ' .. r:GetManaCost())
    assert(r:GetCooldownTimeRemaining() <= 3.0, 'Reincarnation is within the 3s window')
    assert(bot:GetMana() - q:GetManaCost() < r:GetManaCost(),
        'the reserve clause must BIND on this frame: 222 - 95 = 127 < 220. If this '
        .. 'is false the mana prices went back to 0 and the clause is dead again '
        .. '-- check mana_ladder() in tests/mock/replay_fixture.lua')
    assert(RESERVE_CLEARING_MANA == q:GetManaCost() + r:GetManaCost(),
        'the lift above must stay the LEAST value that clears the clause')

    J.IsSoakCandidate = function() return false end
    local X = rf.load_hero('skeleton_king')
    X.SkillsComplement()
    local d = X.ConsiderQ()
    assert(d == 0,
        'shipped WK must decline at 222 mana (reserve rule), got desire ' .. tostring(d))
end

tests['[real frame] shipped ConsiderQ aims at whoever the list puts first'] = function()
    local d1, n1 = wk_decision(false)
    assert(d1 > 0 and n1 == 'npc_dota_hero_lich',
        'with the list nearest-first the stun goes to lich (36% health, 197u); got '
        .. tostring(n1) .. ' at desire ' .. tostring(d1))
    local d2, n2 = wk_decision(true)
    assert(d2 > 0 and n2 == 'npc_dota_hero_nevermore',
        'reversing the list moves the same cast to nevermore (76% health, 394u); '
        .. 'got ' .. tostring(n2) .. ' at desire ' .. tostring(d2))
    assert(d1 == d2,
        'the desire is unchanged (' .. tostring(d1) .. ' vs ' .. tostring(d2)
        .. '); order decides WHO is hit, not WHETHER -- which is exactly why this '
        .. 'defect was invisible to every gate test in the suite')
end

return tests
