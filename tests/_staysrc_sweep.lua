-- Heavy corpus sweep for tests/test_staysrc_field_supply.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap. The leading underscore keeps
-- run_tests.lua from globbing it.
--
-- WHAT IS MEASURED.  J.ShouldStayAndRegen is PROMOTED -- live in every turbo
-- game.  Its own docstring states the approved supply condition as "can afford
-- a regen consumable (gold >= 90) OR ALREADY CARRIES ONE", and the code
-- implements "already carries one" as item_flask alone.  A tango, a
-- tango_single, a faerie fire or a charged bottle in a main slot therefore read
-- as "carries nothing", the decision falls to the gold term, and a hurt,
-- unchased bot holding three tangoes and 40 gold is released to go home -- the
-- trip owner priority P2 forbids.  The 'staysrc' lever widens that read to
-- J.HasFieldRegenSource, the sibling the gated `stayfield` family already uses.
--
-- This census is the DOMAIN PRICE of that lever on the real-frame corpus:
--   * how many live hero frames REACH the supply clause at all (every earlier
--     clause of the function having passed);
--   * how many of those the supply clause vetoes;
--   * of those, how many carry a real field regen source in a real item slot
--     (the frames the lever is about) versus how many carry nothing (where the
--     lever is completely inert).
--
-- ⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  The lever carries a real soak id,
-- so both answers come from the shipped function with J.IsSoakCandidate stubbed
-- to false and then to true.  Nothing here re-implements the decision.  The
-- prefix buckets ARE evaluated separately -- that is what makes "the clause was
-- reached" and "the clause vetoed" two different numbers -- and the two paths
-- are cross-checked: `flips` (driven, from the function's own return value) and
-- `blocked_with_src` (bucketed, from the prefix walk) must be EQUAL, and the
-- test asserts that.  Two independent routes to one number, so a drift in
-- either shows up as a red instead of as agreement.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  `flip_true_to_false` counts frames
-- where arming turns a TRUE into a FALSE.  Widening `bHasRegen` can only remove
-- vetoes, so that counter must be 0; downstream asserts it.
--
-- ⚠️ THE GOLD TERM IS NOT MEASURABLE HERE, AND THAT IS MEASURED TOO.  Gold is
-- not networked into a .dem (tools/batch_test/behavioral/hometp_invfull_lag.py,
-- honest-bounds block), so no fixture carries it and `bot:GetGold()` falls
-- through to mock/bot_api.lua's `^Get -> 0` scalar (GH #495).  `gold_nonzero`
-- must therefore read 0 over the whole corpus -- asserted downstream, because
-- the honest bound this file publishes (the measured flip set is the GOLD-POOR
-- SUPERSET of the live one) is only true while that holds.  The day a fixture
-- carries real gold, that assertion goes red and the bound gets re-derived
-- instead of quietly staying in a report.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac> <source_item>
--       one live frame where J.ShouldStayAndRegen flips false -> true
--   P <fixture> <hero> <hp_frac>
--       one live frame that NEITHER id flips alone and the PAIR does (the
--       and-of-vetoes column -- see the block at the third drive below)
--   N <fixture> <hero> <hp_frac>
--       one live frame the supply clause vetoes with NO source carried (the
--       lever's own inert column -- the anti-vacuum control for "the situation
--       is common but the lever is narrow")
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

-- Every structural fact below is a claim about CODE, and this lever ships with
-- a long comment naming J.IsSoakCandidate, J.HasFieldRegenSource, item names
-- and the gold constant in prose.  Reading the raw block would let the COMMENT
-- satisfy the assertions -- the §EN mistake, where a counter that must read 0
-- read 1 off a comment explaining why it was 0.
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local src = read_file(JMZ)
local stay = strip_comments(block(src, 'function J.ShouldStayAndRegen( bot )'))
local source = strip_comments(
    block(src, 'function J.HasFieldRegenSource( bot )'))
G.STAY = stay and 1 or 0
G.SRC = source and 1 or 0
-- The lever itself, as parsed facts.
G.STAY_SOAKID = (stay and stay:find("J.IsSoakCandidate( 'staysrc' )", 1, true))
    and 1 or 0
G.STAY_CALLS_SRC = (stay and stay:find('J.HasFieldRegenSource( bot )', 1, true))
    and 1 or 0
-- The 'pullcad' trap is TWO IDS IN ONE CONDITION, not two ids in one function:
-- a conjunction of ids freezes FALSE the day either is promoted, while
-- check_armed_wiring.py still calls it WIRED.  This function now carries two
-- INDEPENDENT levers -- 'stayattr' on the chase clause, 'staysrc' on the supply
-- clause -- so the total is 2 and the per-condition maximum is 1, and it is the
-- second number that is the invariant.  (The sibling file measured the total
-- until this lever landed; see tests/test_stayattr_global_ult.lua.)
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
-- The NESTING this lever creates, registered rather than assumed: the callee
-- carries a gate of its own ('bagsalve').  Census row (A) -- un-armed it only
-- ever admits one more backpack slot, so the un-armed callee is the shipped
-- answer.  If this number moves, the (A) classification needs re-reading.
local nInner = 0
if source then for _ in source:gmatch('IsSoakCandidate') do nInner = nInner + 1 end end
G.SRC_NIDS = nInner
-- The constants the shipped function actually uses, parsed so the test asserts
-- the tree's numbers and not this file's memory of them.
G.STAY_GOLD = stay and tonumber(stay:match('GetGold%(%) < (%d+)'))
G.STAY_RING = stay and tonumber(stay:match('GetNearbyHeroes%( bot, (%d+), true'))
G.STAY_HP_LO = stay and tonumber(stay:match('nHP < ([%d%.]+)'))
G.STAY_HP_HI = stay and tonumber(stay:match('nHP > ([%d%.]+)'))
G.STAY_CHASE_WINDOW = stay
    and tonumber(stay:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)'))
-- The asymmetry, as two parsed numbers rather than as prose: how many distinct
-- consumable ITEM names the shipped supply read names, and how many the sibling
-- names.  1 vs 5 is the finding.
local function count_items(s)
    local n = 0
    if s == nil then return 0 end
    for _, nm in ipairs({ 'item_flask', 'item_tango', 'item_tango_single',
        'item_faerie_fire', 'item_bottle' }) do
        if s:find("'" .. nm .. "'", 1, true) then n = n + 1 end
    end
    return n
end
-- Counted on the shipped supply read only -- the two lines that compute
-- `bHasFlask` -- so the lever's own call to the sibling cannot inflate it.
G.STAY_SHIPPED_ITEMS = count_items(stay and stay:match('local bHasFlask.-\n\n'))
G.SRC_ITEMS = count_items(source)
-- The docstring claim this lever is measured against.  Deliberately read off
-- the RAW source (it is a comment; that is the point) and pinned so that
-- deleting the sentence turns the finding red instead of dissolving it.
G.DOC_CARRIES = src:find('or already carries one', 1, true) and 1 or 0

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
    'blocked_supply', 'blocked_with_src', 'blocked_no_src', 'ship_true',
    'arm_true', 'flips', 'flip_true_to_false', 'arm_leak', 'gold_zero',
    'gold_nonzero', 'raises', 'attr_true', 'both_true', 'flips_attr',
    'flips_pair_only', 'pair_raises' }) do
    rawset(c, k, 0)
