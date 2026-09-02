-- [fieldbuy / owner priority P2] GH #123 says the salve fieldbuy buys can land
-- in the backpack, where it cannot be drunk, and proposes narrowing the
-- purchase gate from `Item.GetEmptyInventoryAmount` (slots 0..8) to
-- `Item.GetEmptyNonBackpackInventoryAmount` (slots 0..5), so the gate and
-- J.HasFieldRegenSource read the same slots.
--
-- ⭐ THE FIX MUST NOT SHIP AS PROPOSED, and this file is the reason.
--
-- The issue's premise -- a salve delivered into the backpack is stuck there --
-- is not true of this tree. `TrySwapInvItemForFlask()`
-- (mode_team_roam_generic.lua:1854) swaps a backpacked flask into a main slot,
-- and it is NOT roam-only behaviour: it is called from ItemOpsDesire(), which
-- is called from GetDesireHelper(), which is called from GetDesire() -- and the
-- engine polls every mode file's GetDesire() on every frame for every bot,
-- whichever mode ends up winning. That is not an inference about the engine;
-- docs/BOT_API_REFERENCE.md states it: "GetDesire() is called every frame for
-- ALL modes simultaneously. The mode returning the highest desire value wins
-- and becomes the active mode. Only that mode's Think() is then called."
-- So "it lives in the roam mode file" does NOT mean "it is roam-only": the
-- GetDesire half of a mode file is shared, per-frame, whole-roster code, and
-- only the Think half belongs to the winner. Only one guard sits between the top of
-- GetDesireHelper and that call (invulnerable / not-a-live-hero / illusion), so
-- for a live hero standing in the field the rescuer runs, throttled to once per
-- 6.2 seconds. All of that is asserted below off the source, not restated.
--
-- What that costs the proposed fix, measured on the same corpus the id's own
-- census already uses (SPLIT line, tests/_fieldbuy_supply_sweep.lua):
--   * the fix would silence this id on 13 of the 28 dry domain frames (46.4%)
--     -- every frame whose six main slots are full;
--   * on 13 of those 13, the shipped rescuer has a main-slot item it is
--     allowed to swap out, i.e. it would have worked. 0 are stuck.
-- Both counts are measured on the DOMAIN predicate (J.ShouldFieldBuyRegen's
-- situation AND dry legs), not on the full purchase conjunction, which also
-- carries stash/gold/stock/modifier clauses this corpus cannot all answer. So
-- 13 is an upper bound on the purchases lost -- but 28 is the same upper bound
-- for the same reason, and the 46.4% ratio is what the argument rests on.
-- The replay desk's 12.9% is the RESIDUAL AFTER the rescuer, not the whole
-- population, so the trade on offer is "stop a 12.9% waste by giving up 46.4%
-- of the behaviour owner P2 asked for". That is the lanefix shape: a locally
-- defensible clause with an aggregate the local argument never looked at.
--
-- The issue's own §3 already contains the disproof and reads it the other way:
-- the viper frame where the flask is visible in the backpack at t=354.5 and
-- DRUNK at 354.6 was attributed to a courier delivery plus a recipe combine
-- freeing a main slot inside one sampling cell. An unconditional every-frame
-- rescuer is the simpler account of the same observation -- and the desk wrote
-- the conclusion itself: "背包只是一站", the backpack is a waypoint.
--
-- ⭐ The trap this file exists to keep shut. On a fixture the mock answers 0 for
-- every Get*, while ITEM_SLOT_TYPE_BACKPACK is an auto-sentinel (1174), so
-- `bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK` is FALSE on every
-- frame in the corpus -- the thirteenth world assertion (GH #89) recurring at a
-- new site. A naive isolation test would therefore have driven the rescuer,
-- recorded zero swaps on all 930 frames, and "confirmed" GH #123. That is
-- charter 0p verbatim, except mirrored: 0p was an unreachable branch silently
-- CREDITING a gate; this is an unreachable branch silently taking the BLAME for
-- a defect it prevents. The declaration is made visible below (GH #61 ruling)
-- and mutated, so it can never go quietly missing.
--
-- Honest bounds, stated first:
--   * the courier delivery is MODELLED, at the GetItemInSlot/FindItemSlot
--     surface. Everything downstream of the injected handle -- which slot it
--     picks, whether it acts at all -- is shipped code reading the real frame's
--     real main-slot contents.
--     ⚠ CORRECTED 2026-08-23: this bound used to read "it has to be: no frame
--     in the corpus carries a flask in a backpack slot". That is FALSE on
--     today's 104-fixture corpus -- 13 live frames do, across all three
--     backpack slots (6:2, 7:6, 8:5); see the BAG line of
--     _fieldbuy_supply_sweep.lua and tests/test_bagsalve_backpack_source.lua,
--     which pins two of them. What is still true, and is the only reason the
--     delivery is modelled HERE, is narrower: no frame carries a backpacked
--     flask while ALSO being inside J.IsFieldRegenSituation (BAG sit_flip=0),
--     which is the frame this file's driven action needs. The wrong version of
--     that sentence was load-bearing for the wrong claim -- it would have sent
--     the next reader away from 13 real frames.
--   * WHICH main item gets swapped out is not measurable here. GetItemCost
--     answers 0 offline, so GetMainInvLessValItemSlot's price comparison is
--     degenerate and it returns the first switchable slot. Only WHETHER a
--     switchable slot exists -- the one thing the rescuer's `~= -1` reads -- is
--     a real result. Asserted, so nobody reads item choice into this file.
--   * this file does not claim the residual 12.9% is not real. It claims the
--     purchase gate is not its cause. Finding the cause is a separate unit;
--     GH #123 has the pointer.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The frame GH #123's fix would silence, and not an arbitrary one: it is the
-- frame the id's own supply test already pins as Frame B (the frame where the
-- shipped tree's 0.45 HP ceiling is the only thing standing between this bot
-- and a salve). Six main slots full, two backpack slots free.
local FIX  = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local HERO = 'npc_dota_hero_viper'

local ROAM     = 'bots/mode_team_roam_generic.lua'
local PURCHASE = 'bots/item_purchase_generic.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Slice a top-level function body: from its header to the next top-level
--- `function` (or end of file). Line-anchored, so nested `end`s cannot
--- truncate it the way a non-greedy `.-\nend` can on a 350-line function.
local function body_of(src, header)
    local i = src:find(header, 1, true)
    if not i then return nil end
    local j = src:find('\nfunction ', i + #header, true)
    return src:sub(i, j and (j - 1) or #src)
end

--- Load the frame with `armed` armed, then dofile the roam mode so its
--- file-local `bot` upvalue binds to this subject and TrySwapInvItemForFlask
--- becomes callable.
local function roam_world(armed)
    local J, bot = rf.load(FIX, HERO)
    J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    TrySwapInvItemForFlask = nil                          -- luacheck: ignore
    assert(pcall(dofile, ROAM), 'the roam mode file did not load')
    assert(type(TrySwapInvItemForFlask) == 'function',    -- luacheck: ignore
        'the rescuer is not a global after loading the roam mode')
    return J, bot
end

--- Declaration 1 (an engine fact, not a model): slots 0..5 are the usable main
--- inventory and 6..8 are the backpack. Nothing about this needs modelling --
--- it is a fixed property of the engine, in the same class as GAMEMODE_TURBO
--- being 23 (GH #93) -- but the mock cannot answer it, so it is declared.
local function declare_slot_types(bot)
    bot.GetItemSlotType = function(_, i)
        if i == nil or i < 0 then return ITEM_SLOT_TYPE_MAIN end
        return (i >= 6) and ITEM_SLOT_TYPE_BACKPACK or ITEM_SLOT_TYPE_MAIN
    end
end

--- Declaration 2: model the courier delivering a salve into slot `nSlot`.
--- Returns the recorded swap list, which the caller drives the rescuer against.
local function deliver_flask(bot, nSlot)
    local real_get, real_find = bot.GetItemInSlot, bot.FindItemSlot
    local hFlask = { GetName = function() return 'item_flask' end }
    bot.GetItemInSlot = function(self, i)
        if i == nSlot then return hFlask end
        return real_get(self, i)
    end
    bot.FindItemSlot = function(self, sName)
        if sName == 'item_flask' then return nSlot end
        return real_find(self, sName)
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

tests['[premise] the pinned frame really is one the proposed fix would silence'] = function()
    local _, bot = roam_world('fieldbuy')
    assert(first_empty(bot, 0, 5) == nil,
        'a main slot is free, so the two clauses agree here and nothing is at stake')
    assert(first_empty(bot, 6, 8) ~= nil,
        'the backpack is full too, so the old clause is FALSE and nothing is at stake')
end

-- SUPERSEDED 2026-09-02 (strategy, the 'slotdust' round), and superseded the
-- way a ratchet is supposed to be: this assertion USED to read
-- `bot:GetItemSlotType(6) ~= ITEM_SLOT_TYPE_BACKPACK` and then that the rescuer
-- fired ZERO times without declare_slot_types -- the thirteenth world assertion
-- at a new site, kept so a naive isolation run could not read zero and call it a
-- confirmation of GH #123. It went red the moment tests/mock/replay_fixture.lua
-- started answering GetItemSlotType off the dump's real 0-5 / 6-8 layout, said
-- "re-measure", and the re-measurement is below.
--
-- The mechanism, now that it is known: the CONSTANTS were never missing --
-- api.install auto-resolves ALL_CAPS globals to distinct sentinels (BACKPACK
-- measured at 1174 on this very frame, which is the number the header above
-- quotes). What was missing was the GETTER, and an unspecced `^Get` answers 0,
-- so `GetItemSlotType(6) == ITEM_SLOT_TYPE_BACKPACK` was `0 == 1174`.
--
-- So the branch is reachable now, and declare_slot_types is redundant rather
-- than load-bearing. Both halves are asserted, because "redundant" is a
-- measurement too: the undeclared world must produce the SAME swap the declared
-- world does, or the loader's layout and the declaration disagree.
tests['[premise] the loader now supplies the slot types the declaration used to'] = function()
    local _, bot = roam_world('fieldbuy')
    assert(bot:GetItemSlotType(6) == ITEM_SLOT_TYPE_BACKPACK,
        'the loader stopped answering GetItemSlotType -- the rescuer is structurally ' ..
        'dead again and a zero reading here means nothing')
    assert(bot:GetItemSlotType(0) == ITEM_SLOT_TYPE_MAIN,
        'the loader answers for the backpack but not the main inventory')
    local swaps = deliver_flask(bot, 6)
    TrySwapInvItemForFlask()                              -- luacheck: ignore
    assert(#swaps == 1, 'the rescuer no longer fires without the declaration: ' .. #swaps)
    assert(swaps[1][1] == 6 and swaps[1][2] >= 0 and swaps[1][2] <= 5,
        'the undeclared world produced a different swap than the declared one: ' ..
        tostring(swaps[1][1]) .. ' <-> ' .. tostring(swaps[1][2]))
end

tests['[premise] item choice is NOT measurable here, only item existence'] = function()
    -- GetItemCost answers 0 offline, so every switchable main item ties at 0
    -- and GetMainInvLessValItemSlot returns the first one. Asserted so the
    -- `SWAP 6 <-> 0` below is never read as "it picked the cheapest item".
    local J, bot = roam_world('fieldbuy')
    assert(GetItemCost('item_yasha') == 0,
        'GetItemCost now answers; the price leg may be testable, re-measure')
    assert(J.Item.GetMainInvLessValItemSlot(bot) == 0,
        'the degenerate tie no longer resolves to slot 0')
end

-- ------------------------------------------------------------- final action --

tests['the shipped rescuer moves the delivered salve out of the backpack'] = function()
    local _, bot = roam_world('fieldbuy')
    declare_slot_types(bot)
    local swaps = deliver_flask(bot, 6)

    TrySwapInvItemForFlask()                              -- luacheck: ignore

    assert(#swaps == 1, 'expected exactly one swap, got ' .. #swaps)
    assert(swaps[1][1] == 6,
        'the rescuer swapped the wrong slot out: ' .. tostring(swaps[1][1]))
    assert(swaps[1][2] >= 0 and swaps[1][2] <= 5,
        'the salve was not moved into a usable slot: ' .. tostring(swaps[1][2]))
end

tests['the rescuer needs no gate and no armed id: it fires with nothing armed'] = function()
    -- It is shipped, ungated behaviour. If it only worked while 'fieldbuy' were
    -- armed, the argument against GH #123 would evaporate the moment the id is
    -- promoted or dropped.
    local _, bot = roam_world(nil)
    declare_slot_types(bot)
    local swaps = deliver_flask(bot, 6)
    TrySwapInvItemForFlask()                              -- luacheck: ignore
    assert(#swaps == 1, 'the rescuer did not fire unarmed: ' .. #swaps)
end

tests['negative control: a salve already in a main slot is not swapped'] = function()
    -- Without this, "one swap" above could be the rescuer firing at anything
    -- rather than at the backpack specifically.
    local _, bot = roam_world('fieldbuy')
    declare_slot_types(bot)
    local swaps = deliver_flask(bot, 3)
    TrySwapInvItemForFlask()                              -- luacheck: ignore
    assert(#swaps == 0, 'the rescuer churned a main-slot salve: ' .. #swaps)
end

tests['negative control: no salve anywhere means no swap'] = function()
    local _, bot = roam_world('fieldbuy')
    declare_slot_types(bot)
    local swaps = {}
    bot.ActionImmediate_SwapItems = function(_, a, b) swaps[#swaps + 1] = { a, b } end
    assert(bot:FindItemSlot('item_flask') < 0, 'this frame carries a flask; pick another')
    TrySwapInvItemForFlask()                              -- luacheck: ignore
    assert(#swaps == 0, 'the rescuer swapped with no flask to swap: ' .. #swaps)
end

-- -------------------------------------------------------------- reachability --

tests['[reverse] the rescuer is on the every-frame GetDesire path, not roam-only'] = function()
    -- The load-bearing claim of this whole file. If someone moves the call into
    -- Think() (which only runs for the WINNING mode), the rescuer really does
    -- become roam-only and GH #123 becomes correct again -- so this must turn
    -- red rather than quietly changing the answer.
    local src = read_file(ROAM)

    local desire = body_of(src, 'function GetDesire()')
    assert(desire and desire:find('GetDesireHelper()', 1, true),
        'GetDesire no longer delegates to GetDesireHelper')

    local helper = body_of(src, 'function GetDesireHelper()')
    assert(helper, 'could not locate GetDesireHelper')
    local iOps = helper:find('ItemOpsDesire()', 1, true)
    assert(iOps, 'GetDesireHelper no longer calls ItemOpsDesire')

    local ops = body_of(src, 'function ItemOpsDesire()')
    assert(ops and ops:find('TrySwapInvItemForFlask()', 1, true),
        'ItemOpsDesire no longer calls the flask rescuer')

    -- Exactly one guard may return before the call, and it is the one that
    -- excludes bots this file makes no claim about.
    -- Comments must come out first: this helper's own header comment contains
    -- the word `return` in backticks, which a bare word match counts as code.
    local before = (helper:sub(1, iOps) .. '\n'):gsub('%-%-[^\n]*', '')
    local _, nReturns = before:gsub('%f[%w]return%f[%W]', '')
    assert(nReturns == 1,
        'a new early return now sits before the rescuer (' .. nReturns
        .. '); its domain must be re-measured')
    assert(before:find('IsInvulnerable', 1, true) and before:find('IsIllusion', 1, true),
        'the one early return is no longer the live-hero guard')
end

tests['[reverse] the rescuer is not called from Think(), which is mode-gated'] = function()
    local src = read_file(ROAM)
    local think = body_of(src, 'function Think()')
    assert(think, 'could not locate Think')
    assert(not think:find('TrySwapInvItemForFlask', 1, true),
        'the rescuer moved into Think; re-read this file s header')
end

tests['[reverse] the 6.2s throttle is a static stamp, not a lazy clock read'] = function()
    -- GH #91 (the fourteenth world assertion) is a table initialised with the
    -- very clock it is then compared against, which pins the difference at 0.
    -- This throttle is not that shape, and the difference decides whether the
    -- rescuer runs at all.
    local src = read_file(ROAM)
    local init = src:match('local SwappedFlaskTime%s*=%s*(%-?%d+)')
    assert(init, 'SwappedFlaskTime is no longer a file-local literal')
    assert(tonumber(init) < 0,
        'the throttle now starts in the future: ' .. init)
    assert(not src:match('local SwappedFlaskTime%s*=%s*[GD][ao][mt][ea]Time'),
        'the throttle is now seeded from a clock read (GH #91 shape)')
    local body = body_of(src, 'function TrySwapInvItemForFlask()')
    assert(body and body:find('SwappedFlaskTime + 6.2', 1, true),
        'the throttle interval moved; re-measure against the 30s stuck window')
end

tests['[recorded] there is exactly one roam mode file, so no hero escapes it'] = function()
    -- If a per-hero override of this mode ever appears, that hero's bots lose
    -- the rescuer and become the residual population GH #123 is looking for.
    local p = assert(io.popen('ls bots/ bots/BotLib/ 2>/dev/null'))
    local out = p:read('*a')
    p:close()
    local _, n = out:gsub('mode_team_roam[%w_]*%.lua', '')
    assert(n == 1, 'expected one roam mode file, found ' .. n)
end

-- ------------------------------------------------------------------ ratchet --

tests['[reverse] the GH #123 fix is NOT applied to the fieldbuy purchase gate'] = function()
    -- The ratchet. Applying the one-word change turns this red, which forces
    -- whoever applies it through this file's header first. It is not a veto:
    -- if the 13/13 reading is ever overturned, delete this test in the same
    -- commit and say so.
    local src = read_file(PURCHASE)
    local i = src:find('J.ShouldFieldBuyRegen( bot )', 1, true)
        or src:find('J.ShouldFieldBuyRegen(bot)', 1, true)
    assert(i, 'could not locate the fieldbuy purchase block')
    local block = src:sub(i, i + 1200)
    local j = block:find('ActionImmediate_PurchaseItem', 1, true)
    assert(j, 'the fieldbuy block no longer ends in a purchase')
    block = block:sub(1, j)
    assert(block:find('Item.GetEmptyInventoryAmount(bot) >= 1', 1, true),
        'the fieldbuy gate no longer reads all nine slots -- if that is '
        .. 'deliberate, read this file s header: the corpus says the change '
        .. 'silences 13 of 28 domain frames to stop a waste the shipped '
        .. 'rescuer already clears on 13 of those 13')
    assert(not block:find('GetEmptyNonBackpackInventoryAmount', 1, true),
        'the GH #123 fix appears to have been applied; see this file s header')
end

return tests
