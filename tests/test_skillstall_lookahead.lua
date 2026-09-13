-- [hero] `skillstall` (GH #799): the banked ability point, and the one branch it
-- can be spent from without touching a single thing shipped code does.
--
-- WHAT THE DEFECT IS
-- ------------------
-- bots/ability_item_usage_generic.lua consumes sAbilityLevelUpList strictly
-- head-first, and the terminal `else` -- the branch a head that cannot be
-- upgraded falls into -- removes nothing below hero level 26.  One stuck head
-- therefore freezes every entry behind it, and the point the hero just earned is
-- BANKED rather than spent.  GH #366 / tests/test_skill_point_stall_frame.lua
-- measured the end state on a real frame: ten heroes at hero level 17-22, each
-- holding exactly THIRTEEN build points and at most one talent, rank multiset
-- {4,4,3,2}, ten for ten across two teams and ten different hero scripts.
-- tests/test_focus_talent_reach_wall.lua then reproduced the same multiset off
-- the five focus heroes' own build rows with no dump in the room.
--
-- ⭐ THE NARROWING THIS FILE ADDS, and it is why the fix goes in the terminal
-- `else` and nowhere else
-- ----------------------------------------------------------------------------
-- #799 acceptance 1 asks WHICH of the three upgrade conditions the stuck head
-- fails -- `IsHidden()`, `GetHeroLevelRequiredToUpgrade()`, or
-- `CanAbilityBeUpgraded()` -- and both #366 and #799 record that it cannot be
-- settled offline, because the mock's GetTalentList answers eight nils.  That is
-- still true.  But the fork is not three-way, and the third leg can be closed
-- from SOURCE plus the measured wall, with no handle at all:
--
--   * the dispatcher's MIDDLE branch is `elseif not IsHidden() and botLevel >=
--     GetHeroLevelRequiredToUpgrade() then` -- it levels the head and REMOVES
--     it;
--   * so a head that failed ONLY `CanAbilityBeUpgraded()` would take that branch,
--     the head would advance, and there would be no wall;
--   * the wall is measured.  Therefore that branch is not the one taken.
--     Therefore `not IsHidden() and botLevel >= required` is FALSE, i.e.
--     `IsHidden()` is true or the level requirement is unmet.
--
-- ⚠️ WHAT THIS DOES NOT SETTLE, and do not quote it as if it did: which of the
-- two SURVIVORS it is.  #799 acceptance 1 still owes that, and it still cannot
-- be paid offline.  What the narrowing buys is narrower and is the thing the
-- lever needed: BOTH survivors land in the terminal `else`, and
-- `CanAbilityBeUpgraded()` alone cannot.  So the terminal `else` is the branch,
-- whichever survivor it turns out to be -- section 1 asserts that shape rather
-- than describing it.
--
-- WHY THE FIX IS SHAPED THIS WAY
-- ------------------------------
--   * GATED, turbo-only, `skillstall`.  This file runs for all 127 heroes; #799
--     acceptance 2 requires the gate and it is the widest-domain change in the
--     repo so far.
--   * WIDENING BY CONSTRUCTION.  It acts only inside the branch where shipped
--     code levels nothing, so the armed leg can only ADD a level-up -- it can
--     never remove or reorder one the shipped leg would have taken.  Section 3
--     asserts that from source; section 5 asserts the helper half of it.
--   * THE HEAD IS LEFT IN PLACE.  If the head is blocked only because its talent
--     tier is not reached yet, it is still taken when the tier arrives.  The
--     entry actually spent is removed, so it is never offered twice.
--
-- THE VALUE ARGUMENT (validation philosophy condition (c)), stated in points and
-- not in ult ranks: an ability point that is never spent buys nothing, and this
-- branch is reached only on a frame that already holds one (`GetAbilityPoints()
-- > 0` gates the whole body).  In turbo the ladder is climbed roughly twice as
-- fast, so the wall is hit earlier in real time and more of the game is played
-- behind it.  There is no in-game reason to prefer a banked point to a spent
-- one; the ordering cost is the only thing being traded, and the ordering being
-- traded away is a build row's own tail, not an arbitrary pick.
--
-- ⛔ NOT CLAIMED HERE: any in-game reading.  Nothing in this file says how often
-- the branch is entered, and the corpus cannot say -- the fixture corpus carries
-- no live talent handles (#366's LIMIT, GH #772's family).  Condition (a) is a
-- wave's job; the queue request is the deliverable, not a number invented here.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local skillmap = require('skill_level_map')

local DISPATCH_SRC = 'bots/ability_item_usage_generic.lua'
local SKILL_SRC = 'bots/FunLib/aba_skill.lua'
local CAND_ID = 'skillstall'

local tests = {}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Comments AND string literals stripped before any source claim is counted.
--- The string half is not decoration: the subjects here sit next to `print`
--- calls whose text quotes the very words being counted (GH #136, and the
--- first run of skillmap.terminal_else_body, which stopped on a `for` it had
--- read out of a warning string).
local function strip_prose(sSrc)
    return (sSrc:gsub('%-%-%[%[.-%]%]', '')
                :gsub('%-%-[^\n]*', '')
                :gsub('"[^"\n]*"', '""')
                :gsub("'[^'\n]*'", "''"))
end

----------------------------------------------------------------------
-- The helper under test, loaded the way the game loads it.
----------------------------------------------------------------------

api.install()
local Skill = dofile('bots/FunLib/aba_skill.lua')

--- A hero whose ability handles are exactly the ones this test names, so every
--- answer below is one this file wrote down rather than a mock default.  An
--- unnamed ability answers nil, which is the `GetAbilityByName` contract the
--- helper guards against.
local function hero_with(tSpecs)
    local tHandles = {}
    for sName, tSpec in pairs(tSpecs) do
        local tFull = {
            IsHidden = false,
            GetHeroLevelRequiredToUpgrade = 1,
            CanAbilityBeUpgraded = true,
            GetLevel = 0,
            GetMaxLevel = 4,
        }
        for k, v in pairs(tSpec) do tFull[k] = v end
        tHandles[sName] = api.MakeAbility(sName, tFull)
    end
    return api.MakeHero('npc_dota_hero_axe', {
        GetAbilityByName = function(_, sName) return tHandles[sName] end,
    }), tHandles
end

--- The shape the defect actually produces: a head that cannot be upgraded, and
--- live entries behind it.  `blocked` picks which condition the head fails, so
--- section 4 can drive BOTH survivors of the narrowing rather than one.
local function stalled_queue(tHeadSpec)
    local hBot = hero_with({
        head = tHeadSpec,
        second = { GetHeroLevelRequiredToUpgrade = 20 },  -- tier not reached
        third = {},                                      -- the spendable one
        fourth = {},
    })
    return hBot, { 'head', 'second', 'third', 'fourth' }
end

-- ---------------------------------------------------------------------------
-- 1. SOURCE: the narrowing.  The middle branch pops the head, so
--    `CanAbilityBeUpgraded()` alone cannot produce the measured wall.
--
-- This is the assertion the whole placement rests on.  If the middle branch ever
-- stops removing the head, the third leg of #799's fork reopens and the lever
-- may be sitting in the wrong branch -- so it is asserted, not described.
-- ---------------------------------------------------------------------------

tests['1. the middle branch levels AND pops the head'] = function()
    local sSrc = strip_prose(read_file(DISPATCH_SRC))

    local sMiddle = sSrc:match(
        'elseif%s+not%s+abilityToLevelup:IsHidden%(%)%s+and%s+botLevel%s*>=%s*'
        .. 'abilityToLevelup:GetHeroLevelRequiredToUpgrade%(%)%s+then(.-)else')
    assert(sMiddle ~= nil,
        DISPATCH_SRC .. ' no longer carries the `elseif not IsHidden() and '
        .. 'botLevel >= GetHeroLevelRequiredToUpgrade()` branch.  The narrowing '
        .. 'in this file\'s header is built on that branch existing and popping '
        .. 'the head; re-derive it before trusting section 2 onwards.')

    assert(sMiddle:find('ActionImmediate_LevelAbility') ~= nil,
        'the middle branch no longer levels the head.')
    assert(sMiddle:find('table%.remove%s*%(%s*sAbilityLevelUpList%s*,%s*1%s*%)') ~= nil,
        'the middle branch no longer REMOVES the head.  That reopens the third '
        .. 'leg of GH #799\'s fork: a head failing only CanAbilityBeUpgraded() '
        .. 'could then wall too, and the terminal else would no longer be the '
        .. 'only branch a stuck head lands in.')

    -- And the condition it is complementary to: the terminal else is reached
    -- exactly when `not IsHidden() and botLevel >= required` is false.
    assert(sSrc:find('abilityToLevelup:CanAbilityBeUpgraded%(%)') ~= nil,
        'CanAbilityBeUpgraded is no longer read in the dispatcher; the fork this '
        .. 'file narrows is not the fork the dispatcher has.')
