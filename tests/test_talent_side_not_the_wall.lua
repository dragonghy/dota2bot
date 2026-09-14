-- [ratchet] [hero] The talent wall is NOT the side selector: a corpus census
-- that eliminates one named candidate mechanism, and registers the two limits
-- that stop it eliminating a second.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
--
-- ===========================================================================
-- THE QUESTION, AND WHOSE IT IS
-- ===========================================================================
-- GH #817 measured, wave-level, that talent uptake is near zero for some heroes
-- and normal for others; GH #822 measured the banked-point band behind it; and
-- `tests/test_skill_point_stall_frame.lua` settled that the points really are
-- unspent (fork (a)) and that the stall is one head-of-line block in
-- bots/ability_item_usage_generic.lua.  What none of the three settles is WHICH
-- of the dispatcher's own conditions the stuck head fails.  GH #799's acceptance
-- 1 narrowed the survivors to two -- `IsHidden()` or the level requirement --
-- and wrote that the last step "cannot be paid offline (the mock's
-- GetTalentList answers eight nils)".
--
-- That last sentence is true of the MOCK.  It is not true of the corpus, and
-- this file is the part of the question the corpus can answer.
--
-- THE CANDIDATE THIS FILE KILLS.  `aba_skill.X.GetTalentBuild` turns a hero
-- file's own `tTalentTreeList` row into an INDEX into `sTalentList`, and the
-- mapping is inverted relative to the naive reading of the row: `{0, 10}` takes
-- index 1 and `{10, 0}` takes index 2 (hero_crystal_maiden.lua's own talent
-- block states the convention: "t25 {0,10} -> {10,0}: sTalentList[8]").  An
-- index that names a talent the hero cannot train at level 10 would be a
-- complete, self-contained explanation of the wall: the queue's tenth entry
-- would fail the level requirement forever, and everything behind it with it.
-- And because the two sides of a tier are DIFFERENT talents, a defect of that
-- shape would have to show up as a difference BETWEEN the two sides.
--
-- IT DOES NOT.  Over the whole fixture corpus, restricted to hero bodies that
-- are past the t10 tier by at least one level and whose hero the dumper is
-- PROVEN able to show a talent for (section 1):
--
--     side 1 (row `{0, n}`, index 1)   37 of 56 carry a talent   0.661
--     side 2 (row `{n, 0}`, index 2)   50 of 77 carry a talent   0.649
--     ------------------------------------------------------------------
--     both                             87 of 133                 0.654
--
-- All four cells of the 2x2 are occupied, and the two shares differ by 1.2
-- percentage points.  Whatever holds 46 of those 133 bodies at zero talents,
-- it is not the side the hero file selects.  Section 3 states that as the
-- four-cells claim rather than as the 1.2pp, on purpose: a cell count is a sum
-- over fixtures and can only grow, so "both sides produce both outcomes"
-- survives corpus growth, while a gap between two shares does not (GH #106 /
-- #127, corpus_scale.lua).
--
-- ===========================================================================
-- THE TWO LIMITS, ASSERTED RATHER THAN PROSED
-- ===========================================================================
-- LIMIT A -- VISIBILITY.  "This body carries no talent" and "this body's
-- talents are invisible to the dumper" are the same row.  GH #817's [hero]
-- comment names three heroes whose selected t10 row it judged dumper-invisible,
-- so the confusion is live, not hypothetical.  The census therefore counts a
-- hero only when some body of that hero SOMEWHERE in the corpus is seen
-- carrying a trained talent -- a visibility witness, built out of the corpus
-- itself and needing no hero-by-hero folklore.  Today that keeps 16 of the 41
-- hero names; the other 25 contribute nothing and are REGISTERED as contributing
-- nothing (section 5) rather than silently folded into the "no talent" column.
--
-- LIMIT B -- NO ab/ba STRATIFICATION EXISTS HERE (iron rule 4(i-a)).  These
-- bodies come from many different games, trees and dates, and a fixture carries
-- no arm leg at all.  So this is a per-body proportion with NO ab/ba reading,
-- and that is registered as an absence.  Anybody comparing it against an
-- armed-wave number must re-stratify from scratch.
--
-- LIMIT C -- AND IT DISAGREES WITH GH #817's HEADLINE.  #817 reads talent
-- uptake as "a constant that takes a value per hero".  In this corpus it is
-- not: `npc_dota_hero_lina` shows BOTH outcomes at level >= 11 (2 bodies with a
-- talent, 19 without), so at least one hero's uptake varies within the corpus.
-- Section 4 pins that, and it is a handoff, not a correction: #817's corpus is
-- eight games on one tree, this one is 125 fixtures across many, and the two
-- readings can both be right about their own material.  What must not happen is
-- the two sitting side by side with nobody noticing they disagree.
--
-- ===========================================================================
-- WHAT SURVIVES
-- ===========================================================================
-- `IsHidden()` and the level requirement both survive, and so does a third
-- possibility this census cannot see: that the queue entry is not FAILING at
-- all but RESOLVING TO NIL -- `sTalentList` being short at hero-file load time
-- would put a nil at list index 10, and GH #286's hole drain then removes it
-- with no level-up and no warning.  That one is not in #799's survivor set
-- because #799 was reasoning about a head that fails, not a head that is not
-- there.  Registering it here is the whole reason this file says what it
-- eliminated AND what it did not.

package.path = 'tests/?.lua;' .. package.path
local cs = require('corpus_scale')

-- ---------------------------------------------------------------------------
-- The reading.
-- ---------------------------------------------------------------------------

local FIXTURE_ROOT = 'tests/fixtures'

local function read_file(sPath)
    local f = io.open(sPath, 'r')
    if f == nil then return nil end
    local s = f:read('*a')
    f:close()
    return s
end

local function fixture_paths()
    local t = {}
    -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
    -- Recursive on purpose: tests/fixtures/ grew subdirectories (skillstall/),
    -- and a top-level-only `ls` would drop them while still reporting a number.
    local p = assert(io.popen("find " .. FIXTURE_ROOT .. " -name '*.lua' | sort"))
    for sLine in p:lines() do
        t[#t + 1] = sLine
    end
    p:close()
    return t
end

--- Every hero body in the corpus, as { fixture, name, level, talents }.
--- `talents` counts entries whose name starts with the engine's own
--- `special_bonus` prefix -- the dumper's own filter key, so it classifies
--- nothing (the reasoning is test_skill_point_stall_frame.lua's).
local function hero_bodies()
    local out, nFiles = {}, 0
    for _, sPath in ipairs(fixture_paths()) do
        nFiles = nFiles + 1
        local ok, fx = pcall(dofile, sPath)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if type(u) == 'table'
                    and type(u.name) == 'string' and u.name:match('^npc_dota_hero_')
                    and type(u.level) == 'number'
                    and type(u.abilities) == 'table'
                then
                    local nTalents = 0
                    for _, ab in ipairs(u.abilities) do
                        if type(ab) == 'table' and type(ab.name) == 'string'
                            and ab.name:match('^special_bonus')
                        then
                            nTalents = nTalents + 1
                        end
                    end
                    out[#out + 1] = {
                        fixture = sPath, name = u.name,
                        level = u.level, talents = nTalents,
                    }
                end
            end
        end
    end
    return out, nFiles
end

--- The set of hero names the dumper is PROVEN able to show a talent for.
local function visibility_witnesses(tBodies)
    local seen = {}
    for _, b in ipairs(tBodies) do
        if b.talents > 0 then seen[b.name] = true end
    end
    return seen
end

--- hero unit name -> its bots/BotLib file, or nil.  Two spellings are tried
--- because the repo uses both (`hero_skeleton_king.lua` keeps the underscores,
--- `hero_vengefulspirit.lua` drops them).
local botlib_index
local function botlib_path(sUnitName)
    if botlib_index == nil then
        botlib_index = {}
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
        local p = assert(io.popen('ls bots/BotLib'))
        for sName in p:lines() do
            local sHero = sName:match('^hero_(.+)%.lua$')
            if sHero ~= nil then botlib_index[sHero] = 'bots/BotLib/' .. sName end
        end
        p:close()
    end
    local sSuffix = sUnitName:match('^npc_dota_hero_(.+)$')
    if sSuffix == nil then return nil end
    return botlib_index[sSuffix] or botlib_index[(sSuffix:gsub('_', ''))]
end

--- The hero file's own t10 row, as the literal pair it ships.
local function t10_row(sSrc)
    local sBody = sSrc:match('local tTalentTreeList = {(.-)\n}')
    if sBody == nil then return nil end
    local a, b = sBody:match("%['t10'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}")
    if a == nil then return nil end
    return tonumber(a), tonumber(b)
end

--- sTalentList index the SHIPPED selector takes for t10 -- driven through the
--- real J.Skill.GetTalentBuild, not a paraphrase of its arithmetic.  The other
--- three tiers are filled with the same row so the call is well-formed; only
--- entry [1] is read.
local real_GetTalentBuild
local function t10_index(nA, nB)
    if real_GetTalentBuild == nil then
        local api = require('mock.bot_api')
        api.reset_modules()
        api.install({ bot = api.MakeHero('npc_dota_hero_crystal_maiden') })
        local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
        real_GetTalentBuild = J.Skill.GetTalentBuild
    end
    local tRow = { t10 = { nA, nB }, t15 = { nA, nB }, t20 = { nA, nB }, t25 = { nA, nB } }
    return real_GetTalentBuild(tRow)[1]
end

--- The 2x2, over bodies at level >= nBand whose hero has a visibility witness.
local function census(tBodies, nBand)
    local tWitness = visibility_witnesses(tBodies)
    local cells = { [1] = { yes = 0, no = 0 }, [2] = { yes = 0, no = 0 } }
    local nSkippedUnwitnessed, nSkippedNoFile = 0, 0
    for _, b in ipairs(tBodies) do
        if b.level >= nBand then
            if not tWitness[b.name] then
                nSkippedUnwitnessed = nSkippedUnwitnessed + 1
            else
                local sPath = botlib_path(b.name)
                local sSrc = sPath ~= nil and read_file(sPath) or nil
                local nA, nB
                if sSrc ~= nil then nA, nB = t10_row(sSrc) end
                if nA == nil then
                    nSkippedNoFile = nSkippedNoFile + 1
                else
                    local nIdx = t10_index(nA, nB)
                    local cell = cells[nIdx]
                    assert(cell ~= nil, 'J.Skill.GetTalentBuild returned t10 index '
                        .. tostring(nIdx) .. ' for row {' .. nA .. ', ' .. nB .. '} -- this '
                        .. 'census is built on the index being 1 or 2; re-read the selector')
                    if b.talents > 0 then cell.yes = cell.yes + 1 else cell.no = cell.no + 1 end
                end
            end
        end
    end
    return cells, nSkippedUnwitnessed, nSkippedNoFile
end

-- ---------------------------------------------------------------------------

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The instrument: it reaches the corpus, and it can see a talent.
-- ---------------------------------------------------------------------------
tests['[hero] the talent reading reaches the whole fixture corpus'] = function()
    local tBodies, nFiles = hero_bodies()
    cs.corpus(nFiles, 'fixture files swept (recursive)')
    cs.ratchet(#tBodies, 1160, 'hero bodies read out of the corpus')

    -- POSITIVE CONTROL, and it is the one that matters: the reading is not
    -- blind.  Take the body this file names in prose and read it directly.
    local fx = assert(dofile('tests/fixtures/f_212636_tide_ancient.lua'),
        'the named witness fixture no longer loads')
    local nSeen = 0
    for _, u in ipairs(fx.units) do
        if u.name == 'npc_dota_hero_lion' then
            assert(u.level == 10, 'the named lion witness is no longer at hero level 10 ('
                .. tostring(u.level) .. ') -- re-pick the witness, do not loosen this')
            for _, ab in ipairs(u.abilities) do
                if type(ab.name) == 'string' and ab.name:match('^special_bonus') then
                    nSeen = nSeen + 1
                end
            end
        end
    end
    assert(nSeen == 1, 'the reading no longer sees the one trained talent on the named lion '
        .. 'witness (saw ' .. nSeen .. '); every "0 talents" count in this file is only '
        .. 'meaningful while this control passes')
end

-- ---------------------------------------------------------------------------
-- 2. The selector is the shipped one, and both of its answers occur.
-- ---------------------------------------------------------------------------
tests['[hero] the t10 side is driven through the real J.Skill.GetTalentBuild'] = function()
    -- The convention, stated by the shipped function rather than by this file:
    -- a ZERO in the first slot takes index 1, a non-zero takes index 2.
    assert(t10_index(0, 10) == 1,
        'J.Skill.GetTalentBuild no longer maps {0, n} to sTalentList index 1 -- the whole '
        .. 'census below is keyed on that mapping, and hero_crystal_maiden.lua`s talent '
        .. 'block states it in prose; both have to move together')
    assert(t10_index(10, 0) == 2,
        'J.Skill.GetTalentBuild no longer maps {n, 0} to sTalentList index 2')

    -- And both answers are actually shipped by hero files in the corpus, so
    -- the 2x2 below is not a 2x1 wearing a disguise.
    local tBodies = hero_bodies()
    local tSides = { [1] = 0, [2] = 0 }
    local tSeenHero = {}
    for _, b in ipairs(tBodies) do
        if not tSeenHero[b.name] then
            tSeenHero[b.name] = true
            local sPath = botlib_path(b.name)
            local sSrc = sPath ~= nil and read_file(sPath) or nil
            local nA, nB
            if sSrc ~= nil then nA, nB = t10_row(sSrc) end
            if nA ~= nil then
                local nIdx = t10_index(nA, nB)
                tSides[nIdx] = tSides[nIdx] + 1
            end
        end
    end
    assert(tSides[1] >= 1 and tSides[2] >= 1,
        'the corpus`s hero files no longer ship both t10 sides (index 1: ' .. tSides[1]
        .. ', index 2: ' .. tSides[2] .. ') -- with one side only, the census below '
        .. 'cannot eliminate anything and must not be read as if it had')
end

-- ---------------------------------------------------------------------------
-- 3. THE FALSIFICATION.  Both sides produce both outcomes.
-- ---------------------------------------------------------------------------
tests['[hero] the t10 side selector does not separate talent uptake'] = function()
    local tBodies = hero_bodies()
    local cells = census(tBodies, 11)

    local nTotal = cells[1].yes + cells[1].no + cells[2].yes + cells[2].no
    local nYes = cells[1].yes + cells[2].yes

    -- The claim, in the form that survives an appended fixture: every cell of
    -- the 2x2 is occupied.  Each cell is a sum over fixtures, so this is a
    -- ratchet in four parts and cannot be undone by growth -- only by a
    -- behaviour change or a lost fixture.
    cs.ratchet(cells[1].yes, 37, 'side 1, carries a talent')
    cs.ratchet(cells[1].no, 19, 'side 1, carries none')
    cs.ratchet(cells[2].yes, 50, 'side 2, carries a talent')
    cs.ratchet(cells[2].no, 27, 'side 2, carries none')

    -- The shares, registered as the numbers the finding was written on
    -- (iron rule 4(iii): the cut comes with the effect size).  Today:
    -- side 1 = 37/56 = 0.661, side 2 = 50/77 = 0.649, both = 87/133 = 0.654.
    -- The bands are wide because a share, unlike a cell, may move in either
    -- direction as the corpus grows; they are not the claim, section 3's four
    -- ratchets are.
    cs.share(cells[1].yes, cells[1].yes + cells[1].no, 0.35, 0.90,
        'side 1 talent uptake at level >= 11', 30)
    cs.share(cells[2].yes, cells[2].yes + cells[2].no, 0.35, 0.90,
        'side 2 talent uptake at level >= 11', 30)
    cs.share(nYes, nTotal, 0.40, 0.85, 'talent uptake at level >= 11, both sides', 80)

    -- And the headline the census is really about, kept in the same section so
    -- it cannot be quoted without its denominator: a third of the witnessed
    -- bodies past the tier carry nothing at all.
    cs.ratchet(nTotal - nYes, 46, 'witnessed bodies at level >= 11 carrying NO talent')
end

-- ---------------------------------------------------------------------------
-- 4. Controls, and the disagreement with GH #817 (LIMIT C).
-- ---------------------------------------------------------------------------
tests['[hero] control: nothing below the tier carries a talent'] = function()
    local tBodies = hero_bodies()
    local nBelow, nBelowWithTalent = 0, 0
    for _, b in ipairs(tBodies) do
        if b.level < 10 then
            nBelow = nBelow + 1
            if b.talents > 0 then nBelowWithTalent = nBelowWithTalent + 1 end
        end
    end
    cs.ratchet(nBelow, 838, 'hero bodies below hero level 10')
    -- A talent below level 10 is impossible in Dota, so a non-zero here is the
    -- reading being wrong -- not a finding about bots.
    assert(nBelowWithTalent == 0,
        nBelowWithTalent .. ' hero bodies below hero level 10 carry a trained talent. That '
        .. 'is impossible in the game, so the `special_bonus` reading is picking up '
        .. 'something that is not a talent -- every count in this file is void until it is')
end

tests['[hero] LIMIT C: uptake is NOT a per-hero constant in this corpus'] = function()
    local tBodies = hero_bodies()
    local nYes, nNo = 0, 0
    for _, b in ipairs(tBodies) do
        if b.name == 'npc_dota_hero_lina' and b.level >= 11 then
            if b.talents > 0 then nYes = nYes + 1 else nNo = nNo + 1 end
        end
    end
    cs.ratchet(nYes, 2, 'lina bodies at level >= 11 WITH a talent')
    cs.ratchet(nNo, 19, 'lina bodies at level >= 11 WITHOUT a talent')
    -- Both outcomes on one hero, one hero file, one t10 row.  The day this goes
    -- red because `nYes` climbed is not a problem; the day it goes red because
    -- the corpus lost the two witnesses, the disagreement with GH #817's
    -- "constant per hero" headline is no longer evidenced and must be re-taken
    -- before anyone quotes it.
    assert(nYes >= 1 and nNo >= 1,
        'lina no longer shows both outcomes at level >= 11 -- this is the only thing in '
        .. 'this file that contradicts GH #817`s per-hero-constant reading')
end

-- ---------------------------------------------------------------------------
-- 5. LIMIT A / B, registered as numbers rather than as prose.
-- ---------------------------------------------------------------------------
tests['[hero] LIMIT A: what the visibility witness excludes is counted'] = function()
    local tBodies = hero_bodies()
    local tWitness = visibility_witnesses(tBodies)

    local tNames, nNames, nWitnessed = {}, 0, 0
    for _, b in ipairs(tBodies) do
        if not tNames[b.name] then
            tNames[b.name] = true
            nNames = nNames + 1
            if tWitness[b.name] then nWitnessed = nWitnessed + 1 end
        end
    end
    cs.ratchet(nNames, 41, 'distinct hero names in the corpus')
    cs.ratchet(nWitnessed, 16, 'hero names with a visibility witness')
    assert(nWitnessed < nNames,
        'every hero name now has a visibility witness. That is good news and it RETIRES '
        .. 'LIMIT A -- re-read the census without the witness filter rather than leaving '
        .. 'this assertion to pass vacuously')

    local _, nSkippedUnwitnessed, nSkippedNoFile = census(tBodies, 11)
    -- The excluded bodies are counted, not dropped: an exclusion nobody counts
    -- is the shape in which a census quietly becomes a different census.
    cs.ratchet(nSkippedUnwitnessed, 1, 'bodies at level >= 11 excluded by LIMIT A')
    assert(nSkippedNoFile == 0,
        nSkippedNoFile .. ' witnessed bodies at level >= 11 have no readable t10 row in '
        .. 'bots/BotLib. That is a hero file this repo ships and cannot parse -- fix the '
        .. 'reader or the file, do not let the census shrink around it')
end

tests['[hero] LIMIT B: no ab/ba stratification exists for this reading'] = function()
    -- Iron rule 4(i-a) asks for both strata to be registered.  Here there are
    -- none: a fixture is a frame out of one game, and it carries no arm leg.
    -- Asserting the ABSENCE is the disclosure -- a reading that silently has no
    -- strata looks exactly like one whose strata agreed.
    local fx = assert(dofile('tests/fixtures/f_212636_tide_ancient.lua'))
    for _, sKey in ipairs({ 'arm', 'armed', 'leg', 'side', 'stratum' }) do
        assert(fx[sKey] == nil,
            'fixtures now carry a `' .. sKey .. '` field. If that is an arm leg, this '
            .. 'census can and must be stratified, and LIMIT B in the header is retired')
    end
end

return tests
