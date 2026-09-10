-- [ownhalf / replay-check 20260910] The (a)-evidence frame for 'ownhalf', on a
-- REAL armed-leg frame with NO synthesized geometry.
--
-- Match:  spot_20260909_212434_..._7eb1ba / 20260909_212625_slot7
--         script_version mirror:...,ownhalf,...:s10607:radiant
--         -> the armed leg is RADIANT, and the subject (lion) is team 2.
-- Frame:  t = 235.0, subject npc_dota_hero_lion (90.7% HP, level 4, 76% mana).
--
-- WHY THIS FRAME AND NOT AN AGGREGATE. Every band count this stream has
-- reported for 'ownhalf' is a FIRING UPPER BOUND, because the two clauses that
-- actually decide the punish -- J.SafeToCommitFight and
-- J.ShouldRefuseUnsupportedPunish -- are not evaluable from a behav-dump. A
-- fixture runs the real helpers on the real frame, so this test buys the half
-- the corpus cannot. (Report 20260910T065600Z named this exact frame as the
-- shortest path from INDETERMINATE to an execution verdict.)
--
-- Unlike tests/test_replay_ownhalf_standoff.lua, which DECLARES both ancients
-- and synthesizes the one allied tower, every distance below is read off the
-- fixture's own 38 buildings and real ancient coordinates.
--
-- What the bot could see at t=235 (asserted below, not declared):
--   * enemy drow_ranger  --  867.4u from lion, 41.5% HP,
--                            1469.4u from our nearest living building,
--                            invade depth 2885.7
--   * enemy pudge        -- 1555.8u from lion, 83.1% HP,
--                            2054.7u from our nearest living building,
--                            invade depth 3235.7
--   * ally  lina         --  649.4u from lion, 100% HP
-- Both enemies are OUTSIDE the shipped 1200-of-a-building domain, so the
-- shipped branch is structurally closed here -- the dead zone this candidate
-- exists to close, caught live rather than reconstructed.
--
-- ============================ WORLD LIMITATION ============================
-- DECLARED, because it decides how much this test is allowed to prove:
-- J.GetTotalEstimatedDamageToTarget reads 0.0 for every hero in this fixture
-- (the Get*-default-0 family the replay-fixture skill lists). So
-- SafeToCommitFight's branch (a), LETHAL, is structurally dead offline, and
-- every safe/unsafe result below is decided by branch (b), NUMBERS, on real
-- positions. Consequences, both directions:
--   * the `true` for drow is bought by REAL parity at the engage point -- real,
--     but narrower than the live helper, which could also pass on burst;
--   * the `false` for pudge is therefore an offline LOWER bound, not a claim
--     that the live game refuses him.
-- Do not promote this to "the discipline refuses pudge in play".
-- ==========================================================================
--
-- GROUND TRUTH from the same replay, for the record (this test asserts the
-- DECISION, not the outcome): lion cast on drow at t=232.2 and t=240.4; at
-- t=247.1 lion killed pudge and at t=248.2 lina killed drow -- 2 kills for 0
-- deaths among the collapsing pair within 13s of this frame.
-- ATTRIBUTION BOUND, stated so it is not over-read later: lion was ALREADY
-- casting at drow at t=232.2, i.e. 2.8s BEFORE this frame, so this frame shows
-- the gate SUSTAINING an engagement already underway. It is NOT evidence that
-- the gate initiated it.
--
-- MUTATION STAND (tools/agent/mutstand_ownhalf_frame.sh; run 2026-09-10):
--   M1  depth margin -> unreachable (>= 100000)      KILLED (2 fails)
--   M2  delete the SafeToCommitFight conjunct        KILLED (2 fails)
--   M3  margin reverted to the OLD constant 800      *** SURVIVED ***
-- M3's survival is a real limit of THIS frame and is declared, not patched
-- around: both invaders sit at depth 2885.7 and 3235.7, i.e. past 800 AND past
-- 1600, so this frame cannot separate the two margins and must not be cited as
-- guarding the constant. tests/test_ownhalf_margin.lua owns that property (it
-- asserts the three sibling margins are EQUAL). What this file buys instead is
-- the thing that test cannot: the commit clauses, evaluated live.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_20260909_212625_lion_235.lua'

