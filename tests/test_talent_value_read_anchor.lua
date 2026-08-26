-- [hero] `TALENTVALUE`: the third half of the talent-binding axis -- not which
-- talent the handle names, but whether that handle can answer `value` at all.
-- GH #228.  Sibling of GH #166/#214 (BY INDEX) and GH #223 (BY LITERAL NAME).
--
-- WHY THIS FILE EXISTS
-- --------------------
-- Twenty-one live call sites in bots/BotLib share one idiom:
--
--     local nRadius = abilityQ:GetSpecialValueInt( 'radius' )
--     if talent7:IsTrained() then nRadius = nRadius + talent7:GetSpecialValueInt( 'value' ) end
--
-- It reads as live arithmetic and it is a no-op, in every one of the twenty-one.
-- Talents come in two families and only one owns a `value`:
--
--   * GENERIC talents (`special_bonus_hp_200`, `special_bonus_strength_15`) are
--     real ability blocks in npc_abilities.txt, each carrying exactly one
--     AbilityValues entry, named `value`.  A read there answers a number.
--   * HERO-UNIQUE talents (`special_bonus_unique_axe_2`) have NO KV block --
--     not in npc_abilities.txt, not in the hero's own KV.  The payload sits
--     inside the MODIFIED ABILITY's entry, as a sub-key named after the talent:
--
--         "radius" { "value" "315"   "special_bonus_unique_axe_2" "+85" }
--
--     so the talent handle has no special values at all and the read is a
--     silent 0 (BOT_API_REFERENCE: "a typo will silently return 0").
--
-- The partition is total, and the NAME carries it: of the 974 talents the
-- shipped roster references, 65 own a block (all generic, all with `value`) and
-- 909 do not -- all 909 with `unique` in the name, none of the 65.  Measured by
-- tools/agent/talent_value_read_census.py, not assumed.
--
-- ⭐ THE PART WORTH KEEPING: THE DEAD TERM IS DEAD IN THE SAFE DIRECTION, AND
-- THE OBVIOUS REPAIR IS THE REGRESSION.  The KV shape above exists so the
-- engine can fold `+85` into `radius` for a caster who trained the talent;
-- there is nowhere else the bonus could live, so if the engine did not fold it
-- the talent would do nothing in the game at all.  Hence
-- `abilityQ:GetSpecialValueInt('radius')` ALREADY carries the bonus, and
-- repointing the term at a handle that answers would DOUBLE-COUNT it.
--
-- This tree has already bet on that fold once, in a landed repair: GH #162's
-- `lionsplash` reads `lion_finger_of_death/splash_radius`, which
-- special_value_shape_census.py classifies NO-BASE -- no base `value`, only
-- `special_bonus_scepter "325"`.  That read is worth something only if the
-- engine resolves `special_bonus_*` sub-entries per caster.  The 21 sites here
-- encode the opposite bet.  Both cannot be right; the KV shape says which is.
--
-- THE ONE SITE WHERE "HARMLESS" DOES NOT FOLLOW.  A fold only reaches a number
-- that was read off the ability.  `hero_axe.lua`'s Culling Blade kill-check
-- HARDCODES its base (`nKillDamage = 150 + 100 * nSkillLV`), so no fold reaches
-- it and the talent bonus is genuinely absent there.  Its repair is the
-- already-registered `hero-2` lever (read the base off `abilityR`), which
-- collects the fold as a side effect -- not this axis, and not this file.
--
-- WHAT THIS FILE ASSERTS, AND WHAT IT LEAVES TO THE CENSUS
-- --------------------------------------------------------
-- The census owns "does this talent own a KV block", which needs the network
-- and so cannot live here.  This file owns "is the tree still the shape the
-- census was run against", which needs nothing and runs in the standing gate:
--
--   1  the snapshot is well-formed and still describes 21 sites;
--   2  the set of live sites IN THE TREE equals the snapshot's set -- a new
--      one, or a deleted one, is red and says to re-run the census;
--   3  the four focus-five sites are pinned by talent name, and each is
--      recorded UNIQUE-READS-ZERO;
--   4  the shipped Zeus annotation no longer carries the reason that was
--      wrong (see below);
--   5  the scanner in 2 is driven BOTH ways on synthetic input, so a green 2
--      cannot mean "the scanner finds nothing anywhere".
--
-- Section 4 exists because the 2026-08-22 annotation on hero_zuus.lua's ult
-- kill-check got the conclusion right (the term is 0) from a wrong reason: it said the
-- talent's special value "is named `bonus_arc_damage`, not `value`", which
-- invites the next reader to repair the site by reading `bonus_arc_damage`.
-- That read is 0 too -- the talent has no keys of any kind -- and had it not
-- been 0 it would have double-counted.  A wrong reason under a right
-- conclusion is the shape that survives review, so it gets its own assertion.
--
-- LIMITS
--   * This is a CONSISTENCY ratchet, not a correctness one.  Snapshot and tree
--     can be wrong together and stay green; correctness is owned by the source,
--     and the source is the census's two KV files.
--   * The scanner is line-based, like the census's.  A binding or a read split
--     across lines is invisible to both; none in this tree is.
--   * Nothing here evaluates the fold.  `GetSpecialValueInt` is engine-side and
--     the mock answers 0 for every key on every handle (GH #100/#133/#145/#154
--     family), so a green run here is NOT evidence about what the engine does
--     with a trained talent.  The argument for the fold is the KV shape and the
--     tree's own `lionsplash` bet, both stated above, and both offline.

