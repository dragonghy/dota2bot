-- [hero] A Glyph veto asked of ONE member of the set the action will hit.
--
-- WHY THIS FILE EXISTS.  `modifier_fountain_glyph` makes a unit invulnerable,
-- so ~90 sites under bots/ refuse an action when their target carries it.  Most
-- of those are correct: the site has ONE target and asks about THAT target.  A
-- subclass is not: the site is about to hit a SET, and it interrogates
-- `<list>[1]`.  Three of them are this stream's focus heroes and all three act
-- on something other than `[1]`:
--
--   hero_axe.lua  X.ConsiderQ  -- Berserker's Call is a NO-TARGET taunt over
--       `radius`; the branch enters at `#laneCreepList >= 4` and every one of
--       those creeps is affected.
--   hero_lion.lua X.ConsiderQ  -- acts on a `bot:FindAoELocation(...)` point
--       computed AFTER the veto; enters at `#laneCreepList >= 5`.
--   hero_lion.lua X.ConsiderR  -- the sharpest: it vetoes on `[1]` and then
--       rescans the whole list for `nBestCreep` by AoE count, so the unit the
--       veto interrogated is provably not the unit it acts on.
--
-- This is the `anyhero`/`lvlany`/`zusjumpany` family (GH #724 / #731 / #741) in
-- its UNIVERSAL direction.  As in GH #731 the list is correctly ordered --
-- `GetNearbyLaneCreeps` is distance sorted -- so SORTING CANNOT FIX IT.  Worse,
-- distance order is adversarial here: Glyph fortifies the units alive at cast
-- time for 5s, so a ring spans two waves exactly when a NEWCOMER has closed on
-- the bot, and the newcomer is the one `[1]` names.
--
-- The fix is `J.IsGlyphVetoClear` in bots/FunLib/jmz_func.lua, gated behind the
-- turbo-only soak candidate 'glyphany'.  Gate off it is the shipped `[1]` call
-- byte for byte; armed it quantifies over the list.  Armed is a pure
-- NARROWING: `not any(P)` implies `not P([1])`, so it can only withdraw a cast,
-- never add one.
--
-- ⛔ WHAT THIS FILE DELIBERATELY IS NOT: a census that pins the sites it found.
-- That is the GH #624 shape -- `== 33` assertions that any group reddens by
-- adding a line -- and it is why three of the push gate's known-red files are
-- red today, two of them this group's.  Every assertion below is either a
-- property of EVERY site the scanner finds, or a direction-safe bound (`>=`,
-- never `==`), or a number that IS ITSELF THE CONCLUSION (section 3's two
-- meter zeroes, which are the claim and not a sample size).
--
-- ⚠️ WHAT IT CANNOT SEE.  It is a text scanner, not a parser: it recognises the
-- literal `<name>[1]:HasModifier( 'modifier_fountain_glyph' )` shape.  A site
-- that hid the same defect behind a local alias would pass.  Section 2 proves
-- on synthetic input that the classifier still ACCUSES the real shape, because
-- a scanner that quietly stopped matching is green and worthless -- the failure
-- mode a sibling file in this directory learned from a live mutant.

package.path = 'tests/?.lua;' .. package.path

local GLYPH = 'modifier_fountain_glyph'

--- The three focus-hero sites this stream owns and has routed through the gate.
local OWNED = {
    'bots/BotLib/hero_axe.lua',
    'bots/BotLib/hero_lion.lua',
}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local b = fh:read('*a')
    fh:close()
    return b
end

local function lua_files(root)
    local t = {}
    local p = assert(io.popen("find " .. root .. " -name '*.lua' -type f 2>/dev/null"))
    for l in p:lines() do t[#t + 1] = l end
    p:close()
    table.sort(t)
    return t
end

--- Does this line ask the Glyph question of `<something>[1]`?
--- @return the receiver text when it does, nil otherwise.
local function subscripted_receiver(line)
    if line:match('^%s*%-%-') then return nil end        -- a commented-out site
    if not line:find(GLYPH, 1, true) then return nil end
    -- `name[1]:HasModifier` -- the whole point is the literal `[1]`.
    local recv = line:match('([%w_%.]+%s*%[%s*1%s*%])%s*:%s*HasModifier')
    if recv == nil then return nil end
    return (recv:gsub('%s+', ''))
end

--- Every Glyph mention, subscripted or not, so a scanner that stopped seeing
--- the idiom cannot pass by seeing nothing.
local function glyph_mentions(body)
    local n = 0
    for line in (body .. '\n'):gmatch('(.-)\n') do
        if not line:match('^%s*%-%-') and line:find(GLYPH, 1, true) then n = n + 1 end
    end
    return n
end

local function scan(root)
    local sites, mentions, nFiles = {}, 0, 0
    for _, path in ipairs(lua_files(root)) do
        nFiles = nFiles + 1
        local body = read_file(path)
        mentions = mentions + glyph_mentions(body)
        local n = 0
        for line in (body .. '\n'):gmatch('(.-)\n') do
            n = n + 1
            local recv = subscripted_receiver(line)
            if recv ~= nil then
                sites[#sites + 1] = { file = path, line = n, recv = recv }
            end
        end
    end
    return sites, mentions, nFiles
end

local tests = {}

tests['[1] the subscripted-Glyph subclass exists, is bounded below, and none of it is ours'] = function()
    local sites, mentions, nFiles = scan('bots')

    -- Direction-safe floors, never `==`: the tree grows and growth must not be
    -- a failure.  They only prove the scanner is still reaching the code.
    assert(nFiles >= 200, string.format(
        'only %d Lua file(s) under bots/ -- the enumerator stopped working, and '
        .. 'a green from a scanner that scanned nothing is not a green.', nFiles))
    assert(mentions >= 70, string.format(
        'only %d live mention(s) of %s reached; there were 92 when this was '
        .. 'written.  Either the idiom was swept tree-wide or the scanner '
        .. 'stopped matching -- say which in the round report.', mentions, GLYPH))

    -- The class itself is a LOWER bound: other groups own their sites and this
    -- file does not conscript them.  It exists so the class stays visible.
    assert(#sites >= 1, string.format(
        'the subscripted-[1] Glyph subclass reads as EMPTY (%d mention(s) '
        .. 'scanned).  It had 19 members outside this stream when this was '
        .. 'written; an empty read means the classifier stopped matching, not '
        .. 'that the class closed.', mentions))

    -- The property that IS ours, and it is universal, not a count: no file this
    -- stream owns may carry the shape.  A regression in hero_axe/hero_lion is
    -- red here by name, and a NEW focus-hero site is red the day it lands.
    local ours = {}
    for _, s in ipairs(sites) do
        for _, owned in ipairs(OWNED) do
            if s.file == owned then
                ours[#ours + 1] = string.format('%s:%d: %s', s.file, s.line, s.recv)
            end
        end
    end
    assert(#ours == 0, string.format(
        '%d focus-hero site(s) still ask the Glyph veto of one member of the set '
        .. 'the action hits.  Route them through J.IsGlyphVetoClear.\n  %s',
        #ours, table.concat(ours, '\n  ')))
end

tests['[2] the classifier still accuses the shape it exists to accuse'] = function()
    local MUST_ACCUSE = {
        'and not laneCreepList[1]:HasModifier( "modifier_fountain_glyph" )',
        "\t\t\tand not nEnemyCreepList[1]:HasModifier( 'modifier_fountain_glyph' )",
        'if nAllyTowers[1]:HasModifier(\'modifier_fountain_glyph\') then',
        'and not runModeBarracks[ 1 ]:HasModifier("modifier_fountain_glyph")',
    }
    for _, line in ipairs(MUST_ACCUSE) do
        assert(subscripted_receiver(line) ~= nil,
            'the classifier did not accuse a subscripted Glyph veto: ' .. line)
    end

    local MUST_NOT_ACCUSE = {
        -- The single-target majority: the receiver IS the acted-on unit.
        'and not creep:HasModifier( "modifier_fountain_glyph" )',
        'and not targetCreep:HasModifier( "modifier_fountain_glyph" )',
        'and not botTarget:HasModifier( "modifier_fountain_glyph" )',
        -- Someone else's index is not this defect.
        'and not laneCreepList[2]:HasModifier( "modifier_fountain_glyph" )',
        'and not laneCreepList[i]:HasModifier( "modifier_fountain_glyph" )',
        -- A different modifier entirely.
        'and not nCreeps[1]:HasModifier( "modifier_invulnerable" )',
        -- Already commented out (hero_invoker.lua carries one).
        '    --             and not laneCreepList[1]:HasModifier( "modifier_fountain_glyph" )',
    }
    for _, line in ipairs(MUST_NOT_ACCUSE) do
        assert(subscripted_receiver(line) == nil,
            'the classifier falsely accused a line: ' .. line
            .. ' -> ' .. tostring(subscripted_receiver(line)))
    end
end

tests['[3] the offline domain is zero for METER reasons, and both are pinned'] = function()
    -- These two numbers are not sample sizes, they ARE the conclusion, which is
    -- the one case the no-`==`-census rule exempts.  Each says "this meter
    -- cannot answer"; either one growing must be read as the meter changing,
    -- never as the lever's domain changing.
    local RF = require('mock.replay_fixture')

    local files = {}
    for _, dir in ipairs({ 'tests/frames', 'tests/fixtures' }) do
        for _, f in ipairs(lua_files(dir)) do files[#files + 1] = f end
    end
    assert(#files >= 100, string.format(
        'only %d frozen frame file(s) found; there were 141.  The corpus '
        .. 'enumerator stopped working.', #files))

    -- (3a) GetNearbyLaneCreeps is on no spec in tests/mock/replay_fixture.lua,
    -- so it answers the empty table on every subject -- including the files
    -- that DO carry a creeps sample.  Both legs of the helper are therefore
    -- silent, and silent identically.
    local nDriven, nWithCreeps, nSampled = 0, 0, 0
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            if type(fx.creeps) == 'table' and #fx.creeps > 0 then
                nSampled = nSampled + 1
            end
            for _, u in ipairs(fx.units) do
                if type(u.name) == 'string' and u.name:match('^npc_dota_hero_')
                    and u.alive then
                    local ok2, bot = pcall(RF.load, path, u.name)
                    if ok2 and bot ~= nil then
                        nDriven = nDriven + 1
                        local okc, lst = pcall(function()
                            return bot:GetNearbyLaneCreeps(1300, true)
                        end)
                        if okc and type(lst) == 'table' and #lst > 0 then
                            nWithCreeps = nWithCreeps + 1
                        end
                    end
                    break
                end
            end
        end
    end

    assert(nDriven >= 100, string.format(
        'only %d subject(s) could be driven out of %d file(s); the loader '
        .. 'stopped loading and the zero below would be its zero, not the '
        .. "meter's.", nDriven, #files))
    assert(nSampled >= 20, string.format(
        'only %d frame file(s) carry a creeps sample; there were 32.  The '
        .. 'sample is what makes (3a) a statement about the GETTER rather than '
        .. 'about the corpus.', nSampled))
    assert(nWithCreeps == 0, string.format(
        'GetNearbyLaneCreeps now answers a non-empty list on %d of %d driven '
        .. "subject(s).  That is the meter growing, NOT the lever's domain "
        .. 'appearing: re-size glyphany against the new reading and update the '
        .. 'header of J.IsGlyphVetoClear before quoting any number from it.',
        nWithCreeps, nDriven))

    -- (3b) And repairing (3a) alone would not be enough: a creep sample entry
    -- carries { team, x, y, dt } -- no name, no health, NO MODIFIER LIST -- so
    -- the Glyph predicate has nothing to read.  Without this half, a getter
    -- repair would turn an honest "cannot see" into a confident, wrong "no
    -- creep is ever fortified".
    local nEntries, nWithModifiers = 0, 0
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.creeps) == 'table' then
            for _, c in ipairs(fx.creeps) do
                nEntries = nEntries + 1
                if c.modifiers ~= nil then nWithModifiers = nWithModifiers + 1 end
            end
        end
    end
    assert(nEntries >= 100, string.format(
        'only %d creep sample entr(ies) across the corpus; the sample reader '
        .. 'stopped reading, so the zero below is its zero.', nEntries))
    assert(nWithModifiers == 0, string.format(
        '%d of %d creep sample entr(ies) now carry a modifier list.  The '
        .. 'dumper grew a field: glyphany is measurable offline now -- go size '
        .. 'it instead of quoting this pin.', nWithModifiers, nEntries))
end

tests['[4] the gate is turbo-only, names exactly one id, and off is the shipped call'] = function()
    local body = read_file('bots/FunLib/jmz_func.lua')

    local fn = body:match('function J%.IsGlyphVetoClear%b()(.-)\nend\n')
    assert(fn ~= nil, 'J.IsGlyphVetoClear is gone from bots/FunLib/jmz_func.lua')

    assert(fn:match("J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%(%s*'glyphany'%s*%)"),
        "the 'glyphany' gate is not the turbo-only conjunction every behaviour "
        .. 'candidate in this repo carries.')

    -- The pullcad trap: a gate that names a sibling id freezes FALSE the day
    -- the sibling is promoted, and check_armed_wiring.py still calls it WIRED.
    local nIds = 0
    for _ in fn:gmatch('IsSoakCandidate%(') do nIds = nIds + 1 end
    assert(nIds == 1, string.format(
        'J.IsGlyphVetoClear names %d soak ids; it must name exactly one '
        .. '(the pullcad trap).', nIds))

    -- Gate off must be the shipped predicate, not a re-derivation of it.
    assert(fn:match("return not tUnits%[1%]:HasModifier%(%s*'" .. GLYPH .. "'%s*%)"),
        'the gate-off leg is no longer the shipped `[1]` call byte for byte; a '
        .. 'candidate that changes behaviour while unarmed is live in real '
        .. 'games, which is the one thing a gate exists to prevent.')

    -- Armed must quantify over the WHOLE list.  Anything that still indexes is
    -- the defect wearing the fix's name.
    local armed = fn:match('IsSoakCandidate.-\n(.-)\n%s*return not tUnits%[1%]')
    assert(armed ~= nil and armed:match('for%s+_,%s*unit%s+in%s+pairs%(%s*tUnits%s*%)'),
        'the armed leg does not iterate tUnits; a universal question is still '
        .. 'being asked of one member.')
    assert(not armed:match('tUnits%[%s*1%s*%]'),
        'the armed leg still subscripts tUnits[1].')

    -- And the callers are exactly the three focus-hero sites.  A fourth caller
    -- widens the gate silently, in a file this stream did not read.
    local callers = {}
    for _, root in ipairs({ 'bots' }) do
        for _, path in ipairs(lua_files(root)) do
            if path ~= 'bots/FunLib/jmz_func.lua' then
                local n = 0
                for line in (read_file(path) .. '\n'):gmatch('(.-)\n') do
                    n = n + 1
                    if not line:match('^%s*%-%-') then
                        -- Count OCCURRENCES, not lines.  Counting lines let a
                        -- live mutant through on this file's own mutation
                        -- stand: two calls on one line read as one caller.
                        local at = 1
                        while true do
                            local i = line:find('J.IsGlyphVetoClear', at, true)
                            if i == nil then break end
                            callers[#callers + 1] = path .. ':' .. n
                            at = i + 1
                        end
                    end
                end
            end
        end
    end
    table.sort(callers)
    assert(#callers == 3, string.format(
        'J.IsGlyphVetoClear has %d call site(s); the candidate was sized on '
        .. "exactly 3 (Axe Q, Lion Q, Lion R).  A new caller is not covered by "
        .. "this stream's reading of the branch it sits in.\n  %s",
        #callers, table.concat(callers, '\n  ')))
    for _, c in ipairs(callers) do
        assert(c:match('^bots/BotLib/hero_axe%.lua:') or c:match('^bots/BotLib/hero_lion%.lua:'),
            'J.IsGlyphVetoClear is called from outside the focus heroes: ' .. c)
    end
end

return tests
