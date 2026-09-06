-- [hero] `cmrangedhp` -- X.cm_GetStrongestUnit REPORTS a hardcoded 500 as the
-- health of the ranged creep it early-returns, and X.ConsiderW's farm block
-- applies four floors AND the creep cap to that fabricated number.  Written
-- 2026-09-06 under OWNER_PRIORITIES P4.4 (bots/ 主体配额).
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_crystal_maiden.lua has two pickers.  Every exit of both hands
-- back the unit's own health -- `nWeakestUnitLowestHealth`, `nStrongestUnitHealth`
-- -- except ONE:
--
--     if string.find( unit:GetUnitName(), 'ranged' ) ~= nil
--         and unit:GetHealth() > GetBot():GetAttackDamage() * 2
--     then
--         return unit, 500                     <-- this literal
--     end
--
-- X.ConsiderW consumes that second return value as a health, five times:
--
--     if ( ...Health2 > 460 or ( ...Health1 > 390 and nMP > 0.45 ) )
--         and ...Health2 <= nCreepCap
--     if ( ...Health1 > 410 or ( ...Health1 > 360 and nMP > 0.45 ) )
--         and ...Health1 <= nCreepCap
--
-- SAME DEFECT AS `cmcreepcap` (GH #541), OTHER SIDE OF THE COMPARISON, AND
-- `cmcreepcap` CANNOT REACH IT.  That lever repaired the CAP so it tracks
-- Frostbite's rank; on this exit the quantity being capped is a constant, so a
-- correct cap is applied to a fabricated health.  Section 3 pins that the two
-- levers are independent.
--
-- 500 IS WRONG IN BOTH DIRECTIONS AT ONCE.  This is not one error with a sign:
--   * IT LIES HIGH on a damaged creep.  The exit admits from `2*ad` upward and
--     then reports 500, which clears all four floors (500 > 460, 410, 390, 360).
--     Lie window: `(2*ad, 460]`, non-empty for any attack damage below 230.
--   * IT LIES LOW on a healthy one.  `500 <= nCreepCap` holds at EVERY rank
--     (600/800/1000/1200), so the kill test the cap exists to run is never run
--     on this exit.  Lie window: `(nCreepCap, 1100]`, 1100 being the picker's
--     own health bar; non-empty at ranks 1-3, empty at rank 4.
--
-- WHAT THIS FILE COVERS AND WHAT IT DOES NOT -- READ BEFORE QUOTING IT
-- --------------------------------------------------------------------
--   * THE CHANGED TERM CANNOT BE DRIVEN WITH A REAL CREEP.  No fixture under
--     tests/fixtures/ carries a creep UNIT: creeps appear only as combat-log
--     `recent_damage` rows, which have no health and no handle, and
--     bot:GetNearbyCreeps answers an empty table on every frame.  Both are
--     asserted as ONE-WAY TRIPWIRES in section 5, so the day the loader or the
--     dumper wires creeps this file goes red and says so rather than staying
--     quietly green.  Same blocker cmcreepcap's own file records.
--   * WHAT IS READ OFF REAL FRAMES IS THE WIDTH OF THE `lies low` WINDOW
--     (section 2): the real Frostbite handle on each of the 10 CM-subject
--     fixtures gives the real rank and the real `dps * creep_multiplier *
--     duration`, and 3 of those 10 frames sit at a cap BELOW the picker's own
--     1100 bar.  Nothing in section 2 is invented by this test.
--   * ⚠️ THE WIDTH OF THE `lies high` WINDOW IS **NOT** A REAL-FRAME READING,
--     AND THE TWO SENTENCES MUST NOT BE MERGED.  It needs `GetAttackDamage`,
--     which answers 0 on every frame because a .dem slice carries neither
--     attack damage nor attack speed -- a CORPUS limit stated in the mock
--     itself (tests/mock/bot_api.lua:134), not a loader bug and not a
--     frequency.  Section 2b pins the zero as a one-way tripwire and refuses to
--     let a 0 be read as "the window is maximal": with ad = 0 the exit's own
--     admission test degenerates to `GetHealth() > 0`, which is a fact about
--     the meter.  Sizing is iterations/queue.json hero-36, never this scan.
--   * DIRECTION IS BY CONSTRUCTION AND IT IS A NARROWING (section 3).  The unit
--     returned does not change -- only the number does -- and all five
--     consuming terms are monotone in it, with 500 satisfying every one of
--     them at every rank.  Arming can only REMOVE a freeze; it can never add
--     one and it can never move a target.  A negative wave read may be blamed
--     on "she should have frozen that creep after all"; it may NEVER be blamed
--     on this lever having invented a cast.
--     ⚠️ AND THE SWEEP THAT CERTIFIES IT IS AN IDENTITY, NOT A SECOND OPINION:
--     once "500 clears every floor and every cap" holds, the per-pair subset
--     check cannot fail for any armed value at all.  Section 3's header says
--     which single assertion is load-bearing and which mutant moves it.
--   * SUBSET IS NOT CORRECTNESS -- the `liondrainbkb` lesson (GH #549), written
--     as its own assertion here.  Section 6 arms the gate on frames that carry
--     no ranged-named unit at all and demands a byte-identical answer; a
--     mutation that reports the WRONG health is still a subset and section 3
--     cannot see it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local SRC = 'bots/BotLib/hero_crystal_maiden.lua'
local FROST = 'crystal_maiden_frostbite'
local CAND = 'cmrangedhp'
local SHIPPED_REPORT = 500
local PICKER_HP_BAR = 1100

-- Every Crystal-Maiden-SUBJECT fixture, listed rather than globbed so a new one
-- is a deliberate edit and section 2's counts move with a named cause.  Same
-- list tests/test_cm_frostbite_creep_cap.lua carries.
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

--- Load a real frame and arm (or do not arm) `cmrangedhp`.
---
--- `opt.armed == true` rather than a truthiness test: an absent key would make
--- this arm nothing, and a helper asserted `== SHIPPED_REPORT` would then pass
--- for the wrong reason.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_cm_frostbite_creep_cap.lua does.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('crystal_maiden')
    return X, J, bot, heroes, fx
end

local function unit_with_health(nHealth, sName)
    local u = {}
    function u:GetHealth() return nHealth end
    function u:GetUnitName() return sName or 'npc_dota_creep_goodguys_ranged' end
    return u
end

--- The KV ladder for one Frostbite key, off the snapshot rather than typed.
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

local function cap_at_rank(nRank)
    return step_at(kv_steps('damage_per_second'), nRank)
         * step_at(kv_steps('creep_multiplier'), nRank)
         * step_at(kv_steps('duration'), nRank)
end

--- The four floors X.ConsiderW applies to the reported health, READ OUT OF THE
--- SOURCE rather than re-typed here.  If someone moves 460 the sweep in section
--- 3 moves with it instead of certifying a shape the file no longer has.
local function consumer_floors()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderW'))
    local floors = {}
    for lit in body:gmatch('nEnemysStrongestCreepsHealth[12]%s*>%s*(%d+)') do
        floors[#floors + 1] = assert(tonumber(lit))
    end
    return floors, body
end

-- ---------------------------------------------------------------- section 1 --
-- The source shapes the whole argument rests on.  Each of these going red means
-- "re-read the file", never "the test is stale".

tests['section 1: the ranged exit no longer carries a bare literal'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetStrongestUnit'))
    assert(body:find('return%s+unit%s*,%s*500') == nil,
        'X.cm_GetStrongestUnit still returns the bare literal 500 -- the call '
        .. 'site was not wired, so the gate is dead and every reading taken '
        .. 'through it measures nothing.')
    assert(body:find('X%.cm_GetRangedCreepReportedHealth%s*%(%s*unit%s*%)') ~= nil,
        'X.cm_GetStrongestUnit no longer calls X.cm_GetRangedCreepReportedHealth( unit ).')
end

tests['section 1: the helper still ships the literal it replaced'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetRangedCreepReportedHealth'))
    assert(body:find('nShipped%s*=%s*500') ~= nil,
        'the shipped report is no longer 500; the direction argument in section '
        .. '3 is written against that value and has to be re-argued.')
    assert(body:find("J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)") ~= nil,
        'the helper is no longer turbo-only + gated on ' .. CAND .. '.')
end

tests['section 1: the exit admits off GetAttackDamage * 2, unchanged'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'cm_GetStrongestUnit'))
    assert(body:find('GetBot%(%):GetAttackDamage%(%)%s*%*%s*2') ~= nil,
        "the ranged exit's admission test moved. The `lies high` window in this "
        .. "file's header is `(2*ad, 460]` and is derived from exactly that "
        .. 'expression.')
    assert(body:find('GetHealth%(%)%s*<=%s*' .. PICKER_HP_BAR) ~= nil,
        'the picker\'s own ' .. PICKER_HP_BAR .. ' health bar moved. It is the '
        .. 'upper end of the `lies low` window and section 2 reads it.')
end

tests['section 1: the consumer still applies four floors and one cap'] = function()
    local floors, body = consumer_floors()
    assert(#floors == 4, string.format(
        'X.ConsiderW now applies %d floors to the reported health, not 4. The '
        .. 'direction sweep in section 3 enumerates them; re-read the block.', #floors))
    local nCap = 0
    for _ in body:gmatch('nEnemysStrongestCreepsHealth[12]%s*<=%s*nCreepCap') do nCap = nCap + 1 end
    assert(nCap == 2, string.format(
        'X.ConsiderW compares the reported health against nCreepCap %d times, '
        .. 'not 2. The `lies low` half of the defect is exactly those terms.', nCap))
end

-- ---------------------------------------------------------------- section 2 --
-- REAL FRAMES.  The width of the `lies low` window, read off the real Frostbite
-- handle on every Crystal-Maiden-subject fixture.  No number below is invented.

tests['section 2: the lies-low window is non-empty on real frames'] = function()
    local nOpen, nTotal = 0, 0
    local seen = {}
    for _, path in ipairs(CM_FRAMES) do
        local X, J, bot = on_frame(path, { armed = true })
        local hFrost = bot:GetAbilityByName(FROST)
        assert(hFrost ~= nil, 'no ' .. FROST .. ' handle on ' .. path)
        local nRank = hFrost:GetLevel()
        local nCap = hFrost:GetSpecialValueInt('damage_per_second')
                   * hFrost:GetSpecialValueInt('creep_multiplier')
                   * hFrost:GetSpecialValueFloat('duration')
        assert(nCap > 0, 'the real handle answered a cap of 0 on ' .. path
            .. ' -- that is the meter, not the game; do not read it as a window.')
        assert(nCap == cap_at_rank(nRank), string.format(
            'the real handle on %s answers %s at rank %s, but the KV snapshot '
            .. 'ladder says %s. One of the two moved.',
            path, tostring(nCap), tostring(nRank), tostring(cap_at_rank(nRank))))
        nTotal = nTotal + 1
        seen[nRank] = (seen[nRank] or 0) + 1
        if nCap < PICKER_HP_BAR then
            nOpen = nOpen + 1
            -- On this frame a real creep with health in (nCap, 1100] is admitted
            -- by the picker's own bar, reported as 500, and passes `<= nCreepCap`
            -- while Frostbite cannot kill it.
            assert(SHIPPED_REPORT <= nCap, 'the shipped report stopped clearing '
                .. 'the cap at rank ' .. tostring(nRank) .. '; the defect changed shape.')
        end
    end
    assert(nTotal == #CM_FRAMES, 'not every listed frame loaded')
    assert(nOpen >= 3, string.format(
        'only %d of %d real Crystal Maiden frames sit at a Frostbite cap below '
        .. 'the picker\'s %d bar. This file\'s one real-frame reading is that '
        .. 'window; if the corpus no longer holds it, say so instead of '
        .. 'quoting the old count.', nOpen, nTotal, PICKER_HP_BAR))
    -- The corpus is rank-heavy and that errs AGAINST this change: at rank 4 the
    -- cap is 1200 and the lies-low window is empty.  A floor on how often the
    -- band is reached in a real turbo game, never a rate.
    assert((seen[4] or 0) >= 1, 'the rank-heavy caveat in the header assumes at '
        .. 'least one rank-4 frame; the corpus changed.')
end

tests['section 2b: GetAttackDamage is 0 on every frame -- a corpus limit'] = function()
    -- ONE-WAY TRIPWIRE.  A .dem slice carries neither attack damage nor attack
    -- speed (tests/mock/bot_api.lua:134), so `2*ad` is 0 here and the exit's
    -- admission test degenerates to `GetHealth() > 0`.  That is a fact about
    -- the meter.  It must NOT be read as "the lies-high window is maximal", and
    -- the day a dump carries the number this assertion goes red and asks for it.
    for _, path in ipairs(CM_FRAMES) do
        local _, _, bot = on_frame(path, { armed = true })
        local ad = bot:GetAttackDamage()
        assert(ad == 0, string.format(
            'bot:GetAttackDamage() answered %s on %s. It has read 0 on every '
            .. 'frame until now, which is why this file refuses to state a '
            .. 'width for the `lies high` window `(2*ad, 460]`. A non-zero '
            .. 'reading means the corpus can now supply it: measure the window '
            .. 'and rewrite the header sentence instead of deleting this test.',
            tostring(ad), path))
    end
end

-- ---------------------------------------------------------------- section 3 --
-- DIRECTION BY CONSTRUCTION -- AND READ THIS BEFORE QUOTING THE SWEEP.
--
-- The load-bearing assertion is the FIRST one: the shipped report 500 clears
-- every floor and every rank's cap.  Everything else about the direction is a
-- COROLLARY of it, not a second measurement -- if `bShipped` is true for every
-- (rank, floor) pair then `bShipped or not bArmed` is true whatever the armed
-- value is, so the per-pair check in the sweep CANNOT FAIL while the first
-- assertion holds.  That is an identity, not a diagnostic (README 铁律 4 (i-c)
-- makes the same distinction about swap-averaged estimators).  It is kept
-- anyway, and it is not decoration: `consumer_floors()` re-reads the floors OUT
-- OF THE SOURCE, so a change that pushes a floor above 500 -- or a patch that
-- pushes the rank-1 cap below it -- turns the premise red rather than leaving a
-- stale "narrowing by construction" sentence standing.  Mutant M6 is exactly
-- that edit.
--
-- What the sweep measures on its own is the OTHER half: `nStrict > 0`, i.e. the
-- lever is not a no-op.

tests['section 3: 500 satisfies every consuming term at every rank'] = function()
    local floors = consumer_floors()
    for _, nFloor in ipairs(floors) do
        assert(SHIPPED_REPORT > nFloor, string.format(
            'the shipped report %d no longer clears the floor %d. The whole '
            .. 'narrowing argument is "500 passes everything, so any other '
            .. 'value can only fail something"; re-argue it.',
            SHIPPED_REPORT, nFloor))
    end
    for nRank = 1, 4 do
        assert(SHIPPED_REPORT <= cap_at_rank(nRank), string.format(
            'the shipped report %d no longer clears the rank-%d cap %s.',
            SHIPPED_REPORT, nRank, tostring(cap_at_rank(nRank))))
    end
end

tests['section 3: armed admits a strict subset, swept over health x rank'] = function()
    local floors = consumer_floors()
    local X = on_frame(CM_FRAMES[1], { armed = true })
    local nStrict = 0
    for nHealth = 1, 1300, 1 do
        local nArmed = X.cm_GetRangedCreepReportedHealth(unit_with_health(nHealth))
        assert(nArmed == nHealth, string.format(
            'armed reported %s for a creep at %d health', tostring(nArmed), nHealth))
        for nRank = 1, 4 do
            local nCap = cap_at_rank(nRank)
            for _, nFloor in ipairs(floors) do
                local bShipped = (SHIPPED_REPORT > nFloor) and (SHIPPED_REPORT <= nCap)
                local bArmed = (nArmed > nFloor) and (nArmed <= nCap)
                -- Corollary of the premise above, machine-checked over the whole
                -- enumerated space rather than argued.  It cannot fail while the
                -- premise holds; when the premise moves, THIS is the line that
                -- says which (health, rank, floor) the direction broke at.
                assert(bShipped or not bArmed, string.format(
                    'WIDENING at health %d, rank %d, floor %d: armed admits '
                    .. 'where shipped does not. The lever claims armed is a '
                    .. 'strict subset of shipped and a negative wave read is '
                    .. 'interpreted under that claim.', nHealth, nRank, nFloor))
                if bShipped and not bArmed then nStrict = nStrict + 1 end
            end
        end
    end
    assert(nStrict > 0, 'the sweep never found a health at which armed declines '
        .. 'and shipped admits -- the lever would be a no-op at every rank.')
end

tests['section 3: the lever is independent of cmcreepcap'] = function()
    -- `cmcreepcap` repairs the CAP; this one repairs the QUANTITY BEING CAPPED.
    -- Arming cmcreepcap alone leaves the ranged exit reporting 500, so the
    -- repaired cap is still applied to a constant.
    local J, bot = rf.load(CM_FRAMES[1])
    J.IsSoakCandidate = function(id) return id == 'cmcreepcap' end
    local X = rf.load_hero('crystal_maiden')
    local n = X.cm_GetRangedCreepReportedHealth(unit_with_health(900))
    assert(n == SHIPPED_REPORT, string.format(
        'with only cmcreepcap armed the ranged exit reported %s, not the '
        .. 'shipped %d. The two gates are meant to be separable: a wave that '
        .. 'arms one must not move the other.', tostring(n), SHIPPED_REPORT))
end

-- ---------------------------------------------------------------- section 4 --
-- GATE-OFF, and the fall-through the shape rule buys.

tests['section 4: gate off is the shipped literal, byte for byte'] = function()
    for _, path in ipairs(CM_FRAMES) do
        local X = on_frame(path, { armed = false })
        for _, h in ipairs({ 1, 300, 500, 900, 1099, 5000 }) do
            local n = X.cm_GetRangedCreepReportedHealth(unit_with_health(h))
            assert(n == SHIPPED_REPORT, string.format(
                'gate off, health %d: reported %s not %d (%s)',
                h, tostring(n), SHIPPED_REPORT, path))
        end
    end
end

tests['section 4: armed but NOT turbo is the shipped literal'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = true, nonTurbo = true })
    local n = X.cm_GetRangedCreepReportedHealth(unit_with_health(900))
    assert(n == SHIPPED_REPORT, string.format(
        'outside turbo the armed helper reported %s, not the shipped %d. Every '
        .. 'behaviour candidate in this repo is turbo-only.',
        tostring(n), SHIPPED_REPORT))
end

tests['section 4: a health reading <= 0 falls through, it does not report 0'] = function()
    local X = on_frame(CM_FRAMES[1], { armed = true })
    for _, u in ipairs({ unit_with_health(0), unit_with_health(-5) }) do
        local n = X.cm_GetRangedCreepReportedHealth(u)
        assert(n == SHIPPED_REPORT, string.format(
            'a non-positive health read reported %s. Reporting 0 would not '
            .. 'narrow this exit, it would CLOSE it -- 0 fails every floor, so '
            .. 'the ranged half of the farm block would go silent in every '
            .. 'armed turbo game (the GH #162 house rule).', tostring(n)))
    end
    local n = X.cm_GetRangedCreepReportedHealth(nil)
    assert(n == SHIPPED_REPORT, 'a nil unit reported ' .. tostring(n))
end

-- ---------------------------------------------------------------- section 5 --
-- COVERAGE BOUNDARY, as ONE-WAY TRIPWIRES.  Stated so nobody quotes this file
-- as "the branch was driven on a real creep".

tests['section 5: no fixture carries a creep UNIT'] = function()
    local nUnits, nRanged = 0, 0
    for _, path in ipairs(CM_FRAMES) do
        local _, _, _, _, fx = on_frame(path, { armed = true })
        for _, u in ipairs(fx.units) do
            nUnits = nUnits + 1
            local sName = u.name or u.unit or ''
            assert(sName:find('npc_dota_creep') == nil, string.format(
                'fixture %s now carries the creep unit %s. The header of this '
                .. 'file says the changed term cannot be driven with a real '
                .. 'creep; that sentence is now WRONG -- drive it and delete '
                .. 'the caveat.', path, sName))
            if sName:find('ranged') ~= nil then nRanged = nRanged + 1 end
        end
    end
    assert(nUnits > 0, 'no units on any frame -- the loader broke, this is not a pass')
    assert(nRanged == 0, string.format(
        '%d unit(s) across the CM frames are now named `ranged`. The ranged '
        .. 'exit is reachable on real frames; drive it.', nRanged))
end

tests['section 5: bot:GetNearbyCreeps is empty on every CM frame'] = function()
    for _, path in ipairs(CM_FRAMES) do
        local _, _, bot = on_frame(path, { armed = true })
        for _, bEnemy in ipairs({ true, false }) do
            local t = bot:GetNearbyCreeps(1400, bEnemy)
            assert(type(t) == 'table' and #t == 0, string.format(
                'bot:GetNearbyCreeps(1400, %s) answered %d creep(s) on %s. '
                .. 'X.ConsiderW\'s farm block feeds exactly that list to the '
                .. 'picker, so the block is now fixture-drivable end to end -- '
                .. 'drive it instead of quoting this file\'s caveat.',
                tostring(bEnemy), #t, path))
        end
    end
end

-- ---------------------------------------------------------------- section 6 --
-- SUBSET IS NOT CORRECTNESS (the liondrainbkb lesson, GH #549).  A mutation that
-- reports the wrong health is STILL a subset of shipped; section 3 cannot see
-- it.  What sees it is: on a frame carrying no ranged-named unit, arming must
-- be a byte-identical no-op through the real picker.

tests['section 6: arming is a no-op through the real picker on real frames'] = function()
    -- X.cm_GetStrongestUnit reads the file-local `nLV`, which only X.SkillsComplement
    -- assigns.  In game that dispatcher always runs first; here it has to be
    -- driven, or the picker dies on `nLV < 25` with nil.  Driving it is also the
    -- faithful thing: it is the real entry point, on the real frame.
    for _, path in ipairs(CM_FRAMES) do
        local XOff, _, botOff = on_frame(path, { armed = false })
        pcall(XOff.SkillsComplement)
        local XOn, _, botOn = on_frame(path, { armed = true })
        pcall(XOn.SkillsComplement)
        for _, nRadius in ipairs({ 800, 1400, 1600 }) do
            local uOff, hOff = XOff.cm_GetStrongestUnit(botOff:GetNearbyHeroes(nRadius, true, 0))
            local uOn, hOn = XOn.cm_GetStrongestUnit(botOn:GetNearbyHeroes(nRadius, true, 0))
            local sOff = uOff and uOff:GetUnitName() or '<nil>'
            local sOn = uOn and uOn:GetUnitName() or '<nil>'
            assert(sOff == sOn, string.format(
                'arming moved the picked unit on %s at r=%d: %s -> %s. This '
                .. 'lever changes a REPORTED NUMBER and must never change '
                .. 'target identity.', path, nRadius, sOff, sOn))
            assert(hOff == hOn, string.format(
                'arming moved the reported health on %s at r=%d: %s -> %s, on '
                .. 'a frame that carries no ranged-named unit. The armed leg '
                .. 'is reaching a path it must not reach.',
                path, nRadius, tostring(hOff), tostring(hOn)))
        end
    end
end

tests['section 6: the wrong-health mutant is still a subset -- so assert value'] = function()
    -- The assertion that catches it: armed must report the unit's OWN health,
    -- not merely SOME value below the shipped 500.  A mutant answering a
    -- constant 1 passes every subset check in section 3.
    local X = on_frame(CM_FRAMES[1], { armed = true })
    for _, h in ipairs({ 37, 461, 799, 1099 }) do
        local n = X.cm_GetRangedCreepReportedHealth(unit_with_health(h))
        assert(n == h, string.format(
            'armed reported %s for a creep at %d health. Any constant below '
            .. '500 is a subset of shipped and section 3 would certify it; '
            .. 'this is the assertion that does not.', tostring(n), h))
    end
end

return tests
