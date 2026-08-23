-- [hero] GH #139 census, generalised off GH #136 -- shopping lists that hold a
-- PARTIAL count of a component its own target needs two of.  Pure build change
-- (quantities and one insertion point, no behaviour), so no gate: this ships
-- LIVE, which is why every step of the reasoning is pinned here as assertions.
--
-- THE TRAP, RESTATED GENERALLY
--
-- GH #136 found Wraith King carrying magic_stick + ONE iron branch + a wand
-- recipe in 40 games out of 40 and never finishing the wand.  The mechanism is
-- a requirement count taken on the wrong side of a filter, and nothing about it
-- is specific to branches:
--
--   1. Item.GetBasicItems (bots/FunLib/aba_item.lua) expands the target and
--      DROPS every component already owned -- except that one copy of a
--      component you hold exactly one of survives, through the sLastRepeatItem
--      dance.
--   2. bots/item_purchase_generic.lua then builds currBuyingRequiredCounts with
--      _buildRequiredCounts off that ALREADY-FILTERED list, so the requirement
--      reads 1.
--   3. _stillNeeds compares that against what is actually in the slots -- also
--      1 -- and _popIfNoLongerNeeded discards it as satisfied.
--
-- So of the doubled component only the copy you do not have goes unbought, and
-- the target never completes.  ZERO owned is safe (nothing is filtered, the
-- expansion asks for both).  TWO OR MORE owned is safe (GetItemCount > 1, so
-- sLastRepeatItem is never armed and both copies drop out, correctly).  EXACTLY
-- ONE is the broken quantity.  The generic half belongs to whoever owns
-- item_purchase_generic.lua and is reported on GH #139; this file fixes only
-- the lists that step on it.
--
-- WHERE THE LAW COMES FROM, AND WHY IT IS NOT ASSERTED FROM MEMORY
--
-- The offline world has no recipes at all: GetItemComponents returns an empty
-- table under the mock, so Item['item_soul_ring'] and friends are nil here
-- (asserted below so nobody reads this file as having checked the engine).
-- Which recipes take two of one component was therefore read out of odota's
-- dotaconstants (build/items.json, package version 10.8.0, fetched
-- 2026-08-23) -- the same source the talent re-anchor used.  Of its 122 items
-- with components, exactly seven want a doubled one; that list is LAWS below.
--
-- That source is external, so it is corroborated against this repo twice, and
-- both overlaps agree:
--
--   * magic_wand -> 2x branches: all 15 item_* composites in aba_item.lua that
--     carry item_recipe_magic_wand supply exactly two branches (the GH #136
--     anchor, re-asserted here against the law table rather than by hand).
--   * soul_ring -> 2x gauntlets: aba_item.lua's item_broken_soul_ring is
--     { ring_of_protection, recipe_soul_ring } -- it deliberately OMITS the
--     gauntlets -- and its only consumer, item_dragon_knight_outfit, supplies
--     two separate item_gauntlets entries alongside it.  An author who thought
--     a Soul Ring took one gauntlet could not have written that pair.
--
-- The other five laws have no in-repo witness because no buy list anywhere
-- supplies those components loose (see the free-at-target histograms in the
-- census test: bfury, desolator, moon_shard and skadi are always bought whole,
-- and necronomicon is not bought at all).  They are carried so the census keeps
-- watching, not because anything was found there.
--
-- WHY THE COUNT HAS TO BE TAKEN AT THE TARGET, NOT OVER THE WHOLE LIST
--
-- The first pass of this census counted each component over the entire buy list
-- and got both answers wrong, in opposite directions:
--
--   * FALSE POSITIVE -- omniknight pos_3 lists one gauntlet and a Soul Ring,
--     but also a Bracer BEFORE the Soul Ring, and a Bracer eats a gauntlet.  By
--     the time soul_ring is the target he holds zero, which is the safe count.
--     "Fixing" him to a pair would have MANUFACTURED the bug: two minus the
--     Bracer's one is exactly one.
--   * FALSE NEGATIVE -- abyssal_underlord pos_4 already started with
--     item_double_gauntlets and looked clean, but its Bracer is also ahead of
--     its Soul Ring, so the count at the target was one.  A whole-list census
--     cannot see him at all.
--
-- The census therefore walks each list in purchase order, adds components as
-- they are bought and subtracts what later composites consume, and reads the
-- count at the moment the doubled target first becomes the head.  CONSUMES is
-- the transitive component expansion of the same dotaconstants build, filtered
-- to the seven components in question; both directions of the model are pinned
-- by a synthetic self-test below, so the model cannot quietly stop working.
--
-- WHAT WAS CHANGED, AND WHAT IS NOT CLAIMED
--
--   * hero_tidehunter.lua pos_1/pos_2/pos_3: item_gauntlets ->
--     item_double_gauntlets.  He buys no Bracer in any core role, so the lone
--     gauntlet sat in a slot until the Soul Ring came up and was read as
--     complete.  Same one-word shape as the WK branch fix.
--   * hero_abyssal_underlord.lua pos_4: a third item_gauntlets inserted after
--     the Bracer and before the Soul Ring, which leaves the starting gold split
--     untouched.
--   * NOT claimed: that any of this was measured.  Neither hero is in the focus
--     five and neither has a corpus reading of his own -- there is no
--     run_001140-style inventory count behind these three files, only the
--     mechanism, which is the same mechanism that WAS observed 40 times out of
--     40 on Wraith King.  The acceptance criterion is the same as GH #136's:
--     a replay recount of games where the hero ever completes the Soul Ring.
--   * NOT claimed: that the seven laws are the current patch's.  dotaconstants
--     is a mirror and can lag; where this repo can check it, it agrees (twice,
--     above).  If the mock ever grows real recipes the boundary test below
--     fails on purpose and this table should be replaced by the engine's.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
api.install({})

