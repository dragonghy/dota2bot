-- `ITEMID`: every `item_*` literal in bots/ names an item the patch ships.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- An item name reaches the engine through two doors and both answer a wrong
-- name with silence:
--
--   * `bot:FindItemSlot(name)` / `Item.HasItem(bot, name)` answer -1 / false for
--     a name no item carries -- identical to "the hero does not own it".  So
--     `not HasItem(bot, 'item_typo')` is a permanently TRUE conjunct.
--   * a buy-list entry that is neither a real item nor an `aba_item.lua` macro
--     is forwarded verbatim by `Item.GetBasicItems` (its `Item[v] == nil`
--     branch) into the purchase layer as if it were a basic item.
--
-- Items really do get renamed: Gleipnir's internal name is `item_gungir`, and
-- `bots/FunLib/aba_site.lua:1522` asks for `item_gleipnir`.  Nothing in the tree
-- said so until this census ran (`print()` never reaches the server console and
-- the engine error handler is broken -- AGENTS.md).
--
-- WHAT IT PINS
-- ------------
-- 1. THE GROUND TRUTH IS REAL.  `tests/mock/item_names.lua` is a frozen read of
--    the patch's items.txt.  A snapshot that lost half its names would turn
--    every correct name into a false MISSING, so its size and a hand-picked
--    spread of names are asserted before anything is judged against it.
-- 2. THE CRITERION AND THE REPORT, ON SYNTHETIC INPUT.  On a tree whose focus
--    files are clean, a census exercises neither branch on real data, and a
--    mutation that loosens the criterion or stops reporting escapes green
--    (charter §24).  Both halves are functions here and both are fed an
--    offender AND a near miss.
--    Per §24's correction: does the tree carry a legal-but-adjacent shape that a
--    LOOSENED criterion would swallow?  Yes -- the four PROBE sites below are
--    `string.find` substrings (`item_recipe_`, `item_double`), deliberately not
--    whole names, and any criterion that stopped separating them would report
--    them as defects.  So both directions have live counterexamples here; the
--    synthetic pair is still fed, because one filter edit removes them.
-- 3. A RATCHET.  The registered sites are frozen by (kind, name, site).  A new
--    unknown name turns this red instead of joining the silence.  Repairs are
--    welcome -- they edit the baseline DOWN.
--
-- WHAT IS NOT CLAIMED
-- -------------------
--   * Silence is not a clean bill of health.  A name assembled at runtime
--     (`'item_' .. sTail`) is invisible here by construction.
--   * A proven-dead name in a file nothing `require`s costs nothing.  Two of
--     the six LOOKUP sites are in `bots/FunLib/advanced_item_strategy.lua`,
--     which no file in the tree requires; that is recorded per site, and this
--     test does not build a call graph to check it.
--   * Neutral-item tiers live in their own KV and are NOT in the snapshot, so
--     `item_enhancement` is registered as a PROBE, not judged as a name.

package.path = package.path .. ';./tests/?.lua;./tests/mock/?.lua'

local ItemNames = dofile('tests/mock/item_names.lua')

local tests = {}
local function check(bCond, sMsg) assert(bCond, sMsg) end

local function read_file(sPath)
    local f = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = f:read('*a')
    f:close()
    return s
end

local nNames = 0
for _ in pairs(ItemNames.NAMES) do nNames = nNames + 1 end

tests['1. the frozen ground truth is a real item list'] = function()
check(nNames >= 400,
    'the frozen item list holds only ' .. nNames .. ' names; a short ground '
    .. 'truth turns every correct name into a false MISSING')

-- A spread, not a sample: one basic, one composite, one neutral-shop staple, one
-- item added late in the patch cycle, one whose name differs from its display
-- name (the whole reason this axis exists).
for _, sName in ipairs({ 'item_tango', 'item_black_king_bar', 'item_aghanims_shard',
                         'item_crellas_crozier', 'item_gungir', 'item_ancient_janggo' }) do
    check(ItemNames.NAMES[sName] == true,
        'the frozen item list is missing ' .. sName .. ' -- regenerate it with '
        .. 'tools/agent/item_name_census.py --snapshot')
