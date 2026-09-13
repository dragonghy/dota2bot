-- Replay-fixture regression for soak candidate 'dusttower' (GH #441 family).
--
-- THE FRAME: game 20260820_043120_slot1, t=398.5, subject Viper (radiant,
-- TEAM_RADIANT=2). Real dump ground truth, no invented world:
--   * Spirit Breaker (dire, 47% HP) stands 174.3u from a RADIANT tower -- i.e.
--     right on top of OUR tower -- and has no dire tower within 700;
--   * Ember Spirit (dire, 33% HP) stands 406.7u from a DIRE tower -- i.e.
--     under ITS OWN tower -- and has no radiant tower within 700.
--
-- THE DEFECT the frame pins: the dust branch's dive guard in
-- bots/ability_item_usage_generic.lua called
--     local nEnemyTowers = enemyHero:GetNearbyTowers(700, true)
-- and refused to dust while that list was non-empty. GetNearbyTowers answers
-- RELATIVE TO THE UNIT IT IS CALLED ON, so on an enemy handle `true` means
-- "towers hostile to the enemy" = OURS. On this one frame that makes the
-- shipped guard answer backwards on BOTH enemies at once: it blocks the dust
-- that our own tower would cash in, and it waves through the dive onto a 33%
-- Ember under the defender's tower.
--
-- WHAT IS PINNED AND WHAT IS NOT. This pins the GUARD'S READING on the real
-- frame, which is the whole of the lever. It does NOT reproduce a completed
-- dust cast: J.IsUnitWillGoInvisible is false for every hero on this frame
-- (nobody is fading out), and that precondition is stated here rather than
-- simulated -- asserted below so the day a fixture does carry one, this note
-- is what fails. The load-bearing claim is the source argument on
-- J.IsDustDiveBlocked; the frame nails one instant of it to real positions.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_260820_043120_viper_defend_poked.lua'
local SB = 'npc_dota_hero_spirit_breaker'
local EMBER = 'npc_dota_hero_ember_spirit'
local LION = 'npc_dota_hero_lion'

local tests = {}

local function frame()
    return rf.load(FIXTURE)
end

-- ---------------------------------------------------------------- ground truth

tests['[ground truth] the frame carries both tower shapes at once'] = function()
    local _, bot, heroes, fx = frame()
    assert(fx.self == 'npc_dota_hero_viper', 'subject moved: ' .. tostring(fx.self))
    assert(math.abs(fx.time - 398.5) < 0.05, 'frame instant moved: ' .. tostring(fx.time))
    assert(bot:GetTeam() == TEAM_RADIANT, 'subject must be radiant for the sides below')

    local sb, ember = heroes[SB], heroes[EMBER]
    assert(sb ~= nil and ember ~= nil, 'fixture lost one of the two witnesses')
    assert(sb:IsAlive() and ember:IsAlive(), 'both witnesses must be alive on the frame')
    assert(sb:GetTeam() == TEAM_DIRE and ember:GetTeam() == TEAM_DIRE,
        'both witnesses must be enemies of the subject')

    -- Spirit Breaker: our tower close, none of his own.
    local sbOurs = sb:GetNearbyTowers(700, true)
    local sbOwn = sb:GetNearbyTowers(700, false)
    assert(#sbOurs == 1 and sbOurs[1]:GetTeam() == TEAM_RADIANT,
        'SB must have exactly one RADIANT tower within 700')
    assert(GetUnitToUnitDistance(sb, sbOurs[1]) < 200,
        'SB must be right on our tower (dump: 174.3u)')
    assert(#sbOwn == 0, 'SB must have no dire tower within 700')

    -- Ember Spirit: his own tower close, none of ours.
    local emOurs = ember:GetNearbyTowers(700, true)
    local emOwn = ember:GetNearbyTowers(700, false)
    assert(#emOwn == 1 and emOwn[1]:GetTeam() == TEAM_DIRE,
        'Ember must have exactly one DIRE tower within 700')
    assert(#emOurs == 0, 'Ember must have no radiant tower within 700')
    assert(ember:GetHealth() / ember:GetMaxHealth() < 0.4,
        'the dive case is only interesting because Ember is low (dump: 33%)')
end

tests['[ground truth] nobody is fading out on this frame'] = function()
    -- The stated, not simulated, precondition of the branch this guard sits in.
    -- If a future fixture edit makes this true, the note at the top is stale.
    local J, _, heroes = frame()
    for name, h in pairs(heroes) do
        if h:IsAlive() then
            assert(J.IsUnitWillGoInvisible(h) ~= true,
                'frame now carries an invis-pending hero (' .. name .. '); '
                .. 'revisit the "what is not pinned" note at the top of this file')
        end
    end
end

-- ------------------------------------------------------- the decision, both ways

tests['shipped guard BLOCKS the best dust there is (enemy on our tower)'] = function()
    local J, _, heroes = frame()
    assert(J.IsDustDiveBlocked(heroes[SB], 700, false) == true,
        'shipped reading must refuse to dust an enemy standing on our own tower')
end

tests['armed guard PERMITS it'] = function()
    local J, _, heroes = frame()
    assert(J.IsDustDiveBlocked(heroes[SB], 700, true) == false,
        'armed reading asks the enemy tower ring, which is empty here')
end

tests['shipped guard WAVES THROUGH the dive (33% enemy under their tower)'] = function()
    local J, _, heroes = frame()
    assert(J.IsDustDiveBlocked(heroes[EMBER], 700, false) == false,
        'shipped reading sees no tower of OURS near Ember and allows the dive')
end

tests['armed guard BLOCKS it'] = function()
    local J, _, heroes = frame()
    assert(J.IsDustDiveBlocked(heroes[EMBER], 700, true) == true,
        'armed reading sees Ember under a dire tower and holds the dust')
end

tests['the inversion is not a one-hero accident: Lion repeats SB'] = function()
    local J, _, heroes = frame()
    local lion = heroes[LION]
    assert(lion ~= nil and lion:IsAlive() and lion:GetTeam() == TEAM_DIRE)
    assert(J.IsDustDiveBlocked(lion, 700, false) == true
        and J.IsDustDiveBlocked(lion, 700, true) == false,
        'a second enemy at our tower (dump: 328.0u) must read the same way')
end

-- --------------------------------------------------------------- gate-off parity

tests['[source-parity] unarmed equals the shipped expression on EVERY hero'] = function()
    -- Not just on the two witnesses: the whole roster, both alive and dead.
    -- The shipped expression is transcribed here once, and the transcription is
    -- the only thing this test trusts.
    local J, _, heroes = frame()
    local n = 0
    for name, h in pairs(heroes) do
        local shipped = h:GetNearbyTowers(700, true)
        local shippedBlocked = not (shipped == nil or #shipped == 0)
        assert(J.IsDustDiveBlocked(h, 700, false) == shippedBlocked,
            'unarmed reading diverged from the shipped expression on ' .. name)
        assert(J.IsDustDiveBlocked(h, 700, nil) == shippedBlocked,
            'a nil gate must read the same as false on ' .. name)
        n = n + 1
    end
    assert(n == 10, 'expected all 10 heroes of the frame, saw ' .. n)
end

tests['[counterfactual] a nil tower list reads "not blocked" on both legs'] = function()
    -- The `nEnemyTowers == nil` half of the shipped test. The mock never
    -- produces it (it always returns a table); the engine override does, for a
    -- non-hero self (bots/FunLib/aba_global_overrides.lua). Declared, not
    -- observed -- which is why it is stated here as its own case.
    local J, _, heroes = frame()
    local sb = heroes[SB]
    rawget(sb, '__spec').GetNearbyTowers = function() return nil end
    assert(J.IsDustDiveBlocked(sb, 700, false) == false
        and J.IsDustDiveBlocked(sb, 700, true) == false,
        'nil must never block, on either leg')
end

-- --------------------------------------------------------------------- census

local function slurp(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

-- Drop whole-line comments before counting. A census that reads prose is a
-- tripwire on the prose (the lesson tests/_towerfear_sweep.lua learned the
-- expensive way): the rationale above the wrapper NAMES the helper it gates,
-- and without this the "exactly once" count is 2 the moment anyone documents
-- the thing. Only full-line comments are stripped -- a trailing comment on a
-- code line cannot hide a call, and cutting at `--` would maul string literals.
local function code_only(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

tests['[census] one gate-resolution site, and the branch calls it'] = function()
    local usage = code_only(slurp('bots/ability_item_usage_generic.lua'))

    local named = 0
    for _ in usage:gmatch('J%.IsDustDiveBlocked') do named = named + 1 end
    assert(named == 1,
        'J.IsDustDiveBlocked must be named exactly once outside jmz_func.lua, saw ' .. named)

    local gated = 0
    for _ in usage:gmatch("IsSoakCandidate%(%s*'dusttower'%s*%)") do gated = gated + 1 end
    assert(gated == 1, "exactly one 'dusttower' gate expression expected, saw " .. gated)

    assert(usage:find('J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%(%s*\'dusttower\'%s*%)') ~= nil,
        'the gate must stay turbo-only')

    assert(usage:find('J%.IsDustDiveBlocked%(%s*hEnemy,%s*700,') ~= nil,
        'the 700u dive ring is the shipped radius and lives at the one gate site')

    assert(usage:find('if not DustDiveBlocked(enemyHero)', 1, true) ~= nil,
        'the dust branch must consult the wrapper')
    assert(usage:find('enemyHero:GetNearbyTowers(700, true)', 1, true) == nil,
        'the inverted call must be gone from the dust branch')
end

tests['[census] other GetNearbyTowers readers are untouched by this lever'] = function()
    -- venomancer:231 is the only other site that asks an ENEMY handle for the
    -- towers hostile to it -- and there it is correct: it goes on to check
    -- nInRangeTower[1]:GetAttackTarget() == enemyHero, i.e. "our tower is
    -- already shooting them". One lever at a time; this test is what makes
    -- "untouched" a claim instead of a hope.
    local venom = code_only(slurp('bots/BotLib/hero_venomancer.lua'))
    assert(venom:find('enemyHero:GetNearbyTowers(700, true)', 1, true) ~= nil,
        'venomancer:231 must still read the towers hostile to the enemy')
    assert(venom:find('nInRangeTower[1]:GetAttackTarget() == enemyHero', 1, true) ~= nil,
        'and must still be the "our tower is already on them" reader')
end

return tests
