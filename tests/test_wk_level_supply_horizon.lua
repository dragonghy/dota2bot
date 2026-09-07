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
-- whole repository holds TWO Wraith King slots above level 12, and neither is in
-- the glob every corpus scan enumerates (GH #236, and GH #281 for the 53 files
-- sharing that `ls tests/fixtures`):
--
--   * the parked frame, its Wraith King at 26, t = 1382.2, in iterations/pending/;
--   * a level-21 Wraith King at t = 1190.4, in tests/frames/ since 2026-08-31.
--
-- The second one is a CORRECTION, not growth (hero 2026-09-01).  It sat in the
-- tree for three days while this file's "whole tree" ledger read 1 and stayed
-- GREEN, because that ledger was the glob plus ONE named path -- an exhaustive
-- set on the day it was written, silently non-exhaustive the day GH #357 created
-- a second out-of-glob directory.  The scan now enumerates that directory
-- (section 6 reads the slot).  The failure direction is what makes it worth
-- naming: the number feeds the premise of queue `hero-10`, which somebody else
-- executes, and it UNDER-counted evidence the repository already owned.
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

-- The OTHER out-of-glob directory, and the reason this file needed a second one
-- (hero 2026-09-01).  When this file was written on 2026-08-28 there was exactly
-- one place a frame could sit outside `ls tests/fixtures` -- the parked frame
-- above -- so "the whole tree" and "the glob plus PARKED" were the same set, and
-- section 2 said so as a hard equality.  `tests/frames/` was created three days
-- later (GH #357) for frames whose ADMISSION price is not paid yet, and the
-- first frame staged in it carries a level-21 Wraith King.  From that moment
-- this file's "whole tree" ledger was short by one WK slot above 12 and STILL
-- GREEN, because a set written as a literal cannot notice a directory that did
-- not exist when it was written.  The fix is to enumerate the staging directory
-- rather than name its members: a third location must cost an edit here, not a
-- silent undercount, because the number it feeds is the premise of a queue
-- request other people execute.
local STAGED_DIR = 'tests/frames/'

local function staged_files()
    local files = {}
    local p = assert(io.popen('ls ' .. STAGED_DIR .. ' 2>/dev/null'))
    for line in p:lines() do
        if line:match('^f_.+%.lua$') then files[#files + 1] = STAGED_DIR .. line end
    end
    p:close()
    table.sort(files)
    return files
end

-- One pass, three ledgers: what the glob can see (`fx`), and what the tree holds
-- outside it (`parked` + `staged`).  Keeping them apart IS the finding --
-- collapsing them is exactly how a horizon gets written down as a frequency.
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
        staged_frames = 0, staged_wk = 0, staged_wk_ge13 = 0, staged_wk_max_level = 0,
        staged_wk_rows = {},
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
    -- The staging directory, on the same ledger as the parked frame: outside the
    -- glob, inside the tree.  The per-slot fields are kept whole (not just the
    -- level) because what the tree owns and what a reading can USE are different
    -- questions here -- see section 6.
    for _, path in ipairs(staged_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            c.staged_frames = c.staged_frames + 1
            for _, u in ipairs(fx.units) do
                if u.name == WK and type(u.level) == 'number' then
                    c.staged_wk = c.staged_wk + 1
                    c.wk_tree = c.wk_tree + 1
                    if u.level > c.staged_wk_max_level then c.staged_wk_max_level = u.level end
                    if u.level >= 13 then
                        c.staged_wk_ge13 = c.staged_wk_ge13 + 1
                        c.wk_tree_ge13 = c.wk_tree_ge13 + 1
                    end
                    c.staged_wk_rows[#c.staged_wk_rows + 1] = {
                        path = path, t = fx.time or 0, level = u.level,
                        alive = u.alive, hp = u.hp, max_hp = u.max_hp,
                        mp = u.mp, max_mp = u.max_mp,
                    }
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
-- 2. Two WK slots above level 12 exist in this tree, and the glob can see
--    neither.  Section 1 without this one is a horizon read as a fact.
--------------------------------------------------------------------------------

tests['2. the tree holds TWO WK slots above 12 and the glob can see neither'] =
function()
    local c = scan()
    assert(c.parked_seen, 'the parked frame is gone from ' .. PARKED .. ' and did '
        .. 'not arrive in tests/fixtures/ under its own basename.  If GH #236 '
        .. 'landed it under a NEW name, re-point PARKED; until then section 1\'s '
        .. 'zero has no witness and must not be quoted as a fact about turbo')
    -- 1 -> 2 on 2026-09-01 (hero), and the correction is the finding, not a
    -- re-baseline: the second slot did not arrive this round.  It has been in
    -- the tree since 2026-08-31, in tests/frames/, and this equality read 1 and
    -- stayed GREEN for those days because the scan enumerated one out-of-glob
    -- location by name.  What "recorded 1" priced was the set this file knew
    -- about, not the tree.  Section 6 reads the new slot; the number stays a
    -- hard equality so a THIRD location costs an edit here too.
    -- 2 -> 4 on 2026-09-07 (hero, backlog -112), and TWO SEPARATE THINGS moved,
    -- which is why this is a re-take and not a bump:
    --   * this equality had been RED ON TRUNK since 2026-09-06.  The round that
    --     staged f_260905_004847_lion_drain_bkb.lua (GH #566) settled the two
    --     enumerating scans its own README names and did not settle this third
    --     one, so a live level-26 Wraith King sat in the tree for a day with
    --     nothing green saying so.  That slot is the one section 6 now reads.
    --   * this round staged f_260828_002127_axe_call_bkb_ring.lua, which adds a
    --     level-19 slot (dead, like the 21).
    -- Recorded 4: parked 26, staged 21 (dead), staged 19 (dead), staged 26 (LIVE).
    assert(c.wk_tree_ge13 == 4, c.wk_tree_ge13 .. ' WK hero-slots above level 12 '
        .. 'in the whole tree, recorded 4 (the parked frame at 26, and three '
        .. 'staged in ' .. STAGED_DIR .. ' at 21, 19 and 26).  More is good news '
        .. '-- the supply this file calls missing arrived -- and queue hero-10 '
        .. 'should be re-read before it is executed')
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

--------------------------------------------------------------------------------
-- 6. What the staged slot answers of queue hero-10, and what it must not be
--    quoted for (hero 2026-09-01).
--
-- hero-10 asks for three numbers.  The slot section 2 just stopped losing speaks
-- to two of them, and in opposite directions:
--
--   (1) LEVEL SUPPLY -- "a zero on (1) IS decisive and retires the lever".  It
--       is not zero.  The tree holds FOUR Wraith King slots at >= 19 (parked 26,
--       staged 21, 19 and 26), all outside the glob every corpus scan
--       enumerates.  That does not answer (1) -- four slots are not a
--       distribution, and hero-10 asks for a rate over archived timelines -- but
--       it does remove the one reading that could have retired `wkrosh` without
--       a scan.
--   (2) MANA -- hero-10's own `result` records "the LARGEST MAX POOL among those
--       frames is 459, i.e. below 600 with a full bar", which is what makes the
--       shipped 600 floor look unreachable rather than merely strict.
--
-- ⭐ RE-TAKEN 2026-09-07 (hero, backlog -112).  THE FLAG ON (2) IS LIFTED.
-- Until now every staged Wraith King above level 12 was DEAD, with `alive =
-- false`, `hp = 0` AND `max_hp = 0`.  A capacity field that reads 0 on a dead
-- unit is the dump zeroing capacity, not a hero with no health -- so the OTHER
-- capacity field on the same record could not be quoted as a live pool reading
-- either, in either direction.  That caveat held for the 711 and it still holds
-- for the two dead rows (21 and 19), which the partition below keeps separate.
--
-- What changed is that the tree now also holds a LIVE one:
-- f_260905_004847_lion_drain_bkb.lua carries a level-26 Wraith King with
-- `alive = true`, `hp = max_hp = 2972` and **max_mp 855**.  Nothing is zeroed on
-- that record, so its pool IS quotable -- and 855 lands ABOVE the shipped 600
-- floor.  On a frame the repo owns, hero-10's "largest max pool 459, below 600
-- with a full bar" is false, and the 600 floor is strict rather than unreachable.
--
-- ⚠️ THE BOUND THAT SURVIVES: n = 1 live row.  That is not a rate, and hero-10
-- asks for a rate.  This answers the "unreachable" half of (2) and nothing else.
-- ⚠️ AND HOW IT WAS FOUND, because it is the reusable half: this section was RED
-- ON TRUNK for a day.  The 2026-09-06 round staged that frame and settled the
-- two enumerating scans tests/frames/README.md names by name -- but this file is
-- a THIRD such scan and was not on that list, so the live Wraith King the repo
-- had been missing for weeks arrived unannounced and stayed unread.  The README
-- list is not the set of scans that enumerate the directory; it is the set
-- somebody remembered.  This is the shape GH #357 row 3 paid once already: a
-- zero that was a proxy for the load-bearing zero rather than the thing itself.
--------------------------------------------------------------------------------

tests['6. the staged slot is level 21 -- and its pool reading is flagged, not usable'] =
function()
    local c = scan()
    assert(c.staged_frames >= 1, 'nothing enumerable in ' .. STAGED_DIR
        .. ' -- section 2\'s "recorded 2" then has no witness and the whole tree '
        .. 'ledger is back to being one directory short without saying so')
    assert(c.staged_wk_ge13 == 3, c.staged_wk_ge13 .. ' staged WK slot(s) at level '
        .. '>= 13, recorded 3; section 2\'s equality is computed from this')
    assert(c.staged_wk_max_level == 26, 'the staged Wraith King high-water is level '
        .. tostring(c.staged_wk_max_level) .. ', recorded 26.  Every statement in '
        .. 'this section names it; re-take them')

    -- Partitioned, not last-wins.  With three rows the old `row = r` selector
    -- read whichever the directory listing reached last, and the two kinds of
    -- row answer hero-10 question (2) in OPPOSITE directions.
    local dead, live = {}, {}
    for _, r in ipairs(c.staged_wk_rows) do
        if r.level >= 13 then
            if r.alive == true then live[#live + 1] = r else dead[#dead + 1] = r end
        end
    end
    assert(#dead == 2 and #live == 1,
        'staged WK rows >= 13 partition as ' .. #dead .. ' dead / ' .. #live
        .. ' live, recorded 2 / 1.  The partition IS the reading below; re-take it.')
    for _, r in ipairs(dead) do
        assert(r.level >= 19, 'a dead staged Wraith King fell below 19, so it no '
            .. 'longer speaks to hero-10 question (1) at the >= 18/19 band')
        assert((r.max_hp or -1) == 0,
            'a dead staged row no longer zeroes max_hp; the "capacity field is '
            .. 'zeroed on a dead unit" caveat below rests on that co-occurrence')
    end

    -- ⭐ THE FLAG IS LIFTED, and that is this section's finding as of 2026-09-07.
    -- Until now every staged Wraith King above 12 was DEAD with max_hp = 0, so
    -- the 711 next to it could not be quoted in either direction: a dump that
    -- zeroes one capacity field cannot be trusted on the other.  The 2026-09-06
    -- frame carries a LIVE one -- hp == max_hp, nonzero -- so its pool is a real
    -- reading, and it lands ABOVE the shipped 600 floor.
    local row = live[1]
    assert(row.level >= 19, 'the live staged Wraith King fell below 19, so it no '
        .. 'longer speaks to hero-10 question (1) at the >= 18/19 band it asks about')
    assert((row.max_hp or 0) > 0 and row.hp == row.max_hp,
        'the live staged row no longer reads hp == max_hp > 0 (' .. tostring(row.hp)
        .. '/' .. tostring(row.max_hp) .. ').  That co-occurrence is the ONLY '
        .. 'thing separating this pool reading from the flagged ones above; '
        .. 'without it the flag comes back and hero-10 (2) is unanswered again')
    assert((row.max_mp or 0) > 600, 'the live staged max_mp is '
        .. tostring(row.max_mp) .. ', recorded 855 -- above the shipped 600 floor. '
        .. 'This is the reading that answers hero-10\'s "the LARGEST MAX POOL '
        .. 'among those frames is 459, i.e. below 600 with a full bar": on a '
        .. 'frame the repo owns, a live Wraith King carries 855.')
    -- The bound that survives: one live frame is not a rate.  hero-10 asks for a
    -- distribution over archived timelines and this does not supply one.
    assert(#live == 1, 'more than one live staged Wraith King above 12 now (' .. #live
        .. ').  Good news -- but the "n=1, not a distribution" bound below every '
        .. 'quote of the 855 has moved and must be re-stated, not carried forward.')
end

return tests
