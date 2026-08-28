-- [hero] The level supply behind BOTH open Wraith King levers, measured, so the
-- queue request that asks for it cannot outlive or misquote its own premise.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- Two gated-and-unpromoted WK candidates are stalled on the SAME missing frames,
-- and until this round each was carrying its own prose account of the gap:
--
--   * `wkrosh` (X.GetRoshanManaFloor, bots/BotLib/hero_skeleton_king.lua).  The
--     24 of 31 frames that argue its floor are "all at level <= 12", i.e. the
--     band least likely to be at Roshan.  Recorded in the hero backlog at -37.
--   * `wkbuild` (the delayed Bone Guard order, same file).  Its condition (c)
--     was measured this week to have a LIFETIME: trained past the t20 bypass,
--     every threshold section 4 of tests/test_wk_bone_guard_thresholds.lua reads
--     collapses to 0 (loudest: rank-4 lane 8 -> 0).  So (c) holds at 12-19 and
--     lapses at 20 -- and every frame that bought it is at <= 12.  Backlog -38.
--
-- Stated separately they read as two lever-specific gripes.  Measured together
-- they are one number, and the number is not what either prose said.
--
-- WHAT THE SWEEP ACTUALLY READS (all figures asserted below, 2026-08-28)
-- ---------------------------------------------------------------------
--   tests/fixtures/    107 frames / 77 games / 1070 hero-slots
--                      48 slots at level >= 13, high-water 19 (a Viper)
--                      LATEST FRAME t = 790.4s = 13:10
--   Wraith King        36 of those slots, high-water 12, and ZERO at >= 13
--   parked frame       iterations/pending/tpgap_159_fixture/, t = 1382.2 (23:02)
--                      10 of 10 slots at >= 20, its Wraith King at 26
--
-- Every level figure above is COUNTER-EVIDENCE to GH #84's ceiling, never an
-- appeal to it: that premise was retired on 2026-08-27 (GH #235) and this file
-- measures what stands in its place.  Said explicitly because the registry
-- sweep in tests/test_level_premise_registry.lua is lexical -- it cannot tell a
-- quote that leans on the ceiling from one that refutes it, and a file arguing
-- the ceiling is a harness artefact necessarily prints the ceiling's own words.
--
-- THE POINT, AND IT IS NOT "TURBO NEVER GETS THERE"
-- -------------------------------------------------
-- The corpus DOES reach level 13+; 48 slots in 22 games do.  It reaches 19.  So
-- the WK zero is not the turbo level curve talking -- it is a fact about which
-- instants somebody chose to freeze, and Wraith King's were all cut early.  The
-- whole repository holds EXACTLY ONE Wraith King frame above level 12, and it is
-- the parked one, one directory outside the glob every corpus scan enumerates
-- (GH #236, and GH #281 for the 53 files sharing that `ls tests/fixtures`).
--
-- That is why the queue ask is "scan the archived timelines for WK at >= 13/18/19
-- past 13:10", not "re-read GH #84's corpus-wide level curve".  The corpus-wide
-- curve answers a question neither lever asked: both are conditioned on the hero.
--
-- WHY THE FIXTURE CEILING IS THE OLD CAP'S SHADOW
-- -----------------------------------------------
-- 790.4s is not where turbo games end.  It is where the frames we cut end, and
-- they end there because the batch harness self-terminated every game at a
-- 10-minute economy cap until owner priority P3 / GH #108 raised it to 25
-- minutes.  The first frame taken past the lift is the parked one, and it reads
-- ten heroes at 22-27 in a naturally-ended 24.9-minute game.  A zero measured
-- under the old cap is therefore a statement about the harness, not about turbo
-- -- the same misreading tests/test_focus_talent_anchor.lua and
-- tests/test_focus_build_level_legality.lua each had to retire this week.
--
-- HONEST BOUNDS
--   * ONE frame.  It kills a universal ("no hero-slot in this tree reaches 20")
--     and it is not a distribution: nothing here says what share of turbo games
--     reach level 20, or how often a level-18 Wraith King stands in the Roshan
--     pit with 600 mana.  Those are the numbers queue `hero-10` asks for and
--     this file cannot produce -- it can only stop the missing ones from being
--     rendered as measured zeros.
--   * The WK zero is over frames we FROZE, not games we played.  Section 4's
--     contrast (48 slots >= 13 exist, none of them WK) is what keeps that
--     distinction visible; it is not evidence that Wraith King levels slower.
--   * `GetActiveMode` still appears in no .dem (the 13th world assertion), so the
--     Roshan half of `wkrosh`'s domain stays positional even after this scan.
--     Unchanged by anything here; restated so the request is not read as buying
--     more than it can.

package.path = package.path .. ';./tests/?.lua;./tests/mock/?.lua'

local cs = require('corpus_scale')

local tests = {}

local WK = 'npc_dota_hero_skeleton_king'
local SRC = 'bots/BotLib/hero_skeleton_king.lua'

-- The parked post-cap frame (GH #235/#236).  Named rather than globbed for the
-- reason this whole file is about: it lives one directory outside tests/fixtures.
local PARKED = 'iterations/pending/tpgap_159_fixture/f_260826_155416_slardar_tpgap.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

-- Enumerated, not globbed, and the parked frame is guarded on existence AND on
-- basename: the day GH #236 lands it in tests/fixtures/ it must be read exactly
-- once whether that landing is a move or a copy.  Counted twice it would inflate
-- the WK denominator, which is the floor sections 1-3 lean on.
local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^.+%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    local base = PARKED:gsub('.*/', '')
    local already = false
    for _, f in ipairs(files) do
        if f:gsub('.*/', '') == base then already = true; break end
    end
    if not already then
        local fh = io.open(PARKED, 'r')
        if fh then
            fh:close()
            files[#files + 1] = PARKED
        end
    end
    return files
end

-- One pass, two ledgers: what the glob can see (`fx`) and what the tree holds
-- (`fx` + `parked`).  Keeping them apart IS the finding -- collapsing them is
-- exactly how a horizon gets written down as a frequency.
--
-- `parked_ge20` counts the frame's slots at level 20 or better.  It is the
-- direct counter to the ceiling retired on 2026-08-27 (GH #235), so it is
-- deliberately a COUNT and not a boolean: "some hero got there once" and "the
-- whole lobby is there" are different facts about turbo, and only the second
-- one makes the fixture corpus's zero unmistakably a window artefact.
local function scan()
    local c = {
        fx_frames = 0, fx_slots = 0, fx_max_t = 0, fx_max_level = 0, fx_ge13 = 0,
        wk_fx = 0, wk_fx_max_level = 0, wk_fx_ge13 = 0,
        wk_tree = 0, wk_tree_ge13 = 0,
        parked_seen = false, parked_t = 0, parked_slots = 0, parked_ge20 = 0,
        parked_wk_level = 0,
    }
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            local parked = (path:gsub('.*/', '') == PARKED:gsub('.*/', ''))
            if parked then
                c.parked_seen = true
                c.parked_t = fx.time or 0
            else
                c.fx_frames = c.fx_frames + 1
                if (fx.time or 0) > c.fx_max_t then c.fx_max_t = fx.time end
            end
            for _, u in ipairs(fx.units) do
                if type(u.name) == 'string' and u.name:find('^npc_dota_hero_')
                    and type(u.level) == 'number' then
                    if parked then
                        c.parked_slots = c.parked_slots + 1
                        -- 20 is the threshold GH #235 retired on 2026-08-27, kept
                        -- here as the same number so the refutation is read on the
                        -- claim's own scale rather than a friendlier one.
                        if u.level >= 20 then c.parked_ge20 = c.parked_ge20 + 1 end
                        if u.name == WK then
                            c.parked_wk_level = u.level
                            c.wk_tree = c.wk_tree + 1
                            if u.level >= 13 then c.wk_tree_ge13 = c.wk_tree_ge13 + 1 end
                        end
                    else
                        c.fx_slots = c.fx_slots + 1
                        if u.level > c.fx_max_level then c.fx_max_level = u.level end
                        if u.level >= 13 then c.fx_ge13 = c.fx_ge13 + 1 end
                        if u.name == WK then
                            c.wk_fx = c.wk_fx + 1
                            c.wk_tree = c.wk_tree + 1
                            if u.level > c.wk_fx_max_level then c.wk_fx_max_level = u.level end
                            if u.level >= 13 then
                                c.wk_fx_ge13 = c.wk_fx_ge13 + 1
                                c.wk_tree_ge13 = c.wk_tree_ge13 + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return c
end

--------------------------------------------------------------------------------
-- 1. The supply zero, in the only form that can go red: over the glob, on WK.
--------------------------------------------------------------------------------

tests['1. 36 WK slots inside tests/fixtures/, high-water 12, ZERO at level >= 13'] =
function()
    local c = scan()
    cs.corpus(c.fx_frames, 'fixture corpus')
    -- A ratchet, not an equality: fixtures are append-only and a new WK frame
    -- must not turn this red for being new (GH #106/#127).
    cs.ratchet(c.wk_fx, 36, 'WK hero-slots in tests/fixtures/')
    -- The zero stays a hard equality on purpose.  It is the premise the queue
    -- request rests on, and the day a level-13 Wraith King lands in the glob the
    -- request has been partly answered by the corpus and must be re-read.
    assert(c.wk_fx_ge13 == 0, c.wk_fx_ge13 .. ' Wraith King hero-slot(s) inside '
        .. 'tests/fixtures/ now reach level 13, recorded 0.  That is the frame '
        .. 'queue hero-10 exists to buy: re-read the request before scanning, and '
        .. 'both levers\' "all evidence <= 12" prose with it')
    assert(c.wk_fx_max_level == 12, 'the WK high-water inside tests/fixtures/ is '
        .. c.wk_fx_max_level .. ', recorded 12; see the level-13 assertion above')
end

--------------------------------------------------------------------------------
-- 2. Exactly one WK frame above level 12 exists in this tree, and the glob
--    cannot see it.  Section 1 without this one is a horizon read as a fact.
--------------------------------------------------------------------------------

tests['2. the tree holds exactly ONE WK slot above 12 and it is the parked frame'] =
function()
    local c = scan()
    assert(c.parked_seen, 'the parked frame is gone from ' .. PARKED .. ' and did '
        .. 'not arrive in tests/fixtures/ under its own basename.  If GH #236 '
        .. 'landed it under a NEW name, re-point PARKED; until then section 1\'s '
        .. 'zero has no witness and must not be quoted as a fact about turbo')
    assert(c.wk_tree_ge13 == 1, c.wk_tree_ge13 .. ' WK hero-slots above level 12 '
        .. 'in the whole tree, recorded 1.  More is good news -- the supply this '
        .. 'file calls missing arrived -- and queue hero-10 should be re-read '
        .. 'before it is executed')
    assert(c.parked_wk_level == 26, 'the parked frame\'s Wraith King is level '
        .. c.parked_wk_level .. ', recorded 26')
    -- Both levers' domains, on the one frame that can speak to them at all:
    -- `wkrosh` needs >= 18/19 (26 clears all three crossing levels 21/19/18),
    -- `wkbuild`'s condition (c) needs < 20 (26 is outside its lifetime).  One
    -- frame answers both and answers them opposite ways; that is the request.
    assert(c.parked_wk_level >= 19, 'the witness no longer clears wkrosh\'s '
        .. 'crossing levels')
    assert(c.parked_wk_level >= 20, 'the witness no longer sits past wkbuild\'s '
        .. 'condition-(c) lifetime, which ends at 20 (test_wk_bone_guard_thresholds '
        .. 'section 4)')
end

--------------------------------------------------------------------------------
-- 3. The time ceiling: 13:10 is the old 10-minute cap's shadow, not turbo's end.
--
-- The two readings in this section are the pair that retired GH #84's ceiling on
-- 2026-08-27 (GH #235): a corpus whose last frame is at 13:10, and a frame at
-- 23:02 whose whole lobby is past level 20.  Neither number alone says anything
-- -- it is their ORDER that shows the zero was measured before the game got
-- there.
--------------------------------------------------------------------------------

tests['3. the glob ends at 13:10 while the parked frame sits at 23:02'] = function()
    local c = scan()
    -- A ceiling, so it goes red the day a post-cap frame lands in tests/fixtures/
    -- -- which is precisely the event that retires this whole file.
    cs.ceiling(math.floor(c.fx_max_t), 900, 'latest frame time in tests/fixtures/ (s)')
    assert(c.parked_t > 1200, 'the parked frame is at t=' .. c.parked_t
        .. 's, recorded 1382.2 -- past any 10-minute cap, which is why it is the '
        .. 'only frame in the tree that can speak about levels 20+')
    assert(c.parked_ge20 == c.parked_slots and c.parked_slots == 10,
        c.parked_ge20 .. ' of ' .. c.parked_slots .. ' parked slots at level >= 20, '
        .. 'recorded 10 of 10.  This is the counter-example to "turbo never '
        .. 'reaches 20" -- the ceiling retired on 2026-08-27 (GH #235) -- and it '
        .. 'has been in the tree since 2026-08-26, a day before the retirement it '
        .. 'could have forced')
end

--------------------------------------------------------------------------------
-- 4. The contrast that stops section 1 being read as "turbo never gets there".
--------------------------------------------------------------------------------

tests['4. level >= 13 IS purchasable in the glob -- 48 slots, none of them WK'] =
function()
    local c = scan()
    cs.ratchet(c.fx_ge13, 48, 'hero-slots at level >= 13 in tests/fixtures/')
    cs.ratchet(c.fx_max_level, 19, 'level high-water in tests/fixtures/')
    -- The two readings together are the whole argument for scanning BY HERO:
    -- the corpus reaches 13+ 48 times and reaches 19, and Wraith King is in
    -- none of it.  A corpus-wide level curve (GH #84) therefore cannot answer
    -- either lever's question, because both are conditioned on the hero.
    assert(c.fx_ge13 > 0 and c.wk_fx_ge13 == 0,
        'the contrast collapsed: >= 13 is now either absent from the corpus or '
        .. 'present on Wraith King.  Either way the "scan by hero, not the '
        .. 'corpus-wide curve" argument in queue hero-10 needs re-reading')
end

--------------------------------------------------------------------------------
-- 5. The request cannot outlive its consumers: both levers still exist, gated.
--------------------------------------------------------------------------------

tests['5. both consumers are still in the shipped source and still gated'] = function()
    local src = read_file(SRC)
    assert(src:find("J.IsSoakCandidate( 'wkrosh' )", 1, true),
        SRC .. ' no longer gates on wkrosh.  If it was promoted or deleted, the '
        .. 'Roshan half of queue hero-10 lost its consumer and the ask should '
        .. 'shrink to wkbuild before anybody spends a scan on it')
    assert(src:find("J.IsSoakCandidate( 'wkbuild' )", 1, true),
        SRC .. ' no longer gates on wkbuild.  Same reading as above, other half')
    assert(src:find('X.GetRoshanManaFloor', 1, true),
        'X.GetRoshanManaFloor is gone; wkrosh\'s mana floor is what the level '
        .. 'supply question is downstream of')
end

return tests
