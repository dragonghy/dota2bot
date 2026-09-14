-- Corpus sweep for tests/test_stayfield_tpleg_live_domain.lua (charter 0NEXT12).
--
-- Deliberately NOT named test_*.lua: run_tests.lua globs '^test_.*%.lua$', and
-- this file is meant to be run in its own process by that test via io.popen --
-- same reason as tests/_stayfield2_livedomain_sweep.lua and tests/_tprecov_sweep.lua.
--
-- ⭐ WHAT IS MEASURED, and why it is NOT a repeat of the walk leg.
--
-- 'stayfield' and 'stayfield2' are two soak ids over ONE predicate:
--
--     J.ShouldRegenNotTpHome( bot )   = IsSoakCandidate('stayfield')  and S
--     J.ShouldRegenNotWalkHome( bot ) = IsSoakCandidate('stayfield2') and S
--     S = J.ShouldRegenNotGoHome = IsFieldRegenSituation
--                                  and HasFieldRegenSource
--                                  and IsFieldSipEnough        -- 'fieldsip', ARMED
--
-- tests/test_stayfield2_live_domain.lua (2026-09-14) measured S on today's
-- member string and found 2 live frames, down from 24 in a world where only
-- `stayfield2` was armed -- 22 taken by `fieldsip`'s magnitude clause. Because
-- the two wrappers SHARE S, that same 2 is the ceiling here.
--
-- ⛔ BUT 2 IS NOT THE ANSWER, AND THAT IS THE WHOLE REASON THIS FILE EXISTS.
-- A guard's domain is its predicate INTERSECTED with the rest of the
-- conjunction it was dropped into (tests/test_stayfield_callsite_domain.lua),
-- and the two wrappers were dropped into DIFFERENT conjunctions:
--
--   * the walk leg's absorber is J.ShouldStayAndRegen, one statement above it;
--   * the TP leg's absorber is the '撤退:3' branch's OWN 20-odd conjuncts in
--     X.ConsiderItemDesire["item_tpscroll"] (bots/ability_item_usage_generic.lua),
--     which is a different object entirely.
--
-- So `margin(stayfield) = branch_open AND S_live` has to be COUNTED. Charter
-- 0NEXT12 says in as many words: do not read the walk leg's 0 onto this leg.
--
-- ⭐⭐ THE COLUMN THAT DECIDES IT: `s_live_blocked_by_branch`. S's supply set
-- (J.HasFieldRegenSource) is {flask, tango, tango_single, faerie_fire, charged
-- bottle}; the '撤退:3' branch already requires `itemFlask == nil` and negates
-- eight heal modifiers including tango_heal and flask_healing. If every live S
-- frame is stopped by a conjunct the branch ALREADY carries, then arming
-- `stayfield` cannot change one frame -- and that is a closed-form statement
-- about an intersection, not a sampling accident. Every such frame is emitted
-- WITH the blocking conjunct named (the `B` rows), so "the branch would have
-- done it anyway" can never be assumed from a count.
--
-- ⛔ DIRECTION GOES THROUGH A COUNTER THAT IS PROVED TO COUNT. This lever is a
-- veto (`and not J.ShouldRegenNotTpHome( bot )`), so arming it can only turn the
-- branch's TRUE into FALSE and `flip_false_to_true` must be 0 over the whole
-- corpus. A counter whose content is all zeros cannot tell "the direction holds"
-- from "the tally never ran", so both directions go through ONE
-- `tally(a, b, sDown, sUp)` and it is called a SECOND time with the legs
-- SWAPPED: the branch that must read 0 on the real call is the branch that must
-- report the WHOLE domain on the swapped call.
--
-- ⚠️ WHAT THIS FILE DOES NOT DRIVE, stated because it is a real limit.
--   * `X` in ability_item_usage_generic is a FILE-LOCAL table, so `X.CanJuke()`
--     and `X.GetNumHeroWithinRange( 1600 )` cannot be called from here. The
--     enemy ring is read with the same readable proxy tests/_tprecov_sweep.lua
--     uses (`#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)`); CanJuke is
--     NOT modelled at all.
--   * `bot:DistanceFromFountain() > nMinTPDistance - 600` is reported as its own
--     counter (`open_far`) and is NOT folded into `branch_open`, so this file's
--     headline stays comparable with the tprecov sweep's `branch_open`.
--   ⇒ `branch_open` is an UPPER BOUND on the branch's reachability, never a
--     claim that the branch fires. An upper bound is the right side of the
--     inequality for a ZERO finding and the wrong side for a positive one, and
--     the calling test asserts only the zero.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   R <fixture> <hero> <hp> <mp> <lvl> <stop>
--       one live frame inside the '撤退:3' trigger, with the first branch
--       conjunct that closes it: lvl | ring | allies | attackally | flask |
--       modifier | name | target | open.  Every trigger frame gets a row, in
--       the domain or not -- the anti-vacuum column.
--   O <fixture> <hero> <hp> <lvl> solo_w=<0|1> live_w=<0|1>
--       one live frame where the branch is OPEN by every readable conjunct,
--       with the wrapper's answer in each of the two worlds.
--   B <fixture> <hero> <why>
--       one frame where S is TRUE on the live member string, with the branch
--       conjunct that already falsifies the branch: NOT_BLOCKED if none does.
--   DONE
-- Absence of the final DONE line is a failed subprocess.
--
-- Usage: lua5.1 tests/_stayfield_tpleg_sweep.lua '<armed csv>'

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local ARMED_CSV = ...
assert(type(ARMED_CSV) == 'string' and ARMED_CSV ~= '',
    'usage: lua5.1 tests/_stayfield_tpleg_sweep.lua "<armed csv>"')

