-- [GH #37 20260819] Where a rescue TP actually PUTS the responder -- pinned on
-- the three real frames the director made the acceptance triple.
--
-- The replay desk proved `lf_rescue` fires (~0.7x/game, arm B = 0, p ~ 0.008)
-- but that 10 of 11 rescues never reached the fight: the gate models a ~4s
-- arrival ("3s channel + a step", J.WillAllySurviveTpWindow) while the landing
-- point is J.GetNearbyLocationToTp = 575 units in front of the nearest ALIVE
-- friendly tower. An ally is under 35% HP with divers on it precisely because
-- it is far from its towers, so the two are negatively correlated and "a step"
-- measured out at a median 2289 units.
--
-- Per test_set.md 0b, an ACTION-class defect must be asserted on the action's
-- real consequence, not on the helper's return value. That was impossible until
-- now: `tests/mock/bot_api.lua` stubbed `GetTower` to nil, so under EVERY
-- fixture J.GetNearbyLocationToTp silently took its no-towers-left fallback and
-- answered the FOUNTAIN. These tests run on real frames that now carry the real
-- structures, so the landing point is the one the game computed.
--
-- NOTHING in bots/ changes here. `lf_rescue` is the variable under test in the
-- running bisect and the director froze its code until that verdict lands; this
-- round pins the frames and settles WHICH of the three candidate fixes can
-- work. Its headline result is negative: the distance threshold (candidate 1)
-- is falsified by these very frames.
--
-- Honest bounds:
--   * Hero move speed is the loader's nominal 300 for every unit. Real speeds
--     run ~285-330, which cannot flip any conclusion below: frame A is over its
--     budget by 4.6x, frame B by 2.9x, and frame C is under by 17x.
--   * `observed.died_after` and `observed.burst` are replay ground truth. The
--     dumper's DAMAGE events undercount (they miss ward/creep/summon damage),
--     so burst sums are a LOWER bound -- which biases J.WillAllySurviveTpWindow
--     toward "survives", i.e. against the point tests 3-4 make. The measured
--     survival times are taken from the death events and are exact.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- The acceptance triple (director, GH #37). Every number in `expect` was
-- reproduced independently from the .dem before being written down here.
local FRAMES = {
    {
        -- 20260819_123012_slot1 t=568.4. Death Prophet (pos 3, 77% HP) TPs for
        -- Dragon Knight, 33% HP with Sniper on him 13786 units away. DK dies
        -- 4.7s later; DP lands next to a tower 5623 units from the corpse and
        -- is pinned there for 12s by tpcommit.
        name = 'A far', verdict = 'reject',
        path = 'tests/fixtures/f_260819_123012_dk_rescue_far.lua',
        responder = 'npc_dota_hero_death_prophet',
        expect = { landing = 5623, died_after = 4.7 },
    },
    {
        -- 20260819_122930_slot1 t=201.3. Lina (pos 5, full HP) TPs for Lich,
        -- 32.5% with Venomancer + Bristleback on him. Lich dies 2.9s later --
        -- before the 3s channel even finishes.
        name = 'B doomed', verdict = 'reject',
        path = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua',
        responder = 'npc_dota_hero_lina',
        expect = { landing = 1579, died_after = 2.9 },
    },
    {
        -- 20260819_123546_slot1 t=145.4. Jakiro (pos 4) TPs for Axe, 25% with
        -- Chaos Knight + Crystal Maiden on him. Jakiro arrives in 5.1s and Axe
        -- lives. The ONE rescue in the wave that worked as designed -- it must
        -- keep working, or this is lanefix all over again.
        name = 'C works', verdict = 'allow',
        path = 'tests/fixtures/f_260819_123546_axe_rescue_ok.lua',
        responder = 'npc_dota_hero_jakiro',
        expect = { landing = 1746, died_after = nil },
    },
}

local NOMINAL_SPEED = 300  -- the loader's per-unit GetCurrentMovementSpeed
local CHANNEL = 3.0        -- TP channel, the half J.WillAllySurviveTpWindow models

--- The landing point the shipped wiring resolves for a rescue of `ally`, and
--- its distance to the ally. The fixture subject IS the ally, so GetTeam() is
--- already the rescuing team -- exactly the team whose towers the engine picks
--- from when the responder casts.
local function landing_distance(J, ally)
    local vLand = J.GetNearbyLocationToTp(ally:GetLocation())
    return J.GetLocationToLocationDistance(vLand, ally:GetLocation()), vLand
end

local function about(got, want, tol)
    return math.abs(got - want) <= (tol or 1.0)
end

tests['[GH #37] fixtures carry the real structures, so the landing point is real'] = function()
    for _, f in ipairs(FRAMES) do
        local J, ally, _, fx = rf.load(f.path)
        assert(fx.buildings ~= nil and #fx.buildings > 0,
            f.name .. ': fixture must carry the frame structures')
        local nTowers = 0
        for i = 0, 10 do
            if GetTower(GetTeam(), i) ~= nil then nTowers = nTowers + 1 end
        end
        assert(nTowers >= 9, f.name .. ': the rescuing team still had 9-11 towers '
            .. 'standing on this frame, got ' .. nTowers)
        local _, vLand = landing_distance(J, ally)
        local vFountain = J.GetTeamFountain()
        assert(J.GetLocationToLocationDistance(vLand, vFountain) > 1,
            f.name .. ': landing resolved to the FOUNTAIN -- that is the '
            .. 'no-towers-left fallback and means the towers did not reach '
            .. 'J.GetNearbyLocationToTp')
    end
end

tests['[GH #37] the rescue lands 5623 units from the ally it is rescuing'] = function()
    local f = FRAMES[1]
    local J, ally, heroes, fx = rf.load(f.path)
    local responder = heroes[f.responder]
    -- The frame really is the cross-map rescue shape the gate is written for.
    assert(GetUnitToUnitDistance(responder, ally) > 3500,
        'GetRescueTpTarget only considers allies further than 3500')
    assert(J.GetHP(ally) < 0.35, 'the ally must be under the genuine-danger bar')
    local nLanding = landing_distance(J, ally)
    assert(about(nLanding, f.expect.landing),
        ('landing distance to the ally: expected ~%d, got %.0f')
            :format(f.expect.landing, nLanding))
    -- The consequence, in the units the gate reasons in: the responder still
    -- has to WALK this after a 3s channel.
    local nArrival = CHANNEL + nLanding / NOMINAL_SPEED
    assert(nArrival > 20, 'arrival time should be over 20s, got '
        .. string.format('%.1f', nArrival))
    assert(fx.observed.died_after ~= nil and fx.observed.died_after < 5,
        'ground truth: the ally died in under 5s')
end

tests['[GH #37] the shipped survival gate passes all three frames'] = function()
    -- J.WillAllySurviveTpWindow is the only arrival-time check in the trigger.
    -- Fed with REAL frame state and ground-truth damage it says "yes, it will
    -- survive" on all three -- including the two that must be rejected. It
    -- separates nothing, because its 4.0s budget is spent entirely on the
    -- channel and never on the distance the responder has to cover.
    for _, f in ipairs(FRAMES) do
        local J, ally = rf.load(f.path)
        assert(J.WillAllySurviveTpWindow(ally) == true,
            f.name .. ': expected the shipped gate to pass this frame')
    end
end

tests['[GH #37] a landing-distance threshold CANNOT work (candidate 1 falsified)'] = function()
    -- The director's first candidate fix was "veto when the landing point is
    -- more than X from the ally", with the replay desk's distribution hinting
    -- at X somewhere in 1200-1600. These frames rule that family out: the frame
    -- that MUST be rejected lands CLOSER than the frame that MUST be allowed,
    -- so no threshold can separate them and every threshold that kills B also
    -- kills the one rescue in the wave that worked.
    local dist = {}
    for _, f in ipairs(FRAMES) do
        local J, ally = rf.load(f.path)
        dist[f.name] = landing_distance(J, ally)
        assert(about(dist[f.name], f.expect.landing),
            ('%s: expected landing ~%d, got %.0f')
                :format(f.name, f.expect.landing, dist[f.name]))
    end
    assert(dist['B doomed'] < dist['C works'],
        'the falsification rests on B landing closer than C; if a regenerated '
        .. 'fixture ever inverts this, the distance-threshold family is back on '
        .. 'the table and this test is the thing that must be revisited')
    -- Stated as the impossibility itself rather than as two magic numbers.
    local nWorst = math.max(dist['A far'], dist['B doomed'])
    assert(nWorst > dist['C works'] or dist['B doomed'] > dist['C works'],
        'no single ceiling separates {reject} from {allow}')
end

tests['[GH #37] arrival-vs-survival separates all three AS A CONCEPT (candidate 2)'] = function()
    -- The second candidate: stop hardcoding 4.0s and budget the walk from the
    -- landing point too, i.e. ask "will the ally still be there when I actually
    -- get there" instead of "will it still be there when I finish channelling".
    -- On these frames that is the discriminator, with room to spare in both
    -- directions -- IF the arrival window could be compared against the ally's
    -- true remaining life. It cannot: the gate's only survival estimate is
    -- GetEstimatedDamageToTarget vs current HP, and the test below shows what
    -- that estimate does once the window is widened. Read this test as "the
    -- QUANTITY separates", not "the implementable gate separates".
    for _, f in ipairs(FRAMES) do
        local J, ally, _, fx = rf.load(f.path)
        local nArrival = CHANNEL + landing_distance(J, ally) / NOMINAL_SPEED
        -- nil died_after = the ally was still alive at the end of the replay's
        -- ground-truth window, i.e. it survived far past any arrival time.
        local nSurvived = fx.observed.died_after or math.huge
        if f.verdict == 'reject' then
            assert(nSurvived < nArrival,
                ('%s must be rejected: ally survives %.1fs but arrival is %.1fs')
                    :format(f.name, nSurvived, nArrival))
        else
            assert(nSurvived > nArrival,
                ('%s must be allowed: ally survives %.1fs, arrival is %.1fs')
                    :format(f.name, nSurvived, nArrival))
        end
    end
end

--- Ground-truth hero damage actually dealt to the fixture subject within
--- `nSeconds` of the frame, from the observed.damage event timeline.
local function damage_within(fx, nSeconds)
    local nSum = 0
    for _, d in ipairs(fx.observed.damage or {}) do
        if d.t <= nSeconds then nSum = nSum + d.value end
    end
    return nSum
end

tests['[GH #37] widening the survival window VETOES the rescue that worked'] = function()
    -- Candidate 2 implemented as written -- pass the arrival time to
    -- GetEstimatedDamageToTarget instead of the hardcoded 4.0 -- is falsified by
    -- the same triple that falsified candidate 1, now that the fixtures carry
    -- the per-event damage timeline (observed.damage) rather than one window.
    --
    -- The gate asks `incoming(window) < ally HP`. At the ARRIVAL window:
    --   A  548 vs 430 HP -> veto   (correct)
    --   B   96 vs 225 HP -> allow  (wrong; must be rejected)
    --   C  258 vs 246 HP -> VETO   (wrong; this is the one rescue that worked)
    -- C survived on regeneration and a salve, which the gate does not model, so
    -- stretching its window from 4s to 8.8s converts the only good rescue in the
    -- wave into a refusal. Direction of the bound matters here: the dumper
    -- UNDERCOUNTS damage, so 258 is a floor -- more data can only make the veto
    -- of C more certain. The same undercount is why B's "allow" is the soft half
    -- of this result (Lich took 117 logged from all sources yet died at 2.9s).
    local WANT = {
        ['A far']    = { window = 21.7, reject = true },
        ['B doomed'] = { window = 8.3,  reject = true },
        ['C works']  = { window = 8.8,  reject = false },
    }
    local nWrong = 0
    for _, f in ipairs(FRAMES) do
        local J, ally, _, fx = rf.load(f.path)
        assert(fx.observed.damage ~= nil,
            f.name .. ': fixture must carry the damage timeline; regenerate it '
            .. 'with the current make_fixture.py')
        local w = WANT[f.name]
        -- The window really is the arrival time this frame computes.
        assert(about(CHANNEL + landing_distance(J, ally) / NOMINAL_SPEED,
            w.window, 0.1), f.name .. ': arrival window mismatch')
        local bVeto = damage_within(fx, w.window) >= ally:GetHealth()
        if bVeto ~= w.reject then nWrong = nWrong + 1 end
    end
    assert(nWrong == 2, 'expected the widened window to get 2 of the 3 frames '
        .. 'wrong, got ' .. nWrong)
    -- Stated on its own because it is the disqualifying half: whatever else a
    -- fix does, it must not refuse frame C.
    local J, ally, _, fx = rf.load(FRAMES[3].path)
    local nArrival = CHANNEL + landing_distance(J, ally) / NOMINAL_SPEED
    assert(damage_within(fx, nArrival) >= ally:GetHealth(),
        'C: the widened window must be shown to veto the working rescue, or '
        .. 'candidate 2 is back on the table and tpdead needs re-justifying')
    assert(damage_within(fx, 4.0) < ally:GetHealth(),
        'and the SHIPPED 4.0s window must still allow it -- otherwise the '
        .. 'widening is not what flips this frame')
end

tests['[GH #37] pre-buildings fixtures keep the old structure-less world'] = function()
    -- Guards the 427 existing tests: a fixture generated before make_fixture.py
    -- emitted `buildings` has no structures at all, so GetTower stays nil and
    -- J.GetNearbyLocationToTp keeps answering the fountain exactly as it did.
    -- This assertion is also the record of the gap itself -- every landing-point
    -- question asked before this change was answered by that fallback.
    local J, bot, _, fx = rf.load('tests/fixtures/f_182552_warlock_ult_hoard.lua')
    assert(fx.buildings == nil, 'this fixture predates buildings capture')
    assert(GetTower(GetTeam(), 0) == nil, 'no towers without a buildings block')
    local vLand = J.GetNearbyLocationToTp(bot:GetLocation())
    assert(J.GetLocationToLocationDistance(vLand, J.GetTeamFountain()) < 1,
        'without structures the landing point degenerates to the fountain')
end

return tests
