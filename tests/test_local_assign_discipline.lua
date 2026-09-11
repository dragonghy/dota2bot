-- [hero] A `local` declaration whose `=` was dropped is silent in every tool
-- this repo runs.  Assert the absence of the shape, over the whole tree.
--
-- WHY THIS FILE EXISTS.  GH #714 (found by the strategy group while sweeping
-- for something else) named two lines in `bots/BotLib/hero_arc_warden.lua`:
--
--     local nEnemyBarracks bot:GetNearbyBarracks(888, true)
--     local sEnemyTowers bot:GetNearbyFillers(888, true)
--
-- Lua does not reject that.  It reads it as TWO statements -- a declaration
-- (`nEnemyBarracks = nil`) and an independent call whose return value is
-- discarded -- so:
--   * it loads, and `tests/test_smoke_load.lua` is green on it;
--   * `luacheck` is green on it, because the names really are used further
--     down, so neither "unused variable" nor "undefined variable" fires;
--   * the engine query still runs on every frame, at full cost, answering
--     into nothing;
--   * and the two disjuncts that read those names were `nil ~= nil` -- FALSE
--     on every frame since the line was typed.
-- Nothing in the repo says a word.  The defect's entire signature is a branch
-- that is quieter than its source reads, which is exactly the signature this
-- group has spent rounds buying frames to see.
--
-- WHAT THE SWEEP FOUND, and why that is the interesting half: over 17,548
-- `local` declarations in `bots/` and `game/`, the class has TWO members, and
-- both are the pair GH #714 already named.  So this file is not maintenance on
-- a known bug -- it closes the class, and then stands guard on it, because the
-- cost of the next instance is not "one wrong branch" but "one wrong branch
-- that no tool in the push path will mention".
--
-- ⛔ WHAT THIS FILE DELIBERATELY IS NOT: a census that pins the sites it found.
-- That is the GH #624 shape -- `== 33` style assertions that any group reddens
-- by adding a line -- and three of the gate's known-red files are red for
-- exactly that reason today, two of them this group's.  Every assertion below
-- is either a property of EVERY declaration the scanner finds, or a
-- direction-safe floor (`>=`, never `==`).  A thousand new correct `local`
-- lines land green; one dropped `=` is red in its own author's pre-push, and
-- the message names the file, the line, and the text.
--
-- ⚠️ WHAT IT CANNOT SEE, so a green is not read as more than it is:
--   * It is a TEXT scanner, not a parser.  It tracks `--[[ ]]` block comments
--     and `[[ ]]` long strings well enough not to accuse their contents, and
--     section 2 proves on synthetic input that it still ACCUSES the real
--     shape -- a scanner that quietly stopped matching would be green and
--     worthless, which is the failure mode a sibling file in this directory
--     learned from a live mutant.
--   * It says nothing about whether an assignment that IS present assigns the
--     right thing.  Only the dropped `=` is in scope.

package.path = 'tests/?.lua;' .. package.path

local ROOTS = { 'bots', 'game' }

--- A trailing remainder that legally follows a `local` name list.
--- `,` covers a name list continued on the next physical line; `<` covers a
--- 5.4 attrib (none in this tree, and the Dota VM is 5.1, but accepting it
--- costs nothing and keeps a false accusation impossible if one ever lands).
local function remainder_is_legal(rest)
    if rest == '' then return true end
    local c = rest:sub(1, 1)
    if c == '=' or c == ',' or c == ';' or c == '<' then return true end
    if rest:sub(1, 2) == '--' then return true end
    return false
end