local Item = dofile('bots/FunLib/aba_item.lua')

local BOTLIB = 'bots/BotLib/'
local TIDE   = BOTLIB .. 'hero_tidehunter.lua'
local UNDER  = BOTLIB .. 'hero_abyssal_underlord.lua'
local OMNI   = BOTLIB .. 'hero_omniknight.lua'

-- Recipes that want two of one component, from dotaconstants 10.8.0.
-- `eat` = every OTHER item whose transitive expansion contains that component,
-- with how many it takes; used to subtract what a list spends on the way past.
local LAWS = {
    {
        t = 'item_magic_wand', b = 'item_branches', n = 2,
        eat = { item_holy_locket = 2 },
    },
    {
        t = 'item_soul_ring', b = 'item_gauntlets', n = 2,
        eat = { item_bracer = 1 },
    },
    {
        t = 'item_bfury', b = 'item_broadsword', n = 2,
        eat = {
            item_blade_mail = 1, item_echo_sabre = 1, item_harpoon = 1,
            item_hydras_breath = 1, item_mask_of_madness = 1,
            item_specialists_array = 1,
        },
    },
    {
        t = 'item_desolator', b = 'item_mithril_hammer', n = 2,
        eat = {
            item_abyssal_blade = 1, item_basher = 1, item_black_king_bar = 1,
            item_maelstrom = 1, item_mjollnir = 1,
        },
    },
    {
        t = 'item_moon_shard', b = 'item_hyperstone', n = 2,
        eat = { item_assault = 1, item_mjollnir = 1 },
    },
    {
        t = 'item_skadi', b = 'item_ultimate_orb', n = 2,
        eat = {
            item_ethereal_blade = 1, item_helm_of_the_overlord = 1,
            item_sphere = 1,
        },
    },
    {
        t = 'item_necronomicon', b = 'item_sobi_mask', n = 2,
        eat = {
            item_arcane_boots = 1, item_bloodthorn = 2, item_devastator = 1,
            item_essence_distiller = 1, item_falcon_blade = 1,
            item_guardian_greaves = 1, item_medallion_of_courage = 1,
            item_necronomicon_2 = 2, item_necronomicon_3 = 2,
            item_oblivion_staff = 1, item_orchid = 1, item_ring_of_basilius = 1,
            item_spirit_vessel = 1, item_urn_of_shadows = 1, item_vladmir = 1,
            item_witch_blade = 1, item_wraith_pact = 1,
        },
    },
}

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE item names are picked out.  The reason blocks
--- added next to the fixed lines quote item names while describing the bug, and
--- the GH #136 census learned the hard way that a parser which reads prose
--- reports the prose.  One definition, shared by the census and its self-test.
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Expand one entry through the composite table loaded out of aba_item.lua.
--- Real items are leaves here (the mock has no recipes), which is exactly the
--- granularity wanted: the purchase layer supplies a target's own components,
--- so only what the LIST hands over is counted.
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

