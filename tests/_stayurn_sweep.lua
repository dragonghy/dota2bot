-- Heavy corpus sweep for tests/test_stayurn_ally_heal.lua, run as a SUBPROCESS:
-- a full-corpus drive that rebuilds jmz_func once per hero-frame must not run on
-- run_tests.lua's long-lived heap.  The leading underscore keeps run_tests.lua
-- from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  J.ShouldStayAndRegen is PROMOTED -- live in every turbo
-- game.  Its supply read accepts regen IN FLIGHT for two consumables as shipped
-- ('modifier_flask_healing', 'modifier_tango_heal') and a third once
-- 'staybottle' is armed.  The urn's own in-flight modifier
-- ('modifier_item_urn_heal') is in none of them, while THREE other shipped sites
-- in this tree treat it as "this hero is healing, do not send it home": the
-- tpscroll '撤退:3' branch, mode_roam_generic's ShouldWaitInBaseToHeal gate, and
-- FunLib/aba_buff.lua's `hero_is_healing` list.  All three are parsed below
-- rather than restated, so deleting one turns the finding red instead of
-- dissolving it.
--
-- ⭐ THE COLUMN THAT MAKES THIS LEVER STRUCTURAL, not merely another widening.
-- An urn heal is cast BY AN ALLY, so the item and the patient sit in different
-- inventories.  Every other lever on this clause reads slots (shipped
-- `bHasFlask` -> J.IsItemAvailable 0-5; 'staysrc' -> J.HasFieldRegenSource
-- `for i = 0, 5`; 'staybag'/'bagsalve' -> the backpack).  `flip_no_urn_item`
-- counts the domain frames whose NINE slots hold neither an urn nor a spirit
-- vessel: those are the frames no slot read of any width can ever reach.
--
-- ⭐⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  Both answers come from the
-- shipped function with J.IsSoakCandidate stubbed to false and then to true.
-- Nothing here re-implements the decision.  The prefix buckets ARE evaluated
-- separately -- that is what makes "the clause was reached" and "the clause
-- vetoed" two different numbers -- and the two paths are cross-checked: `flips`
-- (driven, from the function's own return value) and `blocked_with_mod`
-- (bucketed, from the prefix walk) must be EQUAL, and the test asserts it.
--
-- ⛔ DIRECTION GOES THROUGH A COUNTER THAT IS PROVED TO COUNT.  Widening
-- `bHasRegen` can only remove vetoes, so `flip_true_to_false` must be 0 over the
-- whole corpus.  A counter whose content is all zeros cannot tell "the direction
-- holds" from "the tally never ran" -- deleting its bump would leave the
-- manifest byte-identical (the M14 lesson of the 'staytower' round).  So both
-- directions go through ONE `tally(a, b, sDown, sUp)` and it is called a SECOND
-- time with the two legs SWAPPED: the branch that must read 0 on the real call
-- is the branch that must report the WHOLE domain on the swapped call.
--
-- ⚠️ THE GOLD TERM IS NOT MEASURABLE HERE, AND THAT IS MEASURED TOO.  Gold is
-- not networked into a .dem (tools/batch_test/behavioral/hometp_invfull_lag.py,
-- honest-bounds block), so `bot:GetGold()` falls through to mock/bot_api.lua's
-- `^Get -> 0` scalar (GH #495).  `gold_nonzero` must therefore read 0 over the
-- whole corpus -- asserted downstream, because the honest bound this lever
-- publishes (the measured flip set is the GOLD-POOR SUPERSET of the live one) is
-- only true while that holds.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac> <missing_hp> <carries_urn_family 0|1>
--       one live frame where J.ShouldStayAndRegen flips false -> true
--   B <fixture> <hero> <hp_frac> <stop>
--       one live frame carrying 'modifier_item_urn_heal', with the clause that
--       stops it: band | chase | ring | shipped_ok | domain.  Every carrier gets
--       a row, in the domain or not -- the anti-vacuum column.
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'
local ITEMFILE = 'bots/ability_item_usage_generic.lua'
local ROAMFILE = 'bots/mode_roam_generic.lua'
local BUFFFILE = 'bots/FunLib/aba_buff.lua'
local MOD = 'modifier_item_urn_heal'
local VESSEL = 'modifier_item_spirit_vessel_heal'

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
-- long comment naming J.IsSoakCandidate, both modifier strings, three file paths
-- and the sibling ids in prose.  Reading the raw block would let the COMMENT
-- satisfy the assertions -- the §EN mistake, where a counter that must read 0
-- read 1 off a comment explaining why it was 0.
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
G.STAY_SOAKID = (stay and stay:find("J.IsSoakCandidate( 'stayurn' )", 1, true))
    and 1 or 0
G.STAY_READS_MOD = (stay and stay:find("HasModifier( '" .. MOD .. "' )", 1, true))
    and 1 or 0
-- Honest bound (2), as a parsed fact rather than a promise: the spirit vessel's
-- heal modifier is DELIBERATELY not in this lever (0 corpus carriers, so adding
-- it would widen the domain by an unpriced amount).  If someone adds it, this
-- goes red and the bound is re-derived instead of quietly ceasing to be true.
G.STAY_READS_VESSEL = (stay and stay:find(VESSEL, 1, true)) and 1 or 0
-- The 'pullcad' trap is TWO IDS IN ONE CONDITION, not two ids in one function.
-- This function now carries FIVE independent levers, so the total is 5 and the
-- per-condition maximum is 1 -- and it is the second number that is the
-- invariant.  The total is kept only as a FLOOR (a deletion that makes the
-- function id-free), never as an equality: three separate rounds turned an
-- equality here red by landing a lever that has no trap on it.
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
-- APPENDED, NOT INSERTED: with this id un-armed the three sibling widenings must
-- evaluate byte-identically, which is only true while this block sits AFTER all
-- of them and BEFORE the gold line.  Positions are compared inside the same
-- stripped block, so a comment mentioning any id cannot move them.
local at_src = stay and stay:find("'staysrc'", 1, true)
local at_btl = stay and stay:find("'staybottle'", 1, true)
local at_bag = stay and stay:find("'staybag'", 1, true)
local at_urn = stay and stay:find("'stayurn'", 1, true)
local at_gold = stay and stay:find('GetGold', 1, true)
G.STAY_ORDER_OK = (at_src and at_btl and at_bag and at_urn and at_gold
    and at_urn > at_src and at_urn > at_btl and at_urn > at_bag
    and at_gold > at_urn) and 1 or 0
-- The shipped disjunction reads regen IN FLIGHT for two consumables already --
-- that is the whole argument for the fourth.  Counted on the two lines that
-- compute `bHasFlask`, so no lever's own line can inflate it.  Bounded by the
-- NEXT statement, not by a blank line: stripping comments turns each lever's
-- block into blank lines, so a `.-\n\n` span would have swallowed them.
local shipped_supply = stay and stay:match('local bHasFlask.-local bHasRegen')
local nMods = 0
if shipped_supply then
    for _ in shipped_supply:gmatch('HasModifier') do nMods = nMods + 1 end
end
G.STAY_SHIPPED_MODS = nMods
G.STAY_SHIPPED_HAS_URN_MOD =
    (shipped_supply and shipped_supply:find(MOD, 1, true)) and 1 or 0
-- The widening this round REFUSED to make, kept as a parsed zero: the sibling
-- presence test does not name the urn ITEM.  If a later round adds it, the
-- GH #542 pair-dependency argument in this lever's comment has to be re-read.
G.SRC_NAMES_URN_ITEM =
    (source and source:find('item_urn_of_shadows', 1, true)) and 1 or 0
-- The three corroborating sites, read off the RAW files (they are live
-- conditions/lists there, not comments) and pinned so that deleting one turns
-- the finding red instead of dissolving it.
-- ⛔ COUNTED, NOT FOUND, and the count is the finding.  The first version of
-- this fact was a presence flag, and the mutation stand's anchor check answered
-- `occurs 5 time(s)`: the item layer refuses a heal-or-go-home action on this
-- modifier at FIVE separate sites (two of them byte-identical for five lines).
-- A presence flag cannot go red when one of the five is deleted -- the M6 mutant
-- did exactly that and SURVIVED.  The number is what the condition-(c) argument
-- actually rests on: five live refusals in the item layer, zero in the PROMOTED
-- guard.
local itemsrc = read_file(ITEMFILE)
local NEEDLE = 'not bot:HasModifier( "' .. MOD .. '" )'
local nSites = 0
do
    local at = 1
    while true do
        local i = itemsrc:find(NEEDLE, at, true)
        if i == nil then break end
        nSites = nSites + 1
        at = i + 1
    end
end
G.ITEM_URN_MOD_SITES = nSites
G.TP3_LISTS_URN_MOD = (nSites > 0) and 1 or 0
G.ROAM_LISTS_URN_MOD = read_file(ROAMFILE):find("not bot:HasModifier('" .. MOD .. "')",
    1, true) and 1 or 0
local buffsrc = read_file(BUFFFILE)
local healing = buffsrc:match('hero_is_healing = {(.-)}')
G.BUFF_HEALING_HAS_URN = (healing and healing:find(MOD, 1, true)) and 1 or 0
local nHealing = 0
if healing then for _ in healing:gmatch('modifier_') do nHealing = nHealing + 1 end end
G.BUFF_HEALING_N = nHealing

local HP_LO = tonumber(stay and stay:match('nHP < ([%d%.]+)'))
local HP_HI = tonumber(stay and stay:match('nHP > ([%d%.]+)'))
local RING = tonumber(stay and stay:match('GetNearbyHeroes%( bot, (%d+), true'))
local WINDOW = tonumber(stay and stay:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)'))
G.STAY_HP_LO, G.STAY_HP_HI, G.STAY_RING, G.STAY_CHASE_WINDOW =
    HP_LO, HP_HI, RING, WINDOW

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
    'arm_true', 'flips', 'flip_true_to_false', 'flips_swapped',
    'flip_true_to_false_swapped', 'arm_leak', 'gold_zero', 'gold_nonzero',
    'raises', 'mod_carriers', 'mod_out_of_band', 'mod_chase_stopped',
    'mod_ring_stopped', 'mod_passes_shipped', 'vessel_carriers',
    'flip_no_urn_item', 'flips_staysrc', 'flips_both_levers' }) do
    rawset(c, k, 0)