local function loaded(armed)
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id)
        return armed and id == 'ownhalf'
    end
    return J, bot, heroes, fx
end

local function depthOf(J, bot, enemy)
    local own = GetAncient(bot:GetTeam())
    local ene = GetAncient(bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT)
    local loc = enemy:GetLocation()
    return J.GetLocationToLocationDistance(loc, ene:GetLocation())
         - J.GetLocationToLocationDistance(loc, own:GetLocation())
end

local function nearestAlliedBuilding(enemy)
    local best = math.huge
    for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS)) do
        local d = GetUnitToUnitDistance(enemy, b)
        if d < best then best = d end
    end
    return best
end

local function moveTo(unit, x, y)
    rawget(unit, '__spec').GetLocation = { x = x, y = y, z = 0 }
    rawset(unit, 'GetLocation', nil)
end

local function about(actual, expected, tol, what)
    assert(math.abs(actual - expected) <= (tol or 1.0),
        string.format('%s: expected ~%.1f, fixture reads %.1f', what, expected, actual))
end

local tests = {}

-- ---------------------------------------------------------------- world ----
-- These pin the frame, not the fix. If the dumper or the loader ever changes
-- what this fixture means, these fail FIRST, so the decision assertions below
-- cannot quietly start passing for a different reason.

tests['world: the frame is the one the report named (real geometry, nothing declared)'] = function()
    local J, bot, heroes = loaded(true)
    assert(bot:GetUnitName() == 'npc_dota_hero_lion', 'subject is lion')
    assert(bot:GetTeam() == 2, 'lion is team 2 (radiant) = the armed leg of this game')
    assert(J.IsModeTurbo(), 'ownhalf is turbo-only; the fixture must carry turbo')

    local own = GetAncient(bot:GetTeam())
    local ene = GetAncient(bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT)
    assert(own ~= nil and ene ~= nil, 'both ancients come from the fixture, not a stub')
    about(own:GetLocation().x, -5920, 1, 'own ancient x')
    about(ene:GetLocation().x, 5528, 1, 'enemy ancient x')

    assert(#GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) == 19,
        'the fixture carries our 19 living buildings; the shipped branch is '
        .. 'closed on this frame BECAUSE of real distances, not because the '
        .. 'list is empty (an empty list would close it for the wrong reason)')

    local drow, pudge = heroes['npc_dota_hero_drow_ranger'], heroes['npc_dota_hero_pudge']
    about(GetUnitToUnitDistance(bot, drow), 867.4, 1, 'lion->drow')
    about(GetUnitToUnitDistance(bot, pudge), 1555.8, 1, 'lion->pudge')
    about(nearestAlliedBuilding(drow), 1469.4, 1, 'drow->nearest allied building')
    about(nearestAlliedBuilding(pudge), 2054.7, 1, 'pudge->nearest allied building')
    about(depthOf(J, bot, drow), 2885.7, 1, 'drow invade depth')
    about(depthOf(J, bot, pudge), 3235.7, 1, 'pudge invade depth')
end

tests['world: both enemies sit in the dead zone (>1200 from every building of ours)'] = function()
    local _, _, heroes = loaded(true)
    for _, name in ipairs({ 'npc_dota_hero_drow_ranger', 'npc_dota_hero_pudge' }) do
        assert(nearestAlliedBuilding(heroes[name]) > 1200,
            name .. ' must be outside the shipped 1200 domain for this frame to '
            .. 'be about ownhalf at all')
    end
end

tests['world: the LETHAL branch is offline-dead here (declared, not assumed)'] = function()
    local J, _, heroes = loaded(true)
    for _, name in ipairs({ 'npc_dota_hero_drow_ranger', 'npc_dota_hero_pudge' }) do
        local tgt = heroes[name]
        local allies = J.GetAlliesNearLoc(tgt:GetLocation(), 1200)
        assert(J.GetTotalEstimatedDamageToTarget(allies, tgt) == 0,
            'if this ever reads non-zero the fixture gained damage estimates, '
            .. 'and the WORLD LIMITATION note at the top of this file -- plus '
            .. 'every "bought by numbers" claim below -- must be re-read')
    end
