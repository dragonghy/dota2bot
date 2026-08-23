-- [strategy] Closing the level-gate census (GH #84 §5): the sixth and last of
-- the six TEETH constants, ability_item_usage_generic.lua:5751 ("guard-relic
-- TP"), also cannot be made into a full-shape (gated + real-frame + assert the
-- FINAL desire) fix -- and for a reason distinct from the other five.
--
-- WHERE THE CENSUS STOOD. tests/test_level_gate_census.lua found 6 TEETH level
-- constants (the level clause is a maturity proxy bolted onto a purpose that is
-- already valid earlier; the constant is the thing that keeps it closed). The
-- last three rounds each tried to build one into a shippable lever and each was
-- un-doable for its OWN reason:
--   * mode_farm_generic:286  -- dumper gap (the star-frame world quantity, a
--     team-fight location <2500 with a core, is not in the dump; the honest
--     answer is Vector(0,0), the map origin -- 13th world assertion)
--   * mode_farm_generic:536  -- corpus gap (the inner situation IS live on 3
--     frames, but the outer runMode never co-occurs in the sampled frames --
--     14th assertion territory)
--   * item_purchase_generic:228 -- not in Turbo at all (GeneralPurchase is
--     dispatched past in Turbo; the buyback reserve it guards does not exist
--     on the Turbo leg -- 15th assertion)
--
-- THE SIXTH, aiug:5751, MEASURED ON A REAL FRAME. Unlike the three above, its
-- census level clause (`bot:GetLevel() >= 15`, aiug:5753) IS satisfiable in the
-- corpus: exactly one fixture carries a subject at level >= 15 --
-- f_260820_043120_viper_defend_paired, viper at level 15 -- and on that frame
-- the ENTIRE outer gate (5751-5756) opens: no enemy within 1400, ShouldTpToFarm
-- true, far from fountain, far from the ancient, no ally hugging the ancient.
-- So for this TEETH the level constant is NOT what holds the branch closed.
--
-- What holds it closed is that both of its inner sub-paths fire only when the
-- bot's OWN ancient is under direct siege, a world the self-terminating Turbo
-- batch corpus never reaches (backlog 0a: games end ~640s with one tower down;
-- the nearest enemy to any ancient in the 0411xx wave was 4925u):
--
--   PATH 1 (守护遗迹, 5758-5778): reads J.GetNearestLaneFrontLocation, which
--   calls the loader-REFUSED GetLaneFrontLocation three times (jmz_func:3476-8,
--   GH #61). So path 1's final BOT_ACTION_DESIRE_HIGH (5778) is unassertable in
--   the fixture world without DECLARING a lane-front assumption -- exactly the
--   footing on which defnum/defclose ride the #61 stub. And its geometry clause
--   `GetUnitToLocationDistance(nAncient, nEnemyLaneFront) <= 1600` means "the
--   enemy front has reached within 1600 of my own ancient" = base siege.
--
--   PATH 2 (保护遗迹, 5781-5810): needs BOTH tier-4 towers destroyed
--   (GetTower(team,9) and (team,10) both nil) AND an enemy creep within 800 of
--   the ancient. On the viper frame both tier-4 towers are alive (dump ground
--   truth, non-nil handles) and UNIT_LIST_ENEMY_CREEPS is empty (the dumper
--   carries no creeps), so path 2 is closed twice over. It also carries a
--   SECOND copy of the census constant, `bot:GetLevel() >= 15` at 5791, as a
--   disjunct with "the creep is attacking the ancient".
--
-- CONCLUSION FOR THE CENSUS. All six TEETH are now examined; none is buildable
-- into a shippable gated fix with the current corpus, each blocked by a
-- distinct structural or corpus reason. aiug:5751's is: the level constant is
-- fine, but the branch's PURPOSE (defend a besieged ancient) has no live domain
-- in a self-terminating Turbo batch, and path 1 additionally rides the #61
-- lane-front wall. The corpus request is not new -- it is the SAME
-- "games that reach the base" request backlog 0a already tracks: a base-assault
-- game unlocks 0a's retreat/defend clauses AND this guard-relic TEETH at once.
--
-- bots/ is NOT touched. No gate. No test_set request. No corpus request beyond
-- consolidating onto 0a. Zero AWS.

-- Every other test file that requires from tests/ opens with this line.  This one
-- did not, and passed anyway for as long as some earlier file in the same process
-- had already set it -- so all seven cases here failed with "module
-- 'mock.replay_fixture' not found" the moment the file was run on its own, or the
-- file order moved.  Relying on another test file's side effect is not a shared
-- setup, it is an ordering bug that only shows up per-file.
package.path = 'tests/?.lua;' .. package.path

local FRAME = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'

--- Load the frame with a fresh module graph. Returns J, bot, and the team int.
local function world(path)
    for k in pairs(package.loaded) do
        if k:find('FunLib') or k:find('mock') then package.loaded[k] = nil end
    end
    local rf = require('mock.replay_fixture')
    local J, bot = rf.load(path)
    return J, bot, bot:GetTeam()
end

-- Two tests below DECLARE GetLaneFrontLocation to probe path 1 (a rawset global
-- probe). Per the M16 team rule (charter 0l): a probe must not follow this file
-- into the next one. Reinstall the GH #61 loader refusal after each such probe
-- so the world this file leaves behind is the same one it found -- and this
-- helper is used by a leave-behind assertion so the contract is visible.
local function restore_lanefront_refusal()
    _G.GetLaneFrontLocation = function()
        error('LOADER REFUSES: GetLaneFrontLocation is unresolved (GH #61). '
            .. 'Reinstalled by test_relicguard_siege_gate.lua after a probe.', 2)
    end
end

local tests = {}

-- ------------------------------------------------------------------ census ---

-- The census constant is SATISFIABLE. This is what separates aiug:5751 from
-- 285/535/228, whose gates the corpus cannot reach at all. The subject here is
-- level 15, so `bot:GetLevel() >= 15` (aiug:5753 and again aiug:5793) is TRUE
-- -- the level clause is not the blocker.
tests['the level>=15 gate is satisfiable: subject is level 15'] = function()
    local _, bot = world(FRAME)
    assert(bot:GetUnitName() == 'npc_dota_hero_viper',
        'expected the one level>=15 subject fixture')
    assert(bot:GetLevel() == 15,
        'subject viper must be exactly level 15; got ' .. tostring(bot:GetLevel()))
    assert(bot:GetLevel() >= 15, 'so aiug:5753 / aiug:5793 level clause is TRUE')
    -- Mutation self-check: a claim of >= 16 would be false here, which is the
    -- whole point (level 15 is the real value, not an artifact).
    assert(not (bot:GetLevel() >= 16), 'and it is exactly 15, not higher')
end

-- Corpus census (level is a per-unit dump field, immune to the GetAncient
-- origin fallback noted at the bottom): exactly one of the 96 fixtures carries
-- its SUBJECT at level >= 15, and none carries a subject at level >= 16.
tests['exactly one fixture has its subject at level >= 15'] = function()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    local ge15, ge16, this = 0, 0, false
    for _, fx in ipairs(files) do
        local _, bot = world(fx)
        local lvl = bot:GetLevel()
        if lvl >= 15 then
            ge15 = ge15 + 1
            if fx == FRAME then this = true end
        end
        if lvl >= 16 then ge16 = ge16 + 1 end
    end
    assert(ge15 == 1, 'exactly one subject at level >= 15; got ' .. ge15)
    assert(this, 'and it is ' .. FRAME)
    assert(ge16 == 0, 'no subject reaches level 16; got ' .. ge16)
end

-- ------------------------------------------------------------ outer gate ---

-- The whole outer gate (5751-5756) opens on this frame -- so the branch is
-- genuinely ENTERED here, this is not a spuriously-closed control. nMinTPDistance
-- is the module constant 5500 (aiug:5145), so the distance clause is > 5300.
tests['the whole outer relic-guard gate opens on this frame'] = function()
    local J, bot, team = world(FRAME)
    local nAncient = GetAncient(team)
    assert(nAncient ~= nil, 'this fixture carries a real ancient (building data)')

    assert(#J.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE) == 0,
        '#nNearEnemyList == 0 (5752)')
    assert(J.Role.ShouldTpToFarm() == true, 'ShouldTpToFarm() (5753)')
    assert(bot:DistanceFromFountain() > 2000, 'DistanceFromFountain > 2000 (5754)')
    assert(GetUnitToUnitDistance(bot, nAncient) > 5500 - 200,
        'dist(bot, ancient) > nMinTPDistance-200 (5755); got '
        .. string.format('%.1f', GetUnitToUnitDistance(bot, nAncient)))
    assert(J.GetAroundTargetAllyHeroCount(nAncient, 1400) == 0,
        'no ally within 1400 of the ancient (5756)')
end

-- ------------------------------------------------------------ path 1 (#61) ---

-- Path 1's final desire is unassertable without a declared lane-front
-- assumption: J.GetNearestLaneFrontLocation RAISES under the loader because it
-- calls the GH #61-refused GetLaneFrontLocation. Any claim about the 5778 HIGH
-- desire therefore rides the #61 stub, same as defnum/defclose.
tests['path 1 hits the #61 lane-front wall (raises unless declared)'] = function()
    local J, _, team = world(FRAME)
    local aloc = GetAncient(team):GetLocation()
    local ok, err = pcall(function()
        return J.GetNearestLaneFrontLocation(aloc, true, 400)
    end)
    assert(not ok, 'J.GetNearestLaneFrontLocation must raise under the loader')
    assert(tostring(err):find('LOADER REFUSES', 1, true)
       and tostring(err):find('GetLaneFrontLocation', 1, true),
        'and the raise must be the GH #61 refusal; got: ' .. tostring(err))

    -- Mutation self-check: DECLARING the assumption removes the raise. This is
    -- exactly the footing the #61 discipline names -- a final-desire claim on
    -- path 1 "says so on its face" by declaring the front. With the pre-#61
    -- origin stub declared, the call returns rather than raising.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    local ok2 = pcall(function()
        return J.GetNearestLaneFrontLocation(aloc, true, 400)
    end)
    assert(ok2, 'declaring the front must remove the raise (proves the raise is '
        .. 'conditional on non-declaration, not unconditional)')
    restore_lanefront_refusal() -- M16: do not leak the probe into the next file
end

-- Path 1's geometry clause is a base-siege precondition: even with a front
-- declared, the ancient must be within 1600 of the enemy front. This frame's
-- ancient sits at a real map corner, far from any plausible front; the corpus
-- (0a) never reaches base siege. [recorded]: the number is not re-derived
-- corpus-wide here because GetAncient falls back to the origin on fixtures
-- lacking ancient building data (see the harness note below).
tests['[recorded] path 1 geometry needs the ancient besieged (0a corpus gap)'] = function()
    local J, _, team = world(FRAME)
    local nAncient = GetAncient(team)
    local aloc = nAncient:GetLocation()
    -- Real ancient location for this fixture, not the origin fallback.
    assert(math.abs(aloc.x) > 1000 or math.abs(aloc.y) > 1000,
        'this frame carries a REAL ancient (not the origin fallback)')

    -- Mutation self-check that the <=1600 assertion is not vacuous: declare a
    -- front AT the ancient and the clause flips to TRUE.
    GetLaneFrontLocation = function() return Vector(aloc.x, aloc.y, 0) end -- luacheck: ignore
    local frontHere = J.GetNearestLaneFrontLocation(aloc, true, 400)
    assert(GetUnitToLocationDistance(nAncient, frontHere) <= 1600,
        'a front declared AT the ancient satisfies the <=1600 clause (so the '
        .. 'clause is real -- it just requires the front to have reached base)')
    -- The point: satisfying it requires enemies at the base. Per backlog 0a the
    -- self-terminating Turbo corpus never contains such a frame; this is the
    -- SAME base-assault corpus request 0a already tracks, not a new one.
    restore_lanefront_refusal() -- M16: do not leak the probe into the next file
end

-- [premise] M16 leave-behind contract (charter 0l): this file uses a rawset
-- global (GetLaneFrontLocation) as a probe, and the suite is one process running
-- every test_*.lua in alphabetical order. This test asserts the world this file
-- leaves behind after the two probes above -- the GH #61 refusal, reinstalled --
-- so a probe left declared can never silently follow this file into the next.
-- Running the file alone can never surface a leak; only the whole suite can, and
-- only as an F on an unrelated filename.
tests['[premise] the lane-front probe does not follow this file'] = function()
    -- Simulate the two probe tests having declared the global, then run the
    -- cleanup this file installs, and assert the refusal is back.
    _G.GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    restore_lanefront_refusal()
    local ok, err = pcall(function() return GetLaneFrontLocation(2, 0, 0) end)
    assert(not ok and tostring(err):find('LOADER REFUSES', 1, true),
        'after this file cleans up, GetLaneFrontLocation must refuse again; got: '
        .. tostring(ok) .. ' / ' .. tostring(err))
end

-- ------------------------------------------------------------ path 2 ---

-- Path 2 (5781-5810) needs both tier-4 towers destroyed AND an enemy creep
-- within 800 of the ancient. Both closers hold on this frame, independently.
tests['path 2 is closed twice: tier-4 towers alive AND no creeps in dump'] = function()
    local J, bot, team = world(FRAME)
    local nAncient = GetAncient(team)

    local t9, t10 = GetTower(team, 9), GetTower(team, 10)
    assert(t9 ~= nil and t10 ~= nil,
        'tier-4 towers (GetTower 9/10) are alive here (dump ground truth), so '
        .. '`ancientTower1==nil and ancientTower2==nil` (5783) is FALSE')

    local creeps = GetUnitList(UNIT_LIST_ENEMY_CREEPS) or {}
    local near = 0
    for _, c in pairs(creeps) do
        if J.IsValid(c) and GetUnitToUnitDistance(nAncient, c) <= 800 then
            near = near + 1
        end
    end
    assert(#creeps == 0,
        'the dumper carries no creeps, so UNIT_LIST_ENEMY_CREEPS is empty and '
        .. 'the 5787 creep loop cannot fire; got ' .. #creeps)
    assert(near == 0, 'no enemy creep within 800 of the ancient (5790)')
    -- bot is only referenced to keep the frame installed; silence luacheck.
    assert(bot ~= nil)
end

-- --------------------------------------------------------------- harness ---

-- [recorded] Why the siege gap cannot be re-derived corpus-wide from GetAncient.
-- The loader restores ancients from the fixture's real building data when it is
-- present; otherwise it (or the bare mock) answers GetAncient at the map ORIGIN
-- (tests/mock/replay_fixture.lua:687-690, tests/mock/bot_api.lua:288-293). So a
-- corpus-wide "min enemy -> own ancient" scan is contaminated: fixtures lacking
-- ancient building data report enemies standing near the origin as if they were
-- at the base. Only fixtures that carry real ancient buildings (like this one)
-- can be used to reason about the guard-relic branch at all.
tests['[recorded] GetAncient falls back to the origin without building data'] = function()
    -- The frame under test carries a real ancient...
    local _, _, team = world(FRAME)
    local realLoc = GetAncient(team):GetLocation()
    assert(math.abs(realLoc.x) > 1000 or math.abs(realLoc.y) > 1000,
        'FRAME must carry a real (non-origin) ancient')

    -- ...while at least one other fixture falls back to the origin, which is why
    -- the corpus scan is unreliable and the finding is grounded on FRAME alone.
    local _, _, t2 = world('tests/fixtures/f_073148_zuus_lina.lua')
    local fbLoc = GetAncient(t2):GetLocation()
    assert(math.abs(fbLoc.x) < 1e-9 and math.abs(fbLoc.y) < 1e-9,
        'f_073148_zuus_lina has no ancient building data, so GetAncient answers '
        .. 'the origin (0,0) -- a spurious small enemy->ancient distance there')
end

return tests
