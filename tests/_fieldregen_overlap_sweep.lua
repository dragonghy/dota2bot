-- Heavy corpus sweep for tests/test_fieldregen_family_overlap.lua, run as a
-- SUBPROCESS for the same reason as its siblings: a full-corpus drive that
-- rebuilds jmz_func once per hero-frame must not run on run_tests.lua's
-- long-lived heap.  The leading underscore keeps run_tests.lua from globbing it.
--
-- WHAT IS MEASURED, AND WHY IT IS NOT ALREADY MEASURED SOMEWHERE ELSE.
--
-- The supply-side family has FIVE claimants on one purchase, not four:
--
--   item_purchase_generic.lua:776   the `fieldregen` inline block
--   item_purchase_generic.lua:833   `fieldbuy` or `buyband` or `buytower` or `buyring`
--
-- The four at :833 were designed together and are disjoint BY CONSTRUCTION --
-- `buytower` inverts the tower clause, `buyring` inverts the hero ring, `buyband`
-- takes the strip above `fieldbuy`'s 0.55 ceiling -- and three of the four say so
-- in their own comments ("so the three arms are disjoint by construction", "so
-- the four arms stay disjoint by construction").  tests/_buytower_sweep.lua and
-- tests/_buyring_sweep.lua ASSERT it: `overlap_tower_buy`, `overlap_tower_hurt`
-- and their siblings must all be 0.
--
-- ⭐ THAT CLAIM IS TRUE AMONG THE FOUR AND SAYS NOTHING ABOUT THE FIFTH.  The
-- `fieldregen` block is 57 lines EARLIER in the same function, buys the same
-- `item_flask`, carries NO band floor (`< 0.45`, open below) and NONE of the
-- three surroundings clauses -- no 1600 hero ring, no 1200 tower ring, no
-- attribution window.  So it fires on frames every one of the four arms was
-- written to own, including the two (`buytower`, `buyring`) whose ENTIRE lever is
-- the inverted clause `fieldregen` never asks.  This file measures the overlap
-- the family's own disjointness tests structurally cannot see, because
-- `fieldregen` is not one of the four predicates they drive.
--
-- ⭐⭐ THE OVERLAP IS NOT MERELY CO-OCCURRENCE, IT IS PRE-EMPTION, AND THE
-- DIRECTION IS FIXED BY LINE ORDER.  Both blocks sit in one `ItemPurchaseThink`
-- body and share the same trailing engine guards, among them
-- `not IsThereHealingInStash(bot)` and `bot:FindItemSlot('item_flask') < 0`.
-- `fieldregen` runs FIRST.  When it buys, the salve goes to the stash (the block
-- only runs past 2500 units from the fountain), so on that frame and the ones
-- after it the four-arm `if` at :833 is refused by its own stash clause.  The
-- earlier block does not merely share the frame with the later one; it consumes
-- the purchase the later one exists to make.  `G.FIELDREGEN_LINE` and
-- `G.FAMILY_LINE` are parsed so the order is read, never assumed.
--
-- ⛔ WHAT THIS FILE CANNOT MEASURE, STATED RATHER THAN IMPLIED.  Same bound as
-- every sweep in this family, and it is the reason the counters below are named
-- `*_pred` and not `*_buys`: the engine guards that actually gate
-- ActionImmediate_PurchaseItem -- stash contents, gold, item stock, courier
-- distance from fountain, empty inventory slot -- are NOT readable from a
-- fixture, and gold is not networked into a .dem at all (GH #495).  So this file
-- measures PREDICATE overlap: frames where `fieldregen`'s fixture-readable
-- clauses and an arm's own predicate are true together.  It does not assert a
-- salve was bought, and the pre-emption paragraph above is read off the source
-- (line order + the shared stash clause), not driven.
--
-- ⛔ AND THE SECOND BOUND, WHICH IS THIS FILE'S ALONE.  `fieldregen` is an inline
-- block, not a helper, so it cannot be called the way the four arms can.  Its
-- clauses are RE-EXPRESSED here -- and therefore they can drift from the block
-- they claim to mirror.  The drift guard is `G.FR_*`: every constant and clause
-- name is parsed OUT of item_purchase_generic.lua and asserted against the
-- literals used below, so the day somebody edits the block this file goes red
-- instead of quietly measuring a predicate the tree no longer contains.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   O <fixture> <hero> <hp_frac> <arm>
--       one live frame where `fieldregen`'s readable predicate and <arm>'s own
--       predicate are BOTH true -- i.e. one frame the family's disjointness
--       tests count as belonging to exactly one arm and which a second, older
--       claimant reaches first.  Listed, not just counted, so "the overlap is
--       real" is a readable set rather than a difference of two totals.
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local BUY = 'bots/item_purchase_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local buysrc = read_file(BUY)

-- Line numbers of the two claimants, read rather than assumed: the whole
-- pre-emption argument is "the earlier block consumes the later block's
-- purchase", and that is a statement about ORDER.
local function line_of(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return -1 end
    local _, n = src:sub(1, at):gsub('\n', '')
    return n + 1
end
G.FIELDREGEN_LINE = line_of(buysrc, "J.IsSoakCandidate('fieldregen')")
G.FAMILY_LINE = line_of(buysrc, 'J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot)')
G.FIELDREGEN_FIRST = (G.FIELDREGEN_LINE > 0 and G.FAMILY_LINE > 0
    and G.FIELDREGEN_LINE < G.FAMILY_LINE) and 1 or 0

-- The `fieldregen` block itself, comments stripped so the long prose above it
-- cannot satisfy a single assertion below (the §EN mistake this family already
-- paid for once).
local frblock = nil
do
    local at = buysrc:find("if J.IsModeTurbo() and J.IsSoakCandidate('fieldregen')", 1, true)
    if at then
        local stop = buysrc:find('\n\tend', at, true) or #buysrc
        frblock = strip_comments(buysrc:sub(at, stop))
    end
end
G.FR_BLOCK = frblock and 1 or 0
G.FR_STRIPPED = (frblock and not frblock:find('--', 1, true)) and 1 or 0

-- ⭐ THE DRIFT GUARD.  Each clause this file re-expresses is parsed back out of
-- the block.  A literal that stops matching means the block moved and this
-- sweep is measuring a predicate that no longer exists.
G.FR_HP_HI = frblock and tonumber(frblock:match('J%.GetHP%(bot%) < ([%d%.]+)')) or -1
G.FR_HAS_LANING = (frblock and frblock:find('not J.IsInLaningPhase()', 1, true)) and 1 or 0
G.FR_HAS_ALIVE = (frblock and frblock:find('bot:IsAlive()', 1, true)) and 1 or 0
G.FR_HAS_FLASK = (frblock and frblock:find("bot:FindItemSlot('item_flask') < 0", 1, true))
    and 1 or 0
G.FR_HAS_TANGO = (frblock and frblock:find("bot:FindItemSlot('item_tango') < 0", 1, true))
    and 1 or 0
G.FR_HAS_STASH = (frblock and frblock:find('not IsThereHealingInStash(bot)', 1, true))
    and 1 or 0
-- ⭐⭐ THE ABSENCES, AND THEY ARE THE LEVER OF THIS WHOLE FILE.  `fieldregen`
-- overlaps `buytower` and `buyring` precisely because it does NOT ask the two
-- clauses those arms invert.  Asserted as facts about the source in BOTH
-- directions: a future edit that ADDS a ring or tower clause to the block would
-- shrink the overlap, and this file must go red then rather than keep reporting
-- an overlap it no longer measures.
G.FR_NO_RING = (frblock and not frblock:find('GetNearbyHeroes', 1, true)) and 1 or 0
G.FR_NO_TOWER = (frblock and not frblock:find('GetNearbyTowers', 1, true)) and 1 or 0
G.FR_NO_ATTR = (frblock and not frblock:find('WasRecentlyDamagedByAnyHero', 1, true))
    and 1 or 0
G.FR_NO_HP_FLOOR = (frblock and not frblock:match('J%.GetHP%(bot%) > [%d%.]+')) and 1 or 0
-- Both claimants buy the SAME item.  If they ever stop, the pre-emption argument
-- dies and this file should say so rather than keep counting overlaps.
local nFlaskBuys = 0
for _ in buysrc:gmatch("ActionImmediate_PurchaseItem%('item_flask'%)") do
    nFlaskBuys = nFlaskBuys + 1
end
G.FLASK_PURCHASE_SITES = nFlaskBuys
-- The shared guard that carries the pre-emption, parsed from BOTH blocks.
local famblock = nil
do
    local at = buysrc:find('if ( J.ShouldFieldBuyRegen(bot)', 1, true)
    if at then
        local stop = buysrc:find('\n\tend', at, true) or #buysrc
        famblock = strip_comments(buysrc:sub(at, stop))
    end
end
G.FAM_BLOCK = famblock and 1 or 0
G.FAM_HAS_STASH = (famblock and famblock:find('not IsThereHealingInStash(bot)', 1, true))
    and 1 or 0
G.SHARED_STASH_GUARD = (G.FR_HAS_STASH == 1 and G.FAM_HAS_STASH == 1) and 1 or 0

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
-- Zero-initialised so "the bucket was never reached" and "the bucket measured
-- zero" are never the same thing to the parser (the GH #171 shape).
for _, k in ipairs({ 'fixtures', 'live', 'turbo', 'fr_pred',
    'arm_fieldbuy', 'arm_buyband', 'arm_buytower', 'arm_buyring',
    'overlap_fieldbuy', 'overlap_buyband', 'overlap_buytower', 'overlap_buyring',
    'overlap_any', 'arm_leak', 'probe_runs', 'fr_pred_err', 'arm_err' }) do
    bump(k, 0)
end

local overlaps = {}

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local sArmed = nil
                    J.IsSoakCandidate = function(sId)
                        return sArmed ~= nil and sId == sArmed
                    end

                    if J.IsModeTurbo() then
                        bump('turbo')

                        -- `fieldregen`'s fixture-readable clauses, in the block's
                        -- own order.  The unreadable engine guards (stash, gold,
                        -- stock, courier distance, empty slot, modifiers) are
                        -- omitted, which makes this predicate a SUPERSET of the
                        -- block's real domain -- stated, not hidden: an overlap
                        -- counted here is an upper bound on the frames the block
                        -- actually reaches.
                        local okfr, bFR = pcall(function()
                            return (not J.IsInLaningPhase())
                                and bot:IsAlive()
                                and J.GetHP(bot) < 0.45
                                and bot:FindItemSlot('item_flask') < 0
                                and bot:FindItemSlot('item_tango') < 0
                        end)
                        if not okfr then bump('fr_pred_err') end
                        bFR = okfr and bFR or false
                        if bFR then bump('fr_pred') end

                        -- Each arm driven ALONE, exactly as its own sweep drives
                        -- it: a stub arming more than one id would let a sibling
                        -- move the answer while the frame is still attributed to
                        -- this arm (the M8 survivor of the 'stayattr' round).
                        local arms = {
                            { id = 'fieldbuy', fn = function() return J.ShouldFieldBuyRegen(bot) end },
                            { id = 'buyband', fn = function() return J.ShouldFieldBuyRegenHurt(bot) end },
                            { id = 'buytower', fn = function() return J.ShouldFieldBuyRegenTower(bot) end },
                            { id = 'buyring', fn = function() return J.ShouldFieldBuyRegenRing(bot) end },
                        }
                        for _, a in ipairs(arms) do
                            sArmed = a.id
                            bump('probe_runs')
                            -- The arming must be ONE id wide.
                            for _, other in ipairs({ 'fieldregen', 'fieldsip',
                                'fieldcreep', 'bagsalve', 'buyband', 'buytower',
                                'buyring', 'fieldbuy' }) do
                                if other ~= a.id and J.IsSoakCandidate(other) then
                                    bump('arm_leak')
                                end
                            end
                            local oka, bArm = pcall(a.fn)
                            if not oka then bump('arm_err') end
                            bArm = oka and bArm or false
                            if bArm then bump('arm_' .. a.id) end
                            if bArm and bFR then
                                bump('overlap_' .. a.id)
                                overlaps[#overlaps + 1] = string.format(
                                    'O %s %s %.4f %s',
                                    path:match('([^/]+)%.lua$'), u.name,
                                    J.GetHP(bot), a.id)
                            end
                        end
                        sArmed = nil
                        if bFR then
                            local bAny = false
                            for _, a in ipairs(arms) do
                                sArmed = a.id
                                local oka, bArm = pcall(a.fn)
                                if oka and bArm then bAny = true end
                            end
                            sArmed = nil
                            if bAny then bump('overlap_any') end
                        end
                    end
                end
            end
        end
    end
end

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

local ck = {}
for k in pairs(c) do ck[#ck + 1] = k end
table.sort(ck)
for _, k in ipairs(ck) do out:write(string.format('C %s %d\n', k, c[k])) end

for _, line in ipairs(overlaps) do out:write(line .. '\n') end
out:write('DONE\n')
