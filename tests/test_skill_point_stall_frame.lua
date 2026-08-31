-- [ratchet] [hero] GH #366's step-2 fork, settled: the ability-point gap is
-- (a) BOT-SIDE, and it is one shared head-of-line block in
-- bots/ability_item_usage_generic.lua -- not ten build rows and not a stale dump.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
-- The fix is a behaviour change in a file every one of the 127 heroes runs, so
-- it is its own gated work unit; this file is the diagnosis it has to be built on.
--
-- Tagged [ratchet] because sections 2-4 are REGISTERED EXCEPTIONS: they assert
-- that the defect is still there.  The day somebody fixes the stall they go red,
-- which is the notification -- delete them then, do not loosen them.
--
-- ===========================================================================
-- WHAT #366 ASKED
-- ===========================================================================
-- GH #366 measured, on the staged frame, that nine of ten heroes at level >= 18
-- carry a rank-2 ultimate, and asked for the fork to be判定 before anything in
-- bots/ moves:
--     (a) the bot really never spent the points, or
--     (b) the dump's `abilities[].level` is a stale late-game read.
-- It also asked for a criterion that SEPARATES the two, and warned (its 量具
-- section) that a hand-written facet-name table is not a classifier: the first
-- version of that reading called 42% of the archive's hero units "impossible"
-- while still giving the right answer for Axe.
--
-- ===========================================================================
-- THE ANSWER: (a), AND THE STALL POINT IS THE SAME INDEX FOR ALL TEN
-- ===========================================================================
-- The instrument here needs no facet table at all.  Two readings do the work,
-- and both are open-set-safe:
--
--   * TALENT COUNT.  `special_bonus_` is the engine's own name prefix and the
--     dumper's own filter key (dumper/main.go isRealAbility).  Counting entries
--     with that prefix classifies nothing.
--     Ten heroes at levels 17-22.  SIX carry exactly one talent, FOUR carry
--     none, and NOBODY carries two.  Talent tiers sit at 10/15/20/25, so every
--     hero on this frame is past at least the 10 and 15 tiers -- a hero that had
--     spent its points would hold two.  Ten for ten, two teams, ten different
--     hero scripts.
--
--   * THE RANK MULTISET.  Take each unit's non-talent entries, sort by rank,
--     keep the top four (a standard hero has three basics and an ultimate).
--     All ten heroes hold {4,4,3,2} -- SUM 13 -- and every remaining non-talent
--     entry is at rank 1, i.e. an innate/facet grant.  Ten different build rows
--     do not agree on a rank multiset by coincidence; they agree because they
--     were all cut off after the same number of build entries.
--
-- 13 build points + at most one talent = FOURTEEN skill-list entries consumed,
-- by every hero, whatever its level.  Section 5 reads the shipped
-- J.Skill.GetSkillList and finds that the 15th entry of a 15-ability row is the
-- t15 TALENT; section 6 reads the shipped dispatcher and finds that an entry it
-- cannot upgrade is never removed unless botLevel > 25.  So entry 15 is a wall,
-- and everything behind it -- the last two ability points and the t15/t20/t25
-- talents -- is unreachable for the rest of any game that ends below level 26.
--
-- That also RETIRES #366's own control group.  #366 read Crystal Maiden (level
-- 17, ult rank 2) as the frame-internal control that "this 2 is correct".  It is
-- correct as an ULT RANK and it is not correct as a SPEND: she holds 13 build
-- points and one talent at level 17, where the ladder had already offered her
-- the t15 tier.  The control survives the instrument #366 used and dissolves
-- under this one, which is the reason to state the finding in points rather than
-- in ult ranks.
--
-- ===========================================================================
-- WHY (b) HAS NO MECHANISM
-- ===========================================================================
-- Section 7 reads the dumper: `resolveAbilities` walks m_vecAbilities and reads
-- `m_iLevel` off the live ability entity, inside the per-sample snapshot, with no
-- cache and no first-seen memo.  And the frame itself carries ranks 4 and 3 and
-- a talent at rank 1, so the field is not clamped or truncated at this hour of
-- the game.  A "stale late-game read" would need a mechanism that is not there.
--
-- ===========================================================================
-- WHAT THIS FILE DOES NOT ESTABLISH -- READ BEFORE QUOTING IT
-- ===========================================================================
-- (1) WHICH of the dispatcher's three upgrade conditions the t15 entry fails
--     (`IsHidden()` / `GetHeroLevelRequiredToUpgrade()` / `CanAbilityBeUpgraded()`)
--     is NOT settled here.  It cannot be: the mock's GetTalentList answers eight
--     nils (section 5 measures that rather than assuming it), so no offline world
--     can put a real talent handle at the head of the list.  The block itself is
--     proven from source and does not depend on which condition fails.
-- (2) One correlation is recorded in section 4 and is NOT a mechanism: all six
--     talents that WERE learned are generic (`special_bonus_` with no `unique`),
--     and zero hero-unique talents appear anywhere on the frame.  Axe is the one
--     hero here whose own ladder comment says his t10 pick is hero-unique, and he
--     is one of the four holding no talent.  n = 1 on that pairing.  It is a lead
--     for whoever takes the fix, not a finding.
-- (3) ONE FRAME, ONE GAME, ONE INSTANT -- #366's LIMIT carries over unchanged for
--     anything stated as a rate.  What is NOT rate-shaped, and is the reason this
--     file does not wait for a second game: sections 5-7 are read off SOURCE, and
--     a wall that source puts at entry 15 is there in every game whether or not a
--     second dump is ever taken.  The frame's job here is to show the wall being
--     hit, not to estimate how often.

