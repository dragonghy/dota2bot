-- [hero] [ratchet] `CMWEAKSENT`: the `10000` in `X.cm_GetWeakestUnit` is TWO
-- things at once -- a returned sentinel and a silent cap -- and neither one can
-- be armed.  DO-NOT-ARM, settled offline, no wave needed.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- `X.cm_GetWeakestUnit`'s `10000` had been this desk's number-one next-round
-- candidate for THREE consecutive rounds without anyone touching it, each round
-- carrying the same one-line note ("先提 queue 不要先写 helper -- 域买不到").
-- A candidate that neither moves nor dies is a candidate nobody has priced, so
-- this round priced it.  The answer is that it cannot be armed, for two
-- INDEPENDENT reasons, and both are decidable from source plus the committed
-- corpus -- there was never a wave to request.
--
--     function X.cm_GetWeakestUnit( nEnemyUnits )
--         local nWeakestUnit = nil
--         local nWeakestUnitLowestHealth = 10000        -- <== the subject
--         for _, unit in pairs( nEnemyUnits ) do
--             if J.CanCastOnNonMagicImmune( unit ) then
--                 if unit:GetHealth() < nWeakestUnitLowestHealth then
--                     nWeakestUnitLowestHealth = unit:GetHealth()
--                     nWeakestUnit = unit
--                 end
--             end
--         end
--         return nWeakestUnit, nWeakestUnitLowestHealth
--     end
--
-- READING A -- the sentinel as a RETURNED HEALTH.  When nothing is pickable the
-- function hands back `nil, 10000`: a health belonging to no unit.  That is the
-- same defect shape the sibling picker already carries a gated id for
-- (`cmrangedhp`, on `X.cm_GetStrongestUnit`'s early return).  Here it has NO
-- CONSUMER: section 2 reads all FOURTEEN call sites in the two files that call
-- it and the second binding is a dead local at every one.  An id that changed
-- the constant would be a no-op on every frame of every wave, while
-- `check_armed_wiring.py` still read it WIRED and the verdict came back "tested,
-- no effect" with nothing raising a hand -- the GH #606 zero-domain shape.
--
-- READING B -- the sentinel as a CAP on the first return value.  A unit whose
-- CURRENT health is >= 10000 can never be selected, not even as the only
-- candidate, because the seed is finite and the comparison is strict.  Section 4
-- prices that domain over the whole committed corpus: 1550 hero rows in 155
-- fixture files across the FOUR directories that hold fixtures (`tests/fixtures`,
-- its `outchan/` and `skillstall/`, and `tests/frames`), ceiling `max_hp` 4343
-- and ceiling current `hp` 4340.  The sentinel sits at 2.30x the ceiling and the
-- corpus's entire 4000+ bucket holds FOUR rows.  The domain cannot buy the cap.
--
-- ⚠️ That "four" is a quantifier this file got wrong on its first run and the
-- mistake is recorded rather than quietly corrected: the header first said SIX,
-- which is the number of directories under `tests/` (it counts `tests/` itself
-- and `tests/mock`, neither of which holds a fixture).  Section 4's floor is on
-- directories that CONTAIN fixtures, because that is the set whose shrinking
-- would silently narrow the sweep.  Two readings that disagree are a quantifier
-- difference first and a broken reader second.
--
-- ⭐ WHAT IS WORTH A FILE, BEYOND RETIRING ONE CANDIDATE -- section 6.  The seed
-- is safe here because of what it is MEASURING, not because of how big it is,
-- and the same literal is used elsewhere in `bots/` on a quantity whose ceiling
-- is the MAP:
--
--     bots/mode_outpost_generic.lua  GetClosestOutpost()   local dist = 10000
--         ... GetUnitToUnitDistance(bot, Outposts[i]) < dist ...
--
-- That candidate set is the two map-static outposts and the loop has NO SEARCH
-- RING -- nothing bounds the distance it measures.  Priced against the same
-- corpus, the largest distance between two buildings in it is 16026.6u, i.e.
-- 1.60x that seed, where the health ceiling is 0.43x of it.  So the cap there IS
-- reachable and here it is not, and the difference is the dimension, which no
-- reader of the constant can see.
--
-- ⛔ AND THAT IS STILL NOT A BUG REPORT, WHICH IS THE ACTUAL POINT.  This desk
-- had the outpost finding written up as a live defect before reading its one
-- consumer, and the consumer refutes it:
--
--     ClosestOutpost, ClosestOutpostDist = GetClosestOutpost()
--     if ClosestOutpost ~= nil and ClosestOutpostDist < 3000  -- <== the mask
--
-- A capped answer is `nil, 10000` and fails the first conjunct; the un-capped
-- answer it would have given instead carries a distance >= 10000 and fails the
-- SECOND.  Both legs reach `BOT_ACTION_DESIRE_NONE`, so the cap is invisible in
-- consequence, and `Think()` -- the only other reader of that variable -- runs
-- only when this branch has already bid.  The masking is by a DOWNSTREAM
-- THRESHOLD, a third mechanism, unrelated to the health case's domain ceiling
-- and to reading A's missing consumer.
--
-- ⇒ THREE call sites of the same literal, THREE different reasons it is inert,
-- and NONE of the three is visible where the constant is written.  `bots/` holds
-- around sixty more finite min/max-picker seeds of this family and nobody has
-- ever counted which of them are masked or by what.  That census is the handoff
-- and it is not this desk's (`mode_*` and `FunLib/` are other desks' files);
-- section 6 pins BOTH halves of the outpost reading, so if the seed is fixed OR
-- the `< 3000` mask is loosened -- which is the day the cap becomes live -- this
-- file goes red and says so.
--
-- WHAT THIS FILE DOES NOT ESTABLISH -- READ BEFORE QUOTING IT
-- -----------------------------------------------------------
-- (1) ⛔ SECTION 4 IS A SAMPLE, NOT A PROOF.  "No hero row in 1550 reaches
--     10000 HP" is not "no hero can".  What makes reading B unarmable is a
--     conjunction: the corpus ceiling AND the fact that the optimization target
--     is TURBO, whose games end around 20 minutes.  A 60-minute normal-mode game
--     could plausibly put a Heart-and-more carry above the seed.  The claim is
--     "unreachable in the domain we test and ship for", never "impossible".
-- (2) ⛔ IT SAYS NOTHING ABOUT WHETHER THE PICKER PICKS WELL.  `min(health)` as
--     a target choice is untouched here; so is its `J.CanCastOnNonMagicImmune`
--     filter, which is a separate reading this desk already published
--     (tests/test_cm_kill_confirm_quantifier.lua -- the filter is why the
--     "obvious" immunity fix on the kill-confirm branch was a dead conjunct).
-- (3) ⛔ SECTION 6 IS NOT A MEASUREMENT OF bot->OUTPOST DISTANCE, AND IT IS NOT
--     A DEFECT CLAIM.  The corpus carries no outpost rows, so what section 6
--     prices is the DIMENSION's ceiling (two buildings 16026.6u apart exist),
--     not how often a bot is more than 10000u from the nearer enemy outpost --
--     and per the mask above, that hit rate would not be a defect rate either.
--     A reader who quotes section 6 as either is quoting something it does not
--     contain.
-- (4) The fourteen dead locals are NOT proposed for deletion.  Removing them is
--     a fourteen-site edit to two shipped files for zero behaviour, which is
--     exactly the kind of churn that makes a diff unreviewable; the point of
--     section 2 is the VERDICT it supports, not a cleanup.
--
-- ⚠️ Tagged [ratchet].  Sections 1, 2, 5 and 6 assert that the subject is still
-- there and still has this shape.  The day any of them is fixed they go red;
-- that is the notification.  Delete the section then -- do not loosen it.

