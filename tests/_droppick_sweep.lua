-- Heavy corpus sweep for tests/test_droppick_domain.lua, run as a SUBPROCESS
-- (the backlog 0q rule: a full-corpus drive that rebuilds jmz_func once per
-- hero-frame must not run on run_tests.lua's long-lived heap). The leading
-- underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS PRICED.  GH #452 handed this group one item and left it unclaimed:
-- the dropped-item give-up mechanism in bots/mode_team_roam_generic.lua.
-- `ItemOpsThink` keeps a per-bot `ignorePickupList` so that an item it has
-- failed to reach three times is abandoned.  Three call sites ask that set
-- whether an item is on it, and one writes to it:
--
--   :1771  if not J.Utils.SetContains(itemName) and ...          -- read
--   :1819  if tryPickCount >= 3 and not Utils.SetContains(itemName)
--   :1821      Utils.AddToSet(ignorePickupList, PickedItem.item) -- write
--   :1823  if not Utils.SetContains(itemName) and ...            -- read
--
-- while the shipped declaration (bots/FunLib/utils.lua:1260) is
-- `SetContains(set, key)`.  Two independent defects sit on those four lines:
--
--   (1) ARITY.  All three reads pass ONE argument, so `set` binds to the item
--       NAME (a string) and `key` binds to nil.  `("item_aegis")[nil]` is a
--       legal read through the string metatable and answers nil, so the gate is
--       constantly false and `not SetContains(...)` is constantly true.
--   (2) TWO INDEX SPACES.  The write stores `PickedItem.item` -- a HANDLE --
--       as the key, while every read asks by NAME.  So supplying the missing
--       first argument, which is what the arity defect looks like it wants,
--       still never hits.  (Third appearance of the `0SLOT`/`slotarb` family:
--       a set written in one index space and read in another.)
--
-- THE READING THIS SWEEP EXISTS FOR is the second one.  Defect (1) alone is a
-- source fact anyone can read; what it HIDES is that repairing it changes
-- nothing.  So each real item handle in the corpus is driven through the real
-- shipped `AddToSet`/`SetContains` three times:
--
--   shipped  -- `SetContains(name)`, the tree exactly as it stands.
--   argfix   -- `AddToSet(ignore, handle)` then `SetContains(ignore, name)`:
--               line 1821 verbatim, line 1823 with the missing argument
--               supplied.  This is the one-line repair.
--   bothfix  -- `AddToSet(ignore, name)` then `SetContains(ignore, name)`:
--               both halves repaired, i.e. the set actually keyed by what the
--               readers ask for.
--
-- `argfix` answering "not ignored" as often as `shipped` does is the whole
-- point: on this corpus the one-line repair is INDISTINGUISHABLE from no
-- repair, and `bothfix` is the only column that ever says "ignored".
--
-- ⚠️ HONEST BOUNDARY -- what this sweep does NOT witness.  The handles driven
-- here come from the fixtures' INVENTORIES, not from `GetDroppedItemList()`;
-- the mock answers that `{}` and the dumper writes no dropped-item record at
-- all, so `drop_frames` below is a measured 0 and the DECISION (does a bot
-- ever stand in front of a drop it has already given up on?) is not bought by
-- this corpus at any price.  What the three columns witness is the SET
-- PLUMBING, which is handle-vs-name identically for an inventory handle and a
-- drop handle -- that is why a stand-in is legitimate here and would not be
-- legitimate for the decision.  Charter rule 2 therefore forbids landing a
-- behavior fix off this sweep, and none is landed.
--
-- Three-valued throughout (GH #492): a raise is bucketed on its own and never
-- folded into a measured "no".
--
-- Manifest grammar (one record per line, space-separated):
--   C <key> <n>              a counter bucket
--   N <itemname> <n_handles> <shipped_ign> <argfix_ign> <bothfix_ign>
--       one distinct item name seen in the corpus and, over every handle
--       carrying that name, how many times each of the three columns reported
--       "this item is on the ignore list".
--   DONE
-- The test treats absence of the final DONE line as a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

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

local c = setmetatable({}, { __index = function() return 0 end })
local function bump(k, n) rawset(c, k, c[k] + (n or 1)) end
for _, k in ipairs({
    'fixtures', 'live', 'handles', 'names',
    'drop_frames', 'drop_raise', 'invroom_frames', 'invroom_raise',
    'shipped_ignored', 'shipped_raise',
    'argfix_ignored', 'argfix_raise',
    'bothfix_ignored', 'bothfix_raise',
    'names_argfix_ever_ignored', 'names_bothfix_always_ignored',
}) do rawset(c, k, 0) end

-- name -> { n, shipped, argfix, bothfix }
local per_name, name_order = {}, {}
local function row(name)
    if per_name[name] == nil then
        per_name[name] = { n = 0, shipped = 0, argfix = 0, bothfix = 0 }
        name_order[#name_order + 1] = name
    end
    return per_name[name]
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local okl, J, bot = pcall(rf.load, path, u.name)
                if okl and bot ~= nil and J ~= nil then
                    bump('live')

                    -- The ceiling on the whole ItemOps family: without a drop,
                    -- `PickedItem` is never set and neither ItemOpsDesire's
                    -- early return nor ItemOpsThink's body is reachable.
                    local okd, drops = pcall(GetDroppedItemList)
                    if not okd then bump('drop_raise')
                    elseif type(drops) == 'table' and next(drops) ~= nil then bump('drop_frames') end

                    -- ItemOpsThink's own guard, measured so the pricing says
                    -- which preconditions the corpus DOES carry.
                    local oki, room = pcall(J.Item.GetEmptyInventoryAmount, bot)
                    if not oki then bump('invroom_raise')
                    elseif type(room) == 'number' and room > 0 then bump('invroom_frames') end

                    local SetContains, AddToSet = J.Utils.SetContains, J.Utils.AddToSet
                    for slot = 0, 8 do
                        local oks, hItem = pcall(bot.GetItemInSlot, bot, slot)
                        if oks and hItem ~= nil then
                            local okn, itemName = pcall(hItem.GetName, hItem)
                            if okn and type(itemName) == 'string' and itemName ~= '' then
                                bump('handles')
                                local r = row(itemName)
                                r.n = r.n + 1

                                -- shipped: line 1823 exactly as written.
                                local ok1, v1 = pcall(SetContains, itemName)
                                if not ok1 then bump('shipped_raise')
                                elseif v1 then bump('shipped_ignored'); r.shipped = r.shipped + 1 end

                                -- argfix: line 1821 verbatim (handle), then the
                                -- read with its missing first argument supplied.
                                local ignoreA = {}
                                local ok2, v2 = pcall(function()
                                    AddToSet(ignoreA, hItem)
                                    return SetContains(ignoreA, itemName)
                                end)
                                if not ok2 then bump('argfix_raise')
                                elseif v2 then bump('argfix_ignored'); r.argfix = r.argfix + 1 end

                                -- bothfix: the set keyed by what the readers ask.
                                local ignoreB = {}
                                local ok3, v3 = pcall(function()
                                    AddToSet(ignoreB, itemName)
                                    return SetContains(ignoreB, itemName)
                                end)
                                if not ok3 then bump('bothfix_raise')
                                elseif v3 then bump('bothfix_ignored'); r.bothfix = r.bothfix + 1 end
                            end
                        end
                    end
                end
            end
        end
    end
end

table.sort(name_order)
rawset(c, 'names', #name_order)
for _, name in ipairs(name_order) do
    local r = per_name[name]
    if r.argfix > 0 then bump('names_argfix_ever_ignored') end
    if r.bothfix == r.n then bump('names_bothfix_always_ignored') end
    out:write(string.format('N %s %d %d %d %d\n', name, r.n, r.shipped, r.argfix, r.bothfix))
end

local keys = {}
for k in pairs(c) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