end

-- ---------------------------------------------------------------------------
-- 2. The gate: one resolution site, turbo-only, and the call site names it.
-- ---------------------------------------------------------------------------

tests['2. skillstall is gated turbo-only at exactly one site'] = function()
    local sSrc = strip_prose(read_file(DISPATCH_SRC))

    local nIds = select(2, sSrc:gsub("IsSoakCandidate%s*%(%s*''%s*%)", ''))
    -- The id itself is inside a string literal, which strip_prose blanks, so it
    -- is counted on the RAW source -- and counted, because "the gate exists"
    -- and "the gate exists once" are different claims.
    local sRaw = read_file(DISPATCH_SRC)
    local nNamed = select(2, sRaw:gsub("IsSoakCandidate%s*%(%s*'" .. CAND_ID .. "'%s*%)", ''))
    assert(nNamed == 1,
        'the id `' .. CAND_ID .. '` is named in ' .. nNamed .. ' gate calls in '
        .. DISPATCH_SRC .. ', not exactly one.  A second resolution site is a '
        .. 'call site that can silently miss the gate.')
    assert(nIds >= 1, 'no soak gate survives in ' .. DISPATCH_SRC)

    local sResolver = sRaw:match('function X%.IsSkillStallSkipOn%(%)(.-)\nend')
    assert(sResolver ~= nil,
        'X.IsSkillStallSkipOn is gone.  It is the single gate-resolution site; '
        .. 'inlining the gate at the call site is the shape this repo does not '
        .. 'use, see ClosestDustCarrier in the same file.')
    assert(sResolver:find('J%.IsModeTurbo%(%)') ~= nil,
        'the `' .. CAND_ID .. '` gate lost its turbo conjunct.  This file runs '
        .. 'for all 127 heroes; the turbo term is load-bearing, not decoration.')
    assert(sResolver:find("J%.IsSoakCandidate%s*%(%s*'" .. CAND_ID .. "'%s*%)") ~= nil,
        'the `' .. CAND_ID .. '` gate no longer names its own id.')
