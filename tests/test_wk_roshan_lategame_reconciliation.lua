-- [hero] The two published Wraith King Roshan-mana readings are ONE quantity,
-- and the frame that settles it was already in the tree when both were written.
--
-- ZERO behaviour change in this work unit, and no new gate id.  `wkrosh` is
-- untouched -- still turbo-only, still unarmed.  What this file changes is what
-- two sibling test files are allowed to claim.
--
-- THE TWO READINGS, AND WHY THEY ARE THE SAME QUANTITY
-- ---------------------------------------------------
-- tests/test_wk_roshan_mana_ceiling.lua argues the SHIPPED 600 floor is crossable
-- but only in a tail: its crossing levels are 21 bare / 19 with a magic wand / 18
-- with wand+bracer, and it reads those against GH #84's turbo level census
-- (level >= 20 on 0 of 210 hero-slots, HIGH-WATER 19) to conclude "the tail of
-- that distribution instead of never".  THAT CENSUS IS QUOTED HERE ONLY AS THE
-- SUPERSEDED READING IT IS -- retired 2026-08-27 (GH #235), because the 0 of 210
-- was produced by a 10-minute batch cap that owner priority P3 (GH #108) removed.
-- This file is the re-read that clears that row, not a new argument built on it.
--
-- tests/test_wk_roshan_mana_floor.lua argues the branch is mana-DEAD: the shipped
-- 600 admits 0 of 36 real Wraith King frames, and the largest MAX pool on any of
-- them is 471, so 600 sits above the whole pool with a full bar.  Its 2026-08-28
-- re-take recorded that margin narrowing 141 -> 129 and forecast that "the next
-- round that grows the WK corpus should expect the margin to keep closing".
--
-- Those are not two facts.  Both ask HOW FAR UP THE LEVEL/POOL DISTRIBUTION THE
-- CORPUS REACHES, one in levels and one in mana, and both answer with a number
-- that the same single frame falsifies.  Backlog -37 asked for them to be read as
-- one baton; this is that read.
--
-- THE FRAME
-- ---------
-- iterations/pending/tpgap_159_fixture/f_260826_155416_slardar_tpgap.lua, the
-- first post-cap frame this repo holds (t=1382.2 = 23:02 of a 24.9-minute
-- naturally-ended turbo game; GH #235).  Its Wraith King slot is:
--
--     level 26, mp 762, max_mp 855, Wraithfire Blast rank 4,
--     Reincarnation rank 3, bag = phase_boots armlet radiance
--     black_king_bar blink_dagger (zero intelligence between them, by the
--     ceiling file's OWN ITEM_STATS table).
--
-- WHAT THAT DOES TO EACH READING
--
--   * THE FLOOR READING'S MARGIN DID NOT "KEEP CLOSING" -- IT CHANGED SIGN.  The
--     forecast was 129 and shrinking.  The answer is 855, i.e. 255 ABOVE the
--     shipped 600, and the branch's own test is on CURRENT mana, which is 762 --
--     so the shipped 600 has its FIRST ADMITTED FRAME.  "0 of 36" stays true of
--     the population it scans; the sentence "600 is above the ENTIRE pool of
--     every Wraith King frame this repo has ever recorded" does not.
--   * THE CEILING READING'S TAIL IS GONE, by observation rather than arithmetic.
--     26 is past all three crossing levels (21/19/18).  This does not weaken that
--     file -- it strengthens it in the direction it already pointed, which is why
--     the source comment above the branch already absorbed it on 2026-08-27.  The
--     file's own TURBO_HIGH_WATER_LEVEL = 19 did not.
--
-- THE MECHANISM, WHICH IS THE PART WORTH KEEPING: THE GLOB IS THE HORIZON
-- ----------------------------------------------------------------------
-- Both sibling files enumerate their corpus with `ls tests/fixtures/f_*.lua`.
-- The settling frame is parked one directory away, in iterations/pending/, behind
-- GH #236 (landing it turns 16 corpus files red, and that ordering is the
-- harness/director seat's call).  So the frame was UNSEEABLE to both scans -- and
-- both scans rendered that blindness as a measured extreme: a zero and a
-- high-water.  The floor file's forecast is the tell.  It wrote "a post-GH#108
-- corpus can hold frames the original scan structurally could not" as a statement
-- about FUTURE corpus growth, on 2026-08-28, when the frame that answers it had
-- been in the tree since 2026-08-26.  This is the same family as GH #257/#266
-- ("this layer has no games" rendered as a measured zero) and it is the trap the
-- floor file itself warns about two sections later under a different name.
--
-- Section 1 machine-checks that mechanism instead of narrating it.
--
-- WHAT THIS COSTS THE LEVER (stated because it is not free)
-- --------------------------------------------------------
-- On this frame BOTH legs admit: shipped 600 <= 762, and the armed floor is
-- 140 + 0 = 140 because Reincarnation is rank 3 and rank 3 is free in this patch.
-- So on the one frame in the repo that is late enough for a Roshan fight to be
-- ordinary, `wkrosh` is a NO-OP.  That does not retire the lever -- its bite
-- window is mana in [cost + reserve, 600), which is wide at Reincarnation rank
-- 1-2 (armed floors 315/330 and 235/250) -- but it does re-point where the
-- lever's evidence has to come from: the 24-of-31 admit rate that currently
-- carries it is measured ENTIRELY on frames at level 12 and below, which is where
-- a Roshan fight is least likely, and it says nothing about the band where the
-- lever actually bites.  Registered, not resolved; the domain question is still
-- queue hero-10.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * ONE FRAME.  Everything here is a single hero-slot in a single game.  It is
--     enough to kill a universal ("above the ENTIRE pool", "high-water 19" --
--     the latter already retired 2026-08-27, GH #235) because a universal dies to
--     one counterexample; it is NOT a distribution and nothing here says how
--     often a level-26 Wraith King happens.
--   * SNAPSHOT, NOT A READ, and for the reason tests/mock/lategame_talent_frame.lua
--     already gives: a test that read the parked path directly would either block
--     on GH #236 or break the day the file moves.  Section 5 is a CONTROL that
--     re-derives every number here from the parked file WHEN IT IS PRESENT, so
--     the snapshot cannot silently drift while it stays parked, and skips (loudly,
--     via a recorded reason) once it does not.
--   * THE 168-MANA MODEL GAP IN SECTION 4 IS RECORDED, NOT ATTRIBUTED.  The
--     ceiling file's pool model is exact on 33 of 34 frames, every one of them
--     level 12 or below, and says so: "the model is EXTRAPOLATED past that, which
--     is precisely the range the claim needs".  This is the first frame that can
--     test the extrapolation and the model misses by 14 intelligence.  Two
--     candidates, neither asserted here: (a) the four talents the shipped level-up
--     routine must have spent by level 26, of which this frame shows ONE -- and
--     GH #260 established that the freeze-frame corpus has never once resolved a
--     hero-unique talent row (0 of 960 hero-frames), so talents are structurally
--     under-observed in exactly this dimension; (b) an attribute mechanic above
--     level 12 that a flat 1.4/level does not carry.  One frame cannot separate
--     them -- that needs a second late WK slot at a different level, and the
--     direction is what matters meanwhile.
--   * THE DIRECTION IS THE LOAD-BEARING HALF OF THAT GAP.  The model
--     UNDER-predicts, so the true crossing levels are EARLIER than the published
--     21/19/18, never later.  Every claim built on those levels is therefore
--     conservative in the safe direction, which is why nothing downstream is
--     retracted here -- only re-pointed.
--   * NOTHING HERE TOUCHES THE DOMAIN.  Whether a bot ever enters
--     BOT_MODE_ROSHAN is still unmeasurable offline (GetActiveMode is bot-VM
--     state, in no .dem -- the 13th world assertion).  A mana reading is not a
--     domain reading and this file does not let one stand in for the other.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local CEILING = 'tests/test_wk_roshan_mana_ceiling.lua'
local FLOOR   = 'tests/test_wk_roshan_mana_floor.lua'
local GLOB    = 'ls tests/fixtures/f_*.lua'

-- The parked frame, at its recorded path.  Section 1 asserts this is OUTSIDE the
-- glob above; section 5 reads it when it is there.
local PARKED = 'iterations/pending/tpgap_159_fixture/f_260826_155416_slardar_tpgap.lua'

-- RECORDED 2026-08-28 from PARKED.  The Wraith King hero-slot only; the other
-- nine are in tests/mock/lategame_talent_frame.lua.
local SLOT = {
    level = 26, mp = 762, max_mp = 855,
    blast = 4, reincarn = 3,
    items = { 'phase_boots', 'armlet', 'radiance', 'black_king_bar', 'blink_dagger' },
}

-- The shipped constant and the two cost ladders, quoted from the sibling files so
-- a KV edit that lands there and not here fails rather than diverges silently.
local SHIPPED_FLOOR = 600
local BLAST_MANA    = { 95, 110, 125, 140 }
local REINCARN_MANA = { 220, 110, 0 }

-- The ceiling file's model, restated here so section 4 can drive it against a
-- frame that file cannot see.  Section 4 also asserts the constants still match.
local BASE_MANA, MANA_PER_INT = 75, 12
local BASE_INT, INT_PER_LEVEL = 16, 1.4

local function pool(nLevel, nInt, nFlat)
    return BASE_MANA
        + MANA_PER_INT * math.floor(BASE_INT + INT_PER_LEVEL * (nLevel - 1) + nInt)
        + (nFlat or 0)
end

local function crossing_level(nInt, nFlat)
    for nLevel = 1, 30 do
        if pool(nLevel, nInt, nFlat) >= SHIPPED_FLOOR then
            return nLevel, pool(nLevel, nInt, nFlat)
        end
    end
end

local function read_file(sPath)
    local fh = io.open(sPath, 'r')
    if not fh then return nil end
    local s = fh:read('*a'); fh:close()
    return s
end

local function glob_files(sCmd)
    local p = assert(io.popen(sCmd))
    local t = {}
    for s in p:lines() do t[#t + 1] = s end
    p:close()
    return t
end

local tests = {}

-- ---------------------------------------------------------------- section 1 --
-- The mechanism: the glob both siblings share cannot reach the frame that
-- settles them.  Machine-checked, because "they used a scan that could not see
-- it" is exactly the kind of claim that rots into prose.

tests['section 1: both sibling files enumerate their corpus with the same glob'] = function()
    for _, sPath in ipairs({ CEILING, FLOOR }) do
        local src = assert(read_file(sPath), 'cannot open ' .. sPath)
        assert(src:find(GLOB, 1, true), sPath .. ' no longer enumerates with `'
            .. GLOB .. '`. If it grew a wider scan, the horizon argument in this '
            .. 'file has to be re-read rather than kept.')
    end
end

tests['section 1: the settling frame is OUTSIDE that glob'] = function()
    local tSeen = glob_files(GLOB)
    assert(#tSeen > 0, 'the glob matched nothing at all; the harness moved')
    for _, sPath in ipairs(tSeen) do
        assert(sPath ~= PARKED, 'the parked frame is now inside tests/fixtures/. '
            .. 'That is GH #236 landing, which is good -- but it means the two '
            .. 'sibling scans now SEE it, so their counts must be re-taken and '
            .. 'this file rewritten around the merged corpus, not left standing.')
    end
    assert(not PARKED:find('^tests/fixtures/'),
        'PARKED was re-pointed into tests/fixtures without this file noticing')
end

tests['section 1: the blindness is structural, not a missing file'] = function()
    -- The distinction that makes this a defect and not an accident: the frame
    -- EXISTS and is readable at a path the scan does not look at.  If it were
    -- simply absent there would be nothing to report.
    assert(read_file(PARKED) ~= nil, 'the parked frame is gone from ' .. PARKED
        .. '. If it moved, find it and re-point PARKED; if it was deleted, every '
        .. 'number in this file is unbacked and the file should be deleted too.')
end

-- ---------------------------------------------------------------- section 2 --
-- The floor reading, re-asked on the frame it could not see.

tests['section 2: the shipped 600 has its first admitted frame'] = function()
    assert(SLOT.mp >= SHIPPED_FLOOR, 'the parked frame carries mp ' .. SLOT.mp
        .. ', which no longer clears the shipped floor ' .. SHIPPED_FLOOR)
    -- The branch tests CURRENT mana, not the pool.  Both clear it here, and the
    -- distinction matters: a full-bar reading would be the weaker claim.
    assert(SLOT.max_mp >= SHIPPED_FLOOR, 'full bar must clear it too')
end

tests['section 2: the margin changed sign rather than closing'] = function()
    -- The floor file's re-take recorded 471 (margin 129 BELOW 600) and forecast
    -- further narrowing.  This asserts the forecast's shape was wrong, not just
    -- its size.
    local nOldHighWater, nOldMargin = 471, 129
    assert(SHIPPED_FLOOR - nOldHighWater == nOldMargin,
        'the recorded margin arithmetic does not reproduce')
    local nNewMargin = SLOT.max_mp - SHIPPED_FLOOR
    assert(nNewMargin == 255, 'the parked frame sits ' .. nNewMargin
        .. ' above the shipped floor, recorded 255')
    assert(nNewMargin > 0 and nOldMargin > 0,
        'both margins are stated as magnitudes; the SIGN is what flipped, and if '
        .. 'this assertion is what broke then the arithmetic above is wrong')
end

tests['section 2: what survives is the population, not the universal'] = function()
    -- "0 of 36" is still true and stays asserted in the floor file.  The sentence
    -- this file retires is the one quantified over the whole repo.  Checked
    -- against the source so the correction cannot be undone by a later edit.
    local src = assert(read_file(FLOOR))
    assert(not src:find('above the ENTIRE pool of\n-- every Wraith King frame this repo has ever recorded', 1, true),
        'the withdrawn universal is back in ' .. FLOOR)
    assert(src:find('tests/fixtures', 1, true),
        'the floor file no longer scopes its claim to a named corpus directory')
end

-- ---------------------------------------------------------------- section 3 --
-- The ceiling reading, re-asked on the same frame.

tests['section 3: level 26 is past all three published crossing levels'] = function()
    local nBare   = crossing_level(0, 0)
    local nWand   = crossing_level(3, 0)
    local nBracer = crossing_level(5, 0)
    assert(nBare == 21 and nWand == 19 and nBracer == 18,
        'the published crossing levels are 21/19/18; got '
        .. nBare .. '/' .. nWand .. '/' .. nBracer)
    for _, nCrossing in ipairs({ nBare, nWand, nBracer }) do
        assert(SLOT.level >= nCrossing, 'level ' .. SLOT.level
            .. ' no longer clears crossing level ' .. nCrossing)
    end
end

tests['section 3: the crossing POOL is 603 at every pre-scepter milestone'] = function()
    -- The defect that survives both readings, recomputed here rather than quoted:
    -- 600 asks for 99.5% of the pool at the moment the pool first reaches it.
    for _, tCase in ipairs({ { 0, 21 }, { 3, 19 }, { 5, 18 } }) do
        local nLevel, nPool = crossing_level(tCase[1], 0)
        assert(nLevel == tCase[2], 'int+' .. tCase[1] .. ' crosses at ' .. nLevel)
        assert(nPool == 603, 'int+' .. tCase[1] .. ' crosses with pool ' .. nPool
            .. ', recorded 603 -- the 99.5%-of-pool reading depends on this')
    end
end

tests['section 3: the tail argument is retired by observation'] = function()
    -- GH #84's census read a high-water of 19 under a 10-minute batch cap that
    -- owner priority P3 (GH #108) removed -- retired 2026-08-27, GH #235.  This
    -- asserts the observation that replaces it, and names where the census's
    -- number still lives.
    local nCensusHighWater = 19
    assert(SLOT.level > nCensusHighWater, 'the parked frame no longer exceeds the '
        .. 'GH #84 high-water; if the frame changed, the tail argument is live again')
    local src = assert(read_file(CEILING))
    assert(src:find('TURBO_HIGH_WATER_LEVEL', 1, true),
        CEILING .. ' dropped the constant entirely. It should keep it as a DATED '
        .. 'census reading, not delete it -- the census was correctly taken, it '
        .. 'was the population that moved.')
end

-- ---------------------------------------------------------------- section 4 --
-- The model's first testable extrapolation.  Recorded, not attributed.

tests['section 4: the model constants still match the ceiling file'] = function()
    local src = assert(read_file(CEILING))
    assert(src:find('local BASE_MANA, MANA_PER_INT = 75, 12', 1, true),
        'the mana constants moved in ' .. CEILING .. '; section 4 is driving a '
        .. 'model that file no longer uses')
    assert(src:find('local BASE_INT, INT_PER_LEVEL = 16, 1.4', 1, true),
        'the intelligence constants moved in ' .. CEILING)
end

tests['section 4: every item in the bag is priced at zero intelligence'] = function()
    -- Without this the 168-mana gap could just be an unpriced item.  The prices
    -- come from the ceiling file's own ITEM_STATS table, read here by name so a
    -- future edit that gives one of them intelligence fails loudly.
    local src = assert(read_file(CEILING))
    for _, sItem in ipairs(SLOT.items) do
        local sKey = sItem == 'blink_dagger' and 'blink' or sItem
        local sInt = src:match("%['" .. sKey .. "'%]%s*=%s*{%s*(%-?%d+)")
        assert(sInt, sKey .. ' is not priced in ' .. CEILING .. "'s ITEM_STATS; "
            .. 'the gap below cannot be called a MODEL gap until it is')
        assert(tonumber(sInt) == 0, sKey .. ' now grants ' .. sInt
            .. ' intelligence, so the 168-mana gap has an item explanation and '
            .. 'this section must be re-derived rather than re-asserted')
    end
end

tests['section 4: the model under-predicts the first post-level-12 frame by 14 int'] = function()
    local nPredicted = pool(SLOT.level, 0, 0)
    assert(nPredicted == 687, 'the model answers ' .. nPredicted
        .. ' for a bare level-26 Wraith King, recorded 687')
    local nGap = SLOT.max_mp - nPredicted
    assert(nGap == 168, 'the gap is ' .. nGap .. ' mana, recorded 168')
    assert(nGap % MANA_PER_INT == 0, 'the gap is not a whole number of '
        .. 'intelligence points, which would rule out BOTH candidate '
        .. 'explanations and mean something else is wrong')
    assert(nGap / MANA_PER_INT == 14, 'recorded as 14 intelligence')
    -- The direction, which is the half that anything downstream depends on.
    assert(nGap > 0, 'the model OVER-predicts now. That reverses the safety '
        .. 'direction: the published crossing levels 21/19/18 would become '
        .. 'optimistic rather than conservative, and every claim resting on them '
        .. 'needs re-reading, not just this file.')
end

tests['section 4: the model is exact where it was validated, by construction'] = function()
    -- Guards against "the model is just wrong": it reproduces the datafeed anchor
    -- at level 1 (267 max mana on 16 intelligence, GH #104) exactly.  So the gap
    -- is level-dependent, which is what makes an above-level-12 mechanic or the
    -- unobserved talents the two live candidates.
    assert(pool(1, 0, 0) == 267, 'the level-1 anchor no longer reproduces; got '
        .. pool(1, 0, 0))
end

-- ---------------------------------------------------------------- section 5 --
-- CONTROL: re-derive the snapshot from the parked file while it is reachable.

tests['section 5: the snapshot matches the parked file it was recorded from'] = function()
    local ok, tFix = pcall(dofile, PARKED)
    if not ok or type(tFix) ~= 'table' then
        error('the parked frame no longer loads as a fixture table: '
            .. tostring(tFix) .. '. Section 1 already asserted it is readable, so '
            .. 'this is a FORMAT change, and every number in this file is now '
            .. 'unverified.')
    end
    assert(tFix.time == 1382.2, 'the parked frame is at t=' .. tostring(tFix.time)
        .. ', recorded 1382.2')
    local tWK
    for _, tUnit in ipairs(tFix.units or {}) do
        if tUnit.name == 'npc_dota_hero_skeleton_king' then tWK = tUnit end
    end
    assert(tWK, 'no Wraith King slot in the parked frame')
    assert(tWK.level == SLOT.level, 'level ' .. tostring(tWK.level))
    assert(tWK.mp == SLOT.mp, 'mp ' .. tostring(tWK.mp))
    assert(tWK.max_mp == SLOT.max_mp, 'max_mp ' .. tostring(tWK.max_mp))
    local nBlast, nReincarn = 0, 0
    for _, tAb in ipairs(tWK.abilities or {}) do
        if tAb.name == 'skeleton_king_hellfire_blast' then nBlast = tAb.level end
        if tAb.name == 'skeleton_king_reincarnation' then nReincarn = tAb.level end
    end
    assert(nBlast == SLOT.blast, 'blast rank ' .. nBlast)
    assert(nReincarn == SLOT.reincarn, 'reincarnation rank ' .. nReincarn)
    -- The bag, as a set: order is not part of the claim, membership is.
    local tHeld = {}
    for _, sItem in ipairs(tWK.items or {}) do
        if sItem ~= '' then tHeld[sItem] = true end
    end
    for _, sItem in ipairs(SLOT.items) do
        assert(tHeld[sItem], 'the parked frame no longer holds ' .. sItem)
        tHeld[sItem] = nil
    end
    assert(next(tHeld) == nil, 'the parked frame grew an item the snapshot does '
        .. 'not carry: ' .. tostring(next(tHeld)) .. '. Section 4 prices the bag, '
        .. 'so an unpriced addition invalidates the model gap.')
end

-- ---------------------------------------------------------------- section 6 --
-- What it costs the lever, driven on the REAL helper.

tests['section 6: at this frame ranks both legs admit, so `wkrosh` is a no-op'] = function()
    -- Driven through the shipped function rather than recomputed: the armed floor
    -- at Reincarnation rank 3 is the blast price alone, because rank 3 is free.
    local J, bot = rf.load('tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua')
    J.IsSoakCandidate = function(id) return id == 'wkrosh' end
    local h = bot:GetAbilityByName('skeleton_king_reincarnation')
    rawget(h, '__spec').GetManaCost = REINCARN_MANA[SLOT.reincarn]
    local X = rf.load_hero('skeleton_king')

    local nCost = BLAST_MANA[SLOT.blast]
    local nArmed = X.GetRoshanManaFloor(nCost)
    assert(nArmed == 140, 'the armed floor at blast rank 4 / reincarnation rank 3 '
        .. 'is the blast price 140; got ' .. tostring(nArmed))
    assert(SLOT.mp >= nArmed, 'armed admits')
    assert(SLOT.mp >= SHIPPED_FLOOR, 'shipped admits')
    assert(nArmed < SHIPPED_FLOOR, 'the armed leg is still the looser of the two')
    -- The point: both admitting means the lever changes NOTHING here.
end

tests['section 6: the bite window is stated as arithmetic, not as a hope'] = function()
    -- Where `wkrosh` can still matter: mana in [cost + reserve, 600).  Non-empty
    -- at every rank pair, and widest exactly where this frame is not -- at
    -- Reincarnation rank 1-2.  This keeps the lever's case honest without
    -- overstating what one frame showed.
    local nWidest, nNarrowest = 0, math.huge
    for nB = 1, 4 do
        for nR = 1, 3 do
            local nArmed = BLAST_MANA[nB] + REINCARN_MANA[nR]
            assert(nArmed < SHIPPED_FLOOR, 'rank pair ' .. nB .. '/' .. nR
                .. ' has an armed floor at or above the shipped one')
            local nWidth = SHIPPED_FLOOR - nArmed
            if nWidth > nWidest then nWidest = nWidth end
            if nWidth < nNarrowest then nNarrowest = nWidth end
        end
    end
    assert(nNarrowest == SHIPPED_FLOOR - (BLAST_MANA[4] + REINCARN_MANA[1]),
        'the narrowest window should be the most expensive blast against the most '
        .. 'expensive reserve')
    assert(nNarrowest == 240, 'narrowest bite window recorded 240; got ' .. nNarrowest)
    assert(nWidest == 505, 'widest bite window recorded 505; got ' .. nWidest)
end

return tests
