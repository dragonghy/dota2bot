-- [hero] [ratchet] The H1/H2 fork of GH #260, settled -- and settled offline,
-- on a frame this repo already holds.  2026-08-27.  Zero behaviour change,
-- zero gate.
--
-- Tagged [ratchet] on purpose, so the fast detector subset every stream runs
-- carries it: the day somebody fixes the dumper, section 4 goes red and says
-- what to re-read.  A verdict built on an instrument's blind spot has to hear
-- about it when the blind spot closes.
--
-- WHERE THIS COMES FROM
-- ---------------------
-- GH #260 read every frozen frame in tests/fixtures/ (105 fixtures, 960
-- hero-frames): 67 talent sightings, every one a GENERIC row, and ZERO
-- `special_bonus_unique_*` on any hero at any level.  It then refused to choose
-- between two accounts that a dump cannot separate:
--
--   H1 INSTRUMENT  isRealAbility() in tools/batch_test/behavioral/dumper/main.go
--                  discards any entity whose class name contains
--                  `Special_Bonus_Base` / `Special_Bonus_Attributes` BEFORE the
--                  branch that keeps leveled talents.  Hero-unique talents have
--                  no dedicated engine class, so they are all Special_Bonus_Base
--                  -- and the surviving names in the corpus are indeed CLASS
--                  names (`special_bonus_h_p200`, never the KV's
--                  `special_bonus_hp_200`).
--   H2 WORLD       the bots never train a unique talent; the point is unspent.
--
-- The consequences differ by an order of magnitude -- under H2 the five
-- TALENTPRICE rounds priced rows nobody takes, and Axe's and Wraith King's
-- shipped t10 picks are both on that side -- so the desk filed queue request
-- `hero-21` to buy a re-dump.
--
-- WHAT SETTLES IT WITHOUT THE RE-DUMP
-- The corpus GH #260 could reach tops out at hero level 19, because every batch
-- game self-terminated at a 10-minute economy cap (GH #84's zero, retired by
-- owner priority P3 / GH #108).  The FIRST post-cap frame -- t=1382.2 of a
-- 24.9-minute naturally-ended turbo game, GH #235 -- holds ten heroes at levels
-- 22 to 27, and it is sitting in the repo right now, parked in
-- iterations/pending/ behind GH #236.  Reading a parked file costs nothing.
--
--   ten hero-slots, levels 22-27
--   talent points the shipped level-up queue has spent by then :  36
--   talent rows the frame actually shows                       :   8
--   ... every one of them a generic row; unique rows           :   0
--
-- H2 CANNOT PRODUCE THAT.  H2 says the bots pick generic rows; a hero that
-- picked four generic rows shows four rows.  Three of these ten heroes show
-- ZERO while standing at levels 24, 25 and 25.  Whatever else is true, the
-- instrument is dropping talents that were trained -- 28 of 36, and 12 of 20
-- even on the conservative reading that counts only the t10 and t15 tiers.
-- H1 is not merely the surviving account, it is SUFFICIENT: the drop rule in
-- main.go explains the whole deficit with no assumption about the world at all.
--
-- WHAT THAT BUYS, CONCRETELY
--   * The five TALENTPRICE rounds are NOT invalidated.  The fear they were
--     priced against -- "we priced rows the bots never take" -- was H2, and H2
--     is what just failed.
--   * Every "no frame confirms this talent fired" bound those rounds carried
--     stays true, and now has a REASON rather than an open fork:
--     tests/test_wk_bone_guard_talent_bypass.lua, hero_skeleton_king.lua.
--   * `hero-21` does not close, it NARROWS: the re-dump no longer buys the
--     fork, it buys WHICH rows.  Section 6 pins that so the request is not read
--     as answered.
--
-- HONEST BOUNDS -- read before quoting
--   * ONE frame, ONE game.  The 36 is not a survey; it is what ten hero-slots
--     in a single 24.9-minute game must have spent.  Nothing here is a rate.
--   * `must` is a MODEL, not an observation: it says the level-up queue
--     (section 1) reaches talent k at hero level 10/15/20/25 because the engine
--     block `botLevel >= GetHeroLevelRequiredToUpgrade()` is what holds the head
--     of the queue.  A queue stalled for some other reason lowers `must` and
--     shrinks the deficit -- which is exactly why section 3 also asserts the
--     conservative floor that only uses t10 and t15.
--   * The mechanism (section 4) is read off main.go's source, not measured.  A
--     dropped entity leaves no trace in the dump by construction, so no fixture
--     can ever witness the drop; what section 4 pins is that the code still says
--     what the account needs it to say.
--   * The snapshot is parked-file data.  When GH #236's ordering lands and the
--     fixture moves into tests/fixtures/, the census re-derives the same rows
--     from the new location and this file does not move.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local FRAME = require('mock.lategame_talent_frame')

local DUMPER = 'tools/batch_test/behavioral/dumper/main.go'
local TIERS = { 10, 15, 20, 25 }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Talents trained by hero level, under the queue model section 1 pins.
local function must_by_level(level, tiers)
    local n = 0
    for _, t in ipairs(tiers or TIERS) do
        if level >= t then n = n + 1 end
    end
    return n
end

local function totals(tiers)
    local must, seen, unique, maxrows = 0, 0, 0, 0
    for _, s in ipairs(FRAME.slots) do
        must = must + must_by_level(s.level, tiers)
        seen = seen + #s.rows
        if #s.rows > maxrows then maxrows = #s.rows end
        for _, r in ipairs(s.rows) do
            if r:find('special_bonus_unique_', 1, true) == 1 then unique = unique + 1 end
        end
    end
    return must, seen, unique, maxrows
end

-- ---------------------------------------------------------------------------
-- 0. Anti-vacuum.  EVERY headline in this file is of the form "a count is
--    short", which is what an empty snapshot satisfies for free -- and the
--    sibling round already watched a census print the right sentence off a
--    regex that matched nothing.  So: the snapshot has to be there, has to be
--    self-consistent, and has to be late-game.

tests['[hero] the late-game snapshot is present, self-consistent and late'] = function()
    assert(type(FRAME.slots) == 'table' and #FRAME.slots == 10,
        'the snapshot holds ' .. tostring(FRAME.slots and #FRAME.slots)
        .. ' hero-slots, recorded 10 (one frozen frame = ten heroes). Re-run: '
        .. 'python3 tools/agent/lategame_talent_census.py')

    -- Self-consistency: the recorded `seen` column against the rows it claims
    -- to summarise.  A snapshot whose columns disagree with its own data is the
    -- one thing every assertion below would inherit silently.
    local seen_col, rows_len = 0, 0
    for _, s in ipairs(FRAME.slots) do
        assert(#s.rows == s.seen, s.hero .. ' records seen=' .. s.seen
            .. ' but carries ' .. #s.rows .. ' row name(s); the snapshot '
            .. 'disagrees with itself and nothing below can be trusted')
        assert(s.must == must_by_level(s.level),
            s.hero .. ' at level ' .. s.level .. ' records must=' .. s.must
            .. ', but the tier model says ' .. must_by_level(s.level)
            .. '. One of the two was hand-edited')
        seen_col = seen_col + s.seen
        rows_len = rows_len + #s.rows
    end
    assert(seen_col == rows_len and seen_col == 8,
        'the snapshot sums to ' .. seen_col .. ' talent rows, recorded 8')

    for _, s in ipairs(FRAME.slots) do
        assert(s.level >= 20, s.hero .. ' is at level ' .. s.level
            .. '; this file only says anything at all about slots past level '
            .. '20, the band the 10-minute batch cap used to hide (GH #84, '
            .. 'retired by GH #108 / GH #235). A sub-20 row here means the '
            .. 'snapshot was taken from the wrong frame')
    end

    assert(FRAME.corpus and FRAME.corpus.slots and FRAME.corpus.slots > 500,
        'the census reports only ' .. tostring(FRAME.corpus and FRAME.corpus.slots)
        .. ' hero-slots corpus-wide, so the eight rows below are a sample-size '
        .. 'story rather than a shortfall. The tool refuses to report under its '
        .. 'own floors; this is the same floor, asserted where it is read')
end

-- ---------------------------------------------------------------------------
-- 1. The queue model, driven through the SHIPPED function rather than restated.
--
--    `must` is the load-bearing column and it is not observed, so the thing it
--    rests on gets executed here: X.GetSkillList's placement of the talent
--    picks.  (The lesson is a paid one -- a sibling test re-implemented the
--    scanner it meant to check, and deleting the real code left it green.)

tests['[hero] the shipped skill list parks the four talent picks after level 10'] =
function()
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_skeleton_king') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    -- A 15-entry ability build (the shape every focus hero ships) and the
    -- eight-entry talent list GetTalentBuild returns: four picks then the four
    -- mirrored rows.
    local sAbilityList = { 'a1', 'a2', 'a3', 'a4', 'a5', 'ult' }
    local nAbilityBuildList = { 1, 2, 1, 3, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 }
    local sTalentList = { 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8' }
    local nTalentBuildList = J.Skill.GetTalentBuild({
        t10 = { 0, 10 }, t15 = { 0, 10 }, t20 = { 10, 0 }, t25 = { 0, 10 },
    })

    assert(#nTalentBuildList == 8,
        'GetTalentBuild returned ' .. #nTalentBuildList .. ' entries, not 8. '
        .. 'The queue positions below are computed from that length')

    local list = J.Skill.GetSkillList(sAbilityList, nAbilityBuildList,
        sTalentList, nTalentBuildList)

    local talent_at = {}
    for i = 1, #nAbilityBuildList + #nTalentBuildList do
        if list[i] and list[i]:match('^T%d$') then talent_at[#talent_at + 1] = i end
    end

    -- The first four entries are the PICKS (one per tier); the rest are the
    -- mirrored rows, which the engine refuses because the tier is already spent.
    assert(#talent_at >= 4, 'the shipped skill list holds only ' .. #talent_at
        .. ' talent entries; expected at least the four picks')
    assert(talent_at[1] == 10 and talent_at[2] == 15,
        'the first two talent picks sit at queue positions '
        .. talent_at[1] .. ' and ' .. talent_at[2] .. ', recorded 10 and 15. '
        .. 'The whole `must` column is the claim that the queue reaches talent '
        .. 'k no later than the tier that unlocks it -- re-derive it before '
        .. 'quoting any deficit in this file')
    assert(talent_at[3] > 15 and talent_at[4] > talent_at[3],
        'the third and fourth talent picks are at ' .. tostring(talent_at[3])
        .. ' and ' .. tostring(talent_at[4]) .. '; they must follow the t15 pick')

    -- ...and the reason a queue position EARLIER than the tier is still not a
    -- talent trained early: the level-up caller holds the head of the queue on
    -- the engine's own requirement.
    -- Read the CONDITION of the branch that trains, not the file: the same
    -- string also appears in the "still try it" fallback below it, so a scan of
    -- the whole file goes on passing after the real gate is gone (mutation M6,
    -- which escaped exactly that way before this was narrowed).
    local src = read_file('bots/ability_item_usage_generic.lua')
    local cond = src:match(
        'if not abilityToLevelup:IsHidden%(%)(.-)then%s*\n%s*bot:ActionImmediate_LevelAbility')
    assert(cond, 'bots/ability_item_usage_generic.lua no longer has a branch '
        .. 'that guards ActionImmediate_LevelAbility with an IsHidden() test; '
        .. 'the level-up path was restructured and the `must` column has to be '
        .. 're-derived against whatever replaced it')
    assert(cond:find('botLevel >= abilityToLevelup:GetHeroLevelRequiredToUpgrade()', 1, true),
        'the branch that actually levels an ability no longer gates on '
        .. 'GetHeroLevelRequiredToUpgrade(). That gate is what turns queue '
        .. 'position 18 into "trained at hero level 20"; without it the `must` '
        .. 'column means something else entirely')
    assert(cond:find('CanAbilityBeUpgraded', 1, true),
        'the training branch no longer asks CanAbilityBeUpgraded(). That is '
        .. 'what stops the four MIRRORED talent rows (queue positions 20-23) '
        .. 'from being counted as trained talents')
end

-- ---------------------------------------------------------------------------
-- 2. The deficit itself.

tests['[hero] the late-game frame hides 28 of the 36 talents it must have spent'] =
function()
    local must, seen = totals()
    assert(must == 36, 'the ten slots must have spent ' .. must
        .. ' talent points, recorded 36')
    assert(seen == 8, 'the frame shows ' .. seen .. ' talent rows, recorded 8')
    assert(must - seen == 28, 'the deficit reads ' .. (must - seen)
        .. ', recorded 28. If this has fallen to 0 the dumper was fixed: that '
        .. 'is GOOD news and the whole corpus talent story should be re-read '
        .. 'from a fresh census, not patched here')
end

tests['[hero] H2 is refuted by a hero that shows FEWER rows than tiers passed'] =
function()
    -- The single assertion the verdict rests on.  H2 (the bots never train a
    -- unique talent) still predicts one visible row per tier passed, because a
    -- generic pick is exactly what H2 says they take.  A hero showing fewer
    -- rows than tiers is outside what H2 can produce, whatever it picked.
    local short = {}
    for _, s in ipairs(FRAME.slots) do
        if #s.rows < must_by_level(s.level) then
            short[#short + 1] = s.hero .. ' (lvl ' .. s.level .. ': '
                .. #s.rows .. ' of ' .. must_by_level(s.level) .. ')'
        end
    end
    table.sort(short)
    assert(#short == 10, 'only ' .. #short .. ' of the ten slots show fewer '
        .. 'talent rows than tiers they passed, recorded 10 -- ALL of them, '
        .. 'which is what makes this a property of the pipeline rather than of '
        .. 'particular heroes: ' .. table.concat(short, ', '))

    -- The sharpest three: a hero can pick a unique row at every tier, but it
    -- cannot pick a row and leave the dump with nothing at all.
    local empty = 0
    for _, s in ipairs(FRAME.slots) do
        if #s.rows == 0 and s.level >= 24 then empty = empty + 1 end
    end
    assert(empty >= 3, 'only ' .. empty .. ' hero(es) at level >= 24 show NO '
        .. 'talent row at all, recorded 3 (jakiro 24, necrolyte 25, venomancer '
        .. '24). Those three are what makes this an instrument story rather '
        .. 'than a story about which rows the builds prefer')
end

tests['[hero] the verdict survives on t10+t15 alone'] = function()
    -- The conservative reading, for a reader who disbelieves the queue model:
    -- count only the two tiers passed long before any stall could still be
    -- pending.  It is a weaker number and it still refutes H2.
    local must, seen = totals({ 10, 15 })
    assert(must == 20, 'the t10+t15 floor reads ' .. must .. ', recorded 20')
    assert(must - seen == 12, 'the conservative deficit reads ' .. (must - seen)
        .. ', recorded 12. This is the number to quote when the queue model is '
        .. 'the thing under dispute')
end

-- ---------------------------------------------------------------------------
-- 3. The unique blindness is not a low-level artefact.

tests['[hero] zero unique rows even at levels 22-27'] = function()
    local _, _, unique = totals()
    assert(unique == 0, unique .. ' hero-unique talent row(s) are now visible in '
        .. 'the late-game frame, recorded 0. That is the dumper answering a '
        .. 'question it could not answer before: re-run the census and re-read '
        .. 'GH #260, tests/test_fixture_talent_blindness.lua and every "no '
        .. 'frame can confirm this" bound written on top of them')

    -- The band matters: GH #260's zero could have been "these heroes are too
    -- low to have reached a unique tier".  At 22-27 every one of them has
    -- passed t20, where unique rows are the majority of the tree.  (The old
    -- reading that no turbo hero-slot gets there at all is GH #84's, retired
    -- 2026-08-27 by GH #235 -- this frame is the retirement.)
    local past_t20 = 0
    for _, s in ipairs(FRAME.slots) do
        if s.level >= 20 then past_t20 = past_t20 + 1 end
    end
    assert(past_t20 == 10, past_t20 .. ' of the ten slots are past t20, '
        .. 'recorded 10; below that the zero above is a level artefact again')
end

-- ---------------------------------------------------------------------------
-- 4. The mechanism, pinned in the source it lives in.
--
--    A dropped entity leaves no trace in a dump, so this can only ever be a
--    source read.  What it buys: the day somebody fixes main.go, this test
--    fails and says so, instead of the corpus quietly becoming trustworthy
--    while every verdict written on the old blindness stays on the shelf.

tests['[hero] the dumper still drops Special_Bonus_Base before keeping talents'] =
function()
    local src = read_file(DUMPER)

    -- The FUNCTION BODY, not the file.  The doc comment above isRealAbility
    -- names both strings in the right order and never moves, so a scan of the
    -- raw file reads the documentation back and calls the code correct --
    -- mutation M7 reordered the two real branches and escaped exactly there.
    local body = src:match('func isRealAbility%b()%s*bool%s*{(.-)\n}')
    assert(body, DUMPER .. ' no longer defines isRealAbility(...) bool. That '
        .. 'function IS the account this file rests on; find what replaced it '
        .. 'and re-read the census before quoting any zero from the corpus')

    local drop = body:find('Special_Bonus_Base', 1, true)
    local keep = body:find('Special_Bonus"', 1, true)
    assert(drop, DUMPER .. ' no longer mentions Special_Bonus_Base. If the '
        .. 'unconditional drop is gone the corpus may have stopped being blind '
        .. 'to unique talents -- re-run tools/agent/lategame_talent_census.py '
        .. 'and re-read this whole file before deleting it')
    assert(keep and drop < keep,
        'the Special_Bonus_Base drop no longer precedes the branch that keeps '
        .. 'leveled talents in ' .. DUMPER .. '. The ordering IS the account: '
        .. 'the drop line only ever does work on an entity that is already '
        .. 'leveled, since an untrained talent falls out on `level > 0` anyway')

    -- The corroborating detail, and the reason the account is about CLASS names
    -- and not KV names: what survives is snake-cased from the class.
    assert(src:find('Name:%s*snakeFromClass%(cn'),
        DUMPER .. ' no longer derives the EMITTED ability name from the class '
        .. 'name (the snakeFromClass(cn, ...) call at the abilitySnap site). '
        .. 'The evidence that the surviving rows are classes -- the corpus '
        .. 'carries `special_bonus_h_p200`, never the KV `special_bonus_hp_200` '
        .. '-- rests on that call')
end

-- ---------------------------------------------------------------------------
-- 5. A published inference this frame corrects, recorded rather than quietly
--    dropped.

tests['[hero] a single slot carries TWO talent rows -- the cap was a level artefact'] =
function()
    local _, _, _, maxrows = totals()
    assert(maxrows == 2, 'the busiest late-game slot carries ' .. maxrows
        .. ' talent rows, recorded 2 (dragon_knight at level 26). GH #260 read '
        .. '"no frame ever carries two talents" over tests/fixtures/, and that '
        .. 'reading is still correct THERE -- what it was not is a property of '
        .. 'the pipeline. One row per hero was the 10-minute cap again')
end

-- ---------------------------------------------------------------------------
-- 6. Recorded, NOT tested: what `hero-21` still buys.
--
-- The queue request filed on 2026-08-27 asks for a re-dump with the drop rule
-- lifted, to separate H1 from H2.  That fork is closed here, so the request is
-- narrowed rather than answered: what a re-dump still buys is WHICH unique rows
-- the bots take -- the one reading that could tell a TALENTPRICE round whether
-- the row it priced is the row the game got.  Nothing offline can answer that:
-- an entity the dumper dropped is not in the file to be counted.

return tests
