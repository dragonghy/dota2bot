-- [hero] `cmrcrowd` -- the escape term Crystal Maiden's Freezing Field
-- HEAD-COUNT disjunct never had.
--
-- THE DEFECT, in one line of shipped source (X.ConsiderR, branch 1):
--
--     if ( #nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2 )
--
-- The right-hand disjunct is a QUALITY test the same function computes six lines
-- above it: an enemy is counted into `aoeCanHurtCount` only if he is disabled, or
-- close enough that `nRadius * 0.82 - GetCurrentMovementSpeed()` still reaches
-- him -- i.e. only if he cannot walk out of a 10-second channel.  The left-hand
-- disjunct is the same list with the quality test dropped, and because `or`
-- evaluates left first it SHORT-CIRCUITS the test whenever three heads are
-- present.  So the one path in this function that opens on a crowd is the one
-- path that never asks whether the crowd can be hit.
--
-- THE FRAME (§4).  tests/fixtures/f_260820_043039_cm_cask_close.lua --
-- 20260820_043039_slot1 @ t=515.5 (8:35).  CM 267/890 hp (0.30), THREE visible enemies
-- inside the 734.8u field (witch_doctor 546u, slardar 571u, shadow_shaman 609u),
-- ZERO allies inside 1200u, none of the three disabled and all three outside
-- `734.8 * 0.82 - 300 = 302.5`.  So `aoeCanHurtCount == 0` and the head count is
-- the SOLE reason for the bid.  Shipped answers 0.75; the fixture's ground truth
-- is `died_after = 0.2`.
--
-- ⚠️ TWO METERS THIS FILE RIDES, both declared rather than assumed (§6):
--   * `GetAOERadius()` is NOT one of the seven getters tests/mock/replay_fixture
--     .lua specs, so it answers 0 offline.  Every distance number above rides the
--     835 Liquipedia ANCHOR that tests/test_replay_260819_cm_r_range.lua
--     established and GH #502 ruled must not be re-sourced from the KV's 810.
--   * `GetCurrentMovementSpeed()` is not in the dump; the mock answers a flat
--     300.  On the pin frame the verdict survives that (the quality test admits
--     nobody for any movespeed above 56.5, and hero movespeed is never that low)
--     -- §6 asserts BOTH the flat 300 and that margin, so a corpus-wide hurt
--     count taken elsewhere cannot quietly inherit this frame's robustness.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  Not "CM should never ult alone" -- branch
-- 1's missing ALLY term is a different question with a different id (`nAllies`
-- is computed at the top of X.ConsiderR and read only by branch 2).  Not a
-- frequency: 1 of 10 CM-subject fixtures carries the shape (§5), which is a
-- DOMAIN, not a rate; sizing needs a wave (iterations/queue.json hero-52).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')


local SRC  = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND = 'cmrcrowd'

-- External anchor, see the header.  Same number, same provenance, as
-- tests/test_replay_260819_cm_r_range.lua.
local FIELD_RADIUS = 835

local PIN = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit.  Same list tests/test_cm_far_creep_floor.lua carries.
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
        -- tests/test_cm_far_creep_floor.lua does.
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

--- Re-derive the two counts branch 1 forks on, from the same helpers the shipped
--- code uses.  Deliberately a RE-DERIVATION and not a copy of the shipped
--- expression's result: a census that reads the answer off the thing it is
--- auditing cannot disagree with it.
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
    return #inRange, hurt, nRadius, inRange
end

--- --------------------------------------------------------------- section 1 --
--- The defect and the repair, pinned in the source.  Shape assertions: they say
--- the routing is real and that the bare disjunct is gone.

tests['1.1: the head-count disjunct routes through X.cm_IsFieldCrowdReleaseOk'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('#nEnemysHeroesInRange >= 3 and X.cm_IsFieldCrowdReleaseOk( aoeCanHurtCount )',
        1, true) ~= nil,
        'X.ConsiderR no longer routes the head-count disjunct through '
        .. 'X.cm_IsFieldCrowdReleaseOk. Either the edit was reverted or the '
        .. 'call moved.')
end

tests['1.2: the bare head-count disjunct is gone from X.ConsiderR'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('#nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2', 1, true) == nil,
        'the ungated `#nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2` is back '
        .. 'in X.ConsiderR. A second, unrouted copy of the disjunct makes the '
        .. 'lever a no-op while every gate test below still passes.')
