-- `cmrguard` -- the third id of the 2026-08-19 cohort that sat at verify=0 for
-- 20 days -- retired from the armed set 2026-09-08 (director, test_set.md §GD;
-- state.json:cmrguard_RETURNED_20260908).  armed 42 -> 41.
--
-- ⛔ RETIRED FROM THE ARMED SET IS NOT REJECTED.  The gate, the helper body and
-- both constants stay byte-for-byte; that ruling had zero `bots/` diff.  What
-- this file pins is the BLINDNESS, so a future round proposing re-admission has
-- to go through the instrument rather than around it.
--
-- ⭐⭐⭐ THE FINDING WORTH CARRYING OUT OF THIS FILE.  `cmrguard` fires on
--
--     GetUnitToUnitDistance(cm, e) <= ( hCc:GetCastRange() or 0 ) + 400
--
-- and that cast range is read off an ENEMY's ability.  In this lab's fixture
-- loader an enemy's cast range is never read: it comes back through
-- tests/mock/bot_api.lua's `^Get -> 0` catch-all.  So the veto ring collapses to
-- the 400 buffer for every carrier outside the focus five, which is the
-- direction that DISARMS the gate -- and the sweep behind this file measures the
-- collapse as total: of 487 curated hard-CC handles across 110 fixtures, the 137
-- that answer a cast range are exactly the 137 the KV serves, and all 350 zeros
-- are the catch-all's.  Not one zero in the whole corpus was produced by reading
-- the KV and finding no cast range declared.
--
-- ⭐⭐ AND THE CASE IN CHIEF GOES WITH IT.  On the frame the gate was FILED FOR
-- (20260819_003005, Jakiro holding a ready ice_path 1138.6u away, who stunned CM
-- 0.6s into the channel and killed her), the armed gate ALLOWS the channel --
-- because 1138.6 > 0 + 400.  The green test that says otherwise
-- (tests/test_replay_260819_cm_r_range.lua) writes `GetCastRange = 1000` into
-- the handle first, and calls it an under-estimate in its own prose.  That test
-- is not wrong: 1000 is about right, and asserting the decision GIVEN the input
-- is exactly what a clause test should do.  It is only not condition (a), which
-- asks whether the input is ever READ.  Same shape as `wandlimbo` and `tpdead`
-- (test_set.md §GC, tests/test_blind_a_wandlimbo_tpdead.lua) -- third instance.
--
-- ⭐ AND UNDERNEATH IT, THE PART THAT IS NOT ABOUT THIS ID: THE LOADER ALREADY
-- DIAGNOSED THIS EXACT HAZARD AND FIXED THE NEIGHBOURING KEY.  Thirty lines
-- below the AbilityCastRange branch, replay_fixture.lua installs GetAbilityDamage
-- for EVERY ability of a KV hero -- declaring, in its own comment, that a 0 must
-- mean "the loader read the KV and found none" rather than "nothing was
-- installed", because `lionqdmg` and `zusboltcap` rest on that 0.  The
-- AbilityCastRange branch above it never got the same treatment, and an armed id
-- rested on ITS 0.  Case 4 parses both branches rather than quoting them.
--
-- ⛔ WHAT THIS FILE DOES NOT SAY.  It does not say `cmrguard` is a bad lever, and
-- it does not say (a) is unbuyable everywhere: unlike `wandlimbo`, ONE path
-- reaches the pivot -- tools/batch_test/behavioral/cmrguard_counterfactual.py
-- carries a datafeed-anchored per-level cast range table and declares it as an
-- out-of-frame anchor.  The re-admission condition (owed row
-- `cmrguard_castrange_instrument`) is that path's re-read on the existing
-- corpus, which is what the 2026-08-20 not-promoted verdict already asked for
-- and nobody took.
--
-- CORPUS READINGS pinned as literals from tests/_blind_a_cmrguard_sweep.lua
-- (110 fixtures, ~3s); the Lua detector leg is at its 120s budget (GH #358), the
-- same reason tests/_blind_a_sweep.lua is split out.  Re-take with:
--     lua5.1 tests/_blind_a_cmrguard_sweep.lua
--
--   G KV_ROSTER 5 (axe,crystal_maiden,lion,skeleton_king,zuus)
--   C FIXTURES 110   C HARDCC_HANDLES 487
--   C CR_ZERO 350    C CR_NONZERO 137
--   C KV_SERVED 137  C CATCHALL 350   C ACCIDENTALLY_RIGHT 100
--   C READY 304      C READY_ZERO 217

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local CLOSE = 'tests/fixtures/f_260819_003005_cm_selfpreserve.lua'  -- the case in chief
local FAR   = 'tests/fixtures/f_260819_004858_cm_centaur_far.lua'   -- the GH #34 false positive

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot read ' .. sPath)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Arm exactly the given candidate ids and evaluate the real guard on a frame.
local function guard_says(sPath, tArmed, fTweak)
    local J, bot, heroes = rf.load(sPath)
    local armed = {}
    for _, id in ipairs(tArmed) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    if fTweak then fTweak(J, bot, heroes) end
    local X = rf.load_hero('crystal_maiden')
    return X.cm_IsRSafeToOpen(bot), J, bot, heroes, X
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1 -- the case in chief: armed, on its own motivating frame, the gate is inert
-- ---------------------------------------------------------------------------

tests['[1a] the motivating frame is real in every term the loader can read'] = function()
    local J, bot, heroes = rf.load(CLOSE)
    local jak = heroes['npc_dota_hero_jakiro']
    local ice = jak:GetAbilityByName('jakiro_ice_path')
    -- Real dump data: the distance, the level and the cooldown all come off the
    -- frame.  This is why the blindness is hard to see -- everything else is real.
    assert(math.floor(GetUnitToUnitDistance(bot, jak)) == 1138,
        'the GH #34 / hero.md backlog #2 frame: Jakiro 1138.6u away')
    assert((ice:GetLevel() or 0) >= 1, 'ice_path is leveled on the real frame')
    assert((ice:GetCooldownTimeRemaining() or 0) <= 0, 'and off cooldown on the real frame')
    assert(J.GetReadyHardCc(jak) ~= nil,
        'so the curated scan finds him -- the CAPABILITY half of the gate is bought')
    -- And the one term that is not read.
    assert(ice:GetCastRange() == 0,
        'the DELIVERY half is not: an enemy cast range comes back through the '
        .. '`^Get -> 0` catch-all, not from the KV')
end

tests['[1b] armed on that frame, the gate ALLOWS the channel that killed her'] = function()
    local bSafe = guard_says(CLOSE, { 'cmrguard' })
    assert(bSafe == true,
        'armed and unauthored, cmrguard does not fire on the frame it was filed '
        .. 'for -- 1138.6 > 0 + 400.  This is the reading the ruling rests on')
end

tests['[1c] with the cast range supplied, the same frame withholds -- the lever works'] = function()
    local bSafe = guard_says(CLOSE, { 'cmrguard' }, function(_, _, heroes)
        rawget(heroes['npc_dota_hero_jakiro']:GetAbilityByName('jakiro_ice_path'),
            '__spec').GetCastRange = 1000
    end)
    assert(bSafe == false,
        'the defect is in the instrument, not in the lever: given the delivery '
        .. 'range the engine would report, the gate catches its own case')
end

tests['[1d] the existing green test supplies exactly that value, and says so'] = function()
    -- Parsed, not quoted, so rewriting the prose takes this red rather than
    -- orphaning the citation.  ⛔ Needles verified present at ruling time
    -- (the `text_absent` lesson, test_set.md §GC.4: a needle that never matched
    -- and a sentence that was deleted are indistinguishable byte for byte).
    local t = read_file('tests/test_replay_260819_cm_r_range.lua')
    -- ⚠ Pinned as the CASE-IN-CHIEF line, not as the substring `GetCastRange =
    -- 1000`: that substring occurs twice in the file (the Centaur "pretend it is
    -- ranged" mutation is the other), so the loose form stayed green when the
    -- ice_path stub was deleted -- M6 SURVIVED on the first pass of
    -- tools/agent/mutstand_blind_a_cmrguard.sh, and the mutant was right while
    -- the assertion was wrong (evidence discipline 2).
    assert(t:find("rawget(icePath, '__spec').GetCastRange = 1000", 1, true),
        'test_replay_260819_cm_r_range.lua no longer writes the cast range into '
        .. 'the ice_path handle -- if it now READS one, the fixture path may be '
        .. 'open and case 1b must be re-taken')
    assert(t:find('ranged_cc', 1, true),
        'its helper for supplying a ranged CC is gone -- same re-take')
end

-- ---------------------------------------------------------------------------
-- 2 -- the collapse is total, and `cmrcap` is provably inert on top of it
-- ---------------------------------------------------------------------------

tests['[2a] the KV roster is the focus five -- the zero is a roster fact'] = function()
    local roster = {}
    for k in pairs(shapes.SHAPES) do roster[#roster + 1] = k end
    table.sort(roster)
    assert(#roster == 5, 'KV_ROSTER moved from 5 to ' .. #roster
        .. ' -- if a hard-CC carrier joined it, re-take the sweep')
    assert(table.concat(roster, ',') == 'axe,crystal_maiden,lion,skeleton_king,zuus',
        'the KV roster is no longer the focus five: ' .. table.concat(roster, ','))
end

tests['[2b] a correct zero and a missing zero come out of the same line'] = function()
    -- axe HAS a KV block, and `axe_berserkers_call` is in it -- but the block
    -- declares no AbilityCastRange, so replay_fixture never installs the getter
    -- and the read falls to bot_api.lua's catch-all, exactly as Jakiro's does.
    -- The engine's real answer for berserkers_call IS 0 (no-target), so that one
    -- is right -- for the wrong reason, and indistinguishable from the read.
    local axe = shapes.SHAPES['axe']
    assert(axe ~= nil and axe['axe_berserkers_call'] ~= nil,
        'axe_berserkers_call is no longer in the KV block -- re-take case 2b')
    assert(axe['axe_berserkers_call']['AbilityCastRange'] == nil,
        'the block now declares AbilityCastRange for berserkers_call -- if the '
        .. 'loader now serves it, the "same line" claim must be re-taken')
    local jak = shapes.SHAPES['jakiro']
    assert(jak == nil, 'jakiro gained a KV block -- re-take the sweep and case 1b')
end

tests['[2c] cmrcap cannot change a decision while the range term is the catch-all'] = function()
    -- `cmrcap` caps the range term at 200.  math.min(0, 200) == 0, so on every
    -- frame where the term is the catch-all's zero the cap is a no-op -- which is
    -- every frame outside the focus five.  Its own admission note says it "must
    -- ride the same arm as cmrguard"; this is the stronger statement, that even
    -- riding it there is nothing for it to narrow here.
    for _, path in ipairs({ CLOSE, FAR }) do
        local bWithout = guard_says(path, { 'cmrguard' })
        local bWith    = guard_says(path, { 'cmrguard', 'cmrcap' })
        assert(bWithout == bWith,
            'cmrcap changed the decision on ' .. path .. ' -- if the loader now '
            .. 'serves an enemy cast range, this whole file must be re-taken')
    end
end

tests['[2d] the constants the ruling did NOT touch are still there'] = function()
    -- Retiring an id from the armed set is not rejecting it: nothing in `bots/`
    -- moved.  Pinned because deleting the now-unarmed branch would be the easy
    -- tidy-up, and it would turn a reversible retirement into a silent reject.
    local _, _, _, _, X = guard_says(FAR, {})
    assert(X.nRGuardCloseBuffer == 400, 'the closing buffer moved from 400')
    assert(X.nRGuardRangeCap == 200, 'cmrcap\'s cap moved from 200')
    local src = read_file('bots/BotLib/hero_crystal_maiden.lua')
    assert(src:find("J.IsSoakCandidate( 'cmrguard' )", 1, true),
        'the cmrguard gate is gone from hero_crystal_maiden.lua -- the retirement '
        .. 'was from the armed STRING, not from the source')
    assert(src:find("J.IsSoakCandidate( 'cmrcap' )", 1, true),
        'the cmrcap gate is gone -- same')
end

-- ---------------------------------------------------------------------------
-- 3 -- the debt is not this id's alone
-- ---------------------------------------------------------------------------

tests['[3a] exactly two call sites read a cast range off an ENEMY handle'] = function()
    -- One is `cmrguard` (gated, and as of this ruling not armed).  The other is
    -- the ccburst window in J.IsAboutToBeAttacked -- SHIPPED, live in every
    -- game, ungated.  So buying this instrument is not a favour to one retired
    -- candidate: today no fixture can test the shipped path's delivery term
    -- either, and it models every ranged CC as self-radius in the same direction.
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    local cm  = read_file('bots/BotLib/hero_crystal_maiden.lua')
    local n = 0
    for _, src in ipairs({ jmz, cm }) do
        for _ in src:gmatch('hCc:GetCastRange%(%)') do n = n + 1 end
    end
    assert(n == 2, 'the enemy-side cast range now has ' .. n .. ' consumers, not 2 '
        .. '-- a new one inherits this blindness and the ruling\'s scope must be re-taken')
    assert(jmz:find('local hCc = J.GetReadyHardCc( hEnemy )', 1, true),
        'the shipped ccburst consumer moved -- re-take case 3a')
    -- It is ungated: no IsSoakCandidate on the branch that reads the range.
    local window = jmz:match('if bCcAware then.-end')
    assert(window ~= nil and not window:find('IsSoakCandidate', 1, true),
        'the shipped consumer grew a gate -- then it is no longer evidence that '
        .. 'the debt is live in real games')
end

tests['[3b] the loader fixed this hazard for the neighbouring key and not this one'] = function()
    local ld = read_file('tests/mock/replay_fixture.lua')
    -- AbilityCastRange: installed only when the key is declared.
    local cr = ld:match("local cast_range = value_ladder.-\n.-\n.-\n.-\n.-\n")
    assert(ld:find("local cast_range = value_ladder(u.name, a.name, 'AbilityCastRange')", 1, true),
        'the AbilityCastRange branch moved -- re-take case 3b')
    assert(cr ~= nil and cr:find('if cast_range ~= nil then', 1, true),
        'the AbilityCastRange getter is no longer conditional on the key being '
        .. 'declared -- if it is now installed unconditionally, half the purchase '
        .. 'has landed and this file must be re-taken')
    -- AbilityDamage: installed unconditionally, with the reason written down.
    assert(ld:find('sp.GetAbilityDamage = function(self)', 1, true)
        and ld:find('if ability_damage == nil then return 0 end', 1, true),
        'the AbilityDamage getter no longer answers 0 from inside the loader -- '
        .. 'the contrast this case rests on is gone')
    assert(ld:find('indistinguishable from the read', 1, true),
        'the loader no longer declares the hazard it fixed for AbilityDamage -- '
        .. 'that declaration is the reason this is a missed application and not a '
        .. 'newly discovered problem')
end

tests['[3c] no promote atom names cmrguard, so retiring it froze no other lever'] = function()
    -- The `pullcad` trap runs the other way too: an id leaving the armed set
    -- cannot silently freeze a gate that names it.  Checked, not assumed.
    local atoms = read_file('iterations/promote_atoms.json')
    assert(not atoms:find('cmrguard', 1, true),
        'a promote atom now names cmrguard -- the retirement must be re-checked '
        .. 'against it before it can stand')
end

return tests
