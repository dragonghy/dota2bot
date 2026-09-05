-- Heavy corpus sweep for tests/test_staybag_backpack_salve.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame must
-- not run on run_tests.lua's long-lived heap.  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  J.ShouldStayAndRegen is PROMOTED -- live in every turbo
-- game.  Every stock read on that path stops at slot 5: the shipped `bHasFlask`
-- asks J.IsItemAvailable (`slot >= 0 and slot <= 5`), and the 'staysrc' widening
-- asks J.HasFieldRegenSource (`for i = 0, 5`).  A salve in the BACKPACK is
-- therefore read as "carries nothing", the decision falls through to the gold
-- term, and a hurt, unchased bot is released to go home -- owner priority P2.
-- The 'staybag' lever reads slots 6-8 for a salve, and only a salve: the shipped,
-- ungated `TrySwapInvItemForFlask()` swaps a backpacked flask into a main slot
-- and there is no such swapper for the other three consumables.
--
-- ⭐ THE COLUMN THIS FILE EXISTS FOR, and it is not the flip count.  A backpacked
-- salve is ALREADY reachable from this function -- but only with 'staysrc' AND
-- 'bagsalve' armed TOGETHER ('staysrc' to get J.HasFieldRegenSource called,
-- 'bagsalve' to make its backpack block run).  Each SITE names exactly one id, so
-- this is not the 'pullcad' shape anyone greps for; it is that trap spread over a
-- CALL.  `flips_staysrc` / `flips_bagsalve` / `flips_pair` measure it directly:
-- if the pair flips frames that neither single arm flips, then a single-arm
-- isolation wave reads a correct zero for both ids and the behaviour is
-- unbuyable one lever at a time.  `pair_gain_eq_flips` cross-checks that the
-- standalone lever buys exactly the frames that two-id path buys.
--
-- ⭐⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  Every answer comes from the
-- shipped function with J.IsSoakCandidate stubbed.  Nothing here re-implements
-- the decision.  The prefix buckets ARE evaluated separately -- that is what
-- makes "the clause was reached" and "the clause vetoed" two different numbers --
-- and the two routes are cross-checked: `flips` (driven, from the function's own
-- return value) and `blocked_with_bag` (bucketed, from the prefix walk) must be
-- EQUAL, and the test asserts that.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  `flip_true_to_false` counts frames
-- where arming turns a TRUE into a FALSE.  Widening `bHasRegen` can only remove
-- vetoes, so that counter must be 0; the test asserts it.
--
-- ⚠️ THE GOLD TERM IS NOT MEASURABLE HERE, AND THAT IS MEASURED TOO.  Gold is not
-- networked into a .dem (tools/batch_test/behavioral/hometp_invfull_lag.py,
-- honest-bounds block), so `bot:GetGold()` falls through to mock/bot_api.lua's
-- `^Get -> 0` scalar (GH #495).  `gold_nonzero` must therefore read 0 over the
-- whole corpus -- asserted downstream, because the honest bound this file
-- publishes (the measured flip set is the GOLD-POOR SUPERSET of the live one) is
-- only true while that holds.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac>
--       one live frame where J.ShouldStayAndRegen flips false -> true
--   B <fixture> <hero> <hp_frac> <in_band 0|1> <has_main_src 0|1>
--       one live frame carrying a backpacked salve (every carrier, in band or
--       not -- the anti-vacuum column)
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'
local ROAM = 'bots/mode_team_roam_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction ', at + 10) or #src
    return src:sub(at, stop)
end

-- Every structural fact below is a claim about CODE, and this lever ships with a
-- long comment naming J.IsSoakCandidate, the sibling ids, the slot numbers and
-- the swapper in prose.  Reading the raw block would let the COMMENT satisfy the
-- assertions (the §EN mistake, and the M15 near-miss of the sibling round).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local src = read_file(JMZ)
local stay = strip_comments(block(src, 'function J.ShouldStayAndRegen( bot )'))
local source = strip_comments(block(src, 'function J.HasFieldRegenSource( bot )'))
local avail = strip_comments(block(src, 'function J.IsItemAvailable( sItemName )'))
G.STAY = stay and 1 or 0
G.SRC = source and 1 or 0
G.AVAIL = avail and 1 or 0
G.STAY_SOAKID = (stay and stay:find("J.IsSoakCandidate( 'staybag' )", 1, true))
    and 1 or 0
