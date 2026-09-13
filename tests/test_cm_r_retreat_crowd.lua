-- [hero] `cmrflee` -- Crystal Maiden's Freezing Field RETREAT branch scales an
-- HP fraction by an unbounded head count, so the conjunct is an off-switch, not
-- a gradient.
--
-- ⭐ THE DEFECT IS ARITHMETIC, AND EVERY STEP OF IT IS IN THE FILE.  `nHP` is
-- assigned at hero_crystal_maiden.lua:325 as `bot:GetHealth()/bot:GetMaxHealth()`
-- -- a fraction in [0, 1].  X.ConsiderR branch 3 then asks
-- `nHP > 0.38 * #nEnemysHeroesFurther`, where `nEnemysHeroesFurther` is the
-- 1300u enemy ring.  The reachable rungs are:
--
--     crowd 0   -> UNREACHABLE  (branch 3 needs nEnemysHeroesNearby[1]; the 500u
--                                list is a SUBSET of the 1300u list)
--     crowd 1   -> nHP > 0.38   NO-OP: byte for byte the guard eleven lines up
--     crowd 2   -> nHP > 0.76   the only rung that does work
--     crowd >=3 -> nHP > 1.14   UNSATISFIABLE
--
-- Three chasers with Q AND W on cooldown is the state branch 3 exists for, and
-- it is exactly the state this conjunct deletes.  Nobody wrote "refuse at
-- three": it falls out of multiplying a bounded quantity by an unbounded one.
--
-- THE REPAIR is the monotone closure of the shipped rule -- clamp the multiplier
-- at the rule's OWN last satisfiable rung.  §2.3 RE-DERIVES that cap from the
-- ladder instead of asserting the 2, and §3 shows the added states are exactly
-- the ones the shipped rule already commits to one rung lower.
--
-- ⛔ THE DOMAIN THIS LEVER ADDS IS EMPTY ON TODAY'S CORPUS, and §5 prints the
-- whole table rather than claiming it.  ⇒ NOBODY MAY REPORT A NUMBER OF
-- RELEASES THIS LEVER ADDS.  Sizing needs a wave: queue.json hero-80.
--
-- ⚠️ METERS: none.  `nHP` and the 1300u ring are read straight off the frame.
-- Unlike branch 1's head/hurt counts this conjunct rides neither the 835 AoE
-- anchor (GH #502) nor the mock's flat movespeed -- §5.4 asserts that
-- independence rather than assuming it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC  = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND = 'cmrflee'
local HELPER = 'cm_IsFieldRetreatCrowdOk'

-- The step the shipped branch types, and the step this file reasons about.  It
-- lives at the CALL SITE in the source; §1.2 pins it there.
local STEP = 0.38

-- Anchor for the AoE radius, same number and same provenance as
-- tests/test_cm_r_solo_release.lua.  Branch 3 does not read it; §5.4 uses that.
local FIELD_RADIUS = 835

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit.  Same list tests/test_cm_r_solo_release.lua carries.
local CM_FRAMES = {
    'tests/fixtures/f_113638_cm_chain_rescue.lua',
    'tests/fixtures/f_260819_003005_cm_selfpreserve.lua',
    'tests/fixtures/f_260819_004858_cm_centaur_far.lua',
    'tests/fixtures/f_260820_042009_cm_cask_far.lua',
    'tests/fixtures/f_260820_043039_cm_cask_close.lua',
    'tests/fixtures/f_260820_102645_cm_es_reach.lua',
    'tests/fixtures/f_260820_102645_cm_laning_release.lua',
    'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
    'tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua',
    'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua',
}

-- The frame with the biggest crowd in the corpus, named because §5.2 leans on
-- it: it is the ONLY frame that clears the crowd premise and it fails both of
-- the other two.
local NEAR_MISS = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely mentions the expression.
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

local function squash(s)
    return (s:gsub('%s+', ' '))
end

--- The source of one X.<name> function, comments included.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load a frame, arm/disarm, anchor the AoE radius, hand back the hero module.
--- The ONLY injection is the AoE-radius anchor; nobody is moved, no cooldown is
--- cleared, no HP is edited.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id)
        return opt.armed == true and id == (opt.cand or CAND)
    end
    if opt.nonTurbo then
        GetGameMode = function() return 1 end
    end
    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[6] == 'crystal_maiden_freezing_field',
        path .. ': the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    if not opt.noAnchor then
        rawget(abilityR, '__spec').GetAOERadius = FIELD_RADIUS
    end
    local X = rf.load_hero('crystal_maiden')
    return X, J, bot, heroes, fx, abilityR
