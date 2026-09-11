-- [bagtango / owner priority P2, GH #734] The backpack rescuer set, and the four
-- regen sources that were never given one.
--
-- THE CLAIM, stated as a set difference and asserted off the SOURCE below so it
-- cannot rot:
--   * J.HasFieldRegenSource (jmz_func) accepts FIVE things as field supply --
--     item_flask, item_tango, item_tango_single, item_faerie_fire, and a charged
--     item_bottle.
--   * mode_team_roam_generic.lua ships SIX backpack rescuers -- clarity, flask,
--     smoke, moonshard, cheese, refresher_shard.
--   * The intersection has exactly ONE member: the flask.
-- So a tango or a faerie fire delivered into slots 6-8 is stuck there for the
-- rest of the game. Not for 6.4 seconds; permanently -- nothing in the tree ever
-- swaps it out, and a backpacked item cannot be activated. For those items the
-- stuck rate is not a measured residual, it is 100% BY CONSTRUCTION, which is
-- why this is the piece taken first.
--
-- ⭐ WHAT THIS FILE IS NOT, and it is the load-bearing distinction. GH #734 also
-- proposes narrowing the fieldbuy purchase gate to
-- Item.GetEmptyNonBackpackInventoryAmount. That is GH #123's proposal, and it was
-- measured and REFUTED on this corpus -- tests/test_fieldbuy_backpack_rescuer.lua
-- prices it at 46.4% of the dry domain silenced against a rescuer that would have
-- worked on 13 of 13. This file does not re-open that trade and must never be
-- read as doing so: it lands on the OTHER side of it, making more backpacked
-- supply reachable instead of buying less of it, so it cannot reproduce the loss
-- that refutation priced. The refutation's closing line -- "the purchase gate is
-- not its cause; finding the cause is a separate unit" -- is the pointer this
-- file picks up.
--
-- ⚠️ HONEST BOUND, stated before any assertion. This does NOT claim to be all of
-- #734's 18.0% STUCK. #734's own three frame examples are all FLASKS, which
-- already have a rescuer, so part of that population has a cause still unfound.
-- Two hypotheses are registered in this round's report and neither is tested
-- here, because both need a corpus read this site cannot do:
--   (H1) FindItemSlot is an existence question answered by the FIRST match, so a
--        bot holding a usable main-slot salve AND a second one in the bag reads
--        as "stuck" to a slot-scanning detector while being perfectly fine --
--        i.e. part of the 18.0% may be a detector artefact, not a defect.
--   (H2) ItemOpsDesire `return`s early on a dropped-item bid ABOVE all six
--        rescuer calls, so a frame with loot on the ground skips every rescue.
-- Neither is this id's claim. This id's claim is the set difference above.
--
-- ⚠️ The trap this file inherits from its sibling, restated because it is the
-- one that silently turns a rescuer test into a zero: on a fixture an unspecced
-- `^Get` answers 0 while ITEM_SLOT_TYPE_BACKPACK is an auto-sentinel (1174), so
-- `GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK` used to be `0 == 1174` --
-- FALSE on every frame. tests/mock/replay_fixture.lua now answers the getter off
-- the dump's real 0-5 / 6-8 layout. The premise below asserts that it still does,
-- so a zero reading here can never be mistaken for "the lever does nothing".

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The same frame the sibling rescuer file pins, and for the same property: six
-- main slots full, backpack slots free. A rescue is only meaningful when main is
-- full, because GetMainInvLessValItemSlot short-circuits to any empty main slot.
local FIX  = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local HERO = 'npc_dota_hero_viper'

local ROAM    = 'bots/mode_team_roam_generic.lua'
local JMZFUNC = 'bots/FunLib/jmz_func.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Slice a top-level function body: header to the next top-level `function`.
local function body_of(src, header)
    local i = src:find(header, 1, true)
    if not i then return nil end
    local j = src:find('\nfunction ', i + #header, true)
    return src:sub(i, j and (j - 1) or #src)
end

--- Like body_of, but cut at the function's OWN terminating `end` -- a line that
--- is exactly "end", at column 0. Nested ends in this file are tab-indented, so
--- they cannot truncate it.
---
--- Needed because body_of runs to the NEXT `function` keyword and therefore
--- swallows the doc comment that precedes it. That is not hypothetical: the
--- first version of the set-difference premise below read the flask rescuer's
--- body as containing "bagtango" -- because this id's 60-line header sits
--- between the two functions -- and reported "the flask rescuer disappeared".
--- The assertion was right to go red; it was measuring the wrong bytes.
local function fn_body(src, header)
    local b = body_of(src, header)
    if not b then return nil end
    local j = b:find('\nend\n', 1, true)
    return j and b:sub(1, j + 4) or b
end

--- Load the frame with `armed` armed, then dofile the roam mode so its
--- file-local `bot` upvalue binds to this subject and the rescuers become
--- callable globals.
local function roam_world(armed)
    local J, bot = rf.load(FIX, HERO)
    J.IsSoakCandidate = function(id)
        if armed == nil then return false end
        if type(armed) == 'table' then return armed[id] == true end
        return id == armed
    end
    TrySwapInvItemForFieldRegen = nil                     -- luacheck: ignore
    TrySwapInvItemForFlask = nil                          -- luacheck: ignore
    assert(pcall(dofile, ROAM), 'the roam mode file did not load')
    assert(type(TrySwapInvItemForFieldRegen) == 'function', -- luacheck: ignore
        'the new rescuer is not a global after loading the roam mode')
    return J, bot
end

--- Model a delivery of `sName` into slot `nSlot`. Everything downstream of the
--- injected handle -- which main slot is chosen, whether it acts at all -- is
--- shipped code reading the real frame's real main-slot contents.
local function deliver(bot, sName, nSlot)
    local real_get, real_find = bot.GetItemInSlot, bot.FindItemSlot
    local hItem = { GetName = function() return sName end }
    bot.GetItemInSlot = function(self, i)
        if i == nSlot then return hItem end
        return real_get(self, i)
    end
    bot.FindItemSlot = function(self, s)
        if s == sName then return nSlot end
        return real_find(self, s)
    end
    local swaps = {}
    bot.ActionImmediate_SwapItems = function(_, a, b)
        swaps[#swaps + 1] = { a, b }
    end
    return swaps
end

--- The three names this lever reads. Kept in one place so `only` and the
--- effect cases cannot drift apart.
local RESCUED = { 'item_tango', 'item_tango_single', 'item_faerie_fire' }

--- Like `deliver`, but AUTHORITATIVE over all three names: the delivered one
--- sits in `nSlot`, the other two are absent. Without this a case that models a
--- tango still sees the frame's REAL backpacked faerie fire (slot 6) and the
--- lever rescues that instead -- which is how the first draft of the no-thrash
--- case went red. Use `deliver` only when the other two genuinely do not matter.
local function only(bot, sName, nSlot)
    local real_get, real_find = bot.GetItemInSlot, bot.FindItemSlot
    local hItem = sName and { GetName = function() return sName end } or nil
    local suppressed = {}
    for _, s in ipairs(RESCUED) do suppressed[s] = true end
    if sName then suppressed[sName] = nil end

    bot.GetItemInSlot = function(self, i)
        if nSlot and i == nSlot then return hItem end
        local it = real_get(self, i)
        if it and suppressed[it:GetName()] then return nil end
        return it
    end
    bot.FindItemSlot = function(self, s)
        if suppressed[s] then return -1 end
        if sName and s == sName then return nSlot or -1 end
        return real_find(self, s)
    end
    local swaps = {}
    bot.ActionImmediate_SwapItems = function(_, a, b)
        swaps[#swaps + 1] = { a, b }
    end
    return swaps
end

local function first_empty(bot, lo, hi)
    for i = lo, hi do
        if bot:GetItemInSlot(i) == nil then return i end
    end
    return nil
end

-- ---------------------------------------------------------------- premises --

-- The load-bearing claim, read off the source rather than restated. If anyone
-- ships a tango or faerie-fire rescuer, this goes red and says so -- which is
-- the correct outcome, because this id would then be redundant.
tests['[premise] exactly one regen source has a shipped backpack rescuer'] = function()
    local roam = read_file(ROAM)
    local jmz  = read_file(JMZFUNC)

    local hasSrc = body_of(jmz, 'function J.HasFieldRegenSource( bot )')
    assert(hasSrc, 'J.HasFieldRegenSource moved; re-anchor this premise')
    local supply = { 'item_flask', 'item_tango', 'item_tango_single',
                     'item_faerie_fire', 'item_bottle' }
    for _, s in ipairs(supply) do
        assert(hasSrc:find(s, 1, true),
            'the supply set changed: ' .. s .. ' is no longer read by J.HasFieldRegenSource')
    end

    -- Which of those five does a SHIPPED (un-gated) rescuer name? Count only
    -- rescuer bodies that are not this id's own.
    local shippedRescued = {}
    for name in roam:gmatch('function (TrySwapInvItemFor%w+)%(%)') do
        local b = fn_body(roam, 'function ' .. name .. '()')
        if b and not b:find('bagtango', 1, true) then
            for _, s in ipairs(supply) do
                if b:find("'" .. s .. "'", 1, true) then shippedRescued[s] = true end
            end
        end
    end

    assert(shippedRescued['item_flask'], 'the flask rescuer disappeared; the whole argument moves')
    for _, s in ipairs({ 'item_tango', 'item_tango_single', 'item_faerie_fire' }) do
        assert(not shippedRescued[s],
            s .. ' now has a shipped rescuer -- this id is redundant, retire it')
    end
end

tests['[premise] the pinned frame has a full main inventory and a free backpack'] = function()
    local _, bot = roam_world('bagtango')
    assert(first_empty(bot, 0, 5) == nil,
        'a main slot is free, so the delivery would never have landed in the bag')
    assert(first_empty(bot, 6, 8) ~= nil,
        'the backpack is full, so there is no slot to deliver into')
end

tests['[premise] the loader answers GetItemSlotType, so a zero here would mean something'] = function()
    local _, bot = roam_world('bagtango')
    assert(bot:GetItemSlotType(6) == ITEM_SLOT_TYPE_BACKPACK,
        'the loader stopped answering GetItemSlotType -- every rescuer is structurally ' ..
        'dead on this frame and a zero reading below means nothing')
    assert(bot:GetItemSlotType(0) == ITEM_SLOT_TYPE_MAIN,
        'the loader answers for the backpack but not the main inventory')
end

tests['[premise] item CHOICE is not measurable here, only item EXISTENCE'] = function()
    -- GetItemCost answers 0 offline, so every switchable main item ties at 0 and
    -- GetMainInvLessValItemSlot returns the first. Asserted so no swap below is
    -- ever read as "it picked the cheapest item".
    local J, bot = roam_world('bagtango')
    assert(GetItemCost('item_yasha') == 0,
        'GetItemCost now answers; the price leg may be testable, re-measure')
    assert(J.Item.GetMainInvLessValItemSlot(bot) == 0,
        'the degenerate tie no longer resolves to slot 0')
end

-- -------------------------------------------------------------------- gate --

tests['[gate] un-armed the new rescuer does nothing at all'] = function()
    local _, bot = roam_world(nil)
    local swaps = deliver(bot, 'item_tango', 6)
    TrySwapInvItemForFieldRegen()                         -- luacheck: ignore
    assert(#swaps == 0, 'the lever acted with nothing armed: ' .. #swaps)
end

tests['[gate] armed but NOT turbo the new rescuer does nothing'] = function()
    local J, bot = roam_world('bagtango')
    J.IsModeTurbo = function() return false end
    local swaps = deliver(bot, 'item_tango', 6)
    TrySwapInvItemForFieldRegen()                         -- luacheck: ignore
    assert(#swaps == 0, 'the lever acted outside turbo: ' .. #swaps)
end

tests['[gate] the turbo check is real on this frame, i.e. the gate test above is not vacuous'] = function()
    local J = roam_world('bagtango')
    assert(J.IsModeTurbo() == true,
        'the fixture is not turbo, so the not-turbo gate test proves nothing')
end

-- ------------------------------------------------------------ final action --

-- ⭐ THE HEADLINE CASE, and nothing in it is modelled. This frame was pinned for
-- a different id's argument (six main slots full), and it turns out to carry a
-- REAL item_faerie_fire sitting in REAL backpack slot 6 -- an unmodelled
-- instance of exactly the defect this lever names, found in the corpus rather
-- than constructed for the test. The shipped tree leaves it there for the rest
-- of the game: no rescuer names faerie fire, so the viper is holding 85 health
-- it can never reach. Only ActionImmediate_SwapItems is captured; the item, the
-- slot, the full main inventory and every read the rescuer makes are the frame's.
tests['armed, the REAL backpacked faerie fire on this frame is moved into a usable slot'] = function()
    local _, bot = roam_world('bagtango')

    -- The premise of this case, asserted rather than assumed: the frame really
    -- does carry it, in a real backpack slot, un-injected.
    assert(bot:FindItemSlot('item_faerie_fire') == 6,
        'the frame no longer carries a backpacked faerie fire; this case is now modelled ' ..
        'and must be rewritten or re-pinned')
    assert(bot:GetItemInSlot(6):GetName() == 'item_faerie_fire',
        'slot 6 no longer holds the faerie fire')

    local swaps = {}
    bot.ActionImmediate_SwapItems = function(_, a, b) swaps[#swaps + 1] = { a, b } end

    TrySwapInvItemForFieldRegen()                         -- luacheck: ignore

    assert(#swaps == 1, 'expected exactly one swap, got ' .. #swaps)
    assert(swaps[1][1] == 6, 'the rescuer swapped the wrong slot out: ' .. tostring(swaps[1][1]))
    assert(swaps[1][2] >= 0 and swaps[1][2] <= 5,
        'the faerie fire was not moved into a usable slot: ' .. tostring(swaps[1][2]))
end

tests['[non-empty] the shipped tree leaves that same real faerie fire in the bag'] = function()
    -- The other half of the case above: un-armed, every shipped rescuer runs on
    -- this frame and NONE of them touches slot 6. If this ever goes green-by-
    -- accident (someone ships a faerie-fire rescuer) the premise test says so.
    local _, bot = roam_world(nil)
    local swaps = {}
    bot.ActionImmediate_SwapItems = function(_, a, b) swaps[#swaps + 1] = { a, b } end

    TrySwapInvItemForFlask()                              -- luacheck: ignore
    TrySwapInvItemForFieldRegen()                         -- luacheck: ignore

    assert(#swaps == 0,
        'the shipped tree rescued something on this frame; the defect is not what ' ..
        'this file says it is: ' .. #swaps)
end

for _, sName in ipairs({ 'item_tango', 'item_tango_single' }) do
    tests['armed, ' .. sName .. ' is moved out of the backpack into a usable slot'] = function()
        local _, bot = roam_world('bagtango')
        local swaps = only(bot, sName, 6)

        TrySwapInvItemForFieldRegen()                     -- luacheck: ignore

        assert(#swaps == 1, 'expected exactly one swap for ' .. sName .. ', got ' .. #swaps)
        assert(swaps[1][1] == 6,
            'the rescuer swapped the wrong slot out: ' .. tostring(swaps[1][1]))
        assert(swaps[1][2] >= 0 and swaps[1][2] <= 5,
            sName .. ' was not moved into a usable slot: ' .. tostring(swaps[1][2]))
    end
end

tests['an item already in a MAIN slot is left alone (no thrash)'] = function()
    local _, bot = roam_world('bagtango')
    -- `only`, not `deliver`: the frame's real backpacked faerie fire has to be
    -- suppressed or it -- correctly -- gets rescued and this case measures it
    -- instead of the tango.
    local swaps = only(bot, 'item_tango', 3)
    TrySwapInvItemForFieldRegen()                         -- luacheck: ignore
    assert(#swaps == 0,
        'the rescuer swapped an item that was already usable: ' .. #swaps)
end

tests['the bottle is deliberately NOT rescued'] = function()
    local _, bot = roam_world('bagtango')
    local swaps = only(bot, nil, nil)                     -- all three suppressed
    local real_find = bot.FindItemSlot
    bot.FindItemSlot = function(self, s)
        if s == 'item_bottle' then return 6 end
        return real_find(self, s)
    end
    TrySwapInvItemForFieldRegen()                         -- luacheck: ignore
    assert(#swaps == 0,
        'the bottle was swapped; this lever is three items wide by design: ' .. #swaps)
end

-- -------------------------------------------------------------- isolation --

tests['[isolation] arming this id does not change the shipped flask rescuer'] = function()
    -- The flask rescuer must behave identically whether or not this id is armed;
    -- otherwise the un-armed tree is not byte-identical and a single-arm wave is
    -- reading two levers at once.
    local function flask_swaps(armed)
        local _, bot = roam_world(armed)
        local swaps = deliver(bot, 'item_flask', 6)
        TrySwapInvItemForFlask()                          -- luacheck: ignore
        return swaps
    end
    local off = flask_swaps(nil)
    local on  = flask_swaps('bagtango')
    assert(#off == 1 and #on == 1,
        'the shipped flask rescuer stopped firing: off=' .. #off .. ' on=' .. #on)
    assert(off[1][1] == on[1][1] and off[1][2] == on[1][2],
        'arming bagtango changed the shipped flask rescuer"s swap')
end

tests['[isolation] the new rescuer does not consume the flask rescuer"s throttle'] = function()
    -- A shared timestamp would make the shipped cadence depend on this id.
    local roam = read_file(ROAM)
    local b = body_of(roam, 'function TrySwapInvItemForFieldRegen()')
    assert(b, 'the new rescuer moved; re-anchor this assertion')
    assert(not b:find('SwappedFlaskTime', 1, true),
        'the new rescuer writes the shipped flask throttle')
    assert(b:find('SwappedFieldRegenTime', 1, true),
        'the new rescuer no longer uses its own throttle')
end

tests['[isolation] exactly one soak id appears in the new rescuer (no pullcad trap)'] = function()
    local roam = read_file(ROAM)
    local b = body_of(roam, 'function TrySwapInvItemForFieldRegen()')
    local ids = {}
    for id in b:gmatch("IsSoakCandidate%('([%w_]+)'%)") do ids[#ids + 1] = id end
    assert(#ids == 1, 'expected exactly one gated id, found ' .. #ids)
    assert(ids[1] == 'bagtango', 'the id changed to ' .. tostring(ids[1]))

    -- and exactly one call site, so the id can never be reached only via a
    -- second armed lever (the trap 'staybag' documents as a call-spread pullcad).
    local _, n = roam:gsub('TrySwapInvItemForFieldRegen%(%)', '')
    assert(n == 2, 'expected one definition + one call site, found ' .. n .. ' occurrences')
end

return tests
