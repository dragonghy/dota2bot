-- [hero] What the frozen real-frame corpus can SHOW you about trained talents,
-- 2026-08-27.  Zero behaviour change, zero gate: this file registers a LIMIT of
-- the evidence base, not a decision.
--
-- WHY IT EXISTS
-- Five consecutive hero rounds priced talent rows (TALENTPRICE, GH #238 ->
-- #251 -> #255).  Each of them argued from the game's KV and each recorded, as
-- an honest bound, that no frame in this repo shows the talent trained.  Nobody
-- had asked whether a frame in this repo CAN show one.  It cannot, for the half
-- of the tree that matters:
--
--   * 67 talent sightings across 960 hero-frames -- every one of them a GENERIC
--     row (special_bonus_hp_200, ..._attack_damage_25, ..._movement_speed_20).
--   * ZERO hero-unique (`special_bonus_unique_*`) sightings.  On any hero.  At
--     any level.  Including a Viper at hero level 19, who holds three trained
--     talents by the game's own rules.
--   * No frame ever carries more than ONE talent, and the 9 frames at level >=
--     15 -- where the game guarantees at least two -- carry none.
--
-- So a corpus read of "was this unique talent trained?" can only ever come back
-- zero.  That disqualifies a class of argument (it is the same shape as GH #238:
-- the zero is a property of the instrument, not of the world), and it is the
-- whole claim of this file.
--
-- WHAT THIS FILE DELIBERATELY DOES NOT DECIDE
-- Two accounts survive the corpus and they are observationally identical from a
-- dump:
--   H1 INSTRUMENT -- the dumper drops unique talents.  isRealAbility()
--      (tools/batch_test/behavioral/dumper/main.go) discards any entity whose
--      class name contains Special_Bonus_Base / Special_Bonus_Attributes BEFORE
--      the branch that keeps leveled talents -- and that first line only ever
--      does work on an entity that IS leveled, since an untrained talent is
--      already dropped by `level > 0` on the next line.  The surviving names
--      are CLASS names, not KV names (`special_bonus_h_p200`, never the KV's
--      `special_bonus_hp_200`), which is what makes "generic rows have their own
--      C++ class, unique rows share a base class" a live account.
--   H2 WORLD -- the bots never train a unique talent; the point is unspent.
-- The consequences differ enormously (H1: every corpus talent read is blind.
-- H2: five rounds of pricing bought rows nobody takes), and section 5 below
-- pins the one corpus fact that separates them -- inside a SINGLE frame, where
-- an instrument cannot be blind and not-blind at once.
--
-- SETTLED the same day, and NOT from this corpus: H1.  Everything in this file
-- is scoped to tests/fixtures/, which tops out at hero level 19 because of the
-- very cap GH #84's zero came from, so it could not reach the band where the
-- question answers itself.  The first post-cap frame (GH #235, parked in
-- iterations/pending/ behind GH #236) holds ten heroes at levels 22-27 who must
-- have spent 36 talent points between them; it shows 8, all generic, and three
-- heroes at 24-25 show none at all -- which H2 cannot produce, since a generic
-- pick is a visible row.  Nothing below changes: every assertion here is a
-- statement about tests/fixtures/ and every one of them is still true of it.
-- The verdict lives in tests/test_lategame_talent_visibility.lua.
--
-- HONEST BOUNDS, carried here because they travel with the finding:
--   * The point accounting (section 4) counts a facet-granted ability as a
--     spent point, because a dump cannot tell one from a learned ability.  That
--     biases the deficit DOWN, so 79 is a floor, not a measurement.
--   * Section 5's separating frame is only decisive if Lion's shipped t10 pick
--     was the same on the day that game was played (2026-08-20).  This
--     container's git history starts 2026-08-26, so that is NOT verifiable
--     here; the section asserts today's pick and says so in its failure text.
--   * "Unique" is matched on the token `unique` in the dumped name.  A future
--     hero-specific talent named without it would be counted generic.

package.path = 'tests/?.lua;' .. package.path

local FT = require('mock.fixture_talent_sightings')
local SLOTS = require('mock.talent_slots').SLOTS

local FOCUS_FIVE = { 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

--- The source with every comment removed.  The CM round found out the hard way
--- that a scan over raw text reads this desk's own documentation back as code.
local function live_source(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

local function total_sightings()
    local n = 0
    for _, byname in pairs(FT.SIGHTINGS) do
        for _, k in pairs(byname) do n = n + k end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- 0. Anti-vacuum.  Every claim below is "this count is zero", and a census that
--    parsed nothing reports zero of everything -- the same last line a correct
--    run prints.  That exact failure was caught by hand one round ago
--    (facet_census.py compiled its hero regex without re.M), so the refusal is
--    mechanical here rather than remembered.

tests['[hero] the talent-sighting snapshot is not an empty parse'] = function()
    local c = FT.CORPUS
    assert(c and c.fixtures and c.fixtures >= 50,
        'fixture_talent_sightings.lua reports only ' .. tostring(c and c.fixtures)
        .. ' fixtures. Every "zero unique talents" assertion below is vacuous on '
        .. 'an empty parse. Re-run: python3 tools/agent/fixture_talent_census.py --snapshot')
    assert(c.hero_frames >= 500, 'only ' .. c.hero_frames .. ' hero-frames parsed')
    assert(c.sightings >= 20, 'only ' .. c.sightings .. ' talent sightings parsed -- '
        .. 'if the parser stopped finding talents at all, "no unique ones" proves nothing')
    assert(total_sightings() == c.sightings,
        'X.SIGHTINGS sums to ' .. total_sightings() .. ' but X.CORPUS.sightings says '
        .. c.sightings .. ' -- the snapshot is internally inconsistent')
    assert(c.frames_lv10 >= 100, 'only ' .. c.frames_lv10 .. ' frames at level >= 10')
end

-- ---------------------------------------------------------------------------
-- 1. The finding itself.

tests['[hero] no fixture frame has ever shown a hero-unique talent'] = function()
    assert(FT.CORPUS.unique_sightings == 0,
        'a hero-unique talent now appears in the corpus (' ..
        FT.CORPUS.unique_sightings .. ' sightings). That is GOOD NEWS and this '
        .. 'assertion is meant to go red for it: the blindness this file registers '
        .. 'is over, and every argument that leaned on "no frame can show it" -- '
        .. 'GH #255 section 5, the TALENTPRICE bounds, this file -- should be '
        .. 'reopened with the frames that now exist.')
    for hero, byname in pairs(FT.SIGHTINGS) do
        for name, _ in pairs(byname) do
            assert(not name:find('unique', 1, true),
                hero .. ' shows ' .. name .. ', which reads as hero-unique')
        end
    end
end

tests['[hero] no frame carries two talents, and level >= 15 frames carry none'] = function()
    local c = FT.CORPUS
    assert(c.max_talents_on_one_frame == 1,
        'a frame now carries ' .. c.max_talents_on_one_frame .. ' talents; the '
        .. 'corpus used to top out at one, which was itself the tell')
    assert(c.frames_lv15 > 0, 'no frames at level >= 15 left in the corpus -- the '
        .. 'next assertion would pass by having nothing to check')
    assert(c.sightings_lv15 == 0,
        c.sightings_lv15 .. ' talents now visible on level >= 15 frames. The game '
        .. 'gives a talent point at level 10 AND 15, so those frames hold at least '
        .. 'two trained talents each; the corpus showing some is the blindness '
        .. 'lifting. Re-read section 1.')
    assert(c.max_level >= 15, 'corpus max level dropped to ' .. c.max_level)
end

-- ---------------------------------------------------------------------------
-- 2. Why the zero is not simply "nobody picks a unique row".  The focus five
--    have SINGLE-ROW talent tables (role-blind), so their pick is decidable
--    offline, and it splits three-two by KIND -- not by hero and not by level.

tests['[hero] the focus five talent tables are still single-row'] = function()
    for _, hero in ipairs(FOCUS_FIVE) do
        local f = FT.FOCUS_T10[hero]
        assert(f, 'no FOCUS_T10 entry for ' .. hero)
        assert(f.rows == 1, hero .. ' now has ' .. f.rows .. ' talent rows. The '
            .. 'cross-tab below reads a single shipped t10 pick per hero; with a '
            .. 'per-role table the pick depends on the position that game and the '
            .. 'comparison stops meaning anything. Re-derive before trusting it.')
        assert(f.slot == 1 or f.slot == 2, hero .. ' t10 decodes to slot ' ..
            tostring(f.slot) .. ' -- expected 1 or 2')
    end
end

tests['[hero] the {0,10}/{10,0} decode still matches aba_skill.GetTalentBuild'] = function()
    -- The whole cross-tab rests on this one line of arithmetic:
    --   nTalentBuildList[1] = ( tTalentTreeList['t10'][1] == 0 and 1 or 2 )
    local live = live_source(read_file('bots/FunLib/aba_skill.lua'))
    assert(#live > 2000, 'aba_skill.lua read back nearly empty after comment stripping')
    local n = live:match("%[1%]%s*=%s*%(%s*tTalentTreeList%['t10'%]%[1%]%s*==%s*0%s+and%s+(%d)")
    assert(n == '1', 'aba_skill.X.GetTalentBuild no longer maps t10 {0,10} to slot 1 '
        .. '(matched ' .. tostring(n) .. '). tools/agent/fixture_talent_census.py '
        .. 'decodes every shipped pick with that rule; fix both together.')
end

tests['[hero] the corpus shows every GENERIC focus pick and no UNIQUE one'] = function()
    local generic, unique = 0, 0
    for _, hero in ipairs(FOCUS_FIVE) do
        local f = FT.FOCUS_T10[hero]
        local slot = SLOTS[hero] and SLOTS[hero][f.slot]
        assert(slot and slot.name == f.name, hero .. ' t10 slot ' .. tostring(f.slot)
            .. ' is ' .. tostring(slot and slot.name) .. ' in talent_slots.lua but '
            .. tostring(f.name) .. ' in the census snapshot -- regenerate both')
        if f.kind == 'unique' then
            unique = unique + 1
            assert(f.sightings == 0, hero .. ' picks the unique row ' .. f.name
                .. ' and the corpus now shows it ' .. f.sightings .. ' times -- '
                .. 'see section 1, the blindness is lifting')
            assert(f.frames_lv10 > 0, hero .. ' has no level >= 10 frames at all, so '
                .. 'his zero says nothing about talents')
        else
            generic = generic + 1
            assert(f.sightings > 0, hero .. ' picks the GENERIC row ' .. f.name
                .. ' and the corpus shows him no talent on any of his '
                .. f.frames_lv10 .. ' frames at level >= 10. That breaks the split '
                .. 'this file registers: the visible/invisible line stops being '
                .. '"generic vs unique" and the finding must be re-derived.')
        end
    end
    assert(unique == 2 and generic == 3, 'the focus five t10 picks are now ' ..
        generic .. ' generic / ' .. unique .. ' unique. The three-two split is what '
        .. 'makes the census a comparison rather than an absence; re-read it.')
end

-- ---------------------------------------------------------------------------
-- 3. The two focus heroes whose whole priced tree is invisible.

tests['[hero] skeleton_king and axe pick a unique t10 the corpus cannot see'] = function()
    for _, hero in ipairs({ 'skeleton_king', 'axe' }) do
        local f = FT.FOCUS_T10[hero]
        assert(f.kind == 'unique', hero .. ' t10 is now ' .. f.name ..
            ' (' .. f.kind .. '); this section is about the invisible half')
        assert(FT.SIGHTINGS[hero] == nil,
            hero .. ' now appears in the sighting table at all -- re-read section 1')
    end
    -- The one that matters most: WK's slot 6 is the only talent any focus hero's
    -- decision layer reads (talent6:IsTrained() bypasses the Bone Guard bank
    -- threshold twice inside X.ConsiderW, GH #255).  It is unique-named, so no
    -- frame this repo holds can confirm the bypass ever fires.
    local slot6 = SLOTS['skeleton_king'][6]
    assert(slot6 and slot6.name:find('unique', 1, true), 'WK slot 6 is now ' ..
        tostring(slot6 and slot6.name) .. '. If it became a generic row, the corpus '
        .. 'can finally answer whether talent6:IsTrained() ever fires -- go ask it.')
end

-- ---------------------------------------------------------------------------
-- 4. Point accounting.  Independent of names: a hero at level L holds L skill
--    points and a talent costs the level's point, so
--        deficit = L - (points visibly on abilities) - (talents dumped)
--    counts points the frame cannot account for.  A deficit of 1 is exactly the
--    shape of "the level-10 talent is not in this dump".

tests['[hero] level >= 10 frames carry skill points nothing in the dump accounts for'] = function()
    local c = FT.CORPUS
    assert(c.deficit_frames_lv10 > 0,
        'no frame at level >= 10 has an unaccounted skill point any more. Either '
        .. 'the dump started carrying talents (section 1) or the accounting broke.')
    assert(c.deficit_frames_lv10 <= c.frames_lv10, 'accounting is inconsistent: '
        .. c.deficit_frames_lv10 .. ' deficit frames out of ' .. c.frames_lv10)
    -- Floor, not a measurement: a facet-granted ability is indistinguishable
    -- from a learned one and inflates the visible point count.
    assert(c.zero_talent_frames_lv10 >= c.deficit_frames_lv10,
        'more frames carry an unaccounted point than carry no talent at all -- '
        .. 'the two populations should nest')
end

-- ---------------------------------------------------------------------------
-- 5. The frames where the two accounts come apart.  A dumper cannot be blind
--    and not-blind inside the SAME frozen instant, so a fixture that shows one
--    hero's talent while another hero in it is level >= 10 with an unaccounted
--    point is evidence against the pure-instrument story for THAT hero.

tests['[hero] the corpus holds frames that show one talent and hide another'] = function()
    assert(FT.SPLIT and #FT.SPLIT > 0,
        'no fixture both shows and hides a talent any more -- the H1/H2 tiebreak '
        .. 'evidence is gone from the corpus and the question reopens')
    assert(FT.CORPUS.split_fixtures == #FT.SPLIT, 'X.SPLIT has ' .. #FT.SPLIT ..
        ' rows but X.CORPUS.split_fixtures says ' .. FT.CORPUS.split_fixtures)
    -- Lion is the sharpest case and the only one inside the focus five: his t10
    -- pick is GENERIC today, the corpus shows him that exact talent in one
    -- frame, and shows him none in four others where he is level 11 and a point
    -- short.  HONEST BOUND: decisive only if the pick was the same on the day
    -- those games were played (2026-08-20); this container's git history starts
    -- 2026-08-26, so that is not checkable here.
    local lion = FT.FOCUS_T10['lion']
    assert(lion.kind == 'generic', "lion's t10 pick is no longer generic (" ..
        lion.name .. ') -- the separating case in this section was built on it')
    assert(lion.sightings >= 1 and lion.sightings < lion.frames_lv10,
        'lion now shows his generic t10 on ' .. lion.sightings .. ' of ' ..
        lion.frames_lv10 .. ' frames at level >= 10. This section needs BOTH: at '
        .. 'least one frame that shows it (so the instrument works on him) and at '
        .. 'least one that does not (so something else explains the gap). If it is '
        .. 'now all or nothing, the tiebreak is settled -- write down which way.')
    local found = false
    for _, row in ipairs(FT.SPLIT) do
        for _, h in ipairs(row.blind) do
            if h == 'lion' then found = true end
        end
    end
    assert(found, 'no fixture shows another hero a talent while Lion, level >= 10 '
        .. 'and a point short, shows none. That was the separating observation.')
end

return tests