package.path = 'tests/?.lua;' .. package.path

local FRAME = 'tests/frames/f_20260831_004433_cm_creepreach.lua'
local DISPATCH_SRC = 'bots/ability_item_usage_generic.lua'
local DUMPER_SRC = 'tools/batch_test/behavioral/dumper/main.go'

-- The ability-build row length every mainstream hero file ships (3 basics x 4 +
-- ult x 3).  Not a constant of the engine -- section 5 drives the real
-- GetSkillList with it and reports the positions it produces.
local ROW_LEN = 15
local TALENT_TIERS = { 10, 15, 20, 25 }

local tests = {}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Lua line comments stripped BEFORE any source claim is counted: this file's
--- own header quotes `botLevel > 25` and the talent prefix while explaining
--- them, and a parser that reads prose reports the prose (GH #136).
local function strip_comments(sSrc)
    return (sSrc:gsub('%-%-[^\n]*', ''))
end

local function is_talent(sName)
    return sName:sub(1, 14) == 'special_bonus_'
end

local FX = dofile(FRAME)

--- Per-unit reading, built with NO name table (GH #366's 量具 lesson): entries
--- are split by the engine's own `special_bonus_` prefix, and the build points
--- are the top four non-talent ranks.  `nRest` is every other non-talent entry,
--- reported so that "the rest are all rank 1" is asserted rather than assumed.
local function read_unit(u)
    local tRanks, nTalents, tTalentNames = {}, 0, {}
    for _, a in ipairs(u.abilities or {}) do
        if is_talent(a.name) then
            nTalents = nTalents + 1
            tTalentNames[#tTalentNames + 1] = a.name
        else
            tRanks[#tRanks + 1] = a.level or 0
        end
    end
    table.sort(tRanks, function(x, y) return x > y end)

    local tTop, nSum, nRestMax = {}, 0, 0
    for i, v in ipairs(tRanks) do
        if i <= 4 then
            tTop[#tTop + 1] = v
            nSum = nSum + v
        elseif v > nRestMax then
            nRestMax = v
        end
    end
    return {
        name = u.name,
        level = u.level or 0,
        top = tTop,
        sum = nSum,
        rest_max = nRestMax,
        n_rest = math.max(#tRanks - 4, 0),
        talents = nTalents,
        talent_names = tTalentNames,
    }
end

local HEROES = {}
for _, u in ipairs(FX.units or {}) do
    if type(u.name) == 'string' and u.name:find('npc_dota_hero_', 1, true) == 1 then
        HEROES[#HEROES + 1] = read_unit(u)
    end
end

-- ---------------------------------------------------------------------------
-- 1. The frame is where this file thinks it is, and is still STAGED.
--
-- The path is assembled rather than written out, for the reason
-- tests/test_axe_t15_in_domain.lua section 1 records: a literal
-- `tests/fixtures/...` here is read by test_corpus_existence_claims.lua as a
-- REFERENCE to a file that must exist, while this assertion's whole subject is
-- that it must be ABSENT (GH #367).

tests['[hero] skill stall: the staged frame is present and not admitted'] = function()
    assert(#HEROES == 10,
        'the frame now carries ' .. #HEROES .. ' hero units, not 10.  Every count '
        .. 'below is "N of ten heroes"; re-take them against the new population '
        .. 'rather than editing the numbers.')

    local sAdmitted = FRAME:gsub('tests/frames/', 'tests/' .. 'fixtures/')
    local fh = io.open(sAdmitted, 'r')
    if fh ~= nil then
        fh:close()
        error('the staged frame has been ADMITTED to tests/fixtures/.  That is a '
            .. 'legitimate decision (tests/frames/README.md), but the readings in '
            .. 'this file were taken on it as a STAGED frame; re-take them.')
    end
end

-- ---------------------------------------------------------------------------
-- 2. [REGISTERED EXCEPTION] Ten heroes, ten build rows, one rank multiset.

tests['[hero] skill stall: every hero holds exactly 13 build ability points'] = function()
    local nChecked, tOff = 0, {}
    for _, h in ipairs(HEROES) do
        nChecked = nChecked + 1
        if h.sum ~= 13 then
            tOff[#tOff + 1] = h.name .. ' Lv' .. h.level .. ' sum=' .. h.sum
        end
        assert(#h.top == 4,
            h.name .. ' dumps ' .. #h.top .. ' non-talent abilities, not the four '
            .. '(three basics + ultimate) this reading is built on.  A hero whose '
            .. 'top four are not its build abilities makes the sum meaningless.')
        assert(h.rest_max <= 1,
            h.name .. ' has a non-talent entry outside its top four at rank '
            .. h.rest_max .. '.  Entries beyond the top four are read here as '
            .. 'innate/facet GRANTS, which are rank 1 and cost no point; a rank-2 '
            .. 'one means the top-four rule no longer picks out the build.')
    end

    assert(nChecked == 10, 'expected ten hero units, walked ' .. nChecked)
    assert(#tOff == 0,
        'the 13-point cutoff has moved for: ' .. table.concat(tOff, ', ')
        .. '.  This assertion is a REGISTERED EXCEPTION -- it asserts the defect '
        .. 'is still present.  If the stall in ' .. DISPATCH_SRC .. ' has been '
        .. 'fixed, DELETE sections 2-4 of this file rather than loosening them, '
        .. 'and say so in the report.')
end

tests['[hero] skill stall: the multiset is {4,4,3,2} for all ten'] = function()
    local nExact = 0
    for _, h in ipairs(HEROES) do
        local s = table.concat(h.top, ',')
        if s == '4,4,3,2' then nExact = nExact + 1 end
    end
    -- Two-sided on purpose: a broken reader that returned an empty top-four for
    -- every unit would satisfy "nobody is above 13" and fail this line.
    assert(nExact == 10,
        'only ' .. nExact .. ' of ten heroes hold the {4,4,3,2} rank multiset.  '
        .. 'Ten independent build rows agreeing on one multiset is the fingerprint '
        .. 'of a shared cutoff; if it has broken up, the shared cause has changed '
        .. 'and the diagnosis in this file needs re-taking, not patching.')
end

-- ---------------------------------------------------------------------------
-- 3. [REGISTERED EXCEPTION] Nobody has two talents, at any level on this frame.

tests['[hero] skill stall: no hero on the frame holds a second talent'] = function()
    local nWith, nWithout, nMax, tPast15 = 0, 0, 0, 0
    for _, h in ipairs(HEROES) do
        if h.talents > nMax then nMax = h.talents end
        if h.talents >= 1 then nWith = nWith + 1 else nWithout = nWithout + 1 end
        if h.level >= TALENT_TIERS[2] then tPast15 = tPast15 + 1 end
    end

    assert(tPast15 == 10,
        'only ' .. tPast15 .. ' of ten heroes are at level >= ' .. TALENT_TIERS[2]
        .. '.  The claim "a hero that had spent its points would hold two talents" '
        .. 'rests on every hero here being past the t15 tier.')
    assert(nMax == 1,
        'a hero now holds ' .. nMax .. ' talents.  At 1 this is the defect; at 2 '
        .. 'or more the wall has moved and sections 2-4 must be re-taken.  At 0 '
        .. 'the talent surface has vanished from the dump and the reading is about '
        .. 'the dumper, not the bot.')
    assert(nWith == 6 and nWithout == 4,
        'the split is now ' .. nWith .. ' with a talent and ' .. nWithout
        .. ' without, not 6/4.  The split itself is the section-4 lead; re-read it.')
end

-- ---------------------------------------------------------------------------
-- 4. The lead, recorded as a lead: every learned talent is a GENERIC one.

tests['[hero] skill stall: zero hero-unique talents on the whole frame'] = function()
    local nGeneric, nUnique, tNames = 0, 0, {}
    for _, h in ipairs(HEROES) do
        for _, sName in ipairs(h.talent_names) do
            tNames[#tNames + 1] = sName
            if sName:find('unique', 1, true) then
                nUnique = nUnique + 1
            else
                nGeneric = nGeneric + 1
            end
        end
    end

    assert(nGeneric + nUnique == 6,
        'the frame now carries ' .. (nGeneric + nUnique) .. ' talent entries, not 6.')
    assert(nUnique == 0,
        nUnique .. ' hero-unique talent(s) now appear on the frame ('
        .. table.concat(tNames, ', ') .. ').  Section 4 of this file records the '
        .. 'generic-only observation as a LEAD for whoever takes the fix; the first '
        .. 'unique talent to appear kills that lead and should be reported, because '
        .. 'it is evidence about WHICH upgrade condition the wall entry fails.')
end

-- ---------------------------------------------------------------------------
-- 5. SOURCE + the shipped function: where the wall entry sits.
--
-- J.Skill.GetSkillList takes the talent list as a PARAMETER, so it can be driven
-- with eight declared names.  That is the only way to see the real talent
-- positions offline: the mock's own GetTalentList answers eight nils, which this
-- section measures rather than assumes.

tests['[hero] skill stall: the shipped list puts a talent at position 15'] = function()
    local api = require('mock.bot_api')
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_axe') })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    local bot = GetBot()

    -- MEASURED, not assumed: the mock cannot supply talent names.  This is why
    -- the "which condition fails" question is out of reach offline (header (1)).
    local sMockTalents = J.Skill.GetTalentList(bot)
    local nMockNamed = 0
    for i = 1, 8 do
        if sMockTalents[i] ~= nil then nMockNamed = nMockNamed + 1 end
    end
    assert(nMockNamed == 0,
        'the mock now supplies ' .. nMockNamed .. ' talent name(s).  That is an '
        .. 'improvement, not a failure -- but it means an offline test can finally '
        .. 'drive the dispatcher with a real talent at the head, which is exactly '
        .. 'the reading header note (1) says is out of reach.  Take it.')

    -- Declared inputs: a 15-entry ability row and eight distinct talent names.
    local tRow = {}
    for i = 1, ROW_LEN do tRow[i] = ((i - 1) % 4) + 1 end
    local sTalents = {}
    for i = 1, 8 do sTalents[i] = 'declared_talent_' .. i end
    local sAbilities = {}
    for i = 1, 6 do sAbilities[i] = 'declared_ability_' .. i end

    local nTalentBuild = J.Skill.GetTalentBuild({
        t10 = { 10, 0 }, t15 = { 0, 10 }, t20 = { 10, 0 }, t25 = { 0, 10 },
    })
    local sSkillList = J.Skill.GetSkillList(sAbilities, tRow, sTalents, nTalentBuild)

    local tTalentPos = {}
    for i = 1, 30 do
        local v = sSkillList[i]
        if type(v) == 'string' and v:find('declared_talent_', 1, true) == 1 then
            tTalentPos[#tTalentPos + 1] = i
        end
    end

    assert(tTalentPos[1] == 10 and tTalentPos[2] == 15,
        'the shipped GetSkillList now puts its first two talents at positions '
        .. tostring(tTalentPos[1]) .. '/' .. tostring(tTalentPos[2])
        .. ', not 10/15.  The whole "the wall is entry 15" reading is derived from '
        .. 'those positions; re-derive it.')
    assert(tTalentPos[3] == 18 and tTalentPos[4] == 19,
        'the third and fourth talents now sit at positions ' .. tostring(tTalentPos[3])
        .. '/' .. tostring(tTalentPos[4]) .. ', not 18/19.  Those two positions are '
        .. 'the SECOND half of this defect and are reached below the hero level the '
        .. 'tiers require (a t20 talent offered at the 18th point, a t25 at the '
        .. '19th), so they stall the same dispatcher even after entry 15 is fixed.')

    -- 13 build points + one talent = 14 entries consumed => the head is 15.
    local nConsumed = 13 + 1
    assert(sSkillList[nConsumed + 1] ~= nil
        and sSkillList[nConsumed + 1]:find('declared_talent_', 1, true) == 1,
        'entry ' .. (nConsumed + 1) .. ' of the shipped list is no longer a talent, '
        .. 'so "the head at the moment of the stall is the t15 talent" no longer '
        .. 'follows from the frame reading.')
end

-- ---------------------------------------------------------------------------
-- 6. SOURCE: the dispatcher never removes an entry it cannot upgrade.
--
-- This is the load-bearing half, and it is the same family as GH #286 -- whose
-- landed fix (CompactSkillList) covers the NIL head only.  A non-nil head that
-- fails all three upgrade branches falls to the terminal `else`, which removes
-- nothing below level 26.

tests['[hero] skill stall: the terminal else is a head-of-line block'] = function()
    local sSrc = strip_comments(read_file(DISPATCH_SRC))

    -- Anchored on the branch's own warning string, and closed on the `end` that
    -- ends the guard -- not on a bare substring.  A renamed variable inside the
    -- block still matches; a block that grows an unguarded removal does not.
    local sBlock = sSrc:match('Skipped to level up ability(.-)\n%s*end%s*\n%s*end')
    assert(sBlock ~= nil,
        DISPATCH_SRC .. ' no longer contains the "Skipped to level up ability" '
        .. 'terminal branch this assertion is anchored on.  If the branch was '
        .. 'renamed, re-anchor; if it was REMOVED, the head-of-line block may be '
        .. 'fixed and sections 2-4 should be re-taken.')

    local nRemovals = 0
    for _ in sBlock:gmatch('table%.remove%s*%(%s*sAbilityLevelUpList%s*,%s*1%s*%)') do
        nRemovals = nRemovals + 1
    end
    assert(nRemovals == 1,
        'the terminal branch now performs ' .. nRemovals .. ' head removals, not '
        .. 'one.  The count is the point: exactly one, and it is guarded.')

    local sGuard = sBlock:match('(if%s+botLevel%s*>%s*25%s+then)')
    assert(sGuard ~= nil,
        'the terminal branch removes the head without a `botLevel > 25` guard.  '
        .. 'That would MEAN THE STALL IS FIXED (or that the guard was renamed); '
        .. 'either way sections 2-4 are registered exceptions that must be re-taken.')

    -- Negative control: the removal must sit INSIDE the guard, not merely next to
    -- it.  A block with the guard first and the removal after the guard's `end`
    -- would satisfy both assertions above and be a different program.
    local nGuardAt = sBlock:find('if%s+botLevel%s*>%s*25%s+then')
    local nRemoveAt = sBlock:find('table%.remove%s*%(%s*sAbilityLevelUpList')
    assert(nGuardAt ~= nil and nRemoveAt ~= nil and nGuardAt < nRemoveAt,
        'the head removal in the terminal branch no longer sits after its '
        .. '`botLevel > 25` guard.  Order is the whole claim here: the guard is '
        .. 'what makes every entry behind an unupgradeable head unreachable in a '
        .. 'game that ends below level 26.')
end

-- ---------------------------------------------------------------------------
-- 7. SOURCE + data: hypothesis (b) has no mechanism.

tests['[hero] skill stall: the dumper reads m_iLevel live, per sample'] = function()
    local sGo = read_file(DUMPER_SRC)

    local sFn = sGo:match('resolveAbilities%s*:=%s*func%b()%s*%[%]abilitySnap%s*{(.-)\n\t}')
    assert(sFn ~= nil,
        DUMPER_SRC .. ' no longer defines resolveAbilities in the shape this '
        .. 'assertion parses.  Re-anchor before concluding anything about (b).')
    assert(sFn:find('GetInt32%("m_iLevel"%)') ~= nil,
        'resolveAbilities no longer reads m_iLevel off the ability entity.  Where '
        .. 'the rank comes from instead decides whether (b) is back on the table.')
    assert(sFn:find('map%[') == nil,
        'resolveAbilities now declares a map.  It had no cache and no first-seen '
        .. 'memo, which is exactly why a "stale late-game rank" had no mechanism; '
        .. 'a cache would put GH #366 hypothesis (b) back on the table.')
    assert(sGo:find('Abilities:%s*resolveAbilities%(') ~= nil,
        'the per-sample snapshot no longer calls resolveAbilities, so "read live '
        .. 'at every sample" no longer follows from this file.')

    -- The data half: the field is demonstrably not clamped at this hour.
    local nMaxRank, nRank1Talents = 0, 0
    for _, h in ipairs(HEROES) do
        for _, v in ipairs(h.top) do
            if v > nMaxRank then nMaxRank = v end
        end
        nRank1Talents = nRank1Talents + h.talents
    end
    assert(nMaxRank == 4,
        'the highest ability rank on the frame is now ' .. nMaxRank .. ', not 4.  '
        .. 'The anti-(b) data argument is that the field carries 4s and 3s at '
        .. 't=' .. tostring(FX.time) .. ', so it is not truncated late.')
    assert(nRank1Talents == 6,
        'the frame no longer carries six rank-1 talent entries, so the "talents '
        .. 'are dumped too" half of the anti-(b) argument has moved.')
end

return tests
