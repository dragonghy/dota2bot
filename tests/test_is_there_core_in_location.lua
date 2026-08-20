-- [GH #50] J.IsThereCoreInLocation: the helper hero_largo.lua has called since
-- it shipped and nobody ever defined.
--
--   bots/BotLib/hero_largo.lua:416, inside X.ConsiderCatchLick's laning branch:
--       and (J.IsCore(bot) or not J.IsThereCoreInLocation(creep:GetLocation(), 650))
--
-- Lua resolves a table field at CALL time, so the file loads, luacheck is happy
-- (J is a legit local; its fields are not checked) and test_smoke_load passes --
-- the failure only exists on the frame that reaches the line, and there it is
-- "attempt to call field 'IsThereCoreInLocation' (a nil value)". The `or`
-- short-circuits for a core Largo, so only a SUPPORT Largo ever gets there, and
-- the branch it sits in is the laning-phase last-hit branch, i.e. a frame shape
-- that recurs through the whole lane. Nothing wraps X.SkillsComplement in a
-- pcall (ability_item_usage_generic.lua:8520 calls it bare from
-- AbilityUsageThink), so the throw takes out that bot's entire ability layer for
-- the frame -- and in game the error text is invisible (print never reaches the
-- console; the engine's handler masks it as "error in error handling").
--
-- The fix is NOT gated. A gate's off-side is supposed to be the shipped default,
-- and here the shipped default is a raised error -- there is no conservative
-- version of that to preserve. What IS a real choice is the helper's semantics,
-- so it is pinned here rather than argued: J.IsThereCoreInLocation is
-- J.IsThereCoreNearby with the unit-to-unit distance swapped for the
-- unit-to-location one, keeping its self-exclusion and its J.IsCore test.
--
-- REAL FRAME. 20260720_080225_slot1 @ t=47.0 (0:47) -- laning phase, which is
-- the only phase the Largo call site runs in. Both query points are real
-- positions of real heroes on that frame, and every distance asserted below
-- comes from the dump, not from an anchor.
--
-- WHAT IS DECLARED RATHER THAN OBSERVED (the one honest gap): the dump carries
-- no player id, no lane and no draft (tools/batch_test/behavioral/dumper/main.go
-- emits hero/idx/team/x/y/hp/... and nothing role-shaped), so the fixture world
-- cannot know who was pos 1 and who was pos 5. Left alone, EVERY fixture hero
-- reports PlayerID 0, aba_role's index fallback matches all five against slot 1,
-- and J.IsCore(ally) is true for the entire team -- under which this helper can
-- only ever answer "yes" and the test would be vacuous. So the roster positions
-- are DECLARED here (player id := roster index, which is what aba_role's own
-- fallback consumes outside Captains Mode) and the resulting split is ASSERTED,
-- not assumed. Everything the helper actually reads -- positions, teams, who is
-- alive, who can be seen -- is real frame data.
--
-- NOT COVERED, deliberately: X.ConsiderCatchLick is not driven end-to-end,
-- because no archived replay in reach contains a Largo, so no Largo fixture can
-- be generated (see the report for 2026-08-20). The call-site expression is
-- reconstructed on a real frame instead, and a source-level tripwire pins that
-- the call site still reads the way the reconstruction assumes.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local LANE = 'tests/fixtures/f_080225_wk_lane.lua'

-- Feed aba_role the ids its index fallback needs; see the header. Must run
-- before any J.GetPosition call on the frame, since that caches bot.assignedRole.
local function declare_roster_positions()
    for i = 1, #GetTeamPlayers(GetTeam()) do
        rawget(GetTeamMember(i), '__spec').GetPlayerID = i
    end
end

local function load_lane(sSubject)
    local J, bot, heroes, fx = rf.load(LANE, sSubject)
    declare_roster_positions()
    return J, bot, heroes, fx
end

local tests = {}

tests['[GH #50] ground truth: the real laning frame and its core/support split'] = function()
    local J, bot, heroes, fx = load_lane()
    assert(fx.self == 'npc_dota_hero_skeleton_king')
    assert(fx.time == 47.0, 'decision instant, 0:47 -- laning phase')

    -- The declared split (header), asserted so a change in aba_role's fallback
    -- shows up here instead of quietly re-degenerating the world.
    local tExpected = {
        ['npc_dota_hero_dragon_knight']  = 1,
        ['npc_dota_hero_earthshaker']    = 2,
        ['npc_dota_hero_pudge']          = 3,
        ['npc_dota_hero_skeleton_king']  = 4,
        ['npc_dota_hero_vengeful_spirit'] = 5,
    }
    local nCores = 0
    for i = 1, #GetTeamPlayers(GetTeam()) do
        local ally = GetTeamMember(i)
        assert(J.GetPosition(ally) == tExpected[ally:GetUnitName()],
            'roster position of ' .. ally:GetUnitName())
        if J.IsCore(ally) then nCores = nCores + 1 end
    end
    assert(nCores == 3, 'three cores and two supports, or the split is degenerate')
    assert(J.IsCore(bot) == false, 'the subject is the support side of the guard')

    -- Real geometry, straight from the dump -- these are the numbers every
    -- assertion below turns on.
    local ss = heroes['npc_dota_hero_shadow_shaman']:GetLocation()
    local es = heroes['npc_dota_hero_earthshaker']
    local pudge = heroes['npc_dota_hero_pudge']
    local vs = heroes['npc_dota_hero_vengeful_spirit']
    assert(math.floor(GetUnitToLocationDistance(es, ss)) == 247,
        'the pos-2 core stands 247.9u from the bot-lane opponent')
    assert(math.floor(GetUnitToLocationDistance(bot, ss)) == 539,
        'the subject himself is 539.5u from it -- inside 650, and irrelevant')
    assert(math.floor(GetUnitToLocationDistance(pudge, vs:GetLocation())) == 1852,
        'the nearest core to the pos-5 support is 1852.7u away')
end

-- P1: the enemy the bot lane is trading against. A lane creep in that fight
-- stands between the two heroes, so this is the exact shape the Largo guard
-- exists for -- "my core is right here, this last hit is not mine to take".
tests['[GH #50] a core inside the radius of the query point -> true'] = function()
    local J, _, heroes = load_lane()
    local P1 = heroes['npc_dota_hero_shadow_shaman']:GetLocation()
    assert(J.IsThereCoreInLocation(P1, 650) == true,
        'the pos-2 core is 247.9u from that point, well inside the call site 650')
end

tests['[GH #50] the true/false boundary is the real 247.9u, bracketed both ways'] = function()
    local J, _, heroes = load_lane()
    local P1 = heroes['npc_dota_hero_shadow_shaman']:GetLocation()
    -- Bracketing rather than a single radius: whichever side of the boundary
    -- moves, one of these two flips.
    assert(J.IsThereCoreInLocation(P1, 247) == false,
        'one unit under the real distance, and the next core is 8058u out')
    assert(J.IsThereCoreInLocation(P1, 248) == true,
        'one unit over it')
end

-- P2: the pos-5 support alone in her lane. Nothing to defer to, so the guard
-- must release and let her take the creep.
tests['[GH #50] no core inside the radius -> false (the support may take it)'] = function()
    local J, _, heroes = load_lane()
    local P2 = heroes['npc_dota_hero_vengeful_spirit']:GetLocation()
    assert(J.IsThereCoreInLocation(P2, 650) == false,
        'nearest core is 1852.7u away -- nobody is being robbed of this creep')
    assert(J.IsThereCoreInLocation(P2, 1852) == false, 'boundary, under')
    assert(J.IsThereCoreInLocation(P2, 1853) == true, 'boundary, over')
end

tests['[GH #50] the J.IsCore term is load-bearing: a support at the point is not a core'] = function()
    local J, bot, heroes = load_lane()
    local vs = heroes['npc_dota_hero_vengeful_spirit']
    local P2 = vs:GetLocation()
    -- vs sits ON the query point (distance 0) and is neither the caller nor
    -- dead, so every clause except J.IsCore is satisfied by her. The answer is
    -- false, so J.IsCore is the only thing producing it.
    assert(vs ~= bot and vs:IsAlive() and vs:CanBeSeen(), 'she clears every other clause')
    assert(math.floor(GetUnitToLocationDistance(vs, P2)) == 0, 'and stands on the point')
    assert(J.IsCore(vs) == false, 'but she is pos 5')
    assert(J.IsThereCoreInLocation(P2, 650) == false)
end

tests['[GH #50] the caller is excluded even when the caller is a core'] = function()
    -- Driven from the pos-1 core instead of the subject: he stands ON his own
    -- location (distance 0), is alive and visible, and IS a core -- so every
    -- clause but `allyHero ~= GetBot()` is satisfied by him alone, and the only
    -- thing that can make this false is the self-exclusion.
    local J, bot = load_lane('npc_dota_hero_dragon_knight')
    assert(J.IsCore(bot) == true, 'the caller is pos 1 here')
    assert(J.IsThereCoreInLocation(bot:GetLocation(), 1) == false,
        'a hero is never his own reason to yield a last hit')
end

tests['[GH #50] an unseen core does not suppress the caller'] = function()
    local J, _, heroes = load_lane()
    local P1 = heroes['npc_dota_hero_shadow_shaman']:GetLocation()
    assert(J.IsThereCoreInLocation(P1, 650) == true, 'baseline on the untouched frame')
    -- ANNOTATED MUTATION: hide the pos-2 core. J.IsInLocRange gates on
    -- CanBeSeen(), which is also what keeps a dead ally's stale dump position
    -- from vetoing a live creep.
    rawget(heroes['npc_dota_hero_earthshaker'], '__spec').CanBeSeen = false
    assert(J.IsThereCoreInLocation(P1, 650) == false,
        'what cannot be seen cannot be deferred to')
end

-- The call site itself. No Largo fixture can be generated (no archived replay in
-- reach drafts him), so the expression is reconstructed on a real frame with a
-- real support caller, and the tripwire below pins that the reconstruction still
-- matches the shipped line.
local function largo_guard(J, bot, vLoc)
    return (J.IsCore(bot) or not J.IsThereCoreInLocation(vLoc, 650))
end

tests['[GH #50] call-site expression, support caller: yields to the nearby core'] = function()
    local J, bot, heroes = load_lane()
    assert(J.IsCore(bot) == false, 'support caller, so the `or` does not short-circuit')
    assert(largo_guard(J, bot, heroes['npc_dota_hero_shadow_shaman']:GetLocation()) == false,
        'a core 247.9u from the creep -> the last-hit branch is skipped')
    assert(largo_guard(J, bot, heroes['npc_dota_hero_vengeful_spirit']:GetLocation()) == true,
        'no core within 650 of the creep -> the support takes it')
end

tests['[GH #50] call-site expression, core caller: short-circuits, helper never runs'] = function()
    local J, bot, heroes = load_lane('npc_dota_hero_dragon_knight')
    assert(J.IsCore(bot) == true)
    local nCalls = 0
    local fReal = J.IsThereCoreInLocation
    J.IsThereCoreInLocation = function(...) nCalls = nCalls + 1; return fReal(...) end
    assert(largo_guard(J, bot, heroes['npc_dota_hero_shadow_shaman']:GetLocation()) == true,
        'a core never yields his own last hit')
    assert(nCalls == 0,
        'and never even asks -- which is why a core Largo never hit the crash')
end

tests['[GH #50] the crash this fixes is real, not asserted in prose'] = function()
    local J, bot, heroes = load_lane()
    -- Reinstate the pre-fix world (the name simply absent) and run the same
    -- expression the shipped file runs.
    J.IsThereCoreInLocation = nil
    local ok, err = pcall(largo_guard, J, bot,
        heroes['npc_dota_hero_shadow_shaman']:GetLocation())
    assert(ok == false, 'before the fix this frame raised, it did not merely misjudge')
    assert(tostring(err):find('nil value'),
        'and the raise is the nil call, not something else: ' .. tostring(err))
end

tests['[GH #50] tripwire: the shipped call site still reads the way this test models it'] = function()
    local fh = assert(io.open('bots/BotLib/hero_largo.lua', 'r'))
    local src = fh:read('*a')
    fh:close()
    assert(src:find('J.IsCore(bot) or not J.IsThereCoreInLocation(creep:GetLocation(), 650)', 1, true),
        'hero_largo.lua no longer contains the guard this test reconstructs -- '
        .. 'either the radius, the short-circuit or the helper name moved')
end

return tests
