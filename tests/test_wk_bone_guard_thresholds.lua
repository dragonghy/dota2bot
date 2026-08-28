-- [hero, GH #17 / #104] Wraith King: what a Bone Guard skill point does to the
-- shipped release rule, and therefore what 'wkbuild' condition (c) is allowed to
-- claim.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- The re-anchor in tests/test_wk_fact_anchor.lua voided the rationale recorded
-- with the 'wkbuild' gate: it said the build "keeps Vampiric Aura points for lane
-- sustain", and index 2 is not lifesteal at all -- it is Bone Guard, an active
-- 42s-cooldown skeleton release, and both build rows spend four points on it.
-- That left the gate with NO condition (c).  This file is the replacement
-- argument, driven on shipped code rather than written as prose.
--
-- THE MECHANISM
--   A Bone Guard point raises max_skeleton_charges 2 -> 4 -> 6 -> 8 (datafeed
--   hero_id 42, read 2026-08-22).  X.ConsiderW releases on
--       branch 1   nStack / maxStack >= 0.6      (needs a single nearby target)
--       branch 2   nStack == maxStack            (lane front or farming)
--   with `talent6:IsTrained()` as the only bypass on either -- a level-20 test
--   (test_wk_fact_anchor.lua section 2).  This block used to add that the GH #84
--   census read level 20 on 0 of 210 turbo hero-slots, i.e. that the bypass was
--   dead and the thresholds were the whole rule.  CORRECTED 2026-08-28 (GH #235):
--   that zero was the batch harness's 10-minute economy cap, and the first frame
--   taken past it has THIS hero at level 26 with Bone Guard already at rank 4.
--   The bypass is live from level 20 on, and section 6 below measures what it
--   does.  Both tests are thresholds ON THE CAP, so raising the cap raises the
--   bank WK must hold before he will release anything.  Early Bone Guard points
--   make his own Bone Guard rarer -- see WHERE THAT HOLDS.
--
-- WHERE THAT HOLDS (this is what replaced the census, 2026-08-28)
--   The sweep below needs the bypass inert, and it used to get that from the
--   ceiling: level 20 never happened, so talent6 never existed.  With the ceiling
--   retired the inertness has to come from somewhere that is still true, and it
--   does -- from the DOMAIN OF THE QUANTITY rather than from the reachable range.
--   Condition (c) is a claim about WHEN THE CAP RISES, and both shipped rows have
--   spent all four Bone Guard points by hero level 12 (default 1/3/5/7, the
--   'wkbuild' row 1/9/10/12; the last test in this file pins both).  Twelve is
--   eight levels below the earliest level at which talent6 can exist, so every
--   cap transition this file sweeps happens while the bypass is untrainable, and
--   the untrained stub is the right frame for the question being asked.
--   Section 7 asserts that gap mechanically instead of leaving it as prose.
--
--   The honest cost of the correction is that condition (c) now has a LIFETIME.
--   From level 20 the bypass short-circuits both branches unconditionally, so the
--   'wkbuild' delay buys its frequency advantage over levels 12-19 and that
--   advantage EXPIRES -- and post-cap turbo demonstrably plays past the expiry
--   (ten hero-slots at 22-27 in a 24.9-minute naturally-ended game).  Section 6
--   reads the expiry out of the shipped function rather than asserting it.
--
-- WHAT IS PINNED HERE
--   1. the frame is honest (the release CAN fire there, so silence is a decision
--      and not a missing precondition);
--   2. sections 2 and 3 sweep the ability level with the charge bank HELD FIXED,
--      on each branch, so the only thing that moves is how many skill points went
--      into Bone Guard;
--   3. section 4 does not assert my arithmetic -- it reads the threshold out of
--      the shipped function by sweeping the bank and recording the smallest one
--      that fires, per ability level, per branch.  (test_wk_fact_anchor.lua's own
--      methodology note: asserting a mapping and reading a mapping out of the
--      code are two different tests, and only the second one catches a mutation
--      that re-points the mapping.)
--
-- HONEST BOUNDS -- read these before quoting the file
--   * This fixes the SIGN of the effect, not its size.  Whether WK actually banks
--     2 charges or 8 between releases is a corpus question, and it is one we
--     cannot ask offline: the dumper does not record modifier stack counts (same
--     gap family as GH #27).  Nothing here is a claim about frequency in a game.
--   * A higher cap also raises the PAYLOAD of a release (8 skeletons at 49 damage
--     against 2 at 34).  The claim is one-sided on purpose: the frequency loss is
--     automatic under the shipped rule, the payload gain is conditional on charge
--     supply nobody has measured.
--   * No real frame.  This is the shipped X.ConsiderW under the mock API.
--   * The datafeed numbers in section 5 are RECORDED, not re-derived; this test
--     cannot reach the network.
--   * Section 6 shows the bypass DISARMS the thresholds when talent6 is trained.
--     It does not show the bypass ever fires in a game.  No frame this repo holds
--     can: the dumper drops hero-unique talent rows before writing them (960
--     hero-frames, 67 talent sightings, zero unique rows --
--     tests/test_lategame_talent_visibility.lua, GH #260), and slot 6 is a
--     `special_bonus_unique_*` row.  A corpus read of talent6:IsTrained() comes
--     back zero whether or not it is trained, so the zero is not evidence.
--     tests/test_wk_bone_guard_talent_bypass.lua carries that residual, together
--     with the second one section 6 inherits: if the engine only carries
--     modifier_skeleton_king_bone_guard while charges >= 1, X.ConsiderW's own top
--     guard re-imposes the ammunition test the bypass lifts.  Section 6 holds
--     that modifier true by construction, so it prices the BRANCH TESTS and not
--     the guard above them.
--   * The level-26 reading is ONE frame.  It kills the universal ("level 20 does
--     not happen in turbo") because a universal dies to one counterexample; it is
--     not a distribution, and nothing here says how much of a turbo game is spent
--     past level 20.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local BONE = 'skeleton_king_bone_guard'
local BONE_MOD = 'modifier_skeleton_king_bone_guard'

-- max_skeleton_charges by ability level, datafeed hero_id 42 read 2026-08-22.
local MAX_CHARGES = { 2, 4, 6, 8 }

local tests = {}

----------------------------------------------------------------------
-- Frame construction.
--
-- `where` picks which release branch is even eligible:
--   'lane'  -- WK standing on a lane front with nobody in sight  -> branch 2 only
--   'duel'  -- WK far from every lane front with exactly one enemy hero at 300u,
--              and that enemy is his current target              -> branch 1 only
-- Keeping the two apart is what makes a silence attributable to one threshold.

--
-- `talentTrained` (default false) arms the t20 bypass `talent6:IsTrained()`.
-- Sections 1-4 leave it false, which is the level-1..19 world every cap
-- transition in the shipped builds happens in; section 6 sets it true to price
-- what the bypass does once it CAN be trained.

local function make_frame(where, boneLevel, stacks, talentTrained)
    api.reset_modules()

    local maxCharges = MAX_CHARGES[boneLevel]
    local bone = api.MakeAbility(BONE, {
        IsFullyCastable = true,
        GetLevel = boneLevel,
        GetManaCost = 60 + 10 * boneLevel,       -- 70/80/90/100
        GetSpecialValueInt = maxCharges,
    })
    local reincarnation = api.MakeAbility('skeleton_king_reincarnation', {
        GetManaCost = 220,
        GetCooldownTimeRemaining = 0,
    })

    local enemy = api.MakeHero('npc_dota_hero_lion', {
        GetTeam = 3,                             -- TEAM_DIRE, bot is on 2
        CanBeSeen = true,
        GetLocation = api.Vector(300, 0, 0),     -- inside branch 1's 650u ring
    })
    local seesEnemy = (where == 'duel')

    local bot = api.MakeHero('npc_dota_hero_skeleton_king', {
        GetLevel = 12,
        CanBeSeen = true,
        GetLocation = api.Vector(0, 0, 0),
        GetMana = 500,          -- 500 - 100 >= 220, so X.ShouldSaveMana is false
        GetMaxMana = 500,
        GetActiveMode = BOT_MODE_NONE,
        HasModifier = function(_, name) return name == BONE_MOD end,
        GetModifierByName = function(_, name) return name == BONE_MOD and 3 or -1 end,
        GetModifierStackCount = stacks,
        GetNearbyHeroes = function(_, _, bEnemy)
            if bEnemy and seesEnemy then return { enemy } end
            return {}
        end,
        GetTarget = function() return seesEnemy and enemy or nil end,
        GetAbilityByName = function(self, name)
            if name == BONE then return bone end
            if name == 'skeleton_king_reincarnation' then return reincarnation end
            -- sTalentList is empty under the mock, so the file's
            -- `bot:GetAbilityByName(sTalentList[6])` arrives here as nil.  This
            -- used to hand back an untrained stub unconditionally, on the ground
            -- that "an untrained stub is the turbo reality (GH #84: level >= 20
            -- on 0 of 210 hero-slots)".  CORRECTED 2026-08-28 (GH #235): that
            -- zero was the batch cap, not turbo.  The stub is still untrained for
            -- sections 1-4, but now for the reason in WHERE THAT HOLDS -- the cap
            -- transitions being swept are all spent by hero level 12 -- and it is
            -- a PARAMETER, so section 6 can price the trained side instead of
            -- assuming it away.
            if name == nil then
                return api.MakeAbility('mock_t20_talent',
                    { IsTrained = (talentTrained == true) })
            end
            return api.MakeAbility(name)
        end,
    })
    api.install({ bot = bot })

    -- X.IsNearLaneFront walks the three lane fronts and asks for <= 600.
    _G.GetLaneFrontLocation = function() return api.Vector(0, 0, 0) end
    _G.GetUnitToLocationDistance = function()
        return where == 'lane' and 100 or 5000
    end

    local X = dofile(WK_SRC)
    X.SkillsComplement()  -- sets the file-level nLV / nMP / nHP this path reads
    return X, bot, enemy
end

local function fires(where, boneLevel, stacks, talentTrained)
    local X = make_frame(where, boneLevel, stacks, talentTrained)
    return X.ConsiderW() > 0
end

----------------------------------------------------------------------
-- 1. The frame is honest on both branches.

tests['[GH #17] lane frame: the release fires there at a full bank'] = function()
    local X, bot = make_frame('lane', 1, MAX_CHARGES[1])
    assert(X.IsNearLaneFront(bot) == true,
        'branch 2 needs the lane-front term true, or every silence below is '
        .. 'attributable to geometry instead of to the charge threshold')
    assert(X.ConsiderW() == BOT_ACTION_DESIRE_HIGH,
        'a Bone Guard at rank 1 holding its full 2 charges at the lane front must '
        .. 'release -- otherwise this frame proves nothing about thresholds')
end

tests['[GH #17] duel frame: the release fires there, and NOT via branch 2'] = function()
    local X, bot, enemy = make_frame('duel', 1, MAX_CHARGES[1])
    assert(X.IsNearLaneFront(bot) == false,
        'the duel frame must be away from every lane front, or branch 2 can '
        .. 'answer for branch 1')
    assert(GetUnitToUnitDistance(bot, enemy) <= 650,
        'branch 1 needs the target inside 650u')
    assert(X.ConsiderW() == BOT_ACTION_DESIRE_HIGH,
        'one visible enemy at 300u with a full bank must open branch 1')
end

tests['[GH #17] the duel frame is silent at zero charges'] = function()
    -- Guards the other side: without this, "fires at a full bank" could be some
    -- unconditional path rather than the ratio test.
    assert(fires('duel', 1, 0) == false,
        'a zero bank must not release on either branch')
end

----------------------------------------------------------------------
-- 2. Branch 2, bank held fixed at 2: more Bone Guard points, less Bone Guard.

tests['[GH #17] branch 2: a fixed 2-charge bank releases at rank 1 only'] = function()
    local got = {}
    for lv = 1, 4 do
        got[lv] = fires('lane', lv, 2) and 'fire' or 'silent'
    end
    assert(table.concat(got, ',') == 'fire,silent,silent,silent',
        'same hero, same frame, same two banked charges, only the number of skill '
        .. 'points in Bone Guard moving: got ' .. table.concat(got, ',')
        .. ', recorded fire,silent,silent,silent. This IS condition (c) for '
        .. "'wkbuild' -- branch 2 is `nStack == maxStack`, so rank 1 asks for 2 "
        .. 'charges and rank 4 asks for 8. If this flipped, re-argue the gate.')
end

----------------------------------------------------------------------
-- 3. Branch 1 degrades the same way, one rank later (0.6 of the cap, not all).

tests['[GH #17] branch 1: a fixed 3-charge bank releases at ranks 1-2 only'] = function()
    local got = {}
    for lv = 1, 4 do
        got[lv] = fires('duel', lv, 3) and 'fire' or 'silent'
    end
    assert(table.concat(got, ',') == 'fire,fire,silent,silent',
        'branch 1 is `nStack / maxStack >= 0.6`, so a 3-charge bank clears 2 and '
        .. '4 max charges (1.5 and 0.75) and fails 6 and 8 (0.5 and 0.375): got '
        .. table.concat(got, ',') .. '. The two branches degrade at different '
        .. 'ranks, which is why they are swept separately.')
end

----------------------------------------------------------------------
-- 4. Read the thresholds OUT of the shipped function instead of asserting them.
--
-- For each ability rank, sweep the bank upward and record the smallest one that
-- releases. This is the mapping-vs-assertion distinction: a mutation that
-- re-points the ratio, the equality or max_skeleton_charges moves these numbers,
-- and a test that only asserted "rank 4 is silent at 2" would not see most of it.

local function min_bank_that_fires(where, boneLevel)
    for stacks = 0, 12 do
        if fires(where, boneLevel, stacks) then return stacks end
    end
    return nil
end

tests['[GH #17] the release threshold is non-decreasing in Bone Guard rank'] = function()
    for _, where in ipairs({ 'lane', 'duel' }) do
        local prev = -1
        for lv = 1, 4 do
            local need = min_bank_that_fires(where, lv)
            assert(need ~= nil,
                where .. ' branch never releases at Bone Guard rank ' .. lv
                .. ' for any bank up to 12 -- the sweep has to be able to reach '
                .. 'the threshold or the monotonicity claim is vacuous')
            assert(need >= prev,
                'on the ' .. where .. ' branch the required bank FELL from '
                .. prev .. ' to ' .. need .. ' at rank ' .. lv .. '. The whole '
                .. "of 'wkbuild' condition (c) is that it never falls: every "
                .. 'Bone Guard point makes the release harder to reach, not '
                .. 'easier. If this is now false, the gate has no (c).')
            prev = need
        end
    end
end

tests['[GH #17] the thresholds read out of the code are 2/4/6/8 and 2/3/4/5'] = function()
    local lane, duel = {}, {}
    for lv = 1, 4 do
        lane[lv] = min_bank_that_fires('lane', lv)
        duel[lv] = min_bank_that_fires('duel', lv)
    end
    assert(table.concat(lane, '/') == '2/4/6/8',
        'branch 2 thresholds read ' .. table.concat(lane, '/')
        .. ', recorded 2/4/6/8 (= max_skeleton_charges). A change here means '
        .. 'either the equality test or the charge table moved.')
    assert(table.concat(duel, '/') == '2/3/4/5',
        'branch 1 thresholds read ' .. table.concat(duel, '/')
        .. ', recorded 2/3/4/5 (= the smallest integer >= 0.6 * max charges: '
        .. '1.2 -> 2, 2.4 -> 3, 3.6 -> 4, 4.8 -> 5).')
end

----------------------------------------------------------------------
-- 5. Source ratchets: the numbers the argument above is written against.

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

tests['[GH #17] the release rule still has exactly two charge thresholds'] = function()
    local src = read_file(WK_SRC)
    assert(src:find('nStack / maxStack >= 0.6', 1, true),
        "branch 1's ratio test is gone from " .. WK_SRC .. '. Sections 3 and 4 '
        .. 'measure it; the recorded 2/3/4/5 is derived from that 0.6 and is '
        .. 'stale the moment it moves.')
    assert(src:find('nStack == maxStack', 1, true),
        "branch 2's equality test is gone from " .. WK_SRC)
    assert(src:find('max_skeleton_charges', 1, true),
        'the cap is no longer read from max_skeleton_charges -- the whole '
        .. 'argument is that the threshold tracks the cap')
end

tests['[GH #104] the Wraithfire dot is recorded as a PER-SECOND figure'] = function()
    -- The first re-anchor pass read blast_dot_damage (20/40/60/80) as the dot
    -- total. The feed's heading on the field is "DAMAGE PER SECOND" and
    -- blast_dot_duration is 2, so the dot is 40/80/120/160 and a full-value cast
    -- is 120/180/240/300. The ConsiderQ lever is written against those numbers.
    local src = read_file(WK_SRC)
    assert(src:find('DAMAGE PER SECOND', 1, true),
        'the per-second reading of blast_dot_damage is gone from ' .. WK_SRC
        .. '. It is the correction that makes the ConsiderQ lever a 1.23x '
        .. 'overclaim against a target that stands in the dot to the end, not a '
        .. 'pure 2.64x against the impact -- both numbers matter to whoever '
        .. 'narrows it.')
    assert(src:find('120/180/240/300', 1, true),
        'the impact-plus-whole-dot total is gone from ' .. WK_SRC
        .. ' -- that is the honest ceiling the 168/235/302/370 claim is '
        .. 'compared against')
end

-- Hero levels at which a build row spends a Bone Guard point (ability index 2).
-- Module scope because section 7 asks the same question of the same rows, and a
-- second copy of the parser is a second thing to keep in step.
local function bone_level_list(src, name)
    local row = src:match('local ' .. name .. ' = {%s*{([%d,]+)}')
    assert(row, name .. ' must still be a single build row in ' .. WK_SRC)
    local levels, lv = {}, 0
    for n in row:gmatch('%d+') do
        lv = lv + 1
        if n == '2' then levels[#levels + 1] = lv end
    end
    return levels
end

tests['[GH #17] wkbuild still delays Bone Guard rather than dropping it'] = function()
    -- The re-argued (c) is about WHEN the cap rises, so it is false the moment
    -- the rows stop being a permutation of the same four points.
    local src = read_file(WK_SRC)
    local function bone_levels(name)
        return table.concat(bone_level_list(src, name), '/')
    end
    assert(bone_levels('tAllAbilityBuildList') == '1/3/5/7',
        'the default row reaches the 8-charge cap at hero level '
        .. bone_levels('tAllAbilityBuildList')
        .. '; the (c) argument is written against 1/3/5/7')
    assert(bone_levels('tKillBuildList') == '1/9/10/12',
        'the wkbuild row now takes Bone Guard at '
        .. bone_levels('tKillBuildList') .. ', recorded 1/9/10/12. It is a '
        .. 'DELAY, not a drop -- if that changed, so did condition (c).')
end

----------------------------------------------------------------------
-- 6. What the t20 bypass does, now that it is reachable (2026-08-28, GH #235).
--
-- Sections 2-4 measure the thresholds with talent6 untrained.  That used to be
-- the only world -- the GH #84 census read level 20 on 0 of 210 turbo hero-slots
-- and the bypass was therefore dead weight.  It is not dead: the first frame
-- taken past the removed 10-minute batch cap has this hero at level 26 with Bone
-- Guard at rank 4 (iterations/pending/tpgap_159_fixture/, t=1382.2 of a
-- 24.9-minute naturally-ended game).
--
-- So the question the correction opens is not "does the threshold still hold"
-- but "for how long", and that is answerable off the shipped function.  Both
-- disjuncts are `<threshold> or talent6:IsTrained()`, so a trained talent6
-- should collapse every threshold section 4 read to zero.  Measured, not
-- asserted: sweep the same grid and read the required bank back out.

local function min_bank_that_fires_with_talent(where, boneLevel)
    for stacks = 0, 12 do
        if fires(where, boneLevel, stacks, true) then return stacks end
    end
    return nil
end

tests['[GH #17] a trained t20 talent zeroes every threshold section 4 read'] = function()
    for _, where in ipairs({ 'lane', 'duel' }) do
        for lv = 1, 4 do
            local untrained = min_bank_that_fires(where, lv)
            local trained = min_bank_that_fires_with_talent(where, lv)
            assert(trained == 0, string.format(
                'on the %s branch at Bone Guard rank %d the release still needs a '
                .. 'bank of %s with talent6 TRAINED (it needs %s untrained). Both '
                .. 'branch tests are written `<threshold> or talent6:IsTrained()`, '
                .. 'so a trained t20 row must release off an empty bank; if it does '
                .. 'not, the bypass is not the bypass this file and '
                .. "tests/test_wk_bone_guard_talent_bypass.lua both price, and "
                .. "'wkbuild' condition (c) has to be re-argued at every level, not "
                .. 'just below 20.', where, lv, tostring(trained), tostring(untrained)))
            assert(untrained ~= nil and untrained > 0, string.format(
                'the untrained arm of this comparison read a required bank of %s on '
                .. 'the %s branch at rank %d. It has to be positive, or the two arms '
                .. 'are the same measurement and this section proves nothing about '
                .. 'the bypass.', tostring(untrained), where, lv))
        end
    end
end

tests["[GH #17] condition (c) therefore has a LIFETIME, and it ends at level 20"] = function()
    -- Stated as the difference it makes rather than as a level: at rank 4 the
    -- untrained rule wants a full 8-charge bank on the lane branch, and the
    -- trained rule wants none.  That gap IS the frequency advantage the 'wkbuild'
    -- delay is bought with, and it is gone from the level the t20 row is taken.
    local untrained = min_bank_that_fires('lane', 4)
    local trained = min_bank_that_fires_with_talent('lane', 4)
    assert(untrained == 8 and trained == 0, string.format(
        'the rank-4 lane threshold reads %s untrained / %s trained, recorded 8 / 0. '
        .. 'The 8 is what makes early Bone Guard points cost frequency; the 0 is why '
        .. 'that cost stops being paid once the t20 row is trained. If either moved, '
        .. 'the expiry argument in WHERE THAT HOLDS moved with it.',
        tostring(untrained), tostring(trained)))
end

----------------------------------------------------------------------
-- 7. The gap the untrained stub now stands on, asserted instead of narrated.
--
-- Sections 2-4 are only about a world where talent6 cannot be trained.  With the
-- level ceiling retired that is no longer "all of turbo", so what keeps them
-- honest is that every cap transition they sweep is SPENT before the bypass can
-- exist.  That is a fact about the shipped build rows, so read it off them.

local TALENT_FIRST_LEVEL = 20   -- t20 row; FunLib/aba_skill.lua puts a talent at
                                -- every hero level i >= 10 with i % 5 == 0.

tests['[GH #17] every Bone Guard point is spent well below the t20 bypass'] = function()
    local src = read_file(WK_SRC)
    for _, name in ipairs({ 'tAllAbilityBuildList', 'tKillBuildList' }) do
        local levels = bone_level_list(src, name)
        assert(#levels == 4, string.format(
            '%s spends %d Bone Guard point(s), not 4 -- sections 2-4 sweep ranks '
            .. '1-4 and the domain argument is about all four of them',
            name, #levels))
        local last = levels[#levels]
        assert(last < TALENT_FIRST_LEVEL, string.format(
            '%s takes its last Bone Guard point at hero level %d, at or above the '
            .. 'level %d t20 row. The untrained stub in make_frame is justified by '
            .. 'this gap and by nothing else since GH #235 retired the level '
            .. 'ceiling: if a cap transition can happen after the bypass is '
            .. 'trainable, sections 2-4 are measuring a case the bot does not '
            .. 'always play, and this file owes a swept talent6 there too.',
            name, last, TALENT_FIRST_LEVEL))
    end
end

return tests