local out = io.stdout
local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- Structural facts are claims about CODE. Both files carry long comments that
--- name the very helpers and modifiers asserted below, so reading the raw text
--- would let a COMMENT satisfy the assertion.
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The text of one home-TP branch, from its trigger to its own cast motive.
--- Anchored on the motive STRING (code, never a comment) so no comment can
--- open or close a block.
local function branch(src, sHead, sMotive)
    local a = src:find(sHead, 1, true)
    if a == nil then return nil end
    local b = src:find("sCastMotive = '" .. sMotive .. "'", a, true)
    if b == nil then return nil end
    return strip_comments(src:sub(a, b))
end

local function count(s, needle)
    if s == nil then return 0 end
    local n, at = 0, 1
    while true do
        local i = s:find(needle, at, true)
        if i == nil then break end
        n = n + 1
        at = i + 1
    end
    return n
end

local aiug = read_file(AIUG)
local jmz = strip_comments(read_file(JMZ))

local G = {}

local b3 = branch(aiug, 'if ( botHP < 0.34 or botHP + botMP < 0.43 )', '撤退:3')
G.BRANCH_T3 = b3 and 1 or 0
G.T3_REGENNOTTP = count(b3, 'J.ShouldRegenNotTpHome')
G.T3_ITEMFLASK = count(b3, 'itemFlask == nil')
G.T3_TANGO_HEAL = count(b3, 'modifier_tango_heal')
G.T3_FLASK_HEALING = count(b3, 'modifier_flask_healing')
G.T3_ATTACKTARGET = count(b3, 'bot:GetAttackTarget() == nil')
G.T3_LEVEL9 = count(b3, 'bot:GetLevel() >= 9')
-- One lever, one call site: the TP wrapper must appear nowhere else in the
-- shipped tree, or this file is measuring one of several domains.
G.TPWRAPPER_CALLSITES = count(strip_comments(aiug), 'J.ShouldRegenNotTpHome')
-- The gate, read off the helper rather than believed from the branch comment.
G.WRAPPER_GATED_STAYFIELD =
    jmz:find("function%s+J%.ShouldRegenNotTpHome") and
    (jmz:match("function%s+J%.ShouldRegenNotTpHome.-\nend") or ''):find(
        "IsSoakCandidate%(%s*'stayfield'%s*%)") and 1 or 0
G.WRAPPER_DELEGATES_S =
    (jmz:match("function%s+J%.ShouldRegenNotTpHome.-\nend") or ''):find(
        'J.ShouldRegenNotGoHome', 1, true) and 1 or 0

-- The branch trigger constants, parsed rather than retyped.
G.T3_HP_TRIGGER = tonumber(b3 and b3:match('botHP < ([%d%.]+)')) or -1
G.T3_SUM_TRIGGER = tonumber(b3 and b3:match('botHP %+ botMP < ([%d%.]+)')) or -1
G.T3_LEVEL = tonumber(b3 and b3:match('GetLevel%(%) >= (%d+)')) or -1
G.T3_ENEMY_CAP = tonumber(b3 and b3:match('nEnemyCount <= (%d+)')) or -1
G.T3_ALLY_CAP = tonumber(b3 and b3:match('nAllyCount <= (%d+)')) or -1

local HP_TRIG = G.T3_HP_TRIGGER
local SUM_TRIG = G.T3_SUM_TRIGGER
local LVL = G.T3_LEVEL
local ENEMY_CAP = G.T3_ENEMY_CAP
local ALLY_CAP = G.T3_ALLY_CAP
assert(HP_TRIG > 0 and SUM_TRIG > 0 and LVL > 0 and ENEMY_CAP >= 0 and ALLY_CAP >= 0,
    'the 撤退:3 branch head could not be parsed; the sweep refuses to run on '
    .. 'retyped constants')