local SNAPSHOT_LUA = 'tests/mock/talent_value_reads.lua'
local CENSUS_PY    = 'tools/agent/talent_value_read_census.py'

local SNAP = dofile(SNAPSHOT_LUA)

local tests = {}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local sText = fh:read('*a')
    fh:close()
    return sText
end

-- Blank out `--` line comments while keeping the line COUNT, so a reported line
-- is the line a reader opens.  Nine of the reads in bots/ sit on commented-out
-- `aetherRange` lines; counting those would put the headline out by a third and
-- would point four of the focus-five rows at prose.
local function strip_comments(sText)
    local tOut = {}
    for sLine in (sText .. '\n'):gmatch('([^\n]*)\n') do
        local nCut = sLine:find('--', 1, true)
        tOut[#tOut + 1] = (nCut ~= nil) and sLine:sub(1, nCut - 1) or sLine
    end
    return tOut
end

--- Find every `<var>:GetSpecialValue*('value')` whose <var> is bound in the
--- same file to `bot:GetAbilityByName( sTalentList[N] )`.
--- Returns { { line = n, var = s, slot = n }, ... }.
local function find_sites(tLines)
    local tBind = {}
    for _, sLine in ipairs(tLines) do
        local sVar, sSlot = sLine:match(
            'local%s+([%w_]+)%s*=%s*bot:GetAbilityByName%(%s*sTalentList%[%s*(%d+)%s*%]')
        if sVar ~= nil then tBind[sVar] = tonumber(sSlot) end
    end
    local tOut = {}
    for nLine, sLine in ipairs(tLines) do
        for sVar in sLine:gmatch("([%w_]+):GetSpecialValue%a+%(%s*['\"]value['\"]") do
            if tBind[sVar] ~= nil then
                tOut[#tOut + 1] = { line = nLine, var = sVar, slot = tBind[sVar] }
            end
        end
    end
    return tOut
end

local function hero_files()
    local tPaths = {}
    local p = assert(io.popen("find bots/BotLib -name 'hero_*.lua' | sort"))
    for sPath in p:lines() do tPaths[#tPaths + 1] = sPath end
    p:close()
    assert(#tPaths > 100,
        'found only ' .. #tPaths .. ' hero files -- the scan input collapsed, '
        .. 'so every set comparison below would pass vacuously')
    return tPaths
end

-- Identity of a site, for the set comparison in section 2.  The LINE IS NOT IN
-- IT, on purpose (GH #221): a key that carries a line number turns every edit
-- above a site into a red ratchet, and the five pins that defect cost were all
-- knocked off by commits that had moved the code, not broken it.  Two reads of
-- the same slot in one file are distinguished by the variable, which is what
-- actually differs.  The snapshot still RECORDS the line, because a reader
-- needs somewhere to open -- it is a pointer here, never a key.
local function site_key(sFile, sVar, nSlot)
    return sFile .. ' ' .. sVar .. '[' .. nSlot .. ']'
end

--- True when the file names `bonus_arc_damage` as the talent's special value
--- WITHOUT the retraction standing beside it.
---
--- The first draft of this judge was `find('bonus_arc_damage') == nil`, and it
--- went red on the very correction it exists to protect: retracting a wrong key
--- means quoting it.  A "this string must not appear" assertion is unusable in
--- a file that discusses the string -- the exact dual of the lesson GH #214
--- recorded, that "this string must appear" is near-vacuous in a file which
--- describes itself.  So the judge is an IMPLICATION, not an absence: the
--- mention is allowed, unretracted is not.  Section 5 drives it both ways,
--- because a judge that answers false to everything would make this pass
--- vacuously and silently.
--- One line, not a sentence: the retraction as written wraps across two comment
--- lines ("... not 'value'\".  It is" / "named NOTHING: a hero-UNIQUE talent"),
--- and a multi-word marker that straddles a wrap matches nothing.  This is the
--- same shape as the M8 escape GH #223 recorded -- an assertion aimed at prose
--- has to be aimed at prose that is actually contiguous.
local RETRACTION = 'named NOTHING'
local function mentions_wrong_key_unretracted(sText)
    if sText:find('bonus_arc_damage', 1, true) == nil then return false end
    return sText:find(RETRACTION, 1, true) == nil
end

tests['[hero] the TALENTVALUE snapshot is well-formed and non-empty'] = function()
    assert(type(SNAP) == 'table' and type(SNAP.sites) == 'table',
        SNAPSHOT_LUA .. ' does not return { roster = ..., sites = ... }')
    assert(#SNAP.sites == 21,
        'snapshot describes ' .. #SNAP.sites .. ' sites, expected 21 -- if the '
        .. 'tree really changed, re-run `python3 ' .. CENSUS_PY .. ' --snapshot`'
        .. ' and move this number with a reason')
    assert(type(SNAP.roster) == 'table' and SNAP.roster.talents > 900,
        'roster counts are missing or collapsed; the partition claim rests on them')
    assert(SNAP.roster.with_own_kv_block > 0
        and SNAP.roster.with_own_kv_block < SNAP.roster.talents,
        'roster partition is degenerate (' .. tostring(SNAP.roster.with_own_kv_block)
        .. '/' .. tostring(SNAP.roster.talents) .. ') -- a census that put every '
        .. 'talent on one side would report exactly this file green')
    for _, tSite in ipairs(SNAP.sites) do
        assert(type(tSite.file) == 'string' and type(tSite.line) == 'number'
            and type(tSite.talent) == 'string' and type(tSite.verdict) == 'string',
            'malformed snapshot row for ' .. tostring(tSite.file))
    end
end

tests['[hero] every snapshot site is still exactly where the census left it'] = function()
    -- Compared as a MULTISET, not a set.  Dropping the line from the key (see
    -- site_key) is what makes the ratchet survive an edit above a site, and it
    -- costs exactly this: two reads on the same handle in the same file share a
    -- key.  A plain set comparison then answers green when a SECOND read is
    -- added next to an existing one -- which is the direction that matters, a
    -- fresh silent zero shipping unremarked.  Measured, not feared: that
    -- mutation escaped the set version of this section on the first run.
    local tWant, tHave = {}, {}
    for _, tSite in ipairs(SNAP.sites) do
        local sKey = site_key(tSite.file, tSite.var, tSite.slot)
        tWant[sKey] = (tWant[sKey] or 0) + 1
    end
    for _, sPath in ipairs(hero_files()) do
        local tLines = strip_comments(read_file(sPath))
        for _, tSite in ipairs(find_sites(tLines)) do
            local sKey = site_key(sPath, tSite.var, tSite.slot)
            tHave[sKey] = (tHave[sKey] or 0) + 1
        end
    end

    for sKey, nWant in pairs(tWant) do
        assert((tHave[sKey] or 0) == nWant,
            'snapshot records ' .. nWant .. ' talent `value` read(s) at ' .. sKey
            .. ' and the tree has ' .. (tHave[sKey] or 0)
            .. ' -- if the site was moved or removed on purpose, re-run `python3 '
            .. CENSUS_PY .. ' --snapshot` in the same change')
    end
    for sKey, nHave in pairs(tHave) do
        assert((tWant[sKey] or 0) == nHave,
            'the tree has ' .. nHave .. ' talent `value` read(s) at ' .. sKey
            .. ' that the census classified ' .. (tWant[sKey] or 0)
            .. ' of.  An unclassified one is a silent 0 unless the talent owns a '
            .. 'KV block (only generic ones do) -- run `python3 ' .. CENSUS_PY
            .. '` before shipping it')
    end
end

tests['[hero] the four focus-five sites are pinned by talent name'] = function()
    -- Keyed by FILE + TALENT NAME, never by line number.  A line-number key is
    -- the GH #221 defect verbatim: three compliant commits pushed five pins off
    -- their rows in one day, and every one of them had moved the code it meant
    -- to hold rather than broken it.  Adding the annotations this change ships
    -- would have moved all four of these.
    local tWant = {
        ['bots/BotLib/hero_axe.lua']  = { special_bonus_unique_axe_2 = true,
                                          special_bonus_unique_axe_5 = true },
        ['bots/BotLib/hero_lion.lua'] = { special_bonus_unique_lion_8 = true },
        ['bots/BotLib/hero_zuus.lua'] = { special_bonus_unique_zeus_2 = true },
    }
    local tSeen = {}
    for _, tSite in ipairs(SNAP.sites) do
        local tFile = tWant[tSite.file]
        if tFile ~= nil then
            assert(tFile[tSite.talent],
                tSite.file .. ':' .. tSite.line .. ' now names ' .. tSite.talent
                .. ', which is not one of this file`s pinned talents -- the '
                .. 'talent row moved, so re-read the hero file before trusting '
                .. 'anything downstream of it')
            assert(tSite.verdict == 'UNIQUE-READS-ZERO',
                tSite.file .. ':' .. tSite.line .. ' is recorded ' .. tSite.verdict
                .. '.  If this talent gained a KV block of its own, the term '
                .. 'stopped being a no-op AND started double-counting the fold '
                .. '-- that is a behaviour change, not a snapshot refresh')
            tSeen[tSite.file .. '/' .. tSite.talent] = true
        end
    end
    local nSeen = 0
    for sFile, tTalents in pairs(tWant) do
        for sTalent in pairs(tTalents) do
            assert(tSeen[sFile .. '/' .. sTalent],
                sFile .. ' no longer reads `value` off ' .. sTalent
                .. '.  If the term was removed on purpose, drop it from this pin '
                .. 'in the same change and say in the message which fold now '
                .. 'carries the bonus')
            nSeen = nSeen + 1
        end
    end
    assert(nSeen == 4, 'expected 4 focus-five rows, found ' .. nSeen)
end

tests['[hero] the Zeus annotation no longer carries the wrong reason'] = function()
    local sSrc = read_file('bots/BotLib/hero_zuus.lua')
    assert(sSrc:find('special_bonus_unique_zeus_2', 1, true) ~= nil,
        'the Zeus ult kill-check lost its annotation naming the talent it adds')
    assert(not mentions_wrong_key_unretracted(sSrc),
        'hero_zuus.lua names `bonus_arc_damage` as the talent`s special value '
        .. 'without the retraction beside it.  It is named nothing: a '
        .. 'hero-unique talent has no KV block, so it answers no key at all.  '
        .. 'That reason invites the next reader to "repair" the site by reading '
        .. '`bonus_arc_damage` -- also 0, and had it not been 0 it would have '
        .. 'double-counted the bonus the engine already folds into `damage`')
end

tests['[hero] the site scanner is driven in both directions'] = function()
    -- A scanner that finds nothing everywhere makes section 2 pass vacuously in
    -- the direction that matters (a NEW unclassified read), so it is fed one
    -- live site, one commented site, one read on a handle that is not a talent,
    -- and one talent handle that is never read.
    local tLines = strip_comments(table.concat({
        'local talentA = bot:GetAbilityByName( sTalentList[7] )',
        'local talentB = bot:GetAbilityByName( sTalentList[2] )',
        'local abilityQ = bot:GetAbilityByName( sAbilityList[1] )',
        "if talentA:IsTrained() then n = n + talentA:GetSpecialValueInt( 'value' ) end",
        "--\tif talentB:IsTrained() then n = n + talentB:GetSpecialValueInt( 'value' ) end",
        "local nR = abilityQ:GetSpecialValueInt( 'value' )",
        "local nS = talentA:GetSpecialValueFloat( \"value\" )",
        "local nT = talentA:GetSpecialValueInt( 'radius' )",
    }, '\n'))
    assert(#tLines == 8, 'stripper changed the line count to ' .. #tLines
        .. ' -- reported line numbers would no longer be openable')

    local tFound = find_sites(tLines)
    local tByLine = {}
    for _, tSite in ipairs(tFound) do tByLine[tSite.line] = tSite end

    assert(tByLine[4] ~= nil and tByLine[4].slot == 7,
        'lost the live talent read, or resolved it to the wrong slot')
    assert(tByLine[7] ~= nil and tByLine[7].slot == 7,
        'lost the GetSpecialValueFloat form, or the double-quoted key')
    assert(tByLine[5] == nil,
        'a commented-out read was counted -- this is the case the tree really '
        .. 'has (nine `aetherRange` lines across the focus five and others)')
    assert(tByLine[6] == nil,
        "a `value` read on an sAbilityList handle was counted as a talent read; "
        .. 'that is a different finding (an ability entry`s inner `value` key) '
        .. 'and it does not belong in this census')
    assert(tByLine[8] == nil,
        'a non-`value` key on a talent handle was counted')
    assert(#tFound == 2, 'expected exactly 2 sites, found ' .. #tFound)

    -- And the retraction judge, both ways.  A judge that answered false to
    -- everything would make section 4 green while the wrong reason sat back in
    -- the file, which is precisely the failure this whole round is about.
    assert(mentions_wrong_key_unretracted(
        "-- its special value is named 'bonus_arc_damage', not 'value'"),
        'the judge misses the sentence it was written for -- the 2026-08-22 '
        .. 'annotation verbatim')
    assert(not mentions_wrong_key_unretracted(
        "-- said 'bonus_arc_damage'.  It is\n-- named NOTHING: no KV block"),
        'the judge rejects a retraction that quotes the wrong key, which is the '
        .. 'only way a retraction can be written')
    assert(not mentions_wrong_key_unretracted('-- nothing to do with talents'),
        'the judge fires on a file that never mentions the key')
    assert(mentions_wrong_key_unretracted(
        '-- bonus_arc_damage\n-- named nothing: lower case is a different string'),
        'the marker match went case-insensitive; then any prose containing the '
        .. 'words would count as a retraction')
end

return tests
