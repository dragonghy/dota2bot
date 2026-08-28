-- [hero] Lever C -- the `bot:GetMana() >= 600` floor on Wraith King's Roshan
-- branch (bots/BotLib/hero_skeleton_king.lua, X.ConsiderQ).  ZERO behaviour
-- change in this work unit: what changed is a published CLAIM about that
-- branch, and this file is where the corrected one is machine-checked.
--
-- WHAT THE OLD CLAIM SAID, AND WHY IT IS WITHDRAWN
--
-- The comment that stood above the branch concluded "this branch is unreachable
-- in turbo whatever Roshan is doing".  Two errors under it:
--
--   1. ITEMS.  It asserted that no item ahead of item_ultimate_scepter in either
--      Wraith King buy list grants intelligence.  Three do, and two of them are
--      the sixth and seventh things pos_3 buys: Magic Wand is +3 to ALL
--      attributes, Bracer is +2 intelligence, and each Iron Branch is +1 to all
--      attributes.  (Scepter itself is +10 all attributes AND a flat +175 mana,
--      also uncounted.)
--   2. ARITHMETIC.  Intelligence is FLOORED before it pays out at 12 mana a
--      point.  The old note multiplied the fractional total, which overstates
--      the pool by up to 7 mana -- it quoted 502 at level 15 (really 495), 569
--      at 19 (really 567), 586 at 20 (really 579).
--
-- THE MODEL, AND WHY IT IS NOT ASSERTED BUT MEASURED
--
--     pool = 75 + 12 * floor(16 + 1.4*(level-1) + item_int) + item_flat_mana
--
-- Section 1 runs that against every Wraith King frame in tests/fixtures -- 34
-- hero rows across the archive, each carrying its own level, its own item list
-- and the max_mp the engine actually reported.  33 of 34 come out EXACT.  The
-- 34th is named and pinned below rather than tolerated: f_232320_wk_od_burst
-- reports max_mp 272 on a level-6 Wraith King whose own ability levels sum to 6
-- and whose pool should be 363.  That fixture is the one the Lever A write-up
-- drives, so the disagreement is recorded here where somebody reading mana off
-- it will hit it.  (Its neighbours in the same frame are off in the same
-- direction -- a level-6 Lina at max_mp 800 -- so the suspicion is the frame,
-- not the hero.)
--
-- WHAT THE CORRECTED CLAIM IS
--
-- First level whose FULL pool reaches 600, computed in section 3 off the
-- SHIPPED buy list rather than typed in here:
--
--     bare hero                          21    (the old note's number, correct
--                                               only for a hero holding nothing)
--     magic wand, which eats the branches 19
--     wand + bracer                       18
--     + aghanim's scepter                 every level from 1
--
-- GH #84's turbo level census reads level >= 20 on 0 of 210 hero-slots with a
-- high-water of 19.  So the shipped build reaches its crossing level in the TAIL
-- of the turbo level distribution, not never: the branch is not arithmetically
-- dead, and anything quoting the old sentence is quoting a withdrawn claim.
--
-- THE TAIL IS GONE TOO, 2026-08-28 -- and this file survives that the way it
-- survived the last correction, by getting STRONGER.  The census was taken under
-- a 10-minute batch cap that owner priority P3 (GH #108) removed, and the first
-- frame past it (GH #235) has this hero at level 26 with a pool of 855 -- past
-- all three crossing levels below, not in the tail of anything.  So "not
-- arithmetically dead" upgrades to "observed alive", and the defect this file
-- names is untouched, because it was never about the level.  TURBO_HIGH_WATER_LEVEL
-- below is KEPT as a dated census reading rather than deleted: the census was
-- correctly taken, it is the population that moved.  The read that settles it,
-- together with the sibling file's mana margin -- the same quantity in levels and
-- in mana -- is tests/test_wk_roshan_lategame_reconciliation.lua, which also
-- records that the pool model below UNDER-predicts that frame by 14 intelligence
-- on its first testable extrapolation past level 12.  The direction is the safe
-- one: true crossing levels are EARLIER than 21/19/18, never later.
--
-- The defect that SURVIVES the correction is sharper than the old one.  At every
-- pre-scepter milestone the crossing pool is exactly 603, so a 600 floor asks
-- for 99.5% of the pool; Wraithfire Blast costs 95/110/125/140, so one cast puts
-- him under the floor for the rest of the Roshan fight.  The floor is 4.3x the
-- cost of the spell it gates.  That is a lever worth pulling -- and it is still
-- NOT pulled here.
--
-- 2026-08-26 UPDATE, so this header does not rot under the code: the lever HAS
-- since been pulled, GATED -- `wkrosh`, turbo-only, unarmed
-- (bots/BotLib/hero_skeleton_king.lua X.GetRoshanManaFloor, and
-- tests/test_wk_roshan_mana_floor.lua for its own evidence).  Nothing in THIS
-- file changes: every number here is about the SHIPPED leg, which still demands
-- 600, and section 3 now reaches it through the helper.  The domain paragraph
-- below is unchanged and still binding.
--
-- WHY NOT PULLED: THE DOMAIN CANNOT BE BOUGHT OFFLINE
--
-- A fractional floor is a behaviour change, and its domain is "Wraith King in
-- BOT_MODE_ROSHAN at all".  The 13th world assertion
-- (tests/test_activemode_world_assertion.lua) is that NO fixture carries an
-- active mode: GetActiveMode is bot-VM state, not entity state, so it is in no
-- .dem, so the mock answers 0 while every BOT_MODE_* name resolves >= 1001.
-- This comparison is therefore constant FALSE on every archived frame -- which
-- is a fact about the harness, not a frequency.  Section 5 pins that so nobody
-- reads a fixture-driven zero here as evidence of an empty domain (the axeblink
-- trap, which cost this stream a candidate).  Sizing it needs a POSITIONAL proxy
-- out of the batch corpus; requested as queue hero-10.
--
-- WHAT THIS FILE DOES NOT CLAIM
--
--   * That Wraith King ever actually reaches level 18-19 with a wand and a full
--     pool in a turbo game.  The crossing level is arithmetic; the population at
--     that level is GH #84's, and it is a high-water, not a mode.  (One frame now
--     shows level 26 -- see the 2026-08-28 note above.  One frame is a
--     counterexample to a universal, still not a population.)
--   * That the engine computes mana exactly this way.  33 of 34 real frames is
--     the whole warrant, and every one of them is level 12 or below -- the model
--     is EXTRAPOLATED past that, which is precisely the range the claim needs.
--     THE EXTRAPOLATION HAS SINCE BEEN TESTED ONCE AND IT MISSED, low by 14
--     intelligence at level 26; the warrant below is unchanged and so is every
--     crossing level, because missing LOW makes them conservative.  Do not quote
--     a pool from this model above level 12 without reading
--     tests/test_wk_roshan_lategame_reconciliation.lua section 4 first.
--   * Anything about whether casting Wraithfire Blast on Roshan is a good idea.
--     That is the lever's (c) argument and it has not been made.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
api.install({})

local Item = dofile('bots/FunLib/aba_item.lua')

local WK = 'bots/BotLib/hero_skeleton_king.lua'

-- Wraith King's own numbers.  267 max mana at level 1 on 16 intelligence is the
-- datafeed reading recorded by GH #104 (herodata?hero_id=42, read 2026-08-22);
-- 75 + 12/point and 1.4 int/level are the standard constants that reading is
-- consistent with.  Section 1 is what turns "consistent with" into evidence.
local BASE_MANA, MANA_PER_INT = 75, 12
local BASE_INT, INT_PER_LEVEL = 16, 1.4

-- GH #84's turbo level census: level >= 20 on 0 of 210 hero-slots, high-water 19.
-- DATED READING, superseded as a population but kept as the census it was: taken
-- under the 10-minute batch cap GH #108 removed, and a level-26 frame now exists
-- (GH #235).  Section 3 uses it as an upper bound on the SHIPPED build's crossing
-- level, and that use survives -- the observed 26 only makes the bound looser.
local TURBO_HIGH_WATER_LEVEL = 19

-- Intelligence and flat mana per item, from odota dotaconstants 10.8.0 (read
-- 2026-08-23), keyed by the basic name both the fixtures and the buy lists use
-- once the item_ prefix is off.  { intelligence, flat mana }.  Everything Wraith
-- King's two shipped lists can buy is here, and section 4 fails if the lists
-- grow an entry this table does not know -- that is the ratchet: a future buy
-- list with a new intelligence item invalidates the crossing levels above, and
-- it has to fail rather than silently answer with the old ones.
local ITEM_STATS = {
    ['abyssal_blade']       = { 0, 0 },
    ['aghanims_shard']      = { 0, 0 },
    ['armlet']              = { 0, 0 },
    ['assault']             = { 0, 0 },
    ['black_king_bar']      = { 0, 0 },
    ['blades_of_attack']    = { 0, 0 },
    ['blink']               = { 0, 0 },
    ['boots_of_speed']      = { 0, 0 },
    ['bracer']              = { 2, 0 },
    ['branches']            = { 1, 0 },   -- buy-list spelling
    ['clarity']             = { 0, 0 },
    ['flask']               = { 0, 0 },
    ['gauntlets']           = { 0, 0 },
    ['gloves_of_haste']     = { 0, 0 },
    ['helm_of_iron_will']   = { 0, 0 },
    ['ironwood_branch']     = { 1, 0 },   -- fixture spelling of the same item
    ['magic_stick']         = { 0, 0 },
    ['magic_wand']          = { 3, 0 },
    ['moon_shard']          = { 0, 0 },
    ['nullifier']           = { 0, 0 },
    ['overwhelming_blink']  = { 0, 0 },
    ['phase_boots']         = { 0, 0 },
    ['quelling_blade']      = { 0, 0 },
    ['radiance']            = { 0, 0 },
    ['recipe_magic_wand']   = { 0, 0 },
    ['refresher']           = { 0, 0 },
    ['tango']               = { 0, 0 },
    ['tango_single']        = { 0, 0 },
    ['travel_boots']        = { 0, 0 },
    ['travel_boots_2']      = { 0, 0 },
    ['ultimate_scepter']    = { 10, 175 },
    ['ultimate_scepter_2']  = { 0, 0 },
}

-- What a finished composite REPLACES in the bag.  Only Magic Wand matters for
-- Wraith King, and only its branches carry intelligence, but the rule is written
-- as a component list so that adding another composite is an edit here rather
-- than an arithmetic patch.  Anchored twice: the repo's own 15/15 outfit law
-- (tests/test_wk_magic_wand_branches.lua) says a wand is stick + two branches +
-- recipe, and section 2 shows no real Wraith King frame ever holds a wand and a
-- loose branch at the same time.
local ABSORBS = {
    ['item_magic_wand'] = { 'item_magic_stick', 'item_branches', 'item_branches',
                            'item_recipe_magic_wand' },
}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments before any name is picked out of a source.  Same
--- definition, and the same reason, as in test_wk_magic_wand_branches.lua: the
--- explanatory blocks next to these lists quote item names while describing
--- bugs, and a parser that reads prose reports the prose.
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Flatten one buy-list entry through the REAL composite table out of
--- aba_item.lua.  Static macros (item_double_branches) expand; assembled items
--- (item_magic_wand) have no entry there and stay whole, which is exactly the
--- distinction this file needs.
local function flatten(sName, tOut, nDepth)
    tOut, nDepth = tOut or {}, (nDepth or 0) + 1
    assert(nDepth <= 12, 'composite nesting deeper than 12 at ' .. sName)
    local tComp = Item[sName]
    if type(tComp) == 'table' and #tComp > 0 then
        for _, v in ipairs(tComp) do flatten(v, tOut, nDepth) end
    else
        tOut[#tOut + 1] = sName
    end
    return tOut
end

local function buy_lists(sPath)
    local src = strip_comments(read_file(sPath))
    local t = {}
    for sRole, sBody in src:gmatch("sRoleItemsBuyList%['(pos_%d)'%]%s*=%s*{(.-)\n}") do
        local tList = {}
        for s in sBody:gmatch("['\"](item_[%w_]+)['\"]") do tList[#tList + 1] = s end
        t[sRole] = tList
    end
    return t
end

--- Intelligence and flat mana for one item, by either spelling.  Fails loud on
--- anything unknown: a silent zero here would answer a crossing level that is
--- too high and look exactly like the old comment's mistake.
local function stats_of(sName)
    local sBase = sName:gsub('^item_', '')
    local t = ITEM_STATS[sBase]
    assert(t, 'no intelligence reading for item "' .. sName .. '". Add it from '
        .. 'the item data (odota dotaconstants build/items.json, bonus_intellect '
        .. '/ bonus_all_stats / bonus_mana) and RE-CHECK the crossing levels in '
        .. 'this file\'s header -- they are computed from this table.')
    return t[1], t[2]
end

--- The pool a hero of this level holds with these item bonuses.  The floor is
--- the whole point; section 1 is what earns it.
local function pool_at(nLevel, nInt, nFlatMana)
    return BASE_MANA
        + MANA_PER_INT * math.floor(BASE_INT + INT_PER_LEVEL * (nLevel - 1) + nInt)
        + nFlatMana
end

--- First hero level whose full pool reaches nFloor, or nil inside 1..30.
local function first_level_reaching(nFloor, nInt, nFlatMana)
    for nLevel = 1, 30 do
        if pool_at(nLevel, nInt, nFlatMana) >= nFloor then return nLevel end
    end
    return nil
end

--- One buy-list entry, as the things that end up IN THE BAG.  ITEM_STATS wins
--- over aba_item's recipe table on purpose: aba_item defines real assembled
--- items too (item_phase_boots = blades + boots + chainmail, item_ultimate_
--- scepter = point booster + three staves), and expanding those would price the
--- components instead of the item the hero holds -- Aghanim's +175 mana would
--- arrive twice, once as itself and once as the point booster inside it.  Only
--- entries this file has no reading for are treated as shopping macros and
--- expanded, which is exactly item_double_branches.
local function bag_entries(sEntry)
    if ITEM_STATS[(sEntry:gsub('^item_', ''))] then return { sEntry } end
    return flatten(sEntry)
end

--- Walk a buy list to entry nUpTo and report what is in the bag: intelligence,
--- flat mana.  Composites remove what they consumed (ABSORBS), so the two
--- branches bought for a wand are not counted twice.
local function bag_after(tList, nUpTo)
    local tHeld = {}
    for i = 1, nUpTo do
        for _, sBasic in ipairs(bag_entries(tList[i])) do
            tHeld[#tHeld + 1] = sBasic
        end
        for _, sGone in ipairs(ABSORBS[tList[i]] or {}) do
            for j = #tHeld, 1, -1 do
                if tHeld[j] == sGone then table.remove(tHeld, j); break end
            end
        end
    end
    local nInt, nMana = 0, 0
    for _, sHeld in ipairs(tHeld) do
        local i, m = stats_of(sHeld)
        nInt, nMana = nInt + i, nMana + m
    end
    return nInt, nMana
end

--- Index of an entry in a buy list, or nil.
local function index_of(tList, sWanted)
    for i, s in ipairs(tList) do if s == sWanted then return i end end
    return nil
end

--- Every Wraith King hero row in the fixture archive, with the fields this file
--- reads.  dofile, not a regex: the fixtures are data and the loader for them
--- already exists.
local function wk_frames()
    local p = assert(io.popen('ls tests/fixtures/f_*.lua'))
    local tRows = {}
    for sPath in p:lines() do
        local tFix = dofile(sPath)
        for _, tUnit in ipairs((tFix or {}).units or {}) do
            if tUnit.name == 'npc_dota_hero_skeleton_king' then
                tRows[#tRows + 1] = {
                    file = sPath:match('([^/]+)$'),
                    level = tUnit.level, max_mp = tUnit.max_mp,
                    items = tUnit.items or {},
                }
            end
        end
    end
    p:close()
    return tRows
end

-- The one frame whose reported pool disagrees with the model, pinned exactly so
-- that it cannot spread into a tolerance.
local KNOWN_BAD = { file = 'f_232320_wk_od_burst.lua', level = 6,
                    reported = 272, model = 363 }

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The model, against every real frame we have.

tests['[hero] the mana model reproduces every real WK frame but one'] = function()
    local tRows = wk_frames()
    assert(#tRows >= 30, 'only ' .. #tRows .. ' Wraith King frames in the '
        .. 'fixture archive; this file rests on that population, so a shrunken '
        .. 'one needs re-reading rather than a lowered bar')

    local nExact, tOff = 0, {}
    for _, tRow in ipairs(tRows) do
        local nInt, nMana = 0, 0
        for _, sItem in ipairs(tRow.items) do
            if sItem ~= '' then
                local i, m = stats_of(sItem)
                nInt, nMana = nInt + i, nMana + m
            end
        end
        local nModel = pool_at(tRow.level, nInt, nMana)
        if nModel == tRow.max_mp then
            nExact = nExact + 1
        else
            tOff[#tOff + 1] = { file = tRow.file, level = tRow.level,
                                reported = tRow.max_mp, model = nModel }
        end
    end

    assert(#tOff == 1, 'the mana model disagrees with ' .. #tOff .. ' real '
        .. 'frame(s); exactly one disagreement is recorded (' .. KNOWN_BAD.file
        .. '). Every crossing level in this file comes out of this model, so a '
        .. 'second disagreement invalidates them.')
    local tBad = tOff[1]
    assert(tBad.file == KNOWN_BAD.file and tBad.level == KNOWN_BAD.level
        and tBad.reported == KNOWN_BAD.reported and tBad.model == KNOWN_BAD.model,
        'the single disagreeing frame is now ' .. tBad.file .. ' at level '
        .. tBad.level .. ' (reports ' .. tBad.reported .. ', model says '
        .. tBad.model .. '); the recorded one is ' .. KNOWN_BAD.file .. ' at '
        .. 'level ' .. KNOWN_BAD.level .. ' (' .. KNOWN_BAD.reported .. ' vs '
        .. KNOWN_BAD.model .. ')')
    assert(nExact >= 30, 'only ' .. nExact .. ' frames match exactly')
end

tests['[hero] the floor in the model is what fits the frames, not decoration'] = function()
    -- Drop the floor and the same corpus stops matching. Without this, someone
    -- "simplifying" math.floor out would keep a green suite and a model that is
    -- up to 11 mana high -- which is the size of the error being corrected.
    local nUnfloored = 0
    for _, tRow in ipairs(wk_frames()) do
        local nInt, nMana = 0, 0
        for _, sItem in ipairs(tRow.items) do
            if sItem ~= '' then
                local i, m = stats_of(sItem)
                nInt, nMana = nInt + i, nMana + m
            end
        end
        local nNoFloor = BASE_MANA
            + MANA_PER_INT * (BASE_INT + INT_PER_LEVEL * (tRow.level - 1) + nInt)
            + nMana
        if nNoFloor == tRow.max_mp then nUnfloored = nUnfloored + 1 end
    end
    assert(nUnfloored < 15, 'the unfloored model now fits ' .. nUnfloored
        .. ' frames; the floor was justified by fitting strictly better')
end

-- ---------------------------------------------------------------------------
-- 2. The absorption rule, corroborated by the archive.

tests['[hero] no real WK frame holds a wand and a loose branch at once'] = function()
    local nWithWand, tBoth = 0, {}
    for _, tRow in ipairs(wk_frames()) do
        local bWand, bBranch = false, false
        for _, sItem in ipairs(tRow.items) do
            if sItem == 'magic_wand' then bWand = true end
            if sItem == 'ironwood_branch' then bBranch = true end
        end
        if bWand then
            nWithWand = nWithWand + 1
            if bBranch then tBoth[#tBoth + 1] = tRow.file end
        end
    end
    assert(nWithWand >= 5, 'only ' .. nWithWand .. ' frames carry a finished '
        .. 'wand; the corroboration below would be vacuous')
    assert(#tBoth == 0, 'frames holding both a wand and a loose branch: '
        .. table.concat(tBoth, ', ') .. '. The bag model assumes the wand '
        .. 'consumed them.')
end

-- ---------------------------------------------------------------------------
-- 3. The corrected claim, computed off the shipped source.

tests['[hero] the Roshan branch still prices itself off the same 600'] = function()
    -- UPDATED 2026-08-26.  This assertion used to demand the literal shape
    --     BOT_MODE_ROSHAN ... and bot:GetMana() >= 600
    -- and it FIRED the day the lever this file registered was finally written
    -- (`wkrosh`, gated).  That is the ratchet doing its job, not a false alarm --
    -- so it is re-pointed rather than relaxed.  Every crossing level in this file
    -- is about the number the SHIPPED leg still demands, and the shipped leg is
    -- now the default return of X.GetRoshanManaFloor.  Both halves are checked:
    -- the branch must still consult that helper, and the helper's shipped default
    -- must still be 600.
    local src = read_file(WK)
    assert(src:find('BOT_MODE_ROSHAN[^\n]*\n%s*and bot:GetMana%(%) >= '
        .. 'X%.GetRoshanManaFloor'), 'the Roshan branch in ' .. WK .. ' no longer '
        .. 'reads `GetActiveMode() == BOT_MODE_ROSHAN` followed by the floor '
        .. 'helper; every number in this file is about that comparison')
    local sShipped = src:match('function X%.GetRoshanManaFloor.-local nShipped = (%d+)')
    assert(sShipped, 'X.GetRoshanManaFloor no longer declares a shipped floor')
    assert(tonumber(sShipped) == 600, 'the shipped floor is now ' .. sShipped
        .. '; the crossing levels recorded here are for 600')
    -- And the armed leg is somebody else's file to test -- named here so the two
    -- cannot drift apart silently.
    assert(src:find("J%.IsSoakCandidate%( 'wkrosh' %)"), 'the widened leg is gone '
        .. 'from ' .. WK .. '. If `wkrosh` was PROMOTED, the crossing levels here '
        .. 'describe a floor the bot no longer uses: rewrite, do not delete. '
        .. 'See tests/test_wk_roshan_mana_floor.lua')
end

tests['[hero] with the shipped build the floor is reachable inside turbo'] = function()
    local tPos3 = assert(buy_lists(WK)['pos_3'], 'no pos_3 buy list in ' .. WK)
    local nWand = assert(index_of(tPos3, 'item_magic_wand'),
        'pos_3 no longer buys a magic wand; the crossing levels change')
    local nBracer = assert(index_of(tPos3, 'item_bracer'),
        'pos_3 no longer buys a bracer; the crossing levels change')

    local nBareLevel = first_level_reaching(600, 0, 0)
    assert(nBareLevel == 21, 'a bare Wraith King first holds 600 at level '
        .. tostring(nBareLevel) .. ', recorded 21 -- this is the only number the '
        .. 'withdrawn comment had right')

    local nIntWand, nManaWand = bag_after(tPos3, nWand)
    local nWandLevel = first_level_reaching(600, nIntWand, nManaWand)
    assert(nWandLevel == 19, 'with the wand bought, the pool first reaches 600 '
        .. 'at level ' .. tostring(nWandLevel) .. '; recorded 19')

    local nIntBracer, nManaBracer = bag_after(tPos3, nBracer)
    local nBracerLevel = first_level_reaching(600, nIntBracer, nManaBracer)
    assert(nBracerLevel == 18, 'with wand + bracer, the pool first reaches 600 '
        .. 'at level ' .. tostring(nBracerLevel) .. '; recorded 18')

    -- The conclusion, stated as the comparison it actually is.
    assert(nWandLevel <= TURBO_HIGH_WATER_LEVEL, 'the shipped build no longer '
        .. 'crosses 600 within turbo\'s observed level range (high-water '
        .. TURBO_HIGH_WATER_LEVEL .. ', GH #84). The comment above the branch '
        .. 'says it does -- one of the two is now wrong.')
end

tests['[hero] pos_1 crosses too, one level later, and pos_2/4/5 alias pos_3'] = function()
    local tLists = buy_lists(WK)
    local tPos1 = assert(tLists['pos_1'])
    local nWand = assert(index_of(tPos1, 'item_magic_wand'), 'pos_1 lost its wand')
    local nInt, nMana = bag_after(tPos1, nWand)
    assert(first_level_reaching(600, nInt, nMana) == TURBO_HIGH_WATER_LEVEL,
        'pos_1 with its wand crosses at level '
        .. tostring(first_level_reaching(600, nInt, nMana)) .. '; recorded 19. '
        .. '(pos_1 buys no bracer, so it stops at the wand.)')
    local src = strip_comments(read_file(WK))
    for _, sRole in ipairs({ 'pos_2', 'pos_4', 'pos_5' }) do
        assert(src:find("sRoleItemsBuyList%['" .. sRole .. "'%]%s*=%s*sRoleItemsBuyList%['pos_3'%]"),
            sRole .. ' stopped aliasing pos_3; it needs its own crossing level now')
    end
end

tests['[hero] the scepter turns the floor off entirely, at any level'] = function()
    -- +10 all attributes AND +175 flat mana. This is the half of the correction
    -- that is not marginal: past the scepter the floor stops selecting anything
    -- at all, so "unreachable" was wrong by a wide margin there, not by one level.
    local nInt, nMana = 0, 0
    for _, sItem in ipairs({ 'item_magic_wand', 'item_bracer', 'item_ultimate_scepter' }) do
        local i, m = stats_of(sItem); nInt, nMana = nInt + i, nMana + m
    end
    assert(first_level_reaching(600, nInt, nMana) == 1,
        'with wand + bracer + scepter the pool no longer clears 600 at level 1 '
        .. '(it reads ' .. pool_at(1, nInt, nMana) .. ')')
end

tests['[hero] the crossing pool is 603 everywhere before the scepter'] = function()
    -- The defect that survives the correction: the floor is not "a high level",
    -- it is "essentially a full pool", and it stays that at every milestone.
    for _, tCase in ipairs({ { 0, 0, 21 }, { 2, 0, 20 }, { 3, 0, 19 }, { 5, 0, 18 } }) do
        local nLevel = first_level_reaching(600, tCase[1], tCase[2])
        assert(nLevel == tCase[3], 'int+' .. tCase[1] .. ' crosses at level '
            .. tostring(nLevel) .. ', recorded ' .. tCase[3])
        local nPool = pool_at(nLevel, tCase[1], tCase[2])
        assert(nPool == 603, 'int+' .. tCase[1] .. ' crosses with a pool of '
            .. nPool .. ', recorded 603. The 99.5%-of-pool reading in the source '
            .. 'comment is this number.')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The ratchet: the table has to cover the shipped lists.

tests['[hero] every item WK can buy has an intelligence reading here'] = function()
    local tLists = buy_lists(WK)
    local nSeen = 0
    for _, sRole in ipairs({ 'pos_1', 'pos_3' }) do
        for _, sEntry in ipairs(assert(tLists[sRole], 'no ' .. sRole)) do
            for _, sBasic in ipairs(bag_entries(sEntry)) do
                stats_of(sBasic)   -- asserts on anything unknown
                nSeen = nSeen + 1
            end
        end
    end
    assert(nSeen > 30, 'only ' .. nSeen .. ' buy-list entries examined; the '
        .. 'lists lost most of their population')
end

tests['[hero] an unknown item fails loud instead of reading as zero int'] = function()
    -- The failure mode this guards is precisely the one being corrected: an
    -- item whose intelligence went uncounted answers a crossing level that is
    -- too high, and looks like a proof of unreachability.
    local ok = pcall(stats_of, 'item_bloodstone_of_the_future')
    assert(not ok, 'stats_of answered for an item it has never heard of; a '
        .. 'silent zero here is how the withdrawn claim was produced')
end

-- ---------------------------------------------------------------------------
-- 5. The judgement half, on synthetic input (backlog 24), and the honest bound.

tests['[hero] the crossing calculator answers pools other than this one'] = function()
    -- The census above walks one real hero and would pass on a calculator that
    -- happened to be right at 600. These drive it away from the shipped numbers.
    assert(pool_at(1, 0, 0) == 267, 'level 1 pool reads ' .. pool_at(1, 0, 0)
        .. '; the datafeed reading is 267')
    assert(pool_at(11, 0, 0) == 435, 'level 11 pool reads ' .. pool_at(11, 0, 0))
    assert(pool_at(15, 0, 0) == 495, 'level 15 pool reads ' .. pool_at(15, 0, 0)
        .. '; the withdrawn comment said 502 by not flooring')
    assert(pool_at(19, 0, 0) == 567, 'level 19 pool reads ' .. pool_at(19, 0, 0)
        .. '; the withdrawn comment said 569')
    assert(pool_at(20, 0, 0) == 579, 'level 20 pool reads ' .. pool_at(20, 0, 0)
        .. '; the withdrawn comment said 586')
    assert(pool_at(6, 1, 0) == 363, 'the level-6 one-branch pool reads '
        .. pool_at(6, 1, 0) .. '; that is the model figure the known-bad frame '
        .. 'disagrees with')

    assert(first_level_reaching(1000, 0, 0) == nil,
        'a floor no level reaches must answer nil, not a level')
    assert(first_level_reaching(267, 0, 0) == 1, 'a floor met at level 1 must '
        .. 'answer 1, not the first level ABOVE it')
    assert(first_level_reaching(268, 0, 0) == 2,
        'one mana past the level-1 pool must push the answer to level 2')

    -- The bag model, on a synthetic list, including the absorption rule -- the
    -- shipped list exercises absorption exactly once, so a mutation that dropped
    -- it would be a single-frame accident away from invisible.
    local nInt = select(1, bag_after({ 'item_double_branches', 'item_magic_wand' }, 2))
    assert(nInt == 3, 'wand-after-branches leaves ' .. nInt .. ' intelligence; '
        .. 'the wand consumed the two branches, so it must be 3, not 5')
    assert(select(1, bag_after({ 'item_double_branches' }, 1)) == 2,
        'two loose branches must read +2 intelligence')
    assert(select(2, bag_after({ 'item_ultimate_scepter' }, 1)) == 175,
        'the scepter\'s flat mana is not reaching the bag')
end

tests['[hero] the domain of this branch is not measurable from fixtures'] = function()
    -- The 13th world assertion, restated where this lever needs it: a
    -- fixture-driven zero here says nothing about how often Wraith King is
    -- actually on Roshan. Recorded so that the next person to size Lever C does
    -- not read one out of the archive (axeblink trap).
    assert(BOT_MODE_ROSHAN ~= 0, 'BOT_MODE_ROSHAN resolves to 0 under the mock; '
        .. 'then the shipped comparison would be TRUE by accident here')
    local nRows, nWithMode = 0, 0
    for _, tRow in ipairs(wk_frames()) do
        nRows = nRows + 1
        if tRow.mode ~= nil then nWithMode = nWithMode + 1 end
    end
    assert(nRows > 0 and nWithMode == 0, nWithMode .. ' of ' .. nRows
        .. ' fixture rows now carry an active mode. If the dumper learned to '
        .. 'record it, this lever can finally be sized offline -- rewrite this '
        .. 'test rather than deleting it.')
end

tests['[hero] the correction is still written next to the branch'] = function()
    -- The comment IS the deliverable of this work unit; a needle per claim, each
    -- wholly inside one line of the source.
    local src = read_file(WK)
    for _, sNeedle in ipairs({
        'LEVER C, RE-MEASURED 2026-08-23',
        'CONCLUSION IS WITHDRAWN',
        'is +2 intelligence',
        'Intelligence is FLOORED before it pays out at 12 mana a',
        'HIGH-WATER OF 19',
        'floor demands 99.5% OF THE POOL',
        'queue hero-10',
    }) do
        assert(src:find(sNeedle, 1, true), WK .. ' no longer contains "'
            .. sNeedle .. '". If the reasoning changed, rewrite the needle with '
            .. 'it; do not delete the reasoning and the needle together.')
    end
    -- No assertion that the old sentence is ABSENT: the new block quotes it, on
    -- purpose, so that a reader who arrives holding the old numbers finds them
    -- being retracted rather than vanished. The withdrawal needle above is what
    -- guards it -- a bare absence check would have been decoration here and
    -- would have failed on the very text it was meant to protect.
end

return tests
