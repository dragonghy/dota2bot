-- [stayattr 2026-09-05, 协同组] Owner priority P2: a hurt bot that is in no
-- danger must NOT go home. J.ShouldStayAndRegen is the promoted guard that says
-- "stay and heal" -- live in every turbo game since the 'tphome' promote -- and
-- its chase read is `bot:WasRecentlyDamagedByAnyHero(3.0)`, which carries NO
-- ATTRIBUTION. A global ult landed from the far corner of the map answers TRUE
-- there, the guard steps aside, and the bot walks or TPs home from a spot where
-- the nearest enemy is thousands of units away.
--
-- ⭐ THE REUSABLE JUDGEMENT, and it is why this lever is one clause wide:
-- the GATED family aimed at this very trip (J.IsFieldRegenSituation, the
-- stayfield/stayfield2/fieldbuy ids) ALREADY reads its danger the attributed
-- way, and has since 2026-08-22. The shipped guard sitting on the same decision
-- was simply never brought along. So the defect is not a missing idea -- the
-- idea is in the file, 290 lines further down, in the repo's own words
-- ("Attributed danger: someone hit me recently AND is still near me"). It is an
-- idea that stopped at the boundary of the gated code and never crossed into
-- the promoted code next to it. A guard being right in the experimental half of
-- a file is not evidence that the shipped half asks the same question; those
-- have to be read separately, and here they differ.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped function is driven, twice,
-- on real frames -- once with every candidate disarmed and once with 'stayattr'
-- armed -- and the CAUSE of the changed answer is read off the frame (who dealt
-- the damage, and how far away they are) rather than asserted as a string.
--
-- ⚠️ HONEST BOUNDS, all four stated up front:
-- (1) The lever cannot see fog. An enemy who bursts out of fog and withdraws
--     past 3000 reads exactly like a global ult here. That is the identical
--     bound J.IsFieldRegenSituation declares for its own scan, and it is why
--     the 1200 ring on the next line is left untouched -- that clause, not this
--     one, owns "is someone standing on me". ⚠️ And the corpus does NOT yet
--     corroborate that handover: zero of the five in-band frames this lever
--     acts on had anyone inside that ring, so the ring never had to do the job
--     the bound assigns it. A vacuous zero, asserted as one -- see the
--     [census] test and the UNMEASURABLE entry in the mutation stand.
-- (2) On the flip frame the nearest enemy is a spirit_breaker 1,556 units away
--     with Charge of Darkness off cooldown. He did NOT deal the damage (the
--     frame's own recent_damage rows name only the zuus), so the attributed
--     scan is answering correctly -- but "1,556 units and charging" is a real
--     threat that this lever does not weigh, because the shipped 1200 ring is
--     the clause that owns it and is unchanged. Asserted below as a fact of the
--     frame, not argued away.
-- (3) The frame owner priority P2 itself pins is lina on this same fixture, and
--     her whole-function answer does NOT flip -- the supply clause
--     (`not bHasFlask and bot:GetGold() < 90`) still stops her. Under a mock
--     whose GetGold falls through the `^Get -> 0` catch-all (GH #495) that is a
--     type assertion, not her real gold, so what happens on the live frame is
--     UNKNOWN and is not claimed. What IS shown on her frame is the clause this
--     lever owns: the veto fires, and nobody who hit her is anywhere near.
-- (4) A frame is one instant. This file says the decision at t is wrong; it
--     does not claim the bot that stays then survives the next ten seconds.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_stayattr_sweep.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

-- The witnessed frame -- and it is the fixture owner priority P2 pinned, read
-- one hero across. Zeus casts Thundergod's Wrath (its cooldown reads 128.3 on
-- this frame, i.e. just spent) from (-6394.6,-5510.8); jakiro is at
-- (-5693.5,4891.6), ~10,400 units away, and takes 212+17 of it 2.6s before the
-- instant. Jakiro is at 405/1000 with a tango ticking. Shipped: the veto fires
-- and he is released to go home. Armed: he stays and finishes the tango.
local FX     = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local SUBJ   = 'npc_dota_hero_jakiro'
local DAMAGER = 'npc_dota_hero_zuus'
-- The nearest enemy on that frame -- outside the shipped 1200 ring, and not the
-- one who dealt the damage. See honest bound (2).
local NEAR   = 'npc_dota_hero_spirit_breaker'
-- The frame P2 itself names, same fixture. Clause-level only; see bound (3).
local SUBJ2  = 'npc_dota_hero_lina'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, flips = {}, unattr = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local ff, fh, fd, fp = line:match('^F (%S+) (%S+) ([%d%.]+) ([%d%.]+)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh,
                near = tonumber(fd), hp = tonumber(fp) }
        end
        local uf, uh, ud, ub = line:match('^U (%S+) (%S+) ([%d%.]+) (%S+)$')
        if uf ~= nil then
            m.unattr[#m.unattr + 1] = { fixture = uf, hero = uh,
                near = tonumber(ud), bucket = ub }
        end
        if line == 'DONE' then m.done = true end
    end
    return m
end)()