-- Did the stripping actually HAPPEN? Asserted as its own fact rather than left
-- to be implied by some count coming out at the expected number. It was implied
-- once -- an exact `STAY_NIDS == 4` was the only thing catching the
-- "stop stripping" mutant -- and when that total was relaxed to a floor (for the
-- unrelated and correct reason that an id total is a ratchet trap, not an
-- invariant), the mutant went from CAUGHT to SURVIVED with nothing else in the
-- file changing. A guard that only works while an adjacent number happens to be
-- exact is not a guard.
G.STAY_STRIPPED = (stay and not stay:find('--', 1, true)) and 1 or 0
G.SRC_STRIPPED = (source and not source:find('--', 1, true)) and 1 or 0

-- The 'pullcad' trap is TWO IDS IN ONE CONDITION, not two ids in one function.
-- This function now carries FOUR independent levers, so the total is 4 and the
-- per-condition maximum is 1 -- and it is the second number that is the
-- invariant.
local nIds = 0
if stay then for _ in stay:gmatch('IsSoakCandidate') do nIds = nIds + 1 end end
G.STAY_NIDS = nIds
local nMax = 0
if stay then
    for cond in stay:gmatch('if(.-)then') do
        local n = 0
        for _ in cond:gmatch('IsSoakCandidate') do n = n + 1 end
        if n > nMax then nMax = n end
    end
end
G.STAY_IDS_MAX_PER_COND = nMax

-- APPENDED, NOT INSERTED: with this id un-armed BOTH sibling levers must evaluate
-- byte-identically, which is only true while this block sits after them.
-- Positions are compared inside the same stripped block, so a comment mentioning
-- any id cannot move them.
local at_src = stay and stay:find("'staysrc'", 1, true)
local at_btl = stay and stay:find("'staybottle'", 1, true)
local at_bag = stay and stay:find("'staybag'", 1, true)
G.STAY_ORDER_OK = (at_src and at_btl and at_bag and at_bag > at_btl
    and at_btl > at_src) and 1 or 0

-- The slot ceiling this lever is about, parsed on all three shipped readers.
-- `STAY_SHIPPED_SLOTREADS` is counted on the two lines that compute `bHasFlask`
-- and is bounded by the NEXT STATEMENT, not by a blank line: stripping comments
-- turns this lever's own comment block into blank lines, so a `.-\n\n` span would
-- swallow the lever itself and report the shipped side as already reading the
-- backpack (the M15 self-injury of the 'staybottle' round, made a mutant there).
local shipped_supply = stay and stay:match('local bHasFlask.-local bHasRegen')
local nSlotReads = 0
if shipped_supply then
    for _ in shipped_supply:gmatch('GetItemInSlot') do
        nSlotReads = nSlotReads + 1
    end
end
G.STAY_SHIPPED_SLOTREADS = nSlotReads
G.STAY_SHIPPED_USES_AVAIL =
    (shipped_supply and shipped_supply:find('IsItemAvailable', 1, true))
    and 1 or 0
G.AVAIL_MAX_SLOT = avail and tonumber(avail:match('slot <= (%d+)')) or -1
G.SRC_MAIN_LOOP_HI = source and tonumber(source:match('for i = 0, (%d+) do')) or -1
-- The other half of the two-id path: J.HasFieldRegenSource's backpack block
-- exists and is gated on its own id, so reaching a backpacked salve from
-- J.ShouldStayAndRegen today needs BOTH ids armed.
G.SRC_HAS_BAGSALVE =
    (source and source:find("J.IsSoakCandidate( 'bagsalve' )", 1, true)) and 1 or 0
