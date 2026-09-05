-- [midsupint 2026-09-05, 协同组] GH #503: the mirror now asks the TP-channel
-- interrupt guard about the ally it is about to hand the team's response slot to.
--
-- ⭐ WHY THIS COULD BE WRITTEN TODAY AND NOT YESTERDAY, which is the reusable
-- part. tests/test_midsupmirror_checkability.lua priced §EF.7's four missing
-- mirror members and found all four unwitnessable on this corpus -- this one
-- BY RAISE: J.CanEnemyInterruptTpChannel extrapolates every nearby enemy, the
-- fixture mock did not stub GetExtrapolatedLocation, and the guard raised on
-- 257 of its 257 in-domain frames. Charter step 2 forbids landing a behaviour
-- change whose only evidence is that it compiles, so the member stayed
-- unwritten and the pricing was registered as a [ratchet] instead of archived
-- as a conclusion. The unblocking repair then happened in the HARNESS (GH #492,
-- director, test_set.md §EL) -- somewhere no item on this stream's own backlog
-- was watching. The ratchet fired on the next run and named the leg. That is
-- the whole argument for ratcheting a negative result rather than filing it.
--
-- WHAT IS ASSERTED HERE. Not gate plumbing: the real predicate is driven on real
-- frames, and the CAUSE of its new answer is read off the frame rather than
-- asserted as a string. Two independently-sourced frames, different games,
-- different heroes, so a single fixture's quirk cannot be the whole finding.
--
-- ⚠️ STANDING LIMIT, inherited from the mock repair and restated so it is not
-- lost: a fixture is one instant and carries no velocity, so the mock models
-- every unit as standing still. Only the guard's `nNow <= nReach` clause ("an
-- enemy can strike me where I stand") is reachable here; the "it is closing the
-- gap on me" clause is not. Every count below is therefore a LOWER BOUND on
-- interruption. That model is declared in tests/mock/replay_fixture.lua and
-- measured by tests/test_fixture_extrapolation_mock.lua, so it goes red rather
-- than quiet on the day a fixture carries motion.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_midsupint_sweep.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

-- The witnessed frame. Core slardar is 15,747 from the tower it would answer --
-- past the responder loop's own far floor, so this is a reachable decision
-- instant and not merely a pair the predicate happens to accept. The ONLY
-- support the pre-repair mirror offers for that tower is skywrath_mage at 24% HP
-- with axe 188 away (reach 300): inside striking distance, so the channel dies
-- and the front goes unanswered by anyone at all.
local FX      = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'
local SUBJ    = 'npc_dota_hero_slardar'
local REJECT  = 'npc_dota_hero_skywrath_mage'
local TOWER_X, TOWER_Y = 4860, -6379
-- Independently sourced: different fixture, different game, different heroes.
local FX2     = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua'
local SUBJ2   = 'npc_dota_hero_zuus'
local REJECT2 = 'npc_dota_hero_earthshaker'
local TOWER2_X, TOWER2_Y = -5275, 6036

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
    local m = { g = {}, c = {}, flips = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local ff, fh, fx, fy, fr =
            line:match('^F (%S+) (%S+) (%-?%d+) (%-?%d+) (%S+)$')
        if ff ~= nil then
            m.flips[#m.flips + 1] = { fixture = ff, hero = fh,
                x = tonumber(fx), y = tonumber(fy), rejected = fr }
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

-- Find the allied tower at a known location on the loaded frame.
local function tower_at(J, x, y)
    local tB = GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}
    for _, b in pairs(tB) do
        if J.IsValidBuilding(b)
            and string.find(b:GetUnitName(), 'tower') ~= nil then
            local loc = b:GetLocation()
            if math.abs(loc.x - x) < 1 and math.abs(loc.y - y) < 1 then return b end
        end
    end
    return nil
end

