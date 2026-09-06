-- Heavy corpus sweep for tests/test_urnself_self_patient.lua, run as a
-- SUBPROCESS: it re-executes the 8,500-line item file once per urn-carrying
-- hero-frame per column, which must not happen on run_tests.lua's long-lived
-- heap (the 2026-08-21T20:35Z lesson).  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  X.ConsiderItemDesire["item_urn_of_shadows"] has an ALLY
-- branch and no SELF branch: its patient loop is `bot:GetNearbyHeroes(...)`,
-- which does not return the caller.  The sibling entry in the same table,
-- X.ConsiderItemDesire["item_flask"] -- the same 400 health -- has BOTH, with
-- three ids of arbitration between them.  The 'urnself' lever appends the self
-- branch, and only where the ally branch already declined.
--
-- ⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  Every cast column comes from
-- running the shipped `_G.ItemUsageThink` and reading the recorded engine
-- action.  Nothing here re-implements the decision.  The mirrored prefix walk
-- exists for a DIFFERENT question -- how big is the domain and which conjunct
-- binds it -- and the two are cross-checked: `domain_selfonly` (mirrored) and
-- `casts_armed_c1` (driven) must be EQUAL, and the test asserts that.
--
-- ⚠️ TWO CLAUSES THE LOADER NEVER WIRES, DECLARED RATHER THAN HIDDEN.  A fixture
-- item handle answers IsTrained/IsActivated/IsFullyCastable falsely and
-- GetCurrentCharges as 0 (GH #89 for the first pair; charges are per-frame
-- runtime state that no .dem carries, tests/mock/replay_fixture.lua).  So the
-- shipped dispatcher's `if J.CanCastAbility(hItem)` gate and this entry's own
-- first line `GetCurrentCharges() == 0` would make EVERY column read 0 -- a
-- number that looks exactly like "the lever does nothing".  The urn handle is
-- therefore made honest (the same probe `_itemdesire_sweep.lua` runs for the TP
-- scroll), and the corpus is driven in TWO charge columns, c0 and c1.  BOTH are
-- emitted and BOTH are asserted: c0 must be 0 everywhere (the entry's own first
-- line still refuses) and c1 carries the domain.
--
-- ⛔ DIRECTION IS ASSERTED THROUGH A COUNTER THAT IS PROVED TO COUNT.  Arming
-- can only turn DESIRE_NONE into a cast, so `loss` (armed casts fewer than
-- shipped) must be 0 over the whole corpus.  A counter whose content is all
-- zeros cannot tell "the direction holds" from "the tally never ran" -- deleting
-- its bump would leave the manifest byte-identical (the M14 lesson of the
-- 'staytower' round).  So both directions go through ONE `tally(a, b, sDown,
-- sUp)` and it is called a SECOND time with the two legs SWAPPED: the branch
-- that must read 0 on the real call is the branch that must report the WHOLE
-- domain on the swapped call.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>       a constant / structural fact parsed out of the tree
--   C <key> <n>            a counter bucket
--   D <fixture> <hero> <hp> <missing> <ally_qualifies 0|1>
--       one live frame where the bot itself satisfies the ally loop's own
--       conjuncts (every such frame, ally-competitor or not -- the anti-vacuum
--       column)
--   K <col> <arm> <fixture> <hero>   one DRIVEN urn cast
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local AIUG = 'bots/ability_item_usage_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- The urn consider function, sliced by its own key so a clause of the same
-- shape elsewhere in this 8,500-line file cannot be picked up by mistake.
local src = read_file(AIUG)
--
-- ⚠️ THE END OF THE SLICE IS NEWLINE-ANCHORED, and that is not decoration.  The
-- unanchored needle `X.ConsiderItemDesire[` -- which is what the sibling sweep
-- for item_faerie_fire uses -- is matched by this lever's own COMMENT, which
-- names X.ConsiderItemDesire["item_flask"] as its condition-(c) argument.  The
-- first run of this file cut the block at that comment and reported the self
-- branch as ABSENT from a file that contains it: URN_NIDS 0, SELF_ASSIGNS_BOT 0,
-- SELF_AFTER_ALLY_RETURN 0 -- three structural facts reading exactly as they
-- would if the lever had never been written.  A comment must not be able to move
-- a structural boundary; entries start at column 0, comments do not.
local at = src:find('X.ConsiderItemDesire["item_urn_of_shadows"] = function', 1, true)
local blk = nil
if at ~= nil then
    local stop = src:find('\nX.ConsiderItemDesire[', at + 10, true) or #src
    blk = src:sub(at, stop)
