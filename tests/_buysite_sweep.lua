-- Corpus sweep for tests/test_fieldsip_transfer_receiving_site.lua, run as a
-- SUBPROCESS (backlog 0q: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHAT IT MEASURES. tests/test_fieldsip_atom_pricing.lua (2026-09-08) priced
-- the 'fieldsip' transfer at the PREDICATE level: arming it kills 22 hold
-- frames and hands the same 22 to the supply side, and it called the transfer
-- correct because owner P2's rule ("买大药") lives on the supply side. That is
-- a reading of what J.ShouldFieldBuyRegen ANSWERS. It never asked whether the
-- conjunction that answer was dropped into can act on those frames -- which is
-- this repo's own criterion (tests/test_stayfield_callsite_domain.lua):
--
--     a guard's domain is its predicate INTERSECTED with the rest of the
--     conjunction it was dropped into
--
-- applied for the first time to the leg RECEIVING a transfer rather than to the
-- leg losing one.
--
-- ⛔ THE ANSWER IS NOT A LEVER, AND THIS FILE EXISTS PARTLY TO SAY SO.
-- The narrowing this measurement first suggested -- make the block's slot
-- clause read main slots only -- IS GH #123's proposal, measured and REJECTED
-- on 2026-08-23. tests/test_fieldbuy_backpack_rescuer.lua is the standing
-- ratchet for it and its header carries the disproof: TrySwapInvItemForFlask()
-- (bots/mode_team_roam_generic.lua:2237) swaps a backpacked flask into a main
-- slot, runs every frame for every live hero via GetDesire, and cleared 13 of
-- 13 of the frames the proposal would have silenced on the DRY domain. So the
-- open question this sweep closes is the narrow one that reading leaves:
--
--     the dry domain's rescue rate is measured; the TRANSFERRED set's is not.
--
-- The last leg below measures it, and it uses the rescuer's own predicate
-- (J.Item.GetMainInvLessValItemSlot ~= -1) rather than a reimplementation.
--
-- ⚠️ TWO STATED BOUNDS, neither of which this sweep may be read past.
--   * GOLD AND STOCK ARE UNREADABLE (GH #495: bot:GetGold() is 0 on every live
--     corpus frame), so every `site_*` count is a CEILING on the receiving
--     domain, never the domain.
--   * GetItemCost answers 0 offline, so GetMainInvLessValItemSlot's price
--     comparison is degenerate and it returns the first switchable slot. Only
--     WHETHER a switchable slot exists -- the `~= -1` the rescuer itself reads
--     -- is a real result. WHICH item would be swapped out is not measured here
--     and no reading below depends on it. (Same bound the GH #123 file states.)
--
-- Manifest grammar (one record per line, space-separated):
--   G <key> <n>              a source-parsed structural fact (1/0 or a number)
--   C <key> <n>              a counter bucket
--   XFER <fixture> <hero> <hp4> <main_empty> <bag_empty> <swap_slot>
--       one transferred frame (hold TRUE bare, FALSE with 'fieldsip' armed).
--       hp4 = HP fraction * 10000; swap_slot = GetMainInvLessValItemSlot.
--   DONE
-- Absence of the final DONE line is treated by the test as a failed subprocess.
--
-- NOTE: print() is not usable here -- the loaded bots/ world replaces it -- so
-- every line goes through io.write.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

-- ---------------------------------------------------------------------------
-- Source-parsed structure. Every constant this sweep uses is READ from bots/,
-- never typed here: a sweep that hard-codes the number it is auditing goes on
-- printing the old answer after the source moves.

local IPG = read_file('bots/item_purchase_generic.lua')
local ABA = read_file('bots/FunLib/aba_item.lua')
local JMZ = read_file('bots/FunLib/jmz_func.lua')
local ROAM = read_file('bots/mode_team_roam_generic.lua')

local G = {}

-- The salve block: from the five-arm disjunction to its purchase call.
local blk = IPG:match('if %( J%.ShouldFieldBuyRegen%(bot%).-ActionImmediate_PurchaseItem%(\'item_flask\'%)')
G.BLOCK_FOUND = blk and 1 or 0
blk = blk or ''

-- The nine engine clauses, asserted present by the test rather than assumed.
G.SITE_ALIVE = blk:find('bot:IsAlive()', 1, true) and 1 or 0
G.SITE_NO_FLASK_SLOT = blk:find("bot:FindItemSlot('item_flask') < 0", 1, true) and 1 or 0
G.SITE_NO_STASH_HEAL = blk:find('not IsThereHealingInStash(bot)', 1, true) and 1 or 0
G.SITE_EMPTY_SLOT = blk:find('Item.GetEmptyInventoryAmount(bot) >= 1', 1, true) and 1 or 0
G.SITE_GOLD = blk:find("botGold >= GetItemCost('item_flask')", 1, true) and 1 or 0
G.SITE_STOCK = blk:find("GetItemStockCount('item_flask') > 1", 1, true) and 1 or 0
G.SITE_MOD_FLASK = blk:find("not bot:HasModifier('modifier_flask_healing')", 1, true) and 1 or 0
G.SITE_MOD_FOUNTAIN = blk:find("not bot:HasModifier('modifier_fountain_aura_buff')", 1, true) and 1 or 0
G.SITE_FOUNTAIN_MIN = tonumber(blk:match('botDistanceFromFountain > (%d+)')) or -1

-- ⭐ The two slot bounds the whole question is about, and the third that makes
-- the GH #123 ratchet's disproof work.
local fn_any = ABA:match('function Item%.GetEmptyInventoryAmount%b()(.-)\nend')
local fn_main = ABA:match('function Item%.GetEmptyNonBackpackInventoryAmount%b()(.-)\nend')
local fn_swap = ABA:match('function Item%.GetMainInvLessValItemSlot%b()(.-)\nend')
local fn_src = JMZ:match('function J%.HasFieldRegenSource%b()(.-)\nend')
G.ANY_SLOT_HI = tonumber(fn_any and fn_any:match('for i = 0, (%d+)')) or -1
G.MAIN_SLOT_HI = tonumber(fn_main and fn_main:match('for i = 0, (%d+)')) or -1
G.SWAP_SLOT_HI = tonumber(fn_swap and fn_swap:match('for i = 0, (%d+)')) or -1
G.SRC_SLOT_HI = tonumber(fn_src and fn_src:match('for i = 0, (%d+)')) or -1

-- The rescuer the GH #123 ruling rests on, and the predicate it reads.
local fn_resc = ROAM:match('function TrySwapInvItemForFlask%b()(.-)\nend')
G.RESCUER_FOUND = fn_resc and 1 or 0
G.RESCUER_USES_SWAP_SLOT =
    (fn_resc and fn_resc:find('J.Item.GetMainInvLessValItemSlot(bot)', 1, true)) and 1 or 0
G.RESCUER_TESTS_MINUS_ONE =
    (fn_resc and fn_resc:find('lessValItem ~= -1', 1, true)) and 1 or 0

for k, v in pairs(G) do out:write('G ' .. k .. ' ' .. tostring(v) .. '\n') end

-- ---------------------------------------------------------------------------

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end

-- Zero-initialised so an absent key and a measured zero can never look the same
-- to the parser -- the GH #171 shape ("the assertion never ran" reading as
-- "the assertion passed").
for _, k in ipairs({ 'fixtures', 'live', 'hold_bare', 'hold_sip', 'transferred',
    'site_no_flask_anywhere', 'site_any_slot', 'site_main_slot',
    'site_far_enough', 'site_no_heal_mod',
    'ceiling_readable', 'ceiling_readable_main_slot', 'no_main_slot',
    'rescuable', 'no_main_slot_rescuable', 'no_main_slot_stuck',
    'IMPOSSIBLE_transfer_without_hold' }) do
    rawset(c, k, 0)
end

local function empty_slots(bot, hi)
    local n = 0
    for i = 0, hi do
        if bot:GetItemInSlot(i) == nil then n = n + 1 end
    end
    return n
end

local function has_item(bot, sName, hi)
    for i = 0, hi do
        local h = bot:GetItemInSlot(i)
        if h ~= nil and h:GetName() == sName then return true end
    end
    return false
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local sArmed = nil
                    J.IsSoakCandidate = function(sId) return sId == sArmed end

                    local okA, hold_bare = pcall(J.ShouldRegenNotGoHome, bot)
                    sArmed = 'fieldsip'
                    local okB, hold_sip = pcall(J.ShouldRegenNotGoHome, bot)
                    sArmed = nil

                    if okA and hold_bare then bump('hold_bare') end
                    if okB and hold_sip then bump('hold_sip') end

                    -- The transferred set: the hold had it, 'fieldsip' gave it
                    -- to the supply side. This is `fs_hold_kills` recomputed
                    -- here rather than cited, so this file stands alone.
                    if okA and okB and hold_bare and not hold_sip then
                        bump('transferred')

                        local nMain = empty_slots(bot, G.MAIN_SLOT_HI)
                        local nAny = empty_slots(bot, G.ANY_SLOT_HI)
                        local nDist = bot:DistanceFromFountain()

                        -- The rescuer's OWN predicate, driven rather than
                        -- reimplemented. -1 means "no switchable main slot".
                        local okS, nSwap = pcall(function()
                            return J.Item.GetMainInvLessValItemSlot(bot)
                        end)
                        nSwap = okS and nSwap or -99

                        local sFx = path:match('([^/]+)%.lua$')
                        local sHero = u.name:gsub('npc_dota_hero_', '')
                        out:write(string.format('XFER %s %s %d %d %d %d\n',
                            sFx, sHero, math.floor(J.GetHP(bot) * 10000 + 0.5),
                            nMain, nAny - nMain, nSwap))

                        -- The readable half of the receiving conjunction, in the
                        -- source's own order.
                        local bNoFlask = not has_item(bot, 'item_flask', G.ANY_SLOT_HI)
                        local bAnySlot = nAny >= 1
                        local bMainSlot = nMain >= 1
                        local bFar = (nDist or 0) > G.SITE_FOUNTAIN_MIN
                        local bNoMod = not bot:HasModifier('modifier_flask_healing')
                            and not bot:HasModifier('modifier_fountain_aura_buff')

                        if bNoFlask then bump('site_no_flask_anywhere') end
                        if bAnySlot then bump('site_any_slot') end
                        if bMainSlot then bump('site_main_slot') else bump('no_main_slot') end
                        if bFar then bump('site_far_enough') end
                        if bNoMod then bump('site_no_heal_mod') end

                        local bCeil = bNoFlask and bAnySlot and bFar and bNoMod
                        if bCeil then bump('ceiling_readable') end
                        if bCeil and bMainSlot then bump('ceiling_readable_main_slot') end

                        -- ⭐ THE LEG THIS SWEEP EXISTS FOR. The GH #123 ruling
                        -- measured the rescue rate on the DRY domain (13/13).
                        -- This is the same reading on the TRANSFERRED set --
                        -- the frames the 2026-09-08 transfer created, which did
                        -- not exist when that ruling was written.
                        if nSwap ~= -1 and nSwap ~= -99 then bump('rescuable') end
                        if not bMainSlot then
                            if nSwap ~= -1 and nSwap ~= -99 then
                                bump('no_main_slot_rescuable')
                            else
                                bump('no_main_slot_stuck')
                            end
                        end
                    elseif okA and okB and hold_sip and not hold_bare then
                        -- 'fieldsip' can only NARROW the hold. A frame the
                        -- magnitude test hands BACK would mean the family's
                        -- direction argument is wrong; asserted 0 downstream.
                        bump('IMPOSSIBLE_transfer_without_hold')
                    end
                end
            end
        end
    end
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write('C ' .. k .. ' ' .. tostring(c[k]) .. '\n') end
out:write('DONE\n')
