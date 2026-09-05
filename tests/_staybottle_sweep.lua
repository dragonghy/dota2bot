-- Heavy corpus sweep for tests/test_staybottle_inflight_regen.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap.  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  J.ShouldStayAndRegen is PROMOTED -- live in every turbo
-- game.  Its shipped supply read already accepts regen IN FLIGHT for two of the
-- four consumables this family recognises ('modifier_flask_healing',
-- 'modifier_tango_heal'); the bottle's own in-flight modifier
-- ('modifier_bottle_regeneration') is in neither that line nor the 'staysrc'
-- widening below it.  The omission bites precisely because drinking a bottle is
-- the moment its INVENTORY evidence disappears: the engine renames the item to
-- 'item_empty_bottle' and drops its charges to 0, so the shipped name test and
-- J.HasFieldRegenSource's charge test BOTH answer "carries nothing" while a
-- ~135-health sip is arriving.  The 'staybottle' lever adds that one modifier.
--
-- This census is the DOMAIN PRICE of that lever on the real-frame corpus:
--   * how many live hero frames REACH the supply clause at all (every earlier
--     clause of the function having passed);
--   * how many of those the supply clause vetoes;
--   * of those, how many are mid-sip (the frames the lever is about) versus how
--     many are not (where the lever is completely inert);
--   * and, separately, how many frames carry the modifier but are OUT of the
--     function's own HP band -- the anti-vacuum column, so "the corpus has no
--     bottles at all" and "the corpus has bottles the band rejects" can never be
--     the same reading.
--
-- ⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  Both answers come from the shipped
-- function with J.IsSoakCandidate stubbed to false and then to true.  Nothing
-- here re-implements the decision.  The prefix buckets ARE evaluated separately
-- -- that is what makes "the clause was reached" and "the clause vetoed" two
-- different numbers -- and the two paths are cross-checked: `flips` (driven,
-- from the function's own return value) and `blocked_with_mod` (bucketed, from
-- the prefix walk) must be EQUAL, and the test asserts that.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  `flip_true_to_false` counts frames
-- where arming turns a TRUE into a FALSE.  Widening `bHasRegen` can only remove
-- vetoes, so that counter must be 0; the test asserts it.
--
-- ⭐⭐ THE SIBLING-OVERLAP COLUMN, and it is the one that decides a wave.  The
-- same function now carries THREE independent, individually sufficient vetoes
-- ('stayattr' on the chase clause, 'staysrc' and this one on the supply clause).
-- GH #532 was filed because two of them move owner P2's pinned frame only as a
-- PAIR, so a single-arm isolation wave reads a correct zero there.  This sweep
-- drives 'staysrc' alone as well, so `flips_both_levers` says whether THIS
-- lever's domain has the same problem or is disjoint from its sibling's.
--
-- ⚠️ THE GOLD TERM IS NOT MEASURABLE HERE, AND THAT IS MEASURED TOO.  Gold is
-- not networked into a .dem (tools/batch_test/behavioral/hometp_invfull_lag.py,
-- honest-bounds block), so `bot:GetGold()` falls through to mock/bot_api.lua's
-- `^Get -> 0` scalar (GH #495).  `gold_nonzero` must therefore read 0 over the
-- whole corpus -- asserted downstream, because the honest bound this file
-- publishes (the measured flip set is the GOLD-POOR SUPERSET of the live one) is
-- only true while that holds.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac> <bottle_item_name>
--       one live frame where J.ShouldStayAndRegen flips false -> true
--   B <fixture> <hero> <hp_frac> <in_band 0|1>
--       one live frame carrying 'modifier_bottle_regeneration' (every carrier,
--       in band or not -- the anti-vacuum column)
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'
local ITEMFILE = 'bots/ability_item_usage_generic.lua'
local MOD = 'modifier_bottle_regeneration'

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

-- Every structural fact below is a claim about CODE, and this lever ships with a
-- long comment naming J.IsSoakCandidate, the modifier string, item names and the
-- gold constant in prose.  Reading the raw block would let the COMMENT satisfy
-- the assertions -- the §EN mistake, where a counter that must read 0 read 1 off
-- a comment explaining why it was 0.
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local src = read_file(JMZ)
local stay = strip_comments(block(src, 'function J.ShouldStayAndRegen( bot )'))
local source = strip_comments(block(src, 'function J.HasFieldRegenSource( bot )'))
G.STAY = stay and 1 or 0
G.SRC = source and 1 or 0
G.STAY_SOAKID = (stay and stay:find("J.IsSoakCandidate( 'staybottle' )", 1, true))
    and 1 or 0
G.STAY_READS_MOD = (stay and stay:find("HasModifier( '" .. MOD .. "' )", 1, true))
    and 1 or 0
-- The 'pullcad' trap is TWO IDS IN ONE CONDITION, not two ids in one function.
-- This function now carries THREE independent levers, so the total is 3 and the
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
-- APPENDED, NOT INSERTED: with this id un-armed the sibling lever's evaluation
-- must be byte-identical, which is only true while this block sits AFTER it.
-- Positions are compared inside the same stripped block, so a comment mentioning
-- either id cannot move them.
local at_src = stay and stay:find("'staysrc'", 1, true)
local at_btl = stay and stay:find("'staybottle'", 1, true)
G.STAY_ORDER_OK = (at_src and at_btl and at_btl > at_src) and 1 or 0
-- The shipped disjunction reads regen IN FLIGHT for two consumables already --
-- that is the whole argument for the third.  Counted on the two lines that
-- compute `bHasFlask`, so the lever's own modifier cannot inflate it.
-- Bounded by the NEXT statement, not by a blank line: stripping comments turns
-- this lever's own 40-line block into blank lines, so a `.-\n\n` span would have
-- swallowed the new modifier read and let the shipped-side counters count it.
-- (Measured, not foreseen: the first run of this file reported 3 shipped
-- modifier reads and a shipped bottle read of 1, both off the lever's own line.)
local shipped_supply = stay and stay:match('local bHasFlask.-local bHasRegen')
local nMods = 0
if shipped_supply then
    for _ in shipped_supply:gmatch('HasModifier') do nMods = nMods + 1 end
end
G.STAY_SHIPPED_MODS = nMods
G.STAY_SHIPPED_HAS_BOTTLE_MOD =
    (shipped_supply and shipped_supply:find(MOD, 1, true)) and 1 or 0
-- The structural blindness this lever is about, as two parsed facts: the sibling
-- presence test reaches a bottle ONLY through a positive charge count, and the
-- engine's own name for a drunk bottle is the other class.
G.SRC_BOTTLE_NEEDS_CHARGES =
    (source and source:find('GetCurrentCharges', 1, true)) and 1 or 0
-- The corroborating site: the tpscroll '撤退:3' branch already refuses a home TP
-- while this modifier is up.  Read off the RAW item file (it is a live condition
-- there, not a comment) and pinned so that deleting it turns the finding red
-- instead of dissolving it.
G.TP3_LISTS_BOTTLE_MOD = read_file(ITEMFILE):find(MOD, 1, true) and 1 or 0

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
    'blocked_supply', 'blocked_with_mod', 'blocked_no_mod', 'ship_true',
    'arm_true', 'flips', 'flip_true_to_false', 'arm_leak', 'gold_zero',
    'gold_nonzero', 'raises', 'mod_carriers', 'mod_out_of_band',
    'src_true_via_bottle', 'flips_staysrc', 'flips_both_levers' }) do
    rawset(c, k, 0)
