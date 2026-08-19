-- [GH #15 / backlog "final-bid reachability", midtp+suptp] tparrive: judge the
-- collapse as of ARRIVAL, not as of now.
--
-- The defect is arithmetic, not a threshold. J.ShouldTpSupportTowerFight demands
-- the responder be > 3500 from the threatened tower and picks its target from
-- the enemies within 1200 of that tower -- so the responder is at least 2300
-- units outside the 1200 radius J.SafeToCommitFight scores. Its "winnable-only,
-- never throw the TP into a lost fight" gate is therefore evaluated as if the TP
-- never happened: it asks whether the fight is already fine WITHOUT the
-- responder. Its own heat gate sharpens the inversion -- the ally it counts is
-- REQUIRED to be hurt or under hero fire.
--
-- Consequence: the 1-ally-dived-by-2 collapse the fix exists to answer is
-- refused (1 >= 2 is false), while the 2v2 that needs nobody is allowed.
--
-- The acceptance triple is three real frames from ONE arm-A game
-- (20260819_183613_slot1, 16 ids armed, seeds 863-866), all with the SAME
-- responder -- Storm Spirit, full HP, level 7, TP off cooldown, no enemy within
-- 1600 of him -- so nothing but the head count at the engage point differs
-- between them. Two of the three are 1.0 second apart.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FRAMES = {
    {
        -- t=309.4. Jakiro is at 38% under our own tower with two Dire heroes on
        -- him; Storm Spirit stands 7809 units away at full HP with a ready TP.
        -- Shipped reads 1 ally vs 2 enemies at the engage point and refuses.
        name = 'outnumbered', t = 309.4,
        path = 'tests/fixtures/f_260819_183613_storm_collapse_outnumbered.lua',
        shipped = false, armed = true,
    },
    {
        -- t=310.4 -- ONE SECOND later, same fight, same responder. By now no
        -- ally is left within 1200 of the target: 0 vs 2. Counting the arriving
        -- responder still loses (1 < 2), so armed must refuse this one too.
        -- This is what keeps the candidate from degenerating into "always go".
        name = 'lost', t = 310.4,
        path = 'tests/fixtures/f_260819_183613_storm_collapse_lost.lua',
        shipped = false, armed = false,
    },
    {
        -- t=378.9. A 2v2 at another of our towers -- shipped already says yes.
        -- Armed must be bit-identical here, including WHICH tower it answers.
        name = 'parity', t = 378.9,
        path = 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua',
        shipped = true, armed = true,
    },
}

--- One evaluation of the trigger on a real frame with `ids` armed.
---
--- Always a FRESH load: J.TryTakeTpResponseSlot is a module-level ledger that
--- the trigger CONSUMES on success, so a second call against the same world
--- would answer the quota, not the question under test.
local function run(f, ids)
    local J, bot, heroes, fx = rf.load(f.path)
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    return J, bot, heroes, fx
end

local function trigger(f, ids)
    local J, bot = run(f, ids)
    return J.ShouldTpSupportTowerFight(bot), J, bot
end

-- ---- the frame facts every assertion below rests on --------------------------

tests['[frame] every precondition of the trigger holds, so only the gate differs'] = function()
    for _, f in ipairs(FRAMES) do
        local J, bot, _, fx = run(f, { 'midtp' })
        assert(math.abs(fx.time - f.t) < 0.05,
            f.name .. ': wrong frame, got t=' .. tostring(fx.time))
        assert(J.IsModeTurbo(), f.name .. ': the candidate is turbo-only')
        assert(bot:IsAlive() and bot:GetLevel() >= 6,
            f.name .. ': the responder must be a live level-6+ hero, got level '
            .. tostring(bot:GetLevel()))
        assert(J.IsInTeamFight(bot, 1600) == false,
            f.name .. ': the responder must be idle, not already fighting')
        assert(J.IsGoingOnSomeone(bot) == false,
            f.name .. ': and not already committed to a target')
        assert(J.IsRetreating(bot) == false, f.name .. ': and not retreating')
        local tp = J.GetItem2(bot, 'item_tpscroll')
        assert(tp ~= nil and tp:IsFullyCastable(),
            f.name .. ': the TP must be ready, or the trigger bails for a '
            .. 'reason unrelated to winnability')
        assert(J.CanEnemyInterruptTpChannel(bot) == false,
            f.name .. ': and nobody on his face to break the channel')
    end
end

--- The threatened front on a frame: the allied tower the trigger would answer,
--- rebuilt here from the same engine calls the helper makes.
local function front(J, bot)
    for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
        if J.IsValidBuilding(b)
        and string.find(b:GetUnitName(), 'tower') ~= nil
        and GetUnitToUnitDistance(bot, b) > 3500 then
            local vTower = b:GetLocation()
            local tEnemies = J.GetEnemiesNearLoc(vTower, 1200)
            if #tEnemies > 0 then
                for _, a in pairs(J.GetAlliesNearLoc(vTower, 1200)) do
                    if a ~= bot and J.IsValidHero(a)
                    and (a:WasRecentlyDamagedByAnyHero(3.0) or J.GetHP(a) < 0.75) then
                        return b, tEnemies[1], a
                    end
                end
            end
        end
    end
    return nil
end

tests['[frame] the responder is provably outside the radius the gate scores'] = function()
    -- The mechanism in one number. 3500 (trigger) - 1200 (target pick) = 2300 is
    -- the floor; if this ever stops holding the defect stops being structural.
    for _, f in ipairs(FRAMES) do
        local J, bot = run(f, { 'midtp' })
        local hTower, hTarget = front(J, bot)
        assert(hTower ~= nil, f.name .. ': the frame must carry a threatened front')
        local nGap = GetUnitToLocationDistance(bot, hTarget:GetLocation())
        assert(nGap >= 2300,
            f.name .. ': responder is ' .. string.format('%.0f', nGap)
            .. ' from the engage point; the gate only scores 1200')
        local bIn = false
        for _, a in pairs(J.GetAlliesNearLoc(hTarget:GetLocation(), 1200)) do
            if a == bot then bIn = true end
        end
        assert(bIn == false,
            f.name .. ': so the responder must NOT appear in its own count')
    end
end

tests['[frame] the ally being answered is hurt, exactly as the heat gate demands'] = function()
    -- Which is why the shipped count is systematically pessimistic: the one
    -- ally it is sure to count is the one taking the beating.
    for _, f in ipairs(FRAMES) do
        local J, bot = run(f, { 'midtp' })
        local _, _, hAlly = front(J, bot)
        assert(hAlly ~= nil, f.name .. ': a defended ally must be present')
        assert(hAlly:WasRecentlyDamagedByAnyHero(3.0) or J.GetHP(hAlly) < 0.75,
            f.name .. ': and it must satisfy the heat gate')
    end
end

tests['[frame] the three frames really are 1v2 / 0v2 / 2v2 at the engage point'] = function()
    local EXPECT = { outnumbered = { 1, 2 }, lost = { 0, 2 }, parity = { 2, 2 } }
    for _, f in ipairs(FRAMES) do
        local J, bot = run(f, { 'midtp' })
        local _, hTarget = front(J, bot)
        local vLoc = hTarget:GetLocation()
        local nA = #J.GetAlliesNearLoc(vLoc, 1200)
        local nE = #J.GetEnemiesNearLoc(vLoc, 1200)
        assert(nA == EXPECT[f.name][1] and nE == EXPECT[f.name][2],
            f.name .. ': expected ' .. EXPECT[f.name][1] .. 'v' .. EXPECT[f.name][2]
            .. ' at the engage point, got ' .. nA .. 'v' .. nE)
    end
end

-- ---- the defect --------------------------------------------------------------

tests['[defect] shipped refuses the dive and allows the fight that needs nobody'] = function()
    for _, f in ipairs(FRAMES) do
        local hTower = trigger(f, { 'midtp' })
        assert((hTower ~= nil) == f.shipped,
            f.name .. ': shipped should ' .. (f.shipped and 'respond' or 'refuse')
            .. ', got ' .. tostring(hTower ~= nil))
    end
end

tests['[defect] and it is the winnability gate that does it, nothing else'] = function()
    -- Pin the two predicates directly, so a future failure says WHICH half moved.
    local EXPECT = {
        outnumbered = { false, true },   -- refused now, safe on arrival
        lost        = { false, false },  -- refused now, still refused on arrival
        parity      = { true,  true },   -- already fine, unchanged
    }
    for _, f in ipairs(FRAMES) do
        local J, bot = run(f, { 'midtp' })
        local _, hTarget = front(J, bot)
        assert(J.SafeToCommitFight(bot, hTarget) == EXPECT[f.name][1],
            f.name .. ': SafeToCommitFight should be ' .. tostring(EXPECT[f.name][1]))
        assert(J.SafeToCommitFightOnArrival(bot, hTarget) == EXPECT[f.name][2],
            f.name .. ': SafeToCommitFightOnArrival should be '
            .. tostring(EXPECT[f.name][2]))
    end
end

-- ---- the fix -----------------------------------------------------------------

tests['[fix] armed tparrive answers the dive, still refuses the lost one'] = function()
    for _, f in ipairs(FRAMES) do
        local hTower = trigger(f, { 'midtp', 'tparrive' })
        assert((hTower ~= nil) == f.armed,
            f.name .. ': armed should ' .. (f.armed and 'respond' or 'refuse')
            .. ', got ' .. tostring(hTower ~= nil))
    end
end

tests['[fix] on the frame it already answered, armed picks the same tower'] = function()
    -- A superset must not REDIRECT an existing response to a different front.
    local f = FRAMES[3]
    local hShipped = trigger(f, { 'midtp' })
    local hArmed = trigger(f, { 'midtp', 'tparrive' })
    assert(hShipped ~= nil and hArmed ~= nil, 'parity: both arms respond')
    local a, b = hShipped:GetLocation(), hArmed:GetLocation()
    assert(a.x == b.x and a.y == b.y,
        'parity: armed answered a different tower ('
        .. string.format('%.0f,%.0f vs %.0f,%.0f', a.x, a.y, b.x, b.y) .. ')')
end

tests['[fix] the same holds for the support profile (suptp)'] = function()
    -- Both ids share this helper; suptp additionally needs position >= 4, which
    -- the loader cannot know, so drive it through the helper's own predicate.
    for _, f in ipairs(FRAMES) do
        local J, bot = run(f, { 'suptp', 'tparrive' })
        J.GetPosition = function() return 5 end
        assert((J.ShouldTpSupportTowerFight(bot) ~= nil) == f.armed,
            f.name .. ': suptp must behave like midtp under tparrive')
    end
end

-- ---- separability ------------------------------------------------------------

tests['[separability] tparrive alone changes nothing at all'] = function()
    -- It lives inside a helper that returns nil unless midtp or suptp is armed,
    -- so on its own it is a bit-for-bit no-op -- the same scheduling note
    -- tpdying and tpdead carry: never bisect it as an arm by itself.
    for _, f in ipairs(FRAMES) do
        assert(trigger(f, { 'tparrive' }) == nil,
            f.name .. ': tparrive without midtp/suptp must stay silent')
        assert(trigger(f, {}) == nil,
            f.name .. ': and so must a completely disarmed run')
    end
end

tests['[separability] armed can only ADD a response, never remove one'] = function()
    -- The structural claim behind the candidate: one more ally can only raise
    -- both branches of the gate. Checked on every frame, both profiles.
    for _, f in ipairs(FRAMES) do
        if f.shipped then
            assert(trigger(f, { 'midtp', 'tparrive' }) ~= nil,
                f.name .. ': armed dropped a response shipped already made')
        end
    end
end

tests['[separability] the arrival read never contradicts the shipped one'] = function()
    -- Same claim at the predicate level, and independent of the trigger's other
    -- conditions: SafeToCommitFight true must imply SafeToCommitFightOnArrival.
    for _, f in ipairs(FRAMES) do
        local J, bot = run(f, { 'midtp' })
        local _, hTarget = front(J, bot)
        if J.SafeToCommitFight(bot, hTarget) then
            assert(J.SafeToCommitFightOnArrival(bot, hTarget),
                f.name .. ': the superset property is broken')
        end
    end
end

-- ---- the caller: what the trigger's return actually becomes -------------------

tests['[final decision] a returned tower really does become a cast TP'] = function()
    -- Director SS 0b: assert the decision the engine sees, not the helper's
    -- return. The item-usage branch turns a non-nil tower into
    -- BOT_ACTION_DESIRE_HIGH with J.GetNearbyLocationToTp as the target, and its
    -- ONLY further condition is that the landing point exists. Pin that here on
    -- the real frame, and the absence of any other gate in the source below.
    local f = FRAMES[1]
    local J, bot = run(f, { 'midtp', 'tparrive' })
    local hTower = J.ShouldTpSupportTowerFight(bot)
    assert(hTower ~= nil, 'outnumbered: armed must return a tower')
    local vLand = J.GetNearbyLocationToTp(hTower:GetLocation())
    assert(vLand ~= nil and vLand.x ~= nil,
        'outnumbered: the landing point must exist, or the caller falls through')
end

tests['[final decision] the item-usage branch has no gate the helper cannot see'] = function()
    local fh = assert(io.open('bots/ability_item_usage_generic.lua', 'r'))
    local src = fh:read('*a')
    fh:close()
    local branch = src:match(
        'local hTowerFight = J%.ShouldTpSupportTowerFight%( bot %).-mid支援塔战')
    assert(branch, 'could not locate the mid-support TP branch')
    local _, nIf = branch:gsub('\n%s*if ', '')
    assert(nIf == 2,
        'the branch grew a condition between the helper and the cast (' .. nIf
        .. ' ifs, expected the tower test plus the landing-point test); this '
        .. 'test asserts the helper return reaches BOT_ACTION_DESIRE_HIGH')
    assert(branch:find('BOT_ACTION_DESIRE_HIGH', 1, true),
        'and that the branch still ends in the HIGH bid')
end

-- ---- the intent this candidate deliberately reverses --------------------------

tests['[intent] armed knowingly overturns the shipped no-fire-when-outnumbered rule'] = function()
    -- tests/test_mid_tp_support.lua pins the shipped rule in so many words: "a
    -- losing (outnumbered) tower fight must not pull a wasted TP", 1 defender vs
    -- 2 divers. That rule is what this candidate disputes, and the dispute is
    -- the arithmetic above -- 1v2 without the responder is 2v2 with it, under
    -- our own tower. Stated here so nobody promotes tparrive believing the two
    -- rules coexist: they do not, and the shipped test only stays green because
    -- the gate is off. If tparrive is ever promoted, that test must be rewritten
    -- rather than deleted.
    local hTower = trigger(FRAMES[1], { 'midtp', 'tparrive' })
    assert(hTower ~= nil,
        'the whole point of the candidate is that this outnumbered dive IS '
        .. 'answered once the responder counts itself')
    local J, bot = run(FRAMES[1], { 'midtp' })
    local _, hTarget = front(J, bot)
    local nA = #J.GetAlliesNearLoc(hTarget:GetLocation(), 1200)
    local nE = #J.GetEnemiesNearLoc(hTarget:GetLocation(), 1200)
    assert(nA + 1 == nE,
        'and only by exactly one body: ' .. nA .. '+1 must equal ' .. nE
        .. ', otherwise this is a bigger claim than the candidate makes')
end

-- ---- reverse assertion -------------------------------------------------------

tests['[reverse] this test expires loudly if the shipped gate is ever fixed'] = function()
    -- If someone makes J.SafeToCommitFight itself arrival-aware, the defect
    -- disappears and the candidate becomes dead weight. The [defect] case above
    -- would start failing -- this one states why, so the failure is legible.
    local J, bot = run(FRAMES[1], { 'midtp' })
    local _, hTarget = front(J, bot)
    assert(J.SafeToCommitFight(bot, hTarget) == false,
        'the shipped gate now clears the 1v2 dive on its own -- tparrive is '
        .. 'redundant and should be retired, not promoted')
end

return tests
