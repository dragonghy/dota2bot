-- Heavy corpus sweep for tests/test_tprecov_recover_trip.lua, run as a
-- SUBPROCESS (a full-corpus drive that reloads the mock world once per
-- hero-frame must not run on run_tests.lua's long-lived heap).  The leading
-- underscore keeps run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  X.ConsiderItemDesire["item_tpscroll"]
-- (bots/ability_item_usage_generic.lua) has FOUR branches that set
-- `tpLoc = J.GetTeamFountain()`.  Three of them carry a regen veto; the fourth,
-- '回复状态', carries none -- and it is the only one of the four that does not
-- ask for `bot:WasRecentlyDamagedByAnyHero`, i.e. the quiet-field trip owner
-- priority P2 names.  'tprecov' adds one veto to that fourth branch.
--
-- ⭐ THE COLUMN THAT DECIDES WHETHER THE LEVER IS THE RIGHT ONE, and it is the
-- reason this file exists at all: `sar_true_in_trigger` and
-- `sar_blocked_by_branch`.  The obvious fix is to copy 撤退:1's conjunct
-- (`not J.ShouldStayAndRegen(bot)`) into this branch.  Driven over the corpus,
-- that guard is TRUE on exactly ONE frame inside this branch's trigger set --
-- and on that frame it is TRUE only via `modifier_tango_heal`, which the branch
-- ALREADY vetoes on.  Both numbers are emitted and both are asserted, so
-- "the promoted veto would have done it" can never be assumed here.
--
-- ⭐⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  `helper_*` comes from the
-- SHIPPED global J.ShouldSipNotTpRecover with J.IsSoakCandidate stubbed to
-- false and then to 'tprecov' only.  Nothing here re-implements the decision.
-- The per-frame `R` rows are a separate prefix walk whose only job is to say
-- WHICH clause stopped a trigger frame, so "the corpus has no domain" and "it
-- has a domain this helper rejects earlier" can never be the same reading.
--
-- ⛔ DIRECTION GOES THROUGH A COUNTER THAT IS PROVED TO COUNT.  This lever
-- appends a veto, so it can only turn the branch's TRUE into FALSE and
-- `flip_false_to_true` must be 0 over the whole corpus.  A counter whose
-- content is all zeros cannot tell "the direction holds" from "the tally never
-- ran", so both directions go through ONE `tally(a, b, sDown, sUp)` and it is
-- called a SECOND time with the legs SWAPPED: the branch that must read 0 on
-- the real call is the branch that must report the WHOLE domain on the swapped
-- call.  Deleting either bump moves the manifest instead of leaving it
-- byte-identical.
--
-- ⚠️ WHAT THIS FILE DOES NOT DRIVE, stated because it is a real limit and not a
-- footnote.  `X` in ability_item_usage_generic is a FILE-LOCAL table, so the
-- branch's own body cannot be called from here and neither can `X.CanJuke()`.
-- The branch conjuncts that ARE frame-readable (trigger, level, the eight
-- modifier vetoes, the main-slot flask, the 1600 enemy count) are evaluated on
-- the real frame and reported; `X.CanJuke()`, `J.GetProperTarget`, the ally
-- count, the fountain distance and the TP's castability are NOT, so
-- `branch_open` is an UPPER BOUND on the branch's reachability, never a claim
-- that the branch fires.  Same shape as tests/test_stayfield_callsite_domain.lua,
-- which proves its call-site emptiness in closed form for the same reason.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   R <fixture> <hero> <hp> <lvl> <stop>
--       one live frame inside the '回复状态' trigger, with the clause that
--       stops J.ShouldSipNotTpRecover: gate | turbo | floor | source | damage |
--       ring | tower | domain.  Every trigger frame gets a row, in the domain
--       or not -- the anti-vacuum column.
--   S <fixture> <hero> <why>
--       one live frame inside the trigger where J.ShouldStayAndRegen is TRUE,
--       with the branch conjunct that already falsifies it.
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- Structural facts are claims about CODE.  This lever ships with a long comment
-- that names J.ShouldStayAndRegen, both sibling branches and three file paths,
-- so reading the raw block would let the COMMENT satisfy the assertions.
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
local jmz = read_file(JMZ)

local G = {}

-- The four siblings, as a table read off code.  The whole finding is that ONE
-- of the four columns is zero, so all four are counted rather than flagged.
local b1 = branch(aiug, 'if botHP < 0.19', '撤退:1')
local b2 = branch(aiug, 'if botHP < ( 0.15 + 0.24 * nEnemyCount )', '撤退:2')
local b3 = branch(aiug, 'if ( botHP < 0.34 or botHP + botMP < 0.43 )', '撤退:3')
local b4 = branch(aiug, 'if ( botHP + botMP < 0.3 or botHP < 0.2 )', '回复状态')
G.BRANCH_T1 = b1 and 1 or 0
G.BRANCH_T2 = b2 and 1 or 0
G.BRANCH_T3 = b3 and 1 or 0
G.BRANCH_RECOVER = b4 and 1 or 0

G.T1_STAYANDREGEN = count(b1, 'J.ShouldStayAndRegen')
G.T2_REGEN_VETOES = count(b2, 'J.ShouldStayAndRegen') + count(b2, 'J.ShouldRegenNotTpHome')
    + count(b2, 'J.ShouldSipNotTpRecover')
G.T3_REGENNOTTP = count(b3, 'J.ShouldRegenNotTpHome')
-- The branch under repair: it must carry the NEW veto and must still carry
-- neither of its siblings' (one lever, one call site).
G.RECOVER_SIPVETO = count(b4, 'J.ShouldSipNotTpRecover')
G.RECOVER_STAYANDREGEN = count(b4, 'J.ShouldStayAndRegen')
G.RECOVER_REGENNOTTP = count(b4, 'J.ShouldRegenNotTpHome')

-- ⛔ The 'pullcad' trap: two ids in one condition.  Counted at the call site
-- AND in the helper; the maximum per condition is the invariant.
G.RECOVER_NIDS = count(b4, 'IsSoakCandidate')

-- The three conjuncts that empty J.ShouldStayAndRegen at this call site.  They
-- are the closed form, so they are read off the branch's own code.
G.RECOVER_FLASK_ITEM = count(b4, 'itemFlask == nil')
G.RECOVER_FLASKHEAL = count(b4, "modifier_flask_healing")
G.RECOVER_TANGOHEAL = count(b4, "modifier_tango_heal")
G.RECOVER_VETO_MODS = count(b4, 'HasModifier')
-- and the branch is NOT an escape: it asks for no recent hero damage, while
-- both 撤退 branches above it do.  Counted, because "this branch is the quiet
-- one" is the reason the lever is allowed to exist at all.
G.RECOVER_RECENTDMG = count(b4, 'WasRecentlyDamagedByAnyHero')
G.T1_RECENTDMG = count(b1, 'WasRecentlyDamagedByAnyHero')
G.T2_RECENTDMG = count(b2, 'WasRecentlyDamagedByAnyHero')

-- J.ShouldStayAndRegen's supply disjunction, the other half of the closed form.
local bhf = strip_comments(jmz:match('local bHasFlask =(.-)local bHasRegen'))
-- Counted as TERMS, not as the word `or`: the disjunction is written across
-- three lines, so a substring count of ' or ' reads 1 and would have made the
-- closed form look like a one-legged test.
G.SAR_BHASFLASK_DISJUNCTS = bhf and
    (count(bhf, 'HasModifier') + count(bhf, 'IsItemAvailable')) or 0
G.SAR_BHASFLASK_ITEM = count(bhf, "J.IsItemAvailable( 'item_flask' )")
G.SAR_BHASFLASK_FLASKMOD = count(bhf, 'modifier_flask_healing')
G.SAR_BHASFLASK_TANGOMOD = count(bhf, 'modifier_tango_heal')

-- The helper itself.
local helper = strip_comments(jmz:match('function J%.ShouldSipNotTpRecover.-\nend'))
G.HELPER_FN = helper and 1 or 0
G.HELPER_NIDS = count(helper, 'IsSoakCandidate')
G.HELPER_TURBO = count(helper, 'J.IsModeTurbo()')
-- The gate must be the FIRST thing asked: that is what makes the un-armed
-- evaluation byte-identical (no engine call below it is reached).  Read as an
-- ORDER inside the stripped body, so a comment naming either cannot move it.
local at_gate = helper and helper:find("IsSoakCandidate( 'tprecov' )", 1, true)
local at_turbo = helper and helper:find('IsModeTurbo()', 1, true)
local at_src = helper and helper:find('HasFieldRegenSource', 1, true)
local at_hp = helper and helper:find('J.GetHP(', 1, true)
-- ⚠️ An ABSENT clause must not flip this flag.  The first version required
-- `at_turbo < at_src`, so DELETING the supply read made GATE_FIRST read 0 and
-- the mutation stand went red with the wrong message (it named the gate order
-- for a mutant that had removed a narrowing clause).  Missing positions are
-- therefore treated as +inf: this flag answers "is the gate ahead of every read
-- that IS still here", and the presence of each clause is pinned separately.
local INF = math.huge
G.HELPER_GATE_FIRST = (at_gate and at_turbo
    and at_gate < at_turbo
    and at_gate < (at_hp or INF)
    and at_gate < (at_src or INF)) and 1 or 0
-- ⛔ The deliberate NON-routing.  Both of these would empty the lever on the
-- string the lab is running (fieldsip) or exclude 29 of its 31 trigger frames
-- (IsFieldRegenSituation's 0.18 floor is kept, its situation walk is not), so
-- their ABSENCE is an asserted property, not an omission.
-- The four load-bearing clauses, counted individually.  A single "the helper
-- exists" flag reads the same whether the body still narrows anything or has
-- been reduced to `return true`, and a corpus counter cannot see a clause whose
-- domain is already covered by an earlier one (here the 0.18 floor stops 29 of
-- 31 trigger frames BEFORE the supply and danger clauses are ever reached), so
-- these are structural pins on purpose.
G.HELPER_SOURCE = count(helper, 'J.HasFieldRegenSource')
G.HELPER_ATTRIB = count(helper, 'J.HasNearbyHeroDamager')
G.HELPER_RING = count(helper, 'J.GetNearbyHeroes( bot, 1200')
G.HELPER_TOWER = count(helper, 'bot:GetNearbyTowers( 1200')
G.HELPER_USES_FIELDSIP = count(helper, 'IsFieldSipEnough')
G.HELPER_USES_SITUATION = count(helper, 'IsFieldRegenSituation')
G.HELPER_USES_REGENNOTGOHOME = count(helper, 'ShouldRegenNotGoHome')
-- The floor is COPIED, not chosen: it must equal the two the family already
-- uses.  Parsed from all three bodies and compared downstream.
G.HELPER_FLOOR = tonumber(helper and helper:match('J%.GetHP%( bot %) < ([%d%.]+)')) or -1
local sar = strip_comments(jmz:match('function J%.ShouldStayAndRegen.-\nend\n'))
G.SAR_FLOOR = tonumber(sar and sar:match('nHP < ([%d%.]+)')) or -1
local frs = strip_comments(jmz:match('function J%.IsFieldRegenSituation.-\nend\n'))
G.SITUATION_FLOOR = tonumber(frs and frs:match('nHP < ([%d%.]+)')) or -1
-- The branch's own trigger constants, so the domain rows can be read against
-- numbers that came from the tree rather than from this file.
G.RECOVER_HP_TRIGGER = tonumber(b4 and b4:match('botHP < ([%d%.]+)')) or -1
G.RECOVER_SUM_TRIGGER = tonumber(b4 and b4:match('botHP %+ botMP < ([%d%.]+)')) or -1
G.RECOVER_LEVEL = tonumber(b4 and b4:match('bot:GetLevel%(%) >= (%d+)')) or -1

local gk = {}
for k in pairs(G) do gk[#gk + 1] = k end
table.sort(gk)
for _, k in ipairs(gk) do out:write(string.format('G %s %s\n', k, tostring(G[k]))) end

local HP_TRIG = G.RECOVER_HP_TRIGGER
local SUM_TRIG = G.RECOVER_SUM_TRIGGER
local LVL = G.RECOVER_LEVEL

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
for _, k in ipairs({ 'fixtures', 'live', 'raises', 'trigger', 'trigger_lvl',
    'helper_shipped_true', 'helper_armed_true', 'helper_true_in_trigger',
    'flips', 'flip_false_to_true', 'flips_swapped', 'flip_false_to_true_swapped',
    'arm_leak', 'sar_true_any', 'sar_true_in_trigger', 'sar_blocked_by_branch',
    'stop_floor', 'stop_source', 'stop_damage', 'stop_ring', 'stop_tower',
    'branch_open', 'trigger_hp_leg', 'trigger_sum_leg', 'domain_and_branch_open' }) do
    rawset(c, k, 0)
end

--- ONE tally for both directions, called twice with the legs swapped.
local function tally(a, b, sDown, sUp)
    if a and not b then bump(sDown) end
    if b and not a then bump(sUp) end
end

for _, path in ipairs(fixture_files()) do
    local fx = dofile(path)
    if type(fx) == 'table' and fx.units and fx.time then
        bump('fixtures')
        for _, u in ipairs(fx.units) do
            if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    local armed = false
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'tprecov'
                    end
                    local sFx = path:match('([^/]+)%.lua$')
                    local sHero = u.name:gsub('npc_dota_hero_', '')
                    local nHP, nMP = J.GetHP(bot), J.GetMP(bot)

                    local okShip, shipped = pcall(J.ShouldSipNotTpRecover, bot)
                    armed = true
                    -- The arming must be ONE id wide.  A stub arming them all
                    -- would let another live id move this answer while the flip
                    -- is still attributed here.  Asserted 0 downstream.
                    if J.IsSoakCandidate('stayfield') or J.IsSoakCandidate('fieldsip')
                        or J.IsSoakCandidate('staysrc') then
                        bump('arm_leak')
                    end
                    local okArm, arm = pcall(J.ShouldSipNotTpRecover, bot)
                    -- J.ShouldStayAndRegen is PROMOTED: it is read with the
                    -- stub still one-id wide, which cannot reach it.
                    local okSar, sar_true = pcall(J.ShouldStayAndRegen, bot)
                    armed = false

                    if not (okShip and okArm and okSar) then
                        bump('raises')
                    else
                        shipped = shipped and true or false
                        arm = arm and true or false
                        sar_true = sar_true and true or false

                        if shipped then bump('helper_shipped_true') end
                        if arm then bump('helper_armed_true') end
                        tally(arm, shipped, 'flips', 'flip_false_to_true')
                        -- Legs EXCHANGED, same `tally`.  The counter that must
                        -- read 0 on the real call is the one that must report
                        -- the WHOLE domain here.
                        tally(shipped, arm, 'flips_swapped', 'flip_false_to_true_swapped')
                        if sar_true then bump('sar_true_any') end

                        local bTrigger = (nHP + nMP < SUM_TRIG) or (nHP < HP_TRIG)
                        if bTrigger then
                            bump('trigger')
                            if nHP < HP_TRIG then bump('trigger_hp_leg')
                            else bump('trigger_sum_leg') end
                            if bot:GetLevel() >= LVL then bump('trigger_lvl') end

                            -- The prefix walk: which clause of the helper stops
                            -- this frame.  Buckets sum to `trigger` by counting.
                            local sStop
                            if nHP < G.HELPER_FLOOR then
                                sStop = 'floor'; bump('stop_floor')
                            elseif not J.HasFieldRegenSource(bot) then
                                sStop = 'source'; bump('stop_source')
                            elseif bot:WasRecentlyDamagedByAnyHero(3.0)
                                and J.HasNearbyHeroDamager(bot, 3000, 3.0) then
                                sStop = 'damage'; bump('stop_damage')
                            elseif #J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) > 0 then
                                sStop = 'ring'; bump('stop_ring')
                            elseif #bot:GetNearbyTowers(1200, true) > 0 then
                                sStop = 'tower'; bump('stop_tower')
                            else
                                sStop = 'domain'; bump('helper_true_in_trigger')
                            end
                            out:write(string.format('R %s %s %.3f %d %s\n',
                                sFx, sHero, nHP, bot:GetLevel(), sStop))

                            -- ⭐ The closed-form column.  A frame where the
                            -- PROMOTED veto is true inside this trigger is
                            -- reported WITH the branch conjunct that already
                            -- falsified it, so "just wire the promoted one in"
                            -- can never be assumed from a count alone.
                            if sar_true then
                                bump('sar_true_in_trigger')
                                local sWhy
                                if bot:HasModifier('modifier_tango_heal') then
                                    sWhy = 'branch_vetoes_tango_heal'
                                elseif bot:HasModifier('modifier_flask_healing') then
                                    sWhy = 'branch_vetoes_flask_healing'
                                elseif J.IsItemAvailable('item_flask') ~= nil then
                                    sWhy = 'branch_vetoes_itemFlask'
                                else
                                    sWhy = 'NOT_BLOCKED'
                                end
                                if sWhy ~= 'NOT_BLOCKED' then bump('sar_blocked_by_branch') end
                                out:write(string.format('S %s %s %s\n', sFx, sHero, sWhy))
                            end

                            -- UPPER BOUND on branch reachability: the conjuncts
                            -- a frame can answer.  See the limit block above --
                            -- X.CanJuke / GetProperTarget / ally count /
                            -- fountain distance are NOT driven from here.
                            if bot:GetLevel() >= LVL
                                and #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) <= 1
                                and J.IsItemAvailable('item_flask') == nil
                                and not bot:HasModifier('modifier_flask_healing')
                                and not bot:HasModifier('modifier_clarity_potion')
                                and not bot:HasModifier('modifier_filler_heal')
                                and not bot:HasModifier('modifier_item_urn_heal')
                                and not bot:HasModifier('modifier_item_spirit_vessel_heal')
                                and not bot:HasModifier('modifier_juggernaut_healing_ward_heal')
                                and not bot:HasModifier('modifier_bottle_regeneration')
                                and not bot:HasModifier('modifier_tango_heal')
                            then
                                bump('branch_open')
                                -- ⭐ THE COUNTERFACTUAL DOMAIN, and it is an
                                -- INTERSECTION rather than either factor: a
                                -- frame the helper answers TRUE on but the
                                -- branch already vetoes changes nothing.  This
                                -- is the criterion test_stayfield_callsite_
                                -- domain.lua pinned, counted instead of argued.
                                if sStop == 'domain' then bump('domain_and_branch_open') end
                            end
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