end

-- The bottle this bot is carrying, if any, BY THE ENGINE'S OWN NAME.  Reported
-- for the flip rows so the pinned frame is chosen by what it actually holds
-- rather than by its position in the corpus.
local function bottle_item(bot)
    for i = 0, 8 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil then
            local sName = hItem:GetName()
            if sName == 'item_bottle' or sName == 'item_empty_bottle' then
                return sName
            end
        end
    end
    return 'none'
end

-- Does J.HasFieldRegenSource answer TRUE through its BOTTLE leg on this frame?
-- Documented as a structural zero on fixtures (the mock's GetCurrentCharges
-- default is 0); measured here rather than restated, because the whole finding
-- rests on that leg being unable to see a bottle in flight.
local function src_true_via_bottle(bot)
    for i = 0, 5 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil and hItem:GetName() == 'item_bottle'
            and (tonumber(hItem:GetCurrentCharges()) or 0) > 0
        then
            return true
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
                        return armed and sId == 'staybottle'
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
                    local bMod = bot:HasModifier(MOD) and true or false
                    if bMod then
                        bump('mod_carriers')
                        if not bBand then bump('mod_out_of_band') end
                        out:write(string.format('B %s %s %.4f %d\n',
                            path:match('([^/]+)%.lua$'), u.name, nHP,
                            bBand and 1 or 0))
                    end
                    if src_true_via_bottle(bot) then bump('src_true_via_bottle') end

                    local ok1, shipped = pcall(J.ShouldStayAndRegen, bot)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them
                    -- all would let any of the other live ids move this guard's
                    -- answer while the flip is still attributed to this lever --
                    -- the M8 survivor from the 'stayattr' round.  Asserted 0
                    -- downstream.  'staysrc' and 'bagsalve' are named explicitly
                    -- because they are the ids that would silently widen the
                    -- same clause.
                    if J.IsSoakCandidate('staysrc')
                        or J.IsSoakCandidate('bagsalve')
                        or J.IsSoakCandidate('stayattr') then
                        bump('arm_leak')
                    end
                    local ok2, arm = pcall(J.ShouldStayAndRegen, bot)

                    -- The sibling-overlap column (GH #532).  Drive 'staysrc'
                    -- alone and then both, so the report can say whether this
                    -- lever's domain is DISJOINT from its sibling's (single-arm
                    -- isolation reads it correctly) or shared with it (it does
                    -- not).
                    J.IsSoakCandidate = function(sId) return sId == 'staysrc' end
                    local ok3, srconly = pcall(J.ShouldStayAndRegen, bot)
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'staybottle'
                    end
                    armed = false

                    if not (ok1 and ok2 and ok3) then
                        bump('raises')
                    else
                        if shipped then bump('ship_true') end
                        if arm then bump('arm_true') end
                        if srconly and not shipped then bump('flips_staysrc') end
                        if srconly and not shipped and arm and not shipped then
                            bump('flips_both_levers')
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
                                if bMod then
                                    bump('blocked_with_mod')
                                    out:write(string.format('F %s %s %.4f %s\n',
                                        path:match('([^/]+)%.lua$'), u.name,
                                        nHP, bottle_item(bot)))
                                else
                                    bump('blocked_no_mod')
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