end

--- Branch 3's three premises, RE-DERIVED from the same helpers the shipped code
--- uses rather than read off the expression being audited.
local function branch3_inputs(J, bot)
    local nearby  = J.GetNearbyHeroes(bot, 500,  true, BOT_MODE_NONE)
    local further = J.GetNearbyHeroes(bot, 1300, true, BOT_MODE_NONE)
    local hp = bot:GetHealth() / bot:GetMaxHealth()
    return hp, #nearby, #further
end

--- --------------------------------------------------------------- section 1 --
--- The defect and the repair, pinned in the source.

tests['1.1: branch 3 routes its crowd conjunct through the helper'] = function()
    local body = squash(strip_comments(fn_body(read_file(SRC), 'ConsiderR')))
    assert(body:find('and X.' .. HELPER .. '( nHP, 0.38, #nEnemysHeroesFurther )',
        1, true) ~= nil,
        'X.ConsiderR branch 3 no longer routes its crowd conjunct through X.'
        .. HELPER .. '. Either the wiring was removed (the lever is dead and '
        .. 'check_armed_wiring.py would still call it WIRED, GH #606) or the '
        .. 'arguments moved, in which case every rung in this file is about a '
        .. 'different expression.')
end

tests['1.2: the step stays at the call site and the outer guard still reads 0.38'] = function()
    local body = squash(strip_comments(fn_body(read_file(SRC), 'ConsiderR')))
    assert(body:find('if J.IsRetreating( bot ) and nHP > 0.38 then', 1, true) ~= nil,
        'the guard eleven lines above branch 3\'s crowd conjunct has moved off '
        .. '0.38. That guard is what makes rung 1 a NO-OP; if it changed, §2.2 '
        .. 'is about a rung that no longer exists.')
    local helper = fn_body(read_file(SRC), HELPER)
    assert(strip_comments(helper):find('0.38', 1, true) == nil,
        'X.' .. HELPER .. ' now types 0.38 itself. It must take the step as an '
        .. 'argument: two copies of the number is exactly how the helper drifts '
        .. 'away from the branch it is supposed to reduce to.')
end

tests['1.3: the helper binds and returns the shipped answer FIRST'] = function()
    local body = squash(strip_comments(fn_body(read_file(SRC), HELPER)))
    local iShipped = body:find('local bShipped = nHp > nStep * nCrowd', 1, true)
    local iGate    = body:find('IsSoakCandidate', 1, true)
    assert(iShipped ~= nil,
        'the shipped expression is no longer bound verbatim in X.' .. HELPER)
    assert(iGate ~= nil and iShipped < iGate,
        'the gate now runs before the shipped predicate is bound and returned. '
        .. 'The direction guarantee (armed can only move false -> true) is a '
        .. 'property of that ORDER, not of the prose above the helper.')
end

tests['1.4: the helper is defined once, wired once, and names only its own id'] = function()
    local src = strip_comments(read_file(SRC))
    local nAll, nDef = 0, 0
    for _ in src:gmatch('X%.' .. HELPER .. '%s*%(') do nAll = nAll + 1 end
    for _ in src:gmatch('function%s+X%.' .. HELPER .. '%s*%(') do nDef = nDef + 1 end
    assert(nDef == 1, 'X.' .. HELPER .. ' must be defined exactly once')
    assert(nAll - nDef == 1,
        ('X.%s is wired at %d call site(s); expected exactly 1')
        :format(HELPER, nAll - nDef))

    local ids = {}
    for id in strip_comments(fn_body(read_file(SRC), HELPER))
        :gmatch("IsSoakCandidate%(%s*'([a-z0-9_]+)'%s*%)") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1 and ids[1] == CAND,
        'X.' .. HELPER .. ' must name exactly one candidate id and it must be '
        .. CAND .. ' -- naming a second id freezes this gate FALSE the day that '
        .. 'id is promoted (AGENTS.md, the pullcad trap); saw '
        .. table.concat(ids, ','))