end

-- ---------------------------------------------------------------------------
-- 3. SOURCE: unarmed, the terminal else is byte for byte the shipped branch.
--
-- The claim is positional, not textual: every added statement sits INSIDE the
-- gated `if`, and the shipped guarded head pop still sits outside it and after
-- it.  A version that levelled first and asked the gate afterwards would pass a
-- "the gate is present" test and be a different program.
-- ---------------------------------------------------------------------------

tests['3. the armed leg is wholly inside the gate, and the shipped pop is not'] = function()
    local sBlock = skillmap.terminal_else_body(read_file(DISPATCH_SRC))

    local sGated = sBlock:match('if%s+X%.IsSkillStallSkipOn%(%)%s+then(.-)\n%s*end')
    assert(sGated ~= nil,
        'the terminal else no longer opens a `if X.IsSkillStallSkipOn() then` '
        .. 'block.  If the lever was removed, delete this file; if it was '
        .. 'un-gated, that is an UNGATED behaviour change in a file all 127 '
        .. 'heroes run -- GH #799 acceptance 2 forbids it.')

    assert(sGated:find('FindUpgradableBehindHead') ~= nil,
        'the look-ahead call left the gated block.')
    assert(sGated:find('ActionImmediate_LevelAbility') ~= nil,
        'the armed level-up left the gated block -- unarmed games would take it.')
    assert(sGated:find('table%.remove') ~= nil,
        'the armed removal left the gated block.')

    -- Nothing the armed leg does may touch the head.
    assert(sGated:find('table%.remove%s*%(%s*sAbilityLevelUpList%s*,%s*1%s*%)') == nil,
        'the armed leg removes queue index 1.  The head must stay parked: a head '
        .. 'blocked only by an unreached talent tier is still supposed to be '
        .. 'taken when the tier arrives.')

    local tArgs = skillmap.queue_removals(sBlock)
    local nHead, nOther = 0, 0
    for _, sArg in ipairs(tArgs) do
        if sArg == '1' then nHead = nHead + 1 else nOther = nOther + 1 end
    end
    assert(nHead == 1 and nOther == 1,
        'the terminal else now performs ' .. nHead .. ' head removals and '
        .. nOther .. ' non-head removals, not one of each.  (Seen: '
        .. table.concat(tArgs, ', ') .. ')')

    local nGateAt = sBlock:find('X%.IsSkillStallSkipOn')
    local nShippedPop = sBlock:find('if%s+botLevel%s*>%s*25%s+then')
    assert(nGateAt ~= nil and nShippedPop ~= nil and nGateAt < nShippedPop,
        'the gated block no longer sits ahead of the shipped `botLevel > 25` '
        .. 'guard; the shipped pop must remain the last thing this branch does.')