--- Walk one buy list in purchase order and return how many copies of law.b the
--- hero is holding at the instant law.t first becomes the target, or nil if the
--- list never asks for law.t.  bEatToo=false disables the consumption model,
--- which is only used by the self-test that proves the model matters.
local function free_at_target(tList, law, bEatToo)
    local nFree, nAt = 0, nil
    local sRecipe = law.t:gsub('^item_', 'item_recipe_')
    for _, sEntry in ipairs(tList) do
        for _, w in ipairs(flatten(sEntry)) do
            if nAt == nil and (w == law.t or w == sRecipe) then nAt = nFree end
            if w == law.b then nFree = nFree + 1 end
            local nEaten = law.eat[w]
            if nEaten and bEatToo ~= false then
                nFree = math.max(0, nFree - nEaten)
            end
        end
    end
    return nAt
end

local function hero_files()
    local p = assert(io.popen('ls ' .. BOTLIB .. 'hero_*.lua'))
    local t = {}
    for sLine in p:lines() do t[#t + 1] = sLine end
    p:close()
    assert(#t > 100, 'only ' .. #t .. ' hero files found; the census lost its '
        .. 'population and would pass on an empty world')
    return t
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The standing census.  This is the part that outlives the three edits.

tests['[hero] no buy list holds a partial count of a doubled component'] = function()
    local tOffenders, nWant, nSafeZero, nSafePair = {}, 0, 0, 0
    for _, sPath in ipairs(hero_files()) do
        local sHero = sPath:match('hero_(.+)%.lua')
        for sRole, tList in pairs(buy_lists(sPath)) do
            for _, law in ipairs(LAWS) do
                local nAt = free_at_target(tList, law)
                if nAt ~= nil then
                    nWant = nWant + 1
                    if nAt == 0 then nSafeZero = nSafeZero + 1
                    elseif nAt >= law.n then nSafePair = nSafePair + 1
                    else
                        tOffenders[#tOffenders + 1] = sHero .. ' ' .. sRole
                            .. ' holds ' .. nAt .. ' ' .. law.b .. ' at '
                            .. law.t .. ' (needs ' .. law.n .. ')'
                    end
                end
            end
        end
    end
    assert(nWant > 300, 'only ' .. nWant .. ' (list, doubled-target) pairs '
        .. 'found; the census lost most of its population')
    assert(#tOffenders == 0, 'buy list(s) reaching a doubled-component target '
        .. 'holding a PARTIAL count of that component:\n  '
        .. table.concat(tOffenders, '\n  ') .. '\nExactly one is the broken '
        .. 'quantity: _buildRequiredCounts reads the requirement off the list '
        .. 'GetBasicItems already filtered, so a partial holding is popped as '
        .. 'satisfied and the target never completes. Zero and two are both '
        .. 'fine. GH #139.')
    -- Both legal outcomes must still be populated, or the assertion above is
    -- passing on a world where nothing reaches a doubled target at all.
    assert(nSafeZero > 0 and nSafePair > 0, 'census degenerate: zero-held='
        .. nSafeZero .. ' pair-held=' .. nSafePair)
end

-- ---------------------------------------------------------------------------
-- 2. The consumption model, pinned in BOTH directions on synthetic lists.
--    Real lists cannot pin this any more -- they are fixed now -- but these two
--    shapes are exactly the ones the first pass of the census got wrong.

tests['[hero] the consumption model catches what a whole-list count misses'] = function()
    local law
    for _, l in ipairs(LAWS) do if l.t == 'item_soul_ring' then law = l end end
    assert(law, 'the soul_ring law is gone; this self-test needs rewriting')

    -- The false-positive shape (pre-fix omniknight pos_3): one gauntlet, but a
    -- Bracer eats it first, so the count at the Soul Ring is the safe zero.
    local tEaten = { 'item_gauntlets', 'item_circlet', 'item_bracer', 'item_soul_ring' }
    assert(free_at_target(tEaten, law) == 0,
        'the Bracer ahead of the Soul Ring is not being subtracted; without '
        .. 'that this census "fixes" a list that was fine and manufactures the '
        .. 'bug (two minus the Bracer is exactly one)')
    assert(free_at_target(tEaten, law, false) == 1,
        'the self-test is decoration: with consumption disabled this shape must '
        .. 'read the offending 1, or it is not testing anything')

    -- The false-negative shape (pre-fix abyssal_underlord pos_4): a pair up
    -- front, but the Bracer takes one on the way past.
    local tHidden = { 'item_double_gauntlets', 'item_bracer', 'item_soul_ring' }
    assert(free_at_target(tHidden, law) == 1,
        'a list that starts with a pair and spends one on a Bracer must read 1 '
        .. 'at the Soul Ring; this is the shape a whole-list count calls clean')
    assert(free_at_target(tHidden, law, false) == 2,
        'the self-test is decoration: with consumption disabled this shape must '
        .. 'look clean, which is the whole point of having the model')

    -- A list that never asks for the target is not an offender, it is absent.
    assert(free_at_target({ 'item_gauntlets', 'item_bracer' }, law) == nil,
        'a list with no Soul Ring is being scored anyway')
end

-- ---------------------------------------------------------------------------
-- 3. The three edits, read back out of the shipped source.

tests['[hero] tidehunter pos_1/2/3 reach the Soul Ring holding a pair'] = function()
    local law
    for _, l in ipairs(LAWS) do if l.t == 'item_soul_ring' then law = l end end
    local tLists = buy_lists(TIDE)
    for _, sRole in ipairs({ 'pos_1', 'pos_2', 'pos_3' }) do
        local tList = assert(tLists[sRole], 'no ' .. sRole .. ' in ' .. TIDE)
        local nAt = free_at_target(tList, law)
        assert(nAt ~= nil, sRole .. ' no longer buys a Soul Ring at all -- if '
            .. 'that is deliberate, delete this check, do not silence it')
        assert(nAt == 2, sRole .. ' reaches item_soul_ring holding ' .. nAt
            .. ' gauntlet(s); it must be zero or two (GH #139)')
        local nSingles = 0
        for _, sEntry in ipairs(tList) do
            if sEntry == 'item_gauntlets' then nSingles = nSingles + 1 end
        end
        assert(nSingles == 0, sRole .. ' lists a bare item_gauntlets again; use '
            .. 'item_double_gauntlets in the starting block')
    end
end

tests['[hero] tidehunter still buys no Bracer, which is why a pair is enough'] = function()
    -- The one-word fix is only correct while nothing consumes a gauntlet ahead
    -- of the Soul Ring.  Add a Bracer to any of these lists and the pair
    -- becomes exactly one again -- the abyssal_underlord shape.  This check is
    -- what makes that a loud failure instead of a silent regression.
    local tLists = buy_lists(TIDE)
    for _, sRole in ipairs({ 'pos_1', 'pos_2', 'pos_3' }) do
        for _, sEntry in ipairs(tLists[sRole]) do
            assert(sEntry ~= 'item_bracer', sRole .. ' now buys a Bracer, which '
                .. 'eats one of the two gauntlets before the Soul Ring; that '
                .. 'list needs a third gauntlet, the way abyssal_underlord '
                .. 'pos_4 does')
        end
    end
end

tests['[hero] abyssal_underlord pos_4 buys the third gauntlet after its Bracer'] = function()
    local law
    for _, l in ipairs(LAWS) do if l.t == 'item_soul_ring' then law = l end end
    local tList = assert(buy_lists(UNDER)['pos_4'], 'no pos_4 in ' .. UNDER)
    assert(free_at_target(tList, law) == 2,
        'pos_4 reaches item_soul_ring holding '
        .. tostring(free_at_target(tList, law)) .. ' gauntlet(s)')
    -- Order is load-bearing here, not decoration: bought before the Bracer, the
    -- third gauntlet is eaten too and the count at the Soul Ring is one again.
    local nBracer, nThird, nRing
    for i, sEntry in ipairs(tList) do
        if sEntry == 'item_bracer' and not nBracer then nBracer = i end
        if sEntry == 'item_gauntlets' and not nThird then nThird = i end
        if sEntry == 'item_soul_ring' and not nRing then nRing = i end
    end
    assert(nBracer and nThird and nRing, 'pos_4 lost one of Bracer / bare '
        .. 'gauntlets / Soul Ring; re-derive the count before editing this test')
    assert(nBracer < nThird and nThird < nRing,
        'pos_4 order is Bracer@' .. nBracer .. ' gauntlets@' .. nThird
        .. ' soul_ring@' .. nRing .. '; the third gauntlet has to sit between '
        .. 'the other two or it is consumed as well')
end

tests['[hero] omniknight pos_3 was left alone, and is still safe'] = function()
    -- The control arm.  He carries one gauntlet and a Soul Ring and was the
    -- first census's headline offender; his Bracer is what makes him fine.
    -- If this ever reads 1, something moved his Bracer past the Soul Ring.
    local law
    for _, l in ipairs(LAWS) do if l.t == 'item_soul_ring' then law = l end end
    local nAt = free_at_target(assert(buy_lists(OMNI)['pos_3']), law)
    assert(nAt == 0, 'omniknight pos_3 reaches the Soul Ring holding ' .. nAt
        .. ' gauntlet(s); he used to reach it holding zero, and he was '
        .. 'deliberately not touched')
end

tests['[hero] the reason blocks next to all three edits are still there'] = function()
    -- A quantity change is invisible to a future reader; the comment IS the
    -- record of why it is not a typo.  Positive needles only, each wholly on
    -- one line of its file (the Axe t15 M11 lesson: asserting that a phrase is
    -- ABSENT is decoration if it was never there, and a needle spanning a line
    -- break never matches).
    local tNeedles = {
        [TIDE] = {
            'GH #139 census: this line used to be a SINGLE',
            'ALREADY-FILTERED list (gauntlets: required 1, owned 1)',
            'Tidehunter buys no Bracer in any of his three',
            'GH #139 census, same single gauntlet as pos_3 above',
        },
        [UNDER] = {
            'purchase layer misreads as already satisfied',
            'two lines up eats one, leaving exactly ONE',
            'it needs a third gauntlet, and buying it HERE',
            'the starting gold split exactly as it was',
        },
    }
    for sPath, tList in pairs(tNeedles) do
        local src = read_file(sPath)
        for _, sNeedle in ipairs(tList) do
            assert(src:find(sNeedle, 1, true), sPath .. ' no longer contains "'
                .. sNeedle .. '". If the reasoning changed, rewrite this needle '
                .. 'with it; do not delete the reasoning and the needle together.')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 4. The two places where this repo can check the external law table.

tests['[hero] the repo agrees that a Magic Wand takes two branches'] = function()
    local law
    for _, l in ipairs(LAWS) do if l.t == 'item_magic_wand' then law = l end end
    assert(law and law.n == 2, 'the magic_wand law changed; the 15/15 outfit '
        .. 'unanimity below is what backs it')
    local nSeen, tBad = 0, {}
    for sKey, tVal in pairs(Item) do
        if type(sKey) == 'string' and sKey:match('^item_')
            and type(tVal) == 'table' and #tVal > 0 then
            local nBranches, bWand = 0, false
            for _, w in ipairs(flatten(sKey)) do
                if w == 'item_branches' then nBranches = nBranches + 1 end
                if w == 'item_magic_wand' or w == 'item_recipe_magic_wand' then
                    bWand = true
                end
            end
            if bWand then
                nSeen = nSeen + 1
                if nBranches ~= law.n then tBad[#tBad + 1] = sKey .. '=' .. nBranches end
            end
        end
    end
    assert(nSeen >= 15, 'only ' .. nSeen .. ' composites carry a wand recipe; '
        .. 'this cross-check rests on that population being large')
    assert(#tBad == 0, 'the repo and dotaconstants disagree about the wand: '
        .. table.concat(tBad, ', '))
end

tests['[hero] the repo agrees that a Soul Ring takes two gauntlets'] = function()
    -- Independent in-repo witness, and it is a sharp one: item_broken_soul_ring
    -- deliberately omits the gauntlets, and its only consumer supplies exactly
    -- two loose ones next to it.  An author who thought the recipe took one
    -- could not have written that pair.
    local tBroken = Item['item_broken_soul_ring']
    assert(type(tBroken) == 'table', 'item_broken_soul_ring is gone from '
        .. 'aba_item.lua; the soul_ring law loses its in-repo corroboration')
    for _, v in ipairs(tBroken) do
        assert(v ~= 'item_gauntlets', 'item_broken_soul_ring now supplies its '
            .. 'own gauntlets; every list that pairs it with loose gauntlets '
            .. 'is now over-buying and this census needs re-deriving')
    end
    local nGauntlets, bBroken = 0, false
    for _, w in ipairs(flatten('item_dragon_knight_outfit')) do
        if w == 'item_gauntlets' then nGauntlets = nGauntlets + 1 end
        if w == 'item_recipe_soul_ring' then bBroken = true end
    end
    assert(bBroken, 'item_dragon_knight_outfit no longer carries the soul ring '
        .. 'recipe; pick another consumer of item_broken_soul_ring or drop '
        .. 'this cross-check honestly')
    assert(nGauntlets == 2, 'item_dragon_knight_outfit supplies ' .. nGauntlets
        .. ' loose gauntlet(s) beside a soul ring recipe; two is what says the '
        .. 'recipe takes two')
end

-- ---------------------------------------------------------------------------
-- 5. Honest boundaries -- what the offline world could NOT tell us.

tests['[hero] the engine recipe channel is absent offline, as claimed'] = function()
    -- If this starts failing the mock has grown real recipes, and LAWS should
    -- be rebuilt from the engine instead of from a mirror.
    assert(#GetItemComponents('item_soul_ring') == 0,
        'GetItemComponents returns data now; rebuild LAWS from it')
    for _, law in ipairs(LAWS) do
        assert(Item[law.t] == nil or #Item[law.t] == 0, law.t .. ' is populated '
            .. 'in the composite table now; the census counts it as a leaf and '
            .. 'would double-count its components')
    end
    -- Every consumer in every eat table has to be a leaf too, for the same
    -- reason -- a populated one would be added and subtracted at once.
    for _, law in ipairs(LAWS) do
        for sConsumer in pairs(law.eat) do
            local tComp = Item[sConsumer]
            assert(type(tComp) ~= 'table' or #tComp == 0, sConsumer .. ' now '
                .. 'expands in aba_item.lua; re-derive its entry in eat')
        end
    end
end

tests['[hero] the law table is the whole doubled-recipe population, not a sample'] = function()
    -- Seven is what dotaconstants 10.8.0 reports across its 122 items with
    -- components (two Frostivus mango joke items excluded -- they cost 0 and no
    -- buy list mentions them).  Pinned so that quietly dropping a law to make
    -- the census pass is a visible edit, not an invisible one.
    assert(#LAWS == 7, 'LAWS has ' .. #LAWS .. ' entries, not the 7 read out of '
        .. 'dotaconstants; if the patch changed, say so in the header rather '
        .. 'than trimming the table')
    local tSeen = {}
    for _, law in ipairs(LAWS) do
        assert(law.n == 2, law.t .. ' wants ' .. law.n .. ' of ' .. law.b
            .. '; the census only reasons about pairs')
        assert(not tSeen[law.t], 'duplicate law for ' .. law.t)
        tSeen[law.t] = true
    end
end

tests['[hero] the census parser ignores item names quoted inside comments'] = function()
    -- Not hypothetical: the GH #136 census read the explanatory comment above
    -- its own fixed line and reported three branches where there were two.  The
    -- reason blocks added by THIS change name item_gauntlets and item_bracer
    -- while describing the bug, so the same trap is live here.
    local sFake = [[
sRoleItemsBuyList['pos_9'] = {
	-- this used to be a single "item_gauntlets" and a "item_bracer" ate it
	"item_double_gauntlets",
	"item_soul_ring",
}
]]
    local tList = {}
    for s in strip_comments(sFake):gmatch("['\"](item_[%w_]+)['\"]") do
        tList[#tList + 1] = s
    end
    local law
    for _, l in ipairs(LAWS) do if l.t == 'item_soul_ring' then law = l end end
    assert(free_at_target(tList, law) == 2, 'the comment-stripping parser read '
        .. tostring(free_at_target(tList, law)) .. ' gauntlets from a list that '
        .. 'buys two; prose is being counted as purchases again')
end

return tests
