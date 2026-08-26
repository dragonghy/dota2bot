-- [hero] `TALENTNAME`: the by-NAME half of the talent-binding axis.  GH #223,
-- the lead GH #214 left named but uncounted.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- There are two ways to get a talent handle in this tree, and they break in
-- opposite directions:
--
--   * BY INDEX -- `bot:GetAbilityByName( sTalentList[N] )`.  Survives a rename,
--     breaks on a REORDER; the handle quietly starts naming a different talent
--     and `IsTrained()` answers about that one.  That half is pinned by
--     GH #166 / #214 (tests/mock/talent_slots.lua).
--   * BY LITERAL NAME -- `bot:GetAbilityByName('special_bonus_unique_doom_2')`.
--     Survives a reorder, breaks on a RENAME or a REMOVAL -- and it breaks
--     harder.  `GetAbilityByName` answers **nil** for a talent the hero does
--     not carry, and the very next thing seven of the eight sites in this tree
--     do is call a method on the handle.  `nil:IsTrained()` reaches the engine's
--     broken error handler ("error in error handling" masks the text,
--     AGENTS.md), so Think() stops part-way through the frame and NOTHING is
--     printed anywhere.  There is no counter for it and no log line.
--
-- The measurement (tools/agent/talent_name_binding_census.py, read off the
-- game's own npc_heroes.txt -- the source GH #214 moved to after odota's
-- display list was found a patch behind): 8 literal-name bindings in the tree,
-- 7 names still in their hero's talent run, ONE gone --
-- `hero_doom_bringer.lua`'s `special_bonus_unique_doom_2`.  Doom's shipped
-- ancient-devour predicate this patch is `special_bonus_shard`
-- (`doom_bringer_devour/can_target_ancient` is a shard override key, not a
-- talent one), so the talent did not move, it stopped existing for him.
--
-- ⭐ THE PART THAT MAKES IT A LIVE CRASH RATHER THAN A DEAD READ.  A nil
-- handle only costs something if the call is reached.  It is: the call sits
-- under `nCreepTarget:IsAncientCreep()`, and `nCreepTarget` comes from
-- `J.GetMostHpUnitAnyTier` -- the tier-BLIND selector, whose one and only
-- caller in the whole tree is this devour path (jmz_func.lua), kept blind on
-- purpose by GH #196 so that ancients WOULD reach this comparison.  So the
-- opt-out written to preserve three branches was feeding the first of them a
-- nil dereference.  The census is what turns "an ancient might be nearby" into
-- "the selector is aimed at ancients by design".
--
-- WHAT THIS FILE ASSERTS, AND WHAT IT LEAVES TO THE CENSUS
-- --------------------------------------------------------
-- The census owns the question "does the game still give this hero a talent by
-- this name" -- it needs the network, so it cannot live here.  This file owns
-- the question "is the tree still the shape the census was run against", which
-- needs no network and therefore runs in the standing gate:
--
--   1  the snapshot is well-formed and still describes eight sites;
--   2  the set of literal-name bindings IN THE TREE equals the snapshot's set
--      -- a new one, or a deleted one, is red and says to re-run the census;
--   3  every site the snapshot records as ABSENT is nil-tested at every call;
--   4  the judge used by 3 is driven both ways on synthetic input, so a green
--      3 cannot mean "the judge says yes to everything".
--
-- Section 3 deliberately does NOT extend to the seven PRESENT sites, six of
-- which are also unguarded.  Those are not defects today (the handle exists);
-- they are the same latent shape, and widening a ratchet past the measurement
-- that justifies it is how a gate turns into noise.  They are recorded in the
-- snapshot and named in GH #223 for whoever claims them.
--
-- LIMITS
--   * The scanner here is line-based, like the census's.  A binding split
--     across lines is invisible to both; none in this tree is.
--   * "nil-tested" means the test is in the SAME conjunction -- this line, or
--     the line above when this line continues it.  Conservative on purpose: it
--     can call a correctly guarded call unguarded (visible, arguable); it must
--     never call an unguarded one guarded.  Section 4 drives both directions,
--     including the two shapes the census's first draft got backwards.
--   * Nothing here proves what a PRESENT talent modifies.  That is the
--     snapshot's `mods` column, and an empty `mods` proves nothing at all --
--     generic rows live in npc_abilities.txt, which the census does not read.