end

-- Structural facts are claims about CODE, and this lever ships with a long
-- comment naming the sibling entry, the ids, the constants and the modifiers in
-- prose.  Reading the raw block would let the COMMENT satisfy the assertions.
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end
local body = strip_comments(blk)

local G = {}
G.URN_BLOCK = blk and 1 or 0
G.URN_STRIPPED = (body and not body:find('--', 1, true)) and 1 or 0

-- The ally loop and the self block, as two halves of the same stripped body, so
-- "copied clause for clause" is checked rather than asserted in prose.  The
-- split point is the ally branch's own return, which is what makes this lever a
-- pure append: reaching the self block already proves no ally qualified.
local at_self = body and body:find("J.IsSoakCandidate( 'urnself' )", 1, true)
local at_ally = body and body:find('hNeedHealAlly = npcAlly', 1, true)
local at_return = body and body:find('hEffectTarget = hNeedHealAlly', 1, true)
G.SELF_AFTER_ALLY_RETURN =
    (at_self and at_ally and at_return and at_self > at_return and at_return > at_ally)
    and 1 or 0
local ally_half = (body and at_ally and at_return) and body:sub(at_ally - 900, at_return) or nil
local self_half = (body and at_self) and body:sub(at_self) or nil

local function nums(half)
    if half == nil then return {} end
    return {
        FOUNTAIN = tonumber(half:match('DistanceFromFountain%(%) > (%d+)')),
        DMGWIN = tonumber(half:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')),
        MISSING = tonumber(half:match('OriginalGetMaxHealth%(%) %- [%w%.:]+OriginalGetHealth%(%) > (%d+)')),
    }
end
local A, S = nums(ally_half), nums(self_half)
G.ALLY_FOUNTAIN, G.ALLY_DMGWIN, G.ALLY_MISSING = A.FOUNTAIN, A.DMGWIN, A.MISSING
G.SELF_FOUNTAIN, G.SELF_DMGWIN, G.SELF_MISSING = S.FOUNTAIN, S.DMGWIN, S.MISSING

-- The three heal modifiers the ally loop refuses on, counted on BOTH halves.
local MODS = { 'modifier_item_spirit_vessel_heal', 'modifier_item_urn_heal',
    'modifier_fountain_aura' }
local nAllyMods, nSelfMods = 0, 0
for _, m in ipairs(MODS) do
    if ally_half and ally_half:find(m, 1, true) then nAllyMods = nAllyMods + 1 end
    if self_half and self_half:find(m, 1, true) then nSelfMods = nSelfMods + 1 end
end
G.ALLY_HEALMODS, G.SELF_HEALMODS = nAllyMods, nSelfMods

-- ⚠️ THE NEEDLE CARRIES ITS OWN TERMINATOR.  `hEffectTarget = bot` is a PREFIX
-- of the attack branch's `hEffectTarget = botTarget` twelve lines up, so the
-- bare string finds a match whether or not the self branch exists -- a scouting
-- probe of this same lever reported SELF_MENTION=1 against the UNPATCHED file
-- for exactly that reason.  Anchored to end-of-statement instead.
G.SELF_ASSIGNS_BOT = (self_half and self_half:find('hEffectTarget = bot\n', 1, true))
    and 1 or 0
G.SELF_HAS_TURBO = (self_half and self_half:find('J.IsModeTurbo()', 1, true)) and 1 or 0
G.SELF_ENEMY_LIST = (self_half and self_half:find('#hNearbyEnemyHeroList == 0', 1, true))
    and 1 or 0

-- The 'pullcad' trap is TWO IDS IN ONE CONDITION.  Count both the function total
-- and the per-condition maximum; the second number is the invariant.
local nIds, nMax = 0, 0
if body then
    for _ in body:gmatch('IsSoakCandidate') do nIds = nIds + 1 end
    for cond in body:gmatch('if(.-)then') do
        local n = 0
        for _ in cond:gmatch('IsSoakCandidate') do n = n + 1 end
        if n > nMax then nMax = n end
    end
end
G.URN_NIDS, G.URN_IDS_MAX_PER_COND = nIds, nMax

-- The sibling that already has both branches, read off its own entry: this is
-- the whole condition-(c) argument, so it is a parsed fact and not prose.
local at_f = src:find('X.ConsiderItemDesire["item_flask"] = function', 1, true)
local flask = nil
if at_f ~= nil then
    local stop = src:find('\nX.ConsiderItemDesire[', at_f + 10, true) or #src
    flask = strip_comments(src:sub(at_f, stop))
end
G.FLASK_HAS_SELF = (flask and flask:find('hEffectTarget = bot\n', 1, true)) and 1 or 0
G.FLASK_HAS_ALLY = (flask and flask:find('hNeedHealAlly', 1, true)) and 1 or 0
-- ...and the id that arbitrates between them, which this lever deliberately
-- does not borrow.
G.FLASK_YIELD_ID = (flask and flask:find('J.ShouldYieldSalveToAlly', 1, true)) and 1 or 0

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
for _, k in ipairs({ 'fixtures', 'live', 'has_urn', 'charges_nonzero',
    'self_missing_ok', 'self_far_ok', 'self_undamaged', 'self_no_healmod',
    'self_castable', 'no_enemy_1000', 'self_qualifies', 'ally_qualifies',
    'domain_selfonly', 'domain_with_ally', 'in_stay_band',
    'driven_frames', 'aiug_fail', 'think_crash',
    'casts_ship_c0', 'casts_armed_c0', 'casts_ship_c1', 'casts_armed_c1',
    'gain', 'loss', 'gain_swapped', 'loss_swapped', 'arm_leak' }) do
    rawset(c, k, 0)
end

--- ⛔ ONE tally for both directions, called twice with the legs swapped.  The
--- branch that must read 0 on the real call (`loss`) is the branch that must
--- report the whole domain on the swapped call (`loss_swapped`), so deleting
--- either bump moves the manifest.  See the header.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
end

local FOUNTAIN = G.ALLY_FOUNTAIN or 800
local DMGWIN = G.ALLY_DMGWIN or 3.1
local MISSING = G.ALLY_MISSING or 450
local RANGE = tonumber(body and body:match('local nCastRange = (%d+)')) or 950
out:write(string.format('G ALLY_CASTRANGE %s\n', tostring(RANGE)))

local aiug = assert(loadfile(AIUG))

--- Supply the clauses the fixture loader cannot know, and ONLY those: the two
--- castability flags the mock leaves false (GH #89) and the charge count no .dem
--- carries.  Every other conjunct of the decision is left to the shipped code.
local function make_honest(bot, nCharges)
    local found = false
    for i = 0, 8 do
        local h = bot:GetItemInSlot(i)
        if h ~= nil and h:GetName() == 'item_urn_of_shadows' then
            h.GetCurrentCharges = function() return nCharges end
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
--- URN specifically was cast.  Any other item this frame casts is irrelevant
--- here and is not counted.
local function drive(path, name, nCharges, armed)
    local ok, J, bot = pcall(rf.load, path, name)
    if not ok or bot == nil then return nil end
    J.IsSoakCandidate = function(sId) return armed and sId == 'urnself' end
    -- The arming must be ONE id wide: a stub arming everything would let some
    -- other live id move this answer while the flip is still credited here.
    if J.IsSoakCandidate('stayfield') or J.IsSoakCandidate('salveyield')
        or J.IsSoakCandidate('fieldbuy') then
        bump('arm_leak')
    end
    make_honest(bot, nCharges)
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
        if type(a) == 'table' and a.GetName and a:GetName() == 'item_urn_of_shadows' then
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
                    local bUrn = false
                    for i = 0, 8 do
                        local h = bot:GetItemInSlot(i)
                        if h ~= nil and h:GetName() == 'item_urn_of_shadows' then
                            bUrn = true
                            if (tonumber(h:GetCurrentCharges()) or 0) > 0 then
                                bump('charges_nonzero')
                            end
                        end
                    end
                    if bUrn then
                        bump('has_urn')
                        -- The mirrored prefix walk.  Its job is the DOMAIN and
                        -- which conjunct binds it -- not the decision, which is
                        -- driven below and cross-checked against it.
                        local nEnemy = #J.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
                        local nMiss = bot:OriginalGetMaxHealth() - bot:OriginalGetHealth()
                        local c1 = nMiss > MISSING
                        local c2 = bot:DistanceFromFountain() > FOUNTAIN
                        local c3 = not bot:WasRecentlyDamagedByAnyHero(DMGWIN)
                        local c4 = not bot:HasModifier('modifier_item_urn_heal')
                            and not bot:HasModifier('modifier_item_spirit_vessel_heal')
                            and not bot:HasModifier('modifier_fountain_aura')
                        local c5 = J.CanCastOnNonMagicImmune(bot) and true or false
                        if c1 then bump('self_missing_ok') end
                        if c2 then bump('self_far_ok') end
                        if c3 then bump('self_undamaged') end
                        if c4 then bump('self_no_healmod') end
                        if c5 then bump('self_castable') end
                        if nEnemy == 0 then bump('no_enemy_1000') end
                        local bSelf = c1 and c2 and c3 and c4 and c5 and nEnemy == 0
                        local bAlly = false
                        for _, a in pairs(J.GetNearbyHeroes(bot, RANGE + 80, false,
                            BOT_MODE_NONE)) do
                            if J.IsValid(a) and not a:IsIllusion()
                                and a:DistanceFromFountain() > FOUNTAIN
                                and not a:WasRecentlyDamagedByAnyHero(DMGWIN)
                                and not a:HasModifier('modifier_item_urn_heal')
                                and not a:HasModifier('modifier_item_spirit_vessel_heal')
                                and not a:HasModifier('modifier_fountain_aura')
                                and a:OriginalGetMaxHealth() - a:OriginalGetHealth() > MISSING
                                and nEnemy == 0
                            then
                                bAlly = true
                            end
                        end
                        if bAlly then bump('ally_qualifies') end
                        if bSelf then
                            bump('self_qualifies')
                            if bAlly then bump('domain_with_ally')
                            else bump('domain_selfonly') end
                            local nHP = J.GetHP(bot)
                            if nHP >= 0.18 and nHP <= 0.75 then bump('in_stay_band') end
                            out:write(string.format('D %s %s %.4f %d %d\n',
                                path:match('([^/]+)%.lua$'), u.name, nHP, nMiss,
                                bAlly and 1 or 0))
                        end

                        -- The DRIVEN columns.  Restricted to urn carriers: a
                        -- frame with no urn cannot cast one, and re-executing
                        -- the item file for all 1012 frames x 4 runs is what the
                        -- chunking rule exists to prevent.
                        bump('driven_frames')
                        local s0 = drive(path, u.name, 0, false)
                        local a0 = drive(path, u.name, 0, true)
                        local s1 = drive(path, u.name, 1, false)
                        local a1 = drive(path, u.name, 1, true)
                        if s0 then bump('casts_ship_c0') end
                        if a0 then bump('casts_armed_c0') end
                        if s1 then bump('casts_ship_c1') end
                        if a1 then bump('casts_armed_c1') end
                        if a1 and not s1 then
                            out:write(string.format('K c1 armed %s %s\n',
                                path:match('([^/]+)%.lua$'), u.name))
                        end
                        tally(s1, a1, 'loss', 'gain')
                        tally(a1, s1, 'loss_swapped', 'gain_swapped')
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
