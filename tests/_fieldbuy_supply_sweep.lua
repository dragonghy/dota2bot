-- Corpus sweep helper for tests/test_replay_260822_fieldbuy_supply.lua.
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$' and
-- this file is meant to be run in its own process by that test via io.popen
-- (strategy charter 0q: driving the whole corpus through a big shipped file
-- inside the suite's own process churns GC on a heap a thousand earlier tests
-- have already grown, and the cost then depends on where the calling file
-- lands in the alphabet).
--
-- Usage: lua5.1 tests/_fieldbuy_supply_sweep.lua
-- Emits machine-readable lines on stdout:
--   COUNT fixtures=<n> live=<n> band=<n> band_dry=<n> situation=<n>
--         has=<n> dry=<n> unarmed=<n>
--   HOLE laning=<n> level6plus=<n> both=<n> hpceil=<n>
--   SPLIT dry_split=<n> rescuable=<n> stuck=<n>
--   BAG flask=<n> flip=<n> other=<n> other_flip=<n> sit_flip=<n> victim_neg=<n>
--   DRY <fixture> <hero> <hp> <level> <laning 0|1>
--
-- Every number here is read off the SHIPPED helpers running on real frames.
-- The buckets are a partition by construction (situation == has + dry) and the
-- calling test asserts that, so the two halves of owner priority P2 cannot
-- silently drift apart.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = f end
    end
    p:close()
    table.sort(files)
    return files
end