end

-- ---------------------------------------------------------------------------
-- 4. The helper, DRIVEN, on both survivors of the narrowing.
--
-- Two head shapes, because section 1 closed the fork to two and not to one:
-- a hidden head, and a head whose tier is not reached.  Both must produce the
-- same answer, because the helper is not supposed to care which it is.
-- ---------------------------------------------------------------------------

tests['4. a stalled head still yields the first spendable entry behind it'] = function()
    for sWhy, tHead in pairs({
        ['hidden head'] = { IsHidden = true },
        ['tier not reached'] = { GetHeroLevelRequiredToUpgrade = 25 },
    }) do
        local hBot, tQueue = stalled_queue(tHead)
        local nIdx, hAbility = Skill.FindUpgradableBehindHead(hBot, tQueue, 17)
        assert(nIdx == 3, sWhy .. ': expected queue index 3 (the first entry '
            .. 'behind the head that passes all four conditions; index 2 is held '
            .. 'by an unreached tier), got ' .. tostring(nIdx))
        assert(hAbility ~= nil and hAbility:GetName() == 'third',
            sWhy .. ': the handle returned is not the one at the index returned.')
    end
end

tests['4b. index 1 is never returned, even when the head is upgradable'] = function()
    -- The caller only reaches the helper in a branch where the head has already
    -- failed, so a helper that could answer 1 would re-offer a head the
    -- dispatcher just refused -- and in the hidden-head case that is an infinite
    -- re-offer, once per frame.
    local hBot = hero_with({ head = {}, second = {} })
    local nIdx = Skill.FindUpgradableBehindHead(hBot, { 'head', 'second' }, 17)
    assert(nIdx == 2,
        'expected index 2; the helper answered ' .. tostring(nIdx) .. '.  Index 1 '
        .. 'is the head and is the caller\'s business.')
end

tests['4c. nil when nothing behind the head can be upgraded'] = function()
    local hBot = hero_with({
        head = { IsHidden = true },
        second = { GetHeroLevelRequiredToUpgrade = 25 },
        third = { CanAbilityBeUpgraded = false },
        fourth = { GetLevel = 4, GetMaxLevel = 4 },
        fifth = { IsHidden = true },
    })
    local nIdx = Skill.FindUpgradableBehindHead(
        hBot, { 'head', 'second', 'third', 'fourth', 'fifth' }, 17)
    assert(nIdx == nil,
        'expected nil -- every entry behind the head fails one condition -- got '
        .. tostring(nIdx) .. '.  A false positive here spends a point on an '
        .. 'ability the engine will refuse.')
end