local SNAPSHOT_LUA = 'tests/mock/talent_name_bindings.lua'
local CENSUS_PY    = 'tools/agent/talent_name_binding_census.py'

local SITES = dofile(SNAPSHOT_LUA)

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local sText = fh:read('*a')
    fh:close()
    return sText
end

-- Blank out Lua comments, keeping line NUMBERS and column positions, so a
-- reported line is the line a reader opens.  Mirrors the census's
-- strip_comments (block form first, then line form) because section 2 compares
-- the two scanners' answers by construction: if they drifted, the site sets
-- would stop matching and this file would go red rather than quietly agree.
--
-- This is not hygiene.  hero_doom_bringer.lua carries a COMMENTED-OUT copy of
-- the bearing call site a few dozen lines above the live one; a scanner that
-- reads prose reports a call that cannot run -- the mirror image of the
-- mistake GH #136's first buy-list census made, which counted a quoted item
-- name in a rationale block as a purchase.
local function strip_comments(sText)
    local tOut, bInBlock = {}, false
    for sLine in (sText .. '\n'):gmatch('([^\n]*)\n') do
        if bInBlock then
            local nEnd = sLine:find(']]', 1, true)
            if nEnd == nil then
                tOut[#tOut + 1] = ''
                sLine = nil
            else
                sLine = string.rep(' ', nEnd + 1) .. sLine:sub(nEnd + 2)
                bInBlock = false
            end
        end
        if sLine ~= nil then
            local nStart = sLine:find('--[[', 1, true)
            if nStart ~= nil then
                local nEnd = sLine:find(']]', nStart, true)
                if nEnd == nil then
                    tOut[#tOut + 1] = sLine:sub(1, nStart - 1)
                    bInBlock = true
                    sLine = nil
                else
                    sLine = sLine:sub(1, nStart - 1)
                        .. string.rep(' ', nEnd + 2 - nStart)
                        .. sLine:sub(nEnd + 2)
                end
            end
            if sLine ~= nil then
                local nCut = sLine:find('--', 1, true)
                if nCut ~= nil then sLine = sLine:sub(1, nCut - 1) end
                tOut[#tOut + 1] = sLine
            end
        end
    end
    return tOut
end

local function lua_files()
    local tPaths = {}
    local p = assert(io.popen("find bots -name '*.lua' | sort"))
    for sPath in p:lines() do tPaths[#tPaths + 1] = sPath end
    p:close()
    assert(#tPaths > 100,
        'found only ' .. #tPaths .. ' lua files under bots/ -- the scan input '
        .. 'collapsed, so every set comparison below would pass vacuously')
    return tPaths
end

-- `local Foo = bot:GetAbilityByName('special_bonus_x')` and the bare
-- assignment form (silencer binds inside a function).
local function find_bindings(tLines)
    local tFound = {}
    for n, sLine in ipairs(tLines) do
        for sVar, sTalent in sLine:gmatch(
            "([%a_][%w_]*)%s*=%s*[%a_][%w_]*%s*:%s*GetAbilityByName%s*%(%s*['\"](special_bonus_[%w_]+)['\"]%s*%)")
        do
            tFound[#tFound + 1] = { var = sVar, talent = sTalent, line = n }
        end
    end
    return tFound
end

-- The judge section 4 drives both ways.  A method call on `sVar` counts as
-- nil-tested only when the test is in the SAME conjunction: this line, or the
-- line above when this line continues it (the tree's house style breaks an
-- `and` chain across lines).  The narrowness is load-bearing, not tidiness --
-- the census's first draft looked one line up unconditionally, and its own
-- suite caught it laundering `local a = Foo ~= nil and Foo:IsTrained()` into a
-- guard for a bare `Foo:GetLevel()` underneath.  A test that RAN and a test
-- that GUARDS are not the same thing, and this judge is only allowed to err by
-- over-reporting: an over-report prints a line someone can argue with, an
-- under-report calls a live nil dereference safe.
-- Note what is NOT here: `if`, `elseif`, `while`.  Those OPEN a construct, they
-- do not continue one, so a line starting with `if` must carry its own test.
-- Leaving them in cost a second false GUARDED, on the one site in the tree that
-- is genuinely guarded through an intermediate boolean
-- (hero_silencer.lua:747-748): the judge read a completed `local` line above an
-- `if` and called it that condition's guard.
local function continues(sLine)
    return sLine:find('^%s*then%f[%W]') ~= nil
        or sLine:find('^%s*and%f[%W]') ~= nil
        or sLine:find('^%s*or%f[%W]') ~= nil
        or sLine:find('^%s*not%f[%W]') ~= nil
end

local function is_nil_tested(tLines, nIdx, sVar)
    local tWindow = { tLines[nIdx] }
    if nIdx > 1 and continues(tLines[nIdx]) then
        tWindow[#tWindow + 1] = tLines[nIdx - 1]
    end
    for _, sLine in ipairs(tWindow) do
        if sLine:find(sVar .. '%s*~=%s*nil')
        or sLine:find('not%s+' .. sVar .. '%f[%W]')
        or sLine:find(sVar .. '%s+and%f[%W]')
        then
            return true
        end
    end
    return false
end

local function method_calls(tLines, sVar)
    local tCalls = {}
    for n, sLine in ipairs(tLines) do
        if sLine:find(sVar .. '%s*:%s*[%a_]') then
            tCalls[#tCalls + 1] = { line = n, guarded = is_nil_tested(tLines, n, sVar) }
        end
    end
    return tCalls
end

local function site_key(sFile, sVar, sTalent)
    return sFile .. '|' .. sVar .. '|' .. sTalent
end

local tests = {}

tests['1 the snapshot is well-formed and still names eight sites'] = function()
    assert(type(SITES) == 'table' and type(SITES.SITES) == 'table',
        SNAPSHOT_LUA .. ' no longer returns { SITES = {...} }')
    local tRows = SITES.SITES
    assert(#tRows == 8,
        'snapshot records ' .. #tRows .. ' literal-name bindings, expected 8. '
        .. 'If the tree really changed, re-run ' .. CENSUS_PY
        .. ' --snapshot and update this count in the same change -- the number '
        .. 'is here so a site cannot be added or deleted silently.')
    local nAbsent = 0
    for _, tRow in ipairs(tRows) do
        for _, sKey in ipairs({ 'file', 'hero', 'var', 'talent' }) do
            assert(type(tRow[sKey]) == 'string' and tRow[sKey] ~= '',
                'snapshot row missing ' .. sKey)
        end
        assert(type(tRow.present) == 'boolean', 'row has no present flag')
        assert(type(tRow.mods) == 'table', 'row has no mods list')
        if not tRow.present then nAbsent = nAbsent + 1 end
    end
    -- Not decoration: if a patch hands every name back, section 3 becomes
    -- vacuous and would still print green.  This is where that shows up.
    assert(nAbsent >= 1,
        'no site is recorded ABSENT any more, so section 3 asserts nothing. '
        .. 'That is good news, but confirm it with ' .. CENSUS_PY
        .. ' and then decide what this file should guard instead of leaving a '
        .. 'green run that measures nothing.')

    -- The FIRST line must still declare the generator.  An assertion that reads
    -- only the generated file cannot tell a stale generator from a stale
    -- snapshot (GH #214); the Python side compares the generator's own header
    -- function against this file, this side only refuses a snapshot that has
    -- stopped saying where it came from.
    --
    -- Pinning the first line rather than searching the whole text is not
    -- pedantry: the header names the script twice (once as provenance, once in
    -- the regenerate recipe), so a substring search stayed green through a
    -- mutation that erased the provenance line outright.
    local sText = read_file(SNAPSHOT_LUA)
    local sFirst = sText:match('^([^\n]*)')
    assert(sFirst == '-- GENERATED by ' .. CENSUS_PY
            .. ' --snapshot -- do not hand-edit.',
        SNAPSHOT_LUA .. ' no longer declares its generator on line 1; got:\n  '
        .. tostring(sFirst))
end

tests['2 the tree contains exactly the snapshot bindings, no more, no fewer'] = function()
    local tSeen, tExtra = {}, {}
    for _, sPath in ipairs(lua_files()) do
        local tLines = strip_comments(read_file(sPath))
        for _, tBind in ipairs(find_bindings(tLines)) do
            local sKey = site_key(sPath, tBind.var, tBind.talent)
            tSeen[sKey] = tBind.line
        end
    end
    local tWanted = {}
    for _, tRow in ipairs(SITES.SITES) do
        tWanted[site_key(tRow.file, tRow.var, tRow.talent)] = true
    end
    for sKey, nLine in pairs(tSeen) do
        if not tWanted[sKey] then
            tExtra[#tExtra + 1] = sKey .. ' (line ' .. nLine .. ')'
        end
    end
    table.sort(tExtra)
    assert(#tExtra == 0,
        'a talent is bound by literal name at a site the census never judged:\n  '
        .. table.concat(tExtra, '\n  ')
        .. '\nRun `python3 ' .. CENSUS_PY .. ' --snapshot` -- it answers whether '
        .. 'the game still gives that hero a talent by that name, which is the '
        .. 'whole hazard. Binding by name is not wrong; binding by a name '
        .. 'nobody checked is.')
    local tMissing = {}
    for sKey in pairs(tWanted) do
        if tSeen[sKey] == nil then tMissing[#tMissing + 1] = sKey end
    end
    table.sort(tMissing)
    assert(#tMissing == 0,
        'the snapshot records bindings that are no longer in the tree:\n  '
        .. table.concat(tMissing, '\n  ')
        .. '\nRe-run the census with --snapshot in the change that removed them.')
end

tests['3 every ABSENT name is nil-tested at every call site'] = function()
    local nChecked, nCalls = 0, 0
    for _, tRow in ipairs(SITES.SITES) do
        if not tRow.present then
            nChecked = nChecked + 1
            local tLines = strip_comments(read_file(tRow.file))
            local tCalls = method_calls(tLines, tRow.var)
            assert(#tCalls > 0,
                tRow.file .. ': `' .. tRow.var .. '` is bound but never called. '
                .. 'That is safe today; if the binding is dead, delete it rather '
                .. 'than leaving a nil handle for the next reader to pick up.')
            for _, tCall in ipairs(tCalls) do
                nCalls = nCalls + 1
                assert(tCall.guarded,
                    tRow.file .. ':' .. tCall.line .. ' calls a method on `'
                    .. tRow.var .. '`, which is bound to `' .. tRow.talent
                    .. '` -- a talent the game does not give ' .. tRow.hero
                    .. ' this patch. The handle is nil, and a method call on nil '
                    .. 'reaches the engine error handler that masks its own text, '
                    .. 'so Think() stops here with nothing logged. Nil-test it in '
                    .. 'the same conjunction (`' .. tRow.var .. ' ~= nil and '
                    .. tRow.var .. ':...`).')
            end
        end
    end
    assert(nChecked >= 1 and nCalls >= 1,
        'section 3 examined ' .. nChecked .. ' site(s) and ' .. nCalls
        .. ' call(s) -- with either at zero it proves nothing')
end

tests['4 the guard judge is driven both ways on synthetic input'] = function()
    -- Section 3 is only worth its green if the judge can say no.  Every line
    -- below is a shape that exists, or nearly exists, in the tree.
    local tUnguarded = {
        { 'and DevourAncientTalent:IsTrained()' },
        { 'if Foo:IsTrained()', 'then' },
        { 'local n = Foo:GetSpecialValueInt(\'value\')' },
        -- the guard is real but two lines up: conservative direction, and the
        -- reason this file says so out loud instead of pretending otherwise
        { 'if Foo ~= nil', 'and bar', 'and Foo:IsTrained()' },
        -- ⭐ the two the census's first draft got WRONG, in the one direction
        -- it is never allowed to be wrong in.  A test that ran, and a block
        -- that already closed, do not guard the statement after them.
        { 'local a = Foo ~= nil and Foo:IsTrained()', 'local b = Foo:GetLevel()' },
        { 'if Foo ~= nil then bar() end', 'local n = Foo:GetLevel()' },
        -- really safe in Lua; refused anyway, because telling it apart from
        -- the closed block above needs flow analysis this judge does not do.
        -- Recorded so the over-report is a decision and not a surprise.
        { 'if not Foo then return end', 'local n = Foo:GetLevel()' },
        -- the shape hero_silencer.lua:747-748 really has: the guard is real
        -- but travels through an intermediate boolean, and an `if` opens its
        -- own condition rather than continuing the line above.
        { 'local b = Foo ~= nil and Foo:IsTrained()',
          'if b then n = Foo:GetSpecialValueInt(\'value\') end' },
    }
    for _, tLines in ipairs(tUnguarded) do
        local nLast = #tLines
        assert(not is_nil_tested(tLines, nLast, 'Foo')
            and not is_nil_tested(tLines, nLast, 'DevourAncientTalent'),
            'the judge accepted an unguarded call: ' .. tLines[nLast])
    end
    local tGuarded = {
        { 'return Foo ~= nil and Foo:IsTrained()' },
        { 'local b = Foo and Foo:IsTrained()' },
        { 'if Foo ~= nil', 'then local n = Foo:GetLevel() end' },
        { 'if Foo ~= nil', 'and Foo:IsTrained()' },
    }
    for _, tLines in ipairs(tGuarded) do
        assert(is_nil_tested(tLines, #tLines, 'Foo'),
            'the judge rejected a guarded call: ' .. tLines[#tLines])
    end
    -- The name match must be whole-word, or `Foo` would be guarded by a test
    -- of `FooBar` sitting next to it.
    assert(not is_nil_tested({ 'if FooBar ~= nil then Foo:IsTrained() end' }, 1, 'Foo'),
        'a nil test of a DIFFERENT variable was accepted as a guard')
end

tests['5 the comment stripper hides prose and keeps line numbers'] = function()
    local tLines = strip_comments(table.concat({
        'local A = bot:GetAbilityByName(\'special_bonus_live\')',
        '-- local B = bot:GetAbilityByName(\'special_bonus_commented\')',
        'local C = 1 --[[ inline ]] + 2',
        '--[[ opening a block',
        'local D = bot:GetAbilityByName(\'special_bonus_blocked\')',
        'closing ]] local E = bot:GetAbilityByName(\'special_bonus_after_block\')',
    }, '\n'))
    assert(#tLines == 6, 'stripper changed the line count to ' .. #tLines
        .. ' -- reported line numbers would no longer be openable')
    local tFound = find_bindings(tLines)
    local tNames = {}
    for _, tBind in ipairs(tFound) do tNames[tBind.talent] = tBind.line end
    assert(tNames['special_bonus_live'] == 1, 'lost the live binding')
    assert(tNames['special_bonus_after_block'] == 6,
        'lost the binding that follows a closed block comment')
    assert(tNames['special_bonus_commented'] == nil,
        'a line-commented binding was counted -- this is the case the tree '
        .. 'really has (hero_doom_bringer.lua carries a commented copy of the '
        .. 'bearing call site)')
    assert(tNames['special_bonus_blocked'] == nil,
        'a binding inside a block comment was counted')
end

return tests
