-- Heavy corpus sweep for tests/test_waitclar_mana_trip.lua, run as a SUBPROCESS
-- (a full-corpus drive that re-dofiles mode_roam_generic once per hero-frame
-- must not run on run_tests.lua's long-lived heap).  The leading underscore
-- keeps run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  ConsiderWaitInBaseToHeal (bots/mode_roam_generic.lua) is
-- SHIPPED and ungated -- it decides whether a bot TPs to base.  Its condition is
-- one `or` with two legs:
--   * the HP leg, triggered by `J.GetHP(bot) < 0.25`, which refuses the trip on
--     TEN modifiers meaning "already recovering, or must not be moved" (tango,
--     flask, chemical rage, tempest double, healing ward, purifying flames,
--     fatal bonds, satanic, spirit vessel, urn -- two of them not consumables
--     at all, which is what makes the list read as exhaustive);
--   * the MANA leg, triggered by `J.GetMP(bot) < 0.25`, which refuses on NONE.
-- 'waitclar' adds one veto to the second leg: a ticking 'modifier_clarity_potion'
-- -- the mana-side field consumable this tree drinks itself
-- (X.ConsiderItemDesire["item_clarity"], ungated, `GetMP < 0.4`).
--
-- ⭐ THE COLUMN THAT DECIDES WHETHER THE LEVER IS ABOUT ANYTHING: which leg
-- actually fires.  A finding about the mana leg is worth nothing if the corpus
-- only ever reaches the HP leg, so `wait_hp_leg` and `wait_mana_leg` are counted
-- SEPARATELY and both are asserted.  They are read off the HP trigger of the
-- frame itself, not off a re-implementation of the condition.
--
-- ⭐⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  Both answers come from the
-- SHIPPED global with J.IsSoakCandidate stubbed to false and then to true.
-- Nothing here re-implements the decision.  The carrier walk (`B` rows) is a
-- separate prefix computation whose only job is to say WHERE a clarity carrier
-- stopped, so "the corpus has no clarities" and "it has clarities this function
-- rejects earlier" can never be the same reading.  The two paths cross-check:
-- `flips` (driven, from the function's own return value) and `blocked_domain`
-- (bucketed, from the carrier walk) must be EQUAL.
--
-- ⛔ DIRECTION GOES THROUGH A COUNTER THAT IS PROVED TO COUNT.  This lever
-- appends a veto, so it can only turn TRUE into FALSE and `flip_false_to_true`
-- must be 0 over the whole corpus.  A counter whose content is all zeros cannot
-- tell "the direction holds" from "the tally never ran" -- deleting its bump
-- would leave the manifest byte-identical (the M14 lesson of the 'staytower'
-- round).  So both directions go through ONE `tally(a, b, sDown, sUp)` and it is
-- called a SECOND time with the legs SWAPPED: the branch that must read 0 on the
-- real call is the branch that must report the WHOLE domain on the swapped call.
--
-- ⚠️ THE ANCHOR LESSON THIS FILE WAS BUILT ON (GH #550, third form).  The first
-- version of the sibling family's structural parse split conditions on
-- `if(.-)then` and read three of six -- because `HasModifier` CONTAINS the
-- substring "if" (`Mod`+`if`+`ier`), so the scan resumed mid-token and two
-- conditions came back starting with `ier( 'modifier_...`.  Every keyword anchor
-- below is therefore frontier-anchored (`%f[%w]`), and the count is asserted
-- against a declared number rather than eyeballed.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac> <mp_frac>
--       one live frame where ConsiderWaitInBaseToHeal flips true -> false
--   B <fixture> <hero> <mp_frac> <stop>
--       one live frame carrying 'modifier_clarity_potion', with the clause that
--       stops it: outer | mp | hp_leg | domain.  Every carrier gets a row, in
--       the domain or not -- the anti-vacuum column.
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local ROAMFILE = 'bots/mode_roam_generic.lua'
local ITEMFILE = 'bots/ability_item_usage_generic.lua'
local BUFFFILE = 'bots/FunLib/aba_buff.lua'
local CLAR = 'modifier_clarity_potion'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Frontier-anchored so a keyword inside an identifier cannot open a block.
local function block(src, header, stopPat)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find(stopPat, at + #header) or #src
    return src:sub(at, stop)
end

-- Structural facts are claims about CODE.  This lever ships with a long comment
-- naming the modifier, both legs and three file paths, so reading the raw block
-- would let the COMMENT satisfy the assertions (the §EN mistake).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local roam = strip_comments(block(read_file(ROAMFILE),
    'function ConsiderWaitInBaseToHeal()', '\nfunction '))
G.ROAM_FN = roam and 1 or 0
G.ROAM_SOAKID = (roam and roam:find("J.IsSoakCandidate('waitclar')", 1, true)) and 1 or 0
G.ROAM_TURBO = (roam and roam:find('J.IsModeTurbo()', 1, true)) and 1 or 0
-- The 'pullcad' trap is TWO IDS IN ONE CONDITION.  Counted, and the maximum per
-- condition is the invariant; the total is only a floor.
local nIds = 0
if roam then for _ in roam:gmatch('IsSoakCandidate') do nIds = nIds + 1 end end
G.ROAM_NIDS = nIds
-- ⛔ THE GATE MUST BE THE FIRST CONJUNCT INSIDE ITS `not (...)`.  That is what
-- makes the un-armed evaluation byte-identical -- neither J.IsModeTurbo nor the
-- engine's HasModifier is reached.  Read as an ORDER inside the stripped block,
-- so a comment naming either cannot move it.
local at_gate = roam and roam:find("IsSoakCandidate('waitclar')", 1, true)
local at_turbo = roam and roam:find('IsModeTurbo()', 1, true)
local at_mod = roam and roam:find(CLAR, 1, true)
G.ROAM_GATE_FIRST = (at_gate and at_turbo and at_mod
    and at_gate < at_turbo and at_turbo < at_mod) and 1 or 0
-- ⭐ THE ASYMMETRY THE CONDITION-(c) ARGUMENT RESTS ON, and it is a COUNT, not a
-- presence flag.  The HP leg's veto list is what makes "this list is exhaustive
-- and skipped the mana side" a fact rather than an impression; a presence flag
-- reads the same whether that list has ten entries or one.  (The 'stayurn'
-- round's M6 survivor is the reason this is counted: deleting one of five sites
-- left a presence flag green.)
local hp_leg = roam and roam:match("J%.GetHP%(bot%) < 0%.25(.-)or %(%(%(")
local nHpMods = 0
if hp_leg then for _ in hp_leg:gmatch('HasModifier') do nHpMods = nHpMods + 1 end end
G.HP_LEG_VETOES = nHpMods
G.HP_LEG_HAS_CLARITY = (hp_leg and hp_leg:find(CLAR, 1, true)) and 1 or 0
G.HP_LEG_HAS_BOTTLE =
    (hp_leg and hp_leg:find('modifier_bottle_regeneration', 1, true)) and 1 or 0
-- The mana leg's own veto count: SHIPPED it is zero, and armed it is one.  Both
-- are asserted downstream, because "the mana leg has no supply veto" is the
-- whole finding and a flag that reads 1 either way would erase it.
local mana_leg = roam and roam:match('or %(%(%(J%.IsCore.-\n%s*then')
local nManaMods, nManaGated = 0, 0
if mana_leg then
    for _ in mana_leg:gmatch('HasModifier') do nManaMods = nManaMods + 1 end
    for _ in mana_leg:gmatch('IsSoakCandidate') do nManaGated = nManaGated + 1 end
end
G.MANA_LEG_MODS = nManaMods
G.MANA_LEG_GATED = nManaGated
-- The three corroborating sites, read off the RAW files (live conditions there,
-- not comments), COUNTED rather than flagged.
local itemsrc = read_file(ITEMFILE)
local nClarVeto = 0
do
    local at = 1
    local needle = 'not bot:HasModifier( "' .. CLAR .. '" )'
    while true do
        local i = itemsrc:find(needle, at, true)
        if i == nil then break end
        nClarVeto = nClarVeto + 1
        at = i + 1
    end
end
G.ITEM_CLARITY_VETO_SITES = nClarVeto
-- The CAST PATH -- what the refused urn widening lacked.  The clarity is drunk
-- by the bot itself, ungated, at GetMP < 0.4.
G.ITEM_SELF_DRINKS_CLARITY =
    itemsrc:find('J.GetMP( bot ) < 0.4', 1, true) and 1 or 0
local healing = read_file(BUFFFILE):match('hero_is_healing = {(.-)}')
G.BUFF_HEALING_HAS_CLARITY = (healing and healing:find(CLAR, 1, true)) and 1 or 0

local MP_TRIG = tonumber(roam and roam:match('J%.GetMP%(bot%) < ([%d%.]+)'))
local HP_TRIG = tonumber(roam and roam:match('J%.GetHP%(bot%) < ([%d%.]+)'))
G.MANA_TRIGGER, G.HP_TRIGGER = MP_TRIG, HP_TRIG

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
local function bump(k) rawset(c, k, c[k] + 1) end
-- Zero-initialised so "the bucket was never reached" and "the bucket measured
-- zero" are never the same thing to the parser (the GH #171 shape).
for _, k in ipairs({ 'fixtures', 'live', 'raises', 'ship_true', 'arm_true',
    'flips', 'flip_false_to_true', 'flips_swapped', 'flip_false_to_true_swapped',
    'wait_hp_leg', 'wait_mana_leg', 'clar_carriers', 'clar_stop_outer',
    'clar_stop_mp', 'clar_stop_hp_leg', 'blocked_domain', 'arm_leak',
    'mp_under_trigger' }) do
    rawset(c, k, 0)
end

--- ONE tally for both directions, called twice with the legs swapped.  The
--- branch that must read 0 on the real call is the branch that must report the
--- whole domain on the swapped call, so deleting either bump moves the manifest.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
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
                        return armed and sId == 'waitclar'
                    end
                    local sFx = path:match('([^/]+)%.lua$')
                    local nHP, nMP = J.GetHP(bot), J.GetMP(bot)
                    local bClar = bot:HasModifier(CLAR) and true or false
                    if nMP < MP_TRIG then bump('mp_under_trigger') end

                    local okl = pcall(dofile, ROAMFILE)
                    local okd = okl and pcall(function() GetDesire() end)
                    if not okd then
                        bump('raises')
                    else
                        -- The arming must be ONE id wide.  A stub arming them
                        -- all would let another live id move this answer while
                        -- the flip is still attributed here (the M8 survivor of
                        -- the 'stayattr' round).  Asserted 0 downstream.
                        local ok1, shipped = pcall(function() return ConsiderWaitInBaseToHeal() end)
                        armed = true
                        if J.IsSoakCandidate('c2') or J.IsSoakCandidate('c4')
                            or J.IsSoakCandidate('stayfield') then
                            bump('arm_leak')
                        end
                        local ok2, arm = pcall(function() return ConsiderWaitInBaseToHeal() end)
                        armed = false

                        if not (ok1 and ok2) then
                            bump('raises')
                        else
                            shipped, arm = shipped and true or false, arm and true or false
                            if shipped then
                                bump('ship_true')
                                -- WHICH LEG, off the frame's own HP against the
                                -- HP leg's own trigger constant.
                                if nHP < HP_TRIG then bump('wait_hp_leg')
                                else bump('wait_mana_leg') end
                            end
                            if arm then bump('arm_true') end
                            tally(shipped, arm, 'flips', 'flip_false_to_true')
                            -- Legs EXCHANGED, same `tally`.  The counter that
                            -- must read 0 on the real call is the one that must
                            -- report the WHOLE domain here, so deleting either
                            -- bump moves the manifest instead of leaving it
                            -- byte-identical (the M14 lesson).
                            tally(arm, shipped, 'flips_swapped', 'flip_false_to_true_swapped')
                            if shipped and not arm then
                                out:write(string.format('F %s %s %.3f %.3f\n',
                                    sFx, u.name, nHP, nMP))
                            end
                        end

                        -- The anti-vacuum walk: every clarity carrier gets a row
                        -- naming the clause that stops it.  The five buckets sum
                        -- to `clar_carriers` by counting, not by subtraction.
                        if bClar then
                            bump('clar_carriers')
                            local sStop
                            if not shipped and nMP >= MP_TRIG then
                                sStop = 'mp'
                                bump('clar_stop_mp')
                            elseif not shipped then
                                sStop = 'outer'
                                bump('clar_stop_outer')
                            elseif nHP < HP_TRIG then
                                sStop = 'hp_leg'
                                bump('clar_stop_hp_leg')
                            else
                                sStop = 'domain'
                                bump('blocked_domain')
                            end
                            out:write(string.format('B %s %s %.3f %s\n',
                                sFx, u.name, nMP, sStop))
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
