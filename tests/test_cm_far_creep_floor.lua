-- [hero] `cmfarcreep` -- X.ConsiderW's "先远" half applies its mana-backed
-- relaxed floor to the NEAR creep's health while every other term in the same
-- `if` (and the cast itself) is about the FAR creep.  Written 2026-09-07 under
-- OWNER_PRIORITIES P4.4 (bots/ 主体配额).
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_crystal_maiden.lua X.ConsiderW, block "无英雄目标时冰冻小兵打钱":
--
--     nEnemysCreeps1 = bot:GetNearbyCreeps( nCastRange + 100, true )   -- NEAR
--     nEnemysCreeps2 = bot:GetNearbyCreeps( 1400, true )               -- WIDE
--     ...Creeps1/...Health1 = X.cm_GetStrongestUnit( nEnemysCreeps1 )
--     ...Creeps2/...Health2 = X.cm_GetStrongestUnit( nEnemysCreeps2 )
--
--     -- 先远:  casts on Creeps2
--     if ( ...Health2 > 460 or ( ...Health1 > 390 and nMP > 0.45 ) )   <-- Health1
--         and ...Health2 <= nCreepCap
--     -- 再近:  casts on Creeps1
--     if ( ...Health1 > 410 or ( ...Health1 > 360 and nMP > 0.45 ) )
--         and ...Health1 <= nCreepCap
--
-- The near half is internally consistent -- three terms, all Health1, cast on
-- Creeps1.  The far half is not: its 460 floor and its cap read Health2, its
-- relaxed floor reads Health1.  That single term is the only place in either
-- half where a floor is applied to a creep other than the one being cast on.
--
-- WHY IT BITES WHERE THE BRANCH MATTERS.  X.cm_GetStrongestUnit initialises its
-- running maximum to `GetBot():GetAttackDamage()` and returns it untouched when
-- nothing in the list qualifies -- so with an empty NEAR list Health1 is Crystal
-- Maiden's attack damage, not 0 and not Health2.  Her ranged base is 39-45 and
-- neither buy list carries a damage item, so that fallback sits far below 390 at
-- every level this block can open at (`nLV >= 5`).  ⇒ exactly when the far creep
-- is the ONLY candidate -- the state the "先远" half runs first for -- the
-- relaxed floor is false and the branch can fire only above 460.
--
-- WHAT THIS FILE COVERS AND WHAT IT DOES NOT -- READ BEFORE QUOTING IT
-- --------------------------------------------------------------------
--   * THE CHANGED TERM CANNOT BE DRIVEN WITH A REAL CREEP.  No fixture carries
--     a creep UNIT and bot:GetNearbyCreeps answers an empty table on every
--     frame; both are ONE-WAY TRIPWIRES in section 5, so the day the loader or
--     the dumper wires creeps this file goes red and says so.  Same blocker
--     `cmrangedhp` and `cmcreepcap` each record for the same block.
--   * ⚠️ "HER ATTACK DAMAGE IS FAR BELOW 390" IS ARITHMETIC OFF THE HERO'S STAT
--     SHEET AND THE BUY LISTS -- **NOT** A FRAME READING, and the two sentences
--     must not be merged.  `GetAttackDamage` answers 0 on every fixture frame
--     because a .dem slice carries neither attack damage nor attack speed (a
--     corpus limit stated in tests/mock/bot_api.lua, not a loader bug).  What
--     section 4 pins on real frames is the FALLBACK'S IDENTITY -- that the
--     initialiser is the attack-damage read rather than 0 or Health2 -- plus
--     the meter's own zero as a tripwire.  Section 4 refuses to read that 0 as
--     "the fallback is 0 in game".
--   * DIRECTION IS BY CONSTRUCTION AND IT IS A WIDENING (section 3).  The
--     shipped test is evaluated first and returns on its own; the armed path is
--     only ever reached after it answered false.  So acceptance is a strict
--     SUPERSET for ANY pair of inputs -- no `Health1 <= Health2` argument is
--     load-bearing and none is made.  Arming can only ADD a freeze; it can
--     never remove one and it can never move the target.  A negative wave read
--     may be blamed on "those far creeps were not worth 125-155 mana"; it may
--     NEVER be blamed on this lever having cancelled a cast.
--   * SUPERSET IS NOT CORRECTNESS (the `liondrainbkb` lesson, GH #549), so
--     section 3 also asserts the VALUE the armed path returns, not only that it
--     dominates: a mutant that answers true for everything is also a superset.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND = 'cmfarcreep'
local FLOOR = 390

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit.  Same list tests/test_cm_ranged_creep_health.lua and
-- tests/test_cm_frostbite_creep_cap.lua carry.
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

--- The source of one X.<name> function, comments included.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely mentions the expression.
local function strip_comments(body)
    return (body:gsub('%-%-[^\n]*', ''))
end

--- Load a real frame and arm (or do not arm) `cmfarcreep`.
---
--- `opt.armed == true` rather than a truthiness test: an absent key would make
--- this arm nothing, and a helper asserted against the shipped answer would then
--- pass for the wrong reason.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_cm_ranged_creep_health.lua does.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('crystal_maiden')
    return X, J, bot, heroes, fx
end

-- The (near, far) grid the direction sweeps run over.  It straddles the floor on
-- both coordinates and includes the equality case, because `>` is the shipped
-- operator and an off-by-one mutation lives exactly there.
local GRID = { 0, 39, 45, 200, 389, 390, 391, 460, 461, 800, 1100 }

-- ---------------------------------------------------------------- section 1 --
-- The defect, pinned in the source.  These are shape assertions: they say the
-- cross-read is real and that the near half does not share it.

tests['section 1: the far half no longer tests Health1 inline'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderW'))
    assert(body:find('nEnemysStrongestCreepsHealth1 > 390', 1, true) == nil,
        'X.ConsiderW still carries the bare `nEnemysStrongestCreepsHealth1 > 390`. '
        .. 'That is the cross-read this lever routes through '
        .. 'X.cm_IsFarCreepFloorMet; either the edit was reverted or a second '
        .. 'copy appeared.')
    assert(body:find('X.cm_IsFarCreepFloorMet( nEnemysStrongestCreepsHealth1, '
        .. 'nEnemysStrongestCreepsHealth2, 390 )', 1, true) ~= nil,
        'the far half no longer calls X.cm_IsFarCreepFloorMet with '
        .. '(near, far, 390) in that order. The argument ORDER is the whole '
        .. 'lever: swapping it makes the shipped leg read the far creep.')
end

tests['section 1: the far half still reads Health2 in its other two terms'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderW'))
    assert(body:find('nEnemysStrongestCreepsHealth2 > 460', 1, true) ~= nil,
        'the far half lost its 460 floor -- this lever does not touch it')
    local _, nCap = body:gsub('nEnemysStrongestCreepsHealth2 <= nCreepCap', '')
    assert(nCap == 1, string.format(
        'expected exactly 1 `Health2 <= nCreepCap`, found %d', nCap))
end

tests['section 1: the near half is untouched and internally consistent'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderW'))
    for _, s in ipairs({
        'nEnemysStrongestCreepsHealth1 > 410',
        'nEnemysStrongestCreepsHealth1 > 360',
        'nEnemysStrongestCreepsHealth1 <= nCreepCap',
    }) do
        assert(body:find(s, 1, true) ~= nil, string.format(
            'the near half lost `%s`. This lever moves ONE term in the FAR '
            .. 'half; the near half is deliberately left alone.', s))
    end
    assert(body:find('nEnemysStrongestCreepsHealth2 > 390', 1, true) == nil,
        'a bare `Health2 > 390` appeared inline. The widening belongs inside '
        .. 'X.cm_IsFarCreepFloorMet, behind the gate -- inline it would ship '
        .. 'ungated.')
end

tests['section 1: the two lists really are near and wide'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderW'))
    assert(body:find('nEnemysCreeps1 = bot:GetNearbyCreeps( nCastRange + 100, true )', 1, true),
        'Creeps1 is no longer the cast-range list; the "near vs far" framing in '
        .. 'this file and in the helper header is now wrong -- re-argue it.')
    assert(body:find('nEnemysCreeps2 = bot:GetNearbyCreeps( 1400, true )', 1, true),
        'Creeps2 is no longer the 1400 list; same as above.')
end

-- ---------------------------------------------------------------- section 2 --
-- Gate OFF is the shipped predicate, byte for byte, over the whole grid.

tests['section 2: gate off is `near > floor`, over the grid'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = false })
    for _, nNear in ipairs(GRID) do
        for _, nFar in ipairs(GRID) do
            local bGot = X.cm_IsFarCreepFloorMet(nNear, nFar, FLOOR)
            local bWant = ( nNear > FLOOR )
            assert(bGot == bWant, string.format(
                'gate OFF, near=%d far=%d floor=%d: helper answered %s, shipped '
                .. 'predicate `near > floor` is %s. Gate-off equivalence is the '
                .. 'one promise this lever makes to the shipped tree.',
                nNear, nFar, FLOOR, tostring(bGot), tostring(bWant)))
        end
    end
end

tests['section 2: armed but NOT turbo is the shipped predicate'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = true, nonTurbo = true })
    for _, nNear in ipairs(GRID) do
        for _, nFar in ipairs(GRID) do
            local bGot = X.cm_IsFarCreepFloorMet(nNear, nFar, FLOOR)
            assert(bGot == ( nNear > FLOOR ), string.format(
                'armed in NON-turbo, near=%d far=%d: answered %s. Every lever '
                .. 'this stream ships is turbo-only.', nNear, nFar, tostring(bGot)))
        end
    end
end

-- ---------------------------------------------------------------- section 3 --
-- Direction, and then the value -- because a superset alone is satisfied by a
-- mutant that answers true for everything (the liondrainbkb lesson, GH #549).

tests['section 3: armed accepts a strict superset of shipped'] = function()
    local XOff = on_frame(CM_FRAMES[1], { armed = false })
    local XOn  = on_frame(CM_FRAMES[1], { armed = true })
    local nWidened = 0
    for _, nNear in ipairs(GRID) do
        for _, nFar in ipairs(GRID) do
            local bOff = XOff.cm_IsFarCreepFloorMet(nNear, nFar, FLOOR)
            local bOn  = XOn.cm_IsFarCreepFloorMet(nNear, nFar, FLOOR)
            assert(not (bOff and not bOn), string.format(
                'near=%d far=%d: shipped accepted and armed refused. This lever '
                .. 'may only ADD casts; a wave reading may never be blamed on it '
                .. 'having cancelled one.', nNear, nFar))
            if bOn and not bOff then nWidened = nWidened + 1 end
        end
    end
    assert(nWidened > 0,
        'arming widened NOTHING over the grid -- the lever is a no-op and this '
        .. 'sweep is vacuous. Anti-vacuum, the M9 lesson.')
end

tests['section 3: armed is exactly `near > floor or far > floor`'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = true })
    for _, nNear in ipairs(GRID) do
        for _, nFar in ipairs(GRID) do
            local bGot = X.cm_IsFarCreepFloorMet(nNear, nFar, FLOOR)
            local bWant = ( nNear > FLOOR ) or ( nFar > FLOOR )
            assert(bGot == bWant, string.format(
                'armed, near=%d far=%d floor=%d: answered %s, wanted %s. '
                .. 'A superset check alone cannot see this -- `return true` is '
                .. 'also a superset.', nNear, nFar, FLOOR, tostring(bGot), tostring(bWant)))
        end
    end
end

tests['section 3: the floor is the caller\'s argument, not a helper literal'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = true })
    -- If the helper ignored nFloor and hardcoded 390, this pair would answer
    -- true where the caller asked for a floor of 460.
    assert(X.cm_IsFarCreepFloorMet(0, 400, 460) == false,
        'helper answered true for far=400 against a floor of 460 -- it is not '
        .. 'reading its third argument. The floor lives at the call site so it '
        .. 'reads beside its siblings; a helper-local copy would drift.')
    assert(X.cm_IsFarCreepFloorMet(0, 400, 360) == true,
        'helper answered false for far=400 against a floor of 360')
end

tests['section 3: the shipped leg still short-circuits before the gate'] = function()
    local X, J = on_frame(CM_FRAMES[1], { armed = true })
    local nAsked = 0
    J.IsSoakCandidate = function(id) nAsked = nAsked + 1; return id == CAND end
    assert(X.cm_IsFarCreepFloorMet(FLOOR + 1, 0, FLOOR) == true)
    assert(nAsked == 0,
        'the gate was consulted on a frame the SHIPPED predicate already '
        .. 'accepted. Order is the direction argument: shipped first, return on '
        .. 'its own, armed only reachable after a false.')
    assert(X.cm_IsFarCreepFloorMet(0, FLOOR + 1, FLOOR) == true)
    assert(nAsked == 1, string.format(
        'expected exactly 1 gate read on the widened path, saw %d', nAsked))
end

tests['section 3: the helper names exactly one soak id, and it is its own'] = function()
    local body = fn_body(read_file(SRC), 'cm_IsFarCreepFloorMet')
    local ids = {}
    for id in strip_comments(body):gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do
        ids[#ids + 1] = id
    end
    assert(#ids == 1 and ids[1] == CAND, string.format(
        'X.cm_IsFarCreepFloorMet names %d soak id(s) (%s); it must name exactly '
        .. '`%s`. A gate naming a sibling freezes FALSE the day that sibling is '
        .. 'promoted -- the `pullcad` trap -- and check_armed_wiring.py still '
        .. 'calls it WIRED.', #ids, table.concat(ids, ','), CAND))
end

-- ---------------------------------------------------------------- section 4 --
-- The fallback's IDENTITY, which is what makes the defect bite in the state the
-- far half exists for.  This is a source reading plus a meter tripwire; it is
-- NOT a measurement of her attack damage, and the two must not be merged.

tests['section 4: the picker falls back to attack damage, not 0 and not Health2'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetStrongestUnit'))
    assert(body:find('local nStrongestUnitHealth = GetBot():GetAttackDamage()', 1, true),
        'X.cm_GetStrongestUnit no longer initialises its running maximum to '
        .. 'GetBot():GetAttackDamage(). The helper header argues from that '
        .. 'fallback; if the initialiser moved, re-argue it rather than editing '
        .. 'this assertion.')
    assert(body:find('return nStrongestUnit, nStrongestUnitHealth', 1, true),
        'the picker no longer returns that running maximum as its second value')
end

tests['section 4: an empty near list really reports the fallback'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = false })
    pcall(X.SkillsComplement)   -- the picker reads the file-local nLV
    local hUnit, nHealth = X.cm_GetStrongestUnit({})
    assert(hUnit == nil, 'empty list returned a unit')
    assert(type(nHealth) == 'number', string.format(
        'empty list reported a %s, not a number -- the four floors in '
        .. 'X.ConsiderW are all `>` comparisons against it', type(nHealth)))
end

tests['section 4: GetAttackDamage is 0 on every CM frame -- a corpus limit'] = function()
    -- One-way tripwire.  This zero is a property of the METER (a .dem slice
    -- carries no attack damage), not of the hero, and it may NOT be read as
    -- "the fallback is 0 in game".  The day the dumper carries it, this goes
    -- red and the arithmetic in the helper header becomes a real reading.
    for _, path in ipairs(CM_FRAMES) do
        local _, _, bot = on_frame(path, { armed = false })
        local nAd = bot:GetAttackDamage()
        assert(nAd == 0, string.format(
            'bot:GetAttackDamage() answered %s on %s. The corpus now carries '
            .. 'attack damage: read her real value on these frames and replace '
            .. 'the stat-sheet arithmetic in X.cm_IsFarCreepFloorMet\'s header '
            .. 'with it.', tostring(nAd), path))
    end
end

-- ---------------------------------------------------------------- section 5 --
-- One-way tripwires: the supply this lever's domain needs does not exist.

tests['section 5: no fixture carries a creep UNIT'] = function()
    local nUnits = 0
    for _, path in ipairs(CM_FRAMES) do
        local _, _, _, _, fx = on_frame(path, { armed = true })
        for _, u in ipairs(fx.units) do
            nUnits = nUnits + 1
            local sName = u.name or u.unit or ''
            assert(sName:find('npc_dota_creep') == nil, string.format(
                'fixture %s now carries the creep unit %s. This file\'s header '
                .. 'says the changed term cannot be driven with a real creep; '
                .. 'that sentence is now WRONG -- drive it and delete the '
                .. 'caveat.', path, sName))
        end
    end
    assert(nUnits > 0, 'no units on any frame -- the loader broke, this is not a pass')
end

tests['section 5: bot:GetNearbyCreeps is empty on every CM frame'] = function()
    for _, path in ipairs(CM_FRAMES) do
        local _, _, bot = on_frame(path, { armed = true })
        for _, nRadius in ipairs({ 700, 1400 }) do
            local t = bot:GetNearbyCreeps(nRadius, true)
            assert(type(t) == 'table' and #t == 0, string.format(
                'bot:GetNearbyCreeps(%d, true) answered %d creep(s) on %s. '
                .. 'Both lists this lever compares come from that call, so the '
                .. 'far half is now drivable end to end -- drive it instead of '
                .. 'quoting this file\'s caveat.', nRadius, #t, path))
        end
    end
end

-- ---------------------------------------------------------------- section 6 --
-- Arming must be a no-op through the real dispatcher on real frames, because
-- those frames supply no creeps at all.  This is the "gate plumbing cannot
-- masquerade as validation" half: it proves the lever is inert where the corpus
-- can see it, and says nothing about where it is not.

tests['section 6: arming is inert through X.SkillsComplement on real frames'] = function()
    for _, path in ipairs(CM_FRAMES) do
        local XOff = on_frame(path, { armed = false })
        local okOff, errOff = pcall(XOff.SkillsComplement)
        local XOn = on_frame(path, { armed = true })
        local okOn, errOn = pcall(XOn.SkillsComplement)
        assert(okOff == okOn, string.format(
            'on %s the dispatcher succeeded on one leg and failed on the other '
            .. '(off=%s on=%s): off=%s on=%s', path, tostring(okOff),
            tostring(okOn), tostring(errOff), tostring(errOn)))
    end
end

return tests
