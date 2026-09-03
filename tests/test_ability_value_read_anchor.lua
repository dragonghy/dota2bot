-- [hero] `ABILVALUE`: the sister shape GH #228 measured on TALENT handles,
-- taken here on ORDINARY ABILITY handles.  GH #228 §6.3 registered it as
-- deliberately excluded and said, in as many words, that not one of the seven
-- had ever been counted.  This file is the standing half of that count.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- An ability's special values are keyed by the ENTRY NAME inside its
-- `AbilityValues` block.  A modern entry is written long-form:
--
--     "avalanche_damage"
--     {
--         "value"                     "90 180 270 360"
--         "special_bonus_unique_tiny" "+90"
--     }
--
-- `value` there is an INNER key of the entry `avalanche_damage`, not an entry
-- of the ability.  So `Avalanche:GetSpecialValueInt('value')` asks for an entry
-- that does not exist and gets the documented silent 0 (BOT_API_REFERENCE: "a
-- typo will silently return 0").  An ability answers `value` only when it
-- literally owns an AbilityValues entry NAMED `value`.  Measured by
-- tools/agent/ability_value_key_census.py against the game's own per-hero KV:
-- eight live sites, seven distinct abilities, and NOT ONE of the seven owns
-- such an entry.
--
-- ⭐ THE PART WORTH KEEPING: THE SIGN IS THE OPPOSITE OF #228's.
-- #228's twenty-one sites all reduced to harmless.  A hero-unique talent's
-- bonus has no second home, so the engine must fold it into the base number the
-- site already read; the dead `+ talent:...('value')` term is dead in the SAFE
-- direction, and repairing it would double-count.  All 21 of 21.
--
-- Nothing folds here.  These sites are not adding a bonus to a number they
-- already have -- the read IS the number, and the number is 0:
--
--   * 5 of 8 UNDER  -- a damage or multiplier of 0 fed straight into
--     `J.CanKillTarget(...)`, so the finisher branch can never fire;
--   * 1 of 8 OVER   -- terrorblade's Demon Zeal health cost read as free, so
--     the post-cast HP guard binds on nothing;
--   * 2 of 8 FOLD   -- the only two of #228's harmless kind.
--
-- ⭐ AND AT THE OVER SITE THE OBVIOUS REPAIR IS WRONG IN A SECOND WAY.  The key
-- it wants is `health_cost_pct`, whose KV value is 20 -- twenty PERCENT, not a
-- fraction -- while the line multiplies by current health directly.  Swapping
-- the key alone turns a cost of 0 into 20x the hero's health and flips the
-- guard from always-true to never-true.  Section 4 pins the annotation that
-- says so, because a claimant who reads only the intended-key column would ship
-- exactly that.
--
-- WHAT THIS FILE ASSERTS, AND WHAT IT LEAVES TO THE CENSUS
-- --------------------------------------------------------
-- The census owns "does this ability own an entry named `value`", which needs
-- the network and cannot live here.  This file owns "is the tree still the
-- shape the census was run against", which needs nothing:
--
--   1  the snapshot is well-formed, non-degenerate, and still describes 8 sites;
--   2  the set of live sites IN THE TREE equals the snapshot's set -- a new one
--      or a deleted one is red and says to re-run the census;
--   3  every snapshot row carries a disposition and, where a key is named, a
--      key that is not `value` (a row whose repair is "read `value`" would be
--      the finding contradicting itself);
--   4  the two sites whose repair is NOT a key swap carry the reason in the
--      shipped source, contiguously, so the next reader cannot take the
--      intended-key column as an instruction;
--   5  the scanner in 2 is driven BOTH ways on synthetic input, so a green 2
--      cannot mean "the scanner finds nothing anywhere".
--
-- LIMITS
--   * CONSISTENCY ratchet, not a correctness one.  Snapshot and tree can be
--     wrong together and stay green; correctness is owned by the source, and
--     the source is the census's KV files.
--   * The scanner is line-based, like the census's.  A binding or a read split
--     across lines is invisible to both; none in this tree is.
--   * `sign` is the census author's reading of the arithmetic downstream of the
--     read, not a measured frequency.  NOBODY HAS COUNTED how often these
--     branches are reached in play -- that needs a corpus, and none of these
--     five heroes is focus-five.  A green run here is not evidence that any of
--     it costs a game.
--   * Nothing here evaluates the engine.  The mock answers 0 for every key on
--     every handle (GH #100/#133/#145/#154 family), so a fixture run cannot
--     distinguish a right key from a wrong one -- which is exactly why this
--     axis is settled from the KV and not from a test.

local SNAPSHOT_LUA = 'tests/mock/ability_value_reads.lua'
local CENSUS_PY    = 'tools/agent/ability_value_key_census.py'

local SNAP = dofile(SNAPSHOT_LUA)

package.path = 'tests/?.lua;' .. package.path

local tests = {}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local sText = fh:read('*a')
    fh:close()
    return sText
end

-- Blank out `--` line comments while keeping the line COUNT, so a reported line
-- is the line a reader opens.  Load-bearing in this file more than most: every
-- one of the eight sites now has a paragraph of annotation directly above it
-- that quotes the very idiom being scanned for.
local function strip_comments(sText)
    local tOut = {}
    for sLine in (sText .. '\n'):gmatch('([^\n]*)\n') do
        local nCut = sLine:find('--', 1, true)
        tOut[#tOut + 1] = (nCut ~= nil) and sLine:sub(1, nCut - 1) or sLine
    end
    return tOut
end

--- Find every `<var>:GetSpecialValue*('value')` whose <var> is bound in the
--- same file to `<x>:GetAbilityByName('<ability>')` -- an ABILITY, not a
--- talent.  Returns { { line = n, var = s, ability = s, nth = n }, ... }.
local function find_sites(tLines)
    local tBind = {}
    for _, sLine in ipairs(tLines) do
        local sVar, sName = sLine:match(
            '([%w_]+)%s*=%s*[%w_]+:GetAbilityByName%(%s*[\'"]([%l%d_]+)[\'"]%s*%)')
        if sVar ~= nil and sName:sub(1, 13) ~= 'special_bonus' then
            tBind[sVar] = sName
        end
    end
    local tOut, tSeen = {}, {}
    for nLine, sLine in ipairs(tLines) do
        for sVar in sLine:gmatch("([%w_]+):GetSpecialValue%a*%(%s*['\"]value['\"]") do
            if tBind[sVar] ~= nil then
                tSeen[sVar] = (tSeen[sVar] or 0) + 1
                tOut[#tOut + 1] = { line = nLine, var = sVar,
                                    ability = tBind[sVar], nth = tSeen[sVar] }
            end
        end
    end
    return tOut
end

-- Farm-only files are skipped: `bots/Customize/` holds two gitignored,
-- TRANSIENT switch files that every gate test in this suite creates and
-- deletes, so listing one and then reading it is a race whose red names a
-- file this test has no business reading (GH #365 §2 / #438; hero backlog
-- -79 measured the population at 18 walks in 18 files).  The rule lives in
-- tests/lua_source_scan.lua and is referenced, never copied -- the path
-- literal is load-bearing text and a second copy is the defect.
local function hero_files()
    local tPaths = require('lua_source_scan').bots_files()
    assert(#tPaths > 100,
        'found only ' .. #tPaths .. ' lua files -- the scan input collapsed, so '
        .. 'every set comparison below would pass vacuously')
    return tPaths
end

-- Identity of a site.  The LINE IS NOT IN IT (GH #221): a key carrying a line
-- number turns every edit above a site into a red ratchet, and this very change
-- moved all eight lines down by adding the annotations.  The ORDINAL is in it,
-- and that is the half GH #228 had to learn twice: hero_enigma.lua reads
-- `Malefice` twice and the two reads want OPPOSITE repairs (the first a key,
-- the second deletion), so a key that could not tell them apart would have to
-- hand both rows one instruction, and either choice is wrong for one of them.
local function site_key(sFile, sVar, nNth)
    return sFile .. ' ' .. sVar .. '#' .. nNth
end

tests['[hero] the ABILVALUE snapshot is well-formed and non-degenerate'] = function()
    assert(type(SNAP) == 'table' and type(SNAP.sites) == 'table'
        and type(SNAP.totals) == 'table' and type(SNAP.signs) == 'table',
        SNAPSHOT_LUA .. ' does not return { totals = .., signs = .., sites = .. }')
    assert(#SNAP.sites == 8,
        'snapshot describes ' .. #SNAP.sites .. ' sites, expected 8 -- if the '
        .. 'tree really changed, re-run `python3 ' .. CENSUS_PY .. ' --snapshot`'
        .. ' and move this number with a reason')
    assert(SNAP.totals.sites == #SNAP.sites,
        'snapshot totals disagree with its own rows')
    assert(SNAP.totals.abilities == 7,
        'expected 7 distinct abilities, got ' .. tostring(SNAP.totals.abilities))
    -- The headline is "8 of 8 read zero".  If a future patch gives one of these
    -- abilities an entry named `value`, that row flips to ANSWERS and this line
    -- goes red -- which is the point: the finding would have changed.
    assert(SNAP.totals.reads_zero == 8,
        'expected 8 READS-ZERO rows, got ' .. tostring(SNAP.totals.reads_zero))
    -- Non-degeneracy of the sign split.  A census that put every site in one
    -- bucket would still satisfy every count above; the whole claim of this
    -- axis is that the split is NOT uniform, the way #228's was.
    assert(SNAP.signs.under == 5 and SNAP.signs.over == 1 and SNAP.signs.fold == 2,
        'the sign split moved (under/over/fold = ' .. tostring(SNAP.signs.under)
        .. '/' .. tostring(SNAP.signs.over) .. '/' .. tostring(SNAP.signs.fold)
        .. ') -- that is the axis\'s headline, so move it with a reason')
    for _, tSite in ipairs(SNAP.sites) do
        assert(type(tSite.file) == 'string' and type(tSite.line) == 'number'
            and type(tSite.var) == 'string' and type(tSite.nth) == 'number'
            and type(tSite.ability) == 'string' and type(tSite.sign) == 'string',
            'malformed snapshot row for ' .. tostring(tSite.file))
    end
end

tests['[hero] the live tree still has exactly the ABILVALUE sites on record'] = function()
    local tWant, tGot = {}, {}
    for _, tSite in ipairs(SNAP.sites) do
        tWant[site_key(tSite.file, tSite.var, tSite.nth)] = tSite.ability
    end
    for _, sPath in ipairs(hero_files()) do
        for _, tSite in ipairs(find_sites(strip_comments(read_file(sPath)))) do
            tGot[site_key(sPath, tSite.var, tSite.nth)] = tSite.ability
        end
    end
    for sKey, sAbility in pairs(tWant) do
        assert(tGot[sKey] ~= nil,
            'snapshot site ' .. sKey .. ' is gone from the tree -- if it was '
            .. 'repaired, re-run `python3 ' .. CENSUS_PY .. ' --snapshot`')
        assert(tGot[sKey] == sAbility,
            sKey .. ' is now bound to ' .. tostring(tGot[sKey]) .. ', not '
            .. sAbility .. ' -- the verdict on record is about the old ability')
    end
    for sKey, sAbility in pairs(tGot) do
        assert(tWant[sKey] ~= nil,
            'NEW `<ability>:GetSpecialValue*(\'value\')` site at ' .. sKey
            .. ' (' .. sAbility .. ') -- it is a silent 0 unless that ability '
            .. 'owns an entry literally named `value`.  Run `python3 '
            .. CENSUS_PY .. '` before shipping it')
    end
end

tests['[hero] no ABILVALUE row prescribes the key the axis just disproved'] = function()
    for _, tSite in ipairs(SNAP.sites) do
        assert(tSite.sign == 'UNDER' or tSite.sign == 'OVER'
            or tSite.sign == 'FOLD',
            tSite.file .. ' ' .. tSite.var .. ' carries no disposition ('
            .. tostring(tSite.sign) .. ') -- an UNCLASSIFIED row is a site '
            .. 'nobody read, and it must not sit in the table looking settled')
        assert(tSite.intended ~= 'value',
            tSite.file .. ' ' .. tSite.var .. ' names `value` as its intended '
            .. 'key -- that is the key this axis proved the ability does not own')
        -- FOLD means "the engine already added it"; naming a key there would
        -- invite exactly the double-count GH #228 spent a section on.
        if tSite.sign == 'FOLD' then
            assert(tSite.intended == '',
                tSite.file .. ' ' .. tSite.var .. ' is FOLD but names an '
                .. 'intended key (' .. tostring(tSite.intended) .. ') -- a FOLD '
                .. 'site\'s repair is DELETION; a key there double-counts')
        else
            assert(tSite.intended ~= '' and tSite.intended ~= tSite.ability,
                tSite.file .. ' ' .. tSite.var .. ' has no intended key on '
                .. 'record, so the row reports a defect without its repair')
        end
    end
end

-- Section 4.  Two sites cannot be repaired by reading the intended-key column,
-- and both failure modes are silent, so each gets an assertion in the shipped
-- source rather than a note in a report nobody re-reads:
--   * terrorblade's `health_cost_pct` is a PERCENT and the line multiplies by
--     health directly -- the key swap alone flips its guard to never-true;
--   * enigma's second `Malefice` read is a FOLD term whose repair is deletion.
-- Markers are single contiguous phrases on purpose.  GH #223's M8 and GH #228's
-- retraction marker both escaped a first draft by wrapping across two comment
-- lines: an assertion aimed at prose has to be aimed at prose that does not
-- wrap.
tests['[hero] the two non-key-swap ABILVALUE repairs say so in the source'] = function()
    local sTB = read_file('bots/BotLib/hero_terrorblade.lua')
    assert(sTB:find('health_cost_pct', 1, true) ~= nil,
        'hero_terrorblade.lua no longer names the intended key at all')
    assert(sTB:find('twenty PERCENT, not a', 1, true) ~= nil,
        'hero_terrorblade.lua names `health_cost_pct` without recording that it '
        .. 'is a percentage -- a reader who swaps the key alone multiplies the '
        .. 'cost by 20 and turns the guard off in the other direction')
    local sEN = read_file('bots/BotLib/hero_enigma.lua')
    assert(sEN:find('DOUBLE%-COUNT') ~= nil,
        'hero_enigma.lua no longer records that its second Malefice read is a '
        .. 'folded talent term whose repair is deletion')
    assert(sEN:find('special_bonus_unique_enigma_9', 1, true) ~= nil,
        'hero_enigma.lua no longer records that MidnightPulseRadiusTalent names '
        .. 'the wrong talent (GH #223 §6.3) -- both axes land on that branch')
end

-- Section 5.  A scanner that finds nothing makes section 2 pass vacuously in
-- the direction that matters (a NEW site slipping in unseen), so drive it both
-- ways on input this file owns.
tests['[hero] the ABILVALUE scanner is driven both ways'] = function()
    local tHit = find_sites({
        "local Foo = bot:GetAbilityByName('hero_foo')",
        "local T   = bot:GetAbilityByName('special_bonus_unique_x')",
        "local n = Foo:GetSpecialValueInt('value')",
        "local m = T:GetSpecialValueInt('value')",
        "local k = Bar:GetSpecialValueInt('value')",
        "local j = Foo:GetSpecialValueFloat('radius')",
        "local p = Foo:GetSpecialValueFloat('value')",
    })
    assert(#tHit == 2, 'scanner found ' .. #tHit .. ' sites in the fixture, expected 2')
    assert(tHit[1].line == 3 and tHit[1].var == 'Foo'
        and tHit[1].ability == 'hero_foo' and tHit[1].nth == 1,
        'scanner mis-read the first ability-handle read')
    assert(tHit[2].line == 7 and tHit[2].nth == 2,
        'scanner does not number a second read of the same handle -- that is '
        .. 'the distinction the two Malefice rows rest on')
    assert(#find_sites({ "local n = Foo:GetSpecialValueInt('value')" }) == 0,
        'scanner counts a read whose handle is not bound in the file')
    assert(#find_sites({
        "local T = bot:GetAbilityByName('special_bonus_unique_x')",
        "local m = T:GetSpecialValueInt('value')" }) == 0,
        'scanner counts a TALENT-handle read -- that is GH #228\'s axis, and '
        .. 'double-booking it would inflate this one')
    assert(#find_sites(strip_comments(
        "local Foo = bot:GetAbilityByName('hero_foo')\n"
        .. "-- local n = Foo:GetSpecialValueInt('value')\n")) == 0,
        'scanner counts a commented-out read -- and this change put a paragraph '
        .. 'of prose quoting that idiom above every one of the eight sites')
end

return tests