-- Re-run the mirror's member list WITHOUT the interrupt clause: the pre-repair
-- answer, which the tree can no longer produce (the repair carries no soak id --
-- see the source note; a second id under an already-gated consumer is the
-- pullcad trap). Named allies out, so the test can say WHO would have been sent.
local function pre_repair_accepts(J, bot, b)
    local names = {}
    local tP = GetTeamPlayers(GetTeam()) or {}
    for i = 1, #tP do
        local hAlly = GetTeamMember(i)
        if hAlly ~= nil and hAlly ~= bot
            and J.IsValidHero(hAlly) and hAlly:IsAlive()
            and J.GetPosition(hAlly) >= 4
            and hAlly:GetLevel() >= 6
            and not J.IsInTeamFight(hAlly, 1600)
            and not J.IsRetreating(hAlly)
            and GetUnitToUnitDistance(hAlly, b) > J.TP_RESPONSE_FAR_FLOOR then
            local tp = J.GetItem2(hAlly, 'item_tpscroll')
            local bt = J.GetItem2(hAlly, 'item_travel_boots')
            if (tp ~= nil and tp:IsFullyCastable())
                or (bt ~= nil and bt:IsFullyCastable()) then
                names[#names + 1] = hAlly:GetUnitName()
            end
        end
    end
    return names
end

-- --------------------------------------------------- the tree, as source ---

tests['[source] the conjunct is in the predicate, and carries no soak id'] = function()
    assert(M.g.MIRROR == 1, 'the sweep could not slice '
        .. 'J.HasAvailableSupportResponder out of ' .. JMZ)
    assert(M.g.MIRROR_INT == 1, 'the interrupt conjunct is no longer in '
        .. 'J.HasAvailableSupportResponder -- this whole file is stale')
    assert(M.g.MIRROR_FIGHT == 1, 'the IsInTeamFight leg left the predicate -- '
        .. 'the subsumption reading below is about a gate that is gone')
    -- The pullcad trap, as an assertion rather than as prose in a comment. The
    -- only consumer of this predicate is gated by 'midsupyield'; an id HERE
    -- would make the live condition a two-id conjunction, which freezes FALSE
    -- the day either id is promoted -- and check_armed_wiring.py would still
    -- call it WIRED, because it checks that a call site exists, not that the
    -- predicate can ever be true.
    assert(M.g.MIRROR_SOAKID == 0, 'a soak-candidate id appeared inside '
        .. 'J.HasAvailableSupportResponder. Its only call site is already gated '
        .. 'by IsSoakCandidate("midsupyield"), so this makes the live condition '
        .. 'a conjunction of two ids -- the pullcad trap (AGENTS.md). Gate the '
        .. 'CALL SITE, never this predicate')
    -- The guard really is the shipped, ungated one ('tpsafe2', promoted to a
    -- turbo default 2026-07-23) -- not a private copy that could drift.
    local src = read_file(JMZ)
    assert(src:find('function J.CanEnemyInterruptTpChannel( bot )', 1, true) ~= nil,
        'the guard this repair mirrors is gone from ' .. JMZ)
    assert(M.g.INT_R == 700, 'the narrow interrupt scan moved to '
        .. tostring(M.g.INT_R) .. ' -- re-read the census below')
    assert(M.g.FAR_FLOOR == 3500, 'the far floor moved to '
        .. tostring(M.g.FAR_FLOOR) .. ' -- re-read the census below')
end

-- ------------------------------------------------------- the corpus price ---

tests['[sweep] the subprocess ran to completion'] = function()
    assert(M.done, 'tests/_midsupint_sweep.lua did not print DONE -- every count '
        .. 'below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
    cs.ratchet(C('pairs_eval'), 7048, '(hero, tower) pairs')
end

tests['[instrument] the repaired shadow agrees with the shipped predicate'] = function()
    -- The census needs a PRE-repair answer the tree can no longer give, so it
    -- runs a shadow. A shadow can drift, and then the census measures only
    -- itself (the §EH lesson). The repaired half of the shadow is re-asked
    -- against the real predicate on every pair; this is that check.
    assert(C('shipped_disagrees') == 0, C('shipped_disagrees') .. ' of '
        .. C('pairs_eval') .. ' (hero, tower) pair(s) where the shadow and '
        .. 'J.HasAvailableSupportResponder disagree -- this census is not '
        .. 'measuring the shipped tree, and the flip count is not about the tree')
end

tests['[census] the conjunct changes the decision on real frames'] = function()
    -- The number that says this is a repair and not a no-op. The 0SLOT / slotarb
    -- / droppick family is three rounds of "the diff reads like a fix and
    -- measures byte-identical to the unfixed tree", so a repair that cannot show
    -- a flip is not landed on this stream.
    assert(C('flips') > 0, 'the conjunct never changes the mirror on any of the '
        .. C('pairs_eval') .. ' pairs -- it is a no-op on this corpus and must '
        .. 'not be landed on "it compiles"; re-read before re-baselining')
    cs.ratchet(C('flips'), 151, 'pairs where the conjunct flips the mirror')
    cs.ratchet(C('flip_frames'), 20, 'live frames carrying at least one flip')
    cs.ratchet(C('ship_true'), 2215, 'pairs the repaired mirror accepts')
    cs.ratchet(C('pre_true'), 2366, 'pairs the pre-repair mirror accepted')
    -- Direction, as arithmetic rather than as a claim in a comment: a conjunct
    -- can only SHRINK the accepted set, so armed yields on strictly fewer
    -- frames. A repair that grew the set would mean the clause was not added as
    -- a conjunct, and the "can only move toward shipped" note would be false.
    assert(C('ship_true') + C('flips') == C('pre_true'),
        'the accepted set did not shrink by exactly the flips: '
        .. C('ship_true') .. ' + ' .. C('flips') .. ' ~= ' .. C('pre_true')
        .. ' -- the clause is not acting as a conjunct')
    assert(C('ship_true') < C('pre_true'), 'the repaired mirror accepts at least '
        .. 'as much as the pre-repair one -- this cannot be a conjunct')
end

tests['[census] the new clause is not subsumed by the fight leg above it'] = function()
    -- ⭐ THE ALTERNATIVE EXPLANATION, measured instead of argued away. An enemy
    -- inside the 700 interrupt scan is very often also "a fight within 1600",
    -- and IsInTeamFight is applied one line earlier. If every ally the guard
    -- rejects were already rejected there, this conjunct would be decoration --
    -- exactly the shape the droppick round priced at 0/5932 the day before.
    assert(C('cand_int_raise') == 0, C('cand_int_raise') .. ' ally candidate(s) '
        .. 'make the guard RAISE. The mock lost GetExtrapolatedLocation (GH '
        .. '#492): a raise lands in the "not interrupted" bucket here, so the '
        .. 'flip count above is being taken on a censored corpus')
    cs.ratchet(C('cand'), 285, 'ally candidates reaching the interrupt clause')
    cs.ratchet(C('cand_int_true'), 20, 'candidates the guard rejects')
    cs.ratchet(C('blocked_fight_int_true'), 4, 'guard-true allies the fight leg '
        .. 'had already blocked')
    assert(C('cand_int_true') > C('blocked_fight_int_true'),
        'every ally the interrupt guard rejects was already blocked by '
        .. 'IsInTeamFight -- the conjunct is decoration on this corpus')
end

-- ------------------------------------------- the decision, driven on frames --

local function assert_frame(path, subj, rejected, tx, ty)
    local J, bot = rf.load(path, subj)
    -- Nothing in this predicate reads a soak id (asserted above); disarming
    -- everything makes that fact load-bearing rather than incidental.
    J.IsSoakCandidate = function() return false end
    assert(J.IsCore(bot), subj .. ' is not a core on ' .. path
        .. ' -- the yield this predicate feeds is core-only, so this frame is '
        .. 'no longer a decision instant')
    local b = tower_at(J, tx, ty)
    assert(b ~= nil, 'no allied tower at (' .. tx .. ',' .. ty .. ') on ' .. path
        .. ' -- the witnessed frame moved, re-read the census')

    -- 1. The pre-repair mirror accepted, and the ONLY support it offered is the
    --    one that cannot channel. Both halves matter: "it accepted" alone would
    --    leave open that some OTHER ally could have gone.
    local pre = pre_repair_accepts(J, bot, b)
    assert(#pre == 1 and pre[1] == rejected, 'the pre-repair mirror offered {'
        .. table.concat(pre, ',') .. '} for this tower, expected exactly {'
        .. rejected .. '} -- the frame changed, re-read before re-baselining')

    -- 2. The cause, read off the frame rather than asserted as a string: that
    --    ally has an enemy inside its own attack reach right now. The nil-guard
    --    lesson -- an assertion that passes for the wrong reason is not an
    --    assertion -- is why the reach comparison is driven here.
    local hAlly = nil
    local tP = GetTeamPlayers(GetTeam()) or {}
    for i = 1, #tP do
        local a = GetTeamMember(i)
        if a ~= nil and a:GetUnitName() == rejected then hAlly = a break end
    end
    assert(hAlly ~= nil, rejected .. ' is not on the team on this frame')
    local near = J.GetNearbyHeroes(hAlly, 700, true, BOT_MODE_NONE) or {}
    assert(#near > 0, rejected .. ' has no enemy inside the interrupt scan -- '
        .. 'this frame no longer exercises the guard')
    local bInReach = false
    for _, e in ipairs(near) do
        local d = J.GetLocationToLocationDistance(hAlly:GetLocation(), e:GetLocation())
        if d <= e:GetAttackRange() + 150 then bInReach = true end
    end
    assert(bInReach, 'no enemy is within its own attack reach of ' .. rejected
        .. ' -- the guard must be answering true for the OTHER clause, which the '
        .. 'standing-still mock cannot reach; re-read this frame')
    local okg, ans = pcall(J.CanEnemyInterruptTpChannel, hAlly)
    assert(okg, 'the guard raises on ' .. rejected .. ': ' .. tostring(ans))
    assert(ans == true, 'the guard answers ' .. tostring(ans) .. ' about '
        .. rejected .. ' -- it is not the reason this frame flips')

    -- 3. THE DECISION. The shipped tree now refuses to hand the slot to it, and
    --    with no other candidate the mirror answers false -- so the core keeps
    --    the response instead of yielding it to a hero who cannot arrive.
    assert(J.HasAvailableSupportResponder(bot, b) == false,
        'the repaired mirror still accepts a support for this tower, and the '
        .. 'only candidate is ' .. rejected .. ', who is being struck right now')
    return J, bot, b
end

tests['[frame] a 24%-HP support being hit at melee range no longer takes the slot'] = function()
    local J, bot, b = assert_frame(FX, SUBJ, REJECT, TOWER_X, TOWER_Y)
    -- This frame is a REACHABLE decision, not merely an accepted pair: the core
    -- is past the responder loop's own far floor, which is the distance test the
    -- yield's call site sits behind.
    assert(GetUnitToUnitDistance(bot, b) > J.TP_RESPONSE_FAR_FLOOR,
        'the core is inside the far floor on this frame, so the yield is not '
        .. 'reachable here -- pick another witnessed frame')
    -- And the hero really is in the state the finding describes.
    local tP = GetTeamPlayers(GetTeam()) or {}
    for i = 1, #tP do
        local a = GetTeamMember(i)
        if a ~= nil and a:GetUnitName() == REJECT then
            assert(a:GetHealth() / a:GetMaxHealth() < 0.30, REJECT
                .. ' is no longer at low health on this frame -- the witnessed '
                .. 'case was a 24% support being struck; re-read')
        end
    end
end

tests['[frame] independently on a second game, hero and tower'] = function()
    assert_frame(FX2, SUBJ2, REJECT2, TOWER2_X, TOWER2_Y)
end

tests['[census] the witnessed frames are the ones the corpus sweep names'] = function()
    -- The two frames above are hand-picked; this closes the loop by requiring
    -- the independent full-corpus sweep to name the same pairs. A hand-picked
    -- frame that the census cannot see would mean the two instruments disagree.
    local seen1, seen2 = false, false
    for _, f in ipairs(M.flips) do
        if f.fixture == FX:match('([^/]+)%.lua$') and f.hero == SUBJ
            and f.x == TOWER_X and f.y == TOWER_Y then
            seen1 = true
            assert(f.rejected == REJECT, 'the sweep names ' .. f.rejected
                .. ' as the rejected support, this file says ' .. REJECT)
        end
        if f.fixture == FX2:match('([^/]+)%.lua$') and f.hero == SUBJ2
            and f.x == TOWER2_X and f.y == TOWER2_Y then
            seen2 = true
            assert(f.rejected == REJECT2, 'the sweep names ' .. f.rejected
                .. ' as the rejected support, this file says ' .. REJECT2)
        end
    end
    assert(seen1, 'the corpus sweep does not name the primary witnessed pair')
    assert(seen2, 'the corpus sweep does not name the second witnessed pair')
end

return tests