local function C(key)
    local n = M.c[key]
    assert(n ~= nil, 'the sweep did not emit counter ' .. key
        .. ' -- an absent counter is not a zero')
    return n
end

-- Load one fixture frame with every soak candidate disarmed, and hand back a
-- switch that arms exactly 'stayattr'. Arming ONE id (not 'all') is the point:
-- a bundle answer cannot be attributed to this lever.
local function frame(path, subject)
    local J, bot = rf.load(path, subject)
    local armed = false
    J.IsSoakCandidate = function(sId) return armed and sId == 'stayattr' end
    return J, bot, function(b) armed = b end
end

local function enemy_named(J, bot, sName)
    local t = J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}
    for _, h in pairs(t) do
        if J.IsValidHero(h) and h:GetUnitName() == sName then return h end
    end
    return nil
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the lever is one clause, one id, in the promoted guard'] = function()
    assert(M.done, 'the corpus sweep did not finish -- ' .. SWEEP)
    assert(M.g.STAY == 1, 'the sweep could not slice J.ShouldStayAndRegen out of '
        .. JMZ)
    assert(M.g.DAMAGER == 1, 'the sweep could not slice J.HasNearbyHeroDamager '
        .. 'out of ' .. JMZ .. ' -- this whole file is stale')
    assert(M.g.STAY_SOAKID == 1, "the 'stayattr' id is no longer in "
        .. 'J.ShouldStayAndRegen -- the lever left the tree')
    -- The unarmed path must be the SHIPPED read, and `not IsSoakCandidate(...)`
    -- as the first disjunct is what makes that true by short-circuit rather
    -- than by argument.
    assert(M.g.STAY_NEGATED == 1, "the id is not in a `not IsSoakCandidate` "
        .. 'disjunct -- unarmed behaviour is no longer provably the shipped read')
    -- The pullcad trap, as an assertion instead of prose. A second id here
    -- would make the live condition a conjunction that freezes FALSE the day
    -- either id is promoted -- while check_armed_wiring.py still calls it WIRED.
    -- Parsed off comment-stripped source, because this function's own comment
    -- names the trap and would otherwise satisfy the check it is warning about.
    assert(M.g.STAY_NIDS == 1, 'J.ShouldStayAndRegen names '
        .. tostring(M.g.STAY_NIDS) .. ' soak ids; exactly 1 is allowed '
        .. '(two conjoined ids = the pullcad trap)')
    -- The helper is a question about the world, not a decision. A gate inside
    -- it would be a second arming point nobody reads.
    assert(M.g.DAMAGER_SOAKID == 0,
        'J.HasNearbyHeroDamager grew a soak gate of its own')
end

tests['[source] the constants are the sibling scan\'s, read off the tree'] = function()
    -- Every number this file reasons with is parsed, never remembered: move one
    -- in jmz_func and this assertion moves with it (the M13 lesson).
    assert(M.g.STAY_RADIUS == 3000, 'the attributed scan radius is '
        .. tostring(M.g.STAY_RADIUS) .. ', expected 3000')
    assert(M.g.STAY_WINDOW == 3, 'the attribution window is '
        .. tostring(M.g.STAY_WINDOW) .. 's, expected 3s')
    -- The claim in the shipped comment is "same shape and constants as the
    -- sibling". That is checkable, so it is checked rather than trusted.
    assert(M.g.SIB_RADIUS == M.g.STAY_RADIUS,
        'J.IsFieldRegenSituation scans ' .. tostring(M.g.SIB_RADIUS)
        .. ' but this lever scans ' .. tostring(M.g.STAY_RADIUS)
        .. ' -- the "same constants as the sibling" comment is now false')
    -- The ring and the HP floor are the clauses this lever explicitly does NOT
    -- touch (honest bounds 1 and 2). If either moved, those bounds need reading
    -- again.
    assert(M.g.STAY_RING == 1200, 'the untouched chase ring is now '
        .. tostring(M.g.STAY_RING))
    assert(M.g.STAY_HP_LO == 0.18 and M.g.STAY_HP_HI == 0.75,
        'the HP band moved to [' .. tostring(M.g.STAY_HP_LO) .. ','
        .. tostring(M.g.STAY_HP_HI) .. ']')