end

-- ------------------------------------------------------------- decision ----

tests['OFF: shipped decision on this untouched frame is nil (the dead zone)'] = function()
    local J, bot = loaded(false)
    assert(J.ShouldPunishDive(bot) == nil,
        'un-armed, two invaders 2885u and 3235u deep on our half -- both more '
        .. 'than 1200 from any building of ours -- are nobody to punish. This '
        .. 'is the hole, reproduced on a real frame.')
end

tests['ARMED: the gate fires and names drow_ranger'] = function()
    local J, bot, heroes = loaded(true)
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_drow_ranger'],
        'armed, the invader 867u away at parity is the collapse target')
end

-- ONE of the two clauses is genuinely evaluated here, and the file says which.
-- An earlier draft of this test asserted "the two offline-unreadable clauses
-- pass", which was a right answer resting on a wrong reason: with only
-- 'ownhalf' armed, J.ShouldRefuseUnsupportedPunish returns the literal false on
-- its SECOND LINE (jmz_func.lua:9134, `if not J.IsSoakCandidate('ohnum')`), so
-- its false is the identity element of the `and`, not a verdict about drow.
-- The wave this frame came from armed ownhalf and NOT ohnum, so inert is the
-- faithful reading of the game -- but inert must be asserted as inert.
tests['ARMED: SafeToCommitFight is the clause actually evaluated here'] = function()
    local J, bot, heroes = loaded(true)
    local drow = heroes['npc_dota_hero_drow_ranger']
    assert(J.SafeToCommitFight(bot, drow) == true,
        'J.SafeToCommitFight is the clause no behav-dump can evaluate; on this '
        .. 'frame it passes, which is what turns the band count into a real '
        .. 'firing rather than an upper bound')
end

tests['ARMED: the ohnum refusal is INERT here, by its own gate (not a verdict)'] = function()
    local J, bot, heroes = loaded(true)
    local drow = heroes['npc_dota_hero_drow_ranger']
    assert(J.ShouldRefuseUnsupportedPunish(bot, drow) == false,
        'with ohnum unarmed this must be the identity element')
    -- Same frame, same everything, ohnum additionally armed: it is NOT inert,
    -- and it deletes this punish. That is what proves the false above was the
    -- gate talking and not the world.
    local J2, bot2, heroes2 = rf.load(FIXTURE)
    J2.IsSoakCandidate = function(id) return id == 'ownhalf' or id == 'ohnum' end
    assert(J2.ShouldRefuseUnsupportedPunish(bot2, heroes2['npc_dota_hero_drow_ranger']) == true,
        'armed, ohnum refuses this collapse -- so the unarmed false was inertia')
end

-- Registered because it is the most consequential thing this frame knows, and
-- it is a COUNTERFACTUAL, not an observation: ohnum was not armed in this wave.
-- Ground truth for this exact frame is 2 kills for 0 deaths within 13s (see the
-- header), and ohnum would have deleted the punish that opened it. Measured on
-- the round's 7-frame sample: 4 frames fire under ownhalf, and ohnum deletes 3.
-- Mechanism: ohnum demands numbers ADVANTAGE among allies within 1200 of the
-- TARGET, and lina -- 649u from lion but ~1300u from drow -- is not counted, so
-- a real 2v1 reads as 1v1 parity. GH issue filed by replay-check 2026-09-10.
tests['counterfactual: arming ohnum deletes this punish'] = function()
    local J, bot, heroes = loaded(true)
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_drow_ranger'],
        'baseline: ownhalf alone fires')
    local J2, bot2 = rf.load(FIXTURE)
    J2.IsSoakCandidate = function(id) return id == 'ownhalf' or id == 'ohnum' end
    assert(J2.ShouldPunishDive(bot2) == nil,
        'ohnum deletes the collapse that the replay shows converting 2-for-0')
end