-- The whole justification for widening by exactly one item: a SHIPPED, UNGATED
-- swapper that moves a backpacked flask into a main slot.  Read off the raw file
-- for existence and off the stripped body for the gate count, so a comment can
-- neither create it nor hide a gate in it.
local swap_raw = block(read_file(ROAM), 'function TrySwapInvItemForFlask()')
local swap = strip_comments(swap_raw)
G.SWAP_EXISTS = swap and 1 or 0
G.SWAP_READS_BACKPACK =
    (swap and swap:find('ITEM_SLOT_TYPE_BACKPACK', 1, true)) and 1 or 0
G.SWAP_NIDS = 0
if swap then
    for _ in swap:gmatch('IsSoakCandidate') do G.SWAP_NIDS = G.SWAP_NIDS + 1 end
end
-- ...and NO such swapper for the three consumables this lever deliberately does
-- not count.  Parsed as a count of swapper functions naming each item.
local roam = strip_comments(read_file(ROAM))
G.SWAP_TANGO = roam:find('FindItemSlot(\'item_tango\')', 1, true) and 1 or 0
G.SWAP_BOTTLE = roam:find('FindItemSlot(\'item_bottle\')', 1, true) and 1 or 0

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

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
for _, k in ipairs({ 'fixtures', 'live', 'turbo', 'hp_band', 'supply_tested',
    'blocked_supply', 'blocked_with_bag', 'blocked_no_bag', 'ship_true',
    'arm_true', 'flips', 'flip_true_to_false', 'arm_leak', 'gold_zero',
    'gold_nonzero', 'raises', 'bag_carriers', 'bag_out_of_band',
    'bag_with_main_src', 'flips_staysrc', 'flips_bagsalve', 'flips_pair',
    'flips_both_levers', 'pair_gain', 'pair_gain_not_flips' }) do
    rawset(c, k, 0)
end

--- A salve in the backpack -- the thing this lever reads, measured independently
--- of the lever so "the corpus has none" can never read the same as "the lever
--- does nothing".
local function bag_salve(bot)
    for i = 6, 8 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil and hItem:GetName() == 'item_flask' then return true end
    end
    return false
end

--- What J.HasFieldRegenSource's MAIN loop can see on this frame.  This is the
--- root of the disjointness claim: if a backpack-salve frame also carries a
--- main-slot source then 'staysrc' alone already flips it and this lever cannot
--- be credited for it.
local function main_src(bot)
    for i = 0, 5 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil then
            local sName = hItem:GetName()
            if sName == 'item_flask' or sName == 'item_tango'
                or sName == 'item_tango_single' or sName == 'item_faerie_fire'
            then
                return true
            end
            if sName == 'item_bottle'
                and (tonumber(hItem:GetCurrentCharges()) or 0) > 0
            then
                return true
            end
        end
    end
    return false
end

local HP_LO = tonumber(stay:match('nHP < ([%d%.]+)'))
local HP_HI = tonumber(stay:match('nHP > ([%d%.]+)'))
local RING = tonumber(stay:match('GetNearbyHeroes%( bot, (%d+), true'))
local WINDOW = tonumber(stay:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)'))
G.STAY_HP_LO, G.STAY_HP_HI, G.STAY_RING, G.STAY_CHASE_WINDOW =
    HP_LO, HP_HI, RING, WINDOW