end

tests['1.3: the quality disjunct is UNTOUCHED (the lever narrows one branch only)'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('or aoeCanHurtCount >= 2', 1, true) ~= nil,
        'the `aoeCanHurtCount >= 2` disjunct disappeared. This lever adds a '
        .. 'conjunct to the head-count path; it must not remove the path that '
        .. 'already earns the channel on a pinned pair.')
end

tests['1.4: the helper is wired at exactly one call site'] = function()
    local src = strip_comments(read_file(SRC))
    -- The DEFINITION matches the same name, so it is subtracted by matching
    -- `function X.<name>(` separately rather than by eyeballing an off-by-one.
    local nAll, nDef = 0, 0
    for _ in src:gmatch('X%.cm_IsFieldCrowdReleaseOk%s*%(') do nAll = nAll + 1 end
    for _ in src:gmatch('function%s+X%.cm_IsFieldCrowdReleaseOk%s*%(') do nDef = nDef + 1 end
    assert(nDef == 1, 'X.cm_IsFieldCrowdReleaseOk must be defined exactly once')
    local n = nAll - nDef
    assert(n == 1, ('X.cm_IsFieldCrowdReleaseOk is wired at %d call site(s) in %s; '
        .. 'expected exactly 1. Zero means the lever is dead wiring that '
        .. 'check_armed_wiring.py would still call WIRED (GH #606).'):format(n, SRC))
end

tests['1.5: the gate names its own id and nothing else (the pullcad trap)'] = function()
    local body = fn_body(read_file(SRC), 'cm_IsFieldCrowdReleaseOk')
    local ids = {}
    for id in strip_comments(body):gmatch("IsSoakCandidate%(%s*'([a-z0-9_]+)'%s*%)") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1 and ids[1] == CAND,
        'X.cm_IsFieldCrowdReleaseOk must name exactly one candidate id and it '
        .. 'must be ' .. CAND .. '. Conjoining a sibling id freezes this gate '
        .. 'FALSE the day that sibling is promoted (AGENTS.md, the pullcad trap).')
end

--- --------------------------------------------------------------- section 2 --
--- The gate.  Gate-off is `true` byte for byte, in all three off-worlds.

local function helper_says(opt, nHurt)
    local X = on_frame(PIN, opt)
    return X.cm_IsFieldCrowdReleaseOk(nHurt)
end

tests['2.1: unarmed, the helper answers the shipped `true` at every hurt count'] = function()
    for _, n in ipairs({ 0, 1, 2, 3, 5 }) do
        assert(helper_says({ armed = false }, n) == true,
            ('gate OFF must answer the shipped `true`; at hurt=%d it did not'):format(n))
    end
end

tests['2.2: outside Turbo the helper answers the shipped `true` even armed'] = function()
    for _, n in ipairs({ 0, 1, 2 }) do
        assert(helper_says({ armed = true, nonTurbo = true }, n) == true,
            ('outside Turbo the helper must answer the shipped `true`; at hurt=%d '
             .. 'it did not'):format(n))
    end
end

tests['2.3: a DIFFERENT armed id does not open this gate'] = function()
    assert(helper_says({ armed = true, cand = 'cmrguard' }, 0) == true,
        'arming cmrguard opened the cmrcrowd gate. The gate is reading the '
        .. 'wrong id, or reading none.')
end

tests['2.4: armed and in Turbo, the helper is the hurt-count floor'] = function()
    assert(helper_says({ armed = true }, 0) == false,
        'armed, hurt=0 must be refused -- that is the whole lever')
    assert(helper_says({ armed = true }, 1) == true,
        'armed, hurt=1 must pass -- the floor is ONE enemy who cannot leave, '
        .. 'not two')
end