end

tests['1.5: the siblings on this branch are untouched'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    for _, needle in ipairs({
        'not abilityQ:IsFullyCastable()',
        'not abilityW:IsFullyCastable()',
        'J.GetNearbyHeroes(bot, 500, true, BOT_MODE_NONE )',
        'J.GetNearbyHeroes(bot, 1300, true, BOT_MODE_NONE )',
    }) do
        assert(squash(body):find(squash(needle), 1, true) ~= nil,
            ('branch 3 lost %q. This lever replaces ONE conjunct; it must not '
             .. 'move the premises the rung ladder is derived from.'):format(needle))
    end
end

--- --------------------------------------------------------------- section 2 --
--- THE RUNG LADDER, derived rather than asserted.

tests['2.1: nHP is a fraction -- the source says so, on every real frame'] = function()
    local src = read_file(SRC)
    assert(src:find('nHP = bot:GetHealth()/bot:GetMaxHealth()', 1, true) ~= nil,
        'hero_crystal_maiden.lua no longer defines nHP as a health FRACTION. '
        .. 'Every "unsatisfiable" claim in this file rests on nHP <= 1.')
    for _, path in ipairs(CM_FRAMES) do
        local _, J, bot = on_frame(path, { armed = false })
        local hp = select(1, branch3_inputs(J, bot))
        assert(hp > 0 and hp <= 1,
            ('%s: hp reads %.3f, outside (0, 1]'):format(path, hp))
    end
end

tests['2.2: rung 1 is a NO-OP -- it is the outer guard restated'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = false })
    for i = 0, 100 do
        local hp = i / 100
        assert(X[HELPER](hp, STEP, 1) == (hp > STEP),
            ('at crowd 1 and hp %.2f the conjunct disagreed with the outer '
             .. 'guard `nHP > 0.38`; rung 1 is supposed to be that guard '
             .. 'restated'):format(hp))
    end
end

tests['2.3: the cap is RE-DERIVED from the ladder, not asserted'] = function()
    -- The last rung a health fraction can ever satisfy: the largest integer n
    -- with STEP * n < 1.  Computed here; the source constant must equal it.
    local nLast = 0
    for n = 1, 64 do
        if STEP * n < 1 then nLast = n end
    end
    assert(nLast == 2,
        ('the ladder derived from step %.2f has its last satisfiable rung at '
         .. '%d, not 2. Re-read the whole file before moving the constant -- '
         .. 'the step changed, so every rung changed.'):format(STEP, nLast))
    local X = on_frame(CM_FRAMES[1], { armed = false })
    assert(X.nRRetreatCrowdCap == nLast,
        ('X.nRRetreatCrowdCap is %s; the ladder says the last satisfiable rung '
         .. 'is %d. The cap is not a tuning knob -- it is read OFF the shipped '
         .. 'rule.'):format(tostring(X.nRRetreatCrowdCap), nLast))
end

tests['2.4: from rung 3 up the SHIPPED conjunct is unsatisfiable'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = false })
    for nCrowd = 3, 8 do
        for i = 0, 100 do
            local hp = i / 100
            assert(X[HELPER](hp, STEP, nCrowd) == false,
                ('gate OFF, crowd %d, hp %.2f: the shipped conjunct answered '
                 .. 'true. It cannot -- %.2f * %d = %.2f > 1 >= nHP.')
                :format(nCrowd, hp, STEP, nCrowd, STEP * nCrowd))
        end
    end
end

--- --------------------------------------------------------------- section 3 --
--- DIRECTION BY CONSTRUCTION, and exactly which states the armed leg adds.