for _, k in ipairs({ 'STAY_HP_LO', 'STAY_HP_HI', 'STAY_RING',
    'STAY_CHASE_WINDOW' }) do
    out:write(string.format('G %s %s\n', k, tostring(G[k])))
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local armed = false
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'staybag'
                    end

                    -- The gold term, driven rather than assumed.  See the
                    -- honest-bound block at the top of this file.
                    if (tonumber(bot:GetGold()) or 0) == 0 then
                        bump('gold_zero')
                    else
                        bump('gold_nonzero')
                    end

                    local nHP = J.GetHP(bot)
                    local bTurbo = J.IsModeTurbo() and true or false
                    if bTurbo then bump('turbo') end
                    local bBand = (nHP >= HP_LO and nHP <= HP_HI)
                    if bBand then bump('hp_band') end
                    local bBag = bag_salve(bot)
                    local bMain = main_src(bot)
                    if bBag then
                        bump('bag_carriers')
                        if not bBand then bump('bag_out_of_band') end
                        if bMain then bump('bag_with_main_src') end
                        out:write(string.format('B %s %s %.4f %d %d\n',
                            path:match('([^/]+)%.lua$'), u.name, nHP,
                            bBand and 1 or 0, bMain and 1 or 0))
                    end

                    local ok1, shipped = pcall(J.ShouldStayAndRegen, bot)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them all
                    -- would let any other live id move this guard's answer while
                    -- the flip is still attributed to this lever (the M8 survivor
                    -- of the 'stayattr' round).  Asserted 0 downstream; the three
                    -- siblings that would silently widen the same clause are
                    -- named explicitly.
                    if J.IsSoakCandidate('staysrc')
                        or J.IsSoakCandidate('bagsalve')
                        or J.IsSoakCandidate('staybottle')
                        or J.IsSoakCandidate('stayattr') then
                        bump('arm_leak')
                    end
                    local ok2, arm = pcall(J.ShouldStayAndRegen, bot)

                    -- The two-id-path column (the reason this lever is standalone
                    -- instead of a reuse of J.HasFieldRegenSource).  Drive each
                    -- single arm and then the pair.
                    J.IsSoakCandidate = function(sId) return sId == 'staysrc' end
                    local ok3, srconly = pcall(J.ShouldStayAndRegen, bot)
                    J.IsSoakCandidate = function(sId) return sId == 'bagsalve' end
                    local ok4, bagonly = pcall(J.ShouldStayAndRegen, bot)
                    J.IsSoakCandidate = function(sId)
                        return sId == 'staysrc' or sId == 'bagsalve'
                    end
                    local ok5, pair = pcall(J.ShouldStayAndRegen, bot)
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'staybag'
                    end
                    armed = false

                    if not (ok1 and ok2 and ok3 and ok4 and ok5) then
                        bump('raises')
                    else
                        if shipped then bump('ship_true') end
                        if arm then bump('arm_true') end
                        if srconly and not shipped then bump('flips_staysrc') end
                        if bagonly and not shipped then bump('flips_bagsalve') end
                        if pair and not shipped then bump('flips_pair') end
                        if arm and not shipped and srconly and not shipped then
                            bump('flips_both_levers')
                        end
                        -- What the PAIR buys that neither single arm buys.  If
                        -- this is nonzero, the behaviour exists on the tree today
                        -- but no single-arm wave can see it.
                        if pair and not shipped and not srconly and not bagonly then
                            bump('pair_gain')
                            if not arm then bump('pair_gain_not_flips') end
                        end

                        -- Prefix walk: did control actually REACH the supply
                        -- clause?  Every earlier clause of the function, in the
                        -- function's own order, with every id un-armed (so the
                        -- chase line is the shipped unattributed read -- this
                        -- census does not arm 'stayattr').
                        local bReach = bTurbo and bBand
                            and not bot:WasRecentlyDamagedByAnyHero(WINDOW)
                            and #J.GetNearbyHeroes(bot, RING, true,
                                BOT_MODE_NONE) == 0
                        if bReach then
                            bump('supply_tested')
                            if not shipped then
                                -- Reached the clause and the function still
                                -- answered false: by construction the supply
                                -- clause is the only veto left.
                                bump('blocked_supply')
                                if bBag then
                                    bump('blocked_with_bag')
                                    out:write(string.format('F %s %s %.4f\n',
                                        path:match('([^/]+)%.lua$'), u.name, nHP))
                                else
                                    bump('blocked_no_bag')
                                end
                            end
                        end

                        if arm and not shipped then
                            bump('flips')
                        elseif shipped and not arm then
                            -- Must never happen: widening bHasRegen can only
                            -- remove vetoes.  Asserted 0 downstream.
                            bump('flip_true_to_false')
                        end
                    end
                end
            end
        end
    end
end

local ck = {}
for k in pairs(c) do ck[#ck + 1] = k end
table.sort(ck)
for _, k in ipairs(ck) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
