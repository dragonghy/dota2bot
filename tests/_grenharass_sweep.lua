-- Heavy corpus sweep for tests/test_grenharass_domain.lua, run as a SUBPROCESS
-- (a full-corpus drive that re-loads ability_item_usage_generic.lua once per
-- hero-frame must not run on run_tests.lua's long-lived heap).  The leading
-- underscore keeps run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  X.ConsiderItemDesire['item_blood_grenade']
-- (bots/ability_item_usage_generic.lua ~:7209) is SHIPPED and un-gated, and
-- BOTH of its branches are KILL-CONFIRMS:
--
--   loop 1  J.CanKillTarget(enemy, totalDmg)          -- 125 finishes them
--           (or totalDmg + 150, but only inside bot:GetAttackRange() AND
--            bot:IsFacingLocation(loc, 15) -- a 15-degree cone)
--   loop 2  J.IsGoingOnSomeone(bot) AND an ally chasing the same hero AND
--           J.GetTotalEstimatedDamageToTarget(allies) >= enemy:GetHealth()
--           -- the allies' own damage already kills; the grenade is decoration
--
-- So the tree throws a 25-gold restocking laning consumable only as an execute.
-- 'grenharass' appends a THIRD branch for the use the item is actually bought
-- for: the grenade removes at least a third of what the target has left
-- (`GetHealth() <= totalDmg * 3`).
--
-- ⛔ DIRECTION IS FIXED BY CONSTRUCTION, and the sweep proves it rather than
-- quoting the comment.  The branch is appended AFTER both shipped loops return,
-- so arming can only turn BOT_ACTION_DESIRE_NONE into a cast.  `flip_true_to_false`
-- must therefore be 0 over the whole corpus -- and a counter whose content is
-- all zeros cannot tell "the direction holds" from "the tally never ran" (the
-- M14/M15 lesson of the 'staytower' and 'wkreinctr' rounds).  So both
-- directions go through ONE `tally(a, b, sDown, sUp)`, called a SECOND time
-- with the legs SWAPPED: the branch that must read 0 on the real call is the
-- branch that must report the WHOLE domain on the swapped call.
--
-- ⭐ TWO COLUMNS, AND ONE OF THEM IS A STRUCTURAL ZERO WITH A LABEL.  The
-- PREFIX column walks the entry's conjuncts on the frame and says how big each
-- prefix is.  The DRIVEN column runs the shipped `_G.ItemUsageThink` and reads
-- the recorded engine action.  The driven column needs the grenade handle to be
-- castable at all: `J.CanCastAbility` short-circuits on `not IsTrained()` for
-- every fixture item handle (the sixteenth world assertion,
-- tests/test_itemdesire_world_assertion.lua), so the sweep supplies
-- IsTrained/IsActivated/IsFullyCastable to the GRENADE handle and to it only --
-- exactly as the 'urnself' round did, and for the same reason.  Both columns
-- are emitted and both are asserted, so neither can stand in for the other.
--
-- ⚠️ THE MOCK APPLIES NO MAGIC RESISTANCE.  `GetActualIncomingDamage` returns
-- the raw damage (tests/mock/bot_api.lua ~:161), so every `CanKillTarget`
-- reading below is an UPPER bound.  That is the SAFE direction for the claim
-- this file rests on -- "the shipped kill-confirm fires on zero frames" -- and
-- the UNSAFE direction for any claim that a throw kills.  This lever claims no
-- kill, and nothing here asserts one.
--
-- ⚠️ ANCHORS ARE COUNTED AND FRONTIER-ANCHORED (GH #550/#555).  A structural
-- fact parsed with `if(.-)then` splits on the `if` INSIDE `HasModifier`, and
-- nothing goes red -- the number is just wrong.  Every keyword read below is
-- `%f[%w]`-anchored or a plain `find`, and asserted against a declared count.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   W <fixture> <hero> <enemies> <mindist> <target_hp> <self_hp> <ship> <arm>
--       one live grenade-carrier frame that reaches the enemy loop
--   F <fixture> <hero> <target_hp>
--       one live frame where the entry flips NONE -> cast under arming
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local AIUG = 'bots/ability_item_usage_generic.lua'
local GREN = 'item_blood_grenade'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Structural facts are claims about CODE.  This lever ships with a long comment
-- that quotes both shipped loops, the id name and the threshold, so reading the
-- raw block would let the COMMENT satisfy the assertions (the §EN mistake).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local src = read_file(AIUG)

local at = src:find("X.ConsiderItemDesire['item_blood_grenade'] = function", 1, true)
local raw = nil
if at ~= nil then
    local stop = src:find('\nX.ConsiderItemDesire[', at + 10, true) or #src
    raw = src:sub(at, stop)
end
local body = strip_comments(raw)
G.FN = body and 1 or 0

-- The item's own numbers, read off the entry rather than restated here.
G.CAST_RANGE = tonumber(body and body:match('local nCastRange = (%d+)')) or -1
G.RADIUS = tonumber(body and body:match('local nRadius = (%d+)')) or -1
G.HEALTH_COST = tonumber(body and body:match('local nHealthCost = (%d+)')) or -1
G.IMPACT = tonumber(body and body:match('local nImpactDamage = (%d+)')) or -1
G.DPS = tonumber(body and body:match('local nDPS = (%d+)')) or -1
G.DURATION = tonumber(body and body:match('local nDuration = (%d+)')) or -1

-- The gate, and the two things that make the unarmed evaluation byte-identical:
-- the id is the FIRST conjunct, and turbo is written out (this function has no
-- IsModeTurbo above it).
G.GATE = (body and body:find("J.IsSoakCandidate('grenharass')", 1, true)) and 1 or 0
G.TURBO = (body and body:find('J.IsModeTurbo()', 1, true)) and 1 or 0
do
    local g = body and body:find("IsSoakCandidate('grenharass')", 1, true)
    local t = body and body:find('IsModeTurbo()', 1, true)
    local h = body and body:find('totalDmg %* 3')
    G.GATE_FIRST = (g and t and h and g < t and t < h) and 1 or 0
end

-- ⛔ ONE ID PER CONDITION (the 'pullcad' trap: a gate written as
-- `IsSoakCandidate('X') and IsSoakCandidate('Y')` freezes FALSE the day Y is
-- promoted).  Counted as the maximum per condition, not the total, and the
-- conditions are split on a frontier-anchored `then` so that a `then` inside an
-- identifier cannot re-open the scan mid-word.
G.NIDS = 0
G.IDS_MAX_PER_COND = 0
if body then
    for _ in body:gmatch('IsSoakCandidate') do G.NIDS = G.NIDS + 1 end
    for cond in body:gmatch('%f[%w]if%f[%W](.-)%f[%w]then%f[%W]') do
        local n = 0
        for _ in cond:gmatch('IsSoakCandidate') do n = n + 1 end
        if n > G.IDS_MAX_PER_COND then G.IDS_MAX_PER_COND = n end
    end
end

-- ⭐ APPEND-AFTER-RETURN is the whole direction argument, so it is PARSED:
-- both shipped loops must return before the gate is reached, and the gated
-- block must sit between the last shipped `return BOT_ACTION_DESIRE_HIGH` and
-- the entry's final `return BOT_ACTION_DESIRE_NONE`.
do
    local g = body and body:find("IsSoakCandidate('grenharass')", 1, true)
    local lastHigh, none = nil, nil
    if body then
        local i = nil
        repeat
            i = body:find('return BOT_ACTION_DESIRE_HIGH', (i or 0) + 1, true)
            if i and (g == nil or i < g) then lastHigh = i end
        until i == nil
        none = body:find('return BOT_ACTION_DESIRE_NONE', 1, true)
    end
    G.APPENDED_AFTER_RETURN = (g and lastHigh and none and lastHigh < g and g < none) and 1 or 0
end

-- The conjuncts the gated branch COPIES from the first shipped loop, counted so
-- that a drift in either copy is visible.  Each of these must appear at least
-- twice in the entry: once in the shipped loop, once in the gated one.
for _, k in ipairs({ 'J.IsValidHero', 'J.CanCastOnNonMagicImmune',
    'J.IsSuspiciousIllusion', 'nHealth > nHealthCost * 2',
    'J.GetEnemiesNearLoc', 'J.GetCenterOfUnits' }) do
    local n, i = 0, 0
    while body do
        i = body:find(k, i + 1, true)
        if i == nil then break end
        n = n + 1
    end
    G['COPY_' .. k:gsub('[^%w]', '_')] = n
end

-- The shipped kill-confirms, read off the entry: this is what makes "both
-- branches are executes" a parsed fact rather than prose.
G.SHIP_KILLCONFIRM = 0
if body then
    for _ in body:gmatch('J%.CanKillTarget') do
        G.SHIP_KILLCONFIRM = G.SHIP_KILLCONFIRM + 1
    end
end
G.SHIP_GOINGON = (body and body:find('J.IsGoingOnSomeone(bot)', 1, true)) and 1 or 0
G.SHIP_ALLYDMG =
    (body and body:find('J.GetTotalEstimatedDamageToTarget', 1, true)) and 1 or 0
G.SHIP_FACING_CONE = tonumber(body and body:match('IsFacingLocation%b()')
    and body:match('IsFacingLocation%(enemyHero:GetLocation%(%), (%d+)%)')) or -1

-- Condition (c), counted rather than asserted as a flag: the item is on the buy
-- list of this many hero files under bots/BotLib.  A presence flag reads the
-- same whether that is one hero or forty (the 'stayurn' M6 survivor).
do
    local p = assert(io.popen(
        "grep -rl 'item_blood_grenade' bots/BotLib/ 2>/dev/null | wc -l"))
    G.BUYLIST_HERO_FILES = tonumber(p:read('*a')) or -1
    p:close()
end

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
for _, k in ipairs({ 'fixtures', 'live', 'carrier_main', 'carrier_any',
    'loop', 'cand', 'ship_kill125', 'ship_kill275', 'hp_floor',
    'domain', 'domain_no_hpfloor', 'raises', 'arm_leak',
    'flips', 'flip_true_to_false', 'flips_swapped', 'flip_true_to_false_swapped',
    'driven', 'undriven', 'aiug_fail', 'think_crash', 'cast_ship', 'cast_armed' }) do
    rawset(c, k, 0)
end

--- ⛔ ONE tally for both directions, called twice with the legs swapped.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
end

local aiug = assert(loadfile(AIUG))

--- Supply the clauses the fixture loader cannot know, and ONLY those: the
--- castability flags the mock leaves false (GH #89).  Every other conjunct of
--- the decision is left to the shipped code.  Grenade handle only.
local function make_castable(bot)
    local found = false
    for i = 0, 8 do
        local h = bot:GetItemInSlot(i)
        if h ~= nil and h:GetName() == GREN then
            h.IsTrained = function() return true end
            h.IsActivated = function() return true end
            h.IsFullyCastable = function() return true end
            h.IsPassive = function() return false end
            h.IsHidden = function() return false end
            h.IsNull = function() return false end
            found = true
        end
    end
    return found
end

--- One driven frame: load, arm, run the shipped item think, report whether the
--- GRENADE specifically was cast.  Any other item this frame casts is
--- irrelevant here and is not counted.
local function drive(path, name, armed)
    local ok, J, bot = pcall(rf.load, path, name)
    if not ok or bot == nil then return nil end
    J.IsSoakCandidate = function(sId) return armed and sId == 'grenharass' end
    -- The arming must be ONE id wide: a stub arming everything would let some
    -- other live id move this answer while the flip is still credited here
    -- (the M8 survivor of the 'stayattr' round).
    if J.IsSoakCandidate('urnself') or J.IsSoakCandidate('wandbleed')
        or J.IsSoakCandidate('slotdust') then
        bump('arm_leak')
    end
    if not make_castable(bot) then return nil end
    if not pcall(aiug) then
        bump('aiug_fail')
        return nil
    end
    local log = rf.record_actions(bot)
    bot.lastItemFrameProcessTime = DotaTime() - 100
    if not pcall(_G.ItemUsageThink) then
        bump('think_crash')
        return nil
    end
    for _, e in ipairs(log) do
        local a = e.args[1]
        if type(a) == 'table' and a.GetName and a:GetName() == GREN then
            return true
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
                    local bMain, bAny = false, false
                    for i = 0, 8 do
                        local h = bot:GetItemInSlot(i)
                        if h ~= nil and h:GetName() == GREN then
                            bAny = true
                            if i <= 5 then bMain = true end
                        end
                    end
                    if bAny then bump('carrier_any') end
                    if bMain then
                        bump('carrier_main')
                        local okE, es = pcall(J.GetNearbyHeroes, bot, G.CAST_RANGE, true, 0)
                        if not okE then
                            bump('raises')
                        elseif es ~= nil and #es > 0 then
                            bump('loop')
                            local sFx = path:match('([^/]+)%.lua$')
                            local sHero = u.name:gsub('npc_dota_hero_', '')
                            local nSelf = bot:GetHealth()
                            local bCand, bK125, bK275, bDom = false, false, false, false
                            local nMinDist, nTargetHp = 1e9, -1
                            for _, e in pairs(es) do
                                local d = GetUnitToUnitDistance(bot, e)
                                if d < nMinDist then nMinDist = d end
                                if J.IsValidHero(e) and J.CanCastOnNonMagicImmune(e)
                                    and not J.IsSuspiciousIllusion(e) then
                                    bCand = true
                                    local nTot = G.IMPACT + G.DPS * G.DURATION
                                    if J.CanKillTarget(e, nTot, DAMAGE_TYPE_MAGICAL) then
                                        bK125 = true
                                    end
                                    if J.CanKillTarget(e, nTot + 150, DAMAGE_TYPE_MAGICAL) then
                                        bK275 = true
                                    end
                                    if e:GetHealth() <= nTot * 3 then
                                        if not bDom then nTargetHp = e:GetHealth() end
                                        bDom = true
                                    end
                                end
                            end
                            if bCand then bump('cand') end
                            if bK125 then bump('ship_kill125') end
                            if bK275 then bump('ship_kill275') end
                            local bFloor = nSelf > G.HEALTH_COST * 2
                            if bFloor then bump('hp_floor') end
                            if bDom then bump('domain_no_hpfloor') end
                            if bDom and bFloor then bump('domain') end

                            local shipped = drive(path, u.name, false)
                            local armed = drive(path, u.name, true)
                            -- `driven` + `undriven` == `loop` is asserted
                            -- downstream: a frame is counted exactly once here,
                            -- so a drive that dies cannot quietly shrink the
                            -- denominator the flip columns are read against.
                            if shipped == nil or armed == nil then
                                bump('undriven')
                            else
                                bump('driven')
                                if shipped then bump('cast_ship') end
                                if armed then bump('cast_armed') end
                                tally(armed, shipped, 'flips', 'flip_true_to_false')
                                -- Legs EXCHANGED, same `tally`: the counter that
                                -- must read 0 on the real call is the one that
                                -- must report the WHOLE flip set here.
                                tally(shipped, armed,
                                    'flips_swapped', 'flip_true_to_false_swapped')
                                if armed and not shipped then
                                    out:write(string.format('F %s %s %d\n',
                                        sFx, sHero, nTargetHp))
                                end
                            end
                            out:write(string.format('W %s %s %d %.0f %d %d %s %s\n',
                                sFx, sHero, #es, nMinDist, nTargetHp, nSelf,
                                tostring(shipped), tostring(armed)))
                        end
                    end
                end
            end
        end
    end
end

local ks = {}
for k in pairs(c) do ks[#ks + 1] = k end
table.sort(ks)
for _, k in ipairs(ks) do out:write(string.format('C %s %d\n', k, c[k])) end
out:write('DONE\n')
