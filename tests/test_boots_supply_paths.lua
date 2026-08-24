-- [hero] GH #156, source side.  Can a focus-five bot end up wearing a pair of
-- boots its own role buy list never named?
--
-- WHY THIS FILE EXISTS
--
-- The replay desk found one game in 103 (GH #156) where a Crystal Maiden on the
-- NON-armed leg of the `cmboots` wave finished Arcane Boots, while the buy list
-- her role hands the purchase layer names Tranquil Boots.  The issue's own
-- leading suspicion was an "early boots" chooser reading Item['tEarlyBoots']
-- instead of the role list.  That suspicion is falsified by reading the tree
-- (all four call sites of tEarlyBoots are possession predicates, a skip filter
-- and the late sell-your-old-boots path -- none of them ORDERS a pair), and the
-- only role->boots table outside the hero files, BOOTS_BY_POSITION in
-- FunLib/advanced_item_strategy.lua, is required by nothing.
--
-- That leaves a mechanism nobody had ruled out and which needs no bypass at
-- all: the engine assembles a recipe the instant its components are in the
-- inventory, whoever bought them and for whatever target.  A list that never
-- names Arcane Boots can still walk into one if the components it buys for
-- OTHER targets happen to add up.  This file measures exactly that, and for
-- Crystal Maiden pos_5 the answer is no -- which is what makes the 1/103 leak
-- still unexplained rather than explained away.
--
-- THE CLAIM, AND WHY IT IS ONE-DIRECTIONAL
--
-- ZERO supply is a proof: a component nobody in the list ever buys cannot be
-- consumed, cannot be freed, cannot be reordered into existence.  Arcane Boots
-- needs BOTH a sobi_mask (inside its ring_of_basilius) and a wizard_hat, so a
-- list that supplies zero of EITHER settles the question for that list in every
-- purchase order and under any consumption model.  One zero is enough; the CM
-- pos_5 list happens to have both, and section 2 records which one carries the
-- proof for each list rather than rounding them all to "clean".
--
-- NON-zero supply proves NOTHING and is deliberately not asserted on.  The
-- census in test_dup_component_buylist_census.lua learned this the expensive
-- way: counting components over a whole list produced a false positive AND a
-- false negative in the same pass, because composites earlier in the list eat
-- the very components a later target needs.  Modelling that correctly needs
-- purchase order plus consumption; this file does not have it and therefore
-- does not claim it.  The lists that come back non-zero are reported by name in
-- NOT_PROVEN below so the gap is visible instead of quietly rounded to "clean".
--
-- WHERE THE RECIPE LAW COMES FROM
--
-- Offline there are no recipes at all: the mock's GetItemComponents returns an
-- empty table, so aba_item.lua's Item['item_arcane_boots'] and friends are nil
-- here (asserted below, so nobody reads this file as having consulted the
-- engine).  The transitive component counts in SUPPLY were read out of odota's
-- dotaconstants (build/items.json, package version 10.8.0, fetched
-- 2026-08-24) -- the same source and the same version the doubled-component
-- census used.  The two numbers per row are how many item_sobi_mask and
-- item_wizard_hat that item's FULL transitive expansion contains, those being
-- the two components that separate Arcane Boots from every other pair:
--
--     arcane_boots   = boots + ring_of_basilius + wizard_hat   (1500)
--     tranquil_boots = boots + wind_lace + ring_of_regen       (900)
--     ring_of_basilius = sobi_mask                             (425)
--
-- and the leak frame's tell was exactly a ring_of_basilius, bought at t=237.4
-- with the boots, four minutes before the Arcane Boots appeared.
--
-- In-repo corroboration of the external source, so it is not trusted blind:
-- item_priest_outfit (CM's pos_4 opener, the arcane-carrying one) reads 2
-- sobi_mask / 1 wizard_hat here, and it names item_arcane_boots outright;
-- item_mage_outfit (the pos_5 opener) reads 0/0 and names item_tranquil_boots.
-- The gated `cmboots` swap replaces exactly one of those with the other, which
-- is asserted in section 3 against the two macros rather than against prose.
--
-- WHAT IS NOT CLAIMED
--
--   * Nothing about heroes outside the focus five, and nothing about any writer
--     of the purchase list other than sRoleItemsBuyList.  If the 1/103 leak came
--     from the gate itself evaluating true on the wrong leg -- the issue's own
--     "reverse possibility" -- this file cannot see it and does not pretend to.
--   * Nothing about travel boots.  Its recipe is boots + a recipe scroll, so
--     every list that buys any boots at all "supplies" it; the pair is a
--     deliberate late upgrade everywhere it appears and carries no signal.
--   * That dotaconstants is the current patch.  It is a mirror and can lag.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
api.install({})

local Item = dofile('bots/FunLib/aba_item.lua')

local BOTLIB = 'bots/BotLib/'
local FOCUS = {
    axe            = BOTLIB .. 'hero_axe.lua',
    zuus           = BOTLIB .. 'hero_zuus.lua',
    skeleton_king  = BOTLIB .. 'hero_skeleton_king.lua',
    lion           = BOTLIB .. 'hero_lion.lua',
    crystal_maiden = BOTLIB .. 'hero_crystal_maiden.lua',
}

-- item -> { sobi_mask copies, wizard_hat copies } in its transitive expansion,
-- from dotaconstants 10.8.0.  Every real item reachable from a focus-five role
-- list has a row; section 1 fails if a build change adds one that does not, so
-- the table cannot silently go stale under a new item.
local SUPPLY = {
    ['item_abyssal_blade']        = { 0, 0 },
    ['item_aether_lens']          = { 0, 0 },
    ['item_aghanims_shard']       = { 0, 0 },
    ['item_ancient_janggo']       = { 0, 0 },
    ['item_angels_demise']        = { 0, 0 },
    ['item_arcane_boots']         = { 1, 1 },
    ['item_armlet']               = { 0, 0 },
    ['item_assault']              = { 0, 0 },
    ['item_belt_of_strength']     = { 0, 0 },
    ['item_black_king_bar']       = { 0, 0 },
    ['item_blade_mail']           = { 0, 0 },
    ['item_blade_of_alacrity']    = { 0, 0 },
    ['item_blades_of_attack']     = { 0, 0 },
    ['item_blink']                = { 0, 0 },
    ['item_blood_grenade']        = { 0, 0 },
    ['item_bloodthorn']           = { 2, 0 },
    ['item_boots']                = { 0, 0 },
    ['item_boots_of_bearing']     = { 0, 0 },
    ['item_bottle']               = { 0, 0 },
    ['item_bracer']               = { 0, 0 },
    ['item_branches']             = { 0, 0 },
    ['item_chainmail']            = { 0, 0 },
    ['item_circlet']              = { 0, 0 },
    ['item_crimson_guard']        = { 0, 0 },
    ['item_cyclone']              = { 0, 0 },
    ['item_faerie_fire']          = { 0, 0 },
    ['item_flask']                = { 0, 0 },
    ['item_force_staff']          = { 0, 0 },
    ['item_gauntlets']            = { 0, 0 },
    ['item_glimmer_cape']         = { 0, 0 },
    ['item_gloves']               = { 0, 0 },
    ['item_guardian_greaves']     = { 1, 1 },
    ['item_heart']                = { 0, 0 },
    ['item_heavens_halberd']      = { 0, 0 },
    ['item_hurricane_pike']       = { 0, 0 },
    ['item_kaya']                 = { 0, 0 },
    ['item_kaya_and_sange']       = { 0, 0 },
    ['item_magic_stick']          = { 0, 0 },
    ['item_magic_wand']           = { 0, 0 },
    ['item_mantle']               = { 0, 0 },
    ['item_mekansm']              = { 0, 0 },
    ['item_moon_shard']           = { 0, 0 },
    ['item_null_talisman']        = { 0, 0 },
    ['item_nullifier']            = { 0, 0 },
    ['item_octarine_core']        = { 0, 0 },
    ['item_ogre_axe']             = { 0, 0 },
    ['item_orchid']               = { 1, 0 },
    ['item_overwhelming_blink']   = { 0, 0 },
    ['item_phylactery']           = { 0, 0 },
    ['item_pipe']                 = { 0, 0 },
    ['item_point_booster']        = { 0, 0 },
    ['item_quelling_blade']       = { 0, 0 },
    ['item_radiance']             = { 0, 0 },
    ['item_recipe_bracer']        = { 0, 0 },
    ['item_recipe_magic_wand']    = { 0, 0 },
    ['item_recipe_null_talisman'] = { 0, 0 },
    ['item_refresher']            = { 0, 0 },
    ['item_shadow_amulet']        = { 0, 0 },
    ['item_sheepstick']           = { 0, 0 },
    ['item_shivas_guard']         = { 0, 0 },
    ['item_soul_ring']            = { 0, 0 },
    ['item_spirit_vessel']        = { 1, 0 },
    ['item_staff_of_wizardry']    = { 0, 0 },
    ['item_tango']                = { 0, 0 },
    ['item_tranquil_boots']       = { 0, 0 },
    ['item_travel_boots']         = { 0, 0 },
    ['item_travel_boots_2']       = { 0, 0 },
    ['item_ultimate_scepter_2']   = { 0, 0 },
    ['item_urn_of_shadows']       = { 1, 0 },
    ['item_veil_of_discord']      = { 0, 0 },
    ['item_wind_waker']           = { 0, 0 },
}

-- The two entries that make a list an intentional Arcane buyer.  A list naming
-- either of these is excluded from the claim -- it is supposed to supply both
-- components, and it does.
local ARCANE_NAMERS = {
    ['item_arcane_boots']     = true,
    ['item_guardian_greaves'] = true,
}

-- The lists that supply BOTH components without naming an arcane item -- the
-- ones this file cannot clear.  Pinned as an exhaustive set so that if one ever
-- appears the census reports it instead of a bare pass; empty today, which is
-- the whole finding.  (Several lists supply a sobi_mask or three, from Orchid,
-- Bloodthorn, Urn and Spirit Vessel; none of them supplies a wizard_hat, and
-- that single missing component is what carries the proof for all of them.)
local NOT_PROVEN = {}

-- ---------------------------------------------------------------------------
-- helpers

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE item names are picked out: the reason blocks
--- around the gated CM build quote item names while arguing about them, and a
--- parser that reads prose reports the prose (GH #136's lesson, same shape).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Expand one entry through the composite table in aba_item.lua.  Real items
--- are leaves (the mock has no recipes), which is the granularity SUPPLY is
--- keyed on: the transitive expansion below the leaf lives in the law table.
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
    local t, n = {}, 0
    for sRole, sBody in src:gmatch("sRoleItemsBuyList%['(pos_%d)'%]%s*=%s*{(.-)\n}") do
        local tList = {}
        for s in sBody:gmatch("['\"](item_[%w_]+)['\"]") do tList[#tList + 1] = s end
        t[sRole], n = tList, n + 1
    end
    assert(n > 0, 'no sRoleItemsBuyList literal found in ' .. sPath)
    return t
end

--- Flatten a whole list and return the leaves in purchase order.
local function leaves(tList)
    local tOut = {}
    for _, sEntry in ipairs(tList) do
        for _, w in ipairs(flatten(sEntry)) do tOut[#tOut + 1] = w end
    end
    return tOut
end

--- The two counts this file is about, summed over a flattened list.
local function arcane_supply(tLeaves)
    local nSobi, nHat = 0, 0
    for _, w in ipairs(tLeaves) do
        local law = SUPPLY[w]
        if law then
            nSobi, nHat = nSobi + law[1], nHat + law[2]
        end
    end
    return nSobi, nHat
end

local function names_arcane(tLeaves)
    for _, w in ipairs(tLeaves) do
        if ARCANE_NAMERS[w] then return w end
    end
    return nil
end

--- Every (hero, role, leaves) triple in the focus five, in a stable order.
local function focus_lists()
    local tNames = {}
    for sHero in pairs(FOCUS) do tNames[#tNames + 1] = sHero end
    table.sort(tNames)
    local tOut = {}
    for _, sHero in ipairs(tNames) do
        local tRoles = buy_lists(FOCUS[sHero])
        for i = 1, 5 do
            local sRole = 'pos_' .. i
            if tRoles[sRole] then
                tOut[#tOut + 1] = {
                    hero = sHero, role = sRole, leaves = leaves(tRoles[sRole]),
                }
            end
        end
    end
    return tOut
end

local LISTS = focus_lists()

local tests = {}

-- ---------------------------------------------------------------------------
-- 0. The world this file measures in, asserted rather than assumed.

tests['[hero] the offline world still has no recipes of its own'] = function()
    assert(#GetItemComponents('item_arcane_boots') == 0,
        'GetItemComponents returns data now; SUPPLY should be rebuilt from the '
        .. 'engine instead of from dotaconstants')
    assert(Item['item_arcane_boots'] == nil and Item['item_tranquil_boots'] == nil,
        'aba_item now carries boots components offline; this file\'s leaf '
        .. 'granularity no longer matches SUPPLY')
end

tests['[hero] the census walks a populated world'] = function()
    assert(#LISTS >= 12, 'only ' .. #LISTS .. ' focus-five role lists found; '
        .. 'the census lost its population and would pass on an empty world')
    local nSeen = 0
    for _, e in ipairs(LISTS) do
        assert(#e.leaves > 0, e.hero .. ' ' .. e.role .. ' flattened to nothing')
        if names_arcane(e.leaves) then nSeen = nSeen + 1 end
    end
    assert(nSeen >= 3, 'only ' .. nSeen .. ' focus-five lists name an arcane '
        .. 'item; the exclusion arm of the claim has no domain')
end

-- ---------------------------------------------------------------------------
-- 1. Coverage.  A build change that introduces an item with no pinned row must
--    stop the census, not be counted as a zero.

tests['[hero] every item in a focus-five list has a pinned recipe row'] = function()
    local tMissing, tSeen = {}, {}
    for _, e in ipairs(LISTS) do
        for _, w in ipairs(e.leaves) do
            if SUPPLY[w] == nil and not tSeen[w] then
                tSeen[w] = true
                tMissing[#tMissing + 1] = w .. ' (' .. e.hero .. ' ' .. e.role .. ')'
            end
        end
    end
    assert(#tMissing == 0, 'no pinned sobi_mask/wizard_hat count for: '
        .. table.concat(tMissing, ', ') .. ' -- re-derive them from '
        .. 'dotaconstants before trusting the census below')
end

-- ---------------------------------------------------------------------------
-- 2. The claim.

tests['[hero] a list that does not name arcane is missing one of its parts'] = function()
    local tOffenders = {}
    for _, e in ipairs(LISTS) do
        if not names_arcane(e.leaves) then
            local nSobi, nHat = arcane_supply(e.leaves)
            if nSobi > 0 and nHat > 0 then
                tOffenders[#tOffenders + 1] = e.hero .. ' ' .. e.role
                    .. ' supplies ' .. nSobi .. ' sobi_mask / ' .. nHat
                    .. ' wizard_hat without naming an arcane item'
            end
        end
    end
    -- Reported against the pinned set rather than against zero, so that a list
    -- which legitimately gains supply can be admitted here with its reason
    -- instead of the assertion being weakened.
    local tExpected = {}
    for _, s in ipairs(NOT_PROVEN) do tExpected[s] = true end
    for _, s in ipairs(tOffenders) do
        assert(tExpected[s], s .. ' -- a focus-five role list can now hand the '
            .. 'engine every part of a pair of Arcane Boots it never asked for; '
            .. 'any candidate that changes only the boots entry of a buy list '
            .. 'is contaminated on BOTH legs until this is accounted for')
    end
    assert(#tOffenders == #NOT_PROVEN, 'NOT_PROVEN lists '
        .. #NOT_PROVEN .. ' entries but the census found ' .. #tOffenders
        .. '; a pinned exception went away and should be deleted')
end

tests['[hero] wizard_hat is the component that carries every proof'] = function()
    -- The OR above is satisfied by a different component on different lists,
    -- which would let the census stay green while its real mechanism rotted.
    -- Today ONE component does all the work: nothing in the focus five carries
    -- a wizard_hat except the two items that name Arcane Boots outright, so
    -- every cleared list is cleared by the same zero.  If that stops being
    -- true this test says so while section 2 is still green, and the sobi_mask
    -- side (which Orchid, Bloodthorn, Urn and Spirit Vessel all supply) becomes
    -- load-bearing on its own.
    local tCarry, nCleared = {}, 0
    for _, e in ipairs(LISTS) do
        if not names_arcane(e.leaves) then
            nCleared = nCleared + 1
            local _, nHat = arcane_supply(e.leaves)
            if nHat > 0 then
                tCarry[#tCarry + 1] = e.hero .. ' ' .. e.role
                    .. ' supplies ' .. nHat .. ' wizard_hat'
            end
        end
    end
    assert(nCleared >= 6, 'only ' .. nCleared .. ' focus-five lists avoid '
        .. 'naming an arcane item; this test has almost no domain left')
    assert(#tCarry == 0, table.concat(tCarry, '; ') .. ' -- the wizard_hat zero '
        .. 'no longer clears every list, so re-read section 2: it may now be '
        .. 'passing on the sobi_mask side alone for some of them')
end

tests['[hero] GH #156: CM pos_5 as shipped cannot assemble arcane boots'] = function()
    local e
    for _, x in ipairs(LISTS) do
        if x.hero == 'crystal_maiden' and x.role == 'pos_5' then e = x end
    end
    assert(e, 'crystal_maiden pos_5 not found')
    assert(not names_arcane(e.leaves),
        'CM pos_5 names an arcane item now; the gate-off leg of `cmboots` is '
        .. 'no longer the tranquil one and GH #156 has to be re-read')
    local nSobi, nHat = arcane_supply(e.leaves)
    assert(nSobi == 0 and nHat == 0, 'CM pos_5 supplies ' .. nSobi
        .. ' sobi_mask / ' .. nHat .. ' wizard_hat; the 1/103 arcane leak on '
        .. 'the non-armed leg could be accidental assembly after all')
    -- The tell from the leak frame: ring_of_basilius is sobi_mask + recipe, so
    -- zero sobi_mask is also zero legitimate reasons to own the ring.
    local bRing = false
    for _, w in ipairs(e.leaves) do
        if w == 'item_ring_of_basilius' then bRing = true end
    end
    assert(not bRing, 'CM pos_5 buys a ring_of_basilius outright now; the leak '
        .. 'frame\'s load-bearing observation is no longer anomalous')
end

-- ---------------------------------------------------------------------------
-- 3. The gate's two halves, measured against the same law.  This is what makes
--    section 2 a statement about `cmboots` and not just about one list: the
--    only thing the candidate changes is which of these two macros pos_5 opens
--    on, and they sit on opposite sides of the supply boundary.

tests['[hero] the two CM openers sit on opposite sides of the boundary'] = function()
    local tMage = leaves({ 'item_mage_outfit' })
    local tArc  = leaves({ 'item_mage_arcane_outfit' })
    local nMageSobi, nMageHat = arcane_supply(tMage)
    local nArcSobi, nArcHat   = arcane_supply(tArc)
    assert(nMageSobi == 0 and nMageHat == 0,
        'item_mage_outfit supplies ' .. nMageSobi .. '/' .. nMageHat
        .. '; the shipped opener is no longer arcane-free')
    assert(nArcSobi >= 1 and nArcHat >= 1,
        'item_mage_arcane_outfit supplies ' .. nArcSobi .. '/' .. nArcHat
        .. '; the armed opener does not carry arcane\'s parts, so this file '
        .. 'is measuring nothing')
end

tests['[hero] the pos_4 opener corroborates the external law in-repo'] = function()
    -- item_priest_outfit names item_arcane_boots outright, so its expansion
    -- MUST carry both components; if the external table disagreed with the
    -- repo, this is where the two would come apart.
    local t = leaves({ 'item_priest_outfit' })
    assert(names_arcane(t), 'item_priest_outfit no longer names arcane boots; '
        .. 'the in-repo check on the external recipe law lost its subject')
    local nSobi, nHat = arcane_supply(t)
    assert(nSobi >= 1 and nHat >= 1, 'item_priest_outfit names arcane boots but '
        .. 'the pinned law gives it ' .. nSobi .. ' sobi_mask / ' .. nHat
        .. ' wizard_hat; dotaconstants and this repo disagree')
end

-- ---------------------------------------------------------------------------
-- 4. The model itself, on a synthetic world.  On a clean tree section 2 never
--    walks its reporting branch, so without this the census could quietly stop
--    counting and still be green.

tests['[hero] the census sees supply when there is some'] = function()
    local sFake = [[
sRoleItemsBuyList['pos_9'] = {
	-- prose naming item_arcane_boots must not be read as a purchase
	"item_tranquil_boots",
	"item_urn_of_shadows",
	"item_orchid",
}
]]
    local tList = {}
    for s in strip_comments(sFake):gmatch("['\"](item_[%w_]+)['\"]") do
        tList[#tList + 1] = s
    end
    local t = leaves(tList)
    assert(names_arcane(t) == nil, 'the comment-stripping parser read an arcane '
        .. 'item out of a list that only mentions one in prose')
    local nSobi, nHat = arcane_supply(t)
    assert(nSobi == 2, 'urn + orchid supply two sobi_mask, the census counted '
        .. nSobi)
    assert(nHat == 0, 'neither urn nor orchid carries a wizard_hat, the census '
        .. 'counted ' .. nHat)
end

return tests