tests['3.1: armed is a strict SUPERSET of shipped over the whole grid'] = function()
    local XOff = on_frame(CM_FRAMES[1], { armed = false })
    local XOn  = on_frame(CM_FRAMES[1], { armed = true })
    local nAdded = 0
    for nCrowd = 0, 8 do
        for i = 0, 100 do
            local hp = i / 100
            local bOff = XOff[HELPER](hp, STEP, nCrowd)
            local bOn  = XOn[HELPER](hp, STEP, nCrowd)
            if bOff then
                assert(bOn, ('crowd %d hp %.2f: armed REFUSED a state the '
                    .. 'shipped rule accepts. Arming must only ever move this '
                    .. 'answer false -> true.'):format(nCrowd, hp))
            end
            if bOn and not bOff then nAdded = nAdded + 1 end
        end
    end
    assert(nAdded > 0, 'the armed leg added nothing anywhere on the grid -- the '
        .. 'gate is not reaching the clamp')
end

tests['3.2: the added states are exactly {crowd >= 3, hp above the rung-2 bar}'] = function()
    local XOff = on_frame(CM_FRAMES[1], { armed = false })
    local XOn  = on_frame(CM_FRAMES[1], { armed = true })
    local cap = XOn.nRRetreatCrowdCap
    for nCrowd = 0, 8 do
        for i = 0, 100 do
            local hp = i / 100
            local bAdded = XOn[HELPER](hp, STEP, nCrowd)
                and not XOff[HELPER](hp, STEP, nCrowd)
            local bWant = (nCrowd > cap) and (hp > STEP * cap)
            assert(bAdded == bWant,
                ('crowd %d hp %.2f: added=%s, but the monotone closure of the '
                 .. 'shipped rule says %s. Any other added state is a '
                 .. 'willingness this branch does not already display one rung '
                 .. 'lower.'):format(nCrowd, hp, tostring(bAdded), tostring(bWant)))
        end
    end
end

tests['3.3: every added state is one the shipped rule accepts at the cap'] = function()
    -- The whole justification for the clamp in one assertion: for each state the
    -- armed leg invents, the SHIPPED rule already says yes on the same health at
    -- crowd == cap.
    local XOff = on_frame(CM_FRAMES[1], { armed = false })
    local XOn  = on_frame(CM_FRAMES[1], { armed = true })
    local cap = XOn.nRRetreatCrowdCap
    local nSeen = 0
    for nCrowd = 0, 8 do
        for i = 0, 100 do
            local hp = i / 100
            if XOn[HELPER](hp, STEP, nCrowd)
                and not XOff[HELPER](hp, STEP, nCrowd) then
                assert(XOff[HELPER](hp, STEP, cap),
                    ('crowd %d hp %.2f is added, yet the shipped rule refuses '
                     .. 'that same health at crowd %d'):format(nCrowd, hp, cap))
                nSeen = nSeen + 1
            end
        end
    end
    assert(nSeen > 0, 'no added state was inspected')
end

--- --------------------------------------------------------------- section 4 --
--- TURBO-ONLY, and gate-off byte-for-byte.

tests['4.1: outside Turbo the armed leg is the shipped expression'] = function()
    local XOn = on_frame(CM_FRAMES[1], { armed = true, nonTurbo = true })
    for nCrowd = 0, 8 do
        for i = 0, 100 do
            local hp = i / 100
            assert(XOn[HELPER](hp, STEP, nCrowd) == (hp > STEP * nCrowd),
                ('non-turbo, crowd %d hp %.2f: turbo-only was lost')
                :format(nCrowd, hp))
        end
    end
end

tests['4.2: a DIFFERENT armed id does not open this gate'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = true, cand = 'cmrsolo' })
    assert(X[HELPER](0.9, STEP, 4) == false,
        'arming cmrsolo opened cmrflee\'s clamp -- the gate is not reading its '
        .. 'own id')
end

--- --------------------------------------------------------------- section 5 --
--- THE REAL FRAMES: the three premises, the EMPTY domain, and why.