end

-- Which item in a main slot answers J.HasFieldRegenSource TRUE.  Reported for
-- the flip rows only, so that a pinned frame can be chosen by what actually
-- carries it rather than by position in the corpus.
local function source_item(bot)
    for i = 0, 5 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil then
            local sName = hItem:GetName()
            if sName == 'item_flask' or sName == 'item_tango'
                or sName == 'item_tango_single' or sName == 'item_faerie_fire'
            then
                return sName
            end
            if sName == 'item_bottle'
                and (tonumber(hItem:GetCurrentCharges()) or 0) > 0
            then
                return sName
            end
        end
    end
    return 'none'
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
                        return armed and sId == 'staysrc'
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
                    local bBand = (nHP >= G.STAY_HP_LO and nHP <= G.STAY_HP_HI)
                    if bBand then bump('hp_band') end

                    local ok1, shipped = pcall(J.ShouldStayAndRegen, bot)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them
                    -- all would let any of the other 140 live ids move this
                    -- guard's answer while the flip is still attributed to this
                    -- lever -- the M8 survivor from the 'stayattr' round, which
                    -- this corpus could not otherwise tell apart.  Asserted 0
                    -- downstream.  'bagsalve' is named explicitly because it is
                    -- the id nested INSIDE the callee: if the stub ever armed
                    -- it, the flip set would silently gain backpack salves.
                    if J.IsSoakCandidate('bagsalve')
                        or J.IsSoakCandidate('stayfield')
                        or J.IsSoakCandidate('tphome') then
                        bump('arm_leak')
                    end
                    local ok2, arm = pcall(J.ShouldStayAndRegen, bot)
                    armed = false

                    -- ⭐ THE AND-OF-VETOES READING.  This function protects the
                    -- trip owner priority P2 forbids with TWO independent,
                    -- individually SUFFICIENT vetoes -- the chase clause
                    -- ('stayattr' owns it) and the supply clause ('staysrc'
                    -- owns it).  Either alone leaves the other standing, so a
                    -- single-lever isolation wave can read a correct ZERO on a
                    -- frame that BOTH levers together fix.  Measured here as a
                    -- third and fourth drive rather than argued: `flips_pair_only`
                    -- counts frames where neither id alone changes the answer
                    -- and the pair does.  It is the number that decides whether
                    -- an (a)-evidence wave for P2 may arm these one at a time.
                    J.IsSoakCandidate = function(sId) return sId == 'stayattr' end
                    local ok3, attr = pcall(J.ShouldStayAndRegen, bot)
                    J.IsSoakCandidate = function(sId)
                        return sId == 'stayattr' or sId == 'staysrc'
                    end
                    local ok4, both = pcall(J.ShouldStayAndRegen, bot)
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'staysrc'
                    end
                    if not (ok3 and ok4) then
                        bump('pair_raises')
                    else
                        if attr then bump('attr_true') end
                        if both then bump('both_true') end
                        if ok1 and attr and not shipped then bump('flips_attr') end
                        if ok1 and ok2 and both and not shipped
                            and not arm and not attr then
                            bump('flips_pair_only')
                            out:write(string.format('P %s %s %.4f\n',
                                path:match('([^/]+)%.lua$'), u.name, nHP))
                        end
                    end

                    if not (ok1 and ok2) then
                        bump('raises')
                    else
                        if shipped then bump('ship_true') end
                        if arm then bump('arm_true') end

                        -- Prefix walk: did control actually REACH the supply
                        -- clause?  Every earlier clause of the function, in the
                        -- function's own order, with 'staysrc' un-armed (so the
                        -- chase line is the shipped unattributed read -- this
                        -- census does not arm 'stayattr').
                        local bReach = bTurbo and bBand
                            and not bot:WasRecentlyDamagedByAnyHero(G.STAY_CHASE_WINDOW)
                            and #J.GetNearbyHeroes(bot, G.STAY_RING, true,
                                BOT_MODE_NONE) == 0
                        if bReach then
                            bump('supply_tested')
                            if not shipped then
                                -- Reached the clause and the function still
                                -- answered false: by construction the supply
                                -- clause is the only veto left.
                                bump('blocked_supply')
                                if J.HasFieldRegenSource(bot) then
                                    bump('blocked_with_src')
                                    out:write(string.format('F %s %s %.4f %s\n',
                                        path:match('([^/]+)%.lua$'), u.name,
                                        nHP, source_item(bot)))
                                else
                                    bump('blocked_no_src')
                                    out:write(string.format('N %s %s %.4f\n',
                                        path:match('([^/]+)%.lua$'), u.name, nHP))
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