end

tests['[source] no other call site was touched'] = function()
    -- One lever means one call site. The sibling attributed scan sits on a path
    -- this change deliberately left alone, and the argument for that ("sharing
    -- code with a promoted site turns one lever into a refactor") is only worth
    -- anything if the sibling really is still inline.
    local src = read_file(JMZ)
    local n = 0
    for _ in src:gmatch('J%.HasNearbyHeroDamager%(') do n = n + 1 end
    -- One definition + one call.
    assert(n == 2, 'J.HasNearbyHeroDamager appears ' .. n
        .. ' times in ' .. JMZ .. ' (expected 1 definition + 1 call site); '
        .. 'a second caller makes this a bundle, not a lever')
end

-- ------------------------------------------------ the frame, as behaviour ---

tests['[frame] the shipped guard is vetoed by a global ult 10,400 units away'] = function()
    local J, bot = frame(FX, SUBJ)
    -- The situation, read off the frame before anything is decided.
    assert(J.IsModeTurbo(), 'the fixture frame is not turbo -- this guard is '
        .. 'turbo-only and nothing below applies')
    local nHP = J.GetHP(bot)
    assert(nHP > 0.18 and nHP < 0.75, 'jakiro is at ' .. string.format('%.3f', nHP)
        .. ' HP, outside the guard\'s band -- the frame stopped being in domain')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0),
        'nothing hit jakiro in the last 3s -- the defect needs the blind read '
        .. 'to be TRUE')
    -- WHO hit him, and from where. This is the whole finding, and it is read
    -- off the frame rather than asserted as a name.
    local hZeus = enemy_named(J, bot, DAMAGER)
    assert(hZeus ~= nil, DAMAGER .. ' is not on this frame')
    assert(bot:WasRecentlyDamagedByHero(hZeus, 3.0),
        DAMAGER .. ' is not the source of the damage on this frame')
    local dZeus = GetUnitToUnitDistance(bot, hZeus)
    assert(dZeus > 10000, 'the damage source is ' .. string.format('%.0f', dZeus)
        .. ' units away; this frame is only interesting because it is a global')
    -- And nobody who hit him is anywhere near.
    assert(not J.HasNearbyHeroDamager(bot, 3000, 3.0),
        'someone inside 3000 did hit jakiro -- this is not the global-ult case')
end

tests['[frame] armed, the guard holds the bot; unarmed it releases him'] = function()
    local J, bot, arm = frame(FX, SUBJ)
    arm(false)
    assert(J.ShouldStayAndRegen(bot) == false,
        'the SHIPPED guard already holds jakiro on this frame -- then there is '
        .. 'no defect here and this file is measuring nothing')
    arm(true)
    assert(J.ShouldStayAndRegen(bot) == true,
        'armed, the guard still releases jakiro -- the lever does not reach '
        .. 'its own witnessed frame (the low-HP-chase lesson: a gate test can '
        .. 'pass while the fix misses the frame that motivated it)')
end

tests['[frame] the untouched clauses are why this is one lever'] = function()
    local J, bot = frame(FX, SUBJ)
    -- The 1200 ring: empty, so the lever is not overriding it. Honest bound (2)
    -- lives here -- the nearest enemy is a charging spirit_breaker at ~1,556,
    -- outside that ring TODAY, with or without this change.
    assert(#J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0,
        'the shipped 1200 ring is occupied on this frame, so the guard would '
        .. 'answer false regardless and the flip above has another cause')
    local hSb = enemy_named(J, bot, NEAR)
    assert(hSb ~= nil, NEAR .. ' is not on this frame')
    local dSb = GetUnitToUnitDistance(bot, hSb)
    assert(dSb > 1200 and dSb < 2000, NEAR .. ' is '
        .. string.format('%.0f', dSb) .. ' units off; honest bound (2) was '
        .. 'written about ~1,556 and needs re-reading')
    -- He is NOT the damage source -- which is exactly why the attributed scan
    -- is right to ignore him, and exactly why bound (2) is a bound and not a
    -- refutation.
    assert(not bot:WasRecentlyDamagedByHero(hSb, 3.0),
        NEAR .. ' did deal damage here, so the attributed scan should have '
        .. 'kept the veto and the flip is wrong')
