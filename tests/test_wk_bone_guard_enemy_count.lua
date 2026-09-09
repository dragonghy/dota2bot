-- [hero] `wkbonefight` -- X.ConsiderW releases Bone Guard only in a DUEL, and a
-- duel is the cheapest fight it will ever join.  Written 2026-09-05 under
-- OWNER_PRIORITIES P4.4 (bots/ 主体配额).
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_skeleton_king.lua X.ConsiderW's first branch (the 辅助进攻
-- release) read:
--
--     if J.IsValidHero( npcTarget )
--         and #nEnemysHerosInView == 1            <-- this term
--         and J.IsInRange( npcTarget, bot, 650 )
--         and ( nStack / maxStack >= 0.6 or talent6:IsTrained() )
--
-- `nEnemysHerosInView` is J.GetNearbyHeroes(bot, 1600, true, ...), i.e. the
-- enemy heroes WK can actually SEE within 1600.  `== 1` is a duel test: it fires
-- when WK is alone with one enemy and stays silent through every teamfight.
--
-- Bone Guard is DOTA_ABILITY_BEHAVIOR_NO_TARGET (tests/mock/ability_behavior.lua)
-- costing 70/80/90/100 mana on a FLAT 42s cooldown plus a 0.1s cast point
-- (tests/mock/special_value_shapes.lua).  No term of that price is a function of
-- the enemy count, so the enemy count cannot be a reason to withhold it -- while
-- the payoff runs the other way: skeletons live 40s and carry +25 damage against
-- HEROES on top of 34/39/43/49.  Section 1 anchors every one of those numbers on
-- the repo's KV snapshot so the argument goes red instead of stale when a patch
-- moves them.
--
-- WHAT THIS FILE DOES AND DOES NOT COVER -- READ BEFORE QUOTING IT
-- ----------------------------------------------------------------
--   * THE BRANCH IS NOT FIXTURE-DRIVABLE, and that was already this desk's own
--     finding, written above X.ConsiderW since 2026-08-23 and re-read 2026-08-28
--     (GH #274): modifier_skeleton_king_bone_guard is on 0 of the Wraith King
--     frames because make_fixture.py rebuilds modifiers from combat-log
--     ADD/REMOVE pairs and there are none for this one.  A second, independent
--     blocker is J.GetProperTarget, structurally nil on every fixture frame
--     (GH #474).  Section 5 asserts BOTH, on the frames, so that "source-level
--     coverage" cannot rot into a habit: the day either is fixed this file goes
--     red and names it.
--   * WHAT IS DRIVEN ON REAL FRAMES IS THE TERM THAT CHANGED.  Section 2 runs
--     the REAL J.GetNearbyHeroes on 13 real Wraith-King-subject instants and
--     feeds the REAL helper the counts it returns.  That is not the whole
--     branch, and this file never says it is -- but it is not gate plumbing
--     either: no value in section 2 is invented by the test.
--   * COUNTS ARE VISION-LIMITED.  J.GetNearbyHeroes wraps bot:GetNearbyHeroes,
--     so "2 visible enemies" is what WK could really see, not what stood there.
--     That makes section 2 a LOWER bound on how often the multi-enemy case is
--     reached, which errs against the change rather than for it.
--   * SIZING IS NOT HERE.  The block above X.ConsiderW says it in one line --
--     "Size a Bone Guard change with a batch request, never with a fixture
--     scan" -- and this round obeys it: iterations/queue.json hero-31.
--   * Section 2's counts come from the loader via dofile, never from a regex
--     over the fixture text (the Axe threshold pre-flight under-counted its own
--     frames exactly that way).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')
local behavior = require('mock.ability_behavior')

local SRC = 'bots/BotLib/hero_skeleton_king.lua'
local WK = 'npc_dota_hero_skeleton_king'
local GUARD = 'skeleton_king_bone_guard'
local MOD = 'modifier_skeleton_king_bone_guard'
local CAND = 'wkbonefight'
local VIEW_RADIUS = 1600  -- the radius X.ConsiderW passes to J.GetNearbyHeroes
local REACH = 650         -- the branch's J.IsInRange( npcTarget, bot, 650 )

-- Every Wraith-King-SUBJECT fixture, listed rather than globbed so a new one is
-- a deliberate edit and section 2's counts move with a named cause.
local WK_FRAMES = {
    'tests/fixtures/f_080225_wk_lane.lua',
    'tests/fixtures/f_080225_wk_revive.lua',
    'tests/fixtures/f_163732_sk_pull_ambush.lua',
    'tests/fixtures/f_225947_wk_trade_kite.lua',
    'tests/fixtures/f_230545_wk_laning_safe.lua',
    'tests/fixtures/f_230545_wk_sven_burst.lua',
    'tests/fixtures/f_232228_wk_ownhalf_standoff.lua',
    'tests/fixtures/f_232320_wk_od_burst.lua',
    'tests/fixtures/f_260725_105305_wk_reincarn_gap.lua',
    'tests/fixtures/f_260820_102030_wk_tower_in_reach.lua',
    'tests/fixtures/f_260820_102030_wk_tower_out_of_reach.lua',
    'tests/fixtures/f_260820_181711_wk_l1trade_333.lua',
    'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The source of one X.<name> function, comments included (the ratchets in
--- section 6 that want comments stripped strip them themselves).
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load a real frame, arm (or do not arm) `wkbonefight`, and hand back the
--- hero module together with the frame's own handles.
---
--- `opt.armed == true` and not `opt.armed`: an absent key would make this
--- return nil, and a helper asserted `== false` then fails on a nil that is
--- behaviourally identical.  The distinction is the test's, not the gate's.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_axe_call_immune_veto.lua does.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('skeleton_king')
    return X, J, bot, heroes, fx
end

--- The visible enemy-hero count X.ConsiderW would compute on this frame, from
--- the REAL helper on the REAL frame.
local function visible_enemies(J, bot)
    return #J.GetNearbyHeroes(bot, VIEW_RADIUS, true, BOT_MODE_NONE)
end

--- The enemy-hero TABLE X.ConsiderW computes and now hands to the helper.  Same
--- call, same radius; section 2 counts `#` of this and the helper walks it.
local function visible_table(J, bot)
    return J.GetNearbyHeroes(bot, VIEW_RADIUS, true, BOT_MODE_NONE)
end

--- Is any enemy hero inside the 650 the branch's J.IsInRange asks for?  A
--- GEOMETRIC PROXY for that term and labelled as one: the term itself reads
--- J.GetProperTarget, which section 5 measures as structurally nil here.
local function enemy_within_reach(bot, heroes)
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam()
            and GetUnitToUnitDistance(bot, h) <= REACH
        then return true end
    end
    return false
end

-- ---------------------------------------------------------------- section 1 --
-- The ability's shape, from the repo's own KV snapshot.  This is the price/payoff
-- argument's evidence, not colour: if a patch makes the cooldown scale with
-- anything, or makes the release targeted, the argument changes and this goes red.

tests['section 1: Bone Guard is NO_TARGET -- the release picks nobody'] = function()
    local b = behavior.BEHAVIOR and behavior.BEHAVIOR['skeleton_king']
        or (behavior['skeleton_king'])
    assert(b ~= nil, 'no behavior block for skeleton_king in tests/mock/ability_behavior.lua')
    local s = b[GUARD]
    assert(s ~= nil, 'no behavior string for ' .. GUARD)
    assert(s:find('DOTA_ABILITY_BEHAVIOR_NO_TARGET', 1, true),
        'Bone Guard is no longer NO_TARGET (' .. s .. ').  The whole enemy-count '
        .. 'argument rests on the release having no target and no positioning '
        .. 'requirement -- re-argue it before trusting the gate.')
end

tests['section 1: the price does not scale with the enemy count'] = function()
    local sk = shapes.SHAPES and shapes.SHAPES['skeleton_king'] or shapes['skeleton_king']
    assert(sk ~= nil, 'no skeleton_king block in tests/mock/special_value_shapes.lua')
    local kv = sk[GUARD]
    assert(kv ~= nil, 'no ' .. GUARD .. ' block in the KV snapshot')
    assert(kv['AbilityCooldown'].base == '42',
        'Bone Guard cooldown is no longer a flat 42 (got '
        .. tostring(kv['AbilityCooldown'].base) .. ')')
    assert(kv['AbilityManaCost'].base == '70 80 90 100',
        'mana ladder moved: ' .. tostring(kv['AbilityManaCost'].base))
    assert(kv['AbilityCastPoint'].base == '0.1',
        'cast point moved: ' .. tostring(kv['AbilityCastPoint'].base))
end

tests['section 1: the payoff is hero-facing and 40s long'] = function()
    local sk = shapes.SHAPES and shapes.SHAPES['skeleton_king'] or shapes['skeleton_king']
    local kv = sk[GUARD]
    assert(kv['skeleton_duration'].base == '40',
        'skeleton duration moved: ' .. tostring(kv['skeleton_duration'].base))
    assert(kv['skeleton_bonus_hero_damage'].base == '25',
        'the +25 vs heroes moved: ' .. tostring(kv['skeleton_bonus_hero_damage'].base))
    assert(kv['skeleton_damage_tooltip'].base == '34 39 43 49',
        'skeleton damage moved: ' .. tostring(kv['skeleton_damage_tooltip'].base))
    assert(kv['max_skeleton_charges'].base == '2 4 6 8',
        'the charge cap moved: ' .. tostring(kv['max_skeleton_charges'].base))
end

-- ---------------------------------------------------------------- section 2 --
-- The supply, measured on real frames through the real helper.

tests['section 2: 13 real WK instants, and the shipped clause discards most of them'] = function()
    local nArmed, nShipped, byCount = 0, 0, {}
    for _, path in ipairs(WK_FRAMES) do
        local X, J, bot, _, fx = on_frame(path)
        assert(fx.self == WK, path .. ' is not a WK-subject frame; WK_FRAMES is stale')
        local t = visible_table(J, bot)
        local n = #t
        byCount[n] = (byCount[n] or 0) + 1
        -- shipped: the same helper with the gate down.
        if X.IsBoneGuardEnemyCountOk(n, t, REACH) then nShipped = nShipped + 1 end
        local XA = select(1, on_frame(path, { armed = true }))
        if XA.IsBoneGuardEnemyCountOk(n, t, REACH) then nArmed = nArmed + 1 end
    end
    assert(#WK_FRAMES == 13, 'frame count changed; re-read the numbers below')
    assert((byCount[0] or 0) == 4 and (byCount[1] or 0) == 2 and (byCount[2] or 0) == 7,
        ('visible-enemy histogram moved: 0->%d 1->%d 2->%d (was 4/2/7)'):format(
            byCount[0] or 0, byCount[1] or 0, byCount[2] or 0))
    assert(nShipped == 2, 'shipped clause admits ' .. nShipped .. ' of 13, expected 2')
    assert(nArmed == 6, 'armed clause admits ' .. nArmed .. ' of 13, expected 6')
end

-- THE NARROWING, MEASURED.  This is the section the 2026-09-09 change exists for
-- and the one that would have to be re-argued to widen the leg back to 1600.
tests['section 2: 3 of the old armed leg 9 were priced on enemies out of reach'] = function()
    local nOld, nNew, tDropped = 0, 0, {}
    for _, path in ipairs(WK_FRAMES) do
        local X, J, bot = on_frame(path, { armed = true })
        local t = visible_table(J, bot)
        local n = #t
        -- The leg as it read before 2026-09-09: any non-zero 1600 count.
        local bOld = n >= 1
        local bNew = X.IsBoneGuardEnemyCountOk(n, t, REACH)
        if bOld then nOld = nOld + 1 end
        if bNew then nNew = nNew + 1 end
        if bOld and not bNew then
            tDropped[#tDropped + 1] = ('%s (%d in view, %d in reach)'):format(
                path:gsub('tests/fixtures/', ''), n, X.wk_CountBoneGuardEngaged(t, REACH))
        end
    end
    assert(nOld == 9 and nNew == 6,
        ('old leg %d, new leg %d of 13 (was 9 -> 6)'):format(nOld, nNew))
    assert(#tDropped == 3,
        ('%d frame(s) dropped, expected 3: %s'):format(#tDropped, table.concat(tDropped, '; ')))
    -- Named, because the argument is about these specific geometries: two frames
    -- hold ONE enemy in the ring and a second one far off -- a duel the 1600
    -- count read as a teamfight -- and one holds NONE at all inside 650.
    local sAll = table.concat(tDropped, '; ')
    for _, sWant in ipairs({ 'laning_safe', 'sven_burst', 'reincarn_gap' }) do
        assert(sAll:find(sWant, 1, true),
            sWant .. ' is no longer among the dropped frames: ' .. sAll)
    end
    assert(sAll:find('sven_burst.lua (2 in view, 0 in reach)', 1, true),
        'the zero-in-reach case study moved; it is the clearest statement of the '
        .. 'defect (the old leg counted a "2v2" with nobody the skeletons could '
        .. 'reach): ' .. sAll)
end

tests['section 2: the engaged ring is a subset of the view ring, on every frame'] = function()
    -- The structural fact the call site relies on: #tEnemies is the 1600 count,
    -- and the helper walks THAT table, so engaged <= view always.  This is what
    -- makes "armed fires at n=0" impossible in the real branch rather than
    -- merely unobserved -- section 3 leans on it.
    local byEngaged = {}
    for _, path in ipairs(WK_FRAMES) do
        local X, J, bot = on_frame(path, { armed = true })
        local t = visible_table(J, bot)
        local e = X.wk_CountBoneGuardEngaged(t, REACH)
        byEngaged[e] = (byEngaged[e] or 0) + 1
        assert(e <= #t, path .. ': engaged ' .. e .. ' > view ' .. #t)
    end
    assert((byEngaged[0] or 0) == 6 and (byEngaged[1] or 0) == 3
        and (byEngaged[2] or 0) == 4,
        ('engaged-enemy histogram moved: 0->%d 1->%d 2->%d (was 6/3/4)'):format(
            byEngaged[0] or 0, byEngaged[1] or 0, byEngaged[2] or 0))
end

tests['section 2: inside the branch geometry the shipped clause admits 1 of 7'] = function()
    -- The frames that matter are the ones already shaped like branch 1: an enemy
    -- hero inside the 650 the branch reaches for.  ONE-SIDED TRIPWIRE -- more
    -- fixtures can only move these counts, and the day the ratio inverts this
    -- goes red and says so.
    local nReach, nReachShipped, nReachArmed, sExample = 0, 0, 0, nil
    for _, path in ipairs(WK_FRAMES) do
        local X, J, bot, heroes = on_frame(path)
        if enemy_within_reach(bot, heroes) then
            nReach = nReach + 1
            local t = visible_table(J, bot)
            local n = visible_enemies(J, bot)
            assert(n == #t, path .. ': the count and the table disagree')
            if X.IsBoneGuardEnemyCountOk(n, t, REACH) then
                nReachShipped = nReachShipped + 1
            elseif sExample == nil then
                sExample = path .. ' (' .. n .. ' visible enemies)'
            end
            local XA = select(1, on_frame(path, { armed = true }))
            if XA.IsBoneGuardEnemyCountOk(n, t, REACH) then
                nReachArmed = nReachArmed + 1
            end
        end
    end
    assert(nReach == 7, 'frames with an enemy inside ' .. REACH .. ': ' .. nReach .. ', expected 7')
    assert(nReachShipped == 1,
        'shipped clause admits ' .. nReachShipped .. ' of those ' .. nReach .. ', expected 1')
    -- 5, not 7: inside the branch geometry the narrowed leg still triples what
    -- shipped admits, and the two it declines are the ones holding a single
    -- enemy in the ring -- i.e. the duels shipped was right to price as duels.
    assert(nReachArmed == 5,
        'armed clause admits ' .. nReachArmed .. ' of those ' .. nReach .. ', expected 5')
    assert(sExample ~= nil,
        'no discarded frame found -- section 2 has nothing to show and the '
        .. 'headline "6 of 7 are discarded" is no longer supported')
end

-- ---------------------------------------------------------------- section 3 --
-- Direction, by construction.  A single-value assertion is what let `cullthresh`
-- ship a guard that silently narrowed its own lever, so this sweeps the ladder.

-- The ladder is now swept over (count, table) PAIRS, because the narrowed leg
-- reads both.  Sweeping the count alone against no table would exercise only the
-- restrictive fallback and report a superset that holds vacuously -- the shape
-- that let the Axe round's mutants survive a correct fix (hero 2026-09-09T17:10Z).
tests['section 3: armed is a superset of shipped, over the ladder x every frame'] = function()
    local nWidened, nPairs = 0, 0
    for _, path in ipairs(WK_FRAMES) do
        local X, J, bot = on_frame(path)
        local XA = select(1, on_frame(path, { armed = true }))
        local t = visible_table(J, bot)
        for n = 0, 10 do
            local bShipped = X.IsBoneGuardEnemyCountOk(n, t, REACH)
            local bArmed = XA.IsBoneGuardEnemyCountOk(n, t, REACH)
            nPairs = nPairs + 1
            assert(type(bShipped) == 'boolean' and type(bArmed) == 'boolean',
                'the helper answered a non-boolean at n=' .. n .. ' on ' .. path)
            if bShipped then
                assert(bArmed, ('%s n=%d: shipped releases and armed does not. This '
                    .. 'lever is only allowed to ADD releases; a removal is silent '
                    .. '-- no counter reports a Bone Guard that was not cast.')
                    :format(path, n))
            end
            if bArmed and not bShipped then nWidened = nWidened + 1 end
        end
    end
    assert(nPairs == 143, 'expected 13 frames x 11 counts = 143 pairs, got ' .. nPairs)
    -- 40 = the 4 frames holding 2 enemies inside 650, each widening every count
    -- except n=1 (where shipped already releases).  A frame with fewer than 2 in
    -- the ring widens NOTHING, which is the whole point of the narrowing.
    assert(nWidened == 40,
        'armed widens ' .. nWidened .. ' of 143 (count, frame) pairs, expected 40')
end

tests['section 3: a missing table falls back to the shipped duel test'] = function()
    -- The RESTRICTIVE default, asserted rather than assumed.  A permissive one
    -- would restore the old 1600-ring leg for any caller that forgot the
    -- argument, and no counter would report it.
    local XA = select(1, on_frame(WK_FRAMES[1], { armed = true }))
    for n = 0, 10 do
        assert(XA.IsBoneGuardEnemyCountOk(n) == (n == 1),
            ('armed with no table answered %s at n=%d; the fallback must be the '
            .. 'shipped `== 1`'):format(tostring(XA.IsBoneGuardEnemyCountOk(n)), n))
    end
end

tests['section 3: neither leg releases with nobody in view'] = function()
    -- Each frame paired with ITS OWN count, which is the only pairing the call
    -- site can produce (n = #tEnemies).  Section 2 pins engaged <= view, so a
    -- zero view count forces a zero engaged count and the armed disjunct cannot
    -- reach.  Four of the 13 frames really are at n=0, so this is measured.
    local nZero = 0
    for _, path in ipairs(WK_FRAMES) do
        local X, J, bot = on_frame(path)
        local XA = select(1, on_frame(path, { armed = true }))
        local t = visible_table(J, bot)
        if #t == 0 then
            nZero = nZero + 1
            assert(X.IsBoneGuardEnemyCountOk(0, t, REACH) == false,
                'shipped fires at 0 enemies on ' .. path)
            assert(XA.IsBoneGuardEnemyCountOk(0, t, REACH) == false,
                'armed fires at 0 enemies on ' .. path .. ' -- widening the count '
                .. 'term must not turn the branch into an unconditional release')
        end
    end
    assert(nZero == 4, 'expected 4 frames with nobody in view, got ' .. nZero)
end

-- ---------------------------------------------------------------- section 4 --
-- Gate hygiene.  Inert unless turbo AND this id armed.

-- EVERY control below hands over a table that WOULD open the armed disjunct
-- (WK_FRAMES[1] holds 2 enemies inside 650, section 2's histogram).  Passing no
-- table would drop these onto the restrictive fallback, where the shipped answer
-- comes back whether the gate is open or shut and the control proves nothing.
local function opener_table(path)
    local _, J, bot = on_frame(path, { armed = true })
    local t = J.GetNearbyHeroes(bot, VIEW_RADIUS, true, BOT_MODE_NONE)
    local XA = rf.load_hero('skeleton_king')
    assert(XA.wk_CountBoneGuardEngaged(t, REACH) >= 2,
        path .. ' no longer holds 2 enemies inside ' .. REACH .. '; section 4 has '
        .. 'stopped being a control and now passes for the wrong reason')
    assert(XA.IsBoneGuardEnemyCountOk(3, t, REACH) == true,
        'the armed leg does not open on this table; section 4 proves nothing')
    return t
end

tests['section 4: unarmed reproduces the shipped duel test exactly'] = function()
    local t = opener_table(WK_FRAMES[1])
    local X = on_frame(WK_FRAMES[1])
    for n = 0, 5 do
        assert(X.IsBoneGuardEnemyCountOk(n, t, REACH) == (n == 1),
            'unarmed answer at n=' .. n .. ' is not the shipped `== 1`')
    end
end

tests['section 4: armed but NOT turbo reproduces the shipped duel test'] = function()
    local t = opener_table(WK_FRAMES[1])
    local X = select(1, on_frame(WK_FRAMES[1], { armed = true, nonTurbo = true }))
    for n = 0, 5 do
        assert(X.IsBoneGuardEnemyCountOk(n, t, REACH) == (n == 1),
            'non-turbo answer at n=' .. n .. ' is not the shipped `== 1`; this gate '
            .. 'is turbo-only')
    end
end

tests['section 4: another id armed does not open this one'] = function()
    local t = opener_table(WK_FRAMES[1])
    local _, J = on_frame(WK_FRAMES[1])
    J.IsSoakCandidate = function(id) return id == 'wkbuild' end
    local X = rf.load_hero('skeleton_king')
    assert(X.IsBoneGuardEnemyCountOk(3, t, REACH) == false,
        'a different armed id opened wkbonefight -- the gate reads the wrong name')
end

-- ---------------------------------------------------------------- section 5 --
-- The two upstream blockers, measured rather than recalled.  These are the
-- reason this file claims source-level coverage of the BRANCH, and each one is
-- written so that fixing it turns this section red and names the frame.

tests['section 5: the charge modifier is on 0 of the WK-subject frames (GH #274)'] = function()
    local nWith, sFirst = 0, nil
    for _, path in ipairs(WK_FRAMES) do
        local _, _, bot = on_frame(path)
        if bot:HasModifier(MOD) then
            nWith = nWith + 1
            sFirst = sFirst or path
        end
    end
    assert(nWith == 0,
        ('%s now appears on %d frame(s), first %s.  GOOD NEWS, NOT A FAILURE: the '
        .. 'dumper gap that made X.ConsiderW unreachable offline is closed, so '
        .. 'this lever can finally be driven end to end.  Rewrite this file to do '
        .. 'that and drop the source-level-coverage label.'):format(
            MOD, nWith, tostring(sFirst)))
end

tests['section 5: J.GetProperTarget is nil on every WK-subject frame (GH #474)'] = function()
    local nTargets, sFirst = 0, nil
    for _, path in ipairs(WK_FRAMES) do
        local _, J, bot = on_frame(path)
        if J.GetProperTarget(bot) ~= nil then
            nTargets = nTargets + 1
            sFirst = sFirst or path
        end
    end
    assert(nTargets == 0,
        ('J.GetProperTarget answered on %d frame(s), first %s -- the second '
        .. 'blocker is gone and branch 1 is drivable now.  Same disposition as '
        .. 'the line above: rewrite, do not relax.'):format(nTargets, tostring(sFirst)))
end

tests['section 5: X.ConsiderW therefore bids 0 on all 13 frames, gate or no gate'] = function()
    for _, path in ipairs(WK_FRAMES) do
        local X = on_frame(path)
        X.SkillsComplement()  -- the only writer of the file-level nLV/nMP/nHP
        assert(X.ConsiderW() == 0, 'shipped X.ConsiderW bids on ' .. path)
        local XA = select(1, on_frame(path, { armed = true }))
        XA.SkillsComplement()
        assert(XA.ConsiderW() == 0,
            'ARMED X.ConsiderW bids on ' .. path .. '.  If this is real the branch '
            .. 'is reachable after all and section 5 above is wrong; check that '
            .. 'first, because it would make this whole file under-claim.')
    end
end

-- ---------------------------------------------------------------- section 6 --
-- Source ratchets.  Comments are stripped first, for the reason the CM round
-- found the hard way: this change writes its own argument into the hero file's
-- header, so a raw-text scan would read the documentation back as code.

local function live_source()
    local out = {}
    for line in read_file(SRC):gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

tests['section 6: X.ConsiderW calls the helper and no longer hardcodes `== 1`'] = function()
    local body = fn_body(live_source(), 'ConsiderW')
    assert(body:find('X.IsBoneGuardEnemyCountOk', 1, true),
        'X.ConsiderW no longer calls the helper -- the gate is wired to nothing')
    assert(not body:find('#nEnemysHerosInView == 1', 1, true),
        'the literal duel test is back in X.ConsiderW alongside the helper; one of '
        .. 'the two is dead and the reader cannot tell which')
    assert(body:find('BOT_ACTION_DESIRE_HIGH', 1, true),
        'branch 1 no longer returns BOT_ACTION_DESIRE_HIGH')
end

tests['section 6: the call site hands over its OWN table and the branch radius'] = function()
    local body = fn_body(live_source(), 'ConsiderW')
    assert(body:find('X.IsBoneGuardEnemyCountOk( #nEnemysHerosInView, nEnemysHerosInView, nEngageRange )', 1, true),
        'X.ConsiderW no longer passes the table it walked and the radius it '
        .. 'reaches with.  A count-only call lands on the restrictive fallback, '
        .. 'so the lever silently narrows to the shipped duel test and nothing '
        .. 'goes red -- no counter reports a Bone Guard that was not cast.')
    -- ONE place for the 650.  The next conjunct must read the same local, or the
    -- two rings drift apart and the engaged count stops meaning "in reach".
    assert(body:find('local nEngageRange = 650', 1, true),
        'the branch radius is no longer a named local set to 650')
    assert(body:find('J.IsInRange( npcTarget, bot, nEngageRange )', 1, true),
        'the proper-target reach test no longer reads nEngageRange; the count '
        .. 'ring and the reach ring can now drift apart')
    assert(not body:find('bot, 650', 1, true),
        'a raw 650 is back in X.ConsiderW alongside the local; one of the two is '
        .. 'dead and the reader cannot tell which')
end

tests['section 6: the engaged-count predicate is CALLED, not merely passed'] = function()
    -- The orphan trap of 2026-09-09: a new named predicate handed around as a
    -- function value is invisible to the closure and to
    -- tests/test_hero_export_reachability.py, which counted exactly that as the
    -- 35th orphan against a ceiling of 34.  Fix the code, not the ceiling.
    local src = live_source()
    local body = fn_body(src, 'IsBoneGuardEnemyCountOk')
    assert(body:find('X.wk_CountBoneGuardEngaged(', 1, true),
        'the gate no longer calls X.wk_CountBoneGuardEngaged -- the engaged-ring '
        .. 'premise is back out of the `if` and the leg is priced on 1600 again')
    assert(src:find('function X.wk_CountBoneGuardEngaged(', 1, true),
        'X.wk_CountBoneGuardEngaged is gone from the live source')
end

tests['section 6: the armed leg keeps the shipped duel as a literal disjunct'] = function()
    -- This is what makes DIRECTION BY CONSTRUCTION survive the narrowing.  If
    -- `nEnemies == 1` stops being a disjunct of the armed leg, the lever can
    -- REMOVE a release, and a removal is unobservable in a wave read.
    local body = fn_body(live_source(), 'IsBoneGuardEnemyCountOk')
    local sArmed = body:match('then%s*(.-)%s*end') or ''
    assert(sArmed:find('nEnemies == 1', 1, true),
        'the armed leg no longer accepts the shipped duel outright, so it is no '
        .. 'longer a superset of shipped and a negative wave read stops being '
        .. 'attributable to "more releases were bad": ' .. sArmed)
    assert(sArmed:find('>= 2', 1, true),
        'the engaged threshold is no longer 2; the leg no longer encodes the '
        .. '"joins a 3v3" premise it is justified by: ' .. sArmed)
end

tests['section 6: the gate is turbo-only and names exactly this id'] = function()
    local body = fn_body(live_source(), 'IsBoneGuardEnemyCountOk')
    assert(body:find("J.IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        'the helper does not gate on ' .. CAND)
    assert(body:find('J.IsModeTurbo()', 1, true),
        'the helper is not turbo-only')
    -- The `pullcad` trap: a gate written as a conjunction of two candidate ids
    -- freezes FALSE the day either is promoted.  This one must stay standalone.
    local _, nIds = body:gsub('IsSoakCandidate', '')
    assert(nIds == 1,
        'the helper names ' .. nIds .. ' soak ids; keep it standalone so promoting '
        .. 'another id cannot freeze it false (the pullcad trap)')
end

return tests