-- The eight heal modifiers the branch negates, in branch order.
local BRANCH_MODIFIERS = {
    'modifier_flask_healing', 'modifier_clarity_potion', 'modifier_filler_heal',
    'modifier_item_urn_heal', 'modifier_item_spirit_vessel_heal',
    'modifier_juggernaut_healing_ward_heal', 'modifier_bottle_regeneration',
    'modifier_tango_heal',
}
local nModsInBranch = 0
for _, m in ipairs(BRANCH_MODIFIERS) do
    if count(b3, m) > 0 then nModsInBranch = nModsInBranch + 1 end
end
G.T3_MODIFIER_VETOES = nModsInBranch

local function split(csv)
    local t = {}
    for a in tostring(csv):gmatch('[^,]+') do t[#t + 1] = a end
    return t
end

local ARMED_LIVE = split(ARMED_CSV)
local SOLO = { 'stayfield' }
G.ARMED_N = #ARMED_LIVE

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

local function hero_names(path)
    local fx = dofile('tests/fixtures/' .. path)
    local t = {}
    for _, u in ipairs(fx.units or {}) do
        if type(u.name) == 'string' and u.name:match('^npc_dota_hero_') then
            t[#t + 1] = u.name
        end
    end
    return t
end

--- Install one fixture with one hero as the subject, in the HONEST turbo world
--- (GH #93: by name the fixture world is Turbo, by the literal 23 it is not,
--- and every predicate here opens with IsModeTurbo).
local function world(path, subject)
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load('tests/fixtures/' .. path, subject)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    return J, bot
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ONE LOAD, TWO WORLDS: every predicate reads J.IsSoakCandidate at CALL time,
--- so re-pointing the closure between two readings gives the same two worlds as
--- two rf.load calls at half the fixture-loading cost. Same device, and the same
--- stated assumption, as tests/_stayfield2_livedomain_sweep.lua: nothing between
--- load and call may MEMOISE a gate answer.
local function arm(J, list)
    local set = {}
    for _, a in ipairs(list) do set[a] = true end
    J.IsSoakCandidate = function(id) return set[id] == true end
end

local c = {}
local function bump(k) c[k] = (c[k] or 0) + 1 end

--- One tally, used twice with its legs exchanged. `sUp` on the real call must be
--- 0 (a veto cannot open a branch); on the swapped call the same bump must carry
--- the whole domain, so an all-zero column cannot pass for a proof.
local function tally(a, b, sDown, sUp)
    if b and not a then bump(sDown) end
    if a and not b then bump(sUp) end
end

--- The first branch conjunct that closes '撤退:3' on this frame, walked in
--- branch order. Buckets sum to `trigger` by counting.
local function branch_stop(J, bot, sName)
    if bot:GetLevel() < LVL then return 'lvl' end
    if #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) > ENEMY_CAP then return 'ring' end
    if J.GetAllyCount(bot, 1600) > ALLY_CAP then return 'allies' end
    if #J.GetNearbyHeroes(bot, 1500, false, BOT_MODE_ATTACK) > 0 then return 'attackally' end
    if J.IsItemAvailable('item_flask') ~= nil then return 'flask' end
    if sName == 'npc_dota_hero_huskar' or sName == 'npc_dota_hero_slark' then return 'name' end
    for _, m in ipairs(BRANCH_MODIFIERS) do
        if bot:HasModifier(m) then return 'modifier' end
    end
    if bot:GetAttackTarget() ~= nil then return 'target' end
    return 'open'
end

--- Which conjunct the branch ALREADY carries falsifies it on this frame. The
--- order mirrors J.HasFieldRegenSource's supply set so the answer names the
--- supply the bot was holding, not merely "something".
local function why_blocked(J, bot)
    if J.IsItemAvailable('item_flask') ~= nil then return 'branch_vetoes_itemFlask' end
    if bot:HasModifier('modifier_tango_heal') then return 'branch_vetoes_tango_heal' end
    if bot:HasModifier('modifier_flask_healing') then return 'branch_vetoes_flask_healing' end
    if bot:HasModifier('modifier_bottle_regeneration') then return 'branch_vetoes_bottle' end
    for _, m in ipairs(BRANCH_MODIFIERS) do
        if bot:HasModifier(m) then return 'branch_vetoes_modifier' end
    end
    if bot:GetLevel() < LVL then return 'branch_vetoes_level' end
    if #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) > ENEMY_CAP then
        return 'branch_vetoes_ring'
    end
    return 'NOT_BLOCKED'
end

local rows, brows = {}, {}

for _, path in ipairs(fixture_files()) do
    for _, hero in ipairs(hero_names(path)) do
        local ok, err = pcall(function()
            local J, bot = world(path, hero)
            if bot == nil or not bot:IsAlive() then return end
            bump('frames')

            local nHP = J.GetHP(bot)
            local nMP = J.GetMP(bot)

            arm(J, SOLO)
            local S0 = J.ShouldRegenNotGoHome(bot) == true
            local W0 = J.ShouldRegenNotTpHome(bot) == true
            arm(J, ARMED_LIVE)
            local S1 = J.ShouldRegenNotGoHome(bot) == true
            local W1 = J.ShouldRegenNotTpHome(bot) == true

            if S0 then bump('solo_S') end
            if S1 then bump('live_S') end
            if W0 then bump('solo_wrapper') end
            if W1 then bump('live_wrapper') end
            if S0 and not S1 then
                bump('s_lost')
                -- Attribute the loss: the situation half carries no gate of its
                -- own, so "situation still true but the magnitude clause says
                -- no" is exactly `fieldsip` and nothing else.
                if J.IsFieldRegenSituation(bot) == true
                    and J.IsFieldSipEnough(bot) ~= true then
                    bump('s_lost_sip')
                else
                    bump('s_lost_other')
                end
            end

            local bTrigger = (nHP < HP_TRIG) or (nHP + nMP < SUM_TRIG)
            local sStop = 'no_trigger'
            if bTrigger then
                bump('trigger')
                if nHP < HP_TRIG then bump('trigger_hp_leg') else bump('trigger_sum_leg') end
                sStop = branch_stop(J, bot, hero)
                bump('stop_' .. sStop)
                rows[#rows + 1] = string.format('R %s %s %.3f %.3f %d %s',
                    path, hero, nHP, nMP, bot:GetLevel(), sStop)
            end

            local bOpen = bTrigger and sStop == 'open'
            if bOpen then
                bump('branch_open')
                local okFar, far = pcall(function() return bot:DistanceFromFountain() end)
                if okFar and type(far) == 'number' and far > 5500 - 600 then
                    bump('open_far')
                end
                -- ⭐ THE INTERSECTION, counted rather than argued: a frame the
                -- wrapper answers TRUE on but the branch already vetoes changes
                -- nothing, and a frame the branch leaves open but the wrapper
                -- says nothing about changes nothing either.
                if W0 then bump('margin_solo') end
                if W1 then bump('margin_live') end
            end

            -- Shipped vs armed AT THE BRANCH. Unarmed the wrapper is the literal
            -- false, so `not wrapper` is true and the branch's fate is bOpen.
            local bFiresShipped = bOpen
            local bFiresArmed = bOpen and not W1
            tally(bFiresArmed, bFiresShipped, 'closes', 'flip_false_to_true')
            tally(bFiresShipped, bFiresArmed, 'closes_swapped', 'flip_false_to_true_swapped')
            -- ⭐ THE ANTI-VACUUM CALL, and it is not the swap. When the live
            -- domain is EMPTY, `closes` and `flip_false_to_true` are BOTH zero
            -- and so are both swapped legs -- exchanging the arguments of a
            -- tally whose two inputs are equal on every frame proves nothing.
            -- What does prove the counter counts is the SAME tally in the SOLO
            -- world, where the domain is not empty: `closes_solo` must carry it.
            local bFiresSolo = bOpen and not W0
            tally(bFiresSolo, bFiresShipped, 'closes_solo', 'flip_false_to_true_solo')

            if bOpen then
                out:write(string.format('O %s %s %.3f %d solo_w=%d live_w=%d\n',
                    path, hero, nHP, bot:GetLevel(), W0 and 1 or 0, W1 and 1 or 0))
            end

            -- Every live-S frame gets a B row whether or not the branch blocks
            -- it: the anti-vacuum column for the closed-form claim.
            if S1 then
                local sWhy = why_blocked(J, bot)
                if sWhy ~= 'NOT_BLOCKED' then bump('s_live_blocked_by_branch') end
                brows[#brows + 1] = string.format('B %s %s %s', path, hero, sWhy)
            end
        end)
        if not ok then
            bump('raises')
            out:write('ERR ' .. path .. ' ' .. hero .. ' ' .. tostring(err) .. '\n')
        end
        unprobe()
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

for _, l in ipairs(rows) do out:write(l .. '\n') end
for _, l in ipairs(brows) do out:write(l .. '\n') end
out:write('DONE\n')