package.path = 'tests/?.lua;' .. package.path

local scan = require('lua_source_scan')

--- The literal under test, in every one of its appearances below.
local SENTINEL = 10000

--- Both shipped copies of the picker.  `hero_silencer.lua` carries a third copy
--- of the same function body with the same seed; it is deliberately NOT read
--- here -- Silencer is not a focus hero, and a ratchet that reddens for a file
--- this desk has no charter over hands its red to whoever pushes next.
local PICKER_FILES = {
    'bots/BotLib/hero_crystal_maiden.lua',
    'bots/FunLib/rubick_hero/crystal_maiden.lua',
}

--- The sibling picker, read by the SAME code path in section 3.  This is the
--- anti-vacuity guard and it is load-bearing: without it, section 2's "zero
--- reads at fourteen sites" is a statement about the reader, not about the
--- files.  (Bought the hard way last round -- mutstand M12 there survived
--- because a filter that excluded nothing made the conclusion a tautology.)
local SIBLING = 'cm_GetStrongestUnit'
local SUBJECT = 'cm_GetWeakestUnit'

--- Floors on every sweep in this file.  A sweep that SHRANK is not a sweep that
--- passed: each of these is asserted against what this round actually measured,
--- so a scanner that silently stops resolving reddens instead of agreeing.
local MIN_SUBJECT_SITES = 14
local MIN_SIBLING_SITES = 4
local MIN_SIBLING_READS = 2
-- Directories that CONTAIN fixtures, not directories under `tests/`; see the
-- quantifier note in the header.
local MIN_CORPUS_DIRS = 4
local MIN_CORPUS_FILES = 150
local MIN_HERO_ROWS = 1500