--- --------------------------------------------------------------- section 3 --
--- DIRECTION, swept rather than sampled.  SUPERSET IS NOT CORRECTNESS
--- (the liondrainbkb lesson, GH #549), so this sweeps the whole grid and asserts
--- the VALUE of the composed branch-1 predicate on every cell -- a mutant that
--- answers `false` for everything is also a subset.

--- The shipped and armed branch-1 predicates, reconstructed from their two
--- inputs.  Written out here rather than driven through X.ConsiderR because the
--- grid contains counts no real frame carries.
local function shipped_pred(nHeads, nHurt) return nHeads >= 3 or nHurt >= 2 end

tests['3.1: armed is a strict SUBSET of shipped on the whole (heads, hurt) grid'] = function()
    local X = on_frame(PIN, { armed = true })
    local nStrict = 0
    for heads = 0, 5 do
        for hurt = 0, heads do
            local ship = shipped_pred(heads, hurt)
            local arm = (heads >= 3 and X.cm_IsFieldCrowdReleaseOk(hurt)) or hurt >= 2
            assert(not (arm and not ship),
                ('heads=%d hurt=%d: armed fires where shipped does not. This '
                 .. 'lever may only REMOVE releases (the cullthresh lesson).')
                :format(heads, hurt))
            if ship and not arm then nStrict = nStrict + 1 end
        end
    end
    assert(nStrict > 0,
        'armed and shipped agree on every cell of the grid -- the lever is a '
        .. 'no-op by construction, i.e. dead wiring that every gate test above '
        .. 'still passes (GH #606).')
end

tests['3.2: the removed cells are exactly `3+ heads, 0 or 1 hurt`'] = function()
    local X = on_frame(PIN, { armed = true })
    local removed = {}
    for heads = 0, 5 do
        for hurt = 0, heads do
            local ship = shipped_pred(heads, hurt)
            local arm = (heads >= 3 and X.cm_IsFieldCrowdReleaseOk(hurt)) or hurt >= 2
            if ship and not arm then
                removed[#removed + 1] = heads .. ':' .. hurt
            end
        end
    end
    table.sort(removed)
    local got = table.concat(removed, ' ')
    -- The floor is ONE hurtable enemy, so `hurt == 1` still releases; the cells
    -- this lever removes are exactly the crowds nobody in them can be hit.
    local want = '3:0 4:0 5:0'
    assert(got == want,
        ('the removed set is %q, expected %q. A lever that removes a different '
         .. 'set is a different lever wearing this one\'s name and its whole (c) '
         .. 'argument.'):format(got, want))
end

--- --------------------------------------------------------------- section 4 --
--- THE REAL FRAME, end to end, ZERO injection beyond the AoE-radius anchor.

tests['4.1: the pin frame carries the premise, measured not asserted'] = function()
    local _, J, bot, _, fx, abilityR = on_frame(PIN, { armed = false })
    assert(fx.self == 'npc_dota_hero_crystal_maiden', 'the subject')
    assert(fx.time == 515.5, 'decision instant')
    assert(fx.observed and fx.observed.died_after == 0.2,
        'ground truth: the subject died 0.2s after this frame. That number is '
        .. 'what makes "a 10s channel" the wrong bid here; if it moved, re-read '
        .. 'the whole (c) argument.')
    assert(bot:GetHealth() == 267 and bot:GetMaxHealth() == 890, 'CM hp on the real frame')
    assert(abilityR:IsFullyCastable(), 'R is off cooldown and affordable on this real frame')

    local nHeads, nHurt, nRadius = branch1_inputs(J, bot, abilityR)
    assert(math.abs(nRadius - 734.8) < 0.01, 'the anchored field radius')
    assert(nHeads == 3, ('3 visible enemies inside the field, got %d'):format(nHeads))
    assert(nHurt == 0,
        ('aoeCanHurtCount must be 0 on this frame, got %d -- if it is not, the '
         .. 'head count is no longer the SOLE reason for the shipped bid and '
         .. 'this frame stops being the pin.'):format(nHurt))
    assert(#J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) == 0,
        'zero allied heroes inside 1200u -- recorded because it is the reason '
        .. 'the frame READS as a solo collapse, NOT because this lever tests it')
end

tests['4.2: shipped bids HIGH here; armed refuses -- a real-frame flip'] = function()
    local XOff = on_frame(PIN, { armed = false })
    assert(XOff.ConsiderR() == BOT_ACTION_DESIRE_HIGH,
        'the shipped bid on the pin frame is BOT_ACTION_DESIRE_HIGH. If it is '
        .. 'not, an upstream guard moved and this frame no longer reaches '
        .. 'branch 1.')

    local XOn = on_frame(PIN, { armed = true })
    assert(XOn.ConsiderR() == BOT_ACTION_DESIRE_NONE,
        'armed, X.ConsiderR must answer NONE on the pin frame. Anything else '
        .. 'means the withheld branch-1 bid is being handed back by a branch '
        .. 'below it, and the lever changes nothing in a game.')
end

tests['4.3: outside Turbo the armed leg is byte-for-byte the shipped bid'] = function()
    local XOff = on_frame(PIN, { armed = false, nonTurbo = true })
    local XOn = on_frame(PIN, { armed = true, nonTurbo = true })
    assert(XOff.ConsiderR() == XOn.ConsiderR(),
        'turbo-only was lost: arming moved the bid in a non-turbo game')
end

--- --------------------------------------------------------------- section 5 --
--- THE DOMAIN over the CM-subject corpus, and the SILENCE outside it.

tests['5.1: exactly one CM fixture carries the premise (a domain, not a rate)'] = function()
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
        local nHeads, nHurt = branch1_inputs(J, bot, abilityR)
        if nHeads >= 3 and nHurt < 1 then domain[#domain + 1] = path end
    end
    assert(seen == #CM_FRAMES, 'every listed CM fixture was driven')
    assert(#domain == 1 and domain[1] == PIN,
        ('the domain over the CM corpus is %d frame(s) (%s); this file was '
         .. 'written on exactly one, %s. A second one is good news and needs a '
         .. 'deliberate re-baseline, not a silent pass.')
        :format(#domain, table.concat(domain, ', '), PIN))
end

tests['5.2: on every OTHER CM frame the armed bid is byte-for-byte the shipped bid'] = function()
    local nChecked = 0
    for _, path in ipairs(CM_FRAMES) do
        if path ~= PIN then
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
    assert(nChecked == #CM_FRAMES - 1, 'the whole non-domain corpus was driven')
end

--- --------------------------------------------------------------- section 6 --
--- THE TWO METERS, pinned so a later harness repair cannot silently rewrite the
--- readings above.

tests['6.1: GetAOERadius is still NOT served by the loader (the anchor is load-bearing)'] = function()
    local _, _, bot = on_frame(PIN, { armed = false, noAnchor = true })
    local r = bot:GetAbilityByName('crystal_maiden_freezing_field')
    assert(rawget(r, '__spec').GetAOERadius == nil,
        'the loader now serves GetAOERadius. WHERE FROM decides what to do: '
        .. 'served off the KV, GH #502 forbids it (810 is a choice, not a read); '
        .. 'served from anywhere else, drop FIELD_RADIUS and re-derive every '
        .. 'distance in this file.')
    assert(r:GetAOERadius() == 0,
        'unanchored, GetAOERadius answers the generic `^Get` 0 -- which is why '
        .. 'no test could reach branch 1 of X.ConsiderR before the anchor')
    assert(FIELD_RADIUS == 835,
        'FIELD_RADIUS moved off the Liquipedia anchor that '
        .. 'tests/test_replay_260819_cm_r_range.lua established')
end

tests['6.2: GetCurrentMovementSpeed is a flat mock 300, and the pin survives it'] = function()
    local _, J, bot, _, _, abilityR = on_frame(PIN, { armed = false })
    local _, _, nRadius, inRange = branch1_inputs(J, bot, abilityR)
    assert(#inRange == 3, 'three enemies in the field')
    local nNearest = math.huge
    for _, e in pairs(inRange) do
        assert(e:GetCurrentMovementSpeed() == 300,
            'the mock no longer answers a flat 300 for GetCurrentMovementSpeed. '
            .. 'If the dump started carrying movespeed, this frame\'s hurt count '
            .. 'is now a real reading and the LIMIT above must be rewritten, not '
            .. 'kept.')
        local d = GetUnitToUnitDistance(bot, e)
        if d < nNearest then nNearest = d end
    end
    -- The quality test is `dist <= nRadius*0.82 - ms`.  Solve for the movespeed
    -- at which the NEAREST enemy would start counting: ms = nRadius*0.82 - dist.
    local nFlipMs = nRadius * 0.82 - nNearest
    assert(nFlipMs < 60,
        ('the pin frame\'s hurt count would flip to 1 at movespeed %.1f. Above '
         .. '~60 the reading is decided by the mock rather than by the frame, '
         .. 'and §4.1 must stop being quoted as movespeed-robust.'):format(nFlipMs))
end

return tests
