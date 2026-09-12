-- [hero] `cmrsolo` -- the ALLY term Crystal Maiden's Freezing Field branch 1
-- never had.
--
-- ⭐ WHY THIS ID EXISTS: it is the sibling `cmrcrowd` wrote down and deliberately
-- did not take.  tests/test_cm_r_crowd_release.lua's header says, verbatim, "not
-- 'CM should never ult alone' -- branch 1's missing ALLY term is a different
-- question with a different id", and the shipped note above
-- X.cm_IsFieldCrowdReleaseOk says the same thing as its LIMIT 4.  This is that
-- id.
--
-- THE DEFECT, in X.ConsiderR's own locals.  `nAllies` is computed on the third
-- line of the function --  `J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)`
-- -- and branch 1, the crowd/teamfight release, never reads it.  The only reader
-- is branch 2, the solo-KILL branch, and it reads it in the opposite direction
-- (`#nAllies <= 2`).  So the one path that opens a ten-second channel on a group
-- is the one path that never asks whether anybody is standing next to her while
-- it runs.
--
-- THE TWO FRAMES, from two different games, hitting the two different disjuncts
-- (§4) -- so unlike `zusboltimm` this is not one instant counted twice:
--   * f_260820_043039_cm_cask_close  t=515.5  3 heads / 0 hurt / 0 allies
--     died_after 0.2  -- fires the HEAD-COUNT disjunct
--   * f_260820_103216_cm_es_aftershock t=473.5  2 heads / 2 hurt / 0 allies
--     died_after 1    -- fires the `aoeCanHurtCount >= 2` disjunct, which
--                        `cmrcrowd` does not touch and never will
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  §5.3 measures, and asserts, that armed
-- `cmrself` already answers NONE on BOTH frames: today's corpus cannot separate
-- the two ids, and the separation argued in the shipped note is STRUCTURAL (a
-- full-health solo CM is outside cmrself's predicate and inside this one), not
-- observed.  Not a frequency either: 2 of 10 CM-subject fixtures is a DOMAIN.
--
-- ⚠️ METERS.  The two frames' head/hurt counts ride the same two meters
-- tests/test_cm_r_crowd_release.lua declares (the 835 Liquipedia AoE anchor, GH
-- #502; the mock's flat 300 movespeed).  The ALLY count rides neither -- §6.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')


local SRC  = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND = 'cmrsolo'

-- External anchor, see the header.  Same number, same provenance, as
-- tests/test_cm_r_crowd_release.lua and tests/test_replay_260819_cm_r_range.lua.
local FIELD_RADIUS = 835

-- The head-count witness (shared with cmrcrowd) and the hurt-count witness
-- (this id's own, and the reason the two are not one lever).
local PIN_HEADS = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'
local PIN_HURT  = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua'

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit.  Same list tests/test_cm_r_crowd_release.lua carries.
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

--- Whitespace squashed, so a re-indent of the branch is not a red.
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

--- Load a frame, arm/disarm, anchor the AoE radius, and hand back the hero
--- module plus everything an assertion might want.  The ONLY injection is the
--- AoE-radius anchor; nobody is moved, no cooldown is cleared, no HP is edited.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id)
        return opt.armed == true and id == (opt.cand or CAND)
    end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_cm_r_crowd_release.lua does.
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

--- Re-derive the THREE counts branch 1 forks on, from the same helpers the
--- shipped code uses.  Deliberately a RE-DERIVATION and not a copy of the
--- shipped expression's result: a census that reads the answer off the thing it
--- is auditing cannot disagree with it.
local function branch1_inputs(J, bot, abilityR)
    local nRadius = abilityR:GetAOERadius() * 0.88
    local inRange = J.GetNearbyHeroes(bot, nRadius, true, BOT_MODE_NONE)
    local hurt = 0
    for _, e in pairs(inRange) do
        if J.IsValid(e)
            and J.CanCastOnNonMagicImmune(e)
            and (J.IsDisabled(e)
                 or J.IsInRange(bot, e, nRadius * 0.82 - e:GetCurrentMovementSpeed()))
        then
            hurt = hurt + 1
        end
    end
    local allies = J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
    return #inRange, hurt, #allies, nRadius, inRange
end

--- --------------------------------------------------------------- section 1 --
--- The defect and the repair, pinned in the source.

tests['1.1: branch 1 conjoins X.cm_IsFieldSoloReleaseOk on the WHOLE branch'] = function()
    local body = squash(strip_comments(fn_body(read_file(SRC), 'ConsiderR')))
    assert(body:find('or aoeCanHurtCount >= 2 ) and X.cm_IsFieldSoloReleaseOk( #nAllies )',
        1, true) ~= nil,
        'X.ConsiderR no longer conjoins X.cm_IsFieldSoloReleaseOk to the WHOLE of '
        .. 'branch 1. Conjoining it to one disjunct instead is a DIFFERENT lever: '
        .. 'the peel argument does not distinguish the disjuncts, and the '
        .. 'es_aftershock witness fires the hurt-count one.')
end

tests['1.2: the helper reads the branch\'s own 1200u ally list, not a new ring'] = function()
    local body = squash(strip_comments(fn_body(read_file(SRC), 'ConsiderR')))
    assert(body:find('local nAllies = J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE )',
        1, true) ~= nil,
        'the 1200u ally list X.ConsiderR already computes has moved or changed '
        .. 'radius. This lever reads THAT list; if the ring moved, every reading '
        .. 'in this file is about a different ring.')
    local n = 0
    for _ in body:gmatch('J%.GetNearbyHeroes%(bot, %d+, false') do n = n + 1 end
    assert(n == 1,
        ('X.ConsiderR now builds %d ally rings; it built exactly 1 when this '
         .. 'lever was written. A second ring means the lever may be reading the '
         .. 'wrong one.'):format(n))
end

tests['1.3: the crowd lever is UNTOUCHED (this is a sibling, not a rewrite)'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('#nEnemysHeroesInRange >= 3 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount )',
        1, true) ~= nil,
        'the cmrcrowd routing vanished from X.ConsiderR. This id adds a conjunct '
        .. 'beside it; it must not replace it.')
    assert(body:find('or aoeCanHurtCount >= 2', 1, true) ~= nil,
        'the `aoeCanHurtCount >= 2` disjunct disappeared')
end

tests['1.4: the helper is defined once and wired at exactly one call site'] = function()
    local src = strip_comments(read_file(SRC))
    local nAll, nDef = 0, 0
    for _ in src:gmatch('X%.cm_IsFieldSoloReleaseOk%s*%(') do nAll = nAll + 1 end
    for _ in src:gmatch('function%s+X%.cm_IsFieldSoloReleaseOk%s*%(') do nDef = nDef + 1 end
    assert(nDef == 1, 'X.cm_IsFieldSoloReleaseOk must be defined exactly once')
    local n = nAll - nDef
    assert(n == 1, ('X.cm_IsFieldSoloReleaseOk is wired at %d call site(s) in %s; '
        .. 'expected exactly 1. Zero means the lever is dead wiring that '
        .. 'check_armed_wiring.py would still call WIRED (GH #606).'):format(n, SRC))
end

tests['1.5: the gate names its own id and nothing else (the pullcad trap)'] = function()
    local body = fn_body(read_file(SRC), 'cm_IsFieldSoloReleaseOk')
    local ids = {}
    for id in strip_comments(body):gmatch("IsSoakCandidate%(%s*'([a-z0-9_]+)'%s*%)") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1 and ids[1] == CAND,
        'X.cm_IsFieldSoloReleaseOk must name exactly one candidate id and it '
        .. 'must be ' .. CAND .. '. Conjoining `cmrcrowd` here -- the tempting '
        .. 'way to write "this rides on top of that" -- freezes this gate FALSE '
        .. 'the day cmrcrowd is promoted (AGENTS.md, the pullcad trap).')
end

--- --------------------------------------------------------------- section 2 --
--- The gate.  Gate-off is `true` byte for byte, in all three off-worlds.

local function helper_says(opt, nAllies)
    local X = on_frame(PIN_HEADS, opt)
    return X.cm_IsFieldSoloReleaseOk(nAllies)
end

tests['2.1: unarmed, the helper answers the shipped `true` at every ally count'] = function()
    for _, n in ipairs({ 0, 1, 2, 4 }) do
        assert(helper_says({ armed = false }, n) == true,
            ('gate OFF must answer the shipped `true`; at allies=%d it did not'):format(n))
    end
end

tests['2.2: outside Turbo the helper answers the shipped `true` even armed'] = function()
    for _, n in ipairs({ 0, 1, 2 }) do
        assert(helper_says({ armed = true, nonTurbo = true }, n) == true,
            ('outside Turbo the helper must answer the shipped `true`; at '
             .. 'allies=%d it did not'):format(n))
    end
end

tests['2.3: a DIFFERENT armed id does not open this gate'] = function()
    assert(helper_says({ armed = true, cand = 'cmrcrowd' }, 0) == true,
        'arming cmrcrowd opened the cmrsolo gate. The gate is reading the wrong '
        .. 'id, or reading none -- and cmrcrowd is exactly the id this lever '
        .. 'must stay separable from.')
end

tests['2.4: armed and in Turbo, the helper is the ally floor'] = function()
    assert(helper_says({ armed = true }, 0) == false,
        'armed, allies=0 must be refused -- that is the whole lever')
    assert(helper_says({ armed = true }, 1) == true,
        'armed, allies=1 must pass -- the floor is ONE ally who can peel, not two')
end

--- --------------------------------------------------------------- section 3 --
--- DIRECTION, swept rather than sampled, over the JOINT grid -- and the two
--- witnesses that keep this id and `cmrcrowd` from being one lever.
--- SUPERSET IS NOT CORRECTNESS (the liondrainbkb lesson, GH #549), so this
--- asserts the VALUE of the composed predicate on every cell.

local function shipped_pred(nHeads, nHurt) return nHeads >= 3 or nHurt >= 2 end

tests['3.1: armed is a strict SUBSET of shipped on the whole (heads, hurt, allies) grid'] = function()
    local X = on_frame(PIN_HEADS, { armed = true })
    local nStrict = 0
    for heads = 0, 5 do
        for hurt = 0, heads do
            for allies = 0, 3 do
                local ship = shipped_pred(heads, hurt)
                local arm = ship and X.cm_IsFieldSoloReleaseOk(allies)
                assert(not (arm and not ship),
                    ('heads=%d hurt=%d allies=%d: armed fires where shipped does '
                     .. 'not. This lever may only REMOVE releases (the cullthresh '
                     .. 'lesson).'):format(heads, hurt, allies))
                if ship and not arm then nStrict = nStrict + 1 end
            end
        end
    end
    assert(nStrict > 0,
        'armed and shipped agree on every cell of the grid -- the lever is a '
        .. 'no-op by construction, i.e. dead wiring that every gate test above '
        .. 'still passes (GH #606).')
end

tests['3.2: the removed cells are exactly `branch 1 fires, and allies == 0`'] = function()
    local X = on_frame(PIN_HEADS, { armed = true })
    local nRemoved, nKeptFiring = 0, 0
    for heads = 0, 5 do
        for hurt = 0, heads do
            for allies = 0, 3 do
                local ship = shipped_pred(heads, hurt)
                local arm = ship and X.cm_IsFieldSoloReleaseOk(allies)
                if ship and not arm then
                    assert(allies == 0,
                        ('heads=%d hurt=%d allies=%d was removed, but this lever '
                         .. 'only ever removes ally-less releases. A lever that '
                         .. 'removes a different set is a different lever wearing '
                         .. 'this one\'s name and its whole (c) argument.')
                        :format(heads, hurt, allies))
                    nRemoved = nRemoved + 1
                elseif ship then
                    nKeptFiring = nKeptFiring + 1
                end
            end
        end
    end
    -- 16 of the 21 (heads, hurt) pairs on this grid fire in shipped (15 from
    -- `heads >= 3`, plus the one `heads=2, hurt=2`); each is removed at
    -- allies==0 and kept at allies in {1,2,3}.
    assert(nRemoved == 16 and nKeptFiring == 48,
        ('removed=%d kept=%d; expected 16 and 48 over this grid. A change here '
         .. 'means the floor or the scope moved.'):format(nRemoved, nKeptFiring))
end

tests['3.3: NEITHER lever contains the other -- one witness cell each'] = function()
    local XSolo  = on_frame(PIN_HEADS, { armed = true })
    local XCrowd = on_frame(PIN_HEADS, { armed = true, cand = 'cmrcrowd' })

    local function crowd_pred(X, heads, hurt)
        return (heads >= 3 and X.cm_IsFieldCrowdReleaseOk(hurt)) or hurt >= 2
    end
    local function solo_pred(X, heads, hurt, allies)
        return shipped_pred(heads, hurt) and X.cm_IsFieldSoloReleaseOk(allies)
    end

    -- Witness A: removed by cmrsolo, KEPT by cmrcrowd.
    assert(shipped_pred(3, 1) == true, 'witness A must fire in shipped')
    assert(crowd_pred(XCrowd, 3, 1) == true,
        'heads=3 hurt=1 allies=0: cmrcrowd keeps this cell (its floor is ONE '
        .. 'hurtable enemy). If it no longer does, cmrcrowd\'s floor moved and '
        .. 'the two ids may have collapsed into one.')
    assert(solo_pred(XSolo, 3, 1, 0) == false,
        'heads=3 hurt=1 allies=0: cmrsolo must remove this cell')

    -- Witness B: removed by cmrcrowd, KEPT by cmrsolo.
    assert(shipped_pred(3, 0) == true, 'witness B must fire in shipped')
    assert(crowd_pred(XCrowd, 3, 0) == false,
        'heads=3 hurt=0 allies=2: cmrcrowd must remove this cell')
    assert(solo_pred(XSolo, 3, 0, 2) == true,
        'heads=3 hurt=0 allies=2: cmrsolo keeps this cell. If it no longer does, '
        .. 'this id has silently absorbed cmrcrowd and the two registrations '
        .. 'describe one lever.')
end

--- --------------------------------------------------------------- section 4 --
--- THE TWO REAL FRAMES, end to end, ZERO injection beyond the AoE-radius anchor.

tests['4.1: the HEAD-COUNT frame carries the premise, measured not asserted'] = function()
    local _, J, bot, _, fx, abilityR = on_frame(PIN_HEADS, { armed = false })
    assert(fx.self == 'npc_dota_hero_crystal_maiden', 'the subject')
    assert(fx.time == 515.5, 'decision instant')
    assert(fx.observed and fx.observed.died_after == 0.2,
        'ground truth: the subject died 0.2s after this frame')
    assert(abilityR:IsFullyCastable(), 'R is off cooldown and affordable here')
    local nHeads, nHurt, nAllies = branch1_inputs(J, bot, abilityR)
    assert(nHeads == 3 and nHurt == 0,
        ('expected 3 heads / 0 hurt, got %d/%d'):format(nHeads, nHurt))
    assert(nAllies == 0,
        ('zero allied heroes inside 1200u is THIS lever\'s premise on this '
         .. 'frame; got %d'):format(nAllies))
end

tests['4.2: the HURT-COUNT frame is a SECOND, independent witness'] = function()
    local _, J, bot, _, fx, abilityR = on_frame(PIN_HURT, { armed = false })
    assert(fx.self == 'npc_dota_hero_crystal_maiden', 'the subject')
    assert(fx.time == 473.5, 'decision instant')
    assert(fx.observed and fx.observed.died_after == 1,
        'ground truth: the subject died 1.0s after this frame. That number is '
        .. 'what makes "a 10s channel" the wrong bid here.')
    assert(bot:GetHealth() == 292 and bot:GetMaxHealth() == 1110, 'CM hp on the real frame')
    local nHeads, nHurt, nAllies = branch1_inputs(J, bot, abilityR)
    assert(nHeads == 2 and nHurt == 2,
        ('expected 2 heads / 2 hurt -- i.e. the `aoeCanHurtCount >= 2` disjunct, '
         .. 'the one cmrcrowd does not touch -- got %d/%d'):format(nHeads, nHurt))
    assert(nHeads < 3,
        'the head count must stay BELOW cmrcrowd\'s floor on this frame, or it '
        .. 'stops being an independent witness and becomes a second sighting of '
        .. 'the same funnel (the zusboltimm caveat).')
    assert(nAllies == 0, ('zero allies inside 1200u; got %d'):format(nAllies))
    local far = J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
    assert(#far == 1, 'exactly one ally inside 1600u -- phantom_assassin at 1543u')
    assert(GetUnitToUnitDistance(bot, far[1]) > 1200,
        'the nearest ally must be OUTSIDE the 1200u ring; if a harness change '
        .. 'moved him inside, this frame is no longer in the domain')
end

tests['4.3: shipped bids HIGH on BOTH frames; armed refuses BOTH -- real-frame flips'] = function()
    for _, path in ipairs({ PIN_HEADS, PIN_HURT }) do
        local XOff = on_frame(path, { armed = false })
        assert(XOff.ConsiderR() == BOT_ACTION_DESIRE_HIGH,
            path .. ': the shipped bid is BOT_ACTION_DESIRE_HIGH. If it is not, '
            .. 'an upstream guard moved and this frame no longer reaches branch 1.')
        local XOn = on_frame(path, { armed = true })
        assert(XOn.ConsiderR() == BOT_ACTION_DESIRE_NONE,
            path .. ': armed, X.ConsiderR must answer NONE. Anything else means '
            .. 'the withheld branch-1 bid is handed back by a branch below it, '
            .. 'and the lever changes nothing in a game.')
    end
end

tests['4.4: outside Turbo the armed leg is byte-for-byte the shipped bid'] = function()
    for _, path in ipairs({ PIN_HEADS, PIN_HURT }) do
        local XOff = on_frame(path, { armed = false, nonTurbo = true })
        local XOn  = on_frame(path, { armed = true,  nonTurbo = true })
        assert(XOff.ConsiderR() == XOn.ConsiderR(),
            path .. ': turbo-only was lost -- arming moved the bid in a '
            .. 'non-turbo game')
    end
end

--- --------------------------------------------------------------- section 5 --
--- THE DOMAIN over the CM-subject corpus, the SILENCE outside it, and the
--- overlap with `cmrself` that today's corpus cannot separate.

tests['5.1: exactly two CM fixtures carry the premise (a domain, not a rate)'] = function()
    -- Anti-vacuum floor: this census is over the LISTED CM-subject frames, so
    -- the thing that must not silently shrink is that list, not tests/fixtures.
    assert(#CM_FRAMES == 10,
        ('the CM-subject frame list is %d long; it was 10 when this domain was '
         .. 'taken. Growing it is fine and requires re-reading §5.1, not just '
         .. 'this number.'):format(#CM_FRAMES))
    local domain, seen = {}, 0
    for _, path in ipairs(CM_FRAMES) do
        local _, J, bot, _, _, abilityR = on_frame(path, { armed = false })
        seen = seen + 1
        local nHeads, nHurt, nAllies = branch1_inputs(J, bot, abilityR)
        if shipped_pred(nHeads, nHurt) and nAllies == 0 then
            domain[#domain + 1] = path
        end
    end
    assert(seen == #CM_FRAMES, 'every listed CM fixture was driven')
    table.sort(domain)
    local want = table.concat({ PIN_HEADS, PIN_HURT }, ' ')
    assert(table.concat(domain, ' ') == want,
        ('the domain over the CM corpus is %q; this file was written on exactly '
         .. 'two, %q. A third one is good news and needs a deliberate '
         .. 're-baseline, not a silent pass.')
        :format(table.concat(domain, ' '), want))
end

tests['5.2: on every OTHER CM frame the armed bid is byte-for-byte the shipped bid'] = function()
    local nChecked = 0
    for _, path in ipairs(CM_FRAMES) do
        if path ~= PIN_HEADS and path ~= PIN_HURT then
            local XOff = on_frame(path, { armed = false })
            local dOff = XOff.ConsiderR()
            local XOn = on_frame(path, { armed = true })
            local dOn = XOn.ConsiderR()
            assert(dOff == dOn,
                ('%s: arming moved the bid (%s -> %s) on a frame outside the '
                 .. 'domain'):format(path, tostring(dOff), tostring(dOn)))
            nChecked = nChecked + 1
        end
    end
    assert(nChecked == #CM_FRAMES - 2, 'the whole non-domain corpus was driven')
end

tests['5.3: ⛔ today\'s corpus cannot separate this id from armed `cmrself`'] = function()
    -- This is the LIMIT, asserted rather than written down, so it goes red the
    -- day a frame separates them -- which is the day the wave request
    -- (queue.json hero-66) stops being the only way to size this lever.
    for _, path in ipairs({ PIN_HEADS, PIN_HURT }) do
        local XSelf = on_frame(path, { armed = true, cand = 'cmrself' })
        assert(XSelf.ConsiderR() == BOT_ACTION_DESIRE_NONE,
            path .. ': armed cmrself no longer refuses this frame. It used to, '
            .. 'which is why the shipped note says the corpus cannot separate '
            .. 'the two ids. If that changed, rewrite LIMIT 1 rather than '
            .. 'deleting this assertion.')
        local _, _, bot = on_frame(path, { armed = false })
        assert(bot:GetHealth() / bot:GetMaxHealth() < 0.38
            and bot:WasRecentlyDamagedByAnyHero(2.0) == true,
            path .. ': the overlap above is only expected while BOTH of '
            .. 'cmrself\'s conjuncts hold on this frame; one of them stopped.')
    end
end

--- --------------------------------------------------------------- section 6 --
--- THE METERS.  The head/hurt counts ride two of them; the ALLY count rides
--- neither, and that is the whole reason the second witness is trustworthy.

tests['6.1: the ally count is anchor-free -- it survives GetAOERadius answering 0'] = function()
    for _, path in ipairs({ PIN_HEADS, PIN_HURT }) do
        local _, J, bot = on_frame(path, { armed = false, noAnchor = true })
        local r = bot:GetAbilityByName('crystal_maiden_freezing_field')
        assert(r:GetAOERadius() == 0,
            'unanchored, GetAOERadius answers the generic `^Get` 0. If the loader '
            .. 'now serves it, GH #502 decides what to do and every distance in '
            .. 'this file must be re-derived.')
        assert(#J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) == 0,
            path .. ': the ally count moved when the AoE anchor was dropped. It '
            .. 'must not -- it is a literal 1200u ring over frame positions, and '
            .. 'that independence is what makes §4.2 a second witness rather '
            .. 'than a second reading of the same meter.')
    end
    assert(FIELD_RADIUS == 835,
        'FIELD_RADIUS moved off the Liquipedia anchor that '
        .. 'tests/test_replay_260819_cm_r_range.lua established')
end

tests['6.2: the ally count is movespeed-free'] = function()
    -- The hurt count is decided by the mock's flat 300 (cmrcrowd §6.2 owns that
    -- limit).  Assert here only that THIS lever's input does not read it, so a
    -- future real movespeed cannot quietly move the readings in §4.
    local _, J, bot = on_frame(PIN_HURT, { armed = false })
    local allies = J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
    assert(#allies == 1, 'one ally inside 1600u on the hurt-count frame')
    local d = GetUnitToUnitDistance(bot, allies[1])
    assert(d > 1200 + 100,
        ('the nearest ally is %.1fu away; the margin to the 1200u ring is under '
         .. '100u, so the domain reading is now sensitive to a position fix the '
         .. 'way cmrcrowd\'s hurt count is sensitive to movespeed. Say so before '
         .. 'quoting §4.2.'):format(d))
end

return tests
