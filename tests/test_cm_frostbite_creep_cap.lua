-- [hero] `cmcreepcap` -- the creep-health ceiling in X.ConsiderW's farm block is
-- Frostbite's RANK-4 creep damage, spent at every rank.  Written 2026-09-05 under
-- OWNER_PRIORITIES P4.4 (bots/ 主体配额).
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_crystal_maiden.lua X.ConsiderW's "无英雄目标时冰冻小兵打钱"
-- block admits a creep twice, each time with a bare literal:
--
--     if ( nEnemysStrongestCreepsHealth2 > 460 or ... )
--         and nEnemysStrongestCreepsHealth2 <= 1200        <-- this term
--     ...
--     if ( nEnemysStrongestCreepsHealth1 > 410 or ... )
--         and nEnemysStrongestCreepsHealth1 <= 1200        <-- and this one
--
-- Frostbite's own KV (tests/mock/special_value_shapes.lua) says what a creep
-- actually takes:
--
--     damage_per_second 100  x  creep_multiplier 4  x  duration 1.5/2/2.5/3
--         =  600 / 800 / 1000 / 1200
--
-- so `1200` is EXACTLY the rank-4 figure and nothing else.  The literal is the
-- RIGHT QUANTITY FROZEN AT THE TOP OF ITS OWN LADDER -- the same shape as Zeus's
-- static-field constant (GH #173) and Axe's `150 + 100*lv` (GH #115 §5) -- which
-- is why this is filed as a rank-independence defect and not as "the number is
-- wrong".  Section 1 pins that identity so the argument goes RED rather than
-- stale if a patch moves any of the three factors.
--
-- At ranks 1-3 the block therefore admits creeps this hero cannot kill by
-- 600 / 400 / 200 health, and it admits them at the TOP of the window it
-- searches: X.cm_GetStrongestUnit returns the STRONGEST creep, so the
-- over-admitted band is precisely the band the picker prefers.
--
-- WHAT THIS FILE DOES AND DOES NOT COVER -- READ BEFORE QUOTING IT
-- ----------------------------------------------------------------
--   * THE BLOCK IS NOT FIXTURE-DRIVABLE, for a reason that is the loader's and
--     not the corpus's: bot:GetNearbyCreeps answers an EMPTY table on every
--     frame, for either team, while fixture files in this same tree do carry
--     npc_dota_creep_* unit names in their text.  Section 5 asserts both halves
--     separately, so the day the loader wires creeps this file goes red and says
--     so instead of quietly staying green.  A second, independent blocker is
--     that the block wants `#nEnemysHeroesInView == 0` AND an enemy creep on the
--     same frame, and section 5b measures that intersection as empty.
--   * WHAT IS DRIVEN ON REAL FRAMES IS THE TERM THAT CHANGED.  Section 2 loads
--     all 10 Crystal-Maiden-subject fixtures, resolves the REAL Frostbite handle
--     on each, and reads the three KV values off it -- no value in section 2 is
--     invented by the test.  That is not the whole block, and this file never
--     says it is; but it is not gate plumbing either.  The two sentences are
--     kept apart on purpose: BLOCK = source-level coverage, CHANGED TERM = real-
--     frame coverage.
--   * THE CORPUS IS RANK-HEAVY, and that errs AGAINST this change.  7 of the 10
--     frames already hold rank 4, where armed and shipped are identical; the
--     biting band is levels 2-6 and this corpus (cut from 10-minute-capped
--     games, GH #108) is thin there.  So section 2's "3 of 10 frames differ" is
--     a floor on how often the band is reached in a real turbo game, not a rate.
--     Sizing is iterations/queue.json hero-33, never this scan.
--   * DIRECTION IS BY CONSTRUCTION AND IT IS A NARROWING (section 3): the armed
--     cap is <= 1200 at every rank, with equality only at rank 4, so the armed
--     block admits a strict SUBSET of the creeps the shipped block admits.
--     Arming can only REMOVE a cast, never add one.  A negative reading may
--     therefore be blamed on "she should have frozen that creep after all"; it
--     may NEVER be blamed on the lever having invented a cast.
--   * Section 2's numbers come from the loader via rf.load, never from a regex
--     over the fixture text.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local SRC = 'bots/BotLib/hero_crystal_maiden.lua'
local CM = 'npc_dota_hero_crystal_maiden'
local FROST = 'crystal_maiden_frostbite'
local CAND = 'cmcreepcap'
local SHIPPED_CAP = 1200

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit and section 2's counts move with a named cause.
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

-- A fixture that is NOT CM-subject but whose text names lane creeps.  Section 5
-- uses it to show the empty creep list belongs to the loader, not the corpus.
local CREEP_TEXT_FRAME = 'tests/fixtures/f_212636_tide_ancient.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The source of one X.<name> function, comments included.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Comments stripped, so a ratchet counting call sites cannot be satisfied by
--- prose that merely mentions the expression.
local function strip_comments(body)
    return (body:gsub('%-%-[^\n]*', ''))
end

--- Load a real frame, arm (or do not arm) `cmcreepcap`, and hand back the hero
--- module together with the frame's own handles.
---
--- `opt.armed == true` rather than a truthiness test: an absent key would make
--- this arm nothing and a helper asserted `== SHIPPED_CAP` would then pass for
--- the wrong reason.  The distinction is the test's, not the gate's.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_axe_call_immune_veto.lua does.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('crystal_maiden')
    return X, J, bot, heroes, fx
end

--- A stub ability handle serving one rank off the real KV ladder.  Used only by
--- the ladder scans in sections 3/4/7, where the point is to sweep ranks the
--- corpus does not hold; every number it serves still comes from the KV
--- snapshot, never from a literal typed here.
local function kv_steps(sKey)
    local kv = (shapes.SHAPES or shapes)['crystal_maiden'][FROST][sKey]
    assert(kv ~= nil and kv.base ~= nil, 'no KV base for ' .. sKey)
    local steps = {}
    for tok in kv.base:gmatch('%S+') do steps[#steps + 1] = assert(tonumber(tok)) end
    return steps
end

local function step_at(steps, nRank)
    if nRank == nil or nRank < 1 then return steps[1] end
    return steps[math.min(nRank, #steps)]
end

local function stub_ability(nRank, override)
    override = override or {}
    local vals = {
        damage_per_second = step_at(kv_steps('damage_per_second'), nRank),
        creep_multiplier  = step_at(kv_steps('creep_multiplier'), nRank),
        duration          = step_at(kv_steps('duration'), nRank),
    }
    for k, v in pairs(override) do vals[k] = v end
    local h = {}
    function h:GetSpecialValueFloat(sKey) return vals[sKey] or 0 end
    function h:GetSpecialValueInt(sKey)
        local v = self:GetSpecialValueFloat(sKey)
        if v >= 0 then return math.floor(v) end
        return -math.floor(-v)
    end
    return h
end

--- The armed cap the helper answers for a bare rank, with no frame involved.
local function armed_cap_at(X, nRank, override)
    return X.cm_GetFrostbiteCreepCap(stub_ability(nRank, override))
end

-- ---------------------------------------------------------------- section 1 --
-- The identity the whole argument rests on: the shipped literal IS the rank-4
-- creep figure.  If a patch moves any factor this goes red instead of stale.

tests['section 1: the three KV factors are still what the argument reads'] = function()
    local kv = (shapes.SHAPES or shapes)['crystal_maiden'][FROST]
    assert(kv ~= nil, 'no ' .. FROST .. ' block in tests/mock/special_value_shapes.lua')
    assert(kv['damage_per_second'].base == '100',
        'damage_per_second moved: ' .. tostring(kv['damage_per_second'].base))
    assert(kv['creep_multiplier'].base == '4',
        'creep_multiplier moved: ' .. tostring(kv['creep_multiplier'].base))
    assert(kv['duration'].base == '1.5 2 2.5 3',
        'duration ladder moved: ' .. tostring(kv['duration'].base))
end

tests['section 1: 1200 is the rank-4 creep figure and no other rank'] = function()
    local dps = kv_steps('damage_per_second')
    local mult = kv_steps('creep_multiplier')
    local dur = kv_steps('duration')
    local want = { 600, 800, 1000, 1200 }
    for rank = 1, 4 do
        local got = step_at(dps, rank) * step_at(mult, rank) * step_at(dur, rank)
        assert(got == want[rank], string.format(
            'rank %d creep damage is %s, expected %d -- the ladder this argument '
            .. 'reads has moved', rank, tostring(got), want[rank]))
        if rank < 4 then
            assert(got < SHIPPED_CAP, string.format(
                'rank %d creep damage %d is no longer BELOW the shipped literal '
                .. '%d; the defect this file describes is gone', rank, got, SHIPPED_CAP))
        else
            assert(got == SHIPPED_CAP, string.format(
                'rank 4 creep damage %d is no longer EQUAL to the shipped literal '
                .. '%d; re-argue before trusting the gate', got, SHIPPED_CAP))
        end
    end
end

tests['section 1: the un-armed helper answers exactly the shipped literal'] = function()
    local X = on_frame(CM_FRAMES[1])
    for rank = 0, 6 do
        assert(armed_cap_at(X, rank) == SHIPPED_CAP, string.format(
            'gate down at rank %d answered %s, not the shipped %d',
            rank, tostring(armed_cap_at(X, rank)), SHIPPED_CAP))
    end
end

-- ---------------------------------------------------------------- section 2 --
-- The changed term, measured on real frames through real handles.

tests['section 2: all 10 CM frames resolve a real Frostbite handle with live KV'] = function()
    for _, path in ipairs(CM_FRAMES) do
        local _, _, bot, _, fx = on_frame(path)
        assert(fx.self == CM, path .. ' is not a CM-subject frame; CM_FRAMES is stale')
        local h = bot:GetAbilityByName(FROST)
        assert(h ~= nil, path .. ': no ' .. FROST .. ' handle')
        assert(h:GetSpecialValueInt('damage_per_second') == 100, path .. ': dps read is not live')
        assert(h:GetSpecialValueInt('creep_multiplier') == 4, path .. ': multiplier read is not live')
        assert(h:GetSpecialValueFloat('duration') > 0, path .. ': duration read is not live')
    end
end

tests['section 2: on real frames the armed cap differs from shipped on 3 of 10'] = function()
    local byRank, nDiffer, nSame = {}, 0, 0
    for _, path in ipairs(CM_FRAMES) do
        local XA, _, bot = on_frame(path, { armed = true })
        local h = bot:GetAbilityByName(FROST)
        local rank = h:GetLevel()
        byRank[rank] = (byRank[rank] or 0) + 1
        local armed = XA.cm_GetFrostbiteCreepCap(h)
        assert(armed <= SHIPPED_CAP, string.format(
            '%s: armed cap %s exceeds the shipped %d -- the narrowing claim is broken',
            path, tostring(armed), SHIPPED_CAP))
        if armed < SHIPPED_CAP then nDiffer = nDiffer + 1 else nSame = nSame + 1 end
    end
    assert(byRank[2] == 1 and byRank[3] == 2 and byRank[4] == 7, string.format(
        'the Frostbite rank histogram over CM frames moved (rank2=%s rank3=%s '
        .. 'rank4=%s); section 2 is a corpus reading, so re-read it before '
        .. 'quoting the 3-of-10',
        tostring(byRank[2]), tostring(byRank[3]), tostring(byRank[4])))
    assert(nDiffer == 3 and nSame == 7, string.format(
        'armed differs on %d frames and matches on %d; expected 3 and 7', nDiffer, nSame))
end

tests['section 2: the named rank-2 frame reads 1200 shipped and 800 armed'] = function()
    local path = 'tests/fixtures/f_113638_cm_chain_rescue.lua'
    local XS, _, botS = on_frame(path)
    local XA, _, botA = on_frame(path, { armed = true })
    assert(botS:GetAbilityByName(FROST):GetLevel() == 2,
        path .. ' no longer holds Frostbite at rank 2')
    assert(XS.cm_GetFrostbiteCreepCap(botS:GetAbilityByName(FROST)) == 1200,
        'shipped read on the real handle is not 1200')
    assert(XA.cm_GetFrostbiteCreepCap(botA:GetAbilityByName(FROST)) == 800,
        'armed read on the real handle is not 800 -- this is the ONE number this '
        .. 'round changes, read off a real Frostbite handle')
end

-- ---------------------------------------------------------------- section 3 --
-- Direction, by construction.  A ladder scan, not a single value: a mutation
-- that flips the comparison or drops a factor reads like the intended change at
-- one rank and reverses it at another.

tests['section 3: armed <= shipped at every rank, strict below rank 4'] = function()
    local XA = on_frame(CM_FRAMES[1], { armed = true })
    -- TWO PASSES, and the order is load-bearing.  The direction bound is swept
    -- over the WHOLE ladder before any per-rank strictness is asserted: a change
    -- that widens the cap by a constant breaks strictness at a LOW rank and the
    -- bound at a HIGH one, so a single interleaved loop would abort on the
    -- weaker message and never print the direction failure at all.
    for rank = 0, 8 do
        local armed = armed_cap_at(XA, rank)
        assert(armed <= SHIPPED_CAP, string.format(
            'rank %d: armed cap %s > shipped %d -- arming would ADD casts, and '
            .. 'the whole attribution argument in the header depends on it not',
            rank, tostring(armed), SHIPPED_CAP))
    end
    for rank = 0, 8 do
        local armed = armed_cap_at(XA, rank)
        -- Rank 0 (untrained) clamps onto step 1 of the ladder, i.e. 600 -- NOT
        -- onto the literal.  It is unreachable in play (X.ConsiderW's first line
        -- is `abilityW:IsFullyCastable()`), and it is on the narrowing side
        -- anyway, so it is asserted with ranks 1-3 rather than excused.
        if rank <= 3 then
            assert(armed < SHIPPED_CAP, string.format(
                'rank %d: armed cap %s is not strictly below shipped %d -- the '
                .. 'lever has become a no-op at the rank it was written for',
                rank, tostring(armed), SHIPPED_CAP))
        else
            assert(armed == SHIPPED_CAP, string.format(
                'rank %d: armed cap %s != shipped %d; every rank >= 4 clamps onto '
                .. 'the ladder end and must agree with the literal',
                rank, tostring(armed), SHIPPED_CAP))
        end
    end
end

tests['section 3b: the armed cap is non-decreasing in rank'] = function()
    local XA = on_frame(CM_FRAMES[1], { armed = true })
    local prev = nil
    for rank = 1, 6 do
        local cap = armed_cap_at(XA, rank)
        if prev ~= nil then
            assert(cap >= prev, string.format(
                'rank %d cap %s is BELOW rank %d cap %s -- a higher rank must '
                .. 'never admit fewer creeps than a lower one',
                rank, tostring(cap), rank - 1, tostring(prev)))
        end
        prev = cap
    end
end

-- ---------------------------------------------------------------- section 4 --
-- Gate-off equivalence, on both legs of the gate.

tests['section 4: candidate not armed -> the shipped literal at every rank'] = function()
    local X = on_frame(CM_FRAMES[1])
    for rank = 0, 6 do
        assert(armed_cap_at(X, rank) == SHIPPED_CAP,
            'un-armed rank ' .. rank .. ' answered ' .. tostring(armed_cap_at(X, rank)))
    end
end

tests['section 4: armed but NOT turbo -> the shipped literal at every rank'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = true, nonTurbo = true })
    for rank = 0, 6 do
        assert(armed_cap_at(X, rank) == SHIPPED_CAP, string.format(
            'non-turbo rank %d answered %s; the turbo half of the gate is gone',
            rank, tostring(armed_cap_at(X, rank))))
    end
end

-- ---------------------------------------------------------------- section 5 --
-- The coverage boundary, asserted rather than described.  Two independent
-- blockers, one assertion each, so the day either is lifted this file goes red
-- and names it -- that is GOOD NEWS and means section 2 should be rewritten to
-- drive the block end to end.

tests['section 5: the loader serves no creeps, and the zero is the loader\'s'] = function()
    for _, path in ipairs(CM_FRAMES) do
        -- `J` is bound although this test does not read it: the instrument
        -- control in tools/agent/mutstand_cmcreepcap.sh (M8) swaps the creep
        -- probe for the hero scan, and a control that dies on an undefined
        -- global proves nothing about the probe.
        local _, J, bot = on_frame(path)
        assert(#bot:GetNearbyCreeps(1600, true) == 0, path
            .. ': GOOD NEWS -- bot:GetNearbyCreeps now serves ENEMY creeps. The '
            .. 'farm block is drivable end to end; rewrite section 2.')
        assert(#bot:GetNearbyCreeps(1600, false) == 0, path
            .. ': GOOD NEWS -- allied creeps are served now too.')
    end
    -- And the corpus is not the reason: a fixture in this same tree names lane
    -- creeps in its text, so nothing about creeps is missing from the DUMP.
    local body = read_file(CREEP_TEXT_FRAME)
    assert(body:find('npc_dota_creep_', 1, true) ~= nil,
        CREEP_TEXT_FRAME .. ' no longer names any npc_dota_creep_* unit; pick '
        .. 'another witness before claiming the empty list is the loader\'s')
end

tests['section 5b: no CM frame satisfies the block\'s own gate AND holds a creep'] = function()
    local nGateOpen, nBoth = 0, 0
    for _, path in ipairs(CM_FRAMES) do
        local _, J, bot = on_frame(path)
        local gate = bot:GetActiveMode() ~= BOT_MODE_LANING
            and bot:GetActiveMode() ~= BOT_MODE_RETREAT
            and bot:GetActiveMode() ~= BOT_MODE_ATTACK
            and #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0
            and #J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) < 3
            and bot:GetLevel() >= 5
        if gate then
            nGateOpen = nGateOpen + 1
            if #bot:GetNearbyCreeps(1400, true) > 0 then nBoth = nBoth + 1 end
        end
    end
    -- 2 of 10: three frames are alone (no visible enemy hero), and one of those
    -- three is level 4, below the block's own `nLV >= 5`.
    assert(nGateOpen == 2, 'the block\'s own gate now opens on ' .. nGateOpen
        .. ' CM frames, not 2; re-read section 5b before quoting it')
    assert(nBoth == 0, 'GOOD NEWS -- ' .. nBoth .. ' frame(s) now open the gate '
        .. 'AND hold an enemy creep. Drive the block end to end.')
end

-- ---------------------------------------------------------------- section 6 --
-- Ratchets.  Anchored on EXPRESSIONS, never on line numbers, and each one names
-- which leg of the argument it certifies.

tests['section 6: both call sites read the helper and no bare 1200 is left'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderW'))
    -- The bare literal is checked FIRST on purpose: reverting one call site
    -- fails both of these, and this is the message that names what happened.
    assert(body:find('<=%s*1200') == nil,
        'a bare `<= 1200` is back in X.ConsiderW -- one of the two creep caps has '
        .. 'been un-wired from the helper and is rank-independent again')
    local n = select(2, body:gsub('<=%s*nCreepCap', ''))
    assert(n == 2, 'X.ConsiderW has ' .. n .. ' `<= nCreepCap` call sites, expected 2')
    assert(body:find('X%.cm_GetFrostbiteCreepCap%(%s*abilityW%s*%)') ~= nil,
        'X.ConsiderW no longer binds nCreepCap from the helper on the W handle')
end

tests['section 6: the gate is still there, exactly once, and standalone'] = function()
    local src = strip_comments(read_file(SRC))
    local n = select(2, src:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", ''))
    assert(n == 1, string.format(
        "IsSoakCandidate('%s') appears %d times in %s, expected exactly 1. More "
        .. 'than one is a co-arming dependency (the pullcad trap); zero means the '
        .. 'fix became a live default and every claim in this file about a gated '
        .. 'lever is now false.', CAND, n, SRC))
    local helper = strip_comments(fn_body(read_file(SRC), 'cm_GetFrostbiteCreepCap'))
    assert(helper:find('J%.IsModeTurbo%(%)') ~= nil,
        'the turbo half of the gate is gone from the helper')
    assert(helper:find("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)") ~= nil,
        'the candidate half of the gate is gone from the helper')
end

tests['section 6: the shipped literal is the helper\'s last statement'] = function()
    local helper = strip_comments(fn_body(read_file(SRC), 'cm_GetFrostbiteCreepCap'))
    local returns = {}
    for r in helper:gmatch('return%s+([%w_%.]+)') do returns[#returns + 1] = r end
    assert(#returns == 2, 'the helper has ' .. #returns
        .. ' returns, expected 2 (the armed detour and the shipped fall-through)')
    assert(returns[#returns] == tostring(SHIPPED_CAP), string.format(
        "the helper's LAST return is `%s`, not the shipped literal %d. Gate-off "
        .. 'equivalence is structural only while the shipped expression is the '
        .. 'final statement and the armed branch is the only detour.',
        tostring(returns[#returns]), SHIPPED_CAP))
end

tests['section 6: t25 still takes the half that keeps this a NARROWING'] = function()
    local src = read_file(SRC)
    local row = src:match("%['t25'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}")
    assert(row ~= nil, "tTalentTreeList['t25'] not found in " .. SRC)
    local a, b = src:match("%['t25'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}")
    assert(a == '10' and b == '0', string.format(
        "tTalentTreeList['t25'] is now {%s, %s}. That row is the PREMISE of this "
        .. "file's direction claim: {0, 10} trains "
        .. 'special_bonus_unique_crystal_maiden_1 (+1.0s duration), the engine '
        .. 'folds it into the live duration read (GH #228), and the armed cap '
        .. 'becomes 1600 -- a WIDENING, not the narrowing sections 2 and 3 '
        .. 'certify. Re-argue the direction before trusting the gate.', a, b))
end

-- ---------------------------------------------------------------- section 7 --
-- The fall-through the shape rule buys.  A KV read that answers 0 must land on
-- the shipped literal, never on a cap of 0 -- which would not narrow the block,
-- it would CLOSE it, silently, in every armed game.

tests['section 7: a zero KV read falls through to the shipped literal'] = function()
    local XA = on_frame(CM_FRAMES[1], { armed = true })
    for _, key in ipairs({ 'damage_per_second', 'creep_multiplier', 'duration' }) do
        local cap = armed_cap_at(XA, 4, { [key] = 0 })
        assert(cap == SHIPPED_CAP, string.format(
            "with `%s` reading 0 the armed helper answered %s, not the shipped "
            .. '%d. A cap of 0 does not narrow the farm block, it closes it: '
            .. 'every creep fails `<= 0` and the whole "冰冻小兵打钱" path goes '
            .. 'silent in every armed turbo game.', key, tostring(cap), SHIPPED_CAP))
    end
end

return tests