--- Classify one physical line.
--- @return nil when the line is not a `local` declaration or is fine,
---         the offending text when the `=` was dropped.
local function offence_on_line(line)
    local body = line:match('^%s*local%s+(.*)$')
    if body == nil then return nil end
    if body:match('^function%f[%A]') then return nil end

    -- Walk the comma-separated name list by hand; Lua patterns cannot express
    -- "one or more of X separated by commas" and still hand back the tail.
    local rest = body
    while true do
        local name, tail = rest:match('^([A-Za-z_][%w_]*)%s*(.*)$')
        if name == nil then
            -- `local` followed by something that is not a name at all.  Not the
            -- shape this file is about; leave it to the parser.
            return nil
        end
        if tail:sub(1, 1) == ',' then
            rest = tail:sub(2):match('^%s*(.*)$')
        else
            if remainder_is_legal(tail) then return nil end
            return line:match('^%s*(.-)%s*$')
        end
    end
end

--- Scan a source body, skipping block comments and long strings.
--- @return array of { line = <n>, text = <string> }
local function offences_in(body)
    local out = {}
    local inLong = nil            -- the closer we are looking for, or nil
    local n = 0
    for line in (body .. '\n'):gmatch('(.-)\n') do
        n = n + 1
        if inLong ~= nil then
            if line:find(inLong, 1, true) then inLong = nil end
        else
            -- Does an unterminated long bracket OPEN on this line?  Only the
            -- last one matters, and only if it does not close on the same line.
            local eq = line:match('%[(=*)%[[^%]]*$')
            if eq ~= nil then inLong = ']' .. eq .. ']' end
            local text = offence_on_line(line)
            if text ~= nil then out[#out + 1] = { line = n, text = text } end
        end
    end
    return out
end

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local b = fh:read('*a')
    fh:close()
    return b
end

local function lua_files()
    local t = {}
    for _, root in ipairs(ROOTS) do
        -- The farm-only clause: `bots/Customize/soak_*.lua` is gitignored and
        -- exists only on a batch instance, so it is not shipped source and a
        -- declaration census must not count it.  The literal lives in
        -- tests/lua_source_scan.lua (tests/test_bots_walk_farm_only.py).
        local p = assert(io.popen("find " .. root .. " -name '*.lua' -type f "
            .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. " 2>/dev/null"))
        for l in p:lines() do t[#t + 1] = l end
        p:close()
    end
    table.sort(t)
    return t
end

--- Count `local` declarations, so a scanner that stopped seeing them cannot
--- pass by seeing nothing.
local function declaration_count(body)
    local c = 0
    for line in (body .. '\n'):gmatch('(.-)\n') do
        if line:match('^%s*local%s+') and not line:match('^%s*local%s+function%f[%A]') then
            c = c + 1
        end
    end
    return c
end

local tests = {}

tests['[1] every `local` in bots/ and game/ actually assigns'] = function()
    local files = lua_files()
    assert(#files >= 200, string.format(
        'only %d Lua file(s) found under %s -- the enumerator stopped working, '
        .. 'and a green from a scanner that scanned nothing is not a green.',
        #files, table.concat(ROOTS, '/ ')))

    local nDecl, bad = 0, {}
    for _, path in ipairs(files) do
        local body = read_file(path)
        nDecl = nDecl + declaration_count(body)
        for _, o in ipairs(offences_in(body)) do
            bad[#bad + 1] = string.format('%s:%d: %s', path, o.line, o.text)
        end
    end

    -- Direction-safe floor, never `==`: the tree grows, and growth must not be
    -- a failure.  It only has to prove the scanner is still reaching the code.
    assert(nDecl >= 15000, string.format(
        'only %d `local` declaration(s) reached; there were 17548 when this was '
        .. 'written.  Either the tree shrank by thousands of lines or the '
        .. 'scanner stopped matching -- say which in the round report.', nDecl))

    assert(#bad == 0, string.format(
        '%d `local` declaration(s) dropped their `=`, so the name is nil forever '
        .. 'and the call on the same line answers into nothing.  Nothing else in '
        .. 'the push path will tell you: it loads, luacheck is green, and the '
        .. 'smoke test is green (GH #714).\n  %s',
        #bad, table.concat(bad, '\n  ')))
end

tests['[2] the scanner still accuses the shape it exists to accuse'] = function()
    -- A detector is only worth its green if it is red on the defect.  The
    -- sibling file in this directory found out the hard way that a detector can
    -- stop seeing a site at the exact moment the site becomes defective, so
    -- this runs the real classifier over input carrying the real shape.
    local MUST_ACCUSE = {
        'local nEnemyBarracks bot:GetNearbyBarracks(888, true)',
        '\t\tlocal sEnemyTowers bot:GetNearbyFillers(888, true)',
        'local x f(1)',
        'local a, b g(x):h()',
        'local hTarget J.GetProperTarget(bot)',
        'local n other = 3',        -- `local n` + an assignment to a live global
    }
    for _, line in ipairs(MUST_ACCUSE) do
        assert(offence_on_line(line) ~= nil,
            'the classifier did not accuse a dropped `=`: ' .. line)
    end

    local MUST_NOT_ACCUSE = {
        'local nEnemyBarracks = bot:GetNearbyBarracks(888, true)',
        'local function ClosestCamp(hBot, tCamps)',
        'local a, b = 1, 2',
        'local a,',                      -- name list continued on the next line
        '    local X = {}',
        'local t = {} -- local y f()',   -- the shape inside a trailing comment
        'local bot',                     -- a bare forward declaration
        'local J = require( GetScriptDirectory()..\'/FunLib/jmz_func\' )',
        'locally_named_thing(1)',        -- `local` must be a whole word
        'local -- a comment right after the keyword is not our business',
    }
    for _, line in ipairs(MUST_NOT_ACCUSE) do
        assert(offence_on_line(line) == nil,
            'the classifier falsely accused a legal line: ' .. line
            .. ' -> ' .. tostring(offence_on_line(line)))
    end

    -- And the block-comment / long-string skip must not swallow real code that
    -- follows the close on a later line.
    local body = table.concat({
        '--[[',
        'local swallowed bot:Foo()',
        ']]',
        'local real bot:Bar()',
    }, '\n')
    local got = offences_in(body)
    assert(#got == 1, string.format(
        'expected the commented-out shape to be skipped and the live one kept, '
        .. 'got %d offence(s)', #got))
    assert(got[1].line == 4, 'reported line ' .. got[1].line .. ', expected 4')
end

tests['[3] the GH #714 restoration rides gated, and only the new half does'] = function()
    local body = read_file('bots/BotLib/hero_arc_warden.lua')

    -- The assignment itself is unconditional: restoring `=` is what makes the
    -- name readable at all, and a gate cannot sit on a declaration.
    for _, name in ipairs({ 'nEnemyBarracks', 'sEnemyTowers' }) do
        assert(body:match('local%s+' .. name .. '%s*=%s*bot:GetNearby'),
            name .. ' is not assigned with `=` in X.ConsiderMagneticField; '
            .. 'GH #714 is back.')
    end

    -- The WIDENING is what ships dark.  Both restored disjuncts must be behind
    -- the candidate, and the two that shipped live must not have acquired it --
    -- a gate that crept onto the creep/tower disjuncts would turn a bug fix
    -- into a silent behaviour REMOVAL in every real game.
    local gated, plain = 0, 0
    for line in (body .. '\n'):gmatch('(.-)\n') do
        if line:match('^%s*or%s*%(') and line:match('#%w+%s*>=%s*%d') then
            if line:match('bStructuresCount') then
                gated = gated + 1
            elseif line:match('nEnemyBarracks') or line:match('sEnemyTowers') then
                plain = plain + 1
            end
        end
    end
    assert(gated == 2, string.format(
        'expected both restored disjuncts to be gated behind bStructuresCount, '
        .. 'saw %d', gated))
    assert(plain == 0, string.format(
        '%d restored disjunct(s) read the structure lists WITHOUT the gate, so '
        .. 'the widening is live in real games', plain))

    assert(body:match("J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%(%s*'awraxfield'%s*%)"),
        "the 'awraxfield' gate is not turbo-only; every behaviour candidate in "
        .. 'this repo is.')
end

return tests