end
check(ItemNames.NAMES['item_gleipnir'] == nil,
    'the frozen list contains item_gleipnir; the finding this file registers '
    .. 'rests on that name NOT being an item (the block is keyed item_gungir)')
end

--------------------------------------------------------------------------------
-- 2. The criterion and the report, as functions
--------------------------------------------------------------------------------

--- Every `Item['x'] = ...` key in aba_item.lua: a buy-list entry matching one of
--- these never reaches the engine under that name.  Comments are stripped first
--- -- aba_item.lua carries commented-OUT list entries (`-- "item_shadow_amulet",`
--- at :98) and counting those would register names nothing reads.
local function macros_in(sSrc)
    local tMacro = {}
    for sLine in (sSrc .. '\n'):gmatch('(.-)\n') do
        local sCode = sLine:gsub('%-%-.*$', '')
        for sKey in sCode:gmatch("Item%[%s*['\"]([A-Za-z0-9_]+)['\"]%s*%]%s*=") do
            tMacro[sKey] = true
        end
    end
    return tMacro
end

--- THE CRITERION.  true when the engine (or aba_item.lua) answers to this name.
local function is_known(sName, tMacro)
    if ItemNames.NAMES[sName] or tMacro[sName] then return true end
    local sResult = sName:match('^item_recipe_(.+)$')
    if sResult then return ItemNames.NAMES['item_' .. sResult] == true end
    return false
end

--- THE REPORT.  Returns a list of { kind, name, site }.  `kind` separates a
--- LOOKUP (an exact-name question the engine will answer) from a PROBE (a
--- `string.find` substring, which is not a name at all).
local function offences_in(sPath, sSrc, tMacro)
    local tOut = {}
    local nLine = 0
    for sLine in (sSrc .. '\n'):gmatch('(.-)\n') do
        nLine = nLine + 1
        local sCode = sLine:gsub('%-%-.*$', '')
        local bProbe = sCode:match('string%.[fmg]%a*%s*%(') ~= nil
                    or sCode:match('[:%.]find%s*%(') ~= nil
                    or sCode:match('[:%.]match%s*%(') ~= nil
        for sName in sCode:gmatch("['\"](item_[a-z0-9_]+)['\"]") do
            if not is_known(sName, tMacro) then
                tOut[#tOut + 1] = {
                    bProbe and 'PROBE' or 'LOOKUP', sName, sPath .. ':' .. nLine }
            end
        end
    end
    return tOut
end

-- Synthetic macros: the registration counts, the commented-out one does not.
local tSynthMacro = macros_in(
    "Item['item_mage_outfit'] = { 'item_tranquil_boots' }\n" ..
    "-- Item['item_ghost_outfit'] = { 'x' }\n")

tests['2a. the macro reader, on synthetic input'] = function()
check(tSynthMacro['item_mage_outfit'] == true, 'macro reader missed a live registration')
check(tSynthMacro['item_ghost_outfit'] == nil,
    'macro reader counted a commented-out registration -- a name nothing reads')
end

-- Criterion, both directions, offender and near misses.
tests['2b. the criterion, both directions'] = function()
check(is_known('item_gungir', tSynthMacro), 'a shipped item read as unknown')
check(is_known('item_mage_outfit', tSynthMacro), 'a macro read as unknown')
check(is_known('item_recipe_black_king_bar', tSynthMacro), 'a live recipe read as unknown')
check(not is_known('item_gleipnir', tSynthMacro), 'a renamed item read as known')
check(not is_known('item_recipe_gleipnir', tSynthMacro),
    'a recipe for an item that does not exist read as known')
end

-- Report, on a synthetic file: the lookup is found, the commented-out sibling is
-- not, and the substring probe is classified apart instead of being called a
-- missing item.
tests['2c. the report, on a synthetic file'] = function()
local tGot = offences_in('synthetic.lua',
    "local a = HasItem(bot, 'item_gungir')\n" ..
    "-- local b = HasItem(bot, 'item_gleipnir')\n" ..
    "local c = HasItem(bot, 'item_gleipnir')\n" ..
    "if string.find(n, 'item_gleipnir') then end\n", tSynthMacro)