local n = {
    live = 0, band = 0, band_dry = 0, situation = 0,
    has = 0, dry = 0, unarmed = 0,
}
local hole = { laning = 0, level6plus = 0, both = 0, hpceil = 0 }
-- GH #123 asked to narrow the purchase gate from 9 slots to the 6 usable ones.
-- `split` counts the frames that change would silence: a dry domain frame whose
-- six main slots are all full but whose backpack has room, i.e. exactly where
-- the delivered salve lands in the backpack. `rescuable` then asks the shipped
-- rescuer's own question -- does TrySwapInvItemForFlask have a main-slot item it
-- is allowed to swap out (GetMainInvLessValItemSlot ~= -1)? -- so the size of
-- the proposed fix's blast radius and the reach of the existing remedy are
-- counted on the same frames. See tests/test_fieldbuy_backpack_rescuer.lua.
local split = { dry_split = 0, rescuable = 0, stuck = 0 }
-- [bagsalve, GH #123, 2026-08-23] The other end of the same asymmetry: instead
-- of narrowing the nine-slot purchase gate to six, widen the six-slot holding
-- predicate to see the ONE backpack item a shipped un-gated swapper can bring
-- up (item_flask). `flask` counts live frames carrying one in slots 6..8;
-- `flip` counts frames whose J.HasFieldRegenSource answer changes when
-- 'bagsalve' is armed; `other` counts frames carrying a backpacked
-- tango/tango_single/faerie_fire/bottle with no main-slot heal -- the
-- population that must NOT flip, because nothing in bots/ swaps those in --
-- and `other_flip` is how many of them did (an invariant zero, not a ratchet).
-- `sit_flip` is the same flip restricted to the situation domain, i.e. how many
-- frames actually move between the two decision-side halves. `victim_neg`
-- counts frames where the shipped rescuer's own swap-victim read
-- (GetMainInvLessValItemSlot) answers -1: that is the reachability leg of the
-- argument, and it is a 0DIR-style one-directional read on this corpus --
-- reported, not folded into a clause. See tests/test_bagsalve_backpack_source.lua.
local bag = { flask = 0, flip = 0, other = 0, other_flip = 0, sit_flip = 0,
              victim_neg = 0 }
local dry_rows = {}

local BAG_OTHER = {
    item_tango = true, item_tango_single = true,
    item_faerie_fire = true, item_bottle = true,
}

local function empty_slot_count(bot, lo, hi)
    local c = 0
    for i = lo, hi do
        if bot:GetItemInSlot(i) == nil then c = c + 1 end
    end
    return c
end

local files = fixture_files()

for _, path in ipairs(files) do
    -- One load to learn the roster, then one load per hero so each subject
    -- drives its own frame (the loader rebuilds vision from that hero's team).
    local ok0, names = pcall(function()
        local _, _, heroes = rf.load('tests/fixtures/' .. path)
        local out = {}
        for name in pairs(heroes) do out[#out + 1] = name end
        table.sort(out)
        return out
    end)
    if not ok0 then
        io.write('ERR ' .. path .. ' roster ' .. tostring(names) .. '\n')
        names = {}
    end

    for _, hero in ipairs(names) do
        local ok, err = pcall(function()
            local J, bot = rf.load('tests/fixtures/' .. path, hero)
            if bot == nil or not bot:IsAlive() then return end
            n.live = n.live + 1

            -- Nothing armed: the gate must be shut on every single frame.
            J.IsSoakCandidate = function() return false end
            if J.ShouldFieldBuyRegen(bot) then n.unarmed = n.unarmed + 1 end

            J.IsSoakCandidate = function(id) return id == 'fieldbuy' end

            local nHP = J.GetHP(bot)
            local bHas = J.HasFieldRegenSource(bot) == true
            local bSit = J.IsFieldRegenSituation(bot) == true

            -- [bagsalve] Same frame, same shipped helper, one id armed on top.
            J.IsSoakCandidate = function(id)
                return id == 'fieldbuy' or id == 'bagsalve'
            end
            local bHasBag = J.HasFieldRegenSource(bot) == true
            J.IsSoakCandidate = function(id) return id == 'fieldbuy' end

            local bBagFlask, bBagOther = false, false
            for i = 6, 8 do
                local hItem = bot:GetItemInSlot(i)
                if hItem ~= nil then
                    local sName = hItem:GetName()
                    if sName == 'item_flask' then bBagFlask = true end
                    if BAG_OTHER[sName] then bBagOther = true end
                end
            end
            if bBagFlask then bag.flask = bag.flask + 1 end
            if bHasBag and not bHas then bag.flip = bag.flip + 1 end
            if bBagOther and not bHas then
                bag.other = bag.other + 1
                if bHasBag and not bBagFlask then
                    bag.other_flip = bag.other_flip + 1
                end
            end
            if bSit and bHasBag and not bHas then bag.sit_flip = bag.sit_flip + 1 end
            local nVictimAll = J.Item.GetMainInvLessValItemSlot(bot)
            if nVictimAll == nil or nVictimAll < 0 then
                bag.victim_neg = bag.victim_neg + 1
            end

            if nHP >= 0.18 and nHP <= 0.55 then
                n.band = n.band + 1
                if not bHas then n.band_dry = n.band_dry + 1 end
            end

            if bSit then
                n.situation = n.situation + 1
                if bHas then
                    n.has = n.has + 1
                else
                    n.dry = n.dry + 1
                    local bLaning = J.IsInLaningPhase() == true
                    local nLevel = bot:GetLevel()
                    if bLaning then hole.laning = hole.laning + 1 end
                    if nLevel >= 6 then hole.level6plus = hole.level6plus + 1 end
                    if bLaning and nLevel >= 6 then hole.both = hole.both + 1 end
                    if nHP >= 0.45 then hole.hpceil = hole.hpceil + 1 end
                    if empty_slot_count(bot, 0, 5) == 0
                        and empty_slot_count(bot, 6, 8) >= 1
                    then
                        split.dry_split = split.dry_split + 1
                        local nVictim = J.Item.GetMainInvLessValItemSlot(bot)
                        if nVictim ~= nil and nVictim >= 0 then
                            split.rescuable = split.rescuable + 1
                        else
                            split.stuck = split.stuck + 1
                        end
                    end
                    dry_rows[#dry_rows + 1] = string.format(
                        'DRY %s %s %.4f %d %d',
                        path, hero, nHP, nLevel, bLaning and 1 or 0)
                end
            end
        end)
        if not ok then
            io.write('ERR ' .. path .. ' ' .. hero .. ' ' .. tostring(err) .. '\n')
        end
    end
end

io.write(string.format(
    'COUNT fixtures=%d live=%d band=%d band_dry=%d situation=%d has=%d dry=%d unarmed=%d\n',
    #files, n.live, n.band, n.band_dry, n.situation, n.has, n.dry, n.unarmed))
io.write(string.format('HOLE laning=%d level6plus=%d both=%d hpceil=%d\n',
    hole.laning, hole.level6plus, hole.both, hole.hpceil))
io.write(string.format('SPLIT dry_split=%d rescuable=%d stuck=%d\n',
    split.dry_split, split.rescuable, split.stuck))
io.write(string.format(
    'BAG flask=%d flip=%d other=%d other_flip=%d sit_flip=%d victim_neg=%d\n',
    bag.flask, bag.flip, bag.other, bag.other_flip, bag.sit_flip, bag.victim_neg))
for _, l in ipairs(dry_rows) do io.write(l .. '\n') end
