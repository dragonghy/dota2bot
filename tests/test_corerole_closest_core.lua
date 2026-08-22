-- [GH #105, soak candidate 'corerole'] J.GetClosestCore reads the CALLER's
-- role, never the candidate's.
--
-- jmz_func.lua's loop runs over `member` but tests `J.IsCore(bot)`, so the
-- function's name is wrong in BOTH directions, and both of them are live in
-- shipped turbo play through its one consumer,
-- X.ConsiderHelpWhenCoreIsTargeted (mode_team_roam_generic.lua, ungated):
--
--   * a SUPPORT caller can never get an answer -- the clause is false on every
--     iteration -- so "a core of mine is being focused, go help" is structurally
--     dead for exactly the heroes whose job it is;
--   * a CORE caller gets the first living team member that is not itself, in
--     GetTeamMember() order, which is as likely to be a pos 5 as a core.
--
-- The consumer's own condition is the tell: it opens with
-- `(not J.IsCore(bot) or bot.isBear or ...)`, i.e. the author explicitly wrote
-- a support branch -- which the helper has been making unreachable the whole
-- time. Same family as the director's §0b "the consumer's mechanism quietly
-- voids the helper's reasoning", running in the other direction.
--
-- The correction is GATED ('corerole'); with the gate off the defect is
-- reproduced verbatim, because the consumer is the same chain the AG.4 ladder
-- is measuring and a silent flip would re-route the GH #45 attribution instead
-- of re-deriving it (that re-derivation is in
-- tests/test_roamreach_bounded_chase.lua).
--
-- REAL FRAME: f_260819_181742_ss_chase_start (game 20260819_181742_slot1,
-- seed 866 radiant, t=312.5), subject shadow_shaman, DRAFTED pos 4. Its radiant
-- team on that frame, by slot -- every number below is read off the fixture,
-- none is assumed:
--
--   slot 1 bristleback    core     8955u from the subject, 9594u from Centaur
--   slot 2 death_prophet  core     6258u                   6731u
--   slot 3 shadow_shaman  SUPPORT     0u  (the subject)     656u
--   slot 4 zuus           SUPPORT 11838u                  12398u
--   slot 5 centaur        core      656u                      0u
--
-- That layout is what makes the frame able to separate the two readings at a
-- 3500 radius: the only core within reach of the subject is the Centaur, and
-- the only ally within reach of the Centaur is the SUPPORT subject.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F_START = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'
local RADIUS  = 3500

--- The frame, with an explicit armed-id set. No mode file: this is the helper's
--- own contract, and the helper needs nothing but the frame.
local function world(ids)
    local J, bot, heroes = rf.load(F_START)
    J.IsSoakCandidate = function(id) return (ids or {})[id] == true end
    return J, bot, heroes
end

local function name(u) return u ~= nil and u:GetUnitName() or nil end

-- ---------------------------------------------------------------------------
-- The frame's premises. If any of these move, the four tests below stop
-- separating the two readings and must be re-derived, not re-run.
-- ---------------------------------------------------------------------------

tests['PREMISE: the frame separates caller-role from candidate-role at 3500'] = function()
    local J, bot, heroes = world()
    local cent = heroes['npc_dota_hero_centaur']

    assert(J.IsModeTurbo(), 'the gate is turbo-only, so the frame must be turbo')
    assert(not J.IsCore(bot), 'the subject must be a DRAFTED support; got core')
    assert(J.IsCore(cent), 'the Centaur must be a drafted core')
    assert(cent:IsAlive() and GetUnitToUnitDistance(bot, cent) <= RADIUS,
        'and it must be alive and inside the radius')

    -- The two other cores are outside 3500 of the Centaur -- that is what makes
    -- the core-caller half of the test a real discriminator rather than luck.
    local nCoresNearCentaur, nAlliesNearCentaur = 0, 0
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local m = GetTeamMember(i)
        if m ~= nil and m ~= cent and m:IsAlive()
        and GetUnitToUnitDistance(cent, m) <= RADIUS then
            nAlliesNearCentaur = nAlliesNearCentaur + 1
            if J.IsCore(m) then nCoresNearCentaur = nCoresNearCentaur + 1 end
        end
    end
    assert(nAlliesNearCentaur == 1 and nCoresNearCentaur == 0,
        'the Centaur must have exactly one ally in range and it must be a '
        .. 'support; got ' .. nAlliesNearCentaur .. ' allies / '
        .. nCoresNearCentaur .. ' cores')
end

-- ---------------------------------------------------------------------------
-- Gate OFF: the shipped defect, both directions, unchanged.
-- ---------------------------------------------------------------------------

tests['GATE OFF: a support caller gets nil with a core standing 656u away'] = function()
    local J, bot, heroes = world({})
    assert(J.GetClosestCore(bot, RADIUS) == nil,
        'shipped behaviour must be preserved bit for bit: nil for a support '
        .. 'caller; got ' .. tostring(name(J.GetClosestCore(bot, RADIUS))))
    local cent = heroes['npc_dota_hero_centaur']
    assert(J.IsCore(cent) and GetUnitToUnitDistance(bot, cent) < RADIUS,
        '...while a drafted core is alive 656u away')
end

tests['GATE OFF: a core caller gets handed the pos 4 SUPPORT'] = function()
    local J, _, heroes = world({})
    local cent = heroes['npc_dota_hero_centaur']
    assert(name(J.GetClosestCore(cent, RADIUS)) == 'npc_dota_hero_shadow_shaman',
        'the other half of the defect: J.IsCore(bot) is true for a core caller, '
        .. 'so the loop returns the first living team member that is not itself '
        .. '-- here a support; got ' .. tostring(name(J.GetClosestCore(cent, RADIUS))))
end

-- ---------------------------------------------------------------------------
-- ARMED: the candidate's role is what is read.
-- ---------------------------------------------------------------------------

tests['ARMED: a support caller gets the Centaur'] = function()
    local J, bot = world({ corerole = true })
    assert(name(J.GetClosestCore(bot, RADIUS)) == 'npc_dota_hero_centaur',
        'armed, the support caller must get the drafted core in range; got '
        .. tostring(name(J.GetClosestCore(bot, RADIUS))))
end

tests['ARMED: a core caller gets nil, because no OTHER core is in range'] = function()
    local J, _, heroes = world({ corerole = true })
    local cent = heroes['npc_dota_hero_centaur']
    -- The half that proves the fix reads the CANDIDATE and not merely "somebody
    -- else": armed, the answer for the Centaur goes from the support to nil,
    -- because bristleback (9594u) and death_prophet (6731u) are out of range.
    -- A fix that just dropped the role clause would answer the support here.
    assert(J.GetClosestCore(cent, RADIUS) == nil,
        'armed, a core caller with no other core in range must get nil; got '
        .. tostring(name(J.GetClosestCore(cent, RADIUS))))
end

-- ---------------------------------------------------------------------------
-- Domain and wiring.
-- ---------------------------------------------------------------------------

tests['DOMAIN: armed in normal mode is the shipped defect, verbatim'] = function()
    local J, bot, heroes = world({ corerole = true })
    J.IsModeTurbo = function() return false end
    local cent = heroes['npc_dota_hero_centaur']
    assert(J.GetClosestCore(bot, RADIUS) == nil,
        'normal mode must keep the defect: nil for the support caller')
    assert(name(J.GetClosestCore(cent, RADIUS)) == 'npc_dota_hero_shadow_shaman',
        'and the support for the core caller')
end

tests['WIRING: the correction is gated, and the gate is inside the loop'] = function()
    local src = io.open('bots/FunLib/jmz_func.lua'):read('*a')
    local body = src:match('function J%.GetClosestCore%(bot, nRadius%)(.-)\nend')
    assert(body ~= nil, 'J.GetClosestCore must still exist in jmz_func')
    assert(body:find("IsSoakCandidate('corerole')", 1, true) ~= nil,
        "the correction must stay gated on 'corerole' until it is promoted; the "
        .. 'gate is gone, so shipped default behaviour has changed and every '
        .. 'GetClosestCore-dependent attribution needs re-deriving')
    assert(body:find('IsModeTurbo()', 1, true) ~= nil,
        'and turbo-only, like every other candidate')
    -- The role subject has to be chosen per candidate, not once for the call:
    -- hoisting it out of the loop is how this defect happened in the first place.
    assert(body:find('J.IsCore(hRoleSubject)', 1, true) ~= nil,
        'the role test must consult the per-iteration subject')
end

-- ---------------------------------------------------------------------------
-- Recorded, NOT fixed here: "Closest" is a lie on both paths.
-- ---------------------------------------------------------------------------

tests['[recorded] it is not the CLOSEST core either, on either path'] = function()
    local J, bot = world({ corerole = true })
    local src = io.open('bots/FunLib/jmz_func.lua'):read('*a')
    local body = src:match('function J%.GetClosestCore%(bot, nRadius%)(.-)\nend')
    -- The loop returns on first match in GetTeamMember() order and never
    -- compares distances between candidates, so "Closest" describes nothing.
    -- One lever per unit: this clause changes WHICH ally comes back, never
    -- whether one does, and it is registered as residual on GH #105.
    assert(body:find('return member', 1, true) ~= nil
        and body:find('math.min', 1, true) == nil,
        'if this function learned to compare distances, the residual on GH #105 '
        .. 'is closed and this test should become a real assertion')

    -- On this frame the two readings coincide (the only core in range IS the
    -- nearest one), which is exactly why the frame cannot settle the residual.
    local answer = J.GetClosestCore(bot, RADIUS)
    local nearestCore, nearestDist = nil, math.huge
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local m = GetTeamMember(i)
        if m ~= nil and m ~= bot and m:IsAlive() and J.IsCore(m) then
            local d = GetUnitToUnitDistance(bot, m)
            if d <= RADIUS and d < nearestDist then nearestCore, nearestDist = m, d end
        end
    end
    assert(name(answer) == name(nearestCore),
        'on THIS frame first-in-slot-order and nearest agree, so the frame says '
        .. 'nothing about the residual -- it is a source-level claim')
end

return tests
