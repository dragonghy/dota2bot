-- Heavy corpus sweep for tests/test_tpdeep_recover_band.lua, run as a SUBPROCESS
-- (a full-corpus drive that reloads the mock world once per hero-frame must not
-- run on run_tests.lua's long-lived heap).  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  The '回复状态' branch of X.ConsiderItemDesire["item_tpscroll"]
-- now carries TWO regen vetoes from the same family, and the whole point is that
-- their bands are DISJOINT:
--   'tprecov'  J.ShouldSipNotTpRecover      HP in [0.18, ..)
--   'tpdeep'   J.ShouldDeepSipNotTpRecover  HP in [0.10, 0.18)
-- tests/_tprecov_sweep.lua measured the reason this second one exists:
-- `stop_floor 29` -- the family's shared 0.18 floor stops 29 of the branch's 31
-- trigger frames, so the branch that actually fires at low HP lives almost
-- entirely below the band the P2 family is allowed to speak in.
--
-- ⭐ THE COLUMN THAT DECIDES WHETHER THE BAND IS REALLY A BAND: `overlap`.  Both
-- helpers are driven on EVERY live frame with one id armed at a time, and the
-- number of frames where both answer TRUE must be 0.  Disjointness is what makes
-- a single-arm wave on either id attributable; asserting it in prose while the
-- two predicates drift is exactly how a "per-id A/B" stops meaning anything.
--
-- ⭐⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  `deep_*` comes from the SHIPPED
-- global J.ShouldDeepSipNotTpRecover with J.IsSoakCandidate stubbed to false and
-- then to 'tpdeep' only.  Nothing here re-implements the decision.  The per-frame
-- `R` rows are a separate prefix walk whose only job is to say WHICH clause
-- stopped a trigger frame, so "the corpus has no domain" and "it has a domain
-- this helper rejects earlier" can never be the same reading.
--
-- ⛔ DIRECTION GOES THROUGH A COUNTER THAT IS PROVED TO COUNT.  This lever
-- appends a veto, so it can only turn the branch's TRUE into FALSE and
-- `flip_false_to_true` must be 0 over the whole corpus.  A counter whose content
-- is all zeros cannot tell "the direction holds" from "the tally never ran", so
-- both directions go through ONE `tally(a, b, sDown, sUp)` and it is called a
-- SECOND time with the legs SWAPPED: the branch that must read 0 on the real
-- call is the branch that must report the WHOLE domain on the swapped call.
--
-- ⚠️ ANTI-VACUUM FOR THE TOWER CLAUSE, stated because it is a real limit.  No
-- frame in the deep band has an enemy tower inside 1200, so `stop_tower` is 0 --
-- and a zero there could equally mean "the mock answers {} for everybody".  It
-- does not: `deep_with_any_tower` counts deep-band frames that see an enemy
-- tower at ANY radius (the loader restores real buildings from the dump), so the
-- zero is a reading about 1200 rather than about the mock.  The clause itself is
-- pinned structurally, never by this count.
--
-- ⚠️ WHAT THIS FILE DOES NOT DRIVE.  `X` in ability_item_usage_generic is a
-- FILE-LOCAL table, so the branch's own body cannot be called from here and
-- neither can `X.CanJuke()`.  `branch_open` is therefore an UPPER BOUND on the
-- branch's reachability, never a claim that the branch fires -- same shape and
-- same reason as tests/_tprecov_sweep.lua and
-- tests/test_stayfield_callsite_domain.lua.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   R <fixture> <hero> <hp> <lvl> <stop>
--       one live frame inside the '回复状态' trigger, with the clause that stops
--       J.ShouldDeepSipNotTpRecover: band_high | band_low | source | damage |
--       ring | tower | domain.  (The gate and the turbo check are NOT walked
--       here -- the walk runs below them by construction, and they are driven
--       instead by the shipped-vs-armed columns above.)  Every trigger frame
--       gets a row, in the domain or not -- the anti-vacuum column.
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
-- that names its own sibling, both radii and the shared floor, so reading the
-- raw block would let the COMMENT satisfy the assertions (the §EN mistake).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The text of one home-TP branch, from its trigger to its own cast motive.
--- Anchored on the motive STRING (code, never a comment).
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

local b1 = branch(aiug, 'if botHP < 0.19', '撤退:1')
local b2 = branch(aiug, 'if botHP < ( 0.15 + 0.24 * nEnemyCount )', '撤退:2')
local b4 = branch(aiug, 'if ( botHP + botMP < 0.3 or botHP < 0.2 )', '回复状态')
G.BRANCH_RECOVER = b4 and 1 or 0

-- ⭐ THE PAIR, counted rather than argued.  The sibling's own test file asserts
-- "one call site, one lever" about J.ShouldStayAndRegen and J.ShouldRegenNotTpHome
-- BY NAME, and 'J.ShouldDeepSipNotTpRecover' is not a superstring of
-- 'J.ShouldSipNotTpRecover' (the 'Deep' sits between 'Should' and 'Sip'), so that
-- file's counts are untouched by this landing.  That is stated, not relied on:
-- the pair is pinned HERE, so deleting either call site goes red somewhere.
G.RECOVER_SIPVETO = count(b4, 'J.ShouldSipNotTpRecover')
G.RECOVER_DEEPVETO = count(b4, 'J.ShouldDeepSipNotTpRecover')
G.RECOVER_OTHER_VETOES = count(b4, 'J.ShouldStayAndRegen')
    + count(b4, 'J.ShouldRegenNotTpHome')
-- ⛔ The 'pullcad' trap: two ids in one condition.  The gates live in the
-- helpers, so the branch condition must name none.
G.RECOVER_NIDS = count(b4, 'IsSoakCandidate')

-- The branch is the QUIET one -- that is the entire licence for reaching below
-- the family's floor here, so it is a measured fact and not a remark.
G.RECOVER_RECENTDMG = count(b4, 'WasRecentlyDamagedByAnyHero')
G.T1_RECENTDMG = count(b1, 'WasRecentlyDamagedByAnyHero')
G.T2_RECENTDMG = count(b2, 'WasRecentlyDamagedByAnyHero')
-- ...and it proves it in three more conjuncts.
G.RECOVER_PROPERTARGET = count(b4, 'J.GetProperTarget( bot ) == nil')
G.RECOVER_ATTACKTARGET = count(b4, 'bot:GetAttackTarget() == nil')
G.RECOVER_CANJUKE = count(b4, 'X.CanJuke()')

-- The new helper.
local deep = strip_comments(jmz:match('function J%.ShouldDeepSipNotTpRecover.-\nend'))
G.DEEP_FN = deep and 1 or 0
G.DEEP_NIDS = count(deep, 'IsSoakCandidate')
G.DEEP_TURBO = count(deep, 'J.IsModeTurbo()')

local at_gate = deep and deep:find("IsSoakCandidate( 'tpdeep' )", 1, true)
local at_turbo = deep and deep:find('IsModeTurbo()', 1, true)
local at_hp = deep and deep:find('J.GetHP(', 1, true)
local at_src = deep and deep:find('HasFieldRegenSource', 1, true)
-- An ABSENT clause must not flip this flag (the sibling's stand proved why):
-- missing positions are +inf, so this answers "is the gate ahead of every read
-- that IS still here", and each clause's presence is pinned separately.
local INF = math.huge
G.DEEP_GATE_FIRST = (at_gate and at_turbo
    and at_gate < at_turbo
    and at_gate < (at_hp or INF)
    and at_gate < (at_src or INF)) and 1 or 0

-- The band, parsed off the helper's own code.
G.DEEP_HI = tonumber(deep and deep:match('nHP >= ([%d%.]+)')) or -1
G.DEEP_LO = tonumber(deep and deep:match('nHP < ([%d%.]+)')) or -1

-- The three floors it must agree with.  The UPPER edge is the family's floor
-- copied verbatim: if the family ever moves it, the band must move with it or
-- the two levers start overlapping.
local sib = strip_comments(jmz:match('function J%.ShouldSipNotTpRecover.-\nend'))
G.SIB_FLOOR = tonumber(sib and sib:match('J%.GetHP%( bot %) < ([%d%.]+)')) or -1
local sar = strip_comments(jmz:match('function J%.ShouldStayAndRegen.-\nend\n'))
G.SAR_FLOOR = tonumber(sar and sar:match('nHP < ([%d%.]+)')) or -1
local frs = strip_comments(jmz:match('function J%.IsFieldRegenSituation.-\nend\n'))
G.SITUATION_FLOOR = tonumber(frs and frs:match('nHP < ([%d%.]+)')) or -1

-- The four narrowing clauses, pinned INDIVIDUALLY and with their CONSTANTS.  A
-- corpus counter cannot stand in for these (the band's own edges stop most
-- frames before the later clauses are reached), and a presence flag reads the
-- same whether the radius is 2500 or 120.
G.DEEP_SOURCE = count(deep, 'J.HasFieldRegenSource')
G.DEEP_DMG_WINDOW = tonumber(deep and deep:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.DEEP_RING = tonumber(deep and deep:match('J%.GetNearbyHeroes%( bot, (%d+)')) or -1
G.DEEP_TOWER = tonumber(deep and deep:match('bot:GetNearbyTowers%( (%d+)')) or -1
-- ⛔ The sibling's numbers, so "strictly tighter on every axis" is arithmetic
-- between two parsed constants rather than a sentence.
G.SIB_DMG_WINDOW = tonumber(sib and sib:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.SIB_RING = tonumber(sib and sib:match('J%.GetNearbyHeroes%( bot, (%d+)')) or -1
G.SIB_TOWER = tonumber(sib and sib:match('bot:GetNearbyTowers%( (%d+)')) or -1
-- ⛔ DELIBERATE ABSENCE, asserted so a later round cannot "harmonise" it in: the
-- deep band gives UP the sibling's attribution escape hatch on purpose.  Its
-- presence would widen the lever exactly where it must not widen.
G.DEEP_ATTRIB = count(deep, 'J.HasNearbyHeroDamager')
G.SIB_ATTRIB = count(sib, 'J.HasNearbyHeroDamager')
-- ...and the same non-routing the sibling documents, for the same two reasons.
G.DEEP_USES_FIELDSIP = count(deep, 'IsFieldSipEnough')
G.DEEP_USES_SITUATION = count(deep, 'IsFieldRegenSituation')
G.DEEP_USES_REGENNOTGOHOME = count(deep, 'ShouldRegenNotGoHome')

-- The branch's own trigger constants, so the domain rows are read against
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
local HI = G.DEEP_HI
local LO = G.DEEP_LO

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
for _, k in ipairs({ 'fixtures', 'live', 'raises', 'trigger', 'deep',
    'deep_shipped_true', 'deep_armed_true', 'deep_true_in_trigger',
    'flips', 'flip_false_to_true', 'flips_swapped', 'flip_false_to_true_swapped',
    'arm_leak', 'overlap', 'sibling_armed_true', 'sibling_true_in_trigger',
    'stop_band_high', 'stop_band_low', 'stop_source', 'stop_damage', 'stop_ring',
    'stop_tower', 'branch_open', 'domain_and_branch_open',
    'deep_with_any_tower', 'deep_ring_margin',
    'band_low_otherwise_domain', 'band_high_otherwise_domain' }) do
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
                    local sArmed = nil
                    J.IsSoakCandidate = function(sId)
                        return sArmed ~= nil and sId == sArmed
                    end
                    local sFx = path:match('([^/]+)%.lua$')
                    local sHero = u.name:gsub('npc_dota_hero_', '')
                    local nHP, nMP = J.GetHP(bot), J.GetMP(bot)

                    local okShip, shipped = pcall(J.ShouldDeepSipNotTpRecover, bot)
                    sArmed = 'tpdeep'
                    -- The arming must be ONE id wide.  A stub arming them all
                    -- would let another live id move this answer while the flip
                    -- is still attributed here.  Asserted 0 downstream.
                    if J.IsSoakCandidate('tprecov') or J.IsSoakCandidate('fieldsip')
                        or J.IsSoakCandidate('stayfield') then
                        bump('arm_leak')
                    end
                    local okArm, arm = pcall(J.ShouldDeepSipNotTpRecover, bot)
                    -- ⭐ The sibling, armed on its OWN id, on the same frame.
                    sArmed = 'tprecov'
                    local okSib, sib_true = pcall(J.ShouldSipNotTpRecover, bot)
                    sArmed = nil

                    if not (okShip and okArm and okSib) then
                        bump('raises')
                    else
                        shipped = shipped and true or false
                        arm = arm and true or false
                        sib_true = sib_true and true or false

                        if shipped then bump('deep_shipped_true') end
                        if arm then bump('deep_armed_true') end
                        if sib_true then bump('sibling_armed_true') end
                        -- ⭐ THE DISJOINTNESS COLUMN.  Each helper armed on its
                        -- own id; a frame both answer TRUE on would mean the two
                        -- bands overlap and a single-arm wave on either can no
                        -- longer be attributed.  Must be 0.
                        if arm and sib_true then bump('overlap') end
                        tally(arm, shipped, 'flips', 'flip_false_to_true')
                        -- Legs EXCHANGED, same `tally`.
                        tally(shipped, arm, 'flips_swapped', 'flip_false_to_true_swapped')

                        local bTrigger = (nHP + nMP < SUM_TRIG) or (nHP < HP_TRIG)
                        if bTrigger then
                            bump('trigger')
                            if sib_true then bump('sibling_true_in_trigger') end
                            if nHP < HI then
                                bump('deep')
                                -- Anti-vacuum for the tower clause: does this
                                -- frame's world contain an enemy tower AT ALL?
                                if #bot:GetNearbyTowers(20000, true) > 0 then
                                    bump('deep_with_any_tower')
                                end
                                -- The margin this lever adds over the sibling's
                                -- ring: empty at 1200 (the sibling would pass)
                                -- and NOT empty at this helper's radius.
                                if #J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) == 0
                                    and #J.GetNearbyHeroes(bot, G.DEEP_RING, true, BOT_MODE_NONE) > 0
                                then
                                    bump('deep_ring_margin')
                                end
                            end

                            -- The prefix walk: which clause of the helper stops
                            -- this frame.  Buckets sum to `trigger` by counting.
                            local sStop
                            if nHP >= HI then
                                sStop = 'band_high'; bump('stop_band_high')
                            elseif nHP < LO then
                                sStop = 'band_low'; bump('stop_band_low')
                            elseif not J.HasFieldRegenSource(bot) then
                                sStop = 'source'; bump('stop_source')
                            elseif bot:WasRecentlyDamagedByAnyHero(G.DEEP_DMG_WINDOW) then
                                sStop = 'damage'; bump('stop_damage')
                            elseif #J.GetNearbyHeroes(bot, G.DEEP_RING, true, BOT_MODE_NONE) > 0 then
                                sStop = 'ring'; bump('stop_ring')
                            elseif #bot:GetNearbyTowers(G.DEEP_TOWER, true) > 0 then
                                sStop = 'tower'; bump('stop_tower')
                            else
                                sStop = 'domain'; bump('deep_true_in_trigger')
                            end
                            out:write(string.format('R %s %s %.3f %d %s\n',
                                sFx, sHero, nHP, bot:GetLevel(), sStop))

                            -- ⭐ WHAT EACH BAND EDGE ACTUALLY COSTS.  A prefix
                            -- walk reports the FIRST clause that stops a frame,
                            -- so an edge can read as "stopping 12 frames" while
                            -- costing zero domain -- the later clauses would
                            -- have stopped all 12 anyway.  These two count the
                            -- frames an edge stops that EVERY other clause would
                            -- have let through, i.e. the edge's real price.  A
                            -- zero here is exactly why the edge must be pinned
                            -- structurally and never by a domain count (the
                            -- sibling stand's M6/M7 lesson).
                            if sStop == 'band_low' or sStop == 'band_high' then
                                local bRest = J.HasFieldRegenSource(bot)
                                    and not bot:WasRecentlyDamagedByAnyHero(G.DEEP_DMG_WINDOW)
                                    and #J.GetNearbyHeroes(bot, G.DEEP_RING, true, BOT_MODE_NONE) == 0
                                    and #bot:GetNearbyTowers(G.DEEP_TOWER, true) == 0
                                if bRest then
                                    bump(sStop == 'band_low' and 'band_low_otherwise_domain'
                                        or 'band_high_otherwise_domain')
                                end
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
                                -- ⭐ THE COUNTERFACTUAL DOMAIN, an INTERSECTION
                                -- rather than either factor: a frame the helper
                                -- answers TRUE on but the branch already vetoes
                                -- changes nothing.
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
