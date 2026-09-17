-- [hero] [ratchet] `WEAKHPSEED`: the weakest-enemy health seed is a FAMILY, not
-- a literal -- fourteen sites, one quantity, one byte-identical idiom, and TWO
-- seeds a factor of ten apart.  And the ratchet that retired the first of them
-- guards a quantity that trips 1.15x from here while the quantity that actually
-- decides has 3.87x of room.
--
-- ZERO behaviour change.  No line of `bots/` or `game/` moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.  The
-- only non-test edit it carries is the FAILURE TEXT of one assertion in
-- `tests/test_cm_weakest_sentinel_domain.lua` (section 4 below pins it); the
-- trip point of that assertion is NOT moved.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- Last round retired one member of this family (`X.cm_GetWeakestUnit`'s `10000`,
-- `state.json:cmweaksent_20260917`, DO-NOT-ARM) and left as its number-one next
-- candidate a census of the whole family: "约 60 个有限 min/max 种子的遮罩普查
-- -- 全队没人数过这个族".  This round counted it.  Three things came back that
-- the single-site pricing could not see:
--
--   (1) The family is 201, not ~60, and its majority is the OTHER polarity.
--       Reader definition (stated because the number is only meaningful with
--       it): a bare `local <name> = <number>` line under `bots/`, with |number|
--       >= 1000, followed within 40 lines by both a comparison against <name>
--       and a reassignment of <name>.  That reader finds 201 sites: 77
--       cap/min-search (`< seed`, the shape all three priced samples had) and
--       124 floor/max-search (`> seed`).  ⛔ THAT 201 IS NOT RATCHETED HERE and
--       deliberately so: it is a census over `bots/` source, not over
--       append-only fixtures, so a floor on it reddens for whichever desk next
--       refactors a hero file -- the GH #624 structural-red shape.  It is a
--       reading, and it lives in this header where a reading belongs.
--
--   (2) ⭐⭐ THE HEADLINE.  Narrow to ONE quantity -- an enemy's CURRENT health,
--       seeded for a weakest-of-list scan -- and the sites are provably
--       interchangeable, yet the seeds are not:
--
--           local npcWeakestEnemyHealth = 100000   axe, slardar, rubick/axe  (3)
--           local npcWeakestEnemyHealth =  10000   dazzle, lina, lion, luna,
--                                                  ogre_magi, phantom_assassin,
--                                                  riki, warlock             (8)
--
--       Eleven sites.  At every one of the eleven the name occurs EXACTLY THREE
--       times in comment-stripped source -- the seed, one strict `<`, one
--       reassignment -- so the local is provably never read after the loop and
--       the seed's ONLY effect is the cap.  The domain is therefore identical at
--       all eleven sites, which means the factor of ten CANNOT have been chosen
--       by the domain.  It was chosen by the copy lineage.  Section 1 asserts
--       the universality; section 2 prices every seed in the set against the
--       corpus rather than against its neighbours.
--
--       ⚠️ Two of the eleven are this desk's charter: `hero_axe.lua:1792` (the
--       loose seed) and `hero_lion.lua:1716` (the tight one, guarding the
--       finger-of-death teamfight exit).  The other nine are named so the count
--       is honest, and nothing here asserts over a file this desk cannot fix.
--
--   (3) ⭐⭐ THE FINDING, and it is one fat fixture away, not hypothetical.
--       A cap of this shape sits at the bottom of a THREE-RUNG ladder, and the
--       committed ratchet has rung one only:
--
--         rung 1  does any unit reach the seed?      -> the cap REJECTS someone
--         rung 2  is the MINIMUM over the eligible   -> the cap can remove the
--                 set at or above the seed?             argmin
--         rung 3  ...and does that leave the set     -> THE DECISION CHANGES
--                 empty?
--
--       Rung 1 is necessary, nowhere near sufficient, and it is the only one
--       `tests/test_cm_weakest_sentinel_domain.lua` section 4 measures -- over
--       the corpus ceiling `max_hp`, with a margin clause `nMaxMaxHp * 2 <
--       SENTINEL`.  That clause trips at max_hp 5000.  The corpus ceiling is
--       4343.  It is **1.15x** from red, and a Turbo Bristleback two HP items
--       later gets there.  When it goes, its text tells the next desk that
--       "Reading B just became reachable and the DO-NOT-ARM verdict must be
--       re-decided" -- while rung 2 is at 2585 against a 10000 seed, **3.87x**
--       of room, and rung 3 has never been within reach at all (section 3: the
--       corpus holds 310 live per-team hero groups and NOT ONE of size 1).
--
--       ⇒ So the wire trips 3.4x earlier than the decision, and when it trips it
--       misinstructs.  ⛔ THE FIX IS NOT TO LOOSEN IT.  A rung-1 crossing is
--       real news (the cap starts rejecting units, and `cs` doctrine is explicit
--       that a zero-content claim must redden on its first counter-example).
--       The fix is that the re-decision must have rungs 2 and 3 in hand when it
--       arrives, and that the failure text must not promise a verdict is void
--       when it is only unproven.  This round: rungs 2 and 3 measured here,
--       trip point there UNCHANGED, failure text there corrected, and section 4
--       pins both halves so neither can silently revert.
--
-- ⭐ WHAT MAKES THE DEAD-LOCAL CLAIM A STATEMENT ABOUT THE FILES -- section 5.
-- "Eleven sites, zero reads after the loop" is a statement about the READER
-- until the same reader finds a site that DOES read after the loop.  It does:
-- `nWeakestUnitLowestHealth`, the same quantity and the same idiom under a
-- different name, occurs at three sites with EXACTLY FOUR occurrences each --
-- the fourth being `return nWeakestUnit, nWeakestUnitLowestHealth`, i.e. the
-- escaping sentinel that already carries a gated id elsewhere (`cmrangedhp`).
-- Three at four, eleven at three, one reader.  Without section 5 the census is
-- a tautology -- the exact way last round's M12 mutant survived.
--
-- ⛔ LIMITS (load-bearing, do not drop when quoting this file)
-- 1. Sections 3's corpus readings are a SAMPLE, not a proof.  Turbo (~20 min)
--    is why the ceiling sits where it does; a 60-minute normal-mode game can
--    put a fully-slotted carry over a 10000 seed.  ⛔ Never write "impossible".
-- 2. Rung 2 is measured over LIVE hero rows of one team, which is a SUPERSET of
--    the eligible set each shipped loop actually scans (every loop adds its own
--    predicates).  A superset's minimum is a LOWER bound on the eligible
--    minimum, so a rung-2 reading below the seed does NOT prove the eligible
--    minimum is below it.  What section 3 therefore asserts is the direction
--    that IS sound -- the distance to rung 1's trip point versus rung 2's --
--    and never "the decision domain is empty" as a proved claim.
-- 3. Nothing here re-opens `state.json:cmweaksent_20260917`.  That verdict is
--    argued from rung 1 being EMPTY (zero rows at or above the seed), which is
--    sufficient on its own and is unaffected by everything above.