local tests = {}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Comment-stripped lines, memoised.  Two sections read the same two
--- multi-thousand-line hero files and a third reads one more; without the memo
--- this file paid to strip them over again per section.
local tLineMemo = {}
local function lines_of(sPath)
    if tLineMemo[sPath] == nil then tLineMemo[sPath] = scan.stripped_lines(sPath) end
    return tLineMemo[sPath]
end

--- Start/end line of the top-level `function` block containing line n.
---
--- ⚠️ Scope, not file, is the right quantifier here and getting it wrong is the
--- first thing this file measured wrongly.  `nWeakestEnemyHeroHealth1` is bound
--- in THREE different functions of hero_crystal_maiden.lua, so a file-wide
--- occurrence count reads 3 and looks like "two reads" when the truth is three
--- independent dead bindings.  The bug was in the counter, not the file.
local function fn_bounds(tLines, nLine)
    local nStart, nEnd = nil, #tLines
    for n = nLine, 1, -1 do
        if tLines[n]:match('^function%s') then nStart = n break end
    end
    if nStart == nil then return nil, nil end
    for n = nStart + 1, #tLines do
        if tLines[n]:match('^function%s') then nEnd = n - 1 break end
    end
    return nStart, nEnd
end

--- Every `local a, b = X.<picker>( ... )` site in one file, with the lines
--- inside the enclosing function that READ the second binding.
local function sites_of(sPath, sPicker)
    local tLines = lines_of(sPath)
    local tOut = {}
    for n, sLine in ipairs(tLines) do
        local sFirst, sSecond = sLine:match(
            '^%s*local%s+([%w_]+)%s*,%s*([%w_]+)%s*=%s*X%.' .. sPicker .. '%s*%(')
        if sFirst ~= nil then
            local nStart, nEnd = fn_bounds(tLines, n)
            local tReads = {}
            for m = nStart or 1, nEnd or #tLines do
                if m ~= n then
                    local sPad = ' ' .. tLines[m] .. ' '
                    if sPad:match('[^%w_]' .. sSecond .. '[^%w_]') then
                        tReads[#tReads + 1] = m
                    end
                end
            end
            tOut[#tOut + 1] = { line = n, name = sSecond, reads = tReads }
        end
    end
    return tOut
end

--- Every fixture-shaped corpus file, plus the DIRECTORIES they live in.
---
--- ⚠️ The directory count is asserted rather than noted, because the corpus is
--- not one directory and this desk has already published a wrong "whole corpus"
--- number by assuming it was: last round's first census swept `tests/fixtures`
--- and forgot `tests/frames`, reporting 9/1 where the truth was 22/5.  A walk
--- that finds fewer directories than the last one reddens here.
local tCorpusMemo = nil
local function corpus()
    if tCorpusMemo ~= nil then return tCorpusMemo[1], tCorpusMemo[2] end
    local tFiles, tDirs = {}, {}
    local hPipe = assert(io.popen("find tests -type f -name 'f_*.lua' -print | sort"))
    for sLine in hPipe:lines() do
        tFiles[#tFiles + 1] = sLine
        tDirs[sLine:match('^(.*)/[^/]+$') or '.'] = true
    end
    hPipe:close()
    local nDirs = 0
    for _ in pairs(tDirs) do nDirs = nDirs + 1 end
    tCorpusMemo = { tFiles, nDirs }
    return tFiles, nDirs
end

--- §1.  The subject is still the constant this file is about.
tests['1. both shipped copies of the picker still seed the running minimum with 10000'] = function()
    local tBad = {}
    for _, sPath in ipairs(PICKER_FILES) do
        local sSrc = read_file(sPath)
        local sBody = sSrc:match('function%s+X%.' .. SUBJECT .. '%s*%b()(.-)\nend')
        if sBody == nil then
            tBad[#tBad + 1] = sPath .. ': X.' .. SUBJECT .. ' not found at all'
        else
            local sSeed = sBody:match('nWeakestUnitLowestHealth%s*=%s*(%-?[%w%.]+)')
            if sSeed ~= tostring(SENTINEL) then
                tBad[#tBad + 1] = sPath .. ': seeds the running minimum with '
                    .. tostring(sSeed) .. ', not ' .. SENTINEL
                    .. '.  If that is a FIX, this whole file is about a constant '
                    .. 'that no longer exists -- delete it, do not loosen it.'
            end
            -- Strict `<` against the seed is what makes the seed a CAP rather
            -- than merely an initial value; a `<=` or a nil-first idiom would
            -- change reading B entirely.
            if sBody:match('GetHealth%(%)%s*<%s*nWeakestUnitLowestHealth') == nil then
                tBad[#tBad + 1] = sPath .. ': the pick no longer compares '
                    .. 'GetHealth() < nWeakestUnitLowestHealth; reading B is '
                    .. 'about exactly that comparison'
            end
        end
    end
    assert(#tBad == 0, table.concat(tBad, '\n  '))
end

--- §2.  READING A: the returned sentinel has no consumer anywhere.
tests['2. the second return value is a dead local at every call site of the subject'] = function()
    local nSites, tLive = 0, {}
    for _, sPath in ipairs(PICKER_FILES) do
        for _, tSite in ipairs(sites_of(sPath, SUBJECT)) do
            nSites = nSites + 1
            if #tSite.reads > 0 then
                tLive[#tLive + 1] = sPath .. ':' .. tSite.line .. ' ' .. tSite.name
                    .. ' is read at ' .. table.concat(tSite.reads, ',')
            end
        end
    end

    assert(nSites >= MIN_SUBJECT_SITES,
        'only ' .. nSites .. ' call sites of X.' .. SUBJECT .. ' were resolved; '
        .. 'this round measured ' .. MIN_SUBJECT_SITES .. ' across '
        .. #PICKER_FILES .. ' files.  A scan that shrank is not a scan that '
        .. 'passed -- fix the reader before believing the smaller number.')

    assert(#tLive == 0,
        'the sentinel now HAS a consumer, so reading A is live and the '
        .. 'DO-NOT-ARM verdict must be re-decided before anything quotes it:\n  '
        .. table.concat(tLive, '\n  '))
end

--- §3.  ANTI-VACUITY: the same reader finds the sibling's second value LIVE.
tests['3. the same reader finds cm_GetStrongestUnit\'s second value read at every site'] = function()
    local nSites, tDead, nMinReads = 0, {}, math.huge
    for _, sPath in ipairs(PICKER_FILES) do
        for _, tSite in ipairs(sites_of(sPath, SIBLING)) do
            nSites = nSites + 1
            if #tSite.reads == 0 then
                tDead[#tDead + 1] = sPath .. ':' .. tSite.line .. ' ' .. tSite.name
            end
            if #tSite.reads < nMinReads then nMinReads = #tSite.reads end
        end
    end

    assert(nSites >= MIN_SIBLING_SITES,
        'only ' .. nSites .. ' call sites of X.' .. SIBLING .. ' were resolved; '
        .. 'this round measured ' .. MIN_SIBLING_SITES .. '.  Section 2 means '
        .. 'nothing if this control shrank to nothing.')

    assert(#tDead == 0,
        'the control is no longer a control: X.' .. SIBLING .. ' now also has '
        .. 'dead second bindings, so "zero reads" stops being a fact about X.'
        .. SUBJECT .. ' and becomes one about this reader:\n  '
        .. table.concat(tDead, '\n  '))

    assert(nMinReads >= MIN_SIBLING_READS,
        'the weakest sibling site is read only ' .. nMinReads .. ' time(s); this '
        .. 'round measured at least ' .. MIN_SIBLING_READS .. ' at every site.')
end

--- §4.  READING B: the cap's domain, priced over the whole committed corpus.
tests['4. no hero row in the corpus comes within half the sentinel of it'] = function()
    local tFiles, nDirs = corpus()

    assert(nDirs >= MIN_CORPUS_DIRS,
        'the walk found only ' .. nDirs .. ' corpus directories; this round '
        .. 'found ' .. MIN_CORPUS_DIRS .. '.  A "whole corpus" reading taken '
        .. 'over fewer directories than exist is the 9/1-vs-22/5 mistake again.')
    assert(#tFiles >= MIN_CORPUS_FILES,
        'the walk found only ' .. #tFiles .. ' fixture files; this round found '
        .. MIN_CORPUS_FILES .. '.')

    local nRows, nMaxHp, nMaxMaxHp, nAbove4k = 0, -1, -1, 0
    local sMaxWhere = ''
    for _, sPath in ipairs(tFiles) do
        local fChunk = loadfile(sPath)
        if fChunk ~= nil then
            local bOk, tFix = pcall(fChunk)
            if bOk and type(tFix) == 'table' and type(tFix.units) == 'table' then
                for _, tUnit in ipairs(tFix.units) do
                    if type(tUnit.name) == 'string'
                        and tUnit.name:match('^npc_dota_hero_')
                        and type(tUnit.hp) == 'number'
                    then
                        nRows = nRows + 1
                        if tUnit.hp > nMaxHp then nMaxHp = tUnit.hp end
                        if type(tUnit.max_hp) == 'number' and tUnit.max_hp > nMaxMaxHp then
                            nMaxMaxHp = tUnit.max_hp
                            sMaxWhere = sPath .. ' :: ' .. tUnit.name
                        end
                        if tUnit.hp >= 4000 then nAbove4k = nAbove4k + 1 end
                    end
                end
            end
        end
    end

    assert(nRows >= MIN_HERO_ROWS,
        'only ' .. nRows .. ' hero rows were read; this round read '
        .. MIN_HERO_ROWS .. '.  A ceiling taken over a corpus that shrank is '
        .. 'not the ceiling.')

    -- ⚠️ The anti-vacuity guard for THIS section.  "max < 10000" is satisfied
    -- for free by a reader that finds no health at all, which is precisely how
    -- last round's M12 mutant survived elsewhere.  The corpus must be shown to
    -- reach high health before "it does not reach 10000" says anything.
    assert(nAbove4k >= 1,
        'not one hero row in the corpus reaches 4000 hp, so "nothing reaches '
        .. SENTINEL .. '" is vacuous here -- it would hold for a reader that '
        .. 'parsed no health at all.  Fix the parse before reading the ceiling.')

    assert(nMaxMaxHp > 0 and nMaxMaxHp < SENTINEL,
        'the corpus ceiling is now max_hp ' .. nMaxMaxHp .. ' (' .. sMaxWhere
        .. '), which is no longer below the ' .. SENTINEL .. ' sentinel.  '
        .. 'Reading B just became reachable and the DO-NOT-ARM verdict must be '
        .. 're-decided -- do not loosen this bound.')
    assert(nMaxHp < SENTINEL,
        'the corpus current-hp ceiling is now ' .. nMaxHp .. ', at or above the '
        .. SENTINEL .. ' sentinel; see the max_hp message above.')

    -- The margin, asserted rather than noted, because "below the sentinel" and
    -- "nowhere near it" are different verdicts and only the second one retires
    -- a candidate without a wave.
    assert(nMaxMaxHp * 2 < SENTINEL,
        'the corpus ceiling (max_hp ' .. nMaxMaxHp .. ') is now within 2x of the '
        .. SENTINEL .. ' sentinel.  That is still unreachable but it is no longer '
        .. 'the comfortable margin this verdict was written on -- re-read it.')
end

--- §5.  Why fourteen dead locals survived every push gate this repo has.
tests['5. luacheck is configured to ignore unused locals, so it cannot see section 2'] = function()
    local sRc = read_file('.luacheckrc')
    local sOnly = sRc:match('\nonly%s*=%s*(%b{})')
    assert(sOnly ~= nil,
        '.luacheckrc no longer pins `only`; if the 2xx (unused) warnings are now '
        .. 'enforced, section 2 is enforced by the linter and this file can lose '
        .. 'it -- check before assuming.')
    assert(sOnly:match('"1"') ~= nil and sOnly:match('"2"') == nil,
        '.luacheckrc `only` is now ' .. sOnly .. '.  It used to be {"1"} -- '
        .. 'globals only -- which is the whole reason fourteen dead locals '
        .. 'survived iron rule 6 indefinitely.  If 2xx is on, re-read section 2.')
end

--- §6.  THE HANDOFF PIN, and it pins TWO halves, not one: the same literal one
--- dimension over is BELOW its domain (so the cap is reachable there) AND its
--- consequence is masked by a downstream threshold (so it is still not a bug).
--- ⛔ Not this desk's to fix -- `mode_*` belongs to the strategy group -- and not
--- a hit rate and not a defect claim; see LIMIT (3) in the header.
tests['6. the same 10000 caps a reachable distance, and a downstream threshold masks it'] = function()
    local sPath = 'bots/mode_outpost_generic.lua'
    local sSrc = read_file(sPath)

    local sBody = sSrc:match('function%s+GetClosestOutpost%s*%b()(.-)\nend')
    assert(sBody ~= nil,
        sPath .. ': GetClosestOutpost is gone.  If the picker was rewritten, '
        .. 'the handoff this section pins is DONE -- retire it rather than '
        .. 're-pointing it.')

    local sSeed = sBody:match('local%s+dist%s*=%s*(%-?[%w%.]+)')
    assert(sSeed == tostring(SENTINEL),
        sPath .. ': GetClosestOutpost now seeds `dist` with ' .. tostring(sSeed)
        .. ' instead of ' .. SENTINEL .. '.  That is one of the two fixes the '
        .. 'handoff named -- retire this section.')

    -- No search ring: the candidate set is the two map-static outposts and the
    -- comparison is a full-map unit-to-unit distance.  This is what makes the
    -- seed a cap rather than a value that cannot be reached.
    assert(sBody:match('GetUnitToUnitDistance%s*%(%s*bot%s*,%s*Outposts%[i%]%s*%)%s*<%s*dist') ~= nil,
        sPath .. ': the loop no longer compares an unbounded '
        .. 'GetUnitToUnitDistance against the seed; re-read the handoff before '
        .. 'quoting this section.')

    -- ⭐ THE MASK, and it is the half that keeps this section from being a bug
    -- report.  The sole consumer conjoins `< 3000` onto the SAME returned
    -- distance, so the capped answer (`nil, 10000`, failing the nil test) and
    -- the un-capped answer it would have replaced (distance >= 10000, failing
    -- the threshold) both reach BOT_ACTION_DESIRE_NONE.  Loosen or remove this
    -- conjunct and the cap becomes live -- which is exactly when this red is
    -- worth waking up for.
    --
    -- ⚠️ The threshold is CAPTURED and compared as a number, never matched as a
    -- literal, and that is not fastidiousness: the first version of this
    -- assertion pattern-matched `<%s*3000` and mutstand M16 -- which loosens the
    -- conjunct to `< 30000`, the mutation that makes the cap LIVE -- SURVIVED it,
    -- because "3000" is a prefix of "30000".  A guard bought by a mutant, on the
    -- one mutation this section exists to catch.
    local nMask = tonumber(sSrc:match(
        'ClosestOutpost%s*~=%s*nil%s+and%s+ClosestOutpostDist%s*<%s*(%d+)') or '')
    assert(nMask == 3000,
        sPath .. ": the `ClosestOutpostDist < 3000` conjunct that MASKS the cap "
        .. 'now reads ' .. tostring(nMask) .. '.  That mask is the whole reason the reachable cap '
        .. 'in this file is not a defect; with it gone, a bot further than '
        .. SENTINEL .. 'u from both outposts now gets `nil` where it would have '
        .. 'got the far outpost, and the behaviour differs.  Re-read before '
        .. 'loosening this assertion -- it is the finding, not the plumbing.')

    -- And the dimension's own ceiling, off the same corpus section 4 uses:
    -- two buildings further apart than the seed EXIST, which is exactly the
    -- statement that fails for health.
    local tFiles = corpus()
    local nBest = -1
    for _, sFixture in ipairs(tFiles) do
        local fChunk = loadfile(sFixture)
        if fChunk ~= nil then
            local bOk, tFix = pcall(fChunk)
            if bOk and type(tFix) == 'table' and type(tFix.buildings) == 'table' then
                local tB = tFix.buildings
                for i = 1, #tB do
                    for j = i + 1, #tB do
                        if type(tB[i].x) == 'number' and type(tB[j].x) == 'number' then
                            local dx, dy = tB[i].x - tB[j].x, tB[i].y - tB[j].y
                            local d = math.sqrt(dx * dx + dy * dy)
                            if d > nBest then nBest = d end
                        end
                    end
                end
            end
        end
    end

    assert(nBest > SENTINEL,
        'the widest building pair in the corpus is now only ' .. string.format('%.1f', nBest)
        .. 'u apart, which no longer exceeds the ' .. SENTINEL .. ' seed.  The '
        .. 'asymmetry this section exists to state (health ceiling BELOW the '
        .. 'seed, map ceiling ABOVE it) cannot be read off this corpus any more.')
end

return tests
