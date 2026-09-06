-- Heavy corpus sweep for tests/test_stayfamily_singlearm.lua, run as a
-- SUBPROCESS (a full-corpus drive that rebuilds jmz_func once per hero-frame
-- must not run on run_tests.lua's long-lived heap).  The leading underscore
-- keeps run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED, AND WHY IT IS A DIFFERENT QUESTION FROM THE CENSUS ROW.
-- ------------------------------------------------------------------------
-- tests/test_gated_helper_nesting_census.lua answers the IDENTITY question:
-- un-armed, is the inner helper the identity element of the conjunction it
-- joined?  For J.ShouldStayAndRegen the answer is yes and it is cheap -- every
-- one of its ids puts J.IsSoakCandidate first in its condition, so un-armed the
-- function is byte-identical to the shipped read.
--
-- GH #576 (batch desk, 2026-09-06) asks the question that costs MONEY, and it
-- is not that one.  Six candidate ids now hang off this single PROMOTED helper.
-- If arming one of them ALONE cannot move the helper's answer -- because a
-- SIBLING id, or a shipped clause the sibling was written to widen, already
-- decided every frame in its domain -- then a single-arm isolation wave buys a
-- correct zero, and a correct zero and "tested, no effect" are the SAME ROW in
-- a ruling table.  check_armed_wiring.py cannot tell them apart either: it
-- checks that a call site exists, not that the predicate can be true.
--
-- So each id is armed ALONE here, over the same 1012 live hero frames the six
-- individual sweeps drive, and the flip count is reported per id and per
-- direction.  Nothing is argued: every number comes from calling the SHIPPED
-- function with J.IsSoakCandidate stubbed, never from re-implementing it.
--
-- ⛔ WHY THE PER-DIRECTION SPLIT IS THE LOAD-BEARING PART.  The set contains
-- both kinds of lever and they cannot be read with one counter:
--   * four SUPPLY WIDENINGS ('staysrc', 'staybottle', 'staybag', 'stayurn')
--     each sit behind `not bHasRegen` and can only turn FALSE into TRUE;
--   * 'stayattr' relaxes the chase veto -- also FALSE into TRUE;
--   * 'staytower' APPENDS a veto and can only turn TRUE into FALSE.
-- A single `flips` column would let a widening's gain cancel a veto's loss on
-- the same corpus and read as a small number for both.  `up` and `down` are
-- counted separately and each id asserts BOTH -- including the one that must be
-- zero, which is why they are bumped through one shared `tally` called a second
-- time with the legs swapped (the M14 lesson: a counter whose content is all
-- zeros cannot tell "the direction holds" from "the tally never ran").
--
-- ⭐ THE PAIR COLUMN.  Monotonicity is what makes the four widenings safe to
-- read singly: each is guarded by `not bHasRegen`, so arming more of them can
-- only ADD flips.  The one shape that CAN hide a lever is two independently
-- sufficient VETOES -- arming one measures a correct zero wherever the other
-- also fires.  This set has exactly two vetoes ('stayattr' relaxes one,
-- 'staytower' adds one), so their overlap is measured rather than argued:
-- `pair_attr_tower_both` counts frames where arming the two TOGETHER differs
-- from arming each alone.
--
-- ⚠️ THE GOLD TERM IS NOT MEASURABLE HERE, AND THAT IS MEASURED TOO.  Gold is
-- not networked into a .dem (GH #495), so `bot:GetGold()` falls through to
-- mock/bot_api.lua's `^Get -> 0` scalar and `gold_nonzero` must read 0 over the
-- whole corpus.  Every flip count below is therefore the GOLD-POOR SUPERSET of
-- the live one -- direction fixed, magnitude not claimed.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'

-- The six ids, in the order they appear in the function body.  This list is
-- CROSS-CHECKED against the source below rather than trusted: if a seventh id
-- lands on this helper and nobody adds it here, `IDS_IN_SOURCE` moves and the
-- test goes red, which is the whole point of GH #576.
local IDS = { 'stayattr', 'staytower', 'staysrc', 'staybottle', 'staybag', 'stayurn' }

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

-- Structural facts are claims about CODE, and this function carries hundreds of
-- lines of comment naming every id in prose.  Reading the raw block would let
-- the COMMENTS satisfy the assertions (the §EN mistake).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local stay = strip_comments(block(read_file(JMZ), 'function J.ShouldStayAndRegen( bot )'))
G.STAY = stay and 1 or 0
-- COUNTED, NOT CHECKED FOR PRESENCE.  A presence flag cannot go red when a
-- SEVENTH id lands, and a seventh id landing unmeasured is exactly the failure
-- GH #576 is about.  Both numbers are asserted downstream.
local nCalls = 0
if stay then for _ in stay:gmatch('IsSoakCandidate') do nCalls = nCalls + 1 end end
-- ⛔ GH #550, THIRD FORM -- an anchor that is not word-anchored.  The first
-- version of the gate-order parse below split conditions on `if(.-)then` and
-- read 3 of 6, because `HasModifier` CONTAINS the substring "if"
-- (`Mod` + `if` + `ier`): the scan opened a "condition" mid-token and two of
-- them came back starting with `ier( 'modifier_...`.  Nothing was red -- the
-- number was simply wrong, and it was wrong in the direction that would have
-- made this file report a WEAKER identity guarantee than the tree actually
-- gives.  Every keyword anchor here is frontier-anchored, and the count is
-- asserted against a declared number rather than eyeballed.
G.STAY_SOAK_CALLS = nCalls
local nFound = 0
for _, sId in ipairs(IDS) do
    if stay and stay:find("'" .. sId .. "'", 1, true) then nFound = nFound + 1 end
end
G.IDS_IN_SOURCE = nFound
G.IDS_DECLARED = #IDS
-- The identity answer the census row rests on, read off the source instead of
-- restated: every gate must be the FIRST conjunct of its condition, so un-armed
-- nothing below it is evaluated.  Counted over conditions that mention an id.
local nGateFirst, nCond = 0, 0
if stay then
    for cond in stay:gmatch('%f[%a]if%f[%A](.-)%f[%a]then%f[%A]') do
        if cond:find('IsSoakCandidate', 1, true) then
            nCond = nCond + 1
            -- first conjunct, OR reached only through `not bHasRegen and`
            -- (the four supply widenings) -- both short-circuit before the
            -- engine call the gate guards.
            local sTrim = cond:gsub('^%s+', '')
            if sTrim:find('^J%.IsSoakCandidate')
                or sTrim:find('^not bHasRegen and J%.IsSoakCandidate') then
                nGateFirst = nGateFirst + 1
            end
        end
    end
end
G.GATED_CONDS = nCond
G.GATE_FIRST_CONJUNCT = nGateFirst

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
local ZERO = { 'live', 'raises', 'ship_true', 'all_true', 'gold_zero',
    'gold_nonzero', 'pair_attr_tower_both', 'pair_attr_alone',
    'pair_tower_alone', 'swap_check_up', 'swap_check_down' }
for _, sId in ipairs(IDS) do
    ZERO[#ZERO + 1] = sId .. '_up'
    ZERO[#ZERO + 1] = sId .. '_down'
    ZERO[#ZERO + 1] = sId .. '_true'
    -- ⭐ THE SECOND COLUMN IS WHAT KEEPS A ZERO HONEST.  Gold is not networked
    -- into a .dem (GH #495), so `bot:GetGold()` is 0 on every frame and the
    -- shipped function's TRUE set collapses to 13.  A veto can only act on
    -- frames the function ALREADY accepts, so a subtractive id can read a
    -- structural zero here for a reason that has nothing to do with its
    -- siblings -- and GH #576's question is precisely "is this zero a sibling's
    -- doing".  Driving the same corpus a second time with gold forced past the
    -- 90 gate separates the two causes, and both columns are asserted.
    ZERO[#ZERO + 1] = sId .. '_up_g200'
    ZERO[#ZERO + 1] = sId .. '_down_g200'
end
ZERO[#ZERO + 1] = 'ship_true_g200'
ZERO[#ZERO + 1] = 'all_true_g200'
ZERO[#ZERO + 1] = 'all_minus_tower_true_g200'
ZERO[#ZERO + 1] = 'tower_subtracts_from_all_g200'
for _, k in ipairs(ZERO) do rawset(c, k, 0) end

--- ONE tally for both directions, called a SECOND time with the legs swapped.
--- The branch that must read 0 on the real call is the branch that must report
--- the whole domain on the swapped call, so deleting either bump moves the
--- manifest instead of leaving it byte-identical.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    if (tonumber(bot:GetGold()) or 0) == 0 then
                        bump('gold_zero')
                    else
                        bump('gold_nonzero')
                    end

                    local tArmed = {}
                    J.IsSoakCandidate = function(sId) return tArmed[sId] == true end

                    local bOk = true
                    local function drive(t)
                        tArmed = t
                        local ok2, v = pcall(J.ShouldStayAndRegen, bot)
                        if not ok2 then bOk = false end
                        return v and true or false
                    end

                    local shipped = drive({})
                    local tSolo = {}
                    for _, sId in ipairs(IDS) do
                        tSolo[sId] = drive({ [sId] = true })
                    end
                    local tAll = {}
                    for _, sId in ipairs(IDS) do tAll[sId] = true end
                    local bAll = drive(tAll)
                    local bPair = drive({ stayattr = true, staytower = true })

                    if not bOk then
                        bump('raises')
                    else
                        if shipped then bump('ship_true') end
                        if bAll then bump('all_true') end
                        for _, sId in ipairs(IDS) do
                            if tSolo[sId] then bump(sId .. '_true') end
                            tally(shipped, tSolo[sId], sId .. '_down', sId .. '_up')
                        end
                        -- The swapped call: the SAME tally with the legs
                        -- exchanged, on the one id whose `_down` must be 0.
                        tally(tSolo.staysrc, shipped, 'swap_check_up', 'swap_check_down')
                        -- The only two independently-sufficient vetoes in the
                        -- set.  A frame counted here is one where arming the
                        -- pair differs from arming either alone.
                        if tSolo.stayattr ~= shipped then bump('pair_attr_alone') end
                        if tSolo.staytower ~= shipped then bump('pair_tower_alone') end
                        if bPair ~= tSolo.stayattr and bPair ~= tSolo.staytower then
                            bump('pair_attr_tower_both')
                        end
                    end

                    -- Second pass, same frame, gold forced past the 90 gate.
                    -- Everything else about the frame is untouched: this moves
                    -- ONE value the .dem does not carry, and it moves it to the
                    -- side the live game is usually on.
                    rawset(bot, 'GetGold', function() return 200 end)
                    local bOk2 = true
                    bOk = true
                    local shipped2 = drive({})
                    if bOk then bOk2 = true else bOk2 = false end
                    if bOk2 then
                        if shipped2 then bump('ship_true_g200') end
                        for _, sId in ipairs(IDS) do
                            local v = drive({ [sId] = true })
                            tally(shipped2, v, sId .. '_down_g200', sId .. '_up_g200')
                        end
                        local tAll2 = {}
                        for _, sId in ipairs(IDS) do tAll2[sId] = true end
                        local bAll2 = drive(tAll2)
                        local tNoTower = {}
                        for _, sId in ipairs(IDS) do
                            if sId ~= 'staytower' then tNoTower[sId] = true end
                        end
                        local bNoTower = drive(tNoTower)
                        if bAll2 then bump('all_true_g200') end
                        if bNoTower then bump('all_minus_tower_true_g200') end
                        -- The frame where the ONLY subtractive id in the set
                        -- actually subtracts, and it can only exist once a
                        -- sibling has widened the function into tower range:
                        -- GH #542's shape, measured instead of argued.
                        if bNoTower and not bAll2 then
                            bump('tower_subtracts_from_all_g200')
                        end
                    end
                    rawset(bot, 'GetGold', nil)
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