end

tests['[frame] the frame P2 pins: the veto fires with nobody near her'] = function()
    -- Bound (3): lina's whole-function answer does not flip, so this asserts
    -- only the clause the lever owns. Stated as its own test so the difference
    -- between "the lever acts here" and "the defect is here" stays visible.
    local J, bot, arm = frame(FX, SUBJ2)
    assert(bot:WasRecentlyDamagedByAnyHero(3.0),
        'the blind read is false for lina -- P2\'s pinned frame no longer shows '
        .. 'the defect shape')
    assert(not J.HasNearbyHeroDamager(bot, 3000, 3.0),
        'someone inside 3000 hit lina -- her frame is not the global-ult case')
    local nNear = -1
    for _, h in pairs(J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(h) then
            local d = GetUnitToUnitDistance(bot, h)
            if nNear < 0 or d < nNear then nNear = d end
        end
    end
    assert(nNear > 6000, 'the nearest enemy to lina is '
        .. string.format('%.0f', nNear) .. ' units off; the shipped comment in '
        .. JMZ .. ' says 6,596 and is now wrong')
    -- And the honest half: it still answers false, on BOTH legs, downstream.
    arm(false)
    local a = J.ShouldStayAndRegen(bot)
    arm(true)
    local b = J.ShouldStayAndRegen(bot)
    assert(a == false and b == false,
        'lina\'s whole-function answer now moves -- honest bound (3) says it '
        .. 'does not (the supply clause stops her), and it must be rewritten '
        .. 'rather than quietly outgrown')
end

-- -------------------------------------------------- the corpus, as domain ---

tests['[census] the lever only ever removes vetoes'] = function()
    -- The direction is fixed by construction (an added disjunct can only make
    -- the veto condition harder to satisfy), and this is the assertion that
    -- says so about the TREE rather than about the argument. Its whole content
    -- is a zero, so it stays an equality: it must go red the moment a corpus
    -- frame contradicts it.
    assert(C('flip_true_to_false') == 0,
        C('flip_true_to_false') .. ' frame(s) went TRUE -> FALSE when armed; '
        .. 'this lever is supposed to be monotone')
    assert(C('raises') == 0, C('raises')
        .. ' frame(s) raised inside the guard -- a census of a function that '
        .. 'errors is a census of the pcall, not of the behaviour')
    assert(C('arm_true') >= C('ship_true'), 'the armed TRUE set (' ..
        C('arm_true') .. ') is not a superset of the shipped one ('
        .. C('ship_true') .. ')')
end

tests['[census] the domain price, and the partition that keeps it honest'] = function()
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    -- The blind read fires on 95 of 1012 frames; on 88 of those the damage IS
    -- attributable to someone inside 3000, so the lever is inert there. That
    -- 88 is the load-bearing number of this whole change: the shipped clause is
    -- RIGHT more than nine times out of ten, which is why it is narrowed rather
    -- than deleted.
    cs.ratchet(C('anyhero'), 95, 'frames the blind hero-damage read vetoes')
    cs.ratchet(C('attributed'), 88, 'of those, damage from inside 3000')
    cs.ratchet(C('unattributed'), 7, 'of those, damage from nobody nearby')
    assert(C('anyhero') == C('attributed') + C('unattributed'),
        'the attributed/unattributed split does not cover the veto frames')
    -- The lever's own situation, partitioned in the function's clause order.
    -- Counted out rather than inferred by subtraction, so that "the lever is
    -- inert here" and "the situation is rare" can never be read off the same
    -- number (铁律 4(iii): register which cut produced the effect size).
    assert(C('unattributed') == C('flips') + C('unattr_out_of_band')
        + C('unattr_blocked_ring') + C('unattr_blocked_supply'),
        'the four buckets do not sum to the unattributed frames -- the '
        .. 'partition is not a partition')
    cs.ratchet(C('flips'), 1, 'frames where the guard flips false -> true')
    cs.ratchet(C('unattr_out_of_band'), 2, 'unattributed frames outside the HP band')
    cs.ratchet(C('unattr_blocked_supply'), 4,
        'unattributed frames the supply clause still stops')
    -- ⚠️ THIS ZERO IS VACUOUS, AND SAYING SO IS THE POINT. Not one of the five
    -- in-band unattributed frames had anybody inside the untouched 1200 ring.
    -- Read carelessly that is "the ring covers the case honest bound (1) hands
    -- to it". It is not: it is "no measured frame put the ring to work". The
    -- distinction is not rhetorical -- the mutation stand's M10 makes that
    -- branch unreachable and CANNOT BE CAUGHT on this corpus, which is the
    -- proof that the bucket is empty rather than protective. Registered as an
    -- UNMEASURABLE in tools/agent/mutstand_stayattr.sh rather than papered over.
    --
    -- So the reachability is asserted separately from the count: the branch was
    -- entered on every in-band unattributed frame, and answered zero each time.
    -- The day a fixture lands a ring-occupied one, this bucket stops being
    -- vacuous and the bound acquires real support -- and `ratchet` will say so.
    assert(C('unattr_ring_tested')
        == C('unattributed') - C('unattr_out_of_band'),
        'the 1200-ring branch was entered on ' .. C('unattr_ring_tested')
        .. ' frames but ' .. (C('unattributed') - C('unattr_out_of_band'))
        .. ' in-band unattributed frames exist -- the ring bucket is a zero '
        .. 'about a branch, not about the world (the GH #171 shape)')
    assert(C('unattr_blocked_ring') == 0, C('unattr_blocked_ring')
        .. ' unattributed frame(s) had an enemy inside the 1200 ring -- honest '
        .. 'bound (1) hands exactly that case to the untouched ring, and this '
        .. 'is the first corpus frame that can actually test the handover')
end

tests['[census] the arming is one id wide'] = function()
    -- The whole before/after rests on a stub that arms 'stayattr' and nothing
    -- else. If it armed more, any of the tree's other 140 live gate ids could
    -- move this guard's answer and the flip would still be reported as this
    -- lever's. Its whole content is a zero, so it stays an equality.
    --
    -- This assertion exists because the mutation stand's M8 -- widen the stub
    -- to `return armed` -- SURVIVED the stand's first run. Nothing in the suite
    -- could tell one id from all of them; on this corpus the two happened to
    -- produce identical numbers, which is exactly the condition under which a
    -- widened stub would never be noticed.
    assert(C('arm_leak') == 0, C('arm_leak')
        .. ' frame(s) saw a foreign soak id answer TRUE while the sweep was '
        .. "supposed to be arming only 'stayattr' -- the before/after is not "
        .. 'attributable to this lever')
end

tests['[census] the witnessed frame is the one the corpus sweep names'] = function()
    -- The frame above is hand-picked; this closes the loop by requiring the
    -- independent full-corpus sweep to name the same one. A hand-picked frame
    -- the census cannot see would mean the two instruments disagree.
    local seen = false
    for _, f in ipairs(M.flips) do
        if f.fixture == FX:match('([^/]+)%.lua$') and f.hero == SUBJ then
            seen = true
            assert(f.near > 1200 and f.near < 2000,
                'the sweep puts the nearest enemy at '
                .. string.format('%.0f', f.near) .. ' on the witnessed frame')
        end
    end
    assert(seen, 'the corpus sweep does not name the witnessed frame '
        .. FX .. ' / ' .. SUBJ)
    -- And P2's own hero is named by the sweep as a defect-shape frame the
    -- supply clause stops -- bound (3) as a measurement, not a footnote.
    local seen2 = false
    for _, u in ipairs(M.unattr) do
        if u.fixture == FX:match('([^/]+)%.lua$') and u.hero == SUBJ2 then
            seen2 = true
            assert(u.bucket == 'unattr_blocked_supply',
                'the sweep files lina under ' .. u.bucket
                .. ', honest bound (3) says the supply clause stops her')
        end
    end
    assert(seen2, 'the corpus sweep no longer names lina on ' .. FX
        .. ' as a defect-shape frame -- honest bound (3) is unsourced')
end

return tests
