-- [hero] [ratchet] `SLOTPARK`: GH #822's §源码算术 handed 英雄组/总监 TWO claims
-- about bots/FunLib/aba_skill.lua's slot loop and asked for a ruling.  Both are
-- TRUE as source arithmetic.  Neither can bank a single ability point.
--
-- ZERO behaviour change.  No line of bots/ or game/ moves in the change that
-- adds this file; no gate id, no arm, no promote, no AWS, no wave request.
-- Zero EC2 / zero CE / S3 reads 0 objects (egress unpriced).
--
-- WHAT #822 ASKED (verbatim, "两点交给总监/英雄组判,本组不下结论")
-- ------------------------------------------------------------------
--   1. Talents #3/#4 sit at slots BEFORE their legal hero level -- "问题在于它
--      挡住后面的能力多久 -- 本条测到的就是那个「多久」".
--   2. nTalentBuildList[5..8] is the OTHER SIDE of tiers already taken, and only
--      one talent per tier is ever grantable, so "队头一旦走到槽 20+,结构上再
--      也没有可买项".
--
-- WHAT THIS FILE SETTLES
-- ----------------------
-- Claim 1 is TRUE and it is not rare, it is universal: ALL 173 default-branch
-- build rows place at least one talent below its legal hero level (§4).  All five
-- focus heroes do, identically: t20 is pulled from slot 20 to slot 18, t25 from
-- slot 25 to 19.
--
-- ⚠️ The first probe of this read 174 of 177 and read the three exceptions as
-- meaningful.  They were meepo/invoker rows driven through a loop those two
-- heroes never reach (LIMIT A).  Excluding them, there are no exceptions -- and
-- the guard that caught it is in §4, not in review.
--
-- Claim 2 is TRUE: over all 16 talent-tree shapes, entries [5..8] are exactly the
-- complementary sides of the tiers entries [1..4] pick (§5), so the last four
-- slots are unbuyable by construction.
--
-- ⭐⭐ AND YET THE ANSWER TO "多久" IS ZERO, WHICH IS THE POINT OF THE FILE.
-- §6 sweeps all 177 rows and counts the items that sit BEHIND a parked talent and
-- are LEGAL at the level the head parks: the count is 0.  The reason is a
-- one-line theorem, and it is worth stating because the arithmetic looks alarming
-- until you see it:
--
--     A talent is pulled below its legal level ONLY by the loop's second
--     disjunct, `ability_idx > #nAbilityBuildList` -- that is, only once the
--     ability row is EXHAUSTED.  So the very condition that mis-places the
--     talent also guarantees there is no ability left behind it.
--
-- And a parked talent never blocks a legal TALENT either: the emission order is
-- t10,t15,t20,t25 then the four dead sides, so legal levels are non-decreasing
-- along the queue; if entry k is illegal at slot s, every entry after it is too.
--
-- ⇒ Both claims are exonerated as causes of the stall #822 measured.  The whole
-- weight of those 229/282 PROVEN rows stays on the entry-15 head-park (GH #366),
-- whose surviving question -- `IsHidden()` vs the level requirement -- is GH #799
-- acceptance 1 and is stated there to be unbuyable offline.  This file does not
-- move that, and deliberately asserts nothing about it.
--
-- ⛔ LIMIT A -- THE CENSUS READS THE **DEFAULT** BRANCH ONLY.  X.GetSkillList
-- special-cases meepo and invoker with hardcoded tables, keyed on the LIVE bot's
-- GetUnitName().  The mock bot here is axe, so every row is evaluated through the
-- default loop.  For meepo's and invoker's own rows that is NOT the list that
-- ships, so §3-§6 exclude them by name rather than quietly averaging them in.
-- 125 of 127 heroes take the default branch; those two do not.
--
-- ⛔ LIMIT B -- #822's LIMIT B is inherited verbatim: everything here is about
-- DEFERRAL, never waste.  ⛔ No sentence of the form "N points were thrown away"
-- is licensed by this file, and §6 returning 0 is not a claim that the stall is
-- harmless -- it is a claim that THESE TWO MECHANISMS are not the stall.
--
-- ⛔ LIMIT C -- §7 registers a real limitation of the shipped `skillstall`
-- look-ahead, NOT a defect to go fix.  Once the head reaches the dead tail every
-- entry behind it is also a dead talent, so FindUpgradableBehindHead returns nil
-- by construction.  That is correct behaviour: at that moment the build is
-- complete (15 abilities + 4 talents = 19 purchasables) and there is genuinely
-- nothing to buy.  ⛔ Do not "fix" this by widening the look-ahead.
--
-- ⚠️ LIMIT D -- §7's LOOK-AHEAD HALF IS REDUNDANT, AND SAYING SO IS THE POINT.
-- tests/test_skillstall_lookahead.lua already owns that function and covers it
-- better: its §4 (first spendable entry behind the head), §4b (index 1 never
-- returned even when the head is upgradable), §4c (nil when nothing behind is
-- upgradable), §4d (each of the four conditions is load-bearing) and §4e (nil /
-- non-string entries stepped over) predate this file.  So the positive control
-- and the three guard assertions below are a SECOND copy, not new coverage --
-- which also means the two mutants they kill in mutstand_slotpark.sh (`for i = 2`
-- -> `for i = 1`, and dropping the max-level ceiling) were already killed in the
-- tree by that file's §4b/§4d.  ⛔ Do not read this file's §7 as evidence that
-- the look-ahead was unguarded; it was not.
-- What is NOT redundant, and is why §7 stays: the DEAD-TAIL SHAPE -- that the
-- tail starts at slot 20, that all four of its entries are talent entries >= 5,
-- and therefore that a nil there is structural.  That is #822 claim 2's
-- consequence and it lives nowhere else.
--
-- ⚠️ Tagged [ratchet].  §4/§5/§7 assert that the shipped arithmetic still has
-- this shape.  If the slot loop is rewritten they go red; that is the
-- notification, and the re-derivation is §6's theorem, not these numbers.

package.path = 'tests/?.lua;' .. package.path

local skillmap = require('skill_level_map')

-- The talent tier that nTalentBuildList index k represents.  ⛔ NOT assumed:
-- §5 drives X.GetTalentBuild over all 16 tree shapes and proves that index k
-- points into sTalentList slots (2k-1, 2k) for k<=4 and at the other side of the
-- same tier for k+4.  §6 depends on this table, so §5 must pass for §6 to mean
-- anything -- that is why §5 is not merely descriptive.
local TIER_OF_ENTRY = { 10, 15, 20, 25, 10, 15, 20, 25 }

-- Heroes whose shipped list is NOT the default loop (LIMIT A).
local HARDCODED = { meepo = true, invoker = true }

local tests = {}

--- Marker lists.  Abilities are 'A<i>' and talents 'T<i>', so the interleave is
--- READ OFF the shipped function instead of being re-transcribed next to it --
--- the standing lesson that every simplification in a local re-implementation is
--- an assumption nobody signed.  X.GetSkillList takes all four lists as
--- parameters, so driving it needs no dump and no fixture.
local sAB, sTAL, nTAL = {}, {}, {}
for i = 1, 40 do sAB[i] = 'A' .. i end
for i = 1, 8 do sTAL[i] = 'T' .. i; nTAL[i] = i end

local J, tHeroFiles

local function setup()
    if J ~= nil then return end
    local api = require('mock.bot_api')
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_axe') })
    J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

    tHeroFiles = {}
    local fh = assert(io.popen('ls bots/BotLib/hero_*.lua'), 'cannot list BotLib')
    for sLine in fh:lines() do tHeroFiles[#tHeroFiles + 1] = sLine end
    fh:close()
    assert(#tHeroFiles >= 120,
        'only ' .. #tHeroFiles .. ' hero files were listed; the repo carries 127.  '
        .. 'A census over a shrunken corpus is not a census that passed.')
end

--- Drive the shipped loop for one row and classify every slot.
--- Returns: tKind[slot] = {'A', ability_row_index} or {'T', talent_entry_index},
--- and the slot count.
---
--- ⭐ The entry index is parsed OUT OF THE EMITTED MARKER ('T3' -> 3), never
--- counted by emission order.  The first version of this reader counted order,
--- and the mutation stand caught what that costs: a loop that never advances
--- `talent_idx` emits entry 1 into all eight talent slots, and an order-counting
--- reader labels those 1,2,...,8 and sees nothing wrong.  Identity of the thing
--- emitted, not position in the sequence -- the same lesson the argmax rounds
--- paid for twice.
local function drive(tRow)
    local tList = J.Skill.GetSkillList(sAB, tRow, sTAL, nTAL)
    local nSlots = #tRow + #nTAL
    local tKind = {}
    for i = 1, nSlots do
        local sVal = tList[i]
        if sVal ~= nil then
            local sTag, sNum = sVal:match('^([AT])(%d+)$')
            assert(sTag ~= nil,
                'slot ' .. i .. ' holds ' .. tostring(sVal) .. ', which is not one '
                .. 'of this file\'s markers.  The markers are how entry identity is '
                .. 'read; an unparseable one must raise, not be skipped.')
            tKind[i] = { sTag, tonumber(sNum) }
        end
    end
    return tKind, nSlots
end

--- Every default-branch build row in the corpus, as { hero=, row=, n= }.
local function corpus()
    setup()
    local tOut = {}
    for _, sPath in ipairs(tHeroFiles) do
        local sHero = sPath:match('hero_(.-)%.lua')
        if not HARDCODED[sHero] then
            local bOk, _, tRows = pcall(skillmap.build_row, skillmap.read_file(sPath))
            if bOk then
                for nWhich, tRow in ipairs(tRows) do
                    tOut[#tOut + 1] = { hero = sHero, row = tRow, n = nWhich }
                end
            end
        end
    end
    assert(#tOut >= 170,
        'the corpus came back with only ' .. #tOut .. ' rows; 175+ are expected '
        .. 'after excluding meepo and invoker.  Check build_row, not this bound.')
    return tOut
end

tests['1. the slot loop this file reads is still the one that ships'] = function()
    setup()
    local sSrc = skillmap.read_file('bots/FunLib/aba_skill.lua')

    -- The interleave rule, anchored literally.  If it moves, every number below
    -- is about a function that no longer exists and must be re-taken.
    assert(sSrc:find('i >= 10 and (i % 5 == 0 or ability_idx > #nAbilityBuildList)', 1, true),
        'bots/FunLib/aba_skill.lua no longer contains the interleave condition '
        .. 'this file is anchored on.  §6 theorem names the SECOND disjunct as the '
        .. 'reason the mis-placement is harmless -- if that disjunct changed, the '
        .. 'theorem is void and the exoneration must be re-derived, not re-quoted.')

    assert(sSrc:find('local totalSlots = #nAbilityBuildList + #nTalentBuildList', 1, true),
        'the slot count is no longer #abilities + #talents; the dead-tail '
        .. 'arithmetic in §5 is keyed on that identity.')

    -- LIMIT A's two overrides, asserted rather than remembered.
    for sName in pairs(HARDCODED) do
        assert(sSrc:find("botName == 'npc_dota_hero_" .. sName .. "'", 1, true),
            sName .. ' no longer has a hardcoded branch in X.GetSkillList.  If it '
            .. 'now takes the default loop it must be PUT BACK into the census, '
            .. 'not left excluded -- LIMIT A would be over-claiming.')
    end
end

tests['2. positive control: the hole detector fires on a short row'] = function()
    setup()
    -- A row shorter than 9 leaves the pre-slot-10 tail unassigned, because the
    -- else-branch assigns nothing once abilities run out while i < 10.  This is
    -- the shape §3 reports ZERO of, so it has to be shown firing first -- a
    -- detector that never fires is not evidence that the corpus is clean.
    local tKind, nSlots = drive({ 1, 2, 3, 4, 5 })
    local tHoles = {}
    for i = 1, nSlots do
        if tKind[i] == nil then tHoles[#tHoles + 1] = i end
    end
    assert(nSlots == 13, 'expected 5 + 8 = 13 slots, got ' .. nSlots)
    assert(#tHoles == 4,
        'the 5-entry control produced ' .. #tHoles .. ' holes, expected 4 '
        .. '(slots 6-9).  If this control stops firing, §3 passes vacuously.')
    assert(table.concat(tHoles, ',') == '6,7,8,9',
        'the control holes moved to {' .. table.concat(tHoles, ',') .. '}; '
        .. 'expected {6,7,8,9}.')
end

tests['3. no shipped row has a hole, loses an ability, or drops a talent'] = function()
    local tCorpus = corpus()
    local tBad = {}
    for _, e in ipairs(tCorpus) do
        local tKind, nSlots = drive(e.row)
        local nHoles, nAbil, nTalent = 0, 0, 0
        for i = 1, nSlots do
            local k = tKind[i]
            if k == nil then nHoles = nHoles + 1
            elseif k[1] == 'A' then nAbil = nAbil + 1
            else nTalent = nTalent + 1 end
        end
        if nHoles > 0 or nAbil ~= #e.row or nTalent ~= 8 then
            tBad[#tBad + 1] = string.format('%s row %d (holes=%d abil=%d/%d tal=%d)',
                e.hero, e.n, nHoles, nAbil, #e.row, nTalent)
        end
    end
    assert(#tBad == 0,
        'these rows lose entries in the slot loop: ' .. table.concat(tBad, '; ')
        .. '.  §2 proves the detector fires, so this is a real finding: a dropped '
        .. 'ability or talent is a point the hero can never spend.')
end

tests['4. #822 claim 1 is TRUE -- every default-branch row parks a talent early'] = function()
    local tCorpus = corpus()
    local nEarly, nRows = 0, #tCorpus
    for _, e in ipairs(tCorpus) do
        local tKind, nSlots = drive(e.row)
        for i = 1, nSlots do
            local k = tKind[i]
            if k ~= nil and k[1] == 'T' and i < TIER_OF_ENTRY[k[2]] then
                nEarly = nEarly + 1
                break
            end
        end
    end
    -- ⚠️ 173/173, and the road to that number is worth keeping.  The first probe
    -- of this reading said 174 of 177 and treated the three exceptions as
    -- meaningful ("a property of the row, not of the loop").  They were not: all
    -- four excluded rows belong to meepo and invoker, whose shipped lists are
    -- hardcoded tables (LIMIT A), and three of them only looked exceptional
    -- because the default loop was run over a row that never reaches it.  The
    -- anti-vacuity guard below is what caught it.
    assert(nEarly == nRows,
        'expected EVERY default-branch row to park a talent below its legal level, '
        .. 'got ' .. nEarly .. ' of ' .. nRows .. '.  #822 claim 1 is a statement '
        .. 'about the shipped rows; if the count moved, say so rather than '
        .. 'adjusting it.')
    assert(nRows == 173, 'the default-branch corpus is ' .. nRows .. ' rows, not '
        .. '173.  §4 and §6 both quote counts off it.')

    -- The discriminator, so "every row" is not a blanket truth.  Talent entry 1
    -- is t10 and the loop's first disjunct puts it at slot 10 exactly, so it is
    -- never early; if THAT went early too, `i < TIER_OF_ENTRY` would be measuring
    -- something other than premature placement.
    local nT10Early = 0
    for _, e in ipairs(tCorpus) do
        local tKind, nSlots = drive(e.row)
        for i = 1, nSlots do
            local k = tKind[i]
            if k ~= nil and k[1] == 'T' and k[2] == 1 and i < 10 then
                nT10Early = nT10Early + 1
            end
        end
    end
    assert(nT10Early == 0,
        nT10Early .. ' rows place the t10 talent before slot 10.  The `i >= 10` '
        .. 'guard is what prevents that; if it is gone, §6 must be re-derived.')

    -- The focus five, specifically: t20 pulled to slot 18, t25 to slot 19.
    for _, sHero in ipairs({ 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }) do
        local _, tRows = skillmap.build_row(
            skillmap.read_file('bots/BotLib/hero_' .. sHero .. '.lua'))
        for nWhich, tRow in ipairs(tRows) do
            local tKind = drive(tRow)
            assert(tKind[18] ~= nil and tKind[18][1] == 'T' and tKind[18][2] == 3,
                sHero .. ' row ' .. nWhich .. ': slot 18 is no longer talent entry '
                .. '3 (t20).  The focus five all shared this layout.')
            assert(tKind[19] ~= nil and tKind[19][1] == 'T' and tKind[19][2] == 4,
                sHero .. ' row ' .. nWhich .. ': slot 19 is no longer talent entry '
                .. '4 (t25).')
        end
    end
end

tests['5. #822 claim 2 is TRUE -- entries 5-8 are the other side of the same tiers'] = function()
    setup()
    local nCombos, nBad = 0, 0
    for t10 = 0, 1 do for t15 = 0, 1 do for t20 = 0, 1 do for t25 = 0, 1 do
        nCombos = nCombos + 1
        local nb = J.Skill.GetTalentBuild({
            t10 = { t10, 0 }, t15 = { t15, 0 },
            t20 = { t20, 0 }, t25 = { t25, 0 },
        })
        -- Tier k occupies sTalentList slots (2k-1, 2k): GetTalentList inserts the
        -- engine's talents in slot order, two per tier.  Entry k picks one side;
        -- entry k+4 must be the other.
        for k = 1, 4 do
            local nLo, nHi = 2 * k - 1, 2 * k
            local a, b = nb[k], nb[k + 4]
            if not ((a == nLo and b == nHi) or (a == nHi and b == nLo)) then
                nBad = nBad + 1
            end
        end
        -- This is also what licenses TIER_OF_ENTRY for §6.
        for k = 1, 8 do
            local nTier = ({ 10, 15, 20, 25 })[((k - 1) % 4) + 1]
            assert(TIER_OF_ENTRY[k] == nTier,
                'TIER_OF_ENTRY[' .. k .. '] disagrees with GetTalentBuild\'s own '
                .. 'ordering; §6 reads legal levels out of that table.')
        end
    end end end end

    assert(nCombos == 16, 'expected 16 talent-tree shapes, drove ' .. nCombos)
    assert(nBad == 0, nBad .. ' of 64 (entry k, entry k+4) pairs are NOT the two '
        .. 'sides of one tier.  #822 claim 2 rests on exactly that pairing; if it '
        .. 'broke, the last four slots may now be buyable and the dead-tail '
        .. 'reading must be re-taken.')
end

tests['6. ⭐ the answer to #822\'s "多久" is ZERO -- nothing legal is ever behind a parked talent'] = function()
    local tCorpus = corpus()
    local nParked, nBehind, nViolations = 0, 0, 0
    local tWitness = {}

    for _, e in ipairs(tCorpus) do
        local tKind, nSlots = drive(e.row)
        for s = 1, nSlots do
            local k = tKind[s]
            if k ~= nil and k[1] == 'T' and s < TIER_OF_ENTRY[k[2]] then
                -- The head parks here at hero level s.  Anything behind it that is
                -- already legal at level s is a point this loop is banking.
                nParked = nParked + 1
                for j = s + 1, nSlots do
                    local k2 = tKind[j]
                    if k2 ~= nil then
                        nBehind = nBehind + 1
                        local bLegal
                        if k2[1] == 'A' then
                            bLegal = true -- an ability entry is legal whenever reached
                        else
                            bLegal = (k2[2] <= 4) and (TIER_OF_ENTRY[k2[2]] <= s)
                        end
                        if bLegal then
                            nViolations = nViolations + 1
                            if #tWitness < 5 then
                                tWitness[#tWitness + 1] = string.format(
                                    '%s row %d: parked at slot %d, legal item at slot %d',
                                    e.hero, e.n, s, j)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Anti-vacuity, both halves.  "Zero violations" is free if the scan never
    -- found a parked talent, and equally free if it never looked behind one.
    assert(nParked >= 300, 'the sweep only found ' .. nParked .. ' parked talents; '
        .. '§4 says 174 rows carry at least one and most carry several.  A zero '
        .. 'from a scan that found nothing is not a result.')
    assert(nBehind >= 300, 'the sweep looked behind parked talents only ' .. nBehind
        .. ' times.  Zero violations out of zero inspections is not a result.')

    assert(nViolations == 0,
        nViolations .. ' item(s) sit behind a parked talent while already legal: '
        .. table.concat(tWitness, '; ') .. '.  That would mean the slot loop DOES '
        .. 'bank points on its own, which is the opposite of what this file '
        .. 'reports -- re-open GH #822 §源码算术 before touching anything else.')
end

tests['7. LIMIT C: at the dead tail the skillstall look-ahead returns nil by construction'] = function()
    setup()
    -- Build the queue the focus five actually get, then ask the shipped
    -- look-ahead the question the dispatcher asks once the head reaches slot 20.
    local _, tRows = skillmap.build_row(skillmap.read_file('bots/BotLib/hero_lion.lua'))
    local tKind, nSlots = drive(tRows[1])
    assert(nSlots == 23, 'lion row 1 no longer yields 23 slots (got ' .. nSlots .. ')')

    -- Every slot from the first dead entry on must be a dead talent (entry >= 5).
    local nFirstDead
    for i = 1, nSlots do
        local k = tKind[i]
        if k ~= nil and k[1] == 'T' and k[2] >= 5 and nFirstDead == nil then
            nFirstDead = i
        end
    end
    assert(nFirstDead == 20, 'the dead tail no longer starts at slot 20 (got '
        .. tostring(nFirstDead) .. ')')
    local nDead = 0
    for i = nFirstDead, nSlots do
        local k = tKind[i]
        assert(k ~= nil and k[1] == 'T' and k[2] >= 5,
            'slot ' .. i .. ' is inside the dead tail but is not a dead talent.  '
            .. 'If a buyable entry now sits back there, LIMIT C is wrong and the '
            .. 'look-ahead DOES have work to do at the tail.')
        nDead = nDead + 1
    end
    assert(nDead == 4, 'expected a 4-entry dead tail, found ' .. nDead)

    -- ⚠️ THE MOCK'S DEFAULT ABILITY IS NOT A CANDIDATE, and the first version of
    -- this section did not know that.  A default handle answers
    -- CanAbilityBeUpgraded() == false and GetLevel() == GetMaxLevel() == 0, so
    -- TWO of the four conjuncts fail and the loop returns nil no matter what the
    -- queue holds.  Every look-ahead assertion here passed vacuously; the
    -- mutation stand proved it by surviving both `for i = 2` -> `for i = 1` and
    -- the removal of the max-level ceiling.  So the candidates below are built
    -- explicitly, and the positive control comes first.
    local api = require('mock.bot_api')

    local UPGRADABLE = { IsHidden = false, CanAbilityBeUpgraded = true,
        GetLevel = 1, GetMaxLevel = 4, GetHeroLevelRequiredToUpgrade = 1 }
    local MAXED = { IsHidden = false, CanAbilityBeUpgraded = true,
        GetLevel = 4, GetMaxLevel = 4, GetHeroLevelRequiredToUpgrade = 1 }
    local TIER_UNREACHED = { IsHidden = false, CanAbilityBeUpgraded = true,
        GetLevel = 0, GetMaxLevel = 1, GetHeroLevelRequiredToUpgrade = 30 }
    local DEAD_SIDE = { IsHidden = false, CanAbilityBeUpgraded = false,
        GetLevel = 0, GetMaxLevel = 1, GetHeroLevelRequiredToUpgrade = 10 }

    local function bot_with(tSpecs)
        local tCache = {}
        return api.MakeHero('npc_dota_hero_axe', {
            GetAbilityByName = function(_, sName)
                if tCache[sName] == nil then
                    tCache[sName] = api.MakeAbility(sName, tSpecs[sName] or DEAD_SIDE)
                end
                return tCache[sName]
            end,
        })
    end

    -- POSITIVE CONTROL: with a real candidate behind the head, the look-ahead
    -- must find it and must report its index.
    local nIdx, hAb = J.Skill.FindUpgradableBehindHead(
        bot_with({ q3 = UPGRADABLE }), { 'q1', 'q2', 'q3', 'q4' }, 25)
    assert(nIdx == 3, 'the look-ahead did not find the one upgradable entry '
        .. 'behind the head (got ' .. tostring(nIdx) .. ', expected 3).  Without '
        .. 'this control every other assertion in this section is vacuous.')
    assert(hAb ~= nil, 'the look-ahead returned an index but no handle')

    -- The head is NEVER returned, even when the head itself is upgradable.
    local nHeadIdx = J.Skill.FindUpgradableBehindHead(
        bot_with({ q1 = UPGRADABLE, q4 = UPGRADABLE }), { 'q1', 'q2', 'q3', 'q4' }, 25)
    assert(nHeadIdx == 4, 'with an upgradable HEAD and an upgradable entry 4, the '
        .. 'look-ahead answered ' .. tostring(nHeadIdx) .. '.  Returning 1 would '
        .. 'hand the dispatcher back the very entry that already failed.')

    -- A maxed ability is not a candidate (the GetLevel < GetMaxLevel ceiling).
    assert(J.Skill.FindUpgradableBehindHead(
        bot_with({ q3 = MAXED }), { 'q1', 'q2', 'q3', 'q4' }, 25) == nil,
        'a MAXED entry was offered as upgradable; the max-level ceiling is gone.')

    -- An unreached tier is not a candidate -- this is the dead-tail case's
    -- live cousin and the reason the look-ahead cannot rescue a parked head.
    assert(J.Skill.FindUpgradableBehindHead(
        bot_with({ q3 = TIER_UNREACHED }), { 'q1', 'q2', 'q3', 'q4' }, 25) == nil,
        'an entry whose hero-level requirement is unmet was offered as upgradable.')

    -- LIMIT C itself: the real dead tail.  Four entries, head plus three, every
    -- one of them the spent side of a tier => nil, by construction.
    local tQueue = {}
    for i = nFirstDead, nSlots do tQueue[#tQueue + 1] = 'dead_talent_' .. i end
    assert(#tQueue == 4, 'the tail queue should hold the 4 dead entries')
    assert(J.Skill.FindUpgradableBehindHead(bot_with({}), tQueue, 25) == nil,
        'the all-dead tail produced a candidate.  If that is real, LIMIT C is '
        .. 'wrong and the look-ahead does have work to do back there.')

    local bot = GetBot()
    -- The guard clauses are the part worth ratcheting: a nil bot / non-table
    -- queue / non-number level must not throw inside the dispatcher.
    assert(J.Skill.FindUpgradableBehindHead(nil, tQueue, 25) == nil,
        'FindUpgradableBehindHead no longer guards a nil bot')
    assert(J.Skill.FindUpgradableBehindHead(bot, 'not a table', 25) == nil,
        'FindUpgradableBehindHead no longer guards a non-table queue')
    assert(J.Skill.FindUpgradableBehindHead(bot, tQueue, 'not a number') == nil,
        'FindUpgradableBehindHead no longer guards a non-number level')
    assert(J.Skill.FindUpgradableBehindHead(bot, { 'only_a_head' }, 25) == nil,
        'a queue with nothing behind the head must answer nil')
end

return tests