tests['5.1: the 500u list is a subset of the 1300u list on every real frame'] = function()
    -- This is what makes rung 0 unreachable, and it is asserted on frames rather
    -- than argued: the two lists share an anchor and a filter, so the smaller
    -- radius cannot admit anybody the larger one rejects.
    assert(#CM_FRAMES == 10,
        ('the CM-subject frame list is %d long; it was 10 when this domain was '
         .. 'taken. Growing it is fine and requires re-reading §5, not just '
         .. 'this number.'):format(#CM_FRAMES))
    for _, path in ipairs(CM_FRAMES) do
        local _, J, bot = on_frame(path, { armed = false })
        local _, n500, n1300 = branch3_inputs(J, bot)
        assert(n500 <= n1300,
            ('%s: 500u ring holds %d and the 1300u ring holds %d. The subset '
             .. 'relation is what makes crowd 0 unreachable inside branch 3.')
            :format(path, n500, n1300))
    end
end

tests['5.2: ⛔ the domain this lever ADDS is empty on today\'s corpus'] = function()
    local rows, domain = {}, {}
    for _, path in ipairs(CM_FRAMES) do
        local _, J, bot = on_frame(path, { armed = false })
        local hp, n500, n1300 = branch3_inputs(J, bot)
        rows[#rows + 1] = ('%s hp=%.3f n500=%d n1300=%d')
            :format((path:gsub('tests/fixtures/', '')), hp, n500, n1300)
        if n500 >= 1 and n1300 > 2 and hp > STEP then
            domain[#domain + 1] = path
        end
    end
    assert(#domain == 0,
        ('a frame now carries all three premises (>=1 inside 500u, >=3 inside '
         .. '1300u, hp > %.2f): %s. That is GOOD NEWS and needs a deliberate '
         .. 're-baseline of this section and of the shipped header\'s "NOBODY '
         .. 'MAY REPORT A NUMBER" paragraph -- not a lowered bar.\nreadings:\n%s')
        :format(STEP, table.concat(domain, ' '), table.concat(rows, '\n')))
end

tests['5.3: the near miss is named, and it misses on the other two premises'] = function()
    local _, J, bot = on_frame(NEAR_MISS, { armed = false })
    local hp, n500, n1300 = branch3_inputs(J, bot)
    assert(n1300 > 2,
        NEAR_MISS .. ' no longer carries the crowd premise; it was the only '
        .. 'frame in the corpus that did, so §5.2 has a different shape now')
    assert(n500 == 0 and hp < STEP,
        ('%s: n500=%d hp=%.3f. This frame is quoted in the shipped header as '
         .. 'failing BOTH other premises; if one of them now holds, the header '
         .. 'paragraph is wrong and must be rewritten before anyone cites it.')
        :format(NEAR_MISS, n500, hp))
end

tests['5.4: this conjunct rides neither the AoE anchor nor movespeed'] = function()
    for _, path in ipairs({ NEAR_MISS, CM_FRAMES[3] }) do
        local _, J1, bot1 = on_frame(path, { armed = false })
        local hp1, a1, b1 = branch3_inputs(J1, bot1)
        local _, J2, bot2 = on_frame(path, { armed = false, noAnchor = true })
        local hp2, a2, b2 = branch3_inputs(J2, bot2)
        assert(hp1 == hp2 and a1 == a2 and b1 == b2,
            path .. ': branch 3\'s inputs moved when the 835 AoE anchor was '
            .. 'dropped. They must not -- both rings are literals over frame '
            .. 'positions, and that independence is the whole reason §5.2 is '
            .. 'trustworthy while the end-to-end bid is not drivable.')
    end
end

--- --------------------------------------------------------------- section 6 --
--- END TO END: silence, and the reason it is silence.

tests['6.1: on every CM frame the armed bid equals the shipped bid'] = function()
    local nChecked = 0
    for _, path in ipairs(CM_FRAMES) do
        local XOff = on_frame(path, { armed = false })
        local dOff = XOff.ConsiderR()
        local XOn = on_frame(path, { armed = true })
        local dOn = XOn.ConsiderR()
        assert(dOff == dOn,
            ('%s: arming moved the bid (%s -> %s). §5.2 says the added domain '
             .. 'is EMPTY on this corpus, so a moved bid means either a frame '
             .. 'entered the domain or the lever is reaching a branch it does '
             .. 'not own.'):format(path, tostring(dOff), tostring(dOn)))
        nChecked = nChecked + 1
    end
    assert(nChecked == #CM_FRAMES, 'the whole CM corpus was driven')
end

return tests