end

--- ⛔ ONE tally for both directions, called twice with the legs swapped.  The
--- branch that must read 0 on the real call (`flip_true_to_false`) is the branch
--- that must report the whole domain on the swapped call
--- (`flip_true_to_false_swapped`), so deleting either bump moves the manifest.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
end

--- Does this bot hold an urn or a spirit vessel in ANY of its nine slots?  The
--- column behind "the item and the patient are in different inventories": a
--- domain frame answering false here is one no slot read can ever reach.
local function carries_urn_family(bot)
    for i = 0, 8 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil then
            local sName = hItem:GetName()
            if sName == 'item_urn_of_shadows' or sName == 'item_spirit_vessel' then
                return true
            end
        end
    end
    return false
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
                        return armed and sId == 'stayurn'
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
                    if bot:HasModifier(VESSEL) then bump('vessel_carriers') end

                    local ok1, shipped = pcall(J.ShouldStayAndRegen, bot)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them
                    -- all would let any of the other live ids move this guard's
                    -- answer while the flip is still attributed to this lever --
                    -- the M8 survivor from the 'stayattr' round.  Asserted 0
                    -- downstream.  The three ids named are the ones that widen
                    -- this same clause.
                    if J.IsSoakCandidate('staysrc')
                        or J.IsSoakCandidate('staybottle')
                        or J.IsSoakCandidate('staybag')
                        or J.IsSoakCandidate('bagsalve') then
                        bump('arm_leak')
                    end
                    local ok2, arm = pcall(J.ShouldStayAndRegen, bot)

                    -- The sibling-overlap column (GH #532).  Drive 'staysrc'
                    -- alone and then both, so the report can say whether this
                    -- lever's domain is DISJOINT from its sibling's (single-arm
                    -- isolation reads it correctly) or shared with it.
                    J.IsSoakCandidate = function(sId) return sId == 'staysrc' end
                    local ok3, srconly = pcall(J.ShouldStayAndRegen, bot)
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'stayurn'
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
                        local bChase = bTurbo and bBand
                            and not bot:WasRecentlyDamagedByAnyHero(WINDOW)
                        local bReach = bChase
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
                                else
                                    bump('blocked_no_mod')
                                end
                            end
                        end

                        -- The anti-vacuum column: EVERY carrier gets a row, with
                        -- the clause that stops it.  "The corpus has no urn
                        -- heals" and "the corpus has urn heals this function
                        -- rejects three clauses earlier" must never read alike.
                        if bMod then
                            bump('mod_carriers')
                            local sStop
                            if not bBand then
                                sStop = 'band'
                                bump('mod_out_of_band')
                            elseif not bChase then
                                sStop = 'chase'
                                bump('mod_chase_stopped')
                            elseif not bReach then
                                sStop = 'ring'
                                bump('mod_ring_stopped')
                            elseif shipped then
                                sStop = 'shipped_ok'
                                bump('mod_passes_shipped')
                            else
                                sStop = 'domain'
                            end
                            out:write(string.format('B %s %s %.4f %s\n',
                                path:match('([^/]+)%.lua$'), u.name, nHP, sStop))
                        end

                        if arm and not shipped then
                            local bCarry = carries_urn_family(bot)
                            if not bCarry then bump('flip_no_urn_item') end
                            out:write(string.format('F %s %s %.4f %d %d\n',
                                path:match('([^/]+)%.lua$'), u.name, nHP,
                                bot:OriginalGetMaxHealth() - bot:OriginalGetHealth(),
                                bCarry and 1 or 0))
                        end
                        tally(shipped, arm, 'flip_true_to_false', 'flips')
                        tally(arm, shipped, 'flip_true_to_false_swapped',
                            'flips_swapped')
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
