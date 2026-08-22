-- THE SIXTEENTH WORLD ASSERTION: no fixture in this repository has ever called
-- an item's Consider function. Not the TP scroll's, not any other item's.
--
--     J.CanCastAbility(<any item handle>) == false
--         on 5774 occupied item slots / 911 alive hero frames / 98 fixtures
--
-- and the shipped item loop (ability_item_usage_generic.lua:1007-1035) calls
-- `X.ConsiderItemDesire[name](hItem)` only inside `if J.CanCastAbility(hItem)`.
-- So the entire item decision layer is dark: driving the shipped entry point
-- `ItemUsageThink()` on all 882 drivable hero frames produces ZERO actions and
-- ZERO errors. It looks like a clean pass. It is an empty one.
--
-- WHY. `J.CanCastAbility` (jmz_func.lua:5145) is a six-clause chain:
--
--     ability == nil / IsNull() / IsPassive() / IsHidden()
--     / not IsTrained() / not IsFullyCastable() / not IsActivated()
--
-- The loader builds item handles with exactly ONE of those six wired
-- (replay_fixture.lua:118-132): `IsFullyCastable`, and for the TP scroll it
-- wires it from the dumped cooldown, `IsFullyCastable = u.tp_cd <= 0`. Every
-- other clause falls through to the mock's Is/Has/Can default, which is false
-- -- so `IsTrained()` answers false and `not IsTrained()` short-circuits the
-- chain TWO CLAUSES BEFORE the one the loader took care over. The careful
-- modelling of the real TP cooldown is dead on arrival: 658 of the 911 frames
-- carry a TP scroll whose real cooldown was ready, and not one of them reaches
-- a reader.
--
-- That is the shape worth remembering: this is not a missing field. It is a
-- field that was measured from the replay and then MASKED by two fields nobody
-- thought about, in the same `and` chain, in the same helper.
--
-- HOW BIG, MEASURED (both halves, as this stream's rule requires). Make the TP
-- scroll's IsTrained/IsActivated honest and re-drive all 882 frames:
--
--     today        882 no_action        0 actions   0 crashes
--     honest TP    672 no_action        1 action  209 crashes
--
-- Two things fall out of that, and the crashes are the bigger one:
--
--   * 209 of 882 frames (24%) THROW inside the tpscroll consider, naming two
--     more engine APIs the mock does not stub -- `GetExtrapolatedLocation`
--     (179 frames, via J.CanEnemyInterruptTpChannel) and `GetFarmLaneDesire`
--     (30 frames, via J.GetMostFarmLaneDesire). They join GetRuneSpawnLocation
--     / GetCourierState (GH #62 §0d) and GetRoshanDesire (the fourteenth world
--     assertion) as unrunnable surfaces -- the fourth and fifth. The first of
--     them is NOT on a gated road: `tpsafe2` was promoted to a turbo default on
--     2026-07-23, so J.CanEnemyInterruptTpChannel runs before every TP the
--     item layer would issue in every turbo game we ship, and no test has ever
--     executed it on a real frame.
--   * the ONE action the corpus can produce is a phantom. It is a TP with the
--     shipped motive `支援团战` (support the teamfight), and its
--     trigger is `J.GetTeamFightLocation(bot)` returning Vector(0,0) -- the map
--     origin, which is exactly the artefact the THIRTEENTH world assertion
--     pinned (GetCenterOfUnits({}) returns the origin, not nil). So the honest
--     reading of the counterfactual is: opening this gap reveals no real item
--     decision on this corpus at all, only crashes and one origin-phantom.
--
-- AND THE SEVENTEENTH, found on the same road and pinned here with it: on the
-- 43 of 98 fixtures that carry no `buildings` block, `GetAncient(team)` falls
-- back to bot_api.lua:288 -- a unit at the MAP ORIGIN named
-- `npc_dota_badguys_fort`, returned for BOTH teams, freshly allocated on every
-- call so its identity is not even stable. 117 shipped call sites read it.
-- Anything measured through the ancient on those 403 hero frames is measured
-- against the map centre.
--
-- WHAT THIS DELIVERS TO GH #84 §5 (the (b) shape for
-- ability_item_usage_generic.lua:5753, `bot:GetLevel() >= 15`, the "guard the
-- ancient" TP -- the census in tests/test_level_gate_census.lua calls it
-- TEETH). Two answers, and they point opposite ways:
--
--   * the TEETH verdict is CONFIRMED WITH A NUMBER, the first of the six teeth
--     rows to get one. On the 508 alive hero frames that carry real buildings,
--     the OTHER FIVE operands of that AND all hold on 193, and on 190 of those
--     the level term is the SOLE thing holding the branch shut. Only 8 of 911
--     frames in the whole corpus are level 15 or better.
--   * and the (b) shape STILL cannot be completed here, for a fifth distinct
--     kind of blocker after 285 (dumper gap) / 535 (corpus gap) / 228 (not on
--     turbo's road). Three of the 8 mature frames satisfy the whole outer AND
--     -- and on all three the CONSEQUENT is unreachable: its first sub-branch
--     needs `GetLaneFrontLocation`, which the loader refuses (GH #61), and its
--     second needs both tier-4 towers gone, which is true on 0 of 508 honest
--     frames. Above both of those sits this file's own subject: the function
--     is never called at all.
--
-- Nothing in bots/ is changed by this file, and no soak candidate is proposed.
-- The two coordinate decisions it raises (should the loader wire IsTrained /
-- IsActivated; should GetAncient stop answering for a team it was not asked
-- about) go to the director as [harness] issues, per the stream's rule that
-- the loader's world model is not this desk's to change.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

-- The five globals `bots/ability_item_usage_generic.lua` installs when run. The
-- ~1700 executions that install them happen in the SUBPROCESS below, not here,
-- so this process never sees them change. They are captured now only so the
-- final assertion can prove exactly that: after this file, _G still holds what
-- it held before, and this file contributed nothing to a successor's world.
local AIUG_GLOBALS = {
    'ItemUsageThink', 'AbilityUsageThink', 'BuybackUsageThink',
    'CourierUsageThink', 'AbilityLevelUpThink',
}

-- The slot order the shipped loop scans, verbatim from
-- ability_item_usage_generic.lua:1005. The TP scroll lives in 15.
local SLOTS = { 5, 4, 3, 2, 1, 0, 15, 16 }

--- The ancient-guard branch's level constant, READ OUT OF THE SHIPPED SOURCE
--- rather than copied into this file.
---
--- Copying it is the trap this stream has now walked into three times (the
--- fourteenth assertion's M7, the fifteenth's M9, and this file's own M13,
--- which SURVIVED the first mutation run): a census that restates a constant
--- measures its own copy, so changing the shipped one moves nothing and the
--- census reports the old world with a straight face. The five sibling
--- operands below are restated -- there is no way to run that `if` in
--- isolation -- and they are covered instead by the source pin in
--- '[reverse] the shipped ancient-guard branch still has that shape'. That
--- pairing is the weaker arrangement; it is written down here so nobody reads
--- the census as self-sufficient.
local ANCIENT_GUARD_LEVEL = (function()
    local src = read_file('bots/ability_item_usage_generic.lua')
    local at = assert(src:find('\n\t\t--守护遗迹\n', 1, true),
        'the ancient-guard block moved')
    local n = src:sub(at, at + 200):match('if bot:GetLevel%(%) >= (%d+)')
    return assert(tonumber(n), 'the level term is no longer a literal comparison')
end)()

-- The two sweeps run in a SUBPROCESS (tests/_itemdesire_sweep.lua), not here.
--
-- Each sweep drives the 8500-line item file once per hero -- ~1700 executions.
-- Doing that in run_tests.lua's single long-lived process, on a heap already
-- grown large by every preceding test file, made the whole suite run for the
-- better part of an hour (measured 2026-08-22: 54 min and still going, both
-- with and without a per-fixture collectgarbage -- the collect on a large
-- shared heap is itself the cost). A fresh child VM does the same work with a
-- small heap in a few minutes and, more importantly, in a time that does NOT
-- depend on where this file lands in the alphabetical run. This is the
-- 2026-08-21T20:35Z lesson made mechanical: a full-corpus drive is chunked
-- across processes.
--
-- The child prints a flat manifest; the two count tables, the mature roster,
-- the casts and the load-fail map are all reconstructed from it below. The
-- five aiug globals are therefore NEVER installed in THIS process (they are
-- installed and thrown away in the child), so the successor-hygiene section is
-- reframed accordingly at the end of the file.
local BEFORE = {}
for _, g in ipairs(AIUG_GLOBALS) do BEFORE[g] = _G[g] end

local SWEEP_RESULT = nil
local function run_sweeps()
    if SWEEP_RESULT ~= nil then return SWEEP_RESULT end
    local base = setmetatable({}, { __index = function() return 0 end })
    local honest = setmetatable({}, { __index = function() return 0 end })
    base.mature, base.casts, base.load_fail = {}, {}, {}
    honest.mature, honest.casts, honest.load_fail = {}, {}, {}

    local p = assert(io.popen('lua5.1 tests/_itemdesire_sweep.lua 2>&1'),
        'could not launch the sweep subprocess')
    local saw_done = false
    for line in p:lines() do
        local tag, key, n = line:match('^C (%a+) (%S+) (%d+)$')
        if tag then
            local t = (tag == 'base') and base or honest
            t[key] = tonumber(n)
        elseif line:match('^MATURE ') then
            local fx, hero, lvl, hon, rest = line:match('^MATURE (%S+) (%S+) (%d+) (%a) (%d)$')
            assert(fx, 'malformed MATURE line: ' .. line)
            -- The roster is the same on both sweeps; keep it on both so either
            -- pass() consumer can read it.
            local rec = { fixture = fx, hero = hero, level = tonumber(lvl),
                honest = (hon == 'H'), rest = (rest == '1') }
            base.mature[#base.mature + 1] = rec
            honest.mature[#honest.mature + 1] = rec
        elseif line:match('^CAST ') then
            local tag2, fx, hero, fn, item = line:match('^CAST (%a+) (%S+) (%S+) (%S+) (%S+)$')
            assert(tag2, 'malformed CAST line: ' .. line)
            local t = (tag2 == 'base') and base or honest
            t.casts[#t.casts + 1] = { fixture = fx, hero = hero, fn = fn, item = item }
        elseif line:match('^LOADFAIL ') then
            local hero, n2 = line:match('^LOADFAIL (%S+) (%d+)$')
            assert(hero, 'malformed LOADFAIL line: ' .. line)
            base.load_fail[hero] = tonumber(n2)
            honest.load_fail[hero] = tonumber(n2)
        elseif line == 'DONE' then
            saw_done = true
        else
            error('unexpected output from the sweep subprocess: ' .. line)
        end
    end
    p:close()
    assert(saw_done, 'the sweep subprocess did not finish (no DONE line) -- '
        .. 'run `lua5.1 tests/_itemdesire_sweep.lua` by hand to see why')
    SWEEP_RESULT = { base = base, honest = honest }
    return SWEEP_RESULT
end

local function pass(honest_tp)
    local r = run_sweeps()
    return honest_tp and r.honest or r.base
end

-- ---------------------------------------------------------------------------
-- A. The assertion.
-- ---------------------------------------------------------------------------

tests['[world] not one item on one frame is castable'] = function()
    local c = pass(false)
    assert(c.fixtures == 101, 'corpus size moved: ' .. c.fixtures .. ' fixtures')
    assert(c.subjects == 1010, 'subject count moved: ' .. c.subjects)
    assert(c.alive == 940, 'alive hero frames moved: ' .. c.alive)
    assert(c.slot_occupied == 5957,
        'occupied item slots moved: ' .. c.slot_occupied)
    assert(c.slot_castable == 0,
        'SOMETHING IS NOW CASTABLE (' .. c.slot_castable .. ') -- the sixteenth '
        .. 'world assertion has been repaired or eroded; re-read this whole file')
    assert(c.frames_zero_castable == c.alive,
        'every alive frame must have zero castable items; got '
        .. c.frames_zero_castable .. '/' .. c.alive)
end

tests['[world] the TP scroll: carried by all, ready on 681, castable by none'] = function()
    local c = pass(false)
    assert(c.has_tp == 940, 'every alive hero carries a TP scroll; got ' .. c.has_tp)
    assert(c.tp_cooldown_ready == 681,
        'frames whose dumped tp_cd says READY moved: ' .. c.tp_cooldown_ready)
    assert(c.tp_castable == 0, 'the TP scroll is castable on ' .. c.tp_castable
        .. ' frames -- it must be 0 for the rest of this file to mean anything')
    -- The gap between those two numbers IS the finding: the loader measured a
    -- real cooldown from the replay for 658 frames and no reader can see it.
    assert(c.tp_cooldown_ready > 0,
        'if the loader ever stops modelling tp_cd this assertion is pointless')
end

tests['[MECHANISM] the clause that shuts it is IsTrained, not the cooldown'] = function()
    local J, bot = rf.load('tests/fixtures/f_221200_od_roles.lua')
    local tp = bot:GetItemInSlot(15)
    assert(tp:GetName() == 'item_tpscroll', 'slot 15 is the TP slot')
    -- Walk J.CanCastAbility's six clauses in source order.
    assert(tp:IsNull() == false, 'IsNull')
    assert(tp:IsPassive() == false, 'IsPassive')
    assert(tp:IsHidden() == false, 'IsHidden')
    assert(tp:IsTrained() == false,
        'IsTrained answers FALSE -- this is the clause that ends the chain')
    assert(tp:IsFullyCastable() == true,
        'and the clause AFTER it, the one the loader took care over, is true')
    assert(tp:IsActivated() == false, 'IsActivated is false as well')
    assert(J.CanCastAbility(tp) == false, 'so the helper answers false')

    -- Supply only the two the loader never wired: the chain completes.
    tp.IsTrained = function() return true end
    tp.IsActivated = function() return true end
    assert(J.CanCastAbility(tp) == true,
        'two fields is the whole distance between this corpus and a live '
        .. 'item decision')
end

tests['[MECHANISM] a cooldown-blocked TP stays blocked when the two are honest'] = function()
    -- The negative control for the assertion above: the loader's tp_cd
    -- modelling is not merely masked, it is CORRECT -- once IsTrained and
    -- IsActivated are supplied, a scroll on cooldown is still refused. Without
    -- this, "wire the two fields" could not be told apart from "make every TP
    -- castable".
    local found = nil
    for _, path in ipairs(fixture_files()) do
        local ok, J, bot = pcall(rf.load, path)
        if ok and bot ~= nil and bot:IsAlive() then
            local tp = bot:GetItemInSlot(15)
            if type(tp) == 'table' and not tp:IsFullyCastable() then
                tp.IsTrained = function() return true end
                tp.IsActivated = function() return true end
                assert(J.CanCastAbility(tp) == false,
                    'a scroll on cooldown must stay uncastable: ' .. path)
                found = path
                break
            end
        end
    end
    assert(found ~= nil, 'no fixture carries a TP on cooldown -- if the corpus '
        .. 'ever loses those 246 frames this control is empty and must be redone')
end

tests['[reverse] the mask is an ORDERING fact in jmz_func, not a missing field'] = function()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = src:find('function J.CanCastAbility(ability)', 1, true)
    assert(at ~= nil, 'J.CanCastAbility moved')
    local body = src:sub(at, at + 400)
    local trained = body:find('not ability:IsTrained()', 1, true)
    local castable = body:find('not ability:IsFullyCastable()', 1, true)
    local activated = body:find('not ability:IsActivated()', 1, true)
    assert(trained and castable and activated, 'the three clauses moved')
    assert(trained < castable,
        'IsTrained must still precede IsFullyCastable -- that ORDER is why the '
        .. "loader's cooldown modelling never reaches a reader")
    assert(castable < activated, 'IsActivated is still last')
end

tests['[reverse] the loader wires IsFullyCastable and only IsFullyCastable'] = function()
    local src = read_file('tests/mock/replay_fixture.lua')
    assert(src:find('IsFullyCastable = u.tp_cd <= 0', 1, true),
        'the loader no longer models the dumped TP cooldown')
    assert(src:find("api.MakeAbility('item_' .. itname", 1, true),
        'the carried-item handles moved')
    -- If either of the two masking clauses is ever wired by the loader, this
    -- file's counts change wholesale and it must be re-measured, not patched.
    local a = src:find('IsFullyCastable = u.tp_cd <= 0', 1, true)
    local window = src:sub(a - 600, a + 300)
    assert(not window:find('IsTrained', 1, true),
        'the loader now wires IsTrained -- re-measure this entire file')
    assert(not window:find('IsActivated', 1, true),
        'the loader now wires IsActivated -- re-measure this entire file')
end

tests['[world] so the shipped entry point does nothing, on every frame'] = function()
    local c = pass(false)
    assert(c.driven == 911, 'drivable frames moved: ' .. c.driven)
    assert(c.no_action == 911,
        'ItemUsageThink took an action on ' .. (911 - c.no_action)
        .. ' frames -- today it must be none')
    assert(c.action_total == 0, 'zero actions')
    assert(c.crash_total == 0,
        'and zero errors: the pass is clean AND empty, which is the trap')
end

-- ---------------------------------------------------------------------------
-- B. How big, measured.
-- ---------------------------------------------------------------------------

tests['[measure] honest TP handle: 0 -> 1 action and 0 -> 210 crashes'] = function()
    local c = pass(true)
    assert(c.driven == 911, 'same drivable set as the base sweep: ' .. c.driven)
    assert(c.crash_total == 210,
        'crashes under the honest probe moved: ' .. c.crash_total)
    assert(c.no_action == 700, 'silent frames moved: ' .. c.no_action)
    assert(c.action_total == 1,
        'the corpus produces exactly one item action; got ' .. c.action_total)
    assert(c.item_item_tpscroll == 1, 'and it is a TP scroll')
    assert(c.no_action + c.crash_total + 1 == c.driven,
        'the three buckets must partition the driven frames')
end

tests['[measure] the census half is identical in both sweeps'] = function()
    -- The probe is applied AFTER every measurement it could contaminate. Said
    -- as an assertion rather than as a comment, because "I put the probe in the
    -- right place" is exactly the kind of claim that rots.
    local a, b = pass(false), pass(true)
    for _, k in ipairs({ 'fixtures', 'subjects', 'alive', 'alive_H', 'alive_F',
        'slot_occupied', 'slot_castable', 'frames_zero_castable', 'has_tp',
        'tp_cooldown_ready', 'tp_castable', 'level15', 'rest5_H', 'rest5_F',
        'sole_blocker_H', 'outer_and_H', 'driven', 'aiug_load_fail' }) do
        assert(a[k] == b[k], 'the honest probe moved the census key ' .. k
            .. ': ' .. tostring(a[k]) .. ' vs ' .. tostring(b[k]))
    end
end

tests['[world] the 210 crashes name two more unstubbed engine APIs'] = function()
    local c = pass(true)
    -- 179/30 -> 178/32 on 2026-08-22T10:xxZ, and the move has TWO causes that
    -- had to be separated before either number could be re-pinned:
    --   * +1 at 2597 and +2 at 3325 is the two owner-P2 TP-home frames joining
    --     the corpus (measured: 98 fixtures 177/30/207, 100 fixtures
    --     178/32/210). Plain growth.
    --   * -2 at 2597 happened BEFORE them and is the interesting half. It does
    --     not reproduce on the 98-fixture corpus with bots/ at cac2fa5,
    --     41df6b4, 477d0d4 or 3dc30f2 -- all four read 177 -- so it is not any
    --     bots/ change, and specifically not the stayfield gate (the
    --     100-fixture reading is byte-identical with and without that diff).
    --     THE DIRECTOR BISECTED IT to the strategy stream's own 05:30Z commit
    --     cf7bb4c: healing f_260819_182855_lion_drain_jungle re-sampled the
    --     same --t about 0.33s earlier, so frames of an EXISTING fixture
    --     changed state and corpus-wide absolute counts moved with them
    --     (e8e9421 green, 41df6b4 red, same two failures). GH #107 / #106.
    --     That is the second half of #106's rule: a shared corpus is broken not
    --     only by ADDING a fixture but by HEALING one, and the heal gives no
    --     mechanism warning to the file it breaks.
    assert(c.crash_2597 == 178,
        'jmz_func:2597 crash count moved: ' .. c.crash_2597)
    assert(c.crash_3325 == 32,
        'jmz_func:3325 crash count moved: ' .. c.crash_3325)
    assert(c.crash_2597 + c.crash_3325 == c.crash_total,
        'a THIRD crash site appeared -- name it before touching these numbers')

    -- Both are engine globals the mock never defines, so the Get* default
    -- answers 0 (2597 then indexes a number) or nil (3325 then calls nil).
    rf.load('tests/fixtures/f_221200_od_roles.lua')
    assert(_G.GetFarmLaneDesire == nil,
        'GetFarmLaneDesire is now stubbed -- the 27 becomes something else')
    local J, bot = rf.load('tests/fixtures/f_221200_od_roles.lua')
    local other
    for _, h in pairs(J.GetNearbyHeroes(bot, 100000, true, BOT_MODE_NONE)) do other = h end
    assert(other ~= nil, 'the fixture has enemies')
    assert(type(other:GetExtrapolatedLocation(0.5)) ~= 'table',
        'GetExtrapolatedLocation now answers a location -- re-measure the 178')
end

tests['[world] the first of those two sits on a SHIPPED, ungated road'] = function()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local at = src:find('function J.CanEnemyInterruptTpChannel( bot )', 1, true)
    assert(at ~= nil, 'J.CanEnemyInterruptTpChannel moved')
    local body = src:sub(at, at + 1200)
    assert(body:find('GetExtrapolatedLocation( 0.5 )', 1, true),
        'the unstubbed call moved out of this helper')
    assert(not body:find('IsSoakCandidate', 1, true),
        'the shared core must stay ungated -- that is what makes it live')
    -- tpsafe2 was promoted on 2026-07-23; nothing in bots/ gates it any more.
    local n = 0
    local p = assert(io.popen("grep -rl \"IsSoakCandidate('tpsafe2')\" bots 2>/dev/null | wc -l"))
    n = tonumber(p:read('*a'):match('%d+'))
    p:close()
    assert(n == 0, 'tpsafe2 is gated again in ' .. n .. ' files -- if it is no '
        .. 'longer a turbo default, this road is not live and this test is wrong')
end

tests['[recorded] the one action the corpus can produce is an origin phantom'] = function()
    local c = pass(true)
    assert(#c.casts == 1, 'exactly one recorded action')
    local e = c.casts[1]
    assert(e.fixture == 'f_260819_222559_od_eclipse_solo.lua', 'fixture: ' .. e.fixture)
    assert(e.hero == 'npc_dota_hero_crystal_maiden', 'hero: ' .. e.hero)
    assert(e.fn == 'Action_UseAbilityOnLocation', 'cast type: ' .. e.fn)

    -- Reproduce it and read WHY. The trigger is the thirteenth world
    -- assertion's phantom, not a decision about this frame.
    local J, bot = rf.load('tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
        'npc_dota_hero_crystal_maiden')
    local v = J.GetTeamFightLocation(bot)
    assert(v ~= nil and v.x == 0 and v.y == 0,
        'the teamfight location is the map origin (thirteenth world assertion); got '
        .. tostring(v and v.x) .. ',' .. tostring(v and v.y))
    assert(bot:GetLevel() == 12,
        'and the caster is level 12, so this is NOT the ancient-guard branch '
        .. '(which needs 15) -- got ' .. bot:GetLevel())
end

tests['[reverse] the loop returns after the FIRST item that wants the frame'] = function()
    local src = read_file('bots/ability_item_usage_generic.lua')
    assert(src:find('local nItemSlot = { 5, 4, 3, 2, 1, 0, 15, 16 }', 1, true),
        'the scan order moved -- the TP scroll is slot 15, second to last')
    local at = src:find('local nItemDesire, hItemTarget, sCastType, sMotive = X.ConsiderItemDesire[sItemName]( hItem )', 1, true)
    assert(at ~= nil, 'the single call site of ConsiderItemDesire moved')
    local body = src:sub(at, at + 700)
    assert(body:find('return nSlot + 1', 1, true),
        'the loop no longer returns on the first willing item')
    -- Which is why the castability gap is not merely "the TP consider is
    -- unreachable": it is "nothing after the first willing item is reachable",
    -- and slot 15 is next to last in the scan.
    --
    -- NOT PINNED, and said so rather than left in a report: with EVERY item
    -- handle made honest (not just the TP's) the corpus yields 253 actions, of
    -- which 244 are boots -- power_treads 214, arcane_boots 30 -- and only 1 is
    -- the TP scroll. That third sweep is not run here because it would add
    -- another ~2 minutes for a number no assertion below depends on. To
    -- reproduce: extend the `honest_tp` probe in sweep() to every slot in
    -- SLOTS. Treat the 244 as a measurement someone made, not as a fact this
    -- file guards.
    local guard = src:find('if J.CanCastAbility(hItem)', 1, true)
    assert(guard ~= nil and guard < at,
        'CanCastAbility must still front the call -- it is the gate this file is about')
end

tests['[recorded] 29 subjects cannot load the item file at all (GH #82 naming)'] = function()
    local c = pass(false)
    assert(c.aiug_load_fail == 29, 'load failures moved: ' .. c.aiug_load_fail)
    assert(c.load_fail['npc_dota_hero_queen_of_pain'] == 12,
        'queen_of_pain subject count moved')
    assert(c.load_fail['npc_dota_hero_vengeful_spirit'] == 17,
        'vengeful_spirit subject count moved')
    -- ability_item_usage_generic:12 does dofile(BotLib/ .. gsub(name,'npc_dota_','')),
    -- and the repo files are hero_queenofpain / hero_vengefulspirit. The
    -- mismatch is in the dumped snapshot name, the same pair GH #82 found
    -- structurally blind to death events -- not a defect in bots/.
    local p = assert(io.popen('ls bots/BotLib | grep -c -E "^hero_(queenofpain|vengefulspirit)\\.lua$"'))
    local n = tonumber(p:read('*a'):match('%d+'))
    p:close()
    assert(n == 2, 'the two BotLib files are named without underscores; got ' .. n)
end

-- ---------------------------------------------------------------------------
-- C. Delivery to GH #84 §5: ability_item_usage_generic.lua:5753.
-- ---------------------------------------------------------------------------

tests['[census] the level term is the sole blocker on 197 honest frames'] = function()
    local c = pass(false)
    -- 508/193/190 -> 527/198/195 on 2026-08-22T10:xxZ: both owner-P2 TP-home
    -- frames carry a buildings block, so all 19 of their live hero-frames land
    -- in the HONEST half and 5 of them satisfy the other five operands. The
    -- finding is untouched: outer_and_H is still 3, i.e. the level term is
    -- still the only thing standing on every one of the rest.
    assert(c.alive_H == 537, 'honest-building hero frames moved: ' .. c.alive_H)
    assert(c.alive_F == 403, 'fallback-ancient hero frames moved: ' .. c.alive_F)
    assert(c.alive_H + c.alive_F == c.alive, 'the split partitions the corpus')
    assert(c.rest5_H == 200,
        'honest frames where the other five operands hold: ' .. c.rest5_H)
    assert(c.sole_blocker_H == 197,
        'honest frames where GetLevel() >= 15 is the ONLY closed operand: '
        .. c.sole_blocker_H)
    assert(c.outer_and_H == 3, 'honest frames where the whole AND holds: ' .. c.outer_and_H)
    assert(c.sole_blocker_H + c.outer_and_H == c.rest5_H, 'the two halves partition rest5')
    -- The fallback half is reported, never merged in: its o5 operand measures
    -- distance to the map centre (the seventeenth world assertion below).
    assert(c.rest5_F == 57 and c.sole_blocker_F == 57 and c.outer_and_F == 0,
        'the fallback half moved: ' .. c.rest5_F .. '/' .. c.sole_blocker_F)
end

tests['[census] only 8 of 911 frames are level 15 or better'] = function()
    local c = pass(false)
    assert(ANCIENT_GUARD_LEVEL == 15,
        'the shipped constant is now ' .. ANCIENT_GUARD_LEVEL
        .. ' -- every count in this section was measured at 15')
    assert(c.level15 == 8, 'mature frames moved: ' .. c.level15)
    assert(#c.mature == 8, 'and the roster has the same size')
    local full = {}
    for _, m in ipairs(c.mature) do
        if m.rest then full[#full + 1] = m.fixture .. '/' .. m.hero end
    end
    table.sort(full)
    assert(#full == 3, 'three of the eight satisfy the whole outer AND; got ' .. #full)
    assert(full[1] == 'f_260819_222559_od_eclipse_pair.lua/npc_dota_hero_viper', full[1])
    assert(full[2] == 'f_260819_222559_od_eclipse_solo.lua/npc_dota_hero_viper', full[2])
    assert(full[3] == 'f_260820_043120_viper_defend_paired.lua/npc_dota_hero_viper', full[3])
    -- All three are the same hero on three frames -- so "3" is a count of
    -- frames, not of independent situations. Said out loud so nobody reads it
    -- as breadth.
end

tests['[world] on those three frames the CONSEQUENT is still unreachable'] = function()
    local subject = 'npc_dota_hero_viper'
    for _, path in ipairs({
        'tests/fixtures/f_260819_222559_od_eclipse_pair.lua',
        'tests/fixtures/f_260819_222559_od_eclipse_solo.lua',
        'tests/fixtures/f_260820_043120_viper_defend_paired.lua',
    }) do
        local J, bot = rf.load(path, subject)
        local anc = GetAncient(bot:GetTeam())
        -- sub-branch 1: the nearest enemy lane front to our ancient.
        local ok, err = pcall(J.GetNearestLaneFrontLocation, anc:GetLocation(), true, 400)
        assert(not ok, 'GH #61 no longer refuses on ' .. path
            .. ' -- the (b) shape may now be possible; re-open GH #84 §5')
        assert(tostring(err):find('LOADER REFUSES', 1, true),
            'refused for a different reason: ' .. tostring(err))
        -- sub-branch 2: both tier-4 towers gone.
        assert(GetTower(bot:GetTeam(), 9) ~= nil, 'tier-4 #1 is standing on ' .. path)
        assert(GetTower(bot:GetTeam(), 10) ~= nil, 'tier-4 #2 is standing on ' .. path)
    end
end

tests['[reverse] the shipped ancient-guard branch still has that shape'] = function()
    local src = read_file('bots/ability_item_usage_generic.lua')
    -- Anchor on the block's own comment, not on the earlier `--守护遗迹bug`
    -- line 70 lines above it that names the same thing.
    local at = src:find('\n\t\t--守护遗迹\n', 1, true)
    assert(at ~= nil, 'the ancient-guard block moved')
    local body = src:sub(at, at + 1400)
    assert(body:find('if bot:GetLevel() >= 15', 1, true), 'the level term moved')
    assert(body:find('J.Role.ShouldTpToFarm()', 1, true), 'operand 2 moved')
    assert(body:find('bot:DistanceFromFountain() > 2000', 1, true), 'operand 3 moved')
    assert(body:find('GetUnitToUnitDistance( bot, nAncient ) > nMinTPDistance - 200', 1, true),
        'operand 4 moved')
    assert(body:find('J.GetAroundTargetAllyHeroCount( nAncient, 1400 ) == 0', 1, true),
        'operand 5 moved')
    assert(body:find('J.GetNearestLaneFrontLocation', 1, true), 'sub-branch 1 moved')
    assert(body:find('local ancientTower1 = GetTower(team, 9)', 1, true),
        'sub-branch 2 moved')
end

tests['[world] ShouldTpToFarm is TRUE on every frame, and that is structural'] = function()
    -- Operand 2 of the AND contributes nothing to the census: a fresh VM
    -- initialises lastFarmTpTime to -90 and every fixture frame is later than
    -- -86. In a game it is a 4s cooldown between farm TPs; on a fixture it can
    -- never be observed shut, so no count in this file may be read as evidence
    -- about it.
    local src = read_file('bots/FunLib/aba_role.lua')
    assert(src:find('____exports.lastFarmTpTime = -90', 1, true), 'the seed moved')
    assert(src:find('return DotaTime() > ____exports.lastFarmTpTime + 4', 1, true),
        'the predicate moved')
    local n = 0
    for _, path in ipairs(fixture_files()) do
        local ok, J, bot = pcall(rf.load, path)
        if ok and bot ~= nil then
            assert(J.Role.ShouldTpToFarm() == true, 'shut on ' .. path)
            n = n + 1
        end
    end
    assert(n == 101, 'checked every fixture; got ' .. n)
end

-- ---------------------------------------------------------------------------
-- D. The seventeenth world assertion, found on the same road.
-- ---------------------------------------------------------------------------

tests['[world] 43 fixtures answer GetAncient with a fort at the map origin'] = function()
    -- The 43 is unchanged and that is the point: both frames added on
    -- 2026-08-22T10:xxZ carry a buildings block, so the WITH side went 55 -> 57
    -- and the fallback side did not move at all.
    local c = pass(false)
    -- The count of hero frames whose team has NO tier-4 towers is exactly the
    -- count of frames on a fixture with no buildings block. Not one honest
    -- fixture has lost a tier-4.
    assert(c.both_t4_absent_F == 403, 'fallback frames without tier-4s: ' .. c.both_t4_absent_F)
    assert(c.both_t4_absent_F == c.alive_F, 'ALL fallback frames, i.e. the cause '
        .. 'is the missing block and not tower destruction')
    assert(c.both_t4_absent_H == 0, 'an honest fixture lost a tier-4 -- '
        .. 'the second sub-branch of the ancient guard may now be reachable')

    local nb, nnb = 0, 0
    for _, path in ipairs(fixture_files()) do
        local ok, _, _, _, fx = pcall(rf.load, path)
        if ok then
            if fx.buildings ~= nil then nb = nb + 1 else nnb = nnb + 1 end
        end
    end
    assert(nb == 58 and nnb == 43, 'the split moved: ' .. nb .. ' with / ' .. nnb .. ' without')
end

tests['[MECHANISM] the fallback ancient is one unit, both teams, unstable'] = function()
    local _, bot = rf.load('tests/fixtures/f_045650_lion_meatgrinder.lua')
    local mine, theirs = GetAncient(bot:GetTeam()), GetAncient(5 - bot:GetTeam())
    assert(mine:GetUnitName() == 'npc_dota_badguys_fort',
        'my own ancient is named after the Dire fort: ' .. mine:GetUnitName())
    assert(theirs:GetUnitName() == mine:GetUnitName(),
        'and so is the enemy one -- the team argument is ignored')
    assert(mine:GetLocation().x == 0 and mine:GetLocation().y == 0,
        'it stands at the map origin')
    assert(mine ~= GetAncient(bot:GetTeam()),
        'and a fresh handle comes back on every call, so identity comparisons '
        .. '(e.g. creep:GetAttackTarget() == nAncient) can never be true')
end

tests['[MECHANISM] an honest fixture answers with the real, team-correct ancient'] = function()
    local _, bot = rf.load('tests/fixtures/f_221200_od_roles.lua')
    local mine, theirs = GetAncient(bot:GetTeam()), GetAncient(5 - bot:GetTeam())
    assert(mine:GetUnitName() == 'ancient', 'real ancient handle: ' .. mine:GetUnitName())
    assert(mine ~= theirs, 'the two teams get different ancients')
    assert(mine:GetTeam() == bot:GetTeam(), 'and mine is mine')
    assert(mine:GetLocation().x ~= 0 or mine:GetLocation().y ~= 0, 'not at the origin')
    assert(mine == GetAncient(bot:GetTeam()), 'identity is stable')
end

tests['[reverse] the fallback lives in the mock, not in bots/'] = function()
    local src = read_file('tests/mock/bot_api.lua')
    local at = src:find('G.GetAncient = function()', 1, true)
    assert(at ~= nil, 'the default GetAncient moved')
    local body = src:sub(at, at + 300)
    assert(body:find("GetUnitName = 'npc_dota_badguys_fort'", 1, true), 'the name moved')
    assert(body:find('M.Vector(0, 0, 0)', 1, true), 'the origin moved')
    -- It takes no argument at all: that is the whole "answers for both teams".
    assert(src:sub(at, at + 30):find('function()', 1, true),
        'if it ever takes a team argument, re-measure the 403')
end

-- ---------------------------------------------------------------------------
-- E. What this file leaves behind (the stream's rule after the M16 leak).
-- ---------------------------------------------------------------------------

tests['[world] this file installs nothing into its successors'] = function()
    pass(false)   -- run the sweeps (in the child) before checking this process
    pass(true)
    -- The whole point of the subprocess is that the ~1700 aiug executions --
    -- and the five globals each one installs -- happen in a child VM that has
    -- already exited by the time this runs. So in THIS process the globals are
    -- exactly what they were before this file loaded: successors inherit the
    -- pre-existing value, and this file contributes nothing to it. (The earlier
    -- in-process design had to install-and-restore them; moving the drive to a
    -- child removed that hazard entirely, which is the cleaner form of the
    -- 0l/M16 successor-hygiene rule.)
    for _, g in ipairs(AIUG_GLOBALS) do
        assert(_G[g] == BEFORE[g],
            g .. ' changed in this process -- the sweep is supposed to run in a '
            .. 'child VM and touch nothing here')
    end
end

return tests
