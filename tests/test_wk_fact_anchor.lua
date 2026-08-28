-- [hero, GH #17] Wraith King fact re-anchor: what hero_skeleton_king.lua believed
-- about its own hero, and what the game actually ships.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- WK is a focus hero and the bottom of the pool (GH #17: 15 last hits / 661 gpm /
-- 0.6 kills / 3.2 deaths).  Before proposing any behaviour lever on him, the facts
-- his file is written against were checked against the live Dota 2 datafeed
-- (https://www.dota2.com/datafeed/herodata?language=english&hero_id=42, read
-- 2026-08-22).  Three of them were stale, and one of the stale ones had already
-- been used as the recorded rationale of a gate ('wkbuild', GH #17):
--
--   * ability index 2 is skeleton_king_bone_guard (Bone Guard -- an ACTIVE,
--     no-target skeleton release, 42s cd), NOT "vampiric aura, lifesteal
--     sustain".  The lifesteal costs no skill point.  (The clause that used to
--     stand here -- "the feed flags it INNATE, so J.Skill.GetAbilityList drops
--     it" -- was withdrawn 2026-08-23: GetAbilityList reads no innate flag, and
--     the engine spells the ability skeleton_king_INNATE_vampiric_spirit, a name
--     the feed does not carry.  See tests/test_focus_innate_index_anchor.lua.)
--     Both of WK's build rows spend four points on Bone Guard;
--     'wkbuild' does not "keep points in sustain", it delays Bone Guard.
--   * abilityW was seeded from 'skeleton_king_spectral_blade', a name that is in
--     neither the game's ability set nor anywhere else in this repo.  It resolved
--     to nil on every load; the whole W path rode on the re-fetch in
--     X.SkillsComplement.
--   * the npc/talent block in the file was the 7.2x set (special_bonus_
--     attack_speed_20, ..._strength_15, ..._unique_wraith_king_7/6/1/8).  Today's
--     ladder is a different eight names in a different order.
--
-- WHAT IS PINNED HERE
--   1. source ratchets: the corrected facts, and the absence of the five dead
--      locals removed with them (they were declared, some assigned, none read);
--   2. the tier arithmetic, taken from THIS repo's own J.Skill.GetTalentBuild
--      rather than from convention: indices 5,6 are the t20 pair, 7,8 the t25
--      pair.  That is what makes `talent6:IsTrained()` a level-20 test;
--   3. the behaviour it costs: X.ConsiderW is driven on a frame where the
--      talent6 disjunct is the only thing that could fire the release.  The
--      shipped decision flips with IsTrained, which is the proof the disjunct has
--      teeth -- and the level census behind GH #84 (level >= 20 on 0 of 210
--      hero-slots, high-water 19) is what USED TO make those teeth unreachable in
--      turbo.  That clause is RETIRED (2026-08-28, GH #235): the zero was a
--      property of the 10-minute economy cap every batch game self-terminated at,
--      not of turbo.  Owner priority P3 (GH #108) lifted the cap, and the first
--      frame taken past it reads ten heroes at level 22-27 -- this one at 26.
--      The quote stays, because section 3 is unreadable without it; what it buys
--      is now the opposite of what it bought.  The teeth BITE;
--   4. a repo-wide census of the same shape: every live read of a t20/t25 talent
--      handle in bots/BotLib, split into ADDITIVE (pulls a number to add) and
--      STRUCTURAL (selects a branch or an action).  Section 4's own recorded read
--      was written under the same retired premise and was re-read on 2026-08-28;
--      the replacement discriminator is stated above the census.
--
-- HONEST BOUNDS
--   * No real frame here.  Section 3 is the shipped function under the mock API,
--     sections 1 and 4 are source text, section 2 is repo code driven directly.
--     Nothing below is a claim about how often any of this happens in a game --
--     that is exactly what the levers registered in the file still owe.
--   * The datafeed numbers quoted in comments are RECORDED, not re-derived: this
--     test cannot reach the network.  What is ratcheted is the repo-local half.
--   * The talent-ORDER claim (which name sits at which index) rests on the feed
--     listing talents in ability-slot order.  Section 2 does not depend on it:
--     GetTalentBuild's index->tier map is arithmetic on the index alone.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local BOTLIB = 'bots/BotLib/'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Lines with comments stripped out, so a ratchet on live code never trips on the
--- prose that documents the defect.  BLOCK comments have to go first: the npc dump
--- in hero_skeleton_king.lua is a `--[[ ]]` block whose lines do not start with
--- `--`, and the census below counted a sentence in it as a third talent read the
--- first time this file's own documentation mentioned `talent6`.
local function live_lines(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- 1. Source ratchets on the re-anchored facts.

tests['[GH #17] abilityW is seeded with an ability WK actually has'] = function()
    local src = read_file(WK_SRC)
    local seeded = src:match("local abilityW = bot:GetAbilityByName%('([%w_]+)'%)")
    assert(seeded, 'the abilityW seed line must still exist in ' .. WK_SRC)
    assert(seeded == 'skeleton_king_bone_guard',
        'abilityW is seeded from "' .. seeded .. '". WK\'s learnable set is '
        .. 'hellfire_blast / bone_guard / mortal_strike / reincarnation '
        .. '(vampiric_spirit is innate). A name outside that set resolves to nil '
        .. 'on load -- which is the GH #17 re-anchor finding verbatim.')
end

tests['[GH #17] the SkillsComplement re-fetch is still there'] = function()
    local src = read_file(WK_SRC)
    assert(src:find("if not abilityW or abilityW:IsHidden() then", 1, true),
        'the fallback re-fetch in X.SkillsComplement is what makes the seed line '
        .. 'a no-op either way. Removing it turns the seed into load-order risk, '
        .. 'so it may not go without a decision.')
end

tests['[GH #17] no live reference to the five removed dead locals'] = function()
    local dead = { 'bDebugMode', 'abilityE', 'talent5', 'castEDesire', 'nKeepMana' }
    for _, line in ipairs(live_lines(read_file(WK_SRC))) do
        for _, name in ipairs(dead) do
            assert(not line:find(name, 1, true),
                name .. ' is back in live code in ' .. WK_SRC .. '. All five were '
                .. 'removed as provably unread (nKeepMana was assigned and never '
                .. 'read -- the same dead reserve GH #73 cleared out of Lion). If '
                .. 'this one now has a reader, say so in the file: ' .. line)
        end
    end
end

tests['[GH #17] the stale 7.2x ability and talent names are gone'] = function()
    local src = read_file(WK_SRC)
    for _, stale in ipairs({
        'skeleton_king_vampiric_aura',
        'special_bonus_attack_speed_20',
        'special_bonus_strength_15',
    }) do
        -- These may only reappear as prose ABOUT the re-anchor, so the test
        -- allows them on comment lines and forbids them as data.
        for _, line in ipairs(live_lines(src)) do
            assert(not line:find(stale, 1, true),
                stale .. ' is back as live data in ' .. WK_SRC .. '. It is not in '
                .. 'the shipped ability/talent set -- re-read the datafeed before '
                .. 'trusting it: ' .. line)
        end
    end
end

tests['[GH #17] both build rows still spend four points on Bone Guard'] = function()
    -- The corrected rationale in the file rests on this arithmetic, so pin it.
    local src = read_file(WK_SRC)
    local function count_twos(name)
        local row = src:match('local ' .. name .. ' = {%s*{([%d,]+)}')
        assert(row, name .. ' must still be a single build row in ' .. WK_SRC)
        local levels = {}
        local lv = 0
        for n in row:gmatch('%d+') do
            lv = lv + 1
            if n == '2' then levels[#levels + 1] = lv end
        end
        return levels
    end
    local default_lv = count_twos('tAllAbilityBuildList')
    local kill_lv = count_twos('tKillBuildList')
    assert(#default_lv == 4 and #kill_lv == 4,
        'the "wkbuild delays Bone Guard, it does not trade it away" note in '
        .. WK_SRC .. ' assumes four points in each row; got '
        .. #default_lv .. ' and ' .. #kill_lv)
    assert(table.concat(default_lv, '/') == '1/3/5/7',
        'default row Bone Guard levels moved to ' .. table.concat(default_lv, '/')
        .. ' -- update the note in ' .. WK_SRC)
    assert(table.concat(kill_lv, '/') == '1/9/10/12',
        'wkbuild row Bone Guard levels moved to ' .. table.concat(kill_lv, '/')
        .. ' -- update the note in ' .. WK_SRC)
end

-- ---------------------------------------------------------------------------
-- 2. The tier arithmetic, from the repo's own code.
--
-- This is the load-bearing step: it is what turns "talent6" into "level 20", and
-- it does not depend on knowing which talent NAME sits at index 6.

tests['[GH #84] GetTalentBuild maps indices 5,6 to t20 and 7,8 to t25'] = function()
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_skeleton_king') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    -- Which sTalentList indices does a given tier row actually drive?  Flip that
    -- ONE row and see which returned picks move.  This reads the wiring out of
    -- the code instead of assuming "the third pick is the t20 one" -- the first
    -- draft assumed it, and a mutation that re-pointed a row at the wrong tier
    -- key walked straight through.
    local function baseline()
        return { t10 = { 10, 0 }, t15 = { 10, 0 }, t20 = { 10, 0 }, t25 = { 10, 0 } }
    end
    local base = J.Skill.GetTalentBuild(baseline())

    local function indices_driven_by(key)
        local cfg = baseline()
        cfg[key] = { 0, 10 }
        local flipped = J.Skill.GetTalentBuild(cfg)
        local seen, out = {}, {}
        for pick = 1, 8 do
            if flipped[pick] ~= base[pick] then
                for _, idx in ipairs({ base[pick], flipped[pick] }) do
                    if not seen[idx] then seen[idx] = true; out[#out + 1] = idx end
                end
            end
        end
        table.sort(out)
        return table.concat(out, ',')
    end

    assert(indices_driven_by('t20') == '5,6',
        'the t20 row drives sTalentList indices {' .. indices_driven_by('t20')
        .. '}, recorded {5,6}. That mapping is the whole reason '
        .. '`talent6:IsTrained()` is a level-20 test -- if it moved, every '
        .. '"unreachable in turbo" note in BotLib is stale, including the one in '
        .. WK_SRC)
    assert(indices_driven_by('t25') == '7,8',
        'the t25 row drives {' .. indices_driven_by('t25') .. '}, recorded {7,8}')
    assert(indices_driven_by('t10') == '1,2',
        'the t10 row drives {' .. indices_driven_by('t10') .. '}, recorded {1,2}')
    assert(indices_driven_by('t15') == '3,4',
        'the t15 row drives {' .. indices_driven_by('t15') .. '}, recorded {3,4}')
end

tests['[GH #17] WK still asks for the even/right talent at t20'] = function()
    local src = read_file(WK_SRC)
    local t20 = src:match("%['t20'%]%s*=%s*{%s*(%d+)%s*,")
    assert(t20 == '10',
        'WK\'s t20 row changed. The file records that it resolves to index 6 '
        .. '(the Bone Guard skeleton talent), which is exactly the handle '
        .. 'X.ConsiderW reads -- re-check that note before trusting it.')
end

-- ---------------------------------------------------------------------------
-- 3. What the unreachable disjunct costs: drive the shipped X.ConsiderW.

local BONE = 'skeleton_king_bone_guard'
local BONE_MOD = 'modifier_skeleton_king_bone_guard'

--- A WK at the lane front holding ZERO skeleton charges out of eight. Branch 1
--- of X.ConsiderW cannot fire (no proper target), and branch 2's stack test is
--- false, so `talent6:IsTrained()` is the only term left that could open it.
local function make_frame(talent6_trained, stacks)
    api.reset_modules()

    local bone = api.MakeAbility(BONE, {
        IsFullyCastable = true,
        GetManaCost = 100,
        GetSpecialValueInt = 8,   -- max_skeleton_charges at ability level 4
    })
    local reincarnation = api.MakeAbility('skeleton_king_reincarnation', {
        GetManaCost = 220,
        GetCooldownTimeRemaining = 0,
    })
    local talent = api.MakeAbility('mock_t20_talent',
        { IsTrained = talent6_trained })

    local bot = api.MakeHero('npc_dota_hero_skeleton_king', {
        GetLevel = 12,
        GetMana = 500,            -- 500 - 100 >= 220, so X.ShouldSaveMana is false
        GetMaxMana = 500,
        HasModifier = function(_, name) return name == BONE_MOD end,
        GetModifierByName = function(_, name) return name == BONE_MOD and 3 or -1 end,
        GetModifierStackCount = stacks or 0,
        GetAbilityByName = function(_, name)
            if name == BONE then return bone end
            if name == 'skeleton_king_reincarnation' then return reincarnation end
            -- sTalentList is empty under the mock, so hero_skeleton_king.lua's
            -- `bot:GetAbilityByName(sTalentList[6])` arrives here as nil. That
            -- nil IS the talent6 slot for the purposes of this frame.
            if name == nil then return talent end
            return api.MakeAbility(name)
        end,
    })
    api.install({ bot = bot })

    -- X.IsNearLaneFront walks the three lane fronts; put one under his feet.
    _G.GetLaneFrontLocation = function() return api.Vector(0, 0, 0) end
    _G.GetUnitToLocationDistance = function() return 100 end

    local X = dofile(WK_SRC)
    X.SkillsComplement()  -- sets the file-level nLV / nMP / nHP this path reads
    return X, bot
end

tests['[GH #17] ground truth: the frame holds 0 of 8 charges at the lane front'] = function()
    local X, bot = make_frame(false)
    assert(bot:GetModifierStackCount(3) == 0, 'the frame must hold zero charges')
    assert(bot:GetAbilityByName(BONE):GetSpecialValueInt('max_skeleton_charges') == 8,
        'and eight must be reachable, or "nStack == maxStack" is trivially false '
        .. 'for the wrong reason')
    assert(X.IsNearLaneFront(bot) == true,
        'branch 2 needs the lane-front term true, or this section proves nothing')
end

tests['[GH #17] talent6 untrained (the turbo reality): no release at 0/8'] = function()
    local X = make_frame(false)
    assert(X.ConsiderW() == 0,
        'with the t20 talent untrained, branch 2 is exactly "nStack == maxStack" '
        .. 'and 0 ~= 8, so the release must not fire')
end

tests['[GH #17] the same frame at 8/8 charges DOES release, talent untrained'] = function()
    -- The other half of the isolation: with talent6 dead, the ONLY term left in
    -- branch 2 is the stack test, so moving just the stack count has to flip the
    -- decision. Without this, "no release at 0/8" could be any of the four
    -- early-return guards instead of the branch under discussion.
    local X = make_frame(false, 8)
    assert(X.ConsiderW() == BOT_ACTION_DESIRE_HIGH,
        'at full charges the release must fire with no talent at all -- that is '
        .. 'what "in turbo the condition is exactly nStack == maxStack" means')
end

tests['[GH #17] talent6 trained: the same frame DOES release'] = function()
    local X = make_frame(true)
    assert(X.ConsiderW() == BOT_ACTION_DESIRE_HIGH,
        'the disjunct must have teeth -- otherwise the note it carries would be a '
        .. 'statement about nothing. It flips the shipped decision on this frame, '
        .. 'and it can only be true at hero level 20 (section 2), which the GH #84 '
        .. 'census put at 0 of 210 hero-slots. RETIRED 2026-08-28 (GH #235): that '
        .. 'zero was the 10-minute batch cap, and WK reaches level 26 in a '
        .. 'naturally-ended turbo game -- so this test no longer prices a '
        .. 'hypothetical. WK`s own t20 row takes [6] (section 4b), so the disjunct '
        .. 'this frame flips is LIVE from level 20 in shipped turbo games.')
end

-- ---------------------------------------------------------------------------
-- 4. The same shape across BotLib: who else reads a t20/t25 handle, and does it
--    change a branch or only add a number?

--- Every live (non-comment) line in bots/BotLib that mentions talent5..talent8,
--- excluding the `local talentN = ...` declarations themselves.
local function talent_read_sites()
    local sites = {}
    local pipe = assert(io.popen('ls ' .. BOTLIB .. '*.lua'))
    for path in pipe:lines() do
        local name = path:match('/hero_([%w_]+)%.lua$')
        for _, line in ipairs(name and live_lines(read_file(path)) or {}) do
            -- The trailing class is a hand-rolled word boundary: without it
            -- hero_huskar.lua's `talent6Range` accumulator counts as three reads
            -- of a talent HANDLE, which it is not.
            if (line .. ' '):find('talent[5-8][^%w_]')
                and not line:match('^%s*local talent[5-8]%s*=') then
                sites[#sites + 1] = {
                    hero = name,
                    line = line,
                    -- A read that pulls a number to add is inert when the talent
                    -- is unreachable: the bonus is simply not applied. A read
                    -- with no value fetch on the line is selecting something.
                    additive = line:find('GetSpecialValue') ~= nil,
                }
            end
        end
    end
    pipe:close()
    return sites
end

-- Recorded 2026-08-22. STRUCTURAL = the t20/t25 handle chooses a branch or an
-- action, so its unreachability removes behaviour rather than a bonus.
local STRUCTURAL_CENSUS = {
    chaos_knight = 1,      -- bIgnoreMagicImmune = talent6:IsTrained()
    legion_commander = 2,  -- picks UseAbilityOnLocation vs UseAbilityOnEntity
    lich = 2,              -- gates the repair-buildings and heal-ally branches
    -- 2026-08-25, hero group: 14 -> 1.  NOT a removal.  GH #166 routed all
    -- fifteen `talent8` call sites through one predicate, `X.IsHexAoe()`, so the
    -- structural read that used to be repeated at every site now happens once,
    -- at hero_lion.lua:1258.  The behaviour census is unchanged -- the same
    -- decisions still hang off the same t25 handle, they just read it in one
    -- place.  (This line was red on main from 22:30Z 08-24 until it was noticed
    -- here: the census is a drift alarm, and #166 was exactly the drift it is
    -- for.)
    lion = 1,              -- talent8 (t25), read once inside X.IsHexAoe()
    skeleton_king = 2,     -- the two X.ConsiderW release disjuncts
    warlock = 2,           -- one of them is `talent6:IsTrained() and false`
    zuus = 1,              -- picks UseAbilityOnLocation vs UseAbilityOnEntity
}
-- Read of the census, recorded with it 2026-08-22: three of the six non-WK heroes
-- (legion_commander, lion, zuus) use the handle to choose GROUND-cast over
-- UNIT-cast, and the unreachable half is the ground cast -- the else branch is
-- the correct default, so their unreachability costs nothing observable.  The
-- ones that remove behaviour are chaos_knight (magic-immune targets simply never
-- considered), lich (two whole branches never taken) and skeleton_king (the
-- release condition is strictly tighter than written).  This split is the reason
-- the census stores COUNTS and not a verdict: the shape does not decide it.
--
-- RE-READ 2026-08-28 (GH #235; this file's registry row in
-- tests/test_level_premise_registry.lua is cleared by this block).
--
-- Every sentence above turns on the word UNREACHABLE, and that word came from
-- GH #84's `level >= 20 on 0 of 210 hero-slots` -- a zero the 10-minute batch cap
-- manufactured, not a fact about turbo.  So the question the census was built to
-- answer ("what does unreachability cost?") is VOID, not merely wrong: there is
-- no unreachability left to price.  The counts survive; the read of them does not.
--
-- THE REPLACEMENT DISCRIMINATOR, and why it is a different question.  With levels
-- reachable, a structural read is dead only if the handle it binds is one this
-- hero's OWN BUILD never trains.  A hero takes ONE talent per tier, so exactly one
-- of {5,6} and one of {7,8} is ever trained, and which one is decided offline by
-- the file's own `tTalentTreeList` through J.Skill.GetTalentBuild (section 2).
-- That test never depended on levels, which is why it is what is left.
--
-- Applied to the focus heroes, it splits a bucket the old read had collapsed:
--
--   * zuus [7] and skeleton_king [6] are TRAINED by their own shipped builds.
--     Both were filed above as costing nothing -- zuus explicitly, as one of the
--     three "the else branch is the correct default" heroes.  They are live
--     branches in shipped turbo games from level 25 and 20 respectively.
--   * lion [8] is NOT trained: hero_lion.lua's t25 row takes [7], so `talent8` is
--     structurally untrained and X.IsHexAoe returns false at its first statement.
--     Lion sat in the SAME census bucket as zuus, and the two are now opposite --
--     for a reason (build selection) that the discarded reason (levels) had been
--     masking.  See tests/test_lion_hex_talent_slot.lua sections 2 and 6.
--
-- This is the accounting tests/test_focus_talent_anchor.lua section 4a defers to
-- this file by name ("a read of index 1-4 is a LIVE read and needs its own
-- accounting").  It is discharged for the focus heroes below and NOWHERE ELSE.
--
-- HONEST BOUNDS on the re-read
--   * FOCUS HEROES ONLY.  The trained-set arithmetic needs the hero's own
--     tTalentTreeList; chaos_knight, legion_commander, lich and warlock are not
--     focus heroes and are not priced here.  Their rows keep the 08-22 counts and
--     LOSE the 08-22 verdict: "unreachable, so harmless" is not available to them
--     any more either, and nobody has replaced it.
--   * TRAINED IS NOT CORRECTLY BOUND.  This says the handle can be trained, not
--     that it names the talent its branch is about.  For zuus that second question
--     runs through `sAbilityList[2]`, and GH #203 measured that sAbilityList
--     indices are NOT ability slots -- so what abilityW is on the frame where the
--     ground cast fires is open, and is deliberately not asserted here.
--   * Still no real frame.  Reachability is argued from GH #235's frame, which is
--     not in tests/fixtures/ (it is parked in iterations/pending/, GH #236).

tests['[GH #84] the t20/t25 STRUCTURAL read census has not drifted'] = function()
    local counted = {}
    for _, s in ipairs(talent_read_sites()) do
        if not s.additive then
            counted[s.hero] = (counted[s.hero] or 0) + 1
        end
    end
    for hero, n in pairs(STRUCTURAL_CENSUS) do
        assert(counted[hero] == n,
            'hero_' .. hero .. '.lua now has ' .. tostring(counted[hero])
            .. ' structural t20/t25 reads, recorded ' .. n .. '. These are the '
            .. 'sites where an unreachable talent removes BEHAVIOUR rather than '
            .. 'a bonus -- re-read them and update the census.')
    end
    for hero, n in pairs(counted) do
        assert(STRUCTURAL_CENSUS[hero],
            'hero_' .. hero .. '.lua grew ' .. n .. ' structural t20/t25 read(s) '
            .. 'and is not in the recorded census. This used to read "in turbo '
            .. 'that branch cannot fire (GH #84: level >= 20 on 0 of 210 '
            .. 'hero-slots)"; that zero was the 10-minute batch cap and is retired '
            .. '(GH #235, 2026-08-28). The branch CAN fire -- so say whether this '
            .. 'hero`s own tTalentTreeList trains the index it binds, and what the '
            .. 'branch does when it does, before shipping it.')
    end
end

-- ---------------------------------------------------------------------------
-- 4b. The replacement discriminator, run (2026-08-28, GH #235).
--
-- For each focus hero that owns a structural t20/t25 read: does that hero's own
-- shipped build ever train the index the read binds?  Driven through the real
-- J.Skill.GetTalentBuild on the real tTalentTreeList literal, because a
-- re-implementation of "{10,0} means the even one" is the exact mutation section
-- 2 was written to catch.

--- { t10 = {a,b}, ... } read out of a shipped hero file.
local function talent_rows(hero)
    local body = read_file(BOTLIB .. 'hero_' .. hero .. '.lua')
        :match('local tTalentTreeList = {(.-)\n}')
    assert(body, 'hero_' .. hero .. '.lua has no tTalentTreeList literal')
    local rows = {}
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        rows[tier] = { tonumber(a), tonumber(b) }
    end
    for _, tier in ipairs({ 't10', 't15', 't20', 't25' }) do
        assert(rows[tier], 'hero_' .. hero .. '.lua has no ' .. tier .. ' row')
    end
    return rows
end

-- hero -> { idx = the structural read's talent index, trained = does the build
-- take it, picks = the {t20, t25} indices its own rows resolve to, what = the
-- branch it selects }.  Recorded 2026-08-28.
--
-- `picks` is here because `trained` alone cannot see whose literal was read: all
-- three of these heroes take [7] at t25, so a talent_rows() that returned one
-- hero's rows for everybody answers all three questions correctly by accident
-- (measured, not feared).  Pinning the PAIR separates zuus ({5,7}) from the other
-- two.  It does not separate lion from skeleton_king -- their literals are equal
-- today -- and no assertion here could, which is why `idx` differing is what
-- carries that pair.
local FOCUS_STRUCTURAL = {
    { hero = 'zuus',          idx = 7, trained = true,  picks = { 5, 7 },
      what = 'ground-cast vs unit-cast of abilityW (hero_zuus.lua:~566)' },
    { hero = 'skeleton_king', idx = 6, trained = true,  picks = { 6, 7 },
      what = 'the two X.ConsiderW release disjuncts' },
    { hero = 'lion',          idx = 8, trained = false, picks = { 6, 7 },
      what = 'X.IsHexAoe (GH #166)' },
}

tests['[GH #235] each focus hero`s structural t20/t25 read, against its own build'] = function()
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_skeleton_king') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    -- The census, indexed by hero -> set of talent indices read STRUCTURALLY.
    -- Without this half the rows below would be arithmetic about handles nobody
    -- reads, which is how a census and a verdict drift apart in the first place.
    local read_idx = {}
    for _, s in ipairs(talent_read_sites()) do
        if not s.additive then
            read_idx[s.hero] = read_idx[s.hero] or {}
            for idx in s.line:gmatch('talent(%d)') do
                read_idx[s.hero][tonumber(idx)] = true
            end
        end
    end

    for _, row in ipairs(FOCUS_STRUCTURAL) do
        assert(read_idx[row.hero] and read_idx[row.hero][row.idx],
            'hero_' .. row.hero .. '.lua no longer reads talent' .. row.idx
            .. ' structurally (recorded: ' .. row.what .. '). The build arithmetic '
            .. 'below would then be pricing a handle nothing selects on -- re-read '
            .. 'the site and update this row.')

        -- A hero takes one talent per tier, so the trained set is exactly the
        -- four picks GetTalentBuild returns at [1..4]; [5..8] are the halves NOT
        -- taken.  X.GetSkillList only ever queues the first four.
        local picks = J.Skill.GetTalentBuild(talent_rows(row.hero))
        local trained = {}
        for i = 1, 4 do trained[picks[i]] = true end

        assert(picks[3] == row.picks[1] and picks[4] == row.picks[2],
            'hero_' .. row.hero .. '.lua`s t20/t25 rows now resolve to {' .. picks[3]
            .. ',' .. picks[4] .. '}, recorded {' .. row.picks[1] .. ','
            .. row.picks[2] .. '}. Either the file`s talent tree changed -- in which '
            .. 'case the verdict below changed with it -- or this test is reading '
            .. 'the wrong hero`s literal.')

        assert((trained[row.idx] == true) == row.trained,
            'hero_' .. row.hero .. '.lua binds talent' .. row.idx .. ' for ' .. row.what
            .. ', and its own t20/t25 rows now resolve to {' .. picks[3] .. ',' .. picks[4]
            .. '}, so that handle is ' .. (trained[row.idx] and 'TRAINED' or 'UNTRAINED')
            .. ' -- recorded ' .. (row.trained and 'TRAINED' or 'UNTRAINED') .. '. Since '
            .. 'GH #235 retired the level ceiling, build selection is the ONLY thing '
            .. 'left that can make a structural t20/t25 read dead, so this flip '
            .. 'changes whether the branch ships live. Re-read section 4 before '
            .. 'updating the row.')
    end

    -- Anti-vacuum with teeth: the whole point of the re-read is that these three
    -- do NOT agree, so a bug that made every hero read the same way (talent_rows
    -- returning one hero's literal, GetTalentBuild stubbed) has to land here.
    local seen_true, seen_false = false, false
    for _, row in ipairs(FOCUS_STRUCTURAL) do
        if row.trained then seen_true = true else seen_false = true end
    end
    assert(seen_true and seen_false,
        'FOCUS_STRUCTURAL no longer holds both a trained and an untrained row. The '
        .. 'finding IS the split -- zuus and lion sat in the same 08-22 census '
        .. 'bucket and their handles have opposite fates. A one-sided table makes '
        .. 'this test pass for a reason unrelated to what it says.')
end

tests['[GH #84] warlock still carries the doubly-dead `and false` read'] = function()
    local found = false
    for _, s in ipairs(talent_read_sites()) do
        if s.hero == 'warlock' and s.line:find('and false', 1, true) then
            found = true
        end
    end
    assert(found,
        'hero_warlock.lua:~532 read `if talent6:IsTrained() and false` -- dead '
        .. 'twice over (a level-25 handle AND a literal false). It is recorded '
        .. 'here so that whoever removes the `and false` learns from this line '
        .. 'that the branch is still unreachable in turbo without it.')
end

return tests