tests['4d. each of the four conditions is load-bearing'] = function()
    -- One condition broken at a time on the ONLY candidate behind the head.  If
    -- any of these still answers 2, that condition is not being read and the
    -- helper is not the dispatcher's own admission test any more.
    for sCond, tSpec in pairs({
        ['IsHidden'] = { IsHidden = true },
        ['GetHeroLevelRequiredToUpgrade'] = { GetHeroLevelRequiredToUpgrade = 25 },
        ['CanAbilityBeUpgraded'] = { CanAbilityBeUpgraded = false },
        ['GetLevel < GetMaxLevel'] = { GetLevel = 4, GetMaxLevel = 4 },
    }) do
        local hBot = hero_with({ head = { IsHidden = true }, second = tSpec })
        local nIdx = Skill.FindUpgradableBehindHead(hBot, { 'head', 'second' }, 17)
        assert(nIdx == nil,
            sCond .. ' is not being read: the helper returned ' .. tostring(nIdx)
            .. ' for a candidate that fails exactly that condition.')
    end

    -- Control: the same candidate with nothing broken IS returned, so the four
    -- assertions above are about the conditions and not about the fixture.
    local hBot = hero_with({ head = { IsHidden = true }, second = {} })
    assert(Skill.FindUpgradableBehindHead(hBot, { 'head', 'second' }, 17) == 2,
        'the unbroken control candidate was refused; section 4d proves nothing '
        .. 'as it stands.')
end

tests['4e. a nil or non-string queue entry is stepped over, not crashed on'] = function()
    -- GH #286's hole shape reaches this helper too: a build entry naming an
    -- sAbilityList index that was never written resolves to nil.
    local hBot = hero_with({ head = { IsHidden = true }, real = {} })
    local tQueue = { 'head', nil, 'real' }
    local nIdx = Skill.FindUpgradableBehindHead(hBot, tQueue, 17)
    assert(nIdx == nil or nIdx == 3,
        'a queue with a nil hole answered ' .. tostring(nIdx)
        .. '; expected either the real entry at 3 or nil (Lua 5.1 leaves `#` on '
        .. 'a holed table unspecified, so BOTH are correct -- what must not '
        .. 'happen is an error or an index the queue does not hold).')

    -- An unknown name -- GetAbilityByName answers nil -- must not be levelled.
    local hBot2 = hero_with({ head = { IsHidden = true } })
    assert(Skill.FindUpgradableBehindHead(hBot2, { 'head', 'not_on_this_hero' }, 17) == nil,
        'an ability name this hero does not carry was offered for levelling.')
end

-- ---------------------------------------------------------------------------
-- 5. The helper is PURE and gate-free, and that is a requirement, not a style.
--
-- bots/FunLib/jmz_func.lua:33 requires aba_skill.lua, so a `require` back the
-- other way is a cycle -- which is why the gate cannot live in the helper and
-- why section 2's single-site claim is about the dispatcher.
-- ---------------------------------------------------------------------------

tests['5. the helper carries no gate and no J.* dependency'] = function()
    local sRaw = read_file(SKILL_SRC)
    local sFn = sRaw:match('function X%.FindUpgradableBehindHead.-\nend\n')
    assert(sFn ~= nil,
        SKILL_SRC .. ' no longer defines X.FindUpgradableBehindHead.')

    local sBody = strip_prose(sFn)
    assert(sBody:find('IsSoakCandidate') == nil and sBody:find('IsModeTurbo') == nil,
        'the helper now resolves a gate itself.  It cannot: aba_skill.lua is '
        .. 'required BY jmz_func.lua, so reaching J from here is a require cycle. '
        .. 'The gate belongs at the call site.')
    assert(sBody:find('%f[%w]J%.') == nil,
        'the helper now reaches into J.*; see above -- that is a require cycle.')

    -- ⚠️ On the STRIPPED file, and per require statement.  The first draft ran
    -- `sRaw:find('require.-jmz_func')`, whose `.-` crosses newlines: it matched
    -- from the module's own `require` of utils on line 1 all the way down to the
    -- word `jmz_func` inside THIS lever's header comment, and reported a require
    -- cycle that does not exist.  Same family as GH #136, written into a fresh
    -- assertion whose subject is prose-heavy by construction.
    local sStripped = strip_prose(sRaw)
    for sArg in sStripped:gmatch('require%s*%(([^\n]-)%)') do
        assert(sArg:find('jmz_func') == nil,
            SKILL_SRC .. ' now requires jmz_func.lua.  jmz_func.lua:33 requires '
            .. 'THIS file; that is a cycle.')
    end
end

return tests
