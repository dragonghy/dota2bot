-- [owner priority P2 / strategy 2026-09-14] THE RECEIVING SIDE OF A TRANSFER.
--
-- WHAT THIS ANSWERS. tests/test_fieldsip_atom_pricing.lua (2026-09-08) priced
-- the 'fieldsip' transfer at the PREDICATE level: arming it kills 22 hold
-- frames (`fs_hold_kills`) and hands the same 22 to the supply side
-- (`fs_buy_gains`), and it called the transfer correct because owner P2's rule
-- ("买大药") lives on the supply side. That is a reading of what
-- J.ShouldFieldBuyRegen ANSWERS. It never asked whether the conjunction that
-- answer was dropped into can act on those frames -- which is this repo's own
-- criterion (tests/test_stayfield_callsite_domain.lua):
--
--     a guard's domain is its predicate INTERSECTED with the rest of the
--     conjunction it was dropped into
--
-- applied for the first time to the leg RECEIVING a transfer rather than to the
-- leg losing one.
--
-- ⭐ THE MEASUREMENT, and it is where the interesting part is. Of the 22
-- transferred frames, 15 have NO free main slot -- so the salve the transfer is
-- justified by can only be delivered into a backpack slot, which is not a slot
-- a hero can drink from and not a slot J.HasFieldRegenSource looks at (it scans
-- 0..5; the block's own slot clause counts 0..8).
--
-- ⛔⛔ AND THAT IS *NOT* A DEFECT IN THIS TREE. THE NARROWING IT SUGGESTS IS
-- GH #123's PROPOSAL, MEASURED AND REJECTED ON 2026-08-23.
-- tests/test_fieldbuy_backpack_rescuer.lua is the standing ratchet for it, and
-- its header carries the disproof: TrySwapInvItemForFlask()
-- (bots/mode_team_roam_generic.lua:2237) swaps a backpacked flask into a main
-- slot and is NOT roam-only -- it is reached through GetDesire(), which the
-- engine polls every frame for every mode of every bot. On the DRY domain that
-- rescuer cleared 13 of the 13 frames the proposal would have silenced.
--
-- ⭐⭐ SO THE ONLY THING LEFT OPEN WAS A DIFFERENT SET, AND THIS FILE CLOSES IT.
-- The 13/13 reading is on the DRY domain -- frames where the bot carries
-- nothing drinkable. The transferred set is a DIFFERENT population: those bots
-- carry a faerie fire or a tango in a MAIN slot and were judged under-supplied
-- by magnitude, not by emptiness. That set did not exist when the GH #123
-- ruling was written (the 'fieldsip' transfer is sixteen days younger), so its
-- rescue rate had never been read. Measured here, on the rescuer's own
-- predicate rather than a reimplementation of it:
--
--     no_main_slot            15
--     no_main_slot_rescuable  15      -- GetMainInvLessValItemSlot ~= -1
--     no_main_slot_stuck       0
--
-- ⇒ the GH #123 ruling EXTENDS to the transferred set, 15/15, and the
-- receiving call site is not the hole it looks like from the slot bounds alone.
-- The ratchet stays shut, and now it is shut on two populations instead of one.
--
-- ⚠️⚠️ THIS FILE IS ALSO THE RECORD OF A RE-PURCHASE. The round that wrote it
-- had already landed the narrowing as a gated id ('buymain') with a fixture and
-- a mutation stand before the suite surfaced the ratchet, which then went red
-- and sent it to the header above. The lever was reverted in the same work
-- unit. The transferable lesson is not "read the ratchets" -- it is narrower
-- and it is about ORDER:
--
--     ⭐ a defect argued from TWO READERS DISAGREEING about the same state
--     (here: three different slot bounds over one inventory) is only half an
--     argument. The other half is whether a THIRD site already reconciles them
--     -- and that half is not visible from either reader.
--
-- Both disagreeing readers are in jmz_func/aba_item; the reconciler is in a
-- mode file, reached through an engine-polling path the call graph does not
-- show. Grepping the two readers -- which the round did -- cannot find it.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.
--   * NOT that 'fieldsip' should be un-armed or that the hold should have kept
--     those frames. No id is moved and no bots/ file is touched by this unit.
--   * NOT that the delivery lands in the backpack rather than staying in the
--     stash. Both engine outcomes are outside what a frame can answer.
--   * NOT gold or stock. bot:GetGold() is 0 on every live corpus frame
--     (GH #495), so every `site_*` count is a CEILING on the receiving domain.
--   * NOT which item the rescuer would swap out. GetItemCost answers 0 offline,
--     so GetMainInvLessValItemSlot's price comparison is degenerate and it
--     returns the first switchable slot -- every XFER row reads 0 for exactly
--     that reason. Only WHETHER a switchable slot exists -- the `~= -1` the
--     rescuer itself reads -- is a real result, and it is the only one used.
--     (Same bound tests/test_fieldbuy_backpack_rescuer.lua states.)

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local LINA = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'
local ABA = 'bots/FunLib/aba_item.lua'
local IPG = 'bots/item_purchase_generic.lua'
local ROAM = 'bots/mode_team_roam_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function count_free(bot, lo, hi)
    local n = 0
    for i = lo, hi do
        if bot:GetItemInSlot(i) == nil then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- The frame owner priority P2 pins, read under the string the lab is running.

tests['[frame] P2\'s pinned frame: the hold is off and the buy side owns it'] = function()
    -- The armed member string as test_set.md line 2 carries it. Read as a SET
    -- rather than one id at a time, because the whole point is what two armed
    -- ids do to each other.
    local ARMED = {}
    for id in ('lf_rescue,ownhalf,overchase,wandbleed,blinkflee,odaoe,stayfield,'
        .. 'stayfield2,fieldbuy,pullcad,tpgap,campfarm,abilanc,bbfight,bbshort,'
        .. 'campvoid,wkqdmg,fieldsip,creepthink,lionqdmg,cmqreach,illureal,'
        .. 'slotarb,slotdust,wandbleed2,arbheart'):gmatch('[^,]+') do
        ARMED[id] = true
    end

    local J, bot = rf.load(LINA)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return ARMED[id] == true end

    assert(J.IsFieldRegenSituation(bot) == true, 'hurt, alone, unhit, off tower')
    assert(J.HasFieldRegenSource(bot) == true, 'and a faerie fire in a main slot')
    assert(J.FieldRegenSipValue(bot) == 85, 'worth 85 health')
    assert(bot:GetMaxHealth() == 1088, 'on a 1088 bar')
    assert(J.IsFieldSipEnough(bot) == false,
        '85 < 0.25 * 1088 = 272, so the magnitude test refuses')
    -- The consequence, on BOTH home routes, under the string actually armed.
    assert(J.ShouldRegenNotTpHome(bot) == false,
        "'stayfield' is armed and still answers false here -- 'fieldsip' took it")
    assert(J.ShouldRegenNotWalkHome(bot) == false, '...and the walk leg with it')
    assert(J.ShouldFieldBuyRegen(bot) == true,
        '...and the supply side is what now owns the frame')
end

tests['[frame] and it has no main slot for the salve to be delivered into'] = function()
    local J, bot = rf.load(LINA)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function() return false end
    assert(count_free(bot, 0, 5) == 0, 'six main slots full')
    assert(count_free(bot, 6, 8) == 3, 'three backpack slots free')
    -- So the block's own slot clause PERMITS the purchase on this frame...
    assert(count_free(bot, 0, 8) >= 1,
        'Item.GetEmptyInventoryAmount(bot) >= 1 holds')
    -- ...and the rescuer is what makes that safe. Driven, not reimplemented.
    local nSwap = J.Item.GetMainInvLessValItemSlot(bot)
    assert(nSwap ~= -1,
        'a switchable main-slot item exists, so TrySwapInvItemForFlask can act')
end

-- ---------------------------------------------------------------------------
-- Source tripwires: the claim is about loop bounds and one call path, so both
-- are asserted against the source rather than left to the prose above.

tests['[source] four readers of one inventory, and their bounds'] = function()
    local jmz, aba = read_file(JMZ), read_file(ABA)
    local function bound(s, fn)
        local body = s:match('function ' .. fn .. '%b()(.-)\nend')
        assert(body, fn .. ' is no longer findable')
        return body:match('for i = 0, (%d+)')
    end
    assert(bound(jmz, 'J%.HasFieldRegenSource') == '5',
        'the HOLD side scans 0..5')
    assert(bound(aba, 'Item%.GetEmptyInventoryAmount') == '8',
        "the salve block's slot clause counts 0..8 -- the disagreement")
    assert(bound(aba, 'Item%.GetEmptyNonBackpackInventoryAmount') == '5',
        'its 0..5 sibling exists, i.e. the wider one was chosen')
    assert(bound(aba, 'Item%.GetMainInvLessValItemSlot') == '5',
        'and the reconciler works in the main slots, which is why it reconciles')
end

tests['[source] the reconciler is reached from GetDesire, not from a Think'] = function()
    local roam = read_file(ROAM)
    local resc = roam:match('function TrySwapInvItemForFlask%b()(.-)\nend')
    assert(resc, 'TrySwapInvItemForFlask is no longer findable')
    assert(resc:find('J.Item.GetMainInvLessValItemSlot(bot)', 1, true),
        'it still reads the switchable-slot helper')
    assert(resc:find('lessValItem ~= -1', 1, true),
        'and still acts only when one exists -- the predicate measured below')
    -- The call path GH #123's disproof rests on. If any link breaks, the
    -- rescuer stops being whole-roster per-frame code and that ruling needs
    -- re-reading -- which is the reason this is asserted and not described.
    assert(roam:find('TrySwapInvItemForFlask()', 1, true),
        'it is still called')
    local ops = roam:match('function ItemOpsDesire%b()(.-)\nend')
    assert(ops and ops:find('TrySwapInvItemForFlask()', 1, true),
        'still called from ItemOpsDesire')
    local helper = roam:match('function GetDesireHelper%b()(.-)\nend')
    assert(helper and helper:find('ItemOpsDesire()', 1, true),
        'and ItemOpsDesire is still on the GetDesireHelper path')
end

tests['[source] the GH #123 ratchet is still shut'] = function()
    -- This file must never be read as loosening it. If the ratchet file goes
    -- away, so does the reason this file's headline is "not a defect".
    local f = io.open('tests/test_fieldbuy_backpack_rescuer.lua', 'r')
    assert(f, 'the GH #123 ratchet file is gone -- re-read this file\'s header')
    f:close()
    local ipg = read_file(IPG)
    local i = ipg:find('J.ShouldFieldBuyRegen(bot)', 1, true)
    assert(i, 'the salve block is findable')
    local block = ipg:sub(i, i + 1200)
    assert(block:find('Item.GetEmptyInventoryAmount(bot) >= 1', 1, true),
        'the block still reads all nine slots, i.e. the narrowing is NOT applied')
    assert(not block:find('GetEmptyNonBackpackInventoryAmount', 1, true),
        'and the GH #123 one-word change is still not applied')
end

-- ---------------------------------------------------------------------------
-- The corpus census, run as a subprocess (backlog 0q).

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_buysite_sweep.lua 2>&1'))
    local s = p:read('*a')
    p:close()
    assert(s:find('DONE'), 'the sweep subprocess did not finish:\n' .. s:sub(1, 2000))
    local C, G = {}, {}
    for k, v in s:gmatch('\nC ([%w_]+) (%-?%d+)') do C[k] = tonumber(v) end
    for k, v in s:gmatch('G ([%w_]+) (%-?%d+)') do G[k] = tonumber(v) end
    return C, G
end

local function must(t, k)
    assert(t[k] ~= nil, 'the sweep did not emit ' .. k
        .. ' -- an absent key must never read as a measured zero (GH #171)')
    return t[k]
end

tests['[census] the transfer, recomputed here rather than cited'] = function()
    local C, G = sweep()
    assert(must(G, 'BLOCK_FOUND') == 1, 'the sweep located the salve block')
    assert(must(G, 'SITE_GOLD') == 1 and must(G, 'SITE_STOCK') == 1,
        'the two unreadable clauses are present -- that is why these are ceilings')
    assert(must(C, 'live') > 1000, 'the whole corpus was walked, saw ' .. C.live)
    assert(must(C, 'hold_bare') == 24, 'shipped hold: 24 frames, saw ' .. C.hold_bare)
    assert(must(C, 'hold_sip') == 2, "with 'fieldsip': 2, saw " .. C.hold_sip)
    assert(C.hold_bare - C.hold_sip == must(C, 'transferred'),
        'and the difference IS the transferred set -- no frame lost between reads')
    assert(C.transferred == 22, 'which is 22, saw ' .. C.transferred)
    assert(must(C, 'IMPOSSIBLE_transfer_without_hold') == 0,
        "'fieldsip' can only NARROW the hold; a frame handed BACK would mean "
        .. "the family's direction argument is wrong")
end

tests['[census] 15 of the 22 have nowhere drinkable for the salve to land'] = function()
    local C = sweep()
    assert(must(C, 'site_main_slot') == 7,
        'only 7 of the 22 have a free MAIN slot, saw ' .. C.site_main_slot)
    assert(must(C, 'no_main_slot') == 15,
        '...so 15 do not, saw ' .. C.no_main_slot)
    assert(C.site_main_slot + C.no_main_slot == must(C, 'transferred'),
        'the two halves partition the transferred set')
    -- Earned on the affected set, never inherited from the corpus (the
    -- 'fieldsip' lesson): on the ceiling where every OTHER readable clause is
    -- already satisfied, the slot question is the one still open.
    assert(must(C, 'ceiling_readable') == 18,
        '18 frames clear the readable conjunction, saw ' .. C.ceiling_readable)
    assert(must(C, 'ceiling_readable_main_slot') == 6,
        '...of which 6 have a drinkable slot, saw ' .. C.ceiling_readable_main_slot)
end

tests['[census] ...and the shipped rescuer clears all 15 of them'] = function()
    local C, G = sweep()
    assert(must(G, 'RESCUER_FOUND') == 1, 'the rescuer is findable')
    assert(must(G, 'RESCUER_USES_SWAP_SLOT') == 1
        and must(G, 'RESCUER_TESTS_MINUS_ONE') == 1,
        'and the sweep drove its own predicate, not a reimplementation')

    local nStuck = must(C, 'no_main_slot_stuck')
    local nResc = must(C, 'no_main_slot_rescuable')
    assert(nResc + nStuck == must(C, 'no_main_slot'),
        'every no-main-slot frame is counted exactly once')
    assert(nStuck == 0,
        'THE HEADLINE: no transferred frame is stuck -- if this ever goes '
        .. 'nonzero the GH #123 ruling stops covering this population and the '
        .. 'narrowing has to be re-decided, saw ' .. nStuck .. ' stuck')
    assert(nResc == 15,
        'all 15 are rescuable, saw ' .. nResc)
    -- The whole transferred set, not only the 15: nothing here is stuck.
    assert(must(C, 'rescuable') == C.transferred,
        'and the reading holds across all 22, saw ' .. C.rescuable)
end

return tests