check(#tGot == 2, 'report returned ' .. #tGot .. ' offence(s), expected 2')
if #tGot == 2 then
    check(tGot[1][1] == 'LOOKUP' and tGot[1][3] == 'synthetic.lua:3',
        'first offence was ' .. tGot[1][1] .. ' at ' .. tGot[1][3])
    check(tGot[2][1] == 'PROBE' and tGot[2][3] == 'synthetic.lua:4',
        'second offence was ' .. tGot[2][1] .. ' at ' .. tGot[2][3])
end
end

--------------------------------------------------------------------------------
-- 3. The ratchet, on the real tree
--------------------------------------------------------------------------------

-- Frozen 2026-08-25.  Each line is (kind, name, site) plus what it is.
local tRegistered = {
    -- LOOKUP: an exact-name question the engine answers with silence.
    ['LOOKUP item_gleipnir bots/FunLib/aba_site.lua:1522'] =
        'Gleipnir ships as item_gungir.  `not HasItem(bot, "item_gleipnir")` is '
        .. 'therefore permanently true, so that branch returns true whenever '
        .. 'net worth < 18000 regardless of the item.  aba_site IS required '
        .. '(jmz_func.lua:29), so this one is live.',
    ['LOOKUP item_drum_of_endurance bots/FunLib/aba_item.lua:449'] =
        'Drums ship as item_ancient_janggo (already registered by '
        .. 'tools/agent/sell_pair_census.py as Q1-NOT-AN-ITEM); the '
        .. '(item_boots_of_bearing, item_drum_of_endurance) sell pair can never '
        .. 'fire.  Costless in practice: boots_of_bearing CONSUMES the drums.',
    ['LOOKUP item_great_scepter bots/BotLib/hero_tidehunter.lua:91'] =
        'a buy-list entry no item answers to; Item.GetBasicItems forwards it '
        .. 'verbatim to the purchase layer.  Non-focus hero -- reported, not '
        .. 'fixed, per the GH #168 convention.',
    -- [strategy 20260825T23:xxZ] Re-keyed 6774 -> 6781, and :1013 -> :1020 in
    -- the note.  NOT a repair of this census and NOT a loosening: same kind,
    -- same name, same site -- only the line number moved, by exactly the +7
    -- that commit c48dc11b (strategy 19:26Z, the lf_salve SetUseItem fix) added
    -- to this file at :993, i.e. ABOVE both numbers.  The baseline landed at
    -- 19:55Z carrying 6774, which was already one commit stale when it was
    -- written, so this ratchet was RED on main from the moment it landed.
    -- Charter 0LN2's fourth example and a new sub-shape: the first three had a
    -- pin PUSHED OUT by a later edit; this one was WRITTEN stale against a
    -- checkout behind main (GH #161's gate-slower-than-main race, GH #171's
    -- red-trunk blindness).  Verified per commit:
    --   089bee2a -> 6774 | c48dc11b (+7) -> 6781 | 1fcfcd83 -> 6781 | HEAD -> 6781
    -- 6796 -> 6808 (strategy 2026-08-27T0x:xxZ, gated `salveyield`, GH #237):
    -- the salve consider's two halves were re-ordered so the self branch could
    -- be asked what it pre-empts (the ally scan hoisted above it, plus the
    -- guard's comment and call) -- NINTH instance of the shape at :198, and the
    -- FIFTH consecutive strategy round to move this same pin.  This is also the
    -- largest single move of the five (+12 against +2/+3/+4/+6): the shape is
    -- not merely recurring, its amplitude is growing, because each round's fix
    -- lands in the same forty lines.  Re-anchored, not relaxed; probe and
    -- lookup textually unchanged, and found once more by the Lua leg on the
    -- working tree, before the push.
    -- 6794 -> 6796 (strategy 2026-08-26T2x:xxZ, gated `salveally`, GH #231): the
    -- salve consider's ALLY branch traded its literal for a one-line comment and
    -- a delegating call -- EIGHTH instance of the shape at :198, and the FOURTH
    -- consecutive strategy round to move this same pin.  Re-anchored, not
    -- relaxed; probe and lookup textually unchanged, and found once more by the
    -- selfcheck's Lua leg on the working tree, before the push.
    -- 6791 -> 6794 (strategy 2026-08-26T2x:xxZ, gated `salvepool`, GH #227): the
    -- salve consider's self-use branch grew a comment and a local three screens
    -- above this pin -- SEVENTH instance of the shape at :198, and the THIRD
    -- consecutive strategy round to move this same pin.  Three lines, three
    -- rounds, one registration key: the shape at :198 is not getting rarer, it
    -- is getting more frequent, and that is the argument GH #221 is about.
    -- Re-anchored, not relaxed; the probe and the lookup are textually
    -- unchanged, and this too was found by the selfcheck's Lua leg on the
    -- working tree, before the push.
    -- 6785 -> 6791 (strategy 2026-08-26T1x:xxZ, gated `bbshort`, GH #222): the
    -- 6-line comment above the buyback ladder's `< 60` floor sits above BOTH
    -- pins in this file again -- SIXTH instance of the shape at :198, and the
    -- second time the SAME pair moved together.  Re-anchored, not relaxed; the
    -- probe and the lookup are textually unchanged.  This round found it the way
    -- the note below says it should be found: the selfcheck's Lua leg, on the
    -- working tree, before the push -- so the pin was never red on main.
    -- 6781 -> 6785 (director 2026-08-26T15:5xZ): 71b53d58 (strategy 14:28Z,
    -- gated `bbfight`, GH #215) added 4 lines above BOTH pins in this file.  One
    -- commit, two red keys, and this one only became visible after the other was
    -- fixed -- the check errors on the FIRST new name it meets, so a drifted pin
    -- hides every drifted pin behind it.  That is why the count of reds a run
    -- reports is a LOWER BOUND for this file, not its content.
    -- 6808 -> 6849 (director 2026-08-28T22:xxZ, GH #286, UNGATED): the nil-head
    -- drain repair -- a CompactSkillList helper near the top of the file plus its
    -- call site above the `#sAbilityLevelUpList >= 1` gate, +41 lines, all of it
    -- ABOVE this pin.  TENTH instance of the shape at :198 and the first one
    -- moved by the director rather than the strategy desk, which is the part
    -- worth noting: the note above reads the recurrence as "each round's fix
    -- lands in the same forty lines", and this landing is nowhere near those
    -- forty lines -- it is at the top of the file.  So the shape is not about a
    -- hot region, it is about pinning a LINE NUMBER in a file anyone may edit.
    -- Re-anchored, not relaxed.
    -- 6849 -> 6863 (strategy 2026-08-29T04:2xZ, GH #294): a 14-line COMMENT
    -- above the '撤退:1' branch, recording that the promoted `tphome` veto can
    -- only move [0.18, 0.19) at that call site.  ELEVENTH instance of the shape
    -- at :198, and the cheapest one yet to produce: the edit changed no code at
    -- all.  That is the sharpest reading available of what this pin costs --
    -- a pure comment, in a file 6,800 lines above the pin, is enough to turn a
    -- ratchet red.  Re-anchored, not relaxed; the probe and the lookup are
    -- textually unchanged.  And the honest half: unlike the 15:5xZ landing four
    -- notes above, this one WAS red on main for the length of one commit -- not
    -- because a door was missing but because the author did not walk through
    -- it.  This file is tagged, so the selfcheck's fast Lua leg covers it; that
    -- leg was run at the START of the work unit (clean) and NOT re-run after the
    -- comment was written.  A start-of-unit selfcheck certifies the tree you
    -- arrived on, never the tree you push.
    -- 6863 -> 6876 (strategy 2026-09-02T00:xxZ, GH #406 follow-up): the
    -- 13-line ClosestDustCarrier wrapper -- the single gate-resolution site for
    -- soak candidate 'slotdust' -- landed at :51, 6,800 lines above this pin.
    -- TWELFTH instance of the shape at :198, and the second in a row produced
    -- by a strategy round that had no reason to read this file: the fix's own
    -- eight targeted test families were all green, and only the unfiltered run
    -- found this.  Picking tests by SUBJECT can never pick this one, because
    -- its relationship to the edited file is a line number, not a topic.
    -- Re-anchored, not relaxed; the probe and the lookup are textually unchanged.
    ['LOOKUP item_new bots/ability_item_usage_generic.lua:6876'] =
        'the upstream template stub (its comment is literally "--新物品").  '
        .. 'X.ConsiderItemDesire is indexed by the exact item name at :1020, so '
        .. 'the handler is unreachable -- by design, not by accident.',
    ['LOOKUP item_pipe_of_insight bots/FunLib/advanced_item_strategy.lua:314'] =
        'Pipe ships as item_pipe.  No file in the tree requires '
        .. 'advanced_item_strategy.lua, so the cost today is zero.',
    ['LOOKUP item_battlefury bots/FunLib/advanced_item_strategy.lua:315'] =
        'Battle Fury ships as item_bfury.  Same dead file as the line above.',
    -- PROBE: a string.find substring, not a name.  Registered so that a future
    -- edit turning one into a real lookup shows up as a NEW site.
    ['PROBE item_enhancement bots/Buff/NeutralItems.lua:345'] =
        'neutral-item tier probe; neutral items live in their own KV, which the '
        .. 'snapshot deliberately does not carry.',
    ['PROBE item_enhancement bots/FretBots/NeutralItems.lua:106'] =
        'the FretBots copy of the line above (AGENTS.md: always both files).',
    ['PROBE item_double bots/FunLib/aba_item.lua:1239'] =
        'matches the item_double_* macro family by prefix.',
    -- 1049 -> 1053 (director 2026-08-26T15:5xZ): 1039cad8 (strategy 10:34Z,
    -- gated `bbrespawn`, GH #208).  A DIFFERENT commit from the two pins below,
    -- five hours earlier -- so this file was already red on 224fa713, the tree
    -- GH #216 measured, and stayed red across four more landings without any
    -- gate saying so.  Three pins, two commits, one afternoon.
    ['PROBE item_recipe bots/mode_retreat_generic.lua:1053'] =
        'matches every recipe by prefix.',
    -- 807 -> 813 (strategy 2026-08-26T1x:xxZ, gated `bbshort`, GH #222): same
    -- 6-line comment as the lookup pin above; see that note.
    -- 803 -> 807 (director 2026-08-26T15:5xZ).  FIFTH instance of the shape the
    -- note at :198 names: 71b53d58 (strategy 14:28Z, gated `bbfight`, GH #215)
    -- added 4 lines ABOVE this site, and the pin moved with the file while the
    -- key did not.  The probe itself is unchanged -- same one `string.find`, same
    -- prefix, same file; only its line number moved.  Found by the full suite,
    -- which was the only thing running this file: until the same round tagged
    -- 3b below, it carried no discovery tag and the selfcheck's Lua leg never
    -- picked it up (GH #216).
    -- 813 -> 854 (director 2026-08-28T22:xxZ, GH #286): same +41 as the lookup
    -- pin above; see that note.
    -- 854 -> 867 (strategy 2026-09-02T00:xxZ): same +13 as the lookup pin
    -- above; see that note.
    ['PROBE item_recipe_ bots/ability_item_usage_generic.lua:867'] =
        'matches every recipe by prefix.',
}

local function lua_files()
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    local t = {}
    for sLine in p:lines() do t[#t + 1] = sLine end
    p:close()
    return t
end

local tFiles = lua_files()
local tMacro = macros_in(read_file('bots/FunLib/aba_item.lua'))
local nMacro = 0
for _ in pairs(tMacro) do nMacro = nMacro + 1 end

tests['3a. the scan has something to scan'] = function()
check(#tFiles > 100, 'only ' .. #tFiles .. ' lua files found under bots/ -- the '
    .. 'scan found nothing to scan, which reads exactly like a clean tree')
check(nMacro >= 100, 'aba_item.lua yielded only ' .. nMacro .. ' macro keys; a '
    .. 'macro reader that lost its keys reports live buy lists as broken')
end

-- [director 20260826, GH #216] REPORTS EVERY DISCREPANCY, NOT THE FIRST ONE.
-- Both loops used to `assert` inside the loop, so the run died on the first key
-- and each repair bought exactly one more line of information: the 08-26 14:28Z
-- shift moved THREE pins, and finding that out took three full edit-and-rerun
-- cycles because pins two and three were hidden behind pin one.  Same defect
-- this round fixed in the runner (a failure you cannot see until the slow thing
-- ahead of it finishes), one level down.
--
-- Reporting the two halves TOGETHER is the other half of the fix, and it is what
-- turns the message into a diagnosis.  A pin whose line moved shows up twice --
-- once as a NEW key at the new line, once as a VANISHED key at the old one --
-- and neither half says "this moved" on its own.  Side by side they do, so the
-- MOVED section below pairs them up and prints the two line numbers.
-- TAGGED `[ratchet]` 2026-08-26 (director, GH #216) so the 开工 selfcheck's Lua
-- leg discovers it.  It costs 0.64s and it is the file that sat red on main for
-- ~3h on 08-25 and >5h on 08-26 with no gate saying so; the leg exists for
-- exactly this class and had never covered it.
--
-- Found by accident, and the accident is worth recording: the leg's discovery is
-- `grep -l '\[detector\]\|\[ratchet\]'` over RAW FILE CONTENT, so merely writing
-- the tag inside a COMMENT enrolls the file.  The note above, which said this
-- file carried no tag, enrolled it by saying so -- 8 files became 9 and the
-- sentence made itself false.  The comment was reworded and the tag put here, on
-- the test NAME, which is the documented mechanism and the one
-- tests/test_selfcheck_lua_leg.py's coverage check reads.  That discovery cannot
-- tell a tag from a mention is a separate defect and is handed off, not patched
-- here.
tests['[ratchet] 3b. the tree\'s unknown item names are exactly the registered ones'] = function()
local tSeen, tNew, tGone = {}, {}, {}
for _, sPath in ipairs(tFiles) do
    for _, tHit in ipairs(offences_in(sPath, read_file(sPath), tMacro)) do
        local sKey = tHit[1] .. ' ' .. tHit[2] .. ' ' .. tHit[3]
        tSeen[sKey] = true
        if tRegistered[sKey] == nil then tNew[#tNew + 1] = sKey end
    end
end

    for sKey in pairs(tRegistered) do
        if tSeen[sKey] ~= true then tGone[#tGone + 1] = sKey end
    end
    table.sort(tNew)
    table.sort(tGone)

    -- `KIND name path:line` -> `KIND name path` (the part a line shift leaves
    -- alone), so the two halves of one moved pin can find each other.
    local function stem(sKey) return (sKey:gsub(':%d+$', '')) end
    local tMoved, tNewOnly, tGoneOnly, tStem = {}, {}, {}, {}
    for _, sKey in ipairs(tGone) do tStem[stem(sKey)] = sKey end
    for _, sKey in ipairs(tNew) do
        local sOld = tStem[stem(sKey)]
        if sOld then
            tMoved[#tMoved + 1] = sOld .. '  ->  ' .. sKey:match(':(%d+)$')
            tStem[stem(sKey)] = nil
        else
            tNewOnly[#tNewOnly + 1] = sKey
        end
    end
    for _, sKey in ipairs(tGone) do
        if tStem[stem(sKey)] == sKey then tGoneOnly[#tGoneOnly + 1] = sKey end
    end

    local tMsg = {}
    if #tMoved > 0 then
        tMsg[#tMsg + 1] = #tMoved .. ' MOVED (same kind+name+file, new line -- '
            .. 'an edit above the site pushed the pin out; update the line '
            .. 'number here):\n  ' .. table.concat(tMoved, '\n  ')
    end
    if #tNewOnly > 0 then
        tMsg[#tMsg + 1] = #tNewOnly .. ' NEW unknown item name(s).  Either the '
            .. 'name is a typo (fix it) or the patch renamed the item (fix the '
            .. 'name and regenerate tests/mock/item_names.lua):\n  '
            .. table.concat(tNewOnly, '\n  ')
    end
    if #tGoneOnly > 0 then
        tMsg[#tMsg + 1] = #tGoneOnly .. ' registered site(s) no longer present.  '
            .. 'If repaired, delete the line here:\n  '
            .. table.concat(tGoneOnly, '\n  ')
    end
    check(#tMsg == 0, table.concat(tMsg, '\n'))
end

return tests
