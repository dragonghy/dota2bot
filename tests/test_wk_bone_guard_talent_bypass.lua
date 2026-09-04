-- [hero, GH #17 / #104 backlog section 18 "Lever B"] Wraith King's Bone Guard
-- release rule: what the two t20 disjuncts actually buy, and why X.ConsiderW is
-- the one WK decision that CANNOT be validated on a replay fixture.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- Backlog section 18 left one lever open after the 2026-08-22 re-anchor: "the
-- accounting of the two t20 disjuncts".  X.ConsiderW fires on
--
--     branch 1   ( nStack / maxStack >= 0.6  or  talent6:IsTrained() )
--     branch 2   ( nStack == maxStack        or  talent6:IsTrained() )
--
-- and the natural suspicion -- the one this round set out to confirm -- was that
-- the bypass is a defect: a talent handle that switches OFF the only ammunition
-- test the release rule has, so a WK who owns it would burn a 42s cooldown on an
-- empty bank.  THAT SUSPICION IS WRONG, and section 1 records why: the talent at
-- that slot is `special_bonus_unique_wraith_king_facet_3`, "+5 Bone Guard
-- Skeletons Spawned", a FLAT floor on top of a base `min_skeleton_spawn` of 0.
-- With it trained an activation from an empty bank still puts five skeletons on
-- the field, so "release regardless of the bank" is the correct rule, not a bug.
-- Lever B closes NOT-A-DEFECT.  Nothing in bots/ changes.
--
-- WHAT THE ROUND FOUND INSTEAD (sections 2-4)
-- The first guard of X.ConsiderW is
--     not bot:HasModifier("modifier_skeleton_king_bone_guard")  -> return 0
-- and that modifier appears on ZERO of the 36 Wraith King frames in the fixture
-- corpus, including 19 that carry a modifier list at all (those 19 carry the
-- innate `modifier_skeleton_king_vampiric_spirit_aura` on 19 of 19, so the
-- absence is not "this corpus has no WK modifiers").  Consequence: the shipped
-- X.ConsiderW returns 0 on 36 of 36 real frames, whatever else is true of them.
--
-- CENSUS RE-READ 2026-08-28 (GH #274), VERDICT UNCHANGED.  :269 below instructs
-- that no number in this file may be quoted without re-reading the whole census
-- first, so b50a7727's two fixtures (one venomancer game, all ten hero-slots
-- per frame) bought a re-read rather than a bump.  What the re-read found:
--   * The load-bearing ZERO is intact and its denominator GREW: 0 bone-guard
--     carriers over 36 WK frames, 19 of them carrying a modifier list, sibling
--     control 19 of 19.  A wider denominator makes the unfalsifiable-offline
--     verdict stronger, not weaker.
--   * The shipped function still returns 0 on all 36 with 0 loader refusals.
--   * The blind spot grew 20 -> 22, and the delta is FULLY ATTRIBUTED: both new
--     frames are among the 22.  They are WK at level 11 with Bone Guard already
--     rank 4, so the modifier guard is the only thing standing between them and
--     branch 2 -- the same reason the other 20 are there.  The complement is
--     therefore still exactly 14 frames that stop earlier for reasons the corpus
--     CAN answer, which is why that number in section 3 did not move.
--   * Share of the corpus in the blind spot: 22/36 = 61% (was 20/34 = 59%).
--
-- CENSUS RE-READ 2026-09-01 (GH #392), AND THIS TIME A NUMBER MOVED DOWN.
-- 22 -> 19, on a corpus whose SIZE did not change (36 WK frames, section 2 is
-- still green at 36/19/19).  A shrinking blind spot on a constant denominator is
-- the reading that must never be taken on trust, so section 3b now measures the
-- cause instead of asserting it in prose:
--   * CAUSE: the mana meter, not the guard.  `X.ConsiderW`'s third disjunct is
--     `X.ShouldSaveMana(abilityW)`, which asks `GetMana() - W:GetManaCost() <
--     R:GetManaCost()`.  Until the ladder landed, BOTH costs read 0 (`GetManaCost`
--     was on no spec, so the generic `^Get` answered 0), and the clause was
--     `mana < 0` -- false on every frame that has ever existed.  The rule could
--     not fire; commit ad88ecca is where that was first written down.  With the
--     ladder wired, the reserve rule is alive, and on exactly 3 of the 22 it
--     fires and stops the frame one disjunct BEFORE the modifier guard is
--     reached.  Those 3 leave the blind spot because the corpus can now answer
--     them, which is the direction this file wants numbers to move.
--   * THE 3, each with all three operands of the reserve rule true:
--       f_225947_wk_trade_kite          lv 7, mana 222, 222-100=122 < 220
--       f_232320_wk_od_burst            lv 6, mana 272, 272- 90=182 < 220
--       f_260820_103216_cm_es_aftershock lv 8, mana 280, 280-100=180 < 220
--     All three hold Reincarnation at rank 1 (cost 220) off cooldown, so the
--     `R cd <= 3.0` and `nLV >= 6` operands are true as well.
--   * The move is ONE-DIRECTIONAL and that is checked, not assumed: the 19 are a
--     strict subset of the 22.  No frame ENTERED the blind spot, which is the
--     alarming direction (it would mean the modifier guard started silencing
--     frames it used not to) and is why section 3b asserts the empty set both
--     ways rather than just comparing two counts.
--   * The complement moves 14 -> 17 and its MEANING is unchanged: 17 frames stop
--     earlier for reasons the corpus CAN answer (Bone Guard unlearned or on
--     cooldown, the level 4 floor, and now the mana reserve).
--   * Share of the corpus in the blind spot: 19/36 = 53% (was 22/36 = 61%).
--   * Ratchet consequence, measured not predicted: `tests/frames/README.md`
--     recorded this file's admission delta for the staged frame as
--     "36 -> 37 WK frames, blind spot 22 -> 23".  The base was stale; the staged
--     frame itself was re-measured this round and IS in the blind spot under the
--     real ladder (lv 21, mana 587, 587-100=487 >= R rank-2 cost 110, so the
--     reserve rule is false there).  The delta is therefore 19 -> 20, and that
--     line has been corrected in place.
--
-- The name is NOT wrong.  X.ConsiderW is the only caster of this ability in the
-- whole repo -- `grep -rn bone_guard bots/` outside this hero file finds one
-- weight row in FunLib/spell_list.lua, which only hero_morphling.lua requires --
-- and four corpus frames catch the ability mid-cooldown against its flat 42s
-- (cd 40.2 / 32.5 / 27.1 / 3.5), so the engine answered that HasModifier TRUE
-- during those games.  The absence is a property of the fixture pipeline, not of
-- the world: make_fixture.py rebuilds `modifiers` from combat-log
-- MODIFIER_ADD/REMOVE pairs, and no such pair exists for this one.
--
-- WHY THAT MATTERS ENOUGH TO PIN
-- It is an axeblink trap with a loaded gun in it.  Anyone who proposes a Bone
-- Guard change, measures its domain on fixtures, and reads 0 will conclude the
-- domain is empty -- when what they measured is the tool.  Sections 3 and 4 make
-- that unfalsifiable-by-fixture status explicit and mechanical, so the next round
-- spends its ten minutes on a batch request instead of on a corpus scan that
-- cannot answer.
--
-- HONEST BOUNDS -- read before quoting
--   * "0 of 36" is a statement about the CORPUS, not about a game.  How often WK
--     actually holds charges is unmeasured and unmeasurable here; the baton for
--     it is queue.json `hero-11` (archive event stream, not fixtures).
--   * The datafeed strings in section 1 are RECORDED from a read of odota
--     dotaconstants build/abilities.json on 2026-08-23; this test cannot reach
--     the network and does not re-derive them.
--   * Section 1 does not claim the bypass is GOOD, only that it is coherent: it
--     is a widening disjunct over a real flat floor.  Whether releasing five
--     skeletons the instant a single enemy is within 650u beats banking is a
--     question about the level-20 world.  RE-READ 2026-08-27 (GH #235), and
--     this is the clause that changed: that world is REAL and this hero is in
--     it.  The line used to read "nothing in turbo has reached (GH #84:
--     level >= 20 on 0 of 210 hero-slots, high-water 19)" -- and that zero was
--     the 10-minute batch economy cap, lifted by owner priority P3 / GH #108.
--     The first frame taken past it holds ten heroes at levels 22-27 including
--     THIS ONE at level 26.  So the question the bypass poses is live in every
--     turbo game that goes long, not academic; section 5's trigger has fired.
--   * One residual, registered and NOT resolved here: the empty-bank case the
--     bypass exists for may be pre-empted by the guard ABOVE it, if the engine
--     only applies modifier_skeleton_king_bone_guard while charges >= 1.  That
--     is an in-game question; see section 5's recorded note.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf = require('mock.replay_fixture')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local WK = 'npc_dota_hero_skeleton_king'
local BONE_MOD = 'modifier_skeleton_king_bone_guard'
local SIBLING_MOD = 'modifier_skeleton_king_vampiric_spirit_aura'
-- A real ability name in the same family (dotaconstants lists
-- skeleton_king_bone_guard_damage_tracker), used as the near miss: a criterion
-- loosened to a prefix/substring match swallows it.
local NEAR_MISS_MOD = 'modifier_skeleton_king_bone_guard_damage_tracker'
-- Every WK ability by name, priced or not.  Section 3b zeroes GetManaCost on all
-- of them to reconstruct the pre-ladder meter, and the list is deliberately the
-- WHOLE set rather than the subset `mana_ladder` happens to cover today: a list
-- built from "which ones have an AbilityManaCost row" would silently stop being
-- a reconstruction the day a row is added.  (As of this writing the rows are
-- bone_guard 70/80/90/100, reincarnation 220/110/0 and wraithfire_blast; mortal
-- strike and vampiric spirit carry none and zeroing them is a no-op.)
local WK_ABILITIES = {
    'skeleton_king_wraithfire_blast',
    'skeleton_king_vampiric_spirit',
    'skeleton_king_mortal_strike',
    'skeleton_king_bone_guard',
    'skeleton_king_reincarnation',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Live (non-comment) lines only.  The block comment in this hero file is an npc
--- dump whose lines do not start with `--`, so it has to be stripped as a block
--- first -- same trap test_wk_fact_anchor.lua documents.
local function live_lines(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 1. Lever B: the t20 bypass is a widening disjunct over a flat +5 floor.

-- RECORDED, not re-derived (odota dotaconstants build/abilities.json, read
-- 2026-08-23).  Kept as data so a future re-anchor edits one table.
local FEED = {
    talent_dname = '+5 Bone Guard Skeletons Spawned',
    talent_key = 'special_bonus_unique_wraith_king_facet_3',
    min_skeleton_spawn = 0,
    max_skeleton_charges = { 2, 4, 6, 8 },
    bone_guard_flat_cooldown = 42,
}

tests['[section 1] the talent read as talent6 is a FLAT skeleton floor'] = function()
    -- The whole Lever B verdict rests on these two recorded facts sitting next
    -- to each other, so state them as one assertion rather than as prose: the
    -- bonus is a count of skeletons SPAWNED (not charges granted, not a cap
    -- raise), and the base floor it lifts is zero.
    if not FEED.talent_dname:match('^%+(%d+) Bone Guard Skeletons Spawned$') then
        error('the recorded talent name no longer reads as a flat skeleton '
            .. 'count ("' .. FEED.talent_dname .. '").  Lever B closed '
            .. 'NOT-A-DEFECT only because it is flat: re-open the accounting '
            .. 'before quoting this file')
    end
    if FEED.min_skeleton_spawn ~= 0 then
        error('base min_skeleton_spawn is recorded as '
            .. tostring(FEED.min_skeleton_spawn) .. ', not 0.  If the shipped '
            .. 'ability already spawns skeletons from an empty bank, the bypass '
            .. 'is redundant rather than corrective and section 1 is stale')
    end
end

tests['[section 1] both t20 reads are RIGHT operands of `or` -- widening only'] =
function()
    local n, widening = 0, 0
    for _, line in ipairs(live_lines(read_file(WK_SRC))) do
        for _ in line:gmatch('talent6:IsTrained%(%)') do n = n + 1 end
        -- `X or talent6:IsTrained()` can only ADD firings; `X and ...` or a
        -- negated form could remove them, and that would make the bypass a veto
        -- rather than a floor -- a different verdict entirely.
        if line:match('or%s+talent6:IsTrained%(%)') then widening = widening + 1 end
    end
    if n ~= 2 then
        error('expected exactly 2 live reads of talent6:IsTrained() in '
            .. WK_SRC .. ', found ' .. n .. '.  Lever B is an accounting of TWO '
            .. 'disjuncts; a third read (or a lost one) invalidates it')
    end
    if widening ~= 2 then
        error(n .. ' live reads of talent6:IsTrained(), but only ' .. widening
            .. ' of them are the right operand of `or`.  A read in any other '
            .. 'position can REMOVE firings, and this file\'s verdict '
            .. '("widening disjunct over a flat floor") does not cover that')
    end
end

tests['[section 1] this file\'s own talent build really takes index 6 at t20'] =
function()
    -- Read the pick out of the code rather than asserting it: capture the table
    -- the hero file hands to J.Skill.GetTalentBuild, then run the SHIPPED
    -- GetTalentBuild on it.  (test_wk_fact_anchor.lua section 2 already pins
    -- that the t20 row drives indices {5,6}; what is unpinned, and what the
    -- bypass depends on, is which SIDE of that pair this file takes.)
    api.reset_modules()
    api.install({ bot = api.MakeHero(WK) })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    local real = J.Skill.GetTalentBuild
    local captured
    J.Skill.GetTalentBuild = function(cfg)
        captured = cfg
        return real(cfg)
    end
    local ok, err = pcall(dofile, WK_SRC)
    J.Skill.GetTalentBuild = real
    if not ok then error('loading ' .. WK_SRC .. ' failed: ' .. tostring(err)) end
    if type(captured) ~= 'table' or type(captured.t20) ~= 'table' then
        error('the hero file no longer routes its talent tree through '
            .. 'J.Skill.GetTalentBuild, so which index it takes at t20 cannot '
            .. 'be read this way any more')
    end

    local picks = real(captured)
    if picks[3] ~= 6 then
        error('this file takes sTalentList index ' .. tostring(picks[3])
            .. ' at t20, not 6 -- so `talent6` is a handle on a talent the '
            .. 'shipped build never trains, and the two disjuncts are dead for '
            .. 'a second, independent reason')
    end
end

-- ---------------------------------------------------------------------------
-- 2. The corpus census, with the predicate and the report split apart.
--
-- Backlog section 24: a scan that asserts an EMPTY result has no live positive
-- path, so every mutation to its reporting half escapes.  `carries_bone_guard`
-- is the predicate, `scan_frames` the report, and both are driven on synthetic
-- input at the end of this section.
--
-- Section 24's own correction applies here in BOTH directions, unusually: the
-- loosening direction has a live counterexample in the tree (19 frames carry a
-- sibling `modifier_skeleton_king_*`, so a substring predicate immediately
-- reports), and the silence direction needs the synthetic offender.

local function carries_bone_guard(unit)
    for _, m in ipairs(unit.modifiers or {}) do
        if m.name == BONE_MOD then return true end
    end
    return false
end

local function scan_frames(frames)
    local c = { frames = 0, wk = 0, with_mods = 0, sibling = 0, bone = 0 }
    local rows = {}
    for _, fx in ipairs(frames) do
        if type(fx) == 'table' and type(fx.units) == 'table' then
            c.frames = c.frames + 1
            for _, u in ipairs(fx.units) do
                if u.name == WK then
                    c.wk = c.wk + 1
                    if u.modifiers ~= nil and #u.modifiers > 0 then
                        c.with_mods = c.with_mods + 1
                    end
                    for _, m in ipairs(u.modifiers or {}) do
                        if m.name:match('^modifier_skeleton_king_') then
                            c.sibling = c.sibling + 1
                            break
                        end
                    end
                    if carries_bone_guard(u) then
                        c.bone = c.bone + 1
                        rows[#rows + 1] = string.format('%s t=%s',
                            tostring(fx.game), tostring(fx.time))
                    end
                end
            end
        end
    end
    return c, rows
end

local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^.+%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

local function corpus_frames()
    local frames = {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok then frames[#frames + 1] = fx end
    end
    return frames
end

tests['[section 2] 36 WK frames, 19 with modifiers, 0 carrying the bone modifier'] =
function()
    local c = scan_frames(corpus_frames())
    if c.wk ~= 36 then
        error('the corpus holds ' .. c.wk .. ' Wraith King frames, recorded 36. '
            .. 'Fixtures were added or removed; re-read the whole census before '
            .. 'quoting any number from this file (GH #106)')
    end
    if c.with_mods ~= 19 then
        error(c.with_mods .. ' of the WK frames carry a modifier list, recorded '
            .. '19.  This is the denominator that makes the 0 below evidence '
            .. 'rather than an artefact of v1 fixtures')
    end
    if c.sibling ~= 19 then
        error(c.sibling .. ' of the WK frames carry SOME modifier_skeleton_king_'
            .. '* modifier, recorded 19.  If this ever drops below with_mods, '
            .. 'the corpus stopped carrying WK modifiers at all and the '
            .. 'bone-guard 0 loses its control group')
    end
    if c.bone ~= 0 then
        error(c.bone .. ' WK frames carry ' .. BONE_MOD .. ', recorded 0.  That '
            .. 'is GOOD news: X.ConsiderW became fixture-testable and this '
            .. 'file\'s whole "unfalsifiable offline" verdict should be redone')
    end
end

local function synth_frame(mods)
    return {
        game = 'SYNTHETIC', time = 0,
        units = { { name = WK, team = 2, hp = 1000, max_hp = 1000, alive = true,
                    modifiers = mods } },
    }
end

tests['[section 2] the report half is alive: a synthetic carrier IS reported'] =
function()
    local c, rows = scan_frames({ synth_frame({ { name = BONE_MOD, stacks = 3 } }) })
    if c.bone ~= 1 or #rows ~= 1 then
        error('a frame carrying ' .. BONE_MOD .. ' was counted ' .. c.bone
            .. ' time(s) and reported in ' .. #rows .. ' row(s).  With a clean '
            .. 'corpus this is the ONLY thing that can prove the counting and '
            .. 'the reporting halves still work (backlog section 24)')
    end
end

tests['[section 2] near miss: the damage-tracker modifier is NOT reported'] =
function()
    local c = scan_frames({ synth_frame({ { name = NEAR_MISS_MOD, stacks = 0 } }) })
    if c.bone ~= 0 then
        error(NEAR_MISS_MOD .. ' was counted as the charge modifier.  The '
            .. 'shipped guard asks HasModifier for an exact name, so a '
            .. 'prefix/substring predicate here would report a hit the bot '
            .. 'itself does not see')
    end
    if c.sibling ~= 1 then
        error('the sibling control did not fire on the near miss, so this test '
            .. 'no longer proves the frame reached the predicate at all')
    end
end

tests['[section 2] loosening has a live counterexample -- the sibling column'] =
function()
    -- Section 24's correction: check whether the tree carries a legal-but-
    -- adjacent shape before deciding the synthetic input has to cover both
    -- directions.  Here it does -- 19 real frames -- so a predicate loosened to
    -- the family prefix reports 19 instead of 0 without any synthetic help.
    local c = scan_frames(corpus_frames())
    if c.sibling <= c.bone then
        error('the corpus no longer separates "an exact-name miss" from "no WK '
            .. 'modifiers at all" (sibling ' .. c.sibling .. ' vs bone '
            .. c.bone .. '), so a loosened predicate would now be silent too '
            .. 'and BOTH directions need synthetic input')
    end
end

-- ---------------------------------------------------------------------------
-- 3. The shipped function on every real frame, and the one-field counterfactual.

local function wk_fixture_paths()
    local out = {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == WK then out[#out + 1] = path break end
            end
        end
    end
    return out
end

--- Drive the shipped X.ConsiderW on one real frame.  `grant` = true installs the
--- ONE field the corpus cannot supply (HasModifier for the charge modifier) and
--- changes nothing else.  Returns the desire, or the string 'REFUSED' when the
--- run reaches a loader refusal -- which is itself the observation: it means the
--- function got PAST the modifier guard.
local function desire_on(path, grant)
    local _, bot = rf.load(path, WK)
    if grant then
        local spec = rawget(bot, '__spec')
        spec.HasModifier = function(_, sName) return sName == BONE_MOD end
    end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)   -- primes the file-level nLV/nMP/nHP
    local ok, d = pcall(function() return X.ConsiderW() end)
    if not ok then return 'REFUSED' end
    return d
end

tests['[section 3] shipped X.ConsiderW is 0 on 36 of 36 real WK frames'] =
function()
    local paths = wk_fixture_paths()
    local n, fired, refused = #paths, 0, 0
    for _, path in ipairs(paths) do
        local d = desire_on(path, false)
        if d == 'REFUSED' then refused = refused + 1
        elseif type(d) == 'number' and d > 0 then fired = fired + 1 end
    end
    if n ~= 36 then
        error('drove ' .. n .. ' WK frames, recorded 36 (see section 2)')
    end
    if fired ~= 0 or refused ~= 0 then
        error('shipped X.ConsiderW fired on ' .. fired .. ' frame(s) and hit a '
            .. 'loader refusal on ' .. refused .. '; recorded 0 and 0.  A '
            .. 'non-zero here means Bone Guard became drivable offline and the '
            .. 'unmeasurability verdict is stale')
    end
end

tests['[section 3] granting ONLY HasModifier moves 19 frames past the guard'] =
function()
    -- The counterfactual that makes "the modifier guard is what silences it"
    -- a measurement rather than a reading of the source: flip that one field and
    -- nothing else.  19 frames then run on into X.IsNearLaneFront, where the
    -- loader refuses to invent lane fronts (GH #61) -- i.e. on those frames the
    -- guard was the ONLY thing between the bot and branch 2.  The other 17 stop
    -- earlier for reasons the corpus CAN answer (Bone Guard unlearned or on
    -- cooldown, the level 4 floor, or -- since the mana ladder landed -- the
    -- reserve rule X.ShouldSaveMana).
    --
    -- 20 -> 22 on 2026-08-28 (GH #274) and the complement did NOT move: both of
    -- b50a7727's frames are in the blind spot, both WK level 11 with Bone Guard
    -- at rank 4.  That is the re-read :269 demands, not a re-baseline -- an
    -- unattributed +2 here would have been indistinguishable from the guard
    -- starting to silence frames it used not to.
    --
    -- 22 -> 19 on 2026-09-01 (GH #392) on an UNCHANGED denominator, and the -3
    -- is attributed by MEASUREMENT in section 3b below, not by this comment:
    -- three frames now stop at X.ShouldSaveMana, one disjunct before the modifier
    -- guard.  See the file header for the three and their operands.
    -- 19 -> 0 on 2026-09-04 (hero, `kvgetters`), and the cause is section 4's
    -- own prediction coming true rather than anything about Bone Guard.  The
    -- loader now serves GetSpecialValue* from the KV snapshot
    -- (tests/test_fixture_kv_getters.lua), so max_skeleton_charges answers 8 at
    -- rank 4 where it used to answer 0.  Section 4 recorded exactly what that
    -- zero was doing: `nStack == maxStack` was `0 == 0`, i.e. branch 2 passed
    -- its AMMUNITION test for free.  Every one of the 19 "moved" frames was
    -- moving past the modifier guard and then being waved through by that free
    -- pass.  With the real ceiling in place a WK holding no charges correctly
    -- declines, so granting HasModifier alone moves nobody.
    --
    -- ⚠ THE 19 IS ARCHIVED, NOT REBASELINED TO 0.  It was never a measurement
    -- of the modifier guard's blind spot on its own -- it was that guard AND a
    -- vacuous ammunition test, and nothing in this file could separate them
    -- until the second one stopped being vacuous.  Do not quote it as "the
    -- corpus says 19 frames are hidden behind the modifier".
    local ARCHIVED_MOVED_20260901 = 19
    local paths = wk_fixture_paths()
    local moved = 0
    for _, path in ipairs(paths) do
        local before, after = desire_on(path, false), desire_on(path, true)
        if before == 0 and after ~= 0 then moved = moved + 1 end
    end
    if moved ~= 0 then
        error('granting HasModifier alone changed the outcome on ' .. moved
            .. ' frames, recorded 0 (archived: ' .. ARCHIVED_MOVED_20260901
            .. ' under the vacuous ammunition test).  A non-zero here means the '
            .. 'modifier guard is hiding frames on its own merits -- that is a '
            .. 'FINDING and it needs section 4 re-read first, because section 4 '
            .. 'is what stopped being vacuous')
    end
end

--- Same drive as `desire_on`, plus the one further counterfactual that
--- reconstructs the pre-ladder meter: force every WK ability's GetManaCost back
--- to 0 (and drop the mana term of IsFullyCastable with it, since that term is
--- derived from the same price).  This is the world in which X.ShouldSaveMana
--- asks `GetMana() < 0` and can never be true.
local function desire_on_zero_mana(path, grant)
    local _, bot = rf.load(path, WK)
    if grant then
        local spec = rawget(bot, '__spec')
        spec.HasModifier = function(_, sName) return sName == BONE_MOD end
    end
    for _, sName in ipairs(WK_ABILITIES) do
        local h = bot:GetAbilityByName(sName)
        local sp = rawget(h, '__spec')
        sp.GetManaCost = function() return 0 end
        sp.IsFullyCastable = function(self)
            return self:GetLevel() > 0 and self:GetCooldownTimeRemaining() <= 0
        end
    end
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)
    local ok, d = pcall(function() return X.ConsiderW() end)
    if not ok then return 'REFUSED' end
    return d
end

-- RE-ANCHORED 2026-09-04 (hero, `kvgetters`).  THIS SECTION IS NOW AN ARCHIVE,
-- and it is archived rather than deleted because the numbers in it are the only
-- record of what the pre-repair world measured.
--
-- What changed: the loader serves GetSpecialValue* from the KV snapshot
-- (tests/test_fixture_kv_getters.lua), so max_skeleton_charges answers its real
-- ladder (8 at rank 4) where it used to answer the mock's Get* default 0.
-- Section 4 already wrote down what that 0 was doing -- `nStack == maxStack`
-- was `0 == 0`, so branch 2 passed its AMMUNITION test for free -- and it
-- pre-registered this exact consequence: "If the fixture world learned special
-- values, branch 1's ratio test became meaningful and this section needs
-- redoing."
--
-- So BOTH counts this section decomposed are 0 today, on both legs, and the
-- decomposition has no population left to run on.  That is not a regression and
-- it is not a null result: it is the discovery that the 22 and the 19 were never
-- measuring the modifier guard alone.  They were measuring the guard AND a
-- vacuous ammunition test, and nothing in this file could separate the two until
-- the second one stopped being vacuous.
--
-- ARCHIVED READINGS (do NOT re-derive them from a green run of this file):
--     2026-08-28 (GH #274), GetManaCost forced to 0 ... blind spot 22
--     2026-09-01 (GH #392), real mana ladder ......... blind spot 19
--     the three that left, named:
--         tests/fixtures/f_225947_wk_trade_kite.lua
--         tests/fixtures/f_232320_wk_od_burst.lua
--         tests/fixtures/f_260820_103216_cm_es_aftershock.lua
--     entered the blind spot ......................... 0
local ARCHIVED_PRE_LADDER_20260828 = 22
local ARCHIVED_POST_LADDER_20260901 = 19
local ARCHIVED_LEFT_20260901 = {
    'tests/fixtures/f_225947_wk_trade_kite.lua',
    'tests/fixtures/f_232320_wk_od_burst.lua',
    'tests/fixtures/f_260820_103216_cm_es_aftershock.lua',
}

tests['[section 3b] ARCHIVED: the 22 -> 19 attribution, and why it has no population left'] =
function()
    local paths = wk_fixture_paths()
    local now, pre = {}, {}
    for _, path in ipairs(paths) do
        if desire_on(path, false) == 0 and desire_on(path, true) ~= 0 then
            now[path] = true
        end
        if desire_on_zero_mana(path, false) == 0
            and desire_on_zero_mana(path, true) ~= 0 then
            pre[path] = true
        end
    end
    local n_now, n_pre = 0, 0
    for _ in pairs(now) do n_now = n_now + 1 end
    for _ in pairs(pre) do n_pre = n_pre + 1 end

    if n_now ~= 0 or n_pre ~= 0 then
        error('the blind spot is ' .. n_now .. ' with the real mana ladder and '
            .. n_pre .. ' with GetManaCost forced to 0; both are recorded 0 '
            .. 'since the KV getters landed (archived: '
            .. ARCHIVED_POST_LADDER_20260901 .. ' and '
            .. ARCHIVED_PRE_LADDER_20260828 .. ').  A NON-ZERO IS A FINDING, not '
            .. 'a regression: it means the modifier guard hides frames on its '
            .. 'own merits, which nothing has ever shown.  Read section 4 first '
            .. '-- it is the half that stopped being vacuous.')
    end

    -- The archived pair still has to point the way its attribution says it did.
    -- This is the one live check left here: it guards the ARCHIVE against being
    -- quietly edited, which is the only way these numbers can now go wrong.
    if not (ARCHIVED_PRE_LADDER_20260828 > ARCHIVED_POST_LADDER_20260901) then
        error('the archived pair no longer shows the 22 -> 19 direction this '
            .. 'section was written to attribute')
    end
    if ARCHIVED_PRE_LADDER_20260828 - ARCHIVED_POST_LADDER_20260901
        ~= #ARCHIVED_LEFT_20260901 then
        error('the archived -3 no longer matches the three frames named for it; '
            .. 'the archive has been edited on one side only')
    end
    for _, path in ipairs(ARCHIVED_LEFT_20260901) do
        local fh = io.open(path, 'r')
        if fh == nil then
            error('the archive names a fixture that is gone: ' .. path
                .. ' -- an archive whose members cannot be looked at is a number, '
                .. 'not a record')
        end
        fh:close()
    end
end


-- ---------------------------------------------------------------------------
-- 4. Two further reasons the release ARITHMETIC is meaningless offline.
--
-- Even a corpus that carried the modifier would not make X.ConsiderW drivable:
-- both operands of both thresholds are unanswered in the fixture world.

-- REDONE 2026-09-04 (hero, `kvgetters`), exactly as the old version of this case
-- asked to be: "If the fixture world learned special values, branch 1's ratio
-- test became meaningful and this section needs redoing."  It did, and this is
-- the redo.
--
-- ARCHIVED READING (2026-08-28 .. 2026-09-03): max_skeleton_charges answered 0
-- offline, the mock Get* default.  Its consequences on the shipped rule were
-- the ratio being a NaN comparison (false) and the equality being `0 == 0`
-- (TRUE), so branch 2 passed its AMMUNITION test FOR FREE.  That free pass is
-- what sections 3 and 3b were really measuring; see the archive there.
--
-- WHAT IS STILL UNANSWERABLE, which is the half this section keeps.  The
-- threshold has TWO operands and only one of them was ever a KV constant.  The
-- CEILING (max_skeleton_charges) is now real.  The CURRENT charge count is a
-- modifier stack count, which no snapshot carries and this repair does not
-- touch -- so `nStack` is still 0-by-absence and the branch now reads
-- `0 == 8` (false) instead of `0 == 0` (true).  The arithmetic went from
-- trivially TRUE to trivially FALSE; it did not become drivable.  Both failure
-- directions are asserted below so neither can drift silently.
tests['[section 4] the ceiling is real now; the CURRENT stack count still is not'] =
function()
    local shapes = require('mock.special_value_shapes')
    local _, bot = rf.load('tests/fixtures/f_260820_102030_wk_tower_in_reach.lua', WK)
    local w = bot:GetAbilityByName('skeleton_king_bone_guard')
    if w:GetLevel() < 1 then
        error('this frame no longer has Bone Guard trained, so it cannot carry '
            .. 'the point about the special value')
    end

    -- The ceiling, against the ladder in the snapshot -- parsed, not retyped.
    local kv = shapes.SHAPES['skeleton_king']['skeleton_king_bone_guard']
    local entry = kv and kv['max_skeleton_charges']
    if entry == nil or entry.base == nil then
        error('the KV snapshot no longer carries max_skeleton_charges for Bone '
            .. 'Guard; without it this case is not making its claim')
    end
    local steps = {}
    for tok in entry.base:gmatch('%S+') do steps[#steps + 1] = tonumber(tok) end
    local rank = w:GetLevel()
    local want = steps[math.min(rank, #steps)]
    local maxStack = w:GetSpecialValueInt('max_skeleton_charges')
    if maxStack ~= want then
        error('max_skeleton_charges answers ' .. tostring(maxStack) .. ' at rank '
            .. rank .. ', KV ladder says ' .. tostring(want)
            .. '.  A 0 here means the loader stopped serving GetSpecialValue* and '
            .. 'sections 3 and 3b are back in their archived world')
    end
    if maxStack <= 0 then
        error('the ceiling must be positive for the equality below to be the '
            .. 'FALSE it is claimed to be')
    end

    -- The operand that did NOT become answerable.  A modifier stack count is not
    -- KV; nothing in this repo carries it, and the branch reads it as 0.
    local nStack = bot:GetModifierStackCount(0, bot)
    if nStack ~= 0 then
        error('GetModifierStackCount answers ' .. tostring(nStack)
            .. ' now, recorded 0 (unimplemented in the mock).  If the loader '
            .. 'learned stack counts, X.ConsiderW branch 2 became drivable and '
            .. 'the unmeasurability verdict in this file is stale -- that is a '
            .. 'FINDING, write it up')
    end
    if nStack == maxStack then
        error('the ammunition equality is TRUE again (' .. nStack .. ' == '
            .. maxStack .. '), i.e. branch 2 is back to passing for free')
    end
    -- And the ratio, which is now an ordinary false rather than a NaN one.
    local ratio = nStack / maxStack
    if ratio >= 0.6 then
        error('0 / ' .. maxStack .. ' >= 0.6 answered true; the note above is wrong')
    end
end

tests['[section 4] the loader has no GetModifierByName -- the bank is read off row 1'] =
function()
    local _, bot = rf.load('tests/fixtures/f_260820_102030_wk_tower_in_reach.lua', WK)
    local idx = bot:GetModifierByName(BONE_MOD)
    if idx ~= 0 then
        error('GetModifierByName answered ' .. tostring(idx) .. ' for a modifier '
            .. 'this hero does not carry; recorded 0 (the mock Get* default, '
            .. 'i.e. unimplemented).  If the loader implemented it, -1 would be '
            .. 'the honest answer and X.ConsiderW\'s `modIdx > -1` guard would '
            .. 'start working')
    end
    -- Consequence: `bot:GetModifierStackCount(0)` is row 1 of whatever this hero
    -- happens to carry, sorted by name -- here the Reincarnation scepter buff.
    local first = bot:GetModifierName(0)
    if first == BONE_MOD then
        error('row 0 is the bone-guard modifier itself, so this frame cannot '
            .. 'demonstrate the mis-read')
    end
    if not first:match('^modifier_') then
        error('row 0 of this hero\'s modifier list reads "' .. tostring(first)
            .. '", so the corpus no longer supports the point that the stack '
            .. 'count would be taken from an unrelated modifier')
    end
end

-- ---------------------------------------------------------------------------
-- 5. Recorded, NOT tested: the one residual Lever B leaves open.
--
-- If the engine applies modifier_skeleton_king_bone_guard only while charges are
-- >= 1, then the guard at the top of X.ConsiderW re-imposes exactly the
-- ammunition requirement the t20 bypass exists to lift, and the "+5 from an
-- empty bank" case can never happen no matter how the disjuncts read.  That is
-- an in-game question -- HasModifier is engine state, and the corpus cannot
-- answer it for the reasons above -- so it is registered rather than argued.
--
-- STATUS 2026-08-27 (GH #235): the trigger this note named HAS FIRED.  It said
-- the residual "only becomes payable at level 20, which turbo has not reached
-- (GH #84)", and that GH #108's cap lift 10 -> 25 minutes was the change most
-- likely to make it payable.  The cap is lifted and the first post-cap frame
-- reads this hero at level 26 in a naturally-ended 24.9-minute game.  So the
-- residual is now a question about games we actually play.
--
-- What has NOT changed is that no frame can settle it, and 2026-08-27 upgraded
-- that from an observation to a mechanism: the dumper's isRealAbility() drops
-- every hero-unique talent before it is ever written, so a corpus read of
-- talent6:IsTrained() answers zero whether or not it is trained.  Ten hero-slots
-- at levels 22-27 must have spent 36 talent points between them and the frame
-- shows 8, all generic -- which is what rules out "the bots just never take
-- it".  tests/test_lategame_talent_visibility.lua.  The reading that would
-- settle the residual is an in-game one, and queue request `hero-21` (a re-dump
-- with the drop rule lifted) is the cheapest thing that gets near it.

return tests