package.path = 'tests/?.lua;' .. package.path

local scan = require('lua_source_scan')
local cs = require('corpus_scale')

--- The seed under discussion in the sibling that was already retired.
local SENTINEL = 10000

--- The dead-local family: one quantity, one idiom, one name.
local DEAD_NAME = 'npcWeakestEnemyHealth'
--- The escaping control (section 5).  Same quantity, same idiom, returned.
local LIVE_NAME = 'nWeakestUnitLowestHealth'

--- Occurrence counts that define the two shapes.  A dead local is seed +
--- compare + reassign; the control adds the `return`.
local DEAD_OCCURRENCES = 3
local LIVE_OCCURRENCES = 4

--- Anti-vacuity floors on the source sweeps.  These are NOT the measured counts
--- (11 and 3) -- they carry slack, because a source census that reddens when
--- another desk deletes an unrelated hero's block hands its red to whoever
--- pushes next (GH #624).  The load-bearing assertion is the UNIVERSALITY over
--- whatever the sweep finds; these floors only stop a broken sweep from
--- agreeing with everything.
local MIN_DEAD_SITES = 8
local MIN_LIVE_SITES = 2

--- The two sites this desk has charter over.  Named rather than counted: if the
--- sweep stops resolving, a floor of 8 can still be met by eight other files
--- while the two that matter have gone missing.
local CHARTER_SITES = {
    'bots/BotLib/hero_axe.lua',
    'bots/BotLib/hero_lion.lua',
}

--- The file whose section 4 this one is about.
local SIBLING_TEST = 'tests/test_cm_weakest_sentinel_domain.lua'

--- Corpus floors.  Fixtures are append-only, so these ratchet.
local MIN_CORPUS_FILES = 150
local MIN_HERO_ROWS = 1500
local MIN_GROUPS = 300
--- The smallest live per-team hero group the corpus has ever shown.  Rung 3
--- needs a group of ONE to be able to empty; this is the distance to that.
local MIN_GROUP_SIZE = 2
--- ⭐ A FLOOR on rung 2 itself, and it exists because this file had the very
--- defect it reports: every §3 assertion guarded rung 2 from ONE SIDE.  A rung-2
--- reading that is too LOW makes every margin here look safer than it is, and
--- nothing caught it -- mutant M11 (admit dead rows, whose hp is 0, into the
--- groups) dragged the reading down and the file stayed green.  Rung 2 is a MAX
--- over append-only fixtures, so it can only rise: a fall means the grouping
--- broke or the liveness filter went, never corpus growth.
local MIN_RUNG_2 = 2585
--- Dead hero rows the liveness filter throws out of the rung-2/3 grouping.
--- Asserting the filter's EFFECT is what makes it load-bearing -- see the note
--- at the ratchet in §3.  This round: 114 dead of 1550 rows (1436 live).
local MIN_DEAD_ROWS_EXCLUDED = 114

local tests = {}

-- ---------------------------------------------------------------- source sweep

--- Every `local <name> = <number>` seed site for `sName`, with the number and
--- the count of comment-stripped occurrences of the name in that file.
---
--- The occurrence count is taken over the WHOLE file, not a window.  That is
--- what makes "dead local" provable rather than probable: three occurrences in
--- the whole file, one of which is the declaration, leaves no room for a read
--- anywhere else in it.  A windowed reader could only ever say "no read within
--- N lines".
--- ⚠️ ONE walk over `bots/`, both names at once, and that is a cost decision
--- with a recorded reason: the first version called this once per name, which
--- walked ~500 shipped files and stripped every line of them TWICE.  At 1.19s
--- that row would have moved `budget_seconds` 520.0 -> 530.0 under the derived
--- rule (`2 x the measured sub-cap total, rounded UP to 10s`), and the manifest's
--- own notes are explicit that the budget is DERIVED, not chosen, and that
--- shaving the recorded number to fit is the forbidden move.  So the file got
--- cheaper instead.
local tSweepMemo = nil
local function sweep_all()
    if tSweepMemo ~= nil then return tSweepMemo end
    local tNames = { DEAD_NAME, LIVE_NAME }
    local tOut = {}
    for _, sName in ipairs(tNames) do tOut[sName] = {} end
    for _, sPath in ipairs(scan.bots_files()) do
        local tLines = nil
        for _, sName in ipairs(tNames) do
            local nOccurrences, nSeedLine, nSeed = 0, nil, nil
            local bCompare, bReassign = false, false
            -- Cheap pre-filter: strip the file only if the raw text can match.
            -- ⚠️ This is sound in ONE direction only and that is the direction
            -- needed: stripping comments can never ADD an occurrence, so a file
            -- whose raw text lacks the name lacks it after stripping too.
            if tLines == nil then
                tLines = scan.stripped_lines(sPath)
            end
            for i, sLine in ipairs(tLines) do
                if sLine:find(sName, 1, true) ~= nil then
                    -- One line may hold the name more than once; count each.
                    local nFrom = 1
                    while true do
                        local s = sLine:find(sName, nFrom, true)
                        if s == nil then break end
                        nOccurrences = nOccurrences + 1
                        nFrom = s + #sName
                    end
                    local sNum = sLine:match('^%s*local%s+' .. sName
                        .. '%s*=%s*(%-?%d+%.?%d*)%s*$')
                    if sNum ~= nil then
                        nSeedLine, nSeed = i, tonumber(sNum)
                    end
                    if sLine:find('<%s*' .. sName) ~= nil then bCompare = true end
                    if sLine:match('^%s*' .. sName .. '%s*=%s*') ~= nil then
                        bReassign = true
                    end
                end
            end
            if nSeedLine ~= nil then
                local t = tOut[sName]
                t[#t + 1] = {
                    path = sPath, line = nSeedLine, seed = nSeed,
                    occurrences = nOccurrences,
                    compare = bCompare, reassign = bReassign,
                }
            end
        end
    end
    tSweepMemo = tOut
    return tOut
end

local function sweep(sName)
    return sweep_all()[sName]
end

-- ---------------------------------------------------------------- corpus sweep

--- The committed fixture corpus, read the way the sibling test reads it.
local tCorpusMemo = nil
local function corpus()
    if tCorpusMemo ~= nil then return tCorpusMemo end
    local tFiles = {}
    local hPipe = assert(io.popen("find tests -type f -name 'f_*.lua' -print | sort"))
    for sLine in hPipe:lines() do tFiles[#tFiles + 1] = sLine end
    hPipe:close()

    local r = {
        files = #tFiles, rows = 0,
        max_hp = -1, max_max_hp = -1, where = '',
        above_4k = 0, at_or_above_seed = 0,
        groups = 0, max_of_min = -1, min_group_size = math.huge,
        group_where = '', dead_excluded = 0,
    }
    for _, sPath in ipairs(tFiles) do
        local fChunk = loadfile(sPath)
        if fChunk ~= nil then
            local bOk, tFix = pcall(fChunk)
            if bOk and type(tFix) == 'table' and type(tFix.units) == 'table' then
                local tByTeam = {}
                for _, tUnit in ipairs(tFix.units) do
                    if type(tUnit.name) == 'string'
                        and tUnit.name:match('^npc_dota_hero_')
                        and type(tUnit.hp) == 'number'
                    then
                        r.rows = r.rows + 1
                        if tUnit.hp > r.max_hp then r.max_hp = tUnit.hp end
                        if type(tUnit.max_hp) == 'number' and tUnit.max_hp > r.max_max_hp then
                            r.max_max_hp = tUnit.max_hp
                            r.where = sPath .. ' :: ' .. tUnit.name
                        end
                        if tUnit.hp >= 4000 then r.above_4k = r.above_4k + 1 end
                        if tUnit.hp >= SENTINEL then
                            r.at_or_above_seed = r.at_or_above_seed + 1
                        end
                        -- rung 2/3: live rows only, grouped by team.  A dead row
                        -- is not a unit any shipped loop can pick (GH #794).
                        if tUnit.alive ~= false then
                            local sTeam = tostring(tUnit.team)
                            tByTeam[sTeam] = tByTeam[sTeam] or {}
                            table.insert(tByTeam[sTeam], tUnit.hp)
                        else
                            r.dead_excluded = r.dead_excluded + 1
                        end
                    end
                end
                for sTeam, tHps in pairs(tByTeam) do
                    local nMin = math.huge
                    for _, h in ipairs(tHps) do if h < nMin then nMin = h end end
                    r.groups = r.groups + 1
                    if #tHps < r.min_group_size then r.min_group_size = #tHps end
                    if nMin > r.max_of_min then
                        r.max_of_min = nMin
                        r.group_where = sPath .. ' team=' .. sTeam .. ' n=' .. #tHps
                    end
                end
            end
        end
    end
    tCorpusMemo = r
    return r
end

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- §1.  The family is interchangeable: every site a provably dead local.
tests['1. every weakest-health seed site is a dead local, all of them'] = function()
    local tSites = sweep(DEAD_NAME)

    assert(#tSites >= MIN_DEAD_SITES,
        'the sweep found only ' .. #tSites .. ' `' .. DEAD_NAME .. '` seed '
        .. 'sites; this round found 11 and the floor is ' .. MIN_DEAD_SITES
        .. '.  A universality claim over a sweep that stopped resolving is a '
        .. 'claim about the reader.')

    local tFound = {}
    for _, tSite in ipairs(tSites) do tFound[tSite.path] = tSite end
    for _, sPath in ipairs(CHARTER_SITES) do
        assert(tFound[sPath] ~= nil,
            'this desk\'s own site ' .. sPath .. ' is no longer found by the '
            .. 'sweep.  A floor of ' .. MIN_DEAD_SITES .. ' can be met by eight '
            .. 'other heroes while the two under charter have gone missing, '
            .. 'which is why they are named and not counted.')
    end

    -- The load-bearing assertion: ALL of them, not N of them.  Stronger than a
    -- count, and it keeps speaking about the copies nobody has made yet.
    for _, tSite in ipairs(tSites) do
        assert(tSite.compare, tSite.path .. ':' .. tSite.line .. ' seeds `'
            .. DEAD_NAME .. '` but the sweep found no `< ' .. DEAD_NAME
            .. '` comparison -- the idiom is not what this file describes, '
            .. 're-read it before trusting any count here.')
        assert(tSite.reassign, tSite.path .. ':' .. tSite.line .. ' seeds `'
            .. DEAD_NAME .. '` but never reassigns it; that is not a '
            .. 'weakest-of-list scan.')
        assert(tSite.occurrences == DEAD_OCCURRENCES,
            tSite.path .. ':' .. tSite.line .. ' now holds '
            .. tSite.occurrences .. ' occurrences of `' .. DEAD_NAME
            .. '` (seed + compare + reassign is ' .. DEAD_OCCURRENCES .. ').  '
            .. 'A fourth occurrence means the sentinel ESCAPES the loop at this '
            .. 'site, so the seed is no longer only a cap: it can be read as a '
            .. 'health belonging to no unit, which is the `cmrangedhp` defect '
            .. 'shape.  Price this site on its own -- do not raise this number.')
    end
end

--- §2.  The seeds, priced against the corpus instead of against each other.
tests['2. every seed in the family clears the corpus by a margin'] = function()
    local tSites = sweep(DEAD_NAME)
    local r = corpus()

    local tDistinct, nDistinct, nTightest = {}, 0, math.huge
    for _, tSite in ipairs(tSites) do
        assert(type(tSite.seed) == 'number' and tSite.seed > 0,
            tSite.path .. ':' .. tSite.line .. ' seed did not parse as a '
            .. 'positive number (' .. tostring(tSite.seed) .. ')')
        if tDistinct[tSite.seed] == nil then
            tDistinct[tSite.seed] = 0
            nDistinct = nDistinct + 1
        end
        tDistinct[tSite.seed] = tDistinct[tSite.seed] + 1
        if tSite.seed < nTightest then nTightest = tSite.seed end
    end

    -- ⭐ The spread is REPORTED, not asserted.  Asserting ">= 2 distinct seeds"
    -- would redden the day somebody unifies them -- i.e. it would redden on the
    -- fix.  What is asserted is the property that matters at every seed
    -- whatever its value: it must clear the quantity that decides.
    assert(nDistinct >= 1, 'no seeds parsed at all')

    -- Rung 2, the statistic the cap must clear before it can remove an argmin.
    assert(r.max_of_min > 0, 'rung 2 did not measure (no live hero groups)')
    assert(nTightest > 3 * r.max_of_min,
        'the tightest seed in the family is ' .. nTightest .. ' and the corpus '
        .. 'rung-2 reading (the largest per-team MINIMUM live hero hp) is now '
        .. r.max_of_min .. ' at ' .. r.group_where .. ', so the margin has '
        .. 'fallen inside 3x.  ' .. nDistinct .. ' distinct seed(s) are in this '
        .. 'family; the tight one is the one that breaks first and it is on a '
        .. 'focus hero (hero_lion.lua, the finger teamfight exit).  Re-price the '
        .. 'family -- do not raise the seed to make this pass.')
end

--- §3.  The three-rung ladder, measured.  Rung 1 is what the sibling test pins;
--- rungs 2 and 3 are what a re-decision will need and nobody had.
tests['3. the ladder: rung 1 empty, rung 2 far, rung 3 never in reach'] = function()
    local r = corpus()

    assert(cs.corpus(r.files, 'f_*.lua corpus') >= MIN_CORPUS_FILES,
        'the corpus walk found only ' .. r.files .. ' fixture files; floor '
        .. MIN_CORPUS_FILES)
    cs.ratchet(r.rows, MIN_HERO_ROWS, 'hero rows in the corpus')
    cs.ratchet(r.groups, MIN_GROUPS, 'live per-team hero groups')

    -- Anti-vacuity FIRST, for the same reason the sibling test needs it: every
    -- "nothing reaches X" below is satisfied for free by a reader that parsed no
    -- health at all.
    assert(r.above_4k >= 1,
        'not one hero row in the corpus reaches 4000 hp, so every bound in this '
        .. 'section is vacuous -- it would hold for a reader that parsed '
        .. 'nothing.  Fix the parse before reading any ceiling.')

    -- Rung 1.  This is the claim `state.json:cmweaksent_20260917` rests on, and
    -- it is an EMPTY-SET claim, so it stays an equality (cs doctrine: a
    -- zero-content claim must redden on its first counter-example).
    assert(r.at_or_above_seed == 0,
        r.at_or_above_seed .. ' hero row(s) in the corpus now sit at or above '
        .. 'the ' .. SENTINEL .. ' seed, so rung 1 is no longer empty: the cap '
        .. 'has started REJECTING units.  That is real news and this assertion '
        .. 'is meant to deliver it.  ⛔ It does NOT by itself void the '
        .. 'DO-NOT-ARM verdict -- read rungs 2 and 3 below before re-deciding.')

    -- ⭐ Rung 2 from BELOW.  Everything else in this section reads rung 2 from
    -- above ("it is far from the seed"), which a too-low reading satisfies for
    -- free -- see MIN_RUNG_2.  Ratchet, because rung 2 is a max over
    -- append-only fixtures and can only rise.
    cs.ratchet(r.max_of_min, MIN_RUNG_2,
        'rung 2 (largest per-team MINIMUM live hero hp)')

    -- ⭐ ...and the liveness filter itself, asserted by its EFFECT rather than
    -- by its presence.  ⚠️ The MIN_RUNG_2 ratchet above does NOT cover this and
    -- the mutant proved it: rung 2 is a MAX over groups, so admitting corpses
    -- (hp 0) lowers the minima of the groups that HAVE a corpse while leaving
    -- the arg-max group -- which has none -- exactly where it was.  A filter is
    -- load-bearing only where it actually excludes something, so count what it
    -- excludes.  Ratchet: corpses arrive with fixtures and never leave.
    cs.ratchet(r.dead_excluded, MIN_DEAD_ROWS_EXCLUDED,
        'dead hero rows excluded from the rung-2/3 groups')

    -- Reader sanity.  A per-group MINIMUM can never exceed the global maximum;
    -- if it does, the grouping is broken, not the corpus.
    assert(r.max_of_min <= r.max_hp,
        'rung 2 (' .. r.max_of_min .. ') exceeds the global current-hp ceiling ('
        .. r.max_hp .. ').  A minimum over a subset cannot exceed the maximum '
        .. 'over the whole; the grouping is broken.')

    -- Rung 3.  The cap can only change a decision by emptying the candidate
    -- set, which needs the last eligible enemy to be over the seed.  The corpus
    -- has never shown a live per-team hero group smaller than this.
    assert(r.min_group_size >= MIN_GROUP_SIZE,
        'the corpus now holds a live per-team hero group of size '
        .. r.min_group_size .. ' (floor ' .. MIN_GROUP_SIZE .. ').  Rung 3 needs '
        .. 'a group the cap can empty, and a group of one is the first step '
        .. 'toward it -- re-read rung 3 rather than lowering this floor.')
end

--- §4.  ⭐ The finding, as an assertion: the committed wire trips before the
--- decision does, and both halves of this round's correction are pinned.
tests['4. rung 1 trips earlier than rung 2, and the sibling text says so'] = function()
    local r = corpus()
    local sSrc = read_file(SIBLING_TEST)

    -- (a) The sibling's trip point must still be where it was.  This round did
    -- NOT loosen it and this assertion is what stops a later round from
    -- "fixing" the false red by moving the bound instead of the text.
    assert(sSrc:find('nMaxMaxHp * 2 < SENTINEL', 1, true) ~= nil,
        SIBLING_TEST .. ' no longer carries its `nMaxMaxHp * 2 < SENTINEL` '
        .. 'margin clause.  This file\'s whole finding is that that clause trips '
        .. 'early and misinstructs, and that the remedy is the TEXT, not the '
        .. 'trip point.  If the bound was moved, the finding was answered the '
        .. 'one way it must not be.')

    -- (b) ...and its failure text must carry the correction, so the next desk
    -- to read a rung-1 red is not told a verdict is void when it is unproven.
    --
    -- ⚠️ The first version of this asserted only that the word "rung" appeared
    -- SOMEWHERE in the file, and mutant M13 walked straight through it: the
    -- correction also added a comment block that says "rung" a dozen times, so
    -- the word survives the removal of the one sentence that matters.  What is
    -- asserted now is the POINTER a reader of a rung-1 red actually needs -- the
    -- file and section holding rungs 2 and 3 -- inside the failure text itself.
    --
    -- ⚠️ AND THE SECOND VERSION WAS STILL TOO WEAK: it asserted the POINTER
    -- alone, while M13 removes the words "rungs 2 and 3" and leaves the pointer
    -- standing -- so the text became "read the corpus in <file> §3", a citation
    -- attached to the same overstatement.  Both halves are asserted now.
    -- ⚠️ As two SEPARATE contiguous fragments, not one joined sentence: what is
    -- read here is the sibling's SOURCE TEXT, and there the sentence is split
    -- across a Lua `..` concatenation, so a find() of the joined phrase matches
    -- nothing and would have passed vacuously -- a third version of the same
    -- mistake, caught only because the fragment is the thing M13 mutates.
    local sLadder = 'read rungs 2 and 3 in '
    local sPointer = 'tests/test_weakhp_seed_family.lua §3'
    assert(sSrc:find(sLadder, 1, true) ~= nil,
        SIBLING_TEST .. ' no longer tells a rung-1 red to "' .. sLadder
        .. '".  Its red used to instruct the reader that "the DO-NOT-ARM '
        .. 'verdict must be re-decided", with no rung-2 or rung-3 reading '
        .. 'anywhere in the repo to re-decide it from; naming the ladder is '
        .. 'what fixed that.  A file that still says the word "rung" somewhere '
        .. 'is NOT the same thing -- that is exactly what mutant M13 proved.')
    assert(sSrc:find(sPointer, 1, true) ~= nil,
        SIBLING_TEST .. ' no longer points at "' .. sPointer .. '", so the '
        .. 'ladder it names has no address and the reader is back where the '
        .. 'overstatement left them.')
    assert(sSrc:find('does NOT on its own', 1, true) ~= nil,
        SIBLING_TEST .. ' no longer says that a rung-1 crossing does NOT on its '
        .. 'own void the verdict.  That clause IS the correction; the pointer '
        .. 'above without it just adds a citation to the same overstatement.')

    -- (c) The finding itself.  Distance-to-trip, rung 1 versus rung 2:
    --   rung 1 margin clause trips at SENTINEL/2  -> ratio (SENTINEL/2)/max_max_hp
    --   rung 2 has no clause; it would matter at   -> ratio SENTINEL/max_of_min
    -- so "the wire trips first" is exactly max_of_min < 2 * max_max_hp.
    local nTrip1 = (SENTINEL / 2) / r.max_max_hp
    local nTrip2 = SENTINEL / r.max_of_min
    assert(nTrip1 < nTrip2, string.format(
        'the ordering this file reports has flipped: rung 1 is now %.2fx from '
        .. 'its trip point (ceiling max_hp %g) and rung 2 is %.2fx from '
        .. 'mattering (largest per-team minimum %g).  When rung 2 becomes the '
        .. 'nearer of the two, the cap is genuinely approaching a decision and '
        .. 'the family needs re-pricing -- that is news, not a broken test.',
        nTrip1, r.max_max_hp, nTrip2, r.max_of_min))
end

--- §5.  Anti-vacuity for section 1: the SAME reader finds an escaping site.
tests['5. the same reader finds the escaping control at four occurrences'] = function()
    local tLive = sweep(LIVE_NAME)

    assert(#tLive >= MIN_LIVE_SITES,
        'the control sweep found only ' .. #tLive .. ' `' .. LIVE_NAME
        .. '` sites (floor ' .. MIN_LIVE_SITES .. ', this round 3).  Without a '
        .. 'site that DOES read its sentinel after the loop, section 1\'s '
        .. '"eleven dead locals" is a statement about this reader and not about '
        .. 'the files -- which is exactly how last round\'s M12 mutant survived.')

    for _, tSite in ipairs(tLive) do
        assert(tSite.occurrences == LIVE_OCCURRENCES,
            tSite.path .. ':' .. tSite.line .. ' holds ' .. tSite.occurrences
            .. ' occurrences of `' .. LIVE_NAME .. '`, not ' .. LIVE_OCCURRENCES
            .. '.  The control group is the escaping shape (seed + compare + '
            .. 'reassign + `return`); if it stopped escaping, the discriminator '
            .. 'between the two shapes is gone and section 1 must find another.')
    end

    -- The discriminator, stated: the two shapes must actually differ.  If both
    -- families reported the same count, the reader is measuring nothing.
    local tDead = sweep(DEAD_NAME)
    assert(#tDead > 0 and DEAD_OCCURRENCES ~= LIVE_OCCURRENCES,
        'the dead and escaping shapes are no longer distinguishable by '
        .. 'occurrence count; find another discriminator before quoting '
        .. 'section 1.')
end

return tests
