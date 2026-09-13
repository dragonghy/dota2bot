-- [hero] [ratchet] The skill-point wall, carried from ONE frame to the FIVE focus
-- heroes' own build rows -- and what it does to the third rank of every focus
-- ultimate, to every `sTalentList[3..8]` handle in the tree, and to `cullthresh`.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- GH #366 / tests/test_skill_point_stall_frame.lua settled a fork with a frame:
-- ten heroes at hero level 17-22 ALL hold exactly THIRTEEN ability points and at
-- most ONE talent, rank multiset {4,4,3,2}, ten for ten across two teams and ten
-- different hero scripts.  That reading was quoted straight afterwards to RETIRE
-- an older premise ("GH #84 read level >= 20 on 0 of 210 hero-slots, so the late
-- tiers are dead weight in turbo" -- a zero that belonged to the batch harness's
-- 10-minute economy cap, not to turbo; GH #235).  Retiring it was right.
--
-- What replaced it was not.  Four live sites replaced "the tier is never
-- REACHED" with "the tier IS reached, therefore the talent IS trained", and that
-- step is exactly the one #366 forbids: HERO LEVEL is not POINTS SPENT.  The
-- heroes on that frame are level 17-22 -- past the 10, 15 and 20 tiers -- and
-- hold one talent between them at most.  The four sites, all written 2026-08-27
-- or 08-28, in their own words:
--
--   * bots/BotLib/hero_axe.lua      -- "talent7 is LIVE from level 25 [...] the
--                                      fold argument is the only thing holding
--                                      it up"
--   * bots/BotLib/hero_zuus.lua     -- "`talent5:IsTrained()` is TRUE from level
--                                      20 on [...] it is now load-bearing"
--   * tests/test_focus_talent_anchor.lua
--                                   -- "t20 and t25 are live rows, they are
--                                      reached in the order section 6 pins"
--   * tests/test_focus_build_level_legality.lua
--                                   -- the level-17 idle point, registered as a
--                                      NON-DEFECT lasting "exactly one level"
--
-- WHAT IS NEW HERE, and it is not a re-statement of #366
-- -----------------------------------------------------
-- #366's file reads the wall off ONE dump plus the shipped spender.  This one
-- never opens a dump: it drives the shipped J.Skill.GetSkillList with each focus
-- hero's OWN build row and reads what thirteen points buy that hero.  The two
-- readings meet at the multiset, and that meeting is the corroboration:
--
--   * all SIX focus build rows (Zeus ships two) spend their first thirteen
--     points into {4,4,3,2} -- the identical multiset the frame measured on ten
--     unrelated heroes, derived here from source with no dump in the room;
--   * every one of the six puts its ultimate's THIRD point in row entry 15, the
--     last one, so `ranks[6] == 2` for all of them.  Section 2 asserts it.
--
-- Two consequences follow, and they are the reason this is a hero-group file and
-- not a note:
--
--   (A) EVERY `sTalentList[n >= 3]` HANDLE IN THE FOCUS FIVE IS DEAD.  Indices
--       3-8 are the t15/t20/t25 pairs (aba_skill.lua:140; 1-2 are t10).  Section
--       3 censuses them and asserts the property that makes "dead" harmless
--       rather than silent: every read of such a handle sits on a line that also
--       tests `IsTrained()`, so a handle that never answers is a no-op and never
--       a nil or a 0 leaking into arithmetic.  That is a live safety property --
--       `zusboltcap` (GH #175) is what a 0 that leaks looks like.
--
--   (B) `cullthresh` HAS TWO BANDS, NOT THREE.  The registered hero-2 lever
--       replaces Axe's hardcoded `150 + 100*lv` with the KV's 275/375/475, and
--       its own header, the queue row and tools/batch_test/behavioral/
--       cullthresh_domain.py all write the domain as three bands
--       [250,275) / [350,375) / [450,475).  Culling Blade never reaches rank 3,
--       so the third band is an EMPTY STRATUM: a wave that sizes the lever on
--       three bands is sizing a third of it on nothing.  The scanner itself is
--       safe -- it reads rank off the dump and reports a rank histogram -- but
--       the PROSE that tells a reader what to expect is not, and section 4 pins
--       the corrected declaration in the helper header.
--
-- WHAT IS NOT CLAIMED -- read before quoting any of this
-- ------------------------------------------------------
--  1. THE MECHANISM IS STILL UNSETTLED.  #366's file states plainly that WHICH
--     of the spender's three upgrade conditions the parked entry fails cannot be
--     decided offline (the mock's GetTalentList answers eight nils).  Nothing
--     here decides it either.  What this file uses is the MEASUREMENT (thirteen
--     points, ten for ten) plus each hero's own row -- not a mechanism.
--  2. ONE FRAME, ONE GAME, ONE INSTANT.  #366's LIMIT travels with every number
--     taken from it, including the thirteen.  It is the best registered reading
--     this project has and it is one frame.  The sections below are written so
--     the source half stands alone: section 2 measures what thirteen points buy
--     WITHOUT asserting that thirteen is where every game stops, and it names
--     the dependency in its own failure message.
--  3. THE PARK IS NOT PRICED HERE.  How much a permanently-idle ultimate point
--     costs Axe in a Turbo game is a batch question (queue row, not this file).
--  4. A LEAD, RECORDED AS A LEAD.  #366's LIMIT (2) noticed that the six heroes
--     holding a talent hold GENERIC ones and the four holding none are the
--     hero-UNIQUE pickers.  One arithmetic remark this file can add: those four
--     still hold THIRTEEN build points, and thirteen build points sit behind the
--     t10 slot in the queue -- so their t10 entry LEFT the queue without ever
--     training, which is what the spender's third branch does (warn, try,
--     `table.remove` anyway).  That names a candidate mechanism.  It is n=1 on
--     one frame and it is NOT a finding; do not flip a t10 row on it.

package.path = 'tests/?.lua;' .. package.path

local skillmap = require('skill_level_map')

local tests = {}

--- The focus five, with every build row each file ships (Zeus ships two).
local FOCUS = {
    { hero = 'axe',            file = 'bots/BotLib/hero_axe.lua',            rows = 1 },
    { hero = 'zuus',           file = 'bots/BotLib/hero_zuus.lua',           rows = 2 },
    { hero = 'skeleton_king',  file = 'bots/BotLib/hero_skeleton_king.lua',  rows = 1 },
    { hero = 'lion',           file = 'bots/BotLib/hero_lion.lua',           rows = 1 },
    { hero = 'crystal_maiden', file = 'bots/BotLib/hero_crystal_maiden.lua', rows = 1 },
}

--- The measurement this file carries in from GH #366, named once so a reader can
--- see every place it is leaned on.
local STALL_POINTS = 13
local ULT_SLOT = 6

local function src_of(sPath) return skillmap.read_file(sPath) end

--- Lua line comments stripped before any source claim is counted: this file's own
--- subjects are comment-heavy and a parser that reads prose reports the prose
--- (GH #136, and the M7 lesson of 2026-09-13 -- see `flatten` below).
--- Block comments go FIRST: hero_skeleton_king.lua documents its own talent
--- wiring inside a `--[[ ]]` block, and a line-comment stripper leaves that prose
--- standing.  The census in section 3 read one of those sentences as a code line
--- on its first run.
local function strip_comments(sSrc)
    return (sSrc:gsub('%-%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', ''))
end

--- Comment CONTINUATIONS flattened before a prose needle is matched.  A sentence
--- pinned as a substring is invisible the moment somebody re-wraps the paragraph,
--- and re-wrapping is what a person editing a comment naturally does -- the
--- mutation stand of 2026-09-13 (`wkidleshare`, M7) survived on exactly that.
local function flatten(sSrc)
    return (sSrc:gsub('\n%s*%-%-%-?', ' '):gsub('%s+', ' '))
end

-- ---------------------------------------------------------------------------
-- 1. The wall is a property of the SPENDER, read off source.
--
-- Everything below is only interesting because a head the spender cannot level
-- does not get skipped.  If a future edit pops it, the reachable prefix stops
-- being a prefix and every count here changes meaning -- so the shape is
-- asserted, not described.  (test_focus_build_level_legality.lua section 1
-- asserts the same shape for its own reasons; both files depend on it, and a
-- shared assertion that only one file makes is a shared assumption.)
-- ---------------------------------------------------------------------------

tests['1. the spender parks an unspendable head and only pops it above level 25'] = function()
    local sSpender = strip_comments(src_of('bots/ability_item_usage_generic.lua'))

    assert(sSpender:find('local abilityName = sAbilityLevelUpList%[1%]') ~= nil,
        'the spender no longer reads the HEAD of sAbilityLevelUpList; this file '
        .. 'and GH #366 both assume a head-blocking queue.')

    -- Located by the branch's own warning text rather than by brace shape: the
    -- file holds many `else`s and the first draft of this assertion matched one
    -- of them (`kez_*` swap chain) and reported the wrong thing.
    local sRaw = src_of('bots/ability_item_usage_generic.lua')
    local sTail = sRaw:match('print%("%[WARN%] Skipped to level up ability "(.-)\n\tend')
    assert(sTail ~= nil,
        'the spender\'s final else branch could not be located by its own warning '
        .. 'text; re-read bots/ability_item_usage_generic.lua before trusting '
        .. 'anything below.')
    assert(sTail:find('botLevel > 25') ~= nil,
        'the final else no longer guards its pop with `botLevel > 25`.  If an '
        .. 'unspendable head now pops at any level, the queue is no longer '
        .. 'head-blocking and the thirteen-point wall this file is built on is '
        .. 'gone -- re-read GH #366 rather than loosening this.')
    local nPops = select(2, sTail:gsub('table%.remove', ''))
    assert(nPops == 1,
        'the final else branch holds ' .. nPops .. ' table.remove calls, not 1; '
        .. 'a second pop outside the level-25 guard would skip a parked head.')
end

-- ---------------------------------------------------------------------------
-- 2. What THIRTEEN points buy each focus hero, driven off the shipped
--    J.Skill.GetSkillList and each file's own row.
--
-- The skill list interleaves a talent at levels 10 and 15, so thirteen ABILITY
-- points are consumed by list position 14.  ranks_at() drives the real list and
-- counts only the entries that resolve to an ability slot, so the interleave is
-- read rather than re-derived (GH #134).
-- ---------------------------------------------------------------------------

tests['2. all six focus build rows spend thirteen points into {4,4,3,2}'] = function()
    for _, h in ipairs(FOCUS) do
        local src = src_of(h.file)
        local tal = skillmap.talent_rows(src)
        for nRow = 1, h.rows do
            local row = skillmap.build_row(src, nRow)
            local sWho = h.hero .. ' row ' .. nRow

            assert(#row == 15,
                sWho .. ' is a ' .. #row .. '-entry build row; every claim below '
                .. 'is about the standard 15-entry row (3 basics x 4 + ult x 3).')

            local ranks, list, nSpent = skillmap.ranks_at(h.hero, row, tal, 14)

            assert(list[10] == nil and list[15] == nil,
                sWho .. ': the driven skill list no longer puts its talent holes '
                .. 'at positions 10 and 15, so "position 14 = thirteen ability '
                .. 'points" no longer holds.  Re-read aba_skill.lua GetSkillList.')
            assert(nSpent == STALL_POINTS,
                sWho .. ': ' .. nSpent .. ' ability points are spent by skill-list '
                .. 'position 14, not ' .. STALL_POINTS .. '.')

            local tMultiset = {}
            for _, nRank in pairs(ranks) do tMultiset[#tMultiset + 1] = nRank end
            table.sort(tMultiset, function(a, b) return a > b end)
            assert(table.concat(tMultiset, ',') == '4,4,3,2',
                sWho .. ' spends its first ' .. STALL_POINTS .. ' points into {'
                .. table.concat(tMultiset, ',') .. '}, not {4,4,3,2}.  That '
                .. 'multiset is what GH #366 measured on TEN unrelated heroes; '
                .. 'the agreement between one dump and six shipped rows is the '
                .. 'corroboration this file is built on.')
        end
    end
end

tests['2b. every focus ultimate holds its third point in the LAST row entry'] = function()
    for _, h in ipairs(FOCUS) do
        local src = src_of(h.file)
        local tal = skillmap.talent_rows(src)
        for nRow = 1, h.rows do
            local row = skillmap.build_row(src, nRow)
            local sWho = h.hero .. ' row ' .. nRow
            local ranks = skillmap.ranks_at(h.hero, row, tal, 14)

            assert(row[15] == ULT_SLOT,
                sWho .. ': row entry 15 is sAbilityList[' .. tostring(row[15])
                .. '], not the ultimate.  The wall consequence below is about '
                .. 'WHICH ability loses a rank, so it has to be re-read.')
            assert(ranks[ULT_SLOT] == 2,
                sWho .. ': the ultimate holds rank ' .. tostring(ranks[ULT_SLOT])
                .. ' after ' .. STALL_POINTS .. ' points, not 2.')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 3. Every t15/t20/t25 handle in the focus five, and the property that keeps a
--    dead handle harmless.
--
-- sTalentList indices pair up by tier: [1,2] = t10, [3,4] = t15, [5,6] = t20,
-- [7,8] = t25 (aba_skill.lua:140, and hero_skeleton_king.lua's own note).  A
-- hero takes ONE talent per tier, so the unpicked half of a picked tier was
-- already dead; the wall makes BOTH halves of t15/t20/t25 dead.  What matters
-- for correctness is not that they are dead -- it is that nothing reads a value
-- off them without asking IsTrained() first.
-- ---------------------------------------------------------------------------

tests['3. no focus file reads a t15+ talent handle without testing IsTrained()'] = function()
    local nHandles = 0
    for _, h in ipairs(FOCUS) do
        local sBody = strip_comments(src_of(h.file))
        for sVar, sIdx in sBody:gmatch('local (talent%d+)%s*=%s*bot:GetAbilityByName%(%s*sTalentList%[(%d+)%]') do
            if tonumber(sIdx) >= 3 then
                nHandles = nHandles + 1
                for sLine in sBody:gmatch('[^\n]+') do
                    if sLine:find(sVar, 1, true) ~= nil
                        and sLine:find('GetAbilityByName', 1, true) == nil
                        and sLine:find('IsTrained', 1, true) == nil
                    then
                        error(h.file .. ': `' .. sVar .. '` (sTalentList[' .. sIdx
                            .. '], a t' .. (5 * math.ceil(tonumber(sIdx) / 2) + 5)
                            .. ' handle) is read on a line that does not test '
                            .. 'IsTrained():\n    ' .. sLine:gsub('^%s+', '')
                            .. '\nUnder the GH #366 wall that handle is never '
                            .. 'trained, so an unguarded read is a 0 or a nil '
                            .. 'entering arithmetic every frame -- the shape '
                            .. '`zusboltcap` (GH #175) shipped.')
                    end
                end
            end
        end
    end
    assert(nHandles >= 5,
        'the t15+ handle census found only ' .. nHandles .. ' handles across the '
        .. 'focus five; it found 5 when written (axe talent7/talent8, lion '
        .. 'talent5/talent8, zuus talent5/talent7, wk talent6).  A census that '
        .. 'silently stops matching asserts nothing.')
end

-- ---------------------------------------------------------------------------
-- 4. The four sites that replaced one retired premise with another false one,
--    and the `cullthresh` band declaration that follows.
--
-- These are PROSE assertions and they are the weakest kind, which is why each
-- needle is matched against the FLATTENED source: the failure mode of a prose
-- ratchet is not somebody arguing with it, it is somebody re-wrapping the
-- paragraph so the substring stops existing while the wrong sentence survives.
-- ---------------------------------------------------------------------------

local RETIRED_NEEDLES = {
    { file = 'bots/BotLib/hero_axe.lua',
      needle = 'talent7 is LIVE from level 25' },
    { file = 'bots/BotLib/hero_zuus.lua',
      needle = 'is TRUE from level 20 on' },
    { file = 'tests/test_focus_talent_anchor.lua',
      needle = 't20 and t25 are live rows, they are reached' },
    { file = 'tests/test_focus_talent_anchor.lua',
      needle = 'becomes TRUE for the first time at level 25' },
    { file = 'tests/test_focus_build_level_legality.lua',
      needle = 'hold one point idle for exactly one level' },
}

--- A retired sentence may SURVIVE AS A QUOTATION and only as one.  Deleting it
--- outright would erase the record of what was believed and why -- this project's
--- corrections are written as "it used to say X, and here is the defect in X" --
--- but a quotation that has drifted away from its own retraction is just the
--- wrong sentence again.  So the test is positional, not a plain absence: every
--- occurrence must sit inside a QUOTED span and within 500 flattened characters
--- after a retraction marker.  The quote test is the load-bearing half and it is
--- deliberately LOCAL (nearest double quote either side, within 300 characters)
--- rather than a parity scan of the whole file: one stray apostrophe-as-quote
--- anywhere above would silently flip a parity scan's answer for everything
--- below it, which is the failure mode where a ratchet keeps reporting green.
local RETRACTIONS = { 'used to', 'RE-CORRECTED', 'CORRECTED', 'RE-READ' }
local QUOTE_REACH = 300

local function is_quoted(sFlat, nFrom, nTo)
    local sLead = sFlat:sub(math.max(1, nFrom - QUOTE_REACH), nFrom - 1)
    local sTail = sFlat:sub(nTo + 1, nTo + QUOTE_REACH)
    return sLead:find('"[^"]*$') ~= nil and sTail:find('^[^"]*"') ~= nil
end

tests['4. the "level reached therefore talent trained" sentences survive only as quotations'] = function()
    for _, t in ipairs(RETIRED_NEEDLES) do
        local sFlat = flatten(src_of(t.file))
        local nAt, nSeen = 1, 0
        while true do
            local nFrom = sFlat:find(t.needle, nAt, true)
            if nFrom == nil then break end
            nSeen = nSeen + 1
            assert(is_quoted(sFlat, nFrom, nFrom + #t.needle - 1),
                t.file .. ' carries "' .. t.needle .. '" OUTSIDE a quotation.  A '
                .. 'retired sentence may survive as a quoted record of what was '
                .. 'believed; unquoted it is simply the wrong sentence again.')
            local sLead = sFlat:sub(math.max(1, nFrom - 500), nFrom)
            local bRetracted = false
            for _, sMark in ipairs(RETRACTIONS) do
                if sLead:find(sMark, 1, true) ~= nil then bRetracted = true end
            end
            assert(bRetracted,
                t.file .. ' asserts "' .. t.needle .. '" with no retraction in the '
                .. '500 characters before it.  Hero LEVEL is not POINTS SPENT: GH '
                .. '#366 read ten heroes at level 17-22 holding ' .. STALL_POINTS
                .. ' points and at most one talent.  The sentence this needle '
                .. 'names was written on 2026-08-27/28 to replace the retired GH '
                .. '#84 premise and it inherited the same defect from the other '
                .. 'side.  It may stay in the file as a QUOTATION of what was '
                .. 'believed; it may not stand on its own.')
            nAt = nFrom + 1
        end
        assert(nSeen >= 1,
            t.file .. ' no longer contains "' .. t.needle .. '" at all.  This '
            .. 'ratchet is on the RECORD as much as on the claim: a correction '
            .. 'that deletes the retired sentence instead of quoting it leaves the '
            .. 'next reader free to write it again.  Restore the quotation under '
            .. 'its retraction.')
    end
end

tests['4b. hero_axe.lua declares `cullthresh` a TWO-band domain'] = function()
    local sFlat = flatten(src_of('bots/BotLib/hero_axe.lua'))
    assert(sFlat:find('THE THIRD BAND IS AN EMPTY STRATUM', 1, true) ~= nil,
        'the X.IsCullThresholdOn header no longer declares that Culling Blade '
        .. 'cannot reach rank 3, so a reader sizing the hero-2 wave still sees '
        .. 'three bands (250/275, 350/375, 450/475) where only two can be '
        .. 'occupied.  Section 2b is the measurement behind that declaration.')
    assert(sFlat:find('THE `talent8` TERM CAN NEVER FIRE', 1, true) ~= nil,
        'the X.IsCullThresholdOn header no longer states that the double-count '
        .. 'risk it names is unreachable.  With it unreachable the armed/shipped '
        .. 'difference is an unconditional +25 at both reachable ranks, which is '
        .. 'the whole domain declaration the hero-2 wave needs.')
end

return tests