-- WHY drow passes and pudge does not -- the mechanism, so this is not a right
-- answer resting on a wrong reason. SafeToCommitFight scores heroes within
-- 1200 of the TARGET, not of the bot. Lion is 867u from drow (so he counts as
-- a committing ally, 1v1 parity -> pass) but 1555.8u from pudge (so he counts
-- as ZERO allies there, 0v1 -> refuse). HP is NOT the discriminator: measured
-- on this fixture, dropping pudge to 41.5% leaves him refused and raising drow
-- to 83.1% leaves him accepted.
tests['ARMED: pudge is refused for the DISTANCE reason, not the HP reason'] = function()
    local J, bot, heroes = loaded(true)
    local pudge = heroes['npc_dota_hero_pudge']
    assert(depthOf(J, bot, pudge) >= 1600,
        'pudge clears the 1600 margin, so the domain admits him...')
    assert(#J.GetAlliesNearLoc(pudge:GetLocation(), 1200) == 0,
        '...and lion at 1555.8u is not within 1200 of the engage point, so the '
        .. 'numbers branch counts zero committing allies')
    assert(J.SafeToCommitFight(bot, pudge) == false,
        'ownhalf widens the DOMAIN, never the DISCIPLINE')
end

tests['ARMED: HP is not what separates the two enemies (measured both ways)'] = function()
    local J, bot, heroes = loaded(true)
    local pudge = heroes['npc_dota_hero_pudge']
    rawget(pudge, '__spec').GetHealth = math.floor(pudge:GetMaxHealth() * 0.415)
    rawset(pudge, 'GetHealth', nil)
    assert(J.SafeToCommitFight(bot, pudge) == false,
        'pudge at drow HP is still refused -- so the refusal was never about HP')

    local J2, bot2, heroes2 = loaded(true)
    local drow = heroes2['npc_dota_hero_drow_ranger']
    rawget(drow, '__spec').GetHealth = math.floor(drow:GetMaxHealth() * 0.831)
    rawset(drow, 'GetHealth', nil)
    assert(J2.SafeToCommitFight(bot2, drow) == true,
        'drow at pudge HP is still accepted -- same conclusion from the other side')
end

-- ------------------------------------------------------- counterfactuals ----

tests['counterfactual: pull drow inside the margin -> the gate lets go'] = function()
    local J, bot, heroes = loaded(true)
    -- ONE field flipped, said out loud: drow is moved onto the enemy side of
    -- the midline (depth well under 1600). Same HP, still no building of ours
    -- near him.
    moveTo(heroes['npc_dota_hero_drow_ranger'], 1200, 900)
    assert(depthOf(J, bot, heroes['npc_dota_hero_drow_ranger']) < 1600,
        'test setup: the moved drow must be inside the margin')
    assert(J.ShouldPunishDive(bot) == nil,
        'the depth clause is load-bearing: an invader who is NOT clearly on our '
        .. 'half is not this gate is business, however killable he looks')
end

-- This one exists to kill the mutant "delete the SafeToCommitFight conjunct
-- from ShouldPunishDive". Domain membership is untouched -- drow still clears
-- depth and is still outside 1200 of a building -- so ONLY the commit test can
-- turn this to nil.
tests['counterfactual: outnumber us at the engage point -> the gate lets go'] = function()
    local J, bot, heroes = loaded(true)
    local drow = heroes['npc_dota_hero_drow_ranger']
    local dl = drow:GetLocation()
    moveTo(heroes['npc_dota_hero_pudge'], dl.x + 200, dl.y + 200)
    assert(depthOf(J, bot, drow) >= 1600 and nearestAlliedBuilding(drow) > 1200,
        'test setup: drow must still be admitted by the ownhalf domain')
    assert(#J.GetAlliesNearLoc(dl, 1200) == 1 and #J.GetEnemiesNearLoc(dl, 1200) == 2,
        'test setup: 1 ally vs 2 enemies at the engage point')
    assert(J.ShouldPunishDive(bot) == nil,
        'a 1v2 collapse is refused even deep on our own half -- the lethal-or-'
        .. 'numbers discipline is inside this gate, not beside it')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    local J, bot = loaded(true)
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J.ShouldPunishDive(bot) == nil,
        'turbo-only; normal mode ships unchanged even armed')
end

return tests
