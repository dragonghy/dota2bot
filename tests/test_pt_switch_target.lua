-- [hero] `J.SetQueuePtToINT` -- the five-name family that every focus-five
-- spell cast walks through -- accepts exactly one Power Treads state, and that
-- state is ATTRIBUTE_AGILITY.  Not INTELLECT.  Measured, not read off.
--
-- WHY THIS FILE EXISTS (new axis, 2026-08-25)
--
-- The six previous rounds asked what a NUMBER is worth (`0CLK` a constant,
-- `0TERN` how an expression parses, GH #162/#179 what a KV read returns,
-- GH #175 which field an API call reads) or whether the ENGINE ACCEPTS an
-- order (GH #177 `CASTSHAPE`).  This one asks a third kind of question:
--
--   a helper family agrees with ITSELF perfectly, and its correctness rests
--   entirely on one engine fact nobody in the tree ever wrote down.
--
-- Every focus-five hero opens each queued cast the same way::
--
--     J.SetQueuePtToINT( bot, <bSoulRingUsed> )      -- 19 call sites, 5 files
--     bot:ActionQueue_UseAbility*( ability, target )
--
-- and `J.SetQueuePtToINT` is load-bearing twice over: its `Action_ClearActions`
-- is what stops the appended cast from sitting behind the mode's move order
-- (BOT_API_REFERENCE.md:1628-1630 -- `ActionQueue_*` APPENDS), and its second
-- half queues Power Treads presses AHEAD of the spell.  The point of pressing
-- treads before a cast is the mana: Intelligence treads raise max AND current
-- mana, so the switch is what pays for the spell.
--
-- THE MEASUREMENT (section 1, executes the shipped helpers)
--
-- Drive the real `J.SetQueuePtToINT` with a real treads handle reporting each
-- of the three attributes and count the presses it queues:
--
--     treads on STR  -> 1 press,  treads on INT -> 2 presses,
--     treads on AGI  -> 0 presses   <-- the ONLY state it leaves alone
--
-- The state the family calls "done" is ATTRIBUTE_AGILITY.  `J.IsPTReady`
-- produces that by rewriting its own argument (INT -> AGI) before comparing,
-- so `IsPTReady(bot, ATTRIBUTE_INTELLECT)` literally asks "are the treads on
-- Agility".  Section 1 asserts this off the running code, so it cannot be
-- dismissed as a misreading of the source.
--
-- WHY THE CYCLE DIRECTION DOES NOT RESCUE IT (section 2)
--
-- One might hope the press counts redeem the names.  They cannot, and the
-- arithmetic is done here for BOTH possible toggle directions rather than
-- asserting one:
--
--   cycle A  STR -> AGI -> INT -> STR   every start converges on AGI and stops
--   cycle B  STR -> INT -> AGI -> STR   STR<->INT is a 2-cycle that never
--                                       reaches the accepted state at all, so
--                                       1-2 item presses are queued in front of
--                                       EVERY spell on EVERY tick, forever
--
-- Under A the family parks the treads on Agility before each cast; under B it
-- never settles.  Under neither is "treads on ATTRIBUTE_INTELLECT" a state the
-- family will hold.  That is the direction-independent result, and it needs no
-- knowledge of the real toggle order -- which this file therefore does not
-- claim to have.
--
-- THE COUNTER-HYPOTHESIS, STATED SO IT IS NOT QUIETLY SKIPPED
--
-- `bots/` reads `GetPowerTreadsStat()` six times, in four functions across
-- three files, and they do not agree on what the returned value means.  Three
-- functions rewrite INT<->AGI before comparing (`J.IsPTReady`,
-- `J.ShouldSwitchPTStat`, and `ability_item_usage_generic.lua`'s
-- ConsiderItemDesire['item_power_treads']); two take the raw value at face
-- value (`J.SetQueueSwitchPtToINT`, and `hero_morphling.lua`'s attribute
-- accounting, which credits nAddedAGI when the read says AGILITY).
-- Nothing anywhere says why the swap is there.  If the engine really does report Intelligence
-- treads as ATTRIBUTE_AGILITY, then that swap is a correct workaround, the
-- accepted state IS true Intelligence, and this whole family is right --
-- misnamed at four sites but right.  `docs/BOT_API_REFERENCE.md:1616` says the
-- opposite ("Current Power Treads attribute (ATTRIBUTE_STRENGTH,
-- ATTRIBUTE_AGILITY, ATTRIBUTE_INTELLECT)").
--
-- So the behavior of all 22 focus-five cast paths hangs on one predicate no
-- desk here can evaluate -- exactly the shape GH #177 named on CM's dispatcher.
-- And the disagreement is not academic: under the swap hypothesis morphling's
-- own stat accounting is the one that is wrong, so SOME reader in this tree is
-- wrong either way.
-- This file does NOT decide it.  It pins the arithmetic so that whichever way
-- the observation lands, the conclusion follows in one step, and so that a
-- future edit to any one of the four readers cannot silently desynchronize it
-- from the other three.
--
-- DECLARED LIMITS (all four measured below, none assumed)
--
--   L1  The mock hands unrecognized ALL_CAPS globals sequential integers, so
--       ATTRIBUTE_STRENGTH/AGILITY/INTELLECT here are 1001/1002/1003, not the
--       engine's values.  Only their DISTINCTNESS is used; section 4 asserts
--       that and nothing more.  (Same trap as GH #177, where mock flag values
--       that were not disjoint powers of two turned a correct implementation
--       red.)
--   L2  `GetPowerTreadsStat()` answers 0 on an unstubbed handle -- GH #133
--       measured 270/270 real fixture handles reading 0, and 0 equals none of
--       the three constants.  Every stat in section 1 is INJECTED.  No claim
--       here is a real-frame observation, and no green run of any fixture test
--       may be read as evidence about this family.
--   L3  The toggle direction is not read from the engine either; section 2
--       enumerates both and asserts only what holds in both.
--   L4  Section 3's ratchet is SOURCE-level on purpose (same reasoning as
--       test_gate_claim_consistency.lua): a run can only exercise the paths it
--       happens to take, while "the four readers agree" has to hold for the
--       reader somebody adds next month.
--
-- ZERO BEHAVIOR CHANGE.  `bots/` is untouched by this file's landing: turning a
-- possibly-correct compensation off is itself a behavior change needing its own
-- justification (GH #170's reasoning), and the domain is all 127 heroes, not
-- the five this group owns.  Next baton is the observation, filed as a queue
-- request; the id to gate is not written until that comes back.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local FOCUS_FIVE = {
    'bots/BotLib/hero_axe.lua',
    'bots/BotLib/hero_zuus.lua',
    'bots/BotLib/hero_skeleton_king.lua',
    'bots/BotLib/hero_lion.lua',
    'bots/BotLib/hero_crystal_maiden.lua',
}

local JMZ = 'bots/FunLib/jmz_func.lua'
local ITEM_USAGE = 'bots/ability_item_usage_generic.lua'
local MORPHLING = 'bots/BotLib/hero_morphling.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local text = fh:read('*a')
    fh:close()
    return text
end

-- The mock mints ALL_CAPS globals lazily, so ATTRIBUTE_STRENGTH does not exist
-- until something has installed the API and touched it. Materialize the three
-- once, up front, and carry them in locals: reading them off _G at call time
-- silently yields nil before the first install, and a nil stat matches neither
-- branch of the switcher -- which reads exactly like "the code queues nothing".
-- (Cost of learning this: the first run of section 1 reported STR -> 0 presses.)
local STR, AGI, INT
do
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_lion') })
    STR, AGI, INT = ATTRIBUTE_STRENGTH, ATTRIBUTE_AGILITY, ATTRIBUTE_INTELLECT
end

----------------------------------------------------------------------
-- Section 1 -- measure the shipped helpers
----------------------------------------------------------------------

--- Fresh world with the bot wearing Power Treads reporting `nStat`.
-- Returns J, bot, and a press counter that ONLY counts presses of the treads
-- handle (a soul ring / other queued item would not be a tread press, and
-- counting it would fake the very table this file measures).
local function fresh(nStat)
    api.reset_modules()
    local presses = { n = 0 }
    local treads
    local bot = api.MakeHero('npc_dota_hero_lion', {
        GetItemInSlot = function(_, slot)
            if slot == 0 then return treads end
            return nil
        end,
    })
    -- Action_ClearActions and ActionQueue_UseAbility have no mock default that
    -- means anything (the metatable answers nil for non-Get names); stub them
    -- so the count is of real calls made by real code.
    bot.__spec.Action_ClearActions = function() return nil end
    bot.__spec.ActionQueue_UseAbility = function(_, hItem)
        if hItem == treads then presses.n = presses.n + 1 end
        return nil
    end
    api.install({ bot = bot })
    treads = api.MakeAbility('item_power_treads', {
        IsFullyCastable = true,
        GetPowerTreadsStat = nStat,
    })
    assert(ATTRIBUTE_STRENGTH == STR and ATTRIBUTE_AGILITY == AGI
        and ATTRIBUTE_INTELLECT == INT,
        'mock renumbered the ATTRIBUTE_* globals between installs')
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    return J, bot, presses
end

--- Net presses `J.SetQueuePtToINT` queues from a given starting tread stat.
local function presses_from(nStat)
    local J, bot, presses = fresh(nStat)
    J.SetQueuePtToINT(bot, false)
    return presses.n
end

--- Does the family consider `nStat` already done?
local function guard_accepts(nStat)
    local J, bot = fresh(nStat)
    return J.IsPTReady(bot, INT) == true
end

tests['1.1 press table: STR->1, INT->2, AGI->0 (measured off the shipped code)'] = function()
    local got = {
        STR = presses_from(STR),
        AGI = presses_from(AGI),
        INT = presses_from(INT),
    }
    local want = { STR = 1, AGI = 0, INT = 2 }
    for _, k in ipairs({ 'STR', 'AGI', 'INT' }) do
        if got[k] ~= want[k] then
            error(string.format(
                'SetQueuePtToINT from %s queued %d treads presses, expected %d'
                .. ' (press table changed -- redo section 2 arithmetic)',
                k, got[k], want[k]), 0)
        end
    end
end

tests['1.2 the ONLY state the family leaves alone is ATTRIBUTE_AGILITY'] = function()
    local accepted = {}
    for _, pair in ipairs({
        { 'STR', STR }, { 'AGI', AGI }, { 'INT', INT },
    }) do
        if guard_accepts(pair[2]) then accepted[#accepted + 1] = pair[1] end
    end
    if #accepted ~= 1 or accepted[1] ~= 'AGI' then
        error('IsPTReady(bot, ATTRIBUTE_INTELLECT) accepts { '
            .. table.concat(accepted, ', ') .. ' }; expected exactly { AGI }', 0)
    end
end

tests['1.3 treads already on ATTRIBUTE_INTELLECT are treated as WRONG'] = function()
    -- The headline, and it needs no cycle direction and no mock constant
    -- values: a family whose five names all say INT fires when the treads
    -- report INT, and only stops when they report AGI.
    if guard_accepts(INT) then
        error('IsPTReady now accepts INT -- the INT/AGI question has moved;'
            .. ' re-read this whole file before trusting it', 0)
    end
    if presses_from(INT) == 0 then
        error('SetQueuePtToINT no longer presses from INT', 0)
    end
end

----------------------------------------------------------------------
-- Section 2 -- both toggle directions, and what survives both
----------------------------------------------------------------------

local CYCLES = {
    A = { STR, AGI, INT },
    B = { STR, INT, AGI },
}

local function advance(cycle, nStat, nPresses)
    local idx
    for i, v in ipairs(cycle) do if v == nStat then idx = i end end
    assert(idx, 'stat not in cycle')
    return cycle[((idx - 1 + nPresses) % 3) + 1]
end

--- One guarded tick: accepted states hold, others get their measured presses.
local function step(cycle, nStat)
    if guard_accepts(nStat) then return nStat end
    return advance(cycle, nStat, presses_from(nStat))
end

--- Orbit of `nStat` under repeated ticks, as a list of states visited.
local function orbit(cycle, nStat, nTicks)
    local seen = { nStat }
    local cur = nStat
    for _ = 1, nTicks do
        cur = step(cycle, cur)
        seen[#seen + 1] = cur
    end
    return seen
end

tests['2.1 cycle A (STR->AGI->INT): every start converges on AGI and stops'] = function()
    for _, start in ipairs({ STR, AGI, INT }) do
        local o = orbit(CYCLES.A, start, 4)
        for i = 2, #o do
            if o[i] ~= AGI then
                error('cycle A: orbit from ' .. tostring(start)
                    .. ' did not settle on AGI at tick ' .. (i - 1), 0)
            end
        end
    end
end

tests['2.2 cycle B (STR->INT->AGI): STR and INT form a 2-cycle that never reaches the accepted state'] = function()
    for _, start in ipairs({ STR, INT }) do
        local o = orbit(CYCLES.B, start, 6)
        for i = 2, #o do
            if o[i] == AGI then
                error('cycle B: orbit from ' .. tostring(start)
                    .. ' reached AGI -- the 2-cycle claim is stale', 0)
            end
        end
        -- and it really is a 2-cycle, i.e. presses are queued forever
        if o[2] == start or o[3] ~= start then
            error('cycle B: orbit from ' .. tostring(start) .. ' is not a 2-cycle', 0)
        end
    end
end

tests['2.3 direction-independent: INTELLECT is a stable state under NEITHER cycle'] = function()
    for name, cycle in pairs(CYCLES) do
        if step(cycle, INT) == INT then
            error('cycle ' .. name .. ': treads on INT are held -- the whole'
                .. ' finding is void, re-derive it', 0)
        end
    end
end

----------------------------------------------------------------------
-- Section 3 -- source ratchet over the four readers and the 22 call sites
----------------------------------------------------------------------

--- Body of a top-level `function <name>(` in `src`, up to the matching column-0
-- `end`.  Deliberately NOT a lazy `.-` grab across the whole file: GH #151
-- recorded a census that silently ate the last entry of every block that way.
local function function_body(src, name)
    local s = src:find('\nfunction%s+' .. name:gsub('%.', '%%.') .. '%s*%(')
    assert(s, 'function not found: ' .. name)
    local e = src:find('\nend', s, true)
    assert(e, 'unterminated function: ' .. name)
    return src:sub(s, e + 3)
end

tests['3.1 exactly six GetPowerTreadsStat readers, in the three known files'] = function()
    local p = assert(io.popen('grep -rc "GetPowerTreadsStat()" bots/ --include=*.lua'
        .. ' 2>/dev/null | grep -v ":0$" | sort'))
    local lines = {}
    for line in p:lines() do lines[#lines + 1] = line end
    p:close()
    local want = { JMZ .. ':4', ITEM_USAGE .. ':1', MORPHLING .. ':1' }
    table.sort(want)
    if #lines ~= #want then
        error('GetPowerTreadsStat reader files changed: { '
            .. table.concat(lines, ', ') .. ' }', 0)
    end
    for i, v in ipairs(want) do
        if lines[i] ~= v then
            error('GetPowerTreadsStat readers: got ' .. lines[i]
                .. ', want ' .. v, 0)
        end
    end
end

tests['3.2 three of the four readers rewrite INT<->AGI; the switcher does not'] = function()
    -- The swap, written the one way the tree writes it.
    local SWAP = 'ATTRIBUTE_INTELLECT%s*\n?%s*then%s*\n?%s*[%w]*%s*=?%s*ATTRIBUTE_AGILITY'
    local jmz = read_file(JMZ)
    local usage = read_file(ITEM_USAGE)

    local swaps = {
        ['J.IsPTReady'] = function_body(jmz, 'J.IsPTReady'),
        ['J.ShouldSwitchPTStat'] = function_body(jmz, 'J.ShouldSwitchPTStat'),
    }
    for name, body in pairs(swaps) do
        if not body:find(SWAP) then
            error(name .. ' no longer rewrites INT->AGI before comparing;'
                .. ' the four readers have desynchronized', 0)
        end
    end
    -- The item-usage consumer swaps at the top of its ConsiderItemDesire entry.
    if not usage:find(SWAP) then
        error(ITEM_USAGE .. ' no longer rewrites INT->AGI', 0)
    end
    -- ... and the switcher, alone, compares the raw value.
    local switcher = function_body(jmz, 'J.SetQueueSwitchPtToINT')
    if switcher:find(SWAP) then
        error('J.SetQueueSwitchPtToINT now swaps too -- section 1/2 arithmetic'
            .. ' is stale, re-measure before trusting this file', 0)
    end
end

tests['3.3 the switcher has no ATTRIBUTE_AGILITY branch (AGI falls through at 0 presses)'] = function()
    local switcher = function_body(read_file(JMZ), 'J.SetQueueSwitchPtToINT')
    if switcher:find('ATTRIBUTE_AGILITY') then
        error('J.SetQueueSwitchPtToINT grew an AGI branch; re-measure section 1', 0)
    end
end

tests['3.4 all 22 focus-five queued casts still funnel through SetQueuePtToINT'] = function()
    -- The bite: this is not a helper five files could route around. Counted per
    -- file so a drop in one hero is visible instead of hidden in a total.
    local want = {
        ['bots/BotLib/hero_axe.lua'] = 3,
        ['bots/BotLib/hero_zuus.lua'] = 6,
        ['bots/BotLib/hero_skeleton_king.lua'] = 2,
        ['bots/BotLib/hero_lion.lua'] = 3,
        ['bots/BotLib/hero_crystal_maiden.lua'] = 5,
    }
    local total = 0
    for _, path in ipairs(FOCUS_FIVE) do
        local src = read_file(path)
        local n = 0
        for _ in src:gmatch('J%.SetQueuePtToINT%s*%(') do n = n + 1 end
        if n ~= want[path] then
            error(string.format('%s: %d SetQueuePtToINT call sites, expected %d',
                path, n, want[path]), 0)
        end
        total = total + n
    end
    if total ~= 19 then
        error('focus-five SetQueuePtToINT call sites total ' .. total
            .. ', expected 19', 0)
    end
end

tests['3.5 morphling reads the same value with the OPPOSITE convention'] = function()
    -- Not a focus hero and not this group's to fix, but it is the cleanest
    -- statement of the disagreement: the same call, credited straight to
    -- nAddedAGI with no swap. Whichever hypothesis is true, this site and the
    -- three swapping ones cannot both be right.
    local src = read_file(MORPHLING)
    if not src:find('treadsState == ATTRIBUTE_AGILITY', 1, true) then
        error(MORPHLING .. ' no longer credits AGI off the raw read;'
            .. ' the two-convention claim needs re-measuring', 0)
    end
    if src:find('ATTRIBUTE_INTELLECT') then
        error(MORPHLING .. ' grew an INT branch -- re-read the convention claim', 0)
    end
end

----------------------------------------------------------------------
-- Section 4 -- the declared limits, asserted rather than promised
----------------------------------------------------------------------

tests['4.1 L1: only the DISTINCTNESS of the three mock constants is used'] = function()
    if STR == AGI or AGI == INT or STR == INT then
        error('mock ATTRIBUTE_* constants are not distinct -- every reading in'
            .. ' this file collapses (GH #177 shape)', 0)
    end
end

tests['4.2 L2: an unstubbed handle answers 0, which is none of the three'] = function()
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_lion') })
    local bare = api.MakeAbility('item_power_treads', { IsFullyCastable = true })
    local v = bare:GetPowerTreadsStat()
    if v ~= 0 then
        error('mock default for GetPowerTreadsStat is now ' .. tostring(v)
            .. '; GH #133 (270/270 real handles read 0) needs re-reading', 0)
    end
    if v == STR or v == AGI or v == INT then
        error('0 now equals an ATTRIBUTE_* constant', 0)
    end
end

tests['4.3 L2 again: with the default handle the family presses from nowhere'] = function()
    -- Why no fixture can settle this: on a real dumped frame the stat reads 0,
    -- which matches neither branch of the switcher, so the offline run takes
    -- the fall-through and queues nothing. A green fixture here would mean
    -- "the mock does not know", never "the treads were fine".
    if presses_from(0) ~= 0 then
        error('a 0-stat handle now presses; L2 needs restating', 0)
    end
end

return tests
