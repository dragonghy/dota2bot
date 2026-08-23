-- [hero] GH #136 -- Wraith King never builds a Magic Wand, in 40 games out of
-- 40, because his pos_3 shopping list asks for ONE iron branch and the recipe
-- takes TWO.  Pure build change (a quantity, not a behaviour), so no gate: this
-- ships LIVE, which is why the reasoning is pinned here as assertions.
--
-- WHAT WAS OBSERVED (run_001140, 76 mirrored games, reported on GH #136)
--
--   * skeleton_king's median END-OF-GAME UNSPENT GOLD is 4007.  The other nine
--     heroes in the same mirrored draft sit at 366-487.  Eight to eleven times.
--   * All three legs read the same -- armed (24 ids) 3611, baseline 4344, and
--     the all-stock warm-up leg 3795 -- so this is SHIPPED behaviour, not a
--     regression from anything in the test set.  Do not go looking in the
--     armed set for a culprit.
--   * In the 40 games with a .dem, the end-of-game inventory is
--     magic_stick + ONE ironwood_branch + recipe_magic_wand, in 40 of 40, and
--     28 of those 40 never bought boots at all.  Over the whole timeline his
--     maximum simultaneous branch count is a histogram of {1: 40} -- he never
--     holds two at once for a single frame.  The other nine heroes: 40/40 hold
--     two, 40/40 finish the wand.
--
-- WHY THE PURCHASE LAYER CANNOT HEAL IT (the part the issue did not have)
--
-- It is tempting to assume the composite expansion buys whatever is missing
-- when the target reaches item_magic_wand.  It does not, and the reason is a
-- count that is taken on the wrong side of a filter:
--
--   1. Item.GetBasicItems (bots/FunLib/aba_item.lua) expands item_magic_wand
--      into its components and DROPS every one already owned -- except that a
--      component appearing twice in a row survives via the sLastRepeatItem
--      dance.  Holding magic_stick + one branch, the surviving list is
--      { item_branches, item_recipe_magic_wand }: one branch, correctly, is
--      still wanted.
--   2. bots/item_purchase_generic.lua then builds currBuyingRequiredCounts
--      with _buildRequiredCounts(currBuyingBasicItemRefList) -- off that
--      ALREADY-FILTERED list.  So required[item_branches] = 1.
--   3. _stillNeeds compares that against _countOwnedEverywhere, which counts
--      what is in the fifteen slots -- the ONE branch he already has.  1 < 1 is
--      false, so _popIfNoLongerNeeded discards it as satisfied.
--
-- The recipe -- the only component he did not already own a copy of -- is
-- therefore the one thing bought, and the wand never completes.  That is
-- exactly the inventory seen in 40 of 40 games, and it is why the fix has to be
-- in the shopping list: the layer below is structurally unable to notice.
-- The generic half of this (a requirement count taken after the filter that
-- removes what you own) is not a Wraith King problem and belongs to whoever
-- owns item_purchase_generic.lua; it is reported separately.  This file fixes
-- only the two lists that step on it.
--
-- WHY TWO BRANCHES, ANCHORED IN THIS REPO RATHER THAN ASSERTED
--
-- The offline world has no item recipes at all: GetItemComponents returns an
-- empty table under the mock, so Item['item_magic_wand'] is nil here (asserted
-- below, so that nobody later reads these tests as having checked the recipe
-- against the engine).  The anchor is the repo's own data instead, and it is
-- unanimous: of the 15 item_* composites in aba_item.lua that carry
-- item_recipe_magic_wand, ALL 15 supply exactly two branches -- fourteen
-- through item_double_branches and item_priest_outfit through two separate
-- item_branches entries.  Zero counterexamples.  (Out of frame, for the record:
-- Magic Wand 450g = Magic Stick 200 + 2x Iron Branch 50 + Recipe 150.)
--
-- THE CENSUS, AND THE INVARIANT IT ENFORCES
--
-- Exactly one branch is the broken quantity.  ZERO is fine -- owning none, the
-- expansion in step 1 keeps both and step 3 buys both.  TWO OR MORE is fine.
-- Only a partial holding trips the count.  Across all hero buy lists in
-- bots/BotLib: 367 lists want a wand, 6 supply zero branches, 361 supply two or
-- more, and before this change 2 supplied exactly one -- skeleton_king pos_3
-- (which pos_2/4/5 alias, so it is four roles) and life_stealer pos_1.  Both
-- are changed here; the census assertion below keeps it at zero.
--
-- WHAT THIS FILE DOES NOT CLAIM
--
--   * That the wand fixes Wraith King.  4007 unspent gold has a wand-shaped
--     hole in it, but the census cannot say the rest of the list flows once the
--     head unblocks; the acceptance criterion on GH #136 is a replay recount
--     ("games where WK ever holds two branches" should go 0/40 -> ~40/40, and
--     unspent gold back to the other heroes' order of magnitude).  Until that
--     comes back this is a defensible build fix with a mechanism, not a
--     measured win.
--   * Anything about life_stealer from the corpus.  He is outside the focus
--     five and was not in the run_001140 draft; he is fixed on the structural
--     identity of the list plus the 15/15 law, and that is stated in his file.
--   * That the 4 of 40 games which reached phase_boots/bracer got there by
--     escaping this trap.  They still carried the recipe and still had no wand;
--     the rebuildCount<3 / GetReducedPurchaseList path is the likely reason the
--     queue is not STRICTLY blocking, and it was not traced.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
api.install({})

local Item = dofile('bots/FunLib/aba_item.lua')

local BOTLIB = 'bots/BotLib/'
local WK     = BOTLIB .. 'hero_skeleton_king.lua'
local LS     = BOTLIB .. 'hero_life_stealer.lua'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Flatten one shopping-list entry through the REAL composite table loaded out
--- of aba_item.lua.  Leaves (no Item[] entry, or an empty one) return
--- themselves.  Depth-capped so a malformed cycle fails loudly, not forever.
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

--- Strip Lua line comments.  This has to happen BEFORE item names are picked
--- out: the explanatory comments added next to the fixed lines quote item
--- names while describing the bug, and the first run of this census counted
--- them as purchases.  A parser that reads prose reports the prose.  One
--- definition, used by the census and by its own self-test below, so that
--- removing it cannot pass.
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Every sRoleItemsBuyList['pos_N'] block in one hero source, as
--- { [role] = { entries } }.
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

--- Branches supplied, and whether a wand is wanted at all, for one buy list.
local function wand_profile(tList)
    local nBranches, bWantsWand = 0, false
    for _, sEntry in ipairs(tList) do
        for _, sBasic in ipairs(flatten(sEntry)) do
            if sBasic == 'item_branches' then nBranches = nBranches + 1 end
            if sBasic == 'item_magic_wand' or sBasic == 'item_recipe_magic_wand' then
                bWantsWand = true
            end
        end
    end
    return nBranches, bWantsWand
end

--- The verdict, factored out of the census below so that it has somewhere to
--- be tested.  Once the two lists were fixed the tree stopped containing a
--- single partial holding, so the census walks a world in which this boundary
--- can be widened without anything noticing -- the failure mode written up as
--- backlog 24 (and caught twice in test_dup_component_buylist_census.lua, whose
--- is_partial / offences_in pair this mirrors).
local function is_partial(nBranches)
    return nBranches == 1
end

--- Score one buy list and return the offence it commits, if any, as a readable
--- string.  Extracted for the same reason is_partial is: the reporting branch
--- is unreachable from real data on a clean tree, so a mutation that stopped
--- reporting would be invisible without a synthetic caller.  (Still invisible,
--- honestly: a mutation at the census's own CALL SITE -- dropping the results
--- on the floor -- which no amount of extraction can falsify from a world with
--- nothing to report.)
local function offences_in(sHero, sRole, tList)
    local nBranches, bWantsWand = wand_profile(tList)
    if bWantsWand and is_partial(nBranches) then
        return { sHero .. ' ' .. sRole .. ' supplies ' .. nBranches
            .. ' iron branch for a wand that needs two' }
    end
    return {}
end

local function hero_files()
    local p = assert(io.popen('ls ' .. BOTLIB .. 'hero_*.lua'))
    local t = {}
    for sLine in p:lines() do t[#t + 1] = sLine end
    p:close()
    assert(#t > 100, 'only ' .. #t .. ' hero files found; the census lost its population')
    return t
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The change itself, read back out of the shipped source.

tests['[hero] WK pos_3 supplies two branches for the wand, not one'] = function()
    local tLists = buy_lists(WK)
    local tPos3 = assert(tLists['pos_3'], 'no pos_3 list found in ' .. WK)
    local nBranches, bWantsWand = wand_profile(tPos3)
    assert(bWantsWand, 'pos_3 no longer wants a magic wand at all -- if that is '
        .. 'deliberate this whole file is moot and should go, not be silenced')
    assert(nBranches == 2, 'pos_3 supplies ' .. nBranches .. ' iron branch(es) '
        .. 'and Magic Wand takes two. One is the broken quantity: the purchase '
        .. 'layer counts requirements AFTER filtering out what is already owned '
        .. '(see this file\'s header), so a partial holding is read as complete '
        .. 'and only the recipe gets bought. GH #136.')

    local nSingles = 0
    for _, sEntry in ipairs(tPos3) do
        if sEntry == 'item_branches' then nSingles = nSingles + 1 end
    end
    assert(nSingles == 0 or nSingles == 2,
        'pos_3 lists item_branches ' .. nSingles .. ' time(s) directly; use '
        .. 'item_double_branches, or two entries, never one')
end

tests['[hero] WK pos_2/4/5 still alias pos_3, so the fix reaches them'] = function()
    -- The alias is what makes one line worth four roles. If someone gives a
    -- role its own list, this test stops being evidence for that role.
    local src = strip_comments(read_file(WK))
    for _, sRole in ipairs({ 'pos_2', 'pos_4', 'pos_5' }) do
        assert(src:find("sRoleItemsBuyList%['" .. sRole .. "'%]%s*=%s*sRoleItemsBuyList%['pos_3'%]"),
            sRole .. ' no longer aliases pos_3 in ' .. WK .. '; it needs its own '
            .. 'branch-count check now')
    end
end

tests['[hero] WK pos_1 is the control arm: it was always correct'] = function()
    -- pos_1 has carried item_double_branches since before this project forked,
    -- and pos_1 Wraith Kings do finish their wand. If the ruler used above
    -- disagreed with the arm that was never broken, the ruler would be wrong.
    local nBranches, bWantsWand = wand_profile(assert(buy_lists(WK)['pos_1']))
    assert(bWantsWand and nBranches == 2,
        'pos_1 reads ' .. nBranches .. ' branches / wand=' .. tostring(bWantsWand))
end

tests['[hero] life_stealer pos_1 carried the same single branch'] = function()
    local nBranches, bWantsWand = wand_profile(assert(buy_lists(LS)['pos_1']))
    assert(bWantsWand and nBranches == 2, 'life_stealer pos_1 supplies '
        .. nBranches .. ' branch(es) for a wand it wants. Same shape as WK '
        .. 'pos_3, fixed on structural identity only -- he has no corpus '
        .. 'reading of his own (GH #136).')
end

tests['[hero] the reason blocks next to both fixed lines are still there'] = function()
    -- A one-word quantity change is invisible to a future reader; the comment
    -- IS the record of why it is not a typo. Six independent positive needles,
    -- each wholly on one line of its file (the Axe t15 M11 lesson: an assertion
    -- that some phrase is ABSENT is decoration if the phrase was never there,
    -- and a needle spanning a line break never matches).
    local tNeedles = {
        [WK] = {
            'GH #136: this line used to be a SINGLE',
            'Item.GetBasicItems drops every component',
            'ALREADY-FILTERED list',
            'observed in run_001140',
            'Median unspent gold 4007',
        },
        [LS] = {
            'same shape as Wraith King',
            'No corpus reading of',
            'law that all 15 outfit macros carrying',
        },
    }
    for sPath, tList in pairs(tNeedles) do
        local src = read_file(sPath)
        for _, sNeedle in ipairs(tList) do
            assert(src:find(sNeedle, 1, true),
                sPath .. ' no longer contains "' .. sNeedle .. '". If the '
                .. 'reasoning changed, rewrite this needle with it; do not '
                .. 'delete the reasoning and the needle together.')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 2. The anchor: what the repo itself says a wand costs in branches.

tests['[hero] all 15 wand-carrying outfit macros supply exactly two branches'] = function()
    local nSeen, tBad = 0, {}
    for sKey, tVal in pairs(Item) do
        if type(sKey) == 'string' and sKey:match('^item_')
            and type(tVal) == 'table' and #tVal > 0 then
            local nBranches, bWantsWand = wand_profile({ sKey })
            if bWantsWand then
                nSeen = nSeen + 1
                if nBranches ~= 2 then
                    tBad[#tBad + 1] = sKey .. '=' .. nBranches
                end
            end
        end
    end
    assert(nSeen >= 15, 'only ' .. nSeen .. ' item_* composites carry '
        .. 'item_recipe_magic_wand; this file rests on that population being '
        .. 'large and unanimous, so a shrunk one needs re-reading, not a '
        .. 'lowered threshold')
    assert(#tBad == 0, 'the repo is no longer unanimous that a wand takes two '
        .. 'branches: ' .. table.concat(tBad, ', ') .. '. The whole argument '
        .. 'for the WK change is this unanimity -- resolve it before touching '
        .. 'the assertion.')
end

tests['[hero] item_double_branches really is two branches, not a rename'] = function()
    local tFlat = flatten('item_double_branches')
    assert(#tFlat == 2, 'item_double_branches flattens to ' .. #tFlat
        .. ' item(s): ' .. table.concat(tFlat, ','))
    assert(tFlat[1] == 'item_branches' and tFlat[2] == 'item_branches',
        'item_double_branches is ' .. table.concat(tFlat, ',')
        .. '; the WK fix assumed it was two iron branches')
end

-- ---------------------------------------------------------------------------
-- 3. The standing census -- this is the part that outlives the two edits.

tests['[hero] no hero buy list anywhere supplies exactly one branch'] = function()
    local nWand, nZero, nMany, tOne = 0, 0, 0, {}
    for _, sPath in ipairs(hero_files()) do
        local sHero = sPath:match('hero_(.+)%.lua')
        for sRole, tList in pairs(buy_lists(sPath)) do
            local nBranches, bWantsWand = wand_profile(tList)
            if bWantsWand then
                nWand = nWand + 1
                for _, sOffence in ipairs(offences_in(sHero, sRole, tList)) do
                    tOne[#tOne + 1] = sOffence
                end
                if nBranches == 0 then nZero = nZero + 1
                elseif not is_partial(nBranches) then nMany = nMany + 1 end
            end
        end
    end
    assert(nWand > 300, 'only ' .. nWand .. ' buy lists want a wand; the census '
        .. 'lost most of its population and would pass vacuously')
    assert(#tOne == 0, 'buy list(s) supplying exactly one iron branch for a '
        .. 'magic wand: ' .. table.concat(tOne, ', ') .. '. Exactly one is the '
        .. 'broken quantity -- zero is fine (nothing owned, the expansion buys '
        .. 'both) and two or more is fine; only a partial holding is read as '
        .. 'complete by _stillNeeds. GH #136.')
    -- The two legal outcomes must both still be populated, or the assertion
    -- above is passing on an empty world.
    assert(nZero > 0 and nMany > 0,
        'census degenerate: zero-branch lists=' .. nZero .. ' two-plus=' .. nMany)
end

tests['[hero] one is the broken quantity; zero and two are not'] = function()
    -- The census above can only exercise the verdicts a clean tree produces,
    -- and a clean tree produces none of the interesting one. The boundary lives
    -- here instead, so widening it is a failing edit rather than a silent one.
    assert(is_partial(1), 'supplying exactly one branch is the broken case: '
        .. 'GetBasicItems keeps one copy alive, _buildRequiredCounts reads the '
        .. 'requirement off that filtered list, and _stillNeeds pops it as '
        .. 'satisfied. GH #136.')
    assert(not is_partial(0), 'supplying none is safe -- nothing is filtered '
        .. 'out, so the expansion asks for both copies')
    assert(not is_partial(2), 'supplying the pair is safe')
    assert(not is_partial(3), 'supplying more than the pair is safe too')
end

tests['[hero] the census can still name an offender when there is one'] = function()
    -- The pre-fix Wraith King pos_3 shape, which is the one thing the census
    -- can no longer meet on the real tree. Without this caller, a mutation that
    -- stopped appending to the offence list passes on every hero file.
    local tHit = offences_in('synthetic', 'pos_9', {
        'item_tango', 'item_quelling_blade', 'item_gauntlets',
        'item_branches', 'item_magic_stick', 'item_magic_wand',
    })
    assert(#tHit == 1, 'the census found ' .. #tHit .. ' offence(s) in the '
        .. 'exact list that was stuck in 40 games of 40; it must find one, or '
        .. 'it is reporting nothing on the real tree for reasons that have '
        .. 'nothing to do with the real tree')
    assert(tHit[1]:find('synthetic pos_9', 1, true),
        'the offence does not name the list it came from: ' .. tHit[1])

    -- Two near misses, one on each side of the boundary, through the same
    -- entry point: the fixed shape, and a list with a lone branch and no wand.
    assert(#offences_in('synthetic', 'pos_9', {
        'item_tango', 'item_double_branches', 'item_magic_stick',
        'item_magic_wand',
    }) == 0, 'the fixed shape is still reported as an offence')
    assert(#offences_in('synthetic', 'pos_9', {
        'item_tango', 'item_branches', 'item_quelling_blade',
    }) == 0, 'a lone branch with no wand anywhere is not an offence -- nothing '
        .. 'ever puts a doubled recipe at the head of that queue')
end

-- ---------------------------------------------------------------------------
-- 4. Honest boundaries -- what the offline world could NOT tell us.

tests['[hero] the engine recipe channel is absent offline, as claimed'] = function()
    -- If this ever starts failing, the mock has grown real recipes and the
    -- 15/15 outfit law stops being the anchor: read Item['item_magic_wand']
    -- directly instead, and re-derive the branch count from the engine.
    assert(#GetItemComponents('item_magic_wand') == 0,
        'GetItemComponents now returns data; this file\'s anchor should be '
        .. 'upgraded from the outfit census to the recipe itself')
    assert(Item['item_magic_wand'] == nil,
        'Item[\'item_magic_wand\'] is populated now -- see above')
end

tests['[hero] the census parser ignores item names quoted inside comments'] = function()
    -- Not hypothetical: the first run of this census read the explanatory
    -- comment added above the fixed line -- which quotes "item_branches" while
    -- describing the bug -- and reported skeleton_king pos_3 at three branches.
    local sFake = [[
sRoleItemsBuyList['pos_9'] = {
	-- this used to be a single "item_branches" and that was the bug
	"item_double_branches",
	"item_magic_wand",
}
]]
    local tList = {}
    for s in strip_comments(sFake):gmatch("['\"](item_[%w_]+)['\"]") do
        tList[#tList + 1] = s
    end
    local nBranches, bWantsWand = wand_profile(tList)
    assert(bWantsWand and nBranches == 2,
        'the comment-stripping parser read ' .. nBranches .. ' branches from a '
        .. 'list that buys two; prose is being counted as purchases again')
end

return tests
