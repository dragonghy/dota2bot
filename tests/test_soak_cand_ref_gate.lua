-- [GH #141] J.IsSoakCandidate's two-leg contract.
--
-- WHY THIS EXISTS
--     test_set.md §AS.3 froze the test set and left exactly one non-lucky
--     thaw condition: run a BISECT wave -- split the armed set into two arms
--     inside ONE tree. That wave could not be launched, and not because it was
--     hard: soak_side.lua carried a single `cand` string, so an id was either
--     armed on the candidate leg or armed nowhere. The reference leg had no way
--     to carry ids at all. GH #141 adds an optional `cand_ref`.
--
-- WHAT IS AT STAKE
--     This function is the gate for EVERY gated fix in the tree. The blast
--     radius of a mistake here is the whole soak-candidate mechanism, in both
--     directions: a fix that silently stops arming (a wave measures nothing and
--     reports a number anyway), or a fix that silently starts arming off-farm
--     (shipped behavior changes). So the first contract below is not "the new
--     feature works" but "WITHOUT the new field, nothing moved" -- asserted
--     over all four shapes `cand` can take, including the two nobody writes by
--     hand ('all' and the comma bundle).
--
--     The two-leg assertions deliberately run on a REAL replay frame with two
--     real teams (tests/fixtures/f_080225_wk_lane.lua) rather than a mocked
--     team number: what the gate compares is GetTeam() against a side name, and
--     a mock that hands back the number the test wants would be asserting the
--     test's own arithmetic. The fixture's teams come out of a real .dem.
--
-- MUTATIONS THIS FILE IS BUILT TO CATCH (GH #141 §4.3)
--     M1  cand_ref absent, but the reference leg falls through to `cand`
--         => 'off-candidate side arms nothing' goes red.
--     M2  both legs match the same string
--         => 'each leg reads its own string' goes red.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local fixture = require('mock.replay_fixture')
local ss = require('mock.soak_side')               -- owns bots/Customize/soak_side.lua

local FIXTURE = 'tests/fixtures/f_080225_wk_lane.lua'
-- Two heroes on that frame, one per team (team 2 = radiant, team 3 = dire).
local RADIANT_HERO = 'npc_dota_hero_zuus'
local DIRE_HERO = 'npc_dota_hero_skeleton_king'

local tests = {}

-- Write the (gitignored) gate file, run fn, always clean up. reset_modules
-- inside the loaders re-requires jmz_func, so its cached GetSoakSideConf
-- re-reads the file rather than answering from the previous test's cache.
--
-- [GH #365 §3 / GH #229, hero backlog `-78`] The three lines this used to
-- inline are now in tests/mock/soak_side.lua, the switch's one owner. This
-- file is the one that goes through `arm_body` rather than `arm`, because its
-- subject IS the gate resolver and it must write two shapes `ss.body` cannot
-- express: the closed gate (`side = false, cand = false`) and the two-leg
-- `cand_ref` of GH #141. It is also the file with the most to lose from an
-- unchecked write: EVERY case here has an assertion whose expected value is
-- `false`, so a write that did not land, or a switch a concurrent process
-- removed, reads as the contract holding.
local function with_gate(sBody, fn)
    ss.with_body(sBody, fn)
end

-- ...and once HERE, at file-load time, the only moment that sees the state this
-- process STARTED in: every armed span ends by removing the switch, and the
-- armed cases can sort before the unarmed one, so an INHERITED leftover is
-- deleted by a sibling case before any per-case guard looks at it (GH #417:
-- such a leftover survived a per-case guard 19/19 green).
ss.assert_clean('test_soak_cand_ref_gate')

-- jmz on a mock hero pinned to `team`, used only by the single-arm contract
-- (which is about the string matcher, not about which team is which).
local function jmz_on(team)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion', {})
    api.install({ bot = bot, team = team })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func')
end

-- jmz driven from a named hero of the real frame; global GetTeam() becomes that
-- hero's REAL team, which is the value the gate actually compares.
local function jmz_on_fixture_hero(sHero)
    local J = fixture.load(FIXTURE, sHero)
    return J
end

----------------------------------------------------------------------------
-- Contract 1 (the precondition): no cand_ref => literally today's behavior.
----------------------------------------------------------------------------

tests['single-arm: single id arms only itself, only on the candidate side'] = function()
    with_gate("return { side = 'radiant', cand = 'tpsafe' }", function()
        local J = jmz_on(2)
        assert(J.IsSoakCandidate('tpsafe') == true, 'armed id must be live')
        assert(J.IsSoakCandidate('nodive') == false, 'unarmed id must stay dark')
        local K = jmz_on(3)
        assert(K.IsSoakCandidate('tpsafe') == false,
            'off-candidate side must arm NOTHING when cand_ref is absent')
    end)
end

tests["single-arm: 'all' arms every id on the candidate side only"] = function()
    with_gate("return { side = 'radiant', cand = 'all' }", function()
        local J = jmz_on(2)
        assert(J.IsSoakCandidate('tpsafe') == true, "'all' must arm any id")
        assert(J.IsSoakCandidate('whatever_id') == true, "'all' must arm any id")
        local K = jmz_on(3)
        assert(K.IsSoakCandidate('tpsafe') == false,
            "'all' must not leak onto the reference leg")
    end)
end

tests['single-arm: comma bundle arms exactly its members'] = function()
    with_gate("return { side = 'dire', cand = 'a,b,c' }", function()
        local J = jmz_on(3)
        assert(J.IsSoakCandidate('a') == true, 'first member armed')
        assert(J.IsSoakCandidate('b') == true, 'middle member armed')
        assert(J.IsSoakCandidate('c') == true, 'last member armed')
        assert(J.IsSoakCandidate('ab') == false, 'a non-member must stay dark')
        local K = jmz_on(2)
        assert(K.IsSoakCandidate('b') == false,
            'bundle must not leak onto the reference leg')
    end)
end

tests['single-arm: a closed gate file arms nothing anywhere'] = function()
    with_gate('return { side = false, cand = false }', function()
        for _, team in ipairs({ 2, 3 }) do
            local J = jmz_on(team)
            assert(J.IsSoakCandidate('tpsafe') == false,
                'closed gate must be false on team ' .. team)
            assert(J.IsSoakCandidate('all') == false,
                "closed gate must not be tricked by the id 'all'")
        end
    end)
end

tests['single-arm: no gate file at all (the shipped default) arms nothing'] = function()
    -- Not armed on purpose: this is the state every real game is in, and it is
    -- the one state the file must NOT exist for. `with_candidate(nil, ...)`
    -- asserts that absence before AND after the body -- before, because a
    -- leftover would make this whole case measure somebody else's candidate;
    -- after, because the path is one global inode and a concurrent lua5.1
    -- process can arm it mid-case. The `io.open` handle this used to take was
    -- also never closed on the branch it was testing for.
    ss.with_candidate(nil, function()
        for _, team in ipairs({ 2, 3 }) do
            local J = jmz_on(team)
            assert(J.IsSoakCandidate('tpsafe') == false,
                'shipped default must be false on team ' .. team)
        end
    end)
end

----------------------------------------------------------------------------
-- Contract 2 (the feature): with cand_ref, each leg reads its own string.
-- Driven from a real frame's real teams, per GH #141 §4.2.
----------------------------------------------------------------------------

-- Guard against the whole block passing vacuously on a fixture that turned out
-- to be one-sided: assert the two subjects really are on opposite teams before
-- asserting anything about legs.
tests['fixture sanity: the two subjects sit on opposite real teams'] = function()
    local fx = dofile(FIXTURE)
    local seen = {}
    for _, u in ipairs(fx.units) do
        if u.name == RADIANT_HERO or u.name == DIRE_HERO then seen[u.name] = u.team end
    end
    assert(seen[RADIANT_HERO] ~= nil, 'radiant subject missing from fixture')
    assert(seen[DIRE_HERO] ~= nil, 'dire subject missing from fixture')
    assert(seen[RADIANT_HERO] ~= seen[DIRE_HERO],
        'the two subjects must be on different teams for the leg test to mean anything')
    assert(seen[RADIANT_HERO] == 2 and seen[DIRE_HERO] == 3,
        'fixture teams must be radiant=2 / dire=3 as the gate compares them')
end

tests['two-arm: candidate leg reads cand, reference leg reads cand_ref'] = function()
    with_gate("return { side = 'radiant', cand = 'x,shared', cand_ref = 'y,shared' }", function()
        local R = jmz_on_fixture_hero(RADIANT_HERO)   -- the candidate leg
        assert(R.IsSoakCandidate('x') == true, 'cand-only id must be live on the candidate leg')
        assert(R.IsSoakCandidate('y') == false, 'ref-only id must be dark on the candidate leg')

        local D = jmz_on_fixture_hero(DIRE_HERO)      -- the reference leg
        assert(D.IsSoakCandidate('y') == true, 'ref-only id must be live on the reference leg')
        assert(D.IsSoakCandidate('x') == false, 'cand-only id must be dark on the reference leg')
    end)
end

tests['two-arm: the intersection is live on BOTH legs (the shared base)'] = function()
    with_gate("return { side = 'radiant', cand = 'x,shared', cand_ref = 'y,shared' }", function()
        local R = jmz_on_fixture_hero(RADIANT_HERO)
        assert(R.IsSoakCandidate('shared') == true, 'shared id must be live on the candidate leg')
        local D = jmz_on_fixture_hero(DIRE_HERO)
        assert(D.IsSoakCandidate('shared') == true, 'shared id must be live on the reference leg')
    end)
end

tests['two-arm: an id in neither string is dark on both legs'] = function()
    with_gate("return { side = 'radiant', cand = 'x', cand_ref = 'y' }", function()
        assert(jmz_on_fixture_hero(RADIANT_HERO).IsSoakCandidate('z') == false,
            'unlisted id must be dark on the candidate leg')
        assert(jmz_on_fixture_hero(DIRE_HERO).IsSoakCandidate('z') == false,
            'unlisted id must be dark on the reference leg')
    end)
end

tests['two-arm: the candidate side flips with `side`, not with team order'] = function()
    -- Same two strings, opposite `side`: every answer above must invert. This
    -- is what separates "reads the right string" from "radiant happens to win".
    with_gate("return { side = 'dire', cand = 'x', cand_ref = 'y' }", function()
        local D = jmz_on_fixture_hero(DIRE_HERO)      -- now the candidate leg
        assert(D.IsSoakCandidate('x') == true, 'dire is the candidate leg here')
        assert(D.IsSoakCandidate('y') == false, 'dire must not read cand_ref here')
        local R = jmz_on_fixture_hero(RADIANT_HERO)   -- now the reference leg
        assert(R.IsSoakCandidate('y') == true, 'radiant reads cand_ref here')
        assert(R.IsSoakCandidate('x') == false, 'radiant must not read cand here')
    end)
end

tests["two-arm: 'all' on the reference leg arms everything there"] = function()
    with_gate("return { side = 'radiant', cand = 'x', cand_ref = 'all' }", function()
        local D = jmz_on_fixture_hero(DIRE_HERO)
        assert(D.IsSoakCandidate('anything') == true,
            "'all' must have the same meaning in cand_ref as in cand")
        local R = jmz_on_fixture_hero(RADIANT_HERO)
        assert(R.IsSoakCandidate('anything') == false,
            'the candidate leg still reads only its own string')
    end)
end

return tests
